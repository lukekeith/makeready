//
//  PageHeader.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-040-page-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  DEPENDENCY: C-021 GlyphButton, level 1 — its own contract and preview view. It fills the
//  leading slot and each trailing glyph and owns its 44×44 tap area (OQ-C-040-7).
//  DEPENDENCY: C-076 ActivitySpinner, level 1 — replaces the `textButtons` trailing label
//  while `trailingLoading` is true (D66).
//

import SwiftUI

/// C-040 PageHeader — the 56pt bar at the top of a pushed page.
struct PageHeader: View {

    /// §4 `style` — the variant axis (R-06, nested by R-36).
    enum Style {
        case `default`
        case textButtons
        case twoIcons
        case backAndLink
    }

    // GAP — C-040 §2: "The labels' targets are their text box expanded to 44pt tall"; no
    // hit-target token yet. OQ-C-021-4 (owner, 2026-10-20) mints `size-hit-target` = 44 for
    // every C-021 host; this becomes that token's member once a spec run lands the row.
    private static let labelHitHeight: CGFloat = 44

    let style: Style
    /// §4 `title` — centred; single line, tail ellipsis (OQ-C-040-5).
    let title: String?
    /// §4 `showTitle` — Figma default true.
    var showTitle: Bool = true
    /// §4 `showIcons` — gates the trailing glyph slot in `default` AND `twoIcons`
    /// (OQ-C-040-1, deviation 5). Figma default true.
    var showIcons: Bool = true
    /// §4 `leadingGlyph` — any C-021 glyph (OQ-C-040-6). Designed: `back`.
    var leadingGlyph: GlyphButton.Glyph = .back
    /// §4 `rightButtons` — trailing glyphs in order. Required. Designed: `[settings]` for
    /// `default`, `[export, settings]` for `twoIcons`.
    let rightButtons: [GlyphButton.Glyph]
    /// §4 `leadingLabel` — `textButtons` leading label (OQ-C-040-4).
    var leadingLabel: String = "Cancel"
    /// §4 `leadingEnabled` — whether the `textButtons` leading label is tappable. `false`:
    /// `color-white-50` (its tint already), not tappable, not-enabled trait (D66).
    var leadingEnabled: Bool = true
    /// §4 `trailingLabel` — the trailing text action of `textButtons` and `backAndLink`
    /// (OQ-C-040-4, D60): Select / Save / Enroll / Done.
    var trailingLabel: String = "Done"
    /// §4 `trailingEnabled` — whether the trailing text action is tappable. `false` is the
    /// undesigned dimmed look (OQ-C-040-001): `color-white-50`, not tappable, same geometry.
    var trailingEnabled: Bool = true
    /// §4 `trailingLoading` — the `textButtons` saving look: a C-076 ActivitySpinner replaces
    /// the trailing label and the action is not tappable. Wins over `trailingEnabled`;
    /// `backAndLink` ignores it (D66).
    var trailingLoading: Bool = false
    // Interaction-bearing props have no render effect; defaulted no-ops (R-03) so the
    // promoted view keeps its real signature. Shape confirmed by OQ-C-040-8.
    var onLeading: () -> Void = {}
    var onRightButton: (GlyphButton.Glyph) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        // §2: leading at the start, trailing at the end, title centred on the bar's full
        // width — never wider than the room the two slots leave it (OQ-C-040-5).
        PageHeaderLayout(margin: Token.Space.pageMargin) {
            leading.ui2Element("Leading").layoutValue(key: PageHeaderSlot.self, value: .leading)
            trailing.ui2Element("Trailing").layoutValue(key: PageHeaderSlot.self, value: .trailing)
            titleView.layoutValue(key: PageHeaderSlot.self, value: .title)
        }
        .background(Token.transparent)                // §2: no background, no hairline (OQ-C-040-3)
        .ui2Element("PageHeader")
    }

    @ViewBuilder private var leading: some View {
        switch style {
        case .default, .twoIcons, .backAndLink:
            GlyphButton(glyph: leadingGlyph, onTap: onLeading)
        case .textButtons:
            label(leadingLabel, color: Token.white50, action: onCancel)
                .disabled(!leadingEnabled)               // D66: onCancel never fires
                .ui2Element("Leading label")
        }
    }

    @ViewBuilder private var trailing: some View {
        switch style {
        case .default, .twoIcons:
            if showIcons {                               // OQ-C-040-1: gates both glyph styles
                HStack(spacing: Token.Space.rowGap) {    // §2: gap 24
                    ForEach(Array(rightButtons.enumerated()), id: \.offset) { index, glyph in
                        GlyphButton(glyph: glyph) { onRightButton(glyph) }
                            .ui2Element("Trailing glyph \(index + 1)")
                    }
                }
            }
        case .textButtons where trailingLoading:       // D66: spinner replaces the label
            // C-076 at its designed 24pt / color-accent — the label's line box, so the bar stays 56.
            ActivitySpinner()
                .ui2Element("Trailing spinner")
        case .textButtons, .backAndLink:              // D60: the same text action
            label(trailingLabel, color: trailingEnabled ? Token.accent : Token.white50, action: onDone)
                .disabled(!trailingEnabled)              // OQ-C-040-001: onDone never fires
                .ui2Element("Trailing label")
        }
    }

    /// §2: a text-action label (`textButtons`, `backAndLink`) — `type-nav-action`, no underline (not C-049), with its tap
    /// target expanded to 44pt tall without changing the 24pt layout box.
    private func label(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            Text(text)
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                // §2: type-nav-action is 14 / 24 — a one-line Text gets no line box from
                // lineSpacing, so the 24 is the frame (else a glyph-less bar is 49pt, not 56).
                .frame(minHeight: Token.TypeStyle.navAction.lineHeight)
        }
        .buttonStyle(UndimmedLabelStyle())             // the tint is the whole disabled look
        .contentShape(LabelHitShape(height: Self.labelHitHeight))
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var titleView: some View {
        if showTitle, let title {
            Text(title)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)                            // OQ-C-040-5: one line, never wraps
                .truncationMode(.tail)                   // OQ-C-040-5: tail ellipsis
                .accessibilityAddTraits(.isHeader)
                .ui2Element("Title")
        }
    }
}

