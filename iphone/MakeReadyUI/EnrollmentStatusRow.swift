//
//  EnrollmentStatusRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-031-enrollment-status-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-031 EnrollmentStatusRow — "one aggregate's completion, as a disc + labelled bar row".
///
/// §2: 410×64 in the set, **width-driven** (§1 deviation 3 — the consumer renders it at 408
/// and the two flexing cells absorb the difference). "No fill, no border, no radius — the row
/// paints nothing of its own; every pixel belongs to one of its two slots."
///
/// Chrome-free (R-16): the row fills the width it is given and states its own 64pt height; it
/// paints no page background and adds no outer padding. Frame, background and outer margin
/// belong to the ViewRegistry call site.
///
/// §4, in the rulebook's shape: R-05 flat parameters in the contract's order, R-01 controlled
/// (every prop is caller-owned resolved data — R-04/R-19), R-07 all required, R-03 no closure
/// rows (the source designs no action on the row — §3b, ratified by OQ-C-031-4).
struct EnrollmentStatusRow: View {

    /// C-031 §4 `statusColor` — **OQ-C-031-1 (owner, 2026-09-21):** "statusColor takes the
    /// closed green / yellow / red set the way C-033 §3b does". This replaces §4's open `Color`
    /// cell; the tokens per value are C-033 §3b's, so the two rows read one set. Nested per
    /// R-36. Which threshold picks which value is settled program-wide by
    /// OQ-home-dashboard-3 / OQ-study-program-home-5, not here — the row takes the answer.
    enum StatusColor: String {
        case green
        case yellow
        case red

        /// C-033 §3b's token per value. Every one is a token by name (R-10).
        var token: Color {
            switch self {
            case .green: return Token.positive
            case .yellow: return Token.highlight
            case .red: return Token.negative
            }
        }
    }

    /// C-031 §4: `percent` — the disc's number, 0…100, WITHOUT the `%` (C-062 draws it, §3c).
    /// Passed through as C-062 `percent`. A different quantity from `progress` (§1 deviation 7,
    /// OQ-C-031-3: "% current" vs "% of target").
    let percent: Int
    /// C-031 §4: `label` — the metrics row's leading label; the first flexing cell (§2).
    let label: String
    /// C-031 §4: `count` — the metrics row's count, right-aligned in a fixed 40pt cell.
    /// **OQ-C-031-6 (owner, 2026-09-21):** "type count as Int, formatted by the component,
    /// matching percent" — replaces §4's `String` cell.
    let count: Int
    /// C-031 §4: `progress` — 0…1, passed through as C-057 `progress`.
    let progress: Double
    /// C-031 §4: `subtitle` — the second line, `color-text-secondary`, one line.
    let subtitle: String
    /// C-031 §4: `statusColor` — "the one status colour the row spends three ways": C-062's
    /// `statusColor` override (its 20% ground + 100% number) and C-057's `fillColor` (the bar
    /// fill).
    let statusColor: StatusColor

    var body: some View {
        // §2: "Root: a horizontal pair, vertically centred, gap 16".
        HStack(alignment: .center, spacing: Self.rootGap) {
            disc
            info
        }
        .frame(maxWidth: .infinity, alignment: .leading)   // fills the width it's given (R-16)
        .ui2Element("EnrollmentStatusRow")                 // capture element map — UI2Element.swift
    }

    // MARK: - §2.1 Disc

    /// §2: "**C-062 PercentDisc**, supplying `statusColor`, centred in a **fixed 64×64 slot**.
    /// The slot is what sets the row's 64pt height — it is the row's, not C-062's 80 (the
    /// source instance is the bare 64 disc at the row's origin), and it never changes with
    /// content."
    ///
    /// C-062's built view states an **80×80 slot** in every variant (C-062 §2/§3c: "a consumer
    /// reserves 80 for every variant and never re-flows"), which this row's §2 does not. The
    /// slot is therefore constrained to the row's 64 here — the circle is centred in its slot,
    /// so nothing painted moves — and the two contracts' disagreement is reported by the build
    /// as a gap rather than resolved by either view.
    ///
    /// **The diameter follows `percent`** — §2 / §1 deviation 9, owner ruling 2026-09-21
    /// (`/d2m-resolve C-031 poor-completion-red`): "a 12% completion should produce a smaller
    /// circle than a 100% completion". Not drawn in Figma — the set's one symbol draws 78% at
    /// 64, which §2's table renders at 56; that difference is expected, not a defect.
    private var disc: some View {
        PercentDisc(percent: percent, size: Self.discSize(for: percent), statusColor: statusColor.token)
            .frame(width: Self.discSlot, height: Self.discSlot)
            .ui2Element("Disc")
    }

    // MARK: - §2.2 Info

