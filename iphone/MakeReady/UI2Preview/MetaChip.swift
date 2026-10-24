//
//  MetaChip.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-043-meta-chip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-043 MetaChip — "bordered inline chip that renders one metadata fact (a value, optionally
/// with a dimmed label)".
///
/// §2: "One or two single-line text runs inside a small-radius box. No icon, no shadow, no
/// sub-components. The box has two looks: outlined (`default`, `accent`, `complete`) and filled
/// (`highlighted` and `muted`)." Content-sized: §1 deviation 2 — "the chip is content-width
/// (hug) — a consumer never sets its width, and a chip wider than its host's available width
/// truncates its runs with a tail ellipsis (label first, so the value keeps priority) rather
/// than growing or wrapping."
/// Its 24pt height is §2's arithmetic in both looks — outlined 1 border + 4 inset + 14 line box
/// + 4 inset + 1 border, filled 2 inset + 20 line box + 2 inset — and nothing else (R-16,
/// stated rather than assumed, as §4 calls out). It paints no page background and adds no
/// outer padding: the host row owns the gap between chips (§2 Row usage).
///
/// Static display (OQ-C-043-4, ruled 2026-09-21): no events, no pressed / disabled state — the
/// tap belongs to the host row. No owned or ephemeral state (R-01 / R-02); every §3 state is a
/// prop combination.
struct MetaChip: View {

    /// §4 `state` — `default | accent | complete | highlighted | muted`: `default`/`accent`/
    /// `complete` "are outlined … and map 1:1 onto the Figma set's `state` axis (`accent` =
    /// Figma `Purple`, renamed by OQ-C-043-5)"; `highlighted` (accent fill) and `muted` (grey
    /// fill, OQ-enrollment-select-group-006) "are the filled look from the SelectCard
    /// instances". Nested per R-36.
    enum State: String {
        case `default`
        case accent
        case complete
        case highlighted
        case muted
    }

    /// §4 `labelPosition` — `trailing | leading`, "selects run order when `label` is non-nil:
    /// `trailing` = value then label (Figma `align=Left`), `leading` = label then value (Figma
    /// `align=Right`); ignored when `label` is nil". Renamed from `align` by OQ-C-043-1.
    /// Nested per R-36.
    enum LabelPosition: String {
        case trailing
        case leading
    }

    /// §4 `value` — "the emphasised run — a count, a date, a name, or a whole phrase; single
    /// line, keeps priority when the host is narrower than the chip (the label truncates
    /// first)". Required: per-instance content.
    let value: String
    /// §4 `label` — "the dimmed descriptor ('complete', 'hours', 'Joined', 'enrolled'); `nil`
    /// renders the `Single` type, non-nil the `Key value` type". Defaulted because the
    /// `Single` symbols show the chip without one (R-07).
    let label: String?
    /// §4 `state` — "selects the look per §2". Defaulted: `Default` is the base tone (R-07).
    let state: State
    /// §4 `labelPosition` — run order. Defaulted: `trailing` is the base; `leading` only
    /// reorders (R-07).
    let labelPosition: LabelPosition

    init(
        value: String,
        label: String? = nil,
        state: State = .default,
        labelPosition: LabelPosition = .trailing
    ) {
        self.value = value
        self.label = label
        self.state = state
        self.labelPosition = labelPosition
    }

    var body: some View {
        switch state {
        case .highlighted, .muted: filled
        case .default, .accent, .complete: outlined
        }
    }

    /// §2 Outlined container (`default`, `accent`, `complete`).
    private var outlined: some View {
        runs
            // FLAGGED LITERAL — C-043 §2: "horizontal inset 8, vertical inset 4 — flagged
            // literals (no Figma variable; the same 8/4 chip inset C-053 StatusBadge and C-068
            // TagChip measure and flag)".
            // GAP — OQ-C-043-7 (ruled 2026-09-21): "Mint space-chip-inset-x (8) /
            // space-chip-inset-y (4) with OQ-C-068-2" — neither row is in the register yet, so
            // the literal stands until the re-spec mints them.
            .padding(.horizontal, Self.insetX)
            .padding(.vertical, Self.insetY)
            // FLAGGED LITERAL — C-043 §2: "Border 1pt — flagged literal (no border-width token
            // exists in the era)". GAP — OQ-C-043-7 (ruled 2026-09-21) also mints
            // `border-hairline` (1); not in the register yet. The border is drawn INSIDE the
            // box (`strokeBorder`), so its 1pt is the outer term of §2's height arithmetic.
            .padding(Self.borderWidth)
            .overlay(
                // §2 Container: 1pt border per `state`, corner `radius-card-sm` (4), no fill —
                // "the page or card behind shows through".
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(borderColor, lineWidth: Self.borderWidth)
                    .ui2Element("Container")
            )
            // §4 R-17: no interactive element, so no traits; "the chip exposes one accessibility
            // label reading its runs in display order so a screen reader hears the fact as one
            // phrase". Whether it is an element of its own is the host's call.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(orderedRuns.joined(separator: " "))
            .ui2Element("MetaChip")     // capture element map — UI2Element.swift
    }

