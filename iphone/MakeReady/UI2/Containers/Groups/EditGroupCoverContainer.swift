import SwiftUI

/// group-cover-image D4/D6/D7/D13/D26/D28/D30: wires the d2m-built Edit cover screen
/// (`EditCoverScreen`) to `EditGroupCoverModel`. A new pick opens at once; a stored cover loads its
/// original (`coverOriginalUrl ?? coverImageUrl`) first. The model is built once both the image and
/// the screen's frame rect (`onFrameLayout`) are known, so its `frameSize` is the frame the canvas
/// really draws. Cancel with a change asks to discard (D26), else pops. Done saves → D13: pop on
/// success (AppState + the image cache already updated), 404 → back to Groups, 401 → sign-out,
/// anything else → the surfaced banner with the page kept.
struct EditGroupCoverContainer: View {
    let groupId: String
    let source: CoverEditSource

    enum Route: Equatable { case pop, popToRoot, signOut, banner, stay }
    /// D26: what Cancel does.
    enum CancelAction: Equatable { case confirmDiscard, pop }

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// The photo to frame and where it opens — set once it is in hand (D6 at once, D7 after a load).
    @State private var opening: Opening?
    /// The screen's frame rect, in the canvas slot's coordinates (`onFrameLayout`).
    @State private var frameRect: CGRect = .zero
    @State private var model: EditGroupCoverModel?
    /// D26: the C-066 "Discard changes" confirmation is up.
    @State private var discardMenuOpen = false

    private struct Opening {
        let image: UIImage
        let framing: CoverFraming
        let isNewPick: Bool
        let hasStoredOriginal: Bool
    }

    /// Cache-first: a new pick, or a stored original already in Ui2ImageCache, is in hand before the
    /// push animates in; only an uncached original waits for `prepare()`.
    init(groupId: String, source: CoverEditSource) {
        self.groupId = groupId
        self.source = source
        _opening = State(initialValue: Self.immediateOpening(groupId: groupId, source: source))
    }

    @MainActor
    private static func immediateOpening(groupId: String, source: CoverEditSource) -> Opening? {
        switch source {
        case let .newPick(image):
            // D6 at the floor, centred; the pick itself is uploaded as the original.
            return Opening(image: image, framing: .identity, isNewPick: true, hasStoredOriginal: true)
        case .stored:
            guard let group = AppState.shared.groups[groupId],
                  let stored = EditGroupCoverModel.opening(group: group),
                  let url = URL(string: stored.url),
                  let image = Ui2ImageCache.shared.image(for: url) else { return nil }
            return Opening(image: image, framing: stored.framing, isNewPick: false, hasStoredOriginal: stored.hasOriginal)
        }
    }

    static func route(_ outcome: EditGroupCoverModel.SaveOutcome) -> Route {
        switch outcome {
        case .saved: return .pop
        case .gone: return .popToRoot
        case .unauthorized: return .signOut
        case .failed: return .banner
        case .ignored: return .stay
        }
    }

    /// D26: any framing change, or a new pick, asks before discarding.
    static func cancelAction(hasChanges: Bool) -> CancelAction {
        hasChanges ? .confirmDiscard : .pop
    }

    /// D28/D30: the screen's inputs. The grid shows during any gesture, the readout only while
    /// twisting or turning the dial; Done mirrors `hasChanges`. No model yet (loading) → a still,
    /// unsavable page.
    @MainActor
    static func screenState<Canvas: View>(_ model: EditGroupCoverModel?) -> EditCoverScreen<Canvas>.State {
        guard let model else {
            return .init(showsGrid: false, readoutDegrees: nil, rotationDegrees: 0, saving: false, doneEnabled: false)
        }
        return .init(showsGrid: model.isGestureActive,
                     readoutDegrees: model.isTwisting ? model.readoutDegrees : nil,
                     rotationDegrees: model.framing.rotation,
                     saving: model.isSaving,
                     doneEnabled: model.hasChanges)
    }

    /// D26: the confirmation's one row.
    static let discardAction = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Discard changes", tone: .destructive)

    /// D7: the banner a stored original that will not load shows; the page pops.
    static let loadFailedMessage = "Couldn't load the cover"

