# Confirm Enrollment

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/ConfirmEnrollmentPage.swift`
**Type:** screen (step 3 panel of the Enrollment Flow Modal)
**Screen states:** populated only (all data passed in via `EnrollmentData`; group/study cover images have their own AsyncImage empty/failure fallbacks)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitleLink` (leftIcon `chevron.left` "Confirm" rightLink) | Header: back chevron + "Confirm" link that submits the enrollment. |
| `FieldGroup` | default | Wraps the "Require response" toggle. |
| `ToggleControl` | default (title + description + `isOn` binding) | "Require response" toggle. |

## Notes
- Most of the screen is bespoke layout (overview card, members-stats card, schedule card with inline `DayCircle`, send-invites row) built from raw `VStack`/`HStack` + tokens — NOT custom components.
- `DayCircle` is a private sub-view local to this file (weekday enabled/disabled pill), not a shared component.
- Group and study cover images use raw `AsyncImage` with system-icon fallbacks (`person.2.fill`, `book.fill`), not `Avatar`/`CachedAsyncImage`.
- "Send invites" uses a raw SwiftUI `DatePicker` (`.hourAndMinute`), not `DatePickerField`.
- For parity, note the overview/schedule/stats sections are hand-rolled cards — there is no `CardGroup`/`CardStudy` reuse here.
