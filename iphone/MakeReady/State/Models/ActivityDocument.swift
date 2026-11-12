//
//  ActivityDocument.swift
//  MakeReady
//
//  One activity's document (02-content-schema). Reads are lenient (D11): the envelope decodes first
//  and anything unreadable becomes a fallback page instead of an error. The raw JSON is kept whole,
//  so fields this build doesn't know survive an edit and a save (02 §9).
//

import Foundation
import os

/// A document's canvas text object (02 §3). Fields the editor doesn't edit stay in `ActivityDocument.raw`.
struct TextObject: Codable, Hashable, Identifiable {
    struct Transform: Codable, Hashable {
        var x: Double
        var y: Double
        var width: Double
        var scale: Double
        var rotation: Double
    }

    /// D32: the scripture + citation block at the top, middle or bottom of the page (nested: the module must not
    /// shadow SwiftUI's `VerticalAlignment`).
    enum VerticalAlignment: String, Codable, Hashable {
        case top, center, bottom
    }

    /// Inline styling over a UTF-16 range of `text`.
    struct Mark: Codable, Hashable {
        var start: Int
        var end: Int
        var kind: String
        var href: String?
    }

    struct Highlight: Codable, Hashable, Identifiable {
        var id: String
        var start: Int
        var end: Int
        var noteMarkdown: String?
    }

    var id: String
    var text: String
    var font: String
    var weight: Int
    var size: Double
    var lineHeight: Double
    var color: String
    var alignment: String
    var transform: Transform
    var marks: [Mark]
    var highlights: [Highlight]
    /// "scripture" / "citation" mark a Bible activity's locked objects (D10, D11); nil on ordinary text.
    var role: String?
    var listStyle: String?
    var startNumber: Int?
    /// The passage a scripture object quotes (SC2). A malformed `reference` reads as nil; the
    /// document's raw JSON still holds it (D23).
    var reference: ScriptureReference?
    /// D27: how a scripture object draws its verse numbers. Reads `.inline` when the document never wrote one
    /// (every document before the ruling); assigning nil removes the field again.
    var verseNumbers: VerseNumbers? {
        get { writtenVerseNumbers ?? .inline }
        set { writtenVerseNumbers = newValue }
    }
    /// D28: padding from the page edge, 16-64 pt; nil = the 32 pt default (not written when absent).
    var inset: Double?
    /// D32: where a scripture's block sits between the page's 96 pt insets. nil = the field is absent, which reads
    /// `.top` and is never written until the leader picks one.
    var verticalAlignment: VerticalAlignment?
    /// The `verseNumbers` the document carries; nil = the field is absent and is never written.
    var writtenVerseNumbers: VerseNumbers?

    /// D11/D23/D34: a scripture object with a `reference` is locked in the editor. The citation is ordinary text.
    var isLockedScripture: Bool { role == "scripture" && reference != nil }

    /// `marks` and `highlights` count UTF-16 code units in every client (02 §3); Swift `String`
    /// distances count characters, so this converts at the boundary. Nil when the offsets are out
    /// of range, reversed or split a surrogate pair.
    func utf16Range(start: Int, end: Int) -> Range<String.Index>? {
        let units = text.utf16
        guard start >= 0, start <= end, end <= units.count else { return nil }
        let lower = units.index(units.startIndex, offsetBy: start)
        let upper = units.index(units.startIndex, offsetBy: end)
        guard lower.samePosition(in: text.unicodeScalars) != nil,
              upper.samePosition(in: text.unicodeScalars) != nil else { return nil }
        return lower..<upper
    }
}

extension TextObject {
    private enum CodingKeys: String, CodingKey {
        case id, text, font, weight, size, lineHeight, color, alignment, transform, marks, highlights
        case role, listStyle, startNumber, reference, verseNumbers, inset, verticalAlignment
    }

