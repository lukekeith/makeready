//
//  CaptureFixture.swift
//  MakeReadyCaptureTests
//
//  JSON fixture model and loader. Discovers fixture files from the capture/ directory.
//

import Foundation
@testable import MakeReady

struct CaptureFixture: Codable {
    let platform: String?
    let view: String
    let output: String
    let title: String?
    let devices: [String]
    let auth: CaptureAuth?
    let state: CaptureState?
    // Page fixtures only: render on a canvas this many points TALL (device
    // width kept) instead of the device height, so a scrolling page's full
    // content is captured in one shot — the page-level analogue of the web
    // runner's default fullPage screenshot. Ignored for component fixtures.
    let captureHeight: Int?
    // Component fixtures only (d2m designer-pick-width, 2026-10-05): lay the
    // component out FILLING this many points of width, its preview's specimen
    // framing (a pinned master width, specimen margins) dropped — the
    // component as a page uses it full-width. Nil: the natural specimen.
    let fill: Int?
    // d2m designer-live-picks D5 (2026-10-06): a DESIGN capture — lay out the bare component (no
    // master width, no specimen margin) and name its exact bounds `__root` in the element map.
    // Only a case that declares its PreviewFrame can; any other renders framed, with no `__root`.
    let bare: Bool?
    // Seconds to let the hosted view run (network-stub loads, .task) before the
    // snapshot is taken. Nil: snapshot immediately.
    let settle: Double?
}

struct CaptureAuth: Codable {
    let isAuthenticated: Bool
    let currentUser: CaptureUser?
}

struct CaptureUser: Codable {
    let id: String
    let name: String
    let email: String
    let picture: String?
}

/// Loosely-typed state container. Each field maps to an AppState entity store.
struct CaptureState: Codable {
    let programs: [[String: AnyCodableValue]]?
    let groups: [CaptureGroup]?
    let enrollments: [CaptureEnrollment]?
    let homeStats: CaptureHomeStats?
    // Group-home views: which group to render, and which slider screen (0 = overview)
    let groupId: String?
    // Member-profile page: member id + seeded display name (profile itself
    // loads over the network, so only the seeded pre-load state can render)
    let memberId: String?
    let seedName: String?
    // Member-requests page: pending join requests seeded into
    // AppState.pendingJoinRequestsByGroupId (group names come from `groups`)
    let joinRequests: [CaptureJoinRequest]?
    let screenIndex: Int?
    // Isolated component views (view == "component.*")
    let component: CaptureComponent?
    // Activity-editor views
    let activity: CaptureActivity?
    let programId: String?
    let lessonId: String?
    let videoUrl: String?
    let videoThumbnailUrl: String?
    // Program-home views: seed lessons directly
    let lessons: [CaptureLesson]?
    // Program-home: which TabSlider tab to open (0 Lessons / 1 Enrollments /
    // 2 Analytics) — flows into ProgramHomePage(initialTab:)
    let selectedTab: Int?
    // Program-home Analytics tab: payload seeded into
    // AppState.programAnalyticsById[programId]. Reuses the production
    // Codable, so the fixture JSON is exactly the wrapper response shape.
    let analytics: ProgramAnalytics?
    // Program metadata (name, days) for pages that show the full program header
    let programName: String?
    let programDays: Int?
    // Path to a local image file (relative to capture root) to seed as the program cover image
    let programCoverImagePath: String?
    // Enrollment flow (pages.enrollment-flow): which entry presents it —
    // "group" (preselected group → Select Program panel) or "program"
    // (preselected program → Select Group panel). Lists come from
    // `groups` / `programs`; the wizard's step index is private @State, so
    // only panel 0 is seedable.
    let enrollmentFlowEntry: String?
    // Calendar screen: lesson/event entries to seed into AppState.calendarEvents
    let calendarEvents: [CaptureCalendarEntry]?
    // Media library screen: items to seed into AppState.mediaLibrary
    let media: [CaptureMediaItem]?
    // Search screen: mock the network so recents/results render (test-target
    // MockURLProtocol). `searchRecents` mocks GET /api/activities from seeded
    // programs/groups; `searchQuery` mocks GET /api/search + drives the query.
    let searchRecents: Bool?
    let searchQuery: String?
    // pages.member-request-respond — prop seed for the topLevel RAW modal.
    let respond: CaptureRespondSeed?
    // pages.change-membership — prop seed (panel is private @State: only the
    // MAIN panel is capturable; confirm/transfer variants are web-only).
    let changeMembership: CaptureChangeMembershipSeed?
    // pages.study-invite — mocks GET /api/lesson-schedules/:id/invite (the page
    // loads everything from the network; the QR is built in the stub).
    let studyInvite: CaptureStudyInviteSeed?
}

struct CaptureStudyInviteSeed: Codable {
    let scheduleId: String
    let code: String
    let inviteUrl: String
    let dayNumber: Int
    let scheduledDate: String?
    let passageReference: String?
    let programName: String
    let programDays: Int
    let groupName: String
}

// MARK: - topLevel RAW modal seeds

struct CaptureRespondSeed: Codable {
    let memberName: String
    let groupName: String
    /// Unix epoch seconds; formatted by the modal itself (fullMonthDayYear +
    /// time12Hour, LOCAL tz). Defaults to the fixed capture base when omitted.
    let requestedAt: Double?
}

struct CaptureChangeMembershipSeed: Codable {
    let memberName: String
    let groupName: String
    /// "joined" | "removed"
    let mode: String?
    let candidates: [CaptureTransferCandidate]?
}

struct CaptureTransferCandidate: Codable {
    let id: String
    let name: String
    let coverImageUrl: String?
    let memberCount: Int
    let activeStudies: Int
}

/// A calendar entry for the Calendar SCREEN capture (seeded into
/// AppState.calendarEvents, keyed by `date` "yyyy-MM-dd"). Distinct from
/// CaptureCalendarEvent, which is the calendar COMPONENT fixture shape.
struct CaptureCalendarEntry: Codable {
    let id: String
    let date: String        // "yyyy-MM-dd"
    let title: String
    let studyName: String?
}

/// A media-library item for the Media screen capture (seeded into
/// AppState.mediaLibrary). `type` is a raw MediaType-ish string.
struct CaptureMediaItem: Codable {
    let id: String
    let title: String
    let type: String?
}

// MARK: - Component capture model

/// Props for an isolated component render (view == "component.*"). Superset of
/// the fields any single comparable card needs; each ViewRegistry case reads the
/// subset it cares about. All fields are optional so the generic iphone-card
/// adapter can hand a variant's `shared` block straight through. Grow this as new
/// cards need new fields — every field is additive and ignored by cases that
/// don't read it.
struct CaptureComponent: Codable {
    let name: String?                 // e.g. "CardStudy"
    let title: String?
    let subtitle: String?
    let description: String?
    let type: String?
    let status: String?               // confirmed | pending | new | selected
    let coverUrl: String?
    let iconSystemName: String?
    let imageStyle: CaptureImageStyle? // photo | icon | dateDisplay | timeDisplay
    let metadata: [CaptureDataItem]?
    // RETYPED 2026-09-15 (/d2m-component-build C-028), by the same reasoning and in the same
    // shape as `size`, `date` and `percent` below. This was `Bool?`, the 1.0 GroupCard's
    // brand-overlay flag (and C-047 RadioOptionRow's `selected: Bool`). C-028 InlineDropdown
    // §4's second prop is ALSO named `selected` and is a **String** — the option that is
    // current — and preview-build.md §3 rule 3 forbids bending a contract's prop name to fit
    // an existing field. So the field decodes both shapes: the 1.0 readers and C-047 ask for
    // `.boolValue`; C-028 asks for `.stringValue`.
    let selected: CaptureBoolOrString? // GroupCard: brand overlay + check; C-047 — OR C-028's current option
    // RETYPED 2026-09-11 (/ui2-component-build C-038), by the same reasoning and in the same
    // shape as `date` and `percent` below. This was `String?`, the 1.0 card size "Row"|"Mini".
    // C-038 §4's fourth prop is ALSO named `size` and is a **CGFloat diameter**, and
    // preview-build.md §3 rule 3 forbids bending a contract's prop name to fit an existing
    // field — so the field decodes both shapes. The 1.0 readers ask for `.stringValue`;
    // C-038 asks for `.doubleValue`.
    let size: CaptureDoubleOrString?  // "Row" | "Mini" (1.0 cards) — OR a diameter (C-038) — OR C-048 "md" | "lg"
    let pendingRequestCount: Int?     // GroupCard avatar badge
    // ── generic scalars used across assorted cards ──
    // C-052 DayChip (2026-09-11) reuses this field: its §4 prop is ALSO named `day` and is
    // ALSO an Int (the ordinal program day), so rule 3's second bound is satisfied by the
    // contract's own name — no addition, no rename.
    // RETYPED 2026-09-20 (/d2m-component-build C-025 — that row merged into C-023 RailCard `kind=day` 2026-09-21), by the same reasoning and in the same
    // shape as `size`, `date` and `percent` below. This was `Int?`. C-025 §4 (now C-023 §4 `kind=day`; re-specced
    // 2026-09-20, flat props) has a `day` that is a **String** ("24") → C-070 `day`, and
    // rule 3's second bound forbids bending a contract's prop name to fit an existing field —
    // so the field decodes both shapes. The 1.0 readers and C-052 ask for `.intValue`;
    // C-023 `kind=day` (ex-C-025) asks for `.stringValue`.
    let day: CaptureIntOrString?      // 1.0 cards / C-052 — an Int; C-023 kind=day (ex-C-025) — C-070's day string
    let month: String?
    let time: String?
    let period: String?
    let progress: Double?             // 0…1 progress bars
    let badge: String?                // status badge text
    // RETYPED 2026-09-10 (/ui2-component-build C-025 — that row merged into C-023 2026-09-21), by the same reasoning and in the same
    // shape as `days` below. This was `String?`, a 1.0 display/ISO date. C-025 §4's second
    // prop is ALSO named `date` and is C-070 DateBlock's prop object, and preview-build.md §3
    // rule 3 forbids bending a contract's prop name to fit an existing field — so the field
    // decodes both shapes. The 1.0 readers ask for `.string`; C-023 `kind=day` (ex-C-025) asks for `.block`.
    let date: CaptureDateOrBlock?     // ISO or display date string, OR C-070's props
    let dateRange: String?
    let memberCount: Int?
    let duration: String?
    let label: String?
    let value: String?
    let imageUrl: String?
    let initials: String?
    let isReleased: Bool?
    let isConfigured: Bool?
    let estimatedMinutes: Int?
    let count: Int?
    let dayNumber: Int?
    let passage: String?
    let text: String?
    let authorName: String?
    let timeAgo: String?
    let groupName: String?
    let activities: [CaptureLessonActivity]?   // CardLesson / CardEnrolled
    let sections: [CaptureSectionProgress]?    // CardLesson progress mode
    let mode: String?                          // CardLesson: planning|lesson|progress|lessonList
    let lessonStatus: String?                  // complete | next | upcoming:<text>
    let images: [String]?                      // GroupPostCard image URLs
    // ── card-specific extras (added as cards were onboarded) ──
    let isPublished: Bool?                     // CardStudySelectable / CardProgramFull badge
    let firstName: String?                     // CardMember / CardContact / CardSearchResult
    let lastName: String?
    let avatarUrl: String?                     // CardMember / CardContact avatar
    let groups: [String]?                      // CardMember group-badge row
    let variant: String?                       // CardMember / CardContact: "invite" → trailing button
    let available: Bool?                       // CardActivityType dimmed/disabled state
    let category: String?                      // CardActivity: AUTH | JOIN | ACCESS
    let createdAt: String?                     // ISO8601 — CardActivity / CardProgramFull
    let studyTitle: String?                    // CardEnrolled
    let startDate: String?                     // ISO8601 — CardEnrolled / EnrollmentCard
    let endDate: String?
    let lessonsLeft: Int?                      // CardEnrolled
    let studyImageURL: String?                 // CardEnrolled
    let groupImageURL: String?
    let tags: [String]?                        // CardProgramFull
    // RETYPED 2026-09-08 (owner ruling, /ui2-component-build C-026). This was `Int?`, a
    // 1.0 duration. C-026 §4's first prop is ALSO named `days` and is a day timeline, and
    // preview-build.md §3 rule 3 forbids renaming a contract's prop to dodge a collision —
    // so the field decodes both shapes, exactly as `activeTab` does for Int-or-String. The
    // 1.0 readers ask for `.duration`; C-026 asks for `.timeline`.
    let days: CaptureDays?                     // CardProgramFull / EnrollmentCard / C-026
    let enrollmentCount: Int?                  // CardProgramFull
    let programName: String?                   // UpcomingLessonCard
    let isCompleted: Bool?                     // EnrollmentCard
    let durationSeconds: Int?                  // CardMediaFull (MediaLibraryItem.duration)
    let isMember: Bool?                        // CardSearchResult
    let isVideo: Bool?                         // CardSearchResult / CardLessonActivity
    let showChevron: Bool?                     // CardSearchResult
    let highlightQuery: String?               // CardSearchResult
    let createdSecondsAgo: Int?               // GroupPostCard deterministic timestamp

