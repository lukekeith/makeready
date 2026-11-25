//
//  RowSwitchStyle.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Extracted from screen video-recorder §2d (the Sound switch); shared with C-066 ActionMenuOverlay.
//

import SwiftUI

/// The switch row (video-recorder §2d Sound, C-066 Confirmation toggle): the iOS switch's geometry in tokens — the system control's knob is drawn
/// by the render server and comes out missing in a capture.
struct RowSwitchStyle: ToggleStyle {
    let animation: Animation?

    /// GAP — video-recorder §2d: the iOS switch, 51 × 31 with a 27 pt knob inset 2; no size token.
    private static let track = CGSize(width: 51, height: 31)
    private static let knob: CGFloat = 27
    private static let knobInset: CGFloat = 2

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        SwiftUI.Button { configuration.isOn.toggle() } label: {
            HStack(spacing: Token.Space.stackGap) {
                configuration.label
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Capsule()
                    .fill(configuration.isOn ? Token.accent : Token.white20)
                    .frame(width: Self.track.width, height: Self.track.height)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Token.textPrimary)
                            .frame(width: Self.knob, height: Self.knob)
                            .padding(Self.knobInset)
                    }
                    // §2d "dimmed", at C-147's disabled 50 % (`color-white-50`).
                    .opacity(isEnabled ? 1 : 0.5)
                    .animation(animation, value: configuration.isOn)
                    .ui2Element("Switch")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // One switch to VoiceOver: its own label, value and on/off action.
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
