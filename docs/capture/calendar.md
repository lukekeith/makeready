# Calendar

**iPhone source:** `iphone/MakeReady/Pages/Main/MainCalendar.swift`
**Type:** tab
**Screen states:** loading (full-screen `ProgressView` over background) / populated calendar with events

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `SplitMonthCalendar` (via `SplitMonthCalendarWithBar`) | title-only convenience init: `selectedDate`, `events`, `onEventTap` | The entire screen body; collapsing month calendar + event bar. Source file `Components/Calendar/SplitMonthCalendar.swift` also defines `SplitMonthCalendarWithBar` |
| `LessonActionMenu` | default | presented via `overlayManager` on event tap (Edit Activities / Open / Share / Edit Enrollment / Delete) |
| `AddActivityMenu` | default | reached from `EditEnrollmentDayWrapper` → edit-activities flow |

## Notes
- This page is almost entirely `SplitMonthCalendarWithBar`. The `YearSelector`, `MonthSelector`, `CalendarGrid`, and `CalendarDay` structs declared lower in `MainCalendar.swift` are NOT used by `MainCalendar.body` — they are legacy/standalone sub-views (built from raw VStack/HStack/ScrollView), not custom inventory components.
- Initial loading overlays a full-screen `appBackground` + centered `ProgressView` while `calendarEvents` first loads.
- Events come from `state.calendarEvents`; tapping an event resolves `state.lessonScheduleMap` then opens `LessonActionMenu` (overlay, capture separately).
