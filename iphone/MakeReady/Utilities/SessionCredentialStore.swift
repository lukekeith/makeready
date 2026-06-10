//
//  SessionCredentialStore.swift
//  MakeReady
//
//  Keychain-backed storage for the server session cookie (connect.sid).
//  Single source of truth for session credential persistence — replaces the
//  legacy UserDefaults key that was read independently by AuthManager,
//  APIClient, and the Bible services.
//

import Foundation
import Security

enum SessionCredentialStore {

    // MARK: - Configuration

    /// Keychain service string, scoped to the bundle identifier so each
    /// build configuration (debug/dev/staging/release) keeps its own session.
    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "com.makeready.app").credentials"
    }

    private static let account = "session_cookie"

    /// Legacy UserDefaults key — read once for migration, then deleted.
    private static let legacyUserDefaultsKey = "makeready_session_cookie"

    // MARK: - In-Memory Cache

    /// Keychain reads are comparatively slow and the old code read
    /// UserDefaults freely, so cache the value after the first read.
    private static let lock = NSLock()
    private static var cachedValue: String?
    private static var hasLoadedFromKeychain = false

    // MARK: - Public API

    /// Returns the session cookie, or nil if the user has no session.
    /// On first call, migrates any value left in the legacy UserDefaults key
    /// into the Keychain so existing logged-in users stay logged in.
    static func get() -> String? {
        lock.lock()
        defer { lock.unlock() }

        if hasLoadedFromKeychain {
            return cachedValue
        }

        var value = readFromKeychain()

        // One-time migration from the legacy UserDefaults key
        if value == nil,
           let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey) {
            writeToKeychain(legacy)
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
            value = legacy
        }

        cachedValue = value
        hasLoadedFromKeychain = true
        return value
    }

    /// Stores the session cookie in the Keychain.
    static func set(_ cookie: String) {
        lock.lock()
        defer { lock.unlock() }

        writeToKeychain(cookie)
        cachedValue = cookie
        hasLoadedFromKeychain = true
    }

    /// Removes the session cookie from the Keychain (and any legacy copy).
    static func clear() {
        lock.lock()
        defer { lock.unlock() }

        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        cachedValue = nil
        hasLoadedFromKeychain = true
    }

    // MARK: - Keychain Primitives

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func readFromKeychain() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func writeToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete-then-add keeps the logic simple and ensures the
        // accessibility attribute is always applied.
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = data
        // AfterFirstUnlock so background refreshes/pushes can still read the
        // session after a reboot, before the device is unlocked again.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("⚠️ SessionCredentialStore: Keychain write failed (status: %d)", status)
        }
    }

    private static func deleteFromKeychain() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
