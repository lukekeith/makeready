//
//  MemoAudioExporter.swift
//  MakeReady
//
//  `.caf` → `.m4a` (D38): the AAC recorded into the cut-off-safe `.caf` is re-wrapped, not
//  re-encoded, so the uploaded file is the same audio in an `audio/mp4` container.
//

import AVFoundation

enum MemoAudioExporter {
    enum ExportError: Error {
        case sessionUnavailable
    }

    static func exportM4A(from source: URL, to destination: URL) async throws {
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source),
                                                 presetName: AVAssetExportPresetPassthrough) else {
            throw ExportError.sessionUnavailable
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try await session.export(to: destination, as: .m4a)
    }
}
