//
//  FormatStrip.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-002-format-strip in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  No Figma reference exists or will (OQ-C-002-001): §2's geometry is the notes analysis's
//  written measurements, and the first accepted capture is the reference the owner approves by eye.
//

import SwiftUI

/// The notes feature's shared character style (DECISIONS §4b `InlineStyle`; C-002 §4 Shared
/// types): top-level and unnested (R-38), because C-001 MarkdownTextEditor, C-015 and the codec
/// share it. Declared here, as C-015 declares `ListStyle`, because the preview module imports
/// SwiftUI only and cannot reach the app's `State/Models/NoteEditorModels.swift`.
enum InlineStyle: String, CaseIterable, Hashable {
    case bold
    case italic
    case underline
    case strikethrough
}

/// C-002 FormatStrip — the note editor's horizontally scrollable formatting capsule, docked by
/// C-001 as its `inputAccessoryView`: five C-003 FormatStripButtons, B I U S and the list menu
/// (DECISIONS §4: "That is the entire v1 strip").
///
/// Controlled (R-01): `activeStyles` is C-001's query of the caret's attribute run (02 §2) and the
/// strip never flips it; taps leave through `onToggle` / `onListMenu` (R-03). The scroll position,
/// the row's measured width and the list slot's measured frame are the only internal state (R-02).
/// Hugs its 287 pt row, capped at the width given, with an intrinsic 43 pt height (R-16); centring
/// it and the keyboard docking are C-001's.
struct FormatStrip: View {

    /// C-002 §4 `activeStyles` — which of B/I/U/S draw C-003's active circle. Required.
    let activeStyles: Set<InlineStyle>
    /// C-002 §4 `listMenuPresented` — C-015 ListStyleMenu is open: the row hides in place. Required.
    let listMenuPresented: Bool
    /// C-002 §4 `onToggle` — a B/I/U/S tap with its style; C-001 applies it. No render effect.
    var onToggle: (InlineStyle) -> Void = { _ in }
    /// C-002 §4 `onListMenu` — a list-slot tap with the slot's global frame; the caller presents
    /// C-015 anchored there. No render effect.
    var onListMenu: (CGRect) -> Void = { _ in }

    /// The list slot's frame in global coordinates, handed out by `onListMenu` (§4). Ephemeral
    /// layout state, never a designed state (R-02).
    @State private var listSlotFrame: CGRect = .zero
    /// The button row's measured width (§2: 3 + 5×37 + 4×24 + 3 = 287 pt) — the capsule hugs it.
    /// Ephemeral layout state, never a designed state (R-02).
    @State private var rowWidth: CGFloat = 0

    /// C-002 §2's flagged literals (OQ-C-002-003: kept as literals, one consumer).
    private enum Geometry {
        /// FLAGGED LITERAL — C-002 §2 FL-1: capsule height 43 (01 §3.4 "~43 pt tall"), no token.
        static let height: CGFloat = 43
        /// FLAGGED LITERAL — C-002 §2 FL-2: content inset 3, (43 − 37) / 2, so the end circles
        /// sit concentric with the capsule's rounded ends; no token.
        static let inset: CGFloat = 3
        /// FLAGGED LITERAL — C-002 §2 FL-3: slot gap 24 (from "7 visible at rest"), no token.
        static let gap: CGFloat = 24
    }

    /// C-002 §2 slots 1–4 — fixed anatomy in fixed order (not props): style, glyph, label.
    private static let styleSlots: [(style: InlineStyle, glyph: GlyphName, label: String)] = [
        (.bold, .bold, "Bold"),
        (.italic, .italic, "Italic"),
        (.underline, .underline, "Underline"),
        (.strikethrough, .strikethrough, "Strikethrough"),
    ]

    var body: some View {
        // §2 Scroll container: free momentum, no paging, no snapping, no indicator, no edge fade.
        HorizontalRail(showsIndicators: false) {
            // §2 Button row: leading-aligned, 37 × 37 slots, vertically centred.
            HStack(spacing: Geometry.gap) {
                ForEach(Self.styleSlots, id: \.style) { slot in
                    FormatStripButton(
                        glyph: slot.glyph,
                        active: activeStyles.contains(slot.style),
                        accessibilityLabel: slot.label,
                        onTap: { onToggle(slot.style) }
                    )
                    .ui2Element(slot.label)
                }
                // §2 slot 5: never active (OQ-C-002-005); it only opens C-015.
                FormatStripButton(
                    glyph: .list,
                    active: false,
                    accessibilityLabel: "List style",
                    onTap: { onListMenu(listSlotFrame) }
                )
                .accessibilityHint("Opens list styles")
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { frame in
                    listSlotFrame = frame
                }
                .ui2Element("List menu")
            }
            .padding(.horizontal, Geometry.inset)
            .frame(height: Geometry.height)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                rowWidth = width
            }
            .ui2Element("Button row")
        }
        // §2 Capsule: hugs the row (287 pt), never the screen width; when the width given is
        // smaller, it takes the given width and the row scrolls. Centring is the host's (C-001).
        .frame(maxWidth: rowWidth > 0 ? rowWidth : .infinity, alignment: .leading)
        .frame(height: Geometry.height)
        // §2 Capsule: `radius-circle` is parsed:false (no member), so the fully rounded ends are
        // the Capsule shape itself. Fill `color-modal-background` (OQ-C-002-002); no border, no shadow.
        .background(Token.modalBackground, in: Capsule())
        .clipShape(Capsule())
        // §2 Hidden while the list menu is open: opacity 0 at once, no hit testing, no
        // accessibility element; layout space and scroll position are kept. Back in over
        // `motion-format-strip-reveal`.
        .opacity(listMenuPresented ? 0 : 1)
        .animation(listMenuPresented ? nil : Token.Motion.formatStripReveal, value: listMenuPresented)
        .allowsHitTesting(!listMenuPresented)
        // §2 Accessibility (R-17): one container labelled "Formatting". GAP — C-002 §2 "with the
        // toolbar role": SwiftUI has no toolbar accessibility trait, so the role is not expressed.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Formatting")
        .accessibilityHidden(listMenuPresented)
        .ui2Element("FormatStrip")
    }
}
