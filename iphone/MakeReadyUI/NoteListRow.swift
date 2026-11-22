//
//  NoteListRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-005-note-list-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-005 NoteListRow — "one note in the leader's All-Notes list": a leading C-038 note avatar,
/// then title + accent date / preview / context line naming the linked item (library-home §2).
///
/// Stateless and controlled (R-01, R-02, R-04): everything it shows is derived by the caller
/// (N11 title/preview, N12 date formatting, N3 link name); the row only lays it out and
/// reports a tap through `onTap`.
///
/// Chrome-free and width-driven (R-16; deviation 4): it fills the width it is given and states
/// its own intrinsic height. library-home change (house list page): the row takes the house
/// list-row look of C-037 / C-059 — their type scale, vertical insets and row-height rhythm — and
/// no longer sits in an Apple-Notes card; the page margin and the C-088 hairline between rows
/// belong to the consuming screen.
struct NoteListRow: View {

    /// §4 `title` — "Line 1: the note's first non-empty line, markdown-stripped, ≤ 120 chars".
    let title: String
    /// §4 `preview` — "Line 2 after the date … `nil` shows the date alone". Required, no default.
    let preview: String?
    /// §4 `dateLabel` — "`updatedAt` already formatted by the caller (N12)" — line 1 trailing, accent (library-home §2).
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

    /// House list-row band (C-037 §2, as members-home's `subject=member` rows): a leading C-038
    /// Avatar, then the text column, `space-card-padding` (16) between them, vertically centred,
    /// vertical inset `space-card-padding` (16) top and bottom. No horizontal inset of its own (the
    /// page margin is the screen's). The row paints no background (R-16).
    private var lines: some View {
        // FLAGGED (D7) — C-037 §2: the 16 band gap is cited as `space-card-padding` (value-equal).
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            leadingAvatar
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleLine
                // library-home §2: "A note with no body text has no line 2, and its row is shorter."
                if let preview {
                    previewText(preview)
                }
                // §2 Line 3: "With no `contextLabel`, the line … [is] absent" — an absent child adds
                // no stack spacing (here `space-element-gap`).
                if let contextLabel {
                    contextText(contextLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// library-home §2 "Leading icon avatar": "a C-038 Avatar at 32 pt, round, exactly like the
    /// member rows … A note uses the `note` fallback glyph (`notebook-pen`) … on the Initials
    /// ground, with no photo or initials." Decorative (§3 Accessibility).
    private var leadingAvatar: some View {
        Avatar(imageURL: nil, initials: nil, size: Self.avatarSize, fallbackGlyph: .note)
            .accessibilityHidden(true)
            .ui2Element("Leading")
    }

    /// library-home §2 Line 1: "the title on the left (one line, truncating) and the date label on
    /// the right, in `color-accent`".
    private var titleLine: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(title)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
            Text(dateLabel)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .ui2Element("Date")
        }
        .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
        .ui2Element("Title line")
    }

    /// library-home §2 Line 2: "one line, truncating, with no date in front: the first line of the
    /// note's body text after the title".
    private func previewText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
            .ui2Element("Preview")
    }

    /// Line 3: `contextLabel` on the house type scale (C-037 §2 Detail: `type-body-sm`),
    /// `color-text-secondary`, one line, tail-truncated — text only, no folder glyph (deviation 1).
    private func contextText(_ label: String) -> some View {
        Text(label)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
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

    /// library-home §2: "a C-038 Avatar at 32 pt" — members-home's member-row diameter.
    static let avatarSize: CGFloat = 32
}
