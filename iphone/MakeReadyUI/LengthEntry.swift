//
//  LengthEntry.swift
//  MakeReadyUI — the UI 2.0 module
//
//  The video-recorder Length panel's typed length (§3), as pure functions.
//

import Foundation

/// `m:ss` entry: digits fill from the right, never past 2:00.
enum LengthEntry {
    static let minimumSeconds = 5
    static let maximumSeconds = 120

    /// What the input shows for `raw`: 1 → 0:01, 13 → 0:13, 130 → 1:30, 2005 → 2:00.
    static func digits(_ raw: String) -> String {
        let (minutes, seconds) = parts(raw)
        // Seconds 60–99 stay as typed until commit, unless the total is over the cap.
        guard minutes * 60 + seconds <= maximumSeconds else { return format(maximumSeconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// The length `text` stands for, in seconds: 0:75 → 75 (1:15), 0:02 → 5.
    static func commit(_ text: String) -> Int {
        let (minutes, seconds) = parts(text)
        return min(max(minutes * 60 + seconds, minimumSeconds), maximumSeconds)
    }

    /// `m:ss` — 5 → "0:05", 75 → "1:15".
    static func format(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// The last two digits are seconds, the rest minutes.
    private static func parts(_ raw: String) -> (minutes: Int, seconds: Int) {
        let typed = raw.filter { $0.isASCII && $0.isNumber }.drop { $0 == "0" }
        // Five significant digits are already far past the cap.
        let value = Int(typed.prefix(5)) ?? 0
        return (value / 100, value % 100)
    }
}
