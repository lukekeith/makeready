# Member Overview (legacy)

**iPhone source:** `iphone/MakeReady/Pages/Manage/Member/MemberOverview.swift`
**Type:** screen
**Screen states:** populated only (placeholder content)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| `PageHeader` | tabs-only init (no trailing content) | Tabs `["Members", "Groups"]` |
| `NavBar` | default | Bottom nav; profile tap opens `HamburgerMenu` |
| `HamburgerMenu` | default | Presented on profile tap |

## Notes
- Marked in-source as "an older standalone page, kept for reference."
- Tab bodies are placeholder Text ("Members Content" / "Groups Content") inside a paged `TabView` — no real cards/lists.
- Owns its own `OverlayManager` and renders the overlay stack directly.
- Low parity priority; included for completeness.
