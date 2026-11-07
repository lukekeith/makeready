//
//  ActionSheetPreview.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-137-action-sheet-preview in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-137 ActionSheetPreview — the sheet a leader sees when tapping an action in the iPhone viewer:
/// the layout members get, with Save disabled and a "Preview" label, because the native viewer
/// writes nothing.
///
/// The panel only (OQ-C-137-001): the host presents it through the app's overlay system and owns its
/// placement, motion and dim. Controlled (R-01): the host holds the draft and discards it on close
/// (OQ-C-137-008). The panel paints its own ground, an R-16 carve-out (OQ-C-137-002).
struct ActionSheetPreview: View {

    /// C-137 §4 `kind` — selects the layout and fixed copy. Nested per R-36.
    enum Kind: String {
        case addToPrayerList
        case write
    }

    /// C-137 §4 `kind`.
    let kind: Kind
    /// C-137 §4 `title` — the heading's value. `write` ignores it.
    let title: String
    /// C-137 §4 `bodyText` — the body's value.
    let bodyText: String
    /// C-137 §4 `prompt` — `write`'s body placeholder. `addToPrayerList` ignores it.
    let prompt: String
    /// C-137 §4 `bottomInset` — the host's bottom safe-area inset; places the privacy line.
    let bottomInset: CGFloat
    /// C-137 §4 `onClose` — Close tapped, or the accessibility escape.
    var onClose: () -> Void = {}
    /// C-137 §4 `onTitleChange` — every heading edit.
    var onTitleChange: (String) -> Void = { _ in }
    /// C-137 §4 `onBodyTextChange` — every body edit.
    var onBodyTextChange: (String) -> Void = { _ in }

    /// R-02: ephemeral. While a field has focus the keyboard covers the privacy line, so the scroll
    /// area stops reserving room for it and ends above the keyboard (OQ-C-137-008).
    @State private var fieldFocused = false

    init(
        kind: Kind,
        title: String,
        bodyText: String,
        prompt: String,
        bottomInset: CGFloat,
        onClose: @escaping () -> Void = {},
        onTitleChange: @escaping (String) -> Void = { _ in },
        onBodyTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.kind = kind
        self.title = title
        self.bodyText = bodyText
        self.prompt = prompt
        self.bottomInset = bottomInset
        self.onClose = onClose
        self.onTitleChange = onTitleChange
        self.onBodyTextChange = onBodyTextChange
    }

    /// C-137 §2's flagged literals, measured from the frozen still. Sizes and insets are fixed points
    /// that do not scale with `u` (§2).
    private enum Geometry {
        /// FLAGGED LITERAL — C-137 §2, OQ-C-137-003: top corners measured about 36 ±4 pt.
        static let topCorners: CGFloat = 36
        /// FLAGGED LITERAL — C-137 §2: the header row sits at y 17.
        static let headerTop: CGFloat = 17
        /// FLAGGED LITERAL — C-137 §2: the header row is 44 tall.
        static let headerHeight: CGFloat = 44
        /// FLAGGED LITERAL — C-137 §2: 20 pt header side insets.
        static let headerInset: CGFloat = 20
        /// FLAGGED LITERAL — C-137 §2, OQ-C-137-004: 44 pt close circle.
        static let closeCircle: CGFloat = 44
        /// FLAGGED LITERAL — C-137 §2: 28 pt close glyph box.
        static let closeGlyph: CGFloat = 28
        /// FLAGGED LITERAL — C-137 §2, OQ-C-137-004: 1 pt inner stroke.
        static let stroke: CGFloat = 1
        /// FLAGGED LITERAL — C-137 §2, OQ-C-134-7: pressed fill rises over 50 ms.
        static let pressFade: Double = 0.05
        /// FLAGGED LITERAL — C-137 §2: the fields start 40 below the header row (y 101).
        static let fieldsTop: CGFloat = 40
        /// FLAGGED LITERAL — C-137 §2: heading leading 29.
        static let headingLeading: CGFloat = 29
        /// FLAGGED LITERAL — C-137 §2: body leading 24.
        static let bodyLeading: CGFloat = 24
        /// FLAGGED LITERAL — C-137 §2: heading and body trailing 50.
        static let fieldTrailing: CGFloat = 50
        /// FLAGGED LITERAL — C-137 §2: count trailing 32.
        static let countTrailing: CGFloat = 32
        /// FLAGGED LITERAL — C-137 §2: the count's baseline sits 4 pt above the heading's last.
        static let countRaise: CGFloat = 4
        /// FLAGGED LITERAL — C-137 §2, OQ-C-137-009: the title limit.
        static let titleLimit = 70
        /// FLAGGED LITERAL — C-137 §2: the privacy line's centre is `bottomInset` + 32 above the bottom.
        static let privacyCentre: CGFloat = 32
        /// FLAGGED LITERAL — C-137 §2: privacy glyph at x 26.
        static let privacyLeading: CGFloat = 26
        /// FLAGGED LITERAL — C-137 §2: 12 pt privacy glyph box.
        static let privacyGlyph: CGFloat = 12
        /// FLAGGED LITERAL — C-137 §2: privacy text at x 53.
        static let privacyText: CGFloat = 53
    }

