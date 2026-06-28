# Member Home

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberHomePage.swift`
**Type:** screen
**Screen states:** loading (skeleton / spinner) / empty / populated / error — three tabs: Groups, Members, Enrolled

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs init with trailing content | Tabs `["Groups", "Members", "Enrolled"]`; trailing slot has invite (paperplane) + add (plus) buttons |
| `InviteMenu` | default | Presented from the paperplane button (`.groupsInviteMenu`) |
| `ActionCardMenu` | default (single item: "Group") | Presented from the plus button (`.groupsAddMenu`) |
| `SkeletonCardGroup` | default | Groups tab first-load skeleton (x3) |
| `SwipeableCard` | with one `SlideButton` (delete) | Wraps group cards (Groups tab) and enrolled cards (Enrolled tab) |
| `SlideButton` | `.delete` | Trash action inside the swipeable cards |
| `CardGroup` | `.icon` and `.photo` image styles; `pendingRequestCount` badge; `isSelected: false` | Groups tab rows; badge shows pending join requests |
| `SearchField` | default (active/inactive binding) | Members tab search bar |
| `FilterChipDropdownTrigger` | default | Members/Non-members status filter trigger |
| `FilterChipDropdownPanel` | default (2 items, no clear-all) | Members/Non-members dropdown panel |
| `CardMember` | convenience init (no trailing content) | Members tab member rows and non-member rows; non-member rows pass `groups: []` |
| `CardEnrolled` | default | Enrolled tab rows |
| `UnenrollOptionsModal` | default | Presented on swipe-delete of an enrollment |
| `UnenrollConfirmation` | `.present(...)` (processing overlay) | Processing/confirmation overlay during unenroll |

## Notes
- Three-tab page; content switches by `activeTab` (no swipe between tabs to avoid conflict with swipeable cards).
- Groups tab: skeleton (x3) on cold load, empty state ("No Groups"), populated swipeable group list.
- Members tab: spinner on first load, error state with Try Again, empty state ("No members"), plus an inline "Member requests" button-card (custom HStack, not a listed component) that pushes `MemberRequestsPage`.
- Members tab has a Members / Non-members toggle; non-members render via `CardMember` with no group badges.
- Enrolled tab: empty state ("No Enrollments") or swipeable `CardEnrolled` list.
- The "Member requests" card and the various empty/error states are hand-rolled VStacks, not custom components.
- Group delete uses a native `.alert`, not a custom overlay.
