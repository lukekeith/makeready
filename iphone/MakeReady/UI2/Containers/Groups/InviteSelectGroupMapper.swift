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
        /// ui2-enrollment-create D5: the enroll picker lists only groups with an active member.
        var eligibleOnly: Bool = false
        /// D19: the caller's orgs — the Orgs chip shows for 2+ (GroupsHomeMapper's rule).
        var organizations: [OrganizationData] = []
        var pickedOrgIds: Set<String> = []
        /// The picked group to show selected on open; nil = none.
        var selectedId: String? = nil
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
        /// D19: one option per org, A→Z; [] unless the caller passes its orgs.
        var orgOptions: [LeaderOption]
    }

    static let restingLeaderLabel = "Leaders"
    static let restingOrgLabel = "Orgs"

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = input.groups
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leaderIds.isEmpty || input.leaderIds.contains($0.creatorId) }   // D5: any of
            .filter { !input.eligibleOnly || EnrollChecklistMapper.isEligible($0) }
            .filter { input.pickedOrgIds.isEmpty || $0.organizationId.map(input.pickedOrgIds.contains) == true }
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
        let orgOptions = input.organizations
            .map { LeaderOption(id: $0.id, label: $0.name) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        let pickedOrgs = orgOptions.filter { input.pickedOrgIds.contains($0.id) }.map(\.label)
        let state = EnrollmentSelectGroupScreen.State(
            searchText: input.query,
            orgFilterVisible: input.organizations.count > 1,
            orgFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedOrgs, resting: restingOrgLabel, noun: "orgs"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: picked, resting: restingLeaderLabel, noun: "leaders"),
            groupNames: rows.map(\.name),
            groupPhotoURLs: rows.map { $0.coverImageUrl ?? "" },
            groupLeaderNames: rows.map { $0.creatorName ?? "" },
            groupMemberCounts: rows.map(\.memberCount),
            groupEnrollmentCounts: rows.map { input.enrollmentCounts[$0.id] ?? 0 },
            selectedIndex: input.selectedId.flatMap { id in rows.firstIndex { $0.id == id } } ?? -1,
            loading: input.loading,
            failed: input.failed
        )
        return Output(state: state, groupIds: rows.map(\.id), leaderOptions: leaderOptions, orgOptions: orgOptions)
    }

    /// ui2-enrollment-create D14: the third chip counts active enrollments only (upcoming counts).
    static func activeEnrollmentCounts(_ groups: [UserGroup],
                                       enrollmentsFor: (String) -> [EnrollmentWithProgram]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: groups.map { g in (g.id, enrollmentsFor(g.id).filter(\.isActive).count) })
    }
}
