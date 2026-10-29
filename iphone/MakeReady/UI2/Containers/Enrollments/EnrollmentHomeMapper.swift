import Foundation

/// ui2-enrollments-browse D20: §Contract Home → `EnrollmentHomeScreen.State`. Pure. Every
/// `yyyy-MM-dd` is shown as sent and compared with the device's today (F9). The empty schedule is
/// the built `empty-schedule` state: start card only, zero span, no rail, no lessons.
enum EnrollmentHomeMapper {
    struct Input {
        var name: String
        var home: EnrollmentHome?
        var loading = false
        var failed = false
    }

    static func state(_ input: Input, today: Date, timeZone: TimeZone) -> EnrollmentHomeScreen.State {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let h = input.home
        let start = h.flatMap { EnrollmentWire.date(ymd: $0.startDate, in: timeZone) }
        let end = h.flatMap { EnrollmentWire.date(ymd: $0.endDate, in: timeZone) }
        let hasSchedule = !(h?.days.isEmpty ?? true)
        let gap = (hasSchedule ? zip2(start, end) : nil).map { span(from: $0.0, to: $0.1, calendar: cal) } ?? (0, 0)
        let days = h?.days ?? []
        let dayDates = days.map { EnrollmentWire.date(ymd: $0.date, in: timeZone) }
        let lessons = h?.lessons ?? []
        let invite = inviteTime(h?.smsTime)
        let f = { (d: Date?, p: String) in d.map { format($0, p, timeZone) } ?? "" }
        var state = EnrollmentHomeScreen.State(
            coverURL: h?.studyProgram.coverImageUrl ?? "",
            programName: h?.studyProgram.name ?? input.name,
            programDescription: h?.studyProgram.description ?? "",
            memberCount: h?.memberCount ?? 0,
            authorName: h?.studyProgram.authorName ?? "",
            enrolledLabel: h.flatMap { MembersHomeMapper.parseDate($0.enrolledAt) }
                .map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? "",
            leaderName: h?.group.leader?.name ?? "",
            startMonth: f(start, "MMM"),
            startWeekday: f(start, "EEE"),
            startDay: f(start, "d"),
            endMonth: hasSchedule ? f(end, "MMM") : "",
            endWeekday: hasSchedule ? f(end, "EEE") : "",
            endDay: hasSchedule ? f(end, "d") : "",
            spanMonths: gap.0,
            spanDays: gap.1,
            dayMonths: dayDates.map { f($0, "MMM").uppercased() },
            dayWeekdays: dayDates.map { f($0, "EEE").uppercased() },
            dayNumbers: dayDates.map { f($0, "d") },
            dayDateStates: dayDates.map { d in d.map { cal.isDate($0, inSameDayAs: today) } == true ? "today" : "default" },
            dayPercents: days.map { Int($0.percent.rounded()) },
            dayLine1s: days.map { "\($0.lessonCount)" },
            dayLine2s: days.map { _ in invite },
            dayDetailsStates: days.map { _ in "lessonDay" },
            lessonNumbers: lessons.map(\.dayNumber),
            lessonTitles: lessons.map { MembersHomeMapper.nonEmpty($0.title) ?? "Day \($0.dayNumber)" },
            lessonMetaLabels: lessons.map { l in
                EnrollmentWire.date(ymd: l.date, in: timeZone).map { relativeLabel($0, today: today, calendar: cal) } ?? ""
            },
            lessonProgress: lessons.map { l in
                let isToday = EnrollmentWire.date(ymd: l.date, in: timeZone).map { cal.isDate($0, inSameDayAs: today) } ?? false
                return isToday ? l.progress : nil
            },
            lessonSlideImages: lessons.map { $0.activities.map { $0.thumbnailUrl ?? "" } },
            lessonSlideLabels: lessons.map { $0.activities.map(slideLabel) }
        )
        state.loading = input.loading && h == nil                                         // D14.4
        state.failed = input.failed && h == nil
        return state
    }

    /// T8 day line 2: `HH:mm` → `h:mma` lower-case ("7:30am"); null → "".
    static func inviteTime(_ smsTime: String?) -> String {
        guard let parts = smsTime?.split(separator: ":"), parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return "" }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", h12, minute, hour < 12 ? "am" : "pm")
    }

    /// The span between the start and end cards: whole months, then the remaining days.
    static func span(from start: Date, to end: Date, calendar: Calendar) -> (months: Int, days: Int) {
        let c = calendar.dateComponents([.month, .day], from: start, to: end)
        return (c.month ?? 0, c.day ?? 0)
    }

    /// C-063 `metaLabel`: "Today" / "Tomorrow" / "Mon D".
    static func relativeLabel(_ date: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: today) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return format(date, "MMM d", calendar.timeZone)
    }

    /// VoiceOver only: "Read: Romans 1", "Video".
    private static func slideLabel(_ a: EnrollmentHome.Activity) -> String {
        let type = a.type.lowercased().capitalized
        guard let title = MembersHomeMapper.nonEmpty(a.title) else { return type }
        return "\(type): \(title)"
    }

    private static func zip2(_ a: Date?, _ b: Date?) -> (Date, Date)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private static func format(_ date: Date, _ pattern: String, _ zone: TimeZone) -> String {
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
