//
//  RecorderSettings.swift
//  MakeReady
//
//  The recorder's per-device choices, kept in UserDefaults (video-recorder D2, D3, D7): the length,
//  the pre-roll, the countdown sound, the teleprompter draft, its speed and its text size.
//

import Foundation

struct RecorderSettings {
    private enum Key {
        static let length = "videoRecorder.lengthSeconds"
        static let lengthMode = "videoRecorder.lengthMode"
        static let endCountdown = "videoRecorder.endCountdownSeconds"
        static let preRoll = "videoRecorder.preRollSeconds"
        static let countdownSound = "videoRecorder.countdownSound"
        static let script = "videoRecorder.teleprompterScript"
        static let speedStep = "videoRecorder.teleprompterSpeedStep"
        static let sizeStep = "videoRecorder.teleprompterSizeStep"
    }

    static let speedSteps = 1...5
    static let sizeSteps = 1...3
    static let defaultSpeedStep = 3
    static let defaultSizeStep = 2

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 1:00 until the leader types or drags another; any second in 0:05…2:00 (video-polish D13).
    var length: Int {
        get {
            guard let stored = defaults.object(forKey: Key.length) as? Int else { return RecordingTimeline.defaultLength }
            return RecordingTimeline.clampedLength(stored)
        }
        nonmutating set { defaults.set(RecordingTimeline.clampedLength(newValue), forKey: Key.length) }
    }

    /// Any length for a new leader; Specify length for one who already saved a length (video-polish D4).
    var lengthMode: LengthMode {
        get {
            if let raw = defaults.string(forKey: Key.lengthMode), let mode = LengthMode(rawValue: raw) { return mode }
            return defaults.object(forKey: Key.length) == nil ? .any : .specify
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lengthMode) }
    }

    /// The end countdown: off until the leader picks 3 s or 10 s (video-polish D6).
    var endCountdownSeconds: Int {
        get {
            let stored = defaults.integer(forKey: Key.endCountdown)
            return RecordingTimeline.endCountdownChoices.contains(stored) ? stored : 0
        }
        nonmutating set {
            defaults.set(RecordingTimeline.endCountdownChoices.contains(newValue) ? newValue : 0, forKey: Key.endCountdown)
        }
    }

    /// Off until the leader turns a countdown on (D2).
    var preRoll: PreRoll {
        get { PreRoll.allCases.first { $0.seconds == defaults.integer(forKey: Key.preRoll) } ?? .off }
        nonmutating set { defaults.set(newValue.seconds, forKey: Key.preRoll) }
    }

    /// The countdown's beep: off until the leader turns it on, so demos, fixtures and agent walks
    /// stay silent (countdown-sound S2, S3, owner 2026-11-24).
    var countdownSound: Bool {
        get { defaults.bool(forKey: Key.countdownSound) }
        nonmutating set { defaults.set(newValue, forKey: Key.countdownSound) }
    }

    /// The teleprompter draft, kept until replaced (D7).
    var script: String {
        get { defaults.string(forKey: Key.script) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Key.script) }
    }

    var speedStep: Int {
        get { Self.stored(Key.speedStep, in: defaults, range: Self.speedSteps, fallback: Self.defaultSpeedStep) }
        nonmutating set { defaults.set(min(max(newValue, Self.speedSteps.lowerBound), Self.speedSteps.upperBound), forKey: Key.speedStep) }
    }

    var sizeStep: Int {
        get { Self.stored(Key.sizeStep, in: defaults, range: Self.sizeSteps, fallback: Self.defaultSizeStep) }
        nonmutating set { defaults.set(min(max(newValue, Self.sizeSteps.lowerBound), Self.sizeSteps.upperBound), forKey: Key.sizeStep) }
    }

    private static func stored(_ key: String, in defaults: UserDefaults, range: ClosedRange<Int>, fallback: Int) -> Int {
        guard let value = defaults.object(forKey: key) as? Int else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
