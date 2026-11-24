//
//  VideoEditorToolbar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-155-videoeditortoolbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-155 VideoEditorToolbar — "Editor toolbar with Text and Captions actions; Captions shows
/// Transcribing… while working."
///
/// §2: two 112 × 56 tiles centred as a group, Text then Captions. Width-driven, chrome-free (R-16).
///
/// Controlled (R-01): the only internal state is pressed feedback (R-02). It reports two taps;
/// what they mean is the caller's (R-03, R-04).
struct VideoEditorToolbar: View {
    /// §2 Labels.
    static let textLabel = "Text"
    static let captionsLabel = "Captions"
    static let transcribingLabel = "Transcribing…"

    /// §4: Captions shows the spinner and "Transcribing…" and takes no tap.
    let transcribing: Bool
    /// §4: Text was tapped.
    var onText: () -> Void = {}
    /// §4: Captions was tapped; never fires while `transcribing`.
    var onCaptions: () -> Void = {}

    private enum Geometry {
        /// FLAGGED LITERAL — C-155 §2 FL-1: 112 × 56 tile, no size token.
        static let tileWidth: CGFloat = 112
        /// FLAGGED LITERAL — C-155 §2 FL-1: 112 × 56 tile, no size token.
        static let tileHeight: CGFloat = 56
        /// FLAGGED LITERAL — C-155 §2 FL-2: 24 glyph, no size token.
        static let glyph: CGFloat = 24
    }

    /// §2 Pressed: the tile at 0.6 opacity, the house pressed rule (C-013, C-147).
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? VideoEditorToolbar.pressedOpacity : 1)
        }
    }

    private static let pressedOpacity: Double = 0.6

    var body: some View {
        HStack(spacing: Token.Space.buttonGap) {
            SwiftUI.Button(action: onText) {
                tile(Self.textLabel, name: "Text") { glyph(.textFont) }
            }
            .buttonStyle(PressedDim())
            .accessibilityLabel(Self.textLabel)

            SwiftUI.Button(action: onCaptions) {
                tile(transcribing ? Self.transcribingLabel : Self.captionsLabel, name: "Captions") {
                    if transcribing {
                        ActivitySpinner()
                    } else {
                        glyph(.messageCircle)
                    }
                }
            }
            .buttonStyle(PressedDim())
            // §2 Interaction: no tap and no pressed look while transcribing.
            .disabled(transcribing)
            .accessibilityLabel(Self.captionsLabel)
            .accessibilityValue(transcribing ? Self.transcribingLabel : "")
        }
        .frame(maxWidth: .infinity)
        .ui2Element("VideoEditorToolbar")
    }

    /// §2 Tile: the glyph (or spinner) over its label, the pair centred; the whole tile is the hit area.
    private func tile<Mark: View>(
        _ label: String,
        name: String,
        @ViewBuilder mark: () -> Mark
    ) -> some View {
        VStack(spacing: Token.Space.metaGap) {
            mark()
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .ui2Element("\(name) glyph")
            Text(label)
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .ui2Element("\(name) label")
        }
        .frame(width: Geometry.tileWidth, height: Geometry.tileHeight)
        .background(Token.white10, in: RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        .contentShape(Rectangle())
        .ui2Element("\(name) tile")
    }

    private func glyph(_ name: GlyphName) -> some View {
        Glyph(name, size: .md, tint: Token.textPrimary)
            .accessibilityHidden(true)
    }
}
