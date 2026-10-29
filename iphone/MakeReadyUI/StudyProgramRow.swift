//
//  StudyProgramRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-059-study-program-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-059 StudyProgramRow — "one study program in a list: its identity, its progress, its
/// completion".
///
/// §2: a Details column (title + a per-state 2nd element + a C-043 chip row) beside a 64×64
/// cover, with no border and no fill. Width-driven, intrinsic height (R-16): 120 `Condensed`,
/// 96 `Progress` / `Complete`, 132 `Enrolled` at a two-line description, 108 `Program` — the
/// row's own `space-card-padding` inset top and bottom is inside that height; it paints no
/// background and adds no other outer padding.
///
/// Controlled (R-01): every §3 state is a prop combination — `state` + `progress` +
/// `metaChips` (+ `description`, + `caption`) give the five symbols, `progress = 0` and `cover = nil` the two ruled
/// undesigned rows. The only internal state is the ephemeral pressed look (R-02), which the
/// button style owns.
struct StudyProgramRow: View {

    /// §4 `state` — `Condensed | Progress | Complete | Enrolled | Program`, nested per R-06 /
    /// R-36. Raw values are §3's labels verbatim, because those are the strings the fixture
    /// carries. `Complete` is Figma's placeholder `state4`, renamed by OQ-C-059-2 (deviation 4).
    /// `Enrolled` is Figma `3767:11827`, added by D53; `Program` is Figma `3608:4488`, by D59.
    enum State: String {
        case condensed = "Condensed"
        case progress = "Progress"
        case complete = "Complete"
        case enrolled = "Enrolled"
        case program = "Program"
    }

    /// One entry of §4 `metaChips: [C-043 MetaChip]` — "each element a C-043 prop tuple
    /// (`value`, `label`, `state`, `align`) … The chip's value sets are C-043's and are not
    /// restated here", so the fields take C-043's own types and C-043's own defaults.
    struct Chip {
        let value: String
        var label: String?
        var state: MetaChip.State = .default
        /// C-043's `labelPosition` (OQ-C-043-1), still named `align` in this row's own §4.
        var align: MetaChip.LabelPosition = .trailing
    }

    /// §4 `state` — required.
    let state: State
    /// §4 `title` — "single line, ellipsized in every state". Required.
    let title: String
    /// §4 `description` — "`Condensed`, `Enrolled` and `Program` only; wraps in
    /// `Condensed`/`Enrolled`, one line, ellipsized in `Program`. Ignored in the other states".
    /// Unrequired (R-07: two of five variants show the row without it).
    let description: String?
    /// §4 `caption` — "`Program` only (D59): the plain `color-accent` line under the
    /// description — the caller's whole string … One line, ellipsized. Ignored in the other
    /// states". Unrequired.
    let caption: String?
    /// §4 `progress` — "passed straight to C-057 in `Progress` / `Complete`; `Complete` pins
    /// 1.0 whatever is passed; ignored in `Condensed`, `Enrolled` and `Program`". Required.
    let progress: Double
    /// §4 `metaChips` — "the chip row, in order. Ignored in `Program`". Required.
    let metaChips: [Chip]
    /// §4 `cover` — "the 88×64 portrait the 64×64 box crops, resolved by the caller (R-19 /
    /// R-32 … the row does no loading). `nil` → the ruled missing-cover box". Unrequired.
    let cover: Image?
    /// §4 `onTap` — "the row's one action (R-03). A no-op means no gesture, no pressed
    /// feedback, no button trait". A closure cannot be compared against `{}`, so the no-op
    /// default is spelled as the initializer that takes no `onTap`: `nil` here is that default.
    private let onTap: (() -> Void)?

    /// The row with §4's no-op `onTap` — §3c: "a caller that leaves it wires no gesture and no
    /// pressed feedback" (members-profile's Engagement rows).
    init(
        state: State,
        title: String,
        description: String? = nil,
        caption: String? = nil,
        progress: Double,
        metaChips: [Chip],
        cover: Image? = nil
    ) {
        self.state = state
        self.title = title
        self.description = description
        self.caption = caption
        self.progress = progress
        self.metaChips = metaChips
        self.cover = cover
        self.onTap = nil
    }

