//
//  TagChip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-068-tag-chip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-068 TagChip — "filled label pill that renders one tag of a tag list".
///
/// §2: "A single-line text run inside a filled pill. No border, no icon, no shadow, no
/// sub-components." Content-sized: §1 deviation 2 — "the chip is content-width (hug) — a
/// consumer never sets its width, and a chip wider than its host's available width truncates
/// its label with a tail ellipsis rather than growing or wrapping." Its 22pt height is the
/// label's 14pt line box plus the 4/4 insets and nothing else. Frame, background and outer
/// padding belong to the call site (R-16).
///
/// Static display (OQ-C-068-1, ruled 2026-09-21): no events, no pressed / selected / removable
/// state — "tap, selection and removal belong to the host". `Solid` is a `style` value a
/// consumer opts into, not a selected state.
struct TagChip: View {

    /// §4 `style` — `default | solid`, "maps 1:1 onto the Figma `style` axis". Nested per R-36.
    enum Style: String {
        case `default`
        case solid
    }

    /// §4 `label` — "the tag text; single line, tail-ellipsized when wider than the host allows".
    let label: String
    /// §4 `style` — "selects the fill/label colour pair". Defaulted because §4 names a default.
    let style: Style

    init(label: String, style: Style = .default) {
        self.label = label
        self.style = style
    }

    var body: some View {
        Text(label)
            // §2 Label: `type-caption` (SF Pro Regular 12/14), colour per `style` (§3).
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundStyle(labelColor)
            // §2 / §1 deviation 2: single line, tail-ellipsized — never grows or wraps.
            .lineLimit(1)
            .truncationMode(.tail)
            // §2: "14pt line box + 4/4 insets = the 22pt chip height". SwiftUI's lineSpacing
            // does nothing to a single line and SF Pro's natural 12pt box is taller than 14,
            // so the line box is pinned — the same construction C-042's row label uses.
            .frame(height: Self.labelLineBox)
            .ui2Element("Label")
            // FLAGGED LITERAL — C-068 §2: "horizontal inset 8, vertical inset 4 — flagged
            // literals (no Figma variable … not cited as `space-element-gap`/`space-meta-gap`
            // because those name gaps, not insets)".
            // GAP — OQ-C-068-2 (ruled 2026-09-21): "Mint space-chip-inset-x (8) /
            // space-chip-inset-y (4) and cite them" — neither row is in the register yet, so
            // the literal stands until the re-spec mints them.
            .padding(.horizontal, Self.insetX)
            .padding(.vertical, Self.insetY)
            .background(
                // §2 Container: fill per `style` (§3), corner = a full capsule.
                // GAP — OQ-C-068-3 (ruled 2026-09-21): "Mint radius-pill (a capsule: half the
                // height) and cite it from the chips instead of borrowing radius-modal." No
                // `radius-pill` row exists yet; `Capsule()` IS half-the-height, so it renders
                // the ruled geometry without borrowing `Token.Radius.modal` (which §2 cited by
                // value and the ruling retired).
                Capsule()
                    .fill(fill)
                    .ui2Element("Container")
            )
            .ui2Element("TagChip")     // capture element map — UI2Element.swift
    }

    /// §3: `Default` fill `color-white-20`; `Solid` fill `color-accent`.
    private var fill: Color {
        switch style {
        case .default: Token.white20
        case .solid: Token.accent
        }
    }

    /// §3: `Default` label `color-white-70`; `Solid` label `color-text-primary`.
    private var labelColor: Color {
        switch style {
        case .default: Token.white70
        case .solid: Token.textPrimary
        }
    }

    /// §2: the label's 14pt line box — `type-caption`'s leading, the middle term of 22 = 4 + 14 + 4.
    private static let labelLineBox: CGFloat = Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size
    /// §2: the pill's measured insets — see the flag on `body`'s padding.
    private static let insetX: CGFloat = 8
    private static let insetY: CGFloat = 4
}
