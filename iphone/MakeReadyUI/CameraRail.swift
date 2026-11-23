//
//  CameraRail.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-146-camera-rail in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-146 CameraRail — the recorder's right-side tool rail: five C-147 RailTool slots (Flip,
/// Countdown, Length, Filters, Teleprompter) stacked on a translucent dark 40 pt capsule, each
/// tool's label floating to the capsule's left. No chevron, no divider, no title (D1).
///
/// Controlled (R-01): every value is the caller's; the rail holds no state (R-02 — the pressed
/// look is C-147's). One closure per tool (R-03), decides nothing (R-04). Width-driven (R-16):
/// fills the width it is given, content trailing-aligned, intrinsic height 250 (5 × 50); it
/// paints nothing outside its capsule and adds no outer padding — the screen places it.
struct CameraRail: View {

    /// C-146 §4 `countdownValue` — the pre-roll countdown as shown ("3s", "10s"); nil is Off (D2).
    var countdownValue: String?
    /// C-146 §4 `lengthValue` — the chosen length as m:ss ("1:00", D3). Required.
    let lengthValue: String
    /// C-146 §4 `lengthEnabled` — false once the first segment is recorded (D3).
    var lengthEnabled: Bool = true
    /// C-146 §4 `filtersActive` — a filter other than Normal is applied (D6).
    var filtersActive: Bool = false
    /// C-146 §4 `teleprompterActive` — the teleprompter is on (D7).
    var teleprompterActive: Bool = false
    /// C-146 §4 — one closure per tool; no render effect, defaulted to a no-op (R-03).
    var onFlip: () -> Void = {}
    var onCountdown: () -> Void = {}
    var onLength: () -> Void = {}
    var onFilters: () -> Void = {}
    var onTeleprompter: () -> Void = {}

    /// FLAGGED LITERAL — C-146 §2 FL-1: 40 wide, the rail's column width (C-147's FL-1 slot
    /// width); no size token. The height follows from the five 50 pt slots.
    private static let capsuleWidth: CGFloat = 40

    var body: some View {
        // §2 Slots: 5 × C-147 RailTool, stacked with no gap, in the fixed order (closed wiring).
        VStack(spacing: 0) {
            RailTool(tool: .flip, onTap: onFlip)
                .ui2Element("Slot 1")
            RailTool(
                tool: .countdown,
                value: countdownValue,
                active: countdownValue != nil,
                onTap: onCountdown
            )
            .ui2Element("Slot 2")
            RailTool(tool: .length, value: lengthValue, enabled: lengthEnabled, onTap: onLength)
                .ui2Element("Slot 3")
            RailTool(tool: .filters, active: filtersActive, onTap: onFilters)
                .ui2Element("Slot 4")
            RailTool(tool: .teleprompter, active: teleprompterActive, onTap: onTeleprompter)
                .ui2Element("Slot 5")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        // §2 Capsule: 40 × 250, flush with the trailing edge and with the first and last slot;
        // `color-black-60` (OQ-C-146-001), corners `radius-circle` — a capsule, radius = half
        // the width (the token is parsed:false, "50%", so the shape itself carries it).
        .background(alignment: .trailing) {
            Capsule()
                .fill(Token.black60)
                .frame(width: Self.capsuleWidth)
                .ui2Element("Capsule")
        }
        // §2 Accessibility: a container labelled "Camera tools"; each slot is C-147's own button.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera tools")
        .ui2Element("CameraRail")
    }
}
