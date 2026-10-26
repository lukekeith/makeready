import Foundation

/// ui2-members-browse §iphone State: the Members directory and one member's page. Writes the
/// in-memory member stores on `AppState` (D21). A 401 ends the session (ui2-shell D27); any other
/// failure is recorded console-only — these are background loads — and keeps what the store
/// already holds (D28); a cancelled load (a newer keystroke) is neither written nor recorded.
struct MemberActions {
    /// D12: the member page's day rail — the 30 local days ending today.
    static let railDays = 30

    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let now: () -> Date
    private let timeZone: TimeZone
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.now = now
        self.timeZone = timeZone
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - Directory (members-home)

    /// D6/P12: one directory load — the server orders, filters and D7-scopes it. `search` is
    /// trimmed; empty values are not sent.
    @MainActor
    func loadDirectory(orgId: String, search: String = "", groupId: String? = nil, leaderId: String? = nil) async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = Self.path("/api/organizations/\(orgId)/members",
                             [("search", query), ("groupId", groupId ?? ""), ("leaderId", leaderId ?? "")])
        guard let response = await fetch("loadDirectory", path, OrgMembersResponse.self) else { return }
        state.orgMembersByOrgId[orgId] = OrgMemberDirectory(
            search: query, groupId: groupId, leaderId: leaderId,
            members: response.data, viewerScope: response.viewerScope
        )
    }

    /// The Groups and Leaders chip options (members-home §5): `/api/groups` → `AppState.groups`,
    /// `/api/group-leaders` → `AppState.groupLeaders`. Each is independent.
    @MainActor
    func loadFilterOptions() async {
        do {
            try await GroupActions(api: api, state: state).loadGroups()
        } catch {
            await handle(error, "loadFilterOptions.groups")
        }
        do {
            try await ProgramActions(api: api, state: state).loadGroupLeaders()
        } catch {
            await handle(error, "loadFilterOptions.leaders")
        }
    }

    // MARK: - One member (members-profile)

    @MainActor
    func loadMember(_ id: String) async {
        guard let response = await fetch("loadMember", "/api/members/\(id)", MemberDetailResponse.self),
              let detail = response.data else { return }
        state.memberDetails.upsert(detail)
    }

    @MainActor
    func loadMemberGroups(_ id: String) async {
        guard let response = await fetch("loadMemberGroups", "/api/members/\(id)/groups", MemberGroupsResponse.self)
        else { return }
        state.memberGroupsById[id] = response.data
    }

    /// D11: `tz` makes "lessons scheduled before today" the caller's today.
    @MainActor
    func loadEngagement(_ id: String) async {
        let path = Self.path("/api/members/\(id)/engagement", [("tz", timeZone.identifier)])
        guard let engagement = await fetch("loadEngagement", path, MemberEngagement.self) else { return }
        state.memberEngagementById[id] = engagement
    }

    /// D12/P14: `/api/home/days` filtered to the member, for today−29 … today in the caller's tz.
    @MainActor
    func loadMemberDays(_ id: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: 0, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let path = Self.path("/api/home/days", [
            ("from", from), ("to", to), ("tz", timeZone.identifier),
            ("memberId", id), ("organizationId", state.organizationId ?? "")
        ])
        guard let response = await fetch("loadMemberDays", path, HomeDaysResponse.self) else { return }
        state.memberDaysById[id] = response.days
    }

    // MARK: - Helpers

    /// `APIClient.get` takes the raw path, so each value is encoded here
    /// (`DashboardActions.queryValue` — `+`, `&`, `=`, `#` escaped). Empty values are dropped.
    static func path(_ base: String, _ params: [(String, String)]) -> String {
        let items = params.filter { !$0.1.isEmpty }
        guard !items.isEmpty else { return base }
        return base + "?" + items.map { "\($0.0)=\(DashboardActions.queryValue($0.1))" }.joined(separator: "&")
    }

    /// One GET. Returns nil — and writes nothing — when it failed, was cancelled, or a sign-out
    /// retired the session while it was in flight.
    @MainActor
    private func fetch<T: Decodable>(_ context: String, _ path: String, _ type: T.Type) async -> T? {
        let generation = state.initialLoad.generation
        do {
            let response = try await api.get(path, responseType: type)
            guard !Task.isCancelled, state.initialLoad.isCurrent(generation) else { return nil }
            return response
        } catch {
            await handle(error, context)
            return nil
        }
    }

    @MainActor
    private func handle(_ error: Error, _ context: String) async {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        state.recordError(error, context: "MemberActions.\(context)", surface: false)
    }
}
