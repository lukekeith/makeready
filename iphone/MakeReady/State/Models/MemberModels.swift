import Foundation

// MARK: - ui2-members-browse §Contract — the iPhone's side of the member payloads
//
// T9 / F7: every date here (`joinedAt`, `birthday`) is the server's ISO 8601 STRING, parsed in
// the mappers (MembersHomeMapper.parseDate) with the fractional-then-plain fallback — Prisma
// writes `.SSSZ`. Every key decodes with a default (`decodeIfPresent`) so a server a step behind
// or ahead never fails a whole page. `MemberProfile` (GroupModels.swift) holds Dates and is not
// reused.

/// D15: the caller's D7 scope, from the server's `memberAccessScope`. `all` = Owner, Admin,
/// Super Admin; otherwise `groupIds` are the groups the caller created.
struct ViewerScope: Codable, Equatable {
    var all: Bool = false
    var groupIds: [String] = []
}

extension ViewerScope {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        all = try c.decodeIfPresent(Bool.self, forKey: .all) ?? false
        groupIds = try c.decodeIfPresent([String].self, forKey: .groupIds) ?? []
    }
}

/// One row of `GET /api/organizations/:organizationId/members` (P12, D6).
struct OrgMemberListItem: Codable, Equatable, Identifiable {
    var id: String = ""
    var firstName: String?
    var lastName: String?
    var profilePicture: String?
    var googlePicture: String?
    var joinedAt: String = ""          // this org's MemberOrganization.joinedAt, ISO (F7)
    var groupCount: Int = 0
}

extension OrgMemberListItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        profilePicture = try c.decodeIfPresent(String.self, forKey: .profilePicture)
        googlePicture = try c.decodeIfPresent(String.self, forKey: .googlePicture)
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        groupCount = try c.decodeIfPresent(Int.self, forKey: .groupCount) ?? 0
    }
}

/// `GET /api/organizations/:organizationId/members` — server-ordered `joinedAt` desc (D6).
struct OrgMembersResponse: Codable, Equatable {
    var success: Bool = false
    var data: [OrgMemberListItem] = []
    var count: Int = 0
    var viewerScope: ViewerScope?      // nil = a server without D15 — the mapper treats it as `all`
}

extension OrgMembersResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([OrgMemberListItem].self, forKey: .data) ?? []
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        viewerScope = try c.decodeIfPresent(ViewerScope.self, forKey: .viewerScope)
    }
}

/// `AppState.orgMembersByOrgId`'s value: the last directory load for an org and the query it
/// answered (in memory only, D21).
struct OrgMemberDirectory: Equatable {
    var search: String = ""
    var groupId: String?
    var leaderId: String?
    var members: [OrgMemberListItem] = []
    var viewerScope: ViewerScope?
}

/// `organizations[].organization` on the member payload (D8: already caller-scoped by the server).
struct MemberOrganizationRef: Codable, Equatable {
    var id: String = ""
    var name: String = ""
}

extension MemberOrganizationRef {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

/// One `MemberOrganization` row on the member payload.
struct MemberDetailOrganization: Codable, Equatable {
    var organizationId: String = ""
    var joinedAt: String = ""          // ISO (F7)
    var organization: MemberOrganizationRef?
}

extension MemberDetailOrganization {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        organizationId = try c.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        organization = try c.decodeIfPresent(MemberOrganizationRef.self, forKey: .organization)
    }
}

/// `GET /api/members/:memberId` — the existing member columns plus SC1–SC3 and SC8.
struct MemberDetail: Codable, Equatable, Identifiable {
    var id: String = ""
    var phoneNumber: String = ""
    var phoneVerified: Bool = false
    var firstName: String?
    var lastName: String?
    var email: String?
    var googleEmail: String?
    var gender: String?                // stored lowercase ("male" / "female")
    var birthday: String?              // ISO, a calendar date at UTC midnight (F7)
    var profilePicture: String?
    var googlePicture: String?
    var userId: String?
    var address: String?               // SC1 — multi-line (P7)
    var emergencyContactName: String?  // SC2 (P6)
    var emergencyContactPhone: String? // SC3 (P6)
    var isGroupLeader: Bool = false    // SC8 (D8)
    var organizations: [MemberDetailOrganization] = []
}

extension MemberDetail {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        phoneVerified = try c.decodeIfPresent(Bool.self, forKey: .phoneVerified) ?? false
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        googleEmail = try c.decodeIfPresent(String.self, forKey: .googleEmail)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday)
        profilePicture = try c.decodeIfPresent(String.self, forKey: .profilePicture)
        googlePicture = try c.decodeIfPresent(String.self, forKey: .googlePicture)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        emergencyContactName = try c.decodeIfPresent(String.self, forKey: .emergencyContactName)
        emergencyContactPhone = try c.decodeIfPresent(String.self, forKey: .emergencyContactPhone)
        isGroupLeader = try c.decodeIfPresent(Bool.self, forKey: .isGroupLeader) ?? false
        organizations = try c.decodeIfPresent([MemberDetailOrganization].self, forKey: .organizations) ?? []
    }
}

