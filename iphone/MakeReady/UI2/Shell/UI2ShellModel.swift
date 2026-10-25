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

/// Ephemeral shell state (SPEC D19) — held as @State by UI2Shell, never persisted.
struct UI2ShellModel {
    var tab: TabBar.Tab = .home
    var section: UI2Section = .home
    var expansion: Double = 0
    var scrollOffset: CGFloat = 0

    var showsTopNav: Bool { tab == .home }

    mutating func apply(_ route: UI2Route) {
        switch route {
        case .tab(let next):
            if next == .home && tab == .home { section = .home }
            tab = next
        case .section(let next):
            section = next
            expansion = 0
        }
    }
}
