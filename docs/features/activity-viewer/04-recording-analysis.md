# 04 — Recording analysis

## Source

| | |
|---|---|
| File | `~/MakeReady/activities/Activity viewer.MP4` (not in the repo) |
| Format | 1320×2868 (440×956 pt @3x), 60 fps variable, 70.37 s, 4,222 frames |
| Reference app | YouVersion Bible App, Guided Scripture, then one screen of Guided Prayer |

## Method

1. 2 fps timestamped contact sheets across the whole recording, for the outline.
2. 10–30 fps windows on every transition, and 3× crops of the rail and chrome.
3. A row profile of all 4,222 frames (mean color per row across 75 % of the width, skipping the
   rail). The hard edge between two page backgrounds was tracked per frame, which gives position and
   speed directly. Accuracy: ±1.3 pt per row, ±17 ms per frame.
4. Each landing correlated against its final frame, then fitted with a critically damped spring and
   a cubic ease-out.

**Limits:**

- **The finger isn't visible.** Lift moments are inferred from a change in speed, so commit
  thresholds are brackets, not measurements. The velocity constant in `01` §6 is a default for this
  reason.
- **Repeating text lines alias the correlation.** Fits on text-to-text landings were discarded.
  Only these were clean: scripture → share (twice), video → article, article → video, article →
  completion. Only the two video ones cover nearly a full page (ω 20.4 and 19.6); the others started
  late, and gave ω 10.6–27.6.
- **One sample only:** momentum stopping at a long page's end without spilling into the next page.
- **Never demonstrated:** tapping the rail, a video reaching its end, pulling past the first page,
  pulling to the top of a long page and on into the previous one, and the first entry to a long page
  from below. Each has a *(default)* in `01`.

## Timestamped outline

± 0.25 s, except **bold** rows, which were measured at 30–60 fps.

| t (s) | What it shows |
|---|---|
| 0.0–2.5 | Video page at rest: chrome, captions, presenter row, remaining time. No rail |
| 2.5–4.5 | **Scrubbing.** Remaining time jumps 1:47 → 1:45 → 1:01 → 1:39; the stack doesn't move |
| 5.4–6.9 | Paused, then resumed; play glyph |
| **8.1–10.1** | **Slow drag, video up to 74 % gone, finger held. No commit. Rail appears at 8.1** |
| **9.1** | **Video pauses with the boundary at 480 of 956 pt. Top-right icon begins to swap at 9.2** |
| **10.1–11.25** | **Same finger returns it to rest. Video resumes** |
| **11.4–12.3** | **Second drag and release: commit to the article. Rail morph 12.0–12.15, thumb fades in by 12.3** |
| 12.3–16.7 | Long article: free scroll, rail thumb travels, text fades beneath the top scrim |
| **16.70–16.89** | **Stops at the article's end. Next movement is 190 ms later** |
| 16.9–20.2 | Pulled past the end: next page attached 80 pt below the last line, reversed, held |
| **20.6–22.3** | **Article → scripture commit** |
| **23.3–25.6** | **Single touch: up to 36 %, held, back through rest, on into the previous page** |
| 27.2–28.2 | Scripture → article from below; lands at the article's end |
| 29.0–31.5 | Article scrolled up, then down, then into scripture |
| **32.2–33.07** | **Slow drag then flick: commit from 33 %. The cleanest edge trace** |
| 34.0–35.75 | Share ⇄ scripture, repeated reversals, then commit back |
| 36.1–36.8 | Scripture → share |
| 37.3–38.4 | Share → prayer; slow, past 74 % |
| 39.3–40.5 | Small pulls on the prayer page, returning to rest |
| **41.1–41.6** | **Add to Prayer List: sheet opens** |
| 41.6–43.0 | Sheet at rest: title, count, body, privacy line |
| **43.0–43.4** | **Close pressed, sheet falls** |
| 43.75–45.2 | Prayer → second video; spinner over poster at 45.0 |
| **46.6–46.9** | **Rail fades out, 1.5 s after settling** |
| 48.7–50.2 | Video → article with hero image and pinned Start Plan |
| 50.2–54.3 | Long article: inline link, lists, italics, pinned pill stays put |
| **54.55–55.05** | **At the article's end: pulled up 25 pt, reversed, page slides down to the video with its text frozen. Rail shows no reaction** |
| **55.05–55.5** | **Video resumes from its old position** |
| **57.2–57.64** | **Flick: video → prayer** |
| **58.3–58.76** | **Flick: prayer → video** |
| **59.44–59.85** | **Flick: video → article, landing on its retained offset, not its top** |
| 60.0–62.0 | At rest on the article; rail stays visible |
| 62.4–63.24 | Article → completion |
| 63.2–65.9 | Completion at rest |
| **65.9–67.1** | **Pulled up 158 pt, then the whole stack slides down to home** |
| 67.3–68.3 | Next lesson (Guided Prayer) rises, content fades in |
| **69.4–69.65** | **Rail fades on the narrated page** |
| **69.6–70.05** | **Close pressed: tint fill, stack slides down** |

## Page-edge traces

Boundary position in pt (956 = bottom of screen), at each listed time. The source of `01` §6.

**Drag, hold, return (8.15–11.25):** 927 · 8.5: 769 · 9.0: 517 · 9.5: 361 · 10.0: 251 · **10.1: 248
(held)** · 10.5: 517 · 11.0: 825 · 11.25: 924

**Slow drag then flick, commit (32.2–33.07):** 32.20: 932 · 32.50: 809 · 32.70: 637 · 32.75: 487 ·
32.80: 297 · 32.85: 155 · 32.90: 80 · 32.95: 25 · 33.00: 9 · 33.05: 0. Speed: 320–1,120 pt/s while
dragging, ≈3,600 pt/s at the start of the settle, no overshoot.

**Slow drag, held, back through rest (23.3–24.8):** 912 · 23.5: 808 · 24.0: 628 · **24.15: 611
(held)** · 24.5: 759 · 24.8: 940

## Settle fits

| Landing | Fit starts at (pt left) | ω (rad/s) | RMS (pt) | Overshoot |
|---|---|---|---|---|
| Video → article (49.2–50.3) | 383 | 20.4 | 6.0 | 0 |
| Article → video (54.75–55.75) | 503 | 19.6 | 12.8 | 0 |
| Scripture → share (36.2–36.95) | 186 | 27.6 | 2.9 | 0 |
| Scripture → share (32.5–33.3) | 93 | 12.3 | 2.4 | 0 |
| Article → completion (62.5–63.4) | 130 | 10.6 | 3.5 | 0 |

Rulings use the two long-distance fits. Short tails fit a wide range, because little distance is
left to constrain them.

Whole-motion timings from the trace: flick commits move 903–976 pt in 0.42–0.45 s.

## Rail evidence

The window formula in `01` §8 was checked against 3× crops of all eight pages: active 0 (capsule + 4
dots), 1 (1 + 3), 2, 3, 4 and 5 (2 + 2), 6 (3 + 1), 7 (4 + capsule). Every one matches. Active 0 was
read from the next lesson's rail at 68 s; its page count isn't known, but it shows the same shape.

## Stills

`assets/` holds 440 pt-wide stills named by their timestamp, and `rail-3x-crop.png` at full
resolution. Any other moment can be re-extracted:

```
ffmpeg -ss <t> -i "~/MakeReady/activities/Activity viewer.MP4" -frames:v 1 out.png
```
