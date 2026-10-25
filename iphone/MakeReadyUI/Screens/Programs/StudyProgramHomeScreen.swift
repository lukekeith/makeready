//
//  StudyProgramHomeScreen.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen study-program-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/programs/{id} ·
//  GET /api/programs/{programId}/enrollments · PATCH /api/programs/{id} (via shared-edit-field)
//  (creator.name, leader, Visibility, Age, Maximum members and Member directory access are
//  API-GAPs in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Study program home — the leader's overview of one study program: cover + details grid,
/// the program's settings as inline field rows, its active enrollments and its lessons (§2).
/// A pushed page (C-040 back chevron). Composed only of §4's C-020, C-021, C-022, C-037, C-040,
/// C-042, C-052, C-063, C-087 and C-088; C-043, C-061 and C-079 render only inside those.
///
/// §3 names six states. This build renders `Populated`, `No cover image`, `Empty (no
/// enrollments)` and `Empty (no lessons)`. `Loading` ("skeletons at their contracted
/// geometry") and `Error` ("page-level retry") name no §4 component, so they are reported as
/// spec defects and not improvised here (the home-dashboard / members-profile precedent).
struct StudyProgramHomeScreen: View {

    /// One §3 state's inputs. Every built §3 state is reachable by these alone. Parallel arrays,
    /// one entry per enrollment row / lesson card, because the preview's props are JSON and the
    /// §4 views take flat parameters (R-05).
    struct State {
        // ── Program detail (§2.1) ──
        /// C-087's cover by URL; "" = no `coverImageUrl` → §3 `No cover image`.
        var coverURL: String
        /// Details grid — Created (`Mon D, YYYY`), Author, Group leader.
        var createdLabel: String
        var authorName: String
        var leaderName: String
        /// §1 deviation 5: one live lesson count feeds the details grid and the Lessons row.
        var lessonCount: Int
        // ── Settings (§2.3) — the seven C-042 values ──
        var programName: String
        var programDescription: String
        var visibility: String
        var ageRange: String
        var maximumMembers: String
        var memberDirectoryAccess: String
        // ── Active enrollments (§2.5) — C-037 `Group+tags`, one entry per enrollment ──
        var enrollmentNames: [String]
        /// "" = no photo → C-038's fallback inside C-037.
        var enrollmentPhotoURLs: [String]
        /// C-043 `Single` — the group leader's short name.
        var enrollmentLeaders: [String]
        /// C-043 `Key value` — "N members".
        var enrollmentMemberCounts: [Int]
        // ── Lessons (§2.7) ──
        /// The program's day count: the header MetaPair and the day rail's N.
        var dayCount: Int
        /// The one `Active` C-052 chip.
        var activeDay: Int
        /// C-063, one entry per lesson card.
        var lessonNumbers: [Int]
        var lessonTitles: [String]
        /// C-063 `metaLabel` — the lesson's duration here (§4 C-063 amendment).
        var lessonDurations: [String]
        /// Per lesson, its slides' screenshots by URL ("" = unresolved → C-079 `empty`).
        var lessonSlideImages: [[String]]
        /// Per lesson, its slides' VoiceOver labels (never rendered).
        var lessonSlideLabels: [[String]]
    }

