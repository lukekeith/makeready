//
//  InviteMemberScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen invite-member in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/invites/send
//  (the invitee's `recipientName` is an API-GAP in §5, OQ-invite-member-003).
//  Hosted by iphone/MakeReady/UI2/Containers/Groups/InviteMemberContainer.swift (invite-member).
//

import SwiftUI

/// Invite member — a pushed page hosting a three-step flow: the invitee's name, their cell
/// number on the on-screen keypad, then the sent confirmation (§2). Every step shares the C-040
/// header; only the content column changes. Composed only of §4's C-040, C-046 (→ C-045),
/// C-048, C-107 (→ C-108) and C-109. Standalone: the screen is not minted from a collection
/// (`identifiedFrom` is null), so no D7 template applies.
struct InviteMemberScreen: View {

    /// §3's three steps — the page changes step in place.
    enum Step: String {
        case name
        case phone
        case sent
    }

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// The step on show: `name` (§3 `name-empty` / `name-ready`), `phone` (`phone-empty` …
        /// `send-failed`) or `sent`. An unknown word renders `name`.
        var step: String
        /// The invitee's full name as typed (step 1; shown again on step 3).
        var inviteeName: String
        /// The national number's digits, 0–10 (US/NANP, "+1" fixed). Formatted by the screen.
        var digits: String
        /// §3 `sending`: the send request is in flight.
        var sending: Bool
    }

    let state: State
    /// invite-member D4/D7 (owner 2026-10-26): false hides View invite on the sent step, leaving
    /// Done alone — until invite-home is wired. Default true keeps the designed page.
    var showsViewInvite: Bool = true
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                              // step 1 back / edge-swipe → caller
    var onCancel: () -> Void = {}                            // Cancel (steps 1–2) → pop the flow
    var onSendInvite: (String, String) -> Void = { _, _ in } // (name, E.164) → POST /api/invites/send
    var onDone: () -> Void = {}                              // Done, and step 3 back → caller
    var onViewInvite: () -> Void = {}                        // View invite → replace with invite-home

    // §3 UI-only rules — real local state, seeded from `State`: the step (Continue → step 2,
    // step-2 back → step 1 with the name kept), the typed name and the keypad's digits.
    @SwiftUI.State private var step: Step
    @SwiftUI.State private var name: String
    @SwiftUI.State private var digits: String

    init(
        state: State,
        showsViewInvite: Bool = true,
        onBack: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {},
        onSendInvite: @escaping (String, String) -> Void = { _, _ in },
        onDone: @escaping () -> Void = {},
        onViewInvite: @escaping () -> Void = {}
    ) {
        self.state = state
        self.showsViewInvite = showsViewInvite
        self.onBack = onBack
        self.onCancel = onCancel
        self.onSendInvite = onSendInvite
        self.onDone = onDone
        self.onViewInvite = onViewInvite
        _step = SwiftUI.State(initialValue: Step(rawValue: state.step) ?? .name)
        _name = SwiftUI.State(initialValue: state.inviteeName)
        _digits = SwiftUI.State(initialValue: String(state.digits.filter(\.isNumber).prefix(Self.numberLength)))
    }

    // MARK: - §2 constants

    private static let title = "Invite member"
    private static let nameLabel = "Who are you inviting?"
    private static let namePlaceholder = "Full name"
    private static let phoneLabel = "What is their cell number?"
    private static let phonePlaceholder = "Phone number"
    private static let continueLabel = "Continue"
    private static let sendLabel = "Send invite"
    private static let cancelLabel = "Cancel"
    private static let doneLabel = "Done"
    private static let viewInviteLabel = "View invite"
    private static let sentLead = "Invitation was sent to"
    /// §3 `phone-ready`: "+1" fixed (C-045 OQ-C-045-002 governs any other country).
    private static let countryCode = "+1"
    /// §3 `phone-ready`: exactly 10 digits; further digit taps are ignored.
    private static let numberLength = 10
    /// §3 `name-ready`: trimmed name 1–100 characters.
    private static let nameMaxLength = 100

    // FLAGGED LITERAL — invite-member §2 FL-2: 16 (button-stack and recipient-text gaps; same
    // value as `space-page-margin`, different role).
    private static let stackGap: CGFloat = 16
    // FLAGGED LITERAL — invite-member §2 FL-1: 64 (confirmation block gap).
    private static let confirmationGap: CGFloat = 64
    // GAP — invite-member §2 step 2.2: "NumberKeypad … centred in the 408 column (x60), 320×398"
    // — no size token for the keypad's width; its height is its own.
    private static let keypadWidth: CGFloat = 320
    // GAP — invite-member §2 step 3.1: "ConfirmationMark — 100×100 disc" — C-109's diameter is
    // set by the call site; no size token.
    private static let markSize: CGFloat = 100

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root. The status bar (§1 deviation 1) is the harness's.
        VStack(spacing: 0) {
            // §2 chrome 2: C-040 `twoIcons`, `showIcons: false` — back + centred title.
            PageHeader(
                style: .twoIcons,
                title: Self.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: back
            )
            .ui2Element("C-040 PageHeader")

            // §2 chrome 3: content column — padding `space-page-margin`, gap `space-section-gap`.
            VStack(spacing: Token.Space.sectionGap) {
                switch step {
                case .name: nameStep
                case .phone: phoneStep
                case .sent: sentStep
                }
            }
            .padding(Token.Space.pageMargin)
        }
        // §2 step 1.3: empty background below; the column stays top-anchored.
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)
        // invite-member D7 (owner 2026-10-26): a host moves the page to a later step (`sent` after
        // an async send) by changing `state.step`; the name and digits the leader entered stay.
        .onChange(of: state.step) { _, newStep in
            if let adopted = Step(rawValue: newStep) { step = adopted }
        }
    }

    // MARK: - Step 1 — name

    @ViewBuilder
    private var nameStep: some View {
        // §2 step 1.1: C-046 Centered, `field: Text`, `Focus` while editing.
        FieldGroup(
            label: Self.nameLabel,
            field: .text,
            style: .focus,
            layout: .centered,
            text: name,
            placeholder: Self.namePlaceholder
        )
        .ui2Element("C-046 FieldGroup")

        // §2 step 1.2: Continue (`affirmative`) then Cancel (`secondary`, D57).
        buttons(
            primary: Self.continueLabel,
            primaryEnabled: continueEnabled,
            primaryAction: { step = .phone },
            secondary: Self.cancelLabel,
            secondaryEnabled: true,
            secondaryAction: onCancel
        )
    }

    // MARK: - Step 2 — cell number

    @ViewBuilder
    private var phoneStep: some View {
        // §2 step 2.1: C-046 Centered, `field: Phone` (D58), `Focus` — read-only while sending.
        FieldGroup(
            label: Self.phoneLabel,
            field: .phone,
            style: state.sending ? .default : .focus,
            layout: .centered,
            text: Self.formatted(digits),
            placeholder: Self.phonePlaceholder
        )
        .ui2Element("C-046 FieldGroup")

        // §2 step 2.2 / §4: C-107 — `delete-disabled` with no digits, `disabled` while sending.
        NumberKeypad(
            enabled: !state.sending,
            deleteEnabled: !digits.isEmpty,
            onDigit: appendDigit,
            onDelete: { digits = String(digits.dropLast()) },
            onClear: { digits = "" }
        )
        .frame(width: Self.keypadWidth)
        .ui2Element("C-107 NumberKeypad")

        // §2 step 2.3: Send invite (`affirmative`) then Cancel (`secondary`).
        buttons(
            primary: Self.sendLabel,
            primaryEnabled: sendEnabled,
            primaryAction: { onSendInvite(trimmedName, Self.countryCode + digits) },
            secondary: Self.cancelLabel,
            secondaryEnabled: !state.sending,
            secondaryAction: onCancel
        )
    }

    // MARK: - Step 3 — sent

    @ViewBuilder
    private var sentStep: some View {
        // §2 step 3.1: the result block — padding 32 (`space-section-gap` value), centred, gap FL-1.
        VStack(spacing: Self.confirmationGap) {
            // §4 C-109: "the success disc + check" — settled. invite-member names no appear
            // animation, and an animated mark snapshots at its 0-opacity start.
            ConfirmationMark(tone: .success, animated: false)
                .frame(width: Self.markSize)
                .ui2Element("C-109 ConfirmationMark")

            // §2 step 3.1: recipient text — screen-owned, no registry row; each line single-line,
            // tail-truncated.
            VStack(spacing: 0) {
                line(Self.sentLead, style: Token.TypeStyle.bodySm, color: Token.textSecondary)
                    .padding(.bottom, Self.stackGap)
                line(trimmedName, style: Token.TypeStyle.valueHero, color: Token.textPrimary)
                    .padding(.bottom, Token.Space.elementGap)
                line(Self.countryCode + " " + Self.formatted(digits),
                     style: Token.TypeStyle.valueHero, color: Token.textNavigation)
            }
        }
        .padding(Token.Space.sectionGap)
        .frame(maxWidth: .infinity)

        // §2 step 3.2: Done (`affirmative`) then View invite (`secondary`); D4/D7: Done alone
        // while `showsViewInvite` is false.
        if showsViewInvite {
            buttons(
                primary: Self.doneLabel,
                primaryEnabled: true,
                primaryAction: onDone,
                secondary: Self.viewInviteLabel,
                secondaryEnabled: true,
                secondaryAction: onViewInvite
            )
        } else {
            PageActionButton(label: Self.doneLabel, role: .affirmative, enabled: true, onTap: onDone)
                .ui2Element("C-048 PageActionButton")
        }
    }

    // MARK: - Parts

    /// §2: the two C-048 buttons, vertical, gap FL-2, each the column's full width.
    private func buttons(
        primary: String,
        primaryEnabled: Bool,
        primaryAction: @escaping () -> Void,
        secondary: String,
        secondaryEnabled: Bool,
        secondaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Self.stackGap) {
            PageActionButton(label: primary, role: .affirmative, enabled: primaryEnabled, onTap: primaryAction)
                .ui2Element("C-048 PageActionButton")
            PageActionButton(label: secondary, role: .secondary, enabled: secondaryEnabled, onTap: secondaryAction)
                .ui2Element("C-048 PageActionButton 2")
        }
    }

    /// One recipient-text line in its token's line box, centred, single line, tail ellipsis.
    private func line(_ text: String, style: DesignTextStyle, color: Color) -> some View {
        Text(text)
            .designTextStyle(style)
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity,
                   minHeight: style.lineHeight ?? style.size,
                   maxHeight: style.lineHeight ?? style.size)
    }

    // MARK: - §3 rules

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    // §3 `name-empty` disables Continue; `name-ready` (trimmed 1–100) enables it.
    private var continueEnabled: Bool { !trimmedName.isEmpty && trimmedName.count <= Self.nameMaxLength }

    // §3: Send invite enabled only at exactly 10 digits and not while `sending`; `send-failed`
    // keeps the number and re-enables it as the retry.
    private var sendEnabled: Bool { digits.count == Self.numberLength && !state.sending }

    // §3: digit tap appends until 10; further taps are ignored.
    private func appendDigit(_ digit: Int) {
        guard digits.count < Self.numberLength else { return }
        digits.append(String(digit))
    }

    // §3 header back: step 1 → caller; step 2 → step 1 with the name kept; step 3 → as Done.
    private func back() {
        switch step {
        case .name: onBack()
        case .phone: step = .name
        case .sent: onDone()
        }
    }

    /// §3 `phone-partial`: "formatted as typed (`(214) 862-3`)" — NANP `(XXX) XXX-XXXX`.
    static func formatted(_ digits: String) -> String {
        let d = Array(digits)
        guard !d.isEmpty else { return "" }
        var out = "(" + String(d.prefix(3))
        if d.count > 3 { out += ") " + String(d[3..<min(d.count, 6)]) }
        if d.count > 6 { out += "-" + String(d[6...]) }
        return out
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case). "Tony Stark" and "+1 (214) 862-3611" are the frames' fixture data (§1 dev. 7).

