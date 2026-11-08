import SwiftUI

/// Where the editor sends the leader: the viewer and the image pick (push), another activity or the
/// type picker (in place), back (pop).
@MainActor
protocol ActivitiesEditorNavigating: AnyObject {
    func push(_ destination: UI2Destination)
    func replace(with destination: UI2Destination)
    func pop()
}

/// text-activity D16/D17/D22/D33/D39/D40/D46: the `.activitiesEditor` destination. It owns the
/// activity's edit buffer — the whole document, patched by each of the screen's object edits so every
/// field the screen doesn't edit passes through — maps it to `ActivitiesEditorScreen.State`, and saves
/// it whole on Done, optimistically: the canvas commits at once and the PUT runs behind (§3 Saving).
/// A save refused with 409 `NOT_DRAFT` reloads the draft, finds the activity by `activityKey` and
/// re-PUTs once; a failure after that raises the screen's "Couldn't save activity" alert (D46).
/// Backing out of an untouched activity deletes it (D16).
struct ActivitiesEditorContainer: View {
    let activityId: String

    static let loadContext = "ActivitiesEditorContainer.load"

    @Environment(\.ui2Navigator) private var navigator
    /// This page's veto on the shell's edge swipe: leaving always runs `back()` (save or D16 delete).
    @Environment(\.ui2BackSwipeGuard) private var backSwipe
    @State private var model: Model
    /// Bumped when the background image lands in Ui2ImageCache, which SwiftUI does not observe.
    @State private var imagesSeeded = 0

    init(activityId: String) {
        self.activityId = activityId
        _model = State(initialValue: Model.resolving(activityId: activityId))
    }

    var body: some View {
        let _ = imagesSeeded
        let state = Self.screenState(model, app: AppState.shared)
        ActivitiesEditorScreen(
            state: state,
            onBack: { Task { await model.back() } },
            onCancel: { model.cancel() },
            onDone: { Task { await model.done() } },
            onSelectSlide: { id in Task { await model.selectSlide(id) } },
            onAdd: { Task { await model.addActivity() } },
            onTapEmpty: { point in model.tapEmpty(at: point) },
            onTapObject: { index in model.tapObject(index) },
            onEditObject: { edit in model.edit(edit) },
            onPlay: { Task { await model.play() } },
            onLoadFailed: { message in Self.surfaceLoadFailure(message) },
            onPickImage: { model.pickImage() },
            onChangeBackground: { background in model.changeBackground(background) },
            onChangeActions: { actions in Task { await model.changeActions(actions) } },
            onRetry: { Task { await model.retry() } },
            onDiscard: { model.discard() }
        )
        // The screen seeds its sheets' buffers and its alert from `State` once, at init; a new
        // generation (loaded, a failed save, a discard) re-seeds them.
        .id(model.screenGeneration)
        .ui2PushedPageFill()
        .onAppear {
            model.navigator = LiveNavigator(navigator: navigator, current: .activitiesEditor(activityId: activityId))
            backSwipe?.blocksBackSwipe = { true }
            backSwipe?.onBlockedBackSwipe = { [model] in Task { await model.back() } }
            // D40: the Media pick mode delivers here; the page is back on top.
            model.takeBackgroundPick()
        }
        .task { await model.load() }
        .task(id: state.pageImageURL) {
            if await UI2ImageLoader.seed([state.pageImageURL], context: "ActivitiesEditorContainer") { imagesSeeded += 1 }
        }
    }

    /// The screen's state: the buffer mapped over the version's slides, plus the mode and flags.
    @MainActor
    static func screenState(_ model: Model, app: AppState) -> ActivitiesEditorScreen.State {
        var state = ActivitiesEditorMapper.state(document: model.document, media: app.mediaMap,
                                                 slides: app.activities(forVersion: model.lessonVersionId),
                                                 activeID: model.activityId)
        state.editorMode = model.editingIndex >= 0 ? "editing" : "idle"
        state.editingIndex = model.editingIndex
        state.saving = model.isSaving
        state.saveFailed = model.saveError != nil
        state.loadFailed = model.phase == .failed
        return state
    }

