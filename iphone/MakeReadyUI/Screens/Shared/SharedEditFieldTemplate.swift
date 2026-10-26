//
//  SharedEditFieldTemplate.swift
//  MakeReadyUI — the UI 2.0 module
//
//  The shared §2 layout of the screens minted from collection shared-edit-field whose layouts
//  differ only in content (D7): edit-text-single-field and edit-text-multi-field. Both §2s read
//  PageHeader → page description → C-046 FieldGroup → C-051 AISuggestionsBlock → C-048 Save,
//  in one content column; they differ in C-046's `field`, in whether an empty value may be
//  saved, and in the server's length cap — each taken here as a parameter.
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id} · GET /api/groups/{id}
//  (the AI field-suggestion endpoint is an API-GAP in both screens' §5).
//  ui2-members-edit T9 a–f, routed to /ui2-resolve (F2): C-051 can be hidden (a), the inline
//  error line above Save (c), keyboard/focus/cap per field (d), a live C-045 field (e), a
//  caller-supplied save rule (f). Every addition is defaulted to today's render.
//  Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift (ui2-members-edit).
//

import SwiftUI

/// The layout both text-field edit screens share. Each screen is a thin wrapper that keeps its
/// own `State`, closures and `#Preview` blocks and passes its content in.
struct SharedEditFieldTemplate: View {
    /// §2: C-040's centered title — the field's short name.
    let title: String
    /// §2: the screen-owned page description.
    let description: String
    /// §2: C-046's label.
    let label: String
    /// §2: C-046's `field` — the one structural value the two screens differ by.
    let field: FieldGroup.Field
    /// §1: placeholder copy is undesigned per use; proposed default "".
    let placeholder: String
    /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
    let loadedValue: String
    /// §3 input sub-state: focused → C-046 `style=Focus` (the static render; the live field
    /// reports its own focus).
    let focused: Bool
    /// §3 `saving`: a save is in flight — Save disabled and the input locked, no spinner (D26).
    let saving: Bool
    /// §2: C-051's per-field prompt copy.
    let promptCopy: String
    /// §3: C-051's state — the screen owns the request, so the block's state is an input.
    let aiState: String
    /// §3: C-051's rows in `list` / `regenerating`.
    let suggestions: [String]
    /// §3: whether a trimmed-empty value may be saved (single: no → `invalid`; multi: yes).
    let allowsEmpty: Bool
    /// §3 Length: the silent hard cap at the server limit (§5's zod `max`).
    let maxLength: Int
    /// ui2-members-edit T9a (D3): false hides C-051 — no member field offers AI suggestions.
    let showsAISuggestions: Bool
    /// T9c (D13/D16): §3 `save-failed`'s inline error line directly above Save, drawn as
    /// edit-option-field draws it; "" renders no line.
    let errorMessage: String
    /// T9e: true → a live C-045 text field the user types into; false → the static render the
    /// previews and captures use.
    let editable: Bool
    /// T9d (D22): the live field's keyboard, content type, capitalization and correction.
    let keyboard: UIKeyboardType
    let textContentType: UITextContentType?
    let autocapitalization: TextInputAutocapitalization
    let autocorrect: Bool
    /// D22: the live field takes focus on appear.
    let focusOnAppear: Bool
    /// T9f (D24): when given, replaces the dirty/empty rule with the caller's (it receives the
    /// trimmed text); `saving` still disables Save.
    let canSave: ((String) -> Bool)?
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    /// Every accepted edit (after the cap). No render effect.
    var onTextChange: (String) -> Void = { _ in }

    // §3 UI-only rule: "picking a suggestion replaces the input's text with it (→ `dirty`, or
    // `clean` if it equals the loaded value)" — the field's local text, seeded by the caller.
    @SwiftUI.State private var text: String
    /// The live field's focus as C-045 reports it; drives C-046 `style` when `editable`.
    @SwiftUI.State private var inputFocused = false

