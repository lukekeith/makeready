//
//  BibleCacheManager.swift
//  MakeReady
//
//  Manages local caching of Bible data for offline access and fast loading.
//  Fetches chapters on-demand from GET /api/bible/{translationCode}/{bookNumber}/{chapter}
//

import Foundation

// MARK: - API Response Models

/// Response from GET /api/bible/{translationCode}/{bookNumber}/{chapter}
struct ChapterResponse: Codable {
    let translation: String?
    let book: ChapterBookInfo?
    let chapter: Int?
    let verses: [APIVerse]?
    let navigation: ChapterNavigation?
    let fumsToken: String?
    let copyright: String?
}

struct ChapterBookInfo: Codable {
    let bookNumber: Int?
    let name: String?
    let abbrev: String?
    let testament: String?
}

struct APIVerse: Codable {
    let verse: Int
    let text: String
}

struct ChapterNavigation: Codable {
    let previousChapter: ChapterRef?
    let nextChapter: ChapterRef?
}

struct ChapterRef: Codable {
    let bookNumber: Int
    let chapter: Int
}

// MARK: - Legacy compat models (used by other files)

struct BibleDownload: Codable {
    let translation: TranslationInfo
    let books: [BookInfo]
    let verses: [VerseCompact]
    let metadata: DownloadMetadata
}

struct TranslationInfo: Codable {
    let code: String
    let name: String
    let language: String
    let copyright: String
}

struct BookInfo: Codable {
    let bookNumber: Int
    let name: String
    let abbrev: String
    let testament: String
    let chapters: Int
}

struct VerseCompact: Codable {
    let b: Int  // bookNumber
    let c: Int  // chapter
    let v: Int  // verse
    let t: String  // text
}

struct DownloadMetadata: Codable {
    let version: String
    let totalVerses: Int
    let downloadedAt: String
}

// MARK: - Chapter Cache Entry

struct CachedChapter: Codable {
    let translationCode: String
    let bookNumber: Int
    let chapter: Int
    let verses: [VerseCompact]
    let copyright: String?
    let cachedAt: Date
}

// MARK: - Bible Cache Manager

class BibleCacheManager {
    static let shared = BibleCacheManager()

