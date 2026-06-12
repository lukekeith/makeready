//
//  VideoLibraryGrid.swift
//  MakeReady
//
//  3-column edge-to-edge grid of photo library videos.
//  Cells use 9:16 portrait aspect ratio matching Figma design.
//  Tap a thumbnail to open VideoPreviewOverlay for zoom preview.
//
//  Internals use UICollectionView via UIViewRepresentable for true
//  cell reuse, prefetching, and reliable scrollViewDidScroll.
//

import SwiftUI
import Photos

// MARK: - VideoThumbnailCell

final class VideoThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "VideoThumbnailCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 2
        label.layer.shadowOffset = .zero
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let placeholderView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0x19/255.0, green: 0x1C/255.0, blue: 0x25/255.0, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .white
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private(set) var currentAssetID: String?
    private var currentAsset: PHAsset?
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true

        contentView.addSubview(placeholderView)
        contentView.addSubview(imageView)
        contentView.addSubview(durationLabel)
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(asset: PHAsset, formattedDuration: String, isScrubbing: Bool, size: CGSize) {
        currentAsset = asset
        currentAssetID = asset.localIdentifier
        durationLabel.text = formattedDuration

        if isScrubbing {
            showPlaceholder()
        } else {
            loadThumbnail(size: size)
        }
    }

    func setScrubbing(_ isScrubbing: Bool, size: CGSize) {
        if isScrubbing {
            showPlaceholder()
        } else {
            loadThumbnail(size: size)
        }
    }

    private func showPlaceholder() {
        loadTask?.cancel()
        loadTask = nil
        imageView.isHidden = true
        durationLabel.isHidden = true
        placeholderView.isHidden = false
        spinner.startAnimating()
    }

    private func loadThumbnail(size: CGSize) {
        guard let asset = currentAsset else { return }
        let assetID = asset.localIdentifier

        spinner.stopAnimating()
        durationLabel.isHidden = false
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak self] in
            guard let image = await PhotoLibraryManager.shared.thumbnail(for: asset, size: size) else { return }
            guard let self, self.currentAssetID == assetID else { return }
            self.imageView.image = image
            self.imageView.isHidden = false
            self.placeholderView.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        imageView.image = nil
        imageView.isHidden = true
        placeholderView.isHidden = false
        spinner.stopAnimating()
        durationLabel.isHidden = false
        contentView.alpha = 1
        currentAssetID = nil
        currentAsset = nil
    }
}

// MARK: - VideoCollectionView

private struct VideoCollectionView: UIViewRepresentable {
    let photoLibrary: PhotoLibraryManager
    let isScrubbing: Bool
    let onVideoSelected: (SelectedVideoResult) -> Void
    let onScrollChanged: (CGFloat, CGFloat, CGFloat) -> Void
    @Binding var scrollToProgress: CGFloat?

    private static let spacing: CGFloat = 2
    private static let columnCount: CGFloat = 4

    static var itemSize: CGSize {
        let screenWidth = Screen.bounds.width
        let w = floor((screenWidth - spacing * (columnCount - 1)) / columnCount)
        return CGSize(width: w, height: w * 16 / 9)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = Self.spacing
        layout.minimumLineSpacing = Self.spacing
        layout.sectionInset = .zero
        layout.itemSize = Self.itemSize

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(VideoThumbnailCell.self, forCellWithReuseIdentifier: VideoThumbnailCell.reuseIdentifier)
        cv.dataSource = context.coordinator
        cv.delegate = context.coordinator
        cv.prefetchDataSource = context.coordinator
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)

        context.coordinator.collectionView = cv
        return cv
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        // Album or data change → full reload
        let currentCount = photoLibrary.videoCount
        let currentAlbumID = photoLibrary.selectedAlbum?.id
        if coordinator.lastVideoCount != currentCount || coordinator.lastAlbumID != currentAlbumID {
            coordinator.lastVideoCount = currentCount
            coordinator.lastAlbumID = currentAlbumID
            collectionView.reloadData()
            if coordinator.lastAlbumID != currentAlbumID {
                collectionView.setContentOffset(.zero, animated: false)
            }
        }

        // Scrubbing state change → update visible cells in place
        if coordinator.lastIsScrubbing != isScrubbing {
            coordinator.lastIsScrubbing = isScrubbing
            let size = Self.itemSize
            for cell in collectionView.visibleCells {
                (cell as? VideoThumbnailCell)?.setScrubbing(isScrubbing, size: size)
            }
        }

