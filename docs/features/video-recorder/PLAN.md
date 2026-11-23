# video-recorder — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders record (or import) a video of up to 2:00 on the iPhone, from the + menu or a lesson's video activity. They can use segments, countdowns, a teleprompter and filters. Saving exports one file, transcribes it on device and uploads it in the background, and the video then appears in their Library with its transcript and plays in the lesson.

**Architecture:** d2m builds every new screen and component first (P2). The server adds the `Video` transcript fields and `libraryRemovedAt`, a new `videos.service.ts` (create, Library paging, remove-from-Library, lesson-use count, Stream refresh) and two maintenance-job steps; the contract freezes at that phase's close. The iPhone builds tested state and services, then wires d2m's views into containers and entry points.

**Tech Stack:** server — Express, Prisma over the schema YAML + Atlas, zod, vitest on the test DB, Cloudflare Stream, Groq + ffmpeg; iphone — Swift 5 / SwiftUI, `@Observable` + Actions, AVFoundation (`AVCaptureSession`, `AVAssetExportSession`, `AVVideoComposition` + Core Image), Speech (`SpeechTranscriber`), PhotosUI, XCTest (`MakeReadyCaptureTests`); d2m through the `d2m-channel` MCP server.

**Spec:** `docs/features/video-recorder/SPEC.md` (program rulings P1–P10: `docs/features/video-recording/PROGRAM.md`)

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(video-recorder): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | iphone | 1 | d2m has specced and built the video-recorder and video-detail screens, the library-home, activity-new and activities-editor changes, and the new and changed components (P2) |
| 2 | server | 2–4 | `Video` carries the transcript fields and `libraryRemovedAt`. `POST /api/videos` is strict, idempotent and creates the Media row before it returns. `GET /library`, remove-from-Library, `lessonUseCount` and the `/me` filter are served |
| 3 | server | 5–7 | The maintenance job moves pending videos to ready or error and transcribes pending ones from Stream. Fixtures seed every Library video state. 🔴 The contract freezes |
| 4 | iphone | 8–13 | The stores, Actions, recorder timeline, capture engine, draft store, exporter, transcriber and upload queue exist and are tested, with no screen wired yet |
| 5 | iphone | 14–18 | The screens are live: Library video rows and Type filter, Video detail, the full-screen recorder from +, Review/import/trim/Save, and the lesson video activity |

---

### Task 1: File the d2m handover requests and wait for the builds
App: iphone
Phase: 1
Recipe: REFERENCE §Prototype mode (design is d2m's; this task only requests and records)

**Files:**
- Modify (by d2m, not by hand): `iphone/MakeReadyUI/**` — the subjects below
- Create: `.builder/video-recorder/d2m-api.md` (workspace, git-ignored) — the names d2m shipped, for Tasks 14–18

**Interfaces:**
- Consumes: SPEC §iphone "Phase 1 is d2m" list, §Decisions D1–D9, D15–D19, the program's `01-youtube-1-analysis.md`, `02-youtube-2-analysis.md`, `03-figma-design.md` and the Figma frames `3567:34892` / `3567:34787`.
- Produces (requested names; `d2m-api.md` records any deviation, and Tasks 14–18 use what it records):
  - `VideoRecorderScreen(layout: .fullScreen | .lessonInline)` whose `State.phase` is `.ready`, `.preRoll(Int)`, `.recording`, `.paused`, `.endCountdown(Int)`, `.permissionDenied`, `.review`, `.trim`, plus segments (fractions of the length), length, filter and strength, teleprompter; callbacks for record, delete last, done, `onRail(RailTool)` (`.flip`, `.countdown`, `.length`, `.filters`, `.teleprompter`, D1), import, close, retake, save, open Settings — and the SPEC §iphone component list
  - `VideoDetailScreen`; `LibraryItemType.video` ("Videos") after `.memo` and the video row (D15); C-132's optional action; C-142 `removesRow: false`; the Video tile, the inline recorder, the pending activity and **Replace video** in the activity screens (D18); the tokens

**Behaviour:**
- one `request_project_change` per subject: screens `video-recorder`, `video-detail`, `library-home`, `activity-new`, `activities-editor`; components C-132, C-142, C-013. Each has `references` set to the SPEC plus the three program docs (committed on this branch) and `branch` set to the current branch, with an intent of ≤ 2000 characters naming the decisions it implements (P2)
- the `video-detail` request asks d2m to settle memo-detail's unseen states first (draft, no frozen snapshot) and to list each state it designs (F9 — build-time risk: the d2m phase settles video-detail's states before owner approval)
- the `video-recorder` request names d2m to pick the teleprompter glyph (D1) and the 7 filter looks (D6)
- `wait_project_change` until each is done. A handback is settled from the SPEC: `questions` → `answer_project_change` with the ruling's text; a failed step → `retry_project_change`; a held item that is a build checkpoint → `approve_project_change`. A hold for the owner's screen approval (P2: "The owner approves each screen in d2m before any app wiring starts") is a person's step: the build parks `human-step` naming the screens awaiting approval. Park also when `next` starts `cannot be done:` (P2)
- the d2m-channel tools are MCP: this task runs where the `d2m-channel` server is connected (the orchestrator), not in an implementer without MCP

**Tests:**
- `the app still compiles and its suite passes on d2m's last commit` — no new assertions: d2m captures and diffs every screen state (SPEC §Testing); a case d2m made obsolete is listed in `d2m-api.md`

- [ ] **Step 1: Confirm the tree is clean** — `git status --short` is empty
- [ ] **Step 2: File the eight requests** — `request_project_change` per subject, per the Behaviour
- [ ] **Step 3: Wait and settle handbacks** — `wait_project_change` per subject until done (call again on `timedOut`)
- [ ] **Step 4: Record the shipped names** — write `d2m-api.md` from d2m's commits (`git log -p`)
- [ ] **Step 5: Run the iphone-xctest suite on HEAD** — PASS, except cases listed in `d2m-api.md`

### Task 2: `Video` transcript and Library columns
App: server
Phase: 2
Recipe: REFERENCE §Schema & API changes

**Files:**
- Modify: `server/schema/schema.yaml:1296-1345` — the `Video` fields and an `indexes:` block
- Create (generated, never hand-edited): `server/atlas/migrations/<timestamp>_video_transcript_library.sql` and the regenerated `server/prisma/schema.prisma`
- Test: `server/test/video-schema-migration.test.ts` — the columns, defaults and indexes on the test DB

**Interfaces:**
- Produces: Prisma `Video` fields `transcript: string | null`, `transcriptSegments: Json | null`, `transcriptStatus: string` (default `'none'`), `transcriptSource: string | null`, `transcriptAttempts: number` (default 0), `transcriptClaimedAt: Date | null`, `libraryRemovedAt: Date | null`; indexes `(userId, createdAt, id)` and `(status, createdAt)`

**Behaviour:**
- the YAML additions, following VoiceMemo's field style (`schema.yaml:3475-3490`); plain strings, no Prisma enum (SC1–SC7, SC10, Data plan):

```yaml
      transcript:          { type: text, nullable: true }
      transcriptSegments:  { type: json, nullable: true }
      transcriptStatus:    { type: string, default: "none", description: "none, pending, ready, failed" }
      transcriptSource:    { type: string, nullable: true, description: "on_device, server" }
      transcriptAttempts:  { type: int, default: 0 }
      transcriptClaimedAt: { type: datetime, nullable: true }
      libraryRemovedAt:    { type: datetime, nullable: true }
    indexes:
      - fields: [userId, createdAt, id]
      - fields: [status, createdAt]
```

  Write them in the block style the file uses; the keys and values are the ones above
- the migration is generated with `npm run schema:diff` and committed as generated; it adds nullable or defaulted columns only, so no backfill (Data plan)

**Tests:**
- `existing rows default to transcriptStatus none and attempts 0` (SC3, SC5)

```ts
it('existing rows default to transcriptStatus none and attempts 0', async () => {
  const v = await prisma.video.create({ data: { cloudflareUid: `mig-${stamp}`, playbackUrl: '', userId } })
  expect(v.transcriptStatus).toBe('none')
  expect(v.transcriptAttempts).toBe(0)
  expect(v.transcript).toBeNull()
  expect(v.libraryRemovedAt).toBeNull()
})
```

