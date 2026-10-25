//
//  SectionHeader.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-020-section-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-020 SectionHeader — "the 24pt row that titles a page section and carries its one trailing
/// accessory".
///
/// §2: "One horizontal row: a **title** that takes all the width it can, and an optional
/// **accessory** cluster hugging the trailing edge. No background, no border, no padding of its
/// own — **width-driven per R-16**". The consumer owns the `space-page-margin` inset every
/// instance shows (§1 deviation 1).
struct SectionHeader: View {

    /// C-020 §4 `style` — "the title's face and colour (§3)".
    ///
    /// OQ-C-020-003 (answered 2026-09-25): "Strike `subsection` from the matrix — a superseded
    /// frame is not a normative source, and no live frame draws it; re-add it only when a
    /// screen designs it." §4 still lists it; the owner's answer on this row wins, so it has no
    /// case here.
    enum Style: String {
        case section
        case block
    }

    /// C-020 §4 `accessory` — "what the trailing cluster holds (§2)". Each case carries exactly
    /// the payload its sub-component needs; `glyph` takes C-021's set and `.link`'s `style`
    /// takes C-049's (§4 "Delegations").
    enum Accessory {
        case none
        case meta(value: String, label: String, glyph: GlyphButton.Glyph)
        case link(label: String, style: LinkButton.Style)
        /// §4 owner ruling: "`dropdown` is a trigger, not a chooser" — it carries only the
        /// `label` the caller sets from its own current selection; no option list, no selection.
        case dropdown(label: String)
        case caption(label: String, glyph: GlyphButton.Glyph)
    }

    /// §4 `title` — "the section name; single line, tail-truncates (§2). **Required**".
    let title: String
    /// §4 `style` — "**Defaults to `.section`** — the design shows it as the base on 15 of 16
    /// consumed instances (R-07)".
    var style: Style = .section
    /// §4 `accessory` — "**Defaults to `.none`** — the designed bare form (invite-home)".
    var accessory: Accessory = .none
    /// §4 `onAccessoryTap` — "raised by the accessory's one action: the C-021 button in `meta`
    /// and `caption`, the C-049 link in `link`, and the label-and-chevron trigger in `dropdown`.
    /// No-op default (R-03)". §4: "The prior `options`, `selected` and `onSelect` props are
    /// removed" — the C-036 the presenter shows owns the choice.
    var onAccessoryTap: () -> Void = {}

    var body: some View {
        // §2 Row: "horizontal, `items: center`, gap **8** = `space-element-gap`". Height falls
        // out of the taller of the title's line box and the accessory (24, or 24.5 with C-049).
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            titleText
            accessoryCluster
                // §2: the accessory is "`shrink-0` and never truncates"; the title yields first.
                .fixedSize()
                .layoutPriority(1)
        }
        .ui2Element("SectionHeader")                  // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Title: "`flex: 1`, `min-width: 1`, **single line, no wrap, tail-truncates with an
    // ellipsis**". Face and colour by `style`.
    private var titleText: some View {
        Text(title)
            .designTextStyle(titleStyle)
            .foregroundColor(titleColor)
            .lineLimit(1)
            .truncationMode(.tail)
            // SwiftUI has no line-height: `designTextStyle` spells the leading as lineSpacing,
            // which does nothing to a single line, so the designed line box (24 for `section`,
            // 16 for `block`) is pinned as a frame — the same construction C-022 and C-028 use.
            .frame(height: titleStyle.lineHeight ?? titleStyle.size)
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2 Accessibility (R-17): "the title is static text with the header trait".
            .accessibilityAddTraits(.isHeader)
            .ui2Element("Title")
    }

    private var titleStyle: DesignTextStyle {
        switch style {
        case .section: return Token.TypeStyle.sectionTitle    // §2: SF Pro Semibold 18/24
        case .block: return Token.TypeStyle.blockLabel        // §2: Regular 14/16
        }
    }

    private var titleColor: Color {
        switch style {
        // §1: the title's white is `text-white`, unbound in Figma — "hex-equal to
        // `color-text-primary`, cited as that row". §2 names the token, so the token is used.
        case .section: return Token.textPrimary
        case .block: return Token.textSecondary
        }
    }

    // §2 "The five accessories".
    @ViewBuilder private var accessoryCluster: some View {
        switch accessory {
        case .none:
            // §2: "nothing; the title spans the whole row".
            EmptyView()

        case let .meta(value, label, glyph):
            // §2: "C-022 MetaPair `layout=inline align=Left` … + 16 + C-021 GlyphButton".
            HStack(alignment: .center, spacing: Self.clusterGap) {
                MetaPair(value: value, label: label, layout: .inline, align: .left)
                GlyphButton(glyph: glyph, onTap: onAccessoryTap)
            }
            .ui2Element("Accessory")

        case let .link(label, linkStyle):
            // §2: "C-049 LinkButton alone, `style` per consumer … 24.5 tall".
            LinkButton(label: label, style: linkStyle, onTap: onAccessoryTap)
                .ui2Element("Accessory")

        case let .dropdown(label):
            // §4: "The `dropdown` trigger takes only its look from C-028". C-028 renders exactly
            // `selected` and nothing of `options` (C-028 §4), so the label goes in as both; the
            // option set belongs to the C-036 the presenter shows on `onAccessoryTap`.
            // Simultaneous, because C-028 already holds its ruled 44pt tap shape (OQ-C-028-3).
            InlineDropdown(options: [label], selected: label)
                .simultaneousGesture(TapGesture().onEnded(onAccessoryTap))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, onAccessoryTap)
                .ui2Element("Accessory")

        case let .caption(label, glyph):
            captionCluster(label: label, glyph: glyph)
        }
    }

    // §2 `caption`: "a caption text run, SF Pro **Regular 12/24** `color-text-secondary`,
    // `nowrap`, no underline … + 16 + **C-021 GlyphButton**".
    //
    // OQ-C-020-002 (answered 2026-09-25): "the caption and the glyph button are one control —
    // both fire onAccessoryTap, with one accessibility element labelled by the caption and the
    // 44pt target spanning the cluster."
    private func captionCluster(label: String, glyph: GlyphButton.Glyph) -> some View {
        HStack(alignment: .center, spacing: Self.clusterGap) {
            Text(label)
                .designTextStyle(Self.captionStyle)
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .frame(height: Self.captionLineBox)
                .ui2Element("Caption")
            GlyphButton(glyph: glyph, onTap: onAccessoryTap)
        }
        // The 44pt target spans the cluster: an expanded tap SHAPE centred on the 24pt row, not
        // a larger frame, so the row stays 24 — the construction C-021 / C-049 use.
        .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.captionLineBox) / 2))
        .onTapGesture(perform: onAccessoryTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onAccessoryTap)
        .ui2Element("Accessory")
    }

    // FLAGGED LITERAL — C-020 §2: "Internal gap **16** between a meta/caption text and its
    // glyph button — **flagged literal** (the same 16 C-050 and C-051 carry; no spacing token
    // has that role)."
    private static let clusterGap: CGFloat = 16

    // FLAGGED LITERAL — C-020 §2: the caption's "SF Pro **Regular 12/24** … (**flagged
    // literal**: the program's unrowed 12/24 face, OQ-C-027-2 cited)".
    private static let captionStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 24, tracking: 0
    )
    /// §2: the caption's 24pt line box, which is the row's height in `caption`.
    private static let captionLineBox: CGFloat = 24

    /// OQ-C-020-002 ruling: "the 44pt target spanning the cluster" — the same 44 C-021 §2 names;
    /// no token row exists for a tap target.
    private static let hitTarget: CGFloat = 44
}
