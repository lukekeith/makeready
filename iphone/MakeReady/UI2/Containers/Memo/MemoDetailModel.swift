import Foundation

/// memo-screens D4, D8, D13, D17: one open memo — a stored one (`.server`) or one still in the upload queue
/// (`.local`). Loads it, hands its audio to `MemoPlayer`, renames and deletes it, and turns it into
/// `MemoDetailScreen.State` through `MemoDetailMapper`.
@MainActor @Observable
final class MemoDetailModel {
    enum Target: Equatable {
        case server(String)
        case local(String)
    }

    /// D8: the server's title limit.
    static let titleLimit = 120
    private static let localPrefix = "local:"

    /// Where the memo is now. A `.local` page becomes `.server` once its upload completes (D17).
    private(set) var target: Target
    let player: MemoPlayer

    private var memo: VoiceMemo?
    private var queued: MemoQueueItem?
    private let actions: MemoActions
    private let uploads: MemoUploadController?
    private let state: AppState

    init(memoId: String, actions: MemoActions, uploads: MemoUploadController?, player: MemoPlayer, state: AppState? = nil) {
        let state = state ?? AppState.shared
        let target = Self.target(memoId)
        self.target = target
        self.actions = actions
        self.uploads = uploads
        self.player = player
        self.state = state
        if case .server(let id) = target { memo = state.voiceMemoDetails[id] }
    }

    /// A route id: `local:<localId>` is a queued memo, anything else a server id (D17).
    static func target(_ memoId: String) -> Target {
        memoId.hasPrefix(localPrefix) ? .local(String(memoId.dropFirst(localPrefix.count))) : .server(memoId)
    }

    // MARK: - Loading

    func load() async {
        switch target {
        case .server(let id): await loadServer(id)
        case .local(let localId): await loadLocal(localId)
        }
    }

    /// D17: once the queue has a server id for this page's memo, show the server memo in place.
    func syncQueued() async {
        guard case .local(let localId) = target, let serverId = uploads?.serverId(forLocalId: localId) else { return }
        target = .server(serverId)
        queued = nil
        await loadServer(serverId)
    }

    private func loadServer(_ id: String) async {
        do {
            let loaded = try await actions.loadMemo(id: id)
            guard target == .server(id) else { return }  // the page moved on while this was in flight
            memo = loaded
            await player.load(.remote(loaded))
        } catch {
            state.recordError(error, context: "MemoDetailModel.load", surface: true,
                              friendlyMessage: "Couldn't load this memo", retry: { [weak self] in
                                  Task { await self?.load() }
                              })
        }
    }

    private func loadLocal(_ localId: String) async {
        guard let uploads, let item = uploads.item(localId: localId) else {
            // The upload may have finished since the page was pushed.
            await syncQueued()
            return
        }
        queued = item
        await player.load(.local(url: uploads.fileURL(for: item), durationMs: item.durationMs))
    }

    // MARK: - Rename and delete

    /// D8: an empty title is ignored (the screen reverts it); a long one is cut to 120.
    func rename(_ title: String) async {
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.titleLimit))
        guard !trimmed.isEmpty else { return }
        do {
            switch target {
            case .server(let id):
                try await actions.rename(id: id, title: trimmed)
                memo?.title = trimmed
            case .local(let localId):
                guard let uploads else { throw CancellationError() }
                try await uploads.rename(localId: localId, title: trimmed)
                queued = uploads.item(localId: localId) ?? queued
            }
        } catch {
            state.recordError(error, context: "MemoDetailModel.rename", surface: true, friendlyMessage: "Couldn't rename this memo")
        }
    }

    /// D8, D17: true means the page should pop.
    func delete() async -> Bool {
        do {
            switch target {
            case .server(let id):
                try await actions.softDelete(id: id)
            case .local(let localId):
                guard let uploads else { throw CancellationError() }
                try await uploads.remove(localId: localId)
            }
        } catch {
            state.recordError(error, context: "MemoDetailModel.delete", surface: true, friendlyMessage: "Couldn't delete this memo")
            return false
        }
        player.stop()
        return true
    }

    // MARK: - Playback

    /// D4: seek to the paragraph's start and play.
    func seekParagraph(_ index: Int) {
        let starts = screenState(now: Date(), calendar: .current).paragraphStarts
        guard starts.indices.contains(index) else { return }
        player.seek(to: starts[index])
        player.play()
    }

    /// D13: leaving the page stops playback and gives the audio session back.
    func stop() {
        player.stop()
    }

    // MARK: - Screen

    func screenState(now: Date, calendar: Calendar) -> MemoDetailScreen.State {
        let elapsed = player.elapsed, playing = player.isPlaying, ready = player.isReady
        if let memo {
            return MemoDetailMapper.state(memo: memo, elapsed: elapsed, playing: playing, playerReady: ready, now: now, calendar: calendar)
        }
        if let queued {
            return MemoDetailMapper.state(queued: queued, elapsed: elapsed, playing: playing, playerReady: ready, now: now, calendar: calendar)
        }
        return loadingState(now: now, calendar: calendar)
    }

    /// Before the memo is loaded: the Library row's title and length when it is cached, a disabled player.
    private func loadingState(now: Date, calendar: Calendar) -> MemoDetailScreen.State {
        var summary: VoiceMemoSummary?
        if case .server(let id) = target { summary = state.voiceMemos[id] }
        var loading = MemoDetailScreen.State(
            title: summary?.title ?? "",
            dateLabel: summary.map { MemoDetailMapper.metaDate($0.recordedAt, now: now, calendar: calendar) } ?? "",
            duration: Double(summary?.durationMs ?? 0) / 1000, playerReady: false)
        loading.transcript = .transcribing
        return loading
    }
}
