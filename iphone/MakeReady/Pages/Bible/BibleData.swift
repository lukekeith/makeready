//
//  BibleData.swift
//  MakeReady
//
//  Static data for all 66 books of the Bible.
//  Includes names, abbreviations, chapter counts, categories, and category colors.
//

import SwiftUI
import UIKit

// MARK: - Testament

enum Testament {
    case old
    case new
}

// MARK: - Book Category

enum BookCategory: String, CaseIterable {
    case pentateuch       // Gen–Deut
    case historical       // Josh–Esther
    case wisdom           // Job–Song of Solomon
    case majorProphets    // Isa–Dan
    case minorProphets    // Hos–Mal
    case gospelsAndActs   // Matt–Acts
    case paulineEpistles  // Rom–Philemon
    case generalEpistles  // Heb–Jude
    case apocalyptic      // Revelation

    var color: Color {
        switch self {
        case .pentateuch:      return Color(hex: "#424216")
        case .historical:      return Color(hex: "#143F45")
        case .wisdom:          return Color(hex: "#254422")
        case .majorProphets:   return Color(hex: "#143F45")
        case .minorProphets:   return Color(hex: "#563B2D")
        case .gospelsAndActs:  return Color(hex: "#563139")
        case .paulineEpistles: return Color(hex: "#424216")
        case .generalEpistles: return Color(hex: "#563B2D")
        case .apocalyptic:     return Color(hex: "#563139")
        }
    }

    var uiColor: UIColor {
        switch self {
        case .pentateuch:      return UIColor(red: 0x42/255, green: 0x42/255, blue: 0x16/255, alpha: 1)
        case .historical:      return UIColor(red: 0x14/255, green: 0x3F/255, blue: 0x45/255, alpha: 1)
        case .wisdom:          return UIColor(red: 0x25/255, green: 0x44/255, blue: 0x22/255, alpha: 1)
        case .majorProphets:   return UIColor(red: 0x14/255, green: 0x3F/255, blue: 0x45/255, alpha: 1)
        case .minorProphets:   return UIColor(red: 0x56/255, green: 0x3B/255, blue: 0x2D/255, alpha: 1)
        case .gospelsAndActs:  return UIColor(red: 0x56/255, green: 0x31/255, blue: 0x39/255, alpha: 1)
        case .paulineEpistles: return UIColor(red: 0x42/255, green: 0x42/255, blue: 0x16/255, alpha: 1)
        case .generalEpistles: return UIColor(red: 0x56/255, green: 0x3B/255, blue: 0x2D/255, alpha: 1)
        case .apocalyptic:     return UIColor(red: 0x56/255, green: 0x31/255, blue: 0x39/255, alpha: 1)
        }
    }

    var displayName: String {
        switch self {
        case .pentateuch:      return "Books of the Law"
        case .historical:      return "Historical Books"
        case .wisdom:          return "Wisdom & Poetry"
        case .majorProphets:   return "Major Prophets"
        case .minorProphets:   return "Minor Prophets"
        case .gospelsAndActs:  return "Gospels & Acts"
        case .paulineEpistles: return "Pauline Epistles"
        case .generalEpistles: return "General Epistles"
        case .apocalyptic:     return "Apocalyptic"
        }
    }
}

// MARK: - Bible Book

struct BibleBookInfo: Identifiable {
    let id: Int          // Book number 1–66
    let name: String     // Full name
    let abbreviation: String  // Short label for grid
    let chapters: Int
    let category: BookCategory
    let testament: Testament
}

// MARK: - All Books

