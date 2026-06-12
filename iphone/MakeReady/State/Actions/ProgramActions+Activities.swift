//
//  ProgramActions+Activities.swift
//  MakeReady
//
//  Activity-related methods for ProgramActions: activity CRUD, exegesis
//  highlights, and read-block operations.
//  Phase 5.7 — code motion from ProgramActions.swift; extensions, not new
//  types, so call sites are untouched. A future pass may promote these to a
//  real ActivityActions type.
//

import Foundation

/// Shared response shape for read-block mutation endpoints.
private struct ReadBlockMutationResponse: Decodable {
    let success: Bool
    let error: String?
}

extension ProgramActions {

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
    @MainActor
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

    /// Update activity content fields (title, readContent, help text)
    @MainActor
    func updateActivityContent(
        activityId: String,
        title: String? = nil,
        readContent: String? = nil,
        isHelpEnabled: Bool? = nil,
        helpTitle: String? = nil,
        helpDescription: String? = nil,
        placeholder: String? = nil
    ) async throws -> StudyActivity {
        var body: [String: Any] = [
            "status": "COMPLETE"
        ]

        if let title = title { body["title"] = title }
        if let readContent = readContent { body["readContent"] = readContent }
        if let isHelpEnabled = isHelpEnabled { body["isHelpEnabled"] = isHelpEnabled }
        if let helpTitle = helpTitle { body["helpTitle"] = helpTitle }
        if let helpDescription = helpDescription { body["helpDescription"] = helpDescription }
        if let placeholder = placeholder { body["placeholder"] = placeholder }

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
}
