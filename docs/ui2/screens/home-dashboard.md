# home-dashboard — Home (leader dashboard)

Platform: iphone · Status: specced · Specced: 2026-09-01

## 1. Normative source

- Figma: https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=3622-5487
  — file `nVva9a2WvYmcWQo6zlHupO`, node `3622:5487` ("Home", 440×2730)
- Frozen snapshot: `assets/home-dashboard.png` — captured 2026-09-01
- Supplementary doc source for the top nav: `docs/features/navigation/01-account-switcher-analysis.md`
  (the nav is the Robinhood-morph control; this screen renders only its **collapsed** state — the
  full morph contract is owned by the `shell-topnav` spec)

**Deviations (closed list):**
1. All values, series, dates, names, and photos in the frame are sample content — live data replaces them.
2. The status bar is the iOS system status bar, not the frame's mock.
3. The nav row's tab set and behavior follow the `shell-topnav`/`shell-tabs` specs when written; this frame's collapsed row is evidence, not the nav contract.

Anything else that differs from the source is a defect.

## 2. Layout contract

Page: full-bleed vertical scroll on `color-layout-background` (#030405). Content is
edge-to-edge; text and cards inset by `space-page-margin` (16). Status bar (system) →
collapsed nav row (32pt, C-019) pinned at top → scrolling content.

Five sections separated by 1px `color-layout-border` hairlines with `space-section-gap`
(32) above and below the divider:

1. **Overview** (`node 3636:5050`) — section header (24pt row: title left at x16; right:
   MetaPair "5 metrics" + GlyphButton plus) → 8pt → horizontally scrolling KPI rail:
   KpiCard 140×192, gap 8, leading inset 16, rail overflows the viewport.
2. **Activity** (`3673:12002`) — header (title + text-link "Jump to today", `text/secondary`)
   → day rail: DayActivityCard 131×192, cards butt together with shared 1px vertical borders
   (−1 overlap), leading inset 16, horizontal scroll → 32pt → DualSeriesBarChart 440×149
   full-bleed → Legend row (LegendItem ×2: "Completed lessons" purple dot, "Scheduled
   lessons" gray dot), inset 16, gap 16.
3. **Sessions** (`3622:5501`) — header (title + InlineDropdown "All time ˅") → RadialDayClock
   centered, 280pt ring in a 357×326 chart area with 8 hour labels (12 AM top, clockwise
   3 AM, 6 AM, 9 AM, 12 PM bottom, 3 PM, 6 PM, 9 PM) → 16pt → TimeActivityChart 438×140
   (100pt chart + 24pt tick row; the designed 0/15/30/45 "mins" ticks are sample labels —
   axis = time within a fixed period per the 2026-09-03 C-030 ruling, real labeling
   OQ-C-030-2).
4. **Engagement** (`3622:5609`) — header (title + MetaPair "15 active" + GlyphButton
   arrow-right) → EnrollmentStatusRow 408×64, inset 16.
5. **Following** (`3622:5619`) — header (title + MetaPair "3 enrollments" + GlyphButton
   plus) → per followed program: FollowedProgramHeader (40pt: program title 14pt + meta line
   "Author · Created <date>") → 32pt → horizontally scrolling GroupFollowCard rail 179×228,
   gap 8, leading inset 16 → 32pt → next program block.

Component geometry lives in each component's §4 contract. Radii observed: KPI card 4,
group card 8, percent circle 32, sparkline bars 2.

## 3. Behavior contract

**States (closed list) per section:** `loading` (skeleton placeholder in the section's
content footprint; header renders immediately), `populated`, `empty` (section renders with
zeroed/dimmed content — the sparse-data rule from `docs/features/analytics/README.md`
pre-implementation §1 applies: every chart must look intentional with a handful of events),
`error` (section-level inline retry; the page never blanks). The Following section's `empty`
state (0 followed enrollments) shows the header with "0 enrollments" + plus as the
only affordance.

**Interactions:**
- Overview plus → opens the **KPI metric picker** overlay (`home-kpi-picker`, future spec):
  a manage-metrics list where each registry metric toggles on/off — add and remove live in
  the same picker (owner decision 2026-09-01). "N metrics" = count of enabled metrics.
  Selection persists per leader via preferences (§5). KPI cards themselves are not
  interactive in v1.
- Day rail ⇄ column chart are **synced to one shared timeline** (owner decision 2026-09-01):
  panning either pans the other to the same date window; both use standard scroll physics.
  "Jump to today" recenters **both** to today. The TODAY marker (solid `Text highlight`
  line + label; "dashed" corrected 2026-09-03 per the C-026 set) stays fixed to today's column.
- Sessions dropdown: **time range** filter (owner decision 2026-09-01), closed option list:
  All time · Year · Month · Week. Applies to both the radial clock and the histogram.
- Engagement arrow-right → detail destination deferred (OQ-home-dashboard-1).
- Following plus → **add-enrollment-to-follow** picker (`home-follow-picker`, future spec).
- FollowedProgramHeader ellipsis → context menu; contents deferred (OQ-home-dashboard-4).
- GroupFollowCard tap → destination deferred (OQ-home-dashboard-4).

**Motion:** no bespoke motion on this screen beyond system scroll physics; nav morph
motion is owned by `shell-topnav`. Chart entrance animation is a build-suite decision only
if added as a program motion token later — none is specced here.

## 4. Components

Closed list of registry IDs rendered: **C-019 TopNav** (collapsed state) · **C-020
SectionHeader** · **C-021 GlyphButton** · **C-022 MetaPair** · **C-023 KpiCard** ·
**C-024 SparkBarChart** · **C-025 DayActivityCard** · **C-026 DualSeriesBarChart** ·
**C-027 LegendItem** · **C-028 InlineDropdown** · **C-029 RadialDayClock** · **C-030
TimeActivityChart** · **C-031 EnrollmentStatusRow** · **C-073 StatusPercentDisc**
(2026-09-10 — split out of C-031's anatomy by the full-set run; rendered here only inside
C-031) · **C-032 FollowedProgramHeader** · **C-033 GroupFollowCard**.

Contracts for the rows this screen introduces (all `(new)`; measured from node
`3622:5487`, get_design_context 2026-09-01):

### C-020 SectionHeader
24pt row, full width, title inset 16. Title: section name, SF Pro Bold ~16, white.
Right accessory variants (closed): `meta-button` (MetaPair + 16gap + GlyphButton),
`text-link` (label in `text/secondary`, tappable), `dropdown` (InlineDropdown), `none`.
Props: `title: String`, `accessory: Accessory`.

### C-021 GlyphButton
**Contract relocated 2026-09-07** → `../design-system/components/C-021-glyph-button.md`
(full-set `/ui2-component` run on the owner-designated set `3499:27547`, which enumerates
all **nine** designed glyphs and exports their vector artwork). This screen consumes
`add`, `arrow-forward` and `three-dots` — written `plus` / `arrowRight` / `ellipsis` in
this spec's earlier prose; that contract's §3 carries the alias table. The 24×24 visual,
`color-accent` tint and 44pt hit target are unchanged, and the hit target now has an
open question of its own (OQ-C-021-2).

### C-022 MetaPair
Inline value+label pair, SF Pro Regular 12: value white, label `text/secondary`, 4pt gap
(e.g. "5 metrics", "15 active", "0 mins"). Props: `value: String`, `label: String`.

### C-023 KpiCard
140×192; `card/background` fill, 1px `card/border`, radius 4, padding 16, internal gap 8.
Rows: title (SF Pro Bold 14 white, wraps to 2 lines) → SparkBarChart (fills remaining
height, `align=bottom` with the average annotation: right-aligned average value SF Pro
Semibold 12 `text/secondary` + dashed hairline at the average line — "max annotation"
corrected to average 2026-09-03 per the C-024 contract/owner ruling) → value (SF Pro
Bold 14 white, e.g. "158", "72.4hrs") → percent change: 14pt trend icon + SF Pro
Regular 12, `green` (#6cff73) with ↗ icon when positive, `Red/100` (#ff4759) with ↘
when negative. Props: `title`, `series: [Double]`, `averageLabel: String?` (renamed
from `maxAnnotation` 2026-09-03), `value: String`, `change: (direction, String)?`.

### C-024 SparkBarChart (renamed from MiniBarSparkline 2026-09-03)
Contract relocated 2026-09-03 → `../design-system/components/C-024-spark-bar-chart.md`
(owner-designated set `3672:9689`, with owner behavioral requirements: top/center/bottom
alignment, container-fill sizing, target-bar aggregation, average line + side-placeable
label). Correction carried there: the dashed annotation is the series AVERAGE, not a max
line.

### C-025 DayActivityCard
**Contract relocated 2026-09-10 → `../design-system/components/C-025-day-activity-card.md`**
(`/ui2-component C-025`, D10). The owner-designated set `3672:9223` designs **three** states
where this section described one, and the card's two sub-blocks are their own sets — now
C-070 DateBlock (2 states) and C-071 ValuePair (7 states).

What this screen consumes: C-025 `state=Transparent` (the no-fill, L/R-hairline form this
section had described as the whole component), C-070 `Default`, and C-071 `Default`
populated / `Nothing` zero. Two corrections landed in the relocation, both recorded in that
file's §1 closed deviation list: the filled, fully-bordered form is Figma's `Default` and is
consumed by no screen; and the zero state's lines are `color-white-20`, **not**
`text/secondary` as written here — `text/secondary` is the separate designed `Muted` state
that members-profile consumes.

### C-026 DualSeriesBarChart
Contract relocated 2026-09-03 → `../design-system/components/C-026-dual-series-bar-chart.md`
(owner-designated set `3633:4505`; this screen's instance `3673:12011` = `state=Today`).
The set corrects this section's earlier approximations: high gridline is `Text highlight`
(not `White/20%`), low gridline is `White/50%` (not `White/20%`), and the TODAY rule is a
**solid** 1px line (not dashed).

### C-027 LegendItem
Dot (8pt circle, series color) + 8gap + label (SF Pro Regular 12 `text/secondary`).
Props: `color`, `label`.

### C-028 InlineDropdown
Header-row control: current option label (SF Pro Regular 12, `text/secondary`) + 14pt
chevron-down. Tap presents an option menu (overlay chrome per program conventions when the
shell specs land). Props: `options: [String]` (closed per consumer), `selected`,
`onSelect`.

### C-029 RadialDayClock
Contract relocated 2026-09-03 → `../design-system/components/C-029-radial-day-clock.md`
(owner-designated frame `3634:4871`; this screen's chart node `3636:5161` is a sibling
copy). The contract corrects this section's approximations: all chart text is Inter (not
SF Pro), center value Regular 24, caption Bold 18 `text/secondary`, hour labels
`text/navigation`, base ring `White/10%`, and arcs render in three purple opacity bands
(100/50/20) encoding concentration.

### C-030 TimeActivityChart (renamed from GradientHistogram 2026-09-03)
Contract relocated 2026-09-03 → `../design-system/components/C-030-time-activity-chart.md`
(owner-designated main component `3636:6337`; this screen's chart node `3636:6548` is its
instance). The owner's axis ruling corrects this section's earlier reading: x = time
within one fixed, non-panning period (not session length); the "mins" ticks are sample
labels (OQ-C-030-2).

### C-031 EnrollmentStatusRow
**Contract relocated 2026-09-10** → `../design-system/components/C-031-enrollment-status-row.md`
(full-set `/ui2-component` run on the owner-designated set `3526:30288`). That run measures
what this section stated in prose — the row's internal 8pt gap and its two flexing cells — and
splits the 64pt percent circle out as its own registry row, **C-073 StatusPercentDisc**. This
screen consumes `state=Default` at 408 wide (instance `3622:5617`), with the row's purpose
unchanged (owner, 2026-09-01): progress-across-the-board as a percentage with counts — how many
members currently enrolled in any of the leader's content are current. The fill-colour anomaly
this section flagged is now decided evidence rather than a suspicion: the set spends BOTH greens
inside one symbol (OQ-home-dashboard-6, and OQ-C-031-2 in the contract).

### C-032 FollowedProgramHeader
40pt block inset 16: program title (SF Pro Bold 14ish white, single line) over meta line
(SF Pro Regular 12 `text/secondary`): author name · 4pt dot · "Created <Mon D, YYYY>";
right-aligned GlyphButton `ellipsis`. Props: `title`, `author`, `createdLabel`, `onMenu`.

### C-033 GroupFollowCard
**Contract relocated 2026-09-10** → `../design-system/components/C-033-group-follow-card.md`
(full-set `/ui2-component` run on the owner-designated set `3620:4662`, which this section's
node ref — `3622:5628` — is one **instance** of). The set designs **two axes this section did
not record**: `style` {Default, No bar} and `color` {Green, Yellow, Red}. What this screen
consumes is `style=No bar` at all three colours; `Default` (a C-057 PercentBar in place of
the members line, and no link glyph) is designed-unconsumed.

Three corrections that contract carries, all of which change what this section asserted:
- **`isLinked` → `showLink`.** The set exposes a boolean that shows or hides the glyph and
  pins it to C-072 `linked=true`. The broken-chain artwork **is** designed — on C-072's own
  set — but is not reachable from this card, so "unlinked (broken chain) = detached" is not
  what this component renders today (OQ-C-033-3).
- **The band is an independent prop, not a function of the percentage** — all four symbols
  render "55%" and differ only in colour. That closes the independence half of
  OQ-home-dashboard-3 below; the threshold half stays open.
- **The completion line's colour rule is per-style**: in `No bar` both the number and its
  label take the band colour; in `Default` only the number does and the label is
  `color-white-50`.

The 179×228 / r8 / p16 / gap-10 geometry, the 64pt avatar, and the wrapping Bold 14/20 title
are unchanged. The 16pt glyph is now **C-072 LinkStatusGlyph**; the bar is **C-057
PercentBar**. Props: see that contract's §4.

## 5. Data & API

Read models: analytics metrics (registry), engagement aggregates, followed enrollments
with group/completion/sync data, leader preferences. Writes: preference updates only (KPI
selection, followed-enrollment list if stored as a preference — OQ-4).

| Need | Endpoint | Status |
|---|---|---|
| KPI values + trend series + % change (completed lessons, time in lessons, video time, and any picker metric) | `POST /api/analytics/query` + `GET /api/analytics/meta` (verified via makeready-api) | ✅ exists; **new registry metric registrations** required for any metric not yet in the catalog — the layer's designed expansion path (`docs/features/analytics/architecture.md`), additive-only |
| KPI card selection ("5 metrics") | `GET/PUT /api/preferences/{key}` (verified) — key e.g. `dashboard.kpis` | ✅ exists |
| Day-card series (minutes + lessons per day, all leader's groups) | `POST /api/analytics/query` (per-day buckets, caller timezone per analytics policy) | ✅ layer exists; registry metric additions |
| Scheduled vs completed per day (column chart) | `POST /api/analytics/query` — scheduled side needs a `scheduled_date`-based metric (column exists per analytics README pre-impl §2) | ✅ layer exists; registry metric additions |
| Average session duration, session-length distribution (histogram), per-hour session activity (radial) | — | **API-GAP: the analytics layer has no session concept** — session-ization of `client_events` (grouping into sessions with durations) + session metrics must be added by the backend suite. Interim: the radial's hour distribution alone could draw from `GET /api/engagement/heatmap` (verified), but the center value and histogram cannot |
| Engagement row (% current, members current count, total enrolled, group count, "N active") | — | **API-GAP: no leader-wide engagement aggregate** — pending the "current" definition (OQ-1); new registry metrics or an assembled endpoint |
| Following list (followed enrollments grouped by program, each with group name/photo, member count, % complete, sync status) | Pieces exist: `GET /api/programs/{programId}/enrollments`, `GET /api/groups/{groupId}/enrollments`, `GET /api/enrollments/{id}/completion-stats`, `GET /api/enrollments/{id}/sync` (all verified) | **API-GAP: one assembled "followed enrollments" payload** — per-card fan-out would be N+1 from the client; recommend one endpoint. Storage of the followed set (preference key vs server model) is OQ-4 |

Contract shapes are the build suite's `03-data-and-api.md` to own; mobile additive-only
policy from the analytics spec applies to everything above.

## 6. Connections

- **Entry:** `shell-tabs` → home-dashboard (Home tab, the default tab).
- **Exits/overlays:** Overview plus → `home-kpi-picker` (overlay, future spec) · Following
  plus → `home-follow-picker` (overlay, future spec) · Engagement arrow → deferred (OQ-1) ·
  GroupFollowCard tap + program ellipsis menu → deferred (OQ-4).
- Nav row: tab selection edges are owned by `shell-tabs`/`shell-topnav`.

## 7. Legacy mapping

Replaces `iphone/MakeReady/Pages/Main/MainHome.swift` (the `MainTab.home` root):

| Legacy element | Disposition |
|---|---|
| `chartsSection` — `HeatMapChart` (engagement heatmap), `VerticalBarChart` (weekly), `Kpi` tiles | carried: home-dashboard (Sessions radial + Activity chart + Overview KPI rail are the successors; data moves from `/api/engagement/*` to the analytics layer) |
| `upcomingLessonsSection` (upcoming lessons via `SplitCalendarEvent`, tap → lesson flow, `EditEnrollmentDayWrapper`) | **gap candidate — not on 2.0 home**; likely moves to calendar/groups surfaces; must be dispositioned in gap-analysis sweep 2 |
| `loadActivityLogs` / activity feed | **gap candidate — not on 2.0 home** |
| Legacy components `Chart/{HeatMapChart, VerticalBarChart, Kpi}` | not reused (new chart anatomy); retire with legacy tree at cutover |

Route cases: the home tab root itself (`MainTab.home`); no modal `Route` cases are owned by
this screen.

## 8. Open questions

| # | Question | Blocking? | Decides |
|---|---|---|---|
| OQ-home-dashboard-1 | Engagement: precise definition of a "current" member, the "N active" header metric, and where the arrow-right leads | No — owner explicitly deferred (2026-09-01, "plan the component itself for now"); **must resolve before the build suite's server phase** | Owner |
| OQ-home-dashboard-2 | Session definition for session-ization (e.g. contiguous member activity with a gap timeout) | No for UI; gates the sessions API-GAP work | Owner + backend suite |
| OQ-home-dashboard-3 | Completion-percent color thresholds (observed: 55/89 green, 21 yellow, 12–13 red). **Narrowed 2026-09-10 (C-033 set run):** the band is an independent `color` prop, not derived from the percentage — the set renders "55%" in all three colours — so what remains open is only the mapping this screen should apply when it picks a band, not whether the component derives one | No — build defaults need the closed bands before the suite freezes | Owner |
| OQ-home-dashboard-4 | Following mechanics: where the followed set is stored (preference vs server model); group-card tap destination; ellipsis menu contents | No for this screen's layout; gates `home-follow-picker` and the assembled endpoint | Owner |
| OQ-home-dashboard-5 | Chart annotation font is Inter in Figma (TODAY/max/min/ticks) while everything else is SF Pro — intentional, or normalize to SF Pro? (2026-09-03: the owner-designated C-026 set `3633:4505` and C-029 frame `3634:4871` — labels, value, caption — both use Inter; strong evidence toward intentional) | No — becomes a closed deviation once ruled | Owner |
| OQ-home-dashboard-6 | Engagement progress fill is #4deb4b in Figma vs the `green` variable #6cff73 — intentional second green, or token drift? | No — token ruling | Owner |
| OQ-home-dashboard-7 | ~~The compact nav shows a different top-level set than the seeded tab roots~~ **RESOLVED 2026-09-05 via the owner-designated C-019 TopNav sets (`3555:32772` row, `3555:32733` tab):** the set is closed at 8 — Home · Library · Groups · Members · Enrollments · Invites · Programs · Media, in that order, with no Calendar and no Search tab. Contract: `design-system/components/C-019-top-nav.md` §2/§3. Residual: Library coexists with Programs and Media as siblings (OQ-C-019-8) | Closed | — |
| OQ-home-dashboard-8 | ~~Variant coverage unenumerated~~ **RESOLVED 2026-09-01 via the component sheet (node 3632:4502):** MiniDayChart set = `state` {Activity 1, Activity 2 (sample series), **No activity** (designed zero state — dots only)} × `align` {center, bottom} — fully covered by C-024's contract; Week completions = `style=Default` only (nothing else designed); Percentages = `style` {Thick 16pt, **Thin 2pt**} × `aligned` {Right, **Left**} × sample percents — C-031 consumes Thick/Right; Thin/Left are designed but unconsumed (available to future screens, not buildable here) | Closed | — |
