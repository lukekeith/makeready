//
//  ExtractedModels.swift
//  MakeReady
//
//  Model types cut verbatim from Pages/ and Components/ files so kept code
//  (State, Services, Utilities) no longer depends on UI files (ui2-shell D5).
//

import SwiftUI

// MARK: - From GroupInvitePage

// MARK: - Response Model

struct GroupInviteResponse: Codable {
    let success: Bool
    let invite: GroupInviteData?
    let error: String?
}

struct GroupInviteData: Codable {
    let groupId: String
    let groupName: String
    let code: String
    let inviteUrl: String
    let qrCode: String  // Base64 data URL
}

// MARK: - From StudyInvitePage

// MARK: - Response Model

struct LessonInviteResponse: Codable {
    let success: Bool
    let invite: LessonInviteData?
    let error: String?
}

struct LessonInviteData: Codable {
    let lessonScheduleId: String
    let code: String
    let inviteUrl: String
    let qrCode: String  // Base64 data URL
    let dayNumber: Int?  // At root level in server response
    let scheduledDate: String?
    let passageReference: String?
    let studyProgram: LessonInviteProgram?  // Server sends "studyProgram"
    let group: LessonInviteGroup?
}

struct LessonInviteProgram: Codable {
    let id: String
    let name: String
    let days: Int
    let coverImageUrl: String?
}

struct LessonInviteGroup: Codable {
    let id: String
    let name: String
    let code: String
    let coverImageUrl: String?
}

// MARK: - From BibleVersionMenu

// MARK: - Bible Version

struct BibleVersion: Identifiable, Equatable, Codable {
    let id: String           // API.Bible ID
    let code: String         // Abbreviation (e.g., "KJV", "NASB")
    let name: String         // Full display name
    let language: String?
    let description: String?
    let copyright: String?
}

struct BibleTranslationsResponse: Codable {
    let translations: [BibleVersion]?
    let error: String?
}

// MARK: - Known Translations (cached from API)

let knownBibleVersions: [BibleVersion] = [
    BibleVersion(id: "de4e12af7f28f599-02", code: "KJV",  name: "King James (Authorised) Version",           language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "01b29f4b342acc35-01", code: "ASV",  name: "American Standard Version",                  language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "9879dbb7cfe39e4d-04", code: "FBV",  name: "Free Bible Version",                        language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "65eec8e0b60e656b-01", code: "GNV",  name: "Geneva Bible",                               language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "55212e3cf4d04c49-01", code: "GNTD", name: "Good News Translation (US Version)",         language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "b32b9d1b64b4ef29-01", code: "LSV",  name: "Literal Standard Version",                   language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "c315fa9f71d4af3a-01", code: "WEB",  name: "World English Bible",                        language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "f72b840c855f362c-04", code: "WEBBE",name: "World English Bible, British Edition",       language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "7142879509583d59-04", code: "T4T",  name: "Translation for Translators",                language: "eng", description: nil, copyright: nil),
    BibleVersion(id: "bba9f40f2062d3ca-01", code: "BSB",  name: "Berean Standard Bible",                      language: "eng", description: nil, copyright: nil),
]

// MARK: - From CardActivity

// MARK: - Data Model

struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let category: String
    let activityType: String
    let status: String
    let message: String
    let userId: String?
    let memberId: String?
    let groupId: String?
    let eventId: String?
    let enrollmentId: String?
    let organizationId: String?
    let metadata: [String: AnyCodable]?
    let createdAt: String
}

struct ActivityLogResponse: Codable {
    let success: Bool
    let logs: [ActivityLogEntry]
    let pagination: ActivityLogPagination
}

struct ActivityLogPagination: Codable {
    let hasMore: Bool
    let nextCursor: String?
    let count: Int
}

/// Type-erased Codable for metadata
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String { try container.encode(string) }
        else if let int = value as? Int { try container.encode(int) }
        else if let double = value as? Double { try container.encode(double) }
        else if let bool = value as? Bool { try container.encode(bool) }
    }
}

// MARK: - From CardData

public enum LessonActivityStatus {
    case `default`
    case incomplete
    case complete
    /// Group-completion fill: brand-colored border always shown, with the fill
    /// at an opacity equal to the fraction (0…1) of members who completed the
    /// activity. 0 reads as an empty outlined block. Used on enrollment cards.
    case percentComplete(Double)
}

// MARK: - From SelectableLockedBlockView

/// Known style identifiers.
enum ReadBlockSelectionStyle: String {
    case bold
    case highlight
}
