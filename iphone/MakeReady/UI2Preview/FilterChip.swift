//
//  FilterChip.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-035-filter-chip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-035 FilterChip — "a 24pt pill whose label is the filter's current selection", and since the
/// 2026-10-10 merge of C-101 FontChip also the 36pt font-sample chip (OQ-C-035-001).
///
/// Every type hugs its label (§3b "Width is not a variant"). It paints no page background and
/// adds no outer padding; the frame and background belong to the capture call site (R-16).
///
/// Three types (§3a). `Menu` is a bordered, chevroned selector that presents C-036; `Button` is a
/// chevron-less segmented single-select with no border (OQ-C-035-5); `Font` samples a C-092 face
/// in a 36pt outlined chip that drops its border and fills white when selected.
///
/// The chip is the tappable control (OQ-C-035-003): `Menu` fires `onTap`, `Button` and `Font`
/// fire `onSelect`, every type with the system press feedback OQ-C-035-6 ratified.
struct FilterChip: View {

    /// C-035 §4 `type: Menu | Button | Font` (R-06, nested per R-36). `Menu` and `Button` are the
    /// source axis values; `Font` is the contract's name for the 'Font button' set (OQ-C-035-001).
    enum ChipType: String {
        case menu = "Menu"
        case button = "Button"
        case font = "Font"
    }

    /// §4 `type`.
    let type: ChipType
    /// §4 `active` — applied filter / selected option / selected font (§3a).
    let active: Bool
    /// §4 `label` — Menu: the filter's current selection; Button: the category; Font: the face's
    /// display name (§2's closed table).
    let label: String
    /// §4 `font: C-092 font` — the face the label is set in. Required in `type=Font` and ignored
    /// by the other types, so it is optional here and nil for Menu/Button (R-07 callout).
    let font: CanvasTextObject.Font?
    /// §4 `onTap` — `type=Menu`: presents C-036 FilterMenuOverlay. No render effect.
    let onTap: () -> Void
    /// §4 `onSelect` — `type=Button` / `type=Font`: the chip was chosen in its group
    /// (OQ-C-035-5). No render effect.
    let onSelect: () -> Void

    init(
        type: ChipType,
        active: Bool,
        label: String,
        font: CanvasTextObject.Font? = nil,
        onTap: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.type = type
        self.active = active
        self.label = label
        self.font = font
        self.onTap = onTap
        self.onSelect = onSelect
    }

    // MARK: - Geometry (§2)

    private enum Geometry {
        /// §2: height **24** in `Menu` and `Button`.
        static let pillHeight: CGFloat = 24
        // FLAGGED LITERAL — C-035 §2: "The px 8 inset and the 4pt gap (`Menu`, `Button`). Recorded
        // as measured values rather than as `space-element-gap` (8) and `space-meta-gap` (4)."
        static let horizontalInset: CGFloat = 8
        static let menuGap: CGFloat = 4
        // FLAGGED LITERAL — C-035 §2: "The `Font` inset 8 on every side — the same pill-inset
        // case, carried from C-101 §2."
        static let fontInset: CGFloat = 8
        /// §2 Label (`Font`): "size **17**, line box **18**".
        // FLAGGED LITERAL — C-035 §2: "The `Font` label 17/18 in a non-SF face — no `type-*` token
        // can express a caller-chosen face; size and leading are the measured values."
        static let fontLabelSize: CGFloat = 17
        static let fontLabelBox: CGFloat = 18
        /// §3a: the 1px / 1pt border of `Menu` and of inactive `Font`.
        static let borderWidth: CGFloat = 1
    }

    // MARK: - Variant resolution (§3a's closed matrix)

    /// §3a Ground: `Menu/true` `color-text-primary` (white, OQ-C-035-4b) · `Button/true`
    /// `color-neutral-800` · `Font/true` `color-white-100` · every inactive row none.
    private var ground: Color {
        switch (type, active) {
        case (.menu, true): return Token.textPrimary
        case (.button, true): return Token.neutral800
        case (.font, true): return Token.white100
        default: return .clear
        }
    }

    /// §3a Border: `Menu/false` 1px `color-neutral-600` · `Menu/true` 1px white, invisible (§1
    /// deviation 3 — drawn so the active pill keeps §3a's 70) · `Font/false` 1pt `color-nav-border`
    /// · `Font/true` none ("the border is dropped, not recoloured") · `Button` none.
    private var border: Color? {
        switch (type, active) {
        case (.menu, false): return Token.neutral600
        case (.menu, true): return Token.textPrimary
        case (.font, false): return Token.navBorder
        default: return nil
        }
    }

