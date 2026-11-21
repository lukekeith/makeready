import SwiftUI

/// notes D9, D10, D12: one open note. Holds the editor's document, hands the serialized markdown to the
/// `NoteAutosaveController`, and leaves through it. The codec runs on open (parse, once) and on a save
/// (serialize), never per keystroke: an edit only stores the newest document, and a short coalescing
/// pause (or Back / background, at once) turns it into markdown for the controller's debounce.
@MainActor @Observable
final class NoteEditorModel {
    /// The pause that merges a burst of edits into one `serialize` call. Shorter than the controller's 1.5 s.
    static let serializeDelay: Duration = .milliseconds(300)

    /// Set by the container: pops the page once the controller has settled.
    var onPop: () -> Void = {}

    /// D5, D9: a new note opens with the keyboard up; a reopened one opens to read.
    var opensEditing: Bool { source == nil }
    var initialSelection: NSRange { NSRange(location: 0, length: 0) }
    /// The stored note parsed once, on first use (D9) — a rebuilt parent view never re-parses it.
    var initialText: AttributedString { ensureOpen()?.text ?? AttributedString() }
    /// False only while an uncached `.noteEditor` note is still being fetched.
    var isReady: Bool { noteId == nil || source != nil }

    private let noteId: String?
    private let actions: NoteActions
    private let queue: NoteSaveQueue
    private let state: AppState
    private var source: StudyNote?
    private var pending: AttributedString?
    private var serializeTask: Task<Void, Never>?

    private struct Opened {
        let text: AttributedString
        let controller: NoteAutosaveController
    }
    @ObservationIgnored private var opened: Opened?

    init(noteId: String?, note: StudyNote?, actions: NoteActions? = nil,
         queue: NoteSaveQueue? = nil, state: AppState? = nil) {
        let state = state ?? AppState.shared
        self.noteId = noteId
        self.source = note
        self.actions = actions ?? NoteActions()
        self.queue = queue ?? NoteSaveQueue.shared
        self.state = state
    }

    /// The cached note for `id`, or none.
    static func cachedNote(id: String) -> StudyNote? { AppState.shared.studyNotes[id] }

    /// Builds the parsed text and the controller on first use. D10: a new note starts empty and sends nothing.
    @discardableResult
    private func ensureOpen() -> Opened? {
        if let opened { return opened }
        guard isReady else { return nil }
        let controller = NoteAutosaveController(note: source, actions: actions, queue: queue, state: state)
        controller.onStomped = { [actions, state] in
            Task { @MainActor in
                do { _ = try await actions.load() } catch { state.recordError(error, context: "NoteEditorModel.onStomped") }
            }
        }
        let made = Opened(text: source.map { NoteDocumentCodec.parse($0.content) } ?? AttributedString(), controller: controller)
        opened = made
        return made
    }

    /// Background work for the page's `.task`: refresh a cached note, or fetch one that is not cached.
    func refresh() async {
        guard let noteId else { return }
        do {
            let note = try await actions.loadOne(id: noteId)
            if source == nil { source = note }
        } catch {
            if isReady {
                state.recordError(error, context: "NoteEditorModel.refresh")
            } else {
                state.recordError(error, context: "NoteEditorModel.refresh", surface: true,
                                  friendlyMessage: "Couldn't open the note")
                onPop()
            }
        }
    }

    // MARK: - Editor calls

    /// An edit: keep the newest document; serialize it once the burst has paused.
    func setText(_ doc: AttributedString) {
        pending = doc
        serializeTask?.cancel()
        serializeTask = Task { [weak self] in
            do { try await Task.sleep(for: Self.serializeDelay) } catch { return }
            self?.commitPending()
        }
    }

    private func commitPending() {
        serializeTask?.cancel()
        serializeTask = nil
        guard let doc = pending else { return }
        pending = nil
        ensureOpen()?.controller.edited(NoteDocumentCodec.serialize(doc))
    }

    /// D10, D12: Back saves (or deletes an emptied note) before the page pops.
    func back() async {
        await leave()
        onPop()
    }

    /// The page left the screen by any route (Back, swipe, tab change): settle through the controller.
    func leave() async {
        commitPending()
        await ensureOpen()?.controller.leave()
    }

    /// D12: going to the background saves now.
    func scenePhaseChanged(_ phase: ScenePhase) async {
        guard phase == .background else { return }
        commitPending()
        await ensureOpen()?.controller.flush()
    }
}

/// notes D17: the pushed note editor — d2m's `note-editor` screen over `NoteEditorModel`.
struct NoteEditorContainer: View {
    @State var model: NoteEditorModel
    @Environment(\.ui2Navigator) private var navigator
    @Environment(\.scenePhase) private var scenePhase

    init(model: NoteEditorModel) {
        _model = State(initialValue: model)
    }

    /// `.newNote`: no id; `.noteEditor`: the stored note, parsed from `AppState.studyNotes` when cached.
    init(noteId: String?) {
        _model = State(initialValue: NoteEditorModel(noteId: noteId, note: noteId.flatMap { NoteEditorModel.cachedNote(id: $0) }))
    }

    var body: some View {
        Group {
            if model.isReady {
                // No manual keyboard offset: the shell ignores the keyboard safe area and C-001 docks its own strip.
                NoteEditorScreen(
                    state: .init(text: model.initialText, selection: model.initialSelection, editing: model.opensEditing),
                    onTextChange: model.setText,
                    onBack: { Task { await model.back() } }
                )
            } else {
                Token.layoutBackground.ignoresSafeArea()
            }
        }
        .task {
            model.onPop = { navigator.pop() }
            await model.refresh()
        }
        .onChange(of: scenePhase) { _, phase in Task { await model.scenePhaseChanged(phase) } }
        .onDisappear { Task { await model.leave() } }
    }
}
