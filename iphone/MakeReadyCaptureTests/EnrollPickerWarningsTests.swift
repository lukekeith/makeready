import XCTest
@testable import MakeReady

/// ui2-enrollment-create D11/D18: the picker warnings never block — they ask once.
final class EnrollPickerWarningsTests: XCTestCase {
    private let now = Date()
    private func enrollment(_ program: String, active: Bool) -> EnrollmentWithProgram {
        EnrollmentWithProgram(id: UUID().uuidString, groupId: "g", studyProgramId: program, startDate: .distantPast,
                              endDate: now.addingTimeInterval(active ? 86_400 : -86_400))
    }

    func testAlreadyEnrolledNeedsAnActiveEnrollmentOfTheDraftsProgram() {
        XCTAssertEqual(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: true)], programId: "p1",
                                                     scheduleDates: [], existingLessonDates: []), .alreadyEnrolled)
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: false)], programId: "p1",
                                                   scheduleDates: [], existingLessonDates: []))
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [enrollment("p1", active: true)], programId: nil,
                                                   scheduleDates: [], existingLessonDates: []))
    }

    func testLessonOverlapComparesCalendarDays() {
        let day = Calendar.current.startOfDay(for: now)
        XCTAssertEqual(EnrollPickerWarnings.forGroup(enrollments: [], programId: "p1", scheduleDates: [day],
                                                     existingLessonDates: [day.addingTimeInterval(9 * 3600)]), .lessonOverlap)
        XCTAssertNil(EnrollPickerWarnings.forGroup(enrollments: [], programId: "p1", scheduleDates: [day],
                                                   existingLessonDates: [day.addingTimeInterval(86_400)]))
    }

    func testProgramPickerWarnsAgainstTheDraftsGroupOnly() {
        XCTAssertEqual(EnrollPickerWarnings.forProgram(groupEnrollments: [enrollment("p1", active: true)], programId: "p1"), .alreadyEnrolled)
        XCTAssertNil(EnrollPickerWarnings.forProgram(groupEnrollments: nil, programId: "p1"))
    }

    func testLabels() {
        XCTAssertEqual(EnrollPickerWarnings.confirmLabel(.alreadyEnrolled), "Already enrolled — select anyway")
        XCTAssertEqual(EnrollPickerWarnings.confirmLabel(.lessonOverlap), "Lesson already scheduled — select anyway")
        XCTAssertEqual(EnrollPickerWarnings.chooseAnother, "Choose another")
    }
}

/// ui2-enrollment-create D11/D18 (Task 13 fix round 1): a group Select only fetches lesson dates when
/// the draft has a schedule, and a lookup cancelled by Back yields nothing to write.
@MainActor
final class EnrollGroupSelectOutcomeTests: XCTestCase {
    private func draft(schedule: [Date]) -> EnrollmentDraft {
        var draft = EnrollmentDraft(id: UUID(), groupId: nil, studyProgramId: "p1")
        draft.scheduleDates = schedule
        return draft
    }

    func testNoScheduleDecidesFromCachedEnrollmentsWithoutARequest() async {
        StatePersistence.shared.clear()
        let state = AppState()
        let live = EnrollmentWithProgram(id: "e1", groupId: "g1", studyProgramId: "p1", startDate: .distantPast,
                                         endDate: Date().addingTimeInterval(86_400))
        state.enrollments.upsert(live)
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")
        let api = StubAPIClient()
        let outcome = await EnrollSelectGroupContainer.lookupOutcome(groupId: "g1", draft: draft(schedule: []),
                                                                     state: state, api: api)
        XCTAssertEqual(outcome, .warn(.alreadyEnrolled))
        XCTAssertEqual(EnrollSelectGroupContainer.outcome(groupId: "g2", draft: draft(schedule: []),
                                                          existingLessonDates: [], state: state), .commit)
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testScheduleFetchesLessonDatesBeforeDeciding() async {
        StatePersistence.shared.clear()
        let state = AppState()
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        let outcome = await EnrollSelectGroupContainer.lookupOutcome(groupId: "g1", draft: draft(schedule: [Date()]),
                                                                     state: state, api: api)
        XCTAssertEqual(outcome, .commit)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/enrollments"), 1)
    }

    func testACancelledLookupYieldsNothingToWrite() async {
        StatePersistence.shared.clear()
        let state = AppState()
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g1/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        api.delayFor = { _ in 0.2 }
        let schedule = draft(schedule: [Date()])
        let lookup = Task { @MainActor in
            await EnrollSelectGroupContainer.lookupOutcome(groupId: "g1", draft: schedule, state: state, api: api)
        }
        lookup.cancel()                                  // Back while the lookup is pending
        let outcome = await lookup.value
        XCTAssertNil(outcome)
    }
}
