//
//  VideoLayerTests.swift
//  MakeReadyCaptureTests
//
//  The video editor's layer model: trim, slide, split and lenient decoding (video-editor D3, D13,
//  D15, D24, D28).
//

import XCTest
@testable import MakeReady

final class VideoLayerTests: XCTestCase {
    private struct Box: Decodable {
        let layers: [VideoLayer]?
        enum CodingKeys: String, CodingKey { case layers }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            layers = VideoLayer.decodeLenient(from: container, forKey: .layers)
        }
    }

    func testTrimAndSlide() {
        let l = VideoLayer(kind: .text, text: "T", startMs: 1000, endMs: 4000)
        XCTAssertEqual(VideoLayerTiming.trimStart(l, to: 3900, in: 0...10_000).startMs, 3500)
        XCTAssertEqual(VideoLayerTiming.trimStart(l, to: -50, in: 0...10_000).startMs, 0)
        XCTAssertEqual(VideoLayerTiming.trimEnd(l, to: 99_000, in: 0...10_000).endMs, 10_000)
        let short = VideoLayer(kind: .caption, text: "Hi", startMs: 1000, endMs: 1200)
        XCTAssertEqual(VideoLayerTiming.trimEnd(short, to: 1050, in: 0...10_000).endMs, 1200)
        let late = VideoLayerTiming.slide(l, to: 9000, in: 0...10_000)
        XCTAssertEqual([late.startMs, late.endMs], [7000, 10_000])
        let b = VideoLayer(kind: .caption, text: "b", startMs: 1500, endMs: 2500)
        let all = [VideoLayer(kind: .caption, text: "a", startMs: 0, endMs: 1000), b, VideoLayer(kind: .caption, text: "c", startMs: 3000, endMs: 4000), l]
        XCTAssertEqual(VideoLayerTiming.bounds(of: b, among: all, clipMs: 10_000), 1000...3000)
        XCTAssertEqual(VideoLayerTiming.bounds(of: l, among: all, clipMs: 10_000), 0...10_000)
    }

    func testSplit() {
        let l = VideoLayer(kind: .caption, text: "Grace", centre: CGPoint(x: 0.5, y: 0.78), startMs: 1000, endMs: 4000, sourceSegment: 3)
        let (a, b) = VideoLayerTiming.split(l, at: 2500)
        XCTAssertEqual([a.startMs, a.endMs, b.startMs, b.endMs], [1000, 2500, 2500, 4000])
        XCTAssertTrue(a.id == l.id && b.id != l.id && b.style == l.style && b.centre == l.centre && b.text == "Grace")
        XCTAssertEqual([a.sourceSegment, b.sourceSegment], [3, 3])
        XCTAssertEqual([500, 1499, 1500, 3500, 3501].map { VideoLayerTiming.canSplit(l, at: $0) }, [false, false, true, true, false])
        XCTAssertTrue(l.isVisible(at: 1000)); XCTAssertFalse(l.isVisible(at: 4000))
    }

    func testLenientDecoding() throws {
        let json = #"{"layers":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","kind":"text","text":"A","startMs":0,"endMs":900,"style":{"font":"wingdings","colour":"red","background":"neon"}},{"kind":"text"},7]}"#
        let layers = try XCTUnwrap(JSONDecoder().decode(Box.self, from: Data(json.utf8)).layers)
        XCTAssertEqual(layers.map(\.text), ["A"])
        XCTAssertEqual(layers[0].style.font, VideoLayerStyle.standard.font)
        XCTAssertEqual(layers[0].style.colour, "#FFFFFF"); XCTAssertEqual(layers[0].centre, CGPoint(x: 0.5, y: 0.5))
        XCTAssertNil(try JSONDecoder().decode(Box.self, from: Data(#"{"layers":"x"}"#.utf8)).layers)
        let long = String(repeating: "a", count: 250)
        XCTAssertEqual([VideoLayer.Kind.text, .caption].map { VideoLayer(kind: $0, text: long, startMs: 0, endMs: 900).textLimit }, [200, 250])
    }

    func testDecodedScaleIsClamped() throws {
        let scales = try [40, 10, 0.1, 0.001, 0, -1].map { scale in
            let json = #"{"layers":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","kind":"text","text":"A","startMs":0,"endMs":900,"scale":\#(scale)}]}"#
            return try XCTUnwrap(JSONDecoder().decode(Box.self, from: Data(json.utf8)).layers?.first).scale
        }
        XCTAssertEqual(scales, [10, 10, 0.1, 0.1, 1, 1])
    }

    func testRoundTripAndEmptyWindowDropped() throws {
        let l = VideoLayer(kind: .text, text: "Round", centre: CGPoint(x: 0.2, y: 0.9), scale: 1.5, rotation: 0.3, startMs: 10, endMs: 20)
        let data = try JSONEncoder().encode([l])
        struct Wrap: Codable { let layers: [VideoLayer] }
        let back = try JSONDecoder().decode(Box.self, from: JSONEncoder().encode(Wrap(layers: [l])))
        XCTAssertEqual(back.layers, [l])
        XCTAssertFalse(data.isEmpty)
        let bad = #"{"layers":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","kind":"text","text":"A","startMs":900,"endMs":900}]}"#
        XCTAssertEqual(try JSONDecoder().decode(Box.self, from: Data(bad.utf8)).layers, [])
    }
}
