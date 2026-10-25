//
//  CreateStudyProgramScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen create-study-program in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/programs · GET /api/programs/{id}
//  (§5 API-GAP: the route requires `templateId`, this design collects a title only — OQ-2).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Create Study Program — step 1 of the creation flow: a pushed page that collects the new
/// program's title and creates it (§1). Composed only of §4's C-040, C-046 (→ C-045) and C-048,
/// laid out as the shared-edit-field pattern's §2. Standalone: the screen is not minted from a
/// collection (`identifiedFrom` is null), so no D7 template applies, and the pattern's
/// SharedEditFieldTemplate places C-051, which this §2 excludes.
struct CreateStudyProgramScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The title field's current text — §3 `empty` is blank, `ready` is non-blank.
        var text: String
        /// §3 `creating`: the create call is in flight.
        var creating: Bool
        /// §3 `create-failed`: the inline error line's copy; empty renders no line.
        var errorMessage: String
    }

    let state: State
    var onBack: () -> Void = {}
    var onCreate: (String) -> Void = { _ in }

    // §3 UI-only rule: "`empty` — title blank; Create renders `disabled`. `ready` — title
    // non-blank; Create renders `affirmative`" — the field's local text, seeded from `State`.
    @SwiftUI.State private var text: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCreate: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onCreate = onCreate
        _text = SwiftUI.State(initialValue: state.text)
    }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 2) is the harness's, not drawn here.
        VStack(spacing: 0) {
            // §2: C-040 `Two icons` + `showIcons=false` — back + centered title.
            PageHeader(
                style: .twoIcons,
                title: Self.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2: content — p16 (`space-page-margin`), gap `space-section-gap` 32.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.1: page description — Regular 14/20 (`type-page-title`),
                // `color-text-secondary`, wraps.
                Text(Self.description)
                    .designTextStyle(Token.TypeStyle.pageTitle)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.2: C-046 `Text`/`Default` — label + 44pt C-045 TextInput.
                FieldGroup(
                    label: Self.label,
                    field: .text,
                    style: .default,
                    layout: .default,
                    text: text,
                    placeholder: Self.placeholder
                )
                .ui2Element("C-046 FieldGroup")

                VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                    // §3 `create-failed` (proposed default per OQ-shared-edit-field-3): "inline
                    // error above the button, value preserved". The line's type, colour and gap
                    // are the pattern's other built instance (edit-option-field's save-failed):
                    // `type-page-title`, `color-error`, `space-element-gap`.
                    if !state.errorMessage.isEmpty {
                        Text(state.errorMessage)
                            .designTextStyle(Token.TypeStyle.pageTitle)
                            .foregroundStyle(Token.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // §2.3: C-048 "Create" — `affirmative`, `isEnabled` per §3.
                    PageActionButton(
                        label: Self.createLabel,
                        role: .affirmative,
                        enabled: createEnabled,
                        onTap: { onCreate(trimmed) }
                    )
                    .ui2Element("C-048 PageActionButton")
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: page background
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // §3: `empty` disables Create, `ready` enables it; `creating` disables it (proposed default,
    // OQ-shared-edit-field-3 — its activity indicator has no §4 component, reported as a gap);
    // `create-failed` preserves the value, so Create is enabled again.
    private var createEnabled: Bool { !state.creating && !trimmed.isEmpty }

    // §2 copy.
    private static let title = "Create study program"
    // §1 deviation 1: final copy TBD — the frozen frame's text, verbatim, until the owner
    // supplies it.
    private static let description = "The study program you create will serve as curriculum that can be edited and managed long-term and enrolled in any group. It is also capable of baking cookies and breakfast tacos."
    private static let label = "Give your program a title"
    // Placeholder copy is undesigned (the pattern's proposed default ""); "Daily Inspiration"
    // is the sample title (§1 deviation 1), not a placeholder.
    private static let placeholder = ""
    private static let createLabel = "Create"
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension CreateStudyProgramScreen.State {
    /// §3 `empty` — title blank.
    static let empty = Self(text: "", creating: false, errorMessage: "")
    /// §3 `ready` — the frozen frame's sample title (§1 deviation 1).
    static let ready = Self(text: "Daily Inspiration", creating: false, errorMessage: "")
    /// §3 `creating` — the sample title with the create call in flight.
    static let createInFlight = Self(text: "Daily Inspiration", creating: true, errorMessage: "")
    /// §3 `create-failed` — value preserved; the copy is legacy CreateProgramPage's
    /// `friendlyMessage` for the same failure (§7 replaces that page).
    static let createFailed = Self(text: "Daily Inspiration", creating: false, errorMessage: "Couldn't create the program")
}

#Preview("empty") {
    CreateStudyProgramScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("ready") {
    CreateStudyProgramScreen(state: .ready)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("creating") {
    CreateStudyProgramScreen(state: .createInFlight)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("create-failed") {
    CreateStudyProgramScreen(state: .createFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
