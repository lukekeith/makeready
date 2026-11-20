//
//  NoteSaveQueueTests.swift
//  MakeReadyCaptureTests
//
//  notes Task 10: the persistent per-environment note save queue (D13, D24) and its connectivity flush.
//

import Network
import XCTest
@testable import MakeReady

@MainActor
final class NoteSaveQueueTests: XCTestCase {

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("notes-queue-\(UUID().uuidString).json")
    }

    private func noteJSON(_ id: String, content: String = "body") -> String {
        """
        {"id":"\(id)","memberId":null,"userId":"u1","type":"NOTE","content":"\(content)","title":null,"preview":null,\
        "contextLabel":null,"isActive":true,"createdAt":"2026-11-20T10:00:00.123Z","updatedAt":"2026-11-20T10:05:00.456Z","links":[]}
        """
    }

    func testQueueSurvivesARelaunchLatestWins() {
        let url = tmpURL()
        let q1 = NoteSaveQueue(fileURL: url, actions: NoteActions(api: StubAPIClient(), state: AppState()), state: AppState())
        q1.enqueue(noteId: "n1", .upsert(content: "a", baseUpdatedAt: nil))
        q1.enqueue(noteId: "n1", .upsert(content: "b", baseUpdatedAt: "t1"))
        let q2 = NoteSaveQueue(fileURL: url, actions: NoteActions(api: StubAPIClient(), state: AppState()), state: AppState())
        XCTAssertEqual(q2.entry(for: "n1"), .upsert(content: "b", baseUpdatedAt: "t1"))
    }

    func testALocalNoteFlushesAsPostAndAdoptsTheServerId() async {
        let api = StubAPIClient(); let state = AppState()
        state.studyNotes.upsert(.stub(id: "local-1"))
        api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON("srv1", content: "hi"))}"#)
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        var adopted: (String, String)?
        q.onIdAdopted = { adopted = ($0, $1) }
        q.enqueue(noteId: "local-1", .upsert(content: "hi", baseUpdatedAt: nil))
        _ = await q.flush()
        XCTAssertNil(state.studyNotes["local-1"]); XCTAssertNotNil(state.studyNotes["srv1"])
        XCTAssertEqual(adopted?.1, "srv1")
        XCTAssertNil(q.entry(for: "local-1")); XCTAssertNil(q.entry(for: "srv1"))
    }

    func testStompedIsReportedAndTheEntryCleared() async {
        let api = StubAPIClient(); let state = AppState()
        api.stub("PATCH", "/api/notes/n1", json: #"{"success":true,"stomped":true,"data":\#(noteJSON("n1", content: "mine"))}"#)
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        q.enqueue(noteId: "n1", .upsert(content: "mine", baseUpdatedAt: "2026-11-20T10:00:00.000Z"))
        let outcomes = await q.flush()
        XCTAssertEqual(outcomes, [.stomped("n1")])
        XCTAssertNil(q.entry(for: "n1"))
    }

    func testA404DropsTheEntryAndTheNote() async {
        let api = StubAPIClient(); let state = AppState()
        state.studyNotes.upsert(.stub(id: "n1"))
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Note not found") }
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        q.enqueue(noteId: "n1", .upsert(content: "x", baseUpdatedAt: nil))
        let outcomes = await q.flush()
        XCTAssertEqual(outcomes, [.dropped("n1")])
        XCTAssertNil(state.studyNotes["n1"])
    }

    func testOfflineKeepsTheEntryAndALocalDeleteSendsNothing() async {
        let api = StubAPIClient(); let state = AppState()
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        q.enqueue(noteId: "local-9", .delete)
        q.enqueue(noteId: "n2", .upsert(content: "x", baseUpdatedAt: nil))
        let outcomes = await q.flush()
        XCTAssertEqual(outcomes, [.dropped("local-9"), .kept("n2")])
        XCTAssertEqual(api.calls.count, 1)
        XCTAssertNotNil(q.entry(for: "n2"))
    }

    func testALocalNoteEmptiedWhileItsPostIsInFlightStillGetsDeleted() async {
        let api = StubAPIClient(); let state = AppState()
        api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON("srv1", content: "hi"))}"#)
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        api.beforeReturn = { _, _ in q.enqueue(noteId: "local-1", .delete) }
        q.enqueue(noteId: "local-1", .upsert(content: "hi", baseUpdatedAt: nil))
        _ = await q.flush()
        XCTAssertNil(q.entry(for: "local-1"))
        XCTAssertEqual(q.entry(for: "srv1"), .delete)
    }

    func testATransientHTTPErrorKeepsTheEntryAndStopsTheFlush() async {
        for status in [401, 408, 429, 500, 503] {
            let api = StubAPIClient(); let state = AppState()
            api.errorFor = { _, _ in APIHTTPError(status: status, message: nil) }
            let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
            q.enqueue(noteId: "n1", .upsert(content: "x", baseUpdatedAt: nil))
            q.enqueue(noteId: "n2", .upsert(content: "y", baseUpdatedAt: nil))
            let outcomes = await q.flush()
            XCTAssertEqual(outcomes, [.kept("n1")], "status \(status)")
            XCTAssertNotNil(q.entry(for: "n1"), "status \(status)")
            XCTAssertEqual(api.calls.count, 1, "status \(status)")
        }
    }

    func testAPermanentHTTPErrorDropsTheEntryAndTheFlushContinues() async {
        let api = StubAPIClient(); let state = AppState()
        api.errorFor = { endpoint, _ in endpoint.hasSuffix("n1") ? APIHTTPError(status: 422, message: "bad") : nil }
        api.stub("PATCH", "/api/notes/n2", json: #"{"success":true,"stomped":false,"data":\#(noteJSON("n2"))}"#)
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        q.enqueue(noteId: "n1", .upsert(content: "x", baseUpdatedAt: nil))
        q.enqueue(noteId: "n2", .upsert(content: "y", baseUpdatedAt: nil))
        let outcomes = await q.flush()
        XCTAssertEqual(outcomes, [.dropped("n1"), .sent("n2")])
        XCTAssertNil(q.entry(for: "n1"))
    }

    func testAFlushDuringAFlushSendsOnce() async {
        let api = StubAPIClient(); let state = AppState(); api.delayFor = { _ in 0.2 }
        api.stub("DELETE", "/api/notes/n1", json: #"{"success":true,"message":"Note deleted"}"#)
        let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
        q.enqueue(noteId: "n1", .delete)
        let first = Task { await q.flush() }
        await Task.yield() // the first flush is now waiting on its request
        let second = await q.flush()
        XCTAssertEqual(second, [])
        let firstOutcomes = await first.value
        XCTAssertEqual(firstOutcomes, [.sent("n1")])
        XCTAssertEqual(api.calls.count, 1)
    }

    func testConnectivityFlushesOnlyOnTransitionToSatisfied() {
        let c = NotesConnectivity(); var fired = 0
        c.onSatisfied = { fired += 1 }
        [NWPath.Status.unsatisfied, .satisfied, .satisfied, .unsatisfied, .satisfied].forEach { c.handle($0) }
        XCTAssertEqual(fired, 2)
    }

    func testClearAllDataEmptiesTheQueue() {
        NoteSaveQueue.shared.enqueue(noteId: "n1", .delete)
        AppState.shared.clearAllData()
        XCTAssertNil(NoteSaveQueue.shared.entry(for: "n1"))
    }
}
