# 01 — Video Analysis: iPhone Voice Memos app

**Source:** `/Users/lukekeith/Makeready/Memo/memo.MP4` — 21.72 s, 60 fps, 1320×2868 (3× of
440×956 pt), **dark mode**, iOS 26 generation.
**Method:** 4 fps contact sheets end-to-end (±0.25 s), a 10 fps window over the record-tap
transition (1.5–3.3 s), and full-resolution crops of the list bottom bar, both recorder detents,
and the inline player control row.

Recording elapsed-time ↔ video time offset: **video t = memo elapsed + 2.63 s** (derived from
matched frames; consistent across the whole clip).

> The red pill in the Dynamic Island is the **screen recorder**, not the voice memo. The large
> red circle that appears to hover in the list is the **touch indicator** sitting on top of the
> record button.

---

## 1. Screen inventory

| Surface | Role |
|---|---|
| **All Recordings** list | Browse, search, select, play. Persistent. |
| **Recorder sheet — compact detent** | A card over the bottom of the list. Title, timer, live waveform, one stop button. |
| **Recorder sheet — expanded detent** | Full-height sheet. Adds `⋯`, Done, a scrubbable waveform with a time ruler, transport controls, transcript and audio-settings buttons, and pause instead of stop. |
| **Inline row player** | Not a screen. The selected recording's row in the list *expands in place* into a player. |

The whole feature is **one list plus one two-detent sheet**. Nothing pushes. Playback never
leaves the list.

---

## 2. The All Recordings list

### 2.1 Chrome

- **Top-left:** back chevron in a ~40 pt dark translucent circle (up to the folder list).
- **Top-right:** magnifier circle + a `Select` capsule (multi-select mode).
- All three float over the content — no bar background; rows scroll under them.
- **Large title** `All Recordings` (~34 pt bold) inside the scroll content.
- Below it, a dismissible **Siri tip banner**: a rounded ~44 pt dark row with the Siri orb,
  `Say "Record Voice Memo"`, and an `✕` at the trailing edge.

### 2.2 Rows

Plain rows (not the inset-grouped cards Notes uses), separated by full-width hairlines:

```
Day trading strategy                          ← 17 pt semibold, white
Aug 18, 2026   💬                     31:02   ← 15 pt gray date · transcript glyph · duration
```

- The **`💬` speech-bubble glyph** after the date marks *a transcript exists for this recording*.
  It is present on essentially every row in this library.
- Duration is right-aligned, `m:ss` or `h:mm:ss` (`2:16:41`, `1:24:51`).
- Sort is **newest first** by recording date; no date sections (unlike Notes).
- Titles are location-derived or user-typed: `Harbor Dr`, `2301 Plastic Surgery`,
  `Windhaven Pkwy 5`, alongside `Recording`, `Recording 2`, `Recording 3` from before Significant
  Locations were on. See [02-under-the-hood.md](02-under-the-hood.md) §4.

### 2.3 The record button

A **floating red circle**, bottom-center, over the content — no bar behind it.

| Metric | Value |
|---|---|
| Diameter | ~168 px @3× → **~56 pt** |
| Bezel | a dark ring ~5 pt wide around the red fill, reading as a glass bezel |
| Center | horizontal center of the screen; ~63 pt above the bottom edge (bottom of the button ≈ 35 pt up, clear of the home indicator) |

Rows behind it fade out under a bottom scrim. Tapping it plays a soft gray ripple (visible at
t ≈ 2.9 s) and the button **morphs into the stop control inside the sheet that rises to meet it**
— same position, same size, red circle → red rounded square.

---

## 3. The recorder sheet

### 3.1 Compact detent

Measured at t = 5.0 s (memo elapsed 00:02.25), full resolution.

| Metric | Value |
|---|---|
| Sheet height | ~957 px → **~319 pt** (about ⅓ of the screen) |
| Width | ~1254 px → **~418 pt**, i.e. ~11 pt inset each side |
| Corner radius | ~30 pt |
| Grabber | ~37 pt × 5 px pill, centered, ~8 pt from the top |
| Fill | flat dark gray, a step above the page black; the list is fully visible above it and **not dimmed** |

Contents, top to bottom:

1. **Title** — `Harbor Dr 2`, ~22 pt bold, centered. It is auto-assigned and appears at
   ≈00:01.1, i.e. *shortly after* recording starts, not at t=0.
2. **Elapsed timer** — `00:02.25`, ~20 pt, secondary gray, centered. Hundredths update live.
3. **Live waveform** — red bars on the dark ground, vertically centered, **right-anchored**: the
   newest sample is drawn at the right edge and older samples scroll left. At 00:01.1 it is a
   thumb-wide cluster at the right edge; at 00:02.25 it reaches back to the horizontal center; by
   ≈00:03.4 it spans the full width and begins scrolling off the left.
4. **Stop button** — a red **rounded square** (~28 pt) centered inside a ~56 pt circle with a
   faint outline, bottom-center of the sheet, aligned with where the list's record button was.

There is **no Done, no pause, and no menu at this detent.** One recording, one control.

### 3.2 Expanded detent

Measured at t = 12.0 s (memo elapsed 00:09.25/00:09.37).

Sheet occupies the full height below the status bar, same grabber, and adds a distinct
**header band** (darker than the waveform pane below it):

