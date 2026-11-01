import XCTest
@testable import MakeReady

/// media-page D16: one rule for the TopNav morph, whether the shell's page scroll or a section's own scroll reports it.
final class SectionScrollMorphTests: XCTestCase {
    func testPullPastTheTopWithAFingerDownOpensTheRow() {
        XCTAssertEqual(SectionScrollMorph.target(expansion: 0, interacting: true, offset: -12), 1)
        XCTAssertNil(SectionScrollMorph.target(expansion: 0, interacting: true, offset: -11))
        XCTAssertNil(SectionScrollMorph.target(expansion: 0, interacting: false, offset: -40))
    }

    func testScrollingUpWhileOpenClosesTheRow() {
        XCTAssertEqual(SectionScrollMorph.target(expansion: 1, interacting: false, offset: 8), 0)
        XCTAssertNil(SectionScrollMorph.target(expansion: 1, interacting: true, offset: 7))
    }

    func testMidMorphDoesNothing() {
        XCTAssertNil(SectionScrollMorph.target(expansion: 0.5, interacting: true, offset: -50))
    }

    func testOnlyMediaOwnsItsScroll() {
        XCTAssertEqual(UI2Section.allCases.filter(\.ownsScroll), [.media])
    }

    func testAScrollOwningSectionShrinksFromTheTopByTheRowsGrowth() {
        XCTAssertEqual(SectionScrollMorph.ownedScrollTopPadding(footprint: 60, hidesNav: false, growth: 0), 60)
        XCTAssertEqual(SectionScrollMorph.ownedScrollTopPadding(footprint: 60, hidesNav: false, growth: 30), 90)
        XCTAssertEqual(SectionScrollMorph.ownedScrollTopPadding(footprint: 60, hidesNav: true, growth: 30), 0)
    }
}
