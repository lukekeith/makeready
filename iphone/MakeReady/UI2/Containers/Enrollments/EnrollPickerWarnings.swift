import Foundation

/// ui2-enrollment-create D11/D18: the group and program pickers' Select warnings. They never block
/// — the container shows C-066 with "… — select anyway" and "Choose another" (a recorded deviation:
/// C-066 draws no title or body; a titled confirm is a `/ui2-component-update C-066` follow-up).
enum EnrollPickerWarnings {
    enum Warning: Equatable { case alreadyEnrolled, lessonOverlap }

    static let chooseAnother = "Choose another"

    static func confirmLabel(_ warning: Warning) -> String {
        switch warning {
        case .alreadyEnrolled: return "Already enrolled — select anyway"
        case .lessonOverlap: return "Lesson already scheduled — select anyway"
        }
    }

    static func forGroup(enrollments: [EnrollmentWithProgram], programId: String?, scheduleDates: [Date],
                         existingLessonDates: [Date]) -> Warning? {
        if let programId, enrollments.contains(where: { $0.studyProgramId == programId && $0.isActive }) {
            return .alreadyEnrolled
        }
        let cal = Calendar.current
        let taken = Set(existingLessonDates.map { cal.startOfDay(for: $0) })
        if scheduleDates.contains(where: { taken.contains(cal.startOfDay(for: $0)) }) { return .lessonOverlap }
        return nil
    }

    static func forProgram(groupEnrollments: [EnrollmentWithProgram]?, programId: String) -> Warning? {
        guard let groupEnrollments else { return nil }
        return groupEnrollments.contains { $0.studyProgramId == programId && $0.isActive } ? .alreadyEnrolled : nil
    }
}
