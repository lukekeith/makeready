# UI 2.0 Program — Spec Manifest

The master tracker for the complete UI rebuild: every iPhone screen changes, the member
lesson-consumption UI is rebuilt on the web, and the activities model moves to the
YouVersion-style vertical pager (`docs/features/activities/`). **This file is the source of
truth for program state** — every screen-spec session updates it as its last act, so a fresh
session can pick up exactly where the last one stopped.

**How to work a screen:** run `/ui2-screen` (no argument — takes the first item in the
**Spec queue** below that isn't `specced`), `/ui2-screen <screen-id>` to target one, or
`/ui2-screen <screen-id> <figma-url>` to attach/refresh a Figma source. The command encodes
the pipeline (ingest design → decompose against the component registry → write the screen
spec → update the shared artifacts → update this manifest). One screen per run. For a
Figma link that is a COMPONENT (not a screen), run `/ui2-component <url>` instead — it
specs the whole variant set into `design-system/components/` and the registry (D10),
without touching this screen manifest.

**Where to look at them:** the capture app's component browser has a UI 1.0 ⇄ 2.0 switch —
`http://localhost:5950/components/2.0` lists every registry row, renders each specced
component's frozen Figma snapshot, and takes pinned comments on it (rows without a contract
show the `/ui2-component` command that specs them). It reads `docs/ui2/` and never writes to
it. See `docs/features/component-browser/14-phase-5-ui2-era.md`.

## Hard rules

- **Spec only — no app code.** The spec phase writes docs (`docs/ui2/`), never touches
  `client/`, `server/`, `iphone/`, or `capture/`. Building happens later via `/build-spec`
  suites (see **Build program** below).
- **Figma is normative where it exists.** A screen spec cites its Figma node + a frozen
  snapshot under `screens/assets/`; deviations are a closed enumerated list ending "anything
  else that differs is a defect" (build-spec REFERENCE.md §3c). No-Figma screens name a doc
  source instead (activities analysis §, legacy screen file, or operationalized user intent).
- **No legacy blending** (DECISIONS.md D2). Screen specs describe the new UI on its own
  terms; the only legacy reference is each spec's §Legacy-mapping (which screens/routes it
  replaces) and the registry's `existing` rows.
- **Every visual element resolves to a registry row** (`design-system/registry.md`). A spec
  may not describe a component the registry doesn't list — add the row in the same run.
- **Update this README last, every run.** That is the resumability contract.
- **Component sheet:** Figma node `3632:4502` holds all components (link in DECISIONS.md
  D9) — consult it per consumed component for designed states/variants; it is not wholly
  normative (some entries are prototype-only).

## Status legend

| Status | Meaning |
|---|---|
| `—` | not started |
| `draft` | spec started, incomplete (in-progress marker inside the spec says where) |
| `blocked(OQ#)` | spec written but an open question pins it — resolve in the spec's §8 |
| `specced` | spec complete: normative source + closed contracts + registry rows + legacy mapping |
| `gap-checked` | survived the gap-analysis sweeps (set during that phase, not per-run) |
| `suite-assigned` | claimed by a build-spec suite in the Build program table |
| `built` | its suite's phase covering this screen is VERIFIED |
| ✅ `verified` | user verified live in the UI 2.0 shell |

## Screen table

Screen ids are `<area>-<name>` kebab. Platform: `iphone` (leader app) or `web-member`
(member lesson runtime — DECISIONS.md D1). Figma: `figma` (link attached) / `pending-figma`
(design coming) / `no-figma` (specced from a doc source by decision).

### Shell & chrome (iphone)

| Screen | Platform | Figma | Status | Spec | Notes |
|---|---|---|---|---|---|
| `shell-topnav` | iphone | pending-figma | — | | Account-switcher top nav; doc source exists: `docs/features/navigation/01-account-switcher-analysis.md` (Robinhood morph) |
| `shell-tabs` | iphone | pending-figma | — | | Tab bar / root navigation chrome for the 2.0 shell |

### Tab roots (iphone)

