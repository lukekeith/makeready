//
//  RecorderSettings.swift
//  MakeReady
//
//  The recorder's per-device choices, kept in UserDefaults (video-recorder D2, D3, D7): the length,
//  the pre-roll, the teleprompter draft, its speed and its text size.
//

import Foundation

struct RecorderSettings {
    private enum Key {
        static let length = "videoRecorder.lengthSeconds"
        static let preRoll = "videoRecorder.preRollSeconds"
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

    /// 1:00 until the leader picks another stop (D3).
    var length: Int {
        get {
            guard let stored = defaults.object(forKey: Key.length) as? Int else { return RecordingTimeline.defaultLength }
            return RecordingTimeline.snappedLength(Double(stored))
        }
        nonmutating set { defaults.set(RecordingTimeline.snappedLength(Double(newValue)), forKey: Key.length) }
    }

    /// Off until the leader turns a countdown on (D2).
    var preRoll: PreRoll {
        get { PreRoll.allCases.first { $0.seconds == defaults.integer(forKey: Key.preRoll) } ?? .off }
        nonmutating set { defaults.set(newValue.seconds, forKey: Key.preRoll) }
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
