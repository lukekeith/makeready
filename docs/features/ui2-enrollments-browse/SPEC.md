# ui2-enrollments-browse — spec
> lg · no ticket · child 2 of `docs/features/ui2-enrollment` (PROGRAM.md, go-ahead Luke 2026-10-28) · builds on ui2-enrollment-create (shipped 2026-10-28)

## Idea

**Why.** Leaders can create enrollments in the 2.0 app, but cannot see them: the Enrollments TopNav
section is an empty page, and a checklist abandoned half-way is lost the moment the leader backs out
(the draft lives only in app memory). This feature gives leaders one place to see every enrollment in
their org and how it is going, a detail page per enrollment, and makes an unfinished enrollment a
saved **draft** they — or a co-leader — can come back to.

**What success looks like.** A leader opens Enrollments and sees every enrollment, grouped by group,
with progress, completed members, planned hours and the enrolled date; filters by org, group, leader
and status (Active · Upcoming · Completed · Draft · All); opens one and sees its facts, schedule span,
per-day completion and lessons. A leader who picks a group and a program in the checklist and walks
away finds that enrollment on the list marked "Draft · n/6" (and on the group page), taps it, and
lands in the checklist with every row they did restored; "Discard enrollment" removes it.

**In your words.** "in order for the Enrollment process to save it's status (and show up on the
enrollments list page), it needs a group and a study program" → D3 · "anytime the user clicks on the
enrollment from the enrollments page, it will open the checklist so they can pick up where they left
off" → D7, D9 · "we also need a page action button for "Discard enrollment" at the bottom of the
checklist page" → D10

**The concept.**

```mermaid
flowchart LR
  C[Checklist] -- group+program set --> P[POST /enrollment-drafts]
  C -- each later Select --> U[PATCH /enrollment-drafts/:id]
  C -- Discard + confirm --> X[DELETE /enrollment-drafts/:id]
  C -- Enroll --> E[POST /enrollments draftId] --> R[Enrollment created, draft deleted]
  L[Enrollments list] -- feed --> F[GET /enrollments-feed]
  L -- enrollment row --> H[Enrollment detail GET /enrollments/:id/home]
  L -- draft row --> C
  G[Group page] -- draft row --> C
```

**How it fits today.** The checklist (ui2-enrollment-create) keeps its draft in
`AppState.enrollmentDrafts[UUID]`[1] and sends nothing until Enroll's `POST /api/enrollments`[2],
which writes the enrollment, schedules, activities, events and welcome post in sequential steps (no
transaction)[2]. `Enrollment` requires dates and weekdays and is read by 16 server files[3]. Groups
have no leader field — `Group.creatorId` is the only owner link; leader access is org role
(`groupManageFilter`)[4]. Completion lives in `MemberActivityProgress`/`MemberVideoProgress`/
`MemberLessonProgress`, computed per lesson by `getEnrollmentCompletionStats`[5]; there is no
per-enrollment hours or recency field[5]. `EnrollmentsHomeScreen`, `EnrollmentHomeScreen` are built
in d2m and unwired; the shell shows `EmptyPage` for `.enrollments`[6].

**Approaches considered.** Chosen: a separate `EnrollmentDraft` table, promoted on Enroll (D2).
Rejected: a DRAFT status on `Enrollment` — every one of the 16 readers would have to learn to skip
drafts, and one miss leaks a half-made study to members or analytics. Rejected: two specs (browse,
then drafts) — drafts are only reachable through the list.

[1] `iphone/MakeReady/State/EnrollmentDraft.swift:6` [2] `server/src/routes/enrollments.ts:136-514`
[3] `grep -rln prisma.enrollment.find server/src` [4] `server/src/services/permission.ts:299,335,365`
[5] `server/src/services/enrollment-analytics.service.ts:42`; `schema.prisma:1059,1069,1301,1326,1353`
[6] `iphone/MakeReady/UI2/Shell/UI2Shell.swift:217`

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | New `EnrollmentDraft` model + CRUD; `POST /api/enrollments` takes `draftId`; new org-wide feed `GET /api/enrollments-feed`; new assembled read `GET /api/enrollments/:id/home`; fixture layers | §server |
| client | ⬜ | The web LeaderApp has no draft or org-wide enrollment surface; every endpoint it reads is unchanged, and drafts live in a table it never queries | — |
| iphone | ✅ | Enrollments section + enrollment detail wired; drafts saved, autosaved, resumed, discarded; group page lists drafts; four d2m screens gain defaulted inputs (D14) | §iphone |
| capture | ⬜ | The `screen.2.0` ViewRegistry cases are fixture-fed; d2m re-records the four changed screens' captures itself as part of D14's changes | — |

