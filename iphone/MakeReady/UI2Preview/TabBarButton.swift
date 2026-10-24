//
//  TabBarButton.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from C-083-tabbarbutton in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-083 TabBarButton — one glyph-only tab of the app-level bottom C-084 TabBar.
/// Renamed from NavBarButton by OQ-C-083-003 (the ID is unchanged).
///
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// fixed 84pt height, and paints no background. Controlled (R-01): C-084 owns `active`.
struct TabBarButton: View {

    // FLAGGED LITERAL — C-083 §2: height 84, no size token (OQ-C-083-002: fixed as drawn).
    private static let height: CGFloat = 84
    // FLAGGED LITERAL — C-083 §2: glyph 22×22, no size token.
    private static let glyphSize: CGFloat = 22

    /// C-083 §4: `glyph` — the library glyph drawn at 22pt.
    let glyph: GlyphName
    /// C-083 §4: `accessibilityLabel` — VoiceOver only, never drawn (R-17).
    let accessibilityLabel: String
    /// C-083 §4: `active` — Figma `state=Active`; the delta is colour only.
    let active: Bool
    /// C-083 §4: `onTap` — no render effect; C-084 / shell-tabs decides its meaning (R-03).
    var onTap: () -> Void = {}

    var body: some View {
        // OQ-C-083-001: no pressed look — `.plain` draws no press feedback, and a change of
        // `active` switches the tint instantly (no animation).
        SwiftUI.Button(action: onTap) {
            Image(glyph.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.glyphSize, height: Self.glyphSize)
                // §2: `active == false` → color-white-50; `active == true` → color-white-100.
                .foregroundStyle(active ? Token.white100 : Token.white50)
                .accessibilityHidden(true)
                .ui2Element("Glyph")
                // §2: padding `space-card-padding` top, leading and trailing; glyph top-aligned.
                .padding(.top, Token.Space.cardPadding)
                .padding(.horizontal, Token.Space.cardPadding)
                .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .top)
                // OQ-C-083-002: the whole 84-tall cell is tappable.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .clipped()                                      // §2: the Figma node clips
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("TabBarButton")
    }
}
