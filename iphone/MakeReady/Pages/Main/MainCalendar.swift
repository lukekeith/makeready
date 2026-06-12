//
//  MainCalendar.swift
//  MakeReady
//
//  Calendar/schedule tab page content
//

import SwiftUI

// MARK: - Main Calendar

struct MainCalendar: View {
    let overlayManager: OverlayManager
    let avatarURL: String?
    @State private var selectedDate: Date?

    // Centralized state
    private var state: AppState { AppState.shared }

    private var isInitialLoading: Bool {
        state.loadingStates.state(for: .calendarEvents).isInitialLoading
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            SplitMonthCalendarWithBar(
                selectedDate: $selectedDate,
                events: state.calendarEvents,
                onEventTap: { event in
                    handleLessonTap(event)
                }
            )

            if isInitialLoading {
                Color.appBackground
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
            }
        }
        .task {
            await HomeActions().loadCalendarEvents(forceRefresh: false)
        }
    }

    // MARK: - Lesson Tap

    private func presentEditEnrollmentDay(schedule: LessonSchedule, enrollmentId: String) {
        overlayManager.present(.editEnrollmentDay) {
            EditEnrollmentDayWrapper(
                schedule: schedule,
                enrollmentId: enrollmentId,
                overlayManager: overlayManager
            )
        }
    }

    private func handleLessonTap(_ event: SplitCalendarEvent) {
        guard let entry = state.lessonScheduleMap[event.id] else {
            NSLog("⚠️ MainCalendar: No schedule data for event \(event.id)")
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
                            // User just tapped "Open Lesson" — surface it.
                            await MainActor.run {
                                state.recordError(
                                    error,
                                    context: "MainCalendar.openLesson",
                                    surface: true,
                                    friendlyMessage: "Couldn't open the lesson"
                                )
                            }
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
                        overlayManager.present(.enrollmentSchedule) {
                            EnrollmentSchedulePage(
                                enrollment: enrollment,
                                onDismiss: {
                                    overlayManager.dismiss(.enrollmentSchedule)
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
                            // User just tapped Delete in the lesson menu — surface it.
                            await MainActor.run {
                                state.recordError(
                                    error,
                                    context: "MainCalendar.deleteLessonSchedule",
                                    surface: true,
                                    friendlyMessage: "Couldn't delete the lesson"
                                )
                            }
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Year Selector

struct YearSelector: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var yearRange: [Int] {
        let start = currentYear - 2
        let end = currentYear + 2
        return Array(start...end)
    }

    private func jumpToToday() {
        let today = Date()
        let calendar = Calendar.current
        withAnimation {
            selectedYear = calendar.component(.year, from: today)
            selectedMonth = calendar.component(.month, from: today)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Scrollable years
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(yearRange, id: \.self) { year in
                                Button(action: {
                                    withAnimation {
                                        selectedYear = year
                                    }
                                }) {
                                    Text(verbatim: String(year))
                                        .font(Typography.s17)
                                        .foregroundColor(year == selectedYear ? .white : .white.opacity(0.3))
                                }
                                .id(year)
                            }
                        }
                        .padding(.horizontal, geometry.size.width / 2)
                    }
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.15),
                                .init(color: .black, location: 0.85),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .onAppear {
                        proxy.scrollTo(selectedYear, anchor: .center)
                    }
                    .onChange(of: selectedYear) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }

            Spacer()

            // Today button on the right
            Button(action: jumpToToday) {
                Text("Today")
                    .font(Typography.s17)
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.trailing, 16)
        }
        .frame(height: 20)
    }
}

// MARK: - Month Selector

struct MonthSelector: View {
    @Binding var selectedMonth: Int
    let selectedYear: Int

    private let monthNames = ["January", "February", "March", "April", "May", "June",
                             "July", "August", "September", "October", "November", "December"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 32) {
                    ForEach(1...12, id: \.self) { month in
                        Button(action: {
                            withAnimation {
                                selectedMonth = month
                            }
                        }) {
                            Text(monthNames[month - 1])
                                .font(Typography.s28)
                                .foregroundColor(month == selectedMonth ? Color.brandPrimary : .white.opacity(0.3))
                        }
                        .id(month)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .center)
            }
            .onChange(of: selectedMonth) { oldValue, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Calendar Grid

struct CalendarGrid: View {
    let selectedMonth: Int
    let selectedYear: Int

    private let daysOfWeek = ["SUN", "MON", "TUES", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        VStack(spacing: 10) {
            // Days of week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(Typography.s12)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)

            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 10) {
                ForEach(calendarDays, id: \.id) { day in
                    ZStack {
                        if day.isToday {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 40, height: 40)
                        }
                        Text("\(day.day)")
                            .font(Typography.s12)
                            .foregroundColor(day.isCurrentMonth ? .white : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var calendarDays: [CalendarDay] {
        var days: [CalendarDay] = []

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: today)

        let dateComponents = DateComponents(year: selectedYear, month: selectedMonth)
        guard let date = calendar.date(from: dateComponents),
              let range = calendar.range(of: .day, in: .month, for: date),
              let firstDayOfMonth = calendar.date(from: dateComponents) else {
            return days
        }

        // Get the weekday of the first day (1 = Sunday, 7 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        // Add previous month's days
        if firstWeekday > 1 {
            let previousMonth = selectedMonth == 1 ? 12 : selectedMonth - 1
            let previousYear = selectedMonth == 1 ? selectedYear - 1 : selectedYear
            let prevDateComponents = DateComponents(year: previousYear, month: previousMonth)

            if let prevDate = calendar.date(from: prevDateComponents),
               let prevRange = calendar.range(of: .day, in: .month, for: prevDate) {
                let daysToShow = firstWeekday - 1
                let startDay = prevRange.count - daysToShow + 1

                for day in startDay...prevRange.count {
                    let isToday = day == todayComponents.day && previousMonth == todayComponents.month && previousYear == todayComponents.year
                    days.append(CalendarDay(day: day, month: previousMonth, year: previousYear, isCurrentMonth: false, isToday: isToday))
                }
            }
        }

        // Add current month's days
        for day in range {
            let isToday = day == todayComponents.day && selectedMonth == todayComponents.month && selectedYear == todayComponents.year
            days.append(CalendarDay(day: day, month: selectedMonth, year: selectedYear, isCurrentMonth: true, isToday: isToday))
        }

        // Add next month's days to fill the grid
        let remainingCells = 42 - days.count // 6 rows × 7 days
        let nextMonth = selectedMonth == 12 ? 1 : selectedMonth + 1
        let nextYear = selectedMonth == 12 ? selectedYear + 1 : selectedYear

        for day in 1...remainingCells {
            let isToday = day == todayComponents.day && nextMonth == todayComponents.month && nextYear == todayComponents.year
            days.append(CalendarDay(day: day, month: nextMonth, year: nextYear, isCurrentMonth: false, isToday: isToday))
        }

        return days
    }
}

// MARK: - Calendar Day Model

struct CalendarDay: Identifiable {
    let id = UUID()
    let day: Int
    let month: Int
    let year: Int
    let isCurrentMonth: Bool
    let isToday: Bool
}

#Preview {
    MainCalendar(
        overlayManager: OverlayManager(),
        avatarURL: nil
    )
}
