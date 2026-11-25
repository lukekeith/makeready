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

    /// D37 (owner walk round 13): while the grid shows, an empty placeholder chip sits right after the selected
    /// activity and is the active chip; a chip tap closes the grid and the placeholder goes.
    func testPlusAddsAPlaceholderChipAfterTheSelectedActivity() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text"), ("a3", "text")])
        let model = ActivitiesEditorContainer.Model(activityId: "a3", activityKey: "k-a3",
                                                    document: app.activities["a3"]!.document, actions: ScriptedActivityActions())
        await model.selectSlide("a1", app: app)
        await model.addActivity()
        let grid = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(grid.slideIDs, ["a1", ActivityNewMapper.placeholderID, "a2", "a3"])
        XCTAssertEqual(grid.slideLabels[1], ActivityNewMapper.placeholderLabel)
        XCTAssertEqual(grid.activeID, ActivityNewMapper.placeholderID)
        await model.selectSlide("a2", app: app)
        let closed = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(closed.slideIDs, ["a1", "a2", "a3"])
        XCTAssertEqual(closed.activeID, "a2")
    }

    /// D37: the picked type's activity takes the placeholder's place — created (appended by the server), then the
    /// draft is reordered so it follows the activity that was selected.
    func testThePickedActivityLandsAfterTheSelectedOne() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        var reorders: [[String]] = []
        let newActions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v1" },
            create: { version, kind, title, document in
                app.activities.upsert(ContentActivity(id: "n1", lessonVersionId: version, activityKey: "k-n1", position: 2,
                                                      kind: kind, title: title, document: document, estimatedSeconds: nil))
                return "n1"
            },
            reorder: { _, ids in reorders.append(ids) })
        let model = ActivitiesEditorContainer.Model(activityId: "a2", activityKey: "k-a2",
                                                    document: app.activities["a2"]!.document,
                                                    actions: ScriptedActivityActions(), newActivityActions: newActions)
        await model.selectSlide("a1", app: app)
        await model.addActivity()
        await model.pickType("text", app: app)
        XCTAssertEqual(reorders, [["a1", "n1", "a2"]])
        XCTAssertEqual(model.activityId, "n1")
    }

    /// D37: with the last activity selected the new one already lands in place — no reorder.
    func testAddingAfterTheLastActivityNeedsNoReorder() async {
        let app = appWithLesson([("a1", "text")])
        var reorders: [[String]] = []
        let newActions = ActivityNewContainer.Actions(
            draftVersionId: { _ in "v1" },
            create: { version, kind, title, document in
                app.activities.upsert(ContentActivity(id: "n1", lessonVersionId: version, activityKey: "k-n1", position: 1,
                                                      kind: kind, title: title, document: document, estimatedSeconds: nil))
                return "n1"
            },
            reorder: { _, ids in reorders.append(ids) })
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k-a1",
                                                    document: app.activities["a1"]!.document,
                                                    actions: ScriptedActivityActions(), newActivityActions: newActions)
        await model.addActivity()
        await model.pickType("text", app: app)
        XCTAssertTrue(reorders.isEmpty)
    }

    // MARK: - video-recorder D18: the inline recorder, the pending row and Replace video

    private var recorderDir: URL!

    override func setUp() async throws {
        recorderDir = FileManager.default.temporaryDirectory.appendingPathComponent("EditorRecorder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: recorderDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: recorderDir.lastPathComponent)
        try FileManager.default.removeItem(at: recorderDir)
    }

    /// `holds` keeps the export from ending, so the video stays "being saved".
    private func makeSaver(queue: QueueSpy, holds: Bool = false) -> VideoSaver {
        VideoSaver(drafts: VideoDraftStore(root: recorderDir), queue: queue,
                   nextTitle: { MemoActions.nextDefaultTitle(prefix: "Video", existingTitles: queue.items.map(\.title)) },
                   report: { _, message, _ in XCTFail(message) },
                   export: { _, _, _, _, _, url in
                       if holds { try await Task.sleep(for: .seconds(60)) }
                       return ExportedVideo(url: url, durationSeconds: 3, posterImage: nil)
                   },
                   transcribe: { _, _ in nil }, waitForForeground: { false })
    }

    private func makeRecorderModel(entry: VideoRecorderEntry, queue: QueueSpy, saver: VideoSaver? = nil) -> VideoRecorderModel {
        VideoRecorderModel(
            entry: entry,
            engine: VideoCaptureEngine(session: FakeCaptureSession(), drafts: VideoDraftStore(root: recorderDir),
                                       freeBytes: { nil }, notificationCenter: NotificationCenter()),
            settings: RecorderSettings(defaults: UserDefaults(suiteName: recorderDir.lastPathComponent)!),
            player: ReviewPlayerSpy(), saver: saver ?? makeSaver(queue: queue), recoverDraft: { nil }, beep: { _ in },
            report: { _, message in XCTFail(message) }, loadNotes: {}, now: { 0 })
    }

    private func queued(localId: String, attach: VideoAttach?, stage: VideoUploadStage = .queued,
                        serverId: String? = nil, poster: String? = nil) -> VideoQueueItem {
        VideoQueueItem(
            localId: localId, fileName: "\(localId).mp4", posterFileName: poster, title: attach?.title ?? "V", durationSeconds: 12,
            source: .recording, transcript: nil, createdAt: Date(timeIntervalSince1970: 0), streamUid: nil, serverId: serverId,
            stage: stage, failures: 0, polls: 0, nextAttemptAt: nil, attach: attach, ownerUserId: "u1", environment: "test")
    }

    private func saving(localId: String, attach: VideoAttach?) -> VideoSavingItem {
        VideoSavingItem(localId: localId, title: attach?.title ?? "V", durationSeconds: 12,
                        savedAt: Date(timeIntervalSince1970: 0), attach: attach)
    }

    private func editor(app: AppState, at id: String, queue: QueueSpy, saver: VideoSaver? = nil) -> ActivitiesEditorContainer.Model {
        let model = ActivitiesEditorContainer.Model(
            activityId: id, activityKey: "k-\(id)", document: app.activities[id]!.document, lessonId: "l1",
            lessonVersionId: "v1", actions: ScriptedActivityActions())
        model.makeRecorder = { self.makeRecorderModel(entry: $0, queue: queue, saver: saver) }
        return model
    }

    func testPendingVideoActivity() {
        let q = [queued(localId: "L1", attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 3")),
                 queued(localId: "L2", attach: VideoAttach(versionId: "other", activityId: nil, title: "Video 4"))]
        let rows = ActivitiesEditorMapper.pendingVideoActivities(queued: q, versionId: "ver1")
        XCTAssertEqual(rows.map(\.id), ["local:L1"])
        XCTAssertEqual(rows.first?.statusText, "Uploading…")
    }

    func testAReplacementOrAFinishedAttachIsNotAPendingActivity() {
        let new = VideoAttach(versionId: "ver1", activityId: nil, title: "Video 3")
        let q = [queued(localId: "L1", attach: VideoAttach(versionId: "ver1", activityId: "a1", title: "V")),
                 queued(localId: "L2", attach: new, stage: .attaching, serverId: "s2"),
                 queued(localId: "L3", attach: new, stage: .processing, serverId: "s3"),
                 queued(localId: "L4", attach: new, stage: .creating, serverId: "s4"),
                 queued(localId: "L5", attach: nil)]
        XCTAssertEqual(ActivitiesEditorMapper.pendingVideoActivities(queued: q, versionId: "ver1").map(\.id), ["local:L4"])
        // The activity landed before the stage moved on.
        XCTAssertEqual(ActivitiesEditorMapper.pendingVideoActivities(queued: q, versionId: "ver1", attachedVideoIds: ["s4"]), [])
    }

    /// D12: a video still exporting is listed too, once.
    func testAVideoBeingSavedIsAPendingActivityUntilTheQueueHoldsIt() {
        let attach = VideoAttach(versionId: "ver1", activityId: nil, title: "Video 3")
        let items = [saving(localId: "L1", attach: attach),
                     saving(localId: "L2", attach: VideoAttach(versionId: "other", activityId: nil, title: "V")),
                     saving(localId: "L3", attach: nil)]
        let rows = ActivitiesEditorMapper.pendingVideoActivities(queued: [], saving: items, versionId: "ver1")
        XCTAssertEqual(rows.map(\.id), ["local:L1"])
        XCTAssertEqual(rows.first?.statusText, "Uploading…")
        let both = ActivitiesEditorMapper.pendingVideoActivities(
            queued: [queued(localId: "L1", attach: attach, poster: "L1.jpg")], saving: items, versionId: "ver1")
        XCTAssertEqual(both.map(\.id), ["local:L1"])
        XCTAssertNotNil(both.first?.posterURL)
        // Attached while the saver still lists it: no pending row comes back.
        XCTAssertEqual(ActivitiesEditorMapper.pendingVideoActivities(
            queued: [queued(localId: "L1", attach: attach, stage: .processing)], saving: items, versionId: "ver1"), [])
    }

    func testReplaceVideoAttach() async {
        let queue = QueueSpy()
        let m = makeRecorderModel(entry: .lesson(versionId: "ver1", activityId: "act9"), queue: queue)
        m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
        await m.save()
        XCTAssertEqual(queue.items.first?.attach, VideoAttach(versionId: "ver1", activityId: "act9", title: "Video 1"))
    }

    func testReplaceVideoOpensTheInlineRecorderForThatActivity() async {
        let app = appWithLesson([("a1", "text"), ("v1", "video")])
        let queue = QueueSpy()
        let model = editor(app: app, at: "a1", queue: queue)
        await model.selectSlide("v1", app: app)
        model.replaceVideo(app: app)
        XCTAssertEqual(model.recorder?.entry, .lesson(versionId: "v1", activityId: "v1"))
        let state = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(state.canvasContent, "videoRecorder")
        XCTAssertEqual(state.activeID, "v1")
        XCTAssertEqual(state.slideIDs, ["a1", "v1"])
    }

    /// P3: the header and the strip hide from the countdown to the stop, and show otherwise.
    func testTheChromeHidesOnlyWhileRecording() async throws {
        let app = appWithLesson([("a1", "text")])
        let model = editor(app: app, at: "a1", queue: QueueSpy())
        await model.addActivity()
        await model.pickType("video", app: app)
        let recorder = try XCTUnwrap(model.recorder)
        func hidden() -> Bool { ActivitiesEditorContainer.screenState(model, app: app).videoRecorderHidesChrome }
        XCTAssertFalse(hidden())
        recorder.recordTapped()
        XCTAssertTrue(hidden())
        recorder.tick(recorded: 55)
        XCTAssertTrue(hidden())
        recorder.recordTapped()
        XCTAssertFalse(hidden())
        recorder.rail(.countdown)
        recorder.recordTapped()
        XCTAssertTrue(hidden())
        recorder.recordTapped()
        XCTAssertFalse(hidden())
        await recorder.settled()
    }

    func testTheGridsVideoTileOpensTheRecorderWithAPlaceholderChip() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        let model = editor(app: app, at: "a1", queue: QueueSpy())
        await model.addActivity()
        await model.pickType("video", app: app)
        XCTAssertEqual(model.recorder?.entry, .lesson(versionId: "v1", activityId: nil))
        let state = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(state.canvasContent, "videoRecorder")
        // The server appends the activity, so its chip waits at the end.
        XCTAssertEqual(state.slideIDs, ["a1", "a2", "placeholder"])
        XCTAssertEqual(state.activeID, "placeholder")
    }

    func testSavingANewVideoShowsItsPendingActivity() async {
        let app = appWithLesson([("a1", "text")])
        let queue = QueueSpy()
        let saver = makeSaver(queue: queue, holds: true)
        app.videoSaves = saver
        let model = editor(app: app, at: "a1", queue: queue, saver: saver)
        await model.addActivity()
        await model.pickType("video", app: app)
        let recorder = model.recorder!
        recorder.recordTapped(); recorder.tick(recorded: 3); recorder.recordTapped()
        let save = Task { await recorder.save() }
        for _ in 0..<200 where model.recorder != nil { await Task.yield() }
        let localId = saver.saving[0].localId
        XCTAssertNil(model.recorder)
        let state = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(state.canvasContent, "videoPending")
        XCTAssertEqual(state.slideIDs, ["a1", "local:\(localId)"])
        XCTAssertEqual(state.slideLabels.last, "Video 1, Uploading…")
        XCTAssertEqual(state.activeID, "local:\(localId)")
        // Another chip and back.
        await model.selectSlide("a1", app: app)
        XCTAssertEqual(model.canvasContent, .activity)
        await model.selectSlide("local:\(localId)", app: app)
        XCTAssertEqual(model.canvasContent, .videoPending)
        saver.cancel()
        await save.value
    }

    func testSavingAReplacementShowsThePendingVideoOnItsActivity() async {
        let app = appWithLesson([("a1", "text"), ("v1", "video")])
        let queue = QueueSpy()
        let saver = makeSaver(queue: queue, holds: true)
        app.videoSaves = saver
        let model = editor(app: app, at: "a1", queue: queue, saver: saver)
        await model.selectSlide("v1", app: app)
        model.replaceVideo(app: app)
        let recorder = model.recorder!
        recorder.recordTapped(); recorder.tick(recorded: 3); recorder.recordTapped()
        let save = Task { await recorder.save() }
        for _ in 0..<200 where model.recorder != nil { await Task.yield() }
        let state = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual(state.activeID, "v1")
        XCTAssertEqual(state.slideIDs, ["a1", "v1"])
        XCTAssertEqual(state.canvasContent, "videoPending")
        saver.cancel()
        await save.value
        XCTAssertEqual(ActivitiesEditorContainer.screenState(model, app: app).canvasContent, "readOnly")
    }

    func testAPendingVideoBecomesItsActivityOnceAttached() async {
        let app = appWithLesson([("a1", "text")])
        let model = editor(app: app, at: "a1", queue: QueueSpy())
        let attach = VideoAttach(versionId: "v1", activityId: nil, title: "Video 1")
        let pending = ActivitiesEditorMapper.pendingVideoActivities(queued: [queued(localId: "L1", attach: attach)], versionId: "v1")
        await model.selectSlide("local:L1", app: app, pending: pending)
        XCTAssertEqual(model.canvasContent, .videoPending)
        app.activities.upsert(ContentActivity(id: "new1", lessonVersionId: "v1", activityKey: "k-new1", position: 1, kind: "video",
                                              title: "Video 1", document: LiveVideoUploadAPI.videoDocument(videoId: "s1", title: "Video 1"),
                                              estimatedSeconds: nil))
        await model.settlePendingVideo(app: app, pending: [], serverId: { $0 == "L1" ? "s1" : nil })
        XCTAssertEqual(model.activityId, "new1")
        XCTAssertEqual(model.canvasContent, .readOnly)
    }

    /// D18: a refused attach (or a deleted video) leaves no activity to show.
    func testAPendingVideoThatNeverAttachesFallsBackToTheFirstActivity() async {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        let model = editor(app: app, at: "a2", queue: QueueSpy())
        let attach = VideoAttach(versionId: "v1", activityId: nil, title: "Video 1")
        let pending = ActivitiesEditorMapper.pendingVideoActivities(queued: [queued(localId: "L1", attach: attach)], versionId: "v1")
        await model.selectSlide("local:L1", app: app, pending: pending)
        await model.settlePendingVideo(app: app, pending: pending, serverId: { _ in nil })
        XCTAssertEqual(model.activityId, "local:L1")
        await model.settlePendingVideo(app: app, pending: [], serverId: { _ in nil })
        XCTAssertEqual(model.activityId, "a1")
        XCTAssertEqual(model.canvasContent, .activity)
    }

    func testLeavingTheRecorderWithAClipAsksFirst() async throws {
        let app = appWithLesson([("a1", "text"), ("a2", "text")])
        let nav = RecordingEditorNavigator()
        let model = editor(app: app, at: "a1", queue: QueueSpy())
        model.navigator = nav
        await model.addActivity()
        await model.pickType("video", app: app)
        let recorder = try XCTUnwrap(model.recorder)
        recorder.recordTapped(); recorder.tick(recorded: 3); recorder.recordTapped()
        await recorder.settled()
        await model.back()
        XCTAssertEqual(recorder.confirm, .discard)
        XCTAssertEqual(nav.pops, 0)
        // Not discarded: the recorder stays, and the next way out is the one that counts.
        recorder.dismissConfirm()
        XCTAssertNotNil(model.recorder)
        await model.selectSlide("a2", app: app)
        XCTAssertEqual(recorder.confirm, .discard)
        recorder.discardConfirmed()
        for _ in 0..<50 { await Task.yield() }
        XCTAssertNil(model.recorder)
        XCTAssertEqual(model.activityId, "a2")
        XCTAssertEqual(model.canvasContent, .activity)
        XCTAssertEqual(nav.pops, 0)
        await recorder.settled()
    }

    func testBackFromAnEmptyRecorderLeavesTheEditor() async {
        let app = appWithLesson([("a1", "text")])
        let nav = RecordingEditorNavigator()
        let model = editor(app: app, at: "a1", queue: QueueSpy())
        model.navigator = nav
        await model.addActivity()
        await model.pickType("video", app: app)
        let recorder = model.recorder!
        await model.back()
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(nav.pops, 1)
        XCTAssertTrue(recorder.isClosed)
        await recorder.settled()
    }

    /// The New Activity page's Video tile: no activity yet, so the editor opens on the recorder.
    func testTheEditorCanOpenOnTheRecorderWithNoActivity() async {
        let app = AppState()
        let nav = RecordingEditorNavigator()
        let queue = QueueSpy()
        let model = ActivitiesEditorContainer.Model.recording(lessonId: "l1", versionId: "v1")
        model.navigator = nav
        XCTAssertEqual(ActivitiesEditorContainer.screenState(model, app: app).canvasContent, "videoRecorder")
        model.makeRecorder = { self.makeRecorderModel(entry: $0, queue: queue) }
        model.openPendingRecorder(app: app)
        XCTAssertEqual(model.recorder?.entry, .lesson(versionId: "v1", activityId: nil))
        XCTAssertEqual(ActivitiesEditorContainer.screenState(model, app: app).slideIDs, ["placeholder"])
        let recorder = model.recorder!
        model.openPendingRecorder(app: app)
        XCTAssertTrue(model.recorder === recorder)
        await recorder.settled()
    }

    func testARecorderThatCannotOpenLeavesNoBlankPage() {
        let nav = RecordingEditorNavigator()
        let model = ActivitiesEditorContainer.Model.recording(lessonId: "l1", versionId: "v1")
        model.navigator = nav
        model.makeRecorder = { _ in nil }
        model.openPendingRecorder(app: AppState())
        XCTAssertEqual(nav.pops, 1)
    }

    // MARK: - video-recorder D18: the editor opened on a video activity

    private func videoActivity(_ id: String, key: String = "k", version: String, position: Int = 0) -> ContentActivity {
        ContentActivity(id: id, lessonVersionId: version, activityKey: key, position: position, kind: "video", title: "Video",
                        document: LiveVideoUploadAPI.videoDocument(videoId: "vid1", title: "Video"), estimatedSeconds: nil)
    }

    private func appWithDraft(_ activities: [ContentActivity]) -> AppState {
        let app = AppState()
        app.lessonVersions.upsert(LessonVersion(id: "ver1", lessonId: "l1", enrollmentId: nil, number: 1, status: .draft,
                                                title: nil, estimatedSeconds: nil, publishedAt: nil))
        activities.forEach { app.activities.upsert($0) }
        return app
    }

    private func videoEntry(poster: String? = nil, playback: String = "https://x/v.m3u8") -> MediaMapEntry {
        MediaMapEntry(url: playback, width: nil, height: nil, kind: "video", playbackUrl: playback, posterUrl: poster,
                      durationSeconds: nil, uploaderName: nil)
    }

    /// A Model on lesson l1, version ver1, with a silent log, opened on the video activity `at`.
    private func videoEditor(app: AppState, actions: ScriptedActivityActions, at id: String = "vi1",
                             log: @escaping (Error, String) -> Void = { _, _ in }) -> ActivitiesEditorContainer.Model {
        let model = ActivitiesEditorContainer.Model(activityId: "", activityKey: "", lessonId: "l1", lessonVersionId: "ver1",
                                                    actions: actions, log: log)
        model.open(app.activities[id]!)
        return model
    }

    func testAVideoPageShowsItsStillAndNoTitle() async {
        let app = appWithDraft([videoActivity("vi1", version: "ver1")])
        app.mergeMedia(["vid1": videoEntry(poster: "https://x/still")])
        let model = ActivitiesEditorContainer.Model.resolving(activityId: "vi1", app: app)
        let state = ActivitiesEditorContainer.screenState(model, app: app)
        XCTAssertEqual([state.readOnlyPosterURL, state.readOnlyTitle], ["https://x/still", ""])
        XCTAssertNil(model.missingStillVideoId(app: app))
        XCTAssertTrue(ActivitiesEditorContainer.pageImageURLs(of: state).contains("https://x/still"))
    }

    func testAMissingStillIsFollowedThenTheDraftReloads() async {
        let app = appWithDraft([videoActivity("vi1", version: "ver1")])
        let actions = ScriptedActivityActions()
        var logged: [String] = []
        let model = videoEditor(app: app, actions: actions, log: { _, context in logged.append(context) })
        XCTAssertEqual(model.missingStillVideoId(app: app), "vid1")
        model.waitForVideo = { _ in false }
        await model.followMissingStill(app: app)
        model.waitForVideo = { _ in throw URLError(.timedOut) }
        await model.followMissingStill(app: app)
        model.waitForVideo = { _ in true }
        let cancelled = Task { await model.followMissingStill(app: app) }
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(actions.reloads, 0)
        XCTAssertEqual(logged, ["ActivitiesEditorContainer.followMissingStill"])
        await model.followMissingStill(app: app)
        XCTAssertEqual(actions.reloads, 1)
    }

    // MARK: - video-activity-basics D4, D5, D7, D11, D15: remove from the lesson, delete everywhere

    private var a2: ContentActivity { videoActivity("a2", key: "k-a", version: "ver2") }
    private var z: ContentActivity { videoActivity("z", key: "k-z", version: "ver2", position: 1) }

    /// One video activity per id (key `k-<id>`, all of vid1, in ver1), the editor on `at`. Confirm reads answer allowed;
    /// a video delete or a banner fails the test unless the test swaps it.
    private func deleting(_ ids: [String], at: String = "a", draft: [ContentActivity] = [],
                          steps: [ScriptedActivityActions.Step] = [])
        -> (app: AppState, model: ActivitiesEditorContainer.Model, actions: ScriptedActivityActions) {
        let app = appWithDraft(ids.enumerated().map { videoActivity($1, key: "k-\($1)", version: "ver1", position: $0) })
        let actions = ScriptedActivityActions(deleteSteps: steps, draft: draft)
        let model = videoEditor(app: app, actions: actions, at: at)
        model.readDeleteEverywhere = { _ in .allowed }
        model.deleteVideo = { id in XCTFail("deleted video \(id)") }
        model.report = { _, text in XCTFail("banner \(text)") }
        return (app, model, actions)
    }

    private func remove(_ d: (app: AppState, model: ActivitiesEditorContainer.Model, actions: ScriptedActivityActions),
                        everywhere: Bool = false) async {
        await d.model.openDeleteConfirm(app: d.app)
        await d.model.removeVideo(everywhere: everywhere, app: d.app)
    }

    private func shown(_ d: (app: AppState, model: ActivitiesEditorContainer.Model, actions: ScriptedActivityActions))
        -> ActivitiesEditorScreen.State {
        ActivitiesEditorContainer.screenState(d.model, app: d.app)
    }

    func testRemoveOpensTheNextThenThePreviousThenTheGrid() async {
        for (ids, at, next) in [(["a", "b", "c"], "b", "c"), (["a", "b"], "b", "a"), (["a"], "a", "")] {
            let d = deleting(ids, at: at)
            await remove(d)
            XCTAssertEqual(d.actions.deletedIds + [d.model.activityId], [at, next])
            XCTAssertEqual(d.model.canvasContent, next.isEmpty ? .typeGrid : .readOnly)
            XCTAssertEqual(d.actions.savedIds, [])
        }
    }

    func testEverywhereDeletesTheActivityThenTheVideo() async {
        let d = deleting(["a", "b"])
        var order: [String] = [], banners: [String] = []
        d.actions.onDelete = { order.append("activity") }
        d.model.deleteVideo = { order.append($0); throw URLError(.badServerResponse) }
        d.model.report = { banners.append($1) }
        await remove(d, everywhere: true)
        XCTAssertEqual(order, ["activity", "vid1"])
        XCTAssertEqual(banners, ["Removed from the lesson, but couldn't delete the video"])
        XCTAssertEqual(d.model.activityId, "b")
    }

    func testAFailedRemovalKeepsThePageAndTheVideo() async {
        let steps: [[ScriptedActivityActions.Step]] = [[.failure(.other)], [.failure(.notDraft), .failure(.notDraft)]]
        for (failing, id) in zip(steps, ["a", "a2"]) {
            let d = deleting(["a", "b"], draft: [a2], steps: failing)
            var banners: [String] = []
            d.model.report = { banners.append($1) }
            await remove(d, everywhere: true)
            XCTAssertEqual(banners, ["Couldn't remove the video"])
            XCTAssertEqual(d.model.activityId, id)
            XCTAssertFalse(d.model.isDeleting)
        }
    }

    func testAFrozenDraftRetriesOnceByKey() async {
        for failure in [ScriptedActivityActions.Failure.notDraft, .gone] {
            let d = deleting(["a"], draft: [a2], steps: [.failure(failure)])
            await remove(d)
            XCTAssertEqual(d.actions.deletedIds, ["a", "a2"])
            XCTAssertEqual(d.model.lessonVersionId, "ver2")
        }
        let absent = deleting(["a"], draft: [z], steps: [.failure(.gone)])
        absent.app.activities.upsert(z)
        await remove(absent)
        XCTAssertEqual(absent.actions.deletedIds + [absent.model.activityId], ["a", "z"])
    }

    func testTheConfirmReadsTheCounts() async {
        let d = deleting(["a", "b"])
        XCTAssertEqual(shown(d).deleteEverywhereNote, "Checking where it's used…")
        d.model.readDeleteEverywhere = { _ in .published }
        await d.model.openDeleteConfirm(app: d.app)
        XCTAssertEqual(shown(d).deleteEverywhereNote, "Used in a published lesson")
        XCTAssertFalse(shown(d).deleteEverywhereEnabled)
        await remove(d, everywhere: true)
        XCTAssertEqual(d.actions.deletedIds, [])
        d.model.readDeleteEverywhere = { _ in throw URLError(.timedOut) }
        await d.model.openDeleteConfirm(app: d.app)
        XCTAssertEqual(d.model.deleteEverywhereState, .unknown)
        d.model.readDeleteEverywhere = { _ in await d.model.selectSlide("b", app: d.app); return .allowed }
        await d.model.openDeleteConfirm(app: d.app)
        XCTAssertEqual(d.model.deleteEverywhereState, .checking)
    }

    func testChoicesAreIgnoredWhileDeleting() async {
        let d = deleting(["a", "b"])
        d.model.makeRecorder = { _ in XCTFail("deleting"); return nil }
        d.model.makePlayer = { XCTFail("deleting"); return FakeInlinePlayer() }
        d.app.mergeMedia(["vid1": videoEntry()])
        d.actions.onDelete = {
            d.model.replaceVideo(app: d.app)
            d.model.videoTapped(app: d.app)
            await d.model.removeVideo(everywhere: false, app: d.app)
        }
        await remove(d)
        XCTAssertEqual(d.actions.deletedIds, ["a"])
    }

    // MARK: - video-activity-basics D3, D12: tap to play inline

    @MainActor
    private final class FakeInlinePlayer: VideoPlaying {
        var elapsed: Double = 0
        var isPlaying = false
        var isReady = true
        let layer: CALayer? = CALayer()
        private(set) var loads = 0
        private(set) var stops = 0
        func load(url: URL, duration: Double) { loads += 1 }
        func play() { isPlaying = true }
        func pause() { isPlaying = false }
        func seek(to seconds: Double) { elapsed = seconds }
        func skip(by seconds: Double) { elapsed += seconds }
        func stop() { stops += 1; isPlaying = false }
    }

    /// An editor on video page vi1 (of vi1, vi2) whose player is `player`; `playback` is the stream vid1 has.
    private func playing(_ player: FakeInlinePlayer, playback: String? = "https://x/v.m3u8")
        -> (AppState, ActivitiesEditorContainer.Model) {
        let app = appWithDraft([videoActivity("vi1", version: "ver1"), videoActivity("vi2", version: "ver1", position: 1)])
        app.mergeMedia(["vid1": MediaMapEntry(url: "https://x/v", width: nil, height: nil, kind: "video", playbackUrl: playback,
                                              posterUrl: "https://x/still", durationSeconds: nil, uploaderName: nil)])
        let model = videoEditor(app: app, actions: ScriptedActivityActions())
        model.makePlayer = { player }
        model.makeRecorder = { self.makeRecorderModel(entry: $0, queue: QueueSpy()) }
        return (app, model)
    }

    func testATapPlaysAndPausesTheVideo() {
        let player = FakeInlinePlayer()
        let (app, model) = playing(player)
        XCTAssertEqual(player.loads, 0)
        model.videoTapped(app: app)
        XCTAssertTrue(player.isPlaying)
        XCTAssertTrue(model.videoLayer === player.layer)
        model.videoTapped(app: app)
        XCTAssertFalse(player.isPlaying)
        model.videoTapped(app: app)
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(player.loads, 1)
    }

    func testATapWithNoStreamDoesNothing() {
        for playback in [nil, ""] {
            let player = FakeInlinePlayer()
            let (app, model) = playing(player, playback: playback)
            model.videoTapped(app: app)
            XCTAssertFalse(player.isPlaying)
            XCTAssertNil(model.videoLayer)
        }
    }

    func testLeavingOrBackgroundingStopsTheVideo() async {
        let leaving: [(ActivitiesEditorContainer.Model, AppState) async -> Void] = [
            { m, app in await m.selectSlide("vi2", app: app) },
            { m, _ in await m.addActivity() },
            { m, _ in await m.back() },
            { m, app in m.replaceVideo(app: app) }
        ]
        for leave in leaving {
            let player = FakeInlinePlayer()
            let (app, model) = playing(player)
            model.videoTapped(app: app)
            await leave(model, app)
            XCTAssertEqual(player.stops, 1)
            XCTAssertNil(model.videoLayer)
        }
        let player = FakeInlinePlayer()
        let (app, model) = playing(player)
        model.videoTapped(app: app)
        model.pauseVideo()
        XCTAssertFalse(player.isPlaying)
        XCTAssertNotNil(model.videoLayer)
    }

    /// Replace video is reachable in a lesson whose only activity is a video.
    private func assertReplaceVideoOpens(app: AppState, on id: String) {
        let queue = QueueSpy()
        let model = ActivitiesEditorContainer.Model.resolving(activityId: id, app: app)
        model.makeRecorder = { self.makeRecorderModel(entry: $0, queue: queue) }
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.canvasContent, .readOnly)
        XCTAssertEqual(ActivitiesEditorContainer.screenState(model, app: app).readOnlyKind, "video")
        model.replaceVideo(app: app)
        XCTAssertEqual(model.recorder?.entry, .lesson(versionId: "ver1", activityId: id))
    }

    func testAVideoOnlyLessonOpensOnItsVideoWithReplaceVideo() {
        assertReplaceVideoOpens(app: appWithDraft([videoActivity("vi1", version: "ver1")]), on: "vi1")
    }

    func testAMixedLessonOpensOnItsVideoAndItsTextStaysEditable() async {
        let text = ContentActivity(id: "a1", lessonVersionId: "ver1", activityKey: "k-a1", position: 0, kind: "text", title: "Text",
                                   document: ActivityNewContainer.textDocument(title: "Text"), estimatedSeconds: nil)
        let app = appWithDraft([text, videoActivity("vi1", version: "ver1", position: 1)])
        assertReplaceVideoOpens(app: app, on: "vi1")
        let model = ActivitiesEditorContainer.Model.resolving(activityId: "vi1", app: app)
        XCTAssertEqual(ActivitiesEditorContainer.screenState(model, app: app).slideIDs, ["a1", "vi1"])
        await model.selectSlide("a1", app: app)
        XCTAssertEqual(model.canvasContent, .activity)
        XCTAssertEqual(ActivitiesEditorContainer.Model.resolving(activityId: "a1", app: app).canvasContent, .activity)
    }

    /// The same, for a slide of a lesson whose draft is not loaded.
    func testLoadOpensADraftsVideoReadOnly() async {
        let app = appWithActivityOutsideADraft()
        let row = videoActivity("a2", key: "k1", version: "ver2")
        let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "", phase: .loading,
                                                    actions: ScriptedActivityActions(draft: [row]), log: { _, _ in })
        await model.load(app: app)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.canvasContent, .readOnly)
        XCTAssertEqual(model.kind, "video")
        XCTAssertEqual(model.lessonVersionId, "ver2")
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
    /// Destinations pushed together in one path write (`pushAll`).
    var pushedTogether: [[UI2Destination]] = []
    func push(_ destination: UI2Destination) { pushed.append(destination) }
    func pushAll(_ destinations: [UI2Destination]) { pushedTogether.append(destinations) }
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
    private var deleteSteps: [Step]
    /// Runs inside `delete`, after the id is recorded and before its step.
    var onDelete: () async -> Void = {}
    private let draft: [ContentActivity]
    private let reloadFails: Bool
    private let saveDelayNanoseconds: UInt64
    private var activeSaves = 0
    private(set) var maxConcurrentSaves = 0
    private(set) var savedIds: [String] = []
    private(set) var savedDocuments: [ActivityDocument] = []
    private(set) var deletedIds: [String] = []
    private(set) var reloads = 0

    init(save: [Step] = [], deleteSteps: [Step] = [], draft: [ContentActivity] = [], reloadFails: Bool = false,
         saveDelayNanoseconds: UInt64 = 0) {
        steps = save
        self.deleteSteps = deleteSteps
        self.draft = draft
        self.reloadFails = reloadFails
        self.saveDelayNanoseconds = saveDelayNanoseconds
    }

    func reloadDraft(lessonId: String) async throws -> [ContentActivity] {
        reloads += 1
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

    func delete(activityId: String) async throws {
        deletedIds.append(activityId)
        await onDelete()
        switch deleteSteps.isEmpty ? .success : deleteSteps.removeFirst() {
        case .success: return
        case .failure(.notDraft): throw ActivityActionsError.notDraft
        case .failure(.gone): throw ActivityActionsError.gone
        case .failure(.other): throw Other()
        }
    }
}

extension Array where Element == ContentActivity {
    /// A reloaded draft holding one activity with this id and key.
    @MainActor
    static func withActivity(id: String, key: String) -> [ContentActivity] {
        [ContentActivity(id: id, lessonVersionId: "v2", activityKey: key, position: 0, kind: "text", title: "Text",
                         document: ActivityNewContainer.textDocument(title: "Text"), estimatedSeconds: nil)]
    }
}
