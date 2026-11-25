# Video naming — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** After Review's save in the + recorder, one page names the video with three AI suggestions; a retried upload never flashes an old error.

**Architecture:** A stateless endpoint turns a transcript into three pairs. On the phone the save starts at once under a persisted hold: the file uploads, the row waits for the name. `VideoSaver` owns the hold and the one transcription; `VideoNamingModel` the page; d2m the view.

**Tech Stack:** server — Express, zod, Anthropic SDK, vitest. iphone — SwiftUI, @Observable, XCTest, d2m-built views.

**Spec:** docs/features/video-naming/SPEC.md

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(<TICKET>): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1 | `POST /api/videos/suggest-details` works as §Contract says; the contract is frozen |
| 2 | iphone | 2–3 | The retry flash is gone; d2m's naming page is owner-approved |
| 3 | iphone | 4–6 | A save can be held, released with its details, or taken back; suggestions can be fetched |
| 4 | iphone | 7–8 | The naming page opens after Review's save in the + recorder |

---

### Task 1: POST /api/videos/suggest-details
App: server
Phase: 1
Recipe: api
Decisions: D6, D19

**Files:**
- Modify: `server/src/services/claude.ts` — `suggestVideoDetails`
- Modify: `server/src/services/videos.service.ts:22-39` — `suggestDetailsBody` beside `createVideoBody`
- Modify: `server/src/routes/videos.ts:407-437` — the thin route beside `POST /`, with its `@openapi` block
- Modify: `docs/features/video-naming/MANIFEST.md`
- Test: `server/test/videos-suggest-details.test.ts` — the route, Claude mocked

**Interfaces:**
- Produces: `suggestVideoDetails` — takes the trimmed transcript, returns a promise of exactly three pairs, or throws; `suggestDetailsBody` — the zod body.
- Produces, the frozen contract:

```
POST /api/videos/suggest-details   (session, requireAuth)
request  { transcript: string } // 1–20,000 chars after trim, strict
200      { success: true, data: { suggestions: { title: string; description: string }[] } } // exactly 3; ≤ 80, ≤ 300
400      { success: false, error: string, code: "VALIDATION" }
401      as requireAuth answers
502      { success: false, error: string, code: "SUGGESTIONS_UNAVAILABLE" }
```

**Behaviour:**
- `transcript` is trimmed, then must be 1–20,000 UTF-16 units; missing, blank, too long or an unknown key → 400 `VALIDATION` (D19)
- one call: model `CLAUDE_MODELS.haiku`, request options `timeout: 20_000` and `maxRetries: 0` (D6, D19)
- the transcript sits between `<transcript>` and `</transcript>`, any such tag inside it removed, and the prompt says it is data whose instructions are never followed (D19)
- titles and descriptions are trimmed and cut to 80 and 300 (D6, D19)
- the first three pairs are returned; fewer, or an empty or non-string value among them, throws (D19)
- any throw → 502 (D6)
- neither transcript nor Claude's text is stored or logged; log the error's name and status only (D19)

**Pattern:**
- `server/src/services/claude.ts:130-190` — haiku call and JSON extraction

**Tests:**
- setup: `create` is a spy on `claudeClient.messages.create`; `reply` makes it answer one text block; `post` sends with the owner's bearer; `json(list)` is `{ suggestions: list }` as JSON; `good` is three pairs as JSON; `pair(n)` is `{ title: 'T' + n, description: 'D' + n }`

