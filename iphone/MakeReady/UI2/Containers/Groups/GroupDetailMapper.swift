import Foundation

/// ui2-groups-browse D4, D5, D12, D13/D21, D16–D18 + groups-detail §2–§3: one group's page from
/// the group stores. Pure. A store never loaded keeps its section empty (D4) — the screen draws
/// each section's empty line; the stats count the lists themselves (the screen's R-30).
enum GroupDetailMapper {
    private static let weekdaysShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let weekdaysLong = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current
    /// D13: the chart opens on today−23 … today+3 (today 4th from the end).
    static let chartBackDays = 23

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    struct Input {
        /// The pushing row's name — the header while the group loads (D4).
        var name: String
        var group: UserGroup? = nil
        var members: [GroupMember] = []
        var requests: [JoinRequest] = []
        var enrollments: [EnrollmentWithProgram] = []
        var nextStudy: NextStudy? = nil
        var history: [GroupHistoryEvent] = []
        var days: [HomeDay]? = nil
        var chart: GroupChart? = nil
    }

    /// D7: a member row opens the MEMBER (`GroupMember.userId`), not the membership row.
    struct MemberRow: Equatable {
        let id: String
        let name: String
    }

    struct Output {
        var state: GroupsDetailScreen.State
        var memberRows: [MemberRow]

        func member(atRow row: Int) -> MemberRow? {
            memberRows.indices.contains(row) ? memberRows[row] : nil
        }
    }

    struct Chart: Equatable {
        var dates: [String] = []
        var scheduled: [Int] = []
        var completed: [Int] = []
        var windowStart: String = ""
        var windowEnd: String = ""
        var today: String = ""
    }

    static func output(_ input: Input, now: Date, timeZone: TimeZone) -> Output {
        let g = input.group
        // D18: newest member first (the AppState index is a Set and loses the server's order).
        let members = input.members.sorted { lhs, rhs in
            lhs.joinedAt != rhs.joinedAt ? lhs.joinedAt > rhs.joinedAt : lhs.name < rhs.name
        }
        let enrollments = input.enrollments.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        let rail = rail(days: input.days, chart: input.chart, now: now, timeZone: timeZone)
        let chart = chart(input.chart, now: now, timeZone: timeZone)
        let study = input.nextStudy
        let slides = Array((study?.activities ?? []).prefix(3))          // D17: the first 3
        let state = GroupsDetailScreen.State(
            groupName: MembersHomeMapper.nonEmpty(g?.name) ?? input.name,
            coverURL: g?.coverImageUrl ?? "",
            leaderName: g?.creatorName ?? "",
            createdLabel: g.map { MembersHomeMapper.mediumDate($0.createdAt, timeZone: timeZone) } ?? "",
            groupDescription: g?.description ?? "",
            visibility: g.map { visibilityLabel($0.isPrivate) } ?? "",
            ageRange: g.map { ageLabel($0.ageRange) } ?? "",
            maximumMembers: g.map { maxMembersLabel($0.maxMembers) } ?? "",
            memberDirectoryAccess: g.map { directoryAccessLabel($0.memberDirectoryAccess, memberDirectory: $0.memberDirectory) } ?? "",
            lessonTitles: study.map { [MembersHomeMapper.nonEmpty($0.title) ?? "Day \($0.dayNumber)"] } ?? [],
            lessonProgramNames: study.map { [$0.studyProgram?.name ?? ""] } ?? [],
            lessonMetaLabels: study.map { [lessonMeta($0.scheduledDate, now: now, timeZone: timeZone)] } ?? [],
            lessonSlideImages: study == nil ? [] : [slides.map { $0.thumbnailUrl ?? "" }],
            lessonSlideLabels: study == nil ? [] : [slides.map { $0.title ?? "" }],
            dayMonths: rail.months,
            dayWeekdays: rail.weekdays,
            dayNumbers: rail.numbers,
            dayDateStates: rail.dateStates,
            daySeries: rail.series,
            dayLine1s: rail.line1s,
            dayLine2s: rail.line2s,
            dayDetailsStates: rail.detailsStates,
            chartDates: chart.dates,
            chartScheduled: chart.scheduled,
            chartCompleted: chart.completed,
            chartWindowStart: chart.windowStart,
            chartWindowEnd: chart.windowEnd,
            chartToday: chart.today,
            memberNames: members.map(\.name),
            memberPhotoURLs: members.map { $0.avatarUrl ?? "" },
            memberJoinedLabels: members.map {
                MembersHomeMapper.joinedLabel(isoFractional.string(from: $0.joinedAt), today: now, timeZone: timeZone)
            },
            requestNames: input.requests.map {
                MembersHomeMapper.nonEmpty(MembersHomeMapper.displayName(first: $0.member.firstName, last: $0.member.lastName)) ?? "Unknown"
            },
            requestDates: input.requests.map { dateLabel($0.createdAt, now: now, timeZone: timeZone) },
            programTitles: enrollments.map { $0.studyProgram?.name ?? "" },
            programDescriptions: enrollments.map { $0.studyProgram?.description ?? "" },
            programEnrolledDates: enrollments.map { e in
                e.createdAt.map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? ""
            },
            programCoverURLs: enrollments.map { $0.studyProgram?.coverImageUrl ?? "" },
            eventDates: input.history.map { event in
                MembersHomeMapper.parseDate(event.occurredAt).map { dateLabel($0, now: now, timeZone: timeZone) } ?? ""
            },
            eventTexts: input.history.map(\.text),
            eventHighlights: input.history.map { $0.highlight ?? "" },
            // D16; F8: C-065's built Tone renders "accent" plain until its rebuild.
            eventTones: input.history.map { $0.highlight == nil ? "neutral" : "accent" }
        )
        return Output(state: state, memberRows: members.map { MemberRow(id: $0.userId, name: $0.name) })
    }

