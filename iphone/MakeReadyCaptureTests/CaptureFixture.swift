//
//  CaptureFixture.swift
//  MakeReadyCaptureTests
//
//  JSON fixture model and loader. Discovers fixture files from the capture/ directory.
//

import Foundation

struct CaptureFixture: Codable {
    let platform: String?
    let view: String
    let output: String
    let title: String?
    let devices: [String]
    let auth: CaptureAuth?
    let state: CaptureState?
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
    // Program metadata (name, days) for pages that show the full program header
    let programName: String?
    let programDays: Int?
    // Path to a local image file (relative to capture root) to seed as the program cover image
    let programCoverImagePath: String?
    // Calendar screen: lesson/event entries to seed into AppState.calendarEvents
    let calendarEvents: [CaptureCalendarEntry]?
    // Media library screen: items to seed into AppState.mediaLibrary
    let media: [CaptureMediaItem]?
    // Search screen: mock the network so recents/results render (test-target
    // MockURLProtocol). `searchRecents` mocks GET /api/activities from seeded
    // programs/groups; `searchQuery` mocks GET /api/search + drives the query.
    let searchRecents: Bool?
    let searchQuery: String?
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
    let selected: Bool?               // GroupCard: brand overlay + check
    let size: String?                 // "Row" | "Mini"
    let pendingRequestCount: Int?     // GroupCard avatar badge
    // ── generic scalars used across assorted cards ──
    let day: Int?
    let month: String?
    let time: String?
    let period: String?
    let progress: Double?             // 0…1 progress bars
    let badge: String?                // status badge text
    let date: String?                 // ISO or display date string
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
    let days: Int?                             // CardProgramFull / EnrollmentCard
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
    let enabledDays: [Int]?

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
    let options: [String]?
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

/// Decodes a JSON value that may be either an Int or a String (e.g. `activeTab`,
/// an Int index for PageHeader but a string tab id for NavBar).
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

