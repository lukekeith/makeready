//
//  VideoCaptureEngineTests.swift
//  MakeReadyCaptureTests
//
//  The capture engine's non-camera logic (video-recorder D6, D19, D26) through a fake session.
//

import AVFoundation
import CoreImage
import UIKit
import XCTest
@testable import MakeReady

@MainActor
final class VideoCaptureEngineTests: XCTestCase {
    private var dir: URL!
    private var store: VideoDraftStore!
    private var session: FakeCaptureSession!
    private var center: NotificationCenter!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoCaptureEngineTests-\(UUID().uuidString)")
        store = VideoDraftStore(root: dir)
        session = FakeCaptureSession()
        center = NotificationCenter()
    }

    override func tearDown() async throws {
        // Silent: a test that never began a draft has no folder.
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeEngine(freeBytes: Int64? = 1_000_000_000) -> VideoCaptureEngine {
        VideoCaptureEngine(session: session, drafts: store, freeBytes: { freeBytes }, notificationCenter: center)
    }

    // MARK: an interruption ends the segment and pauses, never resuming (D26)

    func testInterruptionPauses() async throws {
        let engine = VideoCaptureEngine(session: FakeCaptureSession(), drafts: store, freeBytes: { 1_000_000_000 })
        try await engine.start()
        engine.handleInterruption(began: true)
        XCTAssertEqual(engine.state, .paused)
        engine.handleInterruption(began: false)
        XCTAssertEqual(engine.state, .paused)
    }

    func testInterruptionFinalizesTheSegment() async throws {
        let engine = makeEngine()
        var interruptions = 0
        engine.onInterrupted = { interruptions += 1 }
        try await engine.start()
        engine.handleInterruption(began: true)
        await engine.stopSegment()
        XCTAssertEqual(store.recoverable().first?.segments.map(\.duration), [3])
        XCTAssertEqual(interruptions, 1)
        XCTAssertEqual(session.recordings.count, 1)
    }

    func testInterruptionWithNothingRecordingChangesNothing() async throws {
        let engine = makeEngine()
        try await engine.prepare()
        engine.onInterrupted = { XCTFail("no segment was interrupted") }
        engine.handleInterruption(began: true)
        XCTAssertEqual(engine.state, .ready)
    }

    func testEverySystemInterruptionPauses() async throws {
        let engine = makeEngine()
        let posts: [(Notification.Name, [AnyHashable: Any]?)] = [
            (AVCaptureSession.wasInterruptedNotification, nil),
            (AVCaptureSession.runtimeErrorNotification, nil),
            (UIApplication.didEnterBackgroundNotification, nil),
            (AVAudioSession.interruptionNotification,
             [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        ]
        for (name, info) in posts {
            try await engine.start()
            XCTAssertEqual(engine.state, .recording, name.rawValue)
            center.post(name: name, object: nil, userInfo: info)
            XCTAssertEqual(engine.state, .paused, name.rawValue)
        }
        center.post(name: AVAudioSession.interruptionNotification, object: nil,
                    userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        XCTAssertEqual(engine.state, .paused)
    }

    func testRecordingEndedByTheSystemPausesAndKeepsTheSegment() async throws {
        let engine = makeEngine()
        var interrupted = false
        engine.onInterrupted = { interrupted = true }
        try await engine.start()
        session.stopRecording()
        XCTAssertEqual(engine.state, .paused)
        XCTAssertTrue(interrupted)
        XCTAssertEqual(engine.draft?.segments.count, 1)
    }

    // MARK: deleting the last segment, discarding and restoring (D5, D9, D26)

    func testDeleteLastSegmentReturnsToReadyWhenNoneIsLeft() async throws {
        let engine = makeEngine()
        try await engine.start()
        await engine.stopSegment()
        try engine.deleteLastSegment()
        XCTAssertEqual(engine.draft?.segments, [])
        XCTAssertEqual(engine.state, .ready)
        XCTAssertEqual(store.recoverable(), [])
    }

    func testDiscardDraftLeavesNothingOnDisk() async throws {
        let engine = makeEngine()
        try await engine.start()
        await engine.stopSegment()
        engine.discardDraft()
        XCTAssertNil(engine.draft)
        XCTAssertEqual(engine.state, .ready)
        XCTAssertEqual(store.recoverable(), [])
    }

    func testRestoredDraftTakesTheNextSegment() async throws {
        let first = makeEngine()
        try await first.start()
        await first.close()
        let engine = makeEngine()
        engine.restore(try XCTUnwrap(store.recoverable().first))
        try await engine.prepare()
        XCTAssertEqual(engine.state, .paused)
        try await engine.start()
        await engine.stopSegment()
        XCTAssertEqual(store.recoverable().first?.segments.count, 2)
    }

    func testSettingsAreSavedInTheDraft() async throws {
        let engine = makeEngine()
        engine.save(settings: VideoDraftSettings(lengthSeconds: 30))
        XCTAssertEqual(store.recoverable(), [])
        try await engine.start()
        engine.save(settings: VideoDraftSettings(lengthSeconds: 30))
        await engine.stopSegment()
        XCTAssertEqual(store.recoverable().first?.settings.lengthSeconds, 30)
    }

    // MARK: under 500 MB free, recording refuses to start (D26)

    func testLowDiskSpaceRefusesToStart() async throws {
        let engine = makeEngine(freeBytes: 499_999_999)
        do {
            try await engine.start()
            XCTFail("start should refuse")
        } catch {
            XCTAssertEqual(error as? VideoCaptureError, .lowDiskSpace)
        }
        XCTAssertNotEqual(engine.state, .recording)
        XCTAssertEqual(session.recordings, [])
    }

    func testExactlyTheMinimumStarts() async throws {
        let engine = makeEngine(freeBytes: VideoCaptureEngine.minimumFreeBytes)
        try await engine.start()
        XCTAssertEqual(engine.state, .recording)
    }

    // MARK: permissions are asked on first use (D19)

    func testNothingIsAskedBeforeStart() async throws {
        let engine = makeEngine()
        XCTAssertEqual(session.asked, [])
        try await engine.start()
        XCTAssertEqual(session.asked, [.camera, .microphone])
    }

    func testDeniedPermission() async throws {
        for permission in [CapturePermission.camera, .microphone] {
            session = FakeCaptureSession()
            session.denied = [permission]
            let engine = makeEngine()
            try await engine.start()
            XCTAssertEqual(engine.state, .denied(permission))
            XCTAssertEqual(session.recordings, [])
            XCTAssertFalse(session.isOpen)
        }
    }

    // MARK: segments

    func testEachStartRecordsItsOwnFileIntoOneDraft() async throws {
        let engine = makeEngine()
        try await engine.start()
        await engine.stopSegment()
        XCTAssertEqual(engine.state, .paused)
        try await engine.start()
        await engine.stopSegment()
        XCTAssertEqual(engine.draft?.segments.map(\.duration), [3, 3])
        XCTAssertEqual(Set(session.recordings).count, 2)
        XCTAssertEqual(store.recoverable().count, 1)
    }

    func testFailedSegmentIsNotKept() async throws {
        let engine = makeEngine()
        try await engine.start()
        session.failure = VideoCaptureError.recordingFailed
        await engine.stopSegment()
        XCTAssertEqual(engine.state, .ready)
        XCTAssertEqual(engine.lastError as? VideoCaptureError, .recordingFailed)
        XCTAssertEqual(engine.draft?.segments, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: session.recordings[0].path))
    }

    func testStartAfterDiscardBeginsANewDraft() async throws {
        let engine = makeEngine()
        try await engine.start()
        await engine.stopSegment()
        let first = try XCTUnwrap(engine.draft)
        store.discard(first)
        try await engine.start()
        XCTAssertNotEqual(engine.draft?.id, first.id)
    }

    // MARK: preview, flip and close

    func testPrepareOpensThePreviewWithoutRecording() async throws {
        let engine = makeEngine()
        try await engine.prepare()
        XCTAssertEqual(engine.state, .ready)
        XCTAssertTrue(session.isOpen)
        XCTAssertEqual(session.recordings, [])
    }

    func testFilterReachesThePreview() {
        let engine = makeEngine()
        let filter = CIFilter(name: "CIPhotoEffectMono")
        engine.previewFilter = filter
        XCTAssertTrue(session.previewFilter === filter)
    }

    func testFlipOnlyBetweenSegments() async throws {
        let engine = makeEngine()
        try await engine.start()
        engine.flip()
        XCTAssertEqual(session.flips, 0)
        await engine.stopSegment()
        engine.flip()
        XCTAssertEqual(session.flips, 1)
    }

    func testCloseFinalizesTheSegmentAndReleasesTheCamera() async throws {
        let engine = makeEngine()
        try await engine.start()
        await engine.close()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertFalse(session.isOpen)
        XCTAssertEqual(store.recoverable().first?.segments.count, 1)
    }

    func testCloseWhileThePermissionIsAskedLeavesTheCameraOff() async throws {
        let engine = makeEngine()
        session.onAsk = { await engine.close() }
        try await engine.start()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertFalse(session.isOpen)
        XCTAssertEqual(session.recordings, [])
    }
}

@MainActor
private final class FakeCaptureSession: VideoCaptureSession {
    let displayLayer = CALayer()
    var denied: Set<CapturePermission> = []
    var failure: Error?
    var onAsk: (() async -> Void)?
    private(set) var asked: [CapturePermission] = []
    private(set) var isOpen = false
    private(set) var recordings: [URL] = []
    private(set) var flips = 0
    var previewFilter: CIFilter?
    private var onFinish: ((Result<TimeInterval, Error>) -> Void)?

    func requestAccess(_ permission: CapturePermission) async -> Bool {
        asked.append(permission)
        await onAsk?()
        return !denied.contains(permission)
    }

    func open() async throws { isOpen = true }

    func close() { isOpen = false }

    func startRecording(to url: URL, onFinish: @escaping @MainActor (Result<TimeInterval, Error>) -> Void) {
        recordings.append(url)
        FileManager.default.createFile(atPath: url.path, contents: Data([1]))
        self.onFinish = onFinish
    }

    func stopRecording() {
        let finish = onFinish
        onFinish = nil
        if let failure { finish?(.failure(failure)) } else { finish?(.success(3)) }
    }

    func flip() { flips += 1 }
}
