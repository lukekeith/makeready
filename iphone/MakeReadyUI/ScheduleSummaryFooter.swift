//
//  ScheduleSummaryFooter.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-127-schedule-summary-footer in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-127 ScheduleSummaryFooter — the enrollment flow's Select-schedule footer: the schedule's
/// date range above seven weekday toggles, S M T W T F S (§2).
///
/// Controlled (R-01): the footer holds no value. A toggle flip emits the new set through
/// `onEnabledDaysChange`, and the caller recomputes `dateRange` (§4).
///
/// Chrome-free: frame, background and outer padding belong to the call site (R-16, §1
/// deviation 1 — the screen supplies the 16pt inset).
struct ScheduleSummaryFooter: View {

    /// §4 `Weekday` (R-36). The case order is the rendering order: fixed Sunday-first, as the
    /// Figma draws it, never locale-driven (§2).
    enum Weekday: CaseIterable {
        case sunday, monday, tuesday, wednesday, thursday, friday, saturday

        /// §4 Accessibility: the full weekday name is the toggle's label.
        var name: String {
            switch self {
            case .sunday: "Sunday"
            case .monday: "Monday"
            case .tuesday: "Tuesday"
            case .wednesday: "Wednesday"
            case .thursday: "Thursday"
            case .friday: "Friday"
            case .saturday: "Saturday"
            }
        }

        /// §2: a single uppercase initial — both T's and both S's are intentionally identical.
        var letter: String { String(name.prefix(1)) }
    }

    /// §4 `dateRange` — nil means no start date is picked yet (OQ-C-127-003). Required (R-07).
    let dateRange: ClosedRange<Date>?

    /// §4 `enabledDays` — which toggles are on. Never empty. Required (R-07).
    let enabledDays: Set<Weekday>

    /// §4 `onEnabledDaysChange` — fires with the new set when a toggle flips; never with an empty
    /// set (OQ-C-127-002). Defaulted no-op (R-03).
    var onEnabledDaysChange: (Set<Weekday>) -> Void = { _ in }

    var body: some View {
        VStack(spacing: Token.Space.stackGap) {
            rangeText
            HStack(spacing: Token.Space.toggleGap) {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { index, day in
                    toggle(day)
                        .ui2Element("Weekday toggle \(index + 1)")
                }
            }
            .ui2Element("Weekday row")
        }
        // R-16: fills the width it is given; the stack is centred inside it.
        .frame(maxWidth: .infinity)
        .ui2Element("ScheduleSummaryFooter")
    }

    /// §2 Range text: one centred line, no wrap, `type-summary-label`, `color-text-primary`. The
    /// line box is pinned to the style's 14pt line — SwiftUI's lineSpacing does nothing to a single
    /// line, so without it the text centres against SF Pro's natural line box.
    private var rangeText: some View {
        Text(rangeString)
            .designTextStyle(Token.TypeStyle.summaryLabel)
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            .fixedSize()
            .frame(height: Token.TypeStyle.summaryLabel.lineHeight)
            // §4 Accessibility: the range text is a static label.
            .ui2Element(dateRange == nil ? "Prompt" : "Range text")
    }

    /// §2 Weekday toggle: C-052 DayChip in its weekday look; `.active` when the day is enabled.
    private func toggle(_ day: Weekday) -> some View {
        let enabled = enabledDays.contains(day)
        let sole = enabled && enabledDays.count == 1
        return DayChip(
            content: .weekday(letter: day.letter, name: day.name),
            state: enabled ? .active : .default,
            onTap: { flip(day) }
        )
        // §4 Accessibility: the sole enabled toggle says why its tap does nothing.
        .accessibilityHint(sole ? "At least one day must stay on" : "")
    }

    /// §3 Interaction: emit the set with `day` flipped — except the only enabled day, whose tap
    /// emits nothing and changes nothing (OQ-C-127-002).
    private func flip(_ day: Weekday) {
        var next = enabledDays
        if next.contains(day) {
            guard next.count > 1 else { return }
            next.remove(day)
        } else {
            next.insert(day)
        }
        onEnabledDaysChange(next)
    }

    /// §2 Range text format: `MMM d - MMM d`, POSIX en, uppercased, a spaced hyphen-minus (D5),
    /// never a year; or the literal `SELECT START DATE` (OQ-C-127-003).
    private var rangeString: String {
        guard let dateRange else { return "SELECT START DATE" }
        let start = Self.dayFormatter.string(from: dateRange.lowerBound)
        let end = Self.dayFormatter.string(from: dateRange.upperBound)
        return "\(start) - \(end)".uppercased()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()
}
