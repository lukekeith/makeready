//
//  UserFacingErrorFormatter.swift
//  MakeReady
//
//  Converts technical/domain errors into short, actionable copy for alerts,
//  banners, and inline error states. Raw error details should still be logged
//  through AppState.recordError(context:) for diagnostics.
//

import Foundation

protocol UserFacingErrorMessageProviding {
    var userFacingMessage: String { get }
}

enum UserFacingErrorOperation {
    case generic
    case openSelectedFile
    case readImportFile
    case importProgram
    case loadVideos
    case uploadVideo
    case deleteVideo
    case saveRecordedVideo
}

enum UserFacingErrorFormatter {
    static func message(for error: Error, operation: UserFacingErrorOperation = .generic) -> String {
        if let provider = error as? UserFacingErrorMessageProviding {
            return provider.userFacingMessage
        }

        if let urlError = error as? URLError {
            return message(for: urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return message(for: URLError(URLError.Code(rawValue: nsError.code)))
        }

        if let safeMessage = sanitizedMessage(error.localizedDescription) {
            return safeMessage
        }

        return message(for: operation)
    }

    static func message(for operation: UserFacingErrorOperation) -> String {
        switch operation {
        case .generic:
            return "Something went wrong. Please try again."
        case .openSelectedFile:
            return "MakeReady couldn't open that file. Choose it again and try once more."
        case .readImportFile:
            return "MakeReady couldn't read that file. Choose a MakeReady export and try again."
        case .importProgram:
            return "Couldn't import the program. Check the file and try again."
        case .loadVideos:
            return "Couldn't load your videos. Check your connection and try again."
        case .uploadVideo:
            return "Couldn't upload the video. Check your connection and try again."
        case .deleteVideo:
            return "Couldn't delete the video. Try again."
        case .saveRecordedVideo:
            return "Couldn't save the recorded video."
        }
    }

    static func sanitizedMessage(_ message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 180 else { return nil }

        let lowercased = trimmed.lowercased()
        let diagnosticMarkers = [
            "/api/",
            "status ",
            "status:",
            "prisma",
            "sql",
            "stack",
            "trace",
            "decode",
            "decoding",
            "invalid response",
            "nsurlerrordomain"
        ]

        guard !diagnosticMarkers.contains(where: { lowercased.contains($0) }) else {
            return nil
        }

        return trimmed
    }

    private static func message(for urlError: URLError) -> String {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "You're offline. Check your connection and try again."
        case .timedOut:
            return "The request timed out. Try again."
        default:
            return "Couldn't reach MakeReady. Check your connection and try again."
        }
    }
}

extension APIError: UserFacingErrorMessageProviding {
    var userFacingMessage: String {
        switch self {
        case .notAuthenticated:
            return "Sign in to continue."
        case .networkError(let error):
            return UserFacingErrorFormatter.message(for: error)
        case .serverError(let message):
            return UserFacingErrorFormatter.sanitizedMessage(message)
                ?? "MakeReady couldn't complete that request. Try again."
        case .decodingError:
            return "MakeReady got a response it couldn't read. Please update the app or try again later."
        case .invalidResponse:
            return "MakeReady got an unexpected response. Try again."
        case .badURL:
            return "MakeReady couldn't prepare that request."
        }
    }
}

extension VideoError: UserFacingErrorMessageProviding {
    var userFacingMessage: String {
        switch self {
        case .notAuthenticated:
            return "Sign in to manage videos."
        case .networkError(let error):
            return UserFacingErrorFormatter.message(for: error)
        case .serverError(let message):
            return UserFacingErrorFormatter.sanitizedMessage(message)
                ?? "MakeReady couldn't update that video. Try again."
        case .decodingError:
            return "MakeReady got video data it couldn't read. Try again later."
        case .invalidResponse:
            return "MakeReady got an unexpected video response. Try again."
        case .uploadFailed(let message):
            return UserFacingErrorFormatter.sanitizedMessage(message)
                ?? UserFacingErrorFormatter.message(for: .uploadVideo)
        case .videoNotReady:
            return "This video is still processing. Try again in a moment."
        }
    }
}

extension EnrollmentError: UserFacingErrorMessageProviding {
    var userFacingMessage: String {
        switch self {
        case .notAuthenticated:
            return "Sign in to manage enrollments."
        case .networkError(let error):
            return UserFacingErrorFormatter.message(for: error)
        case .serverError(let message):
            return UserFacingErrorFormatter.sanitizedMessage(message)
                ?? "MakeReady couldn't update the enrollment. Try again."
        case .decodingError:
            return "MakeReady got enrollment data it couldn't read. Try again later."
        case .invalidResponse:
            return "MakeReady got an unexpected enrollment response. Try again."
        }
    }
}
