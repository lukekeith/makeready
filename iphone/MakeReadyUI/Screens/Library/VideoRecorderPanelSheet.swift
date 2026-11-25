//
//  VideoRecorderPanelSheet.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-recorder in d2m (§2d Sheet behaviour).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI
import UIKit

/// File scope: a generic type holds no static stored properties.
private enum PanelSheetGeometry {
    /// FLAGGED LITERAL — C-016 §2 FL-2: the 36 × 5 grabber capsule.
    static let grabberWidth: CGFloat = 36
    static let grabberHeight: CGFloat = 5
    /// The most an upward pull lifts the sheet (ActionMenuMotion.dragOffset): the surface runs
    /// this far past the bottom edge, so a pull never uncovers it.
    static let overpull: CGFloat = 16
}

/// The recorder's sheet chrome (§2d, video-polish D1): the app's action-modal motion drawn in place
/// — a `color-black-80` dim fades in, the full-width surface slides up from the bottom edge, and a
/// tap on the dim, or a drag on the grabber strip, slides it off again.
///
/// It owns its motion (as ActionMenuLayer does): it slides in on appear, and when `visible` turns
/// false it slides out, then calls `onHidden` so the screen unmounts it.
struct VideoRecorderPanelSheet<AboveDim: View, Content: View>: View {
    let visible: Bool
    /// Horizontal inset of the content; 0 for content that insets its own rows (C-150).
    let contentInset: CGFloat
    /// Space under the content, inside the surface: the home indicator or the keyboard.
    let bottomInset: CGFloat
    /// True: the dim reaches under the safe areas (fullScreen); false: it stays on the recorder's
    /// area and the sheet is clipped to it (lessonInline).
    let coversScreen: Bool
    /// False: no dim is drawn (the Filters sheet — the live picture must stay readable, owner
    /// 2026-11-24); a tap outside the sheet still dismisses it.
    let dims: Bool
    let onDismiss: () -> Void
    let onHidden: () -> Void
    /// Drawn between the dim and the sheet (the Countdown sheet's rail).
    let aboveDim: AboveDim
    let content: Content

    @State private var shown: Bool
    @State private var keyboardUp = false
    /// This drag closed the keyboard, so it moves nothing else.
    @State private var dragClosedKeyboard = false
    @GestureState(resetTransaction: Transaction(animation: ActionMenuMotion.slide))
    private var drag: CGFloat = 0
    @GestureState private var dragging = false

    /// `startsShown` — a sheet open from the first frame (a seeded state) is at rest, not sliding.
    init(
        visible: Bool,
        startsShown: Bool,
        contentInset: CGFloat,
        bottomInset: CGFloat,
        coversScreen: Bool,
        dims: Bool = true,
        onDismiss: @escaping () -> Void,
        onHidden: @escaping () -> Void,
        @ViewBuilder aboveDim: () -> AboveDim,
        @ViewBuilder content: () -> Content
    ) {
        self.visible = visible
        self.contentInset = contentInset
        self.bottomInset = bottomInset
        self.coversScreen = coversScreen
        self.dims = dims
        self.onDismiss = onDismiss
        self.onHidden = onHidden
        self.aboveDim = aboveDim()
        self.content = content()
        _shown = State(initialValue: startsShown)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // A clear layer still takes the dismissing tap; a 0-opacity one would not hit-test.
            (dims ? Token.black80 : Color.clear)
                .opacity(dims && !shown ? 0 : 1)
                .ignoresSafeArea(edges: coversScreen ? .all : [])
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
                .accessibilityHidden(true)
                .ui2Element("Dim")
            aboveDim
            sheet
                .visualEffect { [shown, drag] effect, proxy in
                    effect.offset(y: (shown ? 0 : proxy.size.height + PanelSheetGeometry.overpull) + drag)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .modifier(ClippedWhen(clipped: !coversScreen))
        .allowsHitTesting(visible)
        .onAppear {
            withAnimation(ActionMenuMotion.slide) { shown = true }
        }
        .onChange(of: visible) { _, nowVisible in
            // Re-presented mid slide-out: slide back up from wherever it is.
            guard !nowVisible else {
                withAnimation(ActionMenuMotion.slide) { shown = true }
                return
            }
            closeKeyboard()
            withAnimation(ActionMenuMotion.slide) {
                shown = false
            } completion: {
                onHidden()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
    }

    /// `color-modal-background`, `radius-modal` top corners, the top strip, then the content.
    private var sheet: some View {
        VStack(spacing: 0) {
            topStrip
            content
                .padding(.horizontal, contentInset)
                .padding(.bottom, Token.Space.pageMargin)
                .padding(.bottom, bottomInset)
        }
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: Token.Radius.modal,
                topTrailingRadius: Token.Radius.modal,
                style: .continuous
            )
            .fill(Token.modalBackground)
            .padding(.bottom, -PanelSheetGeometry.overpull)
            // A tap on the surface is not a tap on the dim.
            .contentShape(Rectangle())
            .onTapGesture {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
        .ui2Element("Sheet")
    }

    /// The only part that drags: the grabber and the strip around it (C-016's `space-section-gap`
    /// above its content).
    private var topStrip: some View {
        Capsule()
            .fill(Token.white30)
            .frame(width: PanelSheetGeometry.grabberWidth, height: PanelSheetGeometry.grabberHeight)
            .ui2Element("Grabber")
            .padding(.top, Token.Space.step4)
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: Token.Space.sectionGap, alignment: .top)
            .contentShape(Rectangle())
            .gesture(dismissDrag)
            .onChange(of: dragging) { _, active in
                if !active { dragClosedKeyboard = false }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Close")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, dismiss)
    }

    private var dismissDrag: some Gesture {
        // pan-ok: a vertical drag-to-dismiss on the sheet's top strip, never a sideways pan.
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($dragging) { _, active, _ in active = true }
            .updating($drag) { value, offset, _ in
                guard !keyboardUp, !dragClosedKeyboard else { return }
                offset = ActionMenuMotion.dragOffset(value.translation.height)
            }
            .onChanged { _ in
                guard keyboardUp else { return }
                dragClosedKeyboard = true
                closeKeyboard()
            }
            .onEnded { value in
                guard !dragClosedKeyboard, !keyboardUp else { return }
                if ActionMenuMotion.shouldDismiss(
                    translation: value.translation.height,
                    predicted: value.predictedEndTranslation.height
                ) {
                    dismiss()
                }
            }
    }

    private func dismiss() {
        closeKeyboard()
        onDismiss()
    }

    private func closeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Clips to the bounds when asked; never changes the view's identity.
private struct ClippedWhen: ViewModifier {
    let clipped: Bool

    func body(content: Content) -> some View {
        content.mask {
            Rectangle().ignoresSafeArea(edges: clipped ? [] : .all)
        }
    }
}
