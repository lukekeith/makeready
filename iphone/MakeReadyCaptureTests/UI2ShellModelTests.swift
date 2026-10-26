import XCTest
import UIKit
@testable import MakeReady

final class UI2ShellModelTests: XCTestCase {
    func testEntryPoint() {
        let m = UI2ShellModel()
        XCTAssertEqual(m.tab, .home); XCTAssertEqual(m.section, .home); XCTAssertTrue(m.showsTopNav)
    }
    func testSectionsMatchTopNavContract() {
        XCTAssertEqual(UI2Section.allCases.map(\.rawValue), TopNav.designedTabs)
    }
    func testTopNavOnlyOnHome() {
        var m = UI2ShellModel()
        for tab in [TabBar.Tab.calendar, .search, .profile] { m.apply(.tab(tab)); XCTAssertFalse(m.showsTopNav) }
    }
    func testSectionSurvivesTabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.groups)); m.scrollOffset = 120
        m.apply(.tab(.search)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .groups); XCTAssertEqual(m.scrollOffset, 120)
    }
    func testRetapHomeReturnsToHomeSection() {
        var m = UI2ShellModel()
        m.apply(.section(.members)); m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }
    /// SPEC D14 (revised 2026-10-25): selecting a tab leaves the row as it is — an expanded
    /// row stays expanded (analysis §5.4).
    func testSelectingSectionKeepsExpansion() {
        var m = UI2ShellModel(); m.expansion = 1
        m.apply(.section(.invites))
        XCTAssertEqual(m.section, .invites); XCTAssertEqual(m.expansion, 1)
        m.expansion = 0
        m.apply(.section(.home))
        XCTAssertEqual(m.expansion, 0)
    }

    // MARK: - ui2-members-browse D1/D2/D20: per-tab push paths

    private let tony = UI2Destination.memberDetail(id: "m1", name: "Tony Stark")

    func testEveryTabStartsAtItsRoot() {
        let m = UI2ShellModel()
        XCTAssertEqual(UI2ShellModel.tabs, [.home, .calendar, .search, .profile])
        for tab in UI2ShellModel.tabs { XCTAssertEqual(m.path(for: tab), []) }
    }

    func testPushAndPopActOnTheNamedTabOnly() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.path(for: .profile), [])
        m.pop(on: .profile)                                    // nothing to pop: no-op
        XCTAssertEqual(m.path(for: .home), [tony])
        m.pop(on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        m.pop(on: .home)                                       // popping an empty path is safe
        XCTAssertEqual(m.path(for: .home), [])
    }

    /// D2: leaving a tab and coming back restores its pushed page.
    func testAPushedPageSurvivesATabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.apply(.tab(.search))
        XCTAssertEqual(m.tab, .search)
        XCTAssertEqual(m.path(for: .search), [])
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.section, .members)
    }

    /// D20: re-tapping the selected tab with a page pushed pops to the root and keeps the section.
    func testRetapWithAPushedPagePopsToTheRootOnly() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.push(.memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [])
        XCTAssertEqual(m.section, .members)
        XCTAssertEqual(m.tab, .home)
    }

    /// D20: with an empty path the re-tap keeps today's behaviour (`.home` section).
    func testRetapWithAnEmptyPathResetsTheSectionAsBefore() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }

    func testSetPathIsTheStackBinding() {
        var m = UI2ShellModel()
        m.setPath([tony], for: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.setPath([], for: .home)                              // the system edge-swipe pop writes this
        XCTAssertEqual(m.path(for: .home), [])
    }

    func testTopNavStaysARootPageFact() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertTrue(m.showsTopNav)                           // D1: no hide logic — the pushed page covers it
    }

    /// F2: the re-armed edge swipe may begin only when there is a page to pop.
    @MainActor
    func testPopGestureBeginsOnlyAboveTheRoot() {
        let nav = UINavigationController(rootViewController: UIViewController())
        let delegate = UI2PopGestureDelegate()
        delegate.navigationController = nav
        let gesture = UIScreenEdgePanGestureRecognizer()
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(gesture))
        nav.pushViewController(UIViewController(), animated: false)
        XCTAssertTrue(delegate.gestureRecognizerShouldBegin(gesture))
        XCTAssertFalse(UI2PopGestureDelegate().gestureRecognizerShouldBegin(gesture))   // no stack known
    }
}
