import XCTest
@testable import MakeReady

/// ui2-groups-browse T14: the group page's stores live in memory only and leave with the
/// session — sign-out and environment switch go through `clearInMemory()`.
@MainActor
final class GroupStoresTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func seed() {
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1", dayNumber: 3, title: "Faith over fear")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1", text: "Held event at Riverside Park")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25", sessionSeconds: 60)]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 3], completed: ["2026-10-25": 1])
        state.myOrganizations = [OrganizationData(id: "o1", name: "Grace Church"), OrganizationData(id: "o2", name: "Hope Chapel")]
        state.groupsListLoaded = true
        state.pendingJoinRequestsByGroupId["g1"] = [
            JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: Date(),
                        member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: "Stark", avatarUrl: nil))
        ]
    }

    func testClearAllDataEmptiesEveryGroupPageStore() {
        seed()
        state.clearAllData()
        XCTAssertTrue(state.nextStudyByGroupId.isEmpty)
        XCTAssertTrue(state.historyByGroupId.isEmpty)
        XCTAssertTrue(state.groupDaysByGroupId.isEmpty)
        XCTAssertTrue(state.groupChartByGroupId.isEmpty)
        XCTAssertTrue(state.myOrganizations.isEmpty)
        XCTAssertTrue(state.pendingJoinRequestsByGroupId.isEmpty)    // pre-existing leak (SPEC §iphone)
        XCTAssertFalse(state.groupsListLoaded)
    }

    func testEnvironmentSwitchEmptiesThemToo() {
        seed()
        state.reloadForEnvironmentSwitch()
        XCTAssertTrue(state.nextStudyByGroupId.isEmpty)
        XCTAssertTrue(state.groupChartByGroupId.isEmpty)
        XCTAssertTrue(state.myOrganizations.isEmpty)
    }

    /// T14: the stores never reach the device's disk cache.
    func testGroupPageStoresNeverReachTheDiskCache() throws {
        seed()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(PersistedState(from: state)), as: UTF8.self)
        for marker in ["Faith over fear", "Riverside Park", "Hope Chapel"] {
            XCTAssertFalse(json.contains(marker), marker)
        }
    }
}
