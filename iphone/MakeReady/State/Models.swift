//
//  Models.swift
//  MakeReady
//
//  Core data models used across the app.
//

import Foundation

// MARK: - Video Models

/// Video status from Cloudflare Stream
enum VideoStatus: String, Codable {
    case pending
    case ready
    case error

    var displayName: String {
        switch self {
        case .pending: return "Processing"
        case .ready: return "Ready"
        case .error: return "Error"
        }
    }
}

/// Video model matching server's Video Prisma model
struct Video: Codable, Identifiable {
    let id: String
    var title: String?
    var description: String?
    let cloudflareUid: String
    let playbackUrl: String
    var thumbnailUrl: String?
    var duration: Int?  // Duration in seconds
    var status: String
    let userId: String
    var isActive: Bool?
    let createdAt: Date
    var updatedAt: Date

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Video status as enum
    var videoStatus: VideoStatus {
        VideoStatus(rawValue: status) ?? .pending
    }

    /// Display title (falls back to "Untitled Video")
    var displayTitle: String {
        title ?? "Untitled Video"
    }
}

// MARK: - Video API Response Models

struct UploadUrlResponse: Codable {
    let success: Bool
    let data: UploadUrlData?
    let error: String?
}

struct UploadUrlData: Codable {
    let uploadUrl: String
    let uid: String
}

struct VideoResponse: Codable {
    let success: Bool
    let data: Video?
    let error: String?
}

struct VideoListResponse: Codable {
    let success: Bool
    let data: [Video]?
    let count: Int?
    let error: String?
}

struct DeleteVideoResponse: Codable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - Video Errors

enum VideoError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case invalidResponse
    case uploadFailed(String)
    case videoNotReady

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage videos."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .videoNotReady:
            return "Video is still processing. Please try again later."
        }
    }
}

// MARK: - Upload Progress

struct UploadProgress {
    let bytesUploaded: Int64
    let totalBytes: Int64

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesUploaded) / Double(totalBytes)
    }

    var percentage: Int {
        Int(progress * 100)
    }
}

// MARK: - Notification Models

/// In-app notification from the server
struct AppNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: String        // "JOIN_REQUEST", "MEMBER_JOINED"
    let title: String
    let body: String
    var isRead: Bool
    let data: NotificationData?
    let createdAt: Date

    /// Relative time string (e.g., "2m ago", "1h ago", "3d ago")
    var relativeTime: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

/// Data payload within a notification
struct NotificationData: Codable {
    let groupId: String?
    let requestId: String?
}

/// API response for notification list
struct NotificationListResponse: Codable {
    let success: Bool
    let notifications: [AppNotification]?
    let error: String?
}

/// API response for unread count
struct UnreadCountResponse: Codable {
    let success: Bool
    let count: Int?
    let error: String?
}

// MARK: - Media Library Models

/// Media type for filtering
enum MediaType: String, Codable {
    case video
    case photo
    case document
    case audio

    var displayName: String {
        switch self {
        case .video: return "Video"
        case .photo: return "Photo"
        case .document: return "Document"
        case .audio: return "Audio"
        }
    }

    var icon: String {
        switch self {
        case .video: return "play.fill"
        case .photo: return "photo"
        case .document: return "doc.fill"
        case .audio: return "waveform"
        }
    }
}

