# 05 — Implementation Readiness Review (memo)


> **Superseded as a decision source:** every ruling below was promoted into
> [DECISIONS.md](DECISIONS.md) on 2026-08-31. This doc remains as the *evidence record* for
> those rulings; "PROPOSED" language below is historical. DECISIONS.md wins on any conflict.

**Date:** 2026-08-31. Gap/feasibility pass requested before `/build-spec-draft memo`. Verdict:
**feasible end-to-end; the locked decisions (M4, M5, M7, engine, storage) survive scrutiny.**
Below: **PROPOSED** answers to the remaining open questions, each grounded in codebase evidence,
then the feasibility gaps the suite hadn't covered — two of which change the design in
[03](03-makeready-translation.md)/[04](04-on-device-transcription.md) and are folded back in.

---

## 1. Proposed answers to the open questions

### M1 — new `VoiceMemo` model, or `Media`? → **New model; `Media` is structurally wrong for this**

Not a taste call — `Media` cannot represent a personal memo:

- `organizationId` is **required** and `uploadedBy` is a **required `User` relation**
  (`schema.prisma:461-463, 484`). A member can't own a `Media` row at all, and a leader's private
  memo would be forced into org scope.
- `Media` carries library semantics — `visibility` defaulting to `"members"`, `MediaTag`,
  `MediaUsage`, org/group indexes. A memo is personal by default; putting it here makes privacy
  an opt-out instead of the shape of the data.

Keep the `VoiceMemo` model from [03](03-makeready-translation.md) §2.1. If a leader ever
*promotes* a memo into the org library, that's a copy into `Media`, not shared ownership.

### M2 — `memberId` or `userId`? → **Both — mirror the notes pattern exactly**

Same evidence and same ruling as notes N2: the server already runs dual route families
(`requireMemberAuth` → `req.member.id`, `requireAuth` → `req.user.id`) over one owner-agnostic
service (`routes/notes.ts:293` vs `:1193`, `notes.service.ts:389-407`). Memos copy it:
`/api/member/memos` and `/api/memos`, one `memos.service.ts`. And since the iPhone app is
session-cookie/Google auth only (`APIClient.swift:65-105`), **v1 = iPhone = leaders = `userId`**.

### M8 — member-facing or leader-only v1? → **Leader-only v1 (iPhone), member web second**

Same reasoning as notes: the reference UX is native iOS and only the leader app is native. The
dual-owner schema and route mirroring mean the member surface is additive later, not a rework.

### M3 — presigned R2 PUT → **Confirmed feasible; one small dependency**

`storage.ts` already holds a configured `S3Client` against the R2 endpoint (`storage.ts:1-33`).
Presigning is `@aws-sdk/s3-request-presigner` (`getSignedUrl(client, new PutObjectCommand(...),
{ expiresIn })`) — same SDK family as the existing `@aws-sdk/client-s3@3.991` in
`server/package.json:45`, one added package, ~20 lines. Two notes:

- `storage.ts`'s `MAX_FILE_SIZE = 5MB` (`storage.ts:9`) governs only the buffer-through-server
  path; the presigned path must enforce size itself by signing `ContentLength` (client sends the
  exact byte count when requesting the URL).
- See F1 below — the upload *sequence* should be create-record-first, which also fixes orphan
  objects.

### M6 — retention and caps → **Propose: 3 h / 100 MB, 30-day soft-delete purge, no org budget in v1**

