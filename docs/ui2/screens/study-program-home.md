# study-program-home — Study Program Home (leader program overview)

Platform: iphone · Status: specced · Specced: 2026-09-01 · **Re-specced: 2026-09-10**
(source re-pointed to node `3833:32194` per owner — a **substantially different frame**, not
a refinement: see the drift table in §1)

> Screen id note: renamed from the README's provisional `programs-home` row 2026-09-01 —
> the user-supplied id matches the Figma frame name ("Study program home"). Same screen
> identity; no spec existed under the old id.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3833-32194
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3833:32194` ("Study program home", 440×2521)
- Frozen snapshot: `assets/study-program-home.png` — captured 2026-09-10
- **Superseded source:** node `3524:29600` (440×1896, same frame name), the 2026-09-01
  normative source. Both frames exist in the file; the owner designated `3833:32194` as
  current on 2026-09-10. The superseded frame is not normative for anything.
- Component-sheet probes (node `3632:4502`, D9): Header set `3313:7615`, Field set
  `3517:29304`, Search-results set `3668:7440`, Metadta set `3518:29457`, Detail set
  `3499:27340`, Slide set `3312:1429`, Button set `3499:27547` — probed 2026-09-10

### Source drift, `3524:29600` → `3833:32194` (closed list)

| # | Was | Now |
|---|---|---|
| 1 | Header title "Program overview", right group = export + settings glyphs | Title **"Study program"**, `showIcons=false` — **no right group at all** |
| 2 | Cover carried a **C-053 StatusBadge** ("Published") | Cover is a bare image — **no badge** |
| 3 | Info block: program name (Bold 14/20) + description (`color-white-70`) under the cover | **Gone** — the name and description moved into the settings rows |
| 4 | Details grid: Enrollments · Author · Created · Published | Details grid: **Created · Author · Group leader · Lessons** |
| 5 | — | **New section:** 7 × **C-042 EditableFieldRow**, headerless, between the details grid and the enrollments section |
| 6 | "Group Activity" section: C-031 EnrollmentStatusRow + "Recent activity" label + 3 × C-054 GroupEnrollmentCard | **"Active enrollments"** section: C-020 header (meta-button) + 3 × **C-037 ListResultRow** (`Group+tags`) — no percentages, no progress bars |
| 7 | Lessons: day rail + **one** lesson block (C-020 `subsection` header) + 3 × C-056 ActivityThumbnail 140×249 | Lessons: day rail + **three** **C-063 LessonCard**, each with its own title row and a **C-061 ActivitySlide** rail (112×244) |
| 8 | "Demographics" section: C-055 CategoryBarTable, 5 age bins | **Gone** |

Rows that lose this screen as a consumer: **C-031**, **C-053**, **C-054**, **C-055**,
**C-056**, **C-057**, **C-073**, and **C-038** (which reached this screen only inside C-054).
C-054, C-055 and C-056 were *introduced* by this spec and now have **no consumer at all** —
their contracts stand (the registry is append-only and a contract is the anchor), and the
registry records them as orphaned pending OQ-14.

**Deviations (closed list):**
1. All values, names, dates, images and counts in the frame are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The day rail and each lesson's slide rail render as horizontal scrollers; the frame clips their overflow (14 day chips at 474pt in a 408pt column; lesson cards drawn 424pt wide in a 408pt column, with up to 5 slides at 576pt).
4. Lesson Card 2 contains a **hidden** Slide instance (`3833:32603`, `hidden="true"`) — Figma authoring residue, not a designed state. Two slides render on that card.
5. The settings rows and the details grid disagree on lesson count ("Lessons 2" in the field row, "Lessons 31" in the details grid, "31 days" in the Lessons header). Sample-content inconsistency; one live value feeds all three (§5).

Anything else that differs from the source is a defect.

## 2. Layout contract

Pushed page (C-040 back chevron), full-height vertical scroll on `color-layout-background`.
System status bar → **C-040 PageHeader** 56pt, style `Two icons` with `showTitle=true` and
**`showIcons=false`**: back chevron left, centered static title "Study program"
(`type-page-title`, white), no right group → scrolling content column, `space-page-margin`
(16) padding, `space-section-gap` (32) between blocks, sections separated by 1px
`color-layout-border` hairlines (32 above and below, i.e. one gap step each side).

1. **Program detail** (408 wide, children gap `space-section-gap` 32)
   1. **Cover** — 408×180, `radius-card` (8), program cover image fill (object-cover).
   2. **Details grid** — 408×88, 2×2 of **C-041 DetailPair**, 16pt column/row gaps, each
      cell 196×36: Created (`Mon D, YYYY`) · Author (creator name) · Group leader (program
      leader name) · Lessons (count).
2. *hairline*
3. **Settings** — 408×518, **no section header**: seven **C-042 EditableFieldRow** stacked
   contiguously, each 408×74 (`py` 16, inner label→value gap `space-element-gap` 8, trailing
   18pt chevron), **no dividers between rows**. Closed row list, in order: Study name ·
   Description · Visibility · Age · Maximum members · Member directory access · Lessons.
   Every row is `state=Default`; Description and Member directory access instantiate the
   set's wrapping-value symbol (`3767:11991`), the rest the single-line symbol
   (`3517:29298`), and Age the age symbol (`3526:30897`).
4. *hairline*
5. **Active enrollments** — 408×344: **C-020 SectionHeader** `size=section` (408×24, gap 8;
   title "Active enrollments" `type-section-title`; accessory `meta-button`, gap 16 =
   **C-022 MetaPair** "3"+"groups" (12/24) + **C-021 GlyphButton** `add` 24pt) → 32 → list
   408×288: three **C-037 ListResultRow** type `Group+tags`, 408×96 each, stacked
   contiguously.
6. *hairline*
7. **Lessons** — 408×1032: **C-020 SectionHeader** `size=section` (title "Lessons";
   accessory `meta-button` = **C-022** "31"+"days" + **C-021** `add`) → 32 → **day rail**
   408×40: horizontally scrolling row of **C-052 DayChip** 32×40, gap `space-chip-gap` (2),
   exactly one `Active`; N = program day count → 32 → **lesson list** 408×904: three
   **C-063 LessonCard**, gap `space-section-gap` (32), each 424×280.
8. Bottom content padding 16.

**C-063 geometry as instantiated here** — title row 20pt, `pr` 16, gap **10** (a flagged
per-screen literal: the spacing family has no 10 row; this is the program's **second**
occurrence after C-033's root stack, see tokens.md hygiene note) → `space-card-padding` (16)
→ slide rail 244pt, gap `space-meta-gap` (4), **C-061 ActivitySlide** 112×244. Slide counts
in the frame: 4 · 2 · 5.

**Tokens:** every Figma variable on this frame is already bound —
`Label Color/Dark/Primary`, `Color/Base/White`, `White/100%`, `White/50%`, `White/20%`,
`Purple/100%`, `text/secondary`, `layout/border`, `Transparent`, `Callout / Bold`. This run
adds **no token rows**. The `10`pt title-row gap is the one flagged literal.

## 3. Behavior contract

**States (closed):**
- **Loading** — cover, details grid, field values, enrollment rows and lesson cards render as skeletons at their contracted geometry; section headers and field labels are static and render immediately.
- **Populated** — as §2.
- **Empty (no enrollments)** — proposed default: the Active-enrollments list is omitted and its header's MetaPair reads "0 groups"; the section and its hairlines stay (OQ-7).
- **Empty (no lessons)** — proposed default: day rail and lesson list omitted, header MetaPair reads the program's day count (OQ-7).
- **Error** — proposed default: page-level retry in place of the content column, header intact (OQ-7).

Undesigned in the source and therefore not buildable beyond the proposed defaults above:
loading, both empties, error, pressed states on every row, and DayChip states beyond
Default/Active (OQ-7).

**Interactions:**
- Back chevron → pop to caller.
- Any **C-042** row tap → the `shared-edit-field` pattern instantiated for that one field (that spec owns the editor, its Save gating and its return).
- Active-enrollments **C-021 `add`** → add-enrollment destination (OQ-10).
- **C-037** row tap → `enrollment-home` (push) for that enrollment.
- Lessons **C-021 `add`** → add-lesson behavior (OQ-1).
- **C-052 DayChip** tap → selects that day; the lesson list scrolls to that day's card (proposed — the frame shows a selected chip but no scroll linkage, OQ-11).
- **C-061 ActivitySlide** tap → `activities-editor` (push; that spec owns the contract).
- Day rail and slide rails scroll horizontally; the page scrolls vertically.

**Motion:** none bespoke — system scroll and push/pop only.

## 4. Components

Closed list of registry rows this screen renders:
- **C-020 SectionHeader** — Active enrollments / Lessons headers (`size=section`)
- **C-021 GlyphButton** — `add` ×2 (both section headers)
- **C-022 MetaPair** — "3 groups", "31 days"
- **C-037 ListResultRow** — enrollment rows (`type=Group+tags`)
- **C-040 PageHeader** — `Two icons` + `showTitle` + **`showIcons=false`**
- **C-041 DetailPair** — 2×2 details grid
- **C-042 EditableFieldRow** — the seven settings rows (`state=Default`)
- **C-043 MetaChip** — leader-name (`Single`) and member-count (`Key value`) chips inside C-037, both `align=Left`
- **C-052 DayChip** — day rail chip *(introduced here)*
- **C-061 ActivitySlide** — slide rail inside C-063 (`state=Fill`, `active=false`)
- **C-063 LessonCard** — the three lesson blocks

### C-052 DayChip (new — introduced by this screen)
32×40, `radius-card-sm` (4), centered day number SF Pro Regular 14 white. Main
components `3495:2777` (Default) / `3495:2787` (Active) — frame-local, not on the sheet.
Instanced on this frame at `3833:33431`–`3833:33444`. Props: `day: Int`, `state`, `onTap`.
**State coverage:** Figma defines `Default` (`color-white-20` fill) and `Active`
(`color-accent` fill) only. The contract needs no more for v1; completed/locked/pressed
are undesigned and may not be built without frames (OQ-7).

### C-053 StatusBadge (defined here, no longer consumed here)
The contract below stands unchanged from the 2026-09-01 run and remains this row's anchor —
but the current frame has **no badge**, so the row has no consumer (OQ-14).

Nodes `3524:29722/29723` (frame-local, no sheet set). Pill px 8 / py 4, `radius-card-sm`,
label SF Pro Text Bold 12, line-height 1.4, tracking −0.24, `color-black` at 70% opacity.
Props: `state: published | draft`.
**State coverage:** Figma designs `published` only ("Published" on `color-positive`).
`draft` is a **proposed default** ("Draft" on `color-white-20`, white text) pending
ratification or a frame (OQ-4).

### C-054 GroupEnrollmentCard / C-055 CategoryBarTable / C-056 ActivityThumbnail (defined here, no longer consumed here)
All three were introduced by the 2026-09-01 run against the superseded frame and are absent
from the current one. Their contracts are preserved verbatim in
[`study-program-home-superseded-contracts.md`](study-program-home-superseded-contracts.md)
so nothing specced is lost, and the registry marks each `orphaned 2026-09-10` (OQ-14 decides
whether they are struck through, re-homed on a future frame, or consolidated —
C-056 already carries a consolidation flag with C-061, OQ-enrollment-home-2).

### C-057 PercentBar (formalized here, no longer consumed here)
Still consumed by C-031, C-044, C-054, C-059 and C-033 — this screen simply no longer renders
one. No contract change; the formalization stands.

### Amendments to existing rows (closed change lists)

- **C-040 PageHeader** — this screen now consumes `Two icons` + `showTitle` +
  **`showIcons=false`**, title "Study program". It was the program's **only** icons-on
  consumer; with that gone, **every specced C-040 consumer is now `showIcons=false`** and
  the icons-on case is designed-unconsumed. This strengthens rather than answers OQ-C-040-1
  (why plain back+title consumers use `Two icons` at all). No prop change.
- **C-042 EditableFieldRow** — gains its **second host** (7 rows here, after members-profile's
  8). Consumed states here are all `Default`; the row's other five designed states are
  untouched. The set's three value symbols (`3517:29298` single-line, `3767:11991` wrapping,
  `3526:30897` age) are all exercised on one screen for the first time. No prop change.
- **C-037 ListResultRow** — `type=Group+tags` gains a consumer. Rendered here with a
  **64pt circular** group image (`rounded-[64px]`, object-cover) — same geometry
  members-profile contracts. No prop change.
- **C-043 MetaChip** — both `Single` (bare label, "L. Keith") and `Key value` ("3" +
  "members") are consumed here at `align=Left`. This screen's previous claim to be the first
  `align=Right` consumer dies with C-054; `align=Right` is now designed-unconsumed
  program-wide. No prop change.
- **C-061 ActivitySlide** — gains its **second host** (C-063 rails here, after
  enrollment-home's). Consumed variant is unchanged: `Fill` / `active=false`, 112×244,
  inner `radius-card` (8), placeholder bg `#2e2e2e` literal. No prop change.