    // MARK: - D5 settings values

    static func ageLabel(_ range: AgeRange?) -> String {
        switch (range?.min, range?.max) {
        case let (min?, max?): return "\(min) - \(max)"
        case let (min?, nil): return "\(min)+"
        case let (nil, max?): return "Up to \(max)"
        case (nil, nil): return "Any age"
        }
    }

    static func visibilityLabel(_ isPrivate: Bool) -> String { isPrivate ? "Private" : "Public" }

    static func maxMembersLabel(_ max: Int?) -> String { max.map { "\($0)" } ?? "Unlimited" }

    /// D5/D11: the enum's three labels; a server without the enum (nil) or a value this build does
    /// not know reads the Boolean the enum was backfilled from.
    static func directoryAccessLabel(_ access: String?, memberDirectory: Bool) -> String {
        switch access {
        case "ALLOWED": return "Allowed"
        case "NAMES_ONLY": return "Names only"
        case "NOT_ALLOWED": return "Not allowed"
        default: return memberDirectory ? "Allowed" : "Not allowed"
        }
    }

    // MARK: - D16 / D17 dates

    /// D16: < 60 min "Just now", today "Today", yesterday "Yesterday", this year "MMM d", else
    /// "MMM d, yyyy" — local calendar days.
    static func dateLabel(_ date: Date, now: Date, timeZone: TimeZone) -> String {
        if now.timeIntervalSince(date) < 3600 { return "Just now" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let age = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if age == 0 { return "Today" }
        if age == 1 { return "Yesterday" }
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        let short = "\(HomeDashboardMapper.shortMonths[m - 1]) \(d)"
        return y == cal.component(.year, from: now) ? short : "\(short), \(y)"
    }

    /// D17: "Today" / "Tomorrow" / the weekday within 6 days / "MMM d", from `scheduledDate`'s UTC
    /// calendar date against the phone's local today.
    static func lessonMeta(_ scheduledDate: String, now: Date, timeZone: TimeZone) -> String {
        guard let stamp = MembersHomeMapper.parseDate(scheduledDate) else { return "" }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = utc
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = timeZone
        let s = utcCal.dateComponents([.year, .month, .day], from: stamp)
        let t = localCal.dateComponents([.year, .month, .day], from: now)
        guard let month = s.month, let day = s.day,
              let scheduled = utcCal.date(from: DateComponents(year: s.year, month: month, day: day)),
              let today = utcCal.date(from: DateComponents(year: t.year, month: t.month, day: t.day)) else { return "" }
        let offset = utcCal.dateComponents([.day], from: today, to: scheduled).day ?? 0
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return weekdaysLong[utcCal.component(.weekday, from: scheduled) - 1]
        default: return "\(HomeDashboardMapper.shortMonths[month - 1]) \(day)"
        }
    }

