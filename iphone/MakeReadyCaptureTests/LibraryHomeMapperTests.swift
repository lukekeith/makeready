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
        let sections = LibraryHomeMapper.rows(notes: notes, searchIds: nil, memos: [], now: now, calendar: chicago)
        XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday"])
        XCTAssertEqual(sections[1].notes.first?.displayTitle, "Old")
    }

    func testSearchShowsOnlyTheServerMatches() {
        let now = Date()
        let notes = ["a", "b", "c"].map { StudyNote.stub(id: $0, updatedAt: now) }
        XCTAssertEqual(LibraryHomeMapper.rows(notes: notes, searchIds: ["b"], memos: [], now: now, calendar: chicago).flatMap(\.notes).map(\.id), ["b"])
    }

    func testPhaseIsEmptyNoResultsOrErrorAsDesigned() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: ""), .empty)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: "zzz"), .noResults)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [], query: ""), .error)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [.init(title: "Today", notes: [.stub(id: "a")], memos: [])], query: ""), .list)
    }

    func testLoadingWithNothingCachedIsLoadingAndRowsWin() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, sections: [], query: ""), .loading)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, sections: [.init(title: "Today", notes: [.stub(id: "a")], memos: [])], query: ""), .list)
    }

    func testStateFlattensRowsAndMapsRowIndexToNoteId() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let notes = [StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60)),
                     StudyNote.stub(id: "b", title: "Old", updatedAt: now.addingTimeInterval(-86_400))]
        let sections = LibraryHomeMapper.rows(notes: notes, searchIds: nil, memos: [], now: now, calendar: chicago)
        let state = LibraryHomeMapper.state(sections: sections, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.phase, .populated)
        XCTAssertEqual(state.sectionTitles, ["Today", "Yesterday"])
        XCTAssertEqual(state.rowSections, [0, 1])
        XCTAssertEqual(state.rowTitles, ["Walk", "Old"])
        XCTAssertEqual(state.rowPreviews, ["Psalm", ""])
        XCTAssertEqual(state.rowContexts, ["Youth", ""])
        XCTAssertEqual(LibraryHomeMapper.noteIds(in: sections), ["a", "b"])
    }

    // MARK: - Memos in the merged list (D5, D16, D17)

    private let now = ISO8601DateFormatter().date(from: "2026-11-20T17:00:00Z")!

    private func note(_ id: String, updated: Date) -> StudyNote { .stub(id: id, updatedAt: updated) }

    private func memo(_ id: String, recorded: Date, preview: MemoListRow.Preview = .audioOnly) -> LibraryHomeMapper.MemoSource {
        .init(id: id, title: "Memo \(id)", durationMs: 42_000, recordedAt: recorded, preview: preview)
    }

    private func summary(_ id: String, status: String = "none", preview: String? = nil) -> VoiceMemoSummary {
        let stamp = "2026-11-20T16:00:00.000Z"
        let previewJSON = preview.map { "\"\($0)\"" } ?? "null"
        let json = #"{"id":"\#(id)","title":"Memo \#(id)","mimeType":"audio/mp4","fileSize":5000,"durationMs":42000,"transcriptPreview":\#(previewJSON),"transcriptStatus":"\#(status)","transcriptSource":null,"uploadStatus":"ready","recordedAt":"\#(stamp)","createdAt":"\#(stamp)","updatedAt":"\#(stamp)"}"#
        return try! JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(json.utf8))
    }

    private func queued(_ localId: String, serverId: String? = nil) -> MemoQueueItem {
        MemoQueueItem(
            localId: localId, fileName: "\(localId).m4a", title: "Queued \(localId)", durationMs: 5_000,
            waveformPeaks: [], recordedAt: "2026-11-20T16:30:00.000Z", transcript: nil, fileSize: 10,
            serverId: serverId, upload: nil, ownerUserId: "u1", environment: "test", attempts: 0, nextAttemptAt: nil)
    }

    func testNotesAndMemosInterleaveBySectionAndDate() {
        let sections = LibraryHomeMapper.rows(
            notes: [note("n1", updated: now - 2 * 3600), note("n2", updated: now - 40 * 86_400)],
            searchIds: nil,
            memos: [memo("m1", recorded: now - 3600), memo("m2", recorded: now - 4 * 86_400)],
            now: now, calendar: chicago)
        XCTAssertEqual(sections.map(\.title), ["Today", "Previous 7 Days", "October"])
        XCTAssertEqual(sections[0].memos.map(\.id), ["m1"]); XCTAssertEqual(sections[0].notes.map(\.id), ["n1"])
        XCTAssertEqual(sections[1].memos.map(\.id), ["m2"]); XCTAssertEqual(sections[2].notes.map(\.id), ["n2"])
    }

    func testPreviewSlotPerStatus() {
        XCTAssertEqual(LibraryHomeMapper.preview(status: .ready, transcriptPreview: "Grace is"), .transcript("Grace is"))
        XCTAssertEqual(LibraryHomeMapper.preview(status: .ready, transcriptPreview: ""), .audioOnly)
        XCTAssertEqual(LibraryHomeMapper.preview(status: .pending, transcriptPreview: nil), .transcribing)
        XCTAssertEqual(LibraryHomeMapper.preview(status: .failed, transcriptPreview: nil), .audioOnly)
        XCTAssertEqual(LibraryHomeMapper.preview(status: .none, transcriptPreview: nil), .audioOnly)
        XCTAssertEqual(LibraryHomeMapper.preview(status: .unknown, transcriptPreview: nil), .audioOnly)
    }

    func testQueuedMemoIsWaitingToUploadAndDeduped() {
        let shown = LibraryHomeMapper.visibleMemos(stored: [summary("m9")], queued: [queued("q1"), queued("q2", serverId: "m9")], searchMatches: nil)
        XCTAssertEqual(shown.map(\.id), ["m9", "local:q1"])
        XCTAssertEqual(shown.last?.preview, .waitingToUpload)
    }

    func testSearchMatchesReplaceStoredAndQueuedMemos() {
        let shown = LibraryHomeMapper.visibleMemos(stored: [summary("m1")], queued: [queued("q1")], searchMatches: [summary("m2", status: "ready", preview: "Grace")])
        XCTAssertEqual(shown.map(\.id), ["m2"])
        XCTAssertEqual(shown.first?.preview, .transcript("Grace"))
    }

    func testDurationsFormatAsMinutesAndHours() {
        XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: 42_000), "0:42")
        XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: 184_000), "3:04")
        XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: 3_725_000), "1:02:05")
        XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: nil), "0:00")
    }

    func testAMemosOnlyListIsPopulated() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [.init(title: "Today", notes: [], memos: [memo("m1", recorded: now)])], query: ""), .list)
    }

    func testStateCarriesMemoRowsAndNoteUpdatedAt() {
        let updated = now - 2 * 3600
        let sections = LibraryHomeMapper.rows(
            notes: [note("n1", updated: updated)], searchIds: nil,
            memos: [memo("m1", recorded: now - 3600, preview: .transcribing), memo("m2", recorded: now - 4 * 86_400)],
            now: now, calendar: chicago)
        let state = LibraryHomeMapper.state(sections: sections, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.sectionTitles, ["Today", "Previous 7 Days"])
        XCTAssertEqual(state.rowSections, [0])
        XCTAssertEqual(state.rowUpdatedAt.map { Int($0.timeIntervalSince1970) }, [Int(updated.timeIntervalSince1970)])
        XCTAssertEqual(state.memos.map(\.id), ["m1", "m2"])
        XCTAssertEqual(state.memos.map(\.section), [0, 1])
        XCTAssertEqual(state.memos.map(\.durationLabel), ["0:42", "0:42"])
        XCTAssertEqual(state.memos.map(\.dateLabel), ["10:00 AM", "Monday"])
        XCTAssertEqual(state.memos.first?.preview, .transcribing)
        XCTAssertEqual(state.memos.first?.recordedAt, now - 3600)
    }

    func testNoResultsAndErrorMapToTheScreensPhases() {
        let args = (now: Date(), calendar: chicago)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .noResults, query: "zzz", now: args.now, calendar: args.calendar).phase, .populated)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .error, query: "", now: args.now, calendar: args.calendar).phase, .loading)
        XCTAssertEqual(LibraryHomeMapper.state(sections: [], phase: .empty, query: "", now: args.now, calendar: args.calendar).phase, .empty)
    }

    func testMemoRowPushesMemoDetail() {
        XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "m1"), .memoDetail(memoId: "m1"))
        XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "local:q1"), .memoDetail(memoId: "local:q1"))
    }
}