    /// The tappable row — §3c: enrollments-home's tap that pushes `enrollment-home`.
    init(
        state: State,
        title: String,
        description: String? = nil,
        caption: String? = nil,
        progress: Double,
        metaChips: [Chip],
        cover: Image? = nil,
        onTap: @escaping () -> Void
    ) {
        self.state = state
        self.title = title
        self.description = description
        self.caption = caption
        self.progress = progress
        self.metaChips = metaChips
        self.cover = cover
        self.onTap = onTap
    }

    var body: some View {
        Group {
            if let onTap {
                // §2 Pressed (OQ-C-059-7): "the whole row at 0.6 opacity for the duration of
                // the touch, when `onTap` is wired". §2 Accessibility (R-17): "one element —
                // label = `title`, trait `.isButton`; the chips and bar are children of that
                // element, not separately focusable" (§2: "the chips, bar and caption").
                SwiftUI.Button(action: onTap) {
                    content
                }
                .buttonStyle(RowPressedStyle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isButton)
            } else {
                content
            }
        }
        .ui2Element("StudyProgramRow")     // capture element map — UI2Element.swift
    }

    /// §2 Root: "fills the width it is given … `space-card-padding` (16) top and bottom …
    /// content clipped". §2 Content row: "`space-card-padding` (16) gap, top-aligned: Details
    /// column (flexible) + Image (fixed)".
    private var content: some View {
        HStack(alignment: .top, spacing: Token.Space.cardPadding) {
            details
            image
        }
        .ui2Element("Content row")
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
    }

    // MARK: - Details

