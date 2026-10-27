//
//  GroupActions.swift
//  MakeReady
//
//  Actions for group operations.
//  Handles API calls, state mutations, and persistence.
//

import Foundation
import UIKit

/// Actions for group CRUD, posts, and member management.
struct GroupActions {

    private let api: APIClientProtocol
    private let stateOverride: AppState?
    /// ui2-groups-browse: the clock and zone the group page's day windows read (D12, D21).
    private let now: () -> Date
    private let timeZone: TimeZone
    /// ui2-groups-browse (ui2-shell D27): what a 401 from the group page's loaders does.
    private let onUnauthorized: @MainActor () async -> Void

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    ///   - now / timeZone: the group page's "today" (ui2-groups-browse D12, D21)
    ///   - onUnauthorized: the group page loaders' 401 (ui2-shell D27); the throwing
    ///     Actions above keep throwing and never call it
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.now = now
        self.timeZone = timeZone
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - Load Groups

    /// Load all groups, using cache if available
    /// - Parameter forceRefresh: If true, always fetch from API
    @MainActor
    func loadGroups(forceRefresh: Bool = false) async throws {
        // If we have cached data and not forcing refresh, show cached and refresh in background
        if state.hasCachedGroups && !forceRefresh {
            state.loadingStates.startLoading(.groups, hasCachedData: true)
            // Fetch in background without blocking
            Task {
                do {
                    try await fetchGroups()
                } catch {
                    state.recordError(error, context: "GroupActions.loadGroups (background refresh)")
                }
            }
            return
        }

        // No cache or forcing refresh - show loading state
        state.loadingStates.startLoading(.groups, hasCachedData: state.hasCachedGroups)

        try await fetchGroups()
    }

    /// Fetch groups from API and update state
    @MainActor
    private func fetchGroups() async throws {
        defer {
            state.loadingStates.finishLoading(.groups)
        }

        let response: ListGroupsResponse = try await api.get("/api/groups", responseType: ListGroupsResponse.self)

        guard response.success, let groups = response.groups else {
            throw APIError.serverError(response.error ?? "Failed to load groups")
        }

        state.groups.replaceAll(groups)
        state.persist()

        NSLog("👥 GroupActions: Loaded \(groups.count) groups")

        // Fan out per-group join-request loads in the background so the
        // pending-request badge on group cards is populated immediately
        // when the Groups tab is shown — without waiting for the user to
        // open each group's Members tab. Fire-and-forget so groups appear
        // instantly; @Observable AppState updates the UI as each lands.
        let groupIds = groups.map { $0.id }
        Task { await self.refreshAllJoinRequests(groupIds: groupIds) }
    }

