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

    private func input(query: String = "", leader: String? = nil) -> InviteSelectGroupMapper.Input {
        .init(groups: groups, enrollmentCounts: ["g2": 2], query: query, leader: leader, loading: false, failed: false)
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

    func testLeaderFilterNarrowsAndLabelsTheChip() {
        let out = InviteSelectGroupMapper.output(input(leader: "Tony Stark"))
        XCTAssertEqual(out.groupIds, ["g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
    }

    func testLeaderOptionsAreDistinctNonEmptyAndSorted() {
        let more = groups + [group("g4", "Alpha", leader: "Tony Stark", members: 1)]
        let out = InviteSelectGroupMapper.output(.init(groups: more, enrollmentCounts: [:], query: "", leader: nil, loading: false, failed: false))
        XCTAssertEqual(out.leaderOptions, ["Pepper Potts", "Tony Stark"])
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
