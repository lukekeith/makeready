---
name: ios-error-surface
description: Route a caught error in the iPhone app (SwiftUI) to the error channel correctly — decide whether it surfaces the top error banner, stays console-only, or carries a retry. Use whenever writing or reviewing a catch block in /iphone, wiring failure handling for a user action (save/upload/delete/send), or when a failure currently vanishes into NSLog.
---

# iPhone Error Surface

You are handling a failure in `/iphone/MakeReady`. The app has exactly **one**
error channel: `AppState.recordError(_:context:surface:friendlyMessage:retry:)`,
rendered by `ErrorBannerHost` (top banner, mounted once in MainView, above all
overlays). Decision Point A resolved 2026-06-11: **top banner; user-initiated
failures only; auto-dismiss 4s + swipe-up/tap; optional retry.**

## The rule for every `catch`

Every new catch block does ONE of these — silent `NSLog`-and-move-on is a
review FAIL (and the SwiftLint gate blocks new NSLog anyway):

1. **Route to the channel** — `state.recordError(error, context: "Type.method", ...)`
2. **Recover meaningfully** — the catch genuinely handles it (fallback value,
   cached path, retry loop). No recording needed.
3. **Justify staying silent** — a comment explaining why this failure is
   genuinely ignorable (e.g. fire-and-forget analytics): `// Silent: <why>`

## Decision: does it surface?

```
Did the USER just ask for this operation (tapped Save/Upload/Delete/Send/
Create, submitted a form)?
├─ YES → surface: true, with a friendlyMessage
│        └─ Can the operation safely re-run as-is? → pass retry:
└─ NO (background refresh, prefetch, cache warm, telemetry)
         → surface: false (the default). Console-only.
            The cache-first contract means users are looking at valid
            cached content when a silent refresh fails — never toast them
            for a network blip they can't perceive.
```

## Surfaced errors — the contract

```swift
state.recordError(
    error,
    context: "GroupHomePage.saveGroup",        // Type.method, greppable
    surface: true,
    friendlyMessage: "Couldn't save group changes",  // user-facing words
    retry: { performGroupSave(currentGroup, imageToUpload: image) }  // optional
)
```

- **`friendlyMessage` is required in spirit** for surfaced errors — raw
  `localizedDescription` is for logs, not users. Pattern: "Couldn't <verb>
  <object>" — short enough for two banner lines.
- **`retry` only when safe to re-run**: idempotent updates by id, uploads of
  still-captured data, create operations the user just confirmed. The closure
  must capture VALUES (the data being saved), not rely on view state that the
  optimistic UI already cleared. If the operation needs one-shot UI resets,
  split them out (see `GroupHomePage.performGroupSave` — the reference
  implementation, extracted exactly so retry can re-run the work without
  re-running the navigation).
- **State cleanup happens before recording** — reset spinners/pending flags in
  the same MainActor block, then record. The banner must not appear over a
  stuck processing state.

## What NOT to do

- **No ad-hoc error UI** — no per-page error toasts, alerts for recoverable
  failures, or second banner hosts. One channel, one banner.
  (Pages' full-screen error STATES for cold-load failures — the
  "Try Again" empty states — are different and stay: they're content, not
  notifications.)
- **No surfacing background work** — `surface: true` on a refresh/prefetch is
  a review FAIL.
- **No `try?` to dodge the decision** on user-initiated paths — swallowing a
  save failure silently loses user data. `try?` is fine for genuinely
  optional side effects (and prefetches), per rule 3's justification comment.

## Before commit

- Every new `catch` matches one of the three forms above.
- Surfaced sites: friendlyMessage present, retry captures values not stale
  view state, cleanup precedes recording.
- Reference: `AppState.recordError`, `ErrorBanner.swift`,
  `GroupHomePage.performGroupSave` / `createEnrollmentInBackground`.
