//
//  EnrollmentActions.swift
//  MakeReady
//
//  Actions for enrollment operations.
//  Handles API calls, state mutations, and cross-entity updates.
//

import Foundation

/// Actions for enrollment CRUD operations.
/// Enrollments connect groups to study programs.
struct EnrollmentActions {

private let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // MARK: - Centralized State Sync
    //
    // The single source of truth for scheduled-side data is `state.scheduledLessons`.
    // Each lesson holds its activities, readBlocks, and sourceReferences inline.
    // Every mutation here goes through `state.replaceScheduledActivity(_:)` or
    // `state.mutateScheduledActivity(activityId:_:)`, which find the lesson
    // aggregate, mutate the activity in place, and upsert the lesson — one write,
    // every observer notified.

    /// Replace a scheduled activity in its lesson aggregate, then patch the
    /// legacy `lessonScheduleMap` (still used by calendar/home cards) and
    /// persist. Used after API responses that return the canonical activity.
    @MainActor
    private func syncScheduledActivityToState(_ updated: ScheduledActivity) {
        state.replaceScheduledActivity(updated)
        patchLegacyScheduleMap(activityId: updated.id) { activities, idx in
            activities[idx] = updated
        }
        state.persist()
    }

    /// Remove a scheduled activity from its lesson aggregate and the legacy map.
    @MainActor
    private func removeScheduledActivityFromState(activityId: String) {
        if let lessonId = state.scheduledLessonContaining(activityId: activityId),
           var lesson = state.scheduledLessons[lessonId] {
            lesson.activities.removeAll { $0.id == activityId }
            state.scheduledLessons.upsert(lesson)
        }
        patchLegacyScheduleMap(activityId: activityId) { activities, idx in
            activities.remove(at: idx)
        }
        state.persist()
    }

    /// Apply a mutation to the legacy `lessonScheduleMap` for any schedule
    /// containing the given activity. Calendar/home cards still read from
    /// this map until they migrate to `state.scheduledLessons` directly.
    @MainActor
    private func patchLegacyScheduleMap(
        activityId: String,
        _ mutate: (inout [ScheduledActivity], Int) -> Void
    ) {
        var map = state.lessonScheduleMap
        var didChange = false
        for (key, entry) in map {
            guard let idx = entry.schedule.lesson.activities.firstIndex(where: { $0.id == activityId }) else { continue }
            var schedule = entry.schedule
            mutate(&schedule.lesson.activities, idx)
            map[key] = (schedule: schedule, studyName: entry.studyName, enrollmentId: entry.enrollmentId)
            didChange = true
            break
        }
        if didChange {
            state.lessonScheduleMap = map
        }
    }

    // MARK: - Load Enrollments for Group

    /// Load enrollments for a specific group
    @MainActor
    func loadEnrollments(groupId: String) async throws -> [EnrollmentWithProgram] {
        let context = LoadingStateManager.contextKey(.groups, groupId, .enrollments)
        state.loadingStates.startLoading(context: context, hasCachedData: state.groupEnrollmentIndex.hasChildren(groupId))

        defer {
            state.loadingStates.finishLoading(context: context)
        }

        struct Response: Decodable {
            let success: Bool
            let enrollments: [EnrollmentWithProgram]?
            let error: String?
        }

        let response: Response = try await api.get(
            "/api/groups/\(groupId)/enrollments",
            responseType: Response.self
        )

        guard response.success, let enrollments = response.enrollments else {
            throw APIError.serverError(response.error ?? "Failed to fetch enrollments")
        }

        // Replace all enrollments for this group
        let oldEnrollmentIds = state.groupEnrollmentIndex.get(groupId)
        state.enrollments.removeMany(oldEnrollmentIds)
        state.groupEnrollmentIndex.removeAll(parentId: groupId)

        for enrollment in enrollments {
            state.enrollments.upsert(enrollment)
            state.groupEnrollmentIndex.add(parentId: groupId, childId: enrollment.id)
            state.programEnrollmentIndex.add(parentId: enrollment.studyProgramId, childId: enrollment.id)
        }

        state.persist()
        NSLog("📅 EnrollmentActions: Loaded \(enrollments.count) enrollments for group \(groupId)")
        return enrollments
    }

    // MARK: - Get Enrollment Details

