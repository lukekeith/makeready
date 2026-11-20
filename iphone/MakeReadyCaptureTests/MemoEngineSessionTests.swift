//
//  MemoEngineSessionTests.swift
//  MakeReadyCaptureTests
//
//  The engine's audio-session handshake (D20), interruption handling (D16), the draft manifest
//  written at start and removed at stop, and salvage of a `.caf` whose writer never closed (D38).
//

import AVFoundation
import XCTest
@testable import MakeReady

/// Records the order of session calls; touches no real `AVAudioSession`.
final class SpySession: MemoAudioSessionControlling {
    private(set) var calls: [String] = []
    func prepareForRecording() throws { calls.append("prepare") }
    func activate() throws { calls.append("activate") }
    func restore() { calls.append("restore") }
}

@MainActor
final class MemoEngineSessionTests: XCTestCase {
    private var dir: URL!
    private var center: NotificationCenter!
    private var drafts: MemoDraftStore!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("memo-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        center = NotificationCenter()
        drafts = MemoDraftStore(directory: dir, ownerUserId: "user-a", environment: "Local")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func makeEngine(seconds: Double, session: MemoAudioSessionControlling = SpySession()) -> MemoRecorderEngine {
        let buffers = (try? MemoAudioFixtures.sineBuffers(seconds: seconds)) ?? []
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let input = BufferFeedInput(format: format, initial: buffers)
        return MemoRecorderEngine(input: input, transcriber: nil, directory: dir, session: session,
                                  drafts: drafts, notificationCenter: center)
    }

    func testSessionIsPreparedActivatedAndRestored() async throws {
        let spy = SpySession(); let engine = makeEngine(seconds: 0.5, session: spy)
        try await engine.prepare(title: "Memo 1"); try await engine.start(); _ = try await engine.stop()
        XCTAssertEqual(spy.calls, ["prepare", "activate", "restore"])
    }

    func testInterruptionPausesAndResumes() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        XCTAssertEqual(engine.state, .paused)
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        XCTAssertEqual(engine.state, .recording)
    }

    func testAnInterruptionEndedWithoutShouldResumeStaysPaused() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        XCTAssertEqual(engine.state, .paused)
    }

    func testAnUnplugPausesTheRecording() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        center.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        XCTAssertEqual(engine.state, .paused)
    }

    func testAManifestExistsWhileRecordingAndIsGoneAfterStop() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 4"); try await engine.start()
        XCTAssertEqual(drafts.recoverable().map(\.title), ["Memo 4"])
        XCTAssertTrue(MemoDraftStore(directory: dir, ownerUserId: "other", environment: "Local").recoverable().isEmpty) // D37
        _ = try await engine.stop()
        XCTAssertTrue(drafts.recoverable().isEmpty)
    }

    func testAnAbandonedCafIsSalvagedToAPlayableM4a() async throws {
        var engine: MemoRecorderEngine? = makeEngine(seconds: 1.0)
        try await engine!.prepare(title: "Memo 5"); try await engine!.start()
        engine = nil
        let manifest = try XCTUnwrap(drafts.recoverable().first)
        let out = try await drafts.salvage(manifest)
        XCTAssertEqual(try AVAudioFile(forReading: out.m4a).fileFormat.channelCount, 1)
        XCTAssertEqual(out.durationMs, 1000, accuracy: 100)
        XCTAssertEqual(out.peaks.count, Int(ceil(Double(out.durationMs) / 100)), accuracy: 1)
        XCTAssertTrue(drafts.recoverable().isEmpty)
    }
}
