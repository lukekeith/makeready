import Foundation

/// ui2-programs D3/D4 + study-programs §3: the Programs section from `AppState.orderedPrograms`.
/// Pure — the container owns the typed text and the chip picks. Search is the screen's own (D3),
/// so the mapper only narrows by the chips; the screen's row index is this output's index. The
/// chip menus speak labels, mapped to ids here; two leaders with one name select together (D3).
enum StudyProgramsMapper {
    static let allOrgs = GroupsHomeMapper.allOrgs
    static let allLeaders = GroupsHomeMapper.allLeaders

    /// The container's chip picks; [] = no filter.
    struct Selection: Equatable {
        var orgLabels: Set<String> = []
        var leaderLabels: Set<String> = []
    }

    /// The State plus the program id behind every row it renders.
    struct Output {
        var state: StudyProgramsScreen.State
        var programIds: [String]

        func programId(atRow row: Int) -> String? {
            programIds.indices.contains(row) ? programIds[row] : nil
        }
    }

    /// - Parameters:
    ///   - programs: every cached program, in any order (`AppState.programs.all`).
    ///   - loaded: the list load succeeded this session.
    ///   - failed: the last list load failed.
    static func output(programs: [StudyProgram], leaders: [GroupLeader], organizations: [OrganizationData],
                       selection: Selection, typedSearch: String, loaded: Bool, failed: Bool) -> Output {
        let orgChipShown = organizations.count >= 2
        let leaderLabels = unique(leaders.map(\.displayName))
        let orgLabels = unique(organizations.map(\.name))
        let pickedLeaders = leaderLabels.filter { selection.leaderLabels.contains($0) }
        // A hidden Orgs chip (< 2 orgs) can't be cleared, so it filters nothing.
        let pickedOrgs = orgChipShown ? orgLabels.filter { selection.orgLabels.contains($0) } : []
        let leaderIds = Set(leaders.filter { pickedLeaders.contains($0.displayName) }.map(\.id))
        let orgIds = Set(organizations.filter { pickedOrgs.contains($0.name) }.map(\.id))
        let rows = sorted(programs).filter { program in
            (pickedLeaders.isEmpty || [program.leaderId, program.creatorId].contains { $0.map(leaderIds.contains) == true })
                && (pickedOrgs.isEmpty || program.organizationId.map { orgIds.contains($0) } == true)
        }
        // D4: skeletons only while nothing is cached; a failure over a cache keeps the list.
        let empty = programs.isEmpty
        let state = StudyProgramsScreen.State(
            searchText: typedSearch,
            orgFilterVisible: orgChipShown,
            orgFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedOrgs, resting: allOrgs, noun: "orgs"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedLeaders, resting: allLeaders, noun: "leaders"),
            orgOptions: orgLabels,
            leaderOptions: leaderLabels,
            selectedOrgs: Set(pickedOrgs),
            selectedLeaders: Set(pickedLeaders),
            loading: empty && !loaded && !failed,
            failed: empty && failed,
            programTitles: rows.map(\.name),
            programDescriptions: rows.map { $0.description ?? "" },
            programEnrollmentCounts: rows.map { $0._count?.enrollments ?? 0 },
            programCoverURLs: rows.map { $0.coverImageUrl ?? "" }
        )
        return Output(state: state, programIds: rows.map(\.id))
    }

    /// D3: newest `updatedAt` first; equal stamps keep a stable order by id.
    static func sorted(_ programs: [StudyProgram]) -> [StudyProgram] {
        programs.sorted { $0.updatedAt != $1.updatedAt ? $0.updatedAt > $1.updatedAt : $0.id < $1.id }
    }

    /// Labels in first-seen order, each once (C-036 options are keyed by label).
    private static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}
