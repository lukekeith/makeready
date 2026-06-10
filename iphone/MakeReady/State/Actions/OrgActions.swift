//
//  OrgActions.swift
//  MakeReady
//
//  Actions for organization operations.
//

import Foundation

/// Actions for organization data (members, etc.).
struct OrgActions {

    private let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // MARK: - Members

    /// Count the members of an organization. Returns nil when the response
    /// carries no member array (callers hide the count row in that case).
    /// Rehomed from OrgHomePage (Phase 2.4) — decodes only the `id` field of
    /// each membership row so this doesn't break if the server adds/removes
    /// fields from the row shape.
    @MainActor
    func loadMemberCount(organizationId: String) async throws -> Int? {
        struct MemberStub: Decodable {
            let id: String
        }
        struct MembersResponse: Decodable {
            let success: Bool?
            let data: [MemberStub]?
        }

        let response: MembersResponse = try await api.get(
            "/api/organizations/\(organizationId)/members",
            responseType: MembersResponse.self
        )
        return response.data?.count
    }
}
