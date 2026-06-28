# Select Group

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Enrollment/SelectGroupPage.swift`
**Type:** screen (step 1 panel of the program→group enrollment flow)
**Screen states:** loading (4 skeleton group cards) / populated (selectable list) / empty ("No groups found" / no search match) / error (retry) / search (shown only when >10 groups or active query)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitleLink` (leftIcon `xmark`, rightLink "Next", `rightLinkDisabled` until a group is selected) | Header overlay pinned to top. |
| `SearchField` | default (`isActive: .constant(true)`, placeholder "Search groups") | Shown only when `shouldShowSearch` (query non-empty or >10 groups). |
| `CardGroup` | `CardGroupData` with `imageStyle: .photo(...)` or `.icon(systemName: "person.2.fill", backgroundColor: .purple)`; `isSelected` toggled; `metadata` = members (+ enrollments) | Selectable group rows; already-enrolled groups get `onTap: nil` and 0.5 opacity. |
| `SkeletonCardGroup` | default | 4 shown in the loading state. |

## Notes
- Already-enrolled groups (in `enrolledGroupIds`) are dimmed (opacity 0.5) and non-selectable.
- `CardGroup` image style branches on whether `coverImageUrl` is present (photo vs purple person.2 icon).
- Metadata is dynamic: always "Members", plus an "Enrollment(s)" item when the group has active enrollments in cache.
- Error/empty states are bespoke icon+text blocks, not components.
