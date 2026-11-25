# video-activity-basics — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** A video activity on iPhone shows its picture, plays on a tap, offers Replace · Delete on a hold (removing it from the lesson or deleting the video everywhere), and a recording saves with the header's purple check.

**Architecture:** The server widens the thumbnail and adds `versionUseCount`, then the contract freezes. d2m changes its views from the SPEC, then the iPhone models and containers wire onto them.

**Tech Stack:** server — Express, Prisma, vitest, TypeScript fixtures. iphone — Swift 5, SwiftUI, @Observable models, AVFoundation, XCTest (MakeReadyCaptureTests), d2m-built MakeReadyUI views.

**Spec:** `docs/features/video-activity-basics/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(video-activity-basics): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–3 | Lesson thumbnails fall back to the video's still, `versionUseCount` is returned, the posterless fixture video exists, the contract is frozen |
| 2 | iphone | 4 | d2m has delivered every changed view; the app still builds on them |
| 3 | iphone | 5–6 | The video page shows its picture, follows one still arriving, and plays inline |
| 4 | iphone | 7–9 | Both deletes work from the hold menu, and Review saves with the header check |

---

### Task 1: Lesson thumbnails fall back to the video's still
App: server
Phase: 1
Recipe: test-driven-development
Decisions: D8

**Files:**
- Modify: `server/src/services/next-study-thumbnail.ts` — the order
- Test: `server/src/services/__tests__/next-study-thumbnail.test.ts`

**Interfaces:**
- Produces: `thumbnailFromDocument` — unchanged signature (document, `MediaMap`), returns a URL string or null.

**Behaviour:**
- the order is background image, poster media, then `media[content.videoId].posterUrl`, else null (D8)
- an id naming a `kind: 'video'` entry yields that entry's `posterUrl`, never its `url`; when it has none, the next source is tried (D8)

**Tests:**
- the still, the order, never a stream (D8). `thumb` (videoId, poster id, background id) is a video page's thumbnail over the file's `media` plus `vid` (kind video, a stream url, posterUrl `still`) and `bare` (kind video, a stream url only)

```ts
it('falls back to the video still', () => {
  expect(thumb('vid')).toBe(still)
})
it('the poster wins over the still', () => {
  expect(thumb('vid', 'poster')).toBe('https://img.test/poster.jpg')
  expect(thumb('vid', 'poster', 'bg')).toBe('https://img.test/bg.jpg')
})
it('never returns a stream url', () => {
  expect(thumb('bare')).toBeNull()
  expect(thumb('bare', 'vid')).toBe(still)
  expect(thumb('bare', null, 'vid')).toBe(still)
  expect(thumb('vid', null, 'bare')).toBe(still)
})
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `npx vitest run src/services/__tests__/next-study-thumbnail.test.ts` in `server/`, watch them fail**
- [ ] **Step 3: Implement the order**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): lesson thumbnails fall back to the video still`

### Task 2: `GET /api/videos/:id` returns `versionUseCount`
App: server
Phase: 1
Recipe: api
Decisions: D5, D7, D11

**Files:**
- Modify: `server/src/services/content-media.service.ts` — `videoVersionUseCount`
- Modify: `server/src/services/videos.service.ts:209` — the `versionUseCount` wrapper beside `lessonUseCount`
- Modify: `server/src/routes/videos.ts:629-736` — the field in the answer and in the OpenAPI text
- Test: `server/test/content-media.test.ts`
- Test: `server/test/videos-library-http.test.ts:46`

**Interfaces:**
- Produces: `videoVersionUseCount` — takes a Prisma client and a video id; `versionUseCount` — takes a video id; both return a promise of a number.
- Produces, the frozen response (SPEC §Contract), additive:

```ts
// GET /api/videos/:id → 200 { success: true, data }
data.lessonUseCount: number   // unchanged
data.versionUseCount: number  // new
```

**Behaviour:**
- the count is of activity ROWS, in versions of every status, whose `documentMediaRefs` name the video by id or by any Media row linked to it (D11)
- the rows read are those whose `activityKey` holds an `ACTIVITY` usage of the video's Media; no table-wide document scan (D11)
- a row naming another video is not counted (D11)
- `lessonUseCount` and DELETE keep their current behaviour (D5, D7)

**Pattern:**
- `server/src/services/content-media.service.ts:69-86` — resolving document refs through Media
- `server/src/services/__tests__/videos-create.test.ts` — doubling the Cloudflare service

**Tests:**
- rows in every version, rows naming another video, and how the count predicts DELETE; mock the Cloudflare service's `deleteVideo` to `{ success: true }` so no request leaves the machine (D7, D11). Helpers: `use` (key, status, media id) seeds through `seedActivity`, syncs the key's usage, returns the row; `newVideo` returns `v` and its Media `m`; `counts` GETs the video as the leader → [lessonUseCount, versionUseCount]

```ts
it('versionUseCount counts rows in every version that name the video', async () => {
  const { v, m } = await newVideo()
  const draft = await use('vu1', 'DRAFT', m.id)
  expect(await counts(v)).toEqual([1, 1])
  await use('vu1', 'PUBLISHED', m.id)
  expect(await counts(v)).toEqual([1, 2])
  // the draft names it by video id
  await prisma.contentActivity.update({ where: { id: draft.id }, data: { document: { ...EXAMPLE_TEXT, content: { type: 'video', videoId: v } } } })
  expect(await counts(v)).toEqual([1, 2])
})
it('a version that names another video is not counted', async () => {
  const a = await newVideo(), b = await newVideo()
  await use('vu2', 'DRAFT', a.m.id)
  await use('vu2', 'PUBLISHED', b.m.id)
  expect(await counts(a.v)).toEqual([1, 1])
})
it('after the draft row goes, DELETE answers as the count predicted', async () => {
  const auth = bearer(w.leader.token)
  for (const [key, published, status] of [['vu3', false, 200], ['vu4', true, 409]] as const) {
    const { v, m } = await newVideo()
    const row = await use(key, 'DRAFT', m.id)
    if (published) await use(key, 'PUBLISHED', m.id)
    await request(app).delete(`/api/content-activities/${row.id}`).set('Authorization', auth)
    expect((await request(app).delete(`/api/videos/${v}`).set('Authorization', auth)).status).toBe(status)
  }
})
```

- in `videos-library-http.test.ts`: an unused video (D11)

```ts
expect(one.body.data).toHaveProperty('versionUseCount', 0)
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `npx vitest run test/content-media.test.ts test/videos-library-http.test.ts` in `server/`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): versionUseCount on a video`

### Task 3: The posterless fixture video, and the freeze
App: server
Phase: 1
Recipe: test-driven-development
Decisions: D8, D11

**Files:**
- Modify: `server/fixtures/screens/activities-editor.ts` — a second video activity with its own Video and Media rows
- Test: `server/fixtures/__tests__/activities-screens.db.test.ts` — its shape and counts
- Modify: `docs/features/video-activity-basics/MANIFEST.md` — `contract: frozen <date>`

**Interfaces:**
- Consumes: `videoVersionUseCount`, `thumbnailFromDocument`, `buildMediaMap`.
- Produces: activity key `fixture-editor-8` in the editor lesson's draft, Video `fixtureId('video', 2_100_010)` titled "Video 2", Media `fixtureId('media', 2_100_013)`.

**Behaviour:**
- the activity is last in the draft, has no `posterMediaId`, and its Media row has `SAMPLE_POSTER_URL` as its still (D8)
- the video is ready, named by this one draft row only, with its `ACTIVITY` usage row present so both counts are 1 (D11)
- the player layer and `base.ts` are unchanged (D11)

**Pattern:**
- `server/fixtures/activity-samples.ts:32-63` — a Video with its Media row

**Tests:**
- D8's and D11's data

```ts
it('the editor draft ends with a posterless, draft-only video', async () => {
  await runScenario('activities-editor', 'full')
  const acts = await db.prisma.contentActivity.findMany({
    where: { lessonVersionId: ids.activitiesEditor.lessonVersionId }, orderBy: { position: 'asc' },
  })
  const last = acts.at(-1)!, doc = last.document as any, id = doc.content.videoId
  expect([last.activityKey, last.kind, doc.content.posterMediaId]).toEqual(['fixture-editor-8', 'video', null])
  const map = await db.prisma.$transaction((tx: any) => buildMediaMap(tx, [doc]))
  expect(thumbnailFromDocument(doc, map)).toBe(SAMPLE_POSTER_URL)
  expect(await Promise.all([videoActivityUseCount(db.prisma, id), videoVersionUseCount(db.prisma, id)])).toEqual([1, 1])
})
```

- [ ] **Step 1: Write the listed test**
- [ ] **Step 2: Run `npx vitest run fixtures/__tests__/activities-screens.db.test.ts` in `server/` with `FIXTURES_TEST_DATABASE_URL` set, watch it fail**
- [ ] **Step 3: Add the rows to `activities-editor.ts`**
- [ ] **Step 4: Run `npx vitest run fixtures`, watch it pass** — PASS
- [ ] **Step 5: Set `contract: frozen <today's date>` in the manifest**
- [ ] **Step 6: Commit** — `feat(video-activity-basics): posterless fixture video; contract frozen`

