# study-program-home — Study Program Home (leader program overview)

Platform: iphone · Status: specced · Specced: 2026-09-01

> Screen id note: renamed from the README's provisional `programs-home` row 2026-09-01 —
> the user-supplied id matches the Figma frame name ("Study program home"). Same screen
> identity; no spec existed under the old id.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3524-29600
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3524:29600` ("Study program home", 440×1896)
- Frozen snapshot: `assets/study-program-home.png` — captured 2026-09-01
- Component-sheet probes (node `3632:4502`, D9): Header set `3313:7615`, Group card set
  `3526:30373`, Enrollment status set `3526:30288`, Percentages set `3526:30471`,
  Metadta set `3518:29457`, Detail set `3499:27340` — probed 2026-09-01

**Deviations (closed list):**
1. All values, names, dates, images, and counts in the frame are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The day rail and activities strip render as horizontal scrollers; the frame clips their overflow (14 day chips at 474pt in a 408pt column; 3 thumbnails at 428pt in a 376pt box).
4. The frame's progress-bar green fill `#4deb4b` and the completion-label green `color-positive` (#6cff73) disagree — the build uses one green per the OQ-home-dashboard-6 ruling when it lands; until then the frame's literals stand.

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page (C-040 back chevron), full-height vertical scroll on `color-layout-background`.
System status bar → **C-040 PageHeader** 56pt, variant `Two icons`: back left, centered
static title "Program overview" (SF Pro Regular 14/20 white), right group 24pt gap =
GlyphButton export + GlyphButton settings → scrolling content column, `space-page-margin`
(16) padding, `space-section-gap` (32) between blocks, sections separated by 1px
`color-layout-border` hairlines (32 above and below, i.e. one gap step each side).

1. **Cover** — 408×180, `radius-card` (8), program cover image fill (object-cover);
   **C-053 StatusBadge** overlaid top-left inset 8/8.
2. **Info** — program name (SF Pro Bold 14/20 = `type-title-card`, white, single line,
   tail-ellipsis) → `space-element-gap` (8) → description (SF Pro Regular 14/20,
   `color-white-70`, single line, tail-ellipsis).
3. **Details grid** — 2×2 of **C-041 DetailPair**, 16pt column/row gaps: Enrollments
   (count) · Author (creator name) · Created (`Mon D, YYYY`) · Published (`Mon D, YYYY`).
4. *hairline*
5. **Lessons section** — **C-020 SectionHeader** (title `type-section-title` 18/24;
   accessory `meta-button`: meta pair "365"+"days" + **C-021 GlyphButton** `add`) → 16 →
   **day rail**: horizontally scrolling row of **C-052 DayChip** 32×40, gap
   `space-chip-gap` (2), exactly one `Active`; N = program day count → 32 → **lesson
   block** for the selected day: subsection header 20pt (lesson title
   `type-subtitle-semibold` 14/20 white, single line ellipsis; right: meta pair
   "12"+"mins" + 24pt share/export button — OQ-2) → 16 → **activities strip**:
   horizontally scrolling **C-056 ActivityThumbnail** 140×249, gap `space-meta-gap` (4),
   one per activity in day order.
