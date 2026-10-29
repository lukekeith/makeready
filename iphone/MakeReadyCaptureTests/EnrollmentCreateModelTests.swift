import XCTest
@testable import MakeReady

/// ui2-enrollment-create T6: the new wire fields decode tolerantly and survive the disk cache.
final class EnrollmentCreateModelTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(T.self, from: Data(json.utf8))
    }

    func testEnrollmentWithProgramDecodesLessonAccessAndSyncMode() throws {
        let e = try decode(EnrollmentWithProgram.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-20T06:00:00.000Z","lessonAccess":"ONE_AT_A_TIME","syncMode":"OFF"}"#)
        XCTAssertEqual(e.lessonAccess, "ONE_AT_A_TIME")
        XCTAssertEqual(e.syncMode, "OFF")
        let round = try JSONDecoder.apiDecoder.decode(EnrollmentWithProgram.self, from: JSONEncoder.apiEncoder.encode(e))
        XCTAssertEqual(round.lessonAccess, "ONE_AT_A_TIME")
        XCTAssertEqual(round.syncMode, "OFF")
    }

    func testEnrollmentWithProgramWithoutTheKeysDecodesNil() throws {
        let e = try decode(EnrollmentWithProgram.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z"}"#)
        XCTAssertNil(e.lessonAccess)
        XCTAssertNil(e.syncMode)
    }

    func testStudyProgramDecodesCompletedEnrollmentCount() throws {
        let p = try decode(StudyProgram.self,
            #"{"id":"p1","name":"Romans","days":12,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","completedEnrollmentCount":3}"#)
        XCTAssertEqual(p.completedEnrollmentCount, 3)
        let round = try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: JSONEncoder.apiEncoder.encode(p))
        XCTAssertEqual(round.completedEnrollmentCount, 3)
        let old = try decode(StudyProgram.self,
            #"{"id":"p1","name":"Romans","days":12,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z"}"#)
        XCTAssertNil(old.completedEnrollmentCount)
    }

    func testCreateResponseEnrollmentDecodesTheNewFields() throws {
        let e = try decode(Enrollment.self,
            #"{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-20T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}"#)
        XCTAssertEqual(e.lessonAccess, "ALL_AT_ONCE")
        XCTAssertEqual(e.syncMode, "AUTO")
    }
}
