# enroll-picker-hide-enrolled — spec
> md · no ticket · follow-up to ui2-enrollment-create (shipped 2026-10-28) and ui2-enrollments-browse (shipped 2026-10-29)

## Idea

**Why.** On the enrollment checklist a leader can pick a program the group is already studying (or a
group already studying the program) and is then stopped by an action menu — "Already enrolled — select
anyway" / "Choose another". The menu is avoidable: the picker already knows which pairs are taken.

**What success looks like.** With the group known, the Select program list shows every eligible program,
but those the group is currently enrolled in are muted, cannot be selected, and read "Unavailable because
currently enrolled" under the name; the same for groups when the program is known. No action menu ever
opens from either picker. The server refuses a second current enrollment of the same pair, so no path —
a stale list, two leaders at once, the web app — creates one.

**In your words.** "the ONLY programs that show up in the list are programs that are not CURRENTLY
enrolled in that group. It's okay if the group previously was enrolled in the program" → D1, D2 ·
"instead of hiding the ones that can't be selected, just mute them and don't allow them to be selected.
And for the metadata below the group or program label it should just say "Unavailable because currently
enrolled"" → D1, D3 · "We should never need an action button overlay for "already enrolled...", "choose
another...", etc." → D4, D5

**The concept.** Each picker computes the set of unavailable row ids from AppState's enrollments for the
other side of the pair (already loaded today), and hands the d2m screen a per-row unavailable flag; the
screen mutes the row, swaps its metadata line for the fixed text, and ignores taps on it. The
lesson-overlap check moves out of the group picker onto the checklist's Schedule row as an amber note.
`POST /api/enrollments` gains one guard.

**How it fits today.** Both pickers list every eligible row and run `EnrollPickerWarnings` on Select;
a hit presents C-066 with a "select anyway" row and "Choose another"[1]. "Current" there is `isActive`,
which falls back to `endDate > now` — active or upcoming[2]. The group picker also warns "Lesson already
scheduled — select anyway" when the draft's schedule dates fall on the group's existing lesson dates,
fetched by `EnrollSelectScheduleContainer.existingLessonDates`[3]. The checklist screen already has one
amber warning line, `groupIneligibleMessage`, under the Group row[4]. `POST /api/enrollments` has no
duplicate-pair check[5].
[1] iphone/MakeReady/UI2/Containers/Enrollments/EnrollPickerWarnings.swift; EnrollSelectProgramContainer.swift; EnrollSelectGroupContainer.swift
[2] iphone/MakeReady/State/Models/EnrollmentModels.swift:184 [3] EnrollSelectScheduleContainer.swift:43
[4] iphone/MakeReadyUI/Screens/Groups/GroupsEnrollProgramScreen.swift:73 [5] server/src/routes/enrollments.ts:137

**Approaches considered.** Chosen: mute + block + fixed metadata text (owner, after first choosing hide).
Rejected: hiding unavailable rows — the leader can't see why a program is missing; keeping the menus —
the owner's rule is no action menu in the pickers.

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | `POST /api/enrollments` refuses a second current enrollment of a group + program (409) | §server |
| client | ⬜ | the web LeaderApp's enroll flow already shows a failed POST's error; the 409 reaches it as an error message, no UI change | — |
| iphone | ✅ | both pickers pass unavailable rows to d2m; checklist Schedule-row overlap note; the picker warnings and both C-066 menus removed | §iphone |
| capture | ⬜ | no capture fixtures or comparisons cover these pickers | — |

**Sequencing:** server guard → verify (contract freezes) → iphone (d2m changes first, then containers).

**Backward compatibility:** a released iPhone build keeps its warning menus; the 409 reaches it only if a
leader picks "select anyway", where it shows the existing error banner. Additive and safe.

