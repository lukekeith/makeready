import XCTest
@testable import MakeReady

final class ActivityBackgroundPalettesTests: XCTestCase {
    /// D4 (round 2): a dark base ≥ 4.5:1 under white, and vivid blob colours ≥ 3:1 with saturation ≥ 0.55.
    func testEveryPaletteHasADarkBaseAndVividBlobs() {
        XCTAssertEqual(ActivityBackgroundPalettes.all.count, 12)
        for palette in ActivityBackgroundPalettes.all {
            XCTAssertTrue((4...5).contains(palette.count), "\(palette)")
            XCTAssertEqual(Set(palette).count, palette.count, "\(palette)")
            let base = ActivityBackgroundPalettes.darkest(palette)
            XCTAssertGreaterThanOrEqual(ActivityBackgroundPalettes.contrastWithWhite(base), 4.5, base)
            for hex in palette where hex != base {
                XCTAssertGreaterThanOrEqual(ActivityBackgroundPalettes.contrastWithWhite(hex), 3.0, hex)
                XCTAssertGreaterThanOrEqual(ActivityBackgroundPalettes.saturation(hex), 0.55, hex)
            }
        }
    }

    func testSaturationReadsHSB() {
        XCTAssertEqual(ActivityBackgroundPalettes.saturation("#FF0000"), 1, accuracy: 0.001)
        XCTAssertEqual(ActivityBackgroundPalettes.saturation("#808080"), 0, accuracy: 0.001)
    }

    func testContrastMatchesWCAG() {
        XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#767676"), 4.54, accuracy: 0.01)
        XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#000000"), 21, accuracy: 0.01)
    }

    func testDarkestPicksTheLowestLuminance() {
        XCTAssertEqual(ActivityBackgroundPalettes.darkest(["#3B3F9E", "#1B1F4A", "#7A2E8E"]), "#1B1F4A")
    }
}
