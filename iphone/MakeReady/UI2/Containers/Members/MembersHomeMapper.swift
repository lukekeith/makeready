import Foundation

/// ui2-members-browse D6/D7/D15 + members-home §3: the Members section from the directory store.
/// Pure — the container owns the selection and the debounce. Order is the server's (`joinedAt`
/// desc); the mapper never re-sorts.
enum MembersHomeMapper {
    static let allGroups = "All Groups"
    static let allLeaders = "All Leaders"

    /// One chip-menu option: the id the server filters by, the label C-036 shows.
    struct Option: Equatable {
        let id: String
        let label: String
    }

    /// The container's query: search text and the two chip picks (nil = "All …").
    struct Selection: Equatable {
        var search = ""
        var groupId: String?
        var leaderId: String?
    }

    enum Pick: Equatable {
        case all
        case option(String)
        case unknown
    }

    /// T13: the State plus the ids behind every index it renders, so a row tap or an option pick
    /// resolves against the snapshot that was on screen, never a re-read store.
    struct Output {
        var state: MembersHomeScreen.State
        var memberIds: [String]
        var groupOptionIds: [String]       // parallel to state.groupOptions minus its leading "All Groups"
        var leaderOptionIds: [String]      // parallel to state.leaderOptions minus its leading "All Leaders"

        func memberId(atRow row: Int) -> String? {
            memberIds.indices.contains(row) ? memberIds[row] : nil
        }

        func groupPick(_ label: String) -> Pick {
            Self.pick(label, all: MembersHomeMapper.allGroups, labels: state.groupOptions, ids: groupOptionIds)
        }

        func leaderPick(_ label: String) -> Pick {
            Self.pick(label, all: MembersHomeMapper.allLeaders, labels: state.leaderOptions, ids: leaderOptionIds)
        }

        private static func pick(_ label: String, all: String, labels: [String], ids: [String]) -> Pick {
            if label == all { return .all }
            guard let index = labels.firstIndex(of: label), index > 0, ids.indices.contains(index - 1)
            else { return .unknown }
            return .option(ids[index - 1])
        }
    }

    static func output(directory: OrgMemberDirectory?, groups: [Option], leaders: [Option],
                       selection: Selection, today: Date, timeZone: TimeZone) -> Output {
        // D15: a server without `viewerScope` (nil) is read as "sees everyone" — it was before D7.
        let scope = directory?.viewerScope
        let seesAll = scope?.all ?? true
        let visibleGroups = seesAll ? groups : groups.filter { (scope?.groupIds ?? []).contains($0.id) }
        let members = directory?.members ?? []
        let state = MembersHomeScreen.State(
            searchText: selection.search,
            groupFilterLabel: visibleGroups.first { $0.id == selection.groupId }?.label ?? allGroups,
            leaderFilterLabel: leaders.first { $0.id == selection.leaderId }?.label ?? allLeaders,
            groupOptions: [allGroups] + visibleGroups.map(\.label),
            leaderOptions: [allLeaders] + leaders.map(\.label),
            showsLeaderFilter: seesAll,
            memberNames: members.map { displayName(first: $0.firstName, last: $0.lastName) },
            memberPhotoURLs: members.map { nonEmpty($0.profilePicture) ?? nonEmpty($0.googlePicture) ?? "" },
            memberInitials: members.map { initials(first: $0.firstName, last: $0.lastName) },
            memberJoinedLabels: members.map { joinedLabel($0.joinedAt, today: today, timeZone: timeZone) },
            memberGroupCounts: members.map(\.groupCount)
        )
        return Output(state: state, memberIds: members.map(\.id),
                      groupOptionIds: visibleGroups.map(\.id), leaderOptionIds: leaders.map(\.id))
    }

    // MARK: - Helpers (also read by MemberProfileMapper)

    /// D6: "Joined " + the LOCAL calendar-day age d — 0 "Today", 1 "Yesterday", 2–6 "d days ago",
    /// 7–29 "⌊d/7⌋ week(s) ago", ≥ 30 "MMM d, yyyy". "" when the stamp does not parse.
    static func joinedLabel(_ iso: String, today: Date, timeZone: TimeZone) -> String {
        guard let joined = parseDate(iso) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let age = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: joined), to: cal.startOfDay(for: today)).day ?? 0)
        switch age {
        case 0: return "Joined Today"
        case 1: return "Joined Yesterday"
        case 2...6: return "Joined \(age) days ago"
        case 7...29:
            let weeks = age / 7
            return "Joined \(weeks) \(weeks == 1 ? "week" : "weeks") ago"
        default: return "Joined " + mediumDate(joined, timeZone: timeZone)
        }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// F7: Prisma's `.SSSZ` first, then a plain ISO 8601 stamp.
    static func parseDate(_ iso: String) -> Date? {
        isoFractional.date(from: iso) ?? isoPlain.date(from: iso)
    }

    /// "MMM d, yyyy" in `timeZone` — D6's absolute form ("Jan 5, 2025").
    static func mediumDate(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return "\(HomeDashboardMapper.shortMonths[m - 1]) \(d), \(y)"
    }

    static func displayName(first: String?, last: String?) -> String {
        [first, last]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// C-038 initials (OQ-C-038-3: two characters, uppercased): first + last initial, or the
    /// first two letters of the one name there is.
    static func initials(first: String?, last: String?) -> String {
        let f = nonEmpty(first?.trimmingCharacters(in: .whitespacesAndNewlines))
        let l = nonEmpty(last?.trimmingCharacters(in: .whitespacesAndNewlines))
        switch (f, l) {
        case let (f?, l?): return (String(f.prefix(1)) + String(l.prefix(1))).uppercased()
        case let (f?, nil): return String(f.prefix(2)).uppercased()
        case let (nil, l?): return String(l.prefix(2)).uppercased()
        case (nil, nil): return ""
        }
    }

    static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