- `the two indexes exist` — `pg_indexes` for `videos` lists `("userId", "createdAt", id)` and `(status, "createdAt")` (SC7, SC10)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run test/video-schema-migration.test.ts`, watch them fail** — unknown field `transcriptStatus`
- [ ] **Step 3: Edit the YAML, run `npm run schema:validate` and `npm run schema:diff`**, then apply to the test DB as `server/.claude/CLAUDE.md` says
- [ ] **Step 4: Run the test, watch it pass**; run `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(video-recorder): Video transcript and libraryRemovedAt columns`

### Task 3: `videos.service.createVideo` — strict, idempotent, Media row awaited
App: server
Phase: 2
Recipe: api

**Files:**
- Create: `server/src/services/videos.service.ts` — video business logic (this task: `createVideoBody`, `createVideo`, `VideoServiceError`)
- Modify: `server/src/routes/videos.ts:360-465` — POST `/` calls `createVideo` and maps its result; the inline `createVideoSchema` moves to the service; `captureToLibrary` is no longer called from this route; OpenAPI block updated
- Test: `server/src/services/__tests__/videos-create.test.ts` — the service; `server/test/videos-create-http.test.ts` — the route

**Interfaces:**
- Consumes: `getUserOrgId` (`media-library.ts:114`), `getVideo` from `cloudflare.ts:165` (`meta.userId`), the Task 2 fields
- Produces: `createVideoBody` (zod); `createVideo(userId, body)` — returns `{ status: 200 | 201, video }` or throws `VideoServiceError(status, message)` with 400/403/409; the route answers `{success: true, data: video}` with that status
- Produces the frozen contract row:

```
| `POST /api/videos` (EDIT) | server | iphone | session; uploader | existing `{cloudflareUid, title?, description?}` plus optional `transcript` (string ≤ 20 000), `transcriptSegments` (`[{text ≤ 1 000, startMs, endMs}]` ≤ 2 000 items, each `0 ≤ startMs ≤ endMs`), `source` (`recording` | `import`; accepted, not persisted) (D24) | **201** `{success, data: Video}` (existing), where `data` adds `transcript`, `transcriptSegments`, `transcriptStatus` (`none`|`pending`|`ready`|`failed`), `transcriptSource` (`on_device`|`server`|null), `libraryRemovedAt` (null). The org Media row exists when it returns (D21). A same-owner duplicate uid → **200** with the existing row (D22) | 400 invalid body (`createVideoSchema.extend({…}).strict()` — never stripping), 401, 403 Stream `meta.userId` is another user, 409 uid owned by another user |
```

**Behaviour:**
- the body is `createVideoSchema.extend({ transcript, transcriptSegments, source }).strict()`. The segment is `z.object({ text: z.string().max(1000), startMs: z.number().int().min(0), endMs: z.number().int().min(0) }).strict()` with a refine `startMs ≤ endMs`; `transcript` `.max(20000)`, `transcriptSegments` `.max(2000)`, `source` `z.enum(['recording','import'])`. Unknown keys → 400 (D24, global zod rule)
- status: transcript sent → `transcriptStatus: 'ready', transcriptSource: 'on_device'`; `source` sent without a transcript → `'pending'`, source null; neither → `'none'` (legacy callers) (§server, D10)
- an existing row with this `cloudflareUid`: same `userId` → 200 with it; another user → 409 "Video already exists". A concurrent create's Prisma `P2002` is caught, the row re-read, and answered by the same rule (D22)
- Stream `meta.userId` present and ≠ caller → 403 (D22)
- the Media row is **awaited** inside the request: when `getUserOrgId(userId)` returns an org, create `Media` keyed on `videoId` exactly as `routes/media.ts:1384` does (type VIDEO, `url: ''` while pending, the org, the uploader). No dedupe on `{url, organizationId}`. No org → the Video only (D21)
- the Video row and its Media row are written in one `prisma.$transaction`, so a Media failure leaves no Video and the retry is a fresh create (D21, D22)

**Pattern:**
- `server/src/services/memos.service.ts:12-27` — the strict segment and body schema
- `server/src/routes/media.ts:1361-1412` — the awaited Media create keyed on `videoId`

**Tests:**
- `a transcript sets ready / on_device; source alone sets pending; neither sets none` (D10)

```ts
it('sets transcriptStatus by what the body carries', async () => {
  const a = await createVideo(userId, { cloudflareUid: uid(), transcript: 'hi', transcriptSegments: [{ text: 'hi', startMs: 0, endMs: 400 }], source: 'recording' })
  expect(a.video).toMatchObject({ transcriptStatus: 'ready', transcriptSource: 'on_device', transcript: 'hi' })
  const b = await createVideo(userId, { cloudflareUid: uid(), source: 'import' })
  expect(b.video).toMatchObject({ transcriptStatus: 'pending', transcriptSource: null })
  const c = await createVideo(userId, { cloudflareUid: uid() })
  expect(c.video.transcriptStatus).toBe('none')
})
```

- `an unknown field and over-limit bodies are 400, never stripped` (D24)

```ts
it.each([
  [{ cloudflareUid: 'x', extra: 1 }],
  [{ cloudflareUid: 'x', transcript: 'a'.repeat(20_001) }],
  [{ cloudflareUid: 'x', transcriptSegments: Array.from({ length: 2001 }, () => ({ text: 'a', startMs: 0, endMs: 1 })) }],
  [{ cloudflareUid: 'x', transcriptSegments: [{ text: 'a'.repeat(1001), startMs: 0, endMs: 1 }] }],
  [{ cloudflareUid: 'x', transcriptSegments: [{ text: 'a', startMs: 5, endMs: 1 }] }],
])('rejects %j', (body) => {
  expect(createVideoBody.safeParse(body).success).toBe(false)
})
```

- `a same-owner duplicate answers 200 with the row; another user's is 409` (D22)

```ts
it('is idempotent for its owner', async () => {
  const u = uid()
  const first = await createVideo(userId, { cloudflareUid: u })
  expect(first.status).toBe(201)
  const again = await createVideo(userId, { cloudflareUid: u })
  expect(again).toMatchObject({ status: 200, video: { id: first.video.id } })
  await expect(createVideo(otherUserId, { cloudflareUid: u })).rejects.toMatchObject({ status: 409 })
})
```

- `two concurrent creates of one uid both succeed with one row` (D22)

```ts
it('catches P2002 on a concurrent duplicate', async () => {
  const u = uid()
  const [a, b] = await Promise.all([createVideo(userId, { cloudflareUid: u }), createVideo(userId, { cloudflareUid: u })])
  expect(a.video.id).toBe(b.video.id)
  expect([a.status, b.status].sort()).toEqual([200, 201])
  expect(await prisma.video.count({ where: { cloudflareUid: u } })).toBe(1)
})
```

- `two pending videos in one org each get their own Media row, and an activity can name the second at once` (D21, F2)

```ts
it('creates a Media row per video before returning', async () => {
  const one = await createVideo(orgOwnerId, { cloudflareUid: uid(), source: 'recording' })
  const two = await createVideo(orgOwnerId, { cloudflareUid: uid(), source: 'recording' })
  expect(await prisma.media.count({ where: { videoId: one.video.id } })).toBe(1)
  expect(await prisma.media.count({ where: { videoId: two.video.id } })).toBe(1)
  await expect(assertDocumentMediaAllowed(prisma, orgOwnerId, { videoIds: [two.video.id], mediaIds: [] })).resolves.not.toThrow()
})
```

- `POST /api/videos returns 201 then 200 for the owner, 409 for another, 400 for an unknown key` — supertest with `bearer()`: 201 with `data.transcriptStatus: 'pending'` and `libraryRemovedAt: null`, then 200, 409 for a stranger, 400 for `{nope: 1}` (§Testing, D22)

- [ ] **Step 1: Write the listed tests** — mock `cloudflare.getVideo` with `vi.mock` (no network); match `assertDocumentMediaAllowed`'s real argument shape at `content-media.service.ts:40-65`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/videos-create.test.ts test/videos-create-http.test.ts`, watch them fail** — module not found
- [ ] **Step 3: Implement `createVideoBody`, `createVideo`, `VideoServiceError`; thin the route** to the Behaviour; `docker restart makeready-server`
- [ ] **Step 4: Run them, watch them pass**; run `test/video-authorization.test.ts` too, and `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(video-recorder): strict idempotent POST /api/videos with awaited Media row`

### Task 4: Library list, remove-from-Library, `lessonUseCount`, `/me` filter
App: server
Phase: 2
Recipe: api

**Files:**
- Modify: `server/src/services/videos.service.ts` — `listLibraryVideos`, `removeFromLibrary`, `lessonUseCount`
- Modify: `server/src/services/content-media.service.ts:131-139` — `isUsedByActivity` calls the shared `videoActivityUseCount` predicate
- Modify: `server/src/routes/videos.ts` — `GET /library` registered beside `/me` and **before** `GET /:videoId`; `POST /:videoId/remove-from-library`; `GET /me` filter `libraryRemovedAt: null`; `GET /:videoId` adds `lessonUseCount`; OpenAPI blocks
- Test: `server/src/services/__tests__/videos-library.test.ts`; `server/test/videos-library-http.test.ts`

**Interfaces:**
- Consumes: `encodeCursor` / `decodeCursor` (`media-library.ts:78-94`)
- Produces: `listLibraryVideos(userId, { limit, cursor, q })` → `{ data: VideoSummary[], nextCursor: string | null, hasMore: boolean }`; `removeFromLibrary(userId, id)` → `{ id, libraryRemovedAt }` or throws 403/404; `videoActivityUseCount(db, videoId)` → number (in `content-media.service.ts`); `lessonUseCount(videoId)` → number
- Produces the frozen contract rows:

```
| `GET /api/videos/library` (NEW) | server | iphone | session; own videos | `?limit=1..100 (default 50)&cursor=<opaque>&q=<text>` | `{success, data: VideoSummary[], nextCursor: string|null, hasMore: boolean}`. `VideoSummary` = `id, title, thumbnailUrl, playbackUrl, duration, status, transcriptStatus, transcriptPreview (≤ 160 chars), createdAt`. Ordered `createdAt desc, id desc` (keyset). Only `isActive`, `libraryRemovedAt IS NULL`, `userId = caller`. `q` matches title or transcript (case-insensitive substring) | 400 bad cursor or limit, 401 |
| `GET /api/videos/:videoId` (EDIT) | server | iphone | session; owner or org content manager (unchanged) | — | existing `{success, data: Video}`, where `data` adds the transcript fields, `libraryRemovedAt` and `lessonUseCount` — distinct `MediaUsage.resourceId` with `usageType: ACTIVITY` over the Media rows whose `videoId` is this video, the predicate `isUsedByActivity` uses (it counts activities, any version) | 401, 403, 404 |
| `POST /api/videos/:videoId/remove-from-library` (NEW) | server | iphone | session; owner | — | `{success, data: {id, libraryRemovedAt}}`. Idempotent: a second call returns the same timestamp | 401, 403 not the owner, 404 |
| `GET /api/videos/me` (EDIT) | server | client (iphone: no in-target caller; the released decoder ignores the change) | session (unchanged) | unchanged | unchanged shape, now excluding rows with `libraryRemovedAt` set | unchanged |
```

