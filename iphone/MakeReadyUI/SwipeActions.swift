//
//  SwipeActions.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-142-swipe-actions in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-142 §4 `SwipeActions.Action` (R-36: nested in `SwipeActions` through the typealias below; it
/// is declared here so a caller can name it without `SwipeActions`' generic `Content`, the
/// `ActivityCanvas.Gradient` precedent).
struct SwipeActionsAction: Identifiable {
    /// §4 — "accessibility name and action name, e.g. "Delete"". Identifiable by `label`.
    let label: String
    /// §4 — "a library glyph — `C-021 glyph`", drawn in `color-text-primary` in the circle.
    let glyph: GlyphName
    /// §4 — "a generated Token member, e.g. `Token.error`": the circle / capsule fill.
    let tint: Color
    /// §4 — "only meaningful on the edge action": allows stretch, arm and full-swipe release.
    var fullSwipe: Bool = false
    /// §4 — "whether running the action removes the row from its list; nil resolves to true for a
    /// destructive action — one tinted `Token.error` — and false otherwise; only `false` springs
    /// the row back to 0 after a full swipe's `onAction`".
    var removesRow: Bool?
    /// §4 (R-03) — "the action's closure; the component never decides what it means".
    var onAction: () -> Void = {}
    /// The resting circle's tap closure (library-home change 2026-11-22): nil = the tap runs
    /// `onAction`. When set, a tap on the resting circle calls it INSTEAD and leaves the row open
    /// (the caller closes it through `openSide`); a full swipe still calls `onAction`.
    var onTap: (() -> Void)?

    var id: String { label }

    /// §4 `removesRow` with nil resolved: true when the action is destructive (tinted `Token.error`).
    var resolvedRemovesRow: Bool { removesRow ?? (tint == Token.error) }

    init(
        label: String,
        glyph: GlyphName,
        tint: Color,
        fullSwipe: Bool = false,
        removesRow: Bool? = nil,
        onAction: @escaping () -> Void = {},
        onTap: (() -> Void)? = nil
    ) {
        self.label = label
        self.glyph = glyph
        self.tint = tint
        self.fullSwipe = fullSwipe
        self.removesRow = removesRow
        self.onAction = onAction
        self.onTap = onTap
    }
}

/// C-142 §4 `SwipeActions.Side` — `enum { case leading, trailing }`.
enum SwipeActionsSide {
    case leading
    case trailing

    /// The sign of an offset that reveals this side: negative reveals trailing (§3).
    var sign: CGFloat { self == .trailing ? -1 : 1 }
}

/// C-142 §2 geometry, named once.
private enum SwipeGeometry {
    /// FLAGGED LITERAL — C-142 §2: the 48 pt action circle, no control-size token.
    static let circle: CGFloat = 48
    /// FLAGGED LITERAL — C-142 §2: a circle grows in from a 6 pt dot.
    static let dot: CGFloat = 6
    /// FLAGGED LITERAL — C-142 §2: the other circles fade to 40 % while the edge action stretches.
    static let stretchedSiblingOpacity: Double = 0.4
    /// FLAGGED LITERAL — C-142 §2, OQ-C-142-2: the row arms at 55 % of its width.
    static let armFraction: CGFloat = 0.55
    /// FLAGGED LITERAL — C-142 §2: and disarms below 50 % (5 % hysteresis).
    static let disarmFraction: CGFloat = 0.50
    /// FLAGGED LITERAL — C-142 §2: a side with no actions, or a non-full-swipe edge action past
    /// full reveal, rubber-bands at ¼ resistance.
    static let rubberBand: CGFloat = 0.25
    /// The inset from the row edge and between circles: `space-element-gap` (8).
    static var gap: CGFloat { Token.Space.elementGap }

    /// §2 "Full reveal = n × 48 + (n + 1) × space-element-gap" — 64 for one action, 176 for three.
    static func fullReveal(_ count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * circle + CGFloat(count + 1) * gap
    }

    /// §2 "Circle i (0 = edge) has slot start sᵢ = 8 + i × 56".
    static func slotStart(_ index: Int) -> CGFloat { gap + CGFloat(index) * (circle + gap) }

    /// §2 "OQ-C-142-2 … the card snaps to |offset| = width − 48, leaving a 48 pt sliver".
    static func armedMagnitude(width: CGFloat) -> CGFloat { max(width - circle, 0) }
}

