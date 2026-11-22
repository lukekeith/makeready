//
//  PlayheadWaveformView.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-012-playhead-waveform-view in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-012 PlayheadWaveformView — "the expanded recorder's waveform pane. A fixed record-red
/// playhead sits at the horizontal centre, the recorded levels scroll left beneath it, and a
/// per-second time ruler runs along the bottom."
///
/// §2 structure, top to bottom: upper dot cap → pane (bars + playhead hairline) → lower dot cap
/// (overlapping the ticks) → ruler (ticks + labels). It fills the width it is given (R-16) and,
/// per OQ-C-012-6 (owner), the height too: pane = given height − 32.33 pt, never under 200 pt.
/// It draws its own pane fill (OQ-C-012-4); the ruler band is left unpainted.
///
/// Display-only (R-01/R-03): no callbacks and no audio access (R-19) — the caller feeds new
/// `samples` / `elapsed` / `sampleTime`. Per §2 Motion (owner ruling 2026-11-21) the view owns a
/// display clock and reads Reduce Motion so the waveform and ruler scroll smoothly while recording.
struct PlayheadWaveformView: View {

    // MARK: - Props (§4, R-05 order)

    /// §4 `samples` — "Recording levels in 0…1, oldest first, about 20 per second. The newest is
    /// drawn in the slot ending at the playhead and the older ones go left; values outside 0…1
    /// are clamped." Required (R-07).
    let samples: [Float]

    /// §4 `elapsed` — "The recording time under the playhead, in seconds. It positions the
    /// ruler's ticks and labels." Required (R-07).
    let elapsed: TimeInterval

    /// §4 `sampleTime` — "The recording time in seconds the newest sample stands for." It sets
    /// `tNewest` and re-anchors the display clock only on a stall or seek; it never moves a bar.
    /// Default `0`.
    var sampleTime: Double = 0

    /// §4 `isRunning` — "`true` while recording; `false` when paused or stopped, which stops the
    /// scroll dead and draws the still stepped layout." Default `false`.
    var isRunning: Bool = false

    /// Capture-only: freezes the scroll progress for a still (§3 `scrolling` — "a still taken
    /// mid-interval"). Not a prop; nil in the app. Set with `stillProgress(_:)`.
    private var stillProgress: Double?

    init(samples: [Float], elapsed: TimeInterval, sampleTime: Double = 0, isRunning: Bool = false) {
        self.samples = samples
        self.elapsed = elapsed
        self.sampleTime = sampleTime
        self.isRunning = isRunning
    }

    /// Capture-only: draws a still at a fixed scroll progress (0…1) instead of the clock.
    func stillProgress(_ progress: Double?) -> PlayheadWaveformView {
        var copy = self
        copy.stillProgress = progress
        return copy
    }

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// §2 Motion: the display clock's one anchor `(date, time)` (C-011's clock T); nil until running.
    @State private var anchor: ClockAnchor?

    // MARK: - Body

    var body: some View {
        content
            // OQ-C-012-6: fills the given height, never below a 200 pt pane.
            .frame(maxWidth: .infinity, minHeight: Self.minPane + Self.chrome, maxHeight: .infinity)
            // §2 Motion: "There is no implicit animation on a value change".
            .transaction { $0.animation = nil }
            // §2 Motion: one clock T, anchored to `(now, sampleTime)` when `isRunning` turns true …
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
            .ui2Element("PlayheadWaveformView")     // capture element map — UI2Element.swift
    }

    @ViewBuilder
    private var content: some View {
        if let stillProgress {
            // A still mid-interval: `T = tNewest − (1 − progress) / 20`, as C-011.
            let lag = (1 - min(max(stillProgress, 0), 1)) / Self.samplesPerSecond
            pane(barTime: newestTime - lag, rulerTime: elapsed - lag)
        } else if isRunning && !reduceMotion {
            // §2 Motion: "a `TimelineView(.animation)` clock moves the waveform and the ruler left
            // continuously under the fixed playhead".
            TimelineView(.animation) { context in
                let clock = anchor?.time(at: context.date) ?? newestTime
                // The ruler follows the same clock, offset by the caller's `elapsed − sampleTime`.
                pane(barTime: clock, rulerTime: clock + (elapsed - sampleTime))
            }
        } else {
            // §2 Motion: paused, stopped or Reduce Motion — "the still stepped layout".
            pane(barTime: newestTime, rulerTime: elapsed)
        }
    }

    /// The time the newest sample stands for: `floor(sampleTime × 20) / 20` (C-011 §2).
    private var newestTime: Double {
        (sampleTime * Self.samplesPerSecond).rounded(.down) / Self.samplesPerSecond
    }

