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
@testable import MakeReadyUI

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
    @discardableResult
    private func show(_ view: some View, size: CGSize = CGSize(width: 440, height: 956)) -> UIViewController {
        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        windows.append(window)
        settle(host)
        return host
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

    // MARK: - Hosted by a real shell host (D10)

    /// Opens Edit under a real `.ui2OverlayHost()`, ends it with `end`, and returns whether the hosted
    /// overlay was on screen before and is gone after.
    private func hostedRoundTrip(_ m: VideoRecorderModel, end: (VideoEditorModel) -> Void) async throws -> (up: Bool, gone: Bool) {
        let seen = Seen()
        show(Color.clear
            .videoEditorPresentation(model: m)
            .ui2OverlayHost()
            .overlayPreferenceValue(UI2HostedOverlayKey.self) { overlay in
                Color.clear.onChange(of: overlay != nil, initial: true) { _, handed in seen.overlay = handed }
            })
        await m.editTapped()
        let editor = try XCTUnwrap(m.editor)
        try await until { seen.overlay }
        settle()
        end(editor)
        try await until { m.editor == nil }
        settle()
        return (true, !seen.overlay)
    }

    func testHostedDoneReturnsToTheSameReview() async throws {
        let m = await reviewModel()
        let result = try await hostedRoundTrip(m) { $0.doneTapped() }
        XCTAssertTrue(result.up)
        XCTAssertTrue(result.gone)
        XCTAssertNil(m.editor)
        XCTAssertFalse(m.isClosed)
        XCTAssertEqual(m.screenState.phase, .review)
    }

    func testHostedCancelReturnsToTheSameReview() async throws {
        let m = await reviewModel()
        let result = try await hostedRoundTrip(m) { $0.cancelTapped() }
        XCTAssertTrue(result.up)
        XCTAssertTrue(result.gone)
        XCTAssertNil(m.editor)
        XCTAssertFalse(m.isClosed)
        XCTAssertEqual(m.screenState.phase, .review)
    }

    // MARK: - The keyboard lifts the text tool (D8)

    private static let safeBottom: CGFloat = 34
    private static let keyboard = CGRect(x: 0, y: 620, width: 440, height: 336)

    private func postKeyboard(_ name: Notification.Name, _ frame: CGRect) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: frame, UIResponder.keyboardAnimationDurationUserInfoKey: 0.0
        ])
    }

    /// `settle`, giving the main queue back so that state set by a notification is drawn.
    private func settled(_ host: UIViewController) async throws {
        for _ in 0..<5 {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
        }
        host.view.layoutIfNeeded()
    }

    /// Opens Edit's text tool under `host` and raises, then hides, a keyboard.
    private func assertKeyboardLiftsTheTool(
        under host: (AnyView) -> AnyView, file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let m = await reviewModel()
        let map = UI2ElementMap()
        let content = AnyView(Color.clear.ignoresSafeArea(.container, edges: .bottom).videoEditorPresentation(model: m))
        let controller = show(host(content)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ui2ElementMap(map))
        controller.additionalSafeAreaInsets.bottom = Self.safeBottom
        // The backdrop fills the editor, which ends at the bottom safe area. Measuring up from there
        // leaves out the slide-in, whose effect an anchor may still carry here.
        func rect(_ name: String) throws -> CGRect {
            func raw(_ name: String) throws -> CGRect {
                try XCTUnwrap(map.elements.first { $0.name == name }?.rect, name, file: file, line: line)
            }
            return try raw(name).offsetBy(dx: 0, dy: 956 - Self.safeBottom - raw("Text tool backdrop").maxY)
        }
        await m.editTapped()
        try await until { m.editor != nil }
        m.editor?.textTapped()
        try await settled(controller)
        postKeyboard(UIResponder.keyboardWillHideNotification, CGRect(x: 0, y: 956, width: 440, height: 336))
        try await settled(controller)
        let rowDown = try rect("Tool row"), preview = try rect("Preview"), backdrop = try rect("Text tool backdrop")

        postKeyboard(UIResponder.keyboardWillChangeFrameNotification, Self.keyboard)
        try await settled(controller)
        XCTAssertEqual(try rect("Tool row").maxY, Self.keyboard.minY - 16, accuracy: 0.5, file: file, line: line)
        XCTAssertEqual(try rect("Preview"), preview, "the column does not move", file: file, line: line)
        XCTAssertEqual(try rect("Text tool backdrop"), backdrop, "the backdrop stays full screen", file: file, line: line)

        postKeyboard(UIResponder.keyboardWillHideNotification, CGRect(x: 0, y: 956, width: 440, height: 336))
        try await settled(controller)
        XCTAssertEqual(try rect("Tool row"), rowDown, file: file, line: line)
    }

    func testKeyboardLiftsTheHostedTextTool() async throws {
        try await assertKeyboardLiftsTheTool { content in
            AnyView(content
                .ignoresSafeArea(.container, edges: .bottom)
                .ui2OverlayHost()
                .ignoresSafeArea(.keyboard, edges: .bottom))
        }
    }

    func testKeyboardLiftsTheTextToolInPlace() async throws {
        try await assertKeyboardLiftsTheTool { content in
            AnyView(content.environment(\.ui2HostsOverlays, false).ignoresSafeArea(.keyboard))
        }
    }

    // MARK: - Review's row fit (F8)

    private final class Widths { var offered: CGFloat = 0 }

    /// The width the screen offers Review's slot beside Edit and Filters at `width`, and the natural
    /// width of the real Retake + Save content.
    private func slotFit(width: CGFloat, layout: VideoRecorderScreen.State.Layout) async -> (offered: CGFloat, natural: CGFloat) {
        let m = await reviewModel()
        let widths = Widths()
        show(VideoRecorderScreen(
            state: .init(layout: layout, phase: .review, segments: [4]),
            reviewSlot: {
                AnyView(VideoReviewActions(model: m)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths.offered = $0 })
            },
            onEdit: {}
        ), size: CGSize(width: width, height: 956))
        let natural = UIHostingController(rootView: VideoReviewActions(model: m).fixedSize())
            .sizeThatFits(in: CGSize(width: 10_000, height: 100)).width
        return (widths.offered, natural)
    }

    func testReviewRowFitsAt440() async throws {
        let fit = await slotFit(width: 440, layout: .fullScreen)
        XCTAssertGreaterThan(fit.offered, 0)
        XCTAssertLessThanOrEqual(fit.natural, fit.offered)
    }

    func testReviewRowFitsAtTheLessonsInlineWidth() async throws {
        let fit = await slotFit(width: 343, layout: .lessonInline)
        XCTAssertGreaterThan(fit.offered, 0)
        XCTAssertLessThanOrEqual(fit.natural, fit.offered)
    }

    // MARK: a track above the filmstrip takes its touches (D3)

    /// Whether a touch at `point` reaches the timeline's track list, with one row and these frames.
    private func touchReachesTracks(_ point: CGPoint, frames: [Image]) throws -> Bool {
        let host = show(VideoEditorTimeline(playing: false, playheadMs: 0, durationMs: 30_000, filmstrip: frames) {
            Color.red.frame(height: 44).contentShape(Rectangle()).onTapGesture {}
        }.ignoresSafeArea(), size: CGSize(width: 440, height: 267))
        let hit = try XCTUnwrap(host.view.hitTest(point, with: nil))
        return sequence(first: hit, next: \.superview).contains { $0 is UIScrollView }
    }

    func testFilmstripLeavesTheTracksTheirTouches() throws {
        // A portrait frame in a wide slot overflows it above and below; clipping hides that, not its touches.
        let frame = Image(uiImage: UIGraphicsImageRenderer(size: CGSize(width: 135, height: 240)).image { _ in })
        let frames = Array(repeating: frame, count: 10)
        // The row is y 48–92, under the 44 pt header and its 4 pt gap; the filmstrip follows it.
        for y in [52.0, 70, 88] {
            let point = CGPoint(x: 300, y: y)
            XCTAssertTrue(try touchReachesTracks(point, frames: []), "no frames, y \(y)")
            XCTAssertTrue(try touchReachesTracks(point, frames: frames), "frames, y \(y)")
        }
        XCTAssertFalse(try touchReachesTracks(CGPoint(x: 300, y: 130), frames: frames))
    }
}