    /// §2 Filled container (`highlighted`, `muted`): "hug × 24pt; fill per `state`; no border;
    /// horizontal inset 4, vertical inset 2 — flagged literals (no Figma variable); corner
    /// radius 4 = `radius-card-sm`. Height: 2 inset + 20 line box + 2 inset = 24."
    private var filled: some View {
        runs
            // FLAGGED LITERAL — C-043 §2: "horizontal inset 4, vertical inset 2 — flagged
            // literals (no Figma variable)".
            .padding(.horizontal, Self.filledInsetX)
            .padding(.vertical, Self.filledInsetY)
            .background(
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .fill(fillColor)
                    .ui2Element("Container")
            )
            // §4 R-17 — as on the outlined look.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(orderedRuns.joined(separator: " "))
            .ui2Element("MetaChip")
    }

    /// §2 Runs: `Key value` is "two runs in a horizontal stack with gap `space-chip-gap` (2)"
    /// (§1 deviation 3, ratified by OQ-C-043-2); `Single` is one. Order per `labelPosition`
    /// (§3).
    /// Content centre-aligned on the cross axis (§2).
    private var runs: some View {
        HStack(alignment: .center, spacing: Token.Space.chipGap) {
            if labelPosition == .leading, let label {
                run(label, color: labelColor).ui2Element("Label")
            }
            run(value, color: valueColor)
                // §1 deviation 2 / OQ-C-043-4: the value keeps priority when the host is
                // narrow — the label shrinks first, the value only after it is gone.
                .layoutPriority(1)
                .ui2Element("Value")
            if labelPosition == .trailing, let label {
                run(label, color: labelColor).ui2Element("Label")
            }
        }
    }

    /// §2: outlined runs in `type-body` (SF Pro Regular 14/14), filled runs in `type-body-sm`
    /// (14/20); "single line, no wrap", tail-ellipsized (§1 deviation 2). The line box is
    /// pinned to the style's leading — SwiftUI's lineSpacing does nothing to a single line —
    /// the same construction C-068 TagChip and C-042's row label use, so the height arithmetic
    /// holds.
    private func run(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(runStyle)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: runStyle.lineHeight ?? runStyle.size)
    }

    /// §2: `type-body` on the outlined look, `type-body-sm` on the filled one.
    private var runStyle: DesignTextStyle {
        isFilled ? Token.TypeStyle.bodySm : Token.TypeStyle.body
    }

    /// §2: `highlighted` and `muted` are the filled look; the rest are outlined.
    private var isFilled: Bool {
        state == .highlighted || state == .muted
    }

    /// The runs in display order — what the accessibility label reads (§4 R-17).
    private var orderedRuns: [String] {
        guard let label else { return [value] }
        return labelPosition == .leading ? [label, value] : [value, label]
    }

    /// §2 colour table, border column: `default` `color-white-20` · `accent` `color-accent` ·
    /// `complete` `color-positive` · `highlighted` / `muted` none (the filled look draws no
    /// border).
    private var borderColor: Color {
        switch state {
        case .default: Token.white20
        case .accent: Token.accent
        case .complete: Token.positive
        case .highlighted, .muted: .clear
        }
    }

    /// §2 colour table, fill column: `highlighted` `color-accent-50` · `muted` `color-white-10`
    /// (OQ-enrollment-select-group-006) · the outlined looks none.
    private var fillColor: Color {
        switch state {
        case .highlighted: Token.accent50
        case .muted: Token.white10
        case .default, .accent, .complete: .clear
        }
    }

    /// §2 colour table, value column — as RULED by OQ-C-043-3 (2026-09-21): "Complete is
    /// border-only green with the runs keeping Default colours (so completion reads as an
    /// outline the way Purple does); fix the two green-run symbols in Figma." So the value run
    /// is `color-text-primary` in every outlined state; the frozen snapshot's green runs on
    /// `Complete/Single/Left` and `Complete/Key value/Left` are the Figma side falling behind
    /// the ruling, not a target for this view.
    /// `highlighted` is `color-white-70`, `muted` `color-white-50` (§2 colour table).
    private var valueColor: Color {
        switch state {
        case .highlighted: Token.white70
        case .muted: Token.white50
        case .default, .accent, .complete: Token.textPrimary
        }
    }

    /// §2 colour table, label column — `color-white-50` in every outlined state (OQ-C-043-3
    /// ruling; see `valueColor`); `highlighted` is `color-white-70` as RULED by OQ-C-043-001
    /// (2026-10-24): "with a label, both runs render in white 70% at gap 2, ordered by align";
    /// `muted` is `color-white-50` by the same one-colour rule (§2).
    private var labelColor: Color {
        state == .highlighted ? Token.white70 : Token.white50
    }

    /// §2: the outlined box's measured insets — see the flag on `outlined`'s padding.
    private static let insetX: CGFloat = 8
    private static let insetY: CGFloat = 4
    /// §2: the 1pt border — see the flag on `outlined`'s overlay.
    private static let borderWidth: CGFloat = 1
    /// §2: the filled box's measured insets — see the flag on `filled`'s padding.
    private static let filledInsetX: CGFloat = 4
    private static let filledInsetY: CGFloat = 2
}
