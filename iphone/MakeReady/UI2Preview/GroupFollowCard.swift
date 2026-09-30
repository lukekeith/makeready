//
//  GroupFollowCard.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-033-group-follow-card.md (§2 geometry, §3
//  states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  Three dependencies, resolved per preview-build.md §4:
//
//  • C-038 Avatar — LEVEL 2, anchored in `docs/ui2/screens/members-home.md` §4, which D10
//    accepts as a full contract anchor. Only what C-033 §5 consumes is built: the 64pt photo
//    circle. The initials fallback's typography is stated by no anchor, and C-033 exposes no
//    `initials` prop at all (OQ-C-033-7), so that half belongs to a
//    `/ui2-component Avatar <figma-url>` run — the same treatment C-062 PercentDisc got in
//    DayActivityCard.swift (retired 2026-09-21 — C-025 merged into C-023 RailCard), where one designed band of six was built.
//  • C-057 PercentBar — was LEVEL 2 (anchored in `docs/ui2/screens/study-program-home.md` §4)
//    and built inline here. **Promoted to LEVEL 1 on 2026-09-12**: C-057 now has its own
//    contract and view, so the inline copy is gone and this card composes `PercentBar`.
//  • C-072 LinkStatusGlyph — RETIRED 2026-09-26 into the glyph library: its two vectors are
//    the glyphs `chain-link` (`linked=true`, the one this card draws) and `chain-broken`
//    (`linked=false`), drawn through the generated `Glyph` view.
//

import SwiftUI

/// C-033 GroupFollowCard — a followed group's completion, in a horizontally-scrolling rail.
///
/// Like C-025, NOT width-driven: §2 opens "179×228 in every state", so the footprint is the
/// contract's and is stated here. It still paints no page background and adds no outer
/// padding — the ground and the outer margin belong to the ViewRegistry call site
/// (preview-build.md OQ-PB-1 / OQ-PB-2).
struct GroupFollowCard: View {

    /// C-033 §4 `style: default | noBar` (§3a's two designed styles).
    ///
    /// `standard` spells §4's `default`, which is a Swift keyword — the same substitution
    /// `PageHeader.Style` makes (and the retired `DayActivityCard.State` made), resolved at the ViewRegistry
    /// call site rather than by a raw value.
    enum Style {
        case standard
        case noBar
    }

    /// C-033 §4 `color: green | yellow | red` — §3b's completion band.
    ///
    /// §3b is explicit that this is "an independent prop, not a function of `percent`": all
    /// four symbols render "55%" and differ only in colour.
    enum BandColor {
        case green
        case yellow
        case red

        /// §3b's token per value. Every one is a token by name.
        var token: Color {
            switch self {
            case .green: return Token.positive
            case .yellow: return Token.highlight
            case .red: return Token.negative
            }
        }
    }

