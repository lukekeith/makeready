# 08 — Transitions (measured)

Every mode change in the recording, measured from 30 fps windows (±33 ms). `t0` is the first
frame that shows any change — one frame after the touch at most. Point values are ±4 pt.
Each transition lists its participants, their individual curves, and the whole-transition
duration; a rebuild should reproduce the **ordering and overlap** first and the exact
milliseconds second.

Conventions: "fade" = opacity only; "slide" = position only; "keyboard curve" = the system
keyboard animation (iOS: ≈ 250 ms ease-out).

## 1. Blank canvas → Editing (new object)

Measured at 0.65 s (window `entry`, 0.45–1.05 s).

| Participant | Starts | Duration | Motion |
|---|---|---|---|
| Placeholder "Type something…" + caret | t0 | ≈ 100 ms | fade in 0 → 1 while rising ≈ 20 pt into the edit slot (y ≈ 264 → 244 pt) |
| Canvas scrim (≈ 50 % black) | t0 | ≈ 100 ms | fade in |
| Chip strip (fonts, Classic centered) | t0 + 33 ms | ≈ 100 ms | fade in **at its post-keyboard position** relative to the rising keyboard — it rides on the keyboard from the first frame it is visible |
| Tool row | t0 + 67 ms | ≈ 100 ms | crossfades over the composer's bottom selector, then rides the keyboard |
| Composer chrome (center "Aa" button, top-left ×, top-right settings) | t0 + 67 ms | ≈ 100 ms | fade out |
| Done (Next) | t0 + 100 ms | ≈ 100 ms | fade in top-right |
| Keyboard (+ strip + tool row on top of it) | t0 + 100 ms | ≈ 230 ms | keyboard curve; top edge 956 → 630 pt |
| Size slider | t0 + 133 ms | ≈ 130–170 ms | slide in from fully off-screen left to thumb-center x ≈ 26 pt, ease-out; thumb fades in during the slide |
| **Settled** | t0 + 330 ms | | |

Ordering that matters: the text and scrim appear *before* the keyboard moves; the slider is the
last thing to arrive. The strip and tool row are never seen at a "pre-keyboard" position — they
are attached to the keyboard's top edge for the whole rise.

## 2. Editing → Committed (Done)

Measured three times: 7.73 s (window `commit1`), 54.6 s (`commit2`), 59.58 s (`commit3`).

| Participant | Starts | Duration | Motion |
|---|---|---|---|
| Caret | t0 | 0 | removed |
| Size slider | t0 | ≤ 67 ms | slides out left / fades (gone by the second frame) |
| Keyboard (+ strip + tool row) | t0 + 33 ms | ≈ 130–200 ms | keyboard curve down; the strip and tool row ride it and fade over the last ≈ 100 ms |
| Scrim | t0 + 33 ms | ≈ 150 ms | fade out |
| Done | t0 + 33 ms | ≈ 100 ms | fade out; composer chrome (right rail, bottom bar, ×) fades in over the same window |
| **The object** | t0 + 33 ms | ≈ 150 ms | **animates from the edit slot to its canvas transform**: position from (slot x by alignment, y ≈ 244 pt) to `transform.position`; scale from 1.0 to `transform.scale`; rotation from 0 to `transform.rotation`. Single ease-out; all three interpolate together (54.5 s mid-frame: the Pixel object is at ≈ 1.5× between 1.0 and its 2.0 canvas scale and halfway down) |
| **Settled** | t0 + 170 ms (`commit2`, `commit3`); ≈ 250 ms in `commit1` where the keyboard dismissal read slower at 4 fps | | |

Where a **new** object lands: the first Done (7.75 s) put the object at y ≈ 37 % of the screen
height (≈ 355 pt), x-center — i.e. ≈ 110 pt below the edit slot. That is the editor's default
canvas slot for an object that has never been dragged. On every later Done the object returned to
wherever it had been dragged/pinched/rotated to.

## 3. Committed → Editing (tap object)

Measured at 12.75 s (window `reenter1`) and 57.28 s (`reenter2`).

