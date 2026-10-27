//
//  GroupsHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen groups-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups · GET /api/group-leaders ·
//  GET /api/organizations/my/organization
//  (a "my organizations" list for multi-org callers is an additive API-GAP in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Groups (leader directory) — the Groups tab root (§6): a flat, filtered list of the caller's
/// groups. The collapsed C-019 nav row, a header of C-034 search over two C-035 filter chips,
/// then the group list of C-037 rows separated by hairlines (§2: "Identical skeleton to
/// `members-home` §2"). Composed only of §4's C-019, C-034, C-035, C-036 and C-037; C-038 and
/// C-043 render only inside C-037 (§4).
///
/// §3 names four states — `loading`, `populated`, `empty`, `error`. This build renders
/// `populated`; `loading` (row skeletons), `empty` (an empty message) and `error` (an inline
/// error with retry) name no §4 component, no geometry and no copy, so they are reported as
/// spec defects and not improvised here (the members-home precedent).
struct GroupsHomeScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per group row, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        // ── Header (§2) ──
        /// C-034 `text` — the current query; "" → the placeholder shows (§4 "Search groups").
        var searchText: String
        /// §1 deviation 4: "The \"All Orgs\" chip renders only for callers belonging to more than
        /// one organization" — the frame shows the multi-org presentation.
        var orgFilterVisible: Bool
        /// C-035 `label` of the Orgs chip — the filter's current selection ("All Orgs" default).
        var orgFilterLabel: String
        /// C-035 `label` of the Leaders chip ("All Leaders" default).
        var leaderFilterLabel: String
        /// C-036 options of the Orgs menu — §3: "\"All Orgs\" + each organization the caller
        /// belongs to".
        var orgOptions: [String]
        /// C-036 options of the Leaders menu — §3: "\"All Leaders\" + each leader in scope".
        var leaderOptions: [String]
        // ── List (§2) — C-037 `type=Group + tags`, one per row ──
        /// C-037 `title` — the group name.
        var groupNames: [String]
        /// C-038's photo inside C-037; "" = no photo → C-038's own fallback.
        var groupPhotoURLs: [String]
        /// C-043 `Single/Default` — the leader's short name ("L. Keith").
        var groupLeaderNames: [String]
        /// C-043 `Key value/Default` — the member count ("3" + "members").
        var groupMemberCounts: [Int]
    }

    /// Which C-036 menu is presented — the one screen-local choice §3 makes.
    private enum FilterMenu {
        case orgs
        case leaders
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    // The screen never decides what an action means.
    var onSelectTab: (String) -> Void = { _ in }    // C-019 tab tap → that tab's root (§6)
    var onToggleNav: () -> Void = {}                // C-019 collapse ⇄ expand
    // OQ-groups-home-2 (answered 2026-10-03): "Groups are added by the NavTabButton when it
    // expands and reveals the plus" — C-019's `onAdd` on the Groups tab.
    var onAddGroup: () -> Void = {}
    var onSearch: (String) -> Void = { _ in }       // §3: live filter, debounced ≥300ms
    var onSelectOrg: (String) -> Void = { _ in }    // §3: an Orgs option applies that filter
    var onSelectLeader: (String) -> Void = { _ in } // §3: a Leaders option applies that filter
    var onOpenGroup: (Int) -> Void = { _ in }       // §3: row tap → groups-detail, by row

    // R-31 ephemeral UI: the query as typed (§3 "live filter") and the presented menu (§3 chip
    // taps → C-036).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?

    init(
        state: State,
        onSelectTab: @escaping (String) -> Void = { _ in },
        onToggleNav: @escaping () -> Void = {},
        onAddGroup: @escaping () -> Void = {},
        onSearch: @escaping (String) -> Void = { _ in },
        onSelectOrg: @escaping (String) -> Void = { _ in },
        onSelectLeader: @escaping (String) -> Void = { _ in },
        onOpenGroup: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSelectTab = onSelectTab
        self.onToggleNav = onToggleNav
        self.onAddGroup = onAddGroup
        self.onSearch = onSearch
        self.onSelectOrg = onSelectOrg
        self.onSelectLeader = onSelectLeader
        self.onOpenGroup = onOpenGroup
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §2 / §4 (C-019): "collapsed nav (C-019, Groups active)".
    private static let selectedTab = "Groups"
    /// §2 / §4 (C-034): "SearchField 408×44 \"Search groups\"".
    private static let searchPlaceholder = "Search groups"
    /// §2: MetaChip `Key value/Default` = member count ("3" + "members").
    private static let memberCountLabel = "members"

    // MARK: - §2 geometry the screen owns

    // GAP — groups-home §2: "header block (116pt: 16 inset → SearchField 408×44 → 16 → chip
    // row" — a vertical 16 with no spacing token naming the role (page-margin is horizontal).
    // The 16 under the chip row is the same GAP: 116 = 16 + 44 + 16 + 24 + 16, and the frozen
    // frame `default` starts the first row there (drawings: chips end at 179, row 1 at 195).
    private static let headerGap: CGFloat = 16
    // GAP — groups-home §2: "1px `color-layout-border` hairlines between rows" — no stroke-width
    // token.
    private static let hairline: CGFloat = 1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            navRow
            header
            groupList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: the page background
        // filter-menu-fullscreen: in the app the shell draws the menu above all chrome.
        .filterMenuPresentation(isPresented: presentedMenu != nil, onDismiss: { presentedMenu = nil }) {
            filterMenu
        }
    }

    /// §2: "status bar → collapsed nav (C-019, Groups active)" — C-019 in its `collapsed` state
    /// (`expansion` 0), full width with no screen inset (C-019 owns its own row inset; the
    /// members-home measurement).
    private var navRow: some View {
        TopNav(
            tabs: TopNav.designedTabs,
            selectedTab: Self.selectedTab,
            expansion: 0,
            scrollOffset: 0,
            onSelect: onSelectTab,
            onToggleExpansion: onToggleNav,
            onAdd: { _ in onAddGroup() }                         // OQ-groups-home-2
        )
        .ui2Element("C-019 TopNav")
    }

    // MARK: §2 Header

    /// §2: "header block (116pt: 16 inset → SearchField 408×44 \"Search groups\" → 16 → chip
    /// row: FilterChip ×2 \"∨ All Orgs\" (95pt), \"∨ All Leaders\" (117pt), 8 gap)".
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Self.headerGap)
            // §4: C-034 `state=Default` — derived by C-034 from `text.isEmpty × focused`; this
            // presentational screen owns no focus, so `focused` is false.
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                focused: false,
                onChange: { newValue in
                    query = newValue
                    onSearch(newValue)
                },
                onClear: {
                    query = ""
                    onSearch("")
                }
            )
            .ui2Element("C-034 SearchField")
            Spacer().frame(height: Self.headerGap)
            // §4: both chips "`type=Menu, active=false`". The resting row fits, so it is a plain
            // HStack (members-home's OQ-members-home-3 default, inherited by "identical skeleton").
            HStack(spacing: Token.Space.elementGap) {                // §2: "8 gap"
                if state.orgFilterVisible {
                    FilterChip(type: .menu, active: false, label: state.orgFilterLabel) {
                        presentedMenu = .orgs
                    }
                    .ui2Element("C-035 FilterChip")
                }
                FilterChip(type: .menu, active: false, label: state.leaderFilterLabel) {
                    presentedMenu = .leaders
                }
                .ui2Element(state.orgFilterVisible ? "C-035 FilterChip 2" : "C-035 FilterChip")
            }
            Spacer().frame(height: Self.headerGap)
        }
        .padding(.horizontal, Token.Space.pageMargin)                // §2: "inset 16"
    }

    // MARK: §2 List

    /// §2: "list: ListResultRow (C-037) `type=Group + tags`, 96pt rows, 1px `color-layout-border`
    /// hairlines between rows (none first/last), inset 16." The frozen frame pitches the rows at
    /// exactly 96 (195, 291, 387), so the hairline sits ON the row boundary rather than adding a
    /// point between rows.
    private var groupList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(state.groupNames.indices, id: \.self) { index in
                groupRow(at: index)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Rectangle()
                                .fill(Token.layoutBorder)
                                .frame(height: Self.hairline)
                        }
                    }
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §2 row content: "64pt group image (rounded-full, C-038 fallback rules) → info (8 gap):
    /// group name … → chip row (4 gap): MetaChip (C-043) `Single/Default` = leader short-name +
    /// MetaChip `Key value/Default` = member count → 18pt chevron-right" — C-037
    /// `subject=group, detail=chips, trailing=chevron`, which owns all of that geometry.
    private func groupRow(at index: Int) -> some View {
        let photo = state.groupPhotoURLs[safe: index] ?? ""
        let leader = state.groupLeaderNames[safe: index] ?? ""
        let members = state.groupMemberCounts[safe: index] ?? 0
        return ListResultRow(
            subject: .group,
            title: state.groupNames[index],
            detail: .chips,
            chips: [
                ListResultRow.Chip(value: leader),
                ListResultRow.Chip(value: String(members), label: Self.memberCountLabel)
            ],
            trailing: .chevron,
            imageURL: photo.isEmpty ? nil : URL(string: photo),
            onTap: { onOpenGroup(index) }
        )
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }

    // MARK: §3 Filter menu

    /// §3: chip taps → "C-036 FilterMenuOverlay, single-select, plain labels"; "Selection/
    /// chip-label/motion behavior identical to members-home §3" — selecting applies the filter and
    /// closes the menu; X closes with no change. The crossfades are C-036's own modifier.
    @ViewBuilder private var filterMenu: some View {
        let options = presentedMenu == .orgs ? state.orgOptions : state.leaderOptions
        let selected = presentedMenu == .orgs ? state.orgFilterLabel : state.leaderFilterLabel
        FilterMenuOverlay(
            options: options.map { FilterMenuOverlay.Option(id: $0, label: $0) },
            selectionMode: .single,
            selectedIDs: [selected],
            onSelect: { option in
                if presentedMenu == .orgs {
                    onSelectOrg(option.id)
                } else {
                    onSelectLeader(option.id)
                }
                presentedMenu = nil
            },
            onClose: { presentedMenu = nil }
        )
        .ui2Element("C-036 FilterMenuOverlay")
    }

    /// `"C-### <Name>"`, with `" N"` from the second instance on (D11).
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension GroupsHomeScreen.State {

    /// §3 `populated` — every value is the text on the frozen frame `default` (node 3668:7676;
    /// §1 deviation 1: sample content), in the frame's order. §3's alphabetical sort
    /// (OQ-groups-home-1, ratified 2026-10-03) belongs to whatever supplies the rows; this
    /// presentational view renders them in the order given. Photos are stand-in
    /// URLs (picsum seeds). The menus' options are §3's defaults; the frame draws no open menu.
    static let populated = Self(
        searchText: "",
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: ["All Orgs"],
        leaderOptions: ["All Leaders"],
        groupNames: ["Young professionals", "Grandparents galore", "The kids"],
        groupPhotoURLs: [
            "https://picsum.photos/seed/groups-home-1/256",
            "https://picsum.photos/seed/groups-home-2/256",
            "https://picsum.photos/seed/groups-home-3/256"
        ],
        groupLeaderNames: ["L. Keith", "S. Stickane", "S. Stickane"],
        groupMemberCounts: [3, 25, 3]
    )
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("populated") {
    GroupsHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
