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
    /// Agent walk round 1: tapping a chip opened no menu. A `Menu` chip fires `onTap`, and an
    /// unlabelled trailing closure on FilterChip binds to `onSelect` (Swift 5's backward scan).
    func testMembersHomeMenuChipTapPresentsTheMenu() {
        var tapped = false
        MembersHomeScreen.menuChip(label: "All Groups") { tapped = true }.onTap()
        XCTAssertTrue(tapped)
    }

    func testMembersHomeTakesNoNavCallbacks() {
        var opened: [Int] = []
        let screen = MembersHomeScreen(state: .populated, onOpenMember: { opened.append($0) })
        screen.onOpenMember(2)
        XCTAssertEqual(opened, [2])
    }

    // MARK: - Task 14: C-042 non-tappable form + MembersProfileScreen (D3, P5/D9, P6, P7, D10, D12)

    func testEditableFieldRowIsTappableUnlessToldOtherwise() {
        XCTAssertTrue(EditableFieldRow(label: "Email address", value: "a@b.example").isTappable)
        XCTAssertFalse(EditableFieldRow(label: "Role", value: "Member", isTappable: false).isTappable)
    }

    /// D22: the screen draws its own C-040 unless the container pins it (capture render stays whole).
    func testMemberPageDrawsItsHeaderByDefault() {
        XCTAssertTrue(MembersProfileScreen(state: .populated).showsHeader)
        XCTAssertFalse(MembersProfileScreen(state: .populated, showsHeader: false).showsHeader)
    }

    /// P6: nine rows, "Emergency phone" last; D3: none of them tappable in this child.
    func testMemberPageDrawsNineDisplayOnlyFields() {
        XCTAssertEqual(MembersProfileScreen.fieldLabels, [
            "Organization", "Role", "Phone number", "Email address", "Birthday",
            "Gender", "Address", "Emergency contact", "Emergency phone"
        ])
        XCTAssertFalse(MembersProfileScreen.fieldsTappable)
    }

    func testFieldValuesComeFromTheirOwnStateFields() {
        let s = MembersProfileScreen.State.populated
        XCTAssertEqual(MembersProfileScreen.fieldValue("Emergency contact", s), s.emergencyContactName)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Emergency phone", s), s.emergencyContactPhone)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Address", s), s.address)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Organization", s), s.organization)
    }

    /// P5/D9: Email carries no indicator; Phone reads Verified / Unverified.
    func testOnlyPhoneCarriesAVerificationIndicator() {
        var s = MembersProfileScreen.State.populated
        XCTAssertNil(MembersProfileScreen.indicator(forField: "Email address", state: s))
        XCTAssertEqual(MembersProfileScreen.indicator(forField: "Phone number", state: s)?.text, "Verified")
        s.phoneVerified = false
        XCTAssertEqual(MembersProfileScreen.indicator(forField: "Phone number", state: s)?.text, "Unverified")
        s.phone = ""
        XCTAssertNil(MembersProfileScreen.indicator(forField: "Phone number", state: s))   // D10: no value, no indicator
    }

    /// D10: Age is a String so a missing birthday renders an empty value line.
    func testSamplesCarryTheSplitEmergencyContactAndAStringAge() {
        XCTAssertEqual(MembersProfileScreen.State.populated.age, "52")
        XCTAssertEqual(MembersProfileScreen.State.populated.emergencyContactName, "Pepper Stark")
        XCTAssertEqual(MembersProfileScreen.State.populated.emergencyContactPhone, "+1 (123) 456-7891")
        XCTAssertEqual(MembersProfileScreen.State.partial.emergencyContactPhone, "")
    }

    /// D12: today is the rail's trailing card.
    func testRailTodayIndex() {
        XCTAssertEqual(MembersProfileScreen.todayIndex(["default", "default", "today"]), 2)
        XCTAssertEqual(MembersProfileScreen.todayIndex(MembersProfileScreen.State.populated.dayDateStates), 3)
        XCTAssertNil(MembersProfileScreen.todayIndex([]))
    }
}
