# enrollment-home — Enrollment Home (single-enrollment detail)

Platform: iphone · Status: specced · Specced: 2026-09-02

The page opened by tapping an enrollment (owner, 2026-09-02) — one group's run of one
program: program identity, schedule span, per-day completion, and the lesson-by-lesson
activity strips.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3773-6944
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3773:6944` ("Enrollment home", 440×1893)
- Frozen snapshot: `assets/enrollment-home.png` — captured 2026-09-02
- Component-sheet sets consumed (D9): Day `3672:9223` (state=Percent circle `3822:34333`),
  Date `3672:10251` (state=Today), Activity details `3673:10832` (state=Lesson day
  `3822:34510`), Percent and size `3822:34382`, Slide `3312:1429`, Calendar date
  `3836:7851`, Text metadata `3836:7920`, Header `3313:7615`, Detail `3499:27340`,
  Button `3499:27547` (calendar glyph).

**Deviations (closed list):**
1. All names, dates, values, images, and fill widths are sample content.
2. The status bar is the iOS system status bar.
3. The day rail and each lesson card's slide rail render as horizontal scrollers; the
   frame clips their overflow (4th day card and 5th slide cut at the edge).
4. One `Slide` instance in the second lesson card is `hidden` in Figma — not rendered.
5. Progress/banding colors are per-screen literals pending the banding ruling (OQ-3):
   `#4deb4b` (lesson bar fill), `#ffb53e` (yellow disc), plus token colors
   `color-positive`/`color-negative` on discs; slide placeholder bg `#2e2e2e`.

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page: system status bar → **C-040 PageHeader** (`Two icons` + `showIcons=false`:
back + centered title "Enrollment", no right icons) → vertical scroll content (py16,
column gap `space-section-gap` 32; sections px16 except the full-bleed rails):

1. **Program identity block** — same anatomy as study-program-home §2 items 1–3 minus the
   badge: cover 408×180 `radius-card` (no C-053 StatusBadge) → program title
   (`type-title-card`, 1-line ellipsis) + 8 → description (Regular 14/20 `color-white-70`,
   1-line ellipsis) → 2×2 **C-041 DetailPair** grid (16 gaps): Members (count) · Author ·
   Enrolled (`Mon D, YYYY`) · Group leader.
2. *hairline* (`color-layout-border`).
3. **Schedule section** — **C-020 SectionHeader** (`type-section-title`; accessory
   `text-link+button`: "Edit schedule" text-link (Regular 12/24 `color-text-secondary`)
   + 16 + **C-021 GlyphButton** `calendar`) → 32 → span row (16 gap): **C-060
   CalendarDateCard** (start date) + **C-064 DateSpanIndicator** (flex, "«3» months
   «3» days" between arrow glyphs) + **C-060** (end date).
4. **Daily progress rail** — full-bleed horizontal scroll of **C-025 DayActivityCard**
   131×192 (shared 1px borders, −1 overlap as on home), in the `Percent circle` body
   state: Date block (MMM + weekday caps 12 secondary; date 18 white; TODAY variant:
   "TODAY" in `color-highlight`) + centered **C-062 PercentDisc** + Activity-details
   caption (`Lesson day` state: lesson count Bold 12 `color-accent` + time Regular 12
   `color-text-secondary`).
5. **Lesson cards** — one **C-063 LessonCard** per listed lesson (three in frame),
   stacked with no divider: py16; title row px16 (lesson number Bold 14
   `color-accent` + title Bold 14 white flex ellipsis + relative-date meta Regular 14
   `color-text-secondary`: "Today" / "Tomorrow" / "Mon D"); today's card only: 2pt
   full-width progress bar (track `color-white-20`, fill `#4deb4b` literal) 8 below the
   title row; → 16 → slide rail (px16, gap `space-meta-gap` 4, horizontal scroll):
   **C-061 ActivitySlide** 112×244 per activity.

## 3. Behavior contract

**States (closed list):**
- `loading` — header + program identity render from the tapped row's data; sections
  skeleton.
- `populated` — as §2.
- `empty-schedule` (no scheduled lessons) — schedule section renders with start card only
  + zeroed span; day rail and lesson cards absent (undesigned — proposed default, OQ-8).
- `error` — section-level inline retry; page never blanks.

**Interactions (closed list):**
- Back → pop to the presenting screen.
- "Edit schedule" text-link → `enrollment-schedule-edit` (new screen, pending Figma —
  row added this run).
- Calendar glyph → calendar view of this enrollment's schedule — destination deferred
  (OQ-1).
- Day rail: horizontal scroll; day-card tap deferred (OQ-1).
- LessonCard title row tap and ActivitySlide tap: deferred — expected to enter the
  leader's edit-in-place canvas (`activities-editor` owns that contract when specced;
  OQ-1).
- DateSpanIndicator is static (proposed default — its arrows point at the two date
  cards; no designed pressed/interactive state; OQ-5).

**Motion:** system scroll + push/pop only; nothing bespoke designed.

