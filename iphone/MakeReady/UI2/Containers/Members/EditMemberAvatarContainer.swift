import SwiftUI

/// image-framing-editor D3/D5/D9/D12: Edit photo — the generalised d2m `edit-cover` screen at 1:1
/// with the round guide, wired to the shared `ImageFramingModel` (D1). A new pick opens at once; a
/// stored avatar loads its original (`profilePictureOriginalUrl`, else `profilePicture` at identity —
/// D5) first. The model is built once both the image and the screen's frame rect are known, so its
/// `frameSize` is the frame the canvas really draws. Cancel or an edge swipe with a change asks to
/// discard (C-066 "Discard changes" + Done), else pops. Done saves → D12: pop on success (AppState
/// and the image cache already updated), 403/404 → pop to the profile, 401 → sign-out, anything
/// else → the surfaced banner with the page kept. The chrome rules are the group cover's
/// (`EditGroupCoverContainer`, group-cover-image D13/D26/D28/D30) — one copy.
struct EditMemberAvatarContainer: View {
    let memberId: String
    let source: ImageEditSource

    enum Route: Equatable { case pop, signOut, banner, stay }

    /// D3/D9: the frame is square; the screen dims outside the circle inscribed in it.
    static let frameAspect: CGFloat = 1
    /// D7: the rendered avatar, 512×512 (the server keeps its 512px WebP re-encode).
    static let renderSize = CGSize(width: 512, height: 512)
    /// D9: the screen's title.
    static let title = "Edit photo"
    /// D12: the banner a failed save shows.
    static let saveFailedMessage = "Couldn't save the photo"
    /// D17: Auto on a face frames head and shoulders — the face box spans half the frame.
    static let autoFaceFill = 0.5
    /// D5: the banner a stored photo that will not load shows; the page pops.
    static let loadFailedMessage = "Couldn't load the photo"
    /// The canvas's accessibility label.
    static let canvasLabel = "Photo framing"

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D12: this page's veto on the shell's edge swipe.
    @Environment(\.ui2BackSwipeGuard) private var backSwipe
    /// The photo to frame and where it opens — set once it is in hand.
    @State private var opening: Opening?
    /// The screen's frame rect, in the canvas slot's coordinates (`onFrameLayout`).
    @State private var frameRect: CGRect = .zero
    @State private var model: ImageFramingModel?
    /// D12: the C-066 "Discard changes" confirmation is up.
    @State private var discardMenuOpen = false

    private struct Opening {
        let image: UIImage
        let framing: ImageFraming
        let isNewPick: Bool
        let hasStoredOriginal: Bool
    }

    /// Cache-first: a new pick, or a stored photo already in Ui2ImageCache, is in hand before the
    /// push animates in; only an uncached one waits for `prepare()`.
    init(memberId: String, source: ImageEditSource) {
        self.memberId = memberId
        self.source = source
        _opening = State(initialValue: Self.immediateOpening(memberId: memberId, source: source))
    }

    /// D5: the stored original at its framing; no original → the avatar itself at identity
    /// (`hasOriginal` false, so the first save stores it as the original); no avatar → nil.
    static func opening(detail: MemberDetail) -> (url: String, framing: ImageFraming, hasOriginal: Bool)? {
        if let original = detail.profilePictureOriginalUrl, !original.isEmpty {
            return (original, detail.profilePictureFraming ?? .identity, true)
        }
        if let avatar = detail.profilePicture, !avatar.isEmpty { return (avatar, .identity, false) }
        return nil
    }

    @MainActor
    private static func immediateOpening(memberId: String, source: ImageEditSource) -> Opening? {
        switch source {
        case let .newPick(image):
            // At the floor, centred; the pick itself is uploaded as the original.
            return Opening(image: image, framing: .identity, isNewPick: true, hasStoredOriginal: true)
        case .stored:
            guard let detail = AppState.shared.memberDetails[memberId],
                  let stored = opening(detail: detail),
                  let url = URL(string: stored.url),
                  let image = Ui2ImageCache.shared.image(for: url) else { return nil }
            return Opening(image: image, framing: stored.framing, isNewPick: false, hasStoredOriginal: stored.hasOriginal)
        }
    }

