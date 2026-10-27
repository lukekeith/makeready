import XCTest
@testable import MakeReady

/// ui2-groups-browse D4/D17/D23: the group page's loads, error routing and image seeding inputs.
@MainActor
final class GroupDetailContainerTests: XCTestCase {
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

    func testUnauthorizedSignsOutAndRecordsNothing() async {
        var signedOut = false
        await GroupDetailContainer.attempt("getGroup", state: state, onUnauthorized: { signedOut = true }) {
            throw APIError.unauthorized
        }
        XCTAssertTrue(signedOut)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D4/D23: a failed or out-of-scope load is recorded console-only — never a banner.
    func testFailedOrOutOfScopeLoadIsConsoleOnly() async {
        await GroupDetailContainer.attempt("getGroup", state: state, onUnauthorized: {}) {
            throw APIError.serverError("Group not found")
        }
        XCTAssertEqual(state.errors.last?.context, "GroupDetailContainer.getGroup")
        XCTAssertEqual(state.errors.last?.surface, false)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testCancelledLoadIsSilent() async {
        await GroupDetailContainer.attempt("loadMembers", state: state, onUnauthorized: {}) {
            throw APIError.networkError(URLError(.cancelled))
        }
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D17: the container seeds the cover, the slide images and the enrollment covers.
    func testImageURLsAreTheCoverSlidesAndProgramCovers() {
        var s = GroupsDetailScreen.State.populated
        s.coverURL = "https://img/c.jpg"
        s.lessonSlideImages = [["https://img/1.jpg", ""]]
        s.programCoverURLs = ["", "https://img/p.jpg"]
        XCTAssertEqual(GroupDetailContainer.imageURLs(s), ["https://img/c.jpg", "https://img/1.jpg", "https://img/p.jpg"])
    }

    /// D4: the page reads every group store for its id.
    func testInputReadsEveryGroupStore() {
        let stamp = Date()
        state.groups.upsert(UserGroup(id: "g1", code: "C1", name: "Young Pros", isPrivate: false, allowInvites: true,
                                      memberCount: 0, creatorId: "u1", createdAt: stamp, updatedAt: stamp))
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25")]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 1])
        state.pendingJoinRequestsByGroupId["g1"] = [
            JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: stamp,
                        member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: nil, avatarUrl: nil))
        ]
        let input = GroupDetailContainer.input(groupId: "g1", name: "Pushed", state: state)
        XCTAssertEqual(input.name, "Pushed")
        XCTAssertEqual(input.group?.name, "Young Pros")
        XCTAssertEqual(input.nextStudy?.id, "s1")
        XCTAssertEqual(input.history.map(\.id), ["h1"])
        XCTAssertEqual(input.days?.count, 1)
        XCTAssertEqual(input.chart?.scheduled["2026-10-25"], 1)
        XCTAssertEqual(input.requests.map(\.id), ["r1"])
        XCTAssertNil(GroupDetailContainer.input(groupId: "g2", name: "Other", state: state).group)
    }

    // MARK: ui2-groups-edit D1

    func testEditFieldPushesTheFieldsPageOnceTheGroupIsLoaded() {
        let g = UserGroup(id: "g1", code: "ABC123", name: "Alpha", isPrivate: false, allowInvites: true,
                          memberCount: 0, creatorId: "u1", createdAt: Date(), updatedAt: Date())
        XCTAssertEqual(GroupDetailContainer.editDestination(groupId: "g1", label: "Age", group: g),
                       .editGroupField(groupId: "g1", field: .ageRange))
        XCTAssertEqual(GroupDetailContainer.editDestination(groupId: "g1", label: "Group name", group: g),
                       .editGroupField(groupId: "g1", field: .name))
        XCTAssertNil(GroupDetailContainer.editDestination(groupId: "g1", label: "Cover", group: g))
        XCTAssertNil(GroupDetailContainer.editDestination(groupId: "g1", label: "Age", group: nil))
    }

    // MARK: ui2-groups-edit D9/D13/D14

    func testDeleteActionIsOneRedRowNamingTheGroup() {
        let item = GroupDetailContainer.deleteAction(groupName: "Empty Group")
        XCTAssertEqual(item.label, "Delete Empty Group")
        XCTAssertEqual(item.glyph, "trash-2")
        XCTAssertEqual(item.tone, .destructive)
        XCTAssertEqual(GroupDetailContainer.deleteFailedMessage, "Couldn't delete the group")
    }
}
