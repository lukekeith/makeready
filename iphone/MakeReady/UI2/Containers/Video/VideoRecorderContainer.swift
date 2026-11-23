//
//  VideoRecorderContainer.swift
//  MakeReady
//
//  video-recorder D25: hosts d2m's `VideoRecorderScreen` over a `VideoRecorderModel`, in both layouts.
//  `VideoRecorderOverlay` is the full-screen recorder the shell hosts (no `.sheet`, no `.fullScreenCover`).
//

import CoreImage
import SwiftUI

/// The recorder as the shell presents it from the + menu: it slides itself in and out, because a
/// hosted overlay gets no presenting transaction (as C-016 RecorderSheet does).
struct VideoRecorderOverlay: View {
    let model: VideoRecorderModel
    let onEnd: () -> Void
    @State private var shown = false

    var body: some View {
        VideoRecorderContainer(model: model, layout: .fullScreen)
            .background(Token.layoutBackground.ignoresSafeArea())
            .visualEffect { [shown] effect, proxy in
                effect.offset(y: shown ? 0 : proxy.frame(in: .global).maxY)
            }
            .ignoresSafeArea(.keyboard)
            .allowsHitTesting(!model.isClosed)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) { model.closeTapped() }
            .onAppear {
                withAnimation(Token.Motion.sheetPresent) { shown = true }
            }
            .onChange(of: model.isClosed) { _, closed in
                guard closed else { return }
                withAnimation(Token.Motion.sheetPresent) {
                    shown = false
                } completion: {
                    onEnd()
                }
            }
    }
}

struct VideoRecorderContainer: View {
    let model: VideoRecorderModel
    let layout: VideoRecorderScreen.State.Layout

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var keyboardHeight: CGFloat = 0
    /// Where this view ends on the screen: the keyboard covers what is below its top edge.
    @State private var bottomEdge: CGFloat = 0
    /// The confirm on screen, kept while its sheet slides out.
    @State private var shownConfirm: VideoRecorderModel.Confirm = .discard
    @State private var thumbnails: [FilterStrip.Look: Image] = [:]

    private var shown: VideoRecorderModel.ScreenState { model.screenState }

    var body: some View {
        screen
            // d2m §3: the chrome fades as recording starts and stops.
            .animation(shown.showsClose ? Token.Motion.menuFadeIn : Token.Motion.menuFadeOut, value: shown.showsClose)
            .ignoresSafeArea(.container, edges: layout == .fullScreen ? .bottom : [])
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottomEdge = $0 }
            .actionMenuPresentation(isPresented: model.confirm != nil, onDismiss: model.dismissConfirm) {
                confirmMenu(model.confirm ?? shownConfirm)
            }
            .filterMenuPresentation(isPresented: model.notePickerOpen, onDismiss: model.closeNotePicker) {
                notePicker
            }
            .onAppear {
                model.open()
                thumbnails = FilterSwatches.images
            }
            .onChange(of: model.confirm) { _, confirm in
                if let confirm { shownConfirm = confirm }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.becameActive() }
                if phase == .background { model.backgrounded() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
                followKeyboard($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) {
                followKeyboard($0, hiding: true)
            }
    }

    private var screen: some View {
        VideoRecorderScreen(
            state: model.viewState(layout: layout),
            onRecord: model.recordTapped,
            onPause: model.pauseTapped,
            onRail: model.rail,
            onClose: model.closeTapped,
            onOpenSettings: openSettings,
            onLengthChange: model.setLength,
            onFilterChange: { model.pickFilter(named: $0) },
            onStrengthChange: model.setFilterStrength,
            onScriptChange: model.setScript,
            onUseNote: model.openNotePicker,
            onSpeedChange: model.setSpeed,
            onTextSizeChange: { model.setTextSize(named: $0) },
            feed: feed,
            hostChrome: false,
            teleprompterOffset: shown.teleprompterOffset,
            filterThumbnails: thumbnails,
            fillsHeight: layout == .fullScreen,
            sheetBottomInset: sheetBottomInset,
            previewSlot: { AnyView(closeButton) },
            recordRowSlot: { AnyView(recordRowButtons) }
        )
    }

    /// Review's player and Trim's clip are not the camera.
    private var feed: CameraPreview<AnyView>.Feed {
        switch shown.phase {
        case .ready, .preRoll, .recording, .endCountdown, .paused: .layer(model.displayLayer)
        case .permissionDenied, .review, .trim: .none
        }
    }

    // MARK: - §2b–2c buttons

    private enum Geometry {
        /// GAP — video-recorder §2c: the record row's 40 pt buttons, in the 80 pt record disc's row at
        /// bottom 6: 6 + (80 − 40) / 2. No size token.
        static let rowButton: CGFloat = 40
        static let rowButtonBottom: CGFloat = 26
        /// GAP — video-recorder §2c: undo "centre 98 left of the record centre".
        static let undoOffset: CGFloat = -98
        /// C-021 §2: a 24 pt glyph in a 44 pt target.
        static let hitTarget: CGFloat = 44
    }

