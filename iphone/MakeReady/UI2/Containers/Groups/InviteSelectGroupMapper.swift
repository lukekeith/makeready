import Foundation

/// invite-member D3/D14/D16: AppState's groups → `EnrollmentSelectGroupScreen.State`. Every
/// group `GET /api/groups` returns is listed (D14), A→Z by name; search and the Leaders filter
/// narrow it locally; the Orgs chip never shows (D16). Pure — the container owns the inputs.
enum InviteSelectGroupMapper {
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]
        var query: String
        /// filter-multiselect D13: the picked creators' `User.id`s; [] = every group.
        var leaderIds: Set<String>
        var loading: Bool
        var failed: Bool
    }

    /// D13: one Leaders option — the creator's id and the name C-036 shows.
    struct LeaderOption: Equatable {
        let id: String
        let label: String
    }

    struct Output {
        var state: EnrollmentSelectGroupScreen.State
        var groupIds: [String]
        var leaderOptions: [LeaderOption]
    }

    static let restingLeaderLabel = "Leaders"
    static let restingOrgLabel = "Orgs"

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = input.groups
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leaderIds.isEmpty || input.leaderIds.contains($0.creatorId) }   // D5: any of
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var seen = Set<String>()
        let leaderOptions = input.groups
            .compactMap { g -> LeaderOption? in
                guard let name = g.creatorName, !name.isEmpty, seen.insert(g.creatorId).inserted else { return nil }
                return LeaderOption(id: g.creatorId, label: name)
            }
            .sorted {
                let byName = $0.label.localizedCaseInsensitiveCompare($1.label)
                return byName == .orderedSame ? $0.id < $1.id : byName == .orderedAscending
            }
        let picked = leaderOptions.filter { input.leaderIds.contains($0.id) }.map(\.label)
        let state = EnrollmentSelectGroupScreen.State(
            searchText: input.query,
            orgFilterVisible: false,
            orgFilterLabel: restingOrgLabel,
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: picked, resting: restingLeaderLabel, noun: "leaders"),
            groupNames: rows.map(\.name),
            groupPhotoURLs: rows.map { $0.coverImageUrl ?? "" },
            groupLeaderNames: rows.map { $0.creatorName ?? "" },
            groupMemberCounts: rows.map(\.memberCount),
            groupEnrollmentCounts: rows.map { input.enrollmentCounts[$0.id] ?? 0 },
            selectedIndex: -1,
            loading: input.loading,
            failed: input.failed
        )
        return Output(state: state, groupIds: rows.map(\.id), leaderOptions: leaderOptions)
    }
}
