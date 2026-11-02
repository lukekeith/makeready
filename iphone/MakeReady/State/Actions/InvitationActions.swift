import Foundation

/// Invites D22: the session owns data and operation identities, including across Action instances.
struct InvitationActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.onUnauthorized = onUnauthorized
    }

    @MainActor
    func loadInvitationFeed(_ query: InvitationQuery) async -> Result<Void, InvitationActionError> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let generation = state.initialLoad.generation
        let token = UUID()
        let revision = state.invitationRevision
        state.invitationFeedOperation = token
        state.invitationFeedQuery = query
        state.invitationFeedIsStale = true
        defer {
            if current(generation), state.invitationFeedOperation == token { state.invitationFeedOperation = nil }
        }
        do {
            let response: InvitationFeedResponse = try await read(query.path)
            guard current(generation), !Task.isCancelled,
                  state.invitationFeedOperation == token, state.invitationRevision == revision else {
                return .failure(.cancelled)
            }
            state.invitations.upsertMany(response.items)
            state.invitationFeedWindow = InvitationFeedWindow(query: query, orderedIDs: response.items.map(\.id), total: response.total)
            state.invitationFilters = response.filters
            state.invitationFeedIsStale = false
            return .success(())
        } catch {
            guard state.invitationFeedOperation == token, state.invitationRevision == revision else { return .failure(.cancelled) }
            if current(generation) { state.invitationFeedOperation = nil }
            return .failure(await failure(error, generation: generation, context: "loadInvitationFeed"))
        }
    }

    @MainActor
    func loadInvitation(_ id: String) async -> Result<Void, InvitationActionError> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let generation = state.initialLoad.generation
        let token = UUID()
        let revision = state.invitationRevision
        state.invitationDetailOperations[id] = token
        defer {
            if current(generation), state.invitationDetailOperations[id] == token { state.invitationDetailOperations[id] = nil }
        }
        do {
            let detail: InvitationDetail = try await read("/api/invitations/\(id)")
            guard current(generation), !Task.isCancelled,
                  state.invitationDetailOperations[id] == token, state.invitationRevision == revision else {
                return .failure(.cancelled)
            }
            guard detail.id == id, detail.selectedInvitation != nil else { throw APIError.invalidResponse }
            state.invitationDetails[id] = detail
            state.invitationDetailsStale.remove(id)
            return .success(())
        } catch {
            guard state.invitationDetailOperations[id] == token, state.invitationRevision == revision else { return .failure(.cancelled) }
            if current(generation) { state.invitationDetailOperations[id] = nil }
            return .failure(await failure(error, generation: generation, context: "loadInvitation"))
        }
    }

    @MainActor
    func approveRequest(id: String, groupId: String) async -> Result<Void, InvitationActionError> {
        await decide(id: id, groupId: groupId, approving: true)
    }

    @MainActor
    func rejectRequest(id: String, groupId: String) async -> Result<Void, InvitationActionError> {
        await decide(id: id, groupId: groupId, approving: false)
    }

    @MainActor
    func resendInvitation(_ id: String) async -> Result<Void, InvitationActionError> {
        await mutatePhone(id: id, withdrawing: false)
    }

    @MainActor
    func withdrawInvitation(_ id: String) async -> Result<Void, InvitationActionError> {
        await mutatePhone(id: id, withdrawing: true)
    }

    @MainActor
    private func mutatePhone(id: String, withdrawing: Bool) async -> Result<Void, InvitationActionError> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let generation = state.initialLoad.generation
        let token = UUID()
        let keys = state.invitationMutationKeys(id)
        guard keys.allSatisfy({ state.invitationMutationOperations[$0] == nil }) else { return .failure(.busy) }
        for key in keys { state.invitationMutationOperations[key] = token }
        defer { finishMutation(keys, token: token, generation: generation) }
        let operation = withdrawing ? "withdraw" : "resend"
        let detail: InvitationDetail
        do {
            detail = try await read("/api/invitations/\(id)/\(operation)", method: "POST")
            guard current(generation), !Task.isCancelled else { return .failure(.cancelled) }
            guard detail.id == id, detail.selectedInvitation != nil else { throw APIError.invalidResponse }
            let affected = state.relatedInvitationIDs(id).union(detail.invitations.map(\.id))
            state.invalidateInvitationCaches(ids: affected)
            state.invitationDetails[id] = detail
            state.invitationDetailsStale.remove(id)
            let withdrawn = Set(detail.invitations.filter { $0.status == .withdrawn }.map(\.id))
            state.invitationFeedWindow?.orderedIDs.removeAll { withdrawn.contains($0) }
        } catch {
            finishMutation(keys, token: token, generation: generation)
            return .failure(await failure(error, generation: generation, context: operation + "Invitation",
                                          friendlyMessage: withdrawing ? "Couldn't withdraw the invitation" : "Couldn't resend the invitation"))
        }
        await refreshAfterMutation(id: id, groups: Set(detail.invitations.compactMap(\.groupId)),
                                   generation: generation, refreshDetail: false)
        return current(generation) && !Task.isCancelled ? .success(()) : .failure(.cancelled)
    }

    @MainActor
    private func decide(id: String, groupId: String, approving: Bool) async -> Result<Void, InvitationActionError> {
        guard !Task.isCancelled else { return .failure(.cancelled) }
        let generation = state.initialLoad.generation
        let token = UUID()
        let keys = state.invitationMutationKeys(id)
        guard keys.allSatisfy({ state.invitationMutationOperations[$0] == nil }) else { return .failure(.busy) }
        for key in keys { state.invitationMutationOperations[key] = token }
        defer { finishMutation(keys, token: token, generation: generation) }
        do {
            let groups = GroupActions(api: api, state: state)
            if approving {
                try await groups.approveJoinRequest(groupId: groupId, requestId: id)
            } else {
                try await groups.rejectJoinRequest(groupId: groupId, requestId: id)
            }
            guard current(generation), !Task.isCancelled else { return .failure(.cancelled) }
        } catch {
            finishMutation(keys, token: token, generation: generation)
            return .failure(await failure(error, generation: generation, context: approving ? "approveRequest" : "rejectRequest",
                                          friendlyMessage: approving ? "Couldn't accept the request" : "Couldn't reject the request"))
        }
        // The write committed. Reconciliation errors use the background channel and cannot undo success.
        await refreshAfterMutation(id: id, groups: [groupId], generation: generation)
        return current(generation) && !Task.isCancelled ? .success(()) : .failure(.cancelled)
    }

    @MainActor
    private func refreshAfterMutation(id: String, groups: Set<String>, generation: Int, refreshDetail: Bool = true) async {
        guard current(generation), !Task.isCancelled else { return }
        if let query = state.invitationFeedQuery ?? state.invitationFeedWindow?.query {
            _ = await loadInvitationFeed(query)
        }
        guard current(generation), !Task.isCancelled else { return }
        if refreshDetail { _ = await loadInvitation(id) }
        for group in groups {
            guard current(generation), !Task.isCancelled else { return }
            do {
                try await GroupActions(api: api, state: state).loadJoinRequests(groupId: group)
            } catch {
                _ = await failure(error, generation: generation, context: "refreshPendingRequests")
            }
        }
    }

    @MainActor
    private func finishMutation(_ keys: Set<String>, token: UUID, generation: Int) {
        guard current(generation) else { return }
        for key in keys where state.invitationMutationOperations[key] == token { state.invitationMutationOperations[key] = nil }
    }

    /// Opt into uncoalesced reads: APIClient's ordinary GET key has no session identity.
    private func read<T: Decodable>(_ path: String, method: String = "GET") async throws -> T {
        try Task.checkCancellation()
        let data = try await api.requestWithStatus(endpoint: path, method: method, body: nil)
        return try JSONDecoder.apiDecoder.decode(T.self, from: data)
    }

    @MainActor private func current(_ generation: Int) -> Bool { state.initialLoad.isCurrent(generation) }

    @MainActor
    private func failure(_ error: Error, generation: Int, context: String,
                         friendlyMessage: String? = nil) async -> InvitationActionError {
        // Silent: cancelled/superseded work belongs to no visible operation or a retired identity.
        guard current(generation), !Task.isCancelled, !Self.cancelled(error) else { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            if state.invitationUnauthorizedGeneration != generation {
                state.invitationUnauthorizedGeneration = generation
                await onUnauthorized()
            }
            return .unauthorized
        }
        state.recordError(error, context: "InvitationActions.\(context)", surface: friendlyMessage != nil,
                          friendlyMessage: friendlyMessage)
        guard let http = error as? APIHTTPError else { return .generic }
        switch http.status {
        case 403: return .forbidden
        case 404: return .notFound
        case 409: return .conflict
        case 502: return .deliveryFailed
        default: return .generic
        }
    }

    private static func cancelled(_ error: Error) -> Bool {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return true }
        if case APIError.networkError(let underlying) = error { return cancelled(underlying) }
        return false
    }
}

