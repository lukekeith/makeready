//
//  GlobalSearchEngine.swift
//  MakeReady
//
//  Search logic using GET /api/search for server-side search
//  and GET /api/activities for recent items.
//

import Foundation

// MARK: - Search Result Category

enum SearchResultCategory: String, CaseIterable, Identifiable {
    case program
    case group
    case lesson
    case member
    case video
    case enrollment
    case template
    case event
    case post
    case notification

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .program: return "Programs"
        case .group: return "Groups"
        case .lesson: return "Lessons"
        case .member: return "Members"
        case .video: return "Videos"
        case .enrollment: return "Enrollments"
        case .template: return "Templates"
        case .event: return "Events"
        case .post: return "Posts"
        case .notification: return "Notifications"
        }
    }

    var icon: String {
        switch self {
        case .program: return "text.book.closed.fill"
        case .group: return "person.3.fill"
        case .lesson: return "list.bullet.rectangle.fill"
        case .member: return "person.fill"
        case .video: return "play.rectangle.fill"
        case .enrollment: return "calendar.badge.clock"
        case .template: return "doc.text.fill"
        case .event: return "calendar"
        case .post: return "text.bubble.fill"
        case .notification: return "bell.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .program: return 0
        case .group: return 1
        case .lesson: return 2
        case .member: return 3
        case .video: return 4
        case .enrollment: return 5
        case .event: return 6
        case .post: return 7
        case .template: return 8
        case .notification: return 9
        }
    }
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id: String
    let category: SearchResultCategory
    let title: String
    let subtitle: String?
    let timestamp: String?
    let imageURL: String?
    let initials: String?
    let sfSymbol: String?
    let entityId: String
    let parentId: String?
    let playbackUrl: String?

    init(
        id: String, category: SearchResultCategory, title: String,
        subtitle: String?, timestamp: String?, imageURL: String?,
        initials: String?, sfSymbol: String?, entityId: String,
        parentId: String?, playbackUrl: String? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.imageURL = imageURL
        self.initials = initials
        self.sfSymbol = sfSymbol
        self.entityId = entityId
        self.parentId = parentId
        self.playbackUrl = playbackUrl
    }
}

// MARK: - Search Results Container

struct CategoryResults {
    let results: [SearchResult]
    let totalCount: Int
}

// MARK: - API Response Models

private struct SearchAPIResponse: Codable {
    let success: Bool
    let query: String?
    let results: SearchAPIResults?
    let counts: [String: Int]?
}

private struct SearchAPIResults: Codable {
    let groups: [APIGroupResult]?
    let programs: [APIProgramResult]?
    let templates: [APITemplateResult]?
    let videos: [APIVideoResult]?
    let events: [APIEventResult]?
    let posts: [APIPostResult]?
    let members: [APIMemberResult]?
    let lessons: [APILessonResult]?
}

private struct APIGroupResult: Codable {
    let id: String
    let name: String
    let description: String?
    let code: String?
    let coverImageUrl: String?
}

private struct APIProgramResult: Codable {
    let id: String
    let name: String
    let description: String?
    let coverImageUrl: String?
    let isPublished: Bool?
    let days: Int?
}

private struct APITemplateResult: Codable {
    let id: String
    let name: String
    let description: String?
}

private struct APISearchLink: Codable {
    let type: String    // PROGRAM, LESSON, GROUP
    let id: String
    let name: String
    let imageUrl: String?
}

private struct APIVideoResult: Codable {
    let id: String
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let playbackUrl: String?
    let status: String?
    let duration: Int?
    let links: [APISearchLink]?
}

private struct APIEventResult: Codable {
    let id: String
    let title: String
    let description: String?
    let coverImageUrl: String?
    let date: String?
    let locationName: String?
    let type: String?
}

private struct APIPostResult: Codable {
    let id: String
    let title: String?
    let content: String?
    let imageUrl: String?
    let type: String?
}

private struct APIMemberResult: Codable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let phoneNumber: String?
    let profilePicture: String?
}

private struct APILessonResult: Codable {
    let id: String
    let title: String?
    let dayNumber: Int?
    let studyProgramId: String?
    let studyProgram: APILessonProgram?
}

private struct APILessonProgram: Codable {
    let name: String
}

// MARK: - User Activity (from GET /api/activities)

