//
//  TextColorPalette.swift
//  MakeReadyUI — the UI 2.0 module
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
    /// C-094 §4 `showsWell` — false: the C-095 well is not drawn at all and the swatches lay out
    /// without it, centred in the row.
    var showsWell: Bool = true

    /// R-02: the swipe's finger-tracked offset is an animation phase, never a prop. It settles
    /// back on release with the ruled slide (OQ-C-094-002).
    @State private var dragOffset: CGFloat = 0

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
        /// FLAGGED LITERAL — C-094 §2: the row's 23pt inset on each side.
        static let rowInset: CGFloat = 23
        /// The presets frame — nine 24pt swatches and their gaps (§2 at 16: 344×24).
        static func pageWidth(gap: CGFloat) -> CGFloat {
            CGFloat(slots) * swatch + CGFloat(slots - 1) * gap
        }
        /// OQ-C-094-002 ruling: ≈ 250 ms ease-out slide, no motion token.
        static let slide: Double = 0.25
    }

    private var pageCount: Int { swatches.count }

    /// §3: a `page` outside the range is a caller defect, clamped (C-097 clamps the same way).
    private var shownPage: Int {
        min(max(page, 0), max(pageCount - 1, 0))
    }

    /// C-094 §2: on a width too narrow for §2's 16pt gaps they shrink evenly so the row fits
    /// between its 23pt insets; the swatches, the well and the gap beside the well keep their sizes.
    private func swatchGap(forWidth width: CGFloat) -> CGFloat {
        let well = showsWell ? Geometry.rowHeight + Geometry.rowGap : 0
        let space = width - 2 * Geometry.rowInset - well - CGFloat(Geometry.slots) * Geometry.swatch
        return min(max(space / CGFloat(Geometry.slots - 1), 0), Geometry.rowGap)
    }

    var body: some View {
        VStack(spacing: Token.Space.elementGap) {                  // §2: row → dots gap 8
            GeometryReader { proxy in
                colourRow(swatchGap: swatchGap(forWidth: proxy.size.width))
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(height: Geometry.rowHeight)
            PageIndicator(pageCount: pageCount, page: shownPage)    // C-097, §5
                .ui2Element("Page dots")
        }
        .padding(.vertical, Geometry.inset)
        .frame(maxWidth: .infinity)
        .ui2Element("TextColorPalette")
    }

    /// §2 Colour row: the well, a 16pt gap, then the swatch pager; shadow on the whole row.
    private func colourRow(swatchGap: CGFloat) -> some View {
        HStack(spacing: Geometry.rowGap) {
            if showsWell {
                ColorPickerWell(color: currentColor, onTap: onWellTap)  // C-095, §5
                    .ui2Element("Well")
            }
            presets(swatchGap: swatchGap)
        }
        .designShadow(Token.Elevation.thumb)                       // §2: `elevation-thumb`
        .ui2Element("Colour row")
    }

    /// §2 Paging (OQ-C-094-002 ruling): every page sits in one strip, offset to the shown page
    /// and clipped to the presets frame (344pt at §2's gap); a horizontal swipe tracks the finger and, on
    /// release, `onPageChange` fires with the nearer page. The caller writes `page` (R-01).
    private func presets(swatchGap: CGFloat) -> some View {
        let pageWidth = Geometry.pageWidth(gap: swatchGap)
        return HStack(spacing: Geometry.rowGap) {
            ForEach(swatches.indices, id: \.self) { pageIndex in
                pageView(swatches[pageIndex], pageIndex: pageIndex, swatchGap: swatchGap)
            }
        }
        // One page's pitch in the sliding strip: the page plus the gap that separates pages.
        .offset(x: -CGFloat(shownPage) * (pageWidth + Geometry.rowGap) + dragOffset)
        .animation(.easeOut(duration: Geometry.slide), value: shownPage)
        .frame(width: pageWidth, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        // Sideways only, so a vertical drag on the palette scrolls the page (HorizontalScrolling.swift).
        .horizontalPan(
            onChanged: { dragOffset = $0.translation },
            onEnded: { value in
                withAnimation(.easeOut(duration: Geometry.slide)) { dragOffset = 0 }
                release(value.predictedEndTranslation, pageWidth: pageWidth)
            }
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
    private func pageView(_ colours: [NamedColor], pageIndex: Int, swatchGap: CGFloat) -> some View {
        HStack(spacing: swatchGap) {
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
        .frame(width: Geometry.pageWidth(gap: swatchGap))
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
    private func release(_ predicted: CGFloat, pageWidth: CGFloat) {
        let threshold = pageWidth / 2
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
