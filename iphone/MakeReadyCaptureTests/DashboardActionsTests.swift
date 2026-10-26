import XCTest
@testable import MakeReady

@MainActor
final class DashboardActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        api.stub("GET", "/api/preferences/dashboard.kpis", json: #"{"key":"dashboard.kpis","value":"","isDefault":true}"#)
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":3},{"day":"2026-10-25","lesson_completions":2}],"previousRows":[{"lesson_completions":4}]}"#)
    }

    func testSendsTimezoneOrgAndNoWindowOnSnapshot() async {
        state.organizationId = "org1"
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let bodies = api.calls.filter { $0.endpoint == "/api/analytics/query" }.compactMap(\.body)
        XCTAssertFalse(bodies.isEmpty)
        for b in bodies {
            XCTAssertEqual(b["timezone"] as? String, "America/Denver")
            XCTAssertEqual((b["filters"] as? [String: Any])?["organizationId"] as? String, "org1")
        }
        let snapshot = bodies.first { ($0["metrics"] as? [String]) == ["watch_seconds"] }
        XCTAssertNotNil(snapshot)
        XCTAssertNil((snapshot?["filters"] as? [String: Any])?["from"])
        XCTAssertNil(snapshot?["dimensions"])
    }

    func testNoOrgFilterWhenOrgUnknown() async {
        state.organizationId = nil
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        for b in api.calls.compactMap(\.body) { XCTAssertNil((b["filters"] as? [String: Any])?["organizationId"]) }
    }

    func testStoresCompletionsByDay() async {
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
        XCTAssertNotNil(state.dashboard.refreshedAt)
    }

    func testKeepsCacheOnFailure() async {
        state.dashboard.completedTotal = 9
        api.errorToThrow = URLError(.notConnectedToInternet)
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.completedTotal, 9)
    }

    func testUnauthorizedSignsOut() async {
        api.errorToThrow = APIError.unauthorized
        var signedOut = false
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: { signedOut = true }).refresh()
        XCTAssertTrue(signedOut)
    }

    func testLegacySnapshotWithoutDashboardDecodes() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacy = try encoder.encode(PersistedState(from: state))
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        XCTAssertNotNil(dict["dashboard"])
        dict.removeValue(forKey: "dashboard")
        let data = try JSONSerialization.data(withJSONObject: dict)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertNoThrow(try decoder.decode(PersistedState.self, from: data))
    }

    func testFractionalWatchSecondsRounds() async {
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":3,"watch_seconds":3600.5}]}"#)
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.watchSeconds, 3601)
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
    }

    func testNullMetricValueDoesNotThrow() async {
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":null},{"day":"2026-10-25","lesson_completions":2}]}"#)
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.activityDays["2026-10-25"], 2)
        XCTAssertNotNil(state.dashboard.refreshedAt)
    }

    func testWatchSecondsFailureKeepsActivity() async {
        api.errorFor = { _, body in (body?["metrics"] as? [String]) == ["watch_seconds"] ? APIError.serverError("boom") : nil }
        state.dashboard.watchSeconds = 42
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
        XCTAssertEqual(state.dashboard.watchSeconds, 42)
    }

    func testWatchSecondsUnauthorizedStillSignsOut() async {
        api.errorFor = { _, body in (body?["metrics"] as? [String]) == ["watch_seconds"] ? APIError.unauthorized : nil }
        var signedOut = false
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: { signedOut = true }).refresh()
        XCTAssertTrue(signedOut)
    }

    /// Final review M-5: a snapshot written before a DashboardSnapshot field existed must still
    /// decode — the dashboard keeps what it has, and nothing else in the snapshot is lost.
    func testDashboardMissingAFieldKeepsTheSnapshot() throws {
        state.organizationId = "org1"
        state.dashboard.completedTotal = 7
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: try encoder.encode(PersistedState(from: state))) as? [String: Any])
        var dashboard = try XCTUnwrap(dict["dashboard"] as? [String: Any])
        dashboard.removeValue(forKey: "kpiNames")
        dict["dashboard"] = dashboard
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistedState.self, from: try JSONSerialization.data(withJSONObject: dict))
        XCTAssertEqual(decoded.organizationId, "org1")
        XCTAssertEqual(decoded.dashboard.completedTotal, 7)
        XCTAssertEqual(decoded.dashboard.kpiNames, DashboardSnapshot().kpiNames)
    }

    /// Final review M-6: a refresh still in flight at sign-out must not write the old
    /// session's dashboard back into the cleared state.
    func testRefreshInFlightAtSignOutDropsItsWrite() async {
        await state.initialLoad.run { _ in }
        api.beforeReturn = { [state] _, body in
            if (body?["metrics"] as? [String]) == ["watch_seconds"] { state?.clearAllData() }   // sign-out lands mid-refresh
        }
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard, DashboardSnapshot())
    }

    /// The new sections persist with the rest of the app snapshot (cache-first, ui2-shell D20).
    func testNewDashboardSectionsPersist() throws {
        state.dashboard.scheduledDays = ["2026-10-24": 5]
        state.dashboard.sessions["all"] = HomeSessionsResponse(averageSeconds: 1920, sessionCount: 4, hourly: [], bins: [], ticks: [])
        state.dashboard.engagement = HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistedState.self, from: try encoder.encode(PersistedState(from: state)))
        XCTAssertEqual(decoded.dashboard, state.dashboard)
    }

    // MARK: - Task 9: the /api/home calls (home-dashboard-data §iphone)

    /// Canned /api/home + scheduled responses for now = 2026-10-25 (Denver): the 36-day window is
    /// 2026-09-27 … 2026-11-01.
    private func stubHome(org: String = "org1") {
        let q = "tz=America/Denver&organizationId=\(org)"
        api.stub("POST", "/api/analytics/query", json: #"{"success":true,"rows":[{"day":"2026-10-24","lesson_completions":3,"scheduled_lessons":5},{"day":"2026-10-25","lesson_completions":2,"scheduled_lessons":4}],"previousRows":[{"lesson_completions":4}]}"#)
        api.stub("GET", "/api/home/days?from=2026-09-27&to=2026-11-01&\(q)", json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]},{"day":"2026-10-25","sessionSeconds":0,"blocks":[0,0,0,0,0,0,0,0,0,0,0,0]}]}"#)
        api.stub("GET", "/api/home/engagement?\(q)", json: #"{"currentCount":7,"enrolledCount":12,"groupCount":3,"percent":58,"activeCount":9}"#)
        api.stub("GET", "/api/home/following?organizationId=\(org)", json: #"{"programs":[{"id":"p1","title":"Romans in 30 days","author":"Luke Keith","createdAt":"2026-07-08T18:00:00.123Z","groups":[{"enrollmentId":"e1","groupName":"Young professionals","photoUrl":null,"memberCount":9,"percent":55,"synced":true}]}]}"#)
        for (range, average) in [("all", 1920), ("year", 1500), ("month", 900), ("week", 630)] {
            api.stub("GET", "/api/home/sessions?range=\(range)&\(q)", json: sessionsJSON(average))
        }
    }

    private func sessionsJSON(_ average: Int) -> String {
        let hourly = Array(repeating: "0", count: 24).joined(separator: ",")
        let bins = Array(repeating: "0", count: 88).joined(separator: ",")
        return "{\"averageSeconds\":\(average),\"sessionCount\":4,\"hourly\":[\(hourly)],\"bins\":[\(bins)],"
            + "\"ticks\":[\"2026-10-19\",\"2026-10-21\",\"2026-10-23\",\"2026-10-25\"]}"
    }

    func testRefreshFillsEveryHomeSection() async {
        state.organizationId = "org1"
        stubHome()
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let d = state.dashboard
        XCTAssertEqual(d.scheduledDays, ["2026-10-24": 5, "2026-10-25": 4])
        XCTAssertEqual(d.dayMinutes["2026-10-24"], 26)                       // 1530 s = 25.5 → 26
        XCTAssertEqual(d.dayMinutes["2026-10-25"], 0)
        XCTAssertEqual(d.dayBlocks["2026-10-24"], [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0])
        XCTAssertEqual(d.engagement, HomeEngagementResponse(currentCount: 7, enrolledCount: 12, groupCount: 3, percent: 58, activeCount: 9))
        XCTAssertEqual(d.following?.programs.first?.groups.first?.groupName, "Young professionals")
        XCTAssertEqual(d.sessions.keys.sorted(), ["all", "month", "week", "year"])
        XCTAssertEqual(d.sessions["all"]?.averageSeconds, 1920)
        XCTAssertEqual(d.sessions["week"]?.averageSeconds, 630)
        XCTAssertEqual(d.activityDays["2026-10-24"], 3)                      // the old sections still land
        XCTAssertNotNil(d.refreshedAt)
    }

    func testScheduledQueryCoversTheChartWindow() async {
        state.organizationId = "org1"
        stubHome()
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let body = api.calls.compactMap(\.body).first { ($0["metrics"] as? [String]) == ["scheduled_lessons"] }
        let filters = body?["filters"] as? [String: Any]
        XCTAssertEqual(body?["dimensions"] as? [String], ["day"])
        XCTAssertEqual(filters?["from"] as? String, "2026-09-27")
        XCTAssertEqual(filters?["to"] as? String, "2026-11-01")
        XCTAssertEqual(filters?["organizationId"] as? String, "org1")
        XCTAssertEqual(body?["timezone"] as? String, "America/Denver")
        XCTAssertEqual(api.callCount("GET", "/api/home/days?from=2026-09-27&to=2026-11-01&tz=America/Denver&organizationId=org1"), 1)
        for range in DashboardActions.sessionRangeKeys {
            XCTAssertEqual(api.callCount("GET", "/api/home/sessions?range=\(range)&tz=America/Denver&organizationId=org1"), 1)
        }
    }

    /// A failed extra call is non-fatal: its cached section stays, everything else still lands.
    func testFailedExtraCallKeepsItsCachedSection() async {
        state.organizationId = "org1"
        stubHome()
        let cachedEngagement = HomeEngagementResponse(currentCount: 1, enrolledCount: 4, groupCount: 1, percent: 25, activeCount: 2)
        let cachedWeek = HomeSessionsResponse(averageSeconds: 42, sessionCount: 1, hourly: [], bins: [], ticks: [])
        state.dashboard.engagement = cachedEngagement
        state.dashboard.sessions["week"] = cachedWeek
        state.dashboard.scheduledDays = ["2026-10-20": 8]
        api.errorFor = { endpoint, body in
            if endpoint.hasPrefix("/api/home/engagement") || endpoint.hasPrefix("/api/home/sessions?range=week") {
                return APIError.serverError("boom")
            }
            if (body?["metrics"] as? [String]) == ["scheduled_lessons"] { return URLError(.timedOut) }
            return nil
        }
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        XCTAssertEqual(state.dashboard.engagement, cachedEngagement)
        XCTAssertEqual(state.dashboard.sessions["week"], cachedWeek)
        XCTAssertEqual(state.dashboard.scheduledDays, ["2026-10-20": 8])
        XCTAssertEqual(state.dashboard.sessions["all"]?.averageSeconds, 1920)
        XCTAssertEqual(state.dashboard.following?.programs.count, 1)
        XCTAssertEqual(state.dashboard.activityDays["2026-10-24"], 3)
        XCTAssertNotNil(state.dashboard.refreshedAt)
    }

    func testUnauthorizedExtraCallStillSignsOut() async {
        state.organizationId = "org1"
        stubHome()
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/home/following") ? APIError.unauthorized : nil }
        var signedOut = false
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: { signedOut = true }).refresh()
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.dashboard.refreshedAt)                            // nothing written
    }

    func testTimezoneIsPercentEncoded() async {
        XCTAssertEqual(DashboardActions.queryValue("Etc/GMT+5"), "Etc/GMT%2B5")
        XCTAssertEqual(DashboardActions.queryValue("America/Denver"), "America/Denver")
        XCTAssertEqual(DashboardActions.queryValue("a&b=c"), "a%26b%3Dc")
        state.organizationId = "org1"
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: TimeZone(identifier: "Etc/GMT+5")!).refresh()
        let engagement = api.calls.first { $0.endpoint.hasPrefix("/api/home/engagement") }?.endpoint
        XCTAssertEqual(engagement, "/api/home/engagement?tz=Etc/GMT%2B5&organizationId=org1")
    }

    func testNoOrganizationIdOnHomeCallsWhenOrgUnknown() async {
        state.organizationId = nil
        await DashboardActions(api: api, state: state, now: { self.now }, timeZone: tz).refresh()
        let home = api.calls.filter { $0.endpoint.hasPrefix("/api/home/") }.map(\.endpoint)
        XCTAssertEqual(home.count, 7)                                        // days, engagement, following, 4 × sessions
        XCTAssertTrue(home.allSatisfy { !$0.contains("organizationId") })
        XCTAssertTrue(home.contains("/api/home/following"))
    }
}
