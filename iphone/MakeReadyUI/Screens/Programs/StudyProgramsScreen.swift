//
//  StudyProgramsScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen study-programs in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/programs ·
//  GET /api/programs?leaders=<id,id>
//  (the org-scope filter, the org leader list and a server-side text search are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Study programs — "main list of all study programs available to the group leader" (the
/// owner's description): the Programs tab of the Home section switcher (§6). The shell's C-019
/// TopNav owns the nav row (§1 deviation 3), so the screen starts at a header of C-034 search
/// over two C-035 filter chips, then one C-059 `state: .program` row per program with a C-088
/// rule under each, the last one included (§2).
/// Composed only of §4's C-034, C-035, C-059 and C-088. §3 Filter API (owner 2026-10-28:
/// exactly `groups-home`'s): a chip tap presents C-036 FilterMenuOverlay in-screen,
/// multi-select with Save; Save leaves through `onSaveOrgs` / `onSaveLeaders`.
///
/// §3 names five states: `loading`, `populated`, `filtered-empty`, `empty` and `error`.
/// `loading` draws skeleton C-059 `Program` rows (108 tall, C-088 rule under each) under the
/// persistent header, so the body is never blank. `error`'s inline retry is one centred "Retry"
/// line (OQ-study-programs-7) that calls `onRetry`.
struct StudyProgramsScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays — one
    /// entry per program row — because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05). Order is the server's (OQ-study-programs-004: `updatedAt desc`).
    struct State {
        // ── Header (§2) ──
        /// C-034 `text`: the current query. "" shows the placeholder (§4 `Default`).
        var searchText: String
        /// §3 Filter API: the org chip is drawn only when true.
        var orgFilterVisible: Bool
        /// C-035 `label` per chip: "The label is the current selection, per the C-035 contract"
        /// (§2). §2's resting labels: "All Orgs" · "All Leaders".
        var orgFilterLabel: String
        var leaderFilterLabel: String
        /// §3 Filter API: C-036 options of the Orgs menu (org scopes; no "All Orgs" row — an
        /// empty selection means no filter).
        var orgOptions: [String]
        /// C-036 options of the Leaders menu — the org's program creators.
        var leaderOptions: [String]
        /// The checked Orgs options (ids = labels until a container supplies ids); non-empty =
        /// the chip is active.
        var selectedOrgs: Set<String> = []
        /// The checked Leaders options.
        var selectedLeaders: Set<String> = []
        /// §3 `loading`: "first launch with no cached data". The body draws skeleton rows.
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

    /// Which C-036 menu is presented — the one screen-local choice §3 makes.
    private enum FilterMenu {
        case orgs
        case leaders
    }

    let state: State
    // §3 interactions that leave the screen. Each is an on<Verb> closure with R-03's no-op
    // default. The screen never decides what an action means.
    var onSearch: (String) -> Void = { _ in }       // §3: live text filter (300ms, min 2)
    var onSaveOrgs: (Set<String>) -> Void = { _ in }    // §3: Save on the Orgs menu
    var onSaveLeaders: (Set<String>) -> Void = { _ in } // §3: Save on the Leaders menu
    var onOpenProgram: (Int) -> Void = { _ in }     // §3: C-059 tap → study-program-home, by row
    var onRetry: () -> Void = {}                    // §3: error-state retry tap → re-run the fetch

    // R-31 ephemeral UI: the query as typed (§3 "a live text filter") and the presented menu
    // (§3 chip taps → C-036).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSaveOrgs: @escaping (Set<String>) -> Void = { _ in },
        onSaveLeaders: @escaping (Set<String>) -> Void = { _ in },
        onOpenProgram: @escaping (Int) -> Void = { _ in },
        onRetry: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSaveOrgs = onSaveOrgs
        self.onSaveLeaders = onSaveLeaders
        self.onOpenProgram = onOpenProgram
        self.onRetry = onRetry
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2: "placeholder \"Search programs\"".
    private static let searchPlaceholder = "Search programs"
    /// §2's resting chip labels, in §2's order (org scope · leaders) — a chip off its resting
    /// label is narrowing.
    private static let restingFilterLabels = ["All Orgs", "All Leaders"]
    /// §3 `loading`: skeleton rows drawn while no row has landed — the frozen frame's count.
    private static let skeletonRowCount = 3
    /// §3 / OQ-study-programs-004 (closed): the two centred lines.
    private static let noMatchMessage = "No programs match"
    private static let emptyMessage = "No programs yet"
    /// §3 `error` / OQ-study-programs-7: the inline retry line.
    private static let retryLabel = "Retry"
    /// §3: "Debounce and min-chars follow search-home: 300ms, min 2".
    private static let minimumQueryLength = 2

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's; the C-019 TopNav is the shell's (§1 deviation 3).
        VStack(alignment: .leading, spacing: 0) {
            header
            programList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        // §3 Filter API: the screen presents C-036 itself (filter-menu-fullscreen: in the app the
        // shell draws the menu above all chrome).
        .filterMenuPresentation(isPresented: presentedMenu != nil, onDismiss: { presentedMenu = nil }) {
            filterMenu
        }
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

    /// §2: "Filter rail: 2 × C-035 FilterChip (`type=Menu`), gap `space-element-gap` (8), 24
    /// tall". Both chips fit the width, so the rail is a plain row. A chip is active while it
    /// has a pick; the org chip is drawn only when `orgFilterVisible` (§3 Filter API).
    private var chipRow: some View {
        HStack(spacing: Token.Space.elementGap) {
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
    }

    /// §4: a `Menu` chip whose tap presents C-036. `onTap:` is passed by label: an unlabelled
    /// trailing closure on FilterChip binds to `onSelect` (Swift 5's backward scan), which a
    /// `Menu` chip never fires (the GroupsHomeScreen precedent).
    static func menuChip(label: String, active: Bool, onTap: @escaping () -> Void) -> FilterChip {
        FilterChip(type: .menu, active: active, label: label, onTap: onTap)
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
            if state.loading, visibleRows.isEmpty {
                // §3 `loading`: skeleton C-059 `Program` rows, 108 tall each, with C-088 rules —
                // the row at its contracted geometry with no data: empty title, description and
                // caption lines in their 20pt boxes, and the ruled missing-cover box.
                ForEach(0..<Self.skeletonRowCount, id: \.self) { index in
                    StudyProgramRow(
                        state: .program,
                        title: "",
                        description: "",
                        caption: "",
                        progress: 0,
                        metaChips: [],
                        cover: nil
                    )
                    .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: index + 1))
                    SectionDivider()
                        .ui2Element(Self.partName("C-088 SectionDivider", ordinal: index + 1))
                }
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
            if state.failed, !state.loading {
                // §3 `error` / OQ-study-programs-7: "one centred "Retry" line in the error body
                // (type-body-sm, color-accent, the same slot as the empty-state line)".
                SwiftUI.Button(action: onRetry) {
                    Text(Self.retryLabel)
                        .designTextStyle(Token.TypeStyle.bodySm)
                        .foregroundStyle(Token.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
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

    /// §3: "Search: a live client-side text filter over program title and description … it
    /// applies from 2 characters".
    private var needle: String {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= Self.minimumQueryLength ? trimmed : ""
    }

    /// §3 `loading` and `error` show no rows; otherwise every program the query leaves. §3: the
    /// match is "diacritic- and case-insensitive (locale-standard containment, so \"cafe\"
    /// matches \"Café\")".
    private var visibleRows: [Int] {
        guard !state.loading, !state.failed else { return [] }
        return state.programTitles.indices.filter { row in
            needle.isEmpty
                || state.programTitles[row].localizedStandardContains(needle)
                || (state.programDescriptions[safe: row] ?? "").localizedStandardContains(needle)
        }
    }

    /// §3: `filtered-empty` → "No programs match"; `empty` (the org has no programs) → "No
    /// programs yet". `filtered-empty` is the empty body while a query or a chip off its resting
    /// label is narrowing the list.
    private var bodyMessage: String? {
        guard visibleRows.isEmpty, !state.loading, !state.failed else { return nil }
        let narrowed = !needle.isEmpty || chipLabels != Self.restingFilterLabels
            || !state.selectedOrgs.isEmpty || !state.selectedLeaders.isEmpty
        return narrowed ? Self.noMatchMessage : Self.emptyMessage
    }

    // MARK: §3 Filter menu

    /// §3: chip taps → C-036 FilterMenuOverlay, "multi-select with a Save action": toggling rows
    /// changes the draft only; Save commits through the save callback; dismissing discards.
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

    /// §3 `loading`: "skeleton program rows … under the persistent header block; the body is
    /// never blank. Search and chips render at once."
    static let loading = Self(
        searchText: "",
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: [],
        leaderOptions: [],
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
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: [],
        leaderOptions: [],
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
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: [],
        leaderOptions: [],
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
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: [],
        leaderOptions: [],
        loading: false,
        failed: false,
        programTitles: [],
        programDescriptions: [],
        programEnrollmentCounts: [],
        programCoverURLs: []
    )

    /// §3 `error`: "inline retry in the body. The header stays." — the centred "Retry" line
    /// (OQ-study-programs-7).
    static let error = Self(
        searchText: "",
        orgFilterVisible: true,
        orgFilterLabel: "All Orgs",
        leaderFilterLabel: "All Leaders",
        orgOptions: [],
        leaderOptions: [],
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
