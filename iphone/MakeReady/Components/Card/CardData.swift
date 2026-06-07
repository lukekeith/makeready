//
//  CardData.swift
//  MakeReady
//
//  Shared data models, enums, and helpers for Card components
//

import SwiftUI

// MARK: - Enums

public enum CardSize {
    case row    // Full width, horizontal layout
    case mini   // Fixed width (120px), vertical layout
}

public enum CardImageStyle: Hashable {
    case photo(imageURL: String)
    case icon(systemName: String, backgroundColor: Color?, foregroundColor: Color?)
    case dateDisplay(day: Int, month: String) // Event only - shows day number + month abbreviation
    case timeDisplay(time: String, period: String) // Event only - shows time (e.g., "6:30") + period (e.g., "PM")
    
    // Convenience factory methods for icon case
    public static func icon(systemName: String) -> CardImageStyle {
        .icon(systemName: systemName, backgroundColor: nil, foregroundColor: nil)
    }
    
    public static func icon(systemName: String, backgroundColor: Color?) -> CardImageStyle {
        .icon(systemName: systemName, backgroundColor: backgroundColor, foregroundColor: nil)
    }
    
    public static func icon(systemName: String, foregroundColor: Color?) -> CardImageStyle {
        .icon(systemName: systemName, backgroundColor: nil, foregroundColor: foregroundColor)
    }
}

public enum CardStatus: Hashable {
    case confirmed
    case pending      // Study only
    case new          // Study only
    case selected     // Group only
}

// MARK: - Data Models

public struct CardStudyData: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String?
    public let type: String?
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let status: CardStatus?
    public let onTap: (() -> Void)?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        type: String? = nil,
        imageStyle: CardImageStyle,
        metadata: [DataItem] = [],
        status: CardStatus? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = CardStudyData.stripHTML(title)
        self.description = description.map { CardStudyData.stripHTML($0) }
        self.type = type
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.status = status
        self.onTap = onTap
    }

    /// Strip HTML tags and decode common entities from text
    private static func stripHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: " ")
        result = result.replacingOccurrences(of: "</div>", with: " ")
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func == (lhs: CardStudyData, rhs: CardStudyData) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.description == rhs.description &&
               lhs.type == rhs.type &&
               lhs.imageStyle == rhs.imageStyle &&
               lhs.metadata == rhs.metadata &&
               lhs.status == rhs.status
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(description)
        hasher.combine(type)
        hasher.combine(imageStyle)
        hasher.combine(metadata)
        hasher.combine(status)
    }
}

public struct CardEventData {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let status: CardStatus?
    public let onTap: (() -> Void)?
}

public struct CardGroupData {
    public let id: String
    public let title: String
    /// Optional secondary line shown directly beneath the title (e.g. the
    /// group leader's name). Hidden when nil.
    public let subtitle: String?
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let isSelected: Bool
    /// When > 0, the avatar shows an iOS app-icon-style red badge with this
    /// count rendered in white. Used today to surface pending member-request
    /// counts. Defaults to 0 so existing call sites keep their rendering.
    public let pendingRequestCount: Int
    public let onTap: (() -> Void)?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        imageStyle: CardImageStyle,
        metadata: [DataItem] = [],
        isSelected: Bool = false,
        pendingRequestCount: Int = 0,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.isSelected = isSelected
        self.pendingRequestCount = pendingRequestCount
        self.onTap = onTap
    }
}

public struct CardVideoData {
    public let id: String
    public let title: String
    public let description: String?
    public let imageStyle: CardImageStyle
    public let metadata: [DataItem]
    public let status: CardStatus?
    public let onTap: (() -> Void)?

    public init(
        id: String,
        title: String,
        description: String? = nil,
        imageStyle: CardImageStyle,
        metadata: [DataItem] = [],
        status: CardStatus? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.imageStyle = imageStyle
        self.metadata = metadata
        self.status = status
        self.onTap = onTap
    }
}

public struct CardMemberData {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let avatarURL: String?
    public let metadata: [DataItem]
    public let groups: [String]
    public let onTap: (() -> Void)?
    public let onInviteTap: (() -> Void)?

    public var fullName: String { "\(firstName) \(lastName)" }

    public init(
        id: String,
        firstName: String,
        lastName: String,
        avatarURL: String? = nil,
        metadata: [DataItem] = [],
        groups: [String] = [],
        onTap: (() -> Void)? = nil,
        onInviteTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarURL = avatarURL
        self.metadata = metadata
        self.groups = groups
        self.onTap = onTap
        self.onInviteTap = onInviteTap
    }
}

public struct CardContactData {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let avatarURL: String?
    public let imageData: Data?
    public let onTap: (() -> Void)?
    public let onInviteTap: (() -> Void)?

    public var fullName: String { "\(firstName) \(lastName)" }

