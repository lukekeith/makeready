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

    /// Sessions are PER-ENVIRONMENT: a cookie minted by the production
    /// server means nothing to a local or staging one — sending it there
    /// just 401s every request. Each environment gets its own Keychain
    /// slot; switching environments switches which session is presented,
    /// and signing in stores under the environment that minted it.
    /// Production keeps the original account name so existing sessions
    /// survive this change.
    private static var account: String {
        switch Configuration.selectedEnvironment {
        case .production: return "session_cookie"
        case .local: return "session_cookie_local"
        case .staging: return "session_cookie_staging"
        }
    }

    /// Legacy UserDefaults key — read once for migration, then deleted.
    private static let legacyUserDefaultsKey = "makeready_session_cookie"

    // MARK: - In-Memory Cache

    /// Keychain reads are comparatively slow and the old code read
    /// UserDefaults freely, so cache values after the first read (keyed
    /// per environment account).
    private static let lock = NSLock()
    private static var cachedValues: [String: String] = [:]
    private static var loadedAccounts: Set<String> = []

    // MARK: - Public API

    /// Returns the session cookie for the CURRENT environment, or nil if
    /// the user has no session there. On first call for the production
    /// slot, migrates any value left in the legacy UserDefaults key into
    /// the Keychain so existing logged-in users stay logged in.
    static func get() -> String? {
        let acct = account
        lock.lock()
        defer { lock.unlock() }

        if loadedAccounts.contains(acct) {
            return cachedValues[acct]
        }

        var value = readFromKeychain(account: acct)

        // One-time migration from the legacy UserDefaults key — that value
        // could only ever have been a production session.
        if value == nil, acct == "session_cookie",
           let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey) {
            writeToKeychain(legacy, account: acct)
            UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
            value = legacy
        }

        cachedValues[acct] = value
        if value == nil { cachedValues.removeValue(forKey: acct) }
        loadedAccounts.insert(acct)
        return value
    }

    /// Stores the session cookie for the CURRENT environment.
    static func set(_ cookie: String) {
        let acct = account
        lock.lock()
        defer { lock.unlock() }

        writeToKeychain(cookie, account: acct)
        cachedValues[acct] = cookie
        loadedAccounts.insert(acct)
    }

    /// Removes the CURRENT environment's session cookie from the Keychain
    /// (and any legacy copy). Other environments' sessions are untouched —
    /// signing out of Local does not sign you out of Production.
    static func clear() {
        let acct = account
        lock.lock()
        defer { lock.unlock() }

        deleteFromKeychain(account: acct)
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsKey)
        cachedValues.removeValue(forKey: acct)
        loadedAccounts.insert(acct)
    }

    // MARK: - Keychain Primitives

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func readFromKeychain(account: String) -> String? {
        var query = baseQuery(account: account)
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

    private static func writeToKeychain(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete-then-add keeps the logic simple and ensures the
        // accessibility attribute is always applied.
        SecItemDelete(baseQuery(account: account) as CFDictionary)

        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        // AfterFirstUnlock so background refreshes/pushes can still read the
        // session after a reboot, before the device is unlocked again.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("⚠️ SessionCredentialStore: Keychain write failed (status: %d)", status)
        }
    }

    private static func deleteFromKeychain(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}
