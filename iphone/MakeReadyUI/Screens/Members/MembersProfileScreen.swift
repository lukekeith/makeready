//
//  MembersProfileScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen members-profile in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/members/{memberId} ·
//  GET /api/members/{memberId}/groups · POST /api/analytics/query
//  (address, emergencyContact, emailVerified and the per-member program engagement are
//  API-GAPs in §5).
//  Wired by MakeReady/UI2/Containers/Members/MemberProfileContainer.swift (ui2-members-browse).
//  ui2-members-browse edits, routed to /ui2-resolve (F3): display-only C-042 rows (D3), no Email
//  indicator (P5/D9), "Emergency contact" + "Emergency phone" (P6), multi-line Address (P7),
//  `age` as a String (D10), the rail opening on today (D12).
//  ui2-members-edit edits, routed to /ui2-resolve (F2): the 7 D1 rows tappable once loaded (D27),
//  `onEditField` reports a MemberField key (D2); Organization and Role stay display-only (D28).
//

import SwiftUI

/// ui2-members-edit D2 (P3): the member fields a leader edits from this page — the key a C-042
/// row reports, never its label. MakeReadyUI compiles into the app module too, so the shell's
/// `UI2Destination.editMemberField` and the edit container use this same type.
enum MemberField: String, CaseIterable {
    case email, phone, birthday, gender, address, emergencyName, emergencyPhone
}

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
        /// D10: "" when the birthday is absent → an empty value line.
        var age: String
        var role: String
        var birthday: String
        var joined: String
        var organization: String
        var phone: String
        var phoneVerified: Bool
        var gender: String
        var address: String
        /// P6: two fields, two rows.
        var emergencyContactName: String
        var emergencyContactPhone: String
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
        // ── ui2-members-edit D27 ──
        /// The 7 D1 rows are tappable only when the member's detail is loaded. Defaulted false:
        /// the previews and the capture case render display-only rows, as before.
        var fieldsEditable: Bool = false
    }

    let state: State
    /// D22: false when the container pins C-040 above its own ScrollView, so the header is not
    /// drawn twice. True (the default) keeps the capture / ViewRegistry render whole.
    let showsHeader: Bool
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}                     // C-040 back — pops to the presenter
    var onEditField: (MemberField) -> Void = { _ in }  // C-042 tap → shared-edit-field (OQ-1), by field key (D2)
    var onJumpToToday: () -> Void = {}              // recenters the day rail on today
    var onAddToGroup: () -> Void = {}               // Membership add → group picker (OQ-2)
    var onOpenGroup: (Int) -> Void = { _ in }       // C-037 tap → the group's screen (OQ-2)
    var onEnroll: () -> Void = {}                   // Engagement add → enroll action (OQ-2)

    init(
        state: State,
        showsHeader: Bool = true,
        onBack: @escaping () -> Void = {},
        onEditField: @escaping (MemberField) -> Void = { _ in },
        onJumpToToday: @escaping () -> Void = {},
        onAddToGroup: @escaping () -> Void = {},
        onOpenGroup: @escaping (Int) -> Void = { _ in },
        onEnroll: @escaping () -> Void = {}
    ) {
        self.state = state
        self.showsHeader = showsHeader
        self.onBack = onBack
        self.onEditField = onEditField
        self.onJumpToToday = onJumpToToday
        self.onAddToGroup = onAddToGroup
        self.onOpenGroup = onOpenGroup
        self.onEnroll = onEnroll
    }

    // R-31 ephemeral UI: the day rail's scroll position (D12: it opens on today, "Jump to today"
    // returns there). Everything else leaves the screen.
    @SwiftUI.State private var railDay: Int?

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
    private static let emergencyPhoneLabel = "Emergency phone"
    /// §2.4 + P6: the nine field rows, top → bottom.
    static let fieldLabels = [
        organizationLabel, roleLabel, phoneLabel, emailLabel, birthdayLabel,
        genderLabel, addressLabel, emergencyContactLabel, emergencyPhoneLabel
    ]
    /// ui2-members-edit D2: the field a row edits — the 7 D1 rows; Organization and Role edit
    /// nothing (D28 / OQ-C-042-3: they keep `isTappable: false`).
    static func field(forLabel label: String) -> MemberField? {
        MemberField.allCases.first { Self.label(for: $0) == label }
    }

    /// D14: the row label, verbatim — also the edit page's title.
    static func label(for field: MemberField) -> String {
        switch field {
        case .email: return emailLabel
        case .phone: return phoneLabel
        case .birthday: return birthdayLabel
        case .gender: return genderLabel
        case .address: return addressLabel
        case .emergencyName: return emergencyContactLabel
        case .emergencyPhone: return emergencyPhoneLabel
        }
    }

    /// D1 + D27: a row is tappable iff it edits a field and the member is loaded.
    static func isTappable(_ label: String, _ s: State) -> Bool {
        s.fieldsEditable && field(forLabel: label) != nil
    }
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
            if showsHeader {
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
            }

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
                statCell(label: Self.ageLabel, value: state.age, ordinal: 1)
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

    /// §2.4 + P6: nine stacked EditableFieldRow (C-042) rows, 74pt each, no separators. §3
    /// `partial`: an absent value is passed as "", never nil (nil drops the value line, D10).
    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.fieldLabels.enumerated()), id: \.offset) { index, label in
                EditableFieldRow(
                    label: label,
                    value: Self.fieldValue(label, state),
                    indicator: Self.indicator(forField: label, state: state),
                    multiline: label == Self.addressLabel,              // P7
                    onTap: { if let field = Self.field(forLabel: label) { onEditField(field) } },   // D2
                    isTappable: Self.isTappable(label, state)           // D1 + D27
                )
                .ui2Element(Self.partName("C-042 EditableFieldRow", ordinal: index + 1))
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    static func fieldValue(_ label: String, _ s: State) -> String {
        switch label {
        case Self.organizationLabel: return s.organization
        case Self.roleLabel: return s.role
        case Self.phoneLabel: return s.phone
        case Self.emailLabel: return s.email
        case Self.birthdayLabel: return s.birthday
        case Self.genderLabel: return s.gender
        case Self.addressLabel: return s.address
        case Self.emergencyContactLabel: return s.emergencyContactName
        case Self.emergencyPhoneLabel: return s.emergencyContactPhone
        default: return ""
        }
    }

    /// P5/D9: only Phone carries an indicator — Green "Verified" / Red "Unverified"; display-only
    /// (§3). No value, no indicator.
    static func indicator(forField label: String, state s: State) -> EditableFieldRow.Indicator? {
        guard label == Self.phoneLabel, !s.phone.isEmpty else { return nil }
        return s.phoneVerified
            ? .init(text: verifiedText, tone: .positive)
            : .init(text: unverifiedText, tone: .negative)
    }

    // MARK: §2.5 Activity

    /// D12: today's card — the rail's trailing card; nil while the rail is empty.
    static func todayIndex(_ dateStates: [String]) -> Int? { dateStates.lastIndex(of: "today") }

    // GAP — no motion token for the recentre: HomeDashboardScreen's ease-in-out, 0.45s.
    private static var jumpAnimation: Animation { .easeInOut(duration: 0.45) }

    private var activitySection: some View {
        // T12: the reader lets "Jump to today" scroll the rail directly (HomeDashboardScreen.swift
        // pattern) — a binding write the rail already holds would not move it.
        ScrollViewReader { rail in
            VStack(alignment: .leading, spacing: 0) {
                // §2.5: "C-020 SectionHeader (title + `text-link` accessory "Jump to today")".
                SectionHeader(
                    title: Self.activityTitle,
                    accessory: .link(label: Self.jumpToTodayLabel, style: .muted),
                    onAccessoryTap: { jumpToToday(rail) }
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
                    .scrollTargetLayout()
                    .padding(.horizontal, Token.Space.pageMargin)
                }
                .scrollIndicators(.hidden)
                // D12: the rail opens with today as its trailing card; days that land after the
                // page opened (cache-first, F5) re-align it.
                .scrollPosition(id: $railDay, anchor: .trailing)
                .onAppear { railDay = Self.todayIndex(state.dayDateStates) }
                .onChange(of: Self.todayIndex(state.dayDateStates)) { _, today in railDay = today }
            }
        }
    }

    /// members-profile §3: "Jump to today" recentres the rail on today (most recent day trailing).
    private func jumpToToday(_ rail: ScrollViewProxy) {
        if let today = Self.todayIndex(state.dayDateStates) {
            withAnimation(Self.jumpAnimation) {
                railDay = today
                rail.scrollTo(today, anchor: .trailing)
            }
        }
        onJumpToToday()
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
        age: "52",
        role: "Member",
        birthday: "Jun 25, 1974",
        joined: "July 5, 2026",
        organization: "MakeReady",
        phone: "+1 (123) 456-7890",
        phoneVerified: true,
        gender: "Male",
        address: "123 Stark Tower, NYC NY 12345",
        emergencyContactName: "Pepper Stark",
        emergencyContactPhone: "+1 (123) 456-7891",
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
        gender: "",
        address: "",
        emergencyContactName: "",
        emergencyContactPhone: "",
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
