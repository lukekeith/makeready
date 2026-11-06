# program-lesson-add-activity — spec
> md · ticket none

## Idea

**Why.** A group leader on iPhone has no way to reach activity creation or delete a lesson from the 2.0 program page, and an empty lesson shows no rail at all. The new Lessons design (Figma `4789:45890`) fixes that surface.

**What success looks like.** On `study-program-home`, every lesson's rail ends in a "+" card, an empty lesson included. The "+" opens the activity-new picker. Each lesson's chevron opens a bottom menu that can open the same picker or delete the lesson. Creating an activity is follow-on work.

**In your words.** "There is always one at the end of every lesson activity rail." → D1 · "Tapping the "+" empty activity card will open the activity-new screen to select an activity type to create." → D2 · "Add a action menu from the bottom (like everywhere else) with action buttons "Add activity" and "Delete lesson"" → D4

**The concept.** Lesson row chevron → `ActionMenuOverlay` → Add activity (picker) or Delete lesson (confirmation, then delete). Rail "+" card → picker. The picker's tiles are not connected yet.

**How it fits today.** `study-program-home` is built with d2m, and its lessons are C-063 `LessonCard`, also used by `enrollment-home` and `groups-detail`. `ActivityNewScreen` is built but has no container or `UI2Destination`, so the app can't open it. The page's `onOpenLesson` and `onOpenActivity` are unwired, as `ui2-programs` left them. `ProgramActions.deleteLesson` exists; the server renumbers later days and refuses a program's last lesson. A `LessonSchedule` owns its content, so a curriculum delete reaches enrollments only through publish and sync (schema comment on `LessonSchedule.lessonId`). The section header's "31 days" and "+" are already built, and that "+" keeps adding a lesson.