**Behaviour:**
- keyset: `WHERE "userId" = $caller AND "isActive" AND "libraryRemovedAt" IS NULL [AND (title ILIKE $p OR transcript ILIKE $p)] [AND ("createdAt", id) < ($c.createdAt, $c.id)] ORDER BY "createdAt" DESC, id DESC LIMIT $limit + 1`. `hasMore` = the extra row exists; `nextCursor` encodes the last returned row's `(createdAt, id)` and is null when `!hasMore` (D20, SC7)
- `q` is ILIKE-escaped (`%`, `_`, `\`) as `memos.service.ts:172-191`; `transcriptPreview` is `left(transcript, 160)` in SQL, never the full transcript (§server)
- `limit` outside 1..100, a non-integer limit or an undecodable cursor → 400 (Contract)
- `removeFromLibrary`: 404 when no row; 403 when `userId` ≠ caller (the owner only, not org managers — §server Authorization); sets `libraryRemovedAt = now()` only when null and returns the stored value (idempotent) (D17)
- `videoActivityUseCount` = count of distinct `MediaUsage.resourceId` with `usageType: 'ACTIVITY'` whose `mediaId` is a Media row with this `videoId`; `isUsedByActivity` returns `count > 0` from it, so DELETE's 409 guard and the count agree (F2, D17)
- `GET /:videoId` keeps its uploader-or-`canManageOrgContent` check and adds `lessonUseCount` (Contract)

**Pattern:**
- `server/src/services/media-library.ts:395-444` — keyset predicate and limit + 1

**Tests:**
- `pages in createdAt desc, id desc with no duplicates or skips across equal createdAt` (D20)

```ts
it('keyset pages without skips', async () => {
  const at = new Date('2026-11-01T00:00:00Z')
  const ids = await Promise.all(Array.from({ length: 5 }, () => seedVideo(userId, { createdAt: at })))
  const p1 = await listLibraryVideos(userId, { limit: 2 })
  const p2 = await listLibraryVideos(userId, { limit: 2, cursor: p1.nextCursor! })
  const p3 = await listLibraryVideos(userId, { limit: 2, cursor: p2.nextCursor! })
  const seen = [...p1.data, ...p2.data, ...p3.data].map((v) => v.id)
  expect(new Set(seen).size).toBe(5)
  expect(seen).toEqual([...ids].sort().reverse())
  expect([p1.hasMore, p2.hasMore, p3.hasMore]).toEqual([true, true, false])
  expect(p3.nextCursor).toBeNull()
})
```

- `q matches title or transcript, case-insensitive, with % escaped` (D15)

```ts
it('searches title and transcript', async () => {
  await seedVideo(userId, { title: 'Grace Talk' })
  await seedVideo(userId, { transcript: 'today we read about GRACE' })
  await seedVideo(userId, { title: '100% done' })
  expect((await listLibraryVideos(userId, { limit: 50, q: 'grace' })).data).toHaveLength(2)
  expect((await listLibraryVideos(userId, { limit: 50, q: '%' })).data).toHaveLength(1)
})
```

- `removed, inactive and another user's rows are never listed; the preview is ≤ 160 chars` (Contract)

```ts
it('lists only the caller’s live Library videos', async () => {
  await seedVideo(userId, { libraryRemovedAt: new Date() })
  await seedVideo(userId, { isActive: false })
  await seedVideo(otherUserId, {})
  const live = await seedVideo(userId, { transcript: 'x'.repeat(500) })
  const { data } = await listLibraryVideos(userId, { limit: 50 })
  expect(data.map((v) => v.id)).toEqual([live])
  expect(data[0].transcriptPreview).toHaveLength(160)
  expect(data[0]).not.toHaveProperty('transcript')
})
```

- `removeFromLibrary is owner-only and idempotent, and /me drops the row` (D17)

```ts
it('removes from the Library once', async () => {
  const id = await seedVideo(userId, {})
  await expect(removeFromLibrary(otherUserId, id)).rejects.toMatchObject({ status: 403 })
  const a = await removeFromLibrary(userId, id)
  const b = await removeFromLibrary(userId, id)
  expect(b.libraryRemovedAt).toEqual(a.libraryRemovedAt)
  const me = await request(app).get('/api/videos/me').set(bearer(owner))
  expect(me.body.data.map((v: any) => v.id)).not.toContain(id)
})
```

- `lessonUseCount is 0 and N, and agrees with the DELETE guard` (F2, D17)

```ts
it('counts distinct activities through the Media row', async () => {
  const id = await seedVideo(userId, {})
  expect(await lessonUseCount(id)).toBe(0)
  const media = await seedMediaFor(id, orgId)
  await seedUsage(media, 'act-1'); await seedUsage(media, 'act-1'); await seedUsage(media, 'act-2')
  expect(await lessonUseCount(id)).toBe(2)
  expect((await request(app).delete(`/api/videos/${id}`).set(bearer(owner))).status).toBe(409)
})
```

- `GET /library is not captured by /:videoId, and bad cursor or limit is 400` (§server Routes)

```ts
it('routes /library before /:videoId', async () => {
  const ok = await request(app).get('/api/videos/library').set(bearer(owner))
  expect(ok.status).toBe(200)
  expect(ok.body).toHaveProperty('hasMore')
  expect((await request(app).get('/api/videos/library?cursor=%%%').set(bearer(owner))).status).toBe(400)
  expect((await request(app).get('/api/videos/library?limit=101').set(bearer(owner))).status).toBe(400)
  const one = await request(app).get(`/api/videos/${someId}`).set(bearer(owner))
  expect(one.body.data).toHaveProperty('lessonUseCount')
})
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/videos-library.test.ts test/videos-library-http.test.ts`, watch them fail**
- [ ] **Step 3: Implement the service functions, the shared predicate and the routes** to the Behaviour; `docker restart makeready-server`
- [ ] **Step 4: Run them plus `test/content-media.test.ts` and `test/video-authorization.test.ts`, watch them pass**; `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(video-recorder): Library video list, remove-from-Library, lessonUseCount`

### Task 5: `refreshFromStream` and the Stream status sync step
App: server
Phase: 3
Recipe: test-driven-development

**Files:**
- Modify: `server/src/services/videos.service.ts` — `refreshFromStream(video)`, `syncPendingVideos(now)`
- Modify: `server/src/routes/videos.ts:995-1080` — `/refresh` keeps its auth and 404 and calls `refreshFromStream`
- Modify: `server/src/jobs/memo-maintenance.ts:18-60` — a `streamSynced` step and counter
- Test: `server/src/services/__tests__/videos-stream-sync.test.ts`; extend `memo-maintenance.test.ts`

**Interfaces:**
- Produces: `refreshFromStream(video)` → the updated `Video` (same fields and `syncVideoStatus` call as today's route body); `syncPendingVideos(now: Date)` → `{ refreshed: number, expired: number }`; `MemoMaintenanceResult` gains `streamSynced: number`

**Behaviour:**
- `refreshFromStream` is the body of `/refresh` moved verbatim: `getVideo(uid)`, the update of status / playbackUrl / thumbnailUrl / duration, then `syncVideoStatus` (D23, §server)
- `syncPendingVideos` refreshes every `status = 'pending'` video with `createdAt ≥ now − 24 h`, one failure not stopping the rest. Those older than 24 h get `status: 'error'`, plus `transcriptStatus: 'failed'` when it was `'pending'` (D23)
- the step runs inside `runSteps` under the existing advisory lock `727201002`, before the fallback step Task 6 adds, with its own try/catch as the memo steps have (D23)
- F11 (build-time risk, settled here): the video document has no duration field (`activity-document.ts:170-176`) and `checkedDocument` reads `Media.duration` (null while pending), so a just-attached video activity **accepts no duration**; nothing backfills `estimatedSeconds`

**Tests:**
- `a pending video turns ready via a mocked getVideo` (D23)

```ts
it('refreshes pending videos', async () => {
  getVideo.mockResolvedValue({ success: true, video: { uid: 'u1', readyToStream: true, status: { state: 'ready' }, duration: 42, thumbnail: 't', playback: { hls: 'h' } } })
  const id = await seedVideo(userId, { cloudflareUid: 'u1', status: 'pending', createdAt: hoursAgo(1) })
  expect(await syncPendingVideos(new Date())).toMatchObject({ refreshed: 1 })
  expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'ready', duration: 42 })
})
```

- `a pending video older than 24 h becomes error, its pending transcript failed` (D23)

```ts
it('expires stale pending videos', async () => {
  const id = await seedVideo(userId, { status: 'pending', transcriptStatus: 'pending', createdAt: hoursAgo(25) })
  await syncPendingVideos(new Date())
  expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ status: 'error', transcriptStatus: 'failed' })
  expect(getVideo).not.toHaveBeenCalledWith(expect.stringContaining(id))
})
```

- `runMemoMaintenance reports streamSynced` — its result has a `streamSynced` count (D23)

- [ ] **Step 1: Write the listed tests** — `vi.mock('../cloudflare.js')` for `getVideo`; match `GetVideoResult`'s real shape at `cloudflare.ts:48`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/videos-stream-sync.test.ts src/services/__tests__/memo-maintenance.test.ts`, watch them fail**
- [ ] **Step 3: Move the body, add `syncPendingVideos` and the step**; `docker restart makeready-server`
- [ ] **Step 4: Run them plus `test/video-authorization.test.ts` (refresh cases), watch them pass**; `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(video-recorder): Stream status sync in the maintenance job`

### Task 6: Server fallback transcription from Stream downloads
App: server
Phase: 3
Recipe: test-driven-development

**Files:**
- Modify: `server/src/services/cloudflare.ts` — `createDownload(uid)`, `getDownload(uid)`, `deleteDownload(uid)`
- Modify: `server/src/services/transcription.service.ts:93-145` — extract `transcribeAudio(audio, deps)`; `transcribeMemo` calls it unchanged in behaviour; add `transcribeVideo(videoId, deps)`
- Modify: `server/src/services/videos.service.ts` — `videoIdsDueForTranscript()`
- Modify: `server/src/jobs/memo-maintenance.ts` — a `videosTranscribed` step after stream sync
- Test: extend `server/src/services/__tests__/transcription.test.ts` and `memo-maintenance.test.ts`

**Interfaces:**
- Produces: `createDownload(uid)` → `{ status: 'inprogress' | 'ready' | 'error', url?: string }` (`POST /accounts/{acct}/stream/{uid}/downloads`); `getDownload(uid)` → the same (`GET …/downloads`); `deleteDownload(uid)` → void (`DELETE …/downloads`); `transcribeAudio(audio: Buffer, deps)` → `{ text, segments }`; `transcribeVideo(videoId, deps)` → `'ready' | 'failed' | 'not-claimed' | 'in-progress' | 'no-key'`; `videoIdsDueForTranscript()` → string[]
- `TranscribeDeps` gains `download?: (url: string) => Promise<Buffer>`, `extractAudio?: (mp4: Buffer) => Promise<Buffer>` and `stream?: { createDownload, getDownload, deleteDownload }`

**Behaviour:**
- the claim is `transcribeMemo`'s (`transcription.service.ts:104-113`) on `prisma.video`, with `status: 'ready'` in place of `uploadStatus: 'ready'` and attempts `< 3`; `libraryRemovedAt` is **not** in the predicate (D11)
- after the claim: `getDownload` → none → `createDownload`; status `inprogress` → release the claim (`transcriptClaimedAt: null`, attempts unchanged) and return `'in-progress'`; `ready` → download the MP4, ffmpeg `-vn -c:a copy` to `.m4a`, then the same chunk/Groq path as memos via `transcribeAudio`, then `deleteDownload` (in a `finally` once a download was fetched) (D11)
- success → `transcript`, `transcriptSegments`, `transcriptStatus: 'ready'`, `transcriptSource: 'server'`, claim cleared; an error → `transcriptAttempts + 1`, `transcriptStatus: 'failed'`, claim cleared — after the third failed attempt the claim no longer matches, so it stays `failed` (D11)
- no `GROQ_API_KEY` → the step is skipped, as memos' is (`memo-maintenance.ts` D33 comment) (D11)
- `videoIdsDueForTranscript` selects ids matching the claim's predicate without the claim timestamp, ordered by `createdAt` (D11, SC10)
- F1 (build-time risk): check the Stream downloads API's call and response shape against Cloudflare's docs before writing the client; the tests mock `stream`, so name the shape used in the report

**Tests:**
- `transcribeVideo claims a pending ready video and stores a server transcript` (D11)

```ts
it('transcribes from the Stream download', async () => {
  const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
  const stream = { getDownload: vi.fn().mockResolvedValue({ status: 'ready', url: 'https://dl/x.mp4' }), createDownload: vi.fn(), deleteDownload: vi.fn() }
  const out = await transcribeVideo(id, { env: { GROQ_API_KEY: 'k' }, stream, download: async () => Buffer.from('mp4'), extractAudio: async () => Buffer.from('m4a'), groq: fakeGroq('hello', [{ text: 'hello', startMs: 0, endMs: 500 }]) })
  expect(out).toBe('ready')
  expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcript: 'hello', transcriptStatus: 'ready', transcriptSource: 'server', transcriptClaimedAt: null })
  expect(stream.deleteDownload).toHaveBeenCalled()
})
```

- `a download in progress releases the claim without spending an attempt` (D11)

```ts
it('waits for an in-progress download', async () => {
  const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
  const stream = { getDownload: vi.fn().mockResolvedValue(null), createDownload: vi.fn().mockResolvedValue({ status: 'inprogress' }), deleteDownload: vi.fn() }
  expect(await transcribeVideo(id, { env: { GROQ_API_KEY: 'k' }, stream })).toBe('in-progress')
  expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcriptAttempts: 0, transcriptClaimedAt: null, transcriptStatus: 'pending' })
})
```

- `three failures leave it failed and unclaimable` (D11)

```ts
it('gives up after 3 attempts', async () => {
  const id = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending' })
  const deps = { env: { GROQ_API_KEY: 'k' }, stream: readyStream(), download: async () => { throw new Error('boom') } }
  for (let i = 0; i < 3; i++) expect(await transcribeVideo(id, deps)).toBe('failed')
  expect(await transcribeVideo(id, deps)).toBe('not-claimed')
  expect(await prisma.video.findUnique({ where: { id } })).toMatchObject({ transcriptAttempts: 3, transcriptStatus: 'failed' })
})
```

- `a video not yet status ready is skipped; a removed-from-Library one is not` (D11)

```ts
it('claims only ready videos, removed ones included', async () => {
  const pendingStream = await seedVideo(userId, { status: 'pending', transcriptStatus: 'pending' })
  const removed = await seedVideo(userId, { status: 'ready', transcriptStatus: 'pending', libraryRemovedAt: new Date() })
  const due = await videoIdsDueForTranscript()
  expect(due).toContain(removed)
  expect(due).not.toContain(pendingStream)
})
```

- `transcribeMemo behaves as before` — the existing memo cases in `transcription.test.ts` pass unchanged against the extracted core

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/transcription.test.ts src/services/__tests__/memo-maintenance.test.ts`, watch the new ones fail**
- [ ] **Step 3: Add the Stream downloads client, extract `transcribeAudio`, add `transcribeVideo`, the due query and the job step**; `docker restart makeready-server`
- [ ] **Step 4: Run them, watch all pass**; `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(video-recorder): server fallback transcription from Stream downloads`

### Task 7: Fixtures for Library videos and Video detail, and the contract freeze
App: server
Phase: 3
Recipe: test-driven-development

**Files:**
- Modify: `server/fixtures/screens/library-home.ts` — `libraryHomeVideos(now, daysAgo)` and its seeding in `full`
- Create: `server/fixtures/screens/video-detail.ts` — one ready video with a transcript and segments
- Modify: `server/fixtures/index.ts` (or the registry the other screens use) — register `video-detail`
- Test: `server/fixtures/__tests__/library-home.test.ts` (extend); `server/fixtures/__tests__/video-detail.test.ts`
- Modify (manifest): `docs/features/video-recorder/MANIFEST.md` — `contract: frozen <date>` via `advance.mjs`

**Interfaces:**
- Produces: `libraryHomeVideos(now, daysAgo)` → the Video rows plus one Media row and one MediaUsage; `video-detail` layer `full(ctx)`

**Behaviour:**
- library-home gains 4 videos for `FIXTURE_USER_ID`: `ready` with a transcript, `pending` (transcriptStatus `pending`), `failed` (status `ready`, transcriptStatus `failed`), and one used in a lesson (a Media row with its `videoId` in a fixture org plus a `MediaUsage` with `usageType: 'ACTIVITY'`) (§iphone Fixtures)
- ids are `fixtureId('video', 2001…2004)` and `video-detail` uses `fixtureId('video', 2101)`, distinct from `groups-detail.ts`'s (§iphone Fixtures)
- layers create no org, user or group, and take dates from `ctx.now` (House rules · fixtures)
- after this task's commit, the phase's last step records the freeze: `node <builder>/scripts/advance.mjs docs/features/video-recorder --set "contract=frozen <YYYY-MM-DD>" --commit "chore(video-recorder): contract frozen"` (REFERENCE §Contract and the contract freeze)

**Tests:**
- `library-home seeds one video per state` (§iphone Fixtures)

```ts
it('library-home seeds one video per state', () => {
  const { videos, media, usages } = libraryHomeVideos(now, daysAgo)
  expect(videos.map((v) => [v.status, v.transcriptStatus])).toEqual([['ready', 'ready'], ['pending', 'pending'], ['ready', 'failed'], ['ready', 'ready']])
  expect(new Set(videos.map((v) => v.id)).size).toBe(4)
  expect(media).toHaveLength(1)
  expect(usages[0]).toMatchObject({ usageType: 'ACTIVITY', mediaId: media[0].id })
})
```

- `video-detail seeds one ready video with segments` (§iphone Fixtures)

```ts
it('video-detail seeds one ready video with segments', () => {
  const v = videoDetailRow(now)
  expect(v).toMatchObject({ id: fixtureId('video', 2101), status: 'ready', transcriptStatus: 'ready', transcriptSource: 'on_device' })
  expect((v.transcriptSegments as unknown[]).length).toBeGreaterThan(1)
})
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/library-home.test.ts fixtures/__tests__/video-detail.test.ts`, watch them fail**
- [ ] **Step 3: Implement the layers** to the Behaviour
- [ ] **Step 4: Run them (and the `.db.test.ts` twins, which run with `FIXTURES_TEST_DATABASE_URL`), watch them pass**; the fixtures typecheck
- [ ] **Step 5: Commit** — `feat(video-recorder): Library video and video-detail fixtures`
- [ ] **Step 6: Record the freeze** — the `advance.mjs` call in the Behaviour, once the phase verifies

### Task 8: `Video` fields, `VideoSummary` and the `libraryVideos` window
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Models/VideoModels.swift:29-92` — Optional `transcript`, `transcriptSegments`, `transcriptStatus`, `transcriptSource`, `libraryRemovedAt`, `lessonUseCount`; new `VideoSummary`, `VideoTranscriptSegment`, `VideoLibraryWindow`
- Modify: `iphone/MakeReady/State/AppState.swift:85,201,994-1013` — `libraryVideos: EntityStore<VideoSummary>`, `videoLibraryWindow`, cleared in `clearInMemory()`
- Modify: `iphone/MakeReady/State/Persistence/PersistedState.swift:27,122,167,215,224,289` — persist `libraryVideos` (cap 100) and the window; `decodeIfPresent` for the new keys; drop `transcriptSegments` on write
- Test: `iphone/MakeReadyCaptureTests/VideoModelsTests.swift`; `iphone/MakeReadyCaptureTests/PersistedVideoSnapshotTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references for new files, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: the frozen §Contract `VideoSummary` and `Video` additions
- Produces: `VideoSummary` (`id, title?, thumbnailUrl?, playbackUrl, duration?, status, transcriptStatus, transcriptPreview?, createdAt`); `VideoLibraryWindow` (`ids: [String]`, `nextCursor: String?`, `hasMore: Bool`, `query: String?`) with `replacing(with page:)` and `appending(page:)`; `AppState.libraryVideos`, `AppState.videoLibraryWindow`

**Behaviour:**
- every new `Video` property is Optional; the snapshot decode uses `decodeIfPresent`, so an old cache decodes (D27, F12 — build-time risk: a decode test of an old snapshot)
- the persisted `videos` snapshot writes `transcriptSegments` as nil (D27)
- `replacing` sets ids to the page's ids (removed videos drop out); `appending` adds ids not already present, in order (D20)
- `libraryVideos` persists at most 100 entries, the window's first 100 ids (D27, `MediaActions.libraryPageSize`)

**Pattern:**
- `iphone/MakeReady/State/Models/InvitationModels.swift:115` — `InvitationFeedWindow` (R-28)

**Tests:**
- `an old snapshot without the new keys still decodes every store` (F12, D27)

```swift
func testOldSnapshotDecodes() throws {
    let json = #"{"videos":[{"id":"v1","cloudflareUid":"u","playbackUrl":"","status":"ready","userId":"me","createdAt":"2026-11-01T00:00:00Z","updatedAt":"2026-11-01T00:00:00Z"}]}"#
    let state = try JSONDecoder.apiDecoder.decode(PersistedState.self, from: Data(json.utf8))
    XCTAssertEqual(state.videos?.first?.id, "v1")
    XCTAssertNil(state.videos?.first?.transcriptStatus)
}
```

- `the written snapshot drops transcriptSegments` (D27)

```swift
func testSnapshotDropsSegments() throws {
    var v = Video.fixture(id: "v1"); v.transcriptSegments = [VideoTranscriptSegment(text: "a", startMs: 0, endMs: 1)]
    let data = try JSONEncoder.apiEncoder.encode(PersistedState.snapshot(videos: [v]))
    XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("startMs"))
}
```

- `a page-1 replace drops ids the server no longer lists; append keeps order and dedupes` (D20)

```swift
func testWindowReplaceAndAppend() {
    var w = VideoLibraryWindow(ids: ["a", "b", "c"], nextCursor: "x", hasMore: true, query: nil)
    w = w.replacing(with: .init(ids: ["b", "d"], nextCursor: "y", hasMore: true))
    XCTAssertEqual(w.ids, ["b", "d"])
    w = w.appending(page: .init(ids: ["d", "e"], nextCursor: nil, hasMore: false))
    XCTAssertEqual(w.ids, ["b", "d", "e"]); XCTAssertFalse(w.hasMore)
}
```

- [ ] **Step 1: Write the listed tests** — adapt the call sites to `PersistedState`'s real API at `PersistedState.swift:27,289`, keeping the assertions
- [ ] **Step 2: Run the iphone-xctest suite for `VideoModelsTests` and `PersistedVideoSnapshotTests`, watch them fail**
- [ ] **Step 3: Implement the models, the store, the window and the persistence** to the Behaviour
- [ ] **Step 4: Run them plus `EntityStoreTests`, watch them pass**; `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(video-recorder): Video transcript fields and the Library video window`

### Task 9: `VideoActions` for the Library, detail and delete-or-remove
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Actions/VideoActions.swift` — `loadLibrary(cursor:q:)`, `loadDetail(id:)`, `rename(id:title:)`, `removeFromLibrary(id:)`, `deleteDecision(id:)`, `deleteOrRemove(id:decision:)`
- Modify: `iphone/MakeReady/State/Actions/MemoActions.swift:8,97-111` — `nextDefaultTitle(prefix:existingTitles:)`; the memo call sites pass `"Memo"`
- Modify: `iphone/MakeReady/State/AppState.swift:822` — `nextVideoTitle()` beside `nextMemoTitle()`, counting queued videos
- Test: `iphone/MakeReadyCaptureTests/VideoActionsLibraryTests.swift`; extend `MemoActionsTests.swift`

**Interfaces:**
- Consumes: `GET /api/videos/library`, `GET /api/videos/:id`, `PATCH /api/videos/:id`, `POST /api/videos/:id/remove-from-library`, `DELETE /api/videos/:id` (frozen §Contract); `VideoLibraryWindow` (Task 8)
- Produces: `VideoDeleteDecision` = `.delete` | `.removeFromLibrary(lessonCount: Int)`, with `confirmTitle`; `VideoActions.deleteDecision(id:) async throws -> VideoDeleteDecision`; `VideoActions.deleteOrRemove(id:decision:) async throws`; `AppState.nextVideoTitle() -> String`; `VideoActions.loadLibrary(cursor: String?, q: String?) async throws`

**Behaviour:**
- `loadLibrary(cursor: nil, …)` replaces the window; with a cursor it appends; both upsert `libraryVideos` (D20, D27)
- `loadDetail` upserts `videos`; `rename` PATCHes the title and upserts both stores; `removeFromLibrary` and `delete` drop the id from both stores and the window in the same Action (D27)
- `deleteDecision` reads `lessonUseCount` from `GET /api/videos/:id`: 0 → `.delete`; N → `.removeFromLibrary(lessonCount: N)`. A thrown error propagates for the caller's error banner (D17)
- confirm copy, exactly (D17):
  - `.delete` → "Delete this video?"
  - `.removeFromLibrary(n)` → "This video is used in \(n) lesson activities. It will stay in them and leave your Library."
- `nextDefaultTitle(prefix: "Video", …)` returns `Video n` with n = 1 + the highest existing `Video n` among the Library titles and queued items (D14)

**Tests:**
- `the delete decision branches on lessonUseCount and carries the spec's copy` (D17)

```swift
func testDeleteDecision() async throws {
    api.stub("GET /api/videos/v0", json: videoJSON(id: "v0", lessonUseCount: 0))
    api.stub("GET /api/videos/v2", json: videoJSON(id: "v2", lessonUseCount: 2))
    let zero = try await VideoActions.deleteDecision(id: "v0")
    XCTAssertEqual(zero, .delete)
    XCTAssertEqual(zero.confirmTitle, "Delete this video?")
    let two = try await VideoActions.deleteDecision(id: "v2")
    XCTAssertEqual(two, .removeFromLibrary(lessonCount: 2))
    XCTAssertEqual(two.confirmTitle, "This video is used in 2 lesson activities. It will stay in them and leave your Library.")
}
```

- `remove-from-Library drops the row from both stores and the window` (D27)

```swift
func testRemoveDropsEverywhere() async throws {
    seedLibrary(ids: ["a", "b"])
    api.stub("POST /api/videos/a/remove-from-library", json: #"{"success":true,"data":{"id":"a","libraryRemovedAt":"2026-11-22T00:00:00Z"}}"#)
    try await VideoActions.deleteOrRemove(id: "a", decision: .removeFromLibrary(lessonCount: 1))
    XCTAssertNil(AppState.shared.libraryVideos["a"]); XCTAssertNil(AppState.shared.videos["a"])
    XCTAssertEqual(AppState.shared.videoLibraryWindow.ids, ["b"])
}
```

- `nextDefaultTitle counts Video titles only` (D14)

```swift
func testNextVideoTitle() {
    XCTAssertEqual(MemoActions.nextDefaultTitle(prefix: "Video", existingTitles: ["Video 2", "Memo 9", "Video x"]), "Video 3")
    XCTAssertEqual(MemoActions.nextDefaultTitle(prefix: "Video", existingTitles: []), "Video 1")
    XCTAssertEqual(MemoActions.nextDefaultTitle(prefix: "Memo", existingTitles: ["Memo 4"]), "Memo 5")
}
```

- [ ] **Step 1: Write the listed tests** — use the API stub the existing `VideoActions`/`MemoActionsTests` use; keep the assertions
- [ ] **Step 2: Run the iphone-xctest suite for `VideoActionsLibraryTests` and `MemoActionsTests`, watch them fail**
- [ ] **Step 3: Implement the Actions and the title prefix** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): VideoActions for Library, detail and delete-or-remove`

### Task 10: The recorder timeline — length, segments, countdowns, teleprompter scroll
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/Services/Video/RecordingTimeline.swift` — pure value type: length, segments, pre-roll, end countdown, auto-stop
- Create: `iphone/MakeReady/Services/Video/TeleprompterScroller.swift` — pure scroll position from recorded time
- Create: `iphone/MakeReady/Services/Video/RecorderSettings.swift` — `UserDefaults`-backed length, countdown, teleprompter draft, speed and size
- Test: `iphone/MakeReadyCaptureTests/RecordingTimelineTests.swift`; `iphone/MakeReadyCaptureTests/TeleprompterScrollerTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Produces: `RecordingTimeline` with `lengthSeconds: Int`, `segments: [TimeInterval]`, `total: TimeInterval`, `canChangeLength: Bool`, `static func snappedLength(_ raw: Double) -> Int`, `mutating func append(_ duration:)`, `mutating func deleteLast()`, `func endCountdown(atRecorded t: TimeInterval) -> Int?`, `func shouldAutoStop(atRecorded t: TimeInterval) -> Bool`, `segmentFractions: [Double]`; `PreRoll` = `.off`, `.three`, `.ten` with `seconds` and `func beepHz(remaining: Int) -> Double`; `TeleprompterScroller(speedStep: 1…5)` with `func offset(atRecorded t: TimeInterval, lineHeight: CGFloat) -> CGFloat`; `RecorderSettings` (`length`, `preRoll`, `script`, `speedStep`, `sizeStep`)

**Behaviour:**
- `snappedLength` rounds to the nearest 10 s and clamps to 10…120 (12 stops); the default is 60; the value persists per device (D3)
- `canChangeLength` is false once `segments` is non-empty (D3)
- `endCountdown(atRecorded:)` = `Int(ceil(length − t))` when `length − 10 < t < length`, else nil — so it shows 10 at length − 10 s and 1 in the last second, measured over the total recorded time across segments (D4)
- `shouldAutoStop` is `t ≥ length` (D4)
- `PreRoll.beepHz` is 1100 for remaining > 1 and 1660 for the last (D2); the end countdown has no beep (D4)
- `deleteLast` removes the last segment only; `total` is the sum (D5)
- the teleprompter offset is a function of **recorded** time only — `pointsPerSecond[speedStep] × t` with `pointsPerSecond = [12, 18, 24, 32, 42]` — so a pause holds the line and the next segment continues from it (D7)

**Tests:**
- `the length slider snaps to 12 stops from 0:10 to 2:00` (D3)

```swift
func testLengthSnaps() {
    XCTAssertEqual(RecordingTimeline.snappedLength(0), 10)
    XCTAssertEqual(RecordingTimeline.snappedLength(64), 60)
    XCTAssertEqual(RecordingTimeline.snappedLength(66), 70)
    XCTAssertEqual(RecordingTimeline.snappedLength(500), 120)
    XCTAssertEqual(Set(stride(from: 0.0, through: 130, by: 0.5).map(RecordingTimeline.snappedLength)).count, 12)
}
```

- `the end countdown fires at length − 10 s of recorded time, across segments` (D4)

```swift
func testEndCountdownAcrossSegments() {
    var t = RecordingTimeline(lengthSeconds: 30)
    t.append(15)
    XCTAssertNil(t.endCountdown(atRecorded: t.total + 4.9))
    XCTAssertEqual(t.endCountdown(atRecorded: t.total + 5.01), 10)
    XCTAssertEqual(t.endCountdown(atRecorded: 29.5), 1)
    XCTAssertTrue(t.shouldAutoStop(atRecorded: 30))
    XCTAssertFalse(t.shouldAutoStop(atRecorded: 29.99))
}
```

- `segments append, delete last and total; length locks after the first` (D5, D3)

```swift
func testSegments() {
    var t = RecordingTimeline(lengthSeconds: 60)
    XCTAssertTrue(t.canChangeLength)
    t.append(10); t.append(5)
    XCTAssertEqual(t.total, 15); XCTAssertFalse(t.canChangeLength)
    t.deleteLast()
    XCTAssertEqual(t.segments, [10])
    XCTAssertEqual(t.segmentFractions, [10.0 / 60.0])
}
```

- `pre-roll beeps 1.1 kHz then 1.66 kHz on the last` — `.three/.ten/.off` are 3/10/0 s; `beepHz(remaining: 3) == 1100`, `beepHz(remaining: 1) == 1660` (D2)

- `the teleprompter holds across a pause and continues from the same line` (D7)

```swift
func testTeleprompterAcrossPause() {
    let s = TeleprompterScroller(speedStep: 3)
    let atPause = s.offset(atRecorded: 8, lineHeight: 30)
    XCTAssertEqual(s.offset(atRecorded: 8, lineHeight: 30), atPause)
    XCTAssertGreaterThan(s.offset(atRecorded: 8.5, lineHeight: 30), atPause)
    XCTAssertEqual(atPause, 24 * 8, accuracy: 0.001)
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `RecordingTimelineTests` and `TeleprompterScrollerTests`, watch them fail**
- [ ] **Step 3: Implement the three files** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): recording timeline, pre-roll and teleprompter scroll`

### Task 11: `VideoCaptureEngine` and `VideoDraftStore`
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoDraftStore.swift` — segment files and settings in the app container, a manifest per draft, crash salvage of finished segments
- Create: `iphone/MakeReady/Services/Video/VideoCaptureEngine.swift` — `AVCaptureSession` + `AVCaptureMovieFileOutput`, one file per segment, flip, interruption handling, free-space guard, live filter on the preview only
- Modify: `iphone/MakeReady/Info.plist:98-123` — `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` copy for video (D19)
- Test: `iphone/MakeReadyCaptureTests/VideoDraftStoreTests.swift`; `iphone/MakeReadyCaptureTests/VideoCaptureEngineTests.swift` (the non-camera logic through injected seams)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `RecordingTimeline` (Task 10)
- Produces: `VideoDraftStore` with `begin() -> VideoDraft`, `finalize(segment url: URL, duration:, in draft:)`, `recoverable() -> [VideoDraft]`, `discard(_ draft:)`; `VideoCaptureEngine` (`@Observable`) with `state` (`.idle`, `.ready`, `.recording`, `.paused`, `.denied(CapturePermission)`), `start() async throws`, `stopSegment() async`, `flip()`, `previewFilter: CIFilter?`, `onInterrupted`; `VideoCaptureError.lowDiskSpace`; `static let minimumFreeBytes: Int64 = 500_000_000`

