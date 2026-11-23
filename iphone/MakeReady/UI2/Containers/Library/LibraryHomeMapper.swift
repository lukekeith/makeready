import Foundation

/// notes D3/D8/D20, memo-screens D5: `AppState.studyNotes` and the memos → library-home's merged list. Pure: the clock and calendar
/// come in, so a capture or a test does not depend on the day it runs.
enum LibraryHomeMapper {

    /// What the screen should be showing. d2m's screen has no error phase (library-home §5), so the
    /// container keeps `.error` on `.loading` and surfaces the failure through the error channel.
    enum Phase: Equatable {
        case loading, error, empty, noResults, list
    }

    /// One voice memo as Library shows it: a stored summary or a queued upload (D5, D17).
    struct MemoSource: Equatable {
        let id: String
        let title: String
        let durationMs: Int?
        let recordedAt: Date
        let preview: MemoListRow.Preview
    }

    /// One video as Library shows it: a stored summary or a queued upload (D15, D27).
    struct VideoSource: Equatable {
        /// What decides the row's second line.
        enum State: Equatable {
            /// In the queue, not yet created on the server.
            case queued
            /// In the queue, created on the server but not yet in the Library window.
            case created
            case stored(VideoSummary)
        }

        let id: String
        let title: String
        let durationMs: Int?
        let recordedAt: Date
        let state: State
    }

    /// library-home §2 item 4: the one flat list's rows, all three kinds, each already newest first
    /// (the screen interleaves them by date). No date sections.
    struct LibraryRows: Equatable {
        let notes: [StudyNote]
        let memos: [MemoSource]
        var videos: [VideoSource] = []
        var isEmpty: Bool { notes.isEmpty && memos.isEmpty && videos.isEmpty }
        /// Every row's id, notes first, then memos, then videos.
        var ids: [String] { notes.map(\.id) + memos.map(\.id) + videos.map(\.id) }
    }

    static func memoSource(summary: VoiceMemoSummary) -> MemoSource {
        MemoSource(id: summary.id, title: summary.title, durationMs: summary.durationMs, recordedAt: summary.recordedAt,
                   preview: preview(status: summary.transcriptStatus, transcriptPreview: summary.transcriptPreview))
    }

    /// A queued memo has no server id yet, so its id is `local:` + `localId` (D17).
    static func memoSource(queued: MemoQueueItem) -> MemoSource {
        MemoSource(id: "local:" + queued.localId, title: queued.title, durationMs: queued.durationMs,
                   recordedAt: NoteTimestamp.parse(queued.recordedAt) ?? .distantPast, preview: .waitingToUpload)
    }

    /// D5, D16: the preview slot. `unknown` reads as `none`; a ready memo with no text has nothing to show.
    static func preview(status: MemoTranscriptStatus, transcriptPreview: String?) -> MemoListRow.Preview {
        switch status {
        case .ready:
            if let transcriptPreview, !transcriptPreview.isEmpty { return .transcript(transcriptPreview) }
            return .audioOnly
        case .pending: return .transcribing
        case .failed, .none, .unknown: return .audioOnly
        }
    }

