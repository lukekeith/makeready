# video-activity-basics — spec
> lg · no ticket · child 1 of the video-activity program (`docs/features/video-activity/PROGRAM.md`)

## Idea

**Why.** A video activity in the lesson editor doesn't behave like a video. Its page shows the
auto-name ("Video 1") on a blank canvas, a tap opens a one-row "Replace video" menu, there is no
way to play it or delete it from there, Review's Save is a text button unlike every other save in
the app, and video slides on the group and enrollment rails are blank. Leaders editing lessons on
iPhone meet all of it.

**What success looks like.** On the owner's phone: a video activity's page shows the video's
picture; a tap plays and pauses it; a hold opens Replace · Delete; Delete offers "Remove from
lesson" or — when nothing else uses it — "Delete video everywhere"; Review saves with the
header's purple check; and every rail shows the video's picture.

**In your words.** "Tapping the video should play/pause the video, tapping and holding should
produce the Replace, Edit, Delete action menu" → D2 · "Ask the user if they want to just delete the
activity or also delete the video from the entire library. Let the user decide. This can be done in
the delete confirmation." → D4, D5 · "the 'Save' button for the video should be in the pageHeader as
the purple circle with the checkmark" → D6.

**The concept.** The program's shared rulings P1–P6, P9–P11, with Edit left for child 2
(video-activity-edit), which adds it to this child's hold menu.

**How it fits today.** The lesson editor's video page (`readOnlyPage`) draws the activity title over
a canvas whose poster is never fetched into the image cache.[^1] Any tap opens a C-066 menu with
one row, "Replace video", which starts the inline recorder.[^2] There is no player in the editor.
The video's Cloudflare still is already on the phone as `media[videoId].posterUrl`.[^3]
`GET /api/videos/:id` already returns `lessonUseCount`, and `DELETE /api/videos/:id` refuses (409
IN_USE) while any activity names the video.[^4] Review's Retake and Save are text buttons in the
container's `VideoReviewActions`.[^5] `PageHeader(showsDone:onDone:)` and C-159 DoneCheck exist.[^6]
The server's lesson thumbnail reads only a poster or background image.[^7] video-polish already
taught the phone's slide strips to fall back to the video's still.[^8]

**Approaches considered.** No fork — the program's rulings fix the shape.

[^1]: iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift:863-893; iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:142-168, 275-277
[^2]: ActivitiesEditorScreen.swift:898-953, 3230; ActivitiesEditorContainer.swift:82, 1089
[^3]: server/src/services/content-media.service.ts:121-126; iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift:123
[^4]: server/src/routes/videos.ts:707-736, 1221-1251; iphone/MakeReady/State/Models/VideoModels.swift:52
[^5]: iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift:325-337
[^6]: iphone/MakeReadyUI/PageHeader.swift:48, 119-135; iphone/MakeReadyUI/DoneCheck.swift
[^7]: server/src/services/next-study-thumbnail.ts:7-11
[^8]: iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeMapper.swift (video-polish 6b66098e)

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | The lesson thumbnail falls back to the video's Cloudflare still; `GET /api/videos/:id` gains `versionUseCount` (D11); one posterless fixture video | §server |
| client | ⬜ | No change — re-derived at audit: no web code reads either `thumbnailFromDocument` endpoint's activity thumbnails (its rails read `activity.video.thumbnailUrl`), and no web code deletes or counts lesson uses through `GET /api/videos/:id` | — |
| iphone | ✅ | The lesson editor's video page (picture, inline player, hold menu, two-scope Delete), the Save check in both recorder layouts (d2m first) | §iphone |

**Sequencing:** server (thumbnail fallback and `versionUseCount`, tested) → d2m changes the iPhone views, owner approves
→ iPhone wiring.

**Backward compatibility:** the iPhone app is a released artifact. An old build reads the same
`thumbnailUrl` and shows the video still where it showed nothing — additive. `versionUseCount` is additive; an old build ignores it. The new
build decodes it as Optional (cached videos lack it) and treats a missing value as unknown: Delete
video everywhere stays disabled. No field is renamed or removed.

