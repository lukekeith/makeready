import SwiftUI
import UIKit
import XCTest
@testable import MakeReady

/// master-search F11: laying out the results list must not fire `onResultAppear` for every row,
/// or the last-five-rows rule would page through every page of a search on its own.

@MainActor
final class SearchHomeScreenAppearTests: XCTestCase {
    func testOnlyTheRowsInAndNearTheViewportAppearAtLayout() {
        var state = SearchHomeScreen.State.queryingResults
        let count = 40
        state.resultKinds = Array(repeating: "program", count: count)
        state.resultTitles = (0..<count).map { "Result \($0)" }
        state.resultDescriptions = Array(repeating: "Created Feb 1, 2021", count: count)

        var appeared = Set<Int>()
        // Through the real page scroll, in a real scene: its anchor must not lay out every row.
        let host = makeHost(SearchPageScroll {
            SearchHomeScreen(state: state, onResultAppear: { appeared.insert($0) })
        })
        settle(host)

        let highest = appeared.max() ?? -1
        XCTAssertGreaterThanOrEqual(highest, 0, "no row appeared: the host did not lay out")
        XCTAssertLessThan(highest, 25, "rows that appeared: \(appeared.sorted())")
    }

    /// Agent walk round 3 (F18c): rows are keyed by index, so a new first page over rows already drawn
    /// fires no `onAppear` unless the rows are made anew, and paging stalls at the page's end.
    func testANewFirstPageMakesItsRowsAppearAgain() {
        var appeared = Set<Int>()
        let rows = results(count: 20, generation: 0)
        let host = makeHost(ScrollView { SearchHomeScreen(state: rows, onResultAppear: { appeared.insert($0) }) })
        settle(host)
        XCTAssertTrue(appeared.contains(0))

        appeared.removeAll()
        var next = rows
        next.resultsGeneration = 1
        host.rootView = AnyView(ScrollView { SearchHomeScreen(state: next, onResultAppear: { appeared.insert($0) }) })
        settle(host)
        XCTAssertTrue(appeared.contains(0), "no row appeared again: \(appeared.sorted())")
    }

    /// Agent walk round 3 (F18b, X4, X4b): content that shrinks under a deep scroll position left the
    /// page blank, the pinned header gone with its section. A cleared query (X4) moves the same token.
    func testAReplacedListGoesBackToItsFirstRow() throws {
        var noResults = results(count: 0, generation: 1)
        noResults.queryAnswered = true
        for ending in [results(count: 20, generation: 1), noResults] {
            let host = makeHost(page(results(count: 60, generation: 0)))
            settle(host)
            let scroll = try XCTUnwrap(scrollView(in: host.view))
            scroll.contentOffset.y = 2_000
            settle(host)
            XCTAssertEqual(scroll.contentOffset.y, 2_000, accuracy: 1, "the list did not scroll: the test proves nothing")

            host.rootView = page(ending)
            settle(host)
            XCTAssertLessThanOrEqual(scroll.contentOffset.y, 1)
        }
    }

    /// Paging extends the list and must leave the scroll position alone.
    func testAnExtendedListKeepsItsScrollPosition() throws {
        let host = makeHost(page(results(count: 60, generation: 0)))
        settle(host)
        let scroll = try XCTUnwrap(scrollView(in: host.view))
        scroll.contentOffset.y = 2_000
        settle(host)
        host.rootView = page(results(count: 80, generation: 0))
        settle(host)
        XCTAssertEqual(scroll.contentOffset.y, 2_000, accuracy: 1)
    }

    /// Agent walk round 4 (P1): the row at a scroll position comes from the lazy stack's height estimate.
    /// A row and its zero-height hairline as two children made that estimate wrong, and it shifted and
    /// shrank as rows were measured while paging. Every row is 74 pt, so the height is known exactly.
    func testPagingKeepsAnExactContentHeight() throws {
        var count = 20
        let host = makeHost(page(results(count: count, generation: 0)))
        settle(host)
        let scroll = try XCTUnwrap(scrollView(in: host.view))
        let chrome = scroll.contentSize.height - 74 * CGFloat(count)

        func assertExact(_ moment: String) {
            XCTAssertEqual(scroll.contentSize.height, chrome + 74 * CGFloat(count), accuracy: 1,
                           "\(moment), \(count) rows, offset \(scroll.contentOffset.y)")
        }
        while count < 100 {
            for _ in 0..<3 {
                scroll.contentOffset.y = min(scroll.contentOffset.y + 518, scroll.contentSize.height - scroll.bounds.height)
                settle(host)
                assertExact("after a drag")
            }
            count += 20
            host.rootView = page(results(count: count, generation: 0))
            settle(host)
            assertExact("after a page landed")
        }
    }

    /// Agent walk round 3 (X1): what a page leaves below itself is page background, never the window's white.
    func testThePageBottomIsPageBackground() throws {
        let band = try pixel(of: Color.clear.ui2PageBottom(50))
        XCTAssertLessThan(band[0], 32, "the space below the page is not the page background: \(band)")
        XCTAssertEqual(band[3], 255, "the space below the page is not filled: \(band)")
    }

    /// Agent walk round 1: content shorter than the screen leaves page background below it, never
    /// the host's white (rendered through a real window, as HomeDashboardContainerTests does).
    func testThePageBackgroundFillsBelowShortContent() throws {
        let below = try pixel(of: SearchPageScroll { Color.clear.frame(height: 10) })
        XCTAssertLessThan(below[0], 32, "the page below the content is not the page background: \(below)")
        XCTAssertEqual(below[3], 255, "the page below the content is not filled: \(below)")
    }

    // MARK: - Helpers

    private func results(count: Int, generation: Int) -> SearchHomeScreen.State {
        var state = SearchHomeScreen.State.queryingResults
        state.resultKinds = Array(repeating: "program", count: count)
        state.resultTitles = (0..<count).map { "Result \($0)" }
        state.resultDescriptions = Array(repeating: "Created Feb 1, 2021", count: count)
        state.resultsGeneration = generation
        return state
    }

    private func page(_ state: SearchHomeScreen.State) -> AnyView {
        AnyView(SearchPageScroll(resetToken: state.resultsGeneration) { SearchHomeScreen(state: state) })
    }

    private func makeHost<V: View>(_ view: V) -> UIHostingController<AnyView> {
        let host = UIHostingController(rootView: AnyView(view))
        host.safeAreaRegions = []
        // In the test host's scene: outside one, a scroll view's contentSize and scrollTo never land
        // (measured: a direct proxy call moved nothing, and 5 rows kept the 60-row contentSize).
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow()
        window.frame = CGRect(x: 0, y: 0, width: 440, height: 956)
        window.rootViewController = host
        window.makeKeyAndVisible()
        addTeardownBlock { window.isHidden = true }
        host.view.frame = window.bounds
        return host
    }

    private func settle(_ host: UIViewController) {
        for _ in 0..<10 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            host.view.layoutIfNeeded()
        }
    }

    private func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.scrollView(in: $0) }.first
    }

    /// The pixel 10 pt above the bottom of `view`, rendered through a real window.
    private func pixel<V: View>(of view: V) throws -> [UInt8] {
        let size = CGSize(width: 100, height: 300)
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            _ = host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let cropped = try XCTUnwrap(image.cgImage?.cropping(to: CGRect(x: 50, y: 290, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel
    }
}
