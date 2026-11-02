//
//  FilterMenuOverlay.swift
//  MakeReadyUI — the UI 2.0 module
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
//  SELECTION API: §4 `selectionMode` + `selectedIDs` (OQ-C-036-9). OQ-C-036-10 as amended by
//  filter-multiselect D1 (owner 2026-10-26): with onSave set, picks are a draft — Save applies,
//  ✕ discards (routed to /d2m:component:update C-036, F2/F4).
//
//  TAG-FLOW FORM (§7, owner 2026-11-01, Figma 4770:11375): `sections` set → the options draw as
//  wrapping tag chips under optional uppercase section headers. The tag chip and the flow layout
//  are private sub-views (R-15 disclosed fallback) until a registry row is minted for the chip.
//  Every list-form caller is unchanged: `sections` is nil unless the tag-flow init is used.
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

    /// §7 `Section` (nested, R-36): an optional header over a flow of options. nil `title` =
    /// no header. Options in the tag-flow form carry no glyph.
    struct Section {
        let title: String?
        let options: [Option]
    }

    /// OQ-C-036-009: `.single` — one tap picks and the presenter closes; `.multiple` — a tap
    /// toggles and the menu stays open.
    enum SelectionMode {
        case single
        case multiple
    }

    /// §4 `options`: the closed option list, in display order.
    let options: [Option]
    /// §7 `sections`: set → the tag-flow form (sections of wrapping tag chips) in place of the
    /// option list; nil → the list form, exactly as before.
    let sections: [Section]?
    /// OQ-C-036-009 `selectionMode`.
    let selectionMode: SelectionMode
    /// OQ-C-036-009 `selectedIDs`: every checked option; empty = a plain option menu with no
    /// checkmark. Controlled (R-01) except in draft mode (onSave set), where it only seeds the draft.
    let selectedIDs: Set<String>
    /// §4 `onSelect`: fires on every option tap, the already-selected one included (R-03).
    var onSelect: (Option) -> Void
    /// §4 `onClose`: the close button (C-082) was tapped; the presenter dismisses. When
    /// `onSave` is set, close discards the draft (D1); only Save commits it.
    var onClose: () -> Void
    /// filter-menu-clear (owner 2026-10-26): every filter menu carries a C-049 "Clear" link top
    /// left, above the list. The presenter resets its filter to rest (and, in `.single`, closes,
    /// as an option tap does). nil hides the link — a plain option menu with no filter.
    var onClear: (() -> Void)?
    /// False while the filter is already at rest — the link draws at C-049's 50% and ignores taps.
    var clearEnabled: Bool

    /// filter-multiselect D1/D10, §8 (owner 2026-11-01): set → draft mode. A draft is seeded from
    /// `selectedIDs` when the menu opens; `.multiple` taps toggle it, `.single` taps replace it with
    /// that option (radio-like); every tap keeps the menu open. The top row's Clear empties the
    /// draft and the menu stays open; Save hands the draft back here (the presenter applies it and
    /// closes); ✕ discards it. `onSelect` still fires per tap. `onClear` / `clearEnabled` are
    /// ignored in this mode (D10).
    var onSave: ((Set<String>) -> Void)?

    /// D1: the picks being edited — seeded once per presentation (each opening builds a new view).
    @SwiftUI.State private var draft: Set<String>

    private static let clearLabel = "Clear"
    private static let saveLabel = "Save"

    init(
        options: [Option],
        selectionMode: SelectionMode,
        selectedIDs: Set<String>,
        onSelect: @escaping (Option) -> Void = { _ in },
        onClose: @escaping () -> Void = {},
        onClear: (() -> Void)? = nil,
        clearEnabled: Bool = true,
        onSave: ((Set<String>) -> Void)? = nil
    ) {
        self.options = options
        self.sections = nil
        self.selectionMode = selectionMode
        self.selectedIDs = selectedIDs
        self.onSelect = onSelect
        self.onClose = onClose
        self.onClear = onClear
        self.clearEnabled = clearEnabled
        self.onSave = onSave
        // Seeded here, not in onAppear, so the first frame already shows the current checks.
        _draft = SwiftUI.State(initialValue: selectedIDs)
    }

    /// §7 the tag-flow form: `sections` in display order, `selectedIDs` seeding the draft. Always
    /// draft mode (§8) — a chip tap toggles its id, Save hands the draft back, Clear empties the
    /// draft and the menu stays open, ✕ (`onClose`) discards.
    init(
        sections: [Section],
        selectedIDs: Set<String>,
        onSelect: @escaping (Option) -> Void = { _ in },
        onClose: @escaping () -> Void = {},
        onSave: ((Set<String>) -> Void)? = nil
    ) {
        self.options = []
        self.sections = sections
        self.selectionMode = .multiple
        self.selectedIDs = selectedIDs
        self.onSelect = onSelect
        self.onClose = onClose
        self.onClear = nil
        self.clearEnabled = true
        self.onSave = onSave
        _draft = SwiftUI.State(initialValue: selectedIDs)
    }

    /// D1: a tap toggles the option's id in the draft.
    static func toggled(_ draft: Set<String>, _ id: String) -> Set<String> {
        var next = draft
        if next.remove(id) == nil { next.insert(id) }
        return next
    }

    /// §8 mode table: the draft after a tap on `id` — `.single` replaces it with just that option
    /// (tapping the selected one keeps it selected), `.multiple` toggles it.
    static func drafted(_ draft: Set<String>, _ id: String, mode: SelectionMode) -> Set<String> {
        switch mode {
        case .single: return [id]
        case .multiple: return toggled(draft, id)
        }
    }

    /// D4: a chip's text for the picked labels — none → `resting`, one → that label,
    /// n ≥ 2 → "n <noun>" (`noun` plural).
    static func chipLabel(picked labels: [String], resting: String, noun: String) -> String {
        switch labels.count {
        case 0: return resting
        case 1: return labels[0]
        default: return "\(labels.count) \(noun)"
        }
    }

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
                VStack(alignment: .leading, spacing: 0) {
                    if let onSave {
                        // filter-multiselect D1/D8: Clear leading, Save trailing, one fixed row above
                        // the list. §8 (owner 2026-11-01): Clear empties the draft and the menu
                        // stays open; enabled while the draft is non-empty. Save always is.
                        HStack(spacing: Token.Space.cardPadding) {
                            // §8 rule 3 / OQ-C-036-12: Clear draws `color-filter-clear` (C-049
                            // `filterClear`); disabled is C-049's 50% of it.
                            LinkButton(label: Self.clearLabel, style: .filterClear, onTap: { draft = [] },
                                       isEnabled: !draft.isEmpty, underlined: false)
                                .ui2Element("C-049 LinkButton")
                            Spacer(minLength: 0)
                            LinkButton(label: Self.saveLabel, onTap: { onSave(draft) }, underlined: false)
                                .ui2Element("C-049 LinkButton 2")
                        }
                        .padding(.horizontal, Token.Space.sectionGap)
                        .padding(.vertical, Token.Space.cardPadding)
                    } else if let onClear {
                        // filter-menu-clear: fixed above the list (it never scrolls away), on the
                        // option rows' leading inset.
                        LinkButton(label: Self.clearLabel, style: .muted, onTap: onClear,
                                   isEnabled: clearEnabled, underlined: false)
                            .padding(.horizontal, Token.Space.sectionGap)
                            .padding(.vertical, Token.Space.cardPadding)
                            .ui2Element("C-049 LinkButton")
                    }
                    Group {
                        if let sections {
                            tagFlow(sections, bottomInset: closeTopOffset)
                        } else {
                            optionList(bottomInset: closeTopOffset)
                        }
                    }
                        .mask { fadeMask(closeTopOffset: closeTopOffset) }
                        .ui2Element("Option list")
                }

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
                        selected: onSave != nil ? draft.contains(option.id) : selectedIDs.contains(option.id),
                        onTap: {
                            if onSave != nil {
                                draft = Self.drafted(draft, option.id, mode: selectionMode)
                            }
                            onSelect(option)
                        }
                    )
                    .ui2Element("Option row \(index + 1)")
                }
            }
            .padding(.horizontal, Token.Space.sectionGap)
            .padding(.bottom, bottomInset)
        }
    }

    /// §7 Tag flow: sections stacked `space-stack-gap` apart (Figma `Filters` gap 16), each an
    /// optional `type-section-overline` header in `color-text-secondary` over a left-aligned flow
    /// of tag chips `space-meta-gap` apart on both axes (Figma `Actions` gap 4), on the list's
    /// `space-section-gap` inset, with the same bottom content inset as the option list.
    private func tagFlow(_ sections: [Section], bottomInset: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Token.Space.stackGap) {
                ForEach(Array(sections.enumerated()), id: \.offset) { sectionIndex, section in
                    if let title = section.title {
                        Text(title)
                            .designTextStyle(Token.TypeStyle.sectionOverline)
                            .textCase(.uppercase)
                            .foregroundStyle(Token.textSecondary)
                            .lineLimit(1)
                            // The designed 24pt line box (Figma 4770:11346).
                            .frame(minHeight: Token.TypeStyle.sectionOverline.lineHeight
                                   ?? Token.TypeStyle.sectionOverline.size)
                            .accessibilityAddTraits(.isHeader)
                            .ui2Element("Section header \(sectionIndex + 1)")
                    }
                    TagFlowLayout(spacing: Token.Space.metaGap) {
                        ForEach(section.options) { option in
                            TagChip(
                                label: option.label,
                                selected: onSave != nil ? draft.contains(option.id) : selectedIDs.contains(option.id),
                                onTap: {
                                    if onSave != nil { draft = Self.toggled(draft, option.id) }
                                    onSelect(option)
                                }
                            )
                            .ui2Element("Tag chip \(option.id)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ui2Element("Tag flow \(sectionIndex + 1)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            SwiftUI.Button(action: onTap) {
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

// MARK: - Tag chip + flow layout (inline until minted — §7)

private extension FilterMenuOverlay {

    /// §7's two-state tag chip (Figma 4770:11316 `Tag clickable`): `type-block-label` (14/16)
    /// on `space-button-padding` (8) all round, one line. Unselected: plain text, no fill,
    /// `color-text-secondary` (§7). Selected: `color-layout-background` text on a white pill
    /// (32pt tall, radius 16 = a capsule).
    struct TagChip: View {
        let label: String
        let selected: Bool
        var onTap: () -> Void = {}

        var body: some View {
            SwiftUI.Button(action: onTap) {
                Text(label)
                    .designTextStyle(Token.TypeStyle.blockLabel)
                    .foregroundStyle(selected ? Token.layoutBackground : Token.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minHeight: Token.TypeStyle.blockLabel.lineHeight ?? Token.TypeStyle.blockLabel.size)
                    .padding(Token.Space.buttonPadding)
                    .background {
                        if selected {
                            Capsule().fill(Token.white100)
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // R-17: one button labelled by its label; selected carries `.isSelected`.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        }
    }

    /// §7 "the build supplies a flow layout inside the module": a leading-aligned wrapping flow
    /// with one gap on both axes. A chip wider than the line is offered the line's width, so it
    /// truncates rather than overflowing.
    struct TagFlowLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let lines = lines(for: proposal.width ?? .infinity, subviews: subviews)
            let height = lines.map(\.height).reduce(0, +) + spacing * CGFloat(max(lines.count - 1, 0))
            let widest = lines.map(\.width).max() ?? 0
            return CGSize(width: proposal.width ?? widest, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var y = bounds.minY
            for line in lines(for: bounds.width, subviews: subviews) {
                var x = bounds.minX
                for item in line.items {
                    subviews[item.index].place(at: CGPoint(x: x, y: y),
                                               anchor: .topLeading,
                                               proposal: ProposedViewSize(item.size))
                    x += item.size.width + spacing
                }
                y += line.height + spacing
            }
        }

        private struct Line {
            var items: [(index: Int, size: CGSize)] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
        }

        private func lines(for maxWidth: CGFloat, subviews: Subviews) -> [Line] {
            var lines: [Line] = []
            var current = Line()
            for index in subviews.indices {
                let ideal = subviews[index].sizeThatFits(.unspecified)
                let size = CGSize(width: min(ideal.width, maxWidth), height: ideal.height)
                if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                    lines.append(current)
                    current = Line()
                }
                current.width = current.items.isEmpty ? size.width : current.width + spacing + size.width
                current.height = max(current.height, size.height)
                current.items.append((index, size))
            }
            if !current.items.isEmpty { lines.append(current) }
            return lines
        }
    }
}

// MARK: - Presentation (§4 modifier, OQ-C-036-4)

extension View {
    /// C-036 §4 `.filterMenuPresentation(isPresented:onDismiss:)`: the full-screen blurred
    /// backdrop (system material under `color-black-60`; was the `color-black-80` dim,
    /// OQ-C-036-3) under the view, crossfaded together with
    /// `motion-menu-fade-in/out`. The dim is not a tap target; the escape action fires
    /// `onDismiss`. Always draws in place (previews, capture).
    func filterMenuPresentation(isPresented: Bool, onDismiss: @escaping () -> Void = {}) -> some View {
        modifier(FilterMenuPresentation(isPresented: isPresented, onDismiss: onDismiss))
    }

    /// filter-menu-fullscreen (routed to /ui2-resolve): the screen-level form — applied to the
    /// SCREEN with the menu as a view. Under a `.ui2OverlayHost()` the presented menu is handed
    /// up and drawn above every piece of the shell's chrome; elsewhere it overlays the screen
    /// exactly as `.overlay { menu.filterMenuPresentation(…) }` did.
    func filterMenuPresentation<Menu: View>(
        isPresented: Bool,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder menu: () -> Menu
    ) -> some View {
        modifier(HostableFilterMenuPresentation(isPresented: isPresented, onDismiss: onDismiss, menu: menu()))
    }
}

private struct FilterMenuPresentation: ViewModifier {
    let isPresented: Bool
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        ZStack {
            if isPresented {
                FilterMenuLayer(onDismiss: onDismiss) { content }
                    // Opacity only — no slide, no scale (§2 Motion).
                    .transition(.opacity)
            }
        }
        .animation(isPresented ? Token.Motion.menuFadeIn : Token.Motion.menuFadeOut, value: isPresented)
    }
}

/// The presented layer: the dim, then the menu as a modal.
private struct FilterMenuLayer<Menu: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder var menu: Menu

    var body: some View {
        ZStack {
            // Full screen, ignoring safe areas; not an accessibility element, no gesture.
            // filter-menu-backdrop (owner 2026-10-26): the page behind is blurred — the system
            // backdrop blur, live like CSS `backdrop-filter` — under a `color-black-60` tint so
            // the options read; replaces the see-through `color-black-80` dim. Snapshots draw
            // the material invisible (a known capture quirk); the device draws it.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Token.black60
            }
            .environment(\.colorScheme, .dark)
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .ui2Element("Dim")
            menu
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape, onDismiss)
        }
    }
}

/// The screen-level presentation. A hosted menu is handed up as the real menu view — never
/// a modifier's `Content`, which renders empty once moved out of its modifier.
private struct HostableFilterMenuPresentation<Menu: View>: ViewModifier {
    let isPresented: Bool
    let onDismiss: () -> Void
    let menu: Menu

    @Environment(\.ui2HostsOverlays) private var hosted

    func body(content: Content) -> some View {
        if hosted {
            content.hostedOverlay(
                isPresented
                    ? UI2HostedOverlay(view: AnyView(FilterMenuLayer(onDismiss: onDismiss) { menu }))
                    : nil
            )
        } else {
            content.overlay {
                menu.filterMenuPresentation(isPresented: isPresented, onDismiss: onDismiss)
            }
        }
    }
}

// MARK: - Hosting (filter-menu-fullscreen, routed to /ui2-resolve)

/// A presented full-screen overlay handed up to the app shell's host. `id` is per instance.
struct UI2HostedOverlay {
    let id = UUID()
    let view: AnyView
    /// action-menu-overlay: how the layer enters and leaves. The filter menu's crossfade is the
    /// default; the action menu brings its own (scrim fade + slide up, with its own animation).
    var transition: AnyTransition = .opacity
}

/// The presented overlay a screen hands up; the first presented one wins.
struct UI2HostedOverlayKey: PreferenceKey {
    static let defaultValue: UI2HostedOverlay? = nil
    static func reduce(value: inout UI2HostedOverlay?, nextValue: () -> UI2HostedOverlay?) {
        if value == nil { value = nextValue() }
    }
}

extension View {
    /// Hands `overlay` up to the shell's `.ui2OverlayHost()` without hiding one already handed up
    /// from inside this view. Presentations stack as nested modifiers on one screen (group-cover-image
    /// C1: delete menu, cover menu, viewer), and an outer `.preference(key:value:)` REPLACES what
    /// its content wrote — `reduce` only merges siblings — so a closed outer writer's nil would
    /// hide an open inner one. Here the inner value is kept and a nil never overrides it.
    func hostedOverlay(_ overlay: UI2HostedOverlay?) -> some View {
        transformPreference(UI2HostedOverlayKey.self) { value in
            if value == nil, let overlay { value = overlay }
        }
    }
}

private struct UI2HostsOverlaysKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True under a `.ui2OverlayHost()` — presentations hand their overlay up instead of drawing
    /// in place.
    var ui2HostsOverlays: Bool {
        get { self[UI2HostsOverlaysKey.self] }
        set { self[UI2HostsOverlaysKey.self] = newValue }
    }
}

extension View {
    /// filter-menu-fullscreen: hosts every `.filterMenuPresentation` below this view over this
    /// view's whole frame — the app shell applies it at its root so a menu covers the TopNav,
    /// the pinned headers and the TabBar. Same crossfade as the in-place presentation.
    func ui2OverlayHost() -> some View {
        environment(\.ui2HostsOverlays, true)
            .overlayPreferenceValue(UI2HostedOverlayKey.self) { overlay in
                ZStack {
                    if let overlay {
                        overlay.view.transition(overlay.transition)
                    }
                }
                .animation(overlay == nil ? Token.Motion.menuFadeOut : Token.Motion.menuFadeIn,
                           value: overlay == nil)
            }
    }
}
