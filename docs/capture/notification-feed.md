# Notification Feed

**iPhone source:** `iphone/MakeReady/Pages/Notifications/NotificationFeedPage.swift`
**Type:** overlay/modal (in-app notification feed)
**Screen states:** loading (spinner, first load only), empty ("No notifications yet"), populated (list of rows)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitleLink` | Title "Notifications", left icon `xmark` (dismiss), right link "Mark all read" — the right link is shown only when `unreadNotificationCount > 0` (passed as `""` otherwise, which renders no link). |

## Notes
- `NotificationRow` is a `private struct` defined in this same file, not a Components/ component. Per-row states: read vs unread (unread → semibold title, white-3% row background, brand-purple unread dot); icon varies by `notification.type` (`person.badge.plus` for JOIN_REQUEST, `person.badge.checkmark` for MEMBER_JOINED, else `bell.fill`).
- Empty state is inline `bell.slash` SF Symbol + text.
- Reads directly from `AppState.shared.orderedNotifications`; tapping a row marks read and routes via `PushNotificationManager` deep links.
