import SwiftUI

/// notes D3/D8/D17/D20: the Home tab's Library section root — the leader's notes, memos and videos list. Reads
/// `AppState.studyNotes` (cache-first), refreshes through `NoteActions`, and sends the search
/// capsule's text to the server as `q` 300 ms after the last keystroke (no client-side corpus
/// search). A row tap pushes the editor through `UI2Navigator`; new notes come from the TabBar +
/// menu (library-home §3: no compose button). The `Type` chip filters by kind here, since the
/// screen's filtering is caller-owned, and pull to refresh re-fetches.
struct LibraryHomeContainer: View {
    @Environment(\.ui2Navigator) private var navigator
    /// Library owns its scroll (`ownsScroll`), so it reports to the TopNav morph itself.
    @Environment(\.sectionScrollReport) private var scrollReport
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var query = ""
    /// The server's matches for `query` (nil: no search, show every note).
    @State private var searchIds: [String]?
    /// The server's memo matches for `query` (nil: no search, show every memo).
    @State private var searchMatches: [VoiceMemoSummary]?
    @State private var searchTask: Task<Void, Never>?
    /// library-home §3 `Type` chip: the saved set of kinds (empty or both = everything).
    @State private var selectedTypes: Set<LibraryItemType> = []
    /// library-home §3 Swipe actions: rows deleted and not yet confirmed by the server — hidden at
    /// once, restored when the delete fails.
    @State private var deletingNoteIds: Set<String> = []
    @State private var deletingMemoIds: Set<String> = []
    /// video-recorder D17: a video row stays until the server call succeeds (`removesRow: false`), so this
    /// is only the second confirm for a video that lessons use.
    @State private var pendingRemoval: LibraryVideoDeletion.Removal?
    /// D20: the last scroll offset, the measured viewport and row count, whether a page is loading, and
    /// whether the last page failed (a failed page waits for Retry, a refresh or the page reappearing).
    @State private var scrollOffset: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var rowCount = 0
    @State private var isPagingVideos = false
    @State private var lastPageFailed = false

    /// D8: the pause after the last keystroke before `q` is sent.
    static let searchDebounce: Duration = .milliseconds(300)

    var body: some View {
        let now = Date()
        let calendar = Calendar.current
        let memos = LibraryHomeMapper.visibleMemos(stored: AppState.shared.voiceMemos.all,
                                                   queued: AppState.shared.memoUploads?.pendingItems ?? [],
                                                   searchMatches: searchMatches)
            .filter { !deletingMemoIds.contains($0.id) }
        let notes = AppState.shared.studyNotes.all.filter { !deletingNoteIds.contains($0.id) }
        let window = AppState.shared.videoLibraryWindow
        let trimmed = Self.trimmedQuery(query)
        // The window answers one query: while another is in flight, its rows are not this list's.
        let windowMatches = window.query == trimmed
        let videos = LibraryHomeMapper.visibleVideos(
            stored: windowMatches ? window.ids.compactMap { AppState.shared.libraryVideos[$0] } : [],
            queued: trimmed == nil ? AppState.shared.videoUploads?.pendingItems ?? [] : [])
        let kinds = LibraryHomeMapper.kinds(checked: selectedTypes)
        let rows = LibraryHomeMapper.rows(notes: kinds.contains(.note) ? notes : [],
                                          searchIds: searchIds, memos: kinds.contains(.memo) ? memos : [],
                                          videos: kinds.contains(.video) ? videos : [],
                                          videosHaveMore: kinds.contains(.video) && windowMatches && window.hasMore)
        let phase = Self.filteredPhase(
            LibraryHomeMapper.phase(isLoading: isLoading, loadFailed: loadFailed, rows: rows, query: query),
            selectedTypes: selectedTypes)
        let noteIds = LibraryHomeMapper.noteIds(in: rows)
        let state: LibraryHomeScreen.State = {
            var state = LibraryHomeMapper.state(rows: rows, phase: phase, query: query, now: now, calendar: calendar)
            state.selectedTypes = selectedTypes
            state.noteIDs = noteIds
            return state
        }()
        LibraryHomeScreen(
            state: state,
            onOpenNote: { row in
                guard noteIds.indices.contains(row) else { return }
                navigator.push(.noteEditor(noteId: noteIds[row]))
            },
            onOpenMemo: { id in navigator.push(Self.destination(forMemoId: id)) },
            onSearchChange: search,
            filtersLocally: false,
            onScrollChange: { offset, interacting in
                scrollReport.report(offset, interacting)
                scrollOffset = offset
                loadMoreVideosIfNearEnd()
            },
            onSaveTypes: { selectedTypes = $0 },
            onRefresh: { Task { await fetch(q: Self.trimmedQuery(query)) } },
            onDeleteNote: { row in
                guard noteIds.indices.contains(row) else { return }
                Task { await deleteNote(id: noteIds[row]) }
            },
            onDeleteMemo: { id in Task { await deleteMemo(id: id) } },
            onDeleteVideo: { id in Task { await deleteVideo(id: id) } }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            viewportHeight = height
            loadMoreVideosIfNearEnd()
        }
        .actionMenuPresentation(isPresented: pendingRemoval != nil, onDismiss: { pendingRemoval = nil }) {
            removalConfirmation
        }
        .task { await fetch(q: nil) }
        // A queued video that finished leaves the queue before the window lists it: reload page 1.
        .onChange(of: AppState.shared.videoUploads?.pendingItems.count) { old, new in
            guard let old, let new, new < old, trimmed == nil else { return }
            Task { await fetch(q: nil) }
        }
        // A short list (older rows held back) cannot scroll, so it asks for the next page itself.
        .onChange(of: rows.ids.count, initial: true) { _, count in
            rowCount = count
            loadMoreVideosIfNearEnd()
        }
        .onDisappear { searchTask?.cancel() }
    }

