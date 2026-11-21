//
//  MarkdownTextEditor.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-001-markdown-text-editor in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//
//  No Figma reference exists or will (OQ-C-001-001): §2's geometry is the notes analysis's
//  written measurements (01 §3.2, made normative by DECISIONS §5), and the first accepted
//  capture is the reference the owner approves by eye.
//

import SwiftUI
import UIKit

// MARK: - The live document's attributes (N9)

/// The notes feature's paragraph style (C-001 §4 `text`: "a paragraph-style attribute (Title /
/// Body / Bulleted / Numbered)"; DECISIONS N1). Exactly one per paragraph. Declared here, beside
/// `InlineStyle` (C-002) and `ListStyle` (C-015), per OQ-C-001-10: every MakeReadyUI file also
/// compiles into the app target (D63), so the app's codec and containers use them from here.
enum NoteParagraphStyle: String, CaseIterable, Hashable {
    case title
    case body
    case bulleted
    case numbered
}

/// The paragraph-style attribute of the live `AttributedString` (C-001 §4 `text`).
enum NoteParagraphStyleAttribute: AttributedStringKey {
    typealias Value = NoteParagraphStyle
    static let name = "makeready.noteParagraphStyle"
}

/// The character-style attribute of the live `AttributedString`: the B/I/U/S set a run carries
/// (DECISIONS N1; 02 §2 "character attributes … freely overlapping").
enum NoteInlineStylesAttribute: AttributedStringKey {
    typealias Value = Set<InlineStyle>
    static let name = "makeready.noteInlineStyles"
}

// MARK: - C-001 MarkdownTextEditor

/// C-001 MarkdownTextEditor — the note canvas: a TextKit 2 `UITextView` wrapped for SwiftUI (N9),
/// with C-002 FormatStrip docked as its `inputAccessoryView`.
///
/// Controlled (R-01): `text` and `selection` are the caller's, and every edit leaves through
/// `onTextChange` / `onSelectionChange` (R-03). `editing` drives first responder. The caret-run
/// active set handed to C-002 is derived from the attributes at the caret, never stored (R-30).
/// No side effects (R-04): autosave, navigation and C-015's presentation are the caller's.
/// It fills the width and height it is given and paints no background (R-16).
struct MarkdownTextEditor: View {

    /// §4 `text` — the live document (N9). Required.
    let text: AttributedString
    /// §4 `onTextChange` — every edit. No render effect.
    var onTextChange: (AttributedString) -> Void = { _ in }
    /// §4 `selection` — the caret or selection, in UTF-16 offsets. Required.
    let selection: NSRange
    /// §4 `onSelectionChange` — the caret or selection moved. No render effect.
    var onSelectionChange: (NSRange) -> Void = { _ in }
    /// §4 `editing` — true: first responder, keyboard and C-002 up; false: read mode. Required.
    let editing: Bool
    /// §4 `onEditingChange` — became or resigned first responder (OQ-C-001-006). No render effect.
    var onEditingChange: (Bool) -> Void = { _ in }
    /// §4 `listMenuPresented` — C-015 is open; passed to C-002, which hides its row. Required.
    let listMenuPresented: Bool
    /// §4 `topContentInset` — the caller's floating chrome height; content scrolls under it.
    let topContentInset: CGFloat
    /// §4 `undoRequest` — each increment performs one undo (OQ-C-001-002). Required.
    let undoRequest: Int
    /// §4 `onCanUndoChange` — the undo stack became empty or non-empty. No render effect.
    var onCanUndoChange: (Bool) -> Void = { _ in }
    /// §4 `onListMenu` — C-002's list-slot frame; the caller presents C-015 there. No render effect.
    var onListMenu: (CGRect) -> Void = { _ in }
    /// §4 `listRequest` — each increment applies `listRequestStyle` at the caret under the
    /// OQ-C-001-004 toggle rule; on an empty paragraph it sets the typing attributes (OQ-C-001-9).
    /// Required.
    let listRequest: Int
    /// §4 `listRequestStyle` — the style the next `listRequest` increment applies; nil until the
    /// first request (OQ-C-001-9). Required.
    let listRequestStyle: ListStyle?

