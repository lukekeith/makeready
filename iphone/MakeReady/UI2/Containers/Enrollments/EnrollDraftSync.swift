import Foundation

/// ui2-enrollments-browse D3/D4/D6/D26/D30: one checklist flow's autosave. A commit point calls
/// `changed()`; the sync sends D3's POST once the draft holds a group and a program (adopting the
/// server id, D21), then a PATCH of what differs from the server's last acknowledged copy
/// (`AppState.enrollmentDraftBaselines`). At most one request is in flight: changes made meanwhile
/// are picked up when it returns. A failure retries once after `retryDelay`; a second failure marks
/// the flow dirty and banners once per dirty episode (D26). 409 re-seeds the flow in place (D6);
/// 404 is D30's gone path. Never a timer for UI — the only wait is the retry's `sleep`. Back
/// (`finish`) lets the save in flight and its one retry settle before the local flow ends (D30 as
/// superseded 2026-10-29); Discard and Enroll cancel it (`cancelPending`/`stop`).
@MainActor
final class EnrollDraftSync {
    static let retryDelay: Duration = .seconds(2)
    static let saveFailedMessage = "Couldn't save the draft"

    /// Owner 2026-10-29: D6's re-seed is announced — a notice banner naming the pair, so a checklist
    /// that suddenly shows every step done explains itself.
    static func existsMessage(groupName: String?, programName: String?) -> String {
        let group = groupName.flatMap { $0.isEmpty ? nil : $0 } ?? "This group"
        let program = programName.flatMap { $0.isEmpty ? nil : $0 } ?? "this program"
        return "\(group) already has a draft for \(program). Opened it so you can pick up where you left off."
    }

    let flowId: UUID
    private let state: AppState
    private let actions: EnrollmentDraftActions
    private let sleep: @MainActor (Duration) async throws -> Void
    /// D30: pop the checklist back to the page that pushed it (set by the checklist container).
    var onGone: @MainActor () -> Void = {}
    /// ui2-shell D27: a 401 ends the session.
    var onUnauthorized: @MainActor () async -> Void = {}

    private(set) var dirty = false
    private var bannerShown = false
    private var stopped = false
    private var inFlight: Task<Void, Never>?
    private var generation = 0
    /// Back: runs once the save in flight has settled. Non-nil = the checklist has been left.
    private var onSettled: (@MainActor () -> Void)?
    var isFinishing: Bool { onSettled != nil }

    init(flowId: UUID, state: AppState, actions: EnrollmentDraftActions,
         sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.flowId = flowId
        self.state = state
        self.actions = actions
        self.sleep = sleep
    }

    /// A commit point wrote the draft, or Retry was tapped.
    func changed() {
        guard !stopped, inFlight == nil else { return }
        generation += 1
        let mine = generation
        inFlight = Task { [weak self] in
            await self?.pump()
            guard let self, self.generation == mine else { return }
            self.inFlight = nil
            if let done = self.onSettled {
                self.onSettled = nil
                self.stopped = true
                done()
            }
        }
    }

    /// Drop the request or retry in flight; the unsent fields stay unsent until the next `changed()`.
    func cancelPending() {
        inFlight?.cancel()
        inFlight = nil
        generation += 1
    }

    /// Discard and Enroll (success): nothing more is ever sent for this flow.
    func stop() {
        stopped = true
        cancelPending()
    }

    /// D2/D30 Back: the create/PATCH in flight — and its one retry — is not cancelled; once it has
    /// settled nothing more is sent and `done` runs (now, when nothing is in flight). A failure after
    /// Back stays console-only and a 404 is silent: the checklist is gone.
    func finish(_ done: @escaping @MainActor () -> Void) {
        guard inFlight != nil, !stopped else {
            stopped = true
            done()
            return
        }
        onSettled = done
    }

    /// The checklist is back on screen before the save settled: keep the flow.
    func reopen() { onSettled = nil }

    /// Tests: wait until the sync is idle.
    func flush() async {
        while let task = inFlight { await task.value }
    }

