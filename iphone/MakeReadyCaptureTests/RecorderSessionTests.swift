//
//  RecorderSessionTests.swift
//  MakeReadyCaptureTests
//
//  The recorder session over a real `MemoRecorderEngine` fed by a `BufferFeedInput` (never the
//  microphone): stop and Done save once, discard saves nothing, dragging leaves the engine alone.
//

import AVFoundation
import XCTest
@testable import MakeReady

@MainActor
final class RecorderSessionTests: XCTestCase {
    private var dir: URL!
    private var drafts: MemoDraftStore!
    private var engine: MemoRecorderEngine!
    private var enqueued: [RecordingResult] = []
    private var calendar: Calendar!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("recorder-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        drafts = MemoDraftStore(directory: dir, ownerUserId: "user-a", environment: "Local")
        enqueued = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        calendar.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = calendar
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(seconds: Double,
                             writeBuffer: @escaping @Sendable (AVAudioFile, AVAudioPCMBuffer) throws -> Void = { try $0.write(from: $1) }) -> RecorderSession {
        let buffers = (try? MemoAudioFixtures.sineBuffers(seconds: seconds)) ?? []
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        engine = MemoRecorderEngine(input: BufferFeedInput(format: format, initial: buffers), transcriber: nil,
                                    directory: dir, session: SpySession(), drafts: drafts, writeBuffer: writeBuffer)
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 19, minute: 43))!
        return RecorderSession(engine: engine, title: "Memo 1", enqueue: { [unowned self] result in
            enqueued.append(result)
            return Self.stubItem(for: result)
        }, now: { evening }, calendar: calendar)
    }

    private static func stubItem(for result: RecordingResult) -> MemoQueueItem {
        MemoQueueItem(localId: "local-1", fileName: "local-1.m4a", title: result.title, durationMs: result.durationMs,
                      waveformPeaks: result.waveformPeaks, recordedAt: "2026-11-21T19:43:00.000Z", transcript: nil,
                      fileSize: 1, serverId: nil, upload: nil, ownerUserId: "user-a", environment: "Local",
                      attempts: 0, nextAttemptAt: nil)
    }

    // MARK: - Tests

    func testFinishEnqueuesOneResultAndSaves() async throws {
        let session = makeSession(seconds: 1.0)
        await session.begin()
        try await Task.sleep(for: .milliseconds(200))
        await session.finish()
        XCTAssertEqual(enqueued.count, 1)
        guard case .saved = session.outcome else { return XCTFail("\(String(describing: session.outcome))") }
    }

    func testBeginStampsTheStartTime() async {
        let session = makeSession(seconds: 1.0)
        await session.begin()
        XCTAssertEqual(session.startTime, "7:43 PM")
    }

    func testDiscardEnqueuesNothing() async {
        let session = makeSession(seconds: 1.0)
        await session.begin()
        session.openMenu()
        XCTAssertEqual(session.menu, .actions)
        session.requestDiscard()
        XCTAssertEqual(session.menu, .discardConfirm)
        await session.confirmDiscard()
        XCTAssertTrue(enqueued.isEmpty)
        XCTAssertEqual(session.outcome, .discarded)
    }

    func testMicDeniedMapsToTheMicDeniedPhase() {
        XCTAssertEqual(RecorderSession.phase(state: .idle, error: .micPermissionDenied), .micDenied)
        XCTAssertEqual(RecorderSession.phase(state: .paused, error: nil), .paused)
        XCTAssertEqual(RecorderSession.phase(state: .recording, error: .speechUnavailable), .recording)
    }

    func testDraggingNeverTouchesTheEngine() async {
        let session = makeSession(seconds: 1.0)
        await session.begin()
        session.settle(1)
        XCTAssertEqual(session.expansion, 1)
        session.settle(0)
        XCTAssertEqual(session.expansion, 0)
        XCTAssertEqual(engine.state, .recording)
    }

    func testAWriteFailureEndsFailedAndEnqueuesNothing() async throws {
        struct WriterFailure: Error {}
        let session = makeSession(seconds: 1.0, writeBuffer: { _, _ in throw WriterFailure() })
        await session.begin()
        try await Task.sleep(for: .milliseconds(300))
        session.failIfEngineFailed()
        XCTAssertEqual(session.outcome, .failed)
        XCTAssertTrue(enqueued.isEmpty)
    }

    func testTheAppRecordsInTheBackground() {
        XCTAssertTrue((Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []).contains("audio"))
    }
}
