import Foundation

/// activity-slide-menu (owner 2026-11-09): a touch-and-hold on an activity's screenshot in a lesson's rail on
/// study-program-home opens Edit · Duplicate · Delete. Duplicate and Delete act on the lesson's draft — the version
/// the editor edits — on the draft activity with the tapped slide's `activityKey`; Edit opens it as a tap does.
enum ActivitySlideMenu {
    enum Choice: String {
        case edit = "Edit activity"
        case duplicate = "Duplicate activity"
        case delete = "Delete activity"
    }

    static let rows: [ActionMenuOverlay.ActionItem] = [
        .init(glyph: "edit", label: Choice.edit.rawValue),
        .init(glyph: "copy", label: Choice.duplicate.rawValue),
        .init(glyph: "trash-2", label: Choice.delete.rawValue, tone: .destructive)
    ]

    static let deleteConfirmTitle = "Delete activity?"
    static let deleteConfirmMessage = "It's removed from this lesson. This can't be undone."
    static let deleteConfirmAction = ActionMenuOverlay.ActionItem(glyph: "", label: "Delete activity", tone: .destructive)
    static let duplicateFailedMessage = "Couldn't duplicate activity"
    static let deleteFailedMessage = "Couldn't delete activity"

    /// The draft operations, injectable for tests.
    struct Ops {
        /// The lesson's draft activities in order (the draft is loaded first).
        var draftActivities: @MainActor (_ lessonId: String) async throws -> [ContentActivity]
        /// `POST /api/lesson-versions/:id/activities` → the new activity's id (appended last).
        var create: @MainActor (_ versionId: String, _ kind: String, _ title: String, _ document: ActivityDocument) async throws -> String
        /// `PATCH /api/lesson-versions/:id/activities/order` — the exact set, in order.
        var reorder: @MainActor (_ versionId: String, _ ids: [String]) async throws -> Void
        /// `DELETE /api/content-activities/:id`.
        var delete: @MainActor (_ activityId: String) async throws -> Void

        static var live: Ops {
            Ops(
                draftActivities: { lessonId in
                    try await ActivityActions().loadDraft(lessonId: lessonId)
                    guard let versionId = AppState.shared.draftVersionId(forLesson: lessonId) else { throw MissingDraft() }
                    return AppState.shared.activities(forVersion: versionId)
                },
                create: { versionId, kind, title, document in
                    try await ActivityActions().create(versionId: versionId, kind: kind, title: title, document: document).id
                },
                reorder: { versionId, ids in try await ActivityActions().reorder(versionId: versionId, activityIds: ids) },
                delete: { id in try await ActivityActions().delete(activityId: id) }
            )
        }
    }

    struct MissingDraft: Error {}
    struct MissingActivity: Error {}

    /// The draft's order with `newId` moved to sit right after `sourceId` (owner 2026-11-09).
    static func order(_ ids: [String], placing newId: String, after sourceId: String) -> [String] {
        var rest = ids.filter { $0 != newId }
        guard let index = rest.firstIndex(of: sourceId) else { return rest + [newId] }
        rest.insert(newId, at: index + 1)
        return rest
    }

    /// Duplicate: a copy with the same kind, title and document lands right after the original.
    @MainActor
    static func duplicate(activityKey: String, lessonId: String, ops: Ops = .live) async throws {
        let draft = try await ops.draftActivities(lessonId)
        guard let source = draft.first(where: { $0.activityKey == activityKey }) else { throw MissingActivity() }
        let newId = try await ops.create(source.lessonVersionId, source.kind, source.title, source.document)
        let ids = order(draft.map(\.id) + [newId], placing: newId, after: source.id)
        try await ops.reorder(source.lessonVersionId, ids)
    }

    /// Delete: the draft activity with this key is deleted (the server closes the positions up).
    @MainActor
    static func delete(activityKey: String, lessonId: String, ops: Ops = .live) async throws {
        let draft = try await ops.draftActivities(lessonId)
        guard let target = draft.first(where: { $0.activityKey == activityKey }) else { throw MissingActivity() }
        try await ops.delete(target.id)
    }
}
