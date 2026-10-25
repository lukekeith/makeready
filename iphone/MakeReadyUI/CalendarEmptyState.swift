//
//  CalendarEmptyState.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-122-calendar-empty-state in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-122 CalendarEmptyState — "the centred search glyph, title and message shown when calendar
/// search has nothing to list".
///
/// §2: "A centred vertical stack; width-driven (R-16) — fills the width given and centres its
/// content; no background. Intrinsic height 40 + 24 + 22 + 4 + 18 = **108** (one-line
/// message)." Placement (120 pt below the search field) is the screen's.
struct CalendarEmptyState: View {

    /// §4 `title` — "the headline ("No Results" / "Search unavailable") — the screen chooses by
    /// state".
    let title: String
    /// §4 `message` — "the supporting line".
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            glyph
            titleText
                // §2 Title: "`space-row-gap` (24) below the glyph".
                .padding(.top, Token.Space.rowGap)
            messageText
                // §2 Message: "`space-meta-gap` (4) below the title".
                .padding(.top, Token.Space.metaGap)
        }
        .frame(maxWidth: .infinity)
        // §2 Accessibility (R-17): "non-interactive; one static element "<title>. <message>";
        // the glyph is decorative (hidden)".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
        .ui2Element("CalendarEmptyState")             // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Glyph: "`search-carbon`, **40 × 40** …, tint `color-white-50`, centred". No
    // `GlyphSize` case is 40, so the imageset is sized here directly (the KeypadKey construction).
    private var glyph: some View {
        Image(GlyphName.searchCarbon.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .foregroundStyle(Token.white50)
            .accessibilityHidden(true)
            .ui2Element("Glyph")
    }

    // §2 Title: "SF Pro **Semibold 17**, line 22 …, `color-white-100`, centred, one line".
    private var titleText: some View {
        Text(title)
            .designTextStyle(Self.titleStyle)
            .foregroundColor(Token.white100)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            // SwiftUI has no line-height for a single line: the designed 22pt line box is pinned
            // as a frame (the SectionHeader construction).
            .frame(height: Self.titleStyle.lineHeight ?? Self.titleStyle.size)
            .ui2Element("Title")
    }

    // §2 Message: "`type-footnote` (SF Pro Text Regular 13/18), `color-white-50`, centred, wraps
    // (no line limit) within the width less 2 × `space-page-margin`".
    private var messageText: some View {
        Text(message)
            .designTextStyle(Token.TypeStyle.footnote)
            .foregroundColor(Token.white50)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: Token.TypeStyle.footnote.lineHeight ?? Token.TypeStyle.footnote.size)
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("Message")
    }

    // FLAGGED LITERAL — C-122 §2: the glyph's "**40 × 40** (FLAGGED LITERAL, 02-design §6.2)".
    private static let glyphSize: CGFloat = 40

    // FLAGGED LITERAL — C-122 §2: the title's "SF Pro **Semibold 17**, line 22 (FLAGGED LITERAL
    // type — `type-title-tile` is Bold 17, not semibold)".
    private static let titleStyle = DesignTextStyle(
        weight: .semibold, size: 17, lineHeight: 22, tracking: 0
    )
}
