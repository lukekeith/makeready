//
//  VerseSelectionLogic.swift
//  MakeReady
//
//  Shared verse selection and rendering logic used by both the Bible reader
//  and the exegesis activity editor. Each consumer owns its own UITextView
//  and circle views — this utility provides the pure logic functions.
//

import UIKit

// MARK: - Verse Range Type

typealias VerseRange = (verse: Int, range: NSRange)

// MARK: - Selection Logic

enum VerseSelectionLogic {

    /// Find which verses overlap the given character range.
    static func versesOverlapping(_ range: NSRange, verseRanges: [VerseRange]) -> [Int] {
        guard range.length > 0 else { return [] }
        let rangeEnd = range.location + range.length
        return verseRanges
            .filter { entry in
                let entryEnd = entry.range.location + entry.range.length
                return entry.range.location < rangeEnd && entryEnd > range.location
            }
            .map(\.verse)
            .sorted()
    }

    /// Build a character range spanning from verse `from` to verse `to` (inclusive).
    static func rangeForVerses(from: Int, to: Int, verseRanges: [VerseRange]) -> NSRange? {
        guard let startEntry = verseRanges.first(where: { $0.verse == from }),
              let endEntry = verseRanges.first(where: { $0.verse == to }) else { return nil }
        let loc = startEntry.range.location
        let len = (endEntry.range.location + endEntry.range.length) - loc
        return NSRange(location: loc, length: len)
    }

    /// Handle a verse circle tap. Returns the new selection range (nil = clear).
    ///
    /// Behavior:
    /// - No selection → select the tapped verse
    /// - Tap inside selection → clear
    /// - Tap outside selection → extend range to include tapped verse
    static func handleCircleTap(
        verseNum: Int,
        currentSelection: NSRange,
        verseRanges: [VerseRange]
    ) -> NSRange? {
        let overlapping = versesOverlapping(currentSelection, verseRanges: verseRanges)
        let currentMin = overlapping.first
        let currentMax = overlapping.last

        // Tap inside current selection → clear
        if let minV = currentMin, let maxV = currentMax,
           verseNum >= minV && verseNum <= maxV {
            return nil // signal to clear
        }

        // No selection → select just this verse
        // Existing selection → extend to include tapped verse
        let newMin = min(currentMin ?? verseNum, verseNum)
        let newMax = max(currentMax ?? verseNum, verseNum)

        return rangeForVerses(from: newMin, to: newMax, verseRanges: verseRanges)
    }

    /// Handle a text body tap. Returns the new selection range (nil = clear).
    ///
    /// Behavior:
    /// - Active selection → clear (any tap on text dismisses)
    /// - No selection → select the verse containing the character index
    static func handleTextTap(
        charIndex: Int,
        currentSelection: NSRange,
        verseRanges: [VerseRange]
    ) -> NSRange? {
        // Active selection → clear
        if currentSelection.length > 0 {
            return nil
        }

        // No selection → find and select the tapped verse
        guard let entry = verseRanges.first(where: {
            charIndex >= $0.range.location && charIndex < $0.range.location + $0.range.length
        }) else {
            return nil
        }

        return entry.range
    }

    // MARK: - Word Boundary Snapping

    /// Snap a selection range to word boundaries. Returns the snapped range,
    /// or the original if no snapping was needed.
    static func snapToWordBoundaries(_ sel: NSRange, in text: NSString) -> NSRange {
        guard sel.length > 0 else { return sel }

        let isWordChar: (Int) -> Bool = { pos in
            guard pos >= 0 && pos < text.length else { return false }
            guard let scalar = Unicode.Scalar(text.character(at: pos)) else { return false }
            return !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.punctuationCharacters.contains(scalar)
        }

        var wordStart = sel.location
        while wordStart > 0 && isWordChar(wordStart - 1) {
            wordStart -= 1
        }

        var wordEnd = sel.location + sel.length
        if wordEnd > 0 && isWordChar(wordEnd - 1) {
            while wordEnd < text.length && isWordChar(wordEnd) {
                wordEnd += 1
            }
        }

        if wordStart >= wordEnd {
            return sel
        }

        return NSRange(location: wordStart, length: wordEnd - wordStart)
    }

    // MARK: - Circle Highlight State

    struct CircleState {
        let isSelected: Bool
        let isUsed: Bool
    }

    /// Compute the highlight state for each verse circle based on the current selection.
    static func circleStates(
        verseRanges: [VerseRange],
        selection: NSRange,
        usedVerses: Set<Int> = []
    ) -> [Int: CircleState] {
        var states: [Int: CircleState] = [:]
        for entry in verseRanges {
            let overlapStart = max(selection.location, entry.range.location)
            let overlapEnd = min(selection.location + selection.length, entry.range.location + entry.range.length)
            let isSelected = selection.length > 0 && overlapStart < overlapEnd
            let isUsed = usedVerses.contains(entry.verse)
            states[entry.verse] = CircleState(isSelected: isSelected, isUsed: isUsed)
        }
        return states
    }

    // MARK: - Text Cleaning

    /// Clean verse text: strip escaped newlines, pilcrow marks, collapse whitespace.
    static func cleanVerseText(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "\\n", with: " ")
        s = s.replacingOccurrences(of: "\\r", with: " ")
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = s.replacingOccurrences(of: "\r", with: " ")
        s = s.replacingOccurrences(of: "¶", with: "")
        while s.contains("  ") {
            s = s.replacingOccurrences(of: "  ", with: " ")
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Verse Parsing

    /// Parse verse positions from plain text that contains inline verse numbers
    /// like "1. In the beginning...\n2. And the earth...".
    /// Returns both the full verse ranges and the number prefix ranges.
    struct ParsedVerses {
        let verseRanges: [VerseRange]
        let numberRanges: [(verse: Int, range: NSRange)]
    }

    static func parseVersePositions(from text: String) -> ParsedVerses {
        let nsText = text as NSString
        let length = nsText.length
        guard length > 0 else { return ParsedVerses(verseRanges: [], numberRanges: []) }

        let pattern = "(?:^|(?<=[\\n]))(\\d+)\\.?\\s"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ParsedVerses(verseRanges: [], numberRanges: [])
        }

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: length))

        var versePositions: [(number: Int, matchRange: NSRange, numRange: NSRange)] = []
        var expectedNext = 0

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let numRange = match.range(at: 1)
            guard let num = Int(nsText.substring(with: numRange)) else { continue }

            if expectedNext == 0 {
                versePositions.append((number: num, matchRange: match.range, numRange: numRange))
                expectedNext = num + 1
            } else if num == expectedNext {
                versePositions.append((number: num, matchRange: match.range, numRange: numRange))
                expectedNext = num + 1
            }
        }

        var verseRanges: [VerseRange] = []
        var numberRanges: [(verse: Int, range: NSRange)] = []

        for (i, pos) in versePositions.enumerated() {
            let verseStart = pos.matchRange.location
            let verseEnd: Int
            if i + 1 < versePositions.count {
                verseEnd = versePositions[i + 1].matchRange.location
            } else {
                verseEnd = length
            }
            verseRanges.append((verse: pos.number, range: NSRange(location: verseStart, length: verseEnd - verseStart)))
            numberRanges.append((verse: pos.number, range: pos.matchRange))
        }

        return ParsedVerses(verseRanges: verseRanges, numberRanges: numberRanges)
    }
}
