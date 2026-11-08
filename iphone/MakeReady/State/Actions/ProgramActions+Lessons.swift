//
//  ProgramActions+Lessons.swift
//  MakeReady
//
//  Lesson-related methods for ProgramActions.
//  Phase 5.7 — code motion from ProgramActions.swift; extensions, not new
//  types, so call sites are untouched. A future pass may promote these to a
//  real LessonActions type.
//

import Foundation

extension ProgramActions {

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
        forgetLessonVersions(lessonId: lessonId)
        state.lessons.remove(lessonId)
        state.programLessonIndex.remove(parentId: programId, childId: lessonId)
        state.persist()
    }

    /// Add a new lesson (day) to a program
    @MainActor
    func addLesson(programId: String) async throws -> Lesson {
        struct Response: Decodable {
            let success: Bool
            let lesson: Lesson?
            let media: [String: MediaMapEntry]?
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
        state.mergeMedia(response.media ?? [:])
        state.persist()

        Log.state.info("added lesson \(lesson.position, privacy: .public) to a program")
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
}

extension ProgramActions {
    /// Drop a lesson's loaded versions and their activities from the stores (the lesson is gone).
    @MainActor
    func forgetLessonVersions(lessonId: String) {
        let versionIds = state.lessonVersions.all.filter { $0.lessonId == lessonId }.map(\.id)
        let activityIds = state.activities.all.filter { versionIds.contains($0.lessonVersionId) }.map(\.id)
        state.activities.removeMany(activityIds)
        state.lessonVersions.removeMany(versionIds)
    }
}
