//
//  EventIndicator.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-112-event-indicator in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-112 EventIndicator — "the coloured capsule under a calendar date that counts its events".
///
/// §2: "A single horizontal capsule, **height 4**, corner `radius-bar` (2), clipped.
/// Non-interactive; it paints nothing outside the capsule and has no background (R-16 — the
/// parent centres it)." The capsule states its own size from the event count, so the capture
/// call site hugs it rather than giving it a width.
struct EventIndicator: View {

    // MARK: - Vocabulary

    /// §4 `EventIndicator.EventType` — "owned here, cited by C-117, C-118, C-121 (never
    /// restated)". One case per `CalendarEvent.type`; raw values are the §4 case names, which
    /// are what the fixture sends.
    enum EventType: String, CaseIterable {
        case lesson
        case meeting
        case online
        case deadline
        case social
        case other

        /// §4 colour table (02-design §8 / D5). `color-negative` is reserved for today / now
        /// and is never an event colour.
        var color: Color {
            switch self {
            case .lesson: Token.accent
            case .meeting: Token.positive
            case .online: Token.brandHighlight
            case .deadline: Token.warning
            case .social: Token.highlight
            case .other: Token.textSecondary
            }
        }
    }

    // MARK: - Props

    /// §4 `eventTypes` — "the day's events in display order (caller sorts: all-day first, then
    /// by start time); count drives width, the first four drive segment colours. Required
    /// (R-07); `[]` renders nothing".
    let eventTypes: [EventType]

    // MARK: - Body

    var body: some View {
        if let width = Self.width(for: eventTypes.count) {
            capsule(width: width)
                // §2 Accessibility (R-17): "decorative — hidden from VoiceOver; the containing
                // date reads its event count (C-113 §4)."
                .accessibilityHidden(true)
                .ui2Element("EventIndicator")     // capture element map — UI2Element.swift
        }
        // §3 `none`: count 0 "renders nothing (zero size)" — the non-state row, no preview.
    }

    /// §2: "equal widths (capsule width ÷ segment count), butted with no gap, in the order
    /// given; each filled solid with its `EventType` token. The clip rounds only the outer ends."
    private func capsule(width: CGFloat) -> some View {
        let segments = Array(eventTypes.prefix(Self.maxSegments))
        return HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, type in
                Rectangle()
                    .fill(type.color)
                    .frame(width: width / CGFloat(segments.count))
                    .ui2Element("Segment \(index + 1)")
            }
        }
        .frame(width: width, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.bar))
    }

    // MARK: - Geometry

    private static let height: CGFloat = 4             // FLAGGED LITERAL — C-112 §2: height 4 (02-design §4.4), no sizing token

    /// §2: "≥ 4 → 4 (the first four)".
    private static let maxSegments = 4

    /// §2's closed width table; nil for 0 events (renders nothing).
    private static func width(for count: Int) -> CGFloat? {
        switch count {
        case ...0: nil
        case 1: 5                                        // FLAGGED LITERAL — C-112 §2: 1 event width 5 (OQ-C-112-001: 5×4 capsule), no sizing token
        case 2: 14                                       // FLAGGED LITERAL — C-112 §2: 2 events width 14, no sizing token
        case 3: 22                                       // FLAGGED LITERAL — C-112 §2: 3 events width 22, no sizing token
        default: 30                                      // FLAGGED LITERAL — C-112 §2: ≥ 4 events width 30, no sizing token
        }
    }
}
