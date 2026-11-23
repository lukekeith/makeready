//
//  VideoActionsLibraryTests.swift
//  MakeReadyCaptureTests
//
//  video-recorder D14, D17, D20, D27: VideoActions' Library paging, detail, rename, and the
//  delete-or-remove decision, against a StubAPIClient and a private AppState.
//

import XCTest
@testable import MakeReady

@MainActor
final class VideoActionsLibraryTests: XCTestCase {

    private var state: AppState!
    private var api: StubAPIClient!
    private var actions: VideoActions!

    override func setUp() {
        super.setUp()
        // AppState() loads persisted state from disk on init: clear first so the test is deterministic.
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        actions = VideoActions(api: api, state: state)
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    // MARK: - Fixtures

    private let stamp = "2026-11-20T10:30:00.000Z"

    private func summaryJSON(_ id: String, title: String = "Video 1") -> String {
        #"{"id":"\#(id)","title":"\#(title)","thumbnailUrl":null,"playbackUrl":"https://x/\#(id).m3u8","duration":45,"status":"ready","transcriptStatus":"ready","transcriptPreview":"In the beginning","createdAt":"\#(stamp)"}"#
    }

    private func videoJSON(id: String, title: String = "Video 1", lessonUseCount: Int = 0) -> String {
        #"{"id":"\#(id)","title":"\#(title)","cloudflareUid":"u\#(id)","playbackUrl":"https://x/\#(id).m3u8","status":"ready","userId":"me","createdAt":"\#(stamp)","updatedAt":"\#(stamp)","transcriptStatus":"ready","lessonUseCount":\#(lessonUseCount)}"#
    }

    private func page(_ ids: [String], next: String?, titles: [String: String] = [:]) -> String {
        let rows = ids.map { summaryJSON($0, title: titles[$0] ?? "Video 1") }.joined(separator: ",")
        let cursor = next.map { #""\#($0)""# } ?? "null"
        return #"{"success":true,"data":[\#(rows)],"nextCursor":\#(cursor),"hasMore":\#(next != nil)}"#
    }

    private func seedLibrary(ids: [String]) {
        for id in ids {
            state.libraryVideos.upsert(try! JSONDecoder.apiDecoder.decode(VideoSummary.self, from: Data(summaryJSON(id).utf8)))
            state.videos.upsert(try! JSONDecoder.apiDecoder.decode(Video.self, from: Data(videoJSON(id: id).utf8)))
        }
        state.videoLibraryWindow = VideoLibraryWindow(ids: ids, nextCursor: nil, hasMore: false, query: nil)
    }

    // MARK: - Delete or remove (D17)

    func testDeleteDecision() async throws {
        api.stub("GET", "/api/videos/v0", json: #"{"success":true,"data":\#(videoJSON(id: "v0", lessonUseCount: 0))}"#)
        api.stub("GET", "/api/videos/v2", json: #"{"success":true,"data":\#(videoJSON(id: "v2", lessonUseCount: 2))}"#)
        let zero = try await actions.deleteDecision(id: "v0")
        XCTAssertEqual(zero, .delete)
        XCTAssertEqual(zero.confirmTitle, "Delete this video?")
        let two = try await actions.deleteDecision(id: "v2")
        XCTAssertEqual(two, .removeFromLibrary(lessonCount: 2))
        XCTAssertEqual(two.confirmTitle, "This video is used in 2 lesson activities. It will stay in them and leave your Library.")
    }

    func testDeleteDecisionPropagatesAFailedRead() async {
        api.errorToThrow = APIError.serverError("offline")
        do { _ = try await actions.deleteDecision(id: "v0"); XCTFail("should throw") } catch {}
    }

    func testRemoveDropsEverywhere() async throws {
        seedLibrary(ids: ["a", "b"])
        api.stub("POST", "/api/videos/a/remove-from-library", json: #"{"success":true,"data":{"id":"a","libraryRemovedAt":"2026-11-22T00:00:00Z"}}"#)
        try await actions.deleteOrRemove(id: "a", decision: .removeFromLibrary(lessonCount: 1))
        XCTAssertNil(state.libraryVideos["a"]); XCTAssertNil(state.videos["a"])
        XCTAssertEqual(state.videoLibraryWindow.ids, ["b"])
    }

    func testDeleteDropsEverywhere() async throws {
        seedLibrary(ids: ["a", "b"])
        api.stub("DELETE", "/api/videos/b", json: #"{"success":true}"#)
        try await actions.deleteOrRemove(id: "b", decision: .delete)
        XCTAssertNil(state.libraryVideos["b"]); XCTAssertNil(state.videos["b"])
        XCTAssertEqual(state.videoLibraryWindow.ids, ["a"])
    }

    func testAFailedRemoveKeepsTheRow() async {
        seedLibrary(ids: ["a"])
        api.errorToThrow = APIError.serverError("boom")
        do { try await actions.deleteOrRemove(id: "a", decision: .delete); XCTFail("should throw") } catch {}
        XCTAssertNotNil(state.libraryVideos["a"]); XCTAssertEqual(state.videoLibraryWindow.ids, ["a"])
    }

    // MARK: - Library window (D20, D27)

    func testPageOneReplacesTheWindowAndLaterPagesAppend() async throws {
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["stale"], nextCursor: "old", hasMore: true, query: nil)
        api.stub("GET", "/api/videos/library?limit=50", json: page(["a", "b"], next: "c1"))
        try await actions.loadLibrary(cursor: nil, q: nil)
        XCTAssertEqual(state.videoLibraryWindow.ids, ["a", "b"])
        XCTAssertEqual(state.videoLibraryWindow.nextCursor, "c1"); XCTAssertTrue(state.videoLibraryWindow.hasMore)
        XCTAssertNotNil(state.libraryVideos["a"])

        api.stub("GET", "/api/videos/library?limit=50&cursor=c1", json: page(["c"], next: nil))
        try await actions.loadLibrary(cursor: "c1", q: nil)
        XCTAssertEqual(state.videoLibraryWindow.ids, ["a", "b", "c"])
        XCTAssertFalse(state.videoLibraryWindow.hasMore)
    }

    func testTheSearchTextIsSentAndKeptOnTheWindow() async throws {
        api.stub("GET", "/api/videos/library?limit=50&q=grace%20alone", json: page(["a"], next: nil))
        try await actions.loadLibrary(cursor: nil, q: "grace alone")
        XCTAssertEqual(state.videoLibraryWindow.query, "grace alone")
    }

    func testARestoredWindowWithNoCursorLoadsPageOne() async throws {
        // Disk keeps the first 100 ids with hasMore true and no cursor (capped).
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["a"], nextCursor: nil, hasMore: true, query: nil)
        api.stub("GET", "/api/videos/library?limit=50", json: page(["n1", "n2"], next: nil))
        try await actions.loadNextLibraryPage()
        XCTAssertEqual(state.videoLibraryWindow.ids, ["n1", "n2"])
        XCTAssertEqual(api.calls.count, 1)
    }

    func testLoadNextPageUsesTheWindowsCursorAndStopsWhenThereIsNoMore() async throws {
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["a"], nextCursor: "c1", hasMore: true, query: nil)
        api.stub("GET", "/api/videos/library?limit=50&cursor=c1", json: page(["b"], next: nil))
        try await actions.loadNextLibraryPage()
        XCTAssertEqual(state.videoLibraryWindow.ids, ["a", "b"])
        try await actions.loadNextLibraryPage()
        XCTAssertEqual(api.calls.count, 1)
    }

    func testARestoredSearchWindowIsResetOnLaunch() {
        seedLibrary(ids: ["a"])
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["a"], nextCursor: nil, hasMore: true, query: "grace")
        state.persistImmediately()
        StatePersistence.shared.waitForPendingWrites()
        let reloaded = AppState()
        XCTAssertEqual(reloaded.videoLibraryWindow, VideoLibraryWindow())
    }

    // MARK: - Detail and rename

    func testLoadDetailUpsertsVideos() async throws {
        api.stub("GET", "/api/videos/v1", json: #"{"success":true,"data":\#(videoJSON(id: "v1", lessonUseCount: 3))}"#)
        try await actions.loadDetail(id: "v1")
        XCTAssertEqual(state.videos["v1"]?.lessonUseCount, 3)
    }

    func testRenamePatchesTheTitleAndUpdatesBothStores() async throws {
        seedLibrary(ids: ["a"])
        api.stub("PATCH", "/api/videos/a", json: #"{"success":true,"data":\#(videoJSON(id: "a", title: "Sunday"))}"#)
        try await actions.rename(id: "a", title: "Sunday")
        XCTAssertEqual(state.videos["a"]?.title, "Sunday")
        XCTAssertEqual(state.libraryVideos["a"]?.title, "Sunday")
        XCTAssertEqual(api.recordedCalls(method: "PATCH").first?.body?["title"] as? String, "Sunday")
    }

    // MARK: - Titles (D14)

    func testNextVideoTitleCountsLibraryTitles() {
        XCTAssertEqual(state.nextVideoTitle(), "Video 1")
        seedLibrary(ids: ["a"])
        state.libraryVideos.upsert(try! JSONDecoder.apiDecoder.decode(VideoSummary.self, from: Data(summaryJSON("b", title: "Video 4").utf8)))
        XCTAssertEqual(state.nextVideoTitle(), "Video 5")
    }
}
