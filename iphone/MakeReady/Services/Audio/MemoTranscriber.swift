//
//  MemoTranscriber.swift
//  MakeReady
//
//  On-device voice-memo transcription over SpeechAnalyzer / SpeechTranscriber (iOS 26). Wraps the
//  asset ensure/reserve/release steps and answers nil, never a throw, when speech is unavailable:
//  the upload then omits the transcript and the server falls back (D5, D21).
//  Live latency and the first-run asset download are proven on a device only (F1).
//

import AVFoundation
import CoreMedia
import Speech

// MARK: - Availability

/// Decides, per locale, whether on-device transcription can run, installing and reserving the
/// speech assets when it can. A struct of one closure so tests substitute it.
struct MemoSpeechAvailability {
    /// The supported locale equivalent to the one asked for, its assets installed and reserved for
    /// this app — or nil when transcription can't run. The caller releases that locale when done.
    let resolve: (Locale) async -> Locale?

    static let system = MemoSpeechAvailability { requested in
        // The device locale (`en_US@rg=…`, a custom calendar, …) is rarely the transcriber's own
        // identifier: every later call — the module, the asset check, the reservation — uses the
        // supported equivalent, or the assets and the reservation never line up.
        guard SpeechTranscriber.isAvailable,
              let locale = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            Log.memo.error("speech unavailable for \(requested.identifier, privacy: .public)")
            return nil
        }
        do {
            let probe = Self.makeTranscriber(locale: locale)
            if await AssetInventory.status(forModules: [probe]) != .installed,
               let request = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
                try await request.downloadAndInstall()
            }
            // `reserve` answers false when the locale is already reserved (an earlier session that
            // never released it): that is still a reservation, not a failure.
            if !(try await AssetInventory.reserve(locale: locale)) {
                let held = await AssetInventory.reservedLocales
                guard held.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
                    Log.memo.error("speech locale not reservable: \(locale.identifier, privacy: .public)")
                    return nil
                }
            }
            return locale
        } catch {
            // Recovered: unavailable is a normal outcome here, the server transcribes instead (D5).
            Log.memo.error("speech assets not installable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Always unavailable (tests, and the fallback path).
    static let unavailable = MemoSpeechAvailability { _ in nil }

    fileprivate static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [],
                          attributeOptions: [.audioTimeRange])
    }
}

// MARK: - Protocol

protocol MemoTranscribing: AnyObject {
    /// Starts a live analysis fed by `stream`. False when on-device transcription is unavailable.
    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool
    /// The format the analyzer wants its input in. Nil until `startLive` succeeds.
    var analyzerFormat: AVAudioFormat? { get }
    /// Finalizes through the end of the live input. Nil when nothing was started or nothing said.
    func finish() async -> Transcript?
    /// The same pipeline over a finished file (D16 salvage). Nil when unavailable or silent.
    func transcribeFile(_ url: URL) async -> Transcript?
}

// MARK: - Transcriber

final class MemoTranscriber: MemoTranscribing, @unchecked Sendable {
    /// One finalized result, in whole milliseconds.
    struct Piece: Equatable {
        let text: String
        let startMs: Int
        let endMs: Int
    }

    private struct LiveSession {
        let analyzer: SpeechAnalyzer
        let collector: Task<[Piece], Never>
        let format: AVAudioFormat
    }

    private let locale: Locale
    private let availability: MemoSpeechAvailability
    /// The supported locale `availability` reserved for the transcription in flight.
    private var reserved: Locale?
    private let lock = NSLock()
    private var session: LiveSession?

    init(locale: Locale = .current, availability: MemoSpeechAvailability = .system) {
        self.locale = locale
        self.availability = availability
    }

    var analyzerFormat: AVAudioFormat? {
        lock.withLock { session?.format }
    }

    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool {
        guard lock.withLock({ session == nil }), let resolved = await availability.resolve(locale) else { return false }
        lock.withLock { reserved = resolved }
        let transcriber = MemoSpeechAvailability.makeTranscriber(locale: resolved)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            Log.memo.error("no analyzer audio format for \(self.locale.identifier)")
            await releaseAssets()
            return false
        }
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collector = Self.collect(from: transcriber)
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            // Recovered: no live transcript; the server fallback covers it (D5, D21).
            Log.memo.error("live analyzer failed to start: \(error.localizedDescription)")
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            await releaseAssets()
            return false
        }
        lock.withLock { session = LiveSession(analyzer: analyzer, collector: collector, format: format) }
        return true
    }

    func finish() async -> Transcript? {
        guard let live = lock.withLock({ () -> LiveSession? in
            defer { session = nil }
            return session
        }) else { return nil }
        do {
            try await live.analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            // Recovered: keep whatever results arrived before the failure.
            Log.memo.error("live finalize failed: \(error.localizedDescription)")
        }
        let pieces = await live.collector.value
        await releaseAssets()
        return Self.transcript(from: pieces)
    }

    func transcribeFile(_ url: URL) async -> Transcript? {
        guard let resolved = await availability.resolve(locale) else { return nil }
        lock.withLock { reserved = resolved }
        let transcriber = MemoSpeechAvailability.makeTranscriber(locale: resolved)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collector = Self.collect(from: transcriber)
        do {
            let file = try AVAudioFile(forReading: url)
            if let last = try await analyzer.analyzeSequence(from: file) {
                try await analyzer.finalizeAndFinish(through: last)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            // Recovered: keep whatever results arrived before the failure.
            Log.memo.error("file transcription failed: \(error.localizedDescription)")
            await analyzer.cancelAndFinishNow()
        }
        let pieces = await collector.value
        await releaseAssets()
        return Self.transcript(from: pieces)
    }

    // MARK: Mapping

    /// Text = the results joined by one space; one segment per result. No text at all → nil (D1).
    static func transcript(from pieces: [Piece]) -> Transcript? {
        let spoken = pieces.filter { !$0.text.isEmpty }
        guard !spoken.isEmpty else { return nil }
        return Transcript(
            text: spoken.map(\.text).joined(separator: " "),
            segments: spoken.map { TranscriptSegment(text: $0.text, startMs: $0.startMs, endMs: $0.endMs) }
        )
    }

    // MARK: Private

    private static func collect(from transcriber: SpeechTranscriber) -> Task<[Piece], Never> {
        Task {
            var pieces: [Piece] = []
            do {
                for try await result in transcriber.results {
                    if let piece = piece(from: result) { pieces.append(piece) }
                }
            } catch {
                // Recovered: results gathered so far still make a partial transcript.
                Log.memo.error("transcriber results ended with an error: \(error.localizedDescription)")
            }
            return pieces
        }
    }

    /// The result's text, timed by the span of its `audioTimeRange` runs (whole result range if none).
    private static func piece(from result: SpeechTranscriber.Result) -> Piece? {
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var range: CMTimeRange?
        for run in result.text.runs {
            guard let runRange = run.audioTimeRange else { continue }
            range = range.map { $0.union(runRange) } ?? runRange
        }
        let span = range ?? result.range
        return Piece(text: text, startMs: milliseconds(span.start), endMs: milliseconds(span.end))
    }

    private static func milliseconds(_ time: CMTime) -> Int {
        let seconds = CMTimeGetSeconds(time)
        return seconds.isFinite ? max(0, Int((seconds * 1000).rounded())) : 0
    }

    private func releaseAssets() async {
        guard let held = lock.withLock({ () -> Locale? in defer { reserved = nil }; return reserved }) else { return }
        _ = await AssetInventory.release(reservedLocale: held)
    }
}
