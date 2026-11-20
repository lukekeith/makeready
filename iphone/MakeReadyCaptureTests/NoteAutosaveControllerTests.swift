//
//  NoteAutosaveControllerTests.swift
//  MakeReadyCaptureTests
//
//  notes Task 11: the editor's autosave — 1.5 s debounce, lazy create, empty delete, offline queueing,
//  stomped and one request in flight (D7, D10, D12, D13, D20, D23, D24).
//

import XCTest
@testable import MakeReady

/// A clock the test drives: `sleep` returns only when `advance` has moved time past its deadline, or
/// when its task is cancelled.
@MainActor
final class ManualNoteClock {
    private struct Waiter { let deadline: Duration; let continuation: CheckedContinuation<Void, Error> }
    private var now: Duration = .zero
    private var waiters: [UUID: Waiter] = [:]
    /// Runs after each `advance`, to let the work the wake-up started finish (set by the test).
    var settle: () async -> Void = {}

    func sleep(_ duration: Duration) async throws {
        let id = UUID()
        let deadline = now + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters[id] = Waiter(deadline: deadline, continuation: continuation)
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    private func cancel(_ id: UUID) {
        waiters.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
    }

    func advance(_ duration: Duration) async {
        for _ in 0..<5 { await Task.yield() }       // let a debounce started just before this call register its sleep first
        now += duration
        for (id, waiter) in waiters where waiter.deadline <= now {
            waiters[id] = nil
            waiter.continuation.resume()
        }
        for _ in 0..<5 { await Task.yield() }
        await settle()
    }
}

extension StudyNote {
    /// Test-only: a note whose `updatedAt` is exactly `updatedAtString`.
    static func stub(id: String, updatedAtString: String) -> StudyNote {
        var note = StudyNote.stub(id: id)
        note.updatedAt = updatedAtString
        return note
    }
}

@MainActor
final class NoteAutosaveControllerTests: XCTestCase {

    private func noteJSON(_ id: String, content: String = "body") -> String {
        """
        {"id":"\(id)","memberId":null,"userId":"u1","type":"NOTE","content":"\(content)","title":null,"preview":null,\
        "contextLabel":null,"isActive":true,"createdAt":"2026-11-20T10:00:00.123Z","updatedAt":"2026-11-20T10:05:00.456Z","links":[]}
        """
    }

