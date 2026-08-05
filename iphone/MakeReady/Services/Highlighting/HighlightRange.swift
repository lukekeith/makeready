//
//  HighlightRange.swift
//  MakeReady
//
//  Positions, for the one highlighting service.
//
//  Two coordinate systems exist in this app and they are not interchangeable:
//
//  1. `HighlightSpan` — ABSOLUTE character offsets into a block's plain text.
//     This is the contract's coordinate system (`ContentHighlight.start` /
//     `.end`, and `ActivityReadBlock.selections[]`), and the one the snapper,
//     the renderer and the selection controller all work in.
//
//  2. `HighlightRange` — VERSE-RELATIVE coordinates ("45-1-5" + an offset into
//     that verse). Moved here verbatim from `StudyModels.swift` — it is a wire
//     type on `StudyActivity`, so its name, fields and Codable shape are fixed.
//     The Bible reader uses it to recreate an exact position inside a passage.
//
//  `VerseCoordinateSpace` converts between them. See
//  docs/features/highlighting/06-iphone.md §The service.
//

import Foundation

// MARK: - Absolute span

/// A half-open span of plain text: `start..<end`, in characters, measured
/// against the same stripped plain-text representation the server stores
/// offsets against.
///
/// Empty and inverted spans cannot be constructed — a highlight that covers
/// nothing is a bug, not a value, and every producer here has somewhere better
/// to put the failure than a zero-length range.
struct HighlightSpan: Equatable, Hashable, Comparable {

    let start: Int
    /// Exclusive.
    let end: Int

    init?(start: Int, end: Int) {
        guard start >= 0, end > start else { return nil }
        self.start = start
        self.end = end
    }

    init?(_ range: NSRange) {
        guard range.location != NSNotFound else { return nil }
        self.init(start: range.location, end: range.location + range.length)
    }

    var nsRange: NSRange { NSRange(location: start, length: end - start) }

    var length: Int { end - start }

    func contains(offset: Int) -> Bool { offset >= start && offset < end }

    /// True when the two spans share at least one character. Adjacency
    /// (`a.end == b.start`) is deliberately NOT an overlap — the server merges
    /// on overlap only (03 §2.2), and consumers must not diverge from it.
    func overlaps(_ other: HighlightSpan) -> Bool {
        start < other.end && other.start < end
    }

    /// The span covering both, including any gap between them.
    func union(_ other: HighlightSpan) -> HighlightSpan {
        // Both operands are valid, so the union is too.
        HighlightSpan(start: Swift.min(start, other.start),
                      end: Swift.max(end, other.end)) ?? self
    }

    /// Trimmed to fit text of `length` characters, or nil if nothing survives.
    func clamped(toLength length: Int) -> HighlightSpan? {
        HighlightSpan(start: Swift.min(start, length), end: Swift.min(end, length))
    }

    static func < (lhs: HighlightSpan, rhs: HighlightSpan) -> Bool {
        lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
    }
}

// MARK: - Verse-relative range

/// Word-level highlight range for precise text selection.
/// Used to recreate exact highlight position in Bible reader.
///
/// Moved from `StudyModels.swift` (2026-08-04, highlighting phase 4.1) without
/// changing its shape — it is encoded onto `StudyActivity` by
/// `ProgramActions.updateActivity`, so renaming or re-typing a field here is a
/// wire-format change.
struct HighlightRange: Codable, Equatable {
    let startElementId: String   // "45-1-1" (bookNum-chapter-verse)
    let startOffset: Int         // Character offset in start verse
    let endElementId: String     // "45-1-5"
    let endOffset: Int           // Character offset in end verse (exclusive)
}

// MARK: - Element ids

/// The `bookNumber-chapter-verse` triple an element id encodes.
struct VerseCoordinate: Equatable {

    let bookNumber: Int
    let chapter: Int
    let verse: Int

