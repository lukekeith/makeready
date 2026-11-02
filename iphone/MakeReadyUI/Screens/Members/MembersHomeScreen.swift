//
//  MembersHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen members-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/organizations/{organizationId}/members ·
//  GET /api/groups · GET /api/group-leaders
//  Wired by MakeReady/UI2/Containers/Members/MembersHomeContainer.swift (ui2-members-browse).
//  ui2-members-browse edits, routed to /ui2-resolve (F3): no C-019 row of its own (D4 — the
//  shell's TopNav is the only one), `showsLeaderFilter` (D7/D15), `memberInitials` (T11), and an
//  editable C-034 (D19).
//

import SwiftUI

/// Members (leader directory) — the Home tab's Members section (§6): the org-wide member
/// directory. A header of C-034 search over the C-035 filter chips, then the member list of
/// C-037 rows separated by hairlines (§2). §2's collapsed C-019 nav row is the shell's TopNav
/// (D4), so this screen starts at the header. Composed only of §4's C-034, C-035, C-036 and
/// C-037; C-038 renders only inside C-037 (§4).
///
/// §3 names four states — `loading`, `populated`, `empty`, `error`. This build renders
/// `populated`; `loading` (row skeletons), `empty` (an empty message) and `error` (an inline
/// error with retry) name no §4 component, no geometry and no copy, so they are reported as
/// spec defects and not improvised here (the home-dashboard / members-profile precedent).
struct MembersHomeScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per member row, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        // ── Header (§2) ──
        /// C-034 `text` — the current query; "" → the placeholder shows (§4 `state=Default`).
        var searchText: String
        /// C-035 `label` of the Groups chip — "the filter's current selection" (§3: "All Groups"
        /// default; a chosen option replaces it).
        var groupFilterLabel: String
        /// C-035 `label` of the Leaders chip (§3: "All Leaders" default).
        var leaderFilterLabel: String
        /// C-036 options of the Groups menu — every group the caller can see (no "All …" row, D3).
        var groupOptions: [String]
        /// C-036 options of the Leaders menu — each leader in the org (no "All …" row, D3).
        var leaderOptions: [String]
        /// filter-multiselect D15: the id behind each `groupOptions` label, parallel; [] = the
        /// labels are the ids (previews, capture).
        var groupOptionIDs: [String] = []
        /// D15: the id behind each `leaderOptions` label, parallel; [] = the labels are the ids.
        var leaderOptionIDs: [String] = []
        /// filter-multiselect D1/D4: the checked Groups ids — C-036's seed; non-empty = active chip.
        var selectedGroupIDs: Set<String> = []
        /// D1/D4: the checked Leaders ids.
        var selectedLeaderIDs: Set<String> = []
        /// D7/D15: the Leaders chip shows only for a caller who sees every member of the org;
        /// a Group Leader's directory is already their own groups.
        var showsLeaderFilter: Bool
        // ── List (§2) — C-037 `subject=member, detail=text, trailing=chevron`, one per row ──
        var memberNames: [String]
        /// C-038's photo inside C-037; "" = no photo → C-038's own fallback.
        var memberPhotoURLs: [String]
        /// C-038's initials inside C-037 — the fallback when the photo is "" (T11; the row
        /// passes them straight through).
        var memberInitials: [String]
        /// C-037 `description` — "Joined …" (formatting per OQ-members-home-1).
        var memberJoinedLabels: [String]
        /// C-037 `count` — the member's group count; 0 → not rendered (§4: "nil/0 not rendered").
        var memberGroupCounts: [Int]
    }

    /// Which C-036 menu is presented — the one screen-local choice §3 makes.
    private enum FilterMenu {
        case groups
        case leaders
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    // The screen never decides what an action means. (D4: no tab / nav-toggle callbacks — the
    // shell's TopNav owns them.)
    var onSearch: (String) -> Void = { _ in }       // §3: typing filters the list live (debounced)
    var onSaveGroups: (Set<String>) -> Void = { _ in }  // filter-multiselect D1: Save on the Groups menu
    var onSaveLeaders: (Set<String>) -> Void = { _ in } // D1: Save on the Leaders menu
    var onOpenMember: (Int) -> Void = { _ in }      // §3: MemberRow tap → members-profile, by row
    /// members-search-pinned (routed to /ui2-resolve): search became active / ended — the shell
    /// pushes its TopNav off screen while it is active. The screen only reports it.
    var onSearchActiveChange: (Bool) -> Void = { _ in }

    // R-31 ephemeral UI: the query as typed (§3 "typing in C-034 filters the list live") and the
    // presented menu (§3 "Tap a chip → FilterMenuOverlay (C-036) opens").
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSaveGroups: @escaping (Set<String>) -> Void = { _ in },
        onSaveLeaders: @escaping (Set<String>) -> Void = { _ in },
        onOpenMember: @escaping (Int) -> Void = { _ in },
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSaveGroups = onSaveGroups
        self.onSaveLeaders = onSaveLeaders
        self.onOpenMember = onOpenMember
        self.onSearchActiveChange = onSearchActiveChange
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §4 (C-034): "placeholder \"Search members\"".
    private static let searchPlaceholder = "Search members"

    // MARK: - §2 geometry the screen owns

    // GAP — members-home §2: "1px `color-layout-border` hairline between rows" — no stroke-width
    // token.
    private static let hairline: CGFloat = 1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — in the app the shell's page scroll scrolls it
        // (HomeSectionLayout); the capture canvas lays it out at its full length.
        // members-search-pinned: the header is a pinned section header, so inside the shell's
        // scroll it stays put and the rows scroll beneath it.
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                memberList
            } header: {
                // C-131 paints its own pinned material and pins below the TopNav.
                header
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        // filter-menu-fullscreen: in the app the shell draws the menu above all chrome.
        .filterMenuPresentation(isPresented: presentedMenu != nil, onDismiss: { presentedMenu = nil }) {
            filterMenu
        }
    }

    // MARK: §2 Header

    /// §2: "Header (fixed content, 116pt): 16pt top inset → SearchField (C-034) 408×44 → 16pt →
    /// chip row: FilterChip (C-035) ×2 — \"∨ All Groups\", \"∨ All Leaders\" — 24pt tall, 8pt
    /// gap, left-aligned." Now the shared C-131 SearchFilterHeader, which owns the field, the
    /// full-bleed rail, the insets, the material and the pinning; this screen passes its chips.
    /// `.underShellTopNav`: the shell's TopNav and its 16 nav gap sit above (D4).
    private var header: some View {
        SearchFilterHeader(
            query: query,
            onQueryChange: { newValue in
                query = newValue
                onSearch(newValue)
            },
            placeholder: Self.searchPlaceholder,
            placement: .underShellTopNav,
            onSearchActiveChange: onSearchActiveChange
        ) {
            Self.menuChip(label: state.groupFilterLabel, active: !state.selectedGroupIDs.isEmpty) { presentedMenu = .groups }
            .ui2Element("C-035 FilterChip")
            if state.showsLeaderFilter {                             // D7/D15
                Self.menuChip(label: state.leaderFilterLabel, active: !state.selectedLeaderIDs.isEmpty) { presentedMenu = .leaders }
                .ui2Element("C-035 FilterChip 2")
            }
        }
    }

    /// members-search-pinned: search is active while the field is focused or holds a query —
    /// C-131's own rule, which now tracks the field's focus.
    static func isSearchActive(query: String, focused: Bool) -> Bool {
        SearchFilterHeader<EmptyView>.isSearchActive(query: query, focused: focused)
    }

    /// §3: "Tap a chip → FilterMenuOverlay (C-036) opens" — a `Menu` chip whose tap presents it;
    /// filter-multiselect D4: active while it has a pick.
    static func menuChip(label: String, active: Bool, onTap: @escaping () -> Void) -> FilterChip {
        FilterChip(type: .menu, active: active, label: label, onTap: onTap)
    }

    /// D15: the ids C-036 gets — the State's ids when they line up with the labels, else the labels.
    static func optionIDs(_ ids: [String], labels: [String]) -> [String] {
        ids.count == labels.count ? ids : labels
    }

    // MARK: §2 List

    /// §2: "full-width rows inset 16; MemberRow (C-037) 80pt each; 1px `color-layout-border`
    /// hairline between rows (flush with the 408pt content width, none above the first or below
    /// the last)." The frozen frame pitches the rows at exactly 80 (195, 275, 355, 435, 515), so
    /// the hairline sits ON the row boundary rather than adding a point between rows.
    private var memberList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(state.memberNames.indices, id: \.self) { index in
                memberRow(at: index)
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

    /// §4: C-037 `subject=member, detail=text, trailing=chevron` — C-038 Avatar 32 → title →
    /// "Joined …" → optional accent count → chevron.
    private func memberRow(at index: Int) -> some View {
        let photo = state.memberPhotoURLs[safe: index] ?? ""
        let initials = state.memberInitials[safe: index] ?? ""
        let count = state.memberGroupCounts[safe: index] ?? 0
        return ListResultRow(
            subject: .member,
            title: state.memberNames[index],
            detail: .text,
            description: state.memberJoinedLabels[safe: index],
            count: count > 0 ? count : nil,
            trailing: .chevron,
            imageURL: photo.isEmpty ? nil : URL(string: photo),
            initials: initials.isEmpty ? nil : initials,             // T11: C-038's fallback
            onTap: { onOpenMember(index) }
        )
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }

    // MARK: §3 Filter menu

    /// §3: "Tap a chip → FilterMenuOverlay (C-036) opens" — plain text labels, no glyph
    /// (OQ-C-036-002's proposed default: this screen passes none). filter-multiselect D1/D2:
    /// multi-select with a draft; Save applies and closes, ✕ closes with no change. There is no
    /// tap-outside dismissal surface. The crossfades are C-036's own modifier.
    @ViewBuilder private var filterMenu: some View {
        let leaders = presentedMenu == .leaders
        let labels = leaders ? state.leaderOptions : state.groupOptions
        let ids = Self.optionIDs(leaders ? state.leaderOptionIDs : state.groupOptionIDs, labels: labels)
        FilterMenuOverlay(
            options: zip(ids, labels).map { FilterMenuOverlay.Option(id: $0.0, label: $0.1) },
            selectionMode: .multiple,
            selectedIDs: leaders ? state.selectedLeaderIDs : state.selectedGroupIDs,
            onClose: { presentedMenu = nil },
            onSave: { picked in
                if leaders { onSaveLeaders(picked) } else { onSaveGroups(picked) }
                presentedMenu = nil
            }
        )
        // Groups and Leaders share this position: a new identity per menu, so a draft never
        // carries from one to the other.
        .id(presentedMenu)
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

extension MembersHomeScreen.State {

    /// §3 `populated` — every value is the text on the frozen frame `default` (node 3668:6801;
    /// §1 deviation 1: sample content), in the frame's order. Photos are stand-in URLs (the
    /// component previews' picsum seeds). The menus' options are §3's defaults plus §3's own
    /// example group, "Young professionals"; the frame draws no open menu.
    static let populated = Self(
        searchText: "",
        groupFilterLabel: "All Groups",
        leaderFilterLabel: "All Leaders",
        groupOptions: ["Young professionals"],
        leaderOptions: [],
        showsLeaderFilter: true,
        memberNames: ["Barry Allen", "Clark Kent", "Incredible Hulk", "Donald Trump", "Bruce Wayne"],
        memberPhotoURLs: [
            "https://picsum.photos/seed/members-home-1/256",
            "https://picsum.photos/seed/members-home-2/256",
            "https://picsum.photos/seed/members-home-3/256",
            "https://picsum.photos/seed/members-home-4/256",
            "https://picsum.photos/seed/members-home-5/256"
        ],
        memberInitials: ["BA", "CK", "IH", "DT", "BW"],
        memberJoinedLabels: [
            "Joined 5 milliseconds ago",
            "Joined 3 months ago",
            "Joined July 17, 2024",
            "Joined Jan 5, 2025",
            "Joined Sep 2, 2025"
        ],
        memberGroupCounts: [2, 1, 3, 0, 3]
    )
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("populated") {
    MembersHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
