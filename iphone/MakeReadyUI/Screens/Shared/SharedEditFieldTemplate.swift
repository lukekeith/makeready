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
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
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
    /// §3 input sub-state: focused → C-046 `style=Focus`.
    let focused: Bool
    /// §3 `saving`: a save is in flight.
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
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }

    // §3 UI-only rule: "picking a suggestion replaces the input's text with it (→ `dirty`, or
    // `clean` if it equals the loaded value)" — the field's local text, seeded by the caller.
    @SwiftUI.State private var text: String

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
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in }
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
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
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
                    style: focused ? .focus : .default,
                    layout: .default,
                    text: text,
                    placeholder: placeholder
                )
                .ui2Element("C-046 FieldGroup")

                // §2.3.3: C-051 — `prompt` as drawn; the screen drives its state (§3).
                AISuggestionsBlock(
                    state: AISuggestionsBlock.State(rawValue: aiState) ?? .prompt,
                    promptCopy: promptCopy,
                    suggestions: suggestions,
                    onGenerate: onGenerate,
                    onPick: { text = String($0.prefix(maxLength)) }
                )
                .ui2Element("C-051 AISuggestionsBlock")

                // §2.3.4: C-048 "Save", `role=affirmative`, `isEnabled` per §3.
                PageActionButton(
                    label: Self.saveLabel,
                    role: .affirmative,
                    enabled: saveEnabled,
                    onTap: { onSave(trimmed) }
                )
                .ui2Element("C-048 PageActionButton")
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: background
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // §3: `clean` (equal to the loaded value) disables Save, and so does `invalid` (empty) where
    // the screen forbids an empty value; `dirty` enables it; `saving` disables it; `save-failed`
    // re-enables it.
    private var saveEnabled: Bool {
        !saving
            && (allowsEmpty || !trimmed.isEmpty)
            && trimmed != loadedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // §2 content tables: the action's copy.
    private static let saveLabel = "Save"
}
