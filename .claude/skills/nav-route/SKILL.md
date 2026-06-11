---
name: nav-route
description: Add a typed navigation destination in the iPhone app (SwiftUI) — a new deep link, push-notification destination, or cross-tab jump. Routes everything through NavigationCoordinator.navigate(to:) and keeps the DeepLink switch exhaustive. Use whenever wiring "tapping X takes you to Y screen" across tabs, from a push notification, from the notification feed, or from a URL scheme in /iphone.
---

# iPhone Navigation Destination Scaffolder

You are adding a navigation destination to `/iphone/MakeReady` — "when the user taps
X (push notification / notification feed row / KPI / link), the app goes to Y."
The single mechanism is `NavigationCoordinator` (`Services/NavigationCoordinator.swift`,
Phase 3.8). **Never** set tabs/sub-tabs or present destination overlays directly from
entry-point code — that's how routing logic fragments.

## The division of labor (don't blur it)

| Concern | Owner |
|---|---|
| WHERE to go (tab, sub-tab, which entity's screen) | `NavigationCoordinator.navigate(to:)` |
| HOW a surface presents (chrome, priority, tap-outside) | `Route` + OverlayManager (`/present-overlay`) |
| PARSING external input (URL scheme, APNs payload, file) | `MakeReadyApp` / `PushNotificationManager` → a `DeepLink` case |

## Step 1 — Is this a deep link or just a jump?

- **In-app cross-tab jump** (KPI tap, button that switches tabs): you only need a
  `NavDestination` case. Skip to Step 3.
- **Externally-triggered** (push notification tap, URL scheme, file import) or
  **notification-feed row tap**: you need a `DeepLink` case too — these all funnel
  through `PushNotificationManager.shared.pendingDeepLink`, which MainView observes.

## Step 2 — Add the DeepLink case (external triggers only)

1. Add the case to `enum DeepLink` (`Services/PushNotificationManager.swift`),
   carrying the minimum identity (`case lesson(scheduleId: String)`).
2. Set it from every relevant entry point:
   - APNs payload parsing → `PushNotificationManager` (`pendingDeepLink = .lesson(...)`)
   - URL scheme / file open → `MakeReadyApp.handleDeepLink(_ url:)`
   - In-app notification rows → `NotificationFeedPage` (sets `pendingDeepLink` too)
3. **The compiler now forces Step 4** — `NavigationCoordinator.handle(deepLink:)` is
   an exhaustive switch with NO `default:`. Keep it that way; a `default:` arm is a
   review FAIL because it lets future cases ship unrouted.

## Step 3 — Add the NavDestination case + navigate arm

In `Services/NavigationCoordinator.swift`:

```swift
enum NavDestination: Equatable {
    // ...
    case lessonSchedule(enrollmentId: String)
}

func navigate(to destination: NavDestination) {
    switch destination {
    // ...
    case .lessonSchedule(let enrollmentId):
        tab = .calendar                       // 1. land on the right tab
        presentLessonSchedule(enrollmentId)   // 2. present via Route if needed
    }
}
```

Rules:
- Compose existing destinations where possible (`.joinRequests` just calls
  `navigate(to: .groupsTab(subTab: 1))`).
- Sub-tab signals are **one-shot optionals** (`groupsSubTab`) consumed and nilled by
  the receiving page — follow that pattern for new sub-tab state.
- If the destination presents an overlay, present it through `overlayManager` (the
  coordinator holds a weak ref, wired by MainView **before** any deep link is
  handled) with a **registered `Route`** — run `/present-overlay` if the surface is new.
- Destination pages presented from cold start MUST satisfy the cache-first contract
  (SWIFTUI_TRANSITIONS.md § Pre-loading Content) — a deep link can arrive before any
  cache is warm; the page shows its loading state riding the animation, never popping.

## Step 4 — Route the DeepLink (external triggers only)

Add the arm in `handle(deepLink:)`:

```swift
case .lesson(let scheduleId):
    navigate(to: .lessonSchedule(enrollmentId: scheduleId))
    PushNotificationManager.shared.clearPendingDeepLink()
```

**Clearing semantics — get this right:**
- Clear immediately after routing (the default).
- Do NOT clear when a page consumes the pending link itself — `.importFile` is the
  reference: MainLibrary observes `pendingDeepLink`, runs the import flow, and clears
  it after consuming the URL. If you copy that pattern, document WHO clears it at the
  case's arm.

## Step 5 — Before commit

- `handle(deepLink:)` still has no `default:` and compiles (exhaustive).
- Every entry point that can produce the trigger sets the same `DeepLink` case
  (APNs + URL scheme + notification feed — grep `pendingDeepLink =`).
- No entry point mutates `tab`/sub-tabs directly — everything goes through
  `navigate(to:)`.
- **Device-verify the destination one-by-one** (cold start + warm): deep links are
  capture-blind (the capture suite never goes through PushNotificationManager), and
  overlay presentation can't be verified by build-green alone.
- Run `/transition-review` if the diff touches any presentation code.
- Reference: `NavigationCoordinator.swift` header, `MODAL_GUIDE.md`, `/present-overlay`.
