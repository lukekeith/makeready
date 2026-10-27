import XCTest
@testable import MakeReady

/// ui2-groups-edit D1–D5: the group edit pages' pure rules.
final class GroupFieldEditorTests: XCTestCase {
    private func group(description: String? = "Men meeting Tuesday mornings.", isPrivate: Bool = true,
                       ageRange: AgeRange? = AgeRange(min: 26, max: 35), maxMembers: Int? = 40,
                       access: String? = "NAMES_ONLY") -> UserGroup {
        UserGroup(id: "g1", code: "ABC123", name: "Tuesday Men's Group", description: description, isPrivate: isPrivate,
                  allowInvites: true, memberDirectory: access == "ALLOWED", ageRange: ageRange, maxMembers: maxMembers,
                  memberCount: 8, creatorId: "u1", memberDirectoryAccess: access, createdAt: Date(), updatedAt: Date())
    }

    // MARK: D1

    func testLabelsMapToFieldsAndUnknownLabelsDoNothing() {
        XCTAssertEqual(GroupField(label: "Group name"), .name)
        XCTAssertEqual(GroupField(label: "Description"), .description)
        XCTAssertEqual(GroupField(label: "Visibility"), .visibility)
        XCTAssertEqual(GroupField(label: "Age"), .ageRange)
        XCTAssertEqual(GroupField(label: "Maximum members"), .maxMembers)
        XCTAssertEqual(GroupField(label: "Member directory access"), .directoryAccess)
        XCTAssertNil(GroupField(label: "Cover"))
    }

    // MARK: D2/D3 pages

    func testNamePage() {
        guard case let .textSingle(s, canSave) = GroupFieldEditModel.page(.name, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("name is a text-single page")
        }
        XCTAssertEqual(s.title, "Group name")
        XCTAssertEqual(s.text, "Tuesday Men's Group")
        XCTAssertEqual(s.loadedValue, "Tuesday Men's Group")
        XCTAssertEqual(s.maxLength, 200)
        XCTAssertFalse(s.allowsEmpty)
        XCTAssertFalse(s.showsAISuggestions)
        XCTAssertTrue(s.description.hasPrefix("The group name is the primary title"))
        XCTAssertFalse(canSave("Tuesday Men's Group"))
        XCTAssertFalse(canSave("  Tuesday Men's Group  "))          // trimmed = stored
        XCTAssertTrue(canSave("Thursday Men"))
    }

    func testNameCanSaveRules() {
        XCTAssertFalse(GroupFieldEditModel.nameCanSave("   ", stored: "A"))
        XCTAssertFalse(GroupFieldEditModel.nameCanSave(String(repeating: "x", count: 201), stored: "A"))
        XCTAssertTrue(GroupFieldEditModel.nameCanSave(String(repeating: "x", count: 200), stored: "A"))
    }

    func testDescriptionPage() {
        guard case let .textMulti(s) = GroupFieldEditModel.page(.description, group: group(description: nil), saving: false, errorMessage: "") else {
            return XCTFail("description is a text-multi page")
        }
        XCTAssertEqual(s.title, "Description")
        XCTAssertEqual(s.text, "")
        XCTAssertEqual(s.maxLength, 2000)
        XCTAssertFalse(s.showsAISuggestions)
    }

    func testVisibilityPage() {
        guard case let .option(s) = GroupFieldEditModel.page(.visibility, group: group(isPrivate: false), saving: false, errorMessage: "") else {
            return XCTFail("visibility is an option page")
        }
        XCTAssertEqual(s.title, "Visibility")
        XCTAssertEqual(s.options, ["Private", "Public"])
        XCTAssertEqual(s.optionDescriptions.count, 2)
        XCTAssertEqual(s.selectedOption, "Public")
        XCTAssertEqual(s.loadedValue, "Public")
    }

    func testDirectoryPage() {
        guard case let .option(s) = GroupFieldEditModel.page(.directoryAccess, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("directory is an option page")
        }
        XCTAssertEqual(s.title, "Member directory access")
        XCTAssertEqual(s.description, "Choose what members of this group can see about each other.")
        XCTAssertEqual(s.options, ["Allowed", "Names only", "Not allowed"])
        XCTAssertEqual(s.selectedOption, "Names only")
    }

    func testMaxMembersPage() {
        guard case let .textSingle(s, canSave) = GroupFieldEditModel.page(.maxMembers, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("maxMembers is a text-single page")
        }
        XCTAssertEqual(s.title, "Maximum members")
        XCTAssertEqual(s.description, "The most members this group can have. Leave it blank for no limit.")
        XCTAssertEqual(s.text, "40")
        XCTAssertEqual(s.keyboard, .numberPad)
        XCTAssertTrue(s.allowsEmpty)
        XCTAssertFalse(canSave("40"))
        XCTAssertTrue(canSave("41"))
        XCTAssertTrue(canSave(""))
    }

