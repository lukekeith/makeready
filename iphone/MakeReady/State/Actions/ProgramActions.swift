//
//  ProgramActions.swift
//  MakeReady
//
//  Actions for study program operations.
//  Handles API calls, state mutations, and persistence.
//

import Foundation
import UIKit

/// Shared response shape for read-block mutation endpoints.
private struct ReadBlockMutationResponse: Decodable {
    let success: Bool
    let error: String?
}

/// Actions for study program CRUD and lesson/activity management.
struct ProgramActions {

    private let state = AppState.shared
    private let api = APIClient.shared

    // MARK: - Load Programs

    /// Load all programs, using cache if available.
    /// - Parameters:
    ///   - forceRefresh: If true, always fetch from API
    ///   - tags: Tags to filter by (multi-select OR semantics on the server)
    ///   - leaders: Group-leader user IDs to filter by (multi-select OR)
    @MainActor
    func loadPrograms(
        forceRefresh: Bool = false,
        tags: [String]? = nil,
        leaders: [String]? = nil
    ) async throws {
        let hasFilters = (tags?.isEmpty == false) || (leaders?.isEmpty == false)

        // If we have cached data, no filters, and not forcing refresh, show
        // cached and refresh in the background.
        if state.hasCachedPrograms && !forceRefresh && !hasFilters {
            state.loadingStates.startLoading(.programs, hasCachedData: true)
            Task {
                do {
                    try await fetchPrograms()
                } catch {
                    NSLog("❌ ProgramActions: Background refresh failed: \(error.localizedDescription)")
                }
            }
            return
        }

        state.loadingStates.startLoading(.programs, hasCachedData: state.hasCachedPrograms)
        try await fetchPrograms(tags: tags, leaders: leaders)
    }

    /// Fetch programs from API and update state.
    @MainActor
    private func fetchPrograms(tags: [String]? = nil, leaders: [String]? = nil) async throws {
        defer {
            state.loadingStates.finishLoading(.programs)
        }

        var query: [String] = []
        if let tags, !tags.isEmpty {
            let joined = tags.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            query.append("tag=\(encoded)")
        }
        if let leaders, !leaders.isEmpty {
            let joined = leaders.joined(separator: ",")
            let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? joined
            query.append("leaders=\(encoded)")
        }
        let endpoint = "/api/programs" + (query.isEmpty ? "" : "?" + query.joined(separator: "&"))

        let response: ListProgramsResponse = try await api.get(endpoint, responseType: ListProgramsResponse.self)

        guard response.success, let programs = response.programs else {
            throw APIError.serverError(response.error ?? "Failed to load programs")
        }

        // Update state with fetched programs
        state.programs.replaceAll(programs)

        // Rebuild enrollment indexes from program data
        for program in programs {
            let enrollmentCount = program._count?.enrollments ?? 0
            let tagList = program.tags ?? []
            NSLog("📚 ProgramActions: Loaded '\(program.name)' with \(enrollmentCount) enrollments, tags: \(tagList)")
        }

        state.persist()
        NSLog("📚 ProgramActions: Loaded \(programs.count) programs")
    }

    // MARK: - Get Single Program

    /// Get a program by ID with its lessons
    /// - Parameters:
    ///   - id: Program ID
    ///   - lessonPage: Page number for lessons (default: 1)
    ///   - lessonLimit: Number of lessons per page (default: 30)
    @MainActor
    func getProgram(id: String, lessonPage: Int = 1, lessonLimit: Int = 30) async throws -> (program: StudyProgram, pagination: PaginationInfo?) {
        state.loadingStates.startLoading(id, hasCachedData: state.programs.contains(id))

        defer {
            state.loadingStates.finishLoading(id)
        }

        var endpoint = "/api/programs/\(id)"
        if lessonPage != 1 || lessonLimit != 30 {
            endpoint += "?lessonPage=\(lessonPage)&lessonLimit=\(lessonLimit)"
        }

        let response: CreateProgramResponse = try await api.get(endpoint, responseType: CreateProgramResponse.self)

        guard response.success, let program = response.program else {
            throw APIError.serverError(response.error ?? "Program not found")
        }

        // Update program in state
        state.programs.upsert(program)

        // Update lessons if included
        if let lessons = program.lessons {
            for lesson in lessons {
                state.lessons.upsert(lesson)
                state.programLessonIndex.add(parentId: id, childId: lesson.id)

                // Update activities
                for activity in lesson.activities {
                    state.activities.upsert(activity)
                    state.lessonActivityIndex.add(parentId: lesson.id, childId: activity.id)
                }
            }
        }

        state.persist()
        return (program: program, pagination: response.pagination)
    }

