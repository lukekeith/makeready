//
//  MakeReadyApp.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

@main
struct MakeReadyApp: App {
    // Connect AppDelegate for push notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var authManager = AuthManager()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        Configuration.migrateLocalServerIP()
        Configuration.printConfiguration()
        KeyboardToolbarInstaller.install()
        KeyboardScrollManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainView()
                        .environment(authManager)
                } else {
                    LoginView()
                        .environment(authManager)
                }
            }
            .onOpenURL { url in
                NSLog("🔗 App received URL: %@", url.absoluteString)
                NSLog("🔗 URL scheme: %@", url.scheme ?? "none")
                NSLog("🔗 URL host: %@", url.host ?? "none")
                NSLog("🔗 URL path: %@", url.path)
                NSLog("🔗 URL query: %@", url.query ?? "none")

                // Handle deep links
                handleDeepLink(url)
            }
            .task {
                // Pre-download Bible data in background on app launch
                await BibleCacheManager.shared.preloadBible()
            }
            .task {
                // On Local dev builds, make sure we're pointed at the right API
                // port — heals it within the configured range if it moved.
                await LocalPortHealer.heal()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    // Flush any debounced state write before the OS suspends us
                    AppState.shared.persistImmediately()
                }
            }
        }
    }

    /// Handle incoming deep links
    private func handleDeepLink(_ url: URL) {
        // File-based open: iOS hands us a file:// URL when the user taps a .makeready file
        // in Files/Mail/Messages/etc. with our app selected as the handler.
        if url.isFileURL {
            let ext = url.pathExtension.lowercased()
            guard ext == "makeready" else {
                NSLog("🔗 Ignoring file URL with unsupported extension: %@", ext)
                return
            }

            NSLog("🔗 Received .makeready file open request: %@", url.lastPathComponent)

            // iOS hands the file in a security-scoped sandbox location that may be
            // cleaned up before the import flow runs. Copy it into the app's
            // temporary directory immediately so the import flow can read it later.
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let tempDir = FileManager.default.temporaryDirectory
                let stableURL = tempDir.appendingPathComponent("inbox-\(UUID().uuidString)-\(url.lastPathComponent)")

                if FileManager.default.fileExists(atPath: stableURL.path) {
                    try FileManager.default.removeItem(at: stableURL)
                }

                try FileManager.default.copyItem(at: url, to: stableURL)
                NSLog("🔗 Copied import file to temp location: %@", stableURL.path)

                PushNotificationManager.shared.pendingDeepLink = .importFile(stableURL)
            } catch {
                NSLog("❌ Failed to copy incoming .makeready file: %@", error.localizedDescription)
            }
            return
        }

        guard url.scheme == "makeready" else { return }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        NSLog("🔗 Processing deep link - host: %@, path: %@", host, pathComponents.joined(separator: "/"))

        switch host {
        case "join-requests":
            // makeready://join-requests/{groupId}
            if let groupId = pathComponents.first {
                NSLog("🔗 Deep link: Navigate to join requests for group %@", groupId)
                PushNotificationManager.shared.pendingDeepLink = .joinRequests(groupId: groupId)
            }

        case "group":
            // makeready://group/{groupId}
            if let groupId = pathComponents.first {
                NSLog("🔗 Deep link: Navigate to group %@", groupId)
                PushNotificationManager.shared.pendingDeepLink = .group(groupId: groupId)
            }

        default:
            NSLog("🔗 Unknown deep link host: %@", host)
        }
    }
}
