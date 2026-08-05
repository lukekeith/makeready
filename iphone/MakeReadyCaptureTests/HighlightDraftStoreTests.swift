//
//  HighlightDraftStoreTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.8b of docs/features/highlighting/ — and the automated regression
//  guard that 09 §G-d recorded as MISSING after phase 1.
//
//  Phase 1 fixed "exegesis notes erased on merge" (monday#12708759849 sub-issue
//  A) with a narrow re-key, verified by one human walkthrough and nothing else,
//  because the succession logic lived inline in a SwiftUI page's create path
//  with no seam a test could call. `applyMerge` is that seam.
//

import XCTest
@testable import MakeReady

final class HighlightDraftStoreTests: XCTestCase {

    private func highlight(
        _ id: String, start: Int = 0, end: Int = 10, note: String = ""
    ) -> ContentHighlight {
        ContentHighlight(id: id, readBlockId: "b1", orderNumber: 1,
                         start: start, end: end, noteMarkdown: note)
    }

    // MARK: Seeding and editing

    func testSeedingFillsDraftsFromSavedNotes() {
        var store = HighlightDraftStore()
        store.seed(from: [highlight("h1", note: "first"), highlight("h2", note: "second")])

        XCTAssertEqual(store["h1"]?.markdown, "first")
        XCTAssertEqual(store["h2"]?.markdown, "second")
        XCTAssertEqual(store.dirtyIds, [], "a seeded draft matches the server")
    }

    func testSeedingNeverClobbersUnsavedTyping() {
        var store = HighlightDraftStore()
        let h1 = highlight("h1", note: "saved")
        store.setMarkdown("typed but not saved", for: h1)

        store.seed(from: [h1])

        XCTAssertEqual(store["h1"]?.markdown, "typed but not saved")
    }

    func testATextMatchingTheServerIsNotDirty() {
        var store = HighlightDraftStore()
        let h1 = highlight("h1", note: "same")
        store.setMarkdown("same", for: h1)
        XCTAssertEqual(store.dirtyIds, [])

        store.setMarkdown("different", for: h1)
        XCTAssertEqual(store.dirtyIds, ["h1"])
    }

    func testMarkSavedClearsTheDirtyFlag() {
        var store = HighlightDraftStore()
        let before = highlight("h1", note: "old")
        store.setMarkdown("new", for: before)
        XCTAssertEqual(store.dirtyIds, ["h1"])

        store.markSaved(highlight("h1", note: "new"))
        XCTAssertEqual(store.dirtyIds, [])
        XCTAssertEqual(store["h1"]?.markdown, "new")
    }

    func testMarkdownFallsBackToTheSavedNoteWhenThereIsNoDraft() {
        let store = HighlightDraftStore()
        XCTAssertEqual(store.markdown(for: highlight("h1", note: "from the server")), "from the server")
    }

    // MARK: The merge — the regression guard

    /// The reported bug, end to end at this layer: two noted highlights are
    /// merged, and the surviving note must not read back empty.
    func testANoteSurvivesAMergeThatChangesTheSpan() {
        var store = HighlightDraftStore()
        let h1 = highlight("h1", start: 0, end: 10, note: "note one")
        let h2 = highlight("h2", start: 20, end: 30, note: "note two")
        store.seed(from: [h1, h2])

        // The server absorbed both and concatenated their saved notes.
        let merged = highlight("h3", start: 0, end: 30, note: "note one\n\nnote two")
        store.applyMerge(created: merged, absorbedIds: ["h1", "h2"])

        XCTAssertEqual(store.markdown(for: merged), "note one\n\nnote two")
        XCTAssertFalse(store.markdown(for: merged).isEmpty, "the reported symptom")
    }

    func testAbsorbedDraftsAreForgottenNotLeftOrphaned() {
        var store = HighlightDraftStore()
        store.seed(from: [highlight("h1", note: "a"), highlight("h2", note: "b")])

        let merged = highlight("h3", note: "a\n\nb")
        store.applyMerge(created: merged, absorbedIds: ["h1", "h2"])

        XCTAssertNil(store["h1"])
        XCTAssertNil(store["h2"])
        XCTAssertEqual(store.drafts.count, 1, "exactly one draft survives — the new entity's")
    }