**Behaviour:**
- read `iphone/.claude/VIDEO_RECORDING.md` and `Pages/Video/CustomVideoRecorder.swift:562-738` first (P10)
- the filter is applied to the preview layer only, never to the recording output (D6)
- a phone call, backgrounding or an `AVCaptureSession` interruption ends the current segment (finalized into the draft) and leaves the state `.paused`; it never resumes by itself (D26)
- `start()` throws `.lowDiskSpace` with less than 500 MB free (`volumeAvailableCapacityForImportantUsage`) (D26)
- `recoverable()` returns only finished segments listed in a manifest; an unfinalized file is deleted (D26)
- camera and microphone are requested in context on first `start()`; a denial sets `.denied` (D19); no speech permission is asked (D19)

**Pattern:**
- `iphone/MakeReady/Services/Audio/MemoDraftStore.swift:14-160` — the manifest and salvage
- `iphone/MakeReady/Services/Audio/MemoRecorderEngine.swift:297-322` — interruption handling

**Tests:**
- `salvage keeps finished segments and drops an unfinished file` (D26)

```swift
func testSalvageKeepsOnlyFinishedSegments() throws {
    let store = VideoDraftStore(root: dir)
    let draft = store.begin()
    let done = dir.appendingPathComponent("s1.mov"); try Data([1]).write(to: done)
    try store.finalize(segment: done, duration: 4, in: draft)
    try Data([2]).write(to: draft.folder.appendingPathComponent("s2.mov"))
    let recovered = VideoDraftStore(root: dir).recoverable()
    XCTAssertEqual(recovered.first?.segments.map(\.duration), [4])
    XCTAssertFalse(FileManager.default.fileExists(atPath: draft.folder.appendingPathComponent("s2.mov").path))
}
```

