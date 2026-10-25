//
//  HomeKpiPickerScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen home-kpi-picker in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/analytics/meta ·
//  POST /api/analytics/query · GET /api/preferences/{key} · PUT /api/preferences/{key}
//  (key `dashboard.kpis`).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// KPI Picker — "a stacked list of KPIs that are available to be tracked and can be added to the
/// user's home screen" (owner description). A page pushed over Home (A1): C-040 PageHeader "Add
/// KPIs" over the KPI list — one C-090 KPIPickerRow per KPI, a C-088 SectionDivider between each
/// adjacent pair (§2). Composed only of §4's C-040, C-090 and C-088.
struct HomeKpiPickerScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per listed KPI in A2's catalog order, because the preview's props are JSON and C-090
    /// takes flat parameters (R-05). A KPI already on Home is simply not in the arrays (§3 3–4).
    struct State {
        /// C-090 `name` — the catalog entry's name (A4).
        var kpiNames: [String]
        /// C-090 `description` — the catalog entry's description (A4).
        var kpiDescriptions: [String]
        /// C-090 `series` — all zeros gives C-023 `empty` (A5, §3 Loading).
        var kpiSeries: [[Double]]
        /// C-090 `averageLabel` — "" = none (A5: an empty card passes no averageLabel).
        var kpiAverageLabels: [String]
        /// C-090 `value`, formatted by the caller.
        var kpiValues: [String]
        /// C-090 `trendDirection` — C-077 `up` | `down` | `neutral`.
        var kpiTrendDirections: [String]
        /// C-090 `trendPolarity` — C-077 `positive` | `negative` | `neutral`.
        var kpiTrendPolarities: [String]
        /// C-090 `trendLabel`, formatted by the caller, never signed.
        var kpiTrendLabels: [String]
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}             // C-040 `onLeading` → pop to home-dashboard (§6)
    var onAdd: (Int) -> Void = { _ in }     // C-090 `onAdd` → add that KPI to Home, by row (§3)

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onAdd: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onAdd = onAdd
    }

    // MARK: - §4 constants (values that no §3 state changes)

    /// §4 (C-040): `title: "Add KPIs"` (A1).
    private static let title = "Add KPIs"

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. §2's "pinned" header and the list's vertical scroll are the promoted screen's.
        VStack(alignment: .leading, spacing: 0) {
            header
            kpiList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
    }

    /// §2 L1: "C-040 PageHeader, full page width, 56 pt" — §4: `style: twoIcons`, `showTitle:
    /// true`, `showIcons: false`, `rightButtons: []`, `leadingGlyph: back`, `onLeading` = pop.
    private var header: some View {
        PageHeader(
            style: .twoIcons,
            title: Self.title,
            showTitle: true,
            showIcons: false,
            leadingGlyph: .back,
            rightButtons: [],
            onLeading: onBack
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2 L2: the KPI list — "an inline page container, not a component" (A3) whose top edge is
    /// the header's bottom edge, padded `space-page-margin` on all four sides. Between adjacent
    /// rows one C-088 with `space-card-padding` above and below; none above the first row, none
    /// below the last, none for a single row.
    private var kpiList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(state.kpiNames.indices, id: \.self) { index in
                if index > 0 {
                    // Annotated before its padding so the part's rect is the 1pt rule itself,
                    // as design-14 draws it (refine round 1: wrapped, it measured 33pt).
                    SectionDivider()
                        .ui2Element(Self.partName("C-088 SectionDivider", ordinal: index))
                        .padding(.vertical, Token.Space.cardPadding)
                }
                kpiRow(at: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Token.Space.pageMargin)
    }

    /// §4: C-090 KPIPickerRow — name and description from the catalog, card props per A5.
    private func kpiRow(at index: Int) -> some View {
        let averageLabel = state.kpiAverageLabels[safe: index] ?? ""
        return KPIPickerRow(
            name: state.kpiNames[index],
            description: state.kpiDescriptions[safe: index] ?? "",
            series: state.kpiSeries[safe: index] ?? [],
            averageLabel: averageLabel.isEmpty ? nil : averageLabel,
            value: state.kpiValues[safe: index] ?? "",
            trendDirection: TrendIndicator.Direction(
                rawValue: state.kpiTrendDirections[safe: index] ?? "") ?? .neutral,
            trendPolarity: TrendIndicator.Polarity(
                rawValue: state.kpiTrendPolarities[safe: index] ?? "") ?? .neutral,
            trendLabel: state.kpiTrendLabels[safe: index] ?? "",
            onAdd: { onAdd(index) }
        )
        .ui2Element(Self.partName("C-090 KPIPickerRow", ordinal: index + 1))
    }

    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - §3 sample states

extension HomeKpiPickerScreen.State {
    /// A2's catalog, in order, with A4's descriptions.
    private static let catalogNames = [
        "Active members", "Lesson completion rate", "Weekly engagement", "Streak leaders",
        "Study enrollments", "New member requests", "Reflection posts", "Video watch time",
        "Attendance", "Prayer requests"
    ]
    private static let catalogDescriptions = [
        "Members who opened a lesson or posted in the last 7 days.",
        "Share of scheduled lessons finished on time across your groups.",
        "Lessons, posts and reflections per member this week.",
        "Members with the longest run of consecutive study days.",
        "New enrollments in your study programs this month.",
        "People waiting for you to approve them into a group.",
        "SOAP reflections members shared after a lesson.",
        "Total minutes of lesson video watched by your members.",
        "Members present at your group's recent meetings.",
        "Open prayer requests shared by members of your groups."
    ]
    /// §5: the KPIs with a registry metric (✅). Every other KPI is an API-GAP and renders C-023
    /// `empty` until it closes (A5, OQ-home-kpi-picker-003).
    private static let metricBacked: Set<String> = [
        "Active members", "Lesson completion rate", "Study enrollments", "Video watch time"
    ]
    /// OQ-home-kpi-picker-001 (owner): "the top 3 or 4 KPIs displayed on home by default" — the
    /// first four in catalog order, hidden from the picker (§3 3's default).
    private static let onHomeByDefault = 4

    /// One row's C-023 card inputs (A5).
    private struct Card {
        let series: [Double]
        let averageLabel: String
        let value: String
        let direction: String
        let polarity: String
        let trendLabel: String
    }

    /// The card the frozen frame design-14 draws on every row (C-090 `default`'s sample).
    private static let frameCard = Card(
        series: [0, 0, 0, 0, 0, 0, 0, 52, 28, 0, 0, 0, 5, 25, 18, 6, 0, 0, 0, 0, 0, 0, 9, 0],
        averageLabel: "130", value: "158", direction: "up", polarity: "positive", trendLabel: "3%"
    )
    /// C-023 `empty`: all-zero series and no averageLabel (A5); C-090 `empty`'s sample values.
    private static let emptyCard = Card(
        series: [Double](repeating: 0, count: 24),
        averageLabel: "", value: "0", direction: "neutral", polarity: "neutral", trendLabel: "0%"
    )

    private static func rows(_ indices: Range<Int>, live: Bool) -> Self {
        let names = Array(catalogNames[indices])
        let cards = names.map { live && metricBacked.contains($0) ? frameCard : emptyCard }
        return Self(
            kpiNames: names,
            kpiDescriptions: Array(catalogDescriptions[indices]),
            kpiSeries: cards.map { $0.series },
            kpiAverageLabels: cards.map { $0.averageLabel },
            kpiValues: cards.map { $0.value },
            kpiTrendDirections: cards.map { $0.direction },
            kpiTrendPolarities: cards.map { $0.polarity },
            kpiTrendLabels: cards.map { $0.trendLabel }
        )
    }

    /// §3 1 Populated (design-14): all ten KPIs; metric-backed cards show data, API-GAPs `empty`.
    static let populated = rows(0..<10, live: true)
    /// §3 2 Loading: every row at once from the store; unresolved card values pass `empty`.
    static let loading = rows(0..<10, live: false)
    /// §3 3 Some KPIs already on Home: their rows do not appear (OQ-001's default).
    static let someOnHome = rows(onHomeByDefault..<10, live: true)
    /// §3 4 All KPIs already on Home: an empty list under the header.
    static let allOnHome = rows(0..<0, live: true)
    /// §3 5 Add failed: nothing is added, the row stays, nothing else changes (OQ-002).
    static let addFailed = rows(0..<10, live: true)
}

#Preview("Populated") {
    HomeKpiPickerScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Loading") {
    HomeKpiPickerScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Some KPIs already on Home") {
    HomeKpiPickerScreen(state: .someOnHome)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("All KPIs already on Home") {
    HomeKpiPickerScreen(state: .allOnHome)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Add failed") {
    HomeKpiPickerScreen(state: .addFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