6. *hairline*
7. **Group Activity section** (children gap 32) — **C-020** (accessory `meta-button`:
   meta pair "15"+"enrollments" + **C-021** `arrowRight`) → **C-031 EnrollmentStatusRow**
   408×64 (program-scoped: percent circle, label "Members current", current-member count,
   C-057 bar Thick/Right, subtitle "«total» total members enrolled across «groups»
   groups") → "Recent activity" label (SF Pro Regular 14/16 `color-text-secondary`) →
   **group list**: **C-054 GroupEnrollmentCard** 408×88, `status=Progress`, gap 32, one
   per enrollment.
8. *hairline*
9. **Demographics section** (gap 16) — **C-020** (accessory `none`) → **C-055
   CategoryBarTable**: column-label row ("% completion", "lessons" — both
   `color-text-secondary` 14/16) + five fixed age-bin rows (18 – 25 · 26 – 35 · 36 – 45 ·
   46 – 60 · 61 and up), rows gap `space-row-gap` (24).

**Per-screen literals (flagged per D7):** progress fill `#4deb4b` (recurs from
OQ-home-dashboard-6); demographics bar palette `#75c8ff` `#b594ff` `#eda3e6` `#4deb4b`
`#ceff4e` (no Figma variables — OQ-6); badge text metrics (SF Pro Text Bold 12 /
line-height 1.4 / tracking −0.24 / 70% opacity) inside C-053's contract.

## 3. Behavior contract

**States (closed list), per section** (page never blanks; header + cover render from the
program record):
- `loading` — skeleton in the section's content footprint; section headers render immediately.
- `populated` — as §2.
- `empty` — Lessons: day rail renders all days, activities strip empty for a day whose
  lesson has zero activities (strip footprint collapses); Group Activity: C-031 zeroed +
  "Recent activity" with no cards when zero enrollments; Demographics: rows render with
  zero-width bars and "0" counts (OQ-7 covers the undesigned visuals — proposed defaults,
  not designed fact).
- `error` — section-level inline retry; other sections unaffected.
- Publish gating: `isPublished=true` → C-053 `published`; `false` → C-053 proposed
  `draft` state (undesigned — OQ-4). The Published DetailPair renders `—` when
  `publishedAt` is null.

**Interactions (closed list):**
- Back (C-040) → pop to caller.
- Header export → program export flow (deferred surface — OQ-3).
- Header settings → program settings/edit surface (deferred surface — OQ-3).
- Lessons header add (C-021 `add`) → add a new day/lesson at the end (proposed default — OQ-1).
- DayChip tap → that day becomes `Active` (single selection); lesson block re-renders to
  the selected day's lesson. Rail scrolls freely; selection does not follow scroll.
- Lesson-row share button → lesson share/export (glyph is normative; semantics OQ-2).
- ActivityThumbnail tap → `activities-editor` for that activity (edge held from the
  prior screen-map; contract owned by the activities-editor spec).
- Group Activity arrowRight → program-enrollments detail destination deferred (OQ-3).
- GroupEnrollmentCard tap → destination deferred (OQ-3).
- Vertical scroll everywhere else; no pull-to-refresh contract on this frame.

**Motion:** none bespoke — system scroll and push/pop only. Day-selection swap of the
lesson block is an immediate re-render unless the activities-editor suite rules otherwise.

## 4. Components

Closed list of registry rows this screen renders:
- **C-020 SectionHeader** — Lessons / Group Activity / Demographics headers (amended: size variants)
- **C-021 GlyphButton** — add (Lessons), arrowRight (Group Activity); export + settings via C-040
- **C-022 MetaPair** — "365 days", "12 mins", "15 enrollments" pairs (amended: emphasis rendering)
- **C-031 EnrollmentStatusRow** — program-scoped members-current row
- **C-038 Avatar** — 64pt group photo inside C-054
- **C-040 PageHeader** — Two-icons pushed-page bar (first consumer of the icons variant)
- **C-041 DetailPair** — 2×2 details grid
- **C-043 MetaChip** — Key-value chips in C-054 (first consumer of `align=Right`)
- **C-052 DayChip** — day rail chip *(introduced here)*
- **C-053 StatusBadge** — cover badge *(introduced here)*
- **C-054 GroupEnrollmentCard** — recent-activity group rows *(introduced here)*
- **C-055 CategoryBarTable** — age-bin completion table *(introduced here)*
- **C-056 ActivityThumbnail** — activities strip card *(introduced here)*
- **C-057 PercentBar** — progress bar unit inside C-031/C-054 *(formalized here)*

### C-052 DayChip (new)
32×40, `radius-card-sm` (4), centered day number SF Pro Regular 14 white. Main
components `3495:2777` (Default) / `3495:2787` (Active) — frame-local, not on the sheet.
Props: `day: Int`, `state`, `onTap`.
**State coverage:** Figma defines `Default` (`color-white-20` fill) and `Active`
(`color-accent` fill) only. The contract needs no more for v1; completed/locked/pressed
are undesigned and may not be built without frames (OQ-7).

### C-053 StatusBadge (new)
Nodes `3524:29722/29723` (frame-local, no sheet set). Pill px 8 / py 4, `radius-card-sm`,
label SF Pro Text Bold 12, line-height 1.4, tracking −0.24, `color-black` at 70% opacity.
Props: `state: published | draft`.
**State coverage:** Figma designs `published` only ("Published" on `color-positive`).
`draft` is a **proposed default** ("Draft" on `color-white-20`, white text) pending
ratification or a frame (OQ-4).

### C-054 GroupEnrollmentCard (new)
Sheet set `3526:30373`, variants `status={Default, Progress}`; 408×88. Consumed here:
`status=Progress` — 16 gap row: **C-038 Avatar** 64 (group photo) + details column
(gap 16): title (`type-title-card`, single line ellipsis) → 8 → completion line (16 gap:
"«n»% complete" SF Pro Regular 14/20 in the status color + **C-057 PercentBar**
Thick/Right, flex) → chip row gap `space-chip-gap` (2): **C-043 MetaChip** Key-value
align=Right "Enrolled «Mon D, YYYY»" + Key-value align=Left "«n» members".
Completion color: `color-positive` at 60% and 18%, `color-negative` at 5% in the frame —
the banding rule is undesigned (OQ-5; same family as OQ-home-dashboard-3). Bar fill
literals per §2 flag. Props: `groupName`, `photoURL`, `completionPercent`, `statusColor`,
`enrolledLabel`, `memberCount`, `onTap`.
**State coverage:** `status=Progress` consumed; `status=Default` designed-unconsumed —
not built without a ruling (OQ-5). No empty/pressed states designed.

### C-055 CategoryBarTable (new)
Frame-local (nodes `3524:29777…29818`), no sheet set. Column-label row (24pt: 100pt
spacer + "% completion" right-aligned in flex + "lessons" right-aligned 100pt, both
`color-text-secondary` 14/16) then five rows (gap 24, each 16pt): age-bin label
(`color-text-secondary` 14/16, 100pt) + bar cell (flex, right-aligned 16pt bar whose
width ∝ % completion) + count label (white 14/16, right-aligned 100pt, abbreviated
"17.3k" formatting). Bins closed: 18 – 25, 26 – 35, 36 – 45, 46 – 60, 61 and up. Bar
colors are the flagged per-screen palette (OQ-6). Props: `rows: [(binLabel, percent,
lessonsLabel)]`.
**State coverage:** one populated instance designed; zero-data and unknown-age handling
are proposed defaults under OQ-7.

### C-056 ActivityThumbnail (new)
Frame-local (nodes `3524:29763–29765`). 140×249, `radius-card` (8), image fill
(object-cover), shadow `elevation-thumbnail` (0 4 4 rgba(0,0,0,0.2)). Props:
`imageURL`, `onTap`.
**State coverage:** only the populated image card is designed. Thumbnail source for
non-video activities and the no-thumbnail fallback are proposed defaults under OQ-8. The
activities-editor/player specs may absorb or extend this row when the pager rows mint.

### C-057 PercentBar (formalized)
Sheet set `3526:30471` ("Percentages") — the bar unit already cited inside C-031 and
C-044; promoted to its own row now that three composites share it (C-031, C-044, C-054).
Track `color-white-10`, fill segment in the consumer's status color (frame literal
anomaly per §2). Variant axes (closed, from the sheet): `style={Thick 16pt, Thin 2pt}` ×
`aligned={Right, Left}` (the `Percent` axis is sample fill levels, not a variant).
Consumed here: Thick/Right (C-031, C-054). C-044 consumes Thin/Left. Props: `progress:
0…1`, `fillColor`, `style`, `aligned`.

