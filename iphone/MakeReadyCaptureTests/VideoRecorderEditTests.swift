//
//  VideoRecorderEditTests.swift
//  MakeReadyCaptureTests
//
//  video-editor D7, D16, D19, D23, D27, D28: Review's Edit in `VideoRecorderModel`, over the real
//  capture engine and draft store with the camera, the players and the saver doubled.
//

import XCTest
@testable import MakeReady

/// Records what Save hands over.
@MainActor
private final class SaveRecorder: VideoSaving {
    private(set) var saves: [VideoSave] = []
    private(set) var clips: [VideoClip] = []

    func start(_ save: VideoSave, of clip: VideoClip) throws -> Task<Void, Never> {
        saves.append(save)
        clips.append(clip)
        return Task {}
    }
}

@MainActor
final class VideoRecorderEditTests: XCTestCase {
    private var dir: URL!
    private var drafts: VideoDraftStore!
    private var session: FakeCaptureSession!
    private var player: ReviewPlayerSpy!
    private var editorPlayer: ReviewPlayerSpy!
    private var saver: SaveRecorder!
    private var reports: [String] = []
    private var suiteName: String!
    private let lesson = VideoRecorderEntry.lesson(versionId: "ver1", activityId: nil)
    private let layers = [VideoLayer(kind: .text, text: "Title", startMs: 0, endMs: 3000)]

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoRecorderEditTests-\(UUID().uuidString)")
        drafts = VideoDraftStore(root: dir.appendingPathComponent("drafts"))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        session = FakeCaptureSession()
        player = ReviewPlayerSpy()
        editorPlayer = ReviewPlayerSpy()
        saver = SaveRecorder()
        reports = []
        suiteName = "VideoRecorderEditTests-\(UUID().uuidString)"
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try FileManager.default.removeItem(at: dir)
    }

    private var tmpURL: URL {
        let url = dir.appendingPathComponent("\(UUID().uuidString).mov")
        FileManager.default.createFile(atPath: url.path, contents: Data([1]))
        return url
    }

    private func model(entry: VideoRecorderEntry = .plusMenu, editorFails: Bool = false) -> VideoRecorderModel {
        let editorPlayer = editorPlayer!
        return VideoRecorderModel(
            entry: entry,
            engine: VideoCaptureEngine(session: session, drafts: drafts, freeBytes: { nil }, notificationCenter: NotificationCenter()),
            settings: RecorderSettings(defaults: UserDefaults(suiteName: suiteName)!),
            player: player, saver: saver, recoverDraft: { [drafts] in drafts!.recoverable().last }, beep: { _ in },
            report: { [weak self] _, message in self?.reports.append(message) }, loadNotes: {},
            makeEditor: { clip, layers, transcript, save in
                if editorFails { throw VideoExportError.nothingToExport }
                return VideoEditorModel(clip: clip, layers: layers, transcript: transcript, player: editorPlayer,
                                        transcribe: { nil }, save: save, report: { _ in })
            },
            now: { 0 })
    }

    /// Records 4 s, calls `done` and lets the engine and the player settle.
    private func inReview(_ m: VideoRecorderModel) async {
        m.recordTapped(); m.tick(recorded: 4); m.recordTapped()
        m.done()
        await m.settled()
        await m.playerSettled()
    }

    /// A lesson's import of `duration` s, kept to `window`, in Review.
    private func imported(_ m: VideoRecorderModel, duration: TimeInterval = 300, window: ClosedRange<Double>? = 10...100) async {
        m.imported(url: tmpURL, duration: duration)
        if let window { m.trimmed(range: window) }
        await m.settled()
        await m.playerSettled()
    }

    // MARK: an edit reaches Review, the draft and Save, and Edit resumes it (D7, D16, D27)

    func testEditARecording() async throws {
        let m = model(); await inReview(m); XCTAssertTrue(m.canEdit)
        await m.editTapped(); XCTAssertFalse(m.canEdit); XCTAssertEqual(player.stops, 1)
        m.editor?.textTapped(); m.editor?.commitText("Title", style: .standard); m.editor?.doneTapped()
        XCTAssertEqual(player.shownLayers.last?.map(\.text), ["Title"])
        m.editorHidden(); XCTAssertNil(m.editor)
        await m.editTapped(); XCTAssertEqual(m.editor?.session.layers.map(\.text), ["Title"])
        m.editor?.cancelTapped(); m.editorHidden()
        await m.save()
        guard case let .draft(draft)? = saver.clips.first else { return XCTFail("a draft") }
        XCTAssertEqual(drafts.current(draft)?.layers.map(\.text), ["Title"])
    }

    // MARK: the first Edit on an import moves it into a draft that saves as imported (D19)

    func testEditAnImport() async throws {
        let m = model(entry: lesson); await imported(m)
        await m.editTapped(); m.editor?.doneTapped(); m.editorHidden()
        let plain = model(entry: lesson); await imported(plain, duration: 10, window: nil)
        let draft = try XCTUnwrap(drafts.recoverable(for: lesson).first)
        XCTAssertEqual(draft.source, .imported); XCTAssertEqual(draft.window, 10...100)
        XCTAssertEqual(m.importedClip?.url, draft.segments[0].url); XCTAssertEqual(m.screenState.segments, [])
        await m.save()
        XCTAssertEqual(saver.saves.last?.source, .imported); XCTAssertEqual(saver.saves.last?.window, 10...100)
        guard case .draft? = saver.clips.last else { return XCTFail("a draft") }
        await plain.save()
        guard case .file? = saver.clips.last else { return XCTFail("a file") }
    }

    // MARK: a kill mid-edit comes back to Review; Retake clears it (D16, D19)

    func testRecovery() async throws {
        let base = try drafts.finalize(segment: tmpURL, duration: 4, in: drafts.begin())
        let plain = model(); plain.open(); await plain.settled()
        XCTAssertEqual(plain.screenState.phase, .paused)
        _ = try drafts.save(layers: layers, transcript: nil, in: base)
        let m = model(); m.open(); await m.settled(); await m.playerSettled()
        XCTAssertEqual(m.screenState.phase, .review); XCTAssertEqual(m.layers, layers); XCTAssertEqual(player.shownLayers.last, layers)
        drafts.discard(base)
        let adopted = try drafts.adopt(imported: tmpURL, duration: 300, window: 10...100, settings: VideoDraftSettings())
        XCTAssertEqual(adopted.source, .imported)
        let n = model(); n.open(); await n.settled(); await n.playerSettled()
        XCTAssertEqual(n.screenState.phase, .review); XCTAssertEqual(n.screenState.segments, [])
        XCTAssertEqual(n.trimWindow, 10...100); XCTAssertEqual(n.importedClip?.duration, 300)
        n.retakeConfirmed(); await n.settled()
        XCTAssertNil(n.importedClip); XCTAssertEqual(drafts.recoverable(), [])
    }

    // MARK: opening fails loudly, a failed write is silent, at Save it is reported (D19, D23, D27, D28)

    func testFailuresAndBackground() async throws {
        let m = model(editorFails: true); await inReview(m)
        await m.editTapped()
        XCTAssertNil(m.editor); XCTAssertEqual(reports, ["Couldn't open the editor"]); XCTAssertEqual(m.screenState.phase, .review)
        let n = model(); await inReview(n)
        await n.editTapped(); n.editor?.playTapped()
        XCTAssertEqual(n.editor?.isPlaying, true)
        let plays = player.plays
        reports = []; n.backgrounded(); n.becameActive()
        XCTAssertEqual(n.editor?.isPlaying, false); XCTAssertEqual(player.plays, plays)
        for draft in drafts.recoverable() { try FileManager.default.removeItem(at: draft.folder) }
        n.editor?.textTapped(); n.editor?.commitText("T", style: .standard)
        XCTAssertEqual(reports, []); XCTAssertEqual(n.layers.count, 1)
        n.editor?.doneTapped(); n.editorHidden(); await n.save()
        XCTAssertEqual(reports, ["Couldn't save your video"]); XCTAssertFalse(n.isClosed)
    }
}
