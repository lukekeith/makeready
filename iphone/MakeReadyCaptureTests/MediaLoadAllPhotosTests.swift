import XCTest
@testable import MakeReady

/// media-page D2/D13/F6 (media-library D4: now /api/media/browse): loadAllMedia follows nextCursor until hasMore is false, writing each page as it
/// lands; an error keeps the loaded pages; cancellation, a sign-out or an org change stops the writes.
@MainActor
final class MediaLoadAllPhotosTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let base = "/api/media/browse?limit=2"

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        state.organizationId = "o1"
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func item(_ id: String) -> String {
        #"{"id":"\#(id)","title":"\#(id)","url":"https://img/\#(id).jpeg","type":"photo","uploadStatus":"ready","tags":[],"usageCount":0,"createdAt":"2026-10-01T12:00:00.000Z","updatedAt":"2026-10-01T12:00:00.000Z","takenAt":null}"#
    }

    private func page(_ ids: [String], total: Int? = nil, next: String?) -> String {
        let totalPart = total.map { #","total":\#($0)"# } ?? ""
        let cursor = next.map { #""\#($0)""# } ?? "null"
        return #"{"success":true,"data":[\#(ids.map(item).joined(separator: ","))]\#(totalPart),"hasMore":\#(next != nil),"nextCursor":\#(cursor)}"#
    }

    private func stubThreePages() {
        api.stub("GET", base, json: page(["a", "b"], total: 5, next: "c1"))
        api.stub("GET", base + "&cursor=c1", json: page(["c", "d"], next: "c2"))
        api.stub("GET", base + "&cursor=c2", json: page(["e"], next: nil))
    }

    func testFollowsTheCursorUntilHasMoreIsFalse() async {
        stubThreePages()
        let outcome = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(api.calls.count, 3)
        XCTAssertEqual(state.mediaLibraryTotal, 5)
        XCTAssertNil(state.mediaLibraryNextCursor)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")
    }

    func testAnErrorKeepsTheLoadedPagesAndARetryResumesFromTheCursor() async {
        stubThreePages()
        api.errorFor = { endpoint, _ in endpoint.hasSuffix("cursor=c1") ? APIError.serverError("boom") : nil }
        let failed = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
        XCTAssertEqual(state.mediaLibraryNextCursor, "c1")
        XCTAssertNil(state.mediaPhotosLoadedOrgId)

        api.errorFor = nil
        let resumed = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2, resumeCursor: "c1")
        XCTAssertEqual(resumed, .completed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
    }

    func testASignOutMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.initialLoad.reset() } }
        let outcome = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    func testAnOrgChangeMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.organizationId = "o2" } }
        let outcome = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    /// Holds the load's Task so the stub can cancel it between pages.
    private final class TaskBox { var task: Task<PhotoLoadOutcome, Never>? }

    /// media-library: a refresh over a shown library swaps once at the end, so a cancel keeps the
    /// whole old library (and its completed load) instead of leaving page 1.
    func testARefreshCancelledAfterPage1KeepsTheOldLibrary() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")

        let box = TaskBox()
        api.beforeReturn = { endpoint, _ in if endpoint.hasSuffix("cursor=c1") { box.task?.cancel() } }
        let actions = MediaActions(api: api, state: state)
        let refresh = Task { await actions.loadAllMedia(pageSize: 2) }
        box.task = refresh
        let outcome = await refresh.value
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")
    }

    /// media-library: a refresh that fails on page 2 keeps the old library and its completed load.
    func testARefreshThatFailsOnPage2KeepsTheOldLibrary() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")

        api.errorFor = { endpoint, _ in endpoint.hasSuffix("cursor=c1") ? APIError.serverError("boom") : nil }
        let outcome = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")
    }

    /// media-library: the pull-to-refresh jump — while a refresh pages through, the grid keeps the whole
    /// old library; the new one replaces it in one write when the last page lands.
    func testARefreshNeverShrinksTheLibraryMidway() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        state.mediaLibrary.upsert(state.mediaLibrary.all[0].withId("gone"))
        var midway: Set<String> = []
        api.beforeReturn = { [state] endpoint, _ in
            if endpoint.hasSuffix("cursor=c2") { midway = Set(state?.mediaLibrary.all.map(\.id) ?? []) }
        }
        let outcome = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(midway, ["a", "b", "c", "d", "e", "gone"])
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
    }

    func testA401SignsOut() async {
        api.errorToThrow = APIError.unauthorized
        var signedOut = false
        let outcome = await MediaActions(api: api, state: state, onUnauthorized: { signedOut = true }).loadAllMedia(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertTrue(signedOut)
    }

    func testLoadSourcesStoresMakeReadyThenOrgs() async {
        api.stub("GET", "/api/media/sources", json: #"{"success":true,"data":[{"id":"mr","name":"MakeReady","isMakeReady":true,"canUpload":false},{"id":"o1","name":"Alpha","isMakeReady":false,"canUpload":true}]}"#)
        await MediaActions(api: api, state: state).loadSources()
        XCTAssertEqual(state.mediaSources.map(\.id), ["mr", "o1"])
        XCTAssertEqual(state.mediaSources.first?.isMakeReady, true)
        XCTAssertEqual(state.mediaSources.last?.canUpload, true)
    }

    func testBrowseItemsDecodeTheirSourceAndOldItemsStillDecode() async {
        let mr = #"{"id":"m","title":"m","url":"https://img/m.jpeg","type":"photo","uploadStatus":"ready","tags":[],"usageCount":0,"createdAt":"2026-10-01T12:00:00.000Z","updatedAt":"2026-10-01T12:00:00.000Z","organizationId":"mr","isMakeReady":true}"#
        api.stub("GET", base, json: #"{"success":true,"data":[\#(mr),\#(item("a"))],"hasMore":false,"nextCursor":null}"#)
        _ = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        XCTAssertEqual(state.mediaLibrary.all.first { $0.id == "m" }?.isMakeReady, true)
        XCTAssertEqual(state.mediaLibrary.all.first { $0.id == "m" }?.organizationId, "mr")
        XCTAssertNil(state.mediaLibrary.all.first { $0.id == "a" }?.isMakeReady)
    }

    func testClearInMemoryForgetsTheLoadedOrg() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllMedia(pageSize: 2)
        state.mediaSources = [MediaSource(id: "o1", name: "Alpha", isMakeReady: false, canUpload: true)]
        state.clearAllData()
        XCTAssertNil(state.mediaPhotosLoadedOrgId)
        XCTAssertTrue(state.mediaSources.isEmpty)
    }
}

private extension MediaLibraryItem {
    func withId(_ id: String) -> MediaLibraryItem {
        MediaLibraryItem(id: id, title: title, description: description, url: url, type: type, mimeType: mimeType,
                         fileSize: fileSize, thumbnailUrl: thumbnailUrl, uploadStatus: uploadStatus, duration: duration,
                         tags: tags, usageCount: usageCount, uploader: uploader, video: video, createdAt: createdAt,
                         updatedAt: updatedAt, takenAt: takenAt)
    }
}
