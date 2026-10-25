//
//  InviteStatusRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-089-invite-status-row in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-089 InviteStatusRow — "one sent invite: recipient, status, group and date, with a push
/// chevron".
///
/// Chrome-free and width-driven (R-16): §2 "fills the width it is given (408 in the frame);
/// intrinsic height **80**. No background, no border, no divider, no horizontal padding — the
/// call site's list owns the inset."
///
/// §4, in the rulebook's shape: R-05 flat parameters in the contract's order, R-07 all
/// required except `onTap`, R-03/R-33 one `onTap` closure with a no-op default, R-04 no
/// navigation of its own — the caller pushes `invite-home`.
struct InviteStatusRow: View {

    /// §4 `status` — "nested enum (R-06, R-36) `sent · requested · accepted · rejected ·
    /// expired`. The component owns the word for each case."
    enum Status: String {
        case sent
        // §3 `requested` (owner-ruled 2026-10-18): undesigned; geometry identical.
        case requested
        case accepted
        case rejected
        case expired

        /// §3 Word column. `sent` renders "Sent" for the Figma `state=Pending` (deviation 1).
        var word: String {
            switch self {
            case .sent: return "Sent"
            case .requested: return "Requested"
            case .accepted: return "Accepted"
            case .rejected: return "Rejected"
            case .expired: return "Expired"
            }
        }

        /// §3 Word tone column. `expired` is `color-neutral-200` per OQ-invites-home-001
        /// (deviation 2).
        var tone: Color {
            switch self {
            case .sent, .expired: return Token.neutral200
            // §3 `requested` word tone: "blue 400 (`color-blue-400`; the existing blue-400
            // token — none minted)" (owner-ruled 2026-10-18).
            case .requested: return Token.blue400
            case .accepted: return Token.positive
            case .rejected: return Token.negative
            }
        }
    }

    /// §4 `recipient` — "already formatted by the caller" (OQ-C-089-3: the member's full name
    /// when linked, otherwise the formatted phone; the row has no fallback logic of its own).
    let recipient: String
    /// §4 `status` — selects the status word and its tone (§3).
    let status: Status
    /// §4 `groupName` — the description line's leading text.
    let groupName: String
    /// §4 `date` — the description line's trailing text, already formatted by the caller.
    let date: String
    /// §4 `onTap` — "The whole row was tapped (R-03, R-33)". R-03's no-op default.
    var onTap: () -> Void = {}

    var body: some View {
        // OQ-C-089-2 (owner, 2026-10-03): "the system highlight over the whole row, no
        // geometry change; the chevron has no separate pressed look" — the plain button
        // style's ephemeral press (R-02).
        SwiftUI.Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        // §4 Accessibility (R-17): "the row is one element … labelled `"<recipient>, <status
        // word>, <groupName>, <date>"` with the `.isButton` trait".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(recipient), \(status.word), \(groupName), \(date)")
        .accessibilityAddTraits(.isButton)
        .ui2Element("InviteStatusRow")         // capture element map — UI2Element.swift
    }

    /// §2 Content: "HStack, centre-aligned, gap **16** — `space-card-padding`, the same 16 the
    /// row pads with": the info column (flexes) then the chevron. Root: "vertical padding
    /// `space-card-padding` (16) top and bottom; horizontal 0".
    private var content: some View {
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            info
            chevron
        }
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2: "Hit target: the whole row (80 tall, full width) is one button."
        .contentShape(Rectangle())
        .ui2Element("Content")
    }

    /// §2 Info column: "VStack, leading, gap `space-element-gap` 8, two lines of equal anatomy".
    private var info: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            titleLine
            descriptionLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Info column")
    }

    /// §2 Title line: "`recipient` — flexes, single line, tail-truncated, `color-neutral-100`;
    /// then the status word — intrinsic width, never truncates, tone per §3".
    private var titleLine: some View {
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            line(recipient, tint: Token.neutral100, flexes: true)
                .ui2Element("Recipient")
            line(status.word, tint: status.tone, flexes: false)
                .ui2Element("Status word")
        }
        .frame(height: Self.lineBox)
        .ui2Element("Title line")
    }

    /// §2 Description line: "`groupName` — flexes, single line, tail-truncated; then `date` —
    /// intrinsic width, single line, never wraps".
    private var descriptionLine: some View {
        HStack(alignment: .center, spacing: Token.Space.elementGap) {
            // OQ-C-089-001 (owner, 2026-10-03): "Unify on `color-text-secondary` in every
            // status" — overrides §2/§3's as-designed `color-white-50` for accepted/rejected.
            line(groupName, tint: Token.textSecondary, flexes: true)
                .ui2Element("Group name")
            line(date, tint: Token.textSecondary, flexes: false)
                .ui2Element("Date")
        }
        .frame(height: Self.lineBox)
        .ui2Element("Description line")
    }

    /// §2: "All four texts: `type-body-sm` (SF Pro Regular 14 / 20)", single line. A flexing
    /// text takes the remaining width and tail-truncates; an intrinsic one keeps its width.
    @ViewBuilder
    private func line(_ text: String, tint: Color, flexes: Bool) -> some View {
        let base = Text(text)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(tint)
            .lineLimit(1)
        if flexes {
            base
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            base.fixedSize(horizontal: true, vertical: false)
        }
    }

    /// §2 Chevron: "library glyph **`chevron-right-carbon`** …, 18×18, `color-white-50`,
    /// vertically centred on the content. It is a cue, not a separate button." Decorative
    /// (R-17). `Glyph` renders only the token scale (16 / 24 / 32), so the imageset is drawn
    /// directly at §2's 18 — same artwork, same template rendering (as C-037 does).
    private var chevron: some View {
        Image(GlyphName.chevronRightCarbon.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .foregroundStyle(Token.white50)
            .accessibilityHidden(true)
            .ui2Element("Chevron")
    }

    // MARK: - §2 constants

    /// §2: each line is "height 20" — `type-body-sm`'s 20pt leading, pinned because
    /// lineSpacing does nothing to a single line (80 = 16 + 20 + 8 + 20 + 16).
    private static let lineBox: CGFloat = Token.TypeStyle.bodySm.lineHeight ?? Token.TypeStyle.bodySm.size

    // GAP — C-089 §2: chevron "18×18"; the glyph size scale has no 18 step.
    private static let glyphSize: CGFloat = 18
}
