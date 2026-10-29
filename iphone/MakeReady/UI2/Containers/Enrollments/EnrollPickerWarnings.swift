import Foundation

/// enroll-picker-hide-enrolled D1/D2/D5/D7 (supersedes ui2-enrollment-create D11/D18's ask-once C-066
/// menus): the pickers never present a menu. A pair with a current enrollment is unavailable — muted
/// and inert in the d2m screen — and a lesson-date clash is an amber note on the Schedule row. Pure.
enum EnrollPickerWarnings {
    /// One lesson the group already has, and the program of the enrollment it belongs to.
    struct ExistingLesson: Equatable {
        let date: Date
        let programName: String
    }
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
        !clashDays(scheduleDates, existing: existingLessonDates.map { .init(date: $0, programName: "") }).isEmpty
    }

    /// D5 (owner 2026-10-29: name the date and the enrollment): "Nov 4 clashes with Foundations of
    /// Faith" · "Nov 4 and 2 more dates clash with Foundations of Faith" — the first clashing day and
    /// the program it clashes with; "" when nothing clashes.
    static func scheduleClashMessage(_ scheduleDates: [Date], existing: [ExistingLesson]) -> String {
        let days = clashDays(scheduleDates, existing: existing)
        guard let first = days.first else { return "" }
        let cal = Calendar.current
        let program = existing.first { cal.isDate($0.date, inSameDayAs: first) }?.programName ?? ""
        let with = program.isEmpty ? "another enrollment" : program
        let date = monthDay.string(from: first)
        return days.count == 1
            ? "\(date) clashes with \(with)"
            : "\(date) and \(days.count - 1) more \(days.count == 2 ? "date" : "dates") clash with \(with)"
    }

    /// The schedule's days that fall on an existing lesson's day, ascending.
    private static func clashDays(_ scheduleDates: [Date], existing: [ExistingLesson]) -> [Date] {
        let cal = Calendar.current
        let taken = Set(existing.map { cal.startOfDay(for: $0.date) })
        return Set(scheduleDates.map { cal.startOfDay(for: $0) }).filter(taken.contains).sorted()
    }

    private static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()
}