    /// C-033 §4: `style`.
    let style: Style
    /// C-033 §4: `color`.
    let color: BandColor
    /// C-033 §4: `title` — group name; wraps (§2).
    let title: String
    /// C-033 §4: `photoURL: String?` → C-038 Avatar at 64.
    let photoURL: String?
    /// C-033 §4: `members` — "`noBar` only — the members-row number". A display string, not a
    /// count: the source types it as one and OQ-C-033-5 is open on whether that is the
    /// component's contract or the sample's.
    let members: String
    /// C-033 §4: `percent` — the completion number, likewise a display string ("55%").
    let percent: String
    /// C-033 §4: `label` — "`noBar` only — the word after `percent`"; `default` hard-codes
    /// "complete" (deviation 7).
    let label: String
    /// C-033 §4: `showLink` — "`noBar` only" (§3d, default true).
    let showLink: Bool
    /// C-033 §4: `progress` — "`default` only" → C-057 PercentBar.
    let progress: Double
    /// C-033 §4: `onTap` — "no render effect, no designed pressed state (§3f)". Emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3's default).
    var onTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rootStackGap) {
            topSlot
                .frame(width: Self.contentWidth, height: topSlotHeight, alignment: .top)
            completionSlot
                .frame(width: Self.contentWidth, height: completionSlotHeight, alignment: .top)
                .ui2Element("Completion")
        }
        // §2: "Padding 16 sits INSIDE the 1px border, so every inset from the outer edge is
        // 17 and the content column is 145."
        .padding(Self.borderWidth + Token.Space.cardPadding)
        // §2: "179×228 in every state."
        .frame(width: Self.width, height: Self.height, alignment: .top)
        // §2: fill `color-card-background`, `radius-card` (8). Deviation 4 records that the
        // source's `#1f2124` is RAW hex rather than variable-bound, and hex-equal to the
        // token — "not a new colour" — so the token is what is named here.
        .background(
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .fill(Token.cardBackground)
        )
        // §2: "1px border `color-card-border`" (deviation 4 again, hex-equal `#2f363a`).
        .overlay(
            RoundedRectangle(cornerRadius: Token.Radius.card)
                .strokeBorder(Token.cardBorder, lineWidth: Self.borderWidth)
                .ui2Element("Border")
        )
        // §2: `overflow: clip` — which is what OQ-C-033-4 says a fourth title line hits.
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        // §4 `onTap`. A plain tap gesture, not a Button: §3f designs no pressed treatment and
        // a Button would supply one of its own.
        .onTapGesture(perform: onTap)
        .ui2Element("GroupFollowCard")            // capture element map — UI2Element.swift
    }

    // MARK: - Top slot (§2 slot 1)

    private var topSlot: some View {
        // §2: "Internal stack gap `space-element-gap` (8)."
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            // §2: "C-038 Avatar at 64 — 64×64, `radius-circle`, image cover-cropped (the
            // source's 64×88 inner frame is the crop, not a size)."
            Avatar(imageURL: photoURL, size: Self.avatarSize)
            // §2: "Title — `type-title-card` (Bold 14/20) `color-text-primary`, full content
            // width, WRAPS (the source sets `word-break: break-word`, not truncation)."
            Text(title)
                .designTextStyle(Token.TypeStyle.titleCard)
                .foregroundColor(Token.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("Title")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // §2: "C-072 LinkStatusGlyph — 16×16, pinned to the slot's top-right corner
        // (x 129, y 0)" — 129 + 16 = 145, the content width, so the corner IS the pin.
        // §3a gates it: rendered in `No bar` when `showLink`, "never rendered" in `Default`.
        .overlay(alignment: .topTrailing) {
            if style == .noBar && showLink {
                // §3e: C-033 pins the glyph to `linked=true`; `linked=false` is designed but
                // unreachable from this card (deviation 5, OQ-C-033-3). C-072 was retired into
                // the glyph library: `linked=true` is `chain-link`, `linked=false` `chain-broken`.
                Glyph(.chainLink, size: .sm, tint: Token.textSecondary)
                    .ui2Element("LinkStatusGlyph")
            }
        }
        .ui2Element("Top")
    }

    // MARK: - Completion slot (§2 slot 2, contents are the §3a axis)

    @ViewBuilder
    private var completionSlot: some View {
        switch style {
        case .standard:
            // §3a `Default`: "stack gap 16: C-057 PercentBar (`style=Thin`, `aligned=Left`,
            // 145×2) above one completion row. Slot 145×38."
            VStack(alignment: .leading, spacing: Self.defaultCompletionGap) {
                PercentBar(
                    progress: progress,
                    // C-033 §1 deviation 9 — this card passes its own colour, which is exactly
                    // the OVERRIDE note 2026-09-12T02:28:29.097Z gives C-057's `fillColor`.
                    fillColor: c033FrameGreen,
                    // note 2026-09-12T02:28:29.097Z renames C-057's thickness axis: `Thin` → `sm`.
                    size: .sm,
                    aligned: .left
                )
                // C-057 states its own 2pt height; only the width is this card's.
                .frame(width: Self.contentWidth)
                // §3a `Default`: "number takes the band colour; label is `color-white-50`,
                // and is the literal \"complete\" (deviation 7)."
                completionRow(
                    value: percent,
                    valueColor: color.token,
                    label: Self.defaultLabel,
                    labelColor: Token.white50
                )
                .ui2Element("Completion row")
            }
        case .noBar:
            // §3a `No bar`: "stack gap `space-meta-gap` (4): members row above completion
            // row. Slot 145×44."
            VStack(alignment: .leading, spacing: Token.Space.metaGap) {
                // §3a: "The members row (\"9\" `color-text-primary` + \"members\"
                // `color-white-50`) exists only in `No bar`." The word itself is designed,
                // not content: §4 gives the row one string prop and it is the number.
                completionRow(
                    value: members,
                    valueColor: Token.textPrimary,
                    label: Self.membersLabel,
                    labelColor: Token.white50
                )
                .ui2Element("Members row")
                // §3a `No bar`: "BOTH number and label take the band colour" — deviation 6
                // records that this is where home-dashboard §4's rule was right.
                completionRow(
                    value: percent,
                    valueColor: color.token,
                    label: label,
                    labelColor: color.token
                )
                .ui2Element("Completion row")
            }
        }
    }

    /// §2: "both its rows are a `flex` pair with `space-meta-gap` (4) between the number and
    /// its label, typed `type-page-title` (Regular 14/20)."
    private func completionRow(
        value: String, valueColor: Color, label: String, labelColor: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Token.Space.metaGap) {
            Text(value)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundColor(valueColor)
                .ui2Element("Value")
            Text(label)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundColor(labelColor)
                .ui2Element("Label")
        }
        .lineLimit(1)
        // §2's 20pt line box (`type-page-title` is Regular 14/**20**), which is what makes
        // the two slot arithmetics close on 38 / 44. Framed explicitly for the reason C-045
        // §2 documents: `designTextStyle` spells the leading as lineSpacing, which applies
        // only BETWEEN lines, so a single run would otherwise sit in its own ~17pt font box.
        .frame(maxWidth: .infinity, minHeight: Self.completionRowHeight,
               maxHeight: Self.completionRowHeight, alignment: .leading)
    }

    // MARK: - Geometry (§2)

    // §2's stated dimensions. These are component MEASUREMENTS, not spacing values: the
    // spacing family in tokens.md covers gaps and insets and has no vocabulary for a
    // component's own footprint — the same treatment C-025 §2's 131×192 gets.
    private static let width: CGFloat = 179
    private static let height: CGFloat = 228
    private static let contentWidth: CGFloat = 145
    private static let avatarSize: CGFloat = 64
    private static let completionRowHeight: CGFloat = 20

    // §2: "1px border `color-card-border`", which is why every inset from the outer edge is
    // 17 rather than 16.
    private static let borderWidth: CGFloat = 1

    // FLAGGED LITERAL — C-033 §2: "Root stack gap 10 — FLAGGED LITERAL: `tokens.md`'s
    // spacing family is 16/16/8/32/4/2/24 and has no 10pt row; 10 occurs exactly once in the
    // program, here, so D7's 'per-component literal, explicitly flagged' path applies rather
    // than a new token row." Carried as a literal per preview-build.md §3 rule 4.
    private static let rootStackGap: CGFloat = 10

    // GAP — C-033 §3a gives `Default`'s Completion stack a "stack gap 16" and names no token
    // for it. tokens.md has two 16s — `space-page-margin` and `space-card-padding` — and
    // neither is a gap between a bar and a text row; naming one here would assert that this
    // spacing and a page's outer margin are one decision. Emitted as §3a's own literal, and
    // reported by the run (identical in shape to C-025 §3a's 8pt vertical inset).
    private static let defaultCompletionGap: CGFloat = 16

    // §2: the Top slot "absorbs the whole height difference between the two styles (146 in
    // `Default`, 140 in `No bar`, exactly the 6pt the Completion slot differs by)".
    private var topSlotHeight: CGFloat {
        style == .standard ? 146 : 140
    }

    // §3a: "Slot 145×38" (`Default`) / "Slot 145×44" (`No bar`).
    private var completionSlotHeight: CGFloat {
        style == .standard ? 38 : 44
    }

    // §3a: `Default`'s trailing label is the hard-coded string "complete" in the source, and
    // deviation 7 records exactly that — the state does not read `label`.
    private static let defaultLabel = "complete"
    // §3a: the members row's word is likewise designed, not content (deviation 1 lists the
    // sample strings; §4 gives the row only its number).
    private static let membersLabel = "members"
}

