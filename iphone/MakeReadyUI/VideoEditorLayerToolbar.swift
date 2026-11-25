//
//  VideoEditorLayerToolbar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-156-videoeditorlayertoolbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-156 VideoEditorLayerToolbar — selected-layer toolbar: Split (40% opacity when disabled), Edit,
/// Delete. No Deselect tile (owner 2026-11-24, video-polish D10).
///
/// §2: three 84 × 56 tiles centred as a group. Width-driven, chrome-free (R-16).
///
/// Controlled (R-01): the only internal state is pressed feedback (R-02). It reports three taps;
/// what they mean is the caller's (R-03, R-04).
struct VideoEditorLayerToolbar: View {
    /// §2 Labels.
    static let splitLabel = "Split"
    static let editLabel = "Edit"
    static let deleteLabel = "Delete"

    /// §4: the selected layer's text, spoken only.
    let text: String
    /// §4: the layer's window start, spoken only.
    let startMs: Int
    /// §4: the layer's window end, spoken only.
    let endMs: Int
    /// §4: false dims Split and stops its tap.
    let canSplit: Bool
    /// §4: Split was tapped; never fires while `canSplit` is false.
    var onSplit: () -> Void = {}
    /// §4: Edit was tapped.
    var onEdit: () -> Void = {}
    /// §4: Delete was tapped.
    var onDelete: () -> Void = {}

    private enum Geometry {
        /// FLAGGED LITERAL — C-156 §2 FL-1: 84 × 56 tile, no size token.
        static let tileWidth: CGFloat = 84
        /// FLAGGED LITERAL — C-156 §2 FL-1: 84 × 56 tile, no size token.
        static let tileHeight: CGFloat = 56
        /// FLAGGED LITERAL — C-156 §2 FL-2: 24 glyph, no size token.
        static let glyph: CGFloat = 24
        /// FLAGGED LITERAL — C-156 §2 FL-3: 0.4 disabled opacity, no token.
        static let disabledOpacity: Double = 0.4
        /// §2 Pressed: the house pressed rule (C-013, C-147, C-155), no token.
        static let pressedOpacity: Double = 0.6
    }

    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? Geometry.pressedOpacity : 1)
        }
    }

    var body: some View {
        HStack(spacing: Token.Space.buttonGap) {
            tile(Self.splitLabel, glyph: .scissors, enabled: canSplit, action: onSplit)
            tile(Self.editLabel, glyph: .pencil, action: onEdit)
            tile(Self.deleteLabel, glyph: .trash2, action: onDelete)
        }
        .frame(maxWidth: .infinity)
        .ui2Element("VideoEditorLayerToolbar")
    }

    /// §2 Tile: the glyph over its label, the pair centred; the whole tile is the hit area.
    private func tile(
        _ label: String,
        glyph: GlyphName,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: action) {
            VStack(spacing: Token.Space.metaGap) {
                Glyph(glyph, size: .md, tint: Token.textPrimary)
                    .accessibilityHidden(true)
                    .frame(width: Geometry.glyph, height: Geometry.glyph)
                    .ui2Element("\(label) glyph")
                Text(label)
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    .ui2Element("\(label) label")
            }
            // OQ-C-156-1: only the glyph and label dim; the tile's fill stays.
            .opacity(enabled ? 1 : Geometry.disabledOpacity)
            .frame(width: Geometry.tileWidth, height: Geometry.tileHeight)
            .background(Token.white10, in: RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
            .contentShape(Rectangle())
            .ui2Element("\(label) tile")
        }
        .buttonStyle(PressedDim())
        // §2 Interaction: no tap and no pressed look while disabled.
        .disabled(!enabled)
        .accessibilityLabel("\(label), \(layer)")
    }

    /// §2 Accessibility: «text», «m:ss» to «m:ss», as C-154's.
    private var layer: String {
        "\(Self.oneLine(text)), \(Self.clock(startMs)) to \(Self.clock(endMs))"
    }

    private static func oneLine(_ text: String) -> String {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func clock(_ milliseconds: Int) -> String {
        let seconds = max(milliseconds, 0) / 1000
        let remainder = seconds % 60
        return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
