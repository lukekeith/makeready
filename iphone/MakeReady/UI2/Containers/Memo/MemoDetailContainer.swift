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
        let screen = model.screenState(now: Date(), calendar: .current)
        // A ZStack scopes the `.id` below to the screen alone: the page's load, sync and stop modifiers
        // keep their identity when the screen is rebuilt.
        ZStack {
            MemoDetailScreen(
                state: screen,
                onBack: back,
                onRename: { title in Task { await model.rename(title) } },
                onDelete: { Task { if await model.delete() { navigator.pop() } } },
                onPlayingChange: { $0 ? model.player.play() : model.player.pause() },
                onSkipBack: { model.player.skip(by: -Self.skipSeconds) },
                onSkipForward: { model.player.skip(by: Self.skipSeconds) },
                onSeek: { model.player.seek(to: $0) },
                onSeekParagraph: model.seekParagraph
            )
            // The screen copies its title into the rename field once; a page that opened before its title was
            // known (nothing cached) is rebuilt when the title arrives. A title never goes back to empty (D8).
            .id(screen.title.isEmpty)
        }
        .task { await model.load() }
        // D17: a queued memo's upload finished — it leaves the queue. (Library's ids are not the signal:
        // a list refresh can bring the server row in while the audio is still uploading.)
        .onChange(of: state.memoUploads?.pendingItems.map(\.localId) ?? []) { _, _ in Task { await model.syncQueued() } }
        .onDisappear { model.stop() }
    }

    private func back() {
        model.stop()
        navigator.pop()
    }
}
