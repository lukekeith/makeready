//
//  GlyphButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-021-glyph-button.md (§2 geometry, §3
//  states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  ARTWORK: the nine vectors are the ones exported from the normative Figma set
//  (C-021 §1), carried in Resources/Glyphs.xcassets and keyed by the contract's own glyph
//  names — so the asset name IS the §3 value and there is no mapping table to drift. The
//  catalog is the only way iOS renders these: a raw .svg in a bundle is not loadable.
//

import SwiftUI

/// Resolves the framework's own bundle. `Bundle.module` is generated for SwiftPM targets
/// only; an Xcode framework finds its bundle from any class it declares, which is all this
/// token exists for.
private final class BundleToken {}

extension Bundle {
    static let ui2Preview = Bundle(for: BundleToken.self)
}

/// C-021 GlyphButton — the program's single-glyph tappable control.
///
/// Chrome-free: it paints no background and adds no outer padding. Its footprint is the
/// §2 hit target, not the glyph — see `Glyph.hitTarget`.
struct GlyphButton: View {

    /// C-021 §3 — the closed set of nine designed glyphs. Raw values are the contract's
    /// own names, which are also the asset-catalog names and the fixture's prop values.
    enum Glyph: String, CaseIterable {
        case export, settings, back, add, send
        case arrowForward = "arrow-forward"
        case threeDots = "three-dots"
        case search, calendar
    }

    /// C-021 §2: "Visual size: 24×24".
    private static let visualSize: CGFloat = 24
    /// C-021 §2: "Hit target: 44pt minimum, extending beyond the 24pt visual bounds."
    /// Whether 44 is normative or a floor consumers may narrow is OQ-C-021-2 — two
    /// consumers already render smaller slots, so this is the contract's number, not a
    /// measurement of any consumer.
    private static let hitTarget: CGFloat = 44

    /// C-021 §4: `glyph` — which of the nine designed vectors renders.
    let glyph: Glyph
    /// C-021 §4: `action` — invoked on tap; carries no render effect. Emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3's default).
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(glyph.rawValue, bundle: .ui2Preview)
                // The catalog marks every glyph template-rendering, so the vector is a
                // mask and the tint below is the whole of its colour — which is what
                // makes §2's `color-accent` a token here rather than baked-in purple.
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.visualSize, height: Self.visualSize)
                .foregroundStyle(Token.accent)          // §2: tint `color-accent`
                // §2 says the hit target "extends BEYOND the 24pt visual bounds" — so it
                // is an expanded tap shape, NOT a larger frame. A 44pt frame would make
                // the component's layout footprint 44 and push every consumer's geometry
                // out (C-040's 56pt bar is padding 16 + a 24pt glyph, which only adds up
                // while the glyph lays out at 24).
                .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.visualSize) / 2))
        }
        .buttonStyle(.plain)
        .background(Token.transparent)                  // §2: no background
        // Names itself for the capture browser's element map (UI2Element.swift). The
        // glyph is in the name because that is what a consumer's trailing row is made
        // of — "which icon did you mean" is the whole question a comment there asks.
        .ui2Element("GlyphButton (\(glyph.rawValue))")
    }
}
