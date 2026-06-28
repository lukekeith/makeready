# Select Study Program

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/SelectStudyProgramPage.swift`
**Type:** screen (step 1 panel of the group→program enrollment flow)
**Screen states:** loading (4 skeleton study cards) / populated (selectable list) / empty ("No study programs found" / no search match) / error (retry) / search (shown only when >10 programs or active query) / draft-alert (native alert)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitleLink` (leftIcon `xmark`, rightLink "Next", `rightLinkDisabled` until a program is selected) | Header overlay pinned to top. |
| `SearchField` | default (`isActive: .constant(true)`, placeholder "Search programs") | Shown only when `shouldShowSearch` (query non-empty or >10 programs). |
| `CardStudySelectable` | `CardStudySelectableData` with `isPublished` (Published/Draft badge), `isSelected`, `enrolledUntilDate`, `isDisabled` | Selectable program rows. Disabled when enrollment data unloaded or already enrolled; draft (unpublished) cards stay tappable but trigger the draft alert. |
| `SkeletonCardStudy` | default | 4 shown in the loading state. |

## Notes
- `isDisabled = !isEnrollmentDataLoaded || isCurrentlyEnrolled` — all cards are dimmed/disabled until existing-enrollment data loads; enrolled cards stay dimmed and show an "enrolled until" date.
- Tapping an unpublished (draft) program shows a native `.alert` ("Draft Program") instead of selecting it — not a custom component.
- `CardStudySelectable` selection animates with `Motion.micro`; the published/enrolled state animates with `Motion.standard` on `isEnrollmentDataLoaded`.
- Error/empty states are bespoke icon+text blocks, not components.
