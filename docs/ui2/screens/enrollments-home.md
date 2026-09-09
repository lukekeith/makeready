# enrollments-home — Enrollments (org-wide enrollment directory tab)

Platform: iphone · Status: specced · Specced: 2026-09-02

> Screen id note: invoked as "Enrollments"; normalized to `enrollments-home` per D8
> (`<area>-<name>`). A NEW tab root — no legacy org-wide enrollments surface exists.

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3823-34548
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3823:34548` ("Enrollments", 440×1892)
- Frozen snapshot: `assets/enrollments-home.png` — captured 2026-09-02
- Component-sheet notes: search = C-034 set `3561:33795` (citation corrected 2026-09-05 —
  `3561:33757` is a different, glyph-less component; see the C-034 contract); chips = C-035 `3668:7570`
  internals; bar = C-057 set `3526:30471` (Thin/Left symbols `3621:47xx`); the
  enrollment row's main component is frame-local (`3823:35035` area), no variant axes.

**Deviations (closed list):**
1. All names, dates, images, and fill widths are sample content — live data replaces them.
2. The status bar is the iOS system status bar.
3. The nav row's tab set and behavior follow the `shell-topnav`/`shell-tabs` specs when
   written; this frame's collapsed row is evidence, not the nav contract (and it evidences
   MORE tabs than prior frames — OQ-4).
4. The frame's content fills only the top ~790pt; the empty remainder is canvas, not a
   designed footer region.
5. Progress-fill colors are per-screen literals pending the banding ruling (OQ-3):
   `#4deb4b` (recurring), `#ff4759` (= `color-negative`), and new `#e3eb4b` (yellow band).

Anything else that differs from the source is a defect.

## 2. Layout contract

Tab root: full-height vertical scroll on `color-layout-background`. System status bar →
**C-019 TopNav** collapsed row (32pt, Enrollments active) → header block (`space-page-margin`
16 padding, 16 gap):

1. **C-034 SearchField** — 408×44, `Default` state, placeholder "Search enrollments".
2. **Filter rail** — 4 × **C-035 FilterChip**, gap `space-element-gap` (8): "All Orgs" ·
   "All groups" · "All Leaders" · "Active" (label = current selection per C-035 contract).

Then the sections container (16 padding, `space-section-gap` 32 between blocks), 1px
`color-layout-border` hairlines between group sections. Per **group section** (gap 16):

- **C-058 GroupSectionHeader** — 42pt: 40pt C-038 Avatar (group photo, clips an 88×64
  portrait source) + info column (8 gap: group name `type-title-card` white, single-line
  ellipsis; leader name SF Pro Regular 14/14 `color-white-50`) + right **C-021
  GlyphButton** `arrowRight`.
- **Enrollment list** — one **C-059 EnrollmentProgressRow** (408×96) per enrollment of
  that group, no separators between rows.

## 3. Behavior contract

**States (closed list):**
- `loading` — skeleton sections under the persistent header block (search + chips render
  immediately).
- `populated` — as §2.
- `filtered-empty` — header block persists; body shows no sections (empty-state visual
  undesigned — proposed default: centered `color-text-secondary` "No enrollments match"
  line, OQ-6).
- `empty` (zero enrollments org-wide) — same proposed default, copy without "match" (OQ-6).
- `error` — inline retry in the body; header persists.

**Interactions (closed list):**
- Search: live text filter over program title + group name (C-034 focus/value states per
  its contract; debounce/min-chars are build-suite decisions consistent with the program's
  search precedent).
