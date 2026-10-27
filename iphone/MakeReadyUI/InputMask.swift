import Foundation

/// input-masking: a format-as-you-type mask for C-045 TextInput's live field.
///
/// Display only (input-masking B2): the field shows `format(raw)`; the page saves `raw(text)` and
/// keeps its own save rules, so nothing stored changes. A pattern mask is a string where `#` is a
/// digit, `A` a letter and any other character a literal (B4); literals are drawn only once a
/// character follows them, so the field never ends in a dangling separator.
// GAP — C-045 §4: no `mask` prop in the contract; the owner files it via /ui2-component-update
// C-045 (input-masking B7).
struct InputMask: Sendable, Equatable {
    private enum Kind: Equatable {
        /// Candidate patterns, shortest first; the first whose slots fit the raw value is used.
        case pattern([String])
        /// No `+` → US `(###) ###-####`; a leading `+` → international grouping (B3).
        case phone(allowsExtension: Bool)
    }

    private let kind: Kind

    /// A pattern mask — `#` digit, `A` letter, anything else literal. Several patterns pick the
    /// shortest that holds the value (`#####`, `#####-####`).
    static func pattern(_ patterns: String...) -> InputMask {
        InputMask(kind: .pattern(patterns.sorted { slotCount($0) < slotCount($1) }))
    }

    /// B4 presets.
    static let ssn = pattern("###-##-####")
    static let zip = pattern("#####", "#####-####")
    /// B3: a member's sign-in phone — US by default, a leading `+` switches to international.
    static let phone = InputMask(kind: .phone(allowsExtension: false))
    /// B3: the emergency contact phone — as `phone`, plus a trailing ` x123` extension.
    static let contactPhone = InputMask(kind: .phone(allowsExtension: true))

    // MARK: - Raw ⇄ formatted

    /// What the page saves: the value's own characters, without the mask's literals.
    func raw(_ text: String) -> String {
        switch kind {
        case .pattern(let patterns):
            // The longest pattern's slots, filled in order; characters that fit no slot drop.
            let longest = patterns.max { Self.slotCount($0) < Self.slotCount($1) } ?? ""
            return Self.apply(longest.filter { $0 == "#" || $0 == "A" }, to: text)
        case .phone(let allowsExtension):
            return Self.phoneParts(text, allowsExtension: allowsExtension).raw
        }
    }

    /// What the field shows for a raw value.
    func format(_ raw: String) -> String {
        switch kind {
        case .pattern(let patterns):
            let value = self.raw(raw)
            let pattern = patterns.first { Self.slotCount($0) >= value.count } ?? patterns.last ?? ""
            return Self.apply(pattern, to: value)
        case .phone(let allowsExtension):
            let parts = Self.phoneParts(raw, allowsExtension: allowsExtension)
            let main = parts.international
                ? Self.internationalGrouping(parts.digits)
                : Self.usGrouping(parts.digits)
            guard let ext = parts.extensionDigits else { return main }
            return main + " x" + ext
        }
    }

    /// A keystroke, paste or deletion: the text the field shows next. A deletion that removed
    /// only a literal (the raw value is unchanged) removes the character before it instead, so
    /// backspace never appears to do nothing.
    func edited(old: String, new: String) -> String {
        var value = raw(new)
        if new.count < old.count, value == raw(old), !value.isEmpty {
            if value.hasSuffix(" x") {
                value.removeLast(2)
            } else {
                value.removeLast()
            }
        }
        return format(value)
    }

    /// The UIKit-delegate edit (input-masking, the iOS best practice): replace `range` (UTF-16,
    /// as `textField(_:shouldChangeCharactersIn:replacementString:)` reports it) of `text` with
    /// `replacement`, and return the text to show and the caret's UTF-16 offset in it. The field
    /// never draws the raw keystroke, so nothing flickers.
    /// - A keystroke that adds nothing — the mask is full, or the character fits no slot — leaves
    ///   the text and caret exactly as they were.
    /// - Backspace over a literal deletes the character before it.
    /// - The caret keeps its place among the value's own characters across the reformat.
    func applyEdit(to text: String, range: NSRange, replacement: String) -> (text: String, caret: Int) {
        let ns = text as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= ns.length else {
            return (text, ns.length)
        }
        let oldRaw = raw(text)
        var proposed = ns.replacingCharacters(in: range, with: replacement)
        var caretKey = Self.significantCount(in: (proposed as NSString).substring(to: range.location + (replacement as NSString).length))
        if !replacement.isEmpty, range.length == 0, raw(proposed).count <= oldRaw.count {
            return (text, range.location)                     // full, or nothing that fits
        }
        if replacement.isEmpty, raw(proposed) == oldRaw {
            // Only literals were deleted: take the value character before them instead.
            var before = ns.substring(to: range.location)
            if let index = before.lastIndex(where: Self.isSignificant) {
                before.remove(at: index)
                proposed = before + ns.substring(from: NSMaxRange(range))
                caretKey = Self.significantCount(in: before)
            }
        }
        let formatted = format(raw(proposed))
        return (formatted, Self.offset(in: formatted, afterSignificant: caretKey))
    }

