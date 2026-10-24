# 02 — Adding and editing text

Covers: entering the editor from the blank canvas, the placeholder, typing, the caret, the size
slider, Done, and re-opening an existing object. Transition timings live in `08`; this file says
*what* happens, `08` says *when*.

## 1. Entering from the blank canvas

Reference: 0.65 s (entry), `assets/reference-frames/00-idle-canvas.jpg` → `01-editor-entry-empty.jpg`.

1. The user taps anywhere on the canvas that is not an existing object. A single tap; no
   long-press and no double-tap is involved.
2. A **new text object** is created with the defaults in `01` §1 and the editor opens in Editing
   mode with that object.
3. The keyboard rises immediately (no second tap into a field is needed): the object is
   first-responder from the moment it exists.
4. The placeholder **"Type something…"** is shown in the edit slot, in the default font, at the
   default size, in the default color at reduced opacity (≈50 %), with the caret before it.
5. The tool row opens on the **fonts** category with `Classic` selected and centered in the strip.

The tap location does **not** position the object — the object always opens in the edit slot and
lands at the canvas default slot on Done (see `08` §2). Position is set afterwards by dragging.

## 2. Typing

Reference: 3.0–7.0 s, `02-typing.jpg`.

- Characters append at the caret; the placeholder disappears on the first character and returns
  if the text becomes empty (returning not demonstrated — inferred from the placeholder rule).
- Text is **center-aligned within the edit slot** by default and grows outward from the center
  as it is typed (3.25 s "Te" → 6.0 s "Test content": the text's center stays at x-center).
- Line wrapping: the slot is ≈ full canvas width minus side margins; a line longer than that wraps
  (not demonstrated with a wrap — the test string fits one line; the wrap width is inferred from
  the left/right alignment margins ≈24 pt).
- Return inserts a new line (keyboard shows the return key; not demonstrated).
- Font, color, alignment, label, animation and effect changes made while typing apply to the
  **whole object** — there is no per-character or selection-range styling anywhere in the
  recording. Every tool is object-level.

## 3. The caret

- System caret, blue, at the end of the text, blinking at the system rate (visible/invisible
  alternation is what produces the "caret missing" frames at 7.45–7.7 s).
- Tapping inside the text to move the caret was not demonstrated.

## 4. Done

Reference: 7.75 s, 54.6 s, 59.6 s; `03-committed-object.jpg`.

- Done is the only way out of Editing. There is no Cancel in the reference editor (the composer's
  "×" top-left is hidden while editing). The MakeReady design adds Cancel (`10` §2).
- Done commits every property and the canvas transform, dismisses the keyboard, removes the
  scrim and the slider, and returns to Idle with the object rendered at its transform.
- The object's **animation keeps looping** after commit (Pixel/Typewriter were not combined, but a
  committed Pop/Jump object was not shown; the committed Pixel object at 55–63 s renders the
  effect statically; `OQ-02-1`).

## 5. The size slider

Reference: `01-editor-entry-empty.jpg` (default thumb position), design frame `edit-text.png`
for the MakeReady equivalent.

| Attribute | Value |
|---|---|
| Orientation | vertical, left edge |
| Track | a wedge: wide at the top (≈12 pt), tapering to a point at the bottom, ≈290 pt long, light gray at ≈60 % opacity |
| Thumb | white circle ≈ 24 pt |
| Mapping | top = largest, bottom = smallest; wedge width is the affordance for "bigger up here" |
| Default | thumb ≈64 % down the track (object renders ≈24–26 pt) |
| Interaction | drag the thumb; the text re-renders live at the new size while the finger is down (demonstrated in the prior recording, `features/activities/10-text-editing-analysis.md` §3; not dragged in this one) |
| Visibility | Editing mode only; slides in from the left edge on entry and out on Done (`08` §1, §2) |
| Affects | `size` only — never `transform.scale` |

The thumb is visible at the same default position in every entry (1.0 s, 13.0 s, 57.5 s),
meaning the slider shows the object's **current** `size`; re-opening an object whose size was
changed would show the thumb where it was left (inferred).

## 6. Re-opening an existing object

Reference: 12.75 s, 57.3 s; `08` §3 for timing.

- A single **tap** (touch-down and up without movement) on a committed object re-opens it in
  Editing with its text, font, color, alignment, label, animation and effect — the chip strip
  opens on the **fonts** category every time, scrolled so the object's font chip is centered
  (13.0 s: Classic; 57.5 s: Squeeze).
- The object moves to the edit slot and is shown at `scale` = 1, `rotation` = 0 (`01` §1).
- The caret is placed at the **end** of the text and the keyboard rises.
- Touch-down followed by movement is a drag, not a tap: the distinction is movement before
  finger-up (the drag at 9.5 s starts with no editor entry). The slop threshold was not
  measurable; use the platform's standard tap slop.

## Open questions

- **OQ-02-1** Do animations (Typewriter/Pop/Jump) loop on a committed object in Idle mode, or
  only while editing and in playback? The committed object in this recording had an effect, not
  an animation; the prior recording (`10-text-editing-analysis.md` §4) says they loop live.
- **OQ-02-2** Does the tap location on the blank canvas influence the object's initial canvas
  position? Both canvas taps in the recording were near the canvas middle, so a fixed default
  slot and "where you tapped" are indistinguishable here. The object landed at y ≈ 37 % of the
  screen (first commit) and ≈ 37 % again after re-entry without a drag, so the default is a fixed
  slot (see `08` §2); whether a tap near the top would change it is untested.
