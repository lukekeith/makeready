# Group Members

**iPhone source:** `iphone/MakeReady/Pages/Manage/Group/Member/GroupMembersPage.swift`
**Type:** screen (right-pane push within GroupHomePage; also self-contained header)
**Screen states:** loading (ProgressView, only when no cache) / error / empty ("No members") / populated / no-search-results / search field disabled when no members

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitle` | Header: "Members" + chevron.left back icon. |
| `SearchField` | default | Members search (`isActive` / `searchText` / `isFocused` bindings); dimmed + hit-testing disabled when no members. |
| `CardMember` | trailing-content init (with `ActionButton`) | Pending join-request rows; trailing "Respond" button. |
| `CardMember` | plain init (no trailing content) | Member rows (sorted, filtered by search). |
| `ActionButton` | `.purple` | "Respond" button embedded as `CardMember` trailing content. |

## Notes
- Two sections: "Requests" (only when join requests exist) and "Members"; the "Members" header only renders when requests are also present.
- `requestRow` uses the `CardMember` generic init that takes `@ViewBuilder trailingContent`; `memberRow` uses the non-trailing init.
- Tapping a request opens `MemberRequestProfilePage`; "Respond" opens `MemberRequestRespondModal`; tapping a member opens `MemberProfilePage` (all via overlayManager).
- Card metadata uses `DataItem` (Requested / Joined dates) — a data struct, not a component.
