import XCTest
@testable import MakeReady

/// ui2-enrollment-create D7 + design §3: the three value pickers write the draft only with a valid
/// value; the schedule's existing lesson dates come from the group's active enrollments.
@MainActor
final class EnrollValuePickerTests: XCTestCase {
    func testInviteTimeStoresTimeAndZone() {
        var d = EnrollmentDraft(id: UUID())
        EnrollValueWrite.inviteTime("07:30", timezone: "America/Chicago", into: &d)
        XCTAssertEqual(d.smsTime, "07:30")
        XCTAssertEqual(d.timezone, "America/Chicago")
    }

    func testSyncAcceptsOnlyAutoOrOff() {
        var d = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollValueWrite.sync("APPROVAL", into: &d))
        XCTAssertNil(d.syncMode)
        XCTAssertTrue(EnrollValueWrite.sync("OFF", into: &d))
        XCTAssertEqual(d.syncMode, "OFF")
    }

    func testAccessAcceptsOnlyTheTwoModes() {
        var d = EnrollmentDraft(id: UUID())
        XCTAssertFalse(EnrollValueWrite.access("", into: &d))
        XCTAssertNil(d.lessonAccess)
        XCTAssertTrue(EnrollValueWrite.access("one-at-a-time", into: &d))
        XCTAssertEqual(d.lessonAccess, "one-at-a-time")
    }

    func testExistingLessonDatesReadTheActiveEnrollmentsSchedules() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g1/enrollments", json:
            #"{"success":true,"enrollments":[{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-01T00:00:00.000Z","endDate":"2099-01-01T00:00:00.000Z"},{"id":"e0","groupId":"g1","studyProgramId":"p0","startDate":"2020-01-01T00:00:00.000Z","endDate":"2020-02-01T00:00:00.000Z"}]}"#)
        api.stub("GET", "/api/enrollments/e1", json:
            #"{"success":true,"enrollment":{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-01T00:00:00.000Z","endDate":"2099-01-01T00:00:00.000Z","lessonSchedules":[{"id":"s1","enrollmentId":"e1","lessonId":"l1","scheduledDate":"2035-01-08T06:00:00.000Z","lesson":{"id":"l1","programId":"p1","orderIndex":1}}]}}"#)
        let dates = await EnrollSelectScheduleContainer.existingLessonDates(groupId: "g1", state: state, api: api)
        XCTAssertEqual(dates.count, 1)
        XCTAssertEqual(api.callCount("GET", "/api/enrollments/e0"), 0)   // ended enrollments are skipped
    }
}
