//
//  MemoRecorderEngine.swift
//  MakeReady
//
//  Voice-memo capture core: one input, fanned out to an AAC `.caf` writer, waveform peaks, a live
//  level ring and (when speech is available) the transcriber's input stream (D14, D15). `stop()`
//  exports the `.caf` to `<uuid>.m4a` (D38). Paused audio is dropped, never written or counted
//  (D42). The audio session is prepared, activated and restored around a recording (D20); an
//  interruption or an unplugged input pauses it (D16); a draft manifest sits beside the `.caf`
//  from `start` until the export succeeds, so a cut-off recording can be salvaged.
//

import AVFoundation
import Foundation
import Speech

// MARK: - Engine

@MainActor @Observable
final class MemoRecorderEngine {
    private(set) var state: RecorderState = .idle
    /// The newest ~10 s of levels, one max-abs value per 2 205 frames (~20 Hz), oldest first.
    private(set) var samples: [Float] = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var lastError: MemoEngineError?
    private(set) var cafURL: URL?
    /// Called, on the main actor, with the intact result when the engine stops itself at `maxDuration`.
    @ObservationIgnored var onAutoStop: ((RecordingResult) -> Void)?

    @ObservationIgnored private let input: AudioInputSource
    @ObservationIgnored private let transcriber: MemoTranscribing?
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let maxDuration: TimeInterval
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let writeBuffer: @Sendable (AVAudioFile, AVAudioPCMBuffer) throws -> Void
    @ObservationIgnored private let audioSession: MemoAudioSessionControlling
    @ObservationIgnored private let drafts: MemoDraftStore
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private let requestMicPermission: () async -> Bool
    @ObservationIgnored private var observers = ObserverBag()
    @ObservationIgnored private var prepared: Prepared?
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var lastSequence = 0
    /// True while the pause in effect came from an interruption, so only that pause auto-resumes (D16).
    @ObservationIgnored private var pausedByInterruption = false

    /// What `prepare` set up: the title and, when speech started, the transcriber's input stream.
    private struct Prepared {
        let title: String
        let live: AsyncStream<AnalyzerInput>.Continuation?
        let analyzerFormat: AVAudioFormat?
    }

    /// One recording, from `start` to `stop`.
    private struct Session {
        let cafURL: URL
        let title: String
        let recordedAt: Date
        let pipeline: CapturePipeline
        let transcriberStarted: Bool
    }

    init(input: AudioInputSource, transcriber: MemoTranscribing?, directory: URL,
         maxDuration: TimeInterval = 10_800, now: @escaping () -> Date = Date.init,
         session: MemoAudioSessionControlling = MemoAudioSession(), drafts: MemoDraftStore,
         notificationCenter: NotificationCenter = .default,
         requestMicPermission: @escaping () async -> Bool = { await LiveAudioInput.requestPermission() },
         writeBuffer: @escaping @Sendable (AVAudioFile, AVAudioPCMBuffer) throws -> Void = { try $0.write(from: $1) }) {
        self.audioSession = session
        self.drafts = drafts
        self.notificationCenter = notificationCenter
        self.requestMicPermission = requestMicPermission
        self.writeBuffer = writeBuffer
        self.input = input
        self.transcriber = transcriber
        self.directory = directory
        self.maxDuration = maxDuration
        self.now = now
    }

    // MARK: Lifecycle

    /// Checks the microphone (live input only) and starts the transcriber, which may download
    /// speech assets, so `start()` stays quick.
    func prepare(title: String) async throws {
        guard state == .idle else { throw CancellationError() }
        lastError = nil
        if input is LiveAudioInput, !(await requestMicPermission()) {
            lastError = .micPermissionDenied
            throw MemoEngineError.micPermissionDenied
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Log.memo.error("memo directory not creatable: \(error.localizedDescription)")
            lastError = .writeFailed
            throw MemoEngineError.writeFailed
        }
        do {
            try audioSession.prepareForRecording()
        } catch {
            Log.memo.error("audio session not preparable: \(error.localizedDescription)")
            lastError = .writeFailed
            throw MemoEngineError.writeFailed
        }
        var live: AsyncStream<AnalyzerInput>.Continuation?
        if let transcriber {
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
            if await transcriber.startLive(stream: stream) {
                live = continuation
            } else {
                // Recovered: no live transcript; the server transcribes the upload instead (D5, D21).
                continuation.finish()
                lastError = .speechUnavailable
                Log.memo.error("live transcription unavailable; recording without it")
            }
        }
        prepared = Prepared(title: title, live: live, analyzerFormat: live == nil ? nil : transcriber?.analyzerFormat)
    }

