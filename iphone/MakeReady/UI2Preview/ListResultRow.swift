//
//  ListResultRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-037-list-result-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-037 ListResultRow — "one directory / search result: a circular image, a title, one line
/// of detail (text or chips) and a trailing glyph".
///
/// A controlled component (§4, owner note 2026-09-17; R-01 / R-04): it renders what it is
/// handed and reports interactions through `onTap` / `onCancel`, with no built-in domain
/// behaviour — no navigation, no mutation, no knowledge of members, groups or invites beyond
/// the `subject` axis that sets its geometry.
///
/// Chrome-free and width-driven (R-16; deviation 1, OQ-C-037-5): it fills the width it is
/// given and states its own intrinsic height — 80 (member/text), 84 (member/chips), 96
/// (group/any) — paints no background, draws no hairline (that is the consumer's) and adds no
/// outer padding.
struct ListResultRow: View {

    /// §4 `subject` — "Leading C-038 diameter (32 / 64) and the band height it sets". Nested
    /// per R-36; one case per §4 value (R-06).
    enum Subject: String {
        case member
        case group
    }

    /// §4 `detail` — "a description line + optional count, or a C-043 chip row".
    enum Detail: String {
        case text
        case chips
    }

    /// §4 `trailing` — "The trailing 18pt slot; `chevron` draws glyph `chevron-right-carbon`,
    /// `cancel` draws `close-outline-carbon`".
    enum Trailing: String {
        case chevron
        case cancel
        case none
    }

    /// One entry of §4 `chips: [C-043 MetaChip]` — "supplied whole by the consumer as C-043
    /// instances (each carrying C-043's own §4 props); this row never composes chip content
    /// itself". The fields are C-043's own props with C-043's own types, so no value set is
    /// restated here (§4 "No restated value sets").
    struct Chip {
        let value: String
        var label: String?
        var state: MetaChip.State = .default
        var align: MetaChip.Align = .left
    }

    /// §4 `subject` — required.
    let subject: Subject
    /// §4 `title` — required. "The single-line bold title (member name / group name)".
    let title: String
    /// §4 `detail` — required.
    let detail: Detail
    /// §4 `description` — "`detail=text` only — one line in `color-white-50`". Default `nil`.
    var description: String?
    /// §4 `count` — "`detail=text` only — the trailing accent number; nil or 0 → not
    /// rendered" (deviation 4). Default `nil`.
    var count: Int?
    /// §4 `chips` — "`detail=chips` only". Default `[]`.
    var chips: [Chip] = []
    /// §4 `trailing` — required.
    let trailing: Trailing
    /// §4 `imageURL` — "Passed through to the leading C-038 Avatar unchanged". Default `nil`.
    var imageURL: URL?
    /// §4 `initials` — "Passed through to C-038; C-038 derives its own Has photo / Initials /
    /// Unknown user state". Default `nil`.
    var initials: String?
    /// §4 `onTap: (() -> Void)?` — "The whole-row tap handler. nil → the row is inert: no press
    /// highlight, no button trait". Optional by contract, not R-03's `{}`, so the row can tell
    /// an inert row from a tappable one (deviation 7, R-17).
    var onTap: (() -> Void)?
    /// §4 `onCancel` — "`trailing=cancel` only — delivered by the 44pt hit target on the close
    /// glyph (deviation 8)". R-03's no-op default.
    var onCancel: () -> Void = {}

    var body: some View {
        Group {
            if let onTap {
                // §2 / deviation 7 (OQ-C-037-3): "system highlight over the whole row, no
                // geometry change" — the plain button style's ephemeral press (R-02).
                Button(action: onTap) {
                    band
                }
                .buttonStyle(.plain)
                // R-17: "the row is one button labelled by `title` (plus the description or
                // the chips' text, and the count)". `.contain` keeps the cancel target its own
                // element, so VoiceOver reaches both actions.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityPhrase)
                .accessibilityAddTraits(.isButton)
            } else {
                // §4: "nil → the row is inert" (invite-home's Accepted rows).
                band
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(accessibilityPhrase)
            }
        }
        .ui2Element("ListResultRow")           // capture element map — UI2Element.swift
    }

