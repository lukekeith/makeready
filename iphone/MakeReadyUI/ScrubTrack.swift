//
//  ScrubTrack.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-004-scrubtrack in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-004 ScrubTrack — the memo player's flat seek track with elapsed and remaining time.
///
/// §2: a 20pt track area (a 4pt capsule track, the elapsed fill and a thumb) over a label row
/// (elapsed leading, remaining trailing, `0:04 … −0:12`), `space-meta-gap` apart: 38pt tall.
///
/// Controlled (R-01): the caller owns `elapsed` and `dragging` and feeds them back in from
/// `onSeek` and `onDraggingChange`. Width-driven and chrome-free (R-16): no background, no
/// outer padding. Normative source is markdown only (D72): there is no Figma picture.
struct ScrubTrack: View {
    /// §4 — the playhead position in seconds; clamped to [0, duration] for drawing.
    let elapsed: TimeInterval
    /// §4 — the memo's length in seconds.
    let duration: TimeInterval
    /// §4 — true while the finger is on the track: the `dragging` state (thumb at 20pt).
    let dragging: Bool
    /// §4 / OQ-C-004-003 — false while the audio isn't available: the `disabled` state.
    var enabled: Bool = true
    /// §4 — the seek target in seconds: on touch-down, every drag move, each VoiceOver adjust.
    var onSeek: (TimeInterval) -> Void = { _ in }
    /// §4 — true on touch-down, false on lift.
    var onDraggingChange: (Bool) -> Void = { _ in }

    /// R-02 ephemeral: whether the current drag has already reported touch-down.
    @State private var touching = false

    // FLAGGED LITERAL — C-004 §2 FL-1: 20pt track area, the dragging thumb's diameter.
    private let trackAreaHeight: CGFloat = 20
    // FLAGGED LITERAL — C-004 §2 FL-2: 4pt track, no height token.
    private let trackHeight: CGFloat = 4
    // FLAGGED LITERAL — C-004 §2 FL-3: 12pt thumb at rest.
    private let restingThumb: CGFloat = 12
    // FLAGGED LITERAL — C-004 §2 FL-1 / OQ-C-004-002: 20pt thumb while dragging.
    private let draggingThumb: CGFloat = 20
    /// §2 / §1 deviation 5: the 44pt touch area, centred on the track (R-17 minimum target).
    private let touchHeight: CGFloat = 44
    /// §2 / §1 deviation 6: the VoiceOver adjust step, C-014's skip step.
    private let adjustStep: TimeInterval = 15

    var body: some View {
        VStack(spacing: Token.Space.metaGap) {
            trackArea
            labelRow
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Self.spoken(clampedElapsed)) of \(Self.spoken(safeDuration))")
        .modifier(AdjustableWhenEnabled(enabled: enabled, onAdjust: adjust))
        .ui2Element("ScrubTrack")
    }

    // MARK: - §2 track area

    private var trackArea: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumbX = restingThumb / 2 + progress * max(width - restingThumb, 0)
            let thumb = dragging ? draggingThumb : restingThumb

            ZStack(alignment: .leading) {
                // `radius-circle` is 50 %, not a point value: the ends are a Capsule().
                Capsule()
                    .fill(enabled ? Token.white20 : Token.white30)
                    .frame(width: width, height: trackHeight)
                    .ui2Element("Track")

                if enabled && progress > 0 {
                    Capsule()
                        .fill(Token.textPrimary)
                        .frame(width: thumbX, height: trackHeight)
                        .ui2Element("Elapsed fill")
                }

                if enabled {
                    Circle()
                        .fill(Token.textPrimary)
                        .frame(width: thumb, height: thumb)
                        .ui2Element("Thumb")
                        .offset(x: thumbX - thumb / 2)
                }
            }
            .frame(width: width, height: trackAreaHeight)
            .contentShape(
                Rectangle()
                    .size(width: width, height: touchHeight)
                    .offset(y: (trackAreaHeight - touchHeight) / 2)
            )
            .gesture(
                // pan-ok: horizontal seek track, tracks the finger on its own strip
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !touching {
                            touching = true
                            onDraggingChange(true)
                        }
                        onSeek(seekTarget(x: drag.location.x, width: width))
                    }
                    .onEnded { _ in
                        touching = false
                        onDraggingChange(false)
                    }
            )
            .allowsHitTesting(enabled)
        }
        .frame(height: trackAreaHeight)
    }

    // MARK: - §2 label row

    private var labelRow: some View {
        HStack(spacing: 0) {
            timeLabel(Self.clock(elapsedSeconds))
                .ui2Element("Elapsed")
            Spacer(minLength: 0)
            // U+2212 MINUS SIGN, not a hyphen (§2).
            timeLabel("\u{2212}" + Self.clock(remainingSeconds))
                .ui2Element("Remaining")
        }
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .monospacedDigit()   // §1 deviation 3
            .designTextStyle(Token.TypeStyle.caption)
            .foregroundStyle(enabled ? Token.textSecondary : Token.white30)
            .lineLimit(1)
            // §2: the row is type-caption's 14pt line, so the component is 20 + 4 + 14 = 38pt.
            .frame(height: Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size)
    }

    // MARK: - Computed (R-04: no side effects)

    private var safeDuration: TimeInterval { max(duration, 0) }

    private var clampedElapsed: TimeInterval { min(max(elapsed, 0), safeDuration) }

    /// §2: elapsed ÷ duration, clamped to 0…1; a duration of 0 draws progress 0.
    private var progress: CGFloat {
        guard safeDuration > 0 else { return 0 }
        return CGFloat(clampedElapsed / safeDuration)
    }

    /// §2: ⌊elapsed⌋.
    private var elapsedSeconds: Int { Int(clampedElapsed.rounded(.down)) }

    /// §2: round(duration) − ⌊elapsed⌋, floored at 0.
    private var remainingSeconds: Int { max(Int(safeDuration.rounded()) - elapsedSeconds, 0) }

    /// §2: t = clamp((x − 6) ÷ (width − 12), 0, 1) × duration.
    private func seekTarget(x: CGFloat, width: CGFloat) -> TimeInterval {
        let span = width - restingThumb
        guard span > 0 else { return 0 }
        let fraction = min(max((x - restingThumb / 2) / span, 0), 1)
        return TimeInterval(fraction) * safeDuration
    }

    /// §2 / §1 deviation 6: ±15 s, clamped to [0, duration].
    private func adjust(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment: onSeek(min(clampedElapsed + adjustStep, safeDuration))
        case .decrement: onSeek(max(clampedElapsed - adjustStep, 0))
        @unknown default: break
        }
    }

    /// §2: `m:ss`, or `h:mm:ss` from one hour (memo-screens D11).
    private static func clock(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// R-17: a time spoken in words — "4 seconds", "1 minute, 12 seconds".
    private static func spoken(_ interval: TimeInterval) -> String {
        let whole = interval.rounded(.down)
        return whole < 1 ? "0 seconds" : (spokenFormatter.string(from: whole) ?? "0 seconds")
    }

    private static let spokenFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.hour, .minute, .second]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
}

/// §2: `.adjustable` while enabled; not adjustable while disabled.
private struct AdjustableWhenEnabled: ViewModifier {
    let enabled: Bool
    let onAdjust: (AccessibilityAdjustmentDirection) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAdjustableAction(onAdjust)
        } else {
            content
        }
    }
}
