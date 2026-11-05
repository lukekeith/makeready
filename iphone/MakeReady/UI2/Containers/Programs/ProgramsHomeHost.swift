import SwiftUI

/// master-search D27: the `.programsHome` destination — the Programs list pushed from a tapped template.
/// `StudyProgramsContainer` has no scroll of its own (the shell's section scroll hosts it on Home), so a
/// pushed page supplies the header, the scroll and the pull-down reload.
struct ProgramsHomeHost: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(style: .default, title: "Programs", showIcons: false, rightButtons: [],
                       onLeading: { navigator.pop() })
            ScrollView(.vertical) {
                StudyProgramsContainer(destination: { .studyProgramHome(id: $0, name: $1) })
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .pullDownRefresh { [authManager] in await StudyProgramsContainer.refresh(authManager: authManager) }
        }
        .ui2PushedPageFill()
    }
}