        // Programmatic scroll from scrubber drag
        if let progress = scrollToProgress {
            let maxOffset = max(collectionView.contentSize.height - collectionView.bounds.height, 0)
            if maxOffset > 0 {
                let targetY = progress * maxOffset
                if abs(collectionView.contentOffset.y - targetY) > 1 {
                    collectionView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
                }
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
        var parent: VideoCollectionView
        weak var collectionView: UICollectionView?

        var lastVideoCount: Int = -1
        var lastAlbumID: String?
        var lastIsScrubbing: Bool = false
        var hiddenAssetID: String?

        init(parent: VideoCollectionView) {
            self.parent = parent
        }

        // MARK: DataSource

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.photoLibrary.videoCount
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: VideoThumbnailCell.reuseIdentifier,
                for: indexPath
            ) as! VideoThumbnailCell

            if let videoAsset = parent.photoLibrary.videoAsset(at: indexPath.item) {
                cell.configure(
                    asset: videoAsset.asset,
                    formattedDuration: videoAsset.formattedDuration,
                    isScrubbing: parent.isScrubbing,
                    size: VideoCollectionView.itemSize
                )
                cell.contentView.alpha = (videoAsset.asset.localIdentifier == hiddenAssetID) ? 0 : 1
            }

            return cell
        }

        // MARK: Delegate

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let cell = collectionView.cellForItem(at: indexPath),
                  let videoAsset = parent.photoLibrary.videoAsset(at: indexPath.item),
                  let window = collectionView.window else { return }

            let globalFrame = cell.convert(cell.bounds, to: nil)
            cell.contentView.alpha = 0
            hiddenAssetID = videoAsset.asset.localIdentifier

            let overlay = VideoPreviewOverlayView(
                asset: videoAsset.asset,
                sourceFrame: globalFrame,
                onSelect: { [weak self] selectedAsset in
                    self?.restoreHiddenCell()
                    let result = SelectedVideoResult(asset: selectedAsset, recordedURL: nil)
                    self?.parent.onVideoSelected(result)
                },
                onCancel: { [weak self] in
                    self?.restoreHiddenCell()
                }
            )
            overlay.present(in: window)
        }

        private func restoreHiddenCell() {
            let assetID = hiddenAssetID
            hiddenAssetID = nil
            guard let assetID, let collectionView else { return }
            for cell in collectionView.visibleCells {
                guard let thumbCell = cell as? VideoThumbnailCell,
                      thumbCell.currentAssetID == assetID else { continue }
                UIView.animate(withDuration: 0.2) {
                    thumbCell.contentView.alpha = 1
                }
            }
        }

        // MARK: Prefetching

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            let assets = indexPaths.compactMap { parent.photoLibrary.videoAsset(at: $0.item)?.asset }
            guard !assets.isEmpty else { return }
            parent.photoLibrary.prefetchThumbnails(for: assets, size: VideoCollectionView.itemSize)
        }

        func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            let assets = indexPaths.compactMap { parent.photoLibrary.videoAsset(at: $0.item)?.asset }
            guard !assets.isEmpty else { return }
            parent.photoLibrary.stopPrefetching(for: assets, size: VideoCollectionView.itemSize)
        }

        // MARK: Scroll Delegate

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offsetY = scrollView.contentOffset.y
            let contentH = scrollView.contentSize.height
            let boundsH = scrollView.bounds.height
            // Defer to avoid mutating @State during updateUIView
            DispatchQueue.main.async { [weak self] in
                self?.parent.onScrollChanged(offsetY, contentH, boundsH)
            }
        }
    }
}

// MARK: - VideoLibraryGrid

struct VideoLibraryGrid: View {
    let onVideoSelected: (SelectedVideoResult) -> Void

    @StateObject private var photoLibrary = PhotoLibraryManager.shared

    // Scroll state from UIKit callbacks
    @State private var scrollOffsetY: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    // Date scrubber state
    @State private var showDateLabel = false
    @State private var isDraggingScrubber = false
    @State private var scrubberDragProgress: CGFloat? = nil
    @State private var hideTask: Task<Void, Never>?
    @State private var isScrubbing = false
    @State private var momentumTask: Task<Void, Never>?
    @State private var scrollToTarget: CGFloat? = nil

    // MARK: - Scroll Progress

