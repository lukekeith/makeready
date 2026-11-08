//
//  ThemeModels.swift
//  MakeReady
//
//  Text theme models (JSONValue lives in JSONValue.swift).
//  Phase 5.7 — code motion from State/Models.swift.
//

import Foundation

// MARK: - Text Theme Models

/// A text rendering theme that controls how content is displayed
struct TextTheme: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let isSystem: Bool
    /// Raw JSON string of the theme definition, for passing to WKWebView
    let definitionJSON: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, isSystem, definition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false

        // Decode definition as raw JSON string for web view injection
        if let jsonValue = try? container.decodeIfPresent(JSONValue.self, forKey: .definition) {
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(jsonValue) {
                definitionJSON = String(data: data, encoding: .utf8)
            } else {
                definitionJSON = nil
            }
        } else {
            definitionJSON = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(slug, forKey: .slug)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(isSystem, forKey: .isSystem)
        // Re-encode definitionJSON back to a JSON value for the definition key
        if let jsonStr = definitionJSON, let data = jsonStr.data(using: .utf8),
           let jsonValue = try? JSONDecoder().decode(JSONValue.self, from: data) {
            try container.encode(jsonValue, forKey: .definition)
        }
    }

    init(id: String, name: String, slug: String, description: String? = nil, isSystem: Bool = false, definitionJSON: String? = nil) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.isSystem = isSystem
        self.definitionJSON = definitionJSON
    }
}
