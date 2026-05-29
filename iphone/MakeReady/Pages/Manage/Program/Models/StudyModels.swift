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
    var defaultActivity: ActivityType?
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

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, title, description, defaultActivity
        case days, lessonCount, coverImageUrl
        case creatorId, isActive, isPublished
        case createdAt, updatedAt, lessons
        case _count
        case templateId, template, templateName
        case tags
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
        defaultActivity = try container.decodeIfPresent(ActivityType.self, forKey: .defaultActivity)

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
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .title)  // Always encode as "title" (new format)
        try container.encode(name, forKey: .name)    // Also write "name" for cache compat
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(defaultActivity, forKey: .defaultActivity)
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
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        name: String,
        description: String? = nil,
        defaultActivity: ActivityType? = nil,
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
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.defaultActivity = defaultActivity
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
        lhs.tags == rhs.tags
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

/// A single day/lesson within a study program
///
/// Supports both the new API format (programId, orderIndex, title, description) and
/// legacy cached data (studyProgramId, dayNumber).
struct Lesson: Codable, Identifiable, Equatable {
    static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id && lhs.dayNumber == rhs.dayNumber && lhs.title == rhs.title && lhs.updatedAt == rhs.updatedAt && lhs.activities.count == rhs.activities.count
    }

    let id: String
    var studyProgramId: String?  // Optional when nested in program response
    var dayNumber: Int
    var title: String?           // New API: lesson title
    var lessonDescription: String?  // New API: lesson description
    var estimatedMinutes: Int?   // Calculated time estimate in minutes
    var activities: [StudyActivity]
    let createdAt: Date
    var updatedAt: Date

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, studyProgramId, programId
        case dayNumber, orderIndex
        case title, description, estimatedMinutes
        case activities, createdAt, updatedAt
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        // studyProgramId: try "programId" (new API) first, fall back to "studyProgramId" (cached)
        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decodeIfPresent(String.self, forKey: .studyProgramId)
        }

        // dayNumber: try "orderIndex" (new API) first, fall back to "dayNumber" (cached)
        if let idx = try container.decodeIfPresent(Int.self, forKey: .orderIndex) {
            dayNumber = idx
        } else {
            dayNumber = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        }

        title = try container.decodeIfPresent(String.self, forKey: .title)
        lessonDescription = try container.decodeIfPresent(String.self, forKey: .description)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        activities = try container.decodeIfPresent([StudyActivity].self, forKey: .activities) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(studyProgramId, forKey: .programId)  // New format
        try container.encodeIfPresent(studyProgramId, forKey: .studyProgramId)  // Cache compat
        try container.encode(dayNumber, forKey: .orderIndex)  // New format
        try container.encode(dayNumber, forKey: .dayNumber)   // Cache compat
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(lessonDescription, forKey: .description)
        try container.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(activities, forKey: .activities)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        studyProgramId: String? = nil,
        dayNumber: Int = 1,
        title: String? = nil,
        lessonDescription: String? = nil,
        estimatedMinutes: Int? = nil,
        activities: [StudyActivity] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.studyProgramId = studyProgramId
        self.dayNumber = dayNumber
        self.title = title
        self.lessonDescription = lessonDescription
        self.estimatedMinutes = estimatedMinutes
        self.activities = activities
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Whether this lesson is ready (has at least one activity and all activities are configured)
    var isReady: Bool {
        guard !activities.isEmpty else { return false }
        return activities.allSatisfy { $0.isConfigured }
    }

    /// Total estimated minutes for this lesson, computed from activity estimates.
    /// Falls back to the server-provided `estimatedMinutes` if no activity has an estimate.
    var totalEstimatedMinutes: Int? {
        let totalSeconds = activities.compactMap(\.estimatedSeconds).reduce(0, +)
        if totalSeconds > 0 {
            return max(1, Int(round(Double(totalSeconds) / 60.0)))
        }
        return estimatedMinutes
    }
}

