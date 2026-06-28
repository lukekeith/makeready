# Member Requests

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberRequestsPage.swift`
**Type:** screen (pushed from Member Home → Members tab)
**Screen states:** empty / populated

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` (chevron.left + "Member Requests") | Header with back/dismiss |
| `CardMember` | trailing-content init (with `ActionButton`) | One row per pending join request; passes `groups: []` |
| `ActionButton` | `.purple` (label "Respond") | Trailing content of each `CardMember` row |
| `MemberRequestRespondModal` | default | Presented when "Respond" is tapped |
| `MemberRequestProfilePage` | default | Presented when a request row body is tapped |

## Notes
- List derived reactively from `AppState.pendingJoinRequestsByGroupId`; approving/rejecting animates the card out (scale + opacity transition).
- Empty state ("No pending requests") is a hand-rolled VStack.
- Each row's metadata shows Group name + Requested date.
