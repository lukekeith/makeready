//
//  VideoNamingPresentation.swift
//  MakeReady
//
//  video-naming D1, D2: draws the naming page over the + menu's recorder after Review's save, as
//  `VideoEditorPresentation` draws the editor. It is drawn in place: the + recorder is already the shell's
//  one hosted overlay, and a nested hand-up is lost; the lesson's recorder never opens the page (D2). The
//  page slides itself in and out; the layer stays mounted until a Back's slide-out ends. On the check the
//  recorder closes and slides away with the page on it. No `.sheet`, no `.fullScreenCover`.
//

import SwiftUI

private struct VideoNamingPresentation: ViewModifier {
    let model: VideoRecorderModel

    /// The page on screen, kept while it slides out after the model has let go of it.
    @State private var shownNaming: VideoNamingModel?

    @ViewBuilder private var layer: some View {
        if let naming = shownNaming {
            VideoNamingContainer(
                model: naming,
                leaving: !model.isClosed && (model.phase != .naming || model.naming !== naming),
                onEnd: {
                    if shownNaming === naming { shownNaming = nil }
                    // A page opened again meanwhile is not this one's to drop.
                    if model.naming === naming { model.namingHidden() }
                })
            .id(ObjectIdentifier(naming))
        }
    }

    func body(content: Content) -> some View {
        content
            .overlay { layer }
            .onChange(of: model.naming.map(ObjectIdentifier.init), initial: true) { _, _ in
                if let naming = model.naming { shownNaming = naming }
            }
    }
}

extension View {
    /// The naming page over this recorder while `model.naming` is open; calls `model.namingHidden()` once it has slid out.
    func videoNamingPresentation(model: VideoRecorderModel) -> some View {
        modifier(VideoNamingPresentation(model: model))
    }
}
