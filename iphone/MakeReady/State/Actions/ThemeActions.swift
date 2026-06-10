//
//  ThemeActions.swift
//  MakeReady
//
//  Actions for text theme operations.
//  Handles fetching available themes from the API.
//

import Foundation

/// Actions for loading text themes used in read block rendering.
struct ThemeActions {

    private let api: APIClientProtocol
    private let stateOverride: AppState?

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    // MARK: - Load Themes

    /// Load all available text themes. Also stores the preview URL template
    /// returned by the API onto `AppState.shared.previewUrlTemplate` so the
    /// read-activity preview modal can build the canonical URL to open.
    /// - Returns: Array of TextTheme objects
    func loadThemes() async throws -> [TextTheme] {
        struct ThemesResponse: Decodable {
            let success: Bool
            let themes: [TextTheme]?
            let previewUrlTemplate: String?
            let error: String?
        }

        let response: ThemesResponse = try await api.get(
            "/api/themes",
            responseType: ThemesResponse.self
        )

        guard response.success, let themes = response.themes else {
            throw APIError.serverError(response.error ?? "Failed to load themes")
        }

        // Canonical order for all callers: "No Theme" (slug "none") first,
        // then alphabetical by display name.
        let sorted = themes.sorted {
            if $0.slug == "none" { return true }
            if $1.slug == "none" { return false }
            return $0.name < $1.name
        }

        await MainActor.run {
            state.textThemes = sorted
            if let template = response.previewUrlTemplate {
                state.previewUrlTemplate = template
            }
            state.persist()
        }

        NSLog("🎨 ThemeActions: Loaded \(sorted.count) themes (previewUrlTemplate=\(response.previewUrlTemplate ?? "nil"))")
        return sorted
    }
}
