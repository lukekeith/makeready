//
//  FollowedProgramHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-032-followed-program-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-032 FollowedProgramHeader — "a followed program's title, author · created byline, and
/// overflow action".
///
/// §2: "The root is a row: **text column** on the left, **overflow action** on the right. There
/// is no ground, border or shadow. The component paints no background and adds no outer padding
/// (R-16)." The call site owns the `space-page-margin` inset.
struct FollowedProgramHeader: View {

    /// §4 `title` — "The followed program's title, on one line, tail-truncated".
    let title: String
    /// §4 `author` — "The program author's display name, as the caller resolved it".
    let author: String
    /// §4 `createdLabel` — "The full created text, already formatted by the caller … The
    /// component adds neither the word \"Created\" nor any date formatting".
    let createdLabel: String
    /// §4 `onMenu` — "Called when the overflow action is tapped … The component never decides
    /// (R-03)". No-op default: the one unrequired prop (R-07).
    var onMenu: () -> Void = {}

    /// §2 separator dot: "4×4 circle … It never compresses". The contract names the size as
    /// part of the separator's shape ("the same way C-021's 24pt glyph box … [is] part of its
    /// shape"), not as a spacing value, so there is no token row for it.
    private static let dotSize: CGFloat = 4

    var body: some View {
        // §2 Root: "Horizontal stack, gap **8** (`space-element-gap`), fills the given width.
        // Cross-axis alignment is **top**: the button's top edge meets the title line's top
        // edge (ruled, OQ-C-032-001). Intrinsic height **40** = 16 + 8 + 16".
        HStack(alignment: .top, spacing: Token.Space.elementGap) {
            textColumn
            overflowAction
        }
        .ui2Element("FollowedProgramHeader")          // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Text column: "Vertical stack, leading-aligned, gap **8** (`space-element-gap`). Fills
    // the width left of the action (§1 dev. 1)".
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            titleText
            byline
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // §4 Accessibility: "The text column is one combined static element that reads title,
        // author and created label, in that order."
        .accessibilityElement(children: .combine)
        .ui2Element("Text column")
    }

    // §2 Title: "One line, tail-truncated" — `type-block-label` (Regular 14/16),
    // `color-text-primary`.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.blockLabel)
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            // SwiftUI has no line-height; the designed 16pt line box is pinned as a frame, the
            // same construction C-020 and C-022 use.
            .frame(height: lineBox(Token.TypeStyle.blockLabel))
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element("Title")
    }

    // §2 Byline: "Horizontal stack, center-aligned, gap **8** (`space-element-gap`),
    // leading-aligned in the column. It never wraps".
    private var byline: some View {
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            // §2 author: "When the byline does not fit, the **author** gives up width and
            // tail-truncates (ruled, OQ-C-032-003)".
            Text(author)
                .designTextStyle(Token.TypeStyle.byline)
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: lineBox(Token.TypeStyle.byline))
                .ui2Element("Author")

            // §2 separator dot: "4×4 circle, vertically centred on the 16pt line. It never
            // compresses" — filled `color-text-secondary`.
            Circle()
                .fill(Token.textSecondary)
                .frame(width: Self.dotSize, height: Self.dotSize)
                .fixedSize()
                .ui2Element("Separator dot")

            // §2 created label: "One line, **never truncated**: it keeps its full width at the
            // author's expense (ruled, OQ-C-032-003)".
            Text(createdLabel)
                .designTextStyle(Token.TypeStyle.byline)
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .fixedSize()
                .frame(height: lineBox(Token.TypeStyle.byline))
                .layoutPriority(1)
                .ui2Element("Created label")
        }
        .ui2Element("Byline")
    }

    // §2 Overflow action: "**C-021 GlyphButton** `glyph=three-dots`, 24×24 visual box,
    // trailing. Its hit target is **44×44** … the layout box stays 24×24, so the row stays 40pt
    // tall (ruled, OQ-C-032-002)". C-021 already builds exactly that: an expanded content
    // shape around a 24pt layout box.
    private var overflowAction: some View {
        GlyphButton(glyph: .threeDots, action: onMenu)
            // §4 Accessibility (ruled, OQ-C-032-004): "More options for \(title)" with the
            // `.isButton` trait.
            .accessibilityLabel("More options for \(title)")
            .accessibilityAddTraits(.isButton)
            .ui2Element("Overflow action")
    }

    private func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
