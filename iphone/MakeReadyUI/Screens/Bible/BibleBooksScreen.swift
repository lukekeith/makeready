//
//  BibleBooksScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen bible-books in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/bible/translations ·
//  POST /api/search/smart · GET /api/search/recent?type=bible · DELETE /api/search/recent/:id
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Bible books — the first page of the Bible passage picker (bible-verse-picker D1/D2): C-040
/// back + "Select a book", C-131 with the one translation chip, then either the Old/New Testament
/// grids of C-052 book chips (browse) or, while the field is search-active, the search body
/// (recents, spinner, results, or C-132). Every exit is an `on<Verb>` closure (R-03).
struct BibleBooksScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per cell or row, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        /// The selected translation's code — the C-036 selection key (`selectedIDs`, D7).
        var translationCode: String
        /// C-035 `label` (D55) — the translation's NAME the container passes ("King James Version");
        /// nil = `translationCode`. Tail-truncated when wider than the chip row (C-035 §3c).
        var translationLabel: String? = nil
        /// C-036 `options` — codes (`id`) and names (`label`), popularity desc then name (D7).
        var translationCodes: [String]
        var translationNames: [String]
        /// C-131 `query` — "" shows the placeholder.
        var query: String
        /// §3 search-active: the field is focused (C-131 `initiallyFocused`).
        var searchFocused: Bool
        // ── §2 3a book grids — C-052 `.label`, canonical order (bundled list, D24) ──
        var oldTestamentNumbers: [Int]
        var oldTestamentLabels: [String]
        /// C-052 `fillToken` — the category colour token's member name (D5).
        var oldTestamentFills: [String]
        var newTestamentNumbers: [Int]
        var newTestamentLabels: [String]
        var newTestamentFills: [String]
        /// C-052 `isUsed` — book numbers used by this lesson (D16).
        var usedBooks: [Int]
        // ── §2 3b search body ──
        /// `search-recents` — the recent queries, newest first.
        var recents: [String]
        /// `search-results` Books — C-085 `.book(dotToken:)`.
        var bookResultNumbers: [Int]
        var bookResultNames: [String]
        /// "N chapters · Old Testament" | "N chapters · New Testament", supplied formatted.
        var bookResultDescriptions: [String]
        var bookResultFills: [String]
        /// `search-results` Verses — C-085 `.verse`: reference (or a named passage's title) and
        /// a one-line snippet (or the passage's summary).
        var verseResultTitles: [String]
        var verseResultDescriptions: [String]
        /// `search-loading` — the query is running.
        var searching: Bool
        /// `search-empty` — the query ran and found nothing.
        var searchEmpty: Bool
    }

    /// What the body draws below the header, decided from the inputs alone (§3 states 1–5).
    enum Content: Equatable {
        case browse
        case recents
        case recentsPrompt
        case loading
        case results
        case empty
        case pending
    }

    /// §3: browse until the field is search-active; then empty query → recents (or the prompt),
    /// searching → spinner, nothing found → C-132, rows → results.
    static func content(for state: State, query: String, searchActive: Bool) -> Content {
        guard searchActive else { return .browse }
        if query.isEmpty { return state.recents.isEmpty ? .recentsPrompt : .recents }
        if state.searching { return .loading }
        if state.searchEmpty { return .empty }
        if !state.bookResultNames.isEmpty || !state.verseResultTitles.isEmpty { return .results }
        // Typed, the 300 ms debounce not yet fired (§3): the body stays clear.
        return .pending
    }

    let state: State
    // §3 taps that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                        // C-040 back / edge-swipe
    var onBook: (Int) -> Void = { _ in }               // book chip → bible-chapters
    var onQuery: (String) -> Void = { _ in }           // typing → debounced search
    var onSubmit: () -> Void = {}                      // return → search now, record a recent
    var onRecent: (String) -> Void = { _ in }          // recent row → fill + search
    var onRemoveRecent: (String) -> Void = { _ in }    // recent ✕
    var onBookResult: (Int) -> Void = { _ in }         // book result → bible-chapters
    var onVerseResult: (Int) -> Void = { _ in }        // verse result → bible-reader
    var onTranslation: (String) -> Void = { _ in }     // C-036 pick

    // R-31 ephemeral UI: the query as typed, whether the field is search-active, and whether the
    // translation menu is presented.
    @SwiftUI.State private var query: String
    @SwiftUI.State private var searchActive: Bool
    @SwiftUI.State private var translationMenuOpen = false
    /// The screen's width, measured — the C-035 chip's max width is the rail row inside it (D55).
    @SwiftUI.State private var screenWidth: CGFloat = 0

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onBook: @escaping (Int) -> Void = { _ in },
        onQuery: @escaping (String) -> Void = { _ in },
        onSubmit: @escaping () -> Void = {},
        onRecent: @escaping (String) -> Void = { _ in },
        onRemoveRecent: @escaping (String) -> Void = { _ in },
        onBookResult: @escaping (Int) -> Void = { _ in },
        onVerseResult: @escaping (Int) -> Void = { _ in },
        onTranslation: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onBook = onBook
        self.onQuery = onQuery
        self.onSubmit = onSubmit
        self.onRecent = onRecent
        self.onRemoveRecent = onRemoveRecent
        self.onBookResult = onBookResult
        self.onVerseResult = onVerseResult
        self.onTranslation = onTranslation
        _query = SwiftUI.State(initialValue: state.query)
        _searchActive = SwiftUI.State(
            initialValue: SearchFilterHeader<EmptyView>.isSearchActive(query: state.query, focused: state.searchFocused)
        )
    }

    // MARK: - §2 copy

    private static let title = "Select a book"
    private static let placeholder = "Search reference or topic"
    private static let oldTestamentTitle = "OLD TESTAMENT"
    private static let newTestamentTitle = "NEW TESTAMENT"
    private static let recentsTitle = "Recent searches"
    private static let booksTitle = "Books"
    private static let versesTitle = "Verses"
    private static let promptTitle = "Type to search the Bible"
    private static let emptyTitle = "No results found"
    private static let emptyMessage = "Try a book, a reference or words from a verse."
    /// §2 Book grid: 5 equal columns.
    private static let columns = 5

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // §2 / D53: the ruled exception to `no-root-scroll` — C-040 and C-131 are fixed; the body
        // below them scrolls in the screen's own ScrollView, filling the remaining height. The
        // host gives the screen the full page height. The status bar is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            pageHeader
            searchHeader
            ScrollView(.vertical) {
                switch Self.content(for: state, query: query, searchActive: searchActive) {
                case .browse: browseBody
                case .recents: recentsBody
                case .recentsPrompt: emptyBody(title: Self.promptTitle)
                case .loading: loadingBody
                case .results: resultsBody
                case .empty: emptyBody(title: Self.emptyTitle)
                case .pending: EmptyView()
                }
            }
            .scrollDismissesKeyboard(.interactively)                    // §2: dragging dismisses the keyboard
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { screenWidth = $0 }
        .background(Token.layoutBackground)                     // §2: `color-layout-background`
        // §2 Overlay (pattern sheet): C-036 single-select; in the app the shell draws it above
        // all chrome.
        .filterMenuPresentation(isPresented: translationMenuOpen, onDismiss: { translationMenuOpen = false }) {
            translationMenu
        }
    }

    // MARK: §2 1. Page top

    private var pageHeader: some View {
        PageHeader(
            style: .default,
            title: Self.title,
            leadingGlyph: .back,
            rightButtons: [],
            onLeading: onBack
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: §2 2. Search header

    /// C-131 `underScreenHeader` with ONE C-035 menu chip — the translation's name, else its code
    /// (D55), tail-truncated to the rail row's width (C-035 §3c).
    /// Return searches now and dismisses the keyboard (§3).
    private var searchHeader: some View {
        SearchFilterHeader(
            query: query,
            onQueryChange: { newValue in
                query = newValue
                onQuery(newValue)
            },
            placeholder: Self.placeholder,
            placement: .underScreenHeader,
            onSearchActiveChange: { searchActive = $0 },
            initiallyFocused: state.searchFocused
        ) {
            FilterChip(
                type: .menu,
                active: false,
                label: state.translationLabel ?? state.translationCode,
                onTap: { translationMenuOpen = true },
                maxWidth: chipRowWidth
            )
            .ui2Element("C-035 FilterChip")
        }
        .onSubmit(of: .text) { onSubmit() }
        .ui2Element("C-131 SearchFilterHeader")
    }

    /// The C-130 rail row's width: the screen less `space-page-margin` each side (C-130 §2). nil
    /// until measured, so the first pass is the unconstrained chip.
    private var chipRowWidth: CGFloat? {
        screenWidth > 0 ? max(0, screenWidth - 2 * Token.Space.pageMargin) : nil
    }

    // MARK: §2 3a. Browse body

    /// OLD TESTAMENT then NEW TESTAMENT: each C-020 `.block` caption `space-section-gap` above its
    /// grid, sections `space-section-gap` apart.
    private var browseBody: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.oldTestamentTitle, style: .block, accessory: .none)
                .ui2Element("C-020 SectionHeader")
            bookGrid(
                numbers: state.oldTestamentNumbers,
                labels: state.oldTestamentLabels,
                fills: state.oldTestamentFills,
                ordinalOffset: 0
            )
            SectionHeader(title: Self.newTestamentTitle, style: .block, accessory: .none)
                .ui2Element("C-020 SectionHeader 2")
            bookGrid(
                numbers: state.newTestamentNumbers,
                labels: state.newTestamentLabels,
                fills: state.newTestamentFills,
                ordinalOffset: state.oldTestamentLabels.count
            )
        }
        .padding(Token.Space.pageMargin)
    }

    /// §2 Book grid: 5 equal columns spanning the content width, `space-element-gap` between
    /// columns and rows (OQ-bible-books-002). A short last row keeps the column width.
    private func bookGrid(numbers: [Int], labels: [String], fills: [String], ordinalOffset: Int) -> some View {
        let rows = stride(from: 0, to: labels.count, by: Self.columns).map { start in
            Array(start..<min(start + Self.columns, labels.count))
        }
        return VStack(spacing: Token.Space.elementGap) {
            ForEach(rows, id: \.first) { row in
                HStack(spacing: Token.Space.elementGap) {
                    ForEach(row, id: \.self) { index in
                        let number = value(numbers, index) ?? index + 1
                        DayChip(
                            content: .label(labels[index]),
                            state: .default,
                            fillToken: value(fills, index),
                            isUsed: state.usedBooks.contains(number),
                            onTap: { onBook(number) }
                        )
                        .ui2Element(Self.partName("C-052 DayChip", ordinal: ordinalOffset + index + 1))
                    }
                    ForEach(row.count..<Self.columns, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }

    // MARK: §2 3b. Search body

    /// `search-recents`: C-020 "Recent searches", then one C-085 `verse` row per query with ✕.
    private var recentsBody: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.recentsTitle, style: .section, accessory: .none)
                .ui2Element("C-020 SectionHeader")
            VStack(spacing: 0) {
                ForEach(Array(state.recents.enumerated()), id: \.offset) { index, recent in
                    SearchResultRow(
                        kind: .verse,
                        title: recent,
                        description: nil,
                        trailing: .remove,
                        onTap: { onRecent(recent) },
                        onRemove: { onRemoveRecent(recent) }
                    )
                    .ui2Element(Self.partName("C-085 SearchResultRow", ordinal: index + 1))
                }
            }
        }
        .padding(Token.Space.pageMargin)
    }

    /// `search-loading`: C-076 at its defaults, centred, top inset `space-section-gap`.
    private var loadingBody: some View {
        ActivitySpinner()
            .ui2Element("C-076 ActivitySpinner")
            .frame(maxWidth: .infinity)
            .padding(.top, Token.Space.sectionGap)
    }

    /// `search-results`: Books then Verses; a section with no rows is omitted with its header.
    private var resultsBody: some View {
        let hasBooks = !state.bookResultNames.isEmpty
        return VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            if hasBooks {
                SectionHeader(title: Self.booksTitle, style: .section, accessory: .none)
                    .ui2Element("C-020 SectionHeader")
                VStack(spacing: 0) {
                    ForEach(Array(state.bookResultNames.enumerated()), id: \.offset) { index, name in
                        let number = value(state.bookResultNumbers, index) ?? 0
                        SearchResultRow(
                            kind: .book(dotToken: value(state.bookResultFills, index) ?? ""),
                            title: name,
                            description: value(state.bookResultDescriptions, index),
                            trailing: .none,
                            onTap: { onBookResult(number) }
                        )
                        .ui2Element(Self.partName("C-085 SearchResultRow", ordinal: index + 1))
                    }
                }
            }
            if !state.verseResultTitles.isEmpty {
                SectionHeader(title: Self.versesTitle, style: .section, accessory: .none)
                    .ui2Element(Self.partName("C-020 SectionHeader", ordinal: hasBooks ? 2 : 1))
                VStack(spacing: 0) {
                    ForEach(Array(state.verseResultTitles.enumerated()), id: \.offset) { index, title in
                        SearchResultRow(
                            kind: .verse,
                            title: title,
                            description: value(state.verseResultDescriptions, index),
                            trailing: .none,
                            onTap: { onVerseResult(index) }
                        )
                        .ui2Element(Self.partName(
                            "C-085 SearchResultRow", ordinal: state.bookResultNames.count + index + 1
                        ))
                    }
                }
            }
        }
        .padding(Token.Space.pageMargin)
    }

    /// `search-empty` and the no-recents prompt: C-132, glyph `search`, centred, padded by
    /// `space-section-gap` (OQ-bible-books-003).
    private func emptyBody(title: String) -> some View {
        EmptyState(glyph: .searchCarbon, title: title, message: Self.emptyMessage)
            .ui2Element("C-132 EmptyState")
            .frame(maxWidth: .infinity)
            .padding(Token.Space.sectionGap)
    }

    // MARK: §2 Overlay

    private var translationMenu: some View {
        FilterMenuOverlay(
            options: zip(state.translationCodes, state.translationNames).map {
                FilterMenuOverlay.Option(id: $0.0, label: $0.1)
            },
            selectionMode: .single,
            selectedIDs: [state.translationCode],
            onSelect: { option in
                onTranslation(option.id)
                translationMenuOpen = false
            },
            onClose: { translationMenuOpen = false }
        )
        .ui2Element("C-036 FilterMenuOverlay")
    }

    // MARK: - Helpers

    private func value<T>(_ values: [T], _ index: Int) -> T? {
        index < values.count ? values[index] : nil
    }

    /// `"C-### <Name>"`, with `" N"` from the second instance on (D11).
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

