//
//  NoteEditorContainerTests.swift
//  MakeReadyCaptureTests
//
//  notes Task 14: the three D17 entry routes, the editor's back / background hand-off to the autosave
//  controller, and D16's system keyboard.
//

import SwiftUI
import XCTest
@testable import MakeReady

@MainActor
final class NoteEditorContainerTests: XCTestCase {

    private func makeEditor(
        noteId: String?, content: String = "", stubPatch: String? = nil, stubDelete: String? = nil
    ) -> (container: NoteEditorContainer, api: StubAPIClient) {
        let api = StubAPIClient()
        let state = AppState()
        var note: StudyNote?
        if let noteId {
            let stored = StudyNote.stub(id: noteId, content: content)
            state.studyNotes.upsert(stored)
            note = stored
        }
        if let stubPatch {
            api.stub("PATCH", "/api/notes/\(stubPatch)", json: """
                {"success":true,"stomped":false,"data":{"id":"\(stubPatch)","memberId":null,"userId":"u1","type":"NOTE","content":"x",\
                "title":null,"preview":null,"contextLabel":null,"isActive":true,"createdAt":"2026-11-20T10:00:00.123Z",\
                "updatedAt":"2026-11-20T10:05:00.456Z","links":[]}}
                """)
        }
        if let stubDelete { api.stub("DELETE", "/api/notes/\(stubDelete)", json: #"{"success":true,"message":"Note deleted"}"#) }
        let actions = NoteActions(api: api, state: state)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("notes-queue-\(UUID().uuidString).json")
        let queue = NoteSaveQueue(fileURL: url, actions: actions, state: state)
        let model = NoteEditorModel(noteId: noteId, note: note, actions: actions, queue: queue, state: state)
        return (NoteEditorContainer(model: model), api)
    }

    func testWriteANoteRowPushesAFreshNewNoteOnTheCurrentTab() {
        var model = UI2ShellModel(); model.tab = .search
        let binding = Binding(get: { model }, set: { model = $0 })
        NoteEntry.open(on: .search, model: binding)
        NoteEntry.open(on: .search, model: binding)
        guard case .newNote(let a) = model.path(for: .search)[0], case .newNote(let b) = model.path(for: .search)[1] else { return XCTFail("not newNote") }
        XCTAssertNotEqual(a, b)
        XCTAssertTrue(UI2Destination.newNote(flowId: a).isFullScreen)
        XCTAssertTrue(UI2Destination.noteEditor(noteId: "n1").isFullScreen)
        XCTAssertTrue(UI2Shell.addMenuActions.contains { $0.label == NoteEntry.rowLabel })
    }

    func testBackLeavesThroughTheControllerSoAnEmptiedNoteIsDeleted() async {
        let (container, api) = makeEditor(noteId: "n1", content: "# Old\nx", stubDelete: "n1")
        container.model.setText(AttributedString(""))
        await container.model.back()
        XCTAssertEqual(api.calls.last?.method, "DELETE")
    }

    func testBackPopsAfterTheLeave() async {
        let (container, _) = makeEditor(noteId: "n1", content: "# Old", stubPatch: "n1")
        var popped = 0
        container.model.onPop = { popped += 1 }
        await container.model.back()
        XCTAssertEqual(popped, 1)
    }

    func testBackgroundFlushesThePendingEdit() async {
        let (container, api) = makeEditor(noteId: "n1", content: "# Old", stubPatch: "n1")
        container.model.setText(NoteDocumentCodec.parse("# New"))
        await container.model.scenePhaseChanged(.background)
        XCTAssertEqual(api.calls.last?.body?["content"] as? String, "# New")
    }

    func testANewNoteOpensEditingAtTheStartWithNoRequest() {
        let (container, api) = makeEditor(noteId: nil)
        XCTAssertTrue(container.model.opensEditing)
        XCTAssertEqual(container.model.initialSelection, NSRange(location: 0, length: 0))
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testAStoredNoteOpensParsedAndNotEditing() {
        let (container, _) = makeEditor(noteId: "n1", content: "# Old\nx")
        XCTAssertFalse(container.model.opensEditing)
        XCTAssertEqual(container.model.initialText, NoteDocumentCodec.parse("# Old\nx"))
    }

    func testTheEditorKeepsTheSystemKeyboard() throws {
        let textView = try XCTUnwrap(hostAndFindTextView(makeEditor(noteId: nil).container))
        XCTAssertNil(textView.inputView)
        XCTAssertEqual(textView.keyboardType, .default)
    }

    private func hostAndFindTextView<V: View>(_ view: V) -> UITextView? {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        host.view.layoutIfNeeded()
        return Self.firstTextView(in: host.view)
    }

    private static func firstTextView(in view: UIView) -> UITextView? {
        if let textView = view as? UITextView { return textView }
        for sub in view.subviews { if let found = firstTextView(in: sub) { return found } }
        return nil
    }
}
