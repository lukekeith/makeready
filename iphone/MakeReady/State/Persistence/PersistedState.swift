//
//  PersistedState.swift
//  MakeReady
//
//  Codable snapshot of app state for disk persistence.
//  This is what gets serialized to/from JSON on disk.
//

import Foundation

/// Codable snapshot of all entity stores for disk persistence.
/// Contains raw entity arrays (not EntityStore objects) for simpler serialization.
struct PersistedState: Codable {

    // MARK: - Entity Data

    /// Study programs
    var programs: [StudyProgram]

    /// User groups
    var groups: [UserGroup]

    /// Enrollments (with study program details)
    var enrollments: [EnrollmentWithProgram]

    /// Videos
    var videos: [Video]

    /// Group posts (keyed by groupId for efficient lookup)
    var postsByGroup: [String: [GroupPost]]

    /// Group members (keyed by groupId)
    var membersByGroup: [String: [GroupMember]]

    /// Lessons (keyed by programId) - for loaded program details
    var lessonsByProgram: [String: [Lesson]]

    /// Activities (keyed by lessonId) - for lesson details
    var activitiesByLesson: [String: [StudyActivity]]

    /// Scheduled lessons (full aggregates with their activities + readBlocks +
    /// sourceReferences inlined). The single source of truth for scheduled-side
    /// data — keyed by `LessonWithActivities.id`.
    var scheduledLessons: [LessonWithActivities]

    /// Program enrollments (keyed by programId) - for program detail views
    var programEnrollmentsByProgram: [String: [ProgramEnrollment]]

    /// Lesson templates
    var templates: [LessonTemplate]

    /// Media library items
    var mediaLibrary: [MediaLibraryItem]

    /// Text themes available for read-block rendering. Persisted so the
    /// theme picker + Edit Theme page can render from cache on next launch
    /// before the network refresh lands.
    var textThemes: [TextTheme]

    /// Organization ID
    var organizationId: String?

    // MARK: - Relationship Indexes

    /// Program ID → Enrollment IDs
    var programEnrollmentIndex: [String: [String]]

    /// Group ID → Enrollment IDs
    var groupEnrollmentIndex: [String: [String]]

    /// Program ID → Lesson IDs
    var programLessonIndex: [String: [String]]

    /// Lesson ID → Activity IDs
    var lessonActivityIndex: [String: [String]]

    /// Program ID → ProgramEnrollment IDs
    var programProgramEnrollmentIndex: [String: [String]]

    // MARK: - Home Stats

    /// Cached heatmap data
    var homeHeatmapData: [HeatmapBucket]

    /// Cached weekly activity data
    var homeWeeklyActivity: [DayActivityCount]

    /// Cached total members count
    var homeTotalMembers: Int

    /// Cached total groups count
    var homeTotalGroups: Int

    // MARK: - Calendar Data

    /// Cached calendar events keyed by date string
    var calendarEvents: [String: [SplitCalendarEvent]]

    // MARK: - Metadata

    /// When this state was persisted
    var persistedAt: Date

    /// Schema version for future migrations
    var schemaVersion: Int

    // MARK: - Initialization

    /// Create empty persisted state
    init() {
        self.programs = []
        self.groups = []
        self.enrollments = []
        self.videos = []
        self.postsByGroup = [:]
        self.membersByGroup = [:]
        self.lessonsByProgram = [:]
        self.activitiesByLesson = [:]
        self.scheduledLessons = []
        self.programEnrollmentsByProgram = [:]
        self.templates = []
        self.mediaLibrary = []
        self.textThemes = []
        self.organizationId = nil
        self.programEnrollmentIndex = [:]
        self.groupEnrollmentIndex = [:]
        self.programLessonIndex = [:]
        self.lessonActivityIndex = [:]
        self.programProgramEnrollmentIndex = [:]
        self.homeHeatmapData = []
        self.homeWeeklyActivity = []
        self.homeTotalMembers = 0
        self.homeTotalGroups = 0
        self.calendarEvents = [:]
        self.persistedAt = Date()
        self.schemaVersion = 1
    }

