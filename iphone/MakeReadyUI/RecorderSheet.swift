//
//  RecorderSheet.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-016-recorder-sheet in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-016 RecorderSheet: the two-detent recorder sheet that + → Voice memo presents over the
/// whole UI 2.0 shell. It holds C-017 RecorderCompactView at the compact detent and C-018
/// RecorderExpandedView at the expanded detent, and the finger drags it between them. Dragging
/// between the detents never touches the recording; while `isReady` the sheet stays compact.
/// It presents and dismisses the way C-066's ActionMenuLayer (the + menu) does: it owns its
/// slide-up and slide-out, dims the shell behind it with a tappable black80 scrim, and a swipe
/// down at the compact detent or a tap on the dim asks the caller to dismiss (`onDismiss`).
///
/// §2: a full-screen presentation layer, the stated exception to R-16. It fills the container
/// it is given (the whole screen, safe areas included) and positions the sheet inside it. The
/// dim covers the whole layer, which takes touches everywhere while it is visible.
///
/// Controlled (R-01): `expansion` and `visible` belong to the caller. The finger's in-flight
/// translation and `shown` are ephemeral (R-02), and the sheet reports only the detent it settles
/// on. There is no engine, timer or navigation inside (R-04/R-19); the sheet owns only its slide.
struct RecorderSheet: View {

    // MARK: - Props (§4, R-05 order)

    /// §4 `expansion`: where the sheet rests, 0 = compact … 1 = expanded. Required (R-07).
    let expansion: Double
    /// §4 `onExpansionChange`: the detent (0 or 1) the sheet settled on after a drag, or the
    /// grabber's Expand/Collapse accessibility action.
    var onExpansionChange: (Double) -> Void = { _ in }
    /// §4 `title` → C-017 and C-018 `title`.
    let title: String
    /// §4 `startTime` → C-018 `startTime`.
    let startTime: String
    /// §4 `elapsed` → C-017 and C-018 `elapsed`.
    let elapsed: TimeInterval
    /// §4 `samples` → C-017 and C-018 `samples`.
    let samples: [Float]
    /// §4 `sampleTime` → C-017 and C-018 `sampleTime`. Defaults to `0` (the still, stepped look).
    var sampleTime: Double = 0
    /// §4 `isRunning` → C-017 and C-018 `isRunning`. Defaults to `false`.
    var isRunning: Bool = false
    /// §4 `isReady` → C-017 `isReady`. While `true` the sheet is pinned to the compact detent
    /// (it never expands) and a swipe down calls `onClose`. Defaults to `false`.
    var isReady: Bool = false
    /// §4 `onRecord` → C-017 `onRecord`.
    var onRecord: () -> Void = {}
    /// §4 `phase` → C-018 `phase`; `.micDenied` also disables the drag (deviation 8).
    let phase: RecorderExpandedView.Phase
    /// §4 `menu` → C-018 `menu`.
    let menu: RecorderExpandedView.Menu
    /// §4 `visible`: whether the sheet is presented. The caller sets it false to dismiss; the
    /// sheet slides out, then calls `onHidden`. Defaults to `true`.
    var visible: Bool = true
    /// §4 `onHidden`: the slide-out finished; the caller unmounts the sheet.
    var onHidden: () -> Void = {}
    /// §4 `onDismiss`: the leader tapped the dim, swiped down at the compact detent, or used the
    /// accessibility escape. The caller decides what it means and sets `visible` false.
    var onDismiss: () -> Void = {}
    /// §4 `onStop` → C-017 `onStop`.
    var onStop: () -> Void = {}
    /// §4 → the C-018 callbacks of the same name, unchanged.
    var onMore: () -> Void = {}
    var onDone: () -> Void = {}
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onDiscardRequest: () -> Void = {}
    var onDiscard: () -> Void = {}
    var onDismissMenu: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onClose: () -> Void = {}

    /// R-02: the finger's vertical translation while it is down. It resets with the snap
    /// animation, so the sheet settles in one motion whether or not the caller moves `expansion`.
    @GestureState(resetTransaction: Transaction(animation: Token.Motion.sheetSnap))
    private var dragTranslation: CGFloat = 0

    /// §2 Presentation (R-02): false until the sheet appears, then animated true with
    /// `motion-sheet-present`; back to false when `visible` turns false. A hosted overlay gets no
    /// presenting transaction, so the sheet slides itself (as ActionMenuLayer does).
    @State private var shown = false
    /// True only beneath the capture harness's element map (UI2Element.swift).
    @Environment(\.ui2ElementCollecting) private var capturing

    // MARK: - Geometry

