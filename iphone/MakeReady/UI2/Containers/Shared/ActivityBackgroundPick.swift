import Foundation
import Observation

/// text-activity D40: how the Media pick mode returns a `mediaId` to the editor that asked. A destination
/// is `Hashable` and cannot hold a closure, so the pick is delivered here, keyed by the activity being
/// edited; the editor reads it with `take(for:)` when its page is back on top, which clears it.
@Observable
@MainActor
final class ActivityBackgroundPick {
    static let shared = ActivityBackgroundPick()

    /// The picked media ids waiting for their editor, by activity id.
    private(set) var pending: [String: String] = [:]

    func deliver(mediaId: String, for activityId: String) {
        pending[activityId] = mediaId
    }

    /// The pick for `activityId`, once.
    func take(for activityId: String) -> String? {
        pending.removeValue(forKey: activityId)
    }
}
