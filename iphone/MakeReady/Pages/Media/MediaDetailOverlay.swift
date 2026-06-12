//
//  MediaDetailOverlay.swift
//  MakeReady
//
//  Pure UIKit full-screen overlay for media detail.
//  Animates from source cell frame (zoom-into-place transition).
//  Shows thumbnail at top, metadata sections below, and usage drilldown.
//

import UIKit
import SwiftUI
import AVFoundation
import AVKit

// MARK: - PlayerView (AVPlayerLayer host)

private class PlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class MediaDetailOverlayView: UIView {

    // MARK: - Properties

    private let item: MediaLibraryItem
    private let sourceFrame: CGRect
    private let onDismiss: () -> Void
    private let onUsageTap: ((MediaUsage) -> Void)?

    // MARK: - State

    private var detail: MediaDetailItem?
    private var usages: [MediaUsage] = []
    private var isExpanded = false
    private var expandedImageFrame: CGRect = .zero

    // Edit mode state
    private var isEditing = false
    private var editTitleInput: FloatingLabelTextField?
    private var editDescriptionInput: FloatingLabelTextView?
    private var editTagsView: UIKitTagInput?
    private var editButton: UIButton?
    private var originalTags: [String] = []
    private var isSaving = false
    private var editPanel: UIView?
    private var editPanelScroll: UIScrollView?
    private var editPanDismissStart: CGFloat = 0
    private var editImagePanGesture: UIPanGestureRecognizer?

    // Video playback state
    private var player: AVPlayer?
    private var playerView: PlayerView?
    private var timeObserver: Any?
    private var loopObserver: NSObjectProtocol?
    private var isPlaying = false

    // MARK: - Subviews

