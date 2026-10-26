//
//  LessonCard.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-063-lesson-card in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-063 LessonCard — one lesson: title row + optional progress bar + a horizontally
/// scrolling rail of its activity slides.
///
/// §2: "Vertical stack, fills the given width, intrinsic height (R-16)." §1 deviation 3: the
/// card is full-bleed; its content inset is internal — the title block is inset by
/// `space-page-margin` on both sides and the rail's *content* by the same, so the rail
/// scrolls under the screen edges. §1 deviation 2: no vertical padding; the host stacks
/// cards at `space-section-gap`.
struct LessonCard: View {

    /// §4 `header` — the `header` axis (R-06, nested per R-36): the lesson number, or the
    /// informational link row's label.
    enum Header {
        case numbered(lessonNumber: Int)
        case linked(label: String)
    }

    /// §4 `slides` element (OQ-C-063-6): `image` is the screenshot the caller resolved
    /// (R-19, R-32), passed to C-079 `image`; `label` is the slide button's VoiceOver label,
    /// never rendered.
    struct Slide {
        let image: Image?
        let label: String
    }

    /// §4 #1. Required (R-07).
    let header: Header
    /// §4 #2 — "lesson title; single line, tail ellipsis". Required (R-07).
    let title: String
    /// §4 #3 — "the host owns the wording". Required (R-07).
    let metaLabel: String
    /// §4 #4 — "`nil` → `progress=none`; `0…1` → `shown`, passed to C-057 `progress`".
    let progress: Double?
    /// §4 #5 — "empty → `empty` state". Required (R-07).
    let slides: [Slide]
    /// §4 #6 — "tap on the title block". No render effect; no-op default (R-03).
    var onOpen: () -> Void = {}
    /// §4 #7 — "tap on slide *i*". No render effect; no-op default (R-03).
    var onSelectSlide: (Int) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            // OQ-C-063-005 (ruled): "no activities means the title block only, with no rail
            // and no 16 gap."
            if !slides.isEmpty {
                rail
                    // §2 gap: "16 (`space-card-padding`, as study-program-home §2 cites it)".
                    .padding(.top, Token.Space.cardPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("LessonCard")
    }

    // MARK: - Title block

    /// §2 Title block: "inset `space-page-margin` (16) left and right; vertical stack, gap
    /// `space-element-gap` (8) between the title row and the second line … absent second
    /// line → no gap". §2 Accessibility: "the title block is one button".
    private var titleBlock: some View {
        SwiftUI.Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleRow
                secondLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titleAccessibilityLabel)
        .accessibilityValue(progressAccessibilityValue)
        .accessibilityAddTraits(.isButton)
        .padding(.horizontal, Token.Space.pageMargin)
        .ui2Element("Title block")
    }

