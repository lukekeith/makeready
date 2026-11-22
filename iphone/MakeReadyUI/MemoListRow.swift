//
//  MemoListRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-006-memo-list-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-006 MemoListRow — "one voice memo in the leader's Library list, sitting beside C-005
/// NoteListRow rows in the same date sections": a leading C-038 microphone avatar, then line 1 is
/// the title and the accent `date · duration` label; line 2 is a preview slot that tracks the
/// memo's transcript state (library-home §2).
///
/// Stateless and controlled (R-01, R-02, R-04): the caller formats the duration and the date
/// and maps `transcriptStatus` / the upload queue to `preview`; the row only lays it out and
/// reports a tap through `onTap` (the caller pushes memo-detail, D4).
///
/// Chrome-free and width-driven (R-16; deviation 3): it fills the width it is given and states
/// its own intrinsic height. library-home change (house list page): the same house list-row look
/// as C-005 — C-037 / C-059's type scale, vertical insets and row-height rhythm, no card; the page
/// margin and the C-088 hairline between rows belong to the consuming screen. The four preview
/// states are unchanged.
struct MemoListRow: View {

    /// §4 `preview` — "Line 2 slot: `.transcript(String)` · `.transcribing` · `.audioOnly` ·
    /// `.waitingToUpload`" (R-06, R-36: a nested enum).
    enum Preview {
        case transcript(String)
        case transcribing
        case audioOnly
        case waitingToUpload
    }

    /// §4 `title` — "Line 1: the memo's title (auto `Memo {n}` or the leader's rename)".
    let title: String
    /// §4 `durationLabel` — "Line 1 trailing: the duration already formatted by the caller".
    let durationLabel: String
    /// §4 `dateLabel` — "`recordedAt` formatted by the caller (notes rule)" — line 1 trailing, before the duration (library-home §2).
    let dateLabel: String
    /// §4 `preview` — the line 2 slot.
    let preview: Preview
    /// §4 `onTap` — "The whole row was tapped. The caller pushes `memo-detail`". R-03 no-op default.
    var onTap: () -> Void = {}

    var body: some View {
        // §2 Hit target: "the whole row is one button and delivers `onTap`. Press feedback is the
        // system highlight" (deviation 4) — the plain button style's ephemeral press (R-02).
        SwiftUI.Button(action: onTap) {
            lines
        }
        .buttonStyle(.plain)
        // R-17 / §2 Accessibility: "one combined element, trait `.isButton`".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityPhrase)
        .accessibilityAddTraits(.isButton)
        .ui2Element("MemoListRow")             // capture element map — UI2Element.swift
    }

    /// House list-row band (C-037 §2, as C-005): a leading C-038 Avatar, then the text column,
    /// `space-card-padding` (16) between them, vertically centred, vertical inset
    /// `space-card-padding` (16) top and bottom and `space-element-gap` (8) between the lines. No
    /// horizontal inset of its own (the page margin is the screen's). The row paints no background
    /// (R-16).
    private var lines: some View {
        // FLAGGED (D7) — C-037 §2: the 16 band gap is cited as `space-card-padding` (value-equal).
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            leadingAvatar
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                titleLine
                previewLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// library-home §2 "Leading icon avatar": "a C-038 Avatar at 32 pt, round … a memo the
    /// `microphone` glyph, drawn on the Initials ground". Decorative (§3 Accessibility).
    private var leadingAvatar: some View {
        Avatar(imageURL: nil, initials: nil, size: NoteListRow.avatarSize, fallbackGlyph: .microphone)
            .accessibilityHidden(true)
            .ui2Element("Leading")
    }

    /// library-home §2 Line 1: "the title on the left (one line, truncating) and, on the right, the
    /// date label followed by the duration (`9:38 PM · 0:05`), the whole label in `color-accent` …
    /// The memo drops its inline mic glyph before the title, since the avatar says it is a memo."
    private var titleLine: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(title)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
            // §2 Duration keeps its monospaced digits; the label never truncates or compresses.
            Text("\(dateLabel) · \(durationLabel)")
                .designTextStyle(Token.TypeStyle.bodySm)
                .monospacedDigit()
                .foregroundStyle(Token.accent)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .ui2Element("Date")
        }
        .frame(height: Self.lineBox(Token.TypeStyle.titleCard))
        .ui2Element("Title line")
    }

    /// library-home §2 Line 2: "one line, truncating, with no date in front: the transcript
    /// preview, or the state text".
    private var previewLine: some View {
        Text(previewText)
            .designTextStyle(Token.TypeStyle.bodySm)
            // FLAGGED — C-006 §2: italic applied to `type-body-sm` for `.transcribing`, a
            // style modifier with no italic token.
            .italic(isTranscribing)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
            .ui2Element(isTranscript ? "Preview" : "Status")
    }

    /// §2 Preview slot: the transcript text as given, or the row's own fixed copy
    /// ("the three fixed strings are the row's own copy (brief §C-006)").
    private var previewText: String {
        switch preview {
        case .transcript(let text): return text
        case .transcribing: return "Transcribing…"
        case .audioOnly: return "Audio only"
        case .waitingToUpload: return "Waiting to upload"
        }
    }

    private var isTranscribing: Bool {
        if case .transcribing = preview { return true }
        return false
    }

    private var isTranscript: Bool {
        if case .transcript = preview { return true }
        return false
    }

    /// R-17 / §2: "Its label is "Voice memo", title, duration, date and the preview slot's text in
    /// that order, comma-joined."
    private var accessibilityPhrase: String {
        ["Voice memo", title, durationLabel, dateLabel, previewText].joined(separator: ", ")
    }

    /// A single line's box is its style's line height — lineSpacing does nothing to one line,
    /// so the box is pinned to keep §2's line rhythm (as C-005 does).
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}
