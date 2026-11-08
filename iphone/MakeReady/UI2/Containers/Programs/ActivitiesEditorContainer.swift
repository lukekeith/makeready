import SwiftUI

/// text-activity D39: the `.activitiesEditor` destination. PLACEHOLDER — Task 25 replaces this file with
/// the real container (edit buffer, store mapping, save on Done); the shell routes to this init until then.
struct ActivitiesEditorContainer: View {
    let activityId: String

    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        PageHeader(style: .default, title: "Text", showIcons: false, rightButtons: [], onLeading: { navigator.pop() })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ui2PushedPageFill()
    }
}
