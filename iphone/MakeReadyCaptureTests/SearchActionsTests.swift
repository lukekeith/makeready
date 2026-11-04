import XCTest
@testable import MakeReady

/// A gate a test opens to release a held response.
private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}

/// master-search Task 8: SearchActions and the AppState search domain (D17, D20, D22, D24, D26, D36, D41, D42).
@MainActor
final class SearchActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private var actions: SearchActions!
    private var signOuts = 0

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        signOuts = 0
        actions = SearchActions(api: api, state: state, onUnauthorized: { [weak self] in self?.signOuts += 1 })
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func item(_ id: String, type: String = "GROUP", parent: String? = nil) -> SearchItem {
        SearchItem(type: type, id: id, title: id, createdAt: "2026-10-03T12:00:00.000Z", imageUrl: nil,
                   parent: parent.map { SearchItemParent(type: "PROGRAM", id: $0, name: "P") }, openedAt: nil)
    }

    private func page(_ ids: [String], next: String?) -> String {
        let rows = ids.map { #"{"type":"GROUP","id":"\#($0)","title":"\#($0)","createdAt":"2026-10-03T12:00:00.000Z","score":1,"imageUrl":null,"parent":null}"# }
        let cursor = next.map { #""\#($0)""# } ?? "null"
        return #"{"success":true,"items":[\#(rows.joined(separator: ","))],"nextCursor":\#(cursor)}"#
    }

    func testEncodesPlusAmpersandEquals() async {
        api.stub("GET", "/api/search/ranked?q=%2B1%20a%26b%3Dc", json: page(["a"], next: nil))
        await actions.search(query: "+1 a&b=c", filters: SearchFilters())
        XCTAssertEqual(state.searchResults.map(\.id), ["a"])
    }

    func testPagesMergeWithoutDuplicates() async {
        api.stub("GET", "/api/search/ranked?q=gr", json: page(["a", "b"], next: "c1"))
        api.stub("GET", "/api/search/ranked?q=gr&cursor=c1", json: page(["b", "c"], next: nil))
        await actions.search(query: "gr", filters: SearchFilters())
        await actions.loadNextPage(query: "gr", filters: SearchFilters())
        XCTAssertEqual(state.searchResults.map(\.id), ["a", "b", "c"])
        XCTAssertNil(state.searchNextCursor)
    }

    func testFiltersJoinTheQueryAfterQ() async {
        var filters = SearchFilters()
        filters.types = ["PROGRAM", "TEMPLATE"]
        filters.orgIds = ["o1"]
        api.stub("GET", "/api/search/ranked?q=gr&types=PROGRAM,TEMPLATE&orgIds=o1", json: page(["a"], next: nil))
        await actions.search(query: " gr ", filters: filters)
        XCTAssertEqual(state.searchResults.map(\.id), ["a"])
        XCTAssertEqual(state.searchAnsweredQuery, "gr")
    }

    func testStaleResponseIsDropped() async {
        let gate = AsyncGate()
        api.responseFor = { _, endpoint in
            if endpoint.contains("q=old") { await gate.wait(); return Data(self.page(["old"], next: nil).utf8) }
            return Data(self.page(["new"], next: nil).utf8)
        }
        let first = Task { await actions.search(query: "old", filters: SearchFilters()) }
        await Task.yield()
        await actions.search(query: "new", filters: SearchFilters())
        await gate.open(); await first.value
        XCTAssertEqual(state.searchResults.map(\.id), ["new"])
        XCTAssertEqual(state.searchAnsweredQuery, "new")
    }

    func testFailureLeavesTheQueryUnanswered() async {
        state.searchResults = [item("a")]
        api.errorToThrow = APIError.serverError("boom")
        await actions.search(query: "gr", filters: SearchFilters())
        XCTAssertEqual(state.searchResults.map(\.id), ["a"])
        XCTAssertNil(state.searchAnsweredQuery)
        XCTAssertFalse(state.errors.contains { $0.surface })
    }

    func testCancelQueryClearsAndIgnoresALateResponse() async {
        let gate = AsyncGate()
        api.responseFor = { _, _ in await gate.wait(); return Data(self.page(["late"], next: nil).utf8) }
        let t = Task { await actions.search(query: "gr", filters: SearchFilters()) }
        await Task.yield()
        actions.cancelQuery()
        await gate.open(); await t.value
        XCTAssertTrue(state.searchResults.isEmpty)
        XCTAssertNil(state.searchAnsweredQuery)
    }

    func testResponseAfterSignOutIsIgnored() async {
        api.beforeReturn = { [state] _, _ in state!.clearAllData() }
        api.stub("GET", "/api/search/recent-results", json: page(["a"], next: nil))
        await actions.loadRecents(filters: SearchFilters())
        XCTAssertTrue(state.searchRecents.isEmpty)
    }

    func testClearAllDataEmptiesTheDomain() {
        state.searchRecents = [item("a")]; state.searchResults = [item("b")]; state.searchAnsweredQuery = "gr"
        state.clearAllData()
        XCTAssertTrue(state.searchRecents.isEmpty && state.searchResults.isEmpty)
        XCTAssertNil(state.searchAnsweredQuery)
    }

    func testRecordOpenedMovesToTopAndSendsPut() async {
        state.searchRecents = [item("a"), item("b")]
        api.stub("PUT", "/api/search/recent-results", json: #"{"success":true}"#)
        await actions.recordOpened(item("b"))
        XCTAssertEqual(state.searchRecents.map(\.id), ["b", "a"])
        XCTAssertEqual(api.calls.last?.method, "PUT")
        XCTAssertEqual(api.calls.last?.body?["id"] as? String, "b")
        XCTAssertEqual(api.calls.last?.body?["type"] as? String, "GROUP")
    }

    func testRecordOpenedFailureIsSilentAndKeepsTheMove() async {
        state.searchRecents = [item("a"), item("b")]
        state.searchResults = [item("r")]
        api.errorToThrow = APIError.serverError("boom")
        await actions.recordOpened(item("b"))
        XCTAssertEqual(state.searchRecents.map(\.id), ["b", "a"])
        XCTAssertEqual(state.searchResults.map(\.id), ["r"])
        XCTAssertFalse(state.errors.contains { $0.surface })
    }

    func testFailedRemovalRestoresInPlaceAndSurfacesWithRetry() async {
        state.searchRecents = [item("a"), item("b"), item("c")]
        api.errorToThrow = APIError.serverError("boom")
        await actions.removeRecent(item("b"))
        XCTAssertEqual(state.searchRecents.map(\.id), ["a", "b", "c"])
        XCTAssertTrue(state.searchPendingRemovals.isEmpty)
        XCTAssertEqual(state.errors.last?.message, "Couldn't remove that search")
        XCTAssertEqual(state.errors.last?.surface, true)
        XCTAssertNotNil(state.errors.last?.retry)
    }

    func testRemovalSendsDeleteAndKeepsTheRowOut() async {
        state.searchRecents = [item("a"), item("b")]
        api.stub("DELETE", "/api/search/recent-results/GROUP/b", json: #"{"success":true}"#)
        await actions.removeRecent(item("b"))
        XCTAssertEqual(state.searchRecents.map(\.id), ["a"])
        XCTAssertTrue(state.searchPendingRemovals.isEmpty)
        XCTAssertEqual(api.calls.last?.method, "DELETE")
    }

    func testRecentsMergeSkipsAPendingRemoval() async {
        state.searchPendingRemovals = [item("a").key]
        api.stub("GET", "/api/search/recent-results", json: page(["a", "b"], next: nil))
        await actions.loadRecents(filters: SearchFilters())
        XCTAssertEqual(state.searchRecents.map(\.id), ["b"])
    }

    func testLoadFilterOptionsStoresTheAnswer() async {
        api.stub("GET", "/api/search/filter-options", json: #"{"success":true,"organizations":[{"id":"o","name":"O"}],"groups":[],"leaders":[],"tags":[]}"#)
        await actions.loadFilterOptions()
        XCTAssertEqual(state.searchFilterOptions?.organizations.map(\.id), ["o"])
    }

    func testEachUnauthorizedSignsOut() async {
        api.errorToThrow = APIError.unauthorized
        await actions.search(query: "gr", filters: SearchFilters())
        await actions.loadRecents(filters: SearchFilters())
        await actions.loadFilterOptions()
        await actions.recordOpened(item("a"))
        await actions.removeRecent(item("a"))
        XCTAssertEqual(signOuts, 5)
    }

    func testForgetDropsMatchingRows() {
        state.searchRecents = [item("g1", type: "GROUP"), item("a")]
        GroupActions(state: state).forgetGroup(id: "g1")
        XCTAssertEqual(state.searchRecents.map(\.id), ["a"])
        state.searchResults = [item("l1", type: "LESSON", parent: "p1"), item("p1", type: "PROGRAM")]
        ProgramActions(state: state).forgetProgram(id: "p1")
        XCTAssertTrue(state.searchResults.isEmpty)
    }

    func testDeleteMediaDropsTheItsRows() async throws {
        state.searchRecents = [item("m1", type: "PHOTO"), item("m2", type: "VIDEO"), item("m1", type: "GROUP")]
        api.stub("DELETE", "/api/media/m1", json: #"{"success":true}"#)
        try await MediaActions(api: api, state: state).deleteMedia(id: "m1")
        XCTAssertEqual(state.searchRecents.map(\.key), ["VIDEO:m2", "GROUP:m1"])
    }
}
