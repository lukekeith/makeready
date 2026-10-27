//
//  EditOptionsCustomFieldScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen edit-options-custom-field in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id}
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Edit Options Custom Field — a pushed page that edits ONE bounded value of an entity by
/// picking a preset option or typing custom bounds, and saves it (§2). Composed only of §4's
/// C-040 PageHeader, C-047 RadioOptionRow, C-046 FieldGroup (→ C-045) and C-048
/// PageActionButton; the page description is screen-owned text.
struct EditOptionsCustomFieldScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2.2: C-040's centred title — the field name.
        var title: String
        /// §2.3.1: the screen-owned page description (per-instance copy, §1 deviation 1).
        var description: String
        /// §2.3.2: the option stack's C-047 titles, top → bottom. The first is the "any"
        /// option, the last is the custom option, the ones between are presets (§3).
        var options: [String]
        /// §3: each preset's lower bound, index-aligned with the presets in `options`.
        var presetMinimums: [Int]
        /// §3: each preset's upper bound, index-aligned with the presets in `options`.
        var presetMaximums: [Int]
        /// §4: the first C-046's label.
        var minimumLabel: String
        /// §4: the second C-046's label.
        var maximumLabel: String
        /// §1 deviation 3: the first input's placeholder.
        var minimumPlaceholder: String
        /// §1 deviation 3: the second input's placeholder.
        var maximumPlaceholder: String
        /// §3: the option selected when the page opens.
        var selectedOption: String
        /// The first input's text ("" = no bound).
        var minimum: String
        /// The second input's text ("" = no bound).
        var maximum: String
        /// §3: the stored lower bound as loaded ("" = null) — what `clean` / `dirty` compare against.
        var loadedMinimum: String
        /// §3: the stored upper bound as loaded ("" = null).
        var loadedMaximum: String
        /// §3 input focus: "minimum" | "maximum" | "" — the focused C-046 renders `style=Focus`.
        var focusedInput: String
        /// §3 `saving`: a save is in flight.
        var saving: Bool
        // GAP — editable age inputs, routed to /ui2-resolve (ui2-groups-edit final review)
        /// true → both inputs are live number-pad fields; false → the static render previews and
        /// captures use (members-edit T9e's precedent for the text screens).
        var editable: Bool = false
    }

    let state: State
    var onBack: () -> Void = {}
    var onSave: (String, String) -> Void = { _, _ in }

    // §3 UI-only rule: "Exactly one option is selected at all times (single-select); tapping
    // a row's `onSelect` selects it" — the local selection, seeded from `State`.
    @SwiftUI.State private var selection: String
    // §3 UI-only rule: "Selecting a preset fills both inputs … Selecting the 'any' option
    // clears both inputs" — the inputs' local text, seeded from `State`.
    @SwiftUI.State private var minimum: String
    @SwiftUI.State private var maximum: String
    // The live fields' focus as C-045 reports it; drives C-046 `style` when `editable`.
    @SwiftUI.State private var liveFocus: String = ""

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        _selection = SwiftUI.State(initialValue: state.selectedOption)
        _minimum = SwiftUI.State(initialValue: state.minimum)
        _maximum = SwiftUI.State(initialValue: state.maximum)
    }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 2) is not drawn — the canvas is
        // set at the call site.
        VStack(spacing: 0) {
            // §2.2: C-040 `twoIcons`, `showIcons=false`, leading glyph `back`, centred title.
            PageHeader(
                style: .twoIcons,
                title: state.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2.3: content column — inset `space-page-margin`, `space-page-margin` above the
            // description and below Save; `space-section-gap` between the four parts.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.3.1: screen-owned text, `type-page-title`, `color-text-secondary`, wraps.
                Text(state.description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    // §2: 20pt line box (`type-page-title` 14/20).
                    .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.3.2: C-047 rows at full content width, 0 gap, title-only.
                VStack(spacing: 0) {
                    ForEach(Array(state.options.enumerated()), id: \.offset) { index, option in
                        RadioOptionRow(
                            title: option,
                            description: nil,
                            selected: option == selection,
                            onSelect: { select(option, at: index) }
                        )
                        .ui2Element(index == 0 ? "C-047 RadioOptionRow" : "C-047 RadioOptionRow \(index + 1)")
                    }
                }

                // §2.3.3: 2 × C-046 `field=Text`, side by side, each half the content width
                // less the gutter (196).
                // FLAGGED LITERAL — edit-options-custom-field §2: column gutter 16, no gutter-role token
                HStack(alignment: .top, spacing: 16) {
                    FieldGroup(
                        label: state.minimumLabel,
                        field: .text,
                        style: focusedInput == Self.minimumKey ? .focus : .default,
                        layout: .default,
                        text: minimum,
                        placeholder: state.minimumPlaceholder,
                        editing: state.editable ? liveEditing(state.minimumLabel) : nil,
                        onChange: { minimum = $0; selectCustom() },
                        onFocusChange: { focusChanged(Self.minimumKey, $0) }
                    )
                    .ui2Element("C-046 FieldGroup")

                    FieldGroup(
                        label: state.maximumLabel,
                        field: .text,
                        style: focusedInput == Self.maximumKey ? .focus : .default,
                        layout: .default,
                        text: maximum,
                        placeholder: state.maximumPlaceholder,
                        editing: state.editable ? liveEditing(state.maximumLabel) : nil,
                        onChange: { maximum = $0; selectCustom() },
                        onFocusChange: { focusChanged(Self.maximumKey, $0) }
                    )
                    .ui2Element("C-046 FieldGroup 2")
                }

                // §2.3.4: C-048 "Save", `role=affirmative`, `isEnabled` per §3.
                PageActionButton(
                    label: Self.saveLabel,
                    role: .affirmative,
                    enabled: saveEnabled,
                    onTap: { onSave(minimum, maximum) }
                )
                .ui2Element("C-048 PageActionButton")
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: `color-layout-background`
    }

    // §3: "Selecting a preset fills both inputs with that preset's bounds … Selecting the
    // 'any' option clears both inputs to empty … Selecting the custom option keeps whatever
    // the inputs hold." `saving` makes the options inert.
    private func select(_ option: String, at index: Int) {
        guard !state.saving else { return }
        selection = option
        if index == 0 {
            minimum = ""
            maximum = ""
        } else if index < state.options.count - 1 {
            let preset = index - 1
            if state.presetMinimums.indices.contains(preset) { minimum = String(state.presetMinimums[preset]) }
            if state.presetMaximums.indices.contains(preset) { maximum = String(state.presetMaximums[preset]) }
        }
    }

    /// The focused input: the live fields report their own focus; the static render uses `State`.
    private var focusedInput: String { state.editable ? liveFocus : state.focusedInput }

    /// The live fields' keyboard: whole numbers only (§5), locked while saving (D26).
    private func liveEditing(_ label: String) -> TextInput.Editing {
        TextInput.Editing(
            keyboard: .numberPad,
            autocapitalization: .never,
            autocorrect: false,
            isEnabled: !state.saving,
            accessibilityName: label
        )
    }

    // §3: typing a bound is a custom range — the selection follows the keystroke to the
    // custom option.
    private func selectCustom() {
        if let custom = state.options.last { selection = custom }
    }

    private func focusChanged(_ key: String, _ focused: Bool) {
        if focused {
            liveFocus = key
        } else if liveFocus == key {
            liveFocus = ""
        }
    }

    private var saveEnabled: Bool {
        Self.saveEnabled(
            selection: selection, minimum: minimum, maximum: maximum,
            loadedMinimum: state.loadedMinimum, loadedMaximum: state.loadedMaximum,
            options: state.options, saving: state.saving
        )
    }

    /// §3: `clean` disables Save; `dirty-valid` enables it; `dirty-invalid` disables it;
    /// `saving` disables it; `save-failed` keeps the value, so it is still dirty-valid.
    /// `dirty-invalid` (proposed default, OQ-edit-options-custom-field-3): "min > max;
    /// outside 0–120; custom option selected with both inputs empty". Dirty compares the
    /// effective bounds, so "030" against a stored 30 is clean.
    static func saveEnabled(
        selection: String, minimum: String, maximum: String,
        loadedMinimum: String, loadedMaximum: String,
        options: [String], saving: Bool
    ) -> Bool {
        let dirty = effective(minimum) != effective(loadedMinimum)
            || effective(maximum) != effective(loadedMaximum)
        guard !saving, dirty else { return false }
        if selection == options.last && minimum.isEmpty && maximum.isEmpty { return false }
        let low = bound(minimum)
        let high = bound(maximum)
        if (!minimum.isEmpty && low == nil) || (!maximum.isEmpty && high == nil) { return false }
        if let low, let high, low > high { return false }
        return true
    }

    /// A bound's effective value: its whole number when it parses, else the text as typed.
    private static func effective(_ text: String) -> String {
        Int(text).map(String.init) ?? text
    }

    // §5: `ageRange.min/max` int 0–120. Behaviour, not a design value.
    private static let bounds = 0...120
    private static func bound(_ text: String) -> Int? {
        guard let value = Int(text), bounds.contains(value) else { return nil }
        return value
    }

    private static let minimumKey = "minimum"
    private static let maximumKey = "maximum"

    // §2.3.4: the action's copy.
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}

private extension EditOptionsCustomFieldScreen.State {
    /// The Age-range instance, verbatim from the frozen frame (§1 deviation 1) — the base
    /// every preview varies.
    static func ageRange(
        selectedOption: String = "Any age",
        minimum: String = "",
        maximum: String = "",
        saving: Bool = false
    ) -> Self {
        .init(
            title: "Age range",
            description: "If an age range is specified, then every member who joins must fall within the specified range.",
            options: ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"],
            presetMinimums: [18, 26, 36],
            presetMaximums: [25, 35, 50],
            minimumLabel: "Minimum age",
            maximumLabel: "Maximum age",
            minimumPlaceholder: "18",
            maximumPlaceholder: "24",
            selectedOption: selectedOption,
            minimum: minimum,
            maximum: maximum,
            loadedMinimum: "",
            loadedMaximum: "",
            focusedInput: "",
            saving: saving
        )
    }
}

#Preview("clean") {
    EditOptionsCustomFieldScreen(state: .ageRange())
        .frame(width: 440, height: 649)
}

#Preview("dirty-valid") {
    EditOptionsCustomFieldScreen(state: .ageRange(selectedOption: "18 - 25", minimum: "18", maximum: "25"))
        .frame(width: 440)
}

#Preview("dirty-invalid") {
    EditOptionsCustomFieldScreen(state: .ageRange(selectedOption: "Custom range", minimum: "25", maximum: "18"))
        .frame(width: 440)
}

#Preview("saving") {
    EditOptionsCustomFieldScreen(state: .ageRange(selectedOption: "18 - 25", minimum: "18", maximum: "25", saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditOptionsCustomFieldScreen(state: .ageRange(selectedOption: "18 - 25", minimum: "18", maximum: "25"))
        .frame(width: 440)
}
