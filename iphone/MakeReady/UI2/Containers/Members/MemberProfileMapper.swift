import Foundation

/// ui2-members-browse D8–D12, D14 + members-profile §2–§3: one member's page from the member
/// stores. Pure. A store never loaded keeps its section empty (D10), and a failed load keeps the
/// last State because the stores are only written on success (F5).
enum MemberProfileMapper {
    private static let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current

    struct Input {
        /// The list row's name — the header while the page loads (members-profile §3 `loading`).
        var name: String
        var detail: MemberDetail? = nil
        var groups: [MemberGroupItem]? = nil
        var engagement: MemberEngagement? = nil
        var days: [HomeDay]? = nil
        /// The shell's org — whose `joinedAt` the Joined stat shows.
        var organizationId: String? = nil
    }

    static func state(_ input: Input, today: Date, timeZone: TimeZone) -> MembersProfileScreen.State {
        let d = input.detail
        let detailName = MembersHomeMapper.displayName(first: d?.firstName, last: d?.lastName)
        let detailInitials = MembersHomeMapper.initials(first: d?.firstName, last: d?.lastName)
        let rail = rail(input.days, today: today, timeZone: timeZone)
        let groups = input.groups ?? []
        let programs = input.engagement?.programs ?? []
        return MembersProfileScreen.State(
            memberName: detailName.isEmpty ? input.name : detailName,
            // T13: email ?? googleEmail (the `MemberProfile.displayEmail` precedent).
            email: MembersHomeMapper.nonEmpty(d?.email) ?? MembersHomeMapper.nonEmpty(d?.googleEmail) ?? "",
            avatarURL: MembersHomeMapper.nonEmpty(d?.profilePicture) ?? MembersHomeMapper.nonEmpty(d?.googlePicture) ?? "",
            initials: detailInitials.isEmpty ? listInitials(input.name) : detailInitials,
            age: age(birthday: d?.birthday, today: today, timeZone: timeZone),
            role: d.map { $0.isGroupLeader ? "Group leader" : "Member" } ?? "",              // D8
            birthday: d?.birthday.flatMap(MembersHomeMapper.parseDate).map { MembersHomeMapper.mediumDate($0, timeZone: utc) } ?? "",
            joined: joined(d, organizationId: input.organizationId, timeZone: timeZone),
            organization: (d?.organizations ?? [])
                .compactMap { MembersHomeMapper.nonEmpty($0.organization?.name) }
                .joined(separator: ", "),                                                 // D8
            phone: phoneLabel(d?.phoneNumber ?? ""),
            phoneVerified: d?.phoneVerified ?? false,                                     // D9
            gender: capitalized(d?.gender),
            address: d?.address ?? "",
            emergencyContactName: d?.emergencyContactName ?? "",
            emergencyContactPhone: phoneLabel(d?.emergencyContactPhone ?? ""),
            dayMonths: rail.months,
            dayWeekdays: rail.weekdays,
            dayNumbers: rail.numbers,
            dayDateStates: rail.dateStates,
            daySeries: rail.series,
            dayLine1s: rail.line1s,
            dayLine2s: rail.line2s,
            dayDetailsStates: rail.detailsStates,
            groupTitles: groups.map(\.name),
            groupPhotoURLs: groups.map { $0.coverImageUrl ?? "" },
            groupLeaders: groups.map { leaderShortName($0.creator?.name) },
            groupJoinedDates: groups.map { group in
                MembersHomeMapper.parseDate(group.joinedAt).map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? ""
            },
            programTitles: programs.map(\.title),
            programStates: programs.map { isComplete($0) ? "Complete" : "Progress" },    // D14
            programProgress: programs.map { isComplete($0) ? 1 : Double(min(max($0.percent, 0), 100)) / 100 },
            programCompleteCounts: programs.map { "\($0.completedCount)" },
            programHours: programs.map { "\($0.hours)" },                                // D17: whole hours
            programCoverURLs: programs.map { $0.coverImageUrl ?? "" }
        )
    }

    // MARK: - Helpers

    /// D14: finished only when every live lesson is complete — `percent` counts lessons scheduled
    /// TO DATE, so 100% mid-program is not done.
    static func isComplete(_ program: MemberEngagementProgram) -> Bool {
        program.totalCount > 0 && program.completedCount >= program.totalCount
    }

