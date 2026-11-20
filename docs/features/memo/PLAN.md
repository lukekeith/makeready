# memo — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** the voice-memo engine — a private `VoiceMemo` stored by the server with presigned R2 upload, Groq fallback transcription and a maintenance job, and the iPhone recorder/transcriber/upload-queue engine plus its state, with no UI.

**Architecture:** server first — `voice_memos`, `memos.service.ts` (all rules), `transcription.service.ts` (Groq + ffmpeg, single-flight), a 15-min job, thin `/api/memos` routes; its last task freezes §Contract. Then the iPhone against the frozen contract: models + `AppState` + `MemoActions`, the audio engine, the persistent per-user `MemoUploadController`. Nothing in the UI calls the engine (D28).

**Tech Stack:** server — Express, Prisma/Atlas, zod, `@aws-sdk/s3-request-presigner`, Groq, ffmpeg, vitest. iphone — Swift iOS 26, `AVAudioEngine`, `SpeechAnalyzer`, `NWPathMonitor`, XCTest.

**Spec:** `docs/features/memo/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(memo): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–3 | `voice_memos`; storage presign PUT/GET, sized HEAD, download; single-flight Groq fallback; ffmpeg in the images |
| 2 | server | 4–8 | memo lifecycle, reads, maintenance job, `MEMO` links, the `/api/memos` routes, user-delete purge; **§Contract freezes** |
| 3 | iphone | 9–10 | memo models, `AppState` memo stores and `MemoActions`; the D27 Info.plist strings |
| 4 | iphone | 11–13 | transcriber, recorder engine (tap → `.caf` → `.m4a`, peaks, limit), session/interruptions/draft manifests |
| 5 | iphone | 14–15 | the persistent per-user upload queue: lifecycle, re-mint, backoff, 401 pause, tenancy, launch salvage |

---

### Task 1: `VoiceMemo` schema and migration
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/schema/schema.yaml` — add the `VoiceMemo` model (after `StudyNote`, `:3374-3425`) and a `voiceMemos: one_to_many → VoiceMemo` relation on `User`
- Modify (generated): `server/prisma/schema.prisma`, `server/atlas/.schema.hcl` — by `npm run schema:generate`, never by hand
- Create (generated): `server/atlas/migrations/<timestamp>_voice_memos.sql` and the updated `atlas.sum` — by Atlas `migrate diff`
- Test: `server/test/voice-memo-schema.test.ts` — defaults and the user cascade

**Interfaces:**
- Produces: Prisma model `VoiceMemo` (`prisma.voiceMemo`), table `voice_memos`; `User.voiceMemos`. Columns exactly as SC1; string status columns with no DB enum.

**Behaviour:**
- the model is SC1 verbatim; no `url` column (D31); `transcriptClaimedAt` exists (D32); `deletedAt` exists (D6)
- deleting a `User` deletes their memos by cascade (SC1, D35)
- the migration is additive only: one `CREATE TABLE` + its indexes + FK; nothing else changes (Data plan)

The YAML (source of truth — the migration is generated from it):

```yaml
  VoiceMemo:
    table_name: voice_memos
    fields:
      id: { type: uuid, primary: true, default: uuid() }
      userId: { type: string, nullable: true }
      memberId: { type: string, nullable: true }
      title: { type: string }
      key: { type: string }
      mimeType: { type: string, default: "audio/mp4" }
      fileSize: { type: int, nullable: true }
      durationMs: { type: int, nullable: true }
      waveformPeaks: { type: json, nullable: true }
      transcript: { type: text, nullable: true }
      transcriptSegments: { type: json, nullable: true }
      transcriptStatus: { type: string, default: "none", description: "none, pending, ready, failed" }
      transcriptSource: { type: string, nullable: true, description: "on_device, server" }
      transcriptAttempts: { type: int, default: 0 }
      transcriptClaimedAt: { type: datetime, nullable: true }
      uploadStatus: { type: string, default: "pending", description: "pending, ready" }
      recordedAt: { type: datetime }
      isActive: { type: boolean, default: true }
      deletedAt: { type: datetime, nullable: true }
      createdAt: { type: datetime, default: now() }
      updatedAt: { type: datetime, updatedAt: true }
    relations:
      user: { type: many_to_one, target: User, fields: [userId], references: [id], onDelete: Cascade, nullable: true }
    indexes:
      - fields: [userId, recordedAt]
      - fields: [memberId, recordedAt]
      - fields: [uploadStatus, createdAt]
```

Write it in `StudyNote`'s block style. `memberId` has no relation in v1 (D8).

**Pattern:**
- `server/schema/schema.yaml:3374-3425` — `StudyNote`, the dual-owner block this copies

**Tests:**
- `a memo row gets the SC1 defaults`

```ts
it('a memo row gets the SC1 defaults', async () => {
  const memo = await prisma.voiceMemo.create({ data: { userId, title: 'Memo 1', key: 'memos/u/m.m4a', recordedAt: new Date() } })
  expect(memo).toMatchObject({ mimeType: 'audio/mp4', transcriptStatus: 'none', transcriptSource: null, transcriptAttempts: 0,
    transcriptClaimedAt: null, uploadStatus: 'pending', isActive: true, deletedAt: null, memberId: null })
  expect('url' in memo).toBe(false)
})
```

> ⚠ build-time risk (F20): `npm run schema:diff` runs `dotenv --`, which reads the `server/.env` 1Password pipe. Run `npm run schema:generate`, then `cd server/atlas && ../scripts/atlas.sh migrate diff voice_memos --env local --var database_url=postgresql://postgres:postgres@localhost:5434/postgres` with that explicit URL. Never open `server/.env`.

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`prisma.voiceMemo` is undefined)
- [ ] **Step 2:** Add the YAML, run `npm run schema:generate` and `npm run schema:validate`, then generate the migration as the risk note says; read the generated SQL and confirm it is one `CREATE TABLE "voice_memos"`, its three indexes and one FK to `users` with `ON DELETE CASCADE`, and nothing else
- [ ] **Step 3: `npx prisma generate`; run them — PASS**
- [ ] **Step 4: Commit** — `feat(memo): VoiceMemo model and migration`

### Task 2: storage presign, HEAD with size, download
App: server
Phase: 1
Recipe: /api · tiny

**Files:**
- Modify: `server/src/services/storage.ts` — add `presignClientConfig`, `presignPut`, `presignGet`, `headObject`, `downloadObject`
- Modify: `server/package.json` / `package-lock.json` — add `@aws-sdk/s3-request-presigner` at the same version line as `@aws-sdk/client-s3` (`:47`)
- Modify: `server/.env.example:25-30` — add `R2_PRESIGN_ENDPOINT=` (commented: optional, local dev only, D34)
- Test: `server/src/services/__tests__/storage-presign.test.ts`

**Interfaces:**
- Produces: `presignClientConfig(env)` — `r2ClientConfig(env)` with `endpoint = R2_PRESIGN_ENDPOINT`, `forcePathStyle: true` when that is non-empty
- Produces: `presignPut(key, contentType, contentLength, expiresInSeconds)` → URL; `presignGet(key, expiresInSeconds)` → URL
- Produces: `headObject(key)` → `{ contentLength } | null` (null on not-found, else rethrow, as `objectExists`, `storage.ts:67-76`); `downloadObject(key)` → `Buffer`

**Behaviour:**
- presigning uses a second cached `S3Client` built from `presignClientConfig()` only when `R2_PRESIGN_ENDPOINT` is set, else the normal client (D34)
- `presignPut` signs `ContentType` and `ContentLength`; the URL's `X-Amz-SignedHeaders` includes `content-length` and `content-type` — pass `signableHeaders: new Set(['content-type','content-length'])` to `getSignedUrl` if the default omits them (D9, F21)
- `presignGet` is a `GetObjectCommand` presign (D31)

**Pattern:**
- `server/src/services/__tests__/storage-endpoint.test.ts:1-30` — env-object testing of the config

**Tests:**
- `presignPut signs content-length and content-type and expires in 15 min` (D9, F21, D31)

```ts
const env = { R2_ACCOUNT_ID: 'acct', R2_ACCESS_KEY_ID: 'key', R2_SECRET_ACCESS_KEY: 'secret', R2_ENDPOINT: 'http://localhost:9010', R2_BUCKET_NAME: 'b' }
beforeEach(() => { Object.assign(process.env, env); delete process.env.R2_PRESIGN_ENDPOINT })

it('presignPut signs content-length and content-type and expires in 15 min', async () => {
  const url = new URL(await presignPut('memos/u1/m1.m4a', 'audio/mp4', 1234, 900))
  const signed = url.searchParams.get('X-Amz-SignedHeaders')!.split(';')
  expect(signed).toEqual(expect.arrayContaining(['content-length', 'content-type', 'host']))
  expect(url.searchParams.get('X-Amz-Expires')).toBe('900')
  expect(url.pathname).toBe('/b/memos/u1/m1.m4a')
  expect(new URL(await presignGet('memos/u1/m1.m4a', 3600)).searchParams.get('X-Amz-Expires')).toBe('3600')
})
```

- `R2_PRESIGN_ENDPOINT changes the signed host` (D34)

```ts
it('R2_PRESIGN_ENDPOINT changes the signed host', async () => {
  expect(presignClientConfig({ ...env, R2_PRESIGN_ENDPOINT: 'http://192.168.1.5:9090' })).toMatchObject({ endpoint: 'http://192.168.1.5:9090', forcePathStyle: true })
  expect(presignClientConfig({ ...env, R2_PRESIGN_ENDPOINT: '' }).endpoint).toBe('http://localhost:9010')
})
```

- `headObject returns the size, and null when absent` (D13)

```ts
it('headObject returns the size, and null when absent', async () => {
  const send = vi.spyOn(S3Client.prototype, 'send')
  send.mockResolvedValueOnce({ ContentLength: 42 } as never)
  expect(await headObject('k')).toEqual({ contentLength: 42 })
  send.mockRejectedValueOnce(Object.assign(new Error('nf'), { name: 'NotFound', $metadata: { httpStatusCode: 404 } }))
  expect(await headObject('k')).toBeNull()
  send.mockRejectedValueOnce(Object.assign(new Error('boom'), { $metadata: { httpStatusCode: 500 } }))
  await expect(headObject('k')).rejects.toThrow('boom')
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`presignPut` is not exported)
- [ ] **Step 2:** `npm install @aws-sdk/s3-request-presigner` in `server/`; implement the five functions in `storage.ts` to the Behaviour; add the env line
- [ ] **Step 3: Run them — PASS**
- [ ] **Step 4: Commit** — `feat(memo): presigned R2 PUT/GET and sized HEAD`

### Task 3: Groq fallback transcription service and ffmpeg
App: server
Phase: 1
Recipe: /api

**Files:**
- Create: `server/src/services/transcription.service.ts` — `transcribeMemo`, the Groq client, the ffmpeg splitter
- Modify: `server/Dockerfile:35` (production `node:20-slim` stage) and `server/Dockerfile.dev:13-16` — add `ffmpeg` to the apt install (D23)
- Modify: `server/.env.example` — `GROQ_API_KEY=` and `GROQ_MAX_UPLOAD_BYTES=26214400`
- Test: `server/src/services/__tests__/transcription.test.ts` (DB-backed; storage and Groq stubbed)

**Interfaces:**
- Consumes: `downloadObject(key)` from Task 2; `prisma.voiceMemo` from Task 1
- Produces: `transcribeMemo(memoId, deps?: { groq?, splitAudio?, env? })` → `'ready' | 'failed' | 'no-key' | 'not-claimed'`
- Produces: type `GroqClient` — `transcribe(audio: Buffer, filename)` → `{ text, segments: { text, startMs, endMs }[] }`; `createGroqClient(apiKey)`
- Produces: type `SplitAudio` — `(audio: Buffer, maxBytes)` → `{ audio: Buffer; offsetMs }[]`; `ffmpegSplitAudio`
- Produces: `TRANSCRIPT_MAX_ATTEMPTS = 3`, `CLAIM_STALE_MS = 600_000`

**Behaviour:**
- no `GROQ_API_KEY` → `transcriptStatus: 'failed'`, `transcriptAttempts` untouched, logged only when it was `pending`; `'no-key'`, Groq not called (D33)
- the claim is one atomic `updateMany` (D32); zero rows → `'not-claimed'`, nothing else happens:

```ts
where: { id: memoId, isActive: true, uploadStatus: 'ready', transcriptStatus: { in: ['pending', 'failed'] },
         transcriptAttempts: { lt: TRANSCRIPT_MAX_ATTEMPTS },
         OR: [{ transcriptClaimedAt: null }, { transcriptClaimedAt: { lt: new Date(Date.now() - CLAIM_STALE_MS) } }] },
