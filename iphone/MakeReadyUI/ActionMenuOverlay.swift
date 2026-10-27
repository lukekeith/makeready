//
//  ActionMenuOverlay.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from docs/ui2/design-system/components/C-066-action-menu-overlay.md (§2 geometry,
//  §3 states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  DEPENDENCIES (preview-build.md §4):
//  • C-067 ActionMenuRow — contract ships inside THIS file's §2/§3/§4, and §3 gives it a
//    designed row, so it gets its own view (ActionMenuRow.swift) and is capturable through
//    this component's fixture — the C-019 / C-069 NavTabButton arrangement.
//  • C-048 PageActionButton — **level 1** since 2026-09-15: the row was relocated out of
//    docs/ui2/screens/shared-edit-field.md §4 into a component record of its own, with a
//    contract, a frozen snapshot and (since the /d2m-component-build C-048 run) a preview and
//    a comparison row. So this file composes the REAL PageActionButton.swift at
//    `role: .prominent` — C-048 §3 row 3, which is what C-066 §2's "36pt, white FILL (not
//    bordered), r8" names. The private inline copy this file used to carry was deleted in that
//    run: it existed only because C-048 "owns no comparison row", which stopped being true.
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
    /// action-menu-overlay: the Add menu frame (4717:52460) draws no Done button — the scrim tap
    /// and the swipe down dismiss it instead. Default true keeps the frozen C-066 snapshot.
    // GAP — C-066 §2 item 2: the Done button is not optional in the contract; the owner files the
    // change via /ui2-component-update C-066 (action-menu-overlay B6).
    var showsDone: Bool = true
    /// action-menu-overlay: the Add menu frame draws hairlines BETWEEN rows only; the C-066
    /// snapshot draws one after the last row too. Default true keeps the snapshot.
    // GAP — C-066 §2 item 1: "including after the last row" (action-menu-overlay B6).
    var hairlineAfterLast: Bool = true

    var body: some View {
        // §2: "internal gap 16" — between the actions list and the Done button.
        VStack(spacing: Self.gap) {
            actionsList.ui2Element("Actions list")
            if showsDone {
                doneButton.ui2Element("Done")
            }
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
                    .overlay(alignment: .bottom) {
                        if hairlineAfterLast || index < actions.count - 1 {
                            hairline.ui2Element("Hairline \(index + 1)")
                        }
                    }
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
        PageActionButton(label: "Done", role: .prominent, onTap: onDone)
    }

    /// §2: "1px `color-layout-border` hairline".
    private static let hairlineWidth: CGFloat = 1
    // §2's "internal gap 16". See ActionMenuRow for why `space-card-padding` is the 16 taken.
    private static let gap: CGFloat = Token.Space.cardPadding
}
