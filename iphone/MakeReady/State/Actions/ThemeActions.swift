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

    private let api = APIClient.shared

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
            AppState.shared.textThemes = sorted
            if let template = response.previewUrlTemplate {
                AppState.shared.previewUrlTemplate = template
            }
            AppState.shared.persist()
        }

        NSLog("🎨 ThemeActions: Loaded \(sorted.count) themes (previewUrlTemplate=\(response.previewUrlTemplate ?? "nil"))")
        return sorted
    }
}
