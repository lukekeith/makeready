//
//  AllDayEventChip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-118-all-day-event-chip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-118 AllDayEventChip — "one all-day event (or the \"+N more\" overflow) in the day
/// timeline's pinned all-day row".
///
/// §2: "Width-driven (R-16): fills the width given … Fixed height **20**." The overflow chip is
/// "the same chip with `eventType: .other` and `title` = \"+N more\" (caller-formatted)"
/// (OQ-C-118-001, ratified), so there is no second look and no style prop.
struct AllDayEventChip: View {

    // MARK: - Props (§4, in the contract's order — R-05)

    /// §4 `title` — "the event title, or the overflow label \"+N more\"".
    let title: String
    /// §4 `eventType` — "fill and tint (C-117 recipe); `.other` for the overflow chip. Value set
    /// owned by C-112".
    let eventType: EventIndicator.EventType
    /// §4 `onTap` — "event: open it (D7, no-op in the preview); overflow: C-120 expands the row".
    /// Unrequired (R-07 call-out).
    var onTap: () -> Void = {}

    // MARK: - Body

    var body: some View {
        // `SwiftUI.Button`: the module's own C-105 `Button` shadows SwiftUI's.
        SwiftUI.Button(action: onTap) {
            // §2 Title — "SF Pro **Semibold 13** … one line, tail \"…\", leading inset
            // `space-element-gap` (8), vertically centred".
            Text(title)
                .designTextStyle(Self.titleStyle)
                .foregroundStyle(tint)
                .lineLimit(1)
                .truncationMode(.tail)
                .ui2Element("Title")
                .padding(.leading, Token.Space.elementGap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Geometry.height)
                // §2 Shape — "capsule (`radius-circle`, i.e. 10), fill = `eventType` token at
                // opacity **0.25**". `radius-circle` is an unparsed token ("50%"), so the shape
                // is SwiftUI's Capsule rather than a radius member.
                .background(
                    Capsule()
                        .fill(eventType.color.opacity(Geometry.fillOpacity))
                        .ui2Element("Shape")
                )
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressDimStyle())
        // §2 Accessibility (R-17): "one button, label \"<title>, all-day\"".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), all-day")
        .accessibilityAddTraits(.isButton)
        .ui2Element("AllDayEventChip")
    }

    // MARK: - Colour

    /// FLAGGED LITERAL — C-118 §2: title colour "`mix(eventType token, white, 0.55)` (C-117's
    /// tint)". Read back out of the C-112 token, so it cannot drift from it.
    private var tint: Color {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(eventType.color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let t = Geometry.whiteMix
        return Color(red: r + (1 - r) * t, green: g + (1 - g) * t, blue: b + (1 - b) * t)
    }

    // MARK: - Type

    /// FLAGGED LITERAL — C-118 §2: Title "SF Pro **Semibold 13** (FLAGGED LITERAL type)".
    private static let titleStyle = DesignTextStyle(weight: .semibold, size: 13, lineHeight: nil, tracking: 0)

    // MARK: - Geometry

    private enum Geometry {
        static let height: CGFloat = 20                          // FLAGGED LITERAL — C-118 §2: fixed height 20 (analysis §4)
        static let fillOpacity: Double = 0.25                    // FLAGGED LITERAL — C-118 §2: fill opacity 0.25 (C-117's recipe)
        static let whiteMix: CGFloat = 0.55                      // FLAGGED LITERAL — C-118 §2: mix toward white 0.55 (C-117's tint)
    }
}

/// §2 Pressed — "opacity 0.6 while touched (ephemeral, R-02 — C-117's feedback)".
private struct PressDimStyle: ButtonStyle {
    private static let pressedOpacity: Double = 0.6              // FLAGGED LITERAL — C-118 §2: pressed opacity 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }
}
