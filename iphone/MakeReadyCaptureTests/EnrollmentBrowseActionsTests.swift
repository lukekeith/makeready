import XCTest
@testable import MakeReady

/// ui2-enrollments-browse §iphone Store/Actions: drafts, the feed and the home read; memory-only stores.
@MainActor
final class EnrollmentBrowseActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let chicago = TimeZone(identifier: "America/Chicago")!

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

    private func wire(_ id: String, group: String = "g1", program: String = "p1",
                      updated: String = "2035-01-02T00:00:00.000Z") -> DraftWire {
        DraftWire(id: id, groupId: group, studyProgramId: program, startDate: nil, enabledDays: nil,
                  overriddenDates: nil, scheduleDates: nil, smsTime: nil, timezone: nil, syncMode: nil,
                  lessonAccess: nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: updated)
    }

    /// One §Contract Draft object.
    private func draftObject(_ id: String, group: String = "g1", program: String = "p1",
                             updated: String = "2035-01-02T00:00:00.000Z") -> String {
        #"{"id":"\#(id)","groupId":"\#(group)","studyProgramId":"\#(program)","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"\#(updated)"}"#
    }

    /// `{success, draft}`.
    private func draftJSON(_ id: String, group: String = "g1", program: String = "p1",
                           updated: String = "2035-01-02T00:00:00.000Z") -> String {
        #"{"success":true,"draft":\#(draftObject(id, group: group, program: program, updated: updated))}"#
    }

    private var drafts: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }
    private func anyFeed() -> EnrollmentFeed { EnrollmentFeed(sections: [], options: EnrollmentFeedOptions(groups: [], leaders: [])) }

    private let homeJSON = #"{"success":true,"home":{"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":"Paul's letter","coverImageUrl":null,"authorName":"Jonathan Edwards"},"group":{"id":"g1","name":"Young Professionals","leader":{"id":"u1","name":"Tony Stark"}},"memberCount":17,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-03-10","lessonAccess":"ALL_AT_ONCE","smsTime":"07:30","timezone":"America/Chicago","days":[{"scheduleId":"s1","date":"2035-01-08","percent":78,"lessonCount":1,"plannedMinutes":15}],"lessons":[{"scheduleId":"s1","dayNumber":1,"title":"It is evident","date":"2035-01-08","progress":0.69,"activities":[{"id":"a1","type":"READ","title":"Romans 1","thumbnailUrl":"https://x/a1.png"}]}]}}"#

    // MARK: drafts

    func testCreateStoresTheDraftUnderItsGroupAndDropsTheFeed() async throws {
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        let outcome = try await drafts.create(body: ["groupId": "g1", "studyProgramId": "p1"])
        XCTAssertEqual(outcome, .saved(wire("d1")))
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    func testAConflictReturnsTheExistingDraftId() async throws {        // D6
        api.errorFor = { _, _ in APIHTTPError(status: 409, message: "draft_exists", details: ["draftId": "d9"]) }
        let outcome = try await drafts.create(body: ["groupId": "g1", "studyProgramId": "p1"])
        XCTAssertEqual(outcome, .exists(draftId: "d9"))
        let patched = try await drafts.update(id: "d1", body: ["groupId": "g2"])
        XCTAssertEqual(patched, .exists(draftId: "d9"))
    }

    func testStatusErrorKeepsTheBodysDraftId() {
        let data = Data(#"{"success":false,"error":"draft_exists","draftId":"d9"}"#.utf8)
        let error = APIClient.statusError(status: 409, data: data) as? APIHTTPError
        XCTAssertEqual(error?.details["draftId"], "d9")
        XCTAssertEqual(error, APIHTTPError(status: 409, message: "draft_exists"))   // details are not identity
    }

    func testAGroupChangeMovesTheDraftBetweenBothGroupsLists() async throws {
        state.enrollmentDraftsByGroupId = ["g1": [wire("d1"), wire("d0")], "g2": [wire("d5", group: "g2", updated: "2035-01-01T00:00:00.000Z")]]
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", group: "g2", updated: "2035-01-03T00:00:00.000Z"))
        _ = try await drafts.update(id: "d1", body: ["groupId": "g2"])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d0"])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g2"]?.map(\.id), ["d1", "d5"])   // newest updatedAt first
    }

    func testDeleteRemovesTheDraftAndDropsTheFeed() async throws {
        state.enrollmentDraftsByGroupId = ["g1": [wire("d1")]]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        api.stub("DELETE", "/api/enrollment-drafts/d1", json: #"{"success":true}"#)
        try await drafts.delete(id: "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    func testA404KeepsItsStatus() async {                                // D30 needs the status
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        do { _ = try await drafts.load(id: "d1"); XCTFail("expected a throw") } catch {
            XCTAssertEqual((error as? APIHTTPError)?.status, 404)
        }
    }

    func testListByGroupStoresTheServersOrder() async throws {
        api.stub("GET", "/api/enrollment-drafts?groupId=g1",
                 json: #"{"success":true,"drafts":[\#(draftObject("d2")),\#(draftObject("d1"))]}"#)
        try await drafts.listByGroup(groupId: "g1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d2", "d1"])
    }

    func testSeedAndFindTheFlowOfAServerDraft() {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        XCTAssertEqual(state.enrollmentDrafts[flow]?.serverId, "d1")
        XCTAssertEqual(state.enrollmentDraftBaselines[flow], state.enrollmentDrafts[flow])
        XCTAssertEqual(state.enrollmentFlowId(forServerId: "d1"), flow)
        XCTAssertNil(state.enrollmentFlowId(forServerId: "d2"))
        state.seedEnrollmentDraft(wire("d7", program: "p7"), flowId: flow)      // D6: in place
        XCTAssertEqual(state.enrollmentDrafts[flow]?.serverId, "d7")
        XCTAssertEqual(state.enrollmentDrafts.count, 1)
        state.endEnrollmentDraft(flow)
        XCTAssertNil(state.enrollmentDraftBaselines[flow])
    }

    // MARK: feed + home

    private let feedJSON = #"{"success":true,"sections":[{"group":{"id":"g1","name":"Young Professionals","coverImageUrl":null,"leader":{"id":"u1","name":"Luke Keith"}},"items":[{"kind":"enrollment","id":"e1","studyProgram":{"id":"p1","name":"Romans","coverImageUrl":"https://x/p1.png"},"startDate":"2035-01-08","endDate":"2035-02-01","enrolledAt":"2035-01-01T15:00:00.000Z","progress":0.5,"completedMembers":3,"memberCount":12,"plannedMinutes":90,"recencyAt":"2035-01-05T00:00:00.000Z"},{"kind":"draft","draft":{"id":"d1","groupId":"g1","studyProgramId":"p2","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-04T00:00:00.000Z"},"studyProgram":{"id":"p2","name":"John","coverImageUrl":null},"recencyAt":"2035-01-04T00:00:00.000Z"}]}],"options":{"groups":[{"id":"g1","name":"Young Professionals"}],"leaders":[{"id":"u1","name":"Luke Keith"}]}}"#

    func testFeedPathCarriesTheFilterAndTheDeviceZone() {
        XCTAssertEqual(EnrollmentFeedFilter().path(timeZone: chicago), "/api/enrollments-feed?status=active&tz=America/Chicago")
        XCTAssertEqual(EnrollmentFeedFilter(orgId: "o1", groupId: "g1", leaderId: "u1", status: .draft).path(timeZone: chicago),
                       "/api/enrollments-feed?orgId=o1&groupId=g1&leaderId=u1&status=draft&tz=America/Chicago")
        XCTAssertEqual(EnrollmentFeedFilter.Status.allCases.map(\.label), ["Active", "Upcoming", "Completed", "Draft", "All"])
    }

    func testLoadFeedDecodesAndIsCacheFirst() async throws {
        api.stub("GET", "/api/enrollments-feed?status=active&tz=America/Chicago", json: feedJSON)
        let actions = EnrollmentActions(api: api, state: state)
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), timeZone: chicago)
        let feed = try XCTUnwrap(state.enrollmentFeed[EnrollmentFeedFilter()])
        XCTAssertEqual(feed.sections.first?.group.leader?.name, "Luke Keith")
        XCTAssertEqual(feed.sections.first?.items.map(\.kind), ["enrollment", "draft"])
        XCTAssertEqual(feed.sections.first?.items.last?.draft?.id, "d1")
        XCTAssertEqual(feed.options.leaders.map(\.id), ["u1"])
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), timeZone: chicago)
        XCTAssertEqual(api.calls.count, 1)                                     // cached
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), forceRefresh: true, timeZone: chicago)
        XCTAssertEqual(api.calls.count, 2)
    }

    func testLoadHomeDecodes() async throws {
        api.stub("GET", "/api/enrollments/e1/home?tz=America/Chicago", json: homeJSON)
        try await EnrollmentActions(api: api, state: state).loadHome(id: "e1", timeZone: chicago)
        let home = try XCTUnwrap(state.enrollmentHomes["e1"])
        XCTAssertEqual(home.group.leader?.name, "Tony Stark")
        XCTAssertEqual(home.days.first?.percent, 78)
        XCTAssertEqual(home.lessons.first?.activities.first?.thumbnailUrl, "https://x/a1.png")
        XCTAssertEqual(home.smsTime, "07:30")
    }

    // MARK: enroll (D11/D24)

    func testCreateEnrollmentSendsDraftIdAndRemovesThePairsDrafts() async throws {
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollments" ? nil : APIError.serverError("refresh not stubbed") }
        api.stub("POST", "/api/enrollments", json: #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#)
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1", program: "p1"), wire("d2", program: "p2")]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        _ = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: Date(timeIntervalSince1970: 2_051_222_400),
            enabledDays: ["Mon"], smsTime: "07:30", timezone: "America/Chicago", draftId: "d1")
        XCTAssertEqual(api.calls.first { $0.endpoint == "/api/enrollments" }?.body?["draftId"] as? String, "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d2"])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    // MARK: enrollment mutations drop the browse caches

    private func seedBrowseCaches() async throws {
        api.stub("GET", "/api/enrollments/e1/home?tz=America/Chicago", json: homeJSON)
        try await EnrollmentActions(api: api, state: state).loadHome(id: "e1", timeZone: chicago)
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        XCTAssertNotNil(state.enrollmentHomes["e1"])
    }

    private func assertBrowseCachesDropped(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(state.enrollmentFeed.isEmpty, file: file, line: line)
        XCTAssertNil(state.enrollmentHomes["e1"], file: file, line: line)
    }

    func testDeleteByIdDropsTheFeedAndThatHome() async throws {
        try await seedBrowseCaches()
        api.stub("DELETE", "/api/enrollments/e1", json: #"{"success":true}"#)
        try await EnrollmentActions(api: api, state: state).deleteEnrollment(id: "e1")
        assertBrowseCachesDropped()
    }

    func testDeleteWithGroupAndProgramDropsTheFeedAndThatHome() async throws {
        try await seedBrowseCaches()
        api.stub("DELETE", "/api/enrollments/e1", json: #"{"success":true}"#)
        try await EnrollmentActions(api: api, state: state).deleteEnrollment(id: "e1", groupId: "g1", programId: "p1")
        assertBrowseCachesDropped()
    }

    func testUpdateAndCancelFutureDropTheFeedAndThatHome() async throws {
        try await seedBrowseCaches()
        api.stub("PATCH", "/api/enrollments/e1", json: #"{"success":true}"#)
        try await EnrollmentActions(api: api, state: state).updateEnrollment(enrollmentId: "e1", body: ["smsTime": "08:00"])
        assertBrowseCachesDropped()

        try await seedBrowseCaches()
        api.stub("POST", "/api/enrollments/e1/cancel-future", json: #"{"success":true}"#)
        try await EnrollmentActions(api: api, state: state).cancelFutureLessons(id: "e1")
        assertBrowseCachesDropped()
    }

    func testClearAllDataClearsTheNewStores() {
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        _ = state.seedEnrollmentDraft(wire("d1"))
        state.clearAllData()
        XCTAssertTrue(state.enrollmentDraftsByGroupId.isEmpty)
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
        XCTAssertTrue(state.enrollmentHomes.isEmpty)
        XCTAssertTrue(state.enrollmentDraftBaselines.isEmpty)
    }
}
