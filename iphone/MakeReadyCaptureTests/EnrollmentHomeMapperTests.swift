import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D20 + §Contract Home → `EnrollmentHomeScreen.State`.
final class EnrollmentHomeMapperTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2035-01-09T18:00:00Z")!     // Tue Jan 9, 12:00 local

    private func home() throws -> EnrollmentHome {
        try JSONDecoder.apiDecoder.decode(EnrollmentHome.self, from: Data(#"""
        {"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":"Paul's letter","coverImageUrl":"https://x/p1.png","authorName":"Jonathan Edwards"},
         "group":{"id":"g1","name":"Young Professionals","leader":{"id":"u1","name":"Tony Stark"}},
         "memberCount":17,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-03-10",
         "lessonAccess":"ALL_AT_ONCE","smsTime":"07:30","timezone":"America/Chicago",
         "days":[{"scheduleId":"s1","date":"2035-01-08","percent":78,"lessonCount":1,"plannedMinutes":15},
                 {"scheduleId":"s2","date":"2035-01-09","percent":65.4,"lessonCount":2,"plannedMinutes":30}],
         "lessons":[{"scheduleId":"s1","dayNumber":1,"title":"It is evident","date":"2035-01-08","progress":1,"activities":[]},
                    {"scheduleId":"s2","dayNumber":2,"title":"In the beginning","date":"2035-01-09","progress":0.69,
                     "activities":[{"id":"a1","type":"READ","title":"Romans 1","thumbnailUrl":"https://x/a1.png"},
                                   {"id":"a2","type":"VIDEO","title":null,"thumbnailUrl":null}]},
                    {"scheduleId":"s3","dayNumber":3,"title":null,"date":"2035-01-10","progress":0,"activities":[]},
                    {"scheduleId":"s4","dayNumber":4,"title":"Later","date":"2035-01-22","progress":null,"activities":[]}]}
        """#.utf8))
    }

    private func state(_ home: EnrollmentHome?, loading: Bool = false, failed: Bool = false) -> EnrollmentHomeScreen.State {
        EnrollmentHomeMapper.state(.init(name: "Pushed", home: home, loading: loading, failed: failed), today: today, timeZone: zone)
    }

    func testIdentityAndDetails() throws {
        let s = state(try home())
        XCTAssertEqual(s.coverURL, "https://x/p1.png")
        XCTAssertEqual(s.programName, "Romans")
        XCTAssertEqual(s.programDescription, "Paul's letter")
        XCTAssertEqual(s.memberCount, 17)
        XCTAssertEqual(s.authorName, "Jonathan Edwards")
        XCTAssertEqual(s.enrolledLabel, "Jan 1, 2035")
        XCTAssertEqual(s.leaderName, "Tony Stark")                               // D13
    }

    func testScheduleCardsAndSpan() throws {
        let s = state(try home())
        XCTAssertEqual([s.startMonth, s.startWeekday, s.startDay], ["Jan", "Mon", "8"])
        XCTAssertEqual([s.endMonth, s.endWeekday, s.endDay], ["Mar", "Sat", "10"])
        XCTAssertEqual(s.spanMonths, 2)
        XCTAssertEqual(s.spanDays, 2)
    }

    func testDayRail() throws {
        let s = state(try home())
        XCTAssertEqual(s.dayMonths, ["JAN", "JAN"])
        XCTAssertEqual(s.dayWeekdays, ["MON", "TUE"])
        XCTAssertEqual(s.dayNumbers, ["8", "9"])
        XCTAssertEqual(s.dayDateStates, ["default", "today"])                    // vs the device's today
        XCTAssertEqual(s.dayPercents, [78, 65])
        XCTAssertEqual(s.dayLine1s, ["1", "2"])                                  // lessons that day
        XCTAssertEqual(s.dayLine2s, ["7:30am", "7:30am"])                        // the invite time
        XCTAssertEqual(s.dayDetailsStates, ["lessonDay", "lessonDay"])
    }

    func testLessons() throws {
        let s = state(try home())
        XCTAssertEqual(s.lessonNumbers, [1, 2, 3, 4])
        XCTAssertEqual(s.lessonTitles, ["It is evident", "In the beginning", "Day 3", "Later"])
        XCTAssertEqual(s.lessonMetaLabels, ["Jan 8", "Today", "Tomorrow", "Jan 22"])
        XCTAssertEqual(s.lessonProgress, [nil, 0.69, nil, nil])                 // §2.5: today's card only
        XCTAssertEqual(s.lessonSlideImages, [[], ["https://x/a1.png", ""], [], []])
        XCTAssertEqual(s.lessonSlideLabels, [[], ["Read: Romans 1", "Video"], [], []])
    }

    func testInviteTimeFormat() {                                                // T8
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("07:30"), "7:30am")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("19:05"), "7:05pm")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("00:00"), "12:00am")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime(nil), "")
    }

    func testNoScheduleRendersTheStartCardOnly() throws {                      // OQ-enrollment-home-8
        let json = Data(#"{"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":null,"coverImageUrl":null,"authorName":null},"group":{"id":"g1","name":"YP","leader":null},"memberCount":0,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-01-08","lessonAccess":null,"smsTime":null,"timezone":null,"days":[],"lessons":[]}"#.utf8)
        let s = state(try JSONDecoder.apiDecoder.decode(EnrollmentHome.self, from: json))
        XCTAssertEqual(s.startDay, "8")
        XCTAssertEqual([s.endMonth, s.endWeekday, s.endDay], ["", "", ""])
        XCTAssertEqual([s.spanMonths, s.spanDays], [0, 0])
        XCTAssertEqual(s.dayNumbers, []); XCTAssertEqual(s.lessonTitles, [])
        XCTAssertEqual(s.leaderName, ""); XCTAssertEqual(s.authorName, "")
    }

    func testLoadingKeepsThePushedNameAndFailedShowsOnlyWithNothingCached() throws {
        let loading = state(nil, loading: true)
        XCTAssertEqual(loading.programName, "Pushed")
        XCTAssertTrue(loading.loading)
        XCTAssertTrue(state(nil, failed: true).failed)
        XCTAssertFalse(state(try home(), failed: true).failed)                   // a cached page stays
    }
}
