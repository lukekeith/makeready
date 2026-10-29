import Foundation

/// ui2-enrollment-create D5/D17/D19: AppState's programs → `EnrollmentSelectProgramScreen.State`.
/// Published programs with lessons only, A→Z; search and Leaders (leaderId ?? creatorId) narrow
/// locally; Orgs hidden (GET /api/programs is scoped to the session org). Pure.
enum EnrollSelectProgramMapper {
    struct Input {
        var programs: [StudyProgram]
        var query: String
        var leaderIds: Set<String>
        var leaders: [GroupLeader]
        /// D17: the draft group's enrollments; nil = no group in the draft.
        var draftGroupEnrollments: [EnrollmentWithProgram]?
        var selectedId: String?
        var loading: Bool
        var today: Date
    }

    struct Output {
        var state: EnrollmentSelectProgramScreen.State
        var programIds: [String]
        var leaderOptions: [InviteSelectGroupMapper.LeaderOption]
    }

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let leaderOf = { (p: StudyProgram) in p.leaderId ?? p.creatorId ?? "" }
        let rows = input.programs
            .filter(EnrollChecklistMapper.isEligible)
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leaderIds.isEmpty || input.leaderIds.contains(leaderOf($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let leaderOptions = input.leaders
            .map { InviteSelectGroupMapper.LeaderOption(id: $0.id, label: $0.displayName) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        let picked = leaderOptions.filter { input.leaderIds.contains($0.id) }.map(\.label)
        let startOfToday = Calendar.current.startOfDay(for: input.today)
        let completed: (StudyProgram) -> Int = { p in
            guard let enrollments = input.draftGroupEnrollments else { return p.completedEnrollmentCount ?? 0 }
            return enrollments.filter { $0.studyProgramId == p.id && $0.endDate < startOfToday }.count
        }
        let state = EnrollmentSelectProgramScreen.State(
            searchText: input.query,
            orgFilterVisible: false,
            orgFilterLabel: InviteSelectGroupMapper.restingOrgLabel,
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: picked, resting: InviteSelectGroupMapper.restingLeaderLabel, noun: "leaders"),
            programTitles: rows.map(\.name),
            programCoverURLs: rows.map { $0.coverImageUrl ?? "" },
            programCreatedLabels: rows.map { monthYear($0.createdAt) },
            programDayCounts: rows.map(\.days),
            programCompletedCounts: rows.map(completed),
            selectedIndex: input.selectedId.flatMap { id in rows.firstIndex { $0.id == id } } ?? -1,
            loading: input.loading
        )
        return Output(state: state, programIds: rows.map(\.id), leaderOptions: leaderOptions)
    }

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM yyyy"
        return f
    }()

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.timeZone = .current
        return monthYearFormatter.string(from: date)
    }
}
