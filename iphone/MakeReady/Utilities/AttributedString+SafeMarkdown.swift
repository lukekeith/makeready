//
//  AttributedString+SafeMarkdown.swift
//  MakeReady
//
//  Safe markdown parsing that falls back to the literal string instead of crashing.
//

import Foundation

extension AttributedString {

    /// Parses the given string as markdown, falling back to the literal
    /// (unstyled) string if parsing fails.
    ///
    /// Use this instead of `try! AttributedString(markdown:)`, which crashes
    /// on invalid markdown input (e.g. user-entered program or group names
    /// interpolated into a markdown template).
    static func safeMarkdown(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
