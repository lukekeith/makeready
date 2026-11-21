//
//  RecorderCompactView.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-017-recorder-compact-view in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-017 RecorderCompactView — the recorder sheet's compact-detent content: the memo's title,
/// the running timer, C-011's live waveform and a single stop button, so the leader can see the
/// memo is recording without the sheet covering the screen they were on. Stop saves the memo
/// exactly as Done does (memo-screens D3).
///
/// §2 structure: one vertical stack, every child horizontally centred, filling the width it is
/// given with an intrinsic 250 pt height (R-16); no background, no outer padding. The sheet's
/// fill, grabber, insets and drag belong to C-016. Display-only (R-01): no timer, audio or
/// navigation (R-04/R-19) — the caller feeds `elapsed` and `samples`.
struct RecorderCompactView: View {

    // MARK: - Props (§4, R-05 order)

    /// §4 `title` — the memo's title (`Memo {n}`); one line, truncated. Required (R-07).
    let title: String
    /// §4 `elapsed` — seconds recorded so far; formatted per §2 item 3. Required.
    let elapsed: TimeInterval
    /// §4 `samples` — levels 0…1, oldest first, ≈20 Hz; passed straight to C-011. Required.
    let samples: [Float]
    /// §4 `onStop` — the stop button was tapped; the caller stops and saves, as Done does (D3).
    var onStop: () -> Void = {}

    // MARK: - Geometry

    private enum Geometry {
        /// FLAGGED LITERAL — C-017 §2 FL-1: 58 pt stop circle (measured 174 px at 3×).
        static let stopCircle: CGFloat = 58
        /// FLAGGED LITERAL — C-017 §2 FL-2: 24 pt stop square.
        static let stopSquare: CGFloat = 24
        /// GAP — C-017 §2 item 7: "a 1 pt `color-white-10` stroke"; no stroke token.
        static let stroke: CGFloat = 1
        /// GAP — C-017 §2 Motion / OQ-C-017-3: "dims to 0.6 opacity while pressed"; no opacity token.
        static let pressedOpacity: Double = 0.6
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleText
            Spacer().frame(height: Token.Space.metaGap)
            timerText
            Spacer().frame(height: Token.Space.sectionGap)
            LiveWaveformView(samples: samples)
                .ui2Element("Waveform")
            Spacer().frame(height: Token.Space.sectionGap)
            stopButton
        }
        .frame(maxWidth: .infinity)
        // §2 Motion: a new elapsed/samples value re-renders without implicit animation.
        .transaction { $0.animation = nil }
        .ui2Element("RecorderCompactView")     // capture element map — UI2Element.swift
    }

    /// §2 item 1: `type-value-emphasis`, `color-text-primary`, one line, centred, tail-truncated.
    private var titleText: some View {
        Text(title)
            .designTextStyle(Token.TypeStyle.valueEmphasis)
            .foregroundStyle(Token.textPrimary)
            .lineLimit(1)
            .truncationMode(.tail)
            // §2 item 1: a 24 pt line box — the token's own line height.
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: Self.lineBox(Token.TypeStyle.valueEmphasis))
            .accessibilityAddTraits(.isHeader)
            .ui2Element("Title")
    }

    /// §2 item 3: `type-body-sm`, monospaced digits, `color-text-secondary`, centred.
    private var timerText: some View {
        Text(RecorderExpandedView.timer(elapsed))
            .monospacedDigit()
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            // §2 item 3: a 20 pt line box — the token's own line height.
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: Self.lineBox(Token.TypeStyle.bodySm))
            .accessibilityLabel("Recording, \(RecorderExpandedView.spoken(elapsed))")
            .accessibilityAddTraits(.updatesFrequently)
            .ui2Element("Elapsed timer")
    }

    /// §2 item 7: a ringed 58 pt circle holding a 24 pt `color-error` square with
    /// `radius-step-4` corners. The whole circle is the hit target.
    private var stopButton: some View {
        SwiftUI.Button(action: onStop) {
            RoundedRectangle(cornerRadius: Token.Radius.step4, style: .continuous)
                .fill(Token.error)
                .frame(width: Geometry.stopSquare, height: Geometry.stopSquare)
                .ui2Element("Stop square")
                .frame(width: Geometry.stopCircle, height: Geometry.stopCircle)
                .overlay(Circle().strokeBorder(Token.white10, lineWidth: Geometry.stroke))
                .contentShape(Circle())
                .accessibilityHidden(true)
        }
        .buttonStyle(PressedDim())
        .accessibilityLabel("Stop recording")
        .accessibilityHint("Saves the memo")
        .accessibilityAddTraits(.isButton)
        .ui2Element("StopButton")
    }

    /// A single-line text's line box is its type token's line height.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat { style.lineHeight ?? style.size }

    /// OQ-C-017-3 (R-02, internal): the whole button dims while pressed, no scale.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? Geometry.pressedOpacity : 1)
        }
    }
}