    let icon: String?                          // Button: SF Symbol (ActionButton / BoxButton)
    let iconPosition: String?                  // BoxButton: left | right | none
    let style: String?                         // BoxButton: solid | border
    let fullWidth: Bool?                       // BoxButton: stretch to container width
    // ── Calendar / Content / Loading ──
    let showViewModes: Bool?
    let eventColors: [String]?
    let isCurrentMonth: Bool?
    let isToday: Bool?
    let isSelected: Bool?
    let events: [CaptureCalendarEvent]?
    let selectedDate: String?
    let plainText: String?
    let highlights: [CaptureHighlight]?
    let selections: [CaptureHighlight]?
    /// An IN-PROGRESS selection — the span under the user's finger before
    /// release. Rendered at the contract's live colour (`#F4FF76 @ 0.55`,
    /// 03 §5) rather than the saved `@ 0.35`, so the two are visually
    /// distinguishable in a snapshot. Added by highlighting phase 6.8: the
    /// live colour is a contract value, and until now no fixture could express
    /// one, because the component cases hardcoded `.constant(nil)`.
    let liveSelection: CaptureHighlight?
    let isSelectionEnabled: Bool?
    let usePreviewHighlightStyle: Bool?
    let isScripture: Bool?
    let fontSize: Int?
    let shape: String?
    let width: Int?
    let height: Int?
    let cornerRadius: Int?
    let rows: [CaptureShimmerRow]?

    // ── Cards / Domain / Group / Feedback ──
    let slideButtons: [CaptureSlideButton]?
    let isSwipeEnabled: Bool?
    let programImageUrl: String?
    let programDays: Int?
    let message: String?
    let buttonLabel: String?
    let isProcessing: Bool?
    let processingMessage: String?
    let hasRetry: Bool?
    let option: String?

    // ── Chart ──
    let dataPoints: [CaptureChartPoint]?
    let heatMapPoints: [CaptureHeatMapPoint]?
    let trendLines: [CaptureTrendLine]?
    let innerRadiusRatio: Double?
    let showCenterLabel: Bool?
    let centerLabelText: String?
    let centerLabelSubtext: String?
    let showValues: Bool?
    let barHeight: Double?
    let chartHeight: Double?
    let showDayLabels: Bool?
    let colorScale: [String]?
    let timeScale: String?
    let yAxisScale: String?
    let showArea: Bool?
    let interactive: Bool?
    let animated: Bool?
    let interpolationMethod: String?

    // ── Display ──
    let letters: [String]?
    let buttons: [CaptureDialogButton]?
    let items: [CaptureListItem]?
    let valueType: String?
    let suffix: String?
    let kpiValue: Double?
    let trend: CaptureKpiTrend?
    let iconColor: String?
    let age: Int?
    let joinDate: String?
    // RETYPED 2026-10-24 (/d2m:component:build C-127), in the same either-shape pattern as
    // `date` above. This was `[Int]?` (0 = Sun … 6 = Sat — WeekdayIndicator, C-128). C-127 §4's
    // prop is ALSO named `enabledDays` and takes weekday NAMES ("monday"), and the build rules
    // forbid bending a contract's prop name to fit an existing field — so the field decodes both
    // shapes into the same 0…6 indices. It is a Sequence of Int and array-literal-expressible, so
    // the existing `Set(c.enabledDays ?? [])` readers compile unchanged.
    let enabledDays: CaptureWeekdays?

    // ── Input ──
    let minAge: String?
    let maxAge: String?
    let color: String?
    let overlayOpacity: Double?
    let programDescription: String?
    let existingImageUrl: String?
    let fieldRows: [String]?
    let selectedSize: String?
    let inputType: String?
    let placeholder: String?
    let floatingLabel: String?
    let markdown: String?
    let autoGrow: Bool?
    // RETYPED 2026-09-30 (/d2m-component-build C-036), by the same reasoning and in the same
    // shape as `selected`, `size`, `day`, `date` and `days`. This was `[String]?` (MenuInput,
    // C-028 InlineDropdown, the edit-field pickers). C-036 FilterMenuOverlay §4's first prop
    // is ALSO named `options` and is `[FilterMenuOverlay.Option]` — objects of id/label/glyph —
    // and the rule forbids bending a contract's prop name to fit an existing field. So the
    // field decodes both shapes: the existing readers ask for `.strings`; C-036 for `.items`.
    let options: CaptureStringsOrOptions?
    let optionsWithDescriptions: [CaptureMenuOption]?
    let selectedOption: String?
    let html: String?
    let outputFormat: String?
    let isActive: Bool?
    let searchText: String?
    let isOn: Bool?

    // ── Layout / Overlays / Video ──
    let searchItems: [CaptureSearchListItem]?
    let showAlphabetScrubber: Bool?
    let tableSections: [CaptureTableSection]?
    let sizePx: Int?
    let currentSource: String?

    // ── Navigation ──
    let menuId: String?
    let studyName: String?
    let enrollmentId: String?
    let scheduledDate: String?
    let showEditEnrollment: Bool?
    let showAddLesson: Bool?
    let avatarURL: String?
    let activeTab: CaptureIntOrString?
    let tabs: [String]?
    let selectedIndex: Int?
    let selectedIds: [String]?
    let showClearAll: Bool?
    let factory: String?
    let leftIcon: String?
    let leftLink: String?
    let rightIcon: String?
    let rightLink: String?
    let rightIcons: [CaptureRightIcon]?
    let backText: String?

    // ── BlockStyleEditor (connected component) ──
    let blockTitle: String?
    let availableThemes: [CaptureThemeOption]?
    // ── UserMenu (connected component) ──
    let organizations: [CaptureOrg]?

