import Foundation

/// ui2-enrollment-create D9: one "New enrollment" flow's choices — the checklist's source of truth.
/// Each picker writes it only on Select/Save; row done/disabled is derived on read, never stored.
/// Memory-only (D13): `PersistedState` never encodes it, so a relaunch or sign-out discards it.
struct EnrollmentDraft: Equatable {
    enum Phase: String { case checklist, processing, enrolled }

    let id: UUID
    var groupId: String?
    private(set) var studyProgramId: String?
    var startDate: Date?
    var enabledDays: Set<Int> = []          // 0 = Sun … 6 = Sat
    var overriddenDates: Set<Date> = []
    var scheduleDates: [Date] = []           // [] = schedule not done
    var endDate: Date?
    var smsTime: String?                     // "HH:mm"
    var timezone: String?
    var syncMode: String?                    // "AUTO" | "OFF"
    var lessonAccess: String?                // "one-at-a-time" | "all-at-once"
    var phase: Phase = .checklist

    init(id: UUID, groupId: String? = nil, studyProgramId: String? = nil) {
        self.id = id
        self.groupId = groupId
        self.studyProgramId = studyProgramId
    }

    /// The schedule row is done once its exact dates exist (A4: a short list is never stored).
    var scheduleDone: Bool { startDate != nil && !scheduleDates.isEmpty }

    /// Design rule 2: a different program un-does the schedule but keeps start / weekdays /
    /// overrides as the schedule picker's seed. Picking the same program changes nothing.
    mutating func setProgram(_ id: String?) {
        guard id != studyProgramId else { return }
        studyProgramId = id
        scheduleDates = []
        endDate = nil
    }
}

/// The calendar's own rule (MakeReadyUI's `EnrollmentDateState`, the 1.0 port) — never re-implemented.
enum EnrollScheduleMath {
    /// One date per lesson, start-of-day, ascending; nil when the rule cannot reach `lessonCount`
    /// (A4: the port's iteration cap) or there is no lesson.
    static func dates(start: Date, days: Set<Int>, overrides: Set<Date>, lessonCount: Int) -> [Date]? {
        guard lessonCount > 0, !days.isEmpty else { return nil }
        let scratch = EnrollmentDateState(lessonCount: lessonCount)
        scratch.startDate = start
        scratch.enabledDays = days
        scratch.overriddenDates = overrides
        let dates = scratch.highlightedDates.sorted()
        return dates.count == lessonCount ? dates : nil
    }
}
