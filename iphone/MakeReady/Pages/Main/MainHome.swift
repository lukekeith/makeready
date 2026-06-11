//
//  MainHome.swift
//  MakeReady
//
//  Home tab page content
//

import SwiftUI

enum HomeKPIDestination {
    case members
    case groups
    case enrolledLessons
    case studies
}

struct MainHome: View {
    let overlayManager: OverlayManager
    let avatarURL: String?
    var onAddTap: (() -> Void)? = nil
    var onKPITap: ((HomeKPIDestination) -> Void)? = nil
    @State private var activeTab = 0

    @Environment(AuthManager.self) var authManager

    // Centralized state
    private var state: AppState { AppState.shared }

    // Refresh state
    @State private var isRefreshing = false

    // Activity tab state
    @State private var activityLogs: [ActivityLogEntry] = []
    @State private var activityCursor: String? = nil
    @State private var activityHasMore = true
    @State private var isLoadingActivity = false
    @State private var isLoadingMoreActivity = false
    @State private var activitySearchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool

    // MARK: - Computed Properties (transform AppState → chart data)

    private var heatmapData: [HeatMapDataPoint] {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return state.homeHeatmapData.map { bucket in
            HeatMapDataPoint(
                week: bucket.day,
                day: bucket.hour,
                value: Double(bucket.count),
                dayLabel: dayLabels[bucket.day]
            )
        }
    }

    private var weeklyActivityData: [BarChartDataPoint] {
        let dayFormatter = DateFormatters.dateKey
        let displayFormatter = DateFormatters.weekdayAbbrev

        return state.homeWeeklyActivity.compactMap { day in
            guard let date = dayFormatter.date(from: day.date) else { return nil }
            return BarChartDataPoint(
                label: displayFormatter.string(from: date),
                value: Double(day.count),
                color: Color(hex: "#6c47ff")
            )
        }
    }

