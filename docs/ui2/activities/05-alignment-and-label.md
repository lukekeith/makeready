# 05 — Alignment and label background

The last two tools in the row are **instant-action** tools: a tap changes the object immediately,
the chip strip stays on whatever category it was on, and the tool never takes the highlight pill
(17.25 s: the effects strip stays visible while alignment is tapped; 17.75 s: still visible while
the label is cycled).

## 1. Alignment (≡)

Reference: 17.0 → 17.25 s, 44.25 → 45.5 s, 47.0 → 48.0 s, 53.0 → 53.25 s;
`17-align-right.jpg`.

| Attribute | Value |
|---|---|
| States | `center` → `left` → `right` → `center` … (one state per tap) |
| Default | `center` |
| Icon | three horizontal lines whose alignment mirrors the current state (centered lines = center, flush-left lines = left, flush-right lines = right); the glyph morphs between states on each tap |
| Effect on the edit slot | the text block's anchor moves: `left` → left edge at ≈ 24 pt from the canvas edge; `right` → right edge at ≈ 24 pt from the canvas edge; `center` → centered on the canvas |
| Effect on the object | `alignment` is stored on the object; multi-line text aligns its lines accordingly (single-line text only in this recording, so line-level alignment is inferred) |
| Timing | instant (≤ 1 frame at 4 fps) |

Observed sequence: center (17.0 s) → left (17.25 s) → … → left (44.25 s) → right (44.5 s) →
center (45.5 s) → right (47.0 s) → left (48.0 s) → center (53.25 s). The 45.5 → 47.0 and
47.0 → 48.0 steps each contain two taps within the 4 fps sampling gap (center→left→right, then
right→center→left); every single-tap step observed is consistent with the 3-cycle above.

The canvas **position** (`transform.position`) is not changed by alignment — alignment moves the
text within its own bounding box and the box's anchor within the edit slot. After Done the
object sits at its canvas position with its lines aligned (inferred; the committed objects in
this recording were all center-aligned).

## 2. Label background (A▢)

Reference: 17.5 → 19.5 s, 48.25 → 50.5 s; `09-label-black.jpg`, `10-label-white.jpg`,
`18-pixel-plus-label.jpg`.

| Attribute | Value |
|---|---|
| States | `none` → `solid-dark` → `solid-light` → `none` … (one state per tap) |
| Default | `none` |
| `solid-dark` | a filled black rounded rectangle behind the text, padding ≈ 8 pt horizontally / ≈ 4 pt vertically, corner radius ≈ 6 pt; the text stays white |
| `solid-light` | the same box in white; the text becomes **black** |
| Icon | the "A in a box" glyph fills when a label is active (17.75 s onwards the icon is a filled box with a dark A) and returns to outline for `none` |
| Draw order | behind the glyphs and **behind the effect**: Pixel's dark outline is drawn over the black box (48.5 s) and the white box (49.5 s) |
| Timing | instant |

Observed sequence: none (17.5 s) → solid-dark (17.75 s) → solid-light (18.75 s) → none (19.5 s);
again none (48.25 s) → solid-dark (48.5 s) → solid-light (49.5 s) → none (50.5 s). The box
covers only the text's bounding box per line (single line here).

Relationship with `color`: both label cycles ran with white text, so the observed rule is "dark
box keeps the text color, light box inverts the text to black". With colored text the prior
recording showed a **tinted** box (`10-text-editing-analysis.md` §4: "translucent tinted label
mode"), which suggests the general rule is: state 1 = contrasting solid box, text unchanged;
state 2 = box in the text's color, text in the contrasting color. Treat that generalization as
`OQ-05-1`.

## Open questions

- **OQ-05-1** Label colors with non-white text: confirm whether the box takes the text's color
  in `solid-light` and whether a translucent third state exists for colored text.
- **OQ-05-2** Multi-line label: one box per line (Instagram) or one box around the block? Not
  demonstrated.