/// C-142 SwipeActions — "wraps any list row with trailing and/or leading actions: ~48 pt circles
/// (white glyph on a solid tint) that grow in from the edge. A half swipe rests open; a swipe past
/// ~55% arms a stretched capsule with haptics, and an armed release runs the action. Uses
/// .horizontalPan. One row open per list. Delete is always trailing." (owner).
///
/// Controlled (R-01): which side rests open is the caller's `openSide`, reported back through
/// `onOpenSideChange`, so the screen keeps one row open per list and closes it on scroll
/// (deviation 4). The drag offset, the armed flag and the full-swipe cover are ephemeral gesture
/// state (R-02). `posedOffset` draws a mid-gesture phase from props alone, for captures.
///
/// Chrome-free and width-driven (R-16): the content fills the width it is given and sets the
/// height; C-142 adds no padding and paints nothing at rest.
struct SwipeActions<Content: View>: View {
    typealias Action = SwipeActionsAction
    typealias Side = SwipeActionsSide

    /// §4 #1 — "Trailing actions, edge-first; `[0]` is the edge action. Delete goes here".
    let trailing: [Action]
    /// §4 #2 — "Leading actions, edge-first, mirrored. Empty → that direction rubber-bands."
    let leading: [Action]
    /// §4 #3 — "Which side rests open; nil = closed. Caller-owned (R-01)".
    let openSide: Side?
    /// §4 #4 — "Reports a rest-open or close the user caused (R-01, R-33)".
    let onOpenSideChange: (Side?) -> Void
    /// §4 #5 — "Pose override: when set, the row is drawn at this signed offset as if mid-drag
    /// (armed when past the threshold) and the gesture is off."
    let posedOffset: CGFloat?
    /// §4 #6 — "The row the list already draws (R-08 slot)".
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The row's width, for the arm threshold and the armed snap (§2).
    @State private var width: CGFloat = 0
    /// Where the card sits while not armed: the finger's offset, or the rest pose (R-02).
    @State private var liveOffset: CGFloat
    @State private var dragging = false
    @State private var dragStart: CGFloat = 0
    /// §2 "Armed (|offset| ≥ 0.55 × row width)" — ephemeral (R-02).
    @State private var armed = false
    /// §2 release rule: "the capsule covers the row, the card leaves (|offset| = width)".
    @State private var covering = false
    /// The side being swiped while armed or covering.
    @State private var activeSide: Side = .trailing

    init(
        trailing: [Action] = [],
        leading: [Action] = [],
        openSide: Side?,
        onOpenSideChange: @escaping (Side?) -> Void = { _ in },
        posedOffset: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.trailing = trailing
        self.leading = leading
        self.openSide = openSide
        self.onOpenSideChange = onOpenSideChange
        self.posedOffset = posedOffset
        self.content = content()
        _liveOffset = State(initialValue: Self.restOffset(openSide, trailing: trailing, leading: leading))
    }

    var body: some View {
        SwipeLayers(
            offset: cardOffset,
            trailing: trailing,
            leading: leading,
            catchesTaps: openSide != nil,
            reduceMotion: reduceMotion,
            onCircleTap: tapCircle,
            onContentTap: close,
            content: content
        )
        // Content that moves past the row's edges is not drawn over its neighbours: the row is
        // its own clip, as a list cell is (default, unruled — §2 names no clip).
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // §2 "Drag via the house .horizontalPan (HorizontalScrolling.swift), never DragGesture".
        .horizontalPan(onChanged: panChanged, onEnded: panEnded)
        // §2 Haptics: "medium when armed turns true, light when it turns false by dragging back;
        // none on reveal, rest-open or tap."
        .sensoryFeedback(trigger: armed) { _, isArmed in
            if isArmed { return .impact(weight: .medium) }
            return dragging ? .impact(weight: .light) : nil
        }
        .onChange(of: openSide) { _, side in
            guard !dragging, !covering else { return }
            withAnimation(Token.Motion.swipeSettle) {
                liveOffset = Self.restOffset(side, trailing: trailing, leading: leading)
            }
        }
        // §2 "Reappearing after removal … it comes back closed": reset the gesture state when the
        // view reappears and whenever its actions change (by label), independent of view identity.
        .onAppear(perform: resetGesture)
        .onChange(of: trailing.map(\.label) + ["|"] + leading.map(\.label)) { _, _ in resetGesture() }
        // §2 Accessibility (R-17): "The row carries one accessibilityAction(named: label) per
        // action on both sides."
        .accessibilityActions {
            ForEach(trailing + leading) { action in
                SwiftUI.Button(action.label, action: action.onAction)
            }
        }
        .ui2Element("SwipeActions")             // capture element map — UI2Element.swift
    }

    // MARK: - Pose

    /// The signed offset the card is drawn at.
    private var cardOffset: CGFloat {
        if let posed = posedOffset {
            let side: Side = posed < 0 ? .trailing : .leading
            return isArmable(side) && abs(posed) >= SwipeGeometry.armFraction * width && width > 0
                ? side.sign * SwipeGeometry.armedMagnitude(width: width)
                : posed
        }
        if covering { return activeSide.sign * width }
        if armed { return activeSide.sign * SwipeGeometry.armedMagnitude(width: width) }
        return liveOffset
    }

