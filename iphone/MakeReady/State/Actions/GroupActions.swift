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
                    NSLog("❌ GroupActions: Background refresh failed: \(error.localizedDescription)")
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
                        try await GroupActions().loadJoinRequests(groupId: id)
                    } catch {
                        NSLog("⚠️ GroupActions: join-requests prefetch failed for \(id): \(error.localizedDescription)")
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

        state.groups.upsert(group)
        state.persist()

        return group
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

        state.groups.upsert(group)
        state.persist()

        NSLog("👥 GroupActions: Updated group '\(group.name)'")
        return group
    }

    // MARK: - Delete Group

    /// Delete a group
    @MainActor
    func deleteGroup(id: String) async throws {
        let groupName = state.groups[id]?.name ?? id

        let response: APISuccessResponse = try await api.delete("/api/groups/\(id)", responseType: APISuccessResponse.self)

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete group")
        }

        // Remove from state
        state.groups.remove(id)

        // Clean up related data
        let postIds = state.groupPostIndex.get(id)
        state.posts.removeMany(postIds)
        state.groupPostIndex.removeAll(parentId: id)

        let memberIds = state.groupMemberIndex.get(id)
        state.members.removeMany(memberIds)
        state.groupMemberIndex.removeAll(parentId: id)

        // Remove enrollments for this group
        let enrollmentIds = state.groupEnrollmentIndex.get(id)
        state.enrollments.removeMany(enrollmentIds)
        state.groupEnrollmentIndex.removeAll(parentId: id)

        state.persist()
        NSLog("👥 GroupActions: Deleted group '\(groupName)'")
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

        return invite
    }

    // MARK: - Posts

    /// Load posts for a group
    @MainActor
    func loadPosts(groupId: String, cursor: String? = nil, limit: Int = 20) async throws -> (posts: [GroupPost], nextCursor: String?) {
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

        // Add to state (don't replace if paginating)
        for post in posts {
            state.posts.upsert(post)
            state.groupPostIndex.add(parentId: groupId, childId: post.id)
        }

        state.persist()
        return (posts: posts, nextCursor: response.nextCursor)
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

        return profile
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
}
