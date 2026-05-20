//
//  BibleReaderBridge.swift
//  MakeReady
//
//  SwiftUI bridge to present the UIKit BibleReaderOverlayView.
//  Used by both the hamburger menu and read activity verse selection.
//

import SwiftUI

/// SwiftUI full-screen wrapper for the UIKit Bible reader overlay.
/// Present this with `.fullScreenCover` or via OverlayManager.
struct BibleReaderModal: View {
    let overlayManager: OverlayManager
    var onVerseSelected: ((BibleBookInfo, Int, Int) -> Void)?
    var onPassageConfirmed: ((BibleBookInfo, Int, Int, Int, String) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        BibleReaderViewBridge(
            overlayManager: overlayManager,
            onVerseSelected: onVerseSelected,
            onPassageConfirmed: onPassageConfirmed,
            onDismiss: onDismiss
        )
        .ignoresSafeArea()
        .background(Color.clear)
    }
}

/// UIViewRepresentable bridge
private struct BibleReaderViewBridge: UIViewRepresentable {
    let overlayManager: OverlayManager
    var onVerseSelected: ((BibleBookInfo, Int, Int) -> Void)?
    var onPassageConfirmed: ((BibleBookInfo, Int, Int, Int, String) -> Void)?
    var onDismiss: (() -> Void)?

    func makeUIView(context: Context) -> BibleReaderOverlayView {
        let view = BibleReaderOverlayView(
            overlayManager: overlayManager,
            onDismiss: {
                onDismiss?()
            },
            onVerseSelected: onVerseSelected,
            onPassageConfirmed: onPassageConfirmed
        )
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: BibleReaderOverlayView, context: Context) {}
}