struct UserActivity: Codable, Identifiable {
    let id: String
    let actorId: String
    let action: String
    let resourceType: String
    let resourceId: String
    let resourceName: String
    let organizationId: String?
    let createdAt: Date
}

struct UserActivityResponse: Codable {
    let success: Bool
    let activities: [UserActivity]?
}

// MARK: - Global Search Engine

struct GlobalSearchEngine {

    /// Format a date as relative time string
    private static func relativeTime(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        let weeks = days / 7
        if weeks < 4 { return "\(weeks)w ago" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Build a subtitle for video search results from duration and linked lessons/programs.
    /// - Single lesson: "1:30 · Day 3 — Romans in 30 Days"
    /// - Multiple lessons: "1:30 · Used in 2 lessons"
    /// - No links: "1:30 · Library"
    private static func videoSubtitle(duration: Int?, links: [APISearchLink]?) -> String {
        var parts: [String] = []

        if let d = duration, d > 0 {
            let mins = d / 60
            let secs = d % 60
            parts.append(String(format: "%d:%02d", mins, secs))
        }

        let lessons = links?.filter { $0.type == "LESSON" } ?? []
        let programs = links?.filter { $0.type == "PROGRAM" } ?? []

        if lessons.count == 1 {
            let lessonName = lessons[0].name
            if let program = programs.first {
                parts.append("\(lessonName) — \(program.name)")
            } else {
                parts.append(lessonName)
            }
        } else if lessons.count > 1 {
            parts.append("Used in \(lessons.count) lessons")
        } else {
            parts.append("Library")
        }

        return parts.joined(separator: " · ")
    }

    // MARK: - Server-Side Search (GET /api/search)

    static func search(query: String) async -> [SearchResultCategory: CategoryResults] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [:] }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let api = APIClient.shared

        do {
            let response: SearchAPIResponse = try await api.get(
                "/api/search?q=\(encoded)&limit=5&links=VIDEO",
                responseType: SearchAPIResponse.self
            )
            guard response.success, let apiResults = response.results else { return [:] }
            return mapAPIResults(apiResults, counts: response.counts)
        } catch {
            NSLog("⚠️ GlobalSearchEngine: Server search failed: \(error)")
            return [:]
        }
    }

