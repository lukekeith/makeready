//
//  BibleSearchService.swift
//  MakeReady
//
//  Service for Bible search API calls
//

import Foundation

// MARK: - Models

struct BibleBook: Codable {
    let bookNumber: Int
    let name: String
    let abbrev: String
}

struct BibleVerse: Codable {
    let verse: Int
    let text: String
    let reference: String
}

struct SemanticResult: Codable {
    let verseId: String?
    let book: BibleBook
    let chapter: Int
    let verse: Int
    let text: String
    let reference: String
    let similarity: Double
}

struct BookSuggestion: Codable {
    let bookNumber: Int
    let bookName: String
    let abbrev: String
    let chapters: Int
    let examples: [String]
}

// MARK: - API Response Models

struct DirectSearchResponse: Codable {
    let type: String
    let query: String
    let translation: String
    let book: BibleBook
    let chapter: Int
    let verses: [BibleVerse]
    let total: Int
}

struct SemanticSearchResponse: Codable {
    let type: String
    let query: String
    let translation: String
    let results: [SemanticResult]
    let total: Int
}

struct GroupedSearchResponse: Codable {
    let type: String
    let query: String
    let translation: String
    let books: [MatchedBook]
    let verses: [SemanticResult]
    let total: Int
}

struct MatchedBook: Codable, Identifiable {
    let bookNumber: Int
    let bookName: String
    let chapters: Int
    let testament: String

    var id: Int { bookNumber }
}

struct SuggestionsResponse: Codable {
    let suggestions: [BookSuggestion]
}

// MARK: - Unified Search Result

enum BibleSearchResult {
    case direct(book: BibleBook, chapter: Int, verses: [BibleVerse])
    case semantic(results: [SemanticResult])
    case grouped(books: [MatchedBook], verses: [SemanticResult])
    case empty
}

// MARK: - Search Result Item (for UI display)

struct SearchResultItem: Identifiable {
    let id = UUID()
    let reference: String
    let text: String
    let bookNumber: Int
    let chapter: Int
    let verse: Int
    let similarity: Double?  // Only for semantic results

    init(from verse: BibleVerse, book: BibleBook, chapter: Int) {
        self.reference = verse.reference
        self.text = verse.text
        self.bookNumber = book.bookNumber
        self.chapter = chapter
        self.verse = verse.verse
        self.similarity = nil
    }

    init(from result: SemanticResult) {
        self.reference = result.reference
        self.text = result.text
        self.bookNumber = result.book.bookNumber
        self.chapter = result.chapter
        self.verse = result.verse
        self.similarity = result.similarity
    }
}

// MARK: - Service

class BibleSearchService {
    static let shared = BibleSearchService()

    private init() {}

    /// Perform smart search (auto-detects reference vs semantic)
    func smartSearch(query: String, translation: String? = nil, limit: Int = 10) async throws -> BibleSearchResult {
        // AppState is @MainActor; hop to read the selected translation
        let translation = if let translation { translation } else { await MainActor.run { AppState.shared.selectedBibleTranslation } }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }

        guard let url = URL(string: "\(Configuration.baseURL)/api/search/smart") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie if available
        if let sessionCookie = SessionCredentialStore.get() {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        let body: [String: Any] = [
            "query": query,
            "translation": translation,
            "limit": limit
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard httpResponse.statusCode == 200 else {
            print("Search API error: \(httpResponse.statusCode)")
            if let errorString = String(data: data, encoding: .utf8) {
                print("Error body: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }

        // First, decode just the type to determine which response to parse
        struct TypeResponse: Codable {
            let type: String
        }

        let typeResponse = try JSONDecoder().decode(TypeResponse.self, from: data)

        switch typeResponse.type {
        case "direct":
            let directResponse = try JSONDecoder().decode(DirectSearchResponse.self, from: data)
            if directResponse.verses.isEmpty {
                return .empty
            }
            return .direct(book: directResponse.book, chapter: directResponse.chapter, verses: directResponse.verses)

        case "semantic":
            let semanticResponse = try JSONDecoder().decode(SemanticSearchResponse.self, from: data)
            if semanticResponse.results.isEmpty {
                return .empty
            }
            return .semantic(results: semanticResponse.results)

        case "grouped":
            let groupedResponse = try JSONDecoder().decode(GroupedSearchResponse.self, from: data)
            if groupedResponse.books.isEmpty && groupedResponse.verses.isEmpty {
                return .empty
            }
            return .grouped(books: groupedResponse.books, verses: groupedResponse.verses)

        default:
            return .empty
        }
    }

    /// Get book name suggestions for autocomplete
    func getSuggestions(query: String, translation: String? = nil) async throws -> [BookSuggestion] {
        // AppState is @MainActor; hop to read the selected translation
        let translation = if let translation { translation } else { await MainActor.run { AppState.shared.selectedBibleTranslation } }
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var components = URLComponents(string: "\(Configuration.baseURL)/api/search/suggestions")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "translation", value: translation)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie if available
        if let sessionCookie = SessionCredentialStore.get() {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let suggestionsResponse = try JSONDecoder().decode(SuggestionsResponse.self, from: data)
        return suggestionsResponse.suggestions
    }

    /// Convert search result to array of SearchResultItems for UI
    func toSearchResultItems(_ result: BibleSearchResult) -> [SearchResultItem] {
        switch result {
        case .direct(let book, let chapter, let verses):
            return verses.map { SearchResultItem(from: $0, book: book, chapter: chapter) }
        case .semantic(let results):
            return results.map { SearchResultItem(from: $0) }
        case .grouped(_, let verses):
            return verses.map { SearchResultItem(from: $0) }
        case .empty:
            return []
        }
    }

    /// Extract matched books from a grouped search result
    func toMatchedBooks(_ result: BibleSearchResult) -> [MatchedBook] {
        if case .grouped(let books, _) = result { return books }
        return []
    }

    // MARK: - Recent Searches

    /// Get recent Bible searches for the authenticated user
    func getRecentSearches(limit: Int = 10) async throws -> [RecentSearch] {
        var components = URLComponents(string: "\(Configuration.baseURL)/api/search/recent")
        components?.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "type", value: "bible")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let sessionCookie = SessionCredentialStore.get() {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(RecentSearchesResponse.self, from: data)
        return decoded.searches ?? []
    }
}

// MARK: - Recent Search Models

struct RecentSearch: Codable, Identifiable {
    let id: String?
    let query: String
    let type: String?
    let createdAt: String?

    var stableId: String { id ?? query }
}

struct RecentSearchesResponse: Codable {
    let searches: [RecentSearch]?
}
