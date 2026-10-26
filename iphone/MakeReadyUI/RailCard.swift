//
//  RailCard.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-023-rail-card in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  One row, two Figma sources (C-023 §1, deviation 14; OQ-C-023-004 closed: Figma stays two
//  sets): `kind=metric` is the KPI set `3673:11163`, `kind=day` is the Day set `3672:9223`
//  absorbed from C-025 DayActivityCard by `/d2m-component-merge C-023 C-025` (2026-09-21).
//  C-025's retired view composed C-070 / C-071 / C-062 inline; every one of them has since
//  been built on its own row, so this view composes the real types (R-15).
//

import SwiftUI

/// C-023 RailCard — "one 192pt cell of a horizontally scrolling rail: a tracked metric
/// (`metric`) or one day of an enrollment (`day`)".
///
/// Width-driven, intrinsic height (R-16, C-023 §2a "Sizing under R-16"): the card fills the
/// width its host gives it — the Overview rail gives 140, the day rails give 131, and §3d
/// says width follows `kind` and is not a prop — and states an intrinsic height of 192. The
/// ground and the inset border are **the card's own** (§2a); the 16pt padding is inner; the
/// card adds no outer margin. The page ground and the outer margin belong to the ViewRegistry
/// call site.
///
/// Neither kind is interactive in v1 (home-dashboard §3 for `metric`; OQ-C-023-009 for
/// `day`), so there is no `onTap` and no callback (R-01 / R-03), and no interactive element
/// to label (R-17).
struct RailCard: View {

    /// C-023 §4 `kind: metric | day` — the absorbing axis; selects the whole form (§2a / §2b).
    /// This row's own enum, minted by the merge (R-06, R-36).
    enum Kind {
        case metric
        case day
    }

    /// C-023 §4 `state: standard | transparent | percentCircle` — the Day set's own axis
    /// (§3b), 1:1 with its three symbols (R-06, R-36). `standard` spells Figma `Default`
    /// (`default` is a Swift keyword — §4).
    enum DayState {
        case standard
        case transparent
        case percentCircle
    }

    // C-023 §4's seventeen rows, one parameter each, in the contract's order (R-05). Every
    // prop after `kind` is scoped to one kind: required within it, nil outside it — which is
    // why each is optional and defaults to nil ("so the other kind can omit it", §4). A nil
    // where the kind needs a value is a call-site defect, not a default (§4); the ViewRegistry
    // case guards for it, and the fallbacks below are only what keeps the view total.

    /// C-023 §4: `kind` — required.
    let kind: Kind

    // ── metric ──
    /// C-023 §4: `title` — the metric's name; wraps, capped at two lines (OQ-C-023-002).
    var title: String? = nil
    /// C-023 §4: `series` — → C-024 `series`, unscaled. **Both kinds**: metric (24 values;
    /// all zeros = `empty`) and `day · standard` / `transparent`; ignored in `percentCircle`.
    var series: [Double]? = nil
    /// C-023 §4: `averageLabel` — → C-024's average-line label; nil = line only (the one
    /// genuinely optional metric prop).
    var averageLabel: String? = nil
    /// C-023 §4: `value` — the headline number, pre-formatted by the consumer.
    var value: String? = nil
    /// C-023 §4: `trendDirection` — → C-077 `direction`; C-077's value set (R-36).
    var trendDirection: TrendIndicator.Direction? = nil
    /// C-023 §4: `trendPolarity` — → C-077 `polarity`; C-077's value set (R-36).
    var trendPolarity: TrendIndicator.Polarity? = nil
    /// C-023 §4: `trendLabel` — → C-077 `label`, pre-formatted, never signed.
    var trendLabel: String? = nil

