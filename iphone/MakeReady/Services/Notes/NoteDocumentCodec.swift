import Foundation
import Markdown

/// The paragraph kind of a `NoteRun`: the test seam's spelling of d2m's `NoteParagraphStyle`.
enum NoteParagraphKind: Equatable {
    case title
    case body
    case bulleted
    case numbered
}

/// One styled run of one paragraph, the flat form of the document the codec tests read and build.
struct NoteRun: Equatable {
    var block: Int
    var text: String
    var paragraph: NoteParagraphKind
    var bold = false
    var italic = false
    var underline = false
    var strike = false
}

/// Converts a note's markdown (D4) to and from the editor's live `AttributedString` (C-001 §4),
/// which carries d2m's `NoteParagraphStyleAttribute` and `NoteInlineStylesAttribute` and nothing
/// else (D9). Paragraphs are joined by one "\n" that carries the paragraph's own style. Parse
/// once on open and serialize on autosave, never per keystroke.
enum NoteDocumentCodec {

    // MARK: - Public

    static func parse(_ markdown: String) -> AttributedString {
        let document = Markdown.Document(parsing: strippingHighlights(markdown))
        var paragraphs: [Paragraph] = []
        for block in document.children {
            appendBlock(block, to: &paragraphs)
        }
        paragraphs.removeAll { $0.isEmpty }
        // D5: the first non-empty paragraph is the title, whatever block it came from.
        if !paragraphs.isEmpty { paragraphs[0].style = .title }
        return attributedString(from: paragraphs)
    }

    static func serialize(_ doc: AttributedString) -> String {
        var paragraphs = paragraphs(of: doc).filter { !$0.isEmpty }
        for index in paragraphs.indices {
            paragraphs[index].style = index == 0 ? .title : (paragraphs[index].style == .title ? .body : paragraphs[index].style)
        }
        var out = ""
        var ordinal = 0
        for (index, paragraph) in paragraphs.enumerated() {
            ordinal = paragraph.style == .numbered ? ordinal + 1 : 0
            if index > 0 {
                let previous = paragraphs[index - 1].style
                let sameList = previous == paragraph.style && (previous == .bulleted || previous == .numbered)
                out += sameList ? "\n" : "\n\n"
            }
            out += prefix(for: paragraph.style, ordinal: ordinal) + inlineMarkdown(of: paragraph)
        }
        return out
    }

    static func runs(_ doc: AttributedString) -> [NoteRun] {
        var out: [NoteRun] = []
        for (block, paragraph) in paragraphs(of: doc).enumerated() {
            let kind = Self.kind(of: paragraph.style)
            if paragraph.pieces.isEmpty {
                out.append(NoteRun(block: block, text: "", paragraph: kind))
            }
            for piece in paragraph.pieces {
                out.append(NoteRun(
                    block: block, text: piece.text, paragraph: kind,
                    bold: piece.styles.contains(.bold), italic: piece.styles.contains(.italic),
                    underline: piece.styles.contains(.underline), strike: piece.styles.contains(.strikethrough)
                ))
            }
        }
        return out
    }

    static func document(_ runs: [NoteRun]) -> AttributedString {
        var paragraphs: [Paragraph] = []
        var currentBlock: Int?
        for run in runs {
            if run.block != currentBlock {
                paragraphs.append(Paragraph(style: style(of: run.paragraph)))
                currentBlock = run.block
            }
            guard !run.text.isEmpty else { continue }
            var styles = Set<InlineStyle>()
            if run.bold { styles.insert(.bold) }
            if run.italic { styles.insert(.italic) }
            if run.underline { styles.insert(.underline) }
            if run.strike { styles.insert(.strikethrough) }
            paragraphs[paragraphs.count - 1].pieces.append(Piece(text: run.text, styles: styles))
        }
        return attributedString(from: paragraphs)
    }

    // MARK: - Model

    private struct Piece {
        var text: String
        var styles: Set<InlineStyle>
    }

    private struct Paragraph {
        var style: NoteParagraphStyle
        var pieces: [Piece] = []

        var isEmpty: Bool { pieces.allSatisfy { $0.text.isEmpty } }
    }

    private static func kind(of style: NoteParagraphStyle) -> NoteParagraphKind {
        switch style {
        case .title: return .title
        case .body: return .body
        case .bulleted: return .bulleted
        case .numbered: return .numbered
        }
    }

    private static func style(of kind: NoteParagraphKind) -> NoteParagraphStyle {
        switch kind {
        case .title: return .title
        case .body: return .body
        case .bulleted: return .bulleted
        case .numbered: return .numbered
        }
    }

    // MARK: - AttributedString ⇄ paragraphs

