import XCTest
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
    func testSelectingSectionCollapses() {
        var m = UI2ShellModel(); m.expansion = 1
        m.apply(.section(.invites))
        XCTAssertEqual(m.expansion, 0)
    }
}
