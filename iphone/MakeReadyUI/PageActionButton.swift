//
//  PageActionButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-048-page-action-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-048 PageActionButton — "the full-width page-level action button (Save / Create / Done)".
///
/// §2: "A single-line label inside a rounded pill, with an **optional glyph** at the leading or
/// trailing side. No sub-components (the glyph is library artwork)."
///
/// Chrome-free and width-driven (R-16): §2 "**Width is the consumer's.**" The view fills the
/// width it is given and states only its own height (38 Md / 44 Lg); the call site supplies
/// width and ground.
struct PageActionButton: View {

    /// C-048 §4 `role: affirmative | destructive | prominent | secondary | accent` — "selects the
    /// §2 paint row". Nested per R-36.
    enum Role: String {
        case affirmative
        case destructive
        case prominent
        case secondary
        case accent
    }

    /// C-048 §4 `size: md | lg` — "selects the §2 size column (38 / 44 tall, label type, glyph
    /// box)". Nested per R-36.
    enum Size: String {
        case md
        case lg
    }

    /// C-048 §4 `glyphPosition: leading | trailing` — "the side the glyph sits on (Figma
    /// `icon=Left/Right`)". Nested per R-36.
    enum GlyphPosition: String {
        case leading
        case trailing
    }

    /// C-048 §4 `layout: spread | centered` — "`spread` = label and glyph at opposite edges;
    /// `centered` = centred together with an 8pt gap". Nested per R-36.
    enum Layout: String {
        case spread
        case centered
    }

