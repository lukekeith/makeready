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
    /// never rendered. `glyph` (2026-11-09) goes to C-079 `glyph` and shows only with no
    /// image; `enabled == false` (2026-11-09) makes the slide inert to a tap — no
    /// `onSelectSlide`, no `.isButton`, no default accessibility action — while its
    /// touch-and-hold, press dim and "More actions" stay.
    struct Slide {
        let image: Image?
        let label: String
        var glyph: GlyphName? = nil
        var enabled: Bool = true
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
    /// §4 #8 — "`nil` → no add card (today's look; `empty` keeps OQ-C-063-005). Non-nil → the
    /// add card after the last slide, `numbered` header only".
    var onAddActivity: (() -> Void)? = nil
    /// §4 #9 — "`nil` → no chevron. Non-nil → the actions chevron button in the title row, a
    /// sibling of the title-block button".
    var onActions: (() -> Void)? = nil
    /// §4 #10 — "`nil` → one-tone meta. Non-nil → two-tone: `metaLabel` in
    /// `color-text-primary`, `metaUnit` in `color-text-secondary`".
    var metaUnit: String? = nil
    /// §4 #11 — "`false` → the number draws as "{n}" (today's look). `true` with `.numbered` →
    /// uppercase "DAY {n}", tracking 1.4pt, same type and colour, never truncated; no effect
    /// with `.linked`. VoiceOver labels unchanged".
    var showsDayLabel: Bool = false
    /// Touch-and-hold on slide *i* (study-program-home §3 "Slide touch-and-hold", 2026-11-09):
    /// a system-duration long-press on the slide's C-079 calls this **instead of**
    /// `onSelectSlide(i)`; the slide also exposes the "More actions" accessibility action that
    /// calls it. No render effect; no-op default (R-03), so hosts that omit it are unchanged.
    var onLongPressSlide: (Int) -> Void = { _ in }

    /// The slide under a finger that may still become a touch-and-hold — it draws the 0.6
    /// press dim. Ephemeral gesture state, owned by the card (R-02).
    @SwiftUI.State private var pressedSlide: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            // OQ-C-063-005 (ruled): "no activities means the title block only, with no rail
            // and no 16 gap." §3 `empty-add` departs from it for a host that supplies
            // `onAddActivity`: the rail draws the add card alone, its 16 gap present.
            if !slides.isEmpty || addAction != nil {
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
        // §2 ↳ actions chevron: "a separate button, a sibling of the title-block button — never
        // inside it". Top-aligned so it stays on the title row above a second line. Figma
        // `4789:45919` sets it 16 after the meta.
        HStack(alignment: .top, spacing: Token.Space.cardPadding) {
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
            if let onActions {
                actionsChevron(onActions)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .ui2Element("Title block")
    }

    /// §2 ↳ actions chevron: "Glyph `chevron-down-carbon` 24, tint `color-accent` … hit target
    /// ≥ 44 high". The 24 glyph (Figma `4789:45921`) fills the title row's 24 height; the hit
    /// area is an expanded content shape, as C-021 does.
    private func actionsChevron(_ action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            Glyph(.chevronDownCarbon, size: .md, tint: Token.accent)
                .frame(height: Self.titleRowHeightWithActions)
                .contentShape(Rectangle().inset(by: -Self.chevronHitInset))
        }
        .buttonStyle(PressedDim())
        // §2 Accessibility: "its own button, label "Lesson {n} actions", trait `.isButton`".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(actionsAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .ui2Element("Actions chevron")
    }

    /// §2 Title row: "height 20; 24 when `onActions` is set, HStack centre-aligned, gap 10 —
    /// FLAGGED LITERAL".
    private var titleRow: some View {
        HStack(alignment: .center, spacing: Self.titleRowGap) {
            if case .numbered(let lessonNumber) = header {
                // §2 ↳ lesson number: `type-title-card`, `color-accent`, intrinsic width.
                lessonNumberText(lessonNumber)
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
            // Two-tone (`metaUnit`): `metaLabel` in `color-text-primary`, the unit in
            // `color-text-secondary`, same type style, separated by one space.
            metaText
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textSecondary)
                .fixedSize()
                .ui2Element("Meta")
        }
        // §2 "height 20" — the row is exactly one `type-title-card` line (Bold 14/20); 24 when
        // `onActions` is set (Figma Top frame `4789:45916`).
        .frame(height: onActions == nil ? Token.TypeStyle.titleCard.lineHeight : Self.titleRowHeightWithActions)
        .ui2Element("Title row")
    }

    /// §2 Day label: "uppercase "DAY {n}" instead of "{n}" … tracking 0.1em = 1.4pt at 14pt".
    /// The tracking sits on the `Text` itself so it outranks the type style's own tracking.
    private func lessonNumberText(_ lessonNumber: Int) -> Text {
        guard showsDayLabel else { return Text(String(lessonNumber)) }
        return Text(verbatim: "DAY \(lessonNumber)").tracking(Self.dayLabelTracking)
    }

    private var metaText: Text {
        guard let metaUnit else { return Text(metaLabel) }
        return Text("\(Text(metaLabel).foregroundStyle(Token.textPrimary)) \(metaUnit)")
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
                    // A slide is a tap plus a touch-and-hold, not a Button: a Button (and a
                    // gesture run alongside it) keeps the touch when a sideways drag starts on a
                    // slide, so the scroll fired the tap or the long-press. These two fail once
                    // the finger moves, so the HorizontalRail takes the drag.
                    ActivityScreenshot(image: slides[index].image, glyph: slides[index].glyph)
                        .frame(width: Self.slideWidth)
                        .opacity(pressedSlide == index ? Self.pressedOpacity : 1)
                        .contentShape(Rectangle())
                        // §3 per-slide options: a disabled slide's tap does nothing.
                        .onTapGesture { if slides[index].enabled { onSelectSlide(index) } }
                        // study-program-home §3 "Slide touch-and-hold": the hold fires instead of
                        // the tap; moving more than 10 pt cancels it and lets the rail scroll.
                        .onLongPressGesture(
                            minimumDuration: Self.slideHoldDuration,
                            maximumDistance: Self.slideHoldSlop,
                            perform: { onLongPressSlide(index) },
                            onPressingChanged: { pressing in
                                if pressing {
                                    pressedSlide = index
                                } else if pressedSlide == index {
                                    pressedSlide = nil
                                }
                            }
                        )
                        // §2 Accessibility: "each slide is a button labelled `Slide.label`" —
                        // its activation is the tap the Button used to give it.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(slides[index].label)
                        // A disabled slide drops `.isButton` and the default action (§3).
                        .modifier(SlideActivation(enabled: slides[index].enabled) { onSelectSlide(index) })
                        // VoiceOver cannot long-press reliably: the same callback as a custom action.
                        .accessibilityAction(named: "More actions") { onLongPressSlide(index) }
                        .ui2Element("Slide \(index + 1)")
                }
                if let addAction {
                    addCard(addAction)
                }
            }
            .padding(.horizontal, Token.Space.pageMargin)
        }
        // The rail's height is its slides' height (C-079's aspect), not the harness's proposal.
        .fixedSize(horizontal: false, vertical: true)
        .ui2Element("Activity rail")
    }

    /// §3: "The add card is not drawn with `header=linked`."
    private var addAction: (() -> Void)? {
        guard case .numbered = header else { return nil }
        return onAddActivity
    }

    /// §2 Add card: "112 wide, the slide's height … Glyph `add-large-carbon` 24×24 centred,
    /// tint `color-white-50`. Surface and corner radius follow Figma `4494:40744`" (#2e2e2e,
    /// radius 8). The hidden C-079 gives the height, so the rail is the same height with or
    /// without slides and follows C-079's aspect if it ever moves.
    private func addCard(_ action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            ActivityScreenshot(image: nil)
                .hidden()
                .frame(width: Self.slideWidth)
                .overlay {
                    RoundedRectangle(cornerRadius: Token.Radius.card)
                        .fill(Token.activitySlidePlaceholder)
                    Glyph(.addLargeCarbon, size: .md, tint: Token.white50)
                        .ui2Element("Add icon")
                }
        }
        .buttonStyle(PressedDim())
        // §2 Accessibility: "a button, label "Add activity to lesson {n}", trait `.isButton`;
        // the icon is decorative."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(addAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .ui2Element("Add card")
    }

    // MARK: - Accessibility

    /// §2 Accessibility: "Lesson {n}, {title}, {metaLabel}" (two-tone: "{metaLabel} {metaUnit}"
    /// in place of {metaLabel}; `linked`: "{title}, {label}, {metaLabel}").
    private var titleAccessibilityLabel: String {
        let meta = metaUnit.map { "\(metaLabel) \($0)" } ?? metaLabel
        switch header {
        case .numbered(let lessonNumber): return "Lesson \(lessonNumber), \(title), \(meta)"
        case .linked(let label): return "\(title), \(label), \(meta)"
        }
    }

    /// §2 Accessibility: "Lesson {n} actions". A `linked` card has no number, so it reads its title.
    private var actionsAccessibilityLabel: String {
        switch header {
        case .numbered(let lessonNumber): "Lesson \(lessonNumber) actions"
        case .linked: "\(title) actions"
        }
    }

    /// §2 Accessibility: "Add activity to lesson {n}". The card is only drawn for `numbered`.
    private var addAccessibilityLabel: String {
        guard case .numbered(let lessonNumber) = header else { return "Add activity" }
        return "Add activity to lesson \(lessonNumber)"
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

    // GAP — C-063 §2: day-label tracking 0.1em = 1.4pt at 14pt, no tracking token (owner ruling
    // 2026-11-06, program-day-rail-sticky).
    private static let dayLabelTracking: CGFloat = 1.4

    // GAP — C-063 §2 / §1 dev 4: slide width 112, no size token (OQ-C-063-008).
    private static let slideWidth: CGFloat = 112

    // GAP — C-063 §2: title row "24 when `onActions` is set", no size token.
    private static let titleRowHeightWithActions: CGFloat = 24

    // GAP — C-063 §2: "hit target ≥ 44 high", no size token. 12 above and below the 24 row.
    private static let chevronHitInset: CGFloat = 12

    /// §1 deviation 4 / OQ-C-063-6: "0.6 press feedback". Ephemeral, owned by the button (R-02).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? LessonCard.pressedOpacity : 1)
        }
    }

    private static let pressedOpacity: Double = 0.6

    /// §3 per-slide options (2026-11-09): an enabled slide is a button whose default
    /// accessibility action is its tap; a disabled one is neither.
    private struct SlideActivation: ViewModifier {
        let enabled: Bool
        let action: () -> Void

        func body(content: Content) -> some View {
            if enabled {
                content
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { action() }
            } else {
                content
            }
        }
    }

    /// study-program-home §3 "Slide touch-and-hold": the system long-press duration (0.5 s).
    private static let slideHoldDuration: Double = 0.5

    /// The finger travel that cancels a slide's tap / hold so the rail scrolls instead (10 pt).
    private static let slideHoldSlop: CGFloat = 10
}
