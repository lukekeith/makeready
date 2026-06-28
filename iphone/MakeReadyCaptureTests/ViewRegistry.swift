//
//  ViewRegistry.swift
//  MakeReadyCaptureTests
//
//  Maps fixture "view" keys to SwiftUI views.
//  Add new cases here as you add capture fixtures for more screens.
//

import SwiftUI
@testable import MakeReady

enum ViewRegistryError: Error {
    case unknownView(String)
}

// MARK: - Shared decoders for component.* card fixtures

/// Maps a small set of named colors used in component previews. Avoids
/// `Color(hex:)` (which the SwiftLint gate reserves for Colors.swift); unknown
/// names fall back to the component's own default.
func namedCaptureColor(_ name: String?) -> Color? {
    switch name?.lowercased() {
    case "purple": return Color.brandPrimary  // app shadows Color.purple → use the brand token
    case "green": return Color.green
    case "orange": return Color.orange
    case "blue": return Color.blue
    case "red": return Color.red
    default: return nil
    }
}

/// Builds a `CardImageStyle` from a fixture's loose image-style block.
func makeCaptureImageStyle(_ s: CaptureImageStyle?, defaultIcon: String) -> CardImageStyle {
    guard let s else { return .icon(systemName: defaultIcon) }
    switch s.kind {
    case "photo":
        return .photo(imageURL: s.url ?? "")
    case "dateDisplay":
        return .dateDisplay(day: s.day ?? 1, month: s.month ?? "")
    case "timeDisplay":
        return .timeDisplay(time: s.time ?? "", period: s.period ?? "")
    default:
        return .icon(systemName: s.systemName ?? defaultIcon,
                     backgroundColor: namedCaptureColor(s.background),
                     foregroundColor: namedCaptureColor(s.foreground))
    }
}

/// Builds `[DataItem]` metadata chips. The first non-nil of
/// (badge, number, label+value, icon+value) picks the flavor.
func makeCaptureDataItems(_ raw: [CaptureDataItem]?) -> [DataItem] {
    (raw ?? []).map { d in
        if let badge = d.badge { return DataItem(badge: badge) }
        if let number = d.number { return DataItem(number: number, label: d.label ?? "") }
        if let icon = d.icon { return DataItem(icon: icon, value: d.value ?? "", isPurple: d.isPurple ?? false) }
        if let label = d.label { return DataItem(label: label, value: d.value ?? "") }
        return DataItem(icon: "circle", value: d.value ?? "")
    }
}

/// Maps a fixture status string to CardStatus (nil when absent/unknown).
func makeCaptureStatus(_ s: String?) -> CardStatus? {
    switch s {
    case "pending": return .pending
    case "new": return .new
    case "selected": return .selected
    case "confirmed": return .confirmed
    default: return nil
    }
}

// Deterministic date parsing for fixtures — captures must never depend on "now".
private let captureISODateFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
private let captureYMDDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// Parses an ISO8601 or `yyyy-MM-dd` fixture string to a Date (nil if absent/invalid).
func makeCaptureDateOptional(_ s: String?) -> Date? {
    guard let s else { return nil }
    return captureISODateFormatter.date(from: s) ?? captureYMDDateFormatter.date(from: s)
}

/// Non-optional variant — falls back to a fixed epoch so layout stays deterministic.
func makeCaptureDate(_ s: String?) -> Date {
    makeCaptureDateOptional(s) ?? Date(timeIntervalSince1970: 0)
}

