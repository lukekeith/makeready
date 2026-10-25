//
//  GroupModels.swift
//  MakeReady
//
//  Data models for groups, posts, and related entities.
//  Matches server-side Prisma schema for Group, GroupPost.
//
//  API Reference: See .claude/API_REFERENCE.md for endpoint specifications.
//

import Foundation

// MARK: - Group Models

/// A group that users can join and interact in
/// Named `UserGroup` to avoid conflict with SwiftUI's Group view
struct UserGroup: Codable, Identifiable {
    let id: String
    let code: String  // 6-character alphanumeric code for joining
    var name: String
    var description: String?
    var coverImageUrl: String?
    var isPrivate: Bool
    var allowInvites: Bool
    var memberDirectory: Bool
    var welcomeMessage: String?
    var ageRange: AgeRange?
    var maxMembers: Int?
    var memberCount: Int
    let creatorId: String
    let createdAt: Date
    var updatedAt: Date

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        // Tolerate a null/absent join code: the server can return one (e.g. a
        // group whose code was cleared), and a non-optional decode here would
        // poison the WHOLE /api/groups list — one bad group blanked every
        // group, which stalled the edit-enrollment modal (monday#12270302158).
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? ""
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        isPrivate = try container.decode(Bool.self, forKey: .isPrivate)
        allowInvites = try container.decode(Bool.self, forKey: .allowInvites)
        memberDirectory = try container.decodeIfPresent(Bool.self, forKey: .memberDirectory) ?? true
        welcomeMessage = try container.decodeIfPresent(String.self, forKey: .welcomeMessage)
        ageRange = try container.decodeIfPresent(AgeRange.self, forKey: .ageRange)
        maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    init(
        id: String, code: String, name: String, description: String? = nil,
        coverImageUrl: String? = nil, isPrivate: Bool, allowInvites: Bool,
        memberDirectory: Bool = true, welcomeMessage: String? = nil,
        ageRange: AgeRange? = nil, maxMembers: Int? = nil, memberCount: Int,
        creatorId: String, createdAt: Date, updatedAt: Date
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.isPrivate = isPrivate
        self.allowInvites = allowInvites
        self.memberDirectory = memberDirectory
        self.welcomeMessage = welcomeMessage
        self.ageRange = ageRange
        self.maxMembers = maxMembers
        self.memberCount = memberCount
        self.creatorId = creatorId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Age range restriction for a group
struct AgeRange: Codable, Equatable {
    var min: Int?
    var max: Int?

    /// Human-readable age range string
    var displayString: String {
        switch (min, max) {
        case (let min?, let max?):
            return "\(min)-\(max) years"
        case (let min?, nil):
            return "\(min)+ years"
        case (nil, let max?):
            return "Under \(max) years"
        case (nil, nil):
            return "All ages"
        }
    }
}

// MARK: - Group Post Models

/// A post within a group (poll, video, event, or announcement)
struct GroupPost: Codable, Identifiable {
    let id: String
    let groupId: String
    let authorId: String?               // NULL for system-generated posts (WELCOME)
    var authorName: String
    var authorAvatarUrl: String?
    var type: PostType
    var content: String
    var title: String?
    var imageUrl: String?               // Cover image (e.g., study program image for WELCOME)
    var enrollmentId: String?           // Reference to enrollment for WELCOME posts
    let createdAt: Date
    var updatedAt: Date

    // Engagement stats
    var viewCount: Int?                 // Number of views
    var shareCount: Int?                // Number of shares

    // Type-specific data
    var pollOptions: [PollOption]?      // For poll type
    var videoUrl: String?               // For video type
    var eventDate: Date?                // For event type
    var eventLocation: String?          // For event type
    var eventTitle: String?             // Event card title
    var attendeeCount: Int?             // Number of people attending event
}

/// Type of group post
enum PostType: String, Codable, CaseIterable {
    case welcome = "WELCOME"
    case poll = "POLL"
    case video = "VIDEO"
    case event = "EVENT"
    case announcement = "ANNOUNCEMENT"

    var displayName: String {
        switch self {
        case .welcome: return "Welcome"
        case .poll: return "Poll"
        case .video: return "Video"
        case .event: return "Event"
        case .announcement: return "Announcement"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "sparkles"
        case .poll: return "chart.bar.fill"
        case .video: return "play.fill"
        case .event: return "calendar"
        case .announcement: return "megaphone.fill"
        }
    }
}

/// A poll option with vote count
struct PollOption: Codable, Identifiable {
    let id: String
    var text: String
    var voteCount: Int
    var hasVoted: Bool  // Whether current user voted for this option
}

// MARK: - Group Member

/// A member of a group
struct GroupMember: Codable, Identifiable {
    let id: String
    let userId: String
    let groupId: String
    var role: GroupRole
    var name: String
    var avatarUrl: String?
    let joinedAt: Date
}

/// Role within a group
enum GroupRole: String, Codable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case member = "MEMBER"

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Member Profile (from /api/members/:memberId/profile)

/// Full member profile returned by the profile endpoint
struct MemberProfile: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let phoneNumber: String
    let email: String?
    let gender: String?
    let birthday: Date?
    let profilePicture: String?
    let googleEmail: String?
    let googlePicture: String?
    let googleLinkedAt: Date?
    let createdAt: Date
    let groups: [MemberProfileGroup]

    /// Full display name
    var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }

    /// Best available avatar URL (profile picture, then Google picture)
    var avatarUrl: String? {
        profilePicture ?? googlePicture
    }

    /// Best available email (direct email, then Google email)
    var displayEmail: String? {
        email ?? googleEmail
    }

    /// Calculated age from birthday
    var age: Int? {
        guard let birthday = birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
    }

    /// Earliest group join date
    var earliestJoinDate: Date? {
        groups.map(\.joinedAt).min()
    }
}

/// A group the member belongs to
struct MemberProfileGroup: Codable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let role: String
    let joinedAt: Date
}

/// A row in the member-profile groups list. Lives in AppState
/// (`memberGroupCardsById`) so membership changes (remove / rejoin / transfer)
/// update the rendered cards reactively. `removedAt != nil` renders the
/// destructive "removed" state with the removal date.
struct MemberGroupCard: Identifiable, Equatable {
    let id: String          // group id
    let name: String
    let coverImageUrl: String?
    let joinedAt: Date
    var removedAt: Date?
}

/// Response from GET /api/members/:memberId/profile
struct MemberProfileResponse: Codable {
    let success: Bool
    let data: MemberProfile?
    let error: String?
}

// MARK: - Create/Update DTOs

/// Data for creating a new group
struct CreateGroupRequest: Codable {
    var name: String
    var description: String?
    var coverImageUrl: String?
    var isPrivate: Bool
    var allowInvites: Bool
    var memberDirectory: Bool
    var welcomeMessage: String?
    var ageRange: AgeRange?
    var maxMembers: Int?
}

/// Data for updating a group
struct UpdateGroupRequest: Codable {
    var name: String?
    var description: String?
    var coverImageUrl: String?
    var isPrivate: Bool?
    var allowInvites: Bool?
    var memberDirectory: Bool?
    var welcomeMessage: String?
    var ageRange: AgeRange?
    var maxMembers: Int?
}

/// Data for creating a post
struct CreatePostRequest: Codable {
    var type: PostType
    var content: String
    var title: String?
    var pollOptions: [String]?      // For poll type
    var videoUrl: String?           // For video type
    var eventDate: Date?            // For event type
    var eventLocation: String?      // For event type
}

// MARK: - API Response Models

/// Response from POST /api/groups and GET /api/groups/:id
struct GroupResponse: Codable {
    let success: Bool
    let group: UserGroup?
    let error: String?
}

/// Response from GET /api/groups
struct ListGroupsResponse: Codable {
    let success: Bool
    let groups: [UserGroup]?
    let error: String?
}

/// Response from GET /api/groups/:id/posts
struct ListPostsResponse: Codable {
    let success: Bool
    let posts: [GroupPost]?
    let nextCursor: String?  // For pagination
    let error: String?
}

/// Response from POST /api/groups/:id/posts
struct CreatePostResponse: Codable {
    let success: Bool
    let post: GroupPost?
    let error: String?
}

/// Response from GET /api/groups/:id/members
struct ListMembersResponse: Codable {
    let success: Bool
    let members: [GroupMember]?
    let error: String?
}