    public init(
        id: String,
        firstName: String,
        lastName: String,
        avatarURL: String? = nil,
        imageData: Data? = nil,
        onTap: (() -> Void)? = nil,
        onInviteTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.avatarURL = avatarURL
        self.imageData = imageData
        self.onTap = onTap
        self.onInviteTap = onInviteTap
    }
}

public struct CardEnrolledData: Identifiable {
    public let id: String
    public let studyTitle: String
    public let groupName: String
    public let startDate: Date
    public let endDate: Date
    public let lessonsLeft: Int?
    public let studyImageURL: String?
    public let groupImageURL: String?
    public let onTap: (() -> Void)?

    public init(
        id: String,
        studyTitle: String,
        groupName: String,
        startDate: Date,
        endDate: Date,
        lessonsLeft: Int? = nil,
        studyImageURL: String? = nil,
        groupImageURL: String? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.studyTitle = studyTitle
        self.groupName = groupName
        self.startDate = startDate
        self.endDate = endDate
        self.lessonsLeft = lessonsLeft
        self.studyImageURL = studyImageURL
        self.groupImageURL = groupImageURL
        self.onTap = onTap
    }
}

// MARK: - Lesson Enums

public enum CardLessonMode {
    case planning     // Current behavior (activity config, chevron)
    case lesson       // Title + full date + activity icon boxes
    case progress     // Title + description + progress bar + sections
    case lessonList   // Status badge + title (complete/next/upcoming)
}

public enum CardLessonStatus {
    case complete
    case next
    case upcoming(String)  // Custom text like "Thursday"
}

// MARK: - Section Progress

public struct SectionProgress: Identifiable {
    public let id = UUID()
    public let name: String
    public let completedAt: Date?

    public init(name: String, completedAt: Date? = nil) {
        self.name = name
        self.completedAt = completedAt
    }
}

public enum LessonActivityStatus {
    case `default`
    case incomplete
    case complete
    /// Group-completion fill: brand-colored border always shown, with the fill
    /// at an opacity equal to the fraction (0…1) of members who completed the
    /// activity. 0 reads as an empty outlined block. Used on enrollment cards.
    case percentComplete(Double)
}

public struct LessonActivityData: Identifiable {
    public let id = UUID()
    public let icon: String       // SF Symbol name
    public let type: String?      // Activity type (e.g., "SOAP", "Video")
    public let title: String      // Activity title (e.g., "Romans 1:1-2", "3:00")
    public let label: String?     // Optional label for select style
    public let isConfigured: Bool // Whether this activity has content assigned (passage for study, video for video)
    public let isLoading: Bool    // Whether this activity is currently processing (clear, upload, etc.)
    public let status: LessonActivityStatus
    public let size: CGFloat      // Width and height of the icon box

    public init(
        icon: String,
        type: String? = nil,
        title: String,
        label: String? = nil,
        isConfigured: Bool = true,
        isLoading: Bool = false,
        status: LessonActivityStatus = .default,
        size: CGFloat = 32
    ) {
        self.icon = icon
        self.type = type
        self.title = title
        self.label = label
        self.isConfigured = isConfigured
        self.isLoading = isLoading
        self.status = status
        self.size = size
    }

    /// Returns the appropriate Image view for this activity's icon.
    /// Asset catalog names (e.g. "IconActivityRead") use `Image(_:)`,
    /// SF Symbol names (e.g. "book.fill") use `Image(systemName:)`.
    public func iconImage(size iconSize: CGFloat) -> some View {
        Group {
            if icon.hasPrefix("Icon") {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
            }
        }
    }
}

public struct CardLessonData {
    public let id: String
    public let day: Int
    public let mode: CardLessonMode
    public let activities: [LessonActivityData]
    public let title: String?
    public let description: String?
    public let date: Date?
    public let progress: Double?
    public let sections: [SectionProgress]?
    public let status: CardLessonStatus?
    public let coverImageUrl: String?
    public let estimatedMinutes: Int?
    /// Whether the lesson has been released (its date is today or in the past).
    /// In `.lesson` mode this drives the card background: released → brand
    /// (purple), otherwise the neutral default. Defaults to false.
    public let isReleased: Bool
    public let onTap: (() -> Void)?

    // Backward-compatible init (defaults to .planning mode)
    public init(
        id: String,
        day: Int,
        activities: [LessonActivityData] = [],
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.day = day
        self.mode = .planning
        self.activities = activities
        self.title = nil
        self.description = nil
        self.date = nil
        self.progress = nil
        self.sections = nil
        self.status = nil
        self.coverImageUrl = nil
        self.estimatedMinutes = nil
        self.isReleased = false
        self.onTap = onTap
    }

