//
//  FilterMenuOverlay.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-036-filtermenuoverlay in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  DEPENDENCIES (§5 Consumes):
//  • the close button is C-082 ModalCloseButton, the linked registry row (deviation 7).
//  • each option is FilterMenuOptionRow (OQ-C-036-1), ruled but not yet a registry row, so
//    it is a private sub-view drawn from C-036 §2's row anatomy — the disclosed fallback of
//    R-15 that §5 names. It moves out when that row is minted, specced and built.
//
//  SELECTION API: §4 `selectionMode` + `selectedIDs` (OQ-C-036-9). OQ-C-036-10: in
//  `.multiple` choices apply live and the ✕ simply dismisses.
//

import SwiftUI

/// C-036 FilterMenuOverlay — a full-screen single- or multi-select option menu.
///
/// Fills the frame it is given (R-16; `.filterMenuPresentation` gives it the full screen) and
/// paints no dim of its own (OQ-C-036-4). Two layers in z: the scrolling option list under
/// its bottom fade mask, then the close button — the topmost layer (note 2026-09-29).
struct FilterMenuOverlay: View {

    /// §4 `Option` (nested, R-36): `glyph` is a glyph-library name; nil = no glyph box
    /// (OQ-C-036-2).
    struct Option: Identifiable {
        let id: String
        let label: String
        var glyph: String?
    }

    /// OQ-C-036-009: `.single` — one tap picks and the presenter closes; `.multiple` — a tap
    /// toggles and the menu stays open.
    enum SelectionMode {
        case single
        case multiple
    }

    /// §4 `options`: the closed option list, in display order.
    let options: [Option]
    /// OQ-C-036-009 `selectionMode`.
    let selectionMode: SelectionMode
    /// OQ-C-036-009 `selectedIDs`: every checked option; empty = a plain option menu with no
    /// checkmark. Controlled (R-01) — the view never holds the selection.
    let selectedIDs: Set<String>
    /// §4 `onSelect`: fires on every option tap, the already-selected one included (R-03).
    var onSelect: (Option) -> Void = { _ in }
    /// §4 `onClose`: the close button (C-082) was tapped; the presenter dismisses. In
    /// `.multiple` the live choices stand (OQ-C-036-10).
    var onClose: () -> Void = {}

    private enum Geometry {
        /// FLAGGED LITERAL — C-036 §2: "⚑ 174pt (flagged literal: Figma gradient stop
        /// 0.7865→1 of 815.5; no token)" — the fade band ending at the close button's top.
        static let fadeBand: CGFloat = 174
        /// GAP — C-036 §2 / C-082 §2: "Close button | 44×44"; no sizing token.
        static let closeDisc: CGFloat = 44
    }

    var body: some View {
        GeometryReader { proxy in
            // OQ-C-036-6: the close button's bottom edge sits max(bottom safe-area inset,
            // `space-section-gap`) above the screen bottom.
            let closeBottom = max(proxy.safeAreaInsets.bottom, Token.Space.sectionGap)
            // The close button's top edge, measured up from the screen bottom.
            let closeTopOffset = closeBottom + Geometry.closeDisc

            ZStack(alignment: .bottom) {
                optionList(bottomInset: closeTopOffset)
                    .mask { fadeMask(closeTopOffset: closeTopOffset) }
                    .ui2Element("Option list")

                // Topmost layer: always hit-testable, fixed while the list scrolls.
                ModalCloseButton(onClose: onClose)
                    .padding(.bottom, closeBottom)
                    .ui2Element("Close button")
            }
            .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .ui2Element("FilterMenuOverlay")
    }

    /// §2 Option list: horizontal inset `space-section-gap`, rows stacked with no gap and no
    /// separators, content from the top safe-area inset, and a bottom content inset equal to
    /// the close button's top offset so the last row scrolls clear (OQ-C-036-6).
    private func optionList(bottomInset: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    OptionRow(
                        glyph: option.glyph,
                        label: option.label,
                        selected: selectedIDs.contains(option.id),
                        onTap: { onSelect(option) }
                    )
                    .ui2Element("Option row \(index + 1)")
                }
            }
            .padding(.horizontal, Token.Space.sectionGap)
            .padding(.bottom, bottomInset)
        }
    }

    /// §2 Bottom fade: an alpha mask fixed to the viewport (deviation 5) — opaque above,
    /// linear to clear over the 174pt band ending at the close button's top edge, clear
    /// below it. Only the mask's alpha is read, so its colours carry no design value.
    private func fadeMask(closeTopOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Geometry.fadeBand)
            Color.clear
                .frame(height: closeTopOffset)
        }
    }
}

