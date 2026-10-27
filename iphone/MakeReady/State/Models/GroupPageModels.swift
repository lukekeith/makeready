//
//  GroupPageModels.swift
//  MakeReady
//
//  ui2-groups-browse: the group page's payloads that have no model yet — the next lesson
//  (T11, D17) and the merged group history (T12, D15). Every key decodes leniently: these are
//  read by a released app, so a missing key is a default, never a failed decode.
//

import Foundation

// MARK: - GET /api/groups/:id/next-study (T11, D17)

/// `{success, study}`. A 204 (no lesson ahead) has no body and never reaches this decode —
/// `GroupActions.loadNextStudy` reads the empty body as "no lesson".
struct NextStudyResponse: Codable, Equatable {
    var success: Bool = false
    var study: NextStudy?
}

extension NextStudyResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        study = try c.decodeIfPresent(NextStudy.self, forKey: .study)
    }
}

/// The group's next scheduled lesson (a `LessonSchedule`). `scheduledDate` stays the wire's ISO
/// string (the ui2-members F7 rule): the mapper reads its UTC calendar date (D17).
struct NextStudy: Codable, Equatable {
    var id: String = ""
    var code: String?
    var dayNumber: Int = 0
    var scheduledDate: String = ""
    /// SC5: `LessonSchedule.title`; nil → the card shows "Day «dayNumber»" (D17).
    var title: String?
    var studyProgram: NextStudyProgram?
    var activities: [NextStudyActivity] = []
}

extension NextStudy {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        code = try c.decodeIfPresent(String.self, forKey: .code)
        dayNumber = try c.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 0
        scheduledDate = try c.decodeIfPresent(String.self, forKey: .scheduledDate) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        studyProgram = try c.decodeIfPresent(NextStudyProgram.self, forKey: .studyProgram)
        activities = try c.decodeIfPresent([NextStudyActivity].self, forKey: .activities) ?? []
    }
}

struct NextStudyProgram: Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var description: String?
    var coverImageUrl: String?
}

extension NextStudyProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
    }
}

/// One scheduled activity of the next lesson. SC5: `thumbnailUrl` = the YouTube / video
/// thumbnail, else a READ activity's first image, else nil.
struct NextStudyActivity: Codable, Equatable {
    var id: String = ""
    var type: String = ""
    var orderNumber: Int = 0
    var title: String?
    var thumbnailUrl: String?
}

extension NextStudyActivity {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        orderNumber = try c.decodeIfPresent(Int.self, forKey: .orderNumber) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
    }
}

// MARK: - GET /api/groups/:id/history (T12, D15)

struct GroupHistoryResponse: Codable, Equatable {
    var success: Bool = false
    var events: [GroupHistoryEvent] = []
}

extension GroupHistoryResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        events = try c.decodeIfPresent([GroupHistoryEvent].self, forKey: .events) ?? []
    }
}

/// One Timeline row, newest first. `kind` stays a String (member_joined | member_left |
/// join_requested | settings_updated | cover_updated | group_created | event_held) so a kind a
/// released build does not know still decodes; the page renders `text` and `highlight` only.
struct GroupHistoryEvent: Codable, Equatable, Identifiable {
    var id: String = ""
    /// ISO 8601 — kept a String (F7); the mapper parses it for D16's label.
    var occurredAt: String = ""
    var kind: String = ""
    var text: String = ""
    var highlight: String?
}

extension GroupHistoryEvent {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        occurredAt = try c.decodeIfPresent(String.self, forKey: .occurredAt) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        highlight = try c.decodeIfPresent(String.self, forKey: .highlight)
    }
}

// MARK: - The group page's activity series (T13, D21)

/// The two D21 analytics series of one group, per local `yyyy-MM-dd` day — `scheduled_lessons`
/// and `lesson_completions`, each from its own query. A day missing from a map is zero; the
/// mapper zero-fills the window (D13). A failed query leaves its map as it was (D21).
struct GroupChart: Equatable {
    var scheduled: [String: Int] = [:]
    var completed: [String: Int] = [:]
}
