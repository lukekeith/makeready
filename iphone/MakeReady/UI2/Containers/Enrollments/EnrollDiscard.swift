import SwiftUI

/// ui2-enrollments-browse D10/D29/D30: Discard enrollment — DELETE the saved draft, end the local
/// flow, pop to the page that pushed the checklist. A failure keeps the page with a Retry banner; a
/// 404 is D30's gone path. Any pending autosave is cancelled first so no PATCH races the DELETE.
@MainActor
enum EnrollDiscard {
    static let label = "Discard enrollment"
    static let failedMessage = "Couldn't discard the draft"
    /// D29: the C-066 menu's one row; its Done keeps editing.
    static let action = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: label, tone: .destructive)

    @discardableResult
    static func run(flowId: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil,
                    pop: @escaping () -> Void,
                    onUnauthorized: @escaping @MainActor () async -> Void = {}) async -> Bool {
        let state = state ?? .shared
        let actions = actions ?? EnrollmentDraftActions(state: state)
        guard let draft = state.enrollmentDrafts[flowId], draft.phase == .checklist,
              let serverId = draft.serverId else { return false }
        EnrollDraftSyncs.cancelPending(flowId)
        do {
            try await actions.delete(id: serverId)
            EnrollDraftSyncs.stop(flowId)
            state.endEnrollmentDraft(flowId)
            pop()
            return true
        } catch {
            if GroupActions.isCancellation(error) { return false }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            if let http = error as? APIHTTPError, http.status == 404 {
                EnrollDraftSyncs.stop(flowId)
                EnrollDraftOpen.gone(flowId: flowId, draftId: serverId, error: error, pop: pop, state: state, actions: actions)
                return false
            }
            state.recordError(error, context: "EnrollChecklistContainer.discard", surface: true,
                              friendlyMessage: failedMessage,
                              retry: {
                                  Task { @MainActor in
                                      await run(flowId: flowId, state: state, actions: actions, pop: pop,
                                                onUnauthorized: onUnauthorized)
                                  }
                              })
            return false
        }
    }
}
