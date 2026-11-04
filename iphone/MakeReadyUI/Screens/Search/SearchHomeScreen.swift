//
//  SearchHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen search-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/search?q=&types=&limit=&cursor= ·
//  GET /api/organizations/my/organizations · GET /api/group-leaders · GET /api/media/tags ·
//  API-GAP one ranked list + filters · API-GAP record, list and delete one recent result
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Search Home — master search, the Search tab's root (§6, D51). The shared C-131 header (C-034
/// over the full-bleed C-130 rail of five C-035 menu chips) pins over either "Recent searches"
/// (C-020 + C-085 rows with ✕) or, once a query is live, ONE list ranked by relevance across every
/// type (C-085 rows without ✕, D67). The shell draws C-084 / C-083 and reserves their height
/// (D64, deviation 2), so this view draws neither.
struct SearchHomeScreen: View {

    /// §3's closed list of five filters, in rail order.
    enum Filter: String, CaseIterable {
        case type, orgs, groups, leaders, tags
    }

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per row, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        /// C-131 `query` — the current query; "" → the placeholder shows (§3 states 1/2).
        var searchText: String
        // ── C-035 `label` per chip (§3: at rest it names its dimension; one pick shows the value;
        //    several show "n <noun>") ──
        var typeFilterLabel: String
        var orgFilterLabel: String
        var groupFilterLabel: String
        var leaderFilterLabel: String
        var tagFilterLabel: String
        /// `Filter` raw values of the chips with picks — C-035 `active` (§3).
        var activeFilters: [String]
        // ── Recent section (§3 state 1) — C-085 `trailing=remove`, newest first ──
        /// C-085 `kind` raw values (§4's mapping: `program`, `member`, `group`, `lesson`, `event`,
        /// `post`, `media`, `photo`).
        var recentKinds: [String]
        var recentTitles: [String]
        /// C-085 `description` — the "Created <date>" meta line (§3), supplied formatted.
        var recentDescriptions: [String]
        // ── Query results (§3 states 3/4) — C-085 `trailing=none`, in relevance order ──
        var resultKinds: [String]
        var resultTitles: [String]
        var resultDescriptions: [String]
        /// master-search D41 — the results belong to the current query. With no rows and no answer
        /// the screen keeps the last render instead of printing the no-results line.
        var queryAnswered: Bool = true
        /// master-search D41 (refined) — the last answered query, when that answer had no rows and
        /// the current query has none yet. With no rows and no answer, the screen keeps printing the
        /// no-results line for this query instead of falling through to the recents. nil → today's
        /// fall-through. A prop, never screen `@State` (R-01).
        var heldNoResultsQuery: String?
    }

    /// What the body draws below the header, decided from the inputs alone (§3 states 1–4, D41).
    enum Content: Equatable {
        case results
        case noResults(query: String)
        case recents
        case empty
    }

    /// §3: a query of 2+ characters shows its rows, or its no-results line once answered (D41), or
    /// the held query's line while the new one is unanswered; otherwise the recents, or nothing.
    static func content(for state: State, query: String) -> Content {
        if query.count >= minimumQueryLength {
            if !state.resultTitles.isEmpty { return .results }
            if state.queryAnswered { return .noResults(query: query) }
            if let held = state.heldNoResultsQuery { return .noResults(query: held) }
        }
        // §3 state 2: no recents → the section, title included, is absent.
        return state.recentTitles.isEmpty ? .empty : .recents
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onSearch: (String) -> Void = { _ in }         // §3: typing runs the debounced query
    var onTapFilter: (Filter) -> Void = { _ in }      // §3/§6: a chip presents C-036
    var onOpenRecent: (Int) -> Void = { _ in }        // §3: recent row tap → record + open (§6)
    var onRemoveRecent: (Int) -> Void = { _ in }      // §3: recent row ✕ → remove that one item
    var onOpenResult: (Int) -> Void = { _ in }        // §3: result row tap → record + open (§6)
    var onResultAppear: (Int) -> Void = { _ in }      // §3 (R-28): next page near the list's end

    // R-31 ephemeral UI: the query as typed (§5 "the query text … screen-local @State").
    @SwiftUI.State private var query: String

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onTapFilter: @escaping (Filter) -> Void = { _ in },
        onOpenRecent: @escaping (Int) -> Void = { _ in },
        onRemoveRecent: @escaping (Int) -> Void = { _ in },
        onOpenResult: @escaping (Int) -> Void = { _ in },
        onResultAppear: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onTapFilter = onTapFilter
        self.onOpenRecent = onOpenRecent
        self.onRemoveRecent = onRemoveRecent
        self.onOpenResult = onOpenResult
        self.onResultAppear = onResultAppear
        _query = SwiftUI.State(initialValue: state.searchText)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2: placeholder "Search content, users, and media".
    private static let searchPlaceholder = "Search content, users, and media"
    /// §2: C-020 `section/none` "Recent searches".
    private static let recentTitle = "Recent searches"
    /// §3 state 3: "query ≥ 2 chars" (OQ-search-home-4a).
    private static let minimumQueryLength = 2

    // MARK: - §2 geometry the screen owns

    // GAP — search-home §2 / deviation 5: "each followed by a 1px `color-layout-border`
    // hairline" — no stroke-width token.
    private static let hairline: CGFloat = 1

    // MARK: - Derived (§3)

    /// §2 rail order, each with its current label.
    private var filterChips: [(filter: Filter, label: String)] {
        [
            (.type, state.typeFilterLabel),
            (.orgs, state.orgFilterLabel),
            (.groups, state.groupFilterLabel),
            (.leaders, state.leaderFilterLabel),
            (.tags, state.tagFilterLabel)
        ]
    }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — in the app the container's scroll scrolls it; the
        // capture canvas lays it out at its full length. §2 Pinning: C-131 is the pinned section
        // header of a LazyVStack, so only the list scrolls. The status bar is the harness's.
        // swiftlint:disable:next lazy_container_in_overlay_content - §2 Pinning: only a lazy stack pins.
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            Section {
                switch Self.content(for: state, query: query) {
                case .results: resultsList
                case .noResults(let noResultsQuery): noResultsLine(for: noResultsQuery)
                case .recents: recentSection
                case .empty: EmptyView()
                }
            } header: {
                header
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)              // §2 + deviation 6: page background
    }

    // MARK: §2 Header

    /// §4: C-131 with five C-035 `Menu` chips in its slot. No `onSearchActiveChange`: there is no
    /// TopNav to hide (§3).
    private var header: some View {
        SearchFilterHeader(
            query: query,
            onQueryChange: { newValue in
                query = newValue
                onSearch(newValue)
            },
            placeholder: Self.searchPlaceholder,
            placement: .underScreenHeader
        ) {
            ForEach(Array(filterChips.enumerated()), id: \.offset) { index, chip in
                FilterChip(
                    type: .menu,
                    active: state.activeFilters.contains(chip.filter.rawValue),
                    label: chip.label,
                    onTap: { onTapFilter(chip.filter) }
                )
                .ui2Element(index == 0 ? "C-035 FilterChip" : "C-035 FilterChip \(index + 1)")
            }
        }
        .ui2Element("C-131 SearchFilterHeader")
    }

    // MARK: §2 Recent section

    /// §2: "column, padding `space-page-margin`, gap `space-stack-gap`" — C-020 then C-085 rows,
    /// each followed by a hairline.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.stackGap) {
            SectionHeader(title: Self.recentTitle, style: .section, accessory: .none)
                .ui2Element("C-020 SectionHeader")
            VStack(spacing: 0) {
                ForEach(state.recentTitles.indices, id: \.self) { index in
                    SearchResultRow(
                        kind: kind(state.recentKinds, index),
                        title: state.recentTitles[index],
                        description: value(state.recentDescriptions, index),
                        trailing: .remove,
                        onTap: { onOpenRecent(index) },
                        onRemove: { onRemoveRecent(index) }
                    )
                    .ui2Element(index == 0 ? "C-085 SearchResultRow" : "C-085 SearchResultRow \(index + 1)")
                    hairlineView
                }
            }
        }
        .padding(Token.Space.pageMargin)
    }

    // MARK: §3 states 3–4

    /// §2 No-results line (state 4, OQ-4b): `type-body-sm`, `color-text-secondary`, centred in the
    /// content width, `space-page-margin` below the header.
    private func noResultsLine(for noResultsQuery: String) -> some View {
        Text("No results for \"\(noResultsQuery)\"")
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(Token.Space.pageMargin)
    }

    /// §2 Results list (state 3): padding `space-page-margin`, then C-085 rows + hairlines.
    /// One ranked list: no C-020 title and no per-type sections (D67).
    private var resultsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(state.resultTitles.indices, id: \.self) { index in
                SearchResultRow(
                    kind: kind(state.resultKinds, index),
                    title: state.resultTitles[index],
                    description: value(state.resultDescriptions, index),
                    trailing: .none,
                    onTap: { onOpenResult(index) }
                )
                .ui2Element(index == 0 ? "C-085 SearchResultRow" : "C-085 SearchResultRow \(index + 1)")
                .onAppear { onResultAppear(index) }
                hairlineView
            }
        }
        .padding(Token.Space.pageMargin)
    }

    /// Deviation 5: the screen's list separator, drawn after each row (R-16). §2 "rows 408×74, no
    /// gap": the frame's pitch is 74 (hairlines 4536:8505 / 4536:8507 at y292 / y366), so the line
    /// takes no layout height of its own.
    private var hairlineView: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(maxWidth: .infinity)
            .frame(height: Self.hairline)
            .padding(.bottom, -Self.hairline)
    }

    private func kind(_ kinds: [String], _ index: Int) -> SearchResultRow.Kind {
        index < kinds.count ? SearchResultRow.Kind(rawValue: kinds[index]) ?? .program : .program
    }

    private func value(_ values: [String], _ index: Int) -> String? {
        index < values.count && !values[index].isEmpty ? values[index] : nil
    }
}

