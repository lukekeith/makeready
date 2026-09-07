//
//  PageHeader.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-040-page-header.md (§2 geometry, §3
//  states, §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//
//  DEPENDENCY: C-021 GlyphButton resolves at level 2 (preview-build.md §4) — its anchor is
//  screens/home-dashboard.md §4 + screens/members-profile.md §4 amendment, which name the
//  glyph, its 24pt size and its purple tint but not the vector artwork (that lives only in
//  Figma set 3499:27547). It has no contract file of its own, so it cannot be a build target
//  and is composed inline below rather than via its own run.
//

import SwiftUI

/// C-021 GlyphButton, inline at level 2. SF Symbols stand in for the Figma vectors, chosen
/// to match the source layer names (`Chevron--left`, `Export`, `settings`); any shape
/// mismatch is a gap for the build report, not something to nudge.
private enum Glyph: String {
    case back, export, settings

    var systemName: String {
        switch self {
        case .back: return "chevron.left"
        case .export: return "square.and.arrow.up"
        case .settings: return "gearshape"
        }
    }
}

private struct GlyphButton: View {
    let glyph: Glyph
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: glyph.systemName)
                .resizable()
                .scaledToFit()
                // C-040 §2: 24×24 visual. Anatomy, not a spacing token.
                .frame(width: 24, height: 24)
                .foregroundStyle(Token.accent)   // C-021 anchor: Purple/100% tint
        }
        .buttonStyle(.plain)
    }
}

/// C-040 PageHeader — the 56pt bar at the top of a pushed page.
struct PageHeader: View {

    /// §4 `style` — the variant axis.
    enum Style {
        case standard      // §3 `Default`; `default` is a Swift keyword
        case textButtons
        case twoIcons
    }

    /// §4 `rightButtons` — closed to [export, settings] as designed (OQ-C-040-6).
    enum RightButton {
        case export, settings
    }

    let style: Style
    let title: String?
    let showTitle: Bool
    let showIcons: Bool
    var rightButtons: [RightButton] = [.export, .settings]
    // Interaction-bearing props have no render effect; emitted as no-ops so the promoted
    // view keeps its real signature (preview-build.md OQ-PB-3's proposed default).
    var onBack: () -> Void = {}
    var onExport: () -> Void = {}
    var onSettings: () -> Void = {}
    var onCancel: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            leading
            Spacer(minLength: 0)
            trailing
        }
        .padding(Token.Space.pageMargin)              // §2: padding 16
        .frame(height: 56)                               // §2: 56 = 16 + 24 + 16. Anatomy.
        .background(Token.transparent)                // §2: no background, no hairline
        // §1 deviation 3 + 4: the source places the title at left calc(50% + 0.5px) and 2pt
        // low in two symbols; §2 contracts it as optically centred in all three.
        .overlay(alignment: .center) { titleView }
    }

    @ViewBuilder private var leading: some View {
        switch style {
        case .standard, .twoIcons:
            GlyphButton(glyph: .back, action: onBack)
        case .textButtons:
            Text("Cancel")                               // §1 deviation 1: a designed label
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(Token.white50)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch style {
        case .standard:
            // §2 + OQ-C-040-1: `showIcons` does NOT gate Default's settings icon.
            GlyphButton(glyph: .settings, action: onSettings)
        case .textButtons:
            Text("Done")
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(Token.accent)
        case .twoIcons:
            if showIcons {
                HStack(spacing: Token.Space.rowGap) {  // §2: gap 24
                    ForEach(rightButtons, id: \.self) { button in
                        switch button {
                        case .export: GlyphButton(glyph: .export, action: onExport)
                        case .settings: GlyphButton(glyph: .settings, action: onSettings)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var titleView: some View {
        if showTitle, let title {
            Text(title)
                .designTextStyle(Token.TypeStyle.pageTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)                            // §3: single line, no wrap
        }
    }
}

extension PageHeader.RightButton: Hashable {}
