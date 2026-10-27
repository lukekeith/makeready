//
//  TextInput.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-045-text-input in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-045 TextInput — the program's general text input (single, multiline and phone).
///
/// Controlled (R-01): the caller holds `text` and `focused`; the view holds no value.
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// intrinsic height, paints no page background and adds no outer padding. Frame, background
/// and outer padding belong to the capture call site.
struct TextInput: View {

    /// C-045 §4 `kind: single · multi · phone` — the Figma `type` axis (R-06 / R-36).
    enum Kind: String {
        case single
        case multi
        case phone
    }

    /// C-045 §4 `alignment: leading · center` — Single and Multi only (OQ-C-046-004).
    enum Alignment: String {
        case leading
        case center
    }

    /// C-045 §4: the value as the caller holds it; empty → placeholder shows.
    /// Phone: already formatted — the component formats nothing.
    let text: String
    /// C-045 §4: shown when `text` is empty; also the accessibility label (R-17).
    let placeholder: String
    /// C-045 §4: layout, type style and keyboard.
    let kind: Kind
    /// C-045 §4: defaulted `.leading` — every Text input symbol draws leading text (R-07).
    /// Ignored by Phone, which is centred by anatomy.
    var alignment: Alignment = .leading
    /// C-045 §4: drives the white border + caret.
    let focused: Bool
    /// C-045 §4: Phone only — the prefix. Defaulted because the design shows `+1` (R-07,
    /// OQ-C-045-002).
    var countryCode: String = "+1"
    /// C-045 §4: every edit, with the new raw text (R-01, R-33). No render effect.
    var onChange: (String) -> Void = { _ in }
    /// C-045 §4: focus gained/lost; the caller owns `focused` (R-01). No render effect.
    var onFocusChange: (Bool) -> Void = { _ in }

    /// ui2-members-edit T9e (D22, D26): nil — the default — is the static render every preview
    /// and capture draws (R-01: `text` is drawn, nothing is typed). Non-nil makes Single and
    /// Multi a live text field: every edit calls `onChange`, focus calls `onFocusChange`, and the
    /// caller keeps owning `text` and `focused`. Phone ignores it (no live consumer yet; the
    /// member Phone page uses `field: .text`, D22). Routed to /ui2-resolve (F2).
    var editing: Editing? = nil

    /// ui2-members-edit T9d/T9e: the live field's keyboard and focus — behaviour, not design.
    struct Editing {
        var keyboard: UIKeyboardType = .default
        var textContentType: UITextContentType? = nil
        var autocapitalization: TextInputAutocapitalization = .sentences
        var autocorrect: Bool = true
        /// D22: the field takes focus when it appears.
        var focusOnAppear: Bool = false
        /// D26: false while a save is in flight — the input is locked.
        var isEnabled: Bool = true
        /// R-17: the live field's spoken name (C-046 passes its label); "" falls back to `placeholder`.
        var accessibilityName: String = ""
        /// input-masking: formats the text as it is typed — the caller still owns `text` (now the
        /// formatted form) and reads the saved value back with `mask.raw(_:)`. nil = no mask.
        var mask: InputMask? = nil
    }

    var body: some View {
        if let editing, kind != .phone {
            // T9e: the live form — the same §2 box with a real field inside. The field carries
            // its own accessibility (R-17), so the box does not flatten it.
            chrome(
                LiveField(
                    text: text,
                    placeholder: placeholder,
                    multiline: kind == .multi,
                    alignment: textAlignment,
                    editing: editing,
                    onChange: onChange,
                    onFocusChange: onFocusChange
                )
                .ui2Element(text.isEmpty ? "Placeholder" : "Value")
            )
            .ui2Element("TextInput")
        } else {
            chrome(content)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(placeholder)          // R-17: §4 names placeholder as the label
                .accessibilityValue(text)
                .ui2Element("TextInput")                  // capture element map — UI2Element.swift
        }
    }

