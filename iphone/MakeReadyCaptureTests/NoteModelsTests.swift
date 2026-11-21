import XCTest
@testable import MakeReady

/// notes Task 8: the `StudyNote` wire type, D3 sectioning, and `AppState.studyNotes` (D26).
@MainActor
final class NoteModelsTests: XCTestCase {

    /// Gregorian, America/Chicago, `en_US_POSIX`: the fixed clock D3's bucketing is checked against.
    private var chicago: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    func testNoteDecodesTheContractShapeAndKeepsTimestampsVerbatim() throws {
        let json = ##"{"id":"n1","memberId":null,"userId":"u1","type":"NOTE","content":"# Walk\nbody","title":"Walk","preview":"body","contextLabel":"Youth Group","isActive":true,"createdAt":"2026-11-20T10:00:00.123Z","updatedAt":"2026-11-20T10:05:00.456Z","links":[{"id":"l1","noteId":"n1","refType":"MEMO","refId":"m1","metadata":null,"createdAt":"2026-11-20T10:00:00.123Z"}]}"##
        let note = try JSONDecoder.apiDecoder.decode(StudyNote.self, from: Data(json.utf8))
        XCTAssertEqual(note.updatedAt, "2026-11-20T10:05:00.456Z")
        XCTAssertEqual(note.links.first?.refType, "MEMO")
        XCTAssertEqual(note.contextLabel, "Youth Group")
    }

    func testDisplayTitleFallsBackToTheFirstContentLine() {
        XCTAssertEqual(StudyNote.stub(content: "\n## Old note\nmore", title: nil).displayTitle, "Old note")
        XCTAssertEqual(StudyNote.stub(content: "  ", title: nil).displayTitle, "New Note")
    }

    func testSectionsBucketByCalendarDayNewestFirst() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let ages = [0, 1, 4, 7, 8, 30, 45, 400]
        let notes = ages.map { StudyNote.stub(id: "n\($0)", updatedAt: now.addingTimeInterval(-Double($0) * 86_400)) }
        let sections = NotesSectioning.sections(notes.reversed(), now: now, calendar: chicago)
        XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "October", "2025"])
        XCTAssertEqual(sections[2].notes.map(\.id), ["n4", "n7"])
    }

    func testDateLabelIsTimeWeekdayOrShortDate() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-3_600), now: now, calendar: chicago), "11:00 AM")
        XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-2 * 86_400), now: now, calendar: chicago), "Wednesday")
        XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-9 * 86_400), now: now, calendar: chicago), "11/11/26")
    }

    func testPersistedSnapshotKeepsThe200NewestNotesAndOldCachesDecode() throws {
        let state = AppState()
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        state.studyNotes.replaceAll((0..<250).map { StudyNote.stub(id: "n\($0)", updatedAt: base.addingTimeInterval(Double($0))) })
        let snapshot = PersistedState(from: state)
        XCTAssertEqual(Set(snapshot.studyNotes.map(\.id)), Set((50..<250).map { "n\($0)" }))
        var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]; dict["studyNotes"] = nil
        XCTAssertEqual(try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: dict)).studyNotes.count, 0)
    }

    func testClearAllDataEmptiesStudyNotes() {
        let state = AppState()
        state.studyNotes.upsert(.stub(id: "n1"))
        state.clearAllData()
        XCTAssertTrue(state.studyNotes.all.isEmpty)
    }
}

extension StudyNote {
    /// Test-only: every field defaulted; `updatedAt` takes a `Date` and is written the way the server does (fractional ISO).
    static func stub(
        id: String = "n1",
        content: String = "body",
        title: String? = nil,
        preview: String? = nil,
        contextLabel: String? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_790_000_000),
        links: [NoteLinkRef] = []
    ) -> StudyNote {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let stamp = formatter.string(from: updatedAt)
        return StudyNote(
            id: id, userId: "u1", type: "NOTE", content: content, title: title, preview: preview,
            contextLabel: contextLabel, isActive: true, createdAt: stamp, updatedAt: stamp, links: links
        )
    }
}
