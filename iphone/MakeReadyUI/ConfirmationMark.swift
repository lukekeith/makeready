//
//  ConfirmationMark.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-109-confirmationmark in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-109 ConfirmationMark — an animated icon in a coloured circle, for confirmation screens,
/// alerts, warnings and other validation views (owner description).
///
/// §2: two layers centred on each other — a **Disc** filled with the tone colour and a template
/// **Glyph** tinted `color-background-alt` at 40% of the diameter. Width-driven and square
/// (R-16): the diameter is the width the call site gives it (invite-member gives 100).
///
/// §3 animation (OQ-C-109-002, ratified): with `animated` the mark plays once on appear — the
/// disc scales 0.6 → 1.0 and fades in on a spring, the glyph scales 0.4 → 1.0 and fades in on
/// the same spring 0.12 s later. `animated: false` or Reduce Motion renders settled. A tone
/// change while visible does not replay it. The animation phase is the only internal state (R-02).
struct ConfirmationMark: View {

    /// C-109 §4 `tone` — the disc colour and the glyph (§3, OQ-C-109-001 ratified).
    enum Tone: String {
        case success, warning, error

        var discColor: Color {
            switch self {
            case .success: return Token.success
            case .warning: return Token.warning
            case .error: return Token.error
            }
        }

        var glyph: GlyphName {
            switch self {
            case .success: return .checkmarkCarbon
            case .warning: return .alertTriangle
            case .error: return .closeLargeCarbon
            }
        }

        /// §2 accessibility: the mark's one element carries its tone's label.
        var label: String {
            switch self {
            case .success: return "Success"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
    }

    /// C-109 §4: `tone` — required (R-07).
    let tone: Tone
    /// C-109 §4: `animated` — `true` plays the appear animation once; `false` renders settled.
    let animated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// R-02: animation phase only.
    @State private var appeared = false

    // FLAGGED LITERAL — C-109 §2: 40% glyph ratio, geometry of the design, not a token.
    private static let glyphRatio: CGFloat = 0.4
    // FLAGGED LITERAL — C-109 §3 / OQ-C-109-002: spring response 0.35 s, damping 0.7 —
    // `motion-confirmation-appear` is ruled but not yet minted in the token register.
    private static let appear = Animation.spring(response: 0.35, dampingFraction: 0.7)
    // FLAGGED LITERAL — C-109 §3 / OQ-C-109-002: glyph starts 0.12 s after the disc.
    private static let glyphDelay: Double = 0.12
    // FLAGGED LITERAL — C-109 §3 / OQ-C-109-002: start scales (disc 0.6, glyph 0.4).
    private static let discStartScale: CGFloat = 0.6
    private static let glyphStartScale: CGFloat = 0.4

    private var settled: Bool { !animated || reduceMotion || appeared }

    var body: some View {
        // R-16: square at the width it is given — the height follows the width, never the
        // height proposal (the capture harness proposes 0).
        SquareLayout {
            mark
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone.label)
        .accessibilityAddTraits(.isImage)
        .ui2Element("ConfirmationMark")
        .onAppear {
            guard animated, !reduceMotion else { return }
            appeared = true
        }
    }

    private var mark: some View {
        // §2 Disc: `radius-circle` is NOT PARSED ("50%"), so the Circle shape is what names it —
        // a true circle at any size (§1 deviation 2).
        Circle()
            .fill(tone.discColor)
            .ui2Element("Disc")
            .scaleEffect(settled ? 1 : Self.discStartScale)
            .opacity(settled ? 1 : 0)
            .animation(Self.appear, value: appeared)
            .overlay {
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height) * Self.glyphRatio
                    Image(tone.glyph.rawValue, bundle: .ui2Preview)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: side, height: side)
                        .foregroundStyle(Token.backgroundAlt)
                        .ui2Element("Glyph")
                        .scaleEffect(settled ? 1 : Self.glyphStartScale)
                        .opacity(settled ? 1 : 0)
                        .animation(Self.appear.delay(Self.glyphDelay), value: appeared)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
    }
}

/// Sizes its one subview as a square whose side is the proposed width (R-16: width-driven,
/// intrinsic height).
private struct SquareLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let side = proposal.width ?? subviews.first?.sizeThatFits(.unspecified).width ?? 0
        return CGSize(width: side, height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        }
    }
}
