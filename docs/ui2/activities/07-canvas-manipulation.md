# 07 — Canvas manipulation (committed objects)

Everything in this file happens in **Manipulating** mode (`01` §2): a committed object under a
finger that has moved. These gestures never enter Editing and never show the keyboard.

Reference: 9.25–12.5 s (drag + pinch), 60.3–63.5 s (drag, then two-finger rotate+scale);
`04-pinch-scale-guide.jpg`, `05-drag-to-delete.jpg`, `20-rotate-scale.jpg`.

## 1. One-finger drag

- Touch-down on the object followed by movement. The object follows the finger 1:1 with no lag
  visible at 30 fps; the touch point's offset from the object center is preserved (the finger
  does not snap to the center).
- Chrome reacts within ≈ 67–100 ms of the first movement (measured at 60.37 s → 60.43 s): the
  composer's top-left ×, right rail and bottom bar fade out; the **delete target** (§4) fades in.
- The canvas is **not** dimmed during a drag.
- On release (all fingers up) the object stays where it was dropped; chrome fades back in
  (≈ 250 ms, 4 fps estimate: 10.25 s released → 11.25 s chrome fully back).
- A drop on the delete target deletes the object (§4; not performed in this recording).

## 2. Pinch (scale)

- Two fingers on the object, spreading/closing. Writes `transform.scale`.
- Observed 9.5 → 10.5 s: "Test content" grows from ≈ 173 pt wide to ≈ 350 pt wide (≈ 2.0×) in
  one continuous gesture. Scale is applied about the object's center; the glyphs re-render
  sharply (vector scale, not a bitmap stretch — the Classic face stays crisp at 2×).
- No minimum/maximum was reached. The prior recording's post editor showed the same.
- During a two-finger gesture the **delete target is not shown** (61.5–62.0 s: no trash, no
  "Drag to delete"), while the chrome still hides.

## 3. Two-finger rotate

- Two fingers twisting. Writes `transform.rotation`; a pinch and a rotate are read from the same
  two fingers simultaneously (61.5–62.0 s: the object rotates to ≈ −12° **and** scales ≈ 1.5× in
  the same gesture).
- Rotation is about the object's center. No angle snapping was observed (the object settled at
  an arbitrary angle, 63.0 s).
- Effects rotate with the text (Pixel outline and shadow follow the glyphs, 62.5 s).

## 4. Delete target

| Attribute | Value |
|---|---|
| Content | caption **"Drag to delete"** (≈ 11 pt, white) above a circle ≈ 40 pt with a trash-can glyph, centered horizontally |
| Position | y ≈ 88 % of the screen height (above the home indicator), over the canvas |
| Appears | ≈ 67–100 ms after a one-finger drag starts; fades in |
| Hidden | for two-finger gestures; on release |
| Hover state | when the dragged object's center enters the circle the circle grows and the object shrinks toward it (prior recording §5; **not demonstrated here**) |
| Drop | deletes the object (not demonstrated) |

## 5. Center guide

- A **1 px white vertical line** spanning the canvas height at x-center appears while the
  object's center is within snap range of x-center during a one-finger drag or a pinch (9.5 s,
  10.0 s, 12.0 s).
- The object's center snaps to the line while the guide is visible (10.0 s: text exactly
  centered; the finger was still moving).
- Snap range: not measurable here; the prior recording's post editor used ≈ 8 pt. The guide
  disappears as soon as the center leaves the range.
- Only the **vertical center** guide was shown. No horizontal center guide, no thirds, no
  rotation-angle guide appeared in this recording (the post editor in the prior recording also
  showed horizontal/thirds guides in cyan — a different editor variant).

## 6. Tap vs drag disambiguation

- Touch-down + up with no movement past the slop → **tap** → Editing (`02` §6).
- Touch-down + movement → **drag**; the editor is never entered even if the finger returns to
  the start point. The threshold was below the sampling resolution; use the platform default.

## 7. What manipulation does *not* do

- It never changes `size`, `font`, `color`, `alignment`, `label`, `animation` or `effect`.
- It never dims the canvas or shows the slider/strip/keyboard.
- It does not bring a tapped object to the front (single object only; `OQ-01-1`).

## Open questions

- **OQ-07-1** Snap range and whether a horizontal-center guide exists in this editor variant.
- **OQ-07-2** Delete-target hover feedback and the delete animation (not performed).
- **OQ-07-3** Scale limits (min/max) — none hit.
