import XCTest
@testable import MakeReady

/// group-cover-image D5/D11: no empty corners at any rotation; scale is relative to the floor.
final class CoverFramingMathTests: XCTestCase {
    private let frame = CGSize(width: 408, height: 180)
    private let wide = CGSize(width: 2400, height: 1600)
    private let tall = CGSize(width: 1200, height: 2400)

    /// Every frame corner, mapped into the image's own axes, lies inside the scaled image.
    private func covers(_ f: CoverFraming, image: CGSize, accuracy: CGFloat = 0.01) -> Bool {
        let s = CoverFramingMath.absoluteScale(f, image: image, frame: frame)
        let c = CoverFramingMath.imageCenter(f, frame: frame)
        let t = f.rotation * .pi / 180
        let corners = [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map {
            CGPoint(x: $0.0 * frame.width / 2, y: $0.1 * frame.height / 2)
        }
        return corners.allSatisfy { p in
            let dx = p.x - c.x, dy = p.y - c.y
            let u = dx * cos(t) + dy * sin(t), v = -dx * sin(t) + dy * cos(t)
            return abs(u) <= s * image.width / 2 + accuracy && abs(v) <= s * image.height / 2 + accuracy
        }
    }

    func testFloorAtZeroIsTheCoverFit() {
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0), 408.0 / 2400.0, accuracy: 1e-6)
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: tall, frame: frame, rotationDegrees: 0), 408.0 / 1200.0, accuracy: 1e-6)
    }

    func testFloorCoversAt0_45_90ForWideAndTall() {
        for image in [wide, tall] {
            for deg in [0.0, 45, 90, -30, 180] {
                let f = CoverFraming(scale: 1, rotation: deg, offsetX: 0, offsetY: 0)
                XCTAssertTrue(covers(f, image: image), "\(image) at \(deg)°")
                // …and is the smallest such scale: 1% below it leaves a corner empty.
                let floor = CoverFramingMath.zoomFloor(image: image, frame: frame, rotationDegrees: deg)
                let below = CoverFraming(scale: 0.99, rotation: deg, offsetX: 0, offsetY: 0)
                XCTAssertGreaterThan(floor, 0)
                XCTAssertFalse(covers(below, image: image, accuracy: 0), "\(image) at \(deg)° not minimal")
            }
        }
    }

    func testFloorGrowsWithRotation() {
        let f0 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0)
        let f45 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 45)
        XCTAssertGreaterThan(f45, f0)
    }

    func testClampPullsAnOffsetBackUntilCovered() {
        for deg in [0.0, 20, 45, 90] {
            let wild = CoverFraming(scale: 1.5, rotation: deg, offsetX: 1, offsetY: -1)
            let c = CoverFramingMath.clamped(wild, image: wide, frame: frame)
            XCTAssertTrue(covers(c, image: wide), "\(deg)°")
        }
    }

    func testClampAtTheFloorCentres() {
        let c = CoverFramingMath.clamped(CoverFraming(scale: 1, rotation: 0, offsetX: 0.5, offsetY: 0.5), image: wide, frame: frame)
        // wide at floor: width fits exactly, so no horizontal slack.
        XCTAssertEqual(c.offsetX, 0, accuracy: 1e-6)
        // 2400×1600 at 0.17 is 272pt tall in a 180pt frame: (272−180)/2 = 46pt of vertical slack.
        let slack = (1600 * (408.0 / 2400.0) - 180) / 2
        XCTAssertEqual(c.offsetY, slack / 180, accuracy: 1e-6)
    }

    func testClampKeepsALegalOffset() {
        let f = CoverFraming(scale: 2, rotation: 0, offsetX: 0.1, offsetY: 0.05)
        XCTAssertEqual(CoverFramingMath.clamped(f, image: wide, frame: frame), f)
    }

    func testScaleIsClampedTo1Through8() {
        XCTAssertEqual(CoverFramingMath.clamped(CoverFraming(scale: 0.4, rotation: 0, offsetX: 0, offsetY: 0), image: wide, frame: frame).scale, 1)
        XCTAssertEqual(CoverFramingMath.clamped(CoverFraming(scale: 12, rotation: 0, offsetX: 0, offsetY: 0), image: wide, frame: frame).scale, 8)
    }

    /// D11: the server rejects offsets outside −1…1, so the clamp bounds them as well as covering.
    func testClampBoundsOffsetsToOneAndStillCoversAtScale8() {
        for deg in [0.0, 20, 45, 90] {
            for (ox, oy) in [(50.0, -50.0), (-9, 9), (3.5, 0), (0, -3.5)] {
                let wild = CoverFraming(scale: 8, rotation: deg, offsetX: ox, offsetY: oy)
                let c = CoverFramingMath.clamped(wild, image: wide, frame: frame)
                XCTAssertLessThanOrEqual(abs(c.offsetX), 1 + 1e-9, "\(deg)° x")
                XCTAssertLessThanOrEqual(abs(c.offsetY), 1 + 1e-9, "\(deg)° y")
                XCTAssertTrue(covers(c, image: wide), "\(deg)° covers")
            }
        }
        // Past ±1 the coverage-only clamp alone would have allowed this far: 2400×1600 at 8× is ±3.5.
        let far = CoverFramingMath.clamped(CoverFraming(scale: 8, rotation: 0, offsetX: 9, offsetY: 0), image: wide, frame: frame)
        XCTAssertEqual(far.offsetX, 1, accuracy: 1e-9)
    }

    func testNonFiniteFramingComesBackUnchanged() {
        let nan = CoverFraming(scale: 2, rotation: 0, offsetX: .nan, offsetY: 0)
        let out = CoverFramingMath.clamped(nan, image: wide, frame: frame)
        XCTAssertTrue(out.offsetX.isNaN)
        let inf = CoverFraming(scale: .infinity, rotation: 0, offsetX: 0, offsetY: 0)
        XCTAssertEqual(CoverFramingMath.clamped(inf, image: wide, frame: frame), inf)
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
    /// different frame size (the 1200×529 render vs the on-screen frame).
    func testRelativeScaleRoundTripsAcrossFrameSizes() {
        let f = CoverFraming(scale: 2.5, rotation: 30, offsetX: 0.05, offsetY: -0.1)
        let big = CGSize(width: 1200, height: 1200 / CoverFramingMath.frameAspect)
        let sSmall = CoverFramingMath.absoluteScale(f, image: wide, frame: frame)
        let sBig = CoverFramingMath.absoluteScale(f, image: wide, frame: big)
        XCTAssertEqual(sBig / sSmall, big.width / frame.width, accuracy: 1e-3)
        XCTAssertEqual(CoverFramingMath.clamped(f, image: wide, frame: big), CoverFramingMath.clamped(f, image: wide, frame: frame))
    }
}