    /// Refresh pending join requests for every supplied group ID in parallel.
    /// Failures are swallowed per-group so one bad call doesn't kill the rest.
    @MainActor
    private func refreshAllJoinRequests(groupIds: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for id in groupIds {
                group.addTask { @MainActor in
                    do {
                        try await self.loadJoinRequests(groupId: id)
                    } catch {
                        AppState.shared.recordError(error, context: "GroupActions.loadJoinRequests prefetch (\(id))")
                    }
                }
            }
        }
    }

    // MARK: - Get Single Group

    /// Get a group by ID
    @MainActor
    func getGroup(id: String) async throws -> UserGroup {
        state.loadingStates.startLoading(id, hasCachedData: state.groups.contains(id))

        defer {
            state.loadingStates.finishLoading(id)
        }

        let response: GroupResponse = try await api.get("/api/groups/\(id)", responseType: GroupResponse.self)

        guard response.success, let group = response.group else {
            throw APIError.serverError(response.error ?? "Group not found")
        }

        upsertKeepingOrganization(group)
        state.persist()

        return state.groups[group.id] ?? group
    }

    /// ui2-groups-browse D10 (verify A1): only `GET /api/groups` carries a group's org; the detail
    /// and PATCH responses don't, so a group they return keeps the org already cached for it —
    /// the Orgs chip filters on it.
    @MainActor
    private func upsertKeepingOrganization(_ group: UserGroup) {
        var merged = group
        if merged.organizationId == nil, let cached = state.groups[group.id] {
            merged.organizationId = cached.organizationId
            merged.organizationName = cached.organizationName
        }
        state.groups.upsert(merged)
    }

    // MARK: - Create Group

    /// Create a new group
    @MainActor
    func createGroup(
        name: String,
        description: String? = nil,
        coverImageUrl: String? = nil,
        isPrivate: Bool = false,
        allowInvites: Bool = true,
        memberDirectory: Bool = true,
        welcomeMessage: String? = nil,
        ageRange: AgeRange? = nil,
        maxMembers: Int? = nil
    ) async throws -> UserGroup {
        var body: [String: Any] = [
            "name": name,
            "isPrivate": isPrivate,
            "allowInvites": allowInvites,
            "memberDirectory": memberDirectory
        ]

        if let description = description {
            body["description"] = description
        }
        if let coverImageUrl = coverImageUrl {
            body["coverImageUrl"] = coverImageUrl
        }
        if let welcomeMessage = welcomeMessage {
            body["welcomeMessage"] = welcomeMessage
        }
        if let ageRange = ageRange {
            var ageRangeDict: [String: Any] = [:]
            if let min = ageRange.min {
                ageRangeDict["min"] = min
            }
            if let max = ageRange.max {
                ageRangeDict["max"] = max
            }
            body["ageRange"] = ageRangeDict
        }
        if let maxMembers = maxMembers {
            body["maxMembers"] = maxMembers
        }

        let response: GroupResponse = try await api.post("/api/groups", body: body, responseType: GroupResponse.self)

        guard response.success, let group = response.group else {
            throw APIError.serverError(response.error ?? "Failed to create group")
        }

        state.groups.upsert(group)
        state.persist()

        NSLog("👥 GroupActions: Created group '\(group.name)'")
        return group
    }

    // MARK: - Update Group

    /// Update group metadata
    @MainActor
    func updateGroup(
        id: String,
        name: String? = nil,
        description: String? = nil,
        coverImageUrl: String? = nil,
        isPrivate: Bool? = nil,
        allowInvites: Bool? = nil,
        memberDirectory: Bool? = nil,
        welcomeMessage: String? = nil,
        ageRange: AgeRange? = nil,
        maxMembers: Int? = nil
    ) async throws -> UserGroup {
        var body: [String: Any] = [:]

        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let coverImageUrl = coverImageUrl { body["coverImageUrl"] = coverImageUrl }
        if let isPrivate = isPrivate { body["isPrivate"] = isPrivate }
        if let allowInvites = allowInvites { body["allowInvites"] = allowInvites }
        if let memberDirectory = memberDirectory { body["memberDirectory"] = memberDirectory }
        if let welcomeMessage = welcomeMessage { body["welcomeMessage"] = welcomeMessage }
        if let ageRange = ageRange {
            var ageRangeDict: [String: Any] = [:]
            if let min = ageRange.min { ageRangeDict["min"] = min }
            if let max = ageRange.max { ageRangeDict["max"] = max }
            body["ageRange"] = ageRangeDict
        }
        if let maxMembers = maxMembers { body["maxMembers"] = maxMembers }

        let response: GroupResponse = try await api.patch("/api/groups/\(id)", body: body, responseType: GroupResponse.self)

        guard response.success, let group = response.group else {
            throw APIError.serverError(response.error ?? "Failed to update group")
        }

        upsertKeepingOrganization(group)
        state.persist()

        NSLog("👥 GroupActions: Updated group '\(group.name)'")
        return state.groups[group.id] ?? group
    }

    /// ui2-groups-edit D5/D6: one field's PATCH. Uses the status-keeping request so the edit page
    /// can tell a 404 (the group is gone or out of scope) from a failure worth retrying; a 401
    /// still throws `APIError.unauthorized`. Merges the response, keeping the cached org (D10 of
    /// ui2-groups-browse — the PATCH response carries none).
    @MainActor
    func updateGroup(id: String, patch: GroupPatch) async throws -> UserGroup {
        let data = try await api.requestWithStatus(endpoint: "/api/groups/\(id)", method: "PATCH", body: patch.body)
        let response = try JSONDecoder.apiDecoder.decode(GroupResponse.self, from: data)
        guard response.success, let group = response.group else {
            throw APIError.serverError(response.error ?? "Failed to update group")
        }
        upsertKeepingOrganization(group)
        state.persist()
        return state.groups[group.id] ?? group
    }

    // MARK: - Delete Group

    /// Delete a group (server archives it: `isActive = false`), then forget it locally (D10).
    @MainActor
    func deleteGroup(id: String) async throws {
        let groupName = state.groups[id]?.name ?? id

        let response: APISuccessResponse = try await api.delete("/api/groups/\(id)", responseType: APISuccessResponse.self)

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete group")
        }

        forgetGroup(id: id)
        Log.state.info("GroupActions: deleted group \(groupName, privacy: .private)")
    }

    /// ui2-groups-edit D10: drop a group from every store keyed by or listing it, so nothing
    /// stale stays tappable — the entity stores and indexes, the group page's stores, each
    /// member's group list, and Home's followed groups (matched by the group's enrollment ids,
    /// read before the index is cleared). Local only: also the edit page's 404 path (D5).
    @MainActor
    func forgetGroup(id: String) {
        let enrollmentIds = Set(state.groupEnrollmentIndex.get(id))

        state.groups.remove(id)

        let postIds = state.groupPostIndex.get(id)
        state.posts.removeMany(postIds)
        state.groupPostIndex.removeAll(parentId: id)

        let memberIds = state.groupMemberIndex.get(id)
        state.members.removeMany(memberIds)
        state.groupMemberIndex.removeAll(parentId: id)

        state.enrollments.removeMany(Array(enrollmentIds))
        state.groupEnrollmentIndex.removeAll(parentId: id)

        state.nextStudyByGroupId[id] = nil
        state.historyByGroupId[id] = nil
        state.groupDaysByGroupId[id] = nil
        state.groupChartByGroupId[id] = nil
        state.pendingJoinRequestsByGroupId[id] = nil
        state.groupInvitesByGroupId[id] = nil

        for (memberId, items) in state.memberGroupsById where items.contains(where: { $0.id == id }) {
            state.memberGroupsById[memberId] = items.filter { $0.id != id }
        }

        if var following = state.dashboard.following {
            following.programs = following.programs.compactMap { program in
                let kept = program.groups.filter { !enrollmentIds.contains($0.enrollmentId) }
                guard kept.count != program.groups.count else { return program }
                guard !kept.isEmpty else { return nil }
                var trimmed = program
                trimmed.groups = kept
                return trimmed
            }
            state.dashboard.following = following
        }

        state.persist()
    }

    // MARK: - Cover Image Upload

    /// Upload a cover image for a group
    @MainActor
    func uploadCoverImage(groupId: String, image: UIImage) async throws -> String {
        struct CoverImageResponse: Decodable {
            let success: Bool
            let coverImageUrl: String?
            let error: String?
        }

        let data = try await api.uploadImage(endpoint: "/api/groups/\(groupId)/cover-image", image: image)
        let response = try JSONDecoder.apiDecoder.decode(CoverImageResponse.self, from: data)

        guard response.success, let url = response.coverImageUrl else {
            throw APIError.serverError(response.error ?? "Failed to upload cover image")
        }

        // Update group in state
        if var group = state.groups[groupId] {
            group.coverImageUrl = url
            state.groups.upsert(group)
            state.persist()
        }

        NSLog("📸 GroupActions: Uploaded cover image for group \(groupId)")
        return url
    }

    // MARK: - Group Invite

    /// Fetch the group invite (URL + QR code payload) for a group.
    /// Rehomed from GroupInvitePage (Phase 2.4) — same request, same parsing.
    @MainActor
    func loadGroupInvite(groupId: String) async throws -> GroupInviteData {
        let response = try await api.get(
            "/api/groups/\(groupId)/invite",
            responseType: GroupInviteResponse.self
        )

        guard response.success, let invite = response.invite else {
            throw NSError(
                domain: "GroupInvite",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "Failed to load invite"]
            )
        }

        state.groupInvitesByGroupId[groupId] = invite
        return invite
    }

    // MARK: - Posts

    /// Load a page of a group's posts into `AppState`.
    ///
    /// Writes rather than returns: the posts feed is read through
    /// `state.postsFor(groupId:)` and "has more" is derived from
    /// `state.groupPostsNextCursor`, so no page owns a copy of either.
    ///
    /// **A `cursor == nil` load is authoritative for the first page** — it
    /// prunes this group's posts before adding, mirroring `loadMembers` below.
    /// That is what makes a deleted post actually disappear on refresh (the
    /// unenroll flow relies on exactly this to drop the welcome post). Paged
    /// loads (`cursor != nil`) only ever **append**.
    @MainActor
    func loadPosts(groupId: String, cursor: String? = nil, limit: Int = 20) async throws {
        let context = LoadingStateManager.contextKey(.groups, groupId, .posts)
        state.loadingStates.startLoading(context: context, hasCachedData: state.groupPostIndex.hasChildren(groupId))

        defer {
            state.loadingStates.finishLoading(context: context)
        }

        var endpoint = "/api/groups/\(groupId)/posts?limit=\(limit)"
        if let cursor = cursor {
            endpoint += "&cursor=\(cursor)"
        }

        let response: ListPostsResponse = try await api.get(endpoint, responseType: ListPostsResponse.self)

        guard response.success, let posts = response.posts else {
            throw APIError.serverError(response.error ?? "Failed to load posts")
        }

        // First page is authoritative: drop what the group held so posts
        // deleted server-side actually disappear. Paged loads never prune —
        // that would delete the pages already gathered.
        if cursor == nil {
            let staleIds = state.groupPostIndex.get(groupId)
            state.posts.removeMany(staleIds)
            state.groupPostIndex.removeAll(parentId: groupId)
        }

        // Add to state (append — never `replace`, which would drop earlier pages)
        for post in posts {
            state.posts.upsert(post)
            state.groupPostIndex.add(parentId: groupId, childId: post.id)
        }

        // Key present == more to load. Removing it (rather than storing nil)
        // is what keeps the derived `hasMorePosts` honest.
        if let next = response.nextCursor {
            state.groupPostsNextCursor[groupId] = next
        } else {
            state.groupPostsNextCursor.removeValue(forKey: groupId)
        }

        state.persist()
    }

    /// Create a post in a group
    @MainActor
    func createPost(
        groupId: String,
        type: PostType,
        content: String,
        title: String? = nil,
        pollOptions: [String]? = nil,
        videoUrl: String? = nil,
        eventDate: Date? = nil,
        eventLocation: String? = nil
    ) async throws -> GroupPost {
        var body: [String: Any] = [
            "type": type.rawValue,
            "content": content
        ]

        if let title = title { body["title"] = title }
        if let pollOptions = pollOptions { body["pollOptions"] = pollOptions }
        if let videoUrl = videoUrl { body["videoUrl"] = videoUrl }
        if let eventDate = eventDate {
            body["eventDate"] = ISO8601DateFormatter().string(from: eventDate)
        }
        if let eventLocation = eventLocation { body["eventLocation"] = eventLocation }

        let response: CreatePostResponse = try await api.post(
            "/api/groups/\(groupId)/posts",
            body: body,
            responseType: CreatePostResponse.self
        )

        guard response.success, let post = response.post else {
            throw APIError.serverError(response.error ?? "Failed to create post")
        }

        state.posts.upsert(post)
        state.groupPostIndex.add(parentId: groupId, childId: post.id)
        state.persist()

        return post
    }

    // MARK: - Members

    /// Load members for a group
    @MainActor
    func loadMembers(groupId: String) async throws -> [GroupMember] {
        let context = LoadingStateManager.contextKey(.groups, groupId, .members)
        state.loadingStates.startLoading(context: context, hasCachedData: state.groupMemberIndex.hasChildren(groupId))

        defer {
            state.loadingStates.finishLoading(context: context)
        }

        let response: ListMembersResponse = try await api.get(
            "/api/groups/\(groupId)/members",
            responseType: ListMembersResponse.self
        )

        guard response.success, let members = response.members else {
            throw APIError.serverError(response.error ?? "Failed to load members")
        }

        // Replace all members for this group
        let oldMemberIds = state.groupMemberIndex.get(groupId)
        state.members.removeMany(oldMemberIds)
        state.groupMemberIndex.removeAll(parentId: groupId)

        for member in members {
            state.members.upsert(member)
            state.groupMemberIndex.add(parentId: groupId, childId: member.id)
        }

        state.persist()
        return members
    }

    // MARK: - Member Profile

    /// Load full profile for a member
    @MainActor
    func loadMemberProfile(memberId: String) async throws -> MemberProfile {
        let response: MemberProfileResponse = try await api.get(
            "/api/members/\(memberId)/profile",
            responseType: MemberProfileResponse.self
        )

        guard response.success, let profile = response.data else {
            throw APIError.serverError(response.error ?? "Failed to load member profile")
        }

        // Mirror the member's group associations into AppState so the member
        // profile's group cards render from (and react to) centralized state.
        state.memberGroupCardsById[profile.id] = profile.groups.map {
            MemberGroupCard(
                id: $0.id,
                name: $0.name,
                coverImageUrl: $0.coverImageUrl,
                joinedAt: $0.joinedAt,
                removedAt: nil
            )
        }

        return profile
    }

    // MARK: - Membership Changes

    /// Remove a member from a single group. The server soft-deletes the
    /// membership (and never the member), so it can be restored via `rejoinGroup`
    /// without losing any of the member's data.
    @MainActor
    func removeMember(groupId: String, memberId: String) async throws {
        let response: ApproveRequestResponse = try await api.delete(
            "/api/groups/\(groupId)/members/\(memberId)",
            responseType: ApproveRequestResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to remove member from group")
        }
        // Flip the card to the removed state in centralized state.
        setMemberGroupRemovedAt(memberId: memberId, groupId: groupId, date: Date())
    }

    /// Re-add a member to a group they were removed from. The server reactivates
    /// the existing (soft-deleted) membership, restoring all prior group data.
    @MainActor
    func rejoinGroup(groupId: String, memberId: String, role: String = "member") async throws {
        let response: ApproveRequestResponse = try await api.post(
            "/api/groups/\(groupId)/members",
            body: ["memberId": memberId, "role": role],
            responseType: ApproveRequestResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to rejoin group")
        }
        // Clear the removed state so the card returns to "joined".
        setMemberGroupRemovedAt(memberId: memberId, groupId: groupId, date: nil)
    }

    /// Move a member from one group to another: remove them from `fromGroupId`
    /// and add them to `toGroupId` (composed from the existing endpoints, since
    /// there is no single transfer endpoint). On success, the source card flips
    /// to removed and the target group is added as a joined card.
    @MainActor
    func transferMember(memberId: String, fromGroupId: String, toGroupId: String) async throws {
        // Add to the target FIRST: while the member is still active in the source
        // group, the server recognizes them as an org member (and heals a missing
        // org link). Then remove them from the source group.
        let addResponse: ApproveRequestResponse = try await api.post(
            "/api/groups/\(toGroupId)/members",
            body: ["memberId": memberId, "role": "member"],
            responseType: ApproveRequestResponse.self
        )
        guard addResponse.success else {
            throw APIError.serverError(addResponse.error ?? "Failed to transfer member")
        }

        let removeResponse: ApproveRequestResponse = try await api.delete(
            "/api/groups/\(fromGroupId)/members/\(memberId)",
            responseType: ApproveRequestResponse.self
        )
        guard removeResponse.success else {
            throw APIError.serverError(removeResponse.error ?? "Failed to transfer member")
        }

        var cards = state.memberGroupCardsById[memberId] ?? []
        // Source group → removed state.
        if let idx = cards.firstIndex(where: { $0.id == fromGroupId }) {
            cards[idx].removedAt = Date()
        }
        // Target group → joined (clear a prior removed state, or append a new card).
        if let idx = cards.firstIndex(where: { $0.id == toGroupId }) {
            cards[idx].removedAt = nil
        } else {
            let target = state.groups[toGroupId]
            cards.append(MemberGroupCard(
                id: toGroupId,
                name: target?.name ?? "Group",
                coverImageUrl: target?.coverImageUrl,
                joinedAt: Date(),
                removedAt: nil
            ))
        }
        state.memberGroupCardsById[memberId] = cards
    }

    /// Set (or clear) the removed timestamp on a member's group card in state.
    @MainActor
    private func setMemberGroupRemovedAt(memberId: String, groupId: String, date: Date?) {
        guard var cards = state.memberGroupCardsById[memberId],
              let idx = cards.firstIndex(where: { $0.id == groupId }) else { return }
        cards[idx].removedAt = date
        state.memberGroupCardsById[memberId] = cards
    }

    // MARK: - Join Requests

    /// Fetch pending join requests for a group and write them into AppState.
    /// Drives the red-dot indicator on group cards and the `person.2` icon
    /// in the group-home header. Failures are non-fatal — the badge UI just
    /// won't update if this throws.
    @MainActor
    @discardableResult
    func loadJoinRequests(groupId: String) async throws -> [JoinRequest] {
        let response: JoinRequestsResponse = try await api.get(
            "/api/groups/\(groupId)/join-requests",
            responseType: JoinRequestsResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to load join requests")
        }

        let requests = response.requests ?? []
        state.pendingJoinRequestsByGroupId[groupId] = requests
        return requests
    }

    /// Approve a pending join request and synchronously remove it from
    /// `AppState.pendingJoinRequestsByGroupId` so the red-dot indicator
    /// updates immediately — without waiting for a refetch round-trip.
    /// Callers can still call `loadJoinRequests(groupId:)` afterwards to
    /// reconcile with the server, but the badge transition is no longer
    /// gated on that network call.
    @MainActor
    func approveJoinRequest(groupId: String, requestId: String) async throws {
        let response: ApproveRequestResponse = try await api.post(
            "/api/groups/\(groupId)/join-requests/\(requestId)/approve",
            body: [:],
            responseType: ApproveRequestResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to approve request")
        }
        if var requests = state.pendingJoinRequestsByGroupId[groupId] {
            requests.removeAll { $0.id == requestId }
            state.pendingJoinRequestsByGroupId[groupId] = requests
        }
    }

    /// Reject a pending join request. Like approval, this removes the request
    /// from `AppState.pendingJoinRequestsByGroupId` so the red-dot indicators
    /// update instantly. The server preserves the rejection (and the member),
    /// so the leader can later reverse it from the membership history.
    @MainActor
    func rejectJoinRequest(groupId: String, requestId: String) async throws {
        let response: ApproveRequestResponse = try await api.post(
            "/api/groups/\(groupId)/join-requests/\(requestId)/reject",
            body: [:],
            responseType: ApproveRequestResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to reject request")
        }
        if var requests = state.pendingJoinRequestsByGroupId[groupId] {
            requests.removeAll { $0.id == requestId }
            state.pendingJoinRequestsByGroupId[groupId] = requests
        }
    }

    // MARK: - ui2-groups-browse: the group page's loads (T11–T13, T18)
    // Non-throwing, as MemberActions: a 401 signs out, a 404 is the caller's scope (D23) and
    // writes nothing, anything else is recorded console-only (these are background loads, D4)
    // and the store keeps what it held. A cancelled load or a retired session writes nothing.

    /// D12: the rail's 30 local days, today trailing.
    static let railDays = 30
    /// D13/D21: the chart's days reach three past today.
    static let chartAheadDays = 3
    /// D4: the Timeline shows the latest 5.
    static let historyLimit = 5

    /// T11/D17: the next lesson; a 204 (no lesson ahead) removes the group's entry.
    @MainActor
    func loadNextStudy(groupId: String) async {
        guard let data = await send("loadNextStudy", "GET", "/api/groups/\(groupId)/next-study") else { return }
        guard !data.isEmpty else {
            state.nextStudyByGroupId.removeValue(forKey: groupId)
            return
        }
        guard let response = decode("loadNextStudy", data, NextStudyResponse.self) else { return }
        if let study = response.study {
            state.nextStudyByGroupId[groupId] = study
        } else {
            state.nextStudyByGroupId.removeValue(forKey: groupId)
        }
    }

    /// T12/D15: the merged group history, newest first.
    @MainActor
    func loadHistory(groupId: String, limit: Int = GroupActions.historyLimit) async {
        let path = MemberActions.path("/api/groups/\(groupId)/history", [("limit", "\(limit)")])
        guard let data = await send("loadHistory", "GET", path),
              let response = decode("loadHistory", data, GroupHistoryResponse.self) else { return }
        state.historyByGroupId[groupId] = response.events
    }

    /// T13/D12/D14: `/api/home/days` filtered to the group's members, today−29 … today, local tz.
    @MainActor
    func loadGroupDays(groupId: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: 0, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let path = MemberActions.path("/api/home/days", [
            ("from", from), ("to", to), ("tz", timeZone.identifier), ("groupId", groupId)
        ])
        guard let data = await send("loadGroupDays", "GET", path),
              let response = decode("loadGroupDays", data, HomeDaysResponse.self) else { return }
        state.groupDaysByGroupId[groupId] = response.days
    }

    /// T13/D21: `scheduled_lessons` and `lesson_completions` cannot share a query (the engine
    /// 400s on mixed buckets), so two run at once over today−29 … today+3. Each series that lands
    /// replaces its map; a failed one keeps the old map and is recorded.
    @MainActor
    func loadGroupChart(groupId: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: Self.chartAheadDays, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let generation = state.initialLoad.generation
        async let scheduled = dailyCounts("loadGroupChart.scheduled", metric: "scheduled_lessons",
                                          groupId: groupId, from: from, to: to)
        async let completed = dailyCounts("loadGroupChart.completed", metric: "lesson_completions",
                                          groupId: groupId, from: from, to: to)
        let (scheduledDays, completedDays) = await (scheduled, completed)
        guard state.initialLoad.isCurrent(generation), scheduledDays != nil || completedDays != nil else { return }
        var chart = state.groupChartByGroupId[groupId] ?? GroupChart()
        if let scheduledDays { chart.scheduled = scheduledDays }
        if let completedDays { chart.completed = completedDays }
        state.groupChartByGroupId[groupId] = chart
    }

    /// T18/D3: every org the caller holds a role in — the Groups Orgs chip, for every role.
    @MainActor
    func loadMyOrganizations() async {
        guard let data = await send("loadMyOrganizations", "GET", "/api/organizations/my/organizations"),
              let response = decode("loadMyOrganizations", data, MyOrganizationsResponse.self) else { return }
        state.myOrganizations = response.data
    }

    /// One metric's rows keyed by their `day` (rows without a day or a number are skipped).
    static func byDay(_ rows: [[String: AnalyticsValue]], metric: String) -> [String: Int] {
        Dictionary(rows.compactMap { row in row["day"]?.string.flatMap { key in row[metric]?.int.map { (key, $0) } } },
                   uniquingKeysWith: { $1 })
    }

    /// A cancelled load — directly, or wrapped by APIClient as a network error.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return true }
        if case APIError.networkError(let inner) = error { return isCancellation(inner) }
        return false
    }

    /// D21: one single-metric analytics query, per day, or nil when it failed.
    @MainActor
    private func dailyCounts(_ context: String, metric: String, groupId: String, from: String, to: String) async -> [String: Int]? {
        let body: [String: Any] = [
            "metrics": [metric],
            "dimensions": ["day"],
            "timezone": timeZone.identifier,
            "filters": ["groupId": groupId, "from": from, "to": to]
        ]
        guard let data = await send(context, "POST", "/api/analytics/query", body: body),
              let response = decode(context, data, AnalyticsQueryResponse.self) else { return nil }
        return Self.byDay(response.rows, metric: metric)
    }

    /// One request through `requestWithStatus`, so a 404 keeps its status. nil = failed,
    /// cancelled, or a sign-out retired the session meanwhile; empty Data = a 204.
    @MainActor
    private func send(_ context: String, _ method: String, _ path: String, body: [String: Any]? = nil) async -> Data? {
        let generation = state.initialLoad.generation
        do {
            let data = try await api.requestWithStatus(endpoint: path, method: method, body: body)
            guard !Task.isCancelled, state.initialLoad.isCurrent(generation) else { return nil }
            return data
        } catch {
            await handle(error, context)
            return nil
        }
    }

    @MainActor
    private func decode<T: Decodable>(_ context: String, _ data: Data, _ type: T.Type) -> T? {
        do {
            return try JSONDecoder.apiDecoder.decode(type, from: data)
        } catch {
            state.recordError(APIError.decodingError(error), context: "GroupActions.\(context)", surface: false)
            return nil
        }
    }

    @MainActor
    private func handle(_ error: Error, _ context: String) async {
        if Self.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()                                         // ui2-shell D27
            return
        }
        if let http = error as? APIHTTPError, http.status == 404 { return } // D23: scope, not failure
        state.recordError(error, context: "GroupActions.\(context)", surface: false)
    }
}
