//
//  CalendarModels.swift
//  MakeReady
//
//  Data models for the Split-Month Calendar component
//

import SwiftUI

// MARK: - Cached Date Formatters

/// Cached DateFormatters for calendar performance
/// DateFormatter creation is expensive - reuse these throughout the calendar
enum CalendarFormatters {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let monthOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    static let dateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dayHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE – MMM d"
        return formatter
    }()

    /// Day name only (e.g., "Monday")
    static let dayName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// Date without day name (e.g., "Dec 8")
    static let dayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let monthAbbrev: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// Time without period (e.g., "6:30")
    static let timeWithoutPeriod: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    /// Period only (e.g., "AM" or "PM")
    static let timePeriod: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter
    }()

    static let fullDateHeader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    static let monthYearShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    static let yearOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

// MARK: - Calendar Month

struct SplitCalendarMonth: Hashable, Identifiable {
    let year: Int
    let month: Int
    var days: [SplitCalendarDay]

    var id: String { "\(year)-\(String(format: "%02d", month))" }

    var displayName: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(year)"
        }
        return CalendarFormatters.monthYear.string(from: date)
    }

    var shortDisplayName: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else {
            return "\(month)"
        }
        return CalendarFormatters.monthOnly.string(from: date)
    }

    /// Generate a SplitCalendarMonth for a given date
    /// Only includes days from the current month - no padding from previous/next months
    static func generate(for date: Date, events: [String: [SplitCalendarEvent]] = [:]) -> SplitCalendarMonth {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        // Get first day of month
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return SplitCalendarMonth(year: year, month: month, days: [])
        }

        // Get weekday of first day (1 = Sunday, 2 = Monday, ... 7 = Saturday)
        // Convert to 0-indexed (0 = Sunday, 1 = Monday, ... 6 = Saturday)
        let firstWeekdayIndex = calendar.component(.weekday, from: firstDayOfMonth) - 1

        var days: [SplitCalendarDay] = []

        // Add ONLY current month's days - no padding from adjacent months
        for day in range {
            var dayComponents = components
            dayComponents.day = day
            let dayDate = calendar.date(from: dayComponents)!
            let dateKey = SplitCalendarDay.dateKey(for: dayDate)

            // Calculate position in grid
            // Day 1 goes in column = firstWeekdayIndex
            // Day 2 goes in column = (firstWeekdayIndex + 1) % 7, etc.
            let dayOffset = day - 1  // 0-indexed day offset
            let weekdayIndex = (firstWeekdayIndex + dayOffset) % 7
            let rowIndex = (firstWeekdayIndex + dayOffset) / 7

            days.append(SplitCalendarDay(
                date: dayDate,
                dayNumber: day,
                isCurrentMonth: true,
                weekdayIndex: weekdayIndex,
                rowIndex: rowIndex,
                events: events[dateKey] ?? []
            ))
        }

        return SplitCalendarMonth(year: year, month: month, days: days)
    }
}

// MARK: - Calendar Day

struct SplitCalendarDay: Hashable, Identifiable {
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let weekdayIndex: Int    // 0-6 for column position (0 = Sunday)
    let rowIndex: Int        // Row within month grid
    let events: [SplitCalendarEvent]

    var id: String { Self.dateKey(for: date) }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var eventCount: Int {
        events.count
    }

    static func dateKey(for date: Date) -> String {
        return CalendarFormatters.dateKey.string(from: date)
    }

    // Hashable conformance (excluding events for performance)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SplitCalendarDay, rhs: SplitCalendarDay) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Calendar Activity Icon (for persistence)

struct CalendarActivityIcon: Identifiable, Hashable, Codable {
    let id: String
    let icon: String       // Asset catalog or SF Symbol name
    let label: String      // e.g., "Read", "Watch", "Pray"
    let rawType: String?   // Raw API type for ActivityStyle lookup (e.g. "READ", "VIDEO")

    init(icon: String, label: String, rawType: String? = nil) {
        self.id = "\(icon)-\(label)"
        self.icon = icon
        self.label = label
        self.rawType = rawType
    }
}

// MARK: - Calendar Event

struct SplitCalendarEvent: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String?
    let startTime: Date
    let endTime: Date?
    let color: String        // Hex color for left indicator
    let location: String?

    // Lesson-specific fields (optional, populated for scheduled lessons)
    let dayNumber: Int?
    let coverImageUrl: String?
    let activityIcons: [CalendarActivityIcon]?
    let estimatedMinutes: Int?

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        color: String,
        location: String? = nil,
        dayNumber: Int? = nil,
        coverImageUrl: String? = nil,
        activityIcons: [CalendarActivityIcon]? = nil,
        estimatedMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.startTime = startTime
        self.endTime = endTime
        self.color = color
        self.location = location
        self.dayNumber = dayNumber
        self.coverImageUrl = coverImageUrl
        self.activityIcons = activityIcons
        self.estimatedMinutes = estimatedMinutes
    }

    var timeString: String {
        var result = CalendarFormatters.time.string(from: startTime)
        if let end = endTime {
            result += " - " + CalendarFormatters.time.string(from: end)
        }
        return result
    }

    var isAllDay: Bool {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        return startComponents.hour == 0 && startComponents.minute == 0 && endTime == nil
    }

    // Mock events for testing
    static func mockEvents() -> [String: [SplitCalendarEvent]] {
        var events: [String: [SplitCalendarEvent]] = [:]
        let calendar = Calendar.current
        let today = Date()

        // Add some mock events around today
        for dayOffset in -5...10 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let dateKey = SplitCalendarDay.dateKey(for: date)

            // Random number of events (0-3)
            let eventCount = Int.random(in: 0...3)
            if eventCount == 0 { continue }

            var dayEvents: [SplitCalendarEvent] = []
            let colors = ["#6C47FF", "#5680ff", "#57DB5D", "#F4FF76", "#FF4759"]

            for i in 0..<eventCount {
                var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
                startComponents.hour = 9 + (i * 3)
                startComponents.minute = 0

                var endComponents = startComponents
                endComponents.hour = (startComponents.hour ?? 9) + 1

                let startTime = calendar.date(from: startComponents) ?? date
                let endTime = calendar.date(from: endComponents)

                let titles = ["Team Meeting", "Lunch", "Code Review", "Standup", "Planning", "1:1", "Demo"]
                let locations = ["Conference Room A", "Zoom", "Office", nil, "Building 2"]

                dayEvents.append(SplitCalendarEvent(
                    id: "\(dateKey)-\(i)",
                    title: titles.randomElement() ?? "Event",
                    subtitle: i == 0 ? "With the team" : nil,
                    startTime: startTime,
                    endTime: endTime,
                    color: colors.randomElement() ?? "#6C47FF",
                    location: locations.randomElement() ?? nil
                ))
            }

            events[dateKey] = dayEvents
        }

        return events
    }
}

// MARK: - Month Section (for UICollectionView)

struct SplitMonthSection: Hashable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(String(format: "%02d", month))" }
}
