//
//  PercentBar.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-057-percent-bar.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  NOTE-DRIVEN: note 2026-09-12T02:28:29.097Z rewrites most of §4 — t-shirt sizes, a colour
//  OVERRIDE over a threshold-derived default, a solid/gradient fill switch and a fill
//  animation. A note supersedes the contract per property (ui2-component-notes D3/R13), so
//  every place this file departs from C-057 §4 carries that note's id. The contract's §3
//  state matrix is NOT superseded: the four captured states are still its four, and `md`
//  reaches the browser through the Data tab rather than as a fifth variant (see `Size`).
//

import SwiftUI

/// C-057 PercentBar — "the linear progress unit the program's composites share".
///
/// §2: "Two rectangles: a full-width track and a fill anchored to one end of it. No label, no
/// border, no radius, no shadow, no tick marks."
///
/// Width-driven and chrome-free: the bar fills the width its host gives it (§1 deviation 2 —
/// 255 is the sheet's sample; the live consumers are 255, 145 and 328) and states only its own
/// height. Frame, background and outer padding belong to the call site (OQ-PB-1 / OQ-PB-2).
struct PercentBar: View {

    // MARK: - Vocabulary

    /// **note 2026-09-12T02:28:29.097Z** — "the thickenss of the bar is done with a t-shirt
    /// size where the thin variant in figma is the sm and the thick variant is the lg, we just
    /// need one inbetween for md."
    ///
    /// This replaces C-057 §4's `style` {Thick, Thin}. The two Figma values map exactly —
    /// `Thin` → `sm` (2pt), `Thick` → `lg` (16pt) — so the contract's §3 matrix still describes
    /// what is captured; only the vocabulary moved.
    enum Size: String {
        case sm
        case md
        case lg

        var height: CGFloat {
            switch self {
            case .sm: 2                     // §2: `Thin` — 2, declared on the container
            // GAP — note 2026-09-12T02:28:29.097Z asks for "one inbetween for md" and does not
            // size it, and no Figma symbol draws it. 8 is the midpoint of the two designed
            // heights that is also a value the program already spends (`space-element-gap`),
            // chosen rather than the arithmetic 9 for that reason. A `/ui2-component C-057 <url>`
            // run that lands `md` in §3 is what turns this into a measured value.
            case .md: 8
            case .lg: 16                    // §2: `Thick` — 16, from the fill child
            }
        }
    }

    /// §4 `aligned` — "Which end of the track the fill is anchored to — `items-end` /
    /// `items-start` on the source's flex container". Raw values are §3a's labels verbatim,
    /// because those strings are half of the fixture's variant keys (preview-build.md §3
    /// rule 7). Untouched by the note.
    enum Aligned: String {
        case right = "Right"
        case left = "Left"
    }

    /// **note 2026-09-12T02:28:29.097Z** — "a prop to set whether or not we are filling with a
    /// gradiation or filling solid."
    enum FillStyle: String {
        case solid
        case gradient
    }

    /// **note 2026-09-12T02:28:29.097Z** — the easing half of "filling from 0 -> it's value at
    /// a duration with an easing function."
    enum Easing: String {
        case linear
        case easeIn
        case easeOut
        case easeInOut
    }

    /// **note 2026-09-12T02:28:29.097Z** — "there are thresholds for red, yellow, and green.
    /// The prop structure should allow these thresholds to be set at whatever value they want …
    /// a value between 0 - 1 and the user can technically put them in any order, but there
    /// should be a default applied 0.2 red, 0.4 yellow 0.7 green."
    ///
    /// Order-independence is honoured by `stops`, which sorts before use — so whichever colour
    /// carries the lowest threshold becomes the floor band, whatever order the caller wrote.
    struct Thresholds {
        var red: Double
        var yellow: Double
        var green: Double

        /// The note's defaults, verbatim.
        static let standard = Thresholds(red: 0.2, yellow: 0.4, green: 0.7)
    }

    /// **note 2026-09-12T02:28:29.097Z** — "an animation prop that controls the bar's animation
    /// when viewed, which would be the the bar filling from 0 -> it's value at a duration with
    /// an easing function."
    ///
    /// `nil` means no animation, which is also what every fixture passes: an animating bar
    /// would make the simulator capture race the transition and the render nondeterministic.
    struct FillAnimation {
        var duration: Double
        var easing: Easing