    // ── day ──
    /// C-023 §4: `state` — selects the §3b row.
    var state: DayState? = nil
    /// C-023 §4: `month` — → C-070 `month`; ignored when `dateState = today`.
    var month: String? = nil
    /// C-023 §4: `weekday` — → C-070 `weekday`; ignored when `dateState = today`.
    var weekday: String? = nil
    /// C-023 §4: `day` — → C-070 `day`.
    var day: String? = nil
    /// C-023 §4: `dateState` — → C-070 `state`; C-070's value set (R-36).
    var dateState: DateBlock.State? = nil
    /// C-023 §4: `percent` — → C-062 `percent`; `percentCircle` only. Colour is C-062's ramp.
    var percent: Int? = nil
    /// C-023 §4: `line1` — → C-071 `line1`.
    var line1: String? = nil
    /// C-023 §4: `line2` — → C-071 `line2`; nil in C-071 `single` / `singleMuted`.
    var line2: String? = nil
    /// C-023 §4: `detailsState` — → C-071 `state`; C-071's value set (R-36).
    var detailsState: ValuePair.State? = nil

    // GAP — C-023: no contract prop for the intro (dashboard-chart-intros D12).
    /// dashboard-chart-intros: nil = the still render (D7). `intro.delay` is the card's place in
    /// its rail's cascade (D8), set by the screen.
    var intro: ChartIntro? = nil

    // GAP — no spacing token for the cascade's 8pt rise (dashboard-chart-intros §iphone C-023).
    private static let introRise: CGFloat = 8
    /// The card's vertical offset at intro progress `progress`.
    static func introOffset(progress: Double) -> CGFloat { introRise * CGFloat(1 - progress) }

    private var introProgress: Double { intro?.progress(fadeOnly: false) ?? 1 }

    var body: some View {
        Group {
            switch kind {
            case .metric: metricCard
            case .day: dayCard
            }
        }
        // §2c: "Height 192" is what the two kinds share; the width is the host's (R-16).
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
        .ui2Element("RailCard")                       // capture element map — UI2Element.swift
    }

    // MARK: - §2a `kind=metric` — "a name, a shape, a number, and a change"

    private var metricCard: some View {
        // §2a Card: "column, `items: start`, gap `space-element-gap` (8)".
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            // §2a Title: "`type-title-card` face, `color-text-primary` (deviation 7), full
            // width, **wraps**". OQ-C-023-002 (closed): "the two-line cap with tail
            // truncation; the chart keeps its two-line height".
            // Leading 20 → **40** at two lines: `designTextStyle` spells the leading as
            // lineSpacing = 20 − 14, which SwiftUI adds to the font's own ~16.7pt line (a
            // 22.7pt pitch). Spend only the difference to the token's line box, half of it
            // above and below, so each line is exactly 20.
            Text(title ?? "")
                .font(Token.TypeStyle.titleCard.font)
                .tracking(Token.TypeStyle.titleCard.tracking)
                .lineSpacing(Self.titleLeading)
                .padding(.vertical, Self.titleLeading / 2)
                .foregroundColor(Token.textPrimary)
                .lineLimit(Self.titleLineCap)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
            // §2a Chart: "C-024 SparkBarChart, `align=bottom`, `showAverage=true`,
            // `averageLabelSide=right`, full width (106). **`flex: 1`** — it takes whatever
            // height the rest leaves". OQ-C-023-003 (closed): "hold the card at 140×192 and
            // let the chart absorb it — 60pt under a two-line title (74 under one line)".
            SparkBarChart(
                series: series ?? [],
                targetBars: nil,                      // §4: "no `targetBars`"
                align: .bottom,
                // §4 "What each kind fixes on C-024" names no `widthFill` for `metric`;
                // C-024 requires one. `gaps` is what the frozen picture measures — 2pt bar
                // modules with the slack in the gaps — and is reported as a default taken.
                widthFill: .gaps,
                showAverage: true,
                averageLabel: averageLabel,
                averageLabelSide: .right,
                intro: intro?.delayed(by: 0.1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ui2Element("Chart")
            // §2a Value stack: "column, gap `space-element-gap` (8), full width".
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                // §2a Value: "`type-title-card` face, `color-text-primary`, `nowrap`; leading
                // 20 → **20**". Framed to the token's own line box: `designTextStyle` spells
                // the leading as lineSpacing, which does nothing to a single line.
                CountUpText(text: value ?? "", intro: intro, after: 0.1)
                    .designTextStyle(Token.TypeStyle.titleCard)
                    .foregroundColor(Token.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: Self.valueLineBox,
                           maxHeight: Self.valueLineBox, alignment: .leading)
                    .ui2Element("Value")
                // §2a Trend: "C-077 TrendIndicator, height 14; glyph by `trendDirection`,
                // colour by `trendPolarity`".
                TrendIndicator(
                    direction: trendDirection ?? .neutral,
                    polarity: trendPolarity ?? .neutral,
                    label: trendLabel ?? ""
                )
                .scaleEffect(0.6 + 0.4 * introProgress, anchor: .leading)
                .opacity(introProgress)
                .animation(intro?.animation(ChartIntroMotion.overshoot, after: 0.3), value: intro?.played)
                .ui2Element("Trend")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Value stack")
        }
        // §2a: "padding `space-card-padding` (16)" inside the "1px `color-card-border` inside
        // the frame" — children start at (17, 17); content column = width − 2 × 17.
        .padding(Self.borderWidth + Token.Space.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // §2a: "Ground `color-card-background`", "`radius-card-sm` (4)".
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .fill(Token.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .strokeBorder(Token.cardBorder, lineWidth: Self.borderWidth)
                .ui2Element("Border")
        )
        // §2a: "`overflow: clip`".
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.cardSm))
        .offset(y: Self.introOffset(progress: introProgress))
        .opacity(intro == nil ? 1 : introProgress)
        .animation(intro?.animation(ChartIntroMotion.rise), value: intro?.played)
        .chartIntroFade(intro)
    }