    private static func mapAPIResults(
        _ api: SearchAPIResults,
        counts: [String: Int]?
    ) -> [SearchResultCategory: CategoryResults] {
        var results: [SearchResultCategory: CategoryResults] = [:]

        // Programs
        if let programs = api.programs, !programs.isEmpty {
            let items = programs.map { p in
                let subtitle = p.days.map { "\($0) days" }
                return SearchResult(
                    id: "program-\(p.id)", category: .program,
                    title: p.name, subtitle: subtitle, timestamp: nil,
                    imageURL: p.coverImageUrl, initials: nil,
                    sfSymbol: "text.book.closed.fill", entityId: p.id, parentId: nil
                )
            }
            results[.program] = CategoryResults(results: items, totalCount: counts?["programs"] ?? items.count)
        }

        // Groups
        if let groups = api.groups, !groups.isEmpty {
            let items = groups.map { g in
                SearchResult(
                    id: "group-\(g.id)", category: .group,
                    title: g.name, subtitle: g.description, timestamp: nil,
                    imageURL: g.coverImageUrl, initials: nil,
                    sfSymbol: "person.3.fill", entityId: g.id, parentId: nil
                )
            }
            results[.group] = CategoryResults(results: items, totalCount: counts?["groups"] ?? items.count)
        }

        // Lessons
        if let lessons = api.lessons, !lessons.isEmpty {
            let items = lessons.map { l in
                let day = l.dayNumber ?? 0
                let programName = l.studyProgram?.name
                let subtitle = "Day \(day)" + (programName.map { " - \($0)" } ?? "")
                return SearchResult(
                    id: "lesson-\(l.id)", category: .lesson,
                    title: l.title ?? "Day \(day)", subtitle: subtitle, timestamp: nil,
                    imageURL: nil, initials: nil,
                    sfSymbol: "list.bullet.rectangle.fill", entityId: l.id, parentId: l.studyProgramId
                )
            }
            results[.lesson] = CategoryResults(results: items, totalCount: counts?["lessons"] ?? items.count)
        }

        // Members
        if let members = api.members, !members.isEmpty {
            let items = members.map { m in
                let name = [m.firstName, m.lastName].compactMap { $0 }.joined(separator: " ")
                return SearchResult(
                    id: "member-\(m.id)", category: .member,
                    title: name.isEmpty ? "Unknown" : name, subtitle: m.email, timestamp: nil,
                    imageURL: m.profilePicture, initials: nil,
                    sfSymbol: nil, entityId: m.id, parentId: nil
                )
            }
            results[.member] = CategoryResults(results: items, totalCount: counts?["members"] ?? items.count)
        }

        // Videos
        if let videos = api.videos, !videos.isEmpty {
            let items = videos.map { v in
                let subtitle = videoSubtitle(duration: v.duration, links: v.links)
                return SearchResult(
                    id: "video-\(v.id)", category: .video,
                    title: v.title ?? "Untitled Video",
                    subtitle: subtitle,
                    timestamp: nil,
                    imageURL: v.thumbnailUrl, initials: nil,
                    sfSymbol: "play.rectangle.fill", entityId: v.id, parentId: nil,
                    playbackUrl: v.playbackUrl
                )
            }
            results[.video] = CategoryResults(results: items, totalCount: counts?["videos"] ?? items.count)
        }

        // Events
        if let events = api.events, !events.isEmpty {
            let items = events.map { e in
                var subtitle = e.locationName
                if subtitle == nil, let dateStr = e.date {
                    subtitle = String(dateStr.prefix(10))
                }
                return SearchResult(
                    id: "event-\(e.id)", category: .event,
                    title: e.title, subtitle: subtitle, timestamp: nil,
                    imageURL: e.coverImageUrl, initials: nil,
                    sfSymbol: "calendar", entityId: e.id, parentId: nil
                )
            }
            results[.event] = CategoryResults(results: items, totalCount: counts?["events"] ?? items.count)
        }

        // Posts
        if let posts = api.posts, !posts.isEmpty {
            let items = posts.map { p in
                let subtitle: String? = p.content.flatMap { $0.isEmpty ? nil : String($0.prefix(60)) }
                return SearchResult(
                    id: "post-\(p.id)", category: .post,
                    title: p.title ?? "Post", subtitle: subtitle, timestamp: nil,
                    imageURL: p.imageUrl, initials: nil,
                    sfSymbol: "text.bubble.fill", entityId: p.id, parentId: nil
                )
            }
            results[.post] = CategoryResults(results: items, totalCount: counts?["posts"] ?? items.count)
        }

        // Templates
        if let templates = api.templates, !templates.isEmpty {
            let items = templates.map { t in
                let subtitle: String? = t.description.flatMap { $0.isEmpty ? nil : String($0.prefix(60)) }
                return SearchResult(
                    id: "template-\(t.id)", category: .template,
                    title: t.name, subtitle: subtitle, timestamp: nil,
                    imageURL: nil, initials: nil,
                    sfSymbol: "doc.text.fill", entityId: t.id, parentId: nil
                )
            }
            results[.template] = CategoryResults(results: items, totalCount: counts?["templates"] ?? items.count)
        }

        return results
    }

    // MARK: - Recent Items (from GET /api/activities)

    @MainActor
    static func fetchRecentItems(
        in state: AppState,
        maxPerCategory: Int = 3
    ) async -> [SearchResultCategory: CategoryResults] {
        let api = APIClient.shared
        do {
            let response: UserActivityResponse = try await api.get(
                "/api/activities?action=CREATED,UPDATED,PUBLISHED&limit=50",
                responseType: UserActivityResponse.self
            )
            guard let activities = response.activities else { return [:] }

            var seen = Set<String>()
            var deduped: [UserActivity] = []
            for activity in activities {
                let key = "\(activity.resourceType)-\(activity.resourceId)"
                if seen.insert(key).inserted {
                    deduped.append(activity)
                }
            }

            return buildRecentResults(from: deduped, state: state, maxPerCategory: maxPerCategory)
        } catch {
            NSLog("⚠️ GlobalSearchEngine: Failed to fetch recent activities: \(error)")
            return [:]
        }
    }

