//
//  HighlightRangeTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.1 of docs/features/highlighting/ — the position type and the
//  absolute ↔ verse-relative conversion.
//

import XCTest
@testable import MakeReady

final class HighlightSpanTests: XCTestCase {

    // MARK: Construction

    func testRejectsEmptyAndInvertedSpans() {
        XCTAssertNil(HighlightSpan(start: 5, end: 5))
        XCTAssertNil(HighlightSpan(start: 5, end: 4))
        XCTAssertNil(HighlightSpan(start: -1, end: 4))
        XCTAssertNotNil(HighlightSpan(start: 0, end: 1))
    }

    func testBridgesToAndFromNSRange() {
        let span = HighlightSpan(NSRange(location: 4, length: 6))
        XCTAssertEqual(span?.start, 4)
        XCTAssertEqual(span?.end, 10)
        XCTAssertEqual(span?.length, 6)
        XCTAssertEqual(span?.nsRange, NSRange(location: 4, length: 6))

        XCTAssertNil(HighlightSpan(NSRange(location: NSNotFound, length: 0)))
        XCTAssertNil(HighlightSpan(NSRange(location: 4, length: 0)))
    }

    // MARK: Geometry

    func testOverlapExcludesAdjacency() {
        let a = HighlightSpan(start: 0, end: 10)!
        let touching = HighlightSpan(start: 10, end: 20)!
        let sharing = HighlightSpan(start: 9, end: 20)!

        // The server merges on overlap only (03 §2.2) — adjacency is not overlap.
        XCTAssertFalse(a.overlaps(touching))
        XCTAssertFalse(touching.overlaps(a))
        XCTAssertTrue(a.overlaps(sharing))
        XCTAssertTrue(sharing.overlaps(a))
    }

    func testUnionCoversBothIncludingAnyGap() {
        let a = HighlightSpan(start: 0, end: 5)!
        let b = HighlightSpan(start: 12, end: 20)!
        XCTAssertEqual(a.union(b), HighlightSpan(start: 0, end: 20))
        XCTAssertEqual(b.union(a), HighlightSpan(start: 0, end: 20))
    }

    func testContainsIsHalfOpen() {
        let span = HighlightSpan(start: 3, end: 6)!
        XCTAssertFalse(span.contains(offset: 2))
        XCTAssertTrue(span.contains(offset: 3))
        XCTAssertTrue(span.contains(offset: 5))
        XCTAssertFalse(span.contains(offset: 6))
    }

    func testClampingToShorterText() {
        let span = HighlightSpan(start: 4, end: 20)!
        XCTAssertEqual(span.clamped(toLength: 10), HighlightSpan(start: 4, end: 10))
        XCTAssertEqual(span.clamped(toLength: 100), span)
        // Nothing survives when the text ends before the span starts.
        XCTAssertNil(span.clamped(toLength: 4))
        XCTAssertNil(span.clamped(toLength: 0))
    }

    func testSortsByStartThenEnd() {
        let spans = [
            HighlightSpan(start: 10, end: 12)!,
            HighlightSpan(start: 0, end: 20)!,
            HighlightSpan(start: 0, end: 5)!
        ]
        XCTAssertEqual(spans.sorted(), [
            HighlightSpan(start: 0, end: 5)!,
            HighlightSpan(start: 0, end: 20)!,
            HighlightSpan(start: 10, end: 12)!
        ])
    }
}

final class VerseCoordinateTests: XCTestCase {

    func testRoundTripsThroughElementId() {
        let coordinate = VerseCoordinate(bookNumber: 45, chapter: 1, verse: 5)
        XCTAssertEqual(coordinate.elementId, "45-1-5")
        XCTAssertEqual(VerseCoordinate(elementId: "45-1-5"), coordinate)
    }

    func testParsesMultiDigitComponents() {
        XCTAssertEqual(VerseCoordinate(elementId: "119-150-176"),
                       VerseCoordinate(bookNumber: 119, chapter: 150, verse: 176))
    }