- **Max duration 3 h** (the reference library's longest real recording is 2:42:00; at our 64 kbps
  mono that's ~84 MB) with the presign refusing `ContentLength` > **100 MB**.
- **Soft delete** (`isActive: false`) with a **30-day purge job** that deletes the R2 object and
  hard-deletes the row — this is what makes the no-confirmation trash button honest
  ([02](02-under-the-hood.md) §7).
- **No org storage budget in v1**: no budget concept exists anywhere in the schema today, and
  memos shouldn't be the feature that invents one. Revisit if member-facing scale arrives.

---

## 2. Feasibility findings

Two findings that **change the recorded design**, folded back into the suite:

| # | Finding | Change |
|---|---|---|
| **F1** | **Upload sequence inverted.** [03](03-makeready-translation.md) §2.3 said presigned PUT *then* `POST /api/memos` — which orphans R2 objects whenever the POST fails, with no reconciliation possible (the server never heard of the key). `Media` already models the right shape: `uploadStatus: pending → ready` (`schema.prisma:467`), same as the Cloudflare direct-upload flow (`cloudflare.ts:96`). | **Create-first:** `POST /api/memos` (metadata, `status: pending`) → response carries the presigned URL → device PUTs → `PATCH /api/memos/:id/complete`. A sweep job expires stale `pending` rows and their keys. |
| **F2** | **Audio-session interruptions are unhandled** in [04](04-on-device-transcription.md) — a phone call, Siri, or another app taking the session kills capture, and the whole point of a memo is surviving interruption. Real Voice Memos auto-pauses and salvages. | Handle `AVAudioSession.interruptionNotification`: on `.began` → pause engine + UI shows paused; on `.ended` with `.shouldResume` → resume. Handle route changes (`routeChangeNotification`) the same way. The `.m4a` on disk plus F3's draft record make a killed session recoverable. |

The rest, ranked:

| # | Finding | Severity | Ruling |
|---|---|---|---|
| F3 | **Crash/kill salvage.** If the app dies mid-recording, a valid partial `.m4a` sits in the container with no record anywhere. | High | Write a local **draft manifest** (URL, startedAt, title draft) when capture starts; on next launch, offer the salvaged recording. Transcript comes from the file-based re-run path ([04](04-on-device-transcription.md) §5). |
| F4 | **The two-detent sheet collides with house overlay rules.** SwiftUI `.sheet`/`presentationDetents` would be the easy route, but the app's typed `Route` + `presentModal` system (`Services/Route.swift`) is the mandated chrome, and native sheets are forbidden by `/present-overlay`. An interactive, undimmed, finger-tracked two-detent surface inside that system is the **largest single UI build item** in the feature. | High | Budget it as its own task; scaffold via `/present-overlay`, review via `/transition-review`. The finger-tracked reversible morph work in the navigation spec (`docs/features/navigation/`) is the closest prior art. |
| F5 | **Groq request size limit.** Hosted Whisper endpoints cap upload size (OpenAI: 25 MB; Groq's limit is tier-dependent — **verify current docs**). A 3 h memo at ~84 MB may exceed it. | Med | Server fallback chunks long audio (ffmpeg segment at silence boundaries, offset the returned segment timestamps). Only affects the fallback path — on-device has no such limit. |
| F6 | **Web capture format.** `MediaRecorder` yields `webm/opus` on Chrome; iOS Safari won't reliably play webm. | Med | Already deferred with web capture (M7): when it lands, server transcodes to `.m4a` on complete (ffmpeg), so every stored memo is one format. Playback-only web is unaffected. |
| F7 | **Offline capture → upload queue.** Recording offline must succeed (capture + on-device transcript are both local); the upload queues and flushes on reconnect, reusing F1's `pending` lifecycle. | Med | State it in 06-iphone; the AppState disk-cache pattern is the precedent. |
| F8 | **AAC write path.** `AVAudioFile(forWriting:settings:)` with AAC settings converts written PCM to AAC, but the buffers must match the file's **`processingFormat`** — the tap's native format usually does, the point where it doesn't (e.g. after a route change to a different sample rate) needs the same `BufferConverter` treatment as the analyzer feed. | Low | One integration test: record across a route change, file stays valid. |
| F9 | **Live transcription duty cycle.** Streaming analysis for hours costs battery. | Low | Acceptable for v1 (memos skew short); the file-based path is the escape hatch if profiling disagrees. |
| F10 | **Doc numbering collision** with the `/build-spec` suite (`01–09` at feature root). | Med | Move `01–05` analysis docs to `docs/features/memo/analysis/` before running the draft. |

---

## 3. What `/build-spec-draft memo` still has to do

With §1 confirmed: the frozen endpoint table (create-first lifecycle from F1), the `VoiceMemo` +
`MemoLink`-via-`NoteLink` schema wording, the iPhone `AppState`/Actions/Route additions including
the F4 detent surface, the capture pipeline as [04](04-on-device-transcription.md) §8's build
order, gates, E2E walk, and the ledger. Nothing else blocks starting it.
