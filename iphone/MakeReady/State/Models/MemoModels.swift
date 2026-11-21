//
//  MemoModels.swift
//  MakeReady
//
//  Voice-memo wire types (the frozen /api/memos contract) and the recording engine's value types.
//

import Foundation

// MARK: - Wire enums

/// Transcript lifecycle. Any string the server adds later decodes as `.unknown`, never throws:
/// the iPhone is a released artifact and the wire enum may only widen deliberately (D32).
enum MemoTranscriptStatus: String, Codable, Equatable {
    case none, pending, ready, failed, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MemoTranscriptStatus(rawValue: raw) ?? .unknown
    }
}

enum MemoUploadStatus: String, Codable, Equatable {
    case pending, ready, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MemoUploadStatus(rawValue: raw) ?? .unknown
    }
}

// MARK: - Wire types

struct TranscriptSegment: Codable, Equatable {
    let text: String
    let startMs: Int
    let endMs: Int
}

/// `GET /api/memos/:id` and the memo inside create/complete/rename responses.
/// `url` is non-null only on the detail GET (D31).
struct VoiceMemo: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    let url: String?
    let urlExpiresAt: Date?
    let mimeType: String
    let fileSize: Int?
    let durationMs: Int?
    let waveformPeaks: [Double]?
    let transcript: String?
    let transcriptSegments: [TranscriptSegment]?
    let transcriptStatus: MemoTranscriptStatus
    let transcriptSource: String?
    let uploadStatus: MemoUploadStatus
    let recordedAt: Date
    let createdAt: Date
    let updatedAt: Date
}

/// One row of `GET /api/memos`: no url, transcript, segments or peaks; a 280-char preview instead.
struct VoiceMemoSummary: Codable, Identifiable, Equatable {
    static let previewLength = 280

    let id: String
    var title: String
    let mimeType: String
    let fileSize: Int?
    let durationMs: Int?
    let transcriptPreview: String?
    let transcriptStatus: MemoTranscriptStatus
    let transcriptSource: String?
    let uploadStatus: MemoUploadStatus
    let recordedAt: Date
    let createdAt: Date
    let updatedAt: Date

    init(_ memo: VoiceMemo) {
        id = memo.id
        title = memo.title
        mimeType = memo.mimeType
        fileSize = memo.fileSize
        durationMs = memo.durationMs
        transcriptPreview = memo.transcript.map { String($0.prefix(Self.previewLength)) }
        transcriptStatus = memo.transcriptStatus
        transcriptSource = memo.transcriptSource
        uploadStatus = memo.uploadStatus
        recordedAt = memo.recordedAt
        createdAt = memo.createdAt
        updatedAt = memo.updatedAt
    }
}

struct MemoUploadTicket: Codable, Equatable {
    let url: String
    let method: String
    let headers: [String: String]
    let expiresAt: Date
}

struct MemoCreateResponse: Codable {
    let memo: VoiceMemo
    let upload: MemoUploadTicket
}

struct MemoResponse: Codable {
    let memo: VoiceMemo
}

struct MemoUploadResponse: Codable {
    let upload: MemoUploadTicket
}

struct MemoListResponse: Codable {
    let memos: [VoiceMemoSummary]
    let total: Int
}

// MARK: - Engine value types

struct Transcript: Codable, Equatable {
    let text: String
    let segments: [TranscriptSegment]
}

/// What the recorder engine hands back at `stop()`; also the persisted queue manifest payload (D22).
struct RecordingResult: Codable, Equatable {
    let fileURL: URL
    let title: String
    let durationMs: Int
    let waveformPeaks: [Double]
    let recordedAt: Date
    let transcript: Transcript?
}

enum RecorderState: Equatable {
    case idle, recording, paused, finishing
}

/// D21: each routes through /ios-error-surface as console-only until a surface exists.
enum MemoEngineError: Error, Equatable {
    case micPermissionDenied
    case speechUnavailable
    case durationLimitReached
    case writeFailed
}