    func testMaxMembersCanSaveRules() {
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("", stored: nil))     // Unlimited → Unlimited
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave("", stored: 40))       // → Unlimited
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("0", stored: nil))
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("4a", stored: nil))
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("-3", stored: nil))
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave("1", stored: nil))
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave(" 12 ", stored: 40))
    }

    // MARK: D4 age range

    func testAgeSelectionFromStoredBounds() {
        XCTAssertEqual(GroupFieldEditModel.ageSelection(nil), "Any age")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: nil, max: nil)), "Any age")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 18, max: 25)), "18 - 25")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 26, max: 35)), "26 - 35")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 36, max: 50)), "36 - 50")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 30, max: nil)), "Custom range")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 20, max: 30)), "Custom range")
    }

    func testAgePage() {
        guard case let .ageRange(s) = GroupFieldEditModel.page(.ageRange, group: group(), saving: true, errorMessage: "") else {
            return XCTFail("age is an options-custom page")
        }
        XCTAssertEqual(s.title, "Age range")
        XCTAssertEqual(s.options, ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"])
        XCTAssertEqual(s.presetMinimums, [18, 26, 36])
        XCTAssertEqual(s.presetMaximums, [25, 35, 50])
        XCTAssertEqual(s.minimumLabel, "Minimum age")
        XCTAssertEqual(s.maximumLabel, "Maximum age")
        XCTAssertEqual(s.selectedOption, "26 - 35")
        XCTAssertEqual(s.minimum, "26")
        XCTAssertEqual(s.loadedMaximum, "35")
        XCTAssertTrue(s.saving)
        XCTAssertTrue(s.editable)                                     // C1: the inputs take typing
    }

    /// D4 lives in the built screen (F8 → OQ-6); these pin its Save rule.
    private func ageSave(_ selection: String, _ minimum: String, _ maximum: String,
                         loaded: (String, String) = ("", ""), saving: Bool = false) -> Bool {
        EditOptionsCustomFieldScreen.saveEnabled(
            selection: selection, minimum: minimum, maximum: maximum,
            loadedMinimum: loaded.0, loadedMaximum: loaded.1,
            options: GroupFieldEditModel.ageOptions, saving: saving
        )
    }

    func testAgeSaveRejectsEveryD4InvalidCase() {
        XCTAssertFalse(ageSave("Custom range", "30", "20"))                     // min > max
        XCTAssertFalse(ageSave("Custom range", "121", ""))                      // above 120
        XCTAssertFalse(ageSave("Custom range", "", "121"))
        XCTAssertFalse(ageSave("Custom range", "-1", ""))                       // below 0
        XCTAssertFalse(ageSave("Custom range", "4a", ""))                       // not a whole number
        XCTAssertFalse(ageSave("Custom range", "", "2.5"))
        XCTAssertFalse(ageSave("Custom range", "", ""))                         // Custom, both empty
        XCTAssertFalse(ageSave("Custom range", "30", "", loaded: ("30", "")))   // unchanged
        XCTAssertFalse(ageSave("Custom range", "030", "", loaded: ("30", "")))  // same effective bound
        XCTAssertFalse(ageSave("Any age", "", ""))                              // Any age → Any age
        XCTAssertFalse(ageSave("Custom range", "20", "30", saving: true))       // saving
    }

    func testAgeSaveAcceptsValidChanges() {
        XCTAssertTrue(ageSave("Custom range", "20", "30"))
        XCTAssertTrue(ageSave("Custom range", "30", "30"))                      // equal bounds
        XCTAssertTrue(ageSave("Custom range", "0", "120"))
        XCTAssertTrue(ageSave("Custom range", "30", ""))                        // one bound
        XCTAssertTrue(ageSave("18 - 25", "18", "25", loaded: ("26", "35")))
        XCTAssertTrue(ageSave("Any age", "", "", loaded: ("26", "35")))         // clear
    }

    // MARK: D2/D4 patches

    func testPatches() {
        XCTAssertEqual(GroupFieldEditModel.patch(.name, .text("  Alpha  ")), .name("Alpha"))
        XCTAssertEqual(GroupFieldEditModel.patch(.description, .text("  ")), .description(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.description, .text("Hello")), .description("Hello"))
        XCTAssertEqual(GroupFieldEditModel.patch(.visibility, .option("Private")), .isPrivate(true))
        XCTAssertEqual(GroupFieldEditModel.patch(.visibility, .option("Public")), .isPrivate(false))
        XCTAssertEqual(GroupFieldEditModel.patch(.maxMembers, .text("")), .maxMembers(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.maxMembers, .text("25")), .maxMembers(25))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Allowed")), .memberDirectoryAccess("ALLOWED"))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Names only")), .memberDirectoryAccess("NAMES_ONLY"))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Not allowed")), .memberDirectoryAccess("NOT_ALLOWED"))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "", maximum: "")), .ageRange(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "26", maximum: "35")), .ageRange(AgeRange(min: 26, max: 35)))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "30", maximum: "")), .ageRange(AgeRange(min: 30, max: nil)))
        XCTAssertNil(GroupFieldEditModel.patch(.name, .option("Private")))           // wrong input for the field
        XCTAssertNil(GroupFieldEditModel.patch(.visibility, .option("Sometimes")))
    }

    /// I2: text that is not a whole number never becomes a cleared value.
    func testPatchRefusesTextThatIsNotAWholeNumber() {
        XCTAssertNil(GroupFieldEditModel.patch(.maxMembers, .text("4a")))
        XCTAssertNil(GroupFieldEditModel.patch(.maxMembers, .text("2.5")))
        XCTAssertNil(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "4a", maximum: "")))
        XCTAssertNil(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "", maximum: "x")))
        XCTAssertNil(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "20", maximum: "3o")))
    }

    // MARK: D5 failures

    func testFailureClasses() {
        XCTAssertEqual(GroupFieldEditModel.failure(for: CancellationError()), .cancelled)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIHTTPError(status: 404, message: "Group not found")), .gone)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIHTTPError(status: 400, message: "bad")), .retry)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIError.serverError("boom")), .retry)
    }
}
