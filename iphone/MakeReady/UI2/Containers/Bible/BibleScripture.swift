import Foundation
import UIKit

/// bible-verse-picker: the Bible activity's document logic, with no view and no network — a picked passage
/// becomes its document (D10, D27, D28) and citation, a changed passage re-anchors its highlights (D13), a
/// long one is never split but grows its page (D29), and a lesson's `used` passages come from its draft (D16).
/// The reference is an ordinary text object above the passage (D34); only the scripture is page-laid-out.
enum BibleScripture {
    // MARK: D10 / D28 default style

    /// The reference canvas (D10): 440 x 956.
    private static let pageWidth = 440.0
    private static let minimumPageHeight = 956.0
    /// D28: the default padding from the page edge.
    private static let sideInset = 32.0
    /// D45: the page's clear top band (the editor header / the player's top chrome, §18 `Snap.top` = 107)
    /// plus room for the reference line above the passage (D34).
    private static let topInset = 143.0
    /// D45: the player's end space (`Snap.bottom`), and with a pinned action its pinned band (`Snap.bottomPinned`).
    private static let bottomInset = 85.0
    private static let bottomInsetPinned = 110.0
    /// D34/D45: the reference's starting top — the top of the clear band, just under the header.
    private static let citationTop = 107.0
    private static let scriptureSize = 18.0
    private static let citationSize = 14.0
    /// D28: the default line height multiple.
    private static let lineHeight = 1.4

    /// D29/D34: the page is at least the text page, and grows to hold the laid-out scripture; the reference is not counted.
    static func pageHeight(scriptureHeight: CGFloat, pinned: Bool = false) -> CGFloat {
        max(minimumPageHeight, topInset + scriptureHeight + (pinned ? bottomInsetPinned : bottomInset))
    }

    /// The default scripture layout width.
    static var textWidth: Double { pageWidth - 2 * sideInset }

    // MARK: Citation

    /// "John 3:16b-18": the formatter's reference (`b` on a start verse that begins mid-verse, `a` on an end verse that
    /// ends mid-verse), with no translation code (D34). It is the reference text object's starting text and the
    /// activity title (D10).
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

    /// D10/D34: a `bible` document holding the locked scripture and the reference above it, over `background`. A pick is one
    /// document whatever its length (D29).
    static func document(for pick: BiblePick, background: ActivityBackground?) -> ActivityDocument {
        let passage = pick.passage
        let verses = selected(pick)
        let text = verses.map(\.text).joined(separator: "\n")
        let citationText = title(for: passage, bookName: pick.bookName)

        let scriptureHeight = height(of: numbered(verses, from: passage.verseStart), size: scriptureSize, width: textWidth)
        let citationHeight = height(of: citationText, size: citationSize, width: textWidth)

        var scripture = textObject(
            role: "scripture", text: text, size: scriptureSize, y: topInset + scriptureHeight / 2)
        scripture["listStyle"] = .string("bibleVerse")
        scripture["startNumber"] = .number(Double(passage.verseStart))
        // D27: one verse reads as plain prose, several are numbered in a gutter.
        scripture["verseNumbers"] = .string(verses.count > 1 ? "gutter" : "hidden")
        scripture["inset"] = .number(sideInset)
        if let reference = referenceJSON(for: passage) { scripture["reference"] = reference }
        // D34: left edge at the scripture's inset, the scripture's face, colour and horizontal alignment (textObject writes them).
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
            "font": .string("display"),   // D44: Poppins by default
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

    /// D34: Change passage rewrites the reference only while it still equals the old passage's reference; text the
    /// leader edited is kept.
    static func citationAfterChange(current: String, old: BiblePick, new: BiblePick) -> String {
        current == title(for: old.passage, bookName: old.bookName) ? title(for: new.passage, bookName: new.bookName) : current
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
        // D44: measured in the default face, Poppins (`display`) at 400.
        let font = ActivityViewerMapper.measuringFont(key: "display", weight: 400, size: size)
        let box = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style], context: nil)
        return ceil(box.height)
    }
}

// MARK: - Page layout (D26–D29)

extension BibleScripture {
    /// Where the page puts one object, in the 440-wide reference's units: the centre and the box.
    struct Placement: Equatable {
        var centerX: Double
        var centerY: Double
        var width: Double
        var height: Double
    }

    /// One `bible` page as the page lays it out (D26): the scripture placement by its index in
    /// `textObjects` and the page's height (D29). The reference is not part of the layout (D34).
    struct PageLayout: Equatable {
        var scriptureIndex: Int
        var scripture: Placement
        var height: Double
        /// D32: the scripture's top on the page after vertical alignment — 96 for `top`, and always 96 on a page
        /// taller than 956 (no slack). `scripture` stays at the top-at-96 frame.
        var scriptureTop: Double
    }

    /// D28: the default padding from the page edge.
    static let defaultInset = 32.0
    private static let gutterGap = 8.0
    private static let gutterNumberScale = 0.7

