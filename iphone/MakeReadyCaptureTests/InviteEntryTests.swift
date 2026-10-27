import XCTest
@testable import MakeReady

/// invite-member D2/D12: 0 groups → nothing, 1 → the invite page, 2+ → the picker.
final class InviteEntryTests: XCTestCase {
    private func group(_ id: String) -> UserGroup {
        UserGroup(id: id, code: "C", name: id, isPrivate: false, allowInvites: true, memberCount: 0,
                  creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testNoGroupsPushesNothing() {
        XCTAssertNil(InviteEntry.destination(groups: [], returnDepth: 0))
    }

    func testOneGroupGoesStraightToTheInvitePage() {
        XCTAssertEqual(InviteEntry.destination(groups: [group("g1")], returnDepth: 2),
                       .inviteMember(groupId: "g1", returnDepth: 2))
    }

    func testTwoOrMoreGroupsOpenThePicker() {
        XCTAssertEqual(InviteEntry.destination(groups: [group("g1"), group("g2")], returnDepth: 0),
                       .inviteSelectGroup(returnDepth: 0))
    }

    func testTheCopy() {
        XCTAssertEqual(InviteEntry.noGroupsMessage, "Create a group before inviting members")
        XCTAssertEqual(InviteEntry.loadFailedMessage, "Couldn't load your groups")
    }
}