| Zone | Contents |
|---|---|
| Header band | `⋯` in a ~48 pt outlined circle (leading) · centered **title** `Harbor Dr 2` with a subtitle line `7:43 PM  0:09` (start time · whole-second duration) · **Done**: a ~56 pt **filled blue circle with a white checkmark** (trailing) |
| Waveform pane | Slightly lighter panel. A **fixed red playhead** — a vertical hairline with a filled dot cap — pinned at horizontal center; the waveform scrolls leftward beneath it. A **time ruler** along the bottom with per-second tick labels (`0:08  0:09  0:10  0:11`). A **dimmed blue `⊕`** in a circle at the pane's bottom-right (disabled while recording — see §6). |
| Timer | `00:09.25`, very large (~44 pt), centered, white, hundredths live |
| Transport row | `⟲15` · `▶` · `15⟳`, all **dimmed/disabled while recording** |
| Bottom row | `💬` transcript button in a ~52 pt outlined circle (leading) · a wide **capsule** (~200 pt) containing a red **pause** (two bars) · an audio-settings/EQ sliders glyph in a matching outlined circle (trailing) |

**The primary control changes with the detent:** compact shows a red **square** (stop), expanded
shows red **pause bars** plus an explicit **Done ✓**. The glyph morphs a beat after the sheet
resizes (observable at 00:12.62, mid-transition, where the sheet is already compact but the bars
have not yet become a square).

### 3.3 Detent behavior

- The sheet is **interactively draggable** between the two detents; the user does this six times
  in the clip (≈9.5 s, 10.2 s, 10.5 s, 15.2 s, 16.2 s, 18.9 s), and intermediate frames show the
  sheet at arbitrary heights, so it tracks the finger rather than animating between fixed states.
- The waveform, timer, and recording are **completely unaffected** — audio keeps recording, the
  timer keeps ticking, no state resets.
- The list stays live and **undimmed** behind the compact detent, and is progressively covered by
  the expanded one. There is no scrim on either.

---

## 4. Finishing a recording

At t ≈ 19.05 s (memo elapsed ≈00:16.4) the user taps **Done ✓**:

1. The sheet dismisses downward.
2. The list re-renders with the new recording **inserted at the top**, above `Day trading
   strategy`.
3. The new row is **already expanded into the inline player** — i.e. finishing a recording
   selects it.

Total transition ≈0.5 s, complete by t ≈ 19.6 s.

### The inline row player (full-res crop, t = 21.0 s)

```
Harbor Dr 2                                          ⋯   ← blue ⋯, trailing
7:43 PM  💬
────────────────────────────────────────────────────     ← flat scrub track, unfilled
0:00                                            −0:16    ← elapsed · remaining (negative)

  ∿        ⟲15      ▶      15⟳                    🗑
 blue     white   white   white                  blue
```

- Leading **blue waveform glyph** = *Edit Recording* (trim / replace).
- `⟲15 ▶ 15⟳` in white, centered as a group.
- Trailing **blue trash** = delete.
- The row's date line switches from `Aug 18, 2026` style to a **time** (`7:43 PM`) for
  same-day recordings — same relative-date rule the Notes list uses.
- The `💬` transcript glyph is present immediately, meaning transcription is available (or at
  least queued) the moment the recording is saved.
- The scrub track is a flat capsule, not a waveform — the waveform view is reserved for the
  recorder sheet and for Edit Recording.

---

## 5. Timestamped outline

Sampled at 4 fps (±0.25 s); **bold** rows re-extracted at 10 fps (±0.1 s).

| video t (s) | memo elapsed | What happens |
|---|---|---|
| 0.0–2.8 | — | **All Recordings** list. User drags the list up, then back down (rubber-band at the top). Floating red record button pinned bottom-center throughout |
| **≈2.85** | 00:00 | **Record button tapped** — gray tap ripple around it |
| **2.9–3.2** | 00:00.2–00:00.6 | Compact recorder sheet rises from the bottom; the record circle morphs into the red stop square in place; recording is already running |
| ≈3.5 | 00:01.1 | Auto-assigned title `Harbor Dr 2` fades in above the timer |
| 3.5–9.4 | 00:01–00:06.8 | Compact detent: title, timer, right-anchored live waveform, stop square. Waveform reaches full width at ≈00:03.4 and starts scrolling |
| **≈9.5–10.0** | 00:06.9–00:07.4 | User drags the sheet **up** → expanded detent: `⋯`, Done ✓, playhead + time ruler, big timer, dimmed transport, transcript / pause / audio-settings row |
| 10.2, 10.5 | 00:07.6, 00:07.9 | Dragged back down to compact and up again (rapid detent toggling) |
| 10.7–15.0 | 00:08.1–00:12.4 | Held at the expanded detent; timer and scrolling waveform continue |
| 15.2–16.1 | 00:12.6–00:13.4 | Dragged down to compact, held |
| 16.2–18.9 | 00:13.6–00:16.3 | Dragged back up to expanded, held |
| **≈19.05** | 00:16.4 | **Done ✓ tapped** — sheet dismisses downward |
| 19.1–19.6 | — | List returns; new row `Harbor Dr 2 · 7:43 PM · 💬` inserted at the **top**, already **expanded into the inline player** (0:00 / −0:16) |
| 19.6–21.7 | — | Idle on the new recording's inline player |

---

## 6. Uncertainties and what the video doesn't show

- **The dimmed blue `⊕`** in the expanded waveform pane is disabled throughout, so its function
  is never demonstrated. Most likely the iOS 26 layered-recording control (record an additional
  take over the existing one) — treat as **unconfirmed**.
- **The compact detent's red square was never tapped.** Standard Voice Memos behavior is that it
  *stops and saves* (equivalent to pause + Done), but this recording only ever finishes via
  Done ✓ from the expanded detent.
- Never opened: the `⋯` menu (rename, duplicate, share, favorite, move to folder, Enhance
  Recording), the transcript view, the audio-settings/EQ panel, Edit Recording, `Select` mode,
  search, and the folder list one level up.
- Playback was never started — the transport row was dimmed the whole time.
- Light mode was not exercised.

See [02-under-the-hood.md](02-under-the-hood.md) for what is known about these from the platform
rather than from the video.
