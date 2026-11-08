//
//  StudyModels.swift
//  MakeReady
//
//  Data models for study programs, lessons, and activities.
//  Matches server-side Prisma schema for StudyProgram, Lesson, LessonActivity.
//
//  API Reference: See .claude/API_REFERENCE.md for endpoint specifications.
//

import Foundation

// MARK: - Study Program Models

/// A study program curriculum containing lessons for multiple days
///
/// Supports both the new API format (title, isPublished, lessonCount) and legacy
/// cached data (name, isActive, days, creatorId, _count).
struct StudyProgram: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var description: String?
    var days: Int
    var coverImageUrl: String?
    var creatorId: String?
    var isActive: Bool?
    var isPublished: Bool?
    let createdAt: Date
    var updatedAt: Date
    var lessons: [Lesson]?
    /// Count metadata from server (legacy format, also populated from lessonCount)
    var _count: ProgramCount?
    var templateId: String?
    var templateName: String?
    var tags: [String]?
    // ui2-programs D15 (§Contract): names, settings and the cover's original + framing. All
    // optional — a program cached before these keys existed decodes with them nil.
    var creatorName: String?
    var leaderName: String?
    var leaderId: String?
    var organizationId: String?
    var organizationName: String?
    var coverOriginalUrl: String?
    var isPrivate: Bool?
    var ageRangeMin: Int?
    var ageRangeMax: Int?
    var maxMembers: Int?
    /// The server's DirectoryAccess raw value, held as a String exactly as `UserGroup` holds it.
    var memberDirectoryAccess: String?
    var coverFraming: ImageFraming?
    /// ui2-enrollment-create D8: enrollments that ended before today; nil on an old cache
    var completedEnrollmentCount: Int?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, title, description
        case days, lessonCount, coverImageUrl
        case creatorId, isActive, isPublished
        case createdAt, updatedAt, lessons
        case _count
        case templateId, template, templateName
        case tags
        case creatorName, leaderName, leaderId, organizationId, organizationName
        case coverOriginalUrl, isPrivate, ageRangeMin, ageRangeMax, maxMembers
        case memberDirectoryAccess, coverFraming
        case completedEnrollmentCount
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // name: try "title" (new API) first, fall back to "name" (cached)
        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            name = title
        } else {
            name = try container.decode(String.self, forKey: .name)
        }

        description = try container.decodeIfPresent(String.self, forKey: .description)

        // days: try "days" (cached) first, then "lessonCount" (new API), then 0
        if let d = try container.decodeIfPresent(Int.self, forKey: .days) {
            days = d
        } else if let lc = try container.decodeIfPresent(Int.self, forKey: .lessonCount) {
            days = lc
        } else {
            days = 0
        }

        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)

        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
        isPublished = try container.decodeIfPresent(Bool.self, forKey: .isPublished)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lessons = try container.decodeIfPresent([Lesson].self, forKey: .lessons)

        // _count: try legacy format first, then construct from lessonCount
        if let count = try container.decodeIfPresent(ProgramCount.self, forKey: ._count) {
            _count = count
        } else if let lc = try container.decodeIfPresent(Int.self, forKey: .lessonCount) {
            _count = ProgramCount(lessons: lc, enrollments: nil)
        }

        // template: nested object { id, name } from API, or flat templateId/templateName from cache
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        if let templateObj = try container.decodeIfPresent([String: String].self, forKey: .template) {
            if templateId == nil { templateId = templateObj["id"] }
            templateName = templateObj["name"]
        } else {
            templateName = try container.decodeIfPresent(String.self, forKey: .templateName)
        }

        tags = try container.decodeIfPresent([String].self, forKey: .tags)

        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
        leaderName = try container.decodeIfPresent(String.self, forKey: .leaderName)
        leaderId = try container.decodeIfPresent(String.self, forKey: .leaderId)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
        coverOriginalUrl = try container.decodeIfPresent(String.self, forKey: .coverOriginalUrl)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
        ageRangeMin = try container.decodeIfPresent(Int.self, forKey: .ageRangeMin)
        ageRangeMax = try container.decodeIfPresent(Int.self, forKey: .ageRangeMax)
        maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers)
        // Tolerant, as UserGroup's (GroupModels.swift): a malformed value reads as unset rather
        // than failing the whole program — and with it the cached list.
        memberDirectoryAccess = (try? container.decodeIfPresent(String.self, forKey: .memberDirectoryAccess)) ?? nil
        coverFraming = (try? container.decodeIfPresent(ImageFraming.self, forKey: .coverFraming)) ?? nil
        completedEnrollmentCount = try container.decodeIfPresent(Int.self, forKey: .completedEnrollmentCount)
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .title)  // Always encode as "title" (new format)
        try container.encode(name, forKey: .name)    // Also write "name" for cache compat
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(days, forKey: .days)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
        try container.encodeIfPresent(creatorId, forKey: .creatorId)
        try container.encodeIfPresent(isActive, forKey: .isActive)
        try container.encodeIfPresent(isPublished, forKey: .isPublished)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(lessons, forKey: .lessons)
        try container.encodeIfPresent(_count, forKey: ._count)
        try container.encodeIfPresent(templateId, forKey: .templateId)
        try container.encodeIfPresent(templateName, forKey: .templateName)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(creatorName, forKey: .creatorName)
        try container.encodeIfPresent(leaderName, forKey: .leaderName)
        try container.encodeIfPresent(leaderId, forKey: .leaderId)
        try container.encodeIfPresent(organizationId, forKey: .organizationId)
        try container.encodeIfPresent(organizationName, forKey: .organizationName)
        try container.encodeIfPresent(coverOriginalUrl, forKey: .coverOriginalUrl)
        try container.encodeIfPresent(isPrivate, forKey: .isPrivate)
        try container.encodeIfPresent(ageRangeMin, forKey: .ageRangeMin)
        try container.encodeIfPresent(ageRangeMax, forKey: .ageRangeMax)
        try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
        try container.encodeIfPresent(memberDirectoryAccess, forKey: .memberDirectoryAccess)
        try container.encodeIfPresent(coverFraming, forKey: .coverFraming)
        try container.encodeIfPresent(completedEnrollmentCount, forKey: .completedEnrollmentCount)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        name: String,
        description: String? = nil,
        days: Int = 0,
        coverImageUrl: String? = nil,
        creatorId: String? = nil,
        isActive: Bool? = nil,
        isPublished: Bool? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lessons: [Lesson]? = nil,
        _count: ProgramCount? = nil,
        templateId: String? = nil,
        templateName: String? = nil,
        tags: [String]? = nil,
        creatorName: String? = nil,
        leaderName: String? = nil,
        leaderId: String? = nil,
        organizationId: String? = nil,
        organizationName: String? = nil,
        coverOriginalUrl: String? = nil,
        isPrivate: Bool? = nil,
        ageRangeMin: Int? = nil,
        ageRangeMax: Int? = nil,
        maxMembers: Int? = nil,
        memberDirectoryAccess: String? = nil,
        coverFraming: ImageFraming? = nil,
        completedEnrollmentCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.days = days
        self.coverImageUrl = coverImageUrl
        self.creatorId = creatorId
        self.isActive = isActive
        self.isPublished = isPublished
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lessons = lessons
        self._count = _count
        self.templateId = templateId
        self.templateName = templateName
        self.tags = tags
        self.creatorName = creatorName
        self.leaderName = leaderName
        self.leaderId = leaderId
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.coverOriginalUrl = coverOriginalUrl
        self.isPrivate = isPrivate
        self.ageRangeMin = ageRangeMin
        self.ageRangeMax = ageRangeMax
        self.maxMembers = maxMembers
        self.memberDirectoryAccess = memberDirectoryAccess
        self.coverFraming = coverFraming
        self.completedEnrollmentCount = completedEnrollmentCount
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: StudyProgram, rhs: StudyProgram) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.isPublished == rhs.isPublished &&
        lhs.coverImageUrl == rhs.coverImageUrl &&
        lhs.days == rhs.days &&
        lhs.updatedAt == rhs.updatedAt &&
        lhs.tags == rhs.tags &&
        lhs.creatorName == rhs.creatorName &&
        lhs.leaderName == rhs.leaderName &&
        lhs.leaderId == rhs.leaderId &&
        lhs.organizationName == rhs.organizationName &&
        lhs.coverOriginalUrl == rhs.coverOriginalUrl &&
        lhs.isPrivate == rhs.isPrivate &&
        lhs.ageRangeMin == rhs.ageRangeMin &&
        lhs.ageRangeMax == rhs.ageRangeMax &&
        lhs.maxMembers == rhs.maxMembers &&
        lhs.memberDirectoryAccess == rhs.memberDirectoryAccess &&
        lhs.coverFraming == rhs.coverFraming
    }
}

