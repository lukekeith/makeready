//
//  VideoImportFlow.swift
//  MakeReady
//
//  video-recorder D8: what the Photos picker gave, as a file the recorder owns and its duration.
//

import AVFoundation
import PhotosUI
import SwiftUI

enum VideoImportFlow {
    struct Clip: Equatable {
        let url: URL
        let duration: TimeInterval
    }

    static func clip(from pick: PhotosPickerItem) async throws -> Clip {
        guard let movie = try await pick.loadTransferable(type: PickedMovie.self) else {
            throw VideoExportError.nothingToExport
        }
        return try await clip(at: movie.url)
    }

    /// Deletes the file when it holds no video.
    static func clip(at url: URL) async throws -> Clip {
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0, try await !asset.loadTracks(withMediaType: .video).isEmpty else {
                throw VideoExportError.nothingToExport
            }
            return Clip(url: url, duration: duration)
        } catch {
            delete(url)
            throw error
        }
    }

    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url) // Silent: a copy in tmp, which the system empties
    }
}