    /// Only `id`, `text` and `transform` are required; the rest take the editor's defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        transform = try c.decode(Transform.self, forKey: .transform)
        font = try c.decodeIfPresent(String.self, forKey: .font) ?? "sans"
        weight = try c.decodeIfPresent(Int.self, forKey: .weight) ?? 400
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 16
        lineHeight = try c.decodeIfPresent(Double.self, forKey: .lineHeight) ?? 1.2
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FFFFFF"
        alignment = try c.decodeIfPresent(String.self, forKey: .alignment) ?? "left"
        marks = try c.decodeIfPresent([Mark].self, forKey: .marks) ?? []
        highlights = try c.decodeIfPresent([Highlight].self, forKey: .highlights) ?? []
        role = try? c.decodeIfPresent(String.self, forKey: .role)
        listStyle = try? c.decodeIfPresent(String.self, forKey: .listStyle)
        startNumber = try? c.decodeIfPresent(Int.self, forKey: .startNumber)
        reference = try? c.decodeIfPresent(ScriptureReference.self, forKey: .reference)
        writtenVerseNumbers = try? c.decodeIfPresent(VerseNumbers.self, forKey: .verseNumbers)
        inset = try? c.decodeIfPresent(Double.self, forKey: .inset)
        verticalAlignment = try? c.decodeIfPresent(VerticalAlignment.self, forKey: .verticalAlignment)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(text, forKey: .text)
        try c.encode(font, forKey: .font)
        try c.encode(weight, forKey: .weight)
        try c.encode(size, forKey: .size)
        try c.encode(lineHeight, forKey: .lineHeight)
        try c.encode(color, forKey: .color)
        try c.encode(alignment, forKey: .alignment)
        try c.encode(transform, forKey: .transform)
        try c.encode(marks, forKey: .marks)
        try c.encode(highlights, forKey: .highlights)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(listStyle, forKey: .listStyle)
        try c.encodeIfPresent(startNumber, forKey: .startNumber)
        try c.encodeIfPresent(reference, forKey: .reference)
        try c.encodeIfPresent(writtenVerseNumbers, forKey: .verseNumbers)
        try c.encodeIfPresent(inset, forKey: .inset)
        try c.encodeIfPresent(verticalAlignment, forKey: .verticalAlignment)
    }
}

/// D27: `gutter` numbers in a left column, `hidden` runs on with none, `inline` runs on with superscripts.
enum VerseNumbers: String, Codable, Hashable {
    case gutter, hidden, inline
}

/// A scripture object's quoted range (SC2). `book` is the book number (43 = John), not a name.
struct ScriptureReference: Codable, Hashable {
    struct Point: Codable, Hashable {
        var book: Int
        var chapter: Int
        var verse: Int
        /// UTF-16 offset into the verse's canonical text (D8/D9); nil = the verse edge.
        var offset: Int?
    }

    var start: Point
    var end: Point
    var translation: String
}

/// One entry of a `bible` document's `content.passages` (D8). A missing `translation` is a legacy
/// passage (D22); a missing offset means the whole verse.
struct BiblePassage: Codable, Hashable {
    var bookNumber: Int
    var chapterStart: Int
    var verseStart: Int
    var chapterEnd: Int
    var verseEnd: Int
    var startOffset: Int?
    var endOffset: Int?
    var translation: String?
}

struct CanvasContent: Codable, Hashable {
    var verticalAnchor: String
    var objects: [TextObject]

    private enum CodingKeys: String, CodingKey { case verticalAnchor, objects }

    init(verticalAnchor: String = "center", objects: [TextObject]) {
        self.verticalAnchor = verticalAnchor
        self.objects = objects
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        verticalAnchor = try c.decodeIfPresent(String.self, forKey: .verticalAnchor) ?? "center"
        objects = try c.decode([TextObject].self, forKey: .objects)
    }
}

struct VideoContent: Codable, Hashable {
    struct Presenter: Codable, Hashable {
        var name: String?
        var avatarMediaId: String?
        var subtitle: String?
    }

    var videoId: String
    var posterMediaId: String?
    var presenter: Presenter?
}

struct YouTubeContent: Codable, Hashable {
    var youtubeVideoId: String
    var startSeconds: Double?
    var endSeconds: Double?
}

struct WriteContent: Codable, Hashable {
    var prompt: TextObject
    var placeholder: String?
}

/// A page background (02 §5). Missing or unreadable pieces take the defaults.
struct ActivityBackground: Codable, Hashable {
    struct Focal: Codable, Hashable {
        var x: Double
        var y: Double
    }

    struct Image: Codable, Hashable {
        var mediaId: String
        var focal: Focal?
    }

    struct Wash: Codable, Hashable {
        var color: String
        var opacity: Double
    }

    struct Motion: Codable, Hashable {
        var mode: String
        var rate: Double?
    }

