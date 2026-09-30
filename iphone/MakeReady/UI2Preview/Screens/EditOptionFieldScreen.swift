//
//  EditOptionFieldScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen edit-option-field in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: PATCH /api/groups/{id}
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Edit Option Field — a pushed page that edits ONE single-choice value of an entity and
/// saves it (§2). Composed only of §4's C-040 PageHeader, C-047 RadioOptionRow and C-048
/// PageActionButton; the page description and the save-failed error line are screen-owned text.
struct EditOptionFieldScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §2.2: C-040's centred title — the field name.
        var title: String
        /// §2.3: the screen-owned page description (per-Use copy, §1 deviation 1).
        var description: String
        /// §2.3: the option stack's C-047 titles, top → bottom (count is per-Use, deviation 1).
        var options: [String]
        /// §2.3: each option's C-047 description, index-aligned with `options`.
        var optionDescriptions: [String]
        /// §3: the value the page was loaded with — what `clean` / `dirty` compare against.
        var loadedValue: String
        /// §3: the option currently selected (deviation 4: the loaded value decides the start).
        var selectedOption: String
        /// §3 `saving`: a save is in flight.
        var saving: Bool
        /// §3 `save-failed`: the inline error line's copy; empty renders no line.
        var errorMessage: String
    }

    let state: State
    var onBack: () -> Void = {}
    var onSave: (String) -> Void = { _ in }

    // §3 UI-only rule: "Tap a C-047 row → `onSelect` → that option becomes the single
    // selection. Exactly one option is selected at all times" — the local selection, seeded
    // from `State`.
    @SwiftUI.State private var selection: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        _selection = SwiftUI.State(initialValue: state.selectedOption)
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
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2.3: content column — inset `space-page-margin`, `space-page-margin` below the
            // header and below Save; `space-section-gap` between description, stack and Save.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.3: screen-owned text, `type-page-title`, `color-text-secondary`, wraps.
                Text(state.description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    // §2: 20pt line box (`type-page-title` 14/20). SwiftUI has no line-height,
                    // so a single line sits in its ~17pt font box unless the box is a minimum.
                    .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.3: C-047 rows at full content width, no gap and no separators.
                VStack(spacing: 0) {
                    ForEach(Array(state.options.enumerated()), id: \.offset) { index, option in
                        RadioOptionRow(
                            title: option,
                            description: description(at: index),
                            selected: option == selection,
                            onSelect: { select(option) }
                        )
                        .ui2Element(index == 0 ? "C-047 RadioOptionRow" : "C-047 RadioOptionRow \(index + 1)")
                    }
                }

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // §3 `save-failed` (proposed default, OQ-edit-option-field-2): "an inline
                    // error line sits in `type-page-title` `color-error` directly above Save".
                    if !state.errorMessage.isEmpty {
                        Text(state.errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, minHeight: Self.lineBox, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // §2.3: C-048 "Save", `role=affirmative`, `isEnabled` per §3.
                    PageActionButton(
                        label: Self.saveLabel,
                        role: .affirmative,
                        isEnabled: saveEnabled,
                        action: { onSave(selection) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: `color-layout-background`
    }

    private func description(at index: Int) -> String? {
        state.optionDescriptions.indices.contains(index) ? state.optionDescriptions[index] : nil
    }

    // §3: "tapping the selected row is a no-op"; `saving` makes the options inert.
    private func select(_ option: String) {
        guard !state.saving, option != selection else { return }
        selection = option
    }

    // §3: `clean` disables Save; `dirty` enables it; `saving` disables it; `save-failed`
    // re-enables it (the selection is kept, so it is still dirty).
    private var saveEnabled: Bool {
        !state.saving && selection != state.loadedValue
    }

    // §2.3: the action's copy.
    private static let saveLabel = "Save"

    /// The designed line box of `type-page-title`.
    private static let lineBox: CGFloat = Token.TypeStyle.pageTitle.lineHeight ?? Token.TypeStyle.pageTitle.size
}

private extension EditOptionFieldScreen.State {
    /// The Visibility Use, verbatim from the frozen frame (§1 deviation 1) — the base every
    /// preview varies.
    static func visibility(
        loadedValue: String = "Private",
        saving: Bool = false,
        errorMessage: String = ""
    ) -> Self {
        .init(
            title: "Visibility",
            description: "Visibility determines who is able to view the group",
            options: ["Private", "Public"],
            optionDescriptions: [
                "Only active members of the group can view information about the group, organization, and group leader.",
                "Anyone can search and view information about the group and the group leader."
            ],
            loadedValue: loadedValue,
            selectedOption: "Private",
            saving: saving,
            errorMessage: errorMessage
        )
    }
}

#Preview("clean") {
    EditOptionFieldScreen(state: .visibility())
        .frame(width: 440, height: 457)
}

#Preview("dirty") {
    EditOptionFieldScreen(state: .visibility(loadedValue: "Public"))
        .frame(width: 440)
}

#Preview("saving") {
    EditOptionFieldScreen(state: .visibility(loadedValue: "Public", saving: true))
        .frame(width: 440)
}

#Preview("save-failed") {
    EditOptionFieldScreen(state: .visibility(loadedValue: "Public", errorMessage: "Couldn't save group changes"))
        .frame(width: 440)
}

#Preview("load-failed") {
    EditOptionFieldScreen(state: .visibility())
        .frame(width: 440)
}
