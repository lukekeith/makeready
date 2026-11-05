import XCTest
@testable import MakeReady

/// master-search Task 8: the C1-C5 wire types (SPEC §iphone API).
final class SearchModelsTests: XCTestCase {

    func testDecodesItemWithNullsAndUnknownType() throws {
        let json = #"{"success":true,"items":[{"type":"FUTURE","id":"1","title":"T","createdAt":"2026-10-03T12:00:00.000Z","score":2.41,"imageUrl":null,"parent":null}],"nextCursor":null}"#
        let r = try JSONDecoder.apiDecoder.decode(SearchItemsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(r.items[0].type, "FUTURE")
        XCTAssertNil(r.items[0].openedAt)
        XCTAssertNil(r.nextCursor)
    }

    func testDecodesFilterOptions() throws {
        let json = #"{"success":true,"organizations":[{"id":"o","name":"O"}],"groups":[{"id":"g","name":"G","organizationId":"o"}],"leaders":[{"id":"l","name":"L"}],"tags":[{"tag":"lent","label":"Lent","category":null}]}"#
        let r = try JSONDecoder.apiDecoder.decode(SearchFilterOptions.self, from: Data(json.utf8))
        XCTAssertNil(r.tags[0].category)
        XCTAssertEqual(r.groups[0].organizationId, "o")
    }

    func testDecodesParentAndRecentFields() throws {
        let json = #"{"success":true,"items":[{"type":"LESSON","id":"l1","title":"Day 3","createdAt":"2026-10-03T12:00:00.000Z","score":null,"imageUrl":"https://i/x.jpg","parent":{"type":"PROGRAM","id":"p1","name":"Romans"},"openedAt":"2026-11-01T12:00:00.000Z"}]}"#
        let item = try JSONDecoder.apiDecoder.decode(SearchItemsResponse.self, from: Data(json.utf8)).items[0]
        XCTAssertEqual(item.parent, SearchItemParent(type: "PROGRAM", id: "p1", name: "Romans"))
        XCTAssertEqual(item.openedAt, "2026-11-01T12:00:00.000Z")
        XCTAssertEqual(item.imageUrl, "https://i/x.jpg")
        XCTAssertEqual(item.key, "LESSON:l1")
    }

    func testQueryPairsKeepOnlyNonEmptyListsCommaJoined() {
        XCTAssertTrue(SearchFilters().queryPairs.isEmpty)
        var filters = SearchFilters()
        filters.types = ["PROGRAM", "TEMPLATE"]
        filters.tags = ["lent"]
        let pairs = filters.queryPairs
        XCTAssertEqual(pairs.map(\.name), ["types", "tags"])
        XCTAssertEqual(pairs.map(\.value), ["PROGRAM,TEMPLATE", "lent"])
    }
}
