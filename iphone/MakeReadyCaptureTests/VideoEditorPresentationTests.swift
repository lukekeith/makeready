//
//  VideoEditorPresentationTests.swift
//  MakeReadyCaptureTests
//
//  video-editor D10, D29: the editor is handed up where something hosts, drawn in place where nothing
//  does, and dropped once it has slid out.
//

import SwiftUI
import XCTest
@testable import MakeReady

@MainActor
private final class NullSaver: VideoSaving {
    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never> { Task {} }
}

@MainActor
final class VideoEditorPresentationTests: XCTestCase {
    private var dir: URL!
    private var windows: [UIWindow] = []

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoEditorPresentationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        windows.forEach { $0.isHidden = true }
        windows = []
        try FileManager.default.removeItem(at: dir)
    }

    /// A recorder in Review (a 4 s recording on the fake camera) whose editor is a real one on a spy player.
    private func reviewModel() async -> VideoRecorderModel {
        let drafts = VideoDraftStore(root: dir.appendingPathComponent("drafts"))
        let editorPlayer = ReviewPlayerSpy()
        let m = VideoRecorderModel(
            entry: .plusMenu,
            engine: VideoCaptureEngine(session: FakeCaptureSession(), drafts: drafts, freeBytes: { nil }, notificationCenter: NotificationCenter()),
            settings: RecorderSettings(defaults: UserDefaults(suiteName: "VideoEditorPresentationTests-\(UUID().uuidString)")!),
            player: ReviewPlayerSpy(), saver: NullSaver(), recoverDraft: { nil }, beep: { _ in },
            report: { _, _ in }, loadNotes: {},
            makeEditor: { clip, layers, transcript, save in
                VideoEditorModel(clip: clip, layers: layers, transcript: transcript, player: editorPlayer,
                                 transcribe: { nil }, save: save, report: { _ in })
            },
            now: { 0 })
        m.recordTapped(); m.tick(recorded: 4); m.recordTapped()
        m.done()
        await m.settled()
        await m.playerSettled()
        return m
    }

    /// Puts `view` in a window and lets SwiftUI settle.
    private func show(_ view: some View) {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        window.rootViewController = host
        window.isHidden = false
        windows.append(window)
        settle(host)
    }

    private func settle(_ host: UIViewController? = nil) {
        for _ in 0..<5 {
            host?.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
    }

    /// Polls every 20 ms for at most 5 s.
    private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<250 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("timed out")
    }

    private final class Seen { var overlay = false }

    /// Whether the editor reaches `UI2HostedOverlayKey` with Edit open, under `ui2HostsOverlays == hosted`.
    private func handedUp(_ hosted: Bool) async throws -> Bool {
        let m = await reviewModel()
        let seen = Seen()
        show(Color.clear
            .videoEditorPresentation(model: m)
            .environment(\.ui2HostsOverlays, hosted)
            .overlayPreferenceValue(UI2HostedOverlayKey.self) { overlay in
                Color.clear.onChange(of: overlay != nil, initial: true) { _, handed in seen.overlay = handed }
            })
        await m.editTapped()
        try await until { m.editor != nil }
        settle()
        return seen.overlay
    }

    func testPlacement() async throws {
        for hosted in [false, true] {
            let up = try await handedUp(hosted)
            XCTAssertEqual(up, hosted)
        }
    }

    func testHiddenAfterDone() async throws {
        let m = await reviewModel()
        show(Color.clear.videoEditorPresentation(model: m).environment(\.ui2HostsOverlays, false))
        await m.editTapped()
        let editor = try XCTUnwrap(m.editor)
        settle()
        editor.doneTapped()
        try await until { m.editor == nil }
        XCTAssertFalse(m.isClosed)
        XCTAssertEqual(m.screenState.phase, .review)
    }
}
