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
    /// members-search-pinned: the keyboard's height and the TabBar's, so the page is padded by
    /// only the part of the keyboard that rises past the TabBar it covers.
    @State private var keyboardHeight: CGFloat = 0
    @State private var tabBarHeight: CGFloat = 0
    /// action-menu-overlay: the TabBar's Add (+) menu is open.
    @State private var addMenuOpen = false

    /// action-menu-overlay B3: the Add menu's actions, as frame 4717:52460 draws them. B5: none of
    /// their destinations existed in the 2.0 shell at the time. "Invite a member" now opens the invite
    /// flow (invite-member D2); the other three still only close the menu until their screens land.
    static let addMenuActions: [ActionMenuOverlay.ActionItem] = [
        .init(glyph: "c066-record", label: "Record a video"),
        .init(glyph: "c066-microphone", label: "Voice memo"),
        .init(glyph: "c066-note", label: "Write a note"),
        .init(glyph: "c066-send-alt", label: "Invite a member"),
    ]

    /// members-search-pinned: the keyboard covers the TabBar instead of lifting it.
    static func keyboardOverlap(keyboardHeight: CGFloat, tabBarHeight: CGFloat) -> CGFloat {
        max(0, keyboardHeight - tabBarHeight)
    }

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
            .safeAreaPadding(.bottom, Self.keyboardOverlap(keyboardHeight: keyboardHeight, tabBarHeight: tabBarHeight))
            // C-084 §2 Motion: "the selection switches instantly with no animation"; a re-tap
            // with a page pushed pops it (D20, the system pop).
            TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: { addMenuOpen = true })
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tabBarHeight = $0 }
                // action-menu-overlay: C-066 slides up over every piece of chrome (the host below).
                .actionMenuPresentation(isPresented: addMenuOpen, onDismiss: { addMenuOpen = false }) {
                    ActionMenuOverlay(
                        actions: Self.addMenuActions,
                        onSelect: { action in
                            addMenuOpen = false
                            guard action.label == InviteEntry.rowLabel else { return }  // the other rows land with their screens
                            InviteEntry.open(on: model.tab, model: $model)
                        },
                        showsDone: false,
                        hairlineAfterLast: false
                    )
                }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        // filter-menu-fullscreen: full-screen menus (C-036) draw here, above TopNav and TabBar.
        .ui2OverlayHost()
        // invite-member Fixes (E6): surfaced errors (`recordError(surface: true)`) draw above everything.
        .overlay(alignment: .top) { UI2ErrorBannerHost() }
        // members-search-pinned: the keyboard never lifts the TabBar (it squeezed the Members
        // list); the pages above it get the keyboard's overlap as safe area instead.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            followKeyboard(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
            followKeyboard(note, hiding: true)
        }
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

    /// members-search-pinned: track the keyboard on its own animation timing.
    private func followKeyboard(_ note: Notification, hiding: Bool = false) {
        let info = note.userInfo
        let frame = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let screenHeight = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? frame.maxY
        let height = hiding ? 0 : max(0, screenHeight - frame.minY)
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        withAnimation(.easeOut(duration: duration)) { keyboardHeight = height }
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
            pop: { model.pop(on: tab) },
            popIfTop: { model.popIfTop($0, on: tab) },
            popTo: { model.popTo(depth: $0, on: tab) },
            depth: { model.path(for: tab).count },
            replaceTop: { model.replaceTop($0, with: $1, on: tab) }
        ))
        // dashboard-chart-intros D15: the dashboard resets its intros while hidden, replays on return.
        .environment(\.chartIntroActive, model.homeActive)
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
        case let .editMemberField(memberId, field): MemberFieldEditContainer(memberId: memberId, field: field)  // ui2-members-edit D2
        case let .inviteSelectGroup(returnDepth): InviteSelectGroupContainer(returnDepth: returnDepth)  // invite-member D3
        case let .inviteMember(groupId, returnDepth): InviteMemberContainer(groupId: groupId, returnDepth: returnDepth)  // invite-member D1
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
        case .members: MembersHomeContainer() // ui2-members-browse
        default: EmptyPage()                  // SPEC D10: Library…Media are unwired
        }
    }
}
