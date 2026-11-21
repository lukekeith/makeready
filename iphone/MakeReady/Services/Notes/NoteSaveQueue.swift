//
//  NoteSaveQueue.swift
//  MakeReady
//
//  notes D13, D24: the saves a note could not send yet, one entry per note id (latest wins), kept as JSON
//  per API environment and flushed one request at a time on launch and when the network returns.
//  Failures here are background work: they are logged through `recordError` (console-only, never a banner).
//

import Foundation

/// What a note still has to tell the server.
enum NoteSaveEntry: Codable, Equatable {
    /// The note's text, and the `updatedAt` string it was edited from (sent verbatim, D23); nil for a note
    /// the server has never seen.
    case upsert(content: String, baseUpdatedAt: String?)
    case delete
}

/// How one entry ended in a flush.
enum NoteFlushOutcome: Equatable {
    /// The server has it.
    case sent(String)
    /// The server had a newer copy and this one was written over it (D7); the entry is done.
    case stomped(String)
    /// The entry was discarded: nothing to send, the note is gone, or the server refused it.
    case dropped(String)
    /// Offline: the entry stays and the flush stopped here.
    case kept(String)
}

@MainActor
final class NoteSaveQueue {

    /// The queue of the selected API environment. Rebuilt when the environment changes, so entries of one
    /// environment never reach another (D24).
    static var shared: NoteSaveQueue {
        let url = defaultFileURL()
        if let current, current.fileURL == url { return current }
        let queue = NoteSaveQueue(fileURL: url, actions: NoteActions(), state: AppState.shared)
        current = queue
        return queue
    }
    private static var current: NoteSaveQueue?

    /// `notes-queue.json` beside the state cache, named per environment as `StatePersistence`'s file is.
    private static func defaultFileURL() -> URL {
        let name: String
        switch AppConfiguration.selectedEnvironment {
        case .production: name = "notes-queue.json"
        case .local: name = "notes-queue_local.json"
        case .staging: name = "notes-queue_staging.json"
        }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent(name)
    }

    /// A note id that only exists on this device until its first save lands.
    static let localIdPrefix = "local-"
    static func isLocalId(_ id: String) -> Bool { id.hasPrefix(localIdPrefix) }

    /// Called with (local id, server id) when a first save lands, so an open editor can switch ids.
    var onIdAdopted: (String, String) -> Void = { _, _ in }

    private struct Item: Codable, Equatable {
        let noteId: String
        var entry: NoteSaveEntry
    }

    private let fileURL: URL
    private let actions: NoteActions
    private let state: AppState
    /// Insertion order; a re-enqueued note keeps its place.
    private var items: [Item]
    private var isFlushing = false

    init(fileURL: URL, actions: NoteActions, state: AppState) {
        self.fileURL = fileURL
        self.actions = actions
        self.state = state
        items = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? []
    }

    // MARK: - Queue

    func enqueue(noteId: String, _ entry: NoteSaveEntry) {
        if let index = items.firstIndex(where: { $0.noteId == noteId }) {
            items[index].entry = entry
        } else {
            items.append(Item(noteId: noteId, entry: entry))
        }
        writeFile()
    }

    func entry(for noteId: String) -> NoteSaveEntry? {
        items.first { $0.noteId == noteId }?.entry
    }

    /// Forgets a note's entry without sending it (a never-created note emptied, D10).
    func remove(noteId: String) {
        guard entry(for: noteId) != nil else { return }
        drop(noteId)
    }

    /// Empties memory and deletes the file (sign-out, D24).
    func clear() {
        items = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Flush

    /// Sends every entry that was queued when the flush began, one request at a time, in insertion order.
    /// A flush while one runs returns `[]` at once. A transport failure keeps its entry and ends the flush.
    func flush() async -> [NoteFlushOutcome] {
        guard !isFlushing else { return [] }
        isFlushing = true
        defer { isFlushing = false }

        var outcomes: [NoteFlushOutcome] = []
        for item in items {
            guard let entry = entry(for: item.noteId) else { continue }
            let outcome = await send(noteId: item.noteId, entry)
            outcomes.append(outcome)
            if case .kept = outcome { break }
        }
        return outcomes
    }

    private func send(noteId: String, _ entry: NoteSaveEntry) async -> NoteFlushOutcome {
        do {
            switch entry {
            case .delete:
                if Self.isLocalId(noteId) {
                    finish(noteId, sent: entry)
                    return .dropped(noteId)
                }
                try await actions.softDelete(id: noteId)
                finish(noteId, sent: entry)
                return .sent(noteId)

            case .upsert(let content, let baseUpdatedAt):
                if Self.isLocalId(noteId) {
                    let note = try await actions.create(content: content)
                    adopt(localId: noteId, note: note, sent: entry)
                    return .sent(noteId)
                }
                let result = try await actions.update(id: noteId, content: content, baseUpdatedAt: baseUpdatedAt)
                finish(noteId, sent: entry)
                if result.stomped {
                    Log.notes.info("note save stomped a newer server copy (the server's text is kept)")
                    return .stomped(noteId)
                }
                return .sent(noteId)
            }
        } catch let error where NoteActions.isNotFound(error) {
            _ = state.studyNotes.remove(noteId)
            state.persist()
            drop(noteId)
            return .dropped(noteId)
        } catch let error as APIHTTPError {
            state.recordError(error, context: "NoteSaveQueue.flush")
            // A session, rate-limit or server problem passes: keep the text and try again next flush
            // (D13, D20). Any other 4xx is permanent: the server will never take this entry.
            if Self.isTransient(error) { return .kept(noteId) }
            drop(noteId)
            return .dropped(noteId)
        } catch {
            state.recordError(error, context: "NoteSaveQueue.flush")
            return .kept(noteId)
        }
    }

    /// A session, rate-limit or server problem: the same request may succeed later.
    static func isTransient(_ error: APIHTTPError) -> Bool {
        [401, 408, 429].contains(error.status) || error.status >= 500
    }

    /// The server took `sent`: the entry goes, unless the note was edited again while the request ran.
    private func finish(_ noteId: String, sent: NoteSaveEntry) {
        guard entry(for: noteId) == sent else { return }
        drop(noteId)
    }

    /// The first save of a local note landed (D13): the server note replaces the local one in the store and
    /// the entry moves to the server id; an edit or delete made while the request ran stays queued against it.
    private func adopt(localId: String, note: StudyNote, sent: NoteSaveEntry) {
        _ = state.studyNotes.remove(localId)
        state.persist()
        if let newer = entry(for: localId), newer != sent, let index = items.firstIndex(where: { $0.noteId == localId }) {
            switch newer {
            case .upsert(let content, _):
                items[index] = Item(noteId: note.id, entry: .upsert(content: content, baseUpdatedAt: note.updatedAt))
            case .delete:
                // Emptied while the POST ran: the server now has the note, so the delete goes to its id (D10).
                items[index] = Item(noteId: note.id, entry: .delete)
            }
            writeFile()
        } else {
            drop(localId)
        }
        onIdAdopted(localId, note.id)
    }

    private func drop(_ noteId: String) {
        items.removeAll { $0.noteId == noteId }
        writeFile()
    }

    private func writeFile() {
        do {
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
        } catch {
            state.recordError(error, context: "NoteSaveQueue.writeFile")
        }
    }
}
