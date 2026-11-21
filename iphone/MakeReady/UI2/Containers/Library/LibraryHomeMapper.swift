import Foundation

/// notes D3/D8/D20: `AppState.studyNotes` → library-home's notes list. Pure: the clock and calendar
/// come in, so a capture or a test does not depend on the day it runs.
enum LibraryHomeMapper {

    /// What the screen should be showing. d2m's screen has no error phase (library-home §5), so the
    /// container keeps `.error` on `.loading` and surfaces the failure through the error channel.
    enum Phase: Equatable {
        case loading, error, empty, noResults, list
    }

    /// D3: the notes in date sections. `searchIds` is the server's match list for the current `q`
    /// (D8): nil shows every note, else only those ids (no client-side corpus search).
    static func rows(notes: [StudyNote], searchIds: [String]?, now: Date, calendar: Calendar) -> [NoteSection] {
        let shown: [StudyNote]
        if let searchIds {
            let wanted = Set(searchIds)
            shown = notes.filter { wanted.contains($0.id) }
        } else {
            shown = notes
        }
        return NotesSectioning.sections(shown, now: now, calendar: calendar)
    }

    /// D20: rows win over every other state (a failed refresh keeps the cached list); with no rows, a
    /// fetch in flight is loading, a failure is an error, a query is no-results, else empty.
    static func phase(isLoading: Bool, loadFailed: Bool, sections: [NoteSection], query: String) -> Phase {
        if !sections.isEmpty { return .list }
        if loadFailed { return .error }
        if isLoading { return .loading }
        return query.trimmingCharacters(in: .whitespaces).isEmpty ? .empty : .noResults
    }

    /// The screen's props for the sections (parallel arrays; `onOpenNote` gives a row index into
    /// `rowTitles`, which `noteIds(in:)` maps back to a note id).
    static func state(sections: [NoteSection], phase: Phase, query: String, now: Date, calendar: Calendar)
        -> LibraryHomeScreen.State {
        var state = LibraryHomeScreen.State(phase: screenPhase(phase), searchText: query)
        for (index, section) in sections.enumerated() {
            state.sectionTitles.append(section.title)
            for note in section.notes {
                state.rowSections.append(index)
                state.rowTitles.append(note.displayTitle)
                state.rowDates.append(note.updatedDate.map {
                    NotesSectioning.dateLabel($0, now: now, calendar: calendar)
                } ?? "")
                state.rowPreviews.append(note.preview ?? "")
                state.rowContexts.append(note.contextLabel ?? "")
            }
        }
        return state
    }

    /// Row order of `state(sections:…)`: the note ids, one per row.
    static func noteIds(in sections: [NoteSection]) -> [String] {
        sections.flatMap { $0.notes.map(\.id) }
    }

    /// `.noResults` is the screen's populated phase with no rows and a query.
    private static func screenPhase(_ phase: Phase) -> LibraryHomeScreen.State.Phase {
        switch phase {
        case .loading, .error: return .loading
        case .empty: return .empty
        case .noResults, .list: return .populated
        }
    }
}