    /// The whole component at display time T: `barTime` places every bar from its own fixed time
    /// (`tNewest` is the stepped layout) and `rulerTime` is the time under the playhead, so bars
    /// and ruler both move at 80 pt/s on one clock and an arriving sample never moves a bar.
    private func pane(barTime: Double, rulerTime: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let paneHeight = Self.paneHeight(forGiven: proxy.size.height)
            let playheadX = width / 2
            let paneBottom = Self.capDiameter + paneHeight

            ZStack(alignment: .topLeading) {
                // §2 Pane: "y 7.33–… full width", fill `color-white-5` (OQ-C-012-4).
                Rectangle()
                    .fill(Token.white5)
                    .frame(width: width, height: paneHeight)
                    .offset(y: Self.capDiameter)
                    .ui2Element("Pane")

                bars(width: width, paneHeight: paneHeight, displayTime: barTime)
                    .frame(width: width, height: paneHeight, alignment: .topLeading)
                    // §2 Anchor: "Nothing is drawn to the right of the playhead" — an arriving
                    // bar slides out from under it; the extra leading slot clips at the edge.
                    .frame(width: playheadX, height: paneHeight, alignment: .topLeading)
                    .clipped()
                    .offset(y: Self.capDiameter)

                ruler(width: width, playheadX: playheadX, elapsed: rulerTime)
                    .frame(width: width, height: Self.rulerBand, alignment: .topLeading)
                    .clipped()
                    .offset(y: paneBottom)
                    .ui2Element("Ruler")

                // §2 Playhead hairline: "1 pt wide (deviation 2), `color-error`, centred on the
                // playhead x. It runs the full pane height … drawn above the bars."
                Rectangle()
                    .fill(Token.error)
                    // DEVIATION 2 — C-012 §1: 1 pt line weight.
                    .frame(width: 1, height: paneHeight)
                    .offset(x: playheadX - 0.5, y: Self.capDiameter)
                    .ui2Element("Playhead")

                // §2 Dot caps: "Two filled `color-error` circles … centred on the playhead x."
                Circle()
                    .fill(Token.error)
                    .frame(width: Self.capDiameter, height: Self.capDiameter)
                    .offset(x: playheadX - Self.capDiameter / 2)
                    .ui2Element("Upper dot cap")

                Circle()
                    .fill(Token.error)
                    .frame(width: Self.capDiameter, height: Self.capDiameter)
                    .offset(x: playheadX - Self.capDiameter / 2, y: paneBottom)
                    .ui2Element("Lower dot cap")
            }
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
        }
    }

    /// §2 Motion: the display clock T — "`T = anchor.time + (now − anchor.date)`" (C-011 §2).
    private struct ClockAnchor: Equatable {
        let date: Date
        let time: Double

        /// T at `now`; held (never backwards) while `now` is before a forward-dated anchor.
        func time(at now: Date) -> Double {
            time + max(0, now.timeIntervalSince(date))
        }

        /// Re-anchors only when `|T − sampleTime| > 0.15 s`; drift under that is left alone. A
        /// T that ran ahead (a stall) holds still until the recording catches up — T never goes
        /// backwards; a T that fell behind jumps forward to `sampleTime`.
        static func reanchored(_ anchor: ClockAnchor?, to sampleTime: Double, at now: Date) -> ClockAnchor {
            guard let anchor else { return ClockAnchor(date: now, time: sampleTime) }
            let displayed = anchor.time(at: now)
            guard abs(displayed - sampleTime) > PlayheadWaveformView.reanchorThreshold else { return anchor }
            if displayed > sampleTime {
                return ClockAnchor(date: now.addingTimeInterval(displayed - sampleTime), time: displayed)
            }
            return ClockAnchor(date: now, time: sampleTime)
        }
    }

    // MARK: - Bars

    /// §2 Bars: 1 pt `color-error` rectangles at a `space-step-4` pitch; the newest sample's slot
    /// ends at the playhead, older ones go left, nothing right of the playhead; each centred on
    /// the pane's midline.
    private func bars(width: CGFloat, paneHeight: CGFloat, displayTime: Double) -> some View {
        let pitch = Token.Space.step4
        let playheadX = width / 2
        // §2 Count: "slots left of the playhead = floor((width / 2) / 4)" — "while scrolling, one
        // extra slot at the leading edge is drawn and clipped so no gap opens".
        let slots = max(0, Int((playheadX / pitch).rounded(.down)))
        let extra = displayTime < newestTime ? 1 : 0
        let shown = Array(samples.suffix(min(slots + extra, samples.count)))
        let tNewest = newestTime
        // OQ-C-012-6: "the bar full scale stays 240 pt, capped at the pane height".
        let fullScale = min(Self.fullScale, paneHeight)

        return ZStack(alignment: .topLeading) {
            ForEach(shown.indices, id: \.self) { index in
                // age 0 = newest; it stands for `tBar = tNewest − age / 20` and sits at
                // `x = playheadX − 2 − (T − tBar) × 80` (centre 2 pt left at rest).
                let age = shown.count - 1 - index
                let barTime = tNewest - Double(age) / Self.samplesPerSecond
                let travel = CGFloat((displayTime - barTime) * Self.samplesPerSecond) * pitch
                let centreX = playheadX - pitch / 2 - travel
                let height = Self.barHeight(shown[index], fullScale: fullScale)
                Rectangle()
                    .fill(Token.error)
                    // DEVIATION 2 — C-012 §1: 1 pt line weight.
                    .frame(width: 1, height: height)
                    .offset(x: centreX - 0.5, y: (paneHeight - height) / 2)
                    .ui2Element("Bar \(index + 1)")
            }
        }
    }

    // MARK: - Ruler

    /// §2 Ruler: a time `t` sits at `x = width/2 − (elapsed − t) × 80`; only `t ≥ 0`, clipped at
    /// the component's edges. Minor ticks every 0.25 s, major + label on every whole second.
    private func ruler(width: CGFloat, playheadX: CGFloat, elapsed: TimeInterval) -> some View {
        // §2 Motion: the ruler is placed from the same clock T as the bars (80 pt/s).
        let ticks = Self.ticks(elapsed: elapsed, playheadX: playheadX)
        return ZStack(alignment: .topLeading) {
            ForEach(ticks, id: \.quarter) { tick in
                let x = playheadX - CGFloat(elapsed - tick.time) * Self.pointsPerSecond
                Rectangle()
                    .fill(Token.white10)
                    // DEVIATION 2 — C-012 §1: 1 pt line weight.
                    .frame(width: 1, height: tick.major ? Self.majorTick : Self.minorTick)
                    .offset(x: x)
                if tick.major {
                    // §2 Labels: "`type-caption`, `color-white-20`. The label's leading edge sits
                    // on its major tick … line box top is 11 pt below the pane's bottom edge."
                    Text(Self.label(seconds: Int(tick.time.rounded())))
                        .designTextStyle(Token.TypeStyle.caption)
                        .foregroundStyle(Token.white20)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(height: Self.labelLineHeight, alignment: .leading)
                        .offset(x: x, y: Self.labelTop)
                        .ui2Element("Label \(Self.label(seconds: Int(tick.time.rounded())))")
                }
            }
        }
    }

    private struct Tick {
        let quarter: Int
        let time: TimeInterval
        let major: Bool
    }

    /// Every quarter-second `t ≥ 0` whose tick (or, for a label, its text) can reach the visible
    /// width. One extra second on the left so a label whose tick is just off-edge still clips in.
    private static func ticks(elapsed: TimeInterval, playheadX: CGFloat) -> [Tick] {
        let halfSpan = TimeInterval(playheadX / pointsPerSecond)
        let first = max(0, Int(((elapsed - halfSpan - 1) * 4).rounded(.up)))
        let last = Int(((elapsed + halfSpan) * 4).rounded(.down))
        guard last >= first else { return [] }
        return (first...last).map { quarter in
            Tick(quarter: quarter, time: TimeInterval(quarter) / 4, major: quarter % 4 == 0)
        }
    }

    /// §2 Label text: "`m:ss` below one hour (`0:08`); `h:mm:ss` from one hour (`1:12:05`)."
    static func label(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Geometry

    /// §2 Height: "`max(1, clamp(sample, 0, 1) × 240)` pt" (full scale capped per OQ-C-012-6).
    private static func barHeight(_ sample: Float, fullScale: CGFloat) -> CGFloat {
        let level = CGFloat(min(max(sample, 0), 1))
        return max(1, level * fullScale)
    }

    /// OQ-C-012-6 (owner): "pane = given height − 32.33 pt and a 200 pt minimum".
    private static func paneHeight(forGiven height: CGFloat) -> CGFloat {
        max(minPane, height - chrome)
    }

    // FLAGGED LITERAL — C-012 §2 FL-1: dot cap 7.33 pt diameter, no token (measured 22 px).
    private static let capDiameter: CGFloat = 22.0 / 3.0
    // FLAGGED LITERAL — C-012 §2 FL-3: bar full scale 240 pt, no token.
    private static let fullScale: CGFloat = 240
    // FLAGGED LITERAL — C-012 §2 FL-4: minor tick 1 × 5 pt, major tick 1 × 10 pt, no token.
    private static let minorTick: CGFloat = 5
    private static let majorTick: CGFloat = 10
    // FLAGGED LITERAL — C-012 §2 FL-5: label line-box top 11 pt below the pane's bottom edge.
    private static let labelTop: CGFloat = 11
    /// `type-caption`'s line height (14), so the ruler band is FL-5 + 14 = §2's "25 pt in all".
    private static let labelLineHeight: CGFloat = Token.TypeStyle.caption.lineHeight ?? 14
    private static let rulerBand: CGFloat = labelTop + labelLineHeight
    // DEVIATION 3 — C-012 §1/§2: ruler time scale 80 pt per second (OQ-C-012-2, owner).
    private static let pointsPerSecond: CGFloat = 80
    // §2 Motion: "4 pt per sample, 80 pt per second (20 samples per second)" — C-011's FL-4 rate.
    private static let samplesPerSecond: Double = 20
    /// §2 Motion: re-anchor the clock only when it is more than 0.15 s off `sampleTime` (C-011 §2).
    fileprivate static let reanchorThreshold: Double = 0.15
    // OWNER RULING — OQ-C-012-6: "a 200 pt minimum" pane; it supersedes §2's FL-2 fixed 400 pt
    // pane, and the ruling names the value itself (no token row).
    private static let minPane: CGFloat = 200
    /// Everything but the pane: the upper cap above it and the ruler band below (32.33 pt).
    private static let chrome: CGFloat = capDiameter + rulerBand
}
