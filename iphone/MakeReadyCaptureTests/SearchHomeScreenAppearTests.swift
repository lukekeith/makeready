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
}
