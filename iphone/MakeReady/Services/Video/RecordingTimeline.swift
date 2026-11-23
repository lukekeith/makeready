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

struct RecordingTimeline: Equatable {
    static let minLength = 10
    static let maxLength = 120
    static let lengthStep = 10
    static let defaultLength = 60
    /// The end countdown shows over the last this-many seconds (D4).
    static let endCountdownSeconds = 10

    private(set) var lengthSeconds: Int
    private(set) var segments: [TimeInterval] = []

    init(lengthSeconds: Int = RecordingTimeline.defaultLength) {
        self.lengthSeconds = Self.snappedLength(Double(lengthSeconds))
    }

    /// The slider's value to its nearest stop: 10 s steps, 10…120 — 12 stops (D3).
    static func snappedLength(_ raw: Double) -> Int {
        let stepped = Int((raw / Double(lengthStep)).rounded()) * lengthStep
        return min(max(stepped, minLength), maxLength)
    }

    var total: TimeInterval { segments.reduce(0, +) }

    /// The length is fixed once the first segment exists (D3).
    var canChangeLength: Bool { segments.isEmpty }

    /// Each segment's share of the progress bar's full width, which is the chosen length.
    var segmentFractions: [Double] { segments.map { $0 / Double(lengthSeconds) } }

    /// Changes the length for the next recording; ignored once a segment exists. Snaps to a stop.
    mutating func setLength(_ seconds: Int) {
        guard canChangeLength else { return }
        lengthSeconds = Self.snappedLength(Double(seconds))
    }

    mutating func append(_ duration: TimeInterval) { segments.append(duration) }

    /// Removes the last segment only (D5).
    mutating func deleteLast() { _ = segments.popLast() }

    /// The numeral for the end countdown at `t` seconds recorded in total (D4): 10 at length − 10 s
    /// down to 1 in the last second; nil outside that window.
    func endCountdown(atRecorded t: TimeInterval) -> Int? {
        let length = Double(lengthSeconds)
        guard t > length - Double(Self.endCountdownSeconds), t < length else { return nil }
        return Int(ceil(length - t))
    }

    /// Recording stops by itself at the chosen length (D4).
    func shouldAutoStop(atRecorded t: TimeInterval) -> Bool {
        t >= Double(lengthSeconds)
    }
}
