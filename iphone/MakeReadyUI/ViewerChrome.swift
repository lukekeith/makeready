//
//  ViewerChrome.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-134-viewer-chrome in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-134 ViewerChrome — the stitched viewer's close circle, per-page top action and top scrim.
///
/// A full-width overlay, as tall as its scrim, that the host pins to the screen's top edge outside
/// the safe area (§2). Pure and controlled: the host says which action the active page takes and
/// when it changes (R-01); the view only runs the swap's fades (R-02, OQ-C-134-4) and emits taps
/// (R-03). Only the circles take touches, so the pager keeps a drag that starts on the scrim.
struct ViewerChrome: View {

    /// C-134 §4 `topAction` — the active page's top-right action (02 §2).
    enum TopAction: String {
        case share, menu, none
    }

    /// C-134 §4 `topAction`.
    let topAction: TopAction
    /// C-134 §4 `topInset` — the host's top safe-area inset; the circles' top edge (OQ-C-134-8).
    let topInset: CGFloat
    /// C-134 §4 `onClose` — Close tapped; the host closes the experience.
    var onClose: () -> Void = {}
    /// C-134 §4 `onShare` — Share tapped.
    var onShare: () -> Void = {}
    /// C-134 §4 `onMenu` — ⋯ tapped.
    var onMenu: () -> Void = {}

    /// C-134 §2's literal geometry and motion. Sizes and side insets are fixed points that do not
    /// scale with the page's `u` (§2).
    private enum Geometry {
        /// FLAGGED LITERAL — C-134 §2: 44 pt circle, no token.
        static let circle: CGFloat = 44
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-3: 1 pt inner stroke, no token.
        static let stroke: CGFloat = 1
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-1: 20 pt from each side, no token.
        static let sideInset: CGFloat = 20
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-8: scrim height is `topInset` + 78.
        static let scrimBelowInset: CGFloat = 78
        /// FLAGGED LITERAL — C-134 §2: 28 pt box for the close glyph, no token.
        static let closeGlyph: CGFloat = 28
        /// FLAGGED LITERAL — C-134 §2: 24 pt box for the top-action glyph, no token.
        static let actionGlyph: CGFloat = 24
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-5: 100 ms out, 50 ms empty hold, 100 ms in.
        static let glyphFade: Double = 0.1
        static let glyphHold: Double = 0.05
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-6: the whole circle fades over the swap's 250 ms.
        static let circleFade: Double = 0.25
        /// FLAGGED LITERAL — C-134 §2, OQ-C-134-7: pressed fill rises over 50 ms.
        static let pressFade: Double = 0.05
        /// FLAGGED LITERAL — C-134 §2: alpha of `color-black-100` at each fraction of the scrim's
        /// height, measured on t12.5.
        static let scrimStops: [(location: CGFloat, alpha: Double)] = [
            (0, 0.58), (0.40, 0.55), (0.50, 0.51), (0.61, 0.38), (0.71, 0.26),
            (0.79, 0.17), (0.86, 0.09), (0.93, 0.04), (1, 0)
        ]
    }

    private var hasTopAction: Bool { topAction != TopAction.none }

