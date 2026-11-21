# memo-screens — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire d2m's voice-memo views (recorder sheet, Library memo rows, memo-detail, SavedToast) to the memo engine on `feature/memo`, with the server fixture layers the walk needs.

**Architecture:** The server changes data only: two fixture layers give `library-home` five memos and `memo-detail` one playable memo. On the iPhone, phase 2 adds the testable state and services under the views (`discard()`, queue rename/remove, paging, `MemoPlayer`, the Library and memo-detail mappers). Phase 3 wires them into containers and the shell. No endpoint, schema or contract changes (`contract: none`), so there is no freeze.

**Tech Stack:** server — TypeScript fixture layers (Prisma, R2 via `src/services/storage.ts`, vitest); iphone — Swift 5 / SwiftUI, `@Observable` + Actions, AVFoundation, XCTest (`MakeReadyCaptureTests`).

**Spec:** `docs/features/memo-screens/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(memo-screens): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–2 | `fixtures:reset full` gives the Fixtures leader 5 memos, one per Library preview state, and one playable memo with 3 transcript segments and its audio in the bucket. No endpoint or schema change, so `contract: none` and no freeze |
| 2 | iphone | 3–8 | The state and services under the views: `discard()`, queued-memo rename/remove/file access, full-list paging, `MemoPlayer`, and the pure Library and memo-detail mappers, each with its XCTest |
| 3 | iphone | 9–12 | The screens are live: memo-detail pushed from Library and the toast, Library lists notes and memos and searches both, + → Voice memo records in the sheet and saves with the toast |

---

### Task 1: library-home memo rows
App: server
Phase: 1
Recipe: test-driven-development

**Files:**
- Modify: `server/fixtures/ids.ts:52` — add `voiceMemo: '0026'` to `FIXTURE_KIND`, with the comment `// memo-screens D19: the library-home and memo-detail screens' voice memos.`
- Modify: `server/fixtures/screens/library-home.ts` — add `libraryHomeMemos` and create its rows in `full`; update the header comment to name the memos
- Test: `server/fixtures/__tests__/library-home.test.ts` — the memo rows

**Interfaces:**
- Produces: `libraryHomeMemos` — takes `now: Date` and `daysAgo: (n: number) => Date` and returns the 5 `voiceMemo` create inputs in the order below. `full(ctx)` also calls `ctx.prisma.voiceMemo.createMany` with them.
- Consumes: `memoKey(userId, memoId)` from `src/services/memos.service.ts:74`, `TRANSCRIPT_MAX_ATTEMPTS` from `src/services/transcription.service.ts:8`, `fixtureId('voiceMemo', n)`, `FIXTURE_USER_ID`

**Behaviour:**
- The 5 rows, ids `fixtureId('voiceMemo', 1…5)`. All have `userId: FIXTURE_USER_ID`, `key: memoKey(FIXTURE_USER_ID, id)`, `uploadStatus: 'ready'`, `isActive: true`, and `createdAt` = `updatedAt` = `recordedAt` (D19):

| n | recordedAt | title | durationMs | transcriptStatus | transcriptAttempts | transcript |
|---|---|---|---|---|---|---|
| 1 | `now − 3_600_000 ms` | `Sermon follow-up` | 12_000 | `ready` | 1 | `Grace is a gift, not a wage. Sunday we start Romans eight with the whole group. Ask Sarah to lead the prayer time.` |
| 2 | `daysAgo(1)` | `Prayer requests` | 95_000 | `pending` | `TRANSCRIPT_MAX_ATTEMPTS` | null |
| 3 | `daysAgo(4)` | `Leader huddle notes` | 184_000 | `failed` | `TRANSCRIPT_MAX_ATTEMPTS` | null |
| 4 | `daysAgo(15)` | `Memo 4` | 31_000 | `none` | 0 | null |
| 5 | `daysAgo(45)` | `Retreat ideas` | 3_725_000 | `ready` | 1 | `Book the lodge early and ask the worship team about Saturday night.` |

