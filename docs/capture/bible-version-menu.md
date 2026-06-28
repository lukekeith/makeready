# Bible Version Menu

**iPhone source:** `iphone/MakeReady/Pages/Bible/BibleVersionMenu.swift`
**Type:** overlay/modal (dropdown popover, pure UIKit `UIView`)
**Screen states:** populated (scrollable translation list; one row shown selected)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from the custom inventory)_ | — | Entirely bespoke UIKit. |

## Notes
- `BibleVersionDropdown` is a self-contained UIKit `UIView` presented by the Bible reader as a popover anchored below the version button. It builds its own scrim, shadowed menu container, and `UITableView` of `VersionDropdownCell` rows.
- Each row (`VersionDropdownCell`, private) is a radio circle (purple-filled + white checkmark when selected, otherwise a 1px white-20% border) plus the translation full name.
- Translation list comes from `knownBibleVersions` (KJV, ASV, FBV, GNV, GNTD, LSV, WEB, WEBBE, T4T, BSB). Selection is keyed by `BibleVersion.id`.
- Animates in with a scale+fade from the anchor's top-left; dismisses on scrim tap (which also clears the parent reader's `versionDropdown`).
- No MakeReady SwiftUI components are reused here — for parity, the web equivalent must replicate the radio/checkmark selected state and the brand-purple fill.
