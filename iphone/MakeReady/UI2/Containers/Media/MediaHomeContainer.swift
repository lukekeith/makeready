import SwiftUI

/// media-page §iphone Container: Home's Media section (D1). Shows what AppState.mediaLibrary already
/// holds at once and loads the whole photo library once per session per org (D17), in pages that fill
/// the grid as they land (D2). Search and chips run on the phone (MediaHomeMapper); the chips' C-036
/// menus are presented here, as EnrollmentsHomeContainer presents them. The section owns its scroll
/// (D16): MediaBrowser reports it to the shell's TopNav. A tile opens ImageViewer over the shell (D12).
struct MediaHomeContainer: View {
    static let pageSize = 200

    @Environment(AuthManager.self) private var authManager
    @Environment(\.displayScale) private var displayScale
    @Environment(\.sectionScrollReport) private var scrollReport
    @State private var selection = MediaHomeMapper.Selection()
    @State private var openMenu: ChipMenu?
    @State private var searchActive = false
    @State private var loadTask: Task<Void, Never>?
    @State private var imageTask: Task<Void, Never>?
    /// R4: true from the first frame when this session has no completed load for the org, so a cold
    /// launch paints `loading`, never `empty`, before page 1 lands.
    @State private var isLoading: Bool
    @State private var refreshing = false
    @State private var failed = false
    @State private var tileImages = MediaTileImages()
    /// MediaBrowser's level (it reports changes) and the range it last reported, with the grid width.
    @State private var level: MediaBrowser.Level = .five
    @State private var visibleRange: Range<Int> = 0..<0
    @State private var gridWidth: CGFloat = 0
    /// D12: the open item, and the tile list frozen while it is open (pages that land meanwhile apply on close).
    @State private var viewer: Viewer?
    @State private var frozenTiles: [MediaHomeMapper.Tile]?

    private enum ChipMenu { case tags, leaders, time }

    private struct Viewer {
        let index: Int
        let url: String
        let frame: CGRect
        let title: String
        let placeholder: UIImage?
    }

    init() {
        let app = AppState.shared
        _isLoading = State(initialValue: app.mediaPhotosLoadedOrgId == nil || app.mediaPhotosLoadedOrgId != app.organizationId)
    }

