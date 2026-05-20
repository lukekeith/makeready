//
//  FilterState.swift
//  MakeReady
//
//  Persisted, scoped filter state. Each screen scope (e.g. "library.programs")
//  gets its own FilterState instance that syncs to the server via UserPreference.
//
//  Usage:
//    let filters = FilterStateManager.shared.state(for: "library.programs")
//    // Read: filters.tags, filters.sort
//    // Write: filters.tags.insert("Faith"); filters.scheduleSave()
//    // Load: await filters.load()
//

import Foundation

// MARK: - FilterState

@Observable
final class FilterState {
    let scope: String

    var tags: Set<String> = []
    var leaders: Set<String> = []
    var sort: String = "newestFirst"
    var mediaType: String = "all"
    var timeFilter: String = "allTime"

    fileprivate(set) var isLoaded = false
    fileprivate(set) var hasExplicitPreference = false
    private var saveTask: Task<Void, Never>?
    private let api = APIClient.shared

    init(scope: String) {
        self.scope = scope
    }

    // MARK: - Load from server

    /// Fetch saved filter state from the server. Silently fails if offline.
    func load() async {
        let key = "filters.\(scope)"
        do {
            let response: PreferenceResponse = try await api.get(
                "/api/preferences/\(key)",
                responseType: PreferenceResponse.self
            )

            // Only apply if a value was actually stored (not a default)
            if !response.isDefault, let value = response.value, !value.isEmpty {
                applyJSON(value)
                hasExplicitPreference = true
            }
        } catch {
            NSLog("⚠️ FilterState[\(scope)]: Failed to load — \(error.localizedDescription)")
        }
        isLoaded = true
    }

    // MARK: - Save to server (debounced)

    /// Schedule a debounced save. Call this after any filter change.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled, let self else { return }
            await self.save()
        }
    }

    /// Immediately save current filter state to the server.
    private func save() async {
        let key = "filters.\(scope)"
        let json = toJSON()

        do {
            let _: PreferenceUpdateResponse = try await api.request(
                endpoint: "/api/preferences/\(key)",
                method: "PUT",
                body: ["value": json],
                responseType: PreferenceUpdateResponse.self
            )
        } catch {
            NSLog("⚠️ FilterState[\(scope)]: Failed to save — \(error.localizedDescription)")
        }
    }

    // MARK: - Serialization

    private func toJSON() -> String {
        var dict: [String: Any] = [
            "tags": Array(tags),
            "leaders": Array(leaders),
            "sort": sort,
        ]

        // Only include media-specific fields for media scopes
        if scope.contains("media") {
            dict["mediaType"] = mediaType
            dict["timeFilter"] = timeFilter
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    fileprivate func applyJSON(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let tagArray = dict["tags"] as? [String] {
            tags = Set(tagArray)
        }
        if let leaderArray = dict["leaders"] as? [String] {
            leaders = Set(leaderArray)
        }
        if let sortValue = dict["sort"] as? String {
            sort = sortValue
        }
        if let mediaTypeValue = dict["mediaType"] as? String {
            mediaType = mediaTypeValue
        }
        if let timeFilterValue = dict["timeFilter"] as? String {
            timeFilter = timeFilterValue
        }
    }
}

// MARK: - FilterStateManager

final class FilterStateManager {
    static let shared = FilterStateManager()

    private var states: [String: FilterState] = [:]

    private init() {}

    /// Get or create a FilterState for the given scope.
    func state(for scope: String) -> FilterState {
        if let existing = states[scope] { return existing }
        let new = FilterState(scope: scope)
        states[scope] = new
        return new
    }

    /// Batch-load all registered filter scopes from the server.
    func loadAll() async {
        let scopes = Array(states.keys)
        guard !scopes.isEmpty else { return }

        let keys = scopes.map { "filters.\($0)" }

        do {
            let response: PreferenceBatchResponse = try await APIClient.shared.post(
                "/api/preferences/batch",
                body: ["keys": keys],
                responseType: PreferenceBatchResponse.self
            )

            for (key, value) in response.preferences ?? [:] {
                let scope = String(key.dropFirst("filters.".count))
                if let state = states[scope] {
                    state.applyJSON(value)
                    state.isLoaded = true
                }
            }
        } catch {
            NSLog("⚠️ FilterStateManager: Failed to batch-load — \(error.localizedDescription)")
        }

        // Mark remaining as loaded (even if no server data)
        for state in states.values where !state.isLoaded {
            state.isLoaded = true
        }
    }
}

// MARK: - API Response Types

private struct PreferenceResponse: Codable {
    let key: String?
    let value: String?
    let isDefault: Bool
}

private struct PreferenceUpdateResponse: Codable {
    let key: String?
    let value: String?
    let message: String?
}

private struct PreferenceBatchResponse: Codable {
    let preferences: [String: String]?
}
