//
//  MediaLibraryGrid.swift
//  MakeReady
//
//  Virtualized 3-column grid for the media library.
//  Uses UICollectionView for true cell reuse and prefetching.
//  1:1 aspect ratio, hard corners, edge-to-edge layout.
//

import SwiftUI

// MARK: - MediaThumbnailCell

/// Thumbnail URL for a media item — shared by the cell and the prefetcher.
func mediaThumbnailURL(for item: MediaLibraryItem) -> URL? {
    let thumbnailUrl: String?
    if let url = item.thumbnailUrl, !url.isEmpty {
        thumbnailUrl = url
    } else if item.mediaType == .photo, !item.url.isEmpty {
        thumbnailUrl = item.url.mediumImageUrl
    } else {
        thumbnailUrl = nil
    }
    guard let urlString = thumbnailUrl else { return nil }
    return URL(string: urlString)
}

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

        // Videos are identified by the duration badge alone (no center play icon)

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

        guard let url = mediaThumbnailURL(for: item) else {
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
            typeIconView.isHidden = true // icon is placeholder-only (was a faint play.fill over video thumbs)
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
        usageLabel.isHidden = true
        durationLabel.isHidden = true
        currentItemId = nil
    }
}

// MARK: - MediaCollectionView (UIViewRepresentable)

private struct MediaCollectionView: UIViewRepresentable {
    let items: [MediaLibraryItem]
    let topInset: CGFloat
    /// (item, source frame in window coords, restore). The selected cell is
    /// hidden for the detail zoom transition; the presenter calls `restore`
    /// on dismiss to un-hide it (Phase 4.4 — direct closure, replacing the
    /// old NotificationCenter handshake).
    let onItemSelected: (MediaLibraryItem, CGRect, @escaping () -> Void) -> Void
    /// Fired when scrolling nears the end of the loaded items — the host
    /// loads the next page (Phase 4.1). Re-fires are cheap: the Action
    /// no-ops while a page is in flight or when everything is loaded.
    var onNearEnd: (() -> Void)? = nil
    /// Optional handle for the detail overlay's pager (see MediaGridPagerBridge).
    var pagerBridge: MediaGridPagerBridge? = nil

    fileprivate static let spacing: CGFloat = 2
    fileprivate static let columnCount: CGFloat = 3

    /// Cell size derived from the collection view's own width (Phase 4.6 —
    /// was computed once from static Screen.bounds, which is wrong on
    /// rotation/iPad and identical on today's iPhones).
    fileprivate static func itemSize(forContainerWidth width: CGFloat) -> CGSize {
        let w = floor((width - spacing * (columnCount - 1)) / columnCount)
        return CGSize(width: max(w, 1), height: max(w, 1)) // 1:1 aspect ratio
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
        // Item size comes from the flow-layout delegate (sizeForItemAt),
        // which reads the live collection view width.

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(MediaThumbnailCell.self, forCellWithReuseIdentifier: MediaThumbnailCell.reuseIdentifier)
        cv.delegate = context.coordinator
        cv.showsVerticalScrollIndicator = false
        cv.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 100, right: 0)
        cv.contentOffset = CGPoint(x: 0, y: -topInset)

