import XCTest
@testable import MakeReady

/// text-activity §Contract enrollment rows: the sync apply result and the `lessonSchedules[]` rows.
final class EnrollmentSyncDecodingTests: XCTestCase {
    func testSyncApplyDecodesSkippedLessons() throws {
        let r = try JSONDecoder.apiDecoder.decode(EnrollmentSyncResult.self, from: Data(#"{"syncedProgramVersionNumber":2,"currentVersionNumber":2,"skippedCustomizedLessonIds":["l2"]}"#.utf8))
        XCTAssertEqual(r.skippedCustomizedLessonIds, ["l2"])
        XCTAssertEqual(r.syncedProgramVersionNumber, 2)
        XCTAssertEqual(r.currentVersionNumber, 2)
    }

    func testSkippedLessonsDefaultToEmpty() throws {
        let r = try JSONDecoder.apiDecoder.decode(EnrollmentSyncResult.self, from: Data(#"{"success":true,"alreadySynced":true}"#.utf8))
        XCTAssertEqual(r.skippedCustomizedLessonIds, [])
    }

    func testScheduledLessonDecodesTodaysKeysAndKinds() throws {
        let json = #"""
        {"id":"s1","code":"c1","enrollmentId":"e1","lessonId":"l1","scheduledDate":"2035-01-08T00:00:00Z","smsSentAt":null,
         "title":"Day one","estimatedMinutes":5,"currentVersionId":"v3","removedAt":null,
         "scheduledActivities":[{"id":"a1","activityKey":"k1","position":0,"kind":"text","title":"Text",
           "document":{"schemaVersion":1,"kind":"text"}}],
         "lesson":{"id":"l1","dayNumber":3,"title":"Day one","studyProgramId":"p1",
           "activities":[{"id":"a1","activityKey":"k1","position":0,"kind":"text","title":"Text","document":{"schemaVersion":1,"kind":"text"}}]}}
        """#
        let s = try JSONDecoder.apiDecoder.decode(ScheduledLesson.self, from: Data(json.utf8))
        XCTAssertEqual(s.id, "s1")
        XCTAssertEqual(s.lessonId, "l1")
        XCTAssertEqual(s.dayNumber, 3)
        XCTAssertEqual(s.currentVersionId, "v3")
        XCTAssertEqual(s.activities.map(\.kind), ["text"])
    }

    func testScheduledLessonSurvivesTheDiskRoundTrip() throws {
        let json = #"{"id":"s1","enrollmentId":"e1","lessonId":"l1","scheduledDate":"2035-01-08T00:00:00Z","currentVersionId":"v3","scheduledActivities":[],"lesson":{"id":"l1","dayNumber":4}}"#
        let decoded = try JSONDecoder.apiDecoder.decode(ScheduledLesson.self, from: Data(json.utf8))
        let again = try JSONDecoder.apiDecoder.decode(ScheduledLesson.self, from: JSONEncoder.apiEncoder.encode(decoded))
        XCTAssertEqual(again, decoded)
        XCTAssertEqual(again.dayNumber, 4)
    }
}
