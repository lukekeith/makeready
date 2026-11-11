import SwiftUI

/// Where the editor sends the leader: the viewer and the image pick (push), another activity or the
/// type picker (in place), back (pop).
@MainActor
protocol ActivitiesEditorNavigating: AnyObject {
    func push(_ destination: UI2Destination)
    /// bible-verse-picker D12: push several pages, in order, as one path write.
    func pushAll(_ destinations: [UI2Destination])
    func replace(with destination: UI2Destination)
    func pop()
    /// bible-verse-picker D2: the stack depth a Bible pick returns to.
    var depth: Int { get }
}

extension ActivitiesEditorNavigating {
    var depth: Int { 0 }
    func pushAll(_ destinations: [UI2Destination]) { destinations.forEach(push) }
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
            onCancel: { Task { await model.cancel() } },
            onDone: { Task { await model.done() } },
            onSelectSlide: { id in Task { await model.selectSlide(id) } },
            onAdd: { Task { await model.addActivity() } },
            onPickType: { type in Task { await model.pickType(type) } },
            onTapEmpty: { point in model.tapEmpty(at: point) },
            onTapObject: { index in Task { await model.tapObject(index) } },
            onEditObject: { edit in model.edit(edit) },
            onLoadFailed: { message in Self.surfaceLoadFailure(message) },
            onTapOff: { Task { await model.tapOff() } },
            onBackground: { command in model.changeBackground(command) },
            onActionsChange: { actions in model.changeActions(actions) },
            onPageRailsClosed: { Task { await model.closePageRails() } },
            onDeleteHighlight: { Task { await model.deleteSelectedHighlight() } },
            onRetry: { Task { await model.retry() } },
            onDiscard: { model.discard() },
            onHighlightRange: { index, start, end in model.highlightRange(objectIndex: index, start: start, end: end) },
            onToggleHighlight: { model.startHighlighting() },
            onEndHighlighting: { Task { await model.endHighlighting() } },
            onBibleStyleChange: { change in model.setBibleStyle(change) }
        )
        // The screen seeds its sheets' buffers and its alert from `State` once, at init; a new
        // generation (loaded, a failed save, a discard) re-seeds them.
        .id(model.screenGeneration)
        .ui2PushedPageFill()
        // bible-verse-picker D12: Change passage · Highlight; the chosen row runs once the menu has hidden.
        .actionMenuPresentation(isPresented: model.isPassageMenuOpen, onDismiss: { model.cancelPresentation() },
                                onHidden: { model.menuHidden() }) {
            ActionMenuOverlay(
                actions: BiblePassageMenu.items,
                onSelect: { item in
                    model.choose(ActivitiesEditorScreen.lockedObjectMenuRows.first { $0.label == item.label }?.id)
                },
                onDone: { model.cancelPresentation() }
            )
        }
        // D13: the count of highlights a change removes, before anything saves.
        .actionMenuPresentation(isPresented: model.isChangeConfirmationOpen, onDismiss: { model.cancelPresentation() }) {
            confirmationOverlay(model.shownChangeConfirmation, onConfirm: { Task { await model.confirmChange() } })
        }
        // D11: deleting a locked object deletes the whole passage, after asking.
        .actionMenuPresentation(isPresented: model.isDeleteConfirmationOpen, onDismiss: { model.cancelPresentation() }) {
            confirmationOverlay(BiblePassageMenu.deleteConfirmation, onConfirm: { Task { await model.confirmDelete() } })
        }
        .onAppear {
            model.navigator = LiveNavigator(navigator: navigator, current: .activitiesEditor(activityId: activityId))
            backSwipe?.blocksBackSwipe = { true }
            backSwipe?.onBlockedBackSwipe = { [model] in Task { await model.back() } }
            // D40: the Media pick mode delivers here; the page is back on top.
            model.takeBackgroundPick()
        }
        // D12: a changed passage returns the same way, keyed by the change flow's id.
        .onChange(of: model.changeFlowId.flatMap { BiblePassagePick.shared.pending[$0] }) { _, pick in
            if pick != nil { Task { await model.receiveChangePick() } }
        }
        // D2: the Bible picker's Select delivers its pick through the mailbox; the grid's model saves it.
        .onChange(of: model.bibleGrid?.pendingFlowId.flatMap { BiblePassagePick.shared.pending[$0] }) { _, pick in
            if pick != nil { Task { await model.bibleGrid?.receiveBiblePick() } }
        }
        .task { await model.load() }
        .task { await model.loadImages() }
        // Round 6: the chips' screenshots — rendered thumbnails for canvas kinds, posters and stills otherwise.
        .task(id: chipImageKey) {
            let app = AppState.shared
            let slides = app.activities(forVersion: model.lessonVersionId)
            var seeded = await ActivityThumbnail.seed(ActivitiesEditorMapper.slideSummaries(slides), media: app.mediaMap)
            let others = ActivitiesEditorMapper.slideImages(slides, media: app.mediaMap).filter { $0.hasPrefix("http") }
            if await UI2ImageLoader.seed(others, context: "ActivitiesEditorContainer.chips") { seeded = true }
            if seeded { imagesSeeded += 1 }
        }
        .task(id: state.pageImageURL) {
            if await UI2ImageLoader.seed([state.pageImageURL], context: "ActivitiesEditorContainer") { imagesSeeded += 1 }
        }
    }

    private func confirmationOverlay(_ confirmation: BiblePassageMenu.Confirmation,
                                     onConfirm: @escaping () -> Void) -> some View {
        ActionMenuOverlay(
            title: confirmation.title,
            message: confirmation.message,
            actions: [confirmation.action],
            doneLabel: confirmation.cancel,
            onSelect: { _ in onConfirm() },
            onDone: { model.cancelPresentation() }
        )
    }

    /// Changes whenever a chip's screenshot could: a saved document, an added activity, a new poster.
    private var chipImageKey: [String] {
        ActivitiesEditorMapper.slideImages(AppState.shared.activities(forVersion: model.lessonVersionId),
                                           media: AppState.shared.mediaMap)
    }

    /// D37: the chips with the new activity's empty placeholder right after `after` (at the end when it is not a
    /// chip), made the active chip. The placeholder is the New Activity page's own id and label.
    static func withPlaceholder(_ state: ActivitiesEditorScreen.State, after: String?) -> ActivitiesEditorScreen.State {
        var state = state
        let slot = after.flatMap { state.slideIDs.firstIndex(of: $0) }.map { $0 + 1 } ?? state.slideIDs.count
        state.slideIDs.insert(ActivityNewMapper.placeholderID, at: slot)
        state.slideLabels.insert(ActivityNewMapper.placeholderLabel, at: min(slot, state.slideLabels.count))
        if state.slideImages.count >= slot { state.slideImages.insert("", at: slot) }
        state.activeID = ActivityNewMapper.placeholderID
        return state
    }

    /// The screen's state: the buffer mapped over the version's slides, plus the mode and flags.
    @MainActor
    static func screenState(_ model: Model, app: AppState) -> ActivitiesEditorScreen.State {
        var state = ActivitiesEditorMapper.state(document: model.document, media: app.mediaMap,
                                                 slides: app.activities(forVersion: model.lessonVersionId),
                                                 activeID: model.activityId, kind: model.kind)
        state = ActivitiesEditorMapper.withBackgroundRail(state, document: model.document, library: app.mediaLibrary.all,
                                                          hasMoreImages: app.mediaLibrary.count < app.mediaLibraryTotal)
        state.editorMode = model.editingIndex >= 0 ? "editing" : "idle"
        // D12/D21: Highlight enters the mode on one locked object, with no keyboard.
        if let id = model.highlightingObjectID, state.objectIDs.contains(id) {
            state.editorMode = "highlighting"
            state.openTool = "highlight"
            state.highlightingObjectID = id
            state.selectedHighlightID = model.selectedHighlightID
        }
        state.editingIndex = model.editingIndex
        state.saving = model.isSaving
        state.saveFailed = model.saveError != nil
        state.loadFailed = model.phase == .failed
        // D26–D28: what the canvas area shows — the activity, the type grid in place, or a read-only page.
        switch model.canvasContent {
        case .activity: state.canvasContent = "activity"
        case .typeGrid: state.canvasContent = "typeGrid"
        case .readOnly: state.canvasContent = "readOnly"
        }
        // D37: while the grid shows, an empty placeholder chip follows the activity it was opened from and is active.
        if model.canvasContent == .typeGrid {
            state = withPlaceholder(state, after: model.insertAfterID)
        }
        state.unavailableTypes = ActivityNewContainer.unavailableTypes
        state.pendingType = model.pendingType
        if model.canvasContent == .readOnly, let activity = app.activities[model.activityId] {
            state.readOnlyKind = activity.kind
            state.readOnlyTitle = activity.title
            if case .video(let video) = activity.document.renderable {
                state.readOnlyPosterURL = ActivityViewerMapper.videoEntry(video, media: app.mediaMap)?.posterUrl ?? ""
            }
        }
        // Owner 2026-11-08: the Idle Done is muted until there is something to save.
        state.canSave = model.phase == .ready && model.document != model.savedDocument
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
        func pushAll(_ destinations: [UI2Destination]) { navigator.pushAll(destinations) }
        func replace(with destination: UI2Destination) { navigator.replaceTop(current, destination) }
        func pop() { navigator.popIfTop(current) }
        var depth: Int { navigator.depth() }
    }

    /// The grid's model pushes Books through the editor's own navigator.
    @MainActor
    private final class GridNavigator: ActivityNewNavigating {
        let editor: ActivitiesEditorNavigating
        init(editor: ActivitiesEditorNavigating) { self.editor = editor }
        func replace(with destination: UI2Destination) { editor.replace(with: destination) }
        func push(_ destination: UI2Destination) { editor.push(destination) }
        var depth: Int { editor.depth }
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
        /// The open activity's kind: `bible` shows the highlight tool and locks its scripture (D21).
        private(set) var kind: String
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
             lessonId: String = "", lessonVersionId: String = "", phase: Phase = .ready, kind: String = "text",
             actions: ActivityActionsProtocol? = nil,
             newActivityActions: ActivityNewContainer.Actions? = nil,
             log: ((Error, String) -> Void)? = nil) {
            self.newActivityActions = newActivityActions ?? .live
            self.activityId = activityId
            self.activityKey = activityKey
            self.document = document
            self.savedDocument = document
            self.lessonId = lessonId
            self.lessonVersionId = lessonVersionId
            self.phase = phase
            self.kind = kind
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
                             lessonId: version.lessonId, lessonVersionId: version.id, kind: activity.kind)
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
                kind = row.kind
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

        /// Idle: a tap on an object edits it. While another object is being edited, that edit is
        /// committed first, exactly as tap-off does, then the tapped object opens (text-activity-v2 D20).
        func tapObject(_ index: Int) async {
            guard phase == .ready, index != editingIndex else { return }
            var target = index
            if editingIndex >= 0 {
                let droppedIndex = await commitEdit()
                // A dropped empty object before the tapped one shifts it down by one.
                if let droppedIndex, droppedIndex < target { target -= 1 }
            }
            guard target >= 0, target < ActivitiesEditorMapper.rawObjects(document).count else { return }
            // D12: a locked scripture or citation opens the passage menu; it is never typed into.
            if isLocked(target) {
                presentation = .menu(object: target)
                return
            }
            editStart = document
            editingIndex = target
            editAddedObject = false
        }

        /// Editing: a tap on the empty canvas ends the edit the way Done does and saves (text-activity-v2 D10).
        func tapOff() async {
            guard editingIndex >= 0 else { return }
            _ = await commitEdit()
        }

        /// D33: one object edit patches only its fields.
        func edit(_ edit: ActivitiesEditorScreen.ObjectEdit) {
            var edit = edit
            // D11: a locked object takes every restyle but no text.
            if isLocked(edit.index) { edit.text = nil }
            // D26: the page places a scripture or citation — a move, pinch, rotate or width is never written.
            if let sibling = pageLaidOutSibling(of: edit.index) {
                edit.transform = nil
                edit.width = nil
                // D28: the citation follows the scripture's colour and alignment (and the face, written by the style panel).
                document = ActivitiesEditorMapper.apply(
                    .init(index: sibling, font: edit.font, color: edit.color, alignment: edit.alignment), to: document)
            }
            document = ActivitiesEditorMapper.apply(edit, to: document)
        }

        /// D28: one Bible style panel change. Face writes the scripture and the citation; weight, line height and verse
        /// numbers the scripture alone; size the scripture and the citation at 14/18 of it; the page padding, colour and
        /// alignment both. Reached from the Idle tool bar (D28), so there is no edit session: Done saves it.
        func setBibleStyle(_ change: ActivitiesEditorScreen.BibleStyleChange) {
            guard kind == "bible", let layout = BibleScripture.layout(of: document) else { return }
            let scripture: [JSONPathComponent] = ["content", "objects", .index(layout.scriptureIndex)]
            let citation = layout.citationIndex.map { ["content", "objects", JSONPathComponent.index($0)] as [JSONPathComponent] }
            document = document.updating { raw in
                switch change {
                case .face(let face):
                    raw[path: scripture + ["font"]] = .string(face)
                    if let citation { raw[path: citation + ["font"]] = .string(face) }
                case .weight(let weight):
                    raw[path: scripture + ["weight"]] = .number(Double(weight))
                case .size(let size):
                    raw[path: scripture + ["size"]] = .number(Double(size))
                    if let citation { raw[path: citation + ["size"]] = .number(Double(size) * BibleScripture.citationRatio) }
                case .lineHeight(let lineHeight):
                    raw[path: scripture + ["lineHeight"]] = .number(Double((lineHeight * 10).rounded() / 10))
                case .inset(let inset):
                    raw[path: scripture + ["inset"]] = .number(Double(inset))
                    if let citation { raw[path: citation + ["inset"]] = .number(Double(inset)) }
                case .verseNumbers(let mode):
                    raw[path: scripture + ["verseNumbers"]] = .string(mode)
                case .color(let hex):
                    raw[path: scripture + ["color"]] = .string(hex)
                    if let citation { raw[path: citation + ["color"]] = .string(hex) }
                case .alignment(let code):
                    raw[path: scripture + ["alignment"]] = .string(code)
                    if let citation { raw[path: citation + ["alignment"]] = .string(code) }
                }
            }
        }

        /// The other half of a page-laid-out pair (scripture ↔ citation) when `index` is one of the two; nil for any
        /// other object, which keeps its transform.
        private func pageLaidOutSibling(of index: Int) -> Int? {
            guard kind == "bible", let layout = BibleScripture.layout(of: document) else { return nil }
            if index == layout.scriptureIndex { return layout.citationIndex ?? -1 }
            if index == layout.citationIndex { return layout.scriptureIndex }
            return nil
        }

        /// Cancel restores only the edited object — an added one is removed, an existing one goes back
        /// to how it was — and keeps every page edit made meanwhile, saving them if any (text-activity-v2 D19).
        func cancel() async {
            guard editingIndex >= 0 else { return }
            if editAddedObject {
                document = ActivitiesEditorMapper.removeObject(at: editingIndex, from: document)
            } else if let editStart {
                let originals = ActivitiesEditorMapper.rawObjects(editStart)
                // D28: the scripture and its citation are styled as one block, so Cancel restores both.
                let restored = [editingIndex] + [pageLaidOutSibling(of: editingIndex)].compactMap { $0 }
                for index in restored where originals.indices.contains(index) {
                    document = ActivitiesEditorMapper.replacingObject(at: index, with: originals[index], in: document)
                }
            }
            endEditing()
            if document != savedDocument { _ = await saveIfChanged() }
        }

        /// Done: commits the edit (a new object left empty is dropped) and saves the whole document.
        func done() async {
            // Owner 2026-11-08: the Idle header's Done saves, then leaves the editor. A failed save
            // stays on the page with the alert, so the edits are not lost.
            guard editingIndex >= 0 else {
                // Nothing to save → nothing happens (the header's Done is muted then anyway).
                guard phase == .ready, document != savedDocument, await saveIfChanged() else { return }
                navigator?.pop()
                return
            }
            _ = await commitEdit()
        }

        /// Ends the text edit and saves the whole document (one PUT): a new object left empty is dropped.
        /// Done, tap-off and a tap on another object all end an edit this way (text-activity-v2 D10, D20).
        /// Returns the index of the dropped object, if one was dropped.
        @discardableResult
        func commitEdit() async -> Int? {
            guard editingIndex >= 0 else { return nil }
            var dropped: Int?
            if editAddedObject,
               ActivitiesEditorMapper.text(at: editingIndex, in: document)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false {
                document = ActivitiesEditorMapper.removeObject(at: editingIndex, from: document)
                dropped = editingIndex
            }
            // A style-tools visit to a locked object saves only when something changed.
            let visitedLocked = isLocked(editingIndex)
            endEditing()
            if !visitedLocked || document != savedDocument { _ = await commit() }
            return dropped
        }

        private func endEditing() {
            editingIndex = -1
            editStart = nil
            editAddedObject = false
        }

        /// The Background sheet's live changes; saved with the next Done or on leaving.
        /// The Background rail's choices patch the buffer live; they save when the rail closes (D19).
        /// Gradient/Colour/Shuffle/palette per D13, D14, D17, D18; Image picks inline, More… pushes the
        /// full picker (D22).
        func changeBackground(_ command: ActivitiesEditorScreen.BackgroundCommand, app: AppState? = nil) {
            switch command {
            case .gradient:
                document = ActivitiesEditorMapper.showingGradient(in: document, rng: &random)
            case .colour(let hex):
                // The Colour option alone shows the page colour as it is; a swatch sets it.
                document = ActivitiesEditorMapper.choosingColour(hex ?? document.background.color, in: document)
            case .shuffle:
                document = ActivitiesEditorMapper.shuffling(in: document, rng: &random)
            case .palette(let index):
                guard ActivityBackgroundPalettes.all.indices.contains(index) else { return }
                document = ActivitiesEditorMapper.choosingPalette(ActivityBackgroundPalettes.all[index], in: document, rng: &random)
            case .image(let mediaId):
                pickLibraryImage(mediaId, app: app ?? .shared)
            case .moreImages:
                pickImage()
            case .loadMoreImages:
                Task { await loadMoreImages() }
            case .focal(let x, let y):
                document = ActivitiesEditorMapper.settingFocal(x: x, y: y, in: document)
            case .wash(let color, let opacity):
                document = ActivitiesEditorMapper.settingWash(color: color, opacity: opacity, in: document)
            }
        }

        /// The randomness behind Gradient, Shuffle and a palette chip; tests swap in a seeded one.
        var random = AnyRandomNumberGenerator(SystemRandomNumberGenerator())

        /// D22: a library thumbnail becomes the background image, its URL merged into the media map the
        /// screen resolves images through (as the Media pick mode does).
        func pickLibraryImage(_ mediaId: String, app: AppState) {
            if let item = app.mediaLibrary[mediaId] {
                app.mergeMedia([item.id: MediaMapEntry(url: item.url, width: nil, height: nil, kind: "image",
                                                       playbackUrl: nil, posterUrl: nil, durationSeconds: nil,
                                                       uploaderName: item.uploader?.name)])
            }
            document = ActivitiesEditorMapper.settingBackgroundImage(mediaId: mediaId, in: document)
        }

        /// D22: the Image rail's photos — the library, cache-first (a background refresh is console-only).
        func loadImages() async {
            do { try await MediaActions().loadLibrary() } catch {
                AppState.shared.recordError(error, context: "ActivitiesEditorContainer.loadImages")
            }
        }

        /// D22: the Image rail scrolled to its end.
        func loadMoreImages() async {
            do { try await MediaActions().loadMoreLibrary() } catch {
                AppState.shared.recordError(error, context: "ActivitiesEditorContainer.loadMoreImages")
            }
        }

        /// The Actions rail's live edits patch the buffer; nothing is saved until the rail closes or the
        /// text edit commits (text-activity-v2 D19).
        func changeActions(_ edited: [ActivitiesEditorScreen.PageAction]) {
            document = ActivitiesEditorMapper.applyActions(edited, to: document)
        }

        /// A Background or Actions rail closed: actions left without a label are dropped, then in Idle the
        /// page saves once if it changed. During a text edit the page edits ride that edit's commit (D19).
        func closePageRails() async {
            document = ActivitiesEditorMapper.droppingUnlabelledActions(in: document)
            guard phase == .ready, editingIndex < 0 else { return }
            _ = await saveIfChanged()
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

        // MARK: Bible scripture (bible-verse-picker D11–D14)

        /// The menu or confirmation over the canvas, if any.
        private(set) var presentation: BiblePassageMenu.Presentation?
        /// D12: the object Highlight put in highlighting mode (an id in `State.objectIDs`).
        private(set) var highlightingObjectID: String?
        /// The highlight just added in highlighting mode, selected for the Selection row.
        private(set) var selectedHighlightID = ""
        /// The open change flow's id, until its pick arrives (D2).
        private(set) var changeFlowId: UUID?
        /// The last change confirmation shown, so the overlay keeps its words while it slides out.
        private(set) var shownChangeConfirmation = BiblePassageMenu.changeConfirmation(removed: 0)
        private var pendingChoice: (row: ActivitiesEditorScreen.LockedObjectMenuRow.ID, object: Int)?
        /// A change waiting for the leader's confirmation, and one that stopped part-way (Retry resumes it).
        private var pendingChange: BibleSave.Plan?
        private var stoppedChange: (plan: BibleSave.Plan, failure: BibleSave.Failure)?

        var isPassageMenuOpen: Bool { if case .menu = presentation { return true } else { return false } }
        var isChangeConfirmationOpen: Bool { if case .change = presentation { return true } else { return false } }
        var isDeleteConfirmationOpen: Bool { if case .delete = presentation { return true } else { return false } }

        /// D11/D23: a referenced scripture or citation object — never an ordinary one.
        private func isLocked(_ index: Int) -> Bool {
            guard kind == "bible" else { return false }
            let objects = document.textObjects
            return objects.indices.contains(index) && objects[index].isLockedScripture
        }

        /// A menu row was chosen: it runs once the menu has hidden (`menuHidden`).
        func choose(_ row: ActivitiesEditorScreen.LockedObjectMenuRow.ID?) {
            guard case .menu(let object)? = presentation, let row else { return }
            pendingChoice = (row, object)
            presentation = nil
        }

        func menuHidden() {
            guard let choice = pendingChoice else { return }
            pendingChoice = nil
            switch choice.row {
            case .highlight:
                let objects = document.textObjects
                guard objects.indices.contains(choice.object) else { return }
                selectedHighlightID = ""
                highlightingObjectID = objects[choice.object].id
            case .changePassage:
                startChangePassage()
            }
        }

        /// D12/D28: the Idle Bible tool bar's Highlight — highlighting on the page's scripture object, as the menu's row.
        func startHighlighting() {
            guard kind == "bible", let layout = BibleScripture.layout(of: document) else { return }
            let objects = document.textObjects
            guard objects.indices.contains(layout.scriptureIndex) else { return }
            selectedHighlightID = ""
            highlightingObjectID = objects[layout.scriptureIndex].id
        }

        /// Dismisses whatever is showing without acting on it.
        func cancelPresentation() {
            if case .change? = presentation { pendingChange = nil }
            presentation = nil
        }

        // Highlighting (D21)

        /// A range selected in the highlighting object: a range inside an existing highlight removes it, any other adds one.
        func highlightRange(objectIndex: Int, start: Int, end: Int) {
            let objects = document.textObjects
            guard objects.indices.contains(objectIndex), start < end, start >= 0,
                  end <= objects[objectIndex].text.utf16.count else { return }
            var list = objects[objectIndex].highlights
            if let hit = list.firstIndex(where: { $0.start <= start && end <= $0.end }) {
                list.remove(at: hit)
                selectedHighlightID = ""
            } else {
                let added = TextObject.Highlight(id: "h" + UUID().uuidString.prefix(8).lowercased(), start: start, end: end)
                list.append(added)
                selectedHighlightID = added.id
            }
            document = BiblePassageEditing.setting(highlights: list, at: objectIndex, in: document)
        }

        /// The Selection row's trash.
        func deleteSelectedHighlight() async {
            guard !selectedHighlightID.isEmpty else { return }
            let objects = document.textObjects
            for (index, object) in objects.enumerated() where object.highlights.contains(where: { $0.id == selectedHighlightID }) {
                document = BiblePassageEditing.setting(highlights: object.highlights.filter { $0.id != selectedHighlightID },
                                                       at: index, in: document)
            }
            selectedHighlightID = ""
        }

        /// Tool 5 again, or Done, while highlighting: the mode ends and the highlights save.
        func endHighlighting() async {
            highlightingObjectID = nil
            selectedHighlightID = ""
            _ = await saveIfChanged()
        }

        // Change passage (D12–D14)

        /// D12: pushes the picker at the current passage — Books with the Reader at the passage's first verse on top,
        /// in one path write, so the Reader's Back goes to Books; the Reader shows `initial` selected.
        private func startChangePassage() {
            guard let navigator, let passage = document.passages.first else { return }
            let app = AppState.shared
            let flowId = UUID()
            let others = app.activities(forVersion: lessonVersionId).filter { $0.id != activityId }
            app.biblePickFlows[flowId] = BiblePickFlow(caller: .change(activityId: activityId), returnDepth: navigator.depth,
                                                       used: BibleScripture.used(in: others), initial: passage)
            changeFlowId = flowId
            navigator.pushAll([
                .bibleBooks(flowId: flowId),
                .bibleReader(book: passage.bookNumber, chapter: passage.chapterStart, verse: passage.verseStart, flowId: flowId)
            ])
        }

        /// D2: takes the pick Select delivered and applies it.
        func receiveChangePick() async {
            guard let flowId = changeFlowId, let pick = BiblePassagePick.shared.take(for: flowId) else { return }
            changeFlowId = nil
            await changePassage(pick: pick)
        }

        /// D13/D14: re-anchors the highlights onto the new passage (a long passage grows its page, D29); if any would be
        /// removed the leader is asked first, otherwise the change saves.
        func changePassage(pick: BiblePick) async {
            guard phase == .ready, kind == "bible", await leave(),
                  let old = BiblePassageEditing.currentPick(of: document) else { return }
            let base = BibleSave.plan(change: activityId, pick: pick, version: lessonVersionId,
                                      background: document.background)

            let previous = BiblePassageEditing.highlights(of: document)
            let kept = [BibleScripture.reanchor(highlights: previous.scripture, old: old, new: pick).kept]
            let keptIDs = Set(kept.flatMap { $0.map(\.id) })
            let removed = previous.scripture.filter { !keptIDs.contains($0.id) }.count + previous.citation

            func withHighlights(_ document: ActivityDocument, _ highlights: [TextObject.Highlight]) -> ActivityDocument {
                BiblePassageEditing.setting(highlights: highlights, in: document)
            }
            let plan = BibleSave.Plan(
                version: base.version,
                posts: base.posts,
                order: base.order,
                // D11/D13: the original keeps the leader's page; only the passage's own fields change.
                put: base.put.map {
                    ($0.activityId, BiblePassageEditing.replacingPassage(in: document, with: withHighlights($0.document, kept[0])))
                })

            guard removed > 0 else { return await runChange(plan, from: 0, created: []) }
            pendingChange = plan
            shownChangeConfirmation = BiblePassageMenu.changeConfirmation(removed: removed)
            presentation = .change(shownChangeConfirmation)
        }

        /// The confirmation's Change.
        func confirmChange() async {
            guard case .change? = presentation, let plan = pendingChange else { return }
            presentation = nil
            pendingChange = nil
            await runChange(plan, from: 0, created: [])
        }

        /// D14: Retry resumes from the failed request, never re-POSTing a created part.
        func retryChange() async {
            guard let stopped = stoppedChange else { return }
            await runChange(stopped.plan, from: stopped.failure.step, created: stopped.failure.created)
        }

        private func runChange(_ plan: BibleSave.Plan, from step: Int, created: [String]) async {
            switch await BibleSave.run(plan, actions: newActivityActions, from: step, created: created) {
            case .success:
                stoppedChange = nil
                if let put = plan.put {
                    document = put.document
                    savedDocument = put.document
                }
                screenGeneration += 1
            case .failure(let failure):
                stoppedChange = (plan, failure)
                if UI2ImageLoader.isCancellation(failure.underlying) { return }
                AppState.shared.recordError(failure.underlying, context: "ActivitiesEditorContainer.changePassage", surface: true,
                                            friendlyMessage: "Couldn't change the passage",
                                            retry: { [weak self] in Task { await self?.retryChange() } })
            }
        }

        // Delete (D11)

        /// Deleting a locked object asks first; confirming deletes the whole passage, both objects.
        func requestDelete(objectIndex: Int) {
            guard isLocked(objectIndex) else { return }
            presentation = .delete(BiblePassageMenu.deleteConfirmation)
        }

        func confirmDelete() async {
            guard case .delete? = presentation else { return }
            presentation = nil
            endEditing()
            highlightingObjectID = nil
            document = BiblePassageEditing.removingPassage(from: document)
            screenGeneration += 1
            _ = await saveIfChanged()
        }

        // MARK: Leaving

        /// Back: unsaved changes save first (an open edit commits), and a failed save stays on the page with
        /// the alert. No activity is ever deleted on the way out (D16, superseded round 5).
        func back() async {
            guard await leave() else { return }
            navigator?.pop()
        }

        /// D26/D27/D28: what the canvas area shows.
        enum CanvasContent: Equatable {
            /// The selected activity's editable canvas.
            case activity
            /// The activity-type grid, in place of the canvas (＋ is disabled meanwhile).
            case typeGrid
            /// A kind this editor can't edit yet, drawn read-only.
            case readOnly
        }

        private(set) var canvasContent: CanvasContent = .activity

        /// D27: the in-place grid's create runs the New Activity page's own create.
        private let newActivityActions: ActivityNewContainer.Actions
        /// C-086 `pendingType` while the grid's create is in flight; "" = interactive.
        private(set) var pendingType = ""

        /// D26: a chip swaps the canvas to that activity in place — the current one saves first, nothing
        /// navigates. D28: a kind the editor can't edit shows read-only. While the grid shows, a chip
        /// closes it (D27).
        func selectSlide(_ id: String, app: AppState? = nil) async {
            let app = app ?? .shared
            guard let target = app.activities[id] else { return }
            guard id != activityId || canvasContent == .typeGrid else { return }
            guard await leave() else { return }
            let editable = ActivityEntry.canvasKinds.contains(target.kind) && ActivitiesEditorMapper.isEditable(target.document)
            activityId = target.id
            activityKey = target.activityKey
            lessonVersionId = target.lessonVersionId
            kind = target.kind
            document = target.document
            savedDocument = target.document
            highlightingObjectID = nil
            presentation = nil
            endEditing()
            saveError = nil
            canvasContent = editable ? .activity : .readOnly
            screenGeneration += 1
        }

        /// D37: the activity the grid was opened from — its placeholder chip, and the new activity, follow it.
        private(set) var insertAfterID: String?

        /// D27: ＋ shows the type grid in place of the canvas, once the current activity has saved.
        func addActivity() async {
            guard canvasContent != .typeGrid, await leave() else { return }
            insertAfterID = activityId
            canvasContent = .typeGrid
            screenGeneration += 1
        }

        /// bible-verse-picker D15: the grid's model while its Bible picker is open or its save is running; the
        /// view watches it for the pick Select delivers.
        private(set) var bibleGrid: ActivityNewContainer.Model?

        /// D15: the Bible tile pushes Books; the pick saves in the background (D25) and the first part opens in place.
        private func pickBible() {
            guard let navigator else { return }
            let grid = ActivityNewContainer.Model(lessonId: lessonId, actions: newActivityActions,
                                                  navigator: GridNavigator(editor: navigator))
            grid.afterActivityId = insertAfterID
            grid.onCreated = { [weak self] id in Task { await self?.selectSlide(id) } }
            bibleGrid = grid
            grid.selectBible()
        }

        /// D27: a type picked on the grid. Text and Bible can be created today (the others are unavailable tiles);
        /// the new activity then opens in place through `selectSlide`. A Bible passage is placed by its own
        /// ordered save (`BibleSave`), so it skips `placeAfterInsertPoint`.
        func pickType(_ rawType: String, app: AppState? = nil) async {
            if rawType == ActivityTypeGrid.ActivityType.bibleVerse.rawValue {
                guard canvasContent == .typeGrid, pendingType.isEmpty else { return }
                pickBible()
                return
            }
            guard canvasContent == .typeGrid, pendingType.isEmpty,
                  rawType == ActivityTypeGrid.ActivityType.text.rawValue else { return }
            let grid = ActivityNewContainer.Model(lessonId: lessonId, actions: newActivityActions)
            var created: String?
            grid.onCreated = { created = $0 }
            pendingType = rawType
            await grid.selectText()
            pendingType = ""
            guard let created else { return }
            await placeAfterInsertPoint(created, app: app ?? .shared)
            await selectSlide(created, app: app)
        }

        /// D37: the server appends a created activity; move it to the placeholder's slot (right after the activity the
        /// grid was opened from). Already there — the last one was selected — needs no request. A failed reorder leaves
        /// it appended and surfaces the banner.
        private func placeAfterInsertPoint(_ created: String, app: AppState) async {
            guard let versionId = app.activities[created]?.lessonVersionId, let anchor = insertAfterID else { return }
            let current = app.activities(forVersion: versionId).sorted { $0.position < $1.position }.map(\.id)
            var order = current.filter { $0 != created }
            guard let at = order.firstIndex(of: anchor) else { return }
            order.insert(created, at: at + 1)
            guard order != current else { return }
            do {
                try await newActivityActions.reorder(versionId, order)
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                app.recordError(error, context: "ActivitiesEditorContainer.placeAfterInsertPoint", surface: true,
                                friendlyMessage: "Couldn't move the new activity")
            }
        }

        /// Whether the editor may move on (another activity, the grid, or out): an open edit commits, and
        /// unsaved changes save. A read-only activity or the grid has nothing to save.
        private func leave() async -> Bool {
            guard phase == .ready else { return true }
            if editingIndex >= 0 { _ = await commitEdit() }
            await waitForSaves()
            guard canvasContent == .activity else { return true }
            return await saveIfChanged()
        }

        private func saveIfChanged() async -> Bool {
            await waitForSaves()
            guard document != savedDocument else { return saveError == nil }
            return await commit()
        }
    }
}

/// A type-erased RNG, so the editor model can hold either the system generator or a seeded test one.
struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    init(_ base: some RandomNumberGenerator) { self.base = base }

    mutating func next() -> UInt64 { base.next() }
}
