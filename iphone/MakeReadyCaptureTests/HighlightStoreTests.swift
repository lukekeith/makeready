//
//  HighlightStoreTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.5 + 4.7 of docs/features/highlighting/ — the store and its model.
//
//  These assert the store against the FROZEN contract in 03 §2: the paths it
//  calls, the fields it sends, and the fields it reads back. The contract is
//  what the web player and the server also code against, so a drift here is a
//  cross-app bug, not a local one.
//

import XCTest
@testable import MakeReady

final class HighlightRouteContextTests: XCTestCase {

    func testProgramPathsMatchTheContract() {
        let context = HighlightRouteContext.program
        XCTAssertEqual(context.highlightsPath(activityId: "a1"), "/api/activities/a1/highlights")
        XCTAssertEqual(context.highlightPath(activityId: "a1", highlightId: "h1"),
                       "/api/activities/a1/highlights/h1")
    }

    func testEnrollmentPathsMatchTheContract() {
        let context = HighlightRouteContext.enrollment
        XCTAssertEqual(context.highlightsPath(activityId: "a1"), "/api/scheduled-activities/a1/highlights")
        XCTAssertEqual(context.highlightPath(activityId: "a1", highlightId: "h1"),
                       "/api/scheduled-activities/a1/highlights/h1")
    }

    func testNeitherContextUsesTheLegacyExegesisPath() {
        // The `…/exegesis-highlights` aliases stay mounted for shipped builds
        // (03 §2.5), but new code must not call them.
        for context in HighlightRouteContext.allCases {
            XCTAssertFalse(context.highlightsPath(activityId: "a").contains("exegesis"))
        }
    }
}

final class ContentHighlightDecodingTests: XCTestCase {

    private func decode(_ json: String) throws -> ContentHighlight {
        try JSONDecoder.apiDecoder.decode(ContentHighlight.self, from: Data(json.utf8))
    }

    func testDecodesTheContractShape() throws {
        let highlight = try decode("""
        { "id": "h1", "readBlockId": "b1", "orderNumber": 2, "start": 0, "end": 42,
          "style": "bold", "noteMarkdown": "a note" }
        """)

        XCTAssertEqual(highlight.id, "h1")
        XCTAssertEqual(highlight.readBlockId, "b1")
        XCTAssertEqual(highlight.orderNumber, 2)
        XCTAssertEqual(highlight.start, 0)
        XCTAssertEqual(highlight.end, 42)
        XCTAssertEqual(highlight.style, "bold")
        XCTAssertEqual(highlight.noteMarkdown, "a note")
    }

    /// The 09 §X-f guard: a cache written by a build that predates `style`.
    func testAnOldCachedPayloadWithNoStyleDecodesToTheDefault() throws {
        let highlight = try decode("""
        { "id": "h1", "readBlockId": "b1", "orderNumber": 1, "start": 2, "end": 19,
          "noteMarkdown": "" }
        """)

        XCTAssertEqual(highlight.style, "highlight")
    }

    func testAMissingNoteDecodesToEmptyRatherThanFailing() throws {
        let highlight = try decode("""
        { "id": "h1", "readBlockId": "b1", "orderNumber": 1, "start": 2, "end": 19 }
        """)

        XCTAssertEqual(highlight.noteMarkdown, "")
    }

    func testRoundTripsThroughEncodeAndDecode() throws {
        let original = ContentHighlight(id: "h1", readBlockId: "b1", orderNumber: 3,
                                        start: 5, end: 12, style: "bold", noteMarkdown: "n")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder.apiDecoder.decode(ContentHighlight.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}

@MainActor
final class APIHighlightStoreTests: XCTestCase {

    private var stub: StubAPIClient!

    override func setUp() {
        super.setUp()
        stub = StubAPIClient()
    }

    private func store(_ context: HighlightRouteContext) -> APIHighlightStore {
        APIHighlightStore(context: context, api: stub)
    }

    // MARK: Fetch

    func testFetchReadsBlockIdsAndHighlights() async throws {
        stub.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": true, "readBlockId": "b1", "blockIds": ["b1", "b2"],
          "highlights": [
            { "id": "h1", "readBlockId": "b1", "orderNumber": 1, "start": 0, "end": 5,
              "style": "highlight", "noteMarkdown": "" },
            { "id": "h2", "readBlockId": "b2", "orderNumber": 2, "start": 7, "end": 9,
              "style": "bold", "noteMarkdown": "note" }
          ] }
        """)

        let result = try await store(.program).fetch(activityId: "a1")

        XCTAssertEqual(result.blockIds, ["b1", "b2"])
        XCTAssertEqual(result.highlights.map(\.id), ["h1", "h2"])
        XCTAssertEqual(result.highlights.map(\.style), ["highlight", "bold"])
    }

    /// A READ activity can hold several locked blocks, so the deprecated
    /// singular `readBlockId` is not enough to address them (03 §2.1). The
    /// result type does not even expose it.
    func testFetchFallsBackToTheHighlightsOwnBlocksWhenBlockIdsIsAbsent() async throws {
        stub.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": true, "readBlockId": "b1",
          "highlights": [
            { "id": "h1", "readBlockId": "b1", "orderNumber": 1, "start": 0, "end": 5,
              "style": "highlight", "noteMarkdown": "" },
            { "id": "h2", "readBlockId": "b2", "orderNumber": 2, "start": 7, "end": 9,
              "style": "highlight", "noteMarkdown": "" },
            { "id": "h3", "readBlockId": "b1", "orderNumber": 3, "start": 11, "end": 14,
              "style": "highlight", "noteMarkdown": "" }
          ] }
        """)

        let result = try await store(.program).fetch(activityId: "a1")

        XCTAssertEqual(result.blockIds, ["b1", "b2"], "deduped, first-seen order")
    }