- `an interruption ends the segment and pauses, never resuming` (D26)

```swift
func testInterruptionPauses() async throws {
    let engine = VideoCaptureEngine(session: FakeCaptureSession(), drafts: store, freeBytes: { 1_000_000_000 })
    try await engine.start()
    engine.handleInterruption(began: true)
    XCTAssertEqual(engine.state, .paused)
    engine.handleInterruption(began: false)
    XCTAssertEqual(engine.state, .paused)
}
```

- `under 500 MB free, recording refuses to start` — with `freeBytes` 499 999 999, `start()` throws `VideoCaptureError.lowDiskSpace` (D26)

- [ ] **Step 1: Read P10's two files; write the listed tests** — the engine takes the session, drafts and free-space reader as seams
- [ ] **Step 2: Run the iphone-xctest suite for `VideoDraftStoreTests` and `VideoCaptureEngineTests`, watch them fail**
- [ ] **Step 3: Implement the store, the engine and the `Info.plist` copy** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): video capture engine and crash-safe draft store`

### Task 12: `VideoExporter` and `VideoTranscriber`
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoExporter.swift` — concatenate segments (or a trimmed import), apply the filter through `AVVideoComposition` with a Core Image handler, orientation, one `.mp4`
- Create: `iphone/MakeReady/Services/Video/VideoFilters.swift` — the 8 filters (Normal + 7 Core Image looks, named as d2m named them in `d2m-api.md`) and `strength` blending
- Create: `iphone/MakeReady/Services/Video/VideoTranscriber.swift` — `.m4a` passthrough extract, then `MemoTranscriber.transcribeFile`, bounded by a timeout
- Test: `iphone/MakeReadyCaptureTests/VideoExporterTests.swift`; `iphone/MakeReadyCaptureTests/VideoTranscriberTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoDraft` (Task 11)
- Produces: `VideoExporter.export(segments: [URL], timeRange: CMTimeRange?, filter: VideoFilter, strength: Double, to: URL) async throws -> ExportedVideo` (`url`, `durationSeconds`, `posterImage`); `VideoFilter` (8 cases, `.normal` first); `VideoTranscriber.transcribe(video: URL, timeout: Duration) async -> VideoTranscript?` (`text`, `segments: [VideoTranscriptSegment]` in ms from the start of the file)

