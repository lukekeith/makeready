//
//  RelationshipIndexTests.swift
//  MakeReadyCaptureTests
//
//  CHARACTERIZATION tests for State/RelationshipIndex.swift.
//  These lock in CURRENT behavior (including quirks) before refactors.
//

import XCTest
@testable import MakeReady

final class RelationshipIndexTests: XCTestCase {

    // MARK: - Unknown parents

    func testUnknownParentBehavior() {
        let index = RelationshipIndex()
        XCTAssertEqual(index.get("nope"), [])
        XCTAssertEqual(index.getSet("nope"), [])
        XCTAssertFalse(index.hasChildren("nope"))
        XCTAssertEqual(index.count("nope"), 0)
        XCTAssertFalse(index.contains(parentId: "nope", childId: "c1"))
        XCTAssertTrue(index.allParentIds.isEmpty)
        // Mutations on unknown parents are silent no-ops.
        index.remove(parentId: "nope", childId: "c1")
        index.removeAll(parentId: "nope")
        XCTAssertTrue(index.allParentIds.isEmpty)
    }

    // MARK: - Add

    func testAddCreatesParentAndDeduplicates() {
        let index = RelationshipIndex()
        index.add(parentId: "p1", childId: "c1")
        index.add(parentId: "p1", childId: "c2")
        // QUIRK: children are a Set — duplicate adds silently dedupe.
        index.add(parentId: "p1", childId: "c1")
        XCTAssertEqual(index.count("p1"), 2)
        XCTAssertEqual(index.getSet("p1"), Set(["c1", "c2"]))
        XCTAssertTrue(index.hasChildren("p1"))
        XCTAssertTrue(index.contains(parentId: "p1", childId: "c1"))
        XCTAssertEqual(index.allParentIds, ["p1"])
    }

    func testAddManyDeduplicatesAgainstExistingAndWithinBatch() {
        let index = RelationshipIndex()
        index.add(parentId: "p1", childId: "c1")
        index.addMany(parentId: "p1", childIds: ["c1", "c2", "c2", "c3"])
        XCTAssertEqual(index.getSet("p1"), Set(["c1", "c2", "c3"]))
    }

    func testGetReturnsUnorderedArray() {
        // QUIRK: get() returns Array(Set) — order is NOT guaranteed.
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2", "c3"])
        XCTAssertEqual(Set(index.get("p1")), Set(["c1", "c2", "c3"]))
    }

    // MARK: - Remove

    func testRemoveChildFromParent() {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2"])
        index.remove(parentId: "p1", childId: "c1")
        XCTAssertEqual(index.get("p1"), ["c2"])
        XCTAssertFalse(index.contains(parentId: "p1", childId: "c1"))
    }

    func testRemovingLastChildDeletesParentKeyEntirely() {
        // QUIRK: removing the last child cleans up the parent key — the parent
        // disappears from allParentIds (it is not kept with an empty set).
        let index = RelationshipIndex()
        index.add(parentId: "p1", childId: "c1")
        index.remove(parentId: "p1", childId: "c1")
        XCTAssertTrue(index.allParentIds.isEmpty)
        XCTAssertFalse(index.hasChildren("p1"))
        XCTAssertEqual(index.toDictionary(), [:])
    }

    func testRemoveAllForParent() {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2"])
        index.add(parentId: "p2", childId: "c3")
        index.removeAll(parentId: "p1")
        XCTAssertEqual(index.allParentIds, ["p2"])
        XCTAssertEqual(index.get("p1"), [])
    }

    func testRemoveChildFromAllParentsCleansEmptyParents() {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["shared", "other"])
        index.add(parentId: "p2", childId: "shared")
        index.removeChild("shared")
        XCTAssertEqual(index.get("p1"), ["other"])
        // QUIRK: p2 only contained "shared", so p2's key is removed entirely.
        XCTAssertEqual(index.allParentIds, ["p1"])
    }

    // MARK: - Replace

    func testReplaceOverwritesChildren() {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2"])
        index.replace(parentId: "p1", childIds: ["c9"])
        XCTAssertEqual(index.get("p1"), ["c9"])
    }

    func testReplaceWithEmptyArrayRemovesParent() {
        // QUIRK: replace(parentId:childIds: []) removes the parent key rather
        // than storing an empty set.
        let index = RelationshipIndex()
        index.add(parentId: "p1", childId: "c1")
        index.replace(parentId: "p1", childIds: [])
        XCTAssertTrue(index.allParentIds.isEmpty)
    }

    func testReplaceDeduplicatesChildIds() {
        let index = RelationshipIndex()
        index.replace(parentId: "p1", childIds: ["c1", "c1", "c2"])
        XCTAssertEqual(index.count("p1"), 2)
    }

    // MARK: - Clear / rebuild

    func testClearRemovesEverything() {
        let index = RelationshipIndex()
        index.add(parentId: "p1", childId: "c1")
        index.add(parentId: "p2", childId: "c2")
        index.clear()
        XCTAssertTrue(index.allParentIds.isEmpty)
    }

    func testRebuildReplacesExistingIndex() {
        struct Pair { let parent: String; let child: String }
        let index = RelationshipIndex()
        index.add(parentId: "old", childId: "gone")
        index.rebuild(
            from: [Pair(parent: "p1", child: "c1"), Pair(parent: "p1", child: "c2"), Pair(parent: "p2", child: "c3")],
            parentKeyPath: \.parent,
            childKeyPath: \.child
        )
        XCTAssertEqual(Set(index.allParentIds), Set(["p1", "p2"]))
        XCTAssertEqual(index.getSet("p1"), Set(["c1", "c2"]))
        XCTAssertEqual(index.get("old"), [])
    }

    // MARK: - Dictionary serialization helpers

    func testToDictionaryAndLoadFromDictionaryRoundTrip() {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2"])
        index.add(parentId: "p2", childId: "c3")

        let dict = index.toDictionary()
        XCTAssertEqual(Set(dict.keys), Set(["p1", "p2"]))
        XCTAssertEqual(Set(dict["p1"] ?? []), Set(["c1", "c2"]))

        let restored = RelationshipIndex()
        restored.add(parentId: "stale", childId: "x")
        restored.loadFromDictionary(dict)  // replaces current state entirely
        XCTAssertEqual(Set(restored.allParentIds), Set(["p1", "p2"]))
        XCTAssertEqual(restored.get("stale"), [])
        XCTAssertEqual(restored.getSet("p1"), Set(["c1", "c2"]))
    }

    // MARK: - Codable

    func testCodableRoundTripAndJSONShape() throws {
        let index = RelationshipIndex()
        index.addMany(parentId: "p1", childIds: ["c1", "c2"])

        let data = try JSONEncoder().encode(index)

        // Encodes as { "index": { "<parentId>": [childIds...] } } —
        // sets become arrays (unordered) for JSON compatibility.
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let wrapped = try XCTUnwrap(json["index"] as? [String: [String]])
        XCTAssertEqual(Set(wrapped["p1"] ?? []), Set(["c1", "c2"]))

        let decoded = try JSONDecoder().decode(RelationshipIndex.self, from: data)
        XCTAssertEqual(decoded.getSet("p1"), Set(["c1", "c2"]))
        XCTAssertEqual(decoded.allParentIds, ["p1"])
    }
}
