import XCTest
@testable import MakeReady

/// memo-screens D6, D14, D17, R1: the + menu's Voice memo entry and the saved toast's presenter.
@MainActor
final class MemoEntryTests: XCTestCase {
    /// D14: one recording at a time.
    func testVoiceMemoIsIgnoredWhileTheRecorderIsUp() {
        XCTAssertTrue(MemoEntry.shouldStart(recorderPresented: false))
        XCTAssertFalse(MemoEntry.shouldStart(recorderPresented: true))
    }

    /// D6, D17: the toast's View opens the queued memo by its local id.
    func testViewOpensTheMemoByItsLocalId() {
        XCTAssertEqual(MemoEntry.viewDestination(localId: "q1"), .memoDetail(memoId: "local:q1"))
    }

    /// D6: the toast hides after 4 s, and a newer toast is not hidden by an older timer.
    func testToastExpiresOnlyItself() async {
        let toast = SavedToastPresenter()
        toast.show(localId: "a"); let first = toast.current!.id
        toast.show(localId: "b")
        await toast.expire(id: first, sleep: { _ in })
        XCTAssertEqual(toast.current?.localId, "b")
        await toast.expire(id: toast.current!.id, sleep: { XCTAssertEqual($0, .seconds(4)) })
        XCTAssertNil(toast.current)
    }

    /// R1: the add menu still lists Voice memo.
    func testTheAddMenuStillListsVoiceMemo() {
        XCTAssertTrue(UI2Shell.addMenuActions.contains { $0.label == MemoEntry.rowLabel })
    }
}
