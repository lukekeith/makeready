//
//  InlineActionRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-138-inline-action-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-138 InlineActionRow — a page's inline action: a borderless, centred 24pt glyph and one-line
/// white label. It takes values and emits a tap; it decides nothing about what the action does.
///
/// §2 / R-16: fills the width it is given and is 44 tall; it paints no background and adds no outer
/// padding. The host owns placement: frame top = last object's bottom + 58u − 10 (OQ-C-138-001).
struct InlineActionRow: View {

    /// C-138 §4 `label` — the row's text and its accessibility label. Required (R-07).
    let label: String
    /// C-138 §4 `glyph` — the 24pt library glyph before the label; `nil` draws the label alone and
    /// drops the gap (OQ-C-138-003).
    var glyph: GlyphName? = .plusCircle
    /// C-138 §4 `onTap` — fired once per tap; the host decides what it means (R-03). No render
    /// effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§3).
    @State private var pressed = false

    /// C-138 §2's literal geometry.
    private enum Geometry {
        /// FLAGGED LITERAL — C-138 §2: the 44pt row frame and minimum hit size (OQ-C-138-001).
        static let hitSize: CGFloat = 44
        /// FLAGGED LITERAL — C-138 §2: 0.6 pressed opacity; no opacity token family.
        static let pressedOpacity: Double = 0.6
    }

    var body: some View {
        HStack(spacing: Token.Space.elementGap) {                // §2 gap, dropped with a nil glyph
            if let glyph {
                // FLAGGED LITERAL — C-138 §2: the 24pt glyph box, GlyphSize.md; no icon-size token.
                Glyph(glyph, size: .md, tint: Token.white100)
                    .accessibilityHidden(true)
                    .ui2Element("Glyph")
            }
            Text(label)
                .designTextStyle(Token.TypeStyle.actionItem)
                .foregroundStyle(Token.white100)
                // §2, OQ-C-138-001: one line, tail truncated; never wraps.
                .lineLimit(1)
                .truncationMode(.tail)
                .ui2Element("Label")
        }
        // §2 hit target (OQ-C-138-001): the content's width, at least 44, by the 44 tall frame.
        .frame(minWidth: Geometry.hitSize, minHeight: Geometry.hitSize, maxHeight: Geometry.hitSize)
        .contentShape(Rectangle())
        .ui2Element("Content")
        // §2 Pressed: the whole content at 0.6 while the finger is down; no scale, no colour.
        .opacity(pressed ? Geometry.pressedOpacity : 1)
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        // §2 Accessibility (R-17): one button, labelled by `label`; the glyph is decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        // §2 Row frame: no contentShape here, so the rest of the width passes touches to the pager.
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.hitSize)
        .ui2Element("InlineActionRow")                           // capture element map — UI2Element.swift
    }
}