    // ── UI 2.0 preview (docs/ui2/preview-build.md §3 rule 3, amended 2026-09-06) ──
    // Additive optionals only. `text` and `placeholder` already exist above and carry the
    // contract's own prop names, so C-045 reuses them rather than adding duplicates.
    let lines: String?                         // C-045 TextInput — "single" | "multi"
    let focused: Bool?                         // C-045 TextInput / C-034 SearchField — border + caret
    let showTitle: Bool?                       // C-040 PageHeader — gates the centred title
    let showIcons: Bool?                       // C-040 PageHeader — gates the trailing group (twoIcons only)
    // C-024 SparkBarChart. `series` is the contract's own prop name and there is no existing
    // field it could be bent into (rule 3's second bound); the 1.0 chart block above spells
    // `dataPoints`/`trendLines`, which are different shapes for different cases.
    let series: [Double]?                      // C-024 — the single data series
    let targetBars: Int?                       // C-024 — bucket-aggregate down to N bars (nil = 1/point)
    let align: String?                         // C-024 — "top" | "center" | "bottom"
    let widthFill: String?                     // C-024 — "bars" | "gaps"
    let showAverage: Bool?                     // C-024 — dashed average line
    let averageLabel: String?                  // C-024 — label at the average line (nil = line only)
    let averageLabelSide: String?              // C-024 — "left" | "right"
    // C-021 GlyphButton. The contract's nine glyph names are also the asset-catalog
    // names, so this one string is the whole prop (see UI2Preview/GlyphButton.swift).
    let glyph: String?                         // C-021 — export|settings|back|add|send|arrow-forward|three-dots|search|calendar
    // C-026 DualSeriesBarChart. `days` is above (retyped, see the note there); these two are
    // additive. `today` is not a §4 prop — C-026 §3 derives `state` from whether today falls in
    // the window, so the capture has to pin "now" or the render drifts by the day it was taken
    // (UI2Preview/DualSeriesBarChart.swift documents it; raised for an OQ-PB row).
    let window: CaptureUI2DateWindow?          // C-026 — visible slice { start, end }
    // RETYPED 2026-10-21 (/d2m:component:build C-113), by the same reasoning and in the same
    // shape as `selected` above. This was `String?`, C-026's capture seam for "now". C-113
    // MonthDayCell §4's second prop is ALSO named `today` and is a **Bool**, and a contract's
    // prop name is never bent to fit an existing field — so the field decodes both shapes:
    // C-026 asks for `.stringValue`; C-113 asks for `.boolValue`.
    let today: CaptureBoolOrString?            // C-026 — capture seam, ISO yyyy-MM-dd (UTC) — OR C-113's Bool
    // C-040 PageHeader glyph slots (owner ruling 2026-09-07, OQ-C-040-6): both take any
    // C-021 glyph name, so they carry the same vocabulary as `glyph` above.
    let leadingGlyph: String?                  // C-040 — the leading slot's glyph
    let rightButtons: [String]?                // C-040 — trailing glyphs, in order
    // C-029 RadialDayClock. All four are the contract's own §4 prop names and none of them
    // could be bent into an existing field (rule 3's second bound): `series` above is C-024's
    // single data series, a different shape for a different contract, and there is no existing
    // centre-value trio at all.
    let hourValues: [Double]?                  // C-029 — activity concentration per hour (24)
    let centerValue: String?                   // C-029 — centre number
    let centerUnit: String?                    // C-029 — unit beside the number
    let centerCaption: String?                 // C-029 — caption under the value
    // C-030 TimeActivityChart. Both are the contract's own §4 prop names. `bins` could not be
    // bent into `series` (C-024's) or `dataPoints` (1.0's) without breaking rule 3's second
    // bound, and no existing field carries a value+unit pair list.
    let bins: [Double]?                        // C-030 — activity intensity per time slice
    let tickLabels: [CaptureUI2TickLabel]?     // C-030 — the 4 justified C-022 MetaPairs
    // C-019 TopNav / C-069 NavTabButton (C-019 §4 — one prop table for both units). `tabs`
    // and `label` already exist above under the contract's own names, so they are reused
    // rather than duplicated. `presentation` is also what the ViewRegistry case dispatches
    // on: it is C-069's alone, so its presence says which of the two units a state renders.
    let selectedTab: String?                   // C-019 — exactly one; sets C-069 active
    let expansion: Double?                     // C-019 — the morph 0…1 (0 and 1 are designed)
    let scrollOffset: Double?                  // C-019 — one shared offset, in pt
    let presentation: String?                  // C-069 — "collapsed" | "expanded"
    let active: Bool?                          // C-069 — the color-only active delta
    // C-069 `addAction?` is an ACTION, and an action has no render effect — but its presence
    // is what C-019 §2b gates the add slot on, so the fixture carries presence as a boolean
    // under the contract's own prop name rather than bending it into some other field.
    let addAction: Bool?                       // C-069 — does this card show its add slot
    // C-042 EditableFieldRow. `label`, `value` and `tags` already exist above under the
    // contract's own prop names, so C-042 reuses them rather than adding duplicates. These
    // two are additive: `indicator` is a (text, tone) pair and a tuple is not Codable, and
    // `multiline` has no existing field it could be bent into (rule 3's second bound —
    // `lines` above is C-045's "single"|"multi" string, a different prop on a different
    // contract).
    let indicator: CaptureUI2Indicator?        // C-042 — trailing indicator { text, tone }
    let multiline: Bool?                       // C-042 — value wraps instead of ellipsizing
    // C-066 ActionMenuOverlay. `glyph` and `label` above already carry C-067 ActionMenuRow's
    // own prop names, so the row state reuses them; only the container's list is additive.
    // It could not be bent into any existing field (rule 3's second bound): `items`,
    // `buttons` and `options` above are 1.0 shapes for 1.0 cases.
    let actions: [CaptureUI2Action]?           // C-066 — the closed action list
    // C-023 RailCard `kind=day` (ex-C-025 DayActivityCard, merged 2026-09-21). `series` above is C-024 SparkBarChart's own prop and C-023 §4
    // delegates to it under the same name, so it is reused rather than duplicated. `date` is
    // retyped above (see the note there). These three are additive: no existing field carries
    // a card state, a completion percentage, or a two-line value pair.
    // C-053 StatusBadge reuses this field: its §4 prop is ALSO named `state` and is also a
    // string, so rule 3's second bound is satisfied by the contract's own name — no
    // addition, no rename.
    // C-052 DayChip reuses it too: its §4 prop is ALSO named `state` and is also a string.
    let state: String?                         // C-023 kind=day (ex-C-025) — "standard" | "transparent" | "percentCircle"
                                               // C-053 — "published" | "draft"
                                               // C-052 — "Default" | "Active"
    // RETYPED 2026-09-10 (/ui2-component-build C-033), by the same reasoning and in the same
    // shape as `days` and `date` above. This was `Int?`, C-025 §4's (now C-023 §4, `kind=day`) `percent: Int?`. C-033 §4's
    // `percent` is ALSO a prop of that name and is a display STRING ("55%") — OQ-C-033-5 is
    // open on whether that is the component's contract or the sample's — and preview-build.md
    // §3 rule 3 forbids bending a contract's prop name to fit an existing field. So the field
    // decodes both shapes: C-023 `kind=day` (ex-C-025) asks for `.intValue`, C-033 for `.stringValue`.
    let percent: CaptureIntOrString?           // C-023 kind=day (ex-C-025) — → C-062 PercentDisc; C-033 — the completion number
    let details: CaptureUI2ValuePair?          // C-023 kind=day (ex-C-025, legacy nested shape) — → C-071 ValuePair's props
    // C-033 GroupFollowCard. `style`, `color`, `title`, `label` and `progress` already exist
    // above under the contract's own prop names, so C-033 reuses them rather than adding
    // duplicates; `percent` is retyped just above. These three are additive and none could be
    // bent into an existing field (rule 3's second bound): `avatarUrl`/`imageUrl` are 1.0
    // names for 1.0 cases, and `memberCount: Int?` is neither this name nor this type.
    let photoURL: String?                      // C-033 — → C-038 Avatar at 64
    let members: String?                       // C-033 — the members-row number, a display string
    let showLink: Bool?                        // C-033 — `noBar` only, gates C-072 LinkStatusGlyph
    // C-038 Avatar. `state`, `initials` and `size` already exist above under the contract's own
    // prop names, so they are reused — `size` is retyped in place (see the note there) rather
    // than duplicated, and `state` is reused exactly as the retired C-025 case used it (now C-023 `kind=day`). `imageURL` IS additive:
    // the struct's existing field is spelled `imageUrl` (lowercase u), a 1.0 name, and
    // preview-build.md §3 rule 3's second bound forbids bending C-038 §4's `imageURL` into it.
    let imageURL: String?                      // C-038 — the photo (NOT 1.0's `imageUrl`)
    // C-046 FieldGroup. `label`, `text` and `placeholder` already exist above under the
    // contract's own prop names (§4's `(input content)` row delegates the latter two to C-045
    // verbatim), so C-046 reuses them rather than adding duplicates. Only `field` is additive:
    // no existing field carries that name, and bending it onto `lines` — C-045's own
    // "single"|"multi" — would rename a contract's prop into another contract's vocabulary,
    // which rule 3's second bound forbids.
    let field: String?                         // C-046 — "Text" | "Multiline Text" | "Phone"
    // C-022 MetaPair. `value`, `label` and `align` already exist above under the contract's own
    // prop names — `align` is C-024's field, the same name and the same `String?`, so reusing it
    // satisfies rule 3's second bound exactly as C-053 reuses `state` (the value sets differ;
    // each case parses its own). Only `layout` is additive: no existing field carries that name,
    // and bending it onto `lines` — C-045's "single"|"multi" — would rename a contract's prop
    // into another contract's vocabulary.
    let layout: String?                        // C-022 — "inline" | "stacked"
                                               // C-022 also reads `align` — "Left" | "Right"
    let valueFirst: Bool?                      // C-022 — stacked only; value above label
    // C-057 PercentBar. `progress` (Double?) and `size` (CaptureDoubleOrString?, read as
    // `.stringValue`) already exist above under this contract's own prop names and types, so
    // they are reused. The rest are additive: `align` above is C-024/C-022's, and C-057's prop
    // is spelled `aligned` — bending one onto the other would rename a contract's prop into
    // another contract's vocabulary, which rule 3's second bound forbids. `fillStyle`,
    // `fillColor`, `thresholds` and `fillAnimation` come from note 2026-09-12T02:28:29.097Z and
    // no existing field carries any of those names.
    let aligned: String?                       // C-057 — "Right" | "Left"
    let fillStyle: String?                     // C-057 — "solid" | "gradient"
    let fillColor: String?                     // C-057 — a tokens.md colour row name; nil = derive from thresholds
    let thresholds: CaptureUI2Thresholds?      // C-057 — the red/yellow/green ramp stops
    let fillAnimation: CaptureUI2FillAnimation? // C-057 — fill 0 → value; omitted so captures are still
    // C-035 FilterChip adds NOTHING. All three of its render-bearing §4 props — `type`,
    // `active` and `label` — already exist above under the contract's own names and types
    // (`type: String?` and `label: String?` in the 1.0 block, `active: Bool?` from C-069), so
    // rule 3's second bound is satisfied by reuse and no field is added. `type` takes
    // "Menu" | "Button" here; `active` is C-069's same-named boolean read by a second
    // contract, exactly as C-052/C-053 read `state`.
    // C-064 DateSpanIndicator adds ONE field. Its §4 second prop is ALSO named `days` and is
    // ALSO an Int, and `days` above is already the polymorphic `CaptureDays` — whose `Int`
    // branch is exactly this shape — so C-064 reads `.duration` and adds nothing for it, the
    // way C-026 reads `.timeline` from the same field. `months` has no existing field at all
    // and could not be bent into one (rule 3's second bound): `month: String?` in the 1.0 block
    // is C-070's display month name, a different prop of a different type on a different
    // contract.
    let months: Int?                           // C-064 — whole months in the span
                                               // C-064 also reads `days` — via `.duration`
    // C-047 RadioOptionRow adds NOTHING. All three of its render-bearing §4 props — `title`,
    // `description` and `selected` — already exist above under the contract's own names and
    // types (`title: String?`, `description: String?` in the 1.0 block, `selected: Bool?`
    // from GroupCard), so rule 3's second bound is satisfied by reuse and no field is added.
    // `onSelect` is an action with no render effect and is not carried by the fixture.
    // C-048 PageActionButton adds TWO fields. `label` already exists above under the contract's
    // own prop name and type, so it is reused. `role` and `isEnabled` are additive and neither
    // could be bent into an existing field (rule 3's second bound): `type`/`style`/`state` above
    // are other contracts' vocabularies for other value sets, and `active`/`available`/`selected`
    // are C-069's, C-013's and GroupCard's booleans meaning different things. `action` is an
    // action with no render effect and is not carried by the fixture.
    let role: String?                          // C-048 — "affirmative" | "destructive" | "prominent" | "secondary" | "accent"
    let isEnabled: Bool?                       // C-048 — false renders the Muted look
    // C-048's 2026-10-20 glyph rows add ONE field. `glyph` (C-021's String), `layout` (C-022's
    // String) and `enabled` (C-108's Bool) already exist above under the contract's own prop
    // names and types and are reused; `layout` takes "spread" | "centered" here. `glyphPosition`
    // has no existing field to reuse.
    let glyphPosition: String?                 // C-048 — "leading" | "trailing"
    // C-049 LinkButton adds NOTHING. All three of its render-bearing §4 props — `label`,
    // `style` and `isEnabled` — already exist above under the contract's own names and types
    // (`label: String?` and `style: String?` in the 1.0 block, `isEnabled: Bool?` from C-048),
    // so rule 3's second bound is satisfied by reuse and no field is added. `style` takes
    // "default" | "muted" here, the way C-033 reads its own set from the same field. `onTap`
    // is an action with no render effect and is not carried by the fixture.
    // C-077 TrendIndicator adds ONE field. `label` already exists above under the contract's
    // own prop name and type, so it is reused. `direction` has no existing field and could not
    // be bent into one (rule 3's second bound): `type`/`style`/`state`/`role` above are other
    // contracts' vocabularies for other value sets, and C-075's `direction` (left | right) is
    // never carried by a fixture — C-064 builds it inline. Takes "up" | "down" | "neutral".
    let direction: String?                     // C-077 — "up" | "down" | "neutral"
    // C-077 re-build 2026-09-17: the owner's note of 04:23 split colour off `direction` into a
    // third prop. No existing field carries a positive|negative|neutral valence, so it is added
    // under the contract's own name (rule 3's second bound).
    let polarity: String?                      // C-077 — "positive" | "negative" | "neutral"
    // C-051 AISuggestionsBlock adds TWO fields. `state` already exists above under the
    // contract's own prop name and type (a string, read as the nested enum's raw value the way
    // C-052/C-053 read theirs), so it is reused. `promptCopy` and `suggestions` are additive:
    // no existing field carries either name, and bending them onto `text`/`description` or
    // `items`/`options`/`tags` — other contracts' and 1.0's vocabularies — would rename a
    // contract's prop, which rule 3's second bound forbids. `onGenerate` and `onPick` are
    // actions with no render effect and are not carried by the fixture.
    let promptCopy: String?                    // C-051 — the `prompt` paragraph
    let suggestions: [String]?                 // C-051 — row titles in order (≤ 3 rendered)
    // C-050 SuggestionRow adds NOTHING. Its one render-bearing §4 prop, `title`, already
    // exists above under the contract's own name and type (`title: String?` in the 1.0
    // block), so rule 3's second bound is satisfied by reuse. `onAdd` is an action with no
    // render effect and is not carried by the fixture.
    // C-078 SuggestionRows (built 2026-09-22) adds NOTHING. Its one render-bearing §4 prop,
    // `suggestions: [String]`, already exists above under the contract's own name and type
    // (C-051's field — the same list C-051 hands it unchanged, §5), so rule 3's second bound
    // is satisfied by reuse. `onPick` is an action with no render effect and is not carried.
    // C-025 DayActivityCard re-build 2026-09-20 (row merged into C-023 RailCard `kind=day` 2026-09-21; fields kept): §4 is now FLAT (R-05) — `state`, `month`,
    // `weekday`, `day`, `dateState`, `series`, `percent`, `line1`, `line2`, `detailsState`.
    // `state`, `month`, `series` and `percent` already exist above under the contract's own
    // names; `day` is retyped above. These five are additive and none could be bent into an
    // existing field (rule 3's second bound): `date`/`details` above are the PRE-restructure
    // nested bags, kept because the three authored previews still carry them (a build never
    // re-props an existing preview) — the C-025 case read the flat keys first and fell
    // back to the nested ones.
    let weekday: String?                       // C-023 kind=day (ex-C-025) — → C-070 `weekday`
    let dateState: String?                     // C-023 kind=day (ex-C-025) — → C-070 `state`: "default" | "today"
    // C-071 ValuePair (built 2026-09-21) adds NOTHING: its three §4 props are `line1`,
    // `line2` and `state`, and all three already exist under the contract's own names and
    // types — `line1` / `line2` here, `state` above (the same string field C-053 / C-052
    // reuse). Rule 3's second bound is satisfied by reuse; `detailsState` is C-023's own key.
    let line1: String?                         // C-023 kind=day (ex-C-025) — → C-071 `line1`; C-071 — `line1`
    let line2: String?                         // C-023 kind=day (ex-C-025) — → C-071 `line2` (nil in single / singleMuted); C-071 — `line2`
    let detailsState: String?                  // C-023 kind=day (ex-C-025) — → C-071 `state`, one of its seven values
    // ── preview props ──
    // C-023 RailCard build 2026-09-21 (the merged row, both kinds in one case). Of its
    // seventeen §4 props, thirteen already exist above under the contract's own names and
    // types — `title`, `series`, `averageLabel`, `value` (metric); `state`, `month`,
    // `weekday`, `day` (`.stringValue`), `dateState`, `percent` (`.intValue`), `line1`,
    // `line2`, `detailsState` (day) — so rule 3's second bound is satisfied by reuse. These
    // four are additive: no existing field carries the absorbing axis, and the three trend
    // props are C-023's own names for what it forwards to C-077 (`direction` / `polarity` /
    // `label` above are C-077's OWN keys, and a contract's prop name is never bent to fit).
    let kind: String?                          // C-023 — "metric" | "day"
    let trendDirection: String?                // C-023 kind=metric — → C-077 `direction`: "up" | "down" | "neutral"
    let trendPolarity: String?                 // C-023 kind=metric — → C-077 `polarity`: "positive" | "negative" | "neutral"
    let trendLabel: String?                    // C-023 kind=metric — → C-077 `label`
    // C-031 EnrollmentStatusRow (built 2026-09-21) adds ONE field. Five of its six §4 props
    // already exist above under the contract's own names and types — `percent`
    // (`.intValue`), `label`, `count` (`Int?`, matching OQ-C-031-6's ruling), `progress`,
    // `subtitle` — so rule 3's second bound is satisfied by reuse. `statusColor` has no
    // existing field: `color` above is C-033's / C-027's own key for their sets, and a
    // contract's prop name is never bent to fit. Takes OQ-C-031-1's closed set.
    let statusColor: String?                   // C-031 — "green" | "yellow" | "red"
    // C-043 MetaChip (built 2026-09-22): `value`, `label` and `state` reuse the fields above
    // under the contract's own names. OQ-C-043-1 (landed in §4 2026-10-24) renamed `align` to
    // `labelPosition` — `trailing | leading` — which has no field here, so it adds ONE.
    let labelPosition: String?                 // C-043 — "trailing" | "leading"
    // C-076 ActivitySpinner (built 2026-09-24) adds ONE field. `size` (`.doubleValue`),
    // `color` (a token name) and `direction` already exist above under the contract's own
    // names; `period` exists too but as a String, so the case never reads it (a number there
    // would fail to decode) and takes §4's default 1.0 — it has no effect on a phase-0 render.
    let strokeWidth: Double?                   // C-076 — ring band width, pt
    // C-020 SectionHeader (built 2026-09-25) adds ONE field. `title` and `style` already exist
    // above under the contract's own names and types. `accessory` is §4's enum with associated
    // values, so it decodes in Swift's own synthesized shape for such an enum — one key per case
    // holding that case's payload, e.g. {"meta": {"value": "5", "label": "metrics", "glyph": "add"}}.
    let accessory: CaptureUI2SectionAccessory? // C-020 — none | meta | link | dropdown | caption
    // C-032 FollowedProgramHeader (built 2026-09-25) adds TWO fields. `title` already exists
    // above under the contract's own name and type; `author` and `createdLabel` have no field.
    let author: String?                        // C-032 — the program author's display name
    let createdLabel: String?                  // C-032 — the caller-formatted created text
    // C-054 AvatarProgressRow (built 2026-09-26) adds ONE field. `title`, `imageURL`,
    // `initials` and `progress` already exist above under the contract's own names and types.
    // `metadata` exists too, as `[CaptureDataItem]` — the 1.0 cards' chip list, whose `value`
    // and `label` are already C-043's names; the two C-043 keys it lacks are added to
    // `CaptureDataItem` itself (additive optionals), so the prop name is not bent.
    let progressLabel: String?                 // C-054 — caller-formatted text beside the bar
    // ── screen edit-text-single-field ──
    // Reused as-is: `title`, `description`, `label`, `placeholder`, `text`, `focused`,
    // `promptCopy`, `suggestions` (same names, same types).
    let loadedValue: String?
    let saving: Bool?
    let aiState: String?
    let __frameHeight: Double?
    // ── screen edit-option-field ──
    // Reused as-is: `title`, `description`, `options`, `selectedOption`, `loadedValue`,
    // `saving`, `__frameHeight` (same names, same types).
    let optionDescriptions: [String]?
    let errorMessage: String?
    // ── screen edit-options-custom-field ──
    // Reused as-is: `title`, `description`, `options`, `selectedOption`, `saving`,
    // `__frameHeight` (same names, same types).
    let presetMinimums: [Int]?
    let presetMaximums: [Int]?
    let minimumLabel: String?
    let maximumLabel: String?
    let minimumPlaceholder: String?
    let maximumPlaceholder: String?
    let minimum: String?
    let maximum: String?
    let loadedMinimum: String?
    let loadedMaximum: String?
    let focusedInput: String?
    // ── screen edit-text-multi-field ──
    // Adds NOTHING: every `State` field — `title`, `description`, `label`, `placeholder`,
    // `text`, `loadedValue`, `focused`, `saving`, `promptCopy`, `aiState`, `suggestions` — and
    // `__frameHeight` already exist above with the same names and types.
    // ── preview props ──
    // C-079 ActivityScreenshot build 2026-09-26. §4 `image` is `Image?`, which JSON cannot
    // carry, so the fixture names the screenshot by URL (file:// or http[s]) under the
    // contract's own key and the registry case resolves it to an Image — the caller's job
    // under R-04 / R-19. Absent = `nil` = the `empty` state.
    let image: String?                         // C-079 — screenshot URL → `image: Image?`
    // ── preview props ──
    // C-067 ActionMenuRow build 2026-09-26. `glyph` and `label` already exist above under the
    // contract's own names and types; `tone` has no field in this struct (C-042's lives
    // inside `CaptureUI2Indicator`).
    let tone: String?                          // C-067 — "standard" | "destructive"
    // ── screen home-dashboard ──
    // Reused as-is: `hourValues`, `centerValue`, `centerUnit`, `centerCaption`, `bins` (same
    // names, same types). `enrollmentCount` exists above as `Int?` (CardProgramFull), so the
    // screen's Following count is spelled `followedCount`. Everything else is the screen's own.
    let metricCount: String?
    let kpiTitles: [String]?
    let kpiValues: [String]?
    let kpiTrendDirections: [String]?
    let kpiTrendPolarities: [String]?
    let kpiTrendLabels: [String]?
    let kpiAverageLabels: [String]?
    let kpiSeries: [[Double]]?
    let dayMonths: [String]?
    let dayWeekdays: [String]?
    let dayNumbers: [String]?
    let dayDateStates: [String]?
    let daySeries: [[Double]]?
    let dayLine1s: [String]?
    let dayLine2s: [String]?
    let dayDetailsStates: [String]?
    let dayDates: [String]?
    let chartDates: [String]?
    let chartScheduled: [Int]?
    let chartCompleted: [Int]?
    let chartWindowStart: String?
    let chartWindowEnd: String?
    let chartToday: String?
    let sessionRange: String?
    let sessionTickValues: [String]?
    let sessionTickUnits: [String]?
    let activeCount: String?
    let engagementPercent: Int?
    let engagementLabel: String?
    let engagementCount: Int?
    let engagementProgress: Double?
    let engagementSubtitle: String?
    let engagementColor: String?
    let followedCount: String?
    let programTitles: [String]?
    let programAuthors: [String]?
    let programCreatedLabels: [String]?
    let groupProgramIndices: [Int]?
    let groupTitles: [String]?
    let groupPhotoURLs: [String]?
    let groupMembers: [String]?
    let groupPercents: [String]?
    let groupColors: [String]?
    let groupShowLinks: [Bool]?
    // ── preview props ──
    // C-037 ListResultRow build 2026-09-27. `title`, `description`, `count` (`Int?`),
    // `imageURL` and `initials` already exist above under the contract's own names and types.
    // `chips` entries are C-043 MetaChip's own props, carried in `CaptureDataItem` (the C-054
    // precedent) with C-043's `align` added there.
    let subject: String?                       // C-037 — "member" | "group"
    let detail: String?                        // C-037 — "text" | "chips"
    let trailing: String?                      // C-037 — "chevron" | "cancel" | "none"
    let chips: [CaptureDataItem]?              // C-037 — [C-043 MetaChip] props
    // C-037 update 2026-10-24 (selectable form): `subject` gains "program"; additive field.
    let selection: String?                     // C-037 — "none" | "unselected" | "selected"
    // ── screen create-study-program ──
    // Reused as-is: `text`, `errorMessage` (same names, same types).
    let creating: Bool?
    // ── preview props ──
    // C-065 TimelineEventRow build 2026-09-28. `text` and `tone` already exist above under
    // the contract's own names and types.
    let dateLabel: String?                     // C-065
    let highlight: String?                     // C-065
    // ── preview props ──
    // C-055 CategoryBarTable build 2026-09-28. `rows` already exists above as
    // `[CaptureShimmerRow]?`; C-055's row fields are added to that struct, additively.
    let valueColumnTitle: String?              // C-055
    let countColumnTitle: String?              // C-055
    // ── preview props ──
    // C-059 StudyProgramRow build 2026-09-29. `state`, `title`, `description` and `progress`
    // already exist above under the contract's own names and types. `metaChips` entries are
    // C-043 MetaChip's own props, carried in `CaptureDataItem` (the C-037 / C-054 precedent,
    // whose `state` and `align` are already C-043's names). §4 `cover` is `Image?`, which JSON
    // cannot carry, so the fixture names it by URL and the registry case resolves it (C-079
    // precedent). Absent = `nil` = the `missing-cover` state.
    let metaChips: [CaptureDataItem]?          // C-059 — [C-043 MetaChip] props
    let cover: String?                         // C-059 — cover URL → `cover: Image?`
    // C-059 update 2026-10-20 (D59): §4 `caption: String?` — the `Program` state's line.
    let caption: String?                       // C-059 — `Program` caption, e.g. "3 enrolled"
    // ── preview props ──
    // C-063 LessonCard build 2026-09-29. `title` and `progress` already exist above under the
    // contract's own names and types. §4 `slides` entries carry `image` by URL (C-079
    // precedent: the registry case resolves it) and `label`.
    let header: CaptureUI2LessonHeader?        // C-063 — `LessonCard.Header`
    let metaLabel: String?                     // C-063
    let slides: [CaptureUI2LessonSlide]?       // C-063 — [LessonCard.Slide]; C-081 — [ActivityNavBar.Slide]
    // ── preview props ──
    // C-081 ActivityNavBar build 2026-09-29. §4 `slides` reuses the field above under the
    // contract's own name (its entries gain `id`, additive, below); `activeID` has no field.
    let activeID: String?                      // C-081 — the outlined slide's id; nil = none
    // ── screen members-profile ──
    // Reused as-is: `avatarURL`, `initials`, `age` (`Int?`), `role`, the eight `day*` arrays,
    // `groupTitles`, `groupPhotoURLs` and `programTitles` (same names, same types).
    let memberName: String?
    let email: String?
    let birthday: String?
    let joined: String?
    let organization: String?
    let phone: String?
    let phoneVerified: Bool?
    let emailVerified: Bool?
    let gender: String?
    let address: String?
    let emergencyContact: String?
    let groupLeaders: [String]?
    let groupJoinedDates: [String]?
    let programStates: [String]?
    let programProgress: [Double]?
    let programCompleteCounts: [String]?
    let programHours: [String]?
    let programCoverURLs: [String]?
    // ── preview props ──
    // C-036 FilterMenuOverlay build 2026-09-30. `options` is retyped above; these three are
    // additive. `selectionMode` + `selectedIDs` are OQ-C-036-009's ruled selection API; the
    // modifier's `isPresented` drives the Presented state (§4 .filterMenuPresentation).
    let selectionMode: String?                 // C-036 — "single" | "multiple"
    let selectedIDs: [String]?                 // C-036
    let isPresented: Bool?                     // C-036 — .filterMenuPresentation(isPresented:)
    // ── screen members-home ──
    // Reused as-is: `searchText` (same name, same type).
    let groupFilterLabel: String?
    let leaderFilterLabel: String?
    let groupOptions: [String]?
    let leaderOptions: [String]?
    let memberNames: [String]?
    let memberPhotoURLs: [String]?
    let memberJoinedLabels: [String]?
    let memberGroupCounts: [Int]?
    // ── preview props ──
    // C-058 GroupSectionHeader build 2026-09-30. `groupName`, `imageURL` and `initials` already
    // exist above under the contract's own names and types; `leaderName` is additive.
    let leaderName: String?                    // C-058 — the group leader's display name
    // ── preview props ──
    // C-083 NavBarButton build 2026-09-30. `glyph` and `active` already exist above under the
    // contract's own names and types; `accessibilityLabel` is additive.
    let accessibilityLabel: String?            // C-083 — VoiceOver label, never drawn
    // ── preview props ──
    // C-086 ActivityTypeGrid build 2026-10-02. `pendingType` is additive.
    let pendingType: String?                   // C-086 — bibleVerse|text|video|youtube|write|poll; nil = interactive
    // ── screen activity-new ──
    // Reused as-is: `activeID`, `pendingType` (same names, same types; "" = interactive).
    let slideIDs: [String]?
    let slideLabels: [String]?
    let createFailed: Bool?
    // ── screen study-program-home ──
    // Reused as-is: `createdLabel`, `authorName`, `leaderName`, `programName`,
    // `programDescription` (same names, same types).
    let coverURL: String?
    let lessonCount: Int?
    let visibility: String?
    let ageRange: String?
    let maximumMembers: String?
    let memberDirectoryAccess: String?
    let enrollmentNames: [String]?
    let enrollmentPhotoURLs: [String]?
    let enrollmentLeaders: [String]?
    let enrollmentMemberCounts: [Int]?
    let dayCount: Int?
    let activeDay: Int?
    let lessonNumbers: [Int]?
    let lessonTitles: [String]?
    let lessonDurations: [String]?
    let lessonSlideImages: [[String]]?
    let lessonSlideLabels: [[String]]?
    // ── screen invite-home ──
    // Reused as-is: `phone`, `memberName`, `avatarURL`, `initials`, `age` (`Int?`), `role`,
    // `birthday`, `joined`, `groupTitles`, `groupPhotoURLs` (same names, same types). Not
    // `linked`: that name is already decoded as `Linked?`.
    let memberLinked: Bool?
    let sentDate: String?
    let invitedBy: String?
    let groupStatuses: [String]?
    let groupStatusDates: [String]?
    let eventDates: [String]?
    let eventTexts: [String]?
    let eventHighlights: [String]?
    let eventTones: [String]?
    // ── screen groups-home ──
    // Reused as-is: `searchText`, `leaderFilterLabel`, `leaderOptions`, `groupPhotoURLs` (same
    // names, same types).
    let orgFilterVisible: Bool?
    let orgFilterLabel: String?
    let orgOptions: [String]?
    let groupNames: [String]?
    let groupLeaderNames: [String]?
    let groupMemberCounts: [Int]?
    // ── screen enrollment-home ──
    // Reused as-is: `coverURL`, `programName`, `programDescription`, `memberCount` (`Int?`),
    // `authorName`, `leaderName`, the seven `day*` string arrays, `lessonNumbers`,
    // `lessonTitles`, `lessonSlideImages`, `lessonSlideLabels` (same names, same types).
    let enrolledLabel: String?
    let startMonth: String?
    let startWeekday: String?
    let startDay: String?
    let endMonth: String?
    let endWeekday: String?
    let endDay: String?
    let spanMonths: Int?
    let spanDays: Int?
    let dayPercents: [Int]?
    let lessonMetaLabels: [String]?
    let lessonProgress: [Double?]?
    // ── preview props ──
    // C-089 InviteStatusRow build 2026-10-03. `status` (`String?`), `groupName` (`String?`)
    // and `date` (`CaptureDateOrBlock?`, read as `.string`) already exist above under the
    // contract's own names; `recipient` is additive.
    let recipient: String?                     // C-089 — caller-formatted name or phone
    // ── screen invites-home ──
    // Reused as-is: `searchText`, `orgFilterLabel`, `groupFilterLabel`, `leaderFilterLabel`
    // (same names, same types).
    let statusFilterLabel: String?
    let loading: Bool?
    let inviteRecipients: [String]?
    let inviteStatuses: [String]?
    let inviteGroupNames: [String]?
    let inviteDates: [String]?
    // ── screen groups-detail ──
    // Reused as-is: `groupName`, `coverURL`, `leaderName`, `createdLabel`, `visibility`,
    // `ageRange`, `maximumMembers`, `memberDirectoryAccess`, `lessonTitles`, `lessonMetaLabels`,
    // `lessonSlideImages`, `lessonSlideLabels`, the eight `day*` arrays, the six `chart*` fields,
    // `memberNames`, `memberPhotoURLs`, `memberJoinedLabels`, `programTitles`,
    // `programCoverURLs` and the four `event*` arrays (same names, same types).
    let groupDescription: String?
    let lessonProgramNames: [String]?
    let programDescriptions: [String]?
    let programEnrolledDates: [String]?
    // groups-detail re-build 2026-10-18 (C-089 join-request rows, §2.7): additive.
    let requestNames: [String]?
    let requestDates: [String]?
    // ── screen enrollments-home ──
    // Reused as-is: `searchText`, the four `*FilterLabel`s, `loading`, `groupNames`,
    // `groupLeaderNames`, `groupPhotoURLs`, `programTitles`, `programProgress`,
    // `programCompleteCounts`, `programHours`, `programEnrolledDates` and `programCoverURLs`
    // (same names, same types).
    let failed: Bool?
    let programGroupIndexes: [Int]?
    // ── screen search-home ──
    // Reused as-is: `searchText` (same name, same type).
    let activeChip: String?
    let recentKinds: [String]?
    let recentTitles: [String]?
    let recentDescriptions: [String]?
    let resultKinds: [String]?
    let resultTitles: [String]?
    let resultDescriptions: [String]?
    // ── screen home-kpi-picker ──
    // Reused as-is: `kpiSeries`, `kpiAverageLabels`, `kpiValues`, `kpiTrendDirections`,
    // `kpiTrendPolarities`, `kpiTrendLabels` (home-dashboard's — same names, same types).
    let kpiNames: [String]?
    let kpiDescriptions: [String]?
    // ── preview props ──
    // C-104 AuthProviderButton build 2026-10-08. `loading` (`Bool?`) already exists above under
    // the contract's own name and type (invites-home's), so rule 3's second bound is satisfied
    // by reuse; `provider` is additive.
    let provider: String?                      // C-104 — "google"
    // ── screen login ──
    // Reused as-is: `errorMessage` (`String?`, edit-text-single-field's — same name, same type).
    let authenticating: Bool?
    // ── preview props ──
    // C-092 CanvasTextObject build 2026-10-12. Reused as-is under the contract's own names:
    // `text` (`String?`), `color` (`String?` — a token row name or a hex), `label` (`String?`),
    // `size` (`CaptureDoubleOrString?` — its number) and `highlights` (`[CaptureHighlight]?` —
    // start/end character offsets into `text`; C-092's optional `note` is not carried, it is not
    // drawn). The rest are additive:
    let font: String?                          // C-092 — poppins | sfPro | georgia | typewriter
    let alignment: String?                     // C-092 — center | left | right
    let listStyle: String?                     // C-092 — none | bullet | numbered | bibleVerse
    let startNumber: Int?                      // C-092 — OQ-C-092-003, first verse number
    let reference: CaptureUI2BibleReference?   // C-092 — `CanvasTextObject.Reference`
    let animation: String?                     // C-092 — none | typewriter | pop | jump
    let effect: String?                        // C-092 — none | sparkle | neon | shimmer | pixel
    let transform: CaptureUI2CanvasTransform?  // C-092 — `CanvasTextObject.Transform`
    let editing: Bool?                         // C-092 — first responder with the caret
    // ── preview props ──
    // C-105 Button build 2026-10-13. Reused as-is under the contract's own names: `label`
    // (`String?`) and `leadingGlyph` (`String?` — a library glyph name, C-040's). Additive:
    let trailingGlyph: String?                 // C-105 — the glyph after the label
    // ── preview props ──
    // C-091 ActivityCanvas build 2026-10-13. Reused as-is under the contract's own names: `mode`
    // (`String?` — idle | editing | highlighting | manipulating, CardLesson's field). `passage`
    // exists as `String?` (the 1.0 cards' reference text) and may not be retyped, so the fixture
    // carries C-091's structured passage as a JSON string under the contract's key, decoded by
    // the registry case into `CaptureUI2CanvasPassage` (the C-093 numeric-string precedent).
    // The canvas height the screen gives it rides in `__frameHeight` (the screens' field).
    // Additive:
    let background: CaptureUI2CanvasBackground?    // C-091 — `ActivityCanvas.Background`
    let selectedHighlightID: String?           // C-091 — the selected highlight's id
    // RETYPED 2026-10-24 (/d2m:component:build C-052), by the same reasoning and in the same
    // shape as `day`, `date` and `size` above. This was `[CaptureUI2CanvasChild]?`. C-052 §4
    // (re-specced 2026-10-24) has a `content` that is a `DayChip.Content` object, and the
    // build forbids bending a contract's prop name to fit an existing field — so the field
    // decodes both shapes. C-091 asks for `.children`; C-052 for `.dayChip`.
    let content: CaptureContentOrChildren?     // C-091 — the slot's children; C-052 — `DayChip.Content`
    let centerGuide: Bool?                     // C-091 — the 1px centre guide (manipulating)
    let deleteTarget: String?                  // C-091 — visible | armed (manipulating)
    // ── preview props ──
    // C-095 ColorPickerWell build 2026-10-13. Reused as-is under the contract's own name:
    // `color` (`String?` — a #rrggbb hex, decoded by the registry case). Additive:
    let armed: Bool?                           // C-095 — the eyedropper is live
    // ── preview props ──
    // C-097 PageIndicator build 2026-10-13. Additive:
    let pageCount: Int?                        // C-097 — how many dots
    let page: Int?                             // C-097 — 0-based active dot
    // ── preview props ──
    // C-094 TextColorPalette build 2026-10-13. Reused as-is under the contract's own name:
    // `page` (`Int?`, C-097's). Additive:
    let currentColor: String?                  // C-094 — a #rrggbb hex, decoded by the registry case
    let swatches: [[CaptureUI2NamedColor]]?    // C-094 — `TextColorPalette.NamedColor` pages
    // ── preview props ──
    // C-106 ChipStrip build 2026-10-13. `items` already exists above as `[CaptureListItem]?` under
    // the contract's own name, so it is reused (its element gains an additive `font`). Additive:
    let selectedID: String?                    // C-106 — the id of the selected chip
    // Harness key, not a §4 prop (the `__frameHeight` precedent): the width the strip is given.
    // C-106 §3 `fit` is derived from width — `overflow` is reached on the same list below 421pt.
    let __frameWidth: Double?
    // ── screen activities-editor ──
    // Reused as-is (same name and type): `slideIDs`, `slideLabels`, `activeID`,
    // `selectedHighlightID`, `centerGuide`, `saving`. Additive:
    let editorMode: String?
    let openTool: String?
    let objectTexts: [String]?
    let objectFonts: [String]?
    let objectColors: [String]?
    let objectSizes: [Double]?
    let objectXs: [Double]?
    let objectYs: [Double]?
    let objectScales: [Double]?
    let objectRotations: [Double]?
    let draftText: String?
    let draftFont: String?
    let draftColor: String?
    let draftSize: Double?
    let draftAlignment: String?
    let pageImageURL: String?
    let pageWashHex: String?
    let pageWashOpacity: Double?
    let verseTexts: [String]?
    let firstVerse: Int?
    let highlightIDs: [String]?
    let highlightVerses: [Int]?
    let highlightStarts: [Int]?
    let highlightEnds: [Int]?
    let deleteTargetShown: Bool?
    let saveFailed: Bool?
    // ── screen request-detail ──
    // Reused as-is: `phone`, `groupName`, `status` (`String?`), `loading` (`Bool?`),
    // `eventDates`, `eventTexts`, `eventHighlights` (same names, same types).
    let requestDate: String?
    let requestTime: String?
    let groupPhotoURL: String?
    let statusDate: String?
    let responding: Bool?
    // ── preview props ──
    // C-108 KeypadKey build 2026-10-19. Both additive; no field of either name existed.
    let key: String?                           // C-108 — §3's spelling: "digit(0)"…"digit(9)" | "delete"
    let enabled: Bool?                         // C-108 — nil = §4's default true
    // C-107 NumberKeypad build 2026-10-19. Additive; reuses `enabled` (same name, same type).
    let deleteEnabled: Bool?                   // C-107 — nil = §4's default true
    // ── preview props ──
    // C-040 PageHeader rebuild 2026-10-19 (OQ-C-040-4). Both additive; no field of either name existed.
    let leadingLabel: String?                  // C-040 — textButtons leading label; nil = §4's "Cancel"
    let trailingLabel: String?                 // C-040 — textButtons trailing label; nil = §4's "Done"
    // C-040 update 2026-10-24 (D60, OQ-C-040-001). Additive; no field of this name existed.
    let trailingEnabled: Bool?                 // C-040 — textButtons / backAndLink trailing action; nil = §4's true
    // ── preview props ──
    // C-045 TextInput rebuild 2026-10-19. Additive; reuses `kind` and `alignment` (same names,
    // same String type); no field named countryCode existed.
    let countryCode: String?                   // C-045 — Phone prefix; nil = §4's "+1"
    // ── screen invite-member ──
    // Additive; no field of these names existed. Not `name`: that field is the component name.
    let step: String?                          // "name" | "phone" | "sent"
    let inviteeName: String?
    let digits: String?                        // the national number's digits, 0–10
    let sending: Bool?
    // ── preview props ──
    // C-069 NavTabButton build 2026-10-19. Additive; reuses `label`, `expansion` and `active`
    // (same names, same types); no field named hasAdd existed.
    let hasAdd: Bool?                          // C-069 — nil = §4's default true
    // ── screen study-programs ──
    // Reused as-is: `searchText`, `orgFilterLabel`, `leaderFilterLabel`, `loading`, `failed`,
    // `programTitles`, `programDescriptions` and `programCoverURLs` (same names, same types).
    let programEnrollmentCounts: [Int]?
    // ── preview props ──
    // C-110 CopyableCodeCard build 2026-10-20. Both additive; no field of either name existed.
    let code: String?                          // C-110 — the code shown, verbatim
    let copied: Bool?                          // C-110 — true shows the "Copied" overlay
    // ── screen invite-qr ──
    // Reused as-is: `code` (same name, same type).
    let hintURL: String?                       // the context's enter-a-code URL
    let qrCode: String?                        // the invite's `qrCode` data URL; nil = blank plate
    let copiedTarget: String?                  // "code" | "link" | "" — the Copied overlay's element
    // ── preview props ──
    // C-114 WeekdayHeader build 2026-10-20. Additive; no field of that name existed.
    let hairline: Bool?                        // C-114 — true draws the rule under the letters
    // ── preview props ──
    // C-112 EventIndicator build 2026-10-20. Additive; no field of that name existed.
    let eventTypes: [String]?                  // C-112 — [EventIndicator.EventType] raw values, display order
    // ── preview props ──
    // C-116 WeekStrip build 2026-10-21. Additive; reuses `selected` (`.stringValue`) and
    // `today` (`.stringValue`) as-is; no field named week existed in this struct.
    let week: String?                          // C-116 — any day in the week, yyyy-MM-dd
    // ── preview props ──
    // C-117 CalendarEventBlock build 2026-10-21. Additive; reuses `title`, `detail` (String?)
    // and the harness keys `__frameWidth` / `__frameHeight` as-is; no field of these names existed.
    let detailKind: String?                    // C-117 — CalendarEventBlock.DetailKind raw value
    let eventType: String?                     // C-117 — EventIndicator.EventType raw value (C-112)
    let recurring: Bool?                       // C-117 — draws repeat-arrows
    let timeRangeText: String?                 // C-117 — spoken time range, a11y label only
    // ── preview props ──
    // C-120 DayTimeline build 2026-10-21. Additive; no field of these names existed.
    let timedEvents: [CaptureUI2TimedEvent]?   // C-120 — [DayTimeline.TimedEvent]
    let allDayEvents: [CaptureUI2AllDayEvent]? // C-120 — [DayTimeline.AllDayEvent]
    let allDayExpanded: Bool?                  // C-120 — all chips (true) vs 3 + "+N more"
    let nowMinute: Int?                        // C-120 — the C-119 now line's minute; nil = not today
    let topMinute: Int?                        // C-120 — the minute at the viewport's top
    // ── preview props ──
    // C-121 CalendarEventRow build 2026-10-21. Additive; reuses `title`, `detail`, `detailKind`
    // and `eventType` as-is; no field of these names existed.
    let timing: String?                        // C-121 — CalendarEventRow.Timing raw value
    let startTime: String?                     // C-121 — caller-formatted start ("3:50 PM")
    let endTime: String?                       // C-121 — caller-formatted end
    let past: Bool?                            // C-121 — before today → row at 0.5 opacity
    // ── screen calendar-home ──
    // Additive; reuses `mode`, `selectedDate`, `focused`, `loading`, `eventDates` and
    // `eventTypes` as-is (same names, same types); no field of these names existed.
    let origin: String?                        // search's origin mode: month|day
    let now: String?                           // injected now, yyyy-MM-dd'T'HH:mm
    let topMonth: String?                      // month at the header, yyyy-MM
    let query: String?                         // C-034 search query
    let searchFetching: Bool?                  // undesigned search-fetching
    let searchFailed: Bool?                    // undesigned search-error
    let eventTitles: [String]?                 // CalendarEvent.title, one per event
    let eventStarts: [String]?                 // CalendarEvent.startTime HH:mm, "" = all-day
    let eventEnds: [String]?                   // CalendarEvent.endTime HH:mm
    let eventLocations: [String]?              // CalendarEvent.locationName, "" = null
    let eventURLs: [String]?                   // CalendarEvent.externalUrl, "" = null
    let eventGroups: [String]?                 // CalendarEvent.groupName
    let eventRecurring: [Bool]?                // CalendarEvent.isRecurring
    // ── preview props ──
    let showsClearWhenEmpty: Bool?             // C-034 SearchField — clear x with an empty query
    // C-047 RadioOptionRow update 2026-10-24 (/d2m:component:update Run 2). Additive: §4 gained
    // `recommended` and `disabled` (both `Bool`, default `false`); no field of these names
    // existed, and `available`/`active`/`selected` mean other things on other contracts.
    let recommended: Bool?                     // C-047 — amber star after the title
    let disabled: Bool?                        // C-047 — whole row at 0.4, taps ignored
    // C-128 DateRangePicker. Additive; reuses `lessonCount` (Int), `today` (string reading),
    // `startDate` (String) and `enabledDays` ([Int]) as-is — same names, same types.
    let overriddenDates: [String]?             // C-128 — yyyy-MM-dd, inclusion flipped
    let existingLessonDates: [String]?         // C-128 — yyyy-MM-dd, event dots + overlap check
    let currentScheduleDates: [String]?        // C-128 — yyyy-MM-dd, schedule ghost
    let prompt: String?                        // C-128 — none | override(yyyy-MM-dd) | overlap(yyyy-MM-dd)
    // ── screen enrollment-select-group ──
    // Additive; reuses `searchText`, `orgFilterVisible`, `orgFilterLabel`, `leaderFilterLabel`,
    // `groupNames`, `groupPhotoURLs`, `groupLeaderNames`, `groupMemberCounts`, `selectedIndex`,
    // `loading` and `failed` as-is (same names, same types).
    let groupEnrollmentCounts: [Int]?          // active enrollments per group row
    // ── screen enrollment-select-program ──
    // Additive; reuses `searchText`, `orgFilterVisible`, `orgFilterLabel`, `leaderFilterLabel`,
    // `programTitles`, `programCoverURLs`, `programCreatedLabels`, `selectedIndex` and `loading`
    // as-is (same names, same types).
    let programDayCounts: [Int]?               // program length in days per row
    let programCompletedCounts: [Int]?         // completed enrollments per row (OQ-003)
    // ── screen enrollment-select-invite-time ──
    let smsTime: String?                       // saved invite time "HH:mm"; "" = none saved
    // ── screen enrollment-select-sync ──
    let syncMode: String?                      // draft syncMode "AUTO" | "OFF"; "" = unset
    // ── screen enrollment-select-access ──
    let lessonAccess: String?                  // draft lessonAccess "one-at-a-time" | "all-at-once"; "" = unset
    // ── preview props ──
    // C-125 EnrollmentProgressHeader build 2026-10-24. Reuses `groupName` and `groupImageURL`
    // (`String?`, parsed to URL at the case) as-is — same names.
    let groupInitials: String?                 // C-125 — C-038 `initials` fallback
    let completedSteps: Int?                   // C-125 — checklist rows done
    let totalSteps: Int?                       // C-125 — checklist rows in all
    // C-123 TaskDisc build 2026-10-24.
    let look: CaptureUI2TaskDiscLook?          // C-123 — `TaskDisc.Look` as {"kind": "<case>", …}
    // C-124 ChecklistStepRow build 2026-10-24. Reuses `title`, `description` and `status`
    // (`String?`) as-is — same names.
    let disc: CaptureUI2TaskDiscLook?          // C-124 — C-123 `TaskDisc.Look`, same encoding as `look`
    // ── screen groups-enroll-program ──
    // Additive; reuses `groupName`, `groupInitials`, `groupImageURL`, `programName`,
    // `programDescription`, `smsTime`, `syncMode` and `lessonAccess` as-is (same names, same types).
    let phase: String?                         // checklist | processing | enrolled
    let groupCreatedOn: String?                // "January 3rd, 2025" as displayed
    let groupActiveMembers: Int?               // active member count
    let programImageURL: String?               // program row photo
    let scheduleStartWeekday: String?          // "Monday"; schedule row done when scheduleStartDay ≠ ""
    let scheduleStartMonth: String?            // "July"
    let scheduleStartDay: String?              // "24"
    let scheduleStartToday: Bool?              // C-123 date(today:)
    let scheduleWeekdays: [String]?            // enabled weekdays, full names
    let scheduleEndDate: String?               // "October 18th, 2026" as displayed
    // ── screen enrollment-select-schedule ──
    // Additive; reuses `lessonCount`, `today` (string reading), `startDate`, `enabledDays`,
    // `overriddenDates`, `existingLessonDates` and `prompt` as-is (same names, same types).
    let programChosen: Bool?                   // false = §3 needs-program
}