    /// §2's box around either form — the static render gets exactly the modifiers it always had,
    /// in the same order.
    private func chrome(_ inner: some View) -> some View {
        inner
            // §2: p16 / px16 for every kind — measured INSIDE the 1px border (see
            // `borderWidth`).
            .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
            .padding(.vertical, verticalInset)
            // §2: Single / Phone 44pt, content vertically centred · Multi 88pt MINIMUM,
            // growing with content (OQ-C-045-3), content top-aligned.
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                maxHeight: kind == .multi ? nil : minHeight,
                alignment: boxAlignment
            )
            .overlay(
                // §2: Border 1px `color-card-border`; focused: 1px `color-text-primary`.
                // (Error = `color-negative` is ruled by OQ-C-045-2 but §4 gives it no prop:
                // "it is not built until a consumer needs it". ui2-members-edit D28: still no
                // red border — the inline error line only.)
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(focused ? Token.textPrimary : Token.cardBorder, lineWidth: Self.borderWidth)
            )
            .contentShape(Rectangle())
    }

    // MARK: - Geometry

    // §2: Border 1px. The border INSETS the content — measured on the frozen snapshot, whose
    // caret (a hard-edged 2×24 rect) starts at frame + 17 horizontally and at frame + 10
    // vertically in the Multi symbols: 1 + 16 and 1 + 9, i.e. §2's p16/py9 from inside the
    // stroke.
    private static let borderWidth: CGFloat = 1

    // GAP — C-045 §2: Single/Phone 44pt and Multi 88pt minimum, no size token.
    private var minHeight: CGFloat { kind == .multi ? 88 : 44 }

    // FLAGGED LITERAL — C-045 §2: Multi py9, no spacing token (D7/D21). Single and Phone
    // state only "content vertically centred" inside 44pt, so their vertical inset is the
    // centring, not a padding value — and centring a 24pt line box in 44pt lands it at 10,
    // the same place the Multi inset puts it.
    private var verticalInset: CGFloat { kind == .multi ? Self.borderWidth + 9 : 0 }

    private var boxAlignment: SwiftUI.Alignment {
        switch kind {
        case .phone: return .center                   // §2: centred by anatomy
        case .single: return alignment == .center ? .center : .leading
        case .multi: return alignment == .center ? .top : .topLeading
        }
    }

    private var textAlignment: TextAlignment { alignment == .center ? .center : .leading }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if kind == .phone {
            phoneRow
        } else {
            textRun
        }
    }

    /// Single / Multi: one text run whose ROLE changes with `text`.
    private var textRun: some View {
        lineBoxed(
            Text(text.isEmpty ? placeholder : text)
                // §2: Single/Multi text — Regular 14/24 `type-input`.
                .designTextStyle(Token.TypeStyle.input)
                // §2: placeholder `color-input-placeholder`, value `color-input-value`.
                .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.inputValue)
                // §2: Single — one line · Multi — wrapping, each line per `alignment`.
                .lineLimit(kind == .single ? 1 : nil)
                .multilineTextAlignment(textAlignment),
            style: Token.TypeStyle.input
        )
        // §2 draws one text run whose role changes with `text` — the element map says which.
        .ui2Element(text.isEmpty ? "Placeholder" : "Value")
        // §2: Caret (focused only): at the content's leading edge — under `alignment:
        // center`, the leading edge of the centred run. An OVERLAY, not a row item: the
        // snapshot's focused and unfocused symbols place the text at the identical x.
        .overlay(alignment: kind == .single ? .leading : .topLeading) {
            if focused { caret }
        }
    }

    /// Phone: prefix + number entry, the group centred both ways (§2).
    private var phoneRow: some View {
        ZStack(alignment: .leading) {
            lineBoxed(
                Text(countryCode)
                    // §2: prefix always `color-text-primary`, Regular 18/24 `type-action-item`.
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundColor(Token.textPrimary)
                    .lineLimit(1),
                style: Token.TypeStyle.actionItem
            )
            .ui2Element("Prefix")

            lineBoxed(
                Text(text.isEmpty ? placeholder : text)
                    // §2: placeholder `color-input-placeholder`; value `color-text-primary`
                    // (white — unlike Single/Multi). Type `type-action-item`.
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.textPrimary)
                    .lineLimit(1),
                style: Token.TypeStyle.actionItem
            )
            .ui2Element(text.isEmpty ? "Placeholder" : "Value")
            // §2: Caret at the insertion point — the number entry's leading edge when
            // empty, its trailing edge when valued (symbols 4639:41648 / 4639:41666).
            .overlay(alignment: text.isEmpty ? .leading : .trailing) {
                if focused {
                    caret.alignmentGuide(.trailing) { $0[.leading] }
                }
            }
            // FLAGGED LITERAL — C-045 §2: the number entry's leading edge sits 24pt after the
            // prefix's leading edge (Figma 4639:41623 x = 24), no spacing token.
            .padding(.leading, 24)
        }
        .fixedSize()
    }

    /// §2: Regular 14/24 and 18/24 — glyphs sit centred in a 24pt line box. SwiftUI has no
    /// line-height: `designTextStyle` spells it as lineSpacing, applied only BETWEEN lines,
    /// so the first line would otherwise sit high. Centring the run in an explicit line box
    /// restores the half-leading above it.
    private func lineBoxed(_ text: some View, style: DesignTextStyle) -> some View {
        text
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: style.lineHeight ?? style.size)
    }

    /// §2: Caret — 2×24, r2, `color-accent`.
    private var caret: some View {
        RoundedRectangle(cornerRadius: Token.Radius.bar)
            .fill(Token.accent)
            // GAP — C-045 §2: caret 2×24, no size token.
            .frame(width: 2, height: 24)
            .ui2Element("Caret")
    }
}

/// ui2-members-edit T9e: C-045's live text run — a `TextField` drawn in §2's `type-input` and
/// colours, with the system caret tinted `color-accent` in place of the drawn 2×24 caret (the
/// C-034 SearchField editable-form precedent). Its own type so the focus state stays private
/// without touching `TextInput`'s memberwise initializer.
private struct LiveField: View {
    let text: String
    let placeholder: String
    let multiline: Bool
    let alignment: TextAlignment
    let editing: TextInput.Editing
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void

