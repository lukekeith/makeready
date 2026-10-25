//
//  PercentDisc.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-062-percent-disc.md (§2 geometry, §2a the
//  colour ramp, §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or
//  flag (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-062 PercentDisc — a completion number, coloured by how good that number is.
///
/// §2: a constant **80×80 slot**, a disc of the variant's diameter centred in it, and a
/// number block centred in the disc. No ring, no track, no stroke, no icon.
///
/// **The colour is computed, not chosen** (§2a, owner ruling 2026-09-11): one colour derived
/// from `percent` along a red→amber→green ramp drives the disc fill at 20% and the text at
/// 100%. There are no bands and no thresholds. `size` selects the diameter alone and is
/// independent of `percent` (§4, owner ruling closing OQ-C-062-9).
///
/// Chrome-free: it states its own 80×80 footprint, paints no page background and adds no
/// outer padding. The outer margin and ground belong to the ViewRegistry call site
/// (preview-build.md OQ-PB-1 / OQ-PB-2).
struct PercentDisc: View {

    /// C-062 §4 `size` — selects the disc diameter ONLY (§3a). Raw values are the contract's
    /// enumerated values verbatim (preview-build.md §3 rule 5), including `size6`, which §1
    /// deviation 3 records as a Figma-side naming defect rather than silently renaming.
    enum Size: String {
        case green1 = "Green 1"
        case green2 = "Green 2"
        case yellow1 = "Yellow 1"
        case yellow2 = "Yellow 2"
        case red1 = "Red 1"
        case size6 = "size6"

        /// §3a's ladder: 80 / 64 / 56 / 48 / 44 / 40.
        var diameter: CGFloat {
            switch self {
            case .green1: return 80
            case .green2: return 64
            case .yellow1: return 56
            case .yellow2: return 48
            case .red1: return 44
            case .size6: return 40
            }
        }
    }

    /// C-062 §4: `percent` — the number drawn, AND the sole input to the colour ramp (§2a).
    let percent: Int
    /// C-062 §4: `size` — the disc diameter (§3a). Independent of `percent`.
    let size: Size
    /// C-062 §4: `statusColor` — "Optional override, absorbed from C-073 (2026-09-11). When
    /// supplied it replaces the ramp's computed colour for both the 20% ground and the 100%
    /// text (§2a); `percent` then drives the number only. Omitted ⇒ the ramp."
    ///
    /// Added 2026-09-21 by the C-031 build: the prop was in this row's contract since the
    /// merge but the build never carried it, and C-031 EnrollmentStatusRow is its designed
    /// consumer (OQ-C-062-11's policy — "a consumer supplies statusColor only when a sibling
    /// element must agree with the disc"). `nil` leaves every existing capture unchanged.
    var statusColor: Color?

    var body: some View {
        // §2: Slot — 80×80 in every variant, no fill, contents centred on both axes. This is
        // the component's footprint (§3c): the disc shrinks inside it, so a consumer reserves
        // 80 for every variant and never re-flows.
        disc
            .frame(width: Self.slot, height: Self.slot)
            .ui2Element("PercentDisc")                // capture element map — UI2Element.swift
    }

    private var disc: some View {
        // §2: a circle of the variant's diameter, centred in the slot, filled the ramp colour
        // at 20% opacity. `radius-circle` is the one token row the generator reports as NOT
        // PARSED (it is "50%", not a point value), so the shape is what names it.
        Circle()
            .fill(discColor.opacity(Self.groundOpacity))
            .frame(width: size.diameter, height: size.diameter)
            .overlay(numberBlock)
            .ui2Element("Disc")
    }

    /// §2: the number block is **28×24 and identical in all six variants** — it does not scale
    /// with the disc. A centred row of two runs with no gap (19 + 9 = 28 exactly).
    private var numberBlock: some View {
        // §2: the `%` is "centred against the number's 24pt box (y-offset 6), not
        // baseline-aligned". An HStack's default vertical alignment is `.center`, which places
        // the 12pt run's box in the middle of the 24pt one — offset 6, exactly the measurement.
        // Spelling it as `.firstTextBaseline` would be the natural-looking choice and wrong.
        HStack(alignment: .center, spacing: 0) {
            Text("\(percent)")
                .designTextStyle(Self.numberStyle)
                // §2: the number's designed line box is **24**, and §2 measures the whole block
                // at 28×24. SwiftUI has no line-height: `designTextStyle` spells 24 as
                // lineSpacing, which is leading applied only BETWEEN lines, so a single-line run
                // reports its ~17pt font box instead and the block comes out 7pt short. Stating
                // the box explicitly makes the rendered anatomy match the contract's — the
                // pixels are unchanged either way (both runs centre on the same mid-line), but
                // the element map a comment anchors to is now the 24 §2 specifies. Same fix, and
                // the same reason, as C-045 TextInput's content row.
                .frame(height: Self.numberLineBox)
                .ui2Element("Number")
            Text("%")
                .designTextStyle(Self.percentSignStyle)
                .ui2Element("Percent sign")
        }
        // §2: both runs take the disc colour at full opacity.
        .foregroundColor(discColor)
        .ui2Element("Number block")
    }

