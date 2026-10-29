import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D9/D23 (stale start on open), D10/D29/D30 (Discard), D11/F10 (Enroll),
/// D2/R4 (Back and prune end the LOCAL flow only).
@MainActor
final class EnrollDraftLifecycleTests: XCTestCase {
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

    private func day(_ ymd: String) -> Date { EnrollmentWire.date(ymd: ymd)! }

    private func wire(_ id: String, start: String? = nil, schedule: [String]? = nil, complete: Bool = false) -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: "p1", startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: complete ? "07:30" : nil,
                  timezone: complete ? "America/Chicago" : nil, syncMode: complete ? "AUTO" : nil,
                  lessonAccess: complete ? "ALL_AT_ONCE" : nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
    }

    private var actions: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }

    // MARK: D9/D23

    func testOpeningAStaleDraftClearsTheScheduleLocallyAndSendsNothing() async {
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-01", schedule: ["2035-01-01"], complete: true),
                                             today: day("2035-01-06"))
        let d = state.enrollmentDrafts[flow]
        XCTAssertNil(d?.startDate)
        XCTAssertEqual(d?.scheduleDates, [])
        XCTAssertNil(d?.endDate)
        XCTAssertEqual(d?.enabledDays, [1])                                    // the picker's seed stays
        XCTAssertEqual(d?.smsTime, "07:30")                                    // every other row keeps its value
        XCTAssertEqual(state.enrollmentDraftBaselines[flow], d)               // so no PATCH carries the clear
        let sync = EnrollDraftSync(flowId: flow, state: state, actions: actions, sleep: { _ in })
        sync.changed(); await sync.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testAFreshDraftKeepsItsSchedule() {
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"]), today: day("2035-01-06"))
        XCTAssertEqual(state.enrollmentDrafts[flow]?.scheduleDone, true)
    }

    // MARK: D10/D29/D30 Discard

    func testDiscardIsOfferedOnlyForASavedDraftOnTheChecklist() {
        var d = EnrollmentDraft(id: UUID(), groupId: "g1", studyProgramId: "p1")
        XCTAssertFalse(EnrollChecklistContainer.offersDiscard(d))             // not saved yet
        d.serverId = "d1"
        XCTAssertTrue(EnrollChecklistContainer.offersDiscard(d))
        d.phase = .processing
        XCTAssertFalse(EnrollChecklistContainer.offersDiscard(d))
        XCTAssertEqual(EnrollDiscard.action.label, "Discard enrollment")
        XCTAssertEqual(EnrollDiscard.action.tone, .destructive)
    }

    func testDiscardDeletesEndsTheFlowAndPops() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        api.stub("DELETE", "/api/enrollment-drafts/d1", json: #"{"success":true}"#)
        var popped = false
        let ok = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertTrue(ok)
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertTrue(popped)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }

    func testDiscardFailureBannersWithRetryAndStays() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { _, _ in APIError.serverError("offline") }
        var popped = false
        let ok = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertFalse(ok)
        XCTAssertNotNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't discard the draft")
        XCTAssertNotNil(state.activeSurfacedError?.retry)
        XCTAssertFalse(popped)
        EnrollDraftSyncs.stop(flow)
    }

    func testDiscardOfAGoneDraftIsTheGonePath() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var popped = false
        _ = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.activeSurfacedError?.message, "This draft no longer exists")
        XCTAssertTrue(popped)
    }

    // MARK: D11/F10 Enroll

    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-08T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#

    func testEnrollSendsTheDraftIdAndDropsTheStoredDraft() async {
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollments" ? nil : APIError.serverError("refresh not stubbed") }
        api.stub("POST", "/api/enrollments", json: created)
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"], complete: true),
                                             today: day("2035-01-06"))
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        let ok = await EnrollSubmit.run(flowId: flow, actions: EnrollmentActions(api: api, state: state), state: state,
                                        onUnauthorized: {})
        XCTAssertTrue(ok)
        XCTAssertEqual(api.calls.first { $0.endpoint == "/api/enrollments" }?.body?["draftId"] as? String, "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertEqual(state.enrollmentDrafts[flow]?.phase, .enrolled)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }

    func testASecondEnrollWhileProcessingSendsNothing() async {               // F10
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"], complete: true),
                                             today: day("2035-01-06"))
        state.updateEnrollmentDraft(flow) { $0.phase = .processing }
        let ok = await EnrollSubmit.run(flowId: flow, actions: EnrollmentActions(api: api, state: state), state: state,
                                        onUnauthorized: {})
        XCTAssertFalse(ok)
        XCTAssertTrue(api.calls.isEmpty)
    }

    // MARK: D2/R4 Back + prune

    func testBackWithNothingInFlightEndsTheLocalFlowAtOnceAndNeverDeletes() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: actions)
        state.updateEnrollmentDraft(flow) { $0.smsTime = "07:30" }               // an unsent change
        EnrollChecklistContainer.endFlow(flow, state: state)
        sync.changed(); await sync.flush()
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertNil(state.enrollmentDraftBaselines[flow])
        XCTAssertTrue(api.calls.isEmpty)                                      // no PATCH, and never a DELETE
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }

    private func draftJSON(_ id: String, sms: String? = nil) -> String {
        let smsValue = sms.map { "\"\($0)\"" } ?? "null"
        return #"{"success":true,"draft":{"id":"\#(id)","groupId":"g1","studyProgramId":"p1","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":\#(smsValue),"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-03T00:00:00.000Z"}}"#
    }

    /// D30 as superseded 2026-10-29 (final review, Important 2): Back lets the pending save settle.
    func testASelectFollowedAtOnceByBackStillSendsItsPatchThenEndsTheFlow() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: actions)
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        state.updateEnrollmentDraft(flow) { $0.smsTime = "07:30" }               // a picker's Select…
        EnrollDraftSyncs.changed(flow)
        EnrollChecklistContainer.endFlow(flow, state: state)                    // …then Back at once
        EnrollDraftSyncs.prune(keeping: [], state: state)                       // the shell, as the checklist leaves
        await sync.flush()
        XCTAssertEqual(api.calls.map(\.method), ["PATCH"])                       // sent, and never a DELETE
        XCTAssertEqual(api.calls.first?.body?["smsTime"] as? String, "07:30")
        XCTAssertNil(state.enrollmentDrafts[flow])                              // then the local flow ends
        XCTAssertNil(state.enrollmentDraftBaselines[flow])
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"]) // the group page lists it
    }

    func testAProgramPickFollowedAtOnceByBackStillSendsTheFirstSave() async {    // D3 + walk step 6
        let flow = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: actions)
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        state.updateEnrollmentDraft(flow) { $0.setProgram("p1") }
        EnrollDraftSyncs.changed(flow)
        EnrollChecklistContainer.endFlow(flow, state: state)
        EnrollDraftSyncs.prune(keeping: [], state: state)
        await sync.flush()
        XCTAssertEqual(api.callCount("POST", "/api/enrollment-drafts"), 1)
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"])
    }

    func testAPickerCommitAfterTheFlowStoppedRegistersNoSync() {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        EnrollDraftSyncs.changed(flow)                                        // only the checklist registers a sync
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }
}
