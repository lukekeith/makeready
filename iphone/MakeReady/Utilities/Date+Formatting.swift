//
//  Date+Formatting.swift
//  MakeReady
//
//  Cached DateFormatter instances for the SwiftUI render path.
//
//  DateFormatter creation is expensive (~ms each); constructing one inside a
//  view body, computed property, or per-row helper re-allocates it on every
//  render. These cached instances are created once and reused.
//
//  ⚠️ THREAD SAFETY: DateFormatter is NOT thread-safe. These shared instances
//  are intended for MAIN-THREAD-ONLY use (the SwiftUI/UIKit render path in
//  Pages/ and Components/). Do not use them from background threads, Actions,
//  or Services — those sites keep their own local formatters on purpose.
//
//  Each formatter's configuration is copied verbatim from the call sites it
//  replaced. Do not add locale/timeZone settings to formatters that did not
//  originally set them — that would change rendered output.
//

import Foundation

/// Cached, main-thread-only DateFormatters. One static instance per unique configuration.
enum DateFormatters {

    // MARK: - dateFormat-based (system locale)

    /// "MMM d" → e.g. "Jun 30"
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// "MMM d, yyyy" → e.g. "Jun 30, 2026"
    static let monthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    /// "MMM dd, yyyy" → e.g. "Jun 05, 2026" (zero-padded day)
    static let monthPaddedDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        return formatter
    }()

    /// "MMM yyyy" → e.g. "Jun 2026"
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    /// "MMMM d, yyyy" → e.g. "June 30, 2026"
    static let fullMonthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    /// "MMMM, d, yyyy" → e.g. "June, 30, 2026" (comma after month — verbatim from VideoLibraryGrid)
    static let fullMonthCommaDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM, d, yyyy"
        return formatter
    }()

    /// "EEEE, MMM d, yyyy" → e.g. "Tuesday, Jun 30, 2026"
    static let weekdayMonthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()

    /// "EEEE MMMM d - h:mma" → e.g. "Tuesday June 30 - 7:30PM"
    static let weekdayFullMonthDayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE MMMM d - h:mma"
        return formatter
    }()

    /// "d" → e.g. "30" (day of month)
    static let dayOfMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    /// "MMM" → e.g. "Jun" (month abbreviation)
    static let monthAbbrev: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    /// "EEE" → e.g. "Tue" (weekday abbreviation)
    static let weekdayAbbrev: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    /// "yyyy-MM-dd" → e.g. "2026-06-30" (calendar event date keys)
    static let dateKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "h:mm a" → e.g. "7:30 AM"
    static let time12Hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// "HH:mm" → e.g. "07:30" (24-hour, for API payloads)
    static let time24Hour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // MARK: - Style-based (system locale)

    /// timeStyle = .short → e.g. "7:30 AM" (dateStyle stays default .none)
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// dateStyle = .medium → e.g. "Jun 30, 2026" (timeStyle stays default .none)
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    /// dateStyle = .medium, timeStyle = .short → e.g. "Jun 30, 2026 at 7:30 AM"
    static let mediumDateShortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Chart axis formatters (en_US_POSIX locale — from LineChart.TimeScale)

    /// "ha" with en_US_POSIX → e.g. "7PM" (lowercased at the call site)
    static let chartHourPOSIX: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ha"
        return formatter
    }()

    /// "EEE" with en_US_POSIX → e.g. "Tue"
    static let chartWeekdayPOSIX: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    /// "MMM" with en_US_POSIX → e.g. "Jun"
    static let chartMonthPOSIX: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    /// "yyyy" with en_US_POSIX → e.g. "2026"
    static let chartYearPOSIX: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}