### Task 4: d2m changes the editor, the recorder and C-066
App: iphone
Phase: 2
Recipe: the d2m-channel rule in the root CLAUDE.md — check_project_change, then request_project_change with references, then wait_project_change
Decisions: D1–D6, D9–D12, D14, D17, D18

**Files:**
- Create: `docs/features/video-activity-basics/d2m-requirements.md` — the d2m brief, at most 8 000 characters, from this task and its SPEC rows
- Modify (by d2m, never by hand): `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift`, `iphone/MakeReadyUI/Screens/Library/VideoRecorderScreen.swift`, `iphone/MakeReadyUI/ActionMenuOverlay.swift`, and their fixtures
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorScreenContractTests.swift` — the delivered defaults

**Interfaces:**
- Produces (requested; `ActivitiesEditorScreen.State`): `deleteEverywhereEnabled` (Bool, default false), `deleteEverywhereNote` (String, default ""), `reviewSaving` (Bool, default false). The page image is the existing `readOnlyPosterURL`.
- Produces (requested; `ActivitiesEditorScreen`): `videoLayer` (optional CALayer, default nil), callbacks defaulting to no-ops: `onVideoTap`, `onVideoMenu` (fires as the hold menu opens), `onReplaceVideo` (kept), `onDelete` (fires as the confirm opens), `onRemoveFromLesson`, `onDeleteEverywhere`, `onReviewSave`.
- Produces (requested; `VideoRecorderScreen`): `onSave`, default no-op.
- Produces (requested; `ActionMenuOverlay.ActionItem`): `enabled` (Bool, default true), `subtitle` (String, default "").
- Where d2m's names differ, they win (F5). Record them in `d2m-requirements.md` under a last heading, "Delivered"; Tasks 5–9 read it.

**Behaviour:**
- a video page draws the still with no title; without one, the canvas background and a centred "Processing…" (D1)
- `videoLayer` draws over the still in the page's frame, hit-testing off; nil draws nothing, and captures pass nil (D3, D9, D12)
- a tap fires `onVideoTap`; a 0.5 s press opens C-066 with Replace then Delete, and no tap follows it (D2)
- Delete opens the confirmation form "Delete this video?": destructive "Remove from lesson", destructive "Delete video everywhere" (enabled and noted by the two inputs), `doneLabel` "Cancel" (D4, D5, D14)
- C-066's new fields at their defaults leave every menu pixel-identical; a disabled button uses C-048's disabled look and fires nothing (D14)
- `reviewSaving` shows C-159 as the header's trailing control, labelled "Save" for VoiceOver; false keeps Done (D6, D18)
- full screen in phase `review` shows C-159 top-right, inset `space-page-margin`; `lessonInline` shows none; `reviewSlot` stays the container's (D6, D18)
- no capture plays audio (D9). d2m's completed result is the approval, handbacks settled against the SPEC, captures listed in the hand-off (D10, D17)
- build-time risk F5: d2m's shape for the player slot, press and C-066 fields is known once its request completes; wiring follows it (D17)

**Tests:**
- the new inputs are off by default, so every existing state and menu row is unchanged (D5, D6, D14)

```swift
func testVideoPageDefaultsLeaveExistingStatesAlone() {
  let state = ActivitiesEditorScreen.State()
  XCTAssertFalse(state.deleteEverywhereEnabled || state.reviewSaving)
  XCTAssertEqual(state.deleteEverywhereNote, "")
  let item = ActionMenuOverlay.ActionItem(glyph: "", label: "Delete", tone: .destructive)
  XCTAssertTrue(item.enabled && item.subtitle.isEmpty)
}
```

- [ ] **Step 1: Call `check_project_change` for activities-editor, video-recorder and C-066; write and commit `d2m-requirements.md`** — `docs(video-activity-basics): d2m requirements`, the one extra commit: d2m reads it from the branch
- [ ] **Step 2: Call `request_project_change` with it as a reference, then `wait_project_change` until done** — answer questions from the SPEC, settle held items with `approve_project_change`, park only on `cannot be done:`
- [ ] **Step 3: Check each Behaviour line against the delivered views and captures** — a miss is a new request, never a hand edit
- [ ] **Step 4: Write the listed test with the delivered names; run `xcodebuild test -scheme MakeReady -only-testing:MakeReadyCaptureTests/ActivitiesEditorScreenContractTests` in `iphone/`, watch it pass**
- [ ] **Step 5: Write "Delivered" in `d2m-requirements.md`, list the captures in the report, commit** — `feat(video-activity-basics): d2m video page, delete confirm and header check`

### Task 5: The video page's picture, and following one that is still arriving
App: iphone
Phase: 3
Recipe: ios-error-surface
Decisions: D1, D16

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift` — `videoStillURL`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — the still in `screenState`, the poll
- Modify: `iphone/MakeReady/State/Actions/VideoActions.swift` — `waitUntilReady`
- Test: `iphone/MakeReadyCaptureTests/` — `ActivitiesEditorMapperTests.swift`, `ActivitiesEditorContainerTests.swift`, `VideoActionsLibraryTests.swift`

