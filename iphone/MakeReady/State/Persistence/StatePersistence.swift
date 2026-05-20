//
//  StatePersistence.swift
//  MakeReady
//
//  Handles reading and writing app state to disk.
//  Provides instant UI on app launch by loading cached state synchronously.
//

import Foundation

/// Handles persistence of app state to disk.
/// Designed for synchronous load on app launch and async save after mutations.
final class StatePersistence {

    // MARK: - Singleton

    static let shared = StatePersistence()

    // MARK: - Configuration

    private let fileName = "app_state.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Queue for serializing write operations
    private let writeQueue = DispatchQueue(label: "com.makeready.persistence.write", qos: .utility)

    /// Flag to track if we have any pending writes
    private var hasPendingWrite = false

    // MARK: - Initialization

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - File Location

    /// Get the file URL for the state file
    private var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent(fileName)
    }

    // MARK: - Load (Synchronous)

    /// Load persisted state from disk.
    /// Called synchronously on app launch for instant UI.
    /// Returns nil if no state exists or if loading fails.
    func load() -> PersistedState? {
        let url = fileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("💾 StatePersistence: No persisted state file found")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let state = try decoder.decode(PersistedState.self, from: data)
            NSLog("💾 StatePersistence: Loaded state (persisted at \(state.persistedAt))")
            NSLog("   Programs: \(state.programs.count), Groups: \(state.groups.count), Enrollments: \(state.enrollments.count)")
            return state
        } catch {
            NSLog("❌ StatePersistence: Failed to load state: \(error.localizedDescription)")
            // Delete corrupted file
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Save (Asynchronous)

    /// Save state to disk asynchronously.
    /// Debounced to avoid excessive writes during rapid mutations.
    func save(_ state: PersistedState) {
        // Mark that we have a pending write
        hasPendingWrite = true

        // Debounce writes - wait a short time before actually writing
        writeQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            // Only write if this is still the most recent request
            guard self.hasPendingWrite else { return }
            self.hasPendingWrite = false

            self.performSave(state)
        }
    }

    /// Save immediately without debouncing.
    /// Use when you need to ensure state is persisted (e.g., app going to background).
    func saveImmediately(_ state: PersistedState) {
        hasPendingWrite = false
        writeQueue.sync {
            performSave(state)
        }
    }

    /// Perform the actual save operation
    private func performSave(_ state: PersistedState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: [.atomic])
            NSLog("💾 StatePersistence: Saved state (\(data.count) bytes)")
        } catch {
            NSLog("❌ StatePersistence: Failed to save state: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear

    /// Delete persisted state (e.g., on logout)
    func clear() {
        do {
            try FileManager.default.removeItem(at: fileURL)
            NSLog("💾 StatePersistence: Cleared persisted state")
        } catch {
            // Ignore error if file doesn't exist
            NSLog("💾 StatePersistence: Clear - file may not exist")
        }
    }

    // MARK: - Debug

    /// Get file info for debugging
    func getFileInfo() -> (exists: Bool, size: Int64, modifiedAt: Date?) {
        let url = fileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return (false, 0, nil)
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modifiedAt = attributes[.modificationDate] as? Date
            return (true, size, modifiedAt)
        } catch {
            return (true, 0, nil)
        }
    }
}
