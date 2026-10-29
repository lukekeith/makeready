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
[3] `grep -rln prisma.enrollment.find server/src` [4] `server/src/services/permission.ts:335,348,365`; `study-program.service.ts:53,129`
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
the web LeaderApp's enroll (`client/…/leader-enrollment-flow.store.ts:158`) posts without `draftId` (D24); nothing else reads `EnrollmentDraft`.

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
| D2 | Draft storage | New table `enrollment_drafts` (§Schema SC1): `groupId`, `studyProgramId` required; every other checklist field nullable; `createdById`, `updatedById`, timestamps. Enroll creates the `Enrollment` from the checklist and deletes the draft (D11). Supersedes ui2-enrollment-create D13 (memory-only draft) and design OQ-004 (Back discards) once a draft is saved: Back then ends the local flow only and the server draft stays; the shell's prune never DELETEs. Rejected: a DRAFT status on `Enrollment` (16 readers would each have to skip drafts; one miss leaks) | Luke 2026-10-28 |
| D3 | When a draft is saved | The first `POST /api/enrollment-drafts` fires the moment the checklist holds both a group and a study program (whichever is picked second — `EnrollEntry.open` preloads one side at most). Before that nothing is stored, and Back loses the checklist as today. Rejected: saving from the first pick (a draft with no program can't be listed by program) | Luke 2026-10-28 |
| D4 | Autosave | After the draft exists, every picker Select that changes the draft (group, program, schedule, invite time, sync, access) sends one `PATCH` with the changed fields; a program change also sends `scheduleDates: null` (the local `setProgram` cascade clears the schedule; `startDate`, `enabledDays`, `overriddenDates` kept). At most one request is in flight per flow: changes made meanwhile coalesce into the next PATCH, and changes made before D3's POST returns are sent once it does. A failed PATCH keeps the value in the app, retries once after 2 s, and on a second failure surfaces the error banner "Couldn't save the draft" with Retry — once per dirty episode, superseded by D26; the checklist stays usable. Rejected: save on leaving the checklist (a quit or crash loses work); a Save draft button (undesigned, forgettable) | Luke 2026-10-28 |
| D5 | Who sees a draft | Every leader whose `groupManageFilter(userId)` admits the draft's group can list, read, update, enroll and delete it; others get 404. Rejected: creator only (co-leaders can't pick it up; duplicates) | Luke 2026-10-28 |
| D6 | One draft per pair | Unique `(groupId, studyProgramId)`. `POST` for an existing pair returns 409 `draft_exists` with `draftId`; a `PATCH` that would move a draft onto a pair another draft holds returns the same 409 and changes nothing. On 409 the app GETs `/enrollment-drafts/:draftId` and re-seeds THIS flow in place — `serverId` = that id, every field overwritten from it, phase `checklist`, no navigation (this checklist's unsaved rows dropped; the draft being edited, if any, keeps its old pair on the server). Rejected: offering open-or-new (allows duplicates); allowing duplicates silently | Luke 2026-10-28 |
| D7 | Where drafts show | (a) Enrollments section: a draft sits in its group's section as a row marked `Draft · n/6` with `Started by «name»` in place of progress, completed, hours and enrolled date; (b) group page Enrollments section: drafts listed after the enrollments, same marker; (c) a draft row tap pushes the checklist for that draft; (d) a section's C-058 arrow pushes `.groupDetail` (OQ-enrollments-home-5). The group page's Enrollments stat and count chip count enrollments only. Rejected: a pinned Drafts block on the list (undesigned layout) | Luke 2026-10-28 (stat: assumed at brainstorm) |
| D8 | Status filter | Options, in order: Active (startDate ≤ today ≤ endDate) · Upcoming (startDate > today) · Completed (endDate < today) · Draft · All. Resting value Active. Drafts appear under Draft and All only. An enrollment's start/end date = `localDate(startDate|endDate, enrollment.timezone ?? 'UTC')` (`server/src/utils/timezone.ts:16`); "today" = `todayInTimezone(tz)` with the request's `tz` (device zone). Rejected: Active/Completed only (hides enrollments that have not started yet) | Luke 2026-10-28 (PROGRAM P9 + drafts) |
| D9 | Stale start date on resume | When a draft is opened and its first `scheduleDates` entry is before today (device zone), the schedule counts as not done: the app clears `startDate`, `scheduleDates`, `endDate` in the local draft and (D23: no request on open) keeps `enabledDays` and `overriddenDates` as the picker's seed, and the picker opens on today. Every other row keeps its value. The list's and group page's `n/6` apply the same stale rule (a stale schedule counts not done). The clear is local only, with no PATCH on open (D23). Rejected: shifting dates automatically (unseen dates enrolled); failing at Enroll (dead end at the last step) | Luke 2026-10-28 |
| D10 | Discard enrollment | A C-048 `PageActionButton` "Discard enrollment", destructive role, at the bottom of the checklist, shown while the checklist is backed by a saved draft and its phase is `checklist`. Tap → C-066 action menu with one destructive row "Discard enrollment" (D29). Confirm → `DELETE /api/enrollment-drafts/:id`, end the local draft, pop to the page that pushed the checklist; failure → banner "Couldn't discard the draft" with Retry, page stays. Rejected: always shown (one button, two meanings before a draft exists); no confirm (accidental loss of shared work) | Luke 2026-10-28 |
| D11 | Enroll from a draft | The checklist sends `draftId` with `POST /api/enrollments`. After the enrollment and its welcome post are created the server deletes that draft with `deleteMany({ id: draftId, groupId: body.groupId, studyProgramId: body.studyProgramId })` in its own try/catch (log only, the 200 stands), placed after the step try/catch closes (`enrollments.ts:441`), never inside it — that catch deletes the enrollment. Drafts of the pair when no `draftId` is sent: D24. The app removes the draft from its store on 200. Rejected: the app deleting the draft after the POST (a crash between leaves a draft beside its enrollment) | (assumed at spec) 2026-10-28 |
| D12 | Hours on a row | Planned study time: the sum of the enrollment's non-removed `LessonSchedule.estimatedMinutes` ÷ 60, shown with at most one decimal and no trailing `.0` (`12`, `1.5`); a null minute counts 0. Rejected: member time spent (only video watch time is recorded, undercounts); hiding it | Luke 2026-10-28 |
| D13 | Leader | "Leader" means the group's creator (`Group.creatorId`): the Leaders filter lists the creators of the groups in the feed; the detail page's "Group leader" shows that user's name. Rejected: the enrollment's creator (the label says Group leader) | Luke 2026-10-28 |
| D14 | d2m screen inputs | Four existing d2m screens gain inputs with defaults (no new screen; requested through `request_project_change` at the iPhone phase's start, each a handover the build waits on): (1) enrollments-home — per-row `programDraftLabels: [String]` (`""` = an enrollment row; non-empty = draft row showing that label and `programDraftStarters[row]` instead of the three chips and the bar); remove the screen's own C-019 nav row — the shell draws TopNav — and pin the header with `.pinnedBelowTopNav()` + `onSearchActiveChange`, as members-home; (2) groups-detail — the same two arrays on its Enrollments rows: a draft row shows `programDraftLabels[i]` in place of the enrolled chip and `programDraftStarters[i]` in place of the description; the Enrollments quick stat and the section's «N» meta count only rows whose label is `""` (F6); (3) groups-enroll-program — `onDiscard: (() -> Void)?` (nil = no button) drawing D10's button below the six rows, and a public `static func completedSteps(_ state: State) -> Int` (the screen's own done rule, used for `n/6`, D19); requested after change `cmvt0h9z80023v0736z822usp` lands on the same file; (4) enrollment-home — `showsScheduleEditing: Bool = true` (false hides "Edit schedule" and the calendar glyph, PROGRAM P10), plus `showsHeader: Bool = true`, `loading: Bool = false`, `failed: Bool = false`, `onRetry` (as study-program-home). Every new State field is defaulted, so the memberwise inits in `MakeReadyCaptureTests/ViewRegistry.swift` keep compiling; d2m updates those cases. Rejected: the app drawing these itself (d2m owns the views) | (assumed at spec) 2026-10-28 |
| D15 | Org filter | The feed takes `orgId` validated against `getManageableOrgIds(userId)` (`permission.ts:305`; 400 `orgId is not one of your organizations`, the message of `programs.ts:445`); options are `data[]` of `GET /api/organizations/my/organizations` plus "All Orgs" (no `orgId`); the no-`orgId` scope for super admins is D25. Rejected: single-org `getUserOrgId` (not multi-org) | (assumed at spec) 2026-10-28 |
| D16 | Row numbers | `progress` = Σ over non-removed schedules of DISTINCT members with `MemberLessonProgress.completedAt` not null who are ACTIVE `GroupMember`s of the enrollment's group, ÷ (active members × non-removed schedules), 0 when either is 0; lesson completion is not version-filtered (a pinned completion counts) — `getEnrollmentCompletionStats` is not copied, it counts ex-members and can exceed 1; the `complete` chip = `«members who completed every non-removed lesson»/«active members»`; enrolled date = `Enrollment.createdAt` as `MMM d, yyyy`. 100% renders C-059 `Complete` | (assumed at spec) 2026-10-28 |
| D17 | Ordering | Sections by their newest item's recency, newest first; rows by recency, newest first. An enrollment's recency = the latest of `createdAt` and its members' `MemberLessonProgress.lastUpdatedAt`/`MemberActivityProgress.lastUpdatedAt`/`MemberVideoProgress.lastWatchedAt`; a draft's = `updatedAt` | (assumed at spec) 2026-10-28 |
| D18 | Search | SUPERSEDED by D27 2026-10-28 — was: `q` (min 2 chars, the app debounces 300 ms) matches program name or group name, case-insensitive substring, across enrollments and drafts | (assumed at spec) 2026-10-28 |
| D19 | Draft lifecycle | Drafts never expire. FK `ON DELETE CASCADE` from group and program; a draft whose group or program is inactive is not listed and `GET`/`PATCH`/enroll return 404 for it; such rows are retained (soft delete never cascades) and unreachable. A draft's `n/6` = `GroupsEnrollProgramScreen.completedSteps(EnrollChecklistMapper.state(…))` (D14.3) with the D9 stale rule, group/program resolved from AppState stores and falling back to the feed's names; never computed by the server | (assumed at spec) 2026-10-28 |
| D20 | Detail read | One `GET /api/enrollments/:id/home` (§Contract) assembles program, group, leader, active member count, span, per-scheduled-day completion and lessons with activities; slide thumbnail = `youtubeThumbnailUrl`, else `video.thumbnailUrl`, else the first read block's `backgroundImageUrl`, else none. `days` = one entry per distinct local date (D8's `localDate`), `scheduleId` = that date's first schedule; day `percent` = active members who completed EVERY non-removed schedule on that date ÷ active members × 100, rounded; `lessons[]` = every non-removed schedule by date (OQ-enrollment-home-7), `progress` null only when there are no active members; activities = the schedule's current version (`filterActivitiesToVersion`), thumbnail = `activityThumbnailUrl()` (`next-study-thumbnail.ts:13`, the order above). Zero schedules render the built `empty-schedule` state (OQ-enrollment-home-8); the span is static (OQ-5). Active-member rule as D16. Day-card and lesson taps are inert; "Edit schedule" and the calendar glyph hidden (D14.4, PROGRAM P10) | (assumed at spec) 2026-10-28 |
| D21 | Draft ↔ checklist identity | `flowId` is always a local UUID for the flow's life; `EnrollmentDraft.serverId: String?` links it to the server row (set when D3's POST or a resume returns). A list or group-page draft tap reuses an open flow whose `serverId` matches, else starts a new flow seeded from the Draft. Routes never change. Rejected: adopting the server id as `flowId` (`EnrollmentDraft.id` is `let`, `replaceTop` works only on the top entry, and a path swap rebuilds the view — `UI2ShellModel.swift:127`) | (assumed at spec) 2026-10-28 |
| D22 | Fixtures | New layers `server/fixtures/screens/enrollments-home.ts` and `enrollment-home.ts`: enrollments active, upcoming and completed across ≥ 3 groups and 2 group creators; one with member progress spread over days; two drafts (one 2/6; one 6/6 whose first `scheduleDates` entry is past, reading 5/6 under D9) under a new fixture id kind `enrollmentDraft: '001b'` (`fixtures/ids.ts`); reset clears them by the group cascade (`wipe.ts:29`) — `wipe.ts` unchanged; no new users (base has two group creators) | (assumed at spec) 2026-10-28 |
| D23 | Stale start on open (D9) | Opening a draft whose first `scheduleDates` entry is before today (device zone) clears `startDate`, `scheduleDates` and the derived `endDate` in the LOCAL draft only and sends no request; the server row keeps its schedule until the leader's next Schedule Select, whose PATCH carries the new values (D4). The list, the group page and the checklist each apply D9's stale rule on read. Rejected: PATCH nulls on open (a read that writes — a co-leader who only looks, possibly in another zone, would null a shared draft's schedule; last write wins) | auto (recommended) 2026-10-28 |
| D24 | Enroll of a drafted pair without `draftId` | `POST /api/enrollments`, after the step try/catch closes (D11's placement), runs `enrollmentDraft.deleteMany({ where: { groupId: body.groupId, studyProgramId: body.studyProgramId } })` in its own try/catch (log only, the 200 stands) whether or not `draftId` is sent; a `draftId` of another pair or an unknown one deletes nothing beyond that pair. Covers the web LeaderApp and 1.0 iPhone (never send `draftId`) and a stale `draftId`. Rejected: delete only the sent `draftId` (a web or 1.0 enroll leaves an orphan draft beside its enrollment) | auto (recommended) 2026-10-28 |
| D25 | Feed scope with no `orgId`, and size | With no `orgId`, every caller — super admins included — sees groups whose `organizationId` is in `getManageableOrgIds(userId)` plus groups with `creatorId = userId`; a super admin's platform-wide reach applies only with an explicit `orgId`: for a super admin any existing organization's id is accepted (one that does not exist → D15's 400), for everyone else `orgId` is validated against `getManageableOrgIds` per D15 (clarified at plan 2026-10-29 — `getManageableOrgIds` holds only owned/role orgs, so D15's check alone would block the reach D25 grants). Each response carries at most 200 items across all sections: items are ranked by D17 recency and the lowest are dropped before sectioning. Rejected: `groupManageFilter`'s `{}` for super admins (every enrollment on the platform, unbounded aggregates) | auto (recommended) 2026-10-28 |
| D26 | Autosave offline | Supersedes D4's failure clause: a PATCH that fails (non-404) retries once after 2 s; on the second failure the flow is marked dirty, and the banner "Couldn't save the draft" with Retry shows once per dirty episode per flow (not again for each later Select while still dirty). While dirty, every later Select coalesces its fields with the unsent ones, and the next Select or Retry re-sends them all in one PATCH; Enroll sends no PATCH — it cancels any pending PATCH or retry (D30) and POSTs with `draftId`, since the enrollment is built from the checklist and the pair's drafts are deleted (D24); a successful PATCH clears dirty. The checklist stays fully usable offline. Rejected: D4 as written (offline, every Select raises a banner) | auto (recommended) 2026-10-28 |
| D27 | Search | Supersedes D18: the iPhone never sends `q`; search is the built screen's local filter (`EnrollmentsHomeScreen.swift:304` — case-insensitive substring of program name or group name over the rows already loaded); the feed has no `q` parameter (an unknown query param is ignored, not a 400). Rejected: D18's server `q` (a cache entry per query, and a server match rule that could disagree with the screen's local one) | auto (recommended) 2026-10-28 |
| D28 | Group-page enrollment-row taps | `GroupDetailContainer` passes `onOpenEnrollment`: a row whose `programDraftLabels` entry is `""` pushes `.enrollmentHome(id:name:)` for that enrollment; a draft row (non-empty label, after the enrollments) pushes `.enrollChecklist(flowId:)` per D21. Rejected: leaving enrollment rows inert (the screen's designed C-059 → enrollment-home tap stays dead) | auto (recommended) 2026-10-28 |
| D29 | Discard confirm rows | Supersedes D10's row list: the C-066 action menu has exactly one row, "Discard enrollment", `tone: .destructive`; the menu's Done dismisses it and keeps editing (no request). Precedent: groups-edit D14 delete (`GroupDetailContainer.swift:177`). Rejected: two rows "Discard enrollment" + "Keep editing" (duplicates Done) | auto (recommended) 2026-10-28 |
| D30 | Draft gone | A `GET`, `PATCH` or `DELETE` 404 for a draft ends its local flow, removes it from `enrollmentFeed` and `enrollmentDraftsByGroupId`, shows the banner "This draft no longer exists" and pops the checklist; Discard and Enroll cancel any pending PATCH or retry; **Back does not** (superseded in part 2026-10-29, final review — D2's "the server draft stays" outranks it): Back ends the local flow only after the pending create/PATCH (and its one retry) has settled, so the last Select before Back is saved; a 404 after the phase leaves `checklist` is silent. Rejected: retry-then-banner on a 404 (a just-enrolled draft would show "Couldn't save the draft") | audit 2026-10-28 |

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
| `GET /api/enrollments-feed` (new) | server | iphone | enrollments and drafts whose group matches `groupManageFilter(userId)` (the group page's scope; no-`orgId` scope D25); active groups/programs | `orgId?` (D15), `groupId?`, `leaderId?` (D13), `status?` `active\|upcoming\|completed\|draft\|all` (default `active`), `tz?` (IANA, default UTC) | `{success, sections:[{group:{id,name,coverImageUrl,leader:{id,name}\|null}, items:[Item]}], options:{groups:[{id,name}], leaders:[{id,name}]}}` ordered per D17 | 400 (bad `status`/`tz`/`orgId`) |
| `GET /api/enrollments/:id/home` (new) | server | iphone | `enrollmentManageFilter` | `tz?` | `{success, home: Home}` | 404 |
| `GET /api/organizations/my/organizations`, `GET /api/enrollments/:id` (unchanged) | server | iphone | existing | — | existing | existing |

**Draft** = `{id, groupId, studyProgramId, startDate, enabledDays, overriddenDates, scheduleDates, smsTime, timezone, syncMode, lessonAccess, createdBy:{id,name}|null, createdAt, updatedAt}` (unset fields `null`; `createdBy` null once its user is deleted — the app shows no starter).
`options` are computed over scope + `orgId` + `status`, never narrowed by `groupId` or `leaderId`. No `q` (D27). Every date in Item and Home (`startDate`, `endDate`, `days[].date`, `lessons[].date`) is `yyyy-MM-dd` in the enrollment's own zone (D8); `enrolledAt`, `recencyAt` are ISO instants.
**Item** = `{kind:"enrollment", id, studyProgram:{id,name,coverImageUrl}, startDate, endDate, enrolledAt, progress (0…1), completedMembers, memberCount, plannedMinutes, recencyAt}` or `{kind:"draft", draft: Draft, studyProgram:{id,name,coverImageUrl}, recencyAt}`.
**Home** = `{id, studyProgram:{id,name,description,coverImageUrl,authorName}, group:{id,name,leader:{id,name}|null}, memberCount, enrolledAt, startDate, endDate, lessonAccess, smsTime ("HH:mm"|null), timezone|null, days:[{scheduleId, date, percent (0…100), lessonCount, plannedMinutes}], lessons:[{scheduleId, dayNumber, title, date, progress (0…1)|null, activities:[{id, type, title, thumbnailUrl|null}]}]}`; `days`/`lessons` exclude removed schedules, ordered by date. `authorName` = the program creator's `User.name` (as `StudyProgramHomeMapper`'s `creatorName`); `dayNumber` = the schedule's 1-based position among the non-removed schedules by `scheduledDate` (`LessonSchedule` has no day column); `smsTime`/`timezone` = `Enrollment.smsTime`/`timezone` — the day card's second line (enrollment-home §2.4 "time"), null → empty line (align T5).

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `EnrollmentDraft` (`enrollment_drafts`): id uuid PK; `groupId` FK→groups CASCADE; `studyProgramId` FK→study_programs CASCADE; `startDate string?` (`yyyy-MM-dd` — the YAML has no `date` type); `enabledDays json?` (the wire `["Sun"…]` array, not Enrollment's varchar-JSON); `overriddenDates json?`; `scheduleDates json?`; `smsTime string?`; `timezone string?`; `syncMode enum EnrollmentSyncMode?`; `lessonAccess enum LessonAccess?`; `createdById` FK→users SET NULL (`EnrollmentDraftCreator`); `updatedById` FK→users SET NULL (`EnrollmentDraftUpdater`); `createdAt`, `updatedAt`; UNIQUE(`groupId`,`studyProgramId`) (its leading column serves `groupId` lookups — no separate index); inverse relations on Group, StudyProgram, User | Draft | D2, D6, D19 | landed — migration 20261029050528_enrollment_drafts (339c21a) |
| SC2 | ADD | `/api/enrollment-drafts` POST/GET list/GET/PATCH/DELETE | Draft | D3–D6, D10 | landed — c48be97 |
| SC3 | EDIT | `POST /api/enrollments` | + `draftId?` | D11 | landed — e5fe855, 8b45314 |
| SC4 | ADD | `GET /api/enrollments-feed` | Item, sections, options | D7, D8, D12, D13, D15–D18 | landed — 0ff9d84 |
| SC5 | ADD | `GET /api/enrollments/:id/home` | Home | D20; enrollment-home `dayLine2s` (the invite time) → `smsTime`/`timezone`, `authorName`, `lessonNumbers` → `dayNumber` (align) | landed — 5601c49 |

**Data plan:** SC1 is a new empty table — no backfill. `server/schema/schema.yaml` → `npm run schema:generate`
(tsx, no dotenv) regenerates `schema.prisma` + `atlas/.schema.hcl` → `cd server/atlas && ../scripts/atlas.sh migrate diff --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`
→ one migration (never `npm run schema:diff`, which reads the 1Password `.env`). Independent of SC2–SC5. Undo = drop the table. SC2–SC5 are new or additive wire.

## server

- `schema/schema.yaml` only (`schema.prisma` is generated — never edited): SC1, then the Data plan's commands; `prisma generate` via `docker exec makeready-server`; a migration-SQL test modelled on `test/enrollment-lesson-access-migration.test.ts`.
- New router `src/routes/enrollment-drafts.ts` mounted `app.use('/api', …)`: SC2. Every handler
  scopes through the draft's group with `groupManageFilter(userId)`; the active check covers group and
  program. Bodies are `z.object({...}).strict()` (unknown field = 400), each field `.nullable().optional()`, written only when the key is present;
  `startDate`/`scheduleDates` `yyyy-MM-dd`, `scheduleDates` strictly ascending (count and not-before-today are Enroll's checks, never the draft's);
  `timezone` via `isValidTimezone`. A PATCH changing `groupId` re-checks the NEW group with `findManageableGroup`, one changing `studyProgramId` re-checks
  `{isActive:true, ...programReadFilter}` — a miss is 404, nothing changes. POST and PATCH catch P2002 (`isUniqueViolation`, `services/member.ts:272`),
  re-read the pair's draft through the scope and return 409 per D6.
- `enrollments.ts` POST: `draftId: z.string().uuid().optional()`; delete per D11/D24 after the step try/catch.
- Feed + home in a service `src/services/enrollment-directory.service.ts` (raw SQL aggregates as
  `enrollment-analytics.service.ts` does — one query per concern, no per-enrollment fan-out); routes in
  the new router mounted `app.use('/api', …)` beside `enrollmentsRoutes` (`index.ts:462`) — no ordering constraint (Express matches whole segments).
- Fixtures D22 (`wipe.ts` unchanged) and a layer test under `fixtures/__tests__`.

## iphone

- **Shell:** `UI2Section.enrollments` → `EnrollmentsHomeContainer`; new `UI2Destination.enrollmentHome(id:name:)` → `EnrollmentHomeContainer`; the TopNav `add` stays the checklist (ui2-enrollment-create).
- **Store:** `AppState.enrollmentFeed` (sections + options, keyed by the filter tuple), `enrollmentHomes[id]`, `enrollmentDraftsByGroupId[groupId]` — cache-first within the session (R-27), memory-only like every UI2 store (`AppState.swift:141-164`; never in `PersistedState`); `clearInMemory` clears them.
- **Actions:** `EnrollmentDraftActions` (create, load, update, delete, list by group) and `EnrollmentActions.loadFeed`, `loadHome`; `createEnrollment` gains `draftId`. Draft create/update/delete and `createEnrollment(draftId:)` update `enrollmentDraftsByGroupId[gid]` (both groups on a group change) and drop or re-fetch `enrollmentFeed` in the same call; Actions return Void.
- **EnrollmentsHomeContainer** hosts `EnrollmentsHomeScreen`: search = the screen's local filter (D27), the four C-036 menus (D8/D13/D15 options), the D14.1 draft labels, `.pageRefresh`, group arrow → `.groupDetail`, enrollment row → `.enrollmentHome`, draft row → `.enrollChecklist(flowId:)` per D21 — seeded from the feed's Draft, then `GET /enrollment-drafts/:id` and re-seeded when its `updatedAt` is newer (404 → D30).
- **EnrollmentHomeContainer** hosts `EnrollmentHomeScreen` with `showsScheduleEditing: false`, lesson/activity taps no-op, `.pullDownRefresh`.
- **Checklist (existing containers):** D3 first save and D21 id adoption; D4 PATCH after each picker's Select (the six `EnrollSelect*Container` commit points); D6 409 → re-seed in place; D30 404; D9 on open; D10 `onDiscard` + C-066 confirm (D29); D11 `draftId` on Enroll.
- **Group page:** `GroupDetailContainer` loads `enrollmentDraftsByGroupId` and passes D14.2's arrays; a draft row → `.enrollChecklist` (D21); enrollment rows per D28.
- **Draft model:** `EnrollmentDraft` gains `serverId`, `createdByName`; a `Draft` ↔ `EnrollmentDraft` mapper (dates `yyyy-MM-dd` in `TimeZone.current`, weekday names ↔ 0…6, access/sync wire forms as ui2-enrollment-create's table).

## Testing

**server**
- drafts: create (201; both ids required; 409 on an existing pair with `draftId`); list by group; get; PATCH each field incl. null-clears and 409 on pair move; DELETE; 404 for a group outside `groupManageFilter`, an inactive group or program; co-leader (role-held org) can read/patch/delete
- POST enrollments with `draftId` deletes the draft; without it, unchanged; a stale `draftId` is ignored
- feed: status buckets on fixed dates and a `tz`; drafts only under `draft`/`all`; `groupId`, `leaderId`, `orgId` (and its 400); ordering (D17); progress/complete/plannedMinutes numbers on a seeded enrollment; options lists
- home: span, `days` percents, lesson progress, removed schedules excluded, thumbnail fallback order; 404 out of scope
- PATCH `groupId` to an out-of-scope or inactive group, `studyProgramId` to an unreadable program → 404, nothing changed; concurrent POST → one 201, one 409; `.strict()` 400 on an unknown field; absent vs null; invalid `timezone` 400
- a `draftId` of another pair is not deleted; a failed delete keeps the 200; D24's pair delete; `createdBy` null after its user is deleted
- an ex-member's completion doesn't count and progress stays ≤ 1; bucket boundaries with an enrollment `timezone` ≠ `tz`; two schedules on one date; `options` unaffected by `groupId`/`leaderId`; `orgId` against `getManageableOrgIds`; D25 cap
- the migration-SQL test; a fixture layer test asserting the two drafts and the status-bucket counts

**iphone**
- mappers: feed → `EnrollmentsHomeScreen.State` (rows, draft labels `Draft · n/6`, hours format, chips), home → `EnrollmentHomeScreen.State`, Draft ↔ `EnrollmentDraft` round-trip
- checklist: first save only when both set; PATCH per Select; retry-then-banner once per dirty episode and re-send on the next Select/Retry/Enroll (D26); 409 replace; D9 stale clear; Discard confirm → delete → pop; `draftId` on Enroll
- PATCH ordering and coalescing; changes before the POST returns; the program-change PATCH's `scheduleDates: null`; 409 on a PATCH while a picker is on top; 404 on GET/PATCH/DELETE and pending-PATCH cancel on Enroll/Discard, while Back lets the pending create/PATCH settle (D30 as superseded 2026-10-29)
- feed and group-draft store refresh after create, delete and enroll; list `n/6` equals the checklist's count incl. the stale rule
- route tests for `.enrollmentHome`; `clearInMemory` clears the new stores; `ios:build-check --test`; swiftlint baseline

**Cross-app verification script (Fixtures identity = org Owner, walk env)**
1. Home → Enrollments — one TopNav (the shell's), sections by group, newest first; rows show bar, `complete`, hours, enrolled date; the status chip reads Active
2. Status → Upcoming, Completed, Draft, All — each shows only its rows; Draft shows the two fixture drafts marked `Draft · n/6` with who started them
3. Search "rom" — only matching programs/groups; Groups and Leaders menus narrow the list; All Orgs lists your orgs
4. Tap an active enrollment — detail shows cover, members, author, enrolled date, group leader, span, per-day completion, lessons; no Edit schedule or calendar glyph; back returns
5. Tap the past-start draft (listed 5/6) — the checklist opens with five rows restored and Schedule to-do
6. From a group page, Enrollments + → pick a program → back out — the group page now lists that draft; the Enrollments list (Draft) shows it
7. Reopen it, set Schedule, invite time, sync, access — quit the app, relaunch, reopen — every row kept
8. Start another checklist for the same group + program — it switches to the existing draft
9. Discard enrollment → dismiss the menu (nothing happens) → Discard enrollment → confirm — back on the group page, the draft gone from both lists
10. Finish a draft and Enroll — "Group enrolled"; the list shows one enrollment row, no draft

## Out of scope

- Editing an enrollment's schedule (`enrollment-schedule-edit` undesigned); the detail's calendar view, day-card, lesson and activity taps (PROGRAM P10).
- Drafts on the web LeaderApp.
- Design OQs with no build effect: OQ-enrollments-home-3 and OQ-enrollment-home-3 (banding — the built C-057 renders as is), OQ-enrollment-home-2, -4, -6 (frame drift); the loading state of enrollments-home is the built empty body under the header (OQ-enrollments-home-6). Decider: audit 2026-10-28 (auto).
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
| T6 | server: fixture layers `screens/enrollments-home.ts`, `screens/enrollment-home.ts`, fixture id kind `001b` (D22) | blocking |
| T7 | iphone: the `Draft` Codable type + `EnrollmentDraft` (`serverId`, `createdByName`) mapper — dates `yyyy-MM-dd` in `TimeZone.current`, weekday names ↔ 0…6, `lessonAccess` `one-at-a-time`/`all-at-once` ↔ `ONE_AT_A_TIME`/`ALL_AT_ONCE`, `syncMode` `AUTO`\|`OFF`, `endDate` derived (F7); `AppState.enrollmentDraftsByGroupId` + `EnrollmentDraftActions` | trailing |
| T8 | iphone: `AppState.enrollmentFeed`, `enrollmentHomes[id]`, `EnrollmentActions.loadFeed`/`loadHome`, both containers and their mappers (day line 2 = `smsTime` formatted `h:mma` lower-case, `7:30am`) | trailing |
| T9 | iphone: the four D14 `request_project_change` handovers (all of D14's items incl. the TopNav removal, `completedSteps`, enrollment-home's header/loading/failed inputs), F2's drift check, D14.3 after `cmvt0h9z80023v0736z822usp` lands | trailing |
| T10 | iphone: checklist autosave (D3/D4), 409 replace (D6), stale start (D9), Discard (D10), `draftId` on Enroll (D11), group page draft rows (D7b) | trailing |
| F8 | Audit corrections made in place (2026-10-28): schema via `schema.yaml` + `schema:generate`, SC1 types (no YAML `date`), D16 active-member rule (the analytics service counts ex-members), D8 local dates, Draft `createdBy` nullable, PATCH re-scope + P2002 on POST, D11 placement, D15 `getManageableOrgIds` + `data[]`, feed scope `groupManageFilter`, `options` not narrowed, D20 per-date days + current-version activities, `wipe.ts` unchanged, no route ordering, `.strict()` bodies, D21 identity, D6 re-seed in place, D4 ordering + program-change nulls, memory-only stores, Actions refresh derived stores, D14 inputs completed (TopNav, groups-detail row parts, `completedSteps`, enrollment-home header/loading/failed, defaulted fields), D22 6/6 stale draft, D2 supersedes create D13/OQ-004 | settled |
| F9 | `contract:` every correction above that touched §Contract (Draft `createdBy|null`, feed scope, `options`, date formats, Home `smsTime`/`timezone`) is additive or narrows a new route — no consumer exists yet | settled — pass 2 (scoped to those rows): each re-traced to its one consumer, iphone — `createdBy` null → starter `""` (T7); Home's `enrollmentManageFilter` ⊇ the feed's `groupManageFilter`, so every feed row opens; local-date strings are displayed as sent and compared with the device's today (T8); no `q` (D27) |
| F10 | Double-submit of `POST /api/enrollments` creates two enrollments (no idempotency, today's behaviour); with `draftId` the second deletes nothing and succeeds | build-time risk — T10: the checklist's `processing` phase blocks a second Enroll |
| F11 | The feed's aggregates (D12, D16, D17) are one GROUP BY `enrollmentId` query each over `lesson_schedules` (`@@index([enrollmentId])`) and the progress tables (`@@index([lessonScheduleId])`) | build-time risk — T4 measures the query on the fixture org |
| F12 | Item 8 (render vs frozen snapshot) not run: the capture server was down (`curl localhost:5950` → 000) and `--no-dev-env` forbids starting it. All four screens are built; D14 has d2m re-render and re-record all four | build-time risk — T9: d2m's own capture + diff of each changed screen is the check |
| F13 | The groups-enroll-program and groups-detail screen specs live only in d2m (not under `docs/ui2/screens/`); their OQs were read from the Swift sources: OQ-004 is superseded (D2), the rest (OQ-005, OQ-C-040-001/-3, groups-detail OQ-004/-006/-007, OQ-schat-groups-detail-1, OQ-C-065-001) have no effect here | settled |
| F14 | The server fast gate `npm run test:run` needs a database a fleet worktree doesn't have (no `server/.env`; ui2-groups-edit's gate log shows the same) | build-time risk — Task 1 builds a branch test DB `makeready_ueb_test` from this branch's migrations + seeds; every server task's test command passes its URL (`DATABASE_URL`, `FIXTURES_TEST_DATABASE_URL`) |
| F15 | Live `makeready_dev` (and likely prod) store ids as `text`, while Atlas-generated FKs are `uuid`; `enrollment-analytics.service.ts`'s `$1::uuid` form fails on `text` | build-time risk — Task 1: applying to dev is not the task's; an "incompatible types" error anywhere is stop-and-report, never a hand-edited migration. Tasks 4–5 compare `col::text = ANY($1::text[])` (index use checked with EXPLAIN on dev) |
| F16 | `GET /api/enrollment-drafts?groupId=` returns Draft (no program name or cover), which the group page's draft rows and `n/6` need | settled by D19's existing fallback — Task 14 resolves the program from AppState and loads programs when one is unknown; no contract change |
| F17 | Plan-time readings with no product effect: Home's `tz` is validated (400 when invalid) and otherwise unused — every Home date is in the enrollment's own zone; a null `LessonSchedule.title` is sent as `''`; `EnrollmentDraft` also stores `serverUpdatedAt` (D21's newer-than check); `APIHTTPError` gains a `details` map to carry the 409's `draftId`; feed/home load failures are console-only with the screen's `failed` state; a failed first POST (D3) retries like a PATCH (D26) | settled (plan 2026-10-29, auto) |
| R1 | repoint (iphone): EmptyPage for `.enrollments` ← `UI2Shell.swift:211-218` (sectionContent gains `case .enrollments`) | builder:plan's repoint + retire phase |
| R2 | repoint (iphone): new `UI2Destination.enrollmentHome(id:name:)` ← `UI2ShellModel.swift:19-60`, `UI2Shell.swift:184-208` (`page(for:)`) | builder:plan's repoint + retire phase |
| R3 | repoint (iphone): groups-detail Enrollments rows ← `GroupDetailContainer.swift:47-70` (`onOpenEnrollment`, D28) | builder:plan's repoint + retire phase |
| R4 | repoint (iphone): the in-memory checklist draft ← prune at `UI2Shell.swift:127`, `AppState.swift:475` (drops local state only, never DELETEs), `EnrollChecklistContainer.swift:86-89` `leave()`; TopNav `add` (`TopNavHost.swift:104`) unchanged | builder:plan's repoint + retire phase |
| R5 | repoint: deep links and notification targets — none (the 2.0 shell drops every deep link, `UI2Shell.swift:119-124`); client and capture — none (web posts without `draftId`, D24; capture's `fixtures/ui2/` holds component fixtures only, the screen cases are in the iphone test target, maintained by d2m) | no repoint |

## Plan

The plan, with its code: `docs/features/ui2-enrollments-browse/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · `EnrollmentDraft` table — schema YAML, Atlas migration, Prisma client, and the branch's test database
- Phase 1 · Task 2 · Draft CRUD — `enrollment-draft.service.ts` + thin `/api/enrollment-drafts` router
- Phase 1 · Task 3 · `POST /api/enrollments` takes `draftId` and deletes the pair's drafts after the welcome post
- Phase 2 · Task 4 · The org-wide feed — `enrollment-directory.service.ts` + `GET /api/enrollments-feed`
- Phase 2 · Task 5 · The enrollment home read — `getEnrollmentHome` + `GET /api/enrollments/:id/home`
- Phase 2 · Task 6 · Fixture layers for the walk — `enrollment-home.ts`, `enrollments-home.ts`, kind `001b` — then freeze the contract
- Phase 3 · Task 7 · Draft wire type, EnrollmentDraft server fields, Draft ↔ EnrollmentDraft mapper and the PATCH body
- Phase 3 · Task 8 · AppState stores, EnrollmentDraftActions, feed and home loads, draftId on Enroll
- Phase 3 · Task 9 · The `.enrollmentHome` destination and its page
- Phase 4 · Task 10 · The Enrollments section — EnrollmentsHomeContainer, EnrollmentsHomeMapper and draft-row opening
- Phase 4 · Task 11 · The enrollment page — EnrollmentHomeContainer and EnrollmentHomeMapper
- Phase 5 · Task 12 · Checklist autosave — EnrollDraftSync and the six commit points
- Phase 5 · Task 13 · Stale start on open, Discard enrollment, draftId on Enroll, Back keeps the server draft
- Phase 5 · Task 14 · Group page — draft rows after the enrollments, row taps open the enrollment or the draft
- Phase 5 · Task 15 · Repoint + retire sweep — prove R1–R5 and guard the prune

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

## Replaced surfaces

| # | Surface (file:line) | Kind | Fingerprint |
|---|---|---|---|
| 1 | `EmptyPage` for `.enrollments` — `iphone/MakeReady/UI2/Shell/UI2Shell.swift:217` (stays for Library, Invites, Media) | REPLACES | 8e79847 |
| 2 | In-memory checklist draft — `iphone/MakeReady/State/EnrollmentDraft.swift:5`, `AppState.swift:454-477`, `EnrollChecklistContainer.swift:86` | ABSORBS (the local flow stays; a server row backs it once saved) | 7ea8431 |
| 3 | groups-detail Enrollments section — `GroupsDetailScreen.swift:530-568`, `GroupDetailMapper.swift:62-110`, `GroupDetailContainer.swift:65` | ABSORBS (draft rows) | 3227149 |
| 4 | `EnrollmentsHomeScreen`, `EnrollmentHomeScreen` (preview-only today) | REUSES (first wiring) | 9bfd45f |
| 5 | Home dashboard followed-enrollment cards — `HomeDashboardContainer.swift:25` | ADJACENT, untouched (§Out of scope) | 3227149 |

| # | Gap / add | App | Disposition |
|---|---|---|---|
| S1 | Back discarded the checklist; a saved draft now survives | iphone | D2 (supersedes create D13 / OQ-004) |
| S2 | the checklist worked offline until Enroll; autosave needs the network | iphone | D26 |
| S3 | group-page enrollment-row taps are dead today | iphone | D28 |
| N1 | the Enrollments list | iphone | D7, D8, D25, D27, T8 |
| N2 | the enrollment detail | iphone | D20, T8 |
| N3 | saved drafts | server | SC1, SC2, T1, T2 |
| N4 | save, resume, discard drafts | iphone | D3–D11, T10 |
| N5 | group-page draft rows | iphone | D7b, T10 |