        cv.prefetchDataSource = context.coordinator
        context.coordinator.collectionView = cv
        context.coordinator.installDataSource(on: cv)
        context.coordinator.wireBridge(pagerBridge)
        return cv
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.wireBridge(pagerBridge)
        coordinator.applySnapshotIfNeeded()
    }

    class Coordinator: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            // Fall back to the window/screen width before first layout.
            let width = collectionView.bounds.width > 0
                ? collectionView.bounds.width
                : (collectionView.window?.bounds.width ?? Screen.bounds.width)
            return MediaCollectionView.itemSize(forContainerWidth: width)
        }

        var parent: MediaCollectionView
        weak var collectionView: UICollectionView?
        var lastItemIds: [String] = []
        var hiddenItemId: String?

        /// Diffable source keyed by item id (Phase 4.2) — structural changes
        /// diff in place instead of reloadData() flashing every cell.
        private var dataSource: UICollectionViewDiffableDataSource<Int, String>?
        /// id → item lookup for the cell provider, refreshed per snapshot.
        private var itemsById: [String: MediaLibraryItem] = [:]

        init(parent: MediaCollectionView) {
            self.parent = parent
            super.init()
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

        // MARK: Prefetching (Phase 4.3)

        /// Cache-warming tasks keyed by item id, cancellable when the
        /// scroll direction reverses. ImageCache coalesces identical
        /// fetches, so overlap with visible-cell loads costs nothing.
        private var prefetchTasks: [String: Task<Void, Never>] = [:]

        func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
            for indexPath in indexPaths where indexPath.item < parent.items.count {
                let item = parent.items[indexPath.item]
                guard prefetchTasks[item.id] == nil,
                      let url = mediaThumbnailURL(for: item),
                      ImageCache.shared.cachedImage(for: url) == nil else { continue }
                prefetchTasks[item.id] = Task {
                    _ = try? await ImageCache.shared.fetch(url: url)
                }
            }
        }

        func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
            for indexPath in indexPaths where indexPath.item < parent.items.count {
                let id = parent.items[indexPath.item].id
                prefetchTasks[id]?.cancel()
                prefetchTasks[id] = nil
            }
        }

        func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
            if indexPath.item < parent.items.count {
                prefetchTasks[parent.items[indexPath.item].id] = nil
            }
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

            parent.onItemSelected(item, globalFrame) { [weak self] in
                self?.restoreHiddenCell()
            }
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

        // MARK: Pager bridge (detail overlay paging)

        func wireBridge(_ bridge: MediaGridPagerBridge?) {
            guard let bridge else { return }
            bridge.frameForItem = { [weak self] id in self?.frameForItem(id: id) }
            bridge.setHiddenItem = { [weak self] id in self?.setHiddenItem(id: id) }
        }

        /// Window-coordinate frame of the visible cell for an item, if any.
        func frameForItem(id: String) -> CGRect? {
            guard let collectionView, let window = collectionView.window else { return nil }
            for cell in collectionView.visibleCells {
                guard let thumbCell = cell as? MediaThumbnailCell,
                      thumbCell.currentItemId == id else { continue }
                return cell.convert(cell.bounds, to: window)
            }
            return nil
        }

        /// Move the hidden-cell marker to a new item (the overlay paged):
        /// restores the previously hidden cell and hides the new one.
        func setHiddenItem(id: String?) {
            guard hiddenItemId != id else { return }
            restoreHiddenCell()
            guard let id, let collectionView else { return }
            hiddenItemId = id
            for cell in collectionView.visibleCells {
                guard let thumbCell = cell as? MediaThumbnailCell,
                      thumbCell.currentItemId == id else { continue }
                thumbCell.contentView.alpha = 0
            }
        }
    }
}

// MARK: - MediaGridPagerBridge

/// Lets the media detail overlay coordinate with the grid while paging
/// between items: look up a cell's frame to retarget the dismiss animation,
/// and move the hidden-cell marker to whichever item the overlay shows.
/// Wired by the grid's Coordinator; called by MediaDetailOverlayView.
final class MediaGridPagerBridge {
    var frameForItem: ((String) -> CGRect?)?
    var setHiddenItem: ((String?) -> Void)?
}

// MARK: - MediaLibraryGrid (SwiftUI wrapper)

struct MediaLibraryGrid: View {
    let items: [MediaLibraryItem]
    var topInset: CGFloat = 0
    /// (item, source frame, restore) — call `restore` when whatever was
    /// presented from the tap is dismissed, to un-hide the source cell.
    let onItemSelected: (MediaLibraryItem, CGRect, @escaping () -> Void) -> Void
    var onNearEnd: (() -> Void)? = nil
    var pagerBridge: MediaGridPagerBridge? = nil

    var body: some View {
        MediaCollectionView(
            items: items,
            topInset: topInset,
            onItemSelected: onItemSelected,
            onNearEnd: onNearEnd,
            pagerBridge: pagerBridge
        )
    }
}
