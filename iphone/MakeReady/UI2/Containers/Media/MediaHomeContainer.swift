import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// media-page §iphone Container: Home's Media section (D1). Shows what AppState.mediaLibrary already
/// holds at once and loads the whole photo library once per session per org (D17), in pages that fill
/// the grid as they land (D2). Search and chips run on the phone (MediaHomeMapper); the chips' C-036
/// menus are presented here, as EnrollmentsHomeContainer presents them. The section owns its scroll
/// (D16): MediaBrowser reports it to the shell's TopNav. A tile opens ImageViewer over the shell (D12).
///
/// media-library: the grid lists MakeReady's library and every org the leader belongs to (D4), with a
/// Source chip (D7); the section's TopNav `add` uploads photos and videos into an org (D8/D13). In
/// `.pick` mode (D9) the same grid sits under a C-040 header and a tap frames that photo as a cover.
struct MediaHomeContainer: View {
    static let pageSize = 200

    enum Mode: Equatable {
        case browse
        /// media-library D9: choose a group's or program's cover from the library.
        case pick(CoverOwner)
    }

    let mode: Mode
    /// media-library D13: bumped by the Media TopNav `add`.
    let addRequest: Int

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
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
    /// Written on every window move while scrolling, and read only by `requestImages`: a reference that is
    /// never observed, so a scroll never re-renders the container's mapper pass over the whole library.
    @State private var gridBox = MediaGridBox()
    @State private var gridWidth: CGFloat = 0
    /// D12: the open item, and the tile list frozen while it is open (pages that land meanwhile apply on close).
    @State private var viewer: Viewer?
    @State private var frozenTiles: [MediaHomeMapper.Tile]?
    /// media-library D8/D13: the org an upload goes to, the system picker and its picks.
    @State private var uploadOrgId: String?
    @State private var uploadPickerOpen = false
    @State private var uploadPicks: [PhotosPickerItem] = []
    /// media-library D9: a pick whose full image is loading (taps are ignored meanwhile).
    @State private var picking = false

    private enum ChipMenu { case source, tags, leaders, time, uploadTo }

    /// media-viewer-paging: the tapped item and its tile's global frame, and the page the viewer is on.
    private struct Viewer {
        let index: Int
        let frame: CGRect
        var current: Int
    }

    init(mode: Mode = .browse, addRequest: Int = 0) {
        self.mode = mode
        self.addRequest = addRequest
        let app = AppState.shared
        _isLoading = State(initialValue: app.mediaPhotosLoadedOrgId == nil || app.mediaPhotosLoadedOrgId != app.organizationId)
    }