    /// Create from current AppState
    init(from appState: AppState) {
        self.programs = appState.programs.all
        self.groups = appState.groups.all
        self.enrollments = appState.enrollments.all
        self.videos = appState.videos.all

        // Posts and members are stored per-group
        var posts: [String: [GroupPost]] = [:]
        var members: [String: [GroupMember]] = [:]
        for groupId in appState.groupPostIndex.allParentIds {
            let postIds = appState.groupPostIndex.get(groupId)
            posts[groupId] = postIds.compactMap { appState.posts[$0] }
        }
        for groupId in appState.groupMemberIndex.allParentIds {
            let memberIds = appState.groupMemberIndex.get(groupId)
            members[groupId] = memberIds.compactMap { appState.members[$0] }
        }
        self.postsByGroup = posts
        self.membersByGroup = members

        // Lessons are stored per-program
        var lessons: [String: [Lesson]] = [:]
        for programId in appState.programLessonIndex.allParentIds {
            let lessonIds = appState.programLessonIndex.get(programId)
            lessons[programId] = lessonIds.compactMap { appState.lessons[$0] }
        }
        self.lessonsByProgram = lessons

        // Activities are stored per-lesson
        var activities: [String: [StudyActivity]] = [:]
        for lessonId in appState.lessonActivityIndex.allParentIds {
            let activityIds = appState.lessonActivityIndex.get(lessonId)
            activities[lessonId] = activityIds.compactMap { appState.activities[$0] }
        }
        self.activitiesByLesson = activities

        // Scheduled lessons are stored as full aggregates with their activities,
        // readBlocks, and sourceReferences inline.
        self.scheduledLessons = appState.scheduledLessons.all

        // Program enrollments are stored per-program
        var programEnrollments: [String: [ProgramEnrollment]] = [:]
        for programId in appState.programProgramEnrollmentIndex.allParentIds {
            let enrollmentIds = appState.programProgramEnrollmentIndex.get(programId)
            programEnrollments[programId] = enrollmentIds.compactMap { appState.programEnrollments[$0] }
        }
        self.programEnrollmentsByProgram = programEnrollments

        // Templates
        self.templates = appState.templates.all

        // Media library
        self.mediaLibrary = appState.mediaLibrary.all
        self.textThemes = appState.textThemes
        self.organizationId = appState.organizationId

        // Serialize relationship indexes
        self.programEnrollmentIndex = appState.programEnrollmentIndex.toDictionary()
        self.groupEnrollmentIndex = appState.groupEnrollmentIndex.toDictionary()
        self.programLessonIndex = appState.programLessonIndex.toDictionary()
        self.lessonActivityIndex = appState.lessonActivityIndex.toDictionary()
        self.programProgramEnrollmentIndex = appState.programProgramEnrollmentIndex.toDictionary()

        self.homeHeatmapData = appState.homeHeatmapData
        self.homeWeeklyActivity = appState.homeWeeklyActivity
        self.homeTotalMembers = appState.homeTotalMembers
        self.homeTotalGroups = appState.homeTotalGroups

        self.calendarEvents = appState.calendarEvents

        self.persistedAt = Date()
        self.schemaVersion = 1
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case programs
        case groups
        case enrollments
        case videos
        case postsByGroup
        case membersByGroup
        case lessonsByProgram
        case activitiesByLesson
        case scheduledLessons
        case programEnrollmentsByProgram
        case templates
        case mediaLibrary
        case textThemes
        case organizationId
        case programEnrollmentIndex
        case groupEnrollmentIndex
        case programLessonIndex
        case lessonActivityIndex
        case programProgramEnrollmentIndex
        case homeHeatmapData
        case homeWeeklyActivity
        case homeTotalMembers
        case homeTotalGroups
        case calendarEvents
        case persistedAt
        case schemaVersion
    }

    // MARK: - Custom Decoding (for backwards compatibility)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Required fields
        self.programs = try container.decode([StudyProgram].self, forKey: .programs)
        self.groups = try container.decode([UserGroup].self, forKey: .groups)
        self.enrollments = try container.decode([EnrollmentWithProgram].self, forKey: .enrollments)
        self.videos = try container.decode([Video].self, forKey: .videos)
        self.postsByGroup = try container.decode([String: [GroupPost]].self, forKey: .postsByGroup)
        self.membersByGroup = try container.decode([String: [GroupMember]].self, forKey: .membersByGroup)
        self.lessonsByProgram = try container.decode([String: [Lesson]].self, forKey: .lessonsByProgram)
        self.programEnrollmentIndex = try container.decode([String: [String]].self, forKey: .programEnrollmentIndex)
        self.groupEnrollmentIndex = try container.decode([String: [String]].self, forKey: .groupEnrollmentIndex)
        self.programLessonIndex = try container.decode([String: [String]].self, forKey: .programLessonIndex)
        self.persistedAt = try container.decode(Date.self, forKey: .persistedAt)
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)

        // Optional fields (for backwards compatibility with older persisted states)
        self.activitiesByLesson = try container.decodeIfPresent([String: [StudyActivity]].self, forKey: .activitiesByLesson) ?? [:]
        self.scheduledLessons = try container.decodeIfPresent([LessonWithActivities].self, forKey: .scheduledLessons) ?? []
        self.lessonActivityIndex = try container.decodeIfPresent([String: [String]].self, forKey: .lessonActivityIndex) ?? [:]
        self.programEnrollmentsByProgram = try container.decodeIfPresent([String: [ProgramEnrollment]].self, forKey: .programEnrollmentsByProgram) ?? [:]
        self.programProgramEnrollmentIndex = try container.decodeIfPresent([String: [String]].self, forKey: .programProgramEnrollmentIndex) ?? [:]
        self.templates = try container.decodeIfPresent([LessonTemplate].self, forKey: .templates) ?? []

        // Media library (optional for backwards compatibility)
        self.mediaLibrary = try container.decodeIfPresent([MediaLibraryItem].self, forKey: .mediaLibrary) ?? []
        self.textThemes = try container.decodeIfPresent([TextTheme].self, forKey: .textThemes) ?? []
        self.organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)

        // Home stats (optional for backwards compatibility)
        self.homeHeatmapData = try container.decodeIfPresent([HeatmapBucket].self, forKey: .homeHeatmapData) ?? []
        self.homeWeeklyActivity = try container.decodeIfPresent([DayActivityCount].self, forKey: .homeWeeklyActivity) ?? []
        self.homeTotalMembers = try container.decodeIfPresent(Int.self, forKey: .homeTotalMembers) ?? 0
        self.homeTotalGroups = try container.decodeIfPresent(Int.self, forKey: .homeTotalGroups) ?? 0

        // Calendar events (optional for backwards compatibility)
        self.calendarEvents = try container.decodeIfPresent([String: [SplitCalendarEvent]].self, forKey: .calendarEvents) ?? [:]
    }
}

// Note: RelationshipIndex serialization helpers are defined in RelationshipIndex.swift
