//
//  DayChip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-052-day-chip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-052 DayChip — one filled shape and one centred text run, in two looks (§2):
/// `day` (the 40×48 rounded box holding an ordinal program-day number) and `weekday`
/// (the 32×32 circle holding one uppercase weekday letter).
///
/// §1 deviation 5: no border, no shadow, no icon, no press look — except §3d's dashed outline
/// for a day with no content. §3a: within one look the fill is the only delta when `isEmpty` is
/// false; `look` changes shape, size and label type, never the fill.
///
/// **Fixed, not content-sized.** §1 deviation 1: a fixed box with `overflow: clip`; a label
/// wider than the box is clipped, not wrapped and not grown (OQ-C-052-4, ruled).
///
/// Chrome-free: frame, background and outer padding belong to the call site (R-16).
struct DayChip: View {

    /// §4 `content` — what the chip shows, and so its `look` (§3a). The case IS the look, so
    /// a weekday letter can never be drawn in the 40×48 box or a day number in the circle.
    enum Content {
        /// The ordinal program day 1…N — not a calendar date.
        case day(Int)
        /// `letter` is the single uppercase initial drawn ("M"); `name` is the full weekday
        /// name used as the accessibility label ("Monday").
        case weekday(letter: String, name: String)
    }

    /// §4 `state` — selects the fill (§3a). `Active` = selected / on, never
    /// "today" (§3b). Raw values are §3's labels verbatim — the fixture's values.
    enum State: String {
        case `default` = "Default"
        case active = "Active"
    }

    /// §4 `content`. Required (R-07).
    let content: Content

    /// §4 `state`. Required (R-07).
    let state: State

    /// §4 `isEmpty` — this day has no content. With `.day` and `state == .default` it draws the
    /// outline (§3d); ignored for `.weekday`, and a selected chip keeps Active's fill. Defaulted
    /// (R-03), so no existing caller changes.
    var isEmpty: Bool = false

    /// §4 `onTap` — what it means (select a day, toggle a weekday) is the consumer's call.
    /// No render effect; a defaulted no-op (R-03, R-33).
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            chip
        }
        .buttonStyle(.plain)
        // §4 Accessibility (R-17): a button, selected when Active, labelled per look.
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isEmptyDay ? "No content" : "")
        .accessibilityAddTraits(state == .active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("DayChip")     // capture element map — UI2Element.swift
    }

    @ViewBuilder
    private var chip: some View {
        switch content {
        case .day(let number):
            label(String(number), style: Token.TypeStyle.body, lineBox: Self.dayLineBox, part: "Number")
                // §2 (owner ruling 2026-11-06): fixed 40 × 48, contents centred on both axes.
                .frame(width: Self.dayWidth, height: Self.dayHeight)
                .background(
                    // §2: `radius-card-sm` (4), fill per state; a stroke only for §3d's dashed
                    // outline, drawn inside the box so the size stays 40 × 48.
                    RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                        .fill(fill)
                        .overlay {
                            if isOutlined {
                                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                                    .strokeBorder(
                                        Token.accent,
                                        style: StrokeStyle(lineWidth: Self.outlineWidth, dash: Self.outlineDash)
                                    )
                            }
                        }
                        .ui2Element("Chip")
                )
                // §1 deviation 1: `overflow: clip`, cut by the chip's own rounded rect.
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.cardSm))
                // §3c (owner ruling 2026-11-06): the day target is the chip's own 40 × 48 box,
                // with no expansion beyond it.
                .contentShape(Rectangle())
        case .weekday(let letter, _):
            label(letter, style: Token.TypeStyle.titleCard, lineBox: Self.weekdayLineBox, part: "Letter")
                // §2: fixed 32 × 32, contents centred on both axes.
                .frame(width: Self.weekdaySide, height: Self.weekdaySide)
                .background(
                    // §2 / §1 deviation 7: a Circle shape, not `radius-circle`; no stroke.
                    Circle()
                        .fill(fill)
                        .ui2Element("Chip")
                )
                .clipShape(Circle())
                // §3c / OQ-C-052-5: weekday target 44 × 44 — C-127's 16pt gap leaves 6pt a
                // side, so neighbouring targets meet but do not overlap. Circle stays 32.
                .contentShape(HitOutset(width: Self.hitSize, height: Self.hitSize))
        }
    }

    /// §2: the centred label. `String(number)` rather than an interpolated Int: no grouping
    /// separator or locale formatting. The line box is pinned as a frame — SwiftUI's
    /// lineSpacing does nothing to a single line, so without it the glyph centres against
    /// SF Pro's natural line box instead of the measured one (day 14, weekday 20).
    private func label(_ text: String, style: DesignTextStyle, lineBox: CGFloat, part: String) -> some View {
        Text(text)
            .designTextStyle(style)
            // §2: `color-text-primary`, both looks (deviation 2, ruled via OQ-C-022-4);
            // §3d: the outline chip's number is `color-text-secondary`.
            .foregroundColor(isOutlined ? Token.textSecondary : Token.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .frame(height: lineBox)
            .ui2Element(part)
    }

    /// §3d: `isEmpty` has a designed meaning in the day look only.
    private var isEmptyDay: Bool {
        guard case .day = content else { return false }
        return isEmpty
    }

    /// §3d: the outline draws for an unselected empty day; selection wins (§3a).
    private var isOutlined: Bool {
        isEmptyDay && state == .default
    }

    /// §3a: the one delta within a look, the same two tokens in both looks; §3d's outline has
    /// no fill.
    private var fill: Color {
        if isOutlined { return .clear }
        switch state {
        // §1 deviation 3: white at 20% alpha, not a grey — it composites against the ground.
        case .default: return Token.white20
        case .active: return Token.accent
        }
    }

    private var accessibilityLabel: String {
        switch content {
        case .day(let number): "Day \(number)"
        case .weekday(_, let name): name
        }
    }

    /// §2: the day look's fixed box.
    private static let dayWidth: CGFloat = 40
    private static let dayHeight: CGFloat = 48
    /// §3d: the outline's stroke width and dash, read from Figma's `state=Incomplete` (`4788:45576`).
    private static let outlineWidth: CGFloat = 1
    private static let outlineDash: [CGFloat] = [2, 2]
    /// §2: the weekday look's fixed circle.
    private static let weekdaySide: CGFloat = 32
    /// §3c / OQ-C-052-5: the weekday look's expanded target, both axes.
    private static let hitSize: CGFloat = 44
    /// §2: `type-body`'s 14pt line (day) and `type-title-card`'s 20pt line (weekday).
    private static let dayLineBox: CGFloat = 14
    private static let weekdayLineBox: CGFloat = 20
}

/// §3c: a hit shape `width` × `height`, centred on the chip — the target grows past the drawn
/// shape without moving the layout.
private struct HitOutset: Shape {
    let width: CGFloat
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: (rect.width - width) / 2, dy: (rect.height - height) / 2))
    }
}
