//
//  ActionMenuRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-067-action-menu-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-067 ActionMenuRow — one contextual action row inside C-066 ActionMenuOverlay.
///
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// intrinsic height (16 + 24 + 16 = 56), paints no background and adds no outer padding.
struct ActionMenuRow: View {

    /// §4 `tone` (R-06 / R-36): the §3 tone axis.
    enum Tone {
        case standard
        case destructive
    }

    /// §4 `glyph`: a glyph-library name, drawn as the leading 24pt glyph.
    let glyph: String
    /// §4 `label`: the action's title.
    let label: String
    /// §4 `tone`: defaults to `.standard`, the designed base look (R-07).
    var tone: Tone = .standard
    /// §4 `onTap`: the row was tapped (R-03, R-33). No render effect.
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            // §2: center-aligned, item gap `space-card-padding`.
            HStack(spacing: Token.Space.cardPadding) {
                leadingGlyph.ui2Element("Glyph")
                Text(label)
                    // §2: `type-action-item`, one line, tail-truncated (OQ-C-067-004).
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    // The designed 24pt line box — taller than SF Pro's natural line at 18pt,
                    // so it supplies the half-leading that centres the label on the glyphs.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Token.TypeStyle.actionItem.lineHeight ?? Token.TypeStyle.actionItem.size,
                        alignment: .leading
                    )
                    .ui2Element(tone == .destructive ? "Label (destructive)" : "Label")
                // §2: fixed anatomy on every row (OQ-C-066-3), `color-white-50` in every tone.
                Glyph(.chevronRightCarbon, size: .md, tint: Token.white50)
                    .accessibilityHidden(true)
                    .ui2Element("Chevron")
            }
            // §2: `space-card-padding` top and bottom, horizontal padding 0.
            .padding(.vertical, Token.Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2: the whole row is the tap target.
            .contentShape(Rectangle())
        }
        // §2 / OQ-C-067-002: the system highlight of a plain button style (ephemeral, R-02).
        .buttonStyle(.plain)
        // R-17: one button element, labelled by `label`; glyph and chevron are decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .ui2Element("ActionMenuRow")
    }

    /// §2: glyph and label are `color-text-primary`; `tone=destructive` turns both
    /// `color-negative` (OQ-C-066-2 + OQ-C-067-001).
    private var tint: Color {
        switch tone {
        case .standard: return Token.textPrimary
        case .destructive: return Token.negative
        }
    }

    @ViewBuilder private var leadingGlyph: some View {
        if let name = Self.glyphName(glyph) {
            Glyph(name, size: .md, tint: tint)
                .accessibilityHidden(true)
        } else {
            // STUB — C-067 `glyph` names no glyph in the library. Drawn obviously unfinished
            // at the designed 24pt rather than substituting a near-enough glyph.
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .strokeBorder(Token.error, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: GlyphSize.md.points, height: GlyphSize.md.points)
        }
    }

    /// The library glyph `glyph` names. §4 retires the pre-library content names `c066-send`
    /// and `c066-close`; §1 traces them to the same Figma art as `send-filled` (3832:31474)
    /// and `x-circle-filled` (the "Misuse" instance), so a fixture still carrying them
    /// resolves to those glyphs rather than to the stub.
    private static func glyphName(_ glyph: String) -> GlyphName? {
        switch glyph {
        case "c066-send": return .sendFilled
        case "c066-close": return .xCircleFilled
        default: return GlyphName(rawValue: glyph)
        }
    }
}