/// Embedded video data returned with activities
struct EmbeddedVideo: Codable {
    let id: String
    var cloudflareUid: String?  // Optional: not always returned by API
    let playbackUrl: String
    var thumbnailUrl: String?
    var title: String?
    var duration: Int?
    var status: String

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// A source reference attached to an activity (e.g., a Bible passage row).
///
/// **Invariant:** A source reference is "live" only when at least one
/// `ActivityReadBlock.sourceReferenceId` points to it. The bare
/// `activity.sourceReferences` array can — and historically does — accumulate
/// dangling rows the server failed to clean up after a block delete.
///
/// **Never** read this array directly to answer "what verses does this activity
/// use?" Always go through the read blocks via `AppState.passagesUsedIn(...)`,
/// which uses `passagesFromBlocks` to resolve `block.sourceReferenceId →
/// ActivitySourceReference`. That is the single source of truth, and it makes
/// us immune to dangling rows by construction.
struct ActivitySourceReference: Codable, Identifiable {
    let id: String
    let lessonActivityId: String?
    var sourceType: String?
    var passageReference: String?
    var bookNumber: Int?
    var bookName: String?
    var chapterStart: Int?
    var chapterEnd: Int?
    var verseStart: Int?
    var verseEnd: Int?
    let createdAt: Date?
    var updatedAt: Date?
}

/// An author-defined styled span within a read block. Offsets index into the
/// stripped plain-text representation of `ActivityReadBlock.content` (see
/// `stripBlockContentToPlain`). The `style` value is opaque to storage —
/// renderers wrap matching ranges with `[[ ]]` markers; unknown styles fall
/// back to plain text.
struct ReadBlockSelection: Codable, Identifiable, Equatable {
    var id: String { "\(start)-\(end)-\(style)" }
    let start: Int
    let end: Int
    let style: String
}

/// Leader-authored highlight + markdown note for EXEGESIS activities.
struct ExegesisHighlight: Codable, Identifiable, Equatable {
    let id: String
    let readBlockId: String
    var orderNumber: Int
    let start: Int
    let end: Int
    var noteMarkdown: String
    let createdAt: Date?
    var updatedAt: Date?
}

/// A read block within a READ activity (verse or editable content section)
struct ActivityReadBlock: Codable, Identifiable {
    let id: String
    let lessonActivityId: String?
    var orderNumber: Int
    var title: String?
    var content: String?
    var isLocked: Bool
    var sourceReferenceId: String?
    var themeId: String?
    var contentFormat: String?
    var backgroundImageUrl: String?
    var backgroundColor: String?
    var backgroundOverlayOpacity: Double?
    var fontSize: String?
    var selections: [ReadBlockSelection]?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, lessonActivityId, orderNumber, title, content
        case isLocked, sourceReferenceId, themeId, contentFormat
        case backgroundImageUrl, backgroundColor, backgroundOverlayOpacity
        case fontSize, selections, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lessonActivityId = try container.decodeIfPresent(String.self, forKey: .lessonActivityId)
        orderNumber = try container.decodeIfPresent(Int.self, forKey: .orderNumber) ?? 1
        title = try container.decodeIfPresent(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        sourceReferenceId = try container.decodeIfPresent(String.self, forKey: .sourceReferenceId)
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId)
        contentFormat = try container.decodeIfPresent(String.self, forKey: .contentFormat)
        backgroundImageUrl = try container.decodeIfPresent(String.self, forKey: .backgroundImageUrl)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        backgroundOverlayOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOverlayOpacity)
        fontSize = try container.decodeIfPresent(String.self, forKey: .fontSize)
        selections = try container.decodeIfPresent([ReadBlockSelection].self, forKey: .selections)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    init(
        id: String,
        lessonActivityId: String? = nil,
        orderNumber: Int = 1,
        title: String? = nil,
        content: String? = nil,
        isLocked: Bool = false,
        sourceReferenceId: String? = nil,
        themeId: String? = nil,
        contentFormat: String? = nil,
        backgroundImageUrl: String? = nil,
        backgroundColor: String? = nil,
        backgroundOverlayOpacity: Double? = nil,
        fontSize: String? = nil,
        selections: [ReadBlockSelection]? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.lessonActivityId = lessonActivityId
        self.orderNumber = orderNumber
        self.title = title
        self.content = content
        self.isLocked = isLocked
        self.sourceReferenceId = sourceReferenceId
        self.themeId = themeId
        self.contentFormat = contentFormat
        self.backgroundImageUrl = backgroundImageUrl
        self.backgroundColor = backgroundColor
        self.backgroundOverlayOpacity = backgroundOverlayOpacity
        self.fontSize = fontSize
        self.selections = selections
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// An activity within a lesson (e.g., study prompt, reading content, or video)
/// Named StudyActivity to avoid conflict with LessonActivity view component
///
/// Supports both the legacy API format (type/status/passageReference) and the new format
/// (activityType/title/helpTitle/readContent/sourceReferences).
struct StudyActivity: Codable, Identifiable {
    let id: String
    let lessonId: String?  // Optional when nested in lesson response
    var type: ActivityType
    var status: ActivityStatus
    var orderNumber: Int
    let createdAt: Date?   // Optional when nested in lesson response
    var updatedAt: Date?   // Optional when nested in lesson response

    // New API fields
    var title: String?             // Human-readable activity title from API (e.g., "Scripture", "Observation")
    var isHelpEnabled: Bool?       // Whether context help is enabled
    var helpTitle: String?         // Helper text title
    var helpDescription: String?   // Helper text body
    var helpAlwaysVisible: Bool?   // Show helper expanded
    var helpIcon: String?          // Icon identifier
    var placeholder: String?       // Custom placeholder text for USER_INPUT activities
    var readContent: String?       // Markdown content for READ activities
    var sourceReferences: [ActivitySourceReference]?  // Source references
    var readBlocks: [ActivityReadBlock]?              // Read blocks for multi-block READ activities

    // Theme override (applies to all read blocks in this activity)
    var themeId: String?

    // Video reference (for VIDEO type activities)
    var videoId: String?           // Reference to Video record
    var videoUrl: String?          // Cloudflare Stream playback URL
    var video: EmbeddedVideo?      // Full video object with thumbnailUrl

    // YouTube reference (for YOUTUBE type activities)
    var youtubeUrl: String?           // Full YouTube URL
    var youtubeVideoId: String?       // Extracted YouTube video ID
    var youtubeStartSeconds: Int?     // Start time in seconds
    var youtubeEndSeconds: Int?       // End time in seconds
    var youtubeThumbnailUrl: String?  // Thumbnail URL from oEmbed

    // Legacy passage fields (kept for backward compat with cached data)
    var passageReference: String?  // "Romans 1:1-5" or "Romans 1:28 - 2:4"
    var bookNumber: Int?           // 1-66
    var bookName: String?          // "Romans"
    var chapterStart: Int?         // Starting chapter
    var chapterEnd: Int?           // Ending chapter (nil if same as start)
    var verseStart: Int?           // Starting verse
    var verseEnd: Int?             // Ending verse
    var startElementId: String?    // "45-1-1" (bookNum-chapter-verse)
    var startOffset: Int?          // Character offset in start verse
    var endElementId: String?      // "45-1-5"
    var endOffset: Int?            // Character offset in end verse (exclusive)

    // Time estimate
    var estimatedSeconds: Int?     // Calculated time estimate in seconds

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, lessonId, type, activityType, status, orderNumber
        case createdAt, updatedAt
        case title, isHelpEnabled, helpTitle, helpDescription, helpAlwaysVisible, helpIcon, placeholder
        case readContent, sourceReferences, readBlocks
        case themeId
        case videoId, videoUrl, video
        case youtubeUrl, youtubeVideoId, youtubeStartSeconds, youtubeEndSeconds, youtubeThumbnailUrl
        case passageReference, bookNumber, bookName
        case chapterStart, chapterEnd, verseStart, verseEnd
        case startElementId, startOffset, endElementId, endOffset
        case estimatedSeconds
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        lessonId = try container.decodeIfPresent(String.self, forKey: .lessonId)
        orderNumber = try container.decodeIfPresent(Int.self, forKey: .orderNumber) ?? 1

        // Handle activityType (new API) vs type (legacy/cached data)
        if let activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) {
            type = activityType
        } else {
            type = try container.decode(ActivityType.self, forKey: .type)
        }

        // Status defaults to .pending when not present (new API doesn't include it)
        status = try container.decodeIfPresent(ActivityStatus.self, forKey: .status) ?? .pending

        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)

