# Media browser — zoomable library grid (reference)

**What this is:** the interaction pattern for browsing a large image library in MakeReady UI 2.0,
taken from Apple Photos' Library grid (iOS 26). The owner asked for it on 2026-10-30 as the basis of
a new **MediaBrowser** component. This is a behaviour reference for the grid only: the images, how
you scroll and zoom through them, and the date labels. The chrome around it (large title, filter
and Select buttons, tab bar, the Years / Months / All control, search) is out of scope. The hosting
screen's spec decides that. Tapping a tile opens the existing viewer
(`docs/ui2/references/image-viewer-zoom-dismiss.md`, §4 below).

**Source:** `~/MakeReady/Images/images.MP4`. Screen recording, 1320×2868 px (440×956 pt @3×),
60 fps, 32.2 s, library of **37,531 items**. Analysed at 4 fps (contact sheets, ±0.13 s), with four
windows re-extracted at 10 fps (±0.05 s, **bold** in the outline). Anything marked *(inferred)* could
not be seen directly in the frames and is the reading most consistent with them.

## 1. Timestamped outline

| t (s) | What is shown |
|---|---|
| 0.0–4.0 | Grid at rest at the **newest end** (bottom of the library), 5 columns. Header subtitle reads "Syncing 1 Item…". Several small pulls past the bottom: the grid lifts and black shows under the last row, then it springs back (rubber band). |
| 4.0–8.0 | Scroll up into older photos at 5 columns. The header subtitle tracks the dates on screen: "Oct 11–22, 2026" → "Oct 11–14" → "Oct 11" → "Oct 10–11" → "Oct 10" → "Oct 1–10" → "Sep 15 – Oct 9" … "Sep 7–29, 2026". |
| **8.6–9.6** | **Pinch out, 5 → ~13 columns.** For ~0.5 s both layouts are on screen at once: the 5-column grid shrinks while the denser grid fades in under it. The header's date subtitle goes, and month pills ("Aug 2026", "Sep 2026", "Oct 2026") fade in once the new level settles. |
| 9.6–10.5 | Pinched back in to 5 columns at the same place ("Sep 7–29, 2026"). Pills gone, header date back. |
| **10.8–11.9** | **Pinch out twice in one gesture:** ~8 columns with month pills (Aug, Sep, Oct 2026) → the year overview (~30+ columns, tiles a few points wide) with **year** pills ("2025", "2026"). The month pills are replaced by year pills when the level changes. |
| 12.0–13.5 | Pinch in from the year overview to ~13 columns, landing on May / Jun / Jul 2026 — the part of the library that was under the fingers. |
| 13.5–17.5 | Scroll down at month level to the newest end (Aug, Sep, Oct 2026), with a rubber band at the bottom. Several month pills are visible at once, each sitting in the grid at the row where its month starts; the topmost one stays pinned under the header. |
| 17.5–20.25 | Fast scroll up at month level: Jul → Jun → May → Apr → Mar → Feb → Jan 2026 → Dec 2025. Pills stream past; the pinned slot hands from one month to the next. |
| **20.25–21.0** | **Pinch out to the year overview** from Dec 2025 / Jan 2026 (crossfade frame at ~20.5 shows both layouts blended). |
| 21.0–24.0 | Scroll up at year level: 2025 / 2026 → 2025 → 2024 / 2025 → 2024 → 2023 / 2024. When two pills meet they sit stacked, touching, never overlapping. |
| **24.4–25.6** | **Pinch in from the year overview straight to 5 columns** in one gesture, passing through an intermediate density (~13 columns) at ~25.2. It lands on "Apr 19–26, 2025": the place under the fingers. Header date returns. |
| 25.6–28.0 | Scroll at 5 columns through Apr → May → Jun 2025. |
| 28.0–30.0 | Very fast travel at 5 columns: Aug 2025 → Sep → Dec 2025 → Feb–Mar 2026 → Jul 2026 → Oct 10, 2026 in about 2 s. Repeated flicks with momentum, not scrubbing (no scroll thumb is visible at the right edge, and the owner confirmed flicks). |
| 30.0–32.2 | Back at the newest end at rest. Header subtitle reads "37,531 Items". The last row is short (3 of 5 tiles), left-aligned. |

