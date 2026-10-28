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

    /// D2 (order: owner 2026-10-27, image-framing-editor D4): Edit · Change · View, with existing glyphs.
    func testMenuRows() {
        let rows = GroupDetailContainer.coverActions
        XCTAssertEqual(rows.map(\.label), ["Edit image", "Change image", "View image"])
        XCTAssertEqual(rows.map(\.glyph), ["edit", "upload", "eye"])
        for row in rows { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(rows.map { GroupDetailContainer.CoverChoice(label: $0.label) }, [.edit, .change, .view])
    }
}
