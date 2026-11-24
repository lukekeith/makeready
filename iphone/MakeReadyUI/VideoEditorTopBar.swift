//
//  VideoEditorTopBar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-157-videoeditortopbar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-157 VideoEditorTopBar — "Editor top bar: Cancel, Undo (dimmed when nothing to undo), Done."
///
/// §2: a 56 pt bar; Cancel leading, Done trailing, Undo centred on the bar's full width.
/// Width-driven, chrome-free (R-16).
///
/// Controlled (R-01): the only internal state is pressed feedback (R-02). It reports three taps;
/// what they mean is the caller's (R-03, R-04).
struct VideoEditorTopBar: View {
    /// §2 Copy.
    static let cancelLabel = "Cancel"
    /// §2 Copy — spoken only.
    static let undoLabel = "Undo"
    static let doneLabel = "Done"

    /// §4: false dims Undo and stops its tap.
    let canUndo: Bool
    /// §4: Cancel was tapped.
    var onCancel: () -> Void = {}
    /// §4: Undo was tapped; never fires while `canUndo` is false.
    var onUndo: () -> Void = {}
    /// §4: Done was tapped.
    var onDone: () -> Void = {}

    private enum Geometry {
        /// FLAGGED LITERAL — C-157 §2 FL-1: 56 height, no size token.
        static let height: CGFloat = 56
        /// FLAGGED LITERAL — C-157 §2 FL-2: 24 glyph, no size token.
        static let glyph: CGFloat = 24
        /// FLAGGED LITERAL — C-157 §2 FL-3: 44 hit area, no size token.
        static let hitArea: CGFloat = 44
        /// §2 Pressed: the house pressed rule (C-013, C-147, C-155), no token.
        static let pressedOpacity: Double = 0.6
    }

    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? Geometry.pressedOpacity : 1)
        }
    }

    var body: some View {
        // Stacked, not in a row: Undo is centred on the bar whatever the labels measure (§2).
        ZStack {
            label(Self.cancelLabel, color: Token.textPrimary, action: onCancel)
                .frame(maxWidth: .infinity, alignment: .leading)
            undo
            label(Self.doneLabel, color: Token.accent, action: onDone)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, Token.Space.pageMargin)
        .frame(height: Geometry.height)
        .accessibilityElement(children: .contain)
        .ui2Element("VideoEditorTopBar")
    }

    /// §2 Cancel / Done: one line in a 24 pt line box; the hit area is the text's width × 44.
    private func label(_ text: String, color: Color, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            Text(text)
                .designTextStyle(Token.TypeStyle.navAction)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .frame(height: Token.TypeStyle.navAction.lineHeight)
                .ui2Element(text)
                .frame(height: Geometry.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel(text)
    }

    /// §2 Undo: stays in place when there is nothing to undo — dimmed, no tap, no pressed look.
    private var undo: some View {
        SwiftUI.Button(action: onUndo) {
            Glyph(.undo2, size: .md, tint: canUndo ? Token.textPrimary : Token.white50)
                .accessibilityHidden(true)
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .ui2Element(Self.undoLabel)
                .frame(width: Geometry.hitArea, height: Geometry.hitArea)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressedDim())
        .disabled(!canUndo)
        .animation(nil, value: canUndo)          // §2 Motion: the tint swaps in place.
        .accessibilityLabel(Self.undoLabel)
    }
}
