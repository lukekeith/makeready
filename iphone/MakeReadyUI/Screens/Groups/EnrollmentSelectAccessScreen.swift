//
//  EnrollmentSelectAccessScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollment-select-access in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/enrollments (run by the checklist's
//  Enroll, `groups-enroll-program`, never from here; this screen writes the draft's `lessonAccess`
//  only — a field the server does not have yet, §5 API-GAP).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select accessibility — the "Accessibility" step of the enrollment checklist
/// (`groups-enroll-program`, §3): a single-select picker between One at a time (`one-at-a-time`)
/// and All at once (`all-at-once`). Only Save commits. C-040 header over two C-047 rows (§2).
/// Composed only of §4's C-040 and C-047.
///
/// §3 names two states — `one-at-a-time` (row 1 selected) and `all-at-once` (row 2 selected).
/// There is no loading, empty, error or disabled state: Save is always enabled (§3).
struct EnrollmentSelectAccessScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The checklist draft's `lessonAccess` (§5): "one-at-a-time", "all-at-once", or "" when
        /// unset. Any value outside those two opens on one-at-a-time (§3 opening value).
        var lessonAccess: String
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                                  // §3 Back: discard + pop
    var onSave: (_ lessonAccess: String) -> Void = { _ in }      // §3 Save: commit + pop

    // R-31 ephemeral UI — §3: "Tap a row selects it and deselects the other … the selection
    // model is the screen's"; Back discards it, so it lives here until Save.
    @SwiftUI.State private var selection: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ lessonAccess: String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        // §3 opening value: the saved value when it is one of the two, else the recommended
        // one-at-a-time.
        _selection = SwiftUI.State(
            initialValue: state.lessonAccess == Self.allAtOnce ? Self.allAtOnce : Self.oneAtATime
        )
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §1 deviation 1: the title is "Select accessibility" (the layer's "Set response
    /// requirement" is a leftover).
    private static let pageTitle = "Select accessibility"
    /// §1 deviation 2: the trailing text action reads "Save".
    private static let saveLabel = "Save"
    /// §3: One at a time → `one-at-a-time`, All at once → `all-at-once`.
    private static let oneAtATime = "one-at-a-time"
    private static let allAtOnce = "all-at-once"
    /// §2 L3, verbatim (§1 deviation 5).
    private static let oneTitle = "One at a time"
    private static let oneDescription = "Enrollment lessons will not be available to members until the day "
        + "they are scheduled at the specified time."
    private static let allTitle = "All at once"
    private static let allDescription = "Members can access any lesson of the enrollment after the first day "
        + "of the enrollment."

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            header
            options
                .padding(.top, Token.Space.pageMargin)               // §2 L3: 16 top padding
                .padding(.horizontal, Token.Space.pageMargin)        // §2: `space-page-margin`
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                          // §2: the page background
    }

    /// §2 L2: C-040 `style: backAndLink` (D60) — back glyph, centred title, trailing "Save",
    /// always enabled (§3).
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.pageTitle,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: Self.saveLabel,
            trailingEnabled: true,
            onLeading: onBack,
            onDone: { onSave(selection) }
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2 L3: two C-047 rows, no gap between them (each carries its own 16 vertical padding).
    private var options: some View {
        VStack(spacing: 0) {
            RadioOptionRow(
                title: Self.oneTitle,
                description: Self.oneDescription,
                selected: selection == Self.oneAtATime,
                recommended: true,                                   // D61: the ★
                onSelect: { selection = Self.oneAtATime }
            )
            .ui2Element("C-047 RadioOptionRow")
            RadioOptionRow(
                title: Self.allTitle,
                description: Self.allDescription,
                selected: selection == Self.allAtOnce,
                onSelect: { selection = Self.allAtOnce }
            )
            .ui2Element("C-047 RadioOptionRow 2")
        }
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension EnrollmentSelectAccessScreen.State {
    /// §3 `one-at-a-time` (frame `one-at-a-time`) — the draft holds `one-at-a-time`.
    static let oneAtATime = Self(lessonAccess: "one-at-a-time")
    /// §3 `all-at-once` — the draft holds `all-at-once`.
    static let allAtOnce = Self(lessonAccess: "all-at-once")
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("one-at-a-time") {
    EnrollmentSelectAccessScreen(state: .oneAtATime)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("all-at-once") {
    EnrollmentSelectAccessScreen(state: .allAtOnce)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