    private var scrollProgress: CGFloat {
        let maxOffset = contentHeight - viewportHeight
        guard maxOffset > 0 else { return 0 }
        return min(max(scrollOffsetY / maxOffset, 0), 1)
    }

    private var effectiveProgress: CGFloat {
        scrubberDragProgress ?? scrollProgress
    }

    private var topVisibleIndex: Int {
        guard photoLibrary.videoCount > 0 else { return 0 }
        return min(Int(effectiveProgress * CGFloat(photoLibrary.videoCount - 1)), photoLibrary.videoCount - 1)
    }

    private var currentDateLabel: String {
        guard photoLibrary.videoCount > 0,
              let asset = photoLibrary.videoAsset(at: topVisibleIndex),
              let date = asset.asset.creationDate else { return "" }
        return DateFormatters.fullMonthCommaDayYear.string(from: date)
    }

    var body: some View {
        VideoCollectionView(
            photoLibrary: photoLibrary,
            isScrubbing: isScrubbing,
            onVideoSelected: onVideoSelected,
            onScrollChanged: { offsetY, contentH, boundsH in
                scrollOffsetY = offsetY
                contentHeight = contentH
                viewportHeight = boundsH

                if !isDraggingScrubber && !isScrubbing {
                    if !showDateLabel {
                        withAnimation(Motion.microFast) {
                            showDateLabel = true
                        }
                    }
                    scheduleHideDateLabel()
                }
            },
            scrollToProgress: $scrollToTarget
        )
        .overlay(alignment: .trailing) {
            dateScrubberOverlay()
        }
        .task {
            await photoLibrary.ensureAuthorized()
        }
    }

    // MARK: - Date Scrubber Overlay

    @ViewBuilder
    private func dateScrubberOverlay() -> some View {
        if photoLibrary.videoCount > 0 {
            GeometryReader { geo in
                let labelHeight: CGFloat = 28
                let verticalInset: CGFloat = 16
                let maxY = geo.size.height - labelHeight - verticalInset * 2
                let labelY = verticalInset + effectiveProgress * maxY

                // Visible date pill — draggable for fast scrolling.
                // Only interactive when the label is visible.
                if !currentDateLabel.isEmpty && showDateLabel {
                    // When dragging, expand hit area to full width so the
                    // user can move their finger freely without losing the gesture.
                    if isDraggingScrubber {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(scrubberDragGesture(height: geo.size.height))
                    }

                    HStack {
                        Spacer()
                        Text(currentDateLabel)
                            .font(Typography.s15)
                            .foregroundColor(Color.appBackground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white)
                            .cornerRadius(32)
                            .contentShape(Rectangle())
                            .gesture(scrubberDragGesture(height: geo.size.height))
                            .padding(.trailing, isDraggingScrubber ? 72 : 12)
                            .animation(Motion.micro, value: isDraggingScrubber)
                    }
                    .offset(y: labelY)
                }
            }
            .coordinateSpace(name: "scrubber")
        }
    }

    private func scrubberDragGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("scrubber"))
            .onChanged { value in
                if !isDraggingScrubber {
                    withAnimation(Motion.microFast) {
                        isDraggingScrubber = true
                        showDateLabel = true
                    }
                    isScrubbing = true
                    momentumTask?.cancel()
                }
                hideTask?.cancel()

                let progress = min(max(value.location.y / height, 0), 1)
                scrubberDragProgress = progress
                scrollToTarget = progress
            }
            .onEnded { value in
                // Calculate momentum from drag velocity
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let momentumY = value.location.y + velocity * 0.3
                let momentumProgress = min(max(momentumY / height, 0), 1)

                // Jump pill and scroll to momentum target (no withAnimation —
                // Optional<CGFloat> isn't VectorArithmetic so animation snaps)
                scrubberDragProgress = momentumProgress
                scrollToTarget = momentumProgress

                withAnimation(Motion.micro) {
                    isDraggingScrubber = false
                }

                // After momentum settles, clear drag state, load thumbnails,
                // then start the 1-second visible + 500ms fade sequence
                momentumTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    scrubberDragProgress = nil
                    scrollToTarget = nil
                    isScrubbing = false
                    scheduleHideDateLabel()
                }
            }
    }

    private func scheduleHideDateLabel() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                showDateLabel = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Live Library") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VideoLibraryGrid(
            onVideoSelected: { result in
                NSLog("Selected video: \(result)")
            }
        )
    }
}
