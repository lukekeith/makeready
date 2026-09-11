//
//  ActionMenuRow.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-066-action-menu-overlay.md — C-067
//  ActionMenuRow has its own registry row but ships inside C-066's contract file (§2
//  anatomy, §3 `property1=Default`, §4 props). PREVIEW ONLY: referenced by no screen,
//  route, tab or flag (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell
//  suite (§7).
//
//  C-067 has no contract file and no frozen snapshot of its own, so it is not a legal
//  `/ui2-component-build` target — but §3 gives it a designed row, so it is capturable
//  through C-066's fixture and ViewRegistry case, exactly as C-069 NavTabButton is
//  through C-019's.
//

import SwiftUI

/// C-067 ActionMenuRow — one contextual action inside C-066 ActionMenuOverlay.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, paints no surface and adds no outer padding. Frame, background and outer padding
/// belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2).
struct ActionMenuRow: View {

    /// The artwork C-066 supplies for its own content slot.
    ///
    /// §2 calls the glyph a **content slot** and §1 deviation 1 makes the sample glyphs
    /// per-instantiation content, so they are NOT part of C-021 GlyphButton's owned set of
    /// nine (preview-build.md §3 rule 5 — a set has one owner, and adding to C-021's is a
    /// `/ui2-component` act on C-021, not something a build run may do). They live beside it
    /// in the catalog under a `c066-` prefix, the same way C-034's and C-039's one-off
    /// vectors do. Raw values are the asset names, which are also the fixture's prop values.
    ///
    /// Owner-supplied 2026-09-10, closing the two flagged stubs the first build reported:
    /// `close` is the filled disc with the X knocked out that §1 deviation 2 calls "Misuse",
    /// and `send` is the FILLED paper plane — distinct from C-021's outline `send`
    /// ("Send--alt"), which is why the prefix is doing real work rather than ceremony.
    enum ContentGlyph: String {
        case close = "c066-close"
        case send = "c066-send"
    }

    /// C-066 §4 (C-067): `glyph`. Names artwork rather than selecting from a set this
    /// contract owns. Resolved against C-021's owned nine first — a consumer is free to use
    /// one — then against `ContentGlyph`; a name in neither renders the flagged stub below
    /// rather than a substitute.
    let glyph: String
    /// C-066 §4 (C-067): `label`.
    let label: String
    /// C-066 §4 (C-067): `onTap`. Interaction-bearing, so it has no render effect; emitted
    /// as a defaulted no-op so the promoted view keeps its real signature (OQ-PB-3).
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            // §2: "56pt row (py16), gap 16".
            HStack(spacing: Self.gap) {
                leadingGlyph.ui2Element("Glyph")
                Text(label)
                    // §2: label `type-action-item` (SF Pro Regular 18/24 white).
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    // The designed 24pt line box — larger than SF Pro's natural ~21.5 at
                    // 18pt, so it supplies the half-leading that centres the glyphs where
                    // the snapshot has them. A minimum, so a longer label can never clip.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Token.TypeStyle.actionItem.lineHeight ?? Token.TypeStyle.actionItem.size,
                        alignment: .leading
                    )
                    .ui2Element("Label")
                chevron.ui2Element("Chevron")
            }
            .padding(.vertical, Self.padY)
            // §2: "56pt row" — 16 + 24 + 16. Stated rather than left to the intrinsic
            // height because the glyph slot's stub has no artwork to size it.
            .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ui2Element("ActionMenuRow")               // capture element map — UI2Element.swift
    }

    /// The asset name for `glyph`, or nil when neither set carries it.
    private var glyphAsset: String? {
        GlyphButton.Glyph(rawValue: glyph)?.rawValue ?? ContentGlyph(rawValue: glyph)?.rawValue
    }

    @ViewBuilder private var leadingGlyph: some View {
        if let glyphAsset {
            Image(glyphAsset, bundle: .ui2Preview)
                // The catalog marks both C-066 vectors template-rendering, exactly as
                // C-021's are, so their `fill="white"` is a mask and the tint below is the
                // whole of their colour — which is what keeps §2's "white" a token here
                // rather than baked-in artwork.
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.glyphSize, height: Self.glyphSize)
                // §2: "24pt glyph (content slot, white)".
                .foregroundStyle(Token.textPrimary)
        } else {
            // STUB — C-067 `glyph`, no prop-level contract. The slot is per-instantiation
            // content (§1 deviation 1), so a consumer can name artwork neither set carries.
            // Substituting a near-enough glyph — or an SF Symbol — would hide that, which is
            // what C-040's build history says not to do, so the slot renders obviously
            // unfinished at the designed 24pt instead. No state built here takes this path.
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .strokeBorder(Token.error, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                .frame(width: Self.glyphSize, height: Self.glyphSize)
        }
    }

    private var chevron: some View {
        // §2: "24pt chevron-right glyph". The mirrored C-021 `back` vector — the same
        // artwork (its Figma group is named "Chevron--left"), verified against this
        // snapshot: `back`'s path spans x 7.5…16.05 of a 24 viewBox, so mirrored at a 24pt
        // box its ink runs 7.95…16.5 from the box's leading edge; the snapshot's chevron
        // measures x 392…399 against a box at 384…408, i.e. 8…15.
        Image(GlyphButton.Glyph.back.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .scaleEffect(x: -1, y: 1)              // chevron-left → chevron-right
            // GAP — §2 states the chevron's SIZE and nothing about its colour (only the
            // LEADING glyph is specified white). Measured on the frozen snapshot: its peak
            // ink is (129, 130, 133) over the (31, 33, 36) container, which solves to 50%
            // white at ~0.875 coverage and rules out the bluish `color-text-secondary`
            // (133, 151, 158). The same measurement produced the same answer on C-042.
            // Reported so a `/ui2-component` re-run can state it.
            .foregroundStyle(Token.white50)
    }

    /// §2: "56pt row (py16)" — 16 + 24 + 16.
    static let height: CGFloat = 56
    /// §2: "24pt glyph … 24pt chevron-right glyph".
    static let glyphSize: CGFloat = 24
    // §2's py16 and gap 16. tokens.md coins its two 16 rows as `space-page-margin` and
    // `space-card-padding` and neither was named for a row's internal inset — `card-padding`
    // is taken here because every one of these 16s is INSIDE C-066's modal surface. A
    // `space-gap` row would name it properly; reported as token hygiene, not a build gap.
    private static let padY: CGFloat = Token.Space.cardPadding
    private static let gap: CGFloat = Token.Space.cardPadding
}
