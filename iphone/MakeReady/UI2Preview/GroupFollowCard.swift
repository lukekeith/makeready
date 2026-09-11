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
//    `/ui2-component Avatar <figma-url>` run — the same treatment C-062 PercentDisc gets in
//    DayActivityCard.swift, where one designed band of six is built.
//  • C-057 PercentBar — LEVEL 2, anchored in `docs/ui2/screens/study-program-home.md` §4.
//    C-033 consumes `Thin`/`Left`; both axes are built here because the anchor states both
//    and they are two numbers, not two designs.
//  • C-072 LinkStatusGlyph — its contract is C-033 §3e, i.e. THIS file's contract. It has no
//    contract file of its own, so it is not a legal `/ui2-component-build` target (that
//    command's phase 0.3) and is built here, as preview-build.md §4 allows. It is
//    instantiated nowhere but inside this card (C-033 §1).
//
//  ARTWORK: C-072's two vectors are the ones exported from the normative Figma set
//  (C-033 §1), carried in Resources/Glyphs.xcassets. A raw .svg in a bundle is not loadable
//  by iOS; the catalog is.
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
    /// `DayActivityCard.CardState` and `PageHeader.Style` make, resolved at the ViewRegistry
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
                // unreachable from this card (deviation 5, OQ-C-033-3).
                LinkStatusGlyph(linked: true)
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
                    fillColor: PercentBar.frameGreen,
                    style: .thin,
                    aligned: .left
                )
                .frame(width: Self.contentWidth, height: PercentBar.thinHeight)
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

/// C-038 Avatar — the circular person/group image primitive (C-033 §5, at 64).
///
/// LEVEL-2 DEPENDENCY (preview-build.md §4): C-038 has no contract file, so it is built from
/// its screen-spec anchor — `docs/ui2/screens/members-home.md` §4, which D10 accepts as a full
/// contract anchor: "Circular member/person image primitive: sizes 32, 40, 64; photo fill, or
/// initials fallback on `color-card-background` when no photo (program convention)."
///
/// **The initials half is deliberately NOT built.** The anchor states no type style, size or
/// colour for the initials, and C-033 §4 exposes no `initials` prop to feed it — which is
/// precisely what OQ-C-033-7 asks the owner to confirm. So this view builds the photo path and
/// the anchor's stated empty ground, and the lettering belongs to a
/// `/ui2-component Avatar <figma-url>` run.
struct Avatar: View {

    /// members-home §4: `imageURL`. C-033 §4 hands it `photoURL: String?`.
    let imageURL: String?
    /// members-home §4: `size` — the closed set 32 / 40 / 64; C-033 §5 consumes 64.
    let size: CGFloat

    var body: some View {
        ZStack {
            // members-home §4: the no-photo ground is `color-card-background`.
            Circle()
                .fill(Token.cardBackground)
            if let url = imageURL.flatMap(URL.init(string:)) {
                // Cache-first, then async — the shape 1.0's `CachedCardImage` uses, and for
                // the same reason (Ui2ImageCache.swift): a snapshot renders in one
                // synchronous pass, so an `AsyncImage` alone comes out empty in a capture.
                if let cached = Ui2ImageCache.shared.image(for: url) {
                    Image(uiImage: cached)
                        .resizable()
                        // §2: "image cover-cropped (the source's 64×88 inner frame is the
                        // crop, not a size)".
                        .scaledToFill()
                } else {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        // No designed loading state anywhere in the source; the ground
                        // stands in.
                        Color.clear
                    }
                }
            }
        }
        // §2: "64×64, `radius-circle`". `radius-circle` is the one token row the generator
        // reports as NOT PARSED (it is "50%", not a point value), so the shape is what names
        // it: a circle IS the 50% radius, not a literal standing in for one.
        .frame(width: size, height: size)
        .clipShape(Circle())
        .ui2Element("Avatar")
    }
}

// MARK: - C-057 PercentBar

/// C-057 PercentBar — the progress bar unit C-033 `Default` puts above its completion row.
///
/// LEVEL-2 DEPENDENCY (preview-build.md §4): C-057 has no contract file, so it is built from
/// its screen-spec anchor — `docs/ui2/screens/study-program-home.md` §4, which D10 accepts as a
/// full contract anchor: "Track `color-white-10`, fill segment in the consumer's status color
/// (frame literal anomaly per §2). Variant axes (closed, from the sheet): `style={Thick 16pt,
/// Thin 2pt}` × `aligned={Right, Left}`. Props: `progress: 0…1`, `fillColor`, `style`,
/// `aligned`." C-033 §5 consumes `Thin` / `Left`.
struct PercentBar: View {