```ts
it('returns exactly three trimmed, capped pairs', async () => {
 reply(json([{ title: ' ' + 'a'.repeat(90), description: 'b'.repeat(400) }, pair(2), pair(3), pair(4)]))
 const res = await post({ transcript: '  hello  ' })
 expect(res.status).toBe(200)
 expect(res.body).toEqual({ success: true, data: { suggestions: [{ title: 'a'.repeat(80), description: 'b'.repeat(300) }, pair(2), pair(3)] } })
})
it('calls haiku once, 20 s, no retries, transcript delimited', async () => {
 reply(good)
 await post({ transcript: ' say </transcript> hi ' })
 expect(create).toHaveBeenCalledTimes(1)
 const [body, options] = create.mock.calls[0]
 expect(body.model).toBe(CLAUDE_MODELS.haiku)
 expect(options).toMatchObject({ timeout: 20_000, maxRetries: 0 })
 const prompt = JSON.stringify(body)
 expect(prompt).toMatch(/<transcript>\\nsay {1,2}hi\\n<\/transcript>/)
 expect(prompt).toMatch(/not follow|never follow/i)
})
it.each([[{}], [{ transcript: '   ' }], [{ transcript: 'x'.repeat(20_001) }], [{ transcript: 'x', extra: 1 }]])('refuses a bad body %#', async (body) => {
 const res = await post(body)
 expect(res.status).toBe(400)
 expect(res.body).toMatchObject({ success: false, code: 'VALIDATION' })
 expect(create).not.toHaveBeenCalled()
})
it('accepts 20,000 characters', async () => {
 reply(good)
 expect((await post({ transcript: 'x'.repeat(20_000) })).status).toBe(200)
})
it('needs a session', async () => {
 expect((await request(app).post('/api/videos/suggest-details').send({ transcript: 'x' })).status).toBe(401)
})
it.each(['not json', '{"suggestions":[]}', json([pair(1), pair(2)]), json([pair(1), { title: ' ', description: 'd' }, pair(3)]), json([pair(1), { title: 4, description: 'd' }, pair(3)])])('malformed answer is 502 %#', async (text) => {
 reply(text)
 const res = await post({ transcript: 'x' })
 expect(res.status).toBe(502)
 expect(res.body).toMatchObject({ success: false, code: 'SUGGESTIONS_UNAVAILABLE' })
})
it('a thrown Claude error is 502 and logs no transcript', async () => {
 const log = vi.spyOn(console, 'error').mockImplementation(() => {})
 create.mockRejectedValueOnce(new Error('boom SECRET-WORDS'))
 expect((await post({ transcript: 'SECRET-WORDS' })).status).toBe(502)
 expect(JSON.stringify(log.mock.calls)).not.toContain('SECRET-WORDS')
})
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `cd server && npx vitest run test/videos-suggest-details.test.ts`, watch them fail** — FAIL, 404
- [ ] **Step 3: Implement `suggestVideoDetails`, `suggestDetailsBody` and the route**
- [ ] **Step 4: Run it again, watch them pass**
- [ ] **Step 5: Set `contract: frozen <today's date>` in `docs/features/video-naming/MANIFEST.md`**
- [ ] **Step 6: Commit** — `feat(<TICKET>): suggest a video's title and description from its transcript`

### Task 2: The upload banner never shows an old failure
App: iphone
Phase: 2
Recipe: ios-error-surface
Decisions: D9, D20

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoUploadController.swift:75-78, 335-365, 420-540, 735-744` — the banner seam, withdrawals, the uncounted suspension
- Modify: `iphone/MakeReady/Services/Video/VideoStreamTransport.swift:27-50` and its `BackgroundWork` — an expired background task throws `suspended`
- Test: `iphone/MakeReadyCaptureTests/VideoUploadControllerTests.swift`

**Interfaces:**
- Produces: `VideoUploadBanner.surface` — gains optional string `itemId`; `VideoUploadBanner.withdraw` — takes `itemId`; `VideoUploadError.suspended`; `URLSessionVideoStreamTransport.failure` — static, takes the error and whether background time expired, returns the error to throw; `AppStateVideoUploadBanner` becomes a final class.

**Behaviour:**
- before any stage of an item runs, when it finishes, and when it is removed, its banner is withdrawn (D20)
- it clears `activeSurfacedError` only while that is the error this item surfaced, by id (D20)
- a refused attach surfaces with `itemId` nil, so the item's next stage does not take it down (D20)
- `suspended` backs off by the next failure's delay, leaves `failures` alone, never surfaces (D20)
- `failure` answers `suspended` only when the time expired and the error is a cancellation (`CancellationError` or `URLError.cancelled`); a plain cancellation still counts (D20)
- build-time risk (F6): the cause is unproven — both candidates (a banner left up as a retry starts; one set while suspended) are failing tests here first; report any already passing (D20)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectScheduleContainer.swift:62` — clearing one's own surfaced error

**Tests:**
- setup: `BannerSpy` gains `events`: "surface:" or "withdraw:" + the item id, "nil" for none. `failed(n)` enqueues one item over an API failing every upload and runs `n` attempts, setting `c`, `api`, `banner`, `id`