data:  { transcriptClaimedAt: new Date() }
```

- download; up to `GROQ_MAX_UPLOAD_BYTES` (default 26 214 400) sent whole at `offsetMs: 0`, above it `splitAudio(buffer, max)` (D5, D23)
- merge: `transcript` = chunk texts trimmed and joined with one space; each segment's `startMs`/`endMs` += its chunk's `offsetMs`, in chunk order (D5)
- success → `transcript`, `transcriptSegments`, `transcriptStatus: 'ready'`, `transcriptSource: 'server'`, `transcriptClaimedAt: null`; return `'ready'`
- any error → `transcriptAttempts` +1, `'failed'`, claim cleared, logged; `'failed'`; never throws (D33)
- `createGroqClient` posts multipart to `https://api.groq.com/openai/v1/audio/transcriptions` with `model=whisper-large-v3-turbo`, `response_format=verbose_json`, `Authorization: Bearer <key>`; segment `start`/`end` seconds → `Math.round(s * 1000)` ms; non-2xx throws (D5)
- `ffmpegSplitAudio` runs `ffmpeg -i <tmp> -af silencedetect=noise=-30dB:d=0.4 -f null -` to collect `silence_end` times, then walks them choosing, for each chunk, the last silence end whose estimated size `(t - chunkStart) / totalDurationMs * totalBytes` stays ≤ 0.9 × `maxBytes` (a hard cut at that size when no silence qualifies), and cuts each with `ffmpeg -ss <a> -to <b> -i <tmp> -c copy -f mp4 <out>`; offsets are the cut starts in ms; temp files removed in `finally` (D23)

> ⚠ build-time risk (F2): Groq's per-request cap is unverified. Check Groq's speech-to-text docs; if it differs from 25 MB, say so in your report — the value stays config (`GROQ_MAX_UPLOAD_BYTES`).
> ⚠ build-time risk (F22): CI has no ffmpeg. Every test stubs `splitAudio`; no test spawns ffmpeg.

**Tests:** (memo seeded `uploadStatus: 'ready'`, `transcriptStatus: 'pending'`; `downloadObject` mocked as `test/media-upload-taken-at.test.ts:5`; `GROQ_API_KEY='k'`)

- `writes the Groq transcript and segments` (D5)

```ts
it('writes the Groq transcript and segments', async () => {
  const groq = { transcribe: vi.fn(async () => ({ text: ' hello world ', segments: [{ text: 'hello world', startMs: 0, endMs: 1200 }] })) }
  const splitAudio = vi.fn()
  expect(await transcribeMemo(memo.id, { groq, splitAudio })).toBe('ready')
  expect(splitAudio).not.toHaveBeenCalled()
  expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcript: 'hello world',
    transcriptSegments: [{ text: 'hello world', startMs: 0, endMs: 1200 }], transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null })
})
```

- `chunks over the cap and offsets their segments` (D5, D23)

```ts
it('chunks over the cap and offsets their segments', async () => {
  download.mockResolvedValueOnce(Buffer.alloc(25))
  const splitAudio = vi.fn(async () => [{ audio: Buffer.alloc(12), offsetMs: 0 }, { audio: Buffer.alloc(13), offsetMs: 60000 }])
  const groq = { transcribe: vi.fn().mockResolvedValueOnce({ text: 'a', segments: [{ text: 'a', startMs: 0, endMs: 2000 }] })
                                   .mockResolvedValueOnce({ text: 'b', segments: [{ text: 'b', startMs: 0, endMs: 2000 }] }) }
  await transcribeMemo(memo.id, { groq, splitAudio, env: { ...process.env, GROQ_API_KEY: 'k', GROQ_MAX_UPLOAD_BYTES: '10' } })
  expect(splitAudio).toHaveBeenCalledWith(expect.any(Buffer), 10)
  const row = await prisma.voiceMemo.findUnique({ where: { id: memo.id } })
  expect(row!.transcript).toBe('a b')
  expect(row!.transcriptSegments).toEqual([{ text: 'a', startMs: 0, endMs: 2000 }, { text: 'b', startMs: 60000, endMs: 62000 }])
})
```

- `a missing key fails without counting an attempt` (D33)

```ts
it('a missing key fails without counting an attempt', async () => {
  const groq = { transcribe: vi.fn() }
  expect(await transcribeMemo(memo.id, { groq, env: { ...process.env, GROQ_API_KEY: '' } })).toBe('no-key')
  expect(groq.transcribe).not.toHaveBeenCalled()
  expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcriptStatus: 'failed', transcriptAttempts: 0 })
})
```

- `a Groq error counts an attempt and fails` (D33)

```ts
it('a Groq error counts an attempt and fails', async () => {
  const groq = { transcribe: vi.fn(async () => { throw new Error('502') }) }
  expect(await transcribeMemo(memo.id, { groq })).toBe('failed')
  expect(await prisma.voiceMemo.findUnique({ where: { id: memo.id } })).toMatchObject({ transcriptStatus: 'failed', transcriptAttempts: 1, transcriptClaimedAt: null })
})
```

- `a fresh claim blocks a second run; a stale one does not` (D32)

```ts
it('a fresh claim blocks a second run; a stale one does not', async () => {
  await prisma.voiceMemo.update({ where: { id: memo.id }, data: { transcriptClaimedAt: new Date(Date.now() - 60_000) } })
  expect(await transcribeMemo(memo.id, { groq: okGroq })).toBe('not-claimed')
  await prisma.voiceMemo.update({ where: { id: memo.id }, data: { transcriptClaimedAt: new Date(Date.now() - 11 * 60_000) } })
  expect(await transcribeMemo(memo.id, { groq: okGroq })).toBe('ready')
})
```

- `createGroqClient converts seconds to ms` (D5)

```ts
it('createGroqClient converts seconds to ms', async () => {
  const f = vi.spyOn(globalThis, 'fetch').mockResolvedValueOnce(new Response('{"text":"hi","segments":[{"text":"hi","start":1.25,"end":2.5}]}'))
  expect((await createGroqClient('k').transcribe(Buffer.from('x'), 'm.m4a')).segments).toEqual([{ text: 'hi', startMs: 1250, endMs: 2500 }])
  expect(f.mock.calls[0][0]).toBe('https://api.groq.com/openai/v1/audio/transcriptions')
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (module not found)
- [ ] **Step 2:** Implement `transcription.service.ts` to the Behaviour; add ffmpeg to both Dockerfiles and the env lines
- [ ] **Step 3: Run them — PASS**; `npx tsc --noEmit` clean
- [ ] **Step 4: Commit** — `feat(memo): Groq fallback transcription with ffmpeg chunking`

### Task 4: memo create, re-mint and complete
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/services/memos.service.ts` — body schemas, serializers, `createMemo`, `remintUpload`, `completeMemo`, the transcription runner seam
- Test: `server/src/services/__tests__/memos-lifecycle.test.ts` (DB-backed; storage mocked)
- Test: `server/src/services/__tests__/memos-schemas.test.ts` (pure zod)

**Interfaces:**
- Consumes: `presignPut`, `headObject` (Task 2); `transcribeMemo` (Task 3)
- Produces: `createMemoBody` (zod, below); `MemoServiceError` (`Error` with `status: 400 | 404 | 409`); `toVoiceMemo(row, url?)`, `toVoiceMemoSummary(row)` — the §Contract JSON
- Produces: `createMemo(userId, input)` → `{ memo, upload: UploadTicket }`, `UploadTicket` = `{ url, method: 'PUT', headers: { 'Content-Type', 'Content-Length' }, expiresAt }`; `remintUpload(userId, memoId)` → `UploadTicket`; `completeMemo(userId, memoId)` → `VoiceMemo`
- Produces: `setTranscriptionRunner(fn)` → the previous runner; default `void transcribeMemo(id)`, a no-op under `NODE_ENV === 'test'` (D33); `memoKey(userId, memoId)` = `memos/${userId}/${memoId}.m4a` (D25)

**Behaviour:**
- `createMemoBody` (D11, D12, D44)

```ts
const segment = z.object({ text: z.string(), startMs: z.number().int().min(0), endMs: z.number().int().min(0) }).strict()
export const createMemoBody = z.object({
  title: z.string().trim().min(1).max(120),
  durationMs: z.number().int().min(1).max(10_800_000),
  fileSize: z.number().int().min(1).max(104_857_600),
  recordedAt: z.string().datetime({ offset: true }),
  waveformPeaks: z.array(z.number().finite().min(0).max(1)).max(108_001),
  transcript: z.string().max(1_000_000).optional(),
  transcriptSegments: z.array(segment).max(50_000).optional(),
}).strict().superRefine((b, ctx) => {
  if (Math.abs(b.waveformPeaks.length - Math.ceil(b.durationMs / 100)) > 1)
    ctx.addIssue({ code: 'custom', path: ['waveformPeaks'], message: 'waveformPeaks must have one value per 100 ms' })
  b.transcriptSegments?.forEach((s, i) => { if (s.startMs > s.endMs || s.endMs > b.durationMs)
    ctx.addIssue({ code: 'custom', path: ['transcriptSegments', i], message: 'segment out of range' }) })
})
```

- every query is scoped `userId = <caller> AND isActive = true`; anything else is `MemoServiceError(404, 'Memo not found')`, never 403 (D8)
- create: the row id is generated first (`crypto.randomUUID()`), `key = memoKey(userId, id)`, `uploadStatus: 'pending'`; a non-empty `transcript` is stored with `transcriptSource: 'on_device'` and `transcriptSegments`, `transcriptStatus` stays `'none'`; the ticket comes from `presignPut(key, 'audio/mp4', fileSize, 900)` with `expiresAt` = now + 900 s ISO (D9, D13, D25)
- re-mint: `pending` → a fresh ticket for the same key and size; `ready` → `MemoServiceError(409, 'Memo already uploaded')` (D29)
- complete on `pending`: `headObject(key)` null → `409 'Uploaded file not found'`; size ≠ `fileSize` → `409 'Uploaded file size does not match'`; else `uploadStatus: 'ready'` and `transcriptStatus` = `'ready'` when a transcript is stored, else `'pending'` and the runner is called once with the id after the update (D13, D33)
- complete on `ready`: returns the memo unchanged; no HEAD, no runner (D30)
- every response from these three has `url: null, urlExpiresAt: null` (D31); dates ISO strings; JSON keys camelCase

**Tests:** (`headObject`, `presignPut` mocked; runner captured with `setTranscriptionRunner(vi.fn())`)

- `create returns a pending memo and a 15-min PUT ticket; an on-device transcript completes ready` (D9, D13, D25, D31, D10, D33)

