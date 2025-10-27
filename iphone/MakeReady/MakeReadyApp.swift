//
//  MakeReadyApp.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

@main
struct MakeReadyApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainView()
                        .environmentObject(authManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
            .onOpenURL { url in
                NSLog("🔗 App received URL: %@", url.absoluteString)
                NSLog("🔗 URL scheme: %@", url.scheme ?? "none")
                NSLog("🔗 URL host: %@", url.host ?? "none")
                NSLog("🔗 URL path: %@", url.path)
                NSLog("🔗 URL query: %@", url.query ?? "none")
            }
        }
    }
}