    // Full init with all fields
    public init(
        id: String,
        day: Int,
        mode: CardLessonMode = .planning,
        activities: [LessonActivityData] = [],
        title: String? = nil,
        description: String? = nil,
        date: Date? = nil,
        progress: Double? = nil,
        sections: [SectionProgress]? = nil,
        status: CardLessonStatus? = nil,
        coverImageUrl: String? = nil,
        estimatedMinutes: Int? = nil,
        isReleased: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.day = day
        self.mode = mode
        self.activities = activities
        self.title = title
        self.description = description
        self.date = date
        self.progress = progress
        self.sections = sections
        self.status = status
        self.coverImageUrl = coverImageUrl
        self.estimatedMinutes = estimatedMinutes
        self.isReleased = isReleased
        self.onTap = onTap
    }
}

public struct CardVerseData: Identifiable {
    public let id: String
    public let passage: String           // e.g., "Ephesians 2:8-9"
    public let text: String              // The verse content
    public let timeAgo: String?          // e.g., "2 weeks ago" (optional)
    public let groupName: String?        // e.g., "Bible & Coffee" (optional)
    public let showArrow: Bool           // Whether to show chevron
    public let onTap: (() -> Void)?

    public init(
        id: String,
        passage: String,
        text: String,
        timeAgo: String? = nil,
        groupName: String? = nil,
        showArrow: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.id = id
        self.passage = passage
        self.text = text
        self.timeAgo = timeAgo
        self.groupName = groupName
        self.showArrow = showArrow
        self.onTap = onTap
    }
}

public enum DataItemType: Hashable {
    case icon       // Icon + value
    case number     // Number + label
    case labelValue // Label + value (label 50% white, value 70% white, 11px)
    case badge      // Small capsule badge (e.g., Published/Draft)
    case loading    // Skeleton shimmer placeholder
}

public struct DataItem: Identifiable, Hashable {
    // ID is computed from content to ensure stability during animations
    // Using UUID() causes SwiftUI to think items are new on each render, causing "snap" effects
    public var id: String {
        "\(type)-\(iconName ?? "")-\(value)-\(label ?? "")-\(isPurple)-\(badgeColor?.description ?? "")"
    }
    public let type: DataItemType
    public let value: String
    public let label: String?           // For number type
    public let iconName: String?        // For icon type
    public let isPurple: Bool           // Use purple color for icon and value
    public let badgeColor: Color?       // Background color for badge type
    public let badgeTextColor: Color?   // Text color for badge type
    public let loadingWidth: CGFloat    // Width for loading skeleton

    // Convenience initializer for icon type
    public init(icon: String, value: String, isPurple: Bool = false) {
        self.type = .icon
        self.value = value
        self.label = nil
        self.iconName = icon
        self.isPurple = isPurple
        self.badgeColor = nil
        self.badgeTextColor = nil
        self.loadingWidth = 0
    }

    // Convenience initializer for number type
    public init(number: String, label: String, isPurple: Bool = false) {
        self.type = .number
        self.value = number
        self.label = label
        self.iconName = nil
        self.isPurple = isPurple
        self.badgeColor = nil
        self.badgeTextColor = nil
        self.loadingWidth = 0
    }

    // Convenience initializer for labelValue type (label 50% white, value 70% white, 11px)
    public init(label: String, value: String) {
        self.type = .labelValue
        self.value = value
        self.label = label
        self.iconName = nil
        self.isPurple = false
        self.badgeColor = nil
        self.badgeTextColor = nil
        self.loadingWidth = 0
    }

    // Convenience initializer for badge type (small capsule)
    // color: background color (defaults to dark gray), textColor: text color (defaults to white)
    public init(badge value: String, color: Color? = nil, textColor: Color? = nil) {
        self.type = .badge
        self.value = value
        self.label = nil
        self.iconName = nil
        self.isPurple = false
        self.badgeColor = color
        self.badgeTextColor = textColor
        self.loadingWidth = 0
    }

    // Convenience initializer for loading skeleton type
    public init(loading width: CGFloat = 80) {
        self.type = .loading
        self.value = ""
        self.label = nil
        self.iconName = nil
        self.isPurple = false
        self.badgeColor = nil
        self.badgeTextColor = nil
        self.loadingWidth = width
    }

    public static func == (lhs: DataItem, rhs: DataItem) -> Bool {
        return lhs.type == rhs.type &&
               lhs.value == rhs.value &&
               lhs.label == rhs.label &&
               lhs.iconName == rhs.iconName &&
               lhs.isPurple == rhs.isPurple &&
               lhs.badgeColor == rhs.badgeColor &&
               lhs.badgeTextColor == rhs.badgeTextColor &&
               lhs.loadingWidth == rhs.loadingWidth
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(value)
        hasher.combine(label)
        hasher.combine(iconName)
        hasher.combine(isPurple)
        hasher.combine(loadingWidth)
    }
}

// MARK: - Shape Helpers

struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Shared View Helpers

struct CardLoadingPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .cornerRadius(8)
    }
}

// Color extensions moved to Colors.swift
