//
//  ActivityStyle.swift
//  MakeReady
//
//  Activity type icon asset names (UI2-shell D5: the legacy Color members left
//  with Colors.swift; HomeActions still reads the icon names).
//

import Foundation

enum ActivityStyle {

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
}
