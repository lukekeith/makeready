//
//  GlyphButton.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-021-glyph-button in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
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
/// Chrome-free: it paints no background and adds no outer padding. It lays out at the 24pt
/// glyph and owns its 44pt tap area through an expanded content shape (OQ-C-021-001).
struct GlyphButton: View {

    /// C-021 §3 — the closed set of nine designed glyphs. Raw values are the contract's
    /// own names, which are also the asset-catalog names and the fixture's prop values.
    enum Glyph: String, CaseIterable {
        case export, settings, back, add, send
        case arrowForward = "arrow-forward"
        case threeDots = "three-dots"
        case search, calendar

        /// R-17: every interactive element carries a label. The contract names no strings,
        /// so each is the glyph's §3 geometry word in plain English.
        var accessibilityLabel: String {
            switch self {
            case .export: "Export"
            case .settings: "Settings"
            case .back: "Back"
            case .add: "Add"
            case .send: "Send"
            case .arrowForward: "Forward"
            case .threeDots: "More"
            case .search: "Search"
            case .calendar: "Calendar"
            }
        }
    }

    // GAP — C-021 §2: "Visual size: 24×24"; no glyph-size token yet. OQ-C-021-4 (owner,
    // 2026-10-20): mint `size-glyph` = 24 and cite it — this becomes that token's member
    // once a spec run lands the row.
    private static let visualSize: CGFloat = 24
    // GAP — C-021 §2: "Hit target: 44pt minimum, extending beyond the 24pt visual bounds";
    // no hit-target token yet. Normative for every host by OQ-C-021-2 (owner, 2026-09-16);
    // OQ-C-021-4 (owner, 2026-10-20): mint `size-hit-target` = 44 and cite it.
    private static let hitTarget: CGFloat = 44

    /// C-021 §4: `glyph` — which of the nine designed vectors renders.
    let glyph: Glyph
    /// C-021 §4: `action`, spelled `onTap` by R-33 — invoked on tap; carries no render
    /// effect. A defaulted no-op so the promoted view keeps its real signature.
    var onTap: () -> Void = {}

    var body: some View {
        SwiftUI.Button(action: onTap) {
            Image(glyph.rawValue, bundle: .ui2Preview)
                // The catalog marks every glyph template-rendering, so the vector is a
                // mask and the tint below is the whole of its colour (§2, OQ-C-064-7).
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.visualSize, height: Self.visualSize)
                .foregroundStyle(Token.accent)          // §2: tint `color-accent`
                .ui2Element("Glyph (\(glyph.rawValue))")
                // OQ-C-021-001 (owner, 2026-09-16): the component owns its 44pt tap area
                // via an expanded content shape on a 24pt layout frame — containers add
                // nothing, and consumers' geometry (C-040's 16 + 24 + 16 bar) is unchanged.
                .contentShape(Rectangle().inset(by: -(Self.hitTarget - Self.visualSize) / 2))
        }
        // OQ-C-021-1 (owner, 2026-09-16): pressed = the system highlight, no geometry
        // change; there is no disabled state — a consumer with no action omits the button.
        .buttonStyle(.plain)
        .background(Token.transparent)                  // §2: no background
        .accessibilityLabel(glyph.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .ui2Element("GlyphButton")
    }
}
