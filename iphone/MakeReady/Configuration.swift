//
//  Configuration.swift
//  MakeReady
//
//  Environment configuration for local development, staging, and production.
//  When DEV_MODE is YES (set in xcconfig), the user menu shows an environment
//  switcher. The selected environment persists across launches via UserDefaults.
//

import Foundation

struct Configuration {

    // MARK: - Developer Mode

    /// Whether DEV_MODE is enabled in the build configuration (xcconfig → Info.plist).
    /// When true, the user menu shows environment radio buttons.
    /// When false, the app always uses production URLs.
    static var devMode: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DEV_MODE") as? String else {
            return false
        }
        return value.uppercased() == "YES"
    }

    // MARK: - Selected Environment

    /// User-selected environment, persisted in UserDefaults.
    /// Only meaningful when devMode is true — otherwise always production.
    enum SelectedEnvironment: String, CaseIterable {
        case local = "Local"
        case staging = "Staging"
        case production = "Production"
    }

    private static let environmentKey = "selectedEnvironment"
    private static let localServerIPKey = "localServerIP"
    static let defaultLocalIP = "192.168.1.65"

    /// User-specified local server IP address.
    /// Persisted in UserDefaults. Falls back to defaultLocalIP.
    static var localServerIP: String? {
        get {
            let saved = UserDefaults.standard.string(forKey: localServerIPKey)
            if let saved, !saved.isEmpty { return saved }
            // No value saved yet — persist and return the default
            UserDefaults.standard.set(defaultLocalIP, forKey: localServerIPKey)
            return defaultLocalIP
        }
        set {
            UserDefaults.standard.set(newValue, forKey: localServerIPKey)
        }
    }

    /// Call once at app startup to migrate stale local server IP.
    /// Removes any IP that is no longer reachable so the default takes over.
    static func migrateLocalServerIP() {
        guard devMode else { return }
        let saved = UserDefaults.standard.string(forKey: localServerIPKey)
        // Reset if the saved IP doesn't match the current default
        // (handles IP changes between networks)
        if let saved, saved != defaultLocalIP {
            UserDefaults.standard.set(defaultLocalIP, forKey: localServerIPKey)
        }
    }

    static var selectedEnvironment: SelectedEnvironment {
        get {
            guard devMode else { return .production }
            guard let raw = UserDefaults.standard.string(forKey: environmentKey),
                  let env = SelectedEnvironment(rawValue: raw) else {
                return .production // Default to production until explicitly changed
            }
            return env
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: environmentKey)
        }
    }

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

    /// Base URL for API requests.
    /// When devMode is on, uses the selected environment.
    /// When devMode is off, always uses production.
    static var baseURL: String {
        guard devMode else { return "https://api.makeready.org" }

        switch selectedEnvironment {
        case .local:
            #if targetEnvironment(simulator)
            if let base = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
               !base.isEmpty {
                return base
            }
            return "http://127.0.0.1:3010"
            #else
            // Physical device — prefer user-specified IP, then Bonjour, then cached
            if let ip = localServerIP, !ip.isEmpty {
                return "http://\(ip):3010"
            }
            if let discoveredURL = LocalServerDiscovery.shared.serverURL {
                return discoveredURL
            }
            if let cachedURL = LocalServerDiscovery.shared.cachedServerURL {
                return cachedURL
            }
            return "https://api.makeready.org"
            #endif

        case .staging:
            return "https://staging.api.makeready.org"

        case .production:
            return "https://api.makeready.org"
        }
    }

    /// Base URL for the web client (Laravel), used for preview URLs, deep links, etc.
    /// When devMode is on, uses the selected environment.
    /// When devMode is off, always uses production.
    static var clientBaseURL: String {
        guard devMode else { return "https://app.makeready.org" }

        switch selectedEnvironment {
        case .local:
            #if targetEnvironment(simulator)
            return "http://localhost:8000"
            #else
            // Physical device — prefer user-specified IP, then Bonjour, then cached
            if let ip = localServerIP, !ip.isEmpty {
                return "http://\(ip):8000"
            }
            if let discoveredURL = LocalServerDiscovery.shared.clientURL {
                return discoveredURL
            }
            if let cachedURL = LocalServerDiscovery.shared.cachedClientURL {
                return cachedURL
            }
            return "https://app.makeready.org"
            #endif

        case .staging:
            return "https://staging.app.makeready.org"

        case .production:
            return "https://app.makeready.org"
        }
    }

    /// Whether the app is using local development server
    static var isLocalDevelopment: Bool {
        return devMode && selectedEnvironment == .local
    }

    /// OAuth redirect URI scheme
    static let redirectScheme = "makeready"

    /// Bundle identifier (varies per environment)
    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.makeready.app"
    }

    // MARK: - Debug Features

    /// Whether authentication bypass is available (dev mode + local only)
    static var allowAuthBypass: Bool {
        return devMode && selectedEnvironment == .local
    }

    /// Whether to show debug information in UI (dev mode only)
    static var showDebugInfo: Bool {
        return devMode
    }

    /// Whether this is running in production mode
    static var isProduction: Bool {
        return !devMode || selectedEnvironment == .production
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
        print("   Dev Mode: \(devMode ? "ON" : "OFF")")
        if devMode {
            print("   Environment: \(selectedEnvironment.rawValue)")
        }
        print("   API URL: \(baseURL)")
        print("   Client URL: \(clientBaseURL)")
        print("   Bundle ID: \(bundleIdentifier)")
        print("   Auth Bypass: \(allowAuthBypass ? "Enabled" : "Disabled")")

        if isLocalDevelopment {
            if let apiURL = LocalServerDiscovery.shared.serverURL {
                print("   📡 Bonjour API: \(apiURL)")
            } else {
                print("   📡 Bonjour API: Searching...")
            }
            if let clientURL = LocalServerDiscovery.shared.clientURL {
                print("   📡 Bonjour Client: \(clientURL)")
            } else {
                print("   📡 Bonjour Client: Searching...")
            }
        }
    }
}
