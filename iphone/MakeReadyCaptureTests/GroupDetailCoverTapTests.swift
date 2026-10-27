import XCTest
@testable import MakeReady

/// group-cover-image D1/D2/F7: what a cover tap does, read from AppState's group (never the screen
/// state, whose coverURL is "" until the image is cached).
@MainActor
final class GroupDetailCoverTapTests: XCTestCase {
    private func group(cover: String?) -> UserGroup {
        UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, isPrivate: false, allowInvites: true,
                  memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testNoCoverOpensThePicker() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: nil)), .picker)
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: "")), .picker)
    }

    func testACoverOpensTheMenu() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: "https://img/c.jpeg")), .menu)
    }

    /// F7: while the group is not in AppState the tap does nothing.
    func testUnloadedGroupIsInert() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: nil), .none)
    }

    /// D2: three rows, in order, with existing glyphs.
    func testMenuRows() {
        let rows = GroupDetailContainer.coverActions
        XCTAssertEqual(rows.map(\.label), ["Change image", "Edit image", "View image"])
        XCTAssertEqual(rows.map(\.glyph), ["upload", "edit", "eye"])
        for row in rows { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(rows.map { GroupDetailContainer.CoverChoice(label: $0.label) }, [.change, .edit, .view])
    }
}
