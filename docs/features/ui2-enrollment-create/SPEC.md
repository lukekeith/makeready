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
| server | ✅ | `Enrollment.lessonAccess` (+ backfill); `POST /api/enrollments` takes `scheduleDates` + `lessonAccess`, refuses a 0-member group; the two lesson-open routes refuse a one-at-a-time lesson before its day; `GET /api/programs` adds `completedEnrollmentCount`; fixture layer | §server |
| client | ✅ | The member join page already renders a failed lookup's `message` (`client/app/Http/Controllers/StudyJoinController.php:50-57`); this feature verifies that the D4 response reads correctly there and adjusts the view only if it does not | §client |
| iphone | ✅ | Seven d2m screens wired through containers; three entries; the draft; `createEnrollment` gains `scheduleDates` + `lessonAccess`; `Enrollment`/`StudyProgram` model fields | §iphone |
| capture | ⬜ | screens capture from fixture JSON via ViewRegistry, not the live API; nothing in `/compare` reads enrollments-create | — |

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
| D4 | Lesson access | New `Enrollment.lessonAccess` (`ONE_AT_A_TIME` \| `ALL_AT_ONCE`, NOT NULL, default `ALL_AT_ONCE`); `POST` accepts it, the checklist always sends it. `GET /api/lessons/code/:code` and `GET /api/lessons/view/:scheduleId` return **403** `{success:false, error:"not_yet_available", message:"This lesson is available on «Weekday, Month d»", availableOn:"yyyy-MM-dd"}` when the schedule's enrollment is `ONE_AT_A_TIME` and today (in the enrollment's `timezone`, UTC when null) is before `scheduledDate`. Existing rows get `ALL_AT_ONCE` (the default fills them). Rejected: store only (does nothing); existing rows one-at-a-time (members lose open lessons) | Luke 2026-10-28 (PROGRAM P3) |
| D5 | Eligibility | Group picker: `AppState.groups` from `GET /api/groups` with `memberCount ≥ 1`. Program picker: `GET /api/programs?isPublished=true` rows with `days ≥ 1`. `POST /api/enrollments` returns 400 `"Group has no members"` for a 0-member group (active members, as `memberCount` counts them). Rejected: picker-only (other callers could enroll an empty group) | Luke 2026-10-28 (PROGRAM P4) |
| D6 | Enroll failure | A failed POST (network, 5xx, or a 4xx the pickers should have prevented) → `state.recordError(surface: true, friendlyMessage: "Couldn't enroll", retry: enroll)`, phase back to `ready` (checklist, Enroll enabled). A 401 signs out. Rejected: returning silently (a failure would look like nothing happened) | Luke 2026-10-28 (PROGRAM P5) |
| D7 | Invite time | The picker's `smsTime` (`HH:mm`) and its returned `timezone` are sent on POST. Sending invites at that time is out of scope. Rejected: building the sender now (Twilio, a scheduler and opt-outs make it a feature of its own) | Luke 2026-10-28 (PROGRAM P6) |
| D8 | Program completed count | `GET /api/programs` adds `completedEnrollmentCount` per program: enrollments of that program whose `endDate` is before the start of today (UTC). The program picker shows it as the design's completed count. Rejected: total enrollments under a "completed" label (the number would be wrong under its label) | Luke 2026-10-28 (PROGRAM P7) |
| D9 | Draft | One `EnrollmentDraft` per flow instance in `AppState.enrollmentDrafts[UUID]` (fields: groupId, studyProgramId, startDate, enabledDays, overriddenDates, scheduleDates, endDate, smsTime, timezone, syncMode, lessonAccess, phase); created at push, removed on pop/Done, cleared in `clearInMemory()`. Row done/disabled flags are derived on read (design draft rules 1–5), never stored. Rejected: `@State` in the checklist container (pickers are separate pushed pages that must write it) | (assumed at spec) 2026-10-28 |
| D10 | Preload checks | A preloaded group counts as done only when it is in the eligible list (D5); a preloaded program only when published with `days ≥ 1`. A failing preload arrives not done (design rule 1). Program change clears the schedule's done state but keeps start/weekdays/overrides as the schedule picker's seed (design rule 2) | design ref 2026-10-28 |
| D11 | Picker warnings | Group picker Select: when the draft has a program and the group has an active enrollment in it (`GET /api/groups/:id/enrollments`), show the screen's already-enrolled warning; when the draft has a schedule and the group already has a lesson on one of its dates, the "Lesson already scheduled" warning. Warnings never block. Program picker Select: the already-enrolled warning against the draft's group. The schedule picker gets the draft group's existing lesson dates (`GET /api/groups/:id/enrollments` then `GET /api/enrollments/:id` per active enrollment, as 1.0) for its overlap prompt | design ref 2026-10-28 |
| D12 | Fixtures | `server/fixtures/screens/groups-enroll-program.ts`: a group with 0 members (hidden in the picker), a group already enrolled in a fixture program (warning), a published program with ≥ 10 lessons, an unpublished program and a 0-lesson program (both hidden), one completed enrollment (completed count 1) | (assumed at spec) 2026-10-28 (PROGRAM P12) |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/enrollments` (extended) | server | iphone | `requireAuth`; group in `groupManageFilter`, active | existing + `scheduleDates?: string[]` (`yyyy-MM-dd`, D3), `lessonAccess?: "ONE_AT_A_TIME" \| "ALL_AT_ONCE"` (D4) | existing `{success, enrollment}` + `enrollment.lessonAccess`, `enrollment.syncMode` | 400 (zod; `scheduleDates` count ≠ lessons, not ascending, before today; 0-member group; unpublished/no-lesson program) · 401 · 404 (group/program) |
| `GET /api/lessons/code/:code`, `GET /api/lessons/view/:scheduleId` (extended) | server | client | public (as today) | unchanged | unchanged when open | **403** `{success:false, error:"not_yet_available", message, availableOn}` (D4) · 404 as today |
| `GET /api/programs` (extended) | server | iphone | as today | unchanged (`isPublished=true` used by the picker) | existing + `completedEnrollmentCount: number` per program (D8) | as today |
| `GET /api/groups`, `GET /api/groups/:id/enrollments`, `GET /api/enrollments/:id`, `GET /api/group-leaders`, `GET /api/organizations/my/organizations` (unchanged) | server | iphone | existing | — | existing | existing |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Enrollment.lessonAccess` enum `LessonAccess {ONE_AT_A_TIME, ALL_AT_ONCE}`, NOT NULL, default `ALL_AT_ONCE` | POST body + enrollment payloads | accessibility row; D4 | planned |
| SC2 | EDIT | `POST /api/enrollments` | + `scheduleDates?`, `lessonAccess?`; 0-member 400 | exact schedule, access, eligibility; D3–D5 | planned |
| SC3 | EDIT | `GET /api/lessons/code/:code`, `GET /api/lessons/view/:scheduleId` | 403 `not_yet_available` | one-at-a-time enforcement; D4 | planned |
| SC4 | EDIT | `GET /api/programs` | + `completedEnrollmentCount` | program picker; D8 | planned |

