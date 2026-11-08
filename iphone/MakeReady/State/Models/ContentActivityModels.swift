//
//  ContentActivityModels.swift
//  MakeReady
//
//  The content-activity wire shapes (SPEC §Contract "Shapes"): activities, the lesson version that
//  holds them, the rail's summaries and the media map that resolves a document's media ids.
//

import Foundation

/// One activity of a lesson version. `document` is the activity's whole content (02-content-schema §2).
struct ContentActivity: Codable, Identifiable, Hashable {
    let id: String
    let lessonVersionId: String
    let activityKey: String
    let position: Int
    let kind: String
    let title: String
    let document: ActivityDocument
    let estimatedSeconds: Int?
}

/// An activity as the program home carries it; `document` feeds the rail's thumbnail slides.
struct ActivitySummary: Codable, Identifiable, Hashable {
    let id: String
    let activityKey: String
    let position: Int
    let kind: String
    let title: String
    let document: ActivityDocument
}

/// A lesson's content at one point in time: a mutable draft or a frozen published version.
struct LessonVersion: Codable, Identifiable, Hashable {
    enum Status: String, Codable, Hashable {
        case draft = "DRAFT"
        case published = "PUBLISHED"
    }

    let id: String
    let lessonId: String
    /// Set when a group's enrollment owns this version; nil for program versions.
    let enrollmentId: String?
    let number: Int
    let status: Status
    let title: String?
    let estimatedSeconds: Int?
    let publishedAt: Date?

    init(id: String, lessonId: String, enrollmentId: String?, number: Int, status: Status,
         title: String?, estimatedSeconds: Int?, publishedAt: Date?) {
        self.id = id
        self.lessonId = lessonId
        self.enrollmentId = enrollmentId
        self.number = number
        self.status = status
        self.title = title
        self.estimatedSeconds = estimatedSeconds
        self.publishedAt = publishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, lessonId, enrollmentId, number, status, title, estimatedSeconds, publishedAt
    }

    /// The server writes JavaScript ISO dates with fractional seconds, which `.iso8601` rejects,
    /// so the date is read as text and parsed with and without them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        lessonId = try c.decode(String.self, forKey: .lessonId)
        enrollmentId = try c.decodeIfPresent(String.self, forKey: .enrollmentId)
        number = try c.decode(Int.self, forKey: .number)
        status = try c.decode(Status.self, forKey: .status)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        estimatedSeconds = try c.decodeIfPresent(Int.self, forKey: .estimatedSeconds)
        if let text = try c.decodeIfPresent(String.self, forKey: .publishedAt) {
            guard let date = Self.parseDate(text) else {
                throw DecodingError.dataCorruptedError(forKey: .publishedAt, in: c, debugDescription: "Bad date: \(text)")
            }
            publishedAt = date
        } else {
            publishedAt = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(lessonId, forKey: .lessonId)
        try c.encode(enrollmentId, forKey: .enrollmentId)
        try c.encode(number, forKey: .number)
        try c.encode(status, forKey: .status)
        try c.encode(title, forKey: .title)
        try c.encode(estimatedSeconds, forKey: .estimatedSeconds)
        try c.encode(publishedAt.map { Self.fractionalFormatter().string(from: $0) }, forKey: .publishedAt)
    }

    private static func fractionalFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    private static func parseDate(_ text: String) -> Date? {
        fractionalFormatter().date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

/// What a `MediaMap` holds for one media id. `kind` is "image" or "video".
struct MediaMapEntry: Codable, Hashable {
    let url: String
    let width: Int?
    let height: Int?
    let kind: String
    let playbackUrl: String?
    let posterUrl: String?
    let durationSeconds: Double?
    let uploaderName: String?
}

/// The response of `GET /api/lessons/:id/draft` and `GET /api/lesson-versions/:id`.
struct LessonVersionPayload: Codable, Hashable {
    let version: LessonVersion
    let activities: [ContentActivity]
    let media: [String: MediaMapEntry]
}
