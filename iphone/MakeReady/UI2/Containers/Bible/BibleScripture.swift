import Foundation
import UIKit

/// bible-verse-picker: the Bible activity's document logic, with no view and no network — a picked passage
/// becomes its document (D10) and citation, a changed passage re-anchors its highlights (D13), a long one
/// splits at verse boundaries (D14), and a lesson's `used` passages come from its draft (D16).
enum BibleScripture {
    // MARK: D10 default style

    /// The reference canvas (D10): 440 x 956.
    private static let pageWidth = 440.0
    private static let pageHeight = 956.0
    private static let sideInset = 32.0
    private static let topInset = 96.0
    private static let citationGap = 16.0
    private static let scriptureSize = 18.0
    private static let citationSize = 14.0
    /// The text editor's own default line height (`TextObject` decode).
    private static let lineHeight = 1.2

    /// The default scripture layout width.
    static var textWidth: Double { pageWidth - 2 * sideInset }

    // MARK: Citation

    /// "John 3:16b-18 ENGKJV": the formatter's reference (`b` on a start verse that begins mid-verse, `a` on
    /// an end verse that ends mid-verse), then a space and the translation code when there is one.
    static func citation(_ passage: BiblePassage, bookName: String) -> String {
        let reference = title(for: passage, bookName: bookName)
        guard let code = passage.translation, !code.isEmpty else { return reference }
        return "\(reference) \(code)"
    }

    /// The activity title: the citation without the translation code (D10).
    static func title(for passage: BiblePassage, bookName: String) -> String {
        let sameVerse = passage.chapterStart == passage.chapterEnd && passage.verseStart == passage.verseEnd
        let startPartial = (passage.startOffset ?? 0) > 0
        let endPartial = passage.endOffset != nil
        let start = CanvasTextObject.Reference.Point(
            book: bookName, chapter: passage.chapterStart, verse: passage.verseStart, isPartial: startPartial)
        guard !sameVerse else {
            // One verse: the formatter marks only a partial start ("b"); one that only ends mid-verse is its first
            // part, "a". Both ends partial keeps "b".
            let reference = BibleReferenceFormatter.format(.init(start: start, end: nil))
            return endPartial && !startPartial ? reference + "a" : reference
        }
        let end = CanvasTextObject.Reference.Point(
            book: bookName, chapter: passage.chapterEnd, verse: passage.verseEnd, isPartial: endPartial)
        return BibleReferenceFormatter.format(.init(start: start, end: end))
    }

    // MARK: Document

    /// D10: a `bible` document holding the locked scripture and its citation, over `background`.
    static func document(for pick: BiblePick, background: ActivityBackground?) -> ActivityDocument {
        let passage = pick.passage
        let verses = selected(pick)
        let text = verses.map(\.text).joined(separator: "\n")
        let citationText = citation(passage, bookName: pick.bookName)

        let scriptureHeight = height(of: numbered(verses, from: passage.verseStart), size: scriptureSize, width: textWidth)
        let citationTop = topInset + scriptureHeight + citationGap
        let citationHeight = height(of: citationText, size: citationSize, width: textWidth)

        var scripture = textObject(
            role: "scripture", text: text, size: scriptureSize, y: topInset + scriptureHeight / 2)
        scripture["listStyle"] = .string("bibleVerse")
        scripture["startNumber"] = .number(Double(passage.verseStart))
        if let reference = referenceJSON(for: passage) { scripture["reference"] = reference }
        let citationObject = textObject(
            role: "citation", text: citationText, size: citationSize, y: citationTop + citationHeight / 2)

        let backgroundJSON = background.flatMap(json) ?? .object(["color": .string(ActivityBackground.default.color)])
        var document = ActivityDocument(raw: .object([
            "schemaVersion": .number(1),
            "kind": .string("bible"),
            "background": backgroundJSON,
            "content": .object([
                "type": .string("canvas"),
                "verticalAnchor": .string("center"),
                "objects": .array([.object(scripture), .object(citationObject)])
            ]),
            "actions": .array([]),
            "chrome": .object(["topAction": .string("share")]),
            "fallback": .object([
                "title": .string(title(for: passage, bookName: pick.bookName)),
                "body": .string(ActivityDocument.fallbackBody)
            ])
        ]))
        document.passages = [passage]
        return document
    }