**Blast radius:** only `POST /api/enrollments` changes; every reader of enrollments is untouched.

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
| D1 | Unavailable rows | iPhone, `enrollment-select-program` and `enrollment-select-group`. When the draft has a group, a program row is **unavailable** iff that group has an enrollment of that program with `isActive` true (`endDate` after now — active or upcoming). When the draft has a program, a group row is unavailable iff that group has such an enrollment of that program. Unavailable rows stay in the list in their normal sort position, rendered muted, and a tap on them changes nothing (no pick, no Select). A pair whose enrollments all ended stays available. With neither side known, nothing is unavailable. Rejected: hiding the rows — the leader can't tell why a program is missing (owner changed hide → mute the same day). | owner 2026-10-29 |
| D2 | Which side is checked | Only the checklist's *other* field decides: the program picker checks the draft's `groupId`, the group picker checks the draft's `studyProgramId`. The row already selected in the draft is never marked unavailable against itself (re-opening a picker on a saved pair shows it selected, not muted). Rejected: checking against drafts too — a draft pair is already unique (ui2-enrollments-browse D6) and switching to it is handled there. | (assumed at spec) 2026-10-29 |
| D3 | Unavailable metadata | An unavailable row's metadata line (programs: created month · days · completed; groups: leader · members · enrollments chips) is replaced by the single text `Unavailable because currently enrolled`, muted. Title, cover/photo stay, muted. | owner 2026-10-29 |
| D4 | Already-enrolled menu | Removed from both pickers: `EnrollPickerWarnings.Warning.alreadyEnrolled`, its "Already enrolled — select anyway" label, `chooseAnother`, and both containers' `.actionMenuPresentation`. Select on an available row commits and pops immediately. Rejected: keeping the menu as a fallback — D1 makes it unreachable. | owner 2026-10-29 |
| D5 | Lesson overlap | The group picker no longer checks lesson dates and never presents a menu; the in-flight lookup (`lookupOutcome`) goes with it. Instead the checklist shows an amber warning line under the Schedule row, text `Some dates clash with this group's existing lessons`, when the draft has a group and schedule dates and any schedule date (calendar day) equals one of that group's existing lesson dates from `EnrollSelectScheduleContainer.existingLessonDates`. The Schedule row's done state and Enroll are unchanged (a warning, not a block). Rejected: keep the overlay (an action menu, against the owner's rule); hide overlapping groups (can't pick the group without first changing dates). | owner 2026-10-29 |
| D6 | Server guard | `POST /api/enrollments`, after auth and body validation and before any write: `prisma.enrollment.findFirst({ where: { groupId, studyProgramId, endDate: { gt: new Date() } } })`; a hit → `409 { success: false, error: 'already_enrolled', enrollmentId }`, nothing written (no draft deleted). Rejected: iPhone-only filtering — duplicates still possible from the web or a race. | owner 2026-10-29 |
| D7 | 409 on iPhone | The checklist's Enroll treats 409 `already_enrolled` like any failed Enroll today: the error banner, the checklist stays open with the draft intact. Banner text `This group is already enrolled in this program`. | (assumed at spec) 2026-10-29 |
| D8 | Overlap lookup timing | The checklist container fetches the group's existing lesson dates when the draft's `groupId` changes (and on appear), cache-first through `existingLessonDates`; a failed fetch shows no note (console-only). | (assumed at spec) 2026-10-29 |
| D9 | d2m inputs | Three handover changes, defaulted so every current caller compiles unchanged: `EnrollmentSelectProgramScreen.State.programUnavailable: [Bool]` and `EnrollmentSelectGroupScreen.State.groupUnavailable: [Bool]` (missing index = available; the screen mutes, swaps the metadata per D3 and drops `onPickProgram`/`onPickGroup`/`onSelect` for that index); `GroupsEnrollProgramScreen.State.scheduleWarningMessage: String = ""` (amber line under the Schedule row, same style as `groupIneligibleMessage`). | (assumed at spec) 2026-10-29 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/enrollments` (extended) | server | iphone, client | as today | as today | as today | as today + `409 { error: 'already_enrolled', enrollmentId }` when the group has an enrollment of that program with `endDate` after now (D6) |

## Schema & API changes

| # | ADD/EDIT/RENAME/REMOVE | Model.field | Wire | Reason | Status |
|---|---|---|---|---|---|
| A1 | EDIT | — | `POST /api/enrollments` 409 `already_enrolled` | D6 | planned |

No schema change (established 2026-10-29).
**Data plan:** none — no stored data changes. Existing duplicate current pairs (if any) are left as they are.

## server

`server/src/routes/enrollments.ts` POST `/enrollments`: the D6 guard placed before the transaction that
creates the enrollment, schedules, events and welcome post. Swagger block gains the 409.

## iphone

- `EnrollSelectProgramMapper` / `InviteSelectGroupMapper` (enroll path) compute `programUnavailable` /
  `groupUnavailable` per D1–D2; the containers pass them (after the d2m change lands).
- `EnrollSelectProgramContainer`, `EnrollSelectGroupContainer`: Select commits directly (D4); the
  C-066 presentations, `pendingProgramId`, `pendingWarning`, `lookup` and `lookupOutcome` removed (D5).
- `EnrollPickerWarnings`: reduced to the pure D1 predicate and the D5 overlap predicate, or removed with
  those moved to the mappers; `EnrollPickerWarningsTests` updated to match.
- `EnrollChecklistMapper` sets `scheduleWarningMessage` per D5 from the draft and the fetched lesson dates;
  `EnrollChecklistContainer` fetches them per D8.
- Enroll's error path maps 409 `already_enrolled` to D7's banner text.
- d2m: three `request_project_change` calls (D9) — `iphone/MakeReadyUI/` is never edited by hand.

## Testing

- **server:** `POST /api/enrollments` — current pair → 409 with `enrollmentId`, nothing created, the pair's
  draft still there; pair whose only enrollment ended yesterday → 201; upcoming (starts next week) → 409.
- **iphone (unit):** program mapper — group with an active, an upcoming and an ended enrollment of three
  programs → first two unavailable, third available; no group → none unavailable; the draft's own selected
  program not muted. Group mapper — the mirror. Checklist mapper — overlap date → message; no group, no
  dates, or no clash → "". 409 → D7 text.
- **iphone (UI, agent walk):** a group with a current enrollment of program P: checklist from that group →
  Select program → P muted with the text, tap does nothing, another program selects and pops with no
  menu. Mirror from a program. Overlap: pick dates that clash → amber note under Schedule, Enroll still
  enabled.
- **Cross-app E2E:** none beyond the above — the client only receives an error.

**Human verification:** on the phone, open a group with an active enrollment, + Enrollment, Select
program: the enrolled program is greyed with "Unavailable because currently enrolled" and can't be
picked; no popup appears anywhere in either picker.

## Out of scope

- A preloaded or resumed checklist whose pair is already currently enrolled shows no row warning; Enroll's
  409 banner (D7) covers it (owner direction is pickers only, 2026-10-29).
- Hiding or warning on drafts in the pickers (D2).
- The web LeaderApp's enroll picker (client ⬜).
