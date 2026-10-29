import Foundation

/// ui2-enrollments-browse D6: a draft write's result — saved, or the pair already has a draft.
enum DraftWriteOutcome: Equatable {
    case saved(DraftWire)
    case exists(draftId: String)
}

/// ui2-enrollments-browse SC2: `/api/enrollment-drafts`. Every call keeps the HTTP status
/// (`requestWithStatus`) so callers see 404 (D30) and 409 (D6). Writes refresh
/// `enrollmentDraftsByGroupId` (both groups on a group change) and drop `enrollmentFeed` in the same call.
struct EnrollmentDraftActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?

    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    private struct One: Decodable { let success: Bool; let draft: DraftWire }
    private struct Many: Decodable { let success: Bool; let drafts: [DraftWire] }

    /// D3: the first save. 409 → `.exists` with the pair's draft id.
    @MainActor
    func create(body: [String: Any]) async throws -> DraftWriteOutcome {
        try await write("POST", "/api/enrollment-drafts", body)
    }

    /// D4: the changed fields. 409 (pair move onto another draft) → `.exists`.
    @MainActor
    func update(id: String, body: [String: Any]) async throws -> DraftWriteOutcome {
        try await write("PATCH", "/api/enrollment-drafts/\(id)", body)
    }

    /// D21 resume / D6 re-seed.
    @MainActor
    func load(id: String) async throws -> DraftWire {
        let data = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts/\(id)", method: "GET", body: nil)
        let wire = try decode(One.self, data).draft
        state.upsertEnrollmentDraftWire(wire)
        return wire
    }

    /// D7b: the group page's drafts, in the server's order (newest `updatedAt` first).
    @MainActor
    func listByGroup(groupId: String) async throws {
        let data = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts?groupId=\(groupId)", method: "GET", body: nil)
        state.enrollmentDraftsByGroupId[groupId] = try decode(Many.self, data).drafts
    }

    /// D10: Discard.
    @MainActor
    func delete(id: String) async throws {
        _ = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts/\(id)", method: "DELETE", body: nil)
        forget(id: id)
    }

    /// D30 / after a delete: the draft is gone from every store.
    @MainActor
    func forget(id: String) {
        state.removeEnrollmentDraftWire(id: id)
        state.enrollmentFeed = [:]
    }

    @MainActor
    private func write(_ method: String, _ endpoint: String, _ body: [String: Any]) async throws -> DraftWriteOutcome {
        do {
            let data = try await api.requestWithStatus(endpoint: endpoint, method: method, body: body)
            let wire = try decode(One.self, data).draft
            state.upsertEnrollmentDraftWire(wire)
            state.enrollmentFeed = [:]
            return .saved(wire)
        } catch let error as APIHTTPError where error.status == 409 {
            guard let draftId = error.details["draftId"] else { throw error }
            return .exists(draftId: draftId)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder.apiDecoder.decode(type, from: data) } catch { throw APIError.decodingError(error) }
    }
}
