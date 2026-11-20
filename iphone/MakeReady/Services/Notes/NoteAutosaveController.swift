//
//  NoteAutosaveController.swift
//  MakeReady
//
//  notes D10, D12, D7, D13, D24: one open note's autosave. `edited` restarts a 1.5 s debounce; a save is a
//  POST the first time (lazy create: nothing is sent while the text is blank) and a PATCH after, carrying
//  the last `updatedAt` verbatim. One request at a time; an edit made meanwhile is saved when it returns
//  (the shape of `EnrollDraftSync`). A save that cannot reach the server goes to `NoteSaveQueue`, and a
//  failure is console-only (D20): the editor never shows a banner for it.
//

import Foundation

@MainActor
final class NoteAutosaveController {

    /// The note's id: nil until its first POST lands, a `local-` id while that save waits in the queue.
    private(set) var noteId: String?
    /// D7: called when a save wrote over a newer server copy. The editor keeps its text; the container
    /// refreshes the list.
    var onStomped: @MainActor () -> Void = {}

    private let actions: NoteActions
    private let queue: NoteSaveQueue
    private let state: AppState
    private let debounce: Duration
    private let sleep: @MainActor (Duration) async throws -> Void

    /// The `updatedAt` of the last server copy, sent back as `baseUpdatedAt` (D23).
    private var baseUpdatedAt: String?
    /// The text the editor holds now, and the text last handed to the server or the queue.
    private var latest: String?
    private var lastSaved: String?
    private var debounceTask: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?

    init(note: StudyNote?, actions: NoteActions, queue: NoteSaveQueue, state: AppState,
         debounce: Duration = .milliseconds(1500),
         sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.noteId = note?.id
        self.baseUpdatedAt = note?.updatedAt
        self.lastSaved = note?.content
        self.actions = actions
        self.queue = queue
        self.state = state
        self.debounce = debounce
        self.sleep = sleep
    }

    // MARK: - Editor calls

    /// The text changed: save it once the editor has been still for the debounce.
    func edited(_ markdown: String) {
        latest = markdown
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do { try await self.sleep(self.debounce) } catch { return }
            self.debounceTask = nil
            self.startSaving()
        }
    }

    /// Leaving the editor or the app going to the background (D12): save now, after the request in flight.
    func flush() async {
        debounceTask?.cancel()
        debounceTask = nil
        startSaving()
        await awaitInFlight()
    }

    /// D10: a note left empty is deleted (an existing one) or never sent (a new one); otherwise `flush`.
    func leave() async {
        guard let latest, Self.isBlank(latest) else {
            await flush()
            return
        }
        debounceTask?.cancel()
        debounceTask = nil
        await awaitInFlight()
        guard let id = noteId else { return }
        if NoteSaveQueue.isLocalId(id) {
            queue.remove(noteId: id)
            _ = state.studyNotes.remove(id)
            state.persist()
        } else {
            do {
                try await actions.softDelete(id: id)
                queue.remove(noteId: id)
            } catch {
                failed(error, queueing: .delete, noteId: id)
            }
        }
        noteId = nil
        baseUpdatedAt = nil
        lastSaved = nil
    }

    /// Waits for the save in flight, and for any save it chained.
    func awaitInFlight() async {
        while let task = inFlight { await task.value }
    }

    // MARK: - Saving

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startSaving() {
        guard inFlight == nil else { return }       // the running save picks up the newest text when it returns
        inFlight = Task { [weak self] in
            guard let self else { return }
            await self.pump()
            self.inFlight = nil
        }
    }

    /// Saves the newest text until nothing differs from what was last sent.
    private func pump() async {
        while let content = latest, !Self.isBlank(content), content != lastSaved {
            lastSaved = content
            await save(content)
        }
    }

    private func save(_ content: String) async {
        do {
            if let id = noteId, !NoteSaveQueue.isLocalId(id) {
                let result = try await actions.update(id: id, content: content, baseUpdatedAt: baseUpdatedAt)
                baseUpdatedAt = result.note.updatedAt
                if result.stomped {
                    Log.notes.info("note save stomped a newer server copy (the editor's text is kept)")
                    onStomped()
                }
            } else if noteId == nil {
                let note = try await actions.create(content: content)
                noteId = note.id
                baseUpdatedAt = note.updatedAt
            } else if let id = noteId {
                // Still a local note: the queue owns its first POST (D13).
                enqueueOffline(content, noteId: id)
            }
        } catch {
            failed(error, queueing: .upsert(content: content, baseUpdatedAt: baseUpdatedAt), noteId: noteId)
        }
    }

    // MARK: - Failure

    /// D13, D20: a transport or transient failure keeps the work in the queue; anything else is only logged.
    private func failed(_ error: Error, queueing entry: NoteSaveEntry, noteId id: String?) {
        state.recordError(error, context: "NoteAutosaveController.save")
        if let http = error as? APIHTTPError, !NoteSaveQueue.isTransient(http) { return }
        switch entry {
        case .upsert(let content, _):
            enqueueOffline(content, noteId: id)
        case .delete:
            if let id { queue.enqueue(noteId: id, .delete) }
        }
    }

    /// Queues `content` under the note's id (a `local-` id for a never-created note) and shows it in the list.
    private func enqueueOffline(_ content: String, noteId id: String?) {
        let id = id ?? NoteSaveQueue.localIdPrefix + UUID().uuidString
        if noteId == nil {
            noteId = id
            followQueueAdoption()
        }
        queue.enqueue(noteId: id, .upsert(content: content, baseUpdatedAt: NoteSaveQueue.isLocalId(id) ? nil : baseUpdatedAt))
        let now = Self.isoNow()
        var note = state.studyNotes[id] ?? StudyNote(id: id, userId: nil, type: "NOTE", content: content, title: nil, preview: nil,
                                                     contextLabel: nil, isActive: true, createdAt: now, updatedAt: now, links: [])
        note.content = content
        note.title = nil
        note.preview = nil
        note.updatedAt = now
        state.studyNotes.upsert(note)
        state.persist()
    }

    /// The queue's flush gave a local note its server id: keep saving under it, not under the local id.
    private func followQueueAdoption() {
        let previous = queue.onIdAdopted
        queue.onIdAdopted = { [weak self] localId, serverId in
            previous(localId, serverId)
            guard let self, self.noteId == localId else { return }
            self.noteId = serverId
            self.baseUpdatedAt = self.state.studyNotes[serverId]?.updatedAt
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func isoNow() -> String { isoFormatter.string(from: Date()) }
}