/// Builds the SwiftUI view for a given fixture, wrapping it with
/// the required environment objects (AuthManager, OverlayManager).
@MainActor
func buildCaptureView(for fixture: CaptureFixture) throws -> AnyView {
    let authManager = makeMockAuthManager(from: fixture.auth)

    switch fixture.view {
    case "component.card-study":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.card-study: missing state.component")
        }
        let status: CardStatus = {
            switch c.status {
            case "pending": return .pending
            case "new": return .new
            default: return .confirmed
            }
        }()
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: c.iconSystemName ?? "book.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = makeCaptureDataItems(c.metadata)
        let data = CardStudyData(
            id: "capture-card-study",
            title: c.title ?? "",
            description: c.description,
            type: c.type,
            imageStyle: imageStyle,
            metadata: metadata,
            status: status,
            onTap: nil
        )
        return AnyView(CardStudy(data: data).padding(16))

    case "component.GroupCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupCard: missing state.component")
        }
        let imageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: "person.2.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let metadata = makeCaptureDataItems(c.metadata)
        let data = CardGroupData(
            id: "capture-group-card",
            title: c.title ?? "",
            imageStyle: imageStyle,
            metadata: metadata,
            isSelected: c.selected ?? false
        )
        if (c.size ?? "Row") == "Mini" {
            return AnyView(CardGroupMini(data: data).padding(16))
        }
        return AnyView(CardGroup(data: data).padding(16))

    case "component.CardEvent":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEvent: missing state.component")
        }
        let data = CardEventData(
            id: "capture-card-event",
            title: c.title ?? "",
            subtitle: c.subtitle,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "calendar"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardEvent(data: data).padding(16))

    case "pages.login":
        return AnyView(
            LoginView()
                .environment(authManager)
        )

    case "pages.home":
        return AnyView(
            MainView()
                .environment(authManager)
        )

    case "pages.group-home":
        // Group is seeded into AppState by setupCaptureState; GroupHomePage.init
        // reads AppState.groups[groupId] for an immediate (non-loading) first paint.
        let groupId = fixture.state?.groupId
            ?? fixture.state?.groups?.first?.id
            ?? "group-1"
        return AnyView(
            GroupHomePage(
                overlayManager: OverlayManager(),
                groupId: groupId,
                onDismiss: {}
            )
            .environment(authManager)
        )

    case "pages.create-program":
        return AnyView(
            CreateProgramPage(overlayManager: OverlayManager())
                .environment(authManager)
        )

    case "pages.edit-read-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let lessonId = fixture.state?.lessonId ?? "capture-lesson-0"
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-read-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditReadActivityPage(
                activity: activity,
                lessonId: lessonId,
                programId: programId,
                onCancel: {},
                onSave: { _ in }
            )
            .environment(OverlayManager())
            .environment(authManager)
        )

    case "pages.edit-exegesis-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-exegesis-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditExegesisActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: {}
            )
            .environment(OverlayManager())
            .environment(authManager)
        )

    case "pages.program-home":
        let programId = fixture.state?.programId ?? "capture-prog-0"
        var coverImage: UIImage? = nil
        if let imagePath = fixture.state?.programCoverImagePath {
            let fullPath = (CaptureFixtureLoader.captureRootPath() as NSString).appendingPathComponent(imagePath)
            coverImage = UIImage(contentsOfFile: fullPath)
        }
        return AnyView(
            ProgramHomePage(
                overlayManager: OverlayManager(),
                programId: programId,
                onShowAddActivityMenu: nil,
                initialCoverImage: coverImage
            )
            .environment(authManager)
        )

    case "pages.video-activity-picker":
        return AnyView(
            VideoActivityPicker(
                onDismiss: {},
                onVideoSelected: { _ in }
            )
            .environment(authManager)
        )

    case "pages.edit-youtube-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-youtube-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditYouTubeActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _ in }
            )
            .environment(authManager)
        )

    case "pages.edit-user-input-activity":
        let activityId = fixture.state?.activity?.id ?? ""
        let programId = fixture.state?.programId ?? "capture-prog-0"
        guard let activity = AppState.shared.activities[activityId] else {
            throw ViewRegistryError.unknownView("pages.edit-user-input-activity: activity '\(activityId)' not in AppState")
        }
        return AnyView(
            EditUserInputActivityPage(
                activity: activity,
                programId: programId,
                onCancel: {},
                onSave: { _, _, _, _, _ in }
            )
            .environment(authManager)
        )

    case "component.CardVideo":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardVideo: missing state.component")
        }
        let data = CardVideoData(
            id: "capture-card-video",
            title: c.title ?? "",
            description: c.description,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "play.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardVideo(data: data).padding(16))

    case "component.CardVideoMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardVideoMini: missing state.component")
        }
        let data = CardVideoData(
            id: "capture-card-video-mini",
            title: c.title ?? "",
            description: c.description,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "play.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardVideoMini(data: data).padding(16))

    case "component.CardStudyMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardStudyMini: missing state.component")
        }
        let data = CardStudyData(
            id: "capture-card-study-mini",
            title: c.title ?? "",
            description: c.description,
            type: c.type,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "book.fill"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardStudyMini(data: data).padding(16))

    case "component.CardStudySelectable":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardStudySelectable: missing state.component")
        }
        let data = CardStudySelectableData(
            id: "capture-card-study-selectable",
            title: c.title ?? "",
            description: c.description,
            lessonCount: c.count ?? 0,
            imageURL: c.imageUrl,
            isSelected: c.selected ?? false,
            isPublished: c.isPublished ?? true,
            enrolledUntilDate: nil,
            isDisabled: false
        )
        return AnyView(CardStudySelectable(data: data).padding(16))

    case "component.CardEventMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEventMini: missing state.component")
        }
        let data = CardEventData(
            id: "capture-card-event-mini",
            title: c.title ?? "",
            subtitle: c.subtitle,
            imageStyle: makeCaptureImageStyle(c.imageStyle, defaultIcon: "calendar"),
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            onTap: nil
        )
        return AnyView(CardEventMini(data: data).padding(16))

    case "component.CardMember":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardMember: missing state.component")
        }
        let data = CardMemberData(
            id: "capture-card-member",
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl,
            metadata: makeCaptureDataItems(c.metadata),
            groups: c.groups ?? []
        )
        if c.variant == "invite" {
            return AnyView(
                CardMember(data: data) {
                    ActionButton(label: "Invite", variant: .purple) {}
                }
                .padding(16)
            )
        }
        return AnyView(CardMember(data: data).padding(16))

    case "component.CardContact":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardContact: missing state.component")
        }
        let data = CardContactData(
            id: "capture-card-contact",
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl
        )
        if c.variant == "invite" {
            return AnyView(
                CardContact(data: data) {
                    ActionButton(label: "Invite", variant: .purple) {}
                }
                .padding(16)
            )
        }
        return AnyView(CardContact(data: data).padding(16))

    case "component.CardActivityType":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardActivityType: missing state.component")
        }
        let catMode: CardActivityTypeMode = (c.mode == "grid") ? .grid : .list
        let catImage: CardActivityTypeImage = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(url: cover)
            }
            return .icon(
                systemName: c.imageStyle?.systemName ?? "book.fill",
                backgroundColor: namedCaptureColor(c.imageStyle?.background) ?? Color.brandPrimary
            )
        }()
        let catCard = CardActivityType(
            title: c.title ?? "",
            description: c.description,
            image: catImage,
            mode: catMode,
            available: c.available ?? true,
            onTap: {}
        )
        if catMode == .grid {
            return AnyView(catCard.frame(width: 120).padding(16))
        }
        return AnyView(catCard.padding(16))

    case "component.CardActivity":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardActivity: missing state.component")
        }
        let entry = ActivityLogEntry(
            id: "capture-card-activity",
            category: c.category ?? "AUTH",
            activityType: "",
            status: c.status ?? "SUCCESS",
            message: c.text ?? "",
            userId: nil, memberId: nil, groupId: nil, eventId: nil,
            enrollmentId: nil, organizationId: nil, metadata: nil,
            createdAt: c.createdAt ?? "2026-01-30T12:00:00Z"
        )
        return AnyView(CardActivity(entry: entry).padding(16))

    case "component.CardLessonActivity":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardLessonActivity: missing state.component")
        }
        let rawType = c.type ?? "READ"
        let isVideoActivity = rawType == "VIDEO" || rawType == "YOUTUBE"
        let isNewActivity = c.status == "new"
        let laImageStyle: CardImageStyle = {
            if let s = c.imageStyle, s.kind == "photo" {
                return .photo(imageURL: s.url ?? "")
            }
            return .icon(
                systemName: ActivityStyle.icon(forRawType: rawType),
                backgroundColor: isNewActivity ? nil : ActivityStyle.color(forRawType: rawType),
                foregroundColor: isNewActivity ? ActivityStyle.color(forRawType: rawType)
                                               : ActivityStyle.iconColor(forRawType: rawType)
            )
        }()
        let laData = CardLessonActivityData(
            id: "capture-card-lesson-activity",
            title: c.title ?? "",
            description: c.description,
            type: rawType,
            rawActivityType: rawType,
            imageStyle: laImageStyle,
            metadata: makeCaptureDataItems(c.metadata),
            status: makeCaptureStatus(c.status),
            isVideo: isVideoActivity,
            estimatedMinutes: c.estimatedMinutes
        )
        let laSize: CardLessonActivitySize = (c.size == "small") ? .small : .default
        return AnyView(
            CardLessonActivity(data: laData, size: laSize, showAnimatedBorder: isNewActivity)
                .padding(16)
        )

    case "component.CardLesson":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardLesson: missing state.component")
        }
        func mapLessonActivityStatus(_ s: String?) -> LessonActivityStatus {
            switch s {
            case "complete": return .complete
            case "incomplete": return .incomplete
            case let v? where v.hasPrefix("percent:"):
                return .percentComplete(Double(v.dropFirst("percent:".count)) ?? 0)
            default: return .default
            }
        }
        func mapLessonActivities(_ raw: [CaptureLessonActivity]?) -> [LessonActivityData] {
            (raw ?? []).map { a in
                let type = a.type ?? "READ"
                // Lesson-mode activities omit `icon` and derive it from `type`;
                // planning-mode activities ship an explicit SF Symbol name.
                let icon = a.icon.flatMap { $0.isEmpty ? nil : $0 } ?? ActivityStyle.icon(forRawType: type)
                return LessonActivityData(
                    icon: icon,
                    type: type,
                    title: a.title ?? "",
                    label: a.title,
                    isConfigured: a.isConfigured ?? true,
                    status: mapLessonActivityStatus(a.status)
                )
            }
        }
        let lessonMode: CardLessonMode = {
            switch c.mode {
            case "lesson": return .lesson
            case "progress": return .progress
            case "lessonList": return .lessonList
            default: return .planning
            }
        }()
        let lessonStatus: CardLessonStatus? = {
            guard let s = c.lessonStatus else { return nil }
            if s == "complete" { return .complete }
            if s == "next" { return .next }
            if s.hasPrefix("upcoming:") { return .upcoming(String(s.dropFirst("upcoming:".count))) }
            return nil
        }()
        let lessonSections: [SectionProgress]? = c.sections.map { secs in
            secs.map { SectionProgress(
                name: $0.name,
                completedAt: ($0.completed ?? false) ? Date(timeIntervalSince1970: 1_769_000_000) : nil
            ) }
        }
        let lessonData = CardLessonData(
            id: "capture-card-lesson",
            day: c.day ?? 1,
            mode: lessonMode,
            activities: mapLessonActivities(c.activities),
            title: c.title,
            description: c.description,
            date: makeCaptureDateOptional(c.date),
            progress: c.progress,
            sections: lessonSections,
            status: lessonStatus,
            coverImageUrl: c.coverUrl,
            estimatedMinutes: c.estimatedMinutes,
            isReleased: c.isReleased ?? false
        )
        return AnyView(CardLesson(data: lessonData).padding(16))

    case "component.ScheduledLessonCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ScheduledLessonCard: missing state.component")
        }
        let schedActivities: [ScheduledActivity] = (c.activities ?? []).enumerated().map { idx, a in
            let title = (a.title?.isEmpty == false) ? a.title : nil
            return ScheduledActivity(
                id: "capture-sched-act-\(idx)",
                lessonId: "capture-sched-lesson",
                type: a.type ?? "SCRIPTURE",
                title: title,
                passageReference: title,
                orderNumber: idx + 1
            )
        }
        let day: TimeInterval = 24 * 60 * 60
        let scheduledDate: Date
        let explicitCompleted: Bool?
        switch c.status {
        case "completed":
            scheduledDate = Date().addingTimeInterval(-7 * day)
            explicitCompleted = true
        case "today":
            scheduledDate = Date()
            explicitCompleted = nil
        default:
            scheduledDate = Date().addingTimeInterval(7 * day)
            explicitCompleted = nil
        }
        let schedule = LessonSchedule(
            id: "capture-schedule",
            enrollmentId: "capture-enrollment",
            lessonId: "capture-sched-lesson",
            scheduledDate: scheduledDate,
            isCompleted: explicitCompleted,
            completedAt: explicitCompleted == true ? Date().addingTimeInterval(-6 * day) : nil,
            lesson: LessonWithActivities(
                id: "capture-sched-lesson",
                studyProgramId: "capture-prog-0",
                dayNumber: c.dayNumber ?? 1,
                activities: schedActivities
            )
        )
        return AnyView(ScheduledLessonCard(schedule: schedule).padding(16))

    case "component.CardEnrolled":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardEnrolled: missing state.component")
        }
        let data = CardEnrolledData(
            id: "capture-card-enrolled",
            studyTitle: c.studyTitle ?? c.title ?? "",
            groupName: c.groupName ?? "",
            startDate: makeCaptureDate(c.startDate),
            endDate: makeCaptureDate(c.endDate),
            lessonsLeft: c.lessonsLeft,
            studyImageURL: c.studyImageURL,
            groupImageURL: c.groupImageURL,
            onTap: nil
        )
        return AnyView(CardEnrolled(data: data).padding(16))

    case "component.CardProgramFull":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardProgramFull: missing state.component")
        }
        let data = CardProgramFullData(
            id: "capture-card-program-full",
            title: c.title ?? "",
            description: c.description,
            coverImageUrl: c.coverUrl,
            tags: c.tags ?? [],
            days: c.days ?? 0,
            enrollmentCount: c.enrollmentCount,
            authorName: c.authorName,
            createdAt: makeCaptureDate(c.createdAt),
            isPublished: c.isPublished ?? false,
            onTap: nil
        )
        return AnyView(CardProgramFull(data: data).padding(16))

    case "component.UpcomingLessonCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.UpcomingLessonCard: missing state.component")
        }
        let upcomingActivities: [ScheduledActivity] = (c.activities ?? []).enumerated().map { idx, a in
            let type = a.type ?? "SCRIPTURE"
            return ScheduledActivity(
                id: "capture-activity-\(idx)",
                lessonId: "capture-lesson-0",
                type: type,
                passageReference: (type == "SCRIPTURE" || type == "SOAP") ? (a.title ?? "Genesis 1:1") : nil,
                videoId: type == "VIDEO" ? "capture-video" : nil,
                prayerPrompt: type == "PRAYER" ? (a.title ?? "Pray") : nil,
                notes: type == "REFLECTION" ? (a.title ?? "Reflect") : nil,
                orderNumber: idx + 1
            )
        }
        let upcomingSchedule = LessonSchedule(
            id: "capture-schedule-0",
            enrollmentId: "capture-enrollment-0",
            lessonId: "capture-lesson-0",
            scheduledDate: makeCaptureDate(c.date),
            isCompleted: nil,
            completedAt: nil,
            lesson: LessonWithActivities(
                id: "capture-lesson-0",
                studyProgramId: "capture-prog-0",
                dayNumber: c.dayNumber ?? 1,
                activities: upcomingActivities
            )
        )
        return AnyView(
            UpcomingLessonCard(
                schedule: upcomingSchedule,
                programName: c.programName ?? c.title ?? "",
                coverImageUrl: c.coverUrl,
                onTap: nil
            ).padding(16)
        )

    case "component.EnrollmentCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.EnrollmentCard: missing state.component")
        }
        let enrollment = EnrollmentWithProgram(
            id: "capture-enrollment-0",
            groupId: "capture-group-0",
            studyProgramId: "capture-prog-0",
            startDate: makeCaptureDate(c.startDate),
            endDate: makeCaptureDate(c.endDate),
            studyProgram: StudyProgramSummary(
                id: "capture-prog-0",
                name: c.title ?? "Study Program",
                description: nil,
                days: c.days ?? 0,
                coverImageUrl: c.coverUrl
            ),
            isActive: !(c.isCompleted ?? false)
        )
        return AnyView(EnrollmentCard(enrollment: enrollment, onTap: nil).padding(16))

    case "component.CardMediaFull":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardMediaFull: missing state.component")
        }
        let item = MediaLibraryItem(
            id: "capture-media-full",
            title: c.title ?? "",
            description: nil,
            url: c.imageUrl ?? "",
            type: c.type ?? "video",
            mimeType: nil,
            fileSize: nil,
            thumbnailUrl: nil,
            uploadStatus: "ready",
            duration: c.durationSeconds,
            tags: [],
            usageCount: c.count ?? 0,
            uploader: nil,
            video: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        return AnyView(CardMediaFull(item: item).frame(width: 120).padding(16))

    case "component.CardSearchResult":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardSearchResult: missing state.component")
        }
        return AnyView(
            CardSearchResult(
                title: c.title ?? "",
                subtitle: c.subtitle,
                timestamp: c.timeAgo,
                imageURL: c.imageUrl,
                firstName: c.firstName,
                lastName: c.lastName,
                sfSymbol: c.iconSystemName ?? "doc.fill",
                isMember: c.isMember ?? false,
                isVideo: c.isVideo ?? false,
                showChevron: c.showChevron ?? true,
                highlightQuery: c.highlightQuery ?? "",
                onTap: {}
            )
            .padding(16)
        )

    case "component.CardBibleSearchResult":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardBibleSearchResult: missing state.component")
        }
        return AnyView(
            CardBibleSearchResult(
                reference: c.passage ?? "",
                text: c.text ?? "",
                title: c.title,
                summary: c.description,
                onTap: nil
            )
            .padding(16)
        )

    case "component.GroupPostCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupPostCard: missing state.component")
        }
        let postType: PostType = {
            switch c.type?.lowercased() {
            case "event": return .event
            case "poll": return .poll
            case "video": return .video
            case "welcome": return .welcome
            default: return .announcement
            }
        }()
        let postCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
            .addingTimeInterval(-Double(c.createdSecondsAgo ?? 0))
        var postEventDate: Date? = nil
        if postType == .event, let pday = c.day {
            let months = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                          "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
            var comps = DateComponents()
            comps.year = c.dayNumber ?? 2025
            comps.month = months[(c.month ?? "").uppercased()] ?? 1
            comps.day = pday
            let hour12 = Int((c.time ?? "0:00").split(separator: ":").first ?? "0") ?? 0
            let minute = Int((c.time ?? "0:00").split(separator: ":").last ?? "0") ?? 0
            let isPM = (c.period ?? "").lowercased() == "pm"
            comps.hour = isPM && hour12 < 12 ? hour12 + 12 : hour12
            comps.minute = minute
            postEventDate = Calendar.current.date(from: comps)
        }
        let post = GroupPost(
            id: "capture-group-post",
            groupId: "capture-group",
            authorId: postType == .welcome ? nil : "capture-author",
            authorName: c.authorName ?? "",
            authorAvatarUrl: c.imageUrl,
            type: postType,
            content: c.text ?? "",
            title: c.title,
            imageUrl: c.images?.first,
            enrollmentId: nil,
            createdAt: postCreatedAt,
            updatedAt: postCreatedAt,
            viewCount: c.count,
            shareCount: Int(c.value ?? ""),
            pollOptions: nil,
            videoUrl: nil,
            eventDate: postEventDate,
            eventLocation: nil,
            eventTitle: c.subtitle,
            attendeeCount: c.memberCount
        )
        return AnyView(GroupPostCard(post: post).padding(16))

    // MARK: - Button

    case "component.ActionButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ActionButton: missing state.component")
        }
        let variant: ActionButtonVariant = {
            switch c.variant {
            case "purple": return .purple
            case "purpleIcon": return .purpleIcon
            case "white": return .white
            case "whiteIcon": return .whiteIcon
            case "whitePurple": return .whitePurple
            case "swipeLarge": return .swipeLarge
            case "circleBlur": return .circleBlur
            default: return .white
            }
        }()
        let actionButton: ActionButton = {
            if let label = c.label {
                return ActionButton(label: label, icon: c.icon, variant: variant, action: {})
            }
            return ActionButton(icon: c.icon ?? "questionmark", variant: variant, action: {})
        }()
        return AnyView(actionButton.padding(16))

    case "component.BoxButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.BoxButton: missing state.component")
        }
        let boxVariant: BoxButtonVariant = {
            switch c.variant {
            case "secondary": return .secondary
            case "destructive": return .destructive
            case "disabled": return .disabled
            default: return .primary
            }
        }()
        let boxStyle: BoxButtonStyle = c.style == "border" ? .border : .solid
        let boxSize: BoxButtonSize = {
            switch c.size {
            case "lg": return .lg
            case "sm": return .sm
            default: return .md
            }
        }()
        let boxIconPosition: BoxButtonIconPosition = {
            switch c.iconPosition {
            case "left": return .left
            case "right": return .right
            case "none": return .none
            default: return c.icon != nil ? .left : .none
            }
        }()
        return AnyView(
            BoxButton(
                action: {},
                label: c.label,
                icon: c.icon,
                iconPosition: boxIconPosition,
                variant: boxVariant,
                style: boxStyle,
                size: boxSize,
                fullWidth: c.fullWidth ?? false
            ).padding(16)
        )


    // ===== Display =====
    // MARK: - Display

    case "component.Alert":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Alert: missing state.component")
        }
        let alertVariant: AlertVariant = (c.variant == "critical") ? .critical : .warning
        return AnyView(
            Alert(message: c.message ?? c.text ?? "", variant: alertVariant)
                .padding(16)
        )

    case "component.AlphabetScrubber":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.AlphabetScrubber: missing state.component")
        }
        let scrubberLetters = (c.letters?.isEmpty == false)
            ? c.letters!
            : Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }
        return AnyView(
            AlphabetScrubber(letters: scrubberLetters, onLetterTap: { _ in })
                .frame(height: 360)
                .padding(16)
        )

    case "component.Avatar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Avatar: missing state.component")
        }
        let avatarSize: AvatarSize = {
            switch c.size {
            case "xs": return .xs
            case "sm": return .sm
            case "md": return .md
            case "lg": return .lg
            case "xl": return .xl
            case "xxl": return .xxl
            default: return .md
            }
        }()
        return AnyView(
            Avatar(
                imageURL: c.imageUrl,
                initials: c.initials,
                size: avatarSize
            )
            .padding(16)
        )

    case "component.DialogOverlay":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.DialogOverlay: missing state.component")
        }
        let dialogButtons: [DialogButtonConfig] = (c.buttons ?? []).map { b in
            let style: DialogButtonStyle = (b.style == "secondary") ? .secondary : .primary
            return DialogButtonConfig(b.label ?? "", style: style, action: {})
        }
        return AnyView(
            DialogOverlay(
                isPresented: .constant(true),
                title: c.title,
                message: c.message,
                buttons: dialogButtons
            )
            .frame(height: 360)
        )

    case "component.FullScreenImageViewer":
        // The viewer takes a UIImage; remote fixture URLs can't be loaded
        // synchronously in a deterministic capture, so render the chrome over a
        // stand-in SF Symbol image.
        return AnyView(
            FullScreenImageViewer(image: UIImage(systemName: "photo.fill"))
                .frame(height: 480)
        )

    case "component.GroupSelectorSheet":
        // Self-contained: its GroupFixtureManager @StateObject hardcodes a default
        // group list, so it renders standalone. We only supply the selection binding
        // and bound the NavigationStack to a sheet-like height for the snapshot.
        return AnyView(
            GroupSelectorSheet(selectedGroup: .constant(nil))
                .frame(width: 393, height: 640)
        )

    case "component.InfoPanel":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.InfoPanel: missing state.component")
        }
        let infoMode: InfoPanelMode = (c.mode == "data") ? .data : .keyValue
        let infoItems: [InfoPanelItem] = (c.items ?? []).map { item in
            InfoPanelItem(label: item.label ?? "", value: item.value ?? "")
        }
        return AnyView(
            InfoPanel(items: infoItems, mode: infoMode)
                .padding(16)
        )

    // SKIPPED component.InviteQRCodeView: QR image is fetched from the server at
    // runtime (network-dependent + requires AuthManager); a capture would show a
    // non-deterministic ProgressView spinner rather than a QR code.

    case "component.Kpi":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.Kpi: missing state.component")
        }
        let kpiVariant: KpiVariant = {
            switch c.variant {
            case "compact": return .compact
            case "sparkline": return .sparkline
            case "iconValue": return .iconValue
            default: return .standard
            }
        }()
        let kpiValueType: KpiValueType = {
            switch c.valueType {
            case "currency": return .currency()
            case "percent": return .percent
            case "custom": return .custom(suffix: c.suffix ?? "")
            case "decimal": return .decimal()
            default: return .number
            }
        }()
        let kpiTrend: KpiTrend? = c.trend.map { KpiTrend(points: $0.points ?? []) }
        return AnyView(
            Kpi(
                value: c.kpiValue ?? 0,
                valueType: kpiValueType,
                label: c.label ?? "",
                description: c.description,
                icon: c.icon,
                iconColor: namedCaptureColor(c.iconColor),
                trend: kpiTrend,
                variant: kpiVariant
            )
            .padding(16)
        )

    case "component.MemberListItem":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.MemberListItem: missing state.component")
        }
        if c.variant == "contact" {
            let contact = MemberListContact(
                firstName: c.firstName ?? "",
                lastName: c.lastName ?? "",
                avatarURL: c.avatarUrl
            )
            return AnyView(MemberListItem(contact: contact).padding(16))
        }
        let memberVariant: MemberListItemVariant = {
            switch c.variant {
            case "member": return .member
            case "memberMultipleGroups": return .memberMultipleGroups
            default: return .memberWithInvite
            }
        }()
        // Member.age is derived from birthDate vs. now — subtract the fixture age
        // in years so the displayed age matches the fixture deterministically.
        let memberBirthDate = c.age.flatMap {
            Calendar.current.date(byAdding: .year, value: -$0, to: Date())
        }
        let member = Member(
            firstName: c.firstName ?? "",
            lastName: c.lastName ?? "",
            avatarURL: c.avatarUrl,
            birthDate: memberBirthDate,
            joinDate: makeCaptureDateOptional(c.joinDate),
            groups: c.groups ?? []
        )
        return AnyView(MemberListItem(member: member, variant: memberVariant).padding(16))

    // SKIPPED component.ShareInviteSheet: full-page sheet that embeds
    // InviteQRCodeView (server-fetched QR), and requires AuthManager +
    // OverlayManager — the QR area renders as a non-deterministic spinner.

    case "component.WeekdayIndicator":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.WeekdayIndicator: missing state.component")
        }
        return AnyView(
            WeekdayIndicator(enabledDays: Set(c.enabledDays ?? []))
                .padding(16)
        )

    // ===== Input =====
    case "component.AgeRangeInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.AgeRangeInput: missing state.component") }
        return AnyView(
            FieldGroup {
                AgeRangeInput(
                    label: c.label ?? "Age range",
                    minAge: .constant(c.minAge ?? "0"),
                    maxAge: .constant(c.maxAge ?? "99")
                )
            }
            .padding(16)
        )

    case "component.BackgroundSourceMenu":
        return AnyView(
            BackgroundSourceMenu(
                onPickFromLibrary: {},
                onPickFromPhotos: {},
                onTakePhoto: {}
            )
            .padding(16)
        )

    case "component.BackgroundSwatch":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.BackgroundSwatch: missing state.component") }
        return AnyView(
            BackgroundSwatch(
                imageUrl: c.imageUrl,
                color: c.color,
                overlayOpacity: c.overlayOpacity,
                onTap: {}
            )
            .padding(16)
        )

    case "component.BlockStyleEditor":
        // The BlockStyleEditor adapter seeds a one-block READ activity into AppState
        // (via setupCaptureState); the editor reads its background/color/font state
        // from that block. We just need the ids + the title/theme init params.
        let bseActivityId = fixture.state?.activity?.id ?? ""
        let bseBlockId = fixture.state?.activity?.readBlocks?.first?.id ?? ""
        guard AppState.shared.activities[bseActivityId] != nil else {
            throw ViewRegistryError.unknownView("component.BlockStyleEditor: activity '\(bseActivityId)' not seeded")
        }
        let bseComponent = fixture.state?.component
        // Build TextThemes by decoding minimal JSON (TextTheme has no memberwise init).
        let bseThemes: [TextTheme]? = bseComponent?.availableThemes?.enumerated().compactMap { index, option in
            let dict: [String: Any] = [
                "id": "capture-theme-\(index)",
                "name": option.name ?? "Theme",
                "slug": "capture-theme-\(index)",
                "isSystem": false,
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let theme = try? JSONDecoder().decode(TextTheme.self, from: data) else { return nil }
            return theme
        }
        return AnyView(
            BlockStyleEditor(
                activityId: bseActivityId,
                blockId: bseBlockId,
                blockTitle: bseComponent?.blockTitle,
                availableThemes: bseThemes
            )
            .environment(OverlayManager())
            .padding(16)
        )

    case "component.CoverImagePicker":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.CoverImagePicker: missing state.component") }
        let coverMode: CoverImagePickerMode = (c.mode == "display") ? .display : .editable
        return AnyView(
            CoverImagePicker(
                selectedImage: .constant(nil),
                programName: c.programName ?? "",
                programDescription: c.programDescription ?? "",
                mode: coverMode,
                existingImageUrl: c.existingImageUrl
            )
            .padding(16)
        )

    case "component.DatePickerField":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.DatePickerField: missing state.component") }
        return AnyView(
            FieldGroup {
                DatePickerField(
                    label: c.label ?? "Date",
                    date: .constant(makeCaptureDate(c.date))
                )
            }
            .padding(16)
        )

    case "component.FieldGroup":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.FieldGroup: missing state.component") }
        let items = c.fieldRows ?? []
        return AnyView(
            FieldGroup {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Text(item)
                        .font(Typography.s17)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    if idx < items.count - 1 {
                        FieldGroupDivider()
                    }
                }
                if let desc = c.description {
                    FieldGroupDivider()
                    FieldGroupDescription(text: desc)
                }
            }
            .padding(16)
        )

    case "component.InlineFontSizePicker":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.InlineFontSizePicker: missing state.component") }
        return AnyView(
            InlineFontSizePicker(
                selectedSize: c.selectedSize ?? "m",
                onSizeSelected: { _ in }
            )
            .padding(16)
        )

    case "component.LargeTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LargeTextInput: missing state.component") }
        let largeInputType: InputType = {
            switch c.inputType {
            case "phone": return .phone
            case "integer": return .integer
            case "float": return .float
            case "currency": return .currency
            case "email": return .email
            case "percentage": return .percentage
            default: return .alphanumeric
            }
        }()
        return AnyView(
            FieldGroup {
                LargeTextInput(
                    label: c.label ?? "",
                    inputType: largeInputType,
                    text: .constant(c.text ?? "")
                )
                .padding(.horizontal, 16)
            }
            .padding(16)
        )

    case "component.MarkdownEditor":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MarkdownEditor: missing state.component") }
        return AnyView(
            MarkdownEditor(
                placeholder: c.placeholder ?? "",
                attributedText: .constant(MarkdownEditor.markdownToAttributed(c.markdown ?? "")),
                minHeight: 200,
                autoGrow: c.autoGrow ?? false
            )
            .padding(16)
        )

    case "component.MenuInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MenuInput: missing state.component") }
        let menuStyle: MenuInputStyle = {
            switch c.style {
            case "wheel": return .wheel
            case "inline": return .inline
            case "segmented": return .segmented
            default: return .menu
            }
        }()
        let menuInput: MenuInput = {
            if let described = c.optionsWithDescriptions {
                return MenuInput(
                    label: c.label ?? "",
                    options: described.map { MenuInputOption($0.value, description: $0.description) },
                    selectedOption: .constant(c.selectedOption ?? ""),
                    style: menuStyle
                )
            }
            return MenuInput(
                label: c.label ?? "",
                options: c.options ?? [],
                selectedOption: .constant(c.selectedOption ?? ""),
                style: menuStyle
            )
        }()
        return AnyView(
            FieldGroup { menuInput }
                .padding(16)
        )

    case "component.MultilineTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.MultilineTextInput: missing state.component") }
        return AnyView(
            FieldGroup {
                MultilineTextInput(
                    placeholder: c.placeholder ?? "",
                    text: .constant(c.text ?? "")
                )
            }
            .padding(16)
        )

    case "component.RichTextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.RichTextInput: missing state.component") }
        return AnyView(
            RichTextInput(
                placeholder: c.placeholder ?? "",
                html: .constant(c.html ?? ""),
                minHeight: 200,
                autoGrow: c.autoGrow ?? false,
                outputFormat: c.outputFormat ?? "html"
            )
            .padding(16)
        )

    case "component.SearchField":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.SearchField: missing state.component") }
        return AnyView(
            CaptureSearchFieldWrapper(
                isActive: c.isActive ?? false,
                searchText: c.searchText ?? "",
                placeholder: c.placeholder ?? "Search"
            )
            .padding(16)
        )

    case "component.TagInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TagInput: missing state.component") }
        return AnyView(
            TagInput(
                tags: .constant(c.tags ?? []),
                placeholder: c.placeholder ?? ""
            )
            .padding(16)
        )

    case "component.TextInput":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TextInput: missing state.component") }
        let textInputType: InputType = {
            switch c.inputType {
            case "phone": return .phone
            case "integer": return .integer
            case "float": return .float
            case "currency": return .currency
            case "email": return .email
            case "percentage": return .percentage
            default: return .alphanumeric
            }
        }()
        let textInput: TextInput = {
            if let floating = c.floatingLabel {
                return TextInput(
                    floatingLabel: floating,
                    icon: c.icon,
                    inputType: textInputType,
                    text: .constant(c.text ?? "")
                )
            }
            if let label = c.label {
                return TextInput(
                    label: label,
                    icon: c.icon,
                    inputType: textInputType,
                    text: .constant(c.text ?? "")
                )
            }
            return TextInput(
                placeholder: c.placeholder ?? "",
                inputType: textInputType,
                text: .constant(c.text ?? "")
            )
        }()
        return AnyView(
            FieldGroup { textInput }
                .padding(16)
        )

    case "component.ToggleControl":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.ToggleControl: missing state.component") }
        return AnyView(
            ToggleGroup {
                ToggleControl(
                    title: c.title ?? "",
                    description: c.description ?? "",
                    isOn: .constant(c.isOn ?? false)
                )
            }
            .padding(16)
        )

    // ===== Navigation =====
    case "component.ActionCardMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.ActionCardMenu: missing state.component") }
        let actionItems: [ActionCardMenuItem] = (c.items ?? []).map { item in
            ActionCardMenuItem(
                icon: item.icon ?? "questionmark",
                title: item.title ?? "",
                description: item.description ?? ""
            ) {}
        }
        return AnyView(ActionCardMenu(title: c.title ?? "", items: actionItems).padding(16))

    // SKIPPED component.AddActivityMenu: fades in from opacity 0 on .onAppear and fills the
    // whole screen (.frame(maxWidth/maxHeight: .infinity)); not suitable for a .sizeThatFits
    // component capture.

    case "component.AddMenu":
        guard fixture.state?.component != nil else { throw ViewRegistryError.unknownView("component.AddMenu: missing state.component") }
        // AddMenu builds its rows from hardcoded content; the submenu sits offscreen at rest,
        // so both fixture variants render the main menu deterministically.
        return AnyView(
            AddMenu()
                .environment(OverlayManager())
                .environment(AuthManager())
                .padding(16)
        )

    case "component.FilterChipDropdown":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.FilterChipDropdown: missing state.component") }
        let chipItems: [FilterChipDropdownItem] = (c.items ?? []).map { item in
            FilterChipDropdownItem(id: item.id ?? UUID().uuidString, label: item.label ?? "")
        }
        let chipSelected = Set(c.selectedIds ?? [])
        return AnyView(
            FilterChipDropdownPanel(
                items: chipItems,
                selectedIds: chipSelected,
                showClearAll: c.showClearAll ?? true,
                onToggle: { _ in },
                onClearAll: {}
            )
            .padding(16)
        )

    case "component.HamburgerMenu":
        guard fixture.state?.component != nil else { throw ViewRegistryError.unknownView("component.HamburgerMenu: missing state.component") }
        // HamburgerMenu rows are hardcoded; fixture items are descriptive only.
        return AnyView(
            HamburgerMenu()
                .environment(OverlayManager())
                .padding(16)
        )

    case "component.InviteMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.InviteMenu: missing state.component") }
        // InviteMenu rows are hardcoded; menuId is the only fixture-driven value.
        return AnyView(
            InviteMenu(overlayManager: OverlayManager(), menuId: c.menuId ?? "preview")
                .environment(AuthManager())
                .padding(16)
        )

    case "component.LessonActionMenu":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LessonActionMenu: missing state.component") }
        let lamSchedule = LessonSchedule(
            id: "capture-lesson-schedule",
            enrollmentId: c.enrollmentId ?? "e1",
            lessonId: "capture-lesson",
            scheduledDate: makeCaptureDate(c.scheduledDate),
            isCompleted: nil,
            completedAt: nil,
            lesson: LessonWithActivities(
                id: "capture-lesson",
                studyProgramId: "capture-program",
                dayNumber: c.dayNumber ?? 1,
                activities: []
            )
        )
        let lamMenu = LessonActionMenu(
            schedule: lamSchedule,
            studyName: c.studyName ?? "",
            enrollmentId: c.enrollmentId ?? "e1",
            onEditActivities: {},
            onOpenLesson: {},
            onShareLesson: {},
            onAddLesson: (c.showAddLesson ?? false) ? {} : nil,
            onEditEnrollment: (c.showEditEnrollment ?? false) ? {} : nil,
            onDelete: {}
        )
        return AnyView(
            lamMenu
                .environment(OverlayManager())
                .padding(16)
        )

    case "component.NavBar":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.NavBar: missing state.component") }
        let navTab: NavBarTab = {
            switch c.activeTab?.stringValue {
            case "home": return .home
            case "groups": return .groups
            case "library": return .library
            case "calendar": return .calendar
            case "search": return .search
            case "profile": return .profile
            default: return .none
            }
        }()
        return AnyView(NavBar(activeTab: navTab, avatarURL: c.avatarURL).padding(16))

    case "component.PageHeader":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.PageHeader: missing state.component") }
        return AnyView(
            PageHeader(tabs: c.tabs ?? [], activeTab: .constant(c.activeTab?.intValue ?? 0))
                .padding(16)
        )

    case "component.PageTitle":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.PageTitle: missing state.component") }
        let ptTitle = c.title ?? ""
        let ptView: AnyView = {
            switch c.factory {
            case "iconTitleLink":
                return AnyView(PageTitle.iconTitleLink(title: ptTitle, leftIcon: c.leftIcon, rightLink: c.rightLink ?? "Done", onLeftIconTap: {}, onRightLinkTap: {}))
            case "iconTitleIcon":
                return AnyView(PageTitle.iconTitleIcon(title: ptTitle, leftIcon: c.leftIcon ?? "xmark", rightIcon: c.rightIcon ?? "checkmark", onLeftIconTap: {}, onRightIconTap: {}))
            case "iconTitleIcons":
                let actions = (c.rightIcons ?? []).map { ic in
                    IconAction(icon: ic.icon ?? "questionmark", showBadge: ic.showBadge ?? false) {}
                }
                return AnyView(PageTitle.iconTitleIcons(title: ptTitle, leftIcon: c.leftIcon, rightIcons: actions, onLeftIconTap: {}))
            case "linkTitle":
                return AnyView(PageTitle.linkTitle(title: ptTitle, link: c.leftLink ?? "Done", onLinkTap: {}))
            case "linkTitleLink":
                return AnyView(PageTitle.linkTitleLink(title: ptTitle, leftLink: c.leftLink ?? "Cancel", rightLink: c.rightLink ?? "Save", onLeftLinkTap: {}, onRightLinkTap: {}))
            case "iconMenu":
                return AnyView(PageTitle.iconMenu(title: ptTitle, leftIcon: c.leftIcon ?? "xmark", onLeftIconTap: {}, onDropdownTap: {}))
            case "iconLink":
                return AnyView(PageTitle.iconLink(leftIcon: c.leftIcon ?? "xmark", rightLink: c.rightLink ?? "Done", onLeftIconTap: {}, onRightLinkTap: {}))
            case "iconIcon":
                return AnyView(PageTitle.iconIcon(leftIcon: c.leftIcon ?? "xmark", rightIcon: c.rightIcon ?? "checkmark", onLeftIconTap: {}, onRightIconTap: {}))
            case "icon":
                return AnyView(PageTitle.icon(icon: c.leftIcon ?? "xmark", onIconTap: {}))
            case "backLinkTitle":
                return AnyView(PageTitle.backLinkTitle(title: ptTitle, backText: c.backText ?? "", onBackTap: {}))
            case "titleOnly":
                return AnyView(PageTitle.titleOnly(title: ptTitle))
            default: // "iconTitle"
                return AnyView(PageTitle.iconTitle(title: ptTitle, icon: c.leftIcon, onIconTap: {}))
            }
        }()
        return AnyView(ptView.padding(16))

    case "component.TabSlider":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.TabSlider: missing state.component") }
        return AnyView(
            TabSlider(tabs: c.tabs ?? [], selectedIndex: .constant(c.selectedIndex ?? 0))
                .padding(16)
        )

    case "component.UserMenu":
        // The UserMenu adapter projects the signed-in user into fixture.auth (→ the
        // mock authManager above) and the org list into component.organizations.
        // Seed those orgs into AppState so the per-org rows render.
        AppState.shared.userOrganizations = (fixture.state?.component?.organizations ?? []).map {
            OrganizationData(id: $0.id ?? "capture-org", name: $0.name ?? "Organization",
                             ownerId: nil, createdAt: nil, updatedAt: nil)
        }
        return AnyView(
            UserMenu()
                .environment(authManager)
                .environment(OverlayManager())
                .frame(width: 393)
                .padding(.vertical, 16)
                .background(Color.appBackground)
        )

    // ===== Chart =====
    // MARK: - Chart components
    //
    // Color strings in chart fixtures are hex ("#6c47ff") or rgba("rgba(...)").
    // Color(hex:) is reserved (Colors.swift only), so each case inlines a small
    // resolver mapping the known palette hexes to brand tokens and falling back
    // to a sensible default for rgba / unknown values.

    case "component.DonutChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.DonutChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.white.opacity(0.3)   // rgba / unknown → muted default
            }
        }
        let donutPoints: [DonutChartDataPoint] = (c.dataPoints ?? []).map {
            DonutChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            DonutChart(
                dataPoints: donutPoints,
                innerRadiusRatio: CGFloat(c.innerRadiusRatio ?? 0.75),
                showCenterLabel: c.showCenterLabel ?? true,
                centerLabelText: c.centerLabelText,
                centerLabelSubtext: c.centerLabelSubtext
            )
            .padding(16)
            .frame(height: 220)
        )

    case "component.HorizontalBarChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.HorizontalBarChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.brandPrimary.opacity(0.5)   // rgba shades / unknown → brand fade
            }
        }
        let hBarPoints: [BarChartDataPoint] = (c.dataPoints ?? []).map {
            BarChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            HorizontalBarChart(
                dataPoints: hBarPoints,
                showValues: c.showValues ?? true,
                barHeight: CGFloat(c.barHeight ?? 32)
            )
            .padding(16)
        )

    case "component.VerticalBarChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.VerticalBarChart: missing state.component") }
        let resolve: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.white.opacity(0.3)   // rgba / unknown → muted default
            }
        }
        let vBarPoints: [BarChartDataPoint] = (c.dataPoints ?? []).map {
            BarChartDataPoint(label: $0.label ?? "", value: $0.value ?? 0, color: resolve($0.color))
        }
        return AnyView(
            VerticalBarChart(
                dataPoints: vBarPoints,
                showValues: c.showValues ?? true,
                chartHeight: CGFloat(c.chartHeight ?? 200)
            )
            .padding(16)
        )

    case "component.HeatMapChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.HeatMapChart: missing state.component") }
        let heatPoints: [HeatMapDataPoint] = (c.heatMapPoints ?? []).map {
            HeatMapDataPoint(week: $0.week ?? 0, day: $0.day ?? 0, value: $0.value ?? 0, dayLabel: $0.dayLabel ?? "")
        }
        // colorScale strings are hex/rgba; resolve last (most saturated) to a token
        // to drive the chart's continuous ramp, otherwise use the chart default.
        let scale: [Color]? = c.colorScale.map { raw in
            raw.map { s -> Color in
                switch s.lowercased() {
                case "#4ade80", "rgba(74,222,128,0.3)", "rgba(74,222,128,0.6)": return Color.green
                case "#ff6b9d", "rgba(255,107,157,0.3)", "rgba(255,107,157,0.6)": return Color.pink
                default: return Color.white.opacity(0.05)
                }
            }
        }
        return AnyView(
            HeatMapChart(
                dataPoints: heatPoints,
                colorScale: scale,
                showDayLabels: c.showDayLabels ?? true,
                chartHeight: CGFloat(c.chartHeight ?? 120)
            )
            .padding(16)
        )

    case "component.LineChart":
        guard let c = fixture.state?.component else { throw ViewRegistryError.unknownView("component.LineChart: missing state.component") }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let resolveHex: (String?) -> Color = { raw in
            switch raw?.lowercased() {
            case "#6c47ff": return Color.brandPrimary
            case "#47d4ff": return Color.accentBlue
            case "#ff6b9d": return Color.pink
            case "#ffd93d": return Color.yellow
            case "#4ade80": return Color.green
            default: return Color.brandPrimary
            }
        }
        let trendLines: [TrendLine] = (c.trendLines ?? []).map { tl in
            let points: [ChartDataPoint] = (tl.dataPoints ?? []).map {
                ChartDataPoint(date: dateFormatter.date(from: $0.date ?? "") ?? Date(), value: $0.value ?? 0)
            }
            let chartColor: ChartColor
            if tl.color?.lowercased() == "gradient" {
                let colors = (tl.gradientColors ?? []).map { resolveHex($0) }
                chartColor = .gradient(colors: colors.isEmpty ? [Color.brandPrimary] : colors,
                                       angle: tl.gradientAngle ?? 90)
            } else {
                chartColor = .solid(resolveHex(tl.solidColor))
            }
            return TrendLine(dataPoints: points, color: chartColor, lineWidth: CGFloat(tl.lineWidth ?? 2))
        }
        let timeScale: TimeScale = {
            switch c.timeScale {
            case "hours": return .hours
            case "weeks": return .weeks
            case "months": return .months
            case "years": return .years
            default: return .days
            }
        }()
        let interp: ChartInterpolationMethod = {
            switch c.interpolationMethod {
            case "linear": return .linear
            case "catmullRom": return .catmullRom
            default: return .monotone
            }
        }()
        return AnyView(
            LineChart(
                trendLines: trendLines,
                timeScale: timeScale,
                yAxisScale: .auto,
                interactive: c.interactive ?? true,
                animated: c.animated ?? true,
                showArea: c.showArea ?? false,
                interpolationMethod: interp
            )
            .padding(16)
        )

    // ===== CalContentLoading =====
    // MARK: - Calendar

    case "component.CalendarBottomBar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarBottomBar: missing state.component")
        }
        // `showViewModes` decides whether the view-mode toggles (and divider) appear:
        // they only render when an `onViewModeChange` closure is supplied. The bar's
        // internal `selectedMode` defaults to `.month`, matching the fixture.
        let calBottomBar: CalendarBottomBar = {
            if c.showViewModes == true {
                return CalendarBottomBar(onTodayTap: {}, onViewModeChange: { _ in })
            }
            return CalendarBottomBar(onTodayTap: {})
        }()
        return AnyView(calBottomBar.padding(16))

    case "component.CalendarDayCell":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarDayCell: missing state.component")
        }
        // UIKit UICollectionViewCell — wrap in UIViewPreviewWrapper (defined alongside
        // the cell). `isToday` is computed from the day's date via Calendar, so the
        // "today" case uses Date(); other cases use a fixed past date for determinism.
        let dayCellEvents: [SplitCalendarEvent] = (c.eventColors ?? []).enumerated().map { idx, hex in
            SplitCalendarEvent(
                id: "capture-daycell-event-\(idx)",
                title: "Event \(idx + 1)",
                startTime: Date(timeIntervalSince1970: 1_769_000_000),
                color: hex
            )
        }
        let dayCellDate: Date = (c.isToday == true)
            ? Date()
            : Date(timeIntervalSince1970: 1_769_000_000)
        let splitDay = SplitCalendarDay(
            date: dayCellDate,
            dayNumber: c.dayNumber ?? 1,
            isCurrentMonth: c.isCurrentMonth ?? true,
            weekdayIndex: 0,
            rowIndex: 0,
            events: dayCellEvents
        )
        let dayCell = CalendarDayCell(frame: CGRect(x: 0, y: 0, width: 48, height: 56))
        dayCell.configure(with: splitDay, isSelected: c.isSelected ?? false)
        dayCell.backgroundColor = UIColor(Color.appBackground)
        return AnyView(
            UIViewPreviewWrapper(view: dayCell)
                .frame(width: 48, height: 56)
                .padding(16)
        )

    case "component.CalendarEventListContent":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CalendarEventListContent: missing state.component")
        }
        let eventListEvents: [SplitCalendarEvent] = (c.events ?? []).map { e in
            SplitCalendarEvent(
                id: e.id,
                title: e.title ?? "",
                subtitle: e.subtitle,
                startTime: Date(timeIntervalSince1970: 1_769_000_000),
                color: e.color ?? "#6c47ff",
                dayNumber: e.dayNumber,
                coverImageUrl: e.coverImageUrl,
                activityIcons: (e.activityIcons ?? []).map {
                    CalendarActivityIcon(icon: $0.icon ?? "circle.fill", label: $0.label ?? "")
                }
            )
        }
        return AnyView(
            CalendarEventListContent(
                events: eventListEvents,
                selectedDate: makeCaptureDate(c.selectedDate),
                onEventTap: { _ in }
            )
        )

    case "component.CalendarWeekdayHeader":
        // No props — renders the fixed "S M T W T F S" header row.
        return AnyView(CalendarWeekdayHeader())

    // SKIPPED component.SplitMonthCalendar: UIViewControllerRepresentable wrapping a
    // live SplitMonthCalendarController (UICollectionView + scroll/expand/snapshot
    // pipeline). It cannot render meaningfully under .sizeThatFits without a hosting
    // window and a driven controller.

    // MARK: - Content

    // SKIPPED component.BibleVerseTextLayout: this is a static-helper enum
    // (fonts/insets/attributed-text builders), not a standalone View. Rendering it
    // would require reimplementing the reader's UITextView/badge layout pipeline.

    case "component.ExegesisVerseView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ExegesisVerseView: missing state.component")
        }
        let exegesisHighlights: [ReadBlockSelection] = (c.highlights ?? []).map {
            ReadBlockSelection(start: $0.start, end: $0.end, style: $0.style ?? "highlight")
        }
        return AnyView(
            ExegesisVerseView(
                plainText: c.plainText ?? "",
                highlights: exegesisHighlights,
                isSelectionEnabled: c.isSelectionEnabled ?? false,
                fontSize: CGFloat(c.fontSize ?? 16),
                usePreviewHighlightStyle: c.usePreviewHighlightStyle ?? false,
                pendingRange: .constant(nil)
            )
            .padding(16)
        )

    case "component.SelectableLockedBlockView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SelectableLockedBlockView: missing state.component")
        }
        let lockedSelections: [ReadBlockSelection] = (c.selections ?? []).map {
            ReadBlockSelection(start: $0.start, end: $0.end, style: $0.style ?? "highlight")
        }
        return AnyView(
            SelectableLockedBlockView(
                plainText: c.plainText ?? "",
                selections: lockedSelections,
                isSelectionEnabled: c.isSelectionEnabled ?? false,
                editingRange: nil,
                pendingRange: .constant(nil),
                fontSize: CGFloat(c.fontSize ?? 16),
                usePreviewHighlightStyle: c.usePreviewHighlightStyle ?? false,
                isScripture: c.isScripture ?? true
            )
            .padding(16)
        )

    // SKIPPED component.ThemedContentView: WKWebView that loads a bundled
    // `themed-content.html` and renders via injected JS (window.renderTheme). Web
    // content loads asynchronously, so it produces nothing under a synchronous
    // .sizeThatFits capture.

    // MARK: - Loading

    case "component.CardSpinnerOverlay":
        // No props — a dimming spinner overlay. Render over a card-sized frame so
        // the overlay has bounds to fill (it has no intrinsic size of its own).
        return AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cardBackground)
                CardSpinnerOverlay()
            }
            .frame(width: 320, height: 140)
            .padding(16)
        )

    case "component.ShimmerView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ShimmerView: missing state.component")
        }
        // ShimmerView ships as a `.shimmer()` modifier, not a view. Build the
        // skeleton shape(s) the fixture describes and apply the modifier.
        let shimmerContent: AnyView = {
            if c.shape == "textRows" {
                return AnyView(
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array((c.rows ?? []).enumerated()), id: \.offset) { _, row in
                            RoundedRectangle(cornerRadius: CGFloat(row.cornerRadius ?? 4))
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: CGFloat(row.width ?? 120), height: CGFloat(row.height ?? 20))
                        }
                    }
                    .shimmer()
                )
            }
            return AnyView(
                RoundedRectangle(cornerRadius: CGFloat(c.cornerRadius ?? 8))
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: CGFloat(c.width ?? 320), height: CGFloat(c.height ?? 100))
                    .shimmer()
            )
        }()
        return AnyView(shimmerContent.padding(16))

    // ===== CardsEtc =====
    // MARK: - Cards (Components/Card/)

    case "component.CardGroupMini":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.CardGroupMini: missing state.component")
        }
        let cgmImageStyle: CardImageStyle = {
            if let cover = c.coverUrl, !cover.isEmpty {
                return .photo(imageURL: cover)
            }
            return .icon(systemName: c.iconSystemName ?? "person.2.fill", backgroundColor: nil, foregroundColor: nil)
        }()
        let cgmData = CardGroupData(
            id: "capture-card-group-mini",
            title: c.title ?? "",
            imageStyle: cgmImageStyle,
            metadata: makeCaptureDataItems(c.metadata),
            isSelected: c.selected ?? false
        )
        return AnyView(CardGroupMini(data: cgmData).padding(16))

    case "component.SkeletonCardGroup":
        return AnyView(SkeletonCardGroup().padding(16))

    case "component.SkeletonCardLesson":
        return AnyView(SkeletonCardLesson().padding(16))

    case "component.SkeletonCardLessonActivity":
        return AnyView(SkeletonCardLessonActivity().padding(16))

    case "component.SkeletonCardMediaFull":
        return AnyView(SkeletonCardMediaFull().frame(width: 120).padding(16))

    case "component.SkeletonCardProgramFull":
        return AnyView(SkeletonCardProgramFull().padding(16))

    case "component.SkeletonCardStudy":
        return AnyView(SkeletonCardStudy().padding(16))

    case "component.SlideButton":
        // SlideButton is a data struct, not a View. Its visual is the circular
        // action button rendered inside SwipeableCard.buttonRow. Reproduce that
        // pill (48×48 circle + white icon) so the button can be compared standalone.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SlideButton: missing state.component")
        }
        let slideBackground: Color = {
            switch c.style {
            case "reschedule": return Color.accentBlue
            case "delete": return Color.destructive
            default: return Color.white.opacity(0.2)   // skip | edit
            }
        }()
        return AnyView(
            Image(systemName: c.icon ?? "questionmark")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(slideBackground)
                .clipShape(Circle())
                .padding(16)
        )

    case "component.SwipeableCard":
        // SwipeableCard wraps content and only reveals its action buttons once
        // swiped (abs(offset) > 5). At rest it shows just the content, so render
        // it around a simple placeholder card.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SwipeableCard: missing state.component")
        }
        let swipeButtons: [SlideButton] = (c.slideButtons ?? []).map { b in
            let style: SlideButtonStyle = {
                switch b.style {
                case "reschedule": return .reschedule
                case "delete": return .delete
                case "edit": return .edit
                default: return .skip
                }
            }()
            return SlideButton(icon: b.icon ?? "circle", style: style, action: {})
        }
        return AnyView(
            SwipeableCard(
                slideButtons: swipeButtons,
                isSwipeEnabled: c.isSwipeEnabled ?? true,
                onTap: {}
            ) {
                CardGroupMini(data: CardGroupData(
                    id: "capture-swipeable-content",
                    title: "Swipeable Card",
                    imageStyle: .icon(systemName: "person.2.fill", backgroundColor: nil, foregroundColor: nil),
                    metadata: [DataItem(number: "12", label: "Members")],
                    isSelected: false
                ))
            }
            .padding(16)
        )

    // MARK: - Domain (Components/Domain/)

    case "component.SkeletonEnrollmentCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SkeletonEnrollmentCard: missing state.component")
        }
        return AnyView(
            SkeletonEnrollmentCard(
                programName: c.programName ?? "",
                programImageUrl: c.programImageUrl,
                programDays: c.programDays ?? 0
            ).padding(16)
        )

    // MARK: - Group (Components/Group/)

    case "component.GroupActionButton":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.GroupActionButton: missing state.component")
        }
        return AnyView(
            GroupActionButton(
                label: c.label ?? "",
                icon: c.icon ?? "circle",
                action: {}
            ).padding(16)
        )

    case "component.SkeletonPostCard":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SkeletonPostCard: missing state.component")
        }
        if let name = c.programName {
            return AnyView(SkeletonPostCard(programName: name, programImageUrl: c.programImageUrl).padding(16))
        }
        return AnyView(SkeletonPostCard().padding(16))

    // MARK: - Feedback (Components/Feedback/)

    case "component.ConfirmationOverlay":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ConfirmationOverlay: missing state.component")
        }
        let confStyle: ConfirmationOverlayStyle = {
            switch c.style {
            case "error": return .error
            case "warning": return .warning
            case "info": return .info
            default: return .success
            }
        }()
        return AnyView(
            ConfirmationOverlay(
                style: confStyle,
                message: AttributedString.safeMarkdown(c.message ?? ""),
                buttonLabel: c.buttonLabel ?? "OK",
                isProcessing: .constant(c.isProcessing ?? false),
                processingMessage: c.processingMessage ?? "Processing...",
                onDismiss: {}
            )
        )

    case "component.ErrorBanner":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.ErrorBanner: missing state.component")
        }
        return AnyView(
            ErrorBanner(
                message: c.message ?? "",
                onRetry: (c.hasRetry ?? false) ? {} : nil,
                onDismiss: {}
            )
        )

    case "component.UnenrollConfirmation":
        // UnenrollConfirmation is a namespace of static helpers that presents a
        // ConfirmationOverlay (style .warning, "Done" button) via OverlayManager.
        // Render that resulting overlay directly using its successMessage builder.
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.UnenrollConfirmation: missing state.component")
        }
        let unenrollOption: UnenrollOption = (c.option == "cancelFuture") ? .cancelFuture : .fullRemoval
        return AnyView(
            ConfirmationOverlay(
                style: .warning,
                message: UnenrollConfirmation.successMessage(
                    option: unenrollOption,
                    programName: c.programName ?? ""
                ),
                buttonLabel: "Done",
                isProcessing: .constant(c.isProcessing ?? false),
                processingMessage: "Processing unenrollment",
                onDismiss: {}
            )
        )

    // ===== LayoutOverlayVideo =====
    // MARK: - Layout / Overlays / Video
    //
    // Paste these cases INSIDE the `switch fixture.view` in ViewRegistry.swift.
    // They depend on three new CaptureComponent fields + two new sub-structs —
    // see LayoutOverlayVideo.fields.txt.

    case "component.SearchableList":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SearchableList: missing state.component")
        }
        // Build literal Identifiable & Hashable items from the fixture.
        struct CaptureSearchRow: Identifiable, Hashable {
            let id = UUID()
            let name: String
            let hasPhone: Bool
        }
        let searchRows: [CaptureSearchRow] = (c.searchItems ?? []).map {
            CaptureSearchRow(name: $0.name ?? "", hasPhone: $0.hasPhone ?? false)
        }
        // GeometryReader/ZStack-based — fill-space, so give it an explicit height.
        return AnyView(
            SearchableList(
                items: searchRows,
                filterPredicate: { (row: CaptureSearchRow, query: String) in
                    row.name.lowercased().contains(query.lowercased())
                },
                placeholder: c.placeholder ?? "Search",
                showAlphabetScrubber: c.showAlphabetScrubber ?? false,
                sectionKeyPath: (c.showAlphabetScrubber ?? false) ? \CaptureSearchRow.name : nil,
                autoFocusSearch: false
            ) { (row: CaptureSearchRow) in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                    Spacer()
                    if row.hasPhone {
                        Text("Invite")
                            .font(Typography.s12)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .frame(height: 640)
        )

    case "component.SectionedTableView":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.SectionedTableView: missing state.component")
        }
        // UIViewControllerRepresentable (UITableViewController) — renders standalone
        // with literal data; fill-space so give it an explicit height.
        struct CaptureTableRow: Identifiable, Hashable {
            let id = UUID()
            let name: String
        }
        let tableSections: [(String, [CaptureTableRow])] = (c.tableSections ?? []).map { sec in
            (sec.title ?? "", (sec.items ?? []).map { CaptureTableRow(name: $0.name ?? "") })
        }
        return AnyView(
            SectionedTableView(
                sections: tableSections,
                sectionIndexTitles: tableSections.map { $0.0 },
                topInset: 16
            ) { (row: CaptureTableRow) in
                HStack {
                    Text(row.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(16)
            }
            .frame(height: 480)
            .padding(16)
        )

    case "component.StylePickerMenu":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.StylePickerMenu: missing state.component")
        }
        // Pure SwiftUI menu content. currentStyle from c.style ("bold" | "highlight" | nil).
        let pickerStyle: ReadBlockSelectionStyle? = {
            switch c.style {
            case "bold": return .bold
            case "highlight": return .highlight
            default: return nil
            }
        }()
        return AnyView(
            StylePickerMenu(
                snippet: c.text ?? "",
                currentStyle: pickerStyle,
                onSelect: { _ in }
            )
            .padding(.vertical, 16)
        )

    case "component.VideoGridItem":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.VideoGridItem: missing state.component")
        }
        // .video(VideoAsset) requires a real PHAsset (no way to fabricate in tests).
        // Only the .camera case stands alone.
        guard c.type != "video" else {
            // SKIPPED component.VideoGridItem (Video variant): .video(VideoAsset)
            // needs a live PhotoKit PHAsset; cannot construct one in a unit test.
            throw ViewRegistryError.unknownView("component.VideoGridItem: video variant needs a live PHAsset (PhotoKit) — skipped")
        }
        return AnyView(
            VideoGridItem(
                type: .camera,
                isSelected: c.isSelected ?? false,
                size: CGFloat(c.sizePx ?? 100),
                onTap: {}
            )
            .padding(16)
        )

    case "component.VideoPreview":
        // SelectedAsset/recordedVideoURL both require live media (PHAsset / AVAsset);
        // there's no hook to inject a UIImage thumbnail. Render the empty-placeholder
        // chrome (both nil) at a fixed frame — represents the "Select a video" state.
        return AnyView(
            VideoPreview(
                selectedAsset: nil,
                recordedVideoURL: nil,
                onTap: {}
            )
            .frame(width: 330, height: 440)
            .padding(16)
        )

    case "component.VideoSourceBar":
        guard let c = fixture.state?.component else {
            throw ViewRegistryError.unknownView("component.VideoSourceBar: missing state.component")
        }
        let videoSource: VideoSource = {
            switch c.currentSource {
            case "favorites": return .favorites
            case "makeReady": return .makeReady
            case "allAlbums": return .allAlbums
            default: return .videos
            }
        }()
        return AnyView(
            VideoSourceBar(
                currentSource: .constant(videoSource),
                onSourceTap: {},
                onMakeReadyTap: {}
            )
            .padding(.vertical, 16)
        )

    default:
        throw ViewRegistryError.unknownView(fixture.view)
    }
}


// SearchField takes a `@FocusState.Binding`, which can't be faked with
// `.constant(_)`, so this tiny wrapper owns real `@FocusState`/`@State` to
// render it statically for capture.
struct CaptureSearchFieldWrapper: View {
    let isActive: Bool
    let searchText: String
    let placeholder: String

    @State private var activeState: Bool
    @State private var textState: String
    @FocusState private var focused: Bool

    init(isActive: Bool, searchText: String, placeholder: String) {
        self.isActive = isActive
        self.searchText = searchText
        self.placeholder = placeholder
        _activeState = State(initialValue: isActive)
        _textState = State(initialValue: searchText)
    }

    var body: some View {
        SearchField(
            isActive: $activeState,
            searchText: $textState,
            isFocused: $focused,
            placeholder: placeholder
        )
    }
}