```swift
func testARetryStartingWithdrawsItsBanner() async throws {
 try await failed(3)
 var atUpload: String?
 api.onUpload = { _ in atUpload = self.banner.events.last }
 _ = await c.processNext()
 XCTAssertEqual(atUpload, "withdraw:\(id)")
}
func testARemovedItemWithdrawsItsBanner() async throws {
 try await failed(3)
 try c.remove(localId: id)
 XCTAssertEqual(banner.events.suffix(2), ["surface:\(id)", "withdraw:\(id)"])
}
func testASuspendedTransferIsNotCounted() async throws {
 try await failed(5, with: VideoUploadError.suspended)
 XCTAssertEqual(c.pending().first?.failures, 0)
 XCTAssertNotNil(c.pending().first?.nextAttemptAt)
 XCTAssertTrue(banner.shown.isEmpty)
}
func testOnlyAnExpiredCancellationIsASuspension() {
 let f = URLSessionVideoStreamTransport.failure
 XCTAssertEqual(f(CancellationError(), true) as? VideoUploadError, .suspended)
 XCTAssertEqual(f(URLError(.cancelled), true) as? VideoUploadError, .suspended)
 XCTAssertTrue(f(CancellationError(), false) is CancellationError)
 XCTAssertEqual((f(URLError(.timedOut), true) as? URLError)?.code, .timedOut)
}
func testWithdrawLeavesAnotherError() {
 surface("mine", itemId: "a"); banner.withdraw(itemId: "b")
 XCTAssertEqual(state.activeSurfacedError?.message, "mine")
 recordOther("theirs"); banner.withdraw(itemId: "a")
 XCTAssertEqual(state.activeSurfacedError?.message, "theirs")
 surface("mine", itemId: "a"); banner.withdraw(itemId: "a")
 XCTAssertNil(state.activeSurfacedError)
}
func testARefusedAttachSurvivesTheNextStage() async throws {
 // one attach job refused with ActivityActionsError.gone, drained
 XCTAssertEqual(banner.events.filter { $0.hasPrefix("surface") }, ["surface:nil"])
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Watch them fail** — no `withdraw`, no `suspended`
- [ ] **Step 3: Implement the Behaviour; watch them pass**
- [ ] **Step 4: Commit** — `fix(<TICKET>): a retried upload never shows an old error`

### Task 3: d2m builds the video-naming screen; the owner approves
App: iphone
Phase: 2
Recipe: REFERENCE §The project's own rules — the d2m-channel rule in the root CLAUDE.md (request_project_change, then wait_project_change)
Decisions: D1, D3, D5, D11, D12, D16, D18

**Files:**
- Create: `docs/features/video-naming/d2m-requirements.md` — the d2m brief, ≤ 8,000 characters
- Create (by d2m): `iphone/MakeReadyUI/Screens/Library/VideoNamingScreen.swift`, fixtures, registry cases
- Modify (by d2m): `iphone/MakeReadyUI/AISuggestionsBlock.swift`, `SuggestionRows.swift`, `SuggestionRow.swift` — additive pair rows, index pick and `empty`
- Test: `iphone/MakeReadyCaptureTests/VideoNamingScreenTests.swift`

**Interfaces:**
- Produces: `VideoNamingScreen` — inputs `title`, `titlePlaceholder`, `description` (strings), `aiState` (`AISuggestionsBlock.State`), `promptCopy` (string), `suggestions` (title + description pairs), `onTitleChange` and `onDescriptionChange` (string), `onPick` (index), `onRegenerate`, `onSave`, `onBack`. Spelling differences: `d2m-requirements.md` §As built.
- Produces: `AISuggestionsBlock.State.empty` — raw string "empty".

**Behaviour:**
- header "Name your video" with back and the C-159 check; Title (C-045/C-046 single-line); Description (multi-line); C-051 below (D1)
- rows are at most three, title on the first line and description below; a tap answers the row's index (D3)
- block states `generating`, `list`, `regenerating`, `prompt` ("Couldn't get suggestions", link "AI suggestions"), `empty` ("No speech to suggest from", no link); the block is hidden in none (D5, D16)
- fields start empty; the caller gives the title placeholder (D18)
- the focused field stays above the keyboard (D1)
- build-time risk (F2): C-051 takes string rows, has no empty state, draws its own rows, picks by title — pair rows, index pick and `empty` are additive; shared-edit-field callers render unchanged (D12)
- captures are silent, text seeded (D11)
- the owner approves the captures before any wiring; an unattended build parks here as `human-step` (D12, F8)

**Tests:**
- `empty` is added, the four stay

```swift
func testTheBlockHasAnEmptyState() {
 XCTAssertEqual(["prompt", "generating", "list", "regenerating", "empty"].compactMap(AISuggestionsBlock.State.init(rawValue:)).count, 5)
}
```

- [ ] **Step 1: Write `testTheBlockHasAnEmptyState`, watch it fail** — four
- [ ] **Step 2: Write and commit `d2m-requirements.md`** — `docs(<TICKET>): d2m requirements for the naming page` (d2m reads it from the branch: this task's one extra commit)
- [ ] **Step 3: `request_project_change`, subject `new:video-naming`, `screen` (that doc, "Video naming", from `edit-text-single-field`), references C-051 and C-078; `wait_project_change` until done**
- [ ] **Step 4: Check the additive rule: no existing shared-edit-field capture changed; the test passes**
- [ ] **Step 5: Commit the test and §As built** — `feat(<TICKET>): the naming page view`; report the capture paths

### Task 4: The queue holds an item for naming
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D4, D7, D8, D13, D15

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoUploadController.swift:57-125, 200-260, 335-510` — item keys, hold, scheduling, stage writes, create
- Modify: `iphone/MakeReady/Services/Video/VideoSaver.swift:55-77` — the `VideoSaveQueue` protocol
- Test: `iphone/MakeReadyCaptureTests/VideoUploadControllerTests.swift`, `VideoRecorderSaveTests.swift`

