# Video Source Menu

**iPhone source:** `iphone/MakeReady/Pages/Video/VideoSourceMenu.swift`
**Type:** overlay/menu (inline popup)
**Screen states:** populated (always shows all four `VideoSource` rows; selected row has a checkmark)

## Components

| Component | Variant(s) used | Notes |
|---|---|---|
| _(none from inventory)_ | — | Self-contained menu; no nested custom components. |

## Notes
- Single-form component (`isPresented`, `selectedSource`, `onAlbumsSelected`, `anchorY`). 220pt-wide ultra-thin-material rounded card with a `Color.white.opacity(0.1)` hairline border.
- Rows are driven by `VideoSource.allCases` — `.videos` ("Videos", `play.rectangle`), `.favorites` ("Favorites", `heart`), `.makeReady` ("MakeReady", custom `MRLogo` image), `.allAlbums` ("All albums", `square.grid.2x2`). Each row: icon + label + trailing checkmark when it equals `selectedSource`.
- Behavior: `.videos` and `.allAlbums` set the selection (the latter also fires `onAlbumsSelected`); `.favorites` and `.makeReady` are placeholders that just dismiss ("coming soon").
- Mounted inline below `VideoSourceBar` inside `SelectVideoPage` (not via `OverlayManager`). Fully static and capturable; the `#Preview` shows it with `.videos` selected.
