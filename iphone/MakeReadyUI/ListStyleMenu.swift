//
//  ListStyleMenu.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-015-list-style-menu in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  No Figma reference exists or will (OQ-C-015-001): §2's geometry is the ruled C-066/C-067
//  metrics, and the first capture is the reference the owner approves by eye.
//

import SwiftUI

/// The notes feature's shared paragraph list style (DECISIONS §4b `ListStyle`, OQ-C-015-007):
/// top-level and unnested, because C-001 MarkdownTextEditor and the codec share it. It is
/// declared here because the preview module imports SwiftUI only and cannot reach the app's
/// `State/Models/NoteEditorModels.swift`; inside this module it shadows SwiftUI's `ListStyle`
/// protocol, which nothing here uses — a file that imports both modules writes
/// `MakeReadyUI.ListStyle`.
enum ListStyle: String, CaseIterable {
    case bulleted
    case numbered
}

/// C-015 ListStyleMenu — the note editor's list-style popover: exactly two rows, Bulleted and
/// Numbered (DECISIONS §4 row 5).
///
/// Holds no designed state (R-01/R-02): no selected style, no open flag. A tap leaves through
/// `onSelect` on the tap itself and the caller applies the style and dismisses (R-03/R-04).
/// Width-driven with an intrinsic 2 × 56 = 112 height (R-16); it paints only its own card —
/// no shadow, no page background, no outer padding.
struct ListStyleMenu: View {

    /// §4 `onSelect` — a row was tapped, with `.bulleted` or `.numbered`. No render effect.
    var onSelect: (ListStyle) -> Void = { _ in }
    /// §4 `onDismiss` — dismissed without a choice (outside tap, VoiceOver escape). Fired by the
    /// §2 presentation modifier; the card itself has no dismiss affordance. No render effect.
    var onDismiss: () -> Void = {}

