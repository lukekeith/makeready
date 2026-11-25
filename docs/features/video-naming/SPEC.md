# video-naming — spec
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
| D7 | Upload starts at Save | The upload is queued at Review's save, before the naming page, as today. The page's check stores the title and description on the queue item; if the server row already exists, they are sent with `PATCH /api/videos/:id`, otherwise with the create call. Rejected: holding the upload until naming ends (slower; a leader who leaves the page loses nothing today) | (assumed at spec) 2026-11-25 |
| D8 | Leaving the page | Leaving the naming page by the app going to the background or the recorder closing keeps the video under "Video N"; a later save is not offered. Back returns to Review (D2) | (assumed at spec) 2026-11-25 |
| D9 | Retry error flash | The upload banner shows only for an attempt that has just failed; starting a retry, or a retry that succeeds, never shows or re-shows it. Rejected: showing a stored earlier failure while retrying (it reads as a new failure when the upload is actually going through) | Luke 2026-11-25 |
| D10 | Lesson activity title | ~~The activity title follows the video title~~ withdrawn 2026-11-25: lesson recording has no naming page (D2), so lesson videos are unchanged | Luke 2026-11-25 |
| D11 | No audio in automated runs | Transcription in tests, captures and agent walks uses seeded transcripts or silent clips; nothing plays sound on the Mac | owner 2026-11-24 |
| D12 | d2m designs the page | The naming page (fields, the pairs in C-078, its states) is built by d2m from this spec; the owner approves the screens before wiring | (assumed at spec) 2026-11-25 |

## Contract

| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| `POST /api/videos/suggest-details` (new) | server | iphone (naming page, D5) | session (requireAuth) | `{ transcript: string }`, 1–20,000 chars | `{ success: true, data: { suggestions: { title: string; description: string }[] } }` — exactly 3; title ≤ 80, description ≤ 300 | 400 `VALIDATION` (missing/too long), 401, 502 `SUGGESTIONS_UNAVAILABLE` |
| `POST /api/videos` (existing, unchanged) | server | iphone (title, description at create) | as today | `description` already accepted | as today | as today |
| `PATCH /api/videos/:id` (existing, unchanged) | server | iphone (title, description after create, D7) | as today | `{ title?, description? }` | as today | as today |

## Schema & API changes

No schema change (established 2026-11-25).

## server

`server/src/services/claude.ts` — `suggestVideoDetails(transcript)`: one haiku call returning 3
`{ title, description }`, trimmed and capped (D6). `server/src/routes/videos.ts` — the route, zod
body, 502 on any Claude failure or malformed output. Vitest with Claude mocked.

## iphone

**d2m (phase 2):** a new `video-naming` screen: header "Name your video" with back and C-159 check;
Title and Description fields; C-051 with C-078 rows showing pairs (two lines per row); states
`loading`, `list`, `regenerating`, `empty` ("No speech to suggest from"); inputs `title`,
`description`, `aiState`, `suggestions: [(title, description)]`, `onTitleChange`,
`onDescriptionChange`, `onPick(index)`, `onRegenerate`, `onSave`, `onBack`. Owner approves (D12).

**Wiring (phase 3):**
- VideoRecorderModel: save moves to a `naming` phase after the export is queued (D7); the naming
  model transcribes (D5), calls VideoActions.suggestDetails, and on check stores title/description.
- VideoSaver / VideoUploadController: the queue item carries `description`; a title or description set
  after create is sent by PATCH (D7); D4's empty-title rule.
- Lesson (lessonInline) save is unchanged (D2).
- VideoUploadController: D9.

## Testing

**server (vitest):** suggest-details — 3 pairs returned and capped; empty and oversized transcript →
400; unauthenticated → 401; Claude throws or returns malformed JSON → 502.

**iphone (XCTest):**
- naming: the editor's transcript is reused; otherwise the transcriber runs once; no transcript → empty.
- a pick fills both fields; empty title saves as "Video N"; empty description saves none.
- title/description go with create when the row does not exist yet, else by PATCH.
- D9: a retry that succeeds surfaces nothing; a failed retry after three failures surfaces once.
- a lessonInline save never opens the naming page (D2).

**Human verification (owner's phone):** record from the + menu (and once in a lesson, to see no naming page); suggestions appear
within seconds and read sensibly; a pick fills both; the Library row shows the title; save with nothing
typed keeps "Video N"; force an upload failure, then a successful retry shows no error.

## Out of scope

- Renaming an existing video from the Library or video detail.
- AI suggestions on other edit-field screens.
- Any web change.
- A naming step for videos recorded inside a lesson activity (D2).