    /// library-home §3 "The container calls `NoteActions.softDelete` for a note … A failure goes to
    /// the app's error banner with a Retry, and the row is restored."
    private func deleteNote(id: String) async {
        deletingNoteIds.insert(id)
        defer { deletingNoteIds.remove(id) }
        do {
            try await NoteActions().softDelete(id: id)
            searchIds?.removeAll { $0 == id }
        } catch {
            AppState.shared.recordError(error, context: "LibraryHomeContainer.deleteNote", surface: true,
                                        friendlyMessage: "Couldn't delete this note",
                                        retry: { Task { await deleteNote(id: id) } })
        }
    }

    /// library-home §3 "… `MemoActions.softDelete` for a memo, or removes a queued (not yet uploaded)
    /// memo from the upload queue" — a queued memo's id is `local:<localId>` (D17).
    private func deleteMemo(id: String) async {
        deletingMemoIds.insert(id)
        defer { deletingMemoIds.remove(id) }
        do {
            if id.hasPrefix(Self.localMemoPrefix) {
                guard let uploads = AppState.shared.memoUploads else { throw CancellationError() }
                try await uploads.remove(localId: String(id.dropFirst(Self.localMemoPrefix.count)))
            } else {
                try await MemoActions().softDelete(id: id)
            }
            searchMatches?.removeAll { $0.id == id }
        } catch {
            AppState.shared.recordError(error, context: "LibraryHomeContainer.deleteMemo", surface: true,
                                        friendlyMessage: "Couldn't delete this memo",
                                        retry: { Task { await deleteMemo(id: id) } })
        }
    }

    /// video-recorder D17: the flow itself is `LibraryVideoDeletion`; this wires its seams to the actions,
    /// the upload queue and the error banner.
    private var videoDeletion: LibraryVideoDeletion {
        let actions = VideoActions()
        return LibraryVideoDeletion(
            decide: { try await actions.deleteDecision(id: $0) },
            perform: { try await actions.deleteOrRemove(id: $0, decision: $1) },
            serverId: { AppState.shared.videoUploads?.serverId(forLocalId: $0) },
            removeQueued: { id in
                guard let uploads = AppState.shared.videoUploads else { throw CancellationError() }
                try uploads.remove(localId: id)
            },
            askAgain: { pendingRemoval = $0 },
            surface: { error, context, message, retry in
                AppState.shared.recordError(error, context: context, surface: true, friendlyMessage: message,
                                            retry: retry)
            })
    }

    private func deleteVideo(id: String) async { await videoDeletion.delete(id: id) }

    private func confirmRemoval() async {
        guard let removal = pendingRemoval else { return }
        pendingRemoval = nil
        await videoDeletion.confirm(removal)
    }

    /// The second C-066 confirm: the decision's own title, one destructive action, Cancel.
    private var removalConfirmation: some View {
        let title = pendingRemoval?.decision.confirmTitle ?? ""
        return ActionMenuOverlay(
            title: title,
            message: nil,
            actions: [.init(glyph: "", label: "Remove from Library", tone: .destructive)],
            doneLabel: "Cancel",
            onSelect: { _ in Task { await confirmRemoval() } },
            onDone: { pendingRemoval = nil }
        )
    }

