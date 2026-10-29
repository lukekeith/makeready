import XCTest
@testable import MakeReady

/// enroll-picker-hide-enrolled D1/D2/D5 (supersedes ui2-enrollment-create D11/D18's ask-once menus):
/// a pair that already has a current enrollment is unavailable in the pickers; a lesson clash is a
/// note on the checklist's Schedule row.
final class EnrollPickerWarningsTests: XCTestCase {
    private let now = Date()
    private let day: TimeInterval = 86_400
    private func enrollment(_ program: String, group: String = "g", start: TimeInterval = -30 * 86_400,
                            end: TimeInterval) -> EnrollmentWithProgram {
        EnrollmentWithProgram(id: UUID().uuidString, groupId: group, studyProgramId: program,
                              startDate: now.addingTimeInterval(start), endDate: now.addingTimeInterval(end))
    }

    func testActiveAndUpcomingAreCurrentEndedIsNot() {
        let enrollments = [enrollment("active", end: 7 * day),
                           enrollment("upcoming", start: 7 * day, end: 30 * day),
                           enrollment("ended", end: -day)]
        XCTAssertEqual(EnrollPickerWarnings.currentProgramIds(enrollments), ["active", "upcoming"])
    }

    func testGroupsCurrentlyEnrolledInTheProgram() {
        let byGroup = ["g1": [enrollment("p1", group: "g1", end: day)],
                       "g2": [enrollment("p1", group: "g2", end: -day)],
                       "g3": [enrollment("p2", group: "g3", end: day)]]
        XCTAssertEqual(EnrollPickerWarnings.unavailableGroupIds(["g1", "g2", "g3"], programId: "p1",
                                                               enrollmentsFor: { byGroup[$0] ?? [] }), ["g1"])
        XCTAssertEqual(EnrollPickerWarnings.unavailableGroupIds(["g1"], programId: nil,
                                                               enrollmentsFor: { byGroup[$0] ?? [] }), [])
    }

    func testScheduleClashComparesCalendarDays() {
        let today = Calendar.current.startOfDay(for: now)
        XCTAssertTrue(EnrollPickerWarnings.scheduleClashes([today], existingLessonDates: [today.addingTimeInterval(9 * 3600)]))
        XCTAssertFalse(EnrollPickerWarnings.scheduleClashes([today], existingLessonDates: [today.addingTimeInterval(day)]))
        XCTAssertFalse(EnrollPickerWarnings.scheduleClashes([], existingLessonDates: [today]))
    }

    func testCopy() {
        XCTAssertEqual(EnrollPickerWarnings.scheduleClashMessage, "Some dates clash with this group's existing lessons")
        XCTAssertEqual(EnrollPickerWarnings.alreadyEnrolledMessage, "This group is already enrolled in this program")
    }
}