// MARK: - FilterMenuOptionRow (inline until minted — OQ-C-036-1)

private extension FilterMenuOverlay {

    /// OQ-C-036-1's FilterMenuOptionRow, drawn from C-036 §2 "Option row ×N": 56pt tall
    /// (`space-card-padding` 16 + 24 + 16), item gap `space-card-padding`, optional 24pt
    /// leading glyph, `type-action-item` label (one line, tail-truncated, OQ-C-036-7), and a
    /// trailing 24pt `checkmark-carbon` on a selected row.
    struct OptionRow: View {
        let glyph: String?
        let label: String
        let selected: Bool
        var onTap: () -> Void = {}

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: Token.Space.cardPadding) {
                    if let glyph {
                        leadingGlyph(glyph).ui2Element("Glyph")
                    }
                    Text(label)
                        .designTextStyle(Token.TypeStyle.actionItem)
                        .foregroundStyle(tint)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        // The designed 24pt line box — taller than SF Pro's natural line at 18pt.
                        .frame(
                            maxWidth: .infinity,
                            minHeight: Token.TypeStyle.actionItem.lineHeight ?? Token.TypeStyle.actionItem.size,
                            alignment: .leading
                        )
                        .ui2Element("Label")
                    if selected {
                        // §2: checkmark `color-accent`.
                        Glyph(.checkmarkCarbon, size: .md, tint: Token.accent)
                            .accessibilityHidden(true)
                            .ui2Element("Checkmark")
                    }
                }
                .padding(.vertical, Token.Space.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            // OQ-C-036-8: the system highlight of a plain button style (ephemeral, R-02).
            .buttonStyle(.plain)
            // R-17: one button labelled by `label`; a selected row also carries `.isSelected`,
            // so selection is never signalled by colour alone. Glyphs are decorative.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }

        /// §2: unselected glyph + label `color-text-secondary`; selected `color-text-primary`.
        private var tint: Color {
            selected ? Token.textPrimary : Token.textSecondary
        }

        @ViewBuilder private func leadingGlyph(_ glyph: String) -> some View {
            if let name = GlyphName(rawValue: glyph) {
                Glyph(name, size: .md, tint: tint)
                    .accessibilityHidden(true)
            } else {
                // STUB — a glyph name the library cannot draw (§4: `glyph` is a glyph-library
                // name). Drawn obviously unfinished at the designed 24pt rather than
                // substituting a near-enough glyph; a capture showing one is a failed build.
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(Token.error, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .frame(width: GlyphSize.md.points, height: GlyphSize.md.points)
            }
        }
    }
}

// MARK: - Presentation (§4 modifier, OQ-C-036-4)

extension View {
    /// C-036 §4 `.filterMenuPresentation(isPresented:onDismiss:)`: the full-screen
    /// `color-black-80` dim (OQ-C-036-3) under the view, crossfaded together with
    /// `motion-menu-fade-in/out`. The dim is not a tap target; the escape action fires
    /// `onDismiss`.
    func filterMenuPresentation(isPresented: Bool, onDismiss: @escaping () -> Void = {}) -> some View {
        modifier(FilterMenuPresentation(isPresented: isPresented, onDismiss: onDismiss))
    }
}

private struct FilterMenuPresentation: ViewModifier {
    let isPresented: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            if isPresented {
                ZStack {
                    // Full screen, ignoring safe areas; not an accessibility element, no gesture.
                    Token.black80
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .ui2Element("Dim")
                    content
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape, onDismiss)
                }
                // Opacity only — no slide, no scale (§2 Motion).
                .transition(.opacity)
            }
        }
        .animation(isPresented ? Token.Motion.menuFadeIn : Token.Motion.menuFadeOut, value: isPresented)
    }
}
