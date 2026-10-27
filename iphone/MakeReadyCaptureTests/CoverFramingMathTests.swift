import XCTest
@testable import MakeReady

/// group-cover-image D5/D20/D21/D25: no empty corners at any rotation or quarter turn; scale is
/// relative to the floor; the frame is 16:9.
final class CoverFramingMathTests: XCTestCase {
    private let frame = CGSize(width: 320, height: 180)
    private let wide = CGSize(width: 2400, height: 1600)
    private let tall = CGSize(width: 1200, height: 2400)
    private let fourByThree = CGSize(width: 1600, height: 1200)
    private let threeByFour = CGSize(width: 1200, height: 1600)

    /// Every frame corner, mapped into the turned image's own axes, lies inside the scaled image.
    /// Odd quarter turns swap the image's width and height (D21); a flip moves no edge.
    private func covers(_ f: CoverFraming, image: CGSize, accuracy: CGFloat = 0.01) -> Bool {
        let turned = f.quarterTurns % 2 == 0 ? image : CGSize(width: image.height, height: image.width)
        let s = CoverFramingMath.absoluteScale(f, image: image, frame: frame)
        let c = CoverFramingMath.imageCenter(f, frame: frame)
        let t = f.rotation * .pi / 180
        let corners = [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map {
            CGPoint(x: $0.0 * frame.width / 2, y: $0.1 * frame.height / 2)
        }
        return corners.allSatisfy { p in
            let dx = p.x - c.x, dy = p.y - c.y
            let u = dx * cos(t) + dy * sin(t), v = -dx * sin(t) + dy * cos(t)
            return abs(u) <= s * turned.width / 2 + accuracy && abs(v) <= s * turned.height / 2 + accuracy
        }
    }

    private func framing(scale: Double = 1, rotation: Double = 0, offsetX: Double = 0, offsetY: Double = 0,
                         flipped: Bool = false, quarterTurns: Int = 0) -> CoverFraming {
        CoverFraming(scale: scale, rotation: rotation, offsetX: offsetX, offsetY: offsetY,
                     flipped: flipped, quarterTurns: quarterTurns)
    }

    func testFrameIs16By9() {
        XCTAssertEqual(CoverFramingMath.frameAspect, 16.0 / 9.0, accuracy: 1e-12)
    }

    func testFloorAtZeroIsTheCoverFit() {
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0), 320.0 / 2400.0, accuracy: 1e-6)
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: tall, frame: frame, rotationDegrees: 0), 320.0 / 1200.0, accuracy: 1e-6)
    }

    /// D20/D21: the floor at 16:9 uses the image's bounding size after quarter turns — odd turns swap.
    func testFloorFor4By3And3By4AtQuarterTurns0And1() {
        let landscapeUpright = 320.0 / 1600.0     // 1600×1200: width binds (0.2 vs 0.15)
        let portraitUpright = 320.0 / 1200.0      // 1200×1600: width binds (0.267 vs 0.1125)
        func floor(_ image: CGSize, _ q: Int) -> CGFloat {
            CoverFramingMath.absoluteScale(framing(quarterTurns: q), image: image, frame: frame)
        }
        XCTAssertEqual(floor(fourByThree, 0), landscapeUpright, accuracy: 1e-6)
        XCTAssertEqual(floor(fourByThree, 1), portraitUpright, accuracy: 1e-6)   // turned: 1200×1600
        XCTAssertEqual(floor(threeByFour, 0), portraitUpright, accuracy: 1e-6)
        XCTAssertEqual(floor(threeByFour, 1), landscapeUpright, accuracy: 1e-6)  // turned: 1600×1200
        XCTAssertEqual(floor(fourByThree, 2), landscapeUpright, accuracy: 1e-6)
        XCTAssertEqual(floor(fourByThree, 3), portraitUpright, accuracy: 1e-6)
    }

    func testFloorCoversAtFineRotationsAndEveryQuarterTurn() {
        for image in [wide, tall, fourByThree, threeByFour] {
            for q in 0...3 {
                for deg in [0.0, 45, -45, -30, 12] {
                    let f = framing(rotation: deg, quarterTurns: q)
                    XCTAssertTrue(covers(f, image: image), "\(image) q\(q) at \(deg)°")
                    // …and is the smallest such scale: 1% below it leaves a corner empty.
                    XCTAssertFalse(covers(framing(scale: 0.99, rotation: deg, quarterTurns: q), image: image, accuracy: 0),
                                   "\(image) q\(q) at \(deg)° not minimal")
                }
            }
        }
    }

    func testFloorGrowsWithRotation() {
        let f0 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0)
        let f45 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 45)
        XCTAssertGreaterThan(f45, f0)
    }

    func testClampPullsAnOffsetBackUntilCovered() {
        for q in 0...3 {
            for deg in [0.0, 20, 45, -45] {
                let c = CoverFramingMath.clamped(framing(scale: 1.5, rotation: deg, offsetX: 1, offsetY: -1, quarterTurns: q),
                                                 image: wide, frame: frame)
                XCTAssertTrue(covers(c, image: wide), "q\(q) \(deg)°")
            }
        }
    }

    func testClampAtTheFloorCentres() {
        let c = CoverFramingMath.clamped(framing(offsetX: 0.5, offsetY: 0.5), image: wide, frame: frame)
        // 2400×1600 at the floor (320/2400): width fits exactly, so no horizontal slack.
        XCTAssertEqual(c.offsetX, 0, accuracy: 1e-6)
        // …and it is 213.3pt tall in a 180pt frame: (213.3−180)/2 of vertical slack.
        let slack = (1600 * (320.0 / 2400.0) - 180) / 2
        XCTAssertEqual(c.offsetY, slack / 180, accuracy: 1e-6)
    }

    func testClampKeepsALegalFraming() {
        let f = framing(scale: 2, rotation: 10, offsetX: 0.1, offsetY: 0.05, flipped: true, quarterTurns: 3)
        XCTAssertEqual(CoverFramingMath.clamped(f, image: wide, frame: frame), f)
    }

    func testScaleIsClampedTo1Through8() {
        XCTAssertEqual(CoverFramingMath.clamped(framing(scale: 0.4), image: wide, frame: frame).scale, 1)
        XCTAssertEqual(CoverFramingMath.clamped(framing(scale: 12), image: wide, frame: frame).scale, 8)
    }

    /// D21: the fine rotation stays within −45…45 (the server's range); quarter turns into 0…3.
    func testRotationIsClampedToFortyFiveAndQuarterTurnsWrap() {
        XCTAssertEqual(CoverFramingMath.clamped(framing(rotation: 80), image: wide, frame: frame).rotation, 45)
        XCTAssertEqual(CoverFramingMath.clamped(framing(rotation: -170), image: wide, frame: frame).rotation, -45)
        XCTAssertEqual(CoverFramingMath.clamped(framing(quarterTurns: 5), image: wide, frame: frame).quarterTurns, 1)
        XCTAssertEqual(CoverFramingMath.clamped(framing(quarterTurns: -1), image: wide, frame: frame).quarterTurns, 3)
    }

    /// D11: the server rejects offsets outside −1…1, so the clamp bounds them as well as covering.
    func testClampBoundsOffsetsToOneAndStillCoversAtScale8() {
        for q in [0, 1] {
            for deg in [0.0, 20, 45, -45] {
                for (ox, oy) in [(50.0, -50.0), (-9, 9), (3.5, 0), (0, -3.5)] {
                    let c = CoverFramingMath.clamped(framing(scale: 8, rotation: deg, offsetX: ox, offsetY: oy, quarterTurns: q),
                                                     image: wide, frame: frame)
                    XCTAssertLessThanOrEqual(abs(c.offsetX), 1 + 1e-9, "q\(q) \(deg)° x")
                    XCTAssertLessThanOrEqual(abs(c.offsetY), 1 + 1e-9, "q\(q) \(deg)° y")
                    XCTAssertTrue(covers(c, image: wide), "q\(q) \(deg)° covers")
                }
            }
        }
        let far = CoverFramingMath.clamped(framing(scale: 8, offsetX: 9), image: wide, frame: frame)
        XCTAssertEqual(far.offsetX, 1, accuracy: 1e-9)
    }

    /// Task 7's deferred minor: a non-finite framing has nothing to clamp to — it reads as identity.
    func testNonFiniteFramingComesBackAsIdentity() {
        XCTAssertEqual(CoverFramingMath.clamped(framing(scale: 2, offsetX: .nan), image: wide, frame: frame), .identity)
        XCTAssertEqual(CoverFramingMath.clamped(framing(scale: .infinity), image: wide, frame: frame), .identity)
        XCTAssertEqual(CoverFramingMath.clamped(framing(rotation: -.infinity, flipped: true), image: wide, frame: frame), .identity)
    }

    func testSnap() {
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 2.9), 0)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: -3), 0)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 3.1), 3.1, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 358), 0)          // −2° after normalising
        XCTAssertEqual(CoverFramingMath.normalized(degrees: 190), -170, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.normalized(degrees: -190), 170, accuracy: 1e-9)
    }

    /// D11: scale is relative to the floor, so the same framing reproduces the same crop at a
    /// different frame size (the 1200×675 render vs the on-screen frame).
    func testRelativeScaleRoundTripsAcrossFrameSizes() {
        let f = framing(scale: 2.5, rotation: 30, offsetX: 0.05, offsetY: -0.1, flipped: true, quarterTurns: 1)
        let big = CGSize(width: 1200, height: 1200 / CoverFramingMath.frameAspect)
        let sSmall = CoverFramingMath.absoluteScale(f, image: wide, frame: frame)
        let sBig = CoverFramingMath.absoluteScale(f, image: wide, frame: big)
        XCTAssertEqual(sBig / sSmall, big.width / frame.width, accuracy: 1e-3)
        let a = CoverFramingMath.clamped(f, image: wide, frame: big), b = CoverFramingMath.clamped(f, image: wide, frame: frame)
        XCTAssertEqual(a.offsetX, b.offsetX, accuracy: 1e-9)
        XCTAssertEqual(a.offsetY, b.offsetY, accuracy: 1e-9)
    }

    /// D21/D22: Flip mirrors the whole view about the frame's vertical centre line — the x offset,
    /// the fine rotation and the quarter turns change sign, the mirror toggles — and keeps coverage.
    func testFlipMirrorsTheXOffsetAndKeepsCoverage() {
        let f = CoverFramingMath.clamped(framing(scale: 2, rotation: 12, offsetX: 0.3, offsetY: -0.1, quarterTurns: 1),
                                         image: wide, frame: frame)
        XCTAssertTrue(covers(f, image: wide))
        let m = CoverFramingMath.flippedHorizontally(f)
        XCTAssertEqual(m.offsetX, -f.offsetX, accuracy: 1e-12)
        XCTAssertEqual(m.offsetY, f.offsetY, accuracy: 1e-12)
        XCTAssertEqual(m.rotation, -f.rotation, accuracy: 1e-12)
        XCTAssertEqual(m.quarterTurns, 3)
        XCTAssertTrue(m.flipped)
        XCTAssertTrue(covers(m, image: wide))
        XCTAssertEqual(CoverFramingMath.clamped(m, image: wide, frame: frame), m)
        XCTAssertEqual(CoverFramingMath.flippedHorizontally(m), f)              // twice = unchanged
    }

    /// D25: displacement beyond the limit moves at 0.3.
    func testRubberBand() {
        XCTAssertEqual(CoverFramingMath.rubberBand(100), 30, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.rubberBand(-10), -3, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.rubberBand(0), 0)
    }

    /// D25: release springs back to a framing that covers the frame; D5: with the fine rotation snapped.
    func testSettleOfAnOverPannedFramingCoversTheFrame() {
        for q in 0...3 {
            let over = framing(scale: 0.6, rotation: 2, offsetX: 1.8, offsetY: -1.4, quarterTurns: q)
            XCTAssertFalse(covers(over, image: wide))
            let settled = CoverFramingMath.settle(over, image: wide, frame: frame)
            XCTAssertTrue(covers(settled, image: wide), "q\(q)")
            XCTAssertEqual(settled.scale, 1)
            XCTAssertEqual(settled.rotation, 0)                                   // within ±3° → 0
            XCTAssertEqual(settled.quarterTurns, q)
        }
        let tilted = CoverFramingMath.settle(framing(rotation: 20), image: wide, frame: frame)
        XCTAssertEqual(tilted.rotation, 20, accuracy: 1e-9)
    }
}
