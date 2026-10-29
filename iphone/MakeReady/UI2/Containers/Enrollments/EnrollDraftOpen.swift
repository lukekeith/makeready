import SwiftUI

/// ui2-enrollments-browse D28/D21: what a tapped enrollments-list or group-page row opens.
enum EnrollmentRowTarget: Equatable {
    case enrollment(id: String, name: String)
    /// The names the row showed for the draft's group and program (the feed's, or the group page's):
    /// the checklist falls back to them when a store does not hold that group or program (D19).
    case draft(DraftWire, groupName: String, programName: String)
}

/// ui2-enrollments-browse D21: a draft row → the checklist for that draft (an open flow backed by
/// the same server row is reused; else a new local flow is seeded from the listed Draft), then the
/// server copy is fetched and re-seeds the flow when newer. D30: a 404 ends the flow. D19: the row's
/// group and program names ride along, so the checklist counts what the row counted.
@MainActor
enum EnrollDraftOpen {
    static let goneMessage = "This draft no longer exists"

    @discardableResult
    static func open(_ wire: DraftWire, groupName: String = "", programName: String = "",
                     push: (UI2Destination) -> Void, state: AppState? = nil) -> UUID {
        let state = state ?? .shared
        let flowId = state.enrollmentFlowId(forServerId: wire.id) ?? state.seedEnrollmentDraft(wire)
        state.updateEnrollmentDraft(flowId) {
            if !groupName.isEmpty { $0.listedGroup = EnrollmentWireRef(id: wire.groupId, name: groupName) }
            if !programName.isEmpty { $0.listedProgram = EnrollmentWireRef(id: wire.studyProgramId, name: programName) }
        }
        push(.enrollChecklist(flowId: flowId))
        return flowId
    }

    static func refresh(flowId: UUID, wire: DraftWire, pop: @escaping () -> Void,
                        state: AppState? = nil, actions: EnrollmentDraftActions? = nil) async {
        let state = state ?? .shared
        let actions = actions ?? EnrollmentDraftActions(state: state)
        do {
            let fresh = try await actions.load(id: wire.id)
            guard let held = state.enrollmentDrafts[flowId], held.phase == .checklist,
                  isNewer(fresh.updatedAt, than: held.serverUpdatedAt) else { return }
            state.seedEnrollmentDraft(fresh, flowId: flowId)
        } catch {
            if GroupActions.isCancellation(error) { return }
            if let http = error as? APIHTTPError, http.status == 404 {
                gone(flowId: flowId, draftId: wire.id, error: error, pop: pop, state: state, actions: actions)
                return
            }
            // Background read: the listed copy is already on screen — console-only.
            state.recordError(error, context: "EnrollDraftOpen.refresh")
        }
    }

    /// D19: a draft opened from a row whose group or program the stores lack (another org's group for
    /// a super admin, a co-leader's group, a program outside `loadPrograms`) loads that store, so the
    /// checklist shows the full row. The row's names cover the wait. Background read: console-only.
    static func loadMissingStores(for wire: DraftWire, api: APIClientProtocol = APIClient.shared,
                                  state: AppState? = nil) async {
        let state = state ?? .shared
        if state.groups[wire.groupId] == nil {
            do { try await GroupActions(api: api, state: state).loadGroups(forceRefresh: true) } catch {
                if !GroupActions.isCancellation(error) { state.recordError(error, context: "EnrollDraftOpen.loadGroups") }
            }
        }
        if state.programs[wire.studyProgramId] == nil {
            do { try await ProgramActions(api: api, state: state).loadPrograms(forceRefresh: true) } catch {
                if !GroupActions.isCancellation(error) { state.recordError(error, context: "EnrollDraftOpen.loadPrograms") }
            }
        }
    }

    static func isNewer(_ candidate: String, than held: String?) -> Bool {
        guard let held, let heldDate = MembersHomeMapper.parseDate(held) else { return true }
        guard let date = MembersHomeMapper.parseDate(candidate) else { return false }
        return date > heldDate
    }

    /// D30: the server has no such draft — forget it everywhere, end the flow, say so, pop the
    /// checklist. Silent once the flow has left `checklist` (a just-enrolled draft is gone on purpose).
    static func gone(flowId: UUID, draftId: String?, error: Error, pop: () -> Void,
                     state: AppState, actions: EnrollmentDraftActions) {
        guard state.enrollmentDrafts[flowId]?.phase == .checklist else { return }
        if let draftId { actions.forget(id: draftId) }
        state.endEnrollmentDraft(flowId)
        state.recordError(error, context: "EnrollDraftOpen.gone", surface: true, friendlyMessage: goneMessage)
        pop()
    }

    /// D28 + D21: an enrollment row pushes its page; a draft row pushes the checklist and refreshes
    /// it, popping back to this page if the draft turns out to be gone, and loads a group or program
    /// the stores lack (D19).
    static func route(_ target: EnrollmentRowTarget?, navigator: UI2Navigator) {
        switch target {
        case let .enrollment(id, name)?:
            navigator.push(.enrollmentHome(id: id, name: name))
        case let .draft(wire, groupName, programName)?:
            let depth = navigator.depth()
            let flowId = open(wire, groupName: groupName, programName: programName, push: navigator.push)
            Task { @MainActor in
                async let stores: () = loadMissingStores(for: wire)
                await refresh(flowId: flowId, wire: wire, pop: { navigator.popTo(depth) })
                await stores
            }
        case nil:
            break
        }
    }
}
