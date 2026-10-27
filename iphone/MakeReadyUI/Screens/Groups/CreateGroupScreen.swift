//
//  CreateGroupScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen create-group in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/groups · GET /api/groups/{id}
//  Wired by MakeReady/UI2/Containers/Groups/CreateGroupContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edit, routed to /ui2-resolve (F3): the name field is live (D27 — the
//  `editing:` precedent of InviteMemberScreen.swift:160), read-only while creating.
//

import SwiftUI

/// Create group — a pushed page that collects the new group's name and creates it; the rest of
/// the group is managed on the group home page (§2 page description). Composed only of §4's
/// C-040, C-046 (→ C-045) and C-048. Standalone: the screen is not minted from a collection
/// (`identifiedFrom` is null), so no D7 template applies.
struct CreateGroupScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The name field's current text — §3 `empty` is blank/whitespace, `ready` is 1–200
        /// trimmed characters.
        var text: String
        /// The field is being edited (C-046 `Focus`) — §3 `empty`: "auto-focused on appear".
        var focused: Bool
        /// §3 `creating`: the create request is in flight.
        var creating: Bool
    }

    let state: State
    var onBack: () -> Void = {}
    var onCreate: (String) -> Void = { _ in }

    // §3 UI-only rule: "`empty` — name blank or whitespace-only; Create renders `isEnabled:
    // false` … `ready` — trimmed name has 1–200 characters" — the field's local text, seeded
    // from `State`. "The input does not accept characters past 200 (server limit, §5)."
    @SwiftUI.State private var text: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onCreate: @escaping (String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onCreate = onCreate
        _text = SwiftUI.State(initialValue: String(state.text.prefix(Self.maxLength)))
    }

    var body: some View {
        // §2: top → bottom. The system status bar (§1 deviation 1) is the harness's, not drawn here.
        VStack(spacing: 0) {
            // §2.2: C-040 `twoIcons` + `showIcons: false` — back + centred title.
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

            // §2.3: content — padding `space-page-margin` on all sides, gap `space-section-gap`.
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                // §2.3.1: page description — screen-owned text, `type-body-sm`,
                // `color-text-secondary`, wraps.
                Text(Self.description)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // §2.3.2: C-046 `Text`, `Default` (→ `Focus` while editing) — label + 44pt
                // C-045 TextInput.
                FieldGroup(
                    label: Self.label,
                    field: .text,
                    style: fieldFocused ? .focus : .default,
                    layout: .default,
                    text: text,
                    placeholder: Self.placeholder,
                    editing: Self.fieldEditing(creating: state.creating),
                    // §3: "The input does not accept characters past 200 (server limit, §5)."
                    onChange: { text = String($0.prefix(Self.maxLength)) }
                )
                .ui2Element("C-046 FieldGroup")

                // §2.3.3: C-048 "Create" — `affirmative`, `isEnabled` per §3.
                PageActionButton(
                    label: Self.createLabel,
                    role: .affirmative,
                    enabled: createEnabled,
                    onTap: { onCreate(trimmed) }
                )
                .ui2Element("C-048 PageActionButton")
            }
            .padding(Token.Space.pageMargin)
        }
        // §2.4: empty background below the button; no scroll.
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2: page background
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // §3: `empty` disables Create, `ready` enables it; `creating` disables it (OQ-create-group-002,
    // ruled: no spinner); `create-failed` keeps the name and Create is the retry, so it is enabled.
    private var createEnabled: Bool { !state.creating && !trimmed.isEmpty }

    // §3 `creating`: "the field is read-only" — it does not render as being edited.
    private var fieldFocused: Bool { state.focused && !state.creating }

    // §3: "The input does not accept characters past 200 (server limit, §5)."
    private static let maxLength = 200

    /// D27: C-045's live form — focused on appear (§3 `empty`), locked while creating (§3
    /// `creating`: "the field is read-only").
    static func fieldEditing(creating: Bool) -> TextInput.Editing {
        TextInput.Editing(focusOnAppear: true, isEnabled: !creating)
    }

    // §2 / §1 deviation 4 — final copy.
    private static let title = "Create group"
    private static let description = "Start by giving your group a name. The rest of the group information can be managed on the group home page."
    private static let label = "Give your group a name"
    private static let placeholder = "Group name"
    private static let createLabel = "Create"
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension CreateGroupScreen.State {
    /// §3 `empty` — name blank; the field auto-focused on appear.
    static let empty = Self(text: "", focused: true, creating: false)
    /// §3 `ready` — a typed name, still editing. "Value" is C-045's own contract sample string:
    /// the frozen frame draws no name.
    static let ready = Self(text: "Value", focused: true, creating: false)
    /// §3 `creating` — the sample name with the create request in flight; the field read-only.
    static let createInFlight = Self(text: "Value", focused: false, creating: true)
    /// §3 `create-failed` — the name kept, Create re-enabled as the retry. The failure copy is
    /// the app shell's error surface (§6), not this screen's.
    static let createFailed = Self(text: "Value", focused: false, creating: false)
}

#Preview("empty") {
    CreateGroupScreen(state: .empty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("ready") {
    CreateGroupScreen(state: .ready)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("creating") {
    CreateGroupScreen(state: .createInFlight)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("create-failed") {
    CreateGroupScreen(state: .createFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
