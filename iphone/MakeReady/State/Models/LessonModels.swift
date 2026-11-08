//
//  LessonModels.swift
//  MakeReady
//
//  The enrollment side of a lesson: a scheduled lesson points at the lesson version the group
//  currently reads (text-activity §Contract, the `lessonSchedules[]` rows).
//

import Foundation

/// One `lessonSchedules[]` row — a dated lesson of an enrollment. Its activities are the rail
/// summaries of the version it points at, where `kind` is the activity type.
///
/// Decodes today's keys. `dayNumber` is the lesson's position, carried under `lesson.dayNumber`
/// on the wire; the row re-encodes to the same shape for the disk cache.
struct ScheduledLesson: Codable, Identifiable, Hashable {
    let id: String
    var code: String?
    let enrollmentId: String
    let lessonId: String
    let scheduledDate: Date
    var smsSentAt: Date?
    var title: String?
    var estimatedMinutes: Int?
    var currentVersionId: String?
    var removedAt: Date?
    var dayNumber: Int
    var activities: [ActivitySummary]

    enum CodingKeys: String, CodingKey {
        case id, code, enrollmentId, lessonId, scheduledDate, smsSentAt
        case title, estimatedMinutes, currentVersionId, removedAt
        case scheduledActivities, lesson
    }

    private enum LessonKeys: String, CodingKey {
        case dayNumber
    }

    init(
        id: String, code: String? = nil, enrollmentId: String, lessonId: String, scheduledDate: Date,
        smsSentAt: Date? = nil, title: String? = nil, estimatedMinutes: Int? = nil,
        currentVersionId: String? = nil, removedAt: Date? = nil, dayNumber: Int = 1,
        activities: [ActivitySummary] = []
    ) {
        self.id = id
        self.code = code
        self.enrollmentId = enrollmentId
        self.lessonId = lessonId
        self.scheduledDate = scheduledDate
        self.smsSentAt = smsSentAt
        self.title = title
        self.estimatedMinutes = estimatedMinutes
        self.currentVersionId = currentVersionId
        self.removedAt = removedAt
        self.dayNumber = dayNumber
        self.activities = activities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        enrollmentId = try c.decode(String.self, forKey: .enrollmentId)
        lessonId = try c.decode(String.self, forKey: .lessonId)
        scheduledDate = try c.decode(Date.self, forKey: .scheduledDate)
        smsSentAt = try c.decodeIfPresent(Date.self, forKey: .smsSentAt)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        estimatedMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        currentVersionId = try c.decodeIfPresent(String.self, forKey: .currentVersionId)
        removedAt = try c.decodeIfPresent(Date.self, forKey: .removedAt)
        activities = try c.decodeIfPresent([ActivitySummary].self, forKey: .scheduledActivities) ?? []
        let lesson = try? c.nestedContainer(keyedBy: LessonKeys.self, forKey: .lesson)
        dayNumber = (try lesson?.decodeIfPresent(Int.self, forKey: .dayNumber)) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encode(enrollmentId, forKey: .enrollmentId)
        try c.encode(lessonId, forKey: .lessonId)
        try c.encode(scheduledDate, forKey: .scheduledDate)
        try c.encodeIfPresent(smsSentAt, forKey: .smsSentAt)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(estimatedMinutes, forKey: .estimatedMinutes)
        try c.encodeIfPresent(currentVersionId, forKey: .currentVersionId)
        try c.encodeIfPresent(removedAt, forKey: .removedAt)
        try c.encode(activities, forKey: .scheduledActivities)
        var lesson = c.nestedContainer(keyedBy: LessonKeys.self, forKey: .lesson)
        try lesson.encode(dayNumber, forKey: .dayNumber)
    }
}
