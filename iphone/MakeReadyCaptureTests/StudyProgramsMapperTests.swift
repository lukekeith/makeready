import XCTest
@testable import MakeReady

/// ui2-programs D3/D4: the Programs section from `AppState.orderedPrograms`.
@MainActor
final class StudyProgramsMapperTests: XCTestCase {
    private func program(_ id: String, _ name: String, updated: TimeInterval = 0, creator: String? = "u1",
                         leader: String? = nil, org: String? = "o1", enrolled: Int? = nil,
                         cover: String? = nil, description: String? = nil) -> StudyProgram {
        StudyProgram(id: id, name: name, description: description, coverImageUrl: cover, creatorId: creator,
                     updatedAt: Date(timeIntervalSince1970: updated),
                     _count: enrolled.map { ProgramCount(lessons: nil, enrollments: $0) },
                     leaderId: leader, organizationId: org)
    }

    private func leader(_ id: String, _ first: String, _ last: String) -> GroupLeader {
        GroupLeader(id: id, firstName: first, lastName: last, avatarUrl: nil, programCount: 0, mediaCount: 0)
    }

    private let orgs = [OrganizationData(id: "o1", name: "Grace Church"), OrganizationData(id: "o2", name: "Hope Chapel")]

    private func output(_ programs: [StudyProgram], leaders: [GroupLeader] = [], organizations: [OrganizationData]? = nil,
                        selection: StudyProgramsMapper.Selection = .init(), loaded: Bool = true,
                        failed: Bool = false) -> StudyProgramsMapper.Output {
        StudyProgramsMapper.output(programs: programs, leaders: leaders, organizations: organizations ?? orgs,
                                   selection: selection, typedSearch: "", loaded: loaded, failed: failed)
    }

    /// D3: rows in `updatedAt` order, newest first; a row maps back to its id.
    func testRowsAreNewestFirstAndMapBackToIds() {
        let out = output([program("a", "Old", updated: 1), program("b", "New", updated: 3), program("c", "Mid", updated: 2)])
        XCTAssertEqual(out.state.programTitles, ["New", "Mid", "Old"])
        XCTAssertEqual(out.programIds, ["b", "c", "a"])
        XCTAssertEqual(out.programId(atRow: 2), "a")
        XCTAssertNil(out.programId(atRow: 3))
    }

    /// D3: a row's description, cover and "«n» enrolled" count (nil count reads 0).
    func testRowFields() {
        let out = output([program("a", "Walk", enrolled: 4, cover: "https://img/a.jpg", description: "Daily"),
                          program("b", "Run", updated: -1)])
        XCTAssertEqual(out.state.programDescriptions, ["Daily", ""])
        XCTAssertEqual(out.state.programCoverURLs, ["https://img/a.jpg", ""])
        XCTAssertEqual(out.state.programEnrollmentCounts, [4, 0])
    }

    /// D3: a leader pick matches the program's leader OR its creator; two same-named leaders
    /// select together.
    func testLeaderChipMatchesLeaderOrCreator() {
        let leaders = [leader("u1", "Luke", "Keith"), leader("u2", "Nathan", "Lee"), leader("u3", "Nathan", "Lee")]
        let programs = [program("a", "Led", updated: 3, creator: "u9", leader: "u2"),
                        program("b", "Made", updated: 2, creator: "u3"),
                        program("c", "Other", updated: 1, creator: "u1", leader: "u1")]
        var selection = StudyProgramsMapper.Selection()
        selection.leaderLabels = ["Nathan Lee"]
        let out = output(programs, leaders: leaders, selection: selection)
        XCTAssertEqual(out.programIds, ["a", "b"])
        XCTAssertEqual(out.state.selectedLeaders, ["Nathan Lee"])
        XCTAssertEqual(out.state.leaderOptions, ["Luke Keith", "Nathan Lee"])
    }