    /// text-activity-v2 D1/D17: a generated blob gradient, drawn between `color` and `image`.
    struct Gradient: Codable, Hashable {
        struct Blob: Codable, Hashable {
            var x: Double
            var y: Double
            var r: Double
            var color: String
        }

        var style: String
        var base: String
        /// D14: true while a solid colour shows over a kept gradient. Absent decodes as false.
        var hidden: Bool
        var blobs: [Blob]

        init(style: String = "blobs", base: String, hidden: Bool = false, blobs: [Blob]) {
            self.style = style
            self.base = base
            self.hidden = hidden
            self.blobs = blobs
        }

        private enum CodingKeys: String, CodingKey { case style, base, hidden, blobs }

        /// Only `style: "blobs"` with a base and at least one readable blob decodes; anything else
        /// throws, so `ActivityBackground` leaves `gradient` nil and the raw JSON keeps it untouched.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            style = try container.decode(String.self, forKey: .style)
            guard style == "blobs" else {
                throw DecodingError.dataCorruptedError(forKey: .style, in: container, debugDescription: "unknown gradient style")
            }
            base = try container.decode(String.self, forKey: .base)
            hidden = (try? container.decode(Bool.self, forKey: .hidden)) ?? false
            let items = (try? container.decode([JSONValue].self, forKey: .blobs)) ?? []
            blobs = items.compactMap { item in
                guard let data = try? JSONEncoder().encode(item) else { return nil }
                return try? JSONDecoder().decode(Blob.self, from: data)
            }
            guard !blobs.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .blobs, in: container, debugDescription: "no readable blobs")
            }
        }

        /// The gradient as the document's JSON object; `hidden` is written only when true.
        var jsonValue: JSONValue {
            var object: [String: JSONValue] = [
                "style": .string(style),
                "base": .string(base),
                "blobs": .array(blobs.map { blob in
                    .object(["x": .number(blob.x), "y": .number(blob.y), "r": .number(blob.r), "color": .string(blob.color)])
                })
            ]
            if hidden { object["hidden"] = .bool(true) }
            return .object(object)
        }
    }

    var color: String
    var image: Image?
    var wash: Wash?
    var motion: Motion?
    var gradient: Gradient?

    init(color: String, image: Image?, wash: Wash?, motion: Motion?, gradient: Gradient? = nil) {
        self.color = color
        self.image = image
        self.wash = wash
        self.motion = motion
        self.gradient = gradient
    }

    private enum CodingKeys: String, CodingKey { case color, image, wash, motion, gradient }

    /// Each field decodes on its own, so one malformed piece never drops the rest (text-activity-v2 §iphone).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        color = (try? container.decode(String.self, forKey: .color)) ?? Self.default.color
        image = try? container.decode(Image.self, forKey: .image)
        wash = try? container.decode(Wash.self, forKey: .wash)
        motion = try? container.decode(Motion.self, forKey: .motion)
        gradient = try? container.decode(Gradient.self, forKey: .gradient)
    }

    static let `default` = ActivityBackground(color: "#000000", image: nil, wash: nil, motion: nil)
}

/// A page action (02 §7). Actions of a kind this build doesn't know are not decoded into this type.
struct ActivityAction: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, Hashable {
        case addToPrayerList, write, openUrl, nextLesson
    }

    enum Placement: String, Codable, Hashable {
        case inline, pinned
    }

    var id: String
    var kind: Kind
    var label: String
    var placement: Placement
    var payload: JSONValue?
}

struct ActivityDocument: Codable, Hashable {
    /// What a page shows. `fallback` is every document this build can't render (D11).
    enum Renderable: Hashable {
        case canvas(CanvasContent)
        case video(VideoContent)
        case youtube(YouTubeContent)
        case write(WriteContent)
        case fallback(title: String, body: String)
    }

    static let fallbackTitle = "A new activity"
    static let fallbackBody = "Update the app to see this."
    private static let supportedSchemaVersion = 1

    /// The document exactly as the server sent it, unknown fields included.
    private(set) var raw: JSONValue
    private(set) var renderable: Renderable
    private(set) var background: ActivityBackground
    /// The actions this build can draw, in document order.
    private(set) var actions: [ActivityAction]

