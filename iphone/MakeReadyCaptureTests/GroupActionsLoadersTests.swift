import XCTest
@testable import MakeReady

/// ui2-groups-browse T11–T13, T18: the group page's loaders write the in-memory group stores;
/// a 401 signs out, a 404 is scope (D23), any other failure is recorded console-only and keeps
/// the store; a sign-out mid-load drops the result.
@MainActor
final class GroupActionsLoadersTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Sun Oct 25, 12:00 local

    private let nextStudyJSON = #"{"success":true,"study":{"id":"s1","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z","title":"Faith over fear","studyProgram":{"id":"p1","name":"Daily Inspiration"},"activities":[{"id":"a1","type":"VIDEO","orderNumber":1,"title":"Watch","thumbnailUrl":"https://img/a1.jpg"}]}}"#
    private let historyJSON = #"{"success":true,"events":[{"id":"h1","occurredAt":"2026-10-25T17:30:00.000Z","kind":"member_joined","text":"Tony Stark joined the group","highlight":"Tony Stark"}]}"#
    private let analyticsJSON = #"{"rows":[{"day":"2026-10-25","scheduled_lessons":3,"lesson_completions":1},{"day":"2026-10-24","scheduled_lessons":2,"lesson_completions":2}]}"#

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func actions(onUnauthorized: @escaping @MainActor () async -> Void = {}) -> GroupActions {
        GroupActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: onUnauthorized)
    }

    // MARK: - Verify A1: the detail keeps the list's org (D10)

    private func groupJSON(org: Bool) -> String {
        let orgFields = org ? #","organizationId":"o1","organizationName":"Grace Church""# : ""
        return #"{"id":"g1","code":null,"name":"Alpha","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-01T10:00:00Z","updatedAt":"2026-10-01T10:00:00Z""#
            + orgFields + "}"
    }

    /// `GET /api/groups/:id` carries no org fields (§Contract); replacing the cached group with it
    /// blanked the org the Orgs chip filters on (verify 2026-10-27, A1).
    func testGetGroupKeepsTheListsOrganization() async throws {
        api.stub("GET", "/api/groups", json: #"{"success":true,"groups":["# + groupJSON(org: true) + "]}")
        try await actions().loadGroups(forceRefresh: true)
        api.stub("GET", "/api/groups/g1", json: #"{"success":true,"group":"# + groupJSON(org: false) + "}")
        _ = try await actions().getGroup(id: "g1")
        XCTAssertEqual(state.groups["g1"]?.organizationId, "o1")
        XCTAssertEqual(state.groups["g1"]?.organizationName, "Grace Church")
    }

    /// The PATCH response has no org fields either.
    func testUpdateGroupKeepsTheListsOrganization() async throws {
        api.stub("GET", "/api/groups", json: #"{"success":true,"groups":["# + groupJSON(org: true) + "]}")
        try await actions().loadGroups(forceRefresh: true)
        api.stub("PATCH", "/api/groups/g1", json: #"{"success":true,"group":"# + groupJSON(org: false) + "}")
        _ = try await actions().updateGroup(id: "g1", name: "Alpha")
        XCTAssertEqual(state.groups["g1"]?.organizationId, "o1")
        XCTAssertEqual(state.groups["g1"]?.organizationName, "Grace Church")
    }

    // MARK: - T11 next study

    func testNextStudyLandsByGroup() async {
        api.stub("GET", "/api/groups/g1/next-study", json: nextStudyJSON)
        await actions().loadNextStudy(groupId: "g1")
        XCTAssertEqual(state.nextStudyByGroupId["g1"]?.title, "Faith over fear")
        XCTAssertEqual(state.nextStudyByGroupId["g1"]?.activities.first?.thumbnailUrl, "https://img/a1.jpg")
    }

    /// T11: 204 → no lesson ahead — the key goes, nothing is recorded.
    func testNoContentRemovesTheNextStudy() async {
        state.nextStudyByGroupId["g1"] = NextStudy(id: "old")
        api.stub("GET", "/api/groups/g1/next-study", json: "")
        await actions().loadNextStudy(groupId: "g1")
        XCTAssertNil(state.nextStudyByGroupId["g1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    // MARK: - T12 history

    func testHistoryAsksForTheLatestFive() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/history?limit=5"), 1)
        XCTAssertEqual(state.historyByGroupId["g1"]?.map(\.highlight), ["Tony Stark"])
    }

    /// D23: a group outside the caller's scope is a 404 — nothing written, nothing recorded.
    func testNotFoundWritesAndRecordsNothing() async {
        let cached = [GroupHistoryEvent(id: "h0", text: "Created the group")]
        state.historyByGroupId["g1"] = cached
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(state.historyByGroupId["g1"], cached)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testOtherFailureKeepsTheStoreAndRecordsConsoleOnly() async {
        let cached = [GroupHistoryEvent(id: "h0", text: "Created the group")]
        state.historyByGroupId["g1"] = cached
        api.errorFor = { _, _ in APIHTTPError(status: 500, message: "boom") }
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(state.historyByGroupId["g1"], cached)
        XCTAssertEqual(state.errors.last?.context, "GroupActions.loadHistory")
        XCTAssertEqual(state.errors.last?.surface, false)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testUnauthorizedSignsOutAndRecordsNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        await actions(onUnauthorized: { signedOut = true }).loadNextStudy(groupId: "g1")
        XCTAssertTrue(signedOut)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// A sign-out while the request is in flight retires the old session's result.
    func testSignOutMidLoadDropsTheResult() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        api.beforeReturn = { _, _ in self.state.clearAllData() }
        await actions().loadHistory(groupId: "g1")
        XCTAssertNil(state.historyByGroupId["g1"])
    }

    func testCancelledLoadWritesAndRecordsNothing() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        api.delayFor = { _ in 0.5 }
        let groupActions = actions()
        let task = Task { @MainActor in await groupActions.loadHistory(groupId: "g1") }
        task.cancel()
        await task.value
        XCTAssertNil(state.historyByGroupId["g1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    // MARK: - T13 days + chart

    /// D12/D14: the 30 local days ending today, filtered to the group.
    func testDaysCoverTheThirtyDaysEndingTodayForTheGroup() async {
        let path = "/api/home/days?from=2026-09-26&to=2026-10-25&tz=America/Denver&groupId=g1"
        api.stub("GET", path, json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]}]}"#)
        await actions().loadGroupDays(groupId: "g1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.groupDaysByGroupId["g1"]?.first?.sessionSeconds, 1530)
    }

    /// D21: two single-metric queries over today−29 … today+3, merged per day.
    func testChartRunsTwoSingleMetricQueriesAndMergesThem() async {
        api.stub("POST", "/api/analytics/query", json: analyticsJSON)
        await actions().loadGroupChart(groupId: "g1")
        let bodies = api.calls.filter { $0.endpoint == "/api/analytics/query" }.compactMap(\.body)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(Set(bodies.compactMap { ($0["metrics"] as? [String])?.joined() }), ["scheduled_lessons", "lesson_completions"])
        for body in bodies {
            XCTAssertEqual(body["dimensions"] as? [String], ["day"])
            XCTAssertEqual(body["timezone"] as? String, "America/Denver")
            let filters = body["filters"] as? [String: Any]
            XCTAssertEqual(filters?["groupId"] as? String, "g1")
            XCTAssertEqual(filters?["from"] as? String, "2026-09-26")
            XCTAssertEqual(filters?["to"] as? String, "2026-10-28")
        }
        XCTAssertEqual(state.groupChartByGroupId["g1"], GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2],
                                                                   completed: ["2026-10-25": 1, "2026-10-24": 2]))
    }

    /// D21: either query failing keeps the other series and records the error.
    func testChartKeepsTheSeriesThatLanded() async {
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: [:], completed: ["2026-10-01": 9])
        api.stub("POST", "/api/analytics/query", json: analyticsJSON)
        api.errorFor = { _, body in
            (body?["metrics"] as? [String]) == ["lesson_completions"] ? APIHTTPError(status: 500, message: "boom") : nil
        }
        await actions().loadGroupChart(groupId: "g1")
        XCTAssertEqual(state.groupChartByGroupId["g1"]?.scheduled, ["2026-10-25": 3, "2026-10-24": 2])
        XCTAssertEqual(state.groupChartByGroupId["g1"]?.completed, ["2026-10-01": 9])
        XCTAssertEqual(state.errors.last?.context, "GroupActions.loadGroupChart.completed")
    }

    func testByDayReadsOneMetricPerDay() {
        let rows: [[String: AnalyticsValue]] = [
            ["day": .string("2026-10-25"), "scheduled_lessons": .int(3)],
            ["day": .string("2026-10-24"), "scheduled_lessons": .double(2.0)],
            ["day": .null, "scheduled_lessons": .int(7)]
        ]
        XCTAssertEqual(GroupActions.byDay(rows, metric: "scheduled_lessons"), ["2026-10-25": 3, "2026-10-24": 2])
    }

    // MARK: - T18 my organizations

    func testMyOrganizationsLandForEveryRole() async {
        api.stub("GET", "/api/organizations/my/organizations",
                 json: #"{"success":true,"data":[{"id":"o1","name":"Grace Church"},{"id":"o2","name":"Hope Chapel"}]}"#)
        await actions().loadMyOrganizations()
        XCTAssertEqual(state.myOrganizations.map(\.name), ["Grace Church", "Hope Chapel"])
    }

    func testCancellationSeesThroughTheNetworkWrapper() {
        XCTAssertTrue(GroupActions.isCancellation(CancellationError()))
        XCTAssertTrue(GroupActions.isCancellation(APIError.networkError(URLError(.cancelled))))
        XCTAssertFalse(GroupActions.isCancellation(APIError.networkError(URLError(.timedOut))))
    }
}
