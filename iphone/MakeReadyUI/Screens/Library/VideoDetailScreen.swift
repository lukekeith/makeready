//
//  VideoDetailScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-detail in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/videos/:videoId ·
//  PATCH /api/videos/:videoId · DELETE /api/videos/:videoId ·
//  POST /api/videos/:videoId/remove-from-library
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Video Detail — the pushed full-screen Library video page (§2), modelled on memo-detail:
/// C-040 PageHeader (Back · ⋯), the screen-local header (title + meta line), the pinned player
/// block (the screen-local 16:9 video surface over C-004 ScrubTrack over C-014
/// TransportControls — OQ-video-detail-002), and the transcript, which alone scrolls.
///
/// Presentational (D6): playback, rename, delete and remove leave through `on<Verb>` closures;
/// the rename field's text, the ⋯ menu and the delete confirmation are UI-only rules (§3
/// interactions 2–4) and are real local state here.
struct VideoDetailScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §5 `status`, plus §3 `uploading` (still in `VideoUploadController`'s queue).
        enum Status: String {
            case ready
            case uploading
            case processing
            case error
        }

        /// §3: what the transcript area shows.
        enum Transcript: String {
            /// The paragraphs (`ready`, or an on-device transcript while uploading).
            case paragraphs
            /// `Transcribing…` — transcriptStatus pending.
            case transcribing
            /// `No transcript for this video` — transcriptStatus none or failed.
            case unavailable
        }

        /// §2 header title.
        var title: String
        /// §2 meta line's `«date label» «time»` (`Today 7:43 PM`), memo-detail's rule. The screen
        /// appends ` · «duration»`.
        var dateLabel: String
        /// C-004 / C-014 — the video's length, seconds.
        var duration: Double
        /// §5 `thumbnailUrl` — the poster on the video surface; empty = the surface's own fill.
        var thumbnailURL: String = ""
        var status: Status = .ready
        /// C-004 `elapsed`, seconds.
        var elapsed: Double = 0
        /// C-014 `playing`; §3: the current paragraph is highlighted only while true.
        var playing: Bool = false
        /// §3 Loading: false until the player is ready — C-004 / C-014 `enabled = false`.
        var playerReady: Bool = true
        var transcript: Transcript = .paragraphs
        /// §3 Paragraphs: each segment's start, seconds (`⌊startMs / 1000⌋`).
        var paragraphStarts: [Double] = []
        /// §3 Paragraphs: each segment's text, index-aligned with `paragraphStarts`.
        var paragraphTexts: [String] = []
        /// §3 interaction 4 (SPEC D17): 0 → Delete; N > 0 → Remove from Library.
        var lessonUseCount: Int = 0
        /// §3 renaming: the title is an editable field.
        var renaming: Bool = false
        /// §3 more-menu-open: C-066 Rename · Delete is presented.
        var menuPresented: Bool = false
        /// §3 delete-confirm: C-066 in confirmation mode is presented.
        var deleteConfirmPresented: Bool = false
    }

    let state: State
    /// §3 interaction 1: stop playback, pop.
    var onBack: () -> Void = {}
    /// §3 interaction 3: commit a trimmed 1–120 character title through `VideoActions.rename`.
    var onRename: (String) -> Void = { _ in }
    /// §3 interaction 4, `lessonUseCount` 0: `DELETE /api/videos/:videoId`, then pop.
    var onDelete: () -> Void = {}
    /// §3 interaction 4, `lessonUseCount` > 0: `POST …/remove-from-library`, then pop.
    var onRemoveFromLibrary: () -> Void = {}
    /// §3 interaction 5 (C-014 `onPlayingChange`, or a tap on the surface).
    var onPlayingChange: (Bool) -> Void = { _ in }
    /// §3 interaction 6: −15 s (C-014 `onSkipBack`).
    var onSkipBack: () -> Void = {}
    /// §3 interaction 6: +15 s (C-014 `onSkipForward`).
    var onSkipForward: () -> Void = {}
    /// §3 interaction 7 (C-004 `onSeek`).
    var onSeek: (TimeInterval) -> Void = { _ in }
    /// §3 interaction 7 (C-004 `onDraggingChange`).
    var onDraggingChange: (Bool) -> Void = { _ in }
    /// §3 interaction 8: seek to the paragraph's start and play.
    var onSeekParagraph: (Int) -> Void = { _ in }

    // §3 interaction 3: "Return or blur commits … empty reverts".
    @SwiftUI.State private var renaming: Bool
    @SwiftUI.State private var titleText: String
    @FocusState private var titleFocused: Bool
    // §3 interaction 2: ⋯ presents C-066 Rename · Delete.
    @SwiftUI.State private var menuPresented: Bool
    // §3 interaction 4: Delete replaces the menu with the C-066 confirmation.
    @SwiftUI.State private var deleteConfirmPresented: Bool
    // C-004: "elapsed follows the finger" — the drag flag the track draws.
    @SwiftUI.State private var dragging = false

    /// True only under the capture harness's element map (see `captureStandInLayer`).
    @Environment(\.ui2ElementCollecting) private var captureStandIn

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onRename: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void = {},
        onRemoveFromLibrary: @escaping () -> Void = {},
        onPlayingChange: @escaping (Bool) -> Void = { _ in },
        onSkipBack: @escaping () -> Void = {},
        onSkipForward: @escaping () -> Void = {},
        onSeek: @escaping (TimeInterval) -> Void = { _ in },
        onDraggingChange: @escaping (Bool) -> Void = { _ in },
        onSeekParagraph: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onRename = onRename
        self.onDelete = onDelete
        self.onRemoveFromLibrary = onRemoveFromLibrary
        self.onPlayingChange = onPlayingChange
        self.onSkipBack = onSkipBack
        self.onSkipForward = onSkipForward
        self.onSeek = onSeek
        self.onDraggingChange = onDraggingChange
        self.onSeekParagraph = onSeekParagraph
        _renaming = SwiftUI.State(initialValue: state.renaming)
        _titleText = SwiftUI.State(initialValue: state.title)
        _menuPresented = SwiftUI.State(initialValue: state.menuPresented)
        _deleteConfirmPresented = SwiftUI.State(initialValue: state.deleteConfirmPresented)
    }

    var body: some View {
        // §2 top → bottom: PageHeader, header and player pinned; only the transcript scrolls.
        VStack(alignment: .leading, spacing: 0) {
            navChrome
            header
                // §2 item 2: 16 below the PageHeader (memo-detail's owner number) — `space-page-margin`.
                .padding(.top, Token.Space.pageMargin)
            playerBlock
                .padding(.top, Token.Space.sectionGap)
            transcriptArea
                .padding(.top, Token.Space.sectionGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // §2: "Full-screen pushed page on `color-layout-background`".
        .background(Token.layoutBackground)
        // §3 interaction 2: the ⋯ menu — C-066 Rename · Delete, `doneLabel` Done.
        .actionMenuPresentation(isPresented: menuPresented && !captureStandIn,
                                onDismiss: { menuPresented = false }) {
            menuCard
        }
        // §3 delete-confirm: the same card in confirmation mode (SPEC D17 copy); Cancel or a
        // scrim tap dismisses with no change.
        .actionMenuPresentation(isPresented: deleteConfirmPresented && !captureStandIn,
                                onDismiss: { deleteConfirmPresented = false }) {
            deleteConfirmCard
        }
        .overlay {
            if captureStandIn && menuPresented {
                captureStandInLayer { menuCard }
            } else if captureStandIn && deleteConfirmPresented {
                captureStandInLayer { deleteConfirmCard }
            }
        }
    }

    private var menuCard: some View {
        ActionMenuOverlay(
            actions: Self.menuActions,
            onSelect: chooseMenuAction,
            onDone: { menuPresented = false }
        )
        .ui2Element("C-066 ActionMenuOverlay")
    }

    private var deleteConfirmCard: some View {
        let removes = state.lessonUseCount > 0
        return ActionMenuOverlay(
            title: removes ? Self.removeTitle(state.lessonUseCount) : "Delete this video?",
            actions: [removes ? Self.removeAction : Self.deleteAction],
            doneLabel: "Cancel",
            onSelect: { _ in
                deleteConfirmPresented = false
                if removes { onRemoveFromLibrary() } else { onDelete() }
            },
            onDone: { deleteConfirmPresented = false }
        )
        .ui2Element("C-066 ActionMenuOverlay 2")
    }

    /// Capture stand-in (memo-detail / note-editor precedent): C-066's presentation mounts after
    /// the first frame and slides in on appear, so a snapshot never sees it. Beneath the capture
    /// element map only, the screen draws the presented layer at rest exactly as
    /// `actionMenuPresentation` lays it out — its dim, then the card `ActionMenuMotion.edgeInset`
    /// from the sides and bottom.
    private func captureStandInLayer<Card: View>(@ViewBuilder _ card: () -> Card) -> some View {
        ZStack(alignment: .bottom) {
            Token.black80
                .ignoresSafeArea()
                .ui2Element("Dim")
            card()
                .padding(.horizontal, ActionMenuMotion.edgeInset)
                .padding(.bottom, ActionMenuMotion.edgeInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - §2 item 1 — nav (C-040 PageHeader)

    private var navChrome: some View {
        // §2 item 1: "style `.twoIcons`, `leadingGlyph = .back`, `rightButtons = [.threeDots]`,
        // no title; as memo-detail uses it".
        PageHeader(
            style: .twoIcons,
            title: nil,
            showTitle: false,
            showIcons: true,
            // C-040 `showsDone`, as memo-detail: the done check shows while renaming.
            showsDone: renaming,
            leadingGlyph: .back,
            rightButtons: [.threeDots],
            onLeading: onBack,
            onRightButton: { _ in menuPresented = true },
            onDone: {
                titleFocused = false
                commitRename()
            }
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: - §2 item 2 — header (screen-local)

    private var header: some View {
        VStack(alignment: .leading, spacing: Token.Space.metaGap) {
            titleView
            Text(metaLine)
                .designTextStyle(Token.TypeStyle.byline)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .ui2Element("Meta line")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Token.Space.pageMargin)
    }

    @ViewBuilder
    private var titleView: some View {
        if renaming {
            // §2: "a one-line text field in the same type, caret `color-accent`, no box".
            TextField("", text: $titleText)
                .designTextStyle(Token.TypeStyle.valueEmphasis)
                .foregroundStyle(Token.textPrimary)
                .tint(Token.accent)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .submitLabel(.done)
                .focused($titleFocused)
                .onSubmit(commitRename)
                .onChange(of: titleFocused) { _, focused in
                    if !focused { commitRename() }
                }
                .onAppear { titleFocused = true }
                .ui2Element("Title field")
        } else {
            Text(titleText)
                .designTextStyle(Token.TypeStyle.valueEmphasis)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
                // §3 interaction 3: "tap on title" enters renaming.
                .onTapGesture { renaming = true }
                .ui2Element("Title")
        }
    }

    // MARK: - §2 item 3 — player block

    /// §3: C-004 / C-014 are `disabled` until the player is ready, and in uploading /
    /// processing / error.
    private var controlsEnabled: Bool { state.playerReady && state.status == .ready }

    private var playerBlock: some View {
        VStack(spacing: Token.Space.rowGap) {
            videoSurface
            ScrubTrack(
                elapsed: state.elapsed,
                duration: state.duration,
                dragging: dragging,
                enabled: controlsEnabled,
                onSeek: onSeek,
                onDraggingChange: { dragging = $0; onDraggingChange($0) }
            )
            .ui2Element("C-004 ScrubTrack")
            TransportControls(
                playing: state.playing,
                enabled: controlsEnabled,
                onPlayingChange: onPlayingChange,
                onSkipBack: onSkipBack,
                onSkipForward: onSkipForward
            )
            .ui2Element("C-014 TransportControls")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// §2 item 3 (OQ-video-detail-002): full inner width, 16:9, corner `radius-card`, fill
    /// `color-layout-background` behind the poster, aspect-fit. uploading / processing: C-076 with
    /// a status line `space-element-gap` below; error: the status line alone (OQ-video-detail-003).
    private var videoSurface: some View {
        // The 16:9 box sizes the surface; the poster is fitted inside it, never the other way round.
        Token.layoutBackground
            // FLAGGED LITERAL — video-detail §2: the 16:9 aspect.
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                ZStack {
                    poster
                    if state.status == .uploading {
                        // §3 uploading: "poster … dimmed under C-076".
                        Token.scrim
                    }
                    surfaceStatus
                }
            }
        .clipShape(RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous))
        .contentShape(Rectangle())
        // §3 interaction 5: "a tap on the surface" plays or pauses.
        .onTapGesture {
            if controlsEnabled { onPlayingChange(!state.playing) }
        }
        .ui2Element("Video surface")
    }

    /// Cache-first, as ObjectCard's banner: a snapshot renders in one synchronous layout pass, so
    /// an `AsyncImage` alone comes out empty in a capture (Ui2ImageCache.swift).
    @ViewBuilder
    private var poster: some View {
        let url = URL(string: state.thumbnailURL)
        if let url, let cached = Ui2ImageCache.shared.image(for: url) {
            Image(uiImage: cached)
                .resizable()
                .scaledToFit()
        } else if let url, !state.thumbnailURL.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var surfaceStatus: some View {
        switch state.status {
        case .ready:
            EmptyView()
        case .uploading, .processing:
            VStack(spacing: Token.Space.elementGap) {
                ActivitySpinner()
                    .ui2Element("C-076 ActivitySpinner")
                surfaceStatusLine(state.status == .uploading ? "Uploading…" : "Processing…")
            }
        case .error:
            surfaceStatusLine("This video couldn't be processed")
        }
    }

    private func surfaceStatusLine(_ text: String) -> some View {
        Text(text)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .multilineTextAlignment(.center)
            .ui2Element("Surface status")
    }

    // MARK: - §2 item 4 — transcript

    @ViewBuilder
    private var transcriptArea: some View {
        switch state.transcript {
        case .paragraphs:
            // §2 Scroll: "only the transcript scrolls".
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Token.Space.rowGap) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        paragraphView(paragraph, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Token.Space.pageMargin)
                // §2: "bottom inset = home-indicator safe area + `space-page-margin`".
                .padding(.bottom, Token.Space.pageMargin)
            }
            .scrollIndicators(.hidden)
        case .transcribing:
            statusLine(Text("Transcribing…").italic())
        case .unavailable:
            statusLine(Text("No transcript for this video"))
        }
    }

    /// §2: timestamp (`type-caption`, secondary, monospaced digits), `space-meta-gap`, then the
    /// text (`type-body-sm`) — primary when it is the playing paragraph, secondary otherwise.
    private func paragraphView(_ paragraph: Paragraph, index: Int) -> some View {
        let highlighted = state.playing && index == currentParagraph
        return SwiftUI.Button { onSeekParagraph(index) } label: {
            VStack(alignment: .leading, spacing: Token.Space.metaGap) {
                Text(Self.clock(Int(paragraph.start.rounded(.down))))
                    .monospacedDigit()
                    .designTextStyle(Token.TypeStyle.caption)
                    .foregroundStyle(Token.textSecondary)
                Text(paragraph.text)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(highlighted ? Token.textPrimary : Token.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ui2Element("Paragraph \(index + 1)")
    }

    private func statusLine(_ text: Text) -> some View {
        text
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("Transcript status")
    }

    // MARK: - §3 Paragraphs

    private struct Paragraph {
        let start: Double
        let text: String
    }

    private var paragraphs: [Paragraph] {
        zip(state.paragraphStarts, state.paragraphTexts).map { Paragraph(start: $0, text: $1) }
    }

    /// §3: "start ≤ elapsed < next start".
    private var currentParagraph: Int? {
        paragraphs.lastIndex { $0.start <= state.elapsed }
    }

    // MARK: - §2 meta line

    /// `«date label» «time» · «duration»`.
    private var metaLine: String {
        "\(state.dateLabel) · \(Self.clock(Int(max(state.duration, 0).rounded())))"
    }

    /// §2 (memo-detail's rule): `m:ss`, `h:mm:ss` from one hour.
    private static func clock(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - §3 interactions 2–4

    private static let renameAction = ActionMenuOverlay.ActionItem(glyph: "pencil", label: "Rename")
    private static let deleteAction = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Delete", tone: .destructive)
    private static let removeAction = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Remove", tone: .destructive)
    private static let menuActions = [renameAction, deleteAction]

    /// SPEC D17: the N > 0 confirmation copy.
    private static func removeTitle(_ count: Int) -> String {
        "This video is used in \(count) \(count == 1 ? "lesson" : "lessons"). It will stay in those lessons and leave your Library."
    }

    private func chooseMenuAction(_ action: ActionMenuOverlay.ActionItem) {
        menuPresented = false
        if action.id == Self.renameAction.id {
            renaming = true
        } else {
            deleteConfirmPresented = true
        }
    }

    /// §3 interaction 3: 1–120 characters after trim; empty reverts.
    private func commitRename() {
        guard renaming else { return }
        renaming = false
        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleText = state.title
            return
        }
        let committed = String(trimmed.prefix(Self.titleLimit))
        titleText = committed
        if committed != state.title { onRename(committed) }
    }

    /// §3 interaction 3: the server's title limit.
    private static let titleLimit = 120
}

// MARK: - Previews (§3 shared fixture: "Video 3", today 7:43 PM, 45 s, segments 0:00 · 0:14 · 0:31;
// segment text from library-home's video sample row and memo-detail's sample paragraphs)

private extension VideoDetailScreen.State {
    static let samplePoster = "http://localhost:5961/api/projects/makeready/images/image-5"
    static let sampleStarts: [Double] = [0, 14, 31]
    static let sampleTexts = [
        "Welcome back. This week we are talking about rest",
        "Start with verse 28 and work backwards to the context.",
        "What does rest look like this week?",
    ]

    static func sample(
        status: Status = .ready,
        elapsed: Double = 0,
        playing: Bool = false,
        transcript: Transcript = .paragraphs,
        renaming: Bool = false,
        menuPresented: Bool = false,
        deleteConfirmPresented: Bool = false
    ) -> Self {
        .init(
            title: "Video 3",
            dateLabel: "Today 7:43 PM",
            duration: 45,
            thumbnailURL: status == .error ? "" : samplePoster,
            status: status,
            elapsed: elapsed,
            playing: playing,
            transcript: transcript,
            paragraphStarts: transcript == .paragraphs ? sampleStarts : [],
            paragraphTexts: transcript == .paragraphs ? sampleTexts : [],
            renaming: renaming,
            menuPresented: menuPresented,
            deleteConfirmPresented: deleteConfirmPresented
        )
    }
}

#Preview("ready") {
    VideoDetailScreen(state: .sample())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("playing") {
    VideoDetailScreen(state: .sample(elapsed: 16, playing: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("no-transcript-yet") {
    VideoDetailScreen(state: .sample(transcript: .transcribing))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("no-transcript") {
    VideoDetailScreen(state: .sample(transcript: .unavailable))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("uploading") {
    VideoDetailScreen(state: .sample(status: .uploading, transcript: .transcribing))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("processing") {
    VideoDetailScreen(state: .sample(status: .processing))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    VideoDetailScreen(state: .sample(status: .error))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("renaming") {
    VideoDetailScreen(state: .sample(renaming: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("more-menu-open") {
    VideoDetailScreen(state: .sample(menuPresented: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("delete-confirm") {
    VideoDetailScreen(state: .sample(deleteConfirmPresented: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
