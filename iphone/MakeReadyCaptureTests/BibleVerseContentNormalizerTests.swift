//
//  BibleVerseContentNormalizerTests.swift
//  MakeReadyCaptureTests
//

import XCTest
@testable import MakeReady

final class BibleVerseContentNormalizerTests: XCTestCase {
    func testNormalizesMarkdownVerseWhitespace() {
        let input = """
        12.  For now we see in a mirror
             dimly, but then face to face.

        13.  So now faith,
             hope, and love abide, these three;
             but the greatest of these is love.
        """

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "12. For now we see in a mirror dimly, but then face to face.\n13. So now faith, hope, and love abide, these three; but the greatest of these is love."
        )
    }

    func testNormalizesHTMLVerseContent() {
        let input = """
        <p><sup>1</sup>&nbsp;In the beginning<br>God created the heavens and the earth.</p>
        <p><sup>2</sup> The earth was without form<br/>and void.</p>
        """

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "1. In the beginning God created the heavens and the earth.\n2. The earth was without form and void."
        )
    }

    func testNormalizesEscapedNewlinesAndEntities() {
        let input = "1. Blessed&nbsp;is the man\\nwho walks not in counsel.\\n2. But his delight is in the law &amp; testimony."

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "1. Blessed is the man who walks not in counsel.\n2. But his delight is in the law & testimony."
        )
    }

    func testDoesNotRequirePassageToStartAtVerseOne() {
        let input = "3 The voice of one crying in the wilderness\n4 John appeared, baptizing in the wilderness"

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "3. The voice of one crying in the wilderness\n4. John appeared, baptizing in the wilderness"
        )
    }

    func testNormalizesLegacySuperscriptVerseMarkers() {
        let input = "¹ In the beginning God created. ² The earth was without form."

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "1. In the beginning God created.\n2. The earth was without form."
        )
    }

    func testFallsBackToCollapsedPlainTextWhenNoVerseMarkersExist() {
        let input = "<p>  No verse marker\n\n but lots    of spacing. </p>"

        XCTAssertEqual(
            BibleVerseContentNormalizer.normalizedMarkdown(from: input),
            "No verse marker but lots of spacing."
        )
    }
}
