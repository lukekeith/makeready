//
//  EnrollmentSelectInviteTimeScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen enrollment-select-invite-time in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/enrollments (run by the checklist's
//  Enroll, `groups-enroll-program`, never from here; this screen writes the draft's `smsTime` +
//  `timezone` only).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Select invite time — the "Set invite time" step of the enrollment checklist
/// (`groups-enroll-program`, §3): the leader picks the daily time each lesson unlocks and the text
/// message goes out. Only Select commits. C-040 header over a C-126 dial (its readout is its own)
/// and a screen-local explanation copy block (§2). Composed only of §4's C-040 and C-126.
///
/// §3 names two states — `default` (nothing saved → the dial opens at 07:00) and `set` (the dial
/// opens at the saved `smsTime`). There is no loading, empty, error or disabled state: Select is
/// always enabled (§3).
struct EnrollmentSelectInviteTimeScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The checklist draft's saved `smsTime` as "HH:mm"; "" = none saved (§3 `default`).
        var smsTime: String
    }

    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                                  // §3 Back: discard + pop
    var onSelect: (_ smsTime: String, _ timezone: String) -> Void = { _, _ in }  // §3 Select: commit + pop

    // R-31 ephemeral UI — §3: "The screen writes each `onChange` value to its screen-local pending
    // value (D43, ephemeral until Select)."
    @SwiftUI.State private var pending: String

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (_ smsTime: String, _ timezone: String) -> Void = { _, _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
        // §3 state 1: "The dial opens at `07:00`" when the checklist holds no invite time.
        _pending = SwiftUI.State(initialValue: state.smsTime.isEmpty ? Self.defaultTime : state.smsTime)
    }

    // MARK: - §2 / §3 constants (values that no §3 state changes)

    /// §2 L1: centred title "Select invite time".
    private static let pageTitle = "Select invite time"
    /// §2 L1 / §1 deviation 5: the trailing text action reads "Select".
    private static let selectLabel = "Select"
    /// §3 state 1: the unset default.
    private static let defaultTime = "07:00"
    /// §2 L3 copy, verbatim with §1 deviation 2's typo fix ("a text message").
    private static let explanation = "Enrollment content will be made available at this time every day of the "
        + "enrollment. Every member of the group will receive a text message at this time containing a link "
        + "to start the lesson."

    // MARK: - §2 geometry the screen owns

    // FLAGGED LITERAL — enrollment-select-invite-time §2: "the 32 pt header-to-dial gap", no spacing
    // token (measured from 4692:45662).
    private static let headerToDialGap: CGFloat = 32
    // FLAGGED LITERAL — enrollment-select-invite-time §2: "the 39 pt copy inset", no spacing token
    // (measured from 4692:45846).
    private static let copyInset: CGFloat = 39

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 1) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            header
            dial
                .padding(.top, Self.headerToDialGap)
            copy
                .padding(.top, Token.Space.labelValueGap)            // §2 L3: 10 pt below the readout
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                          // §2: the page background
    }

    /// §2 L1: C-040 `style: backAndLink` (D60) — back glyph, centred title, trailing "Select",
    /// always enabled (§3).
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.pageTitle,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: Self.selectLabel,
            trailingEnabled: true,
            onLeading: onBack,
            onDone: { onSelect(pending, TimeZone.current.identifier) }   // §3: device zone identifier
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2 L2: C-126, centred horizontally; the screen passes `value` and takes `onChange` (§3).
    private var dial: some View {
        TimeDialPicker(value: pending, onChange: { pending = $0 })
            .ui2Element("C-126 TimeDialPicker")
    }

    /// §2 L3: screen-local static text — `type-body-sm` in `color-text-secondary`, left-aligned,
    /// wrapping, inset 39 pt each side.
    private var copy: some View {
        Text(Self.explanation)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundColor(Token.textSecondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.copyInset)
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension EnrollmentSelectInviteTimeScreen.State {
    /// §3 `default` — no invite time saved (§5: `smsTime` nil) → the dial opens at 07:00.
    static let unset = Self(smsTime: "")
    /// §3 `set` (frame `default`, §1 deviation 4) — a saved 07:00 (§5).
    static let set = Self(smsTime: "07:00")
}

// MARK: - Previews (D21) — one per preview, in the fixture's order, inside the device canvas (D22)

#Preview("default") {
    EnrollmentSelectInviteTimeScreen(state: .unset)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("set") {
    EnrollmentSelectInviteTimeScreen(state: .set)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
