import XCTest
@testable import MakeReady

/// ui2-groups-browse D2/D22/D27: the three groups screens' wiring edits (routed to /ui2-resolve, F3).
@MainActor
final class GroupsScreensEditTests: XCTestCase {
    /// D22: the groups-home list's one line when no row shows.
    func testGroupsHomeEmptyLineCopy() {
        XCTAssertEqual(GroupsHomeScreen.emptyCopy("noGroups"), "No groups yet")
        XCTAssertEqual(GroupsHomeScreen.emptyCopy("noMatch"), "No groups match your search")
        XCTAssertNil(GroupsHomeScreen.emptyCopy(""))                 // loading: chips + an empty list
        XCTAssertEqual(GroupsHomeScreen.State.populated.listEmpty, "")
    }

    /// D27: the container pins C-040 itself; the capture render keeps the screen's own header.
    func testGroupsDetailHeaderDefaultsOnAndCanBePinnedOut() {
        XCTAssertTrue(GroupsDetailScreen(state: .populated).showsHeader)
        XCTAssertFalse(GroupsDetailScreen(state: .populated, showsHeader: false).showsHeader)
    }

    /// D27/D12: the day rail opens at its last card (today trails).
    func testGroupsDetailOpensTheRailAtItsLastCard() {
        XCTAssertEqual(GroupsDetailScreen.openingRailIndex(30), 29)
        XCTAssertEqual(GroupsDetailScreen.openingRailIndex(1), 0)
        XCTAssertNil(GroupsDetailScreen.openingRailIndex(0))
    }

    /// D27: the name field is live, focuses on appear, and locks while the create is in flight.
    func testCreateGroupFieldIsLiveAndLocksWhileCreating() {
        let idle = CreateGroupScreen.fieldEditing(creating: false)
        XCTAssertTrue(idle.focusOnAppear)
        XCTAssertTrue(idle.isEnabled)
        let creating = CreateGroupScreen.fieldEditing(creating: true)
        XCTAssertTrue(creating.focusOnAppear)
        XCTAssertFalse(creating.isEnabled)
    }
}