**Interfaces:**
- Produces: `VideoQueueItem.description` — optional string; `VideoQueueItem.namingHold` — optional bool; both encoded.
- Produces: `VideoUploadController.enqueue` — gains `description` (optional string, default nil) and `namingHold` (bool, default false); `endNamingHold` — takes `localId`, `title` (nil keeps the item's), `description` (optional), throws when the manifest cannot be written, ignores an unknown or released id; `heldIds` — the held local ids. All on `VideoSaveQueue`, with `remove`.
- Produces: `VideoCreateRequest.description` — optional string, passed to `createVideoRecord`.

**Behaviour:**
- a held item runs the `queued` stage and stops at `uploading`: neither `flush` nor `processNext` picks it there, it adds no wake-up, later items go on (D13)
- the transcript wait neither delays a held file upload nor ends with it; once released the create waits for `transcriptDue` as today (D13, D15)
- a release or transcript landing during a transfer is never overwritten: stage and failure writes follow the order below (D13, D15). An unheld item still ends its wait as its run begins, as today
- ending the hold sets both, clears it and starts or wakes the flush (D13)
- the create carries the description, omitted when nil (D4, D7)
- a manifest without the new keys decodes to no description and no hold (F4, D13)

```
fresh = manifest on disk for localId // gone → ItemRemoved
fresh.stage, failures, polls, nextAttemptAt, streamUid, serverId = the stage's values
persist(fresh) // everything else is the disk's
```

**Tests:**
- setup: `setUp` makes `api` and `c`; `held` enqueues localId "H", title "Video 1", `namingHold: true`; `spoken` is a transcript

```swift
func testAHeldItemUploadsItsFileButIsNotCreated() async throws {
 try held()
 let other = try c.enqueue(exported(), title: "Other", attach: nil)
 await c.flush()
 XCTAssertEqual(api.uploads.count, 2)
 XCTAssertEqual(api.created.map(\.title), ["Other"])
 XCTAssertNil(c.queued(localId: other.localId))
 XCTAssertEqual(c.heldIds, ["H"])
}
func testEndingTheHoldCreatesWithTheDetails() async throws {
 try held(); await drain(c)
 try c.endNamingHold(localId: "H", title: "Hope", description: "On hope"); await drain(c)
 XCTAssertEqual(api.created.map(\.title), ["Hope"])
 XCTAssertEqual(api.created.first?.description, "On hope")
 XCTAssertEqual(api.uploads.count, 1)
}
func testAReleaseAndATranscriptDuringTheTransferAreKept() async throws {
 try held(transcriptHold: 600)
 api.onUpload = { _ in
  self.c.supplyTranscript(spoken, forLocalId: "H")
  try self.c.endNamingHold(localId: "H", title: "Hope", description: nil)
 }
 await drain(c)
 XCTAssertEqual(api.created.map(\.title), ["Hope"])
 XCTAssertEqual(api.created.first?.transcript, spoken)
 XCTAssertNil(api.created.first?.description)
}
func testAReleaseDuringAFailingTransferIsKept() async throws {
 // the first upload releases "H" as "Hope", then fails
 _ = await c.processNext()
 XCTAssertEqual(c.queued(localId: "H")?.title, "Hope")
 XCTAssertEqual(c.heldIds, [])
 XCTAssertEqual(c.queued(localId: "H")?.failures, 1)
}
func testAManifestWithoutTheNewKeysDecodes() throws {
 // "H" queued unheld, its JSON then stripped of both new keys
 XCTAssertNotNil(c.queued(localId: "H"))
 XCTAssertNil(c.queued(localId: "H")?.description)
 XCTAssertEqual(c.heldIds, [])
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Watch them fail** — no `namingHold`
- [ ] **Step 3: Implement the Behaviour; watch them pass**
- [ ] **Step 4: Commit** — `feat(<TICKET>): hold a queued video until it is named`

### Task 5: The saver starts, releases and takes back a held save
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D4, D5, D8, D13, D15

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoSaver.swift` — held saves, one transcription, finish and cancel
- Modify: `iphone/MakeReady/Services/Video/VideoDraftStore.swift:200-240` — clear a saving mark
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift`

**Interfaces:**
- Consumes: `endNamingHold`, `heldIds`, `remove`, `enqueue` with `description` and `namingHold` (Task 4).
- Produces: `VideoSave.description` — optional string; `VideoSave.namingHold` — optional bool; both `var`, default nil.
- Produces on `VideoSaving`: `automaticTitle` — takes the local id (the draft id's string), returns the save's title or nil; `namingTranscript` — takes the local id, async, returns an optional transcript; `finishNaming` — takes the local id, `title`, `description`, throws with the hold kept; `cancelNaming` — takes the local id, throws.
- Produces: `VideoDraftStore.clearSaving` — takes a draft, removes its save mark, throws.
- Produces: `VideoSaver.init` gains `transcribeClips` — the shape of `VideoTranscriber.transcribe(clips:window:timeout:)`, live by default.

**Behaviour:**
- `finishNaming` trims both; an empty title keeps the automatic one (nil to `endNamingHold`), an empty description saves none (D4)
- it rewrites the save mark (title, description, no hold) first, then ends the queue item's hold; with no item yet, the enqueue that follows uses the latest mark, not the one captured at start (D13)
- a held draft outlives its enqueue; it is discarded once naming, the enqueue and the clip transcription (which reads its files) have all ended (D13, D15)
- a held save with no editor transcript transcribes the kept clip once from `start`, outliving the recorder, timeout its kept duration; landing before the enqueue it goes along, later it is supplied; `transcribe(video)` never runs (D15)
- `namingTranscript` answers the editor's transcript with corrections, else that one transcription; blank text is nil (D5, D15)
- `cancelNaming` clears the save mark (a failure throws, nothing changed), cancels transcription and export, removes any queue item, and leaves the draft, layers and transcript as they were (D13)
- a save started again for that draft waits for the cancelled job to end, and the cancelled job's end never removes its successor (D13)
- a failed held export reports as today; Retry uses the latest mark (D13)
- `resume` ends the hold of every held save and every `heldIds` item this saver did not itself start, as "Video N", and uploads each once (D8, D13)
- unheld saves behave exactly as today (D13)

**Tests:**
- setup: `heldSave` is `plusSave` with `namingHold = true`; `QueueSpy` records description, hold, ended holds and removals; `makeSaver` takes `clipTranscript`, counting into `clipTranscriptions`; `startHeld(transcript)` starts a held save of `edited(transcript)`, setting `queue`, `saver`, `draft`, `id`; `startHeldExporting` the same, export held open; `realQueue` is a `VideoUploadController` over a `FakeVideoAPI`

```swift
func testACheckedNameReachesTheQueueAndTheDraftGoes() async throws {
 try startHeld(heard); await saver.settled()
 XCTAssertEqual(queue.items.first?.namingHold, true)
 XCTAssertTrue(drafts.exists(draft))
 XCTAssertEqual(saver.automaticTitle(id), "Video 1")
 try saver.finishNaming(id, title: " Hope ", description: "  "); await saver.settled()
 XCTAssertEqual(queue.ended.map(\.title), ["Hope"])
 XCTAssertEqual(queue.ended.map(\.description), [nil])
 XCTAssertFalse(drafts.exists(draft))
}
func testANameCheckedDuringTheExportIsTheOneEnqueued() async throws {
 try await startHeldExporting(heard)
 try saver.finishNaming(id, title: "", description: " d ")
 exporter.release(); await saver.settled()
 XCTAssertEqual(queue.items.map(\.title), ["Video 1"])
 XCTAssertEqual(queue.items.map(\.description), ["d"])
 XCTAssertEqual(queue.items.first?.namingHold, false)
 XCTAssertFalse(drafts.exists(draft))
}
func testBackLeavesNoVideoAndTheDraftIntact() async throws {
 for exporting in [true, false] {
  if exporting { try await startHeldExporting(heard) } else { try startHeld(heard); await saver.settled() }
  try saver.cancelNaming(id)
  XCTAssertEqual(queue.removed, exporting ? [] : [id])
  XCTAssertEqual(drafts.current(draft)?.layers, layers)
  XCTAssertEqual(drafts.current(draft)?.transcript, heard)
  XCTAssertTrue(drafts.saving().isEmpty); XCTAssertTrue(saver.saving.isEmpty)
  _ = try saver.start(heldSave, of: .draft(draft))
  exporter.release(); await saver.settled()
  XCTAssertEqual(queue.items.count, exporting ? 1 : 2)
 }
}
func testTheClipIsTranscribedOnceAndHandedOver() async throws {
 try startHeld(nil, clipTranscript: heard)
 let spoken = await saver.namingTranscript(id)
 XCTAssertEqual(spoken, heard)
 try saver.finishNaming(id, title: "", description: ""); await saver.settled()
 XCTAssertEqual(queue.items.compactMap(\.transcript) + queue.supplied.compactMap { $0 }, [heard])
 XCTAssertEqual(clipTranscriptions, 1); XCTAssertEqual(transcriptTimeouts, [])
 XCTAssertFalse(drafts.exists(draft))
}
func testTheEditorsCorrectedTranscriptIsReusedAndBlankIsNone() async throws {
 try startHeld(heard)
 let spoken = await saver.namingTranscript(id)
 XCTAssertEqual(spoken?.text, "John"); XCTAssertEqual(clipTranscriptions, 0)
 try startHeld(nil, clipTranscript: VideoTranscript(text: "  ", segments: []))
 let none = await saver.namingTranscript(id)
 XCTAssertNil(none)
}
func testARelaunchWhileHeldUploadsOnceAsVideoN() async throws {
 for queuedFirst in [false, true] {
  // a held "Video 1" mark on disk, realQueue holding it too when queuedFirst; a new saver
  saver.resume(); await saver.settled(); await drain(queue)
  XCTAssertEqual(api.created.map(\.title), ["Video 1"])
  XCTAssertFalse(drafts.exists(draft))
 }
}
func testResumeLeavesALiveNamingAloneAndEndsAnOrphanHold() async throws {
 // realQueue already holding "orphan"; a held save started and settled
 saver.resume(); await saver.settled()
 XCTAssertEqual(queue.heldIds, [id])
}
func testAnOldSaveMarkDecodes() throws {
 // `json` is `plusSave` encoded with both new keys removed
 XCTAssertEqual(try JSONDecoder().decode(VideoSave.self, from: json), plusSave)
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Watch them fail** — no `finishNaming`
- [ ] **Step 3: Implement the Behaviour; watch them pass**
- [ ] **Step 4: Commit** — `feat(<TICKET>): a save that waits for its name`

### Task 6: The suggestions Action and the naming page's model
App: iphone
Phase: 3
Recipe: ios-error-surface
Decisions: D3, D4, D5, D6, D15, D16, D17, D18

**Files:**
- Modify: `iphone/MakeReady/State/Actions/VideoActions.swift:138-175` — `suggestDetails`
- Modify: `iphone/MakeReady/Services/Video/VideoUploadController.swift:630-690` — `VideoTranscriptLimits.prefix` loses `private`
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoNamingModel.swift` — the page's logic
- Test: `iphone/MakeReadyCaptureTests/VideoNamingModelTests.swift`, `VideoActionsLibraryTests.swift`

**Interfaces:**
- Consumes: `POST /api/videos/suggest-details` (Task 1).
- Produces: `VideoDetailSuggestion` — decodable, equatable, `title` and `description`; `VideoActions.suggestDetails` — takes the transcript text, async, returns the suggestions, throws.
- Produces: `VideoNamingModel` — init takes `titlePlaceholder`, `transcript` (async, returns an optional string), `suggest` (async throwing, string to suggestions), `save` (takes title and description, returns whether it went through) and `back`; reads `title`, `description`, `block` (`VideoNamingModel.Block`: `generating`, `list`, `regenerating`, `prompt`, `empty`), `promptCopy`, `suggestions`; calls `open`, `setTitle`, `setDescription`, `pick` (index), `regenerate`, `saveTapped`, `backTapped`, `leave`.

**Behaviour:**
- `open` shows `generating`, waits for the transcript, then asks; nil or blank → `empty` with "No speech to suggest from" (D5)
- the text sent is cut to 20,000 UTF-16 units (D15)
- an answer shows at most three rows in `list`; `pick` replaces both fields and the block stays; an index out of range does nothing (D3, D17)
- `regenerate`: from `list` → `regenerating`, rows still pickable; from `prompt` → `generating`; otherwise nothing (D3, D16)
- a failed first ask → `prompt` with "Couldn't get suggestions"; a failed regenerate → `list` with the rows it had; both log only, no `recordError` (D16)
- a 401 also shows `prompt`; sign-out is the app's rule (D16)
- a new list never changes the fields; an answer after `leave`, the check or Back, or after a newer request, is dropped (D17)
- typing is cut to 80 and 300 characters; both fields start empty (D18)
- `saveTapped` during a save or after one that went through does nothing; after a failed one it saves again (D17)

**Tests:**
- setup: `make` builds a model with a scripted transcript and a `SuggestSpy` whose calls are answered or failed by the test; `settle` yields until idle; `three` is three pairs

```swift
func testSuggestionsLoadAndAPickFillsBoth() async {
 let m = make(transcript: "hello"); m.open(); await settle()
 XCTAssertEqual(m.block, .generating)
 spy.answer(three); await settle()
 XCTAssertEqual(m.block, .list); XCTAssertEqual(m.suggestions, three); XCTAssertEqual(m.title, "")
 m.setTitle("mine"); m.pick(1); m.pick(7)
 XCTAssertEqual(m.title, three[1].title); XCTAssertEqual(m.description, three[1].description)
 m.setTitle("after"); m.regenerate(); await settle()
 XCTAssertEqual(m.block, .regenerating); XCTAssertEqual(m.suggestions, three)
 spy.answer(Array(three.reversed())); await settle()
 XCTAssertEqual(m.title, "after"); XCTAssertEqual(m.suggestions, Array(three.reversed()))
}
func testNoTranscriptIsEmpty() async {
 for text in [nil, "  \n"] as [String?] {
  let m = make(transcript: text); m.open(); await settle()
  XCTAssertEqual(m.block, .empty); XCTAssertEqual(m.promptCopy, "No speech to suggest from")
  m.regenerate(); await settle()
  XCTAssertTrue(spy.asked.isEmpty)
 }
}
func testFailuresFollowD16() async {
 let m = make(transcript: "hello"); m.open(); await settle()
 spy.fail(URLError(.timedOut)); await settle()
 XCTAssertEqual(m.block, .prompt); XCTAssertEqual(m.promptCopy, "Couldn't get suggestions")
 m.regenerate(); await settle()
 XCTAssertEqual(m.block, .generating)
 spy.answer(three); await settle(); m.regenerate(); await settle()
 spy.fail(URLError(.timedOut)); await settle()
 XCTAssertEqual(m.block, .list); XCTAssertEqual(m.suggestions, three)
}
func testAnAnswerAfterLeavingIsDropped() async {
 let m = make(transcript: "hello"); m.open(); await settle()
 m.leave()
 spy.answer(three); await settle()
 XCTAssertTrue(m.suggestions.isEmpty)
}
func testCapsAndOneSave() async {
 let m = make(transcript: String(repeating: "x", count: 20_500)); m.open(); await settle()
 XCTAssertEqual(spy.asked.first?.utf16.count, 20_000)
 m.setTitle(String(repeating: "t", count: 90)); m.setDescription(String(repeating: "d", count: 310))
 XCTAssertEqual(m.title.count, 80); XCTAssertEqual(m.description.count, 300)
 saveSucceeds = false; m.saveTapped(); saveSucceeds = true; m.saveTapped(); m.saveTapped()
 XCTAssertEqual(saves.count, 2)
}
func testSuggestDetailsPostsTheTranscript() async throws {
 api.stub("POST", "/api/videos/suggest-details", json: #"{"success":true,"data":{"suggestions":[{"title":"A","description":"B"}]}}"#)
 let answer = try await actions.suggestDetails(transcript: "hello")
 XCTAssertEqual(answer, [VideoDetailSuggestion(title: "A", description: "B")])
 XCTAssertEqual(api.calls.last?.body?["transcript"] as? String, "hello")
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Watch them fail** — no `VideoNamingModel`
- [ ] **Step 3: Implement the Behaviour; watch them pass**
- [ ] **Step 4: Commit** — `feat(<TICKET>): the naming page's model and its suggestions`

### Task 7: The recorder's naming phase
App: iphone
Phase: 4
Recipe: test-driven-development
Decisions: D2, D7, D8, D13, D14

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:56-68, 225-330, 800-970, 1015-1045` — the `naming` phase, save, check, back, background
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift:310-340` — `.live` passes the suggest call
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift`, `VideoRecorderModelTests.swift`

**Interfaces:**
- Consumes: `VideoNamingModel` (Task 6); `automaticTitle`, `namingTranscript`, `finishNaming`, `cancelNaming`, `VideoSave.namingHold` (Task 5).
- Produces: `VideoRecorderModel.Phase.naming`; `VideoRecorderModel.naming` — the open `VideoNamingModel` or nil; `namingHidden` — the host has taken the page off; init gains `suggest` (async throwing, string to suggestions), default returning none.

**Behaviour:**
- `save` from `review` with entry `plusMenu` starts a held save and moves to `naming`; from `paused`, or with a lesson entry, it is exactly as today (D2, D14)
- an import not yet a draft is adopted through `draftToEdit` before the save starts; a failure reports "Couldn't save your video" and stays in Review (D13)
- the save starts first, nothing waits for the upload, playback stops (D7)
- check: `finishNaming`, then the recorder closes and `onFinished` runs; a throw reports "Couldn't save your video" and the page stays (D13)
- Back: `cancelNaming`, then `review`, playing, with clips, layers, transcript, filter and trim as they were; a throw reports "Couldn't go back" and the page stays (D2, D13)
- going to the background or closing the recorder while naming ends it with empty details, calls `leave`, and closes the recorder through `onFinished`; a throw is logged only: the next launch ends the hold (D8)
- while naming, edit, retake, scrub, play, save and `becameActive` do nothing; the view under it shows Review (D13)

**Tests:**
- setup: `toReview` records, or imports a 10 s clip, and settles in Review over a fresh `QueueSpy` and saver; `toNaming` then saves and settles the saver; both set `m`, `queue`, `saver`, `finished`

```swift
func testAPlusSaveFromReviewOpensNaming() async {
 await toNaming()
 XCTAssertEqual(m.screenState.phase, .naming); XCTAssertEqual(m.naming?.titlePlaceholder, "Video 1")
 XCTAssertFalse(m.isClosed); XCTAssertEqual(finished, 0)
 XCTAssertFalse(m.canEdit); m.requestRetake(); XCTAssertNil(m.confirm)
 m.naming?.setTitle("Hope"); m.naming?.saveTapped()
 XCTAssertEqual(queue.ended.map(\.title), ["Hope"])
 XCTAssertTrue(m.isClosed); XCTAssertEqual(finished, 1)
}
func testALessonSaveNeverOpensNaming() async {
 await toReview(entry: .lesson(versionId: "v", activityId: nil)); await m.save()
 XCTAssertNil(m.naming); XCTAssertTrue(m.isClosed); XCTAssertEqual(queue.items.first?.namingHold, false)
}
func testBackReturnsToReviewWithEverything() async {
 for imported in [false, true] {
  await toNaming(imported: imported)
  m.naming?.backTapped()
  XCTAssertEqual(m.screenState.phase, .review); XCTAssertEqual(m.reviewDuration, imported ? 10 : 4)
  XCTAssertEqual(queue.removed.count, 1); XCTAssertTrue(drafts.saving().isEmpty); XCTAssertTrue(m.canEdit)
  await m.playerSettled()
  XCTAssertTrue(FileManager.default.fileExists(atPath: player.loads.last!.clips[0].path))
  await m.save()
  XCTAssertEqual(m.screenState.phase, .naming)
 }
}
func testBackgroundOrCloseEndsNamingAsVideoN() async {
 for leave in [{ (m: VideoRecorderModel) in m.backgrounded() }, { $0.closeTapped() }] {
  await toNaming(); m.naming?.setTitle("typed")
  leave(m); await saver.settled()
  XCTAssertTrue(m.isClosed); XCTAssertNil(m.confirm)
  XCTAssertEqual(queue.ended.map(\.title), [nil]); XCTAssertTrue(drafts.saving().isEmpty)
 }
}
func testAFailedCheckStaysOnThePage() async {
 await toNaming()
 queue.endError = CocoaError(.fileWriteOutOfSpace); m.naming?.saveTapped()
 XCTAssertEqual(reports, ["Couldn't save your video"]); XCTAssertEqual(m.screenState.phase, .naming)
 queue.endError = nil; m.naming?.saveTapped()
 XCTAssertTrue(m.isClosed)
}
```

- [ ] **Step 1: Write the tests; existing + saves made from Review go through the check**
- [ ] **Step 2: Watch them fail** — no `naming`
- [ ] **Step 3: Implement the Behaviour; watch them pass**
- [ ] **Step 4: Commit** — `feat(<TICKET>): name the video after Review's save`

### Task 8: The naming page over the recorder
App: iphone
Phase: 4
Recipe: present-overlay
Decisions: D1, D2, D3, D5, D11, D16, D18

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoNamingContainer.swift` — d2m's screen over the model
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoNamingPresentation.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift:75-80` — mounts it after `videoEditorPresentation`
- Test: `iphone/MakeReadyCaptureTests/VideoNamingContainerTests.swift`

**Interfaces:**
- Consumes: `VideoNamingScreen` and `AISuggestionsBlock.State.empty` (Task 3, spelling in `d2m-requirements.md` §As built); `VideoNamingModel` (Task 6); `VideoRecorderModel.naming`, `namingHidden` (Task 7).
- Produces: `VideoNamingContainer.blockState` — static, takes a `VideoNamingModel.Block`, returns the `AISuggestionsBlock.State` of the same name.

**Behaviour:**
- every input and callback is the model's (D1, D3, D18)
- it slides in and out with the editor's Motion tokens; on the check the recorder slides away with the page on it (D1)
- the keyboard lifts it once only (D1)
- the accessibility escape on the page is Back (D2)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Video/VideoEditorPresentation.swift:15`

**Tests:**
- each block names the view's state

```swift
func testEveryBlockMapsToTheViewsState() {
 let blocks: [VideoNamingModel.Block] = [.generating, .list, .regenerating, .prompt, .empty]
 XCTAssertEqual(blocks.map(VideoNamingContainer.blockState).map(\.rawValue), ["generating", "list", "regenerating", "prompt", "empty"])
}
```

- [ ] **Step 1: Write the listed test**
- [ ] **Step 2: Watch them fail** — no `VideoNamingContainer`
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the suite, then `/transition-review` and `swiftlint` from `iphone/` on the diff**
- [ ] **Step 5: Commit** — `feat(<TICKET>): the naming page over the recorder`