/// C-123 §4 `look` — "Fixtures encode `look` as an object: `{\"kind\": \"<case>\", …associated
/// values by label}`". Field names are the contract's associated-value labels.
struct CaptureUI2TaskDiscLook: Codable {
    let kind: String                           // glyph|check|photo|date|time|syncOn|syncOff|all|one
    let glyph: String?                         // glyph — a library glyph name
    let imageURL: String?                      // photo — nil = unresolved (OQ-C-123-001)
    let weekday: String?                       // date
    let month: String?                         // date
    let day: String?                           // date
    let today: Bool?                           // date
    let time: String?                          // time
    let period: String?                        // time
}

/// C-120 §4 `timedEvents` element — `DayTimeline.TimedEvent`, §4's own field names; `detailKind`
/// and `eventType` are C-117's and C-112's raw values, decoded by the registry case.
struct CaptureUI2TimedEvent: Codable {
    let id: String
    let title: String
    let detail: String?
    let detailKind: String
    let eventType: String
    let recurring: Bool
    let startMinute: Int
    let endMinute: Int
    let timeRangeText: String
}

/// C-120 §4 `allDayEvents` element — `DayTimeline.AllDayEvent`; `eventType` is C-112's raw value.
struct CaptureUI2AllDayEvent: Codable {
    let id: String
    let title: String
    let eventType: String
}

