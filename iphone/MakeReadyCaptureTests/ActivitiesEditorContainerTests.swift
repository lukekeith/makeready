import XCTest
@testable import MakeReady

/// text-activity Task 25 (D16, D22, D46): the editor's save, conflict retry and back-out.
@MainActor
final class ActivitiesEditorContainerTests: XCTestCase {

    func testNotDraftRefetchesRemapsAndRePutsOnce() async {
        let actions = ScriptedActivityActions(save: [.failure(.notDraft), .success], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        await model.done()
        XCTAssertEqual(actions.savedIds, ["a1", "a2"]); XCTAssertNil(model.saveError)
    }

    func testSecondFailureShowsRetryAndDiscard() async {
        let actions = ScriptedActivityActions(save: [.failure(.notDraft), .failure(.notDraft)], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        await model.done()
        XCTAssertEqual(model.saveError?.message, "Couldn't save activity")
        XCTAssertEqual(model.saveError?.options, ["Retry", "Discard changes"])
    }

    func testBackingOutOfAnUntouchedActivityDeletesIt() async {
        let actions = ScriptedActivityActions()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: ActivityNewContainer.textDocument(title: "Text"), actions: actions)
        await model.back()
        XCTAssertEqual(actions.deletedIds, ["a1"])
    }

    /// D16: an activity with an object is kept on back; its unsaved change is saved first, then the page pops.
    func testBackingOutOfAnEditedActivitySavesAndKeepsIt() async {
        let actions = ScriptedActivityActions(save: [.success])
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: ActivityNewContainer.textDocument(title: "Text"), actions: actions)
        model.navigator = nav
        model.tapEmpty(at: CGPoint(x: 220, y: 400))
        model.edit(.init(index: 0, text: "Hello"))
        await model.done()
        await model.back()
        XCTAssertEqual(actions.deletedIds, [])
        XCTAssertEqual(actions.savedIds, ["a1"])
        XCTAssertEqual(nav.pops, 1)
    }

    /// The edit buffer: Done drops a new object left empty, Cancel restores the document from before the edit.
    func testCancelRestoresAndDoneDropsAnEmptyNewObject() async {
        let actions = ScriptedActivityActions(save: [.success])
        let starter = ActivityNewContainer.textDocument(title: "Text")
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: starter, actions: actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400))
        model.edit(.init(index: 0, text: "Hello"))
        model.cancel()
        XCTAssertEqual(model.document, starter)
        XCTAssertEqual(model.editingIndex, -1)
        model.tapEmpty(at: CGPoint(x: 220, y: 400))
        await model.done()
        XCTAssertEqual(actions.savedDocuments, [starter])
    }

    /// D46: Discard changes puts back the last saved document and clears the error.
    func testDiscardRestoresTheSavedDocument() async {
        let actions = ScriptedActivityActions(save: [.failure(.other)])
        let starter = ActivityNewContainer.textDocument(title: "Text")
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: starter, actions: actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400))
        model.edit(.init(index: 0, text: "Hello"))
        await model.done()
        XCTAssertNotNil(model.saveError)
        model.discard()
        XCTAssertNil(model.saveError)
        XCTAssertEqual(model.document, starter)
    }

    /// D22: the play glyph opens the viewer on the draft and the current activity.
    func testPlayOpensTheViewerOnTheDraft() async {
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", lessonVersionId: "v1",
                                                    actions: ScriptedActivityActions())
        model.navigator = nav
        await model.play()
        XCTAssertEqual(nav.pushed, [.activityViewer(lessonVersionId: "v1", activityId: "a1")])
    }
}

// MARK: - Doubles

@MainActor
final class RecordingEditorNavigator: ActivitiesEditorNavigating {
    var pushed: [UI2Destination] = []
    var replaced: [UI2Destination] = []
    var pops = 0
    func push(_ destination: UI2Destination) { pushed.append(destination) }
    func replace(with destination: UI2Destination) { replaced.append(destination) }
    func pop() { pops += 1 }
}

/// The editor's Actions, scripted: each `save` takes the next step; `reloadDraft` returns `draft`.
@MainActor
final class ScriptedActivityActions: ActivityActionsProtocol {
    enum Failure { case notDraft, other }
    enum Step { case success, failure(Failure) }

    private struct Other: Error {}

    private var steps: [Step]
    private let draft: [ContentActivity]
    private(set) var savedIds: [String] = []
    private(set) var savedDocuments: [ActivityDocument] = []
    private(set) var deletedIds: [String] = []

    init(save: [Step] = [], draft: [ContentActivity] = []) {
        steps = save
        self.draft = draft
    }

    func reloadDraft(lessonId: String) async throws -> [ContentActivity] { draft }

    func save(activityId: String, title: String?, document: ActivityDocument) async throws {
        savedIds.append(activityId)
        let step = steps.isEmpty ? .success : steps.removeFirst()
        switch step {
        case .success: savedDocuments.append(document)
        case .failure(.notDraft): throw ActivityActionsError.notDraft
        case .failure(.other): throw Other()
        }
    }

    func delete(activityId: String) async throws { deletedIds.append(activityId) }
}

extension Array where Element == ContentActivity {
    /// A reloaded draft holding one activity with this id and key.
    @MainActor
    static func withActivity(id: String, key: String) -> [ContentActivity] {
        [ContentActivity(id: id, lessonVersionId: "v2", activityKey: key, position: 0, kind: "text", title: "Text",
                         document: ActivityNewContainer.textDocument(title: "Text"), estimatedSeconds: nil)]
    }
}
