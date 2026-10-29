# ui2-enrollment-create — spec
> lg · no ticket · child 1 of `docs/features/ui2-enrollment` (PROGRAM.md, go-ahead Luke 2026-10-28)

## Idea

**Why.** Leaders cannot enroll a group in a study program anywhere in the UI 2.0 shell: the group
page's Enrollments `add` and the program page's enroll action are built but unwired
(`GroupDetailContainer.swift:49-70`, `StudyProgramHomeContainer.swift:63-83`), and the 1.0 wizard
(`EnrollmentFlowModal`) left the app target with ui2-shell. d2m has designed and built the 2.0
replacement — a "New enrollment" checklist (`groups-enroll-program`) and its six pickers — and this
feature wires them to live data and adds the server pieces the design depends on.

**What success looks like.** On the walk env as the Fixtures identity: from a group page, a program
page and the Enrollments card's `add` in the TopNav, a leader opens the checklist (the group or the
program preloaded where it came from), completes the six rows in any order, taps Enroll and sees
"Group enrolled". The enrollment the server creates has exactly the lesson dates the calendar showed
(long-press overrides included), the chosen sync mode and lesson access. A member opening a lesson
link of a one-at-a-time enrollment before that lesson's day sees "This lesson is available on
«date»"; every enrollment that existed before this feature still opens every lesson.

**In your words.** "I'm ready to implement the enrollment screens, they are all built in d2m" → D1 ·
"All of it" (scope) → D1 · "App sends exact dates" → D3 · "Enforce; existing stay open" → D4 ·
"Banner, stay ready" → D6 · "Picker and server" → D5 · "Add to program list" → D8 · "Save time,
send later" → D7.

**The concept.** One draft per flow instance, held in `AppState`, is the checklist's source of truth.
Each picker container seeds its screen from the draft and writes back only on Select/Save; the
checklist container derives every row's done/disabled look from the draft (the design's draft
rules) and, on Enroll, sends one `POST /api/enrollments` carrying the calendar's exact dates.

```mermaid
flowchart LR
  G[Group page add] -->|group preloaded| C
  P[Program page enroll] -->|program preloaded| C
  T[TopNav Enrollments add] --> C[EnrollChecklistContainer<br/>draft in AppState]
  C -->|row tap| S1[group] & S2[program] & S3[schedule] & S4[invite time] & S5[sync] & S6[access]
  S1 & S2 & S3 & S4 & S5 & S6 -->|Select/Save writes draft, pop| C
  C -->|Enroll| API[POST /api/enrollments<br/>scheduleDates + lessonAccess]
  API --> E[enrolled state] -->|Done/Back| Origin[where it started]
```

**How it fits today.** `EnrollmentActions.createEnrollment` (in the target) already posts groupId,
studyProgramId, startDate, enabledDays, smsTime, timezone, requireResponse and syncMode[1]; the server
re-derives every lesson date from start + weekdays + lesson count with server-local `getDay()`[2] and
creates lesson schedules, scheduled activities, LESSON events (smsTime → event start time) and a
welcome post[3]. Nothing sends SMS or gates a lesson by date today[4]. `GET /api/groups` is already
manage-filtered + active with `memberCount`[5]; `GET /api/programs?isPublished=true` returns `days`
(the lesson count), cover, createdAt[6]. The group picker is already wired for invites
(`InviteSelectGroupContainer`) — the picker-container template[7].
[1] `iphone/MakeReady/State/Actions/EnrollmentActions.swift:211-271` [2] `server/src/routes/enrollments.ts:226`, `server/src/services/enrollment-schedule.ts:29-47` [3] `enrollments.ts:112-525` [4] no writer of `smsSentAt`; `GET /lessons/code/:code` (`enrollments.ts:2158`) and `/lessons/view/:scheduleId` (`:2294`) have no date check [5] `server/src/routes/groups.ts:226`, `services/group-payload.ts` [6] `server/src/routes/programs.ts:434` [7] `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupContainer.swift:26`

**Approaches considered.** Chosen: the design as built, with the server taking the app's computed
dates (D3). Rejected: the server re-applying overrides (two copies of the date rule that must agree,
and server-local-time drift); dropping overrides (a d2m change and a lost 1.0 capability).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | `Enrollment.lessonAccess` (+ backfill); `POST /api/enrollments` takes `scheduleDates` + `lessonAccess`, refuses a 0-member group and a program outside the caller's read scope; the member lesson player (`GET /api/member/lessons/:lessonScheduleId`) and `/lessons/today/:enrollmentId` refuse a one-at-a-time lesson before its day (D15); `GET /api/programs` adds `completedEnrollmentCount`; fixture layer | §server |
| client | ✅ | The member lesson player (`LessonController.php:31-38`) turns every non-200 into `abort(404)`; it gains a not-yet page for D15's 403 ("This lesson is available on «date»"). The join page is untouched (D15 keeps its lookup routes open) | §client |
| iphone | ✅ | Seven d2m screens wired through containers; three entries; the draft; `createEnrollment` gains `scheduleDates` + `lessonAccess`; `Enrollment`/`StudyProgram` model fields | §iphone |
| capture | ⬜ | the seven `screen.2.0` ViewRegistry cases (`iphone/MakeReadyCaptureTests/ViewRegistry.swift:3150-3179`) are fixture-fed and their `MakeReadyUI` State is unchanged; `/compare` `enrollment-flow` (`capture/fixtures/compare/groups/enrollment-flow.json`) compares the untouched 1.0 wizard with the LeaderApp twin | — |

**Sequencing:** contract settled → server (schema, endpoints, fixtures) verifies → contract FREEZES →
iphone builds against it; client checks the D4 message → the walk on Fixtures.

**Backward compatibility:** every request field is optional and every response field additive.
Released 1.0 iPhone builds and the web admin keep creating enrollments as today: without
`scheduleDates` the server still derives the dates, and without `lessonAccess` the column default
`ALL_AT_ONCE` keeps every lesson open. Two behaviour changes reach existing callers: creating an
enrollment for a group with 0 members now returns 400 (D5), and a one-at-a-time lesson link opened
early returns 403 (D4) — no such enrollment exists until 2.0 creates one.

**Blast radius:** every caller of `POST /api/enrollments` (1.0 iPhone, web admin, server tests),
`GET /api/lessons/code/:code` and `GET /api/lessons/view/:scheduleId` (the member web join flow),
`GET /api/programs` (1.0 iPhone, web, 2.0 Programs); `Enrollment` reads (new column).

## Decisions

