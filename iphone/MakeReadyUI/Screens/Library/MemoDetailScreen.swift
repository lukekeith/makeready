//
//  MemoDetailScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen memo-detail in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/memos/:id ·
//  PATCH /api/memos/:id · DELETE /api/memos/:id
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Memo Detail — the pushed full-screen memo page (§2): C-040 PageHeader (Back · ⋯), the
/// screen-local header (title + meta line), the pinned player block (C-004 ScrubTrack over C-014
/// TransportControls), and the transcript — screen-local paragraphs (D75 superseded, owner
/// 2026-11-21) or a status line — which alone scrolls.
///
/// Presentational (D6): playback, rename and delete leave through `on<Verb>` closures; the
/// rename field's text, the ⋯ menu and the delete confirmation are UI-only rules (§3
/// interactions 2–4) and are real local state here.
struct MemoDetailScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3: what the transcript area shows.
        enum Transcript: String {
            /// The paragraphs (`ready`, or an on-device transcript while waiting to upload).
            case paragraphs
            /// `Transcribing…` — status pending, or queued with no on-device transcript.
            case transcribing
            /// `No transcript for this memo` — status failed, none or unknown.
            case unavailable
        }

        /// §2 header title.
        var title: String
        /// §2 meta line's `«date label» «time»` (`Today 7:43 PM`); the container formats it by the
        /// notes rule C-006 uses. The screen appends ` · «duration»`.
        var dateLabel: String
        /// C-004 / C-014 — the memo's length, seconds.
        var duration: Double
        /// C-004 `elapsed`, seconds.
        var elapsed: Double = 0
        /// C-014 `playing`; §3: the current paragraph is highlighted only while true.
        var playing: Bool = false
        /// §3 Loading: false until `MemoPlayer` is ready — C-004 / C-014 `enabled = false`.
        var playerReady: Bool = true
        var transcript: Transcript = .paragraphs
        /// §3 Paragraphs: each segment's start, seconds (`⌊startMs / 1000⌋`).
        var paragraphStarts: [Double] = []
        /// §3 Paragraphs: each segment's text, index-aligned with `paragraphStarts`.
        var paragraphTexts: [String] = []
        /// §3 renaming: the title is an editable field.
        var renaming: Bool = false
        /// §3 delete-confirm: C-066 in confirmation mode is presented.
        var deleteConfirmPresented: Bool = false
    }

    let state: State
    /// §3 interaction 1: stop playback, restore the audio session, pop.
    var onBack: () -> Void = {}
    /// §3 interaction 3: commit a trimmed 1–120 character title through `MemoActions.rename`.
    var onRename: (String) -> Void = { _ in }
    /// §3 interaction 4: `MemoActions.softDelete`, then pop.
    var onDelete: () -> Void = {}
    /// §3 interaction 5 (C-014 `onPlayingChange`).
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

    // §3 interaction 3: "Return or leaving the field commits … an empty title reverts".
    @SwiftUI.State private var renaming: Bool
    @SwiftUI.State private var titleText: String
    @FocusState private var titleFocused: Bool
    // §3 interaction 2: ⋯ presents C-066 Rename · Delete.
    @SwiftUI.State private var menuPresented = false
    // §3 interaction 4: Delete replaces the menu with the C-066 confirmation.
    @SwiftUI.State private var deleteConfirmPresented: Bool
    // C-004: "while dragging, elapsed follows the finger" — the drag flag the track draws.
    @SwiftUI.State private var dragging = false

    /// True only under the capture harness's element map (see `captureDeleteConfirm`).
    @Environment(\.ui2ElementCollecting) private var captureStandIn

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onRename: @escaping (String) -> Void = { _ in },
        onDelete: @escaping () -> Void = {},
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
        self.onPlayingChange = onPlayingChange
        self.onSkipBack = onSkipBack
        self.onSkipForward = onSkipForward
        self.onSeek = onSeek
        self.onDraggingChange = onDraggingChange
        self.onSeekParagraph = onSeekParagraph
        _renaming = SwiftUI.State(initialValue: state.renaming)
        _titleText = SwiftUI.State(initialValue: state.title)
        _deleteConfirmPresented = SwiftUI.State(initialValue: state.deleteConfirmPresented)
    }

    var body: some View {
        // §2 top → bottom: PageHeader, header and player pinned; only the transcript scrolls.
        VStack(alignment: .leading, spacing: 0) {
            navChrome
            header
                // §2 item 2: 16 below the PageHeader (owner, 2026-11-21) — `space-page-margin`.
                .padding(.top, Token.Space.pageMargin)
            playerBlock
                .padding(.top, Token.Space.sectionGap)
            transcriptArea
                .padding(.top, Token.Space.sectionGap)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // §2: "Full-screen pushed page on `color-layout-background`".
        .background(Token.layoutBackground)
        // §6: the ⋯ menu — C-066 Rename · Delete, `doneLabel` Done.
        .actionMenuPresentation(isPresented: menuPresented, onDismiss: { menuPresented = false }) {
            ActionMenuOverlay(
                actions: Self.menuActions,
                onSelect: chooseMenuAction,
                onDone: { menuPresented = false }
            )
            .ui2Element("C-066 ActionMenuOverlay")
        }
        // §3 delete-confirm: the same card in confirmation mode — `Delete this memo?` · `Delete` ·
        // `Cancel`; Cancel or a scrim tap dismisses with no change.
        .actionMenuPresentation(isPresented: deleteConfirmPresented && !captureStandIn,
                                onDismiss: { deleteConfirmPresented = false }) {
            deleteConfirmCard
        }
        .overlay {
            if captureStandIn && deleteConfirmPresented {
                captureDeleteConfirm
            }
        }
    }

    private var deleteConfirmCard: some View {
        ActionMenuOverlay(
            title: "Delete this memo?",
            actions: [Self.deleteAction],
            doneLabel: "Cancel",
            onSelect: { _ in
                deleteConfirmPresented = false
                onDelete()
            },
            onDone: { deleteConfirmPresented = false }
        )
        .ui2Element("C-066 ActionMenuOverlay 2")
    }

    /// Capture stand-in (note-editor precedent): C-066's presentation mounts after the first frame
    /// and slides in on appear, so a snapshot never sees it. Beneath the capture element map only,
    /// the screen draws the presented layer at rest exactly as `actionMenuPresentation` lays it out
    /// — its dim, then the card `ActionMenuMotion.edgeInset` from the sides and bottom.
    private var captureDeleteConfirm: some View {
        ZStack(alignment: .bottom) {
            Token.black80
                .ignoresSafeArea()
                .ui2Element("Dim")
            deleteConfirmCard
                .padding(.horizontal, ActionMenuMotion.edgeInset)
                .padding(.bottom, ActionMenuMotion.edgeInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: - §2 item 1 — nav (C-040 PageHeader)

    private var navChrome: some View {
        // §2 item 1: "style `.twoIcons`, `leadingGlyph = .back`, `rightButtons = [.threeDots]`,
        // no title in the bar" — laid out by C-040 itself, as group-detail / enrollment-home use it.
        PageHeader(
            style: .twoIcons,
            title: nil,
            showTitle: false,
            showIcons: true,
            // C-040 `showsDone` (owner, 2026-11-21): the done check shows while renaming.
            showsDone: renaming,
            leadingGlyph: .back,
            rightButtons: [.threeDots],
            onLeading: onBack,
            onRightButton: { _ in menuPresented = true },
            // The check commits the rename and dismisses the keyboard (§3 interaction 3).
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
            // §2: "a one-line text field in the same type with the caret in `color-accent`, no
            // box, no border".
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
                // §3 interaction 3: "a tap on the title" enters renaming.
                .onTapGesture { renaming = true }
                .ui2Element("Title")
        }
    }

    // MARK: - §2 item 3 — player block

    private var playerBlock: some View {
        VStack(spacing: Token.Space.rowGap) {
            ScrubTrack(
                elapsed: state.elapsed,
                duration: state.duration,
                dragging: dragging,
                enabled: state.playerReady,
                onSeek: onSeek,
                onDraggingChange: { dragging = $0; onDraggingChange($0) }
            )
            .ui2Element("C-004 ScrubTrack")
            TransportControls(
                playing: state.playing,
                enabled: state.playerReady,
                onPlayingChange: onPlayingChange,
                onSkipBack: onSkipBack,
                onSkipForward: onSkipForward
            )
            .ui2Element("C-014 TransportControls")
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: - §2 item 4 — transcript

    @ViewBuilder
    private var transcriptArea: some View {
        switch state.transcript {
        case .paragraphs:
            // §2 Scroll: "only the transcript scrolls, vertically, clipped under the player block".
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Token.Space.rowGap) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        paragraphView(paragraph, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Token.Space.pageMargin)
                // §2: "Bottom content inset = the home-indicator safe area + `space-page-margin`".
                .padding(.bottom, Token.Space.pageMargin)
            }
            .scrollIndicators(.hidden)
        case .transcribing:
            statusLine(Text("Transcribing…").italic())
        case .unavailable:
            statusLine(Text("No transcript for this memo"))
        }
    }

    /// §2: timestamp (`type-caption`, secondary, monospaced digits), `space-meta-gap`, then the
    /// text (`type-body-sm`) — primary when highlighted, secondary otherwise. One tap target.
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

    /// §3: "the one whose start ≤ elapsed < the next one's start (the last runs to the end)".
    private var currentParagraph: Int? {
        paragraphs.lastIndex { $0.start <= state.elapsed }
    }

    // MARK: - §2 meta line

    /// `«date label» «time» · «duration»`.
    private var metaLine: String {
        "\(state.dateLabel) · \(Self.clock(Int(max(state.duration, 0).rounded())))"
    }

    /// §2: `m:ss`, `h:mm:ss` from one hour.
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
    private static let menuActions = [renameAction, deleteAction]

    private func chooseMenuAction(_ action: ActionMenuOverlay.ActionItem) {
        menuPresented = false
        if action.id == Self.renameAction.id {
            renaming = true
        } else {
            deleteConfirmPresented = true
        }
    }

    /// §3 interaction 3: 1–120 characters after trim (SPEC D8); an empty title reverts.
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

    /// SPEC D8: the server's title limit.
    private static let titleLimit = 120
}

// MARK: - Previews (§3 shared fixture: "Memo 3", today 7:43 PM, 16 s, segments 0:00 · 0:06 · 0:11;
// segment text from library-home's Memo 3 sample rows)

private extension MemoDetailScreen.State {
    static let sampleStarts: [Double] = [0, 6, 11]
    static let sampleTexts = [
        "So the main thing I want to say this Sunday is about rest",
        "Start with verse 28 and work backwards to the context.",
        "What does rest look like this week?",
    ]

    static func sample(
        elapsed: Double = 0,
        playing: Bool = false,
        transcript: Transcript = .paragraphs,
        renaming: Bool = false,
        deleteConfirmPresented: Bool = false
    ) -> Self {
        .init(
            title: "Memo 3",
            dateLabel: "Today 7:43 PM",
            duration: 16,
            elapsed: elapsed,
            playing: playing,
            transcript: transcript,
            paragraphStarts: transcript == .paragraphs ? sampleStarts : [],
            paragraphTexts: transcript == .paragraphs ? sampleTexts : [],
            renaming: renaming,
            deleteConfirmPresented: deleteConfirmPresented
        )
    }
}

#Preview("ready-paused") {
    MemoDetailScreen(state: .sample())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("playing") {
    MemoDetailScreen(state: .sample(elapsed: 7, playing: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("transcribing") {
    MemoDetailScreen(state: .sample(transcript: .transcribing))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("audio-only") {
    MemoDetailScreen(state: .sample(transcript: .unavailable))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("waiting-to-upload") {
    MemoDetailScreen(state: .sample())
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("renaming") {
    MemoDetailScreen(state: .sample(renaming: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("delete-confirm") {
    MemoDetailScreen(state: .sample(deleteConfirmPresented: true))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