**Behaviour:**
- segments are concatenated in order, 1080×1920 portrait (smaller if the source is), AAC audio, H.264/HEVC as the `AVAssetExportSession` presets allow; orientation through each track's `preferredTransform` (D13, P10)
- `.normal` exports with no video composition; any other filter is drawn into the pixels at export (D6, P5)
- the transcriber extracts an `.m4a` through `MemoAudioExporter`'s passthrough export before `transcribeFile`, uses the device locale, and returns nil on an unsupported locale, a missing model or a failure (D10)
- `transcribe` returns nil when `timeout` (the export's own duration, set by the caller) elapses first — transcription never blocks Save (D10)
- F3 (build-time risk): the live filter and the export composition are proven only on a device — a 2-segment recording with a non-Normal filter exported filtered, portrait and in order. The simulator has no camera, so the report names this as owed to the human walk

**Tests:**
- `two segments concatenate in order into one portrait mp4 with summed duration` (D13)

```swift
func testConcatenatesInOrder() async throws {
    let a = try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 1080, height: 1920))
    let b = try await TestMovie.make(seconds: 2, colour: .blue, size: CGSize(width: 1080, height: 1920))
    let out = try await VideoExporter.export(segments: [a, b], timeRange: nil, filter: .normal, strength: 1, to: tmp("out.mp4"))
    XCTAssertEqual(out.durationSeconds, 3, accuracy: 0.2)
    XCTAssertEqual(try await TestMovie.dominantColour(of: out.url, at: 0.5), .red)
    XCTAssertEqual(try await TestMovie.dominantColour(of: out.url, at: 2.0), .blue)
    XCTAssertEqual(try await TestMovie.naturalPortraitSize(of: out.url), CGSize(width: 1080, height: 1920))
}
```

- `a trim window exports only that window` (D8)

```swift
func testTrimWindow() async throws {
    let clip = try await TestMovie.make(seconds: 5, colour: .green, size: CGSize(width: 720, height: 1280))
    let range = CMTimeRange(start: .init(seconds: 1, preferredTimescale: 600), duration: .init(seconds: 2, preferredTimescale: 600))
    let out = try await VideoExporter.export(segments: [clip], timeRange: range, filter: .normal, strength: 1, to: tmp("trim.mp4"))
    XCTAssertEqual(out.durationSeconds, 2, accuracy: 0.2)
}
```

- `there are 8 filters, Normal first` — `VideoFilter.allCases.count == 8`, `.first == .normal` (D6)

- `the transcriber returns nil when the timeout passes first` (D10)

```swift
func testTranscriberTimesOut() async throws {
    let t = VideoTranscriber(core: SlowTranscriber(delay: .seconds(5)))
    let result = await t.transcribe(video: try await TestMovie.make(seconds: 1, colour: .red, size: CGSize(width: 720, height: 1280)), timeout: .milliseconds(200))
    XCTAssertNil(result)
}
```

- [ ] **Step 1: Write the listed tests** — `TestMovie` writes synthetic clips with `AVAssetWriter` (simulator-safe, no camera)
- [ ] **Step 2: Run the iphone-xctest suite for `VideoExporterTests` and `VideoTranscriberTests`, watch them fail**
- [ ] **Step 3: Implement the exporter, the filters and the transcriber** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): video exporter, filters and on-device transcriber`

### Task 13: `VideoUploadController` — queue, attach jobs, refresh poll
App: iphone
Phase: 4
Recipe: ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoUploadController.swift` — the persisted queue, the state machine, backoff, flush triggers, attach jobs and the ready poll
- Create: `iphone/MakeReady/Services/Video/VideoStreamTransport.swift` — ephemeral `URLSession` multipart upload **streamed from the file** inside `beginBackgroundTask`
- Modify: `iphone/MakeReady/State/AppState.swift:846` — `launchVideoUploads(userId:)` beside `launchMemoUploads`; queued items exposed for the Library merge
- Test: `iphone/MakeReadyCaptureTests/VideoUploadControllerTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoActions.getUploadUrl`, `createVideoRecord`, `refreshVideoStatus` (existing); `POST /api/videos` with `transcript`, `transcriptSegments`, `source` (frozen §Contract); `ActivityActions.create` and `ActivityActions.save(document:)` (`ActivityActions.swift:80,92`); `ExportedVideo`, `VideoTranscript` (Task 12)
- Produces: `VideoQueueItem` (`localId`, `title`, `fileURL`, `durationSeconds`, `source`, `transcript?`, `streamUid?`, `serverId?`, `stage`, `failures`, `attach: VideoAttach?`); `VideoAttach` (`versionId`, `activityId?`, `title`); `VideoUploadStage` = `.queued`, `.uploading`, `.creating`, `.processing`, `.attaching`, `.done`; `VideoUploadController.enqueue(_:attach:) throws -> VideoQueueItem`, `processNext() async -> VideoUploadStep`, `pending() -> [VideoQueueItem]`, `flush() async`

**Behaviour:**
- the manifest is written before any network call; flush on enqueue, on launch and on reconnect (`NWPathMonitor`) (D12)
- the upload streams from the file and never loads it into `Data` (D12, F8)
- the Stream `uid` is persisted before the upload; a retry whose upload URL is spent mints a fresh URL and uid (D12, F14)
- backoff 5 s · 30 s · 2 min · 10 min, never giving up; after 3 consecutive failures of one item, surface the error banner with Retry (`surface: true`) once, and keep backing off (D12)
- the create sends `source`, and `transcript` + `transcriptSegments` when the transcriber returned one; a 200 duplicate on retry is a success that stores the returned `Video.id` (D10, D22)
- after create: poll `refreshVideoStatus` as `waitForVideoReady` does (15 × 2 s); the item is `processing` until `status: ready` (D23)
- with `attach`: once `serverId` is known, create the video activity (`content.videoId = serverId`, no duration — F11 as ruled in Task 5) or save the replaced document; a refusal (version published or deleted) leaves the video in the Library and surfaces the error banner (D18)
- the queue and attach jobs survive a relaunch: a reloaded item resumes from its persisted stage (D18)