    let state: State
    // §3 interactions — every one leaves the screen, so each is an on<Verb> closure with R-03's
    // no-op default. The screen never decides what an action means.
    var onBack: () -> Void = {}                         // C-040 back → pop to caller
    var onEditField: (String) -> Void = { _ in }        // C-042 tap → shared-edit-field, by label
    var onAddEnrollment: () -> Void = {}                // enrollments `add` → OQ-10
    var onOpenEnrollment: (Int) -> Void = { _ in }      // C-037 tap → enrollment-home
    var onAddLesson: () -> Void = {}                    // lessons `add` → OQ-1
    var onSelectDay: (Int) -> Void = { _ in }           // C-052 tap → select day (OQ-11)
    var onOpenLesson: (Int) -> Void = { _ in }          // C-063 title block tap
    var onOpenActivity: (Int, Int) -> Void = { _, _ in } // C-061 tap → activities-editor

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onEditField: @escaping (String) -> Void = { _ in },
        onAddEnrollment: @escaping () -> Void = {},
        onOpenEnrollment: @escaping (Int) -> Void = { _ in },
        onAddLesson: @escaping () -> Void = {},
        onSelectDay: @escaping (Int) -> Void = { _ in },
        onOpenLesson: @escaping (Int) -> Void = { _ in },
        onOpenActivity: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        self.state = state
        self.onBack = onBack
        self.onEditField = onEditField
        self.onAddEnrollment = onAddEnrollment
        self.onOpenEnrollment = onOpenEnrollment
        self.onAddLesson = onAddLesson
        self.onSelectDay = onSelectDay
        self.onOpenLesson = onOpenLesson
        self.onOpenActivity = onOpenActivity
    }

    // §3 has no UI-only rule on this screen: the day selection is reported through `onSelectDay`
    // (the caller owns `activeDay`, R-01), and rail scrolling is scroll physics. So there is no
    // `@SwiftUI.State` here.

    // MARK: - §2 constants (values that no §3 state changes)

    /// §2: C-040's static title.
    private static let pageTitle = "Study program"
    /// §2.1: the details grid labels, in grid order.
    private static let createdLabel = "Created"
    private static let authorLabel = "Author"
    private static let leaderLabel = "Group leader"
    private static let lessonsLabel = "Lessons"
    /// §2.3: the closed settings row list, in order.
    private static let studyNameLabel = "Study name"
    private static let descriptionLabel = "Description"
    private static let visibilityLabel = "Visibility"
    private static let ageLabel = "Age"
    private static let maximumMembersLabel = "Maximum members"
    private static let memberDirectoryLabel = "Member directory access"
    /// §2.5 / §2.7: section titles and their MetaPair labels.
    private static let enrollmentsTitle = "Active enrollments"
    private static let groupsLabel = "groups"
    private static let daysLabel = "days"
    /// §4 C-043 `Key value` chip label inside C-037.
    private static let membersLabel = "members"

    // MARK: - §2 geometry the screen owns

    // GAP — study-program-home §2.1: "2×2 of C-022 MetaPair, 16pt column/row gaps" — no grid
    // spacing token (the members-profile precedent).
    private static let gridGap: CGFloat = 16
    // GAP — study-program-home §2 item 8: "Bottom content padding 16" — a vertical 16 with no
    // spacing token naming the role (page-margin is horizontal).
    private static let bottomPadding: CGFloat = 16

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the canvas is the device width × the content's full
        // length. The status bar (§1 deviation 2) is the harness's.
        VStack(alignment: .leading, spacing: 0) {
            // §2: "C-040 PageHeader 56pt, style `Two icons` with `showTitle=true` and
            // `showIcons=false`: back chevron left, centered static title "Study program"".
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

            VStack(alignment: .leading, spacing: 0) {
                programDetail
                divider(ordinal: 1)
                settings
                divider(ordinal: 2)
                enrollmentsSection
                divider(ordinal: 3)
                lessonsSection
                Spacer().frame(height: Self.bottomPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                  // §2: `color-layout-background`
    }

    /// §2: "C-088 SectionDivider ×3, 408 wide, 32 above and below (one `space-section-gap` step
    /// each side, owned by the page, not the divider)".
    private func divider(ordinal: Int) -> some View {
        SectionDivider()
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element(Self.partName("C-088 SectionDivider", ordinal: ordinal))
            .padding(.vertical, Token.Space.sectionGap)
    }

    // MARK: §2.1 Program detail

    /// §2.1: "Program detail (408 wide, children gap `space-section-gap` 32)" — cover, then the
    /// details grid.
    private var programDetail: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            // §2.1.1: "C-087 CoverImage … 408×180"; §3 `No cover image` → `nil`.
            CoverImage(image: Self.cachedImage(state.coverURL))
                .ui2Element("C-087 CoverImage")
            // §2.1.2: "2×2 of C-022 MetaPair … Created · Author · Group leader · Lessons".
            VStack(alignment: .leading, spacing: Self.gridGap) {
                HStack(alignment: .top, spacing: Self.gridGap) {
                    detailCell(label: Self.createdLabel, value: state.createdLabel, ordinal: 1)
                    detailCell(label: Self.authorLabel, value: state.authorName, ordinal: 2)
                }
                HStack(alignment: .top, spacing: Self.gridGap) {
                    detailCell(label: Self.leaderLabel, value: state.leaderName, ordinal: 3)
                    detailCell(label: Self.lessonsLabel, value: "\(state.lessonCount)", ordinal: 4)
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

    // MARK: §2.3 Settings

    /// §2.3: "no section header: seven C-042 EditableFieldRow stacked contiguously … no
    /// dividers between rows". Description and Member directory access are the set's
    /// wrapping-value symbol (`multiline`); Age builds as `Default` (OQ-C-042-1).
    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldRow(Self.studyNameLabel, state.programName, ordinal: 1)
            fieldRow(Self.descriptionLabel, state.programDescription, multiline: true, ordinal: 2)
            fieldRow(Self.visibilityLabel, state.visibility, ordinal: 3)
            fieldRow(Self.ageLabel, state.ageRange, ordinal: 4)
            fieldRow(Self.maximumMembersLabel, state.maximumMembers, ordinal: 5)
            fieldRow(Self.memberDirectoryLabel, state.memberDirectoryAccess, multiline: true, ordinal: 6)
            fieldRow(Self.lessonsLabel, "\(state.lessonCount)", ordinal: 7)
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    private func fieldRow(_ label: String, _ value: String, multiline: Bool = false, ordinal: Int) -> some View {
        EditableFieldRow(label: label, value: value, multiline: multiline, onTap: { onEditField(label) })
            .ui2Element(Self.partName("C-042 EditableFieldRow", ordinal: ordinal))
    }

    // MARK: §2.5 Active enrollments

    private var enrollmentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2.5: "C-020 SectionHeader `size=section` … accessory `meta-button` = C-022
            // "3"+"groups" + C-021 `add`"; §3 `Empty (no enrollments)`: "reads "0 groups"".
            SectionHeader(
                title: Self.enrollmentsTitle,
                accessory: .meta(value: "\(state.enrollmentNames.count)", label: Self.groupsLabel, glyph: .add),
                onAccessoryTap: onAddEnrollment
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader")
            // §3 `Empty (no enrollments)`: "the Active-enrollments list is omitted".
            if !state.enrollmentNames.isEmpty {
                Spacer().frame(height: Token.Space.sectionGap)       // §2.5: "→ 32 →"
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(state.enrollmentNames.indices, id: \.self) { index in
                        // §4: C-037 `type=Group+tags` — 64pt group image → name → C-043 chips
                        // (`Single` leader + `Key value` member count, both `align=Left`).
                        ListResultRow(
                            subject: .group,
                            title: state.enrollmentNames[index],
                            detail: .chips,
                            chips: enrollmentChips(index),
                            trailing: .chevron,
                            imageURL: Self.optionalText(state.enrollmentPhotoURLs[safe: index]).flatMap(URL.init(string:)),
                            onTap: { onOpenEnrollment(index) }
                        )
                        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
                    }
                }
                .padding(.horizontal, Token.Space.pageMargin)
            }
        }
    }

    private func enrollmentChips(_ index: Int) -> [ListResultRow.Chip] {
        [
            .init(value: state.enrollmentLeaders[safe: index] ?? ""),
            .init(value: "\(state.enrollmentMemberCounts[safe: index] ?? 0)", label: Self.membersLabel)
        ]
    }

    // MARK: §2.7 Lessons

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2.7: "C-020 SectionHeader `size=section` (title "Lessons"; accessory
            // `meta-button` = C-022 "31"+"days" + C-021 `add`)".
            SectionHeader(
                title: Self.lessonsLabel,
                accessory: .meta(value: "\(state.dayCount)", label: Self.daysLabel, glyph: .add),
                onAccessoryTap: onAddLesson
            )
            .padding(.horizontal, Token.Space.pageMargin)
            .ui2Element("C-020 SectionHeader 2")
            // §3 `Empty (no lessons)`: "day rail and lesson list omitted".
            if !state.lessonTitles.isEmpty {
                Spacer().frame(height: Token.Space.sectionGap)       // §2.7: "→ 32 →"
                dayRail
                Spacer().frame(height: Token.Space.sectionGap)       // §2.7: "→ 32 →"
                lessonList
            }
        }
    }

    /// §2.7: "day rail 408×40: horizontally scrolling row of C-052 DayChip 32×40, gap
    /// `space-chip-gap` (2), exactly one `Active`; N = program day count". A horizontal
    /// carousel keeps its own ScrollView (D22); §1 deviation 3.
    private var dayRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Token.Space.chipGap) {
                ForEach(Array(1...max(state.dayCount, 1)), id: \.self) { day in
                    DayChip(
                        content: .day(day),
                        state: day == state.activeDay ? .active : .default,
                        onTap: { onSelectDay(day) }
                    )
                    .ui2Element(Self.partName("C-052 DayChip", ordinal: day))
                }
            }
            .padding(.horizontal, Token.Space.pageMargin)
        }
        .scrollIndicators(.hidden)
    }

    /// §2.7: "lesson list: three C-063 LessonCard, gap `space-section-gap` (32)". C-063 is
    /// full-bleed with its own `space-page-margin` inset (C-063 §1 deviation 3), so the page
    /// adds no margin here — its rail scrolls under the screen edges (§1 deviation 3).
    private var lessonList: some View {
        VStack(alignment: .leading, spacing: Token.Space.sectionGap) {
            ForEach(state.lessonTitles.indices, id: \.self) { index in
                LessonCard(
                    header: .numbered(lessonNumber: state.lessonNumbers[safe: index] ?? index + 1),
                    title: state.lessonTitles[index],
                    metaLabel: state.lessonDurations[safe: index] ?? "",
                    // §4 C-063 amendment: "Both hosts consume the `plain` variant" — no progress.
                    progress: nil,
                    slides: slides(index),
                    onOpen: { onOpenLesson(index) },
                    onSelectSlide: { slide in onOpenActivity(index, slide) }
                )
                .ui2Element(Self.partName("C-063 LessonCard", ordinal: index + 1))
            }
        }
    }

    private func slides(_ lesson: Int) -> [LessonCard.Slide] {
        let images = state.lessonSlideImages[safe: lesson] ?? []
        let labels = state.lessonSlideLabels[safe: lesson] ?? []
        return images.indices.map { slide in
            LessonCard.Slide(image: Self.cachedImage(images[slide]), label: labels[safe: slide] ?? "")
        }
    }

    // MARK: - Derived (JSON-native props → the §4 views' types)

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

