//
//  VideoDraftStore.swift
//  MakeReady
//
//  Crash-safe recorder drafts (video-recorder D26): one folder per draft holding its segment files
//  and a `draft.json` manifest, kept until Save or Retake. Only `finalize` lists a segment, so a file
//  a crash cut off is never in the manifest and `recoverable` deletes it.
//

import Foundation

/// The recorder choices that belong to a draft and come back with it after a crash.
struct VideoDraftSettings: Codable, Equatable {
    var lengthSeconds: Int = RecordingTimeline.defaultLength
    /// The filter's identifier; nil is Normal.
    var filter: String?
    /// 0–100 (D6).
    var filterStrength: Double = 100
    /// Where it was recorded; nil is the + menu.
    var entry: VideoRecorderEntry?
}

struct VideoDraftSegment: Equatable {
    let url: URL
    let duration: TimeInterval
}

/// Why a draft operation had nothing to work on.
enum VideoDraftError: Error, Equatable {
    case noDraft
}

struct VideoDraft: Identifiable, Equatable {
    let id: UUID
    let folder: URL
    let createdAt: Date
    var settings: VideoDraftSettings
    var segments: [VideoDraftSegment]
    /// The edit (D16); empty when none.
    var layers: [VideoLayer] = []
    var transcript: VideoTranscript?
    /// `.recording` when the manifest says nothing (D19).
    var source: VideoSource = .recording
    /// The seconds of an imported clip kept; nil keeps all of it (D19).
    var window: ClosedRange<Double>?
}

struct VideoDraftStore {
    /// On disk a segment is its file name only, resolved against the draft's folder when read, so a
    /// moved app container does not orphan it.
    private struct Manifest: Codable {
        struct Segment: Codable {
            let fileName: String
            let duration: TimeInterval
        }

        let createdAt: Date
        var settings: VideoDraftSettings
        var segments: [Segment]
        var layers: [VideoLayer] = []
        var transcript: VideoTranscript?
        var source: VideoSource?
        /// `[from, to]` in seconds.
        var window: [Double]?

        init(createdAt: Date, settings: VideoDraftSettings, segments: [Segment]) {
            self.createdAt = createdAt
            self.settings = settings
            self.segments = segments
        }

        private enum CodingKeys: String, CodingKey {
            case createdAt, settings, segments, layers, transcript, source, window
        }

        /// The recording's keys are strict; each of the edit's reads as absent when it fails (D28), so a
        /// damaged edit never costs the recording.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            createdAt = try c.decode(Date.self, forKey: .createdAt)
            settings = try c.decode(VideoDraftSettings.self, forKey: .settings)
            segments = try c.decode([Segment].self, forKey: .segments)
            layers = VideoLayer.decodeLenient(from: c, forKey: .layers) ?? []
            transcript = try? c.decodeIfPresent(VideoTranscript.self, forKey: .transcript)
            source = try? c.decodeIfPresent(VideoSource.self, forKey: .source)
            let window = try? c.decodeIfPresent([Double].self, forKey: .window)
            self.window = window.flatMap { Self.isWindow($0) ? $0 : nil }
        }