    var body: some View {
        let app = AppState.shared
        let output = MediaHomeMapper.output(items: app.mediaLibrary.all, selection: selection, today: Date(), timeZone: .current)
        let tiles = frozenTiles ?? output.tiles
        let medium = Self.usesMedium(level)
        let urls = tiles.map { Self.tileURL($0, medium: medium, failed: tileImages.hasFailed) }
        // A tile whose `-md` hasn't landed (or failed) shows its thumb meanwhile.
        let thumbs = Dictionary(zip(urls, tiles).compactMap { url, tile -> (String, URL)? in
            guard let url, let thumb = tile.thumbURL, thumb != url else { return nil }
            return (url.absoluteString, thumb)
        }, uniquingKeysWith: { first, _ in first })
        let images = tileImages
        let sources = app.mediaSources
        // Built here, not in the generation reader, so a landed image doesn't re-format every tile's date.
        let photoURLs = urls.map { $0?.absoluteString ?? "" }
        let photoIDs = tiles.map(\.id)
        let photoDates = tiles.map { Self.dayFormatter.string(from: $0.date) }
        let photoTitles = tiles.map(\.title)
        // Only this reader observes `generation`, so a landed image redraws the screen, not the mapper.
        VStack(spacing: 0) {
          if case .pick = mode {
            // media-library D9: the picker page's header — back, and what it is for.
            PageHeader(style: .default, title: "Choose image", showIcons: false, rightButtons: [],
                       onLeading: { navigator.pop() })
          }
          MediaImageGenerationReader(images: images) { generation in
            MediaHomeScreen(
                state: .init(
                    phase: Self.phase(output: output, isLoading: isLoading, failed: failed),
                    searchText: selection.search,
                    selectedTags: selection.tags.sorted(),
                    selectedLeaders: output.leaderOptions.filter { selection.leaderIds.contains($0.id) }.map(\.label),
                    timeOption: selection.time.label,
                    photoURLs: photoURLs,
                    photoIDs: photoIDs,
                    photoDates: photoDates,
                    photoTitles: photoTitles,
                    hiddenItemID: viewer.flatMap { tiles.indices.contains($0.current) ? tiles[$0.current].id : nil },
                    frozen: viewer != nil,
                    refreshing: refreshing,
                    sourceLabel: Self.sourceLabel(selection.sourceIds, sources: sources),
                    sourceActive: !selection.sourceIds.isEmpty
                ),
                onSearch: { text in update { $0.search = text } },
                onSearchActiveChange: { searchActive = $0 },
                onSource: { openMenu = .source },
                onTapTags: { openMenu = .tags },
                onTapLeaders: { openMenu = .leaders },
                onTapTime: { openMenu = .time },
                onClearFilters: { selection = .init() },
                onRetry: { startLoad(resume: AppState.shared.mediaLibraryNextCursor, refresh: false) },
                onLevelChange: { next in
                    level = next
                    requestImages(tiles: tiles)
                },
                onTap: { id, frame in
                    if case .pick(let owner) = mode { pick(id: id, owner: owner) } else { open(id: id, frame: frame, tiles: tiles) }
                },
                onVisibleRangeChange: { range in
                    gridBox.visibleRange = range
                    requestImages(tiles: tiles)
                },
                onScrollChange: { offset, interacting in
                    // The grid rests at its newest (bottom) end, so its offset is large before anyone
                    // scrolls; reported as-is it read as "scrolled down" and closed the TopNav when the
                    // tab opened. Only the leader's own drag, or a pull past the top, moves the row —
                    // as a page scroll does on Groups and Members.
                    if mode == .browse, interacting || offset < 0 { scrollReport.report(offset, interacting) }
                },
                onRefresh: { startLoad(resume: nil, refresh: true) },
                image: { key in
                    if let url = URL(string: key), let image = images.image(for: url) { return image }
                    return thumbs[key].flatMap(images.image(for:))
                },
                imageGeneration: generation
            )
          }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            gridWidth = width
            requestImages(tiles: tiles)
        }
        // Unobserved: the frame moves on every frame of a TopNav morph.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { gridBox.frame = $0 }
        // Final review I3: a filter or page that changes the tiles without changing the reported range
        // (equal counts at the newest end) gets no range callback, so the new tiles are asked for here.
        .onChange(of: photoIDs) {
            requestImages(tiles: tiles)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .preference(key: UI2HidesTopNavKey.self, value: mode == .browse && searchActive)
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let chip = openMenu { menu(for: chip, output: output, sources: sources) }
        }
        // media-library D13: the system picker — a modifier, not .sheet/.fullScreenCover.
        .photosPicker(isPresented: $uploadPickerOpen, selection: $uploadPicks, maxSelectionCount: 20,
                      matching: .any(of: [.images, .videos]))
        .onChange(of: uploadPicks) { _, picks in
            guard !picks.isEmpty, let orgId = uploadOrgId else { return }
            uploadPicks = []
            Task { await enqueueUploads(picks, orgId: orgId) }
        }
        .onChange(of: addRequest) { beginUpload() }
        .imageViewerPresentation(viewer.map { opened in
            ImageViewer(
                urls: tiles.map(\.fullURL),
                startIndex: opened.index,
                sourceFrame: { index in
                    Self.tileFrame(index: index, openedIndex: opened.index, openedFrame: opened.frame, level: level,
                                   gridWidth: gridWidth, visible: Self.gridBand(screen: gridBox.frame))
                },
                accessibilityLabel: { tiles.indices.contains($0) ? tiles[$0].title : "" },
                placeholder: { index in tiles.indices.contains(index) ? tilePlaceholder(tiles[index]) : nil },
                onIndexChange: { viewer?.current = $0 },
                onClose: { viewer = nil; frozenTiles = nil }
            )
        })
        .task {
            await AppState.shared.loadInitialData()   // waits for the org (as MembersHomeContainer)
            await actions.loadSources()                // media-library D4: Source options + upload targets
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

    /// media-library D7: the Source chip's label — nil (resting "Source") with no choice, else the
    /// chosen names in source order, as "«first» +«n−1»".
    static func sourceLabel(_ ids: Set<String>, sources: [MediaSource]) -> String? {
        let names = sources.filter { ids.contains($0.id) }.map(\.name)
        switch names.count {
        case 0: return nil
        case 1: return names[0]
        default: return "\(names[0]) +\(names.count - 1)"
        }
    }

    /// media-library D8: where an upload goes. `options` are the orgs the leader may upload into
    /// (never MakeReady); with one, it is `direct`; with several, the Upload-to menu shows them,
    /// preselecting the one org the Source chip is narrowed to. Sources not loaded → the primary org.
    struct UploadTargets: Equatable {
        let options: [MediaSource]
        let preselected: String?
        let direct: String?
    }

    static func uploadTargets(sources: [MediaSource], selection: MediaHomeMapper.Selection,
                              primaryOrgId: String?) -> UploadTargets {
        if sources.isEmpty { return .init(options: [], preselected: nil, direct: primaryOrgId) }
        let options = sources.filter { !$0.isMakeReady && $0.canUpload }
        if options.count == 1 { return .init(options: options, preselected: options[0].id, direct: options[0].id) }
        let narrowed = options.filter { selection.sourceIds.contains($0.id) }
        return .init(options: options, preselected: narrowed.count == 1 ? narrowed[0].id : nil, direct: nil)
    }

    /// D13 + R4: loading only while nothing is shown yet; a failure with photos shown keeps them.
    static func phase(output: MediaHomeMapper.Output, isLoading: Bool, failed: Bool) -> MediaHomeScreen.State.Phase {
        if failed { return .failed }
        if output.isEmptyLibrary { return isLoading ? .loading : .empty }
        if output.isNoResults { return .noResults }
        return .loaded
    }

    /// D10: `-md` at 5 columns unless it failed or there is none; the thumb otherwise.
    /// The levels whose tiles are big enough for `-md`: `five`, and search's `three`.
    static func usesMedium(_ level: MediaBrowser.Level) -> Bool { level == .three || level == .five }

    static func tileURL(_ tile: MediaHomeMapper.Tile, medium: Bool, failed: (URL) -> Bool) -> URL? {
        if medium, let medium = tile.mediumURL, !failed(medium) { return medium }
        return tile.thumbURL
    }

    /// D18: the reported range only, at the tile's pixel size.
    static func imageRequests(tiles: [MediaHomeMapper.Tile], range: Range<Int>, medium: Bool, tileSide: CGFloat,
                              scale: CGFloat, failed: (URL) -> Bool) -> [MediaTileImages.Request] {
        let clamped = range.clamped(to: 0..<tiles.count)
        return clamped.compactMap { index in
            tileURL(tiles[index], medium: medium, failed: failed).map { .init(url: $0, maxPixelSize: tileSide * scale) }
        }
    }

    // MARK: - Mapping

    /// MediaHomeScreen reports a tapped item by the id the host passed in `photoIDs` — the tile's own id.
    static func index(ofTileID id: String, in tiles: [MediaHomeMapper.Tile]) -> Int? {
        tiles.firstIndex { $0.id == id }
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
    @ViewBuilder private func menu(for chip: ChipMenu, output: MediaHomeMapper.Output, sources: [MediaSource]) -> some View {
        switch chip {
        case .source:
            FilterMenuOverlay(
                options: MediaHomeMapper.sourceOptions(sources).map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) },
                selectionMode: .multiple, selectedIDs: selection.sourceIds,
                onClose: { openMenu = nil },
                onSave: { ids in
                    update { $0.sourceIds = ids }
                    openMenu = nil
                })
        case .uploadTo:
            FilterMenuOverlay(
                options: Self.uploadTargets(sources: sources, selection: selection, primaryOrgId: nil).options
                    .map { FilterMenuOverlay.Option(id: $0.id, label: $0.name) },
                selectionMode: .single,
                selectedIDs: Self.uploadTargets(sources: sources, selection: selection, primaryOrgId: nil).preselected.map { [$0] } ?? [],
                onSelect: { option in
                    openMenu = nil
                    uploadOrgId = option.id
                    uploadPickerOpen = true
                },
                onClose: { openMenu = nil })
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
            let outcome = await actions.loadAllMedia(pageSize: Self.pageSize, resumeCursor: resume)
            // A cancelled load (a newer one, or the section left) leaves the flags to whoever replaced it.
            guard !Task.isCancelled else { return }
            isLoading = false
            refreshing = false
            failed = outcome == .failed
            // A successful pull forgets failed tile URLs, so a transient outage doesn't blank them for the session.
            if refresh, outcome == .completed { tileImages.clearFailures() }
            if refresh, outcome == .failed {
                // D13: the pull is the leader's own action, so it surfaces. loadAllMedia already logged the real cause
                // console-only and returns no error, so the banner carries this stand-in (a second, surfaced record).
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

    /// D18: the reported range at the current level; a newer request replaces the older one.
    private func requestImages(tiles: [MediaHomeMapper.Tile]) {
        guard gridWidth > 0 else { return }
        let columns = CGFloat(level.columns)
        let side = (gridWidth - (columns - 1) * level.gutter) / columns
        let images = tileImages
        let build = { [range = gridBox.visibleRange, medium = Self.usesMedium(level), scale = displayScale] in
            Self.imageRequests(tiles: tiles, range: range, medium: medium, tileSide: side, scale: scale, failed: images.hasFailed)
        }
        imageTask?.cancel()
        imageTask = Task { @MainActor in await Self.loadImages(into: images, requests: build) }
    }

    /// D10/D18: loads `requests()`, then rebuilds them once — a `-md` that failed is followed by its thumb
    /// (MediaTileImages doesn't bump `generation` on a failure, so nothing else would ask again).
    static func loadImages(into images: MediaTileImages, requests: () -> [MediaTileImages.Request]) async {
        let first = requests()
        await images.load(first)
        guard !Task.isCancelled else { return }
        let fallbacks = requests()
        if fallbacks != first { await images.load(fallbacks) }
    }

    /// media-library D8/D13: the TopNav `add` — straight to Photos for one org, the Upload-to menu for
    /// several, a banner when the leader can upload nowhere.
    private func beginUpload() {
        guard mode == .browse else { return }
        let app = AppState.shared
        let targets = Self.uploadTargets(sources: app.mediaSources, selection: selection, primaryOrgId: app.organizationId)
        if let direct = targets.direct {
            uploadOrgId = direct
            uploadPickerOpen = true
        } else if targets.options.isEmpty {
            app.recordError(APIError.serverError("No organization accepts uploads"), context: "MediaHomeContainer.upload",
                            surface: true, friendlyMessage: "You can't upload media in this organization")
        } else {
            openMenu = .uploadTo
        }
    }

    /// media-library D13: reads each pick (photo bytes, or a video file) and hands them to AppState's queue.
    @MainActor
    private func enqueueUploads(_ picks: [PhotosPickerItem], orgId: String) async {
        var items: [PickedMedia] = []
        for pick in picks {
            do {
                if pick.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    if let movie = try await pick.loadTransferable(type: PickedMovie.self) { items.append(.video(movie.url)) }
                } else if let data = try await pick.loadTransferable(type: Data.self),
                          let image = CoverImageRendering.uprightDownsampled(data) {
                    items.append(.photo(image, data: data))
                }
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                AppState.shared.recordError(error, context: "MediaHomeContainer.readPick", surface: true,
                                            friendlyMessage: "Couldn't read that item")
            }
        }
        let user = authManager.currentUser
        AppState.shared.mediaUploads.enqueue(items, orgId: orgId, uploader: user.map { MediaUploader(id: $0.id, name: $0.name) },
                                             state: AppState.shared)
    }

    /// media-library D9: frame the tapped photo as `owner`'s cover; the picker page is replaced by the
    /// Edit cover page. A photo that won't load leaves the picker up with a banner.
    private func pick(id: String, owner: CoverOwner) {
        guard !picking, let item = AppState.shared.mediaLibrary[id], let url = URL(string: item.url) else { return }
        picking = true
        Task { @MainActor in
            defer { picking = false }
            do {
                let image = try await UI2ImageLoader.live(url, CoverImageRendering.originalMaxPixels)
                navigator.replaceTop(.chooseCoverFromLibrary(owner: owner),
                                     owner.destination(.newPick(image, takenAt: nil, sourceMediaId: item.id)))
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                AppState.shared.recordError(error, context: "MediaHomeContainer.pick", surface: true,
                                            friendlyMessage: "Couldn't open that photo")
            }
        }
    }

    /// D12 → media-viewer-paging: opens the viewer on the tapped tile over the frozen tile list, so a
    /// swipe pages through the grid's own order.
    private func open(id: String, frame: CGRect, tiles: [MediaHomeMapper.Tile]) {
        guard viewer == nil, let index = Self.index(ofTileID: id, in: tiles), tiles.indices.contains(index) else { return }
        frozenTiles = tiles
        viewer = Viewer(index: index, frame: frame, current: index)
    }

    /// D12: the tile's loaded image — its `-md` at the levels that use it, else its thumb.
    private func tilePlaceholder(_ tile: MediaHomeMapper.Tile) -> UIImage? {
        Self.tileURL(tile, medium: Self.usesMedium(level), failed: tileImages.hasFailed).flatMap(tileImages.image(for:))
            ?? tile.thumbURL.flatMap(tileImages.image(for:))
    }

    // GAP — media-home §2: "108 pt is its height in every state except the failed notice"; the top bar
    // isn't reported, so the grid's band starts this far below the screen's top.
    static let topBarHeight: CGFloat = 108

    /// The part of the screen the grid shows (the grid runs to the screen bottom, under the TabBar layer).
    static func gridBand(screen: CGRect) -> CGRect {
        CGRect(x: screen.minX, y: screen.minY + topBarHeight, width: screen.width, height: max(0, screen.height - topBarHeight))
    }

    /// media-viewer-paging: where item `index`'s tile sits while the viewer is up. The grid is frozen,
    /// so it is the opened tile's frame moved by whole columns and rows; nil when it isn't wholly in
    /// `visible`, and the viewer then leaves off the bottom.
    static func tileFrame(index: Int, openedIndex: Int, openedFrame: CGRect, level: MediaBrowser.Level,
                          gridWidth: CGFloat, visible: CGRect) -> CGRect? {
        if index == openedIndex { return openedFrame }
        let columns = level.columns
        guard columns > 0, gridWidth > 0 else { return nil }
        let side = (gridWidth - CGFloat(columns - 1) * level.gutter) / CGFloat(columns)
        let pitch = side + level.gutter
        let dx = CGFloat(index % columns - openedIndex % columns) * pitch
        let dy = CGFloat(index / columns - openedIndex / columns) * pitch
        let frame = openedFrame.offsetBy(dx: dx, dy: dy)
        return visible.contains(frame) ? frame : nil
    }
}

/// The grid's last reported prefetch range and its global frame; a class so writing them re-renders nothing.
private final class MediaGridBox {
    var visibleRange: Range<Int> = 0..<0
    var frame: CGRect = .zero
}

/// Reads `MediaTileImages.generation` in its own body, so a landed tile image re-renders only the
/// screen it wraps — never the container's mapper pass over the whole library (D15).
private struct MediaImageGenerationReader<Content: View>: View {
    let images: MediaTileImages
    @ViewBuilder let content: (Int) -> Content

    var body: some View { content(images.generation) }
}

/// media-library D13: a picked video, copied out of the picker's temporary file so the upload queue can
/// read it after the picker has gone.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("media-upload-\(UUID().uuidString).\(received.file.pathExtension)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
