//
//  LessonModels.swift
//  MakeReady
//
//  Lesson schedule models: scheduled activities, lessons with activities, lesson schedules.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

// MARK: - Lesson Schedule Models

/// Activity within a lesson (API model)
///
/// Supports both new API format (activityType) and legacy (type).
struct ScheduledActivity: Codable, Identifiable {
    let id: String
    var lessonId: String?
    var type: String                    // "USER_INPUT", "READ", "VIDEO", etc.
    var title: String?                   // Human-readable activity title from API
    var isHelpEnabled: Bool?             // Whether context help is enabled
    var helpTitle: String?
    var helpDescription: String?
    var helpIcon: String?
    var readContent: String?
    var sourceReferences: [ActivitySourceReference]?  // Source references
    var readBlocks: [ActivityReadBlock]?              // Read blocks for multi-block READ activities
    var themeId: String?                 // Theme override for all read blocks
    let passageReference: String?       // legacy
    let passageText: String?            // legacy
    var videoId: String?
    var videoUrl: String?
    var video: EmbeddedVideo?
    let prayerPrompt: String?           // legacy
    let notes: String?                  // legacy
    var orderNumber: Int
    var estimatedSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id, lessonId, type, activityType
        case title, isHelpEnabled, helpTitle, helpDescription, helpIcon
        case readContent, sourceReferences, readBlocks
        case themeId
        case passageReference, passageText, videoId, videoUrl, video
        case prayerPrompt, notes, orderNumber, estimatedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        lessonId = try container.decodeIfPresent(String.self, forKey: .lessonId)

        // type: try "activityType" (new API) first, fall back to "type" (cached)
        if let at = try container.decodeIfPresent(String.self, forKey: .activityType) {
            type = at
        } else {
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? "USER_INPUT"
        }

