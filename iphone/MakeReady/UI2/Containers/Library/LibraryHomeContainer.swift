import SwiftUI

/// notes D3/D8/D17/D20: the Home tab's Library section root — the leader's notes list. Reads
/// `AppState.studyNotes` (cache-first), refreshes through `NoteActions`, and sends the search
/// capsule's text to the server as `q` 300 ms after the last keystroke (no client-side corpus
/// search). Compose and a row tap push the editor through `UI2Navigator`.
struct LibraryHomeContainer: View {
    @Environment(\.ui2Navigator) private var navigator
    /// Library owns its scroll (`ownsScroll`), so it reports to the TopNav morph itself.
    @Environment(\.sectionScrollReport) private var scrollReport
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var query = ""
    /// The server's matches for `query` (nil: no search, show every note).
    @State private var searchIds: [String]?
    @State private var searchTask: Task<Void, Never>?

    /// D8: the pause after the last keystroke before `q` is sent.
    static let searchDebounce: Duration = .milliseconds(300)

    var body: some View {
        let now = Date()
        let calendar = Calendar.current
        let sections = LibraryHomeMapper.rows(notes: AppState.shared.studyNotes.all, searchIds: searchIds,
                                              now: now, calendar: calendar)
        let phase = LibraryHomeMapper.phase(isLoading: isLoading, loadFailed: loadFailed, sections: sections, query: query)
        let noteIds = LibraryHomeMapper.noteIds(in: sections)
        LibraryHomeScreen(
            state: LibraryHomeMapper.state(sections: sections, phase: phase, query: query, now: now, calendar: calendar),
            onOpenNote: { row in
                guard noteIds.indices.contains(row) else { return }
                navigator.push(.noteEditor(noteId: noteIds[row]))
            },
            onCompose: { navigator.push(.newNote(flowId: UUID())) },
            onSearchChange: search,
            filtersLocally: false,
            onScrollChange: { offset, interacting in scrollReport.report(offset, interacting) }
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
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: Self.searchDebounce)
            guard !Task.isCancelled else { return }
            await fetch(q: trimmed)
        }
    }

    /// `q == nil` is the full list; else the search. A failure keeps what is on screen and goes to the
    /// error channel with a retry (D20); with nothing cached the screen stays in `.loading`.
    private func fetch(q: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = try await NoteActions().load(q: q)
            loadFailed = false
            if q != nil, !Task.isCancelled { searchIds = ids }
        } catch is CancellationError {
            // Silent: a newer search or leaving the page cancelled this one.
        } catch {
            loadFailed = true
            AppState.shared.recordError(error, context: "LibraryHomeContainer.fetch", surface: true,
                                        friendlyMessage: "Couldn't load your notes",
                                        retry: { Task { await fetch(q: q) } })
        }
    }
}