extension StudyProgram {
    /// True when the given user is the program's creator and therefore
    /// allowed to mutate it (rename, add/remove lessons, edit activities,
    /// reorder, swipe-delete, etc.). Group leaders can VIEW any program in
    /// their org but only edit ones they created themselves.
    ///
    /// Returns false when either side is missing — defensive default that
    /// prevents accidental writes during loading or for malformed data.
    func isEditable(by userId: String?) -> Bool {
        guard let userId, let creatorId else { return false }
        return creatorId == userId
    }
}

/// Count metadata for program pagination
struct ProgramCount: Codable, Hashable {
    let lessons: Int?
    let enrollments: Int?
}

/// A single lesson (day) within a study program, as `GET /api/programs/:id` carries it
/// (SPEC §Contract): its position, the title and estimate of the version shown (the draft, else the
/// latest published), both version ids, and that version's activities as rail summaries.
struct Lesson: Codable, Identifiable, Equatable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id && lhs.position == rhs.position && lhs.title == rhs.title
            && lhs.estimatedSeconds == rhs.estimatedSeconds && lhs.draftVersionId == rhs.draftVersionId
            && lhs.publishedVersionId == rhs.publishedVersionId && lhs.updatedAt == rhs.updatedAt
            && lhs.activities == rhs.activities
    }

    let id: String
    var studyProgramId: String?  // Optional when nested in program response
    var position: Int
    var title: String?
    var estimatedSeconds: Int?
    var draftVersionId: String?
    var publishedVersionId: String?
    var activities: [ActivitySummary]
    let createdAt: Date
    var updatedAt: Date

    /// The 1.0 name for `position`, kept for readers that label a lesson "Day N".
    var dayNumber: Int { position }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, studyProgramId, programId
        case position, dayNumber
        case title, estimatedSeconds, draftVersionId, publishedVersionId
        case activities, createdAt, updatedAt
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decodeIfPresent(String.self, forKey: .studyProgramId)
        }
        // The server sends `position` and, for older readers, the same number as `dayNumber`.
        if let value = try container.decodeIfPresent(Int.self, forKey: .position) {
            position = value
        } else {
            position = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        }
        title = try container.decodeIfPresent(String.self, forKey: .title)
        estimatedSeconds = try container.decodeIfPresent(Int.self, forKey: .estimatedSeconds)
        draftVersionId = try container.decodeIfPresent(String.self, forKey: .draftVersionId)
        publishedVersionId = try container.decodeIfPresent(String.self, forKey: .publishedVersionId)
        activities = try container.decodeIfPresent([ActivitySummary].self, forKey: .activities) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(studyProgramId, forKey: .programId)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(estimatedSeconds, forKey: .estimatedSeconds)
        try container.encodeIfPresent(draftVersionId, forKey: .draftVersionId)
        try container.encodeIfPresent(publishedVersionId, forKey: .publishedVersionId)
        try container.encode(activities, forKey: .activities)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        studyProgramId: String? = nil,
        position: Int = 1,
        title: String? = nil,
        estimatedSeconds: Int? = nil,
        draftVersionId: String? = nil,
        publishedVersionId: String? = nil,
        activities: [ActivitySummary] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.studyProgramId = studyProgramId
        self.position = position
        self.title = title
        self.estimatedSeconds = estimatedSeconds
        self.draftVersionId = draftVersionId
        self.publishedVersionId = publishedVersionId
        self.activities = activities
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Pagination Models

