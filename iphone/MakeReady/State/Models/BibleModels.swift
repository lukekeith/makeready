//
//  BibleModels.swift
//  MakeReady
//
//  bible-verse-picker: the wire types BibleActions decodes — a chapter, a smart-search answer and
//  a recent search (SPEC §Contract: `/:code/:book/:chapter`, `/search/smart`, `/search/recent`).
//

import Foundation

/// One verse of a chapter or a direct reference. `text` is the canonical string (D9): offsets index into it.
struct BibleVerse: Codable, Equatable {
    let verse: Int
    let text: String
}

/// A chapter in one translation, with the licence text the Reader shows under its last verse (D20).
struct BibleChapter: Equatable {
    /// The book number (1-66).
    let book: Int
    let chapter: Int
    /// The translation code as served (D7).
    let translation: String
    let verses: [BibleVerse]
    let copyright: String
}

/// A book matched by a grouped or semantic search.
struct BibleBookHit: Codable, Equatable, Identifiable {
    let bookNumber: Int
    let bookName: String
    let chapters: Int
    let testament: String

    var id: Int { bookNumber }
}

/// A verse (or a named passage when `verseEnd`/`title`/`summary` are set) matched by a search.
struct BibleVerseHit: Codable, Equatable {
    let bookNumber: Int
    let chapter: Int
    let verse: Int
    let verseEnd: Int?
    let reference: String
    let text: String
    let title: String?
    let summary: String?
}

/// `POST /api/search/smart`, one case per response `type`; `semantic` decodes as `grouped`.
enum BibleSearchResult: Decodable, Equatable {
    case direct(book: Int, chapter: Int, verses: [BibleVerse])
    case grouped(books: [BibleBookHit], verses: [BibleVerseHit])
    case error(String)

    private enum CodingKeys: String, CodingKey {
        case type, book, chapter, verses, books, error
    }

    private struct DirectBook: Decodable {
        let bookNumber: Int
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .type) {
        case "direct":
            self = .direct(
                book: try container.decode(DirectBook.self, forKey: .book).bookNumber,
                chapter: try container.decode(Int.self, forKey: .chapter),
                verses: try container.decode([BibleVerse].self, forKey: .verses))
        case "grouped", "semantic":
            self = .grouped(
                books: try container.decodeIfPresent([BibleBookHit].self, forKey: .books) ?? [],
                verses: try container.decodeIfPresent([BibleVerseHit].self, forKey: .verses) ?? [])
        case "error":
            self = .error(try container.decodeIfPresent(String.self, forKey: .error) ?? "")
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown smart-search type \(other)")
        }
    }
}

/// A recent Bible search — the query string the user submitted.
struct BibleRecent: Decodable, Equatable, Identifiable {
    let id: String
    let query: String
}

/// `GET /api/search/recent?type=bible`.
struct BibleRecentsResponse: Decodable {
    let searches: [BibleRecent]
}
