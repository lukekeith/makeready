import XCTest
@testable import MakeReady

/// ui2-enrollment-create D9/D10/D13: the draft's lifetime and design rules 1–2.
@MainActor
final class EnrollmentDraftTests: XCTestCase {
    private func day(_ ymd: String) -> Date {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    func testStartUpdateEndAndPrune() {
        let state = AppState()
        let a = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let b = state.startEnrollmentDraft(groupId: nil, studyProgramId: "p1")
        XCTAssertEqual(state.enrollmentDrafts[a]?.groupId, "g1")
        state.updateEnrollmentDraft(a) { $0.smsTime = "07:30" }
        XCTAssertEqual(state.enrollmentDrafts[a]?.smsTime, "07:30")
        state.pruneEnrollmentDrafts(keeping: [b])
        XCTAssertNil(state.enrollmentDrafts[a])
        state.endEnrollmentDraft(b)
        XCTAssertTrue(state.enrollmentDrafts.isEmpty)
    }

    func testClearAllDataClearsDrafts() {
        let state = AppState()
        _ = state.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        state.clearAllData()
        XCTAssertTrue(state.enrollmentDrafts.isEmpty)
    }

    func testProgramChangeUndoesTheScheduleButKeepsItsSeed() {
        var d = EnrollmentDraft(id: UUID())
        d.setProgram("p1")
        d.startDate = day("2035-01-08"); d.enabledDays = [1, 3]; d.overriddenDates = [day("2035-01-10")]
        d.scheduleDates = [day("2035-01-08")]; d.endDate = day("2035-01-08")
        XCTAssertTrue(d.scheduleDone)
        d.setProgram("p1")                                  // same program: nothing changes
        XCTAssertTrue(d.scheduleDone)
        d.setProgram("p2")
        XCTAssertFalse(d.scheduleDone)
        XCTAssertEqual(d.startDate, day("2035-01-08"))
        XCTAssertEqual(d.enabledDays, [1, 3])
        XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertNil(d.endDate)
    }

    func testScheduleMathMatchesTheCalendarAndRefusesAShortList() {
        // Mon/Wed from Mon 2035-01-08, skipping Wed 01-10 by override → 01-08, 01-15, 01-17
        let dates = EnrollScheduleMath.dates(start: day("2035-01-08"), days: [1, 3],
                                             overrides: [day("2035-01-10")], lessonCount: 3)
        XCTAssertEqual(dates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertNil(EnrollScheduleMath.dates(start: day("2035-01-08"), days: [], overrides: [], lessonCount: 3)) // A4
    }

    /// ui2-enrollments-browse R4/D2: a checklist that leaves every stack drops the LOCAL flow and
    /// stops its autosave — the shell's prune sends no request, and never a DELETE.
    func testThePruneOfASavedDraftsFlowSendsNoRequest() async {
        let api = StubAPIClient()
        let state = AppState()
        var model = UI2ShellModel()
        let wire = DraftWire(id: "d1", groupId: "g1", studyProgramId: "p1", startDate: nil, enabledDays: nil,
                             overriddenDates: nil, scheduleDates: nil, smsTime: nil, timezone: nil, syncMode: nil,
                             lessonAccess: nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                             createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
        let flow = state.seedEnrollmentDraft(wire)
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: EnrollmentDraftActions(api: api, state: state))
        model.push(.enrollChecklist(flowId: flow), on: .home)
        state.updateEnrollmentDraft(flow) { $0.smsTime = "07:30" }                 // an unsent change
        model.pop(on: .home)                                                     // swipe-back
        state.pruneEnrollmentDrafts(keeping: model.enrollmentFlowIds)            // UI2Shell's onChange, both halves
        EnrollDraftSyncs.prune(keeping: model.enrollmentFlowIds)
        sync.changed()
        await sync.flush()
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
        XCTAssertTrue(api.calls.isEmpty)
    }
}