    var body: some View {
        NoteTextViewRepresentable(editor: self)
            .ui2Element("MarkdownTextEditor")
    }

    /// §4 pure helper: the document with `style` applied to (or, per OQ-C-001-004, removed from)
    /// the paragraphs `selection` touches. Choosing the paragraph's current style removes the list
    /// (a flush-left Body line); choosing the other style converts it. No side effects (R-04).
    static func applyingList(_ style: ListStyle, to text: AttributedString, at selection: NSRange) -> AttributedString {
        let storage = NoteDisplay.displayString(for: text)
        let target: NoteParagraphStyle = style == .bulleted ? .bulleted : .numbered
        let paragraphs = NoteDisplay.paragraphRanges(in: storage, touching: selection)
        let allTarget = !paragraphs.isEmpty
            && paragraphs.allSatisfy { NoteDisplay.paragraphStyle(in: storage, at: $0.location) == target }
        for range in paragraphs where range.length > 0 {
            storage.addAttribute(NoteDisplay.paragraphKey, value: (allTarget ? NoteParagraphStyle.body : target).rawValue, range: range)
        }
        NoteDisplay.normalize(storage)
        return NoteDisplay.model(from: storage)
    }
}

// MARK: - Geometry and type (§2)

private enum NoteGeometry {
    /// FLAGGED LITERAL — C-001 §2 FL-1: horizontal text inset 29 pt each side (01 §3.2, R2); no token (OQ-C-001-007).
    static let textInset: CGFloat = 29
    /// FLAGGED LITERAL — C-001 §2 FL-2: Title SF Pro Bold 28 (01 §3.2 "~28 pt bold"); no token (OQ-C-001-007).
    static let titleSize: CGFloat = 28
    /// FLAGGED LITERAL — C-001 §2 FL-2: Title leading 34 (the iOS Title1 metric, inferred); no token.
    static let titleLineHeight: CGFloat = 34
    /// FLAGGED LITERAL — C-001 §2 FL-3: list marker 18 pt past the text inset (01: bullet x ≈ 47 pt); no token.
    static let markerOffset: CGFloat = 18
    /// FLAGGED LITERAL — C-001 §2 FL-4: list item text 35 pt past the text inset (01: text x ≈ 64 pt); no token.
    static let itemIndent: CGFloat = 35
    /// C-002 §2 FL-1's 43 pt capsule: the accessory's height is the strip's own.
    static let stripHeight: CGFloat = 43
}

// MARK: - Model ↔ display

/// Converts the live model (`AttributedString` with the two note attributes) to the text view's
/// storage and back. Display attributes (font, colour, indent, underline, strikethrough) are
/// always DERIVED from the note attributes, so the model never carries a font.
private enum NoteDisplay {
    static let paragraphKey = NSAttributedString.Key("makeready.noteParagraphStyle")
    static let inlineKey = NSAttributedString.Key("makeready.noteInlineStyles")
    static let ordinalKey = NSAttributedString.Key("makeready.noteListOrdinal")

    static func displayString(for text: AttributedString) -> NSMutableAttributedString {
        let out = NSMutableAttributedString()
        for run in text.runs {
            var attributes: [NSAttributedString.Key: Any] = [
                paragraphKey: (run[NoteParagraphStyleAttribute.self] ?? .body).rawValue,
            ]
            let inline = run[NoteInlineStylesAttribute.self] ?? []
            if !inline.isEmpty { attributes[inlineKey] = encode(inline) }
            if let link = run.link { attributes[.link] = link }
            out.append(NSAttributedString(string: String(text[run.range].characters), attributes: attributes))
        }
        normalize(out)
        return out
    }

