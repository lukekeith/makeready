//
//  RequestDetailScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen request-detail in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups/{groupId}/join-requests ·
//  GET /api/groups/{id} · POST /api/groups/{groupId}/join-requests/{requestId}/approve ·
//  POST /api/groups/{groupId}/join-requests/{requestId}/reject
//  (the single-request GET and the request/invite event history are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Join request — the leader opens one group join request to see who asked (phone), when, which
/// group and the history that led to it, and approves or rejects it (§3 purpose). A pushed page:
/// C-040 header, then the requester hero, the request meta, Group requested, the Request
/// timeline and the Approve / Reject actions, separated by C-088 hairlines (§2). Composed only of
/// §4's C-040, C-022, C-088, C-020, C-037, C-065 and C-048; C-038 and C-043 render only inside
/// C-037 (its photo and its `chips` prop).
///
/// §3's closed states — `pending`, `approved`, `rejected`, `loading`, `timeline-empty`,
/// `responding`, `error` — are all reachable through `State` alone.
struct RequestDetailScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per timeline event, because the preview's props are JSON and the §4 views take flat
    /// parameters (R-05).
    struct State {
        // ── Requester hero (§2.1) ──
        /// The requester's phone number.
        var phone: String
        // ── Request meta (§2.2) ──
        /// "Request date" value, `Mon D, YYYY`.
        var requestDate: String
        /// "Request time" value, `h:mma` lowercase ("3:15pm").
        var requestTime: String
        // ── Group requested (§2.4) ──
        var groupName: String
        /// C-038's photo inside C-037; "" = no photo → C-038's fallback.
        var groupPhotoURL: String
        /// `GroupJoinRequest.status`: "pending" | "approved" | "rejected" (§3).
        var status: String
        /// The status chip's date — `createdAt` while pending, `reviewedAt` once reviewed (§3).
        var statusDate: String
        // ── Request timeline (§2.6) — C-065, one entry per event, newest first ──
        /// §3 `loading`: true until the timeline's data lands (the rest renders at once).
        var loading: Bool
        var eventDates: [String]
        var eventTexts: [String]
        /// "" = no highlight.
        var eventHighlights: [String]
        // ── Respond actions (§2.7) ──
        /// §3 `responding`: Approve or Reject was tapped and the server has not answered.
        var responding: Bool
    }

    let state: State
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}       // C-040 back → pop to the pusher
    var onOpenGroup: () -> Void = {}  // C-037 group row → push groups-detail (OQ-004)
    // OQ-request-detail-006 (owner): "Each one will produce a confirmation dialog before
    // performing the action" — the dialog is the caller's, presented when these fire; the
    // screen only emits the tap (§3 still reads "no confirmation step" — see the report).
    var onApprove: () -> Void = {}    // C-048 affirmative → POST …/approve, pop on success
    var onReject: () -> Void = {}     // C-048 destructive → POST …/reject, pop on success

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onOpenGroup: @escaping () -> Void = {},
        onApprove: @escaping () -> Void = {},
        onReject: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onOpenGroup = onOpenGroup
        self.onApprove = onApprove
        self.onReject = onReject
    }

    // §3 has no UI-only rule on this screen: `responding` is a §3 state (a `State` field), every
    // interaction leaves the screen and the timeline is display-only. So no `@SwiftUI.State`.

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: C-040's centred title.
    private static let pageTitle = "Join request"
    /// §2.1: the hero's lead-in.
    private static let heroLabel = "Request from"
    /// §2.2: the two pair labels.
    private static let requestDateLabel = "Request date"
    private static let requestTimeLabel = "Request time"
    /// §2.4 / §2.6: the section titles.
    private static let groupRequestedTitle = "Group requested"
    private static let timelineTitle = "Request timeline"
    /// §3 `timeline-empty` (proposed default, OQ-groups-detail-006's section-empty rule).
    private static let timelineEmptyText = "No history yet"
    /// §2.7: the two action labels.
    private static let approveLabel = "Approve"
    private static let rejectLabel = "Reject"
    /// §3 (OQ-003 owner): the chip's status word per `GroupJoinRequest.status`.
    private static let pendingWord = "Requested"
    private static let approvedWord = "Approved"
    private static let rejectedWord = "Rejected"

    // MARK: - §2 geometry the screen owns

    // GAP — request-detail §2.2: "two C-022 MetaPair in one row, 16 gutter" — no spacing token
    // names a 16 gutter between pairs.
    private static let metaGutter: CGFloat = 16
    // GAP — request-detail §2.6: "a 1px vertical connector (x = 10 inside a 20-wide gutter, from
    // 16 below the block top to 6 above its bottom)" — no token for any of the four.
    private static let connectorWidth: CGFloat = 1
    private static let connectorX: CGFloat = 10
    private static let connectorTopInset: CGFloat = 16
    private static let connectorBottomInset: CGFloat = 6
    // note 2026-10-18T07:10:36.203Z — "Approve / Reject stack gap is 16 (the 16 spacing token),
    // not 8 / `space-element-gap`" (request-detail §2.7). GAP — no spacing token names a 16
    // button-stack gap; the 16-valued rows (space-page-margin, space-card-padding) are other roles.
    private static let actionStackGap: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "C-040 PageHeader (`Two icons`, `showIcons=false`; back + centred title
            // "Join request")".
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

            // §2: "vertical scroll content, padding `space-page-margin` (16), column gap
            // `space-section-gap` (32)".
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                requesterHero
                requestMeta
                SectionDivider()
                    .ui2Element("C-088 SectionDivider")
                groupRequested
                SectionDivider()
                    .ui2Element("C-088 SectionDivider 2")
                timeline
                if isPending {
                    respondActions
                }
            }
            .padding(Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                          // §2: page background
    }

    // MARK: §2.1 Requester hero

    /// §2.1: ""Request from" (`type-body` 14/14, `color-text-secondary`, single-line ellipsis)
    /// over the requester's phone number (`type-value-hero` SF Pro Regular 24/32,
    /// `color-text-primary`, single-line ellipsis), `space-element-gap` (8)."
    private var requesterHero: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(Self.heroLabel)
                .designTextStyle(Token.TypeStyle.body)
                .foregroundStyle(Token.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
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

    // MARK: §2.2 Request meta

    /// §2.2: "two C-022 MetaPair in one row, 16 gutter, each 196×36".
    private var requestMeta: some View {
        HStack(alignment: .top, spacing: Self.metaGutter) {
            MetaPair(value: state.requestDate, label: Self.requestDateLabel, layout: .stacked, align: .left)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("C-022 MetaPair")
            MetaPair(value: state.requestTime, label: Self.requestTimeLabel, layout: .stacked, align: .left)
                .frame(maxWidth: .infinity, alignment: .leading)
                .ui2Element("C-022 MetaPair 2")
        }
    }

    // MARK: §2.4 Group requested

    /// §2.4: "C-020 SectionHeader "Group requested" (accessory `none`) → 32 → one C-037
    /// ListResultRow: `subject: group`, `detail: chips`, `trailing: chevron`" with one C-043
    /// (`Key value`, `align=Right`) carrying the status word + date (§3).
    private var groupRequested: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.groupRequestedTitle)
                .ui2Element("C-020 SectionHeader")
            ListResultRow(
                subject: .group,
                title: state.groupName,
                detail: .chips,
                chips: [
                    .init(
                        value: state.statusDate,
                        label: statusWord,
                        // §3: `Complete` once approved; `Default` while pending and once rejected.
                        state: state.status == "approved" ? .complete : .default,
                        labelPosition: .leading
                    )
                ],
                trailing: .chevron,
                imageURL: Self.optionalText(state.groupPhotoURL).flatMap(URL.init(string:)),
                onTap: onOpenGroup
            )
            .ui2Element("C-037 ListResultRow")
        }
    }

    // MARK: §2.6 Request timeline

    /// §2.6: "C-020 SectionHeader "Request timeline" (accessory `none`) → 32 → timeline block: a
    /// 1px vertical connector … behind stacked C-065 TimelineEventRow (tone `neutral`). Newest
    /// event first." §3 `loading`: the block renders once its data lands; `timeline-empty`: one
    /// `type-body-sm` `color-text-secondary` line.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.timelineTitle)
                .ui2Element("C-020 SectionHeader 2")
            if state.loading {
                // §3 `loading`: "the timeline renders once its data lands. The page never
                // blanks." — the header stays, the block is not drawn yet.
                EmptyView()
            } else if state.eventTexts.isEmpty {
                Text(Self.timelineEmptyText)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.eventTexts.indices, id: \.self) { index in
                        TimelineEventRow(
                            dateLabel: state.eventDates[safe: index] ?? "",
                            text: state.eventTexts[index],
                            highlight: Self.optionalText(state.eventHighlights[safe: index]),
                            tone: .neutral                            // §3: every row neutral
                        )
                        .ui2Element(Self.partName("C-065 TimelineEventRow", ordinal: index + 1))
                    }
                }
                .background(alignment: .topLeading) { connector }
            }
        }
    }

    /// §2.6: the connector — the screen's layout, not C-065's. `4634:41236`/`4634:41237`,
    /// `color-layout-border`.
    private var connector: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(width: Self.connectorWidth)
            .padding(.top, Self.connectorTopInset)
            .padding(.bottom, Self.connectorBottomInset)
            .offset(x: Self.connectorX - Self.connectorWidth / 2)
            .accessibilityHidden(true)
    }

    // MARK: §2.7 Respond actions

    /// §2.7 (owner ruling OQ-001; undesigned geometry): "C-048 PageActionButton "Approve"
    /// (`role=affirmative`) over C-048 "Reject" (`role=destructive`), each full content width at
    /// the contract's 38pt height, stacked with a 16 gap between them" (owner ruling, note
    /// 2026-10-18T07:10:36.203Z — supersedes OQ-006's 8). §3 `responding`: both render
    /// `isEnabled=false`.
    private var respondActions: some View {
        VStack(spacing: Self.actionStackGap) {
            PageActionButton(
                label: Self.approveLabel,
                role: .affirmative,
                enabled: !state.responding,
                onTap: onApprove
            )
            .frame(maxWidth: .infinity)
            .ui2Element("C-048 PageActionButton")
            PageActionButton(
                label: Self.rejectLabel,
                role: .destructive,
                enabled: !state.responding,
                onTap: onReject
            )
            .frame(maxWidth: .infinity)
            .ui2Element("C-048 PageActionButton 2")
        }
    }

    // MARK: - Derived

    /// §3 / OQ-006 (a) proposed default: the actions render only while the request is pending.
    private var isPending: Bool { state.status == "pending" }

    /// §3 (OQ-003 owner): "Requested «date»" / "Approved «date»" / "Rejected «date»".
    private var statusWord: String {
        switch state.status {
        case "approved": return Self.approvedWord
        case "rejected": return Self.rejectedWord
        default: return Self.pendingWord
        }
    }

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

