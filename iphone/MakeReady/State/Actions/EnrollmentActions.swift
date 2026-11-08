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
/// ui2-enrollment-create §Contract *Wire ↔ app mapping*: the transforms between the draft's
/// forms and POST /api/enrollments, written once.
enum EnrollmentWire {
    static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// 0 = Sun … 6 = Sat → the server's day names, in week order (the 1.0 map).
    static func dayNames(_ days: Set<Int>) -> [String] {
        days.sorted().compactMap { dayNames.indices.contains($0) ? dayNames[$0] : nil }
    }

    private static let ymdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// D16: a calendar day as the server reads it — formatted in the calendar's zone.
    static func ymd(_ date: Date, in zone: TimeZone = .current) -> String {
        ymdFormatter.timeZone = zone
        return ymdFormatter.string(from: date)
    }

    /// T7: a `yyyy-MM-dd` wire day as the start of that day in `zone`.
    static func date(ymd: String, in zone: TimeZone = .current) -> Date? {
        ymdFormatter.timeZone = zone
        return ymdFormatter.date(from: ymd)
    }

    /// T7: the server enum → the screen's kebab value (nil = not chosen).
    static func lessonAccessLocal(_ wire: String?) -> String? {
        switch wire {
        case "ONE_AT_A_TIME": return "one-at-a-time"
        case "ALL_AT_ONCE": return "all-at-once"
        default: return nil
        }
    }

