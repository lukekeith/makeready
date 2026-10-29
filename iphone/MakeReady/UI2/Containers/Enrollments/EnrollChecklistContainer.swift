import SwiftUI

/// ui2-enrollment-create D6: Enroll — the POST and its error routing, apart from the view so it is
/// testable (the CreateGroupSubmit precedent).
enum EnrollSubmit {
    static let failedMessage = "Couldn't enroll"

    /// true = enrolled. Sends nothing unless every row is done and the draft is not already
    /// processing (A5). A cancelled request is silent; a 401 signs out and surfaces nothing; any
    /// other failure surfaces `failedMessage` with Retry and returns the page to its 6/6 checklist.
    @MainActor
    static func run(flowId: UUID, actions: EnrollmentActions = EnrollmentActions(), state: AppState? = nil,
                    onUnauthorized: @escaping @MainActor () async -> Void) async -> Bool {
        let state = state ?? .shared
        guard let d = state.enrollmentDrafts[flowId], d.phase == .checklist,
              let groupId = d.groupId, let programId = d.studyProgramId,
              let start = d.startDate, d.scheduleDone, let smsTime = d.smsTime,
              let syncMode = d.syncMode, let access = d.lessonAccess.flatMap(EnrollmentWire.lessonAccessWire)
        else { return false }
        state.updateEnrollmentDraft(flowId) { $0.phase = .processing }
        EnrollDraftSyncs.cancelPending(flowId)                       // ui2-enrollments-browse D30: no PATCH after Enroll
        do {
            _ = try await actions.createEnrollment(
                groupId: groupId, studyProgramId: programId, startDate: start,
                enabledDays: EnrollmentWire.dayNames(d.enabledDays), smsTime: smsTime,
                timezone: d.timezone ?? TimeZone.current.identifier,
                syncMode: syncMode == "AUTO" ? .auto : .off,
                scheduleDates: d.scheduleDates, lessonAccess: access,
                draftId: d.serverId)                                 // D11: the server deletes the draft
            state.updateEnrollmentDraft(flowId) { $0.phase = .enrolled }
            EnrollDraftSyncs.stop(flowId)
            return true
        } catch {
            state.updateEnrollmentDraft(flowId) { $0.phase = .checklist }
            if GroupActions.isCancellation(error) { return false }       // Silent: the user left
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()                                   // ui2-shell D27
                return false
            }
            state.recordError(error, context: "EnrollChecklistContainer.enroll", surface: true,
                              friendlyMessage: failedMessage,
                              retry: { Task { @MainActor in _ = await run(flowId: flowId, actions: actions, state: state, onUnauthorized: onUnauthorized) } })
            return false
        }
    }
}

/// ui2-enrollment-create D2/D6/D9: hosts the d2m-built `GroupsEnrollProgramScreen`. Every row
/// derives from the flow's draft; a row tap pushes its picker; Back (checklist) and Done/Back
/// (enrolled) end the draft and pop to the page that pushed the checklist.
struct EnrollChecklistContainer: View {
    let flowId: UUID

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @Environment(\.ui2BackSwipeGuard) private var backSwipe

    /// D10: the Discard confirmation menu is up.
    @State private var discardMenuOpen = false

    var body: some View {
        let draft = AppState.shared.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        GroupsEnrollProgramScreen(
            state: Self.screenState(draft, app: AppState.shared),
            scrollsContent: true,              // the checklist scrolls under the pinned header
            onBack: leave,
            onSelectStep: { navigator.push(Self.destination(for: $0, flowId: flowId)) },
            onEnroll: enroll,
            onDone: leave,
            // ui2-enrollments-browse D10: only while a saved draft backs the checklist (nil = no button).
            onDiscard: Self.offersDiscard(draft) ? { discardMenuOpen = true } : nil
        )
        .ui2PushedPageFill()
        // D10/D29: one red row; Done keeps editing. Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [EnrollDiscard.action],
                onSelect: { _ in
                    discardMenuOpen = false
                    Task { @MainActor in
                        await EnrollDiscard.run(flowId: flowId,
                                                pop: { navigator.popIfTop(.enrollChecklist(flowId: flowId)) },
                                                onUnauthorized: { [authManager] in
                                                    do { try await authManager.signOut() } catch {
                                                        AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                                                    }
                                                })
                    }
                },
                onDone: { discardMenuOpen = false }
            )
        }
        .onAppear {
            // A5: no swipe-back while the POST is in flight.
            backSwipe?.blocksBackSwipe = { AppState.shared.enrollmentDrafts[flowId]?.phase == .processing }
            // ui2-enrollments-browse D3/D30: this flow's autosave; a gone draft pops to the pusher.
            let entryDepth = max(0, navigator.depth() - 1)
            let sync = EnrollDraftSyncs.sync(for: flowId)
            sync.onGone = { [navigator] in navigator.popTo(entryDepth) }
            sync.onUnauthorized = { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                }
            }
            sync.changed()
        }
    }

    static func destination(for step: GroupsEnrollProgramScreen.Step, flowId: UUID) -> UI2Destination {
        switch step {
        case .group: return .enrollSelectGroup(flowId: flowId)
        case .studyProgram: return .enrollSelectProgram(flowId: flowId)
        case .schedule: return .enrollSelectSchedule(flowId: flowId)
        case .inviteTime: return .enrollSelectInviteTime(flowId: flowId)
        case .sync: return .enrollSelectSync(flowId: flowId)
        case .accessibility: return .enrollSelectAccess(flowId: flowId)
        }
    }

    /// The checklist's rows: the draft, with its group and program looked up in the stores, else the
    /// names the row it opened from showed — the list's own fallback, so both count alike (D19).
    @MainActor
    static func screenState(_ draft: EnrollmentDraft, app: AppState) -> GroupsEnrollProgramScreen.State {
        EnrollChecklistMapper.state(draft,
                                    group: draft.groupId.flatMap { app.groups[$0] },
                                    program: draft.studyProgramId.flatMap { app.programs[$0] },
                                    groupFallbackName: draft.listedGroupName,
                                    programFallbackName: draft.listedProgramName)
    }

    /// D10: the button shows while a saved draft backs the checklist and it is still a checklist.
    static func offersDiscard(_ draft: EnrollmentDraft) -> Bool {
        draft.serverId != nil && draft.phase == .checklist
    }

    /// D2/R4: Back (and Done after enrolling) ends the LOCAL flow only — a saved draft stays on the
    /// server and is never DELETEd here; D30: any pending PATCH or retry is cancelled.
    @MainActor
    static func endFlow(_ flowId: UUID, state: AppState? = nil) {
        EnrollDraftSyncs.stop(flowId)
        (state ?? .shared).endEnrollmentDraft(flowId)
    }

    private func leave() {
        Self.endFlow(flowId)
        navigator.popIfTop(.enrollChecklist(flowId: flowId))
    }

    private func enroll() {
        Task { @MainActor in
            _ = await EnrollSubmit.run(flowId: flowId, onUnauthorized: { [authManager] in
                // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                }
            })
        }
    }
}
