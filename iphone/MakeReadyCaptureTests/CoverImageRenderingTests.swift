import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import MakeReady

/// group-cover-image D3/D12: the render is 1200×529 and shows the framed region; the pick is
/// upright and ≤ 2400px.
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
        let cg = image.cgImage!
        var buf = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &buf, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (buf[0], buf[1], buf[2])
    }

    func testRenderIs1200x529AtScale1() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertEqual(out.cgImage?.width, 1200)
        XCTAssertEqual(out.cgImage?.height, 529)
    }

    func testIdentityShowsBothHalves() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertGreaterThan(pixel(out, 100, 264).r, 200)    // left = red
        XCTAssertGreaterThan(pixel(out, 1100, 264).b, 200)   // right = blue
    }

    /// Image centre moved right by a quarter frame → the frame's left edge now shows… more red.
    func testOffsetMovesTheContent() {
        let zoomed = CoverFraming(scale: 2, rotation: 0, offsetX: 0.25, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: zoomed)
        XCTAssertGreaterThan(pixel(out, 700, 264).r, 200)    // the red/blue seam moved right of centre
    }

    func testRotationLeavesNoEmptyCorners() {
        let f = CoverFraming(scale: 1, rotation: 45, offsetX: 0, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: f)
        for (x, y) in [(1, 1), (1198, 1), (1, 527), (1198, 527)] {
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
