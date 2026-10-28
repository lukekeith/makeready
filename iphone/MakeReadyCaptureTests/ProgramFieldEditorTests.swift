import XCTest
@testable import MakeReady

/// ui2-programs D10: each program field's page, Save rule and one-key patch.
@MainActor
final class ProgramFieldEditorTests: XCTestCase {
    private func program(min: Int? = nil, max: Int? = nil, maxMembers: Int? = nil, access: String? = nil,
                         isPrivate: Bool? = nil, description: String? = nil) -> StudyProgram {
        StudyProgram(id: "p1", name: "Walk", description: description, isPrivate: isPrivate,
                     ageRangeMin: min, ageRangeMax: max, maxMembers: maxMembers, memberDirectoryAccess: access)
    }

    private func page(_ field: ProgramField, _ p: StudyProgram) -> FieldEditPage {
        ProgramFieldEditModel.page(field, program: p, saving: false, errorMessage: "")
    }

    func testNameIsTextSingleWithTheNameRule() {
        guard case let .textSingle(s, canSave) = page(.name, program()) else { return XCTFail("expected textSingle") }
        XCTAssertEqual(s.title, "Study name")
        XCTAssertEqual(s.text, "Walk")
        XCTAssertEqual(s.maxLength, 200)
        XCTAssertFalse(canSave("Walk"))
        XCTAssertFalse(canSave("  "))
        XCTAssertTrue(canSave("Run"))
    }

    func testDescriptionIsTextMulti() {
        guard case let .textMulti(s) = page(.description, program(description: "Daily")) else { return XCTFail("expected textMulti") }
        XCTAssertEqual(s.text, "Daily")
        XCTAssertFalse(s.showsAISuggestions)
    }

    func testVisibilityAndDirectoryAreOptionsSelectedFromTheProgram() {
        guard case let .option(v) = page(.visibility, program(isPrivate: true)) else { return XCTFail("expected option") }
        XCTAssertEqual(v.selectedOption, "Private")
        XCTAssertEqual(v.options, ["Private", "Public"])
        guard case let .option(d) = page(.directoryAccess, program(access: "NOT_ALLOWED")) else { return XCTFail("expected option") }
        XCTAssertEqual(d.selectedOption, "Not allowed")
        guard case let .option(defaults) = page(.directoryAccess, program()) else { return XCTFail("expected option") }
        XCTAssertEqual(defaults.selectedOption, "Allowed")
    }

    func testMaxMembersIsANumberFieldAllowingEmpty() {
        guard case let .textSingle(s, canSave) = page(.maxMembers, program(maxMembers: 40)) else { return XCTFail("expected textSingle") }
        XCTAssertEqual(s.text, "40")
        XCTAssertTrue(s.allowsEmpty)
        XCTAssertTrue(canSave(""))
        XCTAssertFalse(canSave("40"))
        XCTAssertFalse(canSave("0"))
    }

    func testAgeRangeSelectsPresetOrCustom() {
        guard case let .ageRange(preset) = page(.ageRange, program(min: 26, max: 35)) else { return XCTFail("expected ageRange") }
        XCTAssertEqual(preset.selectedOption, "26 - 35")
        guard case let .ageRange(custom) = page(.ageRange, program(min: 18)) else { return XCTFail("expected ageRange") }
        XCTAssertEqual(custom.selectedOption, "Custom range")
        XCTAssertEqual(custom.minimum, "18")
        guard case let .ageRange(any) = page(.ageRange, program()) else { return XCTFail("expected ageRange") }
        XCTAssertEqual(any.selectedOption, "Any age")
    }

    func testPatches() {
        XCTAssertEqual(ProgramFieldEditModel.patch(.name, .text("  Run ")), .name("Run"))
        XCTAssertEqual(ProgramFieldEditModel.patch(.description, .text("  ")), .description(nil))
        XCTAssertEqual(ProgramFieldEditModel.patch(.maxMembers, .text("")), .maxMembers(nil))
        XCTAssertEqual(ProgramFieldEditModel.patch(.maxMembers, .text("12")), .maxMembers(12))
        XCTAssertNil(ProgramFieldEditModel.patch(.maxMembers, .text("abc")))
        XCTAssertEqual(ProgramFieldEditModel.patch(.visibility, .option("Public")), .isPrivate(false))
        XCTAssertEqual(ProgramFieldEditModel.patch(.directoryAccess, .option("Names only")), .memberDirectoryAccess("NAMES_ONLY"))
        XCTAssertEqual(ProgramFieldEditModel.patch(.ageRange, .ageRange(minimum: "", maximum: "")), .ageRange(nil))
        XCTAssertEqual(ProgramFieldEditModel.patch(.ageRange, .ageRange(minimum: "18", maximum: "")), .ageRange(AgeRange(min: 18, max: nil)))
        XCTAssertNil(ProgramFieldEditModel.patch(.ageRange, .ageRange(minimum: "x", maximum: "")))
        XCTAssertNil(ProgramFieldEditModel.patch(.name, .option("Public")))
    }

    func testFailureClasses() {
        XCTAssertEqual(FieldEditRules.failure(for: APIHTTPError(status: 404, message: nil)), .gone)
        XCTAssertEqual(FieldEditRules.failure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(FieldEditRules.failure(for: APIHTTPError(status: 400, message: nil)), .retry)
    }
}