    var body: some View {
        let app = AppState.shared
        let output = MediaHomeMapper.output(items: app.mediaLibrary.all, selection: selection, today: Date(), timeZone: .current)
        let tiles = frozenTiles ?? output.tiles
        let fiveColumns = level == .five
        let urls = tiles.map { Self.tileURL($0, fiveColumns: fiveColumns, failed: tileImages.hasFailed) }
        // A tile whose `-md` hasn't landed (or failed) shows its thumb meanwhile.
        let thumbs = Dictionary(zip(urls, tiles).compactMap { url, tile -> (String, URL)? in
            guard let url, let thumb = tile.thumbURL, thumb != url else { return nil }
            return (url.absoluteString, thumb)
        }, uniquingKeysWith: { first, _ in first })
        let images = tileImages
        // Only this reader observes `generation`, so a landed image redraws the screen, not the mapper.
        MediaImageGenerationReader(images: images) { generation in
            MediaHomeScreen(
                state: .init(
                    phase: Self.phase(output: output, isLoading: isLoading, failed: failed),
                    searchText: selection.search,
                    selectedTags: selection.tags.sorted(),
                    selectedLeaders: output.leaderOptions.filter { selection.leaderIds.contains($0.id) }.map(\.label),
                    timeOption: selection.time.label,
                    photoURLs: urls.map { $0?.absoluteString ?? "" },
                    photoDates: tiles.map { Self.dayFormatter.string(from: $0.date) },
                    photoTitles: tiles.map(\.title),
                    hiddenItemID: viewer.map { Self.itemID($0.index) },
                    frozen: viewer != nil,
                    refreshing: refreshing
                ),
                onSearch: { text in update { $0.search = text } },
                onSearchActiveChange: { searchActive = $0 },
                onTapTags: { openMenu = .tags },
                onTapLeaders: { openMenu = .leaders },
                onTapTime: { openMenu = .time },
                onClearFilters: { selection = .init() },
                onRetry: { startLoad(resume: AppState.shared.mediaLibraryNextCursor, refresh: false) },
                onLevelChange: { next in
                    level = next
                    requestImages(tiles: tiles)
                },
                onTap: { id, frame in open(id: id, frame: frame, tiles: tiles) },
                onVisibleRangeChange: { range in
                    visibleRange = range
                    requestImages(tiles: tiles)
                },
                onScrollChange: { offset, interacting in scrollReport.report(offset, interacting) },
                onRefresh: { startLoad(resume: nil, refresh: true) },
                image: { key in
                    if let url = URL(string: key), let image = images.image(for: url) { return image }
                    return thumbs[key].flatMap(images.image(for:))
                },
                imageGeneration: generation
            )
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            gridWidth = width
            requestImages(tiles: tiles)
        }
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let chip = openMenu { menu(for: chip, output: output) }
        }
        .coverViewerPresentation(url: viewer?.url, sourceFrame: viewer?.frame, accessibilityLabel: viewer?.title ?? "",
                                 placeholder: viewer?.placeholder, onClose: { viewer = nil; frozenTiles = nil })
        .task {
            await AppState.shared.loadInitialData()   // waits for the org (as MembersHomeContainer)
            if Self.shouldLoad(loadedOrgId: AppState.shared.mediaPhotosLoadedOrgId, orgId: AppState.shared.organizationId) {
                startLoad(resume: nil, refresh: false)
            } else {
                isLoading = false
            }
        }
        .onDisappear {
            loadTask?.cancel()
            imageTask?.cancel()
        }
    }

    // MARK: - Decisions (pure, tested)

    /// D17: load when this session has not completed one for the current org.
    static func shouldLoad(loadedOrgId: String?, orgId: String?) -> Bool {
        guard let orgId else { return false }
        return loadedOrgId != orgId
    }

    /// D13 + R4: loading only while nothing is shown yet; a failure with photos shown keeps them.
    static func phase(output: MediaHomeMapper.Output, isLoading: Bool, failed: Bool) -> MediaHomeScreen.State.Phase {
        if failed { return .failed }
        if output.isEmptyLibrary { return isLoading ? .loading : .empty }
        if output.isNoResults { return .noResults }
        return .loaded
    }

    /// D10: `-md` at 5 columns unless it failed or there is none; the thumb otherwise.
    static func tileURL(_ tile: MediaHomeMapper.Tile, fiveColumns: Bool, failed: (URL) -> Bool) -> URL? {
        if fiveColumns, let medium = tile.mediumURL, !failed(medium) { return medium }
        return tile.thumbURL
    }

    /// D18: the reported range only, at the tile's pixel size.
    static func imageRequests(tiles: [MediaHomeMapper.Tile], range: Range<Int>, fiveColumns: Bool, tileSide: CGFloat,
                              scale: CGFloat, failed: (URL) -> Bool) -> [MediaTileImages.Request] {
        let clamped = range.clamped(to: 0..<tiles.count)
        return clamped.compactMap { index in
            tileURL(tiles[index], fiveColumns: fiveColumns, failed: failed).map { .init(url: $0, maxPixelSize: tileSide * scale) }
        }
    }

    // MARK: - Mapping

    /// MediaHomeScreen names its items "photo-<index>" over `photoURLs`.
    private static func itemID(_ index: Int) -> String { "photo-\(index)" }

    private static func index(ofItemID id: String) -> Int? {
        guard id.hasPrefix("photo-") else { return nil }
        return Int(id.dropFirst("photo-".count))
    }

    /// MediaHomeScreen.State.photoDates: "yyyy-MM-dd" in the device time zone (D5).
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// D7: Tags and Leaders are multi-select with Save/Clear; Time is single-select with Clear.
    @ViewBuilder private func menu(for chip: ChipMenu, output: MediaHomeMapper.Output) -> some View {
        switch chip {
        case .tags:
            FilterMenuOverlay(
                options: output.tagOptions.map { FilterMenuOverlay.Option(id: $0, label: $0) },
                selectionMode: .multiple, selectedIDs: selection.tags,
                onClose: { openMenu = nil },
                onSave: { ids in
                    update { $0.tags = ids }
                    openMenu = nil
                })
        case .leaders:
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: selection.leaderIds,
                onClose: { openMenu = nil },
                onSave: { ids in
                    update { $0.leaderIds = ids }
                    openMenu = nil
                })
        case .time:
            FilterMenuOverlay(
                options: MediaHomeMapper.TimeWindow.allCases.map { FilterMenuOverlay.Option(id: $0.rawValue, label: $0.label) },
                selectionMode: .single, selectedIDs: [selection.time.rawValue],
                onSelect: { option in
                    update { $0.time = MediaHomeMapper.TimeWindow(rawValue: option.id) ?? .all }
                    openMenu = nil
                },
                onClose: { openMenu = nil },
                onClear: {
                    update { $0.time = .all }
                    openMenu = nil
                },
                clearEnabled: selection.time != .all)
        }
    }

    // MARK: - Effects

    private var actions: MediaActions {
        MediaActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MediaHomeContainer.signOut", surface: false)
            }
        })
    }

    /// D2/D13/D16: a background load (open, retry) or the leader's own pull-to-refresh at the newest end.
    private func startLoad(resume: String?, refresh: Bool) {
        if refresh, refreshing { return }
        loadTask?.cancel()
        let actions = self.actions
        isLoading = true
        failed = false
        if refresh { refreshing = true }
        loadTask = Task { @MainActor in
            let outcome = await actions.loadAllPhotos(pageSize: Self.pageSize, resumeCursor: resume)
            // A cancelled load (a newer one, or the section left) leaves the flags to whoever replaced it.
            guard !Task.isCancelled else { return }
            isLoading = false
            refreshing = false
            failed = outcome == .failed
            if refresh, outcome == .failed {
                // D13: the pull is the leader's own action — the banner says so (the action already logged the cause).
                AppState.shared.recordError(APIError.serverError("Media refresh failed"), context: "MediaHomeContainer.refresh",
                                            surface: true, friendlyMessage: "Couldn't refresh photos",
                                            retry: { startLoad(resume: nil, refresh: true) })
            }
        }
    }

    private func update(_ change: (inout MediaHomeMapper.Selection) -> Void) {
        var next = selection
        change(&next)
        selection = next   // D9: the screen keeps the level and goes to the newest end on a filter change
    }

    /// D18: the reported range at the current level. A newer request cancels the older one and waits for
    /// it to wind down, so an image still in flight there is requested again rather than skipped. A `-md`
    /// that failed is followed by its thumb (D10).
    private func requestImages(tiles: [MediaHomeMapper.Tile]) {
        guard gridWidth > 0 else { return }
        let columns = CGFloat(level.columns)
        let side = (gridWidth - (columns - 1) * level.gutter) / columns
        let images = tileImages
        let build = { [range = visibleRange, five = level == .five, scale = displayScale] in
            Self.imageRequests(tiles: tiles, range: range, fiveColumns: five, tileSide: side, scale: scale, failed: images.hasFailed)
        }
        let previous = imageTask
        previous?.cancel()
        imageTask = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            let requests = build()
            await images.load(requests)
            guard !Task.isCancelled else { return }
            let fallbacks = build()
            if fallbacks != requests { await images.load(fallbacks) }
        }
    }

    /// D12: one item at a time, from the tile's global frame, seeded with the tile's loaded image.
    private func open(id: String, frame: CGRect, tiles: [MediaHomeMapper.Tile]) {
        guard viewer == nil, let index = Self.index(ofItemID: id), tiles.indices.contains(index) else { return }
        let tile = tiles[index]
        let shown = Self.tileURL(tile, fiveColumns: level == .five, failed: tileImages.hasFailed).flatMap(tileImages.image(for:))
        frozenTiles = tiles
        viewer = Viewer(index: index, url: tile.fullURL, frame: frame, title: tile.title,
                        placeholder: shown ?? tile.thumbURL.flatMap(tileImages.image(for:)))
    }
}

/// Reads `MediaTileImages.generation` in its own body, so a landed tile image re-renders only the
/// screen it wraps — never the container's mapper pass over the whole library (D15).
private struct MediaImageGenerationReader<Content: View>: View {
    let images: MediaTileImages
    @ViewBuilder let content: (Int) -> Content

    var body: some View { content(images.generation) }
}
