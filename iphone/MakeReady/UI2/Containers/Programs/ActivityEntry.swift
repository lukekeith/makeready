import Foundation

/// text-activity D14/D39: the one rule for "open this activity". A canvas kind (`text`, and the imported
/// `bible`) opens the Text editor; every other kind plays in the viewer but cannot be edited yet.
enum ActivityEntry {
    enum Result: Equatable {
        case open(UI2Destination)
        case cannotEdit(message: String)
    }

    static let cannotEditMessage = "This activity can't be edited yet."

    /// The kinds the Text editor opens.
    static let canvasKinds = ["text", "bible"]

    static func destination(for kind: String, activityId: String) -> Result {
        canvasKinds.contains(kind) ? .open(.activitiesEditor(activityId: activityId)) : .cannotEdit(message: cannotEditMessage)
    }

    /// Applies the rule to one tap: pushes the editor, or hands the message to `report` (the banner).
    @MainActor
    static func open(kind: String, activityId: String, push: (UI2Destination) -> Void,
                     report: (String) -> Void = ActivityEntry.surface) {
        switch destination(for: kind, activityId: activityId) {
        case .open(let destination): push(destination)
        case .cannotEdit(let message): report(message)
        }
    }

    /// The error-banner channel (/ios-error-surface): a user-facing message, with no retry.
    @MainActor
    static func surface(_ message: String) {
        AppState.shared.recordError(CannotEdit(), context: "ActivityEntry.open", surface: true, friendlyMessage: message)
    }

    private struct CannotEdit: Error {}
}