| Participant | Starts | Duration | Motion |
|---|---|---|---|
| Scrim | t0 | ≈ 100 ms | fade in |
| Chip strip (fonts, current font centered) + tool row | t0 | ≈ 100 ms | fade in at the canvas bottom, already attached to the keyboard's top edge |
| Composer chrome (right rail, bottom bar, ×) | t0 | ≈ 100 ms | fade out; Done fades in top-right |
| Keyboard | t0 + 33 ms | ≈ 170 ms | keyboard curve up |
| **The object** | t0 + 33 ms | ≈ 130–170 ms | animates from its canvas transform to the edit slot: scale → 1.0, rotation → 0, position → slot (`reenter1`: moves up ≈ 110 pt and shrinks from 2.0× to 1.0×; `reenter2`: moves up ≈ 100 pt) |
| Size slider | t0 + 67 ms | ≈ 130 ms | slide in from the left edge |
| Caret | on settle | 0 | appears at the end of the text |
| **Settled** | t0 + 170–200 ms | | |

This is the exact inverse of §2, with the same participants and durations; the slider is again
the last to arrive. There is no intermediate "selected" state: tap goes straight to Editing.

## 4. Category switch (Aa ↔ //A ↔ ✦ ↔ color)

Measured at 14.0 s (window `menuswitch`): fonts → animations.

| Participant | Duration | Motion |
|---|---|---|
| Strip contents | ≤ 33 ms | swap (at most a one-frame crossfade); the new strip is already scrolled so its selected chip is centered |
| Highlight pill on the tool icon | ≤ 33 ms | jumps to the new icon (no slide) |

The prior recording measured the same switch at ≈ 100 ms with 15 fps sampling; at 30 fps it is
one frame or less. Build it as an instant swap or a ≤ 100 ms crossfade — never a slide.

## 5. Chip selection within a strip

4 fps sampling only: every frame after a chip tap already shows the tapped chip centered or
within a few points of center, and the object already restyled. Scroll-to-center ≈ 150 ms
ease-out (upper bound 250 ms); restyle is immediate.

## 6. Instant-action tools (alignment, label)

0 ms: the object re-renders on the tap frame; the icon glyph morphs over ≈ 100 ms (4 fps
estimate from the mid-morph icon at 46.25 s).

## 7. Idle → Manipulating (gesture start)

Measured at 60.37 s (window `dragdelete`) and 61.5 s (`rotate`).

| Participant | Starts | Duration | Motion |
|---|---|---|---|
| Object | first moved frame | 0 | follows the finger(s) with no settle animation |
| Composer chrome (×, right rail, bottom bar) | ≈ +67 ms after movement starts | ≈ 100 ms | fade out |
| Delete target ("Drag to delete" + trash) | ≈ +67–100 ms | ≈ 100 ms | fade in at bottom center — **one-finger drag only** |
| Center guide | when the object center enters snap range | 0 | appears/disappears with no fade |

## 8. Manipulating → Idle (release)

4 fps only: the object stays at its released transform with no settle; the delete target and
guide disappear on the release frame; the composer chrome fades back in over ≈ 250 ms
(10.25 s → 11.25 s).

## 9. Summary table

| Transition | Total | Longest participant | Must-keep ordering |
|---|---|---|---|
| Blank canvas → Editing | ≈ 330 ms | keyboard (230 ms) | text + scrim first; strip/tool row attached to keyboard; slider last |
| Editing → Committed | ≈ 170–250 ms | keyboard (130–200 ms) | slider gone first; object transform, scrim and keyboard together |
| Committed → Editing | ≈ 170–200 ms | keyboard (170 ms) | scrim + strip first; object un-transforms with the keyboard; slider last; caret on settle |
| Category switch | ≤ 33 ms | — | instant |
| Chip select | ≈ 150 ms | strip scroll | restyle immediately, scroll to center |
| Gesture start | ≈ 100 ms | chrome fade | object moves on frame 1; chrome/target follow |
| Gesture end | ≈ 250 ms | chrome fade | no object settle |