```ts
it('create returns a pending memo and a 15-min PUT ticket', async () => {
  const { memo, upload } = await createMemo(userId, body({ fileSize: 5000 }))
  expect(memo).toMatchObject({ uploadStatus: 'pending', transcriptStatus: 'none', url: null, urlExpiresAt: null, mimeType: 'audio/mp4' })
  expect(presignPut).toHaveBeenCalledWith(`memos/${userId}/${memo.id}.m4a`, 'audio/mp4', 5000, 900)
  expect(upload).toMatchObject({ method: 'PUT', headers: { 'Content-Type': 'audio/mp4', 'Content-Length': '5000' } })
  expect(Date.parse(upload.expiresAt) - Date.now()).toBeGreaterThan(890_000)
  const od = await createMemo(userId, body({ fileSize: 5000, transcript: 'hi', transcriptSegments: [{ text: 'hi', startMs: 0, endMs: 500 }] }))
  headObject.mockResolvedValueOnce({ contentLength: 5000 })  // D10, D33: on-device transcript → ready, nothing started
  expect(await completeMemo(userId, od.memo.id)).toMatchObject({ transcriptStatus: 'ready', transcriptSource: 'on_device', transcript: 'hi' })
  expect(runner).not.toHaveBeenCalled()
})
```

- `complete without a transcript starts the fallback once; again is a no-op` (D13, D33, D30, D8)

```ts
it('complete without a transcript starts the fallback once', async () => {
  const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
  headObject.mockResolvedValueOnce({ contentLength: 5000 })
  expect(await completeMemo(userId, memo.id)).toMatchObject({ uploadStatus: 'ready', transcriptStatus: 'pending' })
  expect(runner).toHaveBeenCalledTimes(1); expect(runner).toHaveBeenCalledWith(memo.id)
  expect(await completeMemo(userId, memo.id)).toMatchObject({ uploadStatus: 'ready' }) // D30: again → same, no HEAD, no run
  expect(headObject).toHaveBeenCalledTimes(1); expect(runner).toHaveBeenCalledTimes(1)
  await expect(completeMemo(otherUserId, memo.id)).rejects.toMatchObject({ status: 404, message: 'Memo not found' })
})
```

- `complete refuses a missing or wrong-size object with 409` (D13)

```ts
it('complete refuses a missing or wrong-size object with 409', async () => {
  const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
  headObject.mockResolvedValueOnce(null)
  await expect(completeMemo(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Uploaded file not found' })
  headObject.mockResolvedValueOnce({ contentLength: 4999 })
  await expect(completeMemo(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Uploaded file size does not match' })
})
```

- `re-mint answers a pending memo, 409 when ready, 404 for another user` (D8, D29)

```ts
it('re-mint answers a pending memo, 409 when ready, 404 for another user', async () => {
  const { memo } = await createMemo(userId, body({ fileSize: 5000 }))
  expect((await remintUpload(userId, memo.id)).headers['Content-Length']).toBe('5000')
  await expect(remintUpload(otherUserId, memo.id)).rejects.toMatchObject({ status: 404, message: 'Memo not found' })
  headObject.mockResolvedValueOnce({ contentLength: 5000 }); await completeMemo(userId, memo.id)
  await expect(remintUpload(userId, memo.id)).rejects.toMatchObject({ status: 409, message: 'Memo already uploaded' })
})
```

- In `memos-schemas.test.ts`, `createMemoBody enforces the D44 caps` — `base` = `{ title: 'Memo 1', durationMs: 1000, fileSize: 10, recordedAt: '2026-11-20T10:00:00.000Z', waveformPeaks: Array(10).fill(0.5) }`

```ts
it.each([
  [{ title: '   ' }], [{ title: 'x'.repeat(121) }], [{ fileSize: 104_857_601 }], [{ durationMs: 10_800_001 }],
  [{ durationMs: 0 }], [{ waveformPeaks: Array(13).fill(0.5) }], [{ waveformPeaks: [...Array(9).fill(0.5), 1.5] }],
  [{ transcriptSegments: [{ text: 'a', startMs: 0, endMs: 1001 }] }], [{ transcriptSegments: [{ text: 'a', startMs: 600, endMs: 500 }] }],
  [{ extra: true }], [{ recordedAt: 'yesterday' }],
])('createMemoBody refuses %j', (patch) => {
  expect(createMemoBody.safeParse({ ...base, ...patch }).success).toBe(false)
})

it.each([9, 10, 11])('createMemoBody accepts %i peaks for 1000 ms', (n) => {
  expect(createMemoBody.safeParse({ ...base, waveformPeaks: Array(n).fill(0) }).success).toBe(true)
})

it('createMemoBody trims the title', () => {
  expect(createMemoBody.parse({ ...base, title: '  Memo 7  ' }).title).toBe('Memo 7')
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (module not found)
- [ ] **Step 2:** Implement `memos.service.ts` to the Interfaces and Behaviour
- [ ] **Step 3: Run them — PASS**
- [ ] **Step 4: Commit** — `feat(memo): memo create, re-mint and idempotent complete`

### Task 5: memo list, search, detail, rename, delete, user purge
App: server
Phase: 2
Recipe: /api

**Files:**
- Modify: `server/src/services/memos.service.ts` — add `listMemosQuery`, `renameMemoBody`, `listMemos`, `getMemo`, `renameMemo`, `softDeleteMemo`, `purgeUserMemoObjects`
- Test: `server/src/services/__tests__/memos-read.test.ts`

**Interfaces:**
- Consumes: `presignGet`, `deleteFromR2` (Task 2); `toVoiceMemo`, `toVoiceMemoSummary`, `MemoServiceError` (Task 4)
- Produces: `listMemosQuery` — zod: `q` optional string, `limit` coerced int 1–100 default 50, `offset` coerced int ≥ 0 default 0, `.strict()`
- Produces: `renameMemoBody` — zod `{ title: z.string().trim().min(1).max(120) }.strict()`
- Produces: `listMemos(userId, { q?, limit, offset })` → `{ memos, total }`; `getMemo(userId, memoId)` → `VoiceMemo`; `renameMemo(userId, memoId, title)` → `VoiceMemo`; `softDeleteMemo(userId, memoId)`; `purgeUserMemoObjects(userId)` → objects deleted (number)

**Behaviour:**
- list: active, `uploadStatus: 'ready'`, owned only; ordered `recordedAt desc, id desc`; `total` counts the same filter (D24, D44)
- list SQL selects explicit columns and `left(transcript, 280) AS "transcriptPreview"`, never `transcript`, `transcriptSegments` or `waveformPeaks`; `$queryRaw` with tagged parameters, never string concatenation (D24, D44)
- `q` matches `title ILIKE p OR transcript ILIKE p` with `p = '%' + q.replace(/[\\%_]/g, '\\$&') + '%'` and `ESCAPE '\'`, so `%` and `_` match literally (D17, D44)
- detail: `url = await presignGet(key, 3600)`, `urlExpiresAt` = now + 3600 s ISO (D31)
- rename sets the trimmed title; soft delete sets `isActive: false`, `deletedAt: now`; both 404 like Task 4 (D6, D8)
- purge: every memo of the user, active or not, gets `deleteFromR2(key)`; a failing delete is logged and the rest continue (D35)

**Tests:** (a `seed(userId, patch)` helper creates ready memos; `ids = async (q?: string) => (await listMemos(userId, { q, limit: 50, offset: 0 })).memos.map((m) => m.id)`)

- `list shows only the owner's ready, active memos, newest first, as summaries` (D8, D24, D31)

```ts
it("list shows only the owner's ready, active memos, newest first", async () => {
  const a = await seed(userId, { recordedAt: new Date('2026-11-01') }); const b = await seed(userId, { recordedAt: new Date('2026-11-02') })
  await seed(userId, { uploadStatus: 'pending' }); await seed(userId, { isActive: false }); await seed(otherUserId, {})
  const { memos, total } = await listMemos(userId, { limit: 50, offset: 0 })
  expect(memos.map((m) => m.id)).toEqual([b.id, a.id]); expect(total).toBe(2)
  await prisma.voiceMemo.update({ where: { id: b.id }, data: { transcript: 'x'.repeat(400), waveformPeaks: [0.1] } })
  const [s] = (await listMemos(userId, { limit: 50, offset: 0 })).memos
  expect(s.transcriptPreview).toHaveLength(280)  // D24: no heavy fields
  for (const k of ['transcript', 'transcriptSegments', 'waveformPeaks', 'url', 'urlExpiresAt']) expect(s).not.toHaveProperty(k)
})
```

- `q matches title or transcript, case-insensitively` (D17)

```ts
it('q matches title or transcript, case-insensitively', async () => {
  const t = await seed(userId, { title: 'Sermon Ideas' }); const r = await seed(userId, { transcript: 'about GRACE today' })
  await seed(userId, { title: 'other' })
  expect(await ids('sermon')).toEqual([t.id])
  expect(await ids('grace')).toEqual([r.id])
})
```

- `q treats % and _ literally` (D44)

```ts
it('q treats % and _ literally', async () => {
  const pct = await seed(userId, { title: '100% sure' }); await seed(userId, { title: 'plain' })
  const und = await seed(userId, { title: 'a_b' }); await seed(userId, { title: 'axb' })
  expect(await ids('%')).toEqual([pct.id])
  expect(await ids('_')).toEqual([und.id])
})
```

- `detail carries a 60-min presigned GET` (D31)

```ts
it('detail carries a 60-min presigned GET', async () => {
  const m = await seed(userId, {}); presignGet.mockResolvedValueOnce('https://signed.test/get')
  const memo = await getMemo(userId, m.id)
  expect(presignGet).toHaveBeenCalledWith(m.key, 3600)
  expect(memo.url).toBe('https://signed.test/get')
  await softDeleteMemo(userId, m.id)
  expect((await prisma.voiceMemo.findUnique({ where: { id: m.id } }))!.deletedAt).toBeInstanceOf(Date)
  expect(Date.parse(memo.urlExpiresAt!) - Date.now()).toBeGreaterThan(3_590_000)
  await expect(getMemo(otherUserId, m.id)).rejects.toMatchObject({ status: 404 })
})
```

- `purgeUserMemoObjects deletes every key and survives one failure` (D35)