    /// §2b: top-leading, hidden while recording or counting down.
    @ViewBuilder private var closeButton: some View {
        if layout == .fullScreen, shown.showsClose {
            glyphButton(.x, label: "Close", size: Geometry.hitTarget, action: model.closeTapped)
                // The glyph, not its target, is inset by the page margin.
                .padding(Token.Space.pageMargin - (Geometry.hitTarget - GlyphSize.visual) / 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private enum GlyphSize {
        static let visual: CGFloat = 24
    }

    /// §2c: undo and ✓, on the record row (D5).
    private var recordRowButtons: some View {
        ZStack {
            if shown.showsDeleteLast {
                glyphButton(.undo2, label: "Delete last clip", size: Geometry.rowButton, action: model.requestDeleteLast)
                    .offset(x: Geometry.undoOffset)
            }
            if shown.canFinish {
                glyphButton(.check, label: "Review", size: Geometry.rowButton, action: model.done)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, Token.Space.pageMargin)
            }
        }
        .padding(.bottom, Geometry.rowButtonBottom)
    }

    private func glyphButton(_ glyph: GlyphName, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        SwiftUI.Button(action: action) {
            Glyph(glyph, size: .md, tint: Token.textPrimary)
                // Reads over any camera image, as C-147's label does.
                .designShadow(Token.Elevation.thumb)
                .frame(width: size, height: size)
                .contentShape(Rectangle().inset(by: -(Geometry.hitTarget - size) / 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Overlays

    private func confirmMenu(_ confirm: VideoRecorderModel.Confirm) -> some View {
        ActionMenuOverlay(
            title: confirm.title,
            actions: [.init(glyph: "trash-2", label: confirm.actionLabel, tone: .destructive)],
            doneLabel: "Cancel",
            onSelect: { _ in
                switch confirm {
                case .deleteLast: model.deleteLastConfirmed()
                case .discard: model.discardConfirmed()
                }
            },
            onDone: model.dismissConfirm
        )
    }

    /// D7: one of the leader's Library notes, newest first.
    private var notePicker: some View {
        let notes = AppState.shared.studyNotes.all.sorted { $0.updatedAt > $1.updatedAt }
        return FilterMenuOverlay(
            options: notes.map { .init(id: $0.id, label: $0.displayTitle) },
            selectionMode: .single,
            selectedIDs: [],
            onSelect: { option in
                guard let note = AppState.shared.studyNotes[option.id] else { return }
                model.useNote(content: note.content)
            },
            onClose: model.closeNotePicker
        )
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    // MARK: - Insets

    /// A sheet's content stays above the home indicator, or above the keyboard.
    private var sheetBottomInset: CGFloat {
        let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow
        let screenHeight = window?.screen.bounds.height ?? bottomEdge
        let safeBottom = layout == .fullScreen ? window?.safeAreaInsets.bottom ?? 0 : 0
        guard keyboardHeight > 0 else { return safeBottom }
        return max(safeBottom, bottomEdge - (screenHeight - keyboardHeight))
    }

    private func followKeyboard(_ note: Notification, hiding: Bool = false) {
        let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
        let screenHeight = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? frame.maxY
        let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = hiding ? 0 : max(0, screenHeight - frame.minY)
        }
    }
}

// MARK: - Live

extension VideoRecorderModel {
    /// A recorder on the camera, with the signed-in user's drafts in this environment. Nil, with a
    /// banner, when their folder cannot be made.
    static func live(entry: VideoRecorderEntry, userId: String) -> VideoRecorderModel? {
        let state = AppState.shared
        let report: (Error, String) -> Void = { error, message in
            state.recordError(error, context: "VideoRecorder", surface: true, friendlyMessage: message)
        }
        do {
            let drafts = VideoDraftStore(root: try draftsFolder(environment: AppState.memoEnvironmentName, userId: userId))
            let engine = VideoCaptureEngine(session: LiveVideoCaptureSession(), drafts: drafts)
            let beeper = CountdownBeeper()
            return VideoRecorderModel(
                entry: entry, engine: engine, settings: RecorderSettings(),
                recoverDraft: { drafts.recoverable().last }, beep: { beeper.beep(hz: $0) }, report: report,
                loadNotes: { _ = try await NoteActions().load() })
        } catch {
            report(error, "Couldn't open the recorder")
            return nil
        }
    }

    /// Beside the user's upload queue, which reads only the files directly in its own folder.
    static func draftsFolder(environment: String, userId: String, root: URL? = nil) throws -> URL {
        var folder = try VideoUploadController.folder(environment: environment, userId: userId, root: root)
            .appendingPathComponent("drafts", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        return folder
    }
}

/// C-150's swatches: each look over the same sky-to-skin gradient.
@MainActor
private enum FilterSwatches {
    private static let side: CGFloat = 168

    static let images: [FilterStrip.Look: Image] = {
        let context = CIContext()
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: side, y: side),
            "inputColor0": CIColor(red: 0.85, green: 0.55, blue: 0.4),
            "inputColor1": CIColor(red: 0.3, green: 0.55, blue: 0.8)
        ])?.outputImage?.cropped(to: rect)
        guard let gradient else { return [:] }
        var images: [FilterStrip.Look: Image] = [:]
        for (look, filter) in zip(FilterStrip.Look.allCases, VideoFilter.allCases) {
            guard let image = context.createCGImage(filter.apply(to: gradient, strength: 1), from: rect) else { continue }
            images[look] = Image(decorative: image, scale: 3)
        }
        return images
    }()
}
