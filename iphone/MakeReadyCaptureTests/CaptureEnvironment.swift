//
//  CaptureEnvironment.swift
//  MakeReadyCaptureTests
//
//  Sets up AppState and AuthManager from fixture data before each capture.
//  Replaces the AppState singleton with a fresh instance so every property
//  starts at its default — no need to enumerate fields to reset.
//

import Foundation
@testable import MakeReady

/// Replaces AppState.shared with a fresh instance and populates from fixture data.
func setupCaptureState(from fixture: CaptureFixture) {
    // Fresh instance — every property at its default value
    AppState.shared = AppState()
    let state = AppState.shared

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
                        helpIcon: captureActivity.helpIcon
                    )
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
