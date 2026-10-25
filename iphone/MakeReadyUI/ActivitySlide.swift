//
//  ActivitySlide.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-061-activity-slide in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-061 ActivitySlide — one lesson activity's empty slide in the editor's activity strip.
///
/// §2: "One rounded frame. It paints only its own frame, with no outer padding (R-16)."
/// Deviation 1 collapses Figma's three nested layers into that one rounded rectangle. The
/// chip shows no text, glyph or image; `label` is VoiceOver-only.
///
/// §2 Frame: "Fixed 33×44, its intrinsic size. The host places it and does not stretch it."
/// So unlike most rows this view is not width-driven: it states both of its own dimensions.
struct ActivitySlide: View {

    /// §4 `active` — "Draws the 1pt active outline and adds `.isSelected`." Required (R-07).
    let active: Bool

    /// §4 `label` — "The activity's name. It is the VoiceOver label and is never rendered
    /// (R-17)." Required (R-07).
    let label: String

    /// §4 `onTap` — "Tap on the slide. The host decides what it means (R-04)." No render
    /// effect; a no-op default (R-03).
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            RoundedRectangle(cornerRadius: Token.Radius.card)
                // §2 Fill: `color-activity-slide-placeholder`.
                .fill(Token.activitySlidePlaceholder)
                .ui2Element("Fill")
                // §2 Active outline: "1pt `color-white-100`, stroked **inside** the frame edge
                // along `radius-card` … No geometry change." `strokeBorder` insets the stroke
                // so the 33×44 frame is unchanged.
                .overlay {
                    if active {
                        RoundedRectangle(cornerRadius: Token.Radius.card)
                            .strokeBorder(Token.white100, lineWidth: Self.outlineWidth)
                            .ui2Element("Active outline")
                    }
                }
                .frame(width: Self.width, height: Self.height)
                // §2 Frame: "Corner `radius-card` (8), content clipped."
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(PressedDim())
        // §2 Accessibility (R-17): "one button labelled `label`, with trait `.isButton`, plus
        // `.isSelected` when `active`."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("ActivitySlide")                  // capture element map — UI2Element.swift
    }

    // Deviation 2 (OQ-C-081-003; R-02): "0.6 opacity while pressed". Ephemeral feedback owned
    // by the button, never a prop. A custom style rather than `.plain`, whose own pressed dim
    // is the framework's value, not the ruling's.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? ActivitySlide.pressedOpacity : 1)
        }
    }

    /// Deviation 2: the ruling's "0.6 opacity", multiplying the slide's own paint.
    private static let pressedOpacity: Double = 0.6

    /// §2 Frame: "Fixed 33×44". §2 records these as the component's own designed geometry,
    /// not literals ("Literals: none").
    private static let width: CGFloat = 33
    private static let height: CGFloat = 44
    /// §2 Active outline: "1pt".
    private static let outlineWidth: CGFloat = 1
}
