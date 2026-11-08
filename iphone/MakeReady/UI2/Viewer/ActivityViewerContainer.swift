import SwiftUI

/// text-activity D39: the `.activityViewer` destination. PLACEHOLDER — Task 27 replaces this file with the
/// real container (load, engine, hosts); the shell routes to this init until then.
struct ActivityViewerContainer: View {
    let lessonVersionId: String
    let activityId: String

    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        PageHeader(style: .default, title: "Viewer", showIcons: false, rightButtons: [], onLeading: { navigator.pop() })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ui2PushedPageFill()
    }
}
