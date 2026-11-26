//
//  VideoNamingContainer.swift
//  MakeReady
//
//  video-naming D1, D3, D18: hosts d2m's `VideoNamingScreen` over a `VideoNamingModel`. Every input and
//  callback is the model's. It slides itself in and out on `sheetPresent` (a hosted overlay gets no
//  presenting transaction), as `VideoEditorContainer` does. No `.sheet`, no `.fullScreenCover`.
//

import SwiftUI
import UIKit

struct VideoNamingContainer: View {
    let model: VideoNamingModel
    /// The page is to slide away: Back, with the recorder staying open. On the check the recorder closes
    /// and carries the page off with it, so this stays false.
    let leaving: Bool
    /// Called once the page has slid out; the host drops it then.
    var onEnd: () -> Void = {}

    @State private var shown = false
    /// The keyboard's top edge on the screen; below everything while it is away.
    @State private var keyboardTop: CGFloat = .infinity
    /// Where the page ends on the screen once it has slid in.
    @State private var bottomEdge: CGFloat = 0

    /// The block the model reports, as the view names it.
    static func blockState(_ block: VideoNamingModel.Block) -> AISuggestionsBlock.State {
        switch block {
        case .generating: .generating
        case .list: .list
        case .regenerating: .regenerating
        case .prompt: .prompt
        case .empty: .empty
        }
    }

    var body: some View {
        // The page scrolls, and its bottom is lifted by the measured keyboard inset so the focused field
        // stays above the keyboard; the system must not lift it as well (D1).
        ScrollView {
            screen
        }
        .contentMargins(.bottom, max(0, bottomEdge - keyboardTop), for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .background(Token.layoutBackground.ignoresSafeArea())
        // An offset on the effect layer, not the layout: keyboard avoidance measures un-offset chrome.
        .visualEffect { [shown] effect, proxy in
            effect.offset(y: shown ? 0 : proxy.frame(in: .global).maxY)
        }
        // Outside the effect, so the slide is not measured.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottomEdge = $0 }
        .ignoresSafeArea(.keyboard)
        .accessibilityAddTraits(.isModal)
        // D2: the accessibility escape is Back.
        .accessibilityAction(.escape) { model.backTapped() }
        .onAppear {
            withAnimation(Token.Motion.sheetPresent) { shown = true }
        }
        .onChange(of: leaving) { _, leaving in
            guard leaving else { return }
            withAnimation(Token.Motion.sheetPresent) {
                shown = false
            } completion: {
                onEnd()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
            followKeyboard($0)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {
            followKeyboard($0, hiding: true)
        }
    }

    private var screen: some View {
        VideoNamingScreen(
            state: .init(
                title: model.title,
                titlePlaceholder: model.titlePlaceholder,
                description: model.description,
                aiState: Self.blockState(model.block),
                promptCopy: model.promptCopy ?? "",
                pairs: model.suggestions.map { .init(title: $0.title, description: $0.description) }),
            onTitleChange: model.setTitle,
            onDescriptionChange: model.setDescription,
            onPick: model.pick,
            onRegenerate: model.regenerate,
            onSave: model.saveTapped,
            onBack: model.backTapped
        )
    }

    private func followKeyboard(_ note: Notification, hiding: Bool = false) {
        let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        withAnimation(.easeOut(duration: duration)) {
            keyboardTop = hiding || frame.isEmpty ? .infinity : frame.minY
        }
    }
}