    /// Get a single enrollment with full lesson schedule details
    @MainActor
    func getEnrollmentDetails(id: String) async throws -> EnrollmentDetails {
        state.loadingStates.startLoading(id, hasCachedData: false)

        defer {
            state.loadingStates.finishLoading(id)
        }

        struct Response: Decodable {
            let success: Bool
            let enrollment: EnrollmentDetails?
            let error: String?
        }

        let response: Response = try await api.get(
            "/api/enrollments/\(id)",
            responseType: Response.self
        )

        guard response.success, let enrollment = response.enrollment else {
            throw APIError.serverError(response.error ?? "Failed to fetch enrollment details")
        }

        // Promote each scheduled lesson aggregate (with its activities,
        // readBlocks, and sourceReferences inline) into the lesson store. The
        // editor and Bible reader read directly from this for any lesson, not
        // just today+future.
        for schedule in enrollment.lessonSchedules {
            state.scheduledLessons.upsert(schedule.lesson)
        }
        state.enrollmentDetailsById[id] = enrollment
        state.persist()

        NSLog("📅 EnrollmentActions: Loaded enrollment details for \(id)")
        return enrollment
    }

    /// Fetch group-completion analytics for an enrollment (member count plus
    /// per-lesson and per-activity distinct-member completion counts). Used to
    /// render group-completion fill on the enrollment lesson cards.
    @MainActor
    func getEnrollmentCompletionStats(id: String) async throws -> EnrollmentCompletionStats {
        struct Response: Decodable {
            let success: Bool
            let stats: EnrollmentCompletionStats?
            let error: String?
        }

        let response: Response = try await api.get(
            "/api/enrollments/\(id)/completion-stats",
            responseType: Response.self
        )

        guard response.success, let stats = response.stats else {
            throw APIError.serverError(response.error ?? "Failed to fetch completion stats")
        }

        NSLog("📊 EnrollmentActions: Loaded completion stats for \(id) (\(stats.lessons.count) lessons, \(stats.memberCount) members)")
        return stats
    }

    // MARK: - Create Enrollment

    /// Create a new enrollment
    @MainActor
    func createEnrollment(
        groupId: String,
        studyProgramId: String,
        startDate: Date,
        enabledDays: [String],
        smsTime: String?,
        timezone: String?,
        requireResponse: Bool = false
    ) async throws -> Enrollment {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var body: [String: Any] = [
            "groupId": groupId,
            "studyProgramId": studyProgramId,
            "startDate": dateFormatter.string(from: startDate),
            "enabledDays": enabledDays,
            "requireResponse": requireResponse
        ]

        if let smsTime = smsTime {
            body["smsTime"] = smsTime
        }
        if let timezone = timezone {
            body["timezone"] = timezone
        }

        struct Response: Decodable {
            let success: Bool
            let enrollment: Enrollment?
            let error: String?
        }

        let response: Response = try await api.post(
            "/api/enrollments",
            body: body,
            responseType: Response.self
        )

        guard response.success, let enrollment = response.enrollment else {
            throw APIError.serverError(response.error ?? "Failed to create enrollment")
        }

        // Update relationship indexes
        state.groupEnrollmentIndex.add(parentId: groupId, childId: enrollment.id)
        state.programEnrollmentIndex.add(parentId: studyProgramId, childId: enrollment.id)

        // Update program enrollment count optimistically
        state.updateProgramEnrollmentCount(programId: studyProgramId, delta: 1)

        state.persist()
        NSLog("📅 EnrollmentActions: Created enrollment \(enrollment.id)")

        return enrollment
    }

    // MARK: - Delete Enrollment

    /// Delete an enrollment
    @MainActor
    func deleteEnrollment(id: String, groupId: String, programId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/enrollments/\(id)",
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete enrollment")
        }

        // Remove from state
        state.enrollments.remove(id)
        state.groupEnrollmentIndex.remove(parentId: groupId, childId: id)
        state.programEnrollmentIndex.remove(parentId: programId, childId: id)

        // Update program enrollment count
        state.updateProgramEnrollmentCount(programId: programId, delta: -1)