extension InviteMemberScreen.State {
    /// §3 `name-empty` — step 1, initial; name blank.
    static let nameEmpty = Self(step: "name", inviteeName: "", digits: "", sending: false)
    /// §3 `name-ready` — a typed name; Continue enabled.
    static let nameReady = Self(step: "name", inviteeName: "Tony Stark", digits: "", sending: false)
    /// §3 `phone-empty` — no digits; placeholder after "+1"; Send invite and delete disabled.
    static let phoneEmpty = Self(step: "phone", inviteeName: "Tony Stark", digits: "", sending: false)
    /// §3 `phone-partial` — §3's own sample `(214) 862-3`.
    static let phonePartial = Self(step: "phone", inviteeName: "Tony Stark", digits: "2148623", sending: false)
    /// §3 `phone-ready` — exactly 10 digits; Send invite enabled.
    static let phoneReady = Self(step: "phone", inviteeName: "Tony Stark", digits: "2148623611", sending: false)
    /// §3 `sending` — the request in flight: buttons and keypad disabled.
    static let sendInFlight = Self(step: "phone", inviteeName: "Tony Stark", digits: "2148623611", sending: true)
    /// §3 `send-failed` — the number kept, Send invite re-enabled as the retry. The error copy is
    /// the app shell's error surface (§6), not this screen's.
    static let sendFailed = Self(step: "phone", inviteeName: "Tony Stark", digits: "2148623611", sending: false)
    /// §3 `sent` — the confirmation, from what the leader entered.
    static let sent = Self(step: "sent", inviteeName: "Tony Stark", digits: "2148623611", sending: false)
}

#Preview("name-empty") {
    InviteMemberScreen(state: .nameEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("name-ready") {
    InviteMemberScreen(state: .nameReady)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("phone-empty") {
    InviteMemberScreen(state: .phoneEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("phone-partial") {
    InviteMemberScreen(state: .phonePartial)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("phone-ready") {
    InviteMemberScreen(state: .phoneReady)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("sending") {
    InviteMemberScreen(state: .sendInFlight)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("send-failed") {
    InviteMemberScreen(state: .sendFailed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("sent") {
    InviteMemberScreen(state: .sent)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
