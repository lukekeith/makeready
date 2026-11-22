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
/// voice memos (C-006) in one list, interleaved newest first, in date sections (§2 item 4), under
/// the pinned C-131 search and `Type` filter header (§2 item 2). No TopNav, no TabBar: the shell's
/// `HomeSectionLayout` owns both (§1 deviation 1). The content model is an ordered list of
/// sections so memo and video sections can be appended later without restructuring (§2).
///
/// Presentational (D6): the caller passes already-bucketed sections and already-formatted date
/// labels (§5: "Date-section grouping, row date formatting … computed on the client from
/// `updatedAt`" — by the app container, not this preview, so a capture does not depend on the
/// day it runs). The live search filter (§3 `search-active`) is a UI-only rule and is real local
/// state here.
///
/// §3 `loading` names skeleton bars that no §4 component draws, so `loading` renders the header
/// over an empty content area and the skeleton is reported as a spec gap — not improvised (the
/// members-home / enrollments-home precedent).
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
        /// C-131 `query` — the initial query; "" → the placeholder shows.
        var searchText: String = ""
        /// C-131 `initiallyFocused` — §3 `search-active`: "the field is focused or has text".
        var searchFocused: Bool = false
        /// §3 input `selectedTypes`: "the seed for C-036's checked rows … It lives in the screen's
        /// `State` and replaces `typeFilter`. `filter-memos` seeds `[.memo]`."
        var selectedTypes: Set<LibraryItemType> = []
        /// §3 `type-menu-open`: "the `Type` chip's C-036 multi-select menu is open" — the preview's
        /// seed for the presented menu (R-31: ephemeral screen state, seeded here).
        var typeMenuOpen: Bool = false
        /// C-020 `title` per section, newest first (§2 item 4: Today … years).
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
        /// §3 input `memos` — the voice memos, interleaved with the note rows by date (§2 item 4).
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
    /// §3 "Tap a note row: opens that note in the editor" — the row's index in `state.rowTitles`.
    var onOpenNote: (Int) -> Void = { _ in }
    /// §3 "Tap a memo row: pushes `memo-detail` for that memo" — the memo's `id`.
    var onOpenMemo: (String) -> Void = { _ in }
    /// The search text after every change, and "" when the field is cleared — for a caller that
    /// searches elsewhere (R-01 change callback; the local query below still updates).
    var onSearchChange: (String) -> Void = { _ in }
    /// `false` when the caller owns the filtering: every row it passed is shown, with no text or
    /// type filter (search-no-results still shows when its rows are empty and the query is
    /// non-empty or one type is checked).
    var filtersLocally: Bool = true
    /// The list's scroll offset (0 at the top, negative on a pull) and whether a finger is on it —
    /// the shell's TopNav morph reads it, since this screen owns its scroll (Library `ownsScroll`).
    var onScrollChange: (CGFloat, Bool) -> Void = { _, _ in }
    /// §3 "Tap `Save` in the `Type` menu: the screen applies the checked set and reports it through
    /// `onSaveTypes`" — an empty set or both types means everything.
    var onSaveTypes: (Set<LibraryItemType>) -> Void = { _ in }
    /// §3 "Pull to refresh: the shared `PullToRefresh` calls `onRefresh`" — media-home's shape
    /// (`() -> Void`, its page's own loading state shows the wait).
    var onRefresh: () -> Void = {}

    // §3 search-active: "The list filters live across both kinds" — UI-only, seeded from `state`
    // (R-31: search text and the presented menu are ephemeral screen state).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var selectedTypes: Set<LibraryItemType>
    @SwiftUI.State private var typeMenuOpen: Bool

    init(
        state: State,
        onOpenNote: @escaping (Int) -> Void = { _ in },
        onOpenMemo: @escaping (String) -> Void = { _ in },
        onSearchChange: @escaping (String) -> Void = { _ in },
        filtersLocally: Bool = true,
        onScrollChange: @escaping (CGFloat, Bool) -> Void = { _, _ in },
        onSaveTypes: @escaping (Set<LibraryItemType>) -> Void = { _ in },
        onRefresh: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onOpenNote = onOpenNote
        self.onOpenMemo = onOpenMemo
        self.onSearchChange = onSearchChange
        self.filtersLocally = filtersLocally
        self.onScrollChange = onScrollChange
        self.onSaveTypes = onSaveTypes
        self.onRefresh = onRefresh
        _query = SwiftUI.State(initialValue: state.searchText)
        _selectedTypes = SwiftUI.State(initialValue: state.selectedTypes)
        _typeMenuOpen = SwiftUI.State(initialValue: state.typeMenuOpen)
    }

    @SwiftUI.State private var fingerDown = false

    // MARK: - §2 / §3 constants

    /// §2 item 2: "C-034 SearchField (placeholder `Search library`)".
    private static let searchPlaceholder = "Search library"

    var body: some View {
        // §2 items 2–3: the C-131 header is pinned under the TopNav (the shell starts an
        // `ownsScroll` section below its row) and stays put while the screen's own ScrollView
        // scrolls beneath it.
        VStack(spacing: 0) {
            header
            GeometryReader { viewport in
                ScrollView(.vertical) {
                    content
                        // A short state (empty, no results) still centres in the visible area.
                        .frame(maxWidth: .infinity, minHeight: viewport.size.height,
                               alignment: showsList ? .top : .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    onScrollChange(offset, fingerDown)
                }
                .onScrollPhaseChange { _, phase in fingerDown = phase == .interacting }
                // §2 item 3: "the shared `PullToRefresh` wraps it, wired the way `media-home`
                // wires it".
                .pullToRefresh(onRefresh)
            }
        }
        .background(Token.layoutBackground)              // §2: "Background `color-layout-background`"
        // §3 The `Type` chip: "Tapping it opens C-036 FilterMenuOverlay" (§6: the one overlay).
        .filterMenuPresentation(isPresented: typeMenuOpen, onDismiss: { typeMenuOpen = false }) {
            typeMenu
        }
    }

    // MARK: - §2 item 2 — the pinned C-131 header

    /// §2 item 2: "C-034 SearchField (placeholder `Search library`) over the C-130 rail of C-035
    /// chips … There is one chip, `Type`." `.underShellTopNav`: the shell's TopNav sits above.
    private var header: some View {
        SearchFilterHeader(
            query: query,
            onQueryChange: { newValue in
                query = newValue
                onSearchChange(newValue)
            },
            placeholder: Self.searchPlaceholder,
            placement: .underShellTopNav,
            initiallyFocused: state.searchFocused
        ) {
            // §3: "one C-035 chip … tapping it opens C-036"; "The chip is active while anything is
            // checked. Its label follows `members-home`'s rule" (filter-multiselect D4).
            FilterChip(type: .menu, active: !selectedTypes.isEmpty, label: typeChipLabel, onTap: { typeMenuOpen = true })
                .ui2Element("C-035 FilterChip")
        }
        // GAP — library-home §3 loading / empty: "its search field is disabled" — C-131 takes no
        // `enabled` input (C-034 has one), so the header is made inert without the dimmed look.
        .disabled(!searchEnabled)
        .ui2Element("C-131 SearchFilterHeader")
    }

    /// §3 loading / empty: "The header's search field is disabled".
    private var searchEnabled: Bool { state.phase == .populated }

    /// §3 The `Type` chip: "C-036 FilterMenuOverlay in its multi-select form, with `Notes` and
    /// `Voice memos` as checkable rows and **Save**. The menu has no "All types" row (D3)." As
    /// members-home: picks are a draft, Save applies and closes, ✕ closes with no change.
    private var typeMenu: some View {
        FilterMenuOverlay(
            options: LibraryItemType.menuOptions.map { FilterMenuOverlay.Option(id: $0.rawValue, label: $0.label) },
            selectionMode: .multiple,
            selectedIDs: Set(selectedTypes.map(\.rawValue)),
            onClose: { typeMenuOpen = false },
            onSave: { picked in
                selectedTypes = Set(picked.compactMap(LibraryItemType.init(rawValue:)))
                onSaveTypes(selectedTypes)
                typeMenuOpen = false
            }
        )
        .ui2Element("C-036 FilterMenuOverlay")
    }

    /// §3: "`All types` with nothing checked, otherwise the house wording for the checked set"
    /// (members-home's rule — C-036's `chipLabel`), in menu order.
    private var typeChipLabel: String {
        FilterMenuOverlay.chipLabel(
            picked: LibraryItemType.menuOptions.filter(selectedTypes.contains).map(\.label),
            resting: "All types",
            noun: "types"
        )
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
                // `Nothing in your Library matches “<text>”.`, or `Nothing in your Library matches
                // this filter.` when the text is empty".
                centredEmptyState(
                    glyph: .searchCarbon,
                    title: "No results",
                    message: query.trimmingCharacters(in: .whitespaces).isEmpty
                        ? "Nothing in your Library matches this filter."
                        : "Nothing in your Library matches \u{201C}\(query)\u{201D}."
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
            // notes or memos yet. Tap + and choose Write a note or Voice memo.""
            centredEmptyState(
                glyph: .fileText,
                title: "Nothing in your Library yet",
                message: "You have no notes or memos yet. Tap + and choose Write a note or Voice memo."
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

    /// §2 item 5: "a centred C-132 EmptyState, or a loading placeholder, under the header".
    private func centredEmptyState(glyph: GlyphName, title: String, message: String) -> some View {
        EmptyState(glyph: glyph, title: title, message: message)
            .ui2Element("C-132 EmptyState")
            .padding(.horizontal, Token.Space.pageMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - §2 item 4 — the Library list (notes and memos, one list)

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
        // §3: "The filter combines with search … Nothing checked, or both checked, shows every row";
        // caller-owned filtering applies neither.
        let showsNotes = !filtersLocally || LibraryItemType.shows(.note, in: selectedTypes)
        let showsMemos = !filtersLocally || LibraryItemType.shows(.memo, in: selectedTypes)
        return state.sectionTitles.indices.compactMap { section in
            let notes = state.rowTitles.indices.filter { row in
                guard showsNotes, state.rowSections.indices.contains(row), state.rowSections[row] == section else {
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
                guard showsMemos, memo.section == section else { return false }
                guard filtering else { return true }
                // §3: "a memo by title and transcript text".
                return memo.title.localizedCaseInsensitiveContains(needle)
                    || (Self.transcript(memo) ?? "").localizedCaseInsensitiveContains(needle)
            }
            let rows = merged(notes: notes, memos: memos)
            return rows.isEmpty ? nil : VisibleSection(id: section, title: state.sectionTitles[section], rows: rows)
        }
    }

    /// §2 item 4: "Within a section, rows of both kinds are ordered by that date descending" —
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

    /// §2 item 4: date sections, each a C-020 SectionHeader over flat house rows.
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            ForEach(Array(visibleSections.enumerated()), id: \.element.id) { position, section in
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // §2: "Section headers are C-020 SectionHeader … carrying the date label with
                    // no trailing accessory."
                    SectionHeader(title: section.title, style: .section, accessory: .none)
                        .ui2Element(Self.annotation("C-020 SectionHeader", position))
                    sectionRows(section)
                }
            }
        }
        // §2: rows and headers at the page margin, as on members-home.
        .padding(.horizontal, Token.Space.pageMargin)
        // §2 item 3: "The list ends with the page's normal bottom inset for the TabBar."
        .padding(.bottom, Token.Space.sectionGap)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §2: "Rows are flat house list rows, not inset cards … the C-088 hairline rule between rows."
    private func sectionRows(_ section: VisibleSection) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(section.rows.enumerated()), id: \.element) { position, item in
                if position > 0 {
                    // §2: "The hairline rule starts where the text column starts" — past the 32 pt
                    // avatar and the row's 16 band gap.
                    SectionDivider()
                        .padding(.leading, NoteListRow.avatarSize + Token.Space.cardPadding)
                        .ui2Element(Self.annotation("C-088 SectionDivider", dividerOrdinal(item)))
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
                    // §2: "A memo row is a C-006 MemoListRow in the same house row look".
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
    }

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

    /// The divider above `item`'s position among every divider drawn (one per row that is not
    /// first in its section), for the D11 annotation suffix.
    private func dividerOrdinal(_ item: Item) -> Int {
        let above = visibleSections.flatMap { $0.rows.dropFirst() }
        return above.firstIndex(of: item) ?? 0
    }

    /// D11: "a component placed twice gets " 2" on the second".
    private static func annotation(_ name: String, _ position: Int) -> String {
        position == 0 ? name : "\(name) \(position + 1)"
    }
}

// MARK: - §3 The `Type` filter

/// §3 inputs: "`LibraryItemType` is `note` or `memo`" — one checkable row of the `Type` menu.
enum LibraryItemType: String {
    case note
    case memo

    /// §3 The `Type` menu's checkable rows, in order: "`Notes` and `Voice memos`".
    static let menuOptions: [Self] = [.note, .memo]

    /// The row's label in C-036 and on the chip.
    var label: String {
        switch self {
        case .note: return "Notes"
        case .memo: return "Voice memos"
        }
    }

    /// §3: "Nothing checked, or both checked, shows every row" — whether `type`'s rows show.
    static func shows(_ type: Self, in selected: Set<Self>) -> Bool {
        selected.isEmpty || selected.contains(type)
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
    /// §3 `search-mixed` is this list with search text matching one note and one memo, and
    /// `filter-memos` is it with `Voice memos` checked in the `Type` menu.
    static func mixed(searchText: String = "", searchFocused: Bool = false, selectedTypes: Set<LibraryItemType> = [],
                      typeMenuOpen: Bool = false) -> Self {
        .init(
            phase: .populated,
            searchText: searchText,
            searchFocused: searchFocused,
            selectedTypes: selectedTypes,
            typeMenuOpen: typeMenuOpen,
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
    LibraryHomeScreen(state: .notes(searchText: "lesson", searchFocused: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-no-results") {
    LibraryHomeScreen(state: .notes(searchText: "bold", searchFocused: true))
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
    LibraryHomeScreen(state: .mixed(searchText: "rest", searchFocused: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("filter-memos") {
    LibraryHomeScreen(state: .mixed(selectedTypes: [.memo]))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("type-menu-open") {
    LibraryHomeScreen(state: .mixed(typeMenuOpen: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