| Screen | Platform | Figma | Status | Spec | Notes |
|---|---|---|---|---|---|
| `home-dashboard` | iphone | figma | specced | [spec](screens/home-dashboard.md) | node 3622:5487; replaces `Pages/Main/MainHome.swift` (upcoming-lessons + activity feed = gap candidates); 7 non-blocking OQs incl. deferred Engagement semantics |
| `groups-home` | iphone | figma | specced | [spec](screens/groups-home.md) | node 3668:7676; flat filtered directory (no sub-tabs); **zero new components** — full registry reuse; creation + requests surfaces pending future frames (OQ-2/3) |
| `groups-detail` | iphone | pending-figma | — | | group screen; entered from groups-home row tap (+ members-profile group rows); Figma to come |
| `shared-edit-field` | iphone | figma | specced | [spec](screens/shared-edit-field.md) | **PATTERN** (primary section 3875:8253, 6 frames — re-specced 2026-09-02, zero drift; AI-state frames retained from 3860:8218): single-field edit screens opened by any C-042 EditableFieldRow tap; text/multiline/radio/range/toggle inputs, dirty-gated Save, 3-state AI-suggestions block; §2b annex = the normative group-field instantiations for `groups-detail`; owner confirmed scope: group home / program home / member home; 6 non-blocking OQs; new API-GAP: tri-state directory access vs Boolean `memberDirectoryEnabled` |
| `library-home` | iphone | pending-figma | — | | **Redefined 2026-09-05 (owner) — NOT the legacy MainLibrary.** The leader's own captured content: video · audio · notes, all created by the nav add action's three options (Record video / Record audio / Write a note), organized by the content types found in their **transcripts**. Undesigned. Doc sources already exist: `docs/features/notes/` + `docs/features/memo/` (their §4b manifests are registry rows C-001–C-018) |
| `calendar-home` | iphone | pending-figma | — | | replaces `Pages/Main/MainCalendar.swift`. **NOT a 2.0 tab** (2026-09-05: the closed C-019 tab set has no Calendar) — its entry surface is unaccounted for; gap-analysis candidate |
| `search-home` | iphone | pending-figma | — | | replaces `Pages/Search/GlobalSearchPage.swift`. **NOT a 2.0 tab** (2026-09-05: no Search tab in the closed set) — legacy search is a real tab today, so its 2.0 entry surface must be found or the capability consciously dropped; gap-analysis candidate |
| `programs-home` | iphone | pending-figma | — | | **Added 2026-09-05 (owner):** the Programs tab root — the list of study programs (MakeReady curriculum); a row tap opens `study-program-home`. **Id note:** `programs-home` was briefly the id of what is now `study-program-home` (renamed 2026-09-01 as a misnomer, no spec written under the old meaning); it is reclaimed here for the list screen it actually names |
| `media-home` | iphone | pending-figma | — | | **Added 2026-09-05 (owner):** the Media tab root — curriculum assets used inside programs and lessons (the legacy MainLibrary "Media" sense), distinct from `library-home`'s leader-captured content |
| `members-home` | iphone | figma | specced | [spec](screens/members-home.md) | node 3668:6801; org member directory (new tab — no direct legacy counterpart); filter-menu behavior from Filter.MP4; 3 non-blocking OQs |
| `enrollments-home` | iphone | figma | specced | [spec](screens/enrollments-home.md) | node 3823:34548 (invoked as "Enrollments", id normalized per D8); NEW tab — org-wide enrollment directory grouped by group; absorbs MainPrograms "Enrolled" tab; minted C-058–C-059; nav row evidences EXPANDED tab set (…Invites·Programs·Media — OQ-4 for shell-topnav); 6 non-blocking OQs; API-GAPs: assembled org-wide feed, "Active" status definition, multi-org filter |
| `members-profile` | iphone | figma | specced | [spec](screens/members-profile.md) | node 3668:8120; **universal member screen** (tapping any member anywhere opens it); 4 non-blocking OQs (edit flows + destinations deferred to future frames) |

### Activities (the model change — analysis adopted from `docs/features/activities/`)

| Screen | Platform | Figma | Status | Spec | Notes |
|---|---|---|---|---|---|
| `activities-editor` | iphone | pending-figma | — | | leader edit-in-place canvas = the player (activities 07/09); preview system retired |
| `activities-player` | web-member | pending-figma | — | | vertical pager, member runtime (activities 01/03/05) |
| `activities-completion` | web-member | pending-figma | — | | checkmark + streak/up-next page (activities 01 §end) |

### Flows & management screens

Rows are added here as Figma arrives or as the screen map identifies them — the current
app's 74 pages do NOT map 1:1 to 2.0 screens; the gap-analysis phase proves nothing was
lost. Don't pre-enumerate.

