//
//  NumberKeypad.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-107-numberkeypad in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-107 NumberKeypad — the on-screen digit pad for entering a phone number.
///
/// A 3-column × 4-row grid of C-108 KeypadKey (§2): `1 2 3` · `4 5 6` · `7 8 9` · `[empty] 0 ⌫`.
/// It has no fill, border or background of its own. The 256pt grid keeps its fixed 96pt pitch and is
/// centred in whatever width it is given (OQ-C-107-002). Its intrinsic height is 398, which includes
/// the 23pt top and bottom inset that belongs to the keypad's own footprint.
///
/// Controlled (R-01): it holds no value. The caller owns the number and formats it. It performs no
/// side effects (R-04): taps leave only through the closures.
struct NumberKeypad: View {

    /// §4 `enabled` — false disables all 11 keys (state `disabled`).
    var enabled: Bool = true
    /// §4 `deleteEnabled` (R-35) — false disables only the delete key (state `delete-disabled`).
    var deleteEnabled: Bool = true
    /// §4 `onDigit` (R-03, R-33) — a digit key was tapped; its value is 0–9.
    var onDigit: (Int) -> Void = { _ in }
    /// §4 `onDelete` — the delete key was tapped.
    var onDelete: () -> Void = {}
    /// §4 `onClear` — the delete key was long-pressed (OQ-invite-member-002).
    var onClear: () -> Void = {}

    /// C-107 §2's placed geometry.
    private enum Geometry {
        /// §2: "each cell is 64×64, and C-108 owns everything inside it". This is C-108's intrinsic
        /// key size. The keypad needs it only for the empty row-4 column-1 cell (deviation 2).
        static let cell: CGFloat = 64
    }

    /// §2 rows 1–3: the digit keys.
    private static let digitRows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: Token.Space.keypadGap) {
            ForEach(Self.digitRows.indices, id: \.self) { rowIndex in
                HStack(spacing: Token.Space.keypadGap) {
                    ForEach(Self.digitRows[rowIndex], id: \.self) { digit in
                        digitKey(digit)
                    }
                }
                .ui2Element("Row \(rowIndex + 1)")
            }
            HStack(spacing: Token.Space.keypadGap) {
                // Deviation 2: the empty cell is a 64×64 spacer with no key and no hit target.
                Color.clear
                    .frame(width: Geometry.cell, height: Geometry.cell)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .ui2Element("Empty cell")
                digitKey(0)
                // Deviation 1 + §4: the delete key. Its enabled value is `enabled && deleteEnabled`.
                KeypadKey(
                    key: .delete,
                    enabled: enabled && deleteEnabled,
                    onTap: onDelete,
                    onLongPress: onClear
                )
                .ui2Element("Delete key")
            }
            .ui2Element("Row 4")
        }
        // §2: the 32/23 inset is part of the keypad's footprint. The 32 is horizontal centring of the
        // 256pt grid, so at the designed width of 320 it is exactly 32. The 23 is padding top and bottom.
        .padding(.vertical, Token.Space.keypadInsetY)
        .frame(maxWidth: .infinity)
        // §4 (R-17): one accessibility container. Layout order gives 1–9, 0, Delete.
        .accessibilityElement(children: .contain)
        .ui2Element("NumberKeypad")
    }

    /// §4 key mapping: a digit cell is C-108 `.digit(n)`, which taps through to `onDigit(n)`.
    private func digitKey(_ digit: Int) -> some View {
        KeypadKey(key: .digit(digit), enabled: enabled, onTap: { onDigit(digit) })
            .ui2Element("Key \(digit)")
    }
}
