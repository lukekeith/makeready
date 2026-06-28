# Groups List

**iPhone source:** `iphone/MakeReady/Pages/Main/MainGroups.swift` (thin wrapper) → `iphone/MakeReady/Pages/Manage/Member/MemberHomePage.swift` (actual content)
**Type:** tab
**Screen states:** loading (group skeletons) / empty / populated; three sub-tabs ("Groups", "Members", "Enrolled")

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs=["Groups","Members","Enrolled"] + trailing invite button | three-tab header; trailing slot presents `InviteMenu` |
| `InviteMenu` | default (`menuId: Route.groupsInviteMenu.id`) | overlay-presented from the header invite button |
| `SkeletonCardGroup` | default | initial loading placeholders for the Groups tab |
| `SwipeableCard` | with `slideButtons: [SlideButton(.delete)]` | wraps each group card and each enrolled card to expose swipe-to-delete |
| `SlideButton` | `style: .delete` | trash action revealed on swipe |
| `CardGroup` | `imageStyle: .photo(...)` or `.icon(...)`; metadata = members (+ active studies) | Groups tab rows |
| `SearchField` | default (placeholder "Search members") | Members tab; overlaid at top |
| `FilterChipDropdownTrigger` | default (label "Members"/"Non-members" filter) | Members tab filter trigger row |
| `FilterChipDropdownPanel` | default (items Members / Non-members) | expanded filter panel |
| `CardMember` | default (no-trailing-content init); `metadata` = Joined / last-action; `groups` badges on members, empty for non-members | Members tab rows (member + non-member) |
| `CardEnrolled` | default | Enrolled tab rows (study + group, lessons-left) |

## Notes
- `MainGroups` only forwards `overlayManager`, `avatarURL`, `pendingSubTab` to `MemberHomePage`; all UI lives in `MemberHomePage`.
- The `#Preview` blocks inside `MainGroups.swift` are mock reconstructions of the three tabs and additionally show `CardMember` WITH a trailing `ActionButton(variant: .purple)` ("Respond") on the Requests preview — that trailing-content `CardMember` variant + purple `ActionButton` are preview-only here, not in the live `MemberHomePage` member rows.
- Members tab list is masked with a top fade gradient; search field is a fixed overlay.
- Group cover images and member avatars are remote — parity-sensitive.
- `LessonActionMenu` is the inventory name; the header invite uses `InviteMenu` (overlay, capture separately).
