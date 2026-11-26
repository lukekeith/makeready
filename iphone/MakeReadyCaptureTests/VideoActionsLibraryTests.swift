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

    /// A `Video` from any endpoint but `GET /api/videos/:id`.
    private func uncountedJSON(id: String) -> String {
        videoJSON(id: id).replacingOccurrences(of: #","lessonUseCount":0"#, with: "")
    }

    /// `videoJSON` with both counts, as `GET /api/videos/:id` answers (D11).
    private func countedJSON(_ id: String, lessons: Int, versions: Int) -> String {
        String(videoJSON(id: id, lessonUseCount: lessons).dropLast()) + #","versionUseCount":\#(versions)}"#
    }

    private func stub(_ videoJSON: String) {
        api.stub("GET", "/api/videos/a", json: #"{"success":true,"data":\#(videoJSON)}"#)
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

    // MARK: - Delete everywhere (D5, D11)

    func testDeleteEverywhereStates() async throws {
        let cases: [(Int, Int, VideoDeleteEverywhere, String)] = [
            (1, 1, .allowed, ""), (0, 0, .allowed, ""), (3, 1, .otherLessons(2), "Used in 2 other lessons"),
            (2, 4, .otherLessons(1), "Used in 1 other lesson"), (1, 2, .published, "Used in a published lesson")
        ]
        for (lessons, versions, expected, note) in cases {
            stub(countedJSON("a", lessons: lessons, versions: versions))
            let state = try await actions.deleteEverywhere(id: "a")
            XCTAssertEqual(state, expected)
            XCTAssertEqual(state.enabled, expected == .allowed)
            XCTAssertEqual(state.note, note)
        }
        XCTAssertFalse(VideoDeleteEverywhere.checking.enabled)
    }

    func testAMissingCountIsUnknownEvenWhenOneIsCached() async throws {
        stub(countedJSON("a", lessons: 1, versions: 1))
        _ = try await actions.deleteEverywhere(id: "a")
        stub(videoJSON(id: "a", lessonUseCount: 1))
        let second = try await actions.deleteEverywhere(id: "a")
        XCTAssertEqual(second, .unknown)
        XCTAssertFalse(second.enabled)
        XCTAssertEqual(second.note, "Couldn't check where it's used")
        XCTAssertEqual(state.videos["a"]?.versionUseCount, 1)
    }

    func testDeleteEverywherePropagatesAFailedRead() async {
        let result = try? await actions.deleteEverywhere(id: "never-stubbed")
        XCTAssertNil(result)
    }

    func testCheckingNoteReads() {
        XCTAssertEqual(VideoDeleteEverywhere.checking.note, "Checking where it's used…")
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

    func testTheConfirmOfOneActivityIsSingular() {
        XCTAssertEqual(VideoDeleteDecision.removeFromLibrary(lessonCount: 1).confirmTitle,
                       "This video is used in 1 lesson activity. It will stay in it and leave your Library.")
    }

    /// Only `GET /api/videos/:id` counts; an answer without the count is not a count of 0.
    func testADetailWithNoUseCountDecidesNothing() async {
        seedLibrary(ids: ["a"])
        api.stub("GET", "/api/videos/a", json: #"{"success":true,"data":\#(uncountedJSON(id: "a"))}"#)
        do {
            let decision = try await actions.deleteDecision(id: "a")
            XCTFail("decided \(decision)")
        } catch {}
    }

    func testAnAnswerWithNoUseCountKeepsTheKnownOne() async throws {
        seedLibrary(ids: ["a"])
        _ = state.videos.update("a") { $0.lessonUseCount = 2 }
        api.stub("PATCH", "/api/videos/a", json: #"{"success":true,"data":\#(uncountedJSON(id: "a"))}"#)
        try await actions.rename(id: "a", title: "T")
        XCTAssertEqual(state.videos["a"]?.lessonUseCount, 2)
        api.stub("POST", "/api/videos/a/refresh", json: #"{"success":true,"data":\#(uncountedJSON(id: "a"))}"#)
        _ = try await actions.refreshVideoStatus(id: "a")
        XCTAssertEqual(state.videos["a"]?.lessonUseCount, 2)
        api.stub("GET", "/api/videos/me", json: #"{"success":true,"data":[\#(uncountedJSON(id: "a"))]}"#)
        try await actions.loadVideos()
        for _ in 0..<200 where state.loadingStates.isLoading(.videos) { await Task.yield() }
        XCTAssertEqual(state.videos["a"]?.lessonUseCount, 2)
    }

    func testARefreshUpdatesTheLibraryRow() async throws {
        seedLibrary(ids: ["a"])
        _ = state.libraryVideos.update("a") { $0.status = "pending"; $0.transcriptStatus = .pending; $0.transcriptPreview = nil }
        let text = String(repeating: "w", count: 200)
        api.stub("POST", "/api/videos/a/refresh", json: #"{"success":true,"data":{"id":"a","title":"Video 1","cloudflareUid":"ua","playbackUrl":"https://new/a.m3u8","thumbnailUrl":"https://new/a.jpg","duration":61,"status":"ready","userId":"me","createdAt":"\#(stamp)","updatedAt":"\#(stamp)","transcriptStatus":"ready","transcript":"\#(text)"}}"#)
        _ = try await actions.refreshVideoStatus(id: "a")
        let row = try XCTUnwrap(state.libraryVideos["a"])
        XCTAssertEqual(row.videoStatus, .ready)
        XCTAssertEqual(row.playbackUrl, "https://new/a.m3u8")
        XCTAssertEqual(row.thumbnailUrl, "https://new/a.jpg")
        XCTAssertEqual(row.duration, 61)
        XCTAssertEqual(row.transcriptStatus, .ready)
        XCTAssertEqual(row.transcriptPreview, String(text.prefix(160)))
    }

    func testARefreshOfAVideoTheLibraryDoesNotListAddsNoRow() async throws {
        api.stub("POST", "/api/videos/z/refresh", json: #"{"success":true,"data":\#(uncountedJSON(id: "z"))}"#)
        _ = try await actions.refreshVideoStatus(id: "z")
        XCTAssertNil(state.libraryVideos["z"])
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

    func testACursorPageForAnOlderQueryIsDropped() async throws {
        // The window moved on to "grace" while a page of the whole Library was in flight.
        state.videoLibraryWindow = VideoLibraryWindow(ids: ["g1"], nextCursor: "cg", hasMore: true, query: "grace")
        api.stub("GET", "/api/videos/library?limit=50&cursor=c1", json: page(["late"], next: nil))
        try await actions.loadLibrary(cursor: "c1", q: nil)
        XCTAssertEqual(state.videoLibraryWindow, VideoLibraryWindow(ids: ["g1"], nextCursor: "cg", hasMore: true, query: "grace"))
        XCTAssertNil(state.libraryVideos["late"])
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

    // MARK: - Following a video that is still arriving (video-activity-basics D16)

    func testWaitUntilReadyIsTrueForAReadyVideo() async throws {
        api.stub("GET", "/api/videos/r", json: #"{"success":true,"data":\#(videoJSON(id: "r"))}"#)
        api.stub("GET", "/api/videos/e", json: #"{"success":true,"data":\#(videoJSON(id: "e").replacingOccurrences(of: #""status":"ready""#, with: #""status":"error""#))}"#)
        let answers = [try await actions.waitUntilReady(id: "r"), try await actions.waitUntilReady(id: "e")]
        XCTAssertEqual(answers, [true, false])
    }

    // MARK: - Titles (D14)

    func testNextVideoTitleCountsLibraryTitles() {
        XCTAssertEqual(state.nextVideoTitle(), "Video 1")
        seedLibrary(ids: ["a"])
        state.libraryVideos.upsert(try! JSONDecoder.apiDecoder.decode(VideoSummary.self, from: Data(summaryJSON("b", title: "Video 4").utf8)))
        XCTAssertEqual(state.nextVideoTitle(), "Video 5")
    }

    // MARK: - Suggestions (video-naming D6)

    func testSuggestDetailsPostsTheTranscript() async throws {
        api.stub("POST", "/api/videos/suggest-details", json: #"{"success":true,"data":{"suggestions":[{"title":"A","description":"B"}]}}"#)
        let answer = try await actions.suggestDetails(transcript: "hello")
        XCTAssertEqual(answer, [VideoDetailSuggestion(title: "A", description: "B")])
        XCTAssertEqual(api.calls.last?.body?["transcript"] as? String, "hello")
    }
}
