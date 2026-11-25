//
//  DoneCheck.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-159-done-check in d2m (the registry description; extracted from C-040 PageHeader §2).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-159 DoneCheck — the purple Done check: a 32 × 32 `color-accent` circle with a white checkmark
/// and a 44 pt tap target. Used by C-040 PageHeader and by the video recorder's sheets.
struct DoneCheck: View {
    /// The one action; the caller decides what Done means.
    var onTap: () -> Void = {}

    // LITERAL — C-040 §2 (owner, 2026-11-21): the done check is a 32×32 `color-accent` circle.
    private static let size: CGFloat = 32
    // GAP — C-040 §2: 44 pt tap target; no hit-target token yet (OQ-C-021-4).
    private static let hitSize: CGFloat = 44

    var body: some View {
        SwiftUI.Button(action: onTap) {
            Glyph(.checkmarkCarbon, size: .sm, tint: Token.white100)
                .accessibilityHidden(true)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(Token.accent))
                .contentShape(Rectangle().inset(by: -(Self.hitSize - Self.size) / 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
        .accessibilityAddTraits(.isButton)
        .ui2Element("DoneCheck")
    }
}