    // MARK: - Load Templates

    /// Load all lesson templates, using cache if available
    /// - Parameter forceRefresh: If true, always fetch from API
    @MainActor
    func loadTemplates(forceRefresh: Bool = false) async throws {
        // If we have cached data and not forcing refresh, refresh in background
        if state.hasCachedTemplates && !forceRefresh {
            Task {
                do {
                    try await fetchTemplates()
                } catch {
                    NSLog("⚠️ ProgramActions: Background refresh of templates failed: \(error.localizedDescription)")
                }
            }
            return
        }

        try await fetchTemplates()
    }

    /// Fetch templates from API and update state
    @MainActor
    private func fetchTemplates() async throws {
        let response: ListTemplatesResponse = try await api.get(
            "/api/templates", responseType: ListTemplatesResponse.self
        )
        guard response.success != false, let templates = response.templates else {
            throw APIError.serverError(response.error ?? "Failed to load templates")
        }
        state.templates.replaceAll(templates)
        state.persist()
        NSLog("📚 ProgramActions: Loaded \(templates.count) templates")
    }

    // MARK: - Create Program

    /// Create a new study program
    @MainActor
    func createProgram(
        name: String,
        description: String?,
        templateId: String,
        days: Int,
        coverImageUrl: String? = nil,
        isPublished: Bool = false
    ) async throws -> StudyProgram {
        var body: [String: Any] = [
            "name": name,
            "templateId": templateId,
            "days": days,
            "isPublished": isPublished
        ]

        if let description = description {
            body["description"] = description
        }
        if let coverImageUrl = coverImageUrl {
            body["coverImageUrl"] = coverImageUrl
        }

        let response: CreateProgramResponse = try await api.post("/api/programs", body: body, responseType: CreateProgramResponse.self)

        guard response.success, let program = response.program else {
            throw APIError.serverError(response.error ?? "Failed to create program")
        }

        // Add to state (matching getProgram pattern so EditDay can find activities)
        state.programs.upsert(program)

        if let lessons = program.lessons {
            for lesson in lessons {
                state.lessons.upsert(lesson)
                state.programLessonIndex.add(parentId: program.id, childId: lesson.id)

                for activity in lesson.activities {
                    state.activities.upsert(activity)
                    state.lessonActivityIndex.add(parentId: lesson.id, childId: activity.id)
                }
            }
        }

        state.persist()

        NSLog("📚 ProgramActions: Created program '\(program.name)'")
        return program
    }

    // MARK: - Update Program

    /// Update program metadata
    @MainActor
    func updateProgram(
        id: String,
        name: String? = nil,
        description: String? = nil,
        days: Int? = nil,
        coverImageUrl: String? = nil,
        isPublished: Bool? = nil
    ) async throws -> StudyProgram {
        var body: [String: Any] = [:]

        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let days = days { body["days"] = days }
        if let coverImageUrl = coverImageUrl { body["coverImageUrl"] = coverImageUrl }
        if let isPublished = isPublished { body["isPublished"] = isPublished }

        let response: CreateProgramResponse = try await api.patch("/api/programs/\(id)", body: body, responseType: CreateProgramResponse.self)

        guard response.success, let program = response.program else {
            throw APIError.serverError(response.error ?? "Failed to update program")
        }

        state.programs.upsert(program)
        state.persist()

        NSLog("📚 ProgramActions: Updated program '\(program.name)'")
        return program
    }

    // MARK: - Update Lesson Title

    /// Update a lesson's title
    @MainActor
    func updateLessonTitle(programId: String, lessonId: String, title: String) async throws {
        let body: [String: Any] = ["title": title]
        let response: APISuccessResponse = try await api.patch(
            "/api/programs/\(programId)/lessons/\(lessonId)",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update lesson title")
        }
        NSLog("📚 ProgramActions: Updated lesson title for \(lessonId)")
    }

    // MARK: - Delete Program

    /// Delete a program
    @MainActor
    func deleteProgram(id: String) async throws {
        // Get program name for logging
        let programName = state.programs[id]?.name ?? id

        let response: APISuccessResponse = try await api.delete("/api/programs/\(id)", responseType: APISuccessResponse.self)

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete program")
        }

        // Remove from state
        state.programs.remove(id)