    /// §3a Chevron: `color-text-secondary` inactive, `color-black` active (`Menu` only).
    private var chevronColor: Color { active ? Token.black : Token.textSecondary }

    /// §3a Label colour.
    private var labelColor: Color {
        switch (type, active) {
        case (.menu, true), (.font, true): return Token.black
        case (.button, true): return Token.textPrimary
        case (.font, false): return Token.navText
        default: return Token.textNavigation
        }
    }

    /// §2 measures every inset from INSIDE the border: "1 + 8 + 16 + 4 + 32 + 8 + 1 = **70**", and
    /// the Font chip's "Width = label + 16 (+ 2 when outlined)". A bordered chip insets by 9.
    private var borderInset: CGFloat { border == nil ? 0 : Geometry.borderWidth }

    // MARK: - Body

    var body: some View {
        // `SwiftUI.Button`: this module's own C-105 `Button` shadows SwiftUI's unqualified.
        SwiftUI.Button(action: type == .menu ? onTap : onSelect) {
            chip
        }
        // OQ-C-035-6 (owner, 2026-09-16): "standard system press feedback, no bespoke symbol" —
        // `.plain` is the framework's own pressed dim, in every type.
        .buttonStyle(.plain)
        // R-17 / §4 Accessibility: label = `label`, `.isButton` plus `.isSelected` when `active`.
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("FilterChip")
    }

    @ViewBuilder
    private var chip: some View {
        if type == .font {
            fontLabel
                .padding(Geometry.fontInset + borderInset)
                .background(RoundedRectangle(cornerRadius: Token.Radius.card).fill(ground))
                .overlay(borderOverlay)
        } else {
            HStack(spacing: type == .menu ? Geometry.menuGap : 0) {
                if type == .menu { chevron }
                pillLabel
            }
            .padding(.horizontal, Geometry.horizontalInset + borderInset)
            .frame(height: Geometry.pillHeight)
            // §2: `radius-card` (8) — a rounded rect, not a capsule.
            .background(RoundedRectangle(cornerRadius: Token.Radius.card).fill(ground))
            .overlay(borderOverlay)
        }
    }

    /// `strokeBorder`: the border draws INSIDE the chip, which is what makes §2's widths close.
    private var borderOverlay: some View {
        border.map { colour in
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .strokeBorder(colour, lineWidth: Geometry.borderWidth)
        }
    }

    // MARK: - Parts (§2 anatomy)

    /// §2 Chevron: "**16×16**, leading — the library glyph **`chevron-down-carbon`** (Carbon
    /// `chevron--down`, template paint)", tinted by token at the call site (D21). `.sm` is the 16pt
    /// box; the glyph's own grid places the 10×5.7 vector inside it.
    private var chevron: some View {
        Glyph(.chevronDownCarbon, size: .sm, tint: chevronColor)
            .ui2Element("Chevron")
    }

    /// §2 Label (`Menu`, `Button`): `type-title-card` (Bold 14/20) in both types — OQ-C-035-3's
    /// ruling; the source's 14/22 and 14/24 are §1 deviation 6. `nowrap`, never truncated (§3c).
    private var pillLabel: some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.titleCard)
            .foregroundColor(labelColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            // The line box IS the leading (§2 "Line box = the leading").
            .frame(height: Token.TypeStyle.titleCard.lineHeight ?? Token.TypeStyle.titleCard.size)
            .ui2Element("Label")
    }

    /// §2 Label (`Font`): the display name set in the font's own face at 17, line box 18, `nowrap`.
    private var fontLabel: some View {
        Text(label)
            .font(fontFace)
            .foregroundColor(labelColor)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: Geometry.fontLabelBox)
            .ui2Element("Label")
    }

    /// OQ-C-035-004 (owner, 2026-10-13): "As the sheet draws each face — Poppins Bold, SF Pro
    /// Text Medium, Georgia Regular, American Typewriter Regular; the chip samples the face, not
    /// the canvas weight." (C-092 renders every face Bold on the canvas; this row does not.)
    private var fontFace: SwiftUI.Font {
        let points = Geometry.fontLabelSize
        switch font {
        case .poppins: return .custom("Poppins-Bold", fixedSize: points)
        case .georgia: return .custom("Georgia", fixedSize: points)
        case .typewriter: return .custom("AmericanTypewriter", fixedSize: points)
        // `.sfPro`, and a nil `font` the capture case refuses before it gets here (§4: required
        // in `type=Font`).
        case .sfPro, .none:
            return DesignTextStyle(weight: .medium, size: points, lineHeight: nil, tracking: 0).font
        }
    }
}