        // New API fields
        title = try container.decodeIfPresent(String.self, forKey: .title)
        isHelpEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHelpEnabled)
        helpTitle = try container.decodeIfPresent(String.self, forKey: .helpTitle)
        helpDescription = try container.decodeIfPresent(String.self, forKey: .helpDescription)
        helpAlwaysVisible = try container.decodeIfPresent(Bool.self, forKey: .helpAlwaysVisible)
        helpIcon = try container.decodeIfPresent(String.self, forKey: .helpIcon)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        readContent = try container.decodeIfPresent(String.self, forKey: .readContent)
        sourceReferences = try container.decodeIfPresent([ActivitySourceReference].self, forKey: .sourceReferences)
        readBlocks = try container.decodeIfPresent([ActivityReadBlock].self, forKey: .readBlocks)

        // Theme override
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId)

        // Video fields
        videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        video = try container.decodeIfPresent(EmbeddedVideo.self, forKey: .video)

        // YouTube fields
        youtubeUrl = try container.decodeIfPresent(String.self, forKey: .youtubeUrl)
        youtubeVideoId = try container.decodeIfPresent(String.self, forKey: .youtubeVideoId)
        youtubeStartSeconds = try container.decodeIfPresent(Int.self, forKey: .youtubeStartSeconds)
        youtubeEndSeconds = try container.decodeIfPresent(Int.self, forKey: .youtubeEndSeconds)
        youtubeThumbnailUrl = try container.decodeIfPresent(String.self, forKey: .youtubeThumbnailUrl)

        // Legacy passage fields
        passageReference = try container.decodeIfPresent(String.self, forKey: .passageReference)
        bookNumber = try container.decodeIfPresent(Int.self, forKey: .bookNumber)
        bookName = try container.decodeIfPresent(String.self, forKey: .bookName)
        chapterStart = try container.decodeIfPresent(Int.self, forKey: .chapterStart)
        chapterEnd = try container.decodeIfPresent(Int.self, forKey: .chapterEnd)
        verseStart = try container.decodeIfPresent(Int.self, forKey: .verseStart)
        verseEnd = try container.decodeIfPresent(Int.self, forKey: .verseEnd)
        startElementId = try container.decodeIfPresent(String.self, forKey: .startElementId)
        startOffset = try container.decodeIfPresent(Int.self, forKey: .startOffset)
        endElementId = try container.decodeIfPresent(String.self, forKey: .endElementId)
        endOffset = try container.decodeIfPresent(Int.self, forKey: .endOffset)
        estimatedSeconds = try container.decodeIfPresent(Int.self, forKey: .estimatedSeconds)
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(lessonId, forKey: .lessonId)
        try container.encode(type, forKey: .activityType)  // Always encode as activityType
        try container.encode(status, forKey: .status)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)

        // New API fields
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(isHelpEnabled, forKey: .isHelpEnabled)
        try container.encodeIfPresent(helpTitle, forKey: .helpTitle)
        try container.encodeIfPresent(helpDescription, forKey: .helpDescription)
        try container.encodeIfPresent(helpAlwaysVisible, forKey: .helpAlwaysVisible)
        try container.encodeIfPresent(helpIcon, forKey: .helpIcon)
        try container.encodeIfPresent(readContent, forKey: .readContent)
        try container.encodeIfPresent(sourceReferences, forKey: .sourceReferences)
        try container.encodeIfPresent(readBlocks, forKey: .readBlocks)

        // Theme override
        try container.encodeIfPresent(themeId, forKey: .themeId)

        // Video fields
        try container.encodeIfPresent(videoId, forKey: .videoId)
        try container.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(video, forKey: .video)

        // YouTube fields
        try container.encodeIfPresent(youtubeUrl, forKey: .youtubeUrl)
        try container.encodeIfPresent(youtubeVideoId, forKey: .youtubeVideoId)
        try container.encodeIfPresent(youtubeStartSeconds, forKey: .youtubeStartSeconds)
        try container.encodeIfPresent(youtubeEndSeconds, forKey: .youtubeEndSeconds)
        try container.encodeIfPresent(youtubeThumbnailUrl, forKey: .youtubeThumbnailUrl)

        // Legacy passage fields
        try container.encodeIfPresent(passageReference, forKey: .passageReference)
        try container.encodeIfPresent(bookNumber, forKey: .bookNumber)
        try container.encodeIfPresent(bookName, forKey: .bookName)
        try container.encodeIfPresent(chapterStart, forKey: .chapterStart)
        try container.encodeIfPresent(chapterEnd, forKey: .chapterEnd)
        try container.encodeIfPresent(verseStart, forKey: .verseStart)
        try container.encodeIfPresent(verseEnd, forKey: .verseEnd)
        try container.encodeIfPresent(startElementId, forKey: .startElementId)
        try container.encodeIfPresent(startOffset, forKey: .startOffset)
        try container.encodeIfPresent(endElementId, forKey: .endElementId)
        try container.encodeIfPresent(endOffset, forKey: .endOffset)
        try container.encodeIfPresent(estimatedSeconds, forKey: .estimatedSeconds)
    }

    // MARK: - Memberwise Init (for previews and programmatic creation)

    init(
        id: String,
        lessonId: String? = nil,
        type: ActivityType,
        status: ActivityStatus = .pending,
        orderNumber: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        title: String? = nil,
        isHelpEnabled: Bool? = nil,
        helpTitle: String? = nil,
        helpDescription: String? = nil,
        helpAlwaysVisible: Bool? = nil,
        helpIcon: String? = nil,
        placeholder: String? = nil,
        readContent: String? = nil,
        sourceReferences: [ActivitySourceReference]? = nil,
        readBlocks: [ActivityReadBlock]? = nil,
        themeId: String? = nil,
        videoId: String? = nil,
        videoUrl: String? = nil,
        video: EmbeddedVideo? = nil,
        passageReference: String? = nil,
        bookNumber: Int? = nil,
        bookName: String? = nil,
        chapterStart: Int? = nil,
        chapterEnd: Int? = nil,
        verseStart: Int? = nil,
        verseEnd: Int? = nil,
        startElementId: String? = nil,
        startOffset: Int? = nil,
        endElementId: String? = nil,
        endOffset: Int? = nil
    ) {
        self.id = id
        self.lessonId = lessonId
        self.type = type
        self.status = status
        self.orderNumber = orderNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.isHelpEnabled = isHelpEnabled
        self.helpTitle = helpTitle
        self.helpDescription = helpDescription
        self.helpAlwaysVisible = helpAlwaysVisible
        self.helpIcon = helpIcon
        self.placeholder = placeholder
        self.readContent = readContent
        self.sourceReferences = sourceReferences
        self.readBlocks = readBlocks
        self.themeId = themeId
        self.videoId = videoId
        self.videoUrl = videoUrl
        self.video = video
        self.passageReference = passageReference
        self.bookNumber = bookNumber
        self.bookName = bookName
        self.chapterStart = chapterStart
        self.chapterEnd = chapterEnd
        self.verseStart = verseStart
        self.verseEnd = verseEnd
        self.startElementId = startElementId
        self.startOffset = startOffset
        self.endElementId = endElementId
        self.endOffset = endOffset
    }

    // MARK: - Computed Properties

    // Computed property for backward compatibility
    var passageData: PassageData? {
        guard let bookNumber = bookNumber,
              let bookName = bookName,
              let chapterStart = chapterStart,
              let verseStart = verseStart,
              let verseEnd = verseEnd else {
            return nil
        }
        return PassageData(
            bookNumber: bookNumber,
            bookName: bookName,
            chapterStart: chapterStart,
            chapterEnd: chapterEnd,
            verseStart: verseStart,
            verseEnd: verseEnd
        )
    }

    // Computed property for highlight range
    var highlightRange: HighlightRange? {
        guard let startElementId = startElementId,
              let startOffset = startOffset,
              let endElementId = endElementId,
              let endOffset = endOffset else {
            return nil
        }
        return HighlightRange(
            startElementId: startElementId,
            startOffset: startOffset,
            endElementId: endElementId,
            endOffset: endOffset
        )
    }

    /// Whether this activity has the required content assigned
    /// - VIDEO type requires a videoId
    /// - READ type is configured if it has readContent
    /// - USER_INPUT type is always considered configured (users fill in during study)
    /// - Legacy study types (SOAP, OIA, DBS, HEAR) require a passageReference
    var isConfigured: Bool {
        switch type {
        case .video:
            return (videoId != nil && !videoId!.isEmpty) || (videoUrl != nil && !videoUrl!.isEmpty)
        case .youtube:
            return youtubeUrl != nil && !youtubeUrl!.isEmpty
        case .read:
            if let blocks = readBlocks, !blocks.isEmpty {
                return blocks.contains { ($0.content ?? "").isEmpty == false }
            }
            return readContent != nil && !readContent!.isEmpty
        case .exegesis:
            guard let t = title, !t.isEmpty else { return false }
            guard let blocks = readBlocks,
                  let locked = blocks.first(where: { $0.isLocked }),
                  let content = locked.content, !content.isEmpty else {
                return false
            }
            // Highlights are derived from EXEGESIS highlight rows and cached
            // as block.selections for rendering.
            return (locked.selections ?? []).isEmpty == false
        case .userInput:
            return title != nil && !title!.isEmpty
        case .soap, .oia, .dbs, .hear:
            return passageReference != nil && !passageReference!.isEmpty
        }
    }
}