```ts
it('purgeUserMemoObjects deletes every key and survives one failure', async () => {
  const a = await seed(userId, {}); const b = await seed(userId, { isActive: false })
  deleteFromR2.mockRejectedValueOnce(new Error('r2 down'))
  expect(await purgeUserMemoObjects(userId)).toBe(1)
  expect(deleteFromR2.mock.calls.map((c) => c[0]).sort()).toEqual([a.key, b.key].sort())
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`listMemos` is not exported)
- [ ] **Step 2:** Implement the seven exports to the Behaviour
- [ ] **Step 3: Run them — PASS**
- [ ] **Step 4: Commit** — `feat(memo): memo list, search, detail, rename, delete and user purge`

### Task 6: memo maintenance job
App: server
Phase: 2
Recipe: /api

**Files:**
- Modify: `server/src/services/memos.service.ts` — `expireStalePendingUploads`, `memoIdsDueForTranscriptRetry`, `purgeDeletedMemos`
- Create: `server/src/jobs/memo-maintenance.ts` — `runMemoMaintenance`, `startMemoMaintenanceJob`, `stopMemoMaintenanceJob`
- Modify: `server/src/index.ts:604-620` — start the job beside the cache-eviction job, inside the same `NODE_ENV !== 'test'` guard
- Test: `server/src/services/__tests__/memo-maintenance.test.ts`

**Interfaces:**
- Consumes: `deleteFromR2` (Task 2); `transcribeMemo`, `TRANSCRIPT_MAX_ATTEMPTS` (Task 3)
- Produces: `expireStalePendingUploads(now: Date)` → `Promise<number>`; `memoIdsDueForTranscriptRetry()` → `Promise<string[]>`; `purgeDeletedMemos(now: Date)` → `Promise<number>`
- Produces: `runMemoMaintenance(deps?: { now?, transcribe?, env? })` → `{ expired, retried, purged }` or `{ skippedLockHeld: true }`
- Produces: `MEMO_MAINTENANCE_INTERVAL_MS = 900_000`, `MEMO_MAINTENANCE_LOCK_KEY = 727201002`

**Behaviour:**
- step 1: `pending` rows created > 24 h ago → `deleteFromR2(key)` (failure logged) then the row is deleted (D13, D26)
- step 2: skipped entirely when `GROQ_API_KEY` is empty (D33); else `transcribe(id)` sequentially for active, `uploadStatus: 'ready'`, `transcriptStatus in (pending, failed)`, `transcriptAttempts < 3` (D26)
- step 3: inactive rows with `deletedAt` > 30 days ago → `deleteFromR2(key)` (failure logged), then one `$transaction` deletes their `NoteLink` rows (`refType: 'MEMO'`, `refId: id`) and the row (D6, D36)
- the steps run in order 1 → 2 → 3, each in its own try/catch so one failing step never stops the next (D26)
- a pass takes `pg_try_advisory_lock(727201002)` on a dedicated `pg` connection (`max: 1` pool, `DIRECT_URL || DATABASE_URL`) and unlocks on that connection in `finally`; not obtained → `{ skippedLockHeld: true }`, no step runs (D32)
- the job runs one pass 10 s after start, then every 15 min, `unref()`'d, as `jobs/cache-eviction.ts` (D26)

**Pattern:** `server/src/jobs/cache-eviction.ts:1-66` (job shape) · `server/src/services/analytics.service.ts:58-115` (lock)

**Tests:** (`deleteFromR2` mocked; `now` injected)

- `expires pending uploads older than 24 h with their objects` (D13, D26)

```ts
it('expires pending uploads older than 24 h with their objects', async () => {
  const old = await seed(userId, { uploadStatus: 'pending', createdAt: hoursAgo(25) }); const young = await seed(userId, { uploadStatus: 'pending', createdAt: hoursAgo(23) })
  expect(await expireStalePendingUploads(new Date())).toBe(1)
  expect(deleteFromR2).toHaveBeenCalledWith(old.key)
  expect(await prisma.voiceMemo.findUnique({ where: { id: old.id } })).toBeNull()
  expect(await prisma.voiceMemo.findUnique({ where: { id: young.id } })).not.toBeNull()
})
```

- `purges memos deleted over 30 days ago with their note links` (D6, D36)

```ts
it('purges memos deleted over 30 days ago with their note links', async () => {
  const gone = await seed(userId, { isActive: false, deletedAt: daysAgo(31) }); const kept = await seed(userId, { isActive: false, deletedAt: daysAgo(29) })
  const note = await prisma.studyNote.create({ data: { userId, type: 'JOURNAL', content: 'n', links: { create: [{ refType: 'MEMO', refId: gone.id }] } } })
  expect(await purgeDeletedMemos(new Date())).toBe(1)
  expect(await prisma.voiceMemo.findUnique({ where: { id: gone.id } })).toBeNull()
  expect(await prisma.noteLink.count({ where: { noteId: note.id } })).toBe(0)
  expect(await prisma.voiceMemo.findUnique({ where: { id: kept.id } })).not.toBeNull()
  expect(deleteFromR2).toHaveBeenCalledWith(gone.key)
})
```

- `retries only eligible transcripts, and nothing without a key` (D26, D33)

```ts
it('retries only eligible transcripts, and nothing without a key', async () => {
  const due = await seed(userId, { transcriptStatus: 'failed', transcriptAttempts: 2 })
  await seed(userId, { transcriptStatus: 'failed', transcriptAttempts: 3 }); await seed(userId, { transcriptStatus: 'ready' })
  await seed(userId, { transcriptStatus: 'pending', uploadStatus: 'pending' })
  const transcribe = vi.fn(async () => 'ready')
  await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: '' } })
  expect(transcribe).not.toHaveBeenCalled()
  await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: 'k' } })
  expect(transcribe.mock.calls.map((c) => c[0])).toContain(due.id)
  expect(transcribe.mock.calls.map((c) => c[0])).toHaveLength(1)
})
```

- `a failing step does not stop the next` (D26)

```ts
it('a failing step does not stop the next', async () => {
  const gone = await seed(userId, { isActive: false, deletedAt: daysAgo(31) })
  const transcribe = vi.fn(async () => { throw new Error('boom') })
  await seed(userId, { transcriptStatus: 'pending' })
  const out = await runMemoMaintenance({ transcribe, env: { ...process.env, GROQ_API_KEY: 'k' } })
  expect(out).toMatchObject({ purged: 1 })
  expect(await prisma.voiceMemo.findUnique({ where: { id: gone.id } })).toBeNull()
})
```

- `a pass is skipped while another holds the lock` (D32)

```ts
it('a pass is skipped while another holds the lock', async () => {
  const holder = new pg.Client({ connectionString: process.env.DIRECT_URL || process.env.DATABASE_URL }); await holder.connect()
  await holder.query('SELECT pg_advisory_lock($1)', [727201002])
  try { expect(await runMemoMaintenance({ transcribe: vi.fn() })).toEqual({ skippedLockHeld: true }) }
  finally { await holder.query('SELECT pg_advisory_unlock($1)', [727201002]); await holder.end() }
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (module not found)
- [ ] **Step 2:** Implement the three service functions, the job module and the `index.ts` start to the Behaviour
- [ ] **Step 3: Run them — PASS**
- [ ] **Step 4: Commit** — `feat(memo): memo maintenance job (expire, retry, purge)`

### Task 7: `MEMO` note link type
App: server
Phase: 2
Recipe: /api · tiny

**Files:**
- Modify: `server/src/services/notes.service.ts:46-52` — `MEMO: 'MEMO'` in `LINK_TYPES`; `:196-200` — add `memoLinkRefusal` beside `removedLinkRefusal`; call it in `createNote` (`:208`) and `addNoteLink` (`:557`)
- Test: `server/src/services/__tests__/notes-memo-link.test.ts` (DB-backed)

**Interfaces:**
- Produces: `memoLinkRefusal(links?, ownerUserId: string | null)` → the `removedLinkRefusal` refusal shape, or null

**Behaviour:**
- no `MEMO` link in `links` → null without a query (D18)
- each `MEMO` link must name a memo with `isActive: true` and `userId === ownerUserId`; a member-owned note (`ownerUserId` null) is always refused (D18)
- refusal copy exactly: `Memo link must reference one of your memos` (D18)
- `createNote` passes `data.userId ?? null`; `addNoteLink` reads the note's `userId` first (D18)

**Tests:**

- `LINK_TYPES gains MEMO` (SC6)

```ts
it('LINK_TYPES gains MEMO', () => { expect(LINK_TYPES.MEMO).toBe('MEMO') })
```

- `a note may link its owner's active memo` (D18)

```ts
it("a note may link its owner's active memo", async () => {
  const r = await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: memo.id }] })
  expect(r.success).toBe(true)
})
```

- `foreign, inactive or member-owned memo links are refused` (D18)

```ts
const refusal = { success: false, code: 'VALIDATION', error: 'Memo link must reference one of your memos' }
it('foreign, inactive or member-owned memo links are refused', async () => {
  expect(await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: otherUsersMemo.id }] })).toEqual(refusal)
  expect(await createNote({ userId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: inactiveMemo.id }] })).toEqual(refusal)
  expect(await createNote({ memberId, type: 'JOURNAL', content: 'c', links: [{ refType: 'MEMO', refId: memo.id }] })).toEqual(refusal)
  const note = await createNote({ userId: otherUserId, type: 'JOURNAL', content: 'c' })
  expect(await addNoteLink(note.data!.id, { refType: 'MEMO', refId: memo.id })).toEqual(refusal)
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`LINK_TYPES.MEMO` undefined)
- [ ] **Step 2:** Implement to the Behaviour
- [ ] **Step 3: Run them plus `src/routes/__tests__/notes-removed-link-types.request.test.ts` — PASS**
- [ ] **Step 4: Commit** — `feat(memo): MEMO note link type with ownership check`

### Task 8: `/api/memos` routes, user hard-delete purge, contract freeze
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/routes/memos.ts` — seven thin handlers
- Modify: `server/src/index.ts` — `import memosRoutes from './routes/memos.js'` and `app.use('/api/memos', memosRoutes)` beside `app.use('/api/users', usersRoutes)` (`:336`)
- Modify: `server/src/routes/users.ts:729-744` — `await purgeUserMemoObjects(req.params.id)` before `prisma.user.delete` (D35)
- Test: `server/test/memos.request.test.ts` — one block per §Contract row, real auth via `createUserWithApiKey`, storage mocked
- Modify: `docs/features/memo/MANIFEST.md` — `contract: frozen <date>` via `advance.mjs` (last step)

**Interfaces:**
- Consumes: every `memos.service.ts` export from Tasks 4–5; `requireAuth` (`middleware/auth.ts:21-52`)
- Produces: the frozen contract, verbatim from SPEC §Contract:

```
| `POST /api/memos` | requireAuth | { title, durationMs, fileSize, recordedAt (ISO), waveformPeaks: number[], transcript?, transcriptSegments?: [{text,startMs,endMs}] } | 201 { memo: VoiceMemo, upload: { url, method: "PUT", headers: { "Content-Type": "audio/mp4", "Content-Length": "<fileSize>" }, expiresAt } } | 400 validation (D44 caps, title, limits D12, peaks length ≠ ceil(durationMs/100)±1) · 401 |
| `PATCH /api/memos/:id/complete` | requireAuth | {} | 200 { memo } with uploadStatus: ready; transcriptStatus: ready if a transcript arrived on POST, else pending and Groq started (D33). On a memo already ready: 200 { memo } unchanged, no HEAD, no Groq (D30) | 404 not owner/absent/swept · 409 object missing or size ≠ fileSize · 401 |
| `POST /api/memos/:id/upload` | requireAuth | {} | 200 { upload } — same shape as POST /api/memos's, a fresh 15-min URL (D29) | 404 not owner/absent/swept · 409 already ready · 401 |
| `GET /api/memos?q=&limit=&offset=` | requireAuth | limit 1–100 (default 50), offset ≥ 0, q optional | 200 { memos: VoiceMemoSummary[], total }, recordedAt desc, active + uploadStatus: ready only | 400 bad paging · 401 |
| `GET /api/memos/:id` | requireAuth | — | 200 { memo: VoiceMemo } with url = presigned GET (60 min) and urlExpiresAt (D31) | 404 · 401 |
| `PATCH /api/memos/:id` | requireAuth | { title } (only field; unknown keys → 400, never silently stripped) | 200 { memo } | 400 · 404 · 401 |
| `DELETE /api/memos/:id` | requireAuth | — | 204 | 404 · 401 |

VoiceMemo = { id, title, url|null, urlExpiresAt|null, mimeType, fileSize|null, durationMs|null, waveformPeaks: number[]|null,
  transcript|null, transcriptSegments|null, transcriptStatus: "none"|"pending"|"ready"|"failed",
  transcriptSource: "on_device"|"server"|null, uploadStatus: "pending"|"ready", recordedAt, createdAt, updatedAt }
VoiceMemoSummary = VoiceMemo minus url, urlExpiresAt, transcript, transcriptSegments, waveformPeaks; plus transcriptPreview: string|null
JSON keys camelCase.
```

**Behaviour:**
- every route uses `requireAuth`; members get 401 (D19)
- POST parses `createMemoBody`, `PATCH /:id` parses `renameMemoBody`, `complete` and `upload` parse `z.object({}).strict()`, `GET /` parses `listMemosQuery` from `req.query`; a zod failure → `400 { success: false, error: 'Invalid request', details: <zod issues> }`, never a strip (D44, §Contract)
- `MemoServiceError` → its status with `{ success: false, error: message }`; anything else → 500 `{ success: false, error: 'Failed to process memo request' }`
- success bodies are exactly §Contract's: `201 { memo, upload }`, `200 { memo }`, `200 { upload }`, `200 { memos, total }`, `204` empty
- `/:id` route order: `PATCH /:id/complete` and `POST /:id/upload` are registered before `PATCH /:id`
- user hard-delete awaits `purgeUserMemoObjects` (which never throws) before deleting the row (D35)

**Tests:** (`server/test/memos.request.test.ts`; `presignPut`, `presignGet`, `headObject`, `deleteFromR2` mocked as `test/media-upload-taken-at.test.ts:5`; `as = (req, t = token) => req.set('Authorization', bearer(t))`, `post = (b) => as(request(app).post('/api/memos')).send(b)`, `api = request(app)`)

- `POST /api/memos creates and returns an upload ticket` (SC2)

```ts
it('POST /api/memos creates and returns an upload ticket', async () => {
  const res = await post(body)
  expect(res.status).toBe(201)
  expect(res.body.memo).toMatchObject({ title: 'Memo 1', uploadStatus: 'pending', url: null, urlExpiresAt: null })
  expect(res.body.upload).toMatchObject({ method: 'PUT', headers: { 'Content-Type': 'audio/mp4', 'Content-Length': String(body.fileSize) } })
})
```

- `POST /api/memos refuses an unknown key and bad peaks with 400, and no auth with 401` (D44, D19)

```ts
it('POST /api/memos refuses an unknown key and bad peaks with 400', async () => {
  expect((await post({ ...body, color: 'red' })).status).toBe(400)
  expect((await post({ ...body, waveformPeaks: [0.1] })).status).toBe(400)
  expect((await post({ ...body, fileSize: 104_857_601 })).status).toBe(400)
  expect((await request(app).post('/api/memos').send(body)).status).toBe(401)
})
```

- `complete, re-mint and complete-again follow D13, D29, D30` (SC3, SC7)

```ts
it('complete, re-mint and complete-again follow D13, D29, D30', async () => {
  const { body: created } = await post(body); const id = created.memo.id
  expect((await as(api.post(`/api/memos/${id}/upload`)).send({})).status).toBe(200)
  headObject.mockResolvedValueOnce(null)
  expect((await as(api.patch(`/api/memos/${id}/complete`)).send({})).status).toBe(409)
  headObject.mockResolvedValueOnce({ contentLength: body.fileSize })
  const done = await as(api.patch(`/api/memos/${id}/complete`)).send({})
  expect(done.status).toBe(200); expect(done.body.memo).toMatchObject({ uploadStatus: 'ready', transcriptStatus: 'pending' })
  const again = await as(api.patch(`/api/memos/${id}/complete`)).send({})
  expect(again.status).toBe(200); expect(again.body.memo).toEqual(done.body.memo)
  expect((await as(api.post(`/api/memos/${id}/upload`)).send({})).status).toBe(409)
  expect((await as(api.patch(`/api/memos/${id}/complete`)).send({ x: 1 })).status).toBe(400)
})
```

- `list, detail, rename and delete answer per §Contract; another user gets 404` (SC4, SC5, D8)

```ts
it('list, detail, rename and delete answer per §Contract; another user gets 404', async () => {
  const id = await createReadyMemo(token)
  const list = await as(api.get('/api/memos?q=memo&limit=10'))
  expect(list.status).toBe(200); expect(list.body.total).toBe(1); expect(list.body.memos[0]).toHaveProperty('transcriptPreview')
  expect((await as(api.get('/api/memos?limit=0'))).status).toBe(400)
  presignGet.mockResolvedValueOnce('https://signed.test/get')
  const detail = await as(api.get(`/api/memos/${id}`))
  expect(detail.body.memo.url).toBe('https://signed.test/get'); expect(detail.body.memo.urlExpiresAt).toEqual(expect.any(String))
  expect((await as(api.get(`/api/memos/${id}`), otherToken)).status).toBe(404)
  expect((await as(api.patch(`/api/memos/${id}`)).send({ title: 'x', transcript: 'y' })).status).toBe(400)
  const renamed = await as(api.patch(`/api/memos/${id}`)).send({ title: ' Renamed ' })
  expect(renamed.body.memo.title).toBe('Renamed')
  expect((await as(api.delete(`/api/memos/${id}`))).status).toBe(204)
  expect((await as(api.get('/api/memos'))).body.total).toBe(0)
})
```

- `user hard-delete purges memo objects first` (D35)

```ts
it('user hard-delete purges memo objects first', async () => {
  const doomed = await createUserWithApiKey({ email: `doomed-${stamp}@t.test`, name: 'Doomed' })
  const id = await createReadyMemo(doomed.token)
  const key = (await prisma.voiceMemo.findUnique({ where: { id } }))!.key
  expect((await as(api.delete(`/api/users/${doomed.userId}`), adminToken)).status).toBe(200)
  expect(deleteFromR2).toHaveBeenCalledWith(key)
  expect(await prisma.voiceMemo.count({ where: { id } })).toBe(0)
})
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (404 on `/api/memos`)
- [ ] **Step 2:** Implement `routes/memos.ts`, mount it, add the purge call to `users.ts`; `docker restart makeready-server`
- [ ] **Step 3: Run them plus every memo service test — PASS**; `npx tsc --noEmit` clean
- [ ] **Step 4: Commit** — `feat(memo): /api/memos routes and user-delete audio purge`
- [ ] **Step 5: Record the freeze** — `node "$BUILDER_DIR"/scripts/advance.mjs docs/features/memo --set "contract=frozen <YYYY-MM-DD>" --commit "chore(memo): contract frozen"` (the phase close that verifies this task is the freeze; no consumer task starts before it)

### Task 9: memo models and Info.plist strings
App: iphone
Phase: 3
Recipe: /ios-error-surface · tiny

**Files:**
- Create: `iphone/MakeReady/State/Models/MemoModels.swift` — wire types and engine value types
- Modify: `iphone/MakeReady/Info.plist:104-119` — the D27 strings; `UIBackgroundModes` unchanged
- Modify: `iphone/MakeReady/Utilities/Log.swift:28-45` — `static let memo = Logger(subsystem: subsystem, category: "memo")` (F25)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs for the new app file and test file; then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoModelsTests.swift`

**Interfaces:**
- Consumes: the frozen §Contract shapes (Task 8)
- Produces: `VoiceMemo`, `VoiceMemoSummary` (Codable, Identifiable, Equatable; every §Contract field; dates `Date`; `waveformPeaks: [Double]?`), `VoiceMemoSummary.init(_ memo: VoiceMemo)` (preview = first 280 chars of `transcript`), `TranscriptSegment { text; startMs: Int; endMs: Int }`
- Produces: `MemoTranscriptStatus` (`none, pending, ready, failed, unknown`), `MemoUploadStatus` (`pending, ready, unknown`) — String raw values, any other string → `.unknown`
- Produces: `MemoUploadTicket { url; method; headers: [String: String]; expiresAt: Date }`, `MemoCreateResponse { memo; upload }`, `MemoResponse { memo }`, `MemoUploadResponse { upload }`, `MemoListResponse { memos; total }`
- Produces: `Transcript { text; segments }`; `RecordingResult { fileURL: URL; title; durationMs: Int; waveformPeaks: [Double]; recordedAt: Date; transcript: Transcript? }` (Codable, Equatable); `RecorderState` (`idle, recording, paused, finishing`); `MemoEngineError` (`micPermissionDenied, speechUnavailable, durationLimitReached, writeFailed`, D21)

**Behaviour:**
- dates decode through `JSONDecoder.apiDecoder`, including fractional seconds (`.123Z`) (§Testing)
- an unknown status string decodes, never throws — the iPhone is a released artifact (D32: the wire enum may only widen deliberately)
- Info.plist copy exactly (D27): `NSMicrophoneUsageDescription` = `MakeReady uses the microphone to record videos and voice memos.`; `NSSpeechRecognitionUsageDescription` = `MakeReady turns your voice memos into text on your iPhone.`; no `audio` in `UIBackgroundModes`

**Tests:**

- `testVoiceMemoDecodesTheDetailPayloadWithFractionalDates` (§Contract)

```swift
func testVoiceMemoDecodesTheDetailPayloadWithFractionalDates() throws {
    let json = #"{"id":"m1","title":"Memo 1","url":"https://s.test/g","urlExpiresAt":"2026-11-20T11:30:00.123Z","mimeType":"audio/mp4","fileSize":5000,"durationMs":1000,"waveformPeaks":[0.1,0.5],"transcript":"hi","transcriptSegments":[{"text":"hi","startMs":0,"endMs":500}],"transcriptStatus":"ready","transcriptSource":"on_device","uploadStatus":"ready","recordedAt":"2026-11-20T10:30:00.123Z","createdAt":"2026-11-20T10:30:01.000Z","updatedAt":"2026-11-20T10:30:02.456Z"}"#
    let memo = try JSONDecoder.apiDecoder.decode(VoiceMemo.self, from: Data(json.utf8))
    XCTAssertEqual(memo.transcriptSegments, [TranscriptSegment(text: "hi", startMs: 0, endMs: 500)])
    XCTAssertEqual(memo.transcriptStatus, .ready)
    XCTAssertEqual(memo.recordedAt.timeIntervalSince1970, 1_763_634_600.123, accuracy: 0.001)
}
```

- `testSummaryDecodesNullsAndUnknownStatus` (D32 released-artifact rule)

```swift
func testSummaryDecodesNullsAndUnknownStatus() throws {
    let json = #"{"id":"m2","title":"Memo 2","mimeType":"audio/mp4","fileSize":null,"durationMs":null,"transcriptPreview":null,"transcriptStatus":"processing","transcriptSource":null,"uploadStatus":"ready","recordedAt":"2026-11-20T10:30:00.000Z","createdAt":"2026-11-20T10:30:00.000Z","updatedAt":"2026-11-20T10:30:00.000Z"}"#
    let s = try JSONDecoder.apiDecoder.decode(VoiceMemoSummary.self, from: Data(json.utf8))
    XCTAssertEqual(s.transcriptStatus, .unknown)
    XCTAssertNil(s.transcriptPreview)
}
```

- `testInfoPlistCarriesTheD27StringsAndNoAudioMode` (D27)

```swift
func testInfoPlistCarriesTheD27StringsAndNoAudioMode() {
    let info = Bundle.main.infoDictionary!
    XCTAssertEqual(info["NSMicrophoneUsageDescription"] as? String, "MakeReady uses the microphone to record videos and voice memos.")
    XCTAssertEqual(info["NSSpeechRecognitionUsageDescription"] as? String, "MakeReady turns your voice memos into text on your iPhone.")
    XCTAssertFalse((info["UIBackgroundModes"] as? [String] ?? []).contains("audio"))
}
```

> ⚠ build-time risk (F23): new Swift files need explicit `pbxproj` refs, and MakeReadyCapture breaks until `ruby iphone/scripts/capture-targets.rb` re-syncs. Add refs for every new file, then run the script.

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`VoiceMemo` not in scope)
- [ ] **Step 2:** Write `MemoModels.swift`, the plist strings and `Log.memo`; add refs; `ruby iphone/scripts/capture-targets.rb`
- [ ] **Step 3: Run them — PASS**; `swiftlint` from `iphone/` adds no finding
- [ ] **Step 4: Commit** — `feat(memo): memo models and D27 permission strings`

### Task 10: `AppState` memo stores and `MemoActions`
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/State/AppState.swift` — `voiceMemos` and `voiceMemoDetails` stores beside `memberDetails` (`:136-138`); load/persist; `clearInMemory` (`:923`)
- Modify: `iphone/MakeReady/State/Persistence/PersistedState.swift` — a `voiceMemos: [VoiceMemoSummary]` snapshot field, `decodeIfPresent … ?? []`, no `schemaVersion` bump
- Create: `iphone/MakeReady/State/Actions/MemoActions.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` + `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoActionsTests.swift`

**Interfaces:**
- Consumes: Task 9's models; `APIClientProtocol` and `StubAPIClient` (`MakeReadyCaptureTests/StubAPIClient.swift`)
- Produces: `AppState.voiceMemos: EntityStore<VoiceMemoSummary>`, `AppState.voiceMemoDetails: EntityStore<VoiceMemo>`, `AppState.voiceMemosNewestFirst: [VoiceMemoSummary]` (by `recordedAt` desc, then `id` desc)
- Produces: `MemoActions(api: = APIClient.shared, state: = .shared)` — `loadMemos(q:) async throws -> [VoiceMemoSummary]`, `loadMemo(id:) async throws -> VoiceMemo`, `rename(id:title:) async throws`, `softDelete(id:) async throws`, `memoCompleted(_:)`
- Produces: `MemoActions.nextDefaultTitle(existingTitles: [String]) -> String` (static, pure)

**Behaviour:**
- `loadMemos(q: nil)` → `GET /api/memos?limit=100&offset=0` replaces `voiceMemos`; with `q` it returns results and leaves the store alone (D39)
- `loadMemo` → `GET /api/memos/<id>`, upserts `voiceMemoDetails` and its summary into `voiceMemos` (D39)
- `rename` → `PATCH /api/memos/<id>` body `["title": title]`; the returned memo updates both stores in the same call (D39)
- `softDelete` → `DELETE /api/memos/<id>` through `requestWithStatus` (a 204 has no body, F25); removes the id from both stores (D39)
- `memoCompleted` upserts the memo into `voiceMemoDetails` and `VoiceMemoSummary(memo)` into `voiceMemos` (D39)
- `voiceMemos` persists via `PersistedState` (newest 200); `voiceMemoDetails` never; both cleared in `clearInMemory` (D39)
- errors are thrown to the caller and logged with `Log.memo` — console-only in this spec (D21, `/ios-error-surface`)
- `nextDefaultTitle` returns `Memo n`, n = 1 + the largest integer captured by `^Memo (\d+)$` among the titles, 1 when none (D11, D43)

**Pattern:**
- `iphone/MakeReady/State/Actions/EnrollmentDraftActions.swift:12-60` — Actions struct, DELETE via `requestWithStatus`
- `iphone/MakeReadyCaptureTests/ActionStubTests.swift:14-50` — private `AppState` + stub

**Tests:** (`state = AppState()` after `StatePersistence.shared.clear()`; `api = StubAPIClient()`)

- `testLoadMemosReplacesTheStore` (D39)

```swift
func testLoadMemosReplacesTheStore() async throws {
    state.voiceMemos.upsert(summary(id: "stale"))
    api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[\#(summaryJSON("m1"))],"total":1}"#)
    _ = try await MemoActions(api: api, state: state).loadMemos(q: nil)
    XCTAssertEqual(state.voiceMemos.all.map(\.id), ["m1"])
}
```

- `testRenameUpdatesBothStores` (D39)

```swift
func testRenameUpdatesBothStores() async throws {
    state.voiceMemos.upsert(summary(id: "m1", title: "Old")); state.voiceMemoDetails.upsert(memo(id: "m1", title: "Old"))
    api.stub("PATCH", "/api/memos/m1", json: #"{"memo":\#(memoJSON("m1", title: "New"))}"#)
    try await MemoActions(api: api, state: state).rename(id: "m1", title: "New")
    XCTAssertEqual(state.voiceMemos["m1"]?.title, "New"); XCTAssertEqual(state.voiceMemoDetails["m1"]?.title, "New")
}
```

- `testSoftDeleteRemovesFromBothStores` (D39, F25)

```swift
func testSoftDeleteRemovesFromBothStores() async throws {
    state.voiceMemos.upsert(summary(id: "m1")); state.voiceMemoDetails.upsert(memo(id: "m1"))
    api.stub("DELETE", "/api/memos/m1", json: "")
    try await MemoActions(api: api, state: state).softDelete(id: "m1")
    XCTAssertNil(state.voiceMemos["m1"]); XCTAssertNil(state.voiceMemoDetails["m1"])
    XCTAssertTrue(api.statusEndpoints.contains("/api/memos/m1"))
}
```

- `testMemoCompletedUpsertsDetailAndSummary` (D39)

```swift
func testMemoCompletedUpsertsDetailAndSummary() throws {
    MemoActions(api: api, state: state).memoCompleted(memo(id: "m9", transcript: "hello"))
    XCTAssertEqual(state.voiceMemoDetails["m9"]?.transcript, "hello")
    XCTAssertEqual(state.voiceMemos["m9"]?.transcriptPreview, "hello")
    MemoActions(api: api, state: state).memoCompleted(memo(id: "m8", transcript: String(repeating: "a", count: 400)))
    XCTAssertEqual(state.voiceMemos["m8"]?.transcriptPreview?.count, 280)
}
```

- `testVoiceMemosPersistButDetailsDoNot` (D39)

```swift
func testVoiceMemosPersistButDetailsDoNot() throws {
    state.voiceMemos.upsert(summary(id: "m1")); state.voiceMemoDetails.upsert(memo(id: "m1"))
    state.persistImmediately()
    let reloaded = AppState()
    XCTAssertNotNil(reloaded.voiceMemos["m1"]); XCTAssertNil(reloaded.voiceMemoDetails["m1"])
}
```

- `testNextDefaultTitle` (D11, D43)

```swift
func testNextDefaultTitle() {
    XCTAssertEqual(MemoActions.nextDefaultTitle(existingTitles: []), "Memo 1")
    XCTAssertEqual(MemoActions.nextDefaultTitle(existingTitles: ["Memo 2", "Memo 10", "Memo 3b", "Sermon"]), "Memo 11")
}
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`voiceMemos` not a member of `AppState`)
- [ ] **Step 2:** Add the stores, persistence field and `MemoActions` to the Behaviour, pbxproj refs, `capture-targets.rb`
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): AppState memo stores and MemoActions`

### Task 11: `MemoTranscriber`
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Audio/MemoTranscriber.swift` — new `Services/Audio` group in pbxproj
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoTranscriberTests.swift`

**Interfaces:**
- Consumes: `Transcript`, `TranscriptSegment` (Task 9)
- Produces: protocol `MemoTranscribing: AnyObject` — `startLive(stream: AsyncStream<AnalyzerInput>) async -> Bool` (false = unavailable), `analyzerFormat: AVAudioFormat?` (nil until started), `finish() async -> Transcript?`, `transcribeFile(_:) async -> Transcript?`
- Produces: `MemoTranscriber: MemoTranscribing` with `init(locale: Locale = .current, availability: MemoSpeechAvailability = .system)`
- Produces: `MemoSpeechAvailability` — struct of one closure `isAvailable: (Locale) async -> Bool`; `.system` checks `SpeechTranscriber.supportedLocales` and installs/reserves assets via `AssetInventory`, `.unavailable` always false (tests)

**Behaviour:**
- unavailable (locale unsupported, assets not installable, analyzer throws) → `startLive` false, `finish`/`transcribeFile` nil, never a throw; logged `Log.memo` (D5, D21)
- live: `SpeechTranscriber(locale:transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])`; `analyzerFormat` = `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])` (D10, D14)
- `finish()` finalizes through end of input; `text` = result texts joined by one space; one segment per result from its `audioTimeRange` in rounded ms; empty → nil (D1) — proven on device only (F1)
- `transcribeFile` runs the same pipeline over an `AVAudioFile` (D16 salvage)
- assets reserved at start are released in `finish` / at the end of `transcribeFile` (§iphone)

**Tests:**

- `testUnavailableStartsNothingAndReturnsNil` (D5, D21)

```swift
func testUnavailableStartsNothingAndReturnsNil() async throws {
    let t = MemoTranscriber(availability: .unavailable)
    let (stream, _) = AsyncStream<AnalyzerInput>.makeStream()
    let started = await t.startLive(stream: stream)
    XCTAssertFalse(started)
    XCTAssertNil(t.analyzerFormat)
    let finished = await t.finish()
    XCTAssertNil(finished)
}
```

- `testTranscribeFileReturnsNilWhenAssetsUnavailable` (§Testing)

```swift
func testTranscribeFileReturnsNilWhenAssetsUnavailable() async throws {
    let url = try MemoAudioFixtures.sineCAF(seconds: 1)
    let result = await MemoTranscriber(availability: .unavailable).transcribeFile(url)
    XCTAssertNil(result)
}
```

`MemoAudioFixtures` is a test-target helper (create `iphone/MakeReadyCaptureTests/MemoAudioFixtures.swift` here): `sineCAF(seconds:sampleRate:)` writes a mono float32 440 Hz sine to a temp `.caf` and returns its URL; `sineBuffers(seconds:sampleRate:frames:)` returns `[AVAudioPCMBuffer]`. Later tasks reuse it.

> ⚠ build-time risk (F1): on-device live transcription, latency and asset download are unproven until the screens spec's device walk (D4). Do not try to prove them here; the simulator tests cover only the unavailable path and the mapping.

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`MemoTranscriber` not in scope)
- [ ] **Step 2:** Implement to the Behaviour, pbxproj refs, `capture-targets.rb`
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): on-device MemoTranscriber`

