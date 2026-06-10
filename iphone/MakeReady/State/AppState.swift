//
//  AppState.swift
//  MakeReady
//
//  Central @Observable store holding all normalized app data.
//  Provides fine-grained reactivity - only views accessing changed properties re-render.
//
//  Architecture:
//  - Entity stores hold normalized data (programs, groups, enrollments, etc.)
//  - Relationship indexes map parent→child relationships
//  - Loading states track per-entity and per-list loading status
//  - Persistence layer saves/loads from disk for instant UI on app launch
//

import Foundation

/// Distinguishes between program-side data (StudyActivity in `state.activities`)
/// and enrollment-side data (ScheduledActivity inside `state.scheduledLessons`).
/// Used by helper methods that return data for either context.
enum LessonContext {
    case program
    case enrollment
}

/// A recorded, user-relevant failure. Top-level (not nested in AppState)
/// so the type itself carries no actor isolation.
/// Rendering these is a deliberate no-op until the error-surface UI is
/// approved (Decision Point A) — recording happens now so failures stop
/// vanishing into logs.
struct AppError: Identifiable {
    let id = UUID()
    /// Where the failure happened, e.g. "GroupActions.loadGroups"
    let context: String
    /// Human-readable description (error.localizedDescription)
    let message: String
    let occurredAt = Date()
}

/// Central observable state store for the entire app.
/// Uses @Observable for fine-grained reactivity (iOS 17+).
/// Main-actor isolated: every read and mutation happens on the main thread,
/// enforced by the compiler. Background work (uploads, encoding) must hop
/// via `await MainActor.run` / `Task { @MainActor in }` to touch state.
@MainActor
@Observable
final class AppState {

    // MARK: - Singleton

    /// Shared instance - use this throughout the app.
    /// Writable so the capture test target can replace with a fresh instance.
    static var shared = AppState()

    // MARK: - Entity Stores

    /// Study programs
    let programs = EntityStore<StudyProgram>()

    /// User groups
    let groups = EntityStore<UserGroup>()

    /// Enrollments (with study program details)
    let enrollments = EntityStore<EnrollmentWithProgram>()

    /// Videos in user's library
    let videos = EntityStore<Video>()

    /// Group posts
    let posts = EntityStore<GroupPost>()

    /// Group members
    let members = EntityStore<GroupMember>()

    /// Lessons (loaded per-program)
    let lessons = EntityStore<Lesson>()

    /// Study activities (within lessons)
    let activities = EntityStore<StudyActivity>()

    /// Scheduled lessons (the per-enrollment, dated copies of program lessons).
    /// Holds the **whole** LessonWithActivities aggregate — every read block,
    /// every source reference, every order number is owned here. Mutations
    /// happen by reading this lesson, mutating its `activities[]` inline, and
    /// upserting back. This is the single source of truth for everything
    /// scheduled-side: editor screens, calendar cards, Bible reader highlights.
    let scheduledLessons = EntityStore<LessonWithActivities>()

    /// Program enrollments (enrollments viewed from program perspective, includes group details)
    let programEnrollments = EntityStore<ProgramEnrollment>()

    /// Lesson templates
    let templates = EntityStore<LessonTemplate>()

    /// Media library items
    let mediaLibrary = EntityStore<MediaLibraryItem>()

    /// Organization ID (needed for media library API). Mirrors the first
    /// entry of `userOrganizations` for callers that only need the primary org.
    var organizationId: String?

    /// All organizations the user belongs to. Drives the per-org buttons in
    /// UserMenu and the Org Home page. Loaded by `loadOrganization()`. Today
    /// the server only exposes the org the user owns; when multi-org listing
    /// is added server-side, this array grows without UI changes.
    var userOrganizations: [OrganizationData] = []

    /// Preview URL template returned by GET /api/themes.
    /// Contains the literal `{activityId}` placeholder the app substitutes
    /// when opening the canonical web preview inside a WKWebView.
    /// e.g. `https://app.makeready.org/preview/activity/{activityId}`
    var previewUrlTemplate: String?

    /// Text themes available for read-block rendering. Loaded once at
    /// startup (`loadInitialData`) and persisted so downstream UI — theme
    /// picker, Edit Theme page, swatches — can read synchronously without
    /// each surface paying for a network round-trip on first open.
    /// Ordered: "No Theme" (slug "none") first, then alphabetical by name.
    var textThemes: [TextTheme] = []

