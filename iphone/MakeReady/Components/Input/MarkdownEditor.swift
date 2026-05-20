//
//  MarkdownEditor.swift
//  MakeReady
//
//  WYSIWYG markdown editor using iOS 26 TextEditor + AttributedString.
//  The user sees rendered formatted text; content is stored as markdown.
//  Toolbar: H1, H2, H3, List, Bold, Italic, Quote
//

import SwiftUI
import UIKit

struct MarkdownEditor: View {
    let placeholder: String
    /// Single source of truth, owned by the parent. When this view is rendered
    /// twice by a drag container (one hidden card for layout, one visible card
    /// in a UIHostingController) both instances bind to the same AttributedString,
    /// so their intrinsic sizes stay in lock-step and the visible editor grows
    /// as the user types. Storing an AttributedString here also skips the
    /// per-keystroke markdown↔HTML round-trip that previously diverged the two
    /// copies and caused the text box to clip.
    @Binding var attributedText: AttributedString
    var minHeight: CGFloat = 200
    var autoGrow: Bool = false

    @State private var selection = AttributedTextSelection()
    @State private var isSanitizing = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            divider
            editorArea
        }
        .background(Color(hex: "#0a0a0f"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(borderOverlay)
    }

    private var toolbar: some View {
        MarkdownEditorToolbar(
            attributedText: $attributedText,
            selection: $selection,
            undoManager: undoManager
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            if attributedText.characters.isEmpty {
                Text(placeholder)
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 12)
                    .padding(.leading, 12)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $attributedText, selection: $selection)
                .padding(8)
                .frame(minHeight: minHeight)
                .scrollDisabled(autoGrow)
                .fixedSize(horizontal: false, vertical: autoGrow)
                .scrollContentBackground(.hidden)
                .tint(Color(hex: "#6c47ff"))
                .font(.system(size: 17))
                .foregroundStyle(.white)
        }
        .background(Color(hex: "#0a0a0f"))
        .onChange(of: attributedText) { oldValue, newValue in
            guard !isSanitizing else { return }

            let oldLen = oldValue.characters.count
            let newLen = newValue.characters.count
            let delta = newLen - oldLen

            // Only process significant text growth (likely a paste)
            guard delta > 1 else { return }

            // Check if pasteboard has HTML content (copied from a website)
            if let htmlData = UIPasteboard.general.data(forPasteboardType: "public.html"),
               let html = String(data: htmlData, encoding: .utf8) {
                isSanitizing = true

                // Convert the pasted HTML to clean markdown, then to AttributedString
                let cleanMarkdown = Self.htmlToMarkdown(html)
                let cleanPasted = Self.markdownToAttributed(cleanMarkdown)

                // Find where the paste was inserted by diffing old vs new characters
                let oldChars = Array(String(oldValue.characters))
                let newChars = Array(String(newValue.characters))

                var prefixLen = 0
                while prefixLen < min(oldChars.count, newChars.count)
                        && oldChars[prefixLen] == newChars[prefixLen] {
                    prefixLen += 1
                }

                var suffixLen = 0
                let maxSuffix = min(oldChars.count - prefixLen, newChars.count - prefixLen)
                while suffixLen < maxSuffix
                        && oldChars[oldChars.count - 1 - suffixLen] == newChars[newChars.count - 1 - suffixLen] {
                    suffixLen += 1
                }

                // Build: old prefix + clean pasted content + old suffix
                var result = AttributedString()

                if prefixLen > 0 {
                    let prefEnd = oldValue.characters.index(oldValue.startIndex, offsetBy: prefixLen)
                    result.append(AttributedString(oldValue[oldValue.startIndex..<prefEnd]))
                }

                result.append(cleanPasted)

                if suffixLen > 0 {
                    let sufStart = oldValue.characters.index(oldValue.endIndex, offsetBy: -suffixLen)
                    result.append(AttributedString(oldValue[sufStart..<oldValue.endIndex]))
                }

                attributedText = result

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSanitizing = false
                }
            } else if UIPasteboard.general.data(forPasteboardType: "public.rtf") != nil
                        || UIPasteboard.general.data(forPasteboardType: "com.apple.flat-rtfd") != nil {
                // Rich text paste (not HTML) — sanitize attributes to our supported subset
                isSanitizing = true
                attributedText = Self.sanitizeAttributes(newValue)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSanitizing = false
                }
            }
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    // MARK: - Markdown → AttributedString

    static func markdownToAttributed(_ md: String) -> AttributedString {
        guard !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AttributedString()
        }

        // Convert markdown to HTML, then parse to AttributedString
        let html = markdownToHtml(md)

        guard let data = html.data(using: .utf8) else {
            var plain = AttributedString(md)
            plain.foregroundColor = .white
            return plain
        }

        do {
            let nsAttr = try NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
            )
            var result = AttributedString(nsAttr)
            // Set white text for dark theme
            for run in result.runs {
                result[run.range].foregroundColor = .white
            }
            return result
        } catch {
            var plain = AttributedString(md)
            plain.foregroundColor = .white
            return plain
        }
    }

    // MARK: - AttributedString → Markdown

    static func attributedToMarkdown(_ attributed: AttributedString) -> String {
        let nsAttr = NSAttributedString(attributed)
        guard nsAttr.length > 0 else { return "" }

        var lines: [String] = []
        var currentLine = ""

        nsAttr.enumerateAttributes(
            in: NSRange(location: 0, length: nsAttr.length),
            options: []
        ) { attrs, range, _ in
            let text = (nsAttr.string as NSString).substring(with: range)

            // Split by newlines to handle line-level formatting (headings, lists, quotes)
            let segments = text.components(separatedBy: "\n")

            for (i, segment) in segments.enumerated() {
                if i > 0 {
                    // Newline boundary — flush current line
                    lines.append(currentLine)
                    currentLine = ""
                }

                guard !segment.isEmpty else { continue }

                var formatted = segment

                if let font = attrs[.font] as? UIFont {
                    let traits = font.fontDescriptor.symbolicTraits
                    let pointSize = font.pointSize

                    // Detect headings by font size
                    if pointSize >= 28 && currentLine.isEmpty {
                        currentLine = "# "
                    } else if pointSize >= 24 && currentLine.isEmpty {
                        currentLine = "## "
                    } else if pointSize >= 20 && traits.contains(.traitBold) && currentLine.isEmpty {
                        currentLine = "### "
                    } else {
                        // Inline formatting
                        let isBold = traits.contains(.traitBold)
                        let isItalic = traits.contains(.traitItalic)

                        if isBold && isItalic {
                            formatted = "***\(segment)***"
                        } else if isBold {
                            formatted = "**\(segment)**"
                        } else if isItalic {
                            formatted = "*\(segment)*"
                        }
                    }
                }

                currentLine += formatted
            }
        }

        // Flush last line
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Markdown → HTML (simple converter)

    private static func markdownToHtml(_ md: String) -> String {
        var html = ""
        let lines = md.components(separatedBy: "\n")

        var inList = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Close list if we're no longer in one
            if inList && !trimmed.hasPrefix("- ") && !trimmed.hasPrefix("* ") {
                html += "</ul>"
                inList = false
            }

            if trimmed.isEmpty {
                html += "<br>"
                continue
            }

            // Headings
            if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                html += "<h3>\(applyInlineFormatting(content))</h3>"
            } else if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                html += "<h2>\(applyInlineFormatting(content))</h2>"
            } else if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2))
                html += "<h1>\(applyInlineFormatting(content))</h1>"
            }
            // Blockquote
            else if trimmed.hasPrefix("> ") {
                let content = String(trimmed.dropFirst(2))
                html += "<blockquote>\(applyInlineFormatting(content))</blockquote>"
            }
            // List items
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList {
                    html += "<ul>"
                    inList = true
                }
                let content = String(trimmed.dropFirst(2))
                html += "<li>\(applyInlineFormatting(content))</li>"
            }
            // Paragraph
            else {
                html += "<p>\(applyInlineFormatting(trimmed))</p>"
            }
        }

        if inList {
            html += "</ul>"
        }

        return html
    }

    private static func applyInlineFormatting(_ text: String) -> String {
        var result = text
        // Bold + italic
        result = result.replacingOccurrences(
            of: "\\*\\*\\*(.+?)\\*\\*\\*",
            with: "<b><i>$1</i></b>",
            options: .regularExpression
        )
        // Bold
        result = result.replacingOccurrences(
            of: "\\*\\*(.+?)\\*\\*",
            with: "<b>$1</b>",
            options: .regularExpression
        )
        // Italic
        result = result.replacingOccurrences(
            of: "\\*(.+?)\\*",
            with: "<i>$1</i>",
            options: .regularExpression
        )
        return result
    }

    // MARK: - HTML → Markdown (paste handling)

    /// Converts raw HTML (e.g. from a website paste) to our supported markdown subset.
    /// Handles headings (h1-h3), bold, italic, lists, blockquotes, and paragraphs.
    /// Everything else is stripped to plain text.
    static func htmlToMarkdown(_ html: String) -> String {
        var text = html

        // Normalize line endings
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        // Remove <style> and <script> blocks entirely
        text = regexReplace(text, pattern: "<style[^>]*>[\\s\\S]*?</style>", template: "")
        text = regexReplace(text, pattern: "<script[^>]*>[\\s\\S]*?</script>", template: "")

        // Convert <br> to newlines early
        text = regexReplace(text, pattern: "<br\\s*/?>", template: "\n")

        // Headings h1-h3 → # / ## / ###
        for level in 1...3 {
            let prefix = String(repeating: "#", count: level)
            text = regexReplace(text, pattern: "<h\(level)[^>]*>([\\s\\S]*?)</h\(level)>", template: "\n\(prefix) $1\n")
        }
        // h4-h6 → ### (we only support up to h3)
        for level in 4...6 {
            text = regexReplace(text, pattern: "<h\(level)[^>]*>([\\s\\S]*?)</h\(level)>", template: "\n### $1\n")
        }

        // Bold: <strong>, <b>
        text = regexReplace(text, pattern: "<(strong|b)(\\s[^>]*)?>([\\s\\S]*?)</\\1>", template: "**$3**")

        // Italic: <em>, <i>
        text = regexReplace(text, pattern: "<(em|i)(\\s[^>]*)?>([\\s\\S]*?)</\\1>", template: "*$3*")

        // List items
        text = regexReplace(text, pattern: "<li[^>]*>([\\s\\S]*?)</li>", template: "\n- $1")

        // Strip list wrappers
        text = regexReplace(text, pattern: "</?[uo]l[^>]*>", template: "\n")

        // Blockquotes
        text = regexReplace(text, pattern: "<blockquote[^>]*>([\\s\\S]*?)</blockquote>", template: "\n> $1\n")

        // Paragraphs and divs → newline-separated text
        text = regexReplace(text, pattern: "</p>", template: "\n\n")
        text = regexReplace(text, pattern: "<p[^>]*>", template: "")
        text = regexReplace(text, pattern: "</div>", template: "\n")
        text = regexReplace(text, pattern: "<div[^>]*>", template: "")

        // Strip all remaining HTML tags
        text = regexReplace(text, pattern: "<[^>]+>", template: "")

        // Decode HTML entities
        text = decodeHTMLEntities(text)

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\t", with: " ")
        // Collapse runs of spaces (but not newlines)
        text = regexReplace(text, pattern: " {2,}", template: " ")
        // Remove leading/trailing spaces on each line
        text = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        // Collapse 3+ newlines to 2
        text = regexReplace(text, pattern: "\n{3,}", template: "\n\n")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Regex replace using NSRegularExpression with dotMatchesLineSeparators
    /// so patterns like [\\s\\S]*? work across newlines.
    private static func regexReplace(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
            ("&hellip;", "…"), ("&bull;", "•"), ("&middot;", "·"),
            ("&copy;", "©"), ("&reg;", "®"), ("&trade;", "™"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // Numeric entities: &#123; and &#x1A;
        if let decRegex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let ns = result as NSString
            for match in decRegex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed() {
                let codeStr = ns.substring(with: match.range(at: 1))
                if let code = Int(codeStr), let scalar = Unicode.Scalar(code) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                }
            }
        }
        if let hexRegex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);") {
            let ns = result as NSString
            for match in hexRegex.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed() {
                let codeStr = ns.substring(with: match.range(at: 1))
                if let code = UInt32(codeStr, radix: 16), let scalar = Unicode.Scalar(code) {
                    result = (result as NSString).replacingCharacters(in: match.range, with: String(Character(scalar)))
                }
            }
        }
        return result
    }

    // MARK: - Attribute Sanitization

    /// Normalizes an AttributedString to only contain our supported formatting:
    /// headings (28pt/24pt/20pt bold), body (17pt), bold, italic. Strips all
    /// other attributes (colors, backgrounds, underlines, links, custom fonts).
    static func sanitizeAttributes(_ text: AttributedString) -> AttributedString {
        guard !text.characters.isEmpty else { return text }

        let ns = NSAttributedString(text)
        let mutable = NSMutableAttributedString(attributedString: ns)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            var targetFont: UIFont
            var isItalic = false

            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                let size = font.pointSize
                let isBold = traits.contains(.traitBold)
                isItalic = traits.contains(.traitItalic)

                if size >= 28 {
                    targetFont = .systemFont(ofSize: 28, weight: .bold)
                } else if size >= 24 {
                    targetFont = .systemFont(ofSize: 24, weight: .bold)
                } else if size >= 20 && isBold {
                    targetFont = .systemFont(ofSize: 20, weight: .bold)
                } else {
                    targetFont = .systemFont(ofSize: 17, weight: isBold ? .bold : .regular)
                }
            } else {
                targetFont = .systemFont(ofSize: 17)
            }

            // Add italic trait if source had it
            if isItalic,
               let italicDesc = targetFont.fontDescriptor.withSymbolicTraits(
                   targetFont.fontDescriptor.symbolicTraits.union(.traitItalic)
               ) {
                targetFont = UIFont(descriptor: italicDesc, size: 0)
            }

            // Replace all attributes with only font + white foreground
            mutable.setAttributes([
                .font: targetFont,
                .foregroundColor: UIColor.white
            ], range: range)
        }

        var result = AttributedString(mutable)
        for run in result.runs {
            result[run.range].foregroundColor = .white
        }
        return result
    }
}