    private enum Geometry {
        /// FLAGGED LITERAL — C-016 §2 FL-1 (OQ-C-016-3): 36 pt continuous corners on all four
        /// corners (measured ≈108 px at 3×); the era's radius tokens stop at radius-modal (16).
        static let cornerRadius: CGFloat = 36
        /// FLAGGED LITERAL — C-016 §2 FL-2: the 36 × 5 grabber capsule (measured 104 × 14 px).
        static let grabberWidth: CGFloat = 36
        static let grabberHeight: CGFloat = 5
        /// FLAGGED LITERAL — C-016 §2 FL-3: C-018 sits 20 below the sheet's top (247 − 186 px).
        static let expandedContentTop: CGFloat = 20
        /// FLAGGED LITERAL — C-016 §2 FL-4: travel past either detent is damped to one third.
        static let overscrollDamping: Double = 1.0 / 3.0
        /// FLAGGED LITERAL — C-016 §2 FL-5: minimum drag distance 10, so C-017/C-018 taps win.
        static let minimumDragDistance: CGFloat = 10
        /// C-016 §2 Detents: "C-017's intrinsic 250" (C-017 §2's fixed height). This is a
        /// dependency's stated size, not a design value of this row.
        static let compactContentHeight: CGFloat = 250
        /// C-016 §2 Content / OQ-C-016-4: C-017 below 0.5, C-018 at 0.5 and above.
        static let contentSwap: Double = 0.5
    }

    /// §2 Detents: the sheet's rect at an effective expansion, in the container's coordinates.
    private struct Layout {
        let width: CGFloat
        let height: CGFloat
        let safeTop: CGFloat
        let safeBottom: CGFloat

        /// Compact: `space-step-8` side and bottom insets, `space-section-gap` + 250 +
        /// `space-section-gap` tall (314).
        var compactInset: CGFloat { Token.Space.step8 }
        var compactHeight: CGFloat {
            Token.Space.sectionGap + Geometry.compactContentHeight + Token.Space.sectionGap
        }
        var compactTop: CGFloat { height - compactInset - compactHeight }
        /// Expanded: no inset, top at the safe-area top, bottom at H (under the home indicator).
        var expandedTop: CGFloat { safeTop }
        /// How far the sheet's top travels between the detents.
        var travel: CGFloat { max(compactTop - expandedTop, 1) }

        /// §2 Between: top, side inset and bottom inset interpolate linearly (deviation 7).
        /// Past either detent the sheet keeps its detent's shape and only moves.
        func frame(at effective: Double) -> CGRect {
            let clamped = min(max(effective, 0), 1)
            let t = CGFloat(clamped)
            let inset = compactInset * (1 - t)
            let top = compactTop + (expandedTop - compactTop) * t
            let bottom = height - inset
            let overshoot = CGFloat(effective - clamped) * travel
            return CGRect(x: inset, y: top - overshoot, width: width - inset * 2, height: bottom - top)
        }

        /// The height C-018 is laid out at: the expanded detent's content box, from FL-3 below
        /// the sheet's top to H − the safe-area bottom.
        var expandedContentHeight: CGFloat {
            height - safeBottom - expandedTop - Geometry.expandedContentTop
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let layout = Layout(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom,
                safeTop: insets.top,
                safeBottom: insets.bottom
            )
            let effective = effectiveExpansion(layout)
            let rect = layout.frame(at: effective)
            // §2 Presentation: the distance from the sheet's top to the bottom edge.
            let hiddenOffset = layout.height - rect.minY
            ZStack(alignment: .topLeading) {
                dim
                sheet(layout: layout, effective: effective)
                    .frame(width: rect.width, height: rect.height)
                    // The reader's origin is the safe-area corner; the sheet's rect is full-screen.
                    .offset(x: rect.minX - insets.leading, y: rect.minY - insets.top)
                    // The whole sheet rides the slide together; nothing inside has a transition.
                    .visualEffect { [shown, hiddenOffset] effect, _ in
                        effect.offset(y: shown ? 0 : hiddenOffset)
                    }
                    .gesture(dragGesture(layout), including: phase == .micDenied ? .none : .all)
                    .accessibilityAction(.escape, onDismiss)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(visible)
        .onAppear {
            // The capture harness snapshots at once, so a captured preview shows the sheet at
            // rest (presented) rather than the first frame of its slide-up.
            if capturing { shown = true; return }
            withAnimation(Token.Motion.sheetPresent) { shown = true }
        }
        .onChange(of: visible) { _, nowVisible in
            // Re-presented mid slide-out: slide back up from wherever it is.
            guard !nowVisible else {
                withAnimation(Token.Motion.sheetPresent) { shown = true }
                return
            }
            withAnimation(Token.Motion.sheetPresent) {
                shown = false
            } completion: {
                onHidden()
            }
        }
        .ui2Element("RecorderSheet")     // capture element map — UI2Element.swift
    }

    // MARK: - Dim

    /// §2 Dim: the + menu's full-screen `black80`, fading with `shown`; a tap asks to dismiss.
    private var dim: some View {
        Token.black80
            .opacity(shown ? 1 : 0)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
            .ui2Element("Dim")
    }

    // MARK: - Sheet

    private func sheet(layout: Layout, effective: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: Geometry.cornerRadius, style: .continuous)
        return ZStack(alignment: .top) {
            // §2 Sheet surface (OQ-C-016-2): `color-modal-background`, no stroke, no shadow.
            shape.fill(Token.modalBackground)
            content(layout: layout, effective: effective)
            grabber
        }
        .clipShape(shape)
        .contentShape(shape)
        .ui2Element("Sheet")
    }

