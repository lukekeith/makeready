//
//  NoteSectionHeader.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-010-note-section-header in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-010 NoteSectionHeader — "the date-bucket label above a run of notes": a flush-left section
/// label (`Today`, `Previous 7 Days`, …) between runs of C-005 NoteListRow in the leader's
/// All-Notes list.
///
/// Stateless (R-01, R-02) with no actions (R-03). The bucket and its label are the caller's
/// (DECISIONS N12): the header does no date bucketing or formatting (R-04, R-19, R-25).
///
/// Chrome-free and width-driven (R-16; §1 deviation 3): it fills the width it is given and its
/// intrinsic height is the 24 pt line box. The page-margin inset and the gaps above and below
/// belong to the consuming screen.
struct NoteSectionHeader: View {

    /// §4 `title` — "The bucket label … computed by the caller from `updatedAt` (N12). Single
    /// line, tail-truncates." Required (R-07).
    let title: String

    var body: some View {
        // §2 Title: "`type-section-title` (SF Pro Semibold 18/24), `color-text-primary`, single
        // line with no wrap, tail-truncated with an ellipsis." (§1 deviation 1: the token, not
        // the measured ~22 pt Bold.)
        Text(title)
            .designTextStyle(Token.TypeStyle.sectionTitle)
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            // SwiftUI has no line-height: `designTextStyle` spells the leading as lineSpacing,
            // which does nothing to one line, so §2's "intrinsic height is the line box: 24 pt"
            // is pinned as a frame, as C-020 does for the same face.
            .frame(height: Token.TypeStyle.sectionTitle.lineHeight ?? Token.TypeStyle.sectionTitle.size)
            // §2 Container: "one text line, leading-aligned, filling the width it is given".
            .frame(maxWidth: .infinity, alignment: .leading)
            // §2 Accessibility (R-17): "static text with the `.isHeader` trait".
            .accessibilityAddTraits(.isHeader)
            .ui2Element("Title")
            .ui2Element("NoteSectionHeader")          // capture element map — UI2Element.swift
    }
}
