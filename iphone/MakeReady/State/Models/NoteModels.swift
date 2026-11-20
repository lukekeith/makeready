//
//  NoteModels.swift
//  MakeReady
//
//  The leader notes wire types (notes SPEC §Contract `Note`), the list pagination envelope, and D3's
//  client-side sectioning of the notes list.
//

import Foundation

// MARK: - Wire types

/// One link from a note to something else. `refType` is an open string: a value this build has never
/// seen (`"MEMO"` before the memo feature lands, anything later) must still decode.
struct NoteLinkRef: Codable, Identifiable, Equatable {
    let id: String
    let noteId: String
    let refType: String
    let refId: String
}

/// A leader's note as `/api/notes` returns it. Named `StudyNote` after the server model, so it never
/// reads as a generic "note". `createdAt` and `updatedAt` stay the server's ISO strings, verbatim: the
/// app's `.iso8601` coders drop fractional seconds, and `updatedAt` is echoed back as `baseUpdatedAt`
/// (D23).
struct StudyNote: Codable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let type: String
    var content: String
    var title: String?
    var preview: String?
    var contextLabel: String?
    var isActive: Bool
    let createdAt: String
    var updatedAt: String
    var links: [NoteLinkRef]

    /// The row's heading: the server's `title`, else the content's first non-empty line without its
    /// leading `#`s (a string operation, never a markdown parse), else "New Note" (F4).
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        for line in content.split(whereSeparator: \.isNewline) {
            let text = line.drop(while: { $0 == "#" || $0 == " " || $0 == "\t" })
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return "New Note"
    }

    /// `updatedAt` as a `Date` (fractional seconds first, else whole seconds); nil when unparseable.
    var updatedDate: Date? { NoteTimestamp.parse(updatedAt) }
}

/// `GET /api/notes` paging: `{ total, limit, offset, hasMore }`. Not `PaginationInfo`, whose shape differs.
struct NotesPagination: Codable, Equatable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
}

// MARK: - Timestamps

enum NoteTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let whole = ISO8601DateFormatter()

    static func parse(_ iso: String) -> Date? {
        fractional.date(from: iso) ?? whole.date(from: iso)
    }
}

// MARK: - Sectioning (D3)

struct NoteSection: Equatable {
    let title: String
    let notes: [StudyNote]
}

enum NotesSectioning {

    /// Notes newest-edited first, `id` descending as the tiebreak. A note whose `updatedAt` cannot be
    /// parsed sorts last.
    static func newestFirst(_ notes: [StudyNote]) -> [StudyNote] {
        var keyed: [(note: StudyNote, date: Date)] = []
        for note in notes {
            keyed.append((note: note, date: note.updatedDate ?? Date.distantPast))
        }
        keyed.sort { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.note.id > rhs.note.id
        }
        return keyed.map { $0.note }
    }

    /// Today / Yesterday / Previous 7 Days / Previous 30 Days, then one section per earlier month of
    /// `now`'s year (full month name), then one per earlier year. Newest first; empty sections omitted.
    static func sections(_ notes: [StudyNote], now: Date, calendar: Calendar) -> [NoteSection] {
        var sections: [NoteSection] = []
        for note in newestFirst(notes) {
            let title = sectionTitle(for: note.updatedDate ?? .distantPast, now: now, calendar: calendar)
            // Newest first, and section titles only ever step older, so a note joins the last section
            // or opens the next one.
            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = NoteSection(title: title, notes: last.notes + [note])
            } else {
                sections.append(NoteSection(title: title, notes: [note]))
            }
        }
        return sections
    }

    /// The row's date: the time today, the weekday within the last six days, else `M/d/yy`.
    static func dateLabel(_ date: Date, now: Date, calendar: Calendar) -> String {
        switch dayDiff(from: date, to: now, calendar: calendar) {
        case ...0: return format(date, "h:mm a", calendar: calendar)
        case 1...6: return format(date, "EEEE", calendar: calendar)
        default: return format(date, "M/d/yy", calendar: calendar)
        }
    }

    // MARK: Private

    private static func sectionTitle(for date: Date, now: Date, calendar: Calendar) -> String {
        switch dayDiff(from: date, to: now, calendar: calendar) {
        case ...0: return "Today"
        case 1: return "Yesterday"
        case 2...7: return "Previous 7 Days"
        case 8...30: return "Previous 30 Days"
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            return format(date, sameYear ? "MMMM" : "yyyy", calendar: calendar)
        }
    }

    /// Calendar days from the start of `date`'s day to the start of `now`'s day.
    private static func dayDiff(from date: Date, to now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
    }

    /// One shared formatter, reconfigured per call under a lock: `DateFormatter` is expensive to make
    /// and not safe to mutate from two threads.
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        return f
    }()
    private static let formatterLock = NSLock()

    private static func format(_ date: Date, _ pattern: String, calendar: Calendar) -> String {
        formatterLock.lock()
        defer { formatterLock.unlock() }
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
