import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// text-activity D9/D10/D12/D22–D25/D39: the `.activityViewer` destination — the full-screen viewer
/// on one lesson version, opened from the editor on its current activity (D22).
///
/// It loads `GET /api/lesson-versions/:id`, owns the `ViewerEngine`, and drives it from one
/// `UIPanGestureRecognizer` and a `CADisplayLink`; `ActivitiesPlayerScreen` draws the positions it
/// reads (D10). It hosts the video players and the YouTube player in the screen's slots (D24), holds
/// the rail's visibility (D12) and the preview-only action sheet's draft (D9). Nothing it does writes
/// progress or a response (D9, D25). Close returns to the editor (D22, D23).
struct ActivityViewerContainer: View {
    let lessonVersionId: String
    let activityId: String

    static let loadContext = "ActivityViewerContainer.load"

    @Environment(\.ui2Navigator) private var navigator
    @Environment(\.openURL) private var openURL
    @State private var model: Model

    init(lessonVersionId: String, activityId: String) {
        self.lessonVersionId = lessonVersionId
        self.activityId = activityId
        _model = State(initialValue: Model(lessonVersionId: lessonVersionId, activityId: activityId))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let insets = Self.viewerInsets(proxy: proxy.safeAreaInsets, window: Self.windowSafeAreaInsets)
            ActivitiesPlayerScreen(
                state: model.screenState(width: Double(size.width), insets: insets),
                videoSlot: { index in model.videoSlot(index) },
                youtubeSlot: { index in model.youtubeSlot(index) },
                onClose: { close() },
                // OQ-004: shown per the document, inert in this build.
                onShare: {},
                onMenu: {},
                onOpenSheet: { id in model.openSheet(id) },
                onOpenURL: { open($0) },
                onOpenLink: { open($0) },
                onVideoProgressChange: { index, fraction in model.video.seek(index, fraction: fraction) },
                onVideoScrubbingChange: { _, _ in },
                onVideoPlayingChange: { index, playing in model.leaderSetPlaying(index, playing) },
                onCloseSheet: { model.sheet = nil },
                onSheetTitleChange: { model.sheet?.title = $0 },
                onSheetBodyTextChange: { model.sheet?.body = $0 },
                onLoadFailed: { Self.surfaceLoadFailure($0) }
            )
            // The viewer's canvases take no hits (C-091 `.viewer`), so without a shape the pan never sees a touch.
            .contentShape(Rectangle())
            .gesture(ViewerPan(
                mayBegin: { point, velocity in model.panMayBegin(at: point, velocity: velocity) },
                onTouchDown: { model.touchDown() },
                onTouchUpWithoutPan: { model.touchUpWithoutPan() },
                onMove: { dy in model.panMoved(dy) },
                onEnd: { velocity in model.panEnded(velocity: velocity) }
            ))
            .onAppear { model.layout(size: size, insets: insets) }
            .onChange(of: size) { model.layout(size: size, insets: insets) }
            .onChange(of: model.activeVideoPlaying) { model.activePlaybackChanged() }
        }
        .ignoresSafeArea()
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await model.load() }
        .onDisappear { model.stop() }
    }

    /// The insets the chrome, the rail and the bottom controls clear. This view ignores the safe area, so its
    /// own proxy reads 0 on every edge; the window's insets are the device's (agent walk round 1: Close was
    /// drawn under the status bar). Each edge takes the larger of the two.
    static func viewerInsets(proxy: EdgeInsets, window: UIEdgeInsets?) -> EdgeInsets {
        guard let window else { return proxy }
        return EdgeInsets(top: max(proxy.top, window.top), leading: max(proxy.leading, window.left),
                          bottom: max(proxy.bottom, window.bottom), trailing: max(proxy.trailing, window.right))
    }

    private static var windowSafeAreaInsets: UIEdgeInsets? {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.safeAreaInsets
    }

    private func close() {
        model.stop()
        navigator.popIfTop(.activityViewer(lessonVersionId: lessonVersionId, activityId: activityId))
    }

    /// An `openUrl` action or a link mark: web links only.
    private func open(_ link: String) {
        guard let url = URL(string: link), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        openURL(url)
    }

    /// D33 item 4 (/ios-error-surface): the leader opened the viewer, so its load failure is a banner.
    @MainActor
    static func surfaceLoadFailure(_ message: String) {
        AppState.shared.recordError(LoadFailed(), context: loadContext, surface: true, friendlyMessage: message)
    }

    private struct LoadFailed: Error {}

    // MARK: - Model

    /// The engine, the hosts and the viewer's ephemeral presentation state.
    @MainActor
    @Observable
    final class Model {
        enum Phase { case loading, ready, failed }

        /// C-137's draft: the sheet's kind and its editable fields, discarded on close (D9).
        struct Sheet: Equatable {
            var kind: String
            var title: String
            var body: String
            var prompt: String
        }

        /// 01 §8: a playing video's rail fades 1.5 s after the stack settles; the morph runs 150 ms.
        static let railHideDelay = Duration.milliseconds(1500)
        static let morphDuration = 0.15
        /// C-135's control row (scrubber and play) claims its touch: `bottomInset` + 44 above the bottom.
        static let videoControlsBand: CGFloat = 44

        let lessonVersionId: String
        let activityId: String
        private(set) var phase: Phase = .loading
        private(set) var engine: ViewerEngine?
        private(set) var railVisible = true
        private(set) var morph: Double = 0
        private(set) var animationStart: Date?
        var sheet: Sheet?
        let video = ViewerVideoHost()

        @ObservationIgnored private var size: CGSize = .zero
        @ObservationIgnored private var bottomInset: CGFloat = 0
        @ObservationIgnored private let clock = ViewerClock()
        @ObservationIgnored private var railHideTask: Task<Void, Never>?
        @ObservationIgnored private var morphElapsed: Double = 0
        @ObservationIgnored private var morphFrom: Double = 0
        @ObservationIgnored private var lastSettled: Int?
        @ObservationIgnored private var hasLoaded = false
        /// The page the rail's capsule is travelling to.
        @ObservationIgnored private var railPage = 0

        init(lessonVersionId: String, activityId: String) {
            self.lessonVersionId = lessonVersionId
            self.activityId = activityId
            clock.onTick = { [weak self] dt in self?.tick(dt: dt) }
            // B2a: a cached version shows from the first frame; `layout` then builds the engine.
            if payload != nil { phase = .ready }
        }

        /// The loaded version, read from the store (the Action wrote it there).
        var payload: LessonVersionPayload? {
            let app = AppState.shared
            guard let version = app.lessonVersions[lessonVersionId] else { return nil }
            return LessonVersionPayload(version: version, activities: app.activities(forVersion: lessonVersionId),
                                        media: app.mediaMap)
        }

        /// Whether the active page's video is playing (the rail's fade rule watches it).
        var activeVideoPlaying: Bool {
            guard let engine else { return false }
            return video.videos[engine.activePage]?.playing ?? false
        }

        // MARK: Load

        /// Cache-first (SWIFTUI_TRANSITIONS § Pre-loading Content): the editor's draft is usually in the
        /// store already, so the pages are there as the push animates; the GET then refreshes it. Only
        /// a load with nothing to show is the Load-failed state.
        func load() async {
            guard !hasLoaded else { return }
            hasLoaded = true
            let cachedPages = phase == .ready ? payload.map { ActivityViewerMapper.pages($0).count } : nil
            do {
                try await ActivityActions().loadVersion(id: lessonVersionId)
                phase = .ready
                // A version that changed shape under the cache rebuilds on the page that was active.
                if engine == nil || payload.map({ ActivityViewerMapper.pages($0).count }) != cachedPages { start() }
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                // Console record of the cause; with nothing cached the screen raises the banner
                // (§3 Load failed), then pops.
                AppState.shared.recordError(error, context: ActivityViewerContainer.loadContext)
                if cachedPages == nil { phase = .failed }
            }
        }

        /// The viewport, measured. A new size rebuilds the engine on the page that was active.
        func layout(size: CGSize, insets: EdgeInsets) {
            bottomInset = insets.bottom
            guard size.width > 0, size.height > 0, size != self.size else { return }
            self.size = size
            start()
        }

        /// Builds the engine once both the version and the viewport are known: the activities plus
        /// the completion page, opening on `activityId`'s page (D22, D23).
        private func start() {
            guard phase == .ready, size.width > 0, let payload else { return }
            let heights = ActivityViewerMapper.pageHeights(payload, size: size)
            let anchor = min(engine?.activePage ?? ActivityViewerMapper.pageIndex(of: activityId, in: payload),
                             heights.count - 1)
            engine = ViewerEngine(viewportHeight: Double(size.height), pageHeights: heights, anchor: anchor)
            railPage = anchor
            morph = 0
            mountVideos()
            video.activate(anchor)
            settled(on: anchor)
        }

        func stop() {
            clock.stop()
            railHideTask?.cancel()
            video.stop()
        }

        // MARK: Screen state

        func screenState(width: Double, insets: EdgeInsets) -> ActivitiesPlayerScreen.State {
            var state: ActivitiesPlayerScreen.State
            if let engine, let payload, phase == .ready {
                let playback = ActivityViewerMapper.Playback(videos: video.videos, railVisible: railVisible, morph: morph)
                state = ActivityViewerMapper.state(payload: payload, engine: engine, viewport: width, playback: playback)
                state.animationStart = animationStart
                if let sheet {
                    state.sheetKind = sheet.kind
                    state.sheetTitle = sheet.title
                    state.sheetBodyText = sheet.body
                    state.sheetPrompt = sheet.prompt
                }
            } else {
                state = ActivityViewerMapper.emptyState(loadFailed: phase == .failed)
            }
            state.topInset = insets.top
            state.bottomInset = insets.bottom
            return state
        }

        func videoSlot(_ index: Int) -> AnyView {
            guard let player = video.player(for: index) else { return ActivitiesPlayerScreen.slotStandIn }
            return AnyView(ViewerVideoLayer(player: player))
        }

        func youtubeSlot(_ index: Int) -> AnyView {
            guard let payload, let engine, let content = ActivityViewerMapper.youtube(at: index, in: payload) else {
                return ActivitiesPlayerScreen.slotStandIn
            }
            return AnyView(ViewerYouTubeHost(videoId: content.youtubeVideoId, startSeconds: content.startSeconds,
                                             endSeconds: content.endSeconds, active: index == engine.activePage))
        }

        // MARK: Touch (01 §5–§6)

        /// A vertical drag, with no sheet open, that doesn't start on a video page's control row.
        func panMayBegin(at point: CGPoint, velocity: CGPoint) -> Bool {
            guard let engine, sheet == nil, abs(velocity.y) > abs(velocity.x) else { return false }
            if let payload, ActivityViewerMapper.isVideoPage(engine.activePage, in: payload),
               point.y > size.height - bottomInset - Self.videoControlsBand {
                return false
            }
            return true
        }

        /// A finger lands: a settle in flight stops under it (01 §6).
        func touchDown() {
            engine?.touchBegan()
        }

        /// A touch that never became a pan (a tap, or a drag a control claimed) lets go where it is.
        func touchUpWithoutPan() {
            guard engine != nil else { return }
            handle(engine?.touchEnded(velocity: 0) ?? [])
            runClockIfNeeded()
        }

        func panMoved(_ dy: Double) {
            guard engine != nil else { return }
            let outputs = engine?.touchMoved(dy: dy) ?? []
            if engine?.owner == .pager { showRail() }
            handle(outputs)
        }

        func panEnded(velocity: Double) {
            guard engine != nil else { return }
            handle(engine?.touchEnded(velocity: velocity) ?? [])
            runClockIfNeeded()
        }

        // MARK: Clock

        private func tick(dt: Double) {
            if engine?.settle != nil { showRail() }
            handle(engine?.tick(dt: dt) ?? [])
            if morph != 0 {
                morphElapsed += dt
                let remaining = max(0, 1 - morphElapsed / Self.morphDuration)
                morph = morphFrom * remaining
            }
            if !needsClock { clock.stop() }
        }

        private var needsClock: Bool {
            guard let engine else { return false }
            return engine.settle != nil || engine.momentum != 0 || morph != 0
        }

        private func runClockIfNeeded() {
            if needsClock { clock.start() }
        }

        // MARK: Engine outputs

        private func handle(_ outputs: [ViewerEngine.Output]) {
            for output in outputs {
                switch output {
                case .activeChanged(let page):
                    // 01 §7: video plays or pauses, the top action swaps and the capsule moves, at once.
                    // C-133: the capsule starts where it was drawn and travels to the new page.
                    let drawnAt = Double(railPage) - morph
                    railPage = page
                    morphFrom = min(1, max(-1, Double(page) - drawnAt))
                    morphElapsed = 0
                    morph = morphFrom
                    mountVideos()
                    video.activate(page)
                case .settled(let page):
                    settled(on: page)
                case .commitStarted:
                    break
                }
            }
            runClockIfNeeded()
        }

        /// A settle landed: the page's text animations start, and a playing video's rail may fade.
        private func settled(on page: Int) {
            if lastSettled != page {
                lastSettled = page
                animationStart = Date()
            }
            scheduleRailHide()
        }

        /// The active page ±1's video streams.
        private func mountVideos() {
            guard let engine, let payload else { return }
            let mounted = Set(ActivityViewerMapper.mountedPages(active: engine.activePage, count: engine.pageHeights.count))
            video.mount(ActivityViewerMapper.videoSources(payload).filter { mounted.contains($0.key) })
        }

        // MARK: Rail (01 §8, D12)

        /// Movement shows the rail (C-133 fades it in over 0.1 s).
        private func showRail() {
            railHideTask?.cancel()
            railHideTask = nil
            if !railVisible { railVisible = true }
        }

        /// At rest on a playing video, the rail fades 1.5 s later (C-133 fades it out over 0.3 s).
        private func scheduleRailHide() {
            railHideTask?.cancel()
            railHideTask = nil
            guard activeVideoPlaying else {
                if !railVisible { railVisible = true }
                return
            }
            railHideTask = Task { [weak self] in
                try? await Task.sleep(for: Self.railHideDelay)
                guard let self, !Task.isCancelled, self.activeVideoPlaying, self.engine?.settle == nil,
                      self.engine?.drag == 0 else { return }
                self.railVisible = false
            }
        }

        /// The active video started or stopped playing (autoplay, the leader, or its end).
        func activePlaybackChanged() {
            guard engine?.settle == nil, engine?.drag == 0 else { return }
            scheduleRailHide()
        }

        func leaderSetPlaying(_ page: Int, _ playing: Bool) {
            video.setPlaying(page, playing)
        }

        // MARK: Sheet (D9)

        /// An `addToPrayerList` or `write` action on the active page opens C-137 with its prefill;
        /// its Save is disabled and labelled "Preview", and closing discards the draft.
        func openSheet(_ actionId: String) {
            guard let engine, let payload,
                  let action = ActivityViewerMapper.action(actionId, onPage: engine.activePage, in: payload) else { return }
            switch action.kind {
            case .addToPrayerList:
                sheet = Sheet(kind: action.kind.rawValue, title: ActivityViewerMapper.payloadString(action, "title"),
                              body: ActivityViewerMapper.payloadString(action, "body"), prompt: "")
            case .write:
                sheet = Sheet(kind: action.kind.rawValue, title: "", body: "",
                              prompt: ActivityViewerMapper.payloadString(action, "prompt"))
            case .openUrl, .nextLesson:
                break
            }
        }
    }
}

