//
//  NoteEditorScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen note-editor in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/notes/{noteId} · POST /api/notes ·
//  PATCH /api/notes/{noteId} · DELETE /api/notes/{noteId}
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Note Editor — the pushed full-screen note canvas (§2): C-001 MarkdownTextEditor edge to edge,
/// C-009 EditorNavChrome floating over it at the top safe area, C-002 FormatStrip docked by C-001
/// as its keyboard accessory, and C-015 ListStyleMenu over the strip's row while open.
///
/// Presentational (D6): the live document arrives in `State`; every edit leaves through
/// `onTextChange` (the container's `NoteAutosaveController` owns the debounced PATCH — §3
/// Autosave, R-04) and Back leaves through `onBack`. Editing, the selection, the undo flag and
/// the list popover are UI-only rules (§3 interactions 2–6) and are real local state here.
///
/// Capture stand-in: a snapshot draws no keyboard and no keyboard window, so C-001's
/// `inputAccessoryView` never reaches the image. Beneath the capture element map only (C-009's
/// capture-fallback precedent) the screen draws C-002 docked at the canvas bottom where the
/// keyboard's top edge would be, centred and content-hugging with no side inset, with C-015 over
/// it while open.
/// The app (no element map) never draws it — C-001 docks the real strip.
struct NoteEditorScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// C-001 `text` — the live document (N9). "" = §3 new-empty.
        var text: AttributedString
        /// C-001 `selection` — the caret or selection, UTF-16 offsets.
        var selection: NSRange
        /// C-001 / C-009 `editing` — §3: compose opens editing (R2); a reopened note does not
        /// (OQ-note-editor-2).
        var editing: Bool
        /// C-009 `canUndo` — the undo stack is non-empty (C-001 `onCanUndoChange`).
        var canUndo: Bool = false
        /// C-002 `activeStyles` — the caret run's B/I/U/S. The app's strip derives it inside C-001;
        /// only the capture stand-in reads this (§3 bold-active).
        var activeStyles: Set<InlineStyle> = []
        /// C-001 `listMenuPresented` — §3 list-menu-open: C-015 is over the strip's row.
        var listMenuPresented: Bool = false
    }

    let state: State
    /// §3 Autosave: every edit; the container debounces and PATCHes (R6, N5, N10, N13).
    var onTextChange: (AttributedString) -> Void = { _ in }
    /// §3 interaction 7: the container flushes autosave and pops.
    var onBack: () -> Void = {}

    // §3 interaction 1: "the first non-empty line is Title, live" — the editor's local document.
    @SwiftUI.State private var text: AttributedString
    @SwiftUI.State private var selection: NSRange
    // §3 interactions 5–6: Done sets `editing = false`; a tap on text re-enters editing.
    @SwiftUI.State private var editing: Bool
    // §3 interaction 4: "Undo shows while `editing && canUndo` (C-001 `onCanUndoChange`)".
    @SwiftUI.State private var canUndo: Bool
    @SwiftUI.State private var undoRequest = 0
    // §3 interaction 3: the list button presents C-015; choosing a row applies on the tap frame.
    @SwiftUI.State private var listMenuPresented: Bool
    @SwiftUI.State private var listMenuAnchor: CGRect = .zero
    @SwiftUI.State private var listRequest = 0
    @SwiftUI.State private var listRequestStyle: ListStyle?
    /// §2: the top safe area the canvas ignores and passes back as content inset.
    @SwiftUI.State private var topSafeArea: CGFloat = 0

    /// True only under the capture harness's element map (see the type's doc comment).
    @Environment(\.ui2ElementCollecting) private var captureStandIn

    init(
        state: State,
        onTextChange: @escaping (AttributedString) -> Void = { _ in },
        onBack: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onTextChange = onTextChange
        self.onBack = onBack
        _text = SwiftUI.State(initialValue: state.text)
        _selection = SwiftUI.State(initialValue: state.selection)
        _editing = SwiftUI.State(initialValue: state.editing)
        _canUndo = SwiftUI.State(initialValue: state.canUndo)
        _listMenuPresented = SwiftUI.State(initialValue: state.listMenuPresented)
    }

    var body: some View {
        // §2 layers, back to front: canvas, nav chrome, (strip — C-001's accessory), popover.
        ZStack(alignment: .top) {
            canvas
            navChrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            if captureStandIn && editing {
                captureStrip
            }
        }
        .overlay(alignment: .topLeading) {
            if !captureStandIn {
                presentedListMenu
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topSafeArea = $0 }
        // §2: "Full-screen pushed page on `color-layout-background`".
        .background(Token.layoutBackground)
    }

    // MARK: - §2 layer 1 — the canvas

    private var canvas: some View {
        MarkdownTextEditor(
            text: text,
            onTextChange: { text = $0; onTextChange($0) },
            selection: selection,
            onSelectionChange: { selection = $0 },
            editing: editing,
            onEditingChange: { editing = $0 },
            listMenuPresented: listMenuPresented,
            // §2 (OQ-note-editor-1): top safe area + C-009's 40 pt row + `space-element-gap`, so the
            // caret's first line starts 8 pt below the chrome row.
            topContentInset: topSafeArea + Self.chromeHeight + Token.Space.elementGap,
            undoRequest: undoRequest,
            onCanUndoChange: { canUndo = $0 },
            onListMenu: openListMenu,
            listRequest: listRequest,
            listRequestStyle: listRequestStyle
        )
        .ui2Element("C-001 MarkdownTextEditor")
        // §2: "It ignores the top safe area so text scrolls under the chrome."
        .ignoresSafeArea(.container, edges: .top)
    }

    // MARK: - §2 layer 2 — the nav chrome

    private var navChrome: some View {
        EditorNavChrome(
            editing: editing,
            canUndo: canUndo,
            onBack: onBack,
            // §3 interaction 4: one coalesced undo per tap.
            onUndo: { undoRequest += 1 },
            // §3 interaction 5: dismiss editing, never commit (R6).
            onDone: { editing = false }
        )
        .ui2Element("C-009 EditorNavChrome")
        // §2 (OQ-note-editor-1): pinned to the top safe area, `space-page-margin` each side.
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: - §2 layers 3–4 — strip stand-in and popover (capture)

    /// The capture stand-in for C-001's docked accessory (see the type's doc comment): the strip
    /// is C-002's own content-hugging capsule, centred, flush at the bottom, no side inset (§2),
    /// with C-015 replacing its row while open (C-015 §2: the strip's width, centred, its bottom
    /// edge on the strip's bottom edge, extending upward).
    private var captureStrip: some View {
        ZStack(alignment: .bottom) {
            FormatStrip(activeStyles: state.activeStyles, listMenuPresented: listMenuPresented)
                .ui2Element("C-002 FormatStrip")
            if listMenuPresented {
                ListStyleMenu(onSelect: chooseList, onDismiss: dismissListMenu)
                    .frame(width: Self.stripWidth)
                    .ui2Element("C-015 ListStyleMenu")
            }
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    /// §2 layer 4 in the app: C-015 over the docked strip's row, anchored to the list button's
    /// frame from C-002 `onListMenu` — centred, the strip's width, extending upward from the
    /// strip's row (§2 layer 4).
    private var presentedListMenu: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ListStyleMenu(onSelect: chooseList, onDismiss: dismissListMenu)
                    .listStyleMenuPresentation(
                        isPresented: listMenuPresented,
                        anchor: listMenuAnchor,
                        onDismiss: dismissListMenu
                    )
                    .ui2Element("C-015 ListStyleMenu")
            }
            .frame(
                width: min(proxy.size.width, Self.stripWidth),
                height: max(0, listMenuAnchor.maxY - origin.y)
            )
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .allowsHitTesting(listMenuPresented)
    }

    // MARK: - §3 interaction 3 — the list popover

    private func openListMenu(_ anchor: CGRect) {
        listMenuAnchor = anchor
        listMenuPresented = true
    }

    /// Applies on the tap frame (OQ-C-001-9), then dismisses.
    private func chooseList(_ style: ListStyle) {
        listRequestStyle = style
        listRequest += 1
        listMenuPresented = false
    }

    /// An outside tap dismisses with no change.
    private func dismissListMenu() {
        listMenuPresented = false
    }

    // MARK: - Geometry

    /// FLAGGED LITERAL — C-009 §2: the chrome row's intrinsic height (40 pt circles); no size token.
    private static let chromeHeight: CGFloat = 40
    /// C-002 §2: the strip's content-hugging width (3 + 5×37 + 4×24 + 3 = 287 pt) — C-002's own
    /// literal, not this screen's; C-015 takes it so it lines up with the strip (§2 layer 4).
    private static let stripWidth: CGFloat = 287
}

// MARK: - Sample data (§3 rows; text from 01 §3.7, the recording's final document)

private extension AttributedString {
    /// One paragraph of the note model: its paragraph style, and runs of (text, inline styles).
    static func noteParagraph(
        _ style: NoteParagraphStyle,
        _ runs: [(String, Set<InlineStyle>)],
        last: Bool = false
    ) -> AttributedString {
        var out = AttributedString()
        for (string, styles) in runs {
            var run = AttributedString(string)
            if !styles.isEmpty { run[NoteInlineStylesAttribute.self] = styles }
            out.append(run)
        }
        if !last { out.append(AttributedString("\n")) }
        out[NoteParagraphStyleAttribute.self] = style
        return out
    }

    static func note(_ paragraphs: [(NoteParagraphStyle, [(String, Set<InlineStyle>)])]) -> AttributedString {
        var out = AttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            out.append(noteParagraph(paragraph.0, paragraph.1, last: index == paragraphs.count - 1))
        }
        return out
    }
}

