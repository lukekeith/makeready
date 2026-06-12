//
//  RichTextInput.swift
//  MakeReady
//
//  Native rich text editor using iOS 26 TextEditor + AttributedString.
//  Supports bold, italic, underline, headings (H1-H4), undo/redo.
//  Content stored as HTML strings for API compatibility.
//

import SwiftUI
import UIKit

struct RichTextInput: View {
    let placeholder: String
    @Binding var html: String
    var minHeight: CGFloat = 200
    var autoGrow: Bool = false
    var outputFormat: String = "html"
    var onContentChanged: ((String) -> Void)?

    @State private var attributedText = AttributedString()
    @State private var selection = AttributedTextSelection()
    @State private var isUpdatingFromHtml = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar — rigid 44pt, never compresses
            RichTextToolbar(
                attributedText: $attributedText,
                selection: $selection,
                undoManager: undoManager
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Editor area
            ZStack(alignment: .topLeading) {
                if attributedText.characters.isEmpty {
                    Text(placeholder)
                        .font(Typography.s17)
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
                    .tint(Color.brandPrimary)
                    .font(Typography.s17)
                    .foregroundStyle(.white)
            }
            .background(Color.backgroundDark)
        }
        .background(Color.backgroundDark)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(borderOverlay)
        .onAppear {
            attributedText = outputFormat == "markdown"
                ? Self.markdownToAttributed(html)
                : Self.htmlToAttributed(html)
        }
        .onChange(of: html) { _, newValue in handleHtmlChange(newValue) }
        .onChange(of: attributedText) { handleAttributedTextChange() }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.08), lineWidth: 1)
    }

    private func handleHtmlChange(_ newValue: String) {
        if isUpdatingFromAttributed {
            isUpdatingFromAttributed = false
            return
        }
        guard !isUpdatingFromHtml else { return }
        isUpdatingFromHtml = true
        attributedText = outputFormat == "markdown"
            ? Self.markdownToAttributed(newValue)
            : Self.htmlToAttributed(newValue)
    }

    @State private var isUpdatingFromAttributed = false

    private func handleAttributedTextChange() {
        if isUpdatingFromHtml {
            isUpdatingFromHtml = false
            return
        }
        let converted = outputFormat == "markdown"
            ? Self.attributedToMarkdown(attributedText)
            : Self.attributedToHtml(attributedText)
        isUpdatingFromAttributed = true
        html = converted
        onContentChanged?(converted)
    }

    // MARK: - HTML Conversion

    static func htmlToAttributed(_ html: String) -> AttributedString {
        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = html.data(using: .utf8) else {
            return AttributedString()
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
            // Set white text for dark theme (HTML parser defaults to black)
            for run in result.runs {
                result[run.range].foregroundColor = .white
            }
            return result
        } catch {
            var plain = AttributedString(html)
            plain.foregroundColor = .white
            return plain
        }
    }

    static func attributedToMarkdown(_ attributed: AttributedString) -> String {
        let nsAttr = NSAttributedString(attributed)
        guard nsAttr.length > 0 else { return "" }

        var result = ""
        nsAttr.enumerateAttributes(in: NSRange(location: 0, length: nsAttr.length), options: []) { attrs, range, _ in
            let text = (nsAttr.string as NSString).substring(with: range)
            var markdown = text

            // Check for font attributes
            if let font = attrs[.font] as? UIFont {
                let traits = font.fontDescriptor.symbolicTraits
                let pointSize = font.pointSize

                // Headings (detect by size - matching the applyHeading sizes in toolbar)
                if pointSize >= 28 {
                    markdown = "# \(text)"
                } else if pointSize >= 24 {
                    markdown = "## \(text)"
                } else if pointSize >= 20 {
                    markdown = "### \(text)"
                } else if pointSize >= 18 && traits.contains(.traitBold) {
                    markdown = "#### \(text)"
                } else {
                    // Inline formatting
                    if traits.contains(.traitBold) {
                        markdown = "**\(text)**"
                    }
                    if traits.contains(.traitItalic) {
                        markdown = "*\(markdown)*"
                    }
                }
            }

            // Underline (no markdown equivalent, use HTML inline)
            if attrs[.underlineStyle] != nil {
                markdown = "<u>\(markdown)</u>"
            }

            result += markdown
        }

        return result
    }

    static func markdownToAttributed(_ markdown: String) -> AttributedString {
        // Convert markdown to HTML first, then use existing htmlToAttributed
        var html = markdown

        // Headings
        html = html.replacingOccurrences(of: "(?m)^#### (.+)$", with: "<h4>$1</h4>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^### (.+)$", with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$", with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$", with: "<h1>$1</h1>", options: .regularExpression)

        // Bold and italic
        html = html.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<b><i>$1</i></b>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<b>$1</b>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<i>$1</i>", options: .regularExpression)

        // Paragraphs (double newline)
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        if !html.hasPrefix("<h") && !html.hasPrefix("<p>") {
            html = "<p>" + html + "</p>"
        }

        return htmlToAttributed(html)
    }

    static func attributedToHtml(_ attributed: AttributedString) -> String {
        let nsAttr = NSAttributedString(attributed)
        guard nsAttr.length > 0 else { return "" }
        do {
            let data = try nsAttr.data(
                from: NSRange(location: 0, length: nsAttr.length),
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ]
            )
            guard let fullHtml = String(data: data, encoding: .utf8) else { return "" }
            // Extract body content only (strip HTML document wrapper)
            if let bodyRange = fullHtml.range(of: "<body[^>]*>", options: .regularExpression),
               let bodyEndRange = fullHtml.range(of: "</body>") {
                return String(fullHtml[bodyRange.upperBound..<bodyEndRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return fullHtml
        } catch {
            return nsAttr.string
        }
    }
}

// MARK: - Custom Toolbar

/// Toolbar matching the app's dark theme with purple active states.
/// Reads typing attributes from selection to highlight active formatting.
private struct RichTextToolbar: View {
    @Binding var attributedText: AttributedString
    @Binding var selection: AttributedTextSelection
    var undoManager: UndoManager?

    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @State private var currentHeading: HeadingLevel = .normal

    private enum HeadingLevel: String {
        case normal, h1, h2, h3, h4
    }

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

    private var isUnderline: Bool {
        typingAttrs.underlineStyle != nil
    }

    private var isHeadingActive: Bool {
        currentHeading != .normal
    }

    var body: some View {
        HStack(spacing: 2) {
            formatGroup
            toolbarDivider
            styleGroup
            toolbarDivider
            historyGroup
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 44)
        .background(Color.cardBackground)
    }

    // MARK: - Format Group (Bold, Italic, Underline)

    private var formatGroup: some View {
        HStack(spacing: 2) {
            toolbarButton(icon: "bold", isActive: isBold) {
                let context = fontResolutionContext
                attributedText.transformAttributes(in: &selection) { container in
                    let currentFont = container.font ?? .body
                    let resolved = currentFont.resolve(in: context)
                    container.font = currentFont.bold(!resolved.isBold)
                }
            }

            toolbarButton(icon: "italic", isActive: isItalic) {
                let context = fontResolutionContext
                attributedText.transformAttributes(in: &selection) { container in
                    let currentFont = container.font ?? .body
                    let resolved = currentFont.resolve(in: context)
                    container.font = currentFont.italic(!resolved.isItalic)
                }
            }

            toolbarButton(icon: "underline", isActive: isUnderline) {
                let wasUnderlined = isUnderline
                attributedText.transformAttributes(in: &selection) { container in
                    container.underlineStyle = wasUnderlined ? nil : .single
                }
            }
        }
    }

    // MARK: - Style Group (Headings)

    private var styleGroup: some View {
        Menu {
            Button {
                applyHeading(.normal, size: 17, weight: .regular)
            } label: {
                Label("Normal", systemImage: currentHeading == .normal ? "checkmark" : "")
            }

            Button {
                applyHeading(.h1, size: 28, weight: .bold)
            } label: {
                Label("Heading 1", systemImage: currentHeading == .h1 ? "checkmark" : "")
            }

            Button {
                applyHeading(.h2, size: 24, weight: .bold)
            } label: {
                Label("Heading 2", systemImage: currentHeading == .h2 ? "checkmark" : "")
            }

            Button {
                applyHeading(.h3, size: 20, weight: .bold)
            } label: {
                Label("Heading 3", systemImage: currentHeading == .h3 ? "checkmark" : "")
            }

            Button {
                applyHeading(.h4, size: 18, weight: .bold)
            } label: {
                Label("Heading 4", systemImage: currentHeading == .h4 ? "checkmark" : "")
            }
        } label: {
            headingMenuLabel
        }
    }

    private var headingMenuLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "textformat.size")
                .font(Typography.s14Medium)
            Image(systemName: "chevron.down")
                .font(Typography.s8Bold)
        }
        .foregroundColor(isHeadingActive ? Color.brandPrimary : .white.opacity(0.5))
        .frame(height: 32)
        .padding(.horizontal, 8)
        .background(isHeadingActive ? Color.brandPrimary.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }

    private func applyHeading(_ level: HeadingLevel, size: CGFloat, weight: Font.Weight) {
        currentHeading = level
        attributedText.transformAttributes(in: &selection) { container in
            container.font = .system(size: size, weight: weight)
        }
    }

    // MARK: - History Group (Undo, Redo)

    private var historyGroup: some View {
        HStack(spacing: 2) {
            toolbarButton(icon: "arrow.uturn.backward", isActive: false) {
                undoManager?.undo()
            }

            toolbarButton(icon: "arrow.uturn.forward", isActive: false) {
                undoManager?.redo()
            }
        }
    }

    // MARK: - Shared Components

    private func toolbarButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Typography.s15Medium)
                .foregroundColor(isActive ? Color.brandPrimary : .white.opacity(0.5))
                .frame(width: 32, height: 32)
                .background(isActive ? Color.brandPrimary.opacity(0.15) : Color.clear)
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
            Text("Rich Text Input")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            RichTextInput(
                placeholder: "Enter formatted text...",
                html: .constant("")
            )
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
