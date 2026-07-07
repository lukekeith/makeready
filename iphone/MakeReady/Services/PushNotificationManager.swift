//
//  PushNotificationManager.swift
//  MakeReady
//
//  Manages push notification permissions, token registration, and notification handling.
//

import Foundation
import UserNotifications
import UIKit

/// Deep link destinations for push notifications and file imports
enum DeepLink: Equatable {
    case joinRequests(groupId: String)
    case group(groupId: String)
    /// Study Sync settings for one enrollment (study-sync notifications).
    case enrollmentSync(enrollmentId: String)
    case importFile(URL)
    case none
}

/// Observable singleton managing push notification state and actions
@Observable
final class PushNotificationManager {

    // MARK: - Singleton

    static let shared = PushNotificationManager()

    // MARK: - State

    /// Current device token (hex string)
    private(set) var deviceToken: String?

    /// Whether push notifications are authorized
    private(set) var isAuthorized: Bool = false

    /// Whether we've requested permission
    private(set) var hasRequestedPermission: Bool = false

    /// Registration error (if any)
    private(set) var registrationError: Error?

    /// Pending deep link to navigate to
    var pendingDeepLink: DeepLink = .none

    // MARK: - Private

    private let userDefaultsKey = "makeready_device_token"
    private var hasRegisteredWithServer = false

    // MARK: - Initialization

    private init() {
        // Load cached token
        deviceToken = UserDefaults.standard.string(forKey: userDefaultsKey)

        // Check current authorization status
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Permission Request

    /// Request notification permission and register for remote notifications.
    /// Call this after user logs in.
    @MainActor
    func requestPermissionAndRegister() async {
        NSLog("📱 PushNotificationManager: Requesting notification permission...")

        hasRequestedPermission = true

        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted

            if granted {
                NSLog("✅ Notification permission granted")
                // Register for remote notifications (must be on main thread)
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                NSLog("⚠️ Notification permission denied")
            }
        } catch {
            NSLog("❌ Failed to request notification permission: %@", error.localizedDescription)
            registrationError = error
        }
    }

    /// Check current authorization status without prompting
    @MainActor
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        isAuthorized = settings.authorizationStatus == .authorized

        // If already authorized and we have no token, re-register
        if isAuthorized && deviceToken == nil {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Token Handling

    /// Called by AppDelegate when device token is received
    func handleDeviceToken(_ token: String) {
        NSLog("📱 PushNotificationManager: Received device token")

        // Store token locally
        deviceToken = token
        UserDefaults.standard.set(token, forKey: userDefaultsKey)

        // Register with server
        Task {
            await registerTokenWithServer()
        }
    }

    /// Called by AppDelegate when registration fails
    func handleRegistrationFailure(_ error: Error) {
        NSLog("❌ PushNotificationManager: Registration failed: %@", error.localizedDescription)
        registrationError = error
    }

    /// Register the current token with the server
    @MainActor
    func registerTokenWithServer() async {
        guard let token = deviceToken else {
            NSLog("⚠️ PushNotificationManager: No device token to register")
            return
        }

        // Determine environment based on build configuration
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif

        do {
            try await DeviceTokenActions().registerToken(token, environment: environment)
            hasRegisteredWithServer = true
            NSLog("✅ PushNotificationManager: Token registered with server")
        } catch {
            NSLog("❌ PushNotificationManager: Failed to register token with server: %@", error.localizedDescription)
            registrationError = error
        }
    }

    /// Remove the current token from the server (call on logout)
    @MainActor
    func removeTokenFromServer() async {
        guard let token = deviceToken else {
            return
        }

        do {
            try await DeviceTokenActions().removeToken(token)
            NSLog("✅ PushNotificationManager: Token removed from server")
        } catch {
            // Don't fail logout if token removal fails
            NSLog("⚠️ PushNotificationManager: Failed to remove token from server: %@", error.localizedDescription)
        }

        // Clear local state
        deviceToken = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        hasRegisteredWithServer = false
    }

    // MARK: - Notification Handling

    /// Handle incoming remote notification (background fetch)
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        // Extract notification data
        guard let type = userInfo["type"] as? String else {
            NSLog("⚠️ PushNotificationManager: Unknown notification type")
            return
        }

        NSLog("📱 PushNotificationManager: Handling notification type: %@", type)

        switch type {
        case "JOIN_REQUEST":
            if let groupId = userInfo["groupId"] as? String {
                NSLog("📱 PushNotificationManager: Join request for group %@", groupId)
            }
        case "MEMBER_JOINED":
            if let groupId = userInfo["groupId"] as? String {
                NSLog("📱 PushNotificationManager: Member joined group %@", groupId)
            }
        default:
            NSLog("⚠️ PushNotificationManager: Unhandled notification type: %@", type)
        }

        // Refresh notification badge count
        Task {
            try? await NotificationActions().loadUnreadCount()
        }
    }

    /// Handle notification tap (user interaction)
    func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else {
            NSLog("⚠️ PushNotificationManager: Unknown notification type on tap")
            return
        }

        NSLog("📱 PushNotificationManager: Notification tapped, type: %@", type)

        switch type {
        case "JOIN_REQUEST":
            if let groupId = userInfo["groupId"] as? String {
                DispatchQueue.main.async {
                    self.pendingDeepLink = .joinRequests(groupId: groupId)
                    NSLog("📱 PushNotificationManager: Set deep link to join requests for group %@", groupId)
                }
            }
        case "MEMBER_JOINED":
            if let groupId = userInfo["groupId"] as? String {
                DispatchQueue.main.async {
                    self.pendingDeepLink = .group(groupId: groupId)
                    NSLog("📱 PushNotificationManager: Set deep link to group %@", groupId)
                }
            }
        case "STUDY_SYNC_UPDATES_AVAILABLE", "STUDY_SYNC_APPLIED":
            if let enrollmentId = userInfo["enrollmentId"] as? String {
                DispatchQueue.main.async {
                    self.pendingDeepLink = .enrollmentSync(enrollmentId: enrollmentId)
                    Log.push.info("deep link to enrollment sync")
                }
            }
        default:
            NSLog("⚠️ PushNotificationManager: Unhandled notification tap type: %@", type)
        }
    }

    /// Clear pending deep link after handling
    func clearPendingDeepLink() {
        pendingDeepLink = .none
    }
}
