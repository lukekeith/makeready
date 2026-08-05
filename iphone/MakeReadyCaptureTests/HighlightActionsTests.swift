//
//  HighlightActionsTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.15 of docs/features/highlighting/ — the two things 08 §iPhone asks
//  for that the service-level tests could not cover:
//
//  * "AppState reflects the mutation without a manual refetch" — i.e. the
//    Action writes state, so a view that reads `AppState` re-renders without
//    anyone re-fetching.
//  * "`clearInMemory()` clears highlights" — org-scoped data left behind leaks
//    into the next session.
//
//  Driven through the Actions' DI seam (stub client + private AppState), so no
//  network and no singleton state is touched.
//

import XCTest
@testable import MakeReady

@MainActor
final class HighlightActionsTests: XCTestCase {

    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    private func highlightJSON(id: String, block: String, start: Int, end: Int, note: String = "") -> String {
        """
        { "id": "\(id)", "readBlockId": "\(block)", "orderNumber": 1,
          "start": \(start), "end": \(end), "style": "highlight", "noteMarkdown": "\(note)" }
        """
    }

    // MARK: Load

    func testLoadingWritesHighlightsIntoAppState() async throws {
        api.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": true, "blockIds": ["b1"],
          "highlights": [\(highlightJSON(id: "h1", block: "b1", start: 0, end: 5))] }
        """)

        try await ProgramActions(api: api, state: state).loadHighlights(activityId: "a1")

        XCTAssertEqual(state.contentHighlights.all.map(\.id), ["h1"])
    }

    /// The wholesale replace: a highlight deleted elsewhere must not survive.
    func testLoadingRemovesRowsTheServerNoLongerReturnsForThoseBlocks() async throws {
        state.contentHighlights.upsert(
            ContentHighlight(id: "gone", readBlockId: "b1", orderNumber: 1,
                             start: 0, end: 3, noteMarkdown: ""))
        api.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": true, "blockIds": ["b1"],
          "highlights": [\(highlightJSON(id: "h1", block: "b1", start: 0, end: 5))] }
        """)

        try await ProgramActions(api: api, state: state).loadHighlights(activityId: "a1")

        XCTAssertNil(state.contentHighlights["gone"])
        XCTAssertNotNil(state.contentHighlights["h1"])
    }

    /// Scoped by the blocks the RESPONSE names, so another activity's rows are
    /// untouched — which is what `blockIds` is for (03 §2.1).
    func testLoadingLeavesAnotherActivitysHighlightsAlone() async throws {
        state.contentHighlights.upsert(
            ContentHighlight(id: "other", readBlockId: "bZ", orderNumber: 1,
                             start: 0, end: 3, noteMarkdown: ""))
        api.stub("GET", "/api/activities/a1/highlights", json: """
        { "success": true, "blockIds": ["b1"],
          "highlights": [\(highlightJSON(id: "h1", block: "b1", start: 0, end: 5))] }
        """)

        try await ProgramActions(api: api, state: state).loadHighlights(activityId: "a1")

        XCTAssertNotNil(state.contentHighlights["other"])
    }

    // MARK: Create — including the merge

    func testCreatingUpsertsAndAppliesTheServersMergeToState() async throws {
        for id in ["h1", "h2"] {
            state.contentHighlights.upsert(
                ContentHighlight(id: id, readBlockId: "b1", orderNumber: 1,
                                 start: 0, end: 3, noteMarkdown: ""))
        }
        api.stub("POST", "/api/activities/a1/highlights", json: """
        { "success": true,
          "highlight": \(highlightJSON(id: "merged", block: "b1", start: 0, end: 40)),
          "absorbedIds": ["h1", "h2"] }
        """)

        let result = try await ProgramActions(api: api, state: state).createHighlight(
            activityId: "a1", readBlockId: "b1", span: HighlightSpan(start: 0, end: 40)!)

        XCTAssertEqual(result.absorbedIds, ["h1", "h2"])
        XCTAssertNil(state.contentHighlights["h1"], "absorbed rows are deleted server-side")
        XCTAssertNil(state.contentHighlights["h2"])
        XCTAssertNotNil(state.contentHighlights["merged"])
    }

    // MARK: Update / delete

    func testUpdatingWritesTheReturnedRowIntoState() async throws {
        state.contentHighlights.upsert(
            ContentHighlight(id: "h1", readBlockId: "b1", orderNumber: 1,
                             start: 0, end: 5, noteMarkdown: "old"))
        api.stub("PATCH", "/api/activities/a1/highlights/h1", json: """
        { "success": true, "highlight": \(highlightJSON(id: "h1", block: "b1", start: 0, end: 5, note: "new")) }
        """)

        _ = try await ProgramActions(api: api, state: state).updateHighlight(
            activityId: "a1", highlightId: "h1", noteMarkdown: "new")

        XCTAssertEqual(state.contentHighlights["h1"]?.noteMarkdown, "new")
    }

    func testDeletingRemovesItFromState() async throws {
        state.contentHighlights.upsert(
            ContentHighlight(id: "h1", readBlockId: "b1", orderNumber: 1,
                             start: 0, end: 5, noteMarkdown: ""))
        api.stub("DELETE", "/api/activities/a1/highlights/h1", json: #"{ "success": true }"#)

        try await ProgramActions(api: api, state: state).deleteHighlight(activityId: "a1", highlightId: "h1")

        XCTAssertNil(state.contentHighlights["h1"])
    }

    // MARK: Both contexts reach the same state

    func testTheEnrollmentActionsWriteTheSameStoreOnItsOwnPaths() async throws {
        api.stub("GET", "/api/scheduled-activities/a1/highlights", json: """
        { "success": true, "blockIds": ["b1"],
          "highlights": [\(highlightJSON(id: "sched", block: "b1", start: 0, end: 5))] }
        """)

        try await EnrollmentActions(api: api, state: state).loadHighlights(activityId: "a1")

        XCTAssertEqual(state.contentHighlights.all.map(\.id), ["sched"])
    }

    // MARK: Sign-out

    /// Org-scoped data left behind leaks into the next user's session.
    func testClearingStateDropsEveryHighlight() {
        state.contentHighlights.upsert(
            ContentHighlight(id: "h1", readBlockId: "b1", orderNumber: 1,
                             start: 0, end: 5, noteMarkdown: ""))
        XCTAssertFalse(state.contentHighlights.all.isEmpty)

        state.clearAllData()

        XCTAssertTrue(state.contentHighlights.all.isEmpty)
    }
}
