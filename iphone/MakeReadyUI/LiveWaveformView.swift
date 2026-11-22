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
/// caller's. Display-only (R-01/R-03): no callbacks and no audio access (R-19) — the caller feeds
/// new `samples` arrays. Per deviation 3 (owner ruling 2026-11-21) the view owns a display clock
/// and reads Reduce Motion so the bars slide continuously between samples while recording.
struct LiveWaveformView: View {

    // MARK: - Props (§4, R-05 order)

    /// §4 `samples` — "Recording levels in 0…1, oldest first. The view draws the newest ones that
    /// fit; values outside 0…1 are clamped." Required (R-07).
    let samples: [Float]
    /// §4 `sampleTime` — "The recording time in seconds the newest sample stands for … it never
    /// moves a bar. It only sets `tNewest` and, on a stall or seek … re-anchors the clock." Default `0`.
    var sampleTime: Double = 0
    /// §4 `isRunning` — "`true` while recording; `false` when paused or stopped, which freezes the
    /// clock and draws the resting layout." Default `false`.
    var isRunning: Bool = false

    /// Capture-only: a still at a fixed scroll progress, "mapped onto T as `T = tNewest − (1 −
    /// progress) / 20`" (§2). Not a prop; nil in the app. Set with `stillProgress(_:)`.
    private var stillProgress: Double?

    init(samples: [Float], sampleTime: Double = 0, isRunning: Bool = false) {
        self.samples = samples
        self.sampleTime = sampleTime
        self.isRunning = isRunning
    }

    /// Capture-only: draws a still at a fixed scroll progress (0…1) instead of the clock.
    func stillProgress(_ progress: Double?) -> LiveWaveformView {
        var copy = self
        copy.stillProgress = progress
        return copy
    }

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// §2 Scrolling step 1: the display clock's one anchor `(date, time)`; nil until running.
    @State private var anchor: ClockAnchor?

    // MARK: - Body

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: Self.stripHeight)
            // §2 Count: the extra leading bar slides out under the strip's edge.
            .clipped()
            // §2 Motion: "No implicit or explicit animation of its own."
            .transaction { $0.animation = nil }
            // §2 Scrolling step 1: anchored to `(now, sampleTime)` when `isRunning` turns true …
            .onAppear { if isRunning { anchor = ClockAnchor(date: Date(), time: sampleTime) } }
            .onChange(of: isRunning) { _, running in
                if running { anchor = ClockAnchor(date: Date(), time: sampleTime) }
            }
            // … and re-anchored only on a stall or seek (`|T − sampleTime| > 0.15 s`).
            .onChange(of: sampleTime) { _, time in
                guard isRunning else { return }
                anchor = ClockAnchor.reanchored(anchor, to: time, at: Date())
            }
            .allowsHitTesting(false)
            // §2 Accessibility: "decorative … `.accessibilityHidden(true)`".
            .accessibilityHidden(true)
            .ui2Element("LiveWaveformView")     // capture element map — UI2Element.swift
    }

    /// §2 Scrolling step 2: "`tNewest = floor(sampleTime × 20) / 20`".
    private var newestTime: Double {
        (sampleTime * Self.samplesPerSecond).rounded(.down) / Self.samplesPerSecond
    }

    @ViewBuilder
    private var content: some View {
        if let stillProgress {
            // §2 stills: "`T = tNewest − (1 − progress) / 20`".
            let progress = min(max(stillProgress, 0), 1)
            strip(displayTime: newestTime - (1 - progress) / Self.samplesPerSecond)
        } else if isRunning && !reduceMotion {
            // §2 Scrolling: a display-rate clock redraws every frame.
            TimelineView(.animation) { context in
                strip(displayTime: anchor?.time(at: context.date) ?? newestTime)
            }
        } else {
            // §2 Reduce Motion, paused, stills: the resting layout (T = tNewest).
            strip(displayTime: newestTime)
        }
    }

    private func strip(displayTime: Double) -> some View {
        GeometryReader { proxy in
            bars(width: proxy.size.width, height: proxy.size.height, displayTime: displayTime)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    // MARK: - Bars

    /// §2 Bars + Count: 1 pt `color-error` rectangles at a `space-step-4` pitch; slot count is
    /// `floor(width / 4)` and the last `min(count + 1, samples.count)` samples are drawn, oldest
    /// left, the extra one clipped past the leading edge. §2 Scrolling step 3: bar `j` stands for
    /// `tBar = tNewest − j / 20` and its centre is `x = trailingEdge − 2 − (T − tBar) × 20 × 4`.
    private func bars(width: CGFloat, height: CGFloat, displayTime: Double) -> some View {
        let pitch = Token.Space.step4
        let slots = max(0, Int((width / pitch).rounded(.down)))
        let shown = Array(samples.suffix(min(slots + 1, samples.count)))
        let tNewest = newestTime

        return ZStack(alignment: .topLeading) {
            ForEach(shown.indices, id: \.self) { index in
                // j = 0 is the newest; at rest (T = tNewest) its centre is 2 pt in.
                let age = shown.count - 1 - index
                let barTime = tNewest - Double(age) / Self.samplesPerSecond
                let travel = CGFloat((displayTime - barTime) * Self.samplesPerSecond) * pitch
                let centreX = width - pitch / 2 - travel
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

    /// §2 Scrolling step 1: "`T = anchor.time + (now − anchor.date)`" — one clock for every bar.
    private struct ClockAnchor: Equatable {
        let date: Date
        let time: Double

        /// T at `now`; held (never backwards) while `now` is before a forward-dated anchor.
        func time(at now: Date) -> Double {
            time + max(0, now.timeIntervalSince(date))
        }

        /// Re-anchors only when `|T − sampleTime| > 0.15 s`; drift under that is left alone. A
        /// T that ran ahead (a stall) holds still until the recording catches up — "T never goes
        /// backwards"; a T that fell behind jumps forward to `sampleTime`.
        static func reanchored(_ anchor: ClockAnchor?, to sampleTime: Double, at now: Date) -> ClockAnchor {
            guard let anchor else { return ClockAnchor(date: now, time: sampleTime) }
            let displayed = anchor.time(at: now)
            guard abs(displayed - sampleTime) > LiveWaveformView.reanchorThreshold else { return anchor }
            if displayed > sampleTime {
                return ClockAnchor(date: now.addingTimeInterval(displayed - sampleTime), time: displayed)
            }
            return ClockAnchor(date: now, time: sampleTime)
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
    // FLAGGED LITERAL — C-011 §2 FL-4: 20 samples per second, no token.
    private static let samplesPerSecond: Double = 20
    /// §2 Scrolling step 1: re-anchor only when the clock is more than 0.15 s off `sampleTime`.
    fileprivate static let reanchorThreshold: Double = 0.15
}

