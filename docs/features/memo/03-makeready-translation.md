# 03 — Translating Voice Memos into MakeReady

What exists and what a voice-memo feature needs. **Analysis only — no code yet.**
Decision-shaped statements in this doc are the working notes behind the rulings; the finalized
versions live in [DECISIONS.md](DECISIONS.md), which wins on any conflict.

---

## 1. What already exists in the monorepo

### There is no audio anywhere

- **iPhone:** `AVAudioSession` appears in exactly four files
  (`Pages/Video/ActivityVideoPlayer.swift`, `Pages/Video/VideoPreviewOverlay.swift`,
  `Pages/Video/VideoActivityManager.swift`, `Pages/Media/MediaDetailOverlay.swift`) — all of it
  configuring playback for **video**. There is **no `AVAudioRecorder`, no recording UI, no audio
  model**.
- **Server:** no audio route, no audio service, no transcription. `Media.type` is
  `photo | video | document` (`server/prisma/schema.prisma:458`) and `Media.mimeType` is
  free-form, but nothing accepts an `audio/*` upload today. The `duration` column
  (`schema.prisma:469`) is already commented "for video/audio", so the field is anticipated.
- **Client:** nothing.

### What *is* reusable

| Piece | Where | How it applies |
|---|---|---|
| **R2 object storage** | `server/src/services/storage.ts` (`uploadToR2`, `deleteFromR2`, key extraction) | The obvious home for `.m4a` files. Audio is a plain object — unlike video it does **not** want Cloudflare Stream. |
| **Direct-upload pattern** | `server/src/services/cloudflare.ts:96` — "allows the iOS app to upload directly to Cloudflare without going through our server" | The same shape (server mints an upload target, device PUTs the bytes) is the right pattern for memos; it needs an R2 presigned-PUT equivalent, which does not exist yet. |
| **Media library** | `Media` + `MediaTag` + `MediaUsage`, `server/src/routes/media.ts` | Either the container for memos, or explicitly *not* — see Q M1. |
| **Notes domain** | `StudyNote` + `NoteLink`, `/api/notes` | The attach-point if a memo can belong to a note (see §4). |
| **Video recorder + teleprompter** | `iphone/MakeReady/Pages/Video/` | Precedent for a capture surface in the iPhone app, including permission handling and the capture→upload lifecycle. Read it before designing the memo recorder. |
| **Claude service** | `server/src/services/claude.ts` | Already used for tagging and alt text; the natural place for anything done *with* a transcript (summarize, extract prayer requests) once transcription exists. |

So the memo feature is **greenfield on all three apps** — "greenfield" meaning there is no
existing code to extend or work around: no model, no endpoint, no UI, nothing to migrate. Every
line gets written from scratch. That is more work than [notes](../notes/README.md), where the
server half already exists, but it is also freer — no legacy shape constrains the design.

---

## 2. The shape of the work

### 2.1 Schema

A `VoiceMemo` model is cleaner than overloading `Media`, because memos need fields `Media` has no
business carrying:

```
VoiceMemo
  id, memberId? / userId?          ← same dual-owner problem as StudyNote (Q M2)
  title                            ← REQUIRED, user-supplied (seeded with a suggestion — Q M5 decided)
  url                              ← R2 object URL
  mimeType, fileSize, duration     ← duration in ms, not seconds — the UI shows hundredths
  waveformPeaks   Json?            ← precomputed peak array for the scrubber
  transcript      Text?            ← plain text; nullable, populated async
  transcriptSegments Json?         ← [{text, startMs, endMs}] — drives tap-to-seek (doc 04 §4)
  transcriptStatus                 ← none | pending | ready | failed
  transcriptSource                 ← on_device | server  (diagnostics only; consumers never branch on it)
  recordedAt, createdAt, updatedAt
  isActive                         ← soft delete, matching StudyNote and giving us
                                     "Recently Deleted" behavior for free
```

plus a link table mirroring `NoteLink` (or a reuse of it) so a memo can hang off a lesson, a
group, an enrollment, or a note.

**`waveformPeaks` is not optional decoration.** Without a stored peak array, every client has to
download and decode the whole file to draw a scrubber. Compute it once — on device at save time
is cheapest, since the samples are already in hand.

### 2.2 Capture (iPhone)

- **`AVAudioEngine` with a single input tap — NOT `AVAudioRecorder`.** `AVAudioRecorder` never
  hands you PCM buffers, and on-device transcription needs them; one tap fans out to the file, the
  analyzer, and the waveform. Full design in
  [04-on-device-transcription.md](04-on-device-transcription.md) §1.
- Write `.m4a` AAC mono at ~64 kbps via `AVAudioFile(forWriting:settings:)`. A 10-minute memo is
  ~5 MB; that is the budget to design uploads around.