/// A media item from the organization media library
struct MediaLibraryItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var description: String?
    var url: String
    var type: String              // "photo", "video", "document", "audio"
    var mimeType: String?
    var fileSize: Int?
    var thumbnailUrl: String?
    var uploadStatus: String      // "pending", "processing", "ready", "error"
    var duration: Int?            // seconds (videos/audio)
    var tags: [String]
    var usageCount: Int
    var uploader: MediaUploader?
    var video: MediaVideo?
    let createdAt: Date
    var updatedAt: Date

    /// Parsed media type
    var mediaType: MediaType {
        MediaType(rawValue: type) ?? .document
    }

    /// Whether the media is ready
    var isReady: Bool {
        uploadStatus == "ready"
    }

    /// Formatted duration string (e.g., "1:30")
    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Display title
    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    static func == (lhs: MediaLibraryItem, rhs: MediaLibraryItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Media uploader info
struct MediaUploader: Codable, Hashable {
    let id: String
    let name: String
}

/// Video details attached to a media item
struct MediaVideo: Codable, Hashable {
    let id: String
    var playbackUrl: String?
    var duration: Int?
    var status: String?
}

/// API response for media library listing
struct MediaLibraryResponse: Codable {
    let success: Bool?
    let data: [MediaLibraryItem]?
    let total: Int?
    let page: Int?
    let limit: Int?
    let totalPages: Int?
    let error: String?
}

/// API response for media detail
struct MediaDetailResponse: Codable {
    let success: Bool?
    let data: MediaDetailItem?
    let error: String?
}

/// Full media detail with tags, video info, and usage summary
struct MediaDetailItem: Codable {
    let id: String
    let title: String?
    let description: String?
    let url: String?
    let type: String?
    let mimeType: String?
    let fileSize: Int?
    let thumbnailUrl: String?
    let uploadStatus: String?
    let duration: Int?
    let tags: [String]?
    let usageCount: Int?       // from library list endpoint
    let usages: [MediaUsage]?  // from detail endpoint
    let uploader: MediaUploader?
    let video: MediaVideo?
    let organization: MediaOrganization?
    let width: Int?
    let height: Int?
    let aspectRatio: String?
    let dominantColor: String?
    let altText: String?
    let source: String?
    let createdAt: Date?
    let updatedAt: Date?

    /// Parsed media type
    var mediaType: MediaType {
        MediaType(rawValue: type ?? "photo") ?? .document
    }

    /// Formatted duration string
    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted file size
    var formattedFileSize: String? {
        guard let size = fileSize, size > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Display title
    var displayTitle: String {
        let t = title ?? ""
        return t.isEmpty ? "Untitled" : t
    }

    /// Resolved usage count (from either usageCount or usages array length)
    var resolvedUsageCount: Int {
        usageCount ?? usages?.count ?? 0
    }

    /// Dimensions string
    var formattedDimensions: String? {
        guard let w = width, let h = height, w > 0, h > 0 else { return nil }
        return "\(w) × \(h)"
    }
}

/// Organization info on a media detail
struct MediaOrganization: Codable {
    let id: String
    let name: String
}

/// API response for media usages
struct MediaUsagesResponse: Codable {
    let success: Bool?
    let data: [MediaUsage]?
    let error: String?
}

/// A single usage record — where media is referenced
struct MediaUsage: Codable, Identifiable {
    let id: String
    let mediaId: String?
    let usageType: String      // "LESSON_ACTIVITY", "PROGRAM_COVER", "GROUP_COVER", "POST"
    let resourceId: String?
    let resourceName: String?
    let createdAt: Date?

    /// Human-readable resource type
    var displayResourceType: String {
        switch usageType {
        case "LESSON_ACTIVITY": return "Lesson Activity"
        case "PROGRAM_COVER": return "Study Program Cover"
        case "GROUP_COVER": return "Group Cover"
        case "POST": return "Post"
        case "EVENT": return "Event"
        default: return usageType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Icon for the resource type
    var resourceIcon: String {
        switch usageType {
        case "LESSON_ACTIVITY": return "list.bullet"
        case "PROGRAM_COVER": return "book.fill"
        case "GROUP_COVER": return "person.3.fill"
        case "POST": return "text.bubble.fill"
        case "EVENT": return "calendar"
        default: return "link"
        }
    }
}

/// API response for organization lookup
struct OrganizationResponse: Codable {
    let success: Bool?
    let data: OrganizationData?
    let error: String?
}

struct OrganizationData: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    var ownerId: String?
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - Enrollment Models

/// Enrollment with study program details (used in list views)
///
/// Supports both the new API format (programId, startedAt, completedAt, isActive) and
/// legacy cached data (studyProgramId, startDate, endDate, enabledDays, etc.).
struct EnrollmentWithProgram: Codable, Identifiable {
    let id: String
    let groupId: String
    var studyProgramId: String
    var startDate: Date
    var endDate: Date
    var enabledDays: String?
    var smsTime: String?
    var timezone: String?
    var requireResponse: Bool?
    var currentLessonId: String?
    var createdAt: Date?
    var updatedAt: Date?
    let studyProgram: StudyProgramSummary?
    private var _isActive: Bool?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, groupId
        case studyProgramId, programId
        case startDate, startedAt
        case endDate, completedAt
        case enabledDays, smsTime, timezone, requireResponse
        case currentLessonId
        case createdAt, updatedAt
        case studyProgram
        case isActive
    }

    // MARK: - Custom Decoder

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)

        // studyProgramId: try "programId" (new) first, fall back to "studyProgramId" (cached)
        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decode(String.self, forKey: .studyProgramId)
        }

        // startDate: try "startedAt" (new) first, fall back to "startDate" (cached)
        if let sa = try container.decodeIfPresent(Date.self, forKey: .startedAt) {
            startDate = sa
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }

        // endDate: try "completedAt" (new), fall back to "endDate" (cached), default far future
        if let ca = try container.decodeIfPresent(Date.self, forKey: .completedAt) {
            endDate = ca
        } else if let ed = try container.decodeIfPresent(Date.self, forKey: .endDate) {
            endDate = ed
        } else {
            endDate = Date.distantFuture
        }

        enabledDays = try container.decodeIfPresent(String.self, forKey: .enabledDays)
        smsTime = try container.decodeIfPresent(String.self, forKey: .smsTime)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        requireResponse = try container.decodeIfPresent(Bool.self, forKey: .requireResponse)
        currentLessonId = try container.decodeIfPresent(String.self, forKey: .currentLessonId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        studyProgram = try container.decodeIfPresent(StudyProgramSummary.self, forKey: .studyProgram)
        _isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    // MARK: - Custom Encoder

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(studyProgramId, forKey: .programId)
        try container.encode(studyProgramId, forKey: .studyProgramId)
        try container.encode(startDate, forKey: .startedAt)
        try container.encode(startDate, forKey: .startDate)
        if endDate != Date.distantFuture {
            try container.encode(endDate, forKey: .completedAt)
            try container.encode(endDate, forKey: .endDate)
        }
        try container.encodeIfPresent(enabledDays, forKey: .enabledDays)
        try container.encodeIfPresent(smsTime, forKey: .smsTime)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(requireResponse, forKey: .requireResponse)
        try container.encodeIfPresent(currentLessonId, forKey: .currentLessonId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(studyProgram, forKey: .studyProgram)
        try container.encodeIfPresent(_isActive, forKey: .isActive)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        groupId: String,
        studyProgramId: String,
        startDate: Date,
        endDate: Date,
        enabledDays: String? = nil,
        smsTime: String? = nil,
        timezone: String? = nil,
        requireResponse: Bool? = nil,
        currentLessonId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        studyProgram: StudyProgramSummary? = nil,
        isActive: Bool? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.studyProgramId = studyProgramId
        self.startDate = startDate
        self.endDate = endDate
        self.enabledDays = enabledDays
        self.smsTime = smsTime
        self.timezone = timezone
        self.requireResponse = requireResponse
        self.currentLessonId = currentLessonId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.studyProgram = studyProgram
        self._isActive = isActive
    }

    /// Whether the enrollment is active
    var isActive: Bool {
        return _isActive ?? (endDate > Date())
    }

    /// Whether the enrollment is completed
    var isCompleted: Bool {
        return !isActive
    }

    /// Formatted date range string (e.g., "DEC 1 - FEB 22")
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = formatter.string(from: endDate).uppercased()
        return "\(start) - \(end)"
    }
}

/// Summary of a study program (included in enrollment responses)
///
/// Supports both new API format (title, lessonCount) and legacy (name, days).
struct StudyProgramSummary: Codable {
    let id: String
    let name: String
    let description: String?
    let days: Int?
    let coverImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, title, description, days, lessonCount, coverImageUrl
        case isPublished
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)

        // name: try "title" (new API) first, fall back to "name" (cached)
        if let t = try container.decodeIfPresent(String.self, forKey: .title) {
            name = t
        } else {
            name = try container.decode(String.self, forKey: .name)
        }

        description = try container.decodeIfPresent(String.self, forKey: .description)

        // days: try "days" (cached) first, then "lessonCount" (new API)
        if let d = try container.decodeIfPresent(Int.self, forKey: .days) {
            days = d
        } else {
            days = try container.decodeIfPresent(Int.self, forKey: .lessonCount)
        }

        coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .title)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(days, forKey: .days)
        try container.encodeIfPresent(coverImageUrl, forKey: .coverImageUrl)
    }

    init(id: String, name: String, description: String? = nil, days: Int? = nil, coverImageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.days = days
        self.coverImageUrl = coverImageUrl
    }
}

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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: scheduledDate).uppercased()
    }

    /// Day of month (e.g., "1", "15")
    var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: scheduledDate)
    }
}

