//
//  HighlightSnapping.swift
//  MakeReady
//
//  ONE snapping implementation, for every surface that highlights text.
//
//  Before this, the app had three: `VerseSelectionLogic.snapToWordBoundaries`
//  (the canonical copy, with zero callers), `ExegesisVerseView
//  .snappedToWordBoundaries`, and an inline closure in `BibleReaderOverlay
//  .textViewDidChangeSelection`. They disagreed about apostrophes — so "Lord's"
//  snapped to a whole word on one surface and split on another.
//
//  The contract settles it (03 §5): grow-only, outward from the user's range,
//  with `'` `’` `-` intra-word. Granularity is INJECTED per surface — the same
//  controller drives a verse-granular Read editor and a word-granular Exegesis
//  editor. See docs/features/highlighting/06-iphone.md §Snapping.
//

import Foundation

/// How far a raw drag is widened before it becomes a highlight.
///
/// `.character` exists because the type would otherwise lie about what the
/// engine can do, but no surface ships with it — 03 §5 assigns `.verse` to the
/// Read editor and `.word` to the Exegesis editor and the Bible reader.
enum HighlightGranularity: String, Equatable, CaseIterable {
    case verse
    case word
    case character
}

enum HighlightSnapping {

    // MARK: - Entry point

    /// Widen `range` to `granularity`'s boundaries. Never trims: whatever the
    /// user covered stays covered.
    ///
    /// `verseRanges` is only consulted for `.verse` — pass what the surface
    /// already computed, or `[]` when it has none (the range comes back
    /// unchanged rather than snapping to something invented).
    static func snap(
        _ range: NSRange,
        in text: NSString,
        granularity: HighlightGranularity,
        verseRanges: [VerseRange] = []
    ) -> NSRange {
        switch granularity {
        case .character:
            return range
        case .word:
            return snapToWordBoundaries(range, in: text)
        case .verse:
            return snapToVerseBoundaries(range, verseRanges: verseRanges)
        }
    }

    /// `HighlightSpan` flavour of the above. Returns nil only when the snapped
    /// result is empty, which means the input covered nothing to begin with.
    static func snap(
        _ span: HighlightSpan,
        in text: NSString,
        granularity: HighlightGranularity,
        verseRanges: [VerseRange] = []
    ) -> HighlightSpan? {
        HighlightSpan(snap(span.nsRange, in: text, granularity: granularity, verseRanges: verseRanges))
    }

    // MARK: - Word

    /// Widens `range` outward so both ends land on word boundaries.
    ///
    /// Only ever grows the range. An end that already sits on a boundary is
    /// left alone — which is what stops a whole-verse selection, whose trailing
    /// character is the newline that terminates the verse, from walking forward
    /// into the first word of the next verse.
    static func snapToWordBoundaries(_ range: NSRange, in text: NSString) -> NSRange {
        guard range.length > 0,
              range.location >= 0,
              range.location + range.length <= text.length else { return range }

        var start = range.location
        var end = range.location + range.length

        // Extend only while genuinely mid-word — i.e. word characters on both
        // sides of the boundary.
        while start > 0, isWordCharacter(at: start, in: text), isWordCharacter(at: start - 1, in: text) {
            start -= 1
        }
        while end < text.length, isWordCharacter(at: end, in: text), isWordCharacter(at: end - 1, in: text) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    /// Whether the character at `index` belongs to a word.
    ///
    /// Alphanumerics, plus the three intra-word marks 03 §5 names: the straight
    /// apostrophe, the typographic apostrophe the Bible text actually uses, and
    /// the hyphen. Everything else — whitespace, and all other punctuation — is
    /// a boundary.
    static func isWordCharacter(at index: Int, in text: NSString) -> Bool {
        guard index >= 0, index < text.length else { return false }
        let scalars = text.substring(with: NSRange(location: index, length: 1)).unicodeScalars
        guard let scalar = scalars.first, scalars.count == 1 else { return false }
        if CharacterSet.alphanumerics.contains(scalar) { return true }
        return scalar == "'" || scalar == "\u{2019}" || scalar == "-"
    }

    // MARK: - Verse

    /// Widens `range` to cover every verse it touches, whole.
    ///
    /// This is the Read editor's granularity: a leader highlights verses, not
    /// phrases, so a drag that clips two words out of two verses becomes both
    /// verses entire.
    static func snapToVerseBoundaries(_ range: NSRange, verseRanges: [VerseRange]) -> NSRange {
        guard range.length > 0, !verseRanges.isEmpty else { return range }

        let touched = VerseSelectionLogic.versesOverlapping(range, verseRanges: verseRanges)
        guard let first = touched.first, let last = touched.last,
              let snapped = VerseSelectionLogic.rangeForVerses(from: first, to: last, verseRanges: verseRanges)
        else { return range }

        // Grow-only, even against a malformed verse map: never hand back
        // something narrower than the user dragged.
        return NSUnionRange(range, snapped)
    }
}