    func testFetchThrowsOnAnUnsuccessfulResponse() async {
        stub.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": false, "error": "Activity not found" }
        """)

        do {
            _ = try await store(.program).fetch(activityId: "a1")
            XCTFail("expected a throw")
        } catch {
            XCTAssertTrue("\(error)".contains("Activity not found"))
        }
    }

    // MARK: Create

    func testCreateSendsTheContractBodyAndReturnsAbsorbedIds() async throws {
        stub.stub("POST", "/api/activities/a1/highlights", json: """
        { "success": true,
          "highlight": { "id": "new", "readBlockId": "b1", "orderNumber": 1,
                         "start": 0, "end": 30, "style": "highlight", "noteMarkdown": "one\\n\\ntwo" },
          "absorbedIds": ["h1", "h2"] }
        """)

        let result = try await store(.program).create(
            activityId: "a1", readBlockId: "b1",
            span: HighlightSpan(start: 4, end: 20)!,
            style: "highlight", noteMarkdown: "")

        XCTAssertEqual(result.highlight.id, "new")
        XCTAssertEqual(result.absorbedIds, ["h1", "h2"], "the merge deleted these rows")

        let body = stub.calls.last?.body
        XCTAssertEqual(body?["readBlockId"] as? String, "b1")
        XCTAssertEqual(body?["start"] as? Int, 4)
        XCTAssertEqual(body?["end"] as? Int, 20)
        XCTAssertEqual(body?["style"] as? String, "highlight")
    }

    func testCreateReportsNoAbsorptionAsAnEmptyListNotAFailure() async throws {
        stub.stub("POST", "/api/activities/a1/highlights", json: """
        { "success": true,
          "highlight": { "id": "new", "readBlockId": "b1", "orderNumber": 1,
                         "start": 0, "end": 5, "style": "highlight", "noteMarkdown": "" } }
        """)

        let result = try await store(.program).create(
            activityId: "a1", readBlockId: "b1", span: HighlightSpan(start: 0, end: 5)!)

        XCTAssertEqual(result.absorbedIds, [])
    }

    // MARK: Update

    func testUpdateSendsOnlyTheFieldsGiven() async throws {
        stub.stub("PATCH", "/api/activities/a1/highlights/h1", json: """
        { "success": true,
          "highlight": { "id": "h1", "readBlockId": "b1", "orderNumber": 1,
                         "start": 0, "end": 5, "style": "bold", "noteMarkdown": "" } }
        """)

        _ = try await store(.program).update(activityId: "a1", highlightId: "h1",
                                             noteMarkdown: nil, style: "bold")

        let body = stub.calls.last?.body
        XCTAssertEqual(body?["style"] as? String, "bold")
        XCTAssertNil(body?["noteMarkdown"], "a nil field is omitted, not sent as empty")
    }

    func testUpdateWithNeitherFieldFailsLocallyRatherThanAskingTheServerFor400() async {
        do {
            _ = try await store(.program).update(activityId: "a1", highlightId: "h1",
                                                 noteMarkdown: nil, style: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(stub.calls.count, 0, "no request should have been made")
        }
    }

    // MARK: Delete

    func testDeleteHitsTheHighlightPath() async throws {
        stub.stub("DELETE", "/api/activities/a1/highlights/h1", json: #"{ "success": true }"#)

        try await store(.program).delete(activityId: "a1", highlightId: "h1")

        XCTAssertEqual(stub.callCount("DELETE", "/api/activities/a1/highlights/h1"), 1)
    }

    // MARK: Both contexts

    /// 08 §iPhone: create/update/delete round-trip through BOTH contexts. The
    /// two differ by a path prefix and nothing else — which is the property
    /// worth pinning, because eight hand-written methods is how they drifted
    /// before.
    func testTheEnrollmentContextRoundTripsIdenticallyOnADifferentPath() async throws {
        stub.stub("POST", "/api/scheduled-activities/a1/highlights", json: """
        { "success": true,
          "highlight": { "id": "h1", "readBlockId": "b1", "orderNumber": 1,
                         "start": 0, "end": 5, "style": "highlight", "noteMarkdown": "" },
          "absorbedIds": [] }
        """)
        stub.stub("PATCH", "/api/scheduled-activities/a1/highlights/h1", json: """
        { "success": true,
          "highlight": { "id": "h1", "readBlockId": "b1", "orderNumber": 1,
                         "start": 0, "end": 5, "style": "highlight", "noteMarkdown": "n" } }
        """)
        stub.stub("DELETE", "/api/scheduled-activities/a1/highlights/h1", json: #"{ "success": true }"#)

        let enrollment = store(.enrollment)
        let created = try await enrollment.create(
            activityId: "a1", readBlockId: "b1", span: HighlightSpan(start: 0, end: 5)!)
        let updated = try await enrollment.update(
            activityId: "a1", highlightId: created.highlight.id, noteMarkdown: "n", style: nil)
        try await enrollment.delete(activityId: "a1", highlightId: updated.id)

        XCTAssertEqual(stub.calls.map(\.method), ["POST", "PATCH", "DELETE"])
        XCTAssertTrue(stub.calls.allSatisfy { $0.endpoint.hasPrefix("/api/scheduled-activities/") })
    }
}
