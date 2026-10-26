//
//  StubAPIClient.swift
//  MakeReadyCaptureTests
//
//  APIClientProtocol stub for Action tests (Phase 2.7). Canned JSON
//  responses keyed by "METHOD endpoint"; records every call for
//  assertions. Decodes with JSONDecoder.apiDecoder, same as APIClient.
//

import Foundation
import UIKit
@testable import MakeReady

final class StubAPIClient: APIClientProtocol {

    struct RecordedCall {
        let method: String
        let endpoint: String
        let body: [String: Any]?
    }

    /// Canned responses keyed by "METHOD endpoint" (e.g. "GET /api/groups").
    var responses: [String: Data] = [:]

    /// When set, every call throws this instead of returning a response.
    var errorToThrow: Error?

    /// Per-call failure hook: return an error to throw for that call (checked after `errorToThrow`).
    var errorFor: ((_ endpoint: String, _ body: [String: Any]?) -> Error?)?

    /// Runs on the main actor before each call returns (e.g. to land a sign-out mid-Action).
    var beforeReturn: (@MainActor (_ endpoint: String, _ body: [String: Any]?) -> Void)?

    /// Seconds each call waits before returning (to prove calls overlap or that a slow one is not waited on).
    var delayFor: ((_ endpoint: String) -> TimeInterval)?

    /// Every call made through the stub, in order.
    /// Recorded under a lock: `DashboardActions.refresh()` calls the stub from several tasks at
    /// once, and an unguarded append raced and crashed the test host.
    private let callsLock = NSLock()
    private var recordedCalls: [RecordedCall] = []
    var calls: [RecordedCall] { callsLock.withLock { recordedCalls } }

    func stub(_ method: String, _ endpoint: String, json: String) {
        responses["\(method) \(endpoint)"] = Data(json.utf8)
    }

    func callCount(_ method: String, _ endpoint: String) -> Int {
        calls.filter { $0.method == method && $0.endpoint == endpoint }.count
    }

    // MARK: - APIClientProtocol

    func request(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data {
        callsLock.withLock { recordedCalls.append(RecordedCall(method: method, endpoint: endpoint, body: body)) }
        if let beforeReturn {
            await beforeReturn(endpoint, body)
        }
        if let delay = delayFor?(endpoint), delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if let errorToThrow {
            throw errorToThrow
        }
        if let error = errorFor?(endpoint, body) {
            throw error
        }
        guard let data = responses["\(method) \(endpoint)"] else {
            throw APIError.serverError("StubAPIClient: no canned response for \(method) \(endpoint)")
        }
        return data
    }

    func request<T: Decodable>(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval, responseType: T.Type) async throws -> T {
        let data = try await request(endpoint: endpoint, method: method, body: body, timeout: timeout)
        return try JSONDecoder.apiDecoder.decode(T.self, from: data)
    }

    func get<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "GET", body: nil, timeout: 30, responseType: responseType)
    }

    func post<T: Decodable>(_ endpoint: String, body: [String: Any]?, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "POST", body: body, timeout: 30, responseType: responseType)
    }

    func patch<T: Decodable>(_ endpoint: String, body: [String: Any], responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "PATCH", body: body, timeout: 30, responseType: responseType)
    }

    func delete<T: Decodable>(_ endpoint: String, responseType: T.Type) async throws -> T {
        try await request(endpoint: endpoint, method: "DELETE", body: nil, timeout: 30, responseType: responseType)
    }

    func upload(endpoint: String, boundary: String, body: Data, timeout: TimeInterval) async throws -> Data {
        try await request(endpoint: endpoint, method: "UPLOAD", body: nil, timeout: timeout)
    }

    func uploadImage(endpoint: String, image: UIImage, maxDimension: CGFloat, quality: CGFloat) async throws -> Data {
        try await request(endpoint: endpoint, method: "UPLOAD-IMAGE", body: nil, timeout: 60)
    }
}
