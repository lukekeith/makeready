import XCTest
import ImageIO
import UIKit
import UniformTypeIdentifiers
@testable import MakeReady

/// media-page D3: the capture date a cover pick sends — DateTimeOriginal (+ OffsetTimeOriginal when present,
/// else the device's zone), as ISO 8601 with an offset; nil when the file has none.
final class CaptureDateTests: XCTestCase {
    private func imageData(_ type: UTType, exif: [CFString: Any]?) throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else {
            throw XCTSkip("\(type.identifier) encoding is unavailable on this simulator")
        }
        var props: [CFString: Any] = [:]
        if let exif { props[kCGImagePropertyExifDictionary] = exif }
        CGImageDestinationAddImage(dest, try XCTUnwrap(image.cgImage), props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    private let chicago = TimeZone(identifier: "America/Chicago")!

    func testDatedJPEGUsesTheDeviceZone() throws {
        let data = try imageData(.jpeg, exif: [kCGImagePropertyExifDateTimeOriginal: "2025:06:14 09:30:00"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2025-06-14T09:30:00-05:00")
    }

    func testDatedHEIC() throws {
        let data = try imageData(.heic, exif: [kCGImagePropertyExifDateTimeOriginal: "2024:01:05 08:00:00"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2024-01-05T08:00:00-06:00")
    }

    func testOffsetTimeOriginalWinsOverTheDevice() throws {
        let data = try imageData(.jpeg, exif: [kCGImagePropertyExifDateTimeOriginal: "2025:06:14 09:30:00",
                                               kCGImagePropertyExifOffsetTimeOriginal: "+05:30"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2025-06-14T09:30:00+05:30")
    }

    func testNoDateIsNil() throws {
        XCTAssertNil(CaptureDate.read(from: try imageData(.jpeg, exif: nil), deviceTimeZone: chicago))
        XCTAssertNil(CaptureDate.read(from: Data("not an image".utf8), deviceTimeZone: chicago))
    }

    func testMalformedValuesAreNil() {
        XCTAssertNil(CaptureDate.format(exifDateTime: "2025:13:14 09:30:00", in: chicago))
        XCTAssertNil(CaptureDate.format(exifDateTime: "0000:00:00 00:00:00", in: chicago))
        XCTAssertNil(CaptureDate.timeZone(offset: "05:30"))
        XCTAssertEqual(CaptureDate.timeZone(offset: "-07:00")?.secondsFromGMT(), -25_200)
    }
}
