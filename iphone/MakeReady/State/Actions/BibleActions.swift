//
//  BibleActions.swift
//  MakeReady
//
//  bible-verse-picker: every Bible API call the picker makes and every write to the AppState Bible
//  domain — translations (D7), chapters through the versioned disk cache (D9, D24), smart search
//  and recents (D17). User-initiated failures surface the top banner (/ios-error-surface).
//

import Foundation

enum BibleActionsError: Error, Equatable {
    /// The chapter is neither cached nor fetchable (D18, D24).
    case chapterUnavailable
    /// A smart search answered `{type:"error"}` (D17).
    case searchFailed(String)
}

struct BibleActions {

    /// D17: the result count the server is asked for.
    private static let searchLimit = 10

    private let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // MARK: - Translations

    /// Replaces the bundled translations with the server's. If the stored selection is not one of the
    /// served codes it moves to the served code of the same name, else to the most popular (D7).
    /// Background load: a failure keeps the bundled list and stays console-only.
    @MainActor
    func loadTranslations() async {
        do {
            let response: BibleTranslationsResponse = try await api.get(
                "/api/bible/translations", responseType: BibleTranslationsResponse.self)
            guard let translations = response.translations, !translations.isEmpty else { return }
            state.bibleTranslations = translations
            let sorted = state.sortedBibleTranslations
            if !sorted.contains(where: { $0.code == state.selectedBibleTranslation }) {
                let storedName = knownBibleVersions.first { $0.code == state.selectedBibleTranslation }?.name
                let match = storedName.flatMap { name in sorted.first { $0.name == name } }
                state.selectedBibleTranslation = (match ?? sorted[0]).code
            }
        } catch {
            state.recordError(error, context: "BibleActions.loadTranslations")
        }
    }

    // MARK: - Chapters

    /// The chapter from AppState, the versioned disk cache, or the network, in that order, and
    /// written to `bibleChapters`. A failed fetch throws `.chapterUnavailable` and writes nothing —
    /// the caller shows the banner with Retry (D18, D24).
    @MainActor
    func loadChapter(book: Int, chapter: Int, translation: String) async throws -> BibleChapter {
        let key = AppState.bibleChapterKey(translation: translation, book: book, chapter: chapter)
        if let loaded = state.bibleChapters[key] { return loaded }
        do {
            let cached = try await BibleCacheManager.shared.chapter(
                bookNumber: book, chapter: chapter, translation: translation, api: api)
            let loaded = BibleChapter(
                book: book, chapter: chapter, translation: translation,
                verses: cached.verses.map { BibleVerse(verse: $0.v, text: $0.t) },
                copyright: cached.copyright ?? "")
            state.bibleChapters[key] = loaded
            return loaded
        } catch {
            Log.state.error("BibleActions.loadChapter: \(error.localizedDescription, privacy: .public)")
            throw BibleActionsError.chapterUnavailable
        }
    }

    // MARK: - Search

    /// Smart search in the selected translation. `record` writes a recent, so only the return key
    /// passes true (D17, SC5). A response for a superseded query is dropped; an error answer or a
    /// thrown error surfaces the banner and keeps the last result.
    @MainActor
    func search(_ query: String, record: Bool) async {
        let token = UUID()
        state.bibleSearchToken = token
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state.bibleSearchResult = nil
            return
        }
        let body: [String: Any] = [
            "query": trimmed,
            "translation": state.selectedBibleTranslation,
            "limit": Self.searchLimit,
            "record": record,
        ]
        do {
            let result: BibleSearchResult = try await api.post(
                "/api/search/smart", body: body, responseType: BibleSearchResult.self)
            guard state.bibleSearchToken == token else { return }
            if case .error(let message) = result {
                surfaceSearchFailure(BibleActionsError.searchFailed(message), query: query, record: record)
                return
            }
            state.bibleSearchResult = result
        } catch {
            guard state.bibleSearchToken == token else { return }
            surfaceSearchFailure(error, query: query, record: record)
        }
    }

    @MainActor
    private func surfaceSearchFailure(_ error: Error, query: String, record: Bool) {
        state.recordError(
            error, context: "BibleActions.search", surface: true,
            friendlyMessage: "Couldn't search the Bible",
            retry: { Task { @MainActor in await self.search(query, record: record) } })
    }

    // MARK: - Recents

    /// Replaces `bibleRecents` with the server's.
    @MainActor
    func loadRecents() async {
        do {
            let response: BibleRecentsResponse = try await api.get(
                "/api/search/recent?type=bible", responseType: BibleRecentsResponse.self)
            state.bibleRecents = response.searches
        } catch {
            state.recordError(
                error, context: "BibleActions.loadRecents", surface: true,
                friendlyMessage: "Couldn't load recent searches",
                retry: { Task { @MainActor in await self.loadRecents() } })
        }
    }

    /// Removes one recent (the server removes every stored row of that query, SC4). A failure keeps the row.
    @MainActor
    func deleteRecent(id: String) async {
        do {
            let _: SuccessResponse = try await api.delete("/api/search/recent/\(id)", responseType: SuccessResponse.self)
            state.bibleRecents.removeAll { $0.id == id }
        } catch {
            state.recordError(
                error, context: "BibleActions.deleteRecent", surface: true,
                friendlyMessage: "Couldn't remove that search",
                retry: { Task { @MainActor in await self.deleteRecent(id: id) } })
        }
    }
}
