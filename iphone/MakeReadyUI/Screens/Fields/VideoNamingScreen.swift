//
//  VideoNamingScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-naming in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/videos · PATCH /api/videos/:id
//  (POST /api/videos/suggest-details is an API-GAP in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Video naming — the page shown after a leader saves a recorded or imported video: C-040 back +
/// "Name your video" + the done check, the Title and Description C-046 fields, then the C-051
/// AI-suggestions block. Every exit is an `on<Verb>` closure (R-03); the host container scrolls
/// the page and keeps the focused field above the keyboard (§2 no-root-scroll).
struct VideoNamingScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// §3: the Title field's text. Starts empty.
        var title: String
        /// §3: the Title field's placeholder — the caller's ("Video 3").
        var titlePlaceholder: String
        /// §3: the Description field's text. Starts empty.
        var description: String
        /// §3: selects the suggestions block's body; the caller owns it (R-01).
        var aiState: AISuggestionsBlock.State
        /// §3: the paragraph drawn in `prompt` and `empty`.
        var promptCopy: String
        /// §3 `suggestions` — the title and description pairs, in order. Spelled as C-051 spells
        /// it: the capture decoder's `suggestions` is C-051's `[String]`.
        var pairs: [SuggestionRows.Pair]
    }

    let state: State
    // §3 taps and outcomes — each an on<Verb> closure with R-03's no-op default.
    var onTitleChange: (String) -> Void = { _ in }          // after the cap
    var onDescriptionChange: (String) -> Void = { _ in }    // after the cap
    var onPick: (Int) -> Void = { _ in }                    // the caller replaces both fields
    var onRegenerate: () -> Void = {}                       // "Try again" / "AI suggestions"
    var onSave: () -> Void = {}                             // the check — always tappable
    var onBack: () -> Void = {}                             // leaves without saving

    // §3 Fields: the local text the caps apply to, seeded by the caller and replaced whenever the
    // caller's value changes (a picked pair).
    @SwiftUI.State private var title: String
    @SwiftUI.State private var description: String
    // §3: "focus is ephemeral screen state (R-02, R-31)" — as C-045 reports it.
    @SwiftUI.State private var titleFocused = false
    @SwiftUI.State private var descriptionFocused = false

    init(
        state: State,
        onTitleChange: @escaping (String) -> Void = { _ in },
        onDescriptionChange: @escaping (String) -> Void = { _ in },
        onPick: @escaping (Int) -> Void = { _ in },
        onRegenerate: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onTitleChange = onTitleChange
        self.onDescriptionChange = onDescriptionChange
        self.onPick = onPick
        self.onRegenerate = onRegenerate
        self.onSave = onSave
        self.onBack = onBack
        _title = SwiftUI.State(initialValue: state.title)
        _description = SwiftUI.State(initialValue: state.description)
    }

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // §2 section-gap: page top, fields and suggestions stack `space-section-gap` apart.
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            pageHeader
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                titleField
                descriptionField
                suggestionsBlock
            }
            .padding(.horizontal, Token.Space.pageMargin)       // §2 page-margin
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                     // §2: background
    }

    // MARK: §2 1. Page top

    /// C-040 `twoIcons`, no trailing glyphs, `showsDone` — C-040 draws the C-159 check.
    private var pageHeader: some View {
        PageHeader(
            style: .twoIcons,
            title: Self.pageTitle,
            showTitle: true,
            showIcons: false,
            showsDone: true,
            leadingGlyph: .back,
            rightButtons: [],
            onLeading: onBack,
            onDone: onSave
        )
        .ui2Element("C-040 PageHeader")
    }

    // MARK: §2 2. Fields

    /// C-046 `Text` — the silent cap runs in `.onChange`, not in the keystroke: clipping there
    /// writes back an equal value and the field keeps showing the over-cap characters.
    private var titleField: some View {
        FieldGroup(
            label: Self.titleLabel,
            field: .text,
            style: titleFocused ? .focus : .default,
            layout: .default,
            text: title,
            placeholder: state.titlePlaceholder,
            // §3: "Title return key dismisses the keyboard" — a given action replaces C-045's
            // keep-focus default, and the system then resigns the field.
            editing: TextInput.Editing(accessibilityName: Self.titleLabel, onSubmit: {}),
            onChange: { title = $0 },
            onFocusChange: { titleFocused = $0 }
        )
        .ui2Element("C-046 FieldGroup")
        .onChange(of: state.title) { _, new in title = new }
        .onChange(of: title) { _, new in
            if new.count > Self.titleCap {
                title = String(new.prefix(Self.titleCap))
            } else if new != state.title {
                onTitleChange(new)
            }
        }
    }

    /// C-046 `Multiline Text` — return inserts a newline (C-045's live Multi).
    private var descriptionField: some View {
        FieldGroup(
            label: Self.descriptionLabel,
            field: .multilineText,
            style: descriptionFocused ? .focus : .default,
            layout: .default,
            text: description,
            placeholder: "",                                    // §2: proposed (OQ-video-naming-004)
            editing: TextInput.Editing(accessibilityName: Self.descriptionLabel),
            onChange: { description = $0 },
            onFocusChange: { descriptionFocused = $0 }
        )
        .ui2Element("C-046 FieldGroup 2")
        .onChange(of: state.description) { _, new in description = new }
        .onChange(of: description) { _, new in
            if new.count > Self.descriptionCap {
                description = String(new.prefix(Self.descriptionCap))
            } else if new != state.description {
                onDescriptionChange(new)
            }
        }
    }

    // MARK: §2 3. AI suggestions

    /// C-051 — "Always present."
    private var suggestionsBlock: some View {
        AISuggestionsBlock(
            state: state.aiState,
            promptCopy: state.promptCopy,
            suggestions: [],
            pairs: state.pairs,
            onGenerate: onRegenerate,
            onPickIndex: onPick
        )
        .ui2Element("C-051 AISuggestionsBlock")
    }

    // §2 — final copy.
    private static let pageTitle = "Name your video"
    private static let titleLabel = "Title"
    private static let descriptionLabel = "Description"

    // §3: "Title silently capped at 80 characters, Description at 300; no counter."
    private static let titleCap = 80
    private static let descriptionCap = 300
}