struct MemberDetailResponse: Codable, Equatable {
    var success: Bool = false
    var data: MemberDetail?
    var error: String?
}

extension MemberDetailResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent(MemberDetail.self, forKey: .data)
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// `creator` on a member's group — the leader shown as C-043 `Single` ("L. Keith").
struct MemberGroupCreator: Codable, Equatable {
    var id: String = ""
    var name: String?
}

extension MemberGroupCreator {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
    }
}

/// One group of `GET /api/members/:memberId/groups` (the group row + `memberCount`, `joinedAt`).
struct MemberGroupItem: Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var coverImageUrl: String?
    var organizationId: String = ""
    var memberCount: Int = 0
    var joinedAt: String = ""          // this membership's GroupMember.joinedAt, ISO (F7)
    var creator: MemberGroupCreator?
}

extension MemberGroupItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        organizationId = try c.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        creator = try c.decodeIfPresent(MemberGroupCreator.self, forKey: .creator)
    }
}

struct MemberGroupsResponse: Codable, Equatable {
    var success: Bool = false
    var data: [MemberGroupItem] = []
    var count: Int = 0
}

extension MemberGroupsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([MemberGroupItem].self, forKey: .data) ?? []
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

/// One enrollment of `GET /api/members/:memberId/engagement` (D11 + D14 `totalCount`; `hours` is
/// whole hours, D17 — the iPhone formats it).
struct MemberEngagementProgram: Codable, Equatable {
    var enrollmentId: String = ""
    var programId: String = ""
    var title: String = ""
    var coverImageUrl: String?
    var completedCount: Int = 0
    var totalCount: Int = 0
    var hours: Int = 0
    var percent: Int = 0
}

extension MemberEngagementProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enrollmentId = try c.decodeIfPresent(String.self, forKey: .enrollmentId) ?? ""
        programId = try c.decodeIfPresent(String.self, forKey: .programId) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        completedCount = try c.decodeIfPresent(Int.self, forKey: .completedCount) ?? 0
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        hours = try c.decodeIfPresent(Int.self, forKey: .hours) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
    }
}

/// `GET /api/members/:memberId/engagement` — `{programs:[…]}`, top level like `/api/home/*`.
struct MemberEngagement: Codable, Equatable {
    var programs: [MemberEngagementProgram] = []
}

extension MemberEngagement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        programs = try c.decodeIfPresent([MemberEngagementProgram].self, forKey: .programs) ?? []
    }
}

/// D18: `GET /api/organizations/my/organizations` — orgs owned or role-held, owned first.
struct MyOrganizationsResponse: Codable, Equatable {
    var success: Bool = false
    var data: [OrganizationData] = []
}

extension MyOrganizationsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([OrganizationData].self, forKey: .data) ?? []
    }
}

// MARK: - ui2-members-edit: one field's edit

/// ui2-members-edit D15: the ONE key a member edit page PATCHes to `/api/members/:id`. nil clears
/// (sent as JSON null, D8). Values are already in their wire form: phone normalized (D4),
/// birthday `YYYY-MM-DD` (D9), gender `male` / `female` (D10), strings trimmed.
enum MemberPatch: Equatable {
    case email(String?)
    case phoneNumber(String?)
    case birthday(String?)
    case gender(String?)
    case address(String?)
    case emergencyContactName(String?)
    case emergencyContactPhone(String?)

    /// The wire key (SPEC §Contract — camelCase on both sides, no transform).
    var key: String {
        switch self {
        case .email: return "email"
        case .phoneNumber: return "phoneNumber"
        case .birthday: return "birthday"
        case .gender: return "gender"
        case .address: return "address"
        case .emergencyContactName: return "emergencyContactName"
        case .emergencyContactPhone: return "emergencyContactPhone"
        }
    }

    var value: String? {
        switch self {
        case .email(let v), .phoneNumber(let v), .birthday(let v), .gender(let v), .address(let v),
             .emergencyContactName(let v), .emergencyContactPhone(let v):
            return v
        }
    }

    /// `JSONSerialization` writes `NSNull` as `null`.
    var jsonValue: Any { value ?? NSNull() }

    var body: [String: Any] { [key: jsonValue] }
}

/// ui2-members-edit D13: how a save failed, as the edit page shows it — the server's text for a
/// 400 / 409, else the generic line.
enum MemberSaveError: Error, Equatable {
    case validation(String)
    case generic
}
