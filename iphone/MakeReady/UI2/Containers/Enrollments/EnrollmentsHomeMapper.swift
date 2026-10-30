import Foundation

/// ui2-enrollments-browse §iphone EnrollmentsHomeContainer: the feed → `EnrollmentsHomeScreen.State`.
/// Pure. Rows keep the feed's order (D17); search is the screen's own local filter (D27).
enum EnrollmentsHomeMapper {
    static let allOrgsLabel = "All Orgs"
    static let allGroupsLabel = "All groups"
    static let allLeadersLabel = "All Leaders"
    /// Owner 2026-10-29: the status chip at rest — no status picked shows every status.
    static let restingStatusLabel = "Status"

    /// The four chips, by the dimension name the screen's `onOpenFilter` passes.
    enum Dimension: String, CaseIterable { case orgs = "Orgs", groups = "Groups", leaders = "Leaders", status = "Status" }

    /// The chips' picks — ids for the request, labels for the chips.
    struct Selection: Equatable {
        var orgId: String?
        var orgLabel: String?
        var groupId: String?
        var groupLabel: String?
        var leaderId: String?
        var leaderLabel: String?
        var statuses: Set<EnrollmentFeedFilter.Status> = []

        var filter: EnrollmentFeedFilter {
            EnrollmentFeedFilter(orgId: orgId, groupId: groupId, leaderId: leaderId, statuses: statuses)
        }
    }

    struct Input {
        var feed: EnrollmentFeed?
        /// The menus' options — the shown feed's, else the last loaded one's.
        var options: EnrollmentFeedOptions?
        var selection = Selection()
        var loading = false
        var failed = false
        var group: (String) -> UserGroup? = { _ in nil }
        var program: (String) -> StudyProgram? = { _ in nil }
    }

    struct Output {
        var state: EnrollmentsHomeScreen.State
        var rowTargets: [EnrollmentRowTarget]
        var sections: [EnrollmentFeedSection.GroupRef]

        func target(atRow row: Int) -> EnrollmentRowTarget? {
            rowTargets.indices.contains(row) ? rowTargets[row] : nil
        }

        /// D7(d): a section's C-058 arrow → that group's page.
        func groupDestination(section: Int) -> UI2Destination? {
            sections.indices.contains(section) ? .groupDetail(id: sections[section].id, name: sections[section].name) : nil
        }
    }

    static func output(_ input: Input, today: Date, timeZone: TimeZone) -> Output {
        let sections = input.feed?.sections ?? []
        var indexes: [Int] = [], titles: [String] = [], progress: [Double] = []
        var completes: [String] = [], hoursLabels: [String] = [], enrolled: [String] = [], covers: [String] = []
        var draftLabels: [String] = [], starters: [String] = []
        var memberCounts: [String] = [], dayCounts: [String] = []
        var targets: [EnrollmentRowTarget] = []
        for (sectionIndex, section) in sections.enumerated() {
            for item in section.items {
                indexes.append(sectionIndex)
                titles.append(item.studyProgram.name)
                covers.append(item.studyProgram.coverImageUrl ?? "")
                if item.kind == "draft", let wire = item.draft {
                    let n = draftCompletedSteps(wire, group: input.group(wire.groupId), program: input.program(wire.studyProgramId),
                                                groupName: section.group.name, programName: item.studyProgram.name,
                                                today: today, timeZone: timeZone)
                    // Rail (owner 2026-10-30): a pending card's line is the checklist's step progress,
                    // its days row the program's length.
                    progress.append(Double(n) / Double(checklistSteps))
                    completes.append(""); hoursLabels.append(""); enrolled.append("")
                    memberCounts.append("")
                    dayCounts.append(input.program(wire.studyProgramId).map { "\($0.days)" } ?? "")
                    draftLabels.append(draftLabel(completed: n))
                    starters.append(starterLabel(wire.createdBy?.name))
                    targets.append(.draft(wire, groupName: section.group.name, programName: item.studyProgram.name))
                } else {
                    progress.append(item.progress ?? 0)
                    completes.append("\(item.completedMembers ?? 0)/\(item.memberCount ?? 0)")       // D16
                    hoursLabels.append(hours(minutes: item.plannedMinutes ?? 0))                       // D12
                    enrolled.append(item.enrolledAt.flatMap(MembersHomeMapper.parseDate)
                        .map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? "")
                    memberCounts.append("\(item.memberCount ?? 0)"); dayCounts.append("")
                    draftLabels.append(""); starters.append("")
                    targets.append(.enrollment(id: item.id ?? "", name: item.studyProgram.name))
                }
            }
        }
        let sel = input.selection
        var state = EnrollmentsHomeScreen.State(
            searchText: "",
            orgFilterLabel: sel.orgLabel ?? allOrgsLabel,
            groupFilterLabel: sel.groupLabel ?? allGroupsLabel,
            leaderFilterLabel: sel.leaderLabel ?? allLeadersLabel,
            statusFilterLabel: FilterMenuOverlay.chipLabel(
                picked: EnrollmentFeedFilter.Status.allCases.filter(sel.statuses.contains).map(\.label),
                resting: restingStatusLabel, noun: "statuses"),
            loading: input.loading && input.feed == nil,
            failed: input.failed && input.feed == nil,
            groupNames: sections.map(\.group.name),
            groupLeaderNames: sections.map { $0.group.leader?.name ?? "" },
            groupPhotoURLs: sections.map { $0.group.coverImageUrl ?? "" },
            programGroupIndexes: indexes,
            programTitles: titles,
            programProgress: progress,
            programCompleteCounts: completes,
            programHours: hoursLabels,
            programEnrolledDates: enrolled,
            programCoverURLs: covers
        )
        state.programDraftLabels = draftLabels                                          // D14.1
        state.programDraftStarters = starters
        // Owner 2026-10-30: each group's entries as a rail of C-033 ObjectCards.
        state.programLayout = .rail
        state.programMemberCounts = memberCounts
        state.programDayCounts = dayCounts
        return Output(state: state, rowTargets: targets, sections: sections.map(\.group))
    }