let bibleBooks: [BibleBookInfo] = [
    // Old Testament — Pentateuch (1–5)
    BibleBookInfo(id: 1,  name: "Genesis",         abbreviation: "Gen",     chapters: 50, category: .pentateuch,    testament: .old),
    BibleBookInfo(id: 2,  name: "Exodus",          abbreviation: "Exod",    chapters: 40, category: .pentateuch,    testament: .old),
    BibleBookInfo(id: 3,  name: "Leviticus",       abbreviation: "Lev",     chapters: 27, category: .pentateuch,    testament: .old),
    BibleBookInfo(id: 4,  name: "Numbers",         abbreviation: "Num",     chapters: 36, category: .pentateuch,    testament: .old),
    BibleBookInfo(id: 5,  name: "Deuteronomy",     abbreviation: "Deut",    chapters: 34, category: .pentateuch,    testament: .old),

    // Old Testament — Historical (6–17)
    BibleBookInfo(id: 6,  name: "Joshua",          abbreviation: "Josh",    chapters: 24, category: .historical,    testament: .old),
    BibleBookInfo(id: 7,  name: "Judges",          abbreviation: "Judg",    chapters: 21, category: .historical,    testament: .old),
    BibleBookInfo(id: 8,  name: "Ruth",            abbreviation: "Ruth",    chapters: 4,  category: .historical,    testament: .old),
    BibleBookInfo(id: 9,  name: "1 Samuel",        abbreviation: "1 Sam",   chapters: 31, category: .historical,    testament: .old),
    BibleBookInfo(id: 10, name: "2 Samuel",        abbreviation: "2 Sam",   chapters: 24, category: .historical,    testament: .old),
    BibleBookInfo(id: 11, name: "1 Kings",         abbreviation: "1 King",  chapters: 22, category: .historical,    testament: .old),
    BibleBookInfo(id: 12, name: "2 Kings",         abbreviation: "2 King",  chapters: 25, category: .historical,    testament: .old),
    BibleBookInfo(id: 13, name: "1 Chronicles",    abbreviation: "1 Chron", chapters: 29, category: .historical,    testament: .old),
    BibleBookInfo(id: 14, name: "2 Chronicles",    abbreviation: "2 Chron", chapters: 36, category: .historical,    testament: .old),
    BibleBookInfo(id: 15, name: "Ezra",            abbreviation: "Ezra",    chapters: 10, category: .historical,    testament: .old),
    BibleBookInfo(id: 16, name: "Nehemiah",        abbreviation: "Neh",     chapters: 13, category: .historical,    testament: .old),
    BibleBookInfo(id: 17, name: "Esther",          abbreviation: "Esther",  chapters: 10, category: .historical,    testament: .old),

    // Old Testament — Wisdom & Poetry (18–22)
    BibleBookInfo(id: 18, name: "Job",             abbreviation: "Job",     chapters: 42, category: .wisdom,        testament: .old),
    BibleBookInfo(id: 19, name: "Psalms",          abbreviation: "Ps",      chapters: 150, category: .wisdom,       testament: .old),
    BibleBookInfo(id: 20, name: "Proverbs",        abbreviation: "Prov",    chapters: 31, category: .wisdom,        testament: .old),
    BibleBookInfo(id: 21, name: "Ecclesiastes",    abbreviation: "Eccles",  chapters: 12, category: .wisdom,        testament: .old),
    BibleBookInfo(id: 22, name: "Song of Solomon", abbreviation: "Song",    chapters: 8,  category: .wisdom,        testament: .old),

    // Old Testament — Major Prophets (23–27)
    BibleBookInfo(id: 23, name: "Isaiah",          abbreviation: "Isa",     chapters: 66, category: .majorProphets, testament: .old),
    BibleBookInfo(id: 24, name: "Jeremiah",        abbreviation: "Jer",     chapters: 52, category: .majorProphets, testament: .old),
    BibleBookInfo(id: 25, name: "Lamentations",    abbreviation: "Lam",     chapters: 5,  category: .majorProphets, testament: .old),
    BibleBookInfo(id: 26, name: "Ezekiel",         abbreviation: "Ezek",    chapters: 48, category: .majorProphets, testament: .old),
    BibleBookInfo(id: 27, name: "Daniel",          abbreviation: "Dan",     chapters: 12, category: .majorProphets, testament: .old),

    // Old Testament — Minor Prophets (28–39)
    BibleBookInfo(id: 28, name: "Hosea",           abbreviation: "Hos",     chapters: 14, category: .minorProphets, testament: .old),
    BibleBookInfo(id: 29, name: "Joel",            abbreviation: "Joel",    chapters: 3,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 30, name: "Amos",            abbreviation: "Amos",    chapters: 9,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 31, name: "Obadiah",         abbreviation: "Obad",    chapters: 1,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 32, name: "Jonah",           abbreviation: "Jonah",   chapters: 4,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 33, name: "Micah",           abbreviation: "Micah",   chapters: 7,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 34, name: "Nahum",           abbreviation: "Nah",     chapters: 3,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 35, name: "Habakkuk",        abbreviation: "Hab",     chapters: 3,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 36, name: "Zephaniah",       abbreviation: "Zeph",    chapters: 3,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 37, name: "Haggai",          abbreviation: "Haggai",  chapters: 2,  category: .minorProphets, testament: .old),
    BibleBookInfo(id: 38, name: "Zechariah",       abbreviation: "Zech",    chapters: 14, category: .minorProphets, testament: .old),
    BibleBookInfo(id: 39, name: "Malachi",         abbreviation: "Mal",     chapters: 4,  category: .minorProphets, testament: .old),

    // New Testament — Gospels & Acts (40–44)
    BibleBookInfo(id: 40, name: "Matthew",         abbreviation: "Matt",    chapters: 28, category: .gospelsAndActs,  testament: .new),
    BibleBookInfo(id: 41, name: "Mark",            abbreviation: "Mark",    chapters: 16, category: .gospelsAndActs,  testament: .new),
    BibleBookInfo(id: 42, name: "Luke",            abbreviation: "Luke",    chapters: 24, category: .gospelsAndActs,  testament: .new),
    BibleBookInfo(id: 43, name: "John",            abbreviation: "John",    chapters: 21, category: .gospelsAndActs,  testament: .new),
    BibleBookInfo(id: 44, name: "Acts",            abbreviation: "Acts",    chapters: 28, category: .gospelsAndActs,  testament: .new),

    // New Testament — Pauline Epistles (45–57)
    BibleBookInfo(id: 45, name: "Romans",          abbreviation: "Rom",     chapters: 16, category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 46, name: "1 Corinthians",   abbreviation: "1 Cor",   chapters: 16, category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 47, name: "2 Corinthians",   abbreviation: "2 Cor",   chapters: 13, category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 48, name: "Galatians",       abbreviation: "Gal",     chapters: 6,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 49, name: "Ephesians",       abbreviation: "Eph",     chapters: 6,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 50, name: "Philippians",     abbreviation: "Phil",    chapters: 4,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 51, name: "Colossians",      abbreviation: "Col",     chapters: 4,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 52, name: "1 Thessalonians", abbreviation: "1 Thess", chapters: 5,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 53, name: "2 Thessalonians", abbreviation: "2 Thess", chapters: 3,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 54, name: "1 Timothy",       abbreviation: "1 Tim",   chapters: 6,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 55, name: "2 Timothy",       abbreviation: "2 Tim",   chapters: 4,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 56, name: "Titus",           abbreviation: "Titus",   chapters: 3,  category: .paulineEpistles, testament: .new),
    BibleBookInfo(id: 57, name: "Philemon",        abbreviation: "Phil",    chapters: 1,  category: .paulineEpistles, testament: .new),

    // New Testament — General Epistles (58–65)
    BibleBookInfo(id: 58, name: "Hebrews",         abbreviation: "Heb",     chapters: 13, category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 59, name: "James",           abbreviation: "James",   chapters: 5,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 60, name: "1 Peter",         abbreviation: "1 Pet",   chapters: 5,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 61, name: "2 Peter",         abbreviation: "2 Pet",   chapters: 3,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 62, name: "1 John",          abbreviation: "1 John",  chapters: 5,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 63, name: "2 John",          abbreviation: "2 John",  chapters: 1,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 64, name: "3 John",          abbreviation: "3 John",  chapters: 1,  category: .generalEpistles, testament: .new),
    BibleBookInfo(id: 65, name: "Jude",            abbreviation: "Jude",    chapters: 1,  category: .generalEpistles, testament: .new),

    // New Testament — Apocalyptic (66)
    BibleBookInfo(id: 66, name: "Revelation",      abbreviation: "Rev",     chapters: 22, category: .apocalyptic,     testament: .new),
]

// MARK: - Convenience

let oldTestamentBooks = bibleBooks.filter { $0.testament == .old }
let newTestamentBooks = bibleBooks.filter { $0.testament == .new }
