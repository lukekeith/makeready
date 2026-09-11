//
//  DayActivityCard.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-025-day-activity-card.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  The contract is one file for three registry rows — C-025 and its two sub-blocks, C-070
//  DateBlock (§3c) and C-071 ValuePair (§3b) — because "they ship together, and neither is
//  instantiated anywhere but inside this card" (C-025 §1). Neither has a contract file of its
//  own, so neither is a legal `/ui2-component-build` target (that command's phase 0.3); they
//  are built here, in this file, as the fallback preview-build.md §4 allows. They are
//  `internal`, not `private`, for one reason: C-025 §4 types `date` and `details` as *their*
//  props, so the ViewRegistry call site has to be able to construct them.
//
//  C-062 PercentDisc is the third dependency and resolves at level 2 — its anchor is
//  `docs/ui2/screens/enrollment-home.md` §4, which D10 accepts as a full contract anchor. Only
//  the one band C-025 consumes (`Green 1`, 80pt) is built here; the other five belong to a
//  `/ui2-component PercentDisc <figma-url>` run. C-024 SparkBarChart resolves at level 1 and is
//  already built, so the real component is composed rather than stubbed.
//

import SwiftUI

/// C-025 DayActivityCard — one day's activity in a horizontally-scrolling day rail.
///
/// Unlike most of this module, the card is NOT width-driven: C-025 §2 opens "131×192 in every
/// state", so the footprint is the contract's and is stated here. It still paints no page
/// background and adds no outer padding — the ground and the outer margin belong to the
/// ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct DayActivityCard: View {

    /// C-025 §4 `state: default | transparent | percentCircle` (§3a's three designed states).
    ///
    /// `standard` spells §4's `default`, which is a Swift keyword — the same substitution
    /// `PageHeader.Style` makes, resolved in the ViewRegistry case rather than by a raw value.
    enum CardState {
        case standard
        case transparent
        case percentCircle
    }

    /// C-025 §4: `state`.
    let state: CardState
    /// C-025 §4: `date` (→ C-070 DateBlock's props).
    let date: DateBlock
    /// C-025 §4: `series: [Double]?` (→ C-024 SparkBarChart, the two chart states).
    let series: [Double]?
    /// C-025 §4: `percent: Int?` (→ C-062 PercentDisc, `percentCircle` only).
    let percent: Int?
    /// C-025 §4: `details` (→ C-071 ValuePair's props).
    let details: ValuePair

    var body: some View {
        // §2: "Three slots stacked top→bottom, gap `space-element-gap` (8), content width 97."
        VStack(spacing: Token.Space.elementGap) {
            date
                .frame(width: Self.contentWidth, height: Self.dateBlockHeight)
            bodySlot
                .frame(width: Self.contentWidth, height: bodySlotHeight)
                .ui2Element("Body slot")
            details
                .frame(width: Self.contentWidth, height: Self.valuePairHeight)
        }
        // §2: "Horizontal inset is 17 in every state — 1px border + 16 — so the 97pt content
        // width is the same throughout, measured inside the stroke."
        .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
        // §2: "The body slot absorbs the whole inset difference between the states."
        .padding(.vertical, verticalInset)
        // §2: "131×192 in every state."
        .frame(width: Self.width, height: Self.height)
        .background(background)
        .overlay(border)
        .ui2Element("DayActivityCard")            // capture element map — UI2Element.swift
    }

    // MARK: - Geometry (§2)

    // §2's stated dimensions. These are component MEASUREMENTS, not spacing values: the
    // spacing family in tokens.md covers gaps and insets, and has no vocabulary for a
    // component's own footprint. Same treatment C-024 §2's 97×64 sample footprint gets.
    private static let width: CGFloat = 131
    private static let height: CGFloat = 192
    private static let contentWidth: CGFloat = 97
    private static let dateBlockHeight: CGFloat = 38
    private static let valuePairHeight: CGFloat = 36
    private static let chartBodyHeight: CGFloat = 68          // §2: `Default`'s body slot
    private static let openBodyHeight: CGFloat = 86           // §2: `Transparent` / `Percent circle`

    // §3a: "1px `color-card-border`". The border insets the content, which is why §2 spells
    // the 17pt inset as "1px border + 16".
    private static let borderWidth: CGFloat = 1

    // GAP — C-025 §3a gives `Transparent` / `Percent circle` a "vertical inset 8", and
    // docs/ui2/design-system/tokens.md has no inset row for it, so it cannot resolve to a
    // Token member by name (preview-build.md §3 rule 4). The spacing family's only 8 is
    // `space-element-gap`, which §2 already spends on the gaps BETWEEN the three slots — a
    // different role, and naming it here would claim the two are one decision. Emitted as
    // C-025 §2's own literal; reported by the run. (Identical in shape to C-019 §2's 8pt row
    // inset, UI2Preview/TopNav.swift.)
    private static let openVerticalInset: CGFloat = 8

    // §3a `Default`: "vertical inset 17"; §2: "`Default` insets 17 vertically (1px border +
    // 16)". So the border and `space-card-padding` account for it in full.
    private var verticalInset: CGFloat {
        state == .standard ? Self.borderWidth + Token.Space.cardPadding : Self.openVerticalInset
    }

    private var bodySlotHeight: CGFloat {
        state == .standard ? Self.chartBodyHeight : Self.openBodyHeight
    }

    // MARK: - Body slot (§2 slot 2)

    @ViewBuilder
    private var bodySlot: some View {
        switch state {
        case .standard, .transparent:
            // §2: "Holds C-024 SparkBarChart (`align=center`) in the two chart states."
            // Everything except `series` and `align` is C-024's own contract: §4 defaults
            // `targetBars` and `averageLabel` to nil, and the frozen snapshot's chart carries
            // no average annotation, so `showAverage` is false. `widthFill` is `gaps` — the
            // mode that keeps §2's 2pt bar module, which is what the snapshot's bars measure.
            SparkBarChart(
                series: series ?? [],
                targetBars: nil,
                align: .center,
                widthFill: .gaps,
                showAverage: false,
                averageLabel: nil,
                averageLabelSide: .right
            )
        case .percentCircle:
            // §2: "a 97×86 `Percent` wrapper centring an 80×80 C-062 PercentDisc".
            PercentDisc(percent: percent ?? 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ui2Element("Percent")
        }
    }

    // MARK: - Chrome (§3a)

    @ViewBuilder
    private var background: some View {
        if state == .standard {
            // §3a `Default`: "`color-card-background` fill + rounded corners".
            RoundedRectangle(cornerRadius: Self.defaultCornerRadius)
                .fill(Token.cardBackground)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch state {
        case .standard:
            // §3a: "1px `color-card-border` on **all four** edges … rounded corners".
            RoundedRectangle(cornerRadius: Self.defaultCornerRadius)
                .strokeBorder(Token.cardBorder, lineWidth: Self.borderWidth)
                .ui2Element("Border")
        case .transparent, .percentCircle:
            // OWNER RULING 2026-09-10 (/ui2-component-build C-025): these two states carry NO
            // border at all. §3a currently reads "1px `color-card-border` on **left and right
            // only**, square, no fill. Adjacent cards in a rail share borders" — the owner
            // states the L/R hairlines exist in the Figma set for prototyping and are not
            // design. So `Transparent` is exactly what it says: no fill, no stroke.
            //
            // The geometry is unaffected: §2's 17pt horizontal inset ("1px border + 16") is
            // what keeps the 97pt content width identical in every state, and it holds
            // whether or not a stroke paints over it.
            //
            // SPEC DEFECT — the contract still says otherwise. Recording the ruling is a
            // `/ui2-component C-025` re-run's job, not this lane's (preview-build.md: a build
            // run never edits docs/ui2/).
            EmptyView()
        }
    }

    // GAP — C-025 §3a measures `Default`'s corner radius at 2pt. tokens.md's only 2 is
    // `radius-bar`, coined for sparkline bars, and OQ-C-025-2 is open on exactly this: a new
    // `radius-card-xs` row, or `radius-bar` reused under a widened note. Naming a bar radius
    // on a card here would pre-empt that ruling, so the measurement is carried as C-025 §3a's
    // own literal; reported by the run.
    private static let defaultCornerRadius: CGFloat = 2
}

// MARK: - C-070 DateBlock

/// C-070 DateBlock — the month/weekday label row over the day number (C-025 §3c).
///
/// 97×38 by contract, but sized by its container here: §3c states the internal stack (a 97×12
/// label row, gap 8, a 24×18 day number) and C-025 §2 gives the slot, so the slot is the
/// frame and this view lays out inside it.
struct DateBlock: View {

    /// C-025 §4 `state: default | today`. `standard` spells `default`, a Swift keyword.
    enum DateState {
        case standard
        case today
    }

    /// C-025 §4: `month: String`.
    let month: String
    /// C-025 §4: `weekday: String`.
    let weekday: String
    /// C-025 §4: `day: String`.
    let day: String
    /// C-025 §4: `state` — `today` "renders the single highlighted label and ignores
    /// `month`/`weekday`".
    let state: DateState

    var body: some View {
        // §3c: "a 97×12 label row, gap `space-element-gap` (8), then the day number (24×18)".
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            labelRow
                .frame(maxWidth: .infinity, minHeight: Self.labelRowHeight,
                       maxHeight: Self.labelRowHeight, alignment: .leading)
                .ui2Element("Label row")
            Text(day)
                .designTextStyle(Self.dayNumberStyle)
                // §3c: day number "Bold 18 `color-text-primary`" in both states.
                .foregroundColor(Token.textPrimary)
                // §3c's 18pt line box. Framed explicitly for the reason C-045 §2 documents:
                // SwiftUI has no line-height, so a single run otherwise sits in its own font
                // box and the stack closes short of 38.
                .frame(maxWidth: .infinity, minHeight: Self.dayNumberHeight,
                       maxHeight: Self.dayNumberHeight, alignment: .leading)
                .ui2Element("Day number")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ui2Element("DateBlock")
    }

    @ViewBuilder
    private var labelRow: some View {
        switch state {
        case .standard:
            // §3c `Default`: "month (left) + weekday (right, justified to the 97pt edge), both
            // `type-caption-bold` `color-text-secondary`".
            HStack(spacing: 0) {
                Text(month)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    .foregroundColor(Token.textSecondary)
                    .ui2Element("Month")
                Spacer(minLength: 0)
                Text(weekday)
                    .designTextStyle(Token.TypeStyle.captionBold)
                    .foregroundColor(Token.textSecondary)
                    .ui2Element("Weekday")
            }
        case .today:
            // §3c `Today`: "ONE label, \"TODAY\", `type-caption-bold` `color-highlight`; the
            // weekday slot is not rendered".
            Text(Self.todayLabel)
                .designTextStyle(Token.TypeStyle.captionBold)
                .foregroundColor(Token.highlight)
                .ui2Element("Today label")
        }
    }

    // §3c: the `Today` label is the literal string "TODAY" — a designed value, not content:
    // §4 gives the state no string prop, and C-025 §1 deviation 1 lists "TODAY" among the
    // sample strings precisely because the state renders it rather than taking it.
    private static let todayLabel = "TODAY"

    // §3c: "a 97×12 label row" and a day number in an "18pt line box".
    private static let labelRowHeight: CGFloat = 12
    private static let dayNumberHeight: CGFloat = 18

    // GAP — C-025 §3c: the day number is "Bold 18 `color-text-primary`, 18pt line box
    // (OQ-C-025-3)". tokens.md's `type-value-emphasis` is SF Pro Bold 18/**24** — same face,
    // size and weight, a different line box — and there is no 18/18 row, so there is no token
    // to name (preview-build.md §3 rule 4). OQ-C-025-3 asks the owner for exactly this: a new
    // token row, or a flag on the contract line. Until then the style is carried locally.
    private static let dayNumberStyle = DesignTextStyle(
        weight: .bold, size: 18, lineHeight: 18, tracking: 0
    )
}

// MARK: - C-071 ValuePair

/// C-071 ValuePair — two stacked caption lines whose colour pair is the state (C-025 §3b).
///
/// 95×36 in its own frame, 97 inside C-025 (§1 deviation 3: "the block is width-driven"), so
/// it takes the width it is given.
struct ValuePair: View {

    /// C-025 §4: "`state` — the seven values of §3b."
    ///
    /// §3b spells its rows as display labels (`Lesson day`, `Single muted`); §4's other two
    /// state props in this contract (`default | transparent | percentCircle`, `default |
    /// today`) give the lowerCamel form of the same labels, so that is the form used here.
    /// `standard` spells `default`, a Swift keyword.
    enum PairState {
        case standard
        case nothing
        case muted
        case lessonDay
        case highlighted
        case single
        case singleMuted
    }

    /// C-025 §4: `line1: String`.
    let line1: String
    /// C-025 §4: `line2: String?` (nil in `Single` / `Single muted`).
    let line2: String?
    /// C-025 §4: `state` — the seven values of §3b.
    let state: PairState

    var body: some View {
        // §3b: "Line 1 over line 2, both `type-caption` (Regular 12/14)"; §2 gives the block
        // 36pt, which is 14 + `space-element-gap` + 14.
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            line(line1, color: line1Color).ui2Element("Line 1")
            if let line2, !isSingle {
                line(line2, color: line2Color).ui2Element("Line 2")
            }
        }
        // §3b `Single` / `Single muted`: "line 2 absent; block stays 36pt" — so the one line
        // stays where line 1 is, and the block does not re-centre (OQ-C-025-6 asks whether
        // the fixed height is contract or sub-component-frame artifact).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ui2Element("ValuePair")
    }

    private func line(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundColor(color)
            .lineLimit(1)
            // §3b's 14pt line box (`type-caption` is Regular 12/**14**). Framed explicitly for
            // the reason C-045 §2 documents: `designTextStyle` spells 14 as lineSpacing, which
            // applies only BETWEEN lines, so a single run would otherwise sit in its own
            // ~12pt font box and the two-line stack would close short of 36.
            .frame(maxWidth: .infinity, minHeight: Self.lineBox,
                   maxHeight: Self.lineBox, alignment: .leading)
    }

    /// §3b: `Single` and `Single muted` are the two states with no line 2. The prop is
    /// `line2: String?`, so the state and the nil agree; the state wins, because it is what
    /// §3b designs.
    private var isSingle: Bool { state == .single || state == .singleMuted }

    // §3b's colour pairs, one row per designed state. Every value is a token by name.
    private var line1Color: Color {
        switch state {
        case .standard, .muted, .highlighted, .single: return Token.textPrimary
        case .nothing, .singleMuted: return Token.white20
        case .lessonDay: return Token.accent
        }
    }

    private var line2Color: Color {
        switch state {
        case .standard: return Token.positive
        case .nothing: return Token.white20
        case .muted, .lessonDay: return Token.textSecondary
        case .highlighted: return Token.highlight
        // §3b: line 2 is absent in both `Single` states — this branch never paints.
        case .single, .singleMuted: return Token.transparent
        }
    }

    // §3b: both lines are `type-caption` (Regular 12/14).
    private static let lineBox: CGFloat =
        Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size
}

