//
//  DeviceTokenActions.swift
//  MakeReady
//
//  Actions for device token registration (push notifications).
//

import Foundation

/// Response from device token registration
struct DeviceTokenResponse: Codable {
    let success: Bool
    let error: String?
    let deviceToken: DeviceTokenData?
}

/// Device token data from server
struct DeviceTokenData: Codable {
    let id: String
    let userId: String
    let token: String
    let platform: String
    let environment: String
    let createdAt: String
    let updatedAt: String
}

/// Actions for managing APNs device tokens on the server.
struct DeviceTokenActions {

    private let api: APIClientProtocol

    /// - Parameter api: client for network calls; stub in tests
    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    // MARK: - Register Token

    /// Register a device token with the server
    /// - Parameters:
    ///   - token: The APNs device token (hex string)
    ///   - environment: Either "sandbox" or "production"
    @MainActor
    func registerToken(_ token: String, environment: String = "production") async throws {
        NSLog("📱 DeviceTokenActions: Registering token with server (environment: %@)", environment)

        let body: [String: Any] = [
            "token": token,
            "platform": "ios",
            "environment": environment
        ]

        let response: DeviceTokenResponse = try await api.post(
            "/api/device-tokens",
            body: body,
            responseType: DeviceTokenResponse.self
        )

        if !response.success {
            throw APIError.serverError(response.error ?? "Failed to register device token")
        }

        NSLog("✅ DeviceTokenActions: Token registered successfully")
    }

    // MARK: - Remove Token

    /// Remove a device token from the server (call on logout)
    /// - Parameter token: The APNs device token to remove
    @MainActor
    func removeToken(_ token: String) async throws {
        NSLog("📱 DeviceTokenActions: Removing token from server")

        // URL-encode the token for the path
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token

        let response: APISuccessResponse = try await api.delete(
            "/api/device-tokens/\(encodedToken)",
            responseType: APISuccessResponse.self
        )

        if !response.success {
            throw APIError.serverError(response.error ?? "Failed to remove device token")
        }

        NSLog("✅ DeviceTokenActions: Token removed successfully")
    }
}