    var body: some View {
        EditCoverScreen(
            state: Self.screenState(model),
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
                withAnimation(CoverFramingCanvas.settle) { model.endStraighten() }
            }
        )
        .background(Token.layoutBackground.ignoresSafeArea())
        // D26: one red row and Done; Done stays. Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [Self.discardAction],
                onSelect: { _ in
                    discardMenuOpen = false
                    navigator.pop()
                },
                onDone: { discardMenuOpen = false }
            )
        }
        .task { await prepare() }
    }

    @ViewBuilder private var canvas: some View {
        if let model {
            CoverFramingCanvas(model: model, frame: frameRect)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cancel() {
        switch Self.cancelAction(hasChanges: model?.hasChanges ?? false) {
        case .pop: navigator.pop()
        case .confirmDiscard: discardMenuOpen = true
        }
    }

    /// The model is built once, from the first laid-out frame that has a size.
    private func makeModelIfReady() {
        guard model == nil, let opening, frameRect.width > 0, frameRect.height > 0 else { return }
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult = { [groupId] rendered, framing, original in
            try await GroupActions().saveCover(groupId: groupId, rendered: rendered, framing: framing, original: original)
        }
        model = EditGroupCoverModel(groupId: groupId, image: opening.image, framing: opening.framing,
                                    isNewPick: opening.isNewPick, hasStoredOriginal: opening.hasStoredOriginal,
                                    frameSize: frameRect.size, save: save)
    }

    @MainActor
    private func prepare() async {
        // A new pick and a cached original were set in `init`; this loads an uncached original (D7).
        guard opening == nil else { return }
        guard let group = AppState.shared.groups[groupId],
              let stored = EditGroupCoverModel.opening(group: group) else { navigator.pop(); return }
        _ = await MemberProfileContainer.seedCovers([stored.url])
        guard let opened = Self.immediateOpening(groupId: groupId, source: source) else {
            AppState.shared.recordError(APIError.invalidResponse, context: "EditGroupCoverContainer.loadOriginal",
                                        surface: true, friendlyMessage: Self.loadFailedMessage)
            navigator.pop()
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
            if case let .failed(message) = outcome {
                AppState.shared.recordError(APIError.serverError(message), context: "EditGroupCoverContainer.save", surface: true,
                                            friendlyMessage: EditGroupCoverModel.saveFailedMessage,
                                            retry: { Task { await save() } })
            }
        case .stay: break
        }
    }
}

/// D5/D25/D30: the framed image and its three simultaneous gestures, placed in the Edit cover
/// screen's canvas slot. It fills the whole canvas area unclipped (the screen dims what lies
/// outside `frame`) and draws the image as `CoverImageRendering` renders it — mirrored, turned,
/// rotated, scaled, offset — against `frame`. The model clamps every change; release springs back
/// to coverage (D25).
struct CoverFramingCanvas: View {
    let model: EditGroupCoverModel
    /// The screen's frame rect, in this view's coordinates.
    let frame: CGRect

    /// D25: the spring back to the nearest covering framing on release.
    static let settle = Animation.spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        let f = model.framing
        let scale = CoverFramingMath.absoluteScale(f, image: model.image.size, frame: frame.size)
        let center = CoverFramingMath.imageCenter(f, frame: frame.size)
        ZStack(alignment: .topLeading) {
            Color.clear
            Image(uiImage: model.image)
                .resizable()
                .frame(width: model.image.size.width * scale, height: model.image.size.height * scale)
                .scaleEffect(x: f.flipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(-90 * Double(f.quarterTurns)))   // D21: counter-clockwise turns
                .rotationEffect(.degrees(f.rotation))
                .position(x: frame.midX + center.x, y: frame.midY + center.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                SimultaneousGesture(MagnifyGesture(), RotateGesture()),
                // pan-ok: the canvas move pans the image in any direction, not a sideways scroll.
                DragGesture(minimumDistance: 0)
            )
            .onChanged { value in
                model.updateGesture(magnification: value.first?.first?.magnification ?? 1,
                                    rotationDegrees: value.first?.second?.rotation.degrees ?? 0,
                                    translation: value.second?.translation ?? .zero)
            }
            .onEnded { _ in
                withAnimation(Self.settle) { model.endGesture() }
            }
        )
        .allowsHitTesting(!model.isSaving)
        .accessibilityElement()
        .accessibilityLabel("Cover framing")
        .accessibilityHint("Pinch to zoom, rotate with two fingers, drag to move")
    }
}