    /// Canonical book data (never changes across translations)
    private let bookData: [(number: Int, name: String, abbrev: String, testament: String, chapters: Int)] = [
        // Old Testament
        (1, "Genesis", "Gen", "OT", 50), (2, "Exodus", "Exod", "OT", 40), (3, "Leviticus", "Lev", "OT", 27),
        (4, "Numbers", "Num", "OT", 36), (5, "Deuteronomy", "Deut", "OT", 34), (6, "Joshua", "Josh", "OT", 24),
        (7, "Judges", "Judg", "OT", 21), (8, "Ruth", "Ruth", "OT", 4), (9, "1 Samuel", "1Sam", "OT", 31),
        (10, "2 Samuel", "2Sam", "OT", 24), (11, "1 Kings", "1Kgs", "OT", 22), (12, "2 Kings", "2Kgs", "OT", 25),
        (13, "1 Chronicles", "1Chr", "OT", 29), (14, "2 Chronicles", "2Chr", "OT", 36), (15, "Ezra", "Ezra", "OT", 10),
        (16, "Nehemiah", "Neh", "OT", 13), (17, "Esther", "Esth", "OT", 10), (18, "Job", "Job", "OT", 42),
        (19, "Psalms", "Ps", "OT", 150), (20, "Proverbs", "Prov", "OT", 31), (21, "Ecclesiastes", "Eccl", "OT", 12),
        (22, "Song of Solomon", "Song", "OT", 8), (23, "Isaiah", "Isa", "OT", 66), (24, "Jeremiah", "Jer", "OT", 52),
        (25, "Lamentations", "Lam", "OT", 5), (26, "Ezekiel", "Ezek", "OT", 48), (27, "Daniel", "Dan", "OT", 12),
        (28, "Hosea", "Hos", "OT", 14), (29, "Joel", "Joel", "OT", 3), (30, "Amos", "Amos", "OT", 9),
        (31, "Obadiah", "Obad", "OT", 1), (32, "Jonah", "Jonah", "OT", 4), (33, "Micah", "Mic", "OT", 7),
        (34, "Nahum", "Nah", "OT", 3), (35, "Habakkuk", "Hab", "OT", 3), (36, "Zephaniah", "Zeph", "OT", 3),
        (37, "Haggai", "Hag", "OT", 2), (38, "Zechariah", "Zech", "OT", 14), (39, "Malachi", "Mal", "OT", 4),
        // New Testament
        (40, "Matthew", "Matt", "NT", 28), (41, "Mark", "Mark", "NT", 16), (42, "Luke", "Luke", "NT", 24),
        (43, "John", "John", "NT", 21), (44, "Acts", "Acts", "NT", 28), (45, "Romans", "Rom", "NT", 16),
        (46, "1 Corinthians", "1Cor", "NT", 16), (47, "2 Corinthians", "2Cor", "NT", 13), (48, "Galatians", "Gal", "NT", 6),
        (49, "Ephesians", "Eph", "NT", 6), (50, "Philippians", "Phil", "NT", 4), (51, "Colossians", "Col", "NT", 4),
        (52, "1 Thessalonians", "1Thess", "NT", 5), (53, "2 Thessalonians", "2Thess", "NT", 3),
        (54, "1 Timothy", "1Tim", "NT", 6), (55, "2 Timothy", "2Tim", "NT", 4), (56, "Titus", "Titus", "NT", 3),
        (57, "Philemon", "Phlm", "NT", 1), (58, "Hebrews", "Heb", "NT", 13), (59, "James", "Jas", "NT", 5),
        (60, "1 Peter", "1Pet", "NT", 5), (61, "2 Peter", "2Pet", "NT", 3), (62, "1 John", "1John", "NT", 5),
        (63, "2 John", "2John", "NT", 1), (64, "3 John", "3John", "NT", 1), (65, "Jude", "Jude", "NT", 1),
        (66, "Revelation", "Rev", "NT", 22)
    ]

    private lazy var bookByName: [String: (number: Int, abbrev: String, testament: String, chapters: Int)] = {
        var dict: [String: (number: Int, abbrev: String, testament: String, chapters: Int)] = [:]
        for b in bookData { dict[b.name] = (b.number, b.abbrev, b.testament, b.chapters) }
        return dict
    }()

    private lazy var bookByNumber: [Int: (name: String, abbrev: String, testament: String, chapters: Int)] = {
        var dict: [Int: (name: String, abbrev: String, testament: String, chapters: Int)] = [:]
        for b in bookData { dict[b.number] = (b.name, b.abbrev, b.testament, b.chapters) }
        return dict
    }()

    // In-memory chapter cache: "translationCode-bookNumber-chapter" → CachedChapter
    private var chapterCache: [String: CachedChapter] = [:]

    // Track in-flight chapter requests to avoid duplicate fetches
    private var loadingChapters: Set<String> = []
    private var chapterContinuations: [String: [CheckedContinuation<[VerseCompact]?, Never>]] = [:]

    // Progress tracking
    var downloadProgress: Double = 0
    var downloadStatus: String = ""

    /// The currently active translation code
    var currentTranslation: String {
        return AppState.shared.selectedBibleTranslation
    }

    private init() {}

    // MARK: - Public API

    /// Get the cached Bible for the current translation (legacy compat — builds a BibleDownload from cached chapters)
    /// NOTE: This only returns chapters that have already been fetched. Use getChapterVerses() for on-demand loading.
    func getBible() async -> BibleDownload? {
        return await getBible(translation: currentTranslation)
    }

