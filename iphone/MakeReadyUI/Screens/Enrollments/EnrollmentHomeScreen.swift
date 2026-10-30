//
//  EnrollmentHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen enrollment-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/enrollments/{id} ·
//  GET /api/programs/{id} · GET /api/enrollments/{id}/completion-stats ·
//  GET /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities
//  (day-bucketed completion and one assembled enrollment-home payload are API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//  Container inputs (§3, as study-program-home / groups-detail): `showsScheduleEditing`,
//  `showsHeader`, `loading`, `failed` + `onRetry` (all defaulted — existing calls unchanged).
//

import SwiftUI

/// Enrollment home — one enrollment of a study program by a group: the program's identity, the
/// schedule's span, a rail of per-day completion, and the scheduled lessons with their slides
/// (§2). A pushed page (C-040 back chevron). Composed of §4's C-020, C-022, C-023, C-040, C-060,
/// C-063 and C-064; C-021, C-062 and C-079 render only inside those. The cover is C-087
/// CoverImage, which §2 names ("same anatomy as study-program-home §2 items 1–3") but §4's
/// roll-call omits — reported as a spec defect.
///
/// §3 names four states — `loading`, `populated`, `empty-schedule`, `failed` — all reachable
/// through `State` alone. `loading` draws the §4 parts at their contracted geometry with no data
/// (study-program-home's treatment): C-087's placeholder fill, empty title / description, C-022
/// labels over empty values, the span row's cards empty with a zeroed C-064, the day rail and
/// lesson cards omitted; section headers static. `failed` keeps the header and puts one centred
/// muted line in place of the content column (study-program-home's Error); the reload is the
/// host's pull-to-refresh (`.pullToRefresh(onRetry)`), not a button.
struct EnrollmentHomeScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per day card / lesson card, because the preview's props are JSON and the §4
    /// views take flat parameters (R-05).
    struct State {
        // ── Program identity (§2.1) ──
        /// C-087's cover by URL; "" = no cover → C-087's placeholder fill.
        var coverURL: String
        var programName: String
        var programDescription: String
        /// Details grid — Members (count) · Author · Enrolled (`Mon D, YYYY`) · Group leader.
        var memberCount: Int
        var authorName: String
        var enrolledLabel: String
        var leaderName: String
        // ── Schedule (§2.3) — two C-060 cards around one C-064 ──
        var startMonth: String
        var startWeekday: String
        var startDay: String
        /// "" = no end card: §3 `empty-schedule` "renders with start card only".
        var endMonth: String
        var endWeekday: String
        var endDay: String
        var spanMonths: Int
        var spanDays: Int
        // ── Daily progress rail (§2.4) — C-023 `kind=day · percentCircle`, one entry per day ──
        var dayMonths: [String]
        var dayWeekdays: [String]
        var dayNumbers: [String]
        /// C-070 `state` — "default" | "today".
        var dayDateStates: [String]
        /// C-062 `percent`.
        var dayPercents: [Int]
        var dayLine1s: [String]
        var dayLine2s: [String]
        /// C-071 `state` — "lessonDay" on this screen (§2.4 `Lesson day`).
        var dayDetailsStates: [String]
        // ── Lesson cards (§2.5) — C-063, one entry per lesson ──
        var lessonNumbers: [Int]
        var lessonTitles: [String]
        /// C-063 `metaLabel` — the relative date: "Today" / "Tomorrow" / "Mon D".
        var lessonMetaLabels: [String]
        /// C-063 `progress` — `nil` = no bar (`numbered`); today's card only (§2.5).
        var lessonProgress: [Double?]
        /// Per lesson, its slides' screenshots by URL ("" = unresolved → C-079 `empty`).
        var lessonSlideImages: [[String]]
        /// Per lesson, its slides' VoiceOver labels (never rendered).
        var lessonSlideLabels: [[String]]
        // ── Load status (§3) ──
        /// §3 `loading`: the parts render at their contracted geometry with no data.
        var loading: Bool = false
        /// §3 `failed`: the load failed — header kept, the content column is the failure line.
        var failed: Bool = false
    }

    let state: State
    /// §3 container input: false omits the "Edit schedule" text-link and the `calendar` C-021
    /// from the Schedule C-020 (accessory none) while `enrollment-schedule-edit` is undesigned.
    let showsScheduleEditing: Bool
    /// §3 container input: false when the host pins C-040 above its own ScrollView, so the header
    /// is not drawn twice (study-program-home / groups-detail). True keeps the capture render whole.
    let showsHeader: Bool
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}                           // C-040 back → pop to caller
    var onEditSchedule: () -> Void = {}                   // "Edit schedule" → enrollment-schedule-edit
    var onOpenLesson: (Int) -> Void = { _ in }            // C-063 title row tap → OQ-1
    var onOpenActivity: (Int, Int) -> Void = { _, _ in }  // C-061/C-079 slide tap → OQ-1
    var onRetry: () -> Void = {}                          // `failed` reload (host applies `.pullToRefresh`)

    init(
        state: State,
        showsScheduleEditing: Bool = true,
        showsHeader: Bool = true,
        onBack: @escaping () -> Void = {},
        onEditSchedule: @escaping () -> Void = {},
        onOpenLesson: @escaping (Int) -> Void = { _ in },
        onOpenActivity: @escaping (Int, Int) -> Void = { _, _ in },
        onRetry: @escaping () -> Void = {}
    ) {
        self.state = state
        self.showsScheduleEditing = showsScheduleEditing
        self.showsHeader = showsHeader
        self.onBack = onBack
        self.onEditSchedule = onEditSchedule
        self.onOpenLesson = onOpenLesson
        self.onOpenActivity = onOpenActivity
        self.onRetry = onRetry
    }

    // §3 has no UI-only rule on this screen: rail scrolling is scroll physics, and the day-card
    // tap and calendar destination are deferred (OQ-1). So there is no `@SwiftUI.State` here.

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: C-040's static title.
    private static let pageTitle = "Enrollment"
    /// §2.1: the details grid labels, in grid order.
    private static let membersLabel = "Members"
    private static let authorLabel = "Author"
    private static let enrolledLabel = "Enrolled"
    private static let leaderLabel = "Group leader"
    /// §2.3: the section title and its text-link.
    private static let scheduleTitle = "Schedule"
    private static let editScheduleLabel = "Edit schedule"
    /// §3 `failed` (study-program-home's Error copy, for this screen): the one failure line.
    private static let failedCopy = "Unable to load enrollment, pull down to refresh"

    // MARK: - §2 geometry the screen owns

    // GAP — enrollment-home §2: "vertical scroll content (py16 …)" — a vertical 16 with no
    // spacing token naming the role (page-margin is horizontal; the study-program-home precedent).
    private static let contentInset: CGFloat = 16
    // GAP — enrollment-home §2.5: "stacked with no divider: py16" — the lesson list's own
    // vertical 16, no spacing token.
    private static let lessonListInset: CGFloat = 16
    // GAP — enrollment-home §2.1: "2×2 C-022 MetaPair grid (16 gaps)" — no grid spacing token
    // (the study-program-home precedent).
    private static let gridGap: CGFloat = 16
    // GAP — enrollment-home §2.2: "hairline (`color-layout-border`)" — 1pt, no stroke token (the
    // members-profile precedent).
    private static let hairline: CGFloat = 1
    // GAP — enrollment-home §2.3: "span row (16 gap)" — no spacing token for a 16pt row gap.
    private static let spanGap: CGFloat = 16
    // GAP — C-060 §2: "96×88 as designed … 96 at every known call site" — the card fills the
    // width it is given; the host gives 96.
    private static let calendarCardWidth: CGFloat = 96
    // GAP — enrollment-home §2.4: "RailCard … 131×192 (shared 1px borders, −1 overlap as on
    // home)" — a contract width and overlap with no spacing token (the home-dashboard precedent).
    private static let dayCardWidth: CGFloat = 131
    private static let dayCardOverlap: CGFloat = -1

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "C-040 PageHeader (`Two icons` + `showIcons=false`: back + centered title
            // "Enrollment", no right icons)".
            // §3 container input `showsHeader`: false → the host pins it.
            if showsHeader {
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
            }

            if state.failed {
                failedLine
            } else {
                // §2: "vertical scroll content (py16, column gap `space-section-gap` 32)".
                VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
                    programIdentity
                    hairlineRule
                    scheduleSection
                    // §3 `empty-schedule`: "day rail and lesson cards absent"; §3 `loading` omits
                    // them too (no rows yet — study-program-home's treatment).
                    if !state.loading, !state.dayNumbers.isEmpty {
                        dayRail
                    }
                    if !state.loading, !state.lessonTitles.isEmpty {
                        lessonList
                    }
                }
                .padding(.vertical, Self.contentInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                  // the page ground
    }

    /// §3 `failed`: "header intact", and in place of the content column one centred line of
    /// `type-body-sm` `color-text-secondary` (study-program-home's Error). The reload is the
    /// host's pull-to-refresh → `onRetry`, so nothing here is tappable.
    private var failedLine: some View {
        Text(Self.failedCopy)
            .designTextStyle(Token.TypeStyle.bodySm)
            .foregroundStyle(Token.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, Token.Space.pageMargin)
            .padding(.vertical, Token.Space.sectionGap)
    }

    /// §3 `loading`: a data value renders empty, at its part's contracted geometry.
    private func value(_ text: String) -> String { state.loading ? "" : text }

    // MARK: §2.1 Program identity

    /// §2.1: "cover 408×180 `radius-card` (no C-053 StatusBadge) → program title + 8 →
    /// description → 2×2 C-022 MetaPair grid".
    private var programIdentity: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            CoverImage(image: state.loading ? nil : Self.cachedImage(state.coverURL))
                .ui2Element("C-087 CoverImage")
            VStack(alignment: .leading, spacing: Token.Space.elementGap) {
                // §2.1: "program title (`type-title-card`, 1-line ellipsis)".
                Text(value(state.programName))
                    .designTextStyle(Token.TypeStyle.titleCard)
                    .foregroundStyle(Token.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minHeight: Token.TypeStyle.titleCard.lineHeight, alignment: .leading)
                // §2.1: "description (Regular 14/20 `color-white-70`, 1-line ellipsis)" —
                // Regular 14/20 is `type-body-sm`.
                Text(value(state.programDescription))
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.white70)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minHeight: Token.TypeStyle.bodySm.lineHeight, alignment: .leading)
            }
            // §2.1: "Members (count) · Author · Enrolled (`Mon D, YYYY`) · Group leader".
            VStack(alignment: .leading, spacing: Self.gridGap) {
                HStack(alignment: .top, spacing: Self.gridGap) {
                    detailCell(label: Self.membersLabel, value: value("\(state.memberCount)"), ordinal: 1)
                    detailCell(label: Self.authorLabel, value: value(state.authorName), ordinal: 2)
                }
                HStack(alignment: .top, spacing: Self.gridGap) {
                    detailCell(label: Self.enrolledLabel, value: value(state.enrolledLabel), ordinal: 3)
                    detailCell(label: Self.leaderLabel, value: value(state.leaderName), ordinal: 4)
                }
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    private func detailCell(label: String, value: String, ordinal: Int) -> some View {
        MetaPair(value: value, label: label, layout: .stacked, align: .left)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ui2Element(Self.partName("C-022 MetaPair", ordinal: ordinal))
    }

    // MARK: §2.2 Hairline

    /// §2.2: "hairline (`color-layout-border`)", inside the 32pt column gaps.
    private var hairlineRule: some View {
        Rectangle()
            .fill(Token.layoutBorder)
            .frame(maxWidth: .infinity)
            .frame(height: Self.hairline)
            .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.3 Schedule

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {   // §2.3: "→ 32 →"
            // §2.3: "C-020 SectionHeader (`type-section-title`; accessory `text-link+button`:
            // "Edit schedule" text-link + 16 + C-021 GlyphButton `calendar`)" — C-020's
            // `caption` accessory. OQ-C-020-002 (answered): the caption and the glyph are ONE
            // control, so both fire `onAccessoryTap` → "Edit schedule"'s exit; the calendar
            // glyph's own destination (OQ-enrollment-home-1, deferred) has no separate hook.
            // §3 container input `showsScheduleEditing`: false → accessory none.
            SectionHeader(
                title: Self.scheduleTitle,
                accessory: showsScheduleEditing
                    ? .caption(label: Self.editScheduleLabel, glyph: .calendar)
                    : .none,
                onAccessoryTap: onEditSchedule
            )
            .ui2Element("C-020 SectionHeader")
            // §2.3: "span row (16 gap): C-060 (start date) + C-064 (flex) + C-060 (end date)".
            HStack(alignment: .center, spacing: Self.spanGap) {
                CalendarDateCard(
                    month: value(state.startMonth),
                    weekday: value(state.startWeekday),
                    day: value(state.startDay)
                )
                .frame(width: Self.calendarCardWidth)
                .ui2Element("C-060 CalendarDateCard")
                DateSpanIndicator(
                    months: state.loading ? 0 : state.spanMonths,
                    days: state.loading ? 0 : state.spanDays
                )
                .frame(maxWidth: .infinity)
                .ui2Element("C-064 DateSpanIndicator")
                // §3 `empty-schedule`: "start card only + zeroed span" (OQ-8, proposed default).
                // §3 `loading`: the end card keeps its geometry, empty.
                if state.loading || !state.endDay.isEmpty {
                    CalendarDateCard(
                        month: value(state.endMonth),
                        weekday: value(state.endWeekday),
                        day: value(state.endDay)
                    )
                    .frame(width: Self.calendarCardWidth)
                    .ui2Element("C-060 CalendarDateCard 2")
                }
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    // MARK: §2.4 Daily progress rail

    /// §2.4: "full-bleed horizontal scroll of C-023 RailCard `kind=day · percentCircle` 131×192
    /// (shared 1px borders, −1 overlap as on home)". A horizontal carousel keeps its own
    /// ScrollView (D22); §1 deviation 3.
    private var dayRail: some View {
        HorizontalRail {
            HStack(alignment: .top, spacing: Self.dayCardOverlap) {
                ForEach(state.dayNumbers.indices, id: \.self) { index in
                    RailCard(
                        kind: .day,
                        state: .percentCircle,
                        month: state.dayMonths[safe: index] ?? "",
                        weekday: state.dayWeekdays[safe: index] ?? "",
                        day: state.dayNumbers[index],
                        dateState: Self.dateState(state.dayDateStates[safe: index]),
                        percent: state.dayPercents[safe: index] ?? 0,
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

    // MARK: §2.5 Lesson cards

    /// §2.5: "one C-063 LessonCard per listed lesson … stacked with no divider: py16". C-063 is
    /// full-bleed with its own `space-page-margin` inset and moves its py16 to the host, which
    /// stacks cards at `space-section-gap` (§4 C-063 relocation note).
    private var lessonList: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            ForEach(state.lessonTitles.indices, id: \.self) { index in
                LessonCard(
                    header: .numbered(lessonNumber: state.lessonNumbers[safe: index] ?? index + 1),
                    title: state.lessonTitles[index],
                    metaLabel: state.lessonMetaLabels[safe: index] ?? "",
                    // §4 C-063: "`numbered-progress` ×1 (today's card) and `numbered` ×2".
                    progress: state.lessonProgress[safe: index] ?? nil,
                    slides: slides(index),
                    onOpen: { onOpenLesson(index) },
                    onSelectSlide: { slide in onOpenActivity(index, slide) }
                )
                .ui2Element(Self.partName("C-063 LessonCard", ordinal: index + 1))
            }
        }
        .padding(.vertical, Self.lessonListInset)
    }

    private func slides(_ lesson: Int) -> [LessonCard.Slide] {
        let images = state.lessonSlideImages[safe: lesson] ?? []
        let labels = state.lessonSlideLabels[safe: lesson] ?? []
        return images.indices.map { slide in
            LessonCard.Slide(image: Self.cachedImage(images[slide]), label: labels[safe: slide] ?? "")
        }
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

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

    /// C-087 `image` and C-063 slide `image` are `Image?`, resolved by the caller (R-19 / R-32).
    /// The screen reads them from the preview module's image cache — which the capture case
    /// seeds — and loads nothing.
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

extension EnrollmentHomeScreen.State {

    private static let readStyled =
        "file:///Users/lukekeith/www/makeready/iphone/capture/fixtures/preview-images/create-read-activity-03-styled-blocks.png"
    private static let exegesis =
        "file:///Users/lukekeith/www/makeready/iphone/capture/fixtures/preview-images/create-exegesis-activity-04-with-highlights-and-notes.png"
    private static let video =
        "file:///Users/lukekeith/www/makeready/iphone/capture/fixtures/preview-images/create-video-activity-03-youtube-loaded.png"
    private static let readBlocks =
        "file:///Users/lukekeith/www/makeready/iphone/capture/fixtures/preview-images/create-read-activity-01-with-blocks.png"

    /// §3 `populated` — every value is the text on the frozen frame `default` (node 3773:6944;
    /// §1 deviation 1: sample content). The fourth (TODAY, clipped) day's percent is 69, today's
    /// lesson progress (§4 C-063: "`progress` ≈0.69"). Images are the C-087 / C-063 component
    /// previews' own samples; slide counts 4 · 2 · 5 (§1 deviations 3 and 4).
    static let populated = Self(
        coverURL: "file:///Users/lukekeith/www/d2m/var/storage/makeready/2.0/snapshots/C-087-coverimage.png",
        programName: "Daily Inspiration",
        programDescription: "All are welcome for anyone who needs it",
        memberCount: 17,
        authorName: "Jonathan Edwards",
        enrolledLabel: "Jun 25, 2026",
        leaderName: "Tony Stark",
        startMonth: "Jul",
        startWeekday: "Mon",
        startDay: "24",
        endMonth: "Oct",
        endWeekday: "Thu",
        endDay: "15",
        spanMonths: 3,
        spanDays: 3,
        dayMonths: ["JUL", "JUL", "JUL", "AUG"],
        dayWeekdays: ["MON", "MON", "MON", "TUE"],
        dayNumbers: ["24", "27", "30", "1"],
        dayDateStates: ["default", "default", "default", "today"],
        dayPercents: [78, 65, 24, 69],
        dayLine1s: ["1", "2", "3", "4"],
        dayLine2s: ["7:30am", "7:30am", "7:30am", "7:30am"],
        dayDetailsStates: ["lessonDay", "lessonDay", "lessonDay", "lessonDay"],
        lessonNumbers: [4, 5, 6],
        lessonTitles: ["It is evident", "In the beginning", "And the next lesson"],
        lessonMetaLabels: ["Today", "Tomorrow", "Aug 22"],
        lessonProgress: [0.69, nil, nil],
        lessonSlideImages: [
            [readStyled, exegesis, readBlocks, video],
            [readBlocks, video],
            [readBlocks, readStyled, exegesis, video, readBlocks]
        ],
        lessonSlideLabels: [
            ["Read: Romans 1", "Exegesis: Romans 2:1", "Read: Romans 2", "Video"],
            ["Read: Romans 2", "Video"],
            ["Read: Romans 2", "Read: Romans 1", "Exegesis: Romans 2:1", "Video", "Read: Romans 2"]
        ]
    )

    /// §3 `empty-schedule` — "(no scheduled lessons) — schedule section renders with start card
    /// only + zeroed span; day rail and lesson cards absent" (undesigned, OQ-8 proposed default).
    /// Everything else is `populated`'s.
    static let emptySchedule = populated.with {
        $0.endMonth = ""
        $0.endWeekday = ""
        $0.endDay = ""
        $0.spanMonths = 0
        $0.spanDays = 0
        $0.dayMonths = []
        $0.dayWeekdays = []
        $0.dayNumbers = []
        $0.dayDateStates = []
        $0.dayPercents = []
        $0.dayLine1s = []
        $0.dayLine2s = []
        $0.dayDetailsStates = []
        $0.lessonNumbers = []
        $0.lessonTitles = []
        $0.lessonMetaLabels = []
        $0.lessonProgress = []
        $0.lessonSlideImages = []
        $0.lessonSlideLabels = []
    }

    /// §3 `loading` — "the program identity block, the schedule span row, the day rail and the
    /// lesson cards render as skeletons at their contracted geometry; section headers and MetaPair
    /// labels are static". `populated`'s data under `loading = true`: the view renders none of it.
    static let loading = populated.with { $0.loading = true }

    /// §3 `failed` — "a page-level retry in place of the content column, header intact": the one
    /// failure line; the reload is the host's pull-to-refresh → `onRetry`.
    static let failed = populated.with { $0.failed = true }

    private func with(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}

#Preview("populated") {
    EnrollmentHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("empty-schedule") {
    EnrollmentHomeScreen(state: .emptySchedule)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("loading") {
    EnrollmentHomeScreen(state: .loading)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("failed") {
    EnrollmentHomeScreen(state: .failed)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
