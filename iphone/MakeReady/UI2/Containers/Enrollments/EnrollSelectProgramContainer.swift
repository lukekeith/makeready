import SwiftUI

/// ui2-enrollment-create D5/D11/D17/D18/D19: the checklist's program picker. Hosts the d2m-built
/// `EnrollmentSelectProgramScreen` unchanged. Programs load cache-first (`loadPrograms` sends no
/// isPublished, so eligibility is filtered locally, D5); the completed chip follows D17; Leaders
/// options come from `AppState.groupLeaders`. Programs the draft's group is currently enrolled in are
/// muted and inert (enroll-picker-hide-enrolled D1, superseding D11/D18's menu); Select `setProgram`s
/// (design rule 2) and pops. Re-keyed only on a load or a chip Save, never on the
/// query (that would drop the keyboard); Select resolves through the tracked id (`EnrollPickerSelection`).
struct EnrollSelectProgramContainer: View {
    let flowId: UUID

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leaderIds: Set<String> = []
    @State private var leaderMenuOpen = false
    @State private var pickedId: String?

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId]
        let programs = app.programs.all
        let trackedId = pickedId ?? draft?.studyProgramId
        let input = EnrollSelectProgramMapper.Input(
            programs: programs, query: query, leaderIds: leaderIds, leaders: app.groupLeaders,
            draftGroupEnrollments: draft?.groupId.map { app.enrollmentsFor(groupId: $0) },
            selectedId: trackedId,
            loading: programs.isEmpty && app.loadingStates.isLoading(.programs), today: Date())
        let output = EnrollSelectProgramMapper.output(input)
        EnrollmentSelectProgramScreen(
            state: output.state,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard let id = EnrollPickerSelection.committedId(index: index, rowIds: output.programIds, trackedId: trackedId)
                else { return }
                commit(id)
            },
            onSearch: { query = $0 },
            onOpenLeaderFilter: { leaderMenuOpen = true },
            onPickProgram: { index in if output.programIds.indices.contains(index) { pickedId = output.programIds[index] } }
        )
        .id(EnrollSelectProgramMapper.screenKey(input))
        .ui2PushedPageFill()
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: leaderIds,
                onClose: { leaderMenuOpen = false },
                onSave: { leaderIds = $0; leaderMenuOpen = false })
        }
        .task { await load() }
    }

    private func commit(_ programId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.setProgram(programId) }
        EnrollDraftSyncs.changed(flowId)                                        // ui2-enrollments-browse D3/D4
        navigator.popIfTop(.enrollSelectProgram(flowId: flowId))
    }

    /// Cache-first; background failures stay console-only.
    @MainActor
    private func load() async {
        let app = AppState.shared
        do { try await ProgramActions().loadPrograms() } catch {
            app.recordError(error, context: "EnrollSelectProgramContainer.loadPrograms")
        }
        do { try await ProgramActions().loadGroupLeaders() } catch {
            app.recordError(error, context: "EnrollSelectProgramContainer.loadGroupLeaders")
        }
        if let groupId = app.enrollmentDrafts[flowId]?.groupId, !app.groupEnrollmentIndex.hasChildren(groupId) {
            do { _ = try await EnrollmentActions().loadEnrollments(groupId: groupId) } catch {
                app.recordError(error, context: "EnrollSelectProgramContainer.loadEnrollments")
            }
        }
    }
}