    static func route(_ outcome: ImageFramingModel.SaveOutcome) -> Route {
        switch outcome {
        case .saved, .forbidden, .gone: return .pop
        case .unauthorized: return .signOut
        case .failed: return .banner
        case .ignored: return .stay
        }
    }

    var body: some View {
        EditCoverScreen(
            state: EditGroupCoverContainer.screenState(model),
            aspect: Self.frameAspect,
            mask: .circle,
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
        // D12, owner 2026-10-27: "Discard changes" as the main button, Done (stays) below it.
        // Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [],
                onDone: { discardMenuOpen = false },
                confirmLabel: EditGroupCoverContainer.discardLabel,
                onConfirm: {
                    discardMenuOpen = false
                    guard EditGroupCoverContainer.discardPops(isSaving: model?.isSaving ?? false) else { return }
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
        switch EditGroupCoverContainer.cancelAction(hasChanges: model?.hasChanges ?? false, isSaving: model?.isSaving ?? false) {
        case .pop: navigator.pop()
        case .confirmDiscard: discardMenuOpen = true
        case .ignore: break
        }
    }

    /// The model is built once, from the first laid-out frame that has a size.
    private func makeModelIfReady() {
        guard model == nil, let opening, frameRect.width > 0, frameRect.height > 0 else { return }
        let save: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String = { [memberId] rendered, framing, original in
            try await MemberActions().saveAvatar(memberId: memberId, rendered: rendered, framing: framing, original: original)
        }
        let built = ImageFramingModel(image: opening.image, framing: opening.framing,
                                      isNewPick: opening.isNewPick, hasStoredOriginal: opening.hasStoredOriginal,
                                      frameSize: frameRect.size, outputSize: Self.renderSize,
                                      saveFailedMessage: Self.saveFailedMessage, autoFaceFill: Self.autoFaceFill, save: save)
        model = built
        // D12: an edge swipe with a change does not pop; it asks to discard, as Cancel does; while saving it neither pops nor asks.
        backSwipe?.blocksBackSwipe = { [weak built] in
            EditGroupCoverContainer.blocksBackSwipe(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
        }
        backSwipe?.onBlockedBackSwipe = { [weak built] in
            let action = EditGroupCoverContainer.cancelAction(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
            if action == .confirmDiscard { discardMenuOpen = true }
        }
    }

    @MainActor
    private func prepare() async {
        // A new pick and a cached photo were set in `init`; this loads an uncached one (D5).
        guard opening == nil else { return }
        // Pops only this page: the member may already have left it (Cancel pops at once while loading).
        let leave = { navigator.popIfTop(.editMemberAvatar(memberId: memberId, source: source)) }
        guard let detail = AppState.shared.memberDetails[memberId],
              let stored = Self.opening(detail: detail) else { leave(); return }
        _ = await MemberProfileContainer.seedCovers([stored.url])
        // Silent: the page was closed during the load — no banner for a page that is gone.
        guard !Task.isCancelled else { return }
        guard let opened = Self.immediateOpening(memberId: memberId, source: source) else {
            AppState.shared.recordError(APIError.invalidResponse, context: "EditMemberAvatarContainer.loadOriginal",
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
        case .pop: navigator.popIfTop(.editMemberAvatar(memberId: memberId, source: source))
        case .signOut:
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EditMemberAvatarContainer.signOut", surface: false)
            }
        case .banner:
            if case let .failed(message) = outcome {
                AppState.shared.recordError(APIError.serverError(message), context: "EditMemberAvatarContainer.save", surface: true,
                                            friendlyMessage: model.saveFailedMessage,
                                            retry: { Task { await save() } })
            }
        case .stay: break
        }
    }
}
