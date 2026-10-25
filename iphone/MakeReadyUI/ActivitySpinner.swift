//
//  ActivitySpinner.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-076-activity-spinner in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-076 ActivitySpinner — the 24pt indeterminate ring shown while the app works on something.
///
/// §2: "A single leaf glyph: two concentric ring strokes on one square canvas, nothing else."
/// A full `color-white-10` track, and over it an arc in `color` whose alpha ramps 0→1
/// clockwise from 12 o'clock to 237.7°, cut flat there. The drawn pose is phase 0; the arc
/// turns about the centre, one full turn per `period` (OQ-C-076-001).
///
/// §2 / R-16: a glyph states its own fixed `size`×`size` footprint rather than filling the
/// width it is given; it paints no background and adds no outer padding.
struct ActivitySpinner: View {

    /// C-076 §4 `direction` — `.clockwise` · `.counterclockwise` (R-36: nested).
    enum RotationDirection {
        case clockwise
        case counterclockwise

        /// SwiftUI's y-down space turns positive degrees clockwise on screen.
        var sign: Double {
            switch self {
            case .clockwise: return 1
            case .counterclockwise: return -1
            }
        }
    }

    /// C-076 §4 `size` — outer diameter on both axes; default 24 is the designed value.
    var size: CGFloat = 24
    /// C-076 §4 `strokeWidth` — width of both the track and the arc band; default 2 is designed.
    var strokeWidth: CGFloat = 2
    /// C-076 §4 `color` — tint of the arc only; OQ-C-076-004 (ruled 2026-09-24): "`color` tints
    /// the arc only; the track stays `color-white-10` regardless."
    var color: Color = Token.accent
    /// C-076 §4 `period` — seconds per full turn; OQ-C-076-001: "1.0s clockwise linear is a
    /// great default."
    var period: TimeInterval = 1.0
    /// C-076 §4 `direction` — default clockwise, the way the drawn comet's tail already trails.
    var direction: RotationDirection = .clockwise

    /// R-02: the rotation phase is ephemeral animation state, never a prop. `false` is the
    /// drawn pose (phase 0), which is what every capture reproduces.
    @State private var spinning = false

    var body: some View {
        ZStack {
            track
            arc
                // §2 Pose: "Rotation turns the whole arc about the centre; the track is
                // rotationally symmetric and need not turn." A full turn ends where it began,
                // so a render with animations disabled lands back on phase 0.
                .rotationEffect(.degrees(spinning ? direction.sign * Self.fullTurn : 0))
        }
        .frame(width: size, height: size)
        .onAppear {
            // §3 rotation (OQ-C-076-001): linear, repeating without pause, from phase 0.
            // OQ-C-076-002 (ruled): it keeps rotating under Reduce Motion — no branch on it.
            withAnimation(.linear(duration: period).repeatForever(autoreverses: false)) {
                spinning = true
            }
        }
        // OQ-C-076-003 (ruled): "accessibilityHidden(true); the consumer labels the region."
        .accessibilityHidden(true)
        .ui2Element("ActivitySpinner")                // capture element map — UI2Element.swift
    }

    /// §2 Track (`base`): a full circle, stroke `strokeWidth` centred on r = size/2 −
    /// strokeWidth/2 (band r 10–12 at the defaults), colour `color-white-10`.
    private var track: some View {
        Circle()
            .strokeBorder(Token.white10, lineWidth: strokeWidth)
            .ui2Element("Track")
    }

    /// §2 Arc (`fill`): the same band over the track, α 0 at 12 o'clock rising linearly
    /// clockwise to α 1 at 237.7°, cut flat (butt, radial) there; the remaining 122.3° shows
    /// the track alone.
    private var arc: some View {
        Circle()
            .inset(by: strokeWidth / 2)               // same band as the track's strokeBorder
            .trim(from: 0, to: Self.sweepTurn)
            .stroke(
                AngularGradient(
                    stops: [
                        .init(color: color.opacity(0), location: 0),
                        .init(color: color, location: Self.sweepTurn)
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt)
            )
            // `Circle`'s trim and an AngularGradient both start at 3 o'clock; §2 starts the
            // arc at 12, so the pair turns back a quarter together.
            .rotationEffect(.degrees(-90))
            .ui2Element("Arc")
    }

    // FLAGGED LITERAL — C-076 §2: "the 237.7° sweep (0.660 turn) and the gradient stop at
    // 34.6 % — each traces to the export and has no token family to live in." The source's
    // α0 stop at 34.6 % of a gradient zeroed at 237.7° IS 12 o'clock (237.7° + 124.6° ≈ 362°),
    // so the visible ramp is spelled here as α 0 at 0 → α 1 at the sweep, which is §2's own
    // reading ("the visible arc is one monotonic 0→1 ramp").
    private static let sweepTurn: CGFloat = 237.7 / 360

    /// One full turn, in degrees.
    private static let fullTurn: Double = 360
}
