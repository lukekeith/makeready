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
        XCTAssertEqual(StudyProgramHomeContainer.imageURLs(s), ["https://c", "https://s", "https://g"])
    }
}
