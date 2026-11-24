//
//  VideoDraftStoreTests.swift
//  MakeReadyCaptureTests
//
//  The recorder's crash-safe drafts (video-recorder D26): what a relaunch keeps and drops.
//

import XCTest
@testable import MakeReady

final class VideoDraftStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("VideoDraftStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data([1]).write(to: url)
        return url
    }

    // MARK: salvage keeps finished segments and drops an unfinished file (D26)

    func testSalvageKeepsOnlyFinishedSegments() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        let done = dir.appendingPathComponent("s1.mov"); try Data([1]).write(to: done)
        try store.finalize(segment: done, duration: 4, in: draft)
        try Data([2]).write(to: draft.folder.appendingPathComponent("s2.mov"))
        let recovered = VideoDraftStore(root: dir).recoverable()
        XCTAssertEqual(recovered.first?.segments.map(\.duration), [4])
        XCTAssertFalse(FileManager.default.fileExists(atPath: draft.folder.appendingPathComponent("s2.mov").path))
    }

    func testSegmentsKeepTheirOrderAndFiles() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        // The same stale `draft` both times: the manifest on disk is the truth.
        try store.finalize(segment: try write("b.mov"), duration: 4, in: draft)
        let updated = try store.finalize(segment: try write("a.mov"), duration: 2, in: draft)
        XCTAssertEqual(updated.segments.map(\.duration), [4, 2])

        let recovered = VideoDraftStore(root: dir).recoverable()
        XCTAssertEqual(recovered.first?.segments, updated.segments)
        XCTAssertTrue(updated.segments.allSatisfy { FileManager.default.fileExists(atPath: $0.url.path) })
    }

    func testDraftWithNoFinishedSegmentIsDeleted() throws {
        let draft = VideoDraftStore(root: dir).begin()
        try Data([2]).write(to: draft.folder.appendingPathComponent("s1.mov"))
        XCTAssertEqual(VideoDraftStore(root: dir).recoverable(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: draft.folder.path))
    }

    func testMissingSegmentFileIsDropped() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft)
        let updated = try store.finalize(segment: try write("s2.mov"), duration: 2, in: draft)
        try FileManager.default.removeItem(at: updated.segments[0].url)
        XCTAssertEqual(store.recoverable().first?.segments.map(\.duration), [2])
    }

    func testDraftSurvivesAMovedContainer() throws {
        let store = VideoDraftStore(root: dir)
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: store.begin())
        let moved = dir.appendingPathExtension("moved")
        try FileManager.default.moveItem(at: dir, to: moved)
        dir = moved
        let segment = try XCTUnwrap(VideoDraftStore(root: moved).recoverable().first?.segments.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: segment.url.path))
    }

    func testSettingsSurvive() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        let settings = VideoDraftSettings(lengthSeconds: 30, filter: "mono", filterStrength: 40)
        try store.save(settings: settings, in: draft)
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft)
        XCTAssertEqual(VideoDraftStore(root: dir).recoverable().first?.settings, settings)
    }

    /// video-recorder D18: a lesson's draft comes back only where it was recorded.
    func testADraftIsRecoverableOnlyForTheEntryItWasRecordedFrom() throws {
        let store = VideoDraftStore(root: dir)
        let lesson = VideoRecorderEntry.lesson(versionId: "ver1", activityId: nil)
        func record(_ name: String, entry: VideoRecorderEntry?) throws -> UUID {
            let draft = store.begin()
            try store.save(settings: VideoDraftSettings(entry: entry), in: draft)
            return try store.finalize(segment: try write(name), duration: 4, in: draft).id
        }
        let plus = try record("s1.mov", entry: nil)
        let inLesson = try record("s2.mov", entry: lesson)
        XCTAssertEqual(store.recoverable(for: .plusMenu).map(\.id), [plus])
        XCTAssertEqual(store.recoverable(for: lesson).map(\.id), [inLesson])
        XCTAssertEqual(store.recoverable(for: .lesson(versionId: "ver1", activityId: "a1")), [])
        XCTAssertEqual(store.recoverable(for: .lesson(versionId: "ver2", activityId: nil)), [])
        XCTAssertEqual(store.recoverable().count, 2)
    }

    func testFinalizeAfterDiscardThrows() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        store.discard(draft)
        XCTAssertThrowsError(try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft))
        XCTAssertFalse(FileManager.default.fileExists(atPath: draft.folder.path))
    }

    // MARK: delete last segment (D5)

    func testDropLastSegmentRemovesOnlyTheLastOneAndItsFile() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft)
        let two = try store.finalize(segment: try write("s2.mov"), duration: 2, in: draft)
        let one = try store.dropLastSegment(in: two)
        XCTAssertEqual(one.segments.map(\.duration), [4])
        XCTAssertFalse(FileManager.default.fileExists(atPath: two.segments[1].url.path))
        XCTAssertEqual(store.recoverable().first?.segments, one.segments)
        XCTAssertEqual(try store.dropLastSegment(in: one).segments, [])
    }

    func testDiscardDeletesTheDraft() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft)
        store.discard(draft)
        XCTAssertFalse(FileManager.default.fileExists(atPath: draft.folder.path))
        XCTAssertEqual(store.recoverable(), [])
    }

    // MARK: the edit and imported clips (video-editor D16, D19, D28)

    private func edit() -> (layers: [VideoLayer], transcript: VideoTranscript) {
        let layers = [
            VideoLayer(kind: .text, text: "Title", centre: CGPoint(x: 0.25, y: 0.75), rotation: 0.5, startMs: 0, endMs: 2000),
            VideoLayer(kind: .caption, text: "hello", startMs: 500, endMs: 1500, sourceSegment: 0)
        ]
        let transcript = VideoTranscript(text: "hello", segments: [VideoTranscriptSegment(text: "hello", startMs: 500, endMs: 1500)])
        return (layers, transcript)
    }

    /// `draft.json` as a dictionary, edited and written back.
    private func editManifest(of draft: VideoDraft, _ change: (inout [String: Any]) -> Void) throws {
        let url = draft.folder.appendingPathComponent("draft.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        change(&json)
        try JSONSerialization.data(withJSONObject: json).write(to: url)
    }

    func testAnEditSurvives() throws {
        let store = VideoDraftStore(root: dir)
        let begun = store.begin()
        let (layers, transcript) = edit()
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: begun)
        try store.save(layers: layers, transcript: transcript, in: begun)
        let draft = try store.save(settings: VideoDraftSettings(lengthSeconds: 30), in: begun)
        let back = try XCTUnwrap(VideoDraftStore(root: dir).recoverable().first)
        XCTAssertEqual(back.layers, layers); XCTAssertEqual(back.transcript, transcript)
        XCTAssertEqual(back.source, .recording); XCTAssertEqual(store.current(draft), back)
    }

    func testOldAndDamagedManifests() throws {
        let store = VideoDraftStore(root: dir)
        let oldDraft = store.begin()
        try store.finalize(segment: try write("o.mov"), duration: 4, in: oldDraft)
        let badDraft = store.begin()
        try store.finalize(segment: try write("b.mov"), duration: 4, in: badDraft)
        let ok = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(
            VideoLayer(kind: .text, text: "ok", startMs: 0, endMs: 1000))))
        try editManifest(of: badDraft) {
            $0["layers"] = [ok, ["text": "no id"]]
            $0["transcript"] = 7; $0["source"] = "hologram"; $0["window"] = "x"
        }
        let recovered = store.recoverable()
        let old = try XCTUnwrap(recovered.first { $0.id == oldDraft.id })
        let bad = try XCTUnwrap(recovered.first { $0.id == badDraft.id })
        XCTAssertEqual(old.layers, []); XCTAssertNil(old.transcript); XCTAssertNil(old.window)
        XCTAssertEqual(bad.layers.map(\.text), ["ok"]); XCTAssertEqual(bad.segments.count, 1)
        XCTAssertNil(bad.transcript); XCTAssertEqual(bad.source, .recording); XCTAssertNil(bad.window)
    }

    func testAWindowThatIsNotAscendingReadsAsAbsent() throws {
        let store = VideoDraftStore(root: dir)
        let draft = store.begin()
        try store.finalize(segment: try write("s1.mov"), duration: 4, in: draft)
        try editManifest(of: draft) { $0["window"] = [9.0, 3.0] }
        XCTAssertNil(try XCTUnwrap(store.recoverable().first).window)
    }

    func testAdopt() throws {
        let store = VideoDraftStore(root: dir)
        let file = try write("clip.mov"); let other = try write("other.mov")
        let draft = try store.adopt(imported: file, duration: 300, window: 10...100, settings: VideoDraftSettings())
        let blocked = VideoDraftStore(root: try write("not-a-folder"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)); XCTAssertEqual(store.recoverable(), [draft])
        XCTAssertEqual(draft.source, .imported); XCTAssertEqual(draft.window, 10...100); XCTAssertEqual(draft.segments.map(\.duration), [300])
        XCTAssertThrowsError(try blocked.adopt(imported: other, duration: 1, window: nil, settings: VideoDraftSettings()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
    }
}