    private func makeControllerWithQueue(
        note: StudyNote?, stubPost: String? = nil, stubPatch: String? = nil, stubDelete: String? = nil,
        stomped: Bool = false, patchDelay: TimeInterval = 0
    ) -> (NoteAutosaveController, StubAPIClient, ManualNoteClock, NoteSaveQueue, AppState) {
        let api = StubAPIClient()
        let state = AppState()
        if let note { state.studyNotes.upsert(note) }
        if let stubPost { api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON(stubPost))}"#) }
        if let stubPatch {
            api.stub("PATCH", "/api/notes/\(stubPatch)", json: #"{"success":true,"stomped":\#(stomped),"data":\#(noteJSON(stubPatch))}"#)
        }
        if let stubDelete { api.stub("DELETE", "/api/notes/\(stubDelete)", json: #"{"success":true,"message":"Note deleted"}"#) }
        if patchDelay > 0 { api.delayFor = { $0.hasPrefix("/api/notes/") ? patchDelay : 0 } }
        let actions = NoteActions(api: api, state: state)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notes-queue-\(UUID().uuidString).json")
        let queue = NoteSaveQueue(fileURL: url, actions: actions, state: state)
        let clock = ManualNoteClock()
        let controller = NoteAutosaveController(note: note, actions: actions, queue: queue, state: state,
                                                sleep: { try await clock.sleep($0) })
        clock.settle = { await controller.awaitInFlight() }
        return (controller, api, clock, queue, state)
    }

    private func makeController(
        note: StudyNote?, stubPost: String? = nil, stubPatch: String? = nil, stubDelete: String? = nil,
        stomped: Bool = false, patchDelay: TimeInterval = 0
    ) -> (NoteAutosaveController, StubAPIClient, ManualNoteClock) {
        let made = makeControllerWithQueue(note: note, stubPost: stubPost, stubPatch: stubPatch, stubDelete: stubDelete,
                                           stomped: stomped, patchDelay: patchDelay)
        return (made.0, made.1, made.2)
    }

    func testNoRequestUntilContentIsNonEmptyThenOnePostAfterTheDebounce() async {
        let (c, api, clock) = makeController(note: nil, stubPost: "srv1")
        c.edited("   ")
        await clock.advance(.milliseconds(1500))
        XCTAssertTrue(api.calls.isEmpty)
        c.edited("H"); c.edited("Hi")
        await clock.advance(.milliseconds(1499))
        XCTAssertTrue(api.calls.isEmpty)
        await clock.advance(.milliseconds(1))
        XCTAssertEqual(api.calls.map(\.method), ["POST"])
        XCTAssertEqual(api.calls[0].body?["content"] as? String, "Hi")
        XCTAssertEqual(c.noteId, "srv1")
    }

    func testLaterSavesPatchWithTheLastUpdatedAt() async {
        let (c, api, _) = makeController(note: .stub(id: "n1", updatedAtString: "2026-11-20T10:00:00.123Z"), stubPatch: "n1")
        c.edited("v2")
        await c.flush()
        XCTAssertEqual(api.calls.last?.method, "PATCH")
        XCTAssertEqual(api.calls.last?.body?["baseUpdatedAt"] as? String, "2026-11-20T10:00:00.123Z")
    }

    func testLeavingAnEmptiedNoteDeletesItAndANewEmptyOneSendsNothing() async {
        let (existing, api1, _) = makeController(note: .stub(id: "n1"), stubDelete: "n1")
        existing.edited("")
        await existing.leave()
        XCTAssertEqual(api1.calls.map(\.method), ["DELETE"])
        let (fresh, api2, _) = makeController(note: nil)
        fresh.edited(" \n ")
        await fresh.leave()
        XCTAssertTrue(api2.calls.isEmpty)
    }

    func testOfflineSaveQueuesUnderALocalIdAndShowsInTheList() async {
        let (c, api, _, queue, state) = makeControllerWithQueue(note: nil)
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        c.edited("Offline idea")
        await c.flush()
        let id = try! XCTUnwrap(c.noteId)
        XCTAssertTrue(NoteSaveQueue.isLocalId(id))
        XCTAssertEqual(queue.entry(for: id), .upsert(content: "Offline idea", baseUpdatedAt: nil))
        XCTAssertEqual(state.studyNotes[id]?.content, "Offline idea")
    }

    func testStompedKeepsTheTextAndAsksForARefresh() async {
        let (c, _, _) = makeController(note: .stub(id: "n1"), stubPatch: "n1", stomped: true)
        var refreshed = false
        c.onStomped = { refreshed = true }
        c.edited("my words")
        await c.flush()
        XCTAssertTrue(refreshed)
    }

    func testAnEditDuringTheRequestIsSavedAfterIt() async {
        let (c, api, _) = makeController(note: .stub(id: "n1"), stubPatch: "n1", patchDelay: 0.2)
        c.edited("one")
        let first = Task { await c.flush() }
        try? await Task.sleep(for: .milliseconds(50))
        c.edited("two")
        await first.value
        await c.flush()
        XCTAssertEqual(api.calls.compactMap { $0.body?["content"] as? String }, ["one", "two"])
    }

    func testLeavingAnEmptiedOfflineNoteDropsItsQueuedEntry() async {
        let (c, api, _, queue, state) = makeControllerWithQueue(note: nil)
        api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
        c.edited("draft")
        await c.flush()
        let id = try! XCTUnwrap(c.noteId)
        api.errorFor = nil
        c.edited("")
        await c.leave()
        XCTAssertNil(queue.entry(for: id))
        XCTAssertNil(state.studyNotes[id])
        XCTAssertEqual(api.calls.count, 1)
    }

    func testAFailedDeleteIsQueuedSoItIsRetried() async {
        let (c, api, _, queue, _) = makeControllerWithQueue(note: .stub(id: "n1"))
        api.errorFor = { _, _ in APIHTTPError(status: 503, message: nil) }
        c.edited("")
        await c.leave()
        XCTAssertEqual(queue.entry(for: "n1"), .delete)
    }
}