- **C-063 LessonCard** — **closed change list, one item:** the title row's trailing meta is a
  **duration** here ("3 mins", `color-text-secondary` Regular 14/20) where enrollment-home
  contracts a relative date ("Today"/"Mon D"). The prop generalizes from `dateLabel` to
  **`metaLabel: String`** — the *host* decides what the label says, the card just renders it
  right-aligned in that slot. Both hosts consume the `plain` variant; `withProgress` stays
  enrollment-home's and is designed-unconsumed here. Nothing else changes.
- **C-020 SectionHeader** — the `subsection` size loses its only consumer (the old lesson
  block header) and becomes designed-unconsumed; the `size` axis stays as measured. Both
  headers here are `size=section` with a `meta-button` accessory. No prop change.

## 5. Data & API

The screen is read-mostly: the seven C-042 rows are *entry points* to `shared-edit-field`,
which owns the writes. Verified against `server/prisma/schema.prisma` +
`server/src/routes/` 2026-09-10:

| Need | Endpoint | Status |
|---|---|---|
| Cover, created date, lesson count | `GET /api/programs/{id}` (verified: `coverImageUrl`, `createdAt`, `_count.lessons`) | ✅ exists |
| Author name (details grid) | same endpoint — the select omits the creator's name (`StudyProgram.creator` relation exists) | **API-GAP (additive):** add `creator.name` to the detail select |
| **Group leader** (details grid) | — | **API-GAP (new field):** `StudyProgram` has no leader relation. Per the owner's 2026-09-10 ruling this is a **program-level leader**, not the enrolled group's — add a `leaderId` relation + expose `leader.name` |
| Study name, Description (settings rows) | `GET /api/programs/{id}` (verified: `name`, `description`) | ✅ exists |
| **Visibility, Age, Maximum members, Member directory access** (settings rows) | — | **API-GAP (new fields):** all four exist on `Group` (`isPrivate`, `ageRangeMin`/`ageRangeMax`, `maxMembers`, `memberDirectoryEnabled`) and **none on `StudyProgram`**. Owner ruling 2026-09-10: they become **additive StudyProgram columns**, mirroring the Group semantics. Migration + read/write are the build suite's `03` |
| Single-field writes from `shared-edit-field` | `PATCH /api/programs/{id}` (verified: accepts `name`, `description`, cover, tags) | **API-GAP (additive):** the zod body must accept the four new settings fields + `leaderId`; the pattern writes one field per visit |
| Active enrollments (group cover, name, leader name, member count) | `GET /api/programs/{programId}/enrollments` (verified at `server/src/routes/enrollments.ts:1418` — returns `group.{name,coverImageUrl,creator.name,_count.members}`) | ✅ exists — and this **closes** the superseded spec's "bundle per-enrollment completion" gap for this screen: the new frame renders no percentages |
| Enrollment count for the header MetaPair ("3 groups") | same endpoint (array length) or `GET /api/programs/{id}`'s `_count.enrollments` (verified) | ✅ exists |
| Day rail (N = program day count) | `GET /api/programs/{id}` (verified: `days`) | ✅ exists |
| Lesson cards (dayNumber, title, duration, activity list) | `GET /api/programs/{id}` paginated `lessons` (verified: `dayNumber`, `title`, `estimatedMinutes`, activities with `video.thumbnailUrl` / `youtubeThumbnailUrl`) | ✅ exists; a long program spans lesson pages (`lessonLimit` max 60) — the rail hydrates from `days`, lesson bodies page in |
| Slide artwork for non-video activities | — | **API-GAP / OQ-8:** unchanged — no stored preview for read/exegesis/input activities |