    /// D33 item 4 (/ios-error-surface): the leader opened this activity, so its load failure is a banner.
    @MainActor
    static func surfaceLoadFailure(_ message: String) {
        AppState.shared.recordError(LoadFailed(), context: loadContext, surface: true, friendlyMessage: message)
    }

    private struct LoadFailed: Error {}

    /// The live seam: `UI2Navigator.replaceTop` needs the page being replaced.
    @MainActor
    private final class LiveNavigator: ActivitiesEditorNavigating {
        let navigator: UI2Navigator
        let current: UI2Destination

        init(navigator: UI2Navigator, current: UI2Destination) {
            self.navigator = navigator
            self.current = current
        }

        func push(_ destination: UI2Destination) { navigator.push(destination) }
        func replace(with destination: UI2Destination) { navigator.replaceTop(current, destination) }
        func pop() { navigator.popIfTop(current) }
    }

    // MARK: - Model

    /// The edit buffer and its save, conflict and back-out rules.
    @MainActor
    @Observable
    final class Model {
        enum Phase { case loading, ready, failed }

        /// D46's alert: its title and its two buttons, in order.
        struct SaveError: Equatable {
            let message: String
            let options: [String]
        }

        static let saveFailed = SaveError(message: "Couldn't save activity", options: ["Retry", "Discard changes"])

        private(set) var activityId: String
        private(set) var activityKey: String
        private(set) var lessonId: String
        private(set) var lessonVersionId: String
        /// The edit buffer: the whole document, as the next Done will PUT it.
        private(set) var document: ActivityDocument
        /// The document as the server last accepted it (Discard changes goes back to it).
        private(set) var savedDocument: ActivityDocument
        private(set) var phase: Phase
        /// The object being edited; −1 = Idle.
        private(set) var editingIndex = -1
        private(set) var isSaving = false
        private(set) var saveError: SaveError?
        /// Bumped whenever the screen must re-seed from `State` (see the container's `.id`).
        private(set) var screenGeneration = 0
        var navigator: ActivitiesEditorNavigating?

        private let actions: ActivityActionsProtocol
        private let log: (Error, String) -> Void
        /// The document before the current edit began (Cancel restores it) and whether the edited
        /// object was added by this edit (Done drops it when left empty).
        private var editStart: ActivityDocument?
        private var editAddedObject = false
        private var inFlight: Task<Bool, Never>?

        init(activityId: String, activityKey: String, document: ActivityDocument = ActivityDocument(raw: .object([:])),
             lessonId: String = "", lessonVersionId: String = "", phase: Phase = .ready,
             actions: ActivityActionsProtocol? = nil,
             log: ((Error, String) -> Void)? = nil) {
            self.activityId = activityId
            self.activityKey = activityKey
            self.document = document
            self.savedDocument = document
            self.lessonId = lessonId
            self.lessonVersionId = lessonVersionId
            self.phase = phase
            // Resolved here, not as default arguments: those are evaluated off the main actor.
            self.actions = actions ?? ActivityActions()
            self.log = log ?? Model.record
        }

        /// Cache-first: an activity of a loaded draft opens at once; otherwise `load()` resolves it.
        static func resolving(activityId: String, app: AppState? = nil) -> Model {
            let app = app ?? .shared
            if let activity = app.activities[activityId],
               let version = app.lessonVersions[activity.lessonVersionId], version.status == .draft,
               ActivitiesEditorMapper.isEditable(activity.document) {
                return Model(activityId: activity.id, activityKey: activity.activityKey, document: activity.document,
                             lessonId: version.lessonId, lessonVersionId: version.id)
            }
            return Model(activityId: activityId, activityKey: "", phase: .loading)
        }

        /// Console-only record of a failure this model shows itself (the alert) or that the leader
        /// didn't ask for (an empty activity's delete on back).
        static func record(_ error: Error, context: String) {
            AppState.shared.recordError(error, context: context, surface: false)
        }

        // MARK: Load

