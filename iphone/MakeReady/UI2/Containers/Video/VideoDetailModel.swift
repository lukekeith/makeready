import Foundation

/// video-recorder D14, D16, D17: one open Library video. Loads it, hands its HLS stream to the player, renames
/// and deletes (or removes) it, and turns it into `VideoDetailScreen.State`. Reads the video from
/// `AppState.videos`, so a rename or a refresh shows without this model copying anything.
@MainActor @Observable
final class VideoDetailModel {
    /// D14: the server's title limit.
    static let titleLimit = 120

    let id: String
    let player: VideoPlaying

    private let actions: VideoActions
    private let state: AppState
    private var loadedStream: URL?

    init(id: String, actions: VideoActions, player: VideoPlaying, state: AppState? = nil) {
        self.id = id
        self.actions = actions
        self.player = player
        self.state = state ?? AppState.shared
    }

    /// The stored video, when there is one.
    private var video: Video? { state.videos[id] }

    // MARK: - Loading

    /// Cache-first: the page renders from what is stored while this refreshes it. The stream loads once the
    /// video is `ready`.
    func load() async {
        do {
            try await actions.loadDetail(id: id)
        } catch {
            state.recordError(error, context: "VideoDetailModel.load", surface: true,
                              friendlyMessage: "Couldn't load this video", retry: { [weak self] in
                                  Task { await self?.load() }
                              })
        }
        loadStream()
    }

    private func loadStream() {
        guard let video, video.videoStatus == .ready, let url = URL(string: video.playbackUrl),
              url != loadedStream else { return }
        loadedStream = url
        player.load(url: url, duration: Double(video.duration ?? 0))
    }

    // MARK: - Rename and delete

    /// D14: the title is trimmed and cut to 120; an empty one is not sent (the screen reverts it).
    func rename(to title: String) async {
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit))
        guard !trimmed.isEmpty else { return }
        do {
            try await actions.rename(id: id, title: trimmed)
        } catch {
            state.recordError(error, context: "VideoDetailModel.rename", surface: true,
                              friendlyMessage: "Couldn't rename this video")
        }
    }

    /// D17, after the screen's own confirm: a video no lesson uses is deleted, one that lessons use leaves the
    /// Library and stays in them. True means the page should pop.
    func requestDelete() async -> Bool {
        let count = video?.lessonUseCount ?? 0
        let decision: VideoDeleteDecision = count > 0 ? .removeFromLibrary(lessonCount: count) : .delete
        do {
            try await actions.deleteOrRemove(id: id, decision: decision)
        } catch {
            state.recordError(error, context: "VideoDetailModel.delete", surface: true,
                              friendlyMessage: count > 0 ? "Couldn't remove this video from your Library"
                                                         : "Couldn't delete this video",
                              retry: { [weak self] in
                                  Task { await self?.requestDelete() }
                              })
            return false
        }
        player.stop()
        return true
    }

    // MARK: - Playback

    /// Seek to the paragraph's start and play.
    func seekParagraph(_ index: Int) {
        let starts = screenState(now: Date(), calendar: .current).paragraphStarts
        guard starts.indices.contains(index) else { return }
        player.seek(to: starts[index])
        player.play()
    }

    /// Leaving the page stops playback and gives the audio session back.
    func stop() {
        player.stop()
    }

    // MARK: - Screen

    func screenState(now: Date, calendar: Calendar) -> VideoDetailScreen.State {
        guard let video else { return loadingState(now: now, calendar: calendar) }
        return Self.screenState(video: video, elapsed: player.elapsed, playing: player.isPlaying,
                                playerReady: player.isReady, now: now, calendar: calendar)
    }

    /// D16: `ready` reads its segments, or its whole transcript as one paragraph; `pending` is transcribing;
    /// `failed`, `none` and an unknown status have no transcript to show.
    static func screenState(video: Video, elapsed: Double, playing: Bool, playerReady: Bool,
                            now: Date, calendar: Calendar) -> VideoDetailScreen.State {
        var state = VideoDetailScreen.State(
            title: video.displayTitle,
            dateLabel: MemoDetailMapper.metaDate(video.createdAt, now: now, calendar: calendar),
            duration: Double(video.duration ?? 0), thumbnailURL: video.thumbnailUrl ?? "",
            status: status(video), elapsed: elapsed, playing: playing, playerReady: playerReady,
            lessonUseCount: video.lessonUseCount ?? 0)
        switch video.transcriptStatus {
        case .ready:
            let segments = video.transcriptSegments ?? []
            if !segments.isEmpty {
                state.transcript = .paragraphs
                state.paragraphStarts = segments.map { Double($0.startMs / 1000) }
                state.paragraphTexts = segments.map(\.text)
            } else if let text = video.transcript, !text.isEmpty {
                state.transcript = .paragraphs
                (state.paragraphStarts, state.paragraphTexts) = ([0], [text])
            } else {
                state.transcript = .unavailable
            }
        case .pending:
            state.transcript = .transcribing
        case .failed, .some(.none), nil:
            state.transcript = .unavailable
        }
        return state
    }

    /// D16: the transcript, or its state: "Transcribing…" while the video is ready and its transcript is not,
    /// "Processing…" while the video itself is still processing, nil when there is none.
    static func transcriptText(_ video: Video) -> String? {
        switch video.transcriptStatus {
        case .ready:
            guard let text = video.transcript, !text.isEmpty else { return nil }
            return text
        case .pending:
            return video.videoStatus == .ready ? "Transcribing…" : "Processing…"
        case .failed, .some(.none), nil:
            return nil
        }
    }

    private static func status(_ video: Video) -> VideoDetailScreen.State.Status {
        switch video.videoStatus {
        case .ready: return .ready
        case .pending: return .processing
        case .error: return .error
        }
    }

    /// Before the video is stored: the Library row's title and length when it is cached, a disabled player.
    private func loadingState(now: Date, calendar: Calendar) -> VideoDetailScreen.State {
        let summary = state.libraryVideos[id]
        var loading = VideoDetailScreen.State(
            title: summary?.title ?? "",
            dateLabel: summary.map { MemoDetailMapper.metaDate($0.createdAt, now: now, calendar: calendar) } ?? "",
            duration: Double(summary?.duration ?? 0), thumbnailURL: summary?.thumbnailUrl ?? "", playerReady: false)
        loading.transcript = .transcribing
        return loading
    }
}
