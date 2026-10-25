//
//  SearchResultRow.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-085-searchresultrow in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-085 SearchResultRow — "one search hit or recently opened result: type badge, title, meta
/// line, optional remove ✕".
///
/// Controlled, no domain behaviour (§4; R-01 / R-04 / R-25): it renders what it is handed and
/// reports taps through `onTap` / `onRemove`. Recording a recent, opening the item and deleting
/// history are the consumer's.
///
/// Chrome-free and width-driven (R-16; deviation 1): it fills the width it is given and states
/// its own intrinsic height — 74 with a description, 52 without — paints no background, draws
/// no hairline (deviation 10, the consumer's) and adds no outer padding.
struct SearchResultRow: View {

    /// §4 `kind` — "Selects the badge glyph". Nested per R-36; one case per §4 value (R-06).
    enum Kind: String {
        case member
        case media
        case program
        case group
        case lesson
        case event
        case post
    }

    /// §4 `trailing` — "`remove` draws `close-large-carbon` with its 44pt target (recents);
    /// `none` omits the slot (query results)".
    enum Trailing: String {
        case remove
        case none
    }

    /// §4 `kind` — required.
    let kind: Kind
    /// §4 `title` — required. "The single-line title".
    let title: String
    /// §4 `description` — "The meta line, supplied formatted; nil → the line is not rendered
    /// and the row is 52 (deviation 3)". Default `nil`.
    var description: String?
    /// §4 `trailing` — required.
    let trailing: Trailing
    /// §4 `onTap` — "The whole-row tap". R-03's no-op default.
    var onTap: () -> Void = {}
    /// §4 `onRemove` — "`trailing=remove` only — delivered by the ✕'s 44pt hit target
    /// (deviation 6)". R-03's no-op default.
    var onRemove: () -> Void = {}

    var body: some View {
        // §2 / OQ-C-085-003: "the system highlight over the whole row, no geometry change; the
        // ✕ target has no separate pressed look" — the plain button style's ephemeral press.
        SwiftUI.Button(action: onTap) {
            band
        }
        .buttonStyle(.plain)
        // R-17: "The row is one button, label = title + description (when present) + the kind's
        // name". `.contain` keeps the ✕ its own element, so VoiceOver reaches both actions.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityPhrase)
        .accessibilityAddTraits(.isButton)
        .ui2Element("SearchResultRow")          // capture element map — UI2Element.swift
    }

    /// §2: "vertical padding `space-card-padding` (16) top and bottom around one horizontal
    /// band, children vertically centred, horizontal gap 16 between siblings."
    private var band: some View {
        // FLAGGED (D7) — C-085 §2: the 16 horizontal gap is cited as `space-card-padding`
        // because it is "value-equal and measured 16 in the symbol and both instances" (the
        // C-037 precedent).
        HStack(alignment: .center, spacing: Token.Space.cardPadding) {
            badge
            info
            trailingSlot
        }
        .padding(.vertical, Token.Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // §2: no background, border or radius of its own; the whole row is the tap target.
        .contentShape(Rectangle())
        .ui2Element("Content")
    }

    /// §2 Badge (inline part, OQ-C-085-001): "24×24 disc, `radius-circle`, fill
    /// `color-card-border` (deviation 8); holds ONE 18×18 glyph centred, tinted
    /// `color-white-50` (deviation 7)". `radius-circle` is 50% (parsed:false), drawn as Circle.
    private var badge: some View {
        Circle()
            .fill(Token.cardBorder)             // FLAGGED — C-085 deviation 8: badge fill
            .frame(width: Self.badgeSize, height: Self.badgeSize)
            .overlay(glyph(Self.glyphName(kind)))
            .accessibilityHidden(true)
            .ui2Element("Badge")
    }

    /// §2 Info column: "fills the remaining width (min-width 0), vertical gap
    /// `space-element-gap` (8), leading-aligned".
    private var info: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            titleText
            descriptionText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ui2Element("Info")
    }

    /// §2 Title: "one line, `type-body-sm` (SF Pro Regular 14/20), `color-text-primary`,
    /// tail-truncated". The line box is pinned so §2's 74 = 16 + 20 + 8 + 14 + 16 holds.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
            .ui2Element("Title")
    }

    /// §2 Description (when non-nil): "`type-body` (SF Pro Regular 14/14),
    /// `color-text-secondary` (deviation 9); one line, tail-truncated" (OQ-C-085-004).
    @ViewBuilder private var descriptionText: some View {
        if let description {
            Text(description)
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.lineBox(Token.TypeStyle.body))
                .ui2Element("Description")
        }
    }

    /// §2 Trailing.
    @ViewBuilder private var trailingSlot: some View {
        switch trailing {
        case .remove:
            // §2 / deviation 6: "glyph `close-large-carbon` drawn 18×18, tinted
            // `color-white-50`, y-centred; a 44pt invisible hit target centred on it delivers
            // `onRemove`". The button's frame is the 44pt target; the negative padding hands
            // the layout back its 18pt slot, so the band's geometry is the symbol's.
            SwiftUI.Button(action: onRemove) {
                glyph(.closeLargeCarbon)
                    .frame(width: Self.hitTarget, height: Self.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding((Self.glyphSize - Self.hitTarget) / 2)
            // R-17: "the ✕ target is a second button labelled 'Remove'".
            .accessibilityLabel("Remove")
            .accessibilityAddTraits(.isButton)
            .ui2Element("Remove")
        case .none:
            // §2: "slot absent; the info column extends to the trailing edge".
            EmptyView()
        }
    }

    /// The library glyph's own imageset at §2's 18pt, tinted `color-white-50` by the row
    /// (deviation 7). `Glyph` renders only the token scale (16 / 24 / 32), so the artwork is
    /// drawn directly — same imageset, same template rendering.
    private func glyph(_ name: GlyphName) -> some View {
        Image(name.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .foregroundStyle(Token.white50)
    }

    /// §2 badge glyph per `kind`: member / media / program from the designed badge set;
    /// group / lesson / event / post per OQ-C-085-002 ("group → users, lesson → file-text,
    /// event → calendar-days, post → message-circle").
    private static func glyphName(_ kind: Kind) -> GlyphName {
        switch kind {
        case .member: return .userFilledCarbon
        case .media: return .playFilledAltCarbon
        case .program: return .bookOpen
        case .group: return .users
        case .lesson: return .fileText
        case .event: return .calendarDays
        case .post: return .messageCircle
        }
    }

    /// R-17 / §4 Accessibility: title, description (when present), then the kind's name.
    private var accessibilityPhrase: String {
        var parts = [title]
        if let description { parts.append(description) }
        parts.append(Self.kindName(kind))
        return parts.joined(separator: ", ")
    }

    /// §4 Accessibility: "the kind's name (\"Program\", \"Member\", \"Media\", \"Group\",
    /// \"Lesson\", \"Event\", \"Post\")".
    private static func kindName(_ kind: Kind) -> String {
        switch kind {
        case .member: return "Member"
        case .media: return "Media"
        case .program: return "Program"
        case .group: return "Group"
        case .lesson: return "Lesson"
        case .event: return "Event"
        case .post: return "Post"
        }
    }

    // GAP — C-085 §2: "24×24 disc" — badge diameter, no token row.
    private static let badgeSize: CGFloat = 24
    // GAP — C-085 §2: glyphs "18×18"; the glyph size scale has no 18 step.
    private static let glyphSize: CGFloat = 18
    // GAP — C-085 §2 / deviation 6: "a 44pt invisible hit target", no token row.
    private static let hitTarget: CGFloat = 44

    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }
}