    /// Legacy compat: returns a BibleDownload with all cached chapters for a translation
    func getBible(translation: String) async -> BibleDownload? {
        let books = bookData.map { BookInfo(bookNumber: $0.number, name: $0.name, abbrev: $0.abbrev, testament: $0.testament, chapters: $0.chapters) }

        // Gather all cached verses for this translation
        var allVerses: [VerseCompact] = []
        for (_, cached) in chapterCache where cached.translationCode == translation {
            allVerses.append(contentsOf: cached.verses)
        }

        let translationInfo = TranslationInfo(code: translation, name: translation, language: "eng", copyright: "")
        let metadata = DownloadMetadata(version: "2.0", totalVerses: allVerses.count, downloadedAt: ISO8601DateFormatter().string(from: Date()))

        return BibleDownload(translation: translationInfo, books: books, verses: allVerses, metadata: metadata)
    }

    /// Get verse count for a specific chapter (fetches from API if not cached)
    func getVerseCount(bookNumber: Int, chapter: Int) async -> Int? {
        guard let verses = await getChapterVerses(bookNumber: bookNumber, chapter: chapter) else { return nil }
        return verses.count
    }

    /// Get verses for a specific chapter (fetches from API if not cached)
    func getChapterVerses(bookNumber: Int, chapter: Int) async -> [VerseCompact]? {
        return await getChapterVerses(bookNumber: bookNumber, chapter: chapter, translation: currentTranslation)
    }

    /// Get verses for a specific chapter in a specific translation
    func getChapterVerses(bookNumber: Int, chapter: Int, translation: String) async -> [VerseCompact]? {
        let cacheKey = "\(translation)-\(bookNumber)-\(chapter)"

        // Check memory cache
        if let cached = chapterCache[cacheKey] {
            return cached.verses
        }

        // Check disk cache
        if let diskCached = loadChapterFromDisk(key: cacheKey) {
            chapterCache[cacheKey] = diskCached
            return diskCached.verses
        }

        // Handle concurrent requests for the same chapter
        if loadingChapters.contains(cacheKey) {
            return await withCheckedContinuation { continuation in
                chapterContinuations[cacheKey, default: []].append(continuation)
            }
        }

        // Fetch from API
        loadingChapters.insert(cacheKey)
        let verses = await fetchChapter(bookNumber: bookNumber, chapter: chapter, translation: translation)
        loadingChapters.remove(cacheKey)

        // Resume waiting continuations
        if let continuations = chapterContinuations[cacheKey] {
            for continuation in continuations {
                continuation.resume(returning: verses)
            }
            chapterContinuations[cacheKey] = nil
        }

        return verses
    }

    /// Get book info by number (uses canonical data, no API call needed)
    func getBook(number: Int) async -> BookInfo? {
        guard let b = bookByNumber[number] else { return nil }
        return BookInfo(bookNumber: number, name: b.name, abbrev: b.abbrev, testament: b.testament, chapters: b.chapters)
    }

    /// Get all books (uses canonical data, no API call needed)
    func getAllBooks() async -> [BookInfo]? {
        return bookData.map { BookInfo(bookNumber: $0.number, name: $0.name, abbrev: $0.abbrev, testament: $0.testament, chapters: $0.chapters) }
    }

    /// Get book number from name (uses canonical data, no API call needed)
    func getBookNumber(from bookName: String) async -> Int? {
        return bookByName[bookName]?.number
    }

    /// Get book name from number (uses canonical data, no API call needed)
    func getBookName(from bookNumber: Int) async -> String? {
        return bookByNumber[bookNumber]?.name
    }

    /// Pre-load: no-op now since we fetch chapters on-demand
    func preloadBible() async {
        print("BibleCacheManager: Using on-demand chapter loading for \(currentTranslation)")
    }

    /// Force refresh the cache for the current translation
    func refreshCache() async -> Bool {
        clearCache(translation: currentTranslation)
        return true
    }

