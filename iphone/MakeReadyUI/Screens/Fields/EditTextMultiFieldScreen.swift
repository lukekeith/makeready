//
//  EditTextMultiFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen edit-text-multi-field in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id} · GET /api/groups/{id}
//  (the AI field-suggestion endpoint is an API-GAP in §5).
//  ui2-members-edit T9 a, c–e, routed to /ui2-resolve (F2): every addition to State is defaulted
//  to today's render. Wired by MakeReady/UI2/Containers/Members/MemberFieldEditContainer.swift.
//

import SwiftUI

/// Edit Text Multi Field — a pushed page that edits ONE multi-line text value of an entity and
/// saves it (§1). Composed only of §4's C-040, C-046 (→ C-045), C-051 (→ C-049) and C-048,
/// laid out by SharedEditFieldTemplate (D7).
struct EditTextMultiFieldScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2: C-040's centered title — the field's short name.
        var title: String
        /// §2: the screen-owned page description.
        var description: String
        /// §2: C-046's label.
        var label: String
        /// §1 deviation 5: placeholder copy is undesigned per use; proposed default "".
        var placeholder: String
        /// The input's current text.
        var text: String
        /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
        var loadedValue: String
        /// §3 input sub-state: focused → C-046 `style=Focus`.
        var focused: Bool
        /// §3 `saving`: a save is in flight.
        var saving: Bool
        /// §2: C-051's per-field prompt copy.
        var promptCopy: String
        /// §3: C-051's state — the screen owns the request, so the block's state is an input.
        var aiState: String
        /// §3: C-051's rows in `list` / `regenerating`.
        var suggestions: [String]
        /// §3 Length (OQ-edit-text-multi-field-3 proposed default): silent hard cap at the server
        /// limit — §5: `description: z.string().max(2000)`. T9d: a caller may set its own.
        var maxLength: Int = 2000
        /// T9c: §3 `save-failed`'s inline error line above Save; "" renders none.
        var errorMessage: String = ""
        /// T9a (D3): false hides C-051.
        var showsAISuggestions: Bool = true
        /// T9e: true → a live text field; false → the static render previews and captures use.
        var editable: Bool = false
        /// T9d (D22): the live field's focus on appear, keyboard, content type, caps, correction.
        var focusOnAppear: Bool = false
        var keyboard: UIKeyboardType = .default
        var textContentType: UITextContentType? = nil
        var autocapitalization: TextInputAutocapitalization = .sentences
        var autocorrect: Bool = true
    }

    let state: State
    var onBack: () -> Void = {}
    var onGenerate: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    var onTextChange: (String) -> Void = { _ in }

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onGenerate: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in },
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onGenerate = onGenerate
        self.onSave = onSave
        self.onTextChange = onTextChange
    }

    var body: some View {
        // D7: the layout is shared with edit-text-single-field — SharedEditFieldTemplate.swift.
        SharedEditFieldTemplate(
            title: state.title,
            description: state.description,
            label: state.label,
            field: .multilineText,                          // §2.3.2: C-046 `field=Multiline Text`
            placeholder: state.placeholder,
            text: state.text,
            loadedValue: state.loadedValue,
            focused: state.focused,
            saving: state.saving,
            promptCopy: state.promptCopy,
            aiState: state.aiState,
            suggestions: state.suggestions,
            allowsEmpty: true,                              // §3 Empty value (OQ-edit-text-multi-field-2 default)
            maxLength: state.maxLength,
            showsAISuggestions: state.showsAISuggestions,
            errorMessage: state.errorMessage,
            editable: state.editable,
            keyboard: state.keyboard,
            textContentType: state.textContentType,
            autocapitalization: state.autocapitalization,
            autocorrect: state.autocorrect,
            focusOnAppear: state.focusOnAppear,
            onBack: onBack,
            onGenerate: onGenerate,
            onSave: onSave,
            onTextChange: onTextChange
        )
    }
}

private extension EditTextMultiFieldScreen.State {
    /// §2's Group description content table — the base every preview varies. The field label
    /// takes OQ-edit-text-multi-field-1's proposed default ("Group description"), not the
    /// frame's "Program description" (§1 deviation 4).
    static func groupDescription(
        loadedValue: String = "A group designed for young men who are out of college and are beginning their professional journey",
        saving: Bool = false
    ) -> Self {
        .init(
            title: "Description",
            description: "The group description is used to help others understand the purpose of your group at a glance.",
            label: "Group description",
            placeholder: "",
            text: "A group designed for young men who are out of college and are beginning their professional journey",
            loadedValue: loadedValue,
            focused: false,
            saving: saving,
            promptCopy: "If you need help writing a description for your group, MakeReady AI can analyze your content and provide suggestions.",
            aiState: "prompt",
            suggestions: []
        )
    }
}

#Preview("clean") {
    EditTextMultiFieldScreen(state: .groupDescription())
        .frame(width: 440, height: 516)
}

#Preview("dirty") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: ""))
        .frame(width: 440)
}

#Preview("saving") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: "", saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditTextMultiFieldScreen(state: .groupDescription(loadedValue: ""))
        .frame(width: 440)
}
