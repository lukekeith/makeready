//
//  ActivityTypeCard.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-080-activitytypecard in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  §5 Consumes no registry rows: the glyph is a library glyph (Glyph.swift), the title and
//  description are text. Rulings honoured:
//  • OQ-C-080-001 — pressed = the whole tile at 0.6 opacity while the finger is down, no
//    geometry change; ephemeral internal state (R-02), not a prop.
//  • OQ-C-080-002 — no disabled state, no `enabled` prop; the grid gates taps while Creating.
//  • OQ-C-080-003 — title one line, tail-truncated; the description box always reserves three
//    lines (54) and tail-truncates beyond three, so the tile stays 180 tall at 200 wide.
//

import SwiftUI

/// C-080 ActivityTypeCard — "one selectable activity type (glyph + title + description tile)".
///
/// Width-driven, intrinsic height (R-16, §2): the tile fills the width its grid gives it and
/// states its own height (180 at the designed 200). The rounded `color-white-10` fill is the
/// tile's own surface (§2), not a call-site background; the tile adds no outer padding.
struct ActivityTypeCard: View {

    // C-080 §4's four rows, one parameter each, in the contract's order (R-05).

    /// C-080 §4: `glyph` — the type's icon from the glyph library, tinted `color-accent`.
    let glyph: GlyphName
    /// C-080 §4: `title` — the type name, one line.
    let title: String
    /// C-080 §4: `description` — what the type does, up to three lines.
    let description: String
    /// C-080 §4: `onTap` — the tile was tapped; the caller decides what it creates (R-03 /
    /// R-04). No render effect; a defaulted no-op so the promoted view keeps its signature.
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            // §2: "Vertical stack, leading-aligned, stack gap `space-row-gap` (24)".
            VStack(alignment: .leading, spacing: Token.Space.rowGap) {
                // §2.1 Glyph: "library glyph, 32×32 box, tinted `color-accent`".
                // FLAGGED LITERAL — C-080 §2: glyph box 32, no glyph-size token in 2.0. The
                // library's own `.lg` scale is exactly 32, so the literal lives there.
                // Decorative (§2 Accessibility): the tile's label is the title.
                Glyph(glyph, size: .lg, tint: Token.accent)
                    .accessibilityHidden(true)
                    .ui2Element("Glyph")

                // §2.2 Details: "vertical stack, gap 0, fills the width".
                VStack(alignment: .leading, spacing: 0) {
                    // §2 Title: "`type-title-tile` (Bold 17/22), `color-text-primary`, one line
                    // (22)". OQ-C-080-003: tail truncation. Framed to the token's own line box:
                    // `designTextStyle` spells leading as lineSpacing, which a single line ignores.
                    Text(title)
                        .designTextStyle(Token.TypeStyle.titleTile)
                        .foregroundColor(Token.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, minHeight: Self.titleLineBox,
                               maxHeight: Self.titleLineBox, alignment: .leading)
                        .ui2Element("Title")

                    // §2 Description: "`type-footnote` (13/18), `color-white-70`, wraps; its box
                    // reserves three lines (54)". §1 deviation 2: the 70% layer opacity renders
                    // as the solid `color-white-70`. OQ-C-080-003: tail-truncates beyond three.
                    // Leading: only the difference between the 18pt line box and the face's
                    // natural line is spent, half above and half below each line, so each line
                    // is exactly 18 and three lines are exactly 54.
                    Text(description)
                        .font(Token.TypeStyle.footnote.font)
                        .tracking(Token.TypeStyle.footnote.tracking)
                        .lineSpacing(Self.descriptionLeading)
                        .padding(.vertical, Self.descriptionLeading / 2)
                        .foregroundColor(Token.white70)
                        .lineLimit(Self.descriptionLines)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity,
                               minHeight: Self.descriptionBox, maxHeight: Self.descriptionBox,
                               alignment: .topLeading)
                        .ui2Element("Description")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Details")
            }
            // §2: "padding `space-tile-padding` (24) on all four sides".
            .padding(Token.Space.tilePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2: "fill `color-white-10`, corner radius `radius-card` (8), no stroke, no shadow".
            .background(
                RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
                    .fill(Token.white10)
            )
            .contentShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        }
        .buttonStyle(PressedDim())
        // §2 Accessibility (R-17): "the whole tile is one button — `.isButton` trait, label =
        // title, hint = description; the glyph is decorative".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(description)
        .accessibilityAddTraits(.isButton)
        .ui2Element("ActivityTypeCard")               // capture element map — UI2Element.swift
    }

    // OQ-C-080-001 (ratified 2026-09-27): "the whole tile at 0.6 opacity while pressed, no
    // geometry change". Ephemeral feedback owned by the button (R-02), never a prop. A custom
    // style rather than `.plain`, whose own pressed dim is the framework's value, not the ruling's.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? ActivityTypeCard.pressedOpacity : 1)
        }
    }

    /// OQ-C-080-001: the ruling's "0.6 opacity" — a ruling value multiplying the tile's own
    /// paint, not a colour token.
    private static let pressedOpacity: Double = 0.6

    /// §2 Title: the `type-title-tile` line box (17/**22**), from the token's own leading.
    private static let titleLineBox: CGFloat =
        Token.TypeStyle.titleTile.lineHeight ?? Token.TypeStyle.titleTile.size

    /// §2 Description / OQ-C-080-003: "reserves three lines".
    private static let descriptionLines = 3

    /// §2 Description: the `type-footnote` line box (13/**18**).
    private static let descriptionLineBox: CGFloat =
        Token.TypeStyle.footnote.lineHeight ?? Token.TypeStyle.footnote.size

    /// §2 Description: "reserves three lines (54)" = 3 × the 18pt line box.
    private static let descriptionBox: CGFloat = descriptionLineBox * CGFloat(descriptionLines)

    /// The footnote line box less the face's natural line height — the leading actually left
    /// to spend between and around lines (same construction as C-023's title).
    private static let descriptionLeading: CGFloat = {
        let style = Token.TypeStyle.footnote
        let natural = UIFont.systemFont(ofSize: style.size, weight: .regular).lineHeight   // footnote is Regular
        return max(descriptionLineBox - natural, 0)
    }()
}
