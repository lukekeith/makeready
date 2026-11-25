//
//  VideoEditorModel.swift
//  MakeReady
//
//  The video editor without a screen: playback, the text tool, captions and leaving (video-editor D3,
//  D4, D7, D8, D11, D14, D15, D20, D21, D23, D30). The container maps it to `VideoEditorScreen.State`.
//

import AVFoundation
import Foundation
import Observation
import QuartzCore

@MainActor @Observable
final class VideoEditorModel {
    /// The clip being edited, as Review plays it.
    struct Clip {
        let urls: [URL]
        let window: ClosedRange<Double>?
        /// The kept length in seconds.
        let duration: TimeInterval
        /// The clip's shown size (D20).
        let frame: CGSize
        let look: VideoLook
    }

    enum Captions: Equatable { case off, transcribing, added, unavailable }

    struct TextTool: Equatable {
        /// The layer being edited; nil adds one.
        let id: UUID?
        let text: String
        let style: VideoLayerStyle
        /// A caption keeps its house style (D4, D8).
        let offersStyle: Bool
    }

    private enum Phase { case idle, transcribing, unavailable }
    private enum Load { case waiting, ready, failed }

    let clip: Clip
    let captionsReason = "Captions aren't available for this video"
    let limitText = "Up to 20 text layers"
    /// Set after `init`: the session's change closure needs `self`.
    @ObservationIgnored private(set) var session: VideoEditSession!

    private(set) var isPlaying = false
    private(set) var textTool: TextTool?
    private(set) var limitMessage: String?
    private(set) var offersRemoveCaptions = false
    private(set) var confirmsCancel = false
    private(set) var isClosed = false
    private var phase = Phase.idle
    @ObservationIgnored private var load = Load.waiting

    @ObservationIgnored var onFinished: (([VideoLayer]) -> Void)?

    @ObservationIgnored private let player: any VideoReviewPlaying
    @ObservationIgnored private let transcribe: () async -> VideoTranscript?
    @ObservationIgnored private let report: (String) -> Void
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private var transcript: VideoTranscript?
    @ObservationIgnored private var transcribeTask: Task<Void, Never>?
    @ObservationIgnored private var transcribeRun = 0
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var messageTask: Task<Void, Never>?

    init(
        clip: Clip,
        layers: [VideoLayer],
        transcript: VideoTranscript?,
        player: any VideoReviewPlaying,
        transcribe: @escaping () async -> VideoTranscript?,
        save: @escaping ([VideoLayer], VideoTranscript?) -> Void,
        report: @escaping (String) -> Void,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.clip = clip
        self.transcript = transcript
        self.player = player
        self.transcribe = transcribe
        self.report = report
        self.sleep = sleep
        session = VideoEditSession(layers: layers, clipMs: Int((clip.duration * 1000).rounded())) { [weak self] layers in
            save(layers, self?.transcript)
        }
    }

    // MARK: Reading

    var captions: Captions {
        switch phase {
        case .transcribing: return .transcribing
        case .unavailable: return .unavailable
        case .idle: return session.hasCaptions ? .added : .off
        }
    }

    var playerLayer: CALayer { player.layer }

    // MARK: Playback