    // MARK: - D12 rail

    /// D12: the 30 local days today−29 … today (today trailing). Line 1 = "«N» lessons"
    /// (`scheduled_lessons`), line 2 per `line2`, `nothing` when no lessons and no sessions;
    /// series = the day's 12 two-hour session blocks in minutes. Never loaded → zero days.
    static func rail(days: [HomeDay]?, chart: GroupChart?, now: Date, timeZone: TimeZone) -> MemberProfileMapper.Rail {
        let byDay = Dictionary((days ?? []).map { ($0.day, $0) }, uniquingKeysWith: { $1 })
        let todayKey = HomeDashboardMapper.key(now, tz: timeZone)
        var r = MemberProfileMapper.Rail()
        for day in HomeDashboardMapper.days(endingAt: now, back: GroupActions.railDays - 1, ahead: 0, tz: timeZone) {
            let isToday = day.key == todayKey
            let scheduled = chart?.scheduled[day.key] ?? 0
            let completed = chart?.completed[day.key] ?? 0
            let seconds = byDay[day.key]?.sessionSeconds ?? 0
            r.months.append(HomeDashboardMapper.shortMonths[day.month - 1].uppercased())
            r.weekdays.append(isToday ? "" : weekdaysShort[day.weekday - 1])
            r.numbers.append("\(day.day)")
            r.dateStates.append(isToday ? "today" : "default")
            r.series.append(HomeDashboardMapper.blockMinutes(byDay[day.key]?.blocks))
            r.line1s.append("\(scheduled) lessons")
            r.line2s.append(line2(scheduled: scheduled, completed: completed, isToday: isToday))
            r.detailsStates.append(scheduled == 0 && seconds == 0 ? "nothing" : "default")
        }
        return r
    }

    /// D12: "«C» complete"; today "«N−C» left" while N > C; empty when N = 0.
    static func line2(scheduled: Int, completed: Int, isToday: Bool) -> String {
        guard scheduled > 0 else { return "" }
        if isToday && scheduled > completed { return "\(scheduled - completed) left" }
        return "\(completed) complete"
    }

    // MARK: - D13/D21 chart

    /// D13/D21: every day of the loaded range today−29 … today+3, zero-filled; the window opens on
    /// today−23 … today+3. Never loaded → no days (C-026's empty state).
    static func chart(_ chart: GroupChart?, now: Date, timeZone: TimeZone) -> Chart {
        let todayKey = HomeDashboardMapper.key(now, tz: timeZone)
        guard let chart else { return Chart(today: todayKey) }
        let keys = HomeDashboardMapper.days(endingAt: now, back: GroupActions.railDays - 1,
                                            ahead: GroupActions.chartAheadDays, tz: timeZone).map(\.key)
        let window = HomeDashboardMapper.days(endingAt: now, back: chartBackDays,
                                              ahead: GroupActions.chartAheadDays, tz: timeZone)
        return Chart(
            dates: keys,
            scheduled: keys.map { chart.scheduled[$0] ?? 0 },
            completed: keys.map { chart.completed[$0] ?? 0 },
            windowStart: window.first?.key ?? todayKey,
            windowEnd: window.last?.key ?? todayKey,
            today: todayKey
        )
    }
}