### Task 12: `MemoRecorderEngine` capture core
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Audio/AudioInputSource.swift` — the protocol and `LiveAudioInput`
- Create: `iphone/MakeReady/Services/Audio/MemoRecorderEngine.swift` — capture, `.caf` writer, peaks, samples, limit, stop/export
- Create: `iphone/MakeReady/Services/Audio/MemoAudioExporter.swift` — `.caf` → `.m4a`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoRecorderEngineTests.swift`, `iphone/MakeReadyCaptureTests/BufferFeedInput.swift` (test input)

**Interfaces:**
- Consumes: `MemoTranscribing` + `analyzerFormat` (Task 11); Task 9's value types; `MemoAudioFixtures` (Task 11)
- Produces: protocol `AudioInputSource: AnyObject` — `format: AVAudioFormat`, `start(_ onBuffer: @escaping (AVAudioPCMBuffer) -> Void) throws`, `stop()`; `LiveAudioInput` taps `AVAudioEngine.inputNode` bus 0, 4096 frames
- Produces: `@MainActor @Observable final class MemoRecorderEngine` — `init(input:transcriber:directory:maxDuration: TimeInterval = 10_800, now: () -> Date = Date.init)`; read-only `state`, `samples: [Float]`, `elapsed`, `lastError: MemoEngineError?`, `cafURL: URL?`; `prepare(title:) async throws`, `start() async throws`, `pause()`, `resume() throws`, `stop() async throws -> RecordingResult`; `onAutoStop: ((RecordingResult) -> Void)?`
- Produces: `MemoAudioExporter.exportM4A(from:to:) async throws` (D38)

