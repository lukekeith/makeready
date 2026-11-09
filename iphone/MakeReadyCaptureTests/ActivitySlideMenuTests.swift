import XCTest
@testable import MakeReady

/// activity-slide-menu (owner 2026-11-09): Duplicate lands right after the original; Delete removes the draft's
/// activity with the slide's key; both act on the draft.
@MainActor
final class ActivitySlideMenuTests: XCTestCase {
    private func activity(_ id: String, key: String, position: Int) -> ContentActivity {
        ContentActivity(id: id, lessonVersionId: "draft", activityKey: key, position: position, kind: "text",
                        title: "T-\(id)", document: ActivityNewContainer.textDocument(title: id), estimatedSeconds: nil)
    }

    func testTheMenuOffersEditDuplicateDelete() {
        XCTAssertEqual(ActivitySlideMenu.rows.map(\.label), ["Edit activity", "Duplicate activity", "Delete activity"])
        XCTAssertEqual(ActivitySlideMenu.deleteConfirmTitle, "Delete activity?")
    }

    func testOrderPlacesTheCopyRightAfterTheOriginal() {
        XCTAssertEqual(ActivitySlideMenu.order(["a", "b", "c", "n"], placing: "n", after: "b"), ["a", "b", "n", "c"])
        XCTAssertEqual(ActivitySlideMenu.order(["a", "n"], placing: "n", after: "zz"), ["a", "n"])
    }

    func testDuplicateCopiesTheDraftActivityAndPlacesItAfterTheOriginal() async throws {
        let draft = [activity("a", key: "ka", position: 0), activity("b", key: "kb", position: 1), activity("c", key: "kc", position: 2)]
        var created: (version: String, kind: String, title: String)?
        var reordered: [String]?
        let ops = ActivitySlideMenu.Ops(
            draftActivities: { _ in draft },
            create: { version, kind, title, _ in created = (version, kind, title); return "n" },
            reorder: { _, ids in reordered = ids },
            delete: { _ in XCTFail("no delete") })
        try await ActivitySlideMenu.duplicate(activityKey: "kb", lessonId: "l1", ops: ops)
        XCTAssertEqual(created?.version, "draft")
        XCTAssertEqual(created?.title, "T-b")
        XCTAssertEqual(reordered, ["a", "b", "n", "c"])
    }

    func testDeleteRemovesTheDraftActivityWithTheSlidesKey() async throws {
        let draft = [activity("a", key: "ka", position: 0), activity("b", key: "kb", position: 1)]
        var deleted: [String] = []
        let ops = ActivitySlideMenu.Ops(
            draftActivities: { _ in draft },
            create: { _, _, _, _ in XCTFail("no create"); return "" },
            reorder: { _, _ in XCTFail("no reorder") },
            delete: { deleted.append($0) })
        try await ActivitySlideMenu.delete(activityKey: "kb", lessonId: "l1", ops: ops)
        XCTAssertEqual(deleted, ["b"])
    }

    func testAMissingActivityThrows() async {
        let ops = ActivitySlideMenu.Ops(draftActivities: { _ in [] }, create: { _, _, _, _ in "" },
                                       reorder: { _, _ in }, delete: { _ in })
        do {
            try await ActivitySlideMenu.delete(activityKey: "kz", lessonId: "l1", ops: ops)
            XCTFail("expected a throw")
        } catch {}
    }
}