## 2. The behaviour, as rules

### Order and resting place

1. **Oldest at the top, newest at the bottom.** One continuous chronological list (capture date
   ascending), no row breaks between days or months at 5 columns.
2. **Opens at the newest end** — scrolled to the bottom, the last (possibly short) row sitting just
   above the bottom inset. Scrolling *up* goes back in time.
3. The last row is filled left to right; a short last row leaves the right-hand cells empty (the
   page background shows).
4. Restoring position after a zoom change or a return from the viewer keeps the same photo in view.
   The grid never jumps back to the newest end on its own.

### Tiles

5. **Square, aspect-fill, centre-cropped.** Every item gets the same square cell regardless of its
   real aspect ratio.
6. **Spacing:** at 5 columns a hairline gap (~1 pt) between tiles in both directions. At 8 columns
   and denser there is no visible gap, so the grid reads as one mosaic.
7. **Edge to edge:** tiles run to the screen edges with no side margins, and the grid scrolls under
   the translucent header and tab bar (content insets keep the first and last rows reachable).
8. **Badges only at 5 columns** (none seen at 8+):
   - video duration, bottom-right, white small semibold text with a soft shadow ("0:35", "2:22");
   - favourite heart, bottom-left;
   - a small status glyph, bottom-left, on many tiles *(meaning not identifiable from the frames)*.
9. A tile with no image yet shows a dark placeholder (dark grey, never white) so the mosaic doesn't
   flash while scrolling.

### Zoom levels (pinch)

10. **Discrete levels, not free zoom.** The grid always rests at one of a fixed set of column
    counts. Observed resting densities on a 440 pt-wide phone:

    | Level | Columns (≈) | Tile (≈ pt) | Labels | Badges |
    |---|---|---|---|---|
    | Detail | 5 | 88 | header shows the visible date range | yes |
    | Month (near) | 8 | 55 | month pills | no |
    | Month (far) | 13–15 | 30–34 | month pills | no |
    | Year overview | 30+ | ≤ 14 | year pills | no |

    *(Photos also has a 3-column level, not used in this recording.)* Column counts in the dense
    levels are estimated from frame measurements to ±1.
11. **Pinch out = more columns (zoom out); pinch in = fewer (zoom in).** The level changes while the
    fingers are still down: crossing a scale threshold commits to the next level, and one long pinch
    can step through several levels (24.4–25.6 s went year → ~13 → 5 in one gesture).
12. **The transition is a crossfade between two layouts**, ~0.4–0.5 s: the outgoing grid scales
    toward the new tile size while the incoming grid fades in over it, both visible at once. It is
    not a continuous re-layout of a single grid.
13. **Anchored on the pinch.** The photo under the fingers' midpoint stays under the fingers across
    the level change. Zooming in from the year overview lands exactly on the month that was pinched
    (Apr 2025 at 25.6 s), and zooming out keeps the same stretch of time centred.
14. Labels change with the level: the header date subtitle fades out as you leave 5 columns, month
    pills fade in at the month levels, year pills replace month pills at the overview. Labels fade
    in *after* the new level settles, not during the crossfade.

### Scrolling

15. Standard iOS vertical scrolling at every level: finger-tracked drag, momentum after a flick,
    rubber-band past either end with a spring back. No horizontal scrolling.
16. Momentum carries far at every level. At 5 columns a series of flicks crossed about a year
    (~10,000 items) in ~2 s; at the year overview one flick crosses most of a year.
