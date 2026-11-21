import XCTest
@testable import MakeReady

/// notes Task 13 (D3, D8, D20): the notes list's state → props mapping.
@MainActor
final class LibraryHomeMapperTests: XCTestCase {

    private var chicago: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    func testRowsCarryTitleDatePreviewAndContextInSections() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let notes = [StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60)),
                     StudyNote.stub(id: "b", content: "# Old\nx", title: nil, updatedAt: now.addingTimeInterval(-86_400))]
        let sections = LibraryHomeMapper.rows(notes: notes, searchIds: nil, now: now, calendar: chicago)
        XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday"])
        XCTAssertEqual(sections[1].notes.first?.displayTitle, "Old")
    }

    func testSearchShowsOnlyTheServerMatches() {
        let now = Date()
        let notes = ["a", "b", "c"].map { StudyNote.stub(id: $0, updatedAt: now) }
        XCTAssertEqual(LibraryHomeMapper.rows(notes: notes, searchIds: ["b"], now: now, calendar: chicago).flatMap(\.notes).map(\.id), ["b"])
    }

    func testPhaseIsEmptyNoResultsOrErrorAsDesigned() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: ""), .empty)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: "zzz"), .noResults)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [], query: ""), .error)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [NoteSection(title: "Today", notes: [.stub(id: "a")])], query: ""), .list)
    }

    func testLoadingWithNothingCachedIsLoadingAndRowsWin() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, sections: [], query: ""), .loading)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, sections: [NoteSection(title: "Today", notes: [.stub(id: "a")])], query: ""), .list)
    }

    func testStateFlattensRowsAndMapsRowIndexToNoteId() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let notes = [StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60)),
                     StudyNote.stub(id: "b", title: "Old", updatedAt: now.addingTimeInterval(-86_400))]
        let sections = LibraryHomeMapper.rows(notes: notes, searchIds: nil, now: now, calendar: chicago)
        let state = LibraryHomeMapper.state(sections: sections, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.phase, .populated)
        XCTAssertEqual(state.sectionTitles, ["Today", "Yesterday"])
        XCTAssertEqual(state.rowSections, [0, 1])
        XCTAssertEqual(state.rowTitles, ["Walk", "Old"])
        XCTAssertEqual(state.rowPreviews, ["Psalm", ""])
        XCTAssertEqual(state.rowContexts, ["Youth", ""])
        XCTAssertEqual(LibraryHomeMapper.noteIds(in: sections), ["a", "b"])
    }

    func testNoResultsAndErrorMapToTheScreensPhases() {
        let args = (now: Date(), calendar: chicago)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .noResults, query: "zzz", now: args.now, calendar: args.calendar).phase, .populated)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .error, query: "", now: args.now, calendar: args.calendar).phase, .loading)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .empty, query: "", now: args.now, calendar: args.calendar).phase, .empty)
    }
}
