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
        // Blocker folders are made read-only; open them so cleanup can remove them.
        if let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            items.forEach { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: $0.path) }
        }
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

    func testAUserPauseIsNotResumedByALaterInterruptionEnd() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        engine.pause()
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        XCTAssertEqual(engine.state, .paused)
    }

    func testAnUnplugPauseIsNotResumedByALaterInterruptionEnd() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        center.post(name: AVAudioSession.routeChangeNotification, object: nil, userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
        XCTAssertEqual(engine.state, .paused)
    }

    func testDraftsOfAnotherEnvironmentAreHidden() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 1"); try await engine.start()
        XCTAssertEqual(drafts.recoverable().count, 1)
        XCTAssertTrue(MemoDraftStore(directory: dir, ownerUserId: "user-a", environment: "Staging").recoverable().isEmpty) // D37
    }

    /// A read-only, non-empty folder where the `.m4a` should go: the exporter cannot clear it, so the export fails.
    private func blockExport(at m4a: URL) throws {
        try FileManager.default.createDirectory(at: m4a, withIntermediateDirectories: true)
        try Data([1]).write(to: m4a.appendingPathComponent("blocker"))
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: m4a.path)
    }

    func testAFailedExportAtStopKeepsTheCafAndManifest() async throws {
        let engine = makeEngine(seconds: 0.5)
        try await engine.prepare(title: "Memo 6"); try await engine.start()
        let manifest = try XCTUnwrap(drafts.recoverable().first)
        try blockExport(at: manifest.cafURL.deletingPathExtension().appendingPathExtension("m4a"))
        do { _ = try await engine.stop(); XCTFail("export should fail") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.cafURL.path))
        XCTAssertEqual(drafts.recoverable().map(\.title), ["Memo 6"])
    }

    func testAFailedExportAtSalvageKeepsTheCafAndManifest() async throws {
        var engine: MemoRecorderEngine? = makeEngine(seconds: 1.0)
        try await engine!.prepare(title: "Memo 7"); try await engine!.start()
        engine = nil
        let manifest = try XCTUnwrap(drafts.recoverable().first)
        try blockExport(at: manifest.cafURL.deletingPathExtension().appendingPathExtension("m4a"))
        do { _ = try await drafts.salvage(manifest); XCTFail("export should fail") } catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.cafURL.path))
        XCTAssertEqual(drafts.recoverable().count, 1)
    }

    func testTheSessionIsRestoredWhenTheWriterFails() async throws {
        let spy = SpySession()
        let buffers = try MemoAudioFixtures.sineBuffers(seconds: 0.5)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        struct WriterFailure: Error {}
        let engine = MemoRecorderEngine(input: BufferFeedInput(format: format, initial: buffers), transcriber: nil,
                                        directory: dir, session: spy, drafts: drafts, notificationCenter: center,
                                        writeBuffer: { _, _ in throw WriterFailure() })
        try await engine.prepare(title: "Memo 8"); try await engine.start()
        for _ in 0..<100 where engine.state != .idle { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(spy.calls.last, "restore")
    }

    func testTheSessionIsRestoredAtTheDurationLimit() async throws {
        let spy = SpySession()
        let buffers = try MemoAudioFixtures.sineBuffers(seconds: 1.0)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 1, interleaved: false)!
        let engine = MemoRecorderEngine(input: BufferFeedInput(format: format, initial: buffers), transcriber: nil,
                                        directory: dir, maxDuration: 0.5, session: spy, drafts: drafts,
                                        notificationCenter: center)
        try await engine.prepare(title: "Memo 9"); try await engine.start()
        for _ in 0..<150 where engine.state != .idle { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(spy.calls.last, "restore")
    }
}
