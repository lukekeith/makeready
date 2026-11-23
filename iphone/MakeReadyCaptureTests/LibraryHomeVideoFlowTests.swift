//
//  LibraryHomeVideoFlowTests.swift
//  MakeReadyCaptureTests
//
//  video-recorder D17, D20: when the Library's video list pages, and what a swipe-delete does for
//  a server row, a row lessons use, a failed read and a queued row. Seams are scripted closures.
//

import XCTest
@testable import MakeReady

final class LibraryVideoPagingTests: XCTestCase {

    private let floor = LibraryVideoPaging.rowHeightFloor

    func testNearTheEndOfTheEstimatedContent() {
        // 50 rows, an 800 pt viewport: content is 50 * floor; the look-ahead is one viewport.
        let content = 50 * floor
        XCTAssertFalse(LibraryVideoPaging.isNearEnd(offset: 0, viewport: 800, rowCount: 50))
        XCTAssertTrue(LibraryVideoPaging.isNearEnd(offset: content - 2 * 800, viewport: 800, rowCount: 50))
    }

    func testTallRowsOnlyPageEarly() {
        // Real rows twice the floor: at the same offset the estimate says "nearer the end" than it is.
        let offset = 50 * floor - 800 - 800
        XCTAssertTrue(LibraryVideoPaging.isNearEnd(offset: offset, viewport: 800, rowCount: 50))
        XCTAssertLessThan(offset + 800, 50 * floor * 2 - 800)
    }

    func testAShortListThatCannotScrollIsNearItsEnd() {
        XCTAssertTrue(LibraryVideoPaging.isNearEnd(offset: 0, viewport: 800, rowCount: 3))
    }

    func testAnUnmeasuredViewportStillUsesAMinimumLookAhead() {
        XCTAssertTrue(LibraryVideoPaging.isNearEnd(offset: 0, viewport: 0, rowCount: 5))
        XCTAssertFalse(LibraryVideoPaging.isNearEnd(offset: 0, viewport: 0, rowCount: 500))
    }

    func testShouldLoadNextNeedsEveryCondition() {
        func should(hasMore: Bool = true, matches: Bool = true, shown: Bool = true, loading: Bool = false,
                    failed: Bool = false) -> Bool {
            LibraryVideoPaging.shouldLoadNext(hasMore: hasMore, windowMatchesQuery: matches, videosShown: shown,
                                              isLoading: loading, lastPageFailed: failed, offset: 0, viewport: 800,
                                              rowCount: 3)
        }
        XCTAssertTrue(should())
        XCTAssertFalse(should(hasMore: false))
        XCTAssertFalse(should(matches: false))
        XCTAssertFalse(should(shown: false))
        XCTAssertFalse(should(loading: true))
        XCTAssertFalse(should(failed: true))
    }
}

@MainActor
final class LibraryVideoDeletionTests: XCTestCase {

    private struct Boom: Error {}

    private final class Script {
        var decision: VideoDeleteDecision = .delete
        var decideFails = false
        var performFails = false
        var serverIds: [String: String] = [:]
        var decided: [String] = []
        var performed: [(String, VideoDeleteDecision)] = []
        var removedQueued: [String] = []
        var asked: [LibraryVideoDeletion.Removal] = []
        var surfaced: [(context: String, message: String)] = []
        var retries: [() -> Void] = []
    }

    private func make(_ s: Script) -> LibraryVideoDeletion {
        LibraryVideoDeletion(
            decide: { id in
                s.decided.append(id)
                if s.decideFails { throw Boom() }
                return s.decision
            },
            perform: { id, decision in
                if s.performFails { throw Boom() }
                s.performed.append((id, decision))
            },
            serverId: { s.serverIds[$0] },
            removeQueued: { s.removedQueued.append($0) },
            askAgain: { s.asked.append($0) },
            surface: { _, context, message, retry in
                s.surfaced.append((context, message))
                s.retries.append(retry)
            })
    }

