//
//  HighlightSnappingTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.2 of docs/features/highlighting/ — the one snapping implementation.
//  These are the cases the app's three previous copies DISAGREED on (08 §iPhone);
//  the contract in 03 §5 settles each one.
//

import XCTest
@testable import MakeReady

final class HighlightSnappingWordTests: XCTestCase {

    // MARK: The apostrophe case — the reason the copies diverged

    func testApostropheIsIntraWordSoLordsStaysWhole() {
        let text = "The Lord's word" as NSString
        let ord = text.range(of: "ord'")  // starts mid-"Lord", ends mid-"Lord's"

        let snapped = HighlightSnapping.snapToWordBoundaries(
            NSRange(location: ord.location, length: 3), in: text)

        XCTAssertEqual(text.substring(with: snapped), "Lord's")
    }

    func testTypographicApostropheIsAlsoIntraWord() {
        let text = "The Lord\u{2019}s word" as NSString
        let mid = NSRange(location: 5, length: 2)  // "or" inside "Lord’s"
        let snapped = HighlightSnapping.snapToWordBoundaries(mid, in: text)
        XCTAssertEqual(text.substring(with: snapped), "Lord\u{2019}s")
    }

    func testHyphenIsIntraWord() {
        let text = "a God-fearing man" as NSString
        let mid = NSRange(location: 3, length: 2)  // "Go"
        let snapped = HighlightSnapping.snapToWordBoundaries(mid, in: text)
        XCTAssertEqual(text.substring(with: snapped), "God-fearing")
    }

    func testOtherPunctuationIsABoundary() {
        let text = "In beginning, God" as NSString
        let mid = NSRange(location: 4, length: 5)  // "eginn"
        let snapped = HighlightSnapping.snapToWordBoundaries(mid, in: text)
        XCTAssertEqual(text.substring(with: snapped), "beginning")
    }

    // MARK: The verse-terminating newline case

    func testSelectionEndingAtAVerseNewlineDoesNotWalkIntoTheNextVerse() {
        let text = "1. In the beginning\n2. And the earth" as NSString
        let firstVerse = NSRange(location: 0, length: 20)  // through the "\n"
        XCTAssertEqual(text.substring(with: firstVerse), "1. In the beginning\n")

        let snapped = HighlightSnapping.snapToWordBoundaries(firstVerse, in: text)

        XCTAssertEqual(snapped, firstVerse, "the trailing newline is already a boundary")
    }

    // MARK: Grow-only

    func testNeverTrimsWhatTheUserCovered() {
        let text = "The Lord's word" as NSString
        let cases = [
            NSRange(location: 3, length: 8),   // " Lord's "  — both ends on whitespace
            NSRange(location: 0, length: 15),  // everything
            NSRange(location: 4, length: 6)    // exactly "Lord's"
        ]
        for original in cases {
            let snapped = HighlightSnapping.snapToWordBoundaries(original, in: text)
            XCTAssertLessThanOrEqual(snapped.location, original.location)
            XCTAssertGreaterThanOrEqual(snapped.location + snapped.length,
                                        original.location + original.length)
        }
    }

    func testLeavesDegenerateAndOutOfBoundsRangesAlone() {
        let text = "The Lord's word" as NSString
        let empty = NSRange(location: 4, length: 0)
        let past = NSRange(location: 12, length: 40)
        XCTAssertEqual(HighlightSnapping.snapToWordBoundaries(empty, in: text), empty)
        XCTAssertEqual(HighlightSnapping.snapToWordBoundaries(past, in: text), past)
    }
}

final class HighlightSnappingVerseTests: XCTestCase {

    /// v1 = 0..<20, v2 = 20..<37, v3 = 37..<50.
    private let verseRanges: [VerseRange] = [
        (verse: 1, range: NSRange(location: 0, length: 20)),
        (verse: 2, range: NSRange(location: 20, length: 17)),
        (verse: 3, range: NSRange(location: 37, length: 13))
    ]

    func testWidensAPartialSelectionToTheWholeVerse() {
        let clipped = NSRange(location: 5, length: 4)
        let snapped = HighlightSnapping.snapToVerseBoundaries(clipped, verseRanges: verseRanges)
        XCTAssertEqual(snapped, NSRange(location: 0, length: 20))
    }

    func testWidensAcrossEveryVerseTouched() {
        let clipped = NSRange(location: 15, length: 30)  // clips v1, all of v2, clips v3
        let snapped = HighlightSnapping.snapToVerseBoundaries(clipped, verseRanges: verseRanges)
        XCTAssertEqual(snapped, NSRange(location: 0, length: 50))
    }

    func testIsGrowOnlyWhenTheVerseMapIsShorterThanTheSelection() {
        let past = NSRange(location: 5, length: 60)
        let snapped = HighlightSnapping.snapToVerseBoundaries(past, verseRanges: verseRanges)
        XCTAssertEqual(snapped.location, 0)
        XCTAssertEqual(snapped.location + snapped.length, 65)
    }

    func testReturnsTheRangeUnchangedWithNoVerseMap() {
        let range = NSRange(location: 5, length: 4)
        XCTAssertEqual(HighlightSnapping.snapToVerseBoundaries(range, verseRanges: []), range)
    }
}

final class HighlightGranularityTests: XCTestCase {

    // "1. In the beginning" is 0..<20 including the newline; "2. And the earth" follows.
    private let text = "1. In the beginning\n2. And the earth" as NSString
    private let verseRanges: [VerseRange] = [
        (verse: 1, range: NSRange(location: 0, length: 20)),
        (verse: 2, range: NSRange(location: 20, length: 16))
    ]

    /// The same call drives every surface — only the injected granularity differs.
    func testOneEntryPointProducesVerseWordAndCharacterResults() {
        let clipped = NSRange(location: 10, length: 3)  // "beg"

        let verse = HighlightSnapping.snap(clipped, in: text,
                                           granularity: .verse, verseRanges: verseRanges)
        let word = HighlightSnapping.snap(clipped, in: text,
                                          granularity: .word, verseRanges: verseRanges)
        let character = HighlightSnapping.snap(clipped, in: text,
                                               granularity: .character, verseRanges: verseRanges)

        XCTAssertEqual(text.substring(with: verse), "1. In the beginning\n")
        XCTAssertEqual(text.substring(with: word), "beginning")
        XCTAssertEqual(character, clipped)
    }

    func testSpanFlavourMatchesTheNSRangeFlavour() {
        let span = HighlightSpan(start: 10, end: 13)!
        let snapped = HighlightSnapping.snap(span, in: text,
                                             granularity: .word, verseRanges: verseRanges)
        XCTAssertEqual(snapped, HighlightSpan(start: 10, end: 19))
    }
}
