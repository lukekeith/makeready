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

    var body: some View {
        VStack(spacing: 0) {
            topNav
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            // C-084 §2 Motion: "the selection switches instantly with no animation".
            TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: {})
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Token.layoutBackground.ignoresSafeArea())
        .task {
            PushNotificationManager.shared.clearPendingDeepLink()  // SPEC D17
            await AppState.shared.loadInitialData()                 // SPEC D24
        }
    }

    /// SPEC D12: TopNav shows only on the Home tab, and switching back restores the section
    /// AND the row's scroll position. TopNav's scroll position lives in its own ScrollView
    /// (its `scrollOffset` prop is a static-render offset, not a binding), so the host stays
    /// mounted off-tab — collapsed to zero height, hidden and inert — instead of being removed.
    private var topNav: some View {
        TopNavHost(model: $model)
            .frame(height: model.showsTopNav ? nil : 0, alignment: .top)
            .clipped()
            .opacity(model.showsTopNav ? 1 : 0)
            .allowsHitTesting(model.showsTopNav)
            .accessibilityHidden(!model.showsTopNav)
    }

    @ViewBuilder private var content: some View {
        switch model.tab {
        case .home: sectionContent
        case .calendar, .search: EmptyPage()
        case .profile: EmptyPage()            // Task 15 replaces this
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: EmptyPage()               // Task 13 replaces this
        default: EmptyPage()                  // SPEC D10: Library…Media are unwired
        }
    }
}
