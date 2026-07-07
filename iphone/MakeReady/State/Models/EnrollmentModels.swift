//
//  EnrollmentModels.swift
//  MakeReady
//
//  Enrollment models: group/program enrollments, completion stats, unenroll info, errors.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

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
        let start = ModelFormatters.monthDay.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = ModelFormatters.monthDay.string(from: endDate).uppercased()
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
        let start = ModelFormatters.monthDay.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = ModelFormatters.monthDay.string(from: endDate).uppercased()
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
        let start = ModelFormatters.monthDay.string(from: startDate).uppercased()
        guard endDate != Date.distantFuture else { return start }
        let end = ModelFormatters.monthDay.string(from: endDate).uppercased()
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
    let creator: ProgramEnrollmentGroupCreator?
}

/// The group's leader (creator) summary, used to surface the leader's name.
struct ProgramEnrollmentGroupCreator: Codable, Equatable {
    let name: String?
}

/// Member count for group
struct GroupMemberCount: Codable, Equatable {
    let members: Int
}

// MARK: - Enrollment Completion Analytics

/// Group-completion counts for one enrollment, from
/// `GET /api/enrollments/:id/completion-stats`. `memberCount` is the fraction
/// denominator; per-activity/per-lesson counts are distinct members completed.
struct EnrollmentCompletionStats: Codable, Equatable {
    let memberCount: Int
    let lessons: [LessonCompletionStat]
}

struct LessonCompletionStat: Codable, Equatable {
    let lessonScheduleId: String
    let completedCount: Int
    let activities: [ActivityCompletionStat]
}

struct ActivityCompletionStat: Codable, Equatable {
    let scheduledActivityId: String
    let completedCount: Int
}

// MARK: - Study Sync (enrollment ↔ program version tracking)

/// How an enrollment tracks curriculum updates published to its study program.
/// Raw values match the server's `EnrollmentSyncMode` enum.
enum EnrollmentSyncMode: String, Codable, Equatable {
    case off = "OFF"            // frozen copy (legacy behavior)
    case auto = "AUTO"          // published updates apply immediately
    case approval = "APPROVAL"  // leader approves before updates apply
}

/// Sync status for one enrollment, from `GET /api/enrollments/:id/sync`.
/// `hasDrift` = the program has published versions this enrollment hasn't
/// received; `pendingVersions` carry the AI change summaries (newest first).
struct EnrollmentSyncStatus: Codable, Equatable {
    let syncMode: EnrollmentSyncMode
    let syncedProgramVersionNumber: Int?
    let currentVersionNumber: Int?
    let hasDrift: Bool
    let pendingVersions: [ProgramPendingVersion]
}

/// One published program version an enrollment hasn't received yet.
struct ProgramPendingVersion: Codable, Equatable {
    let versionNumber: Int
    let publishedAt: Date
    let changeSummary: String?
}

/// One pending lesson change from `GET /api/enrollments/:id/sync/changes` —
/// a row on the Review Changes screen. `key` is the selection token for
/// POST /sync/apply { lessonKeys }.
struct PendingLessonChange: Codable, Equatable, Identifiable {
    let key: String
    let type: ChangeType
    let dayNumber: Int?
    let title: String?
    let scheduledDate: Date?
    let titleChanged: Bool
    let activities: ActivityCounts?

    var id: String { key }

    enum ChangeType: String, Codable {
        case new
        case updated
        case removed
    }

    struct ActivityCounts: Codable, Equatable {
        let added: Int
        let updated: Int
        let removed: Int
    }
}

/// Quantified totals + per-lesson rows for one enrollment's pending changes.
struct EnrollmentPendingChanges: Codable, Equatable {
    let targetVersionNumber: Int?
    let hasPending: Bool
    let changes: [PendingLessonChange]
    let counts: Counts

    struct Counts: Codable, Equatable {
        let lessonsNew: Int
        let lessonsUpdated: Int
        let lessonsRemoved: Int
        let activitiesNew: Int
        let activitiesUpdated: Int
        let activitiesRemoved: Int
    }
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
