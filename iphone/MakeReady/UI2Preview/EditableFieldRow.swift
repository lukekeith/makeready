//
//  EditableFieldRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-042-editable-field-row.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  DEPENDENCIES (preview-build.md §4):
//  • C-068 TagChip — no contract file of its own; its anchor is C-042 §5 plus the
//    registry row, which DOES carry a prop-level spec (filled `color-white-20`, r16,
//    px8 py4, label 12/14 `color-white-70`). So it is built for real rather than stubbed,
//    but inline and private: without its own contract and frozen snapshot it is not a
//    legal build target and has no comparison row. `/ui2-component tag-chip
//    https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3526-30837`
//    would promote it to level 1. Only C-068's `Default` style is built — `Solid` is
//    designed-unconsumed and belongs to that component's own run.
//  • chevron-right — §5 names it "asset, part of anatomy", but no chevron-right vector has
//    been exported: the catalog carries only C-021's `back`, which is the SAME artwork
//    mirrored (its Figma group is literally named "Chevron--left"). It is therefore
//    rendered by mirroring `back` rather than by substituting a foreign glyph, and the
//    measurement below shows that reproduces the snapshot exactly. Reported as a gap.
//

import SwiftUI

/// C-042 EditableFieldRow — the tappable field row that opens its `shared-edit-field`
/// instantiation.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no page background and adds no outer padding. Frame, background and outer
/// padding belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct EditableFieldRow: View {

    /// C-042 §4: `indicator: (text: String, tone: positive|negative)?`. A struct rather than
    /// the contract's tuple only because the fixture has to decode it; the field names are
    /// the contract's.
    struct Indicator {
        /// §2: "optional indicator text Regular 12/20 (state color)".
        enum Tone: String {
            case positive
            case negative

            var color: Color {
                switch self {
                case .positive: return Token.positive   // §3 Green indicator: `color-positive`
                case .negative: return Token.negative   // §3 Red indicator: `color-negative`
                }
            }
        }

        let text: String
        let tone: Tone
    }

    /// §4: `label: String` — always present.
    let label: String
    /// §4: `value: String?` — Default / Green / Red / Age / Multiline.
    var value: String?
    /// §4: `tags: [String]?` — the Tags state, where the chip row replaces the value.
    var tags: [String]?
    /// §4: `indicator: (text, tone)?` — Green / Red.
    var indicator: Indicator?
    /// §4: `multiline: Bool` — §3 Multiline: the value is not height-clamped/ellipsized.
    var multiline: Bool = false
    /// §4: `onTap` — opens the field's `shared-edit-field` instantiation (behaviour owned by
    /// screens/shared-edit-field.md). Interaction-bearing, so it has no render effect;
    /// emitted as a defaulted no-op so the promoted view keeps its real signature
    /// (preview-build.md OQ-PB-3's proposed default).
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            // §2: "gap 8" — also the measured distance between the indicator and the
            // chevron, and between the left column and the trailing group.
            HStack(spacing: Token.Space.elementGap) {
                leftColumn.ui2Element("Left column")
                Spacer(minLength: Token.Space.elementGap)
                trailing.ui2Element("Trailing")
            }
            // §2: "py16". No horizontal inset: the row is width-driven and its consumers
            // own the page margin (§1 deviation 2).
            .padding(.vertical, Token.Space.pageMargin)
            // §2: "full-width tappable" — the whole row, not just its ink.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ui2Element("EditableFieldRow")               // capture element map — UI2Element.swift
    }

    // §2: "Left column (flex, gap 8): label ... over the state's content".
    //
    // The row's height is NOT set here, and deliberately so: §2's two stated heights fall
    // out of the designed line boxes exactly, and pinning them would hide it if they ever
    // stopped agreeing.
    //   74 = 16 + 14 (label box) + 8 + 20 (value box) + 16
    //   76 = 16 + 14 (label box) + 8 + 22 (chip height) + 16
    // Multiline then grows past 74 on its own, which is OQ-C-042-2's proposed unbounded wrap.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(label)
                // §2: "label Regular 14 `color-text-secondary` (single line)".
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                // A FIXED box, not a minimum: the designed line box (14, `type-body`'s size
                // — that family measures no leading) is SMALLER than SF Pro's natural ~16.7
                // at this size, so a minHeight would leave the label 2.7pt tall than
                // designed and push both of §2's row heights past their stated numbers.
                .frame(height: Self.lineBox(Token.TypeStyle.body))
                .ui2Element("Label")
            content
        }
    }

    @ViewBuilder private var content: some View {
        if let tags {
            // §2: "Tags row: gap `space-chip-gap` (2) of C-068 TagChips."
            HStack(spacing: Token.Space.chipGap) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    TagChip(label: tag).ui2Element("Tag \(index + 1)")
                }
            }
            .ui2Element("Tags")
        } else if let value {
            Text(value)
                // §2: "Value text (where present): Regular 14/20 white." `type-page-title`
                // is the program's Regular 14/20 row — tokens.md's own hygiene note records
                // that the same face/size/leading carries body copy beyond C-040's title.
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                // §3 Default: "single-line ellipsized value". §3 Multiline: "value not
                // height-clamped/ellipsized (wraps)" — unbounded, per OQ-C-042-2's proposal.
                .lineLimit(multiline ? nil : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                // A MINIMUM here, unlike the label: the designed 20pt line box is LARGER
                // than the natural ~16.7 (so it supplies the half-leading that puts the
                // glyphs where the snapshot has them), and a wrapping Multiline value has
                // to be free to grow past it.
                .frame(
                    maxWidth: .infinity,
                    minHeight: Self.lineBox(Token.TypeStyle.pageTitle),
                    alignment: .leading
                )
                .ui2Element("Value")
        }
    }

    // §2: "Trailing: optional indicator text Regular 12/20 (state color) + chevron-right
    // 18pt (all six states carry the chevron)."
    private var trailing: some View {
        HStack(spacing: Token.Space.elementGap) {
            if let indicator {
                Text(indicator.text)
                    // GAP — C-042 §2: the indicator is Regular 12/20 and
                    // docs/ui2/design-system/tokens.md has no 12/20 row (`type-caption` is
                    // 12/**14**). The value is contract-traceable, only its token NAME is
                    // missing, so it is emitted as C-042 §2's own literal and raised as an
                    // OQ (preview-build.md §3 rule 4, the OQ-PB-5 path).
                    .designTextStyle(DesignTextStyle(weight: .regular, size: 12, lineHeight: 20, tracking: 0))
                    .foregroundStyle(indicator.tone.color)
                    .lineLimit(1)
                    .ui2Element("Indicator")
            }
            chevron.ui2Element("Chevron")
        }
    }

    private var chevron: some View {
        // The mirrored C-021 `back` vector — see the DEPENDENCIES note in the file header.
        // Verified against the frozen snapshot: `back`'s path spans x 7.5…16.05 and
        // y 4.5…19.5 of a 24 viewBox, so at an 18pt box its ink is 6.4 × 11.3 sitting
        // 5.96 from the mirrored box's leading edge — the snapshot's chevron measures
        // 6 × 12 with its box right edge at exactly 376, the master width.
        Image(GlyphButton.Glyph.back.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.chevronSize, height: Self.chevronSize)
            .scaleEffect(x: -1, y: 1)                 // chevron-left → chevron-right
            // GAP — §2 states the chevron's SIZE and nothing about its colour. Measured on
            // the frozen snapshot: its peak ink is neutral (104, 107, 107) over the
            // (3, 4, 5) ground, which resolves to ~50% white — `color-white-50`, not the
            // bluish `color-text-secondary` (133, 151, 158) the label uses. Reported so a
            // `/ui2-component` re-run can state it rather than leave it to a measurement.
            .foregroundStyle(Token.white50)
    }

    /// §2: "chevron-right 18pt".
    private static let chevronSize: CGFloat = 18

    /// The designed line box of a type token: SwiftUI has no line-height, so the box has to
    /// be spelled as a frame. A family that measures no leading (`type-body`) boxes at its
    /// own size, which is what tokens.md's `lineHeight: nil` means.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}