    private static func isSignificant(_ c: Character) -> Bool {
        c.isASCIIDigit || c.isLetter || c == "+"
    }

    private static func significantCount(in s: String) -> Int {
        s.filter(isSignificant).count
    }

    /// The UTF-16 offset just after the `count`-th value character of `formatted` (its end when
    /// it holds fewer).
    private static func offset(in formatted: String, afterSignificant count: Int) -> Int {
        guard count > 0 else {
            // Before any value character: after a leading literal run such as "(" — keep 0.
            return 0
        }
        var seen = 0
        var utf16 = 0
        for c in formatted {
            utf16 += c.utf16.count
            if isSignificant(c) {
                seen += 1
                if seen == count { return utf16 }
            }
        }
        return (formatted as NSString).length
    }

    // MARK: - Pattern helpers

    private static func slotCount(_ pattern: String) -> Int {
        pattern.filter { $0 == "#" || $0 == "A" }.count
    }

    private static func apply(_ pattern: String, to value: String) -> String {
        var out = ""
        var chars = value[...]
        for slot in pattern {
            // A literal is drawn only when a character follows it.
            guard !chars.isEmpty else { break }
            switch slot {
            case "#":
                // Skip characters that do not fit a digit slot.
                guard let digit = chars.firstIndex(where: \.isASCIIDigit) else { return out }
                out.append(chars[digit])
                chars = chars[chars.index(after: digit)...]
            case "A":
                guard let letter = chars.firstIndex(where: \.isLetter) else { return out }
                out.append(chars[letter])
                chars = chars[chars.index(after: letter)...]
            default:
                out.append(slot)
            }
        }
        return out
    }

    // MARK: - Phone helpers

    private struct PhoneParts {
        var international: Bool
        var digits: String
        var extensionDigits: String?

        var raw: String {
            (international ? "+" : "") + digits + (extensionDigits.map { " x" + $0 } ?? "")
        }
    }

    /// E.164's 15-digit ceiling; a US number is 10 digits.
    private static let internationalMax = 15
    private static let usMax = 10

    private static func phoneParts(_ text: String, allowsExtension: Bool) -> PhoneParts {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        // The extension starts at the first "x" (also "ext", "ext.").
        var mainPart = Substring(trimmed)
        var extPart: Substring?
        if let x = trimmed.firstIndex(where: { $0 == "x" || $0 == "X" || $0 == "e" || $0 == "E" }) {
            mainPart = trimmed[..<x]
            extPart = trimmed[x...]
        }
        var international = mainPart.first == "+"
        var digits = mainPart.filter(\.isASCIIDigit)
        // A stored US number (+1 and 10 digits) shows nationally.
        if international, digits.count == 11, digits.hasPrefix("1") {
            international = false
            digits.removeFirst()
        }
        digits = String(digits.prefix(international ? internationalMax : usMax))
        let ext = allowsExtension && !digits.isEmpty ? extPart.map { String($0.filter(\.isASCIIDigit)) } : nil
        return PhoneParts(international: international, digits: digits, extensionDigits: ext)
    }

    /// `(555) 123-4567`, drawn as far as the digits go.
    private static func usGrouping(_ d: String) -> String {
        let c = Array(d)
        switch c.count {
        case 0: return ""
        case 1...3: return "(" + String(c)
        case 4...6: return "(" + String(c[0..<3]) + ") " + String(c[3...])
        default: return "(" + String(c[0..<3]) + ") " + String(c[3..<6]) + "-" + String(c[6...])
        }
    }

    /// `+44 207 946 0958`: a country code (1 digit for +1/+7, else 2), then groups of three with
    /// the last group holding up to four.
    private static func internationalGrouping(_ d: String) -> String {
        guard !d.isEmpty else { return "+" }
        let ccLength = d.hasPrefix("1") || d.hasPrefix("7") ? 1 : 2
        var rest = Array(d.dropFirst(min(ccLength, d.count)))
        var groups = [String(d.prefix(ccLength))]
        while rest.count > 4 {
            groups.append(String(rest.prefix(3)))
            rest.removeFirst(3)
        }
        if !rest.isEmpty { groups.append(String(rest)) }
        return "+" + groups.joined(separator: " ")
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