**Interfaces:**
- Produces: `ActivitiesEditorMapper.videoStillURL` — takes a `VideoContent` and the media map, returns a String ("" = none).
- Produces: `VideoActions.waitUntilReady` — takes a video id, async throws, returns Bool.
- Produces on `ActivitiesEditorContainer.Model`: `waitForVideo` — a settable async throwing closure from video id to Bool, live over `waitUntilReady`; `missingStillVideoId` — takes an AppState, returns the open page's video id when it has no still; `followMissingStill` — takes an optional AppState, async; `open` — takes a `ContentActivity`.

**Behaviour:**
- the still is `media[videoId].posterUrl`, else the poster media's `posterUrl`, else its `url` when that entry is an image; empty strings count as missing (D1)
- a video page maps no title; the existing page-image task caches the still (D1)
- with no still (and no replacement uploading), `followMissingStill` waits, and only on true calls `reloadDraft`, which merges media; false or a throw leaves the page (D16)
- a `.task(id:)` keyed by `missingStillVideoId` runs it, so leaving cancels it; a cancelled wait reloads nothing; failures use `log` (D16)
- `waitUntilReady` reads the video, then `waitForVideoReady` at its limits; true is status `ready` (D16)

**Tests:**
- the still's order (D1). Helper `entry` (url, kind, poster = nil) is a `MediaMapEntry`