    // MARK: - §2b `kind=day` — "three slots over a 97pt content column"

    private var dayCard: some View {
        // §2b: "Three slots stacked top→bottom, gap `space-element-gap` (8), content width 97".
        VStack(spacing: Token.Space.elementGap) {
            // §2b slot 1: "C-070 DateBlock — 97×38".
            DateBlock(
                month: month ?? "",
                weekday: weekday ?? "",
                day: day ?? "",
                state: dateState ?? .default
            )
            .frame(maxWidth: .infinity, minHeight: Self.dateBlockHeight, maxHeight: Self.dateBlockHeight)
            .ui2Element("Date slot")
            // §2b slot 2: "Body slot — 97×68 (`standard`) or 97×86 (`transparent`,
            // `percentCircle`)".
            dayBodySlot
                .frame(maxWidth: .infinity, minHeight: dayBodyHeight, maxHeight: dayBodyHeight)
                .ui2Element("Body slot")
            // §2b slot 3: "C-071 ValuePair — 97×36 (fixed height by ruling, OQ-C-023-010)".
            ValuePair(
                line1: line1 ?? "",
                line2: line2,
                state: detailsState ?? .default
            )
            .frame(maxWidth: .infinity, minHeight: Self.valuePairHeight, maxHeight: Self.valuePairHeight)
            .ui2Element("Details slot")
        }
        // §2b: "Horizontal inset is 17 in every state — 1px border + 16 — so the 97pt content
        // width is the same throughout, measured inside the stroke".
        .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
        // §2b: "The body slot absorbs the whole inset difference between the states" —
        // `standard` insets 17 vertically, `transparent` / `percentCircle` inset 8.
        .padding(.vertical, dayVerticalInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(dayBackground)
        .overlay(dayBorder)
    }

    @ViewBuilder
    private var dayBodySlot: some View {
        switch state ?? .standard {
        case .standard, .transparent:
            // §2b / §4: "C-024 SparkBarChart (`align=center`, `widthFill=gaps`, no average
            // annotation) in the two chart states". Everything else is C-024's own default.
            SparkBarChart(
                series: series ?? [],
                targetBars: nil,
                align: .center,
                widthFill: .gaps,
                showAverage: false,
                averageLabel: nil,
                averageLabelSide: .right,
                intro: intro
            )
        case .percentCircle:
            // §2b: "a 97×86 `Percent` wrapper centring an 80×80 C-062 PercentDisc at (8.5, 3)".
            // §5: "at its 80pt size" — C-062's `Green 1` is the 80pt diameter; the colour is
            // C-062's ramp from `percent`, never chosen here (§4, OQ-C-023-008).
            PercentDisc(percent: percent ?? 0, size: .green1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ui2Element("Percent")
        }
    }

    @ViewBuilder
    private var dayBackground: some View {
        if state == .standard {
            // §3b `standard`: "`color-card-background` fill + `radius-card-xs` (2)".
            RoundedRectangle(cornerRadius: Token.Radius.cardXs)
                .fill(Token.cardBackground)
        }
    }

    @ViewBuilder
    private var dayBorder: some View {
        switch state ?? .standard {
        case .standard:
            // §3b `standard`: "1px `color-card-border` on **all four** edges", `radius-card-xs`.
            RoundedRectangle(cornerRadius: Token.Radius.cardXs)
                .strokeBorder(Token.cardBorder, lineWidth: Self.borderWidth)
                .ui2Element("Border")
        case .transparent, .percentCircle:
            // §3b `transparent` / `percentCircle`: "1px `color-card-border` on **left and
            // right only**, square, no fill. Adjacent cards share borders" — the overlap is
            // the rail's (−1 on every consuming screen), not the card's.
            HStack(spacing: 0) {
                Rectangle().fill(Token.cardBorder).frame(width: Self.borderWidth)
                Spacer(minLength: 0)
                Rectangle().fill(Token.cardBorder).frame(width: Self.borderWidth)
            }
            .ui2Element("Border")
        }
    }

    // MARK: - Geometry (§2)

    // §2's stated dimensions. Component MEASUREMENTS, not spacing values: the spacing family
    // covers gaps and insets and has no vocabulary for a component's own footprint — the
    // same treatment C-033 GroupFollowCard and C-024's sample footprint get.
    private static let height: CGFloat = 192                   // §2c: shared by both kinds
    private static let dateBlockHeight: CGFloat = 38           // §2b slot 1
    private static let valuePairHeight: CGFloat = 36           // §2b slot 3
    private static let chartBodyHeight: CGFloat = 68           // §2b: `standard`'s body slot
    private static let openBodyHeight: CGFloat = 86            // §2b: `transparent` / `percentCircle`
    private static let titleLineCap = 2                        // §3c / OQ-C-023-002 (closed)

    // §2a: "1px `color-card-border` inside the frame"; §2b: "1px border + 16".
    private static let borderWidth: CGFloat = 1

    // §2a Value: the `type-title-card` line box (Bold 14/**20**) — from the token's own leading.
    private static let valueLineBox: CGFloat =
        Token.TypeStyle.titleCard.lineHeight ?? Token.TypeStyle.titleCard.size

    // §2a Title: the `type-title-card` line box less the face's natural line height — the
    // leading actually left to spend between and around lines.
    private static let titleLeading: CGFloat = {
        let style = Token.TypeStyle.titleCard
        let natural = UIFont.systemFont(ofSize: style.size, weight: .bold).lineHeight
        return max(valueLineBox - natural, 0)
    }()

    // GAP — C-023 §2b: "`transparent` / `percentCircle` inset 8" vertically, and the spacing
    // register has no inset row for it. Its only 8 is `space-element-gap`, which §2b already
    // spends on the gaps BETWEEN the three slots — a different role, and naming it here would
    // claim the two are one decision. Emitted as §2b's own literal; raised for the owner
    // (same shape as C-019 §2's 8pt row inset in TopNav.swift, and as the retired C-025 view).
    private static let openVerticalInset: CGFloat = 8

    private var dayVerticalInset: CGFloat {
        // §2b: "`standard` insets 17 vertically (1px border + 16)".
        state == .standard ? Self.borderWidth + Token.Space.cardPadding : Self.openVerticalInset
    }

    private var dayBodyHeight: CGFloat {
        state == .standard ? Self.chartBodyHeight : Self.openBodyHeight
    }
}
