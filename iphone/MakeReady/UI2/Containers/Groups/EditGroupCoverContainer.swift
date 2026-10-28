import SwiftUI

/// group-cover-image D4/D6/D7/D13/D26/D28/D30: wires the d2m-built Edit cover screen
/// (`EditCoverScreen`) to `ImageFramingModel`. A new pick opens at once; a stored cover loads its
/// original (`coverOriginalUrl ?? coverImageUrl`) first. The model is built once both the image and
/// the screen's frame rect (`onFrameLayout`) are known, so its `frameSize` is the frame the canvas
/// really draws. Cancel or an edge swipe with a change asks to discard (D26), else pops. Done saves
/// → D13: pop on success (AppState + the image cache already updated), 404 → back to Groups,
/// 401 → sign-out, anything else → the surfaced banner with the page kept.
struct EditGroupCoverContainer: View {
    let groupId: String
    let source: ImageEditSource

    enum Route: Equatable { case pop, popToRoot, signOut, banner, stay }
    /// D26: what Cancel does.
    enum CancelAction: Equatable { case confirmDiscard, pop, ignore }

    /// group-cover-image D20 — image-framing-editor D1: the cover's frame is 16:9; the shared editor
    /// takes it as an input, and no other 16:9 constant remains.
    static let frameAspect: CGFloat = 16.0 / 9.0
    /// image-framing-editor D9: the generalised screen's title for the group cover.
    static let title = "Edit cover"
    /// group-cover-image D12/D20: the rendered cover, 1200×675.
    static let renderSize = CGSize(width: 1200, height: 675)
    /// group-cover-image D13: the banner a failed save shows.
    static let saveFailedMessage = "Couldn't save the cover"
    /// The canvas's accessibility label.
    static let canvasLabel = "Cover framing"

    /// group-cover-image D7: Edit image reopens the original at its framing; a cover with no original
    /// opens the cover itself at identity; no cover → nil (the menu is not offered then, D2).
    /// `hasOriginal` is false for the cover fallback: the caller passes it on as `hasStoredOriginal`.
    static func opening(group: UserGroup) -> (url: String, framing: ImageFraming, hasOriginal: Bool)? {
        if let original = group.coverOriginalUrl, !original.isEmpty {
            return (original, group.coverFraming ?? .identity, true)
        }
        if let cover = group.coverImageUrl, !cover.isEmpty { return (cover, .identity, false) }
        return nil
    }

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D26: this page's veto on the shell's edge swipe.
    @Environment(\.ui2BackSwipeGuard) private var backSwipe
    /// The photo to frame and where it opens — set once it is in hand (D6 at once, D7 after a load).
    @State private var opening: Opening?
    /// The screen's frame rect, in the canvas slot's coordinates (`onFrameLayout`).
    @State private var frameRect: CGRect = .zero
    @State private var model: ImageFramingModel?
    /// D26: the C-066 "Discard changes" confirmation is up.
    @State private var discardMenuOpen = false

    private struct Opening {
        let image: UIImage
        let framing: ImageFraming
        let isNewPick: Bool
        let hasStoredOriginal: Bool
    }

    /// Cache-first: a new pick, or a stored original already in Ui2ImageCache, is in hand before the
    /// push animates in; only an uncached original waits for `prepare()`.
    init(groupId: String, source: ImageEditSource) {
        self.groupId = groupId
        self.source = source
        _opening = State(initialValue: Self.immediateOpening(groupId: groupId, source: source))
    }

    @MainActor
    private static func immediateOpening(groupId: String, source: ImageEditSource) -> Opening? {
        switch source {
        case let .newPick(image):
            // D6 at the floor, centred; the pick itself is uploaded as the original.
            return Opening(image: image, framing: .identity, isNewPick: true, hasStoredOriginal: true)
        case .stored:
            guard let group = AppState.shared.groups[groupId],
                  let stored = Self.opening(group: group),
                  let url = URL(string: stored.url),
                  let image = Ui2ImageCache.shared.image(for: url) else { return nil }
            return Opening(image: image, framing: stored.framing, isNewPick: false, hasStoredOriginal: stored.hasOriginal)
        }
    }

    static func route(_ outcome: ImageFramingModel.SaveOutcome) -> Route {
        switch outcome {
        case .saved: return .pop
        case .gone: return .popToRoot
        case .unauthorized: return .signOut
        case .failed: return .banner
        case .forbidden: return .banner   // image-framing-editor D12: a 403 shows the banner, as before
        case .ignored: return .stay
        }
    }

    /// D26: any framing change, or a new pick, asks before discarding. D13: while a save is in
    /// flight Cancel does nothing — a pop now would leave the POST to change the cover after the
    /// leader chose to leave.
    static func cancelAction(hasChanges: Bool, isSaving: Bool) -> CancelAction {
        if isSaving { return .ignore }
        return hasChanges ? .confirmDiscard : .pop
    }

    /// D26/D13: the edge swipe is vetoed while there is a change to discard or a save in flight.
    /// A vetoed swipe opens the discard menu as Cancel does, or nothing while saving.
    static func blocksBackSwipe(hasChanges: Bool, isSaving: Bool) -> Bool {
        hasChanges || isSaving
    }

    /// D13: the discard row pops only when no save is in flight.
    static func discardPops(isSaving: Bool) -> Bool {
        !isSaving
    }