**Pattern:**
- `iphone/MakeReady/Services/Audio/MemoUploadController.swift:28-49,86-116,364-490` — manifest, backoff, `processNext`
- `iphone/MakeReady/Services/Audio/MemoPutTransport.swift:17-42` — ephemeral session + `beginBackgroundTask`

**Tests:**
- `an item moves queued → uploading → creating → processing → done` (D12, D23)

```swift
func testHappyPath() async throws {
    let c = makeController(api: FakeVideoAPI(readyAfterPolls: 1))
    _ = try c.enqueue(exported(), attach: nil)
    var stages: [VideoUploadStage] = []
    for _ in 0..<10 { if await c.processNext() == .idle { break }; stages.append(c.pending().first?.stage ?? .done) }
    XCTAssertEqual(stages.removingDuplicates(), [.uploading, .creating, .processing, .done])
}
```

- `a lost create response retried gets 200 with the same id` (D22)

```swift
func testRetryAfterLostCreate() async throws {
    let api = FakeVideoAPI(dropFirstCreateResponse: true)
    let c = makeController(api: api)
    let item = try c.enqueue(exported(), attach: nil)
    await drain(c)
    XCTAssertEqual(api.createCalls, 2)
    XCTAssertEqual(c.serverId(forLocalId: item.localId), api.createdId)
}
```

- `the banner shows once after 3 consecutive failures and backoff continues` (D12)

```swift
func testBannerAfterThreeFailures() async throws {
    let banner = BannerSpy()
    let c = makeController(api: FakeVideoAPI(failUploads: 4), banner: banner)
    _ = try c.enqueue(exported(), attach: nil)
    for _ in 0..<3 { _ = await c.processNext() }
    XCTAssertEqual(banner.shown.count, 1)
    XCTAssertEqual(banner.shown.first?.hasRetry, true)
    XCTAssertEqual(VideoUploadController.delay(forAttempt: 4), .seconds(600))
    XCTAssertEqual(VideoUploadController.delay(forAttempt: 9), .seconds(600))
}
```

- `an attach job survives a relaunch and creates the activity with the new video id` (D18)

```swift
func testAttachSurvivesRelaunch() async throws {
    let api = FakeVideoAPI()
    let first = makeController(api: api, root: dir)
    _ = try first.enqueue(exported(), attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 1"))
    _ = await first.processNext()
    let second = makeController(api: api, root: dir)
    await drain(second)
    XCTAssertEqual(api.activityCreates.first?.versionId, "ver1")
    XCTAssertEqual(api.activityCreates.first?.videoId, api.createdId)
}
```

- `a refused attach keeps the video and surfaces the error` — with the activity create answering 409, after draining the banner shows once and the queue is empty (D18)

- [ ] **Step 1: Read `/ios-error-surface`; write the listed tests** — the controller takes the API, the transport, the banner and the root folder as seams
- [ ] **Step 2: Run the iphone-xctest suite for `VideoUploadControllerTests`, watch them fail**
- [ ] **Step 3: Implement the controller, the streaming transport and `launchVideoUploads`** to the Behaviour
- [ ] **Step 4: Run them plus `MemoUploadControllerTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): video upload queue with attach jobs and ready poll`

### Task 14: Library video rows, Type filter, paging hold-back and delete
App: iphone
Phase: 5
Recipe: nav-route

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeMapper.swift:14-120` — `VideoSource`, `visibleVideos`, three-kind interleave with the hold-back, the video row's lines
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift:21-110,160-180` — the Type option, paging near the end, swipe delete through `deleteDecision`, server-side search for videos
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeSearch.swift` — video search through `loadLibrary(q:)`
- Test: extend `iphone/MakeReadyCaptureTests/LibraryHomeMapperTests.swift` and `LibraryHomeSearchTests.swift`

**Interfaces:**
- Consumes: d2m's video row and `LibraryItemType.video` (`d2m-api.md`); `AppState.libraryVideos`, `videoLibraryWindow` (Task 8); `VideoActions.loadLibrary`, `deleteDecision`, `deleteOrRemove` (Task 9); `VideoUploadController.pending()` (Task 13); (tapping a video row is wired by the Video detail task)
- Produces: `LibraryHomeMapper.visibleVideos(stored:queued:)`, `LibraryHomeMapper.rows(notes:searchIds:memos:videos:videosHaveMore:)`, `LibraryHomeMapper.videoLine2(_:)`

**Behaviour:**
- rows interleave notes, memos and videos newest first by `createdAt` (D15)
- while `hasMore`, notes and memos older than the oldest loaded video are held back (D20)
- a queued item shows as `local:<localId>` and is dropped once its `serverId` is in `libraryVideos` (D27)
- line 1 is `h:mm a · m:ss` (the memo rule); line 2 by state, in this order (D15):
  - queued, not yet created → "Uploading…"
  - `status: pending` → "Processing…"
  - `transcriptStatus: pending` → "Transcribing…"
  - `ready` with a preview → the preview's first line
  - otherwise → empty
- Type: nothing or all three checked = all kinds; **Videos** shows video rows only (D15)
- swipe uses `removesRow: false`: the row stays until `deleteOrRemove` succeeds and springs back on cancel; the C-066 confirm title is `VideoDeleteDecision.confirmTitle`; a failed `GET` shows the error banner and leaves the row (D17, `/ios-error-surface`)
- the list fetches the next page as it nears its end (D20)

**Tests:**
- `video line 2 for every state` (D15)

```swift
func testVideoLine2() {
    XCTAssertEqual(LibraryHomeMapper.videoLine2(.queued), "Uploading…")
    XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(summary(status: "pending", transcriptStatus: "pending"))), "Processing…")
    XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(summary(status: "ready", transcriptStatus: "pending"))), "Transcribing…")
    XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(summary(status: "ready", transcriptStatus: "ready", preview: "Hello there\nsecond"))), "Hello there")
    XCTAssertEqual(LibraryHomeMapper.videoLine2(.stored(summary(status: "ready", transcriptStatus: "failed"))), "")
}
```

- `older notes are held back while videos have more` (D20)

```swift
func testHoldBack() {
    let rows = LibraryHomeMapper.rows(notes: [note(daysAgo: 1), note(daysAgo: 9)], searchIds: nil, memos: [], videos: [video(daysAgo: 0), video(daysAgo: 5)], videosHaveMore: true)
    XCTAssertEqual(rows.ids.count, 3)
    XCTAssertFalse(rows.ids.contains(note(daysAgo: 9).id))
    let all = LibraryHomeMapper.rows(notes: [note(daysAgo: 1), note(daysAgo: 9)], searchIds: nil, memos: [], videos: [video(daysAgo: 0), video(daysAgo: 5)], videosHaveMore: false)
    XCTAssertEqual(all.ids.count, 4)
}
```

- `a queued video drops once its server id is in the store` (D27)

```swift
func testLocalRowMerge() {
    let q = queued(localId: "L1", serverId: "v9")
    XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [], queued: [q]).map(\.id), ["local:L1"])
    XCTAssertEqual(LibraryHomeMapper.visibleVideos(stored: [summary(id: "v9")], queued: [q]).map(\.id), ["v9"])
}
```

- `the Videos type shows only videos; none or all checked shows every kind` (D15)

```swift
func testTypeFilter() {
    XCTAssertEqual(LibraryHomeMapper.kinds(checked: [.video]), [.video])
    XCTAssertEqual(LibraryHomeMapper.kinds(checked: []), [.note, .memo, .video])
    XCTAssertEqual(LibraryHomeMapper.kinds(checked: [.note, .memo, .video]), [.note, .memo, .video])
}
```

- [ ] **Step 1: Read `/nav-route`, `d2m-api.md`; write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `LibraryHomeMapperTests` and `LibraryHomeSearchTests`, watch them fail**
- [ ] **Step 3: Implement the mapper and container changes** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**; `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(video-recorder): Library video rows, Type filter and delete-or-remove`

### Task 15: Video detail
App: iphone
Phase: 5
Recipe: push-page

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoDetailContainer.swift` — hosts d2m's `VideoDetailScreen`, loads detail, rename, delete
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoDetailModel.swift` — the screen state from `Video`, rename and delete flow
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift` — register `VideoDetailDestination(id:)` and push it on a video row tap (D15)
- Test: `iphone/MakeReadyCaptureTests/VideoDetailModelTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoDetailScreen` (`d2m-api.md`); `VideoActions.loadDetail`, `rename`, `deleteDecision`, `deleteOrRemove` (Task 9)
- Produces: `VideoDetailDestination(id: String)`; `VideoDetailModel(id:)` with `state`, `rename(to:)`, `requestDelete()`

**Behaviour:**
- the screen shows the HLS `playbackUrl` with `thumbnailUrl` as poster, the title (tap to rename), date · duration and the transcript or its state ("Transcribing…" / "Processing…" / none) (D16)
- rename trims; an empty title is not sent (D14)
- Delete in the overflow runs the D17 branch and pops back to the Library on success (D17)
- tapping a stored video row in the Library pushes `VideoDetailDestination(id:)`; a queued (`local:`) row does not open (D15, D16)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Memo/MemoDetailModel.swift` and `MemoDetailContainer.swift`

**Tests:**
- `the detail state shows the transcript or its state` (D16)

```swift
func testTranscriptState() {
    XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "ready", transcript: "Hi")), "Hi")
    XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "pending", status: "ready")), "Transcribing…")
    XCTAssertEqual(VideoDetailModel.transcriptText(video(transcriptStatus: "pending", status: "pending")), "Processing…")
}
```

- `an empty rename is not sent` — `rename(to: "   ")` sends no PATCH (D14)

- [ ] **Step 1: Read `/push-page`; write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `VideoDetailModelTests`, watch them fail**
- [ ] **Step 3: Implement the model, the container and the destination**
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(video-recorder): Video detail screen`