    func start() async throws {
        guard state == .idle, let prepared else { throw CancellationError() }
        let url = directory.appendingPathComponent("\(UUID().uuidString).caf")
        let pipeline: CapturePipeline
        do {
            pipeline = try CapturePipeline(url: url, maxFrames: Int(maxDuration * CapturePipeline.sampleRate),
                                           live: prepared.live, analyzerFormat: prepared.analyzerFormat,
                                           writeBuffer: writeBuffer) { [weak self] output in
                Task { @MainActor in await self?.handle(output) }
            }
        } catch {
            Log.memo.error("capture file not creatable: \(error.localizedDescription)")
            audioSession.restore()
            lastError = .writeFailed
            throw MemoEngineError.writeFailed
        }
        do {
            try audioSession.activate()
        } catch {
            Log.memo.error("audio session not activatable: \(error.localizedDescription)")
            _ = pipeline.close()
            try? FileManager.default.removeItem(at: url) // Silent: nothing was recorded, so no partial .caf is kept
            audioSession.restore()
            lastError = .writeFailed
            throw MemoEngineError.writeFailed
        }
        let startedAt = now()
        do {
            try drafts.write(drafts.manifest(cafURL: url, startedAt: startedAt, title: prepared.title))
        } catch {
            // Recovered: the recording still works, it just cannot be salvaged if cut off.
            Log.memo.error("draft manifest not writable: \(error.localizedDescription)")
        }
        session = Session(cafURL: url, title: prepared.title, recordedAt: startedAt, pipeline: pipeline,
                          transcriberStarted: prepared.live != nil)
        self.prepared = nil
        cafURL = url
        samples = []
        elapsed = 0
        lastSequence = 0
        state = .recording
        observeSession()
        do {
            try input.start { pipeline.process($0) }
        } catch {
            Log.memo.error("audio input did not start: \(error.localizedDescription)")
            _ = pipeline.close()
            drafts.remove(cafURL: url)
            try? FileManager.default.removeItem(at: url) // Silent: nothing was recorded, so no partial .caf is kept
            end()
            throw error
        }
    }

    func pause() {
        guard state == .recording, let session else { return }
        session.pipeline.setPaused(true)
        pausedByInterruption = false
        state = .paused
    }

    func resume() throws {
        guard state == .paused, let session else { throw CancellationError() }
        session.pipeline.setPaused(false)
        pausedByInterruption = false
        state = .recording
    }

    func stop() async throws -> RecordingResult {
        guard state == .recording || state == .paused, let session else {
            throw lastError == .writeFailed ? MemoEngineError.writeFailed : CancellationError()
        }
        state = .finishing
        input.stop()
        let closed = session.pipeline.close()
        let m4a = session.cafURL.deletingPathExtension().appendingPathExtension("m4a")
        do {
            try await MemoAudioExporter.exportM4A(from: session.cafURL, to: m4a)
        } catch {
            // The `.caf` stays on disk for salvage (D38).
            Log.memo.error("m4a export failed: \(error.localizedDescription)")
            lastError = .writeFailed
            _ = await finishTranscript(of: session)
            end()
            throw MemoEngineError.writeFailed
        }
        do {
            try FileManager.default.removeItem(at: session.cafURL)
        } catch {
            // Recovered: the leftover `.caf` is harmless; the `.m4a` is the result.
            Log.memo.error("caf not removable after export: \(error.localizedDescription)")
        }
        drafts.remove(cafURL: session.cafURL)
        let transcript = await finishTranscript(of: session)
        samples = closed.samples
        elapsed = Double(closed.frames) / CapturePipeline.sampleRate
        end()
        return RecordingResult(fileURL: m4a, title: session.title, durationMs: closed.durationMs,
                               waveformPeaks: closed.peaks, recordedAt: session.recordedAt, transcript: transcript)
    }

    /// Undoes `prepare` when the recorder closes before recording starts (owner 2026-11-21: the
    /// recorder waits for the record tap): ends the transcriber's idle stream, releases its speech
    /// assets and gives the audio session back. A no-op unless prepared and not yet started.
    func cancelPrepared() async {
        guard state == .idle, let prepared else { return }
        self.prepared = nil
        prepared.live?.finish()
        if prepared.live != nil { _ = await transcriber?.finish() }
        audioSession.restore()
    }

    /// Throws the recording away (D7): no `.m4a`, no result, no `onAutoStop`. A no-op unless recording or paused.
    func discard() async {
        guard state == .recording || state == .paused, let session else { return }
        // Before the first await, as `stop()` does: a second discard or an auto-stop now finds no live recording.
        state = .finishing
        input.stop()
        _ = session.pipeline.close()
        _ = await finishTranscript(of: session)
        do {
            try FileManager.default.removeItem(at: session.cafURL)
        } catch {
            // Recovered: a leftover `.caf` is harmless; the draft manifest below is gone either way.
            Log.memo.error("caf not removable on discard: \(error.localizedDescription)")
        }
        drafts.remove(cafURL: session.cafURL)
        end()
    }