### Amendments to existing rows (closed change lists)
- **C-040 PageHeader** — the true set is `3313:7615` with `style={Default, Text buttons,
  Two icons}` (the row previously cited only the Two-icons symbol `3524:29584`). This
  screen consumes `Two icons` + `showTitle` + `showIcons` (right group: export + settings
  GlyphButtons, 24 gap) — the only consumer of the icons-on case. `Text buttons` is
  designed-unconsumed — not built without a consuming spec. No other change.
  **Superseded 2026-09-05:** the full contract (all three styles, both booleans, the
  pushed-page presentation) now lives at
  `../design-system/components/C-040-page-header.md`; this amendment stays as the record of
  the set correction.
- **C-020 SectionHeader** — gains a closed `size` axis measured here: `section` (title
  `type-section-title` SF Pro Semibold 18/24, 24pt row — Lessons/Group Activity/
  Demographics) and `subsection` (title `type-subtitle-semibold` 14/20, 20pt row — the
  lesson block header). The home spec's "SF Pro Bold ~16" approximation is superseded by
  the measured 18/24 Semibold (hygiene note in OQ-9). No other change.
- **C-022 MetaPair** — on this frame the pair renders value SF Pro **Bold** 12 white +
  label `color-white-50` (home rendered Regular + `color-text-secondary`). Recorded as
  Figma drift (OQ-9); this screen follows its own frame. No prop change.
