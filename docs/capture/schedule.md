# Schedule

**iPhone source:** `iphone/MakeReady/Pages/View/Schedule/SchedulePage.swift` (stub) — real implementation in `iphone/MakeReady/Pages/Main/MainCalendar.swift`
**Type:** tab (Schedule tab of `MainView`)
**Screen states:** loading (initial calendar fetch) / populated (month grid) / day-expanded (event list) / lesson action menu

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SplitMonthCalendar` | convenience init (`titleOnly` collapsed header + `backLinkTitle` expanded header) — used via `SplitMonthCalendarWithBar` | `UIViewControllerRepresentable` wrapping `SplitMonthCalendarController`; split-month grid that expands into a per-day event list. |
| `CalendarBottomBar` | today-only (no `onViewModeChange`) | Floating "Today" pill; the day/week/month toggle variant is not used here. |
| `CalendarHeaderView` (`CalendarWeekdayHeader` / `CalendarMonthHeaderView` / `CalendarWeekdayHeaderView`) | default | Pinned S–M–T–W–T–F–S weekday row + inline month/year separators inside the scrolling calendar. |
| `CalendarDayCell` | default (`configure(with:isSelected:)`) | Day cells in the month grid, with today/selected states and event dots. |
| `CalendarEventListView` (`CalendarEventListContent` / `CalendarEventListReusableView`) | default | Per-day event list shown in the split "gap"; empty state when no events. |
| `CardLesson` | `mode: .lesson` | Each scheduled-lesson row in the day's event list (day number, title, date, cover image, activity icon boxes). |
| `LessonActivity` (`LessonActivityData`) | data feeds `CardLesson` activity boxes | Activity icon/type/title chips inside the lesson card. |
| `PageTitle` | `titleOnly` (collapsed) and `backLinkTitle` (expanded) | Calendar header, supplied by the `SplitMonthCalendarWithBar` convenience initializer. |
| `LessonActionMenu` | default (item style enum `LessonActionMenuItemStyle`) | Bottom action menu on lesson tap: Edit activities / Open lesson / Share / Edit enrollment / Delete. Presented via `OverlayManager`. |

## Notes
- `SchedulePage.swift` itself is a placeholder (`Text("Schedule Page - See MainView.swift...")`); the live UI is `MainCalendar`, mounted in `MainView`. Capture the `MainCalendar` rendering, not the stub.
- `MainCalendar` also defines local-only helpers (`YearSelector`, `MonthSelector`, `CalendarGrid`, `CalendarDay`) that are **not** wired into the active `SplitMonthCalendarWithBar` path and are not in the custom inventory — ignore for parity unless a separate picker view is captured.
- `CalendarEventRow` (non-lesson fallback) is a private view inside `CalendarEventListView`; the active data path produces lesson events, so `CardLesson (.lesson)` is the row to match.
- Events come from `AppState.calendarEvents` via `HomeActions().loadCalendarEvents`; tapping a lesson maps through `state.lessonScheduleMap` into the `LessonActionMenu`.