// MARK: - Sample states (the preview props, written as Swift)

extension BibleBooksScreen.State {
    // The bundled canon (BibleCacheManager.bookData, unique abbreviations D18) and its
    // categories → colour tokens (D5, BibleBookCatalog).
    private static let olive = "bibleOlive"
    private static let teal = "bibleTeal"
    private static let green = "bibleGreen"
    private static let brown = "bibleBrown"
    private static let maroon = "bibleMaroon"

    private static let oldLabels = [
        "Gen", "Exod", "Lev", "Num", "Deut", "Josh", "Judg", "Ruth", "1Sam", "2Sam",
        "1Kgs", "2Kgs", "1Chr", "2Chr", "Ezra", "Neh", "Esth", "Job", "Ps", "Prov",
        "Eccl", "Song", "Isa", "Jer", "Lam", "Ezek", "Dan", "Hos", "Joel", "Amos",
        "Obad", "Jonah", "Mic", "Nah", "Hab", "Zeph", "Hag", "Zech", "Mal"
    ]
    private static let oldFills: [String] =
        Array(repeating: olive, count: 5) + Array(repeating: teal, count: 12)
        + Array(repeating: green, count: 5) + Array(repeating: teal, count: 5)
        + Array(repeating: brown, count: 12)
    private static let newLabels = [
        "Matt", "Mark", "Luke", "John", "Acts", "Rom", "1Cor", "2Cor", "Gal", "Eph",
        "Phil", "Col", "1Thess", "2Thess", "1Tim", "2Tim", "Titus", "Phlm", "Heb", "Jas",
        "1Pet", "2Pet", "1John", "2John", "3John", "Jude", "Rev"
    ]
    private static let newFills: [String] =
        Array(repeating: maroon, count: 5) + Array(repeating: olive, count: 13)
        + Array(repeating: brown, count: 8) + [maroon]