    /// D28/D30: the screen's inputs. The grid shows during any gesture, the readout only while
    /// twisting or turning the dial; Done mirrors `hasChanges`. No model yet (loading) → a still,
    /// unsavable page.
    @MainActor
    static func screenState<Canvas: View>(_ model: ImageFramingModel?) -> EditCoverScreen<Canvas>.State {
        guard let model else {
            return .init(showsGrid: false, readoutDegrees: nil, rotationDegrees: 0, saving: false, doneEnabled: false)
        }
        return .init(showsGrid: model.isGestureActive,
                     readoutDegrees: model.isTwisting ? model.readoutDegrees : nil,
                     rotationDegrees: model.framing.rotation,
                     saving: model.isSaving,
                     doneEnabled: model.hasChanges)
    }

    /// D26, owner 2026-10-27: the confirmation's main button (Done secondary below it); the avatar shares it.
    static let discardLabel = "Discard changes"

    /// D7: the banner a stored original that will not load shows; the page pops.
    static let loadFailedMessage = "Couldn't load the cover"

    var body: some View {
        EditCoverScreen(
            state: Self.screenState(model),
            aspect: Self.frameAspect,
            mask: .rectangle,
            title: Self.title,
            canvas: { canvas },
            onFrameLayout: { rect in
                frameRect = rect
                makeModelIfReady()
            },
            onCancel: cancel,
            onDone: { Task { await save() } },
            onFlip: { model?.flip() },
            onRotate90: { model?.rotate90() },
            onStraighten: { model?.straighten(to: $0) },
            onStraightenEnd: {
                guard let model else { return }
                withAnimation(ImageFramingCanvas.settle) { model.endStraighten() }
            }
        )
        .background(Token.layoutBackground.ignoresSafeArea())
        // D26, owner 2026-10-27: "Discard changes" as the main button, Done (stays) below it.
        // Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [],
                onDone: { discardMenuOpen = false },
                confirmLabel: Self.discardLabel,
                onConfirm: {
                    discardMenuOpen = false
                    guard Self.discardPops(isSaving: model?.isSaving ?? false) else { return }
                    navigator.pop()
                }
            )
        }
        .task { await prepare() }
    }

    @ViewBuilder private var canvas: some View {
        if let model {
            ImageFramingCanvas(model: model, frame: frameRect, accessibilityLabel: Self.canvasLabel)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cancel() {
        switch Self.cancelAction(hasChanges: model?.hasChanges ?? false, isSaving: model?.isSaving ?? false) {
        case .pop: navigator.pop()
        case .confirmDiscard: discardMenuOpen = true
        case .ignore: break
        }
    }

    /// The model is built once, from the first laid-out frame that has a size.
    private func makeModelIfReady() {
        guard model == nil, let opening, frameRect.width > 0, frameRect.height > 0 else { return }
        let save: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String = { [groupId] rendered, framing, original in
            try await GroupActions().saveCover(groupId: groupId, rendered: rendered, framing: framing, original: original).coverImageUrl
        }
        let built = ImageFramingModel(image: opening.image, framing: opening.framing,
                                      isNewPick: opening.isNewPick, hasStoredOriginal: opening.hasStoredOriginal,
                                      frameSize: frameRect.size, outputSize: Self.renderSize,
                                      saveFailedMessage: Self.saveFailedMessage, save: save)
        model = built
        // D26: an edge swipe with a change does not pop; it asks to discard, as Cancel does.
        // D13: while saving it neither pops nor asks.
        backSwipe?.blocksBackSwipe = { [weak built] in
            Self.blocksBackSwipe(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
        }
        backSwipe?.onBlockedBackSwipe = { [weak built] in
            let action = Self.cancelAction(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
            if action == .confirmDiscard { discardMenuOpen = true }
        }
    }

    @MainActor
    private func prepare() async {
        // A new pick and a cached original were set in `init`; this loads an uncached original (D7).
        guard opening == nil else { return }
        // Pops only this page: the leader may already have left it (Cancel pops at once while loading).
        let leave = { navigator.popIfTop(.editGroupCover(groupId: groupId, source: source)) }
        guard let group = AppState.shared.groups[groupId],
              let stored = Self.opening(group: group) else { leave(); return }
        _ = await MemberProfileContainer.seedCovers([stored.url])
        // Silent: the page was closed during the load — no banner for a page that is gone.
        guard !Task.isCancelled else { return }
        guard let opened = Self.immediateOpening(groupId: groupId, source: source) else {
            AppState.shared.recordError(APIError.invalidResponse, context: "EditGroupCoverContainer.loadOriginal",
                                        surface: true, friendlyMessage: Self.loadFailedMessage)
            leave()
            return
        }
        opening = opened
        makeModelIfReady()
    }

    @MainActor
    private func save() async {
        guard let model else { return }
        let outcome = await model.save()
        switch Self.route(outcome) {
        case .pop: navigator.popIfTop(.editGroupCover(groupId: groupId, source: source))
        case .popToRoot: navigator.popTo(0)
        case .signOut:
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EditGroupCoverContainer.signOut", surface: false)
            }
        case .banner:
            // D13: the friendly text is the model's; a 403 (image-framing-editor D12) carries no server text of its own.
            let message: String
            if case let .failed(text) = outcome { message = text } else { message = model.saveFailedMessage }
            AppState.shared.recordError(APIError.serverError(message), context: "EditGroupCoverContainer.save", surface: true,
                                        friendlyMessage: model.saveFailedMessage,
                                        retry: { Task { await save() } })
        case .stay: break
        }
    }
}
