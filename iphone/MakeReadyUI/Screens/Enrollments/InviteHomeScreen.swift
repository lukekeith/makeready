//
//  InviteHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen invite-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/invites/{token} ·
//  GET /api/members/{memberId}/profile
//  (the leader-facing by-recipient invite detail and the invite event history are API-GAPs
//  in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Invite detail — the page that comes up when the leader taps an invite, so they can monitor
/// its status (§3 purpose, owner, OQ-invite-home-1). A pushed page: C-040 header, then the
/// recipient hero, the identity block, Group invitations and the Invitation timeline,
/// separated by hairlines (§2). Composed only of §4's C-020, C-022, C-037, C-038, C-040 and
/// C-065; C-043 renders only inside C-037 (its `chips` prop).
///
/// §3 names four states — `unlinked`, `linked`, `loading`, `error`. This build renders
/// `unlinked` and `linked`; `loading` (section skeletons) and `error` (a section-level inline
/// retry) name no §4 component and no geometry, so they are reported as spec defects and not
/// improvised here (the members-profile precedent).
struct InviteHomeScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per group invitation / timeline event, because the preview's props are JSON
    /// and the §4 views take flat parameters (R-05).
    struct State {
        // ── Recipient hero (§2.1) ──
        /// The recipient's phone number.
        var phone: String
        // ── Identity block (§2.2) ──
        /// §3: `linked` (true) renders the member block + member meta; `unlinked` (false) the
        /// invite meta pairs. Not `linked`: the fixture already decodes a `linked` of another type.
        var memberLinked: Bool
        /// `unlinked`: "Invitation sent" value (`Mon D, YYYY`).
        var sentDate: String
        /// `unlinked`: "Invited by" value (the leader's name).
        var invitedBy: String
        /// `linked`: the "Existing member" value.
        var memberName: String
        /// `linked`: C-038's photo; "" = no photo → C-038's initials fallback.
        var avatarURL: String
        var initials: String
        /// `linked`: the 2×2 grid. Age is computed by the caller.
        var age: Int
        var role: String
        var birthday: String
        var joined: String
        // ── Group invitations (§2.4) — C-037, one entry per group invitation ──
        var groupTitles: [String]
        /// "" = no photo → C-038's fallback inside C-037.
        var groupPhotoURLs: [String]
        /// The lifecycle word: "Sent" | "Accepted" (designed); any other word renders as a
        /// Default chip (OQ-5 proposed default).
        var groupStatuses: [String]
        /// `Mon D, YYYY` — the status chip's value.
        var groupStatusDates: [String]
        // ── Invitation timeline (§2.6) — C-065, one entry per event ──
        var eventDates: [String]
        var eventTexts: [String]
        /// "" = no highlight.
        var eventHighlights: [String]
        /// C-065 `tone`: "neutral" | "positive".
        var eventTones: [String]
    }

    let state: State
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}                         // C-040 back — pops to the presenter
    var onOpenGroupInvitation: (Int) -> Void = { _ in } // Sent row (chevron) → deferred (OQ-2)
    var onOpenMember: () -> Void = {}                   // linked-member block → members-profile (OQ-6)

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onOpenGroupInvitation: @escaping (Int) -> Void = { _ in },
        onOpenMember: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onOpenGroupInvitation = onOpenGroupInvitation
        self.onOpenMember = onOpenMember
    }

    // §3 has no UI-only rule on this screen: every interaction leaves it and the timeline is
    // display-only. So there is no `@SwiftUI.State` here.

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: C-040's centred title.
    private static let pageTitle = "Invite"
    /// §2.1: the hero's lead-in.
    private static let heroLabel = "Invitation sent to"
    /// §2.2 `unlinked`: the two pair labels.
    private static let sentLabel = "Invitation sent"
    private static let invitedByLabel = "Invited by"
    /// §2.2 `linked`: the member row label and the grid labels, in grid order.
    private static let existingMemberLabel = "Existing member"
    private static let ageLabel = "Age"
    private static let roleLabel = "Role"
    private static let birthdayLabel = "Birthday"
    private static let joinedLabel = "Joined"
    /// §2.4 / §2.6: the section titles.
    private static let groupInvitationsTitle = "Group invitations"
    private static let timelineTitle = "Invitation timeline"
    /// §2.4: the two designed lifecycle words.
    private static let sentStatus = "Sent"
    private static let acceptedStatus = "Accepted"

    // MARK: - §2 geometry the screen owns

    // GAP — invite-home §2.2: "C-038 Avatar 54" — a consumer-applied diameter (C-038 §3b), no
    // size token.
    private static let avatarSize: CGFloat = 54
    // GAP — invite-home §2.2: "2×2 C-022 grid (16 gaps)" and "C-022 ×2 in one row (16
    // gutter)" — no grid spacing token.
    private static let gridGap: CGFloat = 16
    // GAP — invite-home §2.2: "member row (16 gap: C-038 Avatar 54 + C-022 …)" — no spacing
    // token names a row gap of 16.
    private static let memberRowGap: CGFloat = 16
    // GAP — invite-home §2: "hairlines `color-layout-border` between sections" — no
    // stroke-width token. Frame `linked`: the 1pt stroke is centred on a zero-height line
    // (rows 410.5–411.5 in the 4× frame), so content → 32 → line → 32 → header, 64 in all.
    private static let hairline: CGFloat = 1
    // GAP — invite-home §2.6: "a 1px vertical connector line (x = 10 inside a 20-wide gutter,
    // inset 16 top / 28 bottom from the block)" — no token for any of the four.
    private static let connectorWidth: CGFloat = 1
    private static let connectorX: CGFloat = 10
    private static let connectorTopInset: CGFloat = 16
    private static let connectorBottomInset: CGFloat = 28

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "C-040 PageHeader (`Two icons` + `showIcons=false`, back + centered title
            // "Invite")".
            PageHeader(
                style: .twoIcons,
                title: Self.pageTitle,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2: "vertical scroll content (p16, column gap `space-section-gap` 32)".
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                recipientHero
                identityBlock
                sectionDivider
                groupInvitations
                sectionDivider
                timeline
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                          // §2: page background
    }

    /// §2: hairline (`color-layout-border`) — a zero-height item in the 32-gap column whose
    /// 1pt stroke is centred on it (see `hairline`).
    private var sectionDivider: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 0)
            .overlay {
                Rectangle()
                    .fill(Token.layoutBorder)
                    .frame(height: Self.hairline)
            }
            .accessibilityHidden(true)
    }

    // MARK: §2.1 Recipient hero

    /// §2.1: ""Invitation sent to" (`type-body` Regular 14/14, `color-text-secondary`) over the
    /// phone number (`type-value-hero` SF Pro Regular 24/32 `color-text-primary`, single-line
    /// ellipsis), 8 gap."
    private var recipientHero: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(Self.heroLabel)
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .frame(height: Self.lineBox(Token.TypeStyle.body), alignment: .leading)
            Text(state.phone)
                .designTextStyle(Token.TypeStyle.valueHero)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: Self.lineBox(Token.TypeStyle.valueHero), alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: §2.2 Identity block

    @ViewBuilder private var identityBlock: some View {
        if state.memberLinked {
            linkedMember
        } else {
            // §2.2 `unlinked`: "C-022 MetaPair ×2 in one row (16 gutter)".
            HStack(alignment: .top, spacing: Self.gridGap) {
                metaCell(label: Self.sentLabel, value: state.sentDate, ordinal: 1)
                metaCell(label: Self.invitedByLabel, value: state.invitedBy, ordinal: 2)
            }
        }
    }

    /// §2.2 `linked`: "member row (16 gap: C-038 Avatar 54 + C-022 "Existing member"/member
    /// name, vertically centred) → 32 → 2×2 C-022 grid (16 gaps): Age · Role · Birthday ·
    /// Joined."
    private var linkedMember: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            // §3: "Linked-member block tap → `members-profile`" — proposed default (OQ-6); the
            // frame designs no affordance, so the row is a plain button with no chrome.
            SwiftUI.Button(action: onOpenMember) {
                HStack(alignment: .center, spacing: Self.memberRowGap) {
                    Avatar(
                        imageURL: Self.optionalText(state.avatarURL).flatMap(URL.init(string:)),
                        initials: Self.optionalText(state.initials),
                        size: Self.avatarSize
                    )
                    .ui2Element("C-038 Avatar")
                    metaCell(label: Self.existingMemberLabel, value: state.memberName, ordinal: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(Self.existingMemberLabel), \(state.memberName)")
            .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: Self.gridGap) {
                HStack(alignment: .top, spacing: Self.gridGap) {
                    metaCell(label: Self.ageLabel, value: "\(state.age)", ordinal: 2)
                    metaCell(label: Self.roleLabel, value: state.role, ordinal: 3)
                }
                HStack(alignment: .top, spacing: Self.gridGap) {
                    metaCell(label: Self.birthdayLabel, value: state.birthday, ordinal: 4)
                    metaCell(label: Self.joinedLabel, value: state.joined, ordinal: 5)
                }
            }
        }
    }

    /// C-022 `layout=stacked` (label over value); `align` is inert there (C-022 §4).
    private func metaCell(label: String, value: String, ordinal: Int) -> some View {
        MetaPair(value: value, label: label, layout: .stacked, align: .left)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element(Self.partName("C-022 MetaPair", ordinal: ordinal))
    }

    // MARK: §2.4 Group invitations

    /// §2.4: "C-020 SectionHeader (`type-section-title`, accessory `none`) → 32 → one C-037
    /// ListResultRow (96pt incl. py16) per group invitation".
    private var groupInvitations: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.groupInvitationsTitle)
                .ui2Element("C-020 SectionHeader")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(state.groupTitles.indices, id: \.self) { index in
                    groupRow(index)
                        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
                }
            }
        }
    }

    /// §2.4: 64pt group photo + name + the status C-043 (Key value, align Right) through the row's
    /// `chips` prop — "Sent «date»" (Default) or "Accepted «date»" (Complete); `trailing:
    /// chevron` on the Sent row only, `trailing: none` on Accepted rows (OQ-2). §3: "the
    /// Accepted row is designed without a chevron — proposed default: not tappable (OQ-2)", so
    /// only a chevron row carries `onTap`.
    private func groupRow(_ index: Int) -> some View {
        let status = state.groupStatuses[safe: index] ?? ""
        let actionable = status == Self.sentStatus
        return ListResultRow(
            subject: .group,
            title: state.groupTitles[index],
            detail: .chips,
            chips: [
                .init(
                    value: state.groupStatusDates[safe: index] ?? "",
                    label: status,
                    state: status == Self.acceptedStatus ? .complete : .default,
                    labelPosition: .leading
                )
            ],
            trailing: actionable ? .chevron : .none,
            imageURL: Self.optionalText(state.groupPhotoURLs[safe: index]).flatMap(URL.init(string:)),
            onTap: actionable ? { onOpenGroupInvitation(index) } : nil
        )
    }

    // MARK: §2.6 Invitation timeline

    /// §2.6: "C-020 (accessory `none`) → 32 → timeline block: a 1px vertical connector line …
    /// behind stacked C-065 TimelineEventRow items (py8 each)".
    private var timeline: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.timelineTitle)
                .ui2Element("C-020 SectionHeader 2")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(state.eventTexts.indices, id: \.self) { index in
                    TimelineEventRow(
                        dateLabel: state.eventDates[safe: index] ?? "",
                        text: state.eventTexts[index],
                        highlight: Self.optionalText(state.eventHighlights[safe: index]),
                        tone: state.eventTones[safe: index] == "positive" ? .positive : .neutral
                    )
                    .ui2Element(Self.partName("C-065 TimelineEventRow", ordinal: index + 1))
                }
            }
            .background(alignment: .topLeading) {
                if !state.eventTexts.isEmpty { connector }
            }
        }
    }

    /// §2.6: the connector line — the screen's layout, not C-065's (C-065 §2).
    private var connector: some View {
        Rectangle()
            // GAP — invite-home §2.6 names no colour for the connector. Both frames draw it in
            // #2f3639, the same Figma `layout/border` paint as §2's hairlines, which bind to
            // `color-layout-border` (C-088 §1 deviation 1) — so the hairlines' token.
            .fill(Token.layoutBorder)
            .frame(width: Self.connectorWidth)
            .padding(.top, Self.connectorTopInset)
            .padding(.bottom, Self.connectorBottomInset)
            .offset(x: Self.connectorX - Self.connectorWidth / 2)
            .accessibilityHidden(true)
    }

    // MARK: - Derived

    private static func optionalText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    /// The designed line box of a text style: SwiftUI has no line-height, so it is a frame.
    private static func lineBox(_ style: DesignTextStyle) -> CGFloat {
        style.lineHeight ?? style.size
    }

    /// D11: a component placed more than once gets " 2", " 3"… on the later instances.
    private static func partName(_ base: String, ordinal: Int) -> String {
        ordinal <= 1 ? base : "\(base) \(ordinal)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension InviteHomeScreen.State {

    /// §3 `unlinked` — every value is the text on the frozen frame `default` (node 3832:30788;
    /// §1 deviation 1: sample content). The group photo is a stand-in URL (C-037's picsum seed).
    static let unlinked = Self(
        phone: "(135) 920-9123",
        memberLinked: false,
        sentDate: "Jun 25, 2026",
        invitedBy: "Scott Stickane",
        memberName: "",
        avatarURL: "",
        initials: "",
        age: 0,
        role: "",
        birthday: "",
        joined: "",
        groupTitles: ["Young professionals"],
        groupPhotoURLs: ["https://picsum.photos/seed/c037-group/256"],
        groupStatuses: ["Sent"],
        groupStatusDates: ["Jun 25, 2026"],
        eventDates: ["July 26", "Jun 25"],
        eventTexts: [
            "User clicked invitation link",
            "Invitation sent to (214) 862-3686 for Young Professionals"
        ],
        eventHighlights: ["", ""],
        eventTones: ["neutral", "neutral"]
    )

    /// §3 `linked` — every value is the text on the frozen frame `linked` (node 3832:31138).
    /// The duplicated "User clicked invitation link / July 26" rows are §1 deviation 4's sample
    /// rows, kept because the frame draws them. Photos are stand-in URLs.
    static let linked = Self(
        phone: "(135) 920-9123",
        memberLinked: true,
        sentDate: "",
        invitedBy: "",
        memberName: "Tony Stark",
        avatarURL: "https://picsum.photos/seed/members-profile-avatar/328",
        initials: "TS",
        age: 52,
        role: "Member",
        birthday: "Jun 25, 1974",
        joined: "July 5, 2026",
        groupTitles: ["Young professionals", "Grandparents galore"],
        groupPhotoURLs: [
            "https://picsum.photos/seed/c037-group/256",
            "https://picsum.photos/seed/c037-group-2/256"
        ],
        groupStatuses: ["Sent", "Accepted"],
        groupStatusDates: ["Jun 25, 2026", "Jan 3, 2025"],
        eventDates: ["July 26", "July 26", "Jun 25", "Jan 3", "Jan 2"],
        eventTexts: [
            "User clicked invitation link",
            "User clicked invitation link",
            "Invitation sent to (214) 862-3686 for Young Professionals",
            "Accepted invitation to Grandparents galore",
            "Invited to join to Grandparents galore"
        ],
        eventHighlights: ["", "", "", "Accepted", ""],
        eventTones: ["neutral", "neutral", "neutral", "positive", "neutral"]
    )
}

#Preview("unlinked") {
    InviteHomeScreen(state: .unlinked)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("linked") {
    InviteHomeScreen(state: .linked)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