#Preview("new-empty") {
    NoteEditorScreen(state: .init(
        text: AttributedString(),
        selection: NSRange(location: 0, length: 0),
        editing: true
    ))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("typing") {
    let text = AttributedString.note([
        (.title, [("Note", [])]),
        (.body, [("", [])]),
        (.body, [("Here are my thoughts on the lesson", [])]),
    ])
    NoteEditorScreen(state: .init(
        text: text,
        selection: NSRange(location: text.characters.count, length: 0),
        editing: true,
        canUndo: true
    ))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("bold-active") {
    let text = AttributedString.note([
        (.title, [("Note", [])]),
        (.body, [("", [])]),
        (.body, [("Here are my thoughts on the lesson", [])]),
        (.bulleted, [("this is a bullet list", [])]),
        (.bulleted, [("here is another", [])]),
        (.body, [("", [])]),
        (.body, [("This is ", []), ("bold", [.bold])]),
    ])
    NoteEditorScreen(state: .init(
        text: text,
        selection: NSRange(location: text.characters.count - 4, length: 4),
        editing: true,
        canUndo: true,
        activeStyles: [.bold]
    ))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("list-menu-open") {
    let text = AttributedString.note([
        (.title, [("Note", [])]),
        (.body, [("", [])]),
        (.body, [("Here are my thoughts on the lesson", [])]),
        (.body, [("", [])]),
    ])
    NoteEditorScreen(state: .init(
        text: text,
        selection: NSRange(location: text.characters.count, length: 0),
        editing: true,
        canUndo: true,
        listMenuPresented: true
    ))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("reopened-read") {
    NoteEditorScreen(state: .init(
        text: .note([
            (.title, [("Note", [])]),
            (.body, [("", [])]),
            (.body, [("Here are my thoughts on the lesson", [])]),
            (.bulleted, [("this is a bullet list", [])]),
            (.bulleted, [("here is another", [])]),
            (.body, [("", [])]),
            (.body, [("This is ", []), ("bold", [.bold])]),
            (.body, [("", [])]),
            (.body, [("Just typing, watch the UI for styles", [])]),
        ]),
        selection: NSRange(location: 0, length: 0),
        editing: false
    ))
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
