import XCTest
@testable import MakeReady

/// media-page D2/D13/F6: loadAllPhotos follows nextCursor until hasMore is false, writing each page as it
/// lands; an error keeps the loaded pages; cancellation, a sign-out or an org change stops the writes.
@MainActor
final class MediaLoadAllPhotosTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let base = "/api/organizations/o1/media/library?type=photo&limit=2"

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
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
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
        let failed = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
        XCTAssertEqual(state.mediaLibraryNextCursor, "c1")
        XCTAssertNil(state.mediaPhotosLoadedOrgId)

        api.errorFor = nil
        let resumed = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2, resumeCursor: "c1")
        XCTAssertEqual(resumed, .completed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
    }

    func testASignOutMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.initialLoad.reset() } }
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    func testAnOrgChangeMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.organizationId = "o2" } }
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    /// Holds the load's Task so the stub can cancel it between pages.
    private final class TaskBox { var task: Task<PhotoLoadOutcome, Never>? }

    /// §Testing "stops writing after cancellation": a refresh cancelled after page 1 writes no later page.
    /// Final review I1: page 1 replaced the completed library, so the session no longer has a completed
    /// load — the next open must load again.
    func testARefreshCancelledAfterPage1StopsWritingAndForgetsTheCompletedLoad() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")

        let box = TaskBox()
        api.beforeReturn = { endpoint, _ in if endpoint.hasSuffix("cursor=c1") { box.task?.cancel() } }
        let actions = MediaActions(api: api, state: state)
        let refresh = Task { await actions.loadAllPhotos(pageSize: 2) }
        box.task = refresh
        let outcome = await refresh.value
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
        XCTAssertNil(state.mediaPhotosLoadedOrgId)
    }

    /// Final review I1: a refresh that fails on page 2 leaves only page 1, so no completed load is recorded.
    func testARefreshThatFailsOnPage2ForgetsTheCompletedLoad() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")

        api.errorFor = { endpoint, _ in endpoint.hasSuffix("cursor=c1") ? APIError.serverError("boom") : nil }
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
        XCTAssertNil(state.mediaPhotosLoadedOrgId)
    }

    func testA401SignsOut() async {
        api.errorToThrow = APIError.unauthorized
        var signedOut = false
        let outcome = await MediaActions(api: api, state: state, onUnauthorized: { signedOut = true }).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertTrue(signedOut)
    }

    func testClearInMemoryForgetsTheLoadedOrg() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        state.clearAllData()
        XCTAssertNil(state.mediaPhotosLoadedOrgId)
    }
}