/// C-068 TagChip — the filled chip the Tags state's value row is made of.
///
/// Private to this file on purpose: C-068 has no contract file and no frozen snapshot, so
/// it is not a legal `/ui2-component-build` target and owns no comparison row. See the
/// DEPENDENCIES note in the file header for what would promote it.
private struct TagChip: View {

    /// C-068 §4 (registry row): `label`.
    let label: String

    var body: some View {
        Text(label)
            // Registry row: "label 12/14 `color-white-70`" — `type-caption` is Regular 12/14.
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundStyle(Token.white70)
            .lineLimit(1)
            // The designed 14 line box, fixed for the same reason the row's label is: it is
            // below SF Pro's natural height at 12pt, and it is what makes the chip 22 tall
            // (4 + 14 + 4) and therefore §2's 76pt Tags row.
            .frame(height: Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size)
            // Registry row: "px8 py4".
            .padding(.horizontal, Token.Space.elementGap)
            .padding(.vertical, Token.Space.metaGap)
            // Registry row: "filled `color-white-20`, r16". `radius-modal` is the program's
            // 16 row; on a 22pt-tall chip SwiftUI clamps it to a capsule, which is what the
            // frozen snapshot shows. A `radius-chip` row would name it for what it is —
            // reported as token hygiene, not a build-blocking gap.
            .background(Token.white20, in: RoundedRectangle(cornerRadius: Token.Radius.modal))
    }
}
