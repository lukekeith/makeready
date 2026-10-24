# 04 — Color

The color tool is the second tool in the row (a rainbow sphere icon). It is a **category** tool:
tapping it replaces the chip strip with the swatch row and gives the icon the highlight pill.

Reference: 15.75–16.25 s, 27.5–31.75 s; `08-color-swatches.jpg`, `12-color-applied.jpg`.

## 1. The swatch row

| Element | Position / value |
|---|---|
| Eyedropper well | leftmost, a circle ≈ 28 pt with an eyedropper glyph; its **fill shows the object's current color** (white at 27.5 s → yellow at 28.5 s → orange at 29.0 s → red at 29.5 s → magenta at 29.75 s → purple at 30.0 s) |
| Swatches | nine circles ≈ 28 pt, ≈ 12 pt gaps, in order: **white, black, blue, green, yellow, orange, red, pink, purple** |
| Page dots | three dots under the row, centered; the first is active on open — the row pages horizontally to two more palettes (not paged to in this recording) |
| Row position | same y as the chip strip (≈512 pt), replacing it |

Approximate observed values (3x recording, JPEG-sampled, ±10 %): blue ≈ `#3A8DF0`, green ≈
`#5BC260`, yellow ≈ `#F3C94A`, orange ≈ `#EE8A3A`, red ≈ `#E04B4B`, pink ≈ `#D5316E`, purple ≈
`#9B2BD1`. The MakeReady design frame uses the **same nine hues in the same order** with
rounded-square swatches (`assets/design/edit-text.png`); its blue is selected-outlined there.

## 2. Picking a swatch

- Tap → the object's `color` becomes the swatch color and the text re-renders on that frame
  (28.5 s yellow …). No confirm.
- The eyedropper well updates to the picked color at the same time; there is no "selected"
  ring on the swatch itself — the well is the selection indicator.
- Picking white again (31.0 s) returns the well to white.

## 3. The eyedropper

- Tapping the well (not demonstrated here) opens the on-canvas eyedropper/HSB picker shown in
  the prior recording (`features/activities/10-text-editing-analysis.md` §3: eyedropper + Hue /
  Saturation / Brightness sliders replacing the keyboard; the custom color lands in the well).
  The MakeReady design frame shows the well in a **selected** (blue-filled) state, which suggests
  it is a mode toggle there — `OQ-10-4`.

## 4. What changes with the color

- `color` only. Applies to the glyph fill. With a **label** active the relationship inverts (the
  label box takes the color and the glyphs take the contrasting color — see `05` §2); with
  effects the effect recolors with the text (Pixel outline stays dark; Sparkle/Shimmer glints
  stay white — inferred from the prior recording's Neon-over-color combination; not combined
  here).
- Switching to the color category does **not** change the selected animation or effect
  (32.0 s: returning to **//A** shows Typewriter still selected).

## Open questions

- **OQ-04-1** Contents of palette pages 2 and 3 (never paged to).
- **OQ-04-2** Is the swatch row a horizontal pager (swipe) or does tapping a dot page it? Not
  demonstrated.
