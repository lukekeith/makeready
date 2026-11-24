//
//  VideoExporter.swift
//  MakeReady
//
//  Turns a recording's segments, or a trimmed import, into the one `.mp4` that is uploaded
//  (video-recorder D6, D8, D13). Orientation follows each segment's `preferredTransform`
//  (iphone/.claude/VIDEO_RECORDING.md).
//

import AVFoundation
import CoreImage
import os
import UIKit

struct ExportedVideo {
    let url: URL
    let durationSeconds: Double
    /// The first frame; nil when it could not be read.
    let posterImage: UIImage?
}

enum VideoExportError: Error, Equatable {
    /// No segment, no picture in one, or a time range outside them.
    case nothingToExport
    case sessionUnavailable
}

/// The layers a player item draws and the kept window's start, read by the video composition on its
/// own queue (video-editor D23).
final class VideoLayersBox: Sendable {
    private struct Held {
        var drawn: [DrawnLayer] = []
        var startSeconds: Double = 0
    }

    private let stored = OSAllocatedUnfairLock(initialState: Held())

    /// Rasterised on the main actor at `VideoExporter.frameSize(of:)`.
    var drawn: [DrawnLayer] {
        get { stored.withLock { $0.drawn } }
        set { stored.withLock { $0.drawn = newValue } }
    }

    /// Where layer time 0 falls on the joined clips' timeline.
    var startSeconds: Double {
        get { stored.withLock { $0.startSeconds } }
        set { stored.withLock { $0.startSeconds = newValue } }
    }

    fileprivate var held: (drawn: [DrawnLayer], startSeconds: Double) {
        stored.withLock { ($0.drawn, $0.startSeconds) }
    }
}

enum VideoExporter {
    /// Joins `segments` in order, keeps `timeRange` of the result (nil = all of it) and writes it to
    /// `destination`, replacing a file already there. `strength` is the filter's, 0 to 1. `layers`
    /// are drawn above the filter, their times counted from the start of the kept window (D2, D20).
    static func export(segments: [URL], timeRange: CMTimeRange?, filter: VideoFilter, strength: Double,
                       layers: [VideoLayer] = [], to destination: URL) async throws -> ExportedVideo {
        let joined = try await join(segments)
        let whole = CMTimeRange(start: .zero, duration: joined.composition.duration)
        let window = timeRange.map { $0.intersection(whole) } ?? whole
        guard window.duration > .zero else { throw VideoExportError.nothingToExport }
        let drawn = try await rasterise(layers, for: joined)
        guard let session = AVAssetExportSession(asset: joined.composition, presetName: AVAssetExportPreset1920x1080) else {
            throw VideoExportError.sessionUnavailable
        }
        session.timeRange = window
        session.shouldOptimizeForNetworkUse = true
        session.audioMix = audioMix(for: joined)
        session.videoComposition = try await videoComposition(
            for: joined, filter: filter, strength: strength, layers: drawn, windowStart: window.start.seconds)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try await session.export(to: destination, as: .mp4)

        let duration = try await AVURLAsset(url: destination).load(.duration).seconds
        return ExportedVideo(url: destination, durationSeconds: duration, posterImage: await poster(of: destination))
    }

    /// The joined segments for playback, drawn with whatever look the box holds as each frame is shown.
    static func playerItem(segments: [URL], look: VideoLookBox, layers: VideoLayersBox = VideoLayersBox()) async throws -> AVPlayerItem {
        let joined = try await join(segments)
        let drawing = try await drawing(of: joined, look: { look.look }, layers: { layers.held })
        let item = AVPlayerItem(asset: joined.composition)
        item.videoComposition = drawing
        return item
    }

    /// The size the clips are drawn at, which layers are rasterised for (D20).
    static func frameSize(of segments: [URL]) async throws -> CGSize {
        let joined = try await join(segments)
        guard let first = joined.placements.first else { throw VideoExportError.nothingToExport }
        return renderSize(for: first.shownSize)
    }

    /// Every layer's picture, made on the main actor before the session starts (D22). A layer that
    /// cannot be drawn fails the export: a file must not upload missing its text.
    private static func rasterise(_ layers: [VideoLayer], for joined: Joined) async throws -> [DrawnLayer] {
        guard !layers.isEmpty else { return [] }
        guard let first = joined.placements.first else { throw VideoExportError.nothingToExport }
        let frame = renderSize(for: first.shownSize)
        let drawn = await MainActor.run { VideoLayerRenderer().drawn(layers, frame: frame) }
        guard drawn.count == layers.count else { throw VideoExportError.sessionUnavailable }
        return drawn
    }

    // MARK: Joining

    /// One segment's place in the joined video and how its stored pixels are turned upright.
    private struct Placement {
        let range: CMTimeRange
        let storedSize: CGSize
        let transform: CGAffineTransform

        var shownSize: CGSize {
            let shown = CGRect(origin: .zero, size: storedSize).applying(transform)
            return CGSize(width: shown.width, height: shown.height)
        }
    }

    private struct Joined {
        let composition: AVMutableComposition
        let placements: [Placement]
        let videoTrack: AVMutableCompositionTrack
        let audioTrack: AVMutableCompositionTrack?
    }

