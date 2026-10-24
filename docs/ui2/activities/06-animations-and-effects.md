# 06 — Animations and effects

Two category tools share the chip strip with fonts: **//A** (animations) and **✦** (effects).
They are separate object properties (`01` §1) with separate strips, each strip starting with a
**⊗ none** chip. The strip mechanics (centered selection, self-labelled chips, live apply) are
the ones in `03` §2.

Reference: 14.0–15.5 s, 32.0–40.5 s (animations); 15.25–17.5 s, 41.25–54 s (effects).

## 1. Animations (//A)

Chips observed, in strip order: **⊗** (none) · **Typewriter** · **Pop** · **Jump** · … (strip
continues; not scrolled past Jump). Each chip has a small glyph before its label (Typewriter: an
I-beam; Pop: a burst; Jump: an arc).

| Chip | What it does to the object (observed while editing, looping) | Measured |
|---|---|---|
| ⊗ none | static | — |
| **Typewriter** | characters appear one at a time left-to-right, then the full text holds, then the cycle restarts from empty | 38.25 s "Tes" → 38.5 s "Test cont": ≈6 chars / 250 ms ≈ **40 ms per character**; hold ≈ 1 s; loop |
| **Pop** | each word scales up briefly in sequence (a scale pulse ≈ 1.0 → 1.15 → 1.0), with the word gap widening during the pulse | 36.0 s shows "Test  content" with the inter-word gap widened mid-pulse; period ≈ 1 s |
| **Jump** | words leave the baseline in sequence: each word rises ≈ 10 pt and tilts ≈ −10°, then settles; the second word follows the first by ≈ 150 ms | 34.0 s "Test" alone visible (second word mid-flight), 34.25 s both words tilted, 34.5 s settling |

Behavior rules:

- Selecting a chip starts the animation **immediately on the edited object** and it keeps
  looping while editing, including while the caret is shown and while other categories are
  open (32.0 s: Typewriter loops under the color category at 38.25 s).
- Selecting ⊗ stops it and shows static text.
- Returning to the **//A** category after visiting another scrolls the strip to the current
  selection (32.0 s Typewriter centered; 36.0 s Pop centered).
- Animation selection is independent of effect selection: switching between the two strips never
  cleared either (Typewriter was still selected at 41.0 s after effects had been browsed at
  15–20 s).

## 2. Effects (✦)

Chips observed, in strip order: **⊗** (none) · **Sparkle** · **Neon** · **Shimmer** · **Pixel** · …
(strip continues; not scrolled past Pixel). Glyphs: Sparkle a four-point star, Neon a tube
glyph, Shimmer a diagonal-lines glyph, Pixel a hollow circle.

| Chip | What it does to the object (observed) | Measured |
|---|---|---|
| ⊗ none | plain fill | — |
| **Sparkle** | small white four-point glints appear at random glyph positions, each fading in/out over ≈ 300 ms; 1–3 visible at a time | 42.75 s glint on the "T"; 43.0 s glint on the last "t" |
| **Neon** | glow around the glyphs in the text color (not selected in this recording — chip only; the prior recording §4 describes "Neon glow") | — |
| **Shimmer** | a diagonal light band sweeps across the text left→right, ≈ 1 s period | 43.25–43.5 s band mid-sweep |
| **Pixel** | the glyphs are re-rasterized at a coarse pixel grid with a dark 2-px-step outline and a hard drop-shadow offset down-right — a "bitmap sticker" look; **static** (no loop) | 44.25 s onward; the committed object at 55–63 s shows it static |

Behavior rules:

- Live apply on the edited object, no confirm.
- Effects render **in Editing and after commit** (Pixel visible on the committed object through
  every later mode, including during drag and rotate at 60–63 s).
- Pixel **changes the object's rendered bounds** (outline + shadow add ≈ 3 pt on each side); the
  label box (`05` §2) is drawn behind the outline, not expanded for it.
- With Pixel active, the caret was drawn above the text instead of at its end (57.5 s, 59.0 s) —
  rasterized-effect artifact, not a behavior to copy.

## 3. Combining with other tools

| Combination | Observed | Result |
|---|---|---|
| animation + font change | Typewriter + Squeeze (38–40 s) | animation continues in the new face |
| animation + color change | Typewriter + yellow/orange/red (28–30 s, animation selected earlier at 14 s? no — Typewriter was selected at 32.0 s after the colors; the colors ran on static text) | not combined; inferred to compose |
| effect + label | Pixel + solid-dark / solid-light (48.5 s, 49.5 s) | box behind outline (`05` §2) |
| effect + alignment | Pixel + right / center (44.5–45.5 s) | effect follows the text |
| effect + pinch / rotate | Pixel on the committed object (60–63 s) | effect is rasterized with the transform (outline scales with the text) |
| animation + effect | never both non-none at the same time in this recording | `OQ-06-1` |

## Open questions

- **OQ-06-1** Can an animation and an effect be active at once (e.g. Pop + Neon)? The two strips
  keep independent selections, so the model allows it; the rendering was not demonstrated.
- **OQ-06-2** Full chip lists past Jump (animations) and Pixel (effects).
- **OQ-06-3** Whether animations play on the committed object in Idle mode — see `OQ-02-1`.