    /// The screen's kebab value → the server enum (nil = not chosen).
    static func lessonAccessWire(_ screen: String) -> String? {
        switch screen {
        case "one-at-a-time": return "ONE_AT_A_TIME"
        case "all-at-once": return "ALL_AT_ONCE"
        default: return nil
        }
    }
}

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

        // Promote each scheduled lesson, with the rail summaries of the version it points at,
        // into the scheduled-lesson store.
        for schedule in enrollment.lessonSchedules {
            state.scheduledLessons.upsert(schedule)
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
        requireResponse: Bool = false,
        syncMode: EnrollmentSyncMode = .off,
        scheduleDates: [Date]? = nil,
        lessonAccess: String? = nil,
        draftId: String? = nil
    ) async throws -> Enrollment {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var body: [String: Any] = [
            "groupId": groupId,
            "studyProgramId": studyProgramId,
            "startDate": dateFormatter.string(from: startDate),
            "enabledDays": enabledDays,
            "requireResponse": requireResponse,
            "syncMode": syncMode.rawValue
        ]

        if let smsTime = smsTime {
            body["smsTime"] = smsTime
        }
        if let timezone = timezone {
            body["timezone"] = timezone
        }
        // ui2-enrollment-create D3/D16: the calendar's exact days, in its own zone.
        if let scheduleDates {
            body["scheduleDates"] = scheduleDates.map { EnrollmentWire.ymd($0) }
        }
        if let lessonAccess {                                   // D4: ONE_AT_A_TIME | ALL_AT_ONCE
            body["lessonAccess"] = lessonAccess
        }
        if let draftId {                                        // ui2-enrollments-browse D11
            body["draftId"] = draftId
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
        // ui2-enrollments-browse D11/D24: the server deleted the pair's drafts; the feed changed.
        state.removeEnrollmentDrafts(groupId: groupId, studyProgramId: studyProgramId)
        state.enrollmentFeed = [:]

        // Update program enrollment count optimistically
        state.updateProgramEnrollmentCount(programId: studyProgramId, delta: 1)

        state.persist()

        // T13: the index adds alone left loadEnrollmentCounts skipping this group and the group /
        // program pages without the new row — reload what they read. Background: a failure here
        // never fails the create.
        // Agent walk round 2 (E5): the group page's `.task` doesn't re-run when the checklist pops,
        // so its next-study and days are reloaded here, not just cleared.
        let groups = GroupActions(api: api, state: state)
        async let next: () = groups.loadNextStudy(groupId: groupId)
        async let days: () = groups.loadGroupDays(groupId: groupId)
        _ = await (next, days)
        do { _ = try await loadEnrollments(groupId: groupId) } catch {
            state.recordError(error, context: "EnrollmentActions.createEnrollment.refreshGroup")
        }
        do {
            _ = try await ProgramActions(api: api, state: state)
                .getProgramEnrollments(programId: studyProgramId, forceRefresh: true)
        } catch {
            state.recordError(error, context: "EnrollmentActions.createEnrollment.refreshProgram")
        }

        NSLog("📅 EnrollmentActions: Created enrollment \(enrollment.id)")

        return enrollment
    }

    // MARK: - Enrollments feed + home

    /// ui2-enrollments-browse D8/D27: the org-wide feed for `filter`. Cache-first within the session.
    @MainActor
    func loadFeed(filter: EnrollmentFeedFilter, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws {
        if !forceRefresh, state.enrollmentFeed[filter] != nil { return }
        struct Response: Decodable {
            let success: Bool
            let sections: [EnrollmentFeedSection]
            let options: EnrollmentFeedOptions
        }
        let data = try await api.requestWithStatus(endpoint: filter.path(timeZone: timeZone), method: "GET", body: nil)
        let response: Response
        do { response = try JSONDecoder.apiDecoder.decode(Response.self, from: data) } catch { throw APIError.decodingError(error) }
        state.enrollmentFeed[filter] = EnrollmentFeed(sections: response.sections, options: response.options)
    }

    /// ui2-enrollments-browse D20: one enrollment's assembled detail.
    @MainActor
    func loadHome(id: String, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws {
        if !forceRefresh, state.enrollmentHomes[id] != nil { return }
        struct Response: Decodable { let success: Bool; let home: EnrollmentHome }
        let data = try await api.requestWithStatus(endpoint: EnrollmentHome.path(id: id, timeZone: timeZone), method: "GET", body: nil)
        let response: Response
        do { response = try JSONDecoder.apiDecoder.decode(Response.self, from: data) } catch { throw APIError.decodingError(error) }
        state.enrollmentHomes[id] = response.home
    }

    /// Drop the cached Enrollments feed (every filter) and this enrollment's home,
    /// so the next load re-reads the server. Called by every mutation that changes
    /// what the feed or the home shows.
    @MainActor
    private func dropBrowseCaches(enrollmentId: String) {
        state.enrollmentFeed = [:]
        state.enrollmentHomes[enrollmentId] = nil
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
        dropBrowseCaches(enrollmentId: id)
        state.enrollments.remove(id)
        state.groupEnrollmentIndex.remove(parentId: groupId, childId: id)
        state.programEnrollmentIndex.remove(parentId: programId, childId: id)

        // Also prune the program-enrollment store that the Groups → Enrolled tab
        // renders from (AppState.programEnrollmentsFor). Without this the card
        // lingers until a manual pull-to-refresh (monday#12344966891).
        state.programEnrollments.remove(id)
        state.programProgramEnrollmentIndex.remove(parentId: programId, childId: id)

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

            // Clean up indexes by removing this enrollment ID from all parents.
            // No programId in scope here, so mirror the sibling indices with
            // removeChild — including the Enrolled-tab store (monday#12344966891).
            state.groupEnrollmentIndex.removeChild(id)
            state.programEnrollmentIndex.removeChild(id)
            state.programEnrollments.remove(id)
            state.programProgramEnrollmentIndex.removeChild(id)
            dropBrowseCaches(enrollmentId: id)

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

        dropBrowseCaches(enrollmentId: id)
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
        // The server requires a lessonId — it copies that program lesson's
        // activities and dates the schedule by walking the enrollment's
        // enabled days past the last existing schedule. Resolve the study's
        // next unscheduled lesson (lowest day number) to send.
        let details = try await getEnrollmentDetails(id: enrollmentId)
        let scheduledLessonIds = Set(details.lessonSchedules.map { $0.lessonId })

        _ = try await ProgramActions().getProgram(id: details.studyProgramId)
        let nextLesson = state.lessonsFor(programId: details.studyProgramId)
            .sorted { $0.dayNumber < $1.dayNumber }
            .first { !scheduledLessonIds.contains($0.id) }

        guard let nextLesson else {
            throw AddScheduledLessonError.allLessonsScheduled
        }

        do {
            let response: APISuccessResponse = try await api.post(
                "/api/enrollments/\(enrollmentId)/schedules",
                body: ["lessonId": nextLesson.id],
                responseType: APISuccessResponse.self
            )
            guard response.success else {
                throw APIError.serverError(response.error ?? "Failed to add scheduled lesson")
            }
        } catch let error as APIError {
            // 409 = the resolved lesson was scheduled concurrently; from the
            // user's perspective there is nothing left to add.
            if case .serverError(let message) = error, message.localizedCaseInsensitiveContains("already scheduled") {
                throw AddScheduledLessonError.allLessonsScheduled
            }
            throw error
        }

        NSLog("📅 EnrollmentActions: Added scheduled lesson to enrollment \(enrollmentId)")
    }

    /// Thrown by `addScheduledLesson` when every lesson in the study is
    /// already on the enrollment's schedule — callers surface it as an
    /// informational banner (no retry: there is nothing to add).
    enum AddScheduledLessonError: LocalizedError {
        case allLessonsScheduled

        var errorDescription: String? {
            "All lessons in this study are already scheduled"
        }
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

    // MARK: - Study Sync

    /// Get the study-sync status for an enrollment: its sync mode, the program
    /// version its lessons reflect, whether newer versions exist (drift), and
    /// the pending versions' AI change summaries.
    @MainActor
    func getSyncStatus(enrollmentId: String) async throws -> EnrollmentSyncStatus {
        struct Response: Decodable {
            let success: Bool
            let sync: EnrollmentSyncStatus?
            let error: String?
        }
        let response: Response = try await api.get(
            "/api/enrollments/\(enrollmentId)/sync",
            responseType: Response.self
        )
        guard response.success, let sync = response.sync else {
            throw APIError.serverError(response.error ?? "Failed to load sync status")
        }
        // Write-through cache so the page renders synchronously next visit.
        state.enrollmentSyncStatusById[enrollmentId] = sync
        return sync
    }

    /// Dry-run an enrollment edit (group / study / schedule change) so the UI
    /// can warn about destructive/lesson-impacting changes before Save
    /// (monday#12270302158). `body` comes from `EnrollmentEditModel.previewBody()`.
    @MainActor
    func previewEnrollmentEdit(enrollmentId: String, body: [String: Any]) async throws -> EnrollmentEditPreview {
        struct Response: Decodable {
            let success: Bool
            let preview: EnrollmentEditPreview?
            let error: String?
        }
        let response: Response = try await api.post(
            "/api/enrollments/\(enrollmentId)/edit/preview",
            body: body,
            responseType: Response.self
        )
        guard response.success, let preview = response.preview else {
            throw APIError.serverError(response.error ?? "Failed to preview changes")
        }
        return preview
    }

    /// Commit an enrollment edit. `body` comes from `EnrollmentEditModel.patchBody()`
    /// (only-changed-fields). A structural edit (group/study/schedule) can move
    /// the enrollment between groups and rebuild its schedule server-side, so the
    /// caller should reload the affected group(s) afterward rather than trust a
    /// local patch (monday#12270302158).
    @MainActor
    func updateEnrollment(enrollmentId: String, body: [String: Any]) async throws {
        let response: APISuccessResponse = try await api.patch(
            "/api/enrollments/\(enrollmentId)",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update enrollment")
        }
        dropBrowseCaches(enrollmentId: enrollmentId)
    }

    /// Change an enrollment's sync mode (OFF / AUTO / APPROVAL).
    @MainActor
    func updateSyncMode(enrollmentId: String, mode: EnrollmentSyncMode) async throws {
        let response: APISuccessResponse = try await api.patch(
            "/api/enrollments/\(enrollmentId)",
            body: ["syncMode": mode.rawValue],
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update sync mode")
        }
    }

    /// Per-lesson pending changes for the Review Changes screen.
    @MainActor
    func getPendingChanges(enrollmentId: String) async throws -> EnrollmentPendingChanges {
        struct Response: Decodable {
            let success: Bool
            let targetVersionNumber: Int?
            let hasPending: Bool?
            let changes: [PendingLessonChange]?
            let counts: EnrollmentPendingChanges.Counts?
            let error: String?
        }
        let response: Response = try await api.get(
            "/api/enrollments/\(enrollmentId)/sync/changes",
            responseType: Response.self
        )
        guard response.success, let changes = response.changes, let counts = response.counts else {
            throw APIError.serverError(response.error ?? "Failed to load pending changes")
        }
        let pending = EnrollmentPendingChanges(
            targetVersionNumber: response.targetVersionNumber,
            hasPending: response.hasPending ?? !changes.isEmpty,
            changes: changes,
            counts: counts
        )
        state.enrollmentPendingChangesById[enrollmentId] = pending
        return pending
    }

    /// Apply pending curriculum updates to the enrollment. `lessonKeys`
    /// restricts to the approved lessons (Review Changes toggles); nil applies
    /// everything. Partial approvals leave the enrollment drifted so the
    /// leader can approve more later. Members who completed a lesson stay
    /// pinned to the version they finished. Lessons the group customized are
    /// skipped (D5) and named in the result.
    @MainActor
    @discardableResult
    func applySyncUpdates(enrollmentId: String, lessonKeys: [String]? = nil) async throws -> EnrollmentSyncResult {
        /// The route answers `{ success, ...outcome }`, so the result decodes from the same object.
        struct Response: Decodable {
            let success: Bool
            let error: String?
            let result: EnrollmentSyncResult

            private enum CodingKeys: String, CodingKey { case success, error }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                success = try c.decode(Bool.self, forKey: .success)
                error = try c.decodeIfPresent(String.self, forKey: .error)
                result = try EnrollmentSyncResult(from: decoder)
            }
        }
        let body: [String: Any] = lessonKeys.map { ["lessonKeys": $0] } ?? [:]
        let response: Response = try await api.post(
            "/api/enrollments/\(enrollmentId)/sync/apply",
            body: body,
            responseType: Response.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to apply updates")
        }
        // The schedule content may have changed — drop the cached details and
        // pending changes so the next visits refetch.
        state.enrollmentDetailsById[enrollmentId] = nil
        state.enrollmentPendingChangesById[enrollmentId] = nil
        return response.result
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
    /// ui2-enrollment-create T6: server raw values; absent on a response from before.
    let lessonAccess: String?
    let syncMode: String?
}
