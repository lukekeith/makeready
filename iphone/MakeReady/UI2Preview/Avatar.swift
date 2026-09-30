//
//  Avatar.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-038-avatar.md (§2 geometry, §3 states,
//  §4 props), including its §5a sub-contract for C-074 PersonGlyph. PREVIEW ONLY:
//  referenced by no screen, route, tab or flag (docs/ui2/preview-build.md §3 rule 1).
//  Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-038 Avatar — a person's or group's circular image, and what stands in when there isn't one.
///
/// §2: a circle, and one of three things inside it. No border, no ring, no shadow, no badge
/// slot in any state.
///
/// Chrome-free and width-driven: it states its own footprint (`size` × `size`), paints no page
/// background and adds no outer padding. The outer margin and ground belong to the ViewRegistry
/// call site (preview-build.md OQ-PB-1 / OQ-PB-2).
///
/// **Supersedes the placeholder.** Until this build, `GroupFollowCard.swift` carried an inline
/// `struct Avatar` built from the members-home §4 anchor, whose own doc comment said the real
/// one "belongs to a `/ui2-component Avatar <figma-url>` run". That run happened (2026-09-11),
/// so the placeholder is gone and C-033 composes this view. Two things change for C-033: the
/// fallback ground is `color-avatar-fallback` (#242a3e), not the `color-card-background` the
/// old anchor wrongly claimed (C-038 §1 change 2b), and a photo that fails to resolve now falls
/// through §3c's chain instead of showing a bare empty circle.
struct Avatar: View {

    /// C-038 §4 `state` — the Figma axis (§3a). Raw values are the contract's enumerated
    /// values verbatim (preview-build.md §3 rule 5).
    enum State: String {
        case hasPhoto = "Has photo"
        case initials = "Initials"
        case unknownUser = "Unknown user"
    }

    /// C-038 §4: `state`. Normally derived from content rather than passed — see `derive`.
    let state: State
    /// C-038 §4: `imageURL`. Fills the circle cover-cropped in `Has photo`.
    let imageURL: String?
    /// C-038 §4: `initials`. Sample is 2 characters, uppercase ("TD"); count and casing are
    /// OQ-C-038-3, so this view renders the string it is given and normalises nothing.
    let initials: String?
    /// C-038 §4: `size` — the diameter. NOT a variant (§3b): the set designs one diameter, 40,
    /// and 32 / 54 / 64 / 164 are the same symbol at other scales.
    let size: CGFloat

    /// `state` defaults to the §4 derivation so a consumer can pass content alone — which is
    /// what every consumer on file actually does (C-033 passes `photoURL` and nothing else).
    /// It stays settable because a preview fixture can only set props: a state reachable only
    /// by derivation would be uncapturable.
    init(state: State? = nil, imageURL: String? = nil, initials: String? = nil, size: CGFloat) {
        self.imageURL = imageURL
        self.initials = initials
        self.size = size
        self.state = state ?? Self.derive(imageURL: imageURL, initials: initials)
    }

    /// C-038 §4's state derivation — a **proposed default, not designed**. It is the chain
    /// `iphone/MakeReady/Components/Display/Avatar.swift` already implements, and the three
    /// designed states line up with it one-for-one. OQ-C-038-3 asks the owner to confirm it.
    static func derive(imageURL: String?, initials: String?) -> State {
        if let url = imageURL, !url.isEmpty { return .hasPhoto }
        if let text = initials, !text.isEmpty { return .initials }
        return .unknownUser
    }

    var body: some View {
        ZStack {
            content
        }
        // §2: Root — a `size` × `size` circle. `radius-circle` is the one token row the
        // generator reports as NOT PARSED (it is "50%", not a point value), so the shape is
        // what names it: a circle IS the 50% radius, not a literal standing in for one.
        .frame(width: size, height: size)
        .clipShape(Circle())
        .ui2Element("Avatar")                     // capture element map — UI2Element.swift
    }

    @ViewBuilder
    private var content: some View {
        if state == .hasPhoto, let url = imageURL.flatMap(URL.init(string:)) {
            photo(url)
        } else {
            // §3c: a `Has photo` with no usable URL falls through the same chain a failed
            // load does, rather than drawing an empty circle.
            fallback
        }
    }

