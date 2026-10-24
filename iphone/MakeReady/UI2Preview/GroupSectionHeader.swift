//
//  GroupSectionHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-058-group-section-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-058 GroupSectionHeader — "heads one group's block in the org-wide Enrollments directory:
/// the group's photo, the group's name over its leader's name, and a forward arrow that opens
/// the group."
///
/// §2: "The root is a row of **identity block** and **arrow**. It has no background, border or
/// outer padding (R-16), fills the width it is given (408 at design) and has an intrinsic height
/// of **42**." The call site owns the `space-page-margin` inset.
struct GroupSectionHeader: View {

    /// §4 `groupName` — "The group's name on one line, tail-truncated".
    let groupName: String
    /// §4 `leaderName` — "The group leader's display name, as the caller resolved it. The
    /// component adds no prefix".
    let leaderName: String
    /// §4 `imageURL` — "The group photo, passed to C-038 `imageURL`. `nil` falls through C-038's
    /// chain". Unrequired (R-07): optional because C-038's is.
    var imageURL: URL?
    /// §4 `initials` — "The fallback initials for C-038, derived by the caller from `groupName`".
    /// Unrequired (R-07): optional because C-038's is.
    var initials: String?
    /// §4 `onOpen` — "Called when the arrow is tapped. The screen decides the destination".
    /// C-021's `action`, with R-03's no-op default.
    var onOpen: () -> Void = {}

    /// §2 Avatar: "**C-038 Avatar** `size=40`". A diameter is C-038's `size` prop, not a
    /// spacing value, so it has no token row (the same way C-021's 24pt glyph box has none).
    private static let avatarSize: CGFloat = 40

    var body: some View {
        // §2 Root: "Horizontal stack, gap **8** (`space-element-gap`), cross-axis **centre**".
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            identityBlock
            arrow
        }
        .ui2Element("GroupSectionHeader")             // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    // §2 Identity block: "Horizontal stack, gap **16** (`space-card-padding`, value-equal, cited
    // as in C-037 and C-054), cross-axis centre. It fills the width left of the arrow".
    private var identityBlock: some View {
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            // C-038 names itself ("Avatar") in the element map; no second annotation here.
            Avatar(imageURL: imageURL, initials: initials, size: Self.avatarSize)
            textColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // §4 Accessibility: "The avatar and text column are one combined static element that
        // reads the group name, then the leader name." Static per OQ-C-058-2: only the arrow
        // opens the group.
        .accessibilityElement(children: .combine)
        .ui2Element("Identity block")
    }

    // §2 Text column: "Vertical stack, leading-aligned, gap **8** (`space-element-gap`), fills
    // the remaining width. Height 20 + 8 + 14 = **42**".
    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            // §2 Group name: "One line, tail-truncated … full column width" —
            // `type-title-card` (Bold 14/20), `color-text-primary`.
            Text(groupName)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundColor(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                // SwiftUI has no line-height; the designed 20pt line box is pinned as a frame,
                // the same construction C-032 uses.
                .frame(height: lineBox(Token.TypeStyle.titleCard))
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Group name")

            // §2 Leader name: "One line, tail-truncated" (§1 deviation 3, ratified by
            // OQ-C-058-3) — `type-body` (Regular 14/14).
            Text(leaderName)
                .designTextStyle(Token.TypeStyle.body)
                // OQ-C-058-1 (answered 2026-09-30): "Bind the leader name to
                // color-text-secondary … record it as a deviation from the White/50% binding."
                // §2 still reads `color-white-50`; the ruling wins.
                .foregroundColor(Token.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: lineBox(Token.TypeStyle.body))
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Leader name")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Text column")
    }

    // §2 Arrow: "**C-021 GlyphButton** `glyph=arrow-forward`, 24×24 layout box, trailing … Its
    // hit target is 44×44 (deviation 2)". C-021 already builds exactly that: an expanded content
    // shape around a 24pt layout box, so the row stays 42pt.
    private var arrow: some View {
        GlyphButton(glyph: .arrowForward, onTap: onOpen)
            // §4 Accessibility: "Its label is **\"Open \(groupName)\"** so the stacked sections
            // stay distinct, and it carries the `.isButton` trait."
            .accessibilityLabel("Open \(groupName)")
            .accessibilityAddTraits(.isButton)
            .ui2Element("Arrow")
    }

    private func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }
}
