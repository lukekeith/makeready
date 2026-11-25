//
//  RailTool.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-147-rail-tool in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-147 RailTool — one camera-rail button: a 24 pt glyph in a 40 × 50 slot with the tool's
/// label beside it on the leading side, over the live camera preview.
///
/// Controlled (R-01): the value, on-ness and enabled state are the caller's; the view holds only
/// its pressed feedback (R-02). It emits one tap and decides nothing (R-03, R-04). Width-driven
/// (R-16): fills the width it is given, content trailing-aligned, intrinsic height 50; it paints
/// no background — the C-146 capsule behind the slot is the rail's.
struct RailTool: View {

    /// C-147 §2 "Tool → glyph and label" (closed; library glyphs, OQ-C-147-4).
    enum Tool {
        case flip, countdown, length, filters, teleprompter
        /// Review's Edit (OQ-video-recorder-44); never on the rail.
        case edit

        /// §2: flip→refresh-cw, countdown→clock, length→arrow-left-right, filters→palette,
        /// teleprompter→file-text; edit→edit (OQ-video-recorder-44).
        var glyph: GlyphName {
            switch self {
            case .flip: return .refreshCw
            case .countdown: return .clock
            case .length: return .arrowLeftRight
            case .filters: return .palette
            case .teleprompter: return .fileText
            case .edit: return .edit
            }
        }

        /// §2: the tool's name — also the accessibility label (§2 Accessibility).
        var name: String {
            switch self {
            case .flip: return "Flip"
            case .countdown: return "Countdown"
            case .length: return "Length"
            case .filters: return "Filters"
            case .teleprompter: return "Teleprompter"
            case .edit: return "Edit"
            }
        }
    }

    /// C-147 §4 `tool` — picks the glyph and the label.
    let tool: Tool
    /// C-147 §4 `value` — shown in the label instead of the name ("3s", "1:00"); nil shows the
    /// name (OQ-C-147-2).
    var value: String?
    /// C-147 §4 `active` — the tool is on: glyph and label in `color-accent` (OQ-C-147-3).
    var active: Bool = false
    /// C-147 §4 `enabled` — false draws `color-white-50` and ignores taps (D3, OQ-C-147-3).
    var enabled: Bool = true
    /// `labelsVisible` (video-polish D7) — false fades the label out; the glyph, the slot and the
    /// hit target stay. The caller times it and supplies the animation.
    var labelsVisible: Bool = true
    /// C-147 §4 `onTap` — the one action; the caller decides what it means. No render effect;
    /// defaulted to a no-op (R-03).
    var onTap: () -> Void = {}

    /// C-147 §2 Slot geometry.
    private enum Geometry {
        /// FLAGGED LITERAL — C-147 §2 FL-1: 40 × 50, the rail's column width × pitch, no size token.
        static let slotWidth: CGFloat = 40
        /// FLAGGED LITERAL — C-147 §2 FL-1: 40 × 50, the rail's column width × pitch, no size token.
        static let slotHeight: CGFloat = 50
    }

    /// §2 Pressed: "glyph and label at 0.6 opacity while the finger is down" — the house rule
    /// C-013 uses. Ephemeral (R-02); a custom style so the dim is the ruling's value, not `.plain`'s.
    private struct PressedDim: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label.opacity(configuration.isPressed ? RailTool.pressedOpacity : 1)
        }
    }

    /// §2 Pressed: the ruling's 0.6, multiplying the tool's own paint.
    private static let pressedOpacity: Double = 0.6

    /// §2 Glyph / Label paint: default `color-text-primary`, active `color-accent`, disabled
    /// `color-white-50` (OQ-C-147-3). Disabled wins over active: an untappable tool reads as off.
    private var paint: Color {
        if !enabled { return Token.white50 }
        return active ? Token.accent : Token.textPrimary
    }

    /// §2 Label text: the value when set, otherwise the tool's name (OQ-C-147-2).
    private var labelText: String {
        value ?? tool.name
    }

    var body: some View {
        SwiftUI.Button(action: onTap) {
            HStack(spacing: Token.Space.elementGap) {
                // §2 Label: one line, right-aligned, trailing edge `space-element-gap` before the
                // slot, vertically centred on the glyph; never truncates.
                Text(labelText)
                    .designTextStyle(Token.TypeStyle.footnote)
                    .foregroundStyle(paint)
                    .lineLimit(1)
                    .fixedSize()
                    // §2: text shadow `elevation-thumb` so it reads over any camera image.
                    .designShadow(Token.Elevation.thumb)
                    .opacity(labelsVisible ? 1 : 0)
                    .ui2Element(value == nil ? "Label" : "Value")
                // §2 Slot: 40 × 50 at the trailing edge, paint none; Glyph 24 × 24 centred,
                // template paint (C-021's `md` size, deviation 1).
                Glyph(tool.glyph, size: .md, tint: paint)
                    .accessibilityHidden(true)
                    .ui2Element("Glyph")
                    .frame(width: Geometry.slotWidth, height: Geometry.slotHeight)
                    .ui2Element("Slot")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            // §2: the whole row is the hit target (≥ 44 pt tall).
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedDim())
        // §2 Disabled: no tap, no pressed look.
        .disabled(!enabled)
        // §2 Accessibility: one button — label = the name, value = `value` when set,
        // `.isSelected` when active, not enabled when `enabled` is false.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tool.name)
        .accessibilityValue(value ?? "")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .ui2Element("RailTool")
    }
}
