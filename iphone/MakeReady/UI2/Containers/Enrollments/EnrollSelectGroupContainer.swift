import SwiftUI

/// ui2-enrollment-create D5/D11/D14/D18/D19: the checklist's group picker. Hosts the d2m-built
/// `EnrollmentSelectGroupScreen` unchanged: eligible groups only (D5), active-enrollment chip (D14),
/// Orgs for multi-org callers and Leaders (D19); Select warns once (D11/D18), then writes the draft
/// and pops. The picked row is tracked by id and the screen is re-keyed when its rows change, so
/// `onSelect(index)` always names the highlighted row.
struct EnrollSelectGroupContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leaderIds: Set<String> = []
    @State private var orgIds: Set<String> = []
    @State private var leaderMenuOpen = false
    @State private var orgMenuOpen = false
    @State private var pickedId: String?
    @State private var pendingWarning: (groupId: String, warning: EnrollPickerWarnings.Warning)?

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId]
        let groups = app.groups.all
        let output = InviteSelectGroupMapper.output(.init(
            groups: groups,
            enrollmentCounts: InviteSelectGroupMapper.activeEnrollmentCounts(groups, enrollmentsFor: { app.enrollmentsFor(groupId: $0) }),
            query: query, leaderIds: leaderIds,
            loading: groups.isEmpty && app.loadingStates.isLoading(.groups), failed: false,
            eligibleOnly: true, organizations: app.myOrganizations, pickedOrgIds: orgIds,
            selectedId: pickedId ?? draft?.groupId))
        EnrollmentSelectGroupScreen(
            state: output.state,
            scrollsList: true,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard output.groupIds.indices.contains(index) else { return }
                select(output.groupIds[index])
            },
            onSearch: { query = $0 },
            onOpenOrgFilter: { orgMenuOpen = true },
            onOpenLeaderFilter: { leaderMenuOpen = true },
            onPickGroup: { index in if output.groupIds.indices.contains(index) { pickedId = output.groupIds[index] } }
        )
        .id(output.groupIds)
        .ui2PushedPageFill()
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: leaderIds,
                onClose: { leaderMenuOpen = false },
                onSave: { leaderIds = $0; leaderMenuOpen = false })
        }
        .filterMenuPresentation(isPresented: orgMenuOpen, onDismiss: { orgMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.orgOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: orgIds,
                onClose: { orgMenuOpen = false },
                onSave: { orgIds = $0; orgMenuOpen = false })
        }
        // D18: C-066 has no title or body, so the warning is the confirm row's label.
        .actionMenuPresentation(isPresented: pendingWarning != nil, onDismiss: { pendingWarning = nil }) {
            ActionMenuOverlay(
                actions: [.init(glyph: "alert-triangle", label: pendingWarning.map { EnrollPickerWarnings.confirmLabel($0.warning) } ?? ""),
                          .init(glyph: "x", label: EnrollPickerWarnings.chooseAnother)],
                onSelect: { item in
                    let groupId = pendingWarning?.groupId
                    pendingWarning = nil
                    if item.label != EnrollPickerWarnings.chooseAnother, let groupId { commit(groupId) }
                },
                onDone: { pendingWarning = nil })
        }
        .task { await InviteSelectGroupContainer.loadEnrollmentCounts(for: groups.map(\.id)) }
    }

    private func select(_ groupId: String) {
        let app = AppState.shared
        guard let draft = app.enrollmentDrafts[flowId] else { return navigator.pop() }
        Task { @MainActor in
            let existing = await EnrollSelectScheduleContainer.existingLessonDates(groupId: groupId)
            if let warning = EnrollPickerWarnings.forGroup(enrollments: app.enrollmentsFor(groupId: groupId),
                                                           programId: draft.studyProgramId,
                                                           scheduleDates: draft.scheduleDates,
                                                           existingLessonDates: existing) {
                pendingWarning = (groupId, warning)
            } else {
                commit(groupId)
            }
        }
    }

    private func commit(_ groupId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.groupId = groupId }   // group change cascades nothing
        navigator.popIfTop(.enrollSelectGroup(flowId: flowId))
    }
}
