//
//  VideoPreviewOverlay.swift
//  MakeReady
//
//  Pure UIKit zoom-to-fill overlay when a video thumbnail is tapped in the library grid.
//  Animates from source frame to aspect-ratio-aware expanded size.
//  Portrait videos maximize height; landscape videos maximize width.
//
//  Features:
//    - Tap to play/pause with center play icon
//    - Horizontal scrub with 4px white progress bar
//    - Swipe-down to dismiss with background fade (buttons stay fixed)
//    - Cancel button and swipe-to-dismiss for closing
//

import UIKit
import Photos
import AVFoundation

private class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class VideoPreviewOverlayView: UIView {

    // MARK: - Callbacks

    private let asset: PHAsset
    private let sourceFrame: CGRect
    private let onSelect: (PHAsset) -> Void
    private let onCancel: () -> Void

    // MARK: - Subviews

    private let scrimView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        v.alpha = 0
        return v
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        v.layer.cornerRadius = 0
        return v
    }()

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        return iv
    }()

    private var playerView: PlayerView?

    private let playIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
        let image = UIImage(systemName: "play.fill", withConfiguration: config)
        let iv = UIImageView(image: image)
        iv.tintColor = .white
        iv.contentMode = .center
        iv.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        iv.layer.cornerRadius = 36
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = false
        iv.alpha = 1
        return iv
    }()

    private let progressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        v.layer.cornerRadius = 2
        v.clipsToBounds = true
        v.alpha = 0
        return v
    }()

    private let progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 2
        return v
    }()

    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        stack.alpha = 0
        return stack
    }()

    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Cancel", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        btn.layer.cornerRadius = 12
        return btn
    }()

    private let selectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Select", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
        btn.layer.cornerRadius = 12
        return btn
    }()

    // MARK: - Playback State

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var loopObserver: NSObjectProtocol?
    private var readyObservation: NSKeyValueObservation?
    private var isPlaying = false
    private var currentTime: TimeInterval = 0
    private var duration: TimeInterval = 0

    // MARK: - Gesture State

    private enum GestureDirection { case undecided, horizontal, vertical }
    private var gestureDirection: GestureDirection = .undecided
    private var wasPlayingBeforeScrub = false

    // MARK: - Progress Bar

    private var progressFillWidthConstraint: NSLayoutConstraint?
    private var progressBarHideWorkItem: DispatchWorkItem?

    // MARK: - Layout State

    private var isExpanded = false
    private var expandedFrame: CGRect = .zero
    private var buttonsFrame: CGRect = .zero

    // MARK: - Computed

    private var videoAspect: CGFloat {
        guard asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 9.0 / 16.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    // MARK: - Init

    init(asset: PHAsset, sourceFrame: CGRect, onSelect: @escaping (PHAsset) -> Void, onCancel: @escaping () -> Void) {
        self.asset = asset
        self.sourceFrame = sourceFrame
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(frame: .zero)
        setupViews()
        setupGestures()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        // Scrim
        addSubview(scrimView)

        // Content starts at source cell frame
        contentView.frame = sourceFrame
        addSubview(contentView)

        thumbnailImageView.frame = contentView.bounds
        thumbnailImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(thumbnailImageView)

        // Play icon
        let iconSize: CGFloat = 72
        playIcon.frame = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
        playIcon.alpha = 0 // hidden until expanded
        contentView.addSubview(playIcon)

        // Progress bar
        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.addSubview(progressFill)
        contentView.addSubview(progressTrack)

        NSLayoutConstraint.activate([
            progressTrack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            progressTrack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            progressTrack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            progressTrack.heightAnchor.constraint(equalToConstant: 4),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
        ])

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 4)
        fillWidth.isActive = true
        progressFillWidthConstraint = fillWidth

        // Buttons
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(selectTapped), for: .touchUpInside)

        cancelButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        selectButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        selectButton.translatesAutoresizingMaskIntoConstraints = false

        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(selectButton)
        addSubview(buttonStack)
    }

    private func setupGestures() {
        // Pan on content for scrub + dismiss
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        contentView.addGestureRecognizer(pan)

        // Tap on content for play/pause
        let tapContent = UITapGestureRecognizer(target: self, action: #selector(handleContentTap))
        contentView.addGestureRecognizer(tapContent)

        // Tap on scrim to dismiss
        let tapScrim = UITapGestureRecognizer(target: self, action: #selector(handleScrimTap))
        scrimView.addGestureRecognizer(tapScrim)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrimView.frame = bounds
        playIcon.center = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)

        if !isExpanded { return }
        computeExpandedLayout()
    }

    private func computeExpandedLayout() {
        let screenW = bounds.width
        let screenH = bounds.height
        let safeTop = safeAreaInsets.top
        let safeBottom = safeAreaInsets.bottom

        let topPad = safeTop + 16
        let btnH: CGFloat = 50
        let bottomReserve = safeBottom + 32 + btnH + 16
        let availH = screenH - topPad - bottomReserve
        let availW = screenW

        let exp = expandedSize(availW: availW, availH: availH)

        let expX: CGFloat
        let expY: CGFloat
        if videoAspect >= 1 {
            // Landscape: centered
            expX = (screenW - exp.width) / 2
            expY = topPad + (availH - exp.height) / 2
        } else {
            // Portrait: top-aligned
            expX = (screenW - exp.width) / 2
            expY = topPad
        }

        expandedFrame = CGRect(x: expX, y: expY, width: exp.width, height: exp.height)

        let btnY = screenH - safeBottom - 32 - btnH
        buttonsFrame = CGRect(x: 16, y: btnY, width: screenW - 32, height: btnH)
    }

    private func expandedSize(availW: CGFloat, availH: CGFloat) -> CGSize {
        if videoAspect >= 1 {
            let h = availW / videoAspect
            if h > availH { return CGSize(width: availH * videoAspect, height: availH) }
            return CGSize(width: availW, height: h)
        } else {
            let w = availH * videoAspect
            if w > availW { return CGSize(width: availW, height: availW / videoAspect) }
            return CGSize(width: w, height: availH)
        }
    }

    // MARK: - Present

    func present(in window: UIWindow) {
        frame = window.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(self)

        // Force layout to get safe area insets
        layoutIfNeeded()
        computeExpandedLayout()

        // Load thumbnail then animate
        Task { @MainActor in
            let size = CGSize(width: 1200, height: 1200)
            if let image = await PhotoLibraryManager.shared.thumbnail(for: asset, size: size) {
                thumbnailImageView.image = image
            }
            animateExpand()
            loadVideo()
        }
    }

    private func animateExpand() {
        isExpanded = true
        buttonStack.frame = buttonsFrame
        buttonStack.alpha = 0

        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0, options: []) {
            self.contentView.frame = self.expandedFrame
            self.contentView.layer.cornerRadius = 16
            self.scrimView.alpha = 0.9
            self.buttonStack.alpha = 1
            self.playIcon.alpha = 1
            self.playIcon.center = CGPoint(x: self.expandedFrame.width / 2, y: self.expandedFrame.height / 2)
            self.contentView.layoutIfNeeded()
        }
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        switch gesture.state {
        case .changed:
            if gestureDirection == .undecided {
                let absX = abs(translation.x)
                let absY = abs(translation.y)
                if absX > absY * 1.2 && absX > 5 {
                    gestureDirection = .horizontal
                    wasPlayingBeforeScrub = isPlaying
                    player?.pause()
                    isPlaying = false
                    updatePlayIcon()
                    progressBarHideWorkItem?.cancel()
                    progressTrack.alpha = 1
                } else if absY > absX && translation.y > 0 {
                    gestureDirection = .vertical
                }
            }

            switch gestureDirection {
            case .horizontal:
                handleScrub(gesture)
            case .vertical:
                handleDismissDrag(dy: translation.y)
            case .undecided:
                break
            }

        case .ended, .cancelled:
            switch gestureDirection {
            case .horizontal:
                endScrub()
            case .vertical:
                endDismissDrag(dy: translation.y, velocityY: velocity.y)
            case .undecided:
                break
            }
            gestureDirection = .undecided

        default:
            break
        }
    }

    // MARK: - Scrub

    private func handleScrub(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: contentView)
        let fraction = max(0, min(1, location.x / contentView.bounds.width))
        updateProgressBar(fraction: fraction)
        if duration > 0 {
            let target = CMTime(seconds: Double(fraction) * duration, preferredTimescale: 600)
            player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }
    }

    private func endScrub() {
        if wasPlayingBeforeScrub {
            player?.play()
            isPlaying = true
            updatePlayIcon()
        }
        scheduleProgressBarHide()
    }

    // MARK: - Dismiss Drag
    //
    // Swipe-down interpolates between expanded frame (0%) and source cell frame (100%).
    // The drag distance maps to a 0→1 progress that drives position, size, corner radius,
    // scrim opacity, button opacity, and play icon opacity.

    /// How far (in points) the user must drag to reach 100% dismiss progress.
    private var dismissDragDistance: CGFloat {
        // Distance from expanded center to source center gives a natural travel distance
        let dy = sourceFrame.midY - expandedFrame.midY
        let dx = sourceFrame.midX - expandedFrame.midX
        // Use the larger axis, with a minimum so short drags still feel responsive
        return max(abs(dy), abs(dx), 200)
    }

    private func handleDismissDrag(dy: CGFloat) {
        guard dy >= 0 else { return }
        let progress = min(dy / dismissDragDistance, 1)
        applyDismissProgress(progress)
    }

    /// Lerp helper
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func applyDismissProgress(_ t: CGFloat) {
        let f = CGRect(
            x: lerp(expandedFrame.origin.x, sourceFrame.origin.x, t),
            y: lerp(expandedFrame.origin.y, sourceFrame.origin.y, t),
            width: lerp(expandedFrame.width, sourceFrame.width, t),
            height: lerp(expandedFrame.height, sourceFrame.height, t)
        )
        contentView.frame = f
        contentView.layer.cornerRadius = lerp(16, 0, t)
        playIcon.center = CGPoint(x: f.width / 2, y: f.height / 2)
        scrimView.alpha = CGFloat(lerp(0.9, 0, t))
        buttonStack.alpha = CGFloat(max(0, 1 - t * 2.5))
        playIcon.alpha = CGFloat(max(0, 1 - t * 3))
    }

    private func endDismissDrag(dy: CGFloat, velocityY: CGFloat) {
        let progress = min(dy / dismissDragDistance, 1)
        let pastThreshold = progress > 0.35
        let flicked = velocityY > 500

        if pastThreshold || flicked {
            // Animate to source frame (100%)
            let remaining = 1 - progress
            let progressVelocity = dismissDragDistance > 0 ? velocityY / dismissDragDistance : 1
            let relativeVelocity: CGFloat = remaining > 0 ? progressVelocity / remaining : 1
            let initialVelocity = CGVector(dx: 0, dy: relativeVelocity)
            let timing = UISpringTimingParameters(mass: 1, stiffness: 300, damping: 30, initialVelocity: initialVelocity)
            let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timing)
            animator.addAnimations {
                self.applyDismissProgress(1)
            }
            animator.addCompletion { _ in
                self.cleanup()
                self.onCancel()
            }
            animator.startAnimation()
        } else {
            // Snap back to expanded (0%)
            let progressVelocity = dismissDragDistance > 0 ? velocityY / dismissDragDistance : 0
            let relativeVelocity: CGFloat = progress > 0 ? -progressVelocity / progress : 0
            let initialVelocity = CGVector(dx: 0, dy: relativeVelocity)
            let timing = UISpringTimingParameters(mass: 1, stiffness: 300, damping: 30, initialVelocity: initialVelocity)
            let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timing)
            animator.addAnimations {
                self.applyDismissProgress(0)
            }
            animator.startAnimation()
        }
    }

    // MARK: - Tap Handlers

    @objc private func handleContentTap() {
        guard isExpanded, player != nil else { return }
        togglePlayPause()
    }

    @objc private func handleScrimTap() {
        guard isExpanded else { return }
        dismissToSource()
    }

    @objc private func cancelTapped() {
        dismissToSource()
    }

    @objc private func selectTapped() {
        cleanup()
        onSelect(asset)
    }

    // MARK: - Play/Pause

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updatePlayIcon()
    }

    private func updatePlayIcon() {
        UIView.animate(withDuration: 0.2) {
            self.playIcon.alpha = self.isPlaying ? 0 : 1
        }
    }

    // MARK: - Progress Bar

    private func updateProgressBar(fraction: CGFloat) {
        let trackWidth = progressTrack.bounds.width
        progressFillWidthConstraint?.constant = max(4, trackWidth * fraction)
        progressTrack.layoutIfNeeded()
    }

    private func scheduleProgressBarHide() {
        progressBarHideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 1) {
                self?.progressTrack.alpha = 0
            }
        }
        progressBarHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    // MARK: - Dismiss Animations

    private func dismissToSource() {
        player?.pause()
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0, options: []) {
            self.contentView.frame = self.sourceFrame
            self.contentView.layer.cornerRadius = 0
            self.scrimView.alpha = 0
            self.buttonStack.alpha = 0
            self.playIcon.alpha = 0
        } completion: { _ in
            self.cleanup()
            self.onCancel()
        }
    }

    // MARK: - Video Loading

    private func loadVideo() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { [weak self] playerItem, _ in
            guard let self, let playerItem else { return }
            DispatchQueue.main.async {
                let avPlayer = AVPlayer(playerItem: playerItem)
                self.player = avPlayer

                let pv = PlayerView()
                pv.playerLayer.player = avPlayer
                pv.playerLayer.videoGravity = .resizeAspectFill
                pv.frame = self.contentView.bounds
                pv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.contentView.insertSubview(pv, aboveSubview: self.thumbnailImageView)
                self.playerView = pv

                // Hide thumbnail once the player layer has its first video frame,
                // preventing two overlapping images that animate at different rates.
                self.readyObservation = pv.playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] _, change in
                    guard change.newValue == true else { return }
                    DispatchQueue.main.async {
                        self?.thumbnailImageView.isHidden = true
                        self?.readyObservation = nil
                    }
                }

                // Periodic time observer
                let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
                self.timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                    guard let self else { return }
                    self.currentTime = time.seconds
                    if let item = avPlayer.currentItem {
                        let dur = item.duration.seconds
                        if dur.isFinite && dur > 0 {
                            self.duration = dur
                        }
                    }
                    // Update progress bar if visible and not scrubbing
                    if self.progressTrack.alpha > 0 && self.gestureDirection != .horizontal {
                        let fraction = self.duration > 0 ? CGFloat(self.currentTime / self.duration) : 0
                        self.updateProgressBar(fraction: fraction)
                    }
                }

                // Don't auto-play
                avPlayer.pause()

                // Loop
                self.loopObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: avPlayer.currentItem,
                    queue: .main
                ) { _ in
                    avPlayer.seek(to: .zero)
                    avPlayer.play()
                }
            }
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        progressBarHideWorkItem?.cancel()
        readyObservation = nil
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }
        player?.pause()
        player = nil
        playerView?.removeFromSuperview()
        playerView = nil
        removeFromSuperview()
    }
}