// MARK: - Activity Enums

/// Types of study activities
/// Supports both legacy values (SOAP, OIA, DBS, HEAR) and new API values (USER_INPUT, READ, VIDEO)
enum ActivityType: String, Codable, CaseIterable {
    case soap = "SOAP"
    case oia = "OIA"
    case dbs = "DBS"
    case hear = "HEAR"
    case video = "VIDEO"
    case youtube = "YOUTUBE"
    case userInput = "USER_INPUT"
    case read = "READ"
    case exegesis = "EXEGESIS"

    var displayName: String {
        switch self {
        case .userInput: return "Study"
        case .read: return "Read"
        case .youtube: return "YouTube"
        case .exegesis: return "Exegesis"
        default: return rawValue
        }
    }

    var description: String {
        switch self {
        case .soap:
            return "Read Scripture, make Observations, note Application, and close with Prayer."
        case .oia:
            return "Observe the text, Interpret its meaning, then Apply it to life."
        case .dbs:
            return "Look back, look up (read Scripture), look in, look forward, and pray together."
        case .hear:
            return "Highlight verses, Explain the meaning, Apply personally, and Respond in prayer."
        case .video:
            return "Record a video message or select a video from your library."
        case .youtube:
            return "Add a YouTube video for members to watch."
        case .userInput:
            return "Answer a question or write a reflection."
        case .read:
            return "Read the provided content."
        case .exegesis:
            return "Highlight a passage and attach notes for members to review."
        }
    }