**Behaviour:**
- each buffer is converted (an `AVAudioConverter` per input format, so a route change reuses the path, analysis F8) to mono float32 44.1 kHz, then fans out to the writer, the peaks, and — when the transcriber started — a conversion to `analyzerFormat` yielded into its stream (D14)
- writer: `AVAudioFile(forWriting: <directory>/<uuid>.caf, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000], commonFormat: .pcmFormatFloat32, interleaved: false)` (D14, D38)
- peaks: max |sample| per 4 410 written frames, clamped 0–1, the partial last bucket counted, so `count == ceil(frames / 4410)`; `samples`: a 200-value ring, one max-abs per 2 205 frames (~20 Hz) (D15, D42)
- `durationMs` = written frames ÷ 44 100 × 1000, rounded; paused buffers are dropped, never written or counted (D42)
- states: `start` → `.recording`, `pause` → `.paused`, `resume` → `.recording`, `stop` → `.finishing` → `.idle`; a denied mic (`LiveAudioInput` only) throws `.micPermissionDenied` from `prepare`; a writer error sets `.writeFailed` and stops input (D21)
- at `maxDuration × 44 100` written frames the engine stops itself, sets `.durationLimitReached` and hands the intact result to `onAutoStop` (D12)
- `stop` closes the `.caf`, exports it to `<same uuid>.m4a` (`AVAssetExportSession`, `AVAssetExportPresetPassthrough`, `.m4a`), deletes the `.caf`, awaits `transcriber?.finish()`, and returns the `RecordingResult` with `recordedAt` = `now()` at start (D14, D38)
- no `asyncAfter`, `print` or `NSLog` (F25)

