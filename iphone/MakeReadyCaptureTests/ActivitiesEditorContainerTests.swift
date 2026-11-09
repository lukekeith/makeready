import XCTest
@testable import MakeReady

/// text-activity Task 25 (D16, D46; the Idle Done per the owner, 2026-11-08): the editor's save, conflict retry and back-out.
@MainActor
final class ActivitiesEditorContainerTests: XCTestCase {

    func testNotDraftRefetchesRemapsAndRePutsOnce() async {
        let actions = ScriptedActivityActions(save: [.failure(.notDraft), .success], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hello"))
        await model.done()
        XCTAssertEqual(actions.savedIds, ["a1", "a2"]); XCTAssertNil(model.saveError)
    }

    /// D46: another leader's no-change publish deleted the draft, so the PUT is a 404; it remaps the same way.
    func testGoneActivityRefetchesRemapsAndRePutsOnce() async {
        let actions = ScriptedActivityActions(save: [.failure(.gone), .success], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hello"))
        await model.done()
        XCTAssertEqual(actions.savedIds, ["a1", "a2"]); XCTAssertNil(model.saveError)
        XCTAssertEqual(model.activityId, "a2")
    }


    func testSecondFailureShowsRetryAndDiscard() async {
        let actions = ScriptedActivityActions(save: [.failure(.notDraft), .failure(.notDraft)], draft: .withActivity(id: "a2", key: "k1"))
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hello"))
        await model.done()
        XCTAssertEqual(model.saveError?.message, "Couldn't save activity")
        XCTAssertEqual(model.saveError?.options, ["Retry", "Discard changes"])
    }

    /// D16 (superseded round 5): an untouched new activity is kept on back — never auto-deleted.
    func testBackingOutOfAnUntouchedActivityKeepsIt() async {
        let actions = ScriptedActivityActions()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: ActivityNewContainer.textDocument(title: "Text"), actions: actions)
        await model.back()
        XCTAssertEqual(actions.deletedIds, [])
        XCTAssertEqual(actions.savedIds, [])
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
        await model.cancel()
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

    /// Owner 2026-11-08: the Idle Done saves the unsaved change, then leaves the editor.
    func testIdleDoneSavesThenLeaves() async {
        let actions = ScriptedActivityActions(save: [.success, .success])
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        model.navigator = nav
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hello"))
        await model.done()                                  // ends the text edit, saves
        XCTAssertEqual(nav.pops, 0)
        model.changeBackground(.colour("#FF0000"))
        await model.done()                                  // Idle: saves the change, then leaves
        XCTAssertEqual(actions.savedIds, ["a1", "a1"])
        XCTAssertEqual(nav.pops, 1)
    }

    /// The Idle Done with nothing to save does nothing; a failed save stays on the page.
    func testIdleDoneWithNothingToSaveOrAFailedSaveStays() async {
        let actions = ScriptedActivityActions(save: [.failure(.other)])
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        model.navigator = nav
        await model.done()
        XCTAssertEqual(actions.savedIds, []); XCTAssertEqual(nav.pops, 0)
        model.changeBackground(.colour("#FF0000"))
        await model.done()
        XCTAssertNotNil(model.saveError); XCTAssertEqual(nav.pops, 0)
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

    // MARK: - text-activity-v2: tap-off, tap-another and the save moments (D10, D19, D20)

    private func starterModel(_ actions: ScriptedActivityActions) -> ActivitiesEditorContainer.Model {
        ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1",
                                        document: ActivityNewContainer.textDocument(title: "Text"), actions: actions)
    }

    func testTapOffWhileEditingCommitsAndSavesOnce() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hello"))
        await model.tapOff()
        XCTAssertEqual(model.editingIndex, -1)
        XCTAssertEqual(actions.savedDocuments.count, 1)
        XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: actions.savedDocuments[0]), "Hello")
    }

    func testTapOffOnAnAddedEmptyObjectDropsIt() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400))
        await model.tapOff()
        XCTAssertTrue(ActivitiesEditorMapper.rawObjects(model.document).isEmpty)
        XCTAssertEqual(actions.savedDocuments.count, 1)
    }

    func testTapOffInIdleDoesNothing() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        await model.tapOff()
        XCTAssertTrue(actions.savedIds.isEmpty)
    }

    func testTappingAnotherObjectCommitsThenEditsIt() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 300)); model.edit(.init(index: 0, text: "One"))
        await model.tapOff()
        model.tapEmpty(at: CGPoint(x: 220, y: 600)); model.edit(.init(index: 1, text: "Two"))
        await model.tapObject(0)
        XCTAssertEqual(model.editingIndex, 0)
        XCTAssertEqual(actions.savedDocuments.count, 2)
        XCTAssertEqual(ActivitiesEditorMapper.text(at: 1, in: actions.savedDocuments[1]), "Two")
    }

    func testCancelRestoresOnlyTheObjectAndSavesPageEdits() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Original"))
        await model.tapOff()                                            // saved 1
        await model.tapObject(0); model.edit(.init(index: 0, text: "Changed"))
        model.changeActions([.init(id: "x1", kind: .write, label: "Go", placement: .inline, value: "", body: "")])
        await model.cancel()                                            // saved 2: the action, not the text
        XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: model.document), "Original")
        XCTAssertEqual(actions.savedDocuments.count, 2)
        XCTAssertEqual(actions.savedDocuments[1].actions.map(\.label), ["Go"])
        XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: actions.savedDocuments[1]), "Original")
    }

    func testActionEditsSaveWhenTheRailClosesAndEmptyOnesDrop() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.changeActions([.init(id: "x1", kind: .write, label: "Go", placement: .inline, value: "", body: ""),
                             .init(id: "x2", kind: .write, label: "", placement: .inline, value: "", body: "")])
        XCTAssertTrue(actions.savedIds.isEmpty)
        await model.closePageRails()
        XCTAssertEqual(actions.savedDocuments.count, 1)
        XCTAssertEqual(actions.savedDocuments[0].actions.map(\.label), ["Go"])
    }

    // MARK: - text-activity-v2: the Background rail (D13, D14, D18, D22)

    func testBackgroundCommandsPatchLiveAndSaveOnRailClose() async {
        let actions = ScriptedActivityActions()
        let model = starterModel(actions)
        model.random = AnyRandomNumberGenerator(SeededRandom(seed: 21))
        let before = model.document.background.gradient
        model.changeBackground(.shuffle)
        XCTAssertNotEqual(model.document.background.gradient, before)
        model.changeBackground(.palette(3))
        XCTAssertEqual(model.document.background.gradient?.base, ActivityBackgroundPalettes.darkest(ActivityBackgroundPalettes.all[3]))
        model.changeBackground(.colour("#112233"))
        XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: model.document), .colour)
        model.changeBackground(.gradient)
        XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: model.document), .gradient)
        XCTAssertTrue(actions.savedIds.isEmpty)
        await model.closePageRails()
        XCTAssertEqual(actions.savedIds.count, 1)
    }

    func testMoreImagesPushesThePickPageAndAThumbnailSetsTheImage() {
        let model = starterModel(ScriptedActivityActions())
        let nav = RecordingEditorNavigator()
        model.navigator = nav
        model.changeBackground(.moreImages)
        XCTAssertEqual(nav.pushed.last, .chooseActivityBackground(activityId: "a1"))
        model.changeBackground(.image("m9"), app: AppState())
        XCTAssertEqual(model.document.background.image?.mediaId, "m9")
        XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: model.document), .image)
    }

    // MARK: - text-activity-v2 round 5: one editor view (D26, D27, D28)

    private func appWithLesson(_ docs: [(id: String, kind: String)]) -> AppState {
        let app = AppState()
        for (index, entry) in docs.enumerated() {
            let document = entry.kind == "text" ? ActivityNewContainer.textDocument(title: entry.id)
                : ActivityDocument(raw: .object(["schemaVersion": .number(1), "kind": .string(entry.kind),
                                                 "background": .object(["color": .string("#000000")]),
                                                 "content": .object(["type": .string(entry.kind)])]))
            app.activities.upsert(ContentActivity(id: entry.id, lessonVersionId: "v1", activityKey: "k-\(entry.id)",
                                                  position: index, kind: entry.kind, title: entry.id,
                                                  document: document, estimatedSeconds: nil))
        }
        return app
    }

    func testAChipSwapsTheActivityInPlaceAfterSaving() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        let actions = ScriptedActivityActions()
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k-a1",
                                                    document: app.activities["a1"]!.document, actions: actions)
        model.navigator = nav
        model.tapEmpty(at: CGPoint(x: 220, y: 400)); model.edit(.init(index: 0, text: "Hi"))
        await model.selectSlide("a2", app: app)
        XCTAssertEqual(actions.savedIds, ["a1"])                 // the open edit committed and saved first
        XCTAssertEqual(model.activityId, "a2")
        XCTAssertEqual(model.document, app.activities["a2"]!.document)
        XCTAssertEqual(model.editingIndex, -1)
        XCTAssertEqual(model.canvasContent, .activity)
        XCTAssertTrue(nav.pushed.isEmpty)
        XCTAssertEqual(nav.pops, 0)
    }

    func testAKindTheEditorCantEditShowsReadOnly() async {
        let app = appWithLesson([("a1", "text"), ("v1", "video")])
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k-a1",
                                                    document: app.activities["a1"]!.document, actions: ScriptedActivityActions())
        await model.selectSlide("v1", app: app)
        XCTAssertEqual(model.activityId, "v1")
        XCTAssertEqual(model.canvasContent, .readOnly)
    }

    func testPlusShowsTheGridInPlaceAndAChipClosesIt() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k-a1",
                                                    document: app.activities["a1"]!.document, actions: ScriptedActivityActions())
        model.navigator = nav
        await model.addActivity()
        XCTAssertEqual(model.canvasContent, .typeGrid)
        await model.selectSlide("a1", app: app)
        XCTAssertEqual(model.canvasContent, .activity)
        XCTAssertEqual(model.activityId, "a1")
        XCTAssertTrue(nav.pushed.isEmpty)
    }

    func testPickingTextCreatesItAndOpensItInPlace() async {
        let app = appWithLesson([("a1", "text")])
        var createdKinds: [String] = []
        let newActions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v1" },
            create: { version, kind, title, document in
                createdKinds.append(kind)
                app.activities.upsert(ContentActivity(id: "n1", lessonVersionId: version, activityKey: "k-n1", position: 1,
                                                      kind: kind, title: title, document: document, estimatedSeconds: nil))
                return "n1"
            })
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k-a1",
                                                    document: app.activities["a1"]!.document,
                                                    actions: ScriptedActivityActions(), newActivityActions: newActions)
        await model.addActivity()
        await model.pickType("video")                           // unavailable tile: nothing happens
        XCTAssertTrue(createdKinds.isEmpty)
        await model.pickType("text", app: app)
        XCTAssertEqual(createdKinds, ["text"])
        XCTAssertEqual(model.activityId, "n1")
        XCTAssertEqual(model.canvasContent, .activity)
    }

    // MARK: - One save at a time

    /// Three saves started together run one after another: never two PUTs at once.
    func testConcurrentSavesRunOneAtATime() async {
        let actions = ScriptedActivityActions(saveDelayNanoseconds: 20_000_000)
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
        let first = Task { await model.retry() }
        let second = Task { await model.retry() }
        let third = Task { await model.retry() }
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
