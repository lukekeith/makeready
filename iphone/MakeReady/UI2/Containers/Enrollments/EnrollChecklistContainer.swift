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
        do {
            _ = try await actions.createEnrollment(
                groupId: groupId, studyProgramId: programId, startDate: start,
                enabledDays: EnrollmentWire.dayNames(d.enabledDays), smsTime: smsTime,
                timezone: d.timezone ?? TimeZone.current.identifier,
                syncMode: syncMode == "AUTO" ? .auto : .off,
                scheduleDates: d.scheduleDates, lessonAccess: access)
            state.updateEnrollmentDraft(flowId) { $0.phase = .enrolled }
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

    var body: some View {
        let app = AppState.shared
        let draft = app.enrollmentDrafts[flowId] ?? EnrollmentDraft(id: flowId)
        GroupsEnrollProgramScreen(
            state: EnrollChecklistMapper.state(draft,
                                               group: draft.groupId.flatMap { app.groups[$0] },
                                               program: draft.studyProgramId.flatMap { app.programs[$0] }),
            onBack: leave,
            onSelectStep: { navigator.push(Self.destination(for: $0, flowId: flowId)) },
            onEnroll: enroll,
            onDone: leave
        )
        .ui2PushedPageFill()
        .onAppear {
            // A5: no swipe-back while the POST is in flight.
            backSwipe?.blocksBackSwipe = { AppState.shared.enrollmentDrafts[flowId]?.phase == .processing }
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

    private func leave() {
        AppState.shared.endEnrollmentDraft(flowId)
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
