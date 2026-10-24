//
//  StudyProgramsScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen study-programs in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/programs ·
//  GET /api/programs?leaders=<id,id>
//  (the org-scope filter, the org leader list and a server-side text search are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Study programs — "main list of all study programs available to the group leader" (the
/// owner's description): the Programs tab of the Home section switcher (§6). The collapsed C-019
/// nav row, a header of C-034 search over two C-035 filter chips, then one C-059
/// `state: .program` row per program with a C-088 rule under each, the last one included (§2).
/// Composed only of §4's C-019, C-034, C-035, C-059 and C-088. C-036 FilterMenuOverlay is
/// presented by a chip but §4 drops it ("presented, not on the screen"), so a chip tap leaves
/// the screen through `onOpenFilter`.
///
/// §3 names five states: `loading`, `populated`, `filtered-empty`, `empty` and `error`. The
/// `loading` skeleton rows and the `error` inline retry name no §4 component, no geometry and no
/// copy, so both render the persistent header over an empty body and the missing parts are
/// reported as spec gaps — not improvised here (the enrollments-home precedent).
struct StudyProgramsScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays — one
    /// entry per program row — because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05). Order is the server's (OQ-study-programs-004: `updatedAt desc`).
    struct State {
        // ── Header (§2) ──
        /// C-034 `text`: the current query. "" shows the placeholder (§4 `Default`).
        var searchText: String
        /// C-035 `label` per chip: "The label is the current selection, per the C-035 contract"
        /// (§2). §2's resting labels: "All Orgs" · "All Leaders".
        var orgFilterLabel: String
        var leaderFilterLabel: String
        /// §3 `loading`: "first launch with no cached data". The body shows no rows.
        var loading: Bool
        /// §3 `error`: the load failed. The body shows no rows.
        var failed: Bool
        // ── Rows (§2): one C-059 `state: .program` per program ──
        /// C-059 `title`.
        var programTitles: [String]
        /// C-059 `description` (one line, ellipsized in `Program`).
        var programDescriptions: [String]
        /// «n» of the C-059 `caption` "«n» enrolled" — `_count.enrollments` (OQ-study-programs-006).
        var programEnrollmentCounts: [Int]
        /// C-059 `cover`, resolved from the media cache by URL (R-19/R-32); "" = none.
        var programCoverURLs: [String]
    }

    let state: State
    // §3 interactions that leave the screen. Each is an on<Verb> closure with R-03's no-op
    // default. The screen never decides what an action means.
    var onSelectTab: (String) -> Void = { _ in }    // C-019 tab tap → that Home section (§6)
    var onToggleNav: () -> Void = {}                // C-019 collapse ⇄ expand
    var onSearch: (String) -> Void = { _ in }       // §3: live text filter (300ms, min 2)
    var onOpenFilter: (String) -> Void = { _ in }   // §3: chip tap → C-036 for that dimension
    var onOpenProgram: (Int) -> Void = { _ in }     // §3: C-059 tap → study-program-home, by row

    // R-31 ephemeral UI: the query as typed (§3 "a live text filter").
    @SwiftUI.State private var query: String

    init(
        state: State,
        onSelectTab: @escaping (String) -> Void = { _ in },
        onToggleNav: @escaping () -> Void = {},
        onSearch: @escaping (String) -> Void = { _ in },
        onOpenFilter: @escaping (String) -> Void = { _ in },
        onOpenProgram: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSelectTab = onSelectTab
        self.onToggleNav = onToggleNav
        self.onSearch = onSearch
        self.onOpenFilter = onOpenFilter
        self.onOpenProgram = onOpenProgram
        _query = SwiftUI.State(initialValue: state.searchText)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2: "C-019 TopNav, collapsed row, 32pt, **Programs** active".
    private static let selectedTab = "Programs"
    /// §2: "placeholder \"Search programs\"".
    private static let searchPlaceholder = "Search programs"
    /// §3 chip dimensions, in §2's order: org scope · leaders (program creators).
    private static let filterDimensions = ["Orgs", "Leaders"]
    /// §2's resting chip labels, in the same order — a chip off its resting label is narrowing.
    private static let restingFilterLabels = ["All Orgs", "All Leaders"]
    /// §3 / OQ-study-programs-004 (closed): the two centred lines.
    private static let noMatchMessage = "No programs match"
    private static let emptyMessage = "No programs yet"
    /// §3: "Debounce and min-chars follow search-home: 300ms, min 2".
    private static let minimumQueryLength = 2

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            navRow
            header
            programList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
    }

    /// §2: "C-019 TopNav, collapsed row, 32pt, Programs active" — `expansion` 0 at rest
    /// (`scrollOffset` 0). No `onAdd`: no create affordance is drawn (OQ-study-programs-005).
    private var navRow: some View {
        TopNav(
            tabs: TopNav.designedTabs,
            selectedTab: Self.selectedTab,
            expansion: 0,
            scrollOffset: 0,
            onSelect: onSelectTab,
            onToggleExpansion: onToggleNav
        )
        .ui2Element("C-019 TopNav")
    }

    // MARK: §2 Header

    /// §2: "Header block: `space-page-margin` (16) padding on all sides, `space-card-padding`
    /// (16) gap, 116 tall" — persists in every §3 state.
    private var header: some View {
        VStack(alignment: .leading, spacing: Token.Space.cardPadding) {   // §2: 16 gap
            // §2: C-034 "408×44, `Default`" — derived by C-034 from `text.isEmpty × focused`.
            // This presentational screen owns no focus, so `focused` is false.
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
            chipRow
        }
        .padding(Token.Space.pageMargin)
    }

    /// §2: "Filter rail: 2 × C-035 FilterChip (`type=Menu, active=false`), gap
    /// `space-element-gap` (8), 24 tall". Both chips fit the width, so the rail is a plain row.
    private var chipRow: some View {
        HStack(spacing: Token.Space.elementGap) {
            ForEach(chipLabels.indices, id: \.self) { index in
                FilterChip(type: .menu, active: false, label: chipLabels[index]) {
                    onOpenFilter(Self.filterDimensions[index])
                }
                .ui2Element(Self.partName("C-035 FilterChip", ordinal: index + 1))
            }
        }
    }

    // MARK: §2 Program list

    /// §2: "Program list: horizontal `space-page-margin` (16), no top padding. One C-059
    /// StudyProgramRow `state: .program` … per program, stacked with no gap. Under each row is
    /// one C-088 SectionDivider (408 wide), the last one included."
    private var programList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleRows.enumerated()), id: \.element) { position, row in
                programRow(row, ordinal: position + 1)
                SectionDivider()
                    .ui2Element(Self.partName("C-088 SectionDivider", ordinal: position + 1))
            }
            if let message = bodyMessage {
                // §3 / OQ-study-programs-004: "one centred `color-text-secondary` line".
                // GAP — §3 names the colour only; the type style is invites-home's ruled
                // empty line (OQ-invites-home-003: "14 Regular" → `type-body-sm`), as on
                // enrollments-home.
                Text(message)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §2: "This screen passes `title`, `description`, `caption` (\"«n» enrolled\"), `cover` and
    /// `onTap`, and restates none of the row's geometry. `progress` and `metaChips` are ignored
    /// in `Program` (C-059 §4); the screen passes `0` and `[]`."
    private func programRow(_ row: Int, ordinal: Int) -> some View {
        StudyProgramRow(
            state: .program,
            title: state.programTitles[row],
            description: state.programDescriptions[safe: row],
            caption: state.programEnrollmentCounts[safe: row].map { "\($0) enrolled" },
            progress: 0,
            metaChips: [],
            cover: Self.cachedImage(state.programCoverURLs[safe: row]),
            onTap: { onOpenProgram(row) }
        )
        .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: ordinal))
    }

    // MARK: - §3 rules

    private var chipLabels: [String] {
        [state.orgFilterLabel, state.leaderFilterLabel]
    }

    /// §3: "Search: a live text filter over program title and description … min 2".
    private var needle: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= Self.minimumQueryLength ? trimmed : ""
    }

    /// §3 `loading` and `error` show no rows; otherwise every program the query leaves.
    private var visibleRows: [Int] {
        guard !state.loading, !state.failed else { return [] }
        return state.programTitles.indices.filter { row in
            needle.isEmpty
                || state.programTitles[row].localizedCaseInsensitiveContains(needle)
                || (state.programDescriptions[safe: row] ?? "").localizedCaseInsensitiveContains(needle)
        }
    }

    /// §3: `filtered-empty` → "No programs match"; `empty` (the org has no programs) → "No
    /// programs yet". `filtered-empty` is the empty body while a query or a chip off its resting
    /// label is narrowing the list.
    private var bodyMessage: String? {
        guard visibleRows.isEmpty, !state.loading, !state.failed else { return nil }
        let narrowed = !needle.isEmpty || chipLabels != Self.restingFilterLabels
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

    /// R-19/R-32: the cover's bytes come from the media cache by URL; the view does no loading.
    private static func cachedImage(_ raw: String?) -> Image? {
        guard let raw, !raw.isEmpty, let url = URL(string: raw),
              let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
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

extension StudyProgramsScreen.State {

    /// The frozen frame `default`'s three programs (node 4649:43240; §1 deviation 1: sample
    /// content), in the frame's order. The frame ellipsizes the second description at
    /// "…book of Roma…"; its tail completes the visible word. Covers are a stand-in URL (C-059's
    /// own preview picsum seed).
    private static let frameTitles = ["Daily Inspiration", "Romans in 30 days", "My favorite program"]
    private static let frameDescriptions = [
        "All are welcome for anyone who needs it",
        "Anyone interested in studying the book of Romans",
        "A study program that is my favorite"
    ]
    private static let frameEnrollmentCounts = [3, 3, 3]
    private static let frameCoverURLs = [
        "https://picsum.photos/seed/c059/128/176",
        "https://picsum.photos/seed/c059/128/176",
        "https://picsum.photos/seed/c059/128/176"
    ]

    /// §3 `loading`: "skeleton rows under the persistent header block. Search and chips render
    /// at once."
    static let loading = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        loading: true,
        failed: false,
        programTitles: [],
        programDescriptions: [],
        programEnrollmentCounts: [],
        programCoverURLs: []
    )

    /// §3 `populated`: "as in §2" — the frozen frame's three rows.
    static let populated = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        loading: false,
        failed: false,
        programTitles: frameTitles,
        programDescriptions: frameDescriptions,
        programEnrollmentCounts: frameEnrollmentCounts,
        programCoverURLs: frameCoverURLs
    )

    /// §3 `filtered-empty`: the frame's three programs under the query "Exodus", which no title
    /// or description holds — the live filter leaves nothing, so the body shows "No programs
    /// match".
    static let filteredEmpty = Self(
        searchText: "Exodus",
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        loading: false,
        failed: false,
        programTitles: frameTitles,
        programDescriptions: frameDescriptions,
        programEnrollmentCounts: frameEnrollmentCounts,
        programCoverURLs: frameCoverURLs
    )

    /// §3 `empty`: "the org has no programs", every chip at its resting label.
    static let empty = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        loading: false,
        failed: false,
        programTitles: [],
        programDescriptions: [],
        programEnrollmentCounts: [],
        programCoverURLs: []
    )

    /// §3 `error`: "inline retry in the body. The header stays." — the retry has no §4 component
    /// or copy (a spec gap), so the body is empty.
    static let error = Self(
        searchText: "",
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        loading: false,
        failed: true,
        programTitles: [],
        programDescriptions: [],
        programEnrollmentCounts: [],
        programCoverURLs: []
    )
}

// MARK: - Previews (D21): one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("loading") {
    StudyProgramsScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated") {
    StudyProgramsScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("filtered-empty") {
    StudyProgramsScreen(state: .filteredEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    StudyProgramsScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    StudyProgramsScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