    /// FLAGGED LITERAL — C-137 §2, OQ-C-137-011: SF Pro Bold 32/37, no type token.
    private static let headingStyle = DesignTextStyle(weight: .bold, size: 32, lineHeight: 37, tracking: 0)

    private var isPrayer: Bool { kind == .addToPrayerList }

    private var headerTitle: String { isPrayer ? "Add Prayer" : "Write" }

    /// §2, OQ-C-137-009: characters left out of 70, floored at 0.
    private var charactersLeft: Int { max(Geometry.titleLimit - title.count, 0) }

    private var privacyLineHeight: CGFloat {
        Token.TypeStyle.caption.lineHeight ?? Token.TypeStyle.caption.size
    }

    /// §2: the scroll area ends `space-section-gap` above the privacy line, or above the keyboard
    /// while a field has focus. `write` has no privacy line, so it only clears the host's inset.
    private var scrollAreaBottom: CGFloat {
        if fieldFocused { return 0 }
        guard isPrayer else { return bottomInset }
        return bottomInset + Geometry.privacyCentre + privacyLineHeight / 2 + Token.Space.sectionGap
    }

    var body: some View {
        // §2 Layers, bottom to top: ground, content, pinned privacy line.
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                headerRow
                scrollArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isPrayer {
                privacyLine
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    // OQ-C-137-008: the keyboard covers the privacy line, which does not move.
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .background { ground }
        .contentShape(Rectangle())                  // §2 Touches: the panel takes every touch inside it
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
        .ui2Element("ActionSheetPreview")
    }

    /// §2 Ground: opaque, large top corners, square bottom corners. `color-neutral-900` by
    /// OQ-C-137-002, a palette step with no semantic token.
    private var ground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: Geometry.topCorners,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: Geometry.topCorners
        )
        .fill(Token.neutral900)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .ui2Element("Ground")
    }

    // MARK: - Header row

    /// §2 Header row: close, a title centred on the panel, and Save. Fixed while the fields scroll.
    private var headerRow: some View {
        ZStack {
            headerTitleStack

            HStack(spacing: 0) {
                SwiftUI.Button(action: onClose) {
                    Image(GlyphName.closeLargeCarbon.rawValue, bundle: .ui2Preview)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Geometry.closeGlyph, height: Geometry.closeGlyph)
                        .foregroundStyle(Token.white100)
                        .accessibilityHidden(true)
                }
                .buttonStyle(CloseCircleStyle())
                .accessibilityLabel("Close")
                .accessibilityAddTraits(.isButton)
                .ui2Element("Close")

                Spacer(minLength: 0)

                // §2, OQ-C-137-005: C-048's disabled look, hugging its label. Always disabled.
                PageActionButton(label: "Save", role: .prominent, enabled: false)
                    .fixedSize(horizontal: true, vertical: false)
                    .ui2Element("Save")
            }
            .padding(.horizontal, Geometry.headerInset)
        }
        .frame(height: Geometry.headerHeight)
        .ui2Element("Header row")
        .padding(.top, Geometry.headerTop)
    }

    /// §2, OQ-C-137-006: "Preview" stacks directly under the title; the two lines centre together.
    private var headerTitleStack: some View {
        VStack(spacing: 0) {
            Text(headerTitle)
                .designTextStyle(Token.TypeStyle.calloutBold)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .frame(height: Token.TypeStyle.calloutBold.lineHeight)
                .ui2Element("Header title")

            Text("Preview")
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .frame(height: Token.TypeStyle.caption.lineHeight)
                .ui2Element("Preview")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(headerTitle), Preview")
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Fields

    /// §2, OQ-C-137-008: heading, count and body scroll together under the fixed header row.
    private var scrollArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                if isPrayer { headingField }
                bodyField
            }
            .padding(.top, Geometry.fieldsTop)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .padding(.bottom, scrollAreaBottom)
    }

    /// §2 Heading field, with the count in its trailing margin.
    private var headingField: some View {
        SheetField(
            text: title,
            placeholder: "Title",
            style: Self.headingStyle,
            accessibilityName: "Title",
            limit: Geometry.titleLimit,
            onChange: onTitleChange,
            onFocusChange: { fieldFocused = $0 }
        )
        .ui2Element("Heading field")
        .padding(.leading, Geometry.headingLeading)
        .padding(.trailing, Geometry.fieldTrailing)
        .overlay(alignment: .bottomTrailing) {
            Text("\(charactersLeft)")
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.white50)
                .accessibilityLabel("\(charactersLeft) characters left")
                .ui2Element("Count")
                .padding(.trailing, Geometry.countTrailing)
                // §2: the count's baseline sits 4 pt above the heading's last baseline, and the
                // field's last baseline sits one font descent above its bottom edge.
                .alignmentGuide(.bottom) {
                    $0[.lastTextBaseline] + Self.headingStyle.uiFontDescent + Geometry.countRaise
                }
        }
    }

    /// §2 Body field: under the heading, or at the heading's y 101 on `write` (OQ-C-137-007).
    private var bodyField: some View {
        SheetField(
            text: bodyText,
            placeholder: isPrayer ? "Write your prayer" : prompt,
            style: Token.TypeStyle.bodyLg,
            accessibilityName: isPrayer ? "Prayer" : prompt,
            limit: nil,
            onChange: onBodyTextChange,
            onFocusChange: { fieldFocused = $0 }
        )
        .ui2Element("Body field")
        .padding(.leading, Geometry.bodyLeading)
        .padding(.trailing, Geometry.fieldTrailing)
    }

    // MARK: - Privacy line

    /// §2 Privacy line (`addToPrayerList` only): pinned, one static accessibility element.
    private var privacyLine: some View {
        HStack(spacing: 0) {
            Image(GlyphName.lock.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Geometry.privacyGlyph, height: Geometry.privacyGlyph)
                .foregroundStyle(Token.white100)
                .accessibilityHidden(true)
                .padding(.trailing, Geometry.privacyText - Geometry.privacyLeading - Geometry.privacyGlyph)

            Text("Your prayer is private, until you choose to share it.")
                .designTextStyle(Token.TypeStyle.caption)
                .foregroundStyle(Token.white70)
                .lineLimit(1)
        }
        .frame(height: privacyLineHeight)
        .accessibilityElement(children: .combine)
        .ui2Element("Privacy line")
        .padding(.leading, Geometry.privacyLeading)
        .padding(.bottom, bottomInset + Geometry.privacyCentre - privacyLineHeight / 2)
    }

    // MARK: - Close style

    /// §2 Close, inline by OQ-C-137-004: no fill, a 1 pt `color-white-10` inner stroke, and a pressed
    /// fill of `color-white-30` over 50 ms with no geometry change. `radius-circle` parses to no
    /// token, so the shape is SwiftUI's `Circle`.
    private struct CloseCircleStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            ZStack {
                Circle()
                    .fill(configuration.isPressed ? Token.white30 : Token.transparent)
                    .animation(.linear(duration: Geometry.pressFade), value: configuration.isPressed)
                Circle().strokeBorder(Token.white10, lineWidth: Geometry.stroke)
                configuration.label
            }
            .frame(width: Geometry.closeCircle, height: Geometry.closeCircle)
            .contentShape(Circle())
        }
    }
}

