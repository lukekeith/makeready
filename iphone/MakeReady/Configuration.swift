//
//  Configuration.swift
//  MakeReady
//
//  Environment configuration for local development, staging, and production
//

import Foundation

struct Configuration {

    // MARK: - Install Source Detection

    /// Determines how the app was installed on the device
    enum InstallSource {
        case xcode       // Installed via Xcode (USB or Simulator)
        case testFlight  // Installed via TestFlight
        case appStore    // From App Store

        static var current: InstallSource {
            #if targetEnvironment(simulator)
            return .xcode
            #else
            // TestFlight uses sandbox receipts — check receipt path directly
            // to avoid deprecated appStoreReceiptURL
            let sandboxReceiptURL = Bundle.main.bundleURL.appendingPathComponent("_MASReceipt/sandboxReceipt")
            if FileManager.default.fileExists(atPath: sandboxReceiptURL.path) {
                return .testFlight
            }
            // Xcode builds have embedded.mobileprovision
            if Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil {
                return .xcode
            }
            return .appStore
            #endif
        }

        var displayName: String {
            switch self {
            case .xcode: return "Xcode"
            case .testFlight: return "TestFlight"
            case .appStore: return "App Store"
            }
        }
    }

    // MARK: - Environment

    enum Environment: String {
        case debug = "Debug"
        case development = "Development"
        case staging = "Staging"
        case production = "Production"

        var displayName: String {
            return self.rawValue
        }
    }

    // MARK: - Current Environment

    static var current: Environment {
        #if DEBUG
        return .debug
        #elseif DEVELOPMENT
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    // MARK: - API Configuration

    /// Base URL for API requests
    /// - Simulator: Always uses local development server (127.0.0.1)
    /// - Xcode on Physical Device: Uses Bonjour-discovered server or fallback IP
    /// - TestFlight/App Store: Uses production server
    static var baseURL: String {
        switch InstallSource.current {
        case .xcode:
            #if targetEnvironment(simulator)
            // Simulator can use localhost directly.
            // Prefer API_BASE_URL from Info.plist (wired to xcconfig), fallback to 127.0.0.1:3010.
            if let base = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
               !base.isEmpty {
                return base
            }
            return "http://127.0.0.1:3010"
            #else
            // Physical device via Xcode
            // 1) Prefer explicit LOCAL_SERVER_URL (Info.plist)
            // 2) Else use Bonjour-discovered server if available
            // 3) Else use API_BASE_URL *if* it's not a loopback host
            // 4) Else fall back to production
            if let localURL = Bundle.main.object(forInfoDictionaryKey: "LOCAL_SERVER_URL") as? String,
               !localURL.isEmpty {
                return localURL
            }

            if let discoveredURL = LocalServerDiscovery.shared.serverURL {
                return discoveredURL
            }

            if let base = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
               !base.isEmpty,
               !base.contains("127.0.0.1"),
               !base.contains("localhost") {
                return base
            }

            return "https://api.makeready.org"
            #endif

        case .testFlight, .appStore:
            return "https://api.makeready.org"
        }
    }

    /// Base URL for the web client (Laravel), used for preview URLs, deep links, etc.
    /// Laravel dev server is `php artisan serve` on :8000 — NOT Vite on :5173
    /// (Vite only serves built assets, not Blade routes).
    static var clientBaseURL: String {
        switch InstallSource.current {
        case .xcode:
            #if targetEnvironment(simulator)
            return "http://localhost:8000"
            #else
            return "https://app.makeready.org"
            #endif
        case .testFlight, .appStore:
            return "https://app.makeready.org"
        }
    }

    /// Whether the app is using local development server
    static var isLocalDevelopment: Bool {
        return InstallSource.current == .xcode
    }

    /// OAuth redirect URI scheme
    static let redirectScheme = "makeready"

    /// Bundle identifier (varies per environment)
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.makeready.app"
    }

    // MARK: - Debug Features

    /// Whether authentication bypass is available (Xcode builds only)
    static var allowAuthBypass: Bool {
        return InstallSource.current == .xcode
    }

    /// Whether to show debug information in UI (Xcode builds only)
    static var showDebugInfo: Bool {
        return InstallSource.current == .xcode
    }

    /// Whether this is running in production mode
    static var isProduction: Bool {
        return InstallSource.current != .xcode
    }

    // MARK: - Target Environment

    /// Whether running on simulator or physical device
    static var targetEnvironment: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        return "Physical Device"
        #endif
    }

    // MARK: - Logging

    /// Log current configuration on app launch
    static func printConfiguration() {
        print("🔧 MakeReady Configuration")
        print("   Install Source: \(InstallSource.current.displayName)")
        print("   Target: \(targetEnvironment)")
        print("   Build: \(current.displayName)")
        print("   Base URL: \(baseURL)")
        print("   Bundle ID: \(bundleIdentifier)")
        print("   Local Development: \(isLocalDevelopment ? "Yes" : "No")")
        print("   Auth Bypass: \(allowAuthBypass ? "Enabled" : "Disabled")")
        print("   Debug Info: \(showDebugInfo ? "Enabled" : "Disabled")")
        print("   Is Production: \(isProduction ? "Yes" : "No")")

        if isLocalDevelopment {
            if let discoveredURL = LocalServerDiscovery.shared.serverURL {
                print("   📡 Bonjour: Connected to \(discoveredURL)")
            } else {
                print("   📡 Bonjour: Searching for local server...")
            }
        }
    }
}
