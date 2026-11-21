//
//  LibraryHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen library-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/notes and the memo feature's memo
//  list (wire contracts owned by the builder `notes` and `memo` feature specs).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Library — the Home tab's Library section root (§6, D51/D64): the leader's notes (C-005) and
/// voice memos (C-006) in one list, interleaved newest first, in date sections (§2 item 3). No TopNav, no TabBar: the shell's
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
            /// §3 `empty` — the fetch succeeded with zero notes and zero memos.
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
        /// Per note row: its `updatedAt`, the key §2 interleaves memos against ("rows of both kinds
        /// are ordered by that date descending"). A note with none keeps its passed order, ahead
        /// of the section's memos.
        var rowUpdatedAt: [Date] = []
        /// §3 input `memos` — the voice memos, interleaved with the note rows by date (§2 item 3).
        var memos: [MemoRowInput] = []

        /// §3 `MemoRowInput` — one voice memo: "`id`, `title`, `duration`, `recordedAt`, the
        /// transcript state and its preview". Duration and date arrive formatted (D6), with the
        /// date section already chosen, as the note rows do.
        struct MemoRowInput: Identifiable {
            var id: String
            /// C-006 `title`.
            var title: String
            /// C-006 `durationLabel`.
            var durationLabel: String
            /// C-006 `dateLabel` (the notes rule, §2).
            var dateLabel: String
            /// The index into `sectionTitles` it sits under.
            var section: Int
            /// §2: "`recordedAt` for a memo" — the interleave key.
            var recordedAt: Date
            /// C-006 `preview` — the transcript state and its preview.
            var preview: MemoListRow.Preview
        }

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
    /// §3 "Tap a memo row: pushes `memo-detail` for that memo" — the memo's `id`.
    var onOpenMemo: (String) -> Void = { _ in }
    /// §3 "Tap the compose circle: opens a new note in the editor".
    var onCompose: () -> Void = {}
    /// The search text after every change, and "" when the capsule is cleared — for a caller that
    /// searches elsewhere (R-01 change callback; the local query below still updates).
    var onSearchChange: (String) -> Void = { _ in }
    /// `false` when the caller owns the filtering: every row it passed is shown, with no needle
    /// filter (search-no-results still shows when its rows are empty and the query is non-empty).
    var filtersLocally: Bool = true
    /// The list's scroll offset (0 at the top, negative on a pull) and whether a finger is on it —
    /// the shell's TopNav morph reads it, since this screen owns its scroll (Library `ownsScroll`).
    var onScrollChange: (CGFloat, Bool) -> Void = { _, _ in }

    // §3 search-active: "The list filters live by title and body text" — UI-only, seeded from
    // `state` (R-31: search text is ephemeral screen state).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var searchFocused: Bool

    init(
        state: State,
        searchEditable: Bool = true,
        onOpenNote: @escaping (Int) -> Void = { _ in },
        onOpenMemo: @escaping (String) -> Void = { _ in },
        onCompose: @escaping () -> Void = {},
        onSearchChange: @escaping (String) -> Void = { _ in },
        filtersLocally: Bool = true,
        onScrollChange: @escaping (CGFloat, Bool) -> Void = { _, _ in }
    ) {
        self.state = state
        self.searchEditable = searchEditable
        self.onOpenNote = onOpenNote
        self.onOpenMemo = onOpenMemo
        self.onCompose = onCompose
        self.onSearchChange = onSearchChange
        self.filtersLocally = filtersLocally
        self.onScrollChange = onScrollChange
        _query = SwiftUI.State(initialValue: state.searchText)
        _searchFocused = SwiftUI.State(initialValue: state.searchFocused)
    }

    @SwiftUI.State private var fingerDown = false

    var body: some View {
        // notes agent walk round 1: the screen owns its scroll (the shell's Library `ownsScroll`),
        // so C-008 floats over the scroll view, not at the end of its content (§2 item 4: "pinned
        // above the bottom safe area (and above the shell TabBar)").
        GeometryReader { viewport in
            ScrollView(.vertical) {
                content
                    // A short state (empty, no results) still centres in the visible area.
                    .frame(maxWidth: .infinity, minHeight: max(0, viewport.size.height - Self.barClearance),
                           alignment: showsList ? .top : .center)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
            // §2 item 2: "Content scrolls under the floating bottom bar, with bottom inset so the
            // last row clears it."
            .contentMargins(.bottom, Self.barClearance, for: .scrollContent)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                onScrollChange(offset, fingerDown)
            }
            .onScrollPhaseChange { _, phase in fingerDown = phase == .interacting }
        }
        .overlay(alignment: .bottom) { bottomBar }
        .background(Token.layoutBackground)              // §2: "Background `color-layout-background`"
    }

    // MARK: - §2 content area

    /// The notes-and-memos list is drawn (top-aligned); every other state is a centred C-132 or blank.
    private var showsList: Bool { state.phase == .populated && !visibleSections.isEmpty }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .populated:
            if visibleSections.isEmpty {
                // §3 search-no-results: "search glyph, title `No results`, message
                // `Nothing in your Library matches “<text>”.`"
                centredEmptyState(
                    glyph: .searchCarbon,
                    title: "No results",
                    message: "Nothing in your Library matches \u{201C}\(query)\u{201D}."
                )
            } else {
                notesSection
            }
        case .loading:
            // GAP — library-home §3 loading: skeleton rows and a placeholder header name no §4
            // component; the content area is left empty (see the type's doc comment).
            Color.clear.frame(maxWidth: .infinity)
        case .empty:
            // §3 empty: "note glyph, title "Nothing in your Library yet", message "You have no
            // notes or memos yet. Tap the compose button to write your first note.""
            centredEmptyState(
                glyph: .fileText,
                title: "Nothing in your Library yet",
                message: "You have no notes or memos yet. Tap the compose button to write your first note."
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

    // MARK: - §2 item 3 — the Library list (notes and memos, one list)

    /// One row of the merged list: a note (its index in `state.rowTitles`) or a memo (its index in
    /// `state.memos`).
    private enum Item: Hashable {
        case note(Int)
        case memo(Int)
    }

    /// One date section after the live filter (§3: "sections and their order are preserved and
    /// empty sections are dropped").
    private struct VisibleSection: Identifiable {
        let id: Int
        let title: String
        let rows: [Item]
    }

    private var visibleSections: [VisibleSection] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let filtering = filtersLocally && !needle.isEmpty
        return state.sectionTitles.indices.compactMap { section in
            let notes = state.rowTitles.indices.filter { row in
                guard state.rowSections.indices.contains(row), state.rowSections[row] == section else {
                    return false
                }
                guard filtering else { return true }
                // §3: "a note by title and body text" — the preview line is the body text this
                // screen holds (§5).
                return state.rowTitles[row].localizedCaseInsensitiveContains(needle)
                    || (preview(row) ?? "").localizedCaseInsensitiveContains(needle)
            }
            let memos = state.memos.indices.filter { index in
                let memo = state.memos[index]
                guard memo.section == section else { return false }
                guard filtering else { return true }
                // §3: "a memo by title and transcript text".
                return memo.title.localizedCaseInsensitiveContains(needle)
                    || (Self.transcript(memo) ?? "").localizedCaseInsensitiveContains(needle)
            }
            let rows = merged(notes: notes, memos: memos)
            return rows.isEmpty ? nil : VisibleSection(id: section, title: state.sectionTitles[section], rows: rows)
        }
    }

    /// §2 item 3: "Within a section, rows of both kinds are ordered by that date descending" —
    /// `updatedAt` for a note, `recordedAt` for a memo. A stable merge: the notes keep their passed
    /// order, and a note with no `rowUpdatedAt` stays ahead of every memo.
    private func merged(notes: [Int], memos: [Int]) -> [Item] {
        var result: [Item] = []
        var noteCursor = notes.startIndex
        var memoCursor = memos.startIndex
        let sortedMemos = memos.sorted { state.memos[$0].recordedAt > state.memos[$1].recordedAt }
        while noteCursor < notes.endIndex || memoCursor < sortedMemos.endIndex {
            guard memoCursor < sortedMemos.endIndex else {
                result.append(.note(notes[noteCursor])); noteCursor += 1; continue
            }
            guard noteCursor < notes.endIndex else {
                result.append(.memo(sortedMemos[memoCursor])); memoCursor += 1; continue
            }
            let noteDate = state.rowUpdatedAt.indices.contains(notes[noteCursor])
                ? state.rowUpdatedAt[notes[noteCursor]] : .distantFuture
            if noteDate >= state.memos[sortedMemos[memoCursor]].recordedAt {
                result.append(.note(notes[noteCursor])); noteCursor += 1
            } else {
                result.append(.memo(sortedMemos[memoCursor])); memoCursor += 1
            }
        }
        return result
    }

    /// The transcript text a memo row holds — `.transcript(String)`'s text, else none.
    private static func transcript(_ memo: State.MemoRowInput) -> String? {
        if case .transcript(let text) = memo.preview { return text }
        return nil
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
            ForEach(Array(section.rows.enumerated()), id: \.element) { position, item in
                if position > 0 {
                    separator
                }
                switch item {
                case .note(let row):
                    NoteListRow(
                        title: state.rowTitles[row],
                        preview: preview(row),
                        dateLabel: state.rowDates.indices.contains(row) ? state.rowDates[row] : "",
                        contextLabel: context(row),
                        onTap: { onOpenNote(row) }
                    )
                    .ui2Element(Self.annotation("C-005 NoteListRow", rowOrdinal(item)))
                case .memo(let index):
                    // §2 item 3: "A memo row is a C-006 MemoListRow with the same height rhythm,
                    // insets and separators as C-005" — the row owns its insets; the card is shared.
                    let memo = state.memos[index]
                    MemoListRow(
                        title: memo.title,
                        durationLabel: memo.durationLabel,
                        dateLabel: memo.dateLabel,
                        preview: memo.preview,
                        onTap: { onOpenMemo(memo.id) }
                    )
                    .ui2Element(Self.annotation("C-006 MemoListRow", rowOrdinal(item)))
                }
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

    /// The row's position among the visible rows of its own kind, for the D11 annotation suffix.
    private func rowOrdinal(_ item: Item) -> Int {
        let rows = visibleSections.flatMap(\.rows)
        let sameKind = rows.filter {
            switch ($0, item) {
            case (.note, .note), (.memo, .memo): return true
            default: return false
            }
        }
        return sameKind.firstIndex(of: item) ?? 0
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

    /// §3 `populated-mixed`: "notes and memos interleaved in the Today and Previous 7 Days
    /// sections, including one memo `transcribing` and one memo `waiting-to-upload`".
    /// §3 `search-mixed` is this list with search text matching one note and one memo.
    static func mixed(searchText: String = "", searchFocused: Bool = false) -> Self {
        .init(
            phase: .populated,
            searchText: searchText,
            searchFocused: searchFocused,
            sectionTitles: ["Today", "Previous 7 Days"],
            rowSections: [0, 1, 1],
            rowTitles: ["Sermon prep: Romans 8", "Small group questions", "Grocery list"],
            rowDates: ["2:16 PM", "Wednesday", "Monday"],
            rowPreviews: ["Start with verse 28 and work backwards to the context", "What does rest look like this week?", ""],
            rowContexts: ["Sunday sermon recap", "", ""],
            rowUpdatedAt: [at("2026-11-21T14:16:00Z"), at("2026-11-18T19:00:00Z"), at("2026-11-16T10:00:00Z")],
            memos: [
                MemoRowInput(
                    id: "memo-3", title: "Memo 3", durationLabel: "4:12", dateLabel: "3:40 PM", section: 0,
                    recordedAt: at("2026-11-21T15:40:00Z"),
                    preview: .transcript("So the main thing I want to say this Sunday is about rest")
                ),
                MemoRowInput(
                    id: "memo-prayer", title: "Prayer list for Thursday", durationLabel: "1:08", dateLabel: "9:05 AM",
                    section: 0, recordedAt: at("2026-11-21T09:05:00Z"), preview: .transcribing
                ),
                MemoRowInput(
                    id: "memo-2", title: "Memo 2", durationLabel: "0:42", dateLabel: "Tuesday", section: 1,
                    recordedAt: at("2026-11-17T08:00:00Z"), preview: .waitingToUpload
                ),
            ]
        )
    }

    private static let isoFormatter = ISO8601DateFormatter()
    private static func at(_ iso: String) -> Date { isoFormatter.date(from: iso) ?? .distantPast }
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

#Preview("populated-mixed") {
    LibraryHomeScreen(state: .mixed())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-mixed") {
    LibraryHomeScreen(state: .mixed(searchText: "rest", searchFocused: true), searchEditable: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
