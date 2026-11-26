# video-naming — spec
> 🤖 AGENT SIGNED OFF 2026-11-25 — ebe65377 · agent walk round 1 · not human-tested · evidence: .builder/video-naming/agent-walk/round-1/
> lg · no ticket

## Idea

**Why.** Every video a leader records is saved as "Video N" with no description. The Library fills
with "Video 3", "Video 4" and nothing says what each one is. Leaders recording a Library video on iPhone from the + menu meet it every time. Separately, a retried upload that succeeds still
flashes the red upload error for a moment.

**What success looks like.** On the owner's phone: after Save, a "Name your video" page offers a Title
and a Description, and within seconds three AI suggestions written from what was said; one tap fills
both fields; the check saves; the Library row shows the chosen title. Saving with nothing typed keeps
"Video N". A retry that succeeds shows no error.

**In your words.** "add a step using a text input and description like the edit-text-single-field and
edit-text-multi-field screens asking the user to name the video and give it a description" → D1, D2 ·
"process the transcript and use it to generate an appropriate title and description, then display a
list of top 3 suggestions for the user to pick from. You should be able to use the SuggestionRows for
this." → D3, D5 · "it appeared to show the error for a split second" → D9.

**The concept.** One page after Save: a Title field (C-045, as edit-text-single-field), a Description
field (multi-line, as edit-text-multi-field), and one C-051 AI Suggestions block whose C-078
SuggestionRows show three title + description pairs. The phone transcribes the clip itself, so the
suggestions arrive while the upload is already running.

**How it fits today.** Save in Review exports the clip and hands it to `VideoSaver`, which names it
"Video N" and queues the upload.[^1] The upload queue creates the server row with `title` (and can
carry `description` — `createVideoBody` already accepts it).[^2] `PATCH /api/videos/:id` updates
title and description.[^3] The shared edit-field template already draws C-051 + C-078 (states
`prompt`, `loading`, `list`, `regenerating`; rows are strings; `onGenerate`), but every caller turns it
off — the server has no field-suggestion endpoint.[^4] The server calls Claude for tag suggestions and
alt text.[^5] The on-device `VideoTranscriber` transcribes a clip or a kept window; the editor reuses
its transcript for captions.[^6] The upload queue surfaces its banner after three failures in a row.[^7]

**Approaches considered.** Two pages (Title, then Description) reusing the screens as they are — lost
to one page (one pick fills both, fewer steps). Waiting for the server's transcript — lost: minutes
after upload, so most saves would see no suggestions.

[^1]: iphone/MakeReady/Services/Video/VideoSaver.swift:86, 160-162, 207
[^2]: server/src/services/videos.service.ts:22-31
[^3]: server/src/routes/videos.ts:867-885
[^4]: iphone/MakeReadyUI/Screens/Shared/SharedEditFieldTemplate.swift:41-51, 96-127, 199-203; iphone/MakeReady/UI2/Containers/Shared/FieldEditRules.swift:115-118
[^5]: server/src/services/claude.ts:15-20, 49
[^6]: iphone/MakeReady/Services/Video/VideoTranscriber.swift:19; iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:189, 907-909
[^7]: iphone/MakeReady/Services/Video/VideoUploadController.swift:522-538

## Apps

| App | In scope | What changes | Section |
|---|---|---|---|
| server | ✅ | New `POST /api/videos/suggest-details`: a transcript in, three title + description pairs out (Claude) | §server |
| client | ⬜ | No change — the web never records video; it shows the title and description the server already returns | — |
| iphone | ✅ | The naming page after Save in the full-screen (+ menu) recorder only (d2m first), on-device transcription for it, the title and description saved with the video, the retry error flash | §iphone |

**Sequencing:** server (the endpoint, tested) → d2m designs the naming page, owner approves → iPhone
wiring.

**Backward compatibility:** additive. A new endpoint only; an old iPhone build never calls it and
keeps saving "Video N".

