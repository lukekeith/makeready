import SwiftUI

/// notes D3/D8/D17/D20: the Home tab's Library section root — the leader's notes list. Reads
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

    /// D8: the pause after the last keystroke before `q` is sent.
    static let searchDebounce: Duration = .milliseconds(300)

    var body: some View {
        let now = Date()
        let calendar = Calendar.current
        let memos = LibraryHomeMapper.visibleMemos(stored: AppState.shared.voiceMemos.all,
                                                   queued: AppState.shared.memoUploads?.pendingItems ?? [],
                                                   searchMatches: searchMatches)
        let sections = LibraryHomeMapper.rows(notes: LibraryItemType.shows(.note, in: selectedTypes) ? AppState.shared.studyNotes.all : [],
                                              searchIds: searchIds, memos: LibraryItemType.shows(.memo, in: selectedTypes) ? memos : [],
                                              now: now, calendar: calendar)
        let phase = Self.filteredPhase(
            LibraryHomeMapper.phase(isLoading: isLoading, loadFailed: loadFailed, sections: sections, query: query),
            selectedTypes: selectedTypes)
        let noteIds = LibraryHomeMapper.noteIds(in: sections)
        let state: LibraryHomeScreen.State = {
            var state = LibraryHomeMapper.state(sections: sections, phase: phase, query: query, now: now, calendar: calendar)
            state.selectedTypes = selectedTypes
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
            onScrollChange: { offset, interacting in scrollReport.report(offset, interacting) },
            onSaveTypes: { selectedTypes = $0 },
            onRefresh: { Task { await fetch(q: Self.trimmedQuery(query)) } }
        )
        .task { await fetch(q: nil) }
        .onDisappear { searchTask?.cancel() }
    }

    private func search(_ text: String) {
        query = text
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchIds = nil
            searchMatches = nil
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
        defer { isLoading = false }
        do {
            let failed: Bool
            if let q {
                let result = try await LibraryHomeSearch.run(
                    q: q,
                    loadNotes: { try await Self.cancellable { try await NoteActions().load(q: q) } },
                    loadMemos: { try await Self.cancellable { try await MemoActions().loadMemos(q: q) } })
                try Task.checkCancellation()
                searchIds = result.noteIds
                searchMatches = result.memos
                failed = result.failed
            } else {
                async let notes: Void = Self.cancellable { _ = try await NoteActions().load(q: nil) }
                async let memos: Void = Self.cancellable { _ = try await MemoActions().loadMemos(q: nil) }
                var anyFailed = false
                do { try await notes } catch is CancellationError { throw CancellationError() } catch { anyFailed = true }
                do { try await memos } catch is CancellationError { throw CancellationError() } catch { anyFailed = true }
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