        state.persist()
        NSLog("📅 EnrollmentActions: Deleted enrollment \(id)")
    }

    /// Delete an enrollment when we only have the enrollment ID
    /// Looks up group and program IDs from state first
    @MainActor
    func deleteEnrollment(id: String) async throws {
        // Get enrollment from state to find groupId and programId
        guard let enrollment = state.enrollments[id] else {
            // If not in state, still try to delete on server
            let response: APISuccessResponse = try await api.delete(
                "/api/enrollments/\(id)",
                responseType: APISuccessResponse.self
            )

            guard response.success else {
                throw APIError.serverError(response.error ?? "Failed to delete enrollment")
            }

            // Clean up indexes by removing this enrollment ID from all parents
            state.groupEnrollmentIndex.removeChild(id)
            state.programEnrollmentIndex.removeChild(id)

            state.persist()
            return
        }

        try await deleteEnrollment(
            id: id,
            groupId: enrollment.groupId,
            programId: enrollment.studyProgramId
        )
    }

    // MARK: - Unenroll Info

    /// Get unenroll info for an enrollment (lesson data status)
    @MainActor
    func getUnenrollInfo(id: String) async throws -> UnenrollInfo {
        struct Response: Decodable {
            let success: Bool
            let data: UnenrollInfo?
            let error: String?
        }

        let response: Response = try await api.get(
            "/api/enrollments/\(id)/unenroll-info",
            responseType: Response.self
        )

        guard response.success, let info = response.data else {
            throw APIError.serverError(response.error ?? "Failed to fetch unenroll info")
        }

        NSLog("📅 EnrollmentActions: Got unenroll info for \(id) - \(info.lessonsWithData)/\(info.totalLessons) lessons have data")
        return info
    }

    // MARK: - Cancel Future Lessons

    /// Cancel future lessons with no member data for an enrollment
    @MainActor
    func cancelFutureLessons(id: String) async throws {
        let response: APISuccessResponse = try await api.post(
            "/api/enrollments/\(id)/cancel-future",
            body: [:] as [String: Any],
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to cancel future lessons")
        }

        NSLog("📅 EnrollmentActions: Cancelled future lessons for enrollment \(id)")
    }

    // MARK: - Lesson Invite

    /// Fetch the invite (URL + QR payload) for a scheduled lesson.
    /// Rehomed from StudyInvitePage / GroupHomePage / EnrollmentSchedulePage /
    /// MainHome / MainCalendar (Phase 2.4) — those five sites fired the same
    /// GET with the same parsing.
    @MainActor
    func loadLessonInvite(scheduleId: String) async throws -> LessonInviteData {
        let response = try await api.get(
            "/api/lesson-schedules/\(scheduleId)/invite",
            responseType: LessonInviteResponse.self
        )

        guard response.success, let invite = response.invite else {
            throw NSError(
                domain: "LessonInvite",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: response.error ?? "Failed to load invite"]
            )
        }

        return invite
    }

    // MARK: - Delete Lesson Schedule

    /// Delete a lesson schedule from an enrollment
    @MainActor
    func deleteLessonSchedule(enrollmentId: String, scheduleId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/enrollments/\(enrollmentId)/schedules/\(scheduleId)",
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete lesson schedule")
        }

        NSLog("📅 EnrollmentActions: Deleted lesson schedule \(scheduleId) from enrollment \(enrollmentId)")
    }

    // MARK: - Add Lesson Schedule

    /// Add a new scheduled lesson to an enrollment.
    /// Tells the server to create a new lesson schedule — does NOT modify the study program.
    /// - Parameter enrollmentId: The enrollment to add the lesson to
    @MainActor
    func addScheduledLesson(enrollmentId: String) async throws {
        let response: APISuccessResponse = try await api.post(
            "/api/enrollments/\(enrollmentId)/schedules",
            body: [:],
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to add scheduled lesson")
        }

        NSLog("📅 EnrollmentActions: Added scheduled lesson to enrollment \(enrollmentId)")
    }

    // MARK: - Update Schedule Title

    /// Update a lesson schedule's title
    @MainActor
    func updateScheduleTitle(enrollmentId: String, scheduleId: String, title: String) async throws {
        let body: [String: Any] = ["title": title]
        let response: APISuccessResponse = try await api.patch(
            "/api/enrollments/\(enrollmentId)/schedules/\(scheduleId)",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update schedule title")
        }
        NSLog("📅 EnrollmentActions: Updated schedule title for \(scheduleId)")
    }

    // MARK: - Scheduled Activity Operations

    /// Toggle help visibility on a scheduled activity
    @MainActor
    func toggleScheduledActivityHelp(activityId: String, isHelpEnabled: Bool) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        let response: Response = try await api.patch(
            "/api/scheduled-activities/\(activityId)",
            body: ["isHelpEnabled": isHelpEnabled],
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to update scheduled activity")
        }
        syncScheduledActivityToState(activity)
        return activity
    }

    /// Update scheduled activity fields
    @MainActor
    func updateScheduledActivity(activityId: String, title: String?, helpTitle: String?, helpDescription: String?) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let helpTitle = helpTitle { body["helpTitle"] = helpTitle }
        if let helpDescription = helpDescription { body["helpDescription"] = helpDescription }

        let response: Response = try await api.patch(
            "/api/scheduled-activities/\(activityId)",
            body: body,
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to update scheduled activity")
        }
        syncScheduledActivityToState(activity)
        return activity
    }

    /// Delete a scheduled activity
    @MainActor
    func deleteScheduledActivity(enrollmentId: String, scheduleId: String, activityId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/scheduled-activities/\(activityId)",
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete scheduled activity")
        }
        removeScheduledActivityFromState(activityId: activityId)
        NSLog("📅 EnrollmentActions: Deleted scheduled activity \(activityId)")
    }

    /// Add a scheduled activity to a lesson schedule
    @MainActor
    func addScheduledActivity(
        enrollmentId: String,
        scheduleId: String,
        type: String,
        title: String? = nil,
        helpTitle: String? = nil,
        helpDescription: String? = nil,
        videoId: String? = nil
    ) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        var body: [String: Any] = [
            "type": type,
            "title": title ?? type.capitalized
        ]
        if let helpTitle = helpTitle { body["helpTitle"] = helpTitle }
        if let helpDescription = helpDescription { body["helpDescription"] = helpDescription }
        if let videoId = videoId { body["videoId"] = videoId }

        let response: Response = try await api.post(
            "/api/enrollments/\(enrollmentId)/schedules/\(scheduleId)/activities",
            body: body,
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to add scheduled activity")
        }

        // Append to the parent lesson aggregate (the single source of truth)
        // and patch the legacy schedule map for calendar/home cards.
        if let entry = state.lessonScheduleMap[scheduleId] {
            let scheduledLessonId = entry.schedule.lesson.id
            if var lesson = state.scheduledLessons[scheduledLessonId] {
                lesson.activities.append(activity)
                state.scheduledLessons.upsert(lesson)
            }
            var schedule = entry.schedule
            schedule.lesson.activities.append(activity)
            state.lessonScheduleMap[scheduleId] = (schedule: schedule, studyName: entry.studyName, enrollmentId: entry.enrollmentId)
        }
        state.persist()

        return activity
    }

    /// Reorder scheduled activities via drag-and-drop
    @MainActor
    func reorderScheduledActivities(enrollmentId: String, scheduleId: String, activityIds: [String]) async throws {
        let body: [String: Any] = ["activityOrder": activityIds]
        let response: APISuccessResponse = try await api.post(
            "/api/enrollments/\(enrollmentId)/schedules/\(scheduleId)/reorder-activities",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to reorder scheduled activities")
        }

        // Apply the new orderNumber to each activity in the lesson aggregate
        // (single source of truth) and patch the legacy schedule map.
        if let entry = state.lessonScheduleMap[scheduleId] {
            let scheduledLessonId = entry.schedule.lesson.id
            if var lesson = state.scheduledLessons[scheduledLessonId] {
                let byId = Dictionary(uniqueKeysWithValues: lesson.activities.map { ($0.id, $0) })
                var reordered: [ScheduledActivity] = []
                for (i, activityId) in activityIds.enumerated() {
                    if var a = byId[activityId] {
                        a.orderNumber = i + 1
                        reordered.append(a)
                    }
                }
                for a in lesson.activities where !activityIds.contains(a.id) {
                    reordered.append(a)
                }
                lesson.activities = reordered
                state.scheduledLessons.upsert(lesson)
            }

            var schedule = entry.schedule
            schedule.lesson.activities = state.scheduledLessons[scheduledLessonId]?.activities ?? schedule.lesson.activities
            state.lessonScheduleMap[scheduleId] = (schedule: schedule, studyName: entry.studyName, enrollmentId: entry.enrollmentId)
            state.persist()
        }

        NSLog("📅 EnrollmentActions: Reordered activities for schedule \(scheduleId)")
    }

    /// Reset a scheduled activity (clear content, video, source references, read blocks)
    @MainActor
    func clearScheduledActivity(activityId: String) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        let response: Response = try await api.post(
            "/api/scheduled-activities/\(activityId)/reset",
            body: [:] as [String: Any],
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to reset scheduled activity")
        }
        syncScheduledActivityToState(activity)
        return activity
    }

    /// Update a scheduled activity's video
    @MainActor
    func updateScheduledActivityVideo(activityId: String, videoId: String, videoUrl: String) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        let body: [String: Any] = ["videoId": videoId, "videoUrl": videoUrl]
        let response: Response = try await api.patch(
            "/api/scheduled-activities/\(activityId)",
            body: body,
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to update scheduled activity video")
        }
        syncScheduledActivityToState(activity)
        return activity
    }

    /// Remove video from a scheduled activity
    @MainActor
    func removeScheduledActivityVideo(activityId: String) async throws -> ScheduledActivity {
        struct Response: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }
        let body: [String: Any] = ["videoId": NSNull(), "videoUrl": NSNull()]
        let response: Response = try await api.patch(
            "/api/scheduled-activities/\(activityId)",
            body: body,
            responseType: Response.self
        )
        guard response.success, let activity = response.scheduledActivity else {
            throw APIError.serverError(response.error ?? "Failed to remove scheduled activity video")
        }
        syncScheduledActivityToState(activity)
        return activity
    }

    // MARK: - Source Reference Operations

    /// Add a source reference to a scheduled activity
    @MainActor
    func addSourceReference(activityId: String, passageData: PassageData, content: String? = nil) async throws -> ScheduledActivity? {
        var body: [String: Any] = [
            "sourceType": "BIBLE_PASSAGE",
            "passageReference": passageData.reference,
            "bookNumber": passageData.bookNumber,
            "bookName": passageData.bookName,
            "chapterStart": passageData.chapterStart,
            "verseStart": passageData.verseStart,
            "verseEnd": passageData.verseEnd
        ]

        if let chapterEnd = passageData.chapterEnd {
            body["chapterEnd"] = chapterEnd
        }
        if let content = content {
            body["content"] = BibleVerseContentNormalizer.normalizedMarkdown(from: content)
        }

        struct SourceRefResponse: Decodable {
            let success: Bool
            let sourceReference: ActivitySourceReference?
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }

        let response: SourceRefResponse = try await api.post(
            "/api/scheduled-activities/\(activityId)/source-references",
            body: body,
            responseType: SourceRefResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to add source reference")
        }

        NSLog("📅 EnrollmentActions: Added source reference to scheduled activity \(activityId)")
        if let updated = response.scheduledActivity {
            syncScheduledActivityToState(updated)
        }
        return response.scheduledActivity
    }

    /// Remove a source reference from a scheduled activity
    @MainActor
    func deleteSourceReference(activityId: String, refId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/scheduled-activities/\(activityId)/source-references/\(refId)",
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete source reference")
        }

        // The endpoint returns only `{ success }`, so apply the removal locally
        // to the lesson aggregate. This is what makes the Bible reader's
        // "used passages" highlights drop the verse immediately, everywhere.
        state.mutateScheduledActivity(activityId: activityId) { activity in
            activity.sourceReferences?.removeAll { $0.id == refId }
            // Also drop any read block that was anchored to that reference.
            activity.readBlocks?.removeAll { $0.sourceReferenceId == refId }
        }
        patchLegacyScheduleMap(activityId: activityId) { activities, idx in
            activities[idx].sourceReferences?.removeAll { $0.id == refId }
            activities[idx].readBlocks?.removeAll { $0.sourceReferenceId == refId }
        }
        state.persist()

        NSLog("📅 EnrollmentActions: Deleted source reference \(refId) from scheduled activity \(activityId)")
    }

    // MARK: - Read Block Operations

    /// Add a read block to a scheduled activity
    @MainActor
    func createReadBlock(
        activityId: String,
        content: String? = nil,
        isLocked: Bool = false,
        sourceReferenceId: String? = nil,
        orderNumber: Int? = nil
    ) async throws -> ScheduledActivity? {
        var body: [String: Any] = [
            "isLocked": isLocked
        ]
        if let content = content { body["content"] = content }
        if let sourceReferenceId = sourceReferenceId { body["sourceReferenceId"] = sourceReferenceId }
        if let orderNumber = orderNumber { body["orderNumber"] = orderNumber }

        struct ReadBlockResponse: Decodable {
            let success: Bool
            let block: ActivityReadBlock?
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }

        let response: ReadBlockResponse = try await api.post(
            "/api/scheduled-activities/\(activityId)/read-blocks",
            body: body,
            responseType: ReadBlockResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to create read block")
        }

        NSLog("📅 EnrollmentActions: Created read block for scheduled activity \(activityId)")
        if let updated = response.scheduledActivity {
            syncScheduledActivityToState(updated)
        }
        return response.scheduledActivity
    }

    /// Update a read block on a scheduled activity
    @MainActor
    func updateReadBlock(activityId: String, blockId: String, content: String?) async throws {
        var body: [String: Any] = [:]
        if let content = content {
            body["content"] = content
        } else {
            body["content"] = NSNull()
        }

        struct BlockUpdateResponse: Decodable {
            let success: Bool
            let error: String?
        }

        let response: BlockUpdateResponse = try await api.patch(
            "/api/scheduled-activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: BlockUpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update read block")
        }

        // Update in AppState if this activity exists there (program activities)
        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[index].content = content
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }

        // Update the lesson aggregate (single source of truth for enrollment).
        // The endpoint returns just `{success}`, so apply the patch locally.
        state.mutateScheduledActivity(activityId: activityId) { activity in
            guard var blocks = activity.readBlocks,
                  let bIdx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
            blocks[bIdx].content = content
            blocks[bIdx].updatedAt = Date()
            activity.readBlocks = blocks
        }
        patchLegacyScheduleMap(activityId: activityId) { activities, idx in
            guard var blocks = activities[idx].readBlocks,
                  let bIdx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
            blocks[bIdx].content = content
            blocks[bIdx].updatedAt = Date()
            activities[idx].readBlocks = blocks
        }
        state.persist()

        NSLog("📅 EnrollmentActions: Updated read block \(blockId)")
    }

    /// Save the array of styled selections for a scheduled-activity read block.
    @MainActor
    func updateReadBlockSelections(activityId: String, blockId: String, selections: [ReadBlockSelection]) async throws {
        let body: [String: Any] = [
            "selections": selections.map { ["start": $0.start, "end": $0.end, "style": $0.style] }
        ]

        struct BlockUpdateResponse: Decodable {
            let success: Bool
            let error: String?
        }

        let response: BlockUpdateResponse = try await api.patch(
            "/api/scheduled-activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: BlockUpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to save selections")
        }

        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[index].selections = selections
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }

        state.mutateScheduledActivity(activityId: activityId) { activity in
            guard var blocks = activity.readBlocks,
                  let bIdx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
            blocks[bIdx].selections = selections
            blocks[bIdx].updatedAt = Date()
            activity.readBlocks = blocks
        }
        patchLegacyScheduleMap(activityId: activityId) { activities, idx in
            guard var blocks = activities[idx].readBlocks,
                  let bIdx = blocks.firstIndex(where: { $0.id == blockId }) else { return }
            blocks[bIdx].selections = selections
            blocks[bIdx].updatedAt = Date()
            activities[idx].readBlocks = blocks
        }
        state.persist()
    }

    /// Delete a read block from a scheduled activity
    @MainActor
    func deleteReadBlock(activityId: String, blockId: String) async throws -> ScheduledActivity? {
        struct DeleteBlockResponse: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }

        let response: DeleteBlockResponse = try await api.delete(
            "/api/scheduled-activities/\(activityId)/read-blocks/\(blockId)",
            responseType: DeleteBlockResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete read block")
        }

        NSLog("📅 EnrollmentActions: Deleted read block \(blockId)")
        if let updated = response.scheduledActivity {
            syncScheduledActivityToState(updated)
        }
        return response.scheduledActivity
    }

    /// Reorder read blocks for a scheduled activity
    @MainActor
    func reorderReadBlocks(activityId: String, blockIds: [String]) async throws -> ScheduledActivity? {
        let body: [String: Any] = ["blockIds": blockIds]

        struct ReorderBlocksResponse: Decodable {
            let success: Bool
            let scheduledActivity: ScheduledActivity?
            let error: String?
        }

        let response: ReorderBlocksResponse = try await api.patch(
            "/api/scheduled-activities/\(activityId)/read-blocks/reorder",
            body: body,
            responseType: ReorderBlocksResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to reorder read blocks")
        }

        NSLog("📅 EnrollmentActions: Reordered read blocks for scheduled activity \(activityId)")
        if let updated = response.scheduledActivity {
            syncScheduledActivityToState(updated)
        }
        return response.scheduledActivity
    }
}

// MARK: - Enrollment Model (for create response)

/// Basic enrollment model returned from create endpoint
struct Enrollment: Codable, Identifiable {
    let id: String
    let groupId: String
    let studyProgramId: String
    let startDate: Date
    let endDate: Date
    let enabledDays: String  // JSON array string
    let smsTime: String?
    let timezone: String?
    let requireResponse: Bool?
    let createdAt: Date
    let updatedAt: Date
    let createdById: String?
}