**Approaches considered.** Stop at the picker (chosen by the owner). Rejected: create and return (leaves empty activities 2.0 can't edit), open the old editors (mixes old screens into 2.0, and Exegesis needs an overlay system 2.0 lacks), connect `activities-editor` (much bigger, only text is specced).

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | Fixtures only: one new `server/fixtures/screens/activity-new.ts` layer (D18). No route, service or schema change: the existing lesson delete endpoint is used as it is | §server |
| client | ⬜ | Nothing: this is the iPhone UI 2.0 program page, web renders no C-063, and the one endpoint used is unchanged | — |
| iphone | ✅ | C-063 add card and menu button (d2m), study-program-home layout (d2m), activity-new in-app fit (d2m), activity-new route and container, lesson menu and delete flow, `ProgramActions.deleteLesson` success boundary | §iphone |

**Sequencing:** the server fixture layer first (nothing depends on it at compile time). Then, on iphone, d2m changes C-063 and the screens; the container work builds on those inputs.

**Backward compatibility:** no API or data shape changes, so a released build sees nothing new. Its existing delete behaves as before. The `deleteLesson` change (D15) is client-side only; every other caller is in the legacy `Pages/` tree, which is outside the app target.

**Blast radius:** C-063's other hosts must draw exactly as they do today (D7). Deleting a lesson changes the curriculum; enrollments see it only after publish and sync.

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
| D1 | "+" card placement | On `study-program-home`, every lesson's rail draws one "+" card after its last slide. A lesson with no activities shows the rail with the "+" card alone. Card 112×244 (Figma `4494:40744`), add icon 24 centred. No alternative was on the table. | owner 2026-11-06 |
| D2 | "+" tap | Pushes activity-new for that lesson. No alternative was on the table. | owner 2026-11-06 |
| D3 | Tile tap | Tapping any of the six tiles does nothing: no request, no navigation, no state change. Rejected: create and return (empty activities 2.0 can't edit); old editors (mixes old screens, Exegesis needs overlays); new editor (much bigger, only text specced). | owner 2026-11-06 |
| D4 | Chevron | Tapping a lesson's chevron presents `ActionMenuOverlay` with rows Add activity and Delete lesson, in that order. Add activity pushes activity-new for that lesson, after the menu has hidden. Rejected: collapse and expand (the owner wants lesson actions here instead); leaving it out (the page would not match the design). | owner 2026-11-06 |
| D5 | Only one lesson left | When the program has exactly 1 lesson, the menu omits Delete lesson. Rejected: show then explain (offers an action that can't work); allow deleting (adds server work). | owner 2026-11-06 |
| D6 | Text in slides | Slide images stay as today: `youtubeThumbnailUrl`, then `video.thumbnailUrl`, else the blank placeholder. Rejected: live text (approximates themes, changes C-079); stored screenshots (server work and a capture system). | owner 2026-11-06 |
| D7 | Other C-063 hosts | The add card and chevron appear only when the host supplies their inputs. `enrollment-home` and `groups-detail` supply neither, and their previews must not change. Rejected: adding them everywhere, because the request names the program page. | (assumed at brainstorm) |
| D8 | Delete confirmation | Delete lesson shows `ActionMenuOverlay` as a confirmation: title "Delete lesson?", message "This lesson and its activities will be permanently deleted.", destructive button "Delete lesson", then Cancel. Rejected: no confirmation, because the delete is permanent. | (assumed at brainstorm) |
| D9 | Delete result | Success: `ProgramActions.deleteLesson` updates the store and the page redraws renumbered. Failure: the page stays and a banner says "Couldn't delete the lesson", through `recordError(surface: true)` with retry. What counts as success and failure is D15 (audit, 2026-11-06). | (assumed at spec) 2026-11-06 |
| D10 | Picker strip | activity-new's C-081 strip shows that lesson's activities plus the placeholder chip. Its slide taps and add do nothing. Back pops to the program page. Rejected: hiding the strip, because that changes a built screen. | (assumed at brainstorm) |
| D11 | Lesson row wording | The row's meta reads "N mins", including "0 mins" for 0 or no estimate. "1 min" stays singular. Replaces today's "N min" and blank on this page only. | (assumed at spec) 2026-11-06 |
| D12 | d2m ownership | C-063, `StudyProgramHomeScreen` and the activity-new spec and view change through `request_project_change`, with both Figma nodes as references. The request lists: C-063 add card, chevron button and the design's two-tone meta (number `color-text-primary`, unit `color-text-secondary`, Figma `4789:45890`) only where the host opts in, so D7's hosts keep their single-tone meta; `StudyProgramHomeScreen` closures; activity-new §3 and §6 recording D3, D10 and the confirmed entry from study-program-home; and D13's fit fix. App code is in `iphone/MakeReady/UI2`. A probe on 2026-11-06 returned lane `handover` for C-063, because it has three host screens and gains a state. | (assumed at spec) 2026-11-06 |
| D13 | activity-new in the shell | `UI2Destination.activityNew` is in `isFullScreen`, so no TabBar sits under C-081, which is pinned to the bottom. The built view's `minHeight: 775` content region becomes flexible, with the grid scrolling only when it doesn't fit (activity-new §2 already says this), and captures stay unchanged. Rejected: wrapping the view in the container, because the header and bar must stay fixed and the view owns them. | auto (recommended) 2026-11-06 |
| D14 | Selected day after a delete | `StudyProgramHomeMapper` passes `activeDay` clamped to 1…max(lesson count, 1), so deleting the last-numbered lesson while its chip is selected selects the new last chip. `activeDay` state itself is not rewritten. Rejected: resetting to day 1, because it jumps the rail for a delete that didn't affect the selection. | auto (recommended) 2026-11-06 |
| D15 | Delete success boundary | Success means the DELETE returned `{ success: true }`. `ProgramActions.deleteLesson` then updates the stores, calls `state.persist()` and returns, without its `getProgram` refresh. The container then calls its existing `reload()`, as `addLesson` does, which loads every lesson page and logs a failure console-only. Failure uses `loadFailure(for:)`: cancelled is silent, 401 signs out, anything else shows D9's banner with retry and then calls `reload()`, so a row deleted elsewhere or a stale count corrects itself. One delete runs at a time (`deletingLesson`, as `addingLesson`). Rejected: keeping the refresh in the action, because a failed refresh reports a completed delete as failed, its retry then 404s, and page 1 of 30 leaves later lessons with stale numbers. | auto (recommended) 2026-11-06 |
| D16 | Lesson menu details | Rows: `add` glyph, "Add activity", standard tone; `trash-2` glyph, "Delete lesson", destructive tone. The Done button stays, as in the page's cover menu. The confirmation (D8) is `ActionMenuOverlay(title:message:actions:doneLabel: "Cancel")` with one destructive action, the `RequestDetailContainer` form, presented from the menu's `onHidden`. The container holds the chosen lesson's id from the chevron tap, so a background reload can't retarget the action. VoiceOver labels: chevron "Lesson {n} actions", add card "Add activity to lesson {n}". The chevron is a sibling of the title-block button, never inside it, because that button ignores its children for accessibility. | auto (recommended) 2026-11-06 |
| D17 | Placeholder position | The strip lists the lesson's activities by `orderNumber`, then one placeholder chip last, active, id `placeholder`, VoiceOver label "New activity". A new activity lands at the end. A lesson missing from `AppState` shows the placeholder alone. The frame's mid-strip placeholder is sample content (activity-new §2). | auto (recommended) 2026-11-06 |
| D18 | Fixtures | New layer `server/fixtures/screens/activity-new.ts`, `full` scenario, with ids clear of those in use (`fixtureId('program', 200)` and `201`). Program "Lesson Rail Samples" (`days: 3`): lessons with 2, 1 and 0 activities and `estimatedMinutes` 3, 5 and null. Program "Single Lesson Study" (`days: 1`): one lesson with 0 activities. Both are in the fixture org, created by the fixture user, and read only base entities. Rejected: adding lessons to base programs, because enrollments and schedules key on their day counts. | auto (recommended) 2026-11-06 |
| D19 | Roles | No client-side role gating on the add card or chevron, the same as the Lessons `+` beside them. The server's `programManageFilter` decides, and a refused delete arrives as 404 and shows D9's banner. Rejected: hiding by role, because the app has no program-manage capability flag and adding one is server work. | auto (recommended) 2026-11-06 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `DELETE /api/programs/:programId/lessons/:lessonId` (existing, unchanged) | server | iphone | userSession + `programManageFilter` (creator or manageable org) | none | `{ success: true }` | 401 no session · 400 last lesson (`program.days <= 1`) · 404 program not found or not manageable, or lesson not found · 500 |

## Schema & API changes

No schema change (established 2026-11-06).

## server

- **`server/fixtures/screens/activity-new.ts` (new):** the D18 layer. Layers are discovered by filename, so it runs first among the screens and must depend only on base. `server/fixtures/README.md` gets a "What `full` makes non-empty" entry.

## iphone

- **d2m (D12):** C-063 gains defaulted inputs for the trailing add card and the chevron button. `empty` keeps today's look when no add input is given; with an add input it draws the rail, which departs from ruled OQ-C-063-005 for this host only, so the contract records it. `StudyProgramHomeScreen` passes them through with new `onAddActivity(lessonIndex)` and `onOpenLessonMenu(lessonIndex)` closures. `ActivityNewScreen` gets D13's flexible content region.
- **`UI2Destination.activityNew(programId:lessonId:)`:** a new case, routed in `UI2Shell.page(for:)` and listed in `isFullScreen` (D13). It is reached only from the program page: no deep link or notification target.
- **`ActivityNewContainer` (new), in `UI2/Containers/Programs`:** maps the lesson's activities from `AppState` into `ActivityNewScreen.State` (D10, D17) with no load of its own, wires back to `navigator.pop()`, and leaves `onSelect`, `onSelectSlide` and `onAdd` as no-ops (D3, D10). `pendingType` stays "" and `createFailed` false.
- **`ProgramActions.deleteLesson`:** the D15 change. It has no other caller in the app target.
- **`StudyProgramHomeContainer`:** wires both closures, presents the lesson menu and confirmation with `actionMenuPresentation`, and runs the chosen action in `onHidden`, as the cover menu does (D16). Delete follows D15.
- **`StudyProgramHomeMapper`:** the D11 wording, D14's clamp, and the lesson count that D5 reads.

## Testing

**server (fixtures):**
- A new `server/fixtures/__tests__/activity-new.test.ts`: fixed ids clear of other layers, and the D18 lesson and activity counts, in the `study-programs.test.ts` fake-context form.

**iphone (`iphone-xctest`):**
- `StudyProgramHomeMapperTests`: D11 values (nil, 0, 1, 3), updating the existing `["12 min", ""]` assertion at `:66`; D14's clamp.
- `StudyProgramHomeContainerTests`: menu rows with 1 and with 2 or more lessons (D5, D4 order, D16 glyphs and tones); the D8 strings; `loadFailure` routing for delete (D15).
- `ProgramActionsTests` (its `api.stub` form): `deleteLesson` success removes the lesson and its activities and sends no follow-up GET; a server error leaves the stores unchanged and throws (D15).
- `UI2ShellModelTests`: `.activityNew` is full screen (D13).
- A new mapper test for the activity-new state: strip contents, placeholder last, and a missing lesson (D10, D17).
- d2m captures: C-063's new states, and the unchanged previews of `enrollment-home` and `groups-detail` (D7).

**Cross-app E2E:** none, one app.

**Human walk:**
1. Open "Lesson Rail Samples" (D18): the Lessons section matches Figma `4789:45890`, and every rail ends in a "+".
2. Its third lesson shows the "+" card alone, and reads "0 mins".
3. Tap "+": activity-new opens full screen, with that lesson's activities and the placeholder last in the strip, and with the bar fully on screen. Tap a tile: nothing happens. Back returns to the page.
4. Tap a chevron: the menu shows Add activity and Delete lesson. Add activity opens the picker.
5. Delete lesson: the confirmation appears. Cancel keeps the lesson. Confirm removes it and later lessons renumber. With the last day's chip selected, deleting that lesson selects the new last chip.
6. In "Single Lesson Study", the menu shows only Add activity.
7. An enrollment and a group page look as before.

## Out of scope

- Creating or editing activities, and connecting `activities-editor`.
- Mapping picker types to server types (activity-new §5 API-GAP).
- Opening a slide or lesson by tapping it.
- Real text or screenshots in slides (D6).
- The "+" card or chevron on `enrollment-home` and `groups-detail`.
- Any web change, and any change to the last-lesson rule.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | Tiles look tappable but do nothing (D3). | Accepted by the owner: not QA-ready until creation exists. |
| F2 | `study-program-home` has a stale d2m stop (catch-up `cmvujmxxj009dv073n1zxlbbd`, no contract change; d2m reports `hard: false`, `closeable: false`, one manual owner step). | build-time risk: the d2m task settles it; if it blocks, the owner closes it. |
| F3 | `ui2-programs` covers this page and has not been walked. | Owner's call; its walk and this one can run together. |
| F4 | Design defect: `deleteLesson` refreshes with `getProgram` after the delete has succeeded (`ProgramActions+Lessons.swift:54`). A failed refresh would show "Couldn't delete" for a completed delete, and the retry would 404. Page 1 of 30 also leaves later lessons on stale numbers, and `getProgram` only adds to the lesson index. | Fixed by D15. |
| F5 | Design defect: `ActivityNewScreen` forces a 775pt content region (`:95`). With the 56pt header and 76pt bar that is 907pt, more than the safe area on any phone, so it overflows once it leaves the capture canvas. The tab bar would also sit under C-081. | Fixed by D13. build-time risk: d2m's fit fix must keep the four frozen captures; the d2m task settles it. |
| F6 | Gap: deleting the last-numbered lesson left `activeDay` past the rail, so no chip was active. | Fixed by D14. |
| F7 | House-rule gap: the feature wires a UI 2.0 screen with no fixture layer, and base has no empty lesson or one-lesson program, so walk steps 2 and 6 had no data. `server ⬜` was wrong. | Fixed by D18 and the §Apps correction. build-time risk: the new programs may disturb fixture tests that count org programs; the server phase gate settles it. |
| F8 | Gaps in the menu: row glyphs, tones, VoiceOver labels and the chevron's relation to the title-block button were unspecified; so were the placeholder's position and the target lesson across a reload. | Fixed by D16 and D17. |
| F9 | Design: Figma `4789:45890` draws the meta in two tones ("3" primary, "mins" secondary); C-063's `metaLabel` is one tone. | Added to D12's request; D7's hosts keep one tone. |
| F10 | `D1`'s 244pt card height and C-079's 243.35pt slide (112 × 956/440) differ by under 1pt. | build-time risk: the d2m C-063 task settles it. Recommended: the add card takes the slide's height so the rail doesn't change height. |
| F11 | New `UI2/Containers` files are not picked up automatically: the project has no synchronised groups, and `makereadyui-sync.rb` covers only `MakeReadyUI/`. | build-time risk: the `ActivityNewContainer` task adds it to the app target's `project.pbxproj`, then runs `capture-targets.rb`. |
| F12 | Noted, not changed: the server's last-lesson check reads `program.days` outside its transaction, so two concurrent deletes could pass it. | Out of scope (the §Out of scope last-lesson line). Existing behaviour, reachable only by two simultaneous sessions. |

## Plan

The plan, task by task: `docs/features/program-lesson-add-activity/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · The activity-new fixture layer
- Phase 2 · Task 2 · Check d2m's delivery of the card, chevron and picker fit
- Phase 2 · Task 3 · deleteLesson succeeds when the delete does
- Phase 2 · Task 4 · Lesson wording and the selected day after a delete
- Phase 2 · Task 5 · The activity-new route and container
- Phase 2 · Task 6 · The lesson menu, confirmation and delete on the program page
