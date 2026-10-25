//
//  SuggestionRows.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-078-suggestion-rows in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-078 SuggestionRows — "a divided stack of suggestion rows".
///
/// The owner's drawing note (§0): "The container will contain the SuggestionRow stacked with
/// a single line between each one, the line is not part of the SuggestionRow, it's a divider
/// this component produces." §2: "A vertical stack, full container width (deviation 1),
/// **gap 0** … For each suggestion, in order: **Divider** … **C-050 SuggestionRow**."
/// Chrome-free and width-driven (R-16): it fills the width it is given, paints no background
/// and adds no outer padding — C-051 owns the inset. Height n × 56 at one title line per row.
struct SuggestionRows: View {

    /// C-078 §4: `suggestions` — "the row titles in order; element i becomes the i-th C-050
    /// `title` (composition by position). Identity is position, so two equal strings are two
    /// rows." Required: no frame shows a default for it (R-07).
    let suggestions: [String]
    /// C-078 §4: `onPick` — "raised with the row's title when that row's C-050 `onAdd` fires;
    /// the consumer decides what a pick means." Interaction-bearing with no render effect, so
    /// it is emitted as a defaulted no-op closure (R-03) and the promoted view keeps its real
    /// signature.
    var onPick: (String) -> Void = { _ in }

    // FLAGGED LITERAL — C-078 §2: "a full-width **1pt** stroke in `color-layout-border` … (The
    // 1pt stroke width is a flagged literal — the era has no stroke-width token; the colour is
    // the token.)"
    private static let dividerWidth: CGFloat = 1

    var body: some View {
        // §2: "**gap 0**" — the rows sit exactly one C-050 height apart; the divider takes no
        // layout height, so the pitch is C-050's alone ("Row pitch = the C-050 height").
        // OQ-C-078-002 (ruled 2026-09-22): "No cap of its own: SuggestionRows stacks every row
        // it is handed" — no prefix here; the three-row limit stays C-051's (OQ-C-051-3).
        // OQ-C-078-003 (ruled 2026-09-22): an empty list renders "nothing — zero height, no
        // hairline, no placeholder" — an empty ForEach in a zero-spacing VStack is exactly that.
        VStack(spacing: 0) {
            // §4: "Identity is position" — enumerate on the offset, never on the string.
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, title in
                // §2: "**C-050 SuggestionRow** — `title` = the suggestion, `onAdd` → this
                // component's `onPick(title)`. C-050 draws no separator of its own (C-050
                // deviation 2); the line is this component's."
                SuggestionRow(title: title, onAdd: { onPick(title) })
                    // OQ-C-078-001 (ruled 2026-09-22): "SuggestionRows draws one hairline
                    // ABOVE every row including the first (n lines, none below the last)."
                    // §2: "It occupies **no layout height** … the build paints it as an
                    // overlay on the row's top edge (a 1pt rectangle offset −0.5), never as a
                    // 1pt sibling in the stack" — Figma's `inset -0.5`, centred on the boundary.
                    .overlay(alignment: .top) {
                        divider.ui2Element("Divider \(index + 1)")
                    }
                    .ui2Element("Row \(index + 1)")
            }
        }
        // §2 / R-16: fills the width it is given; the intrinsic height is the rows' own.
        .frame(maxWidth: .infinity)
        .ui2Element("SuggestionRows")                             // capture element map — UI2Element.swift
    }

    /// §2: "a full-width **1pt** stroke in `color-layout-border`, drawn as Figma draws it: a
    /// **0-height** layout box with the line centred on the row boundary (`inset -0.5`)".
    /// R-17 / §2 accessibility: "the dividers are decorative and hidden from assistive tech".
    private var divider: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(height: Self.dividerWidth)
            .offset(y: -Self.dividerWidth / 2)
            .accessibilityHidden(true)
    }
}
