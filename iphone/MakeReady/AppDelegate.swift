//
//  AppDelegate.swift
//  MakeReady
//
//  Handles push notification registration and callbacks.
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate to handle foreground notifications
        UNUserNotificationCenter.current().delegate = self

        NSLog("📱 AppDelegate: didFinishLaunchingWithOptions")
        return true
    }

    // MARK: - Orientation Lock (replaces deprecated UIRequiresFullScreen)

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Push Notification Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Convert token to hex string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NSLog("📱 APNs device token received (length: %d, suffix: %@)", tokenString.count, String(tokenString.suffix(4)))

        // Store token and register with server
        PushNotificationManager.shared.handleDeviceToken(tokenString)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("❌ Failed to register for remote notifications: %@", error.localizedDescription)

        // Notify the manager of failure
        PushNotificationManager.shared.handleRegistrationFailure(error)
    }

    // MARK: - Remote Notification Handling

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NSLog("📱 Received remote notification: %@", userInfo.description)

        // Handle the notification payload
        PushNotificationManager.shared.handleRemoteNotification(userInfo)

        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        NSLog("📱 Notification received in foreground: %@", userInfo.description)

        // Refresh notification badge count immediately
        Task { try? await NotificationActions().loadUnreadCount() }

        // Show banner and play sound even when in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NSLog("📱 Notification tapped: %@", userInfo.description)

        // Handle the notification action (navigate to appropriate screen)
        PushNotificationManager.shared.handleNotificationTap(userInfo)

        completionHandler()
    }
}
