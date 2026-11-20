//
//  NoteActions.swift
//  MakeReady
//
//  notes SPEC §Contract: `/api/notes` for the leader's study notes. The only APIClient user for notes.
//  Every call keeps the HTTP status (`requestWithStatus`), so a 404 arrives as `APIHTTPError` (D24), and
//  every call refreshes `AppState.studyNotes` before it returns.
//

import Foundation

/// `update`'s result: the stored note, and whether the server wrote over a newer copy (D7).
struct NoteUpdateResult: Equatable {
    let note: StudyNote
    let stomped: Bool
}

struct NoteActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?

    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// The page size `load` asks for (the server's cap, D25).
    static let pageLimit = 100

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    private struct One: Decodable { let success: Bool; let data: StudyNote; let stomped: Bool? }
    private struct Page: Decodable { let success: Bool; let data: [StudyNote]; let pagination: NotesPagination }

    /// SC6: every page of the list, newest `updatedAt` first, followed by `pagination.hasMore`.
    /// Without `q` the result replaces the stored list (a note deleted elsewhere drops); with `q` it
    /// only upserts the matches (D8). Returns the ids in the server's order.
    @MainActor
    func load(q: String? = nil) async throws -> [String] {
        let query = q.flatMap { $0.isEmpty ? nil : $0 }
        var notes: [StudyNote] = []
        var offset = 0
        while true {
            var endpoint = "/api/notes?type=NOTE&orderBy=updatedAt&limit=\(Self.pageLimit)&offset=\(offset)"
            if let query { endpoint += "&q=\(Self.encode(query))" }
            let data = try await api.requestWithStatus(endpoint: endpoint, method: "GET", body: nil)
            let page = try decode(Page.self, data)
            notes += page.data
            guard page.pagination.hasMore else { break }
            offset += Self.pageLimit
        }
        state.studyNotes.merge(notes, removeStale: query == nil)
        state.persist()
        return notes.map(\.id)
    }

    @MainActor
    func loadOne(id: String) async throws -> StudyNote {
        let data = try await api.requestWithStatus(endpoint: "/api/notes/\(id)", method: "GET", body: nil)
        return store(try decode(One.self, data).data)
    }

    /// D6, D10: the first save of a new note.
    @MainActor
    func create(content: String) async throws -> StudyNote {
        let data = try await api.requestWithStatus(endpoint: "/api/notes", method: "POST", body: ["type": "NOTE", "content": content])
        return store(try decode(One.self, data).data)
    }

    /// D7, D23: `baseUpdatedAt` is the note's `updatedAt` string, sent verbatim; omitted when nil.
    @MainActor
    func update(id: String, content: String, baseUpdatedAt: String?) async throws -> NoteUpdateResult {
        var body: [String: Any] = ["content": content]
        if let baseUpdatedAt { body["baseUpdatedAt"] = baseUpdatedAt }
        let data = try await api.requestWithStatus(endpoint: "/api/notes/\(id)", method: "PATCH", body: body)
        let response = try decode(One.self, data)
        return NoteUpdateResult(note: store(response.data), stomped: response.stomped ?? false)
    }

    /// D10, D24: the note leaves the store whether the server deleted it or no longer has it (404).
    @MainActor
    func softDelete(id: String) async throws {
        do {
            _ = try await api.requestWithStatus(endpoint: "/api/notes/\(id)", method: "DELETE", body: nil)
        } catch let error where Self.isNotFound(error) {
            // Already gone: the same end state as a delete.
        }
        _ = state.studyNotes.remove(id)
        state.persist()
    }

    /// A 404 from any call: the note is missing, inactive or another user's (D6).
    static func isNotFound(_ error: Error) -> Bool {
        (error as? APIHTTPError)?.status == 404
    }

    @MainActor
    private func store(_ note: StudyNote) -> StudyNote {
        state.studyNotes.upsert(note)
        state.persist()
        return note
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONDecoder.apiDecoder.decode(type, from: data)
    }

    /// Percent-encodes a query value: everything but unreserved characters, so `&`, `+` and `=` in a
    /// search never end the parameter.
    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? value
    }
}
