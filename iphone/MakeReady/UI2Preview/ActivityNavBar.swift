//
//  ActivityNavBar.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-081-activitynavbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-081 ActivityNavBar — the lesson editor's bottom strip of activity slides plus a trailing
/// add button.
///
/// §2: "A horizontal row, 76 pt tall at the 440 design width (16 + 44 + 16). Width-driven: it
/// fills the width it is given (R-16). It paints **no background**." The four-side
/// `space-page-margin` is the component's own inset, not outer chrome — it is what makes the
/// row 76 tall.
struct ActivityNavBar: View {

    /// §4 `slides` element (R-36, nested). `image` is the activity's screenshot, already
    /// resolved by the screen (OQ-C-061-6; R-19, R-32); `label` is VoiceOver-only.
    struct Slide {
        let id: String
        let image: Image?
        let label: String
    }

    /// §4 #1 — "One per activity, in lesson order." Required (R-07).
    let slides: [Slide]
    /// §4 #2 — "The slide drawn with C-061 `active=true`. nil means none is outlined."
    /// Required (R-07: no default is designed).
    let activeID: String?
    /// §4 #3 — "Tap on a slide, passing that slide's `id`." No render effect; no-op (R-03).
    var onSelectSlide: (String) -> Void = { _ in }
    /// §4 #4 — "Tap on the trailing C-021 `add`." No render effect; no-op (R-03).
    var onAdd: () -> Void = {}

    var body: some View {
        // Deviation 3 (owner-ruled 2026-09-30): the strip's scroll area spans the full width
        // and the add button sits above it, trailing — so the strip is the base layer, not a
        // sibling squeezed into the padded row.
        ZStack(alignment: .trailing) {
            strip
            // §2 Add button: "one C-021 GlyphButton `glyph=add`, 24×24 visual, trailing,
            // centred vertically … drawn above the strip and its mask. The 44 pt hit target is
            // C-021's." Pinned outside the scroll (OQ-C-081-002).
            GlyphButton(glyph: .add, action: onAdd)
                // §4 Accessibility (R-17): "The add button is labelled \"Add activity\"."
                .accessibilityLabel("Add activity")
                .ui2Element("Add button")
                // §2 Padding: "`space-page-margin` (16) on all four sides."
                .padding(.trailing, Token.Space.pageMargin)
        }
        // §2: "76 pt tall (16 + 44 + 16)" — held even when `slides` is empty (OQ-C-081-001:
        // "the bar keeps its 76 pt height").
        .frame(height: Self.slideHeight + Token.Space.pageMargin * 2)
        .frame(maxWidth: .infinity)
        .ui2Element("ActivityNavBar")
    }

    // MARK: - Slide strip

