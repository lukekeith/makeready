import CoreGraphics

/// SPEC D12/D13: the 8 TopNav sections, in C-019's closed order.
enum UI2Section: String, CaseIterable {
    case home = "Home", library = "Library", groups = "Groups", members = "Members"
    case enrollments = "Enrollments", invites = "Invites", programs = "Programs", media = "Media"
}

/// Release 1 routes: only the two navigation levels (SPEC §iphone Phase 3).
enum UI2Route: Equatable {
    case tab(TabBar.Tab)
    case section(UI2Section)
}

/// ui2-members-browse D1: a page pushed onto a tab's NavigationStack. `name` is the list-known
/// title the pushed page's C-040 header shows while it loads (members-profile §3 `loading`).
/// ui2-members-edit D2: `editMemberField` — one member field's edit page, above the member page.
enum UI2Destination: Hashable {
    case memberDetail(id: String, name: String)
    case editMemberField(memberId: String, field: MemberField)
}

/// Ephemeral shell state (SPEC D19) — held as @State by UI2Shell, never persisted.
struct UI2ShellModel {
    /// The four root tabs in TabBar order — one NavigationStack each (ui2-members-browse D1).
    static let tabs: [TabBar.Tab] = [.home, .calendar, .search, .profile]

    var tab: TabBar.Tab = .home
    var section: UI2Section = .home
    /// dashboard-chart-intros D6/D15: Home is the selected tab. A push or a Home re-tap keeps it
    /// true; selecting another tab makes it false, which resets the dashboard's chart intros.
    var homeActive: Bool { tab == .home }
    var expansion: Double = 0
    var scrollOffset: CGFloat = 0
    /// D1/D2: each tab's push path; a tab missing from the map is at its root.
    var paths: [TabBar.Tab: [UI2Destination]] = [:]

    /// D1: TopNav is part of the Home stack's ROOT page, so a pushed page covers it — no hide logic.
    var showsTopNav: Bool { tab == .home }

    func path(for tab: TabBar.Tab) -> [UI2Destination] { paths[tab] ?? [] }

    /// The stack's `path:` binding writes here — including the system back and edge-swipe pops.
    mutating func setPath(_ path: [UI2Destination], for tab: TabBar.Tab) { paths[tab] = path }

    mutating func push(_ destination: UI2Destination, on tab: TabBar.Tab) {
        paths[tab, default: []].append(destination)
    }

    mutating func pop(on tab: TabBar.Tab) {
        guard var path = paths[tab], !path.isEmpty else { return }
        path.removeLast()
        paths[tab] = path
    }

    /// ui2-members-edit D13: the success pop — only while `destination` is still the tab's last
    /// entry, so a swipe-back or a Home re-tap during the save leaves the stack alone.
    mutating func popIfTop(_ destination: UI2Destination, on tab: TabBar.Tab) {
        guard path(for: tab).last == destination else { return }
        pop(on: tab)
    }

    mutating func apply(_ route: UI2Route) {
        switch route {
        case .tab(let next):
            // ui2-members-browse D20: re-tapping the selected tab with a page pushed pops that
            // tab to its root (the system pop animates it) and changes nothing else.
            if next == tab, !path(for: next).isEmpty {
                paths[next] = []
                return
            }
            if next == .home && tab == .home { section = .home }
            tab = next
        case .section(let next):
            // SPEC D14(b), revised 2026-10-25: selecting leaves `expansion` as it is.
            section = next
        }
    }
}