Dropped needs (the superseded frame's, no longer required by this screen): program-scoped
"members current" metric, per-enrollment completion in the list payload, the age-bin
demographics aggregate, and `publishedAt`. They are **not** withdrawn as product needs — they
move to gap analysis with the sections that carried them (§7).

Contract shapes belong to the build suite's `03-data-and-api.md`.

## 6. Connections

- **Entry:** `programs-home` → study-program-home (push, program row tap — trigger confirmed
  when `programs-home` is specced; this frame's back chevron proves the pushed presentation).
- **Exits:**
  - back → caller
  - each of the 7 **C-042** rows → `shared-edit-field` instantiated for that field (7 edges)
  - **C-037** row tap → `enrollment-home` (push) — a real edge, replacing the superseded
    frame's deferred "GroupEnrollmentCard tap"
  - Active-enrollments `add` → add-enrollment destination (OQ-10)
  - Lessons `add` → add-lesson behavior (OQ-1)
  - **C-061** slide tap → `activities-editor` (push)
- **Removed exits** (they left with the header icons and the Group Activity section): header
  export → export flow · header settings → program settings surface · Group Activity
  arrowRight → program-enrollments. Settings are no longer a destination at all — they are
  **inline on this page** as the C-042 rows, which is the substantive product change in this
  revision.
- **Overlays:** none on this frame.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

Replaces **`iphone/MakeReady/Pages/Manage/Program/ProgramHomePage.swift`** —
`Route.swift` case `.programHome` (`iphone/MakeReady/Services/Route.swift:51`), the
legacy `.programHome` modal. (`Pages/Main/StudyProgramHome.swift` is `MainPrograms` — the
programs *list*, which `programs-home` replaces.)

| Legacy capability (ProgramHomePage) | 2.0 disposition |
|---|---|
| Lessons tab (lesson list, add lesson, EditDay entry, reorder/swipe-delete) | **merged** — day rail + three lesson cards; add via Lessons header (OQ-1); reorder/delete not on this frame → gap-analysis candidates |
| Enrollments tab (enrollment rows, enroll flow entry) | **merged** — Active enrollments section; row tap now reaches `enrollment-home`; the enroll flow itself is OQ-10 |
| Analytics tab (`docs/features/analytics/` Program tab) | **dropped from this screen** — the superseded frame's members-current row and demographics table are both gone. The whole Program-tab analytics surface is now a gap-analysis candidate with no 2.0 home (OQ-14) |
| Edit program settings (`.editProgram` inline form) | **carried, upgraded** — the seven C-042 rows edit settings in place via `shared-edit-field`, replacing the legacy modal form |
| Publish badge + publish-updates flow | **dropped from this screen** — no C-053 badge on the current frame; publish state has no 2.0 surface yet (OQ-4/OQ-14) |
| Export flow (preview → confirm → save) | **dropped from this screen** — the header export glyph is gone; export has no 2.0 surface yet (OQ-14) |
| Preview system (activity/lesson previews) | **dropped by decision** — activities model kills previews (README: activities notes; D4) |

## 8. Open questions

Numbering is stable across the re-spec: OQ-1…9 keep the identities other docs cite, with a
dated status line where the new frame changed the answer. OQ-10…14 are new.

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-study-program-home-1 | Lessons header `add`: add a day/lesson at the end (proposed default, matches legacy addLesson) or open an add menu? | No — default proposed | owner |
| OQ-study-program-home-2 | **Resolved by the new frame (2026-09-10):** the icon-swapped lesson-row export/share slot is gone with the old single-lesson block; the current lesson card has no accessory button. No ruling needed. | No — closed | — |
| OQ-study-program-home-3 | **Narrowed (2026-09-10):** of the four deferred destinations, GroupEnrollmentCard-tap is answered (C-037 → `enrollment-home`) and header settings/export no longer exist on this screen. What remains is where settings and export live in 2.0 at all — see OQ-14. | No | owner (frames) |
| OQ-study-program-home-4 | C-053 `draft` state is undesigned (proposed: "Draft" on `color-white-20`). **2026-09-10:** the badge has no consumer at all now, so this is no longer this screen's question — it rides with OQ-14. | No — default proposed | owner |
| OQ-study-program-home-5 | C-054 completion-color banding + `status=Default`. **2026-09-10:** C-054 is orphaned; the banding question survives on its own across C-031/C-057/C-062 (OQ-home-dashboard-3, OQ-enrollment-home-3) and is no longer scoped here. | No | owner |
| OQ-study-program-home-6 | "Recent activity" ordering + demographics bar palette. **2026-09-10:** both sections are gone; the palette question survives in tokens.md's hygiene note only if a future frame reinstates a categorical chart. | No | owner |
| OQ-study-program-home-7 | Undesigned states: DayChip beyond Default/Active; loading, both empty states and error for this page. Proposed defaults in §3; may not be built beyond them without frames. | No — defaults proposed | owner |
| OQ-study-program-home-8 | Slide artwork for non-video activities (video/YouTube thumbs verified in the API; proposed: themed render/placeholder derived from the activity theme). Now scoped to C-061 rather than C-056. | No — default proposed | owner + backend suite |
| OQ-study-program-home-9 | Figma drift hygiene: C-020 title measured 18/24 Semibold vs home spec's "~16 Bold" approximation. **2026-09-10:** the C-022 half is resolved — this frame renders MetaPair Regular 12/24 white + `text/secondary`, matching home-dashboard, so the old frame's Bold/White-50 rendering was the outlier and dies with it. | No | owner (Figma cleanup) |
| OQ-study-program-home-10 | Active-enrollments `add` glyph: does it enroll another group in this program (proposed default) or open a menu? No destination frame exists. | No — default proposed | owner |
| OQ-study-program-home-11 | Day rail ↔ lesson list linkage: the frame shows one `Active` chip and three lesson cards but no evidence of what selection does. Proposed: the chip scrolls the list to that day's card and the list stays complete (rather than filtering to one day, which is what the superseded frame did). | No — default proposed | owner |
| OQ-study-program-home-12 | The four new StudyProgram settings fields mirror Group semantics — but does **Visibility** gate discovery, enrollment, or both, and do **Age** / **Maximum members** enforce at enrollment time or only advise? The frame shows values, not rules. | **Yes** — the build suite cannot write the migration or the enforcement without this | owner |
| OQ-study-program-home-13 | "Group leader" as a program-level field: is it a single assignable user (proposed default, one `leaderId`), or the creator by another name, or a per-enrollment value the details grid is flattening? Sample content shows one name on a three-group program. | **Yes** — decides whether a column is added at all | owner |
| OQ-study-program-home-14 | **Orphan disposition.** C-053, C-054, C-055 and C-056 lost their only consumer, and with them the publish badge, the program analytics surface and the export flow lost their only 2.0 home. Are those product capabilities dropped, or do they belong on screens not yet designed? Until this is answered, gap analysis cannot classify them. | No — but it is the largest open item this re-spec creates | owner |
