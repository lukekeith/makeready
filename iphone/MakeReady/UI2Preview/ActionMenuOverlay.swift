//
//  ActionMenuOverlay.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-066-action-menu-overlay.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  DEPENDENCIES (preview-build.md §4):
//  • C-067 ActionMenuRow — contract ships inside THIS file's §2/§3/§4, and §3 gives it a
//    designed row, so it gets its own view (ActionMenuRow.swift) and is capturable through
//    this component's fixture — the C-019 / C-069 NavTabButton arrangement.
//  • C-048 PageActionButton (`color=White`) — level 2: its anchor is
//    docs/ui2/screens/shared-edit-field.md §4, which D10 accepts as a full contract anchor.
//    Built inline and private below, and ONLY the White variant: C-066 §2 states that one
//    ("36pt, white FILL (not bordered), r8"), while `disabled` / `affirmative` /
//    `destructive` / `Muted` belong to C-048's own run. `/ui2-component page-action-button
//    <figma-url>` would give it a contract file, a frozen snapshot and a preview of its own.
//
//  ARTWORK: the two content glyphs are the vectors the owner supplied 2026-09-10 (see
//  ActionMenuRow.ContentGlyph), carried in Resources/Glyphs.xcassets under a `c066-` prefix
//  because §2's glyph is a CONTENT slot, not a member of C-021's owned set. The flagged
//  stubs the first build reported are closed; the stub path remains for a consumer that
//  names artwork neither set carries.
//
//  NOT BUILT: §3's presentation row — scrim, position and motion are `undesigned`
//  (OQ-C-066-1), so this view is the panel alone, exactly as the frozen snapshot frames it.
//

import SwiftUI

/// C-066 ActionMenuOverlay — the program's action-sheet chrome for contextual actions.
///
/// Chrome-free and width-driven: it fills the width it is given, states its own intrinsic
/// height, and paints only its OWN modal surface — no scrim, no page background, no outer
/// padding. Frame, background and outer padding belong to the ViewRegistry call site
/// (preview-build.md OQ-PB-1 / OQ-PB-2).
struct ActionMenuOverlay: View {

    /// C-066 §4: one entry of `actions: [ActionItem]`. Its two fields are C-067's own §4
    /// props — the container supplies each row's content and nothing else.
    struct ActionItem: Identifiable {
        let glyph: String
        let label: String

        var id: String { "\(glyph)|\(label)" }
    }

    /// §4: `actions: [ActionItem]` — closed per instantiation (§1 deviation 1).
    let actions: [ActionItem]
    /// §4: `onSelect(action)`. Interaction-bearing, so it has no render effect; emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3).
    var onSelect: (ActionItem) -> Void = { _ in }
    /// §4: `onDone` — "Done always dismisses". Interaction-bearing (OQ-PB-3).
    var onDone: () -> Void = {}

    var body: some View {
        // §2: "internal gap 16" — between the actions list and the Done button.
        VStack(spacing: Self.gap) {
            actionsList.ui2Element("Actions list")
            doneButton.ui2Element("Done")
        }
        // §2: "p24". tokens.md's only 24 row is `space-row-gap`, coined for
        // study-program-home's demographics table — it is the program's 24, but it was not
        // named for a container inset. A `space-modal-padding` row would; reported as token
        // hygiene, not a build gap.
        .padding(Token.Space.rowGap)
        // §2: "Container: `color-modal-background` fill, `radius-modal` (16)".
        .background(Token.modalBackground, in: RoundedRectangle(cornerRadius: Token.Radius.modal))
        .ui2Element("ActionMenuOverlay")            // capture element map — UI2Element.swift
    }

    /// §2: "Actions list — N × C-067 ActionMenuRow, each followed by a 1px
    /// `color-layout-border` hairline (including after the last row, per the frame)."
    ///
    /// Spacing 0, and the hairlines are drawn as overlays rather than stack items: the
    /// frozen snapshot's two hairline centres sit exactly 56 apart (y 80 and y 136) with the
    /// container's own arithmetic — 24 + 56 + 56 + 16 + 36 + 24 = 212, its full height — so
    /// a hairline occupies NO height in the layout. As a stack item each would have added a
    /// point and made the panel 214.
    private var actionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                ActionMenuRow(glyph: action.glyph, label: action.label) { onSelect(action) }
                    .overlay(alignment: .bottom) { hairline.ui2Element("Hairline \(index + 1)") }
            }
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(height: Self.hairlineWidth)
            // Centred ON the row boundary, not tucked inside the row above it. Measured:
            // the snapshot's hairlines ink rows 79+80 and 135+136 at EQUAL half-strength
            // (39,43,46 against the 31,33,36 container — two half-covered rows summing to
            // one full `color-layout-border` line), which is a centre-aligned 1px Figma
            // stroke sitting on y=80.0 and y=136.0, the two row edges.
            .offset(y: Self.hairlineWidth / 2)
    }

    /// §2 item 2: "C-048 PageActionButton, `color=White` — 36pt, white FILL (not bordered),
    /// r8, centered label 'Done'".
    private var doneButton: some View {
        PageActionButton(label: "Done", action: onDone)
    }

    /// §2: "1px `color-layout-border` hairline".
    private static let hairlineWidth: CGFloat = 1
    // §2's "internal gap 16". See ActionMenuRow for why `space-card-padding` is the 16 taken.
    private static let gap: CGFloat = Token.Space.cardPadding
}

/// C-048 PageActionButton, `color=White` — the "Done" dismissal.
///
/// Private to this file on purpose: C-048's anchor is `screens/shared-edit-field.md` §4
/// (level 2), which is a legal source to build from but leaves it without a contract file or
/// a frozen snapshot of its own — so it is not a legal `/ui2-component-build` target and
/// owns no comparison row. See the DEPENDENCIES note in the file header.
private struct PageActionButton: View {

    /// shared-edit-field §4 (C-048): `label`. §2 here pins it to "Done".
    let label: String
    /// shared-edit-field §4 (C-048): `action`. Interaction-bearing (OQ-PB-3).
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(label)
                // GAP — C-066 §2: "SF Pro Text Regular 12/20, ls −0.24".
                // docs/ui2/design-system/tokens.md has no 12/20 row at all, tracked or
                // otherwise (`type-caption` is 12/**14** with no tracking), so this cannot
                // resolve to a Token member (preview-build.md §3 rule 4). Emitted as §2's
                // own literal and raised as an OQ — the same path C-045's `py9` took.
                .designTextStyle(DesignTextStyle(weight: .regular, size: 12, lineHeight: 20, tracking: -0.24))
                // §2: label `color-black`.
                .foregroundStyle(Token.black)
                .lineLimit(1)
                // §2: "36pt" — the White variant's height, NOT shared-edit-field §4's 38.
                .frame(maxWidth: .infinity, minHeight: Self.height)
                // §2: "white FILL (not bordered)". tokens.md line 43 records
                // `color-text-primary` (#ffffff) as the binding for `Color/Base/White`, so
                // it is the program's white here rather than a text-only token.
                .background(Token.textPrimary, in: RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(.plain)
        .ui2Element("PageActionButton")
    }

    /// §2: "36pt".
    private static let height: CGFloat = 36
}