    static func model(from storage: NSAttributedString) -> AttributedString {
        var out = AttributedString()
        let whole = NSRange(location: 0, length: storage.length)
        storage.enumerateAttributes(in: whole) { attributes, range, _ in
            var piece = AttributedString(storage.attributedSubstring(from: range).string)
            piece[NoteParagraphStyleAttribute.self] = NoteParagraphStyle(rawValue: attributes[paragraphKey] as? String ?? "") ?? .body
            let inline = decode(attributes[inlineKey])
            if !inline.isEmpty { piece[NoteInlineStylesAttribute.self] = inline }
            if let url = attributes[.link] as? URL {
                piece.link = url
            } else if let string = attributes[.link] as? String, let url = URL(string: string) {
                piece.link = url
            }
            out.append(piece)
        }
        return out
    }

    static func encode(_ styles: Set<InlineStyle>) -> String {
        styles.map(\.rawValue).sorted().joined(separator: ",")
    }

    static func decode(_ value: Any?) -> Set<InlineStyle> {
        guard let string = value as? String, !string.isEmpty else { return [] }
        return Set(string.split(separator: ",").compactMap { InlineStyle(rawValue: String($0)) })
    }

    static func paragraphStyle(in storage: NSAttributedString, at location: Int) -> NoteParagraphStyle {
        guard location < storage.length else { return .body }
        return NoteParagraphStyle(rawValue: storage.attribute(paragraphKey, at: location, effectiveRange: nil) as? String ?? "") ?? .body
    }

    /// Every paragraph's range, newline included.
    static func paragraphRanges(in storage: NSAttributedString) -> [NSRange] {
        let string = storage.string as NSString
        var ranges: [NSRange] = []
        var location = 0
        while location < string.length {
            let range = string.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(range)
            location = NSMaxRange(range)
        }
        return ranges
    }

    static func paragraphRanges(in storage: NSAttributedString, touching selection: NSRange) -> [NSRange] {
        let string = storage.string as NSString
        let clamped = NSRange(location: min(selection.location, string.length), length: 0)
        let covered = string.paragraphRange(for: NSRange(
            location: clamped.location,
            length: min(selection.length, string.length - clamped.location)
        ))
        return paragraphRanges(in: storage).filter { NSIntersectionRange($0, covered).length > 0 }
    }

    static func contentLength(of range: NSRange, in storage: NSAttributedString) -> Int {
        guard range.length > 0 else { return 0 }
        let last = (storage.string as NSString).character(at: NSMaxRange(range) - 1)
        return last == 0x0A || last == 0x2029 ? range.length - 1 : range.length
    }

    /// The paragraph rules, re-run after every edit: one style per paragraph; the first non-empty
    /// paragraph is always Title and no other is (§2 behaviour 1, R7); numbered items count by
    /// position. Then the display attributes are re-derived.
    static func normalize(_ storage: NSMutableAttributedString) {
        storage.beginEditing()
        var foundTitle = false
        var ordinal = 0
        for range in paragraphRanges(in: storage) {
            var style = paragraphStyle(in: storage, at: range.location)
            if !foundTitle, contentLength(of: range, in: storage) > 0 {
                style = .title
                foundTitle = true
            } else if style == .title {
                style = .body
            }
            ordinal = style == .numbered ? ordinal + 1 : 0
            storage.addAttribute(paragraphKey, value: style.rawValue, range: range)
            if style == .numbered {
                storage.addAttribute(ordinalKey, value: ordinal, range: range)
            } else {
                storage.removeAttribute(ordinalKey, range: range)
            }
        }
        restyle(storage)
        storage.endEditing()
    }

    static func restyle(_ storage: NSMutableAttributedString) {
        let whole = NSRange(location: 0, length: storage.length)
        storage.enumerateAttributes(in: whole) { attributes, range, _ in
            let style = NoteParagraphStyle(rawValue: attributes[paragraphKey] as? String ?? "") ?? .body
            let derived = displayAttributes(paragraph: style, inline: decode(attributes[inlineKey]))
            storage.removeAttribute(.underlineStyle, range: range)
            storage.removeAttribute(.strikethroughStyle, range: range)
            storage.addAttributes(derived, range: range)
        }
    }

