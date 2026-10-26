import SwiftUI

/// dashboard-chart-intros D14: a value string split around its leading number. The prefix is
/// whatever precedes the first digit, the suffix whatever follows the number — both kept verbatim.
struct CountUpFormat: Equatable {
    let source: String
    let prefix: String
    let number: Double
    let decimals: Int
    let grouped: Bool
    let suffix: String

    /// nil when the string holds no number — the caller fades it in instead (D14).
    static func parse(_ text: String) -> CountUpFormat? {
        let chars = Array(text)
        guard let start = chars.firstIndex(where: isDigit) else { return nil }
        var index = start
        var digits = ""
        var grouped = false
        while index < chars.count {
            if isDigit(chars[index]) {
                digits.append(chars[index])
                index += 1
            } else if chars[index] == ",", isGroup(chars, at: index + 1) {
                grouped = true
                index += 1
            } else {
                break
            }
        }
        var decimals = 0
        if index + 1 < chars.count, chars[index] == ".", isDigit(chars[index + 1]) {
            digits.append(".")
            index += 1
            while index < chars.count, isDigit(chars[index]) {
                digits.append(chars[index])
                decimals += 1
                index += 1
            }
        }
        guard let number = Double(digits) else { return nil }
        return CountUpFormat(
            source: text,
            prefix: String(chars[..<start]),
            number: number,
            decimals: decimals,
            grouped: grouped,
            suffix: String(chars[index...])
        )
    }

    /// The string at `value` — exactly `source` at the parsed number.
    func render(_ value: Double) -> String {
        guard value != number else { return source }
        let style = FloatingPointFormatStyle<Double>.number
            .precision(.fractionLength(decimals))
            .grouping(grouped ? .automatic : .never)
            .locale(Locale(identifier: "en_US"))  // "," grouping, "." decimals — the dashboard's strings
        return prefix + value.formatted(style) + suffix
    }

    private static func isDigit(_ char: Character) -> Bool { char.isASCII && char.isNumber }

    /// A grouping comma is followed by exactly three digits.
    private static func isGroup(_ chars: [Character], at start: Int) -> Bool {
        guard start + 3 <= chars.count, chars[start..<start + 3].allSatisfy(isDigit) else { return false }
        return start + 3 == chars.count || !isDigit(chars[start + 3])
    }
}

/// D14: a value string whose number counts up from 0 when its intro plays and moves old → new
/// when it changes after (D9). A string with no number fades in instead. Style it like a Text —
/// `designTextStyle` and `foregroundColor` are View modifiers.
struct CountUpText: View {
    let text: String
    let intro: ChartIntro?
    var after: Double = 0

    var body: some View {
        let format = CountUpFormat.parse(text)
        CountUpLabel(text: text, shown: Self.shown(format, intro: intro))
            .animation(intro?.animation(ChartIntroMotion.countUp, after: after), value: intro?.played)
            .chartIntroMorph(intro, value: text)
            .chartIntroFade(intro, fadeOnly: format == nil)
    }

    /// The number shown before animation: the final value with no intro or once played.
    static func shown(_ format: CountUpFormat?, intro: ChartIntro?) -> Double {
        guard let format else { return 0 }
        return format.number * (intro?.progress(fadeOnly: false) ?? 1)
    }
}

/// Interpolates `shown` frame by frame — `.contentTransition(.numericText())` alone animates the
/// glyph swap, not the values in between (audit F6).
private struct CountUpLabel: View, Animatable {
    let text: String
    var shown: Double

    var animatableData: Double {
        get { shown }
        set { shown = newValue }
    }

    var body: some View {
        Text(CountUpFormat.parse(text)?.render(shown) ?? text)
    }
}

/// D14 for a view that takes an Int (C-031's PercentDisc): `content` is rebuilt with the
/// interpolated value every frame.
struct CountUpNumber<Content: View>: View, Animatable {
    var value: Double
    let content: (Int) -> Content

    init(value: Double, @ViewBuilder content: @escaping (Int) -> Content) {
        self.value = value
        self.content = content
    }

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { content(Int(value.rounded())) }
}