    /// study-program-home §4: `style={Thick 16pt, Thin 2pt}` — the axis is a height.
    enum BarStyle {
        case thick
        case thin
    }

    /// study-program-home §4: `aligned={Right, Left}` — which edge the fill segment anchors to.
    ///
    /// `BarAlignment`, not `Alignment`: SwiftUI already spells one, and a nested `Alignment`
    /// here would shadow it inside this type — the reason `Token.TypeStyle` is not `TextStyle`.
    enum BarAlignment {
        case left
        case right
    }

    /// study-program-home §4: `progress: 0…1`.
    let progress: Double
    /// study-program-home §4: `fillColor` — "the consumer's status color".
    let fillColor: Color
    /// study-program-home §4: `style`.
    let style: BarStyle
    /// study-program-home §4: `aligned`.
    let aligned: BarAlignment

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: aligned == .left ? .leading : .trailing) {
                // study-program-home §4: "Track `color-white-10`".
                Rectangle()
                    .fill(Token.white10)
                // "fill segment in the consumer's status color", clamped to the track.
                Rectangle()
                    .fill(fillColor)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: style == .thick ? Self.thickHeight : Self.thinHeight)
        .ui2Element("PercentBar")
    }

    /// study-program-home §4: "`style={Thick 16pt, Thin 2pt}`".
    static let thickHeight: CGFloat = 16
    static let thinHeight: CGFloat = 2

    // FLAGGED LITERAL — C-033 §1 deviation 9: "That bar's fill is the raw literal `#4deb4b` —
    // C-057's already-recorded green anomaly (OQ-home-dashboard-6) — not `color-positive`."
    // tokens.md carries the same flag. Emitted as a literal per preview-build.md §3 rule 4,
    // NOT promoted to `color-positive` (#6cff73), which is a different green.
    static let frameGreen = Color(red: 0.302, green: 0.9216, blue: 0.2941, opacity: 1)
}

// MARK: - C-072 LinkStatusGlyph

/// C-072 LinkStatusGlyph — the 16pt link indicator in C-033 `No bar`'s top-right corner.
///
/// Its contract is C-033 §3e: "16×16 box in both states; the fill is BAKED INTO THE ARTWORK,
/// not tinted by the consumer." That is a statement about the consumer — C-033 passes no
/// colour — so the token is applied here, inside the glyph, rather than being frozen into the
/// vector: preview-build.md §3 rule 4 wants the colour named, and §3e names it
/// (`color-text-secondary` / `color-brand-highlight`).
///
/// NOT a button: §3e and the registry row are explicit that this is "a 16×16 static indicator
/// (NOT a button — no hit target, no action)".
struct LinkStatusGlyph: View {

    /// C-033 §4: "C-072 LinkStatusGlyph: `linked: Bool` — the two values of §3e."
    let linked: Bool

    var body: some View {
        Image(linked ? Self.linkedAsset : Self.unlinkedAsset, bundle: .ui2Preview)
            // The catalog marks both vectors template-rendering, so the artwork is a mask and
            // the tint below is the whole of its colour — which is what keeps §3e's fills
            // tokens by name rather than baked hex.
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            // §3e: `true` is "two interlocking chain links, 15.02×11.5 in the 16×16 box";
            // `false` is "a broken chain with radiating ticks, 14×14 in the 16×16 box". The
            // artwork carries those proportions; the box is the frame.
            .frame(width: Self.artworkSize(linked: linked).width,
                   height: Self.artworkSize(linked: linked).height)
            .foregroundColor(linked ? Token.textSecondary : Token.brandHighlight)
            .frame(width: Self.box, height: Self.box)
            .ui2Element("LinkStatusGlyph")
    }

    /// §3e: "16×16 box in both states".
    private static let box: CGFloat = 16

    private static func artworkSize(linked: Bool) -> CGSize {
        linked ? CGSize(width: 15.02, height: 11.5) : CGSize(width: 14, height: 14)
    }

    private static let linkedAsset = "c072-link-linked"
    private static let unlinkedAsset = "c072-link-unlinked"
}
