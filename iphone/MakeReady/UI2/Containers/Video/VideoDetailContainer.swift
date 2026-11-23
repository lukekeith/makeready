import SwiftUI

/// video-recorder D16, D17: the pushed video page — d2m's `VideoDetailScreen` over `VideoDetailModel`.
/// Stops playback on Back and whenever the page leaves the screen.
struct VideoDetailContainer: View {
    private static let skipSeconds: Double = 15

    @State private var model: VideoDetailModel
    @Environment(\.ui2Navigator) private var navigator

    init(videoId: String) {
        _model = State(initialValue: VideoDetailModel(id: videoId, actions: VideoActions(), player: AVVideoPlayer()))
    }

    var body: some View {
        let screen = model.screenState(now: Date(), calendar: .current)
        // A ZStack scopes the `.id` below to the screen alone: the page's load and stop modifiers keep their
        // identity when the screen is rebuilt.
        ZStack {
            VideoDetailScreen(
                state: screen,
                onBack: back,
                onRename: { title in Task { await model.rename(to: title) } },
                onDelete: remove,
                onRemoveFromLibrary: remove,
                onPlayingChange: { $0 ? model.player.play() : model.player.pause() },
                onSkipBack: { model.player.skip(by: -Self.skipSeconds) },
                onSkipForward: { model.player.skip(by: Self.skipSeconds) },
                onSeek: { model.player.seek(to: $0) },
                onSeekParagraph: model.seekParagraph,
                playerLayer: model.player.layer
            )
            // The screen copies its title into the rename field once: a page that opened before its title was
            // known (nothing cached) is rebuilt when the title arrives.
            .id(screen.title.isEmpty)
        }
        .task { await model.load() }
        .onDisappear { model.stop() }
    }

    /// The screen has already confirmed (D17); the model picks delete or remove from the use count it showed.
    private func remove() {
        Task { if await model.requestDelete() { navigator.pop() } }
    }

    private func back() {
        model.stop()
        navigator.pop()
    }
}
