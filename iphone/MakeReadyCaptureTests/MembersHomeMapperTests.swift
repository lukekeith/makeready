import XCTest
@testable import MakeReady

/// ui2-members-browse T13 (Members half): D6 labels, D7/D15 chips, the [id] snapshot behind
/// every index the screen renders.
final class MembersHomeMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Oct 25, noon MDT
    private let groups = [MembersHomeMapper.Option(id: "g1", label: "The kids"),
                          MembersHomeMapper.Option(id: "g2", label: "Young professionals")]
    private let leaders = [MembersHomeMapper.Option(id: "u1", label: "Luke Keith"),
                           MembersHomeMapper.Option(id: "u2", label: "Scott Stickane")]

    private func member(_ id: String, _ first: String?, _ last: String?, joined: String = "2026-10-25T07:00:00.000Z",
                        photo: String? = nil, google: String? = nil, groupCount: Int = 0) -> OrgMemberListItem {
        OrgMemberListItem(id: id, firstName: first, lastName: last, profilePicture: photo,
                          googlePicture: google, joinedAt: joined, groupCount: groupCount)
    }

    private func map(_ directory: OrgMemberDirectory?, _ selection: MembersHomeMapper.Selection = .init()) -> MembersHomeMapper.Output {
        MembersHomeMapper.output(directory: directory, groups: groups, leaders: leaders,
                                 selection: selection, today: today, timeZone: tz)
    }

    /// D6, every cut, by LOCAL calendar-day age (Denver).
    func testJoinedLabelAtEveryCut() {
        let cases: [(iso: String, label: String)] = [
            ("2026-10-25T07:00:00.000Z", "Joined Today"),             // Oct 25 01:00 local
            ("2026-10-25T05:59:00.000Z", "Joined Yesterday"),         // Oct 24 23:59 local — tz, not UTC
            ("2026-10-23T18:00:00Z", "Joined 2 days ago"),
            ("2026-10-19T18:00:00Z", "Joined 6 days ago"),
            ("2026-10-18T18:00:00Z", "Joined 1 week ago"),
            ("2026-10-12T18:00:00Z", "Joined 1 week ago"),            // 13 days
            ("2026-10-11T18:00:00Z", "Joined 2 weeks ago"),           // 14 days
            ("2026-09-26T18:00:00Z", "Joined 4 weeks ago"),           // 29 days
            ("2026-09-25T18:00:00Z", "Joined Sep 25, 2026"),          // 30 days — the absolute cut
            ("2025-01-05T18:00:00.000Z", "Joined Jan 5, 2025"),
            ("2026-10-26T18:00:00Z", "Joined Today"),                 // a future stamp clamps to today
            ("garbage", "")
        ]
        for c in cases {
            XCTAssertEqual(MembersHomeMapper.joinedLabel(c.iso, today: today, timeZone: tz), c.label, c.iso)
        }
    }

    /// D6: the server's order is the list's order; T13: every row index resolves to its id.
    func testRowsKeepServerOrderAndResolveToIds() {
        let out = map(OrgMemberDirectory(members: [
            member("m2", "Clark", "Kent", groupCount: 1),
            member("m1", "Barry", "Allen", groupCount: 2)
        ]))
        XCTAssertEqual(out.state.memberNames, ["Clark Kent", "Barry Allen"])
        XCTAssertEqual(out.memberIds, ["m2", "m1"])
        XCTAssertEqual(out.state.memberGroupCounts, [1, 2])
        XCTAssertEqual(out.memberId(atRow: 1), "m1")
        XCTAssertNil(out.memberId(atRow: 2))
    }

    func testPhotoFallsBackToGoogleThenToInitials() {
        let out = map(OrgMemberDirectory(members: [
            member("m1", "Barry", "Allen", photo: "https://cdn.example/b.jpg", google: "https://lh3.example/b.jpg"),
            member("m2", "Clark", "Kent", photo: "", google: "https://lh3.example/c.jpg"),
            member("m3", "Cher", nil)
        ]))
        XCTAssertEqual(out.state.memberPhotoURLs, ["https://cdn.example/b.jpg", "https://lh3.example/c.jpg", ""])
        XCTAssertEqual(out.state.memberInitials, ["BA", "CK", "CH"])
        XCTAssertEqual(out.state.memberNames, ["Barry Allen", "Clark Kent", "Cher"])
    }

    func testNamesAndInitialsHelpers() {
        XCTAssertEqual(MembersHomeMapper.displayName(first: " Tony ", last: "Stark"), "Tony Stark")
        XCTAssertEqual(MembersHomeMapper.displayName(first: nil, last: nil), "")
        XCTAssertEqual(MembersHomeMapper.initials(first: "tony", last: "stark"), "TS")
        XCTAssertEqual(MembersHomeMapper.initials(first: nil, last: "Stark"), "ST")
        XCTAssertEqual(MembersHomeMapper.initials(first: nil, last: nil), "")
    }

    /// D7/D15 + filter-multiselect D3: no "All …" rows; ids ride beside the labels.
    func testAnOwnerSeesEveryGroupAndTheLeaderChip() {
        for scope in [ViewerScope(all: true, groupIds: []), nil] {
            let out = map(OrgMemberDirectory(viewerScope: scope))
            XCTAssertTrue(out.state.showsLeaderFilter)
            XCTAssertEqual(out.state.groupOptions, ["The kids", "Young professionals"])
            XCTAssertEqual(out.state.groupOptionIDs, ["g1", "g2"])
            XCTAssertEqual(out.state.leaderOptions, ["Luke Keith", "Scott Stickane"])
            XCTAssertEqual(out.state.leaderOptionIDs, ["u1", "u2"])
        }
    }

    func testAScopedLeaderSeesOnlyTheirGroupsAndNoLeaderChip() {
        let out = map(OrgMemberDirectory(viewerScope: ViewerScope(all: false, groupIds: ["g2"])))
        XCTAssertFalse(out.state.showsLeaderFilter)
        XCTAssertEqual(out.state.groupOptions, ["Young professionals"])
        XCTAssertEqual(out.state.groupOptionIDs, ["g2"])
    }

    /// filter-multiselect D4: 0 / 1 / many picks.
    func testChipLabelsFollowTheSelection() {
        var selection = MembersHomeMapper.Selection(search: "kent")
        var out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.searchText, "kent")
        XCTAssertEqual(out.state.groupFilterLabel, "Groups")
        XCTAssertEqual(out.state.leaderFilterLabel, "Leaders")
        XCTAssertEqual(out.state.selectedGroupIDs, [])
        selection.groupIds = ["g2"]
        selection.leaderIds = ["u1", "u2"]
        out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.groupFilterLabel, "Young professionals")
        XCTAssertEqual(out.state.leaderFilterLabel, "2 leaders")
        XCTAssertEqual(out.state.selectedGroupIDs, ["g2"])
        XCTAssertEqual(out.state.selectedLeaderIDs, ["u1", "u2"])
        selection.groupIds = ["g1", "g2", "gone"]
        out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.groupFilterLabel, "2 groups")              // an id no longer listed is not counted
        XCTAssertEqual(out.state.selectedGroupIDs, ["g1", "g2"])
    }

    /// filter-multiselect D15: two options with the same label stay two ids.
    func testSameNamedOptionsStayDistinct() {
        let twins = [MembersHomeMapper.Option(id: "u7", label: "Group Leader"),
                     MembersHomeMapper.Option(id: "u8", label: "Group Leader")]
        let out = MembersHomeMapper.output(directory: OrgMemberDirectory(), groups: groups, leaders: twins,
                                           selection: .init(leaderIds: ["u8"]), today: today, timeZone: tz)
        XCTAssertEqual(out.state.leaderOptionIDs, ["u7", "u8"])
        XCTAssertEqual(out.state.selectedLeaderIDs, ["u8"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Group Leader")
    }

    /// F5: no directory yet renders the empty list with the header live.
    func testNoDirectoryYetIsAnEmptyList() {
        let out = map(nil)
        XCTAssertEqual(out.state.memberNames, [])
        XCTAssertEqual(out.memberIds, [])
        XCTAssertTrue(out.state.showsLeaderFilter)
        XCTAssertEqual(out.state.groupFilterLabel, "Groups")
    }

    func testParseDateTakesFractionalAndPlainStamps() {
        XCTAssertNotNil(MembersHomeMapper.parseDate("2026-07-05T14:03:22.123Z"))
        XCTAssertNotNil(MembersHomeMapper.parseDate("2026-07-05T14:03:22Z"))
        XCTAssertNil(MembersHomeMapper.parseDate("July 5"))
        XCTAssertEqual(MembersHomeMapper.mediumDate(try XCTUnwrap(MembersHomeMapper.parseDate("2025-01-05T18:00:00Z")), timeZone: tz), "Jan 5, 2025")
    }

    func testContainerOptionsAndDebounce() {
        let epoch = Date(timeIntervalSince1970: 0)
        func group(_ id: String, _ name: String) -> UserGroup {
            UserGroup(id: id, code: "ABC123", name: name, isPrivate: false, allowInvites: true,
                      memberCount: 1, creatorId: "u1", createdAt: epoch, updatedAt: epoch)
        }
        XCTAssertEqual(MembersHomeContainer.groupOptions([group("g2", "Young professionals"), group("g1", "the kids")]),
                       [MembersHomeMapper.Option(id: "g1", label: "the kids"),
                        MembersHomeMapper.Option(id: "g2", label: "Young professionals")])
        let leaders = [
            GroupLeader(id: "u2", firstName: "Scott", lastName: "Stickane", avatarUrl: nil, programCount: 0, mediaCount: 0),
            GroupLeader(id: "u1", firstName: "Luke", lastName: "Keith", avatarUrl: nil, programCount: 2, mediaCount: 0)
        ]
        XCTAssertEqual(MembersHomeContainer.leaderOptions(leaders).map(\.id), ["u2", "u1"])   // server order
        XCTAssertEqual(MembersHomeContainer.searchDebounce, .milliseconds(300))
    }
}