## 4. Components

Closed list rendered: **C-020 SectionHeader** (accessory `text-link+button` — new combo) ·
**C-021 GlyphButton** (`calendar` — first consumer) · **C-022 MetaPair** (×2 inside
C-064) · **C-025 DayActivityCard** (`Percent circle` body + `Today` date + `Lesson day`
details — all first-consumed here) · **C-040 PageHeader** (Two icons, `showIcons=false`) ·
**C-041 DetailPair** (×4) · **C-060 CalendarDateCard** *(introduced)* · **C-061
ActivitySlide** *(introduced)* · **C-062 PercentDisc** *(introduced)* · **C-063
LessonCard** *(introduced)* · **C-064 DateSpanIndicator** *(introduced)*.

### C-060 CalendarDateCard (new)
Sheet component `3836:7851`, single `state=Default`. 96×88: `color-card-background` fill,
1px `color-card-border`, `radius-card` (8); header row p8 (month Bold 12
`color-negative` + weekday Bold 12 `color-text-secondary`, space-between) over a 1px
hairline, then date Regular 40/40 white p8. Month red is the fixed calendar accent
(proposed reading — OQ-6). Props: `month`, `weekday`, `date`.
**State coverage:** single designed state; no today/selected/disabled variants designed.

### C-061 ActivitySlide (new)
Sheet set `3312:1429` ("Slide"): **`state {Empty, Add, Fill, Incomplete} × active
{false, true}` — 7 designed variants** (no Add/active). Consumed here: `Fill`/inactive —
112×244 slide, inner Image wrapper `radius-card` (8), bg `#2e2e2e` literal, image fill.
Props: `state`, `active`, `imageURL?`, `onTap`.
**State coverage:** Fill/inactive consumed; Empty, Add, Incomplete, and the active=true
axis are designed-unconsumed — not built without a consuming spec (expected consumer:
`activities-editor`; OQ-8). **Consolidation flag:** C-056 ActivityThumbnail
(study-program-home, 140×249 + shadow, frame-local) covers the same role at different
geometry — owner to rule one unit or two (OQ-2).

### C-062 PercentDisc (new)
Sheet set `3822:34382` ("Percent and size"): completion disc whose **color AND diameter
encode the band** — designed sizes `Green 1` (80pt), `Green 2`, `Yellow 1` (56pt,
`#ffb53e`), `Yellow 2`, `Red 1` (44pt, `color-negative`), `size6`. Fill = band color at
20% opacity; number Bold 14 + "%" Semibold 9, in the band color. Consumed here: Green 1
(78%), Yellow 1 (65%), Red 1 (24%). Props: `percent`, `band`.
**State coverage:** three of six variants consumed; Green 2 / Yellow 2 / size6
designed-unconsumed (OQ-8). Band thresholds undesigned (OQ-3). Cross-note: C-031's
64pt percent circle is a fixed-size sibling, not this unit.

### C-063 LessonCard (new)
Frame-local (`3821:33713…`). py16 block: title row px16, 10 gap (lesson number Bold
14/20 `color-accent` · title Bold 14/20 white, flex, tail-ellipsis · relative-date meta
Regular 14/20 `color-text-secondary` — "Today"/"Tomorrow" for ±1 day, else "Mon D") ·
variant `withProgress` (today's lesson only in frame): 2pt full-width bar 8 under the
title row — track `color-white-20`, fill `#4deb4b` (track diverges from C-057's
`color-white-10` — drift flag, OQ-4) · 16 · slide rail (px16, gap 4) of C-061. Props:
`lessonNumber`, `title`, `dateLabel`, `progress?`, `slides`, `onOpen`.
**State coverage:** `withProgress` and plain both designed (cards 4 vs 5/6); completed/
locked/empty-activities undesigned (OQ-8).

### C-064 DateSpanIndicator (new)
Sheet component `3836:7920` ("Text metadata"), single variant. 184×88 centered row, 8
gap: arrow-left glyph 24 · **C-022 MetaPair** "«n» months" · MetaPair "«n» days" ·
arrow-right glyph 24. Pairs render Regular 12/24 white value + `color-text-secondary`
label — matching home's C-022 rendering (evidence against study-program-home's bold
variant; logged on OQ-study-program-home-9). Props: `months`, `days`.
**State coverage:** single designed state; static (OQ-5).

### Amendments (dated 2026-09-02)
- **C-025 DayActivityCard** — first consumption of three designed sheet states: body
  `Percent circle` (centers C-062), Date `Today` ("TODAY" `color-highlight` marker), and
  Activity details `Lesson day` (count `color-accent` + time). Closed change: these
  states join the contract; home's `Default`/zero-dimmed usage unchanged.
- **C-020 SectionHeader** — accessory list gains the `text-link+button` combo (text-link
  + 16 gap + GlyphButton), closed. "Edit schedule" renders `color-text-secondary`
  (more OQ-shared-edit-field-4 evidence).
