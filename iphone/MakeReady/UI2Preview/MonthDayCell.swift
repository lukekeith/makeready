//
//  MonthDayCell.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-113-month-day-cell in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-113 MonthDayCell — "one tappable date in the month grid: numeral, today ring and event
/// indicator".
///
/// §2: "A fixed-height box **colW × 69** (colW = the width the parent gives; C-115 gives
/// width / 7). No background, no border (R-16)." The whole box is the hit target.
struct MonthDayCell: View {

    // MARK: - Props (§4, in order — R-05)

    /// §4 `date` — "the numeral is its day-of-month, weekend-ness and the accessibility label
    /// derive from it (Gregorian, Sunday-first)".
    let date: Date

    /// §4 `today` — "`true` draws the `color-negative` circle and the Bold numeral. The caller
    /// compares against its injected `now` — the cell never reads the clock (R-04)".
    let today: Bool

    /// §4 `eventTypes` — "forwarded to C-112 EventIndicator, already sorted; `[]` = no
    /// indicator. Value set owned by C-112".
    let eventTypes: [EventIndicator.EventType]

    /// §4 `onTap` — "the tap … The screen runs the curtain; the cell decides nothing".
    /// Unrequired (R-07 call-out): no-op default.
    var onTap: () -> Void = {}

    /// §3 `pressed` — "ephemeral feedback (R-02) — not a prop, no preview".
    @State private var pressed = false

    // MARK: - Geometry

    private enum Geometry {
        // FLAGGED LITERAL — C-113 §2: "colW × 69" (02-design §4.1 calendar geometry, no token; OQ-C-113-1).
        static let height: CGFloat = 69
        // FLAGGED LITERAL — C-113 §2: Numeral "centre y = 22" (02-design §4.1, no token;
        // OQ-C-113-1) — the numeral band is 44 tall so its centre sits at 22, and the Ø40
        // circle centred in it spans y 2–42 as §2 states.
        static let numeralBand: CGFloat = 44
        // FLAGGED LITERAL — C-113 §2: Indicator "centre y = 51" (02-design §4.1, no token;
        // OQ-C-113-1) — C-112 is 4 tall, so its top sits at 49, 5 below the numeral band.
        static let indicatorGap: CGFloat = 5
        // FLAGGED LITERAL — C-113 §2: today / pressed circle "Ø 40" (02-design §4.2), no token.
        static let circle: CGFloat = 40
    }

    /// FLAGGED LITERAL — C-113 §2: "SF Pro **Semibold 19** … Type is a FLAGGED LITERAL —
    /// 02-design §4.2, no 19 pt type token; fixed size (no Dynamic Type, §10)".
    private static let numeralStyle = DesignTextStyle(weight: .semibold, size: 19, lineHeight: nil, tracking: 0)

    /// FLAGGED LITERAL — C-113 §2: "Today: SF Pro **Bold 19**" (same flag as above).
    private static let todayNumeralStyle = DesignTextStyle(weight: .bold, size: 19, lineHeight: nil, tracking: 0)

    /// §2 / D9: "Weekend = Saturday or Sunday of `date` in the Gregorian calendar (week starts
    /// Sunday)".
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1
        return c
    }()

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    // MARK: - Derived

    private var dayOfMonth: Int { Self.calendar.component(.day, from: date) }

    private var weekend: Bool {
        let weekday = Self.calendar.component(.weekday, from: date)   // 1 = Sunday, 7 = Saturday
        return weekday == 1 || weekday == 7
    }

    /// §2: weekday `color-white-100`, weekend `color-white-50`, today `color-white-100`
    /// ("overrides weekend").
    private var numeralColor: Color { today || !weekend ? Token.white100 : Token.white50 }

    /// §2 Accessibility (R-17): "<EEEE, MMMM d, yyyy>[, today], <n> event(s)" — "no events" when
    /// empty.
    private var accessibilityText: String {
        var parts = [Self.labelFormatter.string(from: date)]
        if today { parts.append("today") }
        switch eventTypes.count {
        case 0: parts.append("no events")
        case 1: parts.append("1 event")
        default: parts.append("\(eventTypes.count) events")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                circle
                Text(verbatim: "\(dayOfMonth)")
                    .designTextStyle(today ? Self.todayNumeralStyle : Self.numeralStyle)
                    .foregroundStyle(numeralColor)
                    .lineLimit(1)
                    .ui2Element("Numeral")
            }
            .frame(maxWidth: .infinity)
            .frame(height: Geometry.numeralBand)

            // §2 Indicator: "C-112 EventIndicator with `eventTypes`, centred horizontally …
            // Present on today too, below the circle". `[]` renders nothing.
            EventIndicator(eventTypes: eventTypes)
                .padding(.top, Geometry.indicatorGap)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Geometry.height, alignment: .top)
        .contentShape(Rectangle())                                // §2: "Hit target: the whole colW × 69 box"
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .ui2Element("MonthDayCell")
    }

    /// §2 Today circle — "fill `color-negative`, centred on the numeral … Behind the numeral";
    /// §3 pressed — "`color-white-30` Ø40", shown while a touch is down on any date.
    @ViewBuilder
    private var circle: some View {
        if pressed {
            Circle()
                .fill(Token.white30)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .ui2Element("Pressed circle")
        } else if today {
            Circle()
                .fill(Token.negative)
                .frame(width: Geometry.circle, height: Geometry.circle)
                .ui2Element("Today circle")
        }
    }
}
