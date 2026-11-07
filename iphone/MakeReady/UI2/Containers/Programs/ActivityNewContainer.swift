import SwiftUI

/// program-lesson-add-activity D10/D17: the `.activityNew` destination — the activity-type picker for one
/// lesson. It does no load of its own: the lesson is already in `AppState` from the program page. Tile,
/// slide and add taps are no-ops (D3, D10); back pops.
struct ActivityNewContainer: View {
    let programId: String
    let lessonId: String

    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        ActivityNewScreen(
            state: ActivityNewMapper.state(lesson: AppState.shared.lessons[lessonId]),
            onBack: { navigator.pop() }
        )
        .ui2PushedPageFill()
    }
}

/// The picker's strip: the lesson's activities by `orderNumber`, then one placeholder chip, active (D17).
enum ActivityNewMapper {
    static let placeholderID = "placeholder"
    static let placeholderLabel = "New activity"

    static func state(lesson: Lesson?) -> ActivityNewScreen.State {
        let activities = (lesson?.activities ?? []).sorted { $0.orderNumber < $1.orderNumber }
        return ActivityNewScreen.State(
            slideIDs: activities.map(\.id) + [placeholderID],
            slideLabels: activities.map { $0.title ?? "" } + [placeholderLabel],
            activeID: placeholderID,
            pendingType: "",
            createFailed: false
        )
    }
}
