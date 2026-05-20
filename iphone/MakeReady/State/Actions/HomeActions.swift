//
//  HomeActions.swift
//  MakeReady
//
//  Actions for home page data (charts, stats, calendar events).
//  Loads heatmap, weekly activity, member/group counts, and scheduled lessons into AppState.
//

import Foundation

/// Actions for home page data loading.
/// Handles API calls for charts and stats, stores results in AppState.
struct HomeActions {

    private let state = AppState.shared
    private let api = APIClient.shared

    // MARK: - Load All Home Data

    /// Load all home page data (charts + stats) in parallel
    @MainActor
    func loadHomeData(forceRefresh: Bool = false) async {
        state.loadingStates.startLoading(.homeStats, hasCachedData: state.hasCachedHomeStats)

        defer {
            state.loadingStates.finishLoading(.homeStats)
        }

        // Load charts and stats in parallel
        async let statsTask: () = loadStats(forceRefresh: forceRefresh)
        async let chartsTask: () = loadChartData()

        _ = await (statsTask, chartsTask)

        state.homeStatsLoaded = true
        state.persist()
    }

    // MARK: - Stats

    @MainActor
    private func loadStats(forceRefresh: Bool) async {
        do {
            // Load groups
            try await GroupActions().loadGroups(forceRefresh: forceRefresh)
            let groups = state.orderedGroups
            state.homeTotalGroups = groups.count

            // Load members for all groups to get total unique count
            var allUserIds = Set<String>()
            await withTaskGroup(of: [GroupMember]?.self) { group in
                for userGroup in groups {
                    group.addTask {
                        try? await GroupActions().loadMembers(groupId: userGroup.id)
                    }
                }
                for await members in group {
                    if let members = members {
                        for member in members {
                            allUserIds.insert(member.userId)
                        }
                    }
                }
            }
            state.homeTotalMembers = allUserIds.count
        } catch {
            NSLog("❌ HomeActions: Failed to load stats: \(error)")
        }
    }

    // MARK: - Chart Data

    @MainActor
    private func loadChartData() async {
        async let heatmapTask: () = loadHeatmapData()
        async let weeklyTask: () = loadWeeklyActivityData()

        _ = await (heatmapTask, weeklyTask)
    }

    @MainActor
    private func loadHeatmapData() async {
        do {
            let response: HeatmapResponse = try await api.get(
                "/api/activity-logs/stats/heatmap",
                responseType: HeatmapResponse.self
            )

            if response.success, let buckets = response.data {
                state.homeHeatmapData = buckets
            }
        } catch {
            NSLog("❌ HomeActions: Failed to load heatmap data: \(error)")
        }
    }

    @MainActor
    private func loadWeeklyActivityData() async {
        do {
            let response: WeeklyStatsResponse = try await api.get(
                "/api/activity-logs/stats",
                responseType: WeeklyStatsResponse.self
            )

            if response.success, let days = response.data {
                state.homeWeeklyActivity = days
            }
        } catch {
            NSLog("❌ HomeActions: Failed to load weekly activity data: \(error)")
        }
    }

    // MARK: - Calendar Events

