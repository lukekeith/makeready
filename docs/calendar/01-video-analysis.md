# Calendar — reference video analysis

> Evidence for [`02-design.md`](02-design.md) (normative) and [`SPEC.md`](SPEC.md). This file records
> **what the reference does**. What MakeReady builds is in 02-design.md.

## 1. Source

| | |
|---|---|
| File | `/Users/lukekeith/MakeReady/Design reference/calendar/calendar.MP4` |
| App recorded | Apple Calendar (iOS 26), dark mode, Month view, iPhone Pro Max class |
| Video | 1320 × 2868 px (= **440 × 956 pt @3x**), 60 fps, **61.06 s**, with audio (unused) |
| Clock in recording | 10:42–10:43 PM, "today" = **Tuesday Oct 20, 2026** |
| Method | 2 fps contact sheets (`scale=330`, 6×2 tiles) for the outline; **20 fps** strips for every transition window (bold rows in §2); 440 pt-wide stills for geometry (§4, `frames/`) |
| Accuracy | outline rows ±0.5 s (2 fps); **bold** rows ±0.05 s (20 fps) |

Re-extracting a moment: copy the video somewhere this process can read (`~/Makeready/` — the
`Design reference` folder works directly), then
`ffmpeg -ss <t> -t <dur> -i calendar.MP4 -vf "fps=20,scale=300:-1,tile=8x1" out%02d.png`.

## 2. Timestamped outline

| t (s) | View | What is demonstrated |
|---|---|---|
| 0.0 – 5.8 | Month | Fast upward flick Jun → Sep 2026. **Continuous vertical scroll** (not paged), momentum. The large title follows the month at the top of the viewport (June → July → August → September). Inline month labels ("Jul", "Aug", "Sep") sit above the column of each month's 1st; the **current** month's label ("Oct") is red. |
| 5.8 – 9.0 | Month | Scroll back down to July. Title updates in reverse. |
| **9.75 – 10.30** | Month → Day | **Tap Jul 29 → expand into Day view** (0.55 s incl. settle). See §3.1. |
| 10.3 – 14.5 | Day | Vertical scroll of the 24 h timeline up to 12 AM; rubber-band at the top; scroll indicator on the right. Header + week strip stay pinned. |
| **14.90 – 15.85** | Day | **Swipe right on the week strip** → previous week (Jul 19–25). Strip tracks the finger; on release the selection moves to the **same weekday** (Wed 29 → Wed 22) and the day page slides in after it. See §3.2. |
| 16.5 – 17.5 | Day | Swipe left on the strip → back to Jul 26–Aug 1, selection Wed 29. |
| 18.0 – 19.45 | Day | **Swipe left on the day content** → Thu Jul 30. Strip selection follows (§3.3). |
| **20.15 – 20.55** | Day | **Tap "31" in the week strip** → Fri Jul 31; day page slides left. Overlapping events (10 AM) laid out side-by-side (frame 07). |
| 21.0 – 23.5 | Day | Swipe right on content twice: 31 → 30 → 29. |
| **24.05 – 24.60** | Day → Month | **Tap the back pill "‹ July"** → collapse back into Month (0.45 s). See §3.4. |
| 24.6 – 27.3 | Month | Scroll July → October. |
| 27.5 – 28.4 | Month → Day | Tap Oct 20 (today) → Day view. Today in the strip = **red** filled circle. |
| 28.4 – 31.2 | Day | Timeline scroll; **current-time line** (red, "10:42" capsule in the gutter) visible near the bottom; scrolls to 12 AM. |
| 31.3 – 32.0 | Day → Month | Back pill "‹ October" → Month at October. |
| 32.0 – 35.5 | Month | Long flick into 2027 (Dec → Jan → Mar → Apr). The year shown in the top-left pill changes **2026 → 2027** as the top month crosses the year boundary. |
| **35.60 – 35.85** | Month | **Tap Today** → **instant jump** (one frame, no scroll animation) to October 2026 with today visible; the Today pill shows a pressed fill for ~0.2 s. |
| 36.0 – 38.5 | Month | Scroll up to August. |
| **38.80 – 39.25** | Month → Search | **Tap search**: the right button group morphs into a full-width search field + ✕ and the keyboard rises together (~0.25 s). Grid stays put behind, dimmed only by the keyboard. |
| 39.5 – 46.5 | Search | Type "birthfay" → grid fades out and a centred **"No Results"** empty state appears (~0.3 s); backspace to "b". |
| 46.5 – 48.0 | Search | Clear, type "lidon" → results list replaces the grid. |
| 48.0 – 54.0 | Search | Keyboard dismissed by scrolling; results are **chronological ascending** (2014 … 2027), grouped under day headers "Weekday – Mon d, yyyy"; past rows dimmed; a floating **"Today"** pill (red label) centred at the bottom. |
| **54.45 – 55.00** | Search → Month | Tap ✕ → field collapses back to the button group, results fade out, grid returns at its prior scroll position. |
| 55.0 – 61.0 | Month | Scroll August → September; end. |

