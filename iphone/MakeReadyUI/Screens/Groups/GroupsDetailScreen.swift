//
//  GroupsDetailScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen groups-detail in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/groups/{id} ·
//  PATCH /api/groups/{id} · POST /api/groups/{id}/cover-image ·
//  GET /api/groups/{groupId}/members · GET /api/groups/{groupId}/join-requests ·
//  GET /api/groups/{groupId}/enrollments ·
//  GET /api/groups/{groupId}/next-study · POST /api/analytics/query ·
//  GET /api/groups/{groupId}/membership-history · GET /api/groups/{groupId}/events ·
//  DELETE /api/groups/{id}
//  (group-scoped daily completion metrics and one merged group-history feed are API-GAPs
//  in §5).
//  Wired by MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edits, routed to /ui2-resolve (F3): `showsHeader` (D27 — the container
//  pins C-040 above its ScrollView) and the day rail opening at its last card (D27/D12).
//

import SwiftUI

/// Group detail — the leader's group home, pushed from a groups-home row (§6). A pushed page:
/// C-040 header, then the cover, quick stats, the settings fields, Lessons up next, Activity,
/// Members, Enrollments, Timeline and the destructive Delete Group action, separated by
/// C-088 dividers (§2). Composed only of §4's C-020, C-022, C-023, C-026, C-027, C-037, C-040,
/// C-042, C-048, C-059, C-063, C-065, C-087, C-088 and C-089.
///
/// §3 names four states — `populated`, `section-empty`, `loading`, `error` — and all four are
/// reachable through `State` alone: `section-empty` and `loading` are empty lists (§3: "header
/// kept, one `type-body-sm` `color-text-secondary` line below it"), and `error` "keeps the
/// cached render" with no designed banner, so it is the populated data.
struct GroupsDetailScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone. Parallel arrays, one
    /// entry per day card / chart day / member / enrollment / event, because the preview's props
    /// are JSON and the §4 views take flat parameters (R-05). Counts are computed from the
    /// lists, never stored (R-30).
    struct State {
        // ── Group core (§2.1, §2.2, §2.4) — "" = not loaded yet (§3 `loading`) ──
        /// C-040's centred title and the Group name field's value.
        var groupName: String
        /// C-087's image by URL; "" = no cover.
        var coverURL: String
        var leaderName: String
        var createdLabel: String
        var groupDescription: String
        var visibility: String
        var ageRange: String
        var maximumMembers: String
        var memberDirectoryAccess: String
        // ── Lessons up next (§2.5) — C-063 `linked`; empty = section-empty ──
        var lessonTitles: [String]
        var lessonProgramNames: [String]
        var lessonMetaLabels: [String]
        /// Per lesson, its slides' screenshots by URL ("" = unresolved → C-079 `empty`).
        var lessonSlideImages: [[String]]
        /// Per lesson, its slides' VoiceOver labels (never rendered).
        var lessonSlideLabels: [[String]]
        // ── Activity (§2.6) — C-023 `kind=day · transparent`, one entry per day ──
        var dayMonths: [String]
        var dayWeekdays: [String]
        var dayNumbers: [String]
        /// C-070: "default" | "today".
        var dayDateStates: [String]
        var daySeries: [[Double]]
        var dayLine1s: [String]
        /// "" = no second line (C-071 `nothing`).
        var dayLine2s: [String]
        /// C-071 state: "highlighted" | "default" | "nothing" (§4: highlight / positive / nothing).
        var dayDetailsStates: [String]
        // ── Activity chart (§2.6) — C-026, `yyyy-MM-dd` (UTC); empty = C-026's empty state ──
        var chartDates: [String]
        var chartScheduled: [Int]
        var chartCompleted: [Int]
        var chartWindowStart: String
        var chartWindowEnd: String
        /// C-026's capture seam for "today" (its §3 Today rendering is derived from it).
        var chartToday: String
        // ── Members (§2.7) — C-037 `member / text / chevron`, every member ──
        var memberNames: [String]
        /// "" = no photo → C-038's fallback inside C-037.
        var memberPhotoURLs: [String]
        /// The caller-formatted "Joined «relative date»" line.
        var memberJoinedLabels: [String]
        // ── Join requests (§2.7, amended 2026-10-18) — C-089 `requested`, every pending
        // request, above the member rows; empty = none (the frame draws none) ──
        /// C-089 `recipient`: the requester's name.
        var requestNames: [String]
        /// C-089 `date`: the caller-formatted request date.
        var requestDates: [String]
        // ── Enrollments (§2.8) — C-059, every enrollment ──
        var programTitles: [String]
        var programDescriptions: [String]
        /// The C-043 "enrolled «date»" chip's value.
        var programEnrolledDates: [String]
        /// "" = no cover → C-059's missing-cover box.
        var programCoverURLs: [String]
        // ── Timeline (§2.9) — C-065, the latest 5 events ──
        var eventDates: [String]
        var eventTexts: [String]
        /// "" = no highlight.
        var eventHighlights: [String]
        /// C-065 `tone`: "neutral" | "positive" | "accent" (D54).
        var eventTones: [String]
    }

    let state: State
    /// D27: false when the container pins C-040 above its own ScrollView, so the header is not
    /// drawn twice. True (the default) keeps the capture / ViewRegistry render whole.
    let showsHeader: Bool
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op
    // default. The screen never decides what an action means.
    var onBack: () -> Void = {}                         // C-040 back → pops to the pusher
    var onEditField: (String) -> Void = { _ in }        // C-042 tap → that field's edit pattern, by label
    var onOpenLesson: () -> Void = {}                   // C-063 → enrollment-home of that enrollment
    var onPanChart: () -> Void = {}                     // C-026 pans its window (`onWindowChange`)
    var onInviteMember: () -> Void = {}                 // Members `add` → groups-invite-member
    var onOpenMember: (Int) -> Void = { _ in }          // C-037 tap → members-profile
    var onOpenRequest: (Int) -> Void = { _ in }         // C-089 tap → invite-home (OQ-schat-groups-detail-1)
    var onEnrollProgram: () -> Void = {}                // Enrollments `add` → groups-enroll-program
    var onOpenEnrollment: (Int) -> Void = { _ in }      // C-059 tap → enrollment-home
    var onOpenHistory: () -> Void = {}                  // Timeline "All history" → groups-history
    var onDeleteGroup: () -> Void = {}                  // C-048 → the archive confirmation (OQ-004)
    var onCoverTap: () -> Void = {}                     // C-087 tap → picker or the cover menu (group-cover-image D1/D2)

    init(
        state: State,
        showsHeader: Bool = true,
        onBack: @escaping () -> Void = {},
        onEditField: @escaping (String) -> Void = { _ in },
        onOpenLesson: @escaping () -> Void = {},
        onPanChart: @escaping () -> Void = {},
        onInviteMember: @escaping () -> Void = {},
        onOpenMember: @escaping (Int) -> Void = { _ in },
        onOpenRequest: @escaping (Int) -> Void = { _ in },
        onEnrollProgram: @escaping () -> Void = {},
        onOpenEnrollment: @escaping (Int) -> Void = { _ in },
        onOpenHistory: @escaping () -> Void = {},
        onDeleteGroup: @escaping () -> Void = {},
        onCoverTap: @escaping () -> Void = {}
    ) {
        self.state = state
        self.showsHeader = showsHeader
        self.onBack = onBack
        self.onEditField = onEditField
        self.onOpenLesson = onOpenLesson
        self.onPanChart = onPanChart
        self.onInviteMember = onInviteMember
        self.onOpenMember = onOpenMember
        self.onOpenRequest = onOpenRequest
        self.onEnrollProgram = onEnrollProgram
        self.onOpenEnrollment = onOpenEnrollment
        self.onOpenHistory = onOpenHistory
        self.onDeleteGroup = onDeleteGroup
        self.onCoverTap = onCoverTap
    }

    // R-31 ephemeral UI: the day rail's scroll position. D27/D12: the rail opens at its last card
    // (today trails) and "Jump to today" scrolls back to it.
    @SwiftUI.State private var railDay: Int?

    /// D27: the card the rail opens on — the last (today trails, D12); nil while the rail is empty.
    static func openingRailIndex(_ dayCount: Int) -> Int? { dayCount > 0 ? dayCount - 1 : nil }

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2.2: the quick-stat labels, in grid order.
    private static let leaderLabel = "Group Leader"
    private static let membersLabel = "Members"
    private static let createdLabel = "Created"
    private static let enrollmentsLabel = "Enrollments"
    /// §2.4: the field labels, top → bottom.
    private static let groupNameLabel = "Group name"
    private static let descriptionLabel = "Description"
    private static let visibilityLabel = "Visibility"
    private static let ageLabel = "Age"
    private static let maximumMembersLabel = "Maximum members"
    private static let directoryLabel = "Member directory access"
    /// §2.5–§2.9: the section titles and accessories.
    private static let lessonsTitle = "Lessons up next"
    private static let activityTitle = "Activity"
    private static let jumpToTodayLabel = "Jump to today"
    private static let membersTitle = "Members"
    private static let membersCountLabel = "members"
    private static let enrollmentsTitle = "Enrollments"
    private static let programsCountLabel = "programs"
    private static let timelineTitle = "Timeline"
    private static let allHistoryLabel = "All history"
    /// §2.6: the legend — "Completed lessons · Scheduled lessons".
    private static let completedLegendLabel = "Completed lessons"
    private static let scheduledLegendLabel = "Scheduled lessons"
    /// §2.8: the C-043 chip's key — "enrolled «date»".
    private static let enrolledLabel = "enrolled"
    /// §2.10: C-048's label. OQ-groups-detail-007 (owner, closed): "Keep Figma's "Delete Group"
    /// label" although the action archives (OQ-004).
    private static let deleteGroupLabel = "Delete Group"
    /// §3 `section-empty` copy (closed list, OQ-groups-detail-006).
    private static let noLessonsCopy = "No lessons scheduled"
    private static let noMembersCopy = "No members yet"
    private static let noEnrollmentsCopy = "No enrollments yet"
    private static let noHistoryCopy = "No history yet"

    // MARK: - §2 geometry the screen owns

    // GAP — groups-detail §2.2: "cells 196×36, column gutter 16, row gap 16" — no grid spacing
    // token names the role.
    private static let gridGap: CGFloat = 16
    // GAP — groups-detail §2.6: "C-023 RailCard `kind=day · transparent` 131×192".
    private static let dayCardWidth: CGFloat = 131
    // GAP — groups-detail §2.6: "adjacent cards share their 1px side borders (−1pt overlap)".
    private static let dayCardOverlap: CGFloat = -1
    // GAP — groups-detail §2.6: "C-026 DualSeriesBarChart 408×149". C-026's build is a fixed
    // 440×149 footprint (home-dashboard's full-bleed), so it is placed at the page margin and
    // its right 32pt runs past 408 — a C-026 build gap, reported, not patched here.
    private static let chartHeight: CGFloat = 149
    // GAP — groups-detail §2.6: "legend row: two C-027 LegendItem, inset 16, gap 16" — no
    // spacing token names either role.
    private static let legendInset: CGFloat = 16
    private static let legendGap: CGFloat = 16
    // GAP — groups-detail §2.9: "a 1px vertical connector line `color-layout-border` at x = 10
    // of the rows, from 16 below the first row's top to the last dot". The frozen frame
    // `default` ends the line 34 above the block's bottom (the 4th/5th row boundary, measured
    // 2026-10-03), which is what this build draws; no token names any of the four values.
    private static let connectorWidth: CGFloat = 1
    private static let connectorX: CGFloat = 10
    private static let connectorTopInset: CGFloat = 16
    private static let connectorBottomInset: CGFloat = 34

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "C-040 PageHeader (56pt: `back` left, group name centred, no right icons)".
            if showsHeader {
                PageHeader(
                    style: .twoIcons,
                    title: state.groupName,
                    showTitle: true,
                    showIcons: false,
                    leadingGlyph: .back,
                    rightButtons: [],
                    onLeading: onBack
                )
                .ui2Element("C-040 PageHeader")
            }

            // §2: "content top padding 16, bottom padding ≥ 16"; every block, divider and
            // section header → content gap is `space-section-gap` (32).
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                cover
                quickStats
                divider(1)
                fields
                divider(2)
                lessonsSection
                divider(3)
                activitySection
                divider(4)
                membersSection
                divider(5)
                enrollmentsSection
                divider(6)
                timelineSection
                // §2.10: "32 → C-048 PageActionButton `role=destructive` "Delete Group",
                // 408×38".
                PageActionButton(label: Self.deleteGroupLabel, role: .destructive, onTap: onDeleteGroup)
                    .ui2Element("C-048 PageActionButton")
                    .padding(.horizontal, Token.Space.pageMargin)
            }
            .padding(.vertical, Token.Space.pageMargin)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                  // §2: `color-layout-background`
    }

    /// §2: "C-088 SectionDivider; `space-section-gap` (32) above and below every divider" —
    /// the 32s are the column's spacing.
    private func divider(_ ordinal: Int) -> some View {
        SectionDivider()
            .ui2Element(Self.partName("C-088 SectionDivider", ordinal: ordinal))
            .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.1 Cover

    /// §2.1: "C-087 CoverImage 408×180 at y119 (`radius-card`)". group-cover-image D1/D2: tappable;
    /// CoverImage is accessibilityHidden, so the button carries its own label and trait.
    private var cover: some View {
        SwiftUI.Button(action: onCoverTap) {
            CoverImage(image: Self.cachedImage(state.coverURL))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.coverURL.isEmpty ? "Add cover image" : "Cover image")
        .accessibilityAddTraits(.isButton)
        .ui2Element("C-087 CoverImage")
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.2 Quick stats

    /// §2.2: "2×2 C-022 MetaPair `layout=stacked` … Group Leader · Members / Created ·
    /// Enrollments". Both counts are computed from the lists (R-30).
    private var quickStats: some View {
        VStack(alignment: .leading, spacing: Self.gridGap) {
            HStack(alignment: .top, spacing: Self.gridGap) {
                statCell(label: Self.leaderLabel, value: state.leaderName, ordinal: 1)
                statCell(label: Self.membersLabel, value: "\(state.memberNames.count)", ordinal: 2)
            }
            HStack(alignment: .top, spacing: Self.gridGap) {
                statCell(label: Self.createdLabel, value: state.createdLabel, ordinal: 3)
                statCell(label: Self.enrollmentsLabel, value: "\(state.programTitles.count)", ordinal: 4)
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    /// C-022 `layout=stacked` (label over value); `align` is inert there (C-022 §4).
    private func statCell(label: String, value: String, ordinal: Int) -> some View {
        MetaPair(value: value, label: label, layout: .stacked, align: .left)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element(Self.partName("C-022 MetaPair", ordinal: ordinal))
    }

    // MARK: §2.4 Settings fields

    /// §2.4: "6 stacked C-042 EditableFieldRow, no gap between rows: Group name (74) ·
    /// Description (94, two-line value) · Visibility · Age · Maximum members · Member directory
    /// access". An unloaded value is "" — the label persists over an empty value line.
    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow(Self.groupNameLabel, state.groupName, ordinal: 1)
            fieldRow(Self.descriptionLabel, state.groupDescription, multiline: true, ordinal: 2)
            fieldRow(Self.visibilityLabel, state.visibility, ordinal: 3)
            fieldRow(Self.ageLabel, state.ageRange, ordinal: 4)
            fieldRow(Self.maximumMembersLabel, state.maximumMembers, ordinal: 5)
            fieldRow(Self.directoryLabel, state.memberDirectoryAccess, ordinal: 6)
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    private func fieldRow(_ label: String, _ value: String, multiline: Bool = false, ordinal: Int) -> some View {
        EditableFieldRow(label: label, value: value, multiline: multiline, onTap: { onEditField(label) })
            .ui2Element(Self.partName("C-042 EditableFieldRow", ordinal: ordinal))
    }

    // MARK: §2.5 Lessons up next

    /// §2.5: "C-020 SectionHeader `section·none` → 32 → one C-063 LessonCard (title + relative
    /// day, linked program line, three C-079 screenshots)". C-063 is full-bleed with its own
    /// `space-page-margin` inset (C-063 §2), so it takes no page margin here.
    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(title: Self.lessonsTitle)
                .ui2Element("C-020 SectionHeader")
                .padding(.horizontal, Token.Space.pageMargin)
            if let title = state.lessonTitles.first {
                LessonCard(
                    header: .linked(label: state.lessonProgramNames.first ?? ""),
                    title: title,
                    metaLabel: state.lessonMetaLabels.first ?? "",
                    progress: nil,
                    slides: lessonSlides,
                    onOpen: onOpenLesson
                )
                .ui2Element("C-063 LessonCard")
            } else {
                emptyLine(Self.noLessonsCopy)
            }
        }
    }

    private var lessonSlides: [LessonCard.Slide] {
        let images = state.lessonSlideImages.first ?? []
        let labels = state.lessonSlideLabels.first ?? []
        return images.indices.map { slide in
            LessonCard.Slide(image: Self.cachedImage(images[slide]), label: labels[safe: slide] ?? "")
        }
    }

    // MARK: §2.6 Activity

    /// §2.6: "C-020 `section·link` ("Jump to today", C-049 muted) → 32 → day rail … → 32 →
    /// C-026 DualSeriesBarChart … → 32 → legend row". §3 `section-empty`: "Activity renders
    /// C-023 day cards with C-071 `Nothing` and C-026's empty state, no text line".
    private var activitySection: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                SectionHeader(
                    title: Self.activityTitle,
                    accessory: .link(label: Self.jumpToTodayLabel, style: .muted),
                    onAccessoryTap: { scrollToToday(proxy) }
                )
                .ui2Element("C-020 SectionHeader 2")
                .padding(.horizontal, Token.Space.pageMargin)
                dayRail
                // The chart's 149pt slot is the page's; C-026 draws in it from the page margin.
                // An overlay, so C-026's fixed 440 footprint (+ the margin) cannot widen the
                // page column — measured as an 8pt left shift of the whole page when it did.
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.chartHeight)
                    .overlay(alignment: .topLeading) {
                        DualSeriesBarChart(
                            days: chartDays,
                            window: chartWindow,
                            today: Self.chartDate(state.chartToday) ?? .distantPast,
                            onWindowChange: { _ in onPanChart() }
                        )
                        .ui2Element("C-026 DualSeriesBarChart")
                        .padding(.leading, Token.Space.pageMargin)
                    }
                HStack(alignment: .center, spacing: Self.legendGap) {
                    LegendItem(color: Token.accent, label: Self.completedLegendLabel)
                        .ui2Element("C-027 LegendItem")
                    LegendItem(color: Token.white20, label: Self.scheduledLegendLabel)
                        .ui2Element("C-027 LegendItem 2")
                }
                .padding(.horizontal, Token.Space.pageMargin + Self.legendInset)
            }
        }
    }

    /// §2.6: "C-023 RailCard `kind=day · transparent` 131×192, adjacent cards share their 1px
    /// side borders (−1pt overlap), horizontal scroll, bleeding past the right margin". A
    /// horizontal carousel keeps its own ScrollView (D22).
    private var dayRail: some View {
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
                    .id(index)
                    .ui2Element(Self.partName("C-023 RailCard", ordinal: index + 1))
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, Token.Space.pageMargin)
        }
        .scrollIndicators(.hidden)
        // D27: opens on the last card; days that land after the page opened re-align it.
        .scrollPosition(id: $railDay, anchor: .trailing)
        .onAppear { railDay = Self.openingRailIndex(state.dayNumbers.count) }
        .onChange(of: state.dayNumbers.count) { _, count in railDay = Self.openingRailIndex(count) }
    }

    /// §3: ""Jump to today" → scrolls the day rail to today's card".
    private func scrollToToday(_ proxy: ScrollViewProxy) {
        guard let today = state.dayDateStates.firstIndex(of: "today") else { return }
        railDay = today
        proxy.scrollTo(today, anchor: .trailing)
    }

    // MARK: §2.7 Members

    /// §2.7: "C-020 `section·meta` (C-022 inline "«N» members" + 16 + C-021 `add`, deviation 7)
    /// → 32 → **join requests, when the group has any:** one C-089 InviteStatusRow
    /// `status=requested` per pending request (80pt each, no gap, no dividers, uncapped) …
    /// stacked directly below the header and **above** every member row → then **every** member
    /// as a C-037 ListResultRow `member / text / chevron`, 80pt each, no cap". "Requests are not
    /// counted in the header's "«N» members"", and the section is empty "only when there are no
    /// members and no join requests".
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(
                title: Self.membersTitle,
                accessory: .meta(value: "\(state.memberNames.count)", label: Self.membersCountLabel, glyph: .add),
                onAccessoryTap: onInviteMember
            )
            .ui2Element("C-020 SectionHeader 3")
            .padding(.horizontal, Token.Space.pageMargin)
            if state.memberNames.isEmpty && state.requestNames.isEmpty {
                emptyLine(Self.noMembersCopy)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.requestNames.indices, id: \.self) { index in
                        // §2.7: "`recipient` = the requester's name, `groupName` = this group's
                        // name, `date` = the request date".
                        InviteStatusRow(
                            recipient: state.requestNames[index],
                            status: .requested,
                            groupName: state.groupName,
                            date: state.requestDates[safe: index] ?? "",
                            onTap: { onOpenRequest(index) }
                        )
                        .ui2Element(Self.partName("C-089 InviteStatusRow", ordinal: index + 1))
                    }
                    ForEach(state.memberNames.indices, id: \.self) { index in
                        ListResultRow(
                            subject: .member,
                            title: state.memberNames[index],
                            detail: .text,
                            description: state.memberJoinedLabels[safe: index] ?? "",
                            trailing: .chevron,
                            imageURL: Self.optionalText(state.memberPhotoURLs[safe: index]).flatMap(URL.init(string:)),
                            onTap: { onOpenMember(index) }
                        )
                        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    // MARK: §2.8 Enrollments

    /// §2.8: "C-020 `section·meta` ("«N» programs" + C-021 `add`, deviation 7) → 32 → **every**
    /// enrollment as a C-059 StudyProgramRow `Enrolled` (D53), no cap".
    ///
    /// C-059's build predates D53's `Enrolled` state (built 2026-09-29, contract 2026-10-03), so
    /// this composes against the view as built: `Condensed` is the built state with the same
    /// parts (title, wrapping description, chip row, 64pt cover, no PercentBar). Its re-build
    /// (`/d2m:component:build C-059`) is reported; a screen re-build then switches the state.
    private var enrollmentsSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(
                title: Self.enrollmentsTitle,
                accessory: .meta(value: "\(state.programTitles.count)", label: Self.programsCountLabel, glyph: .add),
                onAccessoryTap: onEnrollProgram
            )
            .ui2Element("C-020 SectionHeader 4")
            .padding(.horizontal, Token.Space.pageMargin)
            if state.programTitles.isEmpty {
                emptyLine(Self.noEnrollmentsCopy)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.programTitles.indices, id: \.self) { index in
                        StudyProgramRow(
                            state: .condensed,
                            title: state.programTitles[index],
                            description: Self.optionalText(state.programDescriptions[safe: index]),
                            progress: 0,
                            metaChips: [
                                // §2.8: "C-043 MetaChip `Default · Key value` "enrolled «date»"" —
                                // the key leads, which is C-043's `align=Right` order.
                                .init(
                                    value: state.programEnrolledDates[safe: index] ?? "",
                                    label: Self.enrolledLabel,
                                    align: .leading
                                )
                            ],
                            cover: Self.cachedImage(state.programCoverURLs[safe: index]),
                            onTap: { onOpenEnrollment(index) }
                        )
                        .ui2Element(Self.partName("C-059 StudyProgramRow", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    // MARK: §2.9 Timeline

    /// §2.9: "C-020 `section·caption` ("All history" + 16 + C-021 `arrow-forward`) → 32 → the
    /// latest 5 events as C-065 TimelineEventRow … over a 1px vertical connector line".
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            SectionHeader(
                title: Self.timelineTitle,
                accessory: .caption(label: Self.allHistoryLabel, glyph: .arrowForward),
                onAccessoryTap: onOpenHistory
            )
            .ui2Element("C-020 SectionHeader 5")
            .padding(.horizontal, Token.Space.pageMargin)
            if state.eventTexts.isEmpty {
                emptyLine(Self.noHistoryCopy)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.eventTexts.indices, id: \.self) { index in
                        TimelineEventRow(
                            dateLabel: state.eventDates[safe: index] ?? "",
                            text: state.eventTexts[index],
                            highlight: Self.optionalText(state.eventHighlights[safe: index]),
                            tone: Self.tone(state.eventTones[safe: index])
                        )
                        .ui2Element(Self.partName("C-065 TimelineEventRow", ordinal: index + 1))
                    }
                }
                .background(alignment: .topLeading) { connector }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    /// §2.9: the connector line — "screen layout, not a row (as on invite-home)".
    private var connector: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(width: Self.connectorWidth)
            .padding(.top, Self.connectorTopInset)
            .padding(.bottom, Self.connectorBottomInset)
            .offset(x: Self.connectorX - Self.connectorWidth / 2)
            .accessibilityHidden(true)
    }

    // MARK: §3 section-empty

    /// §3 `section-empty`: "32 below it one line of `type-body-sm` `color-text-secondary` text
    /// replaces the rows".
    private func emptyLine(_ copy: String) -> some View {
        Text(copy)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: Token.TypeStyle.bodySm.lineHeight, alignment: .leading)
            .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

    private var chartDays: [DualSeriesBarChart.Day] {
        state.chartDates.indices.compactMap { index in
            guard let date = Self.chartDate(state.chartDates[index]) else { return nil }
            return DualSeriesBarChart.Day(
                date: date,
                scheduled: state.chartScheduled[safe: index] ?? 0,
                completed: state.chartCompleted[safe: index] ?? 0
            )
        }
    }

    private var chartWindow: ClosedRange<Date> {
        let start = Self.chartDate(state.chartWindowStart) ?? .distantPast
        let end = Self.chartDate(state.chartWindowEnd) ?? start
        return start...max(start, end)
    }

    /// yyyy-MM-dd in UTC — the reading C-026's build gives its dates, so a day never shifts
    /// across a timezone. Data plumbing, not a side effect.
    private static let chartDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func chartDate(_ text: String) -> Date? {
        chartDateFormatter.date(from: text)
    }

    /// C-065's built `Tone` is `neutral | positive`: its build predates D54's `accent`
    /// (built 2026-09-28, contract 2026-10-03), so "accent" composes as the built `.neutral`,
    /// which renders the highlight plain (C-065 OQ-C-065-001). Its re-build
    /// (`/d2m:component:build C-065`) is reported; a screen re-build then maps "accent".
    private static func tone(_ raw: String?) -> TimelineEventRow.Tone {
        raw == "positive" ? .positive : .neutral
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

    private static func optionalText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    /// C-087 `image`, C-063 slide `image` and C-059 `cover` are `Image?`, resolved by the caller
    /// (R-19 / R-32). The screen reads them from the preview module's image cache — which the
    /// capture case seeds — and loads nothing.
    @MainActor
    private static func cachedImage(_ raw: String?) -> Image? {
        guard let raw = optionalText(raw), let url = URL(string: raw),
              let image = Ui2ImageCache.shared.image(for: url) else { return nil }
        return Image(uiImage: image)
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

extension GroupsDetailScreen.State {

    private static let readStyled =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-read-activity/screenshots/iphone-16-pro-max/capture.03-styled-blocks.png"
    private static let readBlocks =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-read-activity/screenshots/iphone-16-pro-max/capture.01-with-blocks.png"
    private static let video =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-video-activity/screenshots/iphone-16-pro-max/capture.03-youtube-loaded.png"

    /// §3 `populated` — every value is the text on the frozen frame `default` (node 3766:11160;
    /// §1 deviation 1: sample content). Images are stand-ins: the C-087 / C-063 / C-059 / C-037
    /// component previews' own samples. Day-rail series and chart columns are read off the
    /// frame's bar shapes (2026-10-03). The TODAY card is clipped at the frame edge (§1
    /// deviation 6): its visible "27 …" / "1 le…" are completed as "27 lessons" / "1 left".
    static let populated = Self(
        groupName: "Young Professionals",
        coverURL: "file:///Users/lukekeith/www/d2m/var/storage/makeready/2.0/snapshots/C-087-coverimage.png",
        leaderName: "J. Smith",
        createdLabel: "Jun 25, 2026",
        groupDescription: "A group designed for young men who are out of college and are beginning their professional journey",
        visibility: "Private",
        ageRange: "18 - 25",
        maximumMembers: "Unlimited",
        memberDirectoryAccess: "Allowed",
        lessonTitles: ["It is evident"],
        lessonProgramNames: ["Romans in 30 days"],
        lessonMetaLabels: ["Tomorrow"],
        lessonSlideImages: [[readStyled, readBlocks, video]],
        lessonSlideLabels: [["Read: Genesis 1", "Read: Genesis 1", "Video"]],
        dayMonths: ["JUL", "JUL", "JUL", "JUL"],
        dayWeekdays: ["MON", "TUE", "WED", ""],
        dayNumbers: ["24", "25", "26", "27"],
        dayDateStates: ["default", "default", "default", "today"],
        daySeries: [
            [0, 0, 0, 0, 0, 0, 0, 52, 28, 0, 0, 0, 5, 25, 18, 6, 0, 0, 0, 0, 0, 0, 9, 0],
            [0, 0, 20, 0, 0, 0, 12, 6, 18, 6, 0, 0, 5, 14, 24, 14, 6, 0, 0, 0, 0, 12, 6, 0],
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            [0, 0, 20, 0, 0, 0, 12, 6, 18, 6, 0, 0, 5, 14, 24, 14, 6, 0, 0, 0, 0, 12, 6, 0]
        ],
        dayLine1s: ["5 lessons", "3 lessons", "0 lessons", "27 lessons"],
        dayLine2s: ["4 complete", "3 complete", "", "1 left"],
        dayDetailsStates: ["highlighted", "default", "nothing", "default"],
        chartDates: [
            "2026-07-04", "2026-07-05", "2026-07-06", "2026-07-07", "2026-07-08", "2026-07-09",
            "2026-07-10", "2026-07-11", "2026-07-12", "2026-07-13", "2026-07-14", "2026-07-15",
            "2026-07-16", "2026-07-17", "2026-07-18", "2026-07-19", "2026-07-20", "2026-07-21",
            "2026-07-22", "2026-07-23", "2026-07-24", "2026-07-25", "2026-07-26", "2026-07-27",
            "2026-07-28", "2026-07-29", "2026-07-30"
        ],
        chartScheduled: [
            26, 33, 23, 13, 20, 37, 54, 20, 10, 7, 70, 54, 57, 49, 45, 42, 54, 98, 70, 20, 13, 9,
            20, 34, 49, 61, 64
        ],
        chartCompleted: [
            14, 10, 2, 4, 16, 9, 7, 4, 1, 2, 39, 45, 24, 7, 13, 37, 32, 23, 3, 1, 3, 1, 0, 0, 0, 0,
            0
        ],
        chartWindowStart: "2026-07-04",
        chartWindowEnd: "2026-07-30",
        chartToday: "2026-07-27",
        memberNames: ["Barry Allen", "Clark Kent", "Incredible Hulk", "Donald Trump", "Bruce Wayne"],
        memberPhotoURLs: [
            "https://picsum.photos/seed/c037-member/256",
            "https://picsum.photos/seed/c037-member-2/256",
            "https://picsum.photos/seed/c037-member-3/256",
            "https://picsum.photos/seed/c037-member-4/256",
            "https://picsum.photos/seed/c037-member-5/256"
        ],
        memberJoinedLabels: [
            "Joined 5 milliseconds ago",
            "Joined yesterday",
            "Joined July 17, 2024",
            "Joined Jan 5, 2025",
            "Joined Sep 2, 2025"
        ],
        // §4: C-089 "appears only when the group has pending join requests — it is data-driven
        // and not drawn in the frame", so the frame's state carries none.
        requestNames: [],
        requestDates: [],
        programTitles: ["Daily Inspiration", "Romans in 30 days"],
        programDescriptions: [
            "A small dose of wisdom for your daily consumption",
            "A deep dive into the book of Romans and what it means for us in modern America"
        ],
        programEnrolledDates: ["Apr 5, 2026", "Jul 3, 2026"],
        programCoverURLs: [
            "https://picsum.photos/seed/c059/128/176",
            "https://picsum.photos/seed/c059-2/128/176"
        ],
        eventDates: ["Just now", "Yesterday", "Aug 3", "Aug 2", "July 30"],
        eventTexts: [
            "Barry Allen",
            "Clark Kent joined the group",
            "Bubba joined the group",
            "Held event at Starbucks",
            "Updated cover photo"
        ],
        eventHighlights: ["", "Clark Kent", "Bubba joined", "event at Starbucks", ""],
        eventTones: ["neutral", "accent", "accent", "accent", "neutral"]
    )

    /// §3 `section-empty` — "header kept, one `type-body-sm` `color-text-secondary` line below
    /// it", with §3's closed copy; "Activity renders C-023 day cards with C-071 `Nothing` and
    /// C-026's empty state, no text line". Every section empty at once, so every copy line
    /// renders; the group core is `populated`'s.
    static let sectionEmpty = populated.with {
        $0.lessonTitles = []
        $0.lessonProgramNames = []
        $0.lessonMetaLabels = []
        $0.lessonSlideImages = []
        $0.lessonSlideLabels = []
        $0.daySeries = Array(repeating: Array(repeating: 0, count: 24), count: 4)
        $0.dayLine1s = Array(repeating: "0 lessons", count: 4)
        $0.dayLine2s = Array(repeating: "", count: 4)
        $0.dayDetailsStates = Array(repeating: "nothing", count: 4)
        $0.chartDates = []
        $0.chartScheduled = []
        $0.chartCompleted = []
        $0.memberNames = []
        $0.memberPhotoURLs = []
        $0.memberJoinedLabels = []
        $0.requestNames = []
        $0.requestDates = []
        $0.programTitles = []
        $0.programDescriptions = []
        $0.programEnrolledDates = []
        $0.programCoverURLs = []
        $0.eventDates = []
        $0.eventTexts = []
        $0.eventHighlights = []
        $0.eventTones = []
    }

    /// §3 `loading` — "(first open, nothing cached) — header shows the group name from the
    /// groups-home row that pushed it; sections render their section-empty state until data
    /// lands (no skeletons designed)". Nothing else is cached, so the cover and every other
    /// group value are absent ("").
    static let loading = sectionEmpty.with {
        $0.coverURL = ""
        $0.leaderName = ""
        $0.createdLabel = ""
        $0.groupDescription = ""
        $0.visibility = ""
        $0.ageRange = ""
        $0.maximumMembers = ""
        $0.memberDirectoryAccess = ""
    }

    /// §3 `error` — "refresh failure keeps the cached render; no designed error banner (follows
    /// D39)". The cached render is `populated`'s.
    static let error = populated

    private func with(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}

#Preview("populated") {
    GroupsDetailScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("section-empty") {
    GroupsDetailScreen(state: .sectionEmpty)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    GroupsDetailScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("error") {
    GroupsDetailScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
