//
//  EditorNavChrome.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-009-editor-nav-chrome in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-009 EditorNavChrome — the note editor's floating navigation: a Back circle, an Undo
/// circle that exists only while there is something to undo, and an accent-filled Done circle
/// at the trailing edge while editing; outside editing a host may ask for a trailing ⋯ (more)
/// circle instead (D74, memo-detail). No bar, no background, no title; the canvas scrolls
/// under it (01 §3.3).
///
/// Controlled (R-01): it holds no state the design names and performs no navigation or undo
/// itself (R-04) — the host decides what each action means. Chrome-free and width-driven
/// (R-16): it fills the width it is given at the circles' 40pt intrinsic height and paints no
/// background or outer padding — the note-editor places it at its page inset and safe area.
struct EditorNavChrome: View {

    /// §4 `editing` — Done renders only while true; Undo only while `editing && canUndo`
    /// (OQ-C-009-1).
    let editing: Bool
    /// §4 `canUndo` — the host binds it to the editor's `UIUndoManager.canUndo`.
    let canUndo: Bool
    /// §4 `more` — the trailing ⋯ circle renders only while `more && !editing` (D74). The
    /// default leaves note-editor unchanged; memo-detail passes true.
    var more: Bool = false
    /// §4 `onBack` — the host flushes autosave and pops (no Save — DECISIONS R6).
    var onBack: () -> Void = {}
    /// §4 `onUndo` — the host undoes one coalesced step.
    var onUndo: () -> Void = {}
    /// §4 `onDone` — the host dismisses keyboard + strip and leaves edit mode (never commit).
    var onDone: () -> Void = {}
    /// §4 `onMore` — the host presents its menu (memo-detail: C-066 Rename · Delete) (D74).
    var onMore: () -> Void = {}

    /// True only under the capture harness's element map; switches on the glass fallback disc.
    @Environment(\.ui2ElementCollecting) private var captureFallback

    var body: some View {
        // §2: a leading cluster [Back][Undo] and a trailing slot holding [Done] while editing or
        // [More] while `more && !editing` (D74), separated by flexible space; all circles share
        // one vertical centre line (OQ-C-009-3, amended 2026-11-21).
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: Token.Space.elementGap) {
                navCircle(glyph: .chevronLeftCarbon, label: "Back", name: "Back", action: onBack)
                // §2 "Undo collapses when hidden — no reserved slot". The host drives the
                // opacity fade with withAnimation (OQ-C-009-4).
                if editing && canUndo {
                    navCircle(glyph: .undo2, label: "Undo", name: "Undo", action: onUndo)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
            // §2 "The trailing slot holds at most one circle": Done while editing; More only
            // while not editing (D74).
            if editing {
                doneCircle
                    .transition(.opacity)
            } else if more {
                navCircle(glyph: .moreHorizontal, label: "More", name: "More", action: onMore)
                    .transition(.opacity)
            }
        }
        // §2: "the row's intrinsic height is 40" — held in every state so the chrome does not
        // shift when Done leaves.
        .frame(maxWidth: .infinity, minHeight: Geometry.nav, maxHeight: Geometry.nav)
        .ui2Element("EditorNavChrome")             // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    /// §2 Back / Undo / More: a 40×40 circle filled with the iOS 26 Liquid Glass material, a 24pt
    /// `color-text-primary` glyph centred, hit area expanded to 44×44 (OQ-C-009-3). Pressed is
    /// the plain style's system highlight with no geometry change (OQ-C-009-4).
    private func navCircle(
        glyph: GlyphName,
        label: String,
        name: String,
        action: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: action) {
            glyphImage(glyph, color: Token.textPrimary)
                .frame(width: Geometry.nav, height: Geometry.nav)
                // FLAGGED LITERAL — C-009 §2: the circle material is the iOS 26 Liquid Glass
                // system material (OQ-C-009-2), not a token. `radius-circle` is "50%" and emits
                // no member, so the circle is the shape.
                // Capture fallback (owner, 2026-11-20 change card): Liquid Glass over the
                // capture's flat background renders nothing, so beneath `ui2ElementMap` the glass
                // sits on a `color-card-background` disc — C-008's regular compose circle, the
                // nearest look-alike (OQ-C-009-5) — and the circle's shape can be reviewed.
                // The app (no element map) draws the glass alone.
                .background {
                    if captureFallback {
                        Circle().fill(Token.cardBackground)
                    }
                }
                .glassEffect(.regular, in: Circle())
                // §2 / OQ-C-009-3: hit area 44×44 around the 40pt visual, no layout change.
                .contentShape(Circle().inset(by: -Geometry.hitOutset))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)                 // §4 Accessibility (R-17) — fixed copy
        .accessibilityAddTraits(.isButton)
        .ui2Element(name)
    }

    /// §2 Done: a 40×40 `color-accent` circle — the same diameter as Back and Undo (owner change
    /// 2026-11-21) — with a 24pt `color-white-100` checkmark; hit area expanded to 44×44.
    private var doneCircle: some View {
        SwiftUI.Button(action: onDone) {
            glyphImage(.checkmarkCarbon, color: Token.white100)
                .frame(width: Geometry.nav, height: Geometry.nav)
                .background(Circle().fill(Token.accent))
                // §2: hit area 44×44 around the 40pt visual, no layout change.
                .contentShape(Circle().inset(by: -Geometry.hitOutset))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")                // §4 Accessibility (R-17) — fixed copy
        .accessibilityAddTraits(.isButton)
        .ui2Element("Done")
    }

    /// A library glyph at the ruled 24×24 visual size; the glyph carries no label (§4).
    private func glyphImage(_ glyph: GlyphName, color: Color) -> some View {
        Image(glyph.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Geometry.glyph, height: Geometry.glyph)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    /// §2 dimensions of fixed-size controls, not values of a token family.
    private enum Geometry {
        /// FLAGGED LITERAL — C-009 §2: the single 40pt circle diameter shared by Back, Undo, Done
        /// and More (owner change 2026-11-21; D74), no size token.
        static let nav: CGFloat = 40
        /// FLAGGED LITERAL — C-009 §2 / OQ-C-009-3: glyphs 24×24 (C-021's visual size).
        static let glyph: CGFloat = 24
        /// FLAGGED LITERAL — C-009 §2 / OQ-C-009-3: 44pt hit area = 40pt visual + 2pt each side.
        static let hitOutset: CGFloat = 2
    }
}
