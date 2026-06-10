//
//  EntityStore.swift
//  MakeReady
//
//  Generic normalized storage for entities keyed by ID.
//  Part of the centralized state management system.
//

import Foundation

/// Generic normalized storage container for entities.
/// Stores entities in a dictionary keyed by their ID for O(1) lookup.
/// Requires entities to have String IDs (which all our models do).
/// Main-actor isolated like AppState — persistence snapshots copy out
/// via `all` on the main actor (see PersistedState), never by encoding
/// the store itself.
@MainActor
@Observable
class EntityStore<T: Identifiable & Codable> where T.ID == String {

    // MARK: - Storage

    private(set) var entities: [String: T] = [:]

    // MARK: - Computed Properties

    /// All entities as an array (unordered)
    var all: [T] {
        Array(entities.values)
    }

    /// Number of entities in the store
    var count: Int {
        entities.count
    }

    /// Whether the store is empty
    var isEmpty: Bool {
        entities.isEmpty
    }

    /// All entity IDs
    var ids: [String] {
        Array(entities.keys)
    }

    // MARK: - Initialization

    init() {}

    init(entities: [T]) {
        for entity in entities {
            self.entities[entity.id] = entity
        }
    }

    // MARK: - CRUD Operations

    /// Get an entity by ID
    subscript(id: String) -> T? {
        get { entities[id] }
    }

    /// Get an entity by ID (explicit method)
    func get(_ id: String) -> T? {
        entities[id]
    }

    /// Insert or update a single entity
    func upsert(_ entity: T) {
        entities[entity.id] = entity
    }

    /// Insert or update multiple entities
    func upsertMany(_ newEntities: [T]) {
        for entity in newEntities {
            entities[entity.id] = entity
        }
    }

    /// Replace all entities (clears existing and adds new)
    func replaceAll(_ newEntities: [T]) {
        entities.removeAll()
        for entity in newEntities {
            entities[entity.id] = entity
        }
    }

    /// Remove an entity by ID
    @discardableResult
    func remove(_ id: String) -> T? {
        entities.removeValue(forKey: id)
    }

    /// Remove multiple entities by IDs
    func removeMany(_ ids: [String]) {
        for id in ids {
            entities.removeValue(forKey: id)
        }
    }

    /// Clear all entities
    func clear() {
        entities.removeAll()
    }

    /// Check if an entity exists
    func contains(_ id: String) -> Bool {
        entities[id] != nil
    }

    // MARK: - Merge Operations

    /// Merge entities, optionally removing those not in the new set
    func merge(_ newEntities: [T], removeStale: Bool = false) {
        if removeStale {
            let newIds = Set(newEntities.map { $0.id })
            let staleIds = entities.keys.filter { !newIds.contains($0) }
            for id in staleIds {
                entities.removeValue(forKey: id)
            }
        }

        for entity in newEntities {
            entities[entity.id] = entity
        }
    }

    // MARK: - Query Helpers

    /// Filter entities by predicate
    func filter(_ predicate: (T) -> Bool) -> [T] {
        entities.values.filter(predicate)
    }

    /// Get entities by multiple IDs (preserving order)
    func getMany(_ ids: [String]) -> [T] {
        ids.compactMap { entities[$0] }
    }

    /// Get first entity matching predicate
    func first(where predicate: (T) -> Bool) -> T? {
        entities.values.first(where: predicate)
    }
}

// MARK: - Convenience Extensions

extension EntityStore {

    /// Update a specific entity with a transform function
    /// Returns true if entity was found and updated
    @discardableResult
    func update(_ id: String, transform: (inout T) -> Void) -> Bool {
        guard var entity = entities[id] else { return false }
        transform(&entity)
        entities[id] = entity
        return true
    }
}
