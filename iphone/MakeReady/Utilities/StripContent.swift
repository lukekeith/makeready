//
//  StripContent.swift
//  MakeReady
//
//  Canonical "what offsets are relative to" function for read-block selections.
//  Both the iPhone selection UI and any future web port must produce the same
//  plain-text output for a given block content so character offsets line up.
//

import Foundation

/// Strips HTML tags and decodes a small set of named entities to produce the
/// plain-text representation used as the offset basis for `ReadBlockSelection`
/// records. Mirrors the regex pipeline that previously lived inside
/// `EditReadActivityPage.stripHTML`.
///
/// Uses regex (not NSAttributedString.init(html:)) because WebKit triggers
/// AttributeGraph crashes when invoked during SwiftUI body evaluation.
func stripBlockContentToPlain(_ html: String) -> String {
    var text = html
    text = text.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "</p>", with: "\n")
    text = text.replacingOccurrences(of: "</div>", with: "\n")
    text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    text = BibleVerseContentNormalizer.decodeEntities(in: text)
    text = text.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
    text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Canonical formatter for scripture read-block content.
///
/// The API stores `ActivityReadBlock.content` as caller-provided markdown/html.
/// Bible selections can therefore arrive with hard line breaks, HTML tags,
/// non-breaking spaces, or copied markdown indentation. This utility turns those
/// variants into one stable markdown/plain-text shape:
///
/// ```
/// 1. In the beginning...
/// 2. The earth was...
/// ```
///
/// Renderers can then hide or externalize the verse number while selection
/// offsets stay relative to the same normalized string everywhere in the app.
enum BibleVerseContentNormalizer {
    struct Verse: Equatable {
        let number: Int
        let text: String
    }

    static func normalizedMarkdown(from input: String) -> String {
        let verses = parseVerses(from: input)
        guard !verses.isEmpty else {
            return collapseWhitespace(in: markdownAndHTMLToText(input))
        }

        return verses
            .map { "\($0.number). \($0.text)" }
            .joined(separator: "\n")
    }

    static func normalizedPlainText(from input: String) -> String {
        normalizedMarkdown(from: input)
    }

    static func parseVerses(from input: String) -> [Verse] {
        let text = markdownAndHTMLToText(input)
        let candidates = verseMarkerCandidates(in: text)
        guard !candidates.isEmpty else { return [] }

        var verses: [Verse] = []
        let nsText = text as NSString

        for (index, candidate) in candidates.enumerated() {
            let start = candidate.markerEnd
            let end = index + 1 < candidates.count ? candidates[index + 1].markerStart : nsText.length
            guard end >= start else { continue }

            let rawVerseText = nsText.substring(with: NSRange(location: start, length: end - start))
            let cleaned = collapseWhitespace(in: rawVerseText)
            guard !cleaned.isEmpty else { continue }
            verses.append(Verse(number: candidate.number, text: cleaned))
        }

        return verses
    }

    static func markdownAndHTMLToText(_ input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // HTML block-ish boundaries become verse-boundary candidates; inline
        // tags such as <sup> keep their text content.
        text = text.replacingOccurrences(of: "<sup[^>]*>\\s*(\\d{1,3})\\s*</sup>", with: "\n$1. ", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</(p|div|li|tr|h[1-6])>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(in: text)
        text = normalizeSuperscriptVerseMarkers(in: text)

        // Remove markdown wrappers that do not belong to the verse body.
        text = text.replacingOccurrences(of: "(?m)^\\s{0,3}#{1,6}\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s{0,3}>\\s?", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s*[-*+]\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(in input: String) -> String {
        var text = input
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")

        text = replaceNumericEntities(in: text, pattern: "&#(\\d+);") { Int($0) }
        text = replaceNumericEntities(in: text, pattern: "&#x([0-9a-fA-F]+);") { Int($0, radix: 16) }
        return text
    }

    private struct VerseMarkerCandidate {
        let number: Int
        let markerStart: Int
        let markerEnd: Int
        let hasExplicitSeparator: Bool
    }

    private static func verseMarkerCandidates(in text: String) -> [VerseMarkerCandidate] {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else { return [] }

        let pattern = "(?:^|\\n)\\s*(\\d{1,3})([.)]?)\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: length))
        let rawCandidates: [VerseMarkerCandidate] = matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }
            let numberRange = match.range(at: 1)
            guard let number = Int(nsText.substring(with: numberRange)) else { return nil }
            let separatorRange = match.range(at: 2)
            let hasSeparator = separatorRange.location != NSNotFound && separatorRange.length > 0

            return VerseMarkerCandidate(
                number: number,
                markerStart: numberRange.location,
                markerEnd: match.range.location + match.range.length,
                hasExplicitSeparator: hasSeparator
            )
        }
        guard !rawCandidates.isEmpty else { return [] }

        var best: [VerseMarkerCandidate] = []
        var bestSeparatorCount = -1

        for startIndex in rawCandidates.indices {
            var chain = [rawCandidates[startIndex]]
            var expectedNext = rawCandidates[startIndex].number + 1

            for candidate in rawCandidates.dropFirst(startIndex + 1) where candidate.number == expectedNext {
                chain.append(candidate)
                expectedNext += 1
            }

            let separatorCount = chain.filter(\.hasExplicitSeparator).count
            if chain.count > best.count ||
                (chain.count == best.count && separatorCount > bestSeparatorCount) {
                best = chain
                bestSeparatorCount = separatorCount
            }
        }

        return best
    }

    private static func collapseWhitespace(in input: String) -> String {
        var text = input
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "¶", with: "")
        text = text.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeSuperscriptVerseMarkers(in input: String) -> String {
        let superscriptDigits: [Character: Character] = [
            "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4",
            "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9"
        ]

        var result = ""
        var index = input.startIndex

        while index < input.endIndex {
            let character = input[index]
            guard superscriptDigits[character] != nil else {
                result.append(character)
                index = input.index(after: index)
                continue
            }

            var markerEnd = index
            var digits = ""
            while markerEnd < input.endIndex,
                  let digit = superscriptDigits[input[markerEnd]] {
                digits.append(digit)
                markerEnd = input.index(after: markerEnd)
            }

            let previous = index == input.startIndex ? "\n" : input[input.index(before: index)]
            let isBoundary = index == input.startIndex || previous == "\n" || previous.isWhitespace
            if isBoundary {
                if index != input.startIndex, previous != "\n" {
                    result.append("\n")
                }
                result.append(digits)
                result.append(" ")
            } else {
                result.append(contentsOf: input[index..<markerEnd])
            }
            index = markerEnd
        }

        return result
    }

    private static func replaceNumericEntities(
        in input: String,
        pattern: String,
        transform: (String) -> Int?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let nsText = input as NSString
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsText.length))
        var result = input

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }
            let raw = nsText.substring(with: match.range(at: 1))
            guard let codePoint = transform(raw),
                  let scalar = UnicodeScalar(codePoint) else { continue }
            let replacement = String(Character(scalar))
            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }

        return result
    }
}
