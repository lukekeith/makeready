//
//  LibraryHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen library-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/notes, the memo feature's memo
//  list and the video-recorder feature's video list (wire contracts owned by the builder `notes`,
//  `memo` and `video-recorder` feature specs).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Library — the Home tab's Library section root (§6, D51/D64): the leader's notes (C-005),
/// voice memos (C-006) and videos in one flat list with no date-section headers, interleaved newest first
/// (§2 item 4), under the pinned C-131 search and `Type` filter header (§2 item 2). No TopNav, no
/// TabBar: the shell's `HomeSectionLayout` owns both (§1 deviation 1). The rows sit in a
/// `LazyVStack` so the list can hold tens of thousands of rows (§2 "Virtualized", §3 Performance
/// contract).
///
/// Presentational (D6): the caller passes already-formatted date labels (§5: "row date formatting
/// … computed on the client from `updatedAt` / `recordedAt`" — by the app container, not this
/// preview, so a capture does not depend on the day it runs). The live search filter (§3 `search-active`) is a UI-only rule and is real local
/// state here.
///
/// §3 `loading` names skeleton bars that no §4 component draws, so `loading` renders the header
/// over an empty content area and the skeleton is reported as a spec gap — not improvised (the
/// members-home / enrollments-home precedent).
struct LibraryHomeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays — one
    /// entry per note row — because the preview's props are JSON and the §4 views take flat parameters (R-05).
    struct State {
        /// §3 states that are not derived from the search text.
        enum Phase: String {
            /// §3 `populated` (default) — also `search-active` / `search-no-results`, which are
            /// this phase with search text (§3).
            case populated
            /// §3 `loading` — first fetch in flight, nothing cached.
            case loading
            /// §3 `empty` — the fetch succeeded with zero notes, zero memos and zero videos.
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
        /// C-005 `title` per row.
        var rowTitles: [String] = []
        /// C-005 `dateLabel` per row (§2: time today, weekday this week, short date older).
        var rowDates: [String] = []
        /// C-005 `preview` per row; "" = nil (no preview line).
        var rowPreviews: [String] = []
        /// C-005 `contextLabel` per row; "" = nil (no context line, §2 "its row is shorter").
        var rowContexts: [String] = []
        /// Per note row: the note's model id — the row's stable identity, so an open or deleted row
        /// stays that note when the rows shift. Empty (previews only) = keyed by row index.
        var noteIDs: [String] = []
        /// Per note row: its `updatedAt`, the key §2 interleaves memos against ("newest first by
        /// each item's own date"). A note with none keeps its passed order, ahead of the memos.
        var rowUpdatedAt: [Date] = []
        /// §3 input `memos` — the voice memos, interleaved with the note rows by date (§2 item 4).
        var memos: [MemoRowInput] = []
        /// §3 input `videos` — "the videos, passed next to the notes and memos", interleaved by
        /// date (§2 item 4).
        var videos: [VideoRowInput] = []
        /// §3 `row-open`: "one row, swiped half way, rests open with its trailing `Delete` circle
        /// showing" — the preview's seed for the open row (R-31: ephemeral screen state, seeded
        /// here): `note:<row index>`, `memo:<memo id>` or `video:<video id>`; nil = every row closed.
        var openRow: String?
        /// §3 `delete-confirm`: "the `row-open` row, with the delete confirmation card presented
        /// over the dimmed page … Seeded like `row-open`" — the card is up for `openRow`'s row.
        var deleteConfirmPresented: Bool = false

        /// §3 `MemoRowInput` — one voice memo: "`id`, `title`, `duration`, `recordedAt`, the
        /// transcript state and its preview". Duration and date arrive formatted (D6), as the note
        /// rows do.
        struct MemoRowInput: Identifiable {
            var id: String
            /// C-006 `title`.
            var title: String
            /// C-006 `durationLabel`.
            var durationLabel: String
            /// C-006 `dateLabel` (the notes rule, §2).
            var dateLabel: String
            /// §2: "`recordedAt` for a memo" — the interleave key.
            var recordedAt: Date
            /// C-006 `preview` — the transcript state and its preview.
            var preview: MemoListRow.Preview
        }

        /// §3 `VideoRowInput` — one video: "Each carries `id`, `title`, `duration`, `recordedAt`
        /// and its state (a transcript first line, `transcribing`, `uploading` or `processing`)."
        /// Duration and date arrive formatted (D6), as the memo rows do.
        struct VideoRowInput: Identifiable {
            /// §2 line 2: "the first line of the video's transcript, or the state text
            /// `Transcribing…`, `Uploading…` or `Processing…`".
            enum Preview {
                case transcript(String)
                case transcribing
                case uploading
                case processing
            }

            var id: String
            var title: String
            /// §2 line 1: "the date label followed by the duration (`9:38 PM · 0:45`, the memo rule)".
            var durationLabel: String
            var dateLabel: String
            /// §2: "`recordedAt` for a memo and for a video" — the interleave key.
            var recordedAt: Date
            var preview: Preview
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
    /// §3 "Tap a video row: pushes **Video detail** for that video, through `onOpenVideo`" — by id.
    var onOpenVideo: (String) -> Void = { _ in }
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
    /// `onSaveTypes`" — "An empty set, or all three kinds, means everything".
    var onSaveTypes: (Set<LibraryItemType>) -> Void = { _ in }
    /// §3 "Pull to refresh: the shared `PullToRefresh` calls `onRefresh`" — media-home's shape
    /// (`() -> Void`, its page's own loading state shows the wait).
    var onRefresh: () -> Void = {}
    /// §3 "Swipe a note row to Delete: the screen calls `onDeleteNote(row)`" — the row's index in
    /// `state.rowTitles`, as `onOpenNote` takes it (the screen's note rows are index-addressed).
    var onDeleteNote: (Int) -> Void = { _ in }
    /// §3 "Swipe a memo row to Delete: the screen calls `onDeleteMemo(id)`" — the memo's `id`.
    var onDeleteMemo: (String) -> Void = { _ in }
    /// §3 `onDeleteVideo` — "a video, by id, was asked to be deleted. The row stays until the call
    /// succeeds" (`removesRow: false`): the screen never removes a video row itself.
    var onDeleteVideo: (String) -> Void = { _ in }

    // §3 search-active: "The list filters live across all three kinds" — UI-only, seeded from `state`
    // (R-31: search text and the presented menu are ephemeral screen state).
    @SwiftUI.State private var query: String
    @SwiftUI.State private var selectedTypes: Set<LibraryItemType>
    @SwiftUI.State private var typeMenuOpen: Bool
    /// §3 Swipe actions: "Only one row is open at a time in the list: the screen holds that state."
    @SwiftUI.State private var openItem: Item?
    /// §3 "The screen removes the row at once (it collapses), and the caller owns the effect" —
    /// rows deleted since the caller last passed its rows; cleared when new rows arrive, so a
    /// caller that restores a row (a failed delete) shows it again.
    @SwiftUI.State private var deletedItems: Set<Item> = []
    /// §3 Delete confirmation: the row whose resting Delete circle was tapped — the C-066 card is
    /// up while it is set (R-31: a presented sheet is ephemeral screen state).
    @SwiftUI.State private var confirmingItem: Item?

    /// True only under the capture harness's element map (memo-detail's `captureDeleteConfirm`).
    @Environment(\.ui2ElementCollecting) private var captureStandIn

    init(
        state: State,
        onOpenNote: @escaping (Int) -> Void = { _ in },
        onOpenMemo: @escaping (String) -> Void = { _ in },
        onSearchChange: @escaping (String) -> Void = { _ in },
        filtersLocally: Bool = true,
        onScrollChange: @escaping (CGFloat, Bool) -> Void = { _, _ in },
        onSaveTypes: @escaping (Set<LibraryItemType>) -> Void = { _ in },
        onRefresh: @escaping () -> Void = {},
        onDeleteNote: @escaping (Int) -> Void = { _ in },
        onDeleteMemo: @escaping (String) -> Void = { _ in },
        onOpenVideo: @escaping (String) -> Void = { _ in },
        onDeleteVideo: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onOpenNote = onOpenNote
        self.onOpenMemo = onOpenMemo
        self.onSearchChange = onSearchChange
        self.filtersLocally = filtersLocally
        self.onScrollChange = onScrollChange
        self.onSaveTypes = onSaveTypes
        self.onRefresh = onRefresh
        self.onDeleteNote = onDeleteNote
        self.onDeleteMemo = onDeleteMemo
        self.onOpenVideo = onOpenVideo
        self.onDeleteVideo = onDeleteVideo
        _openItem = SwiftUI.State(initialValue: Self.seededItem(state.openRow, in: state))
        _confirmingItem = SwiftUI.State(
            initialValue: state.deleteConfirmPresented ? Self.seededItem(state.openRow, in: state) : nil
        )
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
        // §3 Performance contract: "The filtered and merged row list is computed once per render".
        let list = visibleList
        VStack(spacing: 0) {
            header
            GeometryReader { viewport in
                ScrollView(.vertical) {
                    content(list)
                        // A short state (empty, no results) still centres in the visible area.
                        .frame(maxWidth: .infinity, minHeight: viewport.size.height,
                               alignment: showsList(list) ? .top : .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    onScrollChange(offset, fingerDown)
                }
                .onScrollPhaseChange { _, phase in
                    fingerDown = phase == .interacting
                    // C-142 deviation 4: the screen closes the open row when the list scrolls.
                    if phase == .interacting, openItem != nil { openItem = nil }
                }
                // §2 item 3: "the shared `PullToRefresh` wraps it, wired the way `media-home`
                // wires it".
                .pullToRefresh(onRefresh)
            }
        }
        .background(Token.layoutBackground)              // §2: "Background `color-layout-background`"
        // The caller passed new rows (its delete landed, or failed and restored the row): the
        // screen's own removals are superseded.
        .onChange(of: rowsIdentity) { _, _ in deletedItems = [] }
        // §3 The `Type` chip: "Tapping it opens C-036 FilterMenuOverlay" (§6: the one overlay).
        .filterMenuPresentation(isPresented: typeMenuOpen, onDismiss: { typeMenuOpen = false }) {
            typeMenu
        }
        // §3 Delete confirmation: "the same C-066 ActionMenuOverlay card through
        // `.actionMenuPresentation` that `memo-detail`'s delete-confirm uses".
        .actionMenuPresentation(isPresented: confirmingItem != nil && !captureStandIn,
                                onDismiss: cancelDelete) {
            deleteConfirmCard
        }
        .overlay {
            if captureStandIn && confirmingItem != nil {
                captureDeleteConfirm
            }
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

    /// §3 The `Type` chip: "C-036 FilterMenuOverlay in its multi-select form, with `Notes`,
    /// `Voice memos` and `Videos` as checkable rows, in that order, and **Save**. The menu has no "All types" row (D3)." As
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

    /// The Library list is drawn (top-aligned); every other state is a centred C-132 or blank.
    private func showsList(_ list: VisibleList) -> Bool { state.phase == .populated && !list.rows.isEmpty }

    @ViewBuilder
    private func content(_ list: VisibleList) -> some View {
        switch state.phase {
        case .populated:
            if list.rows.isEmpty {
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
                libraryList(list)
            }
        case .loading:
            // GAP — library-home §3 loading: skeleton rows name no §4 component (and there is no
            // section header); the content area is left empty (see the type's doc comment).
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

    // MARK: - §2 item 4 — the Library list (notes, voice memos and videos, one flat list)

    /// One row of the merged list, keyed by its model's stable id: a note (`state.noteIDs`, or its
    /// row index when the caller passed none — previews only), a memo or a video (its `id`).
    private enum Item: Hashable {
        case note(String)
        case memo(String)
        case video(String)
    }

    /// A note row's stable key: its model id, else (previews only) its row index.
    private static func noteKey(_ row: Int, in state: State) -> String {
        state.noteIDs.indices.contains(row) ? state.noteIDs[row] : "row:\(row)"
    }

    /// The note row a key names now, in `state.rowTitles` — a one-off scan, for a delete only.
    private func noteRow(_ key: String) -> Int? {
        state.rowTitles.indices.first { Self.noteKey($0, in: state) == key }
    }

    /// The caller's rows, for resetting `deletedItems` when they change.
    private var rowsIdentity: [String] {
        state.rowTitles.indices.map { Self.noteKey($0, in: state) } + state.memos.map(\.id)
            + state.videos.map(\.id)
    }

    /// §3 `row-open`'s seed: `note:<row index>` → that note row, `memo:<id>` → that memo row,
    /// `video:<id>` → that video row.
    private static func seededItem(_ key: String?, in state: State) -> Item? {
        guard let key, let colon = key.firstIndex(of: ":") else { return nil }
        let value = String(key[key.index(after: colon)...])
        switch key[..<colon] {
        case "note":
            return Int(value).flatMap { state.rowTitles.indices.contains($0) ? Item.note(noteKey($0, in: state)) : nil }
        case "memo": return state.memos.contains { $0.id == value } ? Item.memo(value) : nil
        case "video": return state.videos.contains { $0.id == value } ? Item.video(value) : nil
        default: return nil
        }
    }

    /// One visible row: what it is, where its data sits, and its D11 annotation ordinals — all
    /// resolved once, so per-row work is O(1) (§3 Performance contract: "an id-to-index map once
    /// per render, instead of scanning the notes, memos or videos for every row").
    private struct VisibleRow: Identifiable {
        enum Source { case note(row: Int), memo(index: Int), video(index: Int) }
        let item: Item
        let source: Source
        /// Position among every visible row (C-142 suffix; the C-088 above it is `position - 1`).
        let position: Int
        /// Position among the visible rows of its own kind (C-005 / C-006 / video row suffix).
        let kindPosition: Int
        var id: Item { item }
    }

    /// §2 item 4's list after the live filter and the deleted rows: newest first, no sections.
    private struct VisibleList {
        let rows: [VisibleRow]
    }

    /// §3 Performance contract: "The filtered and merged row list is computed once per render …
    /// so search and type filtering stay O(n)."
    private var visibleList: VisibleList {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let filtering = filtersLocally && !needle.isEmpty
        // §3: "The filter combines with search … Nothing checked, or all three checked, shows every
        // row; one or two checked shows only those kinds";
        // caller-owned filtering applies neither.
        let showsNotes = !filtersLocally || LibraryItemType.shows(.note, in: selectedTypes)
        let showsMemos = !filtersLocally || LibraryItemType.shows(.memo, in: selectedTypes)
        let showsVideos = !filtersLocally || LibraryItemType.shows(.video, in: selectedTypes)
        let notes = showsNotes ? state.rowTitles.indices.filter { row in
            guard !deletedItems.contains(.note(Self.noteKey(row, in: state))) else { return false }
            guard filtering else { return true }
            // §3: "a note by title and body text" — the preview line is the body text this
            // screen holds (§5).
            return state.rowTitles[row].localizedCaseInsensitiveContains(needle)
                || (preview(row) ?? "").localizedCaseInsensitiveContains(needle)
        } : []
        let memos = showsMemos ? state.memos.indices.filter { index in
            let memo = state.memos[index]
            guard !deletedItems.contains(.memo(memo.id)) else { return false }
            guard filtering else { return true }
            // §3: "a memo by title and transcript text".
            return memo.title.localizedCaseInsensitiveContains(needle)
                || (Self.transcript(memo) ?? "").localizedCaseInsensitiveContains(needle)
        } : []
        let videos = showsVideos ? state.videos.indices.filter { index in
            let video = state.videos[index]
            guard filtering else { return true }
            // §3: "a memo or a video by title and transcript text".
            return video.title.localizedCaseInsensitiveContains(needle)
                || (Self.transcript(video) ?? "").localizedCaseInsensitiveContains(needle)
        } : []
        return VisibleList(rows: merged(notes: notes, memos: memos, videos: videos))
    }

    /// §2 item 4: "interleaved in a single list, newest first by each item's own date: `updatedAt`
    /// for a note, `recordedAt` for a memo and for a video". A stable merge: the notes keep their
    /// passed order, and a note with no `rowUpdatedAt` stays ahead of every memo and video; on equal
    /// dates a note comes first, then a memo, then a video. O(n log n) once per render.
    private func merged(notes: [Int], memos: [Int], videos: [Int]) -> [VisibleRow] {
        var result: [VisibleRow] = []
        result.reserveCapacity(notes.count + memos.count + videos.count)
        let sortedMemos = memos.sorted { state.memos[$0].recordedAt > state.memos[$1].recordedAt }
        let sortedVideos = videos.sorted { state.videos[$0].recordedAt > state.videos[$1].recordedAt }
        var noteCursor = notes.startIndex, memoCursor = 0, videoCursor = 0
        var notePosition = 0, memoPosition = 0, videoPosition = 0
        func noteDate() -> Date? {
            guard noteCursor < notes.endIndex else { return nil }
            let row = notes[noteCursor]
            return state.rowUpdatedAt.indices.contains(row) ? state.rowUpdatedAt[row] : .distantFuture
        }
        func memoDate() -> Date? {
            memoCursor < sortedMemos.count ? state.memos[sortedMemos[memoCursor]].recordedAt : nil
        }
        func videoDate() -> Date? {
            videoCursor < sortedVideos.count ? state.videos[sortedVideos[videoCursor]].recordedAt : nil
        }
        while true {
            let nextNote = noteDate(), nextMemo = memoDate(), nextVideo = videoDate()
            if let note = nextNote, note >= (nextMemo ?? .distantPast), note >= (nextVideo ?? .distantPast) {
                let row = notes[noteCursor]
                result.append(VisibleRow(item: .note(Self.noteKey(row, in: state)), source: .note(row: row),
                                         position: result.count, kindPosition: notePosition))
                notePosition += 1; noteCursor += 1
            } else if let memo = nextMemo, memo >= (nextVideo ?? .distantPast) {
                let index = sortedMemos[memoCursor]
                result.append(VisibleRow(item: .memo(state.memos[index].id), source: .memo(index: index),
                                         position: result.count, kindPosition: memoPosition))
                memoPosition += 1; memoCursor += 1
            } else if nextVideo != nil {
                let index = sortedVideos[videoCursor]
                result.append(VisibleRow(item: .video(state.videos[index].id), source: .video(index: index),
                                         position: result.count, kindPosition: videoPosition))
                videoPosition += 1; videoCursor += 1
            } else {
                break
            }
        }
        return result
    }

    /// The transcript text a memo row holds — `.transcript(String)`'s text, else none.
    private static func transcript(_ memo: State.MemoRowInput) -> String? {
        if case .transcript(let text) = memo.preview { return text }
        return nil
    }

    /// The transcript line a video row holds — `.transcript(String)`'s text, else none.
    private static func transcript(_ video: State.VideoRowInput) -> String? {
        if case .transcript(let text) = video.preview { return text }
        return nil
    }

    /// §2 item 4: one flat list of house rows — "no date-section headers" — in a `LazyVStack`
    /// ("only the rows near the viewport are built"). Rows keep their natural heights.
    private func libraryList(_ list: VisibleList) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(list.rows) { row in
                if row.position > 0 {
                    // §2: "The C-088 hairline rule sits between every row … It starts where the
                    // text column starts" — past the 32 pt avatar and the row's 16 band gap.
                    SectionDivider()
                        .padding(.leading, NoteListRow.avatarSize + Token.Space.cardPadding)
                        .ui2Element(Self.annotation("C-088 SectionDivider", row.position - 1))
                }
                swipeRow(row.item) {
                    switch row.source {
                    case .note(let index):
                        NoteListRow(
                            title: state.rowTitles[index],
                            preview: preview(index),
                            dateLabel: state.rowDates.indices.contains(index) ? state.rowDates[index] : "",
                            contextLabel: context(index),
                            onTap: { onOpenNote(index) }
                        )
                        .ui2Element(Self.annotation("C-005 NoteListRow", row.kindPosition))
                    case .memo(let index):
                        // §2: "A memo row is a C-006 MemoListRow" in the same house row look.
                        let memo = state.memos[index]
                        MemoListRow(
                            title: memo.title,
                            durationLabel: memo.durationLabel,
                            dateLabel: memo.dateLabel,
                            preview: memo.preview,
                            onTap: { onOpenMemo(memo.id) }
                        )
                        .ui2Element(Self.annotation("C-006 MemoListRow", row.kindPosition))
                    case .video(let index):
                        // §2: "A video row has the same shape as a memo row, with the video glyph
                        // on the avatar" (§4: composed by the screen, no registry row yet).
                        let video = state.videos[index]
                        LibraryVideoRow(video: video, onTap: { onOpenVideo(video.id) })
                            .ui2Element(Self.annotation("Video row", row.kindPosition))
                    }
                }
                .ui2Element(Self.annotation("C-142 SwipeActions", row.position))
                // §3 Delete: "no fade/removal transition of its own" — C-142 collapses the row's
                // height; the screen's removal draws nothing.
                .transition(.identity)
            }
        }
        // §2: rows at the page margin, as on members-home.
        .padding(.horizontal, Token.Space.pageMargin)
        // §2 item 3: "The list ends with the page's normal bottom inset for the TabBar."
        .padding(.bottom, Token.Space.sectionGap)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// §3 Swipe actions: "every note, memo and video row is wrapped in the global SwipeActions
    /// component, with one trailing `Delete` action: a `trash` glyph on a solid `color-error`
    /// circle, with full-swipe on … Only one row is open at a time in the list: the screen holds
    /// that state."
    private func swipeRow<Row: View>(_ item: Item, @ViewBuilder row: () -> Row) -> some View {
        SwipeActions(
            trailing: [
                // §3: "an armed release deletes at once, with no confirmation"; "Tapping the resting
                // circle asks for confirmation" (`onTap` overrides `onAction` for the circle only).
                SwipeActionsAction(
                    label: "Delete",
                    glyph: .trash2,
                    tint: Token.error,
                    fullSwipe: true,
                    // §3: "A video row uses `removesRow: false`: the row stays in place until the
                    // delete call succeeds, and it springs back closed".
                    removesRow: Self.removesRow(item),
                    onAction: { delete(item, animated: false) },
                    onTap: { confirmingItem = item }
                ),
            ],
            openSide: openItem == item ? .trailing : nil,
            onOpenSideChange: { side in
                if side != nil {
                    openItem = item
                } else if openItem == item {
                    openItem = nil
                }
            },
            content: row
        )
    }

    /// §3 "The screen removes the row at once (it collapses), and the caller owns the effect". An armed release (`animated: false`) arrives
    /// after C-142's own height collapse, so the row is removed instantly with no transition of the
    /// screen's own (C-142 deviation 3). The confirmation's Delete, whose row has not collapsed,
    /// still moves the rows below on `motion-swipe-settle`, with no fade (`.transition(.identity)`).
    /// A video row (`removesRow: false`) is never removed here: it closes and stays until the
    /// caller's delete succeeds and the row leaves `state.videos`.
    private func delete(_ item: Item, animated: Bool = true) {
        if openItem == item { openItem = nil }
        if Self.removesRow(item) {
            withAnimation(animated ? Token.Motion.swipeSettle : nil) { _ = deletedItems.insert(item) }
        }
        switch item {
        case .note(let key): if let row = noteRow(key) { onDeleteNote(row) }
        case .memo(let id): onDeleteMemo(id)
        case .video(let id): onDeleteVideo(id)
        }
    }

    /// §3: notes and memos "collapse the row as soon as Delete runs"; a video row does not.
    private static func removesRow(_ item: Item) -> Bool {
        if case .video = item { return false }
        return true
    }

    // MARK: - §3 Delete confirmation

    private static let deleteAction = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Delete", tone: .destructive)

    /// §3: "The title is `Delete this note?`, `Delete this memo?` or `Delete this video?`, with the actions **Delete**
    /// (destructive) and **Cancel**."
    private var deleteConfirmCard: some View {
        ActionMenuOverlay(
            title: confirmingItem.map(Self.confirmTitle) ?? "",
            actions: [Self.deleteAction],
            doneLabel: "Cancel",
            onSelect: { _ in confirmDelete() },
            onDone: cancelDelete
        )
        .ui2Element("C-066 ActionMenuOverlay")
    }

    private static func confirmTitle(_ item: Item) -> String {
        switch item {
        case .note: return "Delete this note?"
        case .memo: return "Delete this memo?"
        case .video: return "Delete this video?"
        }
    }

    /// §3: "**Delete** runs the delete (a note or memo row collapses and `onDeleteNote` or
    /// `onDeleteMemo` fires; a video row calls `onDeleteVideo` and stays until it succeeds)."
    private func confirmDelete() {
        guard let item = confirmingItem else { return }
        confirmingItem = nil
        delete(item)
    }

    /// §3: "**Cancel**, a tap on the dim, or a swipe down dismisses the card and closes the open row."
    private func cancelDelete() {
        if let item = confirmingItem, openItem == item { openItem = nil }
        confirmingItem = nil
    }

    /// Capture stand-in (memo-detail precedent): C-066's presentation mounts after the first frame
    /// and slides in on appear, so a snapshot never sees it. Beneath the capture element map only,
    /// the screen draws the presented layer at rest exactly as `actionMenuPresentation` lays it out.
    private var captureDeleteConfirm: some View {
        ZStack(alignment: .bottom) {
            Token.black80
                .ignoresSafeArea()
                .ui2Element("Dim")
            deleteConfirmCard
                .padding(.horizontal, ActionMenuMotion.edgeInset)
                .padding(.bottom, ActionMenuMotion.edgeInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
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

    /// D11: "a component placed twice gets " 2" on the second".
    private static func annotation(_ name: String, _ position: Int) -> String {
        position == 0 ? name : "\(name) \(position + 1)"
    }
}

// MARK: - §2 item 4 — the video row

/// §2 "A **video row** has the same shape as a memo row, with the video glyph on the avatar";
/// §4 "Video row ×N — drawn in the same house row look as C-006 (the screen composes it from the
/// same row pattern; no separate registry row exists for it yet)". The C-006 band, line rhythm and
/// type styles exactly, over a C-038 Avatar with its `video` fallback glyph. Stateless: the caller
/// formats the date and duration (D6); a tap is reported through `onTap`.
private struct LibraryVideoRow: View {
    let video: LibraryHomeScreen.State.VideoRowInput
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            // C-006's house list-row band: avatar, then the text column, 16 between, vertical inset
            // 16, 8 between the lines (FLAGGED as C-006: `space-card-padding`, value-equal).
            HStack(alignment: .center, spacing: Token.Space.cardPadding) {
                Avatar(imageURL: nil, initials: nil, size: NoteListRow.avatarSize, fallbackGlyph: .video)
                    .accessibilityHidden(true)
                    .ui2Element("Leading")
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    titleLine
                    previewLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Token.Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // §3 Accessibility: "a memo or a video as title, duration, date, transcript state or preview".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(["Video", video.title, video.durationLabel, video.dateLabel, previewText].joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .ui2Element("VideoRow")
    }

    /// §2 Line 1: "the title on the left (one line, truncating) and, on the right, the date label
    /// followed by the duration (`9:38 PM · 0:45`, the memo rule), the whole label in `color-accent`".
    private var titleLine: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(video.title)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
            Text("\(video.dateLabel) · \(video.durationLabel)")
                .designTextStyle(Token.TypeStyle.bodySm)
                .monospacedDigit()
                .foregroundStyle(Token.accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .ui2Element("Date")
        }
        .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
        .ui2Element("Title line")
    }

    /// §2 Line 2: "one line, truncating, with no date in front: the first line of the video's
    /// transcript, or the state text `Transcribing…`, `Uploading…` or `Processing…`".
    private var previewLine: some View {
        Text(previewText)
            .designTextStyle(Token.TypeStyle.bodySm)
            // FLAGGED — as C-006 §2: italic on `type-body-sm` for `.transcribing`, no italic token.
            .italic(isTranscribing)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
            .ui2Element(isTranscript ? "Preview" : "Status")
    }

    private var previewText: String {
        switch video.preview {
        case .transcript(let text): return text
        case .transcribing: return "Transcribing…"
        case .uploading: return "Uploading…"
        case .processing: return "Processing…"
        }
    }

    private var isTranscribing: Bool {
        if case .transcribing = video.preview { return true }
        return false
    }

    private var isTranscript: Bool {
        if case .transcript = video.preview { return true }
        return false
    }

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}

// MARK: - §3 The `Type` filter

/// §3 inputs: "`LibraryItemType` is `note`, `memo` or `video` ("Videos"), in that order" — one
/// checkable row of the `Type` menu.
enum LibraryItemType: String {
    case note
    case memo
    case video

    /// §3 The `Type` menu's checkable rows, in order: "`Notes`, `Voice memos` and `Videos`".
    static let menuOptions: [Self] = [.note, .memo, .video]

    /// The row's label in C-036 and on the chip.
    var label: String {
        switch self {
        case .note: return "Notes"
        case .memo: return "Voice memos"
        case .video: return "Videos"
        }
    }

    /// §3: "Nothing checked, or all three checked, shows every row" — whether `type`'s rows show.
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

    /// §3 `populated-mixed`: "notes and memos interleaved in one flat list, including one memo
    /// `transcribing` and one memo `waiting-to-upload`, with rows dated today and within the past week".
    /// §3 `search-mixed` is this list with search text matching one note and one memo, and
    /// `filter-memos` is it with `Voice memos` checked in the `Type` menu.
    static func mixed(searchText: String = "", searchFocused: Bool = false, selectedTypes: Set<LibraryItemType> = [],
                      typeMenuOpen: Bool = false, openRow: String? = nil,
                      deleteConfirmPresented: Bool = false, videos: [VideoRowInput] = []) -> Self {
        .init(
            phase: .populated,
            searchText: searchText,
            searchFocused: searchFocused,
            selectedTypes: selectedTypes,
            typeMenuOpen: typeMenuOpen,
            rowTitles: ["Sermon prep: Romans 8", "Small group questions", "Grocery list"],
            rowDates: ["2:16 PM", "Wednesday", "Monday"],
            rowPreviews: ["Start with verse 28 and work backwards to the context", "What does rest look like this week?", ""],
            rowContexts: ["Sunday sermon recap", "", ""],
            rowUpdatedAt: [at("2026-11-21T14:16:00Z"), at("2026-11-18T19:00:00Z"), at("2026-11-16T10:00:00Z")],
            memos: [
                MemoRowInput(
                    id: "memo-3", title: "Memo 3", durationLabel: "4:12", dateLabel: "3:40 PM",
                    recordedAt: at("2026-11-21T15:40:00Z"),
                    preview: .transcript("So the main thing I want to say this Sunday is about rest")
                ),
                MemoRowInput(
                    id: "memo-prayer", title: "Prayer list for Thursday", durationLabel: "1:08", dateLabel: "9:05 AM",
                    recordedAt: at("2026-11-21T09:05:00Z"), preview: .transcribing
                ),
                MemoRowInput(
                    id: "memo-2", title: "Memo 2", durationLabel: "0:42", dateLabel: "Tuesday",
                    recordedAt: at("2026-11-17T08:00:00Z"), preview: .waitingToUpload
                ),
            ],
            videos: videos,
            openRow: openRow,
            deleteConfirmPresented: deleteConfirmPresented
        )
    }

    /// §3 `populated-mixed` / `search-mixed` / `type-menu-open`: "a video row" among the notes and
    /// memos, whose transcript matches `search-mixed`'s "rest".
    static let mixedVideos: [VideoRowInput] = [
        VideoRowInput(
            id: "video-welcome", title: "Sunday welcome", durationLabel: "0:45", dateLabel: "11:20 AM",
            recordedAt: at("2026-11-21T11:20:00Z"),
            preview: .transcript("Welcome back. This week we are talking about rest")
        ),
    ]

    /// §3 `populated-videos`: "video rows in each of their line 2 states: a transcript first line,
    /// `Transcribing…`, `Uploading…` and `Processing…`, among notes and memos". `filter-videos` is
    /// it with `Videos` checked in the `Type` menu.
    static func videos(selectedTypes: Set<LibraryItemType> = []) -> Self {
        mixed(selectedTypes: selectedTypes, videos: mixedVideos + [
            VideoRowInput(
                id: "video-recap", title: "Lesson 4 recap", durationLabel: "2:00", dateLabel: "4:05 PM",
                recordedAt: at("2026-11-21T16:05:00Z"), preview: .transcribing
            ),
            VideoRowInput(
                id: "video-intro", title: "Small group intro", durationLabel: "1:12", dateLabel: "Thursday",
                recordedAt: at("2026-11-19T18:00:00Z"), preview: .uploading
            ),
            VideoRowInput(
                id: "video-prayer-walk", title: "Prayer walk invite", durationLabel: "1:58", dateLabel: "Monday",
                recordedAt: at("2026-11-16T12:00:00Z"), preview: .processing
            ),
        ])
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
    LibraryHomeScreen(state: .mixed(videos: LibraryHomeScreen.State.mixedVideos))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("search-mixed") {
    LibraryHomeScreen(state: .mixed(searchText: "rest", searchFocused: true, videos: LibraryHomeScreen.State.mixedVideos))
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
    LibraryHomeScreen(state: .mixed(typeMenuOpen: true, videos: LibraryHomeScreen.State.mixedVideos))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("row-open") {
    LibraryHomeScreen(state: .mixed(openRow: "note:0"))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("delete-confirm") {
    LibraryHomeScreen(state: .mixed(openRow: "note:0", deleteConfirmPresented: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("populated-videos") {
    LibraryHomeScreen(state: .videos())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("filter-videos") {
    LibraryHomeScreen(state: .videos(selectedTypes: [.video]))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
