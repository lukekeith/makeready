import Foundation
import SwiftUI

/// ui2-members-edit D4/D7/D9/D11/D18: the member-field rules, identical to the server's
/// `services/member-fields.ts` so the iPhone shows the same message without a request (D16).
/// ASCII digits only (`[0-9]`, never ICU's Unicode `\d`), to match JavaScript's `\d`.
enum MemberFieldRules {
    static let phoneMessage = "Enter a valid phone number"
    static let emailMessage = "Enter a valid email"
    static let birthdayMessage = "Birthday must be between 1900 and today"

    private static let e164 = #"^\+[1-9][0-9]{1,14}$"#
    /// D7, the literal server regex with the pre-extension part captured.
    private static let contactPhone = #"^([0-9\s().+-]+)(?:\s*(?:ext\.?|x)\s*[0-9]+)?$"#
    /// zod 3.23 `z.string().email()`.
    private static let email = #"^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$"#
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current

    /// D4 / D18: strip spaces, `-`, `.`, `(`, `)`; 10 digits → `+1…`; 11 digits starting `1` →
    /// `+…`; a leading `+` is kept; the result must be E.164. nil = invalid (400).
    static func normalizePhone(_ raw: String) -> String? {
        let stripped = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace && !"-.()".contains($0) }
        let candidate: String
        if stripped.hasPrefix("+") {
            candidate = stripped
        } else if stripped.count == 10, isDigits(stripped) {
            candidate = "+1" + stripped
        } else if stripped.count == 11, stripped.hasPrefix("1"), isDigits(stripped) {
            candidate = "+" + stripped
        } else {
            candidate = stripped
        }
        return candidate.range(of: e164, options: .regularExpression) != nil ? candidate : nil
    }

    /// D7: digits and separators, an optional `ext`/`x` extension, ≥7 digits before it.
    static func isValidContactPhone(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: contactPhone, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let main = Range(match.range(at: 1), in: s) else { return false }
        return s[main].filter { ("0"..."9").contains($0) }.count >= 7
    }

    /// D11: the trimmed value passes zod's `email()`.
    static func isValidEmail(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.range(of: email, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// D9: 1900-01-01 … today in the device calendar, compared as calendar days.
    static func birthdayInRange(_ day: DateComponents, today: Date, calendar: Calendar) -> Bool {
        guard let y = day.year, let m = day.month, let d = day.day else { return false }
        let t = calendar.dateComponents([.year, .month, .day], from: today)
        guard let ty = t.year, let tm = t.month, let td = t.day else { return false }
        return (y, m, d) >= (1900, 1, 1) && (y, m, d) <= (ty, tm, td)
    }

    /// D9: the wheel's range — 1900-01-01 local … today.
    static func birthdayBounds(today: Date, calendar: Calendar) -> (min: Date, max: Date) {
        (calendar.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast, today)
    }

    /// D9: the stored UTC calendar date as calendar-free components — the wheel shows them as a
    /// LOCAL date, never the UTC instant (which lands a day early west of UTC).
    static func birthdayComponents(_ iso: String?) -> DateComponents? {
        guard let iso, let date = MembersHomeMapper.parseDate(iso) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return DateComponents(year: y, month: m, day: d)
    }

    /// D9: the local day the iPhone sends — `YYYY-MM-DD`.
    static func isoDay(_ day: DateComponents?) -> String? {
        guard let y = day?.year, let m = day?.month, let d = day?.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private static func isDigits(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { ("0"..."9").contains($0) }
    }
}

/// What an edit page hands back on Save.
enum MemberFieldInput {
    /// A text page's trimmed text.
    case text(String)
    /// The option page's selected title.
    case option(String)
    /// The date page's day, nil = cleared.
    case date(DateComponents?)

    fileprivate var trimmedText: String {
        switch self {
        case .text(let s), .option(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date: return ""
        }
    }

    fileprivate var day: DateComponents? {
        if case .date(let d) = self { return d }
        return nil
    }
}

/// D3: the one built screen a field opens, with its State.
enum MemberFieldPage {
    case textSingle(EditTextSingleFieldScreen.State, canSave: ((String) -> Bool)?)
    case textMulti(EditTextMultiFieldScreen.State)
    case option(EditOptionFieldScreen.State)
    case date(EditDateFieldScreen.State)
}

/// ui2-members-edit §iphone Edit container: each field's screen State from the loaded member,
/// the D16 checks and the one-key patch. Pure — `MemberFieldEditContainer` renders and saves.
enum MemberFieldEditModel {
    /// D10: top → bottom; stored `male` / `female` / null.
    static let genderOptions = ["Male", "Female", "Not set"]
    private static let notSet = "Not set"

    /// D14: each page's description, verbatim.
    static func description(_ field: MemberField) -> String {
        switch field {
        case .email: return "The email address used to contact this member."
        case .phone: return "The number this member signs in with. Changing it marks it unverified until they sign in with the new number."
        case .birthday: return "Used to show this member's age to group leaders."
        case .gender: return "Helps leaders place this member in the right groups."
        case .address: return "This member's mailing address."
        case .emergencyName: return "The person to contact if there is an emergency."
        case .emergencyPhone: return "The number to call for this member's emergency contact."
        }
    }

    /// D3 arrangement + D10/D11/D14/D22/D24 per field, from the loaded detail (D27).
    static func page(
        _ field: MemberField,
        detail: MemberDetail,
        saving: Bool,
        errorMessage: String,
        today: Date,
        calendar: Calendar
    ) -> MemberFieldPage {
        let title = MembersProfileScreen.label(for: field)
        switch field {
        case .email:
            return .textSingle(single(field, text: detail.email ?? "", saving: saving, errorMessage: errorMessage), canSave: nil)
        case .phone:
            let stored = detail.phoneNumber
            // input-masking: the stored +1 number shows nationally, formatted by the phone mask.
            return .textSingle(
                single(field, text: InputMask.phone.format(InputMask.phone.raw(stored)), saving: saving, errorMessage: errorMessage),
                canSave: { phoneCanSave($0, stored: stored) }
            )
        case .emergencyName:
            return .textSingle(single(field, text: detail.emergencyContactName ?? "", saving: saving, errorMessage: errorMessage), canSave: nil)
        case .emergencyPhone:
            // input-masking: stored as typed; shown in the contact-phone mask's form.
            let stored = detail.emergencyContactPhone ?? ""
            let shown = stored.isEmpty ? "" : InputMask.phone.format(InputMask.phone.raw(stored))
            return .textSingle(single(field, text: shown, saving: saving, errorMessage: errorMessage), canSave: nil)
        case .address:
            var s = EditTextMultiFieldScreen.State(
                title: title, description: description(field), label: title, placeholder: "",
                text: detail.address ?? "", loadedValue: detail.address ?? "", focused: false, saving: saving,
                promptCopy: "", aiState: "prompt", suggestions: []
            )
            s.maxLength = 2000
            s.errorMessage = errorMessage
            s.showsAISuggestions = false
            s.editable = true
            s.focusOnAppear = true
            s.textContentType = .fullStreetAddress
            return .textMulti(s)
        case .gender:
            let selected = genderLabel(detail.gender)
            return .option(EditOptionFieldScreen.State(
                title: title, description: description(field),
                options: genderOptions, optionDescriptions: [],
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .birthday:
            let day = MemberFieldRules.birthdayComponents(detail.birthday)
            let bounds = MemberFieldRules.birthdayBounds(today: today, calendar: calendar)
            var s = EditDateFieldScreen.State(
                title: title, description: description(field),
                loadedValue: day, selectedValue: day,
                minDate: bounds.min, maxDate: bounds.max,
                saving: saving, errorMessage: errorMessage
            )
            // birthday-no-clear (owner 2026-10-26, supersedes ui2-members-edit D8 for Birthday):
            // a birthday can be changed, not removed.
            s.showsClear = false
            return .date(s)
        }
    }

    /// D24 + D8: Save is enabled when the typed number normalizes to something other than the
    /// stored one (an invalid number counts as different — `validate` explains it); empty never.
    static func phoneCanSave(_ typed: String, stored: String) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && MemberFieldRules.normalizePhone(trimmed) != stored
    }

    /// D16: the server's message for an input it would reject, else nil.
    static func validate(_ field: MemberField, _ input: MemberFieldInput, today: Date, calendar: Calendar) -> String? {
        let text = input.trimmedText
        switch field {
        case .email:
            return text.isEmpty || MemberFieldRules.isValidEmail(text) ? nil : MemberFieldRules.emailMessage
        case .phone:
            return MemberFieldRules.normalizePhone(text) == nil ? MemberFieldRules.phoneMessage : nil
        case .emergencyPhone:
            return text.isEmpty || MemberFieldRules.isValidContactPhone(text) ? nil : MemberFieldRules.phoneMessage
        case .birthday:
            guard let day = input.day else { return nil }
            return MemberFieldRules.birthdayInRange(day, today: today, calendar: calendar) ? nil : MemberFieldRules.birthdayMessage
        case .gender, .address, .emergencyName:
            return nil
        }
    }

    /// D15: the one key and its wire value; "" / "Not set" / a cleared date → nil (D8).
    static func patch(_ field: MemberField, _ input: MemberFieldInput) -> MemberPatch {
        let text = input.trimmedText
        let orNil: String? = text.isEmpty ? nil : text
        switch field {
        case .email: return .email(orNil)
        case .phone: return .phoneNumber(MemberFieldRules.normalizePhone(text) ?? text)
        case .birthday: return .birthday(MemberFieldRules.isoDay(input.day))
        case .gender:
            switch text {
            case "Male": return .gender("male")
            case "Female": return .gender("female")
            default: return .gender(nil)
            }
        case .address: return .address(orNil)
        case .emergencyName: return .emergencyContactName(orNil)
        case .emergencyPhone: return .emergencyContactPhone(orNil)
        }
    }

    /// D13: the inline error line for a failed save.
    static func message(for error: MemberSaveError) -> String {
        switch error {
        case .validation(let message): return message
        case .generic: return MemberActions.saveFailedMessage
        }
    }

    // MARK: - Helpers

    /// D10: "Not set" for null or any value other than male/female, so the page starts clean.
    private static func genderLabel(_ stored: String?) -> String {
        switch stored {
        case "male": return "Male"
        case "female": return "Female"
        default: return notSet
        }
    }

    /// D3/D14/D22: a member text-single page — title = label, no placeholder, no AI block, a live
    /// field focused on appear, the field's keyboard, caps and cap.
    private static func single(_ field: MemberField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        let title = MembersProfileScreen.label(for: field)
        var s = EditTextSingleFieldScreen.State(
            title: title, description: description(field), label: title, placeholder: "",
            text: text, loadedValue: text, focused: false, saving: saving,
            promptCopy: "", aiState: "prompt", suggestions: []
        )
        s.errorMessage = errorMessage
        s.showsAISuggestions = false
        s.editable = true
        s.focusOnAppear = true
        s.allowsEmpty = field != .phone                                  // D8
        switch field {
        case .email:
            s.keyboard = .emailAddress
            s.textContentType = .emailAddress
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 254
        case .phone:
            s.keyboard = .phonePad
            s.textContentType = .telephoneNumber
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 20
            s.mask = .phone                       // input-masking B3
        case .emergencyPhone:
            // Owner 2026-10-26: every phone input opens the number keypad — supersedes D22's
            // numbersAndPunctuation; extension entry is dropped (a stored one shows until edited).
            s.keyboard = .phonePad
            s.textContentType = .telephoneNumber
            s.autocapitalization = .never
            s.autocorrect = false
            s.maxLength = 40
            s.mask = .phone
        case .emergencyName, .birthday, .gender, .address:
            s.keyboard = .default
            s.textContentType = .name
            s.autocapitalization = .words
            s.maxLength = 200
        }
        return s
    }
}