/// Full enrollment details with lesson schedules
///
/// Supports both new API format (programId, startedAt, completedAt) and legacy format.
struct EnrollmentDetails: Codable, Identifiable {
    let id: String
    let groupId: String
    var studyProgramId: String
    var startDate: Date
    var endDate: Date
    var enabledDays: String?
    var smsTime: String?
    var timezone: String?
    var requireResponse: Bool?
    var currentLessonId: String?
    var createdAt: Date?
    var updatedAt: Date?
    let studyProgram: StudyProgramSummary?
    var lessonSchedules: [LessonSchedule]
    private var _isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, groupId
        case studyProgramId, programId
        case startDate, startedAt
        case endDate, completedAt
        case enabledDays, smsTime, timezone, requireResponse
        case currentLessonId
        case createdAt, updatedAt
        case studyProgram, lessonSchedules
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)

        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decode(String.self, forKey: .studyProgramId)
        }

        if let sa = try container.decodeIfPresent(Date.self, forKey: .startedAt) {
            startDate = sa
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }

        if let ca = try container.decodeIfPresent(Date.self, forKey: .completedAt) {
            endDate = ca
        } else if let ed = try container.decodeIfPresent(Date.self, forKey: .endDate) {
            endDate = ed
        } else {
            endDate = Date.distantFuture
        }

        enabledDays = try container.decodeIfPresent(String.self, forKey: .enabledDays)
        smsTime = try container.decodeIfPresent(String.self, forKey: .smsTime)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        requireResponse = try container.decodeIfPresent(Bool.self, forKey: .requireResponse)
        currentLessonId = try container.decodeIfPresent(String.self, forKey: .currentLessonId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        studyProgram = try container.decodeIfPresent(StudyProgramSummary.self, forKey: .studyProgram)
        lessonSchedules = try container.decodeIfPresent([LessonSchedule].self, forKey: .lessonSchedules) ?? []
        _isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(studyProgramId, forKey: .programId)
        try container.encode(studyProgramId, forKey: .studyProgramId)
        try container.encode(startDate, forKey: .startedAt)
        try container.encode(startDate, forKey: .startDate)
        if endDate != Date.distantFuture {
            try container.encode(endDate, forKey: .completedAt)
            try container.encode(endDate, forKey: .endDate)
        }
        try container.encodeIfPresent(enabledDays, forKey: .enabledDays)
        try container.encodeIfPresent(smsTime, forKey: .smsTime)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(requireResponse, forKey: .requireResponse)
        try container.encodeIfPresent(currentLessonId, forKey: .currentLessonId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(studyProgram, forKey: .studyProgram)
        try container.encode(lessonSchedules, forKey: .lessonSchedules)
        try container.encodeIfPresent(_isActive, forKey: .isActive)
    }

    // MARK: - Memberwise Init

    init(
        id: String,
        groupId: String,
        studyProgramId: String,
        startDate: Date,
        endDate: Date,
        enabledDays: String? = nil,
        smsTime: String? = nil,
        timezone: String? = nil,
        requireResponse: Bool? = nil,
        currentLessonId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        studyProgram: StudyProgramSummary? = nil,
        lessonSchedules: [LessonSchedule] = [],
        isActive: Bool? = nil
    ) {
        self.id = id
        self.groupId = groupId
        self.studyProgramId = studyProgramId
        self.startDate = startDate
        self.endDate = endDate
        self.enabledDays = enabledDays
        self.smsTime = smsTime
        self.timezone = timezone
        self.requireResponse = requireResponse
        self.currentLessonId = currentLessonId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.studyProgram = studyProgram
        self.lessonSchedules = lessonSchedules
        self._isActive = isActive
    }

    /// Whether the enrollment is active
    var isActive: Bool {
        return _isActive ?? (endDate > Date())
    }

    /// Formatted date range string (e.g., "DEC 1 - FEB 22")
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = formatter.string(from: endDate).uppercased()
        return "\(start) - \(end)"
    }
}