    /// §2 Title row: "height 20, HStack centre-aligned, gap 10 — FLAGGED LITERAL".
    private var titleRow: some View {
        HStack(alignment: .center, spacing: Self.titleRowGap) {
            if case .numbered(let lessonNumber) = header {
                // §2 ↳ lesson number: `type-title-card`, `color-accent`, intrinsic width.
                Text(String(lessonNumber))
                    .designTextStyle(Token.TypeStyle.titleCard)
                    .foregroundStyle(Token.accent)
                    .fixedSize()
                    .ui2Element("Lesson number")
            }
            // §2 ↳ title: `type-title-card`, `color-text-primary`, flex, single line, tail ellipsis.
            Text(title)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
            // §2 ↳ meta: `type-page-title`, `color-text-secondary`, intrinsic width, trailing.
            Text(metaLabel)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textSecondary)
                .fixedSize()
                .ui2Element("Meta")
        }
        // §2 "height 20" — the row is exactly one `type-title-card` line (Bold 14/20).
        .frame(height: Token.TypeStyle.titleCard.lineHeight)
        .ui2Element("Title row")
    }

    /// §2: the second line is the link row (`linked`) or the progress bar (`progress=shown`);
    /// §3 "`linked` × `shown` is not designed and is not a state", so `linked` wins.
    @ViewBuilder
    private var secondLine: some View {
        switch header {
        case .linked(let label):
            linkRow(label)
        case .numbered:
            if let progress {
                // §2 Progress bar: C-057 `size=sm`, `aligned=Left`, `fillStyle=solid`, full
                // title-block width. OQ-C-063-001: inherit C-057's track rule (sm/Left draws
                // none). OQ-C-063-002: no `fillColor` override — C-057's threshold ramp colours it.
                PercentBar(progress: progress, fillColor: nil, size: .sm, aligned: .left, fillStyle: .solid)
                    .ui2Element("Progress bar")
            }
        }
    }

    /// §2 Link row: "informational, not a link and not tappable (OQ-C-063-004, OQ-C-063-7):
    /// HStack gap `space-element-gap` (8): glyph `chain-link` 16×16 `color-text-secondary` +
    /// label `type-page-title` `color-text-secondary`, flex, wraps". It sits inside the title
    /// block's button and is read in that button's label, never as its own element.
    private func linkRow(_ label: String) -> some View {
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            Glyph(.chainLink, size: .sm, tint: Token.textSecondary)
                .ui2Element("Link glyph")
            Text(label)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Link label")
        }
        // `type-page-title` is 14/20: one line is a 20pt box. `designTextStyle` adds leading
        // only BETWEEN lines, so a single line would measure ~17 without this floor.
        .frame(minHeight: Token.TypeStyle.pageTitle.lineHeight)
        // The harness proposes a numeric 0 height; free the vertical axis OUTSIDE the
        // min-height frame so a wrapping label keeps its own height.
        .fixedSize(horizontal: false, vertical: true)
        .ui2Element("Link row")
    }

    // MARK: - Activity rail

    /// §2 Activity rail: "horizontal ScrollView, content inset `space-page-margin` leading +
    /// trailing, item gap `space-meta-gap` (4); one C-079 ActivityScreenshot per `slides`
    /// entry, 112 wide, height from C-079's aspect … and the rail is that tall; each slide is
    /// a button (0.6 press feedback) calling `onSelectSlide(i)`; clipped at the card's edges".
    private var rail: some View {
        HorizontalRail(showsIndicators: false) {
            HStack(alignment: .top, spacing: Token.Space.metaGap) {
                ForEach(slides.indices, id: \.self) { index in
                    SwiftUI.Button { onSelectSlide(index) } label: {
                        ActivityScreenshot(image: slides[index].image)
                            .frame(width: Self.slideWidth)
                    }
                    .buttonStyle(PressedDim())
                    // §2 Accessibility: "each slide is a button labelled `Slide.label`".
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(slides[index].label)
                    .accessibilityAddTraits(.isButton)
                    .ui2Element("Slide \(index + 1)")
                }
            }
            .padding(.horizontal, Token.Space.pageMargin)
        }
        // The rail's height is its slides' height (C-079's aspect), not the harness's proposal.
        .fixedSize(horizontal: false, vertical: true)
        .ui2Element("Activity rail")
    }

    // MARK: - Accessibility

    /// §2 Accessibility: "Lesson {n}, {title}, {metaLabel}" (`linked`: "{title}, {label},
    /// {metaLabel}").
    private var titleAccessibilityLabel: String {
        switch header {
        case .numbered(let lessonNumber): "Lesson \(lessonNumber), \(title), \(metaLabel)"
        case .linked(let label): "\(title), \(label), \(metaLabel)"
        }
    }

    /// §2 Accessibility: "the progress bar is an accessibility value on that button
    /// ("{percent}% complete")". Only when the bar is drawn.
    private var progressAccessibilityValue: String {
        guard case .numbered = header, let progress else { return "" }
        let percent = Int((min(max(progress, 0), 1) * 100).rounded())
        return "\(percent)% complete"
    }

    // MARK: - Geometry

    // FLAGGED LITERAL — C-063 §2: title-row gap 10, no spacing token (program's 2nd occurrence
    // after C-033's root stack, per study-program-home §2).
    private static let titleRowGap: CGFloat = 10

    // GAP — C-063 §2 / §1 dev 4: slide width 112, no size token (OQ-C-063-008).
    private static let slideWidth: CGFloat = 112

    /// §1 deviation 4 / OQ-C-063-6: "0.6 press feedback". Ephemeral, owned by the button (R-02).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? LessonCard.pressedOpacity : 1)
        }
    }

    private static let pressedOpacity: Double = 0.6
}
