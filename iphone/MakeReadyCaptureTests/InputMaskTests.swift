import XCTest
@testable import MakeReady

/// input-masking: the C-045 mask engine — display formatting only; `raw` is what a page saves.
final class InputMaskTests: XCTestCase {
    // MARK: Pattern masks

    func testSSNFormatsAsTyped() {
        let m = InputMask.ssn
        XCTAssertEqual(m.format("1"), "1")
        XCTAssertEqual(m.format("123"), "123")
        XCTAssertEqual(m.format("1234"), "123-4")
        XCTAssertEqual(m.format("123456789"), "123-45-6789")
        XCTAssertEqual(m.format("1234567890"), "123-45-6789", "extra digits are dropped")
    }

    func testPatternRawKeepsOnlySlotCharacters() {
        XCTAssertEqual(InputMask.ssn.raw("123-45-6789"), "123456789")
        XCTAssertEqual(InputMask.ssn.raw("12a3"), "123")
    }

    func testZipPicksTheShortestPatternThatFits() {
        XCTAssertEqual(InputMask.zip.format("12345"), "12345")
        XCTAssertEqual(InputMask.zip.format("123456"), "12345-6")
        XCTAssertEqual(InputMask.zip.format("123456789"), "12345-6789")
    }

    func testLetterSlots() {
        let m = InputMask.pattern("AA-##")
        XCTAssertEqual(m.format("ab12"), "ab-12")
        XCTAssertEqual(m.raw("ab-12"), "ab12")
    }

    // MARK: Phone

    func testUSPhoneFormatsAsTyped() {
        let m = InputMask.phone
        XCTAssertEqual(m.format("5"), "(5")
        XCTAssertEqual(m.format("555"), "(555")
        XCTAssertEqual(m.format("5551"), "(555) 1")
        XCTAssertEqual(m.format("5551234"), "(555) 123-4")
        XCTAssertEqual(m.format("5551234567"), "(555) 123-4567")
        XCTAssertEqual(m.format("55512345678"), "(555) 123-4567", "a US number caps at 10 digits")
    }

    func testStoredUSNumberShowsNationally() {
        XCTAssertEqual(InputMask.phone.raw("+15551234567"), "5551234567")
        XCTAssertEqual(InputMask.phone.format(InputMask.phone.raw("+1 (555) 123-4567")), "(555) 123-4567")
    }

    func testLeadingPlusSwitchesToInternational() {
        let m = InputMask.phone
        XCTAssertEqual(m.raw("+44 20 7946 0958"), "+442079460958")
        XCTAssertEqual(m.format("+44"), "+44")
        XCTAssertEqual(m.format("+442079460958"), "+44 207 946 0958")
        XCTAssertEqual(m.format("+" + String(repeating: "1", count: 20)).filter(\.isNumber).count, 15, "E.164 caps at 15")
    }

    func testExtensionOnlyWhereAllowed() {
        XCTAssertEqual(InputMask.contactPhone.raw("(555) 123-4567 x12"), "5551234567 x12")
        XCTAssertEqual(InputMask.contactPhone.raw("555 123 4567 ext 9"), "5551234567 x9")
        XCTAssertEqual(InputMask.contactPhone.format("5551234567 x12"), "(555) 123-4567 x12")
        XCTAssertEqual(InputMask.contactPhone.format("5551234567 x"), "(555) 123-4567 x")
        XCTAssertEqual(InputMask.phone.raw("(555) 123-4567 x12"), "5551234567", "Phone takes no extension")
    }

    // MARK: Editing

    func testTypingReformats() {
        XCTAssertEqual(InputMask.phone.edited(old: "(555) 123-456", new: "(555) 123-4567"), "(555) 123-4567")
        XCTAssertEqual(InputMask.phone.edited(old: "(555", new: "(5551"), "(555) 1")
    }

    func testBackspaceOverALiteralDeletesADigit() {
        // Deleting the ")" or "-" alone would leave the digits unchanged — the digit before it goes.
        XCTAssertEqual(InputMask.phone.edited(old: "(555) 123-4", new: "(555) 123-"), "(555) 123")
        XCTAssertEqual(InputMask.phone.edited(old: "(555) 1", new: "(555) "), "(555")
        XCTAssertEqual(InputMask.ssn.edited(old: "123-4", new: "123-"), "123")
    }

    func testBackspaceRemovesAnEmptyExtension() {
        XCTAssertEqual(InputMask.contactPhone.edited(old: "(555) 123-4567 x", new: "(555) 123-4567 "), "(555) 123-4567")
    }

    func testPasteReformats() {
        XCTAssertEqual(InputMask.phone.edited(old: "", new: "555.123.4567"), "(555) 123-4567")
        XCTAssertEqual(InputMask.ssn.edited(old: "", new: "123 45 6789"), "123-45-6789")
    }

    // MARK: Delegate edits (the field never draws the raw keystroke)

    private func type(_ c: String, into text: String, at location: Int? = nil, mask: InputMask = .phone) -> (text: String, caret: Int) {
        let at = location ?? (text as NSString).length
        return mask.applyEdit(to: text, range: NSRange(location: at, length: 0), replacement: c)
    }

    private func backspace(_ text: String, mask: InputMask = .phone) -> (text: String, caret: Int) {
        let n = (text as NSString).length
        return mask.applyEdit(to: text, range: NSRange(location: n - 1, length: 1), replacement: "")
    }

    func testTypingPastAFullMaskChangesNothing() {
        let full = "(555) 123-4567"
        for _ in 0..<5 {
            let r = type("8", into: full)
            XCTAssertEqual(r.text, full)
            XCTAssertEqual(r.caret, (full as NSString).length)
        }
    }

    func testTypingBuildsTheFormatWithTheCaretAtTheEnd() {
        var t = ""
        for d in "5551234567" {
            let r = type(String(d), into: t)
            t = r.text
            XCTAssertEqual(r.caret, (t as NSString).length)
        }
        XCTAssertEqual(t, "(555) 123-4567")
    }

    func testBackspaceAtEndDeletesDigitsThroughLiterals() {
        XCTAssertEqual(backspace("(555) 123-4").text, "(555) 123")
        XCTAssertEqual(backspace("(555) 1").text, "(555")
        XCTAssertEqual(backspace("(5").text, "")
        XCTAssertEqual(backspace("123-4", mask: .ssn).text, "123")
    }

    func testMidNumberEditKeepsTheCaretInPlace() {
        // Delete the "2" in "(555) 123-4567": caret lands after "1".
        let r = InputMask.phone.applyEdit(to: "(555) 123-4567", range: NSRange(location: 7, length: 1), replacement: "")
        XCTAssertEqual(r.text, "(555) 134-567")
        XCTAssertEqual(r.caret, 7)
        // Insert "9" after "(555) 1" in a 9-digit number: caret after the 9.
        let i = InputMask.phone.applyEdit(to: "(555) 134-567", range: NSRange(location: 7, length: 0), replacement: "9")
        XCTAssertEqual(i.text, "(555) 193-4567")
        XCTAssertEqual(i.caret, 8)
    }

    func testDelegatePasteAndExtension() {
        XCTAssertEqual(type("555.123.4567", into: "").text, "(555) 123-4567")
        XCTAssertEqual(type("x", into: "(555) 123-4567", mask: .contactPhone).text, "(555) 123-4567 x")
        XCTAssertEqual(type("1", into: "(555) 123-4567 x", mask: .contactPhone).text, "(555) 123-4567 x1")
        XCTAssertEqual(backspace("(555) 123-4567 x", mask: .contactPhone).text, "(555) 123-4567")
    }
}
