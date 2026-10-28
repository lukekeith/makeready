import Foundation
import SwiftUI

/// ui2-groups-edit D1: the group page's six setting rows.
enum GroupField: String, Hashable, CaseIterable {
    case name, description, visibility, ageRange, maxMembers, directoryAccess

    /// D1: GroupsDetailScreen's row label → its field; any other label is nil (the tap does nothing).
    init?(label: String) {
        switch label {
        case "Group name": self = .name
        case "Description": self = .description
        case "Visibility": self = .visibility
        case "Age": self = .ageRange
        case "Maximum members": self = .maxMembers
        case "Member directory access": self = .directoryAccess
        default: return nil
        }
    }
}

/// D2/D5: the shared page, input and failure types (Shared/FieldEditRules.swift, ui2-programs D10).
typealias GroupFieldPage = FieldEditPage
typealias GroupFieldInput = FieldEditInput
typealias GroupSaveFailure = FieldSaveFailure

/// ui2-groups-edit §iphone Model: each field's screen State from the cached group, the Save
/// rules the screens do not own, the one-key patch and the failure class. Pure —
/// `GroupFieldEditContainer` renders and saves.
enum GroupFieldEditModel {
    static let saveFailedMessage = FieldEditRules.saveFailedMessage

    static let visibilityOptions = FieldEditRules.visibilityOptions
    static let directoryOptions = FieldEditRules.directoryOptions
    static let ageOptions = FieldEditRules.ageOptions
    static let agePresetMinimums = FieldEditRules.agePresetMinimums
    static let agePresetMaximums = FieldEditRules.agePresetMaximums
    /// D2: the column is a 32-bit Int; nine digits always fit.
    static let maxMembersDigits = FieldEditRules.maxMembersDigits

    /// D2: shared-edit-field §2b titles ("Age range" opens from the "Age" row).
    static func title(_ field: GroupField) -> String {
        switch field {
        case .name: return "Group name"
        case .description: return "Description"
        case .visibility: return "Visibility"
        case .ageRange: return "Age range"
        case .maxMembers: return "Maximum members"
        case .directoryAccess: return "Member directory access"
        }
    }

    /// D3: §2b's descriptions verbatim; the two the design left blank are D3's drafts.
    static func description(_ field: GroupField) -> String {
        switch field {
        case .name:
            return "The group name is the primary title for your group that will be surfaced anytime the group is displayed in a MakeReady app"
        case .description:
            return "The group description is used to help others understand the purpose of your group at a glance."
        case .visibility:
            return "Visibility determines who is able to view the group"
        case .ageRange:
            return "If an age range is specified, then every member who joins must fall within the specified range."
        case .maxMembers:
            return "The most members this group can have. Leave it blank for no limit."
        case .directoryAccess:
            return "Choose what members of this group can see about each other."
        }
    }

    static let visibilityDescriptions = [
        "Only active members of the group can view information about the group, organization, and group leader.",
        "Anyone can search and view information about the group and the group leader."
    ]

    static let directoryDescriptions = [
        "All members are able to view the full membership directory with contact information for every member",
        "Members are able to see who is in the group, but they are not able to view any contact information",
        "Members are not able to view any information about members in the group"
    ]

