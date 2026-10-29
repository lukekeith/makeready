import Foundation

/// ui2-enrollments-browse §Contract `GET /api/enrollments-feed` query (D8, D13, D15; no `q` — D27).
/// The `AppState.enrollmentFeed` key: one cached answer per filter.
struct EnrollmentFeedFilter: Hashable {
    enum Status: String, CaseIterable {
        case active, upcoming, completed, draft, all
        /// D8: the chip and menu text, in the menu's order.
        var label: String {
            switch self {
            case .active: return "Active"
            case .upcoming: return "Upcoming"
            case .completed: return "Completed"
            case .draft: return "Draft"
            case .all: return "All"
            }
        }
    }

    var orgId: String?
    var groupId: String?
    var leaderId: String?
    var status: Status = .active

    /// The request path; `tz` is the device zone (D8's "today").
    func path(timeZone: TimeZone) -> String {
        var c = URLComponents()
        c.path = "/api/enrollments-feed"
        c.queryItems = [
            orgId.map { URLQueryItem(name: "orgId", value: $0) },
            groupId.map { URLQueryItem(name: "groupId", value: $0) },
            leaderId.map { URLQueryItem(name: "leaderId", value: $0) },
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "tz", value: timeZone.identifier)
        ].compactMap { $0 }
        return c.string ?? c.path
    }
}

/// §Contract Item's `studyProgram`.
struct EnrollmentFeedProgram: Decodable, Equatable {
    let id: String
    let name: String
    let coverImageUrl: String?
}

/// §Contract **Item** — `kind` "enrollment" (the numbers set) or "draft" (`draft` set).
/// Dates are `yyyy-MM-dd` in the enrollment's zone; `enrolledAt`/`recencyAt` ISO instants.
struct EnrollmentFeedItem: Decodable, Equatable {
    let kind: String
    let id: String?
    let draft: DraftWire?
    let studyProgram: EnrollmentFeedProgram
    let startDate: String?
    let endDate: String?
    let enrolledAt: String?
    let progress: Double?
    let completedMembers: Int?
    let memberCount: Int?
    let plannedMinutes: Int?
    let recencyAt: String
}

/// §Contract `sections[]` — one group (D7, D13) and its items, ordered per D17.
struct EnrollmentFeedSection: Decodable, Equatable {
    struct GroupRef: Decodable, Equatable {
        let id: String
        let name: String
        let coverImageUrl: String?
        let leader: EnrollmentWireRef?
    }
    let group: GroupRef
    let items: [EnrollmentFeedItem]
}

/// §Contract `options` — over scope + orgId + status, never narrowed by group or leader.
struct EnrollmentFeedOptions: Decodable, Equatable {
    let groups: [EnrollmentWireRef]
    let leaders: [EnrollmentWireRef]
}

/// One feed answer, stored per `EnrollmentFeedFilter`.
struct EnrollmentFeed: Equatable {
    let sections: [EnrollmentFeedSection]
    let options: EnrollmentFeedOptions
}

/// §Contract **Home** — `GET /api/enrollments/:id/home` (D20).
struct EnrollmentHome: Decodable, Equatable {
    struct ProgramRef: Decodable, Equatable {
        let id: String
        let name: String
        let description: String?
        let coverImageUrl: String?
        let authorName: String?
    }
    struct GroupRef: Decodable, Equatable {
        let id: String
        let name: String
        let leader: EnrollmentWireRef?
    }
    struct Day: Decodable, Equatable {
        let scheduleId: String
        let date: String
        let percent: Double
        let lessonCount: Int
        let plannedMinutes: Int
    }
    struct Activity: Decodable, Equatable {
        let id: String
        let type: String
        let title: String?
        let thumbnailUrl: String?
    }
    struct Lesson: Decodable, Equatable {
        let scheduleId: String
        let dayNumber: Int
        let title: String?
        let date: String
        let progress: Double?
        let activities: [Activity]
    }

    let id: String
    let studyProgram: ProgramRef
    let group: GroupRef
    let memberCount: Int
    let enrolledAt: String
    let startDate: String
    let endDate: String
    let lessonAccess: String?
    let smsTime: String?
    let timezone: String?
    let days: [Day]
    let lessons: [Lesson]

    static func path(id: String, timeZone: TimeZone) -> String {
        var c = URLComponents()
        c.path = "/api/enrollments/\(id)/home"
        c.queryItems = [URLQueryItem(name: "tz", value: timeZone.identifier)]
        return c.string ?? c.path
    }
}