/// C-094 §4 `swatches` element — `TextColorPalette.NamedColor`: the colour's name and a #rrggbb
/// hex, decoded by the registry case.
struct CaptureUI2NamedColor: Codable {
    let name: String
    let color: String
}

/// C-091 §4 `background: ActivityCanvas.Background` — exactly one key is present, named for the
/// case (the C-020 `accessory` precedent); `image`'s fields are the case's own labels, `washColor`
/// a #rrggbb swatch.
struct CaptureUI2CanvasBackground: Codable {
    struct Plain: Codable {}
    struct ImagePayload: Codable {
        let imageURL: String
        let washColor: String
        let washOpacity: Double
    }
    let plain: Plain?
    let image: ImagePayload?
}

/// C-091 §4 `passage: ActivityCanvas.Passage` — carried as a JSON string in `passage`; `range` is
/// [lowerBound, upperBound) as character offsets into its verse's `text`.
struct CaptureUI2CanvasPassage: Codable {
    struct Verse: Codable {
        let number: Int
        let text: String
    }
    struct Highlight: Codable {
        let id: String
        let verse: Int
        let range: [Int]
        let note: String?
    }
    let verses: [Verse]
    let highlights: [Highlight]
}

/// Decodes a JSON value that may be either C-091's `content` slot (an array of children) or
/// C-052's `DayChip.Content` object. Same either-shape pattern as `CaptureDateOrBlock`.
struct CaptureContentOrChildren: Codable {
    let children: [CaptureUI2CanvasChild]?
    let dayChip: CaptureUI2DayChipContent?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let c = try? container.decode([CaptureUI2CanvasChild].self) {
            children = c
            dayChip = nil
        } else if let d = try? container.decode(CaptureUI2DayChipContent.self) {
            dayChip = d
            children = nil
        } else {
            children = nil
            dayChip = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let children {
            try container.encode(children)
        } else {
            try container.encode(dayChip)
        }
    }
}

