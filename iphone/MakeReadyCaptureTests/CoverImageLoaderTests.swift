import XCTest
import UIKit
@testable import MakeReady

/// cover-image-sizes: lists load the 400px `-md` copy, falling back to the cover cut to 400px.
@MainActor
final class CoverImageLoaderTests: XCTestCase {
    private func jpeg(width: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: width, height: width * 9 / 16)
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.8)!
    }

    private func unique(_ name: String) -> String {
        "https://cdn.test/\(UUID().uuidString)/\(name)"
    }

    func testListURLIsTheMdSibling() {
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/programs/program-1-123.jpeg"), "https://r2/programs/program-1-123-md.jpeg")
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/library/a.webp"), "https://r2/library/a-md.webp")
        XCTAssertEqual(CoverImageLoader.listURL(""), "")
        XCTAssertEqual(CoverImageLoader.listURL("https://img.example.com/photo?id=3"), "https://img.example.com/photo?id=3")
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/a-md.jpeg"), "https://r2/a-md.jpeg")
    }

    func testSeedsTheMdFileWhenItExists() async {
        let cover = unique("c.jpeg")
        let md = CoverImageLoader.listURL(cover)
        let body = jpeg(width: 400)
        var asked: [String] = []
        let seeded = await CoverImageLoader.seedList([cover], fetch: { url in
            await MainActor.run { asked.append(url.absoluteString) }
            return url.absoluteString == md ? (body, 200) : (Data(), 404)
        })
        XCTAssertTrue(seeded)
        XCTAssertEqual(asked, [md])
        XCTAssertEqual(CoverImageLoader.cachedListURLs([cover]), [md])
    }

    func testFallsBackToTheCoverCutToListWidth() async throws {
        let cover = unique("legacy.jpeg")
        let md = CoverImageLoader.listURL(cover)
        let big = jpeg(width: 1600)
        let seeded = await CoverImageLoader.seedList([cover], fetch: { url in
            url.absoluteString == md ? (Data("<Error>NoSuchKey</Error>".utf8), 404) : (big, 200)
        })
        XCTAssertTrue(seeded)
        let image = try XCTUnwrap(Ui2ImageCache.shared.image(for: URL(string: md)!))
        XCTAssertEqual(CoverImageLoader.pixelSize(image).width, 400, accuracy: 0.5)
    }

    func testNothingLoadsKeepsTheEmptyLook() async {
        let cover = unique("gone.jpeg")
        let seeded = await CoverImageLoader.seedList([cover], fetch: { _ in (Data(), 404) }, state: AppState())
        XCTAssertFalse(seeded)
        XCTAssertEqual(CoverImageLoader.cachedListURLs([cover]), [""])
    }
}