// MARK: - Toolbar

private struct MarkdownEditorToolbar: View {
    @Binding var attributedText: AttributedString
    @Binding var selection: AttributedTextSelection
    var undoManager: UndoManager?

    @Environment(\.fontResolutionContext) private var fontResolutionContext

    private var typingAttrs: AttributeContainer {
        selection.typingAttributes(in: attributedText)
    }

    private var isBold: Bool {
        let font = typingAttrs.font ?? .body
        return font.resolve(in: fontResolutionContext).isBold
    }

    private var isItalic: Bool {
        let font = typingAttrs.font ?? .body
        return font.resolve(in: fontResolutionContext).isItalic
    }

    private var currentHeadingLevel: Int {
        let font = typingAttrs.font ?? .body
        let resolved = font.resolve(in: fontResolutionContext)
        let size = resolved.pointSize
        if size >= 28 { return 1 }
        if size >= 24 { return 2 }
        if size >= 20 && resolved.isBold { return 3 }
        return 0
    }

    private var headingLabel: String {
        switch currentHeadingLevel {
        case 1: return "H1"
        case 2: return "H2"
        case 3: return "H3"
        default: return "H"
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            // Heading dropdown
            headingMenu

            toolbarDivider

            // List
            toolbarButton(icon: "list.bullet", isActive: false) {
                insertListPrefix()
            }

            // Quote
            toolbarButton(icon: "text.quote", isActive: false) {
                insertQuotePrefix()
            }

            toolbarDivider

            // Bold
            toolbarButton(icon: "bold", isActive: isBold) {
                toggleBold()
            }

            // Italic
            toolbarButton(icon: "italic", isActive: isItalic) {
                toggleItalic()
            }

            toolbarDivider

            // Clear formatting
            toolbarButton(icon: "textformat.alt", isActive: false) {
                clearFormatting()
            }

            toolbarDivider

            // Undo / Redo
            toolbarButton(icon: "arrow.uturn.backward", isActive: false) {
                undoManager?.undo()
            }
            toolbarButton(icon: "arrow.uturn.forward", isActive: false) {
                undoManager?.redo()
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color(hex: "#252936"))
    }

    // MARK: - Heading Menu

    private var headingMenu: some View {
        let isActive = currentHeadingLevel > 0
        return Menu {
            Button {
                applyHeading(0, size: 17, weight: .regular)
            } label: {
                Label("Normal", systemImage: currentHeadingLevel == 0 ? "checkmark" : "")
            }
            Button {
                applyHeading(1, size: 28, weight: .bold)
            } label: {
                Label("Heading 1", systemImage: currentHeadingLevel == 1 ? "checkmark" : "")
            }
            Button {
                applyHeading(2, size: 24, weight: .bold)
            } label: {
                Label("Heading 2", systemImage: currentHeadingLevel == 2 ? "checkmark" : "")
            }
            Button {
                applyHeading(3, size: 20, weight: .bold)
            } label: {
                Label("Heading 3", systemImage: currentHeadingLevel == 3 ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: 2) {
                Text(headingLabel)
                    .font(.system(size: 13, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(isActive ? Color(hex: "#6c47ff") : .white.opacity(0.5))
            .frame(height: 32)
            .padding(.horizontal, 8)
            .background(isActive ? Color(hex: "#6c47ff").opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
    }

    private func applyHeading(_ level: Int, size: CGFloat, weight: Font.Weight) {
        attributedText.transformAttributes(in: &selection) { container in
            container.font = .system(size: size, weight: weight)
        }
    }

    // MARK: - Formatting Actions

    private func toggleBold() {
        let context = fontResolutionContext
        attributedText.transformAttributes(in: &selection) { container in
            let currentFont = container.font ?? .body
            let resolved = currentFont.resolve(in: context)
            container.font = currentFont.bold(!resolved.isBold)
        }
    }

    private func toggleItalic() {
        let context = fontResolutionContext
        attributedText.transformAttributes(in: &selection) { container in
            let currentFont = container.font ?? .body
            let resolved = currentFont.resolve(in: context)
            container.font = currentFont.italic(!resolved.isItalic)
        }
    }

    private func clearFormatting() {
        attributedText.transformAttributes(in: &selection) { container in
            container.font = .system(size: 17, weight: .regular)
            container.underlineStyle = nil
        }
    }

    // MARK: - Insert Prefixes

    private func insertListPrefix() {
        // Insert "- " at current cursor by modifying the attributed text
        var newText = attributedText
        let insertStr = AttributedString("- ")
        // Append at the end of current selection as a simple approach
        newText.append(insertStr)
        attributedText = newText
    }

    private func insertQuotePrefix() {
        var newText = attributedText
        let insertStr = AttributedString("> ")
        newText.append(insertStr)
        attributedText = newText
    }

    // MARK: - Shared Components

    private func toolbarButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isActive ? Color(hex: "#6c47ff") : .white.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(isActive ? Color(hex: "#6c47ff").opacity(0.15) : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Markdown Editor")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            MarkdownEditor(
                placeholder: "Write in markdown...",
                attributedText: .constant(MarkdownEditor.markdownToAttributed("# Hello World\n\nThis is **bold** and *italic* text.\n\n- First item\n- Second item\n\n> A blockquote")),
                minHeight: 200,
                autoGrow: true
            )
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