        var swiftUI: Animation {
            switch easing {
            case .linear: .linear(duration: duration)
            case .easeIn: .easeIn(duration: duration)
            case .easeOut: .easeOut(duration: duration)
            case .easeInOut: .easeInOut(duration: duration)
            }
        }
    }

    // MARK: - Props

    /// §4 `progress` — "The fraction of the track the fill covers. `fill width = progress ×
    /// track width`". §3b records that the source's sample widths do not demonstrate that law
    /// (two hand-drawn series for the same six percentages); it is the contract's statement,
    /// OQ-C-057-4.
    let progress: Double

    /// §4 `fillColor`, **re-scoped by note 2026-09-12T02:28:29.097Z** from "the fill's colour"
    /// to "the calling surface has control over the color as an override". `nil` — the default —
    /// derives the colour from `progress` against `thresholds`, which is the note's answer to
    /// the contract's own OQ-C-057-3. The contract's prop NAME is kept: a note re-scopes the
    /// semantics, and renaming it would break preview-build.md §3 rule 6.
    var fillColor: Color?

    /// **note 2026-09-12T02:28:29.097Z** — replaces §4's `style`. See `Size`.
    var size: Size = .lg

    /// §4 `aligned`.
    var aligned: Aligned = .right

    /// **note 2026-09-12T02:28:29.097Z**.
    var fillStyle: FillStyle = .solid

    /// **note 2026-09-12T02:28:29.097Z**.
    var thresholds: Thresholds = .standard

    /// **note 2026-09-12T02:28:29.097Z**. Carries no render effect in a still capture.
    var fillAnimation: FillAnimation?