    private static func categoryForResourceType(_ type: String) -> SearchResultCategory? {
        switch type.uppercased() {
        case "PROGRAM": return .program
        case "GROUP": return .group
        case "LESSON": return .lesson
        case "ENROLLMENT": return .enrollment
        case "VIDEO": return .video
        case "TEMPLATE": return .template
        case "EVENT": return .event
        default: return nil
        }
    }

    @MainActor
    private static func buildRecentResults(
        from activities: [UserActivity],
        state: AppState,
        maxPerCategory: Int
    ) -> [SearchResultCategory: CategoryResults] {
        var grouped: [SearchResultCategory: [SearchResult]] = [:]

        for activity in activities {
            guard let category = categoryForResourceType(activity.resourceType) else { continue }
            if (grouped[category]?.count ?? 0) >= maxPerCategory { continue }

            if let result = recentResult(for: activity, category: category, state: state) {
                grouped[category, default: []].append(result)
            }
        }

        var results: [SearchResultCategory: CategoryResults] = [:]
        for (category, items) in grouped {
            results[category] = CategoryResults(results: items, totalCount: items.count)
        }
        return results
    }

    @MainActor
    private static func recentResult(
        for activity: UserActivity,
        category: SearchResultCategory,
        state: AppState
    ) -> SearchResult? {
        let id = activity.resourceId
        let time = relativeTime(from: activity.createdAt)

        switch category {
        case .program:
            guard let program = state.programs[id] else { return nil }
            return SearchResult(
                id: "program-\(id)", category: .program,
                title: program.name,
                subtitle: "\(program.days) days, \(program._count?.lessons ?? program.days) lessons",
                timestamp: time,
                imageURL: program.coverImageUrl, initials: nil,
                sfSymbol: "text.book.closed.fill", entityId: id, parentId: nil
            )

        case .group:
            guard let group = state.groups[id] else { return nil }
            return SearchResult(
                id: "group-\(id)", category: .group,
                title: group.name,
                subtitle: "\(group.memberCount) members",
                timestamp: time,
                imageURL: group.coverImageUrl, initials: nil,
                sfSymbol: "person.3.fill", entityId: id, parentId: nil
            )

        case .enrollment:
            guard let enrollment = state.enrollments[id], enrollment.isActive else { return nil }
            let groupName = state.groups[enrollment.groupId]?.name ?? "Unknown group"
            return SearchResult(
                id: "enrollment-\(id)", category: .enrollment,
                title: enrollment.studyProgram?.name ?? activity.resourceName,
                subtitle: "\(groupName) - \(enrollment.dateRangeString)",
                timestamp: time,
                imageURL: enrollment.studyProgram?.coverImageUrl, initials: nil,
                sfSymbol: "calendar.badge.clock", entityId: id, parentId: enrollment.groupId
            )

        case .video:
            let video = state.videos[id]
            guard video?.isActive != false else { return nil }
            let parts = [video?.formattedDuration, video?.videoStatus.displayName].compactMap { $0 }
            return SearchResult(
                id: "video-\(id)", category: .video,
                title: video?.displayTitle ?? activity.resourceName,
                subtitle: parts.isEmpty ? nil : parts.joined(separator: " - "),
                timestamp: time,
                imageURL: video?.thumbnailUrl, initials: nil,
                sfSymbol: "play.rectangle.fill", entityId: id, parentId: nil
            )

        case .lesson:
            let lesson = state.lessons[id]
            let programName = lesson?.studyProgramId.flatMap { state.programs[$0] }?.name
            return SearchResult(
                id: "lesson-\(id)", category: .lesson,
                title: lesson?.title ?? activity.resourceName,
                subtitle: lesson.map { "Day \($0.dayNumber)" + (programName.map { " - \($0)" } ?? "") },
                timestamp: time,
                imageURL: nil, initials: nil,
                sfSymbol: "list.bullet.rectangle.fill", entityId: id, parentId: lesson?.studyProgramId
            )

        case .template:
            let template = state.templates[id]
            return SearchResult(
                id: "template-\(id)", category: .template,
                title: template?.name ?? activity.resourceName,
                subtitle: template?.description.flatMap { $0.isEmpty ? nil : String($0.prefix(60)) },
                timestamp: time,
                imageURL: nil, initials: nil,
                sfSymbol: "doc.text.fill", entityId: id, parentId: nil
            )

        default:
            return nil
        }
    }
}
