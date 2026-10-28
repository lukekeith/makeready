import UIKit

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
    /// trimmed; filter-multiselect D12: the picks go as sorted comma lists (`groupIds`,
    /// `leaderIds` — never the single params); empty values are not sent.
    @MainActor
    func loadDirectory(orgId: String, search: String = "", groupIds: Set<String> = [], leaderIds: Set<String> = []) async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let groups = groupIds.sorted()
        let leaders = leaderIds.sorted()
        let path = Self.path("/api/organizations/\(orgId)/members",
                             [("search", query),
                              ("groupIds", groups.joined(separator: ",")),
                              ("leaderIds", leaders.joined(separator: ","))])
        guard let response = await fetch("loadDirectory", path, OrgMembersResponse.self) else { return }
        state.orgMembersByOrgId[orgId] = OrgMemberDirectory(
            search: query, groupIds: groups, leaderIds: leaders,
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

    // MARK: - Edit one field (ui2-members-edit)

    /// D13: the edit page's line for any failure that is not a 400 / 409 with a message.
    static let saveFailedMessage = "Couldn't save. Try again."

    /// D13 / D15 / D21: PATCH one key, write it into `memberDetails` so the page shows it even if
    /// the reload fails, then re-read the member with GET. A sign-out mid-save (stale generation)
    /// writes nothing. A 401 signs out; a 400 / 409 returns the server's text; anything
    /// else is generic and recorded console-only (UI 2.0 mounts no banner — the inline line is
    /// the only surface). Never throws: the container shows every failure.
    @MainActor
    func updateMember(_ id: String, _ patch: MemberPatch) async -> Result<Void, MemberSaveError> {
        let generation = state.initialLoad.generation
        do {
            _ = try await api.requestWithStatus(endpoint: "/api/members/\(id)", method: "PATCH", body: patch.body)
        } catch {
            guard state.initialLoad.isCurrent(generation) else { return .failure(.generic) }
            return await saveFailure(error)
        }
        guard state.initialLoad.isCurrent(generation) else { return .failure(.generic) }
        state.memberDetails.update(id) { $0 = Self.applying(patch, to: $0) }
        await loadMember(id)
        return .success(())
    }

    /// D21: the sent key written into a member detail. A CHANGED phone also turns
    /// `phoneVerified` off (D5); the same number changes nothing. A birthday `YYYY-MM-DD` is
    /// stored as the GET's UTC-midnight ISO string, which `MembersHomeMapper.parseDate` reads.
    static func applying(_ patch: MemberPatch, to detail: MemberDetail) -> MemberDetail {
        var d = detail
        switch patch {
        case .email(let v): d.email = v
        case .phoneNumber(let v):
            guard let v, v != detail.phoneNumber else { return d }
            d.phoneNumber = v
            d.phoneVerified = false
        case .birthday(let v): d.birthday = v.map { "\($0)T00:00:00.000Z" }
        case .gender(let v): d.gender = v
        case .address(let v): d.address = v
        case .emergencyContactName(let v): d.emergencyContactName = v
        case .emergencyContactPhone(let v): d.emergencyContactPhone = v
        }
        return d
    }

    @MainActor
    private func saveFailure(_ error: Error) async -> Result<Void, MemberSaveError> {
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()                                     // ui2-shell D27
            return .failure(.generic)
        }
        if let http = error as? APIHTTPError, [400, 409].contains(http.status) {
            return .failure(.validation(http.message ?? Self.saveFailedMessage))
        }
        if !(error is CancellationError) {
            state.recordError(error, context: "MemberActions.updateMember", surface: false)
        }
        return .failure(.generic)
    }

    // MARK: - Avatar (image-framing-editor)

    /// image-framing-editor D8/D12: the avatar upload's long timeout (two JPEGs, up to 10MB each).
    static let avatarSaveTimeout: TimeInterval = 120

    /// D8: the multipart body — `framing` (the six-key framing as a JSON string field), `file` (the
    /// rendered avatar) and, when given, `original`; each file part `Content-Type: image/jpeg`.
    static func avatarBody(boundary: String, rendered: Data, framing: ImageFraming, original: Data?) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: framing.requestBody, options: [.sortedKeys])
        var body = Data()
        func text(_ s: String) { body.append(Data(s.utf8)) }
        func file(_ name: String, _ filename: String, _ data: Data) {
            text("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            text("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            text("\r\n")
        }
        text("--\(boundary)\r\nContent-Disposition: form-data; name=\"framing\"\r\n\r\n")
        body.append(json)
        text("\r\n")
        file("file", "avatar.jpg", rendered)
        if let original { file("original", "original.jpg", original) }
        text("--\(boundary)--\r\n")
        return body
    }

    /// D7/D8/D12: upload the rendered 512×512 avatar (JPEG 0.9) with its framing — and the original
    /// (JPEG 0.9) on a new pick or a first edit — then write the returned fields into `memberDetails`
    /// and the avatar URL into every Members-list row of the member (memory-only stores; group-detail
    /// member rows refresh on their next load). Throws the transport error untouched: 401 →
    /// `APIError.unauthorized` (the caller signs out), 403/404 → `APIHTTPError`. A sign-out while
    /// in flight writes nothing. Returns the new `profilePicture` URL.
    @MainActor
    func saveAvatar(memberId: String, rendered: UIImage, framing: ImageFraming, original: UIImage?) async throws -> String {
        struct Payload: Decodable {
            let url: String?
            let originalUrl: String?
            let framing: ImageFraming?
        }
        struct Response: Decodable {
            let success: Bool
            let data: Payload?
            let error: String?
        }
        guard let renderedJPEG = rendered.jpegData(compressionQuality: 0.9) else {
            throw APIError.serverError("Couldn't encode the photo")
        }
        var originalJPEG: Data?
        if let original {
            guard let data = original.jpegData(compressionQuality: 0.9) else {
                throw APIError.serverError("Couldn't encode the original photo")
            }
            originalJPEG = data
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = try Self.avatarBody(boundary: boundary, rendered: renderedJPEG, framing: framing, original: originalJPEG)
        let generation = state.initialLoad.generation
        let data = try await api.uploadWithStatus(endpoint: "/api/members/\(memberId)/avatar", boundary: boundary,
                                                  body: body, timeout: Self.avatarSaveTimeout)
        let response = try JSONDecoder.apiDecoder.decode(Response.self, from: data)
        guard response.success, let url = response.data?.url, !url.isEmpty else {
            throw APIError.serverError(response.error ?? "Failed to save the photo")
        }
        guard state.initialLoad.isCurrent(generation) else { return url }
        state.memberDetails.update(memberId) {
            $0.profilePicture = url
            $0.profilePictureOriginalUrl = response.data?.originalUrl
            $0.profilePictureFraming = response.data?.framing
        }
        for (orgId, var directory) in state.orgMembersByOrgId where directory.members.contains(where: { $0.id == memberId }) {
            for index in directory.members.indices where directory.members[index].id == memberId {
                directory.members[index].profilePicture = url
            }
            state.orgMembersByOrgId[orgId] = directory
        }
        return url
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
