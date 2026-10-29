import Foundation

/// ui2-enrollment-create T8: draft → `GroupsEnrollProgramScreen.State`, the design's §3 rows. The
/// screen derives done/disabled from these strings ("" = to do), so a value the draft has not got
/// maps to "" — defaults never count as done (design rule 1). Pure.
enum EnrollChecklistMapper {
    static func isEligible(_ group: UserGroup) -> Bool { group.memberCount >= 1 }               // D5
    static func isEligible(_ program: StudyProgram) -> Bool { program.isPublished == true && program.days >= 1 }

    /// D10, superseded 2026-10-28 (owner, walk): a preloaded group is kept whenever it is known; an
    /// ineligible one shows on the Group row with `ineligibleGroupMessage` and the row stays to do.
    static func preloadedGroupId(_ id: String?, groups: [UserGroup]) -> String? {
        guard let id, groups.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    static let ineligibleGroupMessage = "Needs at least one member to enroll"

    static func preloadedProgramId(_ id: String?, programs: [StudyProgram]) -> String? {
        guard let id, let p = programs.first(where: { $0.id == id }), isEligible(p) else { return nil }
        return id
    }

    /// `groupFallbackName`/`programFallbackName`: the names a listing sent for a group or program the
    /// stores do not hold (D19) — used only when `group`/`program` is nil.
    static func state(_ draft: EnrollmentDraft, group: UserGroup?, program: StudyProgram?,
                      groupFallbackName: String = "", programFallbackName: String = "",
                      existingLessonDates: [Date] = [],
                      today: Date = Date()) -> GroupsEnrollProgramScreen.State {
        let cal = Calendar.current
        let start = draft.scheduleDone ? draft.startDate : nil
        var state = GroupsEnrollProgramScreen.State(
            phase: draft.phase.rawValue,
            groupName: group?.name ?? groupFallbackName,
            groupInitials: initials(group?.name ?? groupFallbackName),
            groupImageURL: group?.coverImageUrl ?? "",
            groupCreatedOn: group.map { longDate($0.createdAt) } ?? "",
            groupActiveMembers: group?.memberCount ?? 0,
            programName: program?.name ?? programFallbackName,
            programDescription: program?.description ?? "",
            programImageURL: program?.coverImageUrl ?? "",
            scheduleStartWeekday: start.map { format($0, "EEEE") } ?? "",
            scheduleStartMonth: start.map { format($0, "MMMM") } ?? "",
            scheduleStartDay: start.map { String(cal.component(.day, from: $0)) } ?? "",
            scheduleStartToday: start.map { cal.isDate($0, inSameDayAs: today) } ?? false,
            scheduleWeekdays: start == nil ? [] : draft.enabledDays.sorted().compactMap { fullDayNames.indices.contains($0) ? fullDayNames[$0] : nil },
            scheduleEndDate: (draft.scheduleDone ? draft.endDate : nil).map(longDate) ?? "",
            smsTime: draft.smsTime ?? "",
            syncMode: draft.syncMode ?? "",
            lessonAccess: draft.lessonAccess ?? ""
        )
        if let group, !isEligible(group) { state.groupIneligibleMessage = ineligibleGroupMessage }
        // enroll-picker-hide-enrolled D5: a warning, never a block — the row stays as it was.
        if draft.groupId != nil, EnrollPickerWarnings.scheduleClashes(draft.scheduleDates, existingLessonDates: existingLessonDates) {
            state.scheduleWarningMessage = EnrollPickerWarnings.scheduleClashMessage
        }
        return state
    }

    static let fullDayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// "January 3rd, 2025" — the design's §3 date form.
    static func longDate(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(format(date, "MMMM")) \(day)\(ordinal(day)), \(format(date, "yyyy"))"
    }

    static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private static func ordinal(_ day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 { case 1: return "st"; case 2: return "nd"; case 3: return "rd"; default: return "th" }
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func format(_ date: Date, _ pattern: String) -> String {
        formatter.timeZone = .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
