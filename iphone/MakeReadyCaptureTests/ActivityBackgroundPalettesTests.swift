import XCTest
@testable import MakeReady

final class ActivityBackgroundPalettesTests: XCTestCase {
    func testEveryPaletteHasFourToFiveColoursReadableUnderWhite() {
        XCTAssertEqual(ActivityBackgroundPalettes.all.count, 12)
        for palette in ActivityBackgroundPalettes.all {
            XCTAssertTrue((4...5).contains(palette.count), "\(palette)")
            XCTAssertEqual(Set(palette).count, palette.count, "\(palette)")
            for hex in palette {
                XCTAssertGreaterThanOrEqual(ActivityBackgroundPalettes.contrastWithWhite(hex), 4.5, hex)
            }
        }
    }

    func testContrastMatchesWCAG() {
        XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#767676"), 4.54, accuracy: 0.01)
        XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#000000"), 21, accuracy: 0.01)
    }

    func testDarkestPicksTheLowestLuminance() {
        XCTAssertEqual(ActivityBackgroundPalettes.darkest(["#3B3F9E", "#1B1F4A", "#7A2E8E"]), "#1B1F4A")
    }
}