> ⚠ build-time risk (F4): the headless verify simulator may have no audio input. Every test drives the engine through `BufferFeedInput` (a test-target `AudioInputSource` that, on `start`, synchronously hands it the buffers from `MemoAudioFixtures.sineBuffers`, and exposes `feed(_:)` for more); no test touches `LiveAudioInput` or the mic.

**Tests:**

- `testFixtureInputWritesAMonoAACm4aOfTheRightLength` (§Testing, D14, D15, D38, D42)

```swift
func testFixtureInputWritesAMonoAACm4aOfTheRightLength() async throws {
    let engine = makeEngine(seconds: 2.0)
    try await engine.prepare(title: "Memo 1"); try await engine.start()
    let r = try await engine.stop()
    XCTAssertEqual(r.fileURL.pathExtension, "m4a")
    XCTAssertEqual(r.waveformPeaks.count, Int(ceil(Double(r.durationMs) / 100)))
    let file = try AVAudioFile(forReading: r.fileURL)
    XCTAssertEqual(file.fileFormat.channelCount, 1)
    XCTAssertEqual(file.fileFormat.streamDescription.pointee.mFormatID, kAudioFormatMPEG4AAC)
    XCTAssertEqual(r.durationMs, 2000, accuracy: 25)
    XCTAssertFalse(FileManager.default.fileExists(atPath: r.fileURL.deletingPathExtension().appendingPathExtension("caf").path))
}
```

- `testPauseExcludesPausedAudioAndKeepsOneFile` (§Testing, D42)

```swift
func testPauseExcludesPausedAudioAndKeepsOneFile() async throws {
    let (engine, input) = makeEngineWithInput(seconds: 1.0)
    try await engine.prepare(title: "Memo 1"); try await engine.start()
    engine.pause(); input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.0))
    try engine.resume(); input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.0))
    let r = try await engine.stop()
    XCTAssertEqual(r.durationMs, 2000, accuracy: 25)
    XCTAssertEqual(r.waveformPeaks.count, 20, accuracy: 1)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".m4a") }.count, 1)
}
```

- `testDurationLimitStopsWithTheMemoIntact` (D12)

```swift
func testDurationLimitStopsWithTheMemoIntact() async throws {
    let (engine, input) = makeEngineWithInput(seconds: 0, maxDuration: 1.0)
    let delivered = expectation(description: "auto stop"); var result: RecordingResult?
    engine.onAutoStop = { result = $0; delivered.fulfill() }
    try await engine.prepare(title: "Memo 1"); try await engine.start()
    input.feed(MemoAudioFixtures.sineBuffers(seconds: 1.5))
    await fulfillment(of: [delivered], timeout: 5)
    XCTAssertEqual(engine.lastError, .durationLimitReached)
    XCTAssertEqual(result?.durationMs ?? 0, 1000, accuracy: 100)
}
```

- `testLiveTranscriptRidesOnTheResult`

```swift
func testLiveTranscriptRidesOnTheResult() async throws {
    let stub = StubTranscriber(result: Transcript(text: "hello", segments: []))
    let engine = makeEngine(seconds: 1.0, transcriber: stub)
    try await engine.prepare(title: "Memo 1"); try await engine.start()
    let r = try await engine.stop()
    XCTAssertEqual(r.transcript?.text, "hello")
    XCTAssertGreaterThan(stub.receivedFrames, 0)
}
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`MemoRecorderEngine` not in scope)
- [ ] **Step 2:** Implement the three app files to the Behaviour, pbxproj refs, `capture-targets.rb`
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): MemoRecorderEngine capture core`

### Task 13: engine audio session, interruptions and draft manifests
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Audio/MemoDraftStore.swift` — draft manifest write/remove/list and `.caf` salvage export
- Create: `iphone/MakeReady/Services/Audio/MemoAudioSession.swift` — the session category save/set/restore behind a protocol
- Modify: `iphone/MakeReady/Services/Audio/MemoRecorderEngine.swift` — session in `prepare`/`start`/`stop`, interruption + route-change observers, draft manifest at start and removal at stop
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoEngineSessionTests.swift`

**Interfaces:**
- Consumes: `MemoRecorderEngine`, `MemoAudioExporter`, `BufferFeedInput` (Task 12)
- Produces: protocol `MemoAudioSessionControlling` — `prepareForRecording() throws`, `activate() throws`, `restore()`; live `MemoAudioSession`
- Produces: `MemoRecorderEngine.init` gains `session:` (default `MemoAudioSession()`), `drafts: MemoDraftStore`, `notificationCenter:` (default `.default`)
- Produces: `MemoDraftManifest` (Codable, Equatable): `cafURL`, `startedAt`, `title`, `ownerUserId`, `environment`
- Produces: `MemoDraftStore(directory:ownerUserId:environment:)` — `write(_:) throws`, `remove(cafURL:)`, `recoverable() -> [MemoDraftManifest]` (`.caf` exists and non-empty, this owner + environment), `salvage(_:) async throws -> (m4a: URL, durationMs: Int, peaks: [Double])`

**Behaviour:**
- `prepare` → `session.prepareForRecording()`: saves the current category, sets `.playAndRecord` mode `.spokenAudio`; `start` → `session.activate()`; `stop` → `session.restore()` puts back the saved category (D20)
- `AVAudioSession.interruptionNotification` `.began` → `pause()`; `.ended` with `.shouldResume` → `resume()`; `.ended` without it stays paused (D16)
- `routeChangeNotification` reason `.oldDeviceUnavailable` → `pause()`; a new input format reuses Task 12's converter path (D16, F8)
- `start` writes `<cafURL minus extension>.json` holding the manifest before the first buffer; `stop` removes it after the export succeeds (D16)
- `salvage` reads the abandoned `.caf` for `durationMs` and peaks (one max-abs per 4 410 frames), exports it with `MemoAudioExporter`, and deletes `.caf` + manifest only after the export succeeds (D16, D38, D42)
- `recoverable()` ignores manifests of another `ownerUserId` or `environment` (D37)

**Tests:** (a `SpySession` records calls; interruptions are posted on a private `NotificationCenter`)

- `testSessionIsPreparedActivatedAndRestored` (D20)

```swift
func testSessionIsPreparedActivatedAndRestored() async throws {
    let spy = SpySession(); let engine = makeEngine(seconds: 0.5, session: spy)
    try await engine.prepare(title: "Memo 1"); try await engine.start(); _ = try await engine.stop()
    XCTAssertEqual(spy.calls, ["prepare", "activate", "restore"])
}
```

- `testInterruptionPausesAndResumes` (D16)

```swift
func testInterruptionPausesAndResumes() async throws {
    let engine = makeEngine(seconds: 0.5)
    try await engine.prepare(title: "Memo 1"); try await engine.start()
    center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
    XCTAssertEqual(engine.state, .paused)
    center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
        AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue])
    XCTAssertEqual(engine.state, .recording)
}
```

- `testAManifestExistsWhileRecordingAndIsGoneAfterStop` (D16)

```swift
func testAManifestExistsWhileRecordingAndIsGoneAfterStop() async throws {
    let engine = makeEngine(seconds: 0.5)
    try await engine.prepare(title: "Memo 4"); try await engine.start()
    XCTAssertEqual(drafts.recoverable().map(\.title), ["Memo 4"])
    XCTAssertTrue(MemoDraftStore(directory: dir, ownerUserId: "other", environment: "Local").recoverable().isEmpty) // D37
    _ = try await engine.stop()
    XCTAssertTrue(drafts.recoverable().isEmpty)
}
```

- `testAnAbandonedCafIsSalvagedToAPlayableM4a` (§Testing, D38) (the writer never closed)

