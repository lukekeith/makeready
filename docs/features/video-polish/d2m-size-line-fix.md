# Size line placement and tracking — d2m fix (video-polish, owner phone walk 2026-11-24)

Subjects: C-093 TextSizeSlider, screen `video-editor`, screen `activities-editor`.

## What the owner saw
On the phone the new size line (C-093, 1 pt line + 12 pt dot) sits at the **top right** instead of centred on
the right of the free space, and the **dot does not follow the finger** — it jumps away.

## Cause (read in code)
- Both hosts position the slider with `.offset` + `.scaleEffect` and measure `sliderFrame` with
  `onGeometryChange` placed after them. The touch-down value is computed from `sliderFrame.minY/height`, a
  frame that does not match where the line is drawn, so the first touch jumps the value and the drag reads
  against the wrong reference (VideoEditorScreen.swift slider(unit:) / dragSlider;
  ActivitiesEditorScreen.swift ~1086-1125).
- activities-editor anchors the line to the edit slot (`editSlotY + offset`) clamped to header/container, not
  to the free space; video-editor overlays it on the positioned text object.
- Two drag gestures compete: C-093 now has its own `DragGesture` and each host adds a `highPriorityGesture`.

## Required
1. **Placement by layout, not offsets:** in both editors the line sits at the trailing edge (11 pt inset as
   now), **vertically centred in the free space** between the bottom of the header and the top of the
   bottom tools / keyboard (whatever is above the keyboard). No `.offset`/`.scaleEffect` positioning — use
   frames/padding so its laid-out frame is where it is drawn.
2. **Length fits the space:** C-093 gains an optional `length: CGFloat = 263.5` input (input-added-with-default);
   hosts pass `min(263.5, freeHeight − 32)` so the line never runs under the header or the tools.
3. **One gesture, in the line's own space:** the dot follows the finger exactly — a touch jumps the dot to the
   touch, then the dot stays under the finger (value = 1 − y / length in the slider's local space). Keep a
   single gesture: either C-093's own `onChange` (hosts drop their `highPriorityGesture`), or the host's —
   but measured in the same local space. activities-editor still writes one ObjectEdit on lift: give C-093
   an optional `onEnded: () -> Void = {}` (input-added-with-default) for that.
4. Captions: video-editor still hides the line on a caption's Edit (stylePanels false).

## Captures
Both editors' text editing with the keyboard up, the line centred on the right. 🔴 No capture plays audio.
