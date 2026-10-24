# 09 — Timestamped outline (for re-analysis)

Source: `~/MakeReady/Design reference/Activity/Activity editor.MP4` — 1320×2868, 60 fps
(avg 59.93), 63.5 s, iPhone 16 Pro Max screen recording. Overview sampled at **4 fps**
(timestamps ±0.25 s); the rows in **bold** were re-measured at **30 fps** (±33 ms) and are the
ones `08-transitions.md` is built from.

Re-extraction recipe (from `video-analysis-procedure` memory):
`ffmpeg -ss <t> -t <dur> -i "<file>" -vf "fps=30,scale=220:-1,drawtext=text='%{pts\:hms}':x=4:y=4:fontsize=20:fontcolor=yellow:box=1:boxcolor=black@0.6,tile=6x3" out.jpg`.

## Outline

| t (s) | What's demonstrated | Spec section |
|---|---|---|
| 0.0–0.6 | Idle story composer: gradient canvas, center "Aa" button, left "Aa ×" stack, POST/STORY selector | `01` §3 |
| **0.65–0.98** | **Blank-canvas tap → Editing entry**: placeholder + caret, scrim, strip (Classic centered), tool row, keyboard rise, slider slide-in | `08` §1 |
| 1.0–3.0 | Empty editor at rest: placeholder "Type something…", default thumb position, font strip Modern·Classic·Signature·Editor | `02` §1, §5 |
| 3.0–6.5 | Typing "Test content" (shift → "T", key pop-ups); text grows from center | `02` §2 |
| 6.5–7.5 | Caret blink at rest; "Next" top-right | `02` §3 |
| **7.73–8.0** | **Done → Committed** (first commit; object lands at the default canvas slot y ≈ 37 %) | `08` §2 |
| 8.0–9.25 | Idle with one committed object; composer chrome (right rail Aa/sticker/music/@/sphere) | `01` §3 |
| 9.25–9.5 | Touch-down + drag start: chrome hides, "Drag to delete" appears, center guide visible | `07` §1, §5 |
| 9.5–10.5 | Pinch to ≈ 2×; guide line at x-center; object snapped to center | `07` §2, §5 |
| 10.5–11.25 | Release; chrome fades back (right rail by 11.25) | `08` §8 |
| 11.25–11.75 | Idle; suggested-audio pill (composer chrome, out of scope) | — |
| 11.75–12.5 | Second one-finger drag with "Drag to delete" shown; release | `07` §1, §4 |
| **12.75–12.95** | **Tap object → Editing re-entry**: scrim, strip (Classic centered), keyboard, object un-scales 2× → 1× and rises to the slot, slider slides in | `08` §3 |
| 13.0–13.9 | Re-entered editor at rest; @Mention / Location accessory row (out of scope) | — |
| **14.0** | **Category switch Aa → //A** (≤ 1 frame) | `08` §4 |
| 14.0–15.0 | Animation strip: ⊗ · Typewriter · Pop (Typewriter selected, centered) | `06` §1 |
| 15.0–15.75 | Switch → ✦: ⊗ · Sparkle · Neon (⊗ selected) | `06` §2 |
| 15.75–16.25 | Switch → color: eyedropper well + 9 swatches + 3 page dots | `04` §1 |
| 16.5–16.75 | Switch → //A (Typewriter still selected) then → ✦ | `06` §1 rule 4 |
| 17.0–17.25 | **Alignment tap**: center → left (effects strip stays visible) | `05` §1 |
| 17.5–19.5 | **Label cycle**: none → solid-dark (17.75) → solid-light (18.75) → none (19.5) | `05` §2 |
| 19.5–20.5 | Left-aligned white text at rest; 20.75 switch → Aa | — |
| 21.0–21.75 | Font strip at rest (Classic) | `03` |
| 22.0–26.5 | **Font walk**: Editor 22.0 · Poster 22.25 · Deco 23.25 · Squeeze 23.5 · Typewriter 23.75 · Deco 24.0 · Bubble 24.25 · Poster 24.5 · Editor 24.75 · Signature 25.0 · Classic 25.25 · Modern 25.5 · Signature 25.75 · Bubble 26.0 · Deco 26.25 · Squeeze 26.5 (final) — selected chip always centered | `03` §2, §4 |
| 27.0–27.5 | Squeeze at rest; switch → color (27.5) | — |
| 27.5–30.0 | **Color walk**: yellow 28.5 · orange 29.0 · red 29.5 · pink 29.75 · purple 30.0 — well mirrors the pick | `04` §2 |
| 30.0–31.0 | Purple at rest; white re-picked 31.0 | `04` §2 |
| 31.0–32.0 | White Squeeze at rest; switch → //A (32.0) | — |
| 32.0–33.25 | Animation strip: Typewriter selected (strip ⊗·Typewriter·Pop·Jump) | `06` §1 |
| 33.5 | Pop selected | `06` §1 |
| 33.75–35.25 | **Jump** selected and looping (34.0 "Test" alone, 34.25 tilted pair, 34.5 settling) | `06` §1 |
| 35.5–37.75 | **Pop** looping (36.0 widened gap mid-pulse) | `06` §1 |
| 38.0–40.5 | **Typewriter** looping (38.25 "Tes", 38.5 "Test cont", 38.75 full) | `06` §1 |
| 40.5–41.0 | Typewriter at rest with caret; 41.25 switch → ✦ | — |
| 41.25–42.5 | Effects strip ⊗·Sparkle·Neon·Shimmer; ⊗ selected | `06` §2 |
| 42.5–43.0 | **Sparkle** selected (glints 42.75, 43.0) | `06` §2 |
| 43.25–43.75 | **Shimmer** selected (band sweep) | `06` §2 |
| 44.0–44.25 | **Pixel** selected (bitmap outline + shadow) | `06` §2 |
| 44.5–45.5 | **Alignment taps**: left → right (44.5) → center (45.5) | `05` §1 |
| 45.5–47.0 | Center at rest; two taps → right by 47.0 | `05` §1 |
| 47.0–48.25 | Right at rest; → left by 48.0 | `05` §1 |
| 48.5–50.5 | **Label cycle with Pixel**: solid-dark 48.5 · solid-light 49.5 · none 50.5 | `05` §2 |
| 50.5–53.0 | Pixel, left-aligned, at rest | — |
| 53.25 | Alignment → center | `05` §1 |
| 53.25–54.5 | Pixel centered at rest | — |
| **54.6–54.77** | **Done → Committed** (object grows back to its 2× canvas scale mid-flight at 54.5) | `08` §2 |
| 55.0–57.0 | Idle with the committed Pixel object | `01` §3 |
| **57.28–57.47** | **Tap object → Editing re-entry** (strip opens on Squeeze centered) | `08` §3 |
| 57.5–59.25 | Re-entered editor at rest; caret drawn above the text (effect artifact); AutoFill tooltip (system, out of scope) | `06` §2 |
| **59.58–59.72** | **Done → Committed** | `08` §2 |
| 60.0–60.3 | Idle | — |
| **60.37–60.47** | **Drag start**: chrome out, "Drag to delete" in | `08` §7 |
| 60.5–61.25 | One-finger drag toward center; release | `07` §1 |
| **61.5–61.87** | **Two-finger rotate + scale** (≈ −12°, ≈ 1.5×); no delete target | `07` §2, §3, `08` §7 |
| 62.0–63.5 | Release; object rests rotated/scaled; chrome back | `08` §8 |

