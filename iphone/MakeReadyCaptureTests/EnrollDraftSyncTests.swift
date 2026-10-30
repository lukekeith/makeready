import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D3/D4/D6/D26/D30: the checklist's autosave — first save, PATCH order and
/// coalescing, retry-then-banner once per dirty episode, 409 re-seed, 404 gone, cancel.
@MainActor
final class EnrollDraftSyncTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private var sleeps = 0

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        sleeps = 0
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func wire(_ id: String, program: String = "p1", start: String? = nil, schedule: [String]? = nil) -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: program, startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: nil, timezone: nil, syncMode: nil, lessonAccess: nil,
                  createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
    }

    private func draftJSON(_ id: String, program: String = "p1", sms: String? = nil) -> String {
        let smsValue = sms.map { "\"\($0)\"" } ?? "null"
        return #"{"success":true,"draft":{"id":"\#(id)","groupId":"g1","studyProgramId":"\#(program)","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":\#(smsValue),"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-03T00:00:00.000Z"}}"#
    }

    private var actions: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }

    private func sync(_ flowId: UUID) -> EnrollDraftSync {
        EnrollDraftSync(flowId: flowId, state: state, actions: actions, sleep: { [weak self] _ in self?.sleeps += 1 })
    }

    private func patches() -> [[String: Any]] { api.calls.filter { $0.method == "PATCH" }.compactMap(\.body) }

    func testNothingIsSavedUntilGroupAndProgramAreBothSet() async {          // D3
        let st = state!
        let id = st.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let s = sync(id)
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        st.updateEnrollmentDraft(id) { $0.setProgram("p1") }
        s.changed(); await s.flush()
        XCTAssertEqual(api.callCount("POST", "/api/enrollment-drafts"), 1)
        XCTAssertEqual(Set(api.calls[0].body?.keys.map { $0 } ?? []), ["groupId", "studyProgramId"])
        XCTAssertEqual(st.enrollmentDrafts[id]?.serverId, "d1")              // D21: adopted, flowId unchanged
        XCTAssertEqual(st.enrollmentDrafts[id]?.createdByName, "Luke Keith")
        XCTAssertEqual(st.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"])
    }

    func testChangesMadeWhileThePostIsInFlightArePatchedOnceItReturns() async {  // D4
        let st = state!
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        let id = st.startEnrollmentDraft(groupId: "g1", studyProgramId: "p1")
        let s = sync(id)
        var fired = false
        api.beforeReturn = { endpoint, _ in
            guard endpoint == "/api/enrollment-drafts", !fired else { return }
            fired = true
            st.updateEnrollmentDraft(id) { $0.smsTime = "07:30"; $0.timezone = "America/Chicago" }
            s.changed()                                                      // in flight → coalesced
        }
        s.changed()
        await s.flush()
        XCTAssertEqual(api.calls.map(\.method), ["POST", "PATCH"])
        XCTAssertEqual(Set(patches()[0].keys), ["smsTime", "timezone"])
    }

    func testChangesWhileAPatchIsInFlightCoalesceIntoTheNextPatch() async {    // D4: one in flight
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1"))
        let s = sync(id)
        var first = true
        api.beforeReturn = { _, _ in
            guard first else { return }
            first = false
            st.updateEnrollmentDraft(id) { $0.syncMode = "AUTO" }
            s.changed()
            st.updateEnrollmentDraft(id) { $0.lessonAccess = "all-at-once" }
            s.changed()
        }
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertEqual(Set(patches()[0].keys), ["smsTime"])
        XCTAssertEqual(Set(patches()[1].keys), ["syncMode", "lessonAccess"])
        XCTAssertEqual(patches()[1]["lessonAccess"] as? String, "ALL_AT_ONCE")
    }

    func testAProgramChangeSendsScheduleDatesNull() async {                  // D4
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"]))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", program: "p2"))
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.setProgram("p2") }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().first?["studyProgramId"] as? String, "p2")
        XCTAssertTrue(patches().first?["scheduleDates"] is NSNull)
        XCTAssertNil(patches().first?["startDate"])                           // the seed is kept
    }

    func testAFailedPatchRetriesOnceAfterTheDelay() async {                   // D26
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        var failures = 1
        api.errorFor = { endpoint, _ in
            guard endpoint == "/api/enrollment-drafts/d1", failures > 0 else { return nil }
            failures -= 1
            return APIError.serverError("offline")
        }
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertEqual(sleeps, 1)
        XCTAssertEqual(EnrollDraftSync.retryDelay, .seconds(2))
        XCTAssertFalse(s.dirty)
        XCTAssertNil(st.activeSurfacedError)
    }

    func testASecondFailureBannersOncePerDirtyEpisodeAndResendsEverything() async {   // D26
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollment-drafts/d1" ? APIError.serverError("offline") : nil }
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertTrue(s.dirty)
        XCTAssertEqual(st.activeSurfacedError?.message, "Couldn't save the draft")
        XCTAssertNotNil(st.activeSurfacedError?.retry)
        st.activeSurfacedError = nil
        st.updateEnrollmentDraft(id) { $0.syncMode = "AUTO" }                  // a later Select while dirty
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 4)
        XCTAssertEqual(Set(patches()[3].keys), ["smsTime", "syncMode"])
        XCTAssertNil(st.activeSurfacedError)                                   // no second banner
        api.errorFor = nil
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        s.changed(); await s.flush()                                           // Retry
        XCTAssertEqual(Set(patches()[4].keys), ["smsTime", "syncMode"])
        XCTAssertFalse(s.dirty)
    }

    func testAConflictReseedsThisFlowInPlace() async {                        // D6, also with a picker on top
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { endpoint, _ in
            endpoint == "/api/enrollment-drafts/d1"
                ? APIHTTPError(status: 409, message: "draft_exists", details: ["draftId": "d9"]) : nil
        }
        api.stub("GET", "/api/enrollment-drafts/d9", json: draftJSON("d9", program: "p3", sms: "06:00"))
        var gone = false
        let s = sync(id)
        s.onGone = { gone = true }
        st.updateEnrollmentDraft(id) { $0.setProgram("p3") }
        s.changed(); await s.flush()
        let d = st.enrollmentDrafts[id]
        XCTAssertEqual(d?.serverId, "d9")
        XCTAssertEqual(d?.studyProgramId, "p3")
        XCTAssertEqual(d?.smsTime, "06:00")
        XCTAssertEqual(d?.phase, .checklist)
        XCTAssertEqual(st.enrollmentDraftBaselines[id], d)
        XCTAssertFalse(gone)                                                   // no navigation
        XCTAssertEqual(api.callCount("PATCH", "/api/enrollment-drafts/d1"), 1) // a 409 is not retried
        XCTAssertEqual(st.activeSurfacedError?.kind, .notice)                  // owner 2026-10-29
        XCTAssertEqual(st.activeSurfacedError?.message,
                       EnrollDraftSync.existsMessage(groupName: nil, programName: nil))
    }

    func testTheExistsNoticeNamesThePair() {                                 // owner 2026-10-29
        XCTAssertEqual(EnrollDraftSync.existsMessage(groupName: "Tuesday's Men's Group", programName: "Walking Through John"),
                       "Tuesday's Men's Group already has a draft for Walking Through John. Opened it so you can pick up where you left off.")
        XCTAssertEqual(EnrollDraftSync.existsMessage(groupName: "", programName: nil),
                       "This group already has a draft for this program. Opened it so you can pick up where you left off.")
    }

    func testA404EndsTheFlowWithTheGoneBanner() async {                       // D30
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        st.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var gone = false
        let s = sync(id)
        s.onGone = { gone = true }
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertNil(st.enrollmentDrafts[id])
        XCTAssertEqual(st.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertEqual(st.activeSurfacedError?.message, "This draft no longer exists")
        XCTAssertTrue(gone)
        XCTAssertEqual(patches().count, 1)                                    // a 404 is not retried
    }

    func testStopCancelsPendingWorkForGood() async {                          // D30: Discard/Enroll
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        s.stop()
        await s.flush()
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testNothingIsSavedOncePastTheChecklist() async {                     // processing/enrolled never PATCH
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30"; $0.phase = .processing }
        let s = sync(id)
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    // MARK: D30 as superseded 2026-10-29 — Back lets the pending save settle

    func testFinishLetsTheOneRetrySettleThenEndsWithoutABanner() async {
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollment-drafts/d1" ? APIError.serverError("offline") : nil }
        let s = sync(id)
        var ended = false
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        s.finish { ended = true }
        XCTAssertFalse(ended)                                                  // waits for the save
        await s.flush()
        XCTAssertEqual(patches().count, 2)                                     // the PATCH and its one retry
        XCTAssertEqual(sleeps, 1)
        XCTAssertTrue(ended)
        XCTAssertNil(st.activeSurfacedError)                                   // the checklist is gone: no banner
    }

    func testA404WhileFinishingIsSilentAndDoesNotPop() async {
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        st.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var popped = false, ended = false
        let s = sync(id)
        s.onGone = { popped = true }
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        s.finish { ended = true }
        await s.flush()
        XCTAssertTrue(ended)
        XCTAssertFalse(popped)                                                 // the user already left
        XCTAssertNil(st.activeSurfacedError)
        XCTAssertEqual(st.enrollmentDraftsByGroupId["g1"], [])                 // forgotten all the same
    }

    func testReopeningTheChecklistBeforeTheSaveSettlesKeepsTheFlow() async {
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        let s = sync(id)
        var ended = false
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        s.finish { ended = true }
        s.reopen()                                                             // the row was tapped again
        await s.flush()
        XCTAssertEqual(patches().count, 1)
        XCTAssertFalse(ended)
        st.updateEnrollmentDraft(id) { $0.syncMode = "AUTO" }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 2)                                     // still saving
    }

    func testTheRegistryKeepsOneSyncPerFlowAndPruneStopsTheRest() {
        let a = UUID(), b = UUID()
        let sa = EnrollDraftSyncs.sync(for: a, state: state, actions: actions)
        XCTAssertTrue(EnrollDraftSyncs.sync(for: a) === sa)
        _ = EnrollDraftSyncs.sync(for: b, state: state, actions: actions)
        EnrollDraftSyncs.prune(keeping: [a], state: state)
        XCTAssertTrue(EnrollDraftSyncs.isRegistered(a))
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(b))
        EnrollDraftSyncs.stop(a)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(a))
    }
}
