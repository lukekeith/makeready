//
//  TransportControls.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-014-transportcontrols in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-014 TransportControls — the memo player's ⟲15 · play/pause · 15⟳ row, centred as a group.
///
/// Controlled (R-01): the caller owns `playing` and feeds it back in from `onPlayingChange`;
/// a skip only reports the tap, and the caller's player seeks ±15 s clamped to [0, duration]
/// (R-04, memo-screens D13). Width-driven and chrome-free (R-16): the 208 × 56 pt group is
/// centred in the width it is given, with no background and no outer padding. Normative
/// source is markdown only (D72): there is no Figma picture.
struct TransportControls: View {
    /// §4 — true while the memo plays: the centre control shows pause, labelled "Pause".
    let playing: Bool
    /// §4 — false while the audio isn't available yet: the `disabled` state (R-07 default).
    var enabled: Bool = true
    /// §4 — called with `!playing` when the centre control is tapped.
    var onPlayingChange: (Bool) -> Void = { _ in }
    /// §4 — called when ⟲15 is tapped.
    var onSkipBack: () -> Void = {}
    /// §4 — called when 15⟳ is tapped.
    var onSkipForward: () -> Void = {}

    // FLAGGED LITERAL — C-014 §2 FL-1: 44×44 pt skip hit area (OQ-C-014-1 ratified).
    private let skipHitArea: CGFloat = 44
    // FLAGGED LITERAL — C-014 §2 FL-2: 28 pt skip glyph (OQ-C-014-1 ratified).
    private let skipGlyph: CGFloat = 28
    // FLAGGED LITERAL — C-014 §2 FL-3: 56×56 pt play/pause hit area (OQ-C-014-1 ratified).
    private let playHitArea: CGFloat = 56
    // FLAGGED LITERAL — C-014 §2 FL-4: 32 pt play/pause glyph (OQ-C-014-1 ratified).
    private let playGlyph: CGFloat = 32

    /// §2 Paint: `color-text-primary`, `color-white-30` while disabled (§1 deviation 3).
    private var paint: Color { enabled ? Token.textPrimary : Token.white30 }

    /// §1 deviation 4: while disabled the centre control always shows play.
    private var showsPause: Bool { playing && enabled }

    var body: some View {
        HStack(spacing: Token.Space.sectionGap) {
            skipButton(
                glyph: .rotateCcw,
                label: "Skip back 15 seconds",
                element: "Skip back",
                action: onSkipBack
            )
            playPauseButton
            skipButton(
                glyph: .rotateCw,
                label: "Skip forward 15 seconds",
                element: "Skip forward",
                action: onSkipForward
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: playHitArea)
        .ui2Element("TransportControls")
    }

    // MARK: - §2 controls

    private func skipButton(
        glyph: GlyphName,
        label: String,
        element: String,
        action: @escaping () -> Void
    ) -> some View {
        styled(
            SwiftUI.Button(action: action) {
                ZStack {
                    glyphImage(glyph, size: skipGlyph)
                    // §2 / OQ-C-014-2: the `15` centred in the ring, monospaced digits.
                    Text("15")
                        .monospacedDigit()
                        .designTextStyle(Token.TypeStyle.captionBold)
                        .foregroundStyle(paint)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityHidden(true)
                        .ui2Element("Skip label")
                }
                .frame(width: skipHitArea, height: skipHitArea)
                .contentShape(Rectangle())
            }
        )
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .ui2Element(element)
    }

    private var playPauseButton: some View {
        styled(
            SwiftUI.Button { onPlayingChange(!playing) } label: {
                // §2: the glyph swaps with no transition of its own.
                glyphImage(showsPause ? .pauseFilled : .playFilledAltCarbon, size: playGlyph)
                    .frame(width: playHitArea, height: playHitArea)
                    .contentShape(Rectangle())
                    .transaction { $0.animation = nil }
            }
        )
        .accessibilityLabel(showsPause ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
        .ui2Element("Play/pause")
    }

    private func glyphImage(_ glyph: GlyphName, size: CGFloat) -> some View {
        Image(glyph.rawValue, bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(paint)
            .accessibilityHidden(true)   // §2: glyphs are hidden from VoiceOver
            .ui2Element("Glyph")
    }

    /// §2 Pressed: the system plain-button highlight (R-02), no geometry change. While disabled
    /// no tap fires; `.disabled` also carries the not-enabled trait, and `DisabledStyle` keeps
    /// the plain style from dimming `color-white-30` a second time.
    @ViewBuilder private func styled<Content: View>(_ button: Content) -> some View {
        if enabled {
            button.buttonStyle(.plain)
        } else {
            button.buttonStyle(DisabledStyle()).disabled(true)
        }
    }

    private struct DisabledStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}
