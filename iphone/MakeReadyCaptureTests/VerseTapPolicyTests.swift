//
//  VerseTapPolicyTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.6 of docs/features/highlighting/ — the Read editor's selection model,
//  and the composition rules of the shared renderer.
//
//  The tap model was previously only reachable through a UIKit gesture handler,
//  so "tap a verse, tap another, tap inside to commit" could only be checked by
//  hand. It is a pure function now.
//

import XCTest
import UIKit
@testable import MakeReady

final class VerseTapPolicyTests: XCTestCase {

    /// v1 = 0..<20, v2 = 20..<37, v3 = 37..<50.
    private let verseRanges: [VerseRange] = [
        (verse: 1, range: NSRange(location: 0, length: 20)),
        (verse: 2, range: NSRange(location: 20, length: 17)),
        (verse: 3, range: NSRange(location: 37, length: 13))
    ]

    private func tap(_ verse: Int, live: NSRange?) -> VerseTapOutcome {
        VerseTapPolicy.tap(verse: verse, liveSelection: live, verseRanges: verseRanges)
    }

    func testFirstTapSelectsThatVerse() {
        XCTAssertEqual(tap(2, live: nil), .select(NSRange(location: 20, length: 17)))
    }

    func testTappingAnotherVerseExtendsToCoverBoth() {
        let live = NSRange(location: 0, length: 20)   // v1
        XCTAssertEqual(tap(3, live: live), .select(NSRange(location: 0, length: 50)))
    }

    func testExtendingBackwardsWorksTheSameAsForwards() {
        let live = NSRange(location: 37, length: 13)  // v3
        XCTAssertEqual(tap(1, live: live), .select(NSRange(location: 0, length: 50)))
    }

    func testTappingInsideTheSelectionCommitsIt() {
        let live = NSRange(location: 0, length: 37)   // v1–v2
        XCTAssertEqual(tap(1, live: live), .commit(NSRange(location: 0, length: 37)))
        XCTAssertEqual(tap(2, live: live), .commit(NSRange(location: 0, length: 37)))
    }

    func testCommittingReturnsTheWholeSelectionNotJustTheTappedVerse() {
        let live = NSRange(location: 0, length: 50)   // all three
        XCTAssertEqual(tap(2, live: live), .commit(NSRange(location: 0, length: 50)))
    }

    func testAnUnknownVerseIsIgnored() {
        XCTAssertEqual(tap(9, live: nil), .ignore)
    }

    func testVerseLookupByOffsetIsHalfOpen() {
        XCTAssertEqual(VerseTapPolicy.verse(containing: 0, verseRanges: verseRanges), 1)
        XCTAssertEqual(VerseTapPolicy.verse(containing: 19, verseRanges: verseRanges), 1)
        XCTAssertEqual(VerseTapPolicy.verse(containing: 20, verseRanges: verseRanges), 2)
        XCTAssertNil(VerseTapPolicy.verse(containing: 50, verseRanges: verseRanges))
    }
}

final class HighlightRendererCompositionTests: XCTestCase {

    private let text = "1. In the beginning God created the heavens"

    private func render(
        highlights: [HighlightRenderer.Painted] = [],
        editing: NSRange? = nil,
        live: NSRange? = nil
    ) -> NSAttributedString {
        HighlightRenderer.attributedText(
            plainText: text,
            verseNumberRanges: [],
            fontSize: 16,
            foregroundColor: .white,
            serif: true,
            justified: true,
            highlights: highlights,
            editing: editing,
            live: live
        )
    }

    private func background(_ attributed: NSAttributedString, at index: Int) -> UIColor? {
        attributed.attribute(.backgroundColor, at: index, effectiveRange: nil) as? UIColor
    }

    func testPaintsSavedHighlights() {
        let attributed = render(highlights: [.init(span: HighlightSpan(start: 3, end: 9)!)])
        XCTAssertEqual(background(attributed, at: 4), HighlightAppearance.saved.backgroundColor)
        XCTAssertNil(background(attributed, at: 1))
    }

    func testTheEditedSpanIsPaintedAsEditingNotSaved() {
        let span = HighlightSpan(start: 3, end: 9)!
        let attributed = render(highlights: [.init(span: span)], editing: span.nsRange)
        XCTAssertEqual(background(attributed, at: 4), HighlightAppearance.editing.backgroundColor)
    }

    func testOnlyTheEditedSpanSwitchesAppearance() {
        let edited = HighlightSpan(start: 3, end: 9)!
        let other = HighlightSpan(start: 20, end: 25)!
        let attributed = render(highlights: [.init(span: edited), .init(span: other)],
                                editing: edited.nsRange)

        XCTAssertEqual(background(attributed, at: 4), HighlightAppearance.editing.backgroundColor)
        XCTAssertEqual(background(attributed, at: 21), HighlightAppearance.saved.backgroundColor)
    }

    /// The paint-order rule: dragging across an existing highlight must look
    /// like something is happening (monday#12668695071).
    func testTheLiveSelectionWinsOverASavedSpanItOverlaps() {
        let attributed = render(highlights: [.init(span: HighlightSpan(start: 3, end: 20)!)],
                                live: NSRange(location: 5, length: 6))

        XCTAssertEqual(background(attributed, at: 6), HighlightAppearance.live.backgroundColor)
        XCTAssertEqual(background(attributed, at: 15), HighlightAppearance.saved.backgroundColor,
                       "the part of the saved span outside the drag is untouched")
    }

    func testABoldHighlightGetsNoWash() {
        let attributed = render(highlights: [.init(span: HighlightSpan(start: 3, end: 9)!, style: "bold")])
        XCTAssertNil(background(attributed, at: 4))
    }

    func testAnEmptyRenderIsJustTheText() {
        let attributed = render()
        XCTAssertEqual(attributed.string, text)
        XCTAssertNil(background(attributed, at: 0))
    }

    func testOutOfBoundsHighlightsDoNotCrashTheRender() {
        let attributed = render(highlights: [.init(span: HighlightSpan(start: 40, end: 900)!)],
                                live: NSRange(location: 500, length: 20))
        XCTAssertEqual(attributed.string, text)
    }
}