extension RequestDetailScreen.State {

    /// §3 `pending` — every value is the text on the frozen frame `default` (node 4634:41206;
    /// §1 deviation 1: sample content), except the chip word, which OQ-003 governs (§1 deviation
    /// 4). The group photo is a stand-in URL (C-037's picsum seed, as on invite-home).
    static let pending = Self(
        phone: "(135) 920-9123",
        requestDate: "Jun 25, 2026",
        requestTime: "3:15pm",
        groupName: "Young professionals",
        groupPhotoURL: "https://picsum.photos/seed/c037-group/256",
        status: "pending",
        statusDate: "Jun 25, 2026",
        loading: false,
        eventDates: ["July 26", "Jun 25"],
        eventTexts: [
            "User clicked invitation link",
            "Invitation sent to (214) 862-3686 for Young Professionals"
        ],
        eventHighlights: ["", ""],
        responding: false
    )

    /// §3 `approved` — chip C-043 `Complete` "Approved «date»"; no actions.
    static let approved: Self = {
        var s = pending
        s.status = "approved"
        return s
    }()

    /// §3 `rejected` — chip C-043 `Default` "Rejected «date»"; no actions.
    static let rejected: Self = {
        var s = pending
        s.status = "rejected"
        return s
    }()

    /// §3 `loading` — hero, meta, group row and actions at once; the timeline not yet.
    static let loading: Self = {
        var s = pending
        s.loading = true
        return s
    }()

    /// §3 `timeline-empty` — the section header kept, "No history yet".
    static let timelineEmpty: Self = {
        var s = pending
        s.eventDates = []
        s.eventTexts = []
        s.eventHighlights = []
        return s
    }()

    /// §3 `responding` — both C-048 `isEnabled=false`.
    static let responding: Self = {
        var s = pending
        s.responding = true
        return s
    }()

    /// §3 `error` — "keeps the cached render … re-enables both buttons and shows no designed
    /// banner" (OQ-006 proposed default): the `pending` render.
    static let error = pending
}

#Preview("pending") {
    RequestDetailScreen(state: .pending)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("approved") {
    RequestDetailScreen(state: .approved)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("rejected") {
    RequestDetailScreen(state: .rejected)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    RequestDetailScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("timeline-empty") {
    RequestDetailScreen(state: .timelineEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("responding") {
    RequestDetailScreen(state: .responding)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    RequestDetailScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
