//
//  PinnedActionPill.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-139-pinned-action-pill in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-139 PinnedActionPill — a page's pinned action: a full-width white pill with a black centred
/// label. It takes values and emits a tap; it decides nothing about what the action does.
///
/// §2 / R-16: fills the width it is given and is 46 × `unit` tall; it paints only its capsule and
/// adds no outer padding. The host owns placement and adds the height to the page's bottom band.
struct PinnedActionPill: View {

    /// C-139 §4 `label` — the pill's text and its accessibility label. Required (R-07).
    let label: String
    /// C-139 §4 `unit` — the page's width unit, `viewportWidth / 440`. Multiplies the height, label
    /// size and inner padding (OQ-C-139-2). Required (R-07).
    let unit: CGFloat
    /// C-139 §4 `onTap` — fired once per tap; the host decides what it means (R-03). No render
    /// effect; defaulted to a no-op.
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§3).
    @State private var pressed = false

    /// C-139 §2's literal geometry.
    private enum Geometry {
        /// FLAGGED LITERAL — C-139 §2: the pill is 46 wu tall (D70).
        static let height: CGFloat = 46
        /// FLAGGED LITERAL — C-139 §2: 16 wu inner padding each side (OQ-C-139-4).
        static let innerPadding: CGFloat = 16
        /// FLAGGED LITERAL — C-139 §2: the touch area's 44pt floor (OQ-C-139-3).
        static let minimumHitHeight: CGFloat = 44
        /// FLAGGED LITERAL — C-139 §2: 0.6 pressed opacity; no opacity token family.
        static let pressedOpacity: Double = 0.6
    }

    /// §2 `type-callout-bold` × `unit`: every metric of the token scales with the page (OQ-C-139-2).
    private var labelStyle: DesignTextStyle {
        let style = Token.TypeStyle.calloutBold
        return DesignTextStyle(
            weight: style.weight,
            size: style.size * unit,
            lineHeight: style.lineHeight.map { $0 * unit },
            tracking: style.tracking * unit
        )
    }

    private var height: CGFloat { Geometry.height * unit }

    var body: some View {
        Text(label)
            .designTextStyle(labelStyle)
            .foregroundStyle(Token.black100)
            // §2, OQ-C-139-4: one line, tail truncated; never wraps.
            .lineLimit(1)
            .truncationMode(.tail)
            .ui2Element("Label")
            .padding(.horizontal, Geometry.innerPadding * unit)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Token.white100, in: Capsule())               // §2: no stroke, no shadow
            .ui2Element("Pill")
            // §2 Pressed: the whole pill at 0.6 while the finger is down; no scale, no colour.
            .opacity(pressed ? Geometry.pressedOpacity : 1)
            // §2 Hit target (OQ-C-139-3): the full width and at least 44 tall, centred on the pill.
            // An overlay overflows without moving layout, so the reported height stays 46 × unit.
            .overlay {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: max(height, Geometry.minimumHitHeight))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
            }
            // §2 Accessibility (R-17): one button, labelled by `label`.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, onTap)
            .ui2Element("PinnedActionPill")                          // capture element map — UI2Element.swift
    }
}
