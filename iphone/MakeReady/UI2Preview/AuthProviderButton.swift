//
//  AuthProviderButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-104-auth-provider-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-104 AuthProviderButton — a square tile that starts sign-in with one identity provider,
/// identified only by that provider's mark.
///
/// §2: a 96×96 tile with no fill, a 1pt `color-neutral-600` stroke inside the box, corner
/// radius `radius-card`, and one centred 24×24 slot holding the provider mark — or, while
/// `loading`, C-076 ActivitySpinner at its defaults (OQ-C-104-001, owner 2026-10-08).
///
/// §2 / R-16: the tile is intrinsic 96×96 on both axes ("the one row that does not fill the
/// width it is given"); it paints no background and adds no outer padding — the consumer
/// centres it.
struct AuthProviderButton: View {

    /// C-104 §4 `provider` — `google` is the only case (ruled Google only, OQ-login-004); the
    /// enum is the variation point for a later provider (R-06, R-36 nested).
    enum Provider {
        case google

        /// §2 Accessibility (R-17): the label derives from the provider.
        var accessibilityLabel: String {
            switch self {
            case .google: return "Continue with Google"
            }
        }
    }

    /// C-104 §4 `provider` — selects the mark and the accessibility label. Required (R-07).
    let provider: Provider
    /// C-104 §4 `loading` — `true` → §3 loading: the spinner replaces the mark, taps swallowed.
    var loading: Bool = false
    /// C-104 §4 `onTap` — called once per tap when `loading == false`; never while loading
    /// (R-03: one closure per action, no-op default).
    var onTap: () -> Void = {}

    /// R-02: press feedback is ephemeral and never a prop (§4) — `pressed ? 0.6 : 1`.
    @State private var pressed = false

    var body: some View {
        ZStack {
            tile
            slot
        }
        .frame(width: Self.side, height: Self.side)
        // §3 pressed (OQ-C-104-001): the whole tile — stroke and slot — at 0.6 while the finger
        // is down; loading stays at 1.0 ("the spinner is the feedback; no dimming").
        .opacity(pressed ? Self.pressedOpacity : 1)
        // §2 hit target: the tile's own 96×96 frame.
        .contentShape(Rectangle())
        .onTapGesture {
            // §4 `onTap`: called once per tap when `loading == false`; never while loading.
            if !loading { onTap() }
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
        // §2 Accessibility (R-17): one button, labelled by the provider; its value is
        // "Signing in" and it is not enabled while loading (which also swallows the taps).
        // The C-076 spinner inside is accessibilityHidden (OQ-C-076-003) — this tile labels
        // the region.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(provider.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(loading ? "Signing in" : "")
        .disabled(loading)
        .ui2Element("AuthProviderButton")             // capture element map — UI2Element.swift
    }

    /// §2 tile: 96×96, no fill, 1pt `color-neutral-600` stroke on all four sides, corner radius
    /// `radius-card`; unchanged in every state. Deviation 3: Figma draws the stroke inside the
    /// box, so `strokeBorder` insets the ring by half its width and the outer size stays 96×96.
    private var tile: some View {
        RoundedRectangle(cornerRadius: Token.Radius.card)
            // FLAGGED LITERAL — C-104 §2: 1pt stroke width, no stroke-width token family.
            .strokeBorder(Token.neutral600, lineWidth: 1)
            .ui2Element("Tile")
    }

    /// §2 centred 24×24 slot (36pt from every edge — derived from centring, not a spacing
    /// token): the provider mark while idle / pressed; C-076 ActivitySpinner at its contract
    /// defaults (24 / 2 / `color-accent`, clockwise 1.0 s) while loading — the mark is not
    /// drawn then.
    private var slot: some View {
        Group {
            if loading {
                ActivitySpinner()
            } else {
                providerMark
            }
        }
        .frame(width: Self.slotSide, height: Self.slotSide)
        .ui2Element("Slot")
    }

    /// §2 / §5 (OQ-C-104-002, owner 2026-10-08: "Google logo should be in our glyph library"):
    /// the provider mark is the library glyph `google` drawn with `Glyph(.google)` at 24×24 —
    /// `GlyphSize.md`. The glyph is full-colour (`isTemplate == false`), so it renders in its
    /// own four colours, never tinted and never as a template image. §5 retires the
    /// `ProviderMark` part; the glyph is the slot's content, not a part of its own.
    @ViewBuilder private var providerMark: some View {
        switch provider {
        case .google:
            Glyph(.google, size: .md)
                // §2 Accessibility (R-17): the tile labels the region ("Continue with Google");
                // the glyph's own "google" label must not read a second time.
                .accessibilityHidden(true)
        }
    }

    // FLAGGED LITERAL — C-104 §2: "outer size 96×96 pt, fixed" (`4586:9221` bounds); no sizing
    // token family. Ruled a flagged literal by OQ-C-104-3 (owner, 2026-10-08): no token is minted.
    private static let side: CGFloat = 96
    // FLAGGED LITERAL — C-104 §2: "centred slot 24×24 at (36,36)" (`4586:9215` bounds); no sizing
    // token family. Ruled a flagged literal by OQ-C-104-3 (owner, 2026-10-08): no token is minted.
    private static let slotSide: CGFloat = 24
    // FLAGGED LITERAL — C-104 §2: 0.6 pressed opacity (ruled OQ-login-002 → OQ-C-104-001); no
    // opacity token family.
    private static let pressedOpacity: Double = 0.6
}