    /// Whether this activity type is a Bible study method (vs video)
    var isStudyType: Bool {
        switch self {
        case .video:
            return false
        default:
            return true
        }
    }
}

/// Status of an activity
enum ActivityStatus: String, Codable {
    case pending = "PENDING"
    case complete = "COMPLETE"
}

// MARK: - Passage Data

/// Structured Bible passage data for storage and API
struct PassageData: Codable, Equatable {
    let bookNumber: Int       // 1-66
    let bookName: String      // "Romans"
    let chapterStart: Int     // Starting chapter
    let chapterEnd: Int?      // Ending chapter (nil if same as start)
    let verseStart: Int       // Starting verse
    let verseEnd: Int         // Ending verse

    /// Build from an `ActivitySourceReference`. Returns nil if any required
    /// field is missing on the reference.
    init?(from ref: ActivitySourceReference) {
        guard let bookNumber = ref.bookNumber,
              let bookName = ref.bookName,
              let chapterStart = ref.chapterStart,
              let verseStart = ref.verseStart,
              let verseEnd = ref.verseEnd else { return nil }
        self.bookNumber = bookNumber
        self.bookName = bookName
        self.chapterStart = chapterStart
        self.chapterEnd = ref.chapterEnd
        self.verseStart = verseStart
        self.verseEnd = verseEnd
    }

