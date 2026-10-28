import XCTest
import UIKit
@testable import MakeReady

/// cover-image-sizes + ui2-image-cache: lists load the 400px `-md` copy, falling back to the cover
/// decoded at 400px; every load goes through the shared fetch and lands in Ui2ImageCache once.
@MainActor
final class CoverImageLoaderTests: XCTestCase {
    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [(String, CGFloat?)] = []
        func add(_ url: URL, _ size: CGFloat?) { lock.withLock { list.append((url.absoluteString, size)) } }
        var all: [(String, CGFloat?)] { lock.withLock { list } }
    }

    private func image() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 9), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 9))
        }
    }

    private func unique(_ name: String) -> String { "https://cdn.test/\(UUID().uuidString)/\(name)" }

    func testListURLIsTheMdSibling() {
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/programs/program-1-123.jpeg"), "https://r2/programs/program-1-123-md.jpeg")
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/library/a.webp"), "https://r2/library/a-md.webp")
        XCTAssertEqual(CoverImageLoader.listURL(""), "")
        XCTAssertEqual(CoverImageLoader.listURL("https://img.example.com/photo?id=3"), "https://img.example.com/photo?id=3")
        XCTAssertEqual(CoverImageLoader.listURL("https://r2/a-md.jpeg"), "https://r2/a-md.jpeg")
    }

    func testSeedsTheMdFileOnceThenServesItFromTheCache() async {
        let cover = unique("c.jpeg")
        let md = CoverImageLoader.listURL(cover)
        let calls = Calls()
        let img = image()
        let fetch: UI2ImageLoader.Fetch = { url, size in calls.add(url, size); return img }
        let first = await CoverImageLoader.seedList([cover], fetch: fetch)
        let second = await CoverImageLoader.seedList([cover], fetch: fetch)
        XCTAssertTrue(first)
        XCTAssertFalse(second)                                   // already in the cache: no fetch
        XCTAssertEqual(calls.all.map(\.0), [md])
        XCTAssertNil(calls.all.first?.1)
        XCTAssertEqual(CoverImageLoader.cachedListURLs([cover]), [md])
    }

    func testFallsBackToTheCoverDecodedAtListWidth() async {
        let cover = unique("legacy.jpeg")
        let md = CoverImageLoader.listURL(cover)
        let calls = Calls()
        let img = image()
        let seeded = await CoverImageLoader.seedList([cover], fetch: { url, size in
            calls.add(url, size)
            if url.absoluteString == md { throw URLError(.badServerResponse) }
            return img
        })
        XCTAssertTrue(seeded)
        XCTAssertEqual(calls.all.map(\.0), [md, cover])
        XCTAssertEqual(calls.all.last?.1, CoverImageLoader.listWidth)
        XCTAssertNotNil(Ui2ImageCache.shared.image(for: URL(string: md)!))
    }

    func testNothingLoadsKeepsTheEmptyLook() async {
        let cover = unique("gone.jpeg")
        let seeded = await CoverImageLoader.seedList([cover], fetch: { _, _ in throw URLError(.badServerResponse) }, state: AppState())
        XCTAssertFalse(seeded)
        XCTAssertEqual(CoverImageLoader.cachedListURLs([cover]), [""])
    }

    func testThePageLoaderSkipsCachedAndNonHTTPImages() async {
        let url = unique("page.jpeg")
        let calls = Calls()
        let img = image()
        let fetch: UI2ImageLoader.Fetch = { url, size in calls.add(url, size); return img }
        let first = await UI2ImageLoader.seed([url, "", "file:///x.jpeg"], context: "Test", fetch: fetch)
        let second = await UI2ImageLoader.seed([url], context: "Test", fetch: fetch)
        XCTAssertTrue(first)
        XCTAssertFalse(second)
        XCTAssertEqual(calls.all.map(\.0), [url])
        XCTAssertNotNil(Ui2ImageCache.shared.image(for: URL(string: url)!))
    }
}