        private static func isWindow(_ values: [Double]) -> Bool {
            values.count == 2 && values.allSatisfy(\.isFinite) && values[0] < values[1]
        }
    }

    private static let manifestName = "draft.json"
    /// Present while a saved draft waits for the upload queue to have its video.
    private static let saveName = "save.json"

    /// Holds one folder per draft. Use a root per owner and environment, as memos do.
    let root: URL

    init(root: URL) {
        self.root = root
    }

    /// Beside the user's upload queue, which reads only the files directly in its own folder.
    static func folder(environment: String, userId: String, root: URL? = nil) throws -> URL {
        var folder = try VideoUploadController.folder(environment: environment, userId: userId, root: root)
            .appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return folder
    }

    /// An empty draft with its folder and manifest on disk. If they cannot be written, the first
    /// `finalize` throws.
    func begin() -> VideoDraft {
        let id = UUID()
        let manifest = Manifest(createdAt: Date(), settings: VideoDraftSettings(), segments: [])
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try write(manifest, to: folder)
        } catch {
            Log.media.error("video draft not creatable: \(error.localizedDescription, privacy: .public)")
        }
        return draft(id: id, folder: folder, manifest: manifest)
    }

    /// Moves a finished segment file into the draft (it may already be there) and lists it in the
    /// manifest, last. Returns the draft as it now is on disk.
    @discardableResult
    func finalize(segment url: URL, duration: TimeInterval, in draft: VideoDraft) throws -> VideoDraft {
        var manifest = try readManifest(in: draft.folder)
        var fileName = url.lastPathComponent
        if url.deletingLastPathComponent().standardizedFileURL.path != draft.folder.standardizedFileURL.path {
            if FileManager.default.fileExists(atPath: draft.folder.appendingPathComponent(fileName).path) {
                fileName = "\(UUID().uuidString).\(url.pathExtension)"
            }
            try FileManager.default.moveItem(at: url, to: draft.folder.appendingPathComponent(fileName))
        }
        manifest.segments.append(Manifest.Segment(fileName: fileName, duration: duration))
        try write(manifest, to: draft.folder)
        return self.draft(id: draft.id, folder: draft.folder, manifest: manifest)
    }

    /// Drops the last finished segment from the manifest, then its file (D5). Returns the draft as it
    /// now is on disk.
    @discardableResult
    func dropLastSegment(in draft: VideoDraft) throws -> VideoDraft {
        var manifest = try readManifest(in: draft.folder)
        guard let dropped = manifest.segments.popLast() else { return self.draft(id: draft.id, folder: draft.folder, manifest: manifest) }
        try write(manifest, to: draft.folder)
        delete(draft.folder.appendingPathComponent(dropped.fileName))
        return self.draft(id: draft.id, folder: draft.folder, manifest: manifest)
    }

    @discardableResult
    func save(settings: VideoDraftSettings, in draft: VideoDraft) throws -> VideoDraft {
        var manifest = try readManifest(in: draft.folder)
        manifest.settings = settings
        try write(manifest, to: draft.folder)
        return self.draft(id: draft.id, folder: draft.folder, manifest: manifest)
    }

    /// Keeps the edit with the draft (D16), replacing the last one.
    @discardableResult
    func save(layers: [VideoLayer], transcript: VideoTranscript?, in draft: VideoDraft) throws -> VideoDraft {
        var manifest = try readManifest(in: draft.folder)
        manifest.layers = layers
        manifest.transcript = transcript
        try write(manifest, to: draft.folder)
        return self.draft(id: draft.id, folder: draft.folder, manifest: manifest)
    }

    /// Makes an imported clip a draft (D19): the settings, source and window are written first, then
    /// `file` moves in as the one segment. On failure the file is back in its place, the draft is gone
    /// and the error is thrown.
    @discardableResult
    func adopt(imported file: URL, duration: TimeInterval, window: ClosedRange<Double>?,
               settings: VideoDraftSettings) throws -> VideoDraft {
        let id = UUID()
        let folder = root.appendingPathComponent(id.uuidString, isDirectory: true)
        var manifest = Manifest(createdAt: Date(), settings: settings, segments: [])
        manifest.source = .imported
        manifest.window = window.map { [$0.lowerBound, $0.upperBound] }
        let moved = folder.appendingPathComponent(file.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try write(manifest, to: folder)
            try FileManager.default.moveItem(at: file, to: moved)
            manifest.segments = [Manifest.Segment(fileName: file.lastPathComponent, duration: duration)]
            try write(manifest, to: folder)
        } catch {
            if FileManager.default.fileExists(atPath: moved.path), !FileManager.default.fileExists(atPath: file.path) {
                do {
                    try FileManager.default.moveItem(at: moved, to: file)
                } catch {
                    Log.media.error("imported clip not returned: \(error.localizedDescription, privacy: .public)")
                }
            }
            delete(folder)
            throw error
        }
        return draft(id: id, folder: folder, manifest: manifest)
    }

    /// The draft as it is on disk; nil when it is gone or unreadable.
    func current(_ draft: VideoDraft) -> VideoDraft? {
        guard let manifest = try? readManifest(in: draft.folder) else { return nil }
        return self.draft(id: draft.id, folder: draft.folder, manifest: manifest)
    }

    /// The draft is saved: from here it belongs to `VideoSaver`, not to a recorder.
    func markSaving(_ save: VideoSave, in draft: VideoDraft) throws {
        try JSONEncoder().encode(save).write(to: draft.folder.appendingPathComponent(Self.saveName), options: .atomic)
    }

    /// The draft is not being saved any more (Back from naming): it is an ordinary draft again. Throws, with the
    /// mark kept, when it cannot be removed.
    func clearSaving(_ draft: VideoDraft) throws {
        let url = draft.folder.appendingPathComponent(Self.saveName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    /// Drafts saved whose video the upload queue does not have yet, oldest first.
    func saving() -> [(draft: VideoDraft, save: VideoSave)] {
        folders().compactMap { folder in
            guard let id = UUID(uuidString: folder.lastPathComponent), let save = readSave(in: folder) else { return nil }
            do {
                let manifest = try readManifest(in: folder)
                guard !manifest.segments.isEmpty else {
                    delete(folder)
                    return nil
                }
                return (draft(id: id, folder: folder, manifest: manifest), save)
            } catch {
                Log.media.error("saved video draft unreadable: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }.sorted { $0.draft.createdAt < $1.draft.createdAt }
    }

    /// Drafts with at least one finished segment, oldest first, without those being saved. Deletes
    /// every file no manifest lists and every draft with nothing finished, so call it only while
    /// nothing is recording.
    func recoverable() -> [VideoDraft] {
        folders().compactMap(salvage).sorted { $0.createdAt < $1.createdAt }
    }

    /// `recoverable`, only those recorded from `entry`: a lesson's recording never turns up elsewhere (D18).
    func recoverable(for entry: VideoRecorderEntry) -> [VideoDraft] {
        recoverable().filter { ($0.settings.entry ?? .plusMenu) == entry }
    }

    func discard(_ draft: VideoDraft) {
        delete(draft.folder)
    }

    func exists(_ draft: VideoDraft) -> Bool {
        FileManager.default.fileExists(atPath: draft.folder.path)
    }

    // MARK: Helpers

    private func folders() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
        } catch {
            // Silent: no folder yet means no drafts.
            return []
        }
    }

    /// Nil when the draft is not being saved.
    private func readSave(in folder: URL) -> VideoSave? {
        let url = folder.appendingPathComponent(Self.saveName)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(VideoSave.self, from: Data(contentsOf: url))
        } catch {
            // Recovered: an unreadable save leaves an ordinary draft, which the recorder brings back.
            Log.media.error("video save unreadable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func salvage(_ folder: URL) -> VideoDraft? {
        guard let id = UUID(uuidString: folder.lastPathComponent), readSave(in: folder) == nil else { return nil }
        var manifest: Manifest
        do {
            manifest = try readManifest(in: folder)
        } catch {
            Log.media.error("video draft manifest unreadable, draft deleted: \(error.localizedDescription, privacy: .public)")
            delete(folder)
            return nil
        }
        manifest.segments.removeAll { !hasData(folder.appendingPathComponent($0.fileName)) }
        guard !manifest.segments.isEmpty else {
            delete(folder)
            return nil
        }
        let kept = Set(manifest.segments.map(\.fileName) + [Self.manifestName])
        do {
            for name in try FileManager.default.contentsOfDirectory(atPath: folder.path) where !kept.contains(name) {
                delete(folder.appendingPathComponent(name))
            }
        } catch {
            // Recovered: a leftover unfinished file is never listed, so it is never used.
            Log.media.error("video draft folder unreadable: \(error.localizedDescription, privacy: .public)")
        }
        return draft(id: id, folder: folder, manifest: manifest)
    }

    private func draft(id: UUID, folder: URL, manifest: Manifest) -> VideoDraft {
        VideoDraft(id: id, folder: folder, createdAt: manifest.createdAt, settings: manifest.settings,
                   segments: manifest.segments.map {
                       VideoDraftSegment(url: folder.appendingPathComponent($0.fileName), duration: $0.duration)
                   },
                   layers: manifest.layers, transcript: manifest.transcript, source: manifest.source ?? .recording,
                   window: manifest.window.map { $0[0]...$0[1] })
    }

    private func readManifest(in folder: URL) throws -> Manifest {
        let data = try Data(contentsOf: folder.appendingPathComponent(Self.manifestName))
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    private func write(_ manifest: Manifest, to folder: URL) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: folder.appendingPathComponent(Self.manifestName), options: .atomic)
    }

    private func hasData(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return size > 0
    }

    private func delete(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.media.error("video draft file not removable: \(error.localizedDescription, privacy: .public)")
        }
    }
}