    /// Loads the paused player; it never draws layers, SwiftUI does (D23).
    func open() {
        player.loops = false
        player.autoplays = false
        player.onEnd = { [weak self] in self?.reachedEnd() }
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await player.load(clips: clip.urls, window: clip.window, look: clip.look)
                loaded()
            } catch {
                // Leaving cancels the load; a video the user left needs no message.
                guard !Task.isCancelled, !isClosed else { return }
                load = .failed
                isPlaying = false
                report("Couldn't play this video")
            }
        }
    }

    func playTapped() {
        if isPlaying { return pause() }
        guard load != .failed else { return }
        if session.playheadMs >= session.clipMs {
            session.seek(0)
            player.seek(to: 0)
        }
        isPlaying = true
        // Before the load ends there is nothing to play; `loaded` starts it.
        if load == .ready { player.play() }
    }

    /// A tap on the video away from every layer: deselects the selected layer, else plays or
    /// pauses (video-polish D10).
    func tapEmpty() {
        if session.selectedId != nil { return session.select(nil) }
        playTapped()
    }

    /// The playhead follows the player while it plays.
    func tick() {
        guard isPlaying, load == .ready else { return }
        session.seek(Int((player.currentTime * 1000).rounded()))
    }

    func scrub(toMs ms: Int) {
        pause()
        session.seek(ms)
        player.seek(to: Double(session.playheadMs) / 1000)
    }

    func gestureEnded() {
        session.endGesture()
    }

    /// Returns when the load `open` started has finished or been dropped.
    func loadSettled() async {
        await loadTask?.value
    }

    // MARK: Text

    func textTapped() {
        guard session.canAddText else { return showLimit(limitText) }
        pause()
        textTool = TextTool(id: nil, text: "", style: .standard, offersStyle: true)
    }

    func editTapped() {
        guard let layer = session.selected else { return }
        pause()
        textTool = TextTool(id: layer.id, text: layer.text, style: layer.style, offersStyle: layer.kind == .text)
    }

    /// Empty text deletes the layer, or adds none (D8).
    func commitText(_ text: String, style: VideoLayerStyle) {
        guard let tool = textTool else { return }
        textTool = nil
        if let id = tool.id {
            session.setText(id, text: text, style: style)
        } else {
            session.addText(text, style: style)
        }
    }

    /// Closes the text tool and keeps the layer as it was.
    func textCancelled() {
        textTool = nil
    }

    // MARK: Captions

    func captionsTapped() {
        guard phase != .transcribing else { return }
        if session.hasCaptions {
            offersRemoveCaptions = true
        } else if let transcript {
            add(transcript)
        } else {
            phase = .transcribing
            transcribeRun += 1
            let run = transcribeRun
            transcribeTask = Task { [weak self] in
                guard let self else { return }
                let answer = await transcribe()
                finishTranscribing(answer, run: run)
            }
        }
    }

    /// Returns when the transcription asked for has answered or been dropped.
    func captionsSettled() async {
        await transcribeTask?.value
    }

    func removeCaptionsConfirmed() {
        offersRemoveCaptions = false
        session.removeCaptions()
    }

    func dismissConfirm() {
        offersRemoveCaptions = false
        confirmsCancel = false
    }

    // MARK: Leaving

    func cancelTapped() {
        stopTranscribing()
        if session.canUndo { confirmsCancel = true } else { close() }
    }

    /// Back to the layers as they were when the editor opened; a transcript made here stays (D14, D30).
    func cancelConfirmed() {
        confirmsCancel = false
        session.cancel()
        close()
    }

    func doneTapped() {
        stopTranscribing()
        session.endGesture()
        close()
    }

    func backgrounded() {
        pause()
        stopTranscribing()
    }

    // MARK: Private

    /// Puts the player where the user scrubbed to, and playing if they pressed Play, while it loaded.
    private func loaded() {
        guard !isClosed else { return }
        load = .ready
        if session.playheadMs > 0 { player.seek(to: Double(session.playheadMs) / 1000) }
        if isPlaying { player.play() }
    }

    private func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
    }

    private func reachedEnd() {
        isPlaying = false
        session.seek(session.clipMs)
    }

    private func add(_ transcript: VideoTranscript) {
        guard !VideoCaptions.layers(from: transcript, clipMs: session.clipMs).isEmpty else {
            return showUnavailable()
        }
        self.transcript = transcript
        phase = .idle
        session.addCaptions(transcript)
    }

    private func finishTranscribing(_ answer: VideoTranscript?, run: Int) {
        guard run == transcribeRun, phase == .transcribing, !isClosed else { return }
        guard let answer else { return showUnavailable() }
        add(answer)
    }

    /// Drops the answer of a transcription still running (D21).
    private func stopTranscribing() {
        transcribeRun += 1
        transcribeTask?.cancel()
        if phase == .transcribing { phase = .idle }
    }

    private func showLimit(_ limit: String) {
        limitMessage = limit
        clearMessagesLater()
    }

    private func showUnavailable() {
        phase = .unavailable
        clearMessagesLater()
    }

    /// The message line stays a moment, then goes.
    private func clearMessagesLater() {
        messageTask?.cancel()
        messageTask = Task { [weak self, sleep] in
            do { try await sleep(.seconds(3)) } catch { return }
            guard let self else { return }
            limitMessage = nil
            if phase == .unavailable { phase = .idle }
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        textTool = nil
        offersRemoveCaptions = false
        pause()
        messageTask?.cancel()
        loadTask?.cancel()
        player.stop()
        onFinished?(session.layers)
    }
}
