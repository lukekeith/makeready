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
        let screen = ScrollView {
            SearchHomeScreen(state: state, onResultAppear: { appeared.insert($0) })
        }
        .frame(width: 440, height: 956)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        let host = UIHostingController(rootView: screen)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        for _ in 0..<20 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            host.view.layoutIfNeeded()
        }

        let highest = appeared.max() ?? -1
        XCTAssertGreaterThanOrEqual(highest, 0, "no row appeared: the host did not lay out")
        XCTAssertLessThan(highest, 25, "rows that appeared: \(appeared.sorted())")
    }

    /// Agent walk round 1: content shorter than the screen leaves page background below it, never
    /// the host's white (rendered through a real window, as HomeDashboardContainerTests does).
    func testThePageBackgroundFillsBelowShortContent() throws {
        let size = CGSize(width: 100, height: 300)
        let host = UIHostingController(rootView: SearchPageScroll { Color.clear.frame(height: 10) })
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
        XCTAssertLessThan(pixel[0], 32, "the page below the content is not the page background: \(pixel)")
        XCTAssertEqual(pixel[3], 255, "the page below the content is not filled: \(pixel)")
    }
}