    /// Only ever read when `fillAnimation != nil` — see `shownProgress`. Keeping the
    /// un-animated path free of state is what makes every captured state reachable through the
    /// parameters alone (preview-build.md phase 3).
    @State private var animatedProgress: Double = 0

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: aligned == .right ? .trailing : .leading) {
                track
                fill(trackWidth: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        // §3c: at `progress = 0` "the track renders at its variant's height with no fill; the
        // height is the component's, not the fill's" — the proposed default for the case the
        // source never draws, and the reason the height lives here rather than on the fill
        // (§1 deviation 5: Figma's `Thick` takes its 16 FROM the fill child, so a zero-width
        // fill would collapse it). OQ-C-057-5.
        .frame(height: size.height)
        .onAppear {
            guard let animation = fillAnimation else { return }
            withAnimation(animation.swiftUI) { animatedProgress = clampedProgress }
        }
        .onChange(of: progress) { _, newValue in
            guard let animation = fillAnimation else { return }
            withAnimation(animation.swiftUI) { animatedProgress = Self.clamp(newValue) }
        }
        .ui2Element("PercentBar")     // capture element map — UI2Element.swift
    }

    /// §2: "full width of the host slot; fill `color-white-10`; **square corners**".
    ///
    /// §1 deviation 3 / §3a: the `Thin` + `Left` symbols carry **no background** — six of the
    /// set's twenty-four, and the variant both thin consumers use, verified on C-033's live
    /// instance. Drawn as the source draws it; OQ-C-057-1 asks whether it is intended. `md` is
    /// note-created and no symbol pairs it with `Left`, so it follows the tracked majority.
    private var track: some View {
        Rectangle()
            .fill(drawsTrack ? Token.white10 : Color.clear)
            .ui2Element("Track")
    }

    private var drawsTrack: Bool { !(size == .sm && aligned == .left) }

    /// §2: "height = the track's; width = `progress` × the track's width; **square corners**;
    /// … anchored to the end `aligned` names".
    private func fill(trackWidth: CGFloat) -> some View {
        fillPaint(trackWidth: trackWidth)
            .frame(width: trackWidth * shownProgress)
            .ui2Element("Fill")
    }

    /// Solid or gradient, per the note.
    ///
    /// **The gradient is anchored to the TRACK, not to the fill.** note
    /// 2026-09-12T02:28:29.097Z: "if the bar is 90%, it would gradiate from the red threshold ->
    /// yellow threshold -> green threshold and interpolate all the colors inbetween" — the
    /// stops sit at the threshold fractions of the whole track, and the fill's width reveals as
    /// much of that ramp as `progress` reaches. Laying the ramp across the *fill* instead would
    /// slide every colour as the bar grew, which is not what "the red threshold" names.
    ///
    /// The ramp's origin is the anchored end, because that is where the value axis starts: a
    /// right-anchored bar grows leftward, so its 0 is on the right.
    @ViewBuilder
    private func fillPaint(trackWidth: CGFloat) -> some View {
        if let fillColor {
            // The override wins in both fill styles — the note gives the caller "control over
            // the color", not control over the ramp's endpoints.
            Rectangle().fill(fillColor)
        } else {
            switch fillStyle {
            case .solid:
                Rectangle().fill(bandColor)
            case .gradient:
                LinearGradient(
                    stops: stops.map { Gradient.Stop(color: $0.color, location: $0.threshold) },
                    startPoint: aligned == .right ? .trailing : .leading,
                    endPoint: aligned == .right ? .leading : .trailing
                )
                .frame(width: trackWidth)
                .frame(width: trackWidth * shownProgress, alignment: aligned == .right ? .trailing : .leading)
                .clipped()
            }
        }
    }

    // MARK: - Colour

    /// The note's three colours, sorted by threshold so any authoring order works.
    private var stops: [(threshold: Double, color: Color)] { Self.stops(thresholds) }

    private static func stops(_ thresholds: Thresholds) -> [(threshold: Double, color: Color)] {
        [
            (clamp(thresholds.red), red),
            (clamp(thresholds.yellow), yellow),
            (clamp(thresholds.green), green)
        ]
        .sorted { $0.0 < $1.0 }
        .map { (threshold: $0.0, color: $0.1) }
    }

    /// Solid mode: the colour of the highest threshold `progress` has reached, and the lowest
    /// band below that — the note names thresholds at which a colour STARTS, so the first band
    /// is the floor rather than a hole.
    private var bandColor: Color { Self.solidFillColor(progress: progress, thresholds: thresholds) }

    /// The solid-fill colour this bar paints at `progress` when no `fillColor` override is
    /// given. Exposed so a composite that colours its own text "exactly the colour C-057
    /// computes for its solid fill" (C-054 AvatarProgressRow §1 deviation 4) reads the same
    /// computation instead of restating the ramp.
    static func solidFillColor(progress: Double, thresholds: Thresholds = .standard) -> Color {
        let ramp = stops(thresholds)
        let reached = ramp.last { clamp(progress) >= $0.threshold }
        return reached?.color ?? ramp[0].color
    }

    // FLAGGED LITERALS — C-057 §2: the set spends three fill colours and binds **none** of
    // them. `#ff4759` is hex-equal to `color-negative` but unbound; `#e3eb4b` and `#4deb4b`
    // have no token and no Figma variable anywhere. Emitted as the literals the source states
    // per preview-build.md §3 rule 4, NOT promoted to `Token.negative` / `Token.warning` /
    // `Token.positive` — and note 2026-09-12T02:28:29.097Z, which asks for "red, yellow, and
    // green", does not say WHICH, so it settles the mechanism and not the palette. §2: C-062's
    // ruled ramp is #ff4759 → #ffb53e → #6cff73, so the two completion components share only
    // their red. OQ-C-057-2 is the ruling that would replace these three lines with tokens.
    private static let red = Color(red: 1.0, green: 0.2784, blue: 0.349, opacity: 1)        // #ff4759
    private static let yellow = Color(red: 0.8902, green: 0.9216, blue: 0.2941, opacity: 1) // #e3eb4b
    private static let green = Color(red: 0.302, green: 0.9216, blue: 0.2941, opacity: 1)   // #4deb4b

    // MARK: - Progress

    /// §3c: "`progress > 1` / negative … Clamping is a build decision the contract does not
    /// make." It is made here, and clamping matches what the source does anyway — `Thin`'s
    /// `overflow: clip` is why C-033's 222pt fill reads as full inside its 145pt slot.
    private var clampedProgress: Double { Self.clamp(progress) }

    /// Prop-driven unless an animation was asked for, so a still capture is deterministic.
    private var shownProgress: Double {
        fillAnimation == nil ? clampedProgress : animatedProgress
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
