import XCTest
@testable import MakeReady

/// text-activity Task 25 (D17, D18, D33): the editor's document ↔ screen mapping.
@MainActor
final class ActivitiesEditorMapperTests: XCTestCase {

    func testFlagsOffAndFontsMapped() {
        let s = ActivitiesEditorMapper.state(document: .fixtureTwoObjects, media: [:], slides: [], activeID: "a")
        XCTAssertEqual([s.showsHighlightTool, s.showsEffectsTool, s.showsEyedropper], [false, false, false])
        // The screen takes the document's font KEYS and draws them as Poppins / Inter / Source Serif 4 /
        // Courier Prime itself (ActivitiesEditorScreen.font(_:)); a family name there would draw as sans.
        XCTAssertEqual(s.objectFonts, ["serif", "display"])
    }

    /// D18: an unknown font key renders as `sans`.
    func testAnUnknownFontKeyRendersAsSans() {
        let s = ActivitiesEditorMapper.state(document: .fixtureUnknownFont, media: [:], slides: [], activeID: "a")
        XCTAssertEqual(s.objectFonts, ["sans"])
    }

    func testAnEditPatchesOnlyItsFields() throws {
        let out = ActivitiesEditorMapper.apply(.fixture(index: 0, color: "#FF0000"), to: .fixtureTwoObjectsWithFutureFields)
        let json = try out.jsonObject()
        XCTAssertEqual(json.objects[0]["color"] as? String, "#FF0000")
        XCTAssertEqual(json.objects[0]["glow"] as? String, "soft")
        XCTAssertEqual(json.objects[1] as NSDictionary, try ActivityDocument.fixtureTwoObjectsWithFutureFields.jsonObject().objects[1] as NSDictionary)
    }

    /// D33: a transform edit writes x, y, scale and rotation and keeps the layout width.
    func testATransformEditKeepsTheWidth() throws {
        let edit = ActivitiesEditorScreen.ObjectEdit(index: 1, transform: .init(x: 100, y: 200, scale: 1.5, rotation: -8))
        let json = try ActivitiesEditorMapper.apply(edit, to: .fixtureTwoObjectsWithFutureFields).jsonObject()
        let transform = try XCTUnwrap(json.objects[1]["transform"] as? [String: Any])
        XCTAssertEqual(transform["x"] as? Double, 100)
        XCTAssertEqual(transform["y"] as? Double, 200)
        XCTAssertEqual(transform["scale"] as? Double, 1.5)
        XCTAssertEqual(transform["rotation"] as? Double, -8)
        XCTAssertEqual(transform["width"] as? Double, 300)
    }

    /// D16: the starter document is untouched; an object, a colour or an action is a touch.
    func testUntouchedIsTheStarterDocumentOnly() {
        let starter = ActivityNewContainer.textDocument(title: "Text")
        XCTAssertTrue(ActivitiesEditorMapper.isUntouched(starter))
        XCTAssertFalse(ActivitiesEditorMapper.isUntouched(ActivitiesEditorMapper.appendObject(to: starter, centerY: 400).document))
        XCTAssertFalse(ActivitiesEditorMapper.isUntouched(starter.updating { $0[path: ["background", "color"]] = .string("#000000") }))
        XCTAssertFalse(ActivitiesEditorMapper.isUntouched(starter.updating {
            $0[path: ["actions"]] = .array([.object(["id": .string("a1"), "kind": .string("nextLesson"),
                                                     "label": .string("Next"), "placement": .string("inline")])])
        }))
    }

    /// The page background reads the media map; the actions read their payload prefill.
    func testBackgroundAndActionsMapped() {
        let doc = ActivityDocument.fixtureTwoObjects.updating {
            $0[path: ["background"]] = .object([
                "color": .string("#0E4A4D"),
                "image": .object(["mediaId": .string("m1"), "focal": .object(["x": .number(0.2), "y": .number(0.7)])]),
                "wash": .object(["color": .string("#3B1E8F"), "opacity": .number(0.6)])
            ])
            $0[path: ["actions"]] = .array([.object([
                "id": .string("a1"), "kind": .string("addToPrayerList"), "label": .string("Pray"), "placement": .string("pinned"),
                "payload": .object(["title": .string("T"), "body": .string("B")])
            ])])
        }
        let media = ["m1": MediaMapEntry(url: "https://img/m1.jpg", width: nil, height: nil, kind: "image", playbackUrl: nil,
                                         posterUrl: nil, durationSeconds: nil, uploaderName: nil)]
        let s = ActivitiesEditorMapper.state(document: doc, media: media, slides: [], activeID: "a")
        XCTAssertEqual(s.pageColorHex, "#0E4A4D")
        XCTAssertEqual(s.pageImageURL, "https://img/m1.jpg")
        XCTAssertEqual([s.pageImageFocalX, s.pageImageFocalY], [0.2, 0.7])
        XCTAssertEqual(s.pageWashHex, "#3B1E8F")
        XCTAssertEqual(s.pageWashOpacity, 0.6)
        XCTAssertEqual(s.actionIDs, ["a1"])
        XCTAssertEqual(s.actionPlacements, ["pinned"])
        XCTAssertEqual(s.actionValues, ["T"])
        XCTAssertEqual(s.actionBodies, ["B"])
    }

