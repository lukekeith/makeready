//
//  VideoReviewPlayer.swift
//  MakeReady
//
//  Review's and Trim's player (video-recorder D8, D9): the clips joined as the export joins them, a
//  window of them looped, with the chosen look drawn live.
//

import AVFoundation
import os

/// A filter at a strength from 0 to 1.
struct VideoLook: Equatable, Sendable {
    var filter: VideoFilter = .normal
    var strength: Double = 1
}

/// The look to draw next, read by the video composition on its own queue.
final class VideoLookBox: Sendable {
    private let stored = OSAllocatedUnfairLock(initialState: VideoLook())

    var look: VideoLook {
        get { stored.withLock { $0 } }
        set { stored.withLock { $0 = newValue } }
    }
}

/// What `VideoRecorderModel` needs of a player, so its tests never start one.
@MainActor
protocol VideoReviewPlaying: AnyObject {
    var layer: CALayer { get }
    /// Plays the window in a loop; false stops at the end, calls `onEnd`, and `play` there starts at 0 (D23).
    var loops: Bool { get set }
    /// Whether a load starts playing; false leaves it paused (D23).
    var autoplays: Bool { get set }
    /// Called when playback reaches the end of the window and `loops` is false.
    var onEnd: (() -> Void)? { get set }
    /// Seconds from the window's start, clamped to the window.
    var currentTime: Double { get }
    /// Plays `window` (nil = all) of the joined clips.
    func load(clips: [URL], window: ClosedRange<Double>?, look: VideoLook) async throws
    func show(_ look: VideoLook)
    /// Draws `layers` into the picture, their times from the window's start (D20, D22, D23). Shown
    /// before a load they apply when it ends; `stop` forgets them.
    func show(layers: [VideoLayer])
    func move(to window: ClosedRange<Double>)
    /// Goes on playing after the app was away; from the start when it stopped at the end.
    func play()
    func pause()
    /// Moves to `seconds` from the window's start, exactly, without starting playback.
    func seek(to seconds: Double)
    /// Unloads, and gives the audio session back.
    func stop()
}

@MainActor
final class VideoReviewPlayer: VideoReviewPlaying {
    let layer: CALayer
    var loops = true
    var autoplays = true
    var onEnd: (() -> Void)?

    private let player = AVPlayer()
    private let look = VideoLookBox()
    let layersBox = VideoLayersBox()
    private let renderer = VideoLayerRenderer()
    private let session: MemoPlaybackSessionControlling
    private var start: CMTime = .zero
    private var windowEnd: CMTime?
    private var endObserver: NSObjectProtocol?
    /// Bumped by every load and stop, so a load that is overtaken plays nothing.
    private var generation = 0
    private var layers: [VideoLayer] = []
    /// The size the loaded clips are drawn at, which layers are rasterised for; nil before a load ends.
    private var frame: CGSize?
    private var atEnd = false

    var item: AVPlayerItem? { player.currentItem }

    var currentTime: Double {
        let length = windowLength
        let seconds = player.currentTime().seconds - start.seconds
        guard seconds.isFinite else { return 0 }
        return min(max(seconds, 0), length ?? .infinity)
    }

    init(session: MemoPlaybackSessionControlling? = nil) {
        self.session = session ?? MemoPlaybackSession()
        layer = AVPlayerLayer(player: player)
        // The loop seeks back itself.
        player.actionAtItemEnd = .none
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func load(clips: [URL], window: ClosedRange<Double>?, look shown: VideoLook) async throws {
        generation += 1
        let loading = generation
        look.look = shown
        let item = try await VideoExporter.playerItem(segments: clips, look: look, layers: layersBox)
        guard loading == generation else { return }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reachedEnd() }
        }
        // `playerItem` always sets a composition, at the size layers are rasterised for.
        frame = item.videoComposition?.renderSize
        draw()
        player.replaceCurrentItem(with: item)
        if let window { move(to: window) } else { start = .zero; windowEnd = nil; layersBox.startSeconds = 0; atEnd = false }
        if autoplays { play() }
    }

    func show(_ look: VideoLook) {
        self.look.look = look
    }

    func show(layers shown: [VideoLayer]) {
        layers = shown
        draw()
        // A paused picture is not redrawn by itself, and a seek to the time it is at is skipped, so
        // the seek goes one tick aside: the same frame, drawn again.
        if player.currentItem != nil, player.rate == 0 {
            let now = player.currentTime()
            let tick = CMTime(value: 1, timescale: 600)
            player.seek(to: now > start ? now - tick : now + tick, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    func move(to window: ClosedRange<Double>) {
        start = CMTime(seconds: window.lowerBound, preferredTimescale: 600)
        windowEnd = CMTime(seconds: window.upperBound, preferredTimescale: 600)
        layersBox.startSeconds = window.lowerBound
        player.currentItem?.forwardPlaybackEndTime = windowEnd ?? .invalid
        atEnd = false
        player.seek(to: start)
    }

    func play() {
        guard player.currentItem != nil else { return }
        do {
            try session.activatePlayback()
        } catch {
            // Recovered: it plays through the session already active.
            Log.media.error("review audio session not activated: \(error.localizedDescription, privacy: .public)")
        }
        if atEnd { seek(to: 0) }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), windowLength ?? .infinity)
        atEnd = false
        player.seek(to: start + CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func stop() {
        generation += 1
        player.pause()
        player.replaceCurrentItem(with: nil)
        layers = []
        frame = nil
        layersBox.drawn = []
        atEnd = false
        session.restore()
    }

    /// The window's length in seconds, or the loaded item's when no window was given.
    private var windowLength: Double? {
        if let windowEnd { return (windowEnd - start).seconds }
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite else { return nil }
        return duration - start.seconds
    }

    private func draw() {
        guard let frame else { return }
        layersBox.drawn = renderer.drawn(layers, frame: frame)
    }

    private func reachedEnd() {
        if loops {
            player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        } else {
            player.pause()
            atEnd = true
            onEnd?()
        }
    }
}