    /// C-048 §4 `label: String` — "the label; one line, no wrap, no ellipsis (OQ-C-048-4); also
    /// the accessibility label".
    let label: String
    /// C-048 §4 `role`.
    let role: Role
    /// C-048 §4 `size` — default `.md` ("Figma's default `size=Md`; every consumer to date is Md").
    var size: Size = .md
    /// C-048 §4 `glyph: Glyph?` — "any glyph of the era's library, by name … `nil` gives the
    /// label-only rows". Default `nil` (Figma's default `icon=None`).
    var glyph: GlyphName? = nil
    /// C-048 §4 `glyphPosition` — default `.trailing`; no effect when `glyph == nil`.
    var glyphPosition: GlyphPosition = .trailing
    /// C-048 §4 `layout` — default `.spread` (Figma's default `content=Between`); no effect when
    /// `glyph == nil`.
    var layout: Layout = .spread
    /// C-048 §4 `enabled: Bool` (default true) — "`false` renders the Muted look (OQ-C-048-1)
    /// and swallows taps; reported to accessibility". Bare positive boolean (R-34/R-35).
    var enabled: Bool = true
    /// C-048 §4 `onTap: () -> Void` (default `{}`, R-03) — "fired once per tap; never invoked
    /// while `enabled == false`". No render effect.
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            pill
        }
        // §2 Pressed: "the whole button at 0.6 opacity while pressed; no scale, no colour change
        // (OQ-C-048-2)". A custom ButtonStyle (R-11) owns it — and, unlike `.plain`, a custom
        // style paints nothing of its own when disabled, so `.disabled` below swallows taps and
        // reports the state to accessibility without dimming §2's full-strength Muted paint.
        .buttonStyle(PressedOpacityStyle())
        // §3: "A disabled button ignores taps and never invokes `onTap`"; §2: "A disabled button
        // never shows [pressed]" — a disabled Button never reports isPressed.
        .disabled(!enabled)
        // §2: "**Hit target** = the button's own frame (38 or 44 × width)."
        .ui2Element("PageActionButton")           // capture element map — UI2Element.swift
    }

    // §2 By size: Md "**38** — 36pt content box (8 + 20 + 8) plus a 1px ring outside it"; Lg
    // "**44** — fixed, the 1px ring inside the 44 (content row centred, 11pt above and below it
    // inside the ring)". Both are the same construction — padding, then the 1px ring — with
    // the vertical inset per size: 1 + 8 + 20 + 8 + 1 = 38, 1 + 11 + 20 + 11 + 1 = 44.
    private var pill: some View {
        content
            .frame(maxWidth: .infinity)           // §2: "No glyph: the label is centred"
            .padding(.horizontal, Self.padH)
            .padding(.vertical, padV)
            // The ring is layout as well as paint: `.padding` grows the box by 1pt per side and
            // `strokeBorder` draws inside that ring. Prominent's ring is white (OQ-C-048-002), so
            // its fill runs under the ring — clipping the fill at the inner radius left a dark
            // anti-aliased seam between fill and ring at the corners (capture 2026-10-20).
            // Every other role's fill is transparent, so this moves nothing there.
            .padding(Self.hairline)
            .background(look.fill)
            .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card + Self.hairline))
            .overlay(
                RoundedRectangle(cornerRadius: Token.Radius.card + Self.hairline)
                    .strokeBorder(look.stroke, lineWidth: Self.hairline)
            )
            // §2 "Hit target = the button's own frame": every role but Prominent fills
            // `Token.transparent`, and a ButtonStyle hit-tests only painted pixels — without this
            // only the label and the 1px ring took taps (owner, 2026-10-26).
            .contentShape(RoundedRectangle(cornerRadius: Token.Radius.card + Self.hairline))
    }

    /// §2 "Content layout" — only when a glyph is present. `spread` (Figma `content=Between`):
    /// "label and glyph at opposite inner edges"; `centered` (`content=Centered`): "glyph and
    /// label centred together with an **8pt gap** (`space-element-gap`). Order glyph·label for
    /// `leading`, label·glyph for `trailing`." No glyph: the label alone, centred by `pill`.
    @ViewBuilder
    private var content: some View {
        HStack(spacing: 0) {
            if let glyph, glyphPosition == .leading {
                glyphView(glyph)
                gap
            }
            labelView
            if let glyph, glyphPosition == .trailing {
                gap
                glyphView(glyph)
            }
        }
    }

    /// The space between label and glyph: a spring for `spread`, never closer than 8pt
    /// (OQ-C-048-003, owner 2026-10-20: "the same gap as `centered`"), and the fixed 8pt
    /// `space-element-gap` for `centered`.
    @ViewBuilder
    private var gap: some View {
        switch layout {
        case .spread:
            Spacer(minLength: Token.Space.elementGap)
        case .centered:
            Color.clear.frame(width: Token.Space.elementGap, height: Self.contentRow)
        }
    }

    private var labelView: some View {
        Text(label)
            // §2 label: Md `type-button-label` (12/20), Lg `type-page-action-label-lg` (14/20).
            .designTextStyle(size == .lg ? Token.TypeStyle.pageActionLabelLg : Token.TypeStyle.buttonLabel)
            .foregroundColor(look.labelColor)
            // OQ-C-048-4 (owner 2026-09-17): "single line, no wrap, no ellipsis". `lineLimit(1)`
            // alone would tail-truncate; `fixedSize` keeps the run at its ideal width instead.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            // §2: "content row 20 tall" at both sizes. `designTextStyle` spells the 20pt line
            // height as lineSpacing, which applies only between lines, so the run is framed to 20.
            .frame(height: Self.contentRow)
            .ui2Element("Label")
    }

    /// §2 Glyph: "a template glyph from the library, drawn in its box and tinted per the paint
    /// table" — box 14×14 Md, 20×20 Lg. OQ-C-048-004 (owner 2026-10-20): "`glyph` accepts
    /// template glyphs only, and every glyph takes the role's tint" — so the image is always
    /// rendered as a template, a full-colour library glyph included. Decorative — the label is
    /// the accessibility label (§4 #1).
    private func glyphView(_ name: GlyphName) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: glyphBox, height: glyphBox)
            .foregroundColor(look.glyphColor)
            .accessibilityHidden(true)
            .ui2Element("Glyph")
    }

    /// §2 "Paint by role (both sizes)" — the whole delta between roles is paint; geometry is
    /// identical. OQ-C-048-1 (ruled): `enabled == false` is the Muted look **regardless of
    /// role**, which is why this reads `enabled` first.
    private var look: Look {
        guard enabled else {
            // §2 disabled row: no fill, 1px `color-layout-border`, `color-text-secondary` label;
            // a disabled prominent button drops its white fill. OQ-C-048-001 (owner 2026-10-20):
            // the glyph is `color-text-secondary`, matching its label.
            return Look(fill: Token.transparent, stroke: Token.layoutBorder,
                        labelColor: Token.textSecondary, glyphColor: Token.textSecondary)
        }
        switch role {
        case .affirmative:
            // §2: no fill, 1px `color-positive`, `color-positive` label, `color-white-50` glyph.
            return Look(fill: Token.transparent, stroke: Token.positive,
                        labelColor: Token.positive, glyphColor: Token.white50)
        case .destructive:
            // §2: no fill, 1px `color-negative`, `color-negative` label, `color-white-50` glyph.
            return Look(fill: Token.transparent, stroke: Token.negative,
                        labelColor: Token.negative, glyphColor: Token.white50)
        case .accent:
            // §2 accent (Figma Purple): no fill, 1px `color-accent`, `color-accent` label,
            // `color-white-50` glyph.
            return Look(fill: Token.transparent, stroke: Token.accent,
                        labelColor: Token.accent, glyphColor: Token.white50)
        case .secondary:
            // §2 secondary (Muted, enabled — D57): no fill, 1px `color-layout-border`,
            // `color-text-secondary` label, `color-white-50` glyph.
            return Look(fill: Token.transparent, stroke: Token.layoutBorder,
                        labelColor: Token.textSecondary, glyphColor: Token.white50)
        case .prominent:
            // §2 prominent (White): fill `color-text-primary`, 1px `color-text-primary` ring
            // (OQ-C-048-002), `color-black` label and glyph.
            return Look(fill: Token.textPrimary, stroke: Token.textPrimary,
                        labelColor: Token.black, glyphColor: Token.black)
        }
    }

    /// One row of §2's paint table.
    private struct Look {
        let fill: Color
        let stroke: Color
        let labelColor: Color
        let glyphColor: Color
    }

    /// OQ-C-048-2 (owner 2026-09-17): "the whole button at 0.6 opacity while pressed, no scale,
    /// no colour change". Press is ephemeral feedback (R-02), owned by the style.
    private struct PressedOpacityStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? PageActionButton.pressedOpacity : 1)
        }
    }

    /// §2 By size: the vertical inset inside the ring — Md 8 (36pt content box), Lg 11.
    private var padV: CGFloat {
        switch size {
        case .md: return Self.padVMd
        case .lg: return Self.padVLg
        }
    }

    /// §2 By size: "glyph box **14×14**" Md, "**20×20**" Lg.
    private var glyphBox: CGFloat {
        switch size {
        case .md: return Self.glyphBoxMd
        case .lg: return Self.glyphBoxLg
        }
    }

    // FLAGGED LITERAL — C-048 §2: "horizontal padding 16 (**literal, flagged** — no
    // button-padding token)", both sizes.
    private static let padH: CGFloat = 16

    // FLAGGED LITERAL — C-048 §2: "The 1px stroke is a **literal, flagged** (the program-wide
    // hairline)."
    private static let hairline: CGFloat = 1

    // FLAGGED LITERAL — C-048 §2 By size: "content row 20 tall" (both sizes); flagged as this
    // button's own geometry by OQ-C-048-5 (owner 2026-10-20).
    private static let contentRow: CGFloat = 20
    // FLAGGED LITERAL — C-048 §2 By size: Md "36pt content box (8 + 20 + 8)"; OQ-C-048-5.
    private static let padVMd: CGFloat = 8
    // FLAGGED LITERAL — C-048 §2 By size: Lg "11pt above and below it inside the ring";
    // OQ-C-048-5.
    private static let padVLg: CGFloat = 11
    // FLAGGED LITERAL — C-048 §2 By size: "glyph box **14×14**" Md; OQ-C-048-5.
    private static let glyphBoxMd: CGFloat = 14
    // FLAGGED LITERAL — C-048 §2 By size: "glyph box **20×20**" Lg; OQ-C-048-5.
    private static let glyphBoxLg: CGFloat = 20

    /// §2 Pressed / OQ-C-048-2: "0.6 opacity while pressed" — an owner-ruled value with no
    /// opacity token; it renders in no capture (no prop reaches the pressed state).
    private static let pressedOpacity: Double = 0.6
}