```swift
func testVideoStillOrder() {
  func still(_ media: [String: MediaMapEntry]) -> String {
    ActivitiesEditorMapper.videoStillURL(VideoContent(videoId: "v", posterMediaId: "p", presenter: nil), media: media)
  }
  let stream = entry("s.m3u8", "video"), image = entry("p", "image")
  XCTAssertEqual(still(["v": entry("s.m3u8", "video", "still"), "p": image]), "still")
  XCTAssertEqual(still(["v": stream, "p": entry("p", "image", "pp")]), "pp")
  XCTAssertEqual(still(["v": entry("s.m3u8", "video", ""), "p": image]), "p")
  XCTAssertEqual(still(["v": stream, "p": stream]), "")
}
```

- through `screenState` (D1). Helper `videoEntry` (poster = nil, playback = "https://x/v.m3u8"): a video `MediaMapEntry`

```swift
func testAVideoPageShowsItsStillAndNoTitle() async {
  let app = appWithDraft([videoActivity("vi1", version: "ver1")])
  app.mergeMedia(["vid1": videoEntry(poster: "https://x/still")])
  let model = ActivitiesEditorContainer.Model.resolving(activityId: "vi1", app: app)
  let state = ActivitiesEditorContainer.screenState(model, app: app)
  XCTAssertEqual([state.readOnlyPosterURL, state.readOnlyTitle], ["https://x/still", ""])
  XCTAssertNil(model.missingStillVideoId(app: app))
}
```

- true reloads once; false, a throw and a cancel do not (D16). `ScriptedActivityActions` gains `reloads`. Helper `videoEditor` (app, actions, at = "vi1"): a Model on lesson l1, version ver1 with a silent log, after `open` — `selectSlide`'s assignment block, extracted

```swift
func testAMissingStillIsFollowedThenTheDraftReloads() async {
  let app = appWithDraft([videoActivity("vi1", version: "ver1")])
  let actions = ScriptedActivityActions()
  let model = videoEditor(app: app, actions: actions)
  XCTAssertEqual(model.missingStillVideoId(app: app), "vid1")
  model.waitForVideo = { _ in false }
  await model.followMissingStill(app: app)
  model.waitForVideo = { _ in throw URLError(.timedOut) }
  await model.followMissingStill(app: app)
  model.waitForVideo = { _ in true }
  let cancelled = Task { await model.followMissingStill(app: app) }
  cancelled.cancel()
  await cancelled.value
  XCTAssertEqual(actions.reloads, 0)
  await model.followMissingStill(app: app)
  XCTAssertEqual(actions.reloads, 1)
}
```

- `GET /api/videos/r` is stubbed ready and `e` error; nothing else is (D16)

```swift
func testWaitUntilReadyIsTrueForAReadyVideo() async throws {
  let answers = [try await actions.waitUntilReady(id: "r"), try await actions.waitUntilReady(id: "e")]
  XCTAssertEqual(answers, [true, false])
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `xcodebuild test -scheme MakeReady` with `-only-testing:MakeReadyCaptureTests/ActivitiesEditorMapperTests` and `ActivitiesEditorContainerTests`, `VideoActionsLibraryTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass; run `swiftlint`**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): the video page shows its still`

### Task 6: Tap to play inline
App: iphone
Phase: 3
Recipe: transition-review
Decisions: D2, D3, D9, D12, D13

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoDetailPlayer.swift` — gravity, mute, the at-end flag
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — the inline player and its wiring
- Test: create `iphone/MakeReadyCaptureTests/AVVideoPlayerTests.swift`; `iphone/MakeReadyCaptureTests/ActivitiesEditorContainerTests.swift`

**Interfaces:**
- Consumes: `VideoPlaying`; the delivered `videoLayer`, `onVideoTap`, `onVideoMenu` (`d2m-requirements.md`, "Delivered").
- Produces: `AVVideoPlayer` initialiser — optional `session`, `videoGravity` (AVLayerVideoGravity, default `.resizeAspect`), `muted` (Bool, default `UserDefaults.standard.bool(forKey: "muteVideoPlayback")`); `isMuted` and `isAtEnd` — read-only Bools; `playedToEnd` — internal, so a test can end a video.
- Produces on `ActivitiesEditorContainer.Model`: `makePlayer` — settable closure returning a `VideoPlaying`, live an `AVVideoPlayer` filling; `videoLayer` — optional CALayer, nil until the first play on this page; `videoTapped` — takes an optional AppState; `pauseVideo`; `closeVideo` — stops and drops the player.

