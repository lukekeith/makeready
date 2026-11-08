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
    }
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

    var color: String
    var image: Image?
    var wash: Wash?
    var motion: Motion?

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
    let raw: JSONValue
    let renderable: Renderable
    let background: ActivityBackground
    /// The actions this build can draw, in document order.
    let actions: [ActivityAction]

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