    /// Load scheduled lesson events for today and future dates, store in AppState
    @MainActor
    func loadCalendarEvents(forceRefresh: Bool = false) async {
        state.loadingStates.startLoading(.calendarEvents, hasCachedData: state.hasCachedCalendarEvents)

        defer {
            state.loadingStates.finishLoading(.calendarEvents)
        }

        do {
            // Ensure groups are loaded
            try await GroupActions().loadGroups(forceRefresh: forceRefresh)
            let groups = state.orderedGroups

            // Load enrollments for all groups concurrently
            var allEnrollments: [EnrollmentWithProgram] = []
            await withTaskGroup(of: [EnrollmentWithProgram]?.self) { group in
                for userGroup in groups {
                    group.addTask {
                        try? await EnrollmentActions().loadEnrollments(groupId: userGroup.id)
                    }
                }
                for await enrollments in group {
                    if let enrollments = enrollments {
                        allEnrollments.append(contentsOf: enrollments)
                    }
                }
            }

            // Get details (with lesson schedules) for each enrollment concurrently
            let today = Calendar.current.startOfDay(for: Date())
            let dateKeyFormatter = DateFormatter()
            dateKeyFormatter.dateFormat = "yyyy-MM-dd"

            var allSchedules: [(schedule: LessonSchedule, programName: String, coverImageUrl: String?)] = []
            await withTaskGroup(of: [(LessonSchedule, String, String?)]?.self) { group in
                for enrollment in allEnrollments {
                    group.addTask {
                        guard let details = try? await EnrollmentActions().getEnrollmentDetails(id: enrollment.id) else {
                            return nil
                        }
                        let programName = details.studyProgram?.name ?? "Study"
                        let coverUrl = details.studyProgram?.coverImageUrl
                        // Only include today and future scheduled lessons
                        return details.lessonSchedules
                            .filter { $0.scheduledDate >= today }
                            .map { ($0, programName, coverUrl) }
                    }
                }
                for await result in group {
                    if let schedules = result {
                        allSchedules.append(contentsOf: schedules)
                    }
                }
            }

            // Transform lesson schedules into calendar events keyed by date
            var eventsByDate: [String: [SplitCalendarEvent]] = [:]
            var scheduleMap: [String: (schedule: LessonSchedule, studyName: String, enrollmentId: String)] = [:]

            for (schedule, programName, coverUrl) in allSchedules {
                let dateKey = dateKeyFormatter.string(from: schedule.scheduledDate)
                let title = programName

                // Map activities to icons
                let icons = schedule.lesson.activities.sorted(by: { $0.orderNumber < $1.orderNumber }).map { activity in
                    CalendarActivityIcon(
                        icon: ActivityStyle.icon(forRawType: activity.type),
                        label: Self.activityLabel(for: activity.type),
                        rawType: activity.type
                    )
                }

                let event = SplitCalendarEvent(
                    id: schedule.id,
                    title: title,
                    subtitle: programName,
                    startTime: schedule.scheduledDate,
                    color: "#6c47ff",
                    dayNumber: schedule.lesson.dayNumber,
                    coverImageUrl: coverUrl,
                    activityIcons: icons,
                    estimatedMinutes: schedule.lesson.totalEstimatedMinutes
                )

                eventsByDate[dateKey, default: []].append(event)
                scheduleMap[schedule.id] = (schedule: schedule, studyName: programName, enrollmentId: schedule.enrollmentId)

                // Promote ScheduledActivity into the centralized entity store so the
                // Bible reader, calendar cards, and lesson editors can read live
                // verse-usage data instead of walking the schedule map.
                // Promote the entire lesson aggregate (with its activities,
                // readBlocks, and sourceReferences inline) into the lesson store.
                // This is the single source of truth for scheduled-side data.
                state.scheduledLessons.upsert(schedule.lesson)
            }

            // Sort events within each date bucket by scheduledDate then title for stable ordering
            for key in eventsByDate.keys {
                eventsByDate[key]?.sort {
                    if $0.startTime != $1.startTime {
                        return $0.startTime < $1.startTime
                    }
                    return $0.title < $1.title
                }
            }

            state.calendarEvents = eventsByDate
            state.lessonScheduleMap = scheduleMap
            state.calendarEventsLoaded = true
            state.persist()

            NSLog("📅 HomeActions: Loaded \(allSchedules.count) scheduled lessons across \(allEnrollments.count) enrollments (today+future only)")
        } catch {
            NSLog("❌ HomeActions: Failed to load calendar events: \(error)")
        }
    }

    // MARK: - Activity Helpers

    private static func activityLabel(for type: String) -> String {
        switch type {
        case "READ", "SCRIPTURE": return "Read"
        case "SOAP": return "SOAP"
        case "VIDEO": return "Video"
        case "USER_INPUT": return "Write"
        case "PRAYER": return "Pray"
        case "REFLECTION": return "Review"
        default: return type
        }
    }
}