    var elementId: String { "\(bookNumber)-\(chapter)-\(verse)" }

    init(bookNumber: Int, chapter: Int, verse: Int) {
        self.bookNumber = bookNumber
        self.chapter = chapter
        self.verse = verse
    }

    init?(elementId: String) {
        let parts = elementId.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let bookNumber = Int(parts[0]),
              let chapter = Int(parts[1]),
              let verse = Int(parts[2]) else { return nil }
        self.init(bookNumber: bookNumber, chapter: chapter, verse: verse)
    }
}

// MARK: - Conversion

/// Maps absolute offsets in one rendered chapter to verse coordinates and back.
///
/// Built from the `verseRanges` a surface already computes — the Bible reader
/// walks the rendered text to produce exactly this shape
/// (`BibleReaderOverlay.verseRanges`), and `VerseSelectionLogic.parseVersePositions`
/// produces it for content that carries inline verse numbers.
struct VerseCoordinateSpace {

    let bookNumber: Int
    let chapter: Int
    let verseRanges: [VerseRange]

    init(bookNumber: Int, chapter: Int, verseRanges: [VerseRange]) {
        self.bookNumber = bookNumber
        self.chapter = chapter
        self.verseRanges = verseRanges
    }

    // MARK: Absolute → verse-relative

    /// The verse-relative range for an absolute span, or nil when the span
    /// falls outside every known verse.
    ///
    /// `endOffset` is exclusive and measured inside the verse containing the
    /// span's LAST covered character — so it is always ≥ 1, which is what makes
    /// the legacy `endOffset == 0` sentinel below unambiguous.
    func range(for span: HighlightSpan) -> HighlightRange? {
        guard let startEntry = entry(containing: span.start),
              let endEntry = entry(containing: span.end - 1) else { return nil }

        return HighlightRange(
            startElementId: coordinate(verse: startEntry.verse).elementId,
            startOffset: span.start - startEntry.range.location,
            endElementId: coordinate(verse: endEntry.verse).elementId,
            endOffset: span.end - endEntry.range.location
        )
    }

    // MARK: Verse-relative → absolute

    /// The absolute span for a verse-relative range, or nil when either end
    /// names a verse this space does not contain, or a different book/chapter.
    ///
    /// **Legacy sentinel:** every `HighlightRange` written by this app before
    /// the highlighting feature stores `startOffset: 0, endOffset: 0` to mean
    /// "the whole verse range" (`EditDay.swift`, `EditReadActivityPage.swift`).
    /// A genuine exclusive end offset is never 0, so `endOffset == 0` is read
    /// as "through the end of that verse" rather than as an empty span.
    func span(for range: HighlightRange) -> HighlightSpan? {
        guard let startCoordinate = VerseCoordinate(elementId: range.startElementId),
              let endCoordinate = VerseCoordinate(elementId: range.endElementId),
              contains(startCoordinate), contains(endCoordinate),
              let startEntry = entry(verse: startCoordinate.verse),
              let endEntry = entry(verse: endCoordinate.verse) else { return nil }

        let start = startEntry.range.location + range.startOffset
        let end = range.endOffset == 0
            ? endEntry.range.location + endEntry.range.length
            : endEntry.range.location + range.endOffset

        return HighlightSpan(start: start, end: end)
    }

    // MARK: Lookups

    func coordinate(verse: Int) -> VerseCoordinate {
        VerseCoordinate(bookNumber: bookNumber, chapter: chapter, verse: verse)
    }

    private func contains(_ coordinate: VerseCoordinate) -> Bool {
        coordinate.bookNumber == bookNumber && coordinate.chapter == chapter
    }

    private func entry(verse: Int) -> VerseRange? {
        verseRanges.first { $0.verse == verse }
    }

    private func entry(containing offset: Int) -> VerseRange? {
        verseRanges.first {
            offset >= $0.range.location && offset < $0.range.location + $0.range.length
        }
    }
}