/// Pagination metadata returned with paginated responses
struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let totalLessons: Int
    let totalPages: Int
    let hasMore: Bool
}

// MARK: - API Response Models

/// Response from POST /api/programs and GET /api/programs/:id
struct CreateProgramResponse: Codable {
    let success: Bool
    let program: StudyProgram?
    /// Pagination info (only present when fetching single program with paginated lessons)
    let pagination: PaginationInfo?
    /// `GET /api/programs/:id` (§Contract): the media the lessons' documents name.
    let media: [String: MediaMapEntry]?
    let error: String?
}

/// Response from GET /api/programs
struct ListProgramsResponse: Codable {
    let success: Bool
    let programs: [StudyProgram]?
    let error: String?
}

/// Generic success response
struct SuccessResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Lesson Template Models

/// A reusable lesson template that defines activity structures copied into each lesson on program creation
struct LessonTemplate: Codable, Identifiable {
    let id: String
    var name: String
    var description: String?
    let createdAt: Date
    var updatedAt: Date
}

/// Response from GET /api/templates
/// Note: Templates endpoint may not include `success` field (returns just `{ templates: [...] }`)
struct ListTemplatesResponse: Codable {
    let success: Bool?
    let templates: [LessonTemplate]?
    let error: String?
}

// MARK: - Date Decoding Strategy

extension JSONDecoder {
    /// Decoder configured for API responses with ISO8601 dates
    static var apiDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    /// Encoder configured for API requests with ISO8601 dates
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