    // MARK: Pipeline output

    private func handle(_ output: CapturePipeline.Output) async {
        switch output {
        case .progress(let snapshot):
            guard snapshot.sequence > lastSequence, state == .recording || state == .paused else { return }
            lastSequence = snapshot.sequence
            samples = snapshot.samples
            elapsed = Double(snapshot.frames) / CapturePipeline.sampleRate
        case .limitReached:
            guard state == .recording || state == .paused else { return }
            lastError = .durationLimitReached
            do {
                let result = try await stop()
                onAutoStop?(result)
            } catch {
                Log.memo.error("auto-stop at the duration limit failed: \(error.localizedDescription)")
            }
        case .writeFailed:
            guard state == .recording || state == .paused, let session else { return }
            input.stop()
            _ = session.pipeline.close()
            lastError = .writeFailed
            _ = await finishTranscript(of: session)
            end()
        }
    }

    // MARK: Helpers

    private func finishTranscript(of session: Session) async -> Transcript? {
        session.transcriberStarted ? await transcriber?.finish() : nil
    }

    private func end() {
        observers = ObserverBag()
        pausedByInterruption = false
        audioSession.restore()
        session = nil
        state = .idle
    }

    // MARK: Interruptions and route changes (D16)

    private func observeSession() {
        let bag = ObserverBag()
        bag.add(notificationCenter, AVAudioSession.interruptionNotification) { [weak self] info in
            self?.handleInterruption(info)
        }
        bag.add(notificationCenter, AVAudioSession.routeChangeNotification) { [weak self] info in
            self?.handleRouteChange(info)
        }
        observers = bag
    }