    /// D12: hours with at most one decimal and no trailing `.0`.
    static func hours(minutes: Int) -> String {
        let tenths = Int((Double(minutes) / 6).rounded())
        return tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
    }

    /// The enroll checklist's step count (D14.3).
    static let checklistSteps = 6

    static func draftLabel(completed: Int) -> String { "Draft · \(completed)/\(checklistSteps)" }

    /// D7: "Started by «name»"; no starter (a deleted user, F9) → "".
    static func starterLabel(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "" }
        return "Started by \(name)"
    }

    /// D19: the checklist's own count (D14.3) over the draft as the checklist would show it, with
    /// D9's stale rule; group/program from the stores, else the feed's names.
    static func draftCompletedSteps(_ wire: DraftWire, group: UserGroup?, program: StudyProgram?,
                                    groupName: String, programName: String, today: Date, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var draft = EnrollmentDraftMapping.draft(wire, flowId: UUID(), zone: timeZone)
        draft.clearStaleStart(today: today, calendar: cal)
        let state = EnrollChecklistMapper.state(draft, group: group, program: program,
                                                groupFallbackName: groupName, programFallbackName: programName, today: today)
        return GroupsEnrollProgramScreen.completedSteps(state)
    }

    // MARK: - The four C-036 menus (D8, D13, D15) — single pick, except Status (multi-select, owner
    // 2026-10-29); Clear returns the chip to rest

    static func menu(_ dimension: Dimension, options: EnrollmentFeedOptions?,
                     organizations: [OrganizationData]) -> [FilterMenuOverlay.Option] {
        switch dimension {
        case .orgs:
            return [.init(id: "", label: allOrgsLabel)] + organizations.map { .init(id: $0.id, label: $0.name) }
        case .groups:
            return (options?.groups ?? []).map { .init(id: $0.id, label: $0.name ?? "") }
        case .leaders:
            return (options?.leaders ?? []).map { .init(id: $0.id, label: $0.name ?? "") }
        case .status:
            return EnrollmentFeedFilter.Status.allCases.map { .init(id: $0.rawValue, label: $0.label) }
        }
    }

    /// Status picks several (Save applies them); the other three pick one.
    static func isMultiSelect(_ dimension: Dimension) -> Bool { dimension == .status }

    static func selectedIds(_ dimension: Dimension, _ s: Selection) -> Set<String> {
        switch dimension {
        case .orgs: return [s.orgId ?? ""]
        case .groups: return [s.groupId ?? ""]
        case .leaders: return [s.leaderId ?? ""]
        case .status: return Set(s.statuses.map(\.rawValue))
        }
    }

    /// The Status menu's Save.
    static func savingStatuses(_ ids: Set<String>, _ s: Selection) -> Selection {
        var next = s
        next.statuses = Set(ids.compactMap(EnrollmentFeedFilter.Status.init(rawValue:)))
        return next
    }

    static func selecting(_ option: FilterMenuOverlay.Option, in dimension: Dimension, _ s: Selection) -> Selection {
        var next = s
        let id: String? = option.id.isEmpty ? nil : option.id
        switch dimension {
        case .orgs: next.orgId = id; next.orgLabel = id == nil ? nil : option.label
        case .groups: next.groupId = id; next.groupLabel = id == nil ? nil : option.label
        case .leaders: next.leaderId = id; next.leaderLabel = id == nil ? nil : option.label
        case .status: next.statuses = Set([EnrollmentFeedFilter.Status(rawValue: option.id)].compactMap { $0 })
        }
        return next
    }

    static func clearing(_ dimension: Dimension, _ s: Selection) -> Selection {
        selecting(.init(id: "", label: ""), in: dimension, s)
    }

    static func isAtRest(_ dimension: Dimension, _ s: Selection) -> Bool {
        dimension == .status ? s.statuses.isEmpty : selectedIds(dimension, s) == [""]
    }
}