**Blast radius:** `thumbnailUrl` from `thumbnailFromDocument` feeds the group and enrollment lesson
rails on iPhone (`enrollments.ts:976` next-study, `enrollment-directory.service.ts:419` home).

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
| D1 | Video page preview | The lesson editor's video page shows the video's Cloudflare still (`media[videoId].posterUrl`, else the poster media's `posterUrl ?? url`, an image), fetched into the image cache by the container; no activity title is drawn over a video page. While the still is missing (still processing), the page shows the canvas background and a centred "Processing…" line. Rejected: the title over a blank canvas (it hides what the video is) | Luke 2026-11-24 (PROGRAM P1) |
| D2 | Tap and hold | On the video page a tap plays or pauses the video inline (D3); a press held 0.5 s opens the house C-066 action menu with Replace (renamed from "Replace video") and Delete, in that order. Edit joins between them in child 2. Rejected: a tap that opens a one-row menu (no way to play the video) | Luke 2026-11-24 (PROGRAM P2) |
| D3 | Inline playback | The video plays in the page's frame, aspect-fill like the still. It starts paused on the still, plays with sound, and stops at the end; a tap there replays from the start. Leaving the page, opening a menu, or the app going to the background pauses it. Rejected: autoplay (sound starts unasked) | (assumed at brainstorm) 2026-11-24 (PROGRAM P9) |
| D4 | Delete confirm | Delete opens a second C-066 menu titled "Delete this video?" with two destructive rows, "Remove from lesson" and "Delete video everywhere", and Cancel. Remove from lesson deletes the activity only (the existing activity delete). Delete video everywhere deletes the activity, then the library video. Rejected: one fixed scope (the owner wants to choose each time) | Luke 2026-11-24 (PROGRAM P4) |
| D5 | Delete everywhere when used elsewhere | "Delete video everywhere" is enabled only when `lessonUseCount` from `GET /api/videos/:id` is 1 or less (this activity only). Otherwise it is disabled and its subtitle reads "Used in N other lessons" (N = lessonUseCount − 1). The count is read when the confirm opens; while it loads, the row is disabled. Rejected: deleting every activity that uses it (irreversible, other lessons change); removing here and keeping it silently (the user learns after tapping) | Luke 2026-11-25 |
| D6 | Save on Review | Review's Save is the purple check (C-159) in the header. In a lesson, the "Edit lesson" header's trailing Done becomes the check while the recorder is in Review, and it saves the video; everywhere else that header keeps its Done text. Full screen shows the check top-right, inset `space-page-margin`, opposite the ✕. Retake stays on the bottom row, and the bottom row no longer has Save. Rejected: full screen only (two save styles for one action) | Luke 2026-11-24 (PROGRAM P5) |
| D7 | Delete order and failure | Delete video everywhere removes the activity first, then calls `DELETE /api/videos/:id`. If that fails (including a 409 IN_USE race), the activity stays removed and the error banner reads "Removed from the lesson, but couldn't delete the video". Rejected: video first (a failed activity delete would leave a broken page) | (assumed at brainstorm) 2026-11-25 |
| D11 | Published lessons and Delete everywhere | `GET /api/videos/:id` returns `versionUseCount`: the number of activity rows, in every lesson version of any status (program or enrollment), whose document names the video by its id or by a Media row linked to it. Supplements D5: "Delete video everywhere" is enabled only when `lessonUseCount` ≤ 1 AND `versionUseCount` ≤ 1. Disabled subtitle: `lessonUseCount` > 1 → "Used in 1 other lesson" / "Used in N other lessons"; else `versionUseCount` > 1 → "Used in a published lesson"; loading → "Checking where it's used…"; failed read or a missing count → "Couldn't check where it's used". Why: a published version keeps the same `activityKey`, so `lessonUseCount` reads 1 while DELETE still answers 409 after the draft's activity is gone. Rejected: `lessonUseCount` alone (the enabled button would always fail on a published lesson, after removing the activity); letting DELETE through (members' published lessons would lose the video) | auto (recommended) 2026-11-25 |
| D12 | Inline player type | The lesson editor plays through `AVVideoPlayer` (`VideoPlaying`), constructed with `videoGravity: .resizeAspectFill`; default gravity stays `.resizeAspect` for the video detail page. Source: `media[videoId].playbackUrl` when a non-empty URL; without one a tap does nothing. Play after the end seeks to 0 whatever the known duration (an at-end flag, since `durationSeconds` can be missing). Rejected: `VideoReviewPlayer` (it composes local clip files; an HLS stream has no composable tracks) | auto (recommended) 2026-11-25 |
| D13 | Mute hook | `AVVideoPlayer` takes `muted: Bool`, defaulting to `UserDefaults.standard.bool(forKey: "muteVideoPlayback")`; muted sets `AVPlayer.isMuted` and never activates the audio session. Agent walks launch with `-muteVideoPlayback YES`; unit tests use a fake `VideoPlaying`; captures pass no player layer. Enforces D9. Rejected: detecting XCTest in app code (a UI-tested app process is not under XCTest) | auto (recommended) 2026-11-25 |
| D14 | Confirm rows | The Delete confirm is C-066's Confirmation form (title, full-width C-048 buttons). d2m adds to `ActionItem`: `enabled: Bool = true` (C-048's existing disabled look) and `subtitle: String = ""` drawn under that button, defaults leaving every existing menu unchanged. Cancel is the `doneLabel`. Rejected: putting the reason in `message` (reads as about both buttons) | auto (recommended) 2026-11-25 |
| D15 | After a removal | When the activity delete succeeds the editor opens the activity now at the removed one's position, else the previous one, else the type grid, without saving the removed document. Activity delete on 409 NOT_DRAFT or a gone row reloads the draft, retries once by `activityKey`; a key absent from the reloaded draft counts as removed. Any other failure keeps the page, deletes no video, and shows the banner "Couldn't remove the video". While a delete runs, further menu choices are ignored. Rejected: always the first activity (loses the leader's place) | auto (recommended) 2026-11-25 |
| D16 | Still arriving | While a video page is open with no still, the container follows the video with `VideoActions.waitForVideoReady` (its 15 × 2 s limit), then reloads the draft's media; leaving the page cancels it; failures are console-only. Status `error` or the limit leaves "Processing…" until the lesson is reopened. Rejected: no poll (the editor opens cache-first, so a fresh recording would stay on "Processing…") | auto (recommended) 2026-11-25 |
| D17 | View approval in an unattended build | The d2m request's completed result, with held items settled through `approve_project_change` against this spec, stands for D10's approval in an agent build; the captures are listed in the hand-off for the owner to review. Binds activities-editor, video-recorder and C-066 only. Rejected: stopping mid-build (the owner handed the feature to agents) | auto (recommended) 2026-11-25 |
| D18 | When the header check shows | In a lesson: recorder phase is `review`, no text editor is open over it, and it is not closed. Trim, recording and saving keep the Done text (disabled). Full screen: phase `review` only. A second tap while saving does nothing (the model's `isSaving` guard). Rejected: showing it whenever the recorder is open (nothing to save) | auto (recommended) 2026-11-25 |
| D8 | Server thumbnail | `thumbnailFromDocument` returns, in order: the background image's url, the poster media's url, then the video's still (`media[content.videoId].posterUrl`); never a video's `url` (its stream): a background or poster id that names a `kind: 'video'` entry yields that entry's `posterUrl`. Rejected: iPhone only (group and enrollment rails would stay blank) | Luke 2026-11-24 (PROGRAM P6) |
| D9 | No audio in automated runs | Captures, tests and agent walks never play the inline video's sound; the player is muted under capture and in tests; sound is walked on the owner's phone | owner 2026-11-24 (PROGRAM P11) |
| D10 | d2m designs the views | The activities-editor video page (still, player slot, hold, menus, header check) and the video-recorder full-screen header check change through d2m from this spec; the owner approves before wiring | (assumed at spec) 2026-11-25 |
| D19 | A published version open with no draft yet | Supplements D11, whose counts read 1/1 here: "Delete video everywhere" is also disabled, subtitle "Used in a published lesson", when the lesson version the editor has open is not a draft (`status` ≠ draft) at the moment the Delete confirm opens. It applies after D11's `lessonUseCount` > 1 text and before enabling; loading, failed and missing keep D11's texts. Read from the `LessonVersion` already in `AppState`; `GET /api/videos/:id` and §Contract do not change. "Remove from this lesson" stays enabled. Why: the delete removes the activity from a new draft, the published row keeps the video, and DELETE answers 409. Rejected: a server count of published rows (re-opens the frozen contract) | auto (recommended) 2026-11-25 (agent walk round 1) |
| D20 | Where D19 reads the status | Supersedes D19's "Read from the `LessonVersion` already in `AppState`". When the Delete confirm opens, the editor reads the open version's current `status` from the server with the existing `GET /api/lesson-versions/:id` (beside the video read, inside the same "Checking where it's used…" state). Status not draft → D19's disabled "Used in a published lesson", in D11/D19's order. A failed status read → "Couldn't check where it's used". A version the server no longer has (404) counts as a failed read. A draft answer with 1/1 → enabled. The read only decides the confirm: it never replaces the open page's document or its unsaved edits, and a late answer for an older check is dropped. "Remove from this lesson" stays enabled throughout. Why: publishing keeps the version's id and every publish reaches the app from elsewhere, so the cached draft can be stale. §Contract does not change (the endpoint exists and the app already decodes it). Rejected: trusting the cache; dropping cached drafts on every program read (wider than this feature) | auto (recommended) 2026-11-25 (agent walk round 2) |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| Lesson activity `thumbnailUrl` (existing field, value widened) | server (`thumbnailFromDocument`) | iphone (EnrollmentHomeMapper, GroupDetailMapper) | as today | unchanged | `thumbnailUrl: string \| null` — now also the video's still for a video page with no poster (D8) | unchanged |
| `GET /api/videos/:id` (existing, one additive field) | server | iphone (Delete confirm, D5, D11) | session; as today | — | `data.lessonUseCount: number` (already returned); **new** `data.versionUseCount: number` (D11) | 404, 403 as today |
| `DELETE /api/videos/:id` (existing, unchanged) | server | iphone (Delete video everywhere, D7) | session; as today | — | as today | 409 IN_USE, 404, 403 as today |

## Schema & API changes

No schema change (established 2026-11-25).

## server

`server/src/services/next-study-thumbnail.ts` — `thumbnailFromDocument` adds the video still fallback
(D8), reading `content.videoId` and `media[videoId].posterUrl`. Unit test beside the existing one.

`content-media.service.ts` — `videoVersionUseCount(db, videoId)` (D11), counting `contentActivity` rows
whose `documentMediaRefs` name the video or its Media ids, among the activity keys that hold ACTIVITY
usage of it; exposed through `videos.service.ts`, returned by `routes/videos.ts` GET with its OpenAPI text.

Fixtures — `screens/activities-editor.ts` gains a second video activity in the draft, with its own Video
and Media rows, no poster, a still, and a draft-only use (so Delete video everywhere is enabled there).
The `base.ts` videos stay published (disabled case).

## iphone

**d2m (phase 2):**
- activities-editor video page: the still as the page image (no title); a player slot the container
  fills (a `CALayer` feed, as VideoRecorderScreen takes it) shown while playing; tap → `onVideoTap`;
  0.5 s press → the action menu Replace · Delete (`onReplace`, `onDelete`); the Delete confirm
  (D4, D5) with `deleteEverywhereEnabled: Bool` and `deleteEverywhereNote: String`; "Processing…"
  while there is no still (D1); the header's trailing Done shown as the purple check when
  `reviewSaving: Bool` is true, tap → `onReviewSave` (D6).
- video-recorder: in full screen during Review, the purple check top-right (`onSave`); the
  `reviewSlot` row keeps Retake only.

**Wiring (phase 3):**
- ActivitiesEditorContainer: fetch the still into the image cache (D1); an inline player
  (`AVVideoPlayer`, D12) for the attached video's playback URL, paused on leave/background
  (D3); the hold menu; the Delete confirm reading both counts through a VideoActions method (D5, D11);
  the still poll (D16); what opens after a removal (D15); Remove from lesson through the existing activity delete;
  Delete video everywhere per D7 through `VideoActions.deleteOrRemove(id:decision: .delete)`, which also
  drops it from the Library stores.
- VideoRecorderContainer/Model: Save leaves `VideoReviewActions`; the full-screen check and the
  lesson header check both call `model.save()` (D6); the lesson host learns the recorder is in
  Review.
- Muted player under capture and tests (D9).

## Testing

**server (vitest):** `thumbnailFromDocument` — background wins; poster next; video still next;
a video with no still returns null; never the stream url. `versionUseCount`: draft only 1; draft plus
published 2 with `lessonUseCount` 1; a published version whose document names another video not counted;
after the draft row is deleted DELETE answers 200 for the first case and 409 for the second.

**iphone (XCTest):**
- the activities-editor mapper: a video page's still URL from `media[videoId].posterUrl`; no title.
- the Delete confirm state: counts 1/1 → enabled; lessonUseCount 3 → disabled, "Used in 2 other lessons";
  2 → "Used in 1 other lesson"; 1 with versionUseCount 2 → "Used in a published lesson"; loading, failed,
  missing → disabled (D11).
- after a removal: next activity, else previous, else the grid; an activity-delete failure deletes no video.
- Delete everywhere order: activity delete first, then the video; a video-delete failure leaves the
  activity removed and reports the banner text.
- Review: the bottom row has no Save; the header check saves.
- `AVVideoPlayer`: muted never activates the session; play after the end starts at 0 with no duration.
- The inline player pauses on background and on leaving the page.

**E2E walk (agents, muted, D13):** on the fixture lesson, the posterless video page shows its still and no
title; hold shows Replace · Delete; Delete everywhere removes the activity and the Library video; a
published lesson's video shows it disabled with "Used in a published lesson"; the rails show stills.
Playback, sound and recording (Review's check) are owed to a real iPhone.

**Human verification (owner's phone):** the still on the video page and on every rail; tap to play
and pause, with sound; hold for Replace · Delete; both Delete paths, including a video used in two
lessons; Save from the header check in a lesson and full screen.

## Out of scope

- Edit on a saved video (child 2, video-activity-edit).
- The hold menu on the program home.
- Any web change beyond the thumbnails it now receives.

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | contract: DELETE /api/videos counts usage over every version (`content-media.service.ts` mediaIdsForKey), `lessonUseCount` counts distinct keys: a published lesson reads 1 and still answers 409 | D11, additive field; consequence for the owner: Delete everywhere is available only for a video never published in a lesson |
| F2 | `VideoReviewPlayer.load` composes local clips (`VideoExporter.playerItem`) and cannot play HLS | D12 |
| F3 | The editor opens cache-first, so a fresh recording's missing still never refreshes | D16 |
| F4 | C-066's Confirmation form has no disabled row or subtitle | D14, in the d2m request |
| F5 | build-time risk — d2m's shape for the player slot, press gesture and C-066 fields is known only once its request completes (settled by the d2m task; wiring follows the delivered signatures) | the d2m task |
| F6 | build-time risk — the walk env has no Cloudflare: inline playback of fixture HLS depends on the network and Stream deletion fails softly (`routes/videos.ts` continues to the database delete) | the walk; playback owed to a real iPhone |
| F7 | Auth: GET and DELETE use the same org check (`canManageOrgContent`), so a leader who can open the confirm can delete; a 403/404 on the read disables the row (D11) | no change |

## Plan

The plan, task by task: `docs/features/video-activity-basics/PLAN.md` (§PLAN.md).

- Phase 1 · Task 1 · Lesson thumbnails fall back to the video's still
- Phase 1 · Task 2 · `GET /api/videos/:id` returns `versionUseCount`
- Phase 1 · Task 3 · The posterless fixture video, and the freeze
- Phase 2 · Task 4 · d2m changes the editor, the recorder and C-066
- Phase 3 · Task 5 · The video page's picture, and following one that is still arriving
- Phase 3 · Task 6 · Tap to play inline
- Phase 4 · Task 7 · May this video be deleted everywhere?
- Phase 4 · Task 8 · Remove from lesson and Delete video everywhere
- Phase 4 · Task 9 · Review saves with the purple check

## Fixes

- [x] iphone: Delete confirm on a published lesson's video with no draft yet (versionUseCount 1) — expected "Delete video everywhere" disabled with "Used in a published lesson" (D19), saw it enabled; tapping it removed the activity, then "Removed from the lesson, but couldn't delete the video" (agent walk round 1). Ships a container test: published version open, 1/1 → disabled; draft open, 1/1 → enabled
- [x] server: `versionUseCount` counts every activity row whose document names the video — expected D11's count from the documents alone, saw `videoVersionUseCount` read only keys holding a `media_usages` ACTIVITY row and return 0 for a video without a Media row or usage row (agent walk round 1). `lessonUseCount` unchanged; the field's shape is unchanged. Ships a test
- [x] server: fixture data for published videos (Activity Player Samples "Video", Foundations of Faith "Watch") — expected the Media row (kind video, with a still) and `media_usages` ACTIVITY rows a real save writes, so counts are not 0 and the enrollment rail and editor page show the still; saw 0/0, a blank enrollment rail and "Processing…" (agent walk round 1). Update the fixture counts and their tests with it
- [x] iphone: Delete confirm on a lesson published elsewhere while the app holds its draft in cache — expected "Delete video everywhere" disabled with "Used in a published lesson" (D19, D20), saw it enabled with no note; tapping it removed the activity, then "Removed from the lesson, but couldn't delete the video" (agent walk round 2). `openDeleteConfirm` (`iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift`) reads the status from the server (D20), not `app.lessonVersions`. Ships container tests: cached `.draft` + server PUBLISHED + 1/1 → disabled; server draft + 1/1 → enabled; failed status read → "Couldn't check where it's used"; an unsaved document is untouched by the read
