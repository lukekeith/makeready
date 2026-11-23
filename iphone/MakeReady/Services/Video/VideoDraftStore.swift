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
}

struct VideoDraftSegment: Equatable {
    let url: URL
    let duration: TimeInterval
}

struct VideoDraft: Identifiable, Equatable {
    let id: UUID
    let folder: URL
    let createdAt: Date
    var settings: VideoDraftSettings
    var segments: [VideoDraftSegment]
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

    /// The draft is saved: from here it belongs to `VideoSaver`, not to a recorder.
    func markSaving(_ save: VideoSave, in draft: VideoDraft) throws {
        try JSONEncoder().encode(save).write(to: draft.folder.appendingPathComponent(Self.saveName), options: .atomic)
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
                   })
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
