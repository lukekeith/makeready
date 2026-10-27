import Foundation

/// invite-member D3/D14/D16: AppState's groups → `EnrollmentSelectGroupScreen.State`. Every
/// group `GET /api/groups` returns is listed (D14), A→Z by name; search and the Leaders filter
/// narrow it locally; the Orgs chip never shows (D16). Pure — the container owns the inputs.
enum InviteSelectGroupMapper {
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]
        var query: String
        var leader: String?
        var loading: Bool
        var failed: Bool
    }

    struct Output {
        var state: EnrollmentSelectGroupScreen.State
        var groupIds: [String]
        var leaderOptions: [String]
    }

    static let restingLeaderLabel = "Leaders"
    static let restingOrgLabel = "Orgs"

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = input.groups
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leader == nil || $0.creatorName == input.leader }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let leaderOptions = Set(input.groups.compactMap { $0.creatorName }.filter { !$0.isEmpty })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let state = EnrollmentSelectGroupScreen.State(
            searchText: input.query,
            orgFilterVisible: false,
            orgFilterLabel: restingOrgLabel,
            leaderFilterLabel: input.leader ?? restingLeaderLabel,
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
