import XCTest
@testable import MakeReady

/// ui2-members-edit T8/D16: the edit pages' pure rules. The phone, contact-phone, email and
/// birthday tables mirror the server's (SPEC §Testing server / T2) row for row.
final class MemberFieldEditorTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Denver")!
        return c
    }()
    private let today = ISO8601DateFormatter().date(from: "2026-10-26T18:00:00Z")!   // Mon Oct 26, noon MDT

    private func tony() -> MemberDetail {
        MemberDetail(id: "m1", phoneNumber: "+15550100009", phoneVerified: true, firstName: "Tony", lastName: "Stark",
                     email: nil, googleEmail: "tony@gmail.example", gender: "male",
                     birthday: "1974-06-25T00:00:00.000Z", address: "10880 Malibu Point\nMalibu, CA",
                     emergencyContactName: "Pepper Potts", emergencyContactPhone: "555-123-4567 x2")
    }

    private func page(_ field: MemberField, _ d: MemberDetail, saving: Bool = false, error: String = "") -> MemberFieldPage {
        MemberFieldEditModel.page(field, detail: d, saving: saving, errorMessage: error, today: today, calendar: cal)
    }

    private func single(_ field: MemberField, _ d: MemberDetail) -> (EditTextSingleFieldScreen.State, ((String) -> Bool)?)? {
        if case let .textSingle(s, canSave) = page(field, d) { return (s, canSave) }
        return nil
    }

    // MARK: - D4 / D18 phone normalization (server T2 `normalizePhone` table)

    func testPhoneNormalizationMatchesTheServerTable() {
        // input                      server (D4/D18)          iPhone
        let rows: [(String, String?)] = [
            ("5551234567", "+15551234567"),            // 10 digits → +1
            ("(555) 123-4567", "+15551234567"),        // punctuation stripped
            ("555.123.4567", "+15551234567"),
            (" +1 555 123 4567 ", "+15551234567"),     // trimmed, spaces stripped
            ("15551234567", "+15551234567"),           // D18: 11 digits starting 1
            ("1-555-123-4567", "+15551234567"),        // D18
            ("+44 20 7946 0958", "+442079460958"),     // + kept
            ("+447700900123", "+447700900123"),
            ("555-1234", nil),                         // 400 "Enter a valid phone number"
            ("25551234567", nil),                      // 11 digits not starting 1 → 400
            ("+0123456789", nil),                      // E.164 forbids a leading 0
            ("+1234567890123456", nil),                // 16 digits → 400
            ("abc", nil),
            ("", nil)                                  // empty → 400
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.normalizePhone(input), expected, input)
        }
    }

    // MARK: - D7 emergency phone validity (server T2 `isValidContactPhone` table)

    func testContactPhoneValidityMatchesTheServerTable() {
        let rows: [(String, Bool)] = [
            ("555-123-4567", true),
            ("(555) 123-4567 ext. 89", true),
            ("555 1234 x12", true),
            ("555-1234 EXT 5", true),                  // extension word is case-insensitive
            ("+44 20 7946 0958", true),
            ("1234567", true),                         // 7 digits is enough
            ("123456", false),                         // 6 digits
            ("555-123", false),
            ("555-1234 ext", false),                   // an extension needs digits
            ("call me", false)
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.isValidContactPhone(input), expected, input)
        }
    }

    // MARK: - D11 email (zod `email()`)

    func testEmailValidityMatchesZod() {
        let rows: [(String, Bool)] = [
            ("a@b.com", true),
            ("first.last+tag@example.org", true),
            ("a@b", false),
            ("a..b@c.com", false),
            (".a@b.com", false),
            ("a@b.c", false)
        ]
        for (input, expected) in rows {
            XCTAssertEqual(MemberFieldRules.isValidEmail(input), expected, input)
        }
    }

    // MARK: - birthday-no-clear

    func testBirthdayPageHasNoClear() {
        guard case let .date(s) = page(.birthday, tony()) else { return XCTFail("birthday is the date page") }
        XCTAssertFalse(s.showsClear)                   // owner 2026-10-26, supersedes D8 for Birthday
    }

    // MARK: - D9 birthday

    func testBirthdayBoundsAndUTCCalendarDate() {
        XCTAssertFalse(MemberFieldRules.birthdayInRange(DateComponents(year: 1899, month: 12, day: 31), today: today, calendar: cal))
        XCTAssertTrue(MemberFieldRules.birthdayInRange(DateComponents(year: 1900, month: 1, day: 1), today: today, calendar: cal))
        XCTAssertTrue(MemberFieldRules.birthdayInRange(DateComponents(year: 2026, month: 10, day: 26), today: today, calendar: cal))
        XCTAssertFalse(MemberFieldRules.birthdayInRange(DateComponents(year: 2026, month: 10, day: 27), today: today, calendar: cal))
        // The stored UTC midnight is June 25 everywhere — never June 24 in Denver.
        XCTAssertEqual(MemberFieldRules.birthdayComponents("1974-06-25T00:00:00.000Z"), DateComponents(year: 1974, month: 6, day: 25))
        XCTAssertNil(MemberFieldRules.birthdayComponents(nil))
        XCTAssertNil(MemberFieldRules.birthdayComponents("garbage"))
        XCTAssertEqual(MemberFieldRules.isoDay(DateComponents(year: 1974, month: 6, day: 5)), "1974-06-05")
        XCTAssertNil(MemberFieldRules.isoDay(nil))
    }

    // MARK: - Page states (D3, D10, D11, D14, D22, D24)

    func testEmailPageLoadsTheRawEmailNeverTheGoogleFallback() {
        guard let email = single(.email, tony()) else { return XCTFail("email is a text-single page") }
        let (s, canSave) = email
        XCTAssertEqual(s.title, "Email address")
        XCTAssertEqual(s.label, "Email address")
        XCTAssertEqual(s.description, "The email address used to contact this member.")
        XCTAssertEqual(s.text, "")                     // D11: email nil → "", not googleEmail
        XCTAssertEqual(s.loadedValue, "")
        XCTAssertEqual(s.placeholder, "")
        XCTAssertTrue(s.allowsEmpty)                   // D8
        XCTAssertEqual(s.maxLength, 254)
        XCTAssertEqual(s.keyboard, .emailAddress)
        XCTAssertFalse(s.autocorrect)
        XCTAssertFalse(s.showsAISuggestions)           // D3
        XCTAssertTrue(s.editable)
        XCTAssertTrue(s.focusOnAppear)                 // D22
        XCTAssertNil(canSave)
    }

    func testPhonePagePrefillsTheLabelAndComparesNormalized() {
        guard let phone = single(.phone, tony()) else { return XCTFail("phone is a text-single page") }
        let (s, canSave) = phone
        XCTAssertEqual(s.title, "Phone number")
        XCTAssertEqual(s.description, "The number this member signs in with. Changing it marks it unverified until they sign in with the new number.")
        XCTAssertEqual(s.text, "(555) 010-0009")       // input-masking: the phone mask's national form
        XCTAssertEqual(s.mask, .phone)
        XCTAssertFalse(s.allowsEmpty)                  // D8: Phone can't be cleared
        XCTAssertEqual(s.maxLength, 20)
        XCTAssertEqual(s.keyboard, .phonePad)
        guard let canSave else { return XCTFail("D24: phone supplies canSave") }
        XCTAssertFalse(canSave("+1 (555) 010-0009"))   // same number → clean
        XCTAssertFalse(canSave("555.010.0009"))        // same number, another format → clean
        XCTAssertTrue(canSave("555 010 0001"))         // a different number → dirty
        XCTAssertTrue(canSave("555-01"))               // invalid → enabled; validate() explains
        XCTAssertFalse(canSave(""))                    // D8: empty disables Save
    }

    func testEmergencyPagesKeepTheValueAsTyped() {
        guard let phone = single(.emergencyPhone, tony())?.0 else { return XCTFail("emergency phone is text-single") }
        XCTAssertEqual(phone.title, "Emergency phone")
        // Owner 2026-10-26: the keypad on every phone input; extension entry dropped — a stored
        // extension is not shown on the edit page (the row still shows it until a save).
        XCTAssertEqual(phone.text, "(555) 123-4567")
        XCTAssertEqual(phone.maxLength, 40)
        XCTAssertEqual(phone.keyboard, .phonePad)
        XCTAssertEqual(phone.mask, .phone)
        XCTAssertTrue(phone.allowsEmpty)
        guard let name = single(.emergencyName, tony())?.0 else { return XCTFail("emergency contact is text-single") }
        XCTAssertEqual(name.title, "Emergency contact")
        XCTAssertEqual(name.description, "The person to contact if there is an emergency.")
        XCTAssertEqual(name.text, "Pepper Potts")
        XCTAssertEqual(name.maxLength, 200)
        XCTAssertEqual(name.keyboard, .default)
    }

    func testAddressIsTheMultiLinePage() {
        guard case let .textMulti(s) = page(.address, tony()) else { return XCTFail("address is text-multi") }
        XCTAssertEqual(s.title, "Address")
        XCTAssertEqual(s.description, "This member's mailing address.")
        XCTAssertEqual(s.text, "10880 Malibu Point\nMalibu, CA")
        XCTAssertEqual(s.maxLength, 2000)
        XCTAssertFalse(s.showsAISuggestions)
        XCTAssertTrue(s.editable)
    }

    func testGenderOptionsAndUnknownValuesStartAtNotSet() {
        guard case let .option(s) = page(.gender, tony()) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(s.title, "Gender")
        XCTAssertEqual(s.description, "Helps leaders place this member in the right groups.")
        XCTAssertEqual(s.options, ["Male", "Female", "Not set"])
        XCTAssertEqual(s.optionDescriptions, [])       // D10: title-only rows
        XCTAssertEqual(s.selectedOption, "Male")
        XCTAssertEqual(s.loadedValue, "Male")
        var d = tony()
        d.gender = nil
        guard case let .option(unset) = page(.gender, d) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(unset.selectedOption, "Not set")
        d.gender = "nonbinary"
        guard case let .option(other) = page(.gender, d) else { return XCTFail("gender is the option page") }
        XCTAssertEqual(other.selectedOption, "Not set")
        XCTAssertEqual(other.loadedValue, "Not set")   // the page starts clean
    }

    func testBirthdayPageShowsTheStoredDayAndToday() {
        guard case let .date(s) = page(.birthday, tony(), saving: true, error: "x") else { return XCTFail("birthday is the date page") }
        XCTAssertEqual(s.title, "Birthday")
        XCTAssertEqual(s.description, "Used to show this member's age to group leaders.")
        XCTAssertEqual(s.loadedValue, DateComponents(year: 1974, month: 6, day: 25))
        XCTAssertEqual(s.selectedValue, s.loadedValue)
        XCTAssertEqual(s.maxDate, today)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: s.minDate).year, 1900)
        XCTAssertTrue(s.saving)
        XCTAssertEqual(s.errorMessage, "x")
    }

    func testSavingAndErrorReachTheTextPages() {
        guard case let .textSingle(s, _) = page(.email, tony(), saving: true, error: "Enter a valid email") else {
            return XCTFail("email is text-single")
        }
        XCTAssertTrue(s.saving)
        XCTAssertEqual(s.errorMessage, "Enter a valid email")
    }

    // MARK: - D16 validation, D15 patch, D13 copy

    func testValidationMessagesMatchTheServer() {
        XCTAssertNil(MemberFieldEditModel.validate(.email, .text(""), today: today, calendar: cal))           // clears
        XCTAssertNil(MemberFieldEditModel.validate(.email, .text(" a@b.com "), today: today, calendar: cal))  // trim first
        XCTAssertEqual(MemberFieldEditModel.validate(.email, .text("a@b"), today: today, calendar: cal), "Enter a valid email")
        XCTAssertEqual(MemberFieldEditModel.validate(.phone, .text("555-01"), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertEqual(MemberFieldEditModel.validate(.phone, .text(""), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertNil(MemberFieldEditModel.validate(.phone, .text("(555) 010-0001"), today: today, calendar: cal))
        XCTAssertNil(MemberFieldEditModel.validate(.emergencyPhone, .text(""), today: today, calendar: cal))
        XCTAssertEqual(MemberFieldEditModel.validate(.emergencyPhone, .text("12"), today: today, calendar: cal), "Enter a valid phone number")
        XCTAssertNil(MemberFieldEditModel.validate(.birthday, .date(nil), today: today, calendar: cal))
        XCTAssertEqual(MemberFieldEditModel.validate(.birthday, .date(DateComponents(year: 2026, month: 10, day: 27)), today: today, calendar: cal),
                       "Birthday must be between 1900 and today")
        XCTAssertNil(MemberFieldEditModel.validate(.address, .text(""), today: today, calendar: cal))
        XCTAssertNil(MemberFieldEditModel.validate(.gender, .option("Not set"), today: today, calendar: cal))
    }

    /// `MemberField` ↔ PATCH key, and each field's wire value.
    func testPatchSendsTheFieldsWireKeyAndValue() {
        XCTAssertEqual(MemberFieldEditModel.patch(.email, .text(" a@b.com ")), .email("a@b.com"))
        XCTAssertEqual(MemberFieldEditModel.patch(.email, .text("")), .email(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.phone, .text("(555) 010-0001")), .phoneNumber("+15550100001"))
        XCTAssertEqual(MemberFieldEditModel.patch(.birthday, .date(DateComponents(year: 1974, month: 6, day: 25))), .birthday("1974-06-25"))
        XCTAssertEqual(MemberFieldEditModel.patch(.birthday, .date(nil)), .birthday(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Male")), .gender("male"))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Female")), .gender("female"))
        XCTAssertEqual(MemberFieldEditModel.patch(.gender, .option("Not set")), .gender(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.address, .text("")), .address(nil))
        XCTAssertEqual(MemberFieldEditModel.patch(.emergencyName, .text("Pepper")), .emergencyContactName("Pepper"))
        XCTAssertEqual(MemberFieldEditModel.patch(.emergencyPhone, .text("555-1234 x2")), .emergencyContactPhone("555-1234 x2"))
        let keys = MemberField.allCases.map { MemberFieldEditModel.patch($0, .text("")).key }
        XCTAssertEqual(keys, ["email", "phoneNumber", "birthday", "gender", "address", "emergencyContactName", "emergencyContactPhone"])
    }

    func testSaveErrorCopy() {
        XCTAssertEqual(MemberFieldEditModel.message(for: .validation("That number belongs to another member")),
                       "That number belongs to another member")
        XCTAssertEqual(MemberFieldEditModel.message(for: .generic), "Couldn't save. Try again.")
    }
}
