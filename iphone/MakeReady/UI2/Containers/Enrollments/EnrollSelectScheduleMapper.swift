import Foundation

/// ui2-enrollment-create T8: the draft ↔ `EnrollmentSelectScheduleScreen`. The screen's strings are
/// `yyyy-MM-dd` in the device zone (its own decoder); Select's dates become the draft's exact list.
enum EnrollSelectScheduleMapper {
    static func state(draft: EnrollmentDraft, lessonCount: Int, existingLessonDates: [Date],
                      today: Date) -> EnrollmentSelectScheduleScreen.State {
        EnrollmentSelectScheduleScreen.State(
            programChosen: draft.studyProgramId != nil,
            lessonCount: lessonCount,
            today: EnrollmentWire.ymd(today),
            startDate: draft.startDate.map { EnrollmentWire.ymd($0) } ?? "",
            enabledDays: draft.enabledDays.sorted(),
            overriddenDates: draft.overriddenDates.sorted().map { EnrollmentWire.ymd($0) },
            existingLessonDates: existingLessonDates.sorted().map { EnrollmentWire.ymd($0) },
            prompt: "none"
        )
    }

    /// Select: start/end/weekdays/overrides plus the calendar's exact dates (A4: a list short of
    /// `lessonCount` is refused and the draft is left as it was).
    @MainActor
    static func apply(start: Date, end: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int,
                      to draft: inout EnrollmentDraft) -> Bool {
        guard let dates = EnrollScheduleMath.dates(start: start, days: days, overrides: overrides,
                                                   lessonCount: lessonCount) else { return false }
        // Owner 2026-10-30: a start on a turned-off weekday is allowed — the schedule starts at its
        // first lesson.
        draft.startDate = dates.first ?? start
        draft.enabledDays = days
        draft.overriddenDates = overrides
        draft.scheduleDates = dates
        draft.endDate = dates.last ?? end
        return true
    }
}
