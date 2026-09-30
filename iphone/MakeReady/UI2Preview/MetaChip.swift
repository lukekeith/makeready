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
/// §2: "One or two single-line text runs inside a 1pt-bordered, unfilled, small-radius box. No
/// fill, no icon, no shadow, no sub-components." Content-sized: §1 deviation 2 — "the chip is
/// content-width (hug) — a consumer never sets its width, and a chip wider than its host's
/// available width truncates its runs with a tail ellipsis (value first, then label) rather
/// than growing or wrapping." Its 24pt height is §2's arithmetic — 1 border + 4 inset + 14
/// line box + 4 inset + 1 border — and nothing else (R-16, stated rather than assumed, as §4
/// calls out). It paints no page background and adds no outer padding: the host row owns the
/// gap between chips (§2 Row usage).
///
/// Static display (OQ-C-043-4, ruled 2026-09-21): no events, no pressed / disabled state — the
/// tap belongs to the host row. No owned or ephemeral state (R-01 / R-02); every §3 state is a
/// prop combination.
struct MetaChip: View {

    /// §4 `state` — `default | purple | complete`, "maps 1:1 onto the Figma `state` axis".
    /// Nested per R-36. OQ-C-043-5 (ruled 2026-09-21) renames `purple` → `accent`; that rename
    /// lands in §4 through `/d2m-component C-043`, and this view follows §4 as written so the
    /// fixture, the workbench's prop picker and the registry case all key on one spelling.
    enum State: String {
        case `default`
        case purple
        case complete
    }

    /// §4 `align` — `left | right`, "selects run order when `label` is non-nil: `left` = value
    /// then label, `right` = label then value; ignored when `label` is nil". Nested per R-36.
    /// OQ-C-043-1 (ruled 2026-09-21) renames it `labelPosition: trailing | leading`; same
    /// spec-side landing as `State.purple` above.
    enum Align: String {
        case left
        case right
    }

    /// §4 `value` — "the emphasised run — a count, a date, a name; single line, tail-ellipsized
    /// first when the host is narrower than the chip". Required: per-instance content.
    let value: String
    /// §4 `label` — "the dimmed descriptor ('complete', 'hours', 'Joined', 'enrolled'); `nil`
    /// renders the `Single` type, non-nil the `Key value` type". Defaulted because the
    /// `Single` symbols show the chip without one (R-07).
    let label: String?
    /// §4 `state` — "selects the border colour". Defaulted: `Default` is the base tone (R-07).
    let state: State
    /// §4 `align` — run order. Defaulted: `Left` is the base; `Right` only reorders (R-07).
    let align: Align

    init(value: String, label: String? = nil, state: State = .default, align: Align = .left) {
        self.value = value
        self.label = label
        self.state = state
        self.align = align
    }

    var body: some View {
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

    /// §2 Runs: `Key value` is "two runs in a horizontal stack with gap `space-chip-gap` (2)"
    /// (§1 deviation 3, ratified by OQ-C-043-2); `Single` is one. Order per `align` (§3).
    /// Content centre-aligned on the cross axis (§2).
    private var runs: some View {
        HStack(alignment: .center, spacing: Token.Space.chipGap) {
            if align == .right, let label {
                run(label, color: labelColor).ui2Element("Label")
            }
            run(value, color: valueColor)
                // §1 deviation 2 / OQ-C-043-4: the value keeps priority when the host is
                // narrow — the label shrinks first, the value only after it is gone.
                .layoutPriority(1)
                .ui2Element("Value")
            if align == .left, let label {
                run(label, color: labelColor).ui2Element("Label")
            }
        }
    }

    /// §2: `type-body` (SF Pro Regular 14/14), "single line, no wrap", tail-ellipsized (§1
    /// deviation 2). The 14pt line box is pinned — SwiftUI's lineSpacing does nothing to a
    /// single line and SF Pro's natural 14pt box is taller than 14 — the same construction
    /// C-068 TagChip and C-042's row label use, so the height arithmetic holds.
    private func run(_ text: String, color: Color) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.body)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.runLineBox)
    }

    /// The runs in display order — what the accessibility label reads (§4 R-17).
    private var orderedRuns: [String] {
        guard let label else { return [value] }
        return align == .right ? [label, value] : [value, label]
    }

    /// §2 colour table, border column: `Default` `color-white-20` · `Purple` `color-accent` ·
    /// `Complete` `color-positive`.
    private var borderColor: Color {
        switch state {
        case .default: Token.white20
        case .purple: Token.accent
        case .complete: Token.positive
        }
    }

    /// §2 colour table, value column — as RULED by OQ-C-043-3 (2026-09-21): "Complete is
    /// border-only green with the runs keeping Default colours (so completion reads as an
    /// outline the way Purple does); fix the two green-run symbols in Figma." So the value run
    /// is `color-text-primary` in every state; the frozen snapshot's green runs on
    /// `Complete/Single/Left` and `Complete/Key value/Left` are the Figma side falling behind
    /// the ruling, not a target for this view.
    private var valueColor: Color {
        Token.textPrimary
    }

    /// §2 colour table, label column — `color-white-50` in every state (OQ-C-043-3 ruling; see
    /// `valueColor`).
    private var labelColor: Color {
        Token.white50
    }

    /// §2: the runs' 14pt line box — `type-body`'s leading, the middle term of
    /// 24 = 1 + 4 + 14 + 4 + 1.
    private static let runLineBox: CGFloat = Token.TypeStyle.body.lineHeight ?? Token.TypeStyle.body.size
    /// §2: the box's measured insets — see the flag on `body`'s padding.
    private static let insetX: CGFloat = 8
    private static let insetY: CGFloat = 4
    /// §2: the 1pt border — see the flag on `body`'s overlay.
    private static let borderWidth: CGFloat = 1
}
