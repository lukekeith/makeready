//
//  CaptureFixture.swift
//  MakeReadyCaptureTests
//
//  JSON fixture model and loader. Discovers fixture files from the capture/ directory.
//

import Foundation

struct CaptureFixture: Codable {
    let platform: String?
    let view: String
    let output: String
    let title: String?
    let devices: [String]
    let auth: CaptureAuth?
    let state: CaptureState?
}

struct CaptureAuth: Codable {
    let isAuthenticated: Bool
    let currentUser: CaptureUser?
}

struct CaptureUser: Codable {
    let id: String
    let name: String
    let email: String
    let picture: String?
}

/// Loosely-typed state container. Each field maps to an AppState entity store.
struct CaptureState: Codable {
    let programs: [[String: AnyCodableValue]]?
    let groups: [[String: AnyCodableValue]]?
    let enrollments: [[String: AnyCodableValue]]?
    let homeStats: CaptureHomeStats?
    // Activity-editor views
    let activity: CaptureActivity?
    let programId: String?
    let lessonId: String?
    let videoUrl: String?
    let videoThumbnailUrl: String?
    // Program-home views: seed lessons directly
    let lessons: [CaptureLesson]?
    // Program metadata (name, days) for pages that show the full program header
    let programName: String?
    let programDays: Int?
    // Path to a local image file (relative to capture root) to seed as the program cover image
    let programCoverImagePath: String?
}

// MARK: - Lesson capture model

struct CaptureLesson: Codable {
    let id: String
    let dayNumber: Int
    let title: String?
    let estimatedMinutes: Int?
    let activities: [CaptureActivity]?
}

// MARK: - Activity capture models

struct CaptureActivity: Codable {
    let id: String
    let type: String
    let title: String?
    let orderNumber: Int?
    let status: String?
    let isHelpEnabled: Bool?
    let helpTitle: String?
    let helpDescription: String?
    let helpIcon: String?
    let readBlocks: [CaptureReadBlock]?
    let sourceReferences: [CaptureSourceRef]?
    // YouTube-specific fields
    let youtubeUrl: String?
    let youtubeVideoId: String?
    let youtubeThumbnailUrl: String?
    let youtubeStartSeconds: Int?
    let youtubeEndSeconds: Int?
}

struct CaptureReadBlock: Codable {
    let id: String
    let orderNumber: Int
    let title: String?
    let content: String?
    let isLocked: Bool
    let sourceReferenceId: String?
    let backgroundColor: String?
    let backgroundImageUrl: String?
    let backgroundOverlayOpacity: Double?
    let fontSize: String?
    let selections: [CaptureSelection]?
}

struct CaptureSourceRef: Codable {
    let id: String
    let passageReference: String?
    let bookNumber: Int?
    let bookName: String?
    let chapterStart: Int?
    let chapterEnd: Int?
    let verseStart: Int?
    let verseEnd: Int?
}

struct CaptureSelection: Codable {
    let start: Int
    let end: Int
    let style: String
}

struct CaptureHomeStats: Codable {
    let totalMembers: Int?
    let totalGroups: Int?
    let totalStudies: Int?
    let totalEnrolledLessons: Int?
    let heatmap: [CaptureHeatmapBucket]?
    let weeklyActivity: [CaptureDayActivity]?
}

struct CaptureHeatmapBucket: Codable {
    let day: Int
    let hour: Int
    let count: Int
}

struct CaptureDayActivity: Codable {
    let date: String
    let count: Int
}

/// Simple wrapper for heterogeneous JSON values.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Discovery

struct CaptureFixtureLoader {

    /// Discovers and loads fixture JSON files from the capture/ directory.
    /// Filters by workflow and screen if environment variables are set.
    static func loadAll() throws -> [(workflow: String, fixture: CaptureFixture)] {
        let captureRoot = captureRootPath()
        let workflowFilter = ProcessInfo.processInfo.environment["CAPTURE_WORKFLOW"]?.nilIfEmpty
        let screenFilter = ProcessInfo.processInfo.environment["CAPTURE_SCREEN"]?.nilIfEmpty

        let fm = FileManager.default
        var results: [(String, CaptureFixture)] = []

        let entries = try fm.contentsOfDirectory(atPath: captureRoot)
        for entry in entries.sorted() {
            // Skip non-directories and underscore-prefixed
            var isDir: ObjCBool = false
            let entryPath = (captureRoot as NSString).appendingPathComponent(entry)
            guard fm.fileExists(atPath: entryPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard !entry.hasPrefix("_"), !entry.hasPrefix(".") else { continue }
            guard entry != "screenshots" else { continue }

            if let filter = workflowFilter, entry != filter { continue }

            let files = try fm.contentsOfDirectory(atPath: entryPath)
            for file in files.sorted() where file.hasSuffix(".json") {
                let screenName = (file as NSString).deletingPathExtension
                if let filter = screenFilter, screenName != filter { continue }

                let filePath = (entryPath as NSString).appendingPathComponent(file)
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                let fixture = try JSONDecoder().decode(CaptureFixture.self, from: data)
                results.append((entry, fixture))
            }
        }

        return results
    }

    /// Resolves the capture/ directory path relative to the project root.
    static func captureRootPath() -> String {
        if let envPath = ProcessInfo.processInfo.environment["CAPTURE_ROOT"]?.nilIfEmpty {
            return envPath
        }
        // Fallback: assume capture repo is a sibling of the iphone repo
        let sourceFile = #file
        let testsDir = (sourceFile as NSString).deletingLastPathComponent
        let projectDir = (testsDir as NSString).deletingLastPathComponent
        let makereadyDir = (projectDir as NSString).deletingLastPathComponent
        return (makereadyDir as NSString).appendingPathComponent("capture/fixtures/iphone")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
