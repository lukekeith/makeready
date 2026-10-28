import Foundation

/// ui2-programs D10: each program field's screen State from the cached program, its Save rule
/// and its one-key patch — the group edit pages' shape (ui2-groups-edit D2–D5) over a program,
/// on the shared rules in FieldEditRules. Pure — `ProgramFieldEditContainer` renders and saves.
enum ProgramFieldEditModel {
    /// The page title — the row's label ("Age range" opens from the "Age" row, as for groups).
    static func title(_ field: ProgramField) -> String {
        switch field {
        case .name: return "Study name"
        case .description: return "Description"
        case .visibility: return "Visibility"
        case .ageRange: return "Age range"
        case .maxMembers: return "Maximum members"
        case .directoryAccess: return "Member directory access"
        }
    }

    /// The group pages' descriptions with "group" read as "study program".
    static func description(_ field: ProgramField) -> String {
        switch field {
        case .name:
            return "The study name is the primary title for your study program that will be surfaced anytime the program is displayed in a MakeReady app"
        case .description:
            return "The description is used to help others understand the purpose of your study program at a glance."
        case .visibility:
            return "Visibility determines who is able to find the study program"
        case .ageRange:
            return "The ages this study program is written for."
        case .maxMembers:
            return "The most members a group studying this program should have. Leave it blank for no limit."
        case .directoryAccess:
            return "Choose what members studying this program can see about each other."
        }
    }

    static let visibilityDescriptions = [
        "Only you, the program's leader and your organization's admins can find this program.",
        "Leaders in your organization can find and use this program."
    ]

    static let directoryDescriptions = [
        "All members are able to view the full membership directory with contact information for every member",
        "Members are able to see who is in the group, but they are not able to view any contact information",
        "Members are not able to view any information about members in the group"
    ]

    static func page(_ field: ProgramField, program: StudyProgram, saving: Bool, errorMessage: String) -> FieldEditPage {
        switch field {
        case .name:
            var s = single(field, text: program.name, saving: saving, errorMessage: errorMessage)
            s.maxLength = 200
            s.autocapitalization = .words
            let stored = program.name
            return .textSingle(s, canSave: { FieldEditRules.nameCanSave($0, stored: stored) })
        case .maxMembers:
            var s = single(field, text: program.maxMembers.map(String.init) ?? "", saving: saving, errorMessage: errorMessage)
            s.keyboard = .numberPad
            s.autocapitalization = .never
            s.autocorrect = false
            s.allowsEmpty = true
            s.maxLength = FieldEditRules.maxMembersDigits
            let stored = program.maxMembers
            return .textSingle(s, canSave: { FieldEditRules.maxMembersCanSave($0, stored: stored) })
        case .description:
            let text = program.description ?? ""
            var s = EditTextMultiFieldScreen.State(
                title: title(field), description: description(field), label: title(field), placeholder: "",
                text: text, loadedValue: text, focused: false, saving: saving,
                promptCopy: "", aiState: "prompt", suggestions: []
            )
            s.maxLength = 2000
            s.errorMessage = errorMessage
            s.showsAISuggestions = false
            s.editable = true
            s.focusOnAppear = true
            return .textMulti(s)
        case .visibility:
            let selected = GroupDetailMapper.visibilityLabel(program.isPrivate ?? false)
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: FieldEditRules.visibilityOptions, optionDescriptions: visibilityDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .directoryAccess:
            let selected = GroupDetailMapper.directoryAccessLabel(program.memberDirectoryAccess, memberDirectory: true)
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: FieldEditRules.directoryOptions, optionDescriptions: directoryDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .ageRange:
            let minimum = program.ageRangeMin.map(String.init) ?? ""
            let maximum = program.ageRangeMax.map(String.init) ?? ""
            var s = EditOptionsCustomFieldScreen.State(
                title: title(field), description: description(field),
                options: FieldEditRules.ageOptions, presetMinimums: FieldEditRules.agePresetMinimums,
                presetMaximums: FieldEditRules.agePresetMaximums,
                minimumLabel: "Minimum age", maximumLabel: "Maximum age",
                minimumPlaceholder: "18", maximumPlaceholder: "24",
                selectedOption: FieldEditRules.ageSelection(StudyProgramHomeMapper.ageRange(program)),
                minimum: minimum, maximum: maximum,
                loadedMinimum: minimum, loadedMaximum: maximum,
                focusedInput: "", saving: saving
            )
            s.editable = true
            return .ageRange(s)
        }
    }

    /// The one key and its wire value; nil when the input does not belong to the field, or when a
    /// non-empty number is not a whole number (never a silent clear).
    static func patch(_ field: ProgramField, _ input: FieldEditInput) -> ProgramPatch? {
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

    private static func single(_ field: ProgramField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        FieldEditRules.single(title: title(field), description: description(field), text: text, saving: saving,
                              errorMessage: errorMessage)
    }
}
