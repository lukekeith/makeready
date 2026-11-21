//
//  SavedToast.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-141-saved-toast in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-141 SavedToast — a floating confirmation capsule with one trailing text action
/// ("Saved to Library · View", memo-screens D6).
///
/// Deviation 1: the host owns placement (above the TabBar), the 4 s auto-hide, motion and
/// navigation. This view has none of them (R-04, R-19). Chrome-free (R-16): it fills the
/// width it is given, centres the capsule in it and states its own 48 pt height.
struct SavedToast: View {

    /// C-141 §4 `message: String` — the confirmation text, one line. Required (R-07).
    let message: String
    /// C-141 §4 `actionLabel: String` — the trailing action's label and accessibility label.
    /// Required (R-07).
    let actionLabel: String
    /// C-141 §4 `onView: () -> Void` — raised on tap-up inside the action's hit target.
    /// No-op default (R-03, R-33); the host pushes memo-detail and dismisses the toast.
    var onView: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: Token.Space.stackGap) {   // §2: gap `space-stack-gap`
            Text(message)
                .designTextStyle(Token.TypeStyle.bodySm)              // §2: `type-body-sm` 14/20
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                // §2: the message yields to the action, so the action never truncates.
                .layoutPriority(0)
                .ui2Element("Message")

            SwiftUI.Button(action: onView) {
                Text(actionLabel)
                    .designTextStyle(Token.TypeStyle.link)            // §2: `type-link` semibold 14/24
                    .foregroundColor(Token.accent)                    // §2: `color-accent`, no underline
                    .lineLimit(1)
                    .fixedSize()
                    // §2: intrinsic 48 = 12 + 24 (the `type-link` line) + 12. SwiftUI has no
                    // line-height, so the line box is read from the token's own leading.
                    .frame(height: Self.lineBox)
            }
            .buttonStyle(PressedDim())
            // §2: a hit target of at least 44 × 44 pt, centred on the label. An expanded tap
            // shape, not a larger frame, so it changes no geometry.
            .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.lineBox) / 2))
            .accessibilityLabel(actionLabel)
            .accessibilityAddTraits(.isButton)
            .layoutPriority(1)
            .ui2Element("Action")
        }
        .padding(.horizontal, Token.Space.cardPadding)                // §2: 16 leading/trailing
        .padding(.vertical, Token.Space.fieldGap)                     // §2: 12 top/bottom
        // §2: fill `color-modal-background`, fully rounded (`radius-circle` — parsed:false in
        // the token register, so the shape is SwiftUI's Capsule), shadow `elevation-thumbnail`,
        // no stroke. The shadow goes on the capsule shape itself: on the composite it would
        // also shadow the message and action text.
        .background(
            Capsule()
                .fill(Token.modalBackground)
                .designShadow(Token.Elevation.thumbnail)
        )
        .accessibilityElement(children: .contain)                     // §2 Accessibility (R-17)
        .ui2Element("Capsule")
        // §2 Outer frame: fills the given width, paints nothing; the capsule hugs its content,
        // capped at that width, and sits centred in it.
        .frame(maxWidth: .infinity)
        .ui2Element("SavedToast")
    }

    // §2 Pressed (action): the label at 0.6 opacity while the finger is down; no scale, no
    // colour change (as C-048, C-138, C-139).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? SavedToast.pressed : 1)
        }
    }

    /// §2: the 24 pt `type-link` line box, read from the token.
    private static let lineBox: CGFloat = Token.TypeStyle.link.lineHeight ?? Token.TypeStyle.link.size

    // FLAGGED LITERAL — C-141 §2: the 0.6 pressed opacity, no token.
    private static let pressed: Double = 0.6

    // FLAGGED LITERAL — C-141 §2: the 44 pt touch floor, no token.
    private static let hitTarget: CGFloat = 44
}