    /// §2 Content: chosen by the effective expansion; the swap is instant (deviation 4).
    @ViewBuilder
    private func content(layout: Layout, effective: Double) -> some View {
        if effective < Geometry.contentSwap {
            RecorderCompactView(
                title: title,
                elapsed: elapsed,
                samples: samples,
                sampleTime: sampleTime,
                isRunning: isRunning,
                isReady: isReady,
                onRecord: onRecord,
                onStop: onStop
            )
                .frame(height: Geometry.compactContentHeight)
                .padding(.top, Token.Space.sectionGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transaction { $0.animation = nil }
        } else {
            RecorderExpandedView(
                title: title,
                startTime: startTime,
                elapsed: elapsed,
                samples: samples,
                sampleTime: sampleTime,
                isRunning: isRunning,
                phase: phase,
                menu: menu,
                onMore: onMore,
                onDone: onDone,
                onPause: onPause,
                onResume: onResume,
                onDiscardRequest: onDiscardRequest,
                onDiscard: onDiscard,
                onDismissMenu: onDismissMenu,
                onOpenSettings: onOpenSettings,
                onClose: onClose
            )
            // Top-anchored at the expanded detent's size, clipped by the sheet (OQ-C-016-4).
            .frame(height: layout.expandedContentHeight)
            .padding(.top, Geometry.expandedContentTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transaction { $0.animation = nil }
        }
    }

    /// §2 Grabber: a 36 × 5 `color-white-30` capsule, `space-step-4` below the sheet's top.
    private var grabber: some View {
        Capsule()
            .fill(Token.white30)
            .frame(width: Geometry.grabberWidth, height: Geometry.grabberHeight)
            .padding(.top, Token.Space.step4)
            // R-17: the grabber is the sheet's size control for VoiceOver.
            .accessibilityElement()
            .accessibilityLabel("Recorder size")
            .accessibilityValue(expansion >= Geometry.contentSwap ? "Expanded" : "Compact")
            .accessibilityAction(named: "Expand") { settle(on: 1) }
            .accessibilityAction(named: "Collapse") { settle(on: 0) }
            .accessibilityAction(named: "Close") { if isReady { onClose() } }
            .ui2Element("Grabber")
    }

    // MARK: - Drag

    /// §2 Drag: `expansion` plus the finger's translation (upward = toward expanded), with
    /// travel past either detent damped to one third (FL-4).
    private func effectiveExpansion(_ layout: Layout) -> Double {
        // `isReady` pins the compact detent: an upward drag does not move the sheet.
        let translation = isReady ? max(dragTranslation, 0) : dragTranslation
        let raw = expansion - Double(translation / layout.travel)
        if raw > 1 { return 1 + (raw - 1) * Geometry.overscrollDamping }
        if raw < 0 { return raw * Geometry.overscrollDamping }
        return raw
    }

    private func dragGesture(_ layout: Layout) -> some Gesture {
        // pan-ok: the sheet's drag is vertical, between its two detents (C-016 §2 Drag).
        DragGesture(minimumDistance: Geometry.minimumDragDistance, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // §2 Dismiss: a downward swipe that starts at the compact detent calls
                // `onDismiss` once past the + menu's threshold, in every phase; short of it the
                // sheet snaps back to compact.
                if isReady || expansion <= 0, value.translation.height > 0 {
                    if ActionMenuMotion.shouldDismiss(
                        translation: value.translation.height,
                        predicted: value.predictedEndTranslation.height
                    ) {
                        onDismiss()
                    } else {
                        settle(on: 0)
                    }
                    return
                }
                // The detent nearest the gesture's predicted end.
                let predicted = expansion - Double(value.predictedEndTranslation.height / layout.travel)
                settle(on: predicted >= Geometry.contentSwap ? 1 : 0)
            }
    }

    /// Reports the detent and animates to it with `motion-sheet-snap`. While the microphone is
    /// denied the sheet stays where `expansion` puts it (deviation 8).
    private func settle(on detent: Double) {
        guard phase != .micDenied else { return }
        // `isReady` pins the compact detent.
        let target = isReady ? 0 : detent
        withAnimation(Token.Motion.sheetSnap) { onExpansionChange(target) }
    }
}
