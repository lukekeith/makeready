//
//  InlineDropdown.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-028-inline-dropdown in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  ARTWORK: the 14pt chevron is the vector exported from the normative node `3676:12469`
//  (C-028 §1), carried in Resources/Glyphs.xcassets as `c028-chevron-down`, template-rendered
//  so its fill is a token at the call site — §2: the path "binds `text/secondary` →
//  `color-text-secondary`", i.e. this chevron TINTS, unlike C-035's baked pair.
//

import SwiftUI

/// C-028 InlineDropdown — "the bare header-row control that picks one of a closed option set".
///
/// §2: "A word and a chevron, laid out in a row, centred on each other. No ground, no border,
/// no padding — the control is its own content."
///
/// Chrome-free and content-hugging: the row hugs its label (§3b "Width is not a variant"), and
/// its 24pt height IS the label's line box — the chevron is centred inside it and sets nothing.
/// Frame, background and outer padding belong to the ViewRegistry call site
/// (preview-build.md OQ-PB-1 / OQ-PB-2).
struct InlineDropdown: View {

    /// §4 `options: [String]` — "The closed option set the control chooses from. **Closed per
    /// consumer, not per this row**". Nothing in this view renders it: it is what the presented
    /// chooser (C-036, §5 "Presents — deliberately not nested") draws from, so it is carried
    /// here so the promoted view keeps its real signature.
    let options: [String]
    /// §4 `selected: String` — "Which option is current. It is the whole visible state of the
    /// control: the label renders exactly this string, and nothing else about the component
    /// varies". §1 deviation 1: the snapshot's "All time" is sample content.
    let selected: String
    /// §4 `onSelect: (String) -> Void` — "Called with the chosen option when the presented
    /// chooser commits. **This row does not define what the selection does**". No render
    /// effect, so it is a defaulted no-op here and the promoted view keeps its real signature
    /// (preview-build.md OQ-PB-3).
    var onSelect: (String) -> Void = { _ in }

    var body: some View {
        // §2 Row: "horizontal, `items: center`, gap **4** (`space-meta-gap`); content-hugging
        // both axes." The gap is the TOKEN, deliberately — §2: "this node is a copy of C-022
        // MetaPair's inline set (§1), and `space-meta-gap`'s own note names 'MetaPair
        // value↔label' as the measurement it was minted from. It is the same gap".
        HStack(alignment: .center, spacing: Token.Space.metaGap) {
            labelText
            chevron
        }
        // OQ-C-028-3 ruling (2026-09-16): "Extend the tap area to 44×44 centred on the drawn
        // 61×24 box (visuals unchanged) — the program's 44pt minimum, applied the same way as
        // C-039 and C-049." As in C-039: an expanded tap SHAPE, not a larger frame, so the
        // consumer's placed geometry (§2: trailing inset 16 in C-020's header row) is
        // untouched. Width already exceeds 44, so only the vertical inset grows the target.
        .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.lineBox) / 2))
        // §5: on tap the control PRESENTS C-036 FilterMenuOverlay, which is unspecced,
        // unbuilt, and kept out of this row's anatomy on purpose. The presentation is the
        // consumer's to wire at promotion; the gesture is here so the ruled hit target is a
        // real one. §3c (OQ-C-028-1 ruling): unchanged while open — "the overlay is the
        // feedback" — and standard system press feedback, so no bespoke pressed treatment.
        .onTapGesture {}
        .ui2Element("InlineDropdown")     // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Label: "SF Pro **Regular 12**, leading **24**, variable `text/secondary` →
    // `color-text-secondary` (#85979e), `nowrap`. 43×24 at "All time"".
    private var labelText: some View {
        Text(selected)
            .designTextStyle(Self.labelStyle)
            .foregroundColor(Token.textSecondary)
            // §3c Truncation: "the option set is short by construction (§4) and the control
            // does not truncate — the *title* yields first, which is C-020's business." So
            // `nowrap` and no truncation: the row hugs whatever the label measures.
            .lineLimit(1)
            .fixedSize()
            // §2: "**The height is the label's line box.** 24 = the label's leading". SwiftUI's
            // lineSpacing does nothing to a single line, so the 24pt box is pinned as a frame —
            // the same construction C-027 §2's label and C-022's inline runs use — or the row
            // would close at the font's ~14pt box and the chevron would no longer sit at y=5.
            .frame(height: Self.lineBox)
            .ui2Element("Label")
    }

    // §2 Chevron: "**14×14**, trailing, vector instance `Chevron--down`. Path fill binds
    // `text/secondary` → `color-text-secondary`; its 14×14 backing rect binds `Transparent`
    // … and is an export hit-rect (§1 deviation 4). Vertically centred — y=5 in the 24pt row".
    //
    // The catalogued SVG keeps the source's 14×14 viewBox with the path at its own offset
    // (2.625, 4.6375), so one frame places it exactly where the instance draws it — no
    // artwork-inside-box double frame is needed. The hit-rect is omitted from the asset per
    // deviation 4; nothing here reads it as a background.
    private var chevron: some View {
        Image(Self.chevronAsset, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .frame(width: Self.chevronSize, height: Self.chevronSize)
            .foregroundColor(Token.textSecondary)
            .ui2Element("Chevron")
    }

    // FLAGGED LITERAL — C-028 §2: "**The label's type, Regular 12/24.** No token row carries
    // it — `type-caption` is Regular 12/**14** and `type-input` is Regular **14**/24. This run
    // makes C-028 the **fourth** consumer after C-022 (inline), C-027 and C-030's tick row; not
    // minted off this component, per the same reasoning C-027 applied." OQ-C-027-2.
    private static let labelStyle = DesignTextStyle(
        weight: .regular, size: 12, lineHeight: 24, tracking: 0
    )

    // FLAGGED LITERAL — C-028 §2: "**The chevron's 14.** A size, not a spacing, and the
    // program's fourth chevron size (12 on C-034's magnifier-adjacent decorations, 16 on C-035,
    // 18 on C-042). Carried as this component's own measurement." OQ-C-038-7.
    private static let chevronSize: CGFloat = 14
    /// The asset-catalog name of the vector exported from `3676:12469` (file header).
    private static let chevronAsset = "c028-chevron-down"

    /// §2: the label's 24pt line box, which IS the row's height.
    private static let lineBox: CGFloat = 24
    /// OQ-C-028-3 ruling: the 44pt minimum tap target, centred on the drawn box.
    private static let hitTarget: CGFloat = 44
}