## Reference frames (`assets/reference-frames/`)

| File | t (s) | Shows |
|---|---|---|
| `00-idle-canvas.jpg` | 0.3 | Idle composer before the canvas tap |
| `01-editor-entry-empty.jpg` | 1.5 | Editing, empty: placeholder, slider at default, font strip, tool row, keyboard |
| `02-typing.jpg` | 6.5 | "Test content" typed, caret |
| `03-committed-object.jpg` | 8.25 | First committed object at the default canvas slot |
| `04-pinch-scale-guide.jpg` | 10.25 | Pinched ≈ 2×, center guide line |
| `05-drag-to-delete.jpg` | 12.0 | Drag in progress, "Drag to delete" target |
| `06-animation-chips.jpg` | 14.5 | //A strip: ⊗ · Typewriter · Pop |
| `07-effects-chips.jpg` | 15.25 | ✦ strip: ⊗ · Sparkle · Neon |
| `08-color-swatches.jpg` | 16.0 | Color row + page dots |
| `09-label-black.jpg` | 17.75 | solid-dark label, left-aligned |
| `10-label-white.jpg` | 18.75 | solid-light label (text inverted) |
| `11-font-chips-scrolled.jpg` | 22.5 | Font strip scrolled: Poster centered |
| `12-color-applied.jpg` | 29.5 | Red applied; well shows red |
| `13-jump-animation-midframe.jpg` | 34.25 | Jump mid-cycle |
| `14-typewriter-midframe.jpg` | 38.5 | Typewriter mid-cycle |
| `15-sparkle-effect.jpg` | 42.75 | Sparkle glint |
| `16-pixel-effect.jpg` | 44.25 | Pixel effect |
| `17-align-right.jpg` | 45.0 | Right-aligned |
| `18-pixel-plus-label.jpg` | 50.75 | Pixel + no label after the cycle (compare with 48.5/49.5 in the outline) |
| `19-committed-pixel.jpg` | 56.0 | Committed Pixel object, Idle |
| `20-rotate-scale.jpg` | 61.75 | Two-finger rotate + scale in progress |