- **Pre-arm the `AVAudioSession`** when the recorder surface appears, not on the record tap.
  The zero-latency start in §3 of the [video analysis](01-video-analysis.md) is the single most
  noticeable quality difference between a good recorder and a bad one.
- Live waveform from an RMS/peak reduction over the tapped buffers at ~20 Hz into a
  right-anchored ring buffer, mapped through a non-linear dB curve. The same reduction produces
  `waveformPeaks` — no second decode pass.
- **`Info.plist`:** `NSMicrophoneUsageDescription` already exists (line 100, worded for video);
  `NSSpeechRecognitionUsageDescription` and `UIBackgroundModes` → `audio` must be **added** — see
  [04](04-on-device-transcription.md) §7. Background recording is what makes a memo survive the user
  switching apps mid-thought; it is also an App Review surface.
- The two-detent sheet is **not free in SwiftUI**. Our house rule routes every overlay through
  `/present-overlay`, and this one needs an interactive, undimmed, two-detent presentation that
  keeps the list live behind it — read
  [`docs/features/activities/09-native-ios-player.md`](../activities/09-native-ios-player.md) and
  run `/transition-review` on the diff.

### 2.3 Upload and processing (server)

- Presigned R2 PUT (new — `storage.ts` currently uploads through the server) so the audio never
  transits the API process. Feasible with one added package (`@aws-sdk/s3-request-presigner`)
  against the existing R2 `S3Client`.
- **Create-record-first** (revised per [05-implementation-readiness.md](05-implementation-readiness.md)
  F1): `POST /api/memos` with metadata (`status: pending`) → response carries the presigned URL →
  device PUTs the bytes → `PATCH /api/memos/:id/complete`. Mirrors `Media.uploadStatus` and the
  Cloudflare direct-upload flow, and means a failed upload is a sweepable `pending` row, never an
  orphaned R2 object.

### 2.4 Transcription — **DECIDED: on-device primary, Groq Whisper fallback**

**Claude cannot do this.** The Claude API accepts text, images, and PDF/text documents — there is
no audio input on any model. It is not a question of Claude being "too heavy"; transcription is
simply not a capability of the Messages API. Claude is still the right tool for what happens
*after* a transcript exists (summarize, pull out prayer requests, tag) via the existing
`server/src/services/claude.ts`.

