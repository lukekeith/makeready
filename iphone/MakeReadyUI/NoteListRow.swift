//
//  NoteListRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-005-note-list-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-005 NoteListRow — "one note in the leader's All-Notes list": a 3-line row of title /
/// date + preview / context line naming the linked item.
///
/// Stateless and controlled (R-01, R-02, R-04): everything it shows is derived by the caller
/// (N11 title/preview, N12 date formatting, N3 link name); the row only lays it out and
/// reports a tap through `onTap`.
///
/// Chrome-free and width-driven (R-16; deviation 4): it fills the width it is given and states
/// its own intrinsic height. The section card's fill, radius, separators and section gap belong
/// to the consuming screen.
struct NoteListRow: View {

    /// §4 `title` — "Line 1: the note's first non-empty line, markdown-stripped, ≤ 120 chars".
    let title: String
    /// §4 `preview` — "Line 2 after the date … `nil` shows the date alone". Required, no default.
    let preview: String?
    /// §4 `dateLabel` — "Line 2 leading: `updatedAt` already formatted by the caller (N12)".
    let dateLabel: String
    /// §4 `contextLabel` — "Line 3: the name of the note's linked item … `nil` removes line 3".
    /// Required, no default.
    let contextLabel: String?
    /// §4 `onTap` — "The whole row was tapped. The caller opens the editor". R-03 no-op default.
    var onTap: () -> Void = {}

    var body: some View {
        // §2 Hit target: "the whole row is one button … Press feedback is the system highlight
        // over the full row rect with no geometry change" (deviation 5) — the plain button
        // style's ephemeral press (R-02).
        SwiftUI.Button(action: onTap) {
            lines
        }
        .buttonStyle(.plain)
        // R-17 / §2 Accessibility: "one combined element, trait `.isButton`".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPhrase)
        .accessibilityAddTraits(.isButton)
        .ui2Element("NoteListRow")             // capture element map — UI2Element.swift
    }

    /// §2 Container: "a vertical stack, leading-aligned. Horizontal inset `space-card-padding`
    /// (16) on both sides, vertical inset `space-step-12` top and bottom, and `space-step-2`
    /// between lines. The row paints no background (R-16)."
    private var lines: some View {
        VStack(alignment: .leading, spacing: Token.Space.step2) {
            titleText
            dateLine
            // §2 Line 3: "With no `contextLabel`, the line and the `space-step-2` gap above it
            // are absent" — an absent child adds no stack spacing.
            if let contextLabel {
                contextText(contextLabel)
            }
        }
        .padding(.horizontal, Token.Space.cardPadding)
        .padding(.vertical, Token.Space.step12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// §2 Line 1: "`type-callout-bold`, `color-text-primary`, one line, tail-truncated".
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.calloutBold)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.lineBox(Token.TypeStyle.calloutBold))
            .ui2Element("Title")
    }

    /// §2 Line 2: "a horizontal stack with `space-element-gap` (8) between its parts.
    /// `dateLabel` … never truncates or compresses. `preview` … one line, tail-truncated, and
    /// takes the remaining width. With no preview, line 2 is the date alone."
    private var dateLine: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(dateLabel)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .ui2Element("Date")
            if let preview {
                Text(preview)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ui2Element("Preview")
            }
        }
        .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
        .ui2Element("Date line")
    }

    /// §2 Line 3: "`contextLabel` in `type-footnote` `color-text-secondary`, one line,
    /// tail-truncated" — text only, no folder glyph (deviation 1).
    private func contextText(_ label: String) -> some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.footnote)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.lineBox(Token.TypeStyle.footnote))
            .ui2Element("Context")
    }

    /// R-17 / §2: "Its label is title, date, preview and context in that order, comma-joined,
    /// with absent parts skipped."
    private var accessibilityPhrase: String {
        [title, dateLabel, preview, contextLabel].compactMap { $0 }.joined(separator: ", ")
    }

    /// A single line's box is its style's line height — lineSpacing does nothing to one line,
    /// so the box is pinned to keep §2's line rhythm.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}