    private static func attributedString(from paragraphs: [Paragraph]) -> AttributedString {
        var out = AttributedString()
        for (index, paragraph) in paragraphs.enumerated() {
            for piece in paragraph.pieces where !piece.text.isEmpty {
                var run = AttributedString(piece.text)
                run[NoteParagraphStyleAttribute.self] = paragraph.style
                if !piece.styles.isEmpty { run[NoteInlineStylesAttribute.self] = piece.styles }
                out.append(run)
            }
            if index < paragraphs.count - 1 {
                var newline = AttributedString("\n")
                newline[NoteParagraphStyleAttribute.self] = paragraph.style
                out.append(newline)
            }
        }
        return out
    }

    /// Splits the document at its "\n" characters. A paragraph's style is that of its first text
    /// run; an empty paragraph's is its own newline's, since the newline closing a paragraph
    /// carries that paragraph's style.
    private static func paragraphs(of doc: AttributedString) -> [Paragraph] {
        var paragraphs: [Paragraph] = []
        var current = Paragraph(style: .body)
        var styled = false
        for run in doc.runs {
            let style = run[NoteParagraphStyleAttribute.self] ?? .body
            let styles = run[NoteInlineStylesAttribute.self] ?? []
            let lines = String(doc[run.range].characters).components(separatedBy: "\n")
            for (lineIndex, line) in lines.enumerated() {
                if lineIndex > 0 {
                    if !styled { current.style = style }
                    paragraphs.append(current)
                    current = Paragraph(style: .body)
                    styled = false
                }
                guard !line.isEmpty else { continue }
                if !styled {
                    current.style = style
                    styled = true
                }
                current.pieces.append(Piece(text: line, styles: styles))
            }
        }
        if !styled && current.pieces.isEmpty && paragraphs.isEmpty { return [] }
        paragraphs.append(current)
        return paragraphs
    }

    // MARK: - Serialize

    private static func prefix(for style: NoteParagraphStyle, ordinal: Int) -> String {
        switch style {
        case .title: return "# "
        case .body: return ""
        case .bulleted: return "- "
        case .numbered: return "\(ordinal). "
        }
    }

    /// Outermost first: strikethrough, bold, italic, underline (D4).
    private static let markerOrder: [InlineStyle] = [.strikethrough, .bold, .italic, .underline]

    private static func open(_ style: InlineStyle) -> String {
        switch style {
        case .strikethrough: return "~~"
        case .bold: return "**"
        case .italic: return "*"
        case .underline: return "<u>"
        }
    }

    private static func close(_ style: InlineStyle) -> String {
        style == .underline ? "</u>" : open(style)
    }

    private static func inlineMarkdown(of paragraph: Paragraph) -> String {
        // Whitespace at a styled run's edges moves outside its markers (`**a** b`).
        var pieces: [Piece] = []
        for piece in paragraph.pieces {
            guard !piece.styles.isEmpty else {
                pieces.append(piece)
                continue
            }
            let core = piece.text.trimmingCharacters(in: .whitespaces)
            guard !core.isEmpty, let start = piece.text.firstIndex(where: { !$0.isWhitespace }),
                  let end = piece.text.lastIndex(where: { !$0.isWhitespace }) else {
                pieces.append(Piece(text: piece.text, styles: []))
                continue
            }
            let leading = String(piece.text[..<start])
            let trailing = String(piece.text[piece.text.index(after: end)...])
            if !leading.isEmpty { pieces.append(Piece(text: leading, styles: [])) }
            pieces.append(Piece(text: String(piece.text[start...end]), styles: piece.styles))
            if !trailing.isEmpty { pieces.append(Piece(text: trailing, styles: [])) }
        }

        let escapeLeadingMarker = paragraph.style != .title
        var out = ""
        var openStack: [InlineStyle] = []
        for (index, piece) in pieces.enumerated() {
            let wanted = markerOrder.filter { piece.styles.contains($0) }
            // Keep the markers this piece shares with the open ones, outermost first.
            var shared = 0
            while shared < openStack.count, shared < wanted.count, openStack[shared] == wanted[shared] { shared += 1 }
            for style in openStack[shared...].reversed() { out += close(style) }
            openStack.removeSubrange(shared...)
            for style in wanted[shared...] {
                out += open(style)
                openStack.append(style)
            }
            out += escaped(piece.text, leadingMarker: escapeLeadingMarker && index == 0)
        }
        for style in openStack.reversed() { out += close(style) }
        return out
    }

    private static let escapedCharacters: Set<Character> = ["\\", "*", "_", "~", "=", "<", ">", "#"]

    /// Backslash-escapes the D4 characters; a leading `- `, `+ ` or `<digits>. ` is escaped too
    /// so a body line never reads as a list.
    private static func escaped(_ text: String, leadingMarker: Bool) -> String {
        var out = ""
        for character in text {
            if escapedCharacters.contains(character) { out.append("\\") }
            out.append(character)
        }
        guard leadingMarker else { return out }
        if out.hasPrefix("- ") || out.hasPrefix("+ ") {
            return "\\" + out
        }
        let digits = out.prefix { $0.isASCII && $0.isNumber }
        if !digits.isEmpty, out.dropFirst(digits.count).hasPrefix(". ") {
            return digits + "\\" + out.dropFirst(digits.count)
        }
        return out
    }