extension StudyProgramHomeScreen.State {

    private static let readStyled =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-read-activity/screenshots/iphone-16-pro-max/capture.03-styled-blocks.png"
    private static let exegesis =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-exegesis-activity/screenshots/iphone-16-pro-max/capture.04-with-highlights-and-notes.png"
    private static let video =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-video-activity/screenshots/iphone-16-pro-max/capture.03-youtube-loaded.png"
    private static let readBlocks =
        "file:///Users/lukekeith/www/makeready/capture/fixtures/iphone/create-read-activity/screenshots/iphone-16-pro-max/capture.01-with-blocks.png"

    /// §3 `Populated` — every value is the text on the frozen frame `default` (node 3833:32194;
    /// §1 deviation 1: sample content). §1 deviation 5: one live lesson count (31) feeds the
    /// details grid and the Lessons row. Images are the C-087 / C-037 / C-063 component
    /// previews' own samples; slide counts 4 · 2 · 5 (§2, §1 deviation 4).
    static let populated = Self(
        coverURL: "file:///Users/lukekeith/www/d2m/var/storage/makeready/2.0/snapshots/C-087-coverimage.png",
        createdLabel: "Apr 3, 2026",
        authorName: "Jonathan Edwards",
        leaderName: "Tony Stark",
        lessonCount: 31,
        programName: "Daily Inspiration",
        programDescription: "All are welcome for anyone who needs it",
        visibility: "Private",
        ageRange: "Any age",
        maximumMembers: "Unlimited",
        memberDirectoryAccess: "Allowed",
        enrollmentNames: ["Young professionals", "Grandparents galore", "The kids"],
        enrollmentPhotoURLs: [
            "https://picsum.photos/seed/c037-group/256",
            "https://picsum.photos/seed/c037-group-2/256",
            "https://picsum.photos/seed/c037-group-3/256"
        ],
        enrollmentLeaders: ["L. Keith", "S. Stickane", "S. Stickane"],
        enrollmentMemberCounts: [3, 25, 3],
        dayCount: 31,
        activeDay: 1,
        lessonNumbers: [1, 2, 3],
        lessonTitles: ["It is evident", "In the beginning", "And the next lesson"],
        lessonDurations: ["3 mins", "5 mins", "15 mins"],
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

    /// §3 `No cover image` — "C-087 keeps its 408×180 box … with the
    /// `color-screenshot-placeholder` fill; nothing collapses". Everything else is `populated`'s.
    static let noCoverImage = populated.with { $0.coverURL = "" }

    /// §3 `Empty (no enrollments)` — "the Active-enrollments list is omitted and its header's
    /// MetaPair reads "0 groups"; the section and its hairlines stay".
    static let emptyNoEnrollments = populated.with {
        $0.enrollmentNames = []
        $0.enrollmentPhotoURLs = []
        $0.enrollmentLeaders = []
        $0.enrollmentMemberCounts = []
    }

    /// §3 `Empty (no lessons)` — "day rail and lesson list omitted, header MetaPair reads the
    /// program's day count". No lessons → the one lesson count reads 0 (§1 deviation 5).
    static let emptyNoLessons = populated.with {
        $0.lessonCount = 0
        $0.lessonNumbers = []
        $0.lessonTitles = []
        $0.lessonDurations = []
        $0.lessonSlideImages = []
        $0.lessonSlideLabels = []
    }

    private func with(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}

#Preview("Populated") {
    StudyProgramHomeScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("No cover image") {
    StudyProgramHomeScreen(state: .noCoverImage)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Empty (no enrollments)") {
    StudyProgramHomeScreen(state: .emptyNoEnrollments)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Empty (no lessons)") {
    StudyProgramHomeScreen(state: .emptyNoLessons)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