<!-- The one place rulings live. Record the DECISION — and, in one line, why, and why the rejected option lost. A stated preference
     is the INPUT to a row, not the row. Write each Ruling as something later code can be checked
     against without re-interpretation:
       · positive and specific — "store the full number, mask at render", not "don't truncate"
       · scope named — which apps, screens or endpoints it binds
       · "etc." / "and so on" expanded into the list, or the test for membership stated
       · the rejected alternative named, with the reason it lost (check-obligations warns on a bare one)
       · the enforcement hook, where one exists (lint rule, script, test)
     🔴 NEVER quote the user's prompt as the ruling. Operationalize it: a closed list, a measured
     value, an enumerated set of deviations. A ruling a stranger could implement two ways is not
     written yet.
     Who/date carries the provenance, so the Ruling itself needs no quote marks.
     The owner's own words go in §Idea "In your words", linked to this row — never in the Ruling.
     OPEN rows block the build go-ahead. Never delete a ruling; supersede it in place with a date. -->

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| D1 | Scope | This child wires `groups-enroll-program` and its six pickers (`enrollment-select-group`, `-program`, `-schedule`, `-invite-time`, `-sync`, `-access`) and the three entries (D2). The Enrollments tab and the enrollment detail are child 2 (`ui2-enrollments-browse`). Rejected: the flow without the tab/detail (owner chose all of it, split into two children) | Luke 2026-10-28 (PROGRAM P1) |
| D2 | Entries and exits | Group page `onEnrollProgram` → push the checklist with `groupId` preloaded; program page `onAddEnrollment` → `studyProgramId` preloaded; TopNav Enrollments card `add` → nothing preloaded (as Groups/Programs `add` push their create pages). Back on a checklist state, and Done/Back on `enrolled`, pop to the page that pushed it. Rejected: a button on the Enrollments tab (undesigned) | (assumed at intake) 2026-10-28 (PROGRAM P8) |
| D3 | Exact schedule | `POST /api/enrollments` accepts optional `scheduleDates: string[]` (`yyyy-MM-dd`). When present the server requires exactly one date per program lesson, strictly ascending, none before today in the request's `timezone` (UTC when absent); weekdays are NOT checked against `enabledDays`, because an added override may fall on any day; it uses them as `LessonSchedule.scheduledDate` in order and the last as `endDate`. Absent → today's `generateScheduleDates`. The 2.0 checklist always sends the dates `EnrollmentDateState` computed (overrides included). Rejected: sending overrides for the server to re-apply (two copies of the rule; server-local-time drift); dropping overrides (d2m change; lost 1.0 capability) | Luke 2026-10-28 (PROGRAM P2) |
| D4 | Lesson access | New `Enrollment.lessonAccess` (`ONE_AT_A_TIME` \| `ALL_AT_ONCE`, NOT NULL, default `ALL_AT_ONCE`); `POST` accepts it, the checklist always sends it. `GET /api/lessons/code/:code` and `GET /api/lessons/view/:scheduleId` return **403** `{success:false, error:"not_yet_available", message:"This lesson is available on «Weekday, Month d»", availableOn:"yyyy-MM-dd"}` when the schedule's enrollment is `ONE_AT_A_TIME` and today (in the enrollment's `timezone`, UTC when null) is before `scheduledDate`. Existing rows get `ALL_AT_ONCE` (the default fills them). Rejected: store only (does nothing); existing rows one-at-a-time (members lose open lessons). **Route list superseded 2026-10-28 by D15** (the 403 body stands) | Luke 2026-10-28 (PROGRAM P3) |
| D5 | Eligibility | Group picker: `AppState.groups` from `GET /api/groups` with `memberCount ≥ 1`. Program picker: `AppState.programs` (loaded by `ProgramActions.loadPrograms`, which sends no `isPublished` and `replaceAll`s the shared store, so the filter is local) with `isPublished == true` and `days ≥ 1`. `POST /api/enrollments` returns 400 `{success:false, error:"group_has_no_members", message:"Group has no members"}` for a 0-member group (active members, as `memberCount` counts them). Rejected: picker-only (other callers could enroll an empty group) | Luke 2026-10-28 (PROGRAM P4) |
| D6 | Enroll failure | A failed POST (network, 5xx, or a 4xx the pickers should have prevented) → `state.recordError(error, context: "EnrollChecklistContainer.enroll", surface: true, friendlyMessage: "Couldn't enroll", retry: enroll)` (`AppState.swift:355-362`), phase back to `checklist` (6/6, Enroll enabled). A 401 signs out via `AuthStatusPolicy.shouldSignOut` + `authManager.signOut()`, as `GroupDetailContainer.swift:245-275` does. Rejected: returning silently (a failure would look like nothing happened) | Luke 2026-10-28 (PROGRAM P5) |
| D7 | Invite time | The picker's `smsTime` (`HH:mm`) and its returned `timezone` are sent on POST. Sending invites at that time is out of scope. Rejected: building the sender now (Twilio, a scheduler and opt-outs make it a feature of its own) | Luke 2026-10-28 (PROGRAM P6) |
| D8 | Program completed count | `GET /api/programs` adds `completedEnrollmentCount` per program: enrollments of that program whose `endDate` is before the start of today (UTC). The program picker shows it as the design's completed count. Rejected: total enrollments under a "completed" label (the number would be wrong under its label). **Narrowed 2026-10-28 by D17**: shown only when the draft has no group | Luke 2026-10-28 (PROGRAM P7) |
| D9 | Draft | One `EnrollmentDraft` per flow instance in `AppState.enrollmentDrafts[UUID]` (fields: groupId, studyProgramId, startDate, enabledDays, overriddenDates, scheduleDates, endDate, smsTime, timezone, syncMode, lessonAccess, phase); created at push, removed on pop/Done, cleared in `clearInMemory()`. Row done/disabled flags are derived on read (design draft rules 1–5), never stored. Rejected: `@State` in the checklist container (pickers are separate pushed pages that must write it) | (assumed at spec) 2026-10-28 |
| D10 | Preload checks | A preloaded group counts as done only when it is in the eligible list (D5); a preloaded program only when published with `days ≥ 1`. A failing preload arrives not done (design rule 1). Program change clears the schedule's done state but keeps start/weekdays/overrides as the schedule picker's seed (design rule 2) | design ref 2026-10-28 |
| D11 | Picker warnings | Group picker Select: when the draft has a program and the group has an active enrollment in it (`GET /api/groups/:id/enrollments`), show the screen's already-enrolled warning; when the draft has a schedule and the group already has a lesson on one of its dates, the "Lesson already scheduled" warning. Warnings never block. Program picker Select: the already-enrolled warning against the draft's group. The schedule picker gets the draft group's existing lesson dates (`GET /api/groups/:id/enrollments` then `GET /api/enrollments/:id` per active enrollment, as 1.0) for its overlap prompt | design ref 2026-10-28 |
| D12 | Fixtures | `server/fixtures/screens/groups-enroll-program.ts` (one layer for the checklist and its six pickers, as `invite-member.ts` serves `enrollment-select-group` — no per-picker layer). Reuses base entities: the 0-member `FIXTURE_EMPTY_GROUP_ID` (`fixtures/ids.ts:65`, hidden), unpublished 0-lesson program 4 (`EMPTY_PROGRAM_ID`, hidden), group 1 with its active enrollment 4 (already-enrolled warning). Creates: program n 5 (published, 12 lessons) with one enrollment on a base group that ended before `ctx.now` (completed count 1), program n 6 (published, `days` 0, no lessons, hidden); enrollment/schedule ids from a fresh n 900+ range. Never creates orgs, users or groups | (assumed at spec) 2026-10-28 (PROGRAM P12) |
| D13 | Draft lifetime when the app closes | `AppState.enrollmentDrafts` is memory-only — excluded from the AppState disk cache, so a relaunch (or sign-out) discards an unfinished checklist and the leader starts again from an entry; matches the design's "Back discards the draft" (OQ-004) and D9's push→pop lifetime. Rejected: persisting drafts to disk (a resumed draft would need its own entry point and stale-preload rechecks the design does not draw) | auto (recommended) 2026-10-28 (raised at align) |
| D14 | Group picker enrollment chip | the third chip of `EnrollmentSelectGroupScreen` (`groupEnrollmentCounts`, contract "active-enrollment count") counts only enrollments whose `isActive` is true (`EnrollmentModels.swift:171` — `endDate > now` when the payload has no `isActive`, which `GET /api/groups/:id/enrollments` never sends; upcoming counts as active), filtered where the containers build the mapper's `enrollmentCounts` input (`InviteSelectGroupContainer.swift:20` and the new enroll container) so the invite picker shows the same number. Rejected: counting all enrollments as the invite picker does today (`InviteSelectGroupContainer.swift:20` — a group with only finished enrollments would read "highlighted") | auto (recommended) 2026-10-28 (raised at align) |
| D15 | Where one-at-a-time is enforced (supersedes D4's route list; D4's 403 body stands) | the gate is one service function `lessonAvailability(schedule, enrollment, now)` returning `{available, availableOn}`, applied to **`GET /api/member/lessons/:lessonScheduleId`** (`member-lessons.ts:555-620` → `member-progress.service.ts:637-720`, the real lesson player; group leaders and org managers exempt — it already computes `isGroupLeader`) and **`GET /api/lessons/today/:enrollmentId`** (`enrollments.ts:2420`). **`GET /api/lessons/code/:code` and `/lessons/view/:scheduleId` are NOT gated**: they are the join flow's lookup (`StudyJoinController.php:61-73,137-144` stores `lessonId`/`organizationId` from them), so gating them would stop a member joining the group before the lesson's day. The client lesson player renders D4's `message` on the 403. The member study home's existing client-side lock of future lessons (`use-study-home-state.ts:52-55`, every enrollment) is unchanged. Rejected: gating the lookup routes (blocks joining); leaving the player ungated (the access mode would do nothing — D4's rejected "store only") | auto (recommended) 2026-10-28 (raised at audit) |
| D16 | Schedule date storage | the server stores each `scheduleDates[i]` as 00:00 in the request `timezone` (the instant existing rows already hold — the iPhone sends local midnight, `enrollment-schedule.ts:29-47` copies it forward); never `new Date('yyyy-MM-dd')` (UTC midnight reads a day early in US zones and opens D4 a day early). `timezone` is validated in zod with `assertValidTimezone` (moved from `analytics.service.ts:439` to a shared util with `todayInTimezone`) → 400 on an invalid zone; with `scheduleDates`, `Enrollment.startDate` is stored as `scheduleDates[0]`. The iPhone formats the dates in `TimeZone.current` (the calendar's zone) and sends `timezone` = the invite-time picker's returned zone, else `TimeZone.current.identifier`. D4's "today" and `availableOn` use the enrollment's `timezone`; D8 stays UTC. Rejected: UTC-midnight storage (day shift) | auto (recommended) 2026-10-28 (raised at audit) |
| D17 | Whose completed count (d2m OQ-enrollment-select-program-003, owner-closed) | with a group in the draft, the program picker's completed chip counts that group's enrollments of the program with `endDate` before today, client-side from `app.enrollmentsFor(groupId:)`; with no group, it shows the server's `completedEnrollmentCount` (D8, which stays). Rejected: D8's org-wide count in every case (contradicts the owner's d2m answer) | auto (recommended) 2026-10-28 (raised at audit) |
| D18 | Already-enrolled / lesson-overlap confirm surface (d2m OQ-group-002, OQ-program-002) | the container presents C-066 `ActionMenuOverlay` via `.actionMenuPresentation` (as `GroupDetailContainer.swift:77`) with two rows — "Already enrolled — select anyway" (or "Lesson already scheduled — select anyway") and "Choose another" — a recorded deviation, because C-066 draws no title or body (`ActionMenuOverlay.swift:39-75`); a titled confirm is a d2m follow-up (`/ui2-component-update C-066`). Rejected: building a new confirm view in the app (d2m owns views); skipping the warning (OQ-002 rules it) | auto (recommended) 2026-10-28 (raised at audit) |
| D19 | Org / Leader chips on the two list pickers (d2m OQ-group-003, OQ-program-005) | group picker — Orgs chip visible only when `AppState.myOrganizations.count > 1`, copying `GroupsHomeMapper.swift:42-47`, filtering locally by `organizationId`; Leaders filters by `creatorId` as invite does. Program picker — Orgs hidden (`orgFilterVisible: false`: `GET /api/programs` is scoped to the session org, so there is nothing to switch to); Leaders filters locally on `leaderId ?? creatorId`, options from `AppState.groupLeaders` (`ProgramActions.swift:604`). Rejected: an org switch inside the picker (no API for it) | auto (recommended) 2026-10-28 (raised at audit) |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/enrollments` (extended) | server | iphone | `requireAuth`; group in `groupManageFilter`, active | existing + `scheduleDates?: string[]` (`yyyy-MM-dd`, D3), `lessonAccess?: "ONE_AT_A_TIME" \| "ALL_AT_ONCE"` (D4) | existing `{success, enrollment}` + `enrollment.lessonAccess`, `enrollment.syncMode` | 400 (zod incl. invalid `timezone` (D16); `scheduleDates` count ≠ lessons, not ascending, before today; 0-member group `group_has_no_members`; unpublished/no-lesson program — existing, `enrollments.ts:181-194`) · 401 · 404 (group outside `groupManageFilter`; program outside `programReadFilter(userId)` — new, T12) |
| `GET /api/member/lessons/:lessonScheduleId`, `GET /api/lessons/today/:enrollmentId` (extended, D15) | server | client (`LessonController.php`) | as today (member session) | unchanged | unchanged when open, and for group leaders / managers | **403** `{success:false, error:"not_yet_available", message:"This lesson is available on «Weekday, Month d»", availableOn:"yyyy-MM-dd"}` (D4) · as today |
| `GET /api/lessons/code/:code`, `GET /api/lessons/view/:scheduleId` (unchanged, D15) | server | client (join flow) | public | — | as today | as today |
| `GET /api/programs` (extended) | server | iphone | as today | unchanged (the iPhone loads without `isPublished` and filters locally, D5) | existing + `completedEnrollmentCount: number` per program (D8; one `enrollment.groupBy` after the `findMany`) | as today |
| `GET /api/groups`, `GET /api/groups/:id/enrollments`, `GET /api/enrollments/:id`, `GET /api/group-leaders`, `GET /api/organizations/my/organizations` (unchanged) | server | iphone | existing | — | existing | existing |

**Wire ↔ app mapping (align 2026-10-28)** — each layer keeps its own form; the transform is the mapper's,
written once:

| Design / screen field | iPhone draft | Wire (POST body / payload) | Server |
|---|---|---|---|
| `lessonAccess` `one-at-a-time` \| `all-at-once` (C-screen §5) | `EnrollmentDraft.lessonAccess` (screen form) | `ONE_AT_A_TIME` \| `ALL_AT_ONCE` | `Enrollment.lessonAccess` enum `LessonAccess` |
| `syncMode` `AUTO` \| `OFF` | `EnrollmentDraft.syncMode` | `AUTO` \| `OFF` (no transform; `APPROVAL` never sent) | `Enrollment.syncMode` `EnrollmentSyncMode` |
| schedule `enabledDays` `[Int]` 0 = Sun … 6 = Sat | `Set<Int>` | `enabledDays: ["Sun"…"Sat"]` (1.0 map) | `Enrollment.enabledDays` JSON string |
| schedule `onSelect` start/end/overrides `Date` | `startDate`, `endDate`, `overriddenDates`, `scheduleDates: [Date]` | `startDate` (= first date) + `scheduleDates: ["yyyy-MM-dd"]`, formatted in `TimeZone.current` (D16) — the list is a scratch `EnrollmentDateState(lessonCount:)`'s `highlightedDates.sorted()` (`MakeReadyUI/EnrollCalendar.swift:119-191`, in the app target), asserted `count == lessonCount` before POST | `Enrollment.startDate`/`endDate`, `LessonSchedule.scheduledDate` |
| `overriddenDates` | draft only (the schedule picker's seed) | not sent — folded into `scheduleDates` (DESIGN-ONLY) | — |
| `smsTime` `HH:mm`, `timezone` | draft | `smsTime`, `timezone` | `Enrollment.smsTime`, `.timezone` |
| group row: name, photo, leader, member count, created on | `UserGroup.name`, `.coverImageUrl`, `.creatorName`, `.memberCount`, `.createdAt` | `GET /api/groups` `toGroupPayload` (`memberCount` = active members) | `Group` + `_count.members where isActive` |
| group row: enrollment count | `app.enrollmentsFor(groupId:)` filtered `isActive` (D14) | `GET /api/groups/:id/enrollments` | `Enrollment` |
| program row: title, cover, created, days (the screen has no description field) | `StudyProgram.name`, `.coverImageUrl`, `.createdAt` (`MMM yyyy`), `.days` | `GET /api/programs` | `StudyProgram` |
| program row: completed count | draft group set → client count (D17); else `StudyProgram.completedEnrollmentCount` (T6) | `completedEnrollmentCount` (SC4) | derived, D8 |
| schedule `existingLessonDates` | from `GET /api/enrollments/:id` `lessonSchedules[].scheduledDate` per active enrollment | existing | `LessonSchedule.scheduledDate` |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Enrollment.lessonAccess` enum `LessonAccess {ONE_AT_A_TIME, ALL_AT_ONCE}`, NOT NULL, default `ALL_AT_ONCE` | POST body + enrollment payloads | accessibility row; D4 · T1, T6 | landed — migration 20261029005901 (d8e9cb2) |
| SC2 | EDIT | `POST /api/enrollments` | + `scheduleDates?`, `lessonAccess?`; 0-member 400 | exact schedule, access, eligibility; D3–D5 · T2, T9 | landed 7a91bbf |
| SC3 | EDIT | `GET /api/member/lessons/:lessonScheduleId`, `GET /api/lessons/today/:enrollmentId` (D15; `/lessons/code` + `/lessons/view` unchanged) | 403 `not_yet_available` | one-at-a-time enforcement; D4, D15 · T3, T11 | landed 4c97909 |
| SC4 | EDIT | `GET /api/programs` | + `completedEnrollmentCount` | program picker; D8 · T4, T6 | landed e17852d |

Align 2026-10-28 traced every screen field through the model, zod, wire and iPhone property; the four rows above are the whole data/wire delta (no further column is owed).

**Data plan:** SC1 goes through `server/schema/schema.yaml` → schema diff → one Atlas migration
(house rules: `scripts/atlas.sh --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`,
never `npm run schema:diff`, which reads the 1Password `.env`). The column is added NOT NULL with
`DEFAULT 'ALL_AT_ONCE'`, which fills every existing row in the same statement — that IS the backfill
(D4: existing enrollments stay fully open). Undo = drop the column and the enum. SC2–SC4 are wire
changes, additive for every caller except D4/D5's stated refusals and T12's program-scope 404. Independent ordering. The migration copies the `syncMode` precedent `server/atlas/migrations/20260706062151.sql:1-9` (`CREATE TYPE … AS ENUM` + `ADD COLUMN … NOT NULL DEFAULT` + `COMMENT`); every other Enrollment creator (`fixtures/base.ts:289`, `fixtures/screens/home-dashboard.ts:521`, tests) is covered by the default.

## server

- **Schema:** SC1 in `schema/schema.yaml` (Enrollment block ~2361) + the enum; generated Prisma client
  regenerated; migration committed with `atlas.sum`.
- **`POST /api/enrollments`** (`src/routes/enrollments.ts:112`): zod gains `scheduleDates` (array of
  `yyyy-MM-dd`, optional) and `lessonAccess` (optional enum). After loading the program's lessons:
  `scheduleDates` given → a pure `validateScheduleDates(dates, lessonCount, tz, now)` in
  `services/enrollment-schedule.ts` (length = `lessons.length`, strictly ascending, first ≥ today in
  `timezone`) else 400 `"Schedule doesn't match the program"`; the stored dates are 00:00 in
  `timezone` (D16), replacing `generateScheduleDates(...)`; `startDate` = the first. `timezone`
  validated (D16). The group lookup selects `_count.members where isActive` (as `groups.ts:240`); 0 →
  D5's 400. The program lookup spreads `programReadFilter(userId)` (`study-program.service.ts:136`) →
  404 outside it (T12). `lessonAccess` saved; response `select` (`:402-438`) adds `lessonAccess`, `syncMode`.
- **Lesson gate** (D15): `lessonAvailability(schedule, enrollment, now)` in a service, used by
  `getMemberLessonDetail` (`member-progress.service.ts:637-720`; leaders/managers exempt) and
  `/lessons/today/:enrollmentId` (`enrollments.ts:2420`); each enrollment select adds `timezone` +
  `lessonAccess`; the message formats the date with `Intl` in the enrollment's timezone as
  "This lesson is available on «Weekday, Month d»". `/lessons/code` and `/lessons/view` unchanged.
- **`GET /api/programs`** (`src/routes/programs.ts:434`): add `completedEnrollmentCount` with one
  `prisma.enrollment.groupBy({by:['studyProgramId'], where:{studyProgramId:{in:ids}, endDate:{lt:startOfTodayUTC}}})`
  after the `findMany`, as the org-name lookup at `:508` does (a filtered `_count` can't sit beside the
  existing `_count.enrollments` the iPhone reads); the mocked prisma in `programs-list.request.test.ts` gains `groupBy`.
- **Fixtures:** `server/fixtures/screens/groups-enroll-program.ts` per D12 (the runner discovers
  `screens/*.ts` by filename, `fixtures/runner.ts:91-99`); DB test
  `fixtures/__tests__/groups-enroll-program.db.test.ts` copying `invite-member.db.test.ts`, asserting
  the hidden/visible split and the completed count.

## client

- **Lesson player** (`app/Http/Controllers/LessonController.php:31-38`): on a 403 whose body `error` is
  `not_yet_available`, render a not-yet state with the body's `message` (a neutral line, not the 404
  page), instead of today's `abort(404)` for every non-200. Feature test with `Http::fake`
  (pattern `tests/Feature/StudyJoinTest.php:19`). Design-token SCSS only; no native dialogs.
- **Join page** unchanged (D15 leaves `/lessons/code` and `/lessons/view` open, so the info step keeps
  storing `lessonId`/`organizationId`).
- Web enrollment creators (LeaderApp `leader-enrollment-flow.store.ts:158`, legacy
  `enrollments.domain.ts:98`) keep working; a 0-member group now gets D5's 400 — the legacy admin
  shows its `message`, the LeaderApp its generic "Something went wrong" dialog (accepted, §Out of scope).
- Rebuild the client before capturing (built-bundle landmine).

## iphone

- **Routes** (`UI2/Shell/UI2ShellModel.swift`): `UI2Destination` gains `.enrollChecklist(flowId:)`,
  `.enrollSelectGroup(flowId:)`, `.enrollSelectProgram(flowId:)`, `.enrollSelectSchedule(flowId:)`,
  `.enrollSelectInviteTime(flowId:)`, `.enrollSelectSync(flowId:)`, `.enrollSelectAccess(flowId:)`;
  `UI2Shell` page switch maps each to its container.
- **Entries:** `GroupDetailContainer` passes `onEnrollProgram`; `StudyProgramHomeContainer` passes
  `onAddEnrollment`; `TopNavHost` `onAdd` handles `.enrollments`. Each creates the draft (D9) with its
  preload and pushes `.enrollChecklist`.
- **Draft** (`State/`): `EnrollmentDraft` + `AppState.enrollmentDrafts`, cleared in `clearInMemory()`;
  a pure `EnrollChecklistMapper` derives `GroupsEnrollProgramScreen.State` (row strings per the
  design's §3 rows table, phase, Schedule disabled until the program row is done) and each picker's
  seed state.
- **Checklist container:** `GroupsEnrollProgramScreen` with `onSelectStep` → push the step's picker,
  `onEnroll` → phase `processing` → `EnrollmentActions.createEnrollment(... scheduleDates:,
  lessonAccess:)` → `enrolled`, or D6 on failure; `onBack`/`onDone` → remove the draft and pop.
  Fields `Enrollment.lessonAccess`/`syncMode` decoded tolerantly; `createEnrollment` maps weekday
  ints to `"Sun"…"Sat"` as 1.0 did.
- **Picker containers** (copy `InviteSelectGroupContainer`): group (search/org/leader filters, D5
  filter, `scrollsList: true`, D11 warnings), program (D5 filter, `completedEnrollmentCount`, D11
  warning), schedule (`lessonCount` = program `days`, `programChosen`, existing lesson dates,
  `onSelect` → start/end/days/overrides + the computed `scheduleDates`), invite time, sync, access.
  Each writes the draft only in its Select/Save callback, then pops.
- **Models:** `StudyProgram.completedEnrollmentCount: Int?`, `EnrollmentWithProgram.lessonAccess`/`.syncMode: String?` —
  each needs its `CodingKeys` case + `decodeIfPresent` + `encodeIfPresent` in the custom coders
  (`StudyModels.swift:55-150`, `EnrollmentModels.swift:46-127`); both are disk-cached
  (`PersistedState.swift:18,24`), so absent keys decode nil; no `schemaVersion` bump.
- **After create** (T13): `createEnrollment` today only adds index ids (`EnrollmentActions.swift:254-265`),
  which also makes `loadEnrollmentCounts` skip that group; the Action reloads
  `loadEnrollments(groupId:)`, `ProgramActions.getProgramEnrollments(programId:, forceRefresh: true)`
  and the group's next-study/days, so the group and program pages show the new enrollment.
- **Back-swipe and the draft:** arm `UI2BackSwipeGuard` (`UI2Navigation.swift:117`) while the phase is
  `processing`; drafts whose `.enrollChecklist(flowId)` has left the path are pruned when the shell
  path changes (memory-only, D13).
- **Picker selection by id:** the list screens hold the picked row as an index in their own `@State`,
  seeded once (`EnrollmentSelectGroupScreen.swift:79,105`, Program `:94`); the container tracks the
  picked id from `onPickGroup`/`onPickProgram` and re-keys the screen with `.id(rowIds)` when the
  filtered rows change, so `onSelect(index)` always names the highlighted row.
- **Org/Leader chips** per D19; the shared `InviteSelectGroupMapper` (`:47` hard-codes
  `orgFilterVisible: false`, no member filter) gains `eligibleOnly` + `organizations` inputs, defaulted
  to today's invite behaviour.

## Testing

**server**
- POST: `scheduleDates` used verbatim (stored dates = sent dates, `endDate` = last); 400 on wrong
  count, unsorted, a past first date; absent → derived as today; `lessonAccess` stored and returned,
  absent → `ALL_AT_ONCE`; 0-member group → 400; existing POST tests stay green
- lesson routes: one-at-a-time lesson before its day → 403 with `availableOn`; on/after its day → 200;
  all-at-once → 200 any day; both routes
- programs list: `completedEnrollmentCount` counts only ended enrollments of that program
- POST tenancy: a program outside `programReadFilter` → 404 (`test/enrollment-authorization.test.ts`); invalid `timezone` → 400; stored dates are 00:00 in the request zone (D16)
- member lesson detail + `/lessons/today`: one-at-a-time before its day → 403 for a member, 200 for a group leader; `/lessons/code` and `/lessons/view` stay 200 (D15)
- existing POST tests add an active `groupMember` before posting (D5 — see A1)
- migration applies clean; existing rows read `ALL_AT_ONCE`; fixtures DB test (D12)

**client**
- `LessonController`: a `not_yet_available` 403 renders the not-yet line; any other non-200 still 404s (feature test, `Http::fake`)

**iphone**
- mapper tests: every row's to-do/done copy (design §3 rows, including the three OQ-005 texts),
  Schedule disabled until the program row is done, percent per done count, the phase render
- draft rules: preload pass/fail (D10), program change un-does the schedule and keeps its seed, group
  change cascades nothing, defaults never count as done, Back from a picker leaves the draft unchanged
- `EnrollmentActions.createEnrollment` body: `scheduleDates`, `lessonAccess`, `syncMode`, weekday map;
  failure routes per D6; `ios:build-check --test`; swiftlint baseline
- route tests for the seven destinations; `clearInMemory` clears drafts

**Cross-app verification script (Fixtures identity = org Owner, walk env)**
1. Open a fixture group's page → Enrollments `add` — the checklist opens at 1/6 with the group row done
2. Tap Schedule — it is disabled (no program yet); tap Study program — the picker hides the unpublished
   and 0-lesson programs and shows a completed count; pick one, Select — 2/6, Schedule enabled
3. Tap Schedule — pick a start, long-press one in-range weekday to skip it, Select — the row shows the
   start and end; note the dates
4. Set invite time 7:30 AM, Sync Off, Accessibility One at a time — 6/6, header shows Enroll
5. Tap Enroll — "Group enrolled"; Done returns to the group page
6. Server check (or the 1.0 app / web admin): the new enrollment's lesson dates equal step 3's dates,
   the skipped day absent; `lessonAccess` ONE_AT_A_TIME, `syncMode` OFF
7. As a member of the group, open a future lesson of the new enrollment in the web lesson player (its `/lesson/…` URL) — "This lesson is available on «date»"; today's lesson opens; a pre-existing (all-at-once) enrollment's future lesson still opens by URL; the join link for a future lesson still lets a new member join
8. From a program page's enroll action — the program row arrives done; from the TopNav Enrollments
   `add` — nothing preloaded, 0/6
9. In the group picker the 0-member fixture group is absent; picking the already-enrolled group with
   that program chosen shows the warning and still lets Select through
10. Turn on airplane mode and tap Enroll — the "Couldn't enroll" banner with Retry; the checklist stays
    at 6/6

## Out of scope

- The Enrollments tab and enrollment detail — child 2 (`ui2-enrollments-browse`), decider PROGRAM P1.
- Sending invite SMS at `smsTime` (D7) — a separate feature, owner 2026-10-28.
- Editing an enrollment, APPROVAL sync, `requireResponse` (dropped by the design; the server keeps accepting both).
- Deleting the 1.0 wizard files (out of the target; 2.0 cutover).
- Rescheduling that keeps D3's custom dates: edit, sync re-slotting and add-day (`enrollment-edit.ts:135-150`, `enrollment-sync.ts:418`, `enrollments.ts:4859-4885`) still walk `enabledDays`, so a later reschedule drops skipped days — editing is out of scope (audit 2026-10-28).
- The member study home honouring `ALL_AT_ONCE` (it locks future lessons client-side for every enrollment today, `use-study-home-state.ts:52-55`) — unchanged, D15.
- The LeaderApp web enrollment flow filtering 0-member groups; it shows a generic error on D5's 400 (audit 2026-10-28).
- A titled confirm in C-066 (D18) — a `/ui2-component-update` follow-up.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| T1 | server: `LessonAccess` enum + `Enrollment.lessonAccess` in `schema/enums.yaml` + `schema/schema.yaml`, Atlas migration, Prisma client regenerated (SC1) | blocking |
| T2 | server: `POST /api/enrollments` zod + handler — `scheduleDates` (D3), `lessonAccess` (D4), 0-member 400 (D5), response `select` adds `lessonAccess`, `syncMode` (SC2) | blocking |
| T3 | server: `lessonAvailability` service + the one-at-a-time 403 on `GET /api/member/lessons/:lessonScheduleId` (leaders exempt) and `/lessons/today/:enrollmentId` (SC3, D15) | blocking |
| T4 | server: `GET /api/programs` `completedEnrollmentCount`, one grouped query (SC4) | blocking |
| T5 | server: fixture layer `server/fixtures/screens/groups-enroll-program.ts` + DB test (D12) — service-only, no DDL | blocking |
| T6 | iphone: models — `StudyProgram.completedEnrollmentCount: Int?`; `EnrollmentWithProgram.lessonAccess: String?` and `.syncMode: String?`, `decodeIfPresent` (the released 1.0 cache has neither key; today's model decodes no `syncMode` at all) | trailing |
| T7 | iphone: `EnrollmentDraft` + `AppState.enrollmentDrafts`, memory-only (D13), cleared in `clearInMemory()` | trailing |
| T8 | iphone: checklist + picker mappers carrying the §Contract *Wire ↔ app mapping* transforms (lessonAccess kebab ↔ SCREAMING, weekday ints ↔ `Sun…Sat`, `Date` → `yyyy-MM-dd` in the draft's timezone) with unit tests per transform | trailing |
| T9 | iphone: `EnrollmentActions.createEnrollment` body gains `scheduleDates` + `lessonAccess` (SC2 consumer) | trailing |
| T10 | iphone: group picker enrollment chip counts `isActive` only (D14), in the shared mapper | trailing |
| T11 | client: `LessonController` renders D4's not-yet `message` on a `not_yet_available` 403 (SC3 consumer, D15) | trailing |
| T12 | server: POST program lookup spreads `programReadFilter(userId)` → 404 outside it — pre-existing tenancy gap: any leader can enroll a group in another org's or a private program by UUID (`enrollments.ts:147-175`, comment "any active program") | build-time risk — settled by the POST task (T2) |
| T13 | iphone: `createEnrollment` refreshes the stores the group/program pages read (§iphone *After create*) | trailing |
| contract-1 | contract: D4 as written gated the join lookup and missed the real player — `GET /api/member/lessons/:id` has no date check (`member-progress.service.ts:637-720`) and the join flow needs the lookup (`StudyJoinController.php:61-73`) | §Contract, §server, §client written to D15 — settled, D15 ruled 2026-10-28 |
| contract-2 | contract: D3's "same midnight convention" does not exist — stored dates are copied instants (`enrollment-schedule.ts:29-47`); UTC-midnight parsing shifts a day | D16 (ruled 2026-10-28) |
| contract-3 | contract: D8's org-wide completed count contradicts d2m OQ-enrollment-select-program-003 (group-scoped) | D17 (ruled 2026-10-28) |
| A1 | build-time risk: every existing POST test creates the enrollment for a group with no active member (`program-publish.test.ts:229-240`, `enrollment-sync.test.ts:151,214`, `enrollment-sync-engine.test.ts:167,508`, `enrollment-edit.test.ts:41`, `member-version-resolution.test.ts:114`) — D5 turns them red | the POST task (T2) adds an active member to each |
| A2 | build-time risk: D3 counts against `lessons.length` while the picker and welcome post use `days`; only app code keeps them equal (`programs.ts:1688,4104`) — a drifted program 400s every 2.0 enroll | T2's 400 message names the expected count; the iPhone mapper uses `days` |
| A3 | build-time risk: five pickers report `updateNeeded: true` in d2m (group, program, invite-time, sync, access) — an update could move init signatures mid-build | the first iPhone task calls `check_project_change` for each screen before wiring |
| A4 | build-time risk: `EnrollmentDateState.calculatedEndDate` can stop at its iteration cap short of `lessonCount` (`EnrollCalendar.swift:154-174`) | T8 asserts `count == lessonCount` and treats a short list as "schedule not done" |
| A5 | nit: double-submit — POST has no idempotency and no transaction (deliberate sequential steps with cleanup, `enrollments.ts:226-396`) | the checklist's `processing` phase disables Enroll; no server key |
| A6 | nit: D11's per-enrollment detail load pulls every lesson's activities to get dates (`EnrollmentActions.swift:147-182`) | accepted, as 1.0 |
| A7 | nit: the POST's zod 400 sends `error` as an array; the iPhone `Response.error: String?` can't decode it (`enrollments.ts:470`) | harmless — D6 treats every failure alike |
| R1 | repoint (iphone): legacy enrollment wizard ← no hit in the MakeReady app target (`EnrollmentFlowModal.swift`, `SelectGroupPage.swift`, `SelectStudyProgramPage.swift`, `EnrollmentSyncPage.swift`, `ConfirmEnrollmentPage.swift`, `Services/Route.swift:66-67,127-128`, `NavigationCoordinator.swift:130` all out of the target; `AppState.swift:314` comment only; `MakeReadyCaptureTests/CaptureFixture.swift:93` capture-only); no deep-link/push target creates an enrollment (`PushNotificationManager.swift:14-19`) | nothing to repoint — builder:plan's retire phase is empty |
| V1 | design (items 7–8): all seven screens built in d2m, every frame built; component dots green except select-schedule (amber, 3 drawn components not in §4 — no build impact); d2m exposes no render-diff %, so the render check rests on d2m's built status. OQs: groups-enroll-program 001–005 closed and covered (D2, D13, §Testing); select-group 001/004/005/006 built in, 002 → D18, 003 → D19; select-program 001/004 built in, 002 → D11+D18, 003 → D17, 005 → D19; select-schedule 001–004 built in / D10; select-invite-time 001 = D7; sync, access none (access opens on one-at-a-time with an empty value — the draft reads not-done until Save). No owner notes on any of the seven | READY |

## Plan

The plan, with its code: `docs/features/ui2-enrollment-create/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · `LessonAccess` enum + `Enrollment.lessonAccess` column (SC1)
- Phase 1 · Task 2 · shared timezone util + `validateScheduleDates` (D3, D16)
- Phase 1 · Task 3 · `POST /api/enrollments` — exact dates, lesson access, eligibility, program scope (SC2, D3–D5, D16, T12)
- Phase 2 · Task 4 · one-at-a-time lesson gate (SC3, D4, D15)
- Phase 2 · Task 5 · `GET /api/programs` `completedEnrollmentCount` (SC4, D8)
- Phase 2 · Task 6 · `groups-enroll-program` fixture layer + DB test; record the contract freeze (D12)
- Phase 3 · Task 7 · models — `lessonAccess`, `syncMode`, `completedEnrollmentCount` (T6)
- Phase 3 · Task 8 · `createEnrollment` sends exact dates + access and refreshes the stores (T9, T13)
- Phase 3 · Task 9 · `EnrollmentDraft` in `AppState` + the checklist mapper (D9, D10, D13, T7, T8)
- Phase 3 · Task 10 · picker mappers — group (D5, D14, D19), program (D5, D17, D19), schedule seed (T8, T10)
- Phase 4 · Task 11 · routes, shell page switch and draft pruning (D2, D13)
- Phase 4 · Task 12 · checklist container, enroll submit and the three entries (D2, D6, A5)
- Phase 4 · Task 13 · group + program picker containers with the warnings (D5, D11, D14, D18, D19)
- Phase 4 · Task 14 · schedule, invite-time, sync and access picker containers (D7, D10, D11, T8)
- Phase 5 · Task 15 · member lesson player renders the not-yet message (T11, D15)

## Prototype

Ref: `groups-enroll-program`, `enrollment-select-group`, `enrollment-select-program`,
`enrollment-select-schedule`, `enrollment-select-invite-time`, `enrollment-select-sync`,
`enrollment-select-access` — d2m era 2.0, Figma section Enrollment `4674:44206`; every screen and
component **built** in `iphone/MakeReadyUI/Screens/Groups/` (d2m dots green; select-schedule's
component dot amber: 3 drawn components not in its §4, no build impact). d2m is the source read; the
design doc `d2m docs/superpowers/specs/2026-10-24-enrollment-flow-design.md` is cited by the screen specs.

## Replaced surfaces

| # | Surface (file:line) | REPLACES/ABSORBS/REUSES | Fingerprint | App |
|---|---|---|---|---|
| R1 | `iphone/MakeReady/Pages/Manage/Group/Enrollment/EnrollmentFlowModal.swift` (`Route.enrollmentFlow`, `.programEnrollmentFlow`) + `SelectGroupPage`, `SelectStudyProgramPage`, `EnrollmentSyncPage`, `ConfirmEnrollmentPage` | REPLACES (1.0 linear wizard; out of the app target since ui2-shell, left in place; `requireResponse` + APPROVAL dropped) | legacy enrollment wizard | iphone |
| R2 | `iphone/MakeReady/Pages/Manage/Group/SelectEnrollDatePage.swift` (`EnrollmentDateState`) | REUSES (ported inside C-128 / `EnrollmentSelectScheduleScreen`) | end-date + override rule | iphone |
| R3 | `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupContainer.swift` + mapper | REUSES (picker-container pattern) | group picker wiring | iphone |
| R4 | `iphone/MakeReady/State/Actions/EnrollmentActions.swift:211` `createEnrollment` | REUSES (extended, D3/D4) | create call | iphone |

**N# — what the design adds that the app lacks (written into this SPEC):**

| # | Add | Disposition | App |
|---|---|---|---|
| N1 | exact schedule on create | written into the SPEC — D3, SC2 | server |
| N2 | lesson access stored + enforced | written into the SPEC — D4, SC1, SC3 | server, client |
| N3 | 0-member refusal, completed count | written into the SPEC — D5, D8, SC2, SC4 | server |
| N4 | checklist + six pickers + three entries + draft | written into the SPEC — D2, D6, D9–D11 | iphone |
| N5 | invite SMS sending | out of scope — D7, owner 2026-10-28 | server |

## Fixes

Root causes (agent walk round 1, evidence `.builder/ui2-enrollment-create/agent-walk/round-1/`): (A) `GroupsEnrollProgramScreen` has no ScrollView (its D22 comment) — on iPhone 17 Pro Max the ~1150pt checklist overflows the pushed page: the C-040 header (Back/Enroll) lands at y −81 and the sixth row under the TabBar; (B) `EnrollmentSelectProgramScreen.swift:162` and `EnrollmentSelectGroupScreen.swift:177` build `SearchField` without `editable: true` (defaults `false`), so search is display-only. Both views are d2m-owned — `check_project_change` first; a handover lane goes through `request_project_change`, or the container (`EnrollChecklistContainer`) makes the page scroll.

- [x] iphone: E4 set Accessibility to One at a time → 6/6 with Enroll in the header — expected the sixth row reachable and the header on-screen, saw the Accessibility row under the TabBar (y 891–1006 vs 872) and the header at y −81, neither reachable by swipe; stuck at 83% (cause A) (agent walk round 1) — fixed d54998c: the checklist scrolls under the pinned header
- [x] iphone: E5 tap Enroll → "Group enrolled" → Done back to the group page with Next Study reloaded — expected the success flow, saw no reachable Enroll or Back (cause A) (agent walk round 1) — fixed d54998c: the checklist scrolls under the pinned header
- [x] iphone: E6 the iPhone-created enrollment's dates match E3 with ONE_AT_A_TIME / OFF — expected one iPhone POST, saw none (blocked by cause A) (agent walk round 1) — fixed d54998c
- [x] iphone: E10 Enroll offline → "Couldn't enroll" banner with Retry, checklist stays 6/6 — expected the failure path, saw 6/6 unreachable (cause A) (agent walk round 1) — fixed d54998c: the checklist scrolls under the pinned header
- [x] iphone: item 2 `createEnrollment` body on a live POST (`scheduleDates`, `lessonAccess`, `syncMode`, weekday map) — expected the checklist's POST, saw no app POST in the walk-server log (cause A) (agent walk round 1) — fixed d54998c: the checklist scrolls under the pinned header
- [x] iphone: E2 typing 2+ characters in the program picker's search keeps the keyboard up, and the highlight matches what Select commits — expected an editable field, saw tapping raises no keyboard (0 text fields) (cause B) (agent walk round 1) — fixed ccc5df8: SearchField editable; the highlight follows the pick
- [x] iphone: E9 typing 2+ characters in the group picker's search keeps the keyboard up — expected an editable field, saw tapping raises no keyboard (0 text fields) (cause B) (agent walk round 1) — fixed ccc5df8: SearchField editable; the highlight follows the pick

Root causes (agent walk round 2, evidence `.builder/ui2-enrollment-create/agent-walk/round-2/`): (C) `iphone/MakeReady/UI2/Shell/UI2ErrorBannerHost.swift` never renders `AppError.retry`, so the `retry:` D6 passes to `recordError` is unreachable and the banner auto-dismisses after 4 s; (D) `EnrollmentActions.createEnrollment` (`EnrollmentActions.swift:311`) sets `nextStudyByGroupId[groupId] = nil` but never reloads it, against SPEC §After create — and the group page's `.task` does not re-run when the checklist pops; (E) since ccc5df8 made picker search editable, the C-066 "Already enrolled" menu opens under a still-raised keyboard.

- [x] iphone: E10 Enroll fails → "Couldn't enroll" banner with Retry, checklist stays 6/6 — expected the banner with a Retry action, saw no Retry and the banner auto-dismissing after 4 s (cause C) (agent walk round 2) — fixed: the 2.0 banner shows Retry (dismiss, then re-run)
- [ ] iphone: E5 Enroll → "Group enrolled" → Done back on the group page with Next Study reloaded — expected the Next Study card to show the server's next lesson (Day 30 Walking Through John, 200 from the server), saw "No lessons scheduled" until a fresh launch (cause D) (agent walk round 2)
- [ ] iphone: E9 in the group picker type 2+ characters, pick an already-enrolled group and tap Select → "Already enrolled" warning → Select anyway — expected the warning visible and tappable, saw it open under the keyboard (menu y 722–894, keyboard y 655–898), not hittable, a tap typing into the search field (cause E — dismiss the keyboard on Select/row tap, or present above it) (agent walk round 2)
