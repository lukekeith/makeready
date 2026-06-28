# Lesson Detail (Search)

**iPhone source:** `iphone/MakeReady/Pages/Search/LessonDetailPage.swift` (`struct SearchLessonDetail`)
**Type:** overlay/modal wrapper (opened from a global-search lesson result)
**Screen states:** populated (lesson found → renders EditDay), loading (spinner while fetching program), error ("Lesson not found")

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `EditDay` | default | Full lesson editor page (`iphone/MakeReady/Pages/Manage/Program/EditDay.swift`). Receives `programId`, `lesson`, `onLessonUpdated`, `onShowAddActivityMenu: nil`, and an `isPresented` binding that triggers `onDismiss`. Not in the Components/ inventory — it is a reused editor page with its own component composition. |

## Notes
- This file is a thin wrapper that resolves the `Lesson` (plus its activities) from AppState and delegates entirely to `EditDay`. For full component parity, document `EditDay` separately.
- Loading and "Lesson not found" fallbacks are inline `ZStack` + ProgressView / SF Symbol, not shared components.
