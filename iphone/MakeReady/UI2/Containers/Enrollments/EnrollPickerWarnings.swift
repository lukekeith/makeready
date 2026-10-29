import Foundation

/// enroll-picker-hide-enrolled D1/D2/D5/D7 (supersedes ui2-enrollment-create D11/D18's ask-once C-066
/// menus): the pickers never present a menu. A pair with a current enrollment is unavailable — muted
/// and inert in the d2m screen — and a lesson-date clash is an amber note on the Schedule row. Pure.
enum EnrollPickerWarnings {
    static let scheduleClashMessage = "Some dates clash with this group's existing lessons"
    /// D7: Enroll's banner for `409 already_enrolled` (D6).
    static let alreadyEnrolledMessage = "This group is already enrolled in this program"

    /// D1: the programs a group is currently enrolled in — `isActive` (endDate after now: active or upcoming).
    static func currentProgramIds(_ enrollments: [EnrollmentWithProgram]) -> Set<String> {
        Set(enrollments.filter(\.isActive).map(\.studyProgramId))
    }

    /// D1: the groups currently enrolled in `programId`; none when the draft has no program.
    static func unavailableGroupIds(_ groupIds: [String], programId: String?,
                                    enrollmentsFor: (String) -> [EnrollmentWithProgram]) -> Set<String> {
        guard let programId else { return [] }
        return Set(groupIds.filter { currentProgramIds(enrollmentsFor($0)).contains(programId) })
    }

    /// D5: any schedule date on the same calendar day as one of the group's existing lessons.
    static func scheduleClashes(_ scheduleDates: [Date], existingLessonDates: [Date]) -> Bool {
        let cal = Calendar.current
        let taken = Set(existingLessonDates.map { cal.startOfDay(for: $0) })
        return scheduleDates.contains { taken.contains(cal.startOfDay(for: $0)) }
    }
}
