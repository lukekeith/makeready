//
//  NoteActionsTests.swift
//  MakeReadyCaptureTests
//
//  notes Task 9: NoteActions over a StubAPIClient — paging (SC6), search (D8), the stomped echo (D23, D7),
//  create (D6, D10) and soft delete (D10, D24).
//

import XCTest
@testable import MakeReady

@MainActor
final class NoteActionsTests: XCTestCase {

    private func noteJSON(_ id: String, content: String = "body") -> String {
        """
        {"id":"\(id)","memberId":null,"userId":"u1","type":"NOTE","content":"\(content)","title":null,"preview":null,\
        "contextLabel":null,"isActive":true,"createdAt":"2026-11-20T10:00:00.123Z","updatedAt":"2026-11-20T10:05:00.456Z","links":[]}
        """
    }

    private func page(_ ids: [String], total: Int, offset: Int, hasMore: Bool) -> String {
        let data = ids.map { noteJSON($0) }.joined(separator: ",")
        return #"{"success":true,"data":[\#(data)],"pagination":{"total":\#(total),"limit":100,"offset":\#(offset),"hasMore":\#(hasMore)}}"#
    }

    func testLoadPagesUntilHasMoreIsFalseAndDropsStaleNotes() async throws {
        let api = StubAPIClient(); let state = AppState()
        state.studyNotes.upsert(.stub(id: "gone"))
        api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=0", json: page(["a", "b"], total: 3, offset: 0, hasMore: true))
        api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=100", json: page(["c"], total: 3, offset: 100, hasMore: false))
        let ids = try await NoteActions(api: api, state: state).load()
        XCTAssertEqual(ids, ["a", "b", "c"])
        XCTAssertEqual(Set(state.studyNotes.all.map(\.id)), ["a", "b", "c"])
    }

    private func tmpQueue(_ api: StubAPIClient, _ state: AppState) -> NoteSaveQueue {
        NoteSaveQueue(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("notes-queue-\(UUID().uuidString).json"),
                      actions: NoteActions(api: api, state: state), state: state)
    }

    func testFullLoadKeepsLocalNotesAndQueuedEditsAndSkipsQueuedDeletes() async throws {
        let api = StubAPIClient(); let state = AppState()
        let queue = tmpQueue(api, state)
        state.studyNotes.upsert(.stub(id: "local-1"))
        var edited = StudyNote.stub(id: "a"); edited.content = "offline edit"
        state.studyNotes.upsert(edited)
        queue.enqueue(noteId: "local-1", .upsert(content: "x", baseUpdatedAt: nil))
        queue.enqueue(noteId: "a", .upsert(content: "offline edit", baseUpdatedAt: "2026-11-20T10:05:00.456Z"))
        queue.enqueue(noteId: "c", .delete)
        api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=0", json: page(["a", "b", "c"], total: 3, offset: 0, hasMore: false))
        _ = try await NoteActions(api: api, state: state, queue: queue).load()
        XCTAssertEqual(Set(state.studyNotes.all.map(\.id)), ["local-1", "a", "b"])
        XCTAssertEqual(state.studyNotes["a"]?.content, "offline edit")
        XCTAssertEqual(state.studyNotes["b"]?.content, "body")
    }

    func testSearchUpsertsMatchesWithoutDroppingOthers() async throws {
        let api = StubAPIClient(); let state = AppState()
        state.studyNotes.upsert(.stub(id: "other"))
        api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=0&q=grace%20alone", json: page(["g"], total: 1, offset: 0, hasMore: false))
        let ids = try await NoteActions(api: api, state: state).load(q: "grace alone")
        XCTAssertEqual(ids, ["g"])
        XCTAssertEqual(Set(state.studyNotes.all.map(\.id)), ["other", "g"])
    }

    func testUpdateEchoesBaseUpdatedAtVerbatimAndReturnsStomped() async throws {
        let api = StubAPIClient(); let state = AppState()
        api.stub("PATCH", "/api/notes/n1", json: #"{"success":true,"stomped":true,"data":\#(noteJSON("n1", content: "v2"))}"#)
        let result = try await NoteActions(api: api, state: state).update(id: "n1", content: "v2", baseUpdatedAt: "2026-11-20T10:05:00.456Z")
        XCTAssertTrue(result.stomped)
        XCTAssertEqual(api.calls.last?.body?["baseUpdatedAt"] as? String, "2026-11-20T10:05:00.456Z")
        XCTAssertEqual(state.studyNotes["n1"]?.content, "v2")
    }

    func testCreatePostsANoteAndStoresIt() async throws {
        let api = StubAPIClient(); let state = AppState()
        api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON("srv1", content: "Hi"))}"#)
        let note = try await NoteActions(api: api, state: state).create(content: "Hi")
        XCTAssertEqual(api.calls.last?.body?["type"] as? String, "NOTE")
        XCTAssertEqual(note.id, "srv1")
        XCTAssertNotNil(state.studyNotes["srv1"])
    }

    func testSoftDeleteRemovesTheNoteEvenOn404() async throws {
        let api = StubAPIClient(); let state = AppState()
        state.studyNotes.upsert(.stub(id: "n1"))
        api.errorFor = { endpoint, _ in endpoint == "/api/notes/n1" ? APIHTTPError(status: 404, message: "Note not found") : nil }
        try await NoteActions(api: api, state: state).softDelete(id: "n1")
        XCTAssertNil(state.studyNotes["n1"])
    }
}