    /// §2's type-and-colour table, plus B/I/U/S on top of any paragraph style.
    static func displayAttributes(paragraph: NoteParagraphStyle, inline: Set<InlineStyle>) -> [NSAttributedString.Key: Any] {
        let body = Token.TypeStyle.bodyLg
        let base: UIFont
        let lineHeight: CGFloat
        if paragraph == .title {
            base = UIFont.systemFont(ofSize: NoteGeometry.titleSize, weight: .bold)
            lineHeight = NoteGeometry.titleLineHeight
        } else {
            base = UIFont.systemFont(ofSize: body.size, weight: uiWeight(body.weight))
            lineHeight = body.lineHeight ?? body.size
        }
        var traits = base.fontDescriptor.symbolicTraits
        if inline.contains(.bold) { traits.insert(.traitBold) }
        if inline.contains(.italic) { traits.insert(.traitItalic) }
        let font = base.fontDescriptor.withSymbolicTraits(traits).map { UIFont(descriptor: $0, size: base.pointSize) } ?? base

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.paragraphSpacing = 0
        if paragraph == .bulleted || paragraph == .numbered {
            paragraphStyle.firstLineHeadIndent = NoteGeometry.itemIndent
            paragraphStyle.headIndent = NoteGeometry.itemIndent
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(Token.textPrimary),
            .paragraphStyle: paragraphStyle,
        ]
        if inline.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if inline.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    /// The typing attributes for a paragraph style and inline set: note keys plus display keys.
    static func typingAttributes(paragraph: NoteParagraphStyle, inline: Set<InlineStyle>) -> [NSAttributedString.Key: Any] {
        var attributes = displayAttributes(paragraph: paragraph, inline: inline)
        attributes[paragraphKey] = paragraph.rawValue
        if !inline.isEmpty { attributes[inlineKey] = encode(inline) }
        return attributes
    }

    static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        let pairs: [(Font.Weight, UIFont.Weight)] = [
            (.ultraLight, .ultraLight), (.thin, .thin), (.light, .light), (.regular, .regular),
            (.medium, .medium), (.semibold, .semibold), (.bold, .bold), (.heavy, .heavy), (.black, .black),
        ]
        return pairs.first { $0.0 == weight }?.1 ?? .regular
    }
}

// MARK: - The strip's hosted state

/// What the docked C-002 reads. A mirror of derived values (R-30), refreshed by the coordinator on
/// every caret move; never a designed state of its own.
@Observable
private final class NoteStripState {
    var activeStyles: Set<InlineStyle> = []
    var listMenuPresented = false
}

private struct NoteStripAccessory: View {
    let state: NoteStripState
    let onToggle: (InlineStyle) -> Void
    let onListMenu: (CGRect) -> Void

    var body: some View {
        FormatStrip(
            activeStyles: state.activeStyles,
            listMenuPresented: state.listMenuPresented,
            onToggle: onToggle,
            onListMenu: onListMenu
        )
        // C-001 §2 FL-5 (revised 2026-11-21): the strip hugs its 287 pt row and is centred
        // horizontally, no side insets, flush (0 pt) above the keyboard. C-015's anchor is the
        // list slot's global frame (C-002 `onListMenu`), so it follows the centred strip.
        .frame(maxWidth: .infinity)
    }
}

// MARK: - The text view

/// The note's `UITextView`. Paste keeps only B/I/U/S and never converts markdown (OQ-C-001-005).
private final class NoteTextView: UITextView {
    var onPasteInline: ((NSRange, [(NSRange, Set<InlineStyle>)]) -> Void)?

    override func paste(_ sender: Any?) {
        let board = UIPasteboard.general
        guard let rtf = board.data(forPasteboardType: "public.rtf"),
              let rich = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        else {
            super.paste(sender)
            return
        }
        let start = selectedRange.location
        var runs: [(NSRange, Set<InlineStyle>)] = []
        rich.enumerateAttributes(in: NSRange(location: 0, length: rich.length)) { attributes, range, _ in
            var styles = Set<InlineStyle>()
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { styles.insert(.bold) }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { styles.insert(.italic) }
            }
            if (attributes[.underlineStyle] as? Int ?? 0) != 0 { styles.insert(.underline) }
            if (attributes[.strikethroughStyle] as? Int ?? 0) != 0 { styles.insert(.strikethrough) }
            runs.append((NSRange(location: start + range.location, length: range.length), styles))
        }
        if let range = selectedTextRange { replace(range, withText: rich.string) }
        onPasteInline?(NSRange(location: start, length: (rich.string as NSString).length), runs)
    }
}