    var body: some View {
        // §2 Layers, bottom to top: scrim, then circles.
        ZStack(alignment: .top) {
            scrim

            // Padding and the spacer take no hits, so a drag between the circles reaches the pager.
            HStack(spacing: 0) {
                SwiftUI.Button(action: onClose) {
                    ChromeGlyph(name: .closeLargeCarbon, size: Geometry.closeGlyph)
                        .ui2Element("Close glyph")
                }
                .buttonStyle(ChromeCircleStyle())
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
                .ui2Element("Close circle")

                Spacer(minLength: 0)

                // §2, OQ-C-134-6: `none` has no circle, no hit target and no element.
                if hasTopAction {
                    TopActionCircle(action: topAction, onShare: onShare, onMenu: onMenu)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Geometry.sideInset)
            .padding(.top, topInset)
            .animation(.linear(duration: Geometry.circleFade), value: hasTopAction)
        }
        .frame(maxWidth: .infinity)
        .frame(height: topInset + Geometry.scrimBelowInset, alignment: .top)
        .ui2Element("ViewerChrome")
    }

    /// §2 Scrim: black at alpha, fading to nothing. Takes no touches and is hidden from accessibility.
    private var scrim: some View {
        LinearGradient(
            stops: Geometry.scrimStops.map {
                .init(color: Token.black100.opacity($0.alpha), location: $0.location)
            },
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ui2Element("Scrim")
    }

    /// The top-right circle. It owns the swap's animation phase (R-02): the glyph on show and its
    /// opacity. A new instance appears each time the action returns from `none`.
    private struct TopActionCircle: View {
        let action: TopAction
        let onShare: () -> Void
        let onMenu: () -> Void

        @State private var shownAction: TopAction
        @State private var glyphOpacity = 1.0
        /// Only the latest change may finish its swap: a superseded fade-out's completion is ignored.
        @State private var swapID = 0

        init(action: TopAction, onShare: @escaping () -> Void, onMenu: @escaping () -> Void) {
            self.action = action
            self.onShare = onShare
            self.onMenu = onMenu
            _shownAction = State(initialValue: action)
        }

        var body: some View {
            SwiftUI.Button {
                if action == .share { onShare() } else { onMenu() }
            } label: {
                ChromeGlyph(name: shownAction == .share ? .upload : .moreHorizontal, size: Geometry.actionGlyph)
                    .opacity(glyphOpacity)
                    .ui2Element(shownAction == .share ? "Share glyph" : "Menu glyph")
            }
            .buttonStyle(ChromeCircleStyle())
            .accessibilityLabel(action == .share ? "Share" : "More")
            .accessibilityAddTraits(.isButton)
            .ui2Element("Top-action circle")
            .onChange(of: action) { _, next in swapGlyph(to: next) }
        }

        /// §2: old glyph fades out, the empty circle holds, new glyph fades in. Each fade starts
        /// from the current opacity, so a change mid-swap retargets (OQ-C-134-4).
        private func swapGlyph(to next: TopAction) {
            swapID += 1
            let id = swapID
            guard next != shownAction else {
                withAnimation(.linear(duration: Geometry.glyphFade)) { glyphOpacity = 1 }
                return
            }
            withAnimation(.linear(duration: Geometry.glyphFade)) {
                glyphOpacity = 0
            } completion: {
                guard id == swapID else { return }
                shownAction = next
                withAnimation(.linear(duration: Geometry.glyphFade).delay(Geometry.glyphHold)) {
                    glyphOpacity = 1
                }
            }
        }
    }

    /// One library glyph, painted `color-white-100` and hidden from accessibility (§2).
    private struct ChromeGlyph: View {
        let name: GlyphName
        let size: CGFloat

        var body: some View {
            Image(name.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(Token.white100)
                .accessibilityHidden(true)
        }
    }

    /// §2 Circle: the shared anatomy of both circles (inline, OQ-C-134-9). `radius-circle` parses to
    /// no token, so the shape is SwiftUI's `Circle`.
    private struct ChromeCircleStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                // FLAGGED LITERAL — C-134 §2: background blur 10, as C-102. SwiftUI has no
                // radius-set backdrop blur; the nearest is the system's thinnest material, which
                // renders as flat transparency in simulator capture (§1, deviation 6).
                Circle().fill(.ultraThinMaterial)
                // §2, OQ-C-134-7: pressed fill, no geometry change.
                Circle()
                    .fill(configuration.isPressed ? Token.white30 : Token.white10)
                    .animation(.linear(duration: Geometry.pressFade), value: configuration.isPressed)
                // strokeBorder keeps the 1 pt line inside the 44 pt circle (§2).
                Circle().strokeBorder(Token.white20, lineWidth: Geometry.stroke)
                configuration.label
            }
            .frame(width: Geometry.circle, height: Geometry.circle)
            .contentShape(Circle())                                      // §2: the hit target is the circle
        }
    }
}
