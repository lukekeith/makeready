# Select Enroll Date

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/SelectEnrollDatePage.swift`
**Type:** screen (standalone, or embedded step 2 of the enrollment flow)
**Screen states:** no-start-selected ("SELECT START DATE", Next disabled) / range-selected (highlighted week range, Next enabled) / override-confirmation dialog / overlap-warning alert

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitleLink` | Header from `config`: title + left icon + right link ("Next"), `rightLinkDisabled` until a start date is picked. |

## Notes
- This screen is almost entirely a custom UIKit calendar (`EnrollCalendarController` + `EnrollCalendarLayout` + `EnrollDayCell` + `WeekHighlightDecorationView`) bridged via `EnrollCalendarRepresentable` (`UIViewControllerRepresentable`). None of these are MakeReady SwiftUI components from the inventory — they're page-local UIKit classes.
- The bottom panel (`SelectedRangePanel`), the day-of-week picker (`DayOfWeekPicker`), and each toggle (`DayOfWeekToggle`) are page-local SwiftUI sub-views defined in this file, not shared components — call them out for web parity since the web equivalent must replicate the S-M-T-W-T-F-S circle toggles and the formatted date-range label.
- Override day selection uses a system `.confirmationDialog`; overlap detection uses a system `.alert` — both native, not custom components.
- Although it resembles `SplitMonthCalendar` / `CalendarDayCell` / `WeekdayIndicator`, this page does NOT use those components; it ships its own enroll-specific calendar stack.
