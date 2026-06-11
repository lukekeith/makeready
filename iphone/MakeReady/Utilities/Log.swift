//
//  Log.swift
//  MakeReady
//
//  Per-domain os.Logger wrappers (Phase 5.2). New code logs through these —
//  the SwiftLint gate (Phase 5.1) blocks new print/NSLog call sites; the
//  ~800 existing ones are baselined and migrate opportunistically.
//
//  Usage:
//      Log.nav.info("navigated to \(destination, privacy: .public)")
//      Log.media.error("upload failed: \(error.localizedDescription, privacy: .public)")
//
//  Privacy: os.Logger redacts non-constant interpolations by default in
//  release builds. Mark values `.public` only when they carry no user data
//  (route names, counts, durations); user identifiers, names, emails, and
//  content stay private (the default) or use `.private(mask: .hash)` when
//  you need to correlate without exposing.
//
//  Viewing: Console.app or `log stream --predicate 'subsystem == "<bundle id>"'`
//  — unlike NSLog, info/debug levels are off-by-default in release and cost
//  almost nothing when not captured.
//

import Foundation
import os

enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "org.makeready.app"

    /// Sign-in, session lifecycle, token exchange.
    static let auth = Logger(subsystem: subsystem, category: "auth")
    /// AppState mutations, persistence, entity stores.
    static let state = Logger(subsystem: subsystem, category: "state")
    /// NavigationCoordinator, deep links, overlay presentation.
    static let nav = Logger(subsystem: subsystem, category: "nav")
    /// Media library, image cache, uploads.
    static let media = Logger(subsystem: subsystem, category: "media")
    /// APIClient requests/responses.
    static let api = Logger(subsystem: subsystem, category: "api")
    /// Push notifications, device tokens, APNs.
    static let push = Logger(subsystem: subsystem, category: "push")
    /// View-layer events that don't fit a domain above.
    static let ui = Logger(subsystem: subsystem, category: "ui")
    /// Bible content, search, caching.
    static let bible = Logger(subsystem: subsystem, category: "bible")
}
