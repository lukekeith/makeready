//
//  PageHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-040-page-header.md (§2 geometry, §3
//  states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  DEPENDENCY: C-021 GlyphButton resolves at LEVEL 1 (preview-build.md §4) as of
//  2026-09-07 — it has its own contract, its own preview view, and the real Figma vectors
//  in Resources/Glyphs.xcassets. The inline stand-in this file used to carry (SF Symbols
//  substituting for artwork that existed only in Figma) is gone, and with it the
//  substitution gap the earlier build reported.
//

import SwiftUI

/// C-040 PageHeader — the 56pt bar at the top of a pushed page.
struct PageHeader: View {

    /// §4 `style` — the variant axis.
    enum Style {
        case standard      // §3 `Default`; `default` is a Swift keyword
        case textButtons
        case twoIcons
    }

    let style: Style
    let title: String?
    let showTitle: Bool
    let showIcons: Bool
    /// §4 `leadingGlyph` — any C-021 glyph, delegated to that contract (OQ-C-040-6 resolved
    /// 2026-09-07). Designed value: `back`.
    var leadingGlyph: GlyphButton.Glyph = .back
    /// §4 `rightButtons` — the trailing glyphs in order. Designed: `[settings]` for
    /// `default`, `[export, settings]` for `twoIcons`.
    var rightButtons: [GlyphButton.Glyph] = [.export, .settings]
    // Interaction-bearing props have no render effect; emitted as no-ops so the promoted
    // view keeps its real signature (preview-build.md OQ-PB-3's proposed default). A slot
    // whose glyph is a free prop cannot keep a glyph-NAMED callback (§4, OQ-C-040-8), so
    // the trailing handler is told which glyph was tapped.
    var onLeading: () -> Void = {}
    var onRightButton: (GlyphButton.Glyph) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            leading.ui2Element("Leading")
            Spacer(minLength: 0)
            trailing.ui2Element("Trailing")
        }
        .padding(Token.Space.pageMargin)              // §2: padding 16
        .frame(height: 56)                               // §2: 56 = 16 + 24 + 16. Anatomy.
        .background(Token.transparent)                // §2: no background, no hairline
        // §1 deviation 3 + 4: the source places the title at left calc(50% + 0.5px) and 2pt
        // low in two symbols; §2 contracts it as optically centred in all three.
        .overlay(alignment: .center) { titleView }
        .ui2Element("PageHeader")                     // capture element map — UI2Element.swift
    }

    @ViewBuilder private var leading: some View {
        switch style {
        case .standard, .twoIcons:
            GlyphButton(glyph: leadingGlyph, action: onLeading)
        case .textButtons:
            Text("Cancel")                               // §1 deviation 1: a designed label
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(Token.white50)
                .ui2Element("Cancel")
        }
    }

    @ViewBuilder private var trailing: some View {
        switch style {
        case .standard:
            // §2 + OQ-C-040-1: `showIcons` does NOT gate Default's trailing icon. The
            // glyph list is the same prop as `twoIcons` uses; §3 pins Default's designed
            // value to a single `settings`.
            trailingGroup
        case .textButtons:
            Text("Done")
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(Token.accent)
                .ui2Element("Done")
        case .twoIcons:
            if showIcons { trailingGroup }
        }
    }

    /// The trailing glyph row — one builder for both styles that show glyphs, because the
    /// glyphs are now the same prop; only the `showIcons` gate differs (§3).
    @ViewBuilder private var trailingGroup: some View {
        HStack(spacing: Token.Space.rowGap) {          // §2: gap 24
            ForEach(rightButtons, id: \.self) { glyph in
                GlyphButton(glyph: glyph) { onRightButton(glyph) }
            }
        }
    }

    @ViewBuilder private var titleView: some View {
        if showTitle, let title {
            Text(title)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)                            // §3: single line, no wrap
                .ui2Element("Title")
        }
    }
}