    private static func textObject(role: String, text: String, size: Double, y: Double) -> [String: JSONValue] {
        [
            "id": .string(UUID().uuidString.lowercased()),
            "role": .string(role),
            "text": .string(text),
            "font": .string("serif"),
            "weight": .number(400),
            "size": .number(size),
            "lineHeight": .number(lineHeight),
            "color": .string("#FFFFFF"),
            "alignment": .string("left"),
            "marks": .array([]),
            "highlights": .array([]),
            "transform": .object([
                "x": .number(pageWidth / 2), "y": .number(y), "width": .number(textWidth),
                "scale": .number(1), "rotation": .number(0)
            ])
        ]
    }

    /// SC2: written only with a translation — a reference without one would fail the server's pairing rule.
    private static func referenceJSON(for passage: BiblePassage) -> JSONValue? {
        guard let translation = passage.translation, !translation.isEmpty else { return nil }
        func point(chapter: Int, verse: Int, offset: Int?) -> JSONValue {
            var object: [String: JSONValue] = [
                "book": .number(Double(passage.bookNumber)), "chapter": .number(Double(chapter)),
                "verse": .number(Double(verse))
            ]
            if let offset { object["offset"] = .number(Double(offset)) }
            return .object(object)
        }
        return .object([
            "start": point(chapter: passage.chapterStart, verse: passage.verseStart, offset: passage.startOffset),
            "end": point(chapter: passage.chapterEnd, verse: passage.verseEnd, offset: passage.endOffset),
            "translation": .string(translation)
        ])
    }

