//
//  EntityStoreTests.swift
//  MakeReadyCaptureTests
//
//  CHARACTERIZATION tests for State/EntityStore.swift.
//  These lock in CURRENT behavior (including quirks) before refactors
//  (@MainActor annotation, persistence changes). Do not "fix" behavior here —
//  update these tests only when production behavior intentionally changes.
//

import XCTest
@testable import MakeReady

private struct TestEntity: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var score: Int?
}

final class EntityStoreTests: XCTestCase {

    private func entity(_ id: String, _ name: String = "n", score: Int? = nil) -> TestEntity {
        TestEntity(id: id, name: name, score: score)
    }

    // MARK: - Init / empty state

    func testEmptyStore() {
        let store = EntityStore<TestEntity>()
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.count, 0)
        XCTAssertTrue(store.all.isEmpty)
        XCTAssertTrue(store.ids.isEmpty)
        XCTAssertNil(store["missing"])
        XCTAssertNil(store.get("missing"))
        XCTAssertFalse(store.contains("missing"))
    }

    func testInitWithEntitiesDuplicateIdsLastWins() {
        // QUIRK: duplicate IDs in the init array silently collapse — last one wins.
        let store = EntityStore(entities: [entity("a", "first"), entity("a", "second"), entity("b")])
        XCTAssertEqual(store.count, 2)
        XCTAssertEqual(store["a"]?.name, "second")
    }

    // MARK: - Upsert

    func testUpsertInsertsAndLookupWorks() {
        let store = EntityStore<TestEntity>()
        store.upsert(entity("a", "Alpha", score: 5))
        XCTAssertEqual(store.count, 1)
        XCTAssertFalse(store.isEmpty)
        XCTAssertTrue(store.contains("a"))
        XCTAssertEqual(store["a"], entity("a", "Alpha", score: 5))
        XCTAssertEqual(store.get("a"), store["a"])
    }

    func testUpsertOverwritesWholeEntityNoFieldMerge() {
        // QUIRK: upsert REPLACES the entire entity. A field that was populated
        // on the old entity but nil on the new one is LOST (no per-field merge).
        let store = EntityStore<TestEntity>()
        store.upsert(entity("a", "old", score: 99))
        store.upsert(entity("a", "new", score: nil))
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store["a"]?.name, "new")
        XCTAssertNil(store["a"]?.score)
    }

    func testUpsertManyInsertsAndOverwritesLastWins() {
        let store = EntityStore<TestEntity>()
        store.upsert(entity("a", "keepMe?"))
        store.upsertMany([entity("a", "overwritten"), entity("b"), entity("c", "c1"), entity("c", "c2")])
        XCTAssertEqual(store.count, 3)
        XCTAssertEqual(store["a"]?.name, "overwritten")
        // QUIRK: duplicates inside the upsertMany array — last wins, no error.
        XCTAssertEqual(store["c"]?.name, "c2")
    }

    // MARK: - replaceAll

    func testReplaceAllPreservesNothing() {
        // replaceAll clears ALL existing entities first; nothing survives.
        let store = EntityStore(entities: [entity("a"), entity("b")])
        store.replaceAll([entity("c"), entity("d")])
        XCTAssertEqual(Set(store.ids), Set(["c", "d"]))
        XCTAssertNil(store["a"])
        XCTAssertNil(store["b"])
    }

    func testReplaceAllWithEmptyArrayEmptiesStore() {
        let store = EntityStore(entities: [entity("a")])
        store.replaceAll([])
        XCTAssertTrue(store.isEmpty)
    }

    // MARK: - Remove / clear

    func testRemoveReturnsRemovedEntityOrNil() {
        let store = EntityStore(entities: [entity("a", "Alpha")])
        XCTAssertEqual(store.remove("a"), entity("a", "Alpha"))
        XCTAssertNil(store["a"])
        // Removing an unknown ID is a no-op that returns nil.
        XCTAssertNil(store.remove("never-existed"))
    }

    func testRemoveManyIgnoresUnknownIds() {
        let store = EntityStore(entities: [entity("a"), entity("b"), entity("c")])
        store.removeMany(["a", "zzz", "c"])
        XCTAssertEqual(store.ids, ["b"])
    }

    func testClearEmptiesStore() {
        let store = EntityStore(entities: [entity("a"), entity("b")])
        store.clear()
        XCTAssertTrue(store.isEmpty)
        XCTAssertEqual(store.count, 0)
    }

    // MARK: - Ordering

    func testAllAndIdsAreUnordered() {
        // QUIRK: `all` and `ids` come straight from a Dictionary — NO insertion
        // order is guaranteed. Only set-equality is stable.
        let store = EntityStore(entities: [entity("a"), entity("b"), entity("c")])
        XCTAssertEqual(Set(store.ids), Set(["a", "b", "c"]))
        XCTAssertEqual(Set(store.all.map(\.id)), Set(["a", "b", "c"]))
    }

    func testGetManyPreservesRequestedOrderAndSkipsMissing() {
        let store = EntityStore(entities: [entity("a"), entity("b"), entity("c")])
        let result = store.getMany(["c", "missing", "a"])
        XCTAssertEqual(result.map(\.id), ["c", "a"])
    }

    // MARK: - Merge

    func testMergeWithoutRemoveStaleKeepsExisting() {
        let store = EntityStore(entities: [entity("a", "old"), entity("b")])
        store.merge([entity("a", "new"), entity("c")])
        XCTAssertEqual(Set(store.ids), Set(["a", "b", "c"]))
        XCTAssertEqual(store["a"]?.name, "new")
    }

    func testMergeWithRemoveStaleDropsEntitiesNotInNewSet() {
        let store = EntityStore(entities: [entity("a", "old"), entity("b")])
        store.merge([entity("a", "new"), entity("c")], removeStale: true)
        XCTAssertEqual(Set(store.ids), Set(["a", "c"]))
        XCTAssertNil(store["b"])
    }

    // MARK: - Query helpers

    func testFilterAndFirstWhere() {
        let store = EntityStore(entities: [entity("a", "x", score: 1), entity("b", "x", score: 2), entity("c", "y")])
        XCTAssertEqual(Set(store.filter { $0.name == "x" }.map(\.id)), Set(["a", "b"]))
        XCTAssertEqual(store.first(where: { $0.name == "y" })?.id, "c")
        XCTAssertNil(store.first(where: { $0.name == "z" }))
    }

    // MARK: - update(_:transform:)

    func testUpdateTransformsExistingAndReturnsTrue() {
        let store = EntityStore(entities: [entity("a", "before", score: 1)])
        let updated = store.update("a") { $0.name = "after" }
        XCTAssertTrue(updated)
        XCTAssertEqual(store["a"]?.name, "after")
        XCTAssertEqual(store["a"]?.score, 1)
    }

    func testUpdateOnMissingIdReturnsFalseAndInsertsNothing() {
        let store = EntityStore<TestEntity>()
        let updated = store.update("ghost") { $0.name = "boo" }
        XCTAssertFalse(updated)
        XCTAssertTrue(store.isEmpty)
    }

    // MARK: - Codable

    func testCodableRoundTripAndJSONShape() throws {
        let store = EntityStore(entities: [entity("a", "Alpha", score: 1), entity("b", "Beta")])
        let data = try JSONEncoder().encode(store)

        // QUIRK: encodes as { "entities": { "<id>": {...} } } — a keyed
        // dictionary under an "entities" wrapper, not an array.
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entities = try XCTUnwrap(json["entities"] as? [String: Any])
        XCTAssertEqual(Set(entities.keys), Set(["a", "b"]))

        let decoded = try JSONDecoder().decode(EntityStore<TestEntity>.self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded["a"], entity("a", "Alpha", score: 1))
        XCTAssertEqual(decoded["b"], entity("b", "Beta"))
    }
}
