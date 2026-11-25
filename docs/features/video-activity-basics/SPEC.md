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
| server | ✅ | The lesson thumbnail falls back to the video's Cloudflare still | §server |
| client | ⬜ | No change — the web's lesson rails read the same `thumbnailUrl` and simply start showing video stills; nothing else on the web touches the video page, hold menu or recorder | — |
| iphone | ✅ | The lesson editor's video page (picture, inline player, hold menu, two-scope Delete), the Save check in both recorder layouts (d2m first) | §iphone |

**Sequencing:** server (the one-line fallback, tested) → d2m changes the iPhone views, owner approves
→ iPhone wiring.

**Backward compatibility:** the iPhone app is a released artifact. An old build reads the same
`thumbnailUrl` and shows the video still where it showed nothing — additive. No field is renamed or
removed.

**Blast radius:** `thumbnailUrl` from `thumbnailFromDocument` feeds the group and enrollment lesson
rails on iPhone and web.

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
| D1 | Video page preview | The lesson editor's video page shows the video's Cloudflare still (`media[videoId].posterUrl`, else the poster media's `posterUrl`), fetched into the image cache by the container; no activity title is drawn over a video page. While the still is missing (still processing), the page shows the canvas background and a centred "Processing…" line. Rejected: the title over a blank canvas (it hides what the video is) | Luke 2026-11-24 (PROGRAM P1) |
| D2 | Tap and hold | On the video page a tap plays or pauses the video inline (D3); a press held 0.5 s opens the house C-066 action menu with Replace (renamed from "Replace video") and Delete, in that order. Edit joins between them in child 2. Rejected: a tap that opens a one-row menu (no way to play the video) | Luke 2026-11-24 (PROGRAM P2) |
| D3 | Inline playback | The video plays in the page's frame, aspect-fill like the still. It starts paused on the still, plays with sound, and stops at the end; a tap there replays from the start. Leaving the page, opening a menu, or the app going to the background pauses it. Rejected: autoplay (sound starts unasked) | (assumed at brainstorm) 2026-11-24 (PROGRAM P9) |
| D4 | Delete confirm | Delete opens a second C-066 menu titled "Delete this video?" with two destructive rows, "Remove from lesson" and "Delete video everywhere", and Cancel. Remove from lesson deletes the activity only (the existing activity delete). Delete video everywhere deletes the activity, then the library video. Rejected: one fixed scope (the owner wants to choose each time) | Luke 2026-11-24 (PROGRAM P4) |
| D5 | Delete everywhere when used elsewhere | "Delete video everywhere" is enabled only when `lessonUseCount` from `GET /api/videos/:id` is 1 or less (this activity only). Otherwise it is disabled and its subtitle reads "Used in N other lessons" (N = lessonUseCount − 1). The count is read when the confirm opens; while it loads, the row is disabled. Rejected: deleting every activity that uses it (irreversible, other lessons change); removing here and keeping it silently (the user learns after tapping) | Luke 2026-11-25 |
| D6 | Save on Review | Review's Save is the purple check (C-159) in the header. In a lesson, the "Edit lesson" header's trailing Done becomes the check while the recorder is in Review, and it saves the video; everywhere else that header keeps its Done text. Full screen shows the check top-right, inset `space-page-margin`, opposite the ✕. Retake stays on the bottom row, and the bottom row no longer has Save. Rejected: full screen only (two save styles for one action) | Luke 2026-11-24 (PROGRAM P5) |
| D7 | Delete order and failure | Delete video everywhere removes the activity first, then calls `DELETE /api/videos/:id`. If that fails (including a 409 IN_USE race), the activity stays removed and the error banner reads "Removed from the lesson, but couldn't delete the video". Rejected: video first (a failed activity delete would leave a broken page) | (assumed at brainstorm) 2026-11-25 |
| D8 | Server thumbnail | `thumbnailFromDocument` returns, in order: the background image's url, the poster media's url, then the video's still (`media[content.videoId].posterUrl`); never a video's `url` (its stream). Rejected: iPhone only (group and enrollment rails would stay blank) | Luke 2026-11-24 (PROGRAM P6) |
| D9 | No audio in automated runs | Captures, tests and agent walks never play the inline video's sound; the player is muted under capture and in tests; sound is walked on the owner's phone | owner 2026-11-24 (PROGRAM P11) |
| D10 | d2m designs the views | The activities-editor video page (still, player slot, hold, menus, header check) and the video-recorder full-screen header check change through d2m from this spec; the owner approves before wiring | (assumed at spec) 2026-11-25 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| Lesson activity `thumbnailUrl` (existing field, value widened) | server (`thumbnailFromDocument`) | iphone (EnrollmentHomeMapper, GroupDetailMapper), client (lesson rails) | as today | unchanged | `thumbnailUrl: string \| null` — now also the video's still for a video page with no poster (D8) | unchanged |
| `GET /api/videos/:id` (existing, unchanged) | server | iphone (Delete confirm, D5) | session; as today | — | `data.lessonUseCount: number` (already returned) | 404, 403 as today |
| `DELETE /api/videos/:id` (existing, unchanged) | server | iphone (Delete video everywhere, D7) | session; as today | — | as today | 409 IN_USE, 404, 403 as today |

## Schema & API changes

No schema change (established 2026-11-25).

## server

`server/src/services/next-study-thumbnail.ts` — `thumbnailFromDocument` adds the video still fallback
(D8), reading `content.videoId` and `media[videoId].posterUrl`. Unit test beside the existing one.

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
  (VideoReviewPlayer, loops false) for the attached video's playback URL, paused on leave/background
  (D3); the hold menu; the Delete confirm reading `lessonUseCount` through a VideoActions method that
  writes nothing to the view (D5); Remove from lesson through the existing activity delete;
  Delete video everywhere per D7 through VideoActions.
- VideoRecorderContainer/Model: Save leaves `VideoReviewActions`; the full-screen check and the
  lesson header check both call `model.save()` (D6); the lesson host learns the recorder is in
  Review.
- Muted player under capture and tests (D9).

## Testing

**server (vitest):** `thumbnailFromDocument` — background wins; poster next; video still next;
a video with no still returns null; never the stream url.

**iphone (XCTest):**
- the activities-editor mapper: a video page's still URL from `media[videoId].posterUrl`; no title.
- the Delete confirm state: lessonUseCount 1 → enabled; 3 → disabled, "Used in 2 other lessons";
  loading → disabled.
- Delete everywhere order: activity delete first, then the video; a video-delete failure leaves the
  activity removed and reports the banner text.
- Review: the bottom row has no Save; the header check saves.
- The inline player pauses on background and on leaving the page.

**Human verification (owner's phone):** the still on the video page and on every rail; tap to play
and pause, with sound; hold for Replace · Delete; both Delete paths, including a video used in two
lessons; Save from the header check in a lesson and full screen.

## Out of scope

- Edit on a saved video (child 2, video-activity-edit).
- The hold menu on the program home.
- Any web change beyond the thumbnails it now receives.
