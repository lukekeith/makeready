//
//  MemoRecorderEngineTests.swift
//  MakeReadyCaptureTests
//
//  The capture core driven by a `BufferFeedInput`, never the microphone (F4): file format and
//  length, pause exclusion, the duration limit, and the live transcript riding on the result.
//

import AVFoundation
import Speech
import XCTest
@testable import MakeReady

/// A transcriber that counts the frames it is fed and answers a canned transcript at `finish()`,
/// after its input stream has ended.
private final class StubTranscriber: MemoTranscribing, @unchecked Sendable {
    let analyzerFormat: AVAudioFormat? = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                                       channels: 1, interleaved: false)
    private let result: Transcript?
    private let lock = NSLock()
    private var frames = 0
    private var consumer: Task<Void, Never>?

    init(result: Transcript?) { self.result = result }

    var receivedFrames: Int { lock.withLock { frames } }

    func startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool {
        let task = Task { [weak self] in
            for await input in stream { self?.lock.withLock { self?.frames += Int(input.buffer.frameLength) } }
        }
        lock.withLock { consumer = task }
        return true
    }

    func finish() async -> Transcript? {
        await lock.withLock { consumer }?.value
        return result
    }

    func transcribeFile(_ url: URL) async -> Transcript? { result }
}

@MainActor
final class MemoRecorderEngineTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("memo-engine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeEngineWithInput(seconds: Double, transcriber: MemoTranscribing? = nil,
                                     maxDuration: TimeInterval = 10_800) -> (MemoRecorderEngine, BufferFeedInput) {
        let buffers = (try? MemoAudioFixtures.sineBuffers(seconds: seconds)) ?? []
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let input = BufferFeedInput(format: format, initial: buffers)
        let engine = MemoRecorderEngine(input: input, transcriber: transcriber, directory: dir, maxDuration: maxDuration)
        return (engine, input)
    }

    private func makeEngine(seconds: Double, transcriber: MemoTranscribing? = nil) -> MemoRecorderEngine {
        makeEngineWithInput(seconds: seconds, transcriber: transcriber).0
    }

    // MARK: - Tests

    func testFixtureInputWritesAMonoAACm4aOfTheRightLength() async throws {
        let engine = makeEngine(seconds: 2.0)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        let r = try await engine.stop()
        XCTAssertEqual(r.fileURL.pathExtension, "m4a")
        XCTAssertEqual(r.waveformPeaks.count, Int(ceil(Double(r.durationMs) / 100)))
        let file = try AVAudioFile(forReading: r.fileURL)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
        XCTAssertEqual(r.durationMs, 2000, accuracy: 25)
        XCTAssertFalse(FileManager.default.fileExists(atPath: r.fileURL.deletingPathExtension().appendingPathExtension("caf").path))
    }

    func testPauseExcludesPausedAudioAndKeepsOneFile() async throws {
        let (engine, input) = makeEngineWithInput(seconds: 1.0)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        engine.pause(); try input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.0))
        try engine.resume(); try input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.0))
        let r = try await engine.stop()
        XCTAssertEqual(r.durationMs, 2000, accuracy: 25)
        XCTAssertEqual(r.waveformPeaks.count, 20, accuracy: 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".m4a") }.count, 1)
    }

    func testDurationLimitStopsWithTheMemoIntact() async throws {
        let (engine, input) = makeEngineWithInput(seconds: 0, maxDuration: 1.0)
        let delivered = expectation(description: "auto stop"); var result: RecordingResult?
        engine.onAutoStop = { result = $0; delivered.fulfill() }
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        try input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.5))
        await fulfillment(of: [delivered], timeout: 5)
        XCTAssertEqual(engine.lastError, .durationLimitReached)
        XCTAssertEqual(result?.durationMs ?? 0, 1000, accuracy: 100)
    }

    func testLiveTranscriptRidesOnTheResult() async throws {
        let stub = StubTranscriber(result: Transcript(text: "hello", segments: []))
        let engine = makeEngine(seconds: 1.0, transcriber: stub)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        let r = try await engine.stop()
        XCTAssertEqual(r.transcript?.text, "hello")
        XCTAssertGreaterThan(stub.receivedFrames, 0)
    }
}