**Sequencing:** contract settled → server (schema, endpoints, fixtures) verifies → contract FREEZES →
d2m lands D14's four screen inputs → iphone builds against both → the walk on Fixtures.

**Backward compatibility:** additive only. `draftId` on POST is optional; released 1.0 iPhone builds
and the web admin never send it and never call the new routes. No existing response changes shape.

**Blast radius:** `POST /api/enrollments` callers (1.0 iPhone, web admin, 2.0 checklist, tests);
`fixtures/wipe.ts` (new table); nothing else reads `EnrollmentDraft`.

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
| D1 | Scope | The Enrollments section (enrollments-home), the enrollment detail (enrollment-home) and draft enrollments (save, autosave, resume, discard), as one spec. Rejected: drafts as a separate child, or as a rework of the shipped create child (drafts are only reachable through this list) | Luke 2026-10-28 |
| D2 | Draft storage | New table `enrollment_drafts` (§Schema SC1): `groupId`, `studyProgramId` required; every other checklist field nullable; `createdById`, `updatedById`, timestamps. Enroll creates the `Enrollment` from the checklist and deletes the draft (D11). Rejected: a DRAFT status on `Enrollment` (16 readers would each have to skip drafts; one miss leaks) | Luke 2026-10-28 |
| D3 | When a draft is saved | The first `POST /api/enrollment-drafts` fires the moment the checklist holds both a group and a study program (whichever is picked second, or both preloaded). Before that nothing is stored, and Back loses the checklist as today. Rejected: saving from the first pick (a draft with no program can't be listed by program) | Luke 2026-10-28 |
| D4 | Autosave | After the draft exists, every picker Select that changes the draft (group, program, schedule, invite time, sync, access) sends one `PATCH` with the changed fields. A failed PATCH keeps the value in the app, retries once after 2 s, and on a second failure surfaces the error banner "Couldn't save the draft" with Retry; the checklist stays usable. Rejected: save on leaving the checklist (a quit or crash loses work); a Save draft button (undesigned, forgettable) | Luke 2026-10-28 |
| D5 | Who sees a draft | Every leader whose `groupManageFilter(userId)` admits the draft's group can list, read, update, enroll and delete it; others get 404. Rejected: creator only (co-leaders can't pick it up; duplicates) | Luke 2026-10-28 |
| D6 | One draft per pair | Unique `(groupId, studyProgramId)`. `POST` for an existing pair returns 409 `draft_exists` with `draftId`; a `PATCH` that would move a draft onto a pair another draft holds returns the same 409 and changes nothing. On 409 the app replaces the checklist page with the existing draft's checklist (its saved rows restored; this checklist's unsaved rows dropped; the draft being edited, if any, keeps its old pair). Rejected: offering open-or-new (allows duplicates); allowing duplicates silently | Luke 2026-10-28 |
| D7 | Where drafts show | (a) Enrollments section: a draft sits in its group's section as a row marked `Draft · n/6` with `Started by «name»` in place of progress, completed, hours and enrolled date; (b) group page Enrollments section: drafts listed after the enrollments, same marker; (c) a draft row tap pushes the checklist for that draft. The group page's Enrollments stat and count chip count enrollments only. Rejected: a pinned Drafts block on the list (undesigned layout) | Luke 2026-10-28 (stat: assumed at brainstorm) |
| D8 | Status filter | Options, in order: Active (startDate ≤ today ≤ endDate) · Upcoming (startDate > today) · Completed (endDate < today) · Draft · All. Resting value Active. Drafts appear under Draft and All only. "today" is the request's `tz` (device zone). Rejected: Active/Completed only (hides enrollments that have not started yet) | Luke 2026-10-28 (PROGRAM P9 + drafts) |
| D9 | Stale start date on resume | When a draft is opened and its first `scheduleDates` entry is before today (device zone), the schedule counts as not done: the app clears `startDate`, `scheduleDates`, `endDate` in the local draft and PATCHes them null, keeps `enabledDays` and `overriddenDates` as the picker's seed, and the picker opens on today. Every other row keeps its value. Rejected: shifting dates automatically (unseen dates enrolled); failing at Enroll (dead end at the last step) | Luke 2026-10-28 |
| D10 | Discard enrollment | A C-048 `PageActionButton` "Discard enrollment", destructive role, at the bottom of the checklist, shown while the checklist is backed by a saved draft and its phase is `checklist`. Tap → C-066 action menu rows "Discard enrollment" (destructive) and "Keep editing". Confirm → `DELETE /api/enrollment-drafts/:id`, end the local draft, pop to the page that pushed the checklist; failure → banner "Couldn't discard the draft" with Retry, page stays. Rejected: always shown (one button, two meanings before a draft exists); no confirm (accidental loss of shared work) | Luke 2026-10-28 |
| D11 | Enroll from a draft | The checklist sends `draftId` with `POST /api/enrollments`. After the enrollment and its welcome post are created the server deletes that draft with `deleteMany({ id: draftId, groupId })` — non-fatal (a failure is logged, the 200 stands). The app removes the draft from its store on 200. Rejected: the app deleting the draft after the POST (a crash between leaves a draft beside its enrollment) | (assumed at spec) 2026-10-28 |
| D12 | Hours on a row | Planned study time: the sum of the enrollment's non-removed `LessonSchedule.estimatedMinutes` ÷ 60, shown with at most one decimal and no trailing `.0` (`12`, `1.5`); a null minute counts 0. Rejected: member time spent (only video watch time is recorded, undercounts); hiding it | Luke 2026-10-28 |
| D13 | Leader | "Leader" means the group's creator (`Group.creatorId`): the Leaders filter lists the creators of the groups in the feed; the detail page's "Group leader" shows that user's name. Rejected: the enrollment's creator (the label says Group leader) | Luke 2026-10-28 |
| D14 | d2m screen inputs | Four existing d2m screens gain inputs with defaults (no new screen; requested through `request_project_change` at the iPhone phase's start, each a handover the build waits on): (1) enrollments-home — per-row `programDraftLabels: [String]` (`""` = an enrollment row; non-empty = draft row showing that label and `programDraftStarters[row]` instead of the three chips and the bar); (2) groups-detail — the same two arrays on its Enrollments rows; (3) groups-enroll-program — `onDiscard: (() -> Void)?` (nil = no button) drawing D10's button below the six rows; (4) enrollment-home — `showsScheduleEditing: Bool = true` (false hides "Edit schedule" and the calendar glyph, PROGRAM P10). Rejected: the app drawing these itself (d2m owns the views) | (assumed at spec) 2026-10-28 |
| D15 | Org filter | The feed takes `orgId` validated against `programListScope(userId)` (400 `orgId is not one of your organizations`, as `GET /api/programs`); options are `GET /api/organizations/my/organizations` plus "All Orgs" (no `orgId`). Rejected: single-org `getUserOrgId` (not multi-org) | (assumed at spec) 2026-10-28 |
| D16 | Row numbers | `progress` = completed (member, lesson) pairs ÷ (active members × non-removed lessons), 0 when either is 0, using `MemberLessonProgress.completedAt` on current versions as `getEnrollmentCompletionStats` does; the `complete` chip = `«members who completed every non-removed lesson»/«active members»`; enrolled date = `Enrollment.createdAt` as `MMM d, yyyy`. 100% renders C-059 `Complete` | (assumed at spec) 2026-10-28 |
| D17 | Ordering | Sections by their newest item's recency, newest first; rows by recency, newest first. An enrollment's recency = the latest of `createdAt` and its members' `MemberLessonProgress.lastUpdatedAt`/`MemberActivityProgress.lastUpdatedAt`/`MemberVideoProgress.lastWatchedAt`; a draft's = `updatedAt` | (assumed at spec) 2026-10-28 |
| D18 | Search | `q` (min 2 chars, the app debounces 300 ms) matches program name or group name, case-insensitive substring, across enrollments and drafts | (assumed at spec) 2026-10-28 |
| D19 | Draft lifecycle | Drafts never expire. FK `ON DELETE CASCADE` from group and program; a draft whose group or program is inactive is not listed and `GET`/`PATCH`/enroll return 404 for it. A draft's `n/6` and row states are computed by the app with the checklist's own rules (`EnrollChecklistMapper`), not by the server | (assumed at spec) 2026-10-28 |
| D20 | Detail read | One `GET /api/enrollments/:id/home` (§Contract) assembles program, group, leader, active member count, span, per-scheduled-day completion and lessons with activities; slide thumbnail = `youtubeThumbnailUrl`, else `video.thumbnailUrl`, else the first read block's `backgroundImageUrl`, else none. Day percent = members who completed that day's lesson ÷ active members. Day-card and lesson taps are inert; "Edit schedule" and the calendar glyph hidden (D14.4, PROGRAM P10) | (assumed at spec) 2026-10-28 |
| D21 | Draft ↔ checklist identity | A saved draft's server id (uuid) is the checklist's `flowId`; a checklist opened unsaved gets a local UUID and adopts the server id when D3's POST returns (the route is replaced in place, no visual change). `EnrollmentDraft` gains `serverId: String?` | (assumed at spec) 2026-10-28 |
| D22 | Fixtures | New layers `server/fixtures/screens/enrollments-home.ts` and `enrollment-home.ts`: enrollments active, upcoming and completed across ≥ 3 groups and 2 group creators; one with member progress spread over days; two drafts (one 2/6, one 5/6 with a past start date for D9); `fixtures/wipe.ts` clears `enrollment_drafts` | (assumed at spec) 2026-10-28 |

## Contract

All routes `requireAuth`; ids are uuids; errors `{success:false, error, message?}`; 404 for anything outside the caller's scope.

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/enrollment-drafts` | server | iphone | group in `groupManageFilter`, active; program in `programReadFilter`, active | `{groupId, studyProgramId}` + any of the PATCH fields | 201 `{success, draft}` (Draft shape) | 400 zod · 404 group/program · 409 `{error:"draft_exists", draftId}` |
| `GET /api/enrollment-drafts?groupId=` | server | iphone (group page) | as above, per draft | `groupId` required | `{success, drafts: Draft[]}` newest `updatedAt` first | 400 · 404 group |
| `GET /api/enrollment-drafts/:id` | server | iphone (resume) | draft's group in scope | — | `{success, draft}` | 404 |
| `PATCH /api/enrollment-drafts/:id` | server | iphone (autosave) | as GET | any subset: `groupId`, `studyProgramId`, `startDate` (`yyyy-MM-dd`\|null), `enabledDays` (`["Sun"…"Sat"]`\|null), `overriddenDates` (`yyyy-MM-dd[]`\|null), `scheduleDates` (`yyyy-MM-dd[]`\|null), `smsTime` (`HH:mm`\|null), `timezone`\|null, `syncMode` (`AUTO`\|`OFF`\|null), `lessonAccess` (`ONE_AT_A_TIME`\|`ALL_AT_ONCE`\|null) | `{success, draft}` | 400 · 404 · 409 `draft_exists` |
| `DELETE /api/enrollment-drafts/:id` | server | iphone (Discard) | as GET | — | `{success:true}` | 404 |
| `POST /api/enrollments` (extended) | server | iphone | as today | existing + `draftId?` | as today | as today (an unknown `draftId` is ignored) |
| `GET /api/enrollments-feed` (new) | server | iphone | per item: enrollments via `enrollmentManageFilter`, drafts via `groupManageFilter`; active groups/programs | `orgId?` (D15), `groupId?`, `leaderId?` (D13), `status?` `active\|upcoming\|completed\|draft\|all` (default `active`), `q?` (≥ 2), `tz?` (IANA, default UTC) | `{success, sections:[{group:{id,name,coverImageUrl,leader:{id,name}\|null}, items:[Item]}], options:{groups:[{id,name}], leaders:[{id,name}]}}` ordered per D17 | 400 (bad `status`/`tz`/`orgId`) |
| `GET /api/enrollments/:id/home` (new) | server | iphone | `enrollmentManageFilter` | `tz?` | `{success, home: Home}` | 404 |
| `GET /api/organizations/my/organizations`, `GET /api/enrollments/:id` (unchanged) | server | iphone | existing | — | existing | existing |

**Draft** = `{id, groupId, studyProgramId, startDate, enabledDays, overriddenDates, scheduleDates, smsTime, timezone, syncMode, lessonAccess, createdBy:{id,name}, createdAt, updatedAt}` (unset fields `null`).
**Item** = `{kind:"enrollment", id, studyProgram:{id,name,coverImageUrl}, startDate, endDate, enrolledAt, progress (0…1), completedMembers, memberCount, plannedMinutes, recencyAt}` or `{kind:"draft", draft: Draft, studyProgram:{id,name,coverImageUrl}, recencyAt}`.
**Home** = `{id, studyProgram:{id,name,description,coverImageUrl,authorName}, group:{id,name,leader:{id,name}|null}, memberCount, enrolledAt, startDate, endDate, lessonAccess, smsTime ("HH:mm"|null), timezone|null, days:[{scheduleId, date, percent (0…100), lessonCount, plannedMinutes}], lessons:[{scheduleId, dayNumber, title, date, progress (0…1)|null, activities:[{id, type, title, thumbnailUrl|null}]}]}`; `days`/`lessons` exclude removed schedules, ordered by date. `authorName` = the program creator's `User.name` (as `StudyProgramHomeMapper`'s `creatorName`); `dayNumber` = the schedule's 1-based position among the non-removed schedules by `scheduledDate` (`LessonSchedule` has no day column); `smsTime`/`timezone` = `Enrollment.smsTime`/`timezone` — the day card's second line (enrollment-home §2.4 "time"), null → empty line (align T5).

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `EnrollmentDraft` (`enrollment_drafts`): id uuid PK; `groupId` FK→groups CASCADE; `studyProgramId` FK→study_programs CASCADE; `startDate date?`; `enabledDays text?` (JSON, as Enrollment); `overriddenDates jsonb?`; `scheduleDates jsonb?`; `smsTime text?`; `timezone text?`; `syncMode EnrollmentSyncMode?`; `lessonAccess LessonAccess?`; `createdById` FK→users SET NULL; `updatedById?`; `createdAt`, `updatedAt`; UNIQUE(`groupId`,`studyProgramId`); index `groupId` | Draft | D2, D6, D19 | pending — T1 |
| SC2 | ADD | `/api/enrollment-drafts` POST/GET list/GET/PATCH/DELETE | Draft | D3–D6, D10 | pending — T2 |
| SC3 | EDIT | `POST /api/enrollments` | + `draftId?` | D11 | pending — T3 |
| SC4 | ADD | `GET /api/enrollments-feed` | Item, sections, options | D7, D8, D12, D13, D15–D18 | pending — T4 |
| SC5 | ADD | `GET /api/enrollments/:id/home` | Home | D20; enrollment-home `dayLine2s` (the invite time) → `smsTime`/`timezone`, `authorName`, `lessonNumbers` → `dayNumber` (align) | pending — T5 |

**Data plan:** SC1 is a new empty table — no backfill. `server/schema/schema.yaml` → schema diff → one
Atlas migration (house rules: `scripts/atlas.sh … --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`,
never `npm run schema:diff`). Undo = drop the table. SC2–SC5 are new or additive wire.

## server

- `prisma/schema.prisma` + `schema/schema.yaml`: SC1; `prisma generate` via `docker exec makeready-server`.
- New router `src/routes/enrollment-drafts.ts` mounted `app.use('/api', …)`: SC2. Every handler
  scopes through the draft's group with `groupManageFilter(userId)`; the active check covers group and
  program. `startDate`/`scheduleDates` validated as `yyyy-MM-dd`; `scheduleDates` ascending; pair
  change → 409 per D6 (catch Prisma `P2002`).
- `enrollments.ts` POST: `draftId: z.string().uuid().optional()`; delete per D11 after the welcome post.
- Feed + home in a service `src/services/enrollment-directory.service.ts` (raw SQL aggregates as
  `enrollment-analytics.service.ts` does — one query per concern, no per-enrollment fan-out); routes
  registered **before** `/enrollments/:id` (the feed path is distinct; `/:id/home` is a sub-path).
- Fixtures D22; `fixtures/wipe.ts` entry.

## iphone

- **Shell:** `UI2Section.enrollments` → `EnrollmentsHomeContainer`; new `UI2Destination.enrollmentHome(id:name:)` → `EnrollmentHomeContainer`; the TopNav `add` stays the checklist (ui2-enrollment-create).
- **Store:** `AppState.enrollmentFeed` (sections + options, keyed by the filter tuple), `enrollmentHomes[id]`, `enrollmentDraftsByGroupId[groupId]` — cache-first (R-27), disk-snapshotted like the other entity stores; `clearInMemory` clears them.
- **Actions:** `EnrollmentDraftActions` (create, load, update, delete, list by group) and `EnrollmentActions.loadFeed`, `loadHome`; `createEnrollment` gains `draftId`.
- **EnrollmentsHomeContainer** hosts `EnrollmentsHomeScreen`: search (300 ms, ≥ 2), the four C-036 menus (D8/D13/D15 options), the D14.1 draft labels, `.pageRefresh`, group arrow → `.groupDetail`, enrollment row → `.enrollmentHome`, draft row → `.enrollChecklist(flowId: draft.id)` after seeding the local draft from the Draft.
- **EnrollmentHomeContainer** hosts `EnrollmentHomeScreen` with `showsScheduleEditing: false`, lesson/activity taps no-op, `.pullDownRefresh`.
- **Checklist (existing containers):** D3 first save and D21 id adoption; D4 PATCH after each picker's Select (the six `EnrollSelect*Container` commit points); D6 409 → replace the route with the existing draft; D9 on open; D10 `onDiscard` + C-066 confirm; D11 `draftId` on Enroll.
- **Group page:** `GroupDetailContainer` loads `enrollmentDraftsByGroupId` and passes D14.2's arrays; a draft row → `.enrollChecklist`.
- **Draft model:** `EnrollmentDraft` gains `serverId`, `createdByName`; a `Draft` ↔ `EnrollmentDraft` mapper (dates `yyyy-MM-dd` in `TimeZone.current`, weekday names ↔ 0…6, access/sync wire forms as ui2-enrollment-create's table).

## Testing

**server**
- drafts: create (201; both ids required; 409 on an existing pair with `draftId`); list by group; get; PATCH each field incl. null-clears and 409 on pair move; DELETE; 404 for a group outside `groupManageFilter`, an inactive group or program; co-leader (role-held org) can read/patch/delete
- POST enrollments with `draftId` deletes the draft; without it, unchanged; a stale `draftId` is ignored
- feed: status buckets on fixed dates and a `tz`; drafts only under `draft`/`all`; `groupId`, `leaderId`, `orgId` (and its 400), `q`; ordering (D17); progress/complete/plannedMinutes numbers on a seeded enrollment; options lists
- home: span, `days` percents, lesson progress, removed schedules excluded, thumbnail fallback order; 404 out of scope
- migration applies clean; fixtures load and wipe

**iphone**
- mappers: feed → `EnrollmentsHomeScreen.State` (rows, draft labels `Draft · n/6`, hours format, chips), home → `EnrollmentHomeScreen.State`, Draft ↔ `EnrollmentDraft` round-trip
- checklist: first save only when both set; PATCH per Select; retry-then-banner; 409 replace; D9 stale clear; Discard confirm → delete → pop; `draftId` on Enroll
- route tests for `.enrollmentHome`; `clearInMemory` clears the new stores; `ios:build-check --test`; swiftlint baseline

**Cross-app verification script (Fixtures identity = org Owner, walk env)**
1. Home → Enrollments — sections by group, newest first; rows show bar, `complete`, hours, enrolled date; the status chip reads Active
2. Status → Upcoming, Completed, Draft, All — each shows only its rows; Draft shows the two fixture drafts marked `Draft · n/6` with who started them
3. Search "rom" — only matching programs/groups; Groups and Leaders menus narrow the list; All Orgs lists your orgs
4. Tap an active enrollment — detail shows cover, members, author, enrolled date, group leader, span, per-day completion, lessons; no Edit schedule or calendar glyph; back returns
5. Tap the 5/6 draft (past start) — the checklist opens with five rows restored except Schedule, which is to-do
6. From a group page, Enrollments + → pick a program → back out — the group page now lists that draft; the Enrollments list (Draft) shows it
7. Reopen it, set Schedule, invite time, sync, access — quit the app, relaunch, reopen — every row kept
8. Start another checklist for the same group + program — it switches to the existing draft
9. Discard enrollment → Keep editing (nothing happens) → Discard enrollment → confirm — back on the group page, the draft gone from both lists
10. Finish a draft and Enroll — "Group enrolled"; the list shows one enrollment row, no draft

## Out of scope

- Editing an enrollment's schedule (`enrollment-schedule-edit` undesigned); the detail's calendar view, day-card, lesson and activity taps (PROGRAM P10).
- Drafts on the web LeaderApp.
- Sending invite SMS (PROGRAM P6).
- Home dashboard followed-enrollment cards opening the detail page.
- The empty-group warning on the checklist's Group row — a separate follow-up to ui2-enrollment-create, in flight with d2m (change `cmvt0h9z80023v0736z822usp`), lands on main on its own.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | D14's four d2m inputs are handovers — the iPhone phase can't finish until d2m lands them | build-time risk — the first iPhone task requests all four and waits; a refused or reshaped input is a `/builder:revise` |
| F2 | d2m's enrollments-home / enrollment-home specs cite frames `3823:34548`, `3773:6944`, older than the owner's `4751:54665`, `4751:54817` (PROGRAM out-of-scope note) | build-time risk — the first iPhone task asks d2m for a drift check with D14's requests |
| F3 | `GET /api/enrollments/:id/completion-stats` scopes by single-org `getUserOrgId` — not reused; the feed and home use `enrollmentManageFilter` | settled by D15/D20 |
| F4 | `POST /api/enrollments` is not transactional, so D11's draft delete runs after the welcome post and is non-fatal | settled by D11 |
| F5 | `Enrollment.group._count.members` in `GET /api/enrollments/:id` counts inactive members; the home read counts active members only | settled by D20 |
| F6 | groups-detail derives its Enrollments quick stat and the section's «N» programs meta from `programTitles.count` (`GroupsDetailScreen.swift:318,536`), so draft rows added through D14.2 would be counted, against D7 | settled by T9 — the D14.2 request states both counts cover rows whose `programDraftLabels` entry is `""` only |
| F7 | The local `EnrollmentDraft.endDate` has no column in SC1 or field in Draft | settled — derived: `endDate` = the last `scheduleDates` entry when the mapper reads a Draft (T7); not stored, so D9's clear is `startDate` + `scheduleDates` only on the wire |
| T1 | server: `EnrollmentDraft` in `schema.yaml` + `schema.prisma`, the Atlas migration, `prisma generate` (SC1) | blocking |
| T2 | server: `src/routes/enrollment-drafts.ts` + its service — POST/GET list/GET/PATCH/DELETE, scope, 409 `draft_exists` (SC2) | blocking |
| T3 | server: `POST /api/enrollments` zod gains `draftId`, the non-fatal delete after the welcome post (SC3) | blocking |
| T4 | server: `enrollment-directory.service.ts` feed — sections, items, options, buckets, recency, numbers (SC4) | blocking |
| T5 | server: the same service's home read — incl. `smsTime`, `timezone`, `authorName`, derived `dayNumber` (SC5) | blocking |
| T6 | server: fixture layers `screens/enrollments-home.ts`, `screens/enrollment-home.ts`, `fixtures/wipe.ts` clears `enrollment_drafts` (D22) | blocking |
| T7 | iphone: the `Draft` Codable type + `EnrollmentDraft` (`serverId`, `createdByName`) mapper — dates `yyyy-MM-dd` in `TimeZone.current`, weekday names ↔ 0…6, `lessonAccess` `one-at-a-time`/`all-at-once` ↔ `ONE_AT_A_TIME`/`ALL_AT_ONCE`, `syncMode` `AUTO`\|`OFF`, `endDate` derived (F7); `AppState.enrollmentDraftsByGroupId` + `EnrollmentDraftActions` | trailing |
| T8 | iphone: `AppState.enrollmentFeed`, `enrollmentHomes[id]`, `EnrollmentActions.loadFeed`/`loadHome`, both containers and their mappers (day line 2 = `smsTime` formatted `h:mma` lower-case, `7:30am`) | trailing |
| T9 | iphone: the four D14 `request_project_change` handovers, with F6's count rule in the groups-detail request and F2's drift check | trailing |
| T10 | iphone: checklist autosave (D3/D4), 409 replace (D6), stale start (D9), Discard (D10), `draftId` on Enroll (D11), group page draft rows (D7b) | trailing |

## Prototype

Ref `--ui2 enrollments-home, enrollment-home, groups-enroll-program, groups-detail` (manifest `ui2:`).
All four are **built** d2m screens under `iphone/MakeReadyUI/Screens/` (`Enrollments/EnrollmentsHomeScreen.swift`,
`Enrollments/EnrollmentHomeScreen.swift`, `Groups/GroupsEnrollProgramScreen.swift`, `Groups/GroupsDetailScreen.swift`);
their `State` structs and `populated` fixtures are the harvested payloads. No owner notes on any of them
(`node capture/lib/ui2-notes.mjs read <screen>`, 2026-10-28: `exists: false` ×4). D14's inputs are not built yet.

**Alignment (2026-10-28)** — every rendered input traced to its column and wire field. 19 input groups: 10 ALIGNED,
8 derived or app-only (each settled by a named ruling or finding), 1 MISSING → T5.

| Screen input | Source | Wire | Verdict |
|---|---|---|---|
| draft `groupId`, `studyProgramId`, `startDate`, `enabledDays`, `overriddenDates`, `scheduleDates`, `smsTime`, `timezone` | SC1 columns | Draft | ALIGNED (dates `yyyy-MM-dd`, weekdays names ↔ 0…6 — layer transform, T7) |
| draft `lessonAccess`, `syncMode` | SC1 enums `LessonAccess`, `EnrollmentSyncMode` | `ONE_AT_A_TIME`\|`ALL_AT_ONCE`, `AUTO`\|`OFF` | ALIGNED (app `one-at-a-time` ↔ wire, T7; the column's `APPROVAL` member is never sent — the checklist offers two) |
| draft `endDate` | — | — | derived from `scheduleDates` (F7) |
| draft `phase` | — | — | app-only, transient (`processing`/`enrolled` never persist) |
| enrollments-home `groupNames` · `groupLeaderNames` · `groupPhotoURLs` | `Group.name` · `Group.creator.name` (D13) · `Group.coverImageUrl` | `sections[].group` | ALIGNED |
| `programTitles` · `programCoverURLs` · `programEnrolledDates` | `StudyProgram.name` · `.coverImageUrl` · `Enrollment.createdAt` | Item | ALIGNED |
| `programProgress` · `programCompleteCounts` · `programHours` | progress tables · `LessonSchedule.estimatedMinutes` | `progress`, `completedMembers`, `plannedMinutes` | derived (D16, D12) |
| filter labels ×4 | `options`, `organizations/my/organizations`, D8 | feed `options` | ALIGNED |
| D14.1 `programDraftLabels` · `programDraftStarters` | app (`EnrollChecklistMapper`, D19) · `EnrollmentDraft.createdById` → `User.name` | Draft `createdBy` | derived · ALIGNED |
| enrollment-home `coverURL` · `programName` · `programDescription` · `authorName` | `StudyProgram.coverImageUrl` · `.name` · `.description` · `.creator.name` | Home `studyProgram` | ALIGNED |
| `memberCount` · `enrolledLabel` · `leaderName` | active `GroupMember` count (F5) · `Enrollment.createdAt` · `Group.creator.name` | Home | ALIGNED |
| start/end month·weekday·day, `spanMonths`/`spanDays` | `Enrollment.startDate`/`endDate` | Home | ALIGNED · span derived in the mapper |
| day `dates`, `dayPercents`, `dayLine1s` | `LessonSchedule.scheduledDate` · progress · count per date | `days[]` | ALIGNED · derived (D20) |
| `dayLine2s` (the invite time) | `Enrollment.smsTime` | — | **MISSING** from Home → added (§Contract, T5) |
| `dayDateStates` · `lessonMetaLabels` | `date` vs today in the device zone | — | derived in the mapper |
| `lessonNumbers` · `lessonTitles` · `lessonProgress` | position by date · `LessonSchedule.title` · progress | `lessons[]` `dayNumber`, `title`, `progress` | derived · ALIGNED · derived |
| `lessonSlideImages` · `lessonSlideLabels` | `ScheduledLessonActivity.youtubeThumbnailUrl` → `Video.thumbnailUrl` → first `ActivityReadBlock.backgroundImageUrl` · `type` + `title` | `activities[]` | ALIGNED (D20 order) |
| groups-detail Enrollments rows + D14.2 arrays | existing `GET /api/groups/:id/enrollments` + `GET /api/enrollment-drafts?groupId=` | existing · Draft | ALIGNED; counts per F6 |
| groups-enroll-program rows (group, program, schedule, invite time, sync, access) | the draft fields above | Draft | ALIGNED (ui2-enrollment-create's mapper) |

**Released build:** iphone is `released_artifact`; every change is additive (new routes, an optional `draftId`, new
Home fields on a new route) — nothing a shipped 1.0 build caches changes shape.
