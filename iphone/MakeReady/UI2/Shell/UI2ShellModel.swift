import CoreGraphics
import UIKit

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
    /// invite-member D2/D3: the group pick before the invite (2+ groups). `returnDepth` = the
    /// stack depth when "+" was tapped (D11).
    case inviteSelectGroup(returnDepth: Int)
    /// invite-member D1/D2: the invite page for one group.
    case inviteMember(groupId: String, returnDepth: Int)
    /// ui2-groups-browse D1: one group's page. `name` is the list-known title C-040 shows while
    /// the group loads (D4).
    case groupDetail(id: String, name: String)
    /// ui2-groups-edit D1/D2: one group setting's edit page, above the group page.
    case editGroupField(groupId: String, field: GroupField)
    /// ui2-groups-browse D1/D8: the create form, pushed on the Home stack by the Groups `+`;
    /// success replaces it with the new group's `.groupDetail`.
    case createGroup
    /// group-cover-image D6/D7: the Edit cover page, above the group page — a new pick, or the
    /// stored original at its framing.
    case editGroupCover(groupId: String, source: ImageEditSource)
    /// image-framing-editor D4/D5: the Edit photo page, above the member page — a new pick, or the
    /// stored original (else the avatar itself) at its framing.
    case editMemberAvatar(memberId: String, source: ImageEditSource)
    /// ui2-programs D1: one program's page. `name` is the list-known title while it loads.
    case studyProgramHome(id: String, name: String)
    /// ui2-programs D1/D8: the create form, pushed on the Home stack by the Programs `+`;
    /// success replaces it with the new program's `.studyProgramHome`.
    case createStudyProgram
    /// ui2-programs D10: one program setting's edit page, above the program page.
    case editProgramField(programId: String, field: ProgramField)
    /// ui2-programs D11: the Edit cover page, above the program page (the group cover flow).
    case editProgramCover(programId: String, source: ImageEditSource)
    /// ui2-enrollment-create D2/D9: the "New enrollment" checklist; `flowId` keys its draft in
    /// `AppState.enrollmentDrafts`. Pushed on the stack it was opened from.
    case enrollChecklist(flowId: UUID)
    /// ui2-enrollment-create: the six pickers, each above its checklist; Select/Save writes the draft and pops.
    case enrollSelectGroup(flowId: UUID)
    case enrollSelectProgram(flowId: UUID)
    case enrollSelectSchedule(flowId: UUID)
    case enrollSelectInviteTime(flowId: UUID)
    case enrollSelectSync(flowId: UUID)
    case enrollSelectAccess(flowId: UUID)
}

extension UI2Destination {
    /// A page that takes the whole screen, with no TabBar under it.
    var isFullScreen: Bool {
        switch self {
        case .editGroupCover, .editMemberAvatar, .editProgramCover: return true
        default: return false
        }
    }
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

    /// image-framing-editor (owner walk 2026-10-27): the image editors are full-screen — the TabBar
    /// is gone while one is the selected tab's top page.
    var showsTabBar: Bool { !(path(for: tab).last?.isFullScreen ?? false) }

    func path(for tab: TabBar.Tab) -> [UI2Destination] { paths[tab] ?? [] }

    /// ui2-enrollment-create D13: the flows whose checklist is still on some stack — every other
    /// draft is pruned when the paths change.
    var enrollmentFlowIds: Set<UUID> {
        Set(paths.values.flatMap { $0 }.compactMap {
            if case let .enrollChecklist(flowId) = $0 { return flowId } else { return nil }
        })
    }

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

    /// ui2-groups-browse D8: the create form's success — `next` replaces `expected` in ONE path
    /// write, only while `expected` is still the tab's last entry (as `popIfTop`), so a swipe-back
    /// or a Home re-tap mid-create writes nothing. Back from `next` returns to what was below.
    mutating func replaceTop(_ expected: UI2Destination, with next: UI2Destination, on tab: TabBar.Tab) {
        guard var path = paths[tab], path.last == expected else { return }
        path[path.count - 1] = next
        paths[tab] = path
    }

    /// invite-member D11: Cancel / Done pop the whole flow back to the page "+" was tapped on.
    mutating func popTo(depth: Int, on tab: TabBar.Tab) {
        let path = path(for: tab)
        guard depth < path.count else { return }
        paths[tab] = Array(path.prefix(max(0, depth)))
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
