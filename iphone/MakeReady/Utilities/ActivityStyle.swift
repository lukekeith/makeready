//
//  ActivityStyle.swift
//  MakeReady
//
//  Single source of truth for activity type icons, colors, and label colors.
//  Used across CardLesson, EditDay, ProgramHomePage, CreateProgramPage,
//  EnrollmentSchedulePage, HomeActions, UpcomingLessonCard, etc.
//

import SwiftUI

// MARK: - Activity Appearance (per-status styling)

/// Complete styling for rendering an activity icon box in a given state.
/// Use `ActivityStyle.appearance(forRawType:status:)` to get the right
/// colors for any activity type + completion state combination.
struct ActivityAppearance {
    let backgroundColor: Color
    let iconColor: Color
    let borderColor: Color?
    let borderWidth: CGFloat
}

enum ActivityStyle {

    // MARK: - Appearance (single call for all icon-box colors)

    /// Returns the full icon-box appearance for a given activity type and status.
    static func appearance(for type: ActivityType, status: LessonActivityStatus) -> ActivityAppearance {
        return appearance(forRawType: type.rawValue, status: status)
    }

    /// Returns the full icon-box appearance for a raw API type string and status.
    static func appearance(forRawType type: String?, status: LessonActivityStatus) -> ActivityAppearance {
        let brandColor = color(forRawType: type)

        switch status {
        case .default:
            return ActivityAppearance(
                backgroundColor: Color.white.opacity(0.1),
                iconColor: Color.white.opacity(0.5),
                borderColor: nil,
                borderWidth: 0
            )
        case .incomplete:
            return ActivityAppearance(
                backgroundColor: Color.clear,
                iconColor: brandColor,
                borderColor: brandColor,
                borderWidth: 1.5
            )
        case .complete:
            return ActivityAppearance(
                backgroundColor: brandColor,
                iconColor: iconColor(forRawType: type),
                borderColor: nil,
                borderWidth: 0
            )
        case .percentComplete(let fraction):
            // Always-present brand border (like .incomplete), with the fill at
            // an opacity equal to the completion fraction. Clamp defensively.
            // Once anyone has completed it, the icon goes white so it stays
            // legible over the colored fill; an empty (0%) block keeps the
            // brand-colored icon.
            let clamped = min(max(fraction, 0), 1)
            return ActivityAppearance(
                backgroundColor: brandColor.opacity(clamped),
                iconColor: clamped > 0 ? Color.white : brandColor,
                borderColor: brandColor,
                borderWidth: 1.5
            )
        }
    }

    // MARK: - Icons (asset catalog SVGs)

    /// Icon asset name for an activity type (ActivityType enum).
    static func icon(for type: ActivityType) -> String {
        switch type {
        case .video:     return "IconRecordVideo"
        case .youtube:   return "IconActivityVideo"
        case .read:      return "IconActivityRead"
        case .userInput: return "IconActivityWrite"
        case .exegesis:  return "IconActivityExegesis"
        case .soap, .oia, .dbs, .hear:
                         return "IconActivityRead"
        }
    }

    /// Icon asset name for an activity type (raw string from API).
    static func icon(forRawType type: String) -> String {
        switch type {
        case "READ", "SCRIPTURE", "SOAP", "OIA", "DBS", "HEAR":
            return "IconActivityRead"
        case "VIDEO":
            return "IconRecordVideo"
        case "YOUTUBE":
            return "IconActivityVideo"
        case "USER_INPUT":
            return "IconActivityWrite"
        case "EXEGESIS":
            return "IconActivityExegesis"
        case "PRAYER":
            return "IconActivityPrayer"
        case "REFLECTION":
            return "IconActivityReflection"
        default:
            return "IconActivityRead"
        }
    }

    // MARK: - Colors

    /// Brand color for an activity type (ActivityType enum).
    static func color(for type: ActivityType) -> Color {
        switch type {
        case .read:      return Color(hex: "#6c47ff")
        case .userInput: return Color(hex: "#3b82f6")
        case .video:     return Color.white
        case .youtube:   return Color(hex: "#dc2626")
        case .exegesis:  return Color(hex: "#f59e0b")
        case .soap, .oia, .dbs, .hear:
                         return Color(hex: "#6c47ff")
        }
    }

    /// Brand color for an activity type (raw string from API).
    static func color(forRawType type: String?) -> Color {
        switch type {
        case "READ", "SCRIPTURE", "SOAP", "OIA", "DBS", "HEAR":
            return Color(hex: "#6c47ff")
        case "USER_INPUT":
            return Color(hex: "#3b82f6")
        case "VIDEO":
            return Color.white
        case "YOUTUBE":
            return Color(hex: "#dc2626")
        case "EXEGESIS":
            return Color(hex: "#f59e0b")
        case "PRAYER":
            return Color(hex: "#9333ea")
        case "REFLECTION":
            return Color(hex: "#0d9488")
        default:
            return Color(hex: "#6c47ff")
        }
    }

    // MARK: - Label Colors (text on top of activity color)

    /// Label/text color to use on top of the activity's brand color (ActivityType enum).
    static func labelColor(for type: ActivityType) -> Color {
        switch type {
        case .video: return Color.black
        default:     return Color.white
        }
    }

    /// Label/text color to use on top of the activity's brand color (raw string from API).
    static func labelColor(forRawType type: String?) -> Color {
        switch type {
        case "VIDEO": return Color.black
        default:      return Color.white
        }
    }

    // MARK: - Icon Colors (foreground tint for the icon itself)

    /// Foreground color for the activity icon (ActivityType enum).
    /// Most icons are white (rendered on colored bg). Video is red (rendered on white bg).
    static func iconColor(for type: ActivityType) -> Color {
        switch type {
        case .video: return Color(hex: "#ef4444")
        default:     return Color.white
        }
    }

    /// Foreground color for the activity icon (raw string from API).
    static func iconColor(forRawType type: String?) -> Color {
        switch type {
        case "VIDEO": return Color(hex: "#ef4444")
        default:      return Color.white
        }
    }
}