**Behaviour:**
- muted sets `AVPlayer.isMuted`, and neither play nor stop touches the audio session (D9, D13)
- ending sets `isAtEnd` and stops; play then seeks to 0 whatever the known duration; any seek or load clears the flag; with no known duration `elapsed` keeps its value at the end (D3, D12)
- a tap loads `media[videoId].playbackUrl` on first use (duration from the entry, else 0) and plays, never unasked; the next taps pause and play the same player (D2, D3)
- no playback URL, or an empty one, or any page but a video page: a tap does nothing and makes no player (D12)
- opening the hold menu and the app going to the background pause it (D3)
- leaving closes it: another chip, ＋, Replace's recorder, back, and the container disappearing (D3)
- tests use a fake, or the real player muted on a missing file (D9, D13)
- build-time risk F6: the walk env has no Cloudflare, so playback is owed to a real iPhone, and Stream deletion fails softly there (D9)

**Tests:**
- mute and its key (D13), the end and gravity (D12). `session` is a fake counting every call; `url` a missing file

```swift
func testMutedNeverTouchesTheSession() {
  let player = AVVideoPlayer(session: session, muted: true)
  player.load(url: url, duration: 10)
  player.play()
  player.stop()
  XCTAssertTrue(player.isMuted)
  XCTAssertEqual(session.calls, 0)
}
func testPlayAfterTheEndStartsOverWithNoDuration() {
  let player = AVVideoPlayer(session: session, muted: true)
  player.load(url: url, duration: 0)
  player.seek(to: 5)
  player.playedToEnd()
  XCTAssertEqual([player.isAtEnd, player.isPlaying], [true, false])
  XCTAssertEqual(player.elapsed, 5)
  player.play()
  XCTAssertFalse(player.isAtEnd)
  XCTAssertEqual(player.elapsed, 0)
  player.playedToEnd()
  player.seek(to: 2)
  XCTAssertFalse(player.isAtEnd)
  player.stop()
}
func testGravityDefaultsToFit() {
  func gravity(_ player: AVVideoPlayer) -> AVLayerVideoGravity? { (player.layer as? AVPlayerLayer)?.videoGravity }
  XCTAssertEqual(gravity(AVVideoPlayer(muted: true)), .resizeAspect)
  XCTAssertEqual(gravity(AVVideoPlayer(videoGravity: .resizeAspectFill, muted: true)), .resizeAspectFill)
}
func testTheLaunchArgumentMutes() {
  UserDefaults.standard.set(true, forKey: "muteVideoPlayback")
  defer { UserDefaults.standard.removeObject(forKey: "muteVideoPlayback") }
  XCTAssertTrue(AVVideoPlayer().isMuted)
}
```

- tap to play and pause (D2, D3); no stream (D12); leaving and backgrounding (D3). `FakeInlinePlayer`: a `VideoPlaying` with a layer, counting `loads` and `stops`. Helper `playing` (player, playback): a `videoEditor` on vi1 of two videos vi1, vi2, vid1 in the media map with a still, `makePlayer` returning the fake, `makeRecorder` a `makeRecorderModel`

```swift
func testATapPlaysAndPausesTheVideo() {
  let player = FakeInlinePlayer()
  let (app, model) = playing(player)
  XCTAssertEqual(player.loads, 0)
  model.videoTapped(app: app)
  XCTAssertTrue(player.isPlaying)
  XCTAssertTrue(model.videoLayer === player.layer)
  model.videoTapped(app: app)
  XCTAssertFalse(player.isPlaying)
  model.videoTapped(app: app)
  XCTAssertTrue(player.isPlaying)
  XCTAssertEqual(player.loads, 1)
}
func testATapWithNoStreamDoesNothing() {
  for playback in [nil, ""] {
    let player = FakeInlinePlayer()
    let (app, model) = playing(player, playback: playback)
    model.videoTapped(app: app)
    XCTAssertFalse(player.isPlaying)
    XCTAssertNil(model.videoLayer)
  }
}
func testLeavingOrBackgroundingStopsTheVideo() async {
  let leaving: [(ActivitiesEditorContainer.Model, AppState) async -> Void] = [
    { m, app in await m.selectSlide("vi2", app: app) },
    { m, _ in await m.addActivity() },
    { m, _ in await m.back() },
    { m, app in m.replaceVideo(app: app) }
  ]
  for leave in leaving {
    let player = FakeInlinePlayer()
    let (app, model) = playing(player)
    model.videoTapped(app: app)
    await leave(model, app)
    XCTAssertEqual(player.stops, 1)
    XCTAssertNil(model.videoLayer)
  }
  let player = FakeInlinePlayer()
  let (app, model) = playing(player)
  model.videoTapped(app: app)
  model.pauseVideo()
  XCTAssertFalse(player.isPlaying)
  XCTAssertNotNil(model.videoLayer)
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `xcodebuild test -scheme MakeReady` with `-only-testing:MakeReadyCaptureTests/AVVideoPlayerTests`, `VideoDetailModelTests` and `ActivitiesEditorContainerTests`, watch the new ones fail**
- [ ] **Step 3: Implement to the Behaviour; wire `videoLayer`, `onVideoTap`, `onVideoMenu`; pause when `scenePhase` becomes `.background`, close in `onDisappear`**
- [ ] **Step 4: Run it, watch it pass; run `swiftlint`**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): tap a video page to play it`

