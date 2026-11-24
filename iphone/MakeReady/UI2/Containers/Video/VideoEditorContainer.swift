//
//  VideoEditorContainer.swift
//  MakeReady
//
//  video-editor D29: hosts d2m's `VideoEditorScreen` over a `VideoEditorModel`. It slides itself in and
//  out on `sheetPresent` (a hosted overlay gets no presenting transaction); its confirms and text tool
//  are the screen's own, drawn in place. No `.sheet`, no `.fullScreenCover`.
//

import SwiftUI
import UIKit

struct VideoEditorContainer: View {
    let model: VideoEditorModel
    /// Called once the editor has slid out; the host drops it then.
    var onEnd: () -> Void = {}

    @State private var shown = false
    @State private var frames: [Int: Image] = [:]

    private static let frameCount = 12
    private static let placeholder = Image(uiImage: UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image {
        UIColor(Token.layoutBackground).setFill()
        $0.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    })

    private var session: VideoEditSession { model.session }

    var body: some View {
        screen
            .background(Token.layoutBackground.ignoresSafeArea())
            // An offset on the effect layer, not the layout: keyboard avoidance measures un-offset chrome.
            .visualEffect { [shown] effect, proxy in
                effect.offset(y: shown ? 0 : proxy.frame(in: .global).maxY)
            }
            .allowsHitTesting(!model.isClosed)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { model.cancelTapped() }
            .onAppear {
                withAnimation(Token.Motion.sheetPresent) { shown = true }
            }
            .onChange(of: model.isClosed) { _, closed in
                guard closed else { return }
                withAnimation(Token.Motion.sheetPresent) {
                    shown = false
                } completion: {
                    onEnd()
                }
            }
            .task { await readFrames() }
            .task(id: model.isPlaying) { await follow() }
    }

    private var screen: some View {
        VideoEditorScreen(
            state: VideoEditorMapper.state(of: model, filmstrip: []),
            feed: model.playerLayer,
            filmstripImages: filmstrip,
            onCancel: model.cancelTapped,
            onUndo: session.undo,
            onDone: model.doneTapped,
            onPlayPause: model.playTapped,
            onScrub: model.scrub(toMs:),
            onSelect: { id in session.select(UUID(uuidString: id)) },
            onDeselect: { session.select(nil) },
            onText: model.textTapped,
            onCaptions: model.captionsTapped,
            onRemoveCaptions: model.removeCaptionsConfirmed,
            onSplit: session.split,
            onEdit: { id in
                session.select(UUID(uuidString: id))
                model.editTapped()
            },
            onDelete: { id in
                guard let id = UUID(uuidString: id) else { return }
                session.delete(id)
            },
            onTrimStart: { id, ms in change(id) { session.trimStart($0, to: ms) } },
            onTrimEnd: { id, ms in change(id) { session.trimEnd($0, to: ms) } },
            onSlide: { id, ms in change(id) { session.slide($0, to: ms) } },
            onPlace: { id, centre, scale, rotation in
                change(id) { session.place($0, centre: centre, scale: scale, rotation: rotation) }
            },
            onGestureEnded: model.gestureEnded,
            onTextCommit: { text, style in model.commitText(text, style: VideoEditorMapper.style(style)) },
            onTextCancel: model.textCancelled,
            onConfirmCancel: model.cancelConfirmed,
            onDismissConfirm: model.dismissConfirm
        )
    }

    private func change(_ id: String, _ apply: (UUID) -> Void) {
        guard let id = UUID(uuidString: id) else { return }
        apply(id)
    }

    /// Frames read so far; one not read yet, or unreadable, is the placeholder. Nil until the first.
    private var filmstrip: [Image]? {
        guard !frames.isEmpty else { return nil }
        return (0..<Self.frameCount).map { frames[$0] ?? Self.placeholder }
    }

    private func readFrames() async {
        for await frame in VideoFilmstrip.frames(of: model.clip.urls, window: model.clip.window, count: Self.frameCount) {
            frames[frame.index] = Image(uiImage: frame.image)
        }
    }

    /// The playhead follows the player while it plays.
    private func follow() async {
        guard model.isPlaying else { return }
        while !Task.isCancelled {
            model.tick()
            try? await Task.sleep(for: .milliseconds(33))
        }
    }
}