/// Draws a list paragraph's marker (`•`, or `1.` `2.` … by position) at FL-3, so the marker is
/// never a character in the document and the caller's UTF-16 offsets stay the text's own.
private final class NoteListFragment: NSTextLayoutFragment {
    var marker: NSAttributedString?

    private var markerRect: CGRect {
        guard let marker, let line = textLineFragments.first else { return .zero }
        let size = marker.boundingRect(with: CGSize(width: 200, height: 200), options: [.usesLineFragmentOrigin], context: nil).size
        // The item text starts FL-4 past the inset and the marker FL-3 past it, so the marker sits
        // FL-4 − FL-3 before the first line's own start, whatever origin the fragment reports.
        let x = line.typographicBounds.minX - (NoteGeometry.itemIndent - NoteGeometry.markerOffset)
        return CGRect(x: x, y: line.typographicBounds.minY, width: ceil(size.width), height: line.typographicBounds.height)
    }

    override var renderingSurfaceBounds: CGRect {
        marker == nil ? super.renderingSurfaceBounds : super.renderingSurfaceBounds.union(markerRect)
    }

    override func draw(at point: CGPoint, in context: CGContext) {
        super.draw(at: point, in: context)
        guard let marker else { return }
        let rect = markerRect.offsetBy(dx: point.x, dy: point.y)
        UIGraphicsPushContext(context)
        marker.draw(with: rect, options: [.usesLineFragmentOrigin], context: nil)
        UIGraphicsPopContext()
    }
}

private struct NoteTextViewRepresentable: UIViewRepresentable {
    let editor: MarkdownTextEditor

    func makeCoordinator() -> Coordinator { Coordinator(editor: editor) }

