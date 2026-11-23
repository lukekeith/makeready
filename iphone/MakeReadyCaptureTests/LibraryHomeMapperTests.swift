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

    func testRowsAreOneFlatNewestFirstList() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let notes = [StudyNote.stub(id: "b", content: "# Old\nx", title: nil, updatedAt: now.addingTimeInterval(-86_400)),
                     StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60))]
        let rows = LibraryHomeMapper.rows(notes: notes, searchIds: nil, memos: [])
        XCTAssertEqual(rows.notes.map(\.id), ["a", "b"])
        XCTAssertEqual(rows.notes.last?.displayTitle, "Old")
    }

    func testSearchShowsOnlyTheServerMatches() {
        let now = Date()
        let notes = ["a", "b", "c"].map { StudyNote.stub(id: $0, updatedAt: now) }
        XCTAssertEqual(LibraryHomeMapper.rows(notes: notes, searchIds: ["b"], memos: []).notes.map(\.id), ["b"])
    }

    func testPhaseIsEmptyNoResultsOrErrorAsDesigned() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, rows: .init(notes: [], memos: []), query: ""), .empty)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, rows: .init(notes: [], memos: []), query: "zzz"), .noResults)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, rows: .init(notes: [], memos: []), query: ""), .error)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, rows: .init(notes: [.stub(id: "a")], memos: []), query: ""), .list)
    }

    func testLoadingWithNothingCachedIsLoadingAndRowsWin() {
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, rows: .init(notes: [], memos: []), query: ""), .loading)
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: true, loadFailed: false, rows: .init(notes: [.stub(id: "a")], memos: []), query: ""), .list)
    }

    func testStateFlattensRowsAndMapsRowIndexToNoteId() {
        let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
        let notes = [StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60)),
                     StudyNote.stub(id: "b", title: "Old", updatedAt: now.addingTimeInterval(-86_400))]
        let rows = LibraryHomeMapper.rows(notes: notes, searchIds: nil, memos: [])
        let state = LibraryHomeMapper.state(rows: rows, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.phase, .populated)
        XCTAssertEqual(state.rowTitles, ["Walk", "Old"])
        XCTAssertEqual(state.rowPreviews, ["Psalm", ""])
        XCTAssertEqual(state.rowContexts, ["Youth", ""])
        XCTAssertEqual(LibraryHomeMapper.noteIds(in: rows), ["a", "b"])
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

    func testNotesAndMemosAreEachNewestFirstWithNoSections() {
        let rows = LibraryHomeMapper.rows(
            notes: [note("n2", updated: now - 40 * 86_400), note("n1", updated: now - 2 * 3600)],
            searchIds: nil,
            memos: [memo("m2", recorded: now - 4 * 86_400), memo("m1", recorded: now - 3600)])
        XCTAssertEqual(rows.notes.map(\.id), ["n1", "n2"])
        XCTAssertEqual(rows.memos.map(\.id), ["m1", "m2"])
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
        XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, rows: .init(notes: [], memos: [memo("m1", recorded: now)]), query: ""), .list)
    }

    func testStateCarriesMemoRowsAndNoteUpdatedAt() {
        let updated = now - 2 * 3600
        let rows = LibraryHomeMapper.rows(
            notes: [note("n1", updated: updated)], searchIds: nil,
            memos: [memo("m1", recorded: now - 3600, preview: .transcribing), memo("m2", recorded: now - 4 * 86_400)])
        let state = LibraryHomeMapper.state(rows: rows, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.rowUpdatedAt.map { Int($0.timeIntervalSince1970) }, [Int(updated.timeIntervalSince1970)])
        XCTAssertEqual(state.memos.map(\.id), ["m1", "m2"])
        XCTAssertEqual(state.memos.map(\.durationLabel), ["0:42", "0:42"])
        XCTAssertEqual(state.memos.map(\.dateLabel), ["10:00 AM", "Monday"])
        XCTAssertEqual(state.memos.first?.preview, .transcribing)
        XCTAssertEqual(state.memos.first?.recordedAt, now - 3600)
    }

    func testNoResultsAndErrorMapToTheScreensPhases() {
        let args = (now: Date(), calendar: chicago)
        XCTAssertEqual(LibraryHomeMapper.state(rows: .init(notes: [], memos: []), phase: .noResults, query: "zzz", now: args.now, calendar: args.calendar).phase, .populated)
        XCTAssertEqual(LibraryHomeMapper.state(rows: .init(notes: [], memos: []), phase: .error, query: "", now: args.now, calendar: args.calendar).phase, .loading)
        XCTAssertEqual(LibraryHomeMapper.state(rows: .init(notes: [], memos: []), phase: .empty, query: "", now: args.now, calendar: args.calendar).phase, .empty)
    }

    func testMemoRowPushesMemoDetail() {
        XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "m1"), .memoDetail(memoId: "m1"))
        XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "local:q1"), .memoDetail(memoId: "local:q1"))
    }

    // MARK: - Videos (D15, D20, D27)

    private func videoSummary(_ id: String = "v1", status: String = "ready", transcriptStatus: String = "ready",
                              preview: String? = nil, created: String = "2026-11-20T16:00:00.000Z") -> VideoSummary {
        let previewJSON = preview.map { "\"" + $0.replacingOccurrences(of: "\n", with: "\\n") + "\"" } ?? "null"
        let json = #"{"id":"\#(id)","title":"Video \#(id)","thumbnailUrl":null,"playbackUrl":"https://x/\#(id).m3u8","duration":45,"status":"\#(status)","transcriptStatus":"\#(transcriptStatus)","transcriptPreview":\#(previewJSON),"createdAt":"\#(created)"}"#
        return try! JSONDecoder.apiDecoder.decode(VideoSummary.self, from: Data(json.utf8))
    }

    private func queuedVideo(localId: String, serverId: String? = nil) -> VideoQueueItem {
        VideoQueueItem(
            localId: localId, fileName: "\(localId).mp4", posterFileName: nil, title: "Queued \(localId)", durationSeconds: 12,
            source: .recording, transcript: nil, createdAt: now, streamUid: nil, serverId: serverId, stage: .queued,
            failures: 0, polls: 0, nextAttemptAt: nil, attach: nil, ownerUserId: "u1", environment: "test")
    }

    private func video(daysAgo: Int) -> LibraryHomeMapper.VideoSource {
        .init(id: "video\(daysAgo)", title: "Video", durationMs: 45_000,
              recordedAt: now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)), state: .queued)
    }

    private func note(daysAgo: Int) -> StudyNote {
        .stub(id: "note\(daysAgo)", updatedAt: now.addingTimeInterval(TimeInterval(-daysAgo * 86_400)))
    }

    func testVideoLine2() {
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.queued), "Uploading…")
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.created), "Processing…")
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(videoSummary(status: "pending", transcriptStatus: "pending"))), "Processing…")
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(videoSummary(status: "ready", transcriptStatus: "pending"))), "Transcribing…")
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(videoSummary(status: "ready", transcriptStatus: "ready", preview: "Hello there\nsecond"))), "Hello there")
        XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(videoSummary(status: "ready", transcriptStatus: "failed"))), "")
    }

    func testHoldBack() {
        let videos = [video(daysAgo: 0), video(daysAgo: 5)]
        let rows = LibraryHomeMapper.rows(notes: [note(daysAgo: 1), note(daysAgo: 9)], searchIds: nil, memos: [], videos: videos, videosHaveMore: true)
        XCTAssertEqual(rows.ids.count, 3)
        XCTAssertFalse(rows.ids.contains(note(daysAgo: 9).id))
        let all = LibraryHomeMapper.rows(notes: [note(daysAgo: 1), note(daysAgo: 9)], searchIds: nil, memos: [], videos: videos, videosHaveMore: false)
        XCTAssertEqual(all.ids.count, 4)
    }

    func testHoldBackAlsoHoldsOlderMemos() {
        let rows = LibraryHomeMapper.rows(
            notes: [], searchIds: nil,
            memos: [memo("new", recorded: now.addingTimeInterval(-86_400)), memo("old", recorded: now.addingTimeInterval(-9 * 86_400))],
            videos: [video(daysAgo: 5)], videosHaveMore: true)
        XCTAssertEqual(rows.memos.map(\.id), ["new"])
    }

    func testLocalRowMerge() {
        let q = queuedVideo(localId: "L1", serverId: "v9")
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [], queued: [q]).map(\.id), ["local:L1"])
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [videoSummary("v9")], queued: [q]).map(\.id), ["v9"])
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [], queued: [q]).first?.state, .created)
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [], queued: [queuedVideo(localId: "L2")]).first?.state, .queued)
    }

    /// D12: a video being exported shows at once, as the queued row it becomes.
    func testAVideoBeingSavedIsAnUploadingRowUntilTheQueueHoldsIt() {
        let saving = VideoSavingItem(localId: "L1", title: "Video 3", durationSeconds: 45, savedAt: now, attach: nil)
        let rows = LibraryHomeMapper.visibleVideos(stored: [videoSummary("v9")], queued: [], saving: [saving])
        XCTAssertEqual(rows.map(\.id), ["v9", "local:L1"])
        XCTAssertEqual(rows.last?.title, "Video 3")
        XCTAssertEqual(rows.last?.durationMs, 45_000)
        XCTAssertEqual(rows.last.map { LibraryHomeMapper.videoLine2($0.state) }, "Uploading…")
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [], queued: [queuedVideo(localId: "L1")], saving: [saving]).map(\.id), ["local:L1"])
        // Already on the server: neither local row returns.
        XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [videoSummary("v9")], queued: [queuedVideo(localId: "L1", serverId: "v9")],
                                                       saving: [saving]).map(\.id), ["v9"])
    }

    func testTypeFilter() {
        XCTAssertEqual(LibraryHomeMapper.kinds(checked: [.video]), [.video])
        XCTAssertEqual(LibraryHomeMapper.kinds(checked: []), [.note, .memo, .video])
        XCTAssertEqual(LibraryHomeMapper.kinds(checked: [.note, .memo, .video]), [.note, .memo, .video])
    }

    func testStateCarriesVideoRowsWithTheMemoLine1Rule() {
        let source = LibraryHomeMapper.VideoSource(id: "v1", title: "Video 1", durationMs: 45_000, recordedAt: now,
                                                   state: .stored(videoSummary(preview: "Hello")))
        let rows = LibraryHomeMapper.rows(notes: [], searchIds: nil, memos: [], videos: [source], videosHaveMore: false)
        XCTAssertFalse(rows.isEmpty)
        let state = LibraryHomeMapper.state(rows: rows, phase: .list, query: "", now: now, calendar: chicago)
        XCTAssertEqual(state.videos.map(\.id), ["v1"])
        XCTAssertEqual(state.videos.first?.durationLabel, "0:45")
        XCTAssertEqual(state.videos.first?.dateLabel, NotesSectioning.dateLabel(now, now: now, calendar: chicago))
        guard case .transcript("Hello")? = state.videos.first?.preview else { return XCTFail("expected the transcript line") }
    }
}
