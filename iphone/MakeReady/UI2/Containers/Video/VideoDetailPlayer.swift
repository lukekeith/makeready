import AVFoundation
import Observation
import QuartzCore

/// video-recorder D16: what `VideoDetailModel` needs from a video player, so a test never starts AVPlayer.
@MainActor
protocol VideoPlaying: AnyObject {
    /// Seconds from the start of the loaded video.
    var elapsed: Double { get }
    var isPlaying: Bool { get }
    var isReady: Bool { get }
    /// The layer the screen hosts over the poster; nil until something is loaded.
    var layer: CALayer? { get }
    func load(url: URL, duration: Double)
    func play()
    func pause()
    func seek(to seconds: Double)
    func skip(by seconds: Double)
    /// Pauses and gives the audio session back.
    func stop()
}

/// video-recorder D16: AVPlayer over the video's HLS `playbackUrl`. Playback uses the memo player's audio
/// session (`.playback`, restored on stop), so the video plays with the ringer switch off.
@MainActor
@Observable
final class AVVideoPlayer: VideoPlaying {
    private(set) var elapsed: Double = 0
    private(set) var isPlaying = false
    private(set) var isReady = false

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private let playerLayer: AVPlayerLayer
    @ObservationIgnored private let session: MemoPlaybackSessionControlling
    @ObservationIgnored private var duration: Double = 0
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObserver: NSObjectProtocol?

    var layer: CALayer? { playerLayer }

    init(session: MemoPlaybackSessionControlling? = nil) {
        self.session = session ?? MemoPlaybackSession()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, time.seconds.isFinite else { return }
                self.elapsed = min(max(time.seconds, 0), self.duration > 0 ? self.duration : time.seconds)
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func load(url: URL, duration: Double) {
        self.duration = duration
        elapsed = 0
        isPlaying = false
        isReady = false
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay: self?.isReady = true
                case .failed: self?.failed(item.error)
                default: break
                }
            }
        }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.playedToEnd() }
        }
        player.replaceCurrentItem(with: item)
    }

    func play() {
        // A video that has ended starts over.
        if duration > 0, elapsed >= duration { seek(to: 0) }
        do {
            try session.activatePlayback()
        } catch {
            Log.memo.error("video playback session not activated: \(error.localizedDescription)")
        }
        isPlaying = true
        player.play()
    }

    func pause() {
        isPlaying = false
        player.pause()
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), duration > 0 ? duration : max(seconds, 0))
        elapsed = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func skip(by seconds: Double) {
        seek(to: elapsed + seconds)
    }

    func stop() {
        pause()
        session.restore()
    }

    private func playedToEnd() {
        isPlaying = false
        elapsed = duration
    }

    private func failed(_ error: Error?) {
        isPlaying = false
        isReady = false
        AppState.shared.recordError(error ?? CancellationError(), context: "AVVideoPlayer", surface: true,
                                    friendlyMessage: "Couldn't play this video")
    }
}