    /// D2 arrangement per field, from the cached group.
    static func page(_ field: GroupField, group: UserGroup, saving: Bool, errorMessage: String) -> GroupFieldPage {
        switch field {
        case .name:
            var s = single(field, text: group.name, saving: saving, errorMessage: errorMessage)
            s.maxLength = 200
            s.autocapitalization = .words
            let stored = group.name
            return .textSingle(s, canSave: { nameCanSave($0, stored: stored) })
        case .maxMembers:
            var s = single(field, text: group.maxMembers.map(String.init) ?? "", saving: saving, errorMessage: errorMessage)
            s.keyboard = .numberPad
            s.autocapitalization = .never
            s.autocorrect = false
            s.allowsEmpty = true
            s.maxLength = maxMembersDigits
            let stored = group.maxMembers
            return .textSingle(s, canSave: { maxMembersCanSave($0, stored: stored) })
        case .description:
            let text = group.description ?? ""
            var s = EditTextMultiFieldScreen.State(
                title: title(field), description: description(field), label: title(field), placeholder: "",
                text: text, loadedValue: text, focused: false, saving: saving,
                promptCopy: "", aiState: "prompt", suggestions: []
            )
            s.maxLength = 2000
            s.errorMessage = errorMessage
            s.showsAISuggestions = false                       // P11
            s.editable = true
            s.focusOnAppear = true
            return .textMulti(s)
        case .visibility:
            let selected = group.isPrivate ? "Private" : "Public"
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: visibilityOptions, optionDescriptions: visibilityDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .directoryAccess:
            let selected = GroupDetailMapper.directoryAccessLabel(group.memberDirectoryAccess, memberDirectory: group.memberDirectory)
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: directoryOptions, optionDescriptions: directoryDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .ageRange:
            let minimum = group.ageRange?.min.map(String.init) ?? ""
            let maximum = group.ageRange?.max.map(String.init) ?? ""
            var s = EditOptionsCustomFieldScreen.State(
                title: title(field), description: description(field),
                options: ageOptions, presetMinimums: agePresetMinimums, presetMaximums: agePresetMaximums,
                minimumLabel: "Minimum age", maximumLabel: "Maximum age",
                minimumPlaceholder: "18", maximumPlaceholder: "24",
                selectedOption: ageSelection(group.ageRange),
                minimum: minimum, maximum: maximum,
                loadedMinimum: minimum, loadedMaximum: maximum,
                focusedInput: "", saving: saving
            )
            s.editable = true                                  // C1: the bounds take typing
            return .ageRange(s)
        }
    }

    /// D2: 1–200 characters after trimming, and different from the stored name.
    static func nameCanSave(_ typed: String, stored: String) -> Bool { FieldEditRules.nameCanSave(typed, stored: stored) }

    /// D2: empty = Unlimited; otherwise ASCII digits forming an integer ≥ 1; different from stored.
    static func maxMembersCanSave(_ typed: String, stored: Int?) -> Bool { FieldEditRules.maxMembersCanSave(typed, stored: stored) }

    /// D4: both null → "Any age"; equal to a preset → that preset; anything else → "Custom range".
    static func ageSelection(_ range: AgeRange?) -> String { FieldEditRules.ageSelection(range) }

    /// D2/D4: the one key and its wire value; nil when the input does not belong to the field,
    /// or when a non-empty number input is not a whole number (I2: never a silent clear).
    static func patch(_ field: GroupField, _ input: GroupFieldInput) -> GroupPatch? {
        switch (field, input) {
        case (.name, .text(let s)):
            return .name(s.trimmingCharacters(in: .whitespacesAndNewlines))
        case (.description, .text(let s)):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return .description(trimmed.isEmpty ? nil : trimmed)
        case (.maxMembers, .text(let s)):
            return FieldEditRules.maxMembers(s).map { .maxMembers($0) }
        case (.visibility, .option(let label)):
            return FieldEditRules.isPrivate(label).map { .isPrivate($0) }
        case (.directoryAccess, .option(let label)):
            return FieldEditRules.directoryAccessValue(label).map { .memberDirectoryAccess($0) }
        case (.ageRange, .ageRange(let minimum, let maximum)):
            return FieldEditRules.ageRange(minimum: minimum, maximum: maximum).map { .ageRange($0) }
        default:
            return nil
        }
    }

    /// D5: cancelled → nothing; 401 → sign-out; 404 → gone; anything else → retry.
    static func failure(for error: Error) -> GroupSaveFailure { FieldEditRules.failure(for: error) }

    /// D2: a group text-single page — title = label, no placeholder, no AI block (P11), focused on appear.
    private static func single(_ field: GroupField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        FieldEditRules.single(title: title(field), description: description(field), text: text, saving: saving,
                              errorMessage: errorMessage)
    }
}
