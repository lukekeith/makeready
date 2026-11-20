//
//  MemoDraftStore.swift
//  MakeReady
//
//  Draft manifests (D16): while a recording runs, `<name>.json` sits beside its `<name>.caf`. A
//  manifest still there at launch means the recording was cut off; `salvage` turns its `.caf`
//  into an `.m4a` with peaks (D38, D42). Only this owner's and this environment's drafts are
//  visible (D37).
//

import AVFoundation
import Foundation

struct MemoDraftManifest: Codable, Equatable {
    let cafURL: URL
    let startedAt: Date
    let title: String
    let ownerUserId: String
    let environment: String
}

struct MemoDraftStore {
    private static let peakFrames = 4_410

    let directory: URL
    let ownerUserId: String
    let environment: String

    init(directory: URL, ownerUserId: String, environment: String) {
        self.directory = directory
        self.ownerUserId = ownerUserId
        self.environment = environment
    }

    /// The manifest for a recording this store's owner is starting now.
    func manifest(cafURL: URL, startedAt: Date, title: String) -> MemoDraftManifest {
        MemoDraftManifest(cafURL: cafURL, startedAt: startedAt, title: title,
                          ownerUserId: ownerUserId, environment: environment)
    }

    func write(_ manifest: MemoDraftManifest) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: Self.manifestURL(for: manifest.cafURL), options: .atomic)
    }

    func remove(cafURL: URL) {
        let url = Self.manifestURL(for: cafURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Log.memo.error("draft manifest not removable: \(error.localizedDescription)")
        }
    }

    /// Manifests of this owner and environment whose `.caf` exists and holds data.
    func recoverable() -> [MemoDraftManifest] {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        } catch {
            // Silent: no folder yet means no drafts.
            return []
        }
        return names.filter { $0.hasSuffix(".json") }.sorted().compactMap { name in
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)),
                  let manifest = try? JSONDecoder().decode(MemoDraftManifest.self, from: data),
                  manifest.ownerUserId == ownerUserId, manifest.environment == environment,
                  Self.hasAudio(manifest.cafURL) else { return nil }
            return manifest
        }
    }

    /// Exports the abandoned `.caf` to `.m4a`, reading its duration and peaks (one max-abs per
    /// 4 410 frames). The `.caf` and manifest go only after the export succeeds.
    func salvage(_ manifest: MemoDraftManifest) async throws -> (m4a: URL, durationMs: Int, peaks: [Double]) {
        let (frames, sampleRate, peaks) = try Self.measure(manifest.cafURL)
        let m4a = manifest.cafURL.deletingPathExtension().appendingPathExtension("m4a")
        try await MemoAudioExporter.exportM4A(from: manifest.cafURL, to: m4a)
        do {
            try FileManager.default.removeItem(at: manifest.cafURL)
        } catch {
            Log.memo.error("salvaged caf not removable: \(error.localizedDescription)")
        }
        remove(cafURL: manifest.cafURL)
        let durationMs = Int((Double(frames) / sampleRate * 1000).rounded())
        return (m4a, durationMs, peaks)
    }

    // MARK: Helpers

    private static func manifestURL(for cafURL: URL) -> URL {
        cafURL.deletingPathExtension().appendingPathExtension("json")
    }

    private static func hasAudio(_ url: URL) -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        return size > 0
    }

    /// Reads the file once: its frame count, sample rate and peaks.
    private static func measure(_ url: URL) throws -> (frames: Int, sampleRate: Double, peaks: [Double]) {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_384) else {
            throw MemoEngineError.writeFailed
        }
        var peaks: [Double] = []
        var bucketMax: Float = 0
        var bucketFill = 0
        var frames = 0
        while true {
            do {
                try file.read(into: buffer)
            } catch {
                // A cut-off file can end mid-packet: what read so far is the memo.
                Log.memo.error("caf read ended early: \(error.localizedDescription)")
                break
            }
            guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }
            for index in 0..<Int(buffer.frameLength) {
                bucketMax = max(bucketMax, min(abs(channel[index]), 1))
                bucketFill += 1
                if bucketFill == peakFrames {
                    peaks.append(Double(bucketMax))
                    bucketMax = 0
                    bucketFill = 0
                }
            }
            frames += Int(buffer.frameLength)
        }
        if bucketFill > 0 { peaks.append(Double(bucketMax)) }
        return (frames, format.sampleRate, peaks)
    }
}
