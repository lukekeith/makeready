//
//  TimelineEventRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-065-timeline-event-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  DEPENDENCIES: none. C-065 §5 consumes nothing from the registry — the dot is geometry
//  (§1 deviation 4), the date and the event sentence are text. The connector line and the
//  row stacking belong to the consuming screen (invite-home §2), not to this row.
//

import SwiftUI

/// C-065 TimelineEventRow — one dated event in a vertical history timeline: a tone-coloured
/// dot, a fixed-width date, and the event sentence.
///
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// intrinsic height (text height + 16), paints no background and adds no outer horizontal
/// padding. Display-only, so it takes no callbacks (R-03).
struct TimelineEventRow: View {

    /// §3 `tone` — the dot colour and the highlight colour.
    enum Tone { case neutral, positive }

    /// §4: `dateLabel: String` — the already-formatted date shown in the 100pt column. The
    /// caller formats it; the row never formats dates (R-04).
    let dateLabel: String
    /// §4: `text: String` — the event sentence. Wraps.
    let text: String
    /// §4: `highlight: String?` — a substring of `text` (first occurrence) rendered in the
    /// tone colour. `nil` = no highlight. Defaulted because the base symbol shows none (R-07).
    var highlight: String?
    /// §4: `tone: Tone` — defaulted `.neutral` because the base symbol is neutral (R-07).
    var tone: Tone = .neutral

    var body: some View {
        // §2: "Horizontal row, top-aligned, vertical padding `space-element-gap` (8) top and
        // bottom, gap `space-element-gap` (8) between the three parts."
        HStack(alignment: .top, spacing: Token.Space.elementGap) {
            dot.ui2Element("Dot")
            date.ui2Element("Date")
            eventText.ui2Element("Event text")
        }
        .padding(.vertical, Token.Space.elementGap)
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2 Accessibility (R-17): one combined element read as "<dateLabel>, <text>"; the
        // dot is decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dateLabel), \(text)")
        .ui2Element("TimelineEventRow")             // capture element map — UI2Element.swift
    }

    // §2 Dot: "a 20×20pt box with a filled circle of diameter 8pt centred in it. Fill: tone
    // colour." The 20pt box matches the 20pt text line box, so the dot centres on line 1.
    private var dot: some View {
        Circle()
            .fill(toneColor)
            .frame(width: Self.dotDiameter, height: Self.dotDiameter)
            .frame(width: Self.dotBox, height: Self.dotBox)
            .accessibilityHidden(true)
    }

    // §2 Date: "single line, `type-body-sm`, `color-text-secondary`, fixed width 100pt,
    // leading-aligned." OQ-C-065-002 (answered): keep 100pt fixed, single line, tail-truncate.
    private var date: some View {
        Text(dateLabel)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: Self.dateWidth, height: Self.lineBox, alignment: .leading)
    }

    // §2 Event text: "`type-body-sm`, `color-white-100`, fills the remaining width, wraps to
    // as many lines as needed (no line limit)."
    private var eventText: some View {
        Text(attributedText)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.white100)
            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
            // `fixedSize` OUTSIDE the min-height frame: the capture harness proposes a numeric
            // zero height, and a `minHeight` frame would clamp it to one line without ever
            // asking the text (the C-047 wrapped-text trap).
            .fixedSize(horizontal: false, vertical: true)
    }

    /// `text` with the first occurrence of `highlight` in the tone colour. OQ-C-065-001
    /// (answered): the highlight takes the tone colour, so under `.neutral` it renders plain.
    private var attributedText: AttributedString {
        var result = AttributedString(text)
        if let highlight, !highlight.isEmpty, tone != .neutral,
           let range = result.range(of: highlight) {
            result[range].foregroundColor = toneColor
        }
        return result
    }

    // §3 tone colours: `neutral` → `color-text-secondary`; `positive` → `color-positive`
    // (OQ-C-065-003 ratified the token over Figma's raw #6CFF73).
    private var toneColor: Color {
        switch tone {
        case .neutral: return Token.textSecondary
        case .positive: return Token.positive
        }
    }

    // FLAGGED LITERAL — C-065 §2: 20 (dot box), no sizing token.
    private static let dotBox: CGFloat = 20
    // FLAGGED LITERAL — C-065 §2: 8 (dot diameter), no sizing token.
    private static let dotDiameter: CGFloat = 8
    // FLAGGED LITERAL — C-065 §2: 100 (date column width), no token.
    private static let dateWidth: CGFloat = 100

    /// The designed line box of `type-body-sm` (14/20): SwiftUI has no line-height, so the
    /// box is spelled as a frame.
    private static let lineBox: CGFloat = Token.TypeStyle.bodySm.lineHeight ?? Token.TypeStyle.bodySm.size
}
