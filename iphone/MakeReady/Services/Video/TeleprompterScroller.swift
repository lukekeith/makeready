//
//  TeleprompterScroller.swift
//  MakeReady
//
//  Where the teleprompter script sits for a given recorded time (video-recorder D7). The position
//  is a function of recorded time only: a pause stops the clock, so the line holds, and the next
//  segment continues from it.
//

import CoreGraphics
import Foundation

struct TeleprompterScroller: Equatable {
    /// Points per second for speed steps 1…5.
    static let pointsPerSecond: [CGFloat] = [12, 18, 24, 32, 42]

    let speedStep: Int

    init(speedStep: Int) {
        self.speedStep = min(max(speedStep, 1), Self.pointsPerSecond.count)
    }

    /// The scroll offset in points after `t` seconds of recording. `lineHeight` is the band's
    /// current text size; the scroll speed does not depend on it, so a size change mid-script keeps
    /// the pace.
    func offset(atRecorded t: TimeInterval, lineHeight: CGFloat) -> CGFloat {
        Self.pointsPerSecond[speedStep - 1] * CGFloat(max(t, 0))
    }
}