    /// Memberwise init (Swift loses the synthesized one once a custom init is added).
    init(
        bookNumber: Int,
        bookName: String,
        chapterStart: Int,
        chapterEnd: Int? = nil,
        verseStart: Int,
        verseEnd: Int
    ) {
        self.bookNumber = bookNumber
        self.bookName = bookName
        self.chapterStart = chapterStart
        self.chapterEnd = chapterEnd
        self.verseStart = verseStart
        self.verseEnd = verseEnd
    }

    /// Human-readable reference string
    var reference: String {
        if let chapterEnd = chapterEnd, chapterEnd != chapterStart {
            // Cross-chapter: "Romans 1:28 - 2:4"
            return "\(bookName) \(chapterStart):\(verseStart) - \(chapterEnd):\(verseEnd)"
        } else if verseStart == verseEnd {
            // Single verse: "Romans 1:1"
            return "\(bookName) \(chapterStart):\(verseStart)"
        } else {
            // Same chapter range: "Romans 1:1-5"
            return "\(bookName) \(chapterStart):\(verseStart)-\(verseEnd)"
        }
    }

}

// MARK: - Highlight Range

/// Word-level highlight range for precise text selection
/// Used to recreate exact highlight position in Bible reader
struct HighlightRange: Codable, Equatable {
    let startElementId: String   // "45-1-1" (bookNum-chapter-verse)
    let startOffset: Int         // Character offset in start verse
    let endElementId: String     // "45-1-5"
    let endOffset: Int           // Character offset in end verse (exclusive)
}

// MARK: - Program Activity Context

/// Context for an activity within a program, used for showing all highlights in the reader
/// Includes the day number for display in the reader
struct ProgramActivityContext: Identifiable {
    let activityId: String
    let dayNumber: Int
    let passageData: PassageData
    let highlightRange: HighlightRange

    var id: String { activityId }
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
    let error: String?
}

/// Response from GET /api/programs
struct ListProgramsResponse: Codable {
    let success: Bool
    let programs: [StudyProgram]?
    let error: String?
}

/// Response from PATCH /api/activities/:id and POST /api/.../activities
struct UpdateActivityResponse: Codable {
    let success: Bool
    let activity: StudyActivity?
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
