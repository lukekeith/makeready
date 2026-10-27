# ui2-groups-browse — spec
> lg · child 1 of program `ui2-groups` (docs/features/ui2-groups/PROGRAM.md)

## Idea

**Why.** The iPhone app's root is the UI 2.0 shell (`MakeReadyApp.swift:28`), and its Groups section (Home tab) is a
blank `EmptyPage` (`UI2Shell.swift:165-170`). Leaders — org owners, admins and group leaders — have
nowhere in 2.0 to see their groups, open one, or start one. Every screen they need is already built
as a MakeReadyUI preview from d2m (`groups-home`, `groups-detail`, `create-group`); this child wires
them to live data and adds the server data the group page reads that does not exist yet.

**What success looks like.** On the walk env as the fixtures owner: Groups lists every fixture group
alphabetically, search and both chips narrow it, the TopNav `+` creates a group and lands on its page;
tapping a group pushes its page with every section showing real data — cover, the four stats, the six
setting values, the next lesson with activity thumbnails, the activity rail and chart, pending join
requests above the members, enrollments, the latest 5 history events — and each section shows its
designed one-line empty state on a group with no data. Member rows open the member page, Members `add`
opens invite, and a member page's group row opens the group page.

**In your words.** "build the groups experience, which is the home groups page, group detail page, and
edit screens for group data" → D0 (this child is the browse half; edits are `ui2-groups-edit`) ·
"that's right. proceed" (2026-10-27, confirming this child's scope) → D0.

**The concept.** App-side containers per screen read `AppState`, build the MakeReadyUI screen's
`State`, and map its callbacks to Actions or shell routes — the ui2-members pattern.

```mermaid
flowchart LR
  Tab[Groups tab] --> GH[GroupsHomeContainer] -->|row tap| GD[GroupDetailHost]
  Nav[TopNav +] --> CG[CreateGroupContainer] -->|Create ok| GD
  MP[MemberProfileContainer group row] --> GD
  GD -->|member row| MD[.memberDetail]
  GD -->|Members add| IM[.inviteMember]
  GD --> A[GroupActions: getGroup · members · joinRequests · enrollments · nextStudy · history · days · chart]
  A --> S[(server)]
```

**How it fits today.** The push stack (`UI2Destination` + per-tab `NavigationStack`, `UI2Shell.swift:112-155`),
the invite flow (`.inviteMember`), the member page (`.memberDetail`) and `GroupActions`
(groups, members, join requests, create) exist. The server already scopes every group route by
`groupManageFilter` (`permission.ts:322`); intake (`.builder/ui2-groups/brainstorm.md`) recorded what
each endpoint returns and the 7 places the design's data claims disagreed with the code.

**Approaches considered.** Chosen: containers in `iphone/MakeReady/UI2/Containers/Groups/`, as for
Members. Rejected: wiring inside the MakeReadyUI screens (d2m regenerates them, ui2-shell D2).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | groups list + detail additive fields; new group history endpoint; `/api/home/days` `groupId`; next-study title + thumbnails; cover upload tracked; access checks on group members + membership history; `Group.memberDirectoryAccess` column + backfill; fixture layers | §server |
| client | ⬜ | UI 2.0 leader screens are iPhone-only; web reads `memberDirectory` (Boolean), which stays and is unchanged (P8). The two new access checks (D9) are audited for web callers (F2) | — |
| iphone | ✅ | Groups tab wired (groups-home), group page (groups-detail), create-group, routes, new Actions, members-profile group row, GroupsHomeScreen nav row removed | §iphone |
| capture | ⬜ | screens capture from fixture JSON via ViewRegistry, not the live API; no capture case changes | — |

**Sequencing:** contract settled → server (schema, endpoints, checks, fixtures) verifies → contract
FREEZES → iphone builds against it → the walk on Fixtures.

**Backward compatibility:** every field and endpoint is additive; released 1.0 builds decode the
groups payloads with optional fields and ignore the new keys. The non-additive change is D9 (404 on
the group member list and membership history for callers outside the group's manage scope); F2 lists
the released callers. `memberDirectory` keeps its meaning on every read and write.

**Blast radius:** every caller of `GET /api/groups`, `GET /api/groups/:id`, `/next-study`,
`/api/home/days`, `/groups/:id/members`, `/membership-history`; `Group` reads (new column).

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
| D0 | Program decisions | PROGRAM.md §Shared decisions P1–P15 bind this spec; the rows below apply them to this child or add to them. This child: groups-home, groups-detail (read), create-group and their server data; field edits, the directory-access write and Delete Group are `ui2-groups-edit`. Rejected: one spec for both halves (owner chose the split) | Luke 2026-10-27 |
| D1 | Routes | New `UI2Destination` cases `.groupDetail(id: String, name: String)` and `.createGroup`; `UI2Shell.page(for:)` maps them to `GroupDetailHost` and `CreateGroupContainer`. Groups section root = `GroupsHomeContainer` in `sectionContent` (Groups is a TopNav section of the Home tab, `UI2ShellModel.swift:5`, so every group push goes on the `.home` stack). Rejected: a modal for create-group (the design pushes it) | (assumed at spec) 2026-10-27 |
| D2 | Groups-home nav row (P2) | `GroupsHomeScreen` no longer draws its C-019 row or takes `onSelectTab`/`onToggleNav`/`onAddGroup` (OQ-groups-home-2's `+` now lives on TopNav, D7), exactly as ui2-members-browse D4 did for MembersHomeScreen; the build makes that edit under this ruling and routes it to `/ui2-resolve` so d2m's source matches (F3). Rejected: waiting for the design owner before the iPhone phase (blocks the build on a mechanical edit the members precedent already made) | Luke 2026-10-27 (supersedes P2's prerequisite) |
| D3 | Groups-home list (P4) | Rows = `AppState.groups` (every group `GET /api/groups` returns; `loadGroups` replaces the store), sorted by name, case- and diacritic-insensitive. Search: 300 ms debounce, case-insensitive substring of the group name, AND-combined with both chips. Leaders chip options: `AppState.groupLeaders` (`MemberActions.loadFilterOptions`, `GET /api/group-leaders`) full names (sorted as returned); a group matches when its `creatorId` is the `id` of any leader whose name is selected (the screen returns labels, `GroupsHomeScreen.swift:45`, so two same-named leaders select together). Orgs chip: `GET /api/organizations/my/organizations` names, loaded by a new `loadMyOrganizations` into `AppState.myOrganizations` for every role (today owners only get their owned org, `AppState.swift:930-966`); labels map to ids as for leaders; visible (`orgFilterVisible`) only when that list has ≥2 orgs; a group matches when its `organizationId` is selected. Empty selection = all. Row: cover (`coverImageUrl`, else C-038 initials), name, `creatorName`, member count. Pull-to-refresh on the Groups section reloads groups with `loadGroups(forceRefresh: true)` (`UI2Shell.refreshAction` serves only `.home` today, `UI2Shell.swift:160`). Rejected: server-side filter params (unneeded at this list size) | (assumed at brainstorm) |
| D4 | Group page load (B3) | Push renders at once from `AppState.groups[id]` with the header name from the pushing row; `.task` loads in parallel: `GET /api/groups/:id`, members, pending join requests, enrollments, next-study, history (`limit=5`), days, chart. Each section shows its empty line (copy below) until its data lands; a failed load keeps what is shown and records the error (`recordError`, 401 → sign-out — ui2-shell D28). Section-empty copy, closed: "No lessons scheduled" · "No members yet" · "No enrollments yet" · "No history yet"; Activity renders its C-071 `Nothing` cards and C-026 empty state, no line. Rejected: skeletons (not designed) | (assumed at brainstorm) |
| D5 | Stats + settings display | Stats: Group Leader = `creatorName`; Members and Enrollments = the row counts of the members and enrollments lists (the screen counts `memberNames`/`programTitles`, `GroupsDetailScreen.swift:290-296`; 0 until each loads); Created = `createdAt` as `MMM d, yyyy`; Settings values: Group name; Description (wraps, two lines in the frame); Visibility = "Private" when `isPrivate` else "Public"; Age = both null → "Any age", both set → "«min» - «max»", min only → "«min»+", max only → "Up to «max»"; Maximum members = number or "Unlimited" when null; Member directory access = "Allowed" / "Names only" / "Not allowed" from `memberDirectoryAccess` (D11). Rejected: system locale formats (diverge from the frame) | (assumed at spec) 2026-10-27 |
| D6 | Inert in this child (P1, B1) | The six C-042 rows render with values and chevrons; tapping does nothing until `ui2-groups-edit`. No-ops: Delete Group, join-request rows, enrollment rows, the LessonCard, Enrollments `add`, Timeline "All history", chart pan. Rejected: hiding them (loses the designed layout) | (assumed at brainstorm) |
| D7 | Wired exits | Member row → `.memberDetail(id: GroupMember.userId, name)` (`GroupMember.id` is the membership row); Members `add` → `.inviteMember(groupId, returnDepth)`; members-profile group row (today a no-op, `MemberProfileContainer.swift:49`; `MembersProfileScreen.onOpenGroup(Int)` → `MemberGroupItem.id`) → `.groupDetail`; TopNav `+` on the Groups section → `.createGroup` (P3, beside the Members `+` in `TopNavHost.swift:96`); "Jump to today" scrolls the rail to today's card | Luke 2026-10-27 (P1) · (assumed at brainstorm) (P3) |
| D8 | Create group (P3) | `CreateGroupContainer` calls `GroupActions.createGroup(name: trimmed)` with its default flags (`isPrivate:false, allowInvites:true, memberDirectory:true`, `GroupActions.swift:139-144` → D11 writes `ALLOWED`), name 1–200 chars; success merges the group into `AppState.groups` and replaces the form with `.groupDetail` of the new group through a new `UI2Navigator.replaceTop` (one path write; back returns to Groups), guarded like `popIfTop` — when the form is no longer on top (swiped back mid-create) it writes nothing; creating = Create disabled + field read-only; failure keeps the name, re-enables Create and surfaces "Couldn't create the group" via `recordError(surface: true, friendlyMessage:)` (401 → sign-out first, `AuthStatusPolicy.shouldSignOut`). Rejected: staying on the form after create (the next thing a new group needs — settings, members — lives on its page) | (assumed at brainstorm) |
| D9 | Access checks (P12) | `GET /api/groups/:groupId/members` and `GET /api/groups/:groupId/membership-history` resolve the group through `groupManageFilter(userId)` + `isActive`; otherwise 404, as every other group route. Rejected: leaving them open (any signed-in user reads any group's members) | (assumed at brainstorm) |
| D10 | Leader name + org fields (P4, P13) | `GET /api/groups` adds `organizationId` and `organizationName` per group; `GET /api/groups/:id` and the PATCH response add `creatorName` (the creator's `User.name`). Rejected: phone-side lookups (an extra request per group, and the org list doesn't map groups to orgs) | (assumed at brainstorm) |
| D11 | Directory access column (P8) | New enum `DirectoryAccess { ALLOWED, NAMES_ONLY, NOT_ALLOWED }`, column `Group.memberDirectoryAccess` NOT NULL default `ALLOWED`; the migration backfills `NOT_ALLOWED` where `memberDirectoryEnabled = false`. Every group payload (list, detail, PATCH, create) adds `memberDirectoryAccess`. Writes in this child: `POST /api/groups` and PATCH with only the Boolean `memberDirectory` set the enum to `ALLOWED`/`NOT_ALLOWED` to match; child 2 adds the enum write and the reverse sync. Rejected: deriving the enum on read only (two sources of truth once child 2 writes it) | Luke 2026-10-27 (column) · (assumed at spec) 2026-10-27 (shape) |
| D12 | Activity rail (P5, refined) | 30 local days today−29 … today, today trailing, opened scrolled to today. Per card: line 1 = "«N» lessons" (`scheduled_lessons` that day); line 2 = "«C» complete" (`lesson_completions`), today = "«N−C» left" when N > C else "«C» complete", empty when N = 0; `dayDetailsStates` = `nothing` when N = 0 and no sessions, else `default`; series = `/api/home/days?groupId=` `blocks` (12 two-hour blocks, seconds → minutes, as Home — `HomeDashboardMapper.blockMinutes`). Rejected: minutes on the lines (the built view and frame show lesson counts) | Luke 2026-10-27 (sources) · (assumed at spec) 2026-10-27 (mapping) |
| D13 | Activity chart (P5) | Query shape superseded 2026-10-27 by D21 (two single-metric queries over today−29 … today+3); the rest stands. `POST /api/analytics/query` `{metrics:["scheduled_lessons","lesson_completions"], dimensions:["day"], filters:{groupId}, timeRange: today−23 … today+3}` → `chartDates`/`chartScheduled`/`chartCompleted` zero-filled per day; `chartToday` = today; window = the range (the frame's 27-day window with today 4th from the end) | (assumed at spec) 2026-10-27 |
| D14 | `groupId` on `/api/home/days` | New optional `groupId`; the group must pass `groupManageFilter` for the caller, else 404; filters sessions to members with an active `GroupMember` row in that group (a member in two groups counts in both); `memberId` + `groupId` together → 400; no user id (API-key caller) → 404, as the `memberId` path (`home.ts:129-134`). Rejected: enrollment-tied moments only (the rail shows the group's members' activity, not one program's) | (assumed at spec) 2026-10-27 |
| D15 | History endpoint (P6, refined) | `GET /api/groups/:id/history?limit=1..50` (default 20), `groupManageFilter`; merges newest-first: `MembershipEvent` rows of the group (APPROVED/ADDED/REJOINED → "«name» joined the group"; REMOVED_GROUP → "«name» left the group"; REMOVED_ORG never carries a `groupId` (`organizations.ts:1136`) and is not read; REQUESTED → "«name» requested to join"; INVITED/REJECTED omitted), the group's `Activity` rows (`resourceType GROUP`: UPDATED with `metadata.field = "cover"` → "Updated cover photo", any other UPDATED → "Updated group settings", CREATED → "Created the group"), and the group's `Event` rows dated in the past, `isActive`, `type` ≠ `LESSON` (enrollments create one LESSON event per day, `enrollments.ts:342`) ("Held event at «locationName ?? title»"). «name» = `Member.firstName` + " " + `lastName`, trimmed, else "Unknown" (as `group-members.ts:221`). Each: `{id, occurredAt, kind: member_joined|member_left|join_requested|settings_updated|cover_updated|group_created|event_held, text, highlight|null}`; `highlight` = the member's name (joined/left/requested) or "event at «…»" (event_held), else null. `POST /groups/:id/cover-image` calls `trackActivity` (resourceType GROUP, action UPDATED, metadata `{field:"cover"}`) and history maps it to cover_updated. Rejected: phone-side merge | Luke 2026-10-27 (endpoint) · (assumed at spec) 2026-10-27 (kinds + copy) |
| D16 | Timeline display | `eventTexts` = `text`; `eventHighlights` = `highlight ?? ""`; `eventTones` = `accent` when `highlight` non-null else `neutral`; `eventDates`: < 60 min "Just now", today "Today", yesterday "Yesterday", this year "MMM d", else "MMM d, yyyy" | (assumed at spec) 2026-10-27 |
| D17 | Next lesson (P7) | `GET /api/groups/:id/next-study` adds `study.title` (`LessonSchedule.title`, null-safe) and per activity `thumbnailUrl` (YouTube/video thumbnail when the activity has one, else the first image of a READ activity, else null). The activity select adds `versionId` so `filterActivitiesToVersion` drops other versions' rows (`enrollments.ts:1335`, `lesson-version-resolution.ts:50`). Card: title = `title ?? "Day «dayNumber»"`; program line = program name; meta = "Today" / "Tomorrow" / weekday within 6 days / "MMM d", from `scheduledDate`'s UTC calendar date against the phone's local today; slides = first 3 activities, image = `thumbnailUrl`; the container seeds `Ui2ImageCache` with the cover, the slide images and the enrollment covers and bumps a render token when each lands, as `MemberProfileContainer.seedCovers` (`:91-108`) — the screen reads images only from that cache (`GroupsDetailScreen.swift:662`), label = activity title; 204 → section empty | Luke 2026-10-27 (fields) · (assumed at spec) 2026-10-27 (fallbacks) |
| D18 | Members + requests display | Requests (C-089 `requested`): `GET /groups/:id/join-requests` pending, `recipient` = first + last name, else "Unknown" (both nullable), `date` = `createdAt` per D16's date rule; above the members; not counted in "«N» members". Members: `GET /groups/:id/members`, sorted by the mapper on `joinedAt` desc (the AppState index is a Set and loses server order), "Joined «label»" with ui2-members-browse D6's day-age labels. Enrollments: `GET /groups/:id/enrollments`, sorted by the mapper on `createdAt` desc, title = `studyProgram.name`, description, cover, "enrolled «MMM d, yyyy»" of `createdAt`; header "«N» programs" | (assumed at spec) 2026-10-27 |
| D19 | Fixtures (P15) | `server/fixtures/screens/groups-home.ts` and `groups-detail.ts` (+ `create-group.ts` empty layer if the registry requires one per screen): one fixture group gets 2 pending join requests, a next lesson today (next-study's "today" is the server's midnight, `enrollments.ts:1302`) and tomorrow, each with 3 activities carrying thumbnails, ≥6 history items across all kinds, the base plan's scheduled lessons over the last 30 days (≥20 days; the base gap today−18 … today−14 stays and shows the empty-day card) with partial completions and member sessions; one fixture group stays empty for the section-empty states | (assumed at spec) 2026-10-27 |
| D20 | Groups-home leader short name (align) | the mapper reuses `MemberProfileMapper.leaderShortName(_:)` (`MemberProfileMapper.swift:95-99` — «first initial». «last word», a single word unchanged), "" when null; computed on the phone at render, the wire keeps the full name. Rejected: a server `creatorShortName` (a display rule on the wire); the full name (overflows the chip in the frame) (raised: the built `GroupsHomeScreen` C-043 slot takes a short name ("L. Keith", `GroupsHomeScreen.swift:55`); `creatorName` is the full `User.name`) | auto (recommended) 2026-10-27 — raised by align |
| D21 | Activity chart query split (align, amends D13) | two `POST /api/analytics/query` calls, run concurrently, same `filters:{groupId}`, `dimensions:["day"]` and range — `["scheduled_lessons"]` and `["lesson_completions"]`, over today−29 … today+3 so the rail's 30 days (D12 lines) and the chart's today−23 … today+3 window (D13) both read from them — zero-filled and merged per day, exactly as Home does (`DashboardActions.swift:49,110`); either failing keeps the other series and records the error (D4). Rejected: a server-side combined metric (new engine surface for one chart) (raised: D13's one query 400s: `scheduled_lessons` buckets by stored date and `lesson_completions` by event time, and `analytics.service.ts:538` refuses to mix them) | auto (recommended) 2026-10-27 — raised by align |
| D22 | Groups-home states the design draws only as `populated` (audit) | loading (no cache) = the chips and an empty list; zero groups = one centred line "No groups yet"; no match = "No groups match your search"; first-load failure = `recordError` banner over the cached or empty list; search is not pinned (the screen has no `onSearchActiveChange` hook, unlike Members). The two lines go to `/ui2-resolve` with D27's edits. Rejected: blank list (a filter that hides everything reads as a load failure) | auto (recommended) 2026-10-27 — raised by audit |
| D23 | A group page the caller can't manage (audit) | `GET /api/groups/:id` 404 → the page keeps the pushed name, every section shows its empty state, no banner (a 404 here is scope, not failure); every section load follows the same rule. Rejected: popping back (an unexplained bounce) (raised: reachable from a member page listing groups outside the caller's scope) | auto (recommended) 2026-10-27 — raised by audit |
| D24 | Group deep links (audit) | keep dropping them in this child — §Out of scope, owned by a later deep-link child; the group page exists now, so the route is ready when it lands. Rejected: wiring them here (the first 2.0 deep-link consumer sets shell-wide policy no screen spec owns) (raised: `makeready://group/{id}` (`MakeReadyApp.swift:121`), the `MEMBER_JOINED` push (`PushNotificationManager.swift:222`) and `join-requests` (`MakeReadyApp.swift:114`) are compiled but `UI2Shell` drops every pending link (`UI2Shell.swift:88-96`, ui2-shell D17)) | auto (recommended) 2026-10-27 — raised by audit |
| D25 | The empty fixture group (D19, audit) | `base.ts` gains a 5th group "Empty Group" with no members, enrollments or schedules, outside `created.groups` so existing layers are unchanged; `ids.ts` gains the kinds this feature's rows need (join request, feed Activity, Event, scheduled activity). Rejected: dropping the empty-state walk (the D4 copy then ships unseen) (raised: layers may not create groups (`server/fixtures/README.md`) and all 4 base groups carry members and enrollments (`base.ts:152-172`)) | auto (recommended) 2026-10-27 — raised by audit |
| D26 | Joins by invite never reach history (audit) | accept it in this child and record it under §Out of scope (writing the missing events is a membership-history fix with its own consumers); fixtures seed joins through `MembershipEvent` rows directly. Rejected: adding ADDED events to both paths here (changes the members-profile history too) (raised: invite-accept (`services/invite.ts:240`) and invited auto-join (`group-join-requests.ts:279`) create `GroupMember` with no `MembershipEvent`, so D15 shows no "joined" for them) | auto (recommended) 2026-10-27 — raised by audit |
| D27 | MakeReadyUI screen edits beyond D2 (audit) | the iPhone phase makes the three edits under this ruling, as D2 — `showsHeader: Bool = true`, rail opened at the last card, `editing: .init(focusOnAppear: true, isEnabled: !creating)` (precedent `InviteMemberScreen.swift:160`) — and routes them with D2 and D22's lines to `/ui2-resolve` (F3). Rejected: waiting on the design owner (blocks the build on mechanical edits with precedents) (raised: three built screens can't be wired as specced: `GroupsDetailScreen` draws C-040 in its VStack with no `showsHeader` flag (`:222-232`), has no rail `scrollPosition` to open on today (D12; Members has one, `MembersProfileScreen.swift:415-419`), and `CreateGroupScreen`'s `FieldGroup` gets no `editing:` so it cannot be typed into (`:76-83`, `FieldGroup.swift:59-62`); likewise `GroupsHomeScreen`'s search field is the non-editable form (`SearchField.swift:68`) and gains `editable: true` as Members) | auto (recommended) 2026-10-27 — raised by audit |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `GET /api/groups` (extended) | server | iphone | `requireAuth` + `groupManageFilter` | — | existing per group + `organizationId`, `organizationName`, `memberDirectoryAccess` | 401 |
| `GET /api/groups/:id` (extended) | server | iphone | as today | — | existing + `creatorName` (string\|null), `memberDirectoryAccess` | 401 · 404 |
| `POST /api/groups`, `PATCH /api/groups/:id` (response extended) | server | iphone | as today | unchanged | existing + `creatorName`, `memberDirectoryAccess` (D11 sync on write) | as today |
| `GET /api/groups/:id/history` (new) | server | iphone | `requireAuth` + `groupManageFilter` | `limit?` 1–50 | `{events:[{id, occurredAt (ISO), kind, text, highlight\|null}]}` (D15) | 400 · 401 · 404 |
| `GET /api/groups/:id/next-study` (extended) | server | iphone | as today | — | existing + `study.title` (string\|null), `activities[].thumbnailUrl` (string\|null); 204 unchanged | 401 · 404 |
| `GET /api/home/days` (+ `groupId`) | server | iphone | `requireAuth` + D14 | existing + `groupId?` | existing `{days:[…]}`, filtered per D14 | 400 · 401 · 404 |
| `GET /api/groups/:groupId/members`, `/membership-history` (scoped) | server | iphone | `requireAuth` + `groupManageFilter` (D9) | unchanged | unchanged | 401 · 404 (new) |
| `POST /api/analytics/query` ×2 (D21: `scheduled_lessons` alone, `lesson_completions` alone — they cannot share a query) | server | iphone | existing (`filtersWithinScope`, `analytics.ts:70`) | `{metrics:[one], dimensions:["day"], filters:{groupId, from, to}}` (dates ride in `filters`, `analytics.ts:113-114`, as `DashboardActions.query`) | existing `rows` per day | 400 (mixed buckets) · 404 (group outside scope) |
| `GET /groups/:id/join-requests`, `GET /groups/:id/enrollments`, `GET /api/group-leaders`, `GET /api/organizations/my/organizations` (unchanged) | server | iphone | existing | — | existing | existing |

## Schema & API changes

| # | Kind | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| SC1 | ADD | `Group.memberDirectoryAccess` (enum `DirectoryAccess`, NOT NULL, default `ALLOWED`) | `memberDirectoryAccess` on every group payload | groups-detail settings row "Member directory access" (three options, shared-edit-field §2b); P8 · D11 | landed 865aa61 · migration 20261027064150 · T1, T3 |
| SC2 | EDIT | groups list response | + `organizationId`, `organizationName` | groups-home Orgs chip; D10 | landed e08813c · T2 |
| SC3 | EDIT | group detail / PATCH / create response | + `creatorName` | groups-detail "Group Leader" stat; D10 | landed e08813c · T3 |
| SC4 | ADD | `GET /api/groups/:id/history` | §Contract | groups-detail Timeline; D15 | landed 891f1fe · T4 |
| SC5 | EDIT | next-study response | + `study.title`, `activities[].thumbnailUrl` | groups-detail Lessons up next; D17 | landed c5370b0 · T6 |
| SC6 | EDIT | `/api/home/days` `groupId` param | §Contract | groups-detail day rail series; D14 | landed e0e5b73 · T7 |
| SC7 | EDIT | cover-image upload | + `trackActivity` row | groups-detail Timeline "Updated cover photo"; D15 | landed e08813c · T5 |

**Data plan:** SC1 goes through `server/schema/*.yaml` → `schema:diff` → one Atlas migration (house
rules): add the enum + column with default `ALLOWED`, then `UPDATE "groups" SET "memberDirectoryAccess" =
'NOT_ALLOWED' WHERE "memberDirectoryEnabled" = false` appended to the generated migration before it is committed (precedent `atlas/migrations/20260621022752.sql`), then `atlas migrate hash`; diff/apply through `scripts/atlas.sh --var database_url=…` (`schema:diff` reads the 1Password `.env` via dotenv). Undo = drop the column and
the enum; the Boolean is untouched throughout. SC2–SC7 are additive wire changes. Independent ordering.

## server

- Schema SC1 via the YAML source and an Atlas migration; Prisma client regenerated in the container.
- `groups.ts`: list adds org id/name (Group has no `organization` relation — one batched `organization.findMany` over the distinct ids) and `memberDirectoryAccess`;
  detail/PATCH/create add `creatorName` + `memberDirectoryAccess`; create and PATCH keep the enum in
  sync with a Boolean-only write (D11); cover upload calls `trackActivity` (SC7).
- New `services/group-history.ts` + route `GET /api/groups/:id/history` (D15).
- `enrollments.ts` next-study: select `title`; compute `thumbnailUrl` per activity (D17).
- `home.ts` `/days`: `groupId` in `daysQuery`, the D14 check, member filter passed through `getHomeDays` to `loadSessions` (`home-sessions.ts:64`).
- `group-members.ts`: D9 checks on GET members (`:187`) and GET membership-history (`:712`); POST/PATCH/DELETE are already guarded.
- Fixtures D19.

## iphone

- **Shell:** `UI2Destination` `.groupDetail`, `.createGroup` (D1); `sectionContent` `.groups` →
  `GroupsHomeContainer`; `TopNavHost` `onAdd` for the Groups section → `.createGroup` (D7);
  `UI2Navigator.replaceTop` (D8); `refreshAction` for `.groups` (D3).
- **Groups home:** `GroupsHomeContainer` + `GroupsHomeMapper` (D3); `GroupsHomeScreen` drops its
  C-019 row (D2).
- **Group page:** `GroupDetailHost` (the container pins C-040 with the screen's `showsHeader: false`, D27, as
  `MemberProfileContainer.swift:34-47`) + `GroupDetailContainer` + `GroupDetailMapper` (D4–D7, D12, D13,
  D16–D18).
- **Create:** `CreateGroupContainer` (D8).
- **Members page:** group row → `.groupDetail` (D7).
- **State:** `loadMyOrganizations` → `AppState.myOrganizations` (D3); `UserGroup` gains `organizationId?`, `organizationName?`, `memberDirectoryAccess?`
  (optional decode); new `GroupActions.loadNextStudy`, `loadHistory`, `loadGroupDays`,
  `loadGroupChart`; stores keyed by group id in `AppState`, in memory only, cleared in
  `clearInMemory()` together with `pendingJoinRequestsByGroupId` (not cleared today, `AppState.swift:239`).
  New loaders follow `MemberActions`' non-throwing `fetch` + `handle` (401 → sign-out, a stale
  generation writes nothing).

## Testing

- **server:** route tests — list org fields; detail/PATCH `creatorName`; D11 enum backfill + sync on
  create/PATCH; history (each kind, ordering, limit, highlight, cover upload row, 404 outside scope);
  next-study `title` + `thumbnailUrl` (each source, null); days `groupId` (member filter, two-group
  member, 404 out of scope, 400 with `memberId`); D9 404s for a non-manager; fixtures DB tests (D19);
  `migrate:status` clean on a fresh DB.
- **iphone:** mapper tests (D3 sort/search/chips; D5 values incl. every Age form; D12 lines incl. today
  "left"; D13 zero-fill; D16 date labels; D17 fallbacks; D18 order + counts), decode tests for the
  extended payloads, shell route tests (`.groupDetail`, `.createGroup` replace), `ios:build-check
  --test`, swiftlint baseline.
- **Cross-app E2E (Fixtures, walk env):** Groups lists every fixture group A→Z; search + chips filter;
  Groups section `+` creates "Walk Test Group" and lands on its empty page (every empty line shows); the rich fixture
  group shows every section populated; member row → member page; Members `add` → invite; member page
  group row → group page.
- **Human walk (on device):** scroll feel of the long group page, rail "Jump to today", pinned header.

## Out of scope

- Field edits, the directory-access write and Delete Group — `ui2-groups-edit` (D0).
- invite-home, enrollment-home, groups-enroll-program, groups-history destinations (P1; owner 2026-10-27).
- Group deep links and push targets (D24); history rows for joins by invite (D26).
- Cover upload, directory enforcement, restore, AI suggestions; the web client (P8, P11, PROGRAM §Out of scope).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | d2m marks groups-detail `updateNeeded` (Figma ref re-added after the spec, 2026-10-27) | build-time risk — a d2m drift check before the iPhone phase (design owner); a drifted section goes through `/builder:revise` |
| F2 | D9 adds 404s to two endpoints released 1.0 builds and the web may call without manage rights | audited: GET members is called by `GroupActions.swift:428`, `client/…/members.domain.ts:57`, `leader-group-home.store.ts:337`, `leader-groups.store.ts:155` — all with group ids from manage-scoped lists, so no in-scope caller gets a new 404; membership-history has no live caller. Client ⬜ stands |
| F3 | D2 edits a MakeReadyUI screen (ui2-members-browse precedent) | route the change to `/ui2-resolve` after the build so d2m regenerates the same view |
| F4 | `/api/analytics/query` future-day buckets for `scheduled_lessons` (D13 window ends today+3) are unverified | settled at align: stored-date buckets read `lesson_schedules.scheduledDate`, and Home already queries them to today+7 (`DashboardActions.swift:44`) — the today+3 window stands |
| F5 | D13 as written sends both metrics in one query, which the engine rejects with 400 (`analytics.service.ts:538`) | D21 (OPEN) — two queries, as Home |
| F6 | `Activity.groupId` is set on every resource type in a group (posts, events…), so a history query on `groupId` alone would pull non-group rows into D15's GROUP kinds | T4 filters `resourceType = 'GROUP' AND resourceId = :id` |
| F7 | `UserGroup` is disk-cached in the released app; the three new fields decode optional (`decodeIfPresent`), so an old cache and an old server both load. No RESHAPE on a cached field | T10 — decode test with each key absent |
| T1 | server: `server/schema/*.yaml` enum `DirectoryAccess` + `Group.memberDirectoryAccess` → `schema:diff` migration with the D11 backfill (SC1) | blocking |
| T2 | server: `GET /api/groups` adds `organizationId`, `organizationName` (batched `organization.findMany`; no relation exists), `memberDirectoryAccess` (SC1, SC2) | blocking |
| T3 | server: detail, PATCH and create responses add `creatorName` + `memberDirectoryAccess`; create and Boolean-only PATCH write the enum (D11) (SC1, SC3) | blocking |
| T4 | server: `services/group-history.ts` + `GET /api/groups/:id/history` — `MembershipEvent` by `groupId`, `Activity` by `resourceType 'GROUP'` + `resourceId`, past `Event` with `isActive` and `type ≠ LESSON` (D15, F6) (SC4) | blocking |
| T5 | server: `POST /groups/:id/cover-image` calls `trackActivity` with `metadata {field:"cover"}` (SC7) | blocking |
| T6 | server: next-study selects `title` and `versionId`, and per activity `thumbnailUrl` = `youtubeThumbnailUrl` ?? `video.thumbnailUrl` ?? the lowest-`orderNumber` `readBlocks.backgroundImageUrl` of a READ activity ?? null (D17) (SC5) | blocking |
| T7 | server: `/api/home/days` `groupId` in `daysQuery` (z.object strips undeclared keys), the D14 check, `getHomeDays` `opts.groupId` → `loadSessions` member filter (`home-sessions.ts:64,75`) (SC6) | blocking |
| T8 | server: D9 `groupManageFilter` + `isActive` checks on `group-members.ts:187` (GET members) and `:712` (GET membership-history) | blocking |
| T9 | server: fixture layers D19 + D25's base group and `ids.ts` kinds; the rich group's next schedule gets `ScheduledLessonActivity` rows (fixtures create none today) with a YouTube thumbnail, a Video and a READ block image — dated today, as base schedules cover today | blocking |
| T10 | iphone: `UserGroup` + `organizationId?`, `organizationName?`, `memberDirectoryAccess?` (optional decode, F7) | trailing |
| T11 | iphone: `NextStudy` Codable struct (none exists today) + `GroupActions.loadNextStudy` (204 → nil) | trailing |
| T12 | iphone: `GroupHistoryEvent` Codable struct + `GroupActions.loadHistory(limit: 5)` | trailing |
| T13 | iphone: `GroupActions.loadGroupDays` (reuses `HomeDay`) and `loadGroupChart` (D21's two queries) | trailing |
| T14 | iphone: `AppState.myOrganizations` + per-group stores (next study, history, days, chart) keyed by group id, in memory, cleared in `clearInMemory()` | trailing |
| T15 | iphone: shell routes + `GroupsHomeContainer`/`GroupDetailHost`/`GroupDetailContainer`/`CreateGroupContainer` and their mappers (D1–D8, D12, D16, D18, D20) | trailing |
| T16 | iphone: `GroupsHomeScreen` drops C-019 (D2) + D22's lines; D27's three screen edits; all routed to `/ui2-resolve` (F3) | trailing |
| T17 | iphone: `UI2Navigator.replaceTop` + `UI2ShellModel.replaceTop(_:on:)`, guarded (D8) | trailing |
| T18 | iphone: `refreshAction` for `.groups` (D3) and `loadMyOrganizations` (D3) | trailing |
| F8 | C-065's built `Tone` predates `accent` (OQ-C-065-001, `GroupsDetailScreen.swift:628-634`), so D16's accent rows render plain until C-065 is rebuilt | design owner (`/d2m:component:build C-065`); not a build blocker — the mapper still sends `accent` |
| F9 | Render diff (audit item 8) not re-run: the capture tool (:5950) was down and the audit starts no server. d2m records all three screens built and diffed at intake; groups-detail is `updateNeeded` (F1) | build-time risk — T15's first task runs the d2m drift check (F1) before wiring the group page |
| F11 | D11's Boolean→enum sync turns a future `NAMES_ONLY` back into `ALLOWED` on any PATCH carrying `memberDirectory: true`, and both apps send it on every edit (`groups.ts:922`) | carried to `ui2-groups-edit`: its enum write must stop the Boolean sync overwriting `NAMES_ONLY` |
| F10 | Design OQs on the three screens are all closed and land on rulings: groups-home-1 → D3 · groups-home-2 → D2/D7 · create-group-002 → D8 · groups-detail-006 → D4 · groups-detail-007 + OQ-004 + schat-groups-detail-1 → D6 · OQ-C-065-001 → F8. No owner notes pending (`ui2-notes.mjs read`) | disposed |
| R1 | repoint (iphone): `MainGroups.swift` ← no compiled caller (not in Sources; `MainView.swift:91` also out of target) | builder:plan's repoint + retire phase — nothing to repoint |
| R2 | repoint (iphone): `GroupHomePage.swift`, `GroupMembersPage.swift` ← no compiled caller (`NavigationCoordinator.swift:77,100-102,147`, `GlobalSearchPage.swift:122-127`, `MemberHomePage.swift:178`, `Route.swift:62-63` all out of target); live group deep links are D24 | builder:plan's repoint + retire phase — nothing to repoint |
| R3 | repoint (iphone): `CreateGroupPage.swift` ← no compiled caller (`AddMenu.swift:65` out of target) | builder:plan's repoint + retire phase — nothing to repoint |

**Field alignment (2026-10-27).** 36 rendered fields traced model → zod → wire → `UserGroup`/Actions → screen
`State`: **27 ALIGNED** (home: org options, leader options, name, cover, member count; detail: name, cover,
created, description, visibility, age, max members, program name, lesson meta, slide labels, day lines 1–2,
member name/photo/joined, request name/date, enrollment title/description/date/cover; create: name, 1–200 on
both sides) · **2 RESHAPE** (home leader short name → D20; chart query → D21) · **7 MISSING** (org per group
SC2; detail leader name SC3; directory access SC1; lesson title + slide images SC5; day series by group SC6;
timeline SC4/SC7) · 0 RENAME · 0 DESIGN-ONLY. State that outlives the app: none new — filter selections and
search are screen `@State` (as Members, `MembersHomeContainer.swift:13`), the per-group stores in-memory (T14).
No owner notes on the three screens (`ui2-notes.mjs read`, 2026-10-27).

## Plan

The plan, with its code: `docs/features/ui2-groups-browse/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · DirectoryAccess enum + Group.memberDirectoryAccess (SC1)
- Phase 1 · Task 2 · groups payloads — org fields, creatorName, memberDirectoryAccess, D11 sync, cover trackActivity
- Phase 2 · Task 3 · group history service + GET /api/groups/:id/history (SC4)
- Phase 2 · Task 4 · next-study title, versionId, thumbnailUrl (SC5)
- Phase 2 · Task 5 · /api/home/days groupId (SC6)
- Phase 2 · Task 6 · scope GET group members + membership-history (D9)
- Phase 3 · Task 7 · fixtures — empty group, groups-home / groups-detail / create-group layers; contract freeze
- Phase 4 · Task 8 · decode models — UserGroup fields, NextStudy, GroupHistoryEvent
- Phase 4 · Task 9 · AppState group stores + myOrganizations
- Phase 4 · Task 10 · GroupActions loaders — next study, history, days, chart, my organizations
- Phase 5 · Task 11 · MakeReadyUI screen edits (D2, D22, D27)
- Phase 5 · Task 12 · GroupsHomeMapper + GroupsHomeContainer
- Phase 5 · Task 13 · UI2Navigator.replaceTop + CreateGroupContainer
- Phase 6 · Task 14 · GroupDetailMapper
- Phase 6 · Task 15 · GroupDetailContainer + GroupDetailHost
- Phase 6 · Task 16 · shell wiring + members-profile group row + residual sweep

## Prototype

Ref (via program `ui2-groups`): `groups-home`, `groups-detail`, `create-group` — d2m era 2.0
(`localhost:5961`), every screen and component **built** in `iphone/MakeReadyUI/` (d2m dots green);
`GroupsHomeScreen.swift`, `GroupsDetailScreen.swift`, `CreateGroupScreen.swift`. The repo's
`docs/ui2/` copy predates groups-detail; d2m is the source read.

## Replaced surfaces

| # | Surface (file:line) | REPLACES/ABSORBS/REUSES | Fingerprint | App |
|---|---|---|---|---|
| R1 | `iphone/MakeReady/Pages/Main/MainGroups.swift` | REPLACES (1.0 Groups tab; unreachable from `UI2Root`, left in place) | legacy groups list | iphone |
| R2 | `iphone/MakeReady/Pages/Manage/Group/GroupHomePage.swift` + `Member/GroupMembersPage.swift` | REPLACES (group home + members/requests) | legacy group home | iphone |
| R3 | `iphone/MakeReady/Pages/Manage/Group/CreateGroupPage.swift` | REPLACES (create) | legacy create form | iphone |
| R4 | `iphone/MakeReady/UI2/Containers/Groups/InviteMemberContainer.swift` | REUSES (Members `add`) | `.inviteMember` | iphone |
| R5 | `iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift` | REUSES (member row) | `.memberDetail` | iphone |

**N# — what the design adds that the app lacks (written into this SPEC):**

| # | Add | Disposition | App |
|---|---|---|---|
| N1 | merged group history feed (Timeline) | written into the SPEC — D15, SC4 | server |
| N2 | group-scoped day activity (rail series) | written into the SPEC — D14, SC6 | server |
| N3 | lesson title + activity thumbnails (Lessons up next) | written into the SPEC — D17, SC5 | server |
| N4 | three-state member directory access | written into the SPEC — D11, SC1 (read here; written by `ui2-groups-edit`) | server |
| N5 | org per group (Orgs chip) and leader name on the group | written into the SPEC — D10, SC2, SC3 | server |
| N6 | Groups tab, group page, create-group wiring | written into the SPEC — D1–D8, D12, D13, D16, D18 | iphone |