### Task 7: May this video be deleted everywhere?
App: iphone
Phase: 4
Recipe: test-driven-development
Decisions: D5, D11

**Files:**
- Modify: `iphone/MakeReady/State/Models/VideoModels.swift` — `versionUseCount`, `VideoDeleteEverywhere`
- Modify: `iphone/MakeReady/State/Actions/VideoActions.swift` — `deleteEverywhere`, the kept count
- Test: `iphone/MakeReadyCaptureTests/VideoActionsLibraryTests.swift`

**Interfaces:**
- Consumes: `data.versionUseCount` on `GET /api/videos/:id`.
- Produces: `Video.versionUseCount` — optional Int. `VideoDeleteEverywhere` — an Equatable enum with cases `checking`, `allowed`, `otherLessons` (Int), `published`, `unknown`; `enabled` (Bool), `note` (String), and an initialiser from a `Video`. `VideoActions.deleteEverywhere` — takes an id, async throws, returns a `VideoDeleteEverywhere`.

**Behaviour:**
- enabled only for `allowed`: both counts present and at most 1 (D5, D11)
- N is lessonUseCount − 1; the notes are D11's strings, exactly (D5, D11)
- either count missing → `unknown`; then lessonUseCount above 1 → `otherLessons`; then versionUseCount above 1 → `published` (D11)
- only the fresh answer's counts decide; a failed read throws (D11)
- the store keeps a known `versionUseCount` as it does `lessonUseCount`; a cached video without it decodes (D11)

**Tests:**
- every state with its note (D5, D11); a missing count and a failed read (D11). Helpers: `countedJSON` is `videoJSON` with both counts; `stub` answers `GET /api/videos/a` with it

```swift
func testDeleteEverywhereStates() async throws {
  let cases: [(Int, Int, VideoDeleteEverywhere, String)] = [
    (1, 1, .allowed, ""), (0, 0, .allowed, ""), (3, 1, .otherLessons(2), "Used in 2 other lessons"),
    (2, 4, .otherLessons(1), "Used in 1 other lesson"), (1, 2, .published, "Used in a published lesson")
  ]
  for (lessons, versions, expected, note) in cases {
    stub(countedJSON("a", lessons: lessons, versions: versions))
    let state = try await actions.deleteEverywhere(id: "a")
    XCTAssertEqual(state, expected)
    XCTAssertEqual(state.enabled, expected == .allowed)
    XCTAssertEqual(state.note, note)
  }
  XCTAssertFalse(VideoDeleteEverywhere.checking.enabled)
}
func testAMissingCountIsUnknownEvenWhenOneIsCached() async throws {
  stub(countedJSON("a", lessons: 1, versions: 1))
  _ = try await actions.deleteEverywhere(id: "a")
  stub(videoJSON(id: "a", lessonUseCount: 1))
  let second = try await actions.deleteEverywhere(id: "a")
  XCTAssertEqual(second, .unknown)
  XCTAssertFalse(second.enabled)
  XCTAssertEqual(second.note, "Couldn't check where it's used")
  XCTAssertEqual(state.videos["a"]?.versionUseCount, 1)
}
func testDeleteEverywherePropagatesAFailedRead() async {
  let state = try? await actions.deleteEverywhere(id: "never-stubbed")
  XCTAssertNil(state)
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `xcodebuild test -scheme MakeReady` with `-only-testing:MakeReadyCaptureTests/VideoActionsLibraryTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): whether a video may be deleted everywhere`

### Task 8: Remove from lesson and Delete video everywhere
App: iphone
Phase: 4
Recipe: ios-error-surface
Decisions: D2, D3, D4, D5, D7, D11, D14, D15

**Files:**
- Modify: `iphone/MakeReady/State/Actions/ActivityActions.swift:164` — a 404 on DELETE is `gone`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — the confirm, the removal, what opens next
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorContainerTests.swift`, `iphone/MakeReadyCaptureTests/ActivityActionsTests.swift`

**Interfaces:**
- Consumes: `VideoActions.deleteEverywhere`, `VideoDeleteEverywhere`, `VideoActions.deleteOrRemove` with `.delete`, `closeVideo`, `pauseVideo`; the delivered `onDelete`, `onRemoveFromLesson`, `onDeleteEverywhere`, `deleteEverywhereEnabled`, `deleteEverywhereNote`.
- Produces on `ActivitiesEditorContainer.Model`: `readDeleteEverywhere` and `deleteVideo` — settable async throwing closures by video id, live over `VideoActions`; `report` — settable closure taking an Error and the banner text, live `recordError` with `surface: true`; `deleteEverywhereState` (read-only, starts `checking`); `isDeleting` (read-only); `openDeleteConfirm` — takes an optional AppState, async; `removeVideo` — takes `everywhere` (Bool) and an optional AppState, async.