    /// D26: the page that lays this document out — nil unless it holds a locked scripture object (D11, D23: a
    /// legacy object with no `reference` is ordinary text and keeps its transform).
    static func layout(of document: ActivityDocument) -> PageLayout? {
        let objects = document.textObjects
        guard let scriptureIndex = objects.firstIndex(where: { $0.role == "scripture" && $0.isLockedScripture }) else { return nil }
        let scripture = objects[scriptureIndex]
        let inset = min(max(scripture.inset ?? defaultInset, 16), 64)
        let width = pageWidth - 2 * inset
        let scriptureHeight = scriptureHeight(scripture, width: width)
        let scriptureBox = Placement(centerX: pageWidth / 2, centerY: topInset + scriptureHeight / 2,
                                     width: width, height: scriptureHeight)
        let pinned = document.actions.contains { $0.placement == .pinned }
        let height = Double(pageHeight(scriptureHeight: CGFloat(scriptureHeight), pinned: pinned))
        // D32: the block moves only when the page is 956 tall; a taller page has no slack and reads top.
        let bottom = pinned ? bottomInsetPinned : bottomInset
        let slack = height > minimumPageHeight ? 0 : max(minimumPageHeight - bottom - (topInset + scriptureHeight), 0)
        let shift: Double
        switch scripture.verticalAlignment ?? .top {
        case .top: shift = 0
        case .center: shift = slack / 2
        case .bottom: shift = slack
        }
        return PageLayout(scriptureIndex: scriptureIndex, scripture: scriptureBox, height: height, scriptureTop: topInset + shift)
    }

    /// The document's text objects with the page's placement applied (D26): the scripture takes the layout's centre
    /// and width and an identity scale and rotation; every other object, the reference included, is returned as it is.
    /// `aligned` applies D32's vertical alignment (player, thumbnail); the editor screen shifts the block itself, so
    /// its mapper asks for `aligned: false`.
    static func placed(_ document: ActivityDocument, aligned: Bool = true) -> (objects: [TextObject], layout: PageLayout?) {
        var objects = document.textObjects
        guard let layout = layout(of: document) else { return (objects, nil) }
        let shift = aligned ? layout.scriptureTop - topInset : 0
        let box = layout.scripture
        objects[layout.scriptureIndex].transform = .init(x: box.centerX, y: box.centerY + shift, width: box.width, scale: 1, rotation: 0)
        return (objects, layout)
    }

    // MARK: Measuring

    /// The scripture's laid-out height (D27): gutter and inline put each verse on its own line(s), hidden runs them
    /// on as one paragraph; the gutter takes a column from the text's width.
    private static func scriptureHeight(_ scripture: TextObject, width: Double) -> Double {
        let verses = scripture.text.components(separatedBy: "\n")
        let first = scripture.startNumber ?? 1
        let lineHeight: Double? = scripture.lineHeight
        switch scripture.verseNumbers ?? .inline {
        case .hidden:
            return textHeight(verses.joined(separator: " "), object: scripture, size: scripture.size,
                              lineHeight: lineHeight, width: width)
        case .gutter:
            let numberFont = ActivityViewerMapper.measuringFont(key: scripture.font, weight: scripture.weight,
                                                                size: scripture.size * gutterNumberScale)
            let widest = (0..<max(verses.count, 1)).reduce(0.0) { widest, offset in
                max(widest, ceil(Double(("\(first + offset)" as NSString).size(withAttributes: [.font: numberFont]).width)))
            }
            return rows(verses, object: scripture, lineHeight: lineHeight, width: max(width - widest - gutterGap, 1))
        case .inline:
            // D41: inline runs on as one paragraph, each number inside the text.
            let numbered = verses.enumerated().map { "\(first + $0.offset) \($0.element)" }
            return textHeight(numbered.joined(separator: " "), object: scripture, size: scripture.size,
                              lineHeight: lineHeight, width: width)
        }
    }

    /// C-092 stacks the rows with the line-height gap between them, so every line of the block keeps one pitch.
    private static func rows(_ rows: [String], object: TextObject, lineHeight: Double?, width: Double) -> Double {
        let size = object.size
        let font = ActivityViewerMapper.measuringFont(key: object.font, weight: object.weight, size: size)
        let natural = Double(font.lineHeight)
        let pitch = max((lineHeight ?? 0) * size, natural)
        let lines = rows.reduce(0) { total, row in
            total + max(1, Int((boundingHeight(row, font: font, width: width) / natural).rounded()))
        }
        return ceil(Double(lines) * pitch - (pitch - natural))
    }

    /// A paragraph's height at one line pitch.
    private static func textHeight(_ text: String, object: TextObject, size: Double, lineHeight: Double?, width: Double) -> Double {
        let font = ActivityViewerMapper.measuringFont(key: object.font, weight: object.weight, size: size)
        let natural = Double(font.lineHeight)
        let pitch = max((lineHeight ?? 0) * size, natural)
        let lines = max(1, Int((boundingHeight(text.isEmpty ? " " : text, font: font, width: width) / natural).rounded()))
        return ceil(Double(lines) * pitch - (pitch - natural))
    }

    private static func boundingHeight(_ text: String, font: UIFont, width: Double) -> Double {
        let box = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        return Double(box.height)
    }
}
