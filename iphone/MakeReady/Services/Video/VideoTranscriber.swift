//
//  VideoTranscriber.swift
//  MakeReady
//
//  The on-device transcript of an exported video (video-recorder D10). Answers nil whenever there is
//  none in time (unsupported locale, missing model, failure, timeout): the server then transcribes it,
//  and Save never waits past the timeout.
//

import AVFoundation
import Foundation

struct VideoTranscript: Codable, Equatable {
    let text: String
    /// Timed in ms from the start of the exported file.
    let segments: [VideoTranscriptSegment]
}

struct VideoTranscriber {
    private let core: any MemoTranscribing

    /// The default transcribes in the device's locale.
    init(core: any MemoTranscribing = MemoTranscriber()) {
        self.core = core
    }

    /// Returns at the timeout even when the transcription cannot be stopped; a late answer is dropped.
    func transcribe(video: URL, timeout: Duration) async -> VideoTranscript? {
        let core = core
        return await Self.race(timeout: timeout) { await Self.transcript(of: video, core: core) }
    }

    /// Transcribes an audio file already made, such as `VideoExporter.exportSound`'s. The file stays the caller's.
    func transcribe(audio: URL, timeout: Duration) async -> VideoTranscript? {
        let core = core
        return await Self.race(timeout: timeout) { await Self.transcript(ofAudio: audio, core: core) }
    }

    /// Transcribes the sound of `clips` joined, kept to `window` (seconds, nil = all). Times count from the
    /// window's start (video-editor D11, D21). One timeout covers the export and the transcription; nil on
    /// failure, timeout, cancellation or blank text.
    func transcribe(clips: [URL], window: ClosedRange<Double>?, timeout: Duration) async -> VideoTranscript? {
        let core = core
        let range = window.map {
            CMTimeRange(start: CMTime(seconds: $0.lowerBound, preferredTimescale: 600),
                        end: CMTime(seconds: $0.upperBound, preferredTimescale: 600))
        }
        return await Self.race(timeout: timeout) {
            let audio = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
            defer {
                if FileManager.default.fileExists(atPath: audio.path) {
                    try? FileManager.default.removeItem(at: audio) // Silent: a leftover in tmp, which the system empties
                }
            }
            do {
                try await VideoExporter.exportSound(segments: clips, timeRange: range, to: audio)
            } catch {
                // Recovered: no transcript from the device; the caller shows its reason.
                Log.media.error("clip sound not exported: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            guard let transcript = await Self.transcript(ofAudio: audio, core: core),
                  !transcript.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return transcript
        }
    }

    /// Answers the first of the work and the timer; both are cancelled on the way out.
    private static func race(timeout: Duration,
                             work: @escaping @Sendable () async -> VideoTranscript?) async -> VideoTranscript? {
        let (answers, answer) = AsyncStream.makeStream(of: VideoTranscript?.self)
        let work = Task { answer.yield(await work()) }
        let timer = Task {
            do {
                try await Task.sleep(for: timeout)
                answer.yield(nil)
            } catch {
                // Silent: cancelled, the transcription answered first.
            }
        }
        defer {
            work.cancel()
            timer.cancel()
        }
        for await first in answers { return first }
        return nil
    }

    /// Transcribes an extracted `.m4a`: the analyzer's audio reader may refuse a file with a video track.
    private static func transcript(of video: URL, core: any MemoTranscribing) async -> VideoTranscript? {
        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        defer {
            if FileManager.default.fileExists(atPath: audio.path) {
                try? FileManager.default.removeItem(at: audio) // Silent: a leftover in tmp, which the system empties
            }
        }
        do {
            try await MemoAudioExporter.exportM4A(from: video, to: audio)
        } catch {
            // Recovered: no transcript from the device; the server transcribes instead.
            Log.media.error("video audio not extracted: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        return await transcript(ofAudio: audio, core: core)
    }

    private static func transcript(ofAudio audio: URL, core: any MemoTranscribing) async -> VideoTranscript? {
        guard !Task.isCancelled, let transcript = await core.transcribeFile(audio) else { return nil }
        return VideoTranscript(text: transcript.text, segments: transcript.segments.map {
            VideoTranscriptSegment(text: $0.text, startMs: $0.startMs, endMs: $0.endMs)
        })
    }
}