### Task 16: The recorder model and the full-screen recorder from +
App: iphone
Phase: 5
Recipe: present-overlay

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift` — one model for both layouts: timeline, engine, settings, rail tools, sheets, the record button state machine
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift` — the full-screen host of d2m's `VideoRecorderScreen(layout: .fullScreen)`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:97-108,121-124` — "Record a video" presents the recorder as `.hostedOverlay(UI2HostedOverlay(…))`
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderModelTests.swift`; extend `UI2ShellModelTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoRecorderScreen` and its `State` (`d2m-api.md`); `RecordingTimeline`, `PreRoll`, `TeleprompterScroller`, `RecorderSettings` (Task 10); `VideoCaptureEngine`, `VideoDraftStore` (Task 11); the notes store for **Use a note**
- Produces: `VideoRecorderModel` with `screenState`, `recordTapped()`, `deleteLastConfirmed()`, `tick(recorded:)`, `rail(_ tool:)`, `done()`; `VideoRecorderEntry` = `.plusMenu` | `.lesson(versionId:activityId:)`

**Behaviour:**
- the rail is exactly Flip, Countdown, Length, Filters, Teleprompter (D1)
- record with pre-roll on → `.preRoll(n)` counting down once per second with beeps, then recording; a tap during pre-roll cancels it (D2)
- each tap toggles segment record/stop; Delete last is visible only with ≥ 1 segment and nothing recording, behind the C-066 confirm "Delete the last clip?"; the checkmark is enabled once there is ≥ 1 segment (D5)
- `tick` shows the end countdown and auto-stops into Review at the length (D4)
- the Length sheet is disabled once a segment exists (D3)
- Filters strip: 8 filters, strength 0–100 that resets to 100 on each new pick (D6)
- Teleprompter panel: typed or pasted script, or **Use a note** (the note's body), persisted as a draft; the band scrolls only while recording (D7)
- every sheet and confirm goes through the typed `Route` system (`/present-overlay`); 🔴 no `.sheet`, no `.fullScreenCover` (D25, Global constraints)
- a denied permission shows C-132 with **Open Settings** (D19); low disk shows the error banner "Not enough free space to record" (D26)
- closing with segments asks the C-066 confirm "Discard this recording?" then discards the draft (D9)

**Tests:**
- `a tap during pre-roll cancels it` (D2)

```swift
func testPreRollCancel() {
    let m = makeModel(preRoll: .three)
    m.recordTapped()
    XCTAssertEqual(m.screenState.phase, .preRoll(3))
    m.recordTapped()
    XCTAssertEqual(m.screenState.phase, .ready)
    XCTAssertFalse(engine.didStart)
}
```

- `the end countdown and auto-stop open Review` (D4)

```swift
func testAutoStopOpensReview() async {
    let m = makeModel(length: 30, preRoll: .off)
    m.recordTapped()
    m.tick(recorded: 21)
    XCTAssertEqual(m.screenState.phase, .endCountdown(9))
    m.tick(recorded: 30)
    XCTAssertEqual(m.screenState.phase, .review)
}
```

- `delete-last shows only with a segment and nothing recording` (D5)

```swift
func testDeleteLastVisibility() {
    let m = makeModel(length: 60, preRoll: .off)
    XCTAssertFalse(m.screenState.showsDeleteLast)
    m.recordTapped(); m.tick(recorded: 3)
    XCTAssertFalse(m.screenState.showsDeleteLast)
    m.recordTapped()
    XCTAssertTrue(m.screenState.showsDeleteLast)
}
```

- `the rail order is fixed` — `VideoRecorderModel.railTools == [.flip, .countdown, .length, .filters, .teleprompter]` (D1)

- `a new filter pick resets strength to 100` (D6)

```swift
func testFilterStrengthReset() {
    let m = makeModel(length: 60, preRoll: .off)
    m.setFilterStrength(40)
    m.pickFilter(.allCases[2])
    XCTAssertEqual(m.screenState.filterStrength, 100)
}
```

- `+ → Record a video presents the hosted overlay` (D25)

```swift
func testPlusMenuRecordsVideo() {
    let shell = UI2ShellModel()
    shell.onSelect(.recordVideo)
    XCTAssertEqual(shell.hostedOverlay?.id, "video-recorder")
}
```

- [ ] **Step 1: Read `/present-overlay`, `d2m-api.md` and P10's two files; write the listed tests** — adapt the shell call to `UI2ShellModel`'s real menu API (`UI2Shell.swift:30-39,97-108`), keeping the assertion
- [ ] **Step 2: Run the iphone-xctest suite for `VideoRecorderModelTests` and `UI2ShellModelTests`, watch them fail**
- [ ] **Step 3: Implement the model, the container and the shell entry** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**; run `/transition-review` on the diff
- [ ] **Step 5: Commit** — `feat(video-recorder): full-screen video recorder from the + menu`

### Task 17: Review, import, trim and Save
App: iphone
Phase: 5
Recipe: present-overlay

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift` — Review (loop playback, Filters, Retake, Save), import, trim, the Save hand-off
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoImportFlow.swift` — the PhotosPicker result to a file URL and duration
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift`

**Interfaces:**
- Consumes: `VideoExporter`, `VideoTranscriber` (Task 12); `VideoUploadController.enqueue(_:attach:)` (Task 13); `AppState.nextVideoTitle()` (Task 9); `PickedMovie` (`MediaHomeContainer.swift:469`)
- Produces: `VideoRecorderModel.save() async`, `retakeConfirmed()`, `imported(url:duration:)`, `trimmed(range:)`; `VideoRecorderModel.onFinished: (VideoRecorderEntry) -> Void`

**Behaviour:**
- the gallery button shows only before the first segment; a clip of ≤ 2:00 goes straight to Review, a longer one to the trim step whose window is ≤ 2:00 (D8)
- Retake asks the C-066 confirm, discards everything and returns to the camera (D9)
- Save exports, starts the transcriber with `timeout` = the export's duration, enqueues with title `nextVideoTitle()` and `source` (`recording` or `import`), and closes at once: + menu → the Library; lesson → back to Edit lesson (D9, D10, D14)
- the enqueue happens without waiting for the network (§Idea "Nothing waits on the network")

**Tests:**
- `a clip over 2:00 opens trim; one at or under goes to Review` (D8)

```swift
func testImportRouting() {
    let m = makeModel()
    m.imported(url: tmpURL, duration: 120); XCTAssertEqual(m.screenState.phase, .review)
    let n = makeModel()
    n.imported(url: tmpURL, duration: 180); XCTAssertEqual(n.screenState.phase, .trim)
    n.trimmed(range: 30...150); XCTAssertEqual(n.screenState.phase, .review)
}
```

- `Save enqueues Video n with source and closes to the Library without waiting` (D9, D14)

```swift
func testSaveFromPlus() async {
    let queue = QueueSpy(); var finished: VideoRecorderEntry?
    let m = makeModel(entry: .plusMenu, queue: queue, existingTitles: ["Video 1"])
    m.onFinished = { finished = $0 }
    m.recordTapped(); m.tick(recorded: 4); m.recordTapped()
    await m.save()
    XCTAssertEqual(queue.items.first?.title, "Video 2")
    XCTAssertEqual(queue.items.first?.source, "recording")
    XCTAssertNil(queue.items.first?.attach)
    XCTAssertEqual(finished, .plusMenu)
}
```

- `Retake after confirm returns to the camera with no segments` — after a segment and `done()`, `retakeConfirmed()` leaves `phase == .ready` and `segments` empty (D9)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `VideoRecorderSaveTests`, watch them fail**
- [ ] **Step 3: Implement Review, import, trim and Save** to the Behaviour
- [ ] **Step 4: Run them, watch them pass**; `/transition-review` on the diff
- [ ] **Step 5: Commit** — `feat(video-recorder): review, import, trim and save`

### Task 18: The lesson video activity — tile, inline recorder, Replace video
App: iphone
Phase: 5
Recipe: present-overlay

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:26` — remove `"video"` from `unavailableTypes`; choosing Video opens the inline recorder
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:178-195,905-924` — host `VideoRecorderScreen(layout: .lessonInline)` in the video canvas; the local pending video activity; **Replace video** in a video activity's menu
- Test: extend `iphone/MakeReadyCaptureTests/ActivityNewContainerTests.swift` and `ActivitiesEditorContainerTests.swift`

**Interfaces:**
- Consumes: `VideoRecorderModel` with `VideoRecorderEntry.lesson(versionId:activityId:)` (Task 16); `VideoAttach` and `VideoUploadController.pending()` (Task 13); d2m's editor changes (`d2m-api.md`)
- Produces: `ActivitiesEditorMapper.pendingVideoActivities(queued:versionId:)`

**Behaviour:**
- the Video tile is enabled (D18)
- Save from a lesson enqueues with `attach: {versionId, activityId: nil, title}` for a new activity, or `{versionId, activityId, title}` for **Replace video**, and returns to Edit lesson (D18, D9)
- until the attach job finishes, the editor lists a pending video activity with the poster frame and "Uploading…" for each queued item whose `attach.versionId` is this version and `activityId` is nil (D18)
- the activity is created by the upload controller, never by the editor (D18)
- the C-040 header and activity strip hide while recording and show otherwise (P3)

**Tests:**
- `the Video tile is enabled` — `ActivityNewContainer.unavailableTypes` no longer contains `"video"` (D18)

- `a queued attach for this version shows as a pending activity` (D18)

```swift
func testPendingVideoActivity() {
    let q = [queued(localId: "L1", attach: VideoAttach(versionId: "ver1", activityId: nil, title: "Video 3")),
             queued(localId: "L2", attach: VideoAttach(versionId: "other", activityId: nil, title: "Video 4"))]
    let rows = ActivitiesEditorMapper.pendingVideoActivities(queued: q, versionId: "ver1")
    XCTAssertEqual(rows.map(\.id), ["local:L1"])
    XCTAssertEqual(rows.first?.statusText, "Uploading…")
}
```

- `Replace video carries the activity id on the attach` (D18)

```swift
func testReplaceVideoAttach() async {
    let queue = QueueSpy()
    let m = makeRecorderModel(entry: .lesson(versionId: "ver1", activityId: "act9"), queue: queue)
    m.recordTapped(); m.tick(recorded: 3); m.recordTapped()
    await m.save()
    XCTAssertEqual(queue.items.first?.attach, VideoAttach(versionId: "ver1", activityId: "act9", title: "Video 1"))
}
```

- [ ] **Step 1: Read `/present-overlay`, `d2m-api.md`; write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `ActivityNewContainerTests` and `ActivitiesEditorContainerTests`, watch them fail**
- [ ] **Step 3: Implement the tile, the inline host, the pending row and Replace video** to the Behaviour
- [ ] **Step 4: Run them plus the whole iphone-xctest suite, watch them pass**; `swiftlint` from `iphone/`; `/transition-review` on the diff
- [ ] **Step 5: Commit** — `feat(video-recorder): record a lesson video activity inline`