// MARK: - C-038 Avatar

// The inline placeholder that stood here was SUPERSEDED 2026-09-11 by the real component:
// `UI2Preview/Avatar.swift`, built from docs/ui2/design-system/components/C-038-avatar.md.
// It was a level-2 build from the members-home §4 anchor and said so itself — "the lettering
// belongs to a `/ui2-component Avatar <figma-url>` run". That run happened, and it also
// corrected the anchor: the fallback ground is `color-avatar-fallback` (#242a3e), not
// `color-card-background`, and the initials fallback is a designed state rather than an
// asserted convention — which is what OQ-C-033-7 was waiting on.
//
// Removed rather than kept beside it: `UI2Preview` is one module and one flat namespace, so
// two `struct Avatar` declarations do not compile. The call site above is unchanged — the real
// view's `init` defaults `state` to C-038 §4's content derivation, so `Avatar(imageURL:size:)`
// still resolves.

// MARK: - C-057 PercentBar

// The inline LEVEL-2 copy that stood here was DELETED 2026-09-12 by `/ui2-component-build
// C-057`. C-057 now has a contract file and its own view (`PercentBar.swift`), so this card
// composes the real component — preview-build.md §4: "Level 1 and the dependency has no preview
// of its own yet: prefer running /ui2-component-build C-0xx for it first … this component then
// composes the real thing."
//
// Promoting it corrected a real defect the inline copy carried: it always drew the
// `color-white-10` track, where the `Thin`/`Left` symbols this card instantiates draw **no
// track at all** (C-057 §1 deviation 3 / §3a, verified on this card's own instance
// `3621:4698` → `3621:4753`). So this card's `Default` bar is a bare 145×2 line, and its
// captured render is stale until `/ui2-component-build C-033` re-runs.

/// C-033 §1 deviation 9's flagged literal, kept here rather than reached for inside C-057: it
/// is THIS card's statement about its own fill, and C-057's identical green is that row's
/// separate flag. Two flags on one hex is what OQ-C-057-2 is for; collapsing them here would
/// quietly answer it.
///
// FLAGGED LITERAL — C-033 §1 deviation 9: "That bar's fill is the raw literal `#4deb4b` —
// C-057's already-recorded green anomaly (OQ-home-dashboard-6) — not `color-positive`."
// tokens.md carries the same flag. Emitted as a literal per preview-build.md §3 rule 4,
// NOT promoted to `color-positive` (#6cff73), which is a different green.
private let c033FrameGreen = Color(red: 0.302, green: 0.9216, blue: 0.2941, opacity: 1)