    /// Lookup a theme by id. O(n), but n is small (~6 themes).
    func theme(id: String?) -> TextTheme? {
        guard let id else { return nil }
        return textThemes.first { $0.id == id }
    }

    /// Total media count from server (for pagination)
    var mediaLibraryTotal: Int = 0

    /// Bible translations
    var bibleTranslations: [BibleVersion] = knownBibleVersions

    /// Currently selected Bible translation code (persisted to UserDefaults)
    var selectedBibleTranslation: String = UserDefaults.standard.string(forKey: "selectedBibleTranslation") ?? "KJV" {
        didSet {
            UserDefaults.standard.set(selectedBibleTranslation, forKey: "selectedBibleTranslation")
        }
    }

    /// In-app notifications
    let notifications = EntityStore<AppNotification>()

    // MARK: - Relationship Indexes

    /// Program ID → Enrollment IDs (which groups are enrolled in a program)
    let programEnrollmentIndex = RelationshipIndex()

    /// Group ID → Enrollment IDs (which programs a group is enrolled in)
    let groupEnrollmentIndex = RelationshipIndex()

    /// Program ID → Lesson IDs
    let programLessonIndex = RelationshipIndex()

    /// Lesson ID → Activity IDs
    let lessonActivityIndex = RelationshipIndex()

    /// Program ID → ProgramEnrollment IDs (enrollments with group details)
    let programProgramEnrollmentIndex = RelationshipIndex()

    /// Group ID → Post IDs
    let groupPostIndex = RelationshipIndex()

    /// Group ID → Member IDs
    let groupMemberIndex = RelationshipIndex()

    // MARK: - Join Requests

    /// Pending join requests keyed by group ID. Populated by
    /// `GroupActions.loadJoinRequests(groupId:)` and read by surfaces that
    /// show a "this group has pending requests" indicator (e.g. the red dot
    /// on group cards and the `person.2` icon in the group-home header).
    var pendingJoinRequestsByGroupId: [String: [JoinRequest]] = [:]

    /// True when the given group has at least one pending join request in
    /// the cache. The endpoint we hit (`/api/groups/:groupId/join-requests`)
    /// returns only pending requests, so any non-empty array means "show the
    /// dot." Callers that want stricter filtering can use the array directly.
    func hasPendingJoinRequests(forGroupId groupId: String) -> Bool {
        guard let requests = pendingJoinRequestsByGroupId[groupId] else { return false }
        return !requests.isEmpty
    }

    // MARK: - Loading States

    /// Per-entity and per-list loading states
    let loadingStates = LoadingStateManager()

    // MARK: - Error Channel

    /// Recent recorded failures, newest last, capped at `maxRecordedErrors`.
    /// No UI renders these yet (Decision Point A) — the queue exists so
    /// Actions stop swallowing errors into logs only.
    private(set) var errors: [AppError] = []

    private let maxRecordedErrors = 50

    /// Record a failure into the error channel (and log it). The single
    /// write path for error recording — when the visible error surface
    /// lands, it observes `errors` and nothing else changes.
    func recordError(_ error: Error, context: String) {
        errors.append(AppError(context: context, message: error.localizedDescription))
        if errors.count > maxRecordedErrors {
            errors.removeFirst(errors.count - maxRecordedErrors)
        }
        NSLog("❌ \(context): \(error.localizedDescription)")
    }

    /// Drop all recorded errors (e.g. once a future surface has shown them).
    func clearErrors() {
        errors = []
    }

    // MARK: - Home Stats

    /// Heatmap data (activity by day/hour)
    var homeHeatmapData: [HeatmapBucket] = []

    /// Weekly activity data (last 7 days)
    var homeWeeklyActivity: [DayActivityCount] = []

    /// Total unique members across all groups
    var homeTotalMembers: Int = 0

    /// Total groups count
    var homeTotalGroups: Int = 0

    /// Whether home stats have been loaded at least once
    var homeStatsLoaded: Bool = false

    // MARK: - Calendar Data

    /// Scheduled lesson events keyed by date string ("yyyy-MM-dd"), today and future only
    var calendarEvents: [String: [SplitCalendarEvent]] = [:]

    /// Whether calendar events have been loaded at least once
    var calendarEventsLoaded: Bool = false

    /// Lesson schedules keyed by schedule ID (for action menus)
    var lessonScheduleMap: [String: (schedule: LessonSchedule, studyName: String, enrollmentId: String)] = [:]

    // MARK: - Upload Progress

