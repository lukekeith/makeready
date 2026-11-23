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
}
