//
//  ActivityNavBar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-081-activitynavbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-081 ActivityNavBar — the lesson editor's bottom strip of activity slides plus a trailing
/// add button.
///
/// §2: "A horizontal row, 104 pt tall at the 440 design width (16 + 72 + 16). Width-driven: it
/// fills the width it is given (R-16). It paints **no background**." The four-side
/// `space-page-margin` is the component's own inset, not outer chrome — it is what makes the
/// row 104 tall.
struct ActivityNavBar: View {

    /// §4 `slides` element (R-36, nested). `image` is the activity's screenshot, already
    /// resolved by the screen (OQ-C-061-6; R-19, R-32): non-nil renders the filled chip, nil the
    /// empty C-061 chip (OQ-C-081-6). `label` is VoiceOver-only.
    struct Slide {
        let id: String
        let image: Image?
        let label: String
    }

    /// §4 #1 — "One per activity, in lesson order." Required (R-07).
    let slides: [Slide]
    /// §4 #2 — "The slide drawn active (C-061 `active=true`, or the filled chip's outline). nil
    /// means none is outlined."
    /// Required (R-07: no default is designed).
    let activeID: String?
    /// §4 #3 — "Extra space added below the chips and the add button, inside the bar's frame:
    /// the bar grows by this amount and the chips and ＋ sit that much higher. Default 0."
    var bottomInset: CGFloat = 0
    /// §4 #4 — "Tap on a slide, passing that slide's `id`." No render effect; no-op (R-03).
    var onSelectSlide: (String) -> Void = { _ in }
    /// §4 — the trailing ＋ takes taps (activities-editor §14.2, owner ruling 2026-11-09). When
    /// false the ＋ is drawn at the disabled tone (C-102's disabled look, `color-white-50`), takes
    /// no tap and carries the disabled trait. Default true, so every other caller is unchanged.
    var addEnabled: Bool = true
    /// §4 #5 — "Tap on the trailing C-021 `add`." No render effect; no-op (R-03).
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
            addButton
                .ui2Element("Add button")
                // §2 Padding: "`space-page-margin` (16) on all four sides."
                .padding(.trailing, Token.Space.pageMargin)
        }
        // §2: "104 pt tall (16 + 72 + 16)" — held even when `slides` is empty (OQ-C-081-001;
        // §3 empty: "height unchanged (104)").
        .frame(height: Self.height)
        // §2 Bottom inset: "extra space added below the chips and the add button, inside the
        // bar's frame, on top of the 16 bottom padding. The bar grows by that amount."
        .padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity)
        .ui2Element("ActivityNavBar")
    }

    /// The trailing ＋ — C-021 `add`, or, while `addEnabled` is false, the same C-021 glyph used
    /// as a mask over `color-white-50` inside a disabled button. GAP — C-021 has no disabled state
    /// (OQ-C-021-1), so its accent tint cannot be changed from outside.
    @ViewBuilder private var addButton: some View {
        if addEnabled {
            GlyphButton(glyph: .add, onTap: onAdd)
                // §4 Accessibility (R-17): "The add button is labelled \"Add activity\"."
                .accessibilityLabel("Add activity")
        } else {
            SwiftUI.Button(action: {}) {
                Token.white50
                    .frame(width: Self.addVisual, height: Self.addVisual)
                    .mask { GlyphButton(glyph: .add).allowsHitTesting(false) }
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Add activity")
        }
    }

    // MARK: - Slide strip

    /// §2 Slide strip: "its scroll area spans the full component width (deviation 3); its content
    /// is inset `space-page-margin` (16) leading and 16 + 24 + `space-meta-gap` (44) trailing …
    /// gap `space-meta-gap` (4) between slides … It scrolls horizontally on overflow (deviation
    /// 2), with no scroll indicators (OQ-C-081-002)." OQ-C-081-002 also rules "the active slide
    /// scrolls into view whenever `activeID` changes" — view-local scroll, no side effect (R-04).
    private var strip: some View {
        ScrollViewReader { proxy in
            HorizontalRail(showsIndicators: false) {
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

    /// §3: "Each slide renders the filled chip when its `image` is non-nil and the empty C-061
    /// chip when it is nil (OQ-C-081-6). Both chips are 440:956 at 72 tall (D31)."
    @ViewBuilder
    private func slideView(_ slide: Slide) -> some View {
        if let image = slide.image {
            FilledChip(image: image, active: slide.id == activeID, label: slide.label) {
                onSelectSlide(slide.id)
            }
        } else {
            // C-061 carries its own button, VoiceOver label, `.isSelected` and the 0.6 press
            // dim (OQ-C-081-003) — §4 Accessibility is satisfied by the part itself.
            ActivitySlide(active: slide.id == activeID, label: slide.label) {
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

    /// §2 Slide strip: "Every chip is 72 pt tall and ≈ 33.1 pt wide — C-079 ActivityScreenshot's
    /// aspect, 440:956, so width = 72 × 440 / 956" (SPEC D31, updated 2026-11-09).
    fileprivate static let slideHeight: CGFloat = 72
    fileprivate static let slideWidth: CGFloat = slideHeight * 440 / 956
    /// §2: the bar's height before `bottomInset` — 16 + 72 + 16 = 104. §5: "Hosts lay out against
    /// the bar's measured height, never a literal" — exposed so a host's matching row follows it.
    static let height: CGFloat = slideHeight + Token.Space.pageMargin * 2
    /// §2 Add button: "24×24 visual" (C-021's).
    private static let addVisual: CGFloat = 24
    /// §2: the strip's trailing content inset, "16 + 24 + `space-meta-gap` (44)".
    private static let addClearance: CGFloat = Token.Space.pageMargin + addVisual + Token.Space.metaGap
}

// MARK: - Filled chip

/// §2 Slide strip, filled chip (OQ-C-081-6; SPEC D31): "a slide whose `image` is non-nil renders
/// the screenshot, built **inside this row** (no registry row): the image **scaled to fit** the
/// chip exactly and **never cropped** … clipped to `radius-card`, with C-061's 1 pt active outline
/// (same stroke, colour and inset) when the slide's `id` is `activeID`. Pressed, it dims to 0.6
/// like every slide (OQ-C-081-003)."
private struct FilledChip: View {
    let image: Image
    let active: Bool
    let label: String
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            // §2 (D31): "scaled to fit the chip exactly and never cropped". The clear frame fixes
            // the 440:956 footprint; the screenshot is fitted inside it, so nothing is lost.
            Color.clear
                .frame(width: ActivityNavBar.slideWidth, height: ActivityNavBar.slideHeight)
                .overlay {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: ActivityNavBar.slideWidth, height: ActivityNavBar.slideHeight)
                        .ui2Element("Screenshot")
                }
                // §2: "clipped to `radius-card`".
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
                // §2: "C-061's 1 pt active outline (same stroke, colour and inset)" — C-061 §2:
                // 1pt `color-white-100`, stroked inside the frame edge, no geometry change.
                .overlay {
                    if active {
                        RoundedRectangle(cornerRadius: Token.Radius.card)
                            .strokeBorder(Token.white100, lineWidth: Self.outlineWidth)
                            .ui2Element("Active outline")
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
        .buttonStyle(PressedDim())
        // §4 Accessibility (R-17): "each slide is a button labelled `label`, with
        // `.isSelected` when it is active, whichever chip it renders."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("Filled chip")
    }

    /// C-061 §2 Active outline: "1pt".
    private static let outlineWidth: CGFloat = 1

    /// OQ-C-081-003: "the pressed slide at 0.6 opacity with no geometry change". Ephemeral,
    /// owned by the button (R-02).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
        }
    }
}
