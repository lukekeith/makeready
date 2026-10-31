# media-home-remake — program
> tier: program · d2m screen `media-home` (era 2.0, no Figma) · reference `docs/ui2/references/media-browser.md`

## Overview

Leaders get a working **Media** page in the iPhone UI 2.0 shell, where today the Media section of
Home's top nav shows an empty page (`UI2Shell.swift:222`). Between the shell's TopNav and TabBar,
the page has a search field, four filter chips and **MediaBrowser**: a Photos-style grid that
pinches through four zoom sizes and labels months and years. Tapping an item opens it in
**ImageViewer**. The behaviour comes from the owner's Photos recording, written up in
`docs/ui2/references/media-browser.md`.

The design is made in d2m before child 1's iPhone phase. MediaBrowser becomes a d2m component, with
previews that use the 13 portraits already in d2m's image catalog (`barry-allen` … `wade-wilson`),
one per zoom size. `/d2m:screen:create media-home` then specs the page, and `/d2m:screen:build`
builds it. This program adds the server data the page reads, the app-side container that wires the
page to live data, and the ImageViewer work.

Brainstorm record: `.builder/media-home-remake/brainstorm.md`. Nine branches settled, three of them
assumed, plus two settled at spec.

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | media-page | lg | server+iphone | A leader opens Media and browses the organization's photos in MediaBrowser: pinching through 5, ~8, ~13–15 and 30+ columns with month and year labels, searching, filtering by tags, leaders and time, ordered by the date each photo was taken, and tapping a photo to view it in ImageViewer and dismiss it back into its tile | — |
| 2 | viewer-paging-video | md | iphone | In the viewer, the leader swipes sideways through the grid's items and closes back into the tile of the one they ended on. Videos join the grid with their length badge and play in the viewer, and the Type filter appears | 1 |

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | Page body | media-home is the shell's TopNav and TabBar around C-034 SearchField, a row of C-035 FilterChip (menus in C-036 FilterMenuOverlay) and MediaBrowser. Tapping an item opens ImageViewer (`iphone/MakeReady/UI2/Containers/Shared/ImageViewer.swift`). Rejected: ImageViewer alone as the page body, which leaves nothing to browse | Luke 2026-10-30 |
| P2 | Design route | MediaBrowser is created and built as a d2m component (`/d2m-*`), specced from `docs/ui2/references/media-browser.md`. media-home is specced by `/d2m:screen:create media-home` with the owner's requirements "topnav, search + filters, MediaBrowser, bottom nav", and built by `/d2m:screen:build`. Builder never writes the design (config `design.owned_by`). Both are prerequisites of child 1's iPhone phase. Rejected: a builder spec straight into app code, which bypasses the design system | (assumed at brainstorm) |
| P3 | Zoom levels | Four resting levels: 5 columns (badges, with the visible date range published for the header), ~8 and ~13–15 columns (sticky month pills) and 30+ columns (sticky year pills). The levels change by pinch with a ~0.4–0.5 s crossfade, anchored on the pinch point (reference §2, rules 10–14). Rejected: three levels with no year view (thin today, but revisiting it costs more later); two levels (loses the zooming feel) | Luke 2026-10-30 |
| P4 | Previews | MediaBrowser has at least one preview per level, and every image in them comes from the 13 owner-uploaded portraits in d2m's image catalog, repeated in a fixed shuffle across a made-up library spanning at least two years (reference §6). Rejected: other or invented sample images | Luke 2026-10-30 |
| P5 | Ordering date | The grid runs oldest→newest by **taken-at**: the camera date (EXIF `DateTimeOriginal`) when the media has one, otherwise `createdAt`. Month and year labels and the header range use the same date. It is stored as a new nullable `Media.takenAt`, backfilled from `exifData` and set at upload. The list sorts and labels by `takenAt ?? createdAt`. Rejected: upload date only (old photos uploaded today would bunch under the current month) | Luke 2026-10-30 |
| P6 | Filters | Search matches title, description, tags and uploader name, on the phone, over the loaded list. The chips: **Tags** (multi-select, from `GET /api/media/tags`), **Leaders** (multi-select, by uploader), **Time** (single-select: All time · Last 7 days · Last 30 days · Last 90 days, applied to taken-at) and, from child 2, **Type** (single-select: All · Photos · Videos). Rejected: tags and type only (loses the old Media tab's leader and time filters) | Luke 2026-10-30 (chips) · (assumed at brainstorm) (search) |
| P7 | Media types | The grid shows photos (child 1) and videos (child 2). Audio never appears on this page. Rejected: a stand-in audio tile that plays in the viewer (absent from the reference and more to design) | Luke 2026-10-30 |
| P8 | Videos before child 2 | Child 1 shows photos only and has no Type chip. Child 2 brings in videos, their duration badges, playback and the Type chip together. Rejected: video tiles in child 1 that open as an unplayable still (reads as a bug); playback in child 1 (makes child 1 bigger and riskier) | Luke 2026-10-30 |
| P9 | Viewer paging | ImageViewer takes the grid's list and the tapped index, pages horizontally between items, reports the current item back, and dismisses into that item's tile. The grid scrolls the tile into view and hides it while the viewer is up (reference §4). Rejected: one item at a time until a later release | Luke 2026-10-30 |
| P10 | Loading | The page loads the organization's whole list from `GET /organizations/:id/media` as today, then sorts, filters and searches on the phone. Server paging is out of scope. Rejected: server paging now (a new contract, unneeded at today's sizes; dev has 30 items) | (assumed at brainstorm) |
| P11 | Responsiveness | Drags track the finger and flicks start on the first frame at every level, with no dropped frames while tiles load. Decoding and network never block the main thread, and a tile that isn't ready shows its dark placeholder (reference §2, rule 17a). Each child checks this on a device before its walk | Luke 2026-10-30 |

## Out of scope

- Audio on the Media page (P7).
- Server-side paging and search (P10).
- Select mode and acting on several items at once.
- Uploading or creating media from this page (the TopNav `+` stays as it is).
- The web client and the old app's Library → Media tab, which keep working as they are. `takenAt` is additive.
- Remembering the zoom level between launches. The page opens at 5 columns at the newest end.
