//
//  MainView.swift
//  MakeReady
//
//  Main view that manages navigation between pages
//

import SwiftUI

enum MainTab {
    case home
    case schedule
    case members
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentTab: MainTab = .home
    @State private var showUserMenu = false
    @State private var showAddMenu = false
    @State private var showHamburgerMenu = false
    @State private var showProfilePage = false
    @State private var showComponentsPage = false

    var body: some View {
        ZStack {
            // Current page content
            Group {
                switch currentTab {
                case .home:
                    HomePageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                case .schedule:
                    SchedulePageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                case .members:
                    MembersPageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                }
            }

            // Bottom navbar
            VStack {
                Spacer()
                NavBar(
                    showUserMenu: $showUserMenu,
                    showAddMenu: $showAddMenu,
                    showHamburgerMenu: $showHamburgerMenu,
                    onHomeTap: { currentTab = .home },
                    onScheduleTap: { currentTab = .schedule },
                    onMembersTap: { currentTab = .members }
                )
            }

            // User menu overlay
            if showUserMenu {
                UserMenu(
                    isPresented: $showUserMenu,
                    showProfilePage: $showProfilePage
                )
            }

            // Add menu overlay
            if showAddMenu {
                AddMenu(isPresented: $showAddMenu)
            }

            // Hamburger menu overlay
            if showHamburgerMenu {
                HamburgerMenu(
                    isPresented: $showHamburgerMenu,
                    showComponentsPage: $showComponentsPage
                )
            }
        }
        .sheet(isPresented: $showProfilePage) {
            ProfilePage()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showComponentsPage) {
            ComponentsPage()
        }
    }
}

// MARK: - Page Content Components

struct HomePageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Home"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showUserMenu = true
                        }
                    }
                )

                Spacer()
            }
        }
    }
}

struct SchedulePageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Schedule"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showUserMenu = true
                        }
                    }
                )

                // Calendar content
                VStack(spacing: 0) {
                    // Year selector
                    YearSelector(
                        selectedYear: $selectedYear,
                        selectedMonth: $selectedMonth
                    )
                    .padding(.bottom, 8)

                    // Month selector
                    MonthSelector(selectedMonth: $selectedMonth, selectedYear: selectedYear)
                    .padding(.bottom, 16)

                    // Calendar grid
                    CalendarGrid(selectedMonth: selectedMonth, selectedYear: selectedYear)

                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }
}

struct MembersPageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Members", "Groups"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showUserMenu = true
                        }
                    }
                )

                // Content area
                TabView(selection: $activeTab) {
                    // Members tab content
                    VStack {
                        Spacer()
                        Text("Members Content")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .tag(0)

                    // Groups tab content
                    VStack {
                        Spacer()
                        Text("Groups Content")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
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
                                        .font(.system(size: 17, weight: .regular))
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
                    .onChange(of: selectedYear) { newYear in
                        withAnimation {
                            proxy.scrollTo(newYear, anchor: .center)
                        }
                    }
                }
            }

            Spacer()

            // Today button on the right
            Button(action: jumpToToday) {
                Text("Today")
                    .font(.system(size: 17, weight: .regular))
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
                                .font(.system(size: 28, weight: .regular))
                                .foregroundColor(month == selectedMonth ? Color(hex: "#6c47ff") : .white.opacity(0.3))
                        }
                        .id(month)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .center)
            }
            .onChange(of: selectedMonth) { newMonth in
                withAnimation {
                    proxy.scrollTo(newMonth, anchor: .center)
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
                        .font(.system(size: 12, weight: .regular))
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
                            .font(.system(size: 12, weight: .regular))
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
    MainView()
}