        title = try container.decodeIfPresent(String.self, forKey: .title)
        isHelpEnabled = try container.decodeIfPresent(Bool.self, forKey: .isHelpEnabled)
        helpTitle = try container.decodeIfPresent(String.self, forKey: .helpTitle)
        helpDescription = try container.decodeIfPresent(String.self, forKey: .helpDescription)
        helpIcon = try container.decodeIfPresent(String.self, forKey: .helpIcon)
        readContent = try container.decodeIfPresent(String.self, forKey: .readContent)
        sourceReferences = try container.decodeIfPresent([ActivitySourceReference].self, forKey: .sourceReferences)
        readBlocks = try container.decodeIfPresent([ActivityReadBlock].self, forKey: .readBlocks)
        themeId = try container.decodeIfPresent(String.self, forKey: .themeId)
        passageReference = try container.decodeIfPresent(String.self, forKey: .passageReference)
        passageText = try container.decodeIfPresent(String.self, forKey: .passageText)
        videoId = try container.decodeIfPresent(String.self, forKey: .videoId)
        videoUrl = try container.decodeIfPresent(String.self, forKey: .videoUrl)
        video = try container.decodeIfPresent(EmbeddedVideo.self, forKey: .video)
        prayerPrompt = try container.decodeIfPresent(String.self, forKey: .prayerPrompt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        orderNumber = try container.decodeIfPresent(Int.self, forKey: .orderNumber) ?? 1
        estimatedSeconds = try container.decodeIfPresent(Int.self, forKey: .estimatedSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(lessonId, forKey: .lessonId)
        try container.encode(type, forKey: .activityType)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(isHelpEnabled, forKey: .isHelpEnabled)
        try container.encodeIfPresent(helpTitle, forKey: .helpTitle)
        try container.encodeIfPresent(helpDescription, forKey: .helpDescription)
        try container.encodeIfPresent(helpIcon, forKey: .helpIcon)
        try container.encodeIfPresent(readContent, forKey: .readContent)
        try container.encodeIfPresent(sourceReferences, forKey: .sourceReferences)
        try container.encodeIfPresent(readBlocks, forKey: .readBlocks)
        try container.encodeIfPresent(themeId, forKey: .themeId)
        try container.encodeIfPresent(passageReference, forKey: .passageReference)
        try container.encodeIfPresent(passageText, forKey: .passageText)
        try container.encodeIfPresent(videoId, forKey: .videoId)
        try container.encodeIfPresent(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(video, forKey: .video)
        try container.encodeIfPresent(prayerPrompt, forKey: .prayerPrompt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(orderNumber, forKey: .orderNumber)
        try container.encodeIfPresent(estimatedSeconds, forKey: .estimatedSeconds)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        lessonId: String? = nil,
        type: String,
        title: String? = nil,
        isHelpEnabled: Bool? = nil,
        helpTitle: String? = nil,
        helpDescription: String? = nil,
        helpIcon: String? = nil,
        readContent: String? = nil,
        sourceReferences: [ActivitySourceReference]? = nil,
        readBlocks: [ActivityReadBlock]? = nil,
        themeId: String? = nil,
        passageReference: String? = nil,
        passageText: String? = nil,
        videoId: String? = nil,
        videoUrl: String? = nil,
        video: EmbeddedVideo? = nil,
        prayerPrompt: String? = nil,
        notes: String? = nil,
        orderNumber: Int = 1
    ) {
        self.id = id
        self.lessonId = lessonId
        self.type = type
        self.title = title
        self.isHelpEnabled = isHelpEnabled
        self.helpTitle = helpTitle
        self.helpDescription = helpDescription
        self.helpIcon = helpIcon
        self.readContent = readContent
        self.sourceReferences = sourceReferences
        self.readBlocks = readBlocks
        self.themeId = themeId
        self.passageReference = passageReference
        self.passageText = passageText
        self.videoId = videoId
        self.videoUrl = videoUrl
        self.video = video
        self.prayerPrompt = prayerPrompt
        self.notes = notes
        self.orderNumber = orderNumber
    }

    /// Whether this activity has been configured with actual data
    var isConfigured: Bool {
        switch type {
        case "SCRIPTURE", "SOAP":
            return passageReference != nil && !passageReference!.isEmpty
        case "VIDEO":
            return (videoId != nil && !videoId!.isEmpty) || (videoUrl != nil && !videoUrl!.isEmpty)
        case "PRAYER":
            return prayerPrompt != nil && !prayerPrompt!.isEmpty
        case "REFLECTION":
            return notes != nil && !notes!.isEmpty
        case "READ":
            if let blocks = readBlocks, blocks.contains(where: { ($0.content ?? "").isEmpty == false }) {
                return true
            }
            return readContent != nil && !readContent!.isEmpty
        case "USER_INPUT":
            return true
        default:
            return true
        }
    }

    /// Convert to StudyActivity for use with EditReadActivityPage
    func toStudyActivity() -> StudyActivity {
        let activityType = ActivityType(rawValue: type) ?? .read
        return StudyActivity(
            id: id,
            lessonId: lessonId,
            type: activityType,
            status: .complete,
            orderNumber: orderNumber,
            title: title,
            isHelpEnabled: isHelpEnabled,
            helpTitle: helpTitle,
            helpDescription: helpDescription,
            helpIcon: helpIcon,
            readContent: readContent,
            sourceReferences: sourceReferences,
            readBlocks: readBlocks,
            themeId: themeId,
            videoId: videoId,
            passageReference: passageReference
        )
    }
}

/// Lesson with its activities (API model)
///
/// Supports both new API format (programId, orderIndex) and legacy (studyProgramId, dayNumber).
struct LessonWithActivities: Codable, Identifiable {
    let id: String
    var studyProgramId: String
    var dayNumber: Int
    var title: String?
    var estimatedMinutes: Int?
    let createdAt: Date?
    let updatedAt: Date?
    var activities: [ScheduledActivity]

    enum CodingKeys: String, CodingKey {
        case id, studyProgramId, programId
        case dayNumber, orderIndex
        case title, estimatedMinutes
        case createdAt, updatedAt, activities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        // studyProgramId: try "programId" (new) first, fall back to "studyProgramId" (cached/server)
        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decodeIfPresent(String.self, forKey: .studyProgramId) ?? ""
        }

        // dayNumber: try "orderIndex" (new) first, fall back to "dayNumber" (cached)
        if let idx = try container.decodeIfPresent(Int.self, forKey: .orderIndex) {
            dayNumber = idx
        } else {
            dayNumber = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 1
        }

        title = try container.decodeIfPresent(String.self, forKey: .title)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        activities = try container.decodeIfPresent([ScheduledActivity].self, forKey: .activities) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(studyProgramId, forKey: .programId)
        try container.encode(studyProgramId, forKey: .studyProgramId)
        try container.encode(dayNumber, forKey: .orderIndex)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encode(activities, forKey: .activities)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        studyProgramId: String,
        dayNumber: Int = 1,
        title: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        activities: [ScheduledActivity] = []
    ) {
        self.id = id
        self.studyProgramId = studyProgramId
        self.dayNumber = dayNumber
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.activities = activities
    }

    /// Whether this lesson has at least one configured activity with real data
    var hasConfiguredActivities: Bool {
        activities.contains { $0.isConfigured }
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

/// Scheduled lesson with date and lesson content
struct LessonSchedule: Codable, Identifiable {
    let id: String
    let enrollmentId: String
    let lessonId: String
    let scheduledDate: Date
    let isCompleted: Bool?
    let completedAt: Date?
    var lesson: LessonWithActivities

    /// Formatted month abbreviation (e.g., "JAN")
    var monthAbbrev: String {
        ModelFormatters.monthAbbrev.string(from: scheduledDate).uppercased()
    }

    /// Day of month (e.g., "1", "15")
    var dayOfMonth: String {
        ModelFormatters.dayOfMonth.string(from: scheduledDate)
    }
}