    /// `m:ss` under an hour, `h:mm:ss` from an hour; no duration reads `0:00`.
    static func durationLabel(ms: Int?) -> String {
        let total = max(ms ?? 0, 0) / 1000
        let (hours, minutes, seconds) = (total / 3600, total % 3600 / 60, total % 60)
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// D5, D17: with no search, the stored memos plus the queue (minus a queued item the server already
    /// has); with a search, only its matches — a queued memo has no server transcript to match.
    static func visibleMemos(stored: [VoiceMemoSummary], queued: [MemoQueueItem], searchMatches: [VoiceMemoSummary]?)
        -> [MemoSource] {
        if let searchMatches { return searchMatches.map { memoSource(summary: $0) } }
        let storedIds = Set(stored.map(\.id))
        let waiting = queued.filter { item in item.serverId.map { !storedIds.contains($0) } ?? true }
        return stored.map { memoSource(summary: $0) } + waiting.map { memoSource(queued: $0) }
    }

    /// A stored video as a row source.
    static func videoSource(summary: VideoSummary) -> VideoSource {
        VideoSource(id: summary.id, title: summary.title ?? "", durationMs: summary.duration.map { $0 * 1000 },
                    recordedAt: summary.createdAt, state: .stored(summary))
    }

    /// A queued video has no listed server row yet, so its id is `local:` + `localId` (D27).
    static func videoSource(queued: VideoQueueItem) -> VideoSource {
        VideoSource(id: LibraryVideoDeletion.localPrefix + queued.localId, title: queued.title, durationMs: Int(queued.durationSeconds * 1000),
                    recordedAt: queued.createdAt, state: queued.isOnServer ? .created : .queued)
    }

    /// D12: a video still being saved is the queued row it becomes.
    static func videoSource(saving item: VideoSavingItem) -> VideoSource {
        VideoSource(id: LibraryVideoDeletion.localPrefix + item.localId, title: item.title,
                    durationMs: Int(item.durationSeconds * 1000), recordedAt: item.savedAt, state: .queued)
    }

    /// D27: the stored window plus the queue, minus a queued item whose `serverId` the store already lists;
    /// plus the videos being saved, until the queue holds them (D12).
    static func visibleVideos(stored: [VideoSummary], queued: [VideoQueueItem], saving: [VideoSavingItem] = []) -> [VideoSource] {
        let storedIds = Set(stored.map(\.id))
        let waiting = queued.filter { item in item.serverId.map { !storedIds.contains($0) } ?? true }
        let queuedIds = Set(queued.map(\.localId))
        return stored.map { videoSource(summary: $0) } + waiting.map { videoSource(queued: $0) }
            + saving.filter { !queuedIds.contains($0.localId) }.map { videoSource(saving: $0) }
    }

    /// D15: the second line, in this order: not yet created, still processing, transcribing, the
    /// transcript's first line, else nothing.
    static func videoLine2(_ state: VideoSource.State) -> String {
        guard case .stored(let video) = state else { return state == .queued ? "Uploading…" : "Processing…" }
        if video.videoStatus == .pending { return "Processing…" }
        if video.transcriptStatus == .pending { return "Transcribing…" }
        if video.transcriptStatus == .ready, let preview = video.transcriptPreview {
            return preview.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        }
        return ""
    }

    /// The screen's preview slot for a video's second line.
    private static func videoPreview(_ state: VideoSource.State) -> LibraryHomeScreen.State.VideoRowInput.Preview {
        switch state {
        case .queued: return .uploading
        case .created: return .processing
        case .stored(let video):
            if video.videoStatus == .pending { return .processing }
            if video.transcriptStatus == .pending { return .transcribing }
            return .transcript(videoLine2(state))
        }
    }

    /// D15: the kinds the Type menu's checks show: nothing or all three checked is every kind.
    static func kinds(checked: Set<LibraryItemType>) -> [LibraryItemType] {
        LibraryItemType.menuOptions.filter { LibraryItemType.shows($0, in: checked) }
    }

    /// D3, D5, library-home §2 item 4: notes, memos and videos for the one flat list. `searchIds` is the
    /// server's note match list for the current `q` (D8): nil shows every note, else only those ids
    /// (no client-side corpus search). Notes sort by `updatedAt`, memos and videos by `recordedAt`, newest first.
    /// D20: while `videosHaveMore`, notes and memos older than the oldest loaded video are held back, so
    /// rows never jump when the next page of videos lands.
    static func rows(notes: [StudyNote], searchIds: [String]?, memos: [MemoSource],
                     videos: [VideoSource] = [], videosHaveMore: Bool = false) -> LibraryRows {
        let shownNotes: [StudyNote]
        if let searchIds {
            let wanted = Set(searchIds)
            shownNotes = notes.filter { wanted.contains($0.id) }
        } else {
            shownNotes = notes
        }
        var sortedMemos = memos.sorted { lhs, rhs in
            lhs.recordedAt != rhs.recordedAt ? lhs.recordedAt > rhs.recordedAt : lhs.id > rhs.id
        }
        let sortedVideos = videos.sorted { lhs, rhs in
            lhs.recordedAt != rhs.recordedAt ? lhs.recordedAt > rhs.recordedAt : lhs.id > rhs.id
        }
        var sortedNotes = NotesSectioning.newestFirst(shownNotes)
        if videosHaveMore, let oldest = sortedVideos.last?.recordedAt {
            sortedNotes = sortedNotes.filter { ($0.updatedDate ?? .distantPast) >= oldest }
            sortedMemos = sortedMemos.filter { $0.recordedAt >= oldest }
        }
        return LibraryRows(notes: sortedNotes, memos: sortedMemos, videos: sortedVideos)
    }

    /// D20: rows (notes or memos) win over every other state (a failed refresh keeps the cached list);
    /// with no rows, a fetch in flight is loading, a failure is an error, a query is no-results, else empty.
    static func phase(isLoading: Bool, loadFailed: Bool, rows: LibraryRows, query: String) -> Phase {
        if !rows.isEmpty { return .list }
        if loadFailed { return .error }
        if isLoading { return .loading }
        return query.trimmingCharacters(in: .whitespaces).isEmpty ? .empty : .noResults
    }

    /// The screen's props for the rows (parallel arrays; `onOpenNote` gives a row index into
    /// `rowTitles`, which `noteIds(in:)` maps back to a note id; memo rows carry their own id).
    static func state(rows: LibraryRows, phase: Phase, query: String, now: Date, calendar: Calendar)
        -> LibraryHomeScreen.State {
        var state = LibraryHomeScreen.State(phase: screenPhase(phase), searchText: query)
        for note in rows.notes {
            state.rowTitles.append(note.displayTitle)
            state.rowDates.append(note.updatedDate.map {
                NotesSectioning.dateLabel($0, now: now, calendar: calendar)
            } ?? "")
            state.rowPreviews.append(note.preview ?? "")
            state.rowContexts.append(note.contextLabel ?? "")
            state.rowUpdatedAt.append(note.updatedDate ?? .distantPast)
        }
        state.memos = rows.memos.map { memo in
            .init(id: memo.id, title: memo.title, durationLabel: durationLabel(ms: memo.durationMs),
                  dateLabel: NotesSectioning.dateLabel(memo.recordedAt, now: now, calendar: calendar),
                  recordedAt: memo.recordedAt, preview: memo.preview)
        }
        state.videos = rows.videos.map { video in
            .init(id: video.id, title: video.title, durationLabel: durationLabel(ms: video.durationMs),
                  dateLabel: NotesSectioning.dateLabel(video.recordedAt, now: now, calendar: calendar),
                  recordedAt: video.recordedAt, preview: videoPreview(video.state))
        }
        return state
    }

    /// Row order of `state(rows:…)`: the note ids, one per note row.
    static func noteIds(in rows: LibraryRows) -> [String] {
        rows.notes.map(\.id)
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

/// `MemoListRow.Preview` carries no `Equatable` (the d2m view is not edited here), so the mapper's
/// value types and its tests compare slots through this.
extension MemoListRow.Preview: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.transcript(a), .transcript(b)): return a == b
        case (.transcribing, .transcribing), (.audioOnly, .audioOnly), (.waitingToUpload, .waitingToUpload): return true
        default: return false
        }
    }
}
