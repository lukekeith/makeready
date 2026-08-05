//
//  HighlightRendererTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.3 of docs/features/highlighting/ — the colour values are the
//  contract (03 §5), so they are asserted as values, not eyeballed in a
//  snapshot. If one of these fails, the app and the web player have diverged.
//

import XCTest
import UIKit
@testable import MakeReady

final class HighlightAppearanceTests: XCTestCase {

    private func components(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func assertColor(
        _ appearance: HighlightAppearance,
        hex: (r: Int, g: Int, b: Int),
        alpha: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let actual = components(appearance.backgroundColor)
        XCTAssertEqual(actual.r, CGFloat(hex.r) / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.g, CGFloat(hex.g) / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.b, CGFloat(hex.b) / 255.0, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actual.a, alpha, accuracy: 0.001, file: file, line: line)
    }

    // MARK: The four cross-app values (03 §5)

    func testSavedIsLimeAt35Percent() {
        assertColor(.saved, hex: (0xF4, 0xFF, 0x76), alpha: 0.35)
    }

    func testLiveSelectionIsLimeAt55Percent() {
        assertColor(.live, hex: (0xF4, 0xFF, 0x76), alpha: 0.55)
    }

    func testActiveIsWhiteAt25Percent() {
        assertColor(.active, hex: (0xFF, 0xFF, 0xFF), alpha: 0.25)
    }

    func testUsedIsBrandPurpleAt20Percent() {
        // The one remaining purple — and it does not mean "highlight".
        assertColor(.used, hex: (0x6C, 0x47, 0xFF), alpha: 0.2)
    }

    func testOnlyTheEditorChromeRecolorsTheText() {
        XCTAssertNil(HighlightAppearance.saved.foregroundColor)
        XCTAssertNil(HighlightAppearance.live.foregroundColor)
        XCTAssertNil(HighlightAppearance.active.foregroundColor)
        XCTAssertNil(HighlightAppearance.used.foregroundColor)
        XCTAssertEqual(HighlightAppearance.editing.foregroundColor, .black)
        XCTAssertEqual(HighlightAppearance.preview.foregroundColor, .black)
    }
}

final class HighlightRendererTests: XCTestCase {

    private func text(_ string: String = "In the beginning God created") -> NSMutableAttributedString {
        NSMutableAttributedString(string: string)
    }

    private func background(_ attributed: NSAttributedString, at index: Int) -> UIColor? {
        attributed.attribute(.backgroundColor, at: index, effectiveRange: nil) as? UIColor
    }

    // MARK: Painting

    func testPaintsOnlyTheGivenRange() {
        let attributed = text()
        XCTAssertTrue(HighlightRenderer.paint(.saved, over: NSRange(location: 3, length: 3), in: attributed))

        XCTAssertNil(background(attributed, at: 2))
        XCTAssertEqual(background(attributed, at: 3), HighlightAppearance.saved.backgroundColor)
        XCTAssertEqual(background(attributed, at: 5), HighlightAppearance.saved.backgroundColor)
        XCTAssertNil(background(attributed, at: 6))
    }

    func testEditorChromeAlsoSetsTheForeground() {
        let attributed = text()
        HighlightRenderer.paint(.editing, over: NSRange(location: 0, length: 2), in: attributed)
        let foreground = attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(foreground, .black)
    }

    // MARK: Bounds — the reason this lives in one place

    func testClampsARangeRunningPastTheEndOfTheText() {
        let attributed = text("short")
        XCTAssertTrue(HighlightRenderer.paint(.saved, over: NSRange(location: 3, length: 99), in: attributed))
        XCTAssertEqual(background(attributed, at: 4), HighlightAppearance.saved.backgroundColor)
    }

    func testPaintsNothingWhenNothingSurvivesTheClamp() {
        let attributed = text("short")
        XCTAssertFalse(HighlightRenderer.paint(.saved, over: NSRange(location: 10, length: 4), in: attributed))
        XCTAssertFalse(HighlightRenderer.paint(.saved, over: NSRange(location: 2, length: 0), in: attributed))
        XCTAssertFalse(HighlightRenderer.paint(.saved, over: NSRange(location: NSNotFound, length: 3), in: attributed))
        XCTAssertNil(background(attributed, at: 2))
    }

    func testClampHelperMatchesThatBehaviour() {
        XCTAssertEqual(HighlightRenderer.clamp(NSRange(location: 3, length: 99), to: 5),
                       NSRange(location: 3, length: 2))
        XCTAssertNil(HighlightRenderer.clamp(NSRange(location: 5, length: 2), to: 5))
        XCTAssertNil(HighlightRenderer.clamp(NSRange(location: NSNotFound, length: 2), to: 5))
    }

    // MARK: The `bold` rule (03 §5)

    func testBoldChangesWeightAndPaintsNoWash() {
        let attributed = text()
        let bold = UIFont.boldSystemFont(ofSize: 17)
        let painted = HighlightRenderer.paintHighlight(
            style: .bold, over: NSRange(location: 0, length: 2), in: attributed, boldFont: bold)

        XCTAssertTrue(painted)
        XCTAssertNil(background(attributed, at: 0), "bold must not wash the background")
        XCTAssertEqual(attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, bold)
    }

    func testBoldWithoutAFontPaintsNothingRatherThanFallingBackToAWash() {
        let attributed = text()
        XCTAssertFalse(HighlightRenderer.paintHighlight(
            style: .bold, over: NSRange(location: 0, length: 2), in: attributed))
        XCTAssertNil(background(attributed, at: 0))
    }

    func testHighlightStylePaintsTheWash() {
        let attributed = text()
        HighlightRenderer.paintHighlight(style: .highlight, over: NSRange(location: 0, length: 2), in: attributed)
        XCTAssertEqual(background(attributed, at: 0), HighlightAppearance.saved.backgroundColor)
    }

    func testUnknownWireStyleFallsBackToHighlight() {
        let attributed = text()
        HighlightRenderer.paintHighlight(style: "underline", over: NSRange(location: 0, length: 2), in: attributed)
        XCTAssertEqual(background(attributed, at: 0), HighlightAppearance.saved.backgroundColor)
    }

    func testStoredHighlightCanBePaintedWithANonDefaultAppearance() {
        let attributed = text()
        HighlightRenderer.paintHighlight(
            style: "highlight", appearance: .editing, over: NSRange(location: 0, length: 2), in: attributed)
        XCTAssertEqual(background(attributed, at: 0), HighlightAppearance.editing.backgroundColor)
    }
}