    func makeUIView(context: Context) -> NoteTextView {
        let textView = NoteTextView(usingTextLayoutManager: true)
        let coordinator = context.coordinator
        coordinator.textView = textView
        textView.delegate = coordinator
        textView.textLayoutManager?.delegate = coordinator
        // §2: no border, no background (R-16), no placeholder (R2).
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.contentInsetAdjustmentBehavior = .never
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .none
        // Deviation 1: the system caret, selection wash and handles, tinted `color-accent`.
        textView.tintColor = UIColor(Token.accent)
        // §2 behaviour 6 (R5): default keyboard, no custom inputView; C-002 is the only accessory.
        textView.keyboardType = .default
        textView.inputAccessoryView = coordinator.makeAccessory()
        // §2 Accessibility (R-17): native text traits, labelled "Note".
        textView.accessibilityLabel = "Note"
        textView.onPasteInline = { [weak coordinator] range, runs in coordinator?.applyPastedStyles(range, runs) }
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.readModeTap(_:)))
        tap.delegate = coordinator
        textView.addGestureRecognizer(tap)
        coordinator.readTap = tap

        coordinator.load(editor.text)
        coordinator.lastUndoRequest = editor.undoRequest
        coordinator.lastListRequest = editor.listRequest
        coordinator.apply(editor)
        return textView
    }

    func updateUIView(_ textView: NoteTextView, context: Context) {
        context.coordinator.apply(editor)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, NSTextLayoutManagerDelegate, UIGestureRecognizerDelegate {
        var editor: MarkdownTextEditor
        weak var textView: NoteTextView?
        weak var readTap: UITapGestureRecognizer?
        var lastUndoRequest = 0
        var lastListRequest = 0
        private var lastKnownText = AttributedString()
        private var lastCanUndo = false
        private var applying = false
        private let stripState = NoteStripState()
        /// Retained so the docked C-002 keeps updating; the text view holds only its view.
        private var accessoryHost: UIHostingController<NoteStripAccessory>?

        init(editor: MarkdownTextEditor) { self.editor = editor }

        // MARK: Props in

        func makeAccessory() -> UIView {
            let host = UIHostingController(rootView: NoteStripAccessory(
                state: stripState,
                onToggle: { [weak self] in self?.toggle($0) },
                onListMenu: { [weak self] in self?.editor.onListMenu($0) }
            ))
            host.view.backgroundColor = .clear
            host.view.frame = CGRect(x: 0, y: 0, width: 0, height: NoteGeometry.stripHeight)
            host.view.autoresizingMask = [.flexibleWidth]
            accessoryHost = host
            return host.view
        }

        func load(_ text: AttributedString) {
            guard let textView else { return }
            let display = NoteDisplay.displayString(for: text)
            applying = true
            textView.attributedText = display
            applying = false
            lastKnownText = text
            if display.length == 0 {
                textView.typingAttributes = NoteDisplay.typingAttributes(paragraph: .title, inline: [])
            }
        }

        func apply(_ editor: MarkdownTextEditor) {
            self.editor = editor
            guard let textView else { return }
            if editor.text != lastKnownText { load(editor.text) }

            var inset = textView.textContainerInset
            inset.top = editor.topContentInset
            inset.left = NoteGeometry.textInset
            inset.right = NoteGeometry.textInset
            inset.bottom = 0
            if inset != textView.textContainerInset { textView.textContainerInset = inset }

            let length = (textView.text as NSString).length
            let location = min(max(editor.selection.location, 0), length)
            let wanted = NSRange(location: location, length: min(max(editor.selection.length, 0), length - location))
            if textView.selectedRange != wanted {
                applying = true
                textView.selectedRange = wanted
                applying = false
            }

            if editor.undoRequest > lastUndoRequest {
                for _ in lastUndoRequest..<editor.undoRequest where textView.undoManager?.canUndo == true {
                    textView.undoManager?.undo()
                }
            }
            lastUndoRequest = editor.undoRequest

            if editor.listRequest > lastListRequest, let style = editor.listRequestStyle {
                applyListRequest(style)
            }
            lastListRequest = editor.listRequest

            stripState.listMenuPresented = editor.listMenuPresented
            refreshActiveStyles()

            // §2 Edit vs read: editing = first responder with keyboard and strip; read = neither.
            textView.isEditable = editor.editing
            readTap?.isEnabled = !editor.editing
            if editor.editing, !textView.isFirstResponder {
                DispatchQueue.main.async { [weak textView] in textView?.becomeFirstResponder() }
            } else if !editor.editing, textView.isFirstResponder {
                DispatchQueue.main.async { [weak textView] in textView?.resignFirstResponder() }
            }
        }

        // MARK: Edits out

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // §2 behaviour 2 (02 §2): Return on an empty list item removes the list style from
            // that paragraph instead of inserting a new item.
            guard text == "\n", range.length == 0 else { return true }
            let storage = textView.textStorage
            let paragraph = (storage.string as NSString).paragraphRange(for: range)
            let style = paragraph.length > 0
                ? NoteDisplay.paragraphStyle(in: storage, at: paragraph.location)
                : NoteParagraphStyle(rawValue: textView.typingAttributes[NoteDisplay.paragraphKey] as? String ?? "") ?? .body
            guard style == .bulleted || style == .numbered,
                  NoteDisplay.contentLength(of: paragraph, in: storage) == 0 else { return true }
            let inline = NoteDisplay.decode(textView.typingAttributes[NoteDisplay.inlineKey])
            if paragraph.length > 0 {
                storage.addAttribute(NoteDisplay.paragraphKey, value: NoteParagraphStyle.body.rawValue, range: paragraph)
                NoteDisplay.normalize(storage)
            }
            textView.typingAttributes = NoteDisplay.typingAttributes(paragraph: .body, inline: inline)
            emitText()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            // Never restyle under marked (IME) text.
            if textView.markedTextRange == nil {
                let selection = textView.selectedRange
                NoteDisplay.normalize(textView.textStorage)
                if textView.selectedRange != selection { textView.selectedRange = selection }
            }
            emitText()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            refreshActiveStyles()
            guard !applying else { return }
            editor.onSelectionChange(textView.selectedRange)
        }

        func textViewDidBeginEditing(_ textView: UITextView) { editor.onEditingChange(true) }
        func textViewDidEndEditing(_ textView: UITextView) { editor.onEditingChange(false) }

        private func emitText() {
            guard let textView else { return }
            let model = NoteDisplay.model(from: textView.textStorage)
            lastKnownText = model
            editor.onTextChange(model)
            refreshActiveStyles()
            let canUndo = textView.undoManager?.canUndo ?? false
            if canUndo != lastCanUndo {
                lastCanUndo = canUndo
                editor.onCanUndoChange(canUndo)
            }
        }

        // MARK: Inline styles (§2 behaviours 3–4)

        /// The caret-run active set (02 §2): the typing attributes at an empty caret, else the
        /// styles every character of the selection carries.
        private func activeStyles() -> Set<InlineStyle> {
            guard let textView else { return [] }
            let selection = textView.selectedRange
            guard selection.length > 0 else { return NoteDisplay.decode(textView.typingAttributes[NoteDisplay.inlineKey]) }
            var result: Set<InlineStyle>?
            textView.textStorage.enumerateAttribute(NoteDisplay.inlineKey, in: selection) { value, _, _ in
                let styles = NoteDisplay.decode(value)
                result = result.map { $0.intersection(styles) } ?? styles
            }
            return result ?? []
        }

        private func refreshActiveStyles() {
            let styles = activeStyles()
            if stripState.activeStyles != styles { stripState.activeStyles = styles }
        }

        func toggle(_ style: InlineStyle) {
            guard let textView else { return }
            let selection = textView.selectedRange
            let adding = !activeStyles().contains(style)
            if selection.length > 0 {
                let storage = textView.textStorage
                storage.beginEditing()
                storage.enumerateAttribute(NoteDisplay.inlineKey, in: selection) { value, range, _ in
                    var styles = NoteDisplay.decode(value)
                    if adding { styles.insert(style) } else { styles.remove(style) }
                    if styles.isEmpty {
                        storage.removeAttribute(NoteDisplay.inlineKey, range: range)
                    } else {
                        storage.addAttribute(NoteDisplay.inlineKey, value: NoteDisplay.encode(styles), range: range)
                    }
                }
                NoteDisplay.restyle(storage)
                storage.endEditing()
                textView.selectedRange = selection
                emitText()
            } else {
                var styles = NoteDisplay.decode(textView.typingAttributes[NoteDisplay.inlineKey])
                if adding { styles.insert(style) } else { styles.remove(style) }
                let paragraph = NoteParagraphStyle(rawValue: textView.typingAttributes[NoteDisplay.paragraphKey] as? String ?? "") ?? .body
                textView.typingAttributes = NoteDisplay.typingAttributes(paragraph: paragraph, inline: styles)
                refreshActiveStyles()
            }
        }

        // MARK: List requests (OQ-C-001-9)

        /// Applies `style` at the caret under the OQ-C-001-004 toggle rule: the paragraph's current
        /// style removes the list (a flush-left Body line), the other style converts it. A paragraph
        /// with content takes it as its attribute; an empty one (including the empty last line,
        /// which has no character to carry it) takes it in the typing attributes, plus on its
        /// newline when it has one, so the marker draws.
        private func applyListRequest(_ style: ListStyle) {
            guard let textView else { return }
            let storage = textView.textStorage
            let target: NoteParagraphStyle = style == .bulleted ? .bulleted : .numbered
            let inline = NoteDisplay.decode(textView.typingAttributes[NoteDisplay.inlineKey])
            let selection = textView.selectedRange
            let paragraphs = NoteDisplay.paragraphRanges(in: storage, touching: selection)
            let hasContent = paragraphs.contains { NoteDisplay.contentLength(of: $0, in: storage) > 0 }

            guard hasContent else {
                let current = NoteParagraphStyle(rawValue: textView.typingAttributes[NoteDisplay.paragraphKey] as? String ?? "") ?? .body
                let next: NoteParagraphStyle = current == target ? .body : target
                if let range = paragraphs.first, range.length > 0 {
                    storage.addAttribute(NoteDisplay.paragraphKey, value: next.rawValue, range: range)
                    NoteDisplay.normalize(storage)
                    textView.selectedRange = selection
                }
                textView.typingAttributes = NoteDisplay.typingAttributes(paragraph: next, inline: inline)
                emitText()
                return
            }

            let allTarget = paragraphs.allSatisfy { NoteDisplay.paragraphStyle(in: storage, at: $0.location) == target }
            for range in paragraphs where range.length > 0 {
                storage.addAttribute(NoteDisplay.paragraphKey, value: (allTarget ? NoteParagraphStyle.body : target).rawValue, range: range)
            }
            NoteDisplay.normalize(storage)
            textView.selectedRange = selection
            emitText()
        }

        func applyPastedStyles(_ range: NSRange, _ runs: [(NSRange, Set<InlineStyle>)]) {
            guard let textView else { return }
            let storage = textView.textStorage
            storage.beginEditing()
            for (run, styles) in runs where NSMaxRange(run) <= storage.length {
                if styles.isEmpty {
                    storage.removeAttribute(NoteDisplay.inlineKey, range: run)
                } else {
                    storage.addAttribute(NoteDisplay.inlineKey, value: NoteDisplay.encode(styles), range: run)
                }
            }
            storage.endEditing()
            NoteDisplay.normalize(storage)
            emitText()
        }

        // MARK: Read mode (OQ-C-001-006)

        /// A tap on text in read mode places the caret there and asks to edit; a link tap is left
        /// to the system's link interaction.
        @objc func readModeTap(_ gesture: UITapGestureRecognizer) {
            guard let textView, let position = textView.closestPosition(to: gesture.location(in: textView)) else { return }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            editor.onSelectionChange(NSRange(location: offset, length: 0))
            editor.onEditingChange(true)
        }

        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard gesture === readTap, let textView,
                  let position = textView.closestPosition(to: gesture.location(in: textView)) else { return true }
            let offset = textView.offset(from: textView.beginningOfDocument, to: position)
            guard offset < textView.textStorage.length else { return true }
            return textView.textStorage.attribute(.link, at: offset, effectiveRange: nil) == nil
        }

        func gestureRecognizer(_ gesture: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        // MARK: List markers (§2 FL-3)

        nonisolated func textLayoutManager(
            _ textLayoutManager: NSTextLayoutManager,
            textLayoutFragmentFor location: NSTextLocation,
            in textElement: NSTextElement
        ) -> NSTextLayoutFragment {
            let fragment = NoteListFragment(textElement: textElement, range: textElement.elementRange)
            guard let paragraph = textElement as? NSTextParagraph, paragraph.attributedString.length > 0 else { return fragment }
            let attributes = paragraph.attributedString.attributes(at: 0, effectiveRange: nil)
            let style = NoteParagraphStyle(rawValue: attributes[NoteDisplay.paragraphKey] as? String ?? "") ?? .body
            let markerText: String
            switch style {
            case .bulleted: markerText = "•"
            case .numbered: markerText = "\((attributes[NoteDisplay.ordinalKey] as? Int) ?? 1)."
            case .title, .body: return fragment
            }
            var markerAttributes = NoteDisplay.displayAttributes(paragraph: .body, inline: [])
            if let paragraphStyle = markerAttributes[.paragraphStyle] as? NSParagraphStyle,
               let plain = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle {
                plain.firstLineHeadIndent = 0
                plain.headIndent = 0
                markerAttributes[.paragraphStyle] = plain
            }
            fragment.marker = NSAttributedString(string: markerText, attributes: markerAttributes)
            return fragment
        }
    }
}