    /// Clear the cache for a specific translation (or all)
    func clearCache(translation: String? = nil) {
        if let translation = translation {
            // Remove memory cache entries for this translation
            chapterCache = chapterCache.filter { !$0.key.hasPrefix("\(translation)-") }
            // Remove disk cache
            deleteChaptersFromDisk(translation: translation)
        } else {
            chapterCache.removeAll()
            deleteAllChaptersFromDisk()
        }
    }

    /// Check if any chapters are cached for current translation
    var isCached: Bool {
        let translation = currentTranslation
        return chapterCache.keys.contains(where: { $0.hasPrefix("\(translation)-") })
    }

    // MARK: - API Fetching

    private func fetchChapter(bookNumber: Int, chapter: Int, translation: String) async -> [VerseCompact]? {
        let urlString = "\(Configuration.baseURL)/api/bible/\(translation)/\(bookNumber)/\(chapter)"
        guard let url = URL(string: urlString) else {
            print("BibleCacheManager: Invalid URL: \(urlString)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let sessionCookie = UserDefaults.standard.string(forKey: "makeready_session_cookie") {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("BibleCacheManager: Bad response \(statusCode) for \(translation)/\(bookNumber)/\(chapter)")
                return nil
            }

            let chapterResponse = try JSONDecoder().decode(ChapterResponse.self, from: data)

            guard let apiVerses = chapterResponse.verses, !apiVerses.isEmpty else {
                print("BibleCacheManager: No verses in response for \(translation)/\(bookNumber)/\(chapter)")
                return nil
            }

            // Convert to VerseCompact
            let verses = apiVerses.map { VerseCompact(b: bookNumber, c: chapter, v: $0.verse, t: $0.text) }

            // Cache in memory and disk
            let cacheKey = "\(translation)-\(bookNumber)-\(chapter)"
            let cached = CachedChapter(
                translationCode: translation,
                bookNumber: bookNumber,
                chapter: chapter,
                verses: verses,
                copyright: chapterResponse.copyright,
                cachedAt: Date()
            )
            chapterCache[cacheKey] = cached
            saveChapterToDisk(cached, key: cacheKey)

            print("📖 BibleCacheManager: Fetched \(translation) \(bookByNumber[bookNumber]?.name ?? "?") \(chapter) (\(verses.count) verses)")
            return verses
        } catch {
            print("BibleCacheManager: Fetch error for \(translation)/\(bookNumber)/\(chapter): \(error)")
            return nil
        }
    }

    // MARK: - Disk Storage (per-chapter)

    private var cacheDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("bible_cache")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func chapterFileURL(key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).json")
    }

    private func saveChapterToDisk(_ chapter: CachedChapter, key: String) {
        do {
            let data = try JSONEncoder().encode(chapter)
            try data.write(to: chapterFileURL(key: key))
        } catch {
            print("BibleCacheManager: Failed to save chapter to disk: \(error)")
        }
    }

    private func loadChapterFromDisk(key: String) -> CachedChapter? {
        let url = chapterFileURL(key: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let chapter = try JSONDecoder().decode(CachedChapter.self, from: data)

            // Expire after 14 days (matching API cache policy)
            if Date().timeIntervalSince(chapter.cachedAt) > 14 * 24 * 60 * 60 {
                try? FileManager.default.removeItem(at: url)
                return nil
            }

            return chapter
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private func deleteChaptersFromDisk(translation: String) {
        let prefix = "\(translation)-"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path) {
            for file in files where file.hasPrefix(prefix) {
                try? FileManager.default.removeItem(at: cacheDirectory.appendingPathComponent(file))
            }
        }
    }

    private func deleteAllChaptersFromDisk() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        // Also clean up old bulk cache files
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(atPath: docs.path) {
            for file in files where file.hasPrefix("bible_") && file.hasSuffix("_cache.json") {
                try? FileManager.default.removeItem(at: docs.appendingPathComponent(file))
            }
        }
    }
}