    /// §2: "vertical padding `space-card-padding` (16) above and below one horizontal Content
    /// band; the band is leading image → info column → optional count → trailing glyph,
    /// horizontal gap 16 between siblings."
    private var band: some View {
        // FLAGGED (D7) — C-037 §2: "The 16 horizontal gap between band siblings is cited as
        // `space-card-padding` only because it is value-equal and measures 16 in all five
        // symbols; a distinct row-gap token is a hygiene question".
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            leading
            info
            countText
            trailingSlot
        }
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2: no background, border or radius of its own; the whole band is the tap target.
        .contentShape(Rectangle())
        .ui2Element("Content")
    }

    /// §2 Leading: C-038 Avatar at 32 (`subject=member`) or 64 (`subject=group`), vertically
    /// centred in the band. C-038 derives its own state (deviation 3, OQ-C-037-4: no
    /// `showPhoto`; a missing photo is C-038's fallback).
    private var leading: some View {
        Avatar(imageURL: imageURL?.absoluteString, initials: initials, size: Self.avatarSize(subject))
            .ui2Element("Leading")
    }

    /// §2 Info: "column, gap `space-element-gap` (8), fills the remaining width (min-width 0),
    /// vertically centred in the band".
    private var info: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            titleText
            detailView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Info")
    }

    /// §2 Title: "one line, `type-title-card` (SF Pro Bold 14/20), `color-text-primary`,
    /// tail-truncated". The 20pt line box is pinned — lineSpacing does nothing to a single
    /// line — so §2's height arithmetic (80 = 16 + 20 + 8 + 20 + 16) holds.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.titleCard)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
            .ui2Element("Title")
    }

    @ViewBuilder private var detailView: some View {
        switch detail {
        case .text:
            // §2 Detail, `detail=text`: "description, one line, `type-body-sm` (SF Pro Regular
            // 14/20), `color-white-50`, tail-truncated" (OQ-C-037-7 minted `type-body-sm`).
            if let description {
                Text(description)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.white50)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
                    .ui2Element("Description")
            }
        case .chips:
            chipRow
        }
    }

    /// §2 Detail, `detail=chips`: "horizontal row of C-043 MetaChip (24pt), gap
    /// `space-meta-gap` (4); one line, clipped at the info column's trailing edge" (deviation
    /// 9, OQ-C-037-6). Each chip keeps its hug width (`fixedSize`); what crosses the edge is
    /// clipped, and the row never grows.
    private var chipRow: some View {
        HStack(alignment: .center, spacing: Token.Space.metaGap) {
            ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                MetaChip(value: chip.value, label: chip.label, state: chip.state, align: chip.align)
                    .ui2Element("Chip \(index + 1)")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .ui2Element("Chips")
    }

    /// §2 Count (`detail=text` only): "`type-body-sm` Regular 14/20 in `color-accent`, single
    /// line, immediately before the trailing glyph; absent when `count` is nil or 0".
    @ViewBuilder private var countText: some View {
        if detail == .text, let count, count > 0 {
            Text(String(count))
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.accent)
                .lineLimit(1)
                .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
                .ui2Element("Count")
        }
    }

    /// §2 Trailing: the library glyph drawn at 18×18, tinted by the ROW (deviation 5 — "the
    /// library artwork carries no colour or opacity of its own").
    @ViewBuilder private var trailingSlot: some View {
        switch trailing {
        case .chevron:
            // §2: "tinted `color-white-50`; y-centred; not a hit target of its own".
            glyph(.chevronRightCarbon, tint: Token.white50)
                .accessibilityHidden(true)
                .ui2Element("Chevron")
        case .cancel:
            // §2 / deviation 8 (OQ-C-037-001): "tinted `color-text-primary`; a 44pt invisible
            // hit target centred on it delivers `onCancel`". The button's frame is the 44pt
            // target; the negative padding hands the layout back its 18pt slot, so the band's
            // geometry is the symbol's.
            Button(action: onCancel) {
                glyph(.closeOutlineCarbon, tint: Token.textPrimary)
                    .frame(width: Self.hitTarget, height: Self.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding((Self.glyphSize - Self.hitTarget) / 2)
            // R-17: "the close target is a second button labelled 'Remove'".
            .accessibilityLabel("Remove")
            .accessibilityAddTraits(.isButton)
            .ui2Element("Close")
        case .none:
            // §2: "slot absent; the info column extends to the trailing edge".
            EmptyView()
        }
    }

    /// The library glyph's own imageset at §2's 18pt. `Glyph` renders only the token scale
    /// (16 / 24 / 32), so the artwork is drawn directly — same imageset, same template
    /// rendering, the row's tint.
    private func glyph(_ name: GlyphName, tint: Color) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .foregroundStyle(tint)
    }

    /// R-17: the title, then the description or each chip's runs in display order, then the
    /// count — what the row shows, in order.
    private var accessibilityPhrase: String {
        var parts = [title]
        switch detail {
        case .text:
            if let description { parts.append(description) }
            if let count, count > 0 { parts.append(String(count)) }
        case .chips:
            parts.append(contentsOf: chips.map { chip in
                guard let label = chip.label else { return chip.value }
                return chip.align == .right ? "\(label) \(chip.value)" : "\(chip.value) \(label)"
            })
        }
        return parts.joined(separator: ", ")
    }

    // GAP — C-037 §2: "C-038 Avatar at **32**" / "at **64**" — component diameters, no token
    // row (C-038 §3b: size is consumer-applied, not a variant).
    private static func avatarSize(_ subject: Subject) -> CGFloat {
        switch subject {
        case .member: return 32
        case .group: return 64
        }
    }

    // GAP — C-037 §2: glyph "drawn at 18×18"; the glyph size scale has no 18 step.
    private static let glyphSize: CGFloat = 18
    // GAP — C-037 §2 / deviation 8: "a 44pt invisible hit target", no token row.
    private static let hitTarget: CGFloat = 44

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}
