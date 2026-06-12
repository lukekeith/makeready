//
//  ModelFormatters.swift
//  MakeReady
//
//  Shared formatter cache for the model layer's display helpers.
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

/// Formatter cache for the model layer's display helpers.
/// These computed properties run on the render path (per row, per render) —
/// creating a formatter each call costs ~ms. Main-thread use only, like
/// DateFormatters (see Date+Formatting.swift's thread-safety note).
/// Became internal (was `private`) when the models split into per-domain
/// files (Phase 5.7).
enum ModelFormatters {
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    static let monthAbbrev: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    static let dayOfMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    static let fileSize: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}