## 3. Measured transitions (20 fps)

### 3.1 Month → Day (tap a date) — 9.75 → 10.30 s
| t | Observation |
|---|---|
| 9.75 | Touch-up on 29. Back pill label already reads "July" (label crossfade starts immediately). |
| 9.80 | Header buttons blur-dissolve (glass morph). Tapped date gets a **grey pressed circle**. Rows **below** the tapped week start sliding **down**; hour lines appear in the gap behind them. |
| 9.85 – 9.95 | Rows **above** slide **up** and fade; the tapped week row travels **up** toward the strip position under the weekday letters. "July" title slides up and fades. Timeline is revealed between the tapped row and the rows below (a curtain that opens). |
| 10.00 | Tapped row is in strip position; circle on 29 now **white filled / black numeral**. Subtitle "Wednesday – Jul 29, 2026" fades in. Header buttons resolve (first icon swaps). |
| 10.05 – 10.30 | Strip overshoots ~1–2 pt and settles (spring). Timeline settles with **5 AM at the top**. |
Total ≈ **0.55 s**, spring with slight overshoot (≈ response 0.5, damping 0.85).

### 3.2 Week-strip swipe (previous week) — 14.90 → 15.85 s
| t | Observation |
|---|---|
| 14.90 – 15.50 | Strip follows the finger 1:1 to the right; the previous week's dates enter from the left. **Day content does not move** during the drag; subtitle unchanged. |
| 15.55 | Release past the threshold → strip snaps to Jul 19–25; circle on 29 fades grey and the circle appears (grey → white) on **22** — the same weekday. |
| 15.60 – 15.85 | Day page slides **right** (Jul 29 exits right, Jul 22 enters from left), subtitle travels with the page. ≈ 0.3 s, ease-out. |
| 15.85 | New day lands at its **default scroll anchor** (5 AM / all-day row visible), not at the hour the previous day was scrolled to (Jul 29 had been scrolled to 12 AM). |

### 3.3 Day paging (swipe content / tap a strip date) — 18.0 → 19.45 s, 20.15 → 20.55 s
- Swipe on content: the page tracks the finger; on commit the strip circle moves (29 grey → 30 grey → 30 white over ~0.1 s) and the page completes in ≈ **0.3 s** ease-out.
- Tap a strip date: the tapped date shows the grey pressed circle at touch-down (20.20), the old selection fades; the page slides in the direction of travel (later date = enters from the right) in ≈ **0.3 s**.
- Paging day ↔ day **inside the same week preserves the vertical hour offset** (all of 29 / 30 / 31 sit at 5 AM in the 18–23 s window).

### 3.4 Day → Month (back pill) — 24.05 → 24.60 s
| t | Observation |
|---|---|
| 24.05 – 24.10 | Back pill pressed (light fill highlight). |
| 24.15 | Release. Selection circle turns grey; timeline starts collapsing; header buttons blur-dissolve. |
| 24.20 – 24.40 | Exact reverse of §3.1: week row slides **down** to its place in the month, rows above slide in from the top, rows below rise from the bottom, "July" title fades in, subtitle fades out. |
| 24.45 – 24.60 | Settles; circle gone (Month has **no persistent selection**); pill reads "2026". |
Total ≈ **0.45 s**.