    private var chartsLoaded: Bool {
        state.homeStatsLoaded
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Home", "Activity"],
                    activeTab: $activeTab
                ) {
                    Button {
                        onAddTap?()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if activeTab == 0 {
                    homeTabContent
                } else {
                    activityTabContent
                }
            }
        }
        .task {
            async let homeTask: () = HomeActions().loadHomeData(forceRefresh: false)
            async let calendarTask: () = HomeActions().loadCalendarEvents(forceRefresh: false)
            _ = await (homeTask, calendarTask)
        }
    }

    // MARK: - Home Tab

    private var homeTabContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                kpiGrid
                upcomingLessonsSection
                chartsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .refreshable {
            guard !isRefreshing else { return }
            isRefreshing = true

            Task.detached { @MainActor in
                defer { isRefreshing = false }
                await HomeActions().loadHomeData(forceRefresh: true)
                await HomeActions().loadCalendarEvents(forceRefresh: true)
            }

            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Activity Tab

    private var activityTabContent: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 4) {
                    // Space for search field overlay
                    Color.clear
                        .frame(height: 60)

                    if isLoadingActivity && activityLogs.isEmpty {
                        // Loading skeleton
                        ForEach(0..<8, id: \.self) { _ in
                            activitySkeletonCard
                        }
                    } else if filteredActivityLogs.isEmpty {
                        VStack(spacing: 12) {
                            Spacer().frame(height: 40)

                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))

                            Text(activitySearchText.isEmpty ? "No activity yet" : "No results")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ForEach(filteredActivityLogs) { entry in
                            CardActivity(entry: entry)

                            // Infinite scroll trigger
                            if entry.id == filteredActivityLogs.last?.id && activityHasMore && activitySearchText.isEmpty {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        loadMoreActivityLogs()
                                    }
                            }
                        }

                        if isLoadingMoreActivity {
                            ProgressView()
                                .tint(.white.opacity(0.3))
                                .padding(.vertical, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                await loadActivityLogs(reset: true)
            }

            // Search field overlay
            VStack(spacing: 0) {
                SearchField(
                    isActive: $isSearchActive,
                    searchText: $activitySearchText,
                    isFocused: $isSearchFocused,
                    placeholder: "Search activity"
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appBackground)

                // Fade gradient
                LinearGradient(
                    colors: [Color.appBackground, Color.appBackground.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 12)
            }
        }
        .task {
            if activityLogs.isEmpty {
                await loadActivityLogs(reset: true)
            }
        }
    }

    private var filteredActivityLogs: [ActivityLogEntry] {
        if activitySearchText.isEmpty {
            return activityLogs
        }
        let query = activitySearchText.lowercased()
        return activityLogs.filter { entry in
            entry.message.lowercased().contains(query) ||
            entry.category.lowercased().contains(query) ||
            entry.activityType.lowercased().contains(query)
        }
    }

    private var activitySkeletonCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 10)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func loadActivityLogs(reset: Bool) async {
        if reset {
            activityCursor = nil
            activityHasMore = true
        }
        isLoadingActivity = true
        defer { isLoadingActivity = false }

        do {
            let response = try await HomeActions().loadActivityLogs()
            // Filter to content and membership activities only (exclude auth/login noise)
            activityLogs = response.logs.filter { $0.category != "AUTH" }
            activityCursor = response.pagination.nextCursor
            activityHasMore = response.pagination.hasMore
        } catch {
            NSLog("❌ Failed to load activity logs: \(error)")
        }
    }

    private func loadMoreActivityLogs() {
        guard !isLoadingMoreActivity, activityHasMore, let cursor = activityCursor else { return }
        isLoadingMoreActivity = true

        Task {
            defer { isLoadingMoreActivity = false }
            do {
                let response = try await HomeActions().loadActivityLogs(cursor: cursor)
                activityLogs.append(contentsOf: response.logs.filter { $0.category != "AUTH" })
                activityCursor = response.pagination.nextCursor
                activityHasMore = response.pagination.hasMore
            } catch {
                NSLog("❌ Failed to load more activity logs: \(error)")
            }
        }
    }

    // MARK: - KPI Grid

    private var enrolledLessons: Int {
        state.enrollments.all
            .filter { $0.isActive }
            .reduce(0) { $0 + ($1.studyProgram?.days ?? 0) }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible())], spacing: 4) {
            Button { onKPITap?(.members) } label: {
                Kpi(
                    value: Double(state.homeTotalMembers),
                    valueType: .number,
                    label: "Members",
                    icon: "person.2",
                    iconColor: .brandPrimary,
                    variant: .iconValue
                )
            }
            .buttonStyle(.plain)

            Button { onKPITap?(.groups) } label: {
                Kpi(
                    value: Double(state.homeTotalGroups),
                    valueType: .number,
                    label: "Groups",
                    icon: "person.3",
                    iconColor: .brandPrimary,
                    variant: .iconValue
                )
            }
            .buttonStyle(.plain)

            Button { onKPITap?(.enrolledLessons) } label: {
                Kpi(
                    value: Double(enrolledLessons),
                    valueType: .number,
                    label: "Enrolled Lessons",
                    icon: "book",
                    iconColor: .brandPrimary,
                    variant: .iconValue
                )
            }
            .buttonStyle(.plain)

            Button { onKPITap?(.studies) } label: {
                Kpi(
                    value: Double(state.programs.count),
                    valueType: .number,
                    label: "Studies",
                    icon: "text.book.closed",
                    iconColor: .brandPrimary,
                    variant: .iconValue
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Upcoming Lessons

    /// Get the next scheduled lesson from each enrollment (soonest per enrollment)
    private var upcomingLessons: [SplitCalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        let dateKeyFormatter = DateFormatters.dateKey

        // Flatten all future events, sorted by date
        var allEvents: [SplitCalendarEvent] = []
        for (dateKey, events) in state.calendarEvents {
            guard let date = dateKeyFormatter.date(from: dateKey), date >= today else { continue }
            allEvents.append(contentsOf: events)
        }

        // Sort by start time, then by title for stable ordering when dates match
        allEvents.sort {
            if $0.startTime != $1.startTime {
                return $0.startTime < $1.startTime
            }
            return $0.title < $1.title
        }

        var seenPrograms = Set<String>()
        var result: [SplitCalendarEvent] = []
        for event in allEvents {
            let key = event.subtitle ?? event.title
            if !seenPrograms.contains(key) {
                seenPrograms.insert(key)
                result.append(event)
            }
        }

        return result
    }

    private var upcomingLessonsSection: some View {
        Group {
            if !upcomingLessons.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upcoming Lessons")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    VStack(spacing: 4) {
                        ForEach(upcomingLessons) { event in
                            CardLesson(
                                data: CardLessonData(
                                    id: event.id,
                                    day: event.dayNumber ?? 1,
                                    mode: .lesson,
                                    activities: (event.activityIcons ?? []).map { icon in
                                        LessonActivityData(icon: icon.icon, type: icon.rawType, title: icon.label, status: .incomplete)
                                    },
                                    title: event.title,
                                    date: event.startTime,
                                    coverImageUrl: event.coverImageUrl,
                                    estimatedMinutes: event.estimatedMinutes
                                ),
                                onTap: {
                                    handleLessonTap(event)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Lesson Tap

    private func presentEditEnrollmentDay(schedule: LessonSchedule, enrollmentId: String) {
        overlayManager.presentModal(id: OverlayID.editEnrollmentDay, dismissOnTapOutside: false) {
            EditEnrollmentDayWrapper(
                schedule: schedule,
                enrollmentId: enrollmentId,
                overlayManager: overlayManager
            )
        }
    }

    private func handleLessonTap(_ event: SplitCalendarEvent) {
        guard let entry = state.lessonScheduleMap[event.id] else {
            NSLog("⚠️ MainHome: No schedule data for event \(event.id)")
            return
        }

        overlayManager.present(.lessonActionMenu) {
            LessonActionMenu(
                schedule: entry.schedule,
                studyName: entry.studyName,
                enrollmentId: entry.enrollmentId,
                onEditActivities: { [self] in
                    presentEditEnrollmentDay(schedule: entry.schedule, enrollmentId: entry.enrollmentId)
                },
                onOpenLesson: {
                    Task {
                        do {
                            let invite = try await EnrollmentActions().loadLessonInvite(scheduleId: entry.schedule.id)
                            if let url = URL(string: invite.inviteUrl) {
                                await MainActor.run {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } catch {
                            NSLog("Failed to open lesson: \(error)")
                        }
                    }
                },
                onShareLesson: {
                    let inviteURL = "\(Configuration.clientBaseURL)/join/study/\(entry.schedule.id)"
                    let shareText = "Join Day \(entry.schedule.lesson.dayNumber) of \(entry.studyName) on MakeReady: \(inviteURL)"

                    let activityVC = UIActivityViewController(
                        activityItems: [shareText],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        rootVC.present(activityVC, animated: true)
                    }
                },
                onEditEnrollment: { [self] in
                    if let enrollment = state.enrollments[entry.enrollmentId] {
                        overlayManager.presentModal(id: OverlayID.enrollmentSchedule, dismissOnTapOutside: false) {
                            EnrollmentSchedulePage(
                                enrollment: enrollment,
                                onDismiss: {
                                    overlayManager.dismiss(id: OverlayID.enrollmentSchedule)
                                },
                                leftIcon: "xmark",
                                overlayManager: overlayManager,
                                titleOverride: "Lessons"
                            )
                        }
                    }
                },
                onDelete: {
                    Task {
                        do {
                            try await EnrollmentActions().deleteLessonSchedule(
                                enrollmentId: entry.enrollmentId,
                                scheduleId: entry.schedule.id
                            )
                            await HomeActions().loadCalendarEvents(forceRefresh: true)
                        } catch {
                            NSLog("Failed to delete lesson: \(error)")
                        }
                    }
                }
            )
        }
    }

    // MARK: - Charts Section

    private var chartsSection: some View {
        VStack(spacing: 16) {
            // Bar chart: Last 7 days activity
            VStack(alignment: .leading, spacing: 16) {
                Text("Last 7 Days")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                if chartsLoaded {
                    ZStack {
                        VerticalBarChart(
                            dataPoints: weeklyActivityData.isEmpty ? emptyWeeklyData : weeklyActivityData,
                            showValues: !weeklyActivityData.isEmpty,
                            chartHeight: 160
                        )

                        if weeklyActivityData.isEmpty {
                            Text("No activity in the last 7 days")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                } else {
                    chartLoadingState
                }
            }

            // Heatmap: Activity by day/hour
            VStack(alignment: .leading, spacing: 16) {
                Text("Activity Heatmap")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                if chartsLoaded {
                    ZStack {
                        HeatMapChart(
                            dataPoints: heatmapData.isEmpty ? emptyHeatmapData : heatmapData,
                            showDayLabels: false,
                            xLabels: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                            yLabels: ["12a", "1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12p", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p"],
                            chartHeight: 576
                        )

                        if heatmapData.isEmpty {
                            Text("No lesson activity yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.2))
                        }
                    }
                } else {
                    chartLoadingState
                }
            }
        }
    }

    private var chartLoadingState: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.05))
            .frame(height: 120)
            .overlay(
                ProgressView()
                    .tint(.white.opacity(0.3))
            )
    }

    private var emptyHeatmapData: [HeatMapDataPoint] {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var points: [HeatMapDataPoint] = []
        for day in 0..<7 {
            for hour in 0..<24 {
                points.append(HeatMapDataPoint(week: day, day: hour, value: 0, dayLabel: dayLabels[day]))
            }
        }
        return points
    }

    private var emptyWeeklyData: [BarChartDataPoint] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map { day in
            BarChartDataPoint(label: day, value: 0, color: Color(hex: "#6c47ff"))
        }
    }

}

// MARK: - Previews

#Preview("Home - With Data") {
    MainHomePreviewWithData()
}

#Preview("Home - No Data") {
    MainHomePreviewEmpty()
}

// MARK: - Preview: Home with mock chart data

private struct MainHomePreviewWithData: View {
    // Mock heatmap data: 7 days × 24 hours (days on X, hours on Y)
    private var mockHeatmapData: [HeatMapDataPoint] {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var points: [HeatMapDataPoint] = []
        for day in 0..<7 {
            for hour in 0..<24 {
                let value: Double

                if hour >= 0 && hour <= 4 {
                    // Late night: mostly empty
                    value = Double.random(in: 0...1) < 0.6 ? 0 : Double.random(in: 1...50)
                } else if hour >= 5 && hour <= 7 {
                    // Early morning: high activity peak
                    value = Double.random(in: 400...1000)
                } else if hour >= 8 && hour <= 11 {
                    // Mid morning: moderate
                    value = Double.random(in: 100...500)
                } else if hour >= 12 && hour <= 14 {
                    // Lunch: dip
                    value = Double.random(in: 50...250)
                } else if hour >= 15 && hour <= 18 {
                    // Late afternoon: high activity peak
                    value = Double.random(in: 500...1000)
                } else if hour >= 19 && hour <= 21 {
                    // Evening: moderate
                    value = Double.random(in: 150...450)
                } else {
                    // Night: low
                    value = Double.random(in: 10...120)
                }
                points.append(HeatMapDataPoint(week: day, day: hour, value: value, dayLabel: dayLabels[day]))
            }
        }
        return points
    }

    // Mock bar chart: last 7 days
    private var mockBarData: [BarChartDataPoint] {
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days.map { day in
            BarChartDataPoint(label: day, value: Double.random(in: 3...28), color: Color(hex: "#6c47ff"))
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Simulated header
                HStack {
                    Spacer()
                    Text("Home")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        // KPI grid
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible())], spacing: 4) {
                            Kpi(value: 172, valueType: .number, label: "Members", icon: "person.2", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 5, valueType: .number, label: "Groups", icon: "person.3", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 84, valueType: .number, label: "Enrolled Lessons", icon: "book", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 3, valueType: .number, label: "Studies", icon: "text.book.closed", iconColor: .brandPrimary, variant: .iconValue)
                        }

                        // Upcoming lessons
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Upcoming Lessons")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            CardLesson(data: CardLessonData(
                                id: "ul1", day: 5, mode: .lesson,
                                activities: [
                                    LessonActivityData(icon: "book.fill", title: "Read"),
                                    LessonActivityData(icon: "text.cursor", title: "SOAP")
                                ],
                                title: "Romans Study",
                                date: Calendar.current.date(byAdding: .day, value: 1, to: Date())
                            ))

                            CardLesson(data: CardLessonData(
                                id: "ul2", day: 12, mode: .lesson,
                                activities: [
                                    LessonActivityData(icon: "play.fill", title: "Watch"),
                                    LessonActivityData(icon: "bubble.left.and.bubble.right.fill", title: "Discuss")
                                ],
                                title: "Sermon on the Mount",
                                date: Calendar.current.date(byAdding: .day, value: 2, to: Date())
                            ))
                        }

                        // Bar chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Last 7 Days")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            VerticalBarChart(dataPoints: mockBarData, showValues: true, chartHeight: 160)
                        }

                        // Heatmap
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Activity Heatmap")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            HeatMapChart(
                                dataPoints: mockHeatmapData,
                                showDayLabels: false,
                                xLabels: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                                yLabels: ["12a", "1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12p", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p"],
                                chartHeight: 576
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

// MARK: - Preview: Home with no data

private struct MainHomePreviewEmpty: View {
    private var emptyHeatmapData: [HeatMapDataPoint] {
        let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var points: [HeatMapDataPoint] = []
        for day in 0..<7 {
            for hour in 0..<24 {
                points.append(HeatMapDataPoint(week: day, day: hour, value: 0, dayLabel: dayLabels[day]))
            }
        }
        return points
    }

    private var emptyWeeklyData: [BarChartDataPoint] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map { day in
            BarChartDataPoint(label: day, value: 0, color: Color(hex: "#6c47ff"))
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Home")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 16) {
                        // KPI grid with zeros
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible())], spacing: 4) {
                            Kpi(value: 0, valueType: .number, label: "Members", icon: "person.2", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 0, valueType: .number, label: "Groups", icon: "person.3", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 0, valueType: .number, label: "Enrolled Lessons", icon: "book", iconColor: .brandPrimary, variant: .iconValue)
                            Kpi(value: 0, valueType: .number, label: "Studies", icon: "text.book.closed", iconColor: .brandPrimary, variant: .iconValue)
                        }

                        // Empty bar chart
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Last 7 Days")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ZStack {
                                VerticalBarChart(
                                    dataPoints: emptyWeeklyData,
                                    showValues: false,
                                    chartHeight: 160
                                )

                                Text("No activity in the last 7 days")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }

                        // Empty heatmap
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Activity Heatmap")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(0.5)

                            ZStack {
                                HeatMapChart(
                                    dataPoints: emptyHeatmapData,
                                    showDayLabels: false,
                                    xLabels: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
                                    yLabels: ["12a", "1a", "2a", "3a", "4a", "5a", "6a", "7a", "8a", "9a", "10a", "11a", "12p", "1p", "2p", "3p", "4p", "5p", "6p", "7p", "8p", "9p", "10p", "11p"],
                                    chartHeight: 576
                                )

                                Text("No lesson activity yet")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
        }
    }
}

// MARK: - Edit Activities Helpers

/// Wrapper that bridges EditEnrollmentDay's isPresented binding to OverlayManager dismissal
struct EditEnrollmentDayWrapper: View {
    let schedule: LessonSchedule
    let enrollmentId: String
    let overlayManager: OverlayManager

    @State private var isPresented = true

    var body: some View {
        EditEnrollmentDay(
            isPresented: $isPresented,
            schedule: schedule,
            enrollmentId: enrollmentId,
            onShowAddActivityMenu: { existingTypes, onSelect in
                overlayManager.present(.addActivityMenu) {
                    AddActivityMenu(overlayManager: overlayManager, existingActivityTypes: existingTypes, onActivitySelected: onSelect)
                }
            }
        )
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                overlayManager.dismiss(id: OverlayID.editEnrollmentDay)
                Task {
                    await HomeActions().loadCalendarEvents(forceRefresh: true)
                }
            }
        }
    }
}
