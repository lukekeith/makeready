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

    /// D46: another leader's no-change publish deleted the draft, so the PUT is a 404; it remaps the same way.
    func testGoneActivityRefetchesRemapsAndRePutsOnce() async {
        let actions = ScriptedActivityActions(save: [.failure(.gone), .success], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        await model.done()
        XCTAssertEqual(actions.savedIds, ["a1", "a2"]); XCTAssertNil(model.saveError)
        XCTAssertEqual(model.activityId, "a2")
    }

    /// The rail's "+": the program read's lesson rows carry no program id, so the program comes from the index.
    func testAddOpensTheTypePickerWithTheProgramFromTheLessonIndex() async {
        let app = AppState()
        app.lessons.upsert(Lesson(id: "l1", studyProgramId: nil, position: 1))
        app.programLessonIndex.add(parentId: "p1", childId: "l1")
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", lessonId: "l1",
                                                    actions: ScriptedActivityActions())
        model.navigator = nav
        await model.addActivity(app: app)
        XCTAssertEqual(nav.replaced, [.activityNew(programId: "p1", lessonId: "l1")])
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

    // MARK: - Load

    /// An activity opened outside a loaded draft: its lesson is known, its draft is not.
    private func appWithActivityOutsideADraft() -> AppState {
        let app = AppState()
        app.lessonVersions.upsert(LessonVersion(id: "v1", lessonId: "l1", enrollmentId: nil, number: 1, status: .published,
                                                title: nil, estimatedSeconds: nil, publishedAt: nil))
        app.activities.upsert(ContentActivity(id: "a1", lessonVersionId: "v1", activityKey: "k1", position: 0, kind: "text",
                                              title: "Text", document: ActivityNewContainer.textDocument(title: "Text"),
                                              estimatedSeconds: nil))
        return app
    }

    func testLoadTakesTheDraftActivityWithTheSameKey() async {
        let actions = ScriptedActivityActions(draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "", phase: .loading, actions: actions,
                                                    log: { _, _ in })
        await model.load(app: appWithActivityOutsideADraft())
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.activityId, "a2")
        XCTAssertEqual(model.lessonVersionId, "v2")
    }

    /// A failed load shows the screen's Load-failed state, then back pops (nothing is deleted or saved).
    func testFailedLoadShowsLoadFailedAndBackPops() async {
        let actions = ScriptedActivityActions(reloadFails: true)
        let nav = RecordingEditorNavigator()
        var logged: [String] = []
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "", phase: .loading, actions: actions,
                                                    log: { _, context in logged.append(context) })
        model.navigator = nav
        await model.load(app: appWithActivityOutsideADraft())
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(logged, [ActivitiesEditorContainer.loadContext])
        XCTAssertTrue(ActivitiesEditorContainer.screenState(model, app: AppState()).loadFailed)
        await model.back()
        XCTAssertEqual(nav.pops, 1)
        XCTAssertEqual(actions.deletedIds, [])
        XCTAssertEqual(actions.savedIds, [])
    }

    /// Fix E1 (agent walk round 1): Add → Text on a lesson whose draft was never loaded — the created activity
    /// names a version that isn't in state, and only the program read's `draftVersionId` ties it to its lesson.
    func testLoadFindsTheLessonOfANewActivityFromTheLessonsDraftId() async {
        let app = AppState()
        var lesson = Lesson(id: "l1", studyProgramId: nil, position: 1)
        lesson.draftVersionId = "v2"
        app.lessons.upsert(lesson)
        app.activities.upsert(ContentActivity(id: "a2", lessonVersionId: "v2", activityKey: "k1", position: 0, kind: "text",
                                              title: "Text", document: ActivityNewContainer.textDocument(title: "Text"),
                                              estimatedSeconds: nil))
        let actions = ScriptedActivityActions(draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a2", activityKey: "", phase: .loading, actions: actions,
                                                    log: { _, _ in })
        await model.load(app: app)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.lessonId, "l1")
        XCTAssertEqual(model.activityId, "a2")
    }

    func testLoadFailsWhenTheLessonIsUnknown() async {
        let actions = ScriptedActivityActions(draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "", phase: .loading, actions: actions,
                                                    log: { _, _ in })
        await model.load(app: AppState())
        XCTAssertEqual(model.phase, .failed)
    }

    func testLoadFailsOnADocumentTheEditorCannotEdit() async {
        let row = ContentActivity(id: "a2", lessonVersionId: "v2", activityKey: "k1", position: 0, kind: "video", title: "Video",
                                  document: ActivityDocument(raw: .object([:])), estimatedSeconds: nil)
        let actions = ScriptedActivityActions(draft: [row])
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "", phase: .loading, actions: actions,
                                                    log: { _, _ in })
        await model.load(app: appWithActivityOutsideADraft())
        XCTAssertEqual(model.phase, .failed)
    }

    // MARK: - One save at a time

    /// Three saves started together run one after another: never two PUTs at once.
    func testConcurrentSavesRunOneAtATime() async {
        let actions = ScriptedActivityActions(saveDelayNanoseconds: 20_000_000)
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        let first = Task { await model.done() }
        let second = Task { await model.done() }
        let third = Task { await model.done() }
        await first.value; await second.value; await third.value
        XCTAssertEqual(actions.savedIds.count, 3)
        XCTAssertEqual(actions.maxConcurrentSaves, 1)
        XCTAssertFalse(model.isSaving)
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
    enum Failure { case notDraft, gone, other }
    enum Step { case success, failure(Failure) }

    private struct Other: Error {}

    private var steps: [Step]
    private let draft: [ContentActivity]
    private let reloadFails: Bool
    private let saveDelayNanoseconds: UInt64
    private var activeSaves = 0
    private(set) var maxConcurrentSaves = 0
    private(set) var savedIds: [String] = []
    private(set) var savedDocuments: [ActivityDocument] = []
    private(set) var deletedIds: [String] = []

    init(save: [Step] = [], draft: [ContentActivity] = [], reloadFails: Bool = false, saveDelayNanoseconds: UInt64 = 0) {
        steps = save
        self.draft = draft
        self.reloadFails = reloadFails
        self.saveDelayNanoseconds = saveDelayNanoseconds
    }

    func reloadDraft(lessonId: String) async throws -> [ContentActivity] {
        if reloadFails { throw Other() }
        return draft
    }

    func save(activityId: String, title: String?, document: ActivityDocument) async throws {
        savedIds.append(activityId)
        activeSaves += 1
        maxConcurrentSaves = max(maxConcurrentSaves, activeSaves)
        defer { activeSaves -= 1 }
        if saveDelayNanoseconds > 0 { try? await Task.sleep(nanoseconds: saveDelayNanoseconds) }
        let step = steps.isEmpty ? .success : steps.removeFirst()
        switch step {
        case .success: savedDocuments.append(document)
        case .failure(.notDraft): throw ActivityActionsError.notDraft
        case .failure(.gone): throw ActivityActionsError.gone
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