    private func actions(_ side: Side) -> [Action] { side == .trailing ? trailing : leading }

    /// Only the edge action with `fullSwipe` stretches, arms and full-swipes (§2).
    private func isArmable(_ side: Side) -> Bool { actions(side).first?.fullSwipe == true }

    private static func restOffset(_ side: Side?, trailing: [Action], leading: [Action]) -> CGFloat {
        switch side {
        case .trailing: return -SwipeGeometry.fullReveal(trailing.count)
        case .leading: return SwipeGeometry.fullReveal(leading.count)
        case nil: return 0
        }
    }

    // MARK: - Gesture

    private func panChanged(_ value: HorizontalPanValue) {
        guard posedOffset == nil, !covering else { return }
        if !dragging {
            dragging = true
            dragStart = armed ? cardOffset : liveOffset
        }
        var raw = dragStart + value.translation
        let side: Side = raw < 0 ? .trailing : .leading
        let sideActions = actions(side)
        let full = SwipeGeometry.fullReveal(sideActions.count)
        if sideActions.isEmpty {
            // §2 "A side with no actions rubber-bands at ¼ distance".
            raw *= SwipeGeometry.rubberBand
        } else if !isArmable(side), abs(raw) > full {
            // §2 "Edge action without fullSwipe: … past full reveal the drag rubber-bands at ¼".
            raw = side.sign * (full + (abs(raw) - full) * SwipeGeometry.rubberBand)
        }
        liveOffset = raw

        let magnitude = abs(raw)
        let shouldArm: Bool
        if isArmable(side), width > 0 {
            shouldArm = armed
                ? magnitude >= SwipeGeometry.disarmFraction * width
                : magnitude >= SwipeGeometry.armFraction * width
        } else {
            shouldArm = false
        }
        if shouldArm != armed {
            activeSide = side
            // §2 "Reduce Motion: the arm snap is instant".
            withAnimation(reduceMotion ? nil : Token.Motion.swipeSettle) { armed = shouldArm }
        }
    }

    private func panEnded(_ value: HorizontalPanValue) {
        guard posedOffset == nil, dragging else { return }
        dragging = false
        if armed {
            fullSwipe(activeSide)
            return
        }
        let side: Side = liveOffset < 0 ? .trailing : .leading
        let sideActions = actions(side)
        // §2 "Not armed and |offset| > ½ full reveal → spring to full reveal and
        // onOpenSideChange(side). Otherwise → spring to 0 and onOpenSideChange(nil)."
        if !sideActions.isEmpty, abs(liveOffset) > SwipeGeometry.fullReveal(sideActions.count) / 2 {
            withAnimation(Token.Motion.swipeSettle) {
                liveOffset = side.sign * SwipeGeometry.fullReveal(sideActions.count)
            }
            if openSide != side { onOpenSideChange(side) }
        } else {
            withAnimation(Token.Motion.swipeSettle) { liveOffset = 0 }
            if openSide != nil { onOpenSideChange(nil) }
        }
    }

    /// §2 "Armed → the capsule covers the row, the card leaves (|offset| = width), then onAction
    /// of the edge action fires (animation completion)." Then, per the action's `removesRow`:
    /// true → "the row stays covered and off screen … no spring back, no onOpenSideChange, no
    /// further motion from this view"; false → "the row reports closed and springs to 0".
    private func fullSwipe(_ side: Side) {
        guard let edge = actions(side).first else { return }
        withAnimation(Token.Motion.swipeSettle) {
            covering = true
        } completion: {
            edge.onAction()
            // §2 "The caller's removal … is the last motion".
            guard !edge.resolvedRemovesRow else { return }
            if openSide != nil { onOpenSideChange(nil) }
            withAnimation(Token.Motion.swipeSettle) {
                liveOffset = 0
                covering = false
                armed = false
            }
        }
    }

    /// §2 / §4: "Drag offset, the armed flag, `covering` and the reveal phase … reset when the view
    /// reappears or its actions change" — the row comes back closed (or at its caller-owned rest).
    private func resetGesture() {
        dragging = false
        covering = false
        armed = false
        liveOffset = Self.restOffset(openSide, trailing: trailing, leading: leading)
    }

    /// §2 While open: "a tap on a circle fires its onAction then onOpenSideChange(nil) (no capsule
    /// on tap)". An action with `onTap` calls it instead and stays open: the caller closes the row
    /// through `openSide` (library-home's delete confirmation keeps the row open while it is up).
    private func tapCircle(_ action: Action) {
        if let onTap = action.onTap {
            onTap()
            return
        }
        action.onAction()
        close()
    }

