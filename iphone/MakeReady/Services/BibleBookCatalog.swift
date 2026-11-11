//
//  BibleBookCatalog.swift
//  MakeReady
//
//  Synchronous view of the bundled 66-book canon: category, testament,
//  chapter counts and chapter stepping. Never consults the server.
//

import Foundation

enum BibleCategory: CaseIterable {
    case law, history, wisdom, majorProphets, minorProphets, gospelsActs, pauline, general, apocalyptic

    /// One of five colour tokens; categories sharing a token read as one colour.
    var colorToken: String {
        switch self {
        case .law, .pauline: return "bibleOlive"
        case .history, .majorProphets: return "bibleTeal"
        case .wisdom: return "bibleGreen"
        case .minorProphets, .general: return "bibleBrown"
        case .gospelsActs, .apocalyptic: return "bibleMaroon"
        }
    }
}

extension BookInfo {
    /// Unique across all 66 books ("Phil" Philippians, "Phlm" Philemon).
    var abbreviation: String { abbrev }
}

enum BibleBookCatalog {
    private static let books: [Int: BookInfo] = Dictionary(
        uniqueKeysWithValues: BibleCacheManager.bookData.map {
            ($0.number, BookInfo(bookNumber: $0.number, name: $0.name, abbrev: $0.abbrev,
                                 testament: $0.testament, chapters: $0.chapters))
        })

    static func book(_ number: Int) -> BookInfo? { books[number] }

    static func category(of number: Int) -> BibleCategory {
        switch number {
        case ...5: return .law
        case 6...17: return .history
        case 18...22: return .wisdom
        case 23...27: return .majorProphets
        case 28...39: return .minorProphets
        case 40...44: return .gospelsActs
        case 45...57: return .pauline
        case 58...65: return .general
        default: return .apocalyptic
        }
    }

    static func isOldTestament(_ number: Int) -> Bool { books[number]?.testament == "OT" }

    static func chapterCount(of number: Int) -> Int { books[number]?.chapters ?? 0 }

    /// One chapter forward (+1) or back (-1), across books; nil past Genesis 1 / Revelation 22.
    static func step(book: Int, chapter: Int, by delta: Int) -> (book: Int, chapter: Int)? {
        guard books[book] != nil else { return nil }
        let next = chapter + delta
        if next >= 1 && next <= chapterCount(of: book) { return (book, next) }
        if next < 1 {
            guard book > 1 else { return nil }
            return (book - 1, chapterCount(of: book - 1))
        }
        guard book < 66 else { return nil }
        return (book + 1, 1)
    }
}
