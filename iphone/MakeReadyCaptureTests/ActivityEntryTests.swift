import XCTest
@testable import MakeReady

/// text-activity Task 24 (D14, D39): the one rule for "open this activity", and the two new destinations.
@MainActor
final class ActivityEntryTests: XCTestCase {
    func testCanvasKindsOpenTheEditorOthersCannotEdit() {
        XCTAssertEqual(ActivityEntry.destination(for: "bible", activityId: "a"), .open(.activitiesEditor(activityId: "a")))
        XCTAssertEqual(ActivityEntry.destination(for: "video", activityId: "a"), .cannotEdit(message: "This activity can't be edited yet."))
    }

    func testTextOpensTheEditorAndEveryOtherKindCannotEdit() {
        XCTAssertEqual(ActivityEntry.canvasKinds, ["text", "bible"])
        XCTAssertEqual(ActivityEntry.destination(for: "text", activityId: "t"), .open(.activitiesEditor(activityId: "t")))
        for kind in ["youtube", "write", "poll", "someFutureKind"] {
            XCTAssertEqual(ActivityEntry.destination(for: kind, activityId: "a"), .cannotEdit(message: ActivityEntry.cannotEditMessage), kind)
        }
    }

    func testViewerIsFullScreen() {
        XCTAssertTrue(UI2Destination.activityViewer(lessonVersionId: "v", activityId: "a").isFullScreen)
        XCTAssertFalse(UI2Destination.activitiesEditor(activityId: "a").isFullScreen)
    }

    /// D39: a tap that cannot edit pushes nothing and reports the message through the banner channel.
    func testOpenPushesTheEditorOrSurfacesTheMessage() {
        var pushed: [UI2Destination] = []
        var reported: [String] = []
        ActivityEntry.open(kind: "text", activityId: "a", push: { pushed.append($0) }, report: { reported.append($0) })
        ActivityEntry.open(kind: "video", activityId: "b", push: { pushed.append($0) }, report: { reported.append($0) })
        XCTAssertEqual(pushed, [.activitiesEditor(activityId: "a")])
        XCTAssertEqual(reported, ["This activity can't be edited yet."])
    }
}