17. Scrolling does not change the zoom level, and zooming does not change the scroll speed rules.
17a. **Responsiveness is a requirement** (owner, 2026-10-30: "It responded well to flicks and
    dragging, very responsive"). A drag tracks the finger with no lag, a flick starts moving on the
    first frame, and a flick during momentum adds to the speed instead of stopping it. No frame
    drops while tiles load. Image decoding and network loads never run on the main thread, and a
    tile that isn't ready shows its placeholder (rule 9) rather than holding up the scroll.

### Date labels

18. **At 5 columns: no labels in the grid.** The header subtitle shows the date range of the rows
    on screen, updating as you scroll: one day ("Oct 10, 2026"), a span within a month
    ("Oct 10–11, 2026"), or across months ("Sep 15 – Oct 9, 2026"). At rest at the newest end it
    shows the library count ("37,531 Items") or sync state. *(This subtitle belongs to the chrome,
    but the grid must publish the visible date range for it.)*
19. **At month and year levels: pill labels in the grid.** A label is a capsule: translucent
    dark fill, white semibold text (~15 pt), ~16 pt from the left edge. Text is "Mon YYYY" at month
    levels and "YYYY" at the overview.
20. **A pill overlays the tiles** — it takes no row of its own. It sits at the left of the row that
    holds the section's first item.
21. **Sticky with push-off.** The section at the top of the viewport has its pill pinned just under
    the header. When the next section's pill scrolls up to it, the two sit stacked and touching,
    and the incoming one pushes the pinned one up and out *(inferred from stacked pairs at 11.9,
    21–24 s; the frames never show an overlap)*. Scrolling the other way reverses it.
22. Several pills can be on screen at once (three or four at month level), one pinned and the rest
    in flow.

### Large library (virtualisation)

23. The grid holds 37,531 items and moves through them with no visible loading pause or blank
    rows. Only what is on screen (plus a margin) can be live; everything else has to be recycled
    or drawn cheaply.
24. Image detail follows density: the overview tiles look visibly low-resolution and smeared, so a
    tiny thumbnail tier is used there, while 5-column tiles are sharp.
25. During very fast travel some tiles show a blurry image for a frame before sharpening
    (progressive: low-res first, full tile-size next).

## 3. Building it — notes for the MediaBrowser spec

These are suggestions, not observations.

- **Layout per level:** one `UICollectionView` (or a custom layout) per level, swapped during the
  pinch, matches the crossfade in rule 12 better than one layout re-laid each frame. Keep the outgoing
  and incoming grids both mounted only for the transition, and give each the same data source.
- **Anchor maths:** on pinch begin, record the item index under the fingers' midpoint and its offset
  within the viewport. After the level commits, scroll the incoming grid so that index's row lands
  at the same y. That gives rule 13 and rule 4 for free.
- **Thresholds:** step a level when the gesture's cumulative scale passes about ×1.4 or ×0.7 from
  the current level, then reset the base scale. That makes one long pinch walk several levels
  (rule 11).
- **Thumbnail tiers:** request sizes by level (for example 32 px at the overview, 96 px at the month
  levels, 264 px at 5 columns, @3×), cache by `(id, tier)`, prefetch ahead of the scroll direction,
  and show the next-lower tier already in cache while the right one loads (rule 25). The overview
  may need pre-composited strips or a lower item budget per frame. Profile before committing.
- **Sections:** month and year sections come from the capture date. The data source needs
  `firstIndex(of: section)` for the pills and the visible date range for the header (rule 18).
- **Data paging:** 37k rows cannot be loaded up front from the API. The grid needs the total count
  and each section's count early (so the scroll height and pills are right), then pages items in by
  range as they come into view.
- **What exists today:** the old UI's Media tab uses `MediaLibraryGrid`
  (`iphone/MakeReady/Pages/Media/MediaLibraryGrid.swift`), a 3-column `UICollectionView`
  representable with paging through `mediaGridBridge` (`docs/capture/media-library.md`). It has no
  zoom levels or sections. Its paging bridge may be reusable; its layout is not.

## 4. Opening an item — the existing viewer

Tapping a tile (single tap, any level where the tile is big enough to hit — at least the 5- and
8-column levels) opens **`ImageViewer`**
(`iphone/MakeReady/UI2/Containers/Shared/ImageViewer.swift`), the viewer built for the cover
image menu's "View image" (presented there through `coverViewerPresentation` in
`CoverViewerOverlay.swift`). Its header comment already names "the media library later" as a user.
`ImageViewer` is only the viewer. How it is shown is up to the host: the group page presents it as
an overlay, while the media page hosts it directly (it was renamed from `ImageViewerOverlay` on
2026-10-30 for that reason).

