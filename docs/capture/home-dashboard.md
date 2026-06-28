# Home Dashboard

**iPhone source:** `iphone/MakeReady/Pages/Main/MainHome.swift`
**Type:** tab
**Screen states:** loading (charts skeleton + activity skeleton) / empty (zeroed KPIs, "No activity / No lesson activity" overlays) / populated / two sub-tabs ("Home", "Activity")

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs=["Home","Activity"] + trailing `+` button | sticky two-tab header; trailing slot holds a custom add button |
| `Kpi` | `variant: .iconValue`, `valueType: .number` (×4: Members, Groups, Enrolled Lessons, Studies) | 2×2 `LazyVGrid`; each KPI wrapped in a Button → `onKPITap` |
| `CardLesson` | `mode: .lesson`, activities `status: .incomplete` | "Upcoming Lessons" section; renders cover image, day number, activity icon boxes |
| `VerticalBarChart` | default (`showValues` true when data present, `chartHeight: 160`) | "Last 7 Days" bar chart; empty state overlays a "No activity" label on zeroed bars |
| `HeatMapChart` | default (`showDayLabels: false`, `chartHeight: 576`, x=weekday labels, y=24 hour labels) | "Activity Heatmap"; empty state overlays "No lesson activity yet" |
| `SearchField` | default (placeholder "Search activity") | Activity tab only; overlaid at top with fade gradient |
| `CardActivity` | default | Activity tab feed rows; infinite-scroll list |
| `LessonActionMenu` | default | presented via `overlayManager` on lesson tap (Edit Activities / Open / Share / Edit Enrollment / Delete) |
| `AddActivityMenu` | default | reached from `EditEnrollmentDayWrapper` → edit-activities flow |

## Notes
- Two sub-tabs share the page; Home tab = KPI grid + Upcoming Lessons + charts, Activity tab = search + paginated `CardActivity` feed (AUTH-category logs filtered out).
- Charts gate on `state.homeStatsLoaded`; before loaded they show a plain `chartLoadingState` rectangle (not a Skeleton* component). Activity tab loading uses an inline hand-rolled skeleton card, not a `Skeleton*` component.
- Empty charts still render the chart component with zeroed data plus an overlaid text label.
- `CardLesson` cover images are remote (`coverImageUrl`) — parity-sensitive.
- `LessonActionMenu` / `AddActivityMenu` are overlay-presented, not inline; capture separately if needed.
