//
//  VideoEditorPresentation.swift
//  MakeReady
//
//  video-editor D10, D29: presents the editor over the recorder as `HostableActionMenuPresentation`
//  presents a menu — handed up where `ui2HostsOverlays` is true (the lesson), drawn in place where it is
//  false (the + recorder is already the shell's one hosted overlay, and a nested hand-up is lost). The
//  editor slides itself in and out; the layer stays mounted until the slide-out ends. No `.sheet`, no
//  `.fullScreenCover`.
//

import SwiftUI

private struct VideoEditorPresentation: ViewModifier {
    let model: VideoRecorderModel

    @Environment(\.ui2HostsOverlays) private var hosted
    /// The editor on screen, kept while it slides out after the model has let go of it.
    @State private var shownEditor: VideoEditorModel?

    @ViewBuilder private var layer: some View {
        if let editor = shownEditor {
            VideoEditorContainer(model: editor, onEnd: {
                shownEditor = nil
                model.editorHidden()
            })
            .id(ObjectIdentifier(editor))
            // Its own confirms and text tool draw in place (D29).
            .environment(\.ui2HostsOverlays, false)
        }
    }

    func body(content: Content) -> some View {
        Group {
            if hosted {
                content.hostedOverlay(shownEditor == nil ? nil : UI2HostedOverlay(view: AnyView(layer), transition: .identity))
            } else {
                content.overlay { layer }
            }
        }
        .onChange(of: model.editor.map(ObjectIdentifier.init), initial: true) { _, _ in
            if let editor = model.editor { shownEditor = editor }
        }
    }
}

extension View {
    /// The editor over this recorder while `model.editor` is open; calls `model.editorHidden()` once it has slid out.
    func videoEditorPresentation(model: VideoRecorderModel) -> some View {
        modifier(VideoEditorPresentation(model: model))
    }
}
