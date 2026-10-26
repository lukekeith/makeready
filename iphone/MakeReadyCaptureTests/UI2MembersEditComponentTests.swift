import XCTest
import SwiftUI
@testable import MakeReady

/// ui2-members-edit: the MakeReadyUI edits this feature makes (T9 a–f, T10, T11). Render parity is
/// the d2m harness's job via /ui2-resolve (F2/F4); these pin the props and the pure rules.
final class UI2MembersEditComponentTests: XCTestCase {

    // MARK: - Task 5: shared-edit-field template (T9 a–f)

    /// §3: `clean` (trimmed equal to the loaded value) disables Save; `dirty` enables it;
    /// `saving` disables it.
    func testSaveIsEnabledOnlyWhenDirtyAndNotSaving() {
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Ann", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: " Ann \n", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: true, canSave: nil))
    }

    /// T9b / D8: empty is `invalid` unless the screen allows it; clearing a set value is dirty.
    func testEmptyIsInvalidUnlessAllowed() {
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "  ", loaded: "Ann", allowsEmpty: false, saving: false, canSave: nil))
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "  ", loaded: "Ann", allowsEmpty: true, saving: false, canSave: nil))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "", loaded: "", allowsEmpty: true, saving: false, canSave: nil))
    }

    /// T9f / D24: a caller rule replaces dirty/empty, never `saving`; it sees the trimmed text.
    func testCanSaveReplacesTheDirtyRuleButNotSaving() {
        XCTAssertTrue(SharedEditFieldTemplate.saveEnabled(text: "Ann", loaded: "Ann", allowsEmpty: false, saving: false, canSave: { _ in true }))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: false, canSave: { _ in false }))
        XCTAssertFalse(SharedEditFieldTemplate.saveEnabled(text: "Anna", loaded: "Ann", allowsEmpty: false, saving: true, canSave: { _ in true }))
        var seen = ""
        _ = SharedEditFieldTemplate.saveEnabled(text: "  +1 555 \n", loaded: "", allowsEmpty: false, saving: false, canSave: { seen = $0; return true })
        XCTAssertEqual(seen, "+1 555")
    }

    /// T9d: the silent hard cap.
    func testCapClipsTypedText() {
        XCTAssertEqual(SharedEditFieldTemplate.capped("abcdef", maxLength: 3), "abc")
        XCTAssertEqual(SharedEditFieldTemplate.capped("ab", maxLength: 3), "ab")
    }

    /// T9d review fix: the cap runs as a change handler on the field's state, not in the binding
    /// setter — over-cap text yields a replacement (a real state change, so the UITextField
    /// resyncs and drops the extra characters); text within the cap yields none.
    func testOverCapTextIsReplacedByTheClippedValue() {
        XCTAssertEqual(SharedEditFieldTemplate.overflowReplacement(for: "+1 555 0100 0000 00000", maxLength: 20), "+1 555 0100 0000 000")
        XCTAssertNil(SharedEditFieldTemplate.overflowReplacement(for: "+1 555 0100 0000 000", maxLength: 20))
        XCTAssertNil(SharedEditFieldTemplate.overflowReplacement(for: "", maxLength: 20))
    }

    /// Every new prop defaults to today's render: AI block shown, no error line, static input,
    /// single-line caps at 200 and forbids empty, multi-line caps at 2000.
    func testTextScreenStatesDefaultToTodaysRender() {
        let single = EditTextSingleFieldScreen.State(
            title: "T", description: "D", label: "L", placeholder: "", text: "", loadedValue: "",
            focused: false, saving: false, promptCopy: "", aiState: "prompt", suggestions: []
        )
        XCTAssertFalse(single.allowsEmpty)
        XCTAssertEqual(single.maxLength, 200)
        XCTAssertEqual(single.errorMessage, "")
        XCTAssertTrue(single.showsAISuggestions)
        XCTAssertFalse(single.editable)
        XCTAssertFalse(single.focusOnAppear)
        XCTAssertEqual(single.keyboard, .default)
        XCTAssertNil(single.textContentType)
        XCTAssertTrue(single.autocorrect)

        let multi = EditTextMultiFieldScreen.State(
            title: "T", description: "D", label: "L", placeholder: "", text: "", loadedValue: "",
            focused: false, saving: false, promptCopy: "", aiState: "prompt", suggestions: []
        )
        XCTAssertEqual(multi.maxLength, 2000)
        XCTAssertEqual(multi.errorMessage, "")
        XCTAssertTrue(multi.showsAISuggestions)
        XCTAssertFalse(multi.editable)
    }

    /// T9e: the static render stays the default for C-045 and C-046; the live field's defaults.
    func testInputsAreDisplayOnlyUnlessGivenEditing() {
        XCTAssertNil(TextInput(text: "", placeholder: "", kind: .single, focused: false).editing)
        XCTAssertNil(FieldGroup(label: "L", field: .text, style: .default, layout: .default, text: "", placeholder: "").editing)
        let editing = TextInput.Editing()
        XCTAssertEqual(editing.keyboard, .default)
        XCTAssertTrue(editing.isEnabled)
        XCTAssertFalse(editing.focusOnAppear)
        XCTAssertTrue(editing.autocorrect)
        XCTAssertEqual(editing.accessibilityName, "")
    }

    // MARK: - Task 6: MembersProfileScreen field keys (D1, D2, D27, D28)

    /// D2: a row reports its field KEY, never its label; Organization and Role have none (D28).
    func testEveryEditableRowMapsToItsFieldKey() {
        let expected: [String: MemberField] = [
            "Email address": .email, "Phone number": .phone, "Birthday": .birthday, "Gender": .gender,
            "Address": .address, "Emergency contact": .emergencyName, "Emergency phone": .emergencyPhone
        ]
        for (label, field) in expected {
            XCTAssertEqual(MembersProfileScreen.field(forLabel: label), field, label)
            XCTAssertEqual(MembersProfileScreen.label(for: field), label)
        }
        XCTAssertNil(MembersProfileScreen.field(forLabel: "Organization"))
        XCTAssertNil(MembersProfileScreen.field(forLabel: "Role"))
        XCTAssertEqual(MemberField.allCases.map(\.rawValue),
                       ["email", "phone", "birthday", "gender", "address", "emergencyName", "emergencyPhone"])
    }

    /// D1 + D27: exactly the 7 rows are tappable, and only once the member is loaded; the
    /// previews' samples stay display-only.
    func testRowsAreTappableOnlyOnceTheMemberLoaded() {
        var s = MembersProfileScreen.State.populated
        XCTAssertFalse(s.fieldsEditable)
        for label in MembersProfileScreen.fieldLabels {
            XCTAssertFalse(MembersProfileScreen.isTappable(label, s), label)
        }
        s.fieldsEditable = true
        XCTAssertEqual(MembersProfileScreen.fieldLabels.filter { MembersProfileScreen.isTappable($0, s) }, [
            "Phone number", "Email address", "Birthday", "Gender", "Address", "Emergency contact", "Emergency phone"
        ])
    }

    // MARK: - Task 7: EditDateFieldScreen (D3, D9, D13, D26)

    private var june25: DateComponents { DateComponents(year: 1974, month: 6, day: 25) }

    /// D9 / D13: dirty compares the calendar day only; Clear on a set value is dirty; any wheel
    /// value over a stored null is dirty; null over null is clean.
    func testDateDirtyRuleComparesTheCalendarDayOnly() {
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: june25, loaded: june25))
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: DateComponents(year: 1974, month: 6, day: 25, hour: 9), loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: DateComponents(year: 1974, month: 6, day: 26), loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: nil, loaded: june25))
        XCTAssertTrue(EditDateFieldScreen.isDirty(value: june25, loaded: nil))
        XCTAssertFalse(EditDateFieldScreen.isDirty(value: nil, loaded: nil))
    }

    /// D13 / D26: `saving` disables Save and Clear; D9: Clear is disabled when already "Not set".
    func testDateSaveAndClearEnablement() {
        XCTAssertTrue(EditDateFieldScreen.saveEnabled(value: nil, loaded: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.saveEnabled(value: june25, loaded: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.saveEnabled(value: nil, loaded: june25, saving: true))
        XCTAssertFalse(EditDateFieldScreen.clearEnabled(value: nil, saving: false))
        XCTAssertTrue(EditDateFieldScreen.clearEnabled(value: june25, saving: false))
        XCTAssertFalse(EditDateFieldScreen.clearEnabled(value: june25, saving: true))
    }

    /// D9: the wheel opens on the value, or on 2000-01-01 when "Not set", and never outside its range.
    func testDateWheelStartsAtTheValueOr2000AndStaysInRange() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Denver")!
        let min = cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        let max = cal.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let unset = EditDateFieldScreen.wheelStart(loaded: nil, min: min, max: max, calendar: cal)
        XCTAssertEqual(EditDateFieldScreen.components(of: unset, calendar: cal), DateComponents(year: 2000, month: 1, day: 1))
        let set = EditDateFieldScreen.wheelStart(loaded: june25, min: min, max: max, calendar: cal)
        XCTAssertEqual(EditDateFieldScreen.components(of: set, calendar: cal), june25)
        XCTAssertEqual(EditDateFieldScreen.wheelStart(loaded: DateComponents(year: 2030, month: 1, day: 1), min: min, max: max, calendar: cal), max)
        XCTAssertEqual(EditDateFieldScreen.wheelStart(loaded: DateComponents(year: 1850, month: 1, day: 1), min: min, max: max, calendar: cal), min)
    }

    func testDateDayDropsEverythingButTheCalendarDay() {
        XCTAssertEqual(EditDateFieldScreen.day(DateComponents(year: 1974, month: 6, day: 25, hour: 3, minute: 4)), june25)
        XCTAssertNil(EditDateFieldScreen.day(DateComponents(year: 1974, month: 6)))
        XCTAssertNil(EditDateFieldScreen.day(nil))
    }
}