    // MARK: - §2a The colour ramp (owner ruling 2026-09-11)

    /// §2a: "a disc either computes its colour or is told it, never both" — the override, when
    /// supplied, replaces the ramp for the ground AND the text.
    ///
    /// GAP — OQ-C-062-11's answer says the override's 20% ground "cites color-positive-20 (and
    /// the sibling -20 tokens)", but no `color-positive-20` / `-highlight-20` / `-negative-20`
    /// row exists in the register yet, and a `Color` prop cannot name which one it would be.
    /// Until those rows are minted the ground is the override at `groundOpacity`, the same
    /// construction §2a states for the ramp.
    private var discColor: Color {
        statusColor ?? rampColor
    }

    /// §2a: clamp `percent` to 0…100, then interpolate componentwise in sRGB between the two
    /// adjacent anchors — `color-negative`→`color-warning` over 0…50, then
    /// `color-warning`→`color-positive` over 50…100 — rounding each channel to 8 bits.
    ///
    /// The anchors are read back out of the generated `Token` members rather than restated as
    /// hex, so the ramp cannot drift from `tokens.md` (preview-build.md §3 rule 4: every colour
    /// resolves to a Token member — here three of them, with the values between them derived).
    private var rampColor: Color {
        let p = min(max(percent, 0), 100)
        let (from, to, t) = p <= Self.midAnchor
            ? (Token.negative, Token.warning, Double(p) / Double(Self.midAnchor))
            : (Token.warning, Token.positive, Double(p - Self.midAnchor) / Double(Self.midAnchor))
        return Self.lerp(from, to, t)
    }

    /// §2a rounds each channel to the nearest integer, so the render matches the contract's
    /// worked values exactly (0 → #FF4759, 24 → #FF7C4C, 50 → #FFB53E, 65 → #D3CB4E,
    /// 78 → #ADDE5C, 100 → #6CFF73) rather than landing a fraction off them.
    private static func lerp(_ from: Color, _ to: Color, _ t: Double) -> Color {
        let a = components(from)
        let b = components(to)
        return Color(
            red: quantize(a.r + (b.r - a.r) * t),
            green: quantize(a.g + (b.g - a.g) * t),
            blue: quantize(a.b + (b.b - a.b) * t)
        )
    }

    private static func quantize(_ channel: Double) -> Double {
        (channel * 255).rounded() / 255
    }

    private static func components(_ color: Color) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    /// §2: "Number block — **28×24**", and the number's own designed line box is 24.
    private static let numberLineBox: CGFloat = 24

    /// §2a: the ramp's mid anchor sits at 50.
    private static let midAnchor = 50

    /// §2a: "Disc fill = that colour at 20% opacity."
    private static let groundOpacity: Double = 0.2

    /// §2 / §3c: the slot is 80×80 in every variant.
    private static let slot: CGFloat = 80

    // FLAGGED LITERAL — C-062 §2: the number's "**Bold 14 / 24** has no token row. It is the
    // program's fourth Bold-14 leading — beside `type-title-card` (Bold 14/20),
    // `type-nav-label` (Bold 14/16) and C-046's Bold 14/14 — and its 24 leading matches
    // `type-input` / `type-nav-action` (both Regular 14/24). Carried as a per-component literal
    // rather than a unilateral mint" — OQ-C-062-3.
    private static let numberStyle = DesignTextStyle(
        weight: .bold, size: 14, lineHeight: 24, tracking: 0
    )

    // FLAGGED LITERAL — C-062 §2: the `%`'s "**Semibold 9 / 12** has no token row and is the
    // smallest type in the program by 3pt (`type-caption` and friends bottom out at 12)" —
    // OQ-C-062-3. §2 also records that the glyph is DRAWN by the component, not carried in the
    // prop, which is why it is a second Text run here and not part of `percent`.
    private static let percentSignStyle = DesignTextStyle(
        weight: .semibold, size: 9, lineHeight: 12, tracking: 0
    )
}