    private static func json(_ background: ActivityBackground) -> JSONValue? {
        guard let data = try? JSONEncoder().encode(background) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    // MARK: Used (D16)

    /// Every passage of every `bible` activity in the lesson's draft.
    static func used(in activities: [ContentActivity]) -> [BiblePassage] {
        activities.filter { $0.kind == "bible" }.flatMap { $0.document.passages }
    }

    // MARK: Re-anchoring (D13)

    /// One verse's slice of a scripture text: canonical offsets `start..<end` of the verse, drawn from `base`.
    private struct Segment {
        let verse: Int
        let start: Int
        let end: Int
        let base: Int
        var length: Int { end - start }
    }

    /// Where each selected verse sits in the scripture text (verses joined by one "\n").
    private static func segments(of pick: BiblePick) -> [Segment] {
        var result: [Segment] = []
        var base = 0
        for verse in pick.verses where isSelected(verse, in: pick.passage) {
            let length = verse.text.utf16.count
            let start = verse.verse == pick.passage.verseStart ? min(pick.passage.startOffset ?? 0, length) : 0
            let end = verse.verse == pick.passage.verseEnd ? min(pick.passage.endOffset ?? length, length) : length
            result.append(Segment(verse: verse.verse, start: start, end: max(start, end), base: base))
            base += max(start, end) - start + 1
        }
        return result
    }

    /// A highlight survives when both its ends fall inside the new passage, moved to the new text; a
    /// different translation (offsets do not carry across) or chapter removes every one.
    static func reanchor(
        highlights: [TextObject.Highlight], old: BiblePick, new: BiblePick
    ) -> (kept: [TextObject.Highlight], removed: Int) {
        let a = old.passage, b = new.passage
        guard a.translation == b.translation, a.bookNumber == b.bookNumber, a.chapterStart == b.chapterStart,
              a.chapterEnd == b.chapterEnd else { return ([], highlights.count) }
        let oldSegments = segments(of: old), newSegments = segments(of: new)

        var kept: [TextObject.Highlight] = []
        for highlight in highlights {
            guard highlight.start < highlight.end,
                  let s = oldSegments.first(where: { highlight.start >= $0.base && highlight.start < $0.base + $0.length }),
                  let e = oldSegments.first(where: { highlight.end > $0.base && highlight.end <= $0.base + $0.length }),
                  let ns = newSegments.first(where: { $0.verse == s.verse }),
                  let ne = newSegments.first(where: { $0.verse == e.verse }) else { continue }
            let startCanon = s.start + highlight.start - s.base
            let endCanon = e.start + highlight.end - e.base
            guard startCanon >= ns.start, startCanon < ns.end, endCanon > ne.start, endCanon <= ne.end else { continue }
            var moved = highlight
            moved.start = ns.base + startCanon - ns.start
            moved.end = ne.base + endCanon - ne.start
            kept.append(moved)
        }
        return (kept, highlights.count - kept.count)
    }

    // MARK: Splitting (D14)

    /// Splits `pick` at verse boundaries into the fewest greedy parts that each fit; a part always keeps at
    /// least one verse. The partial start stays on the first part and the partial end on the last.
    static func split(_ pick: BiblePick, fits: ([BibleVerse]) -> Bool) -> [BiblePick] {
        let passage = pick.passage
        let verses = pick.verses.filter { isSelected($0, in: passage) }
        guard !verses.isEmpty else { return [pick] }

        func trimmed(_ verse: BibleVerse) -> BibleVerse {
            BibleVerse(verse: verse.verse, text: trim(verse, in: passage))
        }
        func part(_ members: [BibleVerse]) -> BiblePick {
            var p = passage
            p.verseStart = members[0].verse
            p.verseEnd = members[members.count - 1].verse
            if p.verseStart != passage.verseStart { p.startOffset = nil }
            if p.verseEnd != passage.verseEnd { p.endOffset = nil }
            return BiblePick(passage: p, verses: members, bookName: pick.bookName)
        }

        var parts: [BiblePick] = []
        var current: [BibleVerse] = []
        for verse in verses {
            if current.isEmpty || fits((current + [verse]).map(trimmed)) {
                current.append(verse)
            } else {
                parts.append(part(current))
                current = [verse]
            }
        }
        parts.append(part(current))
        return parts.count == 1 ? [pick] : parts
    }

    /// Whether `verses` (already trimmed) lay out with their citation inside the page's text area (D14).
    static func fits(verses: [BibleVerse], width: Double) -> Bool {
        guard let first = verses.first else { return true }
        let scripture = height(of: numbered(verses, from: first.verse), size: scriptureSize, width: width)
        let citation = height(of: "A", size: citationSize, width: width)
        return scripture + citationGap + citation <= pageHeight - 2 * topInset
    }

    // MARK: Text helpers

    private static func isSelected(_ verse: BibleVerse, in passage: BiblePassage) -> Bool {
        verse.verse >= passage.verseStart && verse.verse <= passage.verseEnd
    }

    /// The selected verses' texts, the first from `startOffset` and the last cut at `endOffset` (D8).
    private static func selected(_ pick: BiblePick) -> [BibleVerse] {
        pick.verses.filter { isSelected($0, in: pick.passage) }
            .map { BibleVerse(verse: $0.verse, text: trim($0, in: pick.passage)) }
    }

    private static func trim(_ verse: BibleVerse, in passage: BiblePassage) -> String {
        let units = Array(verse.text.utf16)
        let from = verse.verse == passage.verseStart ? min(max(passage.startOffset ?? 0, 0), units.count) : 0
        let to = verse.verse == passage.verseEnd ? min(max(passage.endOffset ?? units.count, from), units.count) : units.count
        return from == 0 && to == units.count ? verse.text : String(decoding: units[from..<to], as: UTF16.self)
    }

    /// The scripture as the canvas lays it out: each verse on its own line behind its number.
    private static func numbered(_ verses: [BibleVerse], from firstNumber: Int) -> String {
        verses.enumerated().map { "\(firstNumber + $0.offset) \($0.element.text)" }.joined(separator: "\n")
    }

    private static func height(of text: String, size: Double, width: Double) -> Double {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = size * lineHeight
        style.maximumLineHeight = size * lineHeight
        let font = UIFont.systemFont(ofSize: size)
        let serif = font.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? font
        let box = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: serif, .paragraphStyle: style], context: nil)
        return ceil(box.height)
    }
}
