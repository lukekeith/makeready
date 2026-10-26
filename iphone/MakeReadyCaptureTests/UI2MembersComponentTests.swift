import XCTest
@testable import MakeReady

/// ui2-members-browse: the MakeReadyUI edits this feature makes (D19 C-034, T11/T12 screens,
/// D3 C-042). Render parity is the d2m capture's job (F14); these pin the props.
final class UI2MembersComponentTests: XCTestCase {

    // MARK: - Task 12: C-034 SearchField (D19)

    /// C-034 §4: `Default` = empty ∧ ¬focused · `Focus` = empty ∧ focused · `Has value` = ¬empty.
    func testSearchFieldAppearanceIsDerivedFromTextAndFocus() {
        XCTAssertEqual(SearchField.appearance(text: "", focused: false), .default)
        XCTAssertEqual(SearchField.appearance(text: "", focused: true), .focus)
        XCTAssertEqual(SearchField.appearance(text: "ke", focused: false), .hasValue)
        XCTAssertEqual(SearchField.appearance(text: "ke", focused: true), .hasValue)
    }

    func testSearchFieldIsDisplayOnlyUnlessAskedToEdit() {
        XCTAssertFalse(SearchField(text: "", placeholder: "Search members", focused: false).editable)
        XCTAssertTrue(SearchField(text: "", placeholder: "Search members", focused: false, editable: true).editable)
    }

    // MARK: - Task 13: MembersHomeScreen (D4, D7/D15, T11)

    func testMembersHomeSampleCarriesTheLeaderChipAndInitials() {
        let s = MembersHomeScreen.State.populated
        XCTAssertTrue(s.showsLeaderFilter)
        XCTAssertEqual(s.memberInitials, ["BA", "CK", "IH", "DT", "BW"])
        XCTAssertEqual(s.memberInitials.count, s.memberNames.count)
    }

    /// D4: the screen is built from its State and its four outward actions alone.
    func testMembersHomeTakesNoNavCallbacks() {
        var opened: [Int] = []
        let screen = MembersHomeScreen(state: .populated, onOpenMember: { opened.append($0) })
        screen.onOpenMember(2)
        XCTAssertEqual(opened, [2])
    }
}