    init(raw: JSONValue) {
        self.raw = raw
        renderable = Self.renderable(from: raw)
        background = Self.decodeValue(ActivityBackground.self, raw[path: ["background"]]) ?? .default
        actions = raw[path: ["actions"]].flatMap { value -> [ActivityAction]? in
            guard case .array(let items) = value else { return nil }
            return items.compactMap { Self.decodeValue(ActivityAction.self, $0) }
        } ?? []
    }

    /// Never throws for a document: whatever the JSON holds becomes `raw`.
    init(from decoder: Decoder) throws {
        let value = (try? decoder.singleValueContainer().decode(JSONValue.self)) ?? .null
        self.init(raw: value)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }

    /// A copy of the document with `edit` applied to its raw JSON; everything else is kept.
    func updating(_ edit: (inout JSONValue) -> Void) -> ActivityDocument {
        var value = raw
        edit(&value)
        return ActivityDocument(raw: value)
    }

    // MARK: Bible passages

    /// The canvas's text objects.
    var textObjects: [TextObject] {
        guard case .canvas(let canvas) = renderable else { return [] }
        return canvas.objects
    }

    /// `content.passages`, skipping any entry missing a required int (D22).
    var passages: [BiblePassage] {
        get { Self.validPassages(in: raw).map(\.passage) }
        set {
            let existing = Self.validPassages(in: raw)
            let written: [JSONValue] = newValue.enumerated().map { index, passage in
                // Overlay onto the entry already there so keys this build doesn't know survive.
                var object: [String: JSONValue] = [:]
                if index < existing.count, case .object(let current) = existing[index].json { object = current }
                object["bookNumber"] = .number(Double(passage.bookNumber))
                object["chapterStart"] = .number(Double(passage.chapterStart))
                object["verseStart"] = .number(Double(passage.verseStart))
                object["chapterEnd"] = .number(Double(passage.chapterEnd))
                object["verseEnd"] = .number(Double(passage.verseEnd))
                object["startOffset"] = passage.startOffset.map { .number(Double($0)) }
                object["endOffset"] = passage.endOffset.map { .number(Double($0)) }
                object["translation"] = passage.translation.map { .string($0) }
                return .object(object)
            }
            var value = raw
            value[path: ["content", "passages"]] = .array(written)
            self = ActivityDocument(raw: value)
        }
    }

    private static func validPassages(in raw: JSONValue) -> [(json: JSONValue, passage: BiblePassage)] {
        guard case .array(let items)? = raw[path: ["content", "passages"]] else { return [] }
        return items.compactMap { item in decodeValue(BiblePassage.self, item).map { (item, $0) } }
    }

    // MARK: Decoding

    private static func renderable(from raw: JSONValue) -> Renderable {
        let fallback = fallbackPage(from: raw)
        guard case .object = raw,
              case .string(let kind)? = raw[path: ["kind"]],
              case .number(let version)? = raw[path: ["schemaVersion"]] else {
            Log.state.error("ActivityDocument: malformed envelope; showing the fallback page")
            return fallback
        }
        guard Int(version) <= supportedSchemaVersion else { return fallback }
        let content = raw[path: ["content"]]
        switch kind {
        case "text", "bible":
            return decoded(CanvasContent.self, content, kind: kind).map(Renderable.canvas) ?? fallback
        case "video":
            return decoded(VideoContent.self, content, kind: kind).map(Renderable.video) ?? fallback
        case "youtube":
            return decoded(YouTubeContent.self, content, kind: kind).map(Renderable.youtube) ?? fallback
        case "write":
            return decoded(WriteContent.self, content, kind: kind).map(Renderable.write) ?? fallback
        default:
            return fallback
        }
    }

    private static func fallbackPage(from raw: JSONValue) -> Renderable {
        var title = fallbackTitle
        var body = fallbackBody
        if case .string(let t)? = raw[path: ["fallback", "title"]], !t.isEmpty { title = t }
        if case .string(let b)? = raw[path: ["fallback", "body"]], !b.isEmpty { body = b }
        return .fallback(title: title, body: body)
    }

    private static func decoded<T: Decodable>(_ type: T.Type, _ value: JSONValue?, kind: String) -> T? {
        let result = decodeValue(type, value)
        if result == nil { Log.state.error("ActivityDocument: malformed \(kind, privacy: .public) content; showing the fallback page") }
        return result
    }

    private static func decodeValue<T: Decodable>(_ type: T.Type, _ value: JSONValue?) -> T? {
        guard let value, let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
