import XCTest
@testable import MakeReady

/// ui2-groups-edit D10/T4: a deleted group leaves no row behind in any store keyed by or listing it.
@MainActor
final class GroupDeleteCleanupTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

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

    private func group(_ id: String) -> UserGroup {
        UserGroup(id: id, code: "ABC123", name: id, isPrivate: false, allowInvites: true, memberCount: 0,
                  creatorId: "u1", createdAt: Date(), updatedAt: Date())
    }

    private func seed() {
        state.groups.upsert(group("g1"))
        state.groups.upsert(group("g2"))
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1", dayNumber: 3, title: "Faith over fear")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1", text: "Held event")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25", sessionSeconds: 60)]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 3], completed: [:])
        state.pendingJoinRequestsByGroupId["g1"] = []
        state.nextStudyByGroupId["g2"] = NextStudy(id: "s2", dayNumber: 1, title: "Keep me")
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1", name: "g1"), MemberGroupItem(id: "g2", name: "g2")]
        state.memberGroupsById["m2"] = [MemberGroupItem(id: "g1", name: "g1")]
        state.dashboard.following = HomeFollowingResponse(programs: [
            HomeFollowedProgram(id: "p1", title: "Only g1", groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "g1")]),
            HomeFollowedProgram(id: "p2", title: "Both", groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "g1"),
                                                                    HomeFollowedGroup(enrollmentId: "e9", groupName: "g2")]),
        ])
    }

    func testForgetGroupClearsEveryStoreForThatGroupOnly() {
        seed()
        GroupActions(api: api, state: state).forgetGroup(id: "g1")
        XCTAssertNil(state.groups["g1"])
        XCTAssertNotNil(state.groups["g2"])
        XCTAssertNil(state.nextStudyByGroupId["g1"])
        XCTAssertNil(state.historyByGroupId["g1"])
        XCTAssertNil(state.groupDaysByGroupId["g1"])
        XCTAssertNil(state.groupChartByGroupId["g1"])
        XCTAssertNil(state.pendingJoinRequestsByGroupId["g1"])
        XCTAssertNil(state.groupInvitesByGroupId["g1"])
        XCTAssertEqual(state.nextStudyByGroupId["g2"]?.title, "Keep me")
        XCTAssertEqual(state.memberGroupsById["m1"]?.map(\.id), ["g2"])
        XCTAssertEqual(state.memberGroupsById["m2"]?.map(\.id), [])
        XCTAssertEqual(state.dashboard.following?.programs.map(\.id), ["p2"])
        XCTAssertEqual(state.dashboard.following?.programs.first?.groups.map(\.enrollmentId), ["e9"])
        XCTAssertTrue(state.groupEnrollmentIndex.get("g1").isEmpty)
    }

    func testDeleteGroupCallsDeleteThenForgets() async throws {
        seed()
        api.stub("DELETE", "/api/groups/g1", json: #"{"success":true,"message":"Group deleted"}"#)
        try await GroupActions(api: api, state: state).deleteGroup(id: "g1")
        XCTAssertEqual(api.callCount("DELETE", "/api/groups/g1"), 1)
        XCTAssertNil(state.groups["g1"])
        XCTAssertNil(state.nextStudyByGroupId["g1"])
    }

    func testAFailedDeleteKeepsEverything() async {
        seed()
        api.errorToThrow = APIError.serverError("Failed to delete group")
        do {
            try await GroupActions(api: api, state: state).deleteGroup(id: "g1")
            XCTFail("expected a throw")
        } catch {}
        XCTAssertNotNil(state.groups["g1"])
        XCTAssertNotNil(state.nextStudyByGroupId["g1"])
    }
}
