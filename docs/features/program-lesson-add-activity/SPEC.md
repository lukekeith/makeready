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
| server | ⬜ | Nothing: the existing lesson delete endpoint is used as it is | — |
| client | ⬜ | Nothing: this is the iPhone UI 2.0 program page, and web has no such surface | — |
| iphone | ✅ | C-063 add card and menu button (d2m), study-program-home layout (d2m), activity-new route and container, lesson menu and delete flow | §iphone |

**Sequencing:** d2m changes C-063 and the screens first; the container work builds on those inputs.

**Backward compatibility:** no API or data shape changes, so a released build sees nothing new. Its existing delete behaves as before.

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
| D9 | Delete result | Success: `ProgramActions.deleteLesson` updates the store and the page redraws renumbered. Failure: the page stays and a banner says "Couldn't delete the lesson", through `recordError(surface: true)` with retry. | (assumed at spec) 2026-11-06 |
| D10 | Picker strip | activity-new's C-081 strip shows that lesson's activities plus the placeholder chip. Its slide taps and add do nothing. Back pops to the program page. Rejected: hiding the strip, because that changes a built screen. | (assumed at brainstorm) |
| D11 | Lesson row wording | The row's meta reads "N mins", including "0 mins" for 0 or no estimate. "1 min" stays singular. Replaces today's "N min" and blank on this page only. | (assumed at spec) 2026-11-06 |
| D12 | d2m ownership | C-063, `StudyProgramHomeScreen` and the activity-new spec change through `request_project_change`, with both Figma nodes as references. App code is in `iphone/MakeReady/UI2`. | (assumed at spec) 2026-11-06 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `DELETE /api/programs/:programId/lessons/:lessonId` (existing, unchanged) | server | iphone | userSession | none | `{ success: true }` | 400 last lesson · 404 program or lesson not found · 500 |

## Schema & API changes

No schema change (established 2026-11-06).

## iphone

- **d2m (D12):** C-063 gains defaulted inputs for the trailing add card and the chevron button. `empty` keeps today's look when no add input is given. `StudyProgramHomeScreen` passes them through with new `onAddActivity(lessonIndex)` and `onOpenLessonMenu(lessonIndex)` closures.
- **`UI2Destination.activityNew(programId:lessonId:)`:** a new case, routed in `UI2Shell`.
- **`ActivityNewContainer` (new), in `UI2/Containers/Programs`:** maps the lesson's activities from `AppState` into `ActivityNewScreen.State`, wires back to `navigator.pop()`, and leaves `onSelect`, `onSelectSlide` and `onAdd` as no-ops (D3, D10).
- **`StudyProgramHomeContainer`:** wires both closures, presents the lesson menu and confirmation with `actionMenuPresentation`, and runs the chosen action in `onHidden`, as the cover menu does.
- **`StudyProgramHomeMapper`:** the D11 wording, and the lesson count that D5 reads.

## Testing

**iphone (`iphone-xctest`):**
- `StudyProgramHomeMapperTests`: D11 values (nil, 0, 1, 3).
- `StudyProgramHomeContainerTests`: menu rows with 1 and with 2 or more lessons (D5, D4 order); the D8 strings; delete success and failure (D9).
- A new mapper test for the activity-new state: strip contents and placeholder (D10).
- d2m captures: C-063's new states, and the unchanged previews of `enrollment-home` and `groups-detail` (D7).

**Cross-app E2E:** none, one app.

**Human walk:**
1. Open a program with several lessons: the Lessons section matches Figma `4789:45890`, and every rail ends in a "+".
2. An empty lesson shows the "+" card alone.
3. Tap "+": activity-new opens with that lesson's activities in the strip. Tap a tile: nothing happens. Back returns to the page.
4. Tap a chevron: the menu shows Add activity and Delete lesson. Add activity opens the picker.
5. Delete lesson: the confirmation appears. Cancel keeps the lesson. Confirm removes it and later lessons renumber.
6. In a one-lesson program, the menu shows only Add activity.
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
| F2 | `study-program-home` has a stale d2m stop (catch-up `cmvujmxxj009dv073n1zxlbbd`, no contract change). | build-time risk: the d2m task settles it; if it blocks, the owner closes it. |
| F3 | `ui2-programs` covers this page and has not been walked. | Owner's call; its walk and this one can run together. |