/// C-052 §4 `content: DayChip.Content` — exactly one key set: `{"day": 2}` → `.day(2)`, or
/// `{"weekday": {"letter": "M", "name": "Monday"}}` → `.weekday(letter:name:)`.
struct CaptureUI2DayChipContent: Codable {
    let day: Int?
    let weekday: CaptureUI2DayChipWeekday?
}

/// C-052 `.weekday(letter:name:)` — the field names are the contract's.
struct CaptureUI2DayChipWeekday: Codable {
    let letter: String
    let name: String
}

/// One child of C-091's `content` slot. `component` names the registry row; the rest are that
/// row's own §4 props under its own names, plus where the screen places it (canvas-local:
/// `x`/`y` top-left and `width`; a committed C-092 is placed by its own `transform.position`).
struct CaptureUI2CanvasChild: Codable {
    let component: String                      // C-092 | C-093 | C-102 | C-105
    let x: Double?
    let y: Double?
    let width: Double?
    let text: String?                          // C-092
    let font: String?                          // C-092
    let size: Double?                          // C-092
    let editing: Bool?                         // C-092
    let transform: CaptureUI2CanvasTransform?  // C-092
    let value: Double?                         // C-093 — 0…1
    let glyph: String?                         // C-102
    let tone: String?                          // C-102
    let style: String?                         // C-102
    let selected: Bool?                        // C-102
    let accessibilityLabel: String?            // C-102
    let label: String?                         // C-105
    let leadingGlyph: String?                  // C-105
}