**Behaviour:**
- opening the confirm pauses the video, sets `checking`, then gives the screen the read's `enabled` and `note`; a throw shows `unknown` (console-only); leaving the page resets to `checking` and drops a late answer (D3, D5, D11)
- Remove deletes the activity only; Everywhere the activity, then the video, and nothing unless enabled (D4, D5, D7)
- a video failure keeps the removal; an activity failure keeps the page and the video; the removed document is never saved (D7, D15)
- while it runs, `isDeleting` ignores Replace, Delete, both confirm choices and a tap (D15)
- the removal, fixed (D15):

```text
removeVideo(everywhere):
  guard video page, not isDeleting, (not everywhere or state enabled); isDeleting = true until return
  videoId, key, index = the open activity's video id, activityKey, index in its version
  closeVideo; wait out saves in flight
  delete(activityId)
  on notDraft or gone:
    rows = reloadDraft(lessonId); lessonVersionId = rows.first's version when there is one
    row with key → activityId = row.id, index = its index in rows; delete(row.id) once; any throw is a failure
    no row with key → it counts as removed
  any failure (reload included; a cancellation too) → report "Couldn't remove the video"; return
  remaining = activities(forVersion: lessonVersionId) without key
  open remaining[index], else remaining.last, else the type grid with no insert point
  everywhere → deleteVideo(videoId); throw → report "Removed from the lesson, but couldn't delete the video"
```

**Tests:**
- what opens next, a failed removal, the retry, choices while deleting (D4, D15); the order and banner (D7); the counts (D5, D11)

`ScriptedActivityActions` gains `deleteSteps` (empty = success) and an async `onDelete`; `delete` records the id, runs it, then takes its step. Helper `deleting` (ids, at = "a", draft, steps) returns app, model and actions: one video activity per id, key `k-<id>`, all of vid1 in ver1, `videoEditor` on `at`; `readDeleteEverywhere` answers allowed, `deleteVideo` and `report` fail the test. In ver2: `a2` (key k-a) and `z` (key k-z). Helper `remove` (d, everywhere = false) opens the confirm, then removes; `shown` is its `screenState`.

```swift
func testRemoveOpensTheNextThenThePreviousThenTheGrid() async {
  for (ids, at, next) in [(["a", "b", "c"], "b", "c"), (["a", "b"], "b", "a"), (["a"], "a", "")] {
    let d = deleting(ids, at: at)
    await remove(d)
    XCTAssertEqual(d.actions.deletedIds + [d.model.activityId], [at, next])
    XCTAssertEqual(d.model.canvasContent, next.isEmpty ? .typeGrid : .readOnly)
    XCTAssertEqual(d.actions.savedIds, [])
  }
}
func testEverywhereDeletesTheActivityThenTheVideo() async {
  let d = deleting(["a", "b"])
  var order: [String] = [], banners: [String] = []
  d.actions.onDelete = { order.append("activity") }
  d.model.deleteVideo = { order.append($0); throw URLError(.badServerResponse) }
  d.model.report = { banners.append($1) }
  await remove(d, everywhere: true)
  XCTAssertEqual(order, ["activity", "vid1"])
  XCTAssertEqual(banners, ["Removed from the lesson, but couldn't delete the video"])
  XCTAssertEqual(d.model.activityId, "b")
}
func testAFailedRemovalKeepsThePageAndTheVideo() async {
  let steps: [[ScriptedActivityActions.Step]] = [[.failure(.other)], [.failure(.notDraft), .failure(.notDraft)]]
  for (failing, id) in zip(steps, ["a", "a2"]) {
    let d = deleting(["a", "b"], draft: [a2], steps: failing)
    var banners: [String] = []
    d.model.report = { banners.append($1) }
    await remove(d, everywhere: true)
    XCTAssertEqual(banners, ["Couldn't remove the video"])
    XCTAssertEqual(d.model.activityId, id)
    XCTAssertFalse(d.model.isDeleting)
  }
}
func testAFrozenDraftRetriesOnceByKey() async {
  for failure in [ScriptedActivityActions.Failure.notDraft, .gone] {
    let d = deleting(["a"], draft: [a2], steps: [.failure(failure)])
    await remove(d)
    XCTAssertEqual(d.actions.deletedIds, ["a", "a2"])
    XCTAssertEqual(d.model.lessonVersionId, "ver2")
  }
  let absent = deleting(["a"], draft: [z], steps: [.failure(.gone)])
  absent.app.activities.upsert(z)
  await remove(absent)
  XCTAssertEqual(absent.actions.deletedIds + [absent.model.activityId], ["a", "z"])
}
func testTheConfirmReadsTheCounts() async {
  let d = deleting(["a", "b"])
  XCTAssertEqual(shown(d).deleteEverywhereNote, "Checking where it's used…")
  d.model.readDeleteEverywhere = { _ in .published }
  await d.model.openDeleteConfirm(app: d.app)
  XCTAssertEqual(shown(d).deleteEverywhereNote, "Used in a published lesson")
  XCTAssertFalse(shown(d).deleteEverywhereEnabled)
  await remove(d, everywhere: true)
  XCTAssertEqual(d.actions.deletedIds, [])
  d.model.readDeleteEverywhere = { _ in throw URLError(.timedOut) }
  await d.model.openDeleteConfirm(app: d.app)
  XCTAssertEqual(d.model.deleteEverywhereState, .unknown)
  d.model.readDeleteEverywhere = { _ in await d.model.selectSlide("b", app: d.app); return .allowed }
  await d.model.openDeleteConfirm(app: d.app)
  XCTAssertEqual(d.model.deleteEverywhereState, .checking)
}
func testChoicesAreIgnoredWhileDeleting() async {
  let d = deleting(["a", "b"])
  d.model.makeRecorder = { _ in XCTFail("deleting"); return nil }
  d.model.makePlayer = { XCTFail("deleting"); return FakeInlinePlayer() }
  d.app.mergeMedia(["vid1": videoEntry()])
  d.actions.onDelete = {
    d.model.replaceVideo(app: d.app)
    d.model.videoTapped(app: d.app)
    await d.model.removeVideo(everywhere: false, app: d.app)
  }
  await remove(d)
  XCTAssertEqual(d.actions.deletedIds, ["a"])
}
```