- `transcriptSource` is `'server'` on the two `ready` rows and null elsewhere; `fileSize` is null (memo-detail sets row 1's) (D19)
- `pending`/`failed` carry `TRANSCRIPT_MAX_ATTEMPTS` so `memoIdsDueForTranscriptRetry` (`memos.service.ts:256-268`) never claims them (A5)
- Dates come only from `now`/`daysAgo`; no `ctx.rand`, no org, user or group created (house rule fixtures)

**Tests:**
- `the 5 memos cover each D5 preview state at the D19 ages` — statuses, ages and attempts as the table says

```ts
it('the 5 memos cover each D5 preview state at the D19 ages', () => {
  const NOW = new Date('2026-11-20T17:00:00.000Z')
  const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
  const memos = libraryHomeMemos(NOW, daysAgo)
  expect(memos.map((m) => m.id)).toEqual([1, 2, 3, 4, 5].map((n) => fixtureId('voiceMemo', n)))
  expect(memos.map((m) => m.transcriptStatus)).toEqual(['ready', 'pending', 'failed', 'none', 'ready'])
  expect(memos.map((m) => (NOW.getTime() - m.recordedAt.getTime()) / 3_600_000)).toEqual([1, 24, 96, 360, 1080])
  expect(memos[1].transcriptAttempts).toBe(TRANSCRIPT_MAX_ATTEMPTS)
  expect(memos[2].transcriptAttempts).toBe(TRANSCRIPT_MAX_ATTEMPTS)
  expect(memos.every((m) => m.userId === FIXTURE_USER_ID && m.key === memoKey(FIXTURE_USER_ID, m.id) && m.uploadStatus === 'ready')).toBe(true)
})
```

- [ ] **Step 1: Write the listed test** in `server/fixtures/__tests__/library-home.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/library-home.test.ts`, watch it fail** — `libraryHomeMemos` is not exported
- [ ] **Step 3: Add the `voiceMemo` prefix and `libraryHomeMemos`, and call it in `full`**, following the Behaviour
- [ ] **Step 4: Run the same command, watch it pass** — then `npx tsc -p fixtures/tsconfig.json --noEmit` in `server/`
- [ ] **Step 5: Commit** — `feat(memo-screens): library-home fixture voice memos`

### Task 2: memo-detail fixture layer with its audio
App: server
Phase: 1
Recipe: test-driven-development

**Files:**
- Create: `server/fixtures/audio/memo-detail.m4a` — a short committed AAC file. Generate it once: `say -o /tmp/memo-detail.aiff "Grace is a gift, not a wage. Sunday we start Romans eight with the whole group. Ask Sarah to lead the prayer time."` then `afconvert -f m4af -d aac -b 32000 /tmp/memo-detail.aiff server/fixtures/audio/memo-detail.m4a`. Keep it under 100 KB, check its length with `afinfo`, and adjust the segment starts below only if a sentence starts more than 1 s away from them
- Create: `server/fixtures/screens/memo-detail.ts` — the layer
- Modify: `server/fixtures/README.md` — list `memo-detail` among the layers (one line, like its neighbours), and add memos to the `library-home` line
- Modify: `server/fixtures/__tests__/home-dashboard.test.ts:124` — the expected screen list gains `'memo-detail'` after `'members-profile'` (the runner loads `screens/*.ts` in filename order)
- Test: `server/fixtures/__tests__/memo-detail.test.ts` — segments and upload-once
- Test: `server/fixtures/__tests__/memo-detail.db.test.ts` — reset against a throwaway DB

**Interfaces:**
- Produces: `MEMO_DETAIL_SEGMENTS` — the 3 segments `{ text, startMs, endMs }`. `placeMemoAudio` takes `key: string`, `bytes: Buffer` and `deps: { objectExists, uploadToR2 }` (defaults to `storage.ts`'s own) and returns whether it uploaded. `full(ctx)` updates memo 1 and places its audio.
- Consumes: `fixtureId('voiceMemo', 1)` and the row Task 1's `libraryHomeMemos` creates, `memoKey`, `r2Unconfigured` and `assertFixtureBucket` from `fixtures/images.ts`

**Behaviour:**
- `full` updates `fixtureId('voiceMemo', 1)` with `transcriptSegments: MEMO_DETAIL_SEGMENTS`, `fileSize` = the file's byte length and `durationMs` = the last segment's `endMs` (D19)
- Segments: `{ text: 'Grace is a gift, not a wage.', startMs: 0, endMs: 4000 }`, `{ text: 'Sunday we start Romans eight with the whole group.', startMs: 4000, endMs: 8000 }` and `{ text: 'Ask Sarah to lead the prayer time.', startMs: 8000, endMs: 12000 }`. Their texts joined with a space equal memo 1's `transcript` from Task 1 (D19)
- The upload uses the key a real upload uses (`memoKey(FIXTURE_USER_ID, id)`), content type `audio/mp4`, and is skipped when `objectExists(key)` is true (D19, the `images.ts:224` pattern)
- The same switches as `seedImages` (`images.ts:236-243`): skipped under `FIXTURE_IMAGES=off`, under `VITEST` unless `FIXTURE_IMAGES=on`, and when `r2Unconfigured()` (with a one-line warning); otherwise `assertFixtureBucket()` first, so production is never written (D19)
- The memos go away with the fixture user in `wipe.ts` through the `VoiceMemo.user onDelete: Cascade` (D19). No wipe change

**Tests:**
- `segments are timestamped and spell memo 1's transcript` (D19)

```ts
it('segments are timestamped and spell memo 1\'s transcript', () => {
  expect(MEMO_DETAIL_SEGMENTS.map((s) => s.startMs)).toEqual([0, 4000, 8000])
  const memo1 = libraryHomeMemos(new Date(), (n) => new Date(Date.now() - n * 86_400_000))[0]
  expect(MEMO_DETAIL_SEGMENTS.map((s) => s.text).join(' ')).toBe(memo1.transcript)
})
```

- `the audio uploads once, under the real memo key` (D19)

```ts
it('the audio uploads once, under the real memo key', async () => {
  const uploads: string[] = []
  const stored = new Set<string>()
  const deps = {
    objectExists: async (k: string) => stored.has(k),
    uploadToR2: async (k: string, _b: Buffer, type: string) => { expect(type).toBe('audio/mp4'); uploads.push(k); stored.add(k); return k },
  }
  const key = memoKey(FIXTURE_USER_ID, fixtureId('voiceMemo', 1))
  expect(await placeMemoAudio(key, Buffer.from('x'), deps)).toBe(true)
  expect(await placeMemoAudio(key, Buffer.from('x'), deps)).toBe(false)
  expect(uploads).toEqual([key])
})
```

- `after reset full the leader has the 5 D19 memos, memo 1 with segments; a second reset keeps the ids` — DB test, `describe.skipIf(!TEST_DB_URL)`, the `search-home.db.test.ts` pattern

```ts
it('after reset full the leader has the 5 D19 memos, memo 1 with segments', async () => {
  const memos = await db.prisma.voiceMemo.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { recordedAt: 'desc' } })
  expect(memos.map((m) => m.transcriptStatus)).toEqual(['ready', 'pending', 'failed', 'none', 'ready'])
  expect((memos[0].transcriptSegments as unknown[]).length).toBe(3)
  const { memoIdsDueForTranscriptRetry } = await import('../../src/services/memos.service.js')
  expect(await memoIdsDueForTranscriptRetry()).toEqual([])
})
it('a second reset succeeds with the same memo ids', async () => {
  const ids = async () => (await db.prisma.voiceMemo.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map((r) => r.id)
  const first = await ids()
  await db.run('reset', 'full')
  expect(await ids()).toEqual(first)
})
```

- [ ] **Step 1: Generate and commit-stage the `.m4a`**, as Files says
- [ ] **Step 2: Write the listed tests**, and update the screen list in `home-dashboard.test.ts`
- [ ] **Step 3: Run `cd server && npx vitest run fixtures/__tests__/memo-detail.test.ts fixtures/__tests__/memo-detail.db.test.ts fixtures/__tests__/home-dashboard.test.ts`, watch them fail** — the module does not exist (the DB test runs only with `FIXTURES_TEST_DATABASE_URL` set; the verifier's lease sets it)
- [ ] **Step 4: Write `screens/memo-detail.ts`** to the Behaviour, and update the README
- [ ] **Step 5: Run the same command, watch them pass** — then `npx tsc -p fixtures/tsconfig.json --noEmit`
- [ ] **Step 6: Commit** — `feat(memo-screens): memo-detail fixture layer with playable audio`

### Task 3: `MemoRecorderEngine.discard()`
App: iphone
Phase: 2
Recipe: test-driven-development · tiny

**Files:**
- Modify: `iphone/MakeReady/Services/Audio/MemoRecorderEngine.swift:184` — add `discard()` beside `stop()`
- Test: `iphone/MakeReadyCaptureTests/MemoRecorderEngineTests.swift` — the discard cases

**Interfaces:**
- Produces: `MemoRecorderEngine.discard()` — `async`, returns nothing, never throws

**Behaviour:**
- From `.recording` or `.paused`, `discard()` stops the input, closes the pipeline, finishes the live transcriber and drops its result, deletes the session's `.caf` and calls `drafts.remove(cafURL:)`. It makes no `.m4a` and returns no `RecordingResult`, then runs `end()`, so `state` is `.idle` and the audio session is restored (D7)
- In any other state it does nothing (D7)
- `onAutoStop` is not called (D7)

**Pattern:**
- `MemoRecorderEngine.swift:239-245` — the `.writeFailed` branch's stop/close/finish/end order

**Tests:**
- `discard leaves no caf, no m4a, no draft manifest` (D7)

```swift
func testDiscardLeavesNoCafNoM4aAndNoDraft() async throws {
    let engine = makeEngine(seconds: 1.0)
    try await engine.prepare(title: "Memo 1")
    try await engine.start()
    try await Task.sleep(for: .milliseconds(200))
    await engine.discard()
    XCTAssertEqual(engine.state, .idle)
    let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    XCTAssertTrue(left.filter { $0.hasSuffix(".caf") || $0.hasSuffix(".m4a") }.isEmpty, "\(left)")
    XCTAssertTrue(drafts.recoverable().isEmpty)
}
```

- `discard when idle is a no-op` (D7)

```swift
func testDiscardWhenIdleDoesNothing() async {
    let engine = makeEngine(seconds: 0)
    await engine.discard()
    XCTAssertEqual(engine.state, .idle)
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `MemoRecorderEngineTests`, watch them fail** — no `discard`
- [ ] **Step 3: Implement `discard()`** to the Behaviour
- [ ] **Step 4: Run the suite for `MemoRecorderEngineTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(memo-screens): MemoRecorderEngine.discard`

### Task 4: queued memos — rename, remove, file, completed ids
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/Services/Audio/MemoUploadController.swift:26-44,113-138,418-460` — `title` becomes `var`; `enqueue` returns its item; the new methods below
- Test: `iphone/MakeReadyCaptureTests/MemoUploadControllerTests.swift`

**Interfaces:**
- Produces:
  - `MemoQueueItem.title` is now a `var`.
  - `MemoUploadController.enqueue(_:)` is `@discardableResult` and returns the persisted `MemoQueueItem`.
  - `item(localId:)` returns the pending `MemoQueueItem?`.
  - `fileURL(for:)` takes a `MemoQueueItem` and returns its `.m4a` URL in the queue directory.
  - `rename(localId:title:)` is `async throws`.
  - `remove(localId:)` is `async throws`.
  - `serverId(forLocalId:)` returns `String?`: a pending item's `serverId`, or the server id recorded when that item completed.
- Consumes: `MemoActions.rename(id:title:)`, `MemoActions.softDelete(id:)`

**Behaviour:**
- `rename` rewrites the manifest's `title`, so the create POST carries it. When the item already has a `serverId`, it also calls `actions.rename(id: serverId, title:)` (D17)
- `remove` deletes the `.m4a` and the manifest. When the item has a `serverId`, it also calls `actions.softDelete(id: serverId)`. A flush already running for that item finds no manifest and moves on (D17)
- When `complete` succeeds, the controller records `localId → serverId` in memory before it removes the item, so a `local:` page can find the server memo afterwards (D17)
- An unknown `localId` throws `CancellationError` from `rename` and `remove` (D17)

**Tests:**
- `rename rewrites the manifest title` (D17)

```swift
func testRenameRewritesTheQueuedManifestTitle() async throws {
    let controller = makeController()
    let item = try controller.enqueue(makeResult(transcript: nil))
    try await controller.rename(localId: item.localId, title: "Retreat ideas")
    XCTAssertEqual(controller.item(localId: item.localId)?.title, "Retreat ideas")
    XCTAssertEqual(makeController().pending().first?.title, "Retreat ideas")   // persisted
}
```

- `remove deletes the m4a and the manifest` (D17)

```swift
func testRemoveDeletesTheM4aAndManifest() async throws {
    let controller = makeController()
    let item = try controller.enqueue(makeResult(transcript: nil))
    let file = controller.fileURL(for: item)
    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    try await controller.remove(localId: item.localId)
    XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    XCTAssertTrue(controller.pending().isEmpty)
}
```

- `remove with a server id also soft-deletes on the server` — after a stubbed create gives the item `serverId` `"m9"`, `remove` sends `DELETE /api/memos/m9` (D17)

```swift
XCTAssertTrue(api.recordedStatusCalls.contains { $0.method == "DELETE" && $0.endpoint == "/api/memos/m9" })
```

- `a completed upload keeps its server id findable` — after a full stubbed create → PUT → complete, `serverId(forLocalId:)` is `"m9"` and `pending()` is empty (D17)

```swift
XCTAssertEqual(controller.serverId(forLocalId: item.localId), "m9")
XCTAssertTrue(controller.pending().isEmpty)
```

- [ ] **Step 1: Write the listed tests** — reuse the file's `makeController`, `makeResult`, `SpyTransport` and stubbed create/complete responses; if `StubAPIClient` has no accessor for recorded DELETE calls, add one in `StubAPIClient.swift`
- [ ] **Step 2: Run the iphone-xctest suite for `MemoUploadControllerTests`, watch them fail**
- [ ] **Step 3: Implement the Interfaces** to the Behaviour
- [ ] **Step 4: Run the suites for `MemoUploadControllerTests` and `MemoUploadFlushTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(memo-screens): queued memo rename, remove and file access`

### Task 5: `MemoActions.loadMemos` pages to `total`
App: iphone
Phase: 2
Recipe: test-driven-development · tiny

**Files:**
- Modify: `iphone/MakeReady/State/Actions/MemoActions.swift:23-41` — the paging loop
- Test: `iphone/MakeReadyCaptureTests/MemoActionsTests.swift`

**Interfaces:**
- Produces: `MemoActions.loadMemos(q:)` — same signature. It returns every memo across pages

**Behaviour:**
- It pages `GET /api/memos?[q=…&]limit=100&offset=<n>`, adding 100 to `offset` each time, until it has `total` rows or a page comes back empty (D18)
- Only the unfiltered load (`q` nil or empty) replaces `AppState.voiceMemos`, once, with every row (D18, engine D39)
- A failing page throws and leaves the store as it was (D18)

**Pattern:**
- `NoteActions.swift:46-66` — the paging loop

**Tests:**
- `130 memos over two pages all reach voiceMemos` (D18)

```swift
func testLoadMemosPagesUntilTotal() async throws {
    let first = (1...100).map { summaryJSON("m\($0)") }.joined(separator: ",")
    let second = (101...130).map { summaryJSON("m\($0)") }.joined(separator: ",")
    api.stub("GET", "/api/memos?limit=100&offset=0", json: #"{"memos":[\#(first)],"total":130}"#)
    api.stub("GET", "/api/memos?limit=100&offset=100", json: #"{"memos":[\#(second)],"total":130}"#)
    let memos = try await MemoActions(api: api, state: state).loadMemos(q: nil)
    XCTAssertEqual(memos.count, 130)
    XCTAssertEqual(state.voiceMemos.all.count, 130)
}
```

- `an empty page ends the loop` — `total: 5` with an empty first page returns `[]` and makes one request (D18)

```swift
XCTAssertEqual(memos, [])
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `MemoActionsTests`, watch them fail** — 100 rows, not 130
- [ ] **Step 3: Implement the loop**
- [ ] **Step 4: Run the suite for `MemoActionsTests`, watch them pass**
- [ ] **Step 5: Commit** — `fix(memo-screens): load every page of memos`

### Task 6: `MemoPlayer`
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/Services/Audio/MemoPlayer.swift` — `MemoPlayer`, its backend and session protocols, and the AVFoundation implementations
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — explicit references for the new file and its test, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoPlayerTests.swift` — with a spy backend and a spy session

**Interfaces:**
- Produces:
  - `MemoPlayer` — `@MainActor @Observable`. Its `init` takes `backend: MemoPlaybackBackend`, `session: MemoPlaybackSessionControlling`, `fetchDetail: (String) async throws -> VoiceMemo` and `now: () -> Date`.
  - Published: `elapsed: Double`, `duration: Double`, `isPlaying: Bool`, `isReady: Bool`.
  - `load(_ source: MemoPlayer.Source) async`, where `Source` is `.remote(VoiceMemo)` or `.local(url: URL, durationMs: Int)`.
  - `play()`, `pause()`, `skip(by seconds: Double)`, `seek(to seconds: Double)` and `stop()`.
  - `MemoPlaybackBackend` protocol: `load(url:)`, `play()`, `pause()`, `seek(to:)`, `currentTime` (seconds) and an `onFailure` callback that carries the HTTP status when there is one.
  - `MemoPlaybackSessionControlling` protocol: `activatePlayback() throws` and `restore()`.
  - `AVMemoPlaybackBackend` and `MemoPlaybackSession` are the production implementations, over `AVPlayer` and `AVAudioSession`.
- Consumes: `VoiceMemo.url`, `.urlExpiresAt`, `.durationMs`, `.id`; `MemoActions.loadMemo(id:)`, which the container passes as `fetchDetail`

**Behaviour:**
- `.remote` plays `url`. When `urlExpiresAt` is in the past at `load` or at `play`, it first calls `fetchDetail(memo.id)` and uses the fresh `url`. A backend failure with status 403 re-fetches once and reloads at the same position (D13)
- `.local` plays the queued `.m4a` file URL (D13, D17)
- `duration` comes from `durationMs / 1000` (D13)
- `skip(by:)` and `seek(to:)` clamp to `[0, duration]` (D13)
- `play()` calls `session.activatePlayback()` first, and `stop()` pauses and calls `session.restore()`. The container calls `stop()` when memo-detail disappears (D13)
- `isReady` is false until the backend has a loaded item (memo-detail `playerReady`) (D13)

**Tests:**
- `skip clamps to the memo's bounds` (D13)

```swift
func testSkipClampsToBounds() async {
    let player = makePlayer()
    await player.load(.local(url: URL(fileURLWithPath: "/tmp/a.m4a"), durationMs: 20_000))
    player.skip(by: -15); XCTAssertEqual(backend.seeks.last, 0)
    player.seek(to: 10); player.skip(by: 15); XCTAssertEqual(backend.seeks.last, 20)
}
```

- `an expired url is re-fetched before it loads` (D13)

```swift
func testExpiredURLIsRefetched() async {
    let player = makePlayer(fetch: { _ in self.memo(url: "https://r2/fresh", expires: self.clock.addingTimeInterval(3600)) })
    await player.load(.remote(memo(url: "https://r2/old", expires: clock.addingTimeInterval(-1))))
    XCTAssertEqual(fetches, 1)
    XCTAssertEqual(backend.loaded.last?.absoluteString, "https://r2/fresh")
}
```

- `a 403 re-fetches once` (D13)

```swift
backend.onFailure?(403); try? await Task.sleep(for: .milliseconds(50))
XCTAssertEqual(fetches, 1)
```

- `a queued memo plays from the local file` (D13)

```swift
await player.load(.local(url: URL(fileURLWithPath: "/tmp/q.m4a"), durationMs: 5_000))
XCTAssertEqual(backend.loaded.last, URL(fileURLWithPath: "/tmp/q.m4a"))
XCTAssertEqual(player.duration, 5)
```

- `stop restores the audio session` (D13)

```swift
player.play(); player.stop()
XCTAssertEqual(session.calls, ["activatePlayback", "restore"])
XCTAssertFalse(player.isPlaying)
```

- [ ] **Step 1: Write the listed tests**, with the spies and the `makePlayer`/`memo` helpers in the test file
- [ ] **Step 2: Run the iphone-xctest suite for `MemoPlayerTests`, watch them fail**
- [ ] **Step 3: Implement `MemoPlayer.swift`** to the Behaviour, and register the files
- [ ] **Step 4: Run the suite for `MemoPlayerTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(memo-screens): MemoPlayer`

### Task 7: Library merge — notes and memos in one sectioned list, merged search
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Models/NoteModels.swift:130` — `sectionTitle(for:now:calendar:)` becomes `internal`, so memos share the notes rule
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeMapper.swift` — the merged model below; `rows`, `phase`, `state` and `noteIds` move to `LibrarySection`
- Create: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeSearch.swift` — the parallel search
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift` — only the call sites, so it compiles with notes as before (the memo wiring is Task 10)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/LibraryHomeMapperTests.swift` — existing tests updated to the new signatures, plus the cases below
- Test: `iphone/MakeReadyCaptureTests/LibraryHomeSearchTests.swift`

**Interfaces:**
- Produces:
  - `LibraryHomeMapper.MemoSource` — `id`, `title`, `durationMs: Int?`, `recordedAt: Date` and `preview: MemoListRow.Preview`. Built by `memoSource(summary:)` from a `VoiceMemoSummary`, or by `memoSource(queued:)` from a `MemoQueueItem`, whose `id` is `"local:" + localId`.
  - `LibraryHomeMapper.preview(status:transcriptPreview:)` returns a `MemoListRow.Preview`.
  - `LibraryHomeMapper.durationLabel(ms:)` returns a `String`.
  - `LibraryHomeMapper.visibleMemos(stored:queued:searchMatches:)` returns `[MemoSource]`.
  - `LibraryHomeMapper.LibrarySection` — `title`, `notes: [StudyNote]`, `memos: [MemoSource]`.
  - `LibraryHomeMapper.rows(notes:searchIds:memos:now:calendar:)` returns `[LibrarySection]`.
  - `phase(isLoading:loadFailed:sections:query:)` and `state(sections:phase:query:now:calendar:)` take `[LibrarySection]`.
  - `noteIds(in:)` takes `[LibrarySection]`.
  - `LibraryHomeSearch.run(q:loadNotes:loadMemos:)` — `async`, returns `LibraryHomeSearch.Result`: `noteIds: [String]`, `memos: [VoiceMemoSummary]`, `failed: Bool`.
- Consumes: `VoiceMemoSummary` (`MemoModels.swift`), `MemoQueueItem` (Task 4), `MemoListRow.Preview`, `LibraryHomeScreen.State.MemoRowInput`, `NotesSectioning.sectionTitle`, `NotesSectioning.dateLabel`, `NoteTimestamp.parse`

**Behaviour:**
- Preview mapping: `ready` with non-empty `transcriptPreview` → `.transcript(preview)`; `ready` with an empty preview, `failed`, `none` and `unknown` → `.audioOnly`; `pending` → `.transcribing`; any queued item → `.waitingToUpload` (D5, D16)
- `durationLabel`: `m:ss` under an hour (`0:42`, `3:04`) and `h:mm:ss` from an hour (`1:02:05`); nil `durationMs` → `0:00` (D5)
- `visibleMemos`: with `searchMatches` nil, it returns the stored memos plus the queued items, minus any queued item whose `serverId` is already stored. With `searchMatches` set, it returns only those (a queued memo has no server transcript to match) (D5, D17)
- `rows` sorts each memo by `recordedAt` and each note by `updatedAt`, newest first, in one list, and gives both kinds the section from `NotesSectioning.sectionTitle`. Sections are newest first, with empty ones left out (D5, T2)
- `state` fills `rowUpdatedAt` per note row, and fills `memos` with `MemoRowInput`s. Each carries the index of its section, its `recordedAt`, `durationLabel` and preview, and `dateLabel` from `NotesSectioning.dateLabel` (D5)
- `phase` counts memos as rows: a list holding only memos is `.list` (D5)
- `LibraryHomeSearch.run` runs both loaders at once (`async let`). A side that throws contributes nothing, and `failed` is true. A `CancellationError` from either side is rethrown, not counted as a failure (D5, T5)

**Tests:**
- `notes and memos interleave across Today, Previous 7 Days and an earlier month` (D5, T2)

```swift
func testNotesAndMemosInterleaveBySectionAndDate() {
    let sections = LibraryHomeMapper.rows(
        notes: [note("n1", updated: now - 2 * 3600), note("n2", updated: now - 40 * 86_400)],
        searchIds: nil,
        memos: [memo("m1", recorded: now - 3600), memo("m2", recorded: now - 4 * 86_400)],
        now: now, calendar: calendar)
    XCTAssertEqual(sections.map(\.title), ["Today", "Previous 7 Days", "October"])
    XCTAssertEqual(sections[0].memos.map(\.id), ["m1"]); XCTAssertEqual(sections[0].notes.map(\.id), ["n1"])
    XCTAssertEqual(sections[1].memos.map(\.id), ["m2"]); XCTAssertEqual(sections[2].notes.map(\.id), ["n2"])
}
```

- `each transcript status maps to its preview slot` (D5, D16)

```swift
func testPreviewSlotPerStatus() {
    XCTAssertEqual(LibraryHomeMapper.preview(status: .ready, transcriptPreview: "Grace is"), .transcript("Grace is"))
    XCTAssertEqual(LibraryHomeMapper.preview(status: .pending, transcriptPreview: nil), .transcribing)
    XCTAssertEqual(LibraryHomeMapper.preview(status: .failed, transcriptPreview: nil), .audioOnly)
    XCTAssertEqual(LibraryHomeMapper.preview(status: .none, transcriptPreview: nil), .audioOnly)
    XCTAssertEqual(LibraryHomeMapper.preview(status: .unknown, transcriptPreview: nil), .audioOnly)
}
```

- `a queued memo shows Waiting to upload, under a local id, once` (D5, D17)

```swift
func testQueuedMemoIsWaitingToUploadAndDeduped() {
    let shown = LibraryHomeMapper.visibleMemos(stored: [summary("m9")], queued: [queued("q1"), queued("q2", serverId: "m9")], searchMatches: nil)
    XCTAssertEqual(shown.map(\.id), ["m9", "local:q1"])
    XCTAssertEqual(shown.last?.preview, .waitingToUpload)
}
```

- `durations format as m:ss and h:mm:ss` (D5)

```swift
XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: 42_000), "0:42")
XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: 3_725_000), "1:02:05")
XCTAssertEqual(LibraryHomeMapper.durationLabel(ms: nil), "0:00")
```

- `a memos-only list is populated` (D5)

```swift
XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [.init(title: "Today", notes: [], memos: [memo("m1", recorded: now)])], query: ""), .list)
```

- `the merged search shows both results; one failing still shows the other` (D5, T5)

```swift
func testOneSourceFailingStillShowsTheOther() async throws {
    let both = try await LibraryHomeSearch.run(q: "grace", loadNotes: { ["n1"] }, loadMemos: { [self.summary("m1")] })
    XCTAssertEqual(both.noteIds, ["n1"]); XCTAssertEqual(both.memos.map(\.id), ["m1"]); XCTAssertFalse(both.failed)
    let half = try await LibraryHomeSearch.run(q: "grace", loadNotes: { throw URLError(.notConnectedToInternet) }, loadMemos: { [self.summary("m1")] })
    XCTAssertEqual(half.noteIds, []); XCTAssertEqual(half.memos.map(\.id), ["m1"]); XCTAssertTrue(half.failed)
}
```

- [ ] **Step 1: Write the listed tests, and update the existing mapper tests to the new signatures** — `note`, `memo`, `summary`, `queued` helpers in the test files, with `now` fixed at `2026-11-20T17:00:00Z` and a Gregorian calendar in `America/Chicago`
- [ ] **Step 2: Run the iphone-xctest suite for `LibraryHomeMapperTests` and `LibraryHomeSearchTests`, watch them fail**
- [ ] **Step 3: Implement the mapper and search** to the Behaviour, and update the container's call sites (notes only, no behaviour change)
- [ ] **Step 4: Run the suites, watch them pass**
- [ ] **Step 5: Commit** — `feat(memo-screens): Library merges notes and memos`

### Task 8: memo-detail mapper
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Memo/MemoDetailMapper.swift` — `VoiceMemo` or `MemoQueueItem` + player values → `MemoDetailScreen.State`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoDetailMapperTests.swift`

**Interfaces:**
- Produces:
  - `MemoDetailMapper.state(memo:elapsed:playing:playerReady:now:calendar:)` takes a `VoiceMemo` and returns a `MemoDetailScreen.State`.
  - `MemoDetailMapper.state(queued:elapsed:playing:playerReady:now:calendar:)` does the same for a `MemoQueueItem`.
  - `MemoDetailMapper.metaDate(_:now:calendar:)` returns a `String`.
- Consumes: `MemoDetailScreen.State` (`MakeReadyUI/Screens/Library/MemoDetailScreen.swift:23-56`), `VoiceMemo.transcriptSegments`, `.transcript`, `.transcriptStatus`, `MemoQueueItem.transcript`, `NotesSectioning.dateLabel`

**Behaviour:**
- A server memo:
  - `ready` with segments → `.paragraphs`. `paragraphStarts` is each `floor(startMs / 1000)` and `paragraphTexts` each `text` (T3).
  - `ready` with no segments and a non-empty `transcript` → one paragraph at start `0` (T3).
  - `pending` → `.transcribing` (T3).
  - `failed`, `none` and `unknown` → `.unavailable` (T3, D16).
- A queued memo uses its on-device `Transcript`'s segments when it has some, else `.transcribing` (D17)
- `duration` is `durationMs / 1000`, or `0` when `durationMs` is nil (D4)
- `metaDate`: the day part is `Today` or `Yesterday` for those days and `NotesSectioning.dateLabel` otherwise, followed by a space and the time as `h:mm a` (`Today 7:43 PM`). The screen appends the duration itself (D4)

**Tests:**
- `segments become paragraphs with second starts` (T3)

```swift
func testSegmentsBecomeParagraphs() {
    let s = MemoDetailMapper.state(memo: memo(status: "ready", segments: [("A.", 0), ("B.", 4_500), ("C.", 8_000)]), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
    XCTAssertEqual(s.transcript, .paragraphs)
    XCTAssertEqual(s.paragraphStarts, [0, 4, 8]); XCTAssertEqual(s.paragraphTexts, ["A.", "B.", "C."])
}
```

- `no segments falls back to one paragraph from transcript` (T3)

```swift
let s = MemoDetailMapper.state(memo: memo(status: "ready", segments: [], transcript: "Whole text."), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar)
XCTAssertEqual(s.paragraphStarts, [0]); XCTAssertEqual(s.paragraphTexts, ["Whole text."])
```

- `pending is transcribing; failed, none and unknown are unavailable` (T3, D16)

```swift
XCTAssertEqual(state(status: "pending").transcript, .transcribing)
for status in ["failed", "none", "somethingNew"] { XCTAssertEqual(state(status: status).transcript, .unavailable) }
```

- `a queued memo without an on-device transcript is transcribing` (D17)

```swift
XCTAssertEqual(MemoDetailMapper.state(queued: queued(transcript: nil), elapsed: 0, playing: false, playerReady: true, now: now, calendar: calendar).transcript, .transcribing)
```

- `the meta date reads Today 7:43 PM` (D4)

```swift
XCTAssertEqual(MemoDetailMapper.metaDate(todayAt(19, 43), now: now, calendar: calendar), "Today 7:43 PM")
```

- [ ] **Step 1: Write the listed tests**, with `memo`, `queued`, `state` and `todayAt` helpers and the Task 7 clock and calendar
- [ ] **Step 2: Run the iphone-xctest suite for `MemoDetailMapperTests`, watch them fail**
- [ ] **Step 3: Implement `MemoDetailMapper`** to the Behaviour, and register the files
- [ ] **Step 4: Run the suite, watch them pass**
- [ ] **Step 5: Commit** — `feat(memo-screens): memo-detail mapper`

### Task 9: memo-detail page — destination, model and container
App: iphone
Phase: 3
Recipe: push-page

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:18` — `UI2Destination.memoDetail(memoId: String)`. This is the plan's name for the spec's `UI2Route.memoDetail(memoId:)`: pushed pages in this app are `UI2Destination` cases, and `UI2Route` holds only tabs and sections. It is not full screen (the TabBar stays, like the notes list)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:206` — `page(for:)` gains `case let .memoDetail(memoId): MemoDetailContainer(memoId: memoId)`
- Create: `iphone/MakeReady/UI2/Containers/Memo/MemoDetailModel.swift` — the page's logic
- Create: `iphone/MakeReady/UI2/Containers/Memo/MemoDetailContainer.swift` — the view: renders `MemoDetailScreen` from the model, wires its callbacks and pops through `UI2Navigator`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoDetailModelTests.swift`

**Interfaces:**
- Produces:
  - `UI2Destination.memoDetail(memoId:)`.
  - `MemoDetailModel` — `@MainActor @Observable`. Its `init` takes `memoId: String`, `actions: MemoActions`, `uploads: MemoUploadController?` and `player: MemoPlayer`.
  - `MemoDetailModel.Target` is `.server(String)` or `.local(String)`, parsed by `static func target(_:)` from a `local:` prefix.
  - `load() async`, `syncQueued() async`, `rename(_ title: String) async` and `delete() async -> Bool` (true means pop).
  - `screenState(now:calendar:)` returns a `MemoDetailScreen.State`.
  - `MemoDetailContainer(memoId:)`.
- Consumes:
  - `MemoActions.loadMemo(id:)`, `rename(id:title:)`, `softDelete(id:)`
  - `MemoUploadController.item(localId:)`, `fileURL(for:)`, `rename(localId:title:)`, `remove(localId:)`, `serverId(forLocalId:)` (Task 4)
  - `MemoPlayer` (Task 6), `MemoDetailMapper` (Task 8)

**Behaviour:**
- `.server(id)`: `load()` calls `loadMemo(id:)`, then `player.load(.remote(memo))`. A failure routes through `AppState.shared.recordError(…, surface: true, friendlyMessage: "Couldn't load this memo", retry:)` (D4, D11, `/ios-error-surface`)
- `.local(localId)`: `load()` reads `uploads.item(localId:)` and plays `.local(url: fileURL(for:), durationMs:)` (D17)
- `syncQueued()` switches the target to `.server` and loads the server memo without leaving the page once `serverId(forLocalId:)` returns an id. The container calls it whenever the ids in `AppState.shared.voiceMemos` change (D17)
- `rename` trims the title. An empty result is ignored (the screen already reverts it), and a result over 120 characters is cut to 120. A server target calls `actions.rename`; a local one calls `uploads.rename(localId:title:)` (D8, D17)
- `delete` calls `actions.softDelete` for a server target and `uploads.remove(localId:)` for a local one, then calls `player.stop()` and returns true so the container pops. A failure goes through `recordError(surface: true, friendlyMessage: "Couldn't delete this memo")` and returns false (D8, D17)
- The container calls `player.stop()` in `onBack` and `.onDisappear` (D13)
- Seeking a paragraph seeks to its start and plays (D4)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Notes/` — how a pushed UI2 container reads `ui2Navigator` and pops

**Tests:**
- `a local id targets the queue; any other id the server` (D17)

```swift
XCTAssertEqual(MemoDetailModel.target("local:q1"), .local("q1"))
XCTAssertEqual(MemoDetailModel.target("m1"), .server("m1"))
```

- `an empty rename reverts and sends nothing` (D8)

```swift
await model.rename("   ")
XCTAssertTrue(api.recordedCalls(method: "PATCH").isEmpty)
```

- `delete removes the memo from Library and asks to pop` (D8)

```swift
state.voiceMemos.upsert(summary("m1"))
api.stubStatus("DELETE", "/api/memos/m1", status: 204)
let popped = await model.delete()
XCTAssertTrue(popped); XCTAssertNil(state.voiceMemos["m1"])
```

- `a local page switches to the server memo once the upload completes` (D17)

```swift
let model = makeModel(memoId: "local:\(item.localId)")
await model.load()
completeUpload(item, serverId: "m9")          // drives the stubbed create → PUT → complete
await model.syncQueued()
XCTAssertEqual(model.target, .server("m9"))
```

- `renaming a queued memo rewrites its manifest` (D17)

```swift
await makeModel(memoId: "local:\(item.localId)").rename("Retreat ideas")
XCTAssertEqual(uploads.item(localId: item.localId)?.title, "Retreat ideas")
```

- [ ] **Step 1: Write the listed tests** — a private `AppState`, a `StubAPIClient`, a temp-directory `MemoUploadController`, and a `MemoPlayer` on a spy backend, as Tasks 4 and 6's tests build them. Add `StubAPIClient` helpers only if the ones named are missing
- [ ] **Step 2: Run the iphone-xctest suite for `MemoDetailModelTests`, watch them fail**
- [ ] **Step 3: Add the destination, the model and the container** to the Behaviour, and register the files
- [ ] **Step 4: Run the suites for `MemoDetailModelTests` and `UI2ShellModelTests`, watch them pass** — then `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(memo-screens): memo-detail page`

### Task 10: Library container shows memos and searches both
App: iphone
Phase: 3
Recipe: nav-route

> **Build-time risk (A7), from §Findings:** the walk server has no Groq key, so a memo the walk records itself may stay at Transcribing… unless the on-device transcript arrives. The agent walk's Library item accepts either Transcribing… or a preview. Nothing in this task should change to work around it.

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift` — memos in the list, merged search, memo row push
- Test: `iphone/MakeReadyCaptureTests/LibraryHomeMapperTests.swift` — the row-tap destination

**Interfaces:**
- Produces: `LibraryHomeContainer.destination(forMemoId:)` — `static`, returns `UI2Destination.memoDetail(memoId:)`
- Consumes: `LibraryHomeMapper.visibleMemos`, `rows(notes:searchIds:memos:now:calendar:)`, `memoSource(summary:)` and `memoSource(queued:)`, plus `LibraryHomeSearch.run` (Task 7); `MemoActions.loadMemos(q:)` (Task 5); `AppState.shared.voiceMemos` and `AppState.shared.memoUploads?.pending()`; `UI2Destination.memoDetail(memoId:)` (Task 9)

**Behaviour:**
- The first load runs `NoteActions().load(q: nil)` and `MemoActions().loadMemos(q: nil)` in parallel. One failing keeps the other on screen and routes to `recordError(surface: true, friendlyMessage: "Couldn't load your library", retry:)` (D5, D20 notes)
- The list is `visibleMemos(stored: AppState.shared.voiceMemos.all, queued: memoUploads?.pending() ?? [], searchMatches:)` merged with the notes through `rows` (D5)
- The search keeps the 300 ms debounce, then calls `LibraryHomeSearch.run` with `NoteActions().load(q:)` and `MemoActions().loadMemos(q:)`. It stores `noteIds` as `searchIds` and `memos` as `searchMatches`. `failed` routes to the error channel, and the shown half stays (D5, T5)
- Clearing the query sets both `searchIds` and `searchMatches` back to nil (D5)
- `onOpenMemo` pushes `destination(forMemoId: id)` through `navigator.push`. Queued rows carry their `local:` id (D4, D17)

**Tests:**
- `a memo row pushes memo-detail with its id` (D4, D17)

```swift
func testMemoRowPushesMemoDetail() {
    XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "m1"), .memoDetail(memoId: "m1"))
    XCTAssertEqual(LibraryHomeContainer.destination(forMemoId: "local:q1"), .memoDetail(memoId: "local:q1"))
}
```

- [ ] **Step 1: Write the listed test**
- [ ] **Step 2: Run the iphone-xctest suite for `LibraryHomeMapperTests`, watch it fail**
- [ ] **Step 3: Wire the container** to the Behaviour
- [ ] **Step 4: Run the suites for `LibraryHomeMapperTests` and `LibraryHomeSearchTests`, watch them pass** — then `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(memo-screens): Library lists and searches memos`

### Task 11: the recorder session and sheet container
App: iphone
Phase: 3
Recipe: present-overlay

> **Build-time risk (F1), from §Findings:** the engine's on-device behaviour (≤200 ms start, lock and background survival, call interruption, `SpeechTranscriber` assets) has never run on a device. It is settled by the human walk's item 1 only. An agent walk on the simulator cannot prove it, so nothing here may claim it.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Memo/RecorderSession.swift` — the recording's logic over the engine
- Create: `iphone/MakeReady/UI2/Containers/Memo/RecorderSheetContainer.swift` — renders `RecorderSheet` (C-016) from the session and reports how it ended
- Modify: `iphone/MakeReady/Info.plist:119-122` — add `<string>audio</string>` to `UIBackgroundModes` (D10)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/RecorderSessionTests.swift`

**Interfaces:**
- Produces:
  - `RecorderSession` — `@MainActor @Observable`. Its `init` takes `engine: MemoRecorderEngine`, `title: String`, `enqueue: (RecordingResult) throws -> MemoQueueItem`, `now: () -> Date` and `calendar: Calendar`.
  - `RecorderSession.Outcome` is `.saved(localId: String)`, `.discarded` or `.failed`. The session publishes it as `outcome: Outcome?`.
  - Published: `expansion: Double`, `menu: RecorderExpandedView.Menu`, `startTime: String`, `phase: RecorderExpandedView.Phase`.
  - `begin() async`, `finish() async` (used by both stop and Done), `pause()`, `resume()`, `openMenu()`, `requestDiscard()`, `confirmDiscard() async`, `dismissMenu()`, `close()` and `settle(_ expansion: Double)`.
  - `static func phase(state:error:)` returns a `RecorderExpandedView.Phase`.
  - `RecorderSheetContainer(session:onEnd:)`, where `onEnd` takes an `Outcome`.
- Consumes: `MemoRecorderEngine.prepare(title:)`, `start()`, `pause()`, `resume()`, `stop()`, `discard()` (Task 3), `onAutoStop`, `state`, `elapsed`, `samples`, `lastError`; `MemoUploadController.enqueue(_:)` returning its item (Task 4); `RecorderSheet`'s props (`MakeReadyUI/RecorderSheet.swift:28-55`)

**Behaviour:**
- `begin()` calls `prepare(title:)` and then `start()`, with no record tap. When `start()` returns, it stamps `startTime` as `now()` formatted `h:mm a` (D3, T1)
- `micPermissionDenied` from `prepare` → `phase` `.micDenied`. Nothing is created or enqueued, and `close()` (the mic-denied close) ends with `.discarded`. **Open Settings** opens `UIApplication.openSettingsURLString` (D11)
- `phase(state:error:)`: `.paused` → `.paused`; a `micPermissionDenied` error → `.micDenied`; anything else → `.recording` (T1)
- `settle` changes `expansion` only and never calls the engine. The container gives the sheet no swipe-to-dismiss (D3)
- `finish()` calls `engine.stop()`, enqueues the result and ends with `.saved(localId:)`. Compact stop and expanded Done both call it (D3)
- `engine.onAutoStop` (the 3 h limit) enqueues its result and ends with `.saved`, the same as Done (D11)
- `writeFailed` from `stop()` or the engine → `AppState.shared.recordError(…, surface: true, friendlyMessage: "Couldn't save the recording")` and ends with `.failed` (D11, `/ios-error-surface`)
- `speechUnavailable` does not stop the recording (D11, engine D5)
- `openMenu` → `.actions`; `requestDiscard` → `.discardConfirm`; `dismissMenu` → `.none`. `confirmDiscard` calls `engine.discard()`, enqueues nothing and ends with `.discarded` (D7)
- The container presents nothing itself: no `.sheet`, no `.fullScreenCover`, no `asyncAfter`. The shell hosts it (Task 12). The sheet's snap uses the view's own `Token.Motion.sheetSnap` (`/transition-review`)

**Tests:**
- `stop and Done both enqueue one result and save` (D3)

```swift
func testFinishEnqueuesOneResultAndSaves() async throws {
    let session = makeSession(seconds: 1.0)
    await session.begin()
    try await Task.sleep(for: .milliseconds(200))
    await session.finish()
    XCTAssertEqual(enqueued.count, 1)
    guard case .saved = session.outcome else { return XCTFail("\(String(describing: session.outcome))") }
}
```

- `begin stamps the start time` (T1)

```swift
await session.begin()
XCTAssertEqual(session.startTime, "7:43 PM")   // now() fixed at 19:43 in the test calendar
```

- `discard enqueues nothing` (D7)

```swift
await session.begin(); session.openMenu(); session.requestDiscard()
XCTAssertEqual(session.menu, .discardConfirm)
await session.confirmDiscard()
XCTAssertTrue(enqueued.isEmpty); XCTAssertEqual(session.outcome, .discarded)
```

- `mic denied maps to the mic-denied phase` (D11)

```swift
XCTAssertEqual(RecorderSession.phase(state: .idle, error: .micPermissionDenied), .micDenied)
XCTAssertEqual(RecorderSession.phase(state: .paused, error: nil), .paused)
```

- `dragging never touches the engine` (D3)

```swift
await session.begin(); session.settle(1); session.settle(0)
XCTAssertEqual(engine.state, .recording)
```

- `the app records in the background` (D10)

```swift
XCTAssertTrue((Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []).contains("audio"))
```

- [ ] **Step 1: Write the listed tests** — the engine built as `MemoRecorderEngineTests` builds it (`BufferFeedInput`, `SpySession`, a temp `MemoDraftStore`), with `enqueue` appending to `enqueued` and returning a stub `MemoQueueItem`
- [ ] **Step 2: Run the iphone-xctest suite for `RecorderSessionTests`, watch them fail**
- [ ] **Step 3: Implement the session and container, and add `audio` to `Info.plist`**, to the Behaviour
- [ ] **Step 4: Run the suite, watch them pass** — then `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(memo-screens): recorder session and sheet`

### Task 12: + → Voice memo, and the SavedToast
App: iphone
Phase: 3
Recipe: present-overlay

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Memo/MemoEntry.swift` — the + menu entry and the toast's presenter
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:96-104` — the add-menu `switch` gains `case MemoEntry.rowLabel:`; the shell hosts the recorder and the toast (R1)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — references, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MemoEntryTests.swift`

**Interfaces:**
- Produces:
  - `MemoEntry.rowLabel` is `"Voice memo"`.
  - `MemoEntry.shouldStart(recorderPresented:)` returns `Bool`.
  - `MemoEntry.viewDestination(localId:)` returns `UI2Destination.memoDetail(memoId: "local:<localId>")`.
  - `SavedToastPresenter` — `@MainActor @Observable`. It has `current: SavedToastPresenter.Toast?` (`id: UUID`, `localId: String`), `show(localId:)`, `dismiss()`, `static let visibleFor: Duration = .seconds(4)`, and `expire(id:sleep:) async`.
- Consumes: `RecorderSession`, `RecorderSession.Outcome`, `RecorderSheetContainer(session:onEnd:)` (Task 11); `AppState.shared.startMemoUploads(userId:)`, `nextMemoTitle()`; `SavedToast(message:actionLabel:onView:)` (`MakeReadyUI/SavedToast.swift:20-26`); `UI2HostedOverlay` and `.hostedOverlay(_:)` (`MakeReadyUI/FilterMenuOverlay.swift:567-592`); `UI2ShellModel.push(_:on:)`; `UI2Destination.memoDetail(memoId:)` (Task 9)

**Behaviour:**
- Choosing **Voice memo** closes the add menu. Once its slide-out ends (the `actionMenuPresentation` `onHidden` callback), the shell builds a `RecorderSession` and hands `RecorderSheetContainer` up as a `UI2HostedOverlay` with `.move(edge: .bottom)` over the whole shell. The host keeps only the first presented overlay (`ActionMenuPresentation.swift:9-11`). The session's engine is the live one (`LiveAudioInput`, `MemoTranscriber`, `MemoDraftStore`), its title is `AppState.shared.nextMemoTitle()`, and `enqueue` is `startMemoUploads(userId:)`'s `enqueue`. This is the UI2 shell's sanctioned overlay host, the same one its action and filter menus use: no `.sheet`, no `.fullScreenCover`, no `asyncAfter` (D2, D3)
- While the recorder is presented, `shouldStart` is false, and a second Voice memo selection does nothing (D14)
- A note editor that is open stays mounted under the sheet and keeps its text (D14)
- `.saved(localId)` → remove the overlay, stay on the current tab and page, and `toast.show(localId:)`. `.discarded` and `.failed` → remove the overlay, with no toast (D6, D7, D11)
- The toast is `SavedToast(message: "Saved to Library", actionLabel: "View")`, drawn above the TabBar. `.task(id: toast.current?.id)` calls `expire(id:sleep:)`, which waits `visibleFor` and then dismisses that toast only, so it never uses `asyncAfter` (D6)
- **View** pushes `viewDestination(localId:)` on the current tab with `model.push(_:on: model.tab)` and dismisses the toast (D6, D17)
- The toast's entry and exit use the shell's existing `Motion` tokens (`/transition-review`)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Notes/NoteEntry.swift:1-14` — an add-menu entry
- `iphone/MakeReady/UI2/Shell/UI2Shell.swift:93-108` — the add menu's presentation and `onSelect`

**Tests:**
- `Voice memo is ignored while the recorder is up` (D14)

```swift
XCTAssertTrue(MemoEntry.shouldStart(recorderPresented: false))
XCTAssertFalse(MemoEntry.shouldStart(recorderPresented: true))
```

- `View opens the memo by its local id` (D6, D17)

```swift
XCTAssertEqual(MemoEntry.viewDestination(localId: "q1"), .memoDetail(memoId: "local:q1"))
```

- `the toast hides after 4 s, and a newer toast is not hidden by an older timer` (D6)

```swift
func testToastExpiresOnlyItself() async {
    let toast = SavedToastPresenter()
    toast.show(localId: "a"); let first = toast.current!.id
    toast.show(localId: "b")
    await toast.expire(id: first, sleep: { _ in })
    XCTAssertEqual(toast.current?.localId, "b")
    await toast.expire(id: toast.current!.id, sleep: { XCTAssertEqual($0, .seconds(4)) })
    XCTAssertNil(toast.current)
}
```

- `the add menu still lists Voice memo` (R1)

```swift
XCTAssertTrue(UI2Shell.addMenuActions.contains { $0.label == MemoEntry.rowLabel })
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `MemoEntryTests`, watch them fail**
- [ ] **Step 3: Implement `MemoEntry` and `SavedToastPresenter`, and wire the shell**, to the Behaviour. Update the `addMenuActions` doc comment: Voice memo now opens the recorder (memo-screens D2)
- [ ] **Step 4: Run the suites for `MemoEntryTests` and `UI2ShellModelTests`, watch them pass** — then `swiftlint` from `iphone/`
- [ ] **Step 5: Commit** — `feat(memo-screens): + Voice memo opens the recorder; saved toast`
