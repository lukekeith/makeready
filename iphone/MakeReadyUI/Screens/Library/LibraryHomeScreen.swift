//
//  LibraryHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen library-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/notes (wire contract owned by the
//  builder `notes` feature spec).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Library — the Home tab's Library section root (§6, D51/D64): the leader's All-Notes list,
/// newest first, in date sections (§1, re-scoped 2026-11-20). No TopNav, no TabBar: the shell's
/// `HomeSectionLayout` owns both (§1 deviation 1). The content model is an ordered list of
/// sections so memo and video sections can be appended later without restructuring (§2).
///
/// Presentational (D6): the caller passes already-bucketed sections and already-formatted date
/// labels (§5: "Date-section grouping, row date formatting … computed on the client from
/// `updatedAt`" — by the app container, not this preview, so a capture does not depend on the
/// day it runs). The live search filter (§3 `search-active`) is a UI-only rule and is real local
/// state here.
///
/// §3 `loading` names skeleton bars that no §4 component draws, so `loading` renders the bottom
/// bar (search disabled) over an empty content area and the skeleton is reported as a spec gap —
/// not improvised (the members-home / enrollments-home precedent).
struct LibraryHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays — one
    /// entry per date section, and one per note row with `rowSections` naming its section —
    /// because the preview's props are JSON and the §4 views take flat parameters (R-05).
    struct State {
        /// §3 states that are not derived from the search text.
        enum Phase: String {
            /// §3 `populated` (default) — also `search-active` / `search-no-results`, which are
            /// this phase with search text (§3).
            case populated
            /// §3 `loading` — first fetch in flight, nothing cached.
            case loading
            /// §3 `empty` — the fetch succeeded with zero notes.
            case empty
            /// §3 `coming-soon` — the former placeholder, preview/capture only.
            case comingSoon = "coming-soon"
        }

        var phase: Phase
        /// C-008 `searchText` — the initial query; "" → the placeholder shows.
        var searchText: String = ""
        /// C-008 `searchFocused` — §3 `search-active`: "the capsule is focused or has text".
        var searchFocused: Bool = false
        /// C-010 `title` per section, newest first (§2 item 3: Today … years).
        var sectionTitles: [String] = []
        /// Per row: the index into `sectionTitles` it sits under.
        var rowSections: [Int] = []
        /// C-005 `title` per row.
        var rowTitles: [String] = []
        /// C-005 `dateLabel` per row (§2: time today, weekday this week, short date older).
        var rowDates: [String] = []
        /// C-005 `preview` per row; "" = nil (no preview line).
        var rowPreviews: [String] = []
        /// C-005 `contextLabel` per row; "" = nil (no context line, §2 "its row is shorter").
        var rowContexts: [String] = []

        /// §3 `coming-soon`. Kept because the app's `LibraryHomeContainer` (UI2/Containers) still
        /// renders it; the notes feature rewires that container to `populated` (§7).
        static let comingSoon = State(phase: .comingSoon)
    }

    let state: State
    /// C-008 is driven editable in the app; capture passes `false` so `searchFocused` draws the
    /// focus look (C-008 §4).
    var searchEditable: Bool = true
    /// §3 "Tap a row: opens that note in the editor" — the row's index in `state.rowTitles`.
    var onOpenNote: (Int) -> Void = { _ in }
    /// §3 "Tap the compose circle: opens a new note in the editor".
    var onCompose: () -> Void = {}
    /// The search text after every change, and "" when the capsule is cleared — for a caller that
    /// searches elsewhere (R-01 change callback; the local query below still updates).
    var onSearchChange: (String) -> Void = { _ in }
    /// `false` when the caller owns the filtering: every row it passed is shown, with no needle
    /// filter (search-no-results still shows when its rows are empty and the query is non-empty).
    var filtersLocally: Bool = true

    // §3 search-active: "The list filters live by title and body text" — UI-only, seeded from
    // `state` (R-31: search text is ephemeral screen state).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var searchFocused: Bool

    init(
        state: State,
        searchEditable: Bool = true,
        onOpenNote: @escaping (Int) -> Void = { _ in },
        onCompose: @escaping () -> Void = {},
        onSearchChange: @escaping (String) -> Void = { _ in },
        filtersLocally: Bool = true
    ) {
        self.state = state
        self.searchEditable = searchEditable
        self.onOpenNote = onOpenNote
        self.onCompose = onCompose
        self.onSearchChange = onSearchChange
        self.filtersLocally = filtersLocally
        _query = SwiftUI.State(initialValue: state.searchText)
        _searchFocused = SwiftUI.State(initialValue: state.searchFocused)
    }

    var body: some View {
        // D22: no ScrollView at the page root — the content is laid out at full length.
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // §2 item 2: "Content scrolls under the floating bottom bar, with bottom inset so the
            // last row clears it."
            .padding(.bottom, Self.barClearance)
            .overlay(alignment: .bottom) { bottomBar }
            .background(Token.layoutBackground)              // §2: "Background `color-layout-background`"
    }

    // MARK: - §2 content area

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .populated:
            if visibleSections.isEmpty {
                // §3 search-no-results: "search glyph, title `No results`, message
                // `No notes match “<text>”.`"
                centredEmptyState(
                    glyph: .searchCarbon,
                    title: "No results",
                    message: "No notes match \u{201C}\(query)\u{201D}."
                )
            } else {
                notesSection
            }
        case .loading:
            // GAP — library-home §3 loading: skeleton rows and a placeholder header name no §4
            // component; the content area is left empty (see the type's doc comment).
            Color.clear.frame(maxWidth: .infinity)
        case .empty:
            // §3 empty: "note glyph, title "No notes yet", message inviting the first note".
            centredEmptyState(
                glyph: .fileText,
                title: "No notes yet",
                message: "Tap the compose button to write your first note."
            )
        case .comingSoon:
            // §3 coming-soon: the former placeholder (C-132, "Library coming soon").
            centredEmptyState(
                glyph: .bookOpen,
                title: "Library coming soon",
                message: "The library will be a place to explore community generated content and share your content with the community."
            )
        }
    }

    /// §2 item 5: "a centred C-132 EmptyState … between the TopNav and the bottom bar".
    private func centredEmptyState(glyph: GlyphName, title: String, message: String) -> some View {
        EmptyState(glyph: glyph, title: title, message: message)
            .ui2Element("C-132 EmptyState")
            .padding(.horizontal, Token.Space.pageMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - §2 item 3 — the Notes section

    /// One date section after the live filter (§3: "sections and their order are preserved and
    /// empty sections are dropped").
    private struct VisibleSection: Identifiable {
        let id: Int
        let title: String
        let rows: [Int]
    }

    private var visibleSections: [VisibleSection] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return state.sectionTitles.indices.compactMap { section in
            let rows = state.rowTitles.indices.filter { row in
                guard state.rowSections.indices.contains(row), state.rowSections[row] == section else {
                    return false
                }
                guard filtersLocally, !needle.isEmpty else { return true }
                // §3: "filters live by title and body text" — the preview line is the body text
                // this screen holds (§5).
                return state.rowTitles[row].localizedCaseInsensitiveContains(needle)
                    || (preview(row) ?? "").localizedCaseInsensitiveContains(needle)
            }
            return rows.isEmpty ? nil : VisibleSection(id: section, title: state.sectionTitles[section], rows: rows)
        }
    }

    private var notesSection: some View {
        // §2: "a gap between section cards" — analysis §2.2 "~26 pt gap", nearest spacing token.
        VStack(alignment: .leading, spacing: Token.Space.rowGap) {
            ForEach(Array(visibleSections.enumerated()), id: \.element.id) { position, section in
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    NoteSectionHeader(title: section.title)
                        .ui2Element(Self.annotation("C-010 NoteSectionHeader", position))
                    sectionCard(section)
                }
            }
        }
        // §2: header "flush left at the page margin" (analysis §2.2 "~14 pt", `space-page-margin`).
        .padding(.horizontal, Token.Space.pageMargin)
        .padding(.top, Token.Space.stackGap)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §2: "rows grouped in one inset card (analysis §2.2: row surface one step lighter than the
    /// page, rounded corners, hairline separators inset to the title edge)".
    private func sectionCard(_ section: VisibleSection) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(section.rows.enumerated()), id: \.element) { position, row in
                if position > 0 {
                    separator
                }
                NoteListRow(
                    title: state.rowTitles[row],
                    preview: preview(row),
                    dateLabel: state.rowDates.indices.contains(row) ? state.rowDates[row] : "",
                    contextLabel: context(row),
                    onTap: { onOpenNote(row) }
                )
                .ui2Element(Self.annotation("C-005 NoteListRow", rowOrdinal(row)))
            }
        }
        .background(Token.cardBackground)
        // analysis §2.2 "~18 pt corner radius" — nearest radius token.
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.step16, style: .continuous))
    }

    /// §2: "hairline separators inset to the title edge" — C-005's title sits at
    /// `space-card-padding`.
    private var separator: some View {
        Rectangle()
            .fill(Token.cardBorder)
            // FLAGGED LITERAL — C-008 §2 precedent: "a 1 pt `color-card-border` stroke", the
            // program-wide hairline; no stroke token.
            .frame(height: 1)
            .padding(.leading, Token.Space.cardPadding)
            .accessibilityHidden(true)
    }

    // MARK: - §2 item 4 — the floating bottom bar

    private var bottomBar: some View {
        NotesBottomBar(
            searchText: query,
            searchFocused: searchFocused,
            // §3 loading / empty: "the search capsule is disabled".
            searchEnabled: state.phase == .populated,
            // §3 empty: "The compose circle in C-008 is emphasised (accent fill)".
            composeEmphasis: state.phase == .empty ? .prominent : .regular,
            onSearchChange: { query = $0; onSearchChange($0) },
            onSearchFocusChange: { searchFocused = $0 },
            onSearchClear: { query = ""; onSearchChange("") },
            onCompose: onCompose,
            editable: searchEditable
        )
        .ui2Element("C-008 NotesBottomBar")
        // C-008 §2 "Not this bar's": the side margins and "the ~14 pt offset above the bottom
        // safe area" — `space-page-margin` on both.
        .padding(.horizontal, Token.Space.pageMargin)
        .padding(.top, Token.Space.sectionGap)
        .padding(.bottom, Token.Space.pageMargin)
        // §2 item 4: "a scrim gradient behind it so rows dim beneath it (analysis §2.3)".
        .background(
            LinearGradient(colors: [Color.clear, Token.layoutBackground], startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)
        )
    }

    /// The list's bottom inset: the bar's 44 pt plus its bottom offset and a section gap of air.
    // GAP — C-008 §2: "Intrinsic height 44, C-034's height"; no size token.
    private static let barClearance: CGFloat = 44 + Token.Space.pageMargin + Token.Space.sectionGap

    // MARK: - Helpers

    private func preview(_ row: Int) -> String? {
        guard state.rowPreviews.indices.contains(row), !state.rowPreviews[row].isEmpty else { return nil }
        return state.rowPreviews[row]
    }

    private func context(_ row: Int) -> String? {
        guard state.rowContexts.indices.contains(row), !state.rowContexts[row].isEmpty else { return nil }
        return state.rowContexts[row]
    }

    /// The row's position among the visible rows, for the D11 annotation suffix.
    private func rowOrdinal(_ row: Int) -> Int {
        visibleSections.flatMap(\.rows).firstIndex(of: row) ?? 0
    }

    /// D11: "a component placed twice gets " 2" on the second".
    private static func annotation(_ name: String, _ position: Int) -> String {
        position == 0 ? name : "\(name) \(position + 1)"
    }
}

