//
//  SearchModels.swift
//  MakeReady
//
//  master-search: the wire types of C1-C5 (`/api/search/ranked`, `/recent-results`,
//  `/filter-options`). Named to avoid `SearchResult` and `RecentSearch`, already taken.
//

import Foundation

/// The object a result or recent opens into (a lesson's program, an event's group, ...).
struct SearchItemParent: Codable, Equatable {
    let type: String
    let id: String
    let name: String
}

/// One row of C1 or C2. `type` stays a string so a type a later server adds cannot fail a page
/// in a released build (the mapper drops what it does not know). `score` is not decoded.
struct SearchItem: Codable, Equatable, Identifiable {
    let type: String
    let id: String
    let title: String
    let createdAt: String
    let imageUrl: String?
    let parent: SearchItemParent?
    /// C2 only.
    let openedAt: String?

    /// Identity across types: ids are unique within one table, not across them.
    var key: String { type + ":" + id }
}

/// C1 and C2.
struct SearchItemsResponse: Codable {
    let success: Bool
    let items: [SearchItem]
    /// C1 only.
    let nextCursor: String?
    let error: String?
}

struct SearchFilterOrg: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

struct SearchFilterGroup: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let organizationId: String
}

struct SearchFilterLeader: Codable, Equatable, Identifiable {
    let id: String
    let name: String
}

struct SearchFilterTag: Codable, Equatable, Identifiable {
    let tag: String
    let label: String
    let category: String?

    var id: String { tag }
}

/// C5.
struct SearchFilterOptions: Codable, Equatable {
    let success: Bool
    let organizations: [SearchFilterOrg]
    let groups: [SearchFilterGroup]
    let leaders: [SearchFilterLeader]
    let tags: [SearchFilterTag]
    let error: String?
}

/// The five picks C1 and C2 both take (D6).
struct SearchFilters: Equatable {
    var types: [String] = []
    var orgIds: [String] = []
    var groupIds: [String] = []
    var leaderIds: [String] = []
    var tags: [String] = []

    /// The non-empty lists as query parameters, values comma-joined and not yet percent-encoded.
    var queryPairs: [(name: String, value: String)] {
        [("types", types), ("orgIds", orgIds), ("groupIds", groupIds),
         ("leaderIds", leaderIds), ("tags", tags)]
            .filter { !$0.1.isEmpty }
            .map { (name: $0.0, value: $0.1.joined(separator: ",")) }
    }
}
