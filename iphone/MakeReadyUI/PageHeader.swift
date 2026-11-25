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
//  DEPENDENCY: C-159 DoneCheck, level 1 — the `showsDone` check.
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
    // LITERAL — C-040 §2 (owner, 2026-11-21): every C-021 glyph in this bar draws at 32×32, one
    // 8pt step above `size-glyph` (24); no token holds it yet. C-021 lays out at its own 24pt
    // visual, so the bar scales the part (not a re-draw) and lays it out in a 32pt box.
    private static let glyphSize: CGFloat = 32
    private static let glyphNativeSize: CGFloat = 24

    let style: Style
    /// §4 `title` — centred; single line, tail ellipsis (OQ-C-040-5).
    let title: String?
    /// §4 `showTitle` — Figma default true.
    var showTitle: Bool = true
    /// §4 `showIcons` — gates the trailing glyph slot in `default` AND `twoIcons`
    /// (OQ-C-040-1, deviation 5). Figma default true.
    var showIcons: Bool = true
    /// §4 `showsDone` (owner, 2026-11-21) — the 32pt `color-accent` check circle at the trailing
    /// edge, animated in and out (§2). Label "Done". Pushes the other trailing controls left.
    var showsDone: Bool = false
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
    /// §4 `toolbarTone` (activities-editor §27, D38) — the paint for a header over a LIGHT page.
    /// `.light` (default) is every state unchanged. `.dark`: the title and the `textButtons`
    /// labels `color-black`, a dimmed action `color-black` at 30%, the C-021 glyphs and the C-076
    /// spinner `color-black`; `backAndLink`'s accent action is unchanged.
    var toolbarTone: ToolbarTone = .light
    // Interaction-bearing props have no render effect; defaulted no-ops (R-03) so the
    // promoted view keeps its real signature. Shape confirmed by OQ-C-040-8.
    var onLeading: () -> Void = {}
    var onRightButton: (GlyphButton.Glyph) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        // §2: leading at the start, trailing at the end, title centred on the bar's full
        // width — never wider than the room the two slots leave it (OQ-C-040-5).
        // §2: padding 12 vertical (owner, 2026-11-21), `space-page-margin` horizontal.
        PageHeaderLayout(margin: Token.Space.pageMargin, verticalMargin: Token.Space.step12,
                         contentHeight: Self.glyphSize) {
            leading.ui2Element("Leading").layoutValue(key: PageHeaderSlot.self, value: .leading)
            trailing.ui2Element("Trailing").layoutValue(key: PageHeaderSlot.self, value: .trailing)
            titleView.layoutValue(key: PageHeaderSlot.self, value: .title)
        }
        // §2: the done check enters / exits and the trailing controls slide, on the house spring.
        .animation(Token.Motion.sheetSnap, value: showsDone)
        .background(Token.transparent)                // §2: no background, no hairline (OQ-C-040-3)
        .ui2Element("PageHeader")
    }

    private var isDark: Bool { toolbarTone == .dark }

    /// §4 toolbarTone `.dark`: C-021 paints a fixed `color-accent`; multiplied by `color-black`
    /// it draws black (C-021 takes no tone input). `.light` multiplies by white — no change.
    private var glyphInk: Color { isDark ? Token.black : Token.white100 }

    /// The dimmed look of a text action: `color-white-50`, or `color-black` at 30% in `.dark`.
    private var dimmedInk: Color { isDark ? Token.black30 : Token.white50 }

    @ViewBuilder private var leading: some View {
        switch style {
        case .default, .twoIcons, .backAndLink:
            glyphButton(leadingGlyph, action: onLeading)
        case .textButtons:
            // `.dark`: the leading label is `color-black`, `color-black` at 30% when not enabled.
            label(leadingLabel, color: isDark ? (leadingEnabled ? Token.black : dimmedInk) : Token.white50,
                  action: onCancel)
                .disabled(!leadingEnabled)               // D66: onCancel never fires
                .ui2Element("Leading label")
        }
    }

    /// §2: the trailing slot — the style's control, with the done check (§4 `showsDone`) at the
    /// trailing edge pushing it left by the check's width plus the slot gap (24).
    private var trailing: some View {
        HStack(spacing: Token.Space.rowGap) {
            styleTrailing
            if showsDone {
                doneCheck
                    .transition(.scale(scale: 0.5).combined(with: .opacity))   // §2: enter / exit
            }
        }
    }

    /// §2 Done check (owner, 2026-11-21): C-159 — a 32×32 `color-accent` circle with a white
    /// checkmark; tapping it fires `onDone`; 44pt tap target.
    private var doneCheck: some View {
        DoneCheck(onTap: onDone)
            .ui2Element("Done check")
    }

    /// A C-021 glyph at the bar's 32pt size (§2, owner 2026-11-21), with the `toolbarTone` ink.
    private func glyphButton(_ glyph: GlyphButton.Glyph, action: @escaping () -> Void) -> some View {
        GlyphButton(glyph: glyph, onTap: action)
            .colorMultiply(glyphInk)
            .scaleEffect(Self.glyphSize / Self.glyphNativeSize)
            .frame(width: Self.glyphSize, height: Self.glyphSize)
    }

    @ViewBuilder private var styleTrailing: some View {
        switch style {
        case .default, .twoIcons:
            if showIcons {                               // OQ-C-040-1: gates both glyph styles
                HStack(spacing: Token.Space.rowGap) {    // §2: gap 24
                    ForEach(Array(rightButtons.enumerated()), id: \.offset) { index, glyph in
                        glyphButton(glyph) { onRightButton(glyph) }
                            .ui2Element("Trailing glyph \(index + 1)")
                    }
                }
            }
        case .textButtons where trailingLoading:       // D66: spinner replaces the label
            // C-076 at its designed 24pt / color-accent — the label's line box, so the bar stays 56.
            ActivitySpinner(color: isDark ? Token.black : Token.accent)
                .ui2Element("Trailing spinner")
        case .textButtons, .backAndLink:              // D60: the same text action
            // `.dark`: the `textButtons` trailing label is `color-black`; `backAndLink`'s accent
            // action is unchanged; dimmed is `color-black` at 30%.
            label(trailingLabel, color: trailingInk, action: onDone)
                .disabled(!trailingEnabled)              // OQ-C-040-001: onDone never fires
                .ui2Element("Trailing label")
        }
    }

    private var trailingInk: Color {
        guard trailingEnabled else { return dimmedInk }
        return isDark && style == .textButtons ? Token.black : Token.accent
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
                .foregroundStyle(isDark ? Token.black : Token.textPrimary)   // §4 toolbarTone
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

/// §2's bar. Height is the vertical margin, the taller slot (32 — the glyph and the done check),
/// and the vertical margin again: 12 + 32 + 12 = 56. The title is centred on the full width and gets the
/// width the slots leave symmetric about the centre, so a long title truncates instead of
/// covering a slot.
private struct PageHeaderLayout: Layout {
    let margin: CGFloat
    let verticalMargin: CGFloat
    /// §2: the bar stays 56 for every style — a label-only bar still sizes to the 32pt glyph row.
    let contentHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let slots = subviews.filter { $0[PageHeaderSlot.self] != .title }.map { $0.sizeThatFits(.unspecified) }
        let content = max(contentHeight, slots.map(\.height).max() ?? 0)
        let width = proposal.width ?? (slots.map(\.width).reduce(0, +) + margin * 2)
        return CGSize(width: width, height: content + verticalMargin * 2)
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