// MARK: - Sample states (the preview props, written as Swift)

extension SearchHomeScreen.State {
    /// Frame 4536:8480's two rows (deviation 7: sample data).
    private static let frameKinds = ["program", "program"]
    private static let frameTitles = ["Deep dive on the book of Romans", "Romans in 30 days"]
    private static let frameDescriptions = ["Created Feb 1, 2021", "Created Jan 15, 2025"]

    /// §3 1 Recents — populated: the frozen frame, every chip at rest.
    static let recentsPopulated = Self(
        searchText: "",
        typeFilterLabel: "Type", orgFilterLabel: "Orgs", groupFilterLabel: "Groups",
        leaderFilterLabel: "Leaders", tagFilterLabel: "Tags", activeFilters: [],
        recentKinds: frameKinds, recentTitles: frameTitles, recentDescriptions: frameDescriptions,
        resultKinds: [], resultTitles: [], resultDescriptions: [])
    /// §3 2 Recents — empty: the header only.
    static let recentsEmpty: Self = {
        var sample = recentsPopulated
        sample.recentKinds = []
        sample.recentTitles = []
        sample.recentDescriptions = []
        return sample
    }()
    /// §3 3 Querying — results: one ranked list across types; rows are the frame's and C-085's
    /// own samples (`recent`, `result`, `media`, `lesson`, `photo`).
    static let queryingResults: Self = {
        var sample = recentsPopulated
        sample.searchText = "Romans"
        sample.resultKinds = ["program", "media", "program", "lesson", "photo"]
        sample.resultTitles = [
            "Deep dive on the book of Romans", "Romans 1 — week one teaching", "Romans in 30 days",
            "Justified by faith", "Sunrise over the Sea of Galilee"
        ]
        sample.resultDescriptions = [
            "Created Feb 1, 2021", "Created Jan 15, 2025", "Created Jan 15, 2025",
            "Created Feb 1, 2021", "Created Mar 9, 2025"
        ]
        return sample
    }()
    /// §3 4 Querying — no results.
    static let queryingNoResults: Self = {
        var sample = recentsPopulated
        sample.searchText = "Romans"
        return sample
    }()
    /// §3 5 Loading (R-27): the cached recents render at once, no spinner.
    static let loading = recentsPopulated
    /// §3 6 Error: the last rendered state is kept, no error UI.
    static let error = recentsPopulated
}

#Preview("Recents — populated") {
    SearchHomeScreen(state: .recentsPopulated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Recents — empty") {
    SearchHomeScreen(state: .recentsEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Querying — results") {
    SearchHomeScreen(state: .queryingResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Querying — no results") {
    SearchHomeScreen(state: .queryingNoResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Loading") {
    SearchHomeScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Error") {
    SearchHomeScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
