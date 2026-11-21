import SwiftUI

/// memo-screens D4, D8, D13, D17: the pushed memo page — d2m's `MemoDetailScreen` over `MemoDetailModel`.
/// Stops playback on Back and whenever the page leaves the screen.
struct MemoDetailContainer: View {
    private static let skipSeconds: Double = 15

    @State private var model: MemoDetailModel
    @Environment(\.ui2Navigator) private var navigator
    private var state: AppState { AppState.shared }

    init(memoId: String) {
        let actions = MemoActions()
        let player = MemoPlayer(backend: AVMemoPlaybackBackend(), session: MemoPlaybackSession(),
                                fetchDetail: { try await actions.loadMemo(id: $0) })
        _model = State(initialValue: MemoDetailModel(memoId: memoId, actions: actions,
                                                     uploads: AppState.shared.memoUploads, player: player))
    }

    var body: some View {
        MemoDetailScreen(
            state: model.screenState(now: Date(), calendar: .current),
            onBack: back,
            onRename: { title in Task { await model.rename(title) } },
            onDelete: { Task { if await model.delete() { navigator.pop() } } },
            onPlayingChange: { $0 ? model.player.play() : model.player.pause() },
            onSkipBack: { model.player.skip(by: -Self.skipSeconds) },
            onSkipForward: { model.player.skip(by: Self.skipSeconds) },
            onSeek: { model.player.seek(to: $0) },
            onSeekParagraph: model.seekParagraph
        )
        .task { await model.load() }
        // D17: a queued memo's upload finished — the ids in Library change when its server row lands.
        .onChange(of: state.voiceMemos.all.map(\.id)) { _, _ in Task { await model.syncQueued() } }
        .onDisappear { model.stop() }
    }

    private func back() {
        model.stop()
        navigator.pop()
    }
}
