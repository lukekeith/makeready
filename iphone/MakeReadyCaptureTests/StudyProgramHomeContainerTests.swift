import SwiftUI
import UIKit
import XCTest
@testable import MakeReady

/// ui2-programs D5/D7/D10: the program page's pure decisions.
@MainActor
final class StudyProgramHomeContainerTests: XCTestCase {
    func testLoadFailureClassification() {
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIHTTPError(status: 404, message: nil)), .gone)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: CancellationError()), .cancelled)
        XCTAssertEqual(StudyProgramHomeContainer.loadFailure(for: APIHTTPError(status: 500, message: nil)), .failed)
    }

    /// program-lesson-add-activity D10/D17: the picker's strip — activities by order, then the placeholder, active.
    func testActivityNewStripListsActivitiesThenThePlaceholder() {
        let lesson = Lesson(id: "l1", dayNumber: 1, title: "A",
                            activities: [StudyActivity(id: "a2", type: .read, orderNumber: 2, title: "Second"),
                                         StudyActivity(id: "a1", type: .video, orderNumber: 1, title: "First")])
        let s = ActivityNewMapper.state(lesson: lesson)
        XCTAssertEqual(s.slideIDs, ["a1", "a2", "placeholder"])
        XCTAssertEqual(s.slideLabels, ["First", "Second", "New activity"])
        XCTAssertEqual(s.activeID, "placeholder")
        XCTAssertEqual(s.pendingType, "")
        XCTAssertFalse(s.createFailed)
    }

    /// D17: a lesson missing from AppState shows the placeholder alone.
    func testActivityNewWithoutTheLessonShowsThePlaceholderAlone() {
        let s = ActivityNewMapper.state(lesson: nil)
        XCTAssertEqual(s.slideIDs, ["placeholder"])
        XCTAssertEqual(s.slideLabels, ["New activity"])
    }

    func testSettingsRowsOpenTheirEditPageOnceLoaded() {
        let program = StudyProgram(id: "p1", name: "Walk")
        XCTAssertEqual(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Age", program: program),
                       .editProgramField(programId: "p1", field: .ageRange))
        XCTAssertNil(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Lessons", program: program))
        XCTAssertNil(StudyProgramHomeContainer.editDestination(programId: "p1", label: "Age", program: nil))
    }

    func testImageURLsSkipEmpties() {
        var s = StudyProgramHomeMapper.state(.init(name: "", program: nil, lessons: [], enrollments: [], failed: false, activeDay: 1),
                                             timeZone: .current)
        s.coverURL = "https://c"
        s.lessonSlideImages = [["https://s", ""]]
        s.enrollmentPhotoURLs = ["", "https://g"]
        XCTAssertEqual(StudyProgramHomeContainer.imageURLs(s), ["https://c", "https://s"])   // rows load list copies
    }

    /// D12: the closures d2m delivered are the names the container calls.
    func testProgramPageTakesBothLessonClosures() {
        let state = StudyProgramHomeMapper.state(.init(name: "", program: nil, lessons: [], enrollments: [], failed: false, activeDay: 1),
                                                 timeZone: .current)
        _ = StudyProgramHomeScreen(state: state, onAddActivity: { _ in }, onOpenLessonMenu: { _ in })
    }

    /// D13/F5: the 775pt minimum is gone, so the picker fits a proposed 700pt.
    func testActivityNewFitsAPhone() {
        let host = UIHostingController(rootView: ActivityNewScreen(state: .populated))
        XCTAssertLessThanOrEqual(host.sizeThatFits(in: CGSize(width: 390, height: 700)).height, 700)
    }
}
