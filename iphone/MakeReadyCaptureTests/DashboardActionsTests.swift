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
}
