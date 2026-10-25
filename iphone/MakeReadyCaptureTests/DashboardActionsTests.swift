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
}
