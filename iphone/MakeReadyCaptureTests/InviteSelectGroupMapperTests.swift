import XCTest
@testable import MakeReady

/// invite-member D3/D14/D16: the picker rows, chips, search and Leaders filter, all local.
final class InviteSelectGroupMapperTests: XCTestCase {
    private func group(_ id: String, _ name: String, leader: String?, members: Int, cover: String? = nil) -> UserGroup {
        UserGroup(id: id, code: "C\(id)", name: name, coverImageUrl: cover, isPrivate: false, allowInvites: false,
                  memberCount: members, creatorId: "u-\(id)", creatorName: leader, createdAt: Date(), updatedAt: Date())
    }

    private var groups: [UserGroup] {
        [group("g1", "youth night", leader: "Tony Stark", members: 4),
         group("g2", "Prayer Team", leader: "Pepper Potts", members: 14, cover: "https://img/p.jpg"),
         group("g3", "Men's Study", leader: nil, members: 0)]
    }

    private func input(query: String = "", leaderIds: Set<String> = []) -> InviteSelectGroupMapper.Input {
        .init(groups: groups, enrollmentCounts: ["g2": 2], query: query, leaderIds: leaderIds, loading: false, failed: false)
    }

    func testRowsAreAlphabeticalWithEveryChip() {
        let out = InviteSelectGroupMapper.output(input())
        XCTAssertEqual(out.state.groupNames, ["Men's Study", "Prayer Team", "youth night"])
        XCTAssertEqual(out.groupIds, ["g3", "g2", "g1"])
        XCTAssertEqual(out.state.groupLeaderNames, ["", "Pepper Potts", "Tony Stark"])
        XCTAssertEqual(out.state.groupMemberCounts, [0, 14, 4])
        XCTAssertEqual(out.state.groupEnrollmentCounts, [0, 2, 0])
        XCTAssertEqual(out.state.groupPhotoURLs, ["", "https://img/p.jpg", ""])
        XCTAssertEqual(out.state.selectedIndex, -1)
        XCTAssertFalse(out.state.orgFilterVisible)                      // D16
        XCTAssertEqual(out.state.leaderFilterLabel, "Leaders")
        XCTAssertEqual(out.state.orgFilterLabel, "Orgs")
    }

    func testSearchFiltersByNameCaseInsensitively() {
        let out = InviteSelectGroupMapper.output(input(query: "PRAY"))
        XCTAssertEqual(out.groupIds, ["g2"])
        XCTAssertEqual(out.state.searchText, "PRAY")
    }

    /// filter-multiselect D5/D13/D4: any of the picked creators; the chip summarises.
    func testLeaderFilterNarrowsByCreatorIdAndLabelsTheChip() {
        var out = InviteSelectGroupMapper.output(input(leaderIds: ["u-g1"]))
        XCTAssertEqual(out.groupIds, ["g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
        out = InviteSelectGroupMapper.output(input(leaderIds: ["u-g1", "u-g2"]))
        XCTAssertEqual(out.groupIds, ["g2", "g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "2 leaders")
    }

    /// D13: one option per creator id with a name — same-named creators stay two options.
    func testLeaderOptionsAreOnePerCreatorAndSorted() {
        let more = groups + [group("g4", "Alpha", leader: "Tony Stark", members: 1)]
        let out = InviteSelectGroupMapper.output(.init(groups: more, enrollmentCounts: [:], query: "", leaderIds: [], loading: false, failed: false))
        XCTAssertEqual(out.leaderOptions.map(\.label), ["Pepper Potts", "Tony Stark", "Tony Stark"])
        XCTAssertEqual(out.leaderOptions.map(\.id), ["u-g2", "u-g1", "u-g4"])
    }

    func testLoadingAndFailedPassThrough() {
        var i = input()
        i.loading = true
        i.failed = true
        let out = InviteSelectGroupMapper.output(i)
        XCTAssertTrue(out.state.loading)
        XCTAssertTrue(out.state.failed)
    }
}

@MainActor
final class InviteSelectGroupEnrollmentLoadTests: XCTestCase {
    func testLoadsOnlyGroupsWithoutCachedEnrollments() async {
        StatePersistence.shared.clear()
        let state = AppState()
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g2/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        await InviteSelectGroupContainer.loadEnrollmentCounts(for: ["g1", "g2"], state: state, api: api)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/enrollments"), 0)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g2/enrollments"), 1)
    }
}
