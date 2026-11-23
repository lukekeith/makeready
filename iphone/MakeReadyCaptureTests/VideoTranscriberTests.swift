//
//  VideoTranscriberTests.swift
//  MakeReadyCaptureTests
//
//  The on-device transcript of an exported video (video-recorder D10): never waited for past its timeout.
//

import AVFoundation
import Speech
import XCTest
@testable import MakeReady

/// Ignores cancellation, as a transcription that cannot be stopped would.
private final class SlowTranscriber: MemoTranscribing, @unchecked Sendable {
    let delay: TimeInterval
    let analyzerFormat: AVAudioFormat? = nil

    init(delay: Duration) {
        self.delay = TimeInterval(delay.components.seconds)
    }

    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool { false }
    func finish() async -> Transcript? { nil }
    func transcribeFile(_ url: URL) async -> Transcript? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { continuation.resume() }
        }
        return Transcript(text: "too late", segments: [])
    }
}

private final class FileTranscriber: MemoTranscribing, @unchecked Sendable {
    let analyzerFormat: AVAudioFormat? = nil
    let answer: Transcript?
    private(set) var audio: URL?
    private(set) var seconds: Double?

    init(_ answer: Transcript?) {
        self.answer = answer
    }

    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool { false }
    func finish() async -> Transcript? { nil }
    func transcribeFile(_ url: URL) async -> Transcript? {
        audio = url
        // Silent: an unreadable file leaves `seconds` nil, which the test asserts on.
        seconds = (try? AVAudioFile(forReading: url)).map { Double($0.length) / $0.fileFormat.sampleRate }
        return answer
    }
}

final class VideoTranscriberTests: XCTestCase {
    private let size = CGSize(width: 360, height: 640)

    // MARK: the transcriber returns nil when the timeout passes first (D10)

    func testTranscriberTimesOut() async throws {
        let t = VideoTranscriber(core: SlowTranscriber(delay: .seconds(5)))
        let movie = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 720, height: 1280))
        let started = ContinuousClock.now
        let result = await t.transcribe(video: movie, timeout: .milliseconds(200))
        XCTAssertNil(result)
        XCTAssertLessThan(ContinuousClock.now - started, .seconds(3), "it does not wait for the transcription to end")
    }

    func testTranscribesTheVideosAudio() async throws {
        let core = FileTranscriber(Transcript(text: "hello there", segments: [
            TranscriptSegment(text: "hello", startMs: 0, endMs: 400), TranscriptSegment(text: "there", startMs: 500, endMs: 900)
        ]))
        let movie = try await TestMovie.make(seconds: 1, colour: .red, size: size)
        let result = await VideoTranscriber(core: core).transcribe(video: movie, timeout: .seconds(30))
        XCTAssertEqual(result, VideoTranscript(text: "hello there", segments: [
            VideoTranscriptSegment(text: "hello", startMs: 0, endMs: 400), VideoTranscriptSegment(text: "there", startMs: 500, endMs: 900)
        ]))
        XCTAssertEqual(core.audio?.pathExtension, "m4a")
        XCTAssertEqual(try XCTUnwrap(core.seconds), 1, accuracy: 0.2)
        let audio = try XCTUnwrap(core.audio)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path), "the extracted audio is deleted")
    }

    func testNilWhenSpeechIsUnavailable() async throws {
        let movie = try await TestMovie.make(seconds: 1, colour: .red, size: size)
        let core = MemoTranscriber(availability: .unavailable)
        let result = await VideoTranscriber(core: core).transcribe(video: movie, timeout: .seconds(30))
        XCTAssertNil(result)
    }

    func testNilWhenTheVideoHasNoAudio() async throws {
        let core = FileTranscriber(Transcript(text: "x", segments: []))
        let movie = try await TestMovie.make(seconds: 1, colour: .red, size: size, audio: false)
        let result = await VideoTranscriber(core: core).transcribe(video: movie, timeout: .seconds(30))
        XCTAssertNil(result)
        XCTAssertNil(core.audio)
    }
}
