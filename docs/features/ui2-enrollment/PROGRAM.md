# ui2-enrollment — program
> tier: program · design ref `--ui2 groups-enroll-program,enrollment-select-group,enrollment-select-program,enrollment-select-schedule,enrollment-select-invite-time,enrollment-select-sync,enrollment-select-access,enrollments-home,enrollment-home` (Figma section Enrollment `4674:44206`, d2m era 2.0, intake 2026-10-28)

## Overview

Leaders create and follow enrollments in the iPhone UI 2.0 shell. **Create:** a "New enrollment" checklist with six rows done in any order — group, study program, schedule, invite time, sync, accessibility — each on its own picker page, then Enroll → "Group enrolled". It opens from a group's Enrollments `add` (group preloaded), a program's enroll action (program preloaded) and the Enrollments card `add` in the TopNav (nothing preloaded). **Browse:** the Enrollments tab lists every enrollment in the org grouped by group, with search and four filters, and a row opens the enrollment's detail page (cover, facts, schedule span, per-day completion, lesson cards).

All nine screens are built as MakeReadyUI views in d2m. This program wires them to live data through app-side containers and adds the server pieces the design needs that do not exist: the exact schedule on create, a lesson-access mode that is enforced, an empty-group refusal, a completed count on the program list, an org-wide enrollments feed and an assembled enrollment-detail read. It replaces the 1.0 linear enrollment wizard (`EnrollmentFlowModal`, out of the app target since ui2-shell).

Intake record: `.builder/ui2-enrollment/brainstorm.md` — 14 of 16 settled, 3 contradictions all ruled.

## Children

| # | Feature (folder) | Size | Apps | One line | Depends on |
|---|---|---|---|---|---|
| 1 | ui2-enrollment-create | lg | server+iphone+client | A leader enrolls a group in a study program from the group page, the program page or the Enrollments TopNav `add`: six checklist rows in any order, each picker saving back, then Enroll creates exactly the schedule the calendar showed, with the chosen sync and lesson access; members of a one-at-a-time enrollment see "available on «date»" before a lesson's day | — |
| 2 | ui2-enrollments-browse | lg | server+iphone | A leader opens the Enrollments tab, searches and filters every enrollment in the org (org, group, leader, Active/Upcoming/Completed/All), opens a group from its section arrow, and opens any enrollment's detail page with its facts, schedule span, per-day completion and lesson cards | 1 |

Order: child 1 first — it changes `POST /api/enrollments` and adds `Enrollment.lessonAccess`, which child 2's reads return; and the detail page is only walkable once enrollments can be created in 2.0.

## Shared decisions

| # | Decision | Ruling | Who / date |
|---|---|---|---|
| P1 | Scope | The flow (7 screens), the Enrollments tab (enrollments-home) and the enrollment detail (enrollment-home), as two children. Rejected: the flow only; flow + tab; one spec (nothing usable until all of it lands, one long walk) | Luke 2026-10-28 |
| P2 | Exact schedule | `POST /api/enrollments` takes an optional `scheduleDates` (ISO dates, one per lesson, ascending, none before today); when present the server uses them as the lesson dates and the last as `endDate`; absent → today's `generateScheduleDates`. The app always sends the dates its calendar computed (overrides included). Rejected: sending overrides for the server to re-apply (two copies of the rule, server-local-time drift); dropping long-press overrides (a d2m change and a lost 1.0 capability) | Luke 2026-10-28 |
| P3 | Lesson access | New `Enrollment.lessonAccess` enum `ONE_AT_A_TIME` \| `ALL_AT_ONCE`, accepted by POST (the checklist always sends one). `GET /api/lessons/code/:code` refuses a ONE_AT_A_TIME lesson before its scheduled day with an "available on «date»" response, and the web member lesson page shows that message. Every existing enrollment migrates to `ALL_AT_ONCE`, so nothing members can open today gets locked. Rejected: store only (the choice would do nothing); existing rows ONE_AT_A_TIME (members lose open lessons) | Luke 2026-10-28 |
| P4 | Eligibility | The group picker lists `GET /api/groups` (already manage-filtered, active) minus groups with 0 members; `POST /api/enrollments` also refuses a 0-member group (400). The program picker lists `GET /api/programs?isPublished=true` with `days ≥ 1`. Rejected: picker-only rule (other callers could still enroll an empty group) | Luke 2026-10-28 |
| P5 | Enroll failure | The design's "no failure state" holds for validation; a network or server failure surfaces the error banner ("Couldn't enroll", Retry) and returns the checklist to `ready` (6/6). Rejected: returning silently | Luke 2026-10-28 |
| P6 | Invite time | `smsTime` + the device `timezone` are saved (smsTime already sets the LESSON event start time). Sending SMS invites at that time is a separate feature. Rejected: building the sender now (Twilio, scheduler, opt-outs) | Luke 2026-10-28 |
| P7 | Program completed count | `GET /api/programs` adds a per-program count of enrollments whose `endDate` is before today, shown by the program picker. Rejected: total enrollments under a "completed" label | Luke 2026-10-28 |
| P8 | Enrollments entries | Group page Enrollments `add` → checklist with the group preloaded; program page `onAddEnrollment` → program preloaded; TopNav Enrollments card `add` → nothing preloaded (as Groups/Programs `add` push their create pages). Done/Back on `enrolled` pops to wherever the flow started | (assumed at intake) 2026-10-28 |
| P9 | Tab status filter | Active = started and not ended · Upcoming = starts after today · Completed = ended · All. Derived from `startDate`/`endDate`; no new column. Rejected: Active/Completed only | Luke 2026-10-28 |
| P10 | Detail dead ends | Hide "Edit schedule" and the calendar glyph; day-card and lesson taps are inert (their destinations are unspecced). If `EnrollmentHomeScreen` has no way to hide them, child 2 requests the prop from d2m. Rejected: showing controls that ignore taps | Luke 2026-10-28 |
| P11 | Browse data | One new org-wide enrollments feed (grouped by group; completion %, enrolled date, recency; search/org/group/leader/status params) and one assembled enrollment-detail read (per-scheduled-day completion, lessons with activities) instead of per-group / per-lesson fan-out. "All Orgs" works as on Groups/Programs | (assumed at intake) 2026-10-28 |
| P12 | Fixtures | Each newly wired screen adds its `server/fixtures/screens/<id>.ts` layer (ui2-fixtures rule): groups with and without members, a program with lessons, enrollments that are active, upcoming and completed, both access modes, and lesson completions for the detail page | (assumed at spec) 2026-10-28 |

## Out of scope

- Sending invite SMS at the invite time (P6) — its own feature.
- Editing an enrollment's schedule (`enrollment-schedule-edit` is not designed yet); the detail page's calendar view, day-card and lesson taps (P10).
- Home dashboard followed-enrollment cards opening the detail page.
- The sync APPROVAL mode and `requireResponse` (dropped by the design; the server keeps accepting both).
- Deleting the 1.0 enrollment wizard files (out of the app target; they go with the 2.0 cutover).
- Re-speccing enrollments-home / enrollment-home in d2m: their specs cite older frames (`3823:34548`, `3773:6944`) than the owner's 2026-10-28 copies (`4751:54665`, `4751:54817`), which look the same. A drift check before child 2's iPhone phase is the design owner's job.