    private func handleInterruption(_ info: [AnyHashable: Any]?) {
        guard let raw = info?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            guard state == .recording else { return }
            pause()
            pausedByInterruption = true
        case .ended:
            let options = AVAudioSession.InterruptionOptions(rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            guard options.contains(.shouldResume), state == .paused, pausedByInterruption else { return }
            do {
                try audioSession.activate()
                try resume()
            } catch {
                // Recovered: stays paused; the owner resumes or stops it.
                Log.memo.error("recording not resumed after interruption: \(error.localizedDescription)")
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ info: [AnyHashable: Any]?) {
        guard let raw = info?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
        pause()
    }
}

// MARK: - Capture pipeline

/// The per-buffer work, off the main actor: convert to mono float32 44.1 kHz, write, reduce to
/// peaks and levels, feed the transcriber. Every buffer arrives on the input's thread, so all
/// state sits behind one lock; results go out through `output` after the lock is released.
private final class CapturePipeline: @unchecked Sendable {
    static let sampleRate = 44_100.0
    static let peakFrames = 4_410
    static let levelFrames = 2_205
    static let levelCount = 200

    struct Snapshot {
        let sequence: Int
        let samples: [Float]
        let frames: Int
    }

    enum Output {
        case progress(Snapshot)
        case limitReached
        case writeFailed
    }

    /// What `close` leaves: everything the result needs.
    struct Closed {
        let frames: Int
        let samples: [Float]
        let peaks: [Double]

        var durationMs: Int { Int((Double(frames) / CapturePipeline.sampleRate * 1000).rounded()) }
    }

    private let target: AVAudioFormat
    private let maxFrames: Int
    private let output: @Sendable (Output) -> Void
    private let writeBuffer: @Sendable (AVAudioFile, AVAudioPCMBuffer) throws -> Void
    private let lock = NSLock()

    private var file: AVAudioFile?
    private var converters: [AVAudioFormat: AVAudioConverter] = [:]
    private var live: (continuation: AsyncStream<AnalyzerInput>.Continuation, converter: AVAudioConverter)?
    private var paused = false
    private var ended = false
    private var frames = 0
    private var sequence = 0
    private var peaks: [Double] = []
    private var peakMax: Float = 0
    private var peakFill = 0
    private var levels: [Float] = []
    private var levelMax: Float = 0
    private var levelFill = 0

    init(url: URL, maxFrames: Int, live: AsyncStream<AnalyzerInput>.Continuation?, analyzerFormat: AVAudioFormat?,
         writeBuffer: @escaping @Sendable (AVAudioFile, AVAudioPCMBuffer) throws -> Void,
         output: @escaping @Sendable (Output) -> Void) throws {
        self.writeBuffer = writeBuffer
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate,
                                         channels: 1, interleaved: false) else {
            throw MemoEngineError.writeFailed
        }
        self.target = target
        self.maxFrames = maxFrames
        self.output = output
        file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Self.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000
        ], commonFormat: .pcmFormatFloat32, interleaved: false)
        if let live, let analyzerFormat, let converter = AVAudioConverter(from: target, to: analyzerFormat) {
            self.live = (live, converter)
        } else {
            live?.finish()
        }
    }

    func setPaused(_ value: Bool) {
        lock.withLock { paused = value }
    }

    func process(_ incoming: AVAudioPCMBuffer) {
        let outputs: [Output] = lock.withLock {
            guard !paused, !ended, file != nil, let buffer = convert(incoming) else { return [] }
            let remaining = maxFrames - frames
            let atLimit = Int(buffer.frameLength) >= remaining
            if atLimit { buffer.frameLength = AVAudioFrameCount(max(remaining, 0)) }
            guard buffer.frameLength > 0 else { return [] }
            do {
                if let file { try writeBuffer(file, buffer) }
            } catch {
                Log.memo.error("caf write failed: \(error.localizedDescription)")
                ended = true
                return [.writeFailed]
            }
            frames += Int(buffer.frameLength)
            reduce(buffer)
            feedLive(buffer)
            sequence += 1
            var outputs: [Output] = [.progress(Snapshot(sequence: sequence, samples: levels, frames: frames))]
            if atLimit {
                ended = true
                outputs.append(.limitReached)
            }
            return outputs
        }
        outputs.forEach(output)
    }

    /// Ends the capture: no more buffers are taken, the last partial peak bucket counts, the
    /// `.caf` is closed and the transcriber's stream ends. Safe to call twice.
    func close() -> Closed {
        lock.withLock {
            ended = true
            if peakFill > 0 {
                peaks.append(Double(peakMax))
                peakFill = 0
                peakMax = 0
            }
            file?.close()
            file = nil
            live?.continuation.finish()
            live = nil
            return Closed(frames: frames, samples: levels, peaks: peaks)
        }
    }

    // MARK: Per buffer (lock held)

    private func convert(_ incoming: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let converter: AVAudioConverter
        if let known = converters[incoming.format] {
            converter = known
        } else if let made = AVAudioConverter(from: incoming.format, to: target) {
            converters[incoming.format] = made
            converter = made
        } else {
            Log.memo.error("no converter for input format \(incoming.format)")
            return nil
        }
        return Self.convert(incoming, with: converter, to: target)
    }

    private static func convert(_ source: AVAudioPCMBuffer, with converter: AVAudioConverter,
                                to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount((Double(source.frameLength) * ratio).rounded(.up)) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var failure: NSError?
        let status = converter.convert(to: converted, error: &failure) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error, failure == nil else {
            Log.memo.error("buffer conversion failed: \(failure?.localizedDescription ?? "unknown")")
            return nil
        }
        return converted
    }

    /// Peaks (max |sample| per 4 410 frames) and levels (per 2 205 frames, a 200-value ring).
    private func reduce(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        for index in 0..<Int(buffer.frameLength) {
            let value = min(abs(channel[index]), 1)
            peakMax = max(peakMax, value)
            peakFill += 1
            if peakFill == Self.peakFrames {
                peaks.append(Double(peakMax))
                peakMax = 0
                peakFill = 0
            }
            levelMax = max(levelMax, value)
            levelFill += 1
            if levelFill == Self.levelFrames {
                levels.append(levelMax)
                if levels.count > Self.levelCount { levels.removeFirst(levels.count - Self.levelCount) }
                levelMax = 0
                levelFill = 0
            }
        }
    }

    private func feedLive(_ buffer: AVAudioPCMBuffer) {
        guard let live, let converted = Self.convert(buffer, with: live.converter, to: live.converter.outputFormat) else { return }
        live.continuation.yield(AnalyzerInput(buffer: converted))
    }
}

// MARK: - Notification observers

/// Holds block observers and removes them when it goes away, so the engine needs no `deinit`
/// access to main-actor state. Handlers run on the main actor whatever thread posts.
private final class ObserverBag: @unchecked Sendable {
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    @MainActor
    func add(_ center: NotificationCenter, _ name: Notification.Name,
             handler: @escaping @MainActor ([AnyHashable: Any]?) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: nil) { note in
            nonisolated(unsafe) let info = note.userInfo
            if Thread.isMainThread {
                MainActor.assumeIsolated { handler(info) }
            } else {
                Task { @MainActor in handler(info) }
            }
        }
        tokens.append((center, token))
    }

    deinit {
        tokens.forEach { $0.0.removeObserver($0.1) }
    }
}
