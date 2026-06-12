//
//  StatePersistence.swift
//  MakeReady
//
//  Handles reading and writing app state to disk.
//  Provides instant UI on app launch by loading cached state synchronously.
//

import Foundation
import UIKit

/// Handles persistence of app state to disk.
/// Designed for synchronous load on app launch and async save after mutations.
final class StatePersistence {

    // MARK: - Singleton

    static let shared = StatePersistence()

    // MARK: - Configuration

    /// Persisted state is PER-ENVIRONMENT (matching SessionCredentialStore):
    /// entities cached from the local dev server must not render while
    /// pointed at production — they look real but 404 on every mutation.
    /// Production keeps the legacy filename so existing installs keep
    /// their cache.
    private var fileName: String {
        switch Configuration.selectedEnvironment {
        case .production: return "app_state.json"
        case .local: return "app_state_local.json"
        case .staging: return "app_state_staging.json"
        }
    }
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Queue for serializing write operations
    private let writeQueue = DispatchQueue(label: "com.makeready.persistence.write", qos: .utility)

    /// Protects `pendingWorkItem` and `pendingSnapshot` (accessed from caller threads and writeQueue)
    private let pendingLock = NSLock()

    /// The currently scheduled debounced write, if any
    private var pendingWorkItem: DispatchWorkItem?

    /// The latest snapshot waiting to be written by the debounced work item,
    /// paired with the file URL captured when the save was REQUESTED — so a
    /// write scheduled before an environment switch still lands in the
    /// outgoing environment's file.
    private var pendingSnapshot: (state: PersistedState, url: URL)?

    // MARK: - Initialization

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

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
    /// Always writes the LATEST snapshot: each call replaces the pending
    /// snapshot and reschedules the write, so the last save before
    /// quiescence is never dropped.
    func save(_ state: PersistedState) {
        let url = fileURL // capture now — environment may switch before the write fires

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Take the latest snapshot (it may be newer than the one
            // captured when this item was scheduled).
            self.pendingLock.lock()
            let snapshot = self.pendingSnapshot
            self.pendingSnapshot = nil
            self.pendingWorkItem = nil
            self.pendingLock.unlock()

            // Nil if saveImmediately/clear already consumed or cancelled it
            guard let snapshot = snapshot else { return }
            self.performSave(snapshot.state, to: snapshot.url)
        }

        pendingLock.lock()
        pendingSnapshot = (state, url)
        pendingWorkItem?.cancel()
        pendingWorkItem = workItem
        pendingLock.unlock()

        // Debounce writes - wait a short time before actually writing
        writeQueue.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    /// Save immediately without debouncing.
    /// Use when you need to ensure state is persisted (e.g., app going to background).
    /// Cancels any pending debounced write (the passed-in state is the latest).
    /// Does NOT block the caller: encoding and the disk write happen on the
    /// write queue under a background-task assertion so the OS keeps the
    /// process alive until the write lands even mid-suspension.
    func saveImmediately(_ state: PersistedState) {
        let url = fileURL // capture now — environment may switch before the write lands
        cancelPendingWrite()

        // Both the expiration handler and our completion run on the main
        // queue, so taskID mutation is serialized.
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "StatePersistence.saveImmediately") {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }

        writeQueue.async { [weak self] in
            self?.performSave(state, to: url)
            DispatchQueue.main.async {
                if taskID != .invalid {
                    UIApplication.shared.endBackgroundTask(taskID)
                    taskID = .invalid
                }
            }
        }
    }

    /// Cancel any scheduled debounced write and discard its snapshot.
    private func cancelPendingWrite() {
        pendingLock.lock()
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        pendingSnapshot = nil
        pendingLock.unlock()
    }

    /// Perform the actual save operation
    private func performSave(_ state: PersistedState, to url: URL) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: url, options: [.atomic])
            NSLog("💾 StatePersistence: Saved state (\(data.count) bytes)")
        } catch {
            NSLog("❌ StatePersistence: Failed to save state: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear

    /// Delete persisted state (e.g., on logout).
    /// Also cancels any pending debounced write so a queued snapshot
    /// can't resurrect the cleared state.
    func clear() {
        let url = fileURL // the CURRENT environment's file (logout semantics)
        cancelPendingWrite()
        writeQueue.sync {
            do {
                try FileManager.default.removeItem(at: url)
                NSLog("💾 StatePersistence: Cleared persisted state")
            } catch {
                // Ignore error if file doesn't exist
                NSLog("💾 StatePersistence: Clear - file may not exist")
            }
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
