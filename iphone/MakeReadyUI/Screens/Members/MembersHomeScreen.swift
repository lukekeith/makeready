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
        /// C-036 options of the Groups menu — §3: "All Groups" + every group the caller can see.
        var groupOptions: [String]
        /// C-036 options of the Leaders menu — §3: "All Leaders" + each leader in the org.
        var leaderOptions: [String]
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
    var onSelectGroup: (String) -> Void = { _ in }  // §3: a Groups option applies that filter
    var onSelectLeader: (String) -> Void = { _ in } // §3: a Leaders option applies that filter
    var onOpenMember: (Int) -> Void = { _ in }      // §3: MemberRow tap → members-profile, by row

    // R-31 ephemeral UI: the query as typed (§3 "typing in C-034 filters the list live") and the
    // presented menu (§3 "Tap a chip → FilterMenuOverlay (C-036) opens").
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSelectGroup: @escaping (String) -> Void = { _ in },
        onSelectLeader: @escaping (String) -> Void = { _ in },
        onOpenMember: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSelectGroup = onSelectGroup
        self.onSelectLeader = onSelectLeader
        self.onOpenMember = onOpenMember
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }

    // MARK: - §2 / §4 constants (values that no §3 state changes)

    /// §4 (C-034): "placeholder \"Search members\"".
    private static let searchPlaceholder = "Search members"

    // MARK: - §2 geometry the screen owns

    // GAP — members-home §2: "16pt top inset → SearchField (C-034) 408×44 → 16pt → chip row" — a
    // vertical 16 with no spacing token naming the role (page-margin is horizontal). The 16 under
    // the chip row is the same GAP: §2's "Header (fixed content, 116pt)" = 16 + 44 + 16 + 24 + 16,
    // and the frozen frame `default` starts the first row there (element map: 179 → 195).
    private static let headerGap: CGFloat = 16
    // GAP — members-home §2: "1px `color-layout-border` hairline between rows" — no stroke-width
    // token.
    private static let hairline: CGFloat = 1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — in the app the shell's page scroll scrolls it
        // (HomeSectionLayout); the capture canvas lays it out at its full length.
        VStack(alignment: .leading, spacing: 0) {
            header
            memberList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        .overlay { filterMenu }
    }

    // MARK: §2 Header

    /// §2: "Header (fixed content, 116pt): 16pt top inset → SearchField (C-034) 408×44 → 16pt →
    /// chip row: FilterChip (C-035) ×2 — \"∨ All Groups\", \"∨ All Leaders\" — 24pt tall, 8pt
    /// gap, left-aligned."
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2's "16pt top inset" is the gap between the nav row and the field. The row is now
            // the shell's (D4) and `HomeSectionLayout.navGap` (16) already is that gap, so the
            // screen adds none of its own (routed to /ui2-resolve with D4, F3).
            // §4: C-034, its editable form (D19) — focus is the field's own.
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
                editable: true
            )
            .ui2Element("C-034 SearchField")
            Spacer().frame(height: Self.headerGap)
            // OQ-members-home-3 (non-blocking) proposed default: single line; the chips scroll
            // horizontally only when long selections overflow — the resting row fits, so it is a
            // plain HStack here.
            HStack(spacing: Token.Space.elementGap) {                // §2: "8pt gap"
                FilterChip(type: .menu, active: false, label: state.groupFilterLabel) {
                    presentedMenu = .groups
                }
                .ui2Element("C-035 FilterChip")
                if state.showsLeaderFilter {                         // D7/D15
                    FilterChip(type: .menu, active: false, label: state.leaderFilterLabel) {
                        presentedMenu = .leaders
                    }
                    .ui2Element("C-035 FilterChip 2")
                }
            }
            Spacer().frame(height: Self.headerGap)
        }
        .padding(.horizontal, Token.Space.pageMargin)                // §2: content inset 16
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

    /// §3: "Tap a chip → FilterMenuOverlay (C-036) opens … Options are single-select, plain text
    /// labels" — no glyph (OQ-C-036-002's proposed default: this screen passes none). "Selecting
    /// an option applies the filter immediately, closes the menu … X closes with no change. There
    /// is no tap-outside dismissal surface." The crossfades are C-036's own modifier.
    @ViewBuilder private var filterMenu: some View {
        let options = presentedMenu == .leaders ? state.leaderOptions : state.groupOptions
        let selected = presentedMenu == .leaders ? state.leaderFilterLabel : state.groupFilterLabel
        FilterMenuOverlay(
            options: options.map { FilterMenuOverlay.Option(id: $0, label: $0) },
            selectionMode: .single,
            selectedIDs: [selected],
            onSelect: { option in
                if presentedMenu == .leaders {
                    onSelectLeader(option.id)
                } else {
                    onSelectGroup(option.id)
                }
                presentedMenu = nil
            },
            onClose: { presentedMenu = nil }
        )
        .ui2Element("C-036 FilterMenuOverlay")
        .filterMenuPresentation(isPresented: presentedMenu != nil, onDismiss: { presentedMenu = nil })
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
        groupOptions: ["All Groups", "Young professionals"],
        leaderOptions: ["All Leaders"],
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