    /// Current video upload progress (if any)
    var uploadProgress: UploadProgress?

    // MARK: - Computed Properties (Ordered Lists)

    /// Programs sorted by most recently updated
    var orderedPrograms: [StudyProgram] {
        programs.all.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Groups sorted by most recently updated
    var orderedGroups: [UserGroup] {
        groups.all.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Videos sorted by most recently created
    var orderedVideos: [Video] {
        videos.all.sorted { $0.createdAt > $1.createdAt }
    }

    /// Media library items sorted by most recently created
    var orderedMedia: [MediaLibraryItem] {
        mediaLibrary.all.sorted { $0.createdAt > $1.createdAt }
    }

    /// Templates sorted alphabetically by name
    var orderedTemplates: [LessonTemplate] {
        templates.all.sorted { $0.name < $1.name }
    }

    /// Notifications sorted newest first
    var orderedNotifications: [AppNotification] {
        notifications.all.sorted { $0.createdAt > $1.createdAt }
    }

    /// Count of unread notifications
    var unreadNotificationCount: Int {
        notifications.all.filter { !$0.isRead }.count
    }

    /// Get enrollments for a specific group
    func enrollmentsFor(groupId: String) -> [EnrollmentWithProgram] {
        let enrollmentIds = groupEnrollmentIndex.get(groupId)
        return enrollments.getMany(enrollmentIds).sorted { $0.startDate > $1.startDate }
    }

    /// Get enrollments for a specific program
    func enrollmentsFor(programId: String) -> [EnrollmentWithProgram] {
        let enrollmentIds = programEnrollmentIndex.get(programId)
        return enrollments.getMany(enrollmentIds).sorted { $0.startDate > $1.startDate }
    }

    /// Get lessons for a specific program (ordered by day number)
    func lessonsFor(programId: String) -> [Lesson] {
        let lessonIds = programLessonIndex.get(programId)
        return lessons.getMany(lessonIds).sorted { $0.dayNumber < $1.dayNumber }
    }

    /// Get program activities for a specific lesson (ordered by orderNumber)
    func programActivitiesFor(lessonId: String) -> [StudyActivity] {
        let activityIds = lessonActivityIndex.get(lessonId)
        return activities.getMany(activityIds).sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Find the program-lesson id that contains the given activity id by scanning
    /// the lesson→activity index. Used when only an activity id is in hand and the
    /// activity's own `lessonId` field is unreliable (it's often nil in the store —
    /// the relationship lives in the index, not on the entity).
    func lessonIdContaining(activityId: String) -> String? {
        lessonActivityIndex.allParentIds.first {
            lessonActivityIndex.contains(parentId: $0, childId: activityId)
        }
    }

    /// Get scheduled activities for a specific scheduled lesson (ordered by orderNumber).
    /// Reads from the lesson aggregate — the activities live inline on the lesson value.
    func scheduledActivitiesFor(lessonId: String) -> [ScheduledActivity] {
        guard let lesson = scheduledLessons[lessonId] else { return [] }
        return lesson.activities.sorted { $0.orderNumber < $1.orderNumber }
    }

    /// Find the scheduled lesson id that contains the given activity id, by walking
    /// the small set of cached scheduled lessons. Used by EnrollmentActions write
    /// methods that only know an activity id but need to mutate the lesson aggregate.
    func scheduledLessonContaining(activityId: String) -> String? {
        for lesson in scheduledLessons.all {
            if lesson.activities.contains(where: { $0.id == activityId }) {
                return lesson.id
            }
        }
        return nil
    }

    /// Mutate a scheduled activity by id. Finds the lesson aggregate it lives on,
    /// applies the mutation to the activity in place, and upserts the lesson back.
    /// This is the single write path for any scheduled-activity change.
    @discardableResult
    func mutateScheduledActivity(activityId: String, _ mutate: (inout ScheduledActivity) -> Void) -> Bool {
        guard let lessonId = scheduledLessonContaining(activityId: activityId),
              var lesson = scheduledLessons[lessonId],
              let idx = lesson.activities.firstIndex(where: { $0.id == activityId }) else {
            return false
        }
        mutate(&lesson.activities[idx])
        scheduledLessons.upsert(lesson)
        return true
    }

    /// Replace a scheduled activity wholesale (e.g. with a fresh API response).
    /// Updates the lesson aggregate it lives on. Returns false if not found.
    @discardableResult
    func replaceScheduledActivity(_ activity: ScheduledActivity) -> Bool {
        return mutateScheduledActivity(activityId: activity.id) { existing in
            existing = activity
        }
    }

    /// Compute the union of Bible passages currently used in a lesson, derived
    /// from the lesson aggregate. For multi-block READ activities, only verses
    /// that are anchored to a live `readBlock.sourceReferenceId` count — bare
    /// `sourceReferences` without a block are treated as dangling and ignored.
    /// This matches the user mental model: a verse "exists" only if there's a
    /// block for it. Used by the Bible reader to highlight already-used verses.
    func passagesUsedIn(lessonId: String, context: LessonContext) -> [PassageData] {
        switch context {
        case .program:
            return programActivitiesFor(lessonId: lessonId).flatMap { activity -> [PassageData] in
                var results: [PassageData] = []
                // Legacy single-passage activities (SOAP, OIA, etc.)
                if let pd = activity.passageData {
                    results.append(pd)
                }
                // Multi-block READ activities: only verses anchored to a block.
                results.append(contentsOf: passagesFromBlocks(
                    blocks: activity.readBlocks,
                    references: activity.sourceReferences
                ))
                return results
            }
        case .enrollment:
            return scheduledActivitiesFor(lessonId: lessonId).flatMap { activity -> [PassageData] in
                passagesFromBlocks(
                    blocks: activity.readBlocks,
                    references: activity.sourceReferences
                )
            }
        }
    }

    /// Resolve verses from read blocks by following each block's
    /// `sourceReferenceId` to the matching `ActivitySourceReference`. Blocks
    /// without a source ref id (e.g. editable text blocks) are skipped, and
    /// references not pointed to by any block are ignored — that's how we drop
    /// dangling refs left over from a previous delete.
    private func passagesFromBlocks(
        blocks: [ActivityReadBlock]?,
        references: [ActivitySourceReference]?
    ) -> [PassageData] {
        guard let blocks, !blocks.isEmpty else { return [] }
        let refsById = Dictionary(uniqueKeysWithValues: (references ?? []).map { ($0.id, $0) })
        return blocks.compactMap { block -> PassageData? in
            guard let refId = block.sourceReferenceId, let ref = refsById[refId] else { return nil }
            return PassageData(from: ref)
        }
    }

    /// Get posts for a specific group (ordered by most recent)
    func postsFor(groupId: String) -> [GroupPost] {
        let postIds = groupPostIndex.get(groupId)
        return posts.getMany(postIds).sorted { $0.createdAt > $1.createdAt }
    }

    /// Get members for a specific group (ordered alphabetically)
    func membersFor(groupId: String) -> [GroupMember] {
        let memberIds = groupMemberIndex.get(groupId)
        return members.getMany(memberIds).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Get program enrollments for a specific program (ordered by start date)
    func programEnrollmentsFor(programId: String) -> [ProgramEnrollment] {
        let enrollmentIds = programProgramEnrollmentIndex.get(programId)
        return programEnrollments.getMany(enrollmentIds).sorted { $0.startDate > $1.startDate }
    }

    /// Whether we have cached program enrollments for a specific program
    func hasCachedProgramEnrollments(programId: String) -> Bool {
        !programProgramEnrollmentIndex.get(programId).isEmpty
    }

    // MARK: - Cache Status

    /// Whether we have any cached programs
    var hasCachedPrograms: Bool {
        !programs.isEmpty
    }

    /// Whether we have any cached groups
    var hasCachedGroups: Bool {
        !groups.isEmpty
    }

    /// Whether we have any cached videos
    var hasCachedVideos: Bool {
        !videos.isEmpty
    }

    /// Whether we have any cached media library items
    var hasCachedMedia: Bool {
        !mediaLibrary.isEmpty
    }

    /// Whether we have any cached templates
    var hasCachedTemplates: Bool {
        !templates.isEmpty
    }

    /// Whether we have cached home stats
    var hasCachedHomeStats: Bool {
        homeStatsLoaded
    }

    /// Whether we have cached calendar events
    var hasCachedCalendarEvents: Bool {
        calendarEventsLoaded
    }

    // MARK: - Initialization

    /// Internal init so the capture test target can create fresh instances.
    /// Production code uses `AppState.shared` exclusively.
    init() {
        loadFromDisk()
    }

    // MARK: - Persistence

    /// Load state from disk (synchronous, called on init)
    private func loadFromDisk() {
        guard let persisted = StatePersistence.shared.load() else {
            NSLog("📦 AppState: No persisted state, starting fresh")
            return
        }

        // Restore entity stores
        programs.replaceAll(persisted.programs)
        groups.replaceAll(persisted.groups)
        enrollments.replaceAll(persisted.enrollments)
        videos.replaceAll(persisted.videos)

        // Restore posts and members by group
        var allPosts: [GroupPost] = []
        var allMembers: [GroupMember] = []
        for (_, groupPosts) in persisted.postsByGroup {
            allPosts.append(contentsOf: groupPosts)
        }
        for (_, groupMembers) in persisted.membersByGroup {
            allMembers.append(contentsOf: groupMembers)
        }
        posts.replaceAll(allPosts)
        members.replaceAll(allMembers)

        // Restore lessons
        var allLessons: [Lesson] = []
        for (_, programLessons) in persisted.lessonsByProgram {
            allLessons.append(contentsOf: programLessons)
        }
        lessons.replaceAll(allLessons)

        // Restore activities
        var allActivities: [StudyActivity] = []
        for (_, lessonActivities) in persisted.activitiesByLesson {
            allActivities.append(contentsOf: lessonActivities)
        }
        activities.replaceAll(allActivities)

        // Restore scheduled lessons (full aggregates with their activities inline).
        scheduledLessons.replaceAll(persisted.scheduledLessons)

        // Restore program enrollments
        var allProgramEnrollments: [ProgramEnrollment] = []
        for (_, enrollmentList) in persisted.programEnrollmentsByProgram {
            allProgramEnrollments.append(contentsOf: enrollmentList)
        }
        programEnrollments.replaceAll(allProgramEnrollments)

        // Restore templates
        templates.replaceAll(persisted.templates)

        // Restore media library
        mediaLibrary.replaceAll(persisted.mediaLibrary)
        textThemes = persisted.textThemes
        organizationId = persisted.organizationId

        // Restore relationship indexes
        programEnrollmentIndex.loadFromDictionary(persisted.programEnrollmentIndex)
        groupEnrollmentIndex.loadFromDictionary(persisted.groupEnrollmentIndex)
        programLessonIndex.loadFromDictionary(persisted.programLessonIndex)
        lessonActivityIndex.loadFromDictionary(persisted.lessonActivityIndex)
        programProgramEnrollmentIndex.loadFromDictionary(persisted.programProgramEnrollmentIndex)

        // Rebuild post and member indexes from data
        for (groupId, _) in persisted.postsByGroup {
            let postIds = persisted.postsByGroup[groupId]?.map { $0.id } ?? []
            groupPostIndex.replace(parentId: groupId, childIds: postIds)
        }
        for (groupId, _) in persisted.membersByGroup {
            let memberIds = persisted.membersByGroup[groupId]?.map { $0.id } ?? []
            groupMemberIndex.replace(parentId: groupId, childIds: memberIds)
        }

        // Restore home stats
        homeHeatmapData = persisted.homeHeatmapData
        homeWeeklyActivity = persisted.homeWeeklyActivity
        homeTotalMembers = persisted.homeTotalMembers
        homeTotalGroups = persisted.homeTotalGroups
        homeStatsLoaded = !persisted.homeHeatmapData.isEmpty || !persisted.homeWeeklyActivity.isEmpty || persisted.homeTotalMembers > 0

        // Restore calendar events (filter out past dates on restore)
        let today = Calendar.current.startOfDay(for: Date())
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"
        calendarEvents = persisted.calendarEvents.filter { key, _ in
            guard let date = dateKeyFormatter.date(from: key) else { return false }
            return date >= today
        }
        calendarEventsLoaded = !calendarEvents.isEmpty

        NSLog("📦 AppState: Loaded from disk - \(programs.count) programs, \(groups.count) groups, \(lessons.count) lessons, \(activities.count) activities, \(scheduledLessons.count) scheduled lessons")
    }

    /// Save state to disk (async with debounce)
    func persist() {
        let state = PersistedState(from: self)
        StatePersistence.shared.save(state)
    }

    /// Save state immediately (for app backgrounding)
    func persistImmediately() {
        let state = PersistedState(from: self)
        StatePersistence.shared.saveImmediately(state)
    }

    /// Clear all state (for logout)
    func clearAllData() {
        clear()
    }

    /// Clear all state (for logout)
    private func clear() {
        programs.clear()
        groups.clear()
        enrollments.clear()
        videos.clear()
        posts.clear()
        members.clear()
        lessons.clear()
        activities.clear()
        programEnrollments.clear()
        templates.clear()
        notifications.clear()
        mediaLibrary.clear()
        organizationId = nil
        userOrganizations = []
        mediaLibraryTotal = 0

        programEnrollmentIndex.clear()
        groupEnrollmentIndex.clear()
        programLessonIndex.clear()
        lessonActivityIndex.clear()
        programProgramEnrollmentIndex.clear()
        groupPostIndex.clear()
        groupMemberIndex.clear()

        homeHeatmapData = []
        homeWeeklyActivity = []
        homeTotalMembers = 0
        homeTotalGroups = 0
        homeStatsLoaded = false

        calendarEvents = [:]
        calendarEventsLoaded = false
        lessonScheduleMap = [:]

        loadingStates.clearAll()
        errors = []

        StatePersistence.shared.clear()

        NSLog("📦 AppState: Cleared all state")
    }

    // MARK: - Initial Data Loading

    /// Whether initial data has been loaded this session
    private var hasLoadedInitialData = false

    /// Load all initial data from API. Called once when user is authenticated.
    /// Uses cache-first pattern: shows cached data immediately, refreshes in background.
    func loadInitialData() async {
        guard !hasLoadedInitialData else { return }
        hasLoadedInitialData = true

        NSLog("📦 AppState: Loading initial data...")

        // Load all data concurrently
        async let programsTask: () = loadPrograms()
        async let templatesTask: () = loadTemplates()
        async let notificationsTask: () = loadUnreadNotificationCount()
        async let orgTask: () = loadOrganization()
        async let translationsTask: () = loadBibleTranslations()
        async let themesTask: () = loadTextThemes()

        _ = await (programsTask, templatesTask, notificationsTask, orgTask, translationsTask, themesTask)

        NSLog("📦 AppState: Initial data load complete")
    }

    private func loadPrograms() async {
        do {
            try await ProgramActions().loadPrograms(forceRefresh: false)
        } catch {
            recordError(error, context: "AppState.loadPrograms")
        }
    }

    private func loadTemplates() async {
        do {
            try await ProgramActions().loadTemplates(forceRefresh: false)
        } catch {
            recordError(error, context: "AppState.loadTemplates")
        }
    }

    private func loadUnreadNotificationCount() async {
        do {
            try await NotificationActions().loadUnreadCount()
        } catch {
            recordError(error, context: "AppState.loadUnreadNotificationCount")
        }
    }

    private func loadOrganization() async {
        do {
            let response: OrganizationResponse = try await APIClient.shared.get(
                "/api/organizations/my/organization",
                responseType: OrganizationResponse.self
            )
            if let org = response.data {
                organizationId = org.id
                userOrganizations = [org]
                NSLog("📦 AppState: Loaded organization '\(org.name)' (\(org.id))")
            } else {
                userOrganizations = []
            }
        } catch {
            recordError(error, context: "AppState.loadOrganization")
        }
    }

    private func loadTextThemes() async {
        // Populate `textThemes` at startup so the Edit Theme page, theme
        // picker, and swatches render synchronously — previously each
        // surface re-fetched on first open, producing a visible flash.
        do {
            _ = try await ThemeActions().loadThemes()
        } catch {
            recordError(error, context: "AppState.loadTextThemes")
        }
    }

    private func loadBibleTranslations() async {
        do {
            let response: BibleTranslationsResponse = try await APIClient.shared.get(
                "/api/bible/translations",
                responseType: BibleTranslationsResponse.self
            )
            if let translations = response.translations, !translations.isEmpty {
                bibleTranslations = translations
                NSLog("📖 AppState: Loaded \(translations.count) Bible translations")
            }
        } catch {
            // Still falls back to bundled defaults; recorded so the failed
            // call is visible once an error surface exists.
            recordError(error, context: "AppState.loadBibleTranslations")
        }
    }

    // MARK: - Update Helpers

    /// Update enrollment count for a program in-place
    /// Call this after creating/deleting enrollments to keep counts accurate
    func updateProgramEnrollmentCount(programId: String, delta: Int) {
        guard var program = programs[programId] else { return }

        let currentCount = program._count?.enrollments ?? 0
        let newCount = max(0, currentCount + delta)

        // Create new _count with updated enrollment count
        program._count = ProgramCount(lessons: program._count?.lessons, enrollments: newCount)
        programs.upsert(program)

        NSLog("📦 AppState: Updated program '\(program.name)' enrollment count: \(currentCount) → \(newCount)")
    }
}
