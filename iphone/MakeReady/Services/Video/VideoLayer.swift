//
//  VideoLayer.swift
//  MakeReady
//
//  The video editor's layer: text or caption drawn over a clip for a window of time (video-editor
//  D17). Decoding is lenient so a damaged edit never costs the recording (D28).
//

import CoreGraphics
import Foundation

struct VideoLayerStyle: Codable, Equatable, Sendable {
    enum Font: String, Codable, CaseIterable, Sendable { case display, sans, serif, mono, classic }
    enum Background: String, Codable, CaseIterable, Sendable { case none, solidDark, solidLight }
    enum Alignment: String, Codable, CaseIterable, Sendable { case left, center, right }

    static let weights = [400, 500, 700]

    var font: Font
    var weight: Int
    /// In wu, the editor's 440-wide design unit.
    var size: Double
    /// `#RRGGBB`.
    var colour: String
    var background: Background
    var alignment: Alignment

    static let standard = VideoLayerStyle(
        font: .sans, weight: 700, size: 38, colour: "#FFFFFF", background: .none, alignment: .center
    )

    init(font: Font, weight: Int, size: Double, colour: String, background: Background, alignment: Alignment) {
        self.font = font
        self.weight = weight
        self.size = size
        self.colour = colour
        self.background = background
        self.alignment = alignment
    }

    private enum CodingKeys: String, CodingKey { case font, weight, size, colour, background, alignment }

    /// A missing or bad value reads as `standard`'s.
    init(from decoder: Decoder) throws {
        let std = Self.standard
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { self = std; return }
        font = (try? c.decode(Font.self, forKey: .font)) ?? std.font
        let weight = (try? c.decode(Int.self, forKey: .weight)) ?? std.weight
        self.weight = Self.weights.contains(weight) ? weight : std.weight
        let size = (try? c.decode(Double.self, forKey: .size)) ?? std.size
        self.size = size.isFinite && size > 0 ? size : std.size
        let colour = (try? c.decode(String.self, forKey: .colour)) ?? std.colour
        self.colour = Self.isHex(colour) ? colour : "#FFFFFF"
        background = (try? c.decode(Background.self, forKey: .background)) ?? std.background
        alignment = (try? c.decode(Alignment.self, forKey: .alignment)) ?? std.alignment
    }

    private static func isHex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
}

struct VideoLayer: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case text, caption }

    /// At most this many text layers (D15); captions are not counted.
    static let maxTextLayers = 20
    static let defaultCentre = CGPoint(x: 0.5, y: 0.5)

    var id: UUID
    var kind: Kind
    var text: String
    var style: VideoLayerStyle
    /// A unit point on the shown frame, y down.
    var centre: CGPoint
    var scale: Double
    /// Radians, clockwise.
    var rotation: Double
    var startMs: Int
    var endMs: Int
    /// The transcript segment a caption came from.
    var sourceSegment: Int?

    init(
        id: UUID = UUID(),
        kind: Kind,
        text: String,
        style: VideoLayerStyle = .standard,
        centre: CGPoint = VideoLayer.defaultCentre,
        scale: Double = 1,
        rotation: Double = 0,
        startMs: Int,
        endMs: Int,
        sourceSegment: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.style = style
        self.centre = centre
        self.scale = scale
        self.rotation = rotation
        self.startMs = startMs
        self.endMs = endMs
        self.sourceSegment = sourceSegment
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, style, centre, scale, rotation, startMs, endMs, sourceSegment
    }

    /// Throws when `id`, `kind`, `text`, `startMs` or `endMs` is missing or bad, or the window is
    /// empty; everything else falls back to its default.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        text = try c.decode(String.self, forKey: .text)
        startMs = try c.decode(Int.self, forKey: .startMs)
        endMs = try c.decode(Int.self, forKey: .endMs)
        guard endMs > startMs else {
            throw DecodingError.dataCorruptedError(forKey: .endMs, in: c, debugDescription: "empty window")
        }
        style = (try? c.decode(VideoLayerStyle.self, forKey: .style)) ?? .standard
        let centre = try? c.decode(CGPoint.self, forKey: .centre)
        self.centre = centre.flatMap { $0.x.isFinite && $0.y.isFinite ? $0 : nil } ?? Self.defaultCentre
        let scale = (try? c.decode(Double.self, forKey: .scale)) ?? 1
        self.scale = scale.isFinite && scale > 0 ? scale : 1
        let rotation = (try? c.decode(Double.self, forKey: .rotation)) ?? 0
        self.rotation = rotation.isFinite ? rotation : 0
        sourceSegment = try? c.decode(Int.self, forKey: .sourceSegment)
    }

    /// 200, or a caption's own length when longer (D15, D24).
    var textLimit: Int {
        kind == .caption ? max(200, text.count) : 200
    }

    func isVisible(at ms: Int) -> Bool {
        startMs <= ms && ms < endMs
    }

    /// The layers under `key` that decode, one bad layer dropped alone; nil when the key is absent
    /// or not a list (D28).
    static func decodeLenient<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>, forKey key: Key
    ) -> [VideoLayer]? {
        guard let slots = try? container.decodeIfPresent([Slot].self, forKey: key) else { return nil }
        return slots.compactMap(\.layer)
    }

    private struct Slot: Decodable {
        let layer: VideoLayer?
        init(from decoder: Decoder) throws { layer = try? VideoLayer(from: decoder) }
    }
}