    func testAVideoNoLessonUsesIsDeletedAtOnce() async {
        let s = Script()
        await make(s).delete(id: "v1")
        XCTAssertEqual(s.performed.map(\.0), ["v1"])
        XCTAssertEqual(s.performed.first?.1, .delete)
        XCTAssertTrue(s.asked.isEmpty)
        XCTAssertTrue(s.surfaced.isEmpty)
    }

    func testAVideoLessonsUseAsksASecondConfirmAndDoesNothingYet() async {
        let s = Script()
        s.decision = .removeFromLibrary(lessonCount: 2)
        await make(s).delete(id: "v1")
        XCTAssertEqual(s.asked, [.init(id: "v1", decision: .removeFromLibrary(lessonCount: 2), localId: nil)])
        XCTAssertTrue(s.performed.isEmpty)
    }

    func testConfirmingTheSecondAskRemovesFromTheLibrary() async {
        let s = Script()
        let removal = LibraryVideoDeletion.Removal(id: "v1", decision: .removeFromLibrary(lessonCount: 2), localId: nil)
        await make(s).confirm(removal)
        XCTAssertEqual(s.performed.first?.0, "v1")
        XCTAssertEqual(s.performed.first?.1, .removeFromLibrary(lessonCount: 2))
        XCTAssertTrue(s.surfaced.isEmpty)
    }

    func testAFailedReadSurfacesTheBannerChangesNothingAndRetries() async {
        let s = Script()
        s.decideFails = true
        let deletion = make(s)
        await deletion.delete(id: "v1")
        XCTAssertEqual(s.surfaced.map(\.message), ["Couldn't delete this video"])
        XCTAssertTrue(s.performed.isEmpty)
        XCTAssertTrue(s.asked.isEmpty)
        s.decideFails = false
        s.retries.first?()
        await Task.yield()
        for _ in 0..<20 where s.performed.isEmpty { await Task.yield() }
        XCTAssertEqual(s.performed.map(\.0), ["v1"])
    }

    func testAFailedDeleteSurfacesTheBanner() async {
        let s = Script()
        s.performFails = true
        await make(s).delete(id: "v1")
        XCTAssertEqual(s.surfaced.map(\.context), ["LibraryHomeContainer.deleteVideo"])
    }

    func testAFailedRemovalSurfacesItsOwnBanner() async {
        let s = Script()
        s.performFails = true
        await make(s).confirm(.init(id: "v1", decision: .removeFromLibrary(lessonCount: 1), localId: nil))
        XCTAssertEqual(s.surfaced.map(\.message), ["Couldn't remove this video from your Library"])
    }

    func testAQueuedVideoWithNoServerRowLeavesTheQueue() async {
        let s = Script()
        await make(s).delete(id: "local:L1")
        XCTAssertEqual(s.removedQueued, ["L1"])
        XCTAssertTrue(s.decided.isEmpty)
        XCTAssertTrue(s.performed.isEmpty)
    }

    func testAQueuedVideoWithAServerRowDeletesItThenLeavesTheQueue() async {
        let s = Script()
        s.serverIds["L1"] = "v9"
        await make(s).delete(id: "local:L1")
        XCTAssertEqual(s.decided, ["v9"])
        XCTAssertEqual(s.performed.map(\.0), ["v9"])
        XCTAssertEqual(s.removedQueued, ["L1"])
    }

    func testAQueuedVideoThatFinishedMeanwhileIsASilentNoOp() async {
        let s = Script()
        let deletion = LibraryVideoDeletion(
            decide: { _ in .delete }, perform: { _, _ in }, serverId: { _ in nil },
            removeQueued: { _ in throw CancellationError() }, askAgain: { _ in },
            surface: { _, context, message, _ in s.surfaced.append((context, message)) })
        await deletion.delete(id: "local:L1")
        XCTAssertTrue(s.surfaced.isEmpty)
    }
}
