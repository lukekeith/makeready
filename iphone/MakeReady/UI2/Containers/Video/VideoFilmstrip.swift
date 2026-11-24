//
//  VideoFilmstrip.swift
//  MakeReady
//
//  The editor timeline's frames, read from the kept window of the clips (video-editor D3).
//

import AVFoundation
import UIKit

enum VideoFilmstrip {
    /// Frame `index` of `count`, as it is read; one that cannot be read is never yielded, so its slot
    /// stays the placeholder.
    static func frames(of urls: [URL], window: ClosedRange<Double>?, count: Int) -> AsyncStream<(index: Int, image: UIImage)> {
        AsyncStream { continuation in
            let work = Task.detached {
                let clips = await clips(of: urls)
                let total = clips.reduce(0) { $0 + $1.duration }
                let start = window?.lowerBound ?? 0
                let length = window.map { $0.upperBound - $0.lowerBound } ?? total
                guard count > 0, length > 0, !clips.isEmpty else { return continuation.finish() }
                for index in 0..<count {
                    if Task.isCancelled { break }
                    let time = start + length * (Double(index) + 0.5) / Double(count)
                    guard let (generator, local) = locate(time, in: clips) else { continue }
                    if let image = try? await generator.image(at: CMTime(seconds: local, preferredTimescale: 600)).image {
                        continuation.yield((index, UIImage(cgImage: image)))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    private struct Clip {
        let generator: AVAssetImageGenerator
        let duration: Double
    }

    private static func clips(of urls: [URL]) async -> [Clip] {
        var out: [Clip] = []
        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let duration = try? await asset.load(.duration).seconds, duration.isFinite, duration > 0 else { continue }
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 240, height: 240)
            out.append(Clip(generator: generator, duration: duration))
        }
        return out
    }

    /// The clip holding `time` on the joined timeline, and the time inside it.
    private static func locate(_ time: Double, in clips: [Clip]) -> (AVAssetImageGenerator, Double)? {
        var offset = 0.0
        for clip in clips {
            if time < offset + clip.duration { return (clip.generator, time - offset) }
            offset += clip.duration
        }
        guard let last = clips.last else { return nil }
        return (last.generator, max(0, last.duration - 0.05))
    }
}
