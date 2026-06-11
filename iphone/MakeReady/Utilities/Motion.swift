//
//  Motion.swift
//  MakeReady
//
//  Motion tokens (Phase 3.1) — a pure NAMING pass over the durations and
//  curves the app already uses. Every token is value-identical to the
//  literals it replaced; transitions are frame-identical by construction.
//
//  ⚠️ Decision Point D (audit plan): collapsing near-duplicate values
//  (e.g. 0.25 vs 0.3, easeOut vs easeInOut) is a FEEL change and needs
//  separate approval. Do not "clean up" values here.
//
//  Not yet tokenized (intentionally): one-off decorative timings
//  (shimmers, progress bars, 1s+ pulses) and parameterized/dynamic
//  animations — they stay literal at their call sites.
//

import SwiftUI

enum Motion {

    // MARK: - Micro-interactions (toggles, selection, small reveals)

    /// easeInOut 0.2 — the app's most common micro-interaction timing
    static let micro = Animation.easeInOut(duration: 0.2)

    /// easeInOut 0.15 — fastest micro variant
    static let microFast = Animation.easeInOut(duration: 0.15)

    // MARK: - Standard content transitions (page slides, tab content)

    /// easeInOut 0.3 — the default content/page transition
    static let standard = Animation.easeInOut(duration: 0.3)

    /// easeInOut 0.25 — slightly brisker standard variant
    static let standardBrisk = Animation.easeInOut(duration: 0.25)

    // MARK: - Page push / dismiss (hand-rolled slider navigation)

    /// easeOut 0.3 — page push (decelerating entry)
    static let pagePush = Animation.easeOut(duration: 0.3)

    /// easeOut 0.25 — brisker push
    static let pagePushBrisk = Animation.easeOut(duration: 0.25)

    /// easeOut 0.2 — short settle (snap-back, small entries)
    static let settle = Animation.easeOut(duration: 0.2)

    /// easeIn 0.25 — page dismiss (accelerating exit)
    static let pageDismiss = Animation.easeIn(duration: 0.25)

    /// easeIn 0.2 — faster exit
    static let exit = Animation.easeIn(duration: 0.2)

    /// easeIn 0.15 — fastest exit
    static let exitFast = Animation.easeIn(duration: 0.15)

    // MARK: - Springs

    /// spring(response: 0.4, dampingFraction: 0.85) — modal presentation.
    /// Single source of truth stays ModalAnimations.appear.
    static let modalPresent = ModalAnimations.appear

    /// spring(response: 0.3, dampingFraction: 0.85) — modal dismissal.
    static let modalDismiss = ModalAnimations.dismiss

    /// spring(response: 0.3, dampingFraction: 0.8) — snappy interactive spring
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// spring(response: 0.4, dampingFraction: 0.8) — softer spring
    static let springSoft = Animation.spring(response: 0.4, dampingFraction: 0.8)
}