- in `ActivityActionsTests` (D15)

```swift
func testDeletingAGoneActivityThrowsGone() async {
  api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found", details: ["code": "NOT_FOUND"]) }
  do { try await actions.delete(activityId: "a"); XCTFail("no throw") } catch { XCTAssertEqual(error as? ActivityActionsError, .gone) }
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run `xcodebuild test -scheme MakeReady` with `-only-testing:MakeReadyCaptureTests/ActivitiesEditorContainerTests` and `ActivityActionsTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour; wire the delivered inputs**
- [ ] **Step 4: Run it, watch it pass; run `swiftlint`**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): remove a video from its lesson, or delete it everywhere`

### Task 9: Review saves with the purple check
App: iphone
Phase: 4
Recipe: test-driven-development
Decisions: D6, D9, D18

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift` — `showsSaveCheck`
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift` — the full-screen check, Retake alone
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — the header check
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift`, `iphone/MakeReadyCaptureTests/ActivitiesEditorContainerTests.swift`

**Interfaces:**
- Consumes: the delivered `reviewSaving`, `onReviewSave`, `onSave`; `VideoRecorderModel.save`.
- Produces: `VideoRecorderModel.showsSaveCheck` — Bool. `VideoReviewActions.labels` — the row's button labels, in order. `saveReview` on the editor's Model — async, its recorder's `save` while `showsSaveCheck`, else nothing.

**Behaviour:**
- `showsSaveCheck` is true in phase `review` with no text editor open and not closed (D18)
- in a lesson, `reviewSaving` is the inline recorder's; else Done stays (D6, D18)
- both checks call `model.save()`, holding the recorder until it ends; a second tap saves nothing more (D6, D18)
- the bottom row is Retake only, in both layouts (D6)
- no test plays sound (D9)

**Tests:**
- when the check shows (D18); Retake alone (D6); the header check saves once, in `ActivitiesEditorContainerTests` (D6, D18)

```swift
func testTheSaveCheckShowsOnlyInReview() async {
  let m = makeModel()
  record(m)
  XCTAssertFalse(m.showsSaveCheck)
  m.done()
  XCTAssertTrue(m.showsSaveCheck)
  await m.editTapped()
  XCTAssertNotNil(m.editor)
  XCTAssertFalse(m.showsSaveCheck)
}
func testTheReviewRowIsRetakeAlone() {
  XCTAssertEqual(VideoReviewActions.labels, ["Retake"])
}
func testTheHeaderCheckSavesTheInlineRecording() async throws {
  let app = appWithLesson([("a1", "text")]), queue = QueueSpy()
  let model = editor(app: app, at: "a1", queue: queue)
  await model.addActivity()
  await model.pickType("video", app: app)
  let recorder = try XCTUnwrap(model.recorder)
  func check() -> Bool { ActivitiesEditorContainer.screenState(model, app: app).reviewSaving }
  recorder.recordTapped(); recorder.tick(recorded: 3); recorder.recordTapped()
  XCTAssertFalse(check())
  recorder.done()
  XCTAssertTrue(check())
  async let first: Void = model.saveReview()
  async let second: Void = model.saveReview()
  _ = await (first, second)
  XCTAssertEqual(queue.items.count, 1)
  XCTAssertFalse(check())
}
```

- [ ] **Step 1: Write the tests** — give `makeModel` a `makeEditor` double so `editTapped` opens a `VideoEditorModel`
- [ ] **Step 2: Run `xcodebuild test -scheme MakeReady` with `-only-testing:MakeReadyCaptureTests/VideoRecorderSaveTests` and `ActivitiesEditorContainerTests`, `VideoEditorPresentationTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour; wire the delivered inputs**
- [ ] **Step 4: Run it, watch it pass; run `swiftlint`**
- [ ] **Step 5: Commit** — `feat(video-activity-basics): Review saves with the purple check`