**Data plan:** SC1 goes through `server/schema/schema.yaml` → schema diff → one Atlas migration
(house rules: `scripts/atlas.sh --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`,
never `npm run schema:diff`, which reads the 1Password `.env`). The column is added NOT NULL with
`DEFAULT 'ALL_AT_ONCE'`, which fills every existing row in the same statement — that IS the backfill
(D4: existing enrollments stay fully open). Undo = drop the column and the enum. SC2–SC4 are wire
changes, additive for every caller except D4/D5's stated refusals. Independent ordering.

## server

- **Schema:** SC1 in `schema/schema.yaml` (Enrollment block ~2361) + the enum; generated Prisma client
  regenerated; migration committed with `atlas.sum`.
- **`POST /api/enrollments`** (`src/routes/enrollments.ts:112`): zod gains `scheduleDates` (array of
  `yyyy-MM-dd`, optional) and `lessonAccess` (optional enum). After loading the program's lessons:
  `scheduleDates` given → validate D3 (length = `lessons.length`, strictly ascending, first ≥ today
  in the request `timezone`) else 400 `"Schedule doesn't match the program"`; the schedule list is
  those dates (as stored `scheduledDate` values, the same midnight convention `generateScheduleDates`
  uses) instead of `generateScheduleDates(...)`. The group lookup adds the active-member count; 0 →
  400 `"Group has no members"`. `lessonAccess` saved; response `select` adds `lessonAccess`, `syncMode`.
- **Lesson open routes** (`enrollments.ts:2158`, `:2294`): after loading the schedule with its
  enrollment, apply D4; the message formats the date as "This lesson is available on «Weekday, Month d»".
- **`GET /api/programs`** (`src/routes/programs.ts:434`): add `completedEnrollmentCount` (a filtered
  `_count` or one grouped query — no per-program N+1).
- **Fixtures:** `server/fixtures/screens/groups-enroll-program.ts` per D12, registered in the screens
  index; its DB test asserts the hidden/visible split.

## client

- `StudyJoinController.php:50-57` already shows `$result['body']['message']` for any non-200 on the
  `info` step. Verify on the walk env that a one-at-a-time lesson opened early renders
  "This lesson is available on «date»" in the join page's error slot, not "Study not found.". Change the
  view only if the copy or styling reads as an error rather than a not-yet state (the minimal change:
  branch on `error === 'not_yet_available'` to a neutral line). Rebuild the client before capturing
  (built-bundle landmine).

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
- **Models:** `StudyProgram.completedEnrollmentCount: Int?`, enrollment `lessonAccess: String?`.

## Testing

**server**
- POST: `scheduleDates` used verbatim (stored dates = sent dates, `endDate` = last); 400 on wrong
  count, unsorted, a past first date; absent → derived as today; `lessonAccess` stored and returned,
  absent → `ALL_AT_ONCE`; 0-member group → 400; existing POST tests stay green
- lesson routes: one-at-a-time lesson before its day → 403 with `availableOn`; on/after its day → 200;
  all-at-once → 200 any day; both routes
- programs list: `completedEnrollmentCount` counts only ended enrollments of that program
- migration applies clean; existing rows read `ALL_AT_ONCE`; fixtures DB test (D12)

**client**
- the D4 403 renders the "available on" line on the join page (walk + a feature test on the controller
  when the view branches)

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
7. Open a future lesson's link on the web join page — "This lesson is available on «date»"; today's
   lesson opens; a pre-existing enrollment's future lesson still opens
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

## Findings & risks

| # | Finding | Resolution |
|---|---|---|

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
