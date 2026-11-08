//
//  ActivityActions.swift
//  MakeReady
//
//  The lesson-version draft endpoints (SPEC §Contract rows 1-6). Each Action decodes the contract
//  shape, writes `AppState.activities`, `lessonVersions` and `mediaMap`, and refreshes what the
//  program home derives from them in the same call. Routing a failure to the banner is the
//  container's job (/ios-error-surface); a 409 NOT_DRAFT is the one failure named here (D46).
//

import Foundation

/// A draft write the server refused.
enum ActivityActionsError: Error, Equatable {
    /// 409 `NOT_DRAFT`: another leader published, so the version is frozen (D46).
    case notDraft
    /// 404 on a draft write: a publish with no changes deleted the draft and its activities (D46).
    case gone
}

/// What the activity editor calls (text-activity Task 25), so its save and back-out paths can be
/// tested over a scripted double.
@MainActor
protocol ActivityActionsProtocol {
    /// Reloads the lesson's draft into state and returns its activities (D46's refetch).
    func reloadDraft(lessonId: String) async throws -> [ContentActivity]
    func save(activityId: String, title: String?, document: ActivityDocument) async throws
    func delete(activityId: String) async throws
}

struct ActivityActions {

    let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // MARK: - Reads

    /// `GET /api/lessons/:id/draft` — the lesson's draft (created from the latest published version
    /// when it has none) with its activities.
    @MainActor
    func loadDraft(lessonId: String) async throws {
        let payload: LessonVersionPayload = try await api.get("/api/lessons/\(lessonId)/draft",
                                                              responseType: LessonVersionPayload.self)
        apply(payload)
    }

    /// `GET /api/lesson-versions/:id` — any version, read-only (the viewer).
    @MainActor
    func loadVersion(id: String) async throws {
        let payload: LessonVersionPayload = try await api.get("/api/lesson-versions/\(id)",
                                                              responseType: LessonVersionPayload.self)
        apply(payload)
    }

    /// `GET /api/lessons/:id/draft`, then the reloaded draft's activities. The newest program draft
    /// is read by `number`: a draft another leader published stays in the store until it is reloaded.
    @MainActor
    func reloadDraft(lessonId: String) async throws -> [ContentActivity] {
        try await loadDraft(lessonId: lessonId)
        let draft = state.lessonVersions.all
            .filter { $0.lessonId == lessonId && $0.status == .draft && $0.enrollmentId == nil }
            .max { $0.number < $1.number }
        return draft.map { state.activities(forVersion: $0.id) } ?? []
    }

    // MARK: - Writes

    /// `POST /api/lesson-versions/:id/activities` — appends a new activity. Returns it because the
    /// Text tile swaps to the editor on the created row.
    @MainActor
    @discardableResult
    func create(versionId: String, kind: String, title: String, document: ActivityDocument) async throws -> ContentActivity {
        let body: [String: Any] = ["kind": kind, "title": title, "document": try Self.json(document)]
        let response = try await write("/api/lesson-versions/\(versionId)/activities", method: "POST", body: body)
        state.activities.upsert(response.activity)
        state.mergeMedia(response.media)
        settle(versionId: response.activity.lessonVersionId)
        return response.activity
    }

    /// `PUT /api/content-activities/:id` — the whole document, saved on Done. `title` is sent only
    /// when it changed.
    @MainActor
    func save(activityId: String, title: String?, document: ActivityDocument) async throws {
        var body: [String: Any] = ["document": try Self.json(document)]
        if let title { body["title"] = title }
        let response = try await write("/api/content-activities/\(activityId)", method: "PUT", body: body)
        state.activities.upsert(response.activity)
        state.mergeMedia(response.media)
        settle(versionId: response.activity.lessonVersionId)
    }

    /// `DELETE /api/content-activities/:id` — the server closes the positions up, and so does the store.
    @MainActor
    func delete(activityId: String) async throws {
        let versionId = state.activities[activityId]?.lessonVersionId
        _ = try await send("/api/content-activities/\(activityId)", method: "DELETE", body: nil)
        state.activities.remove(activityId)
        if let versionId {
            for (position, row) in state.activities(forVersion: versionId).enumerated() where row.position != position {
                state.activities.upsert(row.moved(to: position))
            }
            settle(versionId: versionId)
        }
    }

