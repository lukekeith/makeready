//
//  ActivityNewScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen activity-new in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/lessons/{id}/preview-data ·
//  POST /api/programs/{programId}/lessons/{lessonId}/activities ·
//  POST /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities
//  (§5 API-GAP: the server enum has no value per `ActivityType` case yet — OQ-1).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// New Activity — the activity-type picker: a pushed page where the leader picks which of the
/// six activity types to add to the lesson (§1, OQ-1). Composed only of §4's C-040 PageHeader,
/// C-086 ActivityTypeGrid (→ six C-080 ActivityTypeCard) and C-081 ActivityNavBar (→ C-061
/// ActivitySlide chips + C-021 `add`). Standalone: the screen is not minted from a collection
/// (`identifiedFrom` is null), so no D7 template applies.
struct ActivityNewScreen: View {

    /// One §3 state's inputs. Every §3 state is reachable by these alone.
    struct State {
        /// C-081 `slides` ids, in lesson order — the existing activities plus the placeholder.
        var slideIDs: [String]
        /// C-081 `slides` VoiceOver labels, parallel to `slideIDs` (never rendered).
        var slideLabels: [String]
        /// C-081 `activeID` — the placeholder chip for the activity being created (§2).
        var activeID: String
        /// C-086 `pendingType` as its raw case name (`bibleVerse` … `poll`); "" = interactive.
        /// §3 Creating sets it; §3 Pressed tile renders through it too (see `pendingType` below).
        var pendingType: String
        /// §3 Error: the create failed and the "Couldn't add activity" alert is up.
        var createFailed: Bool
    }

    let state: State
    var onBack: () -> Void = {}
    var onSelect: (ActivityTypeGrid.ActivityType) -> Void = { _ in }
    var onSelectSlide: (String) -> Void = { _ in }
    var onAdd: () -> Void = {}
    var onRetry: () -> Void = {}
    var onCancel: () -> Void = {}

    // §3 Error: "a failed create shows a system alert … Retry / Cancel" — the alert's presented
    // flag is local UI state (R-31), seeded from `State`; either button dismisses it.
    @SwiftUI.State private var alertPresented: Bool

    init(
        state: State,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (ActivityTypeGrid.ActivityType) -> Void = { _ in },
        onSelectSlide: @escaping (String) -> Void = { _ in },
        onAdd: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onCancel: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onBack = onBack
        self.onSelect = onSelect
        self.onSelectSlide = onSelectSlide
        self.onAdd = onAdd
        self.onRetry = onRetry
        self.onCancel = onCancel
        _alertPresented = SwiftUI.State(initialValue: state.createFailed)
    }

    var body: some View {
        // §2: top → bottom. The system status bar (deviation 1) is the harness's, not drawn here.
        VStack(spacing: 0) {
            // §2.2: C-040 `style=Default`, `showTitle=true`, `showIcons=false`, title
            // "New activity", leading C-021 `back`; no trailing action (deviation 7, OQ-2).
            // `rightButtons: []` keeps the trailing slot empty under the view as built, which
            // still draws Default's trailing glyphs whatever `showIcons` says (stale against
            // C-040 §3's OQ-C-040-1 ruling — reported).
            PageHeader(
                style: .default,
                title: Self.title,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: onBack
            )
            .ui2Element("C-040 PageHeader")

            // §2.3: content region, padding `space-page-margin` on all four sides → C-086.
            // §2.4: the flexible space below the grid pins the bar to the bottom.
            ActivityTypeGrid(pendingType: pendingType, onSelect: onSelect)
                .ui2Element("C-086 ActivityTypeGrid")
                .padding(Token.Space.pageMargin)
                // GAP — activity-new §2: content region y 105 → 880 (775pt) between the header
                // and the bar, no spacing token. A minimum so the bar sits at the canvas bottom
                // when the harness proposes no height; flexible above it.
                .frame(maxWidth: .infinity, minHeight: Self.contentRegionHeight,
                       maxHeight: .infinity, alignment: .top)

            // §2.5: C-081 `default`, pinned to the bottom; the placeholder chip is `activeID`.
            ActivityNavBar(
                slides: slides,
                activeID: state.activeID,
                onSelectSlide: onSelectSlide,
                onAdd: onAdd
            )
            .ui2Element("C-081 ActivityNavBar")
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                 // §2 + deviation 2: page background
        // §3 Error (OQ-7): "system alert \"Couldn't add activity\" with Retry / Cancel".
        .alert(Self.errorTitle, isPresented: $alertPresented) {
            SwiftUI.Button(Self.retryLabel, action: onRetry)
            SwiftUI.Button(Self.cancelLabel, role: .cancel, action: onCancel)
        }
    }

    /// §3 Creating / Pressed tile: C-086 `pendingType` — the tapped tile at 0.6 opacity, grid
    /// not hit-testing. "" (or an unknown name) = interactive.
    private var pendingType: ActivityTypeGrid.ActivityType? {
        ActivityTypeGrid.ActivityType(rawValue: state.pendingType)
    }

    /// C-081 `slides`: every slide is a C-061 chip — `image` nil (deviation 8, D52).
    private var slides: [ActivityNavBar.Slide] {
        zip(state.slideIDs, state.slideLabels).map { ActivityNavBar.Slide(id: $0, image: nil, label: $1) }
    }

    // §2 copy.
    private static let title = "New activity"
    // §3 Error copy (OQ-7).
    private static let errorTitle = "Couldn't add activity"
    private static let retryLabel = "Retry"
    private static let cancelLabel = "Cancel"
    /// GAP — activity-new §2: content region y 105 → 880, no spacing token.
    private static let contentRegionHeight: CGFloat = 775
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case)

extension ActivityNewScreen.State {
    /// §2 "Slides in the frame": x16 existing · x53 the placeholder (active) · x90, x127 existing.
    /// Labels are VoiceOver-only; the placeholder's is the header title.
    private static let frameSlideIDs = ["activity-1", "placeholder", "activity-2", "activity-3"]
    private static let frameSlideLabels = ["Activity 1", "New activity", "Activity 2", "Activity 3"]

    /// §3 Populated — the frozen frame `default`.
    static let populated = Self(slideIDs: frameSlideIDs, slideLabels: frameSlideLabels,
                                activeID: "placeholder", pendingType: "", createFailed: false)
    /// §3 Pressed tile — the first tile (Bible verse) at 0.6 opacity, via C-086 `pendingType`.
    static let pressedTile = Self(slideIDs: frameSlideIDs, slideLabels: frameSlideLabels,
                                  activeID: "placeholder", pendingType: "bibleVerse", createFailed: false)
    /// §3 Creating — Bible verse tapped, the create in flight; the grid ignores taps.
    static let creating = Self(slideIDs: frameSlideIDs, slideLabels: frameSlideLabels,
                               activeID: "placeholder", pendingType: "bibleVerse", createFailed: false)
    /// §3 Error — the create failed; the page stays, the alert is up.
    static let error = Self(slideIDs: frameSlideIDs, slideLabels: frameSlideLabels,
                            activeID: "placeholder", pendingType: "", createFailed: true)
}

#Preview("Populated") {
    ActivityNewScreen(state: .populated)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Pressed tile") {
    ActivityNewScreen(state: .pressedTile)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Creating") {
    ActivityNewScreen(state: .creating)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("Error") {
    ActivityNewScreen(state: .error)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
