import XCTest
@testable import MakeReady

final class ActivityBackgroundGeneratorTests: XCTestCase {
    func testASeedGivesAFixedGradient() {
        let palette = ActivityBackgroundPalettes.all[0]
        var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
        XCTAssertEqual(ActivityBackgroundGenerator.make(palette: palette, rng: &a),
                       ActivityBackgroundGenerator.make(palette: palette, rng: &b))
    }

    func testBlobsStayInsideTheRulingsRanges() {
        var rng = SeededRandom(seed: 7)
        for palette in ActivityBackgroundPalettes.all {
            let g = ActivityBackgroundGenerator.make(palette: palette, rng: &rng)
            XCTAssertEqual(g.style, "blobs")
            XCTAssertFalse(g.hidden)
            XCTAssertEqual(g.blobs.count, 4)
            XCTAssertEqual(g.base, ActivityBackgroundPalettes.darkest(palette))
            for blob in g.blobs {
                XCTAssertTrue((0...1).contains(blob.x))
                XCTAssertTrue((0...1.6).contains(blob.y))
                XCTAssertTrue((0.6...1.0).contains(blob.r))
                XCTAssertTrue(palette.contains(blob.color))
                XCTAssertNotEqual(blob.color, g.base)
            }
        }
    }

    func testRandomPaletteIsACuratedOne() {
        var rng = SeededRandom(seed: 3)
        XCTAssertTrue(ActivityBackgroundPalettes.all.contains(ActivityBackgroundGenerator.randomPalette(rng: &rng)))
    }
}
