# Profile

**iPhone source:** `iphone/MakeReady/Pages/Profile/ProfilePage.swift`
**Type:** overlay/modal (My Profile page)
**Screen states:** populated (when `authManager.currentUser` exists). Dev-only Environment section shown when `Configuration.devMode` is true. No standalone loading/empty states (renders nothing if no current user).

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `.iconTitle` | Title "My Profile", left icon `xmark`, `onIconTap` dismisses `.profilePage`. |

## Notes
- `ProfileSection` (and its `ProfileItem` model) are defined in this same file, not a Components/ component. Used for the "Account Details" and "Settings" cards (icon + label + value rows with dividers).
- Avatar is an inline `AsyncImage` (120px circle, initials fallback) — NOT the shared `Avatar` component.
- The Environment selector, Server IP field, and API/Client port fields are all inline dev-mode UI (radio rows, raw `TextField`s) — not shared components; gated behind `Configuration.devMode`.
- Environment health checks ping `/health` directly via URLSession (sanctioned exception), showing yellow/green/red status dots.
