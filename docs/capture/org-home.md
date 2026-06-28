# Org Home

**iPhone source:** `iphone/MakeReady/Pages/Manage/Org/OrgHomePage.swift`
**Type:** screen (overlay-presented from UserMenu via `.orgHome`)
**Screen states:** Details tab (populated) / Group Leaders tab — loading (ProgressView) / error / empty / populated

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageTitle` | `iconTitle` | org name title + left dismiss icon |
| `TabSlider` | default | tabs: Details / Group Leaders |
| `Avatar` | `.md` size | leader avatar in each `leaderRow` (photo → initials fallback) |

## Notes
- Details-tab `detailRow(label:value:)` and Group-Leaders `leaderRow(leader:)` are raw HStack/VStack layouts in-file (not inventory components); leader rows separated by `Divider`.
- Loading/error/empty states for the Group Leaders tab are plain ProgressView / Text placeholders.
- No drag-reorder or form inputs on this screen.
- No `#Preview`.