- Each FilterChip tap → single-select option menu via **C-036 FilterMenuOverlay** (the
  program's option-menu chrome, per members-home) with `motion-menu-fade-in/out`; option
  lists are closed but undesigned (OQ-2): org scope, group, leader, status. Chip label
  updates to the selection.
- GroupSectionHeader arrowRight → group destination deferred (OQ-5).
- EnrollmentProgressRow tap → enrollment detail destination deferred (OQ-5).
- Section/row ordering: "Recent activity" implies recency — proposed default: sections by
  most-recent enrollment activity desc, rows by activity recency desc (OQ-1).
- Vertical scroll; nav morph behavior owned by `shell-topnav`.

**Motion:** menu fades per motion tokens; no other bespoke motion designed.

## 4. Components

Closed list rendered: **C-019 TopNav** (collapsed) · **C-021 GlyphButton** (arrowRight) ·
**C-034 SearchField** · **C-035 FilterChip** (×4) · **C-036 FilterMenuOverlay** (presented
by chips) · **C-038 Avatar** (40, in C-058) · **C-057 PercentBar** (Thin/Left, in C-059) ·
**C-058 GroupSectionHeader** *(introduced here)* · **C-059 EnrollmentProgressRow**
*(introduced here)*.

### C-058 GroupSectionHeader (new)
Frame-local (nodes `3823:34882…`), no sheet set, no variant axes. 42pt row, 16 gap:
C-038 Avatar 40 (group photo) + info column (8 gap): group name (`type-title-card`,
single-line ellipsis) over leader name (SF Pro Regular 14/14 `color-white-50`) + trailing
C-021 `arrowRight`. Props: `groupName`, `leaderName`, `photoURL`, `onOpen`.
**State coverage:** single designed state; initials fallback follows C-038's contract;
pressed state undesigned (OQ-6). Distinct from C-032 FollowedProgramHeader (program title
+ created meta + ellipsis) — this one identifies a group + leader with a forward affordance.

### C-059 EnrollmentProgressRow (new)
Frame-local main (`3823:35035` area, single variant). 96pt row (16pt vertical padding),
16 gap: details column (16 gap: program title SF Pro Bold 14/14 white single-line
ellipsis → **C-057 PercentBar** `Thin/Left` at 328pt width, fill in the status color →
"enrolled «Mon D, YYYY»" SF Pro Regular 14/14 `color-text-secondary`) + trailing 64×64
`radius-card` (8) cover thumbnail (clips an 88×64 portrait source). Props: `programTitle`,
`progress`, `statusColor`, `enrolledLabel`, `coverURL`, `onTap`.
**State coverage:** single designed variant; three fill colors observed as content
(#4deb4b green, #e3eb4b yellow, #ff4759 red — banding thresholds undesigned, OQ-3);
no completed/paused/pressed variants designed (OQ-6). Cross-note: closely parallels C-044
StudyProgramCard `state=Progress` (title + Thin/Left bar + image) but with an
enrolled-date meta line instead of MetaChips and a 64×64 thumb instead of full-width —
distinct Figma components; consolidation is the owner's call (flagged, non-blocking).

## 5. Data & API

Read-only screen. Verified against the makeready-api MCP + `server/prisma/schema.prisma`
2026-09-02:

| Need | Endpoint | Status |
|---|---|---|
| Org-wide enrollments grouped by group (group name/photo/leader, per-enrollment program title/cover, completion %, enrolled date, activity recency) | Pieces exist: `GET /api/groups/{groupId}/enrollments`, `GET /api/programs/{programId}/enrollments`, `GET /api/enrollments/{id}/completion-stats` (all previously verified) | **API-GAP: one assembled org-wide enrollments feed** with grouping, completion, and recency — per-group fan-out is N+1 (mirrors home-dashboard's followed-enrollments gap; the build suite should consider serving both from one endpoint family) |
| Search (program title + group name) | `GET /api/search` (verified: unified search) exists as a piece | fold into the assembled feed as a query param — same API-GAP |
| Filters: group, leader | feed params; `Enrollment.createdById` + group leader exist in schema | same API-GAP (param surface) |
| Filter: status "Active" | — | **API-GAP + OQ-2:** `Enrollment` has no status column — "Active" needs a definition (derived from schedules/completion or a new column); backend suite + owner |
| Filter: "All Orgs" | — | **API-GAP + OQ-2:** current server scopes a leader to ONE org (`getUserOrgId`); a multi-org filter implies multi-org leader support or an org-switch semantic — owner must rule before the suite designs it |

Writes: none.

## 6. Connections

- **Entry:** `shell-tabs` → enrollments-home (Enrollments tab — active in this frame's
  nav row).
- **Exits:** GroupSectionHeader arrowRight → group destination deferred (OQ-5; likely
  `groups-detail` or a group-enrollments surface) · EnrollmentProgressRow tap →
  enrollment detail deferred (OQ-5, undesigned).
- **Overlays:** C-036 FilterMenuOverlay ×4 (one per chip).
- Nav-evidence note: this frame's tab row shows Home · Library · Groups · Members ·
  **Enrollments** · Invites · Programs · Media — the widest tab set evidenced so far;
  recorded for `shell-topnav` (OQ-4), not as edges here.

All edges mirrored into `screen-map.md`.

## 7. Legacy mapping

No 1:1 legacy counterpart — the org-wide enrollments directory is new. Nearest legacy
capabilities:

| Legacy element | Disposition |
|---|---|
| `Pages/Main/StudyProgramHome.swift` → `MainPrograms` "Enrolled" tab (`enrolledTabContent`, `CardEnrolled` rows) | **absorbed** — its enrollment list becomes this tab (grouped by group, org-wide) |
| `Pages/Manage/Group/GroupHomePage.swift` trailing enrollments pane (per-group enrollment list) | **partially absorbed** — per-group slice lives here under each section; the group-scoped management flows stay with the group screen (`groups-detail`) |
| Enrollment creation/edit flows (`EnrollmentFlow`, schedule editors) | **not this screen** — no create affordance is designed on this frame; entry points for those flows are unplaced in 2.0 (gap-analysis candidate) |
| `Route.swift` — no legacy route case exists for an org-wide enrollments surface | n/a (new tab) |

## 8. Open questions

| OQ | Question | Blocks? | Decides |
|---|---|---|---|
| OQ-enrollments-home-1 | Grouping/ordering rule: proposed sections by most-recent enrollment activity desc, rows by recency desc ("Recent activity" naming is the only evidence) | No — default proposed | owner |
| OQ-enrollments-home-2 | The four filter chips' closed option lists are undesigned; "Active" has no schema backing (definition needed) and "All Orgs" implies multi-org leaders (not supported server-side today) | No for the spec; gates the filter params in the build suite | owner + backend suite |
| OQ-enrollments-home-3 | Progress banding now has THREE observed colors (green `#4deb4b`, yellow `#e3eb4b`, red `#ff4759`) with undesigned thresholds — joins OQ-home-dashboard-3 / OQ-study-program-home-5; one program-wide ruling wanted | No | owner |
| OQ-enrollments-home-4 | ~~Nav tab set: Invites/Programs/Media prototype-only or real?~~ **RESOLVED 2026-09-05 via the owner-designated C-019 TopNav sets:** all three are real and the set is closed at 8 (Home · Library · Groups · Members · Enrollments · Invites · Programs · Media). This frame's wider row was the first evidence and is correct. Contract: `design-system/components/C-019-top-nav.md` §2/§3. Residual: Library-vs-Programs/Media sibling overlap (OQ-C-019-8) | Closed | — |
| OQ-enrollments-home-5 | Deferred destinations: section-header arrow target and enrollment-row tap target. **Row-tap half RESOLVED 2026-09-02:** tap → `enrollment-home` (specced). Arrow target still open | No — remaining half deferred | owner (frames) |
| OQ-enrollments-home-6 | Undesigned states: empty/filtered-empty visuals, pressed states, row variants beyond the single designed one — proposed defaults in §3 stand until ruled | No | owner |