    /// The actions sheet's list replaces the known actions; an action kind this build can't draw is kept.
    func testActionsEditKeepsUnknownKindsAndFields() throws {
        let doc = ActivityDocument.fixtureTwoObjects.updating {
            $0[path: ["actions"]] = .array([
                .object(["id": .string("a1"), "kind": .string("openUrl"), "label": .string("Open"), "placement": .string("inline"),
                         "payload": .object(["url": .string("https://old")]), "futureField": .string("kept")]),
                .object(["id": .string("a2"), "kind": .string("teleport"), "label": .string("Beam"), "placement": .string("pinned")])
            ])
        }
        let edited = [ActivitiesEditorScreen.PageAction(id: "a1", kind: .openUrl, label: "Visit", placement: .inline,
                                                        value: "https://new", body: "")]
        let json = try ActivitiesEditorMapper.applyActions(edited, to: doc).jsonObject()
        let actions = try XCTUnwrap(json.root["actions"] as? [[String: Any]])
        XCTAssertEqual(actions.map { $0["id"] as? String }, ["a1", "a2"])
        XCTAssertEqual(actions[0]["label"] as? String, "Visit")
        XCTAssertEqual((actions[0]["payload"] as? [String: Any])?["url"] as? String, "https://new")
        XCTAssertEqual(actions[0]["futureField"] as? String, "kept")
        XCTAssertEqual(actions[1]["kind"] as? String, "teleport")
    }
}

// MARK: - Fixtures

extension ActivityDocument {
    private static func decoding(_ json: String) -> ActivityDocument {
        // The document decoder never throws (D11): whatever the JSON holds becomes `raw`.
        (try? JSONDecoder().decode(ActivityDocument.self, from: Data(json.utf8))) ?? ActivityDocument(raw: .null)
    }

    /// Two canvas objects: serif, then display.
    static let fixtureTwoObjects = decoding(#"""
    {"schemaVersion":1,"kind":"text","background":{"color":"#000000"},
     "content":{"type":"canvas","verticalAnchor":"center","objects":[
       {"id":"o1","text":"One","font":"serif","weight":400,"size":26,"color":"#FFFFFF","alignment":"left",
        "transform":{"x":220,"y":300,"width":392,"scale":1,"rotation":0}},
       {"id":"o2","text":"Two","font":"display","weight":700,"size":38,"color":"#509CEF","alignment":"center",
        "transform":{"x":220,"y":500,"width":392,"scale":1,"rotation":0}}]},
     "actions":[]}
    """#)

    static let fixtureUnknownFont = decoding(#"""
    {"schemaVersion":1,"kind":"text","background":{"color":"#000000"},
     "content":{"type":"canvas","objects":[
       {"id":"o1","text":"One","font":"comic","transform":{"x":220,"y":300,"width":392,"scale":1,"rotation":0}}]},
     "actions":[]}
    """#)

    /// The same two objects carrying fields this build doesn't know.
    static let fixtureTwoObjectsWithFutureFields = decoding(#"""
    {"schemaVersion":1,"kind":"text","futureEnvelope":{"a":1},"background":{"color":"#000000","motion":{"mode":"parallax","rate":0.5}},
     "content":{"type":"canvas","verticalAnchor":"top","objects":[
       {"id":"o1","role":"heading","text":"One","font":"serif","weight":400,"size":26,"color":"#FFFFFF","alignment":"left",
        "glow":"soft","tracking":0.1,"transform":{"x":220,"y":300,"width":392,"scale":1,"rotation":0}},
       {"id":"o2","role":"body","text":"Two","font":"display","weight":700,"size":38,"color":"#509CEF","alignment":"center",
        "effect":"neon","animation":{"kind":"pop","trigger":"onActive","loop":false},
        "transform":{"x":220,"y":500,"width":300,"scale":1,"rotation":0}}]},
     "actions":[],"chrome":{"topAction":"share"}}
    """#)

    /// Test-only: the document as Foundation JSON, with its canvas objects pulled out.
    struct JSONObject {
        let root: [String: Any]
        var objects: [[String: Any]] {
            ((root["content"] as? [String: Any])?["objects"] as? [[String: Any]]) ?? []
        }
    }

    func jsonObject() throws -> JSONObject {
        let data = try JSONEncoder().encode(self)
        return JSONObject(root: try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any]))
    }
}

extension ActivitiesEditorScreen.ObjectEdit {
    static func fixture(index: Int, color: String) -> Self { .init(index: index, color: color) }
}