### 3.5 Today in Month, far away — 35.60 → 35.85 s
- Single-frame cut from April 2027 to October 2026 (no scroll animation). Landing position: October's
  title row at the top, today's week visible. Today pill pressed fill 35.60 – 35.80.

### 3.6 Search open / close — 38.80 → 39.25 s, 54.45 → 55.00 s
- Open: search glyph press-dims (38.80), the right capsule stretches leftward over the back pill
  (38.85 – 39.00), becomes a full-width field with placeholder "Search" + mic + a separate ✕ circle
  (39.05); keyboard rises in parallel (39.05 – 39.25). The large month title and grid do **not** move.
- Close: reverse; results/empty state fade out, grid fades back in at the scroll position it had.

## 4. Static anatomy (from 440 pt stills in `frames/` — 1 px = 1 pt)

| Element | Measured |
|---|---|
| Header buttons | 44 pt tall glass pills, centre y 84; back pill x 20–112; right capsule x 258–420 |
| Month title | "September", bold ≈ 32 pt, x 20, baseline ≈ 155 |
| Weekday letters | S M T W T F S, ≈ 10 pt semibold, grey, centre y 177; one per column |
| Columns | **7 equal full-width columns**, 440 / 7 = 62.86 pt; numerals centred at 31, 94, 157, 220, 283, 346, 409 |
| Week row pitch | **69 pt** |
| Day numeral | ≈ 19 pt semibold; Mon–Fri white, **Sat/Sun grey** |
| Today | **red filled circle Ø ≈ 40**, white bold numeral |
| Event indicators | 4 pt-tall capsule **≈ 29 pt below the numeral's centre**; a single event = dot Ø ≈ 5; more events widen the capsule (≈ 6 / 18 / 30 pt) with one colour segment per event |
| Week separators | hairline at the **top** of each week row, spanning **only the columns that hold that month's days** (Sep 27–30 row: x 0–252; Oct 1–3 row: x 252–440) |
| Inline month label | "Oct" bold ≈ 17 pt, centred over the column of the 1st, ≈ 43 pt above the first row's numerals; **red for the current month**, white otherwise; adds ≈ 27 pt to the gap between months |
| Today pill | 44 pt tall, x 28–106, centre y 904 |
| Week strip (Day) | letters centre y 124; numerals ≈ 19 pt regular centre y 154; **selected = white circle Ø ≈ 36 + black bold numeral**; today-selected = red circle + white numeral; hairline y 183 |
| Day subtitle | "Friday – Jul 31, 2026" semibold ≈ 15 pt, centred, y 201; hairline y 218 |
| Timeline | **50 pt per hour**; labels right-aligned to x ≈ 56 ("10" ≈ 13 pt + "AM" ≈ 8 pt; "Noon" replaces 12 PM); hour hairlines from x ≈ 66 to the edge; range 12 AM → 12 AM |
| Event block | fill = event colour at ≈ 25 % over black, radius ≈ 4, 3 pt solid left bar in the colour, title semibold ≈ 13 pt tinted, 2nd line ≈ 11 pt (location / conference) with a leading glyph, repeat glyph top-right; min height ≈ 20 pt; overlapping events split the width into side-by-side columns |
| All-day row | label "all-day" ≈ 9 pt in the gutter; capsule chips ≈ 20 pt tall, full width minus gutter, pinned under the subtitle |
| Current time | red 1 pt line across the timeline + red capsule "10:42" (white ≈ 9 pt bold) in the gutter — **today only** |
| Search results | day header "Thursday – Oct 17, 2019" semibold ≈ 13 pt; rows: 3 pt colour bar, title ≈ 15 pt, 2nd line ≈ 11 pt with glyph, right column start/end times ≈ 11 pt or "all-day"; past rows ≈ 50 % opacity |

## 5. Things in the reference MakeReady drops (per the owner)

- Both icons at the bottom-right (calendar-list and inbox).
- The first top-right icon (month-style / list toggle).
- The year back-pill ("‹ 2026") — there is no year view; see 02-design §2.1 for what replaces it.
- Any multi-day / list mode: tapping a date shows **only that day**.
- iOS glass buttons → MakeReady 2.0 components (02-design §3).
