import XCTest
@testable import MakeReady

/// ui2-programs D5/D6/D7: the program page from AppState.
@MainActor
final class StudyProgramHomeMapperTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let created = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!

    private func input(_ program: StudyProgram?, lessons: [Lesson] = [], enrollments: [ProgramEnrollment] = [],
                       failed: Bool = false, activeDay: Int = 1) -> StudyProgramHomeMapper.Input {
        .init(name: "Pushed", program: program, lessons: lessons, enrollments: enrollments, failed: failed, activeDay: activeDay)
    }

    private func state(_ input: StudyProgramHomeMapper.Input) -> StudyProgramHomeScreen.State {
        StudyProgramHomeMapper.state(input, timeZone: utc)
    }

    private func program(min: Int? = nil, max: Int? = nil, maxMembers: Int? = nil, access: String? = nil,
                         isPrivate: Bool? = nil, leader: String? = nil) -> StudyProgram {
        StudyProgram(id: "p1", name: "Walk", description: "Daily", coverImageUrl: "https://img/c.jpg", createdAt: created,
                     creatorName: "Luke Keith", leaderName: leader, isPrivate: isPrivate, ageRangeMin: min, ageRangeMax: max,
                     maxMembers: maxMembers, memberDirectoryAccess: access)
    }

    /// D6: the details grid and the settings values.
    func testDetailsAndSettings() {
        let s = state(input(program(min: 18, max: 35, maxMembers: 40, access: "NAMES_ONLY", isPrivate: true, leader: "Nathan Lee")))
        XCTAssertEqual(s.createdLabel, "Mar 5, 2026")
        XCTAssertEqual(s.authorName, "Luke Keith")
        XCTAssertEqual(s.leaderName, "Nathan Lee")
        XCTAssertEqual(s.programName, "Walk")
        XCTAssertEqual(s.programDescription, "Daily")
        XCTAssertEqual(s.visibility, "Private")
        XCTAssertEqual(s.ageRange, "18 - 35")
        XCTAssertEqual(s.maximumMembers, "40")
        XCTAssertEqual(s.memberDirectoryAccess, "Names only")
        XCTAssertEqual(s.coverURL, "https://img/c.jpg")
    }

    /// D6: Group's age forms, Unlimited, Public, Allowed, and the leader falling back to the author.
    func testDefaultsAndFallbacks() {
        XCTAssertEqual(state(input(program())).ageRange, "Any age")
        XCTAssertEqual(state(input(program(min: 18))).ageRange, "18+")
        XCTAssertEqual(state(input(program(max: 12))).ageRange, "Up to 12")
        let s = state(input(program()))
        XCTAssertEqual(s.maximumMembers, "Unlimited")
        XCTAssertEqual(s.visibility, "Public")
        XCTAssertEqual(s.memberDirectoryAccess, "Allowed")
        XCTAssertEqual(s.leaderName, "Luke Keith")
    }

    private func summary(_ id: String, position: Int, kind: String = "text", title: String, document: String) -> ActivitySummary {
        let json = #"{"id":"\#(id)","activityKey":"k-\#(id)","position":\#(position),"kind":"\#(kind)","title":"\#(title)","document":\#(document)}"#
        return try! JSONDecoder.apiDecoder.decode(ActivitySummary.self, from: Data(json.utf8))
    }

    /// D6: one card per lesson by position; "N mins" from `ceil(seconds / 60)` (D11); slides in
    /// position order; a canvas kind's image is its rendered page (D26), a YouTube clip's its thumbnail.
    func testLessons() {
        let withImage = summary("a2", position: 1, title: "Read: Romans 1",
            document: ##"{"schemaVersion":1,"kind":"text","background":{"color":"#000000","image":{"mediaId":"m1"}},"content":{"type":"canvas","objects":[]}}"##)
        let clip = summary("a1", position: 0, kind: "youtube", title: "Clip",
            document: #"{"schemaVersion":1,"kind":"youtube","content":{"youtubeVideoId":"abc"}}"#)
        let plain = summary("a3", position: 2, title: "Plain",
            document: #"{"schemaVersion":1,"kind":"text","content":{"type":"canvas","objects":[]}}"#)
        let lessons = [Lesson(id: "l2", position: 2, title: "Second"),
                       Lesson(id: "l1", position: 1, title: "First", estimatedSeconds: 661, activities: [withImage, plain, clip])]
        let media = ["m1": MediaMapEntry(url: "https://cdn/m1.jpg", width: nil, height: nil, kind: "image", playbackUrl: nil,
                                         posterUrl: nil, durationSeconds: nil, uploaderName: nil)]
        var i = input(program(), lessons: lessons)
        i.media = media
        let s = state(i)
        XCTAssertEqual(s.dayCount, 2)
        XCTAssertEqual(s.lessonCount, 2)
        XCTAssertEqual(s.lessonNumbers, [1, 2])
        XCTAssertEqual(s.lessonTitles, ["First", "Second"])
        XCTAssertEqual(s.lessonDurations, ["12 mins", "0 mins"])
        XCTAssertEqual(s.lessonSlideImages, [["https://img.youtube.com/vi/abc/hqdefault.jpg",
                                              ActivityThumbnail.key(for: withImage), ActivityThumbnail.key(for: plain)], []])
        XCTAssertTrue(s.lessonSlideImages[0][1].hasPrefix("activity-thumbnail://"))
        XCTAssertEqual(s.lessonSlideLabels, [["Clip", "Read: Romans 1", "Plain"], []])
    }

    /// The estimate shows in whole minutes, rounded up.
    func testMinutesRoundUp() {
        XCTAssertNil(StudyProgramHomeMapper.minutes(fromSeconds: nil))
        XCTAssertNil(StudyProgramHomeMapper.minutes(fromSeconds: 0))
        XCTAssertEqual(StudyProgramHomeMapper.minutes(fromSeconds: 1), 1)
        XCTAssertEqual(StudyProgramHomeMapper.minutes(fromSeconds: 60), 1)
        XCTAssertEqual(StudyProgramHomeMapper.minutes(fromSeconds: 61), 2)
    }

    /// D6/D16: every enrollment as returned — name, photo, the leader's short name, member count.
    func testEnrollments() throws {
        let json = #"[{"id":"e1","groupId":"g1","studyProgramId":"p1","startDate":"2026-10-01T00:00:00Z","endDate":"2026-11-01T00:00:00Z","group":{"id":"g1","name":"Young professionals","coverImageUrl":"https://img/g.jpg","_count":{"members":27},"creator":{"name":"Luke Keith"}}}]"#
        let enrollments = try JSONDecoder.apiDecoder.decode([ProgramEnrollment].self, from: Data(json.utf8))
        let s = state(input(program(), enrollments: enrollments))
        XCTAssertEqual(s.enrollmentNames, ["Young professionals"])
        XCTAssertEqual(s.enrollmentPhotoURLs, ["https://img/g.jpg"])
        XCTAssertEqual(s.enrollmentLeaders, ["L. Keith"])
        XCTAssertEqual(s.enrollmentMemberCounts, [27])
    }

    /// D5: nothing cached = loading under the pushed name; a failure with nothing cached = failed;
    /// a cache keeps the page whatever the load did.
    func testLoadingAndFailed() {
        let loading = state(input(nil))
        XCTAssertTrue(loading.loading)
        XCTAssertFalse(loading.failed)
        XCTAssertEqual(loading.programName, "Pushed")
        let failed = state(input(nil, failed: true))
        XCTAssertTrue(failed.failed)
        XCTAssertFalse(failed.loading)
        let cached = state(input(program(), failed: true))
        XCTAssertFalse(cached.failed)
        XCTAssertFalse(cached.loading)
    }

    /// D11: the row's meta wording.
    func testLessonDurationWording() {
        XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(nil), "0 mins")
        XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(0), "0 mins")
        XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(1), "1 min")
        XCTAssertEqual(StudyProgramHomeMapper.lessonDuration(3), "3 mins")
    }

    /// D7: the selected chip passes through while it is within the lessons.
    func testActiveDayPassesThrough() {
        let lessons = (1...3).map { Lesson(id: "l\($0)", position: $0, title: "") }
        XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 3)).activeDay, 3)
    }

    /// D14: past the last lesson selects the new last chip; no lessons selects 1.
    func testActiveDayClampsToTheLessons() {
        let lessons = [Lesson(id: "l1", position: 1, title: "A"), Lesson(id: "l2", position: 2, title: "B")]
        XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 3)).activeDay, 2)
        XCTAssertEqual(state(input(program(), lessons: lessons, activeDay: 2)).activeDay, 2)
        XCTAssertEqual(state(input(program(), activeDay: 3)).activeDay, 1)
    }
}