    init(
        title: String,
        description: String,
        label: String,
        field: FieldGroup.Field,
        placeholder: String,
        text: String,
        loadedValue: String,
        focused: Bool,
        saving: Bool,
        promptCopy: String,
        aiState: String,
        suggestions: [String],
        allowsEmpty: Bool,
        maxLength: Int,
        showsAISuggestions: Bool = true,
        errorMessage: String = "",
        editable: Bool = false,
        keyboard: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        autocapitalization: TextInputAutocapitalization = .sentences,
        autocorrect: Bool = true,
        focusOnAppear: Bool = false,
        canSave: ((String) -> Bool)? = nil,
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.title = title
        self.description = description
        self.label = label
        self.field = field
        self.placeholder = placeholder
        self.loadedValue = loadedValue
        self.focused = focused
        self.saving = saving
        self.promptCopy = promptCopy
        self.aiState = aiState
        self.suggestions = suggestions
        self.allowsEmpty = allowsEmpty
        self.maxLength = maxLength
        self.showsAISuggestions = showsAISuggestions
        self.errorMessage = errorMessage
        self.editable = editable
        self.keyboard = keyboard
        self.textContentType = textContentType
        self.autocapitalization = autocapitalization
        self.autocorrect = autocorrect
        self.focusOnAppear = focusOnAppear
        self.canSave = canSave
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
        self.onTextChange = onTextChange
        _text = SwiftUI.State(initialValue: text)
    }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 2) is not drawn — the canvas is
        // set at the call site.
        VStack(spacing: 0) {
            // §2.2: C-040 `twoIcons`, `showIcons=false`, `leadingGlyph=back`, centered title.
            PageHeader(
                style: .twoIcons,
                title: title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2.3: content column — padding `space-page-margin`, gap `space-section-gap`.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.3.1: screen-owned text, `type-page-title`, `color-text-secondary`, wraps.
                Text(description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.3.2: C-046 `field` per screen, `style` per focus (§3; OQ-C-046-1 ruled).
                FieldGroup(
                    label: label,
                    field: field,
                    style: (editable ? inputFocused : focused) ? .focus : .default,
                    layout: .default,
                    text: text,
                    placeholder: placeholder,
                    editing: editable ? liveEditing : nil,
                    onChange: { typed in
                        text = Self.capped(typed, maxLength: maxLength)
                        onTextChange(text)
                    },
                    onFocusChange: { inputFocused = $0 }
                )
                .ui2Element("C-046 FieldGroup")

                // §2.3.3: C-051 — `prompt` as drawn; the screen drives its state (§3). T9a: a
                // caller may hide it (D3).
                if showsAISuggestions {
                    AISuggestionsBlock(
                        state: AISuggestionsBlock.State(rawValue: aiState) ?? .prompt,
                        promptCopy: promptCopy,
                        suggestions: suggestions,
                        onGenerate: onGenerate,
                        onPick: { text = Self.capped($0, maxLength: maxLength) }
                    )
                    .ui2Element("C-051 AISuggestionsBlock")
                }

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // T9c — §3 `save-failed` (edit-option-field's proposed default,
                    // OQ-edit-option-field-2): "an inline error line sits in `type-page-title`
                    // `color-error` directly above Save". "" draws nothing, so the column is
                    // exactly today's.
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // §2.3.4: C-048 "Save", `role=affirmative`, `isEnabled` per §3.
                    PageActionButton(
                        label: Self.saveLabel,
                        role: .affirmative,
                        enabled: saveEnabled,
                        onTap: { onSave(trimmed) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: background
    }

    private var liveEditing: TextInput.Editing {
        TextInput.Editing(
            keyboard: keyboard,
            textContentType: textContentType,
            autocapitalization: autocapitalization,
            autocorrect: autocorrect,
            focusOnAppear: focusOnAppear,
            isEnabled: !saving,                              // D26: saving locks the input
            accessibilityName: label
        )
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var saveEnabled: Bool {
        Self.saveEnabled(text: text, loaded: loadedValue, allowsEmpty: allowsEmpty, saving: saving, canSave: canSave)
    }

    // §3: `clean` (equal to the loaded value) disables Save, and so does `invalid` (empty) where
    // the screen forbids an empty value; `dirty` enables it; `saving` disables it; `save-failed`
    // re-enables it. T9f (D24): a caller rule replaces clean/invalid, never `saving`.
    static func saveEnabled(
        text: String,
        loaded: String,
        allowsEmpty: Bool,
        saving: Bool,
        canSave: ((String) -> Bool)?
    ) -> Bool {
        guard !saving else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let canSave { return canSave(trimmed) }
        return (allowsEmpty || !trimmed.isEmpty)
            && trimmed != loaded.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// §3 Length: the silent hard cap — typed or picked text beyond it is dropped.
    static func capped(_ text: String, maxLength: Int) -> String { String(text.prefix(maxLength)) }

    // §2 content tables: the action's copy.
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}
