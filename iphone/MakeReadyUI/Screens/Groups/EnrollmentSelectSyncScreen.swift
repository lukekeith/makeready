//
//  EnrollmentSelectSyncScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollment-select-sync in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/enrollments (run by the checklist's
//  Enroll, `groups-enroll-program`, never from here; this screen writes the draft's `syncMode`
//  only).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select sync — the "Sync settings" step of the enrollment checklist (`groups-enroll-program`,
/// §3): a single-select picker between Stay in sync (`AUTO`) and Private (`OFF`). Only Save
/// commits. C-040 header over two C-047 rows (§2). Composed only of §4's C-040 and C-047.
///
/// §3 names three states — `unset` (no row selected, Save disabled), `stay-in-sync` (row 1
/// selected) and `private` (row 2 selected). There is no loading, empty or error state: Save is
/// enabled exactly when a row is selected (§3).
struct EnrollmentSelectSyncScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The checklist draft's `syncMode` (§5): "AUTO", "OFF", or "" when unset. Any value
        /// outside {AUTO, OFF} opens on unset (§3 opening value).
        var syncMode: String
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                                  // §3 Back: discard + pop
    var onSave: (_ syncMode: String) -> Void = { _ in }          // §3 Save: commit + pop

    // R-31 ephemeral UI — §3: "Tap a row selects it and deselects the other … the selection
    // model is the screen's"; Back discards it, so it lives here until Save.
    @SwiftUI.State private var selection: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSave: @escaping (_ syncMode: String) -> Void = { _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        // §3 opening value: the saved value when it is AUTO or OFF, else unset ("") — the
        // recommended option is not preselected (owner ruling 2026-10-30).
        _selection = SwiftUI.State(
            initialValue: [Self.auto, Self.off].contains(state.syncMode) ? state.syncMode : ""
        )
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §1 deviation 1: the title is "Select sync" (the frame's "Select invite time" is a slip).
    private static let pageTitle = "Select sync"
    /// §1 deviation 3: the trailing text action reads "Save".
    private static let saveLabel = "Save"
    /// §3: Stay in sync → `AUTO`, Private → `OFF`.
    private static let auto = "AUTO"
    private static let off = "OFF"
    /// §2 L3, verbatim.
    private static let syncTitle = "Stay in sync"
    private static let syncDescription = "Content in the enrollment will be automatically updated with any new "
        + "changes made to the master program by the creator or editor of that program."
    private static let privateTitle = "Private"
    private static let privateDescription = "You can edit lesson content at any time, but changes made to the "
        + "master program will not be synced to the enrollment."

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
    /// enabled exactly when a row is selected; disabled in §3 `unset`.
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.pageTitle,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: Self.saveLabel,
            trailingEnabled: !selection.isEmpty,
            onLeading: onBack,
            onDone: { if !selection.isEmpty { onSave(selection) } }
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2 L3: two C-047 rows, no gap between them (each carries its own 16 vertical padding).
    private var options: some View {
        VStack(spacing: 0) {
            RadioOptionRow(
                title: Self.syncTitle,
                description: Self.syncDescription,
                selected: selection == Self.auto,
                recommended: true,                                   // D61: the ★
                onSelect: { selection = Self.auto }
            )
            .ui2Element("C-047 RadioOptionRow")
            RadioOptionRow(
                title: Self.privateTitle,
                description: Self.privateDescription,
                selected: selection == Self.off,
                onSelect: { selection = Self.off }
            )
            .ui2Element("C-047 RadioOptionRow 2")
        }
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension EnrollmentSelectSyncScreen.State {
    /// §3 `unset` — the draft holds no `syncMode`.
    static let unset = Self(syncMode: "")
    /// §3 `stay-in-sync` (frame `stay-in-sync`) — the draft holds `AUTO`.
    static let stayInSync = Self(syncMode: "AUTO")
    /// §3 `private` — the draft holds `OFF`.
    static let `private` = Self(syncMode: "OFF")
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("unset") {
    EnrollmentSelectSyncScreen(state: .unset)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("stay-in-sync") {
    EnrollmentSelectSyncScreen(state: .stayInSync)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("private") {
    EnrollmentSelectSyncScreen(state: .private)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