// MARK: - Program Enrollment Models

/// Enrollment with group details (for program enrollments list)
///
/// Supports both new API format (programId, startedAt, completedAt) and legacy format.
struct ProgramEnrollment: Codable, Identifiable, Equatable {
    let id: String
    let groupId: String
    var studyProgramId: String
    var startDate: Date
    var endDate: Date
    var enabledDays: String?
    var smsTime: String?
    var timezone: String?
    var requireResponse: Bool?
    var currentLessonId: String?
    var createdAt: Date?
    var updatedAt: Date?
    let group: ProgramEnrollmentGroup?
    private var _isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, groupId
        case studyProgramId, programId
        case startDate, startedAt
        case endDate, completedAt
        case enabledDays, smsTime, timezone, requireResponse
        case currentLessonId
        case createdAt, updatedAt
        case group
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        groupId = try container.decode(String.self, forKey: .groupId)

        if let pid = try container.decodeIfPresent(String.self, forKey: .programId) {
            studyProgramId = pid
        } else {
            studyProgramId = try container.decode(String.self, forKey: .studyProgramId)
        }

        if let sa = try container.decodeIfPresent(Date.self, forKey: .startedAt) {
            startDate = sa
        } else {
            startDate = try container.decode(Date.self, forKey: .startDate)
        }