**Blast radius:** the new endpoint only. Titles and descriptions flow through existing fields.

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
| D1 | One naming page | After Save, one page titled "Name your video" holds a Title field (single line, the C-045/C-046 field edit-text-single-field uses), a Description field (multi-line, as edit-text-multi-field) and one C-051 AI Suggestions block, with the purple C-159 check in the header to save. Rejected: two pages, Title then Description (an extra step; a pick could not fill both) | Luke 2026-11-25 |
| D2 | Where it runs | ~~Both layouts~~ superseded 2026-11-25: the page opens only after Review's save in the full-screen recorder (the + menu, a video going straight to the Library), after its plain checkmark. The lessonInline recorder (a lesson video activity) saves exactly as today, with no naming page. Back returns to Review with nothing saved. Rejected: both places (the owner does not want the extra step when building a lesson) | Luke 2026-11-25 |
| D3 | Suggestions are pairs | The block shows at most 3 rows; each row is one suggestion, its title on the first line and its description below. Tapping a row replaces both fields with that pair. Regenerate asks again. Rejected: separate title and description lists (two picks) | Luke 2026-11-25 |
| D4 | Optional | Saving is never blocked. A trimmed-empty title saves as the automatic "Video N"; a trimmed-empty description saves as no description. Rejected: title required (blocks saving) | Luke 2026-11-25 |
| D5 | Transcript source | The page uses the transcript the editor already made when there is one; otherwise it transcribes the kept clip on the phone (`VideoTranscriber`, the window Review keeps) when the page opens, with the block in `loading`. The transcript's text is sent to D6. No transcript (no speech, or transcription failed) → the block shows no rows and its prompt copy "No speech to suggest from". Rejected: waiting for the server transcript (minutes after upload) | Luke 2026-11-25 |
| D6 | The endpoint | `POST /api/videos/suggest-details`, session auth. Body `{ transcript: string }` (1–20,000 chars). Response `{ success: true, data: { suggestions: [{ title, description }] } }` with exactly 3 suggestions, titles ≤ 80 chars, descriptions ≤ 300 chars. Claude `haiku` (CLAUDE_MODELS.haiku), one call, JSON output; any failure answers 502 `SUGGESTIONS_UNAVAILABLE`. Rejected: a per-video endpoint reading the stored transcript (the video may not exist yet) | (assumed at spec) 2026-11-25 |
| D7 | Upload starts at Save | The upload is queued at Review's save, before the naming page, as today. ~~If the server row already exists the details are PATCHed~~ superseded 2026-11-25 by D13: the row never exists before naming ends, so the details always go with the create call. Rejected: holding the whole upload until naming ends (slower; the file is the slow part) | (assumed at spec) 2026-11-25 · auto (recommended) 2026-11-25 |
| D8 | Leaving the page | Leaving the naming page by the app going to the background or the recorder closing keeps the video under "Video N"; a later save is not offered. Back returns to Review (D2) | (assumed at spec) 2026-11-25 |
| D9 | Retry error flash | The upload banner shows only for an attempt that has just failed; starting a retry, or a retry that succeeds, never shows or re-shows it. Rejected: showing a stored earlier failure while retrying (it reads as a new failure when the upload is actually going through) | Luke 2026-11-25 |
| D10 | Lesson activity title | ~~The activity title follows the video title~~ withdrawn 2026-11-25: lesson recording has no naming page (D2), so lesson videos are unchanged | Luke 2026-11-25 |
| D11 | No audio in automated runs | Transcription in tests, captures and agent walks uses seeded transcripts or silent clips; nothing plays sound on the Mac | owner 2026-11-24 |
| D12 | d2m designs the page | The naming page (fields, the pairs in C-078, its states) is built by d2m from this spec; the owner approves the screens before wiring | (assumed at spec) 2026-11-25 |
| D13 | Naming hold | An item saved from the + menu is queued with a persisted hold. While held, its export and its file upload to Stream run, but `POST /api/videos` does not, and other queue items are not blocked by it. The draft is kept on disk until naming ends. The check sets the title and description, ends the hold and discards the draft. Back removes the queue item (or cancels the export before it is queued), clears the draft's saving mark and returns to Review with the draft, its layers and its transcript as they were; no Video or Media row ever existed, so the Library gains nothing. A launch that finds a held item or a held saving draft ends the hold as "Video N" (D8) and uploads it once. An import is adopted into a draft before the save starts, so Back has a clip to return to. Rejected: creating the row and deleting it on Back (a failed delete leaves a saved video, against D2); no draft kept (Review would have nothing to play) | auto (recommended) 2026-11-25 |
| D14 | Which recorder | The naming page opens exactly when `VideoRecorderModel.entry == .plusMenu` and the save came from Review. Rejected: keying on layout (the model does not know it) | auto (recommended) 2026-11-25 |
| D15 | One transcription | A named save transcribes the kept clip once: the text feeds the suggestions and the transcript is handed to the queue item, and `VideoSaver` does not transcribe that video again. It keeps running after the check or a background exit, within the existing `transcriptHold` wait. Text sent is the editor's transcript with caption corrections (`VideoCaptions.corrected`), cut to 20,000 UTF-16 units; blank text counts as no transcript. Rejected: two transcriptions (double work for one answer) | auto (recommended) 2026-11-25 |
| D16 | Suggestions unavailable | When the request fails (any error, 401 excepted, which follows the app's sign-out rule) the block shows state `prompt` with the copy "Couldn't get suggestions" and its "AI suggestions" link asks again; it is console-only, no error banner, and saving is unaffected. A failed Regenerate keeps the rows already shown. Rejected: the error banner (suggestions are optional help, not the leader's action) | auto (recommended) 2026-11-25 |
| D17 | Stale answers and edits | A pick overwrites both fields; typing afterwards is kept; a new list never changes the fields. An answer that lands after the page was left, or after a newer request, is dropped. A second tap on the check while one is in flight does nothing. Rejected: auto-filling the first suggestion (overwrites typing) | auto (recommended) 2026-11-25 |
| D18 | Field caps | Title is capped at 80 characters and Description at 300 on the page, as D6 caps suggestions; both fields start empty and the Title placeholder is the automatic "Video N". Rejected: no cap (suggestions and typing would differ) | auto (recommended) 2026-11-25 |
| D19 | Endpoint limits | `transcript` is trimmed before the 1–20,000 check; the body is strict. The Claude call has a 20 s timeout and no SDK retries; the transcript is passed as delimited data the prompt says not to follow as instructions. Fewer than 3 usable pairs, or any pair with an empty title or description, is 502; over-long values are cut at the cap. Nothing is stored or logged from the transcript. Error body `{ success: false, error, code }`. Rejected: the SDK's 10-minute default (the page would wait) | auto (recommended) 2026-11-25 |
| D20 | Retry banner mechanics | Starting any upload attempt of an item, its success, or its removal withdraws that item's upload banner if it is still on screen, and never another error's. A transfer cancelled because iOS suspended the app backs off but does not count toward the three failures. Three counted failures in a row still surface once. Rejected: only hiding on success (the red flash shows while the retry runs) | auto (recommended) 2026-11-25 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/videos/suggest-details` (new) | server | iphone (naming page, D5) | session (requireAuth) | `{ transcript: string }`, 1–20,000 chars | `{ success: true, data: { suggestions: { title: string; description: string }[] } }` — exactly 3; title ≤ 80, description ≤ 300 | 400 `VALIDATION` (missing, blank after trim, too long, unknown key), 401, 502 `SUGGESTIONS_UNAVAILABLE` |
| `POST /api/videos` (existing, unchanged) | server | iphone (title, description at create) | as today | `description` already accepted | as today | as today |
| `PATCH /api/videos/:id` (existing, unchanged) | server | iphone (Library rename only; naming does not call it, D13) | as today | `{ title?, description? }` | as today | as today |

## Schema & API changes

No schema change (established 2026-11-25).

## server

`server/src/services/claude.ts` — `suggestVideoDetails(transcript)`: one haiku call returning 3
`{ title, description }`, trimmed and capped (D6). `server/src/routes/videos.ts` — the route, zod
body, 502 on any Claude failure or malformed output (D19). `requireAuth`; no org check — it reads and
writes no stored data. Vitest with Claude mocked.

## iphone

**d2m (phase 2):** a new `video-naming` screen: header "Name your video" with back and C-159 check;
Title and Description fields; C-051 with C-078 rows showing pairs (two lines per row); states
`generating` (C-051's name for loading), `list`, `regenerating`, `prompt` ("Couldn't get suggestions", D16), `empty` ("No speech to suggest from", no link); the block is not
hidden in any state; keyboard-safe scrolling; inputs `title`,
`description`, `aiState`, `suggestions: [(title, description)]`, `onTitleChange`,
`onDescriptionChange`, `onPick(index)`, `onRegenerate`, `onSave`, `onBack`. Owner approves (D12).

**Wiring (phase 3):**
- VideoRecorderModel: a + menu save moves to a `naming` phase (D13, D14); the naming model gets the
  transcript (D5, D15), calls VideoActions.suggestDetails, and on check stores title/description.
  Backgrounding ends naming as Video N and closes the recorder (D8).
- VideoSaver / VideoUploadController / VideoDraftStore: `VideoSave` and `VideoQueueItem` carry
  `description` and the hold, both optional so manifests written by a released build still decode;
  `VideoCreateRequest` carries `description` (`createVideoRecord` already sends it); D4's empty-title rule.
- Lesson (lessonInline) save is unchanged (D2).
- VideoUploadController and the banner seam: D9, D20.

## Testing

**server (vitest):** suggest-details — 3 pairs returned and capped; empty and oversized transcript →
400; unauthenticated → 401; Claude throws or returns malformed JSON → 502.

**iphone (XCTest):**
- naming: the editor's transcript is reused; otherwise the transcriber runs once; no transcript → empty.
- a pick fills both fields; empty title saves as "Video N"; empty description saves none.
- held: the file uploads, no create; check releases with title/description; Back leaves no row and an
  intact draft; relaunch while held uploads once as "Video N"; another queued item is not blocked (D13).
- a manifest without the new keys decodes. A failed or stale suggestion answer follows D16, D17.
- D9, D20: an attempt's start withdraws its own banner only; a suspended transfer is not counted; a retry that succeeds surfaces nothing; a failed retry after three failures surfaces once.
- a lessonInline save never opens the naming page (D2).

**Cross-app E2E walk (agent):** in a `builder-walk-*` simulator, + menu → import a **silent** clip →
Review → check → the naming page shows "No speech to suggest from"; type a title and description → check →
the Library row shows the title and the server row carries both; repeat with nothing typed ("Video N");
repeat with Back (Review returns, Library unchanged). Draft seeded with a transcript → D16's copy (the
walk server has no Claude key). Suggestion rows and real speech are owed to a real iPhone (D11).

**Human verification (owner's phone):** record from the + menu (and once in a lesson, to see no naming page); suggestions appear
within seconds and read sensibly; a pick fills both; the Library row shows the title; save with nothing
typed keeps "Video N"; force an upload failure, then a successful retry shows no error.

## Out of scope

- Renaming an existing video from the Library or video detail.
- AI suggestions on other edit-field screens.
- Any web change.
- A naming step for videos recorded inside a lesson activity (D2).

## Findings & risks

| # | Finding | Resolution |
|---|---|---|
| F1 | D2 (Back saves nothing) contradicted D7: VideoSaver discards the draft as it queues, and the queue may create the row | D13 |
| F2 | C-051 takes `[String]` rows and has no empty state, and draws its own inline rows instead of C-078; `onPick` passes a title, not an index | build-time risk — the d2m task settles the pair rows, index pick and `empty` state additively; shared-edit-field callers render unchanged |
| F3 | contract: the endpoint is new and additive; create already accepts `description`; no released build is affected | resolved |
| F4 | The persisted queue and draft manifests are a released format; a non-optional new key would drop unsent videos | §iphone: optional keys, tested |
| F5 | client ⬜ checked: no web code records video or calls the endpoint | confirmed |
| F6 | The exact cause of the flash cannot be proven by reading; candidates are a banner left up as a retry starts, and one set while suspended | build-time risk — the D9 task reproduces both as failing tests first (D20) |
| F7 | Fixtures rule: the naming page reads no server data, so no `server/fixtures/screens/video-naming.ts` (video-recorder has none either) | resolved |
| F8 | D12 reserves screen approval to the owner | the d2m task ends with captures and parks as a human step until the owner approves; server work comes first |
| F9 | Replaced surfaces: none; the recorder's + menu Save gains a step. Entry and exit edges unchanged (check → Library) | resolved |
