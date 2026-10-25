//
//  CategoryBarTable.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-055-category-bar-table in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  OWNER-RULED BEYOND §4: OQ-C-055-001 (answered 2026-09-29) makes this "a data series chart"
//  — a row may carry its own colour, falling back to a colour scale, and the bars can be read
//  in isolation or as a share of the series total. §4 predates that answer, so the two
//  additions (`Row.color`, `mode`) are defaulted to what the contract already says and carry
//  the OQ id; a `/d2m-component-refresh C-055` run is what lands them in §4.
//

import SwiftUI

/// C-055 CategoryBarTable — "a labelled table of one horizontal bar per category, with a
/// count column". Read-only; no actions, no callbacks.
///
/// Width-driven, intrinsic height (R-16): §2's `24 + n×16 + n×24`, 224 at n = 5.
struct CategoryBarTable: View {

    /// §4: `CategoryBarTable.Row` (R-36, nested).
    struct Row {
        /// §4: category label, e.g. "18 – 25".
        let label: String
        /// §4: the bar value, 0…1, clamped.
        let progress: Double
        /// §4: the count, preformatted by the caller (R-04).
        let countLabel: String
        /// OQ-C-055-001 — "color should be able to be specified or left empty". `nil` takes
        /// the positional palette (palette[i mod 5]), which is §2's rule for every row today.
        var color: Color?
    }

    /// OQ-C-055-001 / OQ-C-055-002 — "different modes where each datapoint in the series is
    /// evaluated against the total of all series values or if it's an isolated value".
    enum Mode {
        /// width = progress × barCell width (§2, OQ-C-055-002's proposed law; what Figma draws).
        case isolated
        /// width = progress ÷ Σprogress × barCell width — "five values of 0.5 … is 20%".
        case shareOfTotal
    }

    /// §4: the bar column's header.
    let valueColumnTitle: String
    /// §4: the count column's header.
    let countColumnTitle: String
    /// §4: one element per category row, top to bottom.
    let rows: [Row]
    /// OQ-C-055-001. Defaulted to `.isolated` because it is the only law the design draws
    /// (sample widths 65/133/81/73/49 of 192 = the rows' progress); unrequired per R-07.
    var mode: Mode = .isolated

    var body: some View {
        // OQ-C-055-003 — "There should not be a 'no data' state because the parent surface
        // will decide whether or not to show it." `rows = []` draws nothing, header included.
        if !rows.isEmpty {
            VStack(spacing: Token.Space.rowGap) {
                header
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    categoryRow(row, index: index)
                }
            }
            .frame(maxWidth: .infinity)
            .ui2Element("CategoryBarTable")     // capture element map — UI2Element.swift
        }
    }

    // MARK: - Header row

    /// §2: 24 tall from its 100×24 spacer; titles are 16pt lines centred inside it. Hidden from
    /// accessibility — its titles are folded into every row (R-17).
    private var header: some View {
        HStack(spacing: Token.Space.elementGap) {
            Color.clear
                .frame(width: Self.columnWidth, height: Self.headerHeight)
                .ui2Element("labelCell")
            cellText(valueColumnTitle, color: Token.textSecondary, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .ui2Element("barCell")
            cellText(countColumnTitle, color: Token.textSecondary, alignment: .trailing)
                .frame(width: Self.columnWidth, alignment: .trailing)
                .ui2Element("countCell")
        }
        .frame(height: Self.headerHeight)
        .ui2Element("Header")
        .accessibilityHidden(true)
    }

    // MARK: - Category row

    private func categoryRow(_ row: Row, index: Int) -> some View {
        HStack(spacing: Token.Space.elementGap) {
            cellText(row.label, color: Token.textSecondary, alignment: .leading)
                .frame(width: Self.columnWidth, alignment: .leading)
                .ui2Element("labelCell")
            bar(row, index: index)
                .ui2Element("barCell")
            cellText(row.countLabel, color: Token.textPrimary, alignment: .trailing)
                .frame(width: Self.columnWidth, alignment: .trailing)
                .ui2Element("countCell")
        }
        .frame(height: Self.barHeight)
        .ui2Element("Row \(index + 1)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(row, index: index))
    }

    /// §2: height 16, anchored trailing, square corners, no track. At 0 the bar is not drawn and
    /// the row keeps its 16pt height from its text.
    private func bar(_ row: Row, index: Int) -> some View {
        GeometryReader { geo in
            let fraction = shownFraction(row)
            if fraction > 0 {
                Rectangle()
                    .fill(row.color ?? Self.palette[index % Self.palette.count])
                    .frame(width: geo.size.width * fraction, height: Self.barHeight)
                    .ui2Element("Bar \(index + 1)")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.barHeight)
    }

    /// §2 / OQ-C-055-005 — "Labels and values cannot wrap, they will truncate … if there is
    /// text overflow, that is acceptable." One line, tail ellipsis.
    private func cellText(_ text: String, color: Color, alignment: TextAlignment) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.blockLabel)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    // MARK: - Values

    private func shownFraction(_ row: Row) -> Double {
        let value = Self.clamp(row.progress)
        switch mode {
        case .isolated:
            return value
        case .shareOfTotal:
            let total = rows.reduce(0) { $0 + Self.clamp($1.progress) }
            return total > 0 ? value / total : 0
        }
    }

    /// §2 (R-17): "‹label›, ‹progress as whole %› ‹valueColumnTitle›, ‹countLabel›
    /// ‹countColumnTitle›" — the percent is the bar's shown share, so it matches in both modes.
    private func accessibilityText(_ row: Row, index: Int) -> String {
        let percent = Int((shownFraction(row) * 100).rounded())
        return "\(row.label), \(percent) % \(valueColumnTitle), \(row.countLabel) \(countColumnTitle)"
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    // MARK: - Geometry

    // FLAGGED LITERAL — C-055 §2: the 100pt labelCell / countCell width, no token (D7).
    private static let columnWidth: CGFloat = 100
    // GAP — C-055 §2: header row "24 tall (from its 100×24 spacer)"; equals space-row-gap by
    // value only, so it is not spent as that token. No size token exists for it.
    private static let headerHeight: CGFloat = 24
    // GAP — C-055 §2: category row / bar "height 16", no size token.
    private static let barHeight: CGFloat = 16

    // FLAGGED LITERALS — C-055 §2 (D7): the bar palette in row order, none with a Figma
    // variable; `#4deb4b` is the same unbound green C-057 flags. OQ-C-055-001 keeps it as the
    // fallback "color scale" when a row gives no colour.
    private static let palette: [Color] = [
        Color(red: 0.4588, green: 0.7843, blue: 1.0, opacity: 1),       // #75c8ff
        Color(red: 0.7098, green: 0.5804, blue: 1.0, opacity: 1),       // #b594ff
        Color(red: 0.9294, green: 0.6392, blue: 0.902, opacity: 1),     // #eda3e6
        Color(red: 0.302, green: 0.9216, blue: 0.2941, opacity: 1),     // #4deb4b
        Color(red: 0.8078, green: 1.0, blue: 0.3059, opacity: 1)        // #ceff4e
    ]
}
