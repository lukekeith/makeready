import XCTest
@testable import MakeReady

/// ui2-enrollment-create D6: Enroll's phases and error routing; D2/D10: the entry's preloads.
@MainActor
final class EnrollSubmitTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        api.errorFor = { endpoint, _ in endpoint.hasPrefix("/api/enrollments") ? nil : APIError.serverError("refresh not stubbed") }
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func readyDraft() -> UUID {
        let id = state.startEnrollmentDraft(groupId: "g1", studyProgramId: "p1")
        state.updateEnrollmentDraft(id) {
            $0.startDate = Date(timeIntervalSince1970: 2_051_222_400)
            $0.enabledDays = [1]
            $0.scheduleDates = [Date(timeIntervalSince1970: 2_051_222_400)]
            $0.endDate = $0.scheduleDates.last
            $0.smsTime = "07:30"; $0.timezone = "America/Chicago"; $0.syncMode = "AUTO"; $0.lessonAccess = "all-at-once"
        }
        return id
    }

    private func run(_ id: UUID, onUnauthorized: @escaping @MainActor () async -> Void = {}) async -> Bool {
        await EnrollSubmit.run(flowId: id, actions: EnrollmentActions(api: api, state: state), state: state, onUnauthorized: onUnauthorized)
    }

    func testSuccessPostsTheDraftAndEndsEnrolled() async {
        api.stub("POST", "/api/enrollments", json: created)
        let id = readyDraft()
        let ok = await run(id)
        XCTAssertTrue(ok)
        XCTAssertEqual(state.enrollmentDrafts[id]?.phase, .enrolled)
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["lessonAccess"] as? String, "ALL_AT_ONCE")
        XCTAssertEqual(body?["syncMode"] as? String, "AUTO")
        XCTAssertEqual((body?["scheduleDates"] as? [String])?.count, 1)
        XCTAssertEqual(body?["enabledDays"] as? [String], ["Mon"])
    }

    func testFailureSurfacesCouldntEnrollAndReturnsToTheChecklist() async {
        api.errorFor = { _, _ in APIError.serverError("boom") }
        let id = readyDraft()
        let ok = await run(id)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.enrollmentDrafts[id]?.phase, .checklist)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't enroll")
        XCTAssertEqual(state.errors.last?.context, "EnrollChecklistContainer.enroll")
    }

    func testUnauthorizedSignsOutAndSurfacesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let id = readyDraft()
        _ = await run(id, onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testAnIncompleteOrProcessingDraftSendsNothing() async {
        let id = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let incomplete = await run(id)
        XCTAssertFalse(incomplete)
        let ready = readyDraft()
        state.updateEnrollmentDraft(ready) { $0.phase = .processing }      // A5: a second tap
        let second = await run(ready)
        XCTAssertFalse(second)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testEntryPreloadsAnEmptyGroup() throws {   // D10, superseded 2026-10-28: preload + warning
        state.groups.upsert(try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(
            #"{"id":"g0","code":"C","name":"Empty","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberCount":0,"creatorId":"u1","createdAt":"2025-01-03T12:00:00.000Z","updatedAt":"2025-01-03T12:00:00.000Z"}"#.utf8)))
        var pushed: [UI2Destination] = []
        EnrollEntry.open(groupId: "g0", studyProgramId: nil, push: { pushed.append($0) }, state: state)
        guard case let .enrollChecklist(flowId)? = pushed.first else { return XCTFail("no checklist pushed") }
        XCTAssertEqual(state.enrollmentDrafts[flowId]?.groupId, "g0")
    }

    func testAScheduleRowTapOpensTheSchedulePicker() {
        let id = UUID()
        XCTAssertEqual(EnrollChecklistContainer.destination(for: .schedule, flowId: id), .enrollSelectSchedule(flowId: id))
    }
}