    private func pump() async {
        var retried = false
        while !Task.isCancelled, !stopped,
              let current = state.enrollmentDrafts[flowId], current.phase == .checklist {
            do {
                if let serverId = current.serverId {
                    let base = state.enrollmentDraftBaselines[flowId] ?? EnrollmentDraft(id: flowId)
                    let body = EnrollmentDraftMapping.patchBody(from: base, to: current)
                    if body.isEmpty { settle(); return }
                    let outcome = try await actions.update(id: serverId, body: body)
                    guard !Task.isCancelled else { return }
                    try await apply(outcome, sent: current)
                } else {
                    guard current.groupId != nil, current.studyProgramId != nil else { return }      // D3
                    let outcome = try await actions.create(body: EnrollmentDraftMapping.createBody(current))
                    guard !Task.isCancelled else { return }
                    try await apply(outcome, sent: current)
                }
                retried = false
            } catch {
                if Task.isCancelled || GroupActions.isCancellation(error) { return }
                if AuthStatusPolicy.shouldSignOut(after: error) {
                    await onUnauthorized()
                    return
                }
                if let http = error as? APIHTTPError, http.status == 404 {                         // D30
                    if isFinishing {                                    // after Back: forget it silently
                        if let serverId = current.serverId { actions.forget(id: serverId) }
                        return
                    }
                    EnrollDraftOpen.gone(flowId: flowId, draftId: current.serverId, error: error,
                                         pop: onGone, state: state, actions: actions)
                    return
                }
                if !retried {                                                                     // D26
                    retried = true
                    do { try await sleep(Self.retryDelay) } catch { return }
                    continue
                }
                markDirty(error)
                return
            }
        }
    }

    private func apply(_ outcome: DraftWriteOutcome, sent: EnrollmentDraft) async throws {
        switch outcome {
        case .saved(let wire):
            var base = sent
            base.serverId = wire.id
            base.createdByName = wire.createdBy?.name
            base.serverUpdatedAt = wire.updatedAt
            state.enrollmentDraftBaselines[flowId] = base
            state.updateEnrollmentDraft(flowId) {
                $0.serverId = wire.id
                $0.createdByName = wire.createdBy?.name
                $0.serverUpdatedAt = wire.updatedAt
            }
        case .exists(let draftId):                                                                 // D6
            let wire = try await actions.load(id: draftId)
            guard !Task.isCancelled else { return }
            state.seedEnrollmentDraft(wire, flowId: flowId)
            if !isFinishing {                                   // after Back there is nothing to explain
                state.showNotice(Self.existsMessage(groupName: state.groups[wire.groupId]?.name,
                                                    programName: state.programs[wire.studyProgramId]?.name),
                                 context: "EnrollDraftSync.exists")
            }
        }
        settle()
    }

    private func settle() {
        dirty = false
        bannerShown = false
    }

    private func markDirty(_ error: Error) {
        dirty = true
        if isFinishing {
            state.recordError(error, context: "EnrollDraftSync.save")
            return
        }
        guard !bannerShown else { return }
        bannerShown = true
        state.recordError(error, context: "EnrollDraftSync.save", surface: true,
                          friendlyMessage: Self.saveFailedMessage,
                          retry: { [weak self] in Task { @MainActor in self?.changed() } })
    }
}

/// One `EnrollDraftSync` per open flow, shared by the checklist and its six pickers.
@MainActor
enum EnrollDraftSyncs {
    private static var syncs: [UUID: EnrollDraftSync] = [:]

    static func sync(for flowId: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil) -> EnrollDraftSync {
        if let existing = syncs[flowId] { return existing }
        let state = state ?? .shared
        let created = EnrollDraftSync(flowId: flowId, state: state, actions: actions ?? EnrollmentDraftActions(state: state))
        syncs[flowId] = created
        return created
    }

    /// D4: called by each picker right after its Select/Save wrote the draft. Only the checklist
    /// registers a sync: a flow that already ended (Discard, Back, Enroll) has none, so this is a no-op.
    /// A flow that is finishing after Back has no picker left to call it.
    static func changed(_ flowId: UUID) { syncs[flowId]?.changed() }

    static func cancelPending(_ flowId: UUID) { syncs[flowId]?.cancelPending() }

    static func stop(_ flowId: UUID) { syncs.removeValue(forKey: flowId)?.stop() }

    /// D2/D30 Back: the flow's save in flight settles, then the sync leaves the registry and the local
    /// flow ends. No sync → the flow ends now.
    static func finish(_ flowId: UUID, state: AppState) {
        guard let sync = syncs[flowId] else {
            state.endEnrollmentDraft(flowId)
            return
        }
        sync.finish { [weak sync] in
            if let sync, syncs[flowId] === sync { syncs[flowId] = nil }
            state.endEnrollmentDraft(flowId)
        }
    }

    /// The shell's prune (ui2-enrollment-create D13 + R4): a flow whose checklist left every stack
    /// ends like Back — its save in flight settles first — and its local draft is kept until then.
    /// Never a request of its own, never a DELETE.
    static func prune(keeping ids: Set<UUID>, state: AppState? = nil) {
        let state = state ?? .shared
        for id in Array(syncs.keys) where !ids.contains(id) { finish(id, state: state) }
        let settling = Set(syncs.filter { $0.value.isFinishing }.keys)
        state.pruneEnrollmentDrafts(keeping: ids.union(settling))
    }

    static func isRegistered(_ flowId: UUID) -> Bool { syncs[flowId] != nil }
}
