import XCTest
@testable import MakeReady

/// ui2-groups-browse D3/D20/D22: the Groups section from `AppState.groups`.
@MainActor
final class GroupsHomeMapperTests: XCTestCase {
    private let stamp = ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!

    private func group(_ id: String, _ name: String, creator: String = "u1", creatorName: String? = "Luke Keith",
                       org: String? = "o1", members: Int = 3, cover: String? = nil) -> UserGroup {
        UserGroup(id: id, code: "C\(id)", name: name, coverImageUrl: cover, isPrivate: false, allowInvites: true,
                  memberCount: members, creatorId: creator, creatorName: creatorName, organizationId: org,
                  createdAt: stamp, updatedAt: stamp)
    }

    private func leader(_ id: String, _ first: String, _ last: String) -> GroupLeader {
        GroupLeader(id: id, firstName: first, lastName: last, avatarUrl: nil, programCount: 0, mediaCount: 0)
    }

    private let orgs = [OrganizationData(id: "o1", name: "Grace Church"), OrganizationData(id: "o2", name: "Hope Chapel")]

    private func output(_ groups: [UserGroup], leaders: [GroupLeader] = [], organizations: [OrganizationData]? = nil,
                        selection: GroupsHomeMapper.Selection = .init(), loaded: Bool = true) -> GroupsHomeMapper.Output {
        GroupsHomeMapper.output(groups: groups, leaders: leaders, organizations: organizations ?? orgs,
                                selection: selection, typedSearch: selection.search, loaded: loaded)
    }

    /// D3: by name, case- and diacritic-insensitive.
    func testRowsSortByNameIgnoringCaseAndDiacritics() {
        let out = output([group("1", "zeta"), group("2", "Émile"), group("3", "alpha"), group("4", "Beta")])
        XCTAssertEqual(out.state.groupNames, ["alpha", "Beta", "Émile", "zeta"])
        XCTAssertEqual(out.groupIds, ["3", "4", "2", "1"])
        XCTAssertEqual(out.groupId(atRow: 1), "4")
        XCTAssertNil(out.groupId(atRow: 9))
    }

    /// D3: case-insensitive substring of the name, trimmed.
    func testSearchIsACaseInsensitiveSubstring() {
        let out = output([group("1", "zeta"), group("2", "Beta"), group("3", "alpha")],
                         selection: .init(search: "  ETA "))
        XCTAssertEqual(out.state.groupNames, ["Beta", "zeta"])
        XCTAssertTrue(GroupsHomeMapper.matches("Young Pros", search: ""))
        XCTAssertFalse(GroupsHomeMapper.matches("Young Pros", search: "old"))
    }

