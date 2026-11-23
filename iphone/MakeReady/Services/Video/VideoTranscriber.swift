//
//  VideoTranscriber.swift
//  MakeReady
//
//  The on-device transcript of an exported video (video-recorder D10). Answers nil whenever there is
//  none in time (unsupported locale, missing model, failure, timeout): the server then transcribes it,
//  and Save never waits past the timeout.
//

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
        let (answers, answer) = AsyncStream.makeStream(of: VideoTranscript?.self)
        let core = core
        let work = Task { answer.yield(await Self.transcript(of: video, core: core)) }
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
        guard !Task.isCancelled, let transcript = await core.transcribeFile(audio) else { return nil }
        return VideoTranscript(text: transcript.text, segments: transcript.segments.map {
            VideoTranscriptSegment(text: $0.text, startMs: $0.startMs, endMs: $0.endMs)
        })
    }
}
