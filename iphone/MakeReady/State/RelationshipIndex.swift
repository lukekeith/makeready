//
//  RelationshipIndex.swift
//  MakeReady
//
//  Manages one-to-many relationship lookups between entities.
//  For example: programId → [enrollmentId, enrollmentId, ...]
//

import Foundation

/// Manages one-to-many relationship indexes between entities.
/// Allows efficient lookup of related entity IDs without duplicating data.
@Observable
class RelationshipIndex: Codable {

    // MARK: - Storage

    /// Maps parent ID to set of child IDs
    /// Using Set for O(1) add/remove and automatic deduplication
    private var index: [String: Set<String>] = [:]

    // MARK: - Initialization

    init() {}

    // MARK: - Query Operations

    /// Get all child IDs for a parent ID
    func get(_ parentId: String) -> [String] {
        Array(index[parentId] ?? [])
    }

    /// Get child IDs as a Set for efficient operations
    func getSet(_ parentId: String) -> Set<String> {
        index[parentId] ?? []
    }

    /// Check if a parent has any children
    func hasChildren(_ parentId: String) -> Bool {
        guard let children = index[parentId] else { return false }
        return !children.isEmpty
    }

    /// Get count of children for a parent
    func count(_ parentId: String) -> Int {
        index[parentId]?.count ?? 0
    }

    /// Check if a specific child is related to a parent
    func contains(parentId: String, childId: String) -> Bool {
        index[parentId]?.contains(childId) ?? false
    }

    // MARK: - Mutation Operations

    /// Add a child ID to a parent
    func add(parentId: String, childId: String) {
        if index[parentId] == nil {
            index[parentId] = []
        }
        index[parentId]?.insert(childId)
    }

    /// Add multiple children to a parent
    func addMany(parentId: String, childIds: [String]) {
        if index[parentId] == nil {
            index[parentId] = []
        }
        for childId in childIds {
            index[parentId]?.insert(childId)
        }
    }

    /// Remove a child ID from a parent
    func remove(parentId: String, childId: String) {
        index[parentId]?.remove(childId)
        // Clean up empty sets
        if index[parentId]?.isEmpty == true {
            index.removeValue(forKey: parentId)
        }
    }

    /// Remove all children for a parent
    func removeAll(parentId: String) {
        index.removeValue(forKey: parentId)
    }

    /// Replace all children for a parent
    func replace(parentId: String, childIds: [String]) {
        if childIds.isEmpty {
            index.removeValue(forKey: parentId)
        } else {
            index[parentId] = Set(childIds)
        }
    }

    /// Clear the entire index
    func clear() {
        index.removeAll()
    }

    /// Remove a child from ALL parents (useful when deleting an entity)
    func removeChild(_ childId: String) {
        for parentId in index.keys {
            index[parentId]?.remove(childId)
            if index[parentId]?.isEmpty == true {
                index.removeValue(forKey: parentId)
            }
        }
    }

    // MARK: - Batch Operations

    /// Build index from an array of items with a key extractor
    /// Useful for rebuilding index from entity list
    func rebuild<T>(from items: [T], parentKeyPath: KeyPath<T, String>, childKeyPath: KeyPath<T, String>) {
        index.removeAll()
        for item in items {
            let parentId = item[keyPath: parentKeyPath]
            let childId = item[keyPath: childKeyPath]
            add(parentId: parentId, childId: childId)
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case index
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode as [String: [String]] and convert to [String: Set<String>]
        let arrayIndex = try container.decode([String: [String]].self, forKey: .index)
        self.index = arrayIndex.mapValues { Set($0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode as [String: [String]] for JSON compatibility
        let arrayIndex = index.mapValues { Array($0) }
        try container.encode(arrayIndex, forKey: .index)
    }
}

// MARK: - Serialization Helpers

extension RelationshipIndex {
    /// Get all parent IDs that have children
    var allParentIds: [String] {
        Array(index.keys)
    }

    /// Convert to dictionary for serialization
    func toDictionary() -> [String: [String]] {
        index.mapValues { Array($0) }
    }

    /// Load from dictionary (replaces current state)
    func loadFromDictionary(_ dict: [String: [String]]) {
        index.removeAll()
        for (parentId, childIds) in dict {
            index[parentId] = Set(childIds)
        }
    }
}

// MARK: - Debug Helpers

extension RelationshipIndex: CustomDebugStringConvertible {
    var debugDescription: String {
        var lines: [String] = ["RelationshipIndex:"]
        for (parentId, childIds) in index.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(parentId): [\(childIds.sorted().joined(separator: ", "))]")
        }
        return lines.joined(separator: "\n")
    }
}