    private static func join(_ segments: [URL]) async throws -> Joined {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw VideoExportError.sessionUnavailable
        }
        var audioTrack: AVMutableCompositionTrack?
        var placements: [Placement] = []
        var cursor = CMTime.zero
        for url in segments {
            let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
            guard let video = try await asset.loadTracks(withMediaType: .video).first else {
                throw VideoExportError.nothingToExport
            }
            let (range, size, transform) = try await video.load(.timeRange, .naturalSize, .preferredTransform)
            try videoTrack.insertTimeRange(range, of: video, at: cursor)
            if let audio = try await asset.loadTracks(withMediaType: .audio).first {
                // Kept in step with the picture: a segment's sound may start or end off its video.
                let heard = try await audio.load(.timeRange).intersection(range)
                if heard.duration > .zero {
                    audioTrack = audioTrack
                        ?? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                    try audioTrack?.insertTimeRange(heard, of: audio, at: cursor + heard.start - range.start)
                }
            }
            placements.append(Placement(range: CMTimeRange(start: cursor, duration: range.duration),
                                        storedSize: size, transform: transform))
            cursor = cursor + range.duration
        }
        return Joined(composition: composition, placements: placements, videoTrack: videoTrack, audioTrack: audioTrack)
    }

    /// Mixes the segments' sound, gaps included, into one continuous run. Without a mix the file keeps
    /// one edit per segment, and `MemoAudioExporter` refuses such a track, so it gets no transcript (D10).
    private static func audioMix(for joined: Joined) -> AVAudioMix? {
        guard let track = joined.audioTrack else { return nil }
        let parameters = AVMutableAudioMixInputParameters(track: track)
        parameters.setVolume(1, at: .zero)
        let mix = AVMutableAudioMix()
        mix.inputParameters = [parameters]
        return mix
    }

    // MARK: Drawing

    /// Nil when the export needs no drawing: Normal, no layers, and every segment stored the same way. Segments
    /// recorded with different cameras or rotations are turned upright here, since one track has only
    /// one `preferredTransform`.
    private static func videoComposition(for joined: Joined, filter: VideoFilter, strength: Double,
                                      layers: [DrawnLayer], windowStart: Double) async throws -> AVVideoComposition? {
        guard let first = joined.placements.first else { throw VideoExportError.nothingToExport }
        let alike = joined.placements.allSatisfy { $0.storedSize == first.storedSize && $0.transform == first.transform }
        if filter == .normal && alike && layers.isEmpty {
            joined.videoTrack.preferredTransform = first.transform
            return nil
        }
        let look = VideoLook(filter: filter, strength: strength)
        return try await drawing(of: joined, look: { look }, layers: { (layers, windowStart) })
    }

    private static func drawing(of joined: Joined, look: @escaping @Sendable () -> VideoLook,
                                layers: @escaping @Sendable () -> (drawn: [DrawnLayer], startSeconds: Double)) async throws -> AVVideoComposition {
        guard let first = joined.placements.first else { throw VideoExportError.nothingToExport }
        let placements = joined.placements
        let renderSize = renderSize(for: first.shownSize)
        let canvas = CGRect(origin: .zero, size: renderSize)
        let drawing = try await AVVideoComposition(applyingFiltersTo: joined.composition) { frame in
            let placement = placements.last { $0.range.start <= frame.compositionTime } ?? first
            let upright = fit(turned(frame.sourceImage, by: placement.transform), in: canvas)
            let shown = look()
            let picture = shown.filter.apply(to: upright, strength: shown.strength)
                .composited(over: CIImage(color: .black))
                .cropped(to: canvas)
            let held = layers()
            let ms = Int(((frame.compositionTime.seconds - held.startSeconds) * 1000).rounded())
            let result = held.drawn.isEmpty ? picture
                : VideoLayerRenderer.compose(held.drawn, over: picture, at: ms, frame: renderSize)
            return AVCIImageFilteringResult(resultImage: result)
        }
        // The drawing above, at the export's own size and in the preview's colours (SDR).
        return AVVideoComposition(configuration: AVVideoComposition.Configuration(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2,
            colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2,
            customVideoCompositorClass: drawing.customVideoCompositorClass,
            frameDuration: drawing.frameDuration,
            instructions: drawing.instructions,
            renderSize: renderSize,
            sourceTrackIDForFrameTiming: drawing.sourceTrackIDForFrameTiming
        ))
    }

    /// The shown size scaled down to 1080×1920 (or 1920×1080 for a landscape video), never up.
    private static func renderSize(for shown: CGSize) -> CGSize {
        let limit = shown.width > shown.height ? CGSize(width: 1920, height: 1080) : CGSize(width: 1080, height: 1920)
        let scale = min(1, limit.width / shown.width, limit.height / shown.height)
        let even = { (length: CGFloat) in (length * scale / 2).rounded() * 2 }
        return CGSize(width: even(shown.width), height: even(shown.height))
    }

    /// Turns the stored pixels as `transform` says. A track transform is written for a y axis that
    /// points down; Core Image's points up, which flips the sign of the two mixed terms.
    private static func turned(_ image: CIImage, by transform: CGAffineTransform) -> CIImage {
        image.transformed(by: CGAffineTransform(a: transform.a, b: -transform.b, c: -transform.c, d: transform.d, tx: 0, ty: 0))
    }

    /// Scales the picture to fit the canvas, centred, wherever its extent was.
    private static func fit(_ image: CIImage, in canvas: CGRect) -> CIImage {
        let extent = image.extent
        let scale = min(canvas.width / extent.width, canvas.height / extent.height)
        return image.transformed(by: CGAffineTransform(translationX: -extent.midX, y: -extent.midY)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: canvas.midX, y: canvas.midY)))
    }

    private static func poster(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        do {
            return UIImage(cgImage: try await generator.image(at: .zero).image)
        } catch {
            // Recovered: the video is saved either way; the row shows its placeholder.
            Log.media.error("video poster not readable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
