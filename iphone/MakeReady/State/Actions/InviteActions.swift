//
//  InviteActions.swift
//  MakeReady
//
//  Actions for invite creation and QR code generation.
//  Moved out of AuthManager (Phase 2.6) — auth lifecycle stays there,
//  API operations live here like every other domain.
//

import Foundation
import UIKit

// Invite model matching server response
struct Invite: Codable {
    let id: String
    let code: String
    let groupId: String?
    let createdAt: String  // ISO date string
    let expiresAt: String?  // ISO date string
    let userId: String
}

struct QRCodeResponse: Codable {
    let success: Bool
    let qrCode: String?
    let data: String?
    let error: String?
}

/// Actions for invites and server-generated QR codes.
struct InviteActions {

    private let api: APIClientProtocol

    /// - Parameter api: client for network calls; stub in tests
    init(api: APIClientProtocol = APIClient.shared) {
        self.api = api
    }

    // MARK: - Invite Creation

    /// Create an invite (optionally scoped to a group, optionally expiring).
    @MainActor
    func createInvite(groupId: String? = nil, expiresAt: String? = nil) async throws -> Invite {
        struct CreateInviteResponse: Codable {
            let success: Bool
            let invite: Invite?
            let error: String?
        }

        var body: [String: Any] = [:]
        if let groupId {
            body["groupId"] = groupId
        }
        if let expiresAt {
            body["expiresAt"] = expiresAt
        }

        let response: CreateInviteResponse = try await api.post(
            "/api/invites",
            body: body.isEmpty ? nil : body,
            responseType: CreateInviteResponse.self
        )

        guard response.success, let invite = response.invite else {
            throw APIError.serverError(response.error ?? "Failed to create invite")
        }

        return invite
    }

    // MARK: - QR Code Generation

    /// Generate a styled QR code image on the server.
    /// Builds its own URLRequest (not via APIClientProtocol) because QR
    /// responses must never be cached (`reloadIgnoringLocalCacheData`),
    /// which APIClient doesn't support. The session credential still comes
    /// from its single owner, APIClient.
    func generateQRCode(
        data: String,
        color: String = "#6c47ff",
        backgroundColor: String = "#ffffff",
        size: Int = 600,
        errorCorrectionLevel: String = "M",
        includeLogo: Bool = true
    ) async throws -> UIImage {
        guard let url = URL(string: "\(Configuration.baseURL)/api/qrcode/generate") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData  // Never cache QR codes
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add session cookie for authentication
        if let sessionCookie = APIClient.shared.sessionCookieValue {
            request.setValue("connect.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        }

        // Request body
        let body: [String: Any] = [
            "data": data,
            "color": color,
            "backgroundColor": backgroundColor,
            "size": size,
            "errorCorrectionLevel": errorCorrectionLevel,
            "includeLogo": includeLogo
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // Check for authentication errors
        if httpResponse.statusCode == 401 {
            print("❌ QR generation requires authentication")
            throw URLError(.userAuthenticationRequired)
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ Server error: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }

        // Parse response
        let qrResponse = try JSONDecoder().decode(QRCodeResponse.self, from: responseData)

        guard qrResponse.success, let qrCodeDataURL = qrResponse.qrCode else {
            throw NSError(domain: "QRCode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: qrResponse.error ?? "Failed to generate QR code"
            ])
        }

        // Convert data URL to UIImage
        // Format: "data:image/png;base64,..."
        guard let base64String = qrCodeDataURL.components(separatedBy: ",").last,
              let imageData = Data(base64Encoded: base64String),
              let image = UIImage(data: imageData) else {
            throw NSError(domain: "QRCode", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode QR code image"
            ])
        }

        print("✅ QR code generated successfully for data: \(data.prefix(50))\(data.count > 50 ? "..." : "")")
        return image
    }
}
