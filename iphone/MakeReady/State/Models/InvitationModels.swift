import Foundation

// Frozen invitations C1–C4. Dates remain ISO strings; nullable wire metadata stays absent.
enum InvitationKind: String, Codable { case invite, request }
enum InvitationDisplayStatus: String, Codable, CaseIterable {
    case sent, requested, accepted, rejected, expired
}
enum InvitationStatus: String, Codable, CaseIterable {
    case sent, requested, accepted, rejected, expired, withdrawn
}
enum InvitationEventType: String, Codable, CaseIterable {
    case sent, resent, linkClicked = "link_clicked", accepted, withdrawn, expired, requested, approved, rejected
}

struct InvitationFeedItem: Codable, Identifiable, Equatable {
    let id: String
    let kind: InvitationKind
    let status: InvitationDisplayStatus
    let recipientPhone: String?
    let recipientName: String?
    let memberId: String?
    let groupId: String?
    let groupName: String?
    let organizationId: String
    let inviterId: String?
    let inviterName: String?
    let date: String
    let createdAt: String
}

struct InvitationFilters: Codable, Equatable {
    struct Option: Codable, Identifiable, Equatable {
        let id: String
        let name: String
    }
    struct Group: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let organizationId: String
    }
    let orgs: [Option]
    let groups: [Group]
    let leaders: [Option]
}

struct InvitationFeedResponse: Codable, Equatable {
    let items: [InvitationFeedItem]
    let total: Int
    let filters: InvitationFilters
}

struct InvitationDetail: Codable, Identifiable, Equatable {
    struct Member: Codable, Identifiable, Equatable {
        let id: String
        let name: String
        let picture: String?
        let age: Int?
        let role: String?
        let birthday: String?
        let joinedAt: String?
    }
    struct Invitation: Codable, Identifiable, Equatable {
        let id: String
        let kind: InvitationKind
        let groupId: String?
        let groupName: String?
        let groupPicture: String?
        let status: InvitationStatus
        let date: String
    }
    struct Event: Codable, Identifiable, Equatable {
        let id: String
        let type: InvitationEventType
        let at: String
        let groupId: String?
        let groupName: String?
        let invitationId: String
    }
    let id: String
    let kind: InvitationKind
    let status: InvitationStatus
    let recipientPhone: String?
    let recipientName: String?
    let inviterName: String?
    let message: String?
    let createdAt: String
    let member: Member?
    let invitations: [Invitation]
    let events: [Event]
    let canResend: Bool
    let canWithdraw: Bool

    var selectedInvitation: Invitation? { invitations.first { $0.id == id } }
}

struct InvitationQuery: Equatable, Hashable {
    var orgId: String?
    var groupId: String?
    var leaderId: String?
    var status: InvitationDisplayStatus?

    var path: String {
        let pairs: [(String, String?)] = [
            ("orgId", orgId), ("groupId", groupId), ("leaderId", leaderId), ("status", status?.rawValue)
        ]
        let query = pairs.compactMap { key, value in
            value.map { key + "=" + DashboardActions.queryValue($0) }
        }.joined(separator: "&")
        return "/api/invitations/feed" + (query.isEmpty ? "" : "?" + query)
    }
}

struct InvitationFeedWindow: Equatable {
    let query: InvitationQuery
    var orderedIDs: [String]
    let total: Int
}

enum InvitationActionError: Error, Equatable {
    case cancelled, unauthorized, forbidden, notFound, conflict, deliveryFailed, busy, generic
}
