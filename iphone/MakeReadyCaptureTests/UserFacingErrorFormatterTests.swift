//
//  UserFacingErrorFormatterTests.swift
//  MakeReadyCaptureTests
//
//  User-facing error copy should stay actionable and avoid leaking transport,
//  decoder, or backend diagnostic details into alerts and banners.
//

import XCTest
@testable import MakeReady

final class UserFacingErrorFormatterTests: XCTestCase {

    func testAPIErrorNetworkMessageHidesRawNetworkPrefix() {
        let message = UserFacingErrorFormatter.message(
            for: APIError.networkError(URLError(.notConnectedToInternet))
        )

        XCTAssertEqual(message, "You're offline. Check your connection and try again.")
        XCTAssertFalse(message.contains("Network error"))
    }

    func testAPIErrorDecodingMessageHidesDecoderDetails() {
        struct Fixture: Decodable {
            let id: Int
        }

        let decodingError: Error
        do {
            _ = try JSONDecoder().decode(Fixture.self, from: Data("{}".utf8))
            XCTFail("Fixture should fail to decode")
            return
        } catch {
            decodingError = error
        }

        let message = UserFacingErrorFormatter.message(
            for: APIError.decodingError(decodingError)
        )

        XCTAssertEqual(message, "MakeReady got a response it couldn't read. Please update the app or try again later.")
        XCTAssertFalse(message.localizedCaseInsensitiveContains("keyNotFound"))
    }

    func testVideoUploadStatusMessageFallsBackToActionableCopy() {
        let message = UserFacingErrorFormatter.message(
            for: VideoError.uploadFailed("Upload failed with status 500"),
            operation: .uploadVideo
        )

        XCTAssertEqual(message, "Couldn't upload the video. Check your connection and try again.")
        XCTAssertFalse(message.contains("status 500"))
    }

    func testEnrollmentInvalidResponseUsesEnrollmentSpecificCopy() {
        let message = UserFacingErrorFormatter.message(for: EnrollmentError.invalidResponse)

        XCTAssertEqual(message, "MakeReady got an unexpected enrollment response. Try again.")
    }

    func testReadImportFileOperationMessageExplainsFix() {
        let message = UserFacingErrorFormatter.message(for: .readImportFile)

        XCTAssertEqual(message, "MakeReady couldn't read that file. Choose a MakeReady export and try again.")
    }
}
