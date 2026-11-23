//
//  TimerPill.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-144-timerpill in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-144 TimerPill — the recorder's elapsed-time pill.
///
/// One horizontal box hugging one text line (§2): `type-timecode` in `color-text-primary` on a
/// `color-record` fill, `radius-card-sm` corners, `space-button-padding` × `space-meta-gap`
/// insets. Intrinsic both ways — the pill hugs its text and the host centres it (§2 Sizing).
/// Display-only: the caller owns the clock and passes `elapsed` each tick (R-04, R-19).
struct TimerPill: View {

    /// §4 `elapsed` — recorded time so far, in seconds. Required (R-07). Floored to whole
    /// seconds and rendered as zero-padded HH:MM:SS (§1 deviation 2).
    let elapsed: TimeInterval

    // MARK: - Body

    var body: some View {
        Text(timecode)
            .designTextStyle(Token.TypeStyle.timecode)
            .monospacedDigit()                       // §1 deviation 1: width holds as seconds tick
            .lineLimit(1)
            .fixedSize()                             // §2: one line, no wrap, no truncation
            .frame(height: Token.TypeStyle.timecode.lineHeight)   // §2: 18 / 25.2 line box
            .foregroundStyle(Token.textPrimary)
            .ui2Element("Value")
            .padding(.horizontal, Token.Space.buttonPadding)
            .padding(.vertical, Token.Space.metaGap)
            .background(
                RoundedRectangle(cornerRadius: Token.Radius.cardSm, style: .continuous)
                    .fill(Token.record)
                    .ui2Element("Fill")
            )
            // §1 deviation 3: one non-interactive element, label + spoken duration.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recording time")
            .accessibilityValue(spokenDuration)
            .ui2Element("TimerPill")
    }

    // MARK: - Formatting

    /// Whole seconds, floored; a negative value reads as zero (§3: `elapsed: 0` → "00:00:00").
    private var wholeSeconds: Int {
        max(Int(elapsed.rounded(.down)), 0)
    }

    /// §4: zero-padded HH:MM:SS — 0 → "00:00:00", 1 → "00:00:01", 3725 → "01:02:05".
    private var timecode: String {
        let total = wholeSeconds
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// §1 deviation 3: the spoken duration ("1 second").
    private var spokenDuration: String {
        let total = wholeSeconds
        return total == 0 ? "0 seconds" : (Self.spokenFormatter.string(from: TimeInterval(total)) ?? "")
    }

    private static let spokenFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .full
        f.allowedUnits = [.hour, .minute, .second]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
}