    /// §2 Slide strip: "its scroll area spans the full component width (deviation 3); its content
    /// is inset `space-page-margin` (16) leading and 16 + 24 + `space-meta-gap` (44) trailing …
    /// gap `space-meta-gap` (4) between slides … It scrolls horizontally on overflow (deviation
    /// 2), with no scroll indicators (OQ-C-081-002)." OQ-C-081-002 also rules "the active slide
    /// scrolls into view whenever `activeID` changes" — view-local scroll, no side effect (R-04).
    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: Token.Space.metaGap) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        slideView(slide)
                            // OQ-C-081-r1: the scroll target is the slide extended one fade
                            // length on its trailing side, so scroll-into-view rests the
                            // active slide clear of the fade. A background, so layout is
                            // unchanged.
                            .background(alignment: .leading) {
                                Color.clear
                                    .frame(width: Self.slideWidth + Self.fadeLength)
                                    .id(ScrollTarget(id: slide.id))
                            }
                            .ui2Element("Slide \(index + 1)")
                    }
                }
                .padding(.vertical, Token.Space.pageMargin)
            }
            // Deviation 3: the 16 pt insets are scroll-CONTENT insets, so scrolled slides
            // reach the left edge; the trailing inset clears the add button and its gap.
            // Content margins (not padding) so `scrollTo` keeps the active slide inside them.
            .contentMargins(.leading, Token.Space.pageMargin, for: .scrollContent)
            .contentMargins(.trailing, Self.addClearance, for: .scrollContent)
            .onAppear { scrollToActive(proxy) }
            .onChange(of: activeID) { scrollToActive(proxy) }
        }
        // Deviation 3 (amended 2026-09-30): "a gradient mask fades the strip from 100% at x 360
        // to 0% at the add button's leading edge (x 400 at 440) and holds 0% to the right
        // edge." Mask colours carry alpha only.
        .mask {
            GeometryReader { geo in
                LinearGradient(
                    stops: [
                        .init(color: .black, location: Self.fadeStart(width: geo.size.width)),
                        .init(color: .clear, location: Self.fadeEnd(width: geo.size.width)),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Slide strip")
    }

    /// Deviation 3: the fade ends at the add button's leading edge, `space-page-margin` +
    /// C-021's 24 pt visual in from the right edge.
    private static func fadeEnd(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        return max(0, (width - fadeLength) / width)
    }

    /// Deviation 3: the fade starts one fade length (40) before it ends, at x 360 at 440.
    private static func fadeStart(width: CGFloat) -> CGFloat {
        guard width > 0 else { return 1 }
        return max(0, (width - fadeLength * 2) / width)
    }

    /// §2: "The fade length is 40 = `space-page-margin` + the add button's 24 visual."
    private static let fadeLength: CGFloat = Token.Space.pageMargin + addVisual

    /// §3: "Which part renders a slide is decided by `image` alone (OQ-C-081-6): nil → C-061,
    /// non-nil → the filled chip."
    @ViewBuilder
    private func slideView(_ slide: Slide) -> some View {
        if slide.image == nil {
            // C-061 carries its own button, VoiceOver label, `.isSelected` and the 0.6 press
            // dim (OQ-C-081-003) — §4 Accessibility is satisfied by the part itself.
            ActivitySlide(active: slide.id == activeID, label: slide.label) {
                onSelectSlide(slide.id)
            }
        } else {
            FilledChipStub(active: slide.id == activeID, label: slide.label) {
                onSelectSlide(slide.id)
            }
        }
    }

    private func scrollToActive(_ proxy: ScrollViewProxy) {
        guard let activeID, slides.contains(where: { $0.id == activeID }) else { return }
        proxy.scrollTo(ScrollTarget(id: activeID))
    }

    /// OQ-C-081-r1: the extended scroll target's identity. Distinct from the `ForEach` element
    /// id, which `scrollTo` would otherwise resolve to the unextended slide.
    private struct ScrollTarget: Hashable {
        let id: String
    }

    /// §2 Slide strip: "44 tall"; "Each slide is 33×44".
    fileprivate static let slideWidth: CGFloat = 33
    fileprivate static let slideHeight: CGFloat = 44
    /// §2 Add button: "24×24 visual" (C-021's).
    private static let addVisual: CGFloat = 24
    /// §2: the strip's trailing content inset, "16 + 24 + `space-meta-gap` (44)".
    private static let addClearance: CGFloat = Token.Space.pageMargin + addVisual + Token.Space.metaGap
}

// MARK: - Filled chip (stub)

// STUB — filled chip, not a linked component. OQ-C-081-6 rules it "a new registry row: a
// 33×44 filled chip showing the activity's screenshot (aspect-fill, top-aligned, clipped to
// radius-card) with C-061's 1pt active outline". The row is not minted, so there is no
// contract to build its visuals from: this holds the correct 33×44 slot, the tap, the
// VoiceOver label and the active outline, and paints an obviously unfinished dashed fill
// instead of the screenshot. Replace it with the real row once it is specced, built and
// linked to C-081's §5.
private struct FilledChipStub: View {
    let active: Bool
    let label: String
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.screenshotPlaceholder)
                // STUB — the unfinished marker: a dashed border no contract designs.
                .overlay {
                    RoundedRectangle(cornerRadius: Token.Radius.card)
                        .strokeBorder(Token.textSecondary, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                // OQ-C-081-6: "C-061's 1pt active outline" — C-061 §2: 1pt `color-white-100`,
                // stroked inside the frame edge.
                .overlay {
                    if active {
                        RoundedRectangle(cornerRadius: Token.Radius.card)
                            .strokeBorder(Token.white100, lineWidth: 1)
                            .ui2Element("Active outline")
                    }
                }
                .frame(width: ActivityNavBar.slideWidth, height: ActivityNavBar.slideHeight)
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(PressedDim())
        // §4 Accessibility (R-17): "each slide is a button labelled `label`, with
        // `.isSelected` when it is active."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("Filled chip (stub)")
    }

    /// OQ-C-081-003 (ratified): "the pressed slide at 0.6 opacity with no geometry change".
    /// Ephemeral, owned by the button (R-02).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}
