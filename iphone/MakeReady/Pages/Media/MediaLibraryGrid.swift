//
//  MediaLibraryGrid.swift
//  MakeReady
//
//  Virtualized 3-column grid for the media library.
//  Uses UICollectionView for true cell reuse and prefetching.
//  1:1 aspect ratio, hard corners, edge-to-edge layout.
//

import SwiftUI

// MARK: - Notifications

extension Notification.Name {
    static let mediaDetailDismissed = Notification.Name("mediaDetailDismissed")
}

// MARK: - MediaThumbnailCell

final class MediaThumbnailCell: UICollectionViewCell {
    static let reuseIdentifier = "MediaThumbnailCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let placeholderView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.05)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let typeIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.tintColor = UIColor(white: 1, alpha: 0.2)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let playIconView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iv = UIImageView(image: UIImage(systemName: "play.fill", withConfiguration: config))
        iv.tintColor = UIColor(white: 1, alpha: 0.8)
        iv.contentMode = .center
        iv.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()

    private let usageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let durationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private var loadTask: Task<Void, Never>?
    private(set) var currentItemId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true

        contentView.addSubview(placeholderView)
        contentView.addSubview(imageView)
        contentView.addSubview(typeIconView)
        contentView.addSubview(playIconView)
        contentView.addSubview(usageLabel)
        contentView.addSubview(durationLabel)

        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            typeIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            typeIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            typeIconView.widthAnchor.constraint(equalToConstant: 32),
            typeIconView.heightAnchor.constraint(equalToConstant: 32),

            playIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            playIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 32),
            playIconView.heightAnchor.constraint(equalToConstant: 32),

            usageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            usageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            usageLabel.heightAnchor.constraint(equalToConstant: 18),

            durationLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            durationLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            durationLabel.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: MediaLibraryItem) {
        currentItemId = item.id

        // Type icon (shown when no thumbnail)
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .regular)
        typeIconView.image = UIImage(systemName: item.mediaType.icon, withConfiguration: config)

        // Play icon for videos
        playIconView.isHidden = item.mediaType != .video

        // Usage count
        if item.usageCount > 0 {
            usageLabel.text = " \(item.usageCount) "
            usageLabel.isHidden = false
        } else {
            usageLabel.isHidden = true
        }

        // Duration
        if let duration = item.formattedDuration {
            durationLabel.text = " \(duration) "
            durationLabel.isHidden = false
        } else {
            durationLabel.isHidden = true
        }

        // Load thumbnail
        loadThumbnail(item: item)
    }

    private func loadThumbnail(item: MediaLibraryItem) {
        loadTask?.cancel()

        let itemId = item.id
        let thumbnailUrl: String?

        if let url = item.thumbnailUrl, !url.isEmpty {
            thumbnailUrl = url
        } else if item.mediaType == .photo, !item.url.isEmpty {
            thumbnailUrl = item.url.mediumImageUrl
        } else {
            thumbnailUrl = nil
        }

        guard let urlString = thumbnailUrl, let url = URL(string: urlString) else {
            imageView.isHidden = true
            placeholderView.isHidden = false
            typeIconView.isHidden = false
            return
        }

        // Synchronous cache check (nonisolated)
        if let cached = ImageCache.shared.cachedImage(for: url) {
            imageView.image = cached
            imageView.isHidden = false
            placeholderView.isHidden = true
            typeIconView.isHidden = false
            return
        }

        loadTask = Task { @MainActor [weak self] in
            do {
                let image = try await ImageCache.shared.fetch(url: url)
                guard let self, self.currentItemId == itemId else { return }
                self.imageView.image = image
                self.imageView.isHidden = false
                self.placeholderView.isHidden = true
                self.typeIconView.isHidden = true
            } catch {
                // Leave placeholder showing
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        imageView.image = nil
        imageView.isHidden = true
        placeholderView.isHidden = false
        typeIconView.isHidden = false
        playIconView.isHidden = true
        usageLabel.isHidden = true
        durationLabel.isHidden = true
        currentItemId = nil
    }
}

// MARK: - MediaCollectionView (UIViewRepresentable)

private struct MediaCollectionView: UIViewRepresentable {
    let items: [MediaLibraryItem]
    let topInset: CGFloat
    let onItemSelected: (MediaLibraryItem, CGRect) -> Void
    /// Fired when scrolling nears the end of the loaded items — the host
    /// loads the next page (Phase 4.1). Re-fires are cheap: the Action
    /// no-ops while a page is in flight or when everything is loaded.
    var onNearEnd: (() -> Void)? = nil

    private static let spacing: CGFloat = 2
    private static let columnCount: CGFloat = 3

    static var itemSize: CGSize {
        let screenWidth = Screen.bounds.width
        let w = floor((screenWidth - spacing * (columnCount - 1)) / columnCount)
        return CGSize(width: w, height: w) // 1:1 aspect ratio
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
        cv.register(MediaThumbnailCell.self, forCellWithReuseIdentifier: MediaThumbnailCell.reuseIdentifier)
        cv.delegate = context.coordinator
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 100, right: 0)
        cv.contentOffset = CGPoint(x: 0, y: -topInset)

        context.coordinator.collectionView = cv
        context.coordinator.installDataSource(on: cv)
        return cv
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.applySnapshotIfNeeded()
    }

    class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: MediaCollectionView
        weak var collectionView: UICollectionView?
        var lastItemIds: [String] = []
        var hiddenItemId: String?
        private var dismissObserver: NSObjectProtocol?

        /// Diffable source keyed by item id (Phase 4.2) — structural changes
        /// diff in place instead of reloadData() flashing every cell.
        private var dataSource: UICollectionViewDiffableDataSource<Int, String>?
        /// id → item lookup for the cell provider, refreshed per snapshot.
        private var itemsById: [String: MediaLibraryItem] = [:]

        init(parent: MediaCollectionView) {
            self.parent = parent
            super.init()

            // Listen for detail dismiss to restore hidden cell
            dismissObserver = NotificationCenter.default.addObserver(
                forName: .mediaDetailDismissed,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.restoreHiddenCell()
            }
        }

        deinit {
            if let observer = dismissObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func installDataSource(on collectionView: UICollectionView) {
            let ds = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { [weak self] cv, indexPath, itemId in
                let cell = cv.dequeueReusableCell(
                    withReuseIdentifier: MediaThumbnailCell.reuseIdentifier,
                    for: indexPath
                ) as! MediaThumbnailCell

                if let self, let item = self.itemsById[itemId] {
                    cell.configure(item: item)
                    cell.contentView.alpha = (item.id == self.hiddenItemId) ? 0 : 1
                }

                return cell
            }
            dataSource = ds
            applySnapshotIfNeeded()
        }

        /// Apply a new snapshot only when item identity changes — matching
        /// the previous reloadData() trigger, which also ignored
        /// content-only changes to an unchanged id list.
        func applySnapshotIfNeeded() {
            guard let dataSource else { return }
            let newIds = parent.items.map(\.id)
            guard lastItemIds != newIds else { return }
            lastItemIds = newIds
            itemsById = Dictionary(uniqueKeysWithValues: parent.items.map { ($0.id, $0) })

            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(newIds)
            // No diff animation: cells slide-shuffling on refresh would be a
            // visible change; without it the apply is still flash-free.
            dataSource.apply(snapshot, animatingDifferences: false)
        }

        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            // Trigger the next page while ~2 rows of items remain below.
            if indexPath.item >= parent.items.count - 12 {
                parent.onNearEnd?()
            }
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard indexPath.item < parent.items.count,
                  let cell = collectionView.cellForItem(at: indexPath),
                  let window = collectionView.window else { return }

            let item = parent.items[indexPath.item]
            let globalFrame = cell.convert(cell.bounds, to: window)

            // Hide the cell while the detail is showing
            cell.contentView.alpha = 0
            hiddenItemId = item.id

            parent.onItemSelected(item, globalFrame)
        }

        /// Restore hidden cell visibility
        func restoreHiddenCell() {
            let itemId = hiddenItemId
            hiddenItemId = nil
            guard let itemId, let collectionView else { return }
            for cell in collectionView.visibleCells {
                guard let thumbCell = cell as? MediaThumbnailCell,
                      thumbCell.currentItemId == itemId else { continue }
                UIView.animate(withDuration: 0.2) {
                    thumbCell.contentView.alpha = 1
                }
            }
        }
    }
}

// MARK: - MediaLibraryGrid (SwiftUI wrapper)

struct MediaLibraryGrid: View {
    let items: [MediaLibraryItem]
    var topInset: CGFloat = 0
    let onItemSelected: (MediaLibraryItem, CGRect) -> Void
    var onNearEnd: (() -> Void)? = nil

    var body: some View {
        MediaCollectionView(
            items: items,
            topInset: topInset,
            onItemSelected: onItemSelected,
            onNearEnd: onNearEnd
        )
    }
}