    /// D3: search AND leaders AND orgs; a pick maps its label to every id with that label.
    func testChipsAndSearchCombineWithAnd() {
        let groups = [
            group("1", "Alpha Men", creator: "u1", org: "o1"),
            group("2", "Alpha Women", creator: "u2", org: "o1"),
            group("3", "Alpha Youth", creator: "u1", org: "o2"),
            group("4", "Beta", creator: "u1", org: "o1")
        ]
        let leaders = [leader("u1", "Tony", "Stark"), leader("u2", "Pepper", "Potts")]
        let out = output(groups, leaders: leaders,
                         selection: .init(search: "alpha", orgLabels: ["Grace Church"], leaderLabels: ["Tony Stark"]))
        XCTAssertEqual(out.state.groupNames, ["Alpha Men"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
        XCTAssertEqual(out.state.orgFilterLabel, "Grace Church")
        XCTAssertEqual(out.state.selectedLeaders, ["Tony Stark"])
        XCTAssertEqual(out.state.selectedOrgs, ["Grace Church"])
    }

    /// D3: two leaders with one name are one option and select together.
    func testSameNamedLeadersSelectTogether() {
        let groups = [group("1", "A", creator: "u1"), group("2", "B", creator: "u9"), group("3", "C", creator: "u2")]
        let leaders = [leader("u1", "Sam", "Lee"), leader("u9", "Sam", "Lee"), leader("u2", "Ann", "Ray")]
        let out = output(groups, leaders: leaders, selection: .init(leaderLabels: ["Sam Lee"]))
        XCTAssertEqual(out.state.leaderOptions, ["Sam Lee", "Ann Ray"])
        XCTAssertEqual(out.state.groupNames, ["A", "B"])
    }

    /// D3: an empty selection is "all"; two picks read "2 leaders".
    func testChipLabels() {
        let leaders = [leader("u1", "Tony", "Stark"), leader("u2", "Pepper", "Potts")]
        XCTAssertEqual(output([], leaders: leaders).state.leaderFilterLabel, "All Leaders")
        XCTAssertEqual(output([], leaders: leaders).state.orgFilterLabel, "All Orgs")
        XCTAssertEqual(output([], leaders: leaders, selection: .init(leaderLabels: ["Tony Stark", "Pepper Potts"]))
            .state.leaderFilterLabel, "2 leaders")
    }

    /// D3: the Orgs chip shows only with ≥2 orgs, and a hidden chip filters nothing.
    func testOrgChipNeedsTwoOrgs() {
        XCTAssertTrue(output([]).state.orgFilterVisible)
        let one = output([group("1", "A", org: "o2")], organizations: [orgs[0]], selection: .init(orgLabels: ["Grace Church"]))
        XCTAssertFalse(one.state.orgFilterVisible)
        XCTAssertEqual(one.state.groupNames, ["A"])
        XCTAssertEqual(one.state.orgOptions, ["Grace Church"])
    }

    /// D20: the leader slot is the short name; D3: cover, member count.
    func testRowShowsShortLeaderNameCoverAndCount() {
        let out = output([group("1", "A", creatorName: "Luke Keith", members: 25, cover: "https://img/a.jpg"),
                          group("2", "B", creatorName: nil, members: 0)])
        XCTAssertEqual(out.state.groupLeaderNames, ["L. Keith", ""])
        XCTAssertEqual(out.state.groupPhotoURLs, ["https://img/a.jpg", ""])
        XCTAssertEqual(out.state.groupMemberCounts, [25, 0])
    }

    /// D22: loading draws nothing; zero groups and no match each get their line.
    func testEmptyLines() {
        XCTAssertEqual(output([], loaded: false).state.listEmpty, "")
        XCTAssertEqual(output([], loaded: true).state.listEmpty, "noGroups")
        XCTAssertEqual(output([group("1", "Alpha")], selection: .init(search: "zzz")).state.listEmpty, "noMatch")
        XCTAssertEqual(output([group("1", "Alpha")]).state.listEmpty, "")
    }

    /// D22 + ui2-shell D28: a failed load surfaces the banner; a 401 signs out instead.
    func testLoadFailureRouting() async {
        let state = AppState()
        var signedOut = false
        await GroupsHomeContainer.route(APIError.unauthorized, context: "GroupsHomeContainer.loadGroups", surface: true,
                                        state: state, onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
        await GroupsHomeContainer.route(APIError.serverError("boom"), context: "GroupsHomeContainer.loadGroups", surface: true,
                                        state: state, onUnauthorized: {})
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't load your groups")
        await GroupsHomeContainer.route(CancellationError(), context: "x", surface: true, state: state, onUnauthorized: {})
        XCTAssertEqual(state.errors.count, 1)
    }
    /// A stub whose leaders and orgs load and whose groups fail with `groupsError`.
    private func failingGroupsAPI(_ groupsError: Error) -> StubAPIClient {
        let api = StubAPIClient()
        api.stub("GET", "/api/group-leaders", json: #"{"success":true,"leaders":[]}"#)
        api.stub("GET", "/api/organizations/my/organizations", json: #"{"success":true,"data":[]}"#)
        api.errorFor = { endpoint, _ in endpoint == "/api/groups" ? groupsError : nil }
        return api
    }

    /// D22: with groups already cached, a failed load still fetches and surfaces the banner over them.
    func testLoadWithCacheSurfacesAFailure() async {
        let state = AppState()
        state.groups.replaceAll([group("1", "Alpha")])
        let api = failingGroupsAPI(APIError.serverError("boom"))
        let ok = await GroupsHomeContainer.load(api: api, state: state, onUnauthorized: {})
        XCTAssertFalse(ok)
        XCTAssertEqual(api.callCount("GET", "/api/groups"), 1)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't load your groups")
        XCTAssertEqual(state.groups.all.map(\.id), ["1"])
    }

    /// D22: a failed first load leaves the list unloaded; the shell's static refresh then loading zero
    /// groups marks it loaded in `AppState`, so the section reads "No groups yet", not a blank list.
    func testFailedLoadThenEmptyRefreshShowsNoGroups() async {
        let state = AppState()
        let api = failingGroupsAPI(APIError.serverError("boom"))
        let failed = await GroupsHomeContainer.load(api: api, state: state, onUnauthorized: {})
        XCTAssertFalse(failed)
        XCTAssertFalse(state.groupsListLoaded)

        api.errorFor = nil
        api.stub("GET", "/api/groups", json: #"{"success":true,"groups":[]}"#)
        let refreshed = await GroupsHomeContainer.load(api: api, state: state, onUnauthorized: {})
        XCTAssertTrue(refreshed)
        XCTAssertTrue(state.groupsListLoaded)
        XCTAssertEqual(output(state.groups.all, loaded: state.groupsListLoaded).state.listEmpty, "noGroups")
    }

    /// ui2-shell D28: with groups already cached, a 401 signs out instead of showing stale data.
    func testLoadWithCacheSignsOutOn401() async {
        let state = AppState()
        state.groups.replaceAll([group("1", "Alpha")])
        var signOuts = 0
        let ok = await GroupsHomeContainer.load(api: failingGroupsAPI(APIError.unauthorized), state: state,
                                                onUnauthorized: { signOuts += 1 })
        XCTAssertFalse(ok)
        XCTAssertEqual(signOuts, 1)
        XCTAssertNil(state.activeSurfacedError)
    }
}
