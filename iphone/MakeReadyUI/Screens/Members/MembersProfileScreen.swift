//
//  MembersProfileScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen members-profile in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/members/{memberId} ·
//  GET /api/members/{memberId}/groups · POST /api/analytics/query
//  (address, emergencyContact, emailVerified and the per-member program engagement are
//  API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Member detail — the member page that opens when any member is tapped anywhere in the app
/// (§1 owner scope). A pushed page: C-040 header, then identity, quick stats, fields, Activity,
/// Membership and Engagement, separated by hairlines (§2). Composed only of §4's C-020, C-022,
/// C-023, C-037, C-038, C-040, C-042 and C-059; C-021, C-024 and C-043 render only inside those.
///
/// §3 names four states — `loading`, `populated`, `partial`, `error`. This build renders
/// `populated` and `partial`; `loading` (skeletons) and `error` (an inline error + retry) name
/// no §4 component and no geometry, so they are reported as spec defects and not improvised
/// here (the home-dashboard precedent).
struct MembersProfileScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per day card / group row / program row, because the preview's props are JSON
    /// and the §4 views take flat parameters (R-05).
    struct State {
        // ── Identity (§2.1) ──
        /// The member's name — C-040's centred title and the identity block's name line.
        var memberName: String
        /// The email under the name, and the Email address field's value.
        var email: String
        /// C-038's photo; "" = no photo → C-038's initials fallback (§3 `partial`).
        var avatarURL: String
        var initials: String
        // ── Quick stats (§2.2) and fields (§2.4); "" = absent → an empty value line (§3) ──
        /// §5: Age is computed client-side from `birthday` — the caller passes the result.
        var age: Int
        var role: String
        var birthday: String
        var joined: String
        var organization: String
        var phone: String
        var phoneVerified: Bool
        var emailVerified: Bool
        var gender: String
        var address: String
        var emergencyContact: String
        // ── Activity (§2.5) — C-023 `kind=day · transparent`, one entry per day ──
        var dayMonths: [String]
        var dayWeekdays: [String]
        var dayNumbers: [String]
        var dayDateStates: [String]
        var daySeries: [[Double]]
        var dayLine1s: [String]
        var dayLine2s: [String]
        var dayDetailsStates: [String]
        // ── Membership (§2.6) — C-037 `group / chips / chevron`, one entry per group ──
        var groupTitles: [String]
        /// "" = no photo → C-038's fallback inside C-037.
        var groupPhotoURLs: [String]
        /// C-043 `Single` — the group leader's short name.
        var groupLeaders: [String]
        /// C-043 `Key value / Right` — "Joined <date>".
        var groupJoinedDates: [String]
        // ── Engagement (§2.7) — C-059, one entry per program ──
        var programTitles: [String]
        /// C-059 `state`: "Progress" | "Complete".
        var programStates: [String]
        var programProgress: [Double]
        var programCompleteCounts: [String]
        var programHours: [String]
        /// "" = no cover → C-059's missing-cover box.
        var programCoverURLs: [String]
    }

    let state: State
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}                     // C-040 back — pops to the presenter
    var onEditField: (String) -> Void = { _ in }    // C-042 tap → shared-edit-field (OQ-1), by label
    var onJumpToToday: () -> Void = {}              // recenters the day rail on today
    var onAddToGroup: () -> Void = {}               // Membership add → group picker (OQ-2)
    var onOpenGroup: (Int) -> Void = { _ in }       // C-037 tap → the group's screen (OQ-2)
    var onEnroll: () -> Void = {}                   // Engagement add → enroll action (OQ-2)

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onEditField: @escaping (String) -> Void = { _ in },
        onJumpToToday: @escaping () -> Void = {},
        onAddToGroup: @escaping () -> Void = {},
        onOpenGroup: @escaping (Int) -> Void = { _ in },
        onEnroll: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onEditField = onEditField
        self.onJumpToToday = onJumpToToday
        self.onAddToGroup = onAddToGroup
        self.onOpenGroup = onOpenGroup
        self.onEnroll = onEnroll
    }

    // §3 has no UI-only rule on this screen: every interaction leaves it, and the rail's free
    // scroll is scroll physics. So there is no `@SwiftUI.State` here.

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2.2: the quick-stat labels, in grid order.
    private static let ageLabel = "Age"
    private static let roleLabel = "Role"
    private static let birthdayLabel = "Birthday"
    private static let joinedLabel = "Joined"
    /// §2.4: the field labels, top → bottom.
    private static let organizationLabel = "Organization"
    private static let phoneLabel = "Phone number"
    private static let emailLabel = "Email address"
    private static let genderLabel = "Gender"
    private static let addressLabel = "Address"
    private static let emergencyContactLabel = "Emergency contact"
    /// §2.4: the Phone / Email indicators — Green "Verified", Red "Unverified".
    private static let verifiedText = "Verified"
    private static let unverifiedText = "Unverified"
    /// §2.5–§2.7: the section titles and accessories.
    private static let activityTitle = "Activity"
    private static let jumpToTodayLabel = "Jump to today"
    private static let membershipTitle = "Membership"
    private static let groupsLabel = "groups"
    private static let engagementTitle = "Engagement"
    private static let programsLabel = "programs"
    /// §4 (C-059 `state=Progress`): the two chips' labels — "N complete", "N hours".
    private static let completeLabel = "complete"
    private static let hoursLabel = "hours"

    // MARK: - §2 geometry the screen owns

    // GAP — members-profile §2.1: "Avatar (C-038) 164pt circle" — a consumer-applied diameter
    // (C-038 §3b), no size token.
    private static let avatarSize: CGFloat = 164
    // GAP — members-profile §2.1: "left-aligned, 16pt top" — a vertical 16 with no spacing
    // token naming the role (page-margin is horizontal).
    private static let avatarTopGap: CGFloat = 16
    // GAP — members-profile §2.1: "name (SF Pro Bold ~24/32 white)" — no Bold 24/32 type
    // token (`type-value-hero` is Regular 24/32).
    private static let nameStyle = DesignTextStyle(weight: .bold, size: 24, lineHeight: 32, tracking: 0)
    // GAP — members-profile §2.2: "16pt column gutter, 16pt row gap" — no grid spacing token.
    private static let gridGap: CGFloat = 16
    // GAP — members-profile §2.5: "C-023 RailCard … 131×192".
    private static let dayCardWidth: CGFloat = 131
    // GAP — members-profile §2.5: "shared 1px borders" — adjacent cards overlap by 1.
    private static let dayCardOverlap: CGFloat = -1
    // GAP — members-profile frame `default` (element map): each Membership / Engagement header
    // sits 16 above its first row (1547→1563, 1842→1858); §2 states no gap.
    private static let listGap: CGFloat = 16
    // GAP — members-profile §2.3: "Hairline (`color-layout-border`)" — no stroke-width token.
    private static let hairline: CGFloat = 1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length, so the page lays out top to bottom at full height. The status bar (§1
        // deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "PageHeader (C-040, 56pt: back chevron left, member name centered, no right
            // icons)" — `style=Two icons`, `showTitle=true`, `showIcons=false` (§4).
            PageHeader(
                style: .twoIcons,
                title: state.memberName,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            VStack(alignment: .leading, spacing: 0) {
                identityBlock
                Spacer().frame(height: Token.Space.sectionGap)       // frame: 374→406
                quickStats
                sectionDivider
                fields
                sectionDivider
                activitySection
                sectionDivider
                membershipSection
                sectionDivider
                engagementSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                          // §2: `color-layout-background`
    }

    /// §2: hairline (`color-layout-border`) with `space-section-gap` (32) above and below. The
    /// frame draws the line INSIDE that 64pt band (element map: every divider band measures 64,
    /// the line at ~31–32), so it is overlaid on the band and adds no height of its own.
    private var sectionDivider: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Token.Space.sectionGap * 2)
            .overlay {
                Rectangle()
                    .fill(Token.layoutBorder)
                    .frame(height: Self.hairline)
            }
            .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.1 Identity

    /// §2.1: "Avatar (C-038) 164pt circle, left-aligned, 16pt top → 32pt → name … over email
    /// …, 8pt gap."
    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Self.avatarTopGap)
            Avatar(
                imageURL: Self.optionalText(state.avatarURL).flatMap(URL.init(string:)),
                initials: Self.optionalText(state.initials),
                size: Self.avatarSize
            )
            .ui2Element("C-038 Avatar")
            Spacer().frame(height: Token.Space.sectionGap)
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                Text(state.memberName)
                    .designTextStyle(Self.nameStyle)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    .frame(minHeight: Self.nameStyle.lineHeight, alignment: .leading)
                // §2.1: "email (SF Pro Regular 14/20 `text/secondary`)" — `type-body-sm`.
                Text(state.email)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.textSecondary)
                    .lineLimit(1)
                    .frame(minHeight: Token.TypeStyle.bodySm.lineHeight, alignment: .leading)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.2 Quick stats

    /// §2.2: "2×2 MetaPair (C-022) grid: cells 196×36, 16pt column gutter, 16pt row gap" —
    /// `layout=stacked` (§4; `align` is inert there, C-022 §4).
    private var quickStats: some View {
        VStack(alignment: .leading, spacing: Self.gridGap) {
            HStack(alignment: .top, spacing: Self.gridGap) {
                statCell(label: Self.ageLabel, value: "\(state.age)", ordinal: 1)
                statCell(label: Self.roleLabel, value: state.role, ordinal: 2)
            }
            HStack(alignment: .top, spacing: Self.gridGap) {
                statCell(label: Self.birthdayLabel, value: state.birthday, ordinal: 3)
                statCell(label: Self.joinedLabel, value: state.joined, ordinal: 4)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    private func statCell(label: String, value: String, ordinal: Int) -> some View {
        MetaPair(value: value, label: label, layout: .stacked, align: .left)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element(Self.partName("C-022 MetaPair", ordinal: ordinal))
    }

    // MARK: §2.4 Fields

    /// §2.4: "8 stacked EditableFieldRow (C-042) rows, 74pt each, no separators". §3 `partial`:
    /// "any absent field value renders the EditableFieldRow with an empty value line (label
    /// persists)" — so an absent value is passed as "", never nil (nil drops the line).
    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow(Self.organizationLabel, state.organization, ordinal: 1)
            fieldRow(Self.roleLabel, state.role, ordinal: 2)
            fieldRow(
                Self.phoneLabel,
                state.phone,
                indicator: Self.verification(state.phoneVerified, present: !state.phone.isEmpty),
                ordinal: 3
            )
            fieldRow(
                Self.emailLabel,
                state.email,
                indicator: Self.verification(state.emailVerified, present: !state.email.isEmpty),
                ordinal: 4
            )
            fieldRow(Self.birthdayLabel, state.birthday, ordinal: 5)
            fieldRow(Self.genderLabel, state.gender, ordinal: 6)
            fieldRow(Self.addressLabel, state.address, ordinal: 7)
            fieldRow(Self.emergencyContactLabel, state.emergencyContact, ordinal: 8)
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    private func fieldRow(
        _ label: String,
        _ value: String,
        indicator: EditableFieldRow.Indicator? = nil,
        ordinal: Int
    ) -> some View {
        EditableFieldRow(label: label, value: value, indicator: indicator, onTap: { onEditField(label) })
            .ui2Element(Self.partName("C-042 EditableFieldRow", ordinal: ordinal))
    }

    /// §2.4: Phone → `Green indicator` "Verified", Email → `Red indicator` "Unverified"; the
    /// indicator is display-only (§3). No value, no indicator.
    private static func verification(_ verified: Bool, present: Bool) -> EditableFieldRow.Indicator? {
        guard present else { return nil }
        return verified
            ? .init(text: verifiedText, tone: .positive)
            : .init(text: unverifiedText, tone: .negative)
    }

    // MARK: §2.5 Activity

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2.5: "C-020 SectionHeader (title + `text-link` accessory "Jump to today")".
            SectionHeader(
                title: Self.activityTitle,
                accessory: .link(label: Self.jumpToTodayLabel, style: .muted),
                onAccessoryTap: onJumpToToday
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader")
            Spacer().frame(height: Token.Space.sectionGap)           // frame: 1236→1268
            // §2.5: "Day rail: C-023 RailCard `kind=day · transparent` ×N, 131×192, shared 1px
            // borders, horizontal scroll". A horizontal carousel keeps its own ScrollView (D22).
            HorizontalRail {
                HStack(alignment: .top, spacing: Self.dayCardOverlap) {
                    ForEach(state.dayNumbers.indices, id: \.self) { index in
                        RailCard(
                            kind: .day,
                            series: state.daySeries[safe: index] ?? [],
                            state: .transparent,
                            month: state.dayMonths[safe: index] ?? "",
                            weekday: state.dayWeekdays[safe: index] ?? "",
                            day: state.dayNumbers[index],
                            dateState: Self.dateState(state.dayDateStates[safe: index]),
                            line1: state.dayLine1s[safe: index] ?? "",
                            line2: Self.optionalText(state.dayLine2s[safe: index]),
                            detailsState: Self.detailsState(state.dayDetailsStates[safe: index])
                        )
                        .frame(width: Self.dayCardWidth)
                        .ui2Element(Self.partName("C-023 RailCard", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: §2.6 Membership

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2.6: "C-020 (title + MetaPair "2 groups" + GlyphButton `add`)"; §3: the count
            // is the list's, "0" when there are none.
            SectionHeader(
                title: Self.membershipTitle,
                accessory: .meta(value: "\(state.groupTitles.count)", label: Self.groupsLabel, glyph: .add),
                onAccessoryTap: onAddToGroup
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 2")
            // §3 `partial`: "zero groups … → the section renders header-only".
            if !state.groupTitles.isEmpty {
                Spacer().frame(height: Self.listGap)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.groupTitles.indices, id: \.self) { index in
                        // §4: `group / chips / chevron` — C-038 64 → title → C-043 chips
                        // (`Single` leader + `Key value / Right` joined date) → chevron; 96pt.
                        ListResultRow(
                            subject: .group,
                            title: state.groupTitles[index],
                            detail: .chips,
                            chips: groupChips(index),
                            trailing: .chevron,
                            imageURL: Self.optionalText(state.groupPhotoURLs[safe: index]).flatMap(URL.init(string:)),
                            onTap: { onOpenGroup(index) }
                        )
                        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    private func groupChips(_ index: Int) -> [ListResultRow.Chip] {
        [
            .init(value: state.groupLeaders[safe: index] ?? ""),
            .init(value: state.groupJoinedDates[safe: index] ?? "", label: Self.joinedLabel, labelPosition: .leading)
        ]
    }

    // MARK: §2.7 Engagement

    private var engagementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2.7: "C-020 (title + MetaPair "2 programs" + GlyphButton `add`)".
            SectionHeader(
                title: Self.engagementTitle,
                accessory: .meta(value: "\(state.programTitles.count)", label: Self.programsLabel, glyph: .add),
                onAccessoryTap: onEnroll
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 3")
            // §3 `partial`: "zero … programs → the section renders header-only".
            if !state.programTitles.isEmpty {
                Spacer().frame(height: Self.listGap)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.programTitles.indices, id: \.self) { index in
                        // §3: "StudyProgramRow tap — no affordance shown in source (no
                        // chevron): not tappable in v1" — the initializer without `onTap`.
                        StudyProgramRow(
                            state: Self.programState(state.programStates[safe: index]),
                            title: state.programTitles[index],
                            progress: state.programProgress[safe: index] ?? 0,
                            metaChips: programChips(index),
                            cover: Self.cachedImage(state.programCoverURLs[safe: index])
                        )
                        .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    /// §4 (C-043 section): `Default/Key value/Left` "N complete" + "N hours"; the second row's
    /// "31 complete" is `Complete/Key value/Left` — the complete chip follows the row's state.
    private func programChips(_ index: Int) -> [StudyProgramRow.Chip] {
        let complete = Self.programState(state.programStates[safe: index]) == .complete
        return [
            .init(
                value: state.programCompleteCounts[safe: index] ?? "",
                label: Self.completeLabel,
                state: complete ? .complete : .default
            ),
            .init(value: state.programHours[safe: index] ?? "", label: Self.hoursLabel)
        ]
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

    private static func optionalText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    /// C-059 §4 `cover: Image?` is resolved by the caller (R-19 / R-32). The screen reads it
    /// from the preview module's image cache — which the capture case seeds — and loads nothing.
    @MainActor
    private static func cachedImage(_ raw: String?) -> Image? {
        guard let raw = optionalText(raw), let url = URL(string: raw),
              let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
    }

    private static func programState(_ raw: String?) -> StudyProgramRow.State {
        StudyProgramRow.State(rawValue: raw ?? "") ?? .progress
    }

    private static func dateState(_ raw: String?) -> DateBlock.State {
        raw == "today" ? .today : .default
    }

    private static func detailsState(_ raw: String?) -> ValuePair.State {
        switch raw {
        case "nothing": return .nothing
        case "muted": return .muted
        case "lessonDay": return .lessonDay
        case "highlighted": return .highlighted
        case "single": return .single
        case "singleMuted": return .singleMuted
        default: return .default
        }
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

extension MembersProfileScreen.State {

    /// §3 `populated` — every value is the text on the frozen frame `default` (node 3668:8120;
    /// §1 deviation 1: sample content). Photos are stand-in URLs (a portrait for the member,
    /// the component previews' picsum seeds elsewhere); the day-rail series are read off the
    /// frame's bar shapes.
    static let populated = Self(
        memberName: "Tony Stark",
        email: "tstank@starkindustries.com",
        avatarURL: "https://i.pravatar.cc/328?img=12",
        initials: "TS",
        age: 52,
        role: "Member",
        birthday: "Jun 25, 1974",
        joined: "July 5, 2026",
        organization: "MakeReady",
        phone: "+1 (123) 456-7890",
        phoneVerified: true,
        emailVerified: false,
        gender: "Male",
        address: "123 Stark Tower, NYC NY 12345",
        emergencyContact: "Pepper Stark",
        dayMonths: ["JUL", "JUL", "JUL", "JUL"],
        dayWeekdays: ["MON", "MON", "MON", ""],
        dayNumbers: ["24", "25", "26", "27"],
        dayDateStates: ["default", "default", "default", "today"],
        daySeries: [
            [0, 0, 3, 5, 2, 0, 4, 6, 3, 2, 5, 0, 3, 7, 4, 2, 6, 8, 3, 1, 4, 2, 0, 3],
            [0, 0, 0, 0, 0, 0, 24, 2, 0, 4, 12, 6, 2, 0, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 20, 0, 0, 0, 12, 6, 18, 6, 0, 0, 5, 14, 24, 14, 6, 0, 0, 0, 0, 12, 6, 0]
        ],
        dayLine1s: ["15 mins", "27 mins", "0 mins", "27 mins"],
        dayLine2s: ["7:20 am", "7:25 am", "0 complete", "8:30 am"],
        dayDetailsStates: ["muted", "muted", "nothing", "muted"],
        groupTitles: ["Young professionals", "The kids"],
        groupPhotoURLs: [
            "https://picsum.photos/seed/c037-group/256",
            "https://picsum.photos/seed/c037-group-2/256"
        ],
        groupLeaders: ["L. Keith", "S. Stickane"],
        groupJoinedDates: ["Jul 3, 2025", "Aug 5, 2025"],
        programTitles: ["Daily Inspiration", "Romans in 30 days"],
        programStates: ["Progress", "Complete"],
        programProgress: [0.68, 1],
        programCompleteCounts: ["12", "31"],
        programHours: ["15", "92"],
        programCoverURLs: [
            "https://picsum.photos/seed/c059/128/176",
            "https://picsum.photos/seed/c059-2/128/176"
        ]
    )

    /// §3 `partial` — "any absent field value renders the EditableFieldRow with an empty value
    /// line (label persists); absent avatar → initials fallback (C-038); zero groups/programs →
    /// the section renders header-only with count "0"". The absent fields are §5's API-GAP
    /// fields (gender, address, emergency contact); everything else is `populated`'s.
    static let partial = Self(
        memberName: populated.memberName,
        email: populated.email,
        avatarURL: "",
        initials: populated.initials,
        age: populated.age,
        role: populated.role,
        birthday: populated.birthday,
        joined: populated.joined,
        organization: populated.organization,
        phone: populated.phone,
        phoneVerified: populated.phoneVerified,
        emailVerified: populated.emailVerified,
        gender: "",
        address: "",
        emergencyContact: "",
        dayMonths: populated.dayMonths,
        dayWeekdays: populated.dayWeekdays,
        dayNumbers: populated.dayNumbers,
        dayDateStates: populated.dayDateStates,
        daySeries: populated.daySeries,
        dayLine1s: populated.dayLine1s,
        dayLine2s: populated.dayLine2s,
        dayDetailsStates: populated.dayDetailsStates,
        groupTitles: [],
        groupPhotoURLs: [],
        groupLeaders: [],
        groupJoinedDates: [],
        programTitles: [],
        programStates: [],
        programProgress: [],
        programCompleteCounts: [],
        programHours: [],
        programCoverURLs: []
    )
}

#Preview("populated") {
    MembersProfileScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("partial") {
    MembersProfileScreen(state: .partial)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
