//
//  NowIndicator.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-119-now-indicator in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-119 NowIndicator — "today's current-time line across the day timeline, with its time
/// capsule in the gutter".
///
/// §2: "Width-driven (R-16): a full-width row (the timeline's width) whose height is the
/// capsule's, **14**." C-120 places it so the row's vertical centre is at the current minute;
/// the row draws above C-117 blocks and never intercepts touches.
struct NowIndicator: View {

    // MARK: - Props

    /// §4 `label` — "the current time, caller-formatted as h:mm without AM/PM ("10:42", "9:05").
    /// The caller re-renders it every minute; the row runs no timer (R-04, R-19)". Required (R-07).
    let label: String

    @Environment(\.displayScale) private var displayScale

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // §2 Capsule: "trailing edge at x 60 so capsule and line read as one mark"
            // (OQ-C-119-001, owner); width hugs the label.
            capsule
                .frame(width: Self.gutterWidth, alignment: .trailing)

            // §2 Line: "1 px (`1 / displayScale`) `color-negative`, from x 60 to the trailing
            // edge, vertically centred".
            Rectangle()
                .fill(Token.negative)
                .frame(maxWidth: .infinity)
                .frame(height: 1 / displayScale)
                .ui2Element("Line")
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .allowsHitTesting(false)
        // §2 Accessibility (R-17): "non-interactive; one static element "Current time, <label>"."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current time, \(label)")
        .ui2Element("NowIndicator")     // capture element map — UI2Element.swift
    }

    /// §2 Capsule: "`radius-circle`, fill `color-negative`, horizontal padding `space-meta-gap`
    /// (4), vertically centred on the line". `radius-circle` ("50%") is a parsed:false token with
    /// no member, so the shape is SwiftUI's `Capsule` — the same fully-rounded end.
    private var capsule: some View {
        Text(label)
            .designTextStyle(Self.labelStyle)
            .foregroundStyle(Token.white100)
            .lineLimit(1)
            .fixedSize()
            .ui2Element("Label")
            .padding(.horizontal, Token.Space.metaGap)
            .frame(height: Self.height)
            .background(Capsule().fill(Token.negative))
            .ui2Element("Capsule")
    }

    // MARK: - Geometry

    /// FLAGGED LITERAL — C-119 §2: row / capsule height "**14** (FLAGGED LITERAL — proposed,
    /// OQ-C-119-001)", ratified by the owner 2026-10-21.
    private static let height: CGFloat = 14

    /// GAP — C-119 §2: line "from **x 60**" / capsule "trailing edge at x 60" (02-design §5.3,
    /// OQ-C-119-001); the timeline's hour gutter has no spacing token. OQ-C-119-2 (owner,
    /// 2026-10-21): mint `space-timeline-gutter` = 60 and cite it in §2 — becomes
    /// `Token.Space.timelineGutter` once the token row exists and Tokens.swift regenerates.
    private static let gutterWidth: CGFloat = 60

    // MARK: - Type

    /// FLAGGED LITERAL — C-119 §2: Label "SF Pro **Bold 9** (FLAGGED LITERAL type, no 9 pt token)".
    private static let labelStyle = DesignTextStyle(weight: .bold, size: 9, lineHeight: nil, tracking: 0)
}
