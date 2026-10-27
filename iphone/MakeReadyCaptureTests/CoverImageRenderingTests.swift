import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import MakeReady

/// group-cover-image D3/D12/D20/D21: the render is 1200×675 (16:9) and shows the framed region —
/// flip, then quarter turns, then the fine rotation, then scale/offset; the pick is upright and ≤ 2400px.
final class CoverImageRenderingTests: XCTestCase {
    /// Left half red, right half blue.
    private func halves(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
        }
    }

    private func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        image.pixel(x, y)
    }

    /// Four quadrants: top-left red, top-right blue, bottom-left green, bottom-right yellow.
    private func quadrants(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let w = size.width / 2, h = size.height / 2
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: w, y: 0, width: w, height: h))
            UIColor.green.setFill(); ctx.fill(CGRect(x: 0, y: h, width: w, height: h))
            UIColor.yellow.setFill(); ctx.fill(CGRect(x: w, y: h, width: w, height: h))
        }
    }

    private func same(_ a: (r: UInt8, g: UInt8, b: UInt8), _ b: (r: UInt8, g: UInt8, b: UInt8)) -> Bool {
        abs(Int(a.r) - Int(b.r)) < 8 && abs(Int(a.g) - Int(b.g)) < 8 && abs(Int(a.b) - Int(b.b)) < 8
    }

    func testRenderIs1200x675AtScale1() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertEqual(out.cgImage?.width, 1200)
        XCTAssertEqual(out.cgImage?.height, 675)
        let turned = CoverImageRendering.render(halves(CGSize(width: 1200, height: 1600)),
                                                framing: CoverFraming(scale: 1, rotation: 0, offsetX: 0, offsetY: 0, quarterTurns: 1))
        XCTAssertEqual(turned.cgImage?.width, 1200)
        XCTAssertEqual(turned.cgImage?.height, 675)
    }

    /// D21: flipped:true renders the mirror of flipped:false — probed at two points.
    func testFlippedRenderIsTheMirrorOfTheUnflippedRender() {
        let image = quadrants(CGSize(width: 2400, height: 1600))
        let plain = CoverFraming(scale: 1.5, rotation: 0, offsetX: 0, offsetY: 0.05)
        var flipped = plain; flipped.flipped = true
        let a = CoverImageRendering.render(image, framing: plain)
        let b = CoverImageRendering.render(image, framing: flipped)
        for (x, y) in [(150, 100), (900, 600)] {
            XCTAssertTrue(same(b.pixel(x, y), a.pixel(1199 - x, y)), "(\(x),\(y)) \(b.pixel(x, y)) vs \(a.pixel(1199 - x, y))")
        }
        XCTAssertFalse(same(a.pixel(150, 100), b.pixel(150, 100)))      // the probe is not symmetric
    }

    /// D22: Flip mirrors the whole framed view, tilt and quarter turn included.
    func testFlippingAFramingMirrorsItsRender() {
        let image = quadrants(CGSize(width: 2400, height: 1600))
        let f = CoverFramingMath.clamped(CoverFraming(scale: 2, rotation: 14, offsetX: 0.2, offsetY: -0.1, quarterTurns: 1),
                                         image: image.size, frame: CoverImageRendering.renderSize)
        let a = CoverImageRendering.render(image, framing: f)
        let b = CoverImageRendering.render(image, framing: CoverFramingMath.flippedHorizontally(f))
        for (x, y) in [(200, 150), (1000, 500), (600, 337)] {
            XCTAssertTrue(same(b.pixel(x, y), a.pixel(1199 - x, y)), "(\(x),\(y))")
        }
    }

    /// D21: a quarter turn is counter-clockwise — the image's left (red) half ends up at the bottom.
    func testQuarterTurnIsCounterClockwise() {
        let out = CoverImageRendering.render(halves(CGSize(width: 1600, height: 1200)),
                                             framing: CoverFraming(scale: 1, rotation: 0, offsetX: 0, offsetY: 0, quarterTurns: 1))
        XCTAssertGreaterThan(out.pixel(600, 50).b, 200)      // top = blue (was the right)
        XCTAssertGreaterThan(out.pixel(600, 625).r, 200)     // bottom = red (was the left)
    }

    func testIdentityShowsBothHalves() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertGreaterThan(pixel(out, 100, 337).r, 200)    // left = red
        XCTAssertGreaterThan(pixel(out, 1100, 337).b, 200)   // right = blue
    }

    /// Image centre moved right by a quarter frame → the frame's left edge now shows… more red.
    func testOffsetMovesTheContent() {
        let zoomed = CoverFraming(scale: 2, rotation: 0, offsetX: 0.25, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: zoomed)
        XCTAssertGreaterThan(pixel(out, 700, 337).r, 200)    // the red/blue seam moved right of centre
    }

    func testRotationLeavesNoEmptyCorners() {
        let f = CoverFraming(scale: 1, rotation: 45, offsetX: 0, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: f)
        for (x, y) in [(1, 1), (1198, 1), (1, 673), (1198, 673)] {
            let p = pixel(out, x, y)
            XCTAssertTrue(p.r > 200 || p.b > 200, "corner \(x),\(y) is \(p)")
        }
    }

    func testPickIsDownsampledTo2400() throws {
        let data = try XCTUnwrap(halves(CGSize(width: 4000, height: 1000)).jpegData(compressionQuality: 0.9))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data))
        XCTAssertEqual(max(out.size.width * out.scale, out.size.height * out.scale), 2400, accuracy: 1)
        XCTAssertEqual(out.imageOrientation, .up)
    }

    func testSmallPickIsNotEnlarged() throws {
        let data = try XCTUnwrap(halves(CGSize(width: 800, height: 600)).jpegData(compressionQuality: 0.9))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data))
        XCTAssertEqual(out.size.width * out.scale, 800, accuracy: 1)
    }

    /// An EXIF-rotated JPEG (orientation 6 = 90° CW): 800×600 stored pixels come back upright as 600×800.
    func testExifOrientationIsApplied() throws {
        let src = halves(CGSize(width: 800, height: 600)).cgImage!
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, src, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data as Data))
        XCTAssertEqual(out.size.width * out.scale, 600, accuracy: 1)
        XCTAssertEqual(out.size.height * out.scale, 800, accuracy: 1)
        XCTAssertEqual(out.imageOrientation, .up)
    }

    func testJunkDataIsNil() {
        XCTAssertNil(CoverImageRendering.uprightDownsampled(Data("not an image".utf8)))
    }
}

private extension UIImage {
    func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        let cg = cgImage!
        var buf = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &buf, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (buf[0], buf[1], buf[2])
    }
}