// MARK: - Sample states (the preview props, single-sourced for the #Preview blocks and the
// capture case)

extension VideoNamingScreen.State {
    /// C-051's `list · pairs` contract sample: three pairs, a long title and long descriptions.
    static let samplePairs: [SuggestionRows.Pair] = [
        .init(
            title: "Daily leadership lessons for small groups that meet before work",
            description: "Five short lessons on leading a small group well, from preparing the opening question to following up with each member during the week."
        ),
        .init(
            title: "Grappling with truth",
            description: "How to handle the hard questions your group raises."
        ),
        .init(
            title: "God in our lives",
            description: "A look at where we notice God at work day to day, with three questions to ask your group before you close in prayer together."
        ),
    ]

    /// §3 1 — the fields start empty; the placeholder is the brief's "Video 3".
    static let generating = Self(
        title: "", titlePlaceholder: "Video 3", description: "",
        aiState: .generating, promptCopy: "", pairs: []
    )
    /// §3 2 — populated.
    static let list = Self(
        title: "", titlePlaceholder: "Video 3", description: "",
        aiState: .list, promptCopy: "", pairs: samplePairs
    )
    /// §3 3 — the status row over the same rows.
    static let regenerating = Self(
        title: "", titlePlaceholder: "Video 3", description: "",
        aiState: .regenerating, promptCopy: "", pairs: samplePairs
    )
    /// §3 4 — the error state.
    static let prompt = Self(
        title: "", titlePlaceholder: "Video 3", description: "",
        aiState: .prompt, promptCopy: "Couldn't get suggestions", pairs: []
    )
    /// §3 5 — the empty state.
    static let empty = Self(
        title: "", titlePlaceholder: "Video 3", description: "",
        aiState: .empty, promptCopy: "No speech to suggest from", pairs: []
    )
    /// §3 6 — the first pair picked; the block stays in `list`.
    static let filled = Self(
        title: samplePairs[0].title, titlePlaceholder: "Video 3", description: samplePairs[0].description,
        aiState: .list, promptCopy: "", pairs: samplePairs
    )
}

#Preview("generating") {
    VideoNamingScreen(state: .generating)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("list") {
    VideoNamingScreen(state: .list)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("regenerating") {
    VideoNamingScreen(state: .regenerating)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("prompt") {
    VideoNamingScreen(state: .prompt)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty") {
    VideoNamingScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("filled") {
    VideoNamingScreen(state: .filled)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