        // Clean up related data
        let lessonIds = state.programLessonIndex.get(id)
        for lessonId in lessonIds {
            let activityIds = state.lessonActivityIndex.get(lessonId)
            state.activities.removeMany(activityIds)
            state.lessonActivityIndex.removeAll(parentId: lessonId)
        }
        state.lessons.removeMany(lessonIds)
        state.programLessonIndex.removeAll(parentId: id)

        // Remove enrollments for this program
        let enrollmentIds = state.programEnrollmentIndex.get(id)
        state.enrollments.removeMany(enrollmentIds)
        state.programEnrollmentIndex.removeAll(parentId: id)

        state.persist()
        NSLog("📚 ProgramActions: Deleted program '\(programName)'")
    }

    // MARK: - Cover Image Upload

    /// Get tags for a specific program
    @MainActor
    func getTags(programId: String) async throws -> [String] {
        struct TagsResponse: Decodable {
            let success: Bool
            let tags: [String]?
            let error: String?
        }

        let response: TagsResponse = try await api.get(
            "/api/programs/\(programId)/tags",
            responseType: TagsResponse.self
        )

        guard response.success, let tags = response.tags else {
            throw APIError.serverError(response.error ?? "Failed to load tags")
        }

        return tags
    }

    /// Add tags to a program
    @MainActor
    func addTags(programId: String, tags: [String]) async throws {
        let body: [String: Any] = ["tags": tags]
        let response: APISuccessResponse = try await api.post(
            "/api/programs/\(programId)/tags",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to add tags")
        }
    }

    /// Remove tags from a program
    @MainActor
    func removeTags(programId: String, tags: [String]) async throws {
        let body: [String: Any] = ["tags": tags]
        let response: APISuccessResponse = try await api.request(
            endpoint: "/api/programs/\(programId)/tags",
            method: "DELETE",
            body: body,
            responseType: APISuccessResponse.self
        )
        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to remove tags")
        }
    }

    /// Sync tags for a program (compares old vs new, adds/removes as needed)
    @MainActor
    func syncTags(programId: String, oldTags: [String], newTags: [String]) async throws {
        let toAdd = newTags.filter { !oldTags.contains($0) }
        let toRemove = oldTags.filter { !newTags.contains($0) }

        if !toAdd.isEmpty {
            try await addTags(programId: programId, tags: toAdd)
        }
        if !toRemove.isEmpty {
            try await removeTags(programId: programId, tags: toRemove)
        }
    }

    /// Get all program tags ordered by usage count
    @MainActor
    func loadAllTags() async throws -> [String] {
        let response: TagsResponse = try await api.get(
            "/api/programs/tags",
            responseType: TagsResponse.self
        )
        guard response.success, let tags = response.tags else {
            throw APIError.serverError(response.error ?? "Failed to load tags")
        }
        return tags.map { $0.tag }
    }

    /// List group leaders in the caller's organization with their program +
    /// media counts. Drives the Library "Group leaders" filter dropdown.
    @MainActor
    func loadGroupLeaders() async throws -> [GroupLeader] {
        let response: GroupLeadersResponse = try await api.get(
            "/api/group-leaders",
            responseType: GroupLeadersResponse.self
        )
        guard response.success, let leaders = response.leaders else {
            throw APIError.serverError(response.error ?? "Failed to load group leaders")
        }
        return leaders
    }

    /// Get AI-suggested tags for a program
    @MainActor
    func suggestTags(programId: String) async throws -> [String] {
        struct SuggestTagsResponse: Decodable {
            let success: Bool
            let tags: [String]?
            let error: String?
        }

        let response: SuggestTagsResponse = try await api.post(
            "/api/programs/\(programId)/suggest-tags",
            body: [:],
            responseType: SuggestTagsResponse.self
        )

        guard response.success, let tags = response.tags else {
            throw APIError.serverError(response.error ?? "Failed to suggest tags")
        }

        return tags
    }

    /// Upload a cover image for a program
    @MainActor
    func uploadCoverImage(programId: String, image: UIImage) async throws -> String {
        struct CoverImageResponse: Decodable {
            let success: Bool
            let coverImageUrl: String?
            let error: String?
        }

        let data = try await api.uploadImage(endpoint: "/api/programs/\(programId)/cover-image", image: image)
        let response = try JSONDecoder.apiDecoder.decode(CoverImageResponse.self, from: data)

        guard response.success, let url = response.coverImageUrl else {
            throw APIError.serverError(response.error ?? "Failed to upload cover image")
        }

        // Update program in state
        if var program = state.programs[programId] {
            program.coverImageUrl = url
            state.programs.upsert(program)
            state.persist()
        }

        NSLog("📸 ProgramActions: Uploaded cover image for program \(programId)")
        return url
    }

    // MARK: - Lesson Operations

    /// Delete a lesson
    @MainActor
    func deleteLesson(programId: String, lessonId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/programs/\(programId)/lessons/\(lessonId)",
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete lesson")
        }

        // Remove from state
        let activityIds = state.lessonActivityIndex.get(lessonId)
        state.activities.removeMany(activityIds)
        state.lessonActivityIndex.removeAll(parentId: lessonId)
        state.lessons.remove(lessonId)
        state.programLessonIndex.remove(parentId: programId, childId: lessonId)

        // Refresh program to get updated lesson order
        _ = try await getProgram(id: programId)
    }

    /// Add a new lesson (day) to a program
    @MainActor
    func addLesson(programId: String) async throws -> Lesson {
        struct Response: Decodable {
            let success: Bool
            let lesson: Lesson?
            let error: String?
        }

        let response: Response = try await api.post(
            "/api/programs/\(programId)/lessons",
            body: [:],
            responseType: Response.self
        )

        guard response.success, let lesson = response.lesson else {
            throw APIError.serverError(response.error ?? "Failed to add lesson")
        }

        state.lessons.upsert(lesson)
        state.programLessonIndex.add(parentId: programId, childId: lesson.id)
        state.persist()

        NSLog("📚 ProgramActions: Added lesson day \(lesson.dayNumber) to program \(programId)")
        return lesson
    }

    /// Reorder lessons in a program
    @MainActor
    func reorderLessons(programId: String, lessonIds: [String]) async throws -> StudyProgram {
        let body: [String: Any] = ["lessonOrder": lessonIds]

        let response: CreateProgramResponse = try await api.post(
            "/api/programs/\(programId)/reorder-lessons",
            body: body,
            responseType: CreateProgramResponse.self
        )

        guard response.success, let program = response.program else {
            throw APIError.serverError(response.error ?? "Failed to reorder lessons")
        }

        state.programs.upsert(program)
        state.persist()

        return program
    }

    // MARK: - Activity Operations

    /// Update an activity with passage information
    @MainActor
    func updateActivity(
        activityId: String,
        passageReference: String,
        passageData: PassageData,
        highlightRange: HighlightRange? = nil
    ) async throws -> StudyActivity {
        var body: [String: Any] = [
            "passageReference": passageReference,
            "bookNumber": passageData.bookNumber,
            "bookName": passageData.bookName,
            "chapterStart": passageData.chapterStart,
            "verseStart": passageData.verseStart,
            "verseEnd": passageData.verseEnd,
            "status": "COMPLETE"
        ]

        if let chapterEnd = passageData.chapterEnd {
            body["chapterEnd"] = chapterEnd
        }

        if let range = highlightRange {
            body["startElementId"] = range.startElementId
            body["startOffset"] = range.startOffset
            body["endElementId"] = range.endElementId
            body["endOffset"] = range.endOffset
        }

        let response: UpdateActivityResponse = try await api.patch(
            "/api/activities/\(activityId)",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to update activity")
        }

        state.activities.upsert(activity)
        state.persist()

        return activity
    }

    /// Update an activity's video
    @MainActor
    func updateActivityVideo(activityId: String, videoId: String, videoUrl: String) async throws -> StudyActivity {
        let body: [String: Any] = [
            "videoId": videoId,
            "videoUrl": videoUrl,
            "status": "COMPLETE"
        ]

        let response: UpdateActivityResponse = try await api.patch(
            "/api/activities/\(activityId)",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to update activity video")
        }

        state.activities.upsert(activity)
        state.persist()

        return activity
    }

    /// Update a YOUTUBE activity with URL and optional time bounds
    func updateActivityYouTube(
        activityId: String,
        title: String,
        youtubeUrl: String,
        startSeconds: Int? = nil,
        endSeconds: Int? = nil
    ) async throws -> StudyActivity {
        var body: [String: Any] = [
            "title": title,
            "youtubeUrl": youtubeUrl,
            "status": "COMPLETE"
        ]

        if let startSeconds = startSeconds { body["youtubeStartSeconds"] = startSeconds }
        if let endSeconds = endSeconds { body["youtubeEndSeconds"] = endSeconds }

        NSLog("📹 Saving YouTube activity \(activityId): url=\(youtubeUrl), title=\(title)")

        let response: UpdateActivityResponse = try await api.patch(
            "/api/activities/\(activityId)",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        NSLog("📹 YouTube save response: success=\(response.success), error=\(response.error ?? "none")")

        guard response.success, var activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to update YouTube activity")
        }

        // Ensure YouTube fields are present on the upserted activity in case
        // the server response doesn't echo them back
        if activity.youtubeUrl == nil || activity.youtubeUrl!.isEmpty {
            activity.youtubeUrl = youtubeUrl
        }
        if activity.title == nil || activity.title!.isEmpty {
            activity.title = title
        }
        if let startSeconds = startSeconds { activity.youtubeStartSeconds = startSeconds }
        if let endSeconds = endSeconds { activity.youtubeEndSeconds = endSeconds }

        state.activities.upsert(activity)
        state.persist()

        return activity
    }

    /// Add an activity to a lesson
    @MainActor
    func addActivity(programId: String, lessonId: String, type: ActivityType, title: String? = nil) async throws -> StudyActivity {
        var body: [String: Any] = [
            "activityType": type.rawValue
        ]
        if let title = title {
            body["title"] = title
        } else if type != .userInput {
            body["title"] = type.displayName
        }

        NSLog("🎬 ProgramActions.addActivity: POST /api/programs/\(programId)/lessons/\(lessonId)/activities body=\(body)")

        let response: UpdateActivityResponse = try await api.post(
            "/api/programs/\(programId)/lessons/\(lessonId)/activities",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        NSLog("🎬 ProgramActions.addActivity response: success=\(response.success) error=\(response.error ?? "none")")

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to add activity")
        }

        state.activities.upsert(activity)
        state.lessonActivityIndex.add(parentId: lessonId, childId: activity.id)
        state.persist()

        return activity
    }

    /// Reorder activities in a lesson
    @MainActor
    func reorderActivities(programId: String, lessonId: String, activityIds: [String]) async throws -> [StudyActivity] {
        struct ReorderResponse: Decodable {
            let success: Bool
            let activities: [StudyActivity]?
            let error: String?
        }

        let body: [String: Any] = ["activityOrder": activityIds]

        let response: ReorderResponse = try await api.post(
            "/api/programs/\(programId)/lessons/\(lessonId)/reorder-activities",
            body: body,
            responseType: ReorderResponse.self
        )

        guard response.success, let activities = response.activities else {
            throw APIError.serverError(response.error ?? "Failed to reorder activities")
        }

        // Update activities in state
        for activity in activities {
            state.activities.upsert(activity)
        }
        state.persist()

        NSLog("📋 ProgramActions: Reordered \(activities.count) activities in lesson \(lessonId)")
        return activities
    }

    /// Delete an activity
    @MainActor
    func deleteActivity(activityId: String) async throws {
        let response: APISuccessResponse = try await api.delete(
            "/api/activities/\(activityId)",
            responseType: APISuccessResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete activity")
        }

        state.activities.remove(activityId)
        state.lessonActivityIndex.removeChild(activityId)
        state.persist()
    }

    /// Update activity content fields (title, readContent, help text, icon)
    @MainActor
    func updateActivityContent(
        activityId: String,
        title: String? = nil,
        readContent: String? = nil,
        isHelpEnabled: Bool? = nil,
        helpAlwaysVisible: Bool? = nil,
        helpTitle: String? = nil,
        helpDescription: String? = nil,
        helpIcon: String? = nil
    ) async throws -> StudyActivity {
        var body: [String: Any] = [
            "status": "COMPLETE"
        ]

        if let title = title { body["title"] = title }
        if let readContent = readContent { body["readContent"] = readContent }
        if let isHelpEnabled = isHelpEnabled { body["isHelpEnabled"] = isHelpEnabled }
        if let helpAlwaysVisible = helpAlwaysVisible { body["helpAlwaysVisible"] = helpAlwaysVisible }
        if let helpTitle = helpTitle { body["helpTitle"] = helpTitle }
        if let helpDescription = helpDescription { body["helpDescription"] = helpDescription }
        if let helpIcon = helpIcon { body["helpIcon"] = helpIcon }

        let response: UpdateActivityResponse = try await api.patch(
            "/api/activities/\(activityId)",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to update activity content")
        }

        state.activities.upsert(activity)
        state.persist()

        return activity
    }

    /// Add a source reference to an activity, optionally with verse HTML content
    /// Returns the updated activity with all readBlocks
    @MainActor
    func addSourceReference(activityId: String, passageData: PassageData, content: String? = nil) async throws -> StudyActivity? {
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
            let activity: StudyActivity?
            let error: String?
        }

        NSLog("📖 addSourceReference: POST /api/activities/\(activityId)/source-references")
        let response: SourceRefResponse = try await api.post(
            "/api/activities/\(activityId)/source-references",
            body: body,
            responseType: SourceRefResponse.self
        )
        NSLog("📖 addSourceReference: success=\(response.success), hasActivity=\(response.activity != nil), hasRef=\(response.sourceReference != nil), error=\(response.error ?? "none")")

        if let activity = response.activity {
            NSLog("📖 addSourceReference: Activity has \(activity.readBlocks?.count ?? 0) readBlocks")
            state.activities.upsert(activity)
            state.persist()
            return activity
        }

        return nil
    }

    // MARK: - Exegesis Highlights

    @MainActor
    func fetchExegesisHighlights(activityId: String) async throws -> (readBlockId: String?, highlights: [ExegesisHighlight]) {
        struct ResponseBody: Decodable {
            let success: Bool
            let readBlockId: String?
            let highlights: [ExegesisHighlight]?
            let error: String?
        }

        let response: ResponseBody = try await api.get(
            "/api/activities/\(activityId)/exegesis-highlights",
            responseType: ResponseBody.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to fetch exegesis highlights")
        }

        return (response.readBlockId, response.highlights ?? [])
    }

    @MainActor
    func createExegesisHighlight(activityId: String, readBlockId: String, start: Int, end: Int, noteMarkdown: String = "") async throws -> ExegesisHighlight {
        struct ResponseBody: Decodable {
            let success: Bool
            let highlight: ExegesisHighlight?
            let error: String?
        }

        let body: [String: Any] = [
            "readBlockId": readBlockId,
            "start": start,
            "end": end,
            "noteMarkdown": noteMarkdown,
        ]

        let response: ResponseBody = try await api.post(
            "/api/activities/\(activityId)/exegesis-highlights",
            body: body,
            responseType: ResponseBody.self
        )

        guard response.success, let highlight = response.highlight else {
            throw APIError.serverError(response.error ?? "Failed to create highlight")
        }

        return highlight
    }

    @MainActor
    func updateExegesisHighlight(activityId: String, highlightId: String, noteMarkdown: String) async throws -> ExegesisHighlight {
        struct ResponseBody: Decodable {
            let success: Bool
            let highlight: ExegesisHighlight?
            let error: String?
        }

        let body: [String: Any] = ["noteMarkdown": noteMarkdown]

        let response: ResponseBody = try await api.patch(
            "/api/activities/\(activityId)/exegesis-highlights/\(highlightId)",
            body: body,
            responseType: ResponseBody.self
        )

        guard response.success, let highlight = response.highlight else {
            throw APIError.serverError(response.error ?? "Failed to update highlight")
        }

        return highlight
    }

    @MainActor
    func deleteExegesisHighlight(activityId: String, highlightId: String) async throws {
        struct ResponseBody: Decodable {
            let success: Bool
            let error: String?
        }

        let response: ResponseBody = try await api.delete(
            "/api/activities/\(activityId)/exegesis-highlights/\(highlightId)",
            responseType: ResponseBody.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete highlight")
        }
    }

    // MARK: - Read Block Operations

    /// Create a read block for an activity
    @MainActor
    func createReadBlock(
        activityId: String,
        title: String? = nil,
        content: String? = nil,
        isLocked: Bool = false,
        orderNumber: Int? = nil
    ) async throws -> StudyActivity? {
        var body: [String: Any] = [
            "isLocked": isLocked,
            "contentFormat": "markdown"
        ]
        if let title = title { body["title"] = title }
        if let content = content { body["content"] = content }
        if let orderNumber = orderNumber { body["orderNumber"] = orderNumber }

        struct ReadBlockResponse: Decodable {
            let success: Bool
            let block: ActivityReadBlock?
            let activity: StudyActivity?
            let error: String?
        }

        let response: ReadBlockResponse = try await api.post(
            "/api/activities/\(activityId)/read-blocks",
            body: body,
            responseType: ReadBlockResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to create read block")
        }

        if let activity = response.activity {
            state.activities.upsert(activity)
            state.persist()
            return activity
        }

        return nil
    }

    /// Update a read block's content and sync to AppState
    @MainActor
    func updateReadBlock(activityId: String, blockId: String, content: String?) async throws {
        var body: [String: Any] = [
            "contentFormat": "markdown"
        ]
        if let content = content {
            body["content"] = content
        } else {
            body["content"] = NSNull()
        }

        let response: ReadBlockMutationResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: ReadBlockMutationResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to update read block")
        }

        // Update the block in the stored activity's readBlocks array
        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[index].content = content
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }
    }

    /// Save the array of styled selections for a read block. Pass an empty array to clear.
    @MainActor
    func updateReadBlockSelections(activityId: String, blockId: String, selections: [ReadBlockSelection]) async throws {
        let body: [String: Any] = [
            "selections": selections.map { ["start": $0.start, "end": $0.end, "style": $0.style] }
        ]

        let response: ReadBlockMutationResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: ReadBlockMutationResponse.self
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
    }

    /// Delete a read block, returns updated activity
    @MainActor
    func deleteReadBlock(activityId: String, blockId: String) async throws -> StudyActivity? {
        struct DeleteBlockResponse: Decodable {
            let success: Bool
            let activity: StudyActivity?
            let error: String?
        }

        let response: DeleteBlockResponse = try await api.delete(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            responseType: DeleteBlockResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete read block")
        }

        if let activity = response.activity {
            state.activities.upsert(activity)
            state.persist()
            return activity
        }

        return nil
    }

    /// Set or clear the t-shirt font-size key on a read block. Values:
    /// "xs" | "s" | "m" | "lg" | "xl". Pass nil to revert to default (m).
    /// The rendered em size is mapped client-side (iPhone + web ThemePlayer).
    @MainActor
    func setReadBlockFontSize(activityId: String, blockId: String, fontSize: String?) async throws {
        var body: [String: Any] = [:]
        body["fontSize"] = fontSize.map { $0 as Any } ?? NSNull()

        struct BlockUpdateResponse: Decodable {
            let success: Bool
            let error: String?
        }

        let response: BlockUpdateResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: BlockUpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to set read block font size")
        }

        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[index].fontSize = fontSize
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }

        NSLog("🎨 ProgramActions: Set fontSize=\(fontSize ?? "nil") on block \(blockId)")
    }

    /// Set or clear the theme on a read block
    @MainActor
    func setReadBlockTheme(activityId: String, blockId: String, themeId: String?) async throws {
        var body: [String: Any] = [:]
        if let themeId = themeId {
            body["themeId"] = themeId
        } else {
            body["themeId"] = NSNull()
        }

        struct BlockUpdateResponse: Decodable {
            let success: Bool
            let error: String?
        }

        let response: BlockUpdateResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: BlockUpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to set read block theme")
        }

        // Update the block in the stored activity's readBlocks array
        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            blocks[index].themeId = themeId
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }

        NSLog("🎨 ProgramActions: Set theme \(themeId ?? "nil") on block \(blockId)")
    }

    /// Set the background of a read block — solid color (hex), an image URL,
    /// both, or clear them. Pass `nil` for a field to leave it untouched;
    /// pass `.some(nil)` (i.e. wrap with a sentinel) to clear. To keep the
    /// API tiny we use two explicit "clear" booleans instead.
    @MainActor
    func setReadBlockBackground(
        activityId: String,
        blockId: String,
        imageUrl: String? = nil,
        color: String? = nil,
        overlayOpacity: Double? = nil,
        clearImage: Bool = false,
        clearColor: Bool = false,
        clearOverlayOpacity: Bool = false
    ) async throws {
        var body: [String: Any] = [:]
        if clearImage {
            body["backgroundImageUrl"] = NSNull()
        } else if let imageUrl = imageUrl {
            body["backgroundImageUrl"] = imageUrl
        }
        if clearColor {
            body["backgroundColor"] = NSNull()
        } else if let color = color {
            body["backgroundColor"] = color
        }
        if clearOverlayOpacity {
            body["backgroundOverlayOpacity"] = NSNull()
        } else if let opacity = overlayOpacity {
            body["backgroundOverlayOpacity"] = opacity
        }

        guard !body.isEmpty else { return }

        struct BlockUpdateResponse: Decodable {
            let success: Bool
            let error: String?
        }

        let response: BlockUpdateResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/\(blockId)",
            body: body,
            responseType: BlockUpdateResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to set read block background")
        }

        if var activity = state.activities[activityId],
           var blocks = activity.readBlocks,
           let index = blocks.firstIndex(where: { $0.id == blockId }) {
            if clearImage      { blocks[index].backgroundImageUrl = nil }
            else if let url = imageUrl { blocks[index].backgroundImageUrl = url }
            if clearColor      { blocks[index].backgroundColor = nil }
            else if let c = color      { blocks[index].backgroundColor = c }
            if clearOverlayOpacity { blocks[index].backgroundOverlayOpacity = nil }
            else if let o = overlayOpacity { blocks[index].backgroundOverlayOpacity = o }
            blocks[index].updatedAt = Date()
            activity.readBlocks = blocks
            state.activities.upsert(activity)
            state.persist()
        }

        let opacityStr = overlayOpacity.map { "\($0)" } ?? "nil"
        NSLog("🎨 ProgramActions: Set background (image=\(imageUrl ?? "nil") color=\(color ?? "nil") opacity=\(opacityStr) clearImage=\(clearImage) clearColor=\(clearColor) clearOpacity=\(clearOverlayOpacity)) on block \(blockId)")
    }

    /// Reorder read blocks, returns updated activity
    @MainActor
    func reorderReadBlocks(activityId: String, blockIds: [String]) async throws -> StudyActivity? {
        let body: [String: Any] = ["blockIds": blockIds]

        struct ReorderBlocksResponse: Decodable {
            let success: Bool
            let activity: StudyActivity?
            let error: String?
        }

        let response: ReorderBlocksResponse = try await api.patch(
            "/api/activities/\(activityId)/read-blocks/reorder",
            body: body,
            responseType: ReorderBlocksResponse.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to reorder read blocks")
        }

        if let activity = response.activity {
            state.activities.upsert(activity)
            state.persist()
            return activity
        }

        return nil
    }

    /// Reset an activity to pending state
    @MainActor
    func resetActivity(activityId: String) async throws -> StudyActivity {
        let response: UpdateActivityResponse = try await api.post(
            "/api/activities/\(activityId)/reset",
            responseType: UpdateActivityResponse.self
        )

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to reset activity")
        }

        state.activities.upsert(activity)
        state.persist()

        return activity
    }

    // MARK: - Remove Activity Video

    /// Remove a video from an activity, resetting it to pending state
    @MainActor
    func removeActivityVideo(activityId: String) async throws -> StudyActivity {
        let body: [String: Any] = [
            "videoId": NSNull(),
            "videoUrl": NSNull(),
            "status": "PENDING"
        ]

        let response: UpdateActivityResponse = try await api.patch(
            "/api/activities/\(activityId)",
            body: body,
            responseType: UpdateActivityResponse.self
        )

        guard response.success, let activity = response.activity else {
            throw APIError.serverError(response.error ?? "Failed to remove activity video")
        }

        state.activities.upsert(activity)
        state.persist()

        NSLog("📹 ProgramActions: Removed video from activity \(activityId)")
        return activity
    }

    // MARK: - Program Enrollments

    /// Get all enrollments for a study program, using cache if available
    /// - Parameters:
    ///   - programId: Program ID
    ///   - forceRefresh: If true, always fetch from API
    @MainActor
    func getProgramEnrollments(programId: String, forceRefresh: Bool = false) async throws -> [ProgramEnrollment] {
        // Check cache first
        let hasCached = state.hasCachedProgramEnrollments(programId: programId)

        if hasCached && !forceRefresh {
            // Return cached data, refresh in background
            NSLog("📚 ProgramActions: Using cached program enrollments for \(programId)")
            Task {
                do {
                    _ = try await fetchProgramEnrollments(programId: programId)
                } catch {
                    NSLog("⚠️ ProgramActions: Background refresh of program enrollments failed: \(error)")
                }
            }
            return state.programEnrollmentsFor(programId: programId)
        }

        return try await fetchProgramEnrollments(programId: programId)
    }

    /// Fetch program enrollments from API and store in cache
    @MainActor
    private func fetchProgramEnrollments(programId: String) async throws -> [ProgramEnrollment] {
        struct Response: Decodable {
            let success: Bool
            let enrollments: [ProgramEnrollment]?
            let error: String?
        }

        let response: Response = try await api.get(
            "/api/programs/\(programId)/enrollments",
            responseType: Response.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to fetch enrollments")
        }

        let enrollments = response.enrollments ?? []

        // Store in cache - REPLACE index to remove stale entries
        let enrollmentIds = enrollments.map { $0.id }
        state.programProgramEnrollmentIndex.replace(parentId: programId, childIds: enrollmentIds)

        for enrollment in enrollments {
            state.programEnrollments.upsert(enrollment)
        }
        state.persist()

        NSLog("📚 ProgramActions: Fetched \(enrollments.count) program enrollments for \(programId)")
        return enrollments
    }
}