/// C-092 §4 `reference: CanvasTextObject.Reference?` — field names are the contract's.
struct CaptureUI2BibleReference: Codable {
    struct Point: Codable {
        let book: String
        let chapter: Int
        let verse: Int?
    }
    let start: Point
    let end: Point?
}

/// C-092 §4 `transform: CanvasTextObject.Transform` — `rotation` in degrees, `position` as {x, y}.
struct CaptureUI2CanvasTransform: Codable {
    struct Position: Codable {
        let x: Double
        let y: Double
    }
    let position: Position?
    let scale: Double?
    let rotation: Double?
    let width: Double?
}

/// C-063 §4 `header: LessonCard.Header` — exactly one key is present, named for the case
/// (the C-020 `accessory` precedent); each payload's field names are the case's own labels.
struct CaptureUI2LessonHeader: Codable {
    struct Numbered: Codable { let lessonNumber: Int }
    struct Linked: Codable { let label: String }
    let numbered: Numbered?
    let linked: Linked?
}

/// C-063 §4 `slides` element `LessonCard.Slide(image: Image?, label: String)`; `image` is a
/// screenshot URL the registry case resolves. Absent `image` = `nil` = C-079's `empty`.
struct CaptureUI2LessonSlide: Codable {
    let image: String?
    let label: String?
    // ── preview props ──
    let id: String?                            // C-081 — ActivityNavBar.Slide.id (C-063 has none)
}

/// C-020 §4 `accessory` — exactly one key is present, named for the case; each payload's field
/// names are §4's own (`glyph` takes C-021's set, `.link`'s `style` takes C-049's).
struct CaptureUI2SectionAccessory: Codable {
    struct Meta: Codable { let value: String; let label: String; let glyph: String }
    struct Link: Codable { let label: String; let style: String }
    struct Dropdown: Codable { let label: String }   // §4: a trigger — label only
    struct Caption: Codable { let label: String; let glyph: String }
    struct Empty: Codable {}

    let none: Empty?
    let meta: Meta?
    let link: Link?
    let dropdown: Dropdown?
    let caption: Caption?
}

/// C-025 §4 `date` (legacy nested shape; row now C-023 `kind=day`) → C-070 DateBlock's own §4 props. The field names are the contract's.
struct CaptureUI2DateBlock: Codable {
    let month: String
    let weekday: String
    let day: String
    let state: String                          // "default" | "today"
}

/// C-025 §4 `details` (legacy nested shape; row now C-023 `kind=day`) → C-071 ValuePair's own §4 props. The field names are the contract's;
/// `state` takes the seven values of C-071 §3 (was summarised as C-025 §3b).
struct CaptureUI2ValuePair: Codable {
    let line1: String
    let line2: String?
    let state: String
}

/// Decodes a JSON value that may be either a display/ISO date String (the 1.0 cards) or a
/// C-070 DateBlock props object (the legacy C-025 §4 `date`; row now C-023 `kind=day`). Same either-shape pattern as
/// `CaptureDays` and `CaptureIntOrString`.
struct CaptureDateOrBlock: Codable {
    let string: String?
    let block: CaptureUI2DateBlock?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            string = s
            block = nil
        } else if let b = try? container.decode(CaptureUI2DateBlock.self) {
            block = b
            string = nil
        } else {
            string = nil
            block = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string {
            try container.encode(string)
        } else {
            try container.encode(block)
        }
    }
}

/// C-066 §4 `actions: [ActionItem]`. Its two fields are C-067 ActionMenuRow's own §4 props.
struct CaptureUI2Action: Codable {
    let glyph: String
    let label: String
}

/// C-042 §4 `indicator: (text: String, tone: positive|negative)?`. A struct only because a
/// tuple is not Codable; the field names are the contract's.
struct CaptureUI2Indicator: Codable {
    let text: String
    let tone: String                           // "positive" | "negative"
}

/// A theme choice for BlockStyleEditor's theme picker.
struct CaptureThemeOption: Codable {
    let name: String?
    let description: String?
}

/// An organization row for UserMenu (seeded into AppState.userOrganizations).
struct CaptureOrg: Codable {
    let id: String?
    let name: String?
}

/// A card image well. `kind` selects which fields apply:
///   photo → url ; icon → systemName (+ optional named bg/fg) ;
///   dateDisplay → day+month ; timeDisplay → time+period.
struct CaptureImageStyle: Codable {
    let kind: String
    let url: String?
    let systemName: String?
    let background: String?           // named color: purple|green|orange|blue|red
    let foreground: String?
    let day: Int?
    let month: String?
    let time: String?
    let period: String?
}

/// A metadata chip. The first non-nil of (badge, number, label+value, icon+value)
/// selects the DataItem flavor — see `makeDataItems` in ViewRegistry.
struct CaptureDataItem: Codable {
    let icon: String?                 // SF Symbol name (iOS)
    let value: String?
    let label: String?
    let number: String?
    let badge: String?
    let isPurple: Bool?
    // ── preview props ──
    let state: String?                // C-054 `metadata` entry → C-043 `state` (default|purple|complete; "accent" per OQ-C-043-5)
    let labelPosition: String?        // C-054 `metadata` entry → C-043 `align` (OQ-C-043-1: trailing = left, leading = right)
    let align: String?                // C-037 `chips` entry → C-043 `align` (left|right), C-043 §4's own name
}

/// A lesson activity box (CardLesson .lesson/.planning, CardEnrolled).
struct CaptureLessonActivity: Codable {
    let icon: String?                 // SF Symbol or asset name; omitted for
                                      // .lesson activities (derived from `type`)
    let type: String?
    let title: String?
    let isConfigured: Bool?
    let status: String?               // default | incomplete | complete | percent:<0…1>
}

/// A section-progress dot row (CardLesson .progress mode).
struct CaptureSectionProgress: Codable {
    let name: String
    let completed: Bool?
}

// MARK: - Group capture models

/// Group seed for pages.group-home. Scalar/string fields only (dates are
/// stamped at seed time), so it decodes with the default JSONDecoder.
struct CaptureGroup: Codable {
    let id: String
    let code: String?
    let name: String?
    let description: String?
    let coverImageUrl: String?
    let isPrivate: Bool?
    let allowInvites: Bool?
    let memberDirectory: Bool?
    let memberCount: Int?
    let creatorId: String?
}

// Pending join request seed for pages.member-requests. `createdAt` is a unix
// epoch (defaults to the fixed capture base 1_700_000_000 when omitted).
struct CaptureJoinRequest: Codable {
    let id: String
    let groupId: String
    let memberId: String?
    let firstName: String?
    let lastName: String?
    let createdAt: Double?
}

struct CaptureEnrollment: Codable {
    let id: String
    let groupId: String
    let studyProgramId: String?
    let isActive: Bool?
    let studyProgram: CaptureStudyProgramSummary?
}

struct CaptureStudyProgramSummary: Codable {
    let id: String
    let name: String
    let days: Int?
}

// MARK: - Lesson capture model

struct CaptureLesson: Codable {
    let id: String
    let dayNumber: Int
    let title: String?
    let estimatedMinutes: Int?
    let activities: [CaptureActivity]?
}

// MARK: - Activity capture models

struct CaptureActivity: Codable {
    let id: String
    let type: String
    let title: String?
    let orderNumber: Int?
    let status: String?
    let placeholder: String?
    let isHelpEnabled: Bool?
    let helpTitle: String?
    let helpDescription: String?
    let helpIcon: String?
    let readBlocks: [CaptureReadBlock]?
    let sourceReferences: [CaptureSourceRef]?
    // EditDay cards: passage label + "N min" estimate
    let passageReference: String?
    let estimatedSeconds: Int?
    // YouTube-specific fields
    let youtubeUrl: String?
    let youtubeVideoId: String?
    let youtubeThumbnailUrl: String?
    let youtubeStartSeconds: Int?
    let youtubeEndSeconds: Int?
}

struct CaptureReadBlock: Codable {
    let id: String
    let orderNumber: Int
    let title: String?
    let content: String?
    let isLocked: Bool
    let sourceReferenceId: String?
    let backgroundColor: String?
    let backgroundImageUrl: String?
    let backgroundOverlayOpacity: Double?
    let fontSize: String?
    let selections: [CaptureSelection]?
}

struct CaptureSourceRef: Codable {
    let id: String
    let passageReference: String?
    let bookNumber: Int?
    let bookName: String?
    let chapterStart: Int?
    let chapterEnd: Int?
    let verseStart: Int?
    let verseEnd: Int?
}

struct CaptureSelection: Codable {
    let start: Int
    let end: Int
    let style: String
}

struct CaptureHomeStats: Codable {
    let totalMembers: Int?
    let totalGroups: Int?
    let totalStudies: Int?
    let totalEnrolledLessons: Int?
    let heatmap: [CaptureHeatmapBucket]?
    let weeklyActivity: [CaptureDayActivity]?
}

struct CaptureHeatmapBucket: Codable {
    let day: Int
    let hour: Int
    let count: Int
}

struct CaptureDayActivity: Codable {
    let date: String
    let count: Int
}

