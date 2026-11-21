//
//  LiveWaveformView.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-011-live-waveform-view in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-011 LiveWaveformView — "the compact recorder's live level meter. Record-red bars are anchored
/// to the trailing edge: the newest level is at the right edge and older ones scroll left, so the
/// leader can see the memo is picking up sound."
///
/// §2 structure: one horizontal strip of vertical bars — no background, baseline, axis or label.
/// It fills the width it is given and states its own 80 pt height (R-16); its ground is the
/// caller's. Display-only (R-01/R-03): no callbacks, no timer, no audio access (R-04/R-19) — the
/// caller feeds new `samples` arrays.
struct LiveWaveformView: View {

    // MARK: - Props (§4, R-05 order)

    /// §4 `samples` — "Recording levels in 0…1, oldest first, about 20 per second. The view draws
    /// the newest ones that fit; values outside 0…1 are clamped." Required (R-07).
    let samples: [Float]

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            bars(width: proxy.size.width, height: proxy.size.height)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.stripHeight)
        // §2 Motion: "Each new `samples` value re-renders without implicit animation."
        .transaction { $0.animation = nil }
        .allowsHitTesting(false)
        // §2 Accessibility: "decorative … `.accessibilityHidden(true)`".
        .accessibilityHidden(true)
        .ui2Element("LiveWaveformView")     // capture element map — UI2Element.swift
    }

    // MARK: - Bars

    /// §2 Bars + Count: 1 pt `color-error` rectangles at a `space-step-4` pitch, each centred in
    /// its slot; the newest sample's slot ends flush with the trailing edge; slot count is
    /// `floor(width / 4)` and the last `min(count, samples.count)` samples are drawn, oldest left.
    private func bars(width: CGFloat, height: CGFloat) -> some View {
        let pitch = Token.Space.step4
        let slots = max(0, Int((width / pitch).rounded(.down)))
        let shown = Array(samples.suffix(min(slots, samples.count)))

        return ZStack(alignment: .topLeading) {
            ForEach(shown.indices, id: \.self) { index in
                // age 0 = newest; its slot is [width − pitch, width], centre 2 pt in.
                let age = shown.count - 1 - index
                let centreX = width - CGFloat(age) * pitch - pitch / 2
                let barHeight = Self.barHeight(shown[index])
                Rectangle()
                    .fill(Token.error)
                    .frame(width: Self.barWidth, height: barHeight)
                    // §2 Vertical: centred on the strip's horizontal midline.
                    .offset(x: centreX - Self.barWidth / 2, y: (height - barHeight) / 2)
                    .ui2Element("Bar \(index + 1)")
            }
        }
    }

    // MARK: - Geometry

    /// §2 Height: "`max(1, clamp(sample, 0, 1) × 76)` pt" — below 1 pt a sample is a 1 pt dot.
    private static func barHeight(_ sample: Float) -> CGFloat {
        let level = CGFloat(min(max(sample, 0), 1))
        return max(barWidth, level * fullScale)
    }

    // FLAGGED LITERAL — C-011 §2 FL-1: intrinsic height 80 pt, no token.
    private static let stripHeight: CGFloat = 80
    // FLAGGED LITERAL — C-011 §2 FL-2: bar width (and minimum dot height) 1 pt, no token.
    private static let barWidth: CGFloat = 1
    // FLAGGED LITERAL — C-011 §2 FL-3: bar full scale 76 pt, no token.
    private static let fullScale: CGFloat = 76
}
