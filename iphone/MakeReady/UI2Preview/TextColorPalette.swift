//
//  TextColorPalette.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-094-textcolorpalette in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-094 TextColorPalette — the colour panel the text tool's colour button opens.
///
/// A C-095 ColorPickerWell beside one page of up to nine C-096 ColorSwatch presets, with a
/// C-097 PageIndicator under the row (§2). Width-driven with a 66pt intrinsic height (R-16):
/// the row centres in the width it is given and the component paints no background (§1
/// deviation 2). Controlled (R-01): `currentColor` and `page` are the caller's; the only
/// internal state is the finger-tracked drag offset of a page swipe (R-02, animation phase).
struct TextColorPalette: View {

    /// C-094 §4 `swatches` element — a preset colour and its name (OQ-C-096-003). `name` is the
    /// C-096 accessibility label, `color` its fill.
    struct NamedColor {
        let name: String
        let color: Color
    }

    /// C-094 §4 `currentColor` — fills the well; the swatch equal to it is outlined
    /// (OQ-C-094-003). Required (R-07).
    let currentColor: Color
    /// C-094 §4 `swatches` — the preset pages, up to nine named colours each. Required.
    let swatches: [[NamedColor]]
    /// C-094 §4 `page` — the 0-based page shown; drives C-097's active dot.
    var page: Int = 0
    /// C-094 §4 `onSelect` — a swatch was tapped, with its colour (R-03). No render effect.
    var onSelect: (Color) -> Void = { _ in }
    /// C-094 §4 `onPageChange` — the row was paged, with the new index on release (R-03,
    /// OQ-C-094-002). No render effect.
    var onPageChange: (Int) -> Void = { _ in }
    /// C-094 §4 `onWellTap` — the well was tapped (R-03). No render effect.
    var onWellTap: () -> Void = {}

    /// R-02: the swipe's finger-tracked offset is an animation phase, never a prop. A
    /// `@GestureState` so it settles back on release with the ruled slide (OQ-C-094-002).
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: Geometry.slide)))
    private var dragOffset: CGFloat = 0

    /// C-094 §2's literal geometry and motion.
    private enum Geometry {
        /// FLAGGED LITERAL — C-094 §2 (OQ-C-094-4): the 8pt top and bottom insets, no token.
        static let inset: CGFloat = 8
        /// FLAGGED LITERAL — C-094 §2: the 16pt gaps in the row (well→presets, swatch→swatch).
        static let rowGap: CGFloat = 16
        /// FLAGGED LITERAL — C-094 §2: the 24pt swatch (C-096's tile), for an empty slot.
        static let swatch: CGFloat = 24
        /// FLAGGED LITERAL — C-094 §2: the 34pt colour row (C-095's well).
        static let rowHeight: CGFloat = 34
        /// C-094 §2: one page holds up to nine swatches.
        static let slots = 9
        /// The presets frame — nine 24pt swatches at a 40pt pitch (§2: 344×24).
        static let pageWidth = CGFloat(slots) * swatch + CGFloat(slots - 1) * rowGap
        /// OQ-C-094-002 ruling: ≈ 250 ms ease-out slide, no motion token.
        static let slide: Double = 0.25
    }

    private var pageCount: Int { swatches.count }

    /// §3: a `page` outside the range is a caller defect, clamped (C-097 clamps the same way).
    private var shownPage: Int {
        min(max(page, 0), max(pageCount - 1, 0))
    }

    /// One page's pitch in the sliding strip: the page plus the gap that separates pages.
    private var pagePitch: CGFloat { Geometry.pageWidth + Geometry.rowGap }

    var body: some View {
        VStack(spacing: Token.Space.elementGap) {                  // §2: row → dots gap 8
            colourRow
            PageIndicator(pageCount: pageCount, page: shownPage)    // C-097, §5
                .ui2Element("Page dots")
        }
        .padding(.vertical, Geometry.inset)
        .frame(maxWidth: .infinity)
        .ui2Element("TextColorPalette")
    }

    /// §2 Colour row: the well, a 16pt gap, then the swatch pager; shadow on the whole row.
    private var colourRow: some View {
        HStack(spacing: Geometry.rowGap) {
            ColorPickerWell(color: currentColor, onTap: onWellTap)  // C-095, §5
                .ui2Element("Well")
            presets
        }
        .frame(height: Geometry.rowHeight)
        .designShadow(Token.Elevation.thumb)                       // §2: `elevation-thumb`
        .ui2Element("Colour row")
    }

    /// §2 Paging (OQ-C-094-002 ruling): every page sits in one strip, offset to the shown page
    /// and clipped to the 344pt presets frame; a horizontal swipe tracks the finger and, on
    /// release, `onPageChange` fires with the nearer page. The caller writes `page` (R-01).
    private var presets: some View {
        HStack(spacing: Geometry.rowGap) {
            ForEach(swatches.indices, id: \.self) { pageIndex in
                pageView(swatches[pageIndex], pageIndex: pageIndex)
            }
        }
        .offset(x: -CGFloat(shownPage) * pagePitch + dragOffset)
        .animation(.easeOut(duration: Geometry.slide), value: shownPage)
        .frame(width: Geometry.pageWidth, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: Geometry.rowGap)
                .updating($dragOffset) { drag, offset, _ in offset = drag.translation.width }
                .onEnded { drag in release(drag.predictedEndTranslation.width) }
        )
        // §2 Accessibility (R-17): the row pages as an adjustable element; the well and the
        // swatches stay the parts' own buttons.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Colour palette, page \(shownPage + 1) of \(pageCount)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: changePage(to: shownPage + 1)
            case .decrement: changePage(to: shownPage - 1)
            @unknown default: break
            }
        }
        .ui2Element("Presets")
    }

    /// One page: up to nine swatches; a short page leaves its trailing slots empty
    /// (OQ-C-094-001 ruling).
    private func pageView(_ colours: [NamedColor], pageIndex: Int) -> some View {
        HStack(spacing: Geometry.rowGap) {
            ForEach(0..<Geometry.slots, id: \.self) { slot in
                if slot < colours.count {
                    let swatch = colours[slot]
                    // C-096, §5: the outline is derived from `currentColor` (OQ-C-094-003).
                    ColorSwatch(
                        color: swatch.color,
                        label: swatch.name,
                        selected: swatch.color == currentColor,
                        onTap: { onSelect(swatch.color) }
                    )
                    .ui2Element("Swatch \(slot + 1)")
                } else {
                    Color.clear.frame(width: Geometry.swatch, height: Geometry.swatch)
                }
            }
        }
        .frame(width: Geometry.pageWidth)
        // An off-page page is mounted only so the slide has something to bring in: `.clipped()`
        // hides it but neither hit-tests nor the accessibility tree nor the element map are
        // clipped, so it would sit over the well (taps, VoiceOver, comment highlights).
        .allowsHitTesting(pageIndex == shownPage)
        .accessibilityHidden(pageIndex != shownPage)
        .transformPreference(UI2ElementPreferenceKey.self) { anchors in
            if pageIndex != shownPage { anchors = [] }
        }
    }

    /// Settles a swipe on the nearer page: past half a page (or a fling past it) pages once.
    private func release(_ predicted: CGFloat) {
        let threshold = Geometry.pageWidth / 2
        var target = shownPage
        if predicted <= -threshold { target += 1 }
        if predicted >= threshold { target -= 1 }
        changePage(to: target)
    }

    private func changePage(to target: Int) {
        let clamped = min(max(target, 0), max(pageCount - 1, 0))
        if clamped != shownPage { onPageChange(clamped) }
    }
}
