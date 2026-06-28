# Study Program Home

**iPhone source:** `iphone/MakeReady/Pages/Main/StudyProgramHome.swift` (struct `MainPrograms`; also defines `ProgramHomeModalContent`)
**Type:** tab
**Screen states:** loading (study skeletons) / empty / populated; two sub-tabs ("Programs", "Enrolled")

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs=["Programs","Enrolled"] + trailing import button | trailing slot is a single import (square.and.arrow.down) button |
| `SkeletonCardStudy` | default | Programs tab initial-load placeholders (×2) |
| `SwipeableCard` | with `slideButtons: [SlideButton(.delete)]` | wraps both program cards (Programs tab) and enrolled cards (Enrolled tab) |
| `SlideButton` | `style: .delete` | trash → delete program / unenroll |
| `CardStudy` | default; `imageStyle: .photo`/`.icon`, `status: .confirmed`, metadata = days + enrollment count + Published/Draft badge (badge can be a `DataItem(loading:)` skeleton while counts load) | Programs tab rows |
| `CardEnrolled` | default | Enrolled tab rows (study + group, lessons-left computed) |
| `Kpi` | `variant: .iconValue`, `valueType: .number` (Days/Activities/Read/Video/Write/Read Blocks/Scriptures) | inside private `ImportConfirmOverlay` import-preview grid (conditional rows) |
| `ConfirmationOverlay` | `style: .success` | shown after a confirmed import (overlay-presented) |
| `UnenrollConfirmation` | `present(...)` with `option` (`.fullRemoval` / `.cancelFuture`) | confirmation flow after unenroll modal |
| `AddActivityMenu` | default | reached via `ProgramHomeModalContent` → `ProgramHomePage` add-activity callback |

## Notes
- `MainPrograms` is the standalone Study Programs page (hamburger-menu / modal route), distinct from the Library tab's Programs view in `MainLibrary.swift`; the two share the import overlay + `CardStudy`/`CardProgramFull` family but use different card components (`CardStudy` here vs `CardProgramFull` in Library).
- Tapping a program presents `ProgramHomePage` via `overlayManager` (route `.programHome`, wrapped by `ProgramHomeModalContent`) — capture that page separately.
- Tapping the Enrolled trash presents `UnenrollOptionsModal` (`.unenrollOptions`), then `UnenrollConfirmation.present(...)`.
- `ImportConfirmOverlay` is a private modal struct (not inventory) hosting `Kpi` rows; `ConfirmationOverlay` is the inventory success confirmation.
- Empty states (`emptyStateView`, `enrolledEmptyState`) are plain SF Symbol + text, no inventory component.
- Program/group cover images are remote — parity-sensitive.
