//
//  SearchHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen search-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/search?q=&types=&limit= ·
//  API-GAP record a recently opened result · API-GAP list recent results ·
//  API-GAP delete one recent result
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Search Home — the Search tab's root (§6, D51): org-wide search over the user's recently
/// opened results. A header of C-034 search over the C-035 category rail, then either the
/// "Recent searches" section (C-020 + C-085 rows with ✕) or, once a query is live, one C-020
/// section per result type (C-085 rows without ✕), with the app-level C-084 TabBar pinned at
/// the bottom, Search active (§2). C-083 renders only inside C-084.
struct SearchHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per row, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        /// C-034 `text` — the current query; "" → the placeholder shows (§3 states 1/2).
        var searchText: String
        /// The active C-035 chip's label — one of `SearchHomeScreen.chips` (§3: default `All`).
        var activeChip: String
        // ── Recent section (§3 state 1) — C-085 `trailing=remove`, newest first ──
        /// C-085 `kind` raw values (`program`, `member`, `media`, `group`, `lesson`, `event`,
        /// `post`).
        var recentKinds: [String]
        var recentTitles: [String]
        /// C-085 `description` — the "Created <date>" meta line (§5), supplied formatted.
        var recentDescriptions: [String]
        // ── Query results (§3 states 3/4) — C-085 `trailing=none` ──
        var resultKinds: [String]
        var resultTitles: [String]
        var resultDescriptions: [String]
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onSearch: (String) -> Void = { _ in }         // §3: typing runs the debounced query
    var onSelectChip: (String) -> Void = { _ in }     // §3: a chip scopes recents + the query
    var onOpenRecent: (Int) -> Void = { _ in }        // §3: recent row tap → record + open (§6)
    var onRemoveRecent: (Int) -> Void = { _ in }      // §3: recent row ✕ → delete from history
    var onOpenResult: (Int) -> Void = { _ in }        // §3: result row tap → record + open (§6)
    var onSelectTab: (TabBar.Tab) -> Void = { _ in }  // §3: C-084 root tabs (shell-tabs)
    var onAdd: () -> Void = {}                        // §6: C-084 Add (shell-tabs)

    // R-31 ephemeral UI: the query as typed and the active chip (§5 "the query text and active
    // chip are screen-local @State").
    @SwiftUI.State private var query: String
    @SwiftUI.State private var activeChip: String

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSelectChip: @escaping (String) -> Void = { _ in },
        onOpenRecent: @escaping (Int) -> Void = { _ in },
        onRemoveRecent: @escaping (Int) -> Void = { _ in },
        onOpenResult: @escaping (Int) -> Void = { _ in },
        onSelectTab: @escaping (TabBar.Tab) -> Void = { _ in },
        onAdd: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSelectChip = onSelectChip
        self.onOpenRecent = onOpenRecent
        self.onRemoveRecent = onRemoveRecent
        self.onOpenResult = onOpenResult
        self.onSelectTab = onSelectTab
        self.onAdd = onAdd
        _query = SwiftUI.State(initialValue: state.searchText)
        _activeChip = SwiftUI.State(initialValue: state.activeChip)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §1: placeholder "Search content, users, and media" (frame 4536:8480).
    private static let searchPlaceholder = "Search content, users, and media"
    /// §2 category rail, in order (OQ-search-home-3).
    static let chips = ["All", "Programs", "Members", "Media"]
    /// §2: C-020 `section/none` "Recent searches".
    private static let recentTitle = "Recent searches"
    /// §3 state 3: "query ≥ 2 chars" (OQ-search-home-4a).
    private static let minimumQueryLength = 2
    /// §3 state 3: result sections titled by type, in §3's order.
    private static let resultSections: [(kind: SearchResultRow.Kind, title: String)] = [
        (.program, "Programs"), (.member, "Members"), (.media, "Media"), (.group, "Groups"),
        (.lesson, "Lessons"), (.event, "Events"), (.post, "Posts")
    ]

    // MARK: - §2 geometry the screen owns

    // GAP — search-home §2 / deviation 2: "each followed by a 1px `color-layout-border`
    // hairline" — no stroke-width token.
    private static let hairline: CGFloat = 1
    // GAP — search-home §2: "Nav bar 872–956 … pinned bottom". The content region is a minimum
    // so the bar sits at the canvas bottom when the harness proposes no height: the frame's bar
    // top (872) less the device's 59pt top inset the harness draws (the frame's own status bar
    // is 46). Flexible above it, so a longer list grows the canvas instead.
    private static let contentRegionHeight: CGFloat = 813

    // MARK: - Derived (§3)

    /// §3: "A query of 0–1 chars shows state 1/2."
    private var isQuerying: Bool { query.count >= Self.minimumQueryLength }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 1) is the harness's.
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if isQuerying {
                    queryContent
                } else if !state.recentTitles.isEmpty {
                    // §3 state 2 (OQ-4c): no recents → the section, header included, is absent.
                    recentSection
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.contentRegionHeight,
                   maxHeight: .infinity, alignment: .top)

            // §2: C-084, Search `Active`; app shell, pinned bottom (D51).
            TabBar(selected: .search, onSelect: onSelectTab, onAdd: onAdd)
                .ui2Element("C-084 TabBar")
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)              // §2 + deviation 3: page background
    }

    // MARK: §2 Header

    /// §2: "column, padding `space-page-margin` (16) all sides, gap 16" — C-034 then the rail.
    private var header: some View {
        VStack(alignment: .leading, spacing: Token.Space.pageMargin) {
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                // §4: `Default` in the frame, `Focus` / `Has value` while typing.
                focused: !query.isEmpty,
                onChange: { query = $0; onSearch($0) },
                // §3: "C-039 clear → back to state 1/2, active chip kept."
                onClear: { query = ""; onSearch("") }
            )
            .ui2Element("C-034 SearchField")

            categoryRail
        }
        .padding(Token.Space.pageMargin)
    }

    /// §2: "4 × C-035 `type=Button`, gap `space-element-gap` (8) … scrolls horizontally if it
    /// overflows (C-035 §3c)".
    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Token.Space.elementGap) {
                ForEach(Array(Self.chips.enumerated()), id: \.offset) { index, chip in
                    FilterChip(
                        type: .button,
                        active: chip == activeChip,
                        label: chip,
                        // §3: "it becomes the sole active chip; scopes recents and the query".
                        // C-035 §4: a `type=Button` chip fires `onSelect` (OQ-C-035-5).
                        onSelect: { activeChip = chip; onSelectChip(chip) }
                    )
                    .ui2Element(index == 0 ? "C-035 FilterChip" : "C-035 FilterChip \(index + 1)")
                }
            }
        }
    }

    // MARK: §2 Recent section

    /// §2: "column, padding 16, gap 16" — C-020 then C-085 rows, each followed by a hairline.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.pageMargin) {
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

    @ViewBuilder private var queryContent: some View {
        if state.resultTitles.isEmpty {
            // §2 / §3 state 4 (OQ-4b): "one centred secondary line … `type-body-sm` in
            // `color-text-secondary`, centred in the content width, 16 below the rail" — the
            // header's own bottom padding is that 16.
            Text("No results for \"\(query)\"")
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Token.Space.pageMargin)
        } else {
            // §2: "Query states reuse the Recent section's geometry: each type section is
            // padding 16, gap 16, C-020 title then C-085 rows + hairlines".
            ForEach(Array(sectionsWithResults.enumerated()), id: \.offset) { sectionIndex, section in
                VStack(alignment: .leading, spacing: Token.Space.pageMargin) {
                    SectionHeader(title: section.title, style: .section, accessory: .none)
                        .ui2Element(sectionIndex == 0 ? "C-020 SectionHeader"
                                    : "C-020 SectionHeader \(sectionIndex + 1)")
                    VStack(spacing: 0) {
                        ForEach(section.rows, id: \.self) { index in
                            SearchResultRow(
                                kind: section.kind,
                                title: state.resultTitles[index],
                                description: value(state.resultDescriptions, index),
                                trailing: .none,
                                onTap: { onOpenResult(index) }
                            )
                            .ui2Element(index == 0 ? "C-085 SearchResultRow"
                                        : "C-085 SearchResultRow \(index + 1)")
                            hairlineView
                        }
                    }
                }
                .padding(Token.Space.pageMargin)
            }
        }
    }

    /// §3 state 3: one section per returned type, in §3's order; a type with no rows is absent.
    private var sectionsWithResults: [(kind: SearchResultRow.Kind, title: String, rows: [Int])] {
        Self.resultSections.compactMap { section in
            let rows = state.resultTitles.indices.filter { kind(state.resultKinds, $0) == section.kind }
            return rows.isEmpty ? nil : (section.kind, section.title, rows)
        }
    }

    /// Deviation 2: the screen's list separator, drawn after each row (R-16).
    private var hairlineView: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(maxWidth: .infinity)
            .frame(height: Self.hairline)
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
    /// Frame 4536:8480's two rows (deviation 4: sample data).
    private static let frameKinds = ["program", "program"]
    private static let frameTitles = ["Deep dive on the book of Romans", "Romans in 30 days"]
    private static let frameDescriptions = ["Created Feb 1, 2021", "Created Jan 15, 2025"]

    /// §3 1 Recents — populated: the frozen frame.
    static let recentsPopulated = Self(
        searchText: "", activeChip: "All",
        recentKinds: frameKinds, recentTitles: frameTitles, recentDescriptions: frameDescriptions,
        resultKinds: [], resultTitles: [], resultDescriptions: [])
    /// §3 2 Recents — empty: header + rail only.
    static let recentsEmpty = Self(
        searchText: "", activeChip: "All",
        recentKinds: [], recentTitles: [], recentDescriptions: [],
        resultKinds: [], resultTitles: [], resultDescriptions: [])
    /// §3 3 Querying — results: the frame's two programs as the hits for "Romans".
    static let queryingResults = Self(
        searchText: "Romans", activeChip: "All",
        recentKinds: frameKinds, recentTitles: frameTitles, recentDescriptions: frameDescriptions,
        resultKinds: frameKinds, resultTitles: frameTitles, resultDescriptions: frameDescriptions)
    /// §3 4 Querying — no results.
    static let queryingNoResults = Self(
        searchText: "Romans", activeChip: "All",
        recentKinds: frameKinds, recentTitles: frameTitles, recentDescriptions: frameDescriptions,
        resultKinds: [], resultTitles: [], resultDescriptions: [])
    /// §3 5 Loading: R-27 cache-first — the cached recents render at once, no spinner.
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