```swift
func testAnAbandonedCafIsSalvagedToAPlayableM4a() async throws {
    var engine: MemoRecorderEngine? = makeEngine(seconds: 1.0)
    try await engine!.prepare(title: "Memo 5"); try await engine!.start()
    engine = nil
    let manifest = try XCTUnwrap(drafts.recoverable().first)
    let out = try await drafts.salvage(manifest)
    XCTAssertEqual(try AVAudioFile(forReading: out.m4a).fileFormat.channelCount, 1)
    XCTAssertEqual(out.durationMs, 1000, accuracy: 100)
    XCTAssertEqual(out.peaks.count, Int(ceil(Double(out.durationMs) / 100)), accuracy: 1)
    XCTAssertTrue(drafts.recoverable().isEmpty)
}
```

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`MemoDraftStore` not in scope)
- [ ] **Step 2:** Implement to the Behaviour; refs; `capture-targets.rb`; re-run `MemoRecorderEngineTests` too
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): engine session, interruptions and draft salvage`

### Task 14: `MemoUploadController` lifecycle and persistent queue
App: iphone
Phase: 5
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Audio/MemoUploadController.swift` — queue manifests, the create → PUT → complete lifecycle, re-mint, re-POST
- Create: `iphone/MakeReady/Services/Audio/MemoPutTransport.swift` — protocol + `URLSession` implementation
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoUploadControllerTests.swift`

**Interfaces:**
- Consumes: §Contract rows `POST /api/memos`, `POST /api/memos/:id/upload`, `PATCH /api/memos/:id/complete` (Task 8) and Task 9's response types; `MemoActions.memoCompleted` (Task 10)
- Produces: protocol `MemoPutTransport` — `put(fileURL:to:headers:) async throws -> Int` (status); `URLSessionMemoPutTransport` (D40)
- Produces: `MemoQueueItem` (Codable): `localId`, `fileName`, `title`, `durationMs`, `waveformPeaks`, `recordedAt`, `transcript?`, `fileSize`, `serverId?`, `upload: MemoUploadTicket?`, `ownerUserId`, `environment`, `attempts`, `nextAttemptAt?`
- Produces: `@MainActor final class MemoUploadController` — `init(api:actions:transport:directory:ownerUserId:environment:now:)`; `enqueue(_ result: RecordingResult) throws`; `pending() -> [MemoQueueItem]`; `processNext() async -> MemoUploadStep` (`idle`, `completed(String)`, `retryLater`, `paused`)

**Behaviour:**
- `enqueue` moves the `.m4a` into `directory`, writes `<localId>.json` beside it, and never touches the network (D22)
- `processNext` takes the oldest due item and runs, persisting the manifest after every server step (D13, D22):
  1. no `serverId` → `POST /api/memos` (`recordedAt` via a static `ISO8601DateFormatter` with fractional seconds, F25; `transcript` + `transcriptSegments` only when a transcript exists); store `serverId` and `upload`
  2. `upload.expiresAt <= now()` → `POST /api/memos/<id>/upload` first and store the new ticket (D29)
  3. PUT through the transport with the ticket's headers; status 403 → re-mint once and PUT again; other non-2xx → `.retryLater`
  4. `PATCH /api/memos/<id>/complete` with `{}`; 200 → `actions.memoCompleted(memo)`, delete the `.m4a` and manifest, `.completed(serverId)`
- a 404 from re-mint or complete clears `serverId`/`upload`; the next pass re-POSTs (D29)
- an item with a `serverId` resumes at re-mint/PUT/complete, never re-created; its file is deleted only after complete returns 200 (D22)
- the PUT never goes through `APIClient` (no base URL, no cookie) (D40)
- a 409 on complete clears `upload`; the next pass re-mints and re-PUTs (D13, D29)
- any other failure → `.retryLater` with the item kept (backoff is Task 15's)

**Tests:** (stub `APIClientProtocol` = `StubAPIClient` with `requestWithStatus`-style errors via `errorFor`; `SpyTransport` records PUTs and returns a scripted status)

- `testCreatePutCompleteThenDeletesTheFile` (D13, D22)

```swift
func testCreatePutCompleteThenDeletesTheFile() async throws {
    try controller.enqueue(result)
    let size = try XCTUnwrap(controller.pending().first?.fileSize)
    stubCreate(id: "m1", expiresIn: 900); stubComplete(id: "m1")
    let step = await controller.processNext()
    XCTAssertEqual(step, .completed("m1"))
    XCTAssertEqual(transport.puts.count, 1)
    XCTAssertEqual(transport.puts[0].headers["Content-Length"], String(size))
    XCTAssertTrue(controller.pending().isEmpty)
    XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    XCTAssertNotNil(state.voiceMemos["m1"])
}
```

- `testAfterACrashBetweenPostAndPutItResumesWithoutASecondCreate` (§Testing, D22)

```swift
func testAfterACrashBetweenPostAndPutItResumesWithoutASecondCreate() async throws {
    try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
    transport.nextStatus = 500
    _ = await controller.processNext()
    let relaunched = makeController()
    transport.nextStatus = 200; stubComplete(id: "m1")
    let step = await relaunched.processNext()
    XCTAssertEqual(step, .completed("m1"))
    XCTAssertEqual(api.callCount("POST", "/api/memos"), 1)
}
```

- `testAnExpiredTicketOrA403IsReMinted` (D29)

```swift
func testAnExpiredTicketOrA403IsReMinted() async throws {
    try controller.enqueue(result); stubCreate(id: "m1", expiresIn: -1); stubRemint(id: "m1", url: "https://r2.test/fresh"); stubComplete(id: "m1")
    _ = await controller.processNext()
    XCTAssertEqual(api.callCount("POST", "/api/memos/m1/upload"), 1)
    XCTAssertEqual(transport.puts.last?.url.absoluteString, "https://r2.test/fresh")
    try controller.enqueue(result); stubCreate(id: "m2", expiresIn: 900); stubRemint(id: "m2", url: "https://r2.test/f2"); stubComplete(id: "m2")
    transport.statuses = [403, 200]  // a 403 PUT re-mints once
    XCTAssertEqual(await controller.processNext(), .completed("m2")); XCTAssertEqual(api.callCount("POST", "/api/memos/m2/upload"), 1)
}
```

- `testA404OnCompleteRePostsTheMemo` (§Testing, D29)

```swift
func testA404OnCompleteRePostsTheMemo() async throws {
    try controller.enqueue(result); stubCreate(id: "m1", expiresIn: 900)
    api.errorFor = { endpoint, _ in endpoint == "/api/memos/m1/complete" ? APIHTTPError(status: 404, message: "Memo not found", details: nil) : nil }
    _ = await controller.processNext()
    api.errorFor = nil; stubCreate(id: "m2", expiresIn: 900); stubComplete(id: "m2")
    XCTAssertEqual(await controller.processNext(), .completed("m2"))
    XCTAssertEqual(api.callCount("POST", "/api/memos"), 2)
}
```

- `testTheTranscriptIsSentOnlyWhenPresent` (D1, D5)

```swift
func testTheTranscriptIsSentOnlyWhenPresent() async throws {
    try controller.enqueue(resultWithoutTranscript); stubCreate(id: "m1", expiresIn: 900); stubComplete(id: "m1")
    _ = await controller.processNext()
    let body = try XCTUnwrap(api.calls.first { $0.endpoint == "/api/memos" }?.body)
    XCTAssertNil(body["transcript"]); XCTAssertNil(body["transcriptSegments"])
    XCTAssertTrue((body["recordedAt"] as? String)?.hasSuffix("Z") == true)
}
```

> ⚠ build-time risk (F24): tests are hosted in MakeReady.app, so app launch code runs in every test. Every test builds its own controller over a temp `directory`; never touch `AppState.shared`'s controller (Task 15 adds it).
> ⚠ build-time risk (F25): no `NSLog`/`print`/`asyncAfter`; `Log.memo`; the `recordedAt` formatter is `static let`.

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`MemoUploadController` not in scope)
- [ ] **Step 2:** Implement the two files to the Behaviour, pbxproj refs, `capture-targets.rb`
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): persistent MemoUploadController lifecycle`

### Task 15: flush policy, tenancy, salvage hand-off and `AppState` ownership
App: iphone
Phase: 5
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/Services/Audio/MemoUploadController.swift` — `flush()`, backoff, the 401 pause, cancel, `NWPathMonitor` trigger, `recoverDrafts`
- Create: `iphone/MakeReady/Services/Audio/MemoStorage.swift` — the per-environment, per-user folder (excluded from backup)
- Modify: `iphone/MakeReady/State/AppState.swift` — `memoUploads: MemoUploadController?`, built on sign-in for the signed-in user + environment, cancelled and released in `clearAllData` / environment switch (files kept); `nextMemoTitle()`
- Modify: `iphone/MakeReady/MakeReadyApp.swift:41-63` — a launch `.task` that, when signed in, runs `recoverDrafts()` then `flush()`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoUploadFlushTests.swift`

**Interfaces:**
- Consumes: Task 14's controller; `MemoDraftStore` (Task 13); `MemoTranscribing.transcribeFile` (Task 11); `MemoActions.nextDefaultTitle` (Task 10)
- Produces: `MemoStorage.folder(environment:userId:root: URL? = nil) throws -> URL`
- Produces on the controller: `flush() async`, `cancel()`, `isPausedForAuth`, `resumeAfterSignIn() async`, `recoverDrafts(drafts:transcriber:) async`, `startPathMonitoring()`, `static delay(forAttempt:) -> Duration`; `init` gains `sleep: (Duration) async throws -> Void` (default `Task.sleep`)
- Produces: `AppState.memoUploads: MemoUploadController?`, `AppState.nextMemoTitle() -> String`

**Behaviour:**
- `flush` runs `processNext` serially until `.idle`/`.paused`; `.retryLater` → `attempts` +1, `nextAttemptAt = now + delay(forAttempt: attempts)`, sleep it, continue; `enqueue` triggers `flush` (D22)
- `APIError.unauthorized` → `.paused`, `isPausedForAuth`, no attempt counted, no backoff, files kept, nobody signed out; `resumeAfterSignIn` clears it and flushes (D41)
- `startPathMonitoring`: an `NWPathMonitor` only while `pending()` is non-empty, flushing on `.satisfied` (D22, F24)
- `cancel` cancels the in-flight flush task; files and manifests stay (D37)
- it reads only its own folder's manifests matching its `ownerUserId` + `environment` (D37)
- `recoverDrafts`: each `recoverable()` manifest → `salvage` → `transcribeFile(m4a)` → `enqueue` with the manifest's title and `startedAt`; a failing draft is logged, the rest continue (D16)
- `AppState.nextMemoTitle()` = `MemoActions.nextDefaultTitle(existingTitles: voiceMemos titles + memoUploads?.pending() titles)` (D11, D43)
- sign-out: `clearAllData` cancels and nils `memoUploads`; the next sign-in builds one for the new user's folder (D37)
- the launch `.task` does nothing when signed out; tests never start it (F24)

**Tests:** (injected `sleep` records durations instead of sleeping; two folders from `MemoStorage` under a temp root)

- `testOfflineBacksOffThenFlushes` (§Testing, D22)

```swift
func testOfflineBacksOffThenFlushes() async throws {
    try controller.enqueue(result)
    api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
    var slept: [Duration] = []
    controller = makeController(sleep: { d in slept.append(d); if slept.count == 3 { self.api.errorFor = nil; self.stubHappyPath(id: "m1") } })
    await controller.flush()
    XCTAssertEqual(slept, [.seconds(5), .seconds(30), .seconds(120)])
    XCTAssertEqual(MemoUploadController.delay(forAttempt: 9), .seconds(600))
    XCTAssertTrue(controller.pending().isEmpty)
}
```

- `testA401PausesWithoutBackoffAndKeepsFiles` (§Testing, D41)

```swift
func testA401PausesWithoutBackoffAndKeepsFiles() async throws {
    try controller.enqueue(result); api.errorToThrow = APIError.unauthorized
    var slept: [Duration] = []; controller = makeController(sleep: { slept.append($0) })
    await controller.flush()
    XCTAssertTrue(controller.isPausedForAuth); XCTAssertTrue(slept.isEmpty)
    XCTAssertEqual(controller.pending().first?.attempts, 0); XCTAssertEqual(controller.pending().count, 1)
}
```

- `testUserBSignsInAndUploadsNoneOfUserAsMemos` (§Testing, D37)

```swift
func testUserBSignsInAndUploadsNoneOfUserAsMemos() async throws {
    let a = makeController(user: "userA"); try a.enqueue(result); a.cancel()
    let b = makeController(user: "userB"); stubHappyPath(id: "m1")
    await b.flush()
    XCTAssertEqual(api.callCount("POST", "/api/memos"), 0)
    XCTAssertEqual(makeController(user: "userA").pending().count, 1)
    let folder = try MemoStorage.folder(environment: "Local", userId: "userA", root: root)
    XCTAssertTrue(folder.path.hasSuffix("memos/Local/userA"))
    XCTAssertEqual(try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
}
```

- `testALeftoverDraftIsRecoveredAndEnqueued` (§Testing, D16)

```swift
func testALeftoverDraftIsRecoveredAndEnqueued() async throws {
    let caf = try MemoAudioFixtures.sineCAF(seconds: 1, in: draftsDir)
    try drafts.write(.init(cafURL: caf, startedAt: Date(), title: "Memo 3", ownerUserId: "userA", environment: "Local"))
    await controller.recoverDrafts(drafts: drafts, transcriber: StubTranscriber(result: nil))
    XCTAssertEqual(controller.pending().map(\.title), ["Memo 3"])
    XCTAssertNil(controller.pending().first?.transcript)
    XCTAssertTrue(drafts.recoverable().isEmpty)
}
```

- `testNextMemoTitleCountsCacheAndQueue` (D43)

```swift
func testNextMemoTitleCountsCacheAndQueue() throws {
    state.voiceMemos.upsert(summary(id: "m1", title: "Memo 4"))
    state.memoUploads = makeController(user: "userA"); try state.memoUploads!.enqueue(result(title: "Memo 6"))
    XCTAssertEqual(state.nextMemoTitle(), "Memo 7")
}
```

`MemoStorage.folder` takes an optional `root: URL` (default Application Support) so this test never writes the real folder; `MemoUploadController.delay(forAttempt:)` is the static that indexes `backoff` (1-based, capped).

- [ ] **Step 1: Write the listed tests; run them through the verifier — FAIL** (`flush` not a member)
- [ ] **Step 2:** Implement to the Behaviour; refs; `capture-targets.rb`; re-run every `Memo*Tests` class
- [ ] **Step 3: Run them — PASS**; swiftlint delta zero
- [ ] **Step 4: Commit** — `feat(memo): upload flush policy, tenancy and launch salvage`