    /// D20: the next page loads when the viewport is near the end of the rows the list holds
    /// (`LibraryVideoPaging`). After a page lands the check runs again, so a list too short to scroll keeps
    /// loading until it fills or runs out. A failure goes to the console and the banner with Retry; nothing
    /// retries it by itself, so a dead network is not hammered by scroll events.
    private func loadMoreVideosIfNearEnd() {
        let window = AppState.shared.videoLibraryWindow
        guard LibraryVideoPaging.shouldLoadNext(
            hasMore: window.hasMore, windowMatchesQuery: window.query == Self.trimmedQuery(query),
            videosShown: LibraryItemType.shows(.video, in: selectedTypes), isLoading: isPagingVideos,
            lastPageFailed: lastPageFailed, offset: scrollOffset, viewport: viewportHeight, rowCount: rowCount)
        else { return }
        isPagingVideos = true
        Task {
            do {
                try await VideoActions().loadNextLibraryPage()
                isPagingVideos = false
                loadMoreVideosIfNearEnd()
            } catch {
                isPagingVideos = false
                lastPageFailed = true
                AppState.shared.recordError(error, context: "LibraryHomeContainer.loadNextVideoPage", surface: true,
                                            friendlyMessage: "Couldn't load more videos",
                                            retry: { lastPageFailed = false; loadMoreVideosIfNearEnd() })
            }
        }
    }

    /// memo-screens D17: a queued memo's row id prefix (`LibraryHomeMapper`).
    private static let localMemoPrefix = "local:"

    private func search(_ text: String) {
        query = text
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchIds = nil
            searchMatches = nil
            // The videos window still answers the old query: load the whole Library again.
            if AppState.shared.videoLibraryWindow.query != nil { searchTask = Task { await fetch(q: nil) } }
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: Self.searchDebounce)
            guard !Task.isCancelled else { return }
            await fetch(q: trimmed)
        }
    }

    /// library-home §3 search-no-results: a type filter matching nothing is no-results, not the empty Library.
    private static func filteredPhase(_ phase: LibraryHomeMapper.Phase, selectedTypes: Set<LibraryItemType>) -> LibraryHomeMapper.Phase {
        phase == .empty && !selectedTypes.isEmpty ? .noResults : phase
    }

    /// The query `fetch(q:)` takes: nil for none.
    private static func trimmedQuery(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// memo-screens D4, D17: a memo row opens its page; a queued memo's id is already `local:<localId>`.
    static func destination(forMemoId id: String) -> UI2Destination { .memoDetail(memoId: id) }

    /// A superseded request surfaces as `URLError(.cancelled)` from `APIClient`; it counts as a cancellation,
    /// not a failed load.
    private static func cancellable<T>(_ load: () async throws -> T) async throws -> T {
        do {
            return try await load()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
    }

    /// `q == nil` is the full list; else the search. A failure keeps what is on screen and goes to the
    /// error channel with a retry (D20); with nothing cached the screen stays in `.loading`. Notes and memos
    /// load in parallel, and one failing keeps the other (D5).
    private func fetch(q: String?) async {
        isLoading = true
        lastPageFailed = false
        defer { isLoading = false }
        do {
            let failed: Bool
            if let q {
                let result = try await LibraryHomeSearch.run(
                    q: q,
                    loadNotes: { try await Self.cancellable { try await NoteActions().load(q: q) } },
                    loadMemos: { try await Self.cancellable { try await MemoActions().loadMemos(q: q) } },
                    loadVideos: { try await Self.cancellable { try await VideoActions().loadLibrary(cursor: nil, q: q) } })
                try Task.checkCancellation()
                searchIds = result.noteIds
                searchMatches = result.memos
                failed = result.failed
            } else {
                async let notes: Void = Self.cancellable { _ = try await NoteActions().load(q: nil) }
                async let memos: Void = Self.cancellable { _ = try await MemoActions().loadMemos(q: nil) }
                async let videos: Void = Self.cancellable { try await VideoActions().loadLibrary(cursor: nil, q: nil) }
                var anyFailed = false
                do { try await notes } catch is CancellationError { throw CancellationError() } catch { anyFailed = true }
                do { try await memos } catch is CancellationError { throw CancellationError() } catch { anyFailed = true }
                do { try await videos } catch is CancellationError { throw CancellationError() } catch { anyFailed = true }
                failed = anyFailed
            }
            loadFailed = failed
            if failed {
                AppState.shared.recordError(LibraryLoadError.partial, context: "LibraryHomeContainer.fetch", surface: true,
                                            friendlyMessage: "Couldn't load your library",
                                            retry: { Task { await fetch(q: q) } })
            }
        } catch {
            // Silent: a newer search or leaving the page cancelled this one.
        }
    }

    private enum LibraryLoadError: Error { case partial }
}