    /// §2 Rows — fixed anatomy in fixed order (not props): glyph, label, the style it emits.
    private static let rows: [(glyph: GlyphName, label: String, style: ListStyle)] = [
        (.list, "Bulleted", .bulleted),
        (.listOrdered, "Numbered", .numbered),
    ]

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                rowView(glyph: row.glyph, label: row.label, style: row.style)
                    .overlay(alignment: .bottom) {
                        // §2: a 1px `color-layout-border` hairline on row 1's bottom edge, a
                        // 0-height stroke (it adds nothing to the 56), none after the last row.
                        if index < Self.rows.count - 1 {
                            Rectangle()
                                .fill(Token.layoutBorder)
                                .frame(height: 1 / displayScale)
                                .accessibilityHidden(true)
                                .ui2Element("Separator")
                        }
                    }
                    .ui2Element("Row \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity)
        // §2 Card: `color-modal-background` fill, `radius-modal` corners, content clipped.
        .background(Token.modalBackground)
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.modal, style: .continuous))
        .ui2Element("ListStyleMenu")
    }

    private func rowView(glyph: GlyphName, label: String, style: ListStyle) -> some View {
        SwiftUI.Button { onSelect(style) } label: {
            // §2: 24×24 leading glyph, then a `space-card-padding` gap, then the label.
            HStack(spacing: Token.Space.cardPadding) {
                Glyph(glyph, size: .md, tint: Token.textPrimary)
                    .accessibilityHidden(true)
                    .ui2Element("Glyph")
                Text(label)
                    // §2: `type-action-item` (18/24), `color-text-primary`, one line, leading.
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    // The designed 24pt line box, as C-067 draws it, so the row is 16 + 24 + 16.
                    .frame(
                        maxWidth: .infinity,
                        minHeight: Token.TypeStyle.actionItem.lineHeight ?? Token.TypeStyle.actionItem.size,
                        alignment: .leading
                    )
                    .ui2Element("Label")
                // §2: no trailing glyph and no checkmark (01 §3.4, OQ-C-015-005).
            }
            // §2: `space-card-padding` on all four sides — 56 tall.
            .padding(Token.Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2: the whole row is the tap target.
            .contentShape(Rectangle())
        }
        // §3 row pressed (OQ-C-015-006): the system plain-button highlight, ephemeral (R-02).
        .buttonStyle(.plain)
        // R-17: one button per row, labelled by its label; the glyph is decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - §2 Presentation (OQ-C-015-004)

extension ListStyleMenu {
    /// Presents this card as the list-style popover — custom chrome, not a UIKit `UIMenu`
    /// (02 §6). The presenter places the card over the format strip's row (bottom edge on the
    /// strip's bottom edge, the strip's width) and passes `anchor`, the list button's global
    /// frame from C-002's `onListMenu(CGRect)`, as the scale origin.
    ///
    /// No scrim and no dimming: the document and keyboard stay exactly as they are. A tap outside
    /// the card fires `onDismiss` with no selection. While `isPresented` is false (and its close
    /// motion has finished) the card is in neither the layout nor the accessibility tree.
    func listStyleMenuPresentation(
        isPresented: Bool,
        anchor: CGRect,
        onDismiss: @escaping () -> Void
    ) -> some View {
        ListStyleMenuPresentation(menu: self, isPresented: isPresented, anchor: anchor, onDismiss: onDismiss)
    }
}

/// The presented card and its motion. `mounted` and `shown` are animation phase only (R-02):
/// `mounted` keeps the card in place through its close motion, `shown` drives scale + fade.
private struct ListStyleMenuPresentation: View {
    let menu: ListStyleMenu
    let isPresented: Bool
    let anchor: CGRect
    let onDismiss: () -> Void

    @State private var mounted = false
    @State private var shown = false
    @State private var cardFrame: CGRect = .zero

    /// The anchor's centre as a unit point of the card, so scale grows from the list button.
    private var scaleOrigin: UnitPoint {
        guard cardFrame.width > 0, cardFrame.height > 0 else { return .bottom }
        return UnitPoint(
            x: (anchor.midX - cardFrame.minX) / cardFrame.width,
            y: (anchor.midY - cardFrame.minY) / cardFrame.height
        )
    }

    var body: some View {
        Group {
            if mounted {
                menu
                    // §2 Motion: scale + fade from `anchor` (open), back toward it (close).
                    .scaleEffect(shown ? 1 : 0, anchor: scaleOrigin)
                    // Measured OUTSIDE the scale: the card's layout frame, which the scale never
                    // moves. Measured inside it, the frame moved with the anchor it was computed
                    // into — a feedback loop that diverges below half scale and hung the main
                    // thread on open (notes agent walk round 1).
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrame = $0 }
                    .opacity(shown ? 1 : 0)
                    .background { outsideTapCatcher }
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape, onDismiss)
                    .onAppear {
                        withAnimation(Token.Motion.popoverOpen) { shown = true }
                    }
            }
        }
        .onChange(of: isPresented, initial: true) { _, presented in
            if presented {
                if mounted {
                    withAnimation(Token.Motion.popoverOpen) { shown = true }
                } else {
                    mounted = true
                }
            } else if mounted {
                withAnimation(Token.Motion.popoverClose) {
                    shown = false
                } completion: {
                    if !isPresented { mounted = false }
                }
            }
        }
    }

    /// §2 Outside tap: a transparent hit layer over the whole window behind the card — not a
    /// scrim, it paints nothing — that fires `onDismiss` with no selection.
    private var outsideTapCatcher: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .global)
            let screen = Self.windowBounds
            Color.clear
                .contentShape(Rectangle())
                .frame(width: screen.width, height: screen.height)
                .offset(x: screen.minX - frame.minX, y: screen.minY - frame.minY)
                .onTapGesture(perform: onDismiss)
                .accessibilityHidden(true)
        }
    }

    /// The key window's bounds in global coordinates; the hit layer spans it.
    private static var windowBounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first?.screen.bounds ?? .zero
    }
}