    private let scrimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0x0D/255, green: 0x10/255, blue: 0x1A/255, alpha: 1)
        v.alpha = 0
        return v
    }()

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isHidden = true
        return iv
    }()

    /// Container for the image area that supports pinch-to-zoom
    private let zoomScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.minimumZoomScale = 1.0
        sv.maximumZoomScale = 4.0
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.bouncesZoom = true
        sv.clipsToBounds = true
        return sv
    }()

    /// The zoomable content view (holds thumbnail + player)
    private let zoomContentView: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        return v
    }()

    private let placeholderView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.05)
        return v
    }()

    private let typeIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = UIColor(white: 1, alpha: 0.2)
        return iv
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.alpha = 0
        sv.contentInsetAdjustmentBehavior = .never
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Opaque background behind the info content area (below the image spacer).
    /// Allows the info section to visually cover the image when scrolled up.
    private let contentBackground: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0x0D/255, green: 0x10/255, blue: 0x1A/255, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let playIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
        let iv = UIImageView(image: UIImage(systemName: "play.fill", withConfiguration: config))
        iv.tintColor = .white
        iv.contentMode = .center
        iv.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        iv.layer.cornerRadius = 36
        iv.clipsToBounds = true
        iv.frame = CGRect(x: 0, y: 0, width: 72, height: 72)
        iv.isHidden = true
        iv.isUserInteractionEnabled = false
        return iv
    }()

    private let fullscreenButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        btn.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.isHidden = true
        return btn
    }()

    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        btn.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0, alpha: 0.4)
        btn.layer.cornerRadius = 18
        btn.clipsToBounds = true
        btn.alpha = 0
        return btn
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(white: 1, alpha: 0.5)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    // MARK: - Init

    init(item: MediaLibraryItem, sourceFrame: CGRect, onDismiss: @escaping () -> Void, onUsageTap: ((MediaUsage) -> Void)? = nil) {
        self.item = item
        self.sourceFrame = sourceFrame
        self.onDismiss = onDismiss
        self.onUsageTap = onUsageTap
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
        addSubview(scrimView)
        addSubview(scrollView)

        // Thumbnail starts at source frame
        thumbnailImageView.frame = sourceFrame
        placeholderView.frame = sourceFrame
        addSubview(placeholderView)
        addSubview(thumbnailImageView)

        // Type icon centered in placeholder
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        typeIconView.image = UIImage(systemName: item.mediaType.icon, withConfiguration: config)
        typeIconView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        typeIconView.center = CGPoint(x: sourceFrame.width / 2, y: sourceFrame.height / 2)
        placeholderView.addSubview(typeIconView)

        // Play icon for videos (on top of thumbnail)
        if item.mediaType == .video {
            addSubview(playIconView)
            playIconView.isHidden = true // shown after expand

            addSubview(fullscreenButton)
            fullscreenButton.addTarget(self, action: #selector(fullscreenTapped), for: .touchUpInside)
        }

        // Zoom scroll view — set up but not yet visible; activated after expand
        zoomScrollView.delegate = self
        zoomScrollView.isHidden = true
        addSubview(zoomScrollView)

        scrollView.addSubview(contentBackground)
        scrollView.addSubview(contentStack)
        scrollView.addSubview(loadingSpinner)

        addSubview(closeButton)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // Tap on the media area to play/pause video
        if item.mediaType == .video {
            let tap = UITapGestureRecognizer(target: self, action: #selector(mediaTapped))
            thumbnailImageView.isUserInteractionEnabled = true
            thumbnailImageView.addGestureRecognizer(tap)
        }

        // Double-tap to zoom on images
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        zoomScrollView.addGestureRecognizer(doubleTap)
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        // The dismiss pan must recognize simultaneously with the scroll view's pan
        // so we can intercept downward swipes when scrolled to top
        scrollView.panGestureRecognizer.require(toFail: pan)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        scrimView.frame = bounds
        scrollView.frame = bounds

        let safeTop = safeAreaInsets.top

        // Close button: top-right
        closeButton.frame = CGRect(x: bounds.width - 52, y: safeTop + 8, width: 36, height: 36)

        // Expanded image: full-width, 1:1 at the top
        let imgH = bounds.width
        expandedImageFrame = CGRect(x: 0, y: 0, width: bounds.width, height: imgH)

        // Loading spinner centered below the image area
        loadingSpinner.center = CGPoint(x: bounds.width / 2, y: imgH + 40)

        // Content stack in scrollView
        contentStack.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0)
        NSLayoutConstraint.deactivate(contentStack.constraints.filter { $0.firstAttribute == .width })
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Position opaque background starting at info area
        updateContentBackground()
    }

    private func updateContentBackground() {
        let infoTop = expandedImageFrame.maxY + 16
        // Tall enough to cover well beyond any content
        contentBackground.frame = CGRect(x: 0, y: infoTop, width: bounds.width, height: bounds.height * 5)
    }

    // MARK: - Present

    func present(in window: UIWindow) {
        frame = window.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(self)

        layoutIfNeeded()

        // Load thumbnail
        loadThumbnailImage()

        // Animate expand
        animateExpand()

        // Fetch detail data
        loadDetailData()
    }

    private func loadThumbnailImage() {
        let urlString: String?
        if let url = item.thumbnailUrl, !url.isEmpty {
            urlString = url
        } else if item.mediaType == .photo, !item.url.isEmpty {
            urlString = item.url.mediumImageUrl
        } else {
            urlString = nil
        }

        guard let urlString, let url = URL(string: urlString) else { return }

        // Check cache first (synchronous, nonisolated)
        if let cached = ImageCache.shared.cachedImage(for: url) {
            thumbnailImageView.image = cached
            thumbnailImageView.isHidden = false
            placeholderView.isHidden = true
            return
        }

        Task { @MainActor in
            do {
                let image = try await ImageCache.shared.fetch(url: url)
                self.thumbnailImageView.image = image
                self.thumbnailImageView.isHidden = false
                self.placeholderView.isHidden = true
            } catch {
                // Silent: optional thumbnail fetch — the placeholder stays visible.
            }
        }
    }

    private func animateExpand() {
        isExpanded = true

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0, options: []) {
            self.thumbnailImageView.frame = self.expandedImageFrame
            self.placeholderView.frame = self.expandedImageFrame
            self.typeIconView.center = CGPoint(x: self.expandedImageFrame.width / 2, y: self.expandedImageFrame.height / 2)
            self.scrimView.alpha = 1
            self.closeButton.alpha = 1
        } completion: { _ in
            // After expand completes, enable pinch-to-zoom and load high-res
            self.enablePinchToZoom()
            self.loadFullResMedia()
        }

        // Fade in scrollView after thumbnail settles
        UIView.animate(withDuration: 0.3, delay: 0.25) {
            self.scrollView.alpha = 1
        }
    }

    // MARK: - Pinch to Zoom

    private func enablePinchToZoom() {
        let frame = expandedImageFrame

        // Move thumbnail into the zoom content view
        zoomContentView.frame = CGRect(origin: .zero, size: frame.size)
        thumbnailImageView.frame = CGRect(origin: .zero, size: frame.size)
        thumbnailImageView.removeFromSuperview()
        zoomContentView.addSubview(thumbnailImageView)

        // If there's a player view, move it too
        if let pv = playerView {
            pv.frame = CGRect(origin: .zero, size: frame.size)
            pv.removeFromSuperview()
            zoomContentView.addSubview(pv)
        }

        zoomScrollView.frame = frame
        zoomScrollView.contentSize = frame.size
        zoomScrollView.addSubview(zoomContentView)
        zoomScrollView.isHidden = false
        zoomScrollView.zoomScale = 1.0

        // Hide the placeholder since image is now in the zoom view
        placeholderView.isHidden = true

        // Bring play/fullscreen controls above zoom view
        if item.mediaType == .video {
            bringSubviewToFront(playIconView)
            bringSubviewToFront(fullscreenButton)
        }
        bringSubviewToFront(closeButton)
    }

    private func disablePinchToZoom() {
        guard !zoomScrollView.isHidden else { return }

        // Reset zoom
        zoomScrollView.zoomScale = 1.0

        // Move thumbnail back out of zoom view
        thumbnailImageView.frame = expandedImageFrame
        thumbnailImageView.removeFromSuperview()
        insertSubview(thumbnailImageView, aboveSubview: placeholderView)

        // Move player view back
        if let pv = playerView {
            pv.frame = expandedImageFrame
            pv.removeFromSuperview()
            insertSubview(pv, aboveSubview: thumbnailImageView)
        }

        zoomContentView.removeFromSuperview()
        zoomScrollView.isHidden = true
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScrollView.zoomScale > 1.0 {
            zoomScrollView.setZoomScale(1.0, animated: true)
        } else {
            let location = gesture.location(in: zoomContentView)
            let zoomRect = CGRect(
                x: location.x - 50,
                y: location.y - 50,
                width: 100,
                height: 100
            )
            zoomScrollView.zoom(to: zoomRect, animated: true)
        }
    }

    // MARK: - Full-Res Media Loading

    private func loadFullResMedia() {
        if item.mediaType == .video {
            loadVideoPlayer()
        } else if item.mediaType == .photo {
            loadFullResImage()
        }
    }

    private func loadFullResImage() {
        // Load the original full-res image URL (not the medium variant)
        let fullUrl = item.url
        guard !fullUrl.isEmpty, let url = URL(string: fullUrl) else { return }

        Task { @MainActor in
            do {
                let image = try await ImageCache.shared.fetch(url: url)
                UIView.transition(with: self.thumbnailImageView, duration: 0.2, options: .transitionCrossDissolve) {
                    self.thumbnailImageView.image = image
                }
            } catch {
                // Silent: optional full-res upgrade — the thumbnail stays visible.
            }
        }
    }

    private func loadVideoPlayer() {
        // Get playback URL from the item's video or use the media URL
        let playbackUrl: String?
        if let video = item.video, let url = video.playbackUrl, !url.isEmpty {
            playbackUrl = url
        } else if item.mediaType == .video, !item.url.isEmpty {
            playbackUrl = item.url
        } else {
            playbackUrl = nil
        }

        guard let urlString = playbackUrl, let url = URL(string: urlString) else { return }

        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer

        let pv = PlayerView()
        pv.playerLayer.player = avPlayer
        pv.playerLayer.videoGravity = .resizeAspectFill
        pv.frame = expandedImageFrame
        pv.alpha = 0
        pv.isUserInteractionEnabled = true
        let pvTap = UITapGestureRecognizer(target: self, action: #selector(mediaTapped))
        pv.addGestureRecognizer(pvTap)
        insertSubview(pv, aboveSubview: thumbnailImageView)
        self.playerView = pv

        // Show play icon and fullscreen button
        playIconView.center = CGPoint(x: expandedImageFrame.midX, y: expandedImageFrame.midY)
        playIconView.isHidden = false
        playIconView.alpha = 1

        fullscreenButton.frame = CGRect(
            x: expandedImageFrame.maxX - 44,
            y: expandedImageFrame.maxY - 44,
            width: 32,
            height: 32
        )
        fullscreenButton.isHidden = false
        fullscreenButton.alpha = 1

        // Fade in player view once ready
        let readyObservation = pv.playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak pv] _, change in
            guard change.newValue == true else { return }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    pv?.alpha = 1
                }
            }
        }
        // Keep observation alive as long as overlay exists
        objc_setAssociatedObject(self, "readyObservation", readyObservation, .OBJC_ASSOCIATION_RETAIN)

        // Loop playback
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }
    }

    // MARK: - Media Tap (play/pause video)

    @objc private func mediaTapped() {
        guard item.mediaType == .video, let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            UIView.animate(withDuration: 0.2) {
                self.playIconView.alpha = 1
            }
        } else {
            player.play()
            isPlaying = true
            UIView.animate(withDuration: 0.2) {
                self.playIconView.alpha = 0
            }
        }
    }

    // MARK: - Fullscreen Video

    @objc private func fullscreenTapped() {
        guard let player else { return }

        // Pause while presenting fullscreen
        player.pause()
        isPlaying = false
        UIView.animate(withDuration: 0.2) {
            self.playIconView.alpha = 1
        }

        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.modalPresentationStyle = .fullScreen

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(playerVC, animated: true) {
                player.play()
            }
        }
    }

    // MARK: - Data Loading

    private func loadDetailData() {
        loadingSpinner.startAnimating()

        Task { @MainActor in
            do {
                let detail = try await MediaActions().loadDetail(id: item.id)
                self.detail = detail
                self.usages = detail.usages ?? []
                self.loadingSpinner.stopAnimating()
                self.buildDetailContent()
            } catch {
                // Detail load on open — console-only.
                AppState.shared.recordError(error, context: "MediaDetailOverlay.loadDetailData")
                self.loadingSpinner.stopAnimating()
                // Try to load usages separately as fallback
                do {
                    self.usages = try await MediaActions().loadUsages(id: item.id)
                } catch {
                    // Fallback load — console-only.
                    AppState.shared.recordError(error, context: "MediaDetailOverlay.loadDetailData.loadUsages")
                }
                self.buildDetailContent()
            }
        }
    }

    // MARK: - Build Content

    private func buildDetailContent() {
        // Clear existing
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 1. Image spacer (matches the image height + 16px gap)
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: expandedImageFrame.maxY + 16).isActive = true
        contentStack.addArrangedSubview(spacer)

        // 2. Title + Edit button
        let titleContainer = UIView()
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = detail?.displayTitle ?? item.displayTitle
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)

        let editBtn = UIButton(type: .system)
        let editConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        editBtn.setImage(UIImage(systemName: "pencil", withConfiguration: editConfig), for: .normal)
        editBtn.tintColor = .white
        editBtn.translatesAutoresizingMaskIntoConstraints = false
        editBtn.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        titleContainer.addSubview(editBtn)
        self.editButton = editBtn

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: editBtn.leadingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: -16),

            editBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            editBtn.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor, constant: -16),
            editBtn.widthAnchor.constraint(equalToConstant: 24),
            editBtn.heightAnchor.constraint(equalToConstant: 24),
        ])

        contentStack.addArrangedSubview(titleContainer)

        // 3. Info grid
        addSection(title: "Details") { container in
            let grid = self.buildInfoGrid()
            grid.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(grid)
            NSLayoutConstraint.activate([
                grid.topAnchor.constraint(equalTo: container.topAnchor),
                grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                grid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                grid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }

        // 4. Description (if any)
        let desc = detail?.description ?? item.description
        if let desc, !desc.isEmpty {
            addSection(title: "Description") { container in
                let descLabel = UILabel()
                descLabel.text = desc
                descLabel.font = .systemFont(ofSize: 15)
                descLabel.textColor = UIColor(white: 1, alpha: 0.7)
                descLabel.numberOfLines = 0
                descLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(descLabel)
                NSLayoutConstraint.activate([
                    descLabel.topAnchor.constraint(equalTo: container.topAnchor),
                    descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                    descLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
        }

        // 5. Tags (if any)
        let tags = detail?.tags ?? item.tags
        if !tags.isEmpty {
            addSection(title: "Tags") { container in
                let tagsView = self.buildTagsView(tags: tags)
                tagsView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(tagsView)
                NSLayoutConstraint.activate([
                    tagsView.topAnchor.constraint(equalTo: container.topAnchor),
                    tagsView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    tagsView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                    tagsView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
        }

        // 6. Usage section
        let usageCount = detail?.resolvedUsageCount ?? item.usageCount
        addSection(title: "Usage (\(usageCount))") { container in
            if self.usages.isEmpty {
                let emptyLabel = UILabel()
                emptyLabel.text = usageCount > 0 ? "Loading..." : "Not used anywhere yet"
                emptyLabel.font = .systemFont(ofSize: 15)
                emptyLabel.textColor = UIColor(white: 1, alpha: 0.4)
                emptyLabel.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(emptyLabel)
                NSLayoutConstraint.activate([
                    emptyLabel.topAnchor.constraint(equalTo: container.topAnchor),
                    emptyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    emptyLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                let usageStack = UIStackView()
                usageStack.axis = .vertical
                usageStack.spacing = 2
                usageStack.translatesAutoresizingMaskIntoConstraints = false

                for usage in self.usages {
                    let row = self.buildUsageRow(usage: usage)
                    usageStack.addArrangedSubview(row)
                }

                container.addSubview(usageStack)
                NSLayoutConstraint.activate([
                    usageStack.topAnchor.constraint(equalTo: container.topAnchor),
                    usageStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                    usageStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                    usageStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
        }

        // Bottom padding
        let bottomPad = UIView()
        bottomPad.translatesAutoresizingMaskIntoConstraints = false
        bottomPad.heightAnchor.constraint(equalToConstant: 120).isActive = true
        contentStack.addArrangedSubview(bottomPad)
    }

    // MARK: - Section Builder

    private func addSection(title: String?, content: (UIView) -> Void) {
        let sectionView = UIView()
        sectionView.translatesAutoresizingMaskIntoConstraints = false

        var topOffset: CGFloat = 0

        if let title {
            let header = UILabel()
            header.text = title.uppercased()
            header.font = .systemFont(ofSize: 13, weight: .semibold)
            header.textColor = UIColor(white: 1, alpha: 0.5)
            header.translatesAutoresizingMaskIntoConstraints = false
            sectionView.addSubview(header)
            NSLayoutConstraint.activate([
                header.topAnchor.constraint(equalTo: sectionView.topAnchor),
                header.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor, constant: 16),
                header.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor, constant: -16),
            ])
            topOffset = 28
        }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        sectionView.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: sectionView.topAnchor, constant: topOffset),
            container.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor, constant: -16),
        ])

        content(container)
        contentStack.addArrangedSubview(sectionView)
    }

    // MARK: - Info Grid

    private func buildInfoGrid() -> UIView {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8

        var rows: [(String, String, String)] = [] // (icon, label, value)

        // Type
        rows.append((item.mediaType.icon, "Type", item.mediaType.displayName))

        // Duration
        if let duration = (detail?.formattedDuration ?? item.formattedDuration) {
            rows.append(("clock", "Duration", duration))
        }

        // File size
        if let size = detail?.formattedFileSize {
            rows.append(("doc", "File Size", size))
        }

        // Dimensions
        if let dims = detail?.formattedDimensions {
            rows.append(("rectangle.split.3x3", "Dimensions", dims))
        }

        // MIME type
        if let mime = detail?.mimeType ?? item.mimeType {
            rows.append(("doc.text", "Format", mime))
        }

        // Created
        let created = detail?.createdAt ?? item.createdAt
        rows.append(("calendar", "Created", DateFormatters.mediumDateShortTime.string(from: created)))

        // Uploader
        if let uploader = detail?.uploader ?? item.uploader {
            rows.append(("person", "Uploaded by", uploader.name))
        }

        // Build the grid rows 2-at-a-time
        for i in stride(from: 0, to: rows.count, by: 2) {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 8
            rowStack.distribution = .fillEqually

            let first = buildInfoCell(icon: rows[i].0, label: rows[i].1, value: rows[i].2)
            rowStack.addArrangedSubview(first)

            if i + 1 < rows.count {
                let second = buildInfoCell(icon: rows[i+1].0, label: rows[i+1].1, value: rows[i+1].2)
                rowStack.addArrangedSubview(second)
            } else {
                let empty = UIView()
                rowStack.addArrangedSubview(empty)
            }

            grid.addArrangedSubview(rowStack)
        }

        return grid
    }

    private func buildInfoCell(icon: String, label: String, value: String) -> UIView {
        let cell = UIView()
        cell.backgroundColor = UIColor(white: 1, alpha: 0.05)
        cell.layer.cornerRadius = 8
        cell.translatesAutoresizingMaskIntoConstraints = false

        let labelLbl = UILabel()
        labelLbl.text = label.uppercased()
        labelLbl.font = .systemFont(ofSize: 11, weight: .medium)
        labelLbl.textColor = UIColor(white: 1, alpha: 0.4)
        labelLbl.translatesAutoresizingMaskIntoConstraints = false

        let valueLbl = UILabel()
        valueLbl.text = value
        valueLbl.font = .systemFont(ofSize: 11, weight: .semibold)
        valueLbl.textColor = .white
        valueLbl.numberOfLines = 1
        valueLbl.lineBreakMode = .byTruncatingTail
        valueLbl.translatesAutoresizingMaskIntoConstraints = false

        cell.addSubview(labelLbl)
        cell.addSubview(valueLbl)

        NSLayoutConstraint.activate([
            labelLbl.topAnchor.constraint(equalTo: cell.topAnchor, constant: 16),
            labelLbl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            labelLbl.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),

            valueLbl.topAnchor.constraint(equalTo: labelLbl.bottomAnchor, constant: 8),
            valueLbl.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 16),
            valueLbl.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
            valueLbl.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -16),
        ])

        return cell
    }

    // MARK: - Tags View

    private func buildTagsView(tags: [String]) -> UIView {
        // Wrapping flow layout — tags stack to show all, no ellipsis, no horizontal scroll
        let container = FlowLayoutView()
        container.spacing = 8
        container.lineSpacing = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        for tag in tags {
            let pill = PaddedLabel()
            pill.text = tag
            pill.font = .systemFont(ofSize: 13, weight: .medium)
            pill.textColor = UIColor(white: 1, alpha: 0.7)
            pill.backgroundColor = UIColor(white: 1, alpha: 0.1)
            pill.layer.cornerRadius = 14
            pill.clipsToBounds = true
            pill.textInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            container.addSubview(pill)
        }

        return container
    }

    // MARK: - Usage Row

    private func buildUsageRow(usage: MediaUsage) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor(white: 1, alpha: 0.05)
        row.layer.cornerRadius = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        row.tag = usages.firstIndex(where: { $0.id == usage.id }) ?? 0

        let titleLabel = UILabel()
        titleLabel.text = usage.resourceName ?? usage.displayResourceType
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        if let date = usage.createdAt {
            dateLabel.text = DateFormatters.mediumDate.string(from: date)
        } else {
            dateLabel.text = ""
        }
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = UIColor(white: 1, alpha: 0.4)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(titleLabel)
        row.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            dateLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(usageRowTapped(_:)))
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true

        return row
    }

    // MARK: - Edit Mode

    @objc private func editTapped() {
        guard !isEditing else { return }
        isEditing = true
        originalTags = detail?.tags ?? item.tags

        // Disable zoom
        disablePinchToZoom()

        // Create the edit panel — starts at info area position, animates to fill screen
        let safeTop = safeAreaInsets.top
        let infoTop = expandedImageFrame.maxY + 16
        let panelStartY = infoTop
        let panelEndY = safeTop

        let panel = UIView()
        panel.backgroundColor = UIColor(red: 0x0D/255, green: 0x10/255, blue: 0x1A/255, alpha: 1)
        panel.frame = CGRect(x: 0, y: panelStartY, width: bounds.width, height: bounds.height - panelStartY)
        panel.layer.cornerRadius = 16
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        panel.alpha = 0 // Start invisible for crossfade
        addSubview(panel)
        self.editPanel = panel

        // Scroll view inside the panel for edit form
        let panelScroll = UIScrollView()
        panelScroll.showsVerticalScrollIndicator = false
        panelScroll.alwaysBounceVertical = true
        panelScroll.contentInsetAdjustmentBehavior = .never
        panelScroll.keyboardDismissMode = .interactive
        panelScroll.frame = panel.bounds
        panelScroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panel.addSubview(panelScroll)
        self.editPanelScroll = panelScroll

        // Build form content into the panel
        let formStack = UIStackView()
        formStack.axis = .vertical
        formStack.spacing = 0
        formStack.translatesAutoresizingMaskIntoConstraints = false
        panelScroll.addSubview(formStack)
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: panelScroll.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: panelScroll.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: panelScroll.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: panelScroll.bottomAnchor),
            formStack.widthAnchor.constraint(equalTo: panelScroll.widthAnchor),
        ])

        buildEditForm(into: formStack)

        // Swipe-down gesture to dismiss edit mode — on the panel
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleEditPan(_:)))
        panel.addGestureRecognizer(panGesture)

        // Also add a swipe-down gesture on the image area above the panel
        let imagePan = UIPanGestureRecognizer(target: self, action: #selector(handleEditPan(_:)))
        imagePan.delegate = self
        addGestureRecognizer(imagePan)
        editImagePanGesture = imagePan

        // Parallax target
        let parallaxShift = -(infoTop - panelEndY) * 0.3

        // Phase 1: Crossfade — fade out info, fade in edit panel in place
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.scrollView.alpha = 0
            panel.alpha = 1
        }

        // Phase 2: Slide panel up with spring, slightly delayed
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0, options: []) {
            panel.frame = CGRect(x: 0, y: panelEndY, width: self.bounds.width, height: self.bounds.height - panelEndY)
            panel.layer.cornerRadius = 0
            self.closeButton.alpha = 0
            self.playIconView.alpha = 0
            self.fullscreenButton.alpha = 0
            // Parallax: image drifts up slower
            self.thumbnailImageView.transform = CGAffineTransform(translationX: 0, y: parallaxShift)
            self.zoomScrollView.transform = CGAffineTransform(translationX: 0, y: parallaxShift)
            self.placeholderView.transform = CGAffineTransform(translationX: 0, y: parallaxShift)
            self.playerView?.transform = CGAffineTransform(translationX: 0, y: parallaxShift)
        }

        // Disable the main dismiss gesture during edit (but keep the image pan for edit dismiss)
        if let mainPan = gestureRecognizers?.first(where: { $0 !== editImagePanGesture }) as? UIPanGestureRecognizer {
            mainPan.isEnabled = false
        }
    }

    @objc private func handleEditPan(_ gesture: UIPanGestureRecognizer) {
        guard let panel = editPanel else { return }
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        // Only allow downward drags, and only when panel scroll is at top
        if let scroll = editPanelScroll, scroll.contentOffset.y > 5 { return }

        switch gesture.state {
        case .began:
            editPanDismissStart = panel.frame.origin.y

        case .changed:
            guard translation.y > 0 else { return }
            let newY = editPanDismissStart + translation.y
            panel.frame.origin.y = newY
            panel.frame.size.height = bounds.height - newY

            // Progressive parallax reset
            let totalDistance = expandedImageFrame.maxY + 16 - safeAreaInsets.top
            let progress = min(translation.y / totalDistance, 1)
            let baseShift = -(totalDistance) * 0.3
            let currentShift = baseShift * (1 - progress)
            let t = CGAffineTransform(translationX: 0, y: currentShift)
            thumbnailImageView.transform = t
            zoomScrollView.transform = t
            placeholderView.transform = t
            playerView?.transform = t

            // Crossfade: edit panel fades out, info fades in
            panel.alpha = 1 - progress * 0.7
            scrollView.alpha = progress
            closeButton.alpha = progress

        case .ended, .cancelled:
            let infoTop = expandedImageFrame.maxY + 16
            if translation.y > 100 || velocity.y > 500 {
                // Dismiss edit mode
                animateEditDismiss()
            } else {
                // Snap back
                let safeTop = safeAreaInsets.top
                let parallaxShift = -(infoTop - safeTop) * 0.3
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9,
                               initialSpringVelocity: 0, options: []) {
                    panel.frame = CGRect(x: 0, y: safeTop, width: self.bounds.width, height: self.bounds.height - safeTop)
                    panel.alpha = 1
                    self.scrollView.alpha = 0
                    self.closeButton.alpha = 0
                    let t = CGAffineTransform(translationX: 0, y: parallaxShift)
                    self.thumbnailImageView.transform = t
                    self.zoomScrollView.transform = t
                    self.placeholderView.transform = t
                    self.playerView?.transform = t
                }
            }

        default:
            break
        }
    }

    private func buildEditForm(into stack: UIStackView) {
        // 1. Drag indicator
        let indicatorContainer = UIView()
        indicatorContainer.translatesAutoresizingMaskIntoConstraints = false
        let indicator = UIView()
        indicator.backgroundColor = UIColor(white: 1, alpha: 0.3)
        indicator.layer.cornerRadius = 2.5
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicatorContainer.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: indicatorContainer.centerXAnchor),
            indicator.topAnchor.constraint(equalTo: indicatorContainer.topAnchor, constant: 10),
            indicator.widthAnchor.constraint(equalToConstant: 36),
            indicator.heightAnchor.constraint(equalToConstant: 5),
            indicatorContainer.heightAnchor.constraint(equalToConstant: 24),
        ])
        stack.addArrangedSubview(indicatorContainer)

        // 2. Edit bar row: "Edit media" [Cancel] [Save]
        let barContainer = UIView()
        barContainer.translatesAutoresizingMaskIntoConstraints = false

        let barTitle = UILabel()
        barTitle.text = "Edit media"
        barTitle.font = .systemFont(ofSize: 17, weight: .bold)
        barTitle.textColor = .white
        barTitle.translatesAutoresizingMaskIntoConstraints = false

        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelBtn.tintColor = UIColor(white: 1, alpha: 0.7)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(editCancelTapped), for: .touchUpInside)

        let saveBtn = UIButton(type: .system)
        saveBtn.setTitle("Save", for: .normal)
        saveBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        saveBtn.tintColor = UIColor(red: 0x6C/255, green: 0x47/255, blue: 0xFF/255, alpha: 1)
        saveBtn.translatesAutoresizingMaskIntoConstraints = false
        saveBtn.addTarget(self, action: #selector(editSaveTapped), for: .touchUpInside)

        barContainer.addSubview(barTitle)
        barContainer.addSubview(cancelBtn)
        barContainer.addSubview(saveBtn)

        NSLayoutConstraint.activate([
            barTitle.topAnchor.constraint(equalTo: barContainer.topAnchor),
            barTitle.leadingAnchor.constraint(equalTo: barContainer.leadingAnchor, constant: 16),
            barTitle.bottomAnchor.constraint(equalTo: barContainer.bottomAnchor, constant: -16),

            cancelBtn.centerYAnchor.constraint(equalTo: barTitle.centerYAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: saveBtn.leadingAnchor, constant: -16),

            saveBtn.centerYAnchor.constraint(equalTo: barTitle.centerYAnchor),
            saveBtn.trailingAnchor.constraint(equalTo: barContainer.trailingAnchor, constant: -16),
        ])
        stack.addArrangedSubview(barContainer)

        // 3. Title field (floating label)
        let titleInput = FloatingLabelTextField(label: "Title")
        titleInput.text = detail?.displayTitle ?? item.displayTitle
        titleInput.translatesAutoresizingMaskIntoConstraints = false
        self.editTitleInput = titleInput

        let titleWrapper = UIView()
        titleWrapper.translatesAutoresizingMaskIntoConstraints = false
        titleWrapper.addSubview(titleInput)
        NSLayoutConstraint.activate([
            titleInput.topAnchor.constraint(equalTo: titleWrapper.topAnchor),
            titleInput.leadingAnchor.constraint(equalTo: titleWrapper.leadingAnchor, constant: 16),
            titleInput.trailingAnchor.constraint(equalTo: titleWrapper.trailingAnchor, constant: -16),
            titleInput.bottomAnchor.constraint(equalTo: titleWrapper.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(titleWrapper)

        // 4. Description field (floating label multiline)
        let descInput = FloatingLabelTextView(label: "Description")
        descInput.text = detail?.description ?? item.description ?? ""
        descInput.translatesAutoresizingMaskIntoConstraints = false
        self.editDescriptionInput = descInput

        let descWrapper = UIView()
        descWrapper.translatesAutoresizingMaskIntoConstraints = false
        descWrapper.addSubview(descInput)
        NSLayoutConstraint.activate([
            descInput.topAnchor.constraint(equalTo: descWrapper.topAnchor),
            descInput.leadingAnchor.constraint(equalTo: descWrapper.leadingAnchor, constant: 16),
            descInput.trailingAnchor.constraint(equalTo: descWrapper.trailingAnchor, constant: -16),
            descInput.bottomAnchor.constraint(equalTo: descWrapper.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(descWrapper)

        // 5. Tags (pill-based tag input)
        let currentTags = detail?.tags ?? item.tags
        let tagInput = UIKitTagInput(tags: currentTags, placeholder: "Add tag...")
        tagInput.translatesAutoresizingMaskIntoConstraints = false
        self.editTagsView = tagInput

        let tagSection = UIView()
        tagSection.translatesAutoresizingMaskIntoConstraints = false

        let tagHeader = UILabel()
        tagHeader.text = "TAGS"
        tagHeader.font = .systemFont(ofSize: 13, weight: .semibold)
        tagHeader.textColor = UIColor(white: 1, alpha: 0.5)
        tagHeader.translatesAutoresizingMaskIntoConstraints = false

        tagSection.addSubview(tagHeader)
        tagSection.addSubview(tagInput)
        NSLayoutConstraint.activate([
            tagHeader.topAnchor.constraint(equalTo: tagSection.topAnchor),
            tagHeader.leadingAnchor.constraint(equalTo: tagSection.leadingAnchor, constant: 16),

            tagInput.topAnchor.constraint(equalTo: tagHeader.bottomAnchor, constant: 12),
            tagInput.leadingAnchor.constraint(equalTo: tagSection.leadingAnchor, constant: 16),
            tagInput.trailingAnchor.constraint(equalTo: tagSection.trailingAnchor, constant: -16),
            tagInput.bottomAnchor.constraint(equalTo: tagSection.bottomAnchor, constant: -16),
        ])
        stack.addArrangedSubview(tagSection)

        // Bottom padding
        let bottomPad = UIView()
        bottomPad.translatesAutoresizingMaskIntoConstraints = false
        bottomPad.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(bottomPad)
    }

    @objc private func editCancelTapped() {
        endEditing(true)
        animateEditDismiss()
    }

    private func animateEditDismiss() {
        guard let panel = editPanel else { return }
        let infoTop = expandedImageFrame.maxY + 16

        // Phase 1: Slide panel down with spring + parallax reset
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0, options: []) {
            panel.frame = CGRect(x: 0, y: infoTop, width: self.bounds.width, height: self.bounds.height - infoTop)
            panel.layer.cornerRadius = 16
            self.thumbnailImageView.transform = .identity
            self.zoomScrollView.transform = .identity
            self.placeholderView.transform = .identity
            self.playerView?.transform = .identity
            if self.item.mediaType == .video {
                self.playIconView.alpha = self.isPlaying ? 0 : 1
                self.fullscreenButton.alpha = 1
            }
            self.closeButton.alpha = 1
        }

        // Phase 2: Crossfade — fade out edit panel, fade in info, slightly delayed
        UIView.animate(withDuration: 0.25, delay: 0.15, options: .curveEaseOut) {
            panel.alpha = 0
            self.scrollView.alpha = 1
        } completion: { _ in
            self.cleanupEditMode()
        }
    }

    private func cleanupEditMode() {
        isEditing = false
        editTitleInput = nil
        editDescriptionInput = nil
        editTagsView = nil
        editPanel?.removeFromSuperview()
        editPanel = nil
        editPanelScroll = nil

        // Remove the edit-mode image pan gesture
        if let pan = editImagePanGesture {
            removeGestureRecognizer(pan)
            editImagePanGesture = nil
        }

        // Re-enable zoom and main dismiss gesture
        enablePinchToZoom()
        gestureRecognizers?.forEach { $0.isEnabled = true }
    }

    @objc private func editSaveTapped() {
        guard !isSaving else { return }
        endEditing(true)
        isSaving = true

        let newTitle = (editTitleInput?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newDescription = (editDescriptionInput?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newTags = editTagsView?.tags ?? []

        Task { @MainActor in
            defer { self.isSaving = false }

            do {
                // Update title & description
                try await MediaActions().updateMedia(
                    id: self.item.id,
                    title: newTitle,
                    description: newDescription
                )

                // Sync tags
                try await MediaActions().syncTags(
                    mediaId: self.item.id,
                    oldTags: self.originalTags,
                    newTags: newTags
                )

                // Reload detail to get fresh data
                let freshDetail = try await MediaActions().loadDetail(id: self.item.id)
                self.detail = freshDetail
                self.usages = freshDetail.usages ?? []

                self.exitEditMode()
            } catch {
                // User just tapped Save — surface. No retry: the edit panel is
                // torn down below, so a safe re-run would need restructuring.
                AppState.shared.recordError(
                    error,
                    context: "MediaDetailOverlay.editSaveTapped",
                    surface: true,
                    friendlyMessage: "Couldn't save media changes"
                )
                self.exitEditMode()
            }
        }
    }

    private func exitEditMode() {
        // Rebuild detail content to show updated data
        buildDetailContent()
        // Animate the panel back down
        animateEditDismiss()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismissToSource()
    }

    /// Dismiss with animation, then call completion. Used when opening a linked resource.
    func dismissAnimated(completion: @escaping () -> Void) {
        player?.pause()
        disablePinchToZoom()
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0, options: []) {
            self.thumbnailImageView.frame = self.sourceFrame
            self.placeholderView.frame = self.sourceFrame
            self.playerView?.frame = self.sourceFrame
            self.typeIconView.center = CGPoint(x: self.sourceFrame.width / 2, y: self.sourceFrame.height / 2)
            self.scrimView.alpha = 0
            self.scrollView.alpha = 0
            self.closeButton.alpha = 0
            self.playIconView.alpha = 0
            self.fullscreenButton.alpha = 0
        } completion: { _ in
            self.cleanup()
            completion()
        }
    }

    @objc private func usageRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view, view.tag < usages.count else { return }
        let usage = usages[view.tag]
        onUsageTap?(usage)
    }

    // MARK: - Pan Gesture (swipe down to dismiss)

    private var dismissDragDistance: CGFloat {
        max(abs(sourceFrame.midY - expandedImageFrame.midY), 200)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        guard translation.y > 0 || gesture.state != .changed else { return }

        switch gesture.state {
        case .began:
            disablePinchToZoom()

        case .changed:
            let progress = min(max(translation.y / dismissDragDistance, 0), 1)
            applyDismissProgress(progress)

        case .ended, .cancelled:
            let progress = min(translation.y / dismissDragDistance, 1)
            if progress > 0.3 || velocity.y > 500 {
                animateDismiss(progress: progress, velocity: velocity.y)
            } else {
                snapBack(from: progress)
                // Re-enable zoom after snapping back
                enablePinchToZoom()
            }

        default:
            break
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func applyDismissProgress(_ t: CGFloat) {
        let f = CGRect(
            x: lerp(expandedImageFrame.origin.x, sourceFrame.origin.x, t),
            y: lerp(expandedImageFrame.origin.y, sourceFrame.origin.y, t),
            width: lerp(expandedImageFrame.width, sourceFrame.width, t),
            height: lerp(expandedImageFrame.height, sourceFrame.height, t)
        )
        thumbnailImageView.frame = f
        placeholderView.frame = f
        playerView?.frame = f
        typeIconView.center = CGPoint(x: f.width / 2, y: f.height / 2)
        playIconView.center = CGPoint(x: f.midX, y: f.midY)
        fullscreenButton.frame = CGRect(x: f.maxX - 44, y: f.maxY - 44, width: 32, height: 32)
        scrimView.alpha = 1 - t
        scrollView.alpha = max(0, 1 - t * 3)
        closeButton.alpha = max(0, 1 - t * 3)
        playIconView.alpha = max(0, (isPlaying ? 0 : 1) - t * 3)
        fullscreenButton.alpha = max(0, 1 - t * 3)
    }

    private func animateDismiss(progress: CGFloat, velocity: CGFloat) {
        let remaining = 1 - progress
        let relVelocity: CGFloat = remaining > 0 ? (velocity / dismissDragDistance) / remaining : 1
        let initialVelocity = CGVector(dx: 0, dy: relVelocity)
        let timing = UISpringTimingParameters(mass: 1, stiffness: 300, damping: 30, initialVelocity: initialVelocity)
        let animator = UIViewPropertyAnimator(duration: 0, timingParameters: timing)
        animator.addAnimations {
            self.applyDismissProgress(1)
        }
        animator.addCompletion { _ in
            self.cleanup()
        }
        animator.startAnimation()
    }

    private func snapBack(from progress: CGFloat) {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.applyDismissProgress(0)
        }
    }

    private func dismissToSource() {
        player?.pause()
        disablePinchToZoom()
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0, options: []) {
            self.thumbnailImageView.frame = self.sourceFrame
            self.placeholderView.frame = self.sourceFrame
            self.playerView?.frame = self.sourceFrame
            self.typeIconView.center = CGPoint(x: self.sourceFrame.width / 2, y: self.sourceFrame.height / 2)
            self.scrimView.alpha = 0
            self.scrollView.alpha = 0
            self.closeButton.alpha = 0
            self.playIconView.alpha = 0
            self.fullscreenButton.alpha = 0
        } completion: { _ in
            self.cleanup()
        }
    }

    private func cleanup() {
        // Clean up video player
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
        objc_setAssociatedObject(self, "readyObservation", nil, .OBJC_ASSOCIATION_RETAIN)

        removeFromSuperview()
        onDismiss()
    }
}

// MARK: - FlowLayoutView (wrapping tag pills)

private class FlowLayoutView: UIView {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    override func layoutSubviews() {
        super.layoutSubviews()

        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for sub in subviews {
            sub.sizeToFit()
            let size = sub.frame.size

            if x + size.width > bounds.width && x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }

            sub.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        // Update intrinsic content size
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for sub in subviews {
            sub.sizeToFit()
            let size = sub.frame.size

            if x + size.width > bounds.width && x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }

            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: UIView.noIntrinsicMetric, height: y + lineHeight)
    }
}

// MARK: - PaddedLabel

private class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let s = super.sizeThatFits(size)
        return CGSize(
            width: s.width + textInsets.left + textInsets.right,
            height: s.height + textInsets.top + textInsets.bottom
        )
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MediaDetailOverlayView: UIGestureRecognizerDelegate, UIScrollViewDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        let location = pan.location(in: self)

        // Must be a downward swipe
        guard velocity.y > abs(velocity.x) && velocity.y > 0 else { return false }

        // Don't allow dismiss while zoomed in
        if zoomScrollView.zoomScale > 1.01 { return false }

        // Only allow dismiss when touch is in the image/media area
        return location.y <= expandedImageFrame.maxY
    }

    // MARK: - UIScrollViewDelegate (zoom)

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if scrollView === zoomScrollView {
            return zoomContentView
        }
        return nil
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView === zoomScrollView else { return }
        // Center the content when zoomed out smaller than the scroll view
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        zoomContentView.center = CGPoint(
            x: scrollView.contentSize.width / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }
}
