//
//  Avatar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-038-avatar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-038 Avatar — a person's or group's circular image, and what stands in when there isn't one.
///
/// §2: a circle (or, `shape: square`, a rounded square), one of three things inside it, and
/// optionally the selected look over it. No border, no ring, no shadow, no badge slot in any state.
///
/// Chrome-free: it states its own footprint (`size` × `size`), paints no page background and
/// adds no outer padding. The outer margin and ground belong to the ViewRegistry call site.
struct Avatar: View {

    /// C-038 §3a — the Figma `state` axis. Raw values are the contract's labels verbatim.
    /// OQ-C-038-3 (d): state is **derived-only**, so this is read from content, never passed.
    enum State: String {
        case hasPhoto = "Has photo"
        case initials = "Initials"
        case unknownUser = "Unknown user"
    }

    /// C-038 §4 `shape` — the outline. Raw values are the contract's values verbatim.
    /// Figma `style=Group` → `round`, `style=Program` → `square`.
    enum Shape: String {
        case round
        case square
    }

    /// C-038 §4: `imageURL`. Fills the circle cover-cropped in `Has photo`.
    let imageURL: URL?
    /// C-038 §4: `initials`. OQ-C-038-3 (c): two characters, uppercased — normalised here.
    let initials: String?
    /// C-038 §4: `size` — the diameter. NOT a variant (§3b): one symbol at 32 / 40 / 54 / 64 / 164.
    let size: CGFloat
    /// C-038 §4: `shape`. Default `round` — every existing consumer is unchanged. Host-set, not derived.
    let shape: Shape
    /// C-038 §4: `selected` — the selected look (§2). Default `false`. Host-set; the avatar is
    /// still never the tap target (OQ-C-038-6).
    let selected: Bool

    init(imageURL: URL?, initials: String?, size: CGFloat, shape: Shape = .round, selected: Bool = false) {
        self.imageURL = imageURL
        self.initials = initials
        self.size = size
        self.shape = shape
        self.selected = selected
    }

    /// C-038 §4's derivation chain, confirmed by OQ-C-038-3 (a):
    /// imageURL resolves → Has photo · else initials non-empty → Initials · else → Unknown user.
    static func derive(imageURL: URL?, initials: String?) -> State {
        if imageURL != nil { return .hasPhoto }
        if let text = initials, !text.isEmpty { return .initials }
        return .unknownUser
    }

    var state: State { Self.derive(imageURL: imageURL, initials: initials) }

    var body: some View {
        ZStack {
            // §2 Selected wash: "the shape filled `color-accent`", under the content.
            if selected {
                outline
                    .fill(Token.accent)
                    .ui2Element("SelectedWash")
            }
            content
                // FLAGGED LITERAL — C-038 §2: "the content … drawn on top at 20% opacity" is a
                // layer opacity, not a colour token. OQ-C-038-002: the same over any content.
                .opacity(selected ? Self.selectedContentOpacity : 1)
            if selected {
                checkmark
            }
        }
        // §2: Root — a `size` × `size` box clipped to the outline; everything inside clips to it.
        .frame(width: size, height: size)
        .clipShape(outline)
        .ui2Element("Avatar")                     // capture element map — UI2Element.swift
    }

    @ViewBuilder
    private var content: some View {
        if let url = imageURL {
            photo(url)
        } else {
            fallback
        }
    }

    /// §2 Root: `round` is a circle — `radius-circle` is "50%" and emits no member, so the shape
    /// names it (a circle IS the 50% radius). `square` is corners `radius-card` at EVERY size
    /// (OQ-C-038-001: the corner is a token, not a ratio).
    private var outline: AnyShape {
        switch shape {
        case .round: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: Token.Radius.card))
        }
    }

    /// C-038 §2 Selected mark — the `checkmark-carbon` glyph, white (`color-text-primary`),
    /// 24 at the designed 64 = 37.5% of the side, scaled proportionally (OQ-C-038-2), drawn
    /// above the wash at full opacity. Drawn from the imageset at the ratio, as `personGlyph` is,
    /// because `Glyph` only offers 16 / 24 / 32.
    private var checkmark: some View {
        Image(GlyphName.checkmarkCarbon.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * Self.checkmarkRatio, height: size * Self.checkmarkRatio)
            .foregroundStyle(Token.textPrimary)
            .accessibilityHidden(true)
            .ui2Element("SelectedMark")
    }

    @ViewBuilder
    private func photo(_ url: URL) -> some View {
        // Cache-first: a snapshot renders in one synchronous layout pass, so an `AsyncImage`
        // alone comes out empty in a capture (Ui2ImageCache.swift).
        if let cached = Ui2ImageCache.shared.image(for: url) {
            // §2: the image fills the shape edge-to-edge, cover-cropped.
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
                // OQ-C-038-3 (b): a photo that fails to load falls through the §4 chain.
                fallback
            }
        }
    }

    /// Both non-photo states: the same ground, different content on it.
    private var fallback: some View {
        ZStack {
            // §2: Ground — "the same shape filled `color-avatar-fallback`".
            outline
                .fill(Token.avatarFallback)
                .ui2Element("Ground")
            if let text = Self.normalisedInitials(initials) {
                initialsText(text)
            } else {
                personGlyph
            }
        }
    }

    /// OQ-C-038-3 (c): "initials are two characters uppercased".
    private static func normalisedInitials(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return String(text.prefix(2)).uppercased()
    }

    private func initialsText(_ text: String) -> some View {
        Text(text)
            .designTextStyle(initialsStyle)
            // §2: `color-text-primary`.
            .foregroundColor(Token.textPrimary)
            .lineLimit(1)
            .fixedSize()
            // §2: "text centred on both axes — measured box 24×22 at (8, 9), whose centre is
            // (20, 20)". Centring in the ZStack is that, without pinning the box.
            .ui2Element("Initials")
    }

    /// C-038 §5a — the `user--filled` glyph (library `user-filled-carbon`), drawn directly: a
    /// plain glyph, not a component and not a button. `Glyph` only offers 16 / 24 / 32, and
    /// §2 + OQ-C-038-2 size it at 60% of the diameter, so the imageset is drawn the way
    /// `Glyph` draws a template glyph, at the ratio.
    private var personGlyph: some View {
        Image(GlyphName.userFilledCarbon.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            // §2: "24×24 at (8, 8) — inset 8 on every side, i.e. 60% of the diameter".
            .frame(width: size * Self.glyphRatio, height: size * Self.glyphRatio)
            // §5a: "white at 50% opacity (`color-white-50`), applied by C-038".
            .foregroundStyle(Token.white50)
            .accessibilityHidden(true)
            .ui2Element("Glyph")
    }

    // FLAGGED LITERAL — C-038 §2: the initials' Bold 17 / 22 has no token row; kept as a
    // per-component literal until the program's Bold-leading ruling (OQ-C-038-4).
    //
    // OQ-C-038-2 (answered): contents scale proportionally — initials at 42.5% of the
    // diameter, glyph at 60%. At the designed 40 these resolve to exactly 17 / 22 and 24.
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
    private static let glyphRatio: CGFloat = 24.0 / 40.0
    // C-038 §2: the checkmark is 24 at the designed 64 — the 37.5% ratio, not a spacing token.
    private static let checkmarkRatio: CGFloat = 24.0 / 64.0
    // FLAGGED LITERAL — C-038 §2: the selected content's 20% layer opacity.
    private static let selectedContentOpacity: Double = 0.2
}
