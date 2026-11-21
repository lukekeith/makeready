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
    private var drafts: MemoDraftStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("memo-engine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        drafts = MemoDraftStore(directory: dir, ownerUserId: "user-a", environment: "Local")
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
        let engine = MemoRecorderEngine(input: input, transcriber: transcriber, directory: dir, maxDuration: maxDuration,
                                  session: SpySession(), drafts: drafts)
        return (engine, input)
    }

    private struct WriterFailure: Error {}

    /// `seconds` of the fixture tone as 48 kHz stereo buffers (the same tone in both channels).
    private func stereo48kBuffers(seconds: Double) throws -> [AVAudioPCMBuffer] {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                                 channels: 2, interleaved: false))
        return try MemoAudioFixtures.sineBuffers(seconds: seconds, sampleRate: 48_000).map { mono in
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: mono.frameLength))
            buffer.frameLength = mono.frameLength
            for channel in 0..<2 {
                let destination = try XCTUnwrap(buffer.floatChannelData?[channel])
                destination.update(from: try XCTUnwrap(mono.floatChannelData?[0]), count: Int(mono.frameLength))
            }
            return buffer
        }
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

    func testAFailingWriterSetsWriteFailedStopsTheInputAndGoesIdle() async throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false))
        let input = BufferFeedInput(format: format)
        let engine = MemoRecorderEngine(input: input, transcriber: nil, directory: dir,
                                        session: SpySession(), drafts: drafts,
                                        writeBuffer: { _, _ in throw WriterFailure() })
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        try input.feed(MemoAudioFixtures.sineBuffers(seconds: 0.5))
        for _ in 0..<100 where engine.state != .idle { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(engine.lastError, .writeFailed)
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(input.stopCount, 1)
    }

    func testNonStandardInputFormatIsConvertedToMono44k() async throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false))
        let input = BufferFeedInput(format: format, initial: try stereo48kBuffers(seconds: 2.0))
        let engine = MemoRecorderEngine(input: input, transcriber: nil, directory: dir,
                                        session: SpySession(), drafts: drafts)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        let r = try await engine.stop()
        XCTAssertEqual(r.durationMs, 2000, accuracy: 50)
        XCTAssertEqual(r.waveformPeaks.count, Int(ceil(Double(r.durationMs) / 100)))
        XCTAssertEqual(try AVAudioFile(forReading: r.fileURL).fileFormat.channelCount, 1)
    }

    func testLevelSamplesRingCapsAtTwoHundred() async throws {
        let long = makeEngine(seconds: 12.0)   // 240 level values written, 200 kept
        try await long.prepare(title: "Memo 1"); try await long.start()
        _ = try await long.stop()
        XCTAssertEqual(long.samples.count, 200)
        let short = makeEngine(seconds: 1.0)   // 44 100 / 2 205 = 20 values
        try await short.prepare(title: "Memo 2"); try await short.start()
        _ = try await short.stop()
        XCTAssertEqual(short.samples.count, 20)
    }

    func testPartialLastPeakBucketIsCounted() async throws {
        let engine = makeEngine(seconds: 0.55)   // 24 255 frames = 5.5 buckets of 4 410
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        let r = try await engine.stop()
        XCTAssertEqual(r.waveformPeaks.count, Int(ceil(24_255.0 / 4_410.0)))
        XCTAssertEqual(r.waveformPeaks.count, 6)
    }

    func testDiscardLeavesNoCafNoM4aAndNoDraft() async throws {
        let engine = makeEngine(seconds: 1.0)
        try await engine.prepare(title: "Memo 1")
        try await engine.start()
        try await Task.sleep(for: .milliseconds(200))
        await engine.discard()
        XCTAssertEqual(engine.state, .idle)
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(left.filter { $0.hasSuffix(".caf") || $0.hasSuffix(".m4a") }.isEmpty, "\(left)")
        XCTAssertTrue(drafts.recoverable().isEmpty)
    }

    func testDiscardWhenIdleDoesNothing() async {
        let engine = makeEngine(seconds: 0)
        await engine.discard()
        XCTAssertEqual(engine.state, .idle)
    }
}
