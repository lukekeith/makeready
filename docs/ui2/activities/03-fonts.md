# 03 — Fonts

The font picker is the chip strip in its **fonts** category (tool row **Aa**). The same strip
widget also hosts the animation and effect categories (`06`), so the mechanics in §2–§3 are
shared by all three.

## 1. Opening the category

- Tap **Aa** in the tool row. The strip swaps to the font chips, scrolled so the object's current
  font is centered; the **Aa** tool gets the light highlight pill.
- Fonts is the category the editor opens on every time it enters Editing (`02` §1, §6).

## 2. The strip (shared mechanics)

Reference: 21.0–27.0 s, `11-font-chips-scrolled.jpg`.

| Attribute | Value |
|---|---|
| Layout | single horizontal row, chips ≈28 pt tall, ≈8 pt gaps, content wider than the screen |
| Selected chip | white fill, dark text, **always at the horizontal center of the screen** |
| Unselected chips | translucent dark fill (≈40 % black), white text |
| Selection by tap | tapping any visible chip selects it **and scrolls the strip so that chip is centered** — one motion, ≈150 ms (4 fps sampling: every frame after a tap already shows the new chip centered or nearly so) |
| Selection by scroll | the strip is a horizontal scroller; the chip that comes to rest at center becomes selected (the standard "center-snapping picker"; the user tapped rather than flicked in this recording, so snapping-on-flick is inferred from the always-centered layout) |
| Live apply | the object re-renders in the new font on the frame the chip is selected (22.0 s Editor, 22.25 s Poster …) — there is no confirm step |
| Overscroll | the first chip can be centered (25.5 s: Modern centered with empty space to its left), so the strip has leading/trailing padding of half a screen |

The strip swap between categories is a crossfade of ≤ 1 frame at 30 fps (`08` §4).

## 3. Self-rendering chips

Every font chip is set in **its own typeface**: "Signature" is script, "Editor" is monospace,
"Poster" is a heavy slab, "Bubble" is rounded-bold, "Deco" is thin geometric, "Squeeze" is
condensed, "Typewriter" is monospace, "Strong" is bold italic. The chip is the preview; there is
no separate sample text.

## 4. Fonts observed (in strip order)

The strip order is fixed; the user walked it left to right and back.

| # | Chip | Rendering of "Test content" (observed) | Seen at |
|---|---|---|---|
| 1 | Modern | medium-weight grotesk | 25.5 s |
| 2 | **Classic** (default) | bold humanist sans (system-like) | 1.0–21.75 s, 25.25 s |
| 3 | Signature | script, lighter weight, italic | 25.0 s, 25.75 s |
| 4 | Editor | monospace, regular weight, wide tracking | 22.0 s, 24.75 s |
| 5 | Poster | heavy slab/serif display bold | 22.25–23.0 s, 24.5 s |
| 6 | Bubble | rounded extra-bold | 24.25 s, 26.0 s |
| 7 | Deco | thin geometric sans | 23.25 s, 24.0 s, 26.25 s |
| 8 | Squeeze | condensed bold grotesk | 23.5 s, 26.5 s → final font for the rest of the recording |
| 9 | Typewriter | monospace typewriter | 23.75 s |
| 10 | Strong | bold italic grotesk | visible as a chip only (never selected) |
| 11+ | … | strip continues past the right edge; not scrolled to | — |

Chip metrics: labels are ≈13 pt in their own face; chip width follows the label (Typewriter ≈
96 pt, Deco ≈ 48 pt).

## 5. What changes with the font

- Only `font`. Size (`size` slider value), color, alignment, label, animation and effect are
  untouched. Rendered height changes with the face's metrics (Poster is taller than Deco at the
  same `size`), and the edit slot re-centers the text vertically on its new height.
- The chip strip's selected chip **tracks the object**: re-opening a Squeeze object scrolls the
  strip to Squeeze (57.5 s).

## MakeReady note

The design frame `assets/design/edit-font.png` shows four chips — Poppins, SF Pro, Georgia,
Typewriter — in a **left-aligned, non-scrolling** row with Typewriter selected (white) and the
rest outlined. That drops the always-centered mechanic because the set fits on screen. See
`10` §3 for the mapping and `OQ-10-3` for whether the strip should scroll/center once more fonts
exist.

## Open questions

- **OQ-03-1** Does flicking the strip (vs tapping a chip) select the chip that lands at center?
  Inferred from the always-centered layout; not demonstrated.
- **OQ-03-2** Full font list beyond Strong — the strip was never scrolled past it.