    /// D3: the Orgs chip shows with 2+ orgs and filters by `organizationId`; chips AND together.
    func testOrgChipAndChipsCombineWithAnd() {
        let leaders = [leader("u1", "Luke", "Keith")]
        let programs = [program("a", "A", updated: 3, creator: "u1", org: "o1"),
                        program("b", "B", updated: 2, creator: "u1", org: "o2"),
                        program("c", "C", updated: 1, creator: "u9", org: "o2")]
        var selection = StudyProgramsMapper.Selection()
        selection.orgLabels = ["Hope Chapel"]
        XCTAssertEqual(output(programs, leaders: leaders, selection: selection).programIds, ["b", "c"])
        selection.leaderLabels = ["Luke Keith"]
        let out = output(programs, leaders: leaders, selection: selection)
        XCTAssertEqual(out.programIds, ["b"])
        XCTAssertTrue(out.state.orgFilterVisible)
        XCTAssertEqual(out.state.orgOptions, ["Grace Church", "Hope Chapel"])
    }

    /// D3: one org hides the Orgs chip, and a stale org pick then filters nothing.
    func testOneOrgHidesTheChipAndIgnoresItsPick() {
        var selection = StudyProgramsMapper.Selection()
        selection.orgLabels = ["Hope Chapel"]
        let out = output([program("a", "A", org: "o1")], organizations: [orgs[0]], selection: selection)
        XCTAssertFalse(out.state.orgFilterVisible)
        XCTAssertEqual(out.programIds, ["a"])
    }

    /// D4: no cache and not loaded = loading; a failed first load with no cache = failed;
    /// a failure with a cache keeps the rows.
    func testLoadingAndFailedStates() {
        XCTAssertTrue(output([], loaded: false).state.loading)
        XCTAssertFalse(output([], loaded: true).state.loading)
        XCTAssertFalse(output([program("a", "A")], loaded: false).state.loading)
        let failed = output([], loaded: false, failed: true).state
        XCTAssertTrue(failed.failed)
        XCTAssertFalse(failed.loading)
        let cached = output([program("a", "A")], loaded: false, failed: true).state
        XCTAssertFalse(cached.failed)
        XCTAssertEqual(cached.programTitles, ["A"])
    }

    /// D3: the typed text reaches the screen, which filters by it itself.
    func testTypedSearchPassesThrough() {
        let out = StudyProgramsMapper.output(programs: [program("a", "A")], leaders: [], organizations: orgs,
                                             selection: .init(), typedSearch: "gen", loaded: true, failed: false)
        XCTAssertEqual(out.state.searchText, "gen")
        XCTAssertEqual(out.programIds, ["a"])
    }
}

/// ui2-programs D4: the list load's flags — a success clears a failure; a 401 signs out.
@MainActor
final class StudyProgramsContainerLoadTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        api.stub("GET", "/api/group-leaders", json: #"{"success":true,"leaders":[]}"#)
        api.stub("GET", "/api/organizations/my/organizations", json: #"{"success":true,"organizations":[]}"#)
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    func testAFailureSetsFailedAndASuccessClearsIt() async {
        api.errorFor = { endpoint, _ in endpoint == "/api/programs" ? APIHTTPError(status: 500, message: nil) : nil }
        let failed = await StudyProgramsContainer.load(api: api, state: state, onUnauthorized: {})
        XCTAssertFalse(failed)
        XCTAssertTrue(state.programsListFailed)
        XCTAssertFalse(state.programsListLoaded)

        api.errorFor = nil
        api.stub("GET", "/api/programs", json: #"{"success":true,"programs":[]}"#)
        let ok = await StudyProgramsContainer.load(api: api, state: state, onUnauthorized: {})
        XCTAssertTrue(ok)
        XCTAssertFalse(state.programsListFailed)
        XCTAssertTrue(state.programsListLoaded)
    }

    func testA401SignsOut() async {
        api.errorFor = { endpoint, _ in endpoint == "/api/programs" ? APIError.unauthorized : nil }
        var signedOut = false
        await StudyProgramsContainer.load(api: api, state: state, onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
    }
}
