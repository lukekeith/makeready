//
//  EmptyState.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-132-empty-state in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-132 EmptyState — "a centred glyph disc, title and wrapping message that fills an otherwise
/// empty page — first drawn as the Library tab's "coming soon" placeholder".
///
/// §2: "A vertical stack, centred horizontally, inset `space-section-gap` (32) on all four sides.
/// Width-driven (R-16) … It paints no background. The 32pt inset is the component's own anatomy
/// (Figma `p-32`), not outer padding." Intrinsic height at 408 wide = 32 + 64 + 32 + 24 + 8 + 72
/// + 32 = 264. Placement on the page is the screen's call.
struct EmptyState: View {

    /// §4 `glyph` — "the library glyph in the disc". Required (R-07).
    let glyph: GlyphName
    /// §4 `title` — "the one-line headline, verbatim". Required (R-07).
    let title: String
    /// §4 `message` — "the supporting copy, verbatim and wrapping". Required (R-07).
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            disc
            titleText
                // §2: gap `space-section-gap` (32) below the disc.
                .padding(.top, Token.Space.sectionGap)
            messageText
                // §2: gap `space-element-gap` (8) below the title.
                .padding(.top, Token.Space.elementGap)
        }
        // §2: "inset `space-section-gap` (32) on all four sides" — the component's own anatomy.
        .padding(Token.Space.sectionGap)
        .frame(maxWidth: .infinity)
        // §2 Accessibility (R-17): "not interactive. The title and message read as one static
        // element, "<title>. <message>". The glyph and disc are decorative".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
        .ui2Element("EmptyState")                 // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Glyph disc: "a 64×64 circle …, `radius-circle`, fill `color-white-10`, no ring. Centred
    // inside it is the `glyph` at 48×48 …, template-tinted `color-white-50`." `radius-circle` is
    // "50%" and emits no member, so the shape names it. OQ-C-132-001 (closed): the disc is inline
    // anatomy of this row, not a registry part.
    private var disc: some View {
        ZStack {
            Circle()
                .fill(Token.white10)
            // `Glyph` offers only 16 / 24 / 32, so the imageset is sized here directly (the C-123
            // TaskDisc construction).
            Image(glyph.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.glyphSize, height: Self.glyphSize)
                .foregroundStyle(Token.white50)
                .ui2Element("Glyph")
        }
        .frame(width: Self.discDiameter, height: Self.discDiameter)
        .accessibilityHidden(true)
        .ui2Element("Glyph disc")
    }

    // §2 Title: "`type-input` (SF Pro Regular 14/24), `color-white-100`, centred, one line".
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.input)
            .foregroundColor(Token.white100)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            // SwiftUI has no line-height for a single line: the designed 24pt line box is pinned
            // as a frame (the SectionHeader construction).
            .frame(height: Self.lineBox)
            .ui2Element("Title")
    }

    // §2 Message: "`type-input` (SF Pro Regular 14/24), `color-text-secondary` (deviation 1),
    // centred. It wraps with no line limit within the width less 2 × 32."
    // Not `designTextStyle`: its lineSpacing (24 − 14) is added to SF Pro's natural ~16.7 line, a
    // 26.7pt pitch. Spend only the line box less the natural line height — between lines, and half
    // above / half below — so n lines are exactly n × 24 (the C-124 / C-047 construction).
    private var messageText: some View {
        Text(message)
            .font(Token.TypeStyle.input.font)
            .tracking(Token.TypeStyle.input.tracking)
            .lineSpacing(Self.messageLeading)
            .padding(.vertical, Self.messageLeading / 2)
            .foregroundColor(Token.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            // The capture harness measures with a NUMERIC height proposal; `fixedSize` makes the
            // text size to its own lines.
            .fixedSize(horizontal: false, vertical: true)
            .ui2Element("Message")
    }

    // `type-input`'s designed 24pt line box.
    private static let lineBox: CGFloat =
        Token.TypeStyle.input.lineHeight ?? Token.TypeStyle.input.size

    private static let messageLeading: CGFloat = {
        let natural = UIFont.systemFont(ofSize: Token.TypeStyle.input.size, weight: .regular).lineHeight
        return max(lineBox - natural, 0)
    }()

    // FLAGGED LITERAL — C-132 §2: "a 64×64 circle (⚠️ flagged literal 64 — no size token; same
    // value as C-123 TaskDisc)".
    private static let discDiameter: CGFloat = 64
    // FLAGGED LITERAL — C-132 §2: "the `glyph` at 48×48 (⚠️ flagged literal 48)".
    private static let glyphSize: CGFloat = 48
}
