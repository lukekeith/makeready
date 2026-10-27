import Foundation

/// ui2-groups-browse D3/D20/D22 + groups-home §3: the Groups section from `AppState.groups`.
/// Pure — the container owns the typed text, the debounce and the chip picks. The screen's chip
/// menus speak labels (`GroupsHomeScreen.State.selectedOrgs` / `selectedLeaders`), so a pick is a
/// label set mapped to ids here; two leaders with one name select together (D3).
enum GroupsHomeMapper {
    static let allOrgs = "All Orgs"
    static let allLeaders = "All Leaders"

    /// The container's query. `search` is the APPLIED text — written 300 ms after the last
    /// keystroke (D3); [] = no filter.
    struct Selection: Equatable {
        var search = ""
        var orgLabels: Set<String> = []
        var leaderLabels: Set<String> = []
    }

    /// The State plus the group id behind every row it renders.
    struct Output {
        var state: GroupsHomeScreen.State
        var groupIds: [String]

        func groupId(atRow row: Int) -> String? {
            groupIds.indices.contains(row) ? groupIds[row] : nil
        }
    }

    static func output(groups: [UserGroup], leaders: [GroupLeader], organizations: [OrganizationData],
                       selection: Selection, typedSearch: String, loaded: Bool) -> Output {
        let orgChipShown = organizations.count >= 2
        let leaderLabels = unique(leaders.map(\.displayName))
        let orgLabels = unique(organizations.map(\.name))
        let pickedLeaders = leaderLabels.filter { selection.leaderLabels.contains($0) }
        // A hidden Orgs chip (< 2 orgs) can't be cleared, so it filters nothing.
        let pickedOrgs = orgChipShown ? orgLabels.filter { selection.orgLabels.contains($0) } : []
        let leaderIds = Set(leaders.filter { pickedLeaders.contains($0.displayName) }.map(\.id))
        let orgIds = Set(organizations.filter { pickedOrgs.contains($0.name) }.map(\.id))
        let rows = sorted(groups).filter { group in
            matches(group.name, search: selection.search)
                && (pickedLeaders.isEmpty || leaderIds.contains(group.creatorId))
                && (pickedOrgs.isEmpty || group.organizationId.map { orgIds.contains($0) } == true)
        }
        let state = GroupsHomeScreen.State(
            searchText: typedSearch,
            orgFilterVisible: orgChipShown,
            orgFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedOrgs, resting: allOrgs, noun: "orgs"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedLeaders, resting: allLeaders, noun: "leaders"),
            orgOptions: orgLabels,
            leaderOptions: leaderLabels,
            selectedOrgs: Set(pickedOrgs),
            selectedLeaders: Set(pickedLeaders),
            groupNames: rows.map(\.name),
            groupPhotoURLs: rows.map { $0.coverImageUrl ?? "" },
            groupLeaderNames: rows.map { MemberProfileMapper.leaderShortName($0.creatorName) },   // D20
            groupMemberCounts: rows.map(\.memberCount),
            listEmpty: listEmpty(rows: rows.count, groups: groups.count, loaded: loaded)
        )
        return Output(state: state, groupIds: rows.map(\.id))
    }

    /// D3: by name, case- and diacritic-insensitive; equal names keep a stable order by id.
    static func sorted(_ groups: [UserGroup]) -> [UserGroup] {
        groups.sorted { lhs, rhs in
            switch lhs.name.compare(rhs.name, options: [.caseInsensitive, .diacriticInsensitive]) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.id < rhs.id
            }
        }
    }

    /// D3: a case-insensitive substring of the name; an empty (trimmed) query matches all.
    static func matches(_ name: String, search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.range(of: query, options: .caseInsensitive) != nil
    }

    /// D22: "" while loading or while rows show; "noGroups" when the caller has none;
    /// "noMatch" when search or a chip hides every group.
    static func listEmpty(rows: Int, groups: Int, loaded: Bool) -> String {
        guard rows == 0, loaded else { return "" }
        return groups == 0 ? "noGroups" : "noMatch"
    }

    /// Labels in first-seen order, each once (C-036 options are keyed by label).
    private static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}