        /// Opens an activity that isn't in a loaded draft: finds its lesson (a program-home slide, or a
        /// loaded version), loads the lesson's draft and takes the activity with the same `activityKey`.
        /// Anything that fails, or a document this build can't edit, is the screen's Load-failed state.
        func load(app: AppState? = nil) async {
            let app = app ?? .shared
            guard phase == .loading else { return }
            let lesson: (id: String, key: String)? = {
                if let activity = app.activities[activityId] {
                    if let version = app.lessonVersions[activity.lessonVersionId] {
                        return (version.lessonId, activity.activityKey)
                    }
                    // A new activity on a draft that was never loaded: only the program read's draft id names its lesson.
                    if let lesson = app.lessons.all.first(where: { $0.draftVersionId == activity.lessonVersionId }) {
                        return (lesson.id, activity.activityKey)
                    }
                }
                for lesson in app.lessons.all {
                    if let slide = lesson.activities.first(where: { $0.id == activityId }) { return (lesson.id, slide.activityKey) }
                }
                return nil
            }()
            guard let lesson else { return fail() }
            do {
                let rows = try await actions.reloadDraft(lessonId: lesson.id)
                guard let row = rows.first(where: { $0.activityKey == lesson.key }),
                      ActivitiesEditorMapper.isEditable(row.document) else { return fail() }
                activityId = row.id
                activityKey = row.activityKey
                lessonId = lesson.id
                lessonVersionId = row.lessonVersionId
                document = row.document
                savedDocument = row.document
                phase = .ready
                screenGeneration += 1
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                log(error, ActivitiesEditorContainer.loadContext)
                fail()
            }
        }

        private func fail() {
            phase = .failed
        }

        // MARK: Editing

        /// Idle: a tap on the empty canvas starts a new object there.
        func tapEmpty(at point: CGPoint) {
            guard phase == .ready, editingIndex < 0 else { return }
            editStart = document
            let added = ActivitiesEditorMapper.appendObject(to: document, centerY: Double(point.y))
            document = added.document
            editingIndex = added.index
            editAddedObject = true
        }

        /// Idle: a tap on an object edits it.
        func tapObject(_ index: Int) {
            guard phase == .ready, editingIndex < 0 else { return }
            editStart = document
            editingIndex = index
            editAddedObject = false
        }

        /// D33: one object edit patches only its fields.
        func edit(_ edit: ActivitiesEditorScreen.ObjectEdit) {
            document = ActivitiesEditorMapper.apply(edit, to: document)
        }

        /// Cancel: the document from before this edit.
        func cancel() {
            if let editStart { document = editStart }
            endEditing()
        }

        /// Done: commits the edit (a new object left empty is dropped) and saves the whole document.
        func done() async {
            if editingIndex >= 0, editAddedObject,
               ActivitiesEditorMapper.text(at: editingIndex, in: document)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false {
                document = ActivitiesEditorMapper.removeObject(at: editingIndex, from: document)
            }
            endEditing()
            _ = await commit()
        }

        private func endEditing() {
            editingIndex = -1
            editStart = nil
            editAddedObject = false
        }

        /// The Background sheet's live changes; saved with the next Done or on leaving.
        func changeBackground(_ background: ActivityCanvas<AnyView>.Background) {
            document = ActivitiesEditorMapper.applyBackground(background, to: document)
        }

        /// The Actions sheet's Done saves the page's actions.
        func changeActions(_ edited: [ActivitiesEditorScreen.PageAction]) async {
            document = ActivitiesEditorMapper.applyActions(edited, to: document)
            _ = await commit()
        }

        /// D40: the Background sheet's image button opens the Media pick mode for this activity.
        func pickImage() {
            navigator?.push(.chooseActivityBackground(activityId: activityId))
        }

        /// D40: a pick delivered while the Media page was on top becomes the background image.
        func takeBackgroundPick(_ mailbox: ActivityBackgroundPick? = nil) {
            let mailbox = mailbox ?? .shared
            guard let mediaId = mailbox.take(for: activityId) else { return }
            document = ActivitiesEditorMapper.settingBackgroundImage(mediaId: mediaId, in: document)
        }

        // MARK: Saving

        /// D46: Retry runs the save again; Discard changes goes back to the saved document.
        func retry() async {
            saveError = nil
            _ = await commit()
        }

        func discard() {
            document = savedDocument
            saveError = nil
            endEditing()
            screenGeneration += 1
        }