- **C-043 MetaChip** — `align=Right` (Key value) moves from designed-unconsumed to
  consumed (C-054's "Enrolled «date»" chip). No other change.

## 5. Data & API

Read-only screen — every edit affordance exits to another surface. Verified against the
makeready-api MCP + `server/src/routes` 2026-09-01:

| Need | Endpoint | Status |
|---|---|---|
| Program record (name, description, coverImageUrl, isPublished, createdAt, days, enrollment + lesson counts) | `GET /api/programs/{id}` (verified: selects all of these incl. `_count.{lessons,enrollments}`) | ✅ exists |
| Author name + published date (Details grid) | same endpoint — the select omits `publishedAt` and the creator's name (model has both: `StudyProgram.publishedAt`, `creator` relation) | **API-GAP (additive):** add `publishedAt` + `creator.name` to the detail select |
| Day rail + selected day's lesson + activities (dayNumber, title, estimatedMinutes, activity list) | `GET /api/programs/{id}` paginated `lessons` (verified: `dayNumber`, `title`, `estimatedMinutes`, activities with `video.thumbnailUrl` / `youtubeThumbnailUrl`) | ✅ exists; a 365-day program spans lesson pages (`lessonLimit` max 60) — rail hydrates from `days` + `_count.lessons`, lesson bodies page in |
| Activity thumbnails for non-video activity types | — | **API-GAP / OQ-8:** no stored preview for read/exegesis/input activities |
| Members-current aggregate (29%, count, totals subtitle) | `GET /api/programs/{programId}/analytics` (verified — Phase A KPI/series/heatmap payload) covers the KPI plumbing | **API-GAP:** a program-scoped "members current" metric — pends the same "current" definition as OQ-home-dashboard-1 |
| Per-group rows (group name/photo/member count, enrolled date, completion %) | `GET /api/programs/{programId}/enrollments` (verified: group name/cover/`_count.members`, `startDate`; **no completion**) + `GET /api/enrollments/{id}/completion-stats` (verified, per-enrollment) | **API-GAP:** bundle per-enrollment completion (and recency, per OQ-5's ordering) into the list payload — client fan-out would be N+1 |
| Demographics rows (age bins × % completion × lesson counts) | — (`Member.birthday` and `gender` exist in `server/prisma/schema.prisma` Member model, so it's computable) | **API-GAP:** program-scoped age-bin aggregate endpoint (closed bins per §2; per-bin % completion + lessons-completed count) |

Writes: none. Contract shapes belong to the build suite's `03-data-and-api.md`; the
analytics additive-only policy applies.

## 6. Connections

- **Entry:** `library-home` → study-program-home (push, program row tap — trigger to be
  confirmed when `library-home` is specced; this frame's back chevron proves the pushed
  presentation). The prior screen-map `shell-tabs → programs-home (tab)` edge is
  **removed** — the 2.0 tab set evidenced on home-dashboard has no Programs tab, and this
  header is a pushed-page bar.
- **Exits:** back → caller · header export → export flow (deferred, OQ-3) · header
  settings → program settings surface (deferred, OQ-3) · Lessons add → add-lesson
  behavior (OQ-1) · lesson share button → lesson share/export (OQ-2) · Group Activity
  arrowRight → program-enrollments destination (deferred, OQ-3) · GroupEnrollmentCard
  tap → deferred (OQ-3) · ActivityThumbnail tap → `activities-editor` (push; contract
  owned by that spec).
- **Overlays:** none on this frame.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

Replaces **`iphone/MakeReady/Pages/Manage/Program/ProgramHomePage.swift`** —
`Route.swift` case `.programHome` (`iphone/MakeReady/Services/Route.swift:51`), the
legacy `.programHome` modal. (Correction: the old README row said "replaces
`StudyProgramHome`", but `Pages/Main/StudyProgramHome.swift` is `MainPrograms` — the
programs *list*, which `library-home` replaces. The per-program screen is
ProgramHomePage.)

| Legacy capability (ProgramHomePage) | 2.0 disposition |
|---|---|
| Lessons tab (lesson list, add lesson, EditDay entry, reorder/swipe-delete) | **merged** — day rail + lesson block; add via Lessons header (OQ-1); reorder/delete not on this frame → gap-analysis candidates |
| Enrollments tab (enrollment rows, enroll flow entry) | **merged** — Group Activity section; enroll/respond flows not on this frame → arrowRight destination (OQ-3) |
| Analytics tab (`docs/features/analytics/` Program tab) | **partially carried** — members-current row + demographics here; KPI/series/heatmap content → dropped-candidate for gap analysis |
| Edit program settings (`.editProgram` inline form) | **carried via exit** — header settings glyph (deferred surface, OQ-3) |
| Publish badge + publish-updates flow | **carried** — C-053 badge; the publish/update dialogs are not on this frame → OQ-4/gap analysis |
| Export flow (preview → confirm → save) | **carried via exit** — header export glyph (deferred surface, OQ-3) |
| Preview system (activity/lesson previews) | **dropped by decision** — activities model kills previews (README: activities notes; D4) |

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-study-program-home-1 | Lessons header `add`: add a day/lesson at the end (proposed default, matches legacy addLesson) or open an add menu? | No — default proposed | owner |
| OQ-study-program-home-2 | Lesson-row accessory renders the **export/share glyph** inside an Add-variant C-021 slot (icon-swap in the frame). Share the lesson, or is the glyph itself the drift? | No — glyph treated as normative (share) | owner |
| OQ-study-program-home-3 | Deferred destinations: header settings surface, header export flow, Group Activity arrowRight target, GroupEnrollmentCard tap. All need future frames. | No — exits deferred like home's OQ-1/4 | owner (frames) |
| OQ-study-program-home-4 | C-053 `draft` state is undesigned (proposed: "Draft" on `color-white-20`); the publish/update dialog flow's 2.0 home is also unplaced. | No — default proposed | owner |
| OQ-study-program-home-5 | C-054: completion-color banding (green at 18% but red at 5% — thresholds undefined; joins OQ-home-dashboard-3), and when does `status=Default` (designed-unconsumed) appear? Unenumerated variants are not built without a ruling. | No | owner |
| OQ-study-program-home-6 | "Recent activity" ordering rule (frame order matches neither startDate desc nor alpha; proposed: most-recent member completion, desc) + demographics bar palette has no Figma variables — tokenize as a categorical chart family or keep per-screen literals? | No — defaults proposed | owner |
| OQ-study-program-home-7 | Undesigned states: DayChip beyond Default/Active; empty-program / zero-data visuals for Lessons, Group Activity, Demographics. Proposed defaults in §3; may not be built beyond them without frames. | No — defaults proposed | owner |
| OQ-study-program-home-8 | Thumbnail source for non-video activities (video/YouTube thumbs verified in the API; proposed: themed render/placeholder derived from the activity theme). | No — default proposed | owner + backend suite |
| OQ-study-program-home-9 | Figma drift hygiene: C-022 value-weight/label-color differs from home's frame; C-020 title measured 18/24 Semibold vs home spec's "~16 Bold" approximation. One rendering should win file-wide. | No — each screen follows its own frame meanwhile | owner (Figma cleanup) |
