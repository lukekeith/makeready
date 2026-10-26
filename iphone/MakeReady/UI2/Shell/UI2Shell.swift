import SwiftUI

/// SPEC D11: the shell owns the app chrome; roots render content only.
///
/// Placement (built from the contracts per F2's 2026-10-25 ruling, re-checked when the d2m
/// `shell-topnav` / `shell-tabs` specs land):
/// - TopNav is pinned under the status bar (home-dashboard §2: "collapsed nav row (32pt,
///   C-019) pinned at top → scrolling content"); as it morphs 32→96 the content below is
///   pushed down in step (analysis §1 / §3 step 2).
/// - TabBar is pinned to the screen's bottom edge OVER the bottom safe area: its 84pt includes
///   the home-indicator clearance (C-084 §2 Placement, OQ-C-083-2).
struct UI2Shell: View {
    @State private var model = UI2ShellModel()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 0) {
            // SPEC D12: the TopNav row (+ its gap) shows only on the Home tab; off-tab the
            // layout collapses it to zero height but keeps it mounted (see HomeSectionLayout).
            HomeSectionLayout(model: $model, onRefresh: refreshAction) { content }
            // C-084 §2 Motion: "the selection switches instantly with no animation".
            TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: {})
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Token.layoutBackground.ignoresSafeArea())
        .task {
            PushNotificationManager.shared.clearPendingDeepLink()  // SPEC D17
            await AppState.shared.loadInitialData()                 // SPEC D24
        }
        // SPEC D17: release 1 has no deep-link consumer, so a link set while the shell is
        // mounted (a push tap, a URL, a file open) is dropped rather than left to fire later.
        // Remove when the first 2.0 deep-link consumer lands.
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, link in
            if link != .none { PushNotificationManager.shared.clearPendingDeepLink() }
        }
    }

    /// home-dashboard-data D24: the pull-to-refresh of the page on screen — Home only (the other
    /// sections are unwired, D10).
    private var refreshAction: (@MainActor () async -> Void)? {
        guard model.tab == .home, model.section == .home else { return nil }
        return { [authManager] in await HomeDashboardContainer.refresh(authManager: authManager) }
    }

    @ViewBuilder private var content: some View {
        switch model.tab {
        case .home: sectionContent
        case .calendar, .search: EmptyPage()
        case .profile: ProfileStopgapContainer()
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: HomeDashboardContainer()  // SPEC D8/D13
        default: EmptyPage()                  // SPEC D10: Library…Media are unwired
        }
    }
}