**The deciding codebase fact:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
(`iphone/MakeReady.xcodeproj/project.pbxproj:2020`). The root `CLAUDE.md` still says "iOS 17.0+",
which is **stale**. Because our floor is genuinely iOS 26, Apple's new
[`SpeechAnalyzer` / `SpeechTranscriber`](https://www.callstack.com/blog/on-device-speech-transcription-with-apple-speechanalyzer)
is available to our *entire* iPhone install base — not a subset. That framework is on-device only,
built for long-form audio, free, offline, and private. It is exactly what real Voice Memos uses.

**Decision (2026-08-31): two paths, one contract.**

1. **iPhone → on-device `SpeechTranscriber`.** Transcribe as the recording finalizes and upload the
   text alongside the memo. Zero marginal cost, no member audio leaves the device for this
   purpose, works offline, and the `💬` glyph can appear immediately on return to the list — the
   exact behavior in the recording.
2. **Everything else → server-side Groq Whisper Large v3 Turbo.** Covers memos captured on web,
   on-device failures, and backfill. **$0.04 per hour of audio** (~$0.0007/min) at ~228× realtime.

Cost sanity check for path 2: 1,000 members recording 10 min/week is ~167 hours/week ≈ **$7/week,
under $30/month**. Even if we abandoned on-device entirely and ran everything server-side, the
bill is a rounding error. On-device is chosen for **privacy and offline behavior**, not for cost.

Alternatives priced for the record (all per hour of audio, batch/async):

| Provider | Cost/hr | Why not first choice |
|---|---|---|
| **Groq — Whisper Large v3 Turbo** | **$0.04** | chosen |
| AssemblyAI Universal-2 | $0.15 | 3.7× the cost; better diarization if we ever need per-speaker output |
| OpenAI `gpt-4o-mini-transcribe` | ~$0.18 | 4.5× |
| Deepgram Nova-3 (pre-recorded) | ~$0.26 | 6.5×; strongest feature set (diarization, redaction, keyterms) |
| OpenAI Whisper (`whisper-1`) | ~$0.36 | 9× |
| Apple `SpeechTranscriber` | $0 | on-device only — cannot serve the web client or backfill |

Note that both paths write to the **same** `transcript` / `transcriptStatus` fields, so consumers
never branch on where a transcript came from. Groq bills a 10-second minimum per request, which
matters only for very short memos.

### 2.5 Web

Everything in [02-under-the-hood.md](02-under-the-hood.md) §9 that is marked "impossible on web"
applies: no background recording, no lock-screen capture, a real permission prompt before the
first byte, and `MediaRecorder` producing `webm/opus` rather than `m4a` unless Safari is the only
target. **Recommendation: iPhone-first for capture, web for playback and transcript reading**,
and say so explicitly in the app-impact table rather than discovering it during the build.

---

## 3. What to copy, ranked

**Tier 1 — the pattern**

1. **A floating record button over the list.** One tap, no confirmation, no "new recording"
   screen. Capture begins on touch-up.
2. **The two-detent sheet.** Compact = title + timer + live waveform + one stop control, with the
   list live and undimmed behind it. Expanded = the same recording with scrubbing, transport, and
   Done. Dragging between them never touches the recording.
3. **A required, user-supplied title** — this is our one deliberate divergence from the recording.
   Apple auto-names from location; we are **not** copying that (Q M5, decided). Instead:
   - The title sits in **exactly the place the recording puts it** — centered in the sheet header,
     same type — but it is an **editable field** rather than a label, so the layout is unchanged.
   - It is seeded with a context-derived suggestion (`Romans — Lesson 3`, `Men's Group`, else
     `Memo N`) so there is always something valid in the field.
   - It is **validated on Done, never during capture.** Recording must never block on typing.
4. **Finish selects.** Done returns to the list with the new memo at the top, already expanded
   into its player.
5. **The inline row player.** Playback never leaves the list — the row expands in place with
   scrub track, ±15 s, play, and delete.
6. **Elapsed/remaining as `0:00 / −0:16`.** Small thing; makes the row read correctly.

**Tier 2**

7. Transcript, and the `💬` glyph that marks a row as having one.
8. Search across transcripts, not just titles — the highest-leverage feature in the whole app.
9. Trim (server-side ffmpeg on a range).
10. Soft delete with a retention window, so the trash button needs no confirmation.

**Tier 3 — out of scope**

Replace-in-place re-recording, layered/multi-take recording, Enhance Recording, lossless quality,
folders, favorites, multi-select management.

---

## 4. Where memo and notes converge

Both suites point at the same place: **a voice memo attached to a note**, or equivalently a note
with an audio block in it. That has three consequences worth settling before either is specced:

- The notes content-format question is now **decided as GFM markdown**
  ([`notes/03-makeready-translation.md`](../notes/03-makeready-translation.md) §2.1), and the
  embed rides on it: a paragraph containing only `[🎙 Harbor Dr 2](makeready://memo/<uuid>)` is an
  inline player in our consumers and a labelled link in any dumb renderer. No block-document
  format needed.
- It argues for **one link table**, not two. `NoteLink` already has the right shape
  (`refType`, `refId`, `metadata`); extending its `refType` set beats inventing `MemoLink`.
- It means a transcript is just note content, which makes "record a memo, get a searchable,
  editable note" the actual product — a much stronger feature than either half alone.

**Spec these together.**

---

## 5. Open questions

| # | Question | Blocks |
|---|---|---|
| M1 | New `VoiceMemo` model, or `Media` with `type: 'audio'`? (Recommendation: new model — see §2.1) | schema |
| M2 | `memberId` or `userId`? Same dual-owner question as notes (N2); answer both the same way | RBAC + endpoints |
| M3 | Presigned R2 PUT — new capability in `storage.ts`; who else needs it? | server phase |
| ~~M4~~ | ~~Transcription: on-device, server-side, or both?~~ — **DECIDED 2026-08-31: both. iPhone uses on-device `SpeechTranscriber` (our floor is genuinely iOS 26); everything else falls back to server-side Groq Whisper v3 Turbo at $0.04/hr. Claude has no audio input and is not a candidate. See §2.4.** | resolved |
| ~~M5~~ | ~~Auto-naming source?~~ — **DECIDED 2026-08-31: no location naming. The user supplies the title; the field is seeded with a context-derived suggestion and validated on Done, never during capture. See §3.3.** | resolved |
| M6 | Retention: do memos count against an org storage budget? What is the max length? | server + product |
| ~~M7~~ | ~~Web capture — in scope or playback-only?~~ — **Constrained 2026-08-31: the UI must mimic the iPhone Voice Memos app on both platforms, so web is a `/compare` twin whenever it lands. Still open is *when* web capture lands, given the platform limits in §2.5 (no background recording, permission prompt before first byte, `webm/opus` instead of `m4a`).** | app-impact scope |
| M8 | Does the member-facing app get memos, or is this leader-only in v1? | scope |

---

## 6. Next step

```
/build-spec-draft memo       → docs/features/memo/ numbered suite (01-architecture … 08-testing)
/build-spec memo             → audit → decisions → plan → build (server first, then iPhone)
```

Settle §4 first — the notes content-format decision (N1) and the memo attach-point decision are
the same decision, and getting them out of order means redoing the schema.
