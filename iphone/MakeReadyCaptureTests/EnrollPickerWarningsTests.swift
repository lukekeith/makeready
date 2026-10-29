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
