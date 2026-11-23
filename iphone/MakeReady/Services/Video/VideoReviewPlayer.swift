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
    /// Plays `window` (nil = all) of the joined clips in a loop.
    func load(clips: [URL], window: ClosedRange<Double>?, look: VideoLook) async throws
    func show(_ look: VideoLook)
    func move(to window: ClosedRange<Double>)
    /// Goes on playing after the app was away.
    func play()
    /// Unloads, and gives the audio session back.
    func stop()
}

@MainActor
final class VideoReviewPlayer: VideoReviewPlaying {
    let layer: CALayer

    private let player = AVPlayer()
    private let look = VideoLookBox()
    private let session: MemoPlaybackSessionControlling
    private var start: CMTime = .zero
    private var endObserver: NSObjectProtocol?
    /// Bumped by every load and stop, so a load that is overtaken plays nothing.
    private var generation = 0

    var item: AVPlayerItem? { player.currentItem }

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
        let item = try await VideoExporter.playerItem(segments: clips, look: look)
        guard loading == generation else { return }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.loop() }
        }
        player.replaceCurrentItem(with: item)
        if let window { move(to: window) } else { start = .zero }
        play()
    }

    func show(_ look: VideoLook) {
        self.look.look = look
    }

    func move(to window: ClosedRange<Double>) {
        start = CMTime(seconds: window.lowerBound, preferredTimescale: 600)
        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: window.upperBound, preferredTimescale: 600)
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
        player.play()
    }

    func stop() {
        generation += 1
        player.pause()
        player.replaceCurrentItem(with: nil)
        session.restore()
    }

    private func loop() {
        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }
}