    /// §2: "flexible width …, intrinsic height 46, vertically centred in the 64pt row (9pt above
    /// and below). A two-row column, gap 16". The column closes on 46 exactly: 16 + 16 + 14.
    private var info: some View {
        VStack(alignment: .leading, spacing: Self.infoGap) {
            metricsRow
            subtitleRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Info")
    }

    /// §2: "**Metrics row** — full width, 16 tall, contents vertically centred, gap
    /// `space-element-gap` (8). Three cells, left → right": Label (flexes), Count (fixed 40,
    /// right-aligned), C-057 PercentBar (flexes). At the set's 410 the two flexing cells are
    /// 137 each — both are given an unbounded max width, so the HStack splits the remainder
    /// between them equally.
    private var metricsRow: some View {
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            Text(label)
                .designTextStyle(Token.TypeStyle.body)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Label")
            // OQ-C-031-6: an Int "formatted by the component" — the source's "52" is the
            // designed sample; the disc formats its own number the same way.
            Text("\(count)")
                .designTextStyle(Token.TypeStyle.body)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                .frame(width: Self.countWidth, alignment: .trailing)
                .ui2Element("Count")
            // §4 "What this row fixes on its sub-components": C-057 `size = lg`, `aligned =
            // Right`, `fillStyle = solid`, `thresholds` = C-057's default (inert while
            // `fillColor` is non-nil), `fillAnimation = nil` (OQ-C-031-001: "the bar sits at
            // progress on first paint, exactly as the static symbol shows").
            PercentBar(
                progress: progress,
                fillColor: statusColor.token,
                size: .lg,
                aligned: .right,
                fillStyle: .solid,
                fillAnimation: nil
            )
            .frame(maxWidth: .infinity)
        }
        .frame(height: Self.metricsRowHeight)
        .ui2Element("Metrics row")
    }

    /// §2: "**Subtitle** — full width, `type-body` (Regular 14/14) `color-text-secondary`, one
    /// line."
    private var subtitleRow: some View {
        Text(subtitle)
            .designTextStyle(Token.TypeStyle.body)
            .foregroundColor(Token.textSecondary)
            .lineLimit(1)
            // `type-body` is 14/14 and §2 closes the column on "16 + 16 + 14". SwiftUI has no
            // line-height — `designTextStyle` spells 14/14 as zero lineSpacing, so a single
            // line reports its ~17pt font box and the column comes out 3pt tall. Stating the
            // 14 box makes the rendered anatomy match the contract's; same fix, and the same
            // reason, as C-062 PercentDisc's number block.
            .frame(height: Self.subtitleLineBox)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Subtitle")
    }

    // MARK: - §2 constants

    /// §2: the fixed 64×64 disc slot — the largest step of this row's ladder (`Green 2`), the
    /// provider's own value for that variant, and the only thing that sets the row's 64pt height.
    private static let discSlot: CGFloat = PercentDisc.Size.green2.diameter

    /// §2's closed table (owner ruling 2026-09-21, deviation 9; the mapping's exact steps are
    /// OQ-C-031-002): `percent` scaled linearly 40→64 across 0→100 and snapped to the nearest
    /// designed C-062 diameter that fits the 64 slot, ties to the larger. `Green 1` (80) is not
    /// in this row's ladder — it cannot fit the designed 64 row.
    private static func discSize(for percent: Int) -> PercentDisc.Size {
        switch percent {
        case ..<9: return .size6        // §2: 0–8 → 40
        case ..<25: return .red1        // §2: 9–24 → 44
        case ..<50: return .yellow2     // §2: 25–49 → 48
        case ..<84: return .yellow1     // §2: 50–83 → 56
        default: return .green2         // §2: 84–100 → 64
        }
    }

    // FLAGGED LITERAL — C-031 §2: "Root: a horizontal pair, vertically centred, gap **16** —
    // FLAGGED LITERAL: `tokens.md`'s spacing family is 16/16/8/32/4/2/24, and its two 16s
    // (`space-page-margin`, `space-card-padding`) are a page inset and a card inset. Neither
    // names a gap *inside* a row between a leading indicator and its content column".
    // OQ-C-031-6 (owner, 2026-09-21): "Keep the two 16s as flagged literals".
    private static let rootGap: CGFloat = 16

    // FLAGGED LITERAL — C-031 §2: the Info column's "gap **16** — the same flagged literal as
    // the root gap, and for the same reason". OQ-C-031-6: kept.
    private static let infoGap: CGFloat = 16

    /// §2: "Metrics row — full width, **16** tall" — the height C-057 `size=lg` states; the
    /// row is framed to it so the label and count centre against the bar.
    private static let metricsRowHeight: CGFloat = 16

    // GAP — C-031 §2: "Count — right-aligned in a fixed **40pt** cell" has no spacing token
    // (the family is 16/16/8/32/4/2/24). Traces cleanly to that line; raised by the build for
    // a token row or a flag on the contract line.
    private static let countWidth: CGFloat = 40

    /// §2: `type-body`'s measured 14/14 leading — the subtitle's designed line box.
    private static let subtitleLineBox: CGFloat = 14
}
