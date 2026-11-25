//
//  RecordingTimeline.swift
//  MakeReady
//
//  The recorder's clock, as a pure value: the chosen length, the recorded segments, the pre-roll and
//  the end countdown (video-recorder D2–D5). Everything is measured in recorded time, so a pause or
//  a deleted clip moves nothing but the total.
//

import Foundation

/// The Countdown tool's choices (D2): how long the numerals count before a segment starts.
enum PreRoll: CaseIterable, Equatable {
    case off, three, ten

    var seconds: Int {
        switch self {
        case .off: 0
        case .three: 3
        case .ten: 10
        }
    }

    /// One beep per second: ≈1.1 kHz, the last one higher at ≈1.66 kHz (D2). The end countdown has
    /// no beep (D4), so it never reaches the recording.
    func beepHz(remaining: Int) -> Double {
        remaining > 1 ? 1100 : 1660
    }
}

/// Any length records until stopped or the 2:00 cap; Specify length stops at the chosen length
/// (video-polish D4).
enum LengthMode: String, Equatable {
    case any, specify
}

struct RecordingTimeline: Equatable {
    static let minLength = 5
    static let maxLength = 120
    static let defaultLength = 60
    /// The end countdown's choices: Off, 3 s, 10 s (video-polish D6).
    static let endCountdownChoices = [0, 3, 10]

    private(set) var lengthSeconds: Int
    private(set) var mode: LengthMode
    /// Seconds the end countdown shows over; 0 = off (video-polish D6).
    private(set) var endCountdownSeconds: Int
    private(set) var segments: [TimeInterval] = []

    init(lengthSeconds: Int = RecordingTimeline.defaultLength, mode: LengthMode = .specify, endCountdownSeconds: Int = 0) {
        self.lengthSeconds = Self.clampedLength(lengthSeconds)
        self.mode = mode
        self.endCountdownSeconds = Self.endCountdownChoices.contains(endCountdownSeconds) ? endCountdownSeconds : 0
    }

    /// Any whole second in 0:05…2:00 — no snapping (video-polish D13).
    static func clampedLength(_ seconds: Int) -> Int {
        min(max(seconds, minLength), maxLength)
    }

    /// The length recording stops at: the 2:00 cap under Any length, else the chosen length (D4).
    var effectiveLength: Int { mode == .any ? Self.maxLength : lengthSeconds }

    /// The same choices with no segments — a fresh take.
    var withoutSegments: RecordingTimeline {
        RecordingTimeline(lengthSeconds: lengthSeconds, mode: mode, endCountdownSeconds: endCountdownSeconds)
    }

    var total: TimeInterval { segments.reduce(0, +) }

    /// The length is fixed once the first segment exists (D3).
    var canChangeLength: Bool { segments.isEmpty }

    /// Each segment's share of the progress bar's full width, which is the chosen length.
    var segmentFractions: [Double] { segments.map { $0 / Double(effectiveLength) } }

    /// Changes the length for the next recording; ignored once a segment exists (D3, D13).
    mutating func setLength(_ seconds: Int) {
        guard canChangeLength else { return }
        lengthSeconds = Self.clampedLength(seconds)
    }

    /// Any or Specify length; ignored once a segment exists (video-polish D4).
    mutating func setMode(_ next: LengthMode) {
        guard canChangeLength else { return }
        mode = next
    }

    /// Off, 3 s or 10 s (video-polish D6).
    mutating func setEndCountdown(_ seconds: Int) {
        endCountdownSeconds = Self.endCountdownChoices.contains(seconds) ? seconds : 0
    }

    mutating func append(_ duration: TimeInterval) { segments.append(duration) }

    /// Removes the last segment only (D5).
    mutating func deleteLast() { _ = segments.popLast() }

    /// The numeral for the end countdown at `t` seconds recorded in total (video-polish D6): the
    /// whole seconds left once fewer than the setting remain, from the start when the length is
    /// shorter; nil when off, under Any length, or outside that window.
    func endCountdown(atRecorded t: TimeInterval) -> Int? {
        guard mode == .specify, endCountdownSeconds > 0 else { return nil }
        let length = Double(lengthSeconds)
        guard t > length - Double(endCountdownSeconds), t < length else { return nil }
        return Int(ceil(length - t))
    }

    /// Recording stops by itself at the chosen length, or the 2:00 cap under Any length (D4).
    func shouldAutoStop(atRecorded t: TimeInterval) -> Bool {
        t >= Double(effectiveLength)
    }
}