    /// `PATCH /api/lesson-versions/:id/activities/order` — `activityIds` is the exact set, in the new order.
    @MainActor
    func reorder(versionId: String, activityIds: [String]) async throws {
        struct Response: Decodable { let activities: [ContentActivity] }
        let data = try await send("/api/lesson-versions/\(versionId)/activities/order", method: "PATCH",
                                  body: ["activityIds": activityIds])
        let response = try JSONDecoder.apiDecoder.decode(Response.self, from: data)
        state.activities.upsertMany(response.activities)
        settle(versionId: versionId)
    }

    // MARK: - Internals

    private struct WriteResponse: Decodable {
        let activity: ContentActivity
        let media: [String: MediaMapEntry]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            activity = try c.decode(ContentActivity.self, forKey: .activity)
            media = try c.decodeIfPresent([String: MediaMapEntry].self, forKey: .media) ?? [:]
        }

        enum CodingKeys: String, CodingKey { case activity, media }
    }

    /// A write that returns `{ activity, media }`.
    @MainActor
    private func write(_ endpoint: String, method: String, body: [String: Any]?) async throws -> WriteResponse {
        let data = try await send(endpoint, method: method, body: body)
        return try JSONDecoder.apiDecoder.decode(WriteResponse.self, from: data)
    }

    /// The status-keeping request, with a 409 `NOT_DRAFT` turned into `ActivityActionsError.notDraft` and a
    /// 404 on a PUT into `.gone`. Every other failure (a 409 `CONFLICT`, a 413) is thrown as the status error.
    @MainActor
    private func send(_ endpoint: String, method: String, body: [String: Any]?) async throws -> Data {
        do {
            return try await api.requestWithStatus(endpoint: endpoint, method: method, body: body)
        } catch let error as APIHTTPError where error.status == 409 && error.details["code"] == "NOT_DRAFT" {
            throw ActivityActionsError.notDraft
        } catch let error as APIHTTPError where error.status == 404 && method == "PUT" {
            throw ActivityActionsError.gone
        }
    }

    /// Write a loaded version into the stores: replace its activities wholesale, so one deleted
    /// elsewhere drops, then refresh the lesson row.
    @MainActor
    private func apply(_ payload: LessonVersionPayload) {
        // A loaded program draft replaces the lesson's other program drafts: a publish made elsewhere froze
        // or deleted them, and a stale one must not be picked as the draft again (D46).
        var replaced = [payload.version.id]
        if payload.version.status == .draft && payload.version.enrollmentId == nil {
            let others = state.lessonVersions.all.filter {
                $0.lessonId == payload.version.lessonId && $0.status == .draft && $0.enrollmentId == nil
                    && $0.id != payload.version.id
            }.map(\.id)
            state.lessonVersions.removeMany(others)
            replaced += others
        }
        let stale = state.activities.all.filter { replaced.contains($0.lessonVersionId) }.map(\.id)
        state.activities.removeMany(stale)
        state.activities.upsertMany(payload.activities)
        state.lessonVersions.upsert(payload.version)
        state.mergeMedia(payload.media)
        settle(versionId: payload.version.id)
    }

    /// Refresh the derived state (the lesson row's rail summaries and estimate) and persist.
    @MainActor
    private func settle(versionId: String) {
        state.refreshLessonSummary(versionId: versionId)
        state.persist()
    }

    /// The document as a JSON object for a request body, unknown fields included.
    private static func json(_ document: ActivityDocument) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(document), options: [.fragmentsAllowed])
    }
}

/// In an extension, so the protocol's `@MainActor` isn't inferred onto the whole struct (its init
/// stays callable from any context; every method it names is `@MainActor` already).
extension ActivityActions: ActivityActionsProtocol {}

private extension ContentActivity {
    func moved(to position: Int) -> ContentActivity {
        ContentActivity(id: id, lessonVersionId: lessonVersionId, activityKey: activityKey, position: position,
                        kind: kind, title: title, document: document, estimatedSeconds: estimatedSeconds)
    }
}