    @ViewBuilder
    private func photo(_ url: URL) -> some View {
        // Cache-first, then async — the shape 1.0's `CachedCardImage` uses, and for the same
        // reason (Ui2ImageCache.swift): a snapshot renders in one synchronous layout pass, so
        // an `AsyncImage` alone comes out empty in a capture.
        if let cached = Ui2ImageCache.shared.image(for: url) {
            // §2: the image fills the circle edge-to-edge, cover-cropped.
            Image(uiImage: cached)
                .resizable()
                .scaledToFill()
                .ui2Element("Photo")
        } else {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .ui2Element("Photo")
            } placeholder: {
                // §3c, photo load failure: "fall through the same chain the state derivation
                // uses — initials if there are any, otherwise Unknown user." Proposed default
                // (OQ-C-038-3); legacy `Avatar.swift` does exactly this.
                fallback
            }
        }
    }

    /// Both non-photo states: the same ground, different content on it.
    @ViewBuilder
    private var fallback: some View {
        ZStack {
            // §2: Ground — "the same circle filled `color-avatar-fallback`", in BOTH fallback
            // states. (C-038 §1 change 2b: members-home §4 claimed `color-card-background`
            // #1f2124; the designed fill is #242a3e, a different colour.)
            Circle()
                .fill(Token.avatarFallback)
                .ui2Element("Ground")
            if state == .initials, let text = initials, !text.isEmpty {
                initialsText(text)
            } else {
                personGlyph
            }
        }
    }

    private func initialsText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(initialsStyle)
            // §2: `color-text-primary`.
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            // §2: "text centred on both axes — measured box 24×22 at (8, 9), whose centre is
            // (20, 20)". Centring in the ZStack is that, expressed without pinning the box.
            .ui2Element("Initials")
    }

    /// C-038 §5a — **C-074 PersonGlyph**. Built inline rather than as its own preview: its
    /// contract is a subsection of C-038's file with no frozen snapshot of its own, so it is
    /// not a legal `/ui2-component-build` target and can never earn its own comparison row.
    private var personGlyph: some View {
        // §5a: "white at 50% opacity (`color-white-50`) — baked into the artwork as a group
        // `opacity="0.5"`, not consumer-tinted." So the imageset is `original`-rendered and
        // carries no `.foregroundColor`; `Token.white50` is the token that value equals, and
        // is named here rather than applied.
        Image("c074-person", bundle: .ui2Preview)
            .resizable()
            // §2: the glyph is 24 at the designed diameter of 40 — "inset 8 on every side,
            // i.e. 60% of the diameter". §2 records it as a RATIO deliberately: the hex-equal
            // `space-element-gap` (8) and `space-row-gap` (24) are gaps between siblings, not
            // an inset inside a circle, and citing them would assert that this inset and a
            // table's row rhythm are one decision.
            .frame(width: size * Self.glyphRatio, height: size * Self.glyphRatio)
            .ui2Element("Glyph")
    }

    // FLAGGED LITERAL — C-038 §2: the initials' "**Bold 17 / 22** has no token row. It is the
    // exact-weight sibling of `type-body-lg` (SF Pro Text Regular 17/22) and the program's
    // first Bold-17. Minting `type-body-lg-bold` off one site would pre-empt the Bold-leading
    // ruling that `type-title-card` (Bold 14/20), `type-nav-label` (Bold 14/16) and C-046's
    // Bold 14/14 are already queued behind, so it is carried as a per-component literal" —
    // OQ-C-038-4.
    //
    // The ratios are OQ-C-038-2's proposed default: the set designs ONE diameter (40), where
    // the type measures 17/22, and members-profile instances this component at 164, where a
    // fixed 17pt initial would be a speck. Scaling proportionally matches legacy
    // `Avatar.swift`'s per-size `fontSize` table. At the designed 40 these resolve to exactly
    // 17 and 22, so the fixture — which renders only 40 — shows nothing unruled.
    private var initialsStyle: DesignTextStyle {
        DesignTextStyle(
            weight: .bold,
            size: size * Self.initialsSizeRatio,
            lineHeight: size * Self.initialsLineHeightRatio,
            tracking: 0
        )
    }

    private static let initialsSizeRatio: CGFloat = 17.0 / 40.0
    private static let initialsLineHeightRatio: CGFloat = 22.0 / 40.0

    // §2: "C-074 PersonGlyph 24×24 at (8, 8) — inset 8 on every side, i.e. 60% of the
    // diameter". Same OQ-C-038-2 caveat as the type ratios above.
    private static let glyphRatio: CGFloat = 24.0 / 40.0
}