    /// §2 While open: "a tap on the content is consumed and calls onOpenSideChange(nil)".
    private func close() {
        withAnimation(Token.Motion.swipeSettle) { liveOffset = 0 }
        if openSide != nil { onOpenSideChange(nil) }
    }
}

/// The drawn layers at one card offset — animatable, so every frame of a settle, arm snap or
/// cover re-derives the circles' reveal scale and the capsule from the moving offset (§2).
private struct SwipeLayers<Content: View>: View, Animatable {
    var offset: CGFloat
    let trailing: [SwipeActionsAction]
    let leading: [SwipeActionsAction]
    let catchesTaps: Bool
    let reduceMotion: Bool
    let onCircleTap: (SwipeActionsAction) -> Void
    let onContentTap: () -> Void
    let content: Content

    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }

    var body: some View {
        content
            .ui2Element("Content")
            // §2 Content card: "While |offset| ≥ 1 pt the content sits on a card: fill
            // color-card-background, continuous corners radius-modal (deviation 1), the content's
            // own bounds, moving 1:1 with it. At rest … the card is not drawn."
            .background {
                if abs(offset) >= 1 {
                    RoundedRectangle(cornerRadius: Token.Radius.modal, style: .continuous)
                        .fill(Token.cardBackground)
                        .ui2Element("Content card")
                }
            }
            .overlay {
                if catchesTaps {
                    // §2 "a tap on the content is consumed": the open row's first tap closes it.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onContentTap)
                        .accessibilityHidden(true)
                }
            }
            .offset(x: offset)
            // §2 Layers, back to front: "the action layer … → the content card → the content slot".
            .background { actionLayer }
    }

    // MARK: - Action layer

    private var side: SwipeActionsSide? {
        if offset < 0 { return .trailing }
        if offset > 0 { return .leading }
        return nil
    }

    @ViewBuilder private var actionLayer: some View {
        if let side {
            let actions = side == .trailing ? trailing : leading
            ZStack(alignment: side == .trailing ? .trailing : .leading) {
                Color.clear
                // Edge action last, so a stretched capsule draws over its siblings.
                ForEach(Array(actions.enumerated().reversed()), id: \.element.id) { index, action in
                    actionView(action, index: index, count: actions.count, side: side)
                }
            }
        }
    }

    private func actionView(_ action: SwipeActionsAction, index: Int, count: Int, side: SwipeActionsSide) -> some View {
        let magnitude = abs(offset)
        let full = SwipeGeometry.fullReveal(count)
        let edgeStretched = (side == .trailing ? trailing : leading).first?.fullSwipe == true && magnitude > full
        let stretched = index == 0 && edgeStretched
        // §2 Reveal scale: "p = clamp((|offset| − sᵢ) / 48, 0, 1); diameter = 6 + 42 p, opacity = p.
        // Reduce Motion: diameter stays 48 and only opacity follows p."
        let progress = min(max((magnitude - SwipeGeometry.slotStart(index)) / SwipeGeometry.circle, 0), 1)
        let diameter = reduceMotion ? SwipeGeometry.circle
            : SwipeGeometry.dot + (SwipeGeometry.circle - SwipeGeometry.dot) * progress
        // §2 Stretch: "its outer end fixed at the 8 pt edge inset, its inner end at the card's edge
        // minus 8 … Other circles stay put at full size and fade to opacity 0.4".
        let length = stretched ? max(SwipeGeometry.circle, magnitude - 2 * SwipeGeometry.gap) : SwipeGeometry.circle
        let opacity = stretched ? 1 : progress * (edgeStretched ? SwipeGeometry.stretchedSiblingOpacity : 1)
        let outer: Alignment = side == .trailing ? .trailing : .leading
        let inner: Alignment = side == .trailing ? .leading : .trailing
        let anchor: UnitPoint = side == .trailing ? .trailing : .leading

        return SwiftUI.Button {
            onCircleTap(action)
        } label: {
            // §2 "The glyph sits in a 48 pt square at the capsule's inner (finger) end."
            ZStack(alignment: inner) {
                Capsule().fill(action.tint)
                Glyph(action.glyph, size: .md, tint: Token.textPrimary)
                    .frame(width: SwipeGeometry.circle, height: SwipeGeometry.circle)
            }
            .frame(width: length, height: SwipeGeometry.circle)
        }
        .buttonStyle(.plain)
        .scaleEffect(stretched ? 1 : diameter / SwipeGeometry.circle, anchor: anchor)
        .opacity(opacity)
        // §2 Accessibility: "Each visible circle: accessibilityLabel(label) + .isButton".
        .accessibilityLabel(action.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(progress == 0)
        .ui2Element(stretched ? "Capsule" : "Action circle \(index + 1)")
        .padding(side == .trailing ? .trailing : .leading, SwipeGeometry.slotStart(index))
        .frame(maxWidth: .infinity, alignment: outer)
    }
}
