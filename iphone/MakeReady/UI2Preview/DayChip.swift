//
//  DayChip.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-052-day-chip.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-052 DayChip — "the 32×40 rounded box holding one ordinal program-day number".
///
/// §2: a fixed box and a number, in either state. §1 deviation 5: "Neither symbol has a
/// border, a shadow, an icon, a dot or a press treatment. A rounded rectangle and one text
/// run is the whole anatomy."
///
/// **Fixed, not content-sized** — the opposite of C-053 StatusBadge. §1 deviation 1: "The
/// box is a fixed 32×40 with `overflow: clip`; the number is centred inside it. A label
/// wider than 32 is **clipped**, not wrapped and not grown." The clip is modelled, not
/// assumed away, because it is the behaviour OQ-C-052-4 is asking the owner about.
///
/// Chrome-free: frame, background and outer padding belong to the call site
/// (preview-build.md OQ-PB-1 / OQ-PB-2).
struct DayChip: View {

    /// §4 `state` — `Default | Active`. §3a: it "selects the chip fill and nothing else";
    /// size, radius, clipping, type and text colour are identical in both symbols.
    ///
    /// §3b: `Active` means "this is the **selected** day", not "today" — the rail draws
    /// ordinal program days on a template, which has no current date, and C-070 DateBlock is
    /// where the program expresses "today". Raw values are §3a's labels verbatim, because
    /// those strings are the fixture's variant keys (preview-build.md §3 rule 7).
    enum State: String {
        case `default` = "Default"
        case active = "Active"
    }

    /// §4 `day` — "the ordinal program day rendered in the box — Day 1 … Day N, not a
    /// calendar date". §4 records that Figma types the text override `string` with default
    /// `"1"`; that is the source's authoring type, and the contract is `Int`.
    let day: Int

    /// §4 `state`.
    let state: State

    /// §4 `onTap` — "Fires on tap. What the caller does with it … belongs to the consuming
    /// screen, not to this row." Carries no render effect; emitted as a defaulted no-op so
    /// the promoted view keeps its real signature (OQ-PB-3's default).
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            number
                // §2: "fixed **32 × 40**, contents centred on both axes".
                .frame(width: Self.width, height: Self.height)
                .background(
                    // §2: `radius-card-sm` (4), fill per state, "No stroke".
                    RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                        .fill(chipFill)
                        .ui2Element("Chip")
                )
                // §2 / §1 deviation 1: `overflow: clip`. A number too wide for 32 is cut by
                // the chip's own rounded rect rather than overflowing it.
                .clipShape(RoundedRectangle(cornerRadius: Token.Radius.cardSm))
        }
        .buttonStyle(.plain)
        .ui2Element("DayChip")     // capture element map — UI2Element.swift
    }

    // §2: the centred number. `String(day)` rather than an interpolated Int: the source
    // renders the digits as authored, with no grouping separator or locale formatting.
    private var number: some View {
        Text(String(day))
            // §2: SF Pro Regular 14 / 14 — `type-body` exactly, the leading measured from
            // the text node's own 14pt box.
            .designTextStyle(Token.TypeStyle.body)
            .foregroundColor(Self.numberWhite)
            .lineLimit(1)
            .fixedSize()
            // §2: "the text node sits at x 12.5 / y 13 with a 7 × 14 box". SwiftUI's
            // lineSpacing does nothing to a single line, so the 14pt line box is pinned as
            // a frame — the same construction C-053's label uses — or the glyph centres
            // against SF Pro's natural ~16.7pt line box instead of the measured one.
            .frame(height: Self.lineBox)
            .ui2Element("Number")
    }

    /// §3a: the one delta between the two symbols.
    private var chipFill: Color {
        switch state {
        // §1 deviation 3: `color-white-20` is white at **20% alpha**, not a grey. The
        // token carries the alpha, so the chip composites against whatever ground the call
        // site paints — which is the whole point of the deviation.
        case .default: Token.white20
        case .active: Token.accent
        }
    }

    // FLAGGED LITERAL — C-052 §1 deviation 2: "The number's white is raw `#ffffff`, bound to
    // no Figma variable, while **both** chip fills **are** bound (`White/20%`,
    // `Purple/100%`)." Emitted as the literal the source states per preview-build.md §3
    // rule 4, NOT promoted to `Token.textPrimary` — promoting it would assert a binding
    // Figma does not have, and the flag exists so the next Figma edit can move one and not
    // the other. Seventh site of the pattern; OQ-C-052-2 asks for the binding, paired with
    // OQ-C-022-4.
    private static let numberWhite = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 1)

    /// §2: the fixed box.
    private static let width: CGFloat = 32
    private static let height: CGFloat = 40
    /// §2: the number's 14pt line box — see the frame on `number`.
    private static let lineBox: CGFloat = 14
}