// MARK: - Sample data (§3 populated — strings from C-005's contract samples and analysis §3.7)

private extension LibraryHomeScreen.State {
    static func notes(phase: Phase = .populated, searchText: String = "", searchFocused: Bool = false) -> Self {
        .init(
            phase: phase,
            searchText: searchText,
            searchFocused: searchFocused,
            sectionTitles: ["Today", "Previous 7 Days", "Previous 30 Days"],
            rowSections: [0, 0, 1, 1, 2, 2],
            rowTitles: [
                "Sermon prep: Romans 8",
                "Note",
                "Small group questions",
                "Grocery list",
                "Follow up with Marcus",
                "Thoughts on the lesson about patience, waiting well, and what Abraham teaches us about trusting the timing",
            ],
            rowDates: ["2:16 PM", "1:53 AM", "Wednesday", "Monday", "8/6/26", "8/3/26"],
            rowPreviews: [
                "Start with verse 28 and work backwards to the context",
                "Here are my thoughts on the lesson",
                "What does rest look like this week?",
                "",
                "",
                "There is a long preview line here that should never wrap onto a second line in the list",
            ],
            rowContexts: [
                "Sunday sermon recap",
                "",
                "",
                "",
                "Voice memo 14",
                "Leadership retreat session three — full recording with discussion",
            ]
        )
    }
}

#Preview("Coming soon") {
    LibraryHomeScreen(state: .init(phase: .comingSoon))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated") {
    LibraryHomeScreen(state: .notes())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    LibraryHomeScreen(state: .init(phase: .loading))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    LibraryHomeScreen(state: .init(phase: .empty))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-active") {
    LibraryHomeScreen(state: .notes(searchText: "lesson", searchFocused: true), searchEditable: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-no-results") {
    LibraryHomeScreen(state: .notes(searchText: "bold", searchFocused: true), searchEditable: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
