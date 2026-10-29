import Foundation

/// ui2-enrollments-browse §Contract: a `{id, name}` reference — a draft's `createdBy`, a feed
/// group's `leader`, a feed filter option. `name` is optional so a null never fails the decode.
struct EnrollmentWireRef: Codable, Equatable, Hashable {
    let id: String
    let name: String?
}

/// ui2-enrollments-browse §Contract **Draft** — the server row behind a checklist (SC1). Unset
/// fields are null; dates are `yyyy-MM-dd`; `createdAt`/`updatedAt` stay ISO text (compared as text,
/// the server writes one format).
struct DraftWire: Codable, Equatable {
    let id: String
    let groupId: String
    let studyProgramId: String
    let startDate: String?
    let enabledDays: [String]?
    let overriddenDates: [String]?
    let scheduleDates: [String]?
    let smsTime: String?
    let timezone: String?
    let syncMode: String?
    let lessonAccess: String?
    let createdBy: EnrollmentWireRef?
    let createdAt: String
    let updatedAt: String
}