/// Simple wrapper for heterogeneous JSON values.
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else if let v = try? container.decode(Double.self) {
            self = .double(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Discovery

struct CaptureFixtureLoader {

    /// Discovers and loads fixture JSON files from the capture/ directory.
    /// Filters by workflow and screen if environment variables are set.
    static func loadAll() throws -> [(workflow: String, fixture: CaptureFixture)] {
        let captureRoot = captureRootPath()
        let workflowFilter = ProcessInfo.processInfo.environment["CAPTURE_WORKFLOW"]?.nilIfEmpty
        let screenFilter = ProcessInfo.processInfo.environment["CAPTURE_SCREEN"]?.nilIfEmpty

        let fm = FileManager.default
        var results: [(String, CaptureFixture)] = []

        let entries = try fm.contentsOfDirectory(atPath: captureRoot)
        for entry in entries.sorted() {
            // Skip non-directories and underscore-prefixed
            var isDir: ObjCBool = false
            let entryPath = (captureRoot as NSString).appendingPathComponent(entry)
            guard fm.fileExists(atPath: entryPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard !entry.hasPrefix("_"), !entry.hasPrefix(".") else { continue }
            guard entry != "screenshots" else { continue }

            if let filter = workflowFilter, entry != filter { continue }

            let files = try fm.contentsOfDirectory(atPath: entryPath)
            for file in files.sorted() where file.hasSuffix(".json") {
                let screenName = (file as NSString).deletingPathExtension
                if let filter = screenFilter, screenName != filter { continue }

                let filePath = (entryPath as NSString).appendingPathComponent(file)
                // Decode each fixture independently: a single malformed/incompatible
                // fixture (e.g. an iPhone-first component whose `shared` shape doesn't
                // map onto CaptureComponent, or one with no ViewRegistry case yet) is
                // skipped with a note rather than aborting the whole capture run.
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                    let fixture = try JSONDecoder().decode(CaptureFixture.self, from: data)
                    results.append((entry, fixture))
                } catch {
                    print("CAPTURE: ⚠ skipping fixture \(entry)/\(file) — \(error)")
                    continue
                }
            }
        }

        return results
    }

    /// Resolves the capture/ directory path relative to the project root.
    static func captureRootPath() -> String {
        if let envPath = ProcessInfo.processInfo.environment["CAPTURE_ROOT"]?.nilIfEmpty {
            return envPath
        }
        // Fallback: assume capture repo is a sibling of the iphone repo
        let sourceFile = #file
        let testsDir = (sourceFile as NSString).deletingLastPathComponent
        let projectDir = (testsDir as NSString).deletingLastPathComponent
        let makereadyDir = (projectDir as NSString).deletingLastPathComponent
        return (makereadyDir as NSString).appendingPathComponent("capture/fixtures/iphone")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Capture sub-structs for the component.* registry cases (generated)

/// A generic list/menu row — all-optional so one shape serves InfoPanel
/// (label/value), the Navigation menus (icon/title/description), and
/// FilterChipDropdown (id/label).
struct CaptureListItem: Codable {
    let id: String?
    let icon: String?
    let title: String?
    let description: String?
    let label: String?
    let value: String?
    // ── preview props ──
    let font: String?                          // C-106 `ChipStrip.Item.font` — a C-092 font case, nil = none
}

/// A DialogOverlay action button (label + style).
struct CaptureDialogButton: Codable {
    let label: String?
    let style: String?   // primary | secondary
}

/// A Kpi sparkline trend series.
struct CaptureKpiTrend: Codable {
    let points: [Double]?
}

/// A swipeable-card action button descriptor (SwipeableCard.slideButtons).
struct CaptureSlideButton: Codable {
    let icon: String?
    let style: String?   // reschedule | delete | skip | edit
}

/// A generic chart point for bar/donut series. `color` is a hex/rgba string.
struct CaptureChartPoint: Codable {
    let label: String?
    let value: Double?
    let color: String?
}

/// A heat-map cell. `dayLabel` is decorative; positioned by week/day.
struct CaptureHeatMapPoint: Codable {
    let week: Int?
    let day: Int?
    let value: Double?
    let dayLabel: String?
}

/// One LineChart trend line.
struct CaptureTrendLine: Codable {
    let color: String?            // "solid" | "gradient"
    let solidColor: String?
    let gradientColors: [String]?
    let gradientAngle: Double?
    let lineWidth: Double?
    let dataPoints: [CaptureLinePoint]?
}

/// A LineChart data point. `date` is an ISO "yyyy-MM-dd" string.
struct CaptureLinePoint: Codable {
    let date: String?
    let value: Double?
}

/// A calendar event for CalendarEventListContent capture.
struct CaptureCalendarEvent: Codable {
    let id: String
    let title: String?
    let subtitle: String?
    let color: String?
    let dayNumber: Int?
    let coverImageUrl: String?
    let activityIcons: [CaptureCalendarActivityIcon]?
}

/// An activity-icon chip inside a calendar lesson card.
struct CaptureCalendarActivityIcon: Codable {
    let icon: String?
    let label: String?
}

/// A scripture highlight/selection span (start/end char offsets + style).
struct CaptureHighlight: Codable {
    let start: Int
    let end: Int
    let style: String?
}

/// One skeleton row for ShimmerView's "textRows" shape.
struct CaptureShimmerRow: Codable {
    let width: Int?
    let height: Int?
    let cornerRadius: Int?
    // ── preview props ──
    let label: String?                         // C-055 CategoryBarTable.Row
    let progress: Double?                      // C-055
    let countLabel: String?                    // C-055
}

/// A MenuInput option with an optional description (MenuInput .menu style).
struct CaptureMenuOption: Codable {
    let value: String
    let description: String?
}

/// A SearchableList row.
struct CaptureSearchListItem: Codable {
    let name: String?
    let hasPhone: Bool?
}

/// A SectionedTableView section.
struct CaptureTableSection: Codable {
    let title: String?
    let items: [CaptureTableItem]?
}

/// A SectionedTableView row.
struct CaptureTableItem: Codable {
    let name: String?
}

/// A right-side icon button for PageTitle.iconTitleIcons.
struct CaptureRightIcon: Codable {
    let icon: String?
    let showBadge: Bool?
}

/// One day of C-026 DualSeriesBarChart's timeline — §4 `days: [(date, scheduled, completed)]`.
/// §2: "Completed ≤ scheduled by construction."
struct CaptureUI2ChartDay: Codable {
    let date: String        // ISO yyyy-MM-dd, read as UTC
    let scheduled: Int
    let completed: Int
}

/// C-026 DualSeriesBarChart §4 `window: date range` — the visible slice, inclusive.
struct CaptureUI2DateWindow: Codable {
    let start: String       // ISO yyyy-MM-dd, read as UTC
    let end: String
}

/// C-057 PercentBar — the three ramp stops from note 2026-09-12T02:28:29.097Z ("thresholds for
/// red, yellow, and green … a value between 0 - 1 and the user can technically put them in any
/// order"). Order-independence is the VIEW's job, not this struct's: it sorts before use.
struct CaptureUI2Thresholds: Codable {
    let red: Double
    let yellow: Double
    let green: Double
}

/// C-057 PercentBar — the fill animation from note 2026-09-12T02:28:29.097Z ("filling from 0 ->
/// it's value at a duration with an easing function"). No fixture sets it: an animating bar
/// would make the simulator capture race the transition.
struct CaptureUI2FillAnimation: Codable {
    let duration: Double
    let easing: String      // "linear" | "easeIn" | "easeOut" | "easeInOut"
}

/// C-030 TimeActivityChart §4 `tickLabels: [(value: String, unit: String)]` — one tick pair.
/// §4's type is a Swift tuple, which is not `Codable`; this struct carries the same two member
/// names and the ViewRegistry case maps it back to the tuple the view's signature states.
struct CaptureUI2TickLabel: Codable {
    let value: String
    let unit: String
}

/// Decodes a JSON value that is either a plain day COUNT (1.0: CardProgramFull's "30 days")
/// or C-026's day TIMELINE. Two components legitimately spell their prop `days` and mean
/// different things; this keeps both names intact rather than renaming either.
struct CaptureDays: Codable {
    let duration: Int?
    let timeline: [CaptureUI2ChartDay]?
    // ── preview props ──
    // C-115 MonthGrid build 2026-10-21. Additive: C-115 §4 also spells its prop `days`
    // ([MonthGrid.DayEvents]), so this shape gains a third reading rather than either name
    // being bent. Tried after the two existing ones, which it can never shadow.
    var monthDays: [CaptureUI2MonthDayEvents]? = nil

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            duration = i
            timeline = nil
        } else if let days = try? container.decode([CaptureUI2ChartDay].self) {
            timeline = days
            duration = nil
        } else if let days = try? container.decode([CaptureUI2MonthDayEvents].self) {
            monthDays = days
            duration = nil
            timeline = nil
        } else {
            duration = nil
            timeline = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let duration {
            try container.encode(duration)
        } else if let monthDays {
            try container.encode(monthDays)
        } else {
            try container.encode(timeline)
        }
    }
}

/// C-115 MonthGrid §4 `MonthGrid.DayEvents` — `day` (1…31) and its C-112 `eventTypes` raw
/// values in display order; the registry case maps it to the nested model type.
struct CaptureUI2MonthDayEvents: Codable {
    let day: Int
    let eventTypes: [String]
}

/// Decodes a JSON value that may be either an Int or a String (e.g. `activeTab`,
/// an Int index for PageHeader but a string tab id for NavBar).
/// A JSON value that is either a number or a string. Exists for the same reason
/// `CaptureIntOrString` does: two contracts spell the same prop name with different types, and
/// preview-build.md §3 rule 3 forbids renaming either one to suit the struct.
struct CaptureDoubleOrString: Codable {
    let doubleValue: Double?
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let d = try? container.decode(Double.self) {
            doubleValue = d
            stringValue = nil
        } else if let s = try? container.decode(String.self) {
            stringValue = s
            doubleValue = nil
        } else {
            doubleValue = nil
            stringValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let d = doubleValue {
            try container.encode(d)
        } else {
            try container.encode(stringValue)
        }
    }
}

/// A JSON value that is either a Bool or a String. Exists for the same reason the two above
/// do: `selected` is a Bool for the 1.0 GroupCard and C-047, and a String for C-028.
struct CaptureBoolOrString: Codable {
    let boolValue: Bool?
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            boolValue = b
            stringValue = nil
        } else if let s = try? container.decode(String.self) {
            stringValue = s
            boolValue = nil
        } else {
            boolValue = nil
            stringValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let b = boolValue {
            try container.encode(b)
        } else {
            try container.encode(stringValue)
        }
    }
}

struct CaptureIntOrString: Codable {
    let intValue: Int?
    let stringValue: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            intValue = i
            stringValue = nil
        } else if let s = try? container.decode(String.self) {
            stringValue = s
            intValue = nil
        } else {
            intValue = nil
            stringValue = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let i = intValue {
            try container.encode(i)
        } else {
            try container.encode(stringValue)
        }
    }
}

/// `options` decodes a list of strings (MenuInput, C-028 and the edit-field pickers) OR a list
/// of C-036 FilterMenuOverlay.Option objects — see the RETYPED note on the field.
struct CaptureStringsOrOptions: Codable {
    let strings: [String]?
    let items: [CaptureFilterMenuOption]?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode([String].self) {
            strings = s
            items = nil
        } else if let o = try? container.decode([CaptureFilterMenuOption].self) {
            items = o
            strings = nil
        } else {
            strings = nil
            items = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = strings {
            try container.encode(s)
        } else {
            try container.encode(items)
        }
    }
}

/// C-036 §4 `FilterMenuOverlay.Option`: `id` · `label` · `glyph` (nil = no glyph box).
struct CaptureFilterMenuOption: Codable {
    let id: String
    let label: String
    let glyph: String?
}

/// `enabledDays` decodes `[Int]` (0 = Sun … 6 = Sat) OR `[String]` weekday names
/// ("sunday" … "saturday", C-127 §4 `ScheduleSummaryFooter.Weekday`) — see the RETYPED note on
/// the field. Either way it reads as the 0…6 indices; an unknown name fails the decode.
struct CaptureWeekdays: Codable, Sequence, ExpressibleByArrayLiteral {
    static let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    let indices: [Int]

    init(arrayLiteral elements: Int...) {
        indices = elements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let ints = try? container.decode([Int].self) {
            indices = ints
        } else {
            let strings = try container.decode([String].self)
            indices = try strings.map { name in
                guard let index = Self.names.firstIndex(of: name.lowercased()) else {
                    throw DecodingError.dataCorruptedError(
                        in: container, debugDescription: "enabledDays: \"\(name)\" is not a weekday name"
                    )
                }
                return index
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(indices)
    }

    func makeIterator() -> IndexingIterator<[Int]> {
        indices.makeIterator()
    }
}