extension AppState {
    /// Keep the selected-ID key even after invalidation removes its cached phone.
    func invitationMutationKeys(_ id: String) -> Set<String> {
        var keys: Set<String> = ["id:" + id]
        if let phone = invitationDetails[id]?.recipientPhone ?? invitations[id]?.recipientPhone { keys.insert("phone:" + phone) }
        return keys
    }

    func invitationMutationPending(_ id: String) -> Bool {
        invitationMutationKeys(id).contains { invitationMutationOperations[$0] != nil }
    }

    /// Retire pre-write reads as well as cached details. Never touch a mutation's ownership token.
    func invalidateInvitationCaches(ids: Set<String>? = nil) {
        invitationRevision = UUID()
        invitationFeedOperation = nil
        invitationDetailOperations = [:]
        invitationFeedIsStale = true
        let removed = ids ?? Set(invitationDetails.keys)
        invitationDetailsStale.formUnion(removed)
        for id in removed { invitationDetails[id] = nil }
    }

    func relatedInvitationIDs(_ id: String) -> Set<String> {
        var ids: Set<String> = [id]
        if let detail = invitationDetails[id] { ids.formUnion(detail.invitations.map(\.id)) }
        if let phone = invitationDetails[id]?.recipientPhone ?? invitations[id]?.recipientPhone {
            ids.formUnion(invitationDetails.values.filter { $0.recipientPhone == phone }.map(\.id))
            ids.formUnion(invitations.all.filter { $0.recipientPhone == phone }.map(\.id))
        }
        return ids
    }

    func invalidateInvitationDecision(id: String, groupId: String) {
        invalidateInvitationCaches(ids: relatedInvitationIDs(id))
        invitationFeedWindow?.orderedIDs.removeAll { $0 == id }
        invitationPendingRequestOperations[groupId] = nil
        invalidateInvitationMembership(groupId: groupId)
    }

    /// Old invite responses do not say whether sending cross-accepted a pending request.
    func invalidateInvitationSend(groupId: String?) {
        invalidateInvitationCaches()
        if let groupId {
            invitationPendingRequestOperations[groupId] = nil
            pendingJoinRequestsByGroupId[groupId] = nil
            invalidateInvitationMembership(groupId: groupId)
        }
    }

    private func invalidateInvitationMembership(groupId: String) {
        members.removeMany(groupMemberIndex.get(groupId))
        groupMemberIndex.removeAll(parentId: groupId)
        groups.remove(groupId)
        groupsListLoaded = false
        historyByGroupId[groupId] = nil
        // Legacy responses may omit member/org identity. These projections reload on their next entry.
        orgMembersByOrgId = [:]
        memberDetails.clear()
        memberGroupsById = [:]
        memberGroupCardsById = [:]
        homeStatsLoaded = false
    }
}
