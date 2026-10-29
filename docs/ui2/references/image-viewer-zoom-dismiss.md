# Image viewer — zoom and drag-to-dismiss (reference)

**What this is:** the interaction pattern for viewing one image full screen in MakeReady UI 2.0,
taken from Apple Photos (iOS 26). The owner asked for it on 2026-10-28 for the cover viewer ("View
image" in the cover menu on group and program pages) and to reuse it in the media library
(`media-home`). This is a behaviour reference, not a screen design. MakeReady's chrome (header,
toolbar) is whatever the hosting screen's spec says. The motion and gestures below are what carries
over.

**Source:** `~/MakeReady/Design reference/dissmissing images.MP4`. Screen recording, 1320×2868,
60 fps, 16.9 s. Analysed at 4 fps (contact sheets, ±0.3 s), with three windows re-extracted at
20 fps (±0.05 s, **bold** in the outline).

## 1. Timestamped outline

| t (s) | What is shown |
|---|---|
| 0.0–1.75 | Photos library grid at rest. |
| **1.80–2.05** | **Open:** a grid tile is tapped. The image grows from the tile's frame to fit the screen, the black backdrop fades in over the grid, and the viewer chrome (back, title pill, ⋯, filmstrip, toolbar) fades in. Settled at ~2.05 (≈0.25 s). |
| 2.05–2.75 | Viewer at rest. The grid tile it came from is blank (black) underneath. |
| 2.75–4.85 | **Slow drag down, then around.** The chrome is gone the moment the drag starts. The image follows the finger 1:1 in x and y and shrinks as it moves down. The backdrop fades with the drag, so the grid shows through, dim at first and fully visible by ~3.75. The source tile stays blank the whole time. |
| **4.85–5.00** | **Release → dismiss:** the image flies from under the finger into the source tile's frame (≈0.15 s, no overshoot visible) and the tile is filled again. |
| 6.0–6.25 | The same photo opens again. |
| **6.75–6.95** | **Quick flick down:** released almost at once with a fast downward swipe. The image shrinks and travels into its tile in ≈0.2 s while the backdrop goes from black to clear. Nothing waits for a drag distance: velocity alone dismisses. |
| 7.5–8.0 | A different photo (landscape) opens from another tile. |
| 8.25–8.75 | Drag down and release: dismissed into its tile (that tile is blank until it lands). |
| 10.0–10.5 | A portrait photo opens. At 10.5 a small sideways drift with the chrome still up and the backdrop still black. In Photos this is the start of a horizontal page swipe, not a dismiss. |
| 10.75–12.25 | Drag down to the bottom of the screen, release: flies back into its tile (row 4, col 1), which is blank until ~12.25. |
| 13.0–14.0 | A landscape photo opens (backdrop and chrome fading in over the dimmed grid at 13.0), is dragged down and right, and dismisses into its tile. |
| 14.0–16.9 | Grid at rest. |

## 2. The behaviour, as rules

**Open (from a source frame):**
1. The image starts at the source's frame on screen (the tile, or the cover) and animates to its
   fitted frame: aspect-fit, centred in the safe area. Duration ≈0.25 s, a critically damped spring
   (no visible overshoot).
2. The backdrop fades from clear to the viewer's background over the same time. The chrome fades in
   alongside.
3. The source is hidden (drawn as its empty look) from the moment the viewer opens until the image
   lands back in it.

**Drag to dismiss (at 1× zoom only):**
4. A vertical-dominant drag starts a dismiss. The chrome hides immediately.
5. The image is offset 1:1 with the finger in **both** x and y. A drag that began downward may then
   wander sideways or back up.
6. The image scales down with the drag's downward distance: `scale = max(minScale, 1 − dy⁺ / H)`,
   where `dy⁺` is the downward translation (upward drags don't grow it past 1) and `H` is the
   viewer's height. In the recording the image is about 0.75× by the time the finger has moved a
   third of the screen. Floor `minScale ≈ 0.5`.
7. The backdrop's opacity falls with the same progress, reaching 0 by about 40% of `H`, so the page
   underneath shows through.
8. **Release:**
   - **Dismiss** when the downward translation is more than ~15% of `H`, **or** the downward
     velocity is more than ~800 pt/s (the 6.75 s flick). The image flies from where it is into the
     source frame with a fast spring (≈0.15–0.2 s, no overshoot). The backdrop goes to 0 and the
     source reappears when the image lands. Hide the viewer only after the flight completes.
   - **Cancel** otherwise. The image springs back to its fitted frame at scale 1, and the backdrop
     and chrome return.
9. **No source frame** (the source has scrolled off screen, or there never was one): dismiss by
   continuing the image's motion off the bottom of the screen while it fades, ≈0.2 s.

**Zoom (not shown in the recording; standard Photos behaviour the owner asked for):**
10. Pinch zooms around the pinch centre, from 1× up to 4×. During the pinch the image may go below
    1×, and it springs back to 1× on release.
11. When zoomed in, a one-finger drag pans, clamped so the image edges can't pull inside the
    viewport. Panning carries momentum.
12. Double-tap toggles between 1× and 2.5×, centred on the tapped point.
13. While zoomed in (> 1×), a drag pans instead of dismissing. The dismiss gesture (rules 4–8) only
    exists at 1×.
14. A single tap toggles the chrome (Photos hides it). The viewer closes by drag-to-dismiss or by
    the chrome's close/back control. Tapping the backdrop does not close it.

## 3. Mapping to MakeReady

- **The cover viewer today** (`iphone/MakeReady/UI2/Containers/Groups/CoverViewerOverlay.swift`,
  group-cover-image D8) crossfades in, and closes on any tap or a straight downward drag past
  80 pt, with no zoom and no flight back to the cover. This pattern replaces it.
- **Source frames:** the cover viewer's source is the C-087 cover on the group or program page. A
  media-library grid's source is its tile. The screen has to report the source's on-screen frame
  (in global coordinates) so the viewer can open from it and fly back to it. A d2m screen exposes
  this as a frame callback; the viewer itself is app-side.
- **Motion tokens:** the open (≈0.25 s) and the dismiss flight (≈0.15–0.2 s) are springs with no
  overshoot. Use the motion tokens where a match exists (`Token.Motion`), and record a GAP where
  none does.
- **Horizontal paging** (10.5 s) belongs to the media library's multi-image viewer, not to the
  single-cover viewer.