        /// One save at a time: a save waits until no save is in flight, then PUTs the buffer as it is now.
        private func commit() async -> Bool {
            await waitForSaves()
            let task = Task { await self.put(self.document) }
            inFlight = task
            let saved = await task.value
            // Another caller may have started its save once this one finished; that one stays guarded.
            if inFlight == task { inFlight = nil }
            return saved
        }

        /// Waits out every save in flight, including one started by another waiter as the last ended
        /// (each waiter resumes on its own, so a single `await` could see a newer save begin).
        private func waitForSaves() async {
            while let task = inFlight {
                _ = await task.value
                if inFlight == task { inFlight = nil }
            }
        }

        /// The PUT, with D46's one refetch-and-remap on 409 `NOT_DRAFT` or a 404 (the draft was deleted).
        private func put(_ snapshot: ActivityDocument) async -> Bool {
            isSaving = true
            defer { isSaving = false }
            do {
                do {
                    try await actions.save(activityId: activityId, title: nil, document: snapshot)
                } catch ActivityActionsError.notDraft {
                    try await remapToTheNewDraft()
                    try await actions.save(activityId: activityId, title: nil, document: snapshot)
                } catch ActivityActionsError.gone {
                    try await remapToTheNewDraft()
                    try await actions.save(activityId: activityId, title: nil, document: snapshot)
                }
                savedDocument = snapshot
                return true
            } catch {
                // Silent: a cancelled save leaves the buffer as it is; the next Done or back saves it.
                if UI2ImageLoader.isCancellation(error) { return false }
                log(error, "ActivitiesEditorContainer.save")
                saveError = Self.saveFailed
                screenGeneration += 1
                return false
            }
        }

        /// Another leader published: the activity now lives in a new draft, under the same key.
        private func remapToTheNewDraft() async throws {
            let rows = try await actions.reloadDraft(lessonId: lessonId)
            guard let row = rows.first(where: { $0.activityKey == activityKey }) else { throw ActivityActionsError.notDraft }
            activityId = row.id
            lessonVersionId = row.lessonVersionId
        }

        // MARK: Leaving

        /// Back: D16 deletes an untouched activity; otherwise unsaved changes save first, and a failed
        /// save stays on the page with the alert.
        func back() async {
            guard await leave() else { return }
            navigator?.pop()
        }

        /// D22: the viewer plays the draft, so unsaved changes save first.
        func play() async {
            guard phase == .ready, await saveIfChanged() else { return }
            navigator?.push(.activityViewer(lessonVersionId: lessonVersionId, activityId: activityId))
        }

        /// D39: another slide opens that activity in place (a kind the editor can't open says so).
        func selectSlide(_ id: String, app: AppState? = nil) async {
            let app = app ?? .shared
            guard id != activityId, let target = app.activities[id] else { return }
            switch ActivityEntry.destination(for: target.kind, activityId: id) {
            case .open(let destination):
                guard await leave() else { return }
                navigator?.replace(with: destination)
            case .cannotEdit(let message):
                ActivityEntry.surface(message)
            }
        }

        /// The rail's add opens the type picker for this lesson in place.
        func addActivity(app: AppState? = nil) async {
            let app = app ?? .shared
            // The program read's lesson rows carry no program id: the index knows the parent.
            guard let programId = app.lessons[lessonId]?.studyProgramId
                    ?? app.programLessonIndex.parent(of: lessonId) else { return }
            guard await leave() else { return }
            navigator?.replace(with: .activityNew(programId: programId, lessonId: lessonId))
        }

        /// Whether the page may close: an untouched activity is deleted (a failed delete is logged, the
        /// leader still leaves); a changed one must save.
        private func leave() async -> Bool {
            guard phase == .ready else { return true }
            await waitForSaves()
            if ActivitiesEditorMapper.isUntouched(document) {
                do {
                    try await actions.delete(activityId: activityId)
                } catch {
                    log(error, "ActivitiesEditorContainer.deleteUntouched")
                }
                return true
            }
            return await saveIfChanged()
        }

        private func saveIfChanged() async -> Bool {
            await waitForSaves()
            guard document != savedDocument else { return saveError == nil }
            return await commit()
        }
    }
}