    /// §2 Details column — flexible; its gap is the per-variant "Details gap": 16 in
    /// `Condensed`, `space-element-gap` (8) in `Progress` / `Complete` / `Enrolled` / `Program`.
    @ViewBuilder
    private var details: some View {
        switch state {
        case .condensed:
            VStack(alignment: .leading, spacing: Token.Space.cardPadding) {
                // §2 `Condensed`: the description sits "`space-element-gap` (8) under the
                // title inside an Info sub-stack".
                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    titleText
                    if let description {
                        descriptionText(description)
                    }
                }
                .ui2Element("Info")
                chipRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Details")
        case .progress, .complete:
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleText
                // §2: C-057 PercentBar `size=sm, align=left`, 328×2 at the designed 408 —
                // "this row passes `progress` only" (§5): no colour, band or threshold, so the
                // fill is C-057's own ramp (deviation 9 retires the `#4deb4b` literal).
                // `Complete` pins 1.0 (deviation 5).
                PercentBar(
                    progress: state == .complete ? 1 : progress,
                    size: .sm,
                    aligned: .left
                )
                .frame(maxWidth: .infinity)
                chipRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Details")
        case .enrolled:
            // §2 `Enrolled` (D53): description "8 under the title; no C-057 PercentBar", then
            // the chip row — the 8 above it derived from groups-detail's 132pt row and ratified
            // by OQ-C-059-002.
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleText
                if let description {
                    descriptionText(description)
                }
                chipRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Details")
        case .program:
            // §2 `Program` (D59): description "single line, ellipsized", then the caption —
            // "no C-043 chip, no C-057 bar"; "a nil `description` or `caption` drops its line
            // and its gap" (column 20 + 8 + 20 + 8 + 20 = 76).
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleText
                if let description {
                    singleLineDescriptionText(description)
                }
                if let caption {
                    captionText(caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Details")
        }
    }

    /// §2 Title: `type-title-card` (Bold 14/20) `color-text-primary`, "single line,
    /// ellipsized, full width". The 20pt line box is pinned — SwiftUI's lineSpacing does
    /// nothing to a single line, and §2's 88 / 62 column arithmetic counts it as 20.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.titleCard)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
            .ui2Element("Title")
    }

    /// §2 `Condensed` / `Enrolled` description: `type-page-title` (Regular 14/20) in `color-text-secondary`
    /// (ruled OQ-C-059-5; Figma still binds `White/50%` — deviation 8), "wraps (no ellipsis)".
    /// One line keeps the 20pt box; more lines grow the row.
    private func descriptionText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.pageTitle)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, minHeight: Self.lineBox(Token.TypeStyle.pageTitle), alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .ui2Element("Description")
    }

    /// §2 `Program` description: `type-page-title` (Regular 14/20) `color-text-secondary`,
    /// "single line, ellipsized (unlike `Condensed`/`Enrolled`)", in the 20pt line box.
    private func singleLineDescriptionText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.pageTitle)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.pageTitle))
            .ui2Element("Description")
    }

    /// §2 `Program` caption: "the `caption` string as plain text, `color-accent`, single line,
    /// ellipsized, 20pt line box" — `type-page-title` (Regular 14/20), ratified by the owner in
    /// OQ-C-059-004 (2026-10-20).
    private func captionText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.pageTitle)
            .foregroundStyle(Token.accent)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.pageTitle))
            .ui2Element("Caption")
    }

    /// §2 chip row: "`space-chip-gap` (2): C-043 MetaChip × n" — whatever `metaChips` the
    /// caller passes, in order, each at its hug width (§3a: "the counts above are what the
    /// symbols demonstrate, not a limit").
    private var chipRow: some View {
        HStack(alignment: .center, spacing: Token.Space.chipGap) {
            ForEach(Array(metaChips.enumerated()), id: \.offset) { index, chip in
                MetaChip(value: chip.value, label: chip.label, state: chip.state, labelPosition: chip.align)
                    .ui2Element("Chip \(index + 1)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .ui2Element("Chip row")
    }

    // MARK: - Image

    /// §2 Image: "64×64, `radius-card` (8), clipped; the source is an 88×64 portrait centred
    /// inside it (offset −12 on y) — the box crops, it does not letterbox". The 64×88 child
    /// centred in the 64×64 frame IS the −12 offset. Missing cover (ruled, OQ-C-059-7; glyph
    /// added by owner ruling 2026-10-28): "the 64×64 box keeps its `color-white-10` fill … and
    /// draws the Lucide `image` glyph centred in it, `color-white-50`, sized at 60% of the box".
    private var image: some View {
        ZStack {
            if let cover {
                cover
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.imageSide, height: Self.portraitHeight)
            } else {
                Token.white10
                missingCoverGlyph
            }
        }
        .frame(width: Self.imageSide, height: Self.imageSide)
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        .ui2Element("Image")
    }

    /// §2 missing cover — "the same glyph and treatment as C-038 Avatar's `fallbackGlyph:
    /// .image`": the library `image` imageset drawn at the ratio, as C-038 draws it. §2
    /// Accessibility: "The missing-cover glyph is decorative (hidden from accessibility)".
    private var missingCoverGlyph: some View {
        Image(GlyphName.image.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.imageSide * Self.glyphRatio, height: Self.imageSide * Self.glyphRatio)
            .foregroundStyle(Token.white50)
            .accessibilityHidden(true)
            .ui2Element("Glyph")
    }

    // GAP — C-059 §2: "Image | 64×64 … the source is an 88×64 portrait" — part footprints
    // the contract states, with no size token in the register (the spacing family has no
    // vocabulary for a part's footprint; C-054 / C-033 treat their 64 the same way).
    private static let imageSide: CGFloat = 64
    private static let portraitHeight: CGFloat = 88
    // GAP — C-059 §2 missing cover: "sized at 60% of the box" — a ratio, as C-038's glyphRatio.
    private static let glyphRatio: CGFloat = 0.6

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}

/// §2 Pressed (ruled, OQ-C-059-7): "the whole row at 0.6 opacity for the duration of the
/// touch" — ephemeral, the button's own pressed flag (R-02). No disabled look ("not offered").
private struct RowPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // GAP — C-059 §2 Pressed: 0.6 opacity, no opacity token (C-054 spends the same 0.6).
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