| Screen | Platform | Figma | Status | Spec | Notes |
|---|---|---|---|---|---|
| `study-program-home` | iphone | figma | **blocked(OQ-12, OQ-13)** | [spec](screens/study-program-home.md) | **Re-specced 2026-09-10 against node `3833:32194`** (owner-designated; the 440×1896 frame `3524:29600` is superseded). Substantially different screen: header icons off + title "Study program", no publish badge, no Info block, **7 inline C-042 settings rows**, "Active enrollments" as C-037 rows (no percentages), three C-063 LessonCards with C-061 slide rails, **Demographics and Group Activity gone**. **ZERO new components**; C-053/C-054/C-055/C-056 orphaned (OQ-14, contracts kept at `screens/study-program-home-superseded-contracts.md`); C-063 `dateLabel`→`metaLabel`; C-040 icons-on now designed-unconsumed program-wide. Blocked on OQ-12 (semantics of the four new StudyProgram settings fields) + OQ-13 (program-level `leaderId`) — both are additive-schema rulings the build suite needs. Original 2026-09-01 pass: node 3524:29600; **renamed from `programs-home`** (user id + Figma frame name) and moved out of Tab roots — it's a PUSHED page (C-040 back bar). Replaces `Pages/Manage/Program/ProgramHomePage.swift` (`.programHome`) — the old row's "replaces StudyProgramHome" was wrong: that file is the programs list (→ `programs-home`, added 2026-09-05 — earlier text said `library-home`, corrected by the owner's Library ruling). Minted C-052–C-057; first consumer of C-040 Two-icons + C-043 align-Right; 9 non-blocking OQs; 4 API-GAPs (publishedAt/creator select, members-current metric, bundled enrollment completion, age-demographics aggregate) |
| `enrollment-home` | iphone | figma | specced | [spec](screens/enrollment-home.md) | node 3773:6944; single-enrollment detail (entered from enrollments-home row tap — resolves half of OQ-enrollments-home-5); minted C-060–C-064; first consumer of C-025 Percent-circle/Today/Lesson-day states + C-021 calendar; unenroll + sync = dropped-candidates for gap analysis; 8 non-blocking OQs; API-GAPs: day-bucketed completion, assembled payload |
| `enrollment-schedule-edit` | iphone | pending-figma | — | | schedule editor opened by enrollment-home "Edit schedule"; discovered via enrollment-home §6 |
| `invite-home` | iphone | figma | specced | [spec](screens/invite-home.md) | nodes 3832:30788 (unlinked) + 3832:31138 (linked) — two designed content states; invite detail: recipient hero, linked-member block, group-invitation rows (C-037 new Group+status type), event timeline (minted C-065); no invite actions designed (OQ-4); API-GAPs: leader-facing by-recipient payload, invite event history; 6 non-blocking OQs |
| `invites-home` | iphone | pending-figma | — | | invites list (entry surface for invite-home; the Invites nav tab evidenced on enrollments-home now has a confirmed detail page — partially answers OQ-enrollments-home-4); discovered via invite-home §6 |
| `create-study-program` | iphone | figma | specced | [spec](screens/create-study-program.md) | node 3833:33374 ("Create program step 1"); shared-edit-field pattern instantiation as creation step 1 — ZERO new components; replaces `CreateProgramPage.swift` (`.createProgram`); **API contract clash: POST /api/programs requires templateId, design collects title only** (OQ-2 + activities-model template retirement); 3 non-blocking OQs |
| `home-kpi-picker` | iphone | pending-figma | — | | manage-metrics toggle list overlay (add + remove in one picker); discovered via home-dashboard §6 |
| `home-follow-picker` | iphone | pending-figma | — | | add-enrollment-to-follow overlay; storage model is OQ-home-dashboard-4; discovered via home-dashboard §6 |

## Spec queue (dependency-ordered)

Fresh sessions take the FIRST unchecked item whose prerequisites are done. Shell and shared
surfaces first — they mint the registry rows everything else consumes. The queue grows as
screen rows are added; insert new items respecting dependencies.

- [ ] `shell-topnav` — no prerequisites. **C-019's component contract now exists** (`design-system/components/C-019-top-nav.md`, 2026-09-05 `/ui2-component` run): both resting states, the closed 8-tab set (Home·Library·Groups·Members·Enrollments·Invites·Programs·Media — closing OQ-home-dashboard-7 + OQ-enrollments-home-4), and C-069 NavTabButton. This spec now owns only the SHELL half: placement, stickiness, safe area, what the row's height change does to page content, and the morph choreography ruling (OQ-C-019-5). Behavior reference stays `docs/features/navigation/01-account-switcher-analysis.md` (Nav.MP4). **Blocked-ish:** OQ-C-019-8 (Library coexisting with Programs + Media as sibling tabs) also gates `library-home`
- [ ] `shell-tabs` — after `shell-topnav`
- [x] `home-dashboard` — **specced 2026-09-01 (queue jump: Figma arrived first)**; minted C-019–C-033 + first token seeding
- [x] `members-home` — **specced 2026-09-01 (queue jump: Figma + Filter.MP4 arrived)**; minted C-034–C-038 + first motion tokens; FilterMenuOverlay is the program's option-menu chrome (also serves C-028)
- [ ] `home-kpi-picker` — after `home-dashboard`; small overlay
- [ ] `home-follow-picker` — after `home-dashboard`; needs OQ-home-dashboard-4
- [x] `members-profile` — **specced 2026-09-01**; minted C-040–C-044, amended C-021/C-025/C-037/C-038; first consumer of Percentages Thin/Left + MetaChip Complete
- [x] `groups-home` — **specced 2026-09-01**; zero new components (C-019/34/35/36/37/38/43 reuse)
- [x] `shared-edit-field` — **specced 2026-09-01 (pattern), re-specced 2026-09-02** (source → section 3875:8253, zero drift; + group-field annex feeding `groups-detail`); minted C-045–C-051; resolves members-profile OQ-1; every future C-042 host inherits it
- [ ] `groups-detail` — after `groups-home`; awaiting Figma
- [ ] `activities-player` — analysis-rich (activities docs); mints pager/theming rows
- [ ] `activities-editor` — after `activities-player` (shares its page surface)
- [ ] `library-home` — after `home-dashboard`; **redefined 2026-09-05** — leader-captured video/audio/notes organized by transcript-derived content type. Spec it WITH `docs/features/notes/` + `docs/features/memo/` (those suites already carry its component manifest, C-001–C-018) and with the nav add action's three options as its entry point
- [ ] `programs-home` — after `home-dashboard`; the study-program list feeding `study-program-home` (already specced) and hosting the program-create affordance (OQ-create-study-program-3)
- [ ] `media-home` — after `programs-home`; curriculum assets
- [ ] `calendar-home` — after `home-dashboard`
- [ ] `search-home` — after `home-dashboard`
- [x] `enrollments-home` — **specced 2026-09-02 (queue jump: Figma arrived; new screen, added this run)**; minted C-058–C-059; expanded nav tab-set evidence recorded for `shell-topnav`
- [x] `enrollment-home` — **specced 2026-09-02 (queue jump: Figma arrived; new screen, added this run)**; minted C-060–C-064; consolidation OQ w/ C-056; banding OQ now spans four screens
- [x] `invite-home` — **specced 2026-09-02 (queue jump: Figma arrived; new screen, added this run)**; minted C-065; C-037 gains Group+status; two-frame content states
- [x] `create-study-program` — **specced 2026-09-03 (queue jump: Figma arrived; new screen, added this run)**; zero new components (pattern instantiation); templateId contract clash flagged
- [ ] `invites-home` — after `invite-home`; awaiting Figma (likely the Invites tab root)
- [ ] `enrollment-schedule-edit` — after `enrollment-home`; awaiting Figma
- [x] `study-program-home` (was `programs-home`) — **specced 2026-09-01 (queue jump: Figma arrived first, ahead of `library-home`)**; minted C-052–C-057 + first elevation token. **Re-specced 2026-09-10** against the owner's new frame `3833:32194` — zero new components, four rows orphaned, now `blocked(OQ-12, OQ-13)` pending two additive-schema rulings
- [ ] `activities-completion` — after `activities-player`

*(Reorder freely when the user feeds Figma in a different order — a screen with a fresh
Figma link jumps the queue; note the jump here.)*

## Phase gates

1. **Spec phase** (now): work the queue until every screen row is `specced` and no
   `blocked(OQ#)` remains.
2. **Gap analysis** (`gap-analysis.md`): only after the spec phase — five sweeps (routes,
   pages, capabilities, endpoints, **registry naming/scoping** per the registry's Naming &
   scoping rules — first audit ran 2026-09-02) until zero open `GAP-###`.
3. **Build phase**: decompose into `/build-spec` suites (table below), per `migration.md`.

**Running alongside all three:** the *preview build* lane (`preview-build.md`, D11) — `/ui2-component-build <C-###>` turns one specced component into a capturable SwiftUI preview so the browser can diff it against its frozen Figma snapshot. It is wired into no screen and decides nothing `ui2-shell` owns; it exists to make a contract verifiable before the build phase reaches it.

## Build program (empty until the build phase)

Filled during gap analysis. Each suite is an ordinary `/build-spec` feature (one bounded
flow — never one mega-suite, never one suite per screen) that cites this program's screen
specs + registry rows as normative sources (REFERENCE.md §3d). Anticipated shape:
`activities-model` (server) → `ui2-shell` → `activities-player-web` ∥ `activities-editor-ios`
→ per-area leader suites → `ui2-cutover`.

| Suite | Screens covered | Prerequisite suites | Status |
|---|---|---|---|
