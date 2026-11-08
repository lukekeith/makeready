import AVFoundation
import SwiftUI
import UIKit

/// text-activity §iphone "Viewer", 01 §9: the viewer's video playback. One `AVPlayer` per mounted
/// video page (the active page and one neighbour each side); a page that unmounts gives its player
/// up and keeps its position, so returning resumes where it was left.
///
/// The active page autoplays; crossing the midline away pauses it, crossing back resumes it — unless
/// the leader paused it themselves, which is kept across leaving and returning (01 §9 default). A
/// video that ends holds its last frame with the play glyph; it never advances the stack.
@MainActor
@Observable
final class ViewerVideoHost {
    /// What C-135 draws, by lesson index.
    private(set) var videos: [Int: ActivityViewerMapper.Playback.Video] = [:]

    @ObservationIgnored private var players: [Int: AVPlayer] = [:]
    @ObservationIgnored private var timeObservers: [Int: Any] = [:]
    @ObservationIgnored private var statusObservers: [Int: NSKeyValueObservation] = [:]
    @ObservationIgnored private var keptPositions: [Int: CMTime] = [:]
    @ObservationIgnored private var pausedByLeader: Set<Int> = []
    @ObservationIgnored private var activePage: Int?

    /// How often C-135's time and progress update.
    private static let tickInterval = CMTime(value: 1, timescale: 4)

    func player(for page: Int) -> AVPlayer? { players[page] }

    /// Mounts players for `sources` (the mounted video pages' streams) and unmounts every other,
    /// keeping its position.
    func mount(_ sources: [Int: URL]) {
        for page in players.keys where sources[page] == nil { unmount(page) }
        for (page, url) in sources where players[page] == nil {
            let player = AVPlayer(url: url)
            player.actionAtItemEnd = .pause
            if let kept = keptPositions[page] { player.seek(to: kept, toleranceBefore: .zero, toleranceAfter: .zero) }
            players[page] = player
            observe(player, page: page)
            if page == activePage, !pausedByLeader.contains(page) { player.play() }
        }
    }

    /// 01 §7: `page` now covers the midline. It plays; every other page pauses.
    func activate(_ page: Int) {
        activePage = page
        for (index, player) in players {
            if index == page, !pausedByLeader.contains(index) { player.play() } else { player.pause() }
        }
    }

    /// C-135's play/pause, the leader's own choice.
    func setPlaying(_ page: Int, _ playing: Bool) {
        guard let player = players[page] else { return }
        if playing {
            pausedByLeader.remove(page)
            if player.currentItem.map({ $0.currentTime() >= $0.duration }) ?? false { player.seek(to: .zero) }
            player.play()
        } else {
            pausedByLeader.insert(page)
            player.pause()
        }
    }

    /// C-135's scrubber: a position 0–1 of the duration.
    func seek(_ page: Int, fraction: Double) {
        guard let player = players[page], let duration = player.currentItem?.duration, duration.isNumeric else { return }
        let target = CMTimeMultiplyByFloat64(duration, multiplier: min(1, max(0, fraction)))
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        videos[page, default: .init()].position = target.seconds
    }

    /// Leaving the viewer: every player stops and goes.
    func stop() {
        for page in Array(players.keys) { unmount(page) }
    }

    private func unmount(_ page: Int) {
        guard let player = players.removeValue(forKey: page) else { return }
        player.pause()
        keptPositions[page] = player.currentTime()
        if let observer = timeObservers.removeValue(forKey: page) { player.removeTimeObserver(observer) }
        statusObservers.removeValue(forKey: page)?.invalidate()
    }

    private func observe(_ player: AVPlayer, page: Int) {
        timeObservers[page] = player.addPeriodicTimeObserver(forInterval: Self.tickInterval, queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, let player = self.players[page] else { return }
                let duration = player.currentItem?.duration
                self.videos[page, default: .init()].position = time.seconds.isFinite ? time.seconds : 0
                if let duration, duration.isNumeric { self.videos[page, default: .init()].duration = duration.seconds }
            }
        }
        statusObservers[page] = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                self?.videos[page, default: .init()].playing = status != .paused
                self?.videos[page, default: .init()].buffering = status == .waitingToPlayAtSpecifiedRate
            }
        }
    }
}

/// The mounted player, drawn full-bleed (cover) in C-135's video slot.
struct ViewerVideoLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        // Safe: `layerClass` makes the backing layer an AVPlayerLayer.
        var playerLayer: AVPlayerLayer { layer as? AVPlayerLayer ?? AVPlayerLayer() }
    }
}