private extension DesignTextStyle {
    var uiFont: UIFont {
        UIFont.systemFont(ofSize: size, weight: weight == .bold ? .bold : .regular)
    }

    /// How far a `SheetField` line's baseline sits above the bottom of its line box.
    var uiFontDescent: CGFloat { -uiFont.descender }
}

/// One editable field of the sheet: a value, its placeholder and a caret in `color-accent`, with no
/// border. A `UITextView` rather than a `TextField` because the title limit has to refuse a keystroke
/// before it is drawn (OQ-C-137-009), which a SwiftUI field can only fix up afterwards, and because it
/// sets the exact line box the contract measures (C-045's `MaskedTextField` precedent).
private struct SheetField: View {
    let text: String
    let placeholder: String
    let style: DesignTextStyle
    let accessibilityName: String
    let limit: Int?
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            SheetTextView(
                text: text,
                style: style,
                accessibilityName: accessibilityName,
                limit: limit,
                onChange: onChange,
                onFocusChange: onFocusChange
            )

            if text.isEmpty {
                // OQ-C-137-010: `color-input-placeholder`. Sits on the field's first line box.
                Text(placeholder)
                    .designTextStyle(style)
                    .foregroundStyle(Token.inputPlaceholder)
                    .frame(minHeight: style.lineHeight, alignment: .bottomLeading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .ui2Element("Placeholder")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// `SheetField`'s text run: non-scrolling, sized to its wrapped text, in the field's type and
/// `color-text-primary`.
private struct SheetTextView: UIViewRepresentable {
    let text: String
    let style: DesignTextStyle
    let accessibilityName: String
    let limit: Int?
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void

    private var lineHeight: CGFloat { style.lineHeight ?? style.size }

    private var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        return [
            .font: style.uiFont,
            .foregroundColor: UIColor(Token.textPrimary),
            .kern: style.tracking,
            .paragraphStyle: paragraph
        ]
    }

    /// §4, OQ-C-137-009: past the limit an edit is taken only if it shortens the text.
    private func allows(_ next: String, over current: String) -> Bool {
        guard let limit, next.count > limit else { return true }
        return next.count < current.count
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.scrollsToTop = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.font = style.uiFont
        view.tintColor = UIColor(Token.accent)                       // §2: caret `color-accent`
        view.typingAttributes = attributes
        view.attributedText = NSAttributedString(string: text, attributes: attributes)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.accessibilityLabel = accessibilityName
        // A host-side change only: re-setting our own text would move the caret.
        if view.markedTextRange == nil, view.text != text {
            view.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, lineHeight))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SheetTextView

        init(_ parent: SheetTextView) { self.parent = parent }

        func textView(_ view: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = view.text ?? ""
            guard let swiftRange = Range(range, in: current) else { return false }
            return parent.allows(current.replacingCharacters(in: swiftRange, with: text), over: current)
        }

        func textViewDidChange(_ view: UITextView) {
            let next = view.text ?? ""
            // Dictation and autofill bypass the delegate check above.
            guard parent.allows(next, over: parent.text) else {
                view.attributedText = NSAttributedString(string: parent.text, attributes: parent.attributes)
                return
            }
            parent.onChange(next)
        }

        func textViewDidBeginEditing(_ view: UITextView) { parent.onFocusChange(true) }
        func textViewDidEndEditing(_ view: UITextView) { parent.onFocusChange(false) }
    }
}