// MARK: - C-062 PercentDisc

/// C-062 PercentDisc — the completion disc C-025 `Percent circle` centres.
///
/// LEVEL-2 DEPENDENCY (preview-build.md §4): C-062 has no contract file, so it is built from
/// its screen-spec anchor — `docs/ui2/screens/enrollment-home.md` §4, which D10 accepts as a
/// full contract anchor. That anchor states six designed bands whose "color AND diameter
/// encode the band"; C-025 §5 consumes exactly one of them ("C-062 PercentDisc (`Percent
/// circle`, at its 80pt `Green 1` size)"), so exactly one is built. The other five — and
/// therefore C-062's own `band` prop — belong to a `/ui2-component PercentDisc <figma-url>`
/// run, which is also what would give this row a fixture of its own.
struct PercentDisc: View {

    /// C-025 §4: `percent: Int?` — "`percent` and the disc's band delegate to C-062
    /// PercentDisc; the size/colour set is that row's and is not restated here."
    let percent: Int

    var body: some View {
        ZStack {
            Circle()
                // enrollment-home §4: "Fill = band color at 20% opacity." The colour is a
                // token by name; the 20% is the anchor's own stated modifier, the same shape
                // `color-accent-20` spells for accent (which has a row; green does not).
                .fill(Token.positive.opacity(Self.fillOpacity))
                .ui2Element("Disc")
            // Measured on the frozen snapshot: the number and the "%" are CENTRE-aligned to
            // each other, not baseline-aligned — the "%" ink sits 2pt above the digits'
            // baseline and their vertical centres coincide within half a point.
            HStack(alignment: .center, spacing: 0) {
                Text("\(percent)")
                    .designTextStyle(Self.numberStyle)
                    .foregroundColor(Token.positive)
                    .ui2Element("Number")
                Text(Self.percentSign)
                    .designTextStyle(Self.percentSignStyle)
                    .foregroundColor(Token.positive)
                    .ui2Element("Percent sign")
            }
        }
        // enrollment-home §4: `Green 1` is the 80pt band.
        .frame(width: Self.diameter, height: Self.diameter)
        .ui2Element("PercentDisc")
    }

    private static let diameter: CGFloat = 80
    private static let fillOpacity: Double = 0.2
    private static let percentSign = "%"

    // GAP — enrollment-home §4 (C-062): "number Bold 14 + \"%\" Semibold 9, in the band
    // color". tokens.md has no Bold 14 row for a number — `type-title-card` is SF Pro Bold
    // 14/20, a card-title role with a 20pt line box — and no 9pt row at all, so neither
    // resolves to a Token member by name (preview-build.md §3 rule 4). Both are
    // contract-traceable, so both are carried as the anchor's own literals and reported.
    private static let numberStyle = DesignTextStyle(
        weight: .bold, size: 14, lineHeight: nil, tracking: 0
    )
    private static let percentSignStyle = DesignTextStyle(
        weight: .semibold, size: 9, lineHeight: nil, tracking: 0
    )
}