    /// The case a plain re-key still loses: text the user typed but had not
    /// saved when the merge happened. The server cannot have concatenated it,
    /// because the server never saw it.
    func testUnsavedTypingInAnAbsorbedHighlightIsCarriedIntoTheSurvivor() {
        var store = HighlightDraftStore()
        let h1 = highlight("h1", note: "saved one")
        let h2 = highlight("h2", note: "saved two")
        store.seed(from: [h1, h2])
        store.setMarkdown("saved two, plus something I just typed", for: h2)

        let merged = highlight("h3", note: "saved one\n\nsaved two")
        store.applyMerge(created: merged, absorbedIds: ["h1", "h2"])

        let text = store.markdown(for: merged)
        XCTAssertTrue(text.contains("saved one"))
        XCTAssertTrue(text.contains("something I just typed"), "unsaved work must not vanish")
        XCTAssertEqual(store.dirtyIds, ["h3"], "and it must still get saved")
    }

    func testAlreadySavedTextIsNotDuplicatedIntoTheSurvivor() {
        var store = HighlightDraftStore()
        store.seed(from: [highlight("h1", note: "one"), highlight("h2", note: "two")])

        let merged = highlight("h3", note: "one\n\ntwo")
        store.applyMerge(created: merged, absorbedIds: ["h1", "h2"])

        XCTAssertEqual(store.markdown(for: merged), "one\n\ntwo")
        XCTAssertEqual(store.dirtyIds, [], "nothing was carried, so nothing needs saving")
    }

    func testAnUnsavedDraftOnTheSURVIVORAlsoSurvives() {
        var store = HighlightDraftStore()
        let survivor = highlight("h3", note: "")
        store.setMarkdown("typing into the one that stays", for: survivor)

        let merged = highlight("h3", note: "absorbed note")
        store.applyMerge(created: merged, absorbedIds: ["h1"])

        XCTAssertTrue(store.markdown(for: merged).contains("absorbed note"))
        XCTAssertTrue(store.markdown(for: merged).contains("typing into the one that stays"))
    }

    func testAMergeThatAbsorbsNothingIsStillCoherent() {
        var store = HighlightDraftStore()
        let created = highlight("h1", note: "just created")
        store.applyMerge(created: created, absorbedIds: [])

        XCTAssertEqual(store.markdown(for: created), "just created")
        XCTAssertEqual(store.dirtyIds, [])
    }

    func testEmptyUnsavedDraftsAreNotCarriedAsBlankParagraphs() {
        var store = HighlightDraftStore()
        let h1 = highlight("h1", note: "had a note")
        store.seed(from: [h1])
        store.setMarkdown("   \n  ", for: h1)   // user cleared it but did not save

        let merged = highlight("h3", note: "had a note")
        store.applyMerge(created: merged, absorbedIds: ["h1"])

        XCTAssertEqual(store.markdown(for: merged), "had a note")
    }

    /// The rich-text working copy must not outlive the text it was rendered
    /// from, or saving would push the pre-merge note back over the merged one.
    func testTheEditorsWorkingCopyIsClearedByAMerge() {
        var store = HighlightDraftStore()
        let survivor = highlight("h3", note: "before")
        store.setMarkdown("before", attributed: AttributedString("before"), for: survivor)

        store.applyMerge(created: highlight("h3", note: "after"), absorbedIds: [])

        XCTAssertNil(store["h3"]?.attributed)
    }

    // MARK: Pruning

    func testPruningDropsDraftsForHighlightsThatAreGone() {
        var store = HighlightDraftStore()
        store.seed(from: [highlight("h1"), highlight("h2"), highlight("h3")])

        store.prune(keeping: ["h1", "h3"])

        XCTAssertNotNil(store["h1"])
        XCTAssertNil(store["h2"])
        XCTAssertNotNil(store["h3"])
    }

    func testForgetRemovesASingleDraft() {
        var store = HighlightDraftStore()
        store.seed(from: [highlight("h1")])
        store.forget(id: "h1")
        XCTAssertTrue(store.isEmpty)
    }
}
