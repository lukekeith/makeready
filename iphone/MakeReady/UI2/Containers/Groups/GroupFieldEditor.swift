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

/// D2: the built screen a field opens, with its State.
enum GroupFieldPage {
    case textSingle(EditTextSingleFieldScreen.State, canSave: (String) -> Bool)
    case textMulti(EditTextMultiFieldScreen.State)
    case option(EditOptionFieldScreen.State)
    case ageRange(EditOptionsCustomFieldScreen.State)
}

/// What an edit page hands back on Save.
enum GroupFieldInput {
    case text(String)
    case option(String)
    case ageRange(minimum: String, maximum: String)
}

/// D5: what a failed save does.
enum GroupSaveFailure: Equatable {
    /// The task was cancelled — nothing to show.
    case cancelled
    /// 401 — ui2-shell D27 sign-out.
    case signOut
    /// 404 — the group is gone or out of scope: forget it locally and pop to Groups.
    case gone
    /// Anything else — the inline line (the age page: the banner); the value is kept.
    case retry
}

/// ui2-groups-edit §iphone Model: each field's screen State from the cached group, the Save
/// rules the screens do not own, the one-key patch and the failure class. Pure —
/// `GroupFieldEditContainer` renders and saves.
enum GroupFieldEditModel {
    static let saveFailedMessage = "Couldn't save. Try again."

    static let visibilityOptions = ["Private", "Public"]
    static let directoryOptions = ["Allowed", "Names only", "Not allowed"]
    static let ageOptions = ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"]
    static let agePresetMinimums = [18, 26, 36]
    static let agePresetMaximums = [25, 35, 50]
    /// D2: the column is a 32-bit Int; nine digits always fit.
    static let maxMembersDigits = 9

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
    static func nameCanSave(_ typed: String, stored: String) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200 && trimmed != stored
    }

    /// D2: empty = Unlimited; otherwise ASCII digits forming an integer ≥ 1; different from stored.
    static func maxMembersCanSave(_ typed: String, stored: Int?) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return stored != nil }
        guard trimmed.allSatisfy({ ("0"..."9").contains($0) }), let value = Int(trimmed), value >= 1 else { return false }
        return value != stored
    }

    /// D4: both null → "Any age"; equal to a preset → that preset; anything else → "Custom range".
    static func ageSelection(_ range: AgeRange?) -> String {
        guard let range, range.min != nil || range.max != nil else { return ageOptions[0] }
        for (i, low) in agePresetMinimums.enumerated() where range.min == low && range.max == agePresetMaximums[i] {
            return ageOptions[i + 1]
        }
        return ageOptions[ageOptions.count - 1]
    }

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
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return .maxMembers(nil) }
            guard let value = Int(trimmed) else { return nil }
            return .maxMembers(value)
        case (.visibility, .option(let label)):
            switch label {
            case "Private": return .isPrivate(true)
            case "Public": return .isPrivate(false)
            default: return nil
            }
        case (.directoryAccess, .option(let label)):
            switch label {
            case "Allowed": return .memberDirectoryAccess("ALLOWED")
            case "Names only": return .memberDirectoryAccess("NAMES_ONLY")
            case "Not allowed": return .memberDirectoryAccess("NOT_ALLOWED")
            default: return nil
            }
        case (.ageRange, .ageRange(let minimum, let maximum)):
            if minimum.isEmpty && maximum.isEmpty { return .ageRange(nil) }
            guard let low = wholeNumber(minimum), let high = wholeNumber(maximum) else { return nil }
            return .ageRange(AgeRange(min: low, max: high))
        default:
            return nil
        }
    }

    /// A bound's value: `.some(nil)` when empty (no bound), `.some(n)` for a whole number,
    /// nil when the text is neither.
    private static func wholeNumber(_ text: String) -> Int?? {
        if text.isEmpty { return .some(nil) }
        guard let value = Int(text) else { return nil }
        return .some(value)
    }

    /// D5: cancelled → nothing; 401 → sign-out; 404 → gone; anything else → retry.
    static func failure(for error: Error) -> GroupSaveFailure {
        if GroupActions.isCancellation(error) { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) { return .signOut }
        if let http = error as? APIHTTPError, http.status == 404 { return .gone }
        return .retry
    }

    /// D2: a group text-single page — title = label, no placeholder, no AI block (P11), focused on appear.
    private static func single(_ field: GroupField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        var s = EditTextSingleFieldScreen.State(
            title: title(field), description: description(field), label: title(field), placeholder: "",
            text: text, loadedValue: text, focused: false, saving: saving,
            promptCopy: "", aiState: "prompt", suggestions: []
        )
        s.errorMessage = errorMessage
        s.showsAISuggestions = false
        s.editable = true
        s.focusOnAppear = true
        return s
    }
}