        if let ca = try container.decodeIfPresent(Date.self, forKey: .completedAt) {
            endDate = ca
        } else if let ed = try container.decodeIfPresent(Date.self, forKey: .endDate) {
            endDate = ed
        } else {
            endDate = Date.distantFuture
        }

        enabledDays = try container.decodeIfPresent(String.self, forKey: .enabledDays)
        smsTime = try container.decodeIfPresent(String.self, forKey: .smsTime)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
        requireResponse = try container.decodeIfPresent(Bool.self, forKey: .requireResponse)
        currentLessonId = try container.decodeIfPresent(String.self, forKey: .currentLessonId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        group = try container.decodeIfPresent(ProgramEnrollmentGroup.self, forKey: .group)
        _isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(studyProgramId, forKey: .programId)
        try container.encode(studyProgramId, forKey: .studyProgramId)
        try container.encode(startDate, forKey: .startedAt)
        try container.encode(startDate, forKey: .startDate)
        if endDate != Date.distantFuture {
            try container.encode(endDate, forKey: .completedAt)
            try container.encode(endDate, forKey: .endDate)
        }
        try container.encodeIfPresent(enabledDays, forKey: .enabledDays)
        try container.encodeIfPresent(smsTime, forKey: .smsTime)
        try container.encodeIfPresent(timezone, forKey: .timezone)
        try container.encodeIfPresent(requireResponse, forKey: .requireResponse)
        try container.encodeIfPresent(currentLessonId, forKey: .currentLessonId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(group, forKey: .group)
        try container.encodeIfPresent(_isActive, forKey: .isActive)
    }

    /// Whether the enrollment is active
    var isActive: Bool {
        return _isActive ?? (endDate > Date())
    }

    /// Formatted date range string (e.g., "JAN 1 - FEB 1")
    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = formatter.string(from: endDate).uppercased()
        return "\(start) - \(end)"
    }

    static func == (lhs: ProgramEnrollment, rhs: ProgramEnrollment) -> Bool {
        lhs.id == rhs.id
    }
}

/// Group details in program enrollment
struct ProgramEnrollmentGroup: Codable, Equatable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let _count: GroupMemberCount?
}

/// Member count for group
struct GroupMemberCount: Codable, Equatable {
    let members: Int
}

// MARK: - Unenroll Info

/// Information about an enrollment's status for the unenroll flow
struct UnenrollInfo: Codable {
    let enrollmentId: String
    let programName: String
    let totalLessons: Int
    let lessonsWithData: Int
    let cleanLessons: Int
    let canFullyUnenroll: Bool   // true when lessonsWithData == 0
}

// MARK: - Generic JSON Value

/// A type-erased JSON value for decoding arbitrary JSON structures.
enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Text Theme Models

/// A text rendering theme that controls how content is displayed
struct TextTheme: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let isSystem: Bool
    /// Raw JSON string of the theme definition, for passing to WKWebView
    let definitionJSON: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, isSystem, definition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false

        // Decode definition as raw JSON string for web view injection
        if let jsonValue = try? container.decodeIfPresent(JSONValue.self, forKey: .definition) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(jsonValue) {
                definitionJSON = String(data: data, encoding: .utf8)
            } else {
                definitionJSON = nil
            }
        } else {
            definitionJSON = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isSystem, forKey: .isSystem)
        // Re-encode definitionJSON back to a JSON value for the definition key
        if let jsonStr = definitionJSON, let data = jsonStr.data(using: .utf8),
           let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) {
            try container.encode(jsonValue, forKey: .definition)
        }
    }

    init(id: String, name: String, slug: String, description: String? = nil, isSystem: Bool = false, definitionJSON: String? = nil) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.isSystem = isSystem
        self.definitionJSON = definitionJSON
    }
}

// MARK: - Enrollment Errors

enum EnrollmentError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage enrollments."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}

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

// MARK: - Tag-Count Models

/// Single tag with its usage count, returned by /api/programs/tags and
/// /api/media/tags. Drives the chip rows inside the tags filter dropdown.
struct TagCount: Codable, Identifiable, Hashable {
    let tag: String
    let count: Int
    var id: String { tag }
}

struct TagsResponse: Codable {
    let success: Bool
    let tags: [TagCount]?
    let error: String?
}