    /// §3 1 browse — the grids at rest; John is used by the fixture lesson (bible-reader.ts, D16).
    static let browse = Self(
        translationCode: "ENGKJV",
        translationLabel: "King James (Authorised) Version",
        translationCodes: ["ENGKJV", "WEBBE", "NIV11"],
        translationNames: [
            "King James (Authorised) Version", "World English Bible British Edition",
            "New International Version 2011"
        ],
        query: "",
        searchFocused: false,
        oldTestamentNumbers: Array(1...39),
        oldTestamentLabels: oldLabels,
        oldTestamentFills: oldFills,
        newTestamentNumbers: Array(40...66),
        newTestamentLabels: newLabels,
        newTestamentFills: newFills,
        usedBooks: [43],
        recents: [],
        bookResultNumbers: [],
        bookResultNames: [],
        bookResultDescriptions: [],
        bookResultFills: [],
        verseResultTitles: [],
        verseResultDescriptions: [],
        searching: false,
        searchEmpty: false
    )
    /// §3 2 search-recents — focused, empty query: the fixture user's recents (bible-books.ts).
    static let searchRecents: Self = {
        var sample = browse
        sample.searchFocused = true
        sample.recents = ["john 3:16", "grace", "Psalm 23", "love one another", "Romans 8", "faith"]
        return sample
    }()
    /// §3 3 search-loading — a query running.
    static let searchLoading: Self = {
        var sample = browse
        sample.searchFocused = true
        sample.query = "john"
        sample.searching = true
        return sample
    }()
    /// §3 4 search-results — Books then Verses: a reference with its snippet and a named passage
    /// with its 2-line summary (semantic-search.test.ts's pericope).
    static let searchResults: Self = {
        var sample = browse
        sample.searchFocused = true
        sample.query = "john"
        sample.bookResultNumbers = [43, 62]
        sample.bookResultNames = ["John", "1 John"]
        sample.bookResultDescriptions = ["21 chapters · New Testament", "5 chapters · New Testament"]
        sample.bookResultFills = [maroon, brown]
        sample.verseResultTitles = ["John 3:16", "The Parable of the Prodigal Son"]
        sample.verseResultDescriptions = [
            "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            "A son squanders his inheritance, returns home, and is welcomed by his father."
        ]
        return sample
    }()
    /// §3 5 search-empty — the query ran and found nothing.
    static let searchEmptyState: Self = {
        var sample = browse
        sample.searchFocused = true
        sample.query = "qwerty"
        sample.searchEmpty = true
        return sample
    }()
}

#Preview("browse") {
    BibleBooksScreen(state: .browse)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-recents") {
    BibleBooksScreen(state: .searchRecents)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-loading") {
    BibleBooksScreen(state: .searchLoading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-results") {
    BibleBooksScreen(state: .searchResults)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-empty") {
    BibleBooksScreen(state: .searchEmptyState)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
