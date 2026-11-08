//
//  StatePersistenceRoundTripTests.swift
//  MakeReadyCaptureTests
//
//  CHARACTERIZATION tests for State/Persistence/PersistedState.swift.
//  Encode → decode round-trips use the same JSONEncoder/JSONDecoder
//  configuration as StatePersistence (iso8601 dates; compact output).
//  Equality is asserted FIELD-BY-FIELD, never on encoded bytes.
//

import XCTest
@testable import MakeReady

final class StatePersistenceRoundTripTests: XCTestCase {

    // Mirrors StatePersistence.init (StatePersistence.swift).
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Whole-second date: .iso8601 strategy does not carry sub-second precision.
    private let date = Date(timeIntervalSince1970: 1_750_000_000)

    private func makePopulatedState() -> PersistedState {
        var state = PersistedState()
        state.programs = [StudyProgram(
            id: "p1", name: "Genesis Study", description: "30 days in Genesis",
            days: 30, coverImageUrl: "https://cdn.example.com/cover.jpg",
            creatorId: "u1", isPublished: true,
            createdAt: date, updatedAt: date, tags: ["ot", "genesis"]
        )]
        state.groups = [UserGroup(
            id: "g1", code: "ABC123", name: "Young Professionals",
            description: "Weeknight group", isPrivate: false, allowInvites: true,
            memberCount: 27, creatorId: "u1", createdAt: date, updatedAt: date
        )]
        state.enrollments = [EnrollmentWithProgram(
            id: "e1", groupId: "g1", studyProgramId: "p1",
            startDate: date, endDate: .distantFuture,
            studyProgram: StudyProgramSummary(id: "p1", name: "Genesis Study", days: 30),
            isActive: true
        )]
        state.videos = [Video(
            id: "v1", title: "Welcome", description: nil, cloudflareUid: "cf-1",
            playbackUrl: "https://stream.example.com/v1", thumbnailUrl: nil,
            duration: 90, status: "ready", userId: "u1", isActive: true,
            createdAt: date, updatedAt: date
        )]
        state.lessonsByProgram = ["p1": [Lesson(
            id: "l1", studyProgramId: "p1", position: 1, title: "Day 1",
            createdAt: date, updatedAt: date
        )]]
        state.activities = [ContentActivity(
            id: "a1", lessonVersionId: "v1", activityKey: "k1", position: 0, kind: "text", title: "Scripture",
            document: ActivityDocument(raw: .object(["schemaVersion": .number(1), "kind": .string("text")])),
            estimatedSeconds: 30
        )]
        state.programLessonIndex = ["p1": ["l1"]]
        state.groupEnrollmentIndex = ["g1": ["e1"]]
        state.programEnrollmentIndex = ["p1": ["e1"]]
        state.organizationId = "org-1"
        state.homeTotalMembers = 42
        state.homeTotalGroups = 7
        state.persistedAt = date
        state.schemaVersion = PersistedState.currentSchemaVersion
        return state
    }

    // MARK: - Round trip

    func testRoundTripPreservesFieldsFieldByField() throws {
        let original = makePopulatedState()
        let data = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(PersistedState.self, from: data)

        // Program
        XCTAssertEqual(decoded.programs.count, 1)
        let program = try XCTUnwrap(decoded.programs.first)
        XCTAssertEqual(program.id, "p1")
        XCTAssertEqual(program.name, "Genesis Study")
        XCTAssertEqual(program.description, "30 days in Genesis")
        XCTAssertEqual(program.days, 30)
        XCTAssertEqual(program.coverImageUrl, "https://cdn.example.com/cover.jpg")
        XCTAssertEqual(program.creatorId, "u1")
        XCTAssertEqual(program.isPublished, true)
        XCTAssertEqual(program.tags, ["ot", "genesis"])
        XCTAssertEqual(program.createdAt, date)

        // Group
        let group = try XCTUnwrap(decoded.groups.first)
        XCTAssertEqual(group.id, "g1")
        XCTAssertEqual(group.code, "ABC123")
        XCTAssertEqual(group.name, "Young Professionals")
        XCTAssertEqual(group.memberCount, 27)
        XCTAssertEqual(group.isPrivate, false)
        XCTAssertEqual(group.allowInvites, true)
        XCTAssertEqual(group.memberDirectory, true)  // default survives round trip

        // Enrollment
        let enrollment = try XCTUnwrap(decoded.enrollments.first)
        XCTAssertEqual(enrollment.id, "e1")
        XCTAssertEqual(enrollment.groupId, "g1")
        XCTAssertEqual(enrollment.studyProgramId, "p1")
        XCTAssertEqual(enrollment.startDate, date)
        // QUIRK: endDate == .distantFuture is NOT encoded at all; the decoder
        // defaults missing completedAt/endDate back to .distantFuture.
        XCTAssertEqual(enrollment.endDate, Date.distantFuture)
        XCTAssertTrue(enrollment.isActive)
        XCTAssertEqual(enrollment.studyProgram?.name, "Genesis Study")
        XCTAssertEqual(enrollment.studyProgram?.days, 30)

        // Video
        let video = try XCTUnwrap(decoded.videos.first)
        XCTAssertEqual(video.id, "v1")
        XCTAssertEqual(video.cloudflareUid, "cf-1")
        XCTAssertEqual(video.playbackUrl, "https://stream.example.com/v1")
        XCTAssertEqual(video.duration, 90)
        XCTAssertEqual(video.status, "ready")

        // Lessons / activities keyed by parent
        XCTAssertEqual(decoded.lessonsByProgram["p1"]?.first?.id, "l1")
        XCTAssertEqual(decoded.lessonsByProgram["p1"]?.first?.position, 1)
        XCTAssertEqual(decoded.activities.first?.id, "a1")
        XCTAssertEqual(decoded.activities.first?.kind, "text")
        XCTAssertEqual(decoded.activities.first?.lessonVersionId, "v1")
        XCTAssertEqual(decoded.activities.first?.estimatedSeconds, 30)

        // Indexes
        XCTAssertEqual(decoded.programLessonIndex, ["p1": ["l1"]])
        XCTAssertEqual(decoded.groupEnrollmentIndex, ["g1": ["e1"]])
        XCTAssertEqual(decoded.programEnrollmentIndex, ["p1": ["e1"]])

        // Scalars / metadata
        XCTAssertEqual(decoded.organizationId, "org-1")
        XCTAssertEqual(decoded.homeTotalMembers, 42)
        XCTAssertEqual(decoded.homeTotalGroups, 7)
        XCTAssertEqual(decoded.persistedAt, date)
        XCTAssertEqual(decoded.schemaVersion, PersistedState.currentSchemaVersion)

        // Empty collections survive
        XCTAssertTrue(decoded.scheduledLessons.isEmpty)
        XCTAssertTrue(decoded.templates.isEmpty)
        XCTAssertTrue(decoded.mediaLibrary.isEmpty)
        XCTAssertTrue(decoded.calendarEvents.isEmpty)
    }

