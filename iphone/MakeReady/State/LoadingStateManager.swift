//
//  LoadingStateManager.swift
//  MakeReady
//
//  Manages per-entity and per-list loading states for granular UI feedback.
//

import Foundation

/// Loading state for a single entity or list
enum LoadingState: Equatable, Codable {
    /// No loading in progress
    case idle

    /// First load, no cached data available
    case loading

    /// Has cached data, refreshing in background
    case refreshing

    /// Failed to load with error message
    case error(String)

    // MARK: - Convenience Properties

    /// Whether currently loading (either initial or refresh)
    var isActive: Bool {
        switch self {
        case .loading, .refreshing:
            return true
        case .idle, .error:
            return false
        }
    }

    /// Whether this is an initial load (no cached data)
    var isInitialLoading: Bool {
        self == .loading
    }

    /// Whether refreshing with cached data
    var isRefreshing: Bool {
        self == .refreshing
    }

    /// Whether there was an error
    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    /// Get error message if in error state
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

/// Well-known list types for list-level loading states
enum ListType: String, Codable {
    case programs
    case groups
    case enrollments
    case videos
    case members
    case posts
    case lessons
    case activities
    case media
    case homeStats
    case calendarEvents
}

/// Manages loading states for entities and lists.
/// Provides granular feedback for UI (e.g., spinner on single card vs whole list).
/// Main-actor isolated like AppState.
@MainActor
@Observable
class LoadingStateManager {

    // MARK: - Storage

    /// Per-entity loading states (keyed by entity ID)
    private var entityStates: [String: LoadingState] = [:]

    /// Per-list loading states (keyed by list type)
    private var listStates: [ListType: LoadingState] = [:]

    /// Per-context loading states (for custom contexts like "group-123-members")
    private var contextStates: [String: LoadingState] = [:]

    // MARK: - Entity States

    /// Get loading state for a specific entity
    func state(for id: String) -> LoadingState {
        entityStates[id] ?? .idle
    }

    /// Set loading state for a specific entity
    func setState(_ state: LoadingState, for id: String) {
        entityStates[id] = state
    }

    /// Check if entity is loading (initial or refresh)
    func isLoading(_ id: String) -> Bool {
        state(for: id).isActive
    }

    /// Check if entity is doing initial load
    func isInitialLoading(_ id: String) -> Bool {
        state(for: id).isInitialLoading
    }

    /// Check if entity is refreshing
    func isRefreshing(_ id: String) -> Bool {
        state(for: id).isRefreshing
    }

    /// Clear loading state for entity
    func clearState(for id: String) {
        entityStates.removeValue(forKey: id)
    }

    // MARK: - List States

    /// Get loading state for a list
    func state(for listType: ListType) -> LoadingState {
        listStates[listType] ?? .idle
    }

    /// Set loading state for a list
    func setState(_ state: LoadingState, for listType: ListType) {
        listStates[listType] = state
    }

    /// Check if list is loading
    func isLoading(_ listType: ListType) -> Bool {
        state(for: listType).isActive
    }

    /// Check if list is doing initial load
    func isInitialLoading(_ listType: ListType) -> Bool {
        state(for: listType).isInitialLoading
    }

    /// Check if list is refreshing
    func isRefreshing(_ listType: ListType) -> Bool {
        state(for: listType).isRefreshing
    }

    /// Clear loading state for list
    func clearState(for listType: ListType) {
        listStates.removeValue(forKey: listType)
    }

    // MARK: - Context States (for custom contexts)

    /// Get loading state for a custom context (e.g., "group-123-members")
    func state(forContext context: String) -> LoadingState {
        contextStates[context] ?? .idle
    }

    /// Set loading state for a custom context
    func setState(_ state: LoadingState, forContext context: String) {
        contextStates[context] = state
    }

    /// Check if context is loading
    func isLoading(context: String) -> Bool {
        state(forContext: context).isActive
    }

    /// Clear loading state for context
    func clearState(forContext context: String) {
        contextStates.removeValue(forKey: context)
    }

    // MARK: - Convenience Methods

    /// Start loading for an entity (chooses initial or refresh based on cached flag)
    func startLoading(_ id: String, hasCachedData: Bool) {
        setState(hasCachedData ? .refreshing : .loading, for: id)
    }

    /// Start loading for a list
    func startLoading(_ listType: ListType, hasCachedData: Bool) {
        setState(hasCachedData ? .refreshing : .loading, for: listType)
    }

    /// Start loading for a context
    func startLoading(context: String, hasCachedData: Bool) {
        setState(hasCachedData ? .refreshing : .loading, forContext: context)
    }

    /// Mark entity as loaded successfully
    func finishLoading(_ id: String) {
        setState(.idle, for: id)
    }

    /// Mark list as loaded successfully
    func finishLoading(_ listType: ListType) {
        setState(.idle, for: listType)
    }

    /// Mark context as loaded successfully
    func finishLoading(context: String) {
        setState(.idle, forContext: context)
    }

    /// Mark entity as failed
    func setError(_ message: String, for id: String) {
        setState(.error(message), for: id)
    }

    /// Mark list as failed
    func setError(_ message: String, for listType: ListType) {
        setState(.error(message), for: listType)
    }

    /// Mark context as failed
    func setError(_ message: String, forContext context: String) {
        setState(.error(message), forContext: context)
    }

    // MARK: - Clear All

    /// Clear all loading states
    func clearAll() {
        entityStates.removeAll()
        listStates.removeAll()
        contextStates.removeAll()
    }
}

// MARK: - Context Helpers

extension LoadingStateManager {

    /// Create a context key for a parent-child relationship
    /// Example: contextKey(.groups, "123", .members) → "groups-123-members"
    static func contextKey(_ parentType: ListType, _ parentId: String, _ childType: ListType) -> String {
        "\(parentType.rawValue)-\(parentId)-\(childType.rawValue)"
    }
}
