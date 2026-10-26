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
}
