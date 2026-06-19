//
//  GroupMembershipModels.swift
//  MakeReady
//
//  Join request and group leader models.
//  Phase 5.7 — code motion from State/Models.swift. (Renamed from
//  GroupModels.swift: the basename collided with the page-local
//  Pages/Manage/Group/Models/GroupModels.swift in the same target.)
//

import Foundation

// MARK: - Join Request Models

/// A pending member join-request for a group.
struct JoinRequest: Codable, Identifiable {
    let id: String
    let status: String
    let message: String?
    let createdAt: Date
    let member: JoinRequestMember
}

struct JoinRequestMember: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let avatarUrl: String?
}

struct JoinRequestsResponse: Codable {
    let success: Bool
    let requests: [JoinRequest]?
    let error: String?
}

struct ApproveRequestResponse: Codable {
    let success: Bool
    let error: String?
}

/// Someone who was associated with the org via a group but is no longer a
/// current member (removed, or had a join request rejected). Backed by the
/// server's MembershipEvent audit trail. `lastAction` is the raw
/// MembershipEventAction; `lastActionLabel` renders it for display.
struct NonMember: Codable, Identifiable {
    let id: String
    let firstName: String?
    let lastName: String?
    let phoneNumber: String
    let avatarUrl: String?
    let lastAction: String
    let lastActionAt: Date
    let groupId: String?
    let groupName: String?
    let note: String?

    var displayName: String {
        let name = [firstName, lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown" : name
    }

    /// Human-readable description of why this person is a non-member.
    var lastActionLabel: String {
        switch lastAction {
        case "REMOVED_GROUP": return "Removed from membership"
        case "REMOVED_ORG": return "Removed from organization"
        case "REJECTED": return "Request rejected"
        case "INVITED": return "Invited"
        case "REQUESTED": return "Requested to join"
        default: return lastAction.capitalized
        }
    }
}

struct NonMembersResponse: Codable {
    let success: Bool
    let members: [NonMember]?
    let error: String?
}

// MARK: - Group Leader Models

/// A user with the "Group Leader" role in the caller's organization. Used by
/// the Library "Group leaders" filter dropdown on both Programs and Media tabs.
struct GroupLeader: Codable, Identifiable, Hashable {
    let id: String
    let firstName: String?
    let lastName: String?
    var avatarUrl: String?
    let programCount: Int
    let mediaCount: Int

    var displayName: String {
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? "Group Leader" : joined
    }
}

struct GroupLeadersResponse: Codable {
    let success: Bool
    let leaders: [GroupLeader]?
    let error: String?
}