    func testRoundTripDropsSubSecondDatePrecision() throws {
        // QUIRK: .iso8601 encoding has whole-second resolution, so fractional
        // seconds are lost on the persistence round trip.
        var state = PersistedState()
        state.persistedAt = Date(timeIntervalSince1970: 1_750_000_000.25)
        let data = try makeEncoder().encode(state)
        let decoded = try makeDecoder().decode(PersistedState.self, from: data)
        XCTAssertEqual(decoded.persistedAt, Date(timeIntervalSince1970: 1_750_000_000))
    }

    // MARK: - Decoding tolerance

    /// JSON containing ONLY the keys PersistedState's decoder hard-requires.
    private let minimalJSON = """
    {"programs":[],"groups":[],"enrollments":[],"videos":[],
     "postsByGroup":{},"membersByGroup":{},"lessonsByProgram":{},
     "programEnrollmentIndex":{},"groupEnrollmentIndex":{},"programLessonIndex":{},
     "persistedAt":"2026-01-01T00:00:00Z","schemaVersion":1}
    """

    func testDecodingMissingOptionalFieldsFallsBackToDefaults() throws {
        let decoded = try makeDecoder().decode(PersistedState.self, from: Data(minimalJSON.utf8))
        // Backwards-compat optionals default rather than throw:
        XCTAssertTrue(decoded.activities.isEmpty)
        XCTAssertTrue(decoded.lessonVersions.isEmpty)
        XCTAssertTrue(decoded.mediaMap.isEmpty)
        XCTAssertTrue(decoded.scheduledLessons.isEmpty)
        XCTAssertTrue(decoded.programEnrollmentsByProgram.isEmpty)
        XCTAssertEqual(decoded.programProgramEnrollmentIndex, [:])
        XCTAssertTrue(decoded.templates.isEmpty)
        XCTAssertTrue(decoded.mediaLibrary.isEmpty)
        XCTAssertNil(decoded.organizationId)
        XCTAssertTrue(decoded.homeHeatmapData.isEmpty)
        XCTAssertTrue(decoded.homeWeeklyActivity.isEmpty)
        XCTAssertEqual(decoded.homeTotalMembers, 0)
        XCTAssertEqual(decoded.homeTotalGroups, 0)
        XCTAssertTrue(decoded.calendarEvents.isEmpty)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testDecodingIgnoresUnknownExtraKeys() throws {
        let withExtras = minimalJSON.replacingOccurrences(
            of: "\"schemaVersion\":1}",
            with: "\"schemaVersion\":1,\"someFutureField\":{\"a\":1},\"anotherUnknown\":[1,2,3]}"
        )
        let decoded = try makeDecoder().decode(PersistedState.self, from: Data(withExtras.utf8))
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testDecodingMissingRequiredKeyThrows() {
        // QUIRK: programs/groups/enrollments/videos/postsByGroup/membersByGroup/
        // lessonsByProgram/the 3 legacy indexes/persistedAt/schemaVersion are
        // REQUIRED — omitting any of them fails the whole cache load.
        let missingVideos = minimalJSON.replacingOccurrences(of: "\"videos\":[],", with: "")
        XCTAssertThrowsError(
            try makeDecoder().decode(PersistedState.self, from: Data(missingVideos.utf8))
        )
    }

    // MARK: - D44: a cache from another schema version is discarded

    func testAVersionOneDiskCacheIsDiscardedAtLaunch() {
        let persistence = StatePersistence.shared
        persistence.clear()
        defer { persistence.clear() }

        var old = PersistedState()
        old.schemaVersion = 1
        persistence.saveImmediately(old)
        waitForTheCacheFile(persistence)
        XCTAssertNil(persistence.load())
        XCTAssertFalse(persistence.getFileInfo().exists, "the stale file is deleted")

        persistence.saveImmediately(PersistedState())
        waitForTheCacheFile(persistence)
        XCTAssertEqual(persistence.load()?.schemaVersion, PersistedState.currentSchemaVersion)
    }

    /// `saveImmediately` writes on a background queue; wait for the file before reading it back.
    private func waitForTheCacheFile(_ persistence: StatePersistence) {
        let deadline = Date().addingTimeInterval(5)
        while !persistence.getFileInfo().exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertTrue(persistence.getFileInfo().exists)
    }
}
