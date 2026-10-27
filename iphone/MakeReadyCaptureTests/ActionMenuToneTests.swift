import XCTest
@testable import MakeReady

/// ui2-groups-edit D13: C-066 rows carry C-067's tone; the default keeps the frozen look.
final class ActionMenuToneTests: XCTestCase {
    func testActionItemDefaultsToStandardTone() {
        XCTAssertEqual(ActionMenuOverlay.ActionItem(glyph: "c066-record", label: "Record a video").tone, .standard)
    }

    func testActionItemCarriesADestructiveTone() {
        let item = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Delete Alpha", tone: .destructive)
        XCTAssertEqual(item.tone, .destructive)
    }
}
