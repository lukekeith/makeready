//
//  MemoListRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-006-memo-list-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-006 MemoListRow — "one voice memo in the leader's Library list, sitting beside C-005
/// NoteListRow rows in the same date sections": line 1 is a mic glyph, the title and the
/// duration; line 2 is the date and a preview slot that tracks the memo's transcript state.
///
/// Stateless and controlled (R-01, R-02, R-04): the caller formats the duration and the date
/// and maps `transcriptStatus` / the upload queue to `preview`; the row only lays it out and
/// reports a tap through `onTap` (the caller pushes memo-detail, D4).
///
/// Chrome-free and width-driven (R-16; deviation 3): it fills the width it is given and states
/// its own intrinsic height. The section card's fill, radius, separators and gap belong to the
/// consuming screen.
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
    /// §4 `dateLabel` — "Line 2 leading: `recordedAt` formatted by the caller (notes rule)".
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

    /// §2 Container: "a vertical stack, leading-aligned. Horizontal inset `space-card-padding`
    /// (16) on both sides, vertical inset `space-step-12` top and bottom, and `space-step-2`
    /// between the lines. The row paints no background (R-16)."
    private var lines: some View {
        VStack(alignment: .leading, spacing: Token.Space.step2) {
            titleLine
            dateLine
        }
        .padding(.horizontal, Token.Space.cardPadding)
        .padding(.vertical, Token.Space.step12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// §2 Line 1: "a horizontal stack in a `type-callout-bold` line box (21 pt)".
    private var titleLine: some View {
        HStack(spacing: 0) {
            // §2 Mic glyph (OQ-C-006-2): "`microphone`, 16×16, tinted `color-text-secondary`,
            // vertically centred on the title line, with `space-meta-gap` (4) to the title".
            Glyph(.microphone, size: .sm, tint: Token.textSecondary)
                .ui2Element("Mic glyph")
            Text(title)
                .designTextStyle(Token.TypeStyle.calloutBold)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Token.Space.metaGap)
                .ui2Element("Title")
            // §2 Duration: "`type-body-sm`, `color-text-secondary`, with monospaced digits. It is
            // right-aligned, has `space-element-gap` (8) before it, and never truncates or
            // compresses."
            Text(durationLabel)
                .designTextStyle(Token.TypeStyle.bodySm)
                .monospacedDigit()
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .padding(.leading, Token.Space.elementGap)
                .ui2Element("Duration")
        }
        .frame(height: Self.lineBox(Token.TypeStyle.calloutBold))
        .ui2Element("Title line")
    }

    /// §2 Line 2 (OQ-C-006-3): "a horizontal stack with `space-element-gap` (8) between its parts
    /// and no dot, exactly as C-005's line 2".
    private var dateLine: some View {
        HStack(spacing: Token.Space.elementGap) {
            Text(dateLabel)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .ui2Element("Date")
            Text(previewText)
                .designTextStyle(Token.TypeStyle.bodySm)
                // FLAGGED — C-006 §2: italic applied to `type-body-sm` for `.transcribing`, a
                // style modifier with no italic token.
                .italic(isTranscribing)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element(isTranscript ? "Preview" : "Status")
        }
        .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
        .ui2Element("Date line")
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
