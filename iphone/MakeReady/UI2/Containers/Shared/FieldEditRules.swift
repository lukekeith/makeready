import Foundation

/// ui2-groups-edit D2 + ui2-programs D10: the built screen a settings field opens, with its State —
/// shared by the group and program edit pages.
enum FieldEditPage {
    case textSingle(EditTextSingleFieldScreen.State, canSave: (String) -> Bool)
    case textMulti(EditTextMultiFieldScreen.State)
    case option(EditOptionFieldScreen.State)
    case ageRange(EditOptionsCustomFieldScreen.State)
}

/// What an edit page hands back on Save.
enum FieldEditInput {
    case text(String)
    case option(String)
    case ageRange(minimum: String, maximum: String)
}

/// ui2-groups-edit D5 / ui2-programs D10: what a failed save does.
enum FieldSaveFailure: Equatable {
    /// The task was cancelled — nothing to show.
    case cancelled
    /// 401 — ui2-shell D27 sign-out.
    case signOut
    /// 404 — the subject is gone or out of scope: forget it locally and pop to the root.
    case gone
    /// Anything else — the inline line (the age page: the banner); the value is kept.
    case retry
}

/// The settings-field rules the group and program edit pages share (lifted from
/// GroupFieldEditModel for ui2-programs D10): the option sets, the Save checks, the age presets
/// and the failure class. Pure.
enum FieldEditRules {
    static let saveFailedMessage = "Couldn't save. Try again."

    static let visibilityOptions = ["Private", "Public"]
    static let directoryOptions = ["Allowed", "Names only", "Not allowed"]
    static let ageOptions = ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"]
    static let agePresetMinimums = [18, 26, 36]
    static let agePresetMaximums = [25, 35, 50]
    /// The columns are 32-bit Ints; nine digits always fit.
    static let maxMembersDigits = 9

    /// 1–200 characters after trimming, and different from the stored name.
    static func nameCanSave(_ typed: String, stored: String) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200 && trimmed != stored
    }

    /// Empty = Unlimited; otherwise ASCII digits forming an integer ≥ 1; different from stored.
    static func maxMembersCanSave(_ typed: String, stored: Int?) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return stored != nil }
        guard trimmed.allSatisfy({ ("0"..."9").contains($0) }), let value = Int(trimmed), value >= 1 else { return false }
        return value != stored
    }

    /// Both null → "Any age"; equal to a preset → that preset; anything else → "Custom range".
    static func ageSelection(_ range: AgeRange?) -> String {
        guard let range, range.min != nil || range.max != nil else { return ageOptions[0] }
        for (i, low) in agePresetMinimums.enumerated() where range.min == low && range.max == agePresetMaximums[i] {
            return ageOptions[i + 1]
        }
        return ageOptions[ageOptions.count - 1]
    }

    /// The two age texts as a range: nil range when both are empty; nil (not a value) when a
    /// non-empty bound is not a whole number (never a silent clear).
    static func ageRange(minimum: String, maximum: String) -> AgeRange?? {
        if minimum.isEmpty && maximum.isEmpty { return .some(nil) }
        guard let low = wholeNumber(minimum), let high = wholeNumber(maximum) else { return nil }
        return .some(AgeRange(min: low, max: high))
    }

    /// The max-members text: `.some(nil)` when empty (Unlimited), `.some(n)` for a whole number,
    /// nil when neither.
    static func maxMembers(_ text: String) -> Int?? {
        wholeNumber(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// The directory option label's wire value.
    static func directoryAccessValue(_ label: String) -> String? {
        switch label {
        case "Allowed": return "ALLOWED"
        case "Names only": return "NAMES_ONLY"
        case "Not allowed": return "NOT_ALLOWED"
        default: return nil
        }
    }

    /// The visibility option label's `isPrivate`.
    static func isPrivate(_ label: String) -> Bool? {
        switch label {
        case "Private": return true
        case "Public": return false
        default: return nil
        }
    }

    /// Cancelled → nothing; 401 → sign-out; 404 → gone; anything else → retry.
    static func failure(for error: Error) -> FieldSaveFailure {
        if GroupActions.isCancellation(error) { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) { return .signOut }
        if let http = error as? APIHTTPError, http.status == 404 { return .gone }
        return .retry
    }

    /// A text-single page — title = label, no placeholder, no AI block (P11), focused on appear.
    static func single(title: String, description: String, text: String, saving: Bool,
                       errorMessage: String) -> EditTextSingleFieldScreen.State {
        var s = EditTextSingleFieldScreen.State(
            title: title, description: description, label: title, placeholder: "",
            text: text, loadedValue: text, focused: false, saving: saving,
            promptCopy: "", aiState: "prompt", suggestions: []
        )
        s.errorMessage = errorMessage
        s.showsAISuggestions = false
        s.editable = true
        s.focusOnAppear = true
        return s
    }

    /// A value: `.some(nil)` when empty, `.some(n)` for a whole number, nil when neither.
    private static func wholeNumber(_ text: String) -> Int?? {
        if text.isEmpty { return .some(nil) }
        guard let value = Int(text) else { return nil }
        return .some(value)
    }
}
