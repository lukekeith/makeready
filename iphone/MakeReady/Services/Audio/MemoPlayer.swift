//
//  MemoPlayer.swift
//  MakeReady
//
//  Playback of one memo (D13). `MemoPlayer` owns the rules — a fresh presigned url, one re-fetch on
//  a 403, seeks clamped to [0, duration], the audio session set on play and restored on stop —
//  behind a backend and a session protocol so tests never touch AVPlayer or the real session.
//  `AVMemoPlaybackBackend` and `MemoPlaybackSession` are the production implementations.
//

import AVFoundation
import Foundation
import Observation

// MARK: - Seams

/// The audio engine under `MemoPlayer`. `onFailure` carries the HTTP status when the failure had one.
@MainActor
protocol MemoPlaybackBackend: AnyObject {
    var onFailure: ((Int?) -> Void)? { get set }
    /// Seconds from the start of the loaded item.
    var currentTime: Double { get }
    func load(url: URL)
    func play()
    func pause()
    func seek(to seconds: Double)
}

@MainActor
protocol MemoPlaybackSessionControlling: AnyObject {
    func activatePlayback() throws
    func restore()
}

// MARK: - Player

@MainActor
@Observable
final class MemoPlayer {
    enum Source {
        /// A server memo: plays `url`, which is re-fetched when it has expired.
        case remote(VoiceMemo)
        /// A memo still in the upload queue: plays its `.m4a` (D17).
        case local(url: URL, durationMs: Int)
    }

    private(set) var elapsed: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var isReady = false

    @ObservationIgnored private let backend: MemoPlaybackBackend
    @ObservationIgnored private let session: MemoPlaybackSessionControlling
    @ObservationIgnored private let fetchDetail: (String) async throws -> VoiceMemo
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var remote: VoiceMemo?
    @ObservationIgnored private var hasRefetchedAfter403 = false
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(backend: MemoPlaybackBackend,
         session: MemoPlaybackSessionControlling,
         fetchDetail: @escaping (String) async throws -> VoiceMemo,
         now: @escaping () -> Date = Date.init) {
        self.backend = backend
        self.session = session
        self.fetchDetail = fetchDetail
        self.now = now
        backend.onFailure = { [weak self] status in self?.backendFailed(status: status) }
    }

    func load(_ source: Source) async {
        ticker?.cancel()
        isPlaying = false
        isReady = false
        elapsed = 0
        hasRefetchedAfter403 = false
        switch source {
        case .local(let url, let durationMs):
            remote = nil
            duration = Double(durationMs) / 1000
            backend.load(url: url)
            isReady = true
        case .remote(let memo):
            remote = memo
            duration = Double(memo.durationMs ?? 0) / 1000
            guard let url = await playableURL(for: memo) else { return }
            backend.load(url: url)
            isReady = true
        }
    }

    func play() {
        do {
            try session.activatePlayback()
        } catch {
            Log.memo.error("playback session not activated: \(error.localizedDescription)")
        }
        isPlaying = true
        if let memo = remote, isExpired(memo) {
            Task { [weak self] in await self?.reloadFromFreshURL() }
            return
        }
        backend.play()
        startTicking()
    }

    func pause() {
        isPlaying = false
        ticker?.cancel()
        backend.pause()
    }

    func skip(by seconds: Double) {
        seek(to: elapsed + seconds)
    }

    func seek(to seconds: Double) {
        let target = min(max(seconds, 0), duration)
        elapsed = target
        backend.seek(to: target)
    }

    func stop() {
        pause()
        session.restore()
    }

    // MARK: - Private

    private func isExpired(_ memo: VoiceMemo) -> Bool {
        guard let expiresAt = memo.urlExpiresAt else { return false }
        return expiresAt <= now()
    }

    /// The memo's url, or a fresh one when it has expired. Nil when there is no usable url.
    private func playableURL(for memo: VoiceMemo) async -> URL? {
        guard isExpired(memo) else { return memo.url.flatMap(URL.init(string:)) }
        return await freshURL(for: memo)
    }

    private func fetchFresh(_ id: String) async -> VoiceMemo? {
        do {
            return try await fetchDetail(id)
        } catch {
            Log.memo.error("memo url not refreshed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Re-fetch the detail, reload the fresh url and carry on from where playback was.
    private func reloadFromFreshURL() async {
        guard let memo = remote else { return }
        let position = backend.currentTime
        guard let url = await freshURL(for: memo) else {
            isPlaying = false
            return
        }
        backend.load(url: url)
        backend.seek(to: position)
        isReady = true
        if isPlaying {
            backend.play()
            startTicking()
        }
    }

    private func freshURL(for memo: VoiceMemo) async -> URL? {
        guard let fresh = await fetchFresh(memo.id) else { return nil }
        remote = fresh
        return fresh.url.flatMap(URL.init(string:))
    }

    private func backendFailed(status: Int?) {
        guard status == 403, remote != nil, !hasRefetchedAfter403 else { return }
        hasRefetchedAfter403 = true
        Task { [weak self] in await self?.reloadFromFreshURL() }
    }

    private func startTicking() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self, !Task.isCancelled else { return }
                elapsed = min(backend.currentTime, duration)
                if duration > 0, elapsed >= duration { pause() }
            }
        }
    }
}

// MARK: - Production backend

@MainActor
final class AVMemoPlaybackBackend: MemoPlaybackBackend {
    var onFailure: ((Int?) -> Void)?

    private let player = AVPlayer()
    private var statusObservation: NSKeyValueObservation?

    var currentTime: Double {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? seconds : 0
    }

    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let status = item.errorLog()?.events.last(where: { $0.errorStatusCode != 0 })?.errorStatusCode
            Task { @MainActor in self?.onFailure?(status) }
        }
        player.replaceCurrentItem(with: item)
    }

    func play() { player.play() }

    func pause() { player.pause() }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }
}

// MARK: - Production session

/// `.playback` while a memo plays; `restore` hands back what the app had.
@MainActor
final class MemoPlaybackSession: MemoPlaybackSessionControlling {
    private struct Saved {
        let category: AVAudioSession.Category
        let mode: AVAudioSession.Mode
        let options: AVAudioSession.CategoryOptions
    }

    private let session: AVAudioSession
    private var saved: Saved?

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func activatePlayback() throws {
        if saved == nil {
            saved = Saved(category: session.category, mode: session.mode, options: session.categoryOptions)
        }
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
    }

    func restore() {
        guard let saved else { return }
        self.saved = nil
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(saved.category, mode: saved.mode, options: saved.options)
        } catch {
            Log.memo.error("playback session not restored: \(error.localizedDescription)")
        }
    }
}