- **Inputs:** `url` (the original image), `sourceFrame` (the tapped tile's frame in global
  coordinates), `accessibilityLabel`, `onClose`.
- **The grid's part:** report the tapped tile's global frame as `sourceFrame`, and draw that tile
  blank while the viewer is open and during the fly-back. The viewer grows from the tile and flies
  back into it on dismiss (viewer reference §2, rules 1–3 and 8).
- **Keep the tile in place:** the grid must not scroll or change level while the viewer is up, so
  the fly-back lands on the right frame. If the tile has scrolled off screen, pass `nil` and the
  viewer closes in place.
- **Gap:** the viewer shows one image. Swiping sideways to the next / previous item (Photos does
  this, viewer reference §3 "Horizontal paging") is not built. A MediaBrowser that wants it needs
  the viewer extended to take the list and a start index, and to report the current item back so the
  grid can scroll to it and fly back into *that* tile.
- **Video:** the viewer loads a still image. Video tiles (rule 8's duration badge) need a decision:
  play in the viewer, or open somewhere else.

## 5. Open questions for the spec

1. Which levels MediaBrowser has: all four, or fewer for a smaller library (a group's media is far
   smaller than 37k)?
2. Does MediaBrowser pick a resting level per screen (and remember the user's last level)?
3. Badges: which MakeReady states replace Photos' favourite and status glyph (video, owner,
   shared), if any?
4. Multi-select ("Select" in Photos' chrome) is out of scope here. Does MediaBrowser need a
   selection mode, and at which levels?
5. Horizontal paging in the viewer (§4 gap): in the first version or later?

## 6. Previews (owner, 2026-10-30)

The component's previews use **all 13 images the owner uploaded** as their example media, in
`~/MakeReady/Images/` (square 200×200 PNG portraits): Barry Allen, Bruce Banner, Bruce Wayne,
Clark Kent, Guy Gardner, Hal Jordan, Logan, Luke Cage, Matt Murdock, Peter Parker, Steven Strange,
Tony Stark, Wade Wilson. They get copied into the component's preview assets; nothing points at the
owner's folder.

**At least one preview per major zoom level:**

| Preview | Level | What it must show |
|---|---|---|
| Detail | 5 columns | Resting at the newest end with a short last row (rule 3), hairline gaps, and badges: at least one video duration and one favourite heart (rule 8). Publishes a visible date range, e.g. "Oct 10–11, 2026". |
| Month (near) | ~8 columns | Month pills over the grid, one pinned under the top edge and at least one more in flow (rules 19–22). No badges, no gaps. |
| Month (far) | ~13–15 columns | Several months on screen with three or more pills, and two pills stacked where one pushes the other (rule 21). |
| Year overview | 30+ columns | Year pills, two years visible ("2025", "2026"), tiny tiles reading as a mosaic. |

**Sample library:** the 13 images repeat in a fixed shuffle (not a plain 1–13 loop, so the denser
levels don't show diagonal stripes) across a made-up library with capture dates that span at least
two years and several months. That gives the month and year pills something to label. The library
has enough items to fill each level's screen several times over (the year overview needs a few
thousand).

**Image size:** at 5 columns a tile is ~88 pt, about 264 px on a 3× screen, so the 200 px
originals scale up slightly and look a little soft there. That's acceptable for previews, or
bigger copies can replace them later. The denser levels scale them down.
