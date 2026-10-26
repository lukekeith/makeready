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
/// ui2-members-browse D1: each tab is its own NavigationStack; paths live in UI2ShellModel.paths.
struct UI2Shell: View {
    @State private var model = UI2ShellModel()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 0) {
            // ui2-members-browse D1/D2: one NavigationStack per tab, above the TabBar. Home stays
            // mounted — its TopNav keeps its own scroll position (SPEC D12) and its pushed page
            // survives a tab switch (D2); any other tab mounts while selected (none pushes yet).
            ZStack {
                ForEach(UI2ShellModel.tabs, id: \.self) { tab in
                    if tab == .home || tab == model.tab {
                        stack(for: tab)
                            .opacity(tab == model.tab ? 1 : 0)
                            .allowsHitTesting(tab == model.tab)
                            .accessibilityHidden(tab != model.tab)
                    }
                }
            }
            // C-084 §2 Motion: "the selection switches instantly with no animation"; a re-tap
            // with a page pushed pops it (D20, the system pop).
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

    /// D1: the system bar is hidden on every page (pushed pages draw C-040); the interactive
    /// edge pop is re-armed on the root and on every pushed page (F2). The motion is the system
    /// push — no custom curve, duration or scrim.
    private func stack(for tab: TabBar.Tab) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            root(for: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .background(UI2InteractivePop())
                .navigationDestination(for: UI2Destination.self) { destination in
                    page(for: destination)
                        .toolbar(.hidden, for: .navigationBar)
                        .background(UI2InteractivePop())
                }
        }
        .environment(\.ui2Navigator, UI2Navigator(
            push: { model.push($0, on: tab) },
            pop: { model.pop(on: tab) }
        ))
    }

    private func pathBinding(for tab: TabBar.Tab) -> Binding<[UI2Destination]> {
        Binding(get: { model.path(for: tab) }, set: { model.setPath($0, for: tab) })
    }

    /// A tab's root page. Home's root is the TopNav + section page (D1: the stack wraps
    /// `HomeSectionLayout`, so TopNav slides left with the root under a push).
    @ViewBuilder private func root(for tab: TabBar.Tab) -> some View {
        switch tab {
        case .home: HomeSectionLayout(model: $model, onRefresh: refreshAction) { sectionContent }
        case .calendar, .search: EmptyPage()
        case .profile: ProfileStopgapContainer()
        }
    }

    @ViewBuilder private func page(for destination: UI2Destination) -> some View {
        switch destination {
        case let .memberDetail(id, name): MemberDetailHost(id: id, name: name)
        }
    }

    /// home-dashboard-data D24: the pull-to-refresh of the page on screen — Home only (the other
    /// sections are unwired, D10).
    private var refreshAction: (@MainActor () async -> Void)? {
        guard model.tab == .home, model.section == .home else { return nil }
        return { [authManager] in await HomeDashboardContainer.refresh(authManager: authManager) }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: HomeDashboardContainer()  // SPEC D8/D13
        default: EmptyPage()                  // SPEC D10: Library…Media are unwired
        }
    }
}