// MARK: - The display link

/// D10: the engine's clock — runs only while a settle, scroll momentum or the rail's morph is moving.
@MainActor
final class ViewerClock: NSObject {
    var onTick: (Double) -> Void = { _ in }
    private var link: CADisplayLink?
    private var last: CFTimeInterval?

    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        last = nil
    }

    /// Stopping releases the link, which retains its target.
    func stop() {
        link?.invalidate()
        link = nil
        last = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let dt = last.map { link.timestamp - $0 } ?? link.duration
        last = link.timestamp
        onTick(dt)
    }
}

// MARK: - The pan

/// D10: the viewer's one pan. Its distances and velocity are reported in the engine's reading
/// direction (a finger moving up is positive). A touch-down is reported before the pan begins, so a
/// settle stops under a resting finger (01 §6); a touch that never pans reports its lift.
struct ViewerPan: UIGestureRecognizerRepresentable {
    let mayBegin: (CGPoint, CGPoint) -> Bool
    let onTouchDown: () -> Void
    let onTouchUpWithoutPan: () -> Void
    let onMove: (Double) -> Void
    let onEnd: (Double) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator(pan: self) }

    func makeUIGestureRecognizer(context: Context) -> ViewerPanRecognizer {
        let recognizer = ViewerPanRecognizer()
        recognizer.maximumNumberOfTouches = 1
        recognizer.delegate = context.coordinator
        recognizer.coordinator = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: ViewerPanRecognizer, context: Context) {
        context.coordinator.pan = self
    }

    func handleUIGestureRecognizerAction(_ recognizer: ViewerPanRecognizer, context: Context) {
        let coordinator = context.coordinator
        let translation = recognizer.translation(in: nil).y
        switch recognizer.state {
        case .began:
            recognizer.panned = true
            coordinator.lastTranslation = 0
            fallthrough
        case .changed:
            let dy = -(translation - coordinator.lastTranslation)
            coordinator.lastTranslation = translation
            onMove(Double(dy))
        case .ended, .cancelled, .failed:
            onEnd(Double(-recognizer.velocity(in: nil).y))
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var pan: ViewerPan
        var lastTranslation: CGFloat = 0

        init(pan: ViewerPan) { self.pan = pan }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            return pan.mayBegin(recognizer.location(in: nil), recognizer.velocity(in: nil))
        }
    }
}

final class ViewerPanRecognizer: UIPanGestureRecognizer {
    weak var coordinator: ViewerPan.Coordinator?
    /// Whether this touch sequence became a pan.
    var panned = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        let first = state == .possible && !panned && (event.allTouches?.count ?? 1) == touches.count
        super.touchesBegan(touches, with: event)
        if first { coordinator?.pan.onTouchDown() }
    }

    override func reset() {
        if !panned { coordinator?.pan.onTouchUpWithoutPan() }
        panned = false
        super.reset()
    }
}
