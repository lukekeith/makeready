//
//  CaptureEnvironment.swift
//  MakeReadyCaptureTests
//
//  Sets up AppState and AuthManager from fixture data before each capture.
//  Replaces the AppState singleton with a fresh instance so every property
//  starts at its default — no need to enumerate fields to reset.
//

import Foundation
import UIKit
@testable import MakeReady

/// Replaces AppState.shared with a fresh instance and populates from fixture data.
@MainActor
func setupCaptureState(from fixture: CaptureFixture) {
    // Fresh instance — every property at its default value
    AppState.shared = AppState()
    let state = AppState.shared
    // Clear any mocked endpoints from the previous fixture (search recents/results).
    MockURLProtocol.reset()

    // Always seed standard lesson templates (used by CreateProgramPage picker)
    let now = Date()
    state.templates.replaceAll([
        LessonTemplate(id: "tmpl-soap", name: "SOAP", description: "Scripture, Observation, Application, Prayer.", createdAt: now, updatedAt: now),
        LessonTemplate(id: "tmpl-oia", name: "OIA", description: "Observe, Interpret, Apply.", createdAt: now, updatedAt: now),
        LessonTemplate(id: "tmpl-dbs", name: "DBS", description: "Discovery Bible Study — seven questions on a passage.", createdAt: now, updatedAt: now),
        LessonTemplate(id: "tmpl-custom", name: "Custom", description: "Build your own lesson structure.", createdAt: now, updatedAt: now)
    ])

    guard let fixtureState = fixture.state else { return }

    let creatorId = fixture.auth?.currentUser?.id ?? "user-1"

    // Pre-seed a component's remote images into the memory cache so the
    // synchronous snapshot renders them. CachedCardImage is cache-first; without
    // this its async network .task can't finish within one snapshot render pass,
    // leaving an empty image box (whereas Playwright waits for the web image).
    // Seed every image-bearing field a card might use — CachedCardImage fetches a
    // derived `mediumImageUrl` first and falls back to the original, and its
    // cache-first init checks BOTH, so seeding the original URL is enough.
    if let component = fixtureState.component {
        let imageURLs = [
            component.coverUrl,
            component.imageUrl,
            component.avatarUrl,
            component.studyImageURL,   // CardEnrolled (top tile)
            component.groupImageURL,   // CardEnrolled (bottom tile)
        ].compactMap { $0 } + (component.images ?? [])
        for urlString in imageURLs {
            guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true,
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { continue }
            ImageCache.shared.seed(image, for: url)
        }
    }

    // Seed groups (pages.group-home reads AppState.groups[groupId] on init)
    if let groups = fixtureState.groups {
        for g in groups {
            state.groups.upsert(UserGroup(
                id: g.id,
                code: g.code ?? "ABC123",
                name: g.name ?? "Group",
                description: g.description,
                coverImageUrl: g.coverImageUrl,
                isPrivate: g.isPrivate ?? false,
                allowInvites: g.allowInvites ?? true,
                memberDirectory: g.memberDirectory ?? true,
                memberCount: g.memberCount ?? 0,
                creatorId: g.creatorId ?? creatorId,
                createdAt: now,
                updatedAt: now
            ))
        }
    }

    // Seed enrollments + the group→enrollment relationship index
    if let enrollments = fixtureState.enrollments {
        for e in enrollments {
            let summary = e.studyProgram.map {
                StudyProgramSummary(id: $0.id, name: $0.name, days: $0.days ?? 30)
            }
            state.enrollments.upsert(EnrollmentWithProgram(
                id: e.id,
                groupId: e.groupId,
                studyProgramId: e.studyProgramId ?? (summary?.id ?? ""),
                startDate: now,
                endDate: Date.distantFuture,
                studyProgram: summary,
                isActive: e.isActive ?? true
            ))
            state.groupEnrollmentIndex.add(parentId: e.groupId, childId: e.id)
        }
    }

    // Seed program whenever programId is present (needed by ProgramHomePage and activity editors)
    if let programId = fixtureState.programId {
        let name = fixtureState.programName ?? "Romans Study"
        let days = fixtureState.programDays ?? 30
        state.programs.upsert(StudyProgram(
            id: programId,
            name: name,
            days: days,
            creatorId: creatorId,
            isPublished: true,
            createdAt: now,
            updatedAt: now
        ))
    }

    // Seed a LIST of programs (Library Programs tab / Enrolled tab / Search).
    // Each entry is an AnyCodableValue bag carrying id/name/days.
    if let programDicts = fixtureState.programs {
        for dict in programDicts {
            func str(_ k: String) -> String? { if case .string(let v)? = dict[k] { return v }; return nil }
            func intVal(_ k: String) -> Int? { if case .int(let v)? = dict[k] { return v }; return nil }
            guard let id = str("id") else { continue }
            state.programs.upsert(StudyProgram(
                id: id,
                name: str("name") ?? "Study",
                days: intVal("days") ?? 0,
                creatorId: creatorId,
                isPublished: true,
                createdAt: now,
                updatedAt: now
            ))
        }
    }

    // Seed lessons for ProgramHomePage fixtures
    if let fixtureLessons = fixtureState.lessons {
        let programId = fixtureState.programId ?? "capture-prog-0"
        for lessonData in fixtureLessons {
            let lesson = Lesson(
                id: lessonData.id,
                studyProgramId: programId,
                dayNumber: lessonData.dayNumber,
                title: lessonData.title,
                estimatedMinutes: lessonData.estimatedMinutes,
                activities: [],
                createdAt: now,
                updatedAt: now
            )
            state.lessons.upsert(lesson)
            state.programLessonIndex.add(parentId: programId, childId: lesson.id)

            // Seed activities embedded in this lesson
            if let lessonActivities = lessonData.activities {
                for captureActivity in lessonActivities {
                    let activityType = ActivityType(rawValue: captureActivity.type) ?? .read
                    let activityStatus = ActivityStatus(rawValue: captureActivity.status ?? "PENDING") ?? .pending
                    // Read blocks drive READ/EXEGESIS `isConfigured` (EditDay cards)
                    let readBlocks: [ActivityReadBlock]? = captureActivity.readBlocks?.map { block in
                        ActivityReadBlock(
                            id: block.id,
                            orderNumber: block.orderNumber,
                            title: block.title,
                            content: block.content,
                            isLocked: block.isLocked,
                            sourceReferenceId: block.sourceReferenceId,
                            backgroundImageUrl: block.backgroundImageUrl,
                            backgroundColor: block.backgroundColor,
                            backgroundOverlayOpacity: block.backgroundOverlayOpacity,
                            fontSize: block.fontSize,
                            selections: block.selections?.map { sel in
                                ReadBlockSelection(start: sel.start, end: sel.end, style: sel.style)
                            }
                        )
                    }
                    var activity = StudyActivity(
                        id: captureActivity.id,
                        lessonId: lessonData.id,
                        type: activityType,
                        status: activityStatus,
                        orderNumber: captureActivity.orderNumber ?? 1,
                        title: captureActivity.title,
                        isHelpEnabled: captureActivity.isHelpEnabled,
                        helpTitle: captureActivity.helpTitle,
                        helpDescription: captureActivity.helpDescription,
                        helpIcon: captureActivity.helpIcon,
                        readBlocks: readBlocks
                    )
                    activity.placeholder = captureActivity.placeholder
                    activity.passageReference = captureActivity.passageReference
                    activity.estimatedSeconds = captureActivity.estimatedSeconds
                    activity.youtubeUrl = captureActivity.youtubeUrl
                    activity.youtubeVideoId = captureActivity.youtubeVideoId
                    activity.youtubeThumbnailUrl = captureActivity.youtubeThumbnailUrl
                    state.activities.upsert(activity)
                    state.lessonActivityIndex.add(parentId: lessonData.id, childId: activity.id)
                }
            }
        }
    }

    // Home stats
    if let homeStats = fixtureState.homeStats {
        if let total = homeStats.totalMembers { state.homeTotalMembers = total }
        if let total = homeStats.totalGroups { state.homeTotalGroups = total }

        if let heatmap = homeStats.heatmap {
            state.homeHeatmapData = heatmap.map {
                HeatmapBucket(day: $0.day, hour: $0.hour, count: $0.count)
            }
        }

        if let weekly = homeStats.weeklyActivity {
            state.homeWeeklyActivity = weekly.map {
                DayActivityCount(date: $0.date, count: $0.count)
            }
        }

        // Populate programs store so the Studies KPI reflects totalStudies
        if let count = homeStats.totalStudies, count > 0 {
            for i in 0..<count {
                state.programs.upsert(StudyProgram(
                    id: "capture-prog-\(i)",
                    name: "Study \(i + 1)",
                    days: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                ))
            }
        }

        // Populate enrollments store so the Enrolled Lessons KPI reflects totalEnrolledLessons
        if let lessonCount = homeStats.totalEnrolledLessons, lessonCount > 0 {
            state.enrollments.upsert(EnrollmentWithProgram(
                id: "capture-enroll-0",
                groupId: "capture-group-0",
                studyProgramId: "capture-prog-0",
                startDate: Date(),
                endDate: Date.distantFuture,
                studyProgram: StudyProgramSummary(
                    id: "capture-prog-0",
                    name: "Capture Study",
                    days: lessonCount
                ),
                isActive: true
            ))
        }

        state.homeStatsLoaded = true
    }

    // Calendar screen — seed AppState.calendarEvents (keyed "yyyy-MM-dd") and
    // mark loaded, so MainCalendar renders the grid instead of the loading
    // spinner (loadCalendarEvents treats cached data as a background refresh).
    if let entries = fixtureState.calendarEvents {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        var byDay: [String: [SplitCalendarEvent]] = [:]
        for e in entries {
            let start = df.date(from: e.date) ?? now
            let event = SplitCalendarEvent(
                id: e.id,
                title: e.title,
                subtitle: e.studyName,
                startTime: start,
                color: "#6c47ff"
            )
            byDay[e.date, default: []].append(event)
        }
        state.calendarEvents = byDay
        state.calendarEventsLoaded = true
    }

    // Media screen — seed AppState.mediaLibrary so hasCachedMedia is true and
    // the Media tab renders instead of spinning.
    if let mediaItems = fixtureState.media {
        let typeMap = ["IMAGE": "photo", "VIDEO": "video", "DOCUMENT": "document", "AUDIO": "audio"]
        let items = mediaItems.map { m in
            MediaLibraryItem(
                id: m.id,
                title: m.title,
                description: nil,
                url: "",
                type: typeMap[m.type ?? ""] ?? (m.type?.lowercased() ?? "document"),
                mimeType: nil,
                fileSize: nil,
                thumbnailUrl: nil,
                uploadStatus: "ready",
                duration: nil,
                tags: [],
                usageCount: 0,
                uploader: nil,
                video: nil,
                createdAt: now,
                updatedAt: now
            )
        }
        state.mediaLibrary.replaceAll(items)
    }

    // Search screen — the recents/results come from the network (no local
    // fallback), so mock the endpoints (test-target only) from the seeded
    // programs/groups. `searchRecents` → GET /api/activities; `searchQuery` →
    // GET /api/search (+ GlobalSearchPage.initialQuery drives the query).
    if fixtureState.searchRecents == true {
        let activities: [UserActivity] =
            state.programs.all.prefix(3).map {
                UserActivity(id: "act-p-\($0.id)", actorId: creatorId, action: "UPDATED",
                             resourceType: "PROGRAM", resourceId: $0.id, resourceName: $0.name,
                             organizationId: nil, createdAt: now)
            } +
            state.groups.all.prefix(3).map {
                UserActivity(id: "act-g-\($0.id)", actorId: creatorId, action: "UPDATED",
                             resourceType: "GROUP", resourceId: $0.id, resourceName: $0.name ?? "Group",
                             organizationId: nil, createdAt: now)
            }
        let response = UserActivityResponse(success: true, activities: activities)
        if let data = try? JSONEncoder.apiEncoder.encode(response) {
            MockURLProtocol.responses["/api/activities"] = data
        }
    }

    if fixtureState.searchQuery != nil {
        // Build the /api/search JSON via JSONSerialization (the SearchAPIResponse
        // types are private to GlobalSearchEngine; only the JSON shape matters).
        let programJSON = state.programs.all.prefix(5).map { p -> [String: Any] in
            ["id": p.id, "name": p.name, "days": p.days]
        }
        let groupJSON = state.groups.all.prefix(5).map { g -> [String: Any] in
            ["id": g.id, "name": g.name ?? "Group"]
        }
        let payload: [String: Any] = [
            "success": true,
            "query": fixtureState.searchQuery ?? "",
            "results": ["programs": programJSON, "groups": groupJSON],
            "counts": ["programs": programJSON.count, "groups": groupJSON.count],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            MockURLProtocol.responses["/api/search"] = data
        }
    }

    // Activity-editor state: seed activity into AppState
    if let captureActivity = fixtureState.activity {
        let programId = fixtureState.programId ?? "capture-prog-0"
        let lessonId = fixtureState.lessonId ?? "capture-lesson-0"

        // Ensure the program is present (may already be seeded above)
        if state.programs[programId] == nil {
            state.programs.upsert(StudyProgram(
                id: programId,
                name: fixtureState.programName ?? "Romans Study",
                days: fixtureState.programDays ?? 30,
                creatorId: creatorId,
                isPublished: true,
                createdAt: now,
                updatedAt: now
            ))
        }

        // Build ActivityReadBlocks
        let readBlocks: [ActivityReadBlock]? = captureActivity.readBlocks?.map { block in
            ActivityReadBlock(
                id: block.id,
                orderNumber: block.orderNumber,
                title: block.title,
                content: block.content,
                isLocked: block.isLocked,
                sourceReferenceId: block.sourceReferenceId,
                backgroundImageUrl: block.backgroundImageUrl,
                backgroundColor: block.backgroundColor,
                backgroundOverlayOpacity: block.backgroundOverlayOpacity,
                fontSize: block.fontSize,
                selections: block.selections?.map { sel in
                    ReadBlockSelection(start: sel.start, end: sel.end, style: sel.style)
                }
            )
        }

        // Build ActivitySourceReferences
        let sourceRefs: [ActivitySourceReference]? = captureActivity.sourceReferences?.map { ref in
            ActivitySourceReference(
                id: ref.id,
                lessonActivityId: captureActivity.id,
                sourceType: nil,
                passageReference: ref.passageReference,
                bookNumber: ref.bookNumber,
                bookName: ref.bookName,
                chapterStart: ref.chapterStart,
                chapterEnd: ref.chapterEnd,
                verseStart: ref.verseStart,
                verseEnd: ref.verseEnd,
                createdAt: nil,
                updatedAt: nil
            )
        }

        let activityType = ActivityType(rawValue: captureActivity.type) ?? .read
        let activityStatus = ActivityStatus(rawValue: captureActivity.status ?? "PENDING") ?? .pending

        var activity = StudyActivity(
            id: captureActivity.id,
            lessonId: lessonId,
            type: activityType,
            status: activityStatus,
            orderNumber: captureActivity.orderNumber ?? 1,
            title: captureActivity.title,
            isHelpEnabled: captureActivity.isHelpEnabled,
            helpTitle: captureActivity.helpTitle,
            helpDescription: captureActivity.helpDescription,
            helpIcon: captureActivity.helpIcon,
            sourceReferences: sourceRefs,
            readBlocks: readBlocks
        )

        // USER_INPUT placeholder (the Write editor's second field)
        activity.placeholder = captureActivity.placeholder

        // YouTube fields
        activity.youtubeUrl = captureActivity.youtubeUrl
        activity.youtubeVideoId = captureActivity.youtubeVideoId
        activity.youtubeThumbnailUrl = captureActivity.youtubeThumbnailUrl
        activity.youtubeStartSeconds = captureActivity.youtubeStartSeconds
        activity.youtubeEndSeconds = captureActivity.youtubeEndSeconds

        state.activities.upsert(activity)
    }
}