    /// Ephemeral UI state (R-02), reported out through `onFocusChange`.
    @FocusState private var fieldFocused: Bool

    init(
        text: String,
        placeholder: String,
        multiline: Bool,
        alignment: TextAlignment,
        editing: TextInput.Editing,
        onChange: @escaping (String) -> Void,
        onFocusChange: @escaping (Bool) -> Void
    ) {
        self.text = text
        self.placeholder = placeholder
        self.multiline = multiline
        self.alignment = alignment
        self.editing = editing
        self.onChange = onChange
        self.onFocusChange = onFocusChange
    }

    var body: some View {
        if let mask = editing.mask, !multiline {
            // input-masking: a masked field formats in the UIKit delegate, before the keystroke is
            // drawn — SwiftUI's TextField can only fix the text up after (a visible flicker, and
            // a fix-up that fights the next keystroke).
            MaskedTextField(
                text: text,
                placeholder: placeholder,
                mask: mask,
                alignment: alignment,
                editing: editing,
                onChange: onChange,
                onFocusChange: onFocusChange
            )
            .frame(maxWidth: .infinity)
            .frame(height: Token.TypeStyle.input.lineHeight ?? Token.TypeStyle.input.size)
        } else {
            plainField
        }
    }

    private var plainField: some View {
        TextField(
            editing.accessibilityName.isEmpty ? placeholder : editing.accessibilityName,
            text: Binding(get: { text }, set: { onChange($0) }),
            prompt: Text(placeholder).foregroundColor(Token.inputPlaceholder),
            // D22: Multi — return inserts a newline; Single — one line.
            axis: multiline ? .vertical : .horizontal
        )
        // §2: Single/Multi text — Regular 14/24 `type-input`, value `color-input-value`.
        .designTextStyle(Token.TypeStyle.input)
        .foregroundColor(Token.inputValue)
        .multilineTextAlignment(alignment)
        .tint(Token.accent)
        .keyboardType(editing.keyboard)
        .textContentType(editing.textContentType)
        .textInputAutocapitalization(editing.autocapitalization)
        .autocorrectionDisabled(!editing.autocorrect)
        .focused($fieldFocused)
        // D26: `saving` locks the input.
        .disabled(!editing.isEnabled)
        // D22: on a single-line page the return key does nothing — Save stays a tap — so the
        // field keeps focus instead of resigning.
        .onSubmit { if !multiline { fieldFocused = true } }
        .onChange(of: fieldFocused) { _, now in onFocusChange(now) }

        .onAppear { if editing.focusOnAppear { fieldFocused = true } }
    }
}

/// input-masking: C-045's masked live field — a `UITextField` whose delegate applies the mask in
/// `textField(_:shouldChangeCharactersIn:replacementString:)` and returns false, the standard iOS
/// pattern: the formatted text and caret are set before anything is drawn, so a keystroke past a
/// full mask changes nothing and backspace never fights the formatter. Drawn in §2's
/// `type-input` and colours, caret tinted `color-accent`, like `LiveField`'s `TextField`.
private struct MaskedTextField: UIViewRepresentable {
    let text: String
    let placeholder: String
    let mask: InputMask
    let alignment: TextAlignment
    let editing: TextInput.Editing
    let onChange: (String) -> Void
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = UIFont.systemFont(ofSize: Token.TypeStyle.input.size, weight: .regular)
        field.textColor = UIColor(Token.inputValue)
        field.tintColor = UIColor(Token.accent)
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(Token.inputPlaceholder)]
        )
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        if editing.focusOnAppear {
            Task { @MainActor in field.becomeFirstResponder() }
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // A caller-side change (seed, cap) — never re-set our own text: that moves the caret.
        if field.text != text { field.text = text }
        field.keyboardType = editing.keyboard
        field.textContentType = editing.textContentType
        field.autocapitalizationType = .none
        field.autocorrectionType = editing.autocorrect ? .default : .no
        field.isEnabled = editing.isEnabled
        field.textAlignment = alignment == .center ? .center : .natural
        field.accessibilityLabel = editing.accessibilityName.isEmpty ? placeholder : editing.accessibilityName
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MaskedTextField

        init(_ parent: MaskedTextField) { self.parent = parent }

        func textField(_ field: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let edit = parent.mask.applyEdit(to: field.text ?? "", range: range, replacement: string)
            if edit.text != field.text {
                field.text = edit.text
                parent.onChange(edit.text)
            }
            if let caret = field.position(from: field.beginningOfDocument, offset: edit.caret) {
                field.selectedTextRange = field.textRange(from: caret, to: caret)
            }
            return false
        }

        /// Autofill and dictation bypass the delegate: format whatever arrived.
        @objc func editingChanged(_ field: UITextField) {
            let current = field.text ?? ""
            let formatted = parent.mask.format(parent.mask.raw(current))
            if formatted != current { field.text = formatted }
            parent.onChange(formatted)
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool { false }   // D22: return does nothing
        func textFieldDidBeginEditing(_ field: UITextField) { parent.onFocusChange(true) }
        func textFieldDidEndEditing(_ field: UITextField) { parent.onFocusChange(false) }
    }
}
