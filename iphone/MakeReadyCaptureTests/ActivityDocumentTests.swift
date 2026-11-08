import XCTest
@testable import MakeReady

final class ActivityDocumentTests: XCTestCase {
    private enum Fixture {
        static let quiz = #"""
        {"schemaVersion":1,"kind":"quiz","background":{"color":"#000000"},"content":{"type":"quiz"},"actions":[]}
        """#
        static let textSchemaV2 = #"""
        {"schemaVersion":2,"kind":"text","background":{"color":"#000000"},
         "content":{"type":"canvas","objects":[]},"actions":[],
         "fallback":{"title":"Newer page","body":"Please update."}}
        """#
        static let textMissingObjects = #"""
        {"schemaVersion":1,"kind":"text","background":{"color":"#000000"},
         "content":{"type":"canvas","verticalAnchor":"center"},"actions":[]}
        """#
        static let textWithFutureFields = #"""
        {"schemaVersion":1,"kind":"text","futureField":"kept","background":{"color":"#0E4A4D"},
         "content":{"type":"canvas","verticalAnchor":"center","objects":[
           {"id":"o1","text":"Hello","font":"serif","weight":700,"size":26,"lineHeight":1.25,
            "color":"#FFFFFF","alignment":"left","glow":"soft",
            "transform":{"x":220,"y":478,"width":392,"scale":1,"rotation":0}}]},
         "actions":[]}
        """#
        static let textWithUnknownAction = #"""
        {"schemaVersion":1,"kind":"text","background":{"color":"#0E4A4D"},
         "content":{"type":"canvas","objects":[]},
         "actions":[{"id":"a1","kind":"openUrl","label":"Open","placement":"inline","payload":{"url":"https://x.org"}},
                    {"id":"a2","kind":"teleport","label":"Beam","placement":"pinned"}]}
        """#
    }

    private func decode(_ json: String) throws -> ActivityDocument {
        try JSONDecoder().decode(ActivityDocument.self, from: Data(json.utf8))
    }

    func testUnknownKindHigherVersionAndMalformedAllFallBack() throws {
        for json in [Fixture.quiz, Fixture.textSchemaV2, Fixture.textMissingObjects] {
            let doc = try JSONDecoder().decode(ActivityDocument.self, from: Data(json.utf8))
            guard case .fallback(let title, _) = doc.renderable else { return XCTFail("expected fallback for \(json.prefix(40))") }
            XCTAssertFalse(title.isEmpty)
        }
    }

    func testFallbackUsesTheDocumentsOwnCopyElseTheDefaults() throws {
        guard case .fallback(let title, let body) = try decode(Fixture.textSchemaV2).renderable else { return XCTFail("expected fallback") }
        XCTAssertEqual(title, "Newer page")
        XCTAssertEqual(body, "Please update.")
        guard case .fallback(let defaultTitle, let defaultBody) = try decode(Fixture.quiz).renderable else { return XCTFail("expected fallback") }
        XCTAssertEqual(defaultTitle, "A new activity")
        XCTAssertEqual(defaultBody, "Update the app to see this.")
    }

    func testKnownTextDocumentIsACanvas() throws {
        guard case .canvas(let canvas) = try decode(Fixture.textWithFutureFields).renderable else { return XCTFail("expected canvas") }
        XCTAssertEqual(canvas.objects.map(\.text), ["Hello"])
        XCTAssertEqual(canvas.objects.first?.font, "serif")
        XCTAssertEqual(canvas.objects.first?.transform.width, 392)
    }

    func testUnknownFieldsSurviveAnEditAndSave() throws {
        let doc = try JSONDecoder().decode(ActivityDocument.self, from: Data(Fixture.textWithFutureFields.utf8))
        let edited = doc.updating { $0[path: ["content", "objects", 0, "text"]] = .string("Edited") }
        let out = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edited)) as! [String: Any]
        XCTAssertEqual(out["futureField"] as? String, "kept")
        XCTAssertEqual(((out["content"] as! [String: Any])["objects"] as! [[String: Any]])[0]["glow"] as? String, "soft")
        guard case .canvas(let canvas) = edited.renderable else { return XCTFail("expected canvas") }
        XCTAssertEqual(canvas.objects.first?.text, "Edited")
    }

    func testUnknownActionKindDecodesAndIsSkipped() throws {
        let doc = try decode(Fixture.textWithUnknownAction)
        XCTAssertEqual(doc.actions.map(\.id), ["a1"])
        let out = try JSONSerialization.jsonObject(with: JSONEncoder().encode(doc)) as! [String: Any]
        XCTAssertEqual((out["actions"] as! [[String: Any]]).count, 2)
    }

    func testUTF16OffsetsAfterEmoji() {
        let obj = TextObject.fixture(text: "🙏 Pray now")
        let range = obj.utf16Range(start: 3, end: 8)!
        XCTAssertEqual(String(obj.text[range]), "Pray ")
    }

    func testUTF16RangeRejectsOutOfBoundsAndSplitSurrogates() {
        let obj = TextObject.fixture(text: "🙏 Pray now")
        XCTAssertNil(obj.utf16Range(start: 3, end: 99))
        XCTAssertNil(obj.utf16Range(start: 1, end: 3))
    }
}

extension TextObject {
    static func fixture(text: String) -> TextObject {
        TextObject(id: "o1", text: text, font: "sans", weight: 400, size: 16, lineHeight: 1.2, color: "#FFFFFF",
                   alignment: "left", transform: .init(x: 220, y: 478, width: 392, scale: 1, rotation: 0),
                   marks: [], highlights: [])
    }
}