/// Creates a mock AuthManager configured from fixture auth data.
func makeMockAuthManager(from auth: CaptureAuth?) -> AuthManager {
    let manager = AuthManager()
    if let auth = auth {
        manager.isAuthenticated = auth.isAuthenticated
        if let user = auth.currentUser {
            manager.currentUser = User(
                id: user.id,
                name: user.name,
                email: user.email,
                picture: user.picture
            )
        }
    }
    return manager
}

// MARK: - Network mock (test target only)

/// A `URLProtocol` that returns canned JSON for specific endpoints during
/// capture, so screens whose content comes only from the network (e.g. the
/// global search screen's recents/results) can render offline. Registered once
/// in `CaptureRunner.setUp`; intercepts `URLSession.shared`. `responses` is
/// reset per fixture by `setupCaptureState`, and `canInit` only matches an
/// endpoint that is currently configured — every other request falls through to
/// the real (offline) path unchanged. Lives in the test target only; ships
/// nothing into the app.
final class MockURLProtocol: URLProtocol {
    /// endpoint-path-substring → response JSON body.
    nonisolated(unsafe) static var responses: [String: Data] = [:]

    static func reset() { responses = [:] }

    private static func match(_ url: URL?) -> Data? {
        guard let s = url?.absoluteString else { return nil }
        for (key, data) in responses where s.contains(key) { return data }
        return nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        match(request.url) != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = MockURLProtocol.match(request.url) ?? Data()
        if let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                          headerFields: ["Content-Type": "application/json"]) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