- **C-021 GlyphButton** — `calendar` glyph moves to consumed.
- **C-040 PageHeader** — no contract change; second consumer of Two-icons+`showIcons=false`.

## 5. Data & API

Read-only screen (edit affordances exit). Verified against the makeready-api MCP
2026-09-02:

| Need | Endpoint | Status |
|---|---|---|
| Enrollment record (program title/description/cover/author, group, leader, member count, startDate) | `GET /api/enrollments/{id}` (verified) + `GET /api/programs/{id}` (verified) for program fields | ✅ exists; field-completeness audited by the build suite |
| Schedule span (start/end dates, months+days arithmetic) | `GET /api/enrollments/{id}` + its schedules (schedule family verified: `POST/PATCH/DELETE /api/enrollments/{id}/schedules…`) | ✅ pieces exist; span math is client-side |
| Per-day completion discs (percent per scheduled day, lesson count, time) | `GET /api/enrollments/{id}/completion-stats` (verified — per-lesson/per-activity distinct-member counts) | **API-GAP: day-bucketed completion** — stats are per-lesson, not per-scheduled-day with times; extend or assemble |
| Lesson cards (scheduled lessons with dates, per-lesson progress, activities with slide thumbnails) | `GET /api/enrollments/{enrollmentId}/schedules/{scheduleId}/activities` (verified) + completion-stats | **API-GAP: one assembled enrollment-home payload** — per-schedule fan-out is N+1; slide thumbnail source for non-video activities is the same gap as OQ-study-program-home-8 |

Writes: none.

## 6. Connections

- **Entry:** `enrollments-home` → enrollment-home (push, C-059 EnrollmentProgressRow tap
  — **resolves the row-tap half of OQ-enrollments-home-5**; the group-arrow half stays
  open). Future entries expected from home-dashboard's followed-enrollment cards
  (OQ-home-dashboard-4) and group surfaces — each added by its own spec.
- **Exits:** back → caller · "Edit schedule" → `enrollment-schedule-edit` (pending-figma
  row added this run) · calendar glyph → deferred (OQ-1) · day-card / lesson-card /
  slide taps → deferred; slides expected to hand off to `activities-editor` (OQ-1).
- **Overlays:** none.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

| Legacy element | Disposition |
|---|---|
| `Pages/View/...` enrollment schedule family (`.enrollmentSchedule` route; schedule list, `CardLesson` rows — `parity-enrollment-schedule` dossier) | **replaced** — schedule span + day rail + lesson cards on one page |
| Edit-day / scheduled-activity editors (`EditDay.swift`, scheduled read/exegesis/input editors) | **carried via exits** — slides hand off to the `activities-editor` canvas (contract there); `enrollment-schedule-edit` takes the schedule-editing half |
| `UnenrollConfirmation.swift` + unenroll flow (`GET /api/enrollments/{id}/unenroll-info`) | **dropped-candidate on this frame** — no unenroll affordance designed; gap-analysis must place it (likely the settings-style surface this header deliberately omits) |
| Enrollment sync ("Review changes", `/api/enrollments/{id}/sync*`) | **dropped-candidate on this frame** — no sync affordance designed; gap-analysis item |
| Legacy `ScheduledLessonCard` | dead in legacy already (per `parity-enrollment-schedule`); not carried |

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-enrollment-home-1 | Deferred destinations: calendar-glyph target, day-card tap, lesson-card/slide tap (expected: `activities-editor`) | No — exits deferred per precedent | owner (frames / activities-editor spec) |
| OQ-enrollment-home-2 | C-056 ActivityThumbnail vs C-061 ActivitySlide: same unit at two geometries or two components? | No — both contracts stand alone meanwhile | owner |
| OQ-enrollment-home-3 | Banding, again with new encoding: PercentDisc adds SIZE to the color code (80/56/44pt) and a fourth observed color family (`#ffb53e` beside `#4deb4b`/`#e3eb4b`/`#ff4759`). One program-wide banding ruling (thresholds + palette + whether size-coding is canonical) would close OQs on four screens | No | owner |
| OQ-enrollment-home-4 | C-063's bar track is `color-white-20`; C-057's is `color-white-10` — same-role drift, one should win | No | owner (Figma cleanup) |
| OQ-enrollment-home-5 | DateSpanIndicator: static (proposed) or interactive (arrows suggest nothing designed)? | No — default proposed | owner |
| OQ-enrollment-home-6 | CalendarDateCard month in `color-negative` — fixed calendar accent (proposed) or a status color? | No — default proposed | owner |
| OQ-enrollment-home-7 | Lesson-card window: which lessons render (frame shows today + next two) and the rail's date window — proposed: upcoming from today, past reachable by scrolling the day rail | No — default proposed | owner |
| OQ-enrollment-home-8 | Undesigned/unconsumed variants: empty-schedule state, C-061's Empty/Add/Incomplete/active axis, C-062's Green 2/Yellow 2/size6, C-063 completed/locked — used variants are contracted; unenumerated ones may not be built without a ruling | No | owner |