    /// Whole years from the stored birthday (a UTC calendar date) to the caller's today; "" when
    /// there is no birthday (D10).
    static func age(birthday: String?, today: Date, timeZone: TimeZone) -> String {
        guard let birthday, let born = MembersHomeMapper.parseDate(birthday) else { return "" }
        var bornCal = Calendar(identifier: .gregorian)
        bornCal.timeZone = utc
        var todayCal = Calendar(identifier: .gregorian)
        todayCal.timeZone = timeZone
        let b = bornCal.dateComponents([.year, .month, .day], from: born)
        let t = todayCal.dateComponents([.year, .month, .day], from: today)
        guard let by = b.year, let bm = b.month, let bd = b.day,
              let ty = t.year, let tm = t.month, let td = t.day else { return "" }
        let years = ty - by - ((tm, td) < (bm, bd) ? 1 : 0)
        return years >= 0 ? "\(years)" : ""
    }

    /// C-043 `Single` on a group row: "Luke Keith" → "L. Keith" (members-profile §4).
    static func leaderShortName(_ name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").map(String.init)
        guard parts.count > 1, let first = parts.first?.first, let last = parts.last else { return parts.first ?? "" }
        return "\(first). \(last)"
    }

    /// The stored E.164 number as the members-profile frame draws it ("+1 (123) 456-7890") for a
    /// NANP number; any other number as stored.
    static func phoneLabel(_ e164: String) -> String {
        let digits = Array(e164.filter(\.isNumber))
        guard e164.hasPrefix("+1"), digits.count == 11 else { return e164 }
        let n = digits.dropFirst().map { String($0) }
        return "+1 (\(n[0..<3].joined())) \(n[3..<6].joined())-\(n[6..<10].joined())"
    }

    private static func capitalized(_ gender: String?) -> String {
        guard let g = MembersHomeMapper.nonEmpty(gender) else { return "" }
        return g.prefix(1).uppercased() + g.dropFirst()
    }

    private static func listInitials(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init)
        return MembersHomeMapper.initials(first: words.first, last: words.count > 1 ? words.last : nil)
    }

    /// The Joined stat: this member's `joinedAt` in the shell's org, else their first org.
    private static func joined(_ detail: MemberDetail?, organizationId: String?, timeZone: TimeZone) -> String {
        let orgs = detail?.organizations ?? []
        guard let entry = orgs.first(where: { $0.organizationId == organizationId }) ?? orgs.first,
              let date = MembersHomeMapper.parseDate(entry.joinedAt) else { return "" }
        return MembersHomeMapper.mediumDate(date, timeZone: timeZone)
    }

    struct Rail {
        var months: [String] = []
        var weekdays: [String] = []
        var numbers: [String] = []
        var dateStates: [String] = []
        var series: [[Double]] = []
        var line1s: [String] = []
        var line2s: [String] = []
        var detailsStates: [String] = []
    }

    /// D12: the 30 local days today−29 … today (today trailing); line 1 = session minutes, line 2 =
    /// the last activity's local "h:mm a" (C-071 `Muted`), a zero day the `Nothing` state. Never
    /// loaded (nil) → no cards.
    static func rail(_ days: [HomeDay]?, today: Date, timeZone: TimeZone) -> Rail {
        guard let days else { return Rail() }
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { $1 })
        let todayKey = HomeDashboardMapper.key(today, tz: timeZone)
        var r = Rail()
        for day in HomeDashboardMapper.days(endingAt: today, back: MemberActions.railDays - 1, ahead: 0, tz: timeZone) {
            let data = byDay[day.key]
            let seconds = data?.sessionSeconds ?? 0
            let isToday = day.key == todayKey
            r.months.append(HomeDashboardMapper.shortMonths[day.month - 1].uppercased())
            r.weekdays.append(isToday ? "" : weekdays[day.weekday - 1])
            r.numbers.append("\(day.day)")
            r.dateStates.append(isToday ? "today" : "default")
            r.series.append(HomeDashboardMapper.blockMinutes(data?.blocks))
            r.line1s.append("\(Int((Double(seconds) / 60).rounded())) mins")
            r.line2s.append(seconds > 0 ? (data?.lastActivityAt.flatMap { clockTime($0, timeZone: timeZone) } ?? "") : "")
            r.detailsStates.append(seconds > 0 ? "muted" : "nothing")
        }
        return r
    }

    /// "7:20 am" — `h:mm a` with the members-profile frame's lowercase day-period symbols.
    private static func clockTime(_ iso: String, timeZone: TimeZone) -> String? {
        guard let date = MembersHomeMapper.parseDate(iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }
}
