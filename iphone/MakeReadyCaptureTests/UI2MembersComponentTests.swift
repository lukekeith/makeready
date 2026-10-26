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
}
