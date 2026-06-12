//
//  ProgramActions.swift
//  MakeReady
//
//  Actions for study program operations.
//  Handles API calls, state mutations, and persistence.
//

import Foundation
import UIKit

/// Actions for study program CRUD and lesson/activity management.
/// Lesson and activity methods live in ProgramActions+Lessons.swift and
/// ProgramActions+Activities.swift (Phase 5.7 split — extensions, so call
/// sites are untouched). `api` and `state` became internal (were private)
/// so those same-module extension files can use them.
struct ProgramActions {

let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

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
                    state.recordError(error, context: "ProgramActions.loadPrograms (background refresh)")
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
                    state.recordError(error, context: "ProgramActions.loadTemplates (background refresh)")
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

    // MARK: - Export / Import / YouTube Metadata

    /// Fetch YouTube metadata for a URL and return the video title (if any).
    /// Rehomed from EditYouTubeActivityPage (Phase 2.4) — same request; the
    /// page only consumed `metadata.title`.
    @MainActor
    func fetchYouTubeMetadataTitle(url: String) async throws -> String? {
        struct MetadataResponse: Codable {
            struct Metadata: Codable {
                let title: String?
            }
            let success: Bool
            let metadata: Metadata?
            let error: String?
        }

        let response: MetadataResponse = try await api.post(
            "/api/youtube/metadata",
            body: ["url": url],
            responseType: MetadataResponse.self
        )
        return response.metadata?.title
    }

    /// Fetch the raw export-preview JSON for a program.
    /// Rehomed from ProgramHomePage (Phase 2.4); the page keeps its
    /// dictionary-walking presentation logic.
    @MainActor
    func loadExportPreviewData(programId: String) async throws -> Data {
        try await api.request(endpoint: "/api/programs/\(programId)/export-preview")
    }

    /// Export a program as a .makeready archive; returns the file bytes.
    /// Rehomed from ProgramHomePage (Phase 2.4).
    @MainActor
    func exportProgramData(programId: String) async throws -> Data {
        try await api.request(endpoint: "/api/programs/\(programId)/export", method: "POST")
    }

    /// Import a .makeready archive. Builds the multipart body and throws
    /// APIError.serverError with the server's message on failure.
    /// Rehomed from MainLibrary + StudyProgramHome (Phase 2.4), which carried
    /// verbatim copies of this multipart assembly.
    @MainActor
    func importProgram(fileData: Data) async throws {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"import.makeready\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let response = try await api.upload(
            endpoint: "/api/programs/import",
            boundary: boundary,
            body: body
        )

        guard let json = try? JSONSerialization.jsonObject(with: response) as? [String: Any],
              let success = json["success"] as? Bool, success else {
            let errorMsg = ((try? JSONSerialization.jsonObject(with: response) as? [String: Any])?["error"] as? String) ?? "Import failed"
            throw APIError.serverError(errorMsg)
        }
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
                    state.recordError(error, context: "ProgramActions.loadProgramEnrollments (background refresh)")
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