    func testRejectsMalformedElementIds() {
        XCTAssertNil(VerseCoordinate(elementId: "45-1"))
        XCTAssertNil(VerseCoordinate(elementId: "45-1-5-2"))
        XCTAssertNil(VerseCoordinate(elementId: "john-1-5"))
        XCTAssertNil(VerseCoordinate(elementId: ""))
    }
}

final class VerseCoordinateSpaceTests: XCTestCase {

    /// Three verses, laid out end to end: v1 = 0..<10, v2 = 10..<25, v3 = 25..<40.
    private let space = VerseCoordinateSpace(
        bookNumber: 43,
        chapter: 1,
        verseRanges: [
            (verse: 1, range: NSRange(location: 0, length: 10)),
            (verse: 2, range: NSRange(location: 10, length: 15)),
            (verse: 3, range: NSRange(location: 25, length: 15))
        ]
    )

    // MARK: Absolute → verse-relative

    func testConvertsASpanInsideOneVerse() {
        let range = space.range(for: HighlightSpan(start: 12, end: 18)!)
        XCTAssertEqual(range?.startElementId, "43-1-2")
        XCTAssertEqual(range?.startOffset, 2)
        XCTAssertEqual(range?.endElementId, "43-1-2")
        XCTAssertEqual(range?.endOffset, 8)
    }

    func testConvertsASpanCrossingVerses() {
        let range = space.range(for: HighlightSpan(start: 5, end: 30)!)
        XCTAssertEqual(range?.startElementId, "43-1-1")
        XCTAssertEqual(range?.startOffset, 5)
        XCTAssertEqual(range?.endElementId, "43-1-3")
        XCTAssertEqual(range?.endOffset, 5)
    }

    func testEndOffsetIsMeasuredAgainstTheLastCOVEREDCharacter() {
        // A span ending exactly at a verse boundary belongs to the verse it
        // covers, not the one it stops in front of.
        let range = space.range(for: HighlightSpan(start: 0, end: 10)!)
        XCTAssertEqual(range?.endElementId, "43-1-1")
        XCTAssertEqual(range?.endOffset, 10)
    }

    func testReturnsNilOutsideEveryVerse() {
        XCTAssertNil(space.range(for: HighlightSpan(start: 40, end: 45)!))
        XCTAssertNil(space.range(for: HighlightSpan(start: 38, end: 60)!))
    }

    // MARK: Verse-relative → absolute

    func testConvertsBackToAbsoluteOffsets() {
        let range = HighlightRange(startElementId: "43-1-2", startOffset: 2,
                                   endElementId: "43-1-3", endOffset: 5)
        XCTAssertEqual(space.span(for: range), HighlightSpan(start: 12, end: 30))
    }

    func testRoundTripsASpan() {
        let original = HighlightSpan(start: 7, end: 22)!
        let range = space.range(for: original)
        XCTAssertNotNil(range)
        XCTAssertEqual(range.flatMap { space.span(for: $0) }, original)
    }

    func testLegacyZeroEndOffsetMeansThroughTheEndOfThatVerse() {
        // Every HighlightRange this app wrote before the highlighting feature
        // stores 0/0 for a whole-verse-range selection (EditDay.swift:786).
        let legacy = HighlightRange(startElementId: "43-1-1", startOffset: 0,
                                    endElementId: "43-1-2", endOffset: 0)
        XCTAssertEqual(space.span(for: legacy), HighlightSpan(start: 0, end: 25))
    }

    func testRejectsAnotherBookOrChapter() {
        let otherBook = HighlightRange(startElementId: "44-1-1", startOffset: 0,
                                       endElementId: "44-1-2", endOffset: 3)
        let otherChapter = HighlightRange(startElementId: "43-2-1", startOffset: 0,
                                          endElementId: "43-2-2", endOffset: 3)
        XCTAssertNil(space.span(for: otherBook))
        XCTAssertNil(space.span(for: otherChapter))
    }

    func testRejectsAVerseThisSpaceDoesNotHold() {
        let range = HighlightRange(startElementId: "43-1-1", startOffset: 0,
                                   endElementId: "43-1-9", endOffset: 3)
        XCTAssertNil(space.span(for: range))
    }
}