/// Draws the label exactly as tinted. `.plain` dims a disabled label again on top of its
/// tint, which would put the ruled `color-white-50` look (OQ-C-040-001, D66) at ~25%.
private struct UndimmedLabelStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

/// A tap shape `height` tall, vertically centred on the view's own box and as wide as it.
private struct LabelHitShape: Shape {
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height))
    }
}

/// Which §2 slot a subview of `PageHeaderLayout` fills. Keyed by role, not position: a slot
/// that renders nothing (`showIcons` / `showTitle` false) drops out of the subviews entirely.
private enum PageHeaderSlot: LayoutValueKey {
    enum Role { case leading, trailing, title }
    static let defaultValue: Role = .title
}

/// §2's bar. Height is the margin, the taller slot (24 — the glyph and the label line), and
/// the margin again: 16 + 24 + 16 = 56. The title is centred on the full width and gets the
/// width the slots leave symmetric about the centre, so a long title truncates instead of
/// covering a slot.
private struct PageHeaderLayout: Layout {
    let margin: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let slots = subviews.filter { $0[PageHeaderSlot.self] != .title }.map { $0.sizeThatFits(.unspecified) }
        let content = slots.map(\.height).max() ?? 0
        let width = proposal.width ?? (slots.map(\.width).reduce(0, +) + margin * 2)
        return CGSize(width: width, height: content + margin * 2)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var leadingWidth: CGFloat = 0
        var trailingWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            switch subview[PageHeaderSlot.self] {
            case .leading:
                leadingWidth = size.width
                subview.place(at: CGPoint(x: bounds.minX + margin, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(size))
            case .trailing:
                trailingWidth = size.width
                subview.place(at: CGPoint(x: bounds.maxX - margin, y: bounds.midY), anchor: .trailing, proposal: ProposedViewSize(size))
            case .title:
                break
            }
        }
        let inset = margin + max(leadingWidth, trailingWidth)
        let room = max(0, bounds.width - inset * 2)
        for subview in subviews where subview[PageHeaderSlot.self] == .title {
            subview.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center, proposal: ProposedViewSize(width: room, height: nil))
        }
    }
}
