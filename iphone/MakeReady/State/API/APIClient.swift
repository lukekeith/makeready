//
//  APIClient.swift
//  MakeReady
//
//  Centralized HTTP client for all API requests.
//  Handles authentication, request building, and error parsing.
//

import Foundation
import ImageIO
import UIKit

// MARK: - API Errors

/// Unified error type for all API operations
enum APIError: LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case serverError(String)
    case decodingError(Error)
    case invalidResponse
    case badURL

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to perform this action."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return "Failed to parse server response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .badURL:
            return "Invalid URL."
        }
    }
}

// MARK: - API Client

/// Centralized HTTP client for making authenticated API requests.
final class APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Configuration

    private let session: URLSession

    /// Base URL is dynamic — resolved from the environment selected on the
    /// Profile screen (and the local IP/port when running against Local dev).
    private var baseURL: String { Configuration.baseURL }

    private init() {
        self.session = URLSession.shared
    }

    // MARK: - Authentication

    /// Get the session cookie from UserDefaults
    private func getSessionCookie() -> String? {
        UserDefaults.standard.string(forKey: "makeready_session_cookie")
    }

    /// Raw `connect.sid` cookie value — used by WKWebView consumers that need
    /// to plant the session into their own cookie store before loading an
    /// authenticated URL on the web client.
    var sessionCookieValue: String? { getSessionCookie() }

    /// Check if user is authenticated
    var isAuthenticated: Bool {
        getSessionCookie() != nil
    }

    // MARK: - Request Building

    /// Build an authenticated URLRequest
    private func buildRequest(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30
    ) throws -> URLRequest {
        guard getSessionCookie() != nil else {
            throw APIError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        if let cookie = getSessionCookie() {
            request.setValue("connect.sid=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    // MARK: - Request Execution

    /// Execute a request and return raw data
    func request(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> Data {
        let request = try buildRequest(endpoint: endpoint, method: method, body: body, timeout: timeout)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to extract error message from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorMessage = json["error"] as? String {
                        throw APIError.serverError(errorMessage)
                    }
                    // Zod errors sometimes come back as an array of objects
                    if let errorArray = json["error"] as? [[String: Any]],
                       let first = errorArray.first {
                        let path = (first["path"] as? [Any])?.map { String(describing: $0) }.joined(separator: ".")
                        let message = first["message"] as? String
                        if let message = message {
                            if let path = path, !path.isEmpty {
                                throw APIError.serverError("\(path): \(message)")
                            }
                            throw APIError.serverError(message)
                        }
                    }
                }
                throw APIError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Execute a request and decode the response
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        timeout: TimeInterval = 30,
        responseType: T.Type
    ) async throws -> T {
        let data = try await request(endpoint: endpoint, method: method, body: body, timeout: timeout)

        do {
            return try JSONDecoder.apiDecoder.decode(T.self, from: data)
        } catch {
            NSLog("❌ APIClient: Decoding error for \(endpoint): \(error)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Convenience Methods

    /// GET request with decoded response
    func get<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "GET", responseType: responseType)
    }

    /// POST request with decoded response
    func post<T: Decodable>(_ endpoint: String, body: [String: Any]? = nil, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "POST", body: body, responseType: responseType)
    }

    /// PATCH request with decoded response
    func patch<T: Decodable>(_ endpoint: String, body: [String: Any], responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "PATCH", body: body, responseType: responseType)
    }

    /// DELETE request with decoded response
    func delete<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "DELETE", responseType: responseType)
    }

    // MARK: - File Upload (Multipart)

    /// Upload file data as multipart/form-data
    func upload(
        endpoint: String,
        boundary: String,
        body: Data,
        timeout: TimeInterval = 60
    ) async throws -> Data {
        guard getSessionCookie() != nil else {
            throw APIError.notAuthenticated
        }

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        if let cookie = getSessionCookie() {
            request.setValue("connect.sid=\(cookie)", forHTTPHeaderField: "Cookie")
        }

        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = json["error"] as? String {
                    throw APIError.serverError(errorMessage)
                }
                throw APIError.serverError("Server returned status \(httpResponse.statusCode)")
            }

            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Image Upload

    /// Upload an image with base64 encoding
    /// Uses ImageIO to strip EXIF metadata (GPS, camera info) for privacy and smaller payloads
    func uploadImage(
        endpoint: String,
        image: UIImage,
        maxDimension: CGFloat = 1200,
        quality: CGFloat = 0.6
    ) async throws -> Data {
        let resizedImage = resizeImageIfNeeded(image, maxDimension: maxDimension)

        guard let cgImage = resizedImage.cgImage else {
            throw APIError.serverError("Failed to process image")
        }

        // Use ImageIO to write JPEG without EXIF metadata
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw APIError.serverError("Failed to create image destination")
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw APIError.serverError("Failed to convert image to JPEG")
        }

        let base64String = (data as Data).base64EncodedString()

        let body: [String: Any] = [
            "imageData": base64String,
            "contentType": "image/jpeg"
        ]

        return try await request(endpoint: endpoint, method: "POST", body: body, timeout: 120)
    }

    /// Resize image using ImageIO downsampling for memory efficiency.
    /// Downsamples during decode rather than loading the full bitmap into memory.
    private func resizeImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height

        if width <= maxDimension && height <= maxDimension {
            return image
        }

        // Use ImageIO for memory-efficient downsampling
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return resizeWithRenderer(image, maxDimension: maxDimension)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(
            imageSource, 0, downsampleOptions as CFDictionary
        ) else {
            return resizeWithRenderer(image, maxDimension: maxDimension)
        }

        return UIImage(cgImage: downsampledImage)
    }

    /// Fallback resize using UIGraphicsImageRenderer
    private func resizeWithRenderer(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let scale: CGFloat = if image.size.width > image.size.height {
            maxDimension / image.size.width
        } else {
            maxDimension / image.size.height
        }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Common Response Types

/// Generic success response (used by many endpoints)
struct APISuccessResponse: Codable {
    let success: Bool
    let error: String?
}