    // MARK: - Parse

    /// `==text==` is parsed but not emitted in v1 (D4): drop an unescaped marker pair on one line.
    /// Done on the source because a parsed `\=\=` and a bare `==` are the same text afterwards.
    private static func strippingHighlights(_ markdown: String) -> String {
        guard markdown.contains("==") else { return markdown }
        return markdown.components(separatedBy: "\n").map(strippingHighlightsInLine).joined(separator: "\n")
    }

    private static func strippingHighlightsInLine(_ line: String) -> String {
        let characters = Array(line)
        var markerStarts: [Int] = []
        var index = 0
        while index < characters.count {
            if characters[index] == "\\" {
                index += 2
            } else if characters[index] == "=", index + 1 < characters.count, characters[index + 1] == "=" {
                markerStarts.append(index)
                index += 2
            } else {
                index += 1
            }
        }
        // An unpaired trailing marker stays literal.
        let paired = Set(markerStarts.prefix(markerStarts.count - markerStarts.count % 2))
        guard !paired.isEmpty else { return line }
        var out = ""
        index = 0
        while index < characters.count {
            if paired.contains(index) {
                index += 2
            } else {
                out.append(characters[index])
                index += 1
            }
        }
        return out
    }

    private static func appendBlock(_ block: Markup, to paragraphs: inout [Paragraph]) {
        switch block {
        case let list as UnorderedList:
            appendListItems(list.listItems, style: .bulleted, to: &paragraphs)
        case let list as OrderedList:
            appendListItems(list.listItems, style: .numbered, to: &paragraphs)
        case let paragraph as Markdown.Paragraph:
            appendInline(paragraph, style: .body, to: &paragraphs)
        case let heading as Markdown.Heading:
            appendInline(heading, style: .body, to: &paragraphs)
        case let code as Markdown.CodeBlock:
            for line in code.code.components(separatedBy: "\n") where !line.isEmpty {
                paragraphs.append(Paragraph(style: .body, pieces: [Piece(text: line, styles: [])]))
            }
        case is Markdown.HTMLBlock, is Markdown.ThematicBreak:
            break
        default:
            // Block quotes, tables and anything a hand-edited note might hold: keep the text.
            for child in block.children { appendBlock(child, to: &paragraphs) }
        }
    }

    private static func appendListItems(_ items: some Sequence<ListItem>, style: NoteParagraphStyle, to paragraphs: inout [Paragraph]) {
        for item in items {
            for child in item.children {
                switch child {
                case let nested as UnorderedList:
                    appendListItems(nested.listItems, style: .bulleted, to: &paragraphs)
                case let nested as OrderedList:
                    appendListItems(nested.listItems, style: .numbered, to: &paragraphs)
                default:
                    appendInline(child, style: style, to: &paragraphs)
                }
            }
        }
    }

    /// Collects the inline content of one block into paragraphs; a line break starts a new one
    /// of the same style, since the editor's model is one paragraph per line.
    private static func appendInline(_ container: Markup, style: NoteParagraphStyle, to paragraphs: inout [Paragraph]) {
        var walker = InlineWalker(style: style)
        walker.walk(container.children, styles: [])
        paragraphs.append(contentsOf: walker.paragraphs)
    }

    private struct InlineWalker {
        let style: NoteParagraphStyle
        var paragraphs: [Paragraph]
        var underlineDepth = 0

        init(style: NoteParagraphStyle) {
            self.style = style
            paragraphs = [Paragraph(style: style)]
        }

        mutating func walk(_ nodes: some Sequence<Markup>, styles: Set<InlineStyle>) {
            for node in nodes {
                switch node {
                case let text as Markdown.Text:
                    add(text.string, styles)
                case let code as Markdown.InlineCode:
                    add(code.code, styles)
                case is Markdown.SoftBreak, is Markdown.LineBreak:
                    paragraphs.append(Paragraph(style: style))
                case let html as Markdown.InlineHTML:
                    switch html.rawHTML.lowercased() {
                    case "<u>": underlineDepth += 1
                    case "</u>": underlineDepth = max(0, underlineDepth - 1)
                    default: break
                    }
                case is Markdown.Strong:
                    walk(node.children, styles: styles.union([.bold]))
                case is Markdown.Emphasis:
                    walk(node.children, styles: styles.union([.italic]))
                case is Markdown.Strikethrough:
                    walk(node.children, styles: styles.union([.strikethrough]))
                default:
                    // Links (a makeready://memo link included) and images keep their text only.
                    walk(node.children, styles: styles)
                }
            }
        }

        private mutating func add(_ text: String, _ styles: Set<InlineStyle>) {
            guard !text.isEmpty else { return }
            let all = underlineDepth > 0 ? styles.union([.underline]) : styles
            paragraphs[paragraphs.count - 1].pieces.append(Piece(text: text, styles: all))
        }
    }
}
