//
//  ModelDecodingTests.swift
//  MakeReadyCaptureTests
//
//  CHARACTERIZATION decoding-fixture tests for the highest-traffic models.
//  Fixtures mirror API JSON; decoding uses JSONDecoder.apiDecoder (.iso8601
//  dates, default key strategy) — the exact configuration APIClient uses.
//

import XCTest
@testable import MakeReady

final class ModelDecodingTests: XCTestCase {

    private func decodeModel<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(T.self, from: Data(json.utf8))
    }

    private let isoDate = "2025-01-15T10:30:00Z"
    private var expectedDate: Date { ISO8601DateFormatter().date(from: "2025-01-15T10:30:00Z")! }

    // MARK: - StudyProgram

    func testStudyProgramDecodesNewAPIFormat() throws {
        let program: StudyProgram = try decodeModel("""
        {"id":"p1","title":"Genesis Study","description":"Walk through Genesis",
         "lessonCount":30,"isPublished":true,"coverImageUrl":"https://cdn.example.com/c.jpg",
         "template":{"id":"tpl-1","name":"SOAP"},"tags":["ot"],
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(program.name, "Genesis Study")        // "title" wins over "name"
        XCTAssertEqual(program.days, 30)                      // derived from lessonCount
        XCTAssertEqual(program._count?.lessons, 30)           // QUIRK: _count synthesized from lessonCount
        XCTAssertEqual(program.templateId, "tpl-1")           // from nested template object
        XCTAssertEqual(program.templateName, "SOAP")
        XCTAssertEqual(program.isPublished, true)
        XCTAssertEqual(program.tags, ["ot"])
        XCTAssertEqual(program.createdAt, expectedDate)
    }

    func testStudyProgramDecodesLegacyCachedFormat() throws {
        let program: StudyProgram = try decodeModel("""
        {"id":"p2","name":"Legacy Program","days":7,"isActive":true,"creatorId":"u1",
         "_count":{"lessons":7,"enrollments":3},
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(program.name, "Legacy Program")
        XCTAssertEqual(program.days, 7)
        XCTAssertEqual(program._count?.enrollments, 3)
        XCTAssertEqual(program.isActive, true)
        XCTAssertNil(program.isPublished)
    }

    func testStudyProgramOptionalFieldAbsenceAndEqualityQuirk() throws {
        let program: StudyProgram = try decodeModel("""
        {"id":"p3","title":"Minimal","createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(program.days, 0)            // QUIRK: missing days/lessonCount → 0
        XCTAssertNil(program.description)
        XCTAssertNil(program._count)
        XCTAssertNil(program.tags)
        XCTAssertNil(program.lessons)

        // QUIRK: == compares a subset of fields; differing creatorId is still "equal".
        var copy = program
        copy.creatorId = "someone-else"
        XCTAssertEqual(program, copy)
    }

    // MARK: - UserGroup

    func testUserGroupDecodesFullPayload() throws {
        let group: UserGroup = try decodeModel("""
        {"id":"g1","code":"ABC123","name":"Young Pros","description":"Weeknights",
         "isPrivate":false,"allowInvites":true,"memberDirectory":false,
         "ageRange":{"min":18,"max":30},"maxMembers":50,"memberCount":27,
         "creatorId":"u1","createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(group.code, "ABC123")
        XCTAssertEqual(group.memberDirectory, false)
        XCTAssertEqual(group.ageRange, AgeRange(min: 18, max: 30))
        XCTAssertEqual(group.maxMembers, 50)
        XCTAssertEqual(group.memberCount, 27)
    }

    func testUserGroupOptionalFieldAbsence() throws {
        let group: UserGroup = try decodeModel("""
        {"id":"g2","code":"XYZ789","name":"Min Group","isPrivate":true,"allowInvites":false,
         "memberCount":1,"creatorId":"u1","createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(group.memberDirectory, true)  // QUIRK: missing memberDirectory → true
        XCTAssertNil(group.description)
        XCTAssertNil(group.ageRange)
        XCTAssertNil(group.maxMembers)
    }

    // MARK: - Lesson

    func testLessonDecodesNewAPIFormat() throws {
        let lesson: Lesson = try decodeModel("""
        {"id":"l1","programId":"p1","orderIndex":3,"title":"Day 3","description":"Overview",
         "estimatedMinutes":12,
         "activities":[{"id":"a1","activityType":"READ","orderNumber":1}],
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(lesson.studyProgramId, "p1")          // "programId" wins
        XCTAssertEqual(lesson.dayNumber, 3)                  // "orderIndex" wins
        XCTAssertEqual(lesson.lessonDescription, "Overview") // JSON key "description"
        XCTAssertEqual(lesson.estimatedMinutes, 12)
        XCTAssertEqual(lesson.activities.count, 1)
        XCTAssertEqual(lesson.activities.first?.type, .read)
    }

    func testLessonOptionalFieldAbsence() throws {
        let lesson: Lesson = try decodeModel("""
        {"id":"l2","createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(lesson.dayNumber, 1)         // QUIRK: missing orderIndex/dayNumber → 1
        XCTAssertTrue(lesson.activities.isEmpty)    // missing activities → []
        XCTAssertNil(lesson.studyProgramId)
        XCTAssertNil(lesson.title)
    }

    // MARK: - StudyActivity

    func testStudyActivityDecodesNewAPIFormat() throws {
        let activity: StudyActivity = try decodeModel("""
        {"id":"a1","activityType":"READ","title":"Scripture","isHelpEnabled":true,
         "helpTitle":"How to read","readContent":"# Read this","orderNumber":2,
         "estimatedSeconds":90,
         "readBlocks":[{"id":"rb1","content":"In the beginning"}]}
        """)
        XCTAssertEqual(activity.type, .read)             // "activityType" preferred
        XCTAssertEqual(activity.status, .pending)        // QUIRK: missing status → .pending
        XCTAssertEqual(activity.orderNumber, 2)
        XCTAssertEqual(activity.readContent, "# Read this")
        XCTAssertEqual(activity.readBlocks?.first?.orderNumber, 1)   // block default
        XCTAssertEqual(activity.readBlocks?.first?.isLocked, false)  // block default
        XCTAssertNil(activity.createdAt)
    }

    func testStudyActivityDecodesLegacyFormatWithDefaults() throws {
        let activity: StudyActivity = try decodeModel("""
        {"id":"a2","lessonId":"l1","type":"SOAP","status":"COMPLETE",
         "passageReference":"Romans 1:1-5"}
        """)
        XCTAssertEqual(activity.type, .soap)             // legacy "type" fallback
        XCTAssertEqual(activity.status, .complete)
        XCTAssertEqual(activity.orderNumber, 1)          // QUIRK: missing orderNumber → 1
        XCTAssertEqual(activity.passageReference, "Romans 1:1-5")
        XCTAssertNil(activity.title)
        XCTAssertNil(activity.readBlocks)
    }

    // MARK: - EnrollmentWithProgram

    func testEnrollmentDecodesNewAPIFormat() throws {
        let enrollment: EnrollmentWithProgram = try decodeModel("""
        {"id":"e1","groupId":"g1","programId":"p1","startedAt":"\(isoDate)","isActive":true,
         "studyProgram":{"id":"p1","title":"Genesis Study","lessonCount":30}}
        """)
        XCTAssertEqual(enrollment.studyProgramId, "p1")        // "programId" wins
        XCTAssertEqual(enrollment.startDate, expectedDate)     // from "startedAt"
        // QUIRK: no completedAt/endDate → endDate defaults to .distantFuture.
        XCTAssertEqual(enrollment.endDate, Date.distantFuture)
        XCTAssertTrue(enrollment.isActive)
        XCTAssertEqual(enrollment.studyProgram?.name, "Genesis Study")  // summary "title" wins
        XCTAssertEqual(enrollment.studyProgram?.days, 30)               // from lessonCount
    }

    func testEnrollmentDecodesLegacyFormatAndComputesIsActive() throws {
        let enrollment: EnrollmentWithProgram = try decodeModel("""
        {"id":"e2","groupId":"g1","studyProgramId":"p2",
         "startDate":"2025-01-01T00:00:00Z","endDate":"2025-02-01T00:00:00Z",
         "studyProgram":{"id":"p2","name":"Legacy Prog","days":7}}
        """)
        XCTAssertEqual(enrollment.studyProgramId, "p2")
        XCTAssertEqual(enrollment.endDate, ISO8601DateFormatter().date(from: "2025-02-01T00:00:00Z"))
        // QUIRK: with no explicit isActive, it is computed as endDate > now.
        XCTAssertFalse(enrollment.isActive)
        XCTAssertNil(enrollment.enabledDays)
        XCTAssertNil(enrollment.currentLessonId)
    }

    // MARK: - MediaLibraryItem

    func testMediaLibraryItemDecodesAndOmitsOptionals() throws {
        let item: MediaLibraryItem = try decodeModel("""
        {"id":"m1","title":"Intro Video","url":"https://cdn.example.com/m1.mp4",
         "type":"video","uploadStatus":"ready","duration":90,"tags":["intro"],
         "usageCount":2,"uploader":{"id":"u1","name":"Luke"},
         "video":{"id":"v9","playbackUrl":"https://stream/v9","duration":90,"status":"ready"},
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(item.mediaType, .video)
        XCTAssertTrue(item.isReady)
        XCTAssertEqual(item.formattedDuration, "1:30")
        XCTAssertEqual(item.uploader?.name, "Luke")
        // Optional fields absent → nil (synthesized Codable, no custom defaults):
        XCTAssertNil(item.description)
        XCTAssertNil(item.mimeType)
        XCTAssertNil(item.thumbnailUrl)

        // QUIRK: Equatable/Hashable use id only — different titles still compare equal.
        var renamed = item
        renamed.title = "Renamed"
        XCTAssertEqual(item, renamed)
    }

    func testMediaLibraryItemRequiresTagsAndUsageCount() {
        // QUIRK: tags and usageCount are non-optional with NO decode default,
        // so an API payload missing them fails to decode entirely.
        let json = """
        {"id":"m2","title":"No tags","url":"https://x","type":"photo","uploadStatus":"ready",
         "usageCount":0,"createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """
        XCTAssertThrowsError(try JSONDecoder.apiDecoder.decode(MediaLibraryItem.self, from: Data(json.utf8)))
    }

    // MARK: - Video

    func testVideoDecodesFullPayload() throws {
        let video: Video = try decodeModel("""
        {"id":"v1","title":"Welcome","cloudflareUid":"cf-123",
         "playbackUrl":"https://stream/v1","thumbnailUrl":"https://thumb/v1.jpg",
         "duration":90,"status":"ready","userId":"u1","isActive":true,
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertEqual(video.videoStatus, .ready)
        XCTAssertEqual(video.formattedDuration, "1:30")
        XCTAssertEqual(video.displayTitle, "Welcome")
        XCTAssertEqual(video.createdAt, expectedDate)
    }

    func testVideoOptionalFieldAbsenceAndUnknownStatus() throws {
        let video: Video = try decodeModel("""
        {"id":"v2","cloudflareUid":"cf-456","playbackUrl":"https://stream/v2",
         "status":"something-unrecognized","userId":"u1",
         "createdAt":"\(isoDate)","updatedAt":"\(isoDate)"}
        """)
        XCTAssertNil(video.title)
        XCTAssertEqual(video.displayTitle, "Untitled Video")
        XCTAssertNil(video.duration)
        XCTAssertNil(video.formattedDuration)
        // QUIRK: unknown status strings map to .pending ("Processing").
        XCTAssertEqual(video.videoStatus, .pending)
    }

    // MARK: - Decoder configuration

    func testApiDecoderAcceptsFractionalSecondDates() throws {
        // Documents current Foundation behavior: .iso8601 on this OS accepts
        // fractional seconds ("...T10:30:00.000Z" decodes). Older Foundation
        // rejected them — if this test ever fails on a new SDK, API date
        // handling needs a custom strategy, not a test tweak.
        let json = """
        {"id":"v3","cloudflareUid":"cf","playbackUrl":"https://x","status":"ready",
         "userId":"u1","createdAt":"2025-01-15T10:30:00.000Z","updatedAt":"2025-01-15T10:30:00.000Z"}
        """
        let video = try JSONDecoder.apiDecoder.decode(Video.self, from: Data(json.utf8))
        XCTAssertEqual(video.id, "v3")
    }
}
