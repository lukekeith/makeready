//
//  GroupsHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen groups-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups · GET /api/group-leaders ·
//  GET /api/organizations/my/organization
//  (a "my organizations" list for multi-org callers is an additive API-GAP in §5).
//  Wired by MakeReady/UI2/Containers/Groups/GroupsHomeContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edits, routed to /ui2-resolve (F3): no C-019 row of its own (D2 — the
//  shell's TopNav is the only one, its Groups `+` opens create-group), an editable C-034 (D3),
//  and `listEmpty`'s one line (D22).
//

import SwiftUI

/// Groups (leader directory) — the Home tab's Groups section (§6): a flat, filtered list of the
/// caller's groups. A header of C-034 search over two C-035 filter chips, then the group list of
/// C-037 rows separated by hairlines (§2). §2's collapsed C-019 nav row is the shell's TopNav
/// (D2), so this screen starts at the header. Composed only of §4's C-034, C-035, C-036 and
/// C-037; C-038 and C-043 render only inside C-037 (§4).
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
        /// C-036 options of the Orgs menu — each organization the caller belongs to (no "All Orgs"
        /// row: filter-multiselect D3, an empty selection means no filter).
        var orgOptions: [String]
        /// C-036 options of the Leaders menu — each leader in scope (no "All Leaders" row: D3).
        var leaderOptions: [String]
        /// filter-multiselect D14: the checked Orgs options (ids = labels until a container
        /// supplies ids); non-empty = the chip is active (D4).
        var selectedOrgs: Set<String> = []
        /// D14: the checked Leaders options.
        var selectedLeaders: Set<String> = []
        // ── List (§2) — C-037 `type=Group + tags`, one per row ──
        /// C-037 `title` — the group name.
        var groupNames: [String]
        /// C-038's photo inside C-037; "" = no photo → C-038's own fallback.
        var groupPhotoURLs: [String]
        /// C-043 `Single/Default` — the leader's short name ("L. Keith").
        var groupLeaderNames: [String]
        /// C-043 `Key value/Default` — the member count ("3" + "members").
        var groupMemberCounts: [Int]

        // ── D22 (ui2-groups-browse): the list's one line when no row shows ──
        /// "" = nothing (loading, or rows showing) · "noGroups" · "noMatch" — the caller decides;
        /// the copy is the screen's (`emptyCopy`).
        var listEmpty: String = ""
    }

    /// Which C-036 menu is presented — the one screen-local choice §3 makes.
    private enum FilterMenu {
        case orgs
        case leaders
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    // The screen never decides what an action means.
    var onSearch: (String) -> Void = { _ in }       // §3: live filter, debounced ≥300ms
    var onSaveOrgs: (Set<String>) -> Void = { _ in }    // filter-multiselect D14: Save on the Orgs menu
    var onSaveLeaders: (Set<String>) -> Void = { _ in } // D14: Save on the Leaders menu
    var onOpenGroup: (Int) -> Void = { _ in }       // §3: row tap → groups-detail, by row
    /// §3 Search active (identical to members-home): search became active / ended — the shell
    /// pushes its TopNav off screen while it is active. The screen only reports it.
    var onSearchActiveChange: (Bool) -> Void = { _ in }

    // R-31 ephemeral UI: the query as typed (§3 "live filter") and the presented menu (§3 chip
    // taps → C-036).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?
    /// §3 Search active: the editable C-034's focus, as it reports it.
    @SwiftUI.State private var searchFocused = false

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSaveOrgs: @escaping (Set<String>) -> Void = { _ in },
        onSaveLeaders: @escaping (Set<String>) -> Void = { _ in },
        onOpenGroup: @escaping (Int) -> Void = { _ in },
        onSearchActiveChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSaveOrgs = onSaveOrgs
        self.onSaveLeaders = onSaveLeaders
        self.onOpenGroup = onOpenGroup
        self.onSearchActiveChange = onSearchActiveChange
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §2 / §4 (C-034): "SearchField 408×44 \"Search groups\"".
    private static let searchPlaceholder = "Search groups"
    /// §2: MetaChip `Key value/Default` = member count ("3" + "members").
    private static let memberCountLabel = "members"
    /// D22 (ui2-groups-browse): the two list lines — no copy on the frame, ruled at audit.
    private static let noGroupsCopy = "No groups yet"
    private static let noMatchCopy = "No groups match your search"

    /// D22: `State.listEmpty` → its line; nil draws nothing.
    static func emptyCopy(_ listEmpty: String) -> String? {
        switch listEmpty {
        case "noGroups": return noGroupsCopy
        case "noMatch": return noMatchCopy
        default: return nil
        }
    }

    // MARK: - §2 geometry the screen owns

    // GAP — groups-home §2: "header block (116pt: 16 inset → SearchField 408×44 → 16 → chip
    // row" — a vertical 16 with no spacing token naming the role (page-margin is horizontal).
    // The 16 under the chip row is the same GAP: 116 = 16 + 44 + 16 + 24 + 16, and the frozen
    // frame `default` starts the first row there (drawings: chips end at 179, row 1 at 195).
    private static let headerGap: CGFloat = 16
    // GAP — groups-home §2: "1px `color-layout-border` hairlines between rows" — no stroke-width
    // token.
    private static let hairline: CGFloat = 1

    /// §3 Search active (identical to members-home): search is active while the field is focused
    /// or holds a query, so typed results stay up after the keyboard drops; only C-039 (the x)
    /// ends it.
    static func isSearchActive(query: String, focused: Bool) -> Bool {
        focused || !query.isEmpty
    }

    private var searchActive: Bool { Self.isSearchActive(query: query, focused: searchFocused) }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's.
        // §3 Pinned header (identical to members-home): the header is a pinned section header, so
        // inside the shell's scroll it stays put and the rows scroll beneath it.
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                groupList
                emptyLine
            } header: {
                header.background { Self.headerMaterial }
                    // topnav-height-env: once pinned, the growing TopNav pushes it down.
                    .pinnedBelowTopNav()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: the page background
        // filter-menu-fullscreen: in the app the shell draws the menu above all chrome.
        .filterMenuPresentation(isPresented: presentedMenu != nil, onDismiss: { presentedMenu = nil }) {
            filterMenu
        }
        .onChange(of: searchActive, initial: true) { _, active in onSearchActiveChange(active) }
    }

    // GAP — groups-home §3 Pinned header (members-search-pinned): no material token. A blur under
    // a mostly-opaque page background, so the rows behind the pinned header are barely visible.
    private static let headerScrimOpacity: Double = 0.8

    private static var headerMaterial: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Token.layoutBackground.opacity(headerScrimOpacity)
        }
    }

    // MARK: §2 Header

    /// §2: "header block (116pt: 16 inset → SearchField 408×44 \"Search groups\" → 16 → chip
    /// row: FilterChip ×2 \"∨ All Orgs\" (95pt), \"∨ All Leaders\" (117pt), 8 gap)".
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2's "16 inset" above the field is the gap under the nav row. The row is now the
            // shell's (D2) and `HomeSectionLayout.navGap` (16) already is that gap, so the
            // screen adds none of its own (the MembersHomeScreen D4 precedent).
            // §4: C-034, its editable form (D3 — members-browse D19 precedent); focus is the field's own.
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
                },
                // §3 Search active: while active the x is always there and ends the search.
                showsClearWhenEmpty: searchActive,
                onFocusChange: { searchFocused = $0 },
                clearDismisses: true,
                editable: true
            )
            .ui2Element("C-034 SearchField")
            Spacer().frame(height: Self.headerGap)
            // §4: both chips `type=Menu`, active while it has a pick — filter-multiselect D4. The resting row fits, so it is a plain
            // HStack (members-home's OQ-members-home-3 default, inherited by "identical skeleton").
            HStack(spacing: Token.Space.elementGap) {                // §2: "8 gap"
                if state.orgFilterVisible {
                    Self.menuChip(label: state.orgFilterLabel, active: !state.selectedOrgs.isEmpty) {
                        presentedMenu = .orgs
                    }
                    .ui2Element("C-035 FilterChip")
                }
                Self.menuChip(label: state.leaderFilterLabel, active: !state.selectedLeaders.isEmpty) {
                    presentedMenu = .leaders
                }
                .ui2Element(state.orgFilterVisible ? "C-035 FilterChip 2" : "C-035 FilterChip")
            }
            Spacer().frame(height: Self.headerGap)
        }
        .padding(.horizontal, Token.Space.pageMargin)                // §2: "inset 16"
    }

    /// §4: a `Menu` chip whose tap presents C-036. `onTap:` is passed by label: an unlabelled
    /// trailing closure on FilterChip binds to `onSelect` (Swift 5's backward scan), which a
    /// `Menu` chip never fires (agent walk round 1, E3 — the MembersHomeScreen precedent).
    static func menuChip(label: String, active: Bool, onTap: @escaping () -> Void) -> FilterChip {
        FilterChip(type: .menu, active: active, label: label, onTap: onTap)
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

    /// D22: one centred `type-body-sm` `color-text-secondary` line under the chips when no row
    /// shows — the groups-detail §3 section-empty treatment.
    @ViewBuilder private var emptyLine: some View {
        if state.groupNames.isEmpty, let copy = Self.emptyCopy(state.listEmpty) {
            Text(copy)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Token.Space.pageMargin)
        }
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

    /// §3: chip taps → C-036 FilterMenuOverlay, plain labels. filter-multiselect D1/D2: multi-select
    /// with a draft; Save applies and closes, ✕ closes with no change.
    @ViewBuilder private var filterMenu: some View {
        let orgs = presentedMenu == .orgs
        let options = orgs ? state.orgOptions : state.leaderOptions
        FilterMenuOverlay(
            options: options.map { FilterMenuOverlay.Option(id: $0, label: $0) },
            selectionMode: .multiple,
            selectedIDs: orgs ? state.selectedOrgs : state.selectedLeaders,
            onClose: { presentedMenu = nil },
            onSave: { picked in
                if orgs { onSaveOrgs(picked) } else { onSaveLeaders(picked) }
                presentedMenu = nil
            }
        )
        // Orgs and Leaders share this position: a new identity per menu, so a draft never carries over.
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
        orgOptions: [],
        leaderOptions: [],
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
