# video-polish — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner's phone-walk fixes to the video recorder and editor — house-motion sheets, a Length panel with an end countdown, a teleprompter that is on only with text, fading rail labels, Review tap-to-play and scrub, and an editor with snapping trims, tap-to-play, no Deselect and a thin size line.

**Architecture:** Pure timing and settings logic first (RecorderSettings, RecordingTimeline, VideoLayerTiming.snap), tested on its own. Then d2m changes the d2m-built views from the SPEC and the owner approves them. Then the containers and models wire the new state and callbacks.

**Tech Stack:** iphone — Swift 5, SwiftUI, @Observable models, XCTest (MakeReadyCaptureTests), d2m-built MakeReadyUI views.

**Spec:** docs/features/video-polish/SPEC.md

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
| 1 | iphone | 1–2 | Length mode, unsnapped length, opt-in end countdown and the layer snap function exist and are tested |
| 2 | iphone | 3 | d2m has changed every affected view and the owner has approved them |
| 3 | iphone | 4–6 | The recorder, Review and the editor are wired to the new views and behave as the SPEC says |

---

### Task 1: Recorder length mode, unsnapped length and the end countdown setting
App: iphone
Phase: 1
Recipe: test-driven-development
Decisions: D4, D6, D13

**Files:**
- Modify: `iphone/MakeReady/Services/Video/RecorderSettings.swift:12-39` — new keys `lengthMode`, `endCountdownSeconds`; `length` unsnapped, clamped 5…120
- Modify: `iphone/MakeReady/Services/Video/RecordingTimeline.swift:31-82` — `minLength` 5, no snapping, `LengthMode`, an end countdown taken from a setting
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:204-210, :256, :386-396, :425-429` — pass mode and end countdown into the timeline; draft recovery keeps the unsnapped length
- Test: `iphone/MakeReadyCaptureTests/RecorderSettingsTests.swift`, `RecordingTimelineTests.swift`, `VideoRecorderModelTests.swift`

**Interfaces:**
- Produces: `RecorderSettings.LengthMode` — enum `any`, `specify` (raw strings "any", "specify"); `RecorderSettings.lengthMode` — read: the stored value, else `specify` when a length is saved, else `any`; `RecorderSettings.endCountdownSeconds` — 0, 3 or 10, default 0; `RecorderSettings.length` — clamped 5…120, no snapping.
- Produces: `RecordingTimeline.init(lengthSeconds:mode:endCountdownSeconds:)`; `RecordingTimeline.effectiveLength` — 120 under `any`, else `lengthSeconds`; `endCountdown(atRecorded:)` — nil when mode is `any` or the setting is 0, else the whole seconds left once fewer than the setting remain (from the start when the length is shorter); `shouldAutoStop` uses `effectiveLength`; `segmentFractions` divide by `effectiveLength`.
- Produces: `VideoRecorderModel.setLengthMode(_:)`, `setEndCountdown(_:)` — set and persist.

**Behaviour:**
- no saved length and no saved mode → `any`; a saved length and no mode → `specify` with that length (D4)
- length 94 stays 94; 2 → 5; 500 → 120 (D13)
- end countdown defaults to 0 (off) and only runs under `specify` (D6)
- under `any`, recording stops at 120 s and the bar's full width is 120 s (D4)

**Tests:**
- `testLengthModeDefaultsToAnyWithoutSavedLength` — fresh defaults → `.any` (D4)

```swift
func testLengthModeDefaultsToAnyWithoutSavedLength() {
    XCTAssertEqual(makeSettings().lengthMode, .any)
}
```

- `testSavedLengthOpensAsSpecify` — a saved 90 → `.specify`, length 90 (D4)

```swift
func testSavedLengthOpensAsSpecify() {
    let s = makeSettings(); s.defaults.set(90, forKey: "videoRecorder.lengthSeconds")
    XCTAssertEqual(s.lengthMode, .specify)
    XCTAssertEqual(s.length, 90)
}
```

- `testLengthIsClampedNotSnapped` — 94 → 94, 2 → 5, 500 → 120 (D13)

```swift
func testLengthIsClampedNotSnapped() {
    let s = makeSettings()
    s.length = 94; XCTAssertEqual(s.length, 94)
    s.length = 2; XCTAssertEqual(s.length, 5)
    s.length = 500; XCTAssertEqual(s.length, 120)
}
```

- `testEndCountdownDefaultsOffAndPersists` — default 0; set 3 → 3 (D6)

```swift
func testEndCountdownDefaultsOffAndPersists() {
    let s = makeSettings()
    XCTAssertEqual(s.endCountdownSeconds, 0)
    s.endCountdownSeconds = 3
    XCTAssertEqual(makeSettings(defaults: s.defaults).endCountdownSeconds, 3)
}
```

- `testEndCountdownOffByDefault` / `testEndCountdownAtThreeSeconds` / `testNoEndCountdownUnderAnyLength` / `testEndCountdownFromStartWhenShorter` (D6)

```swift
func testEndCountdownOffByDefault() {
    let t = RecordingTimeline(lengthSeconds: 30, mode: .specify, endCountdownSeconds: 0)
    XCTAssertNil(t.endCountdown(atRecorded: 29))
}
func testEndCountdownAtThreeSeconds() {
    let t = RecordingTimeline(lengthSeconds: 30, mode: .specify, endCountdownSeconds: 3)
    XCTAssertNil(t.endCountdown(atRecorded: 26.5))
    XCTAssertEqual(t.endCountdown(atRecorded: 27.5), 3)
    XCTAssertEqual(t.endCountdown(atRecorded: 29.5), 1)
}
func testNoEndCountdownUnderAnyLength() {
    let t = RecordingTimeline(lengthSeconds: 30, mode: .any, endCountdownSeconds: 10)
    XCTAssertNil(t.endCountdown(atRecorded: 115))
    XCTAssertTrue(t.shouldAutoStop(atRecorded: 120))
    XCTAssertFalse(t.shouldAutoStop(atRecorded: 60))
}
func testEndCountdownFromStartWhenShorter() {
    let t = RecordingTimeline(lengthSeconds: 5, mode: .specify, endCountdownSeconds: 10)
    XCTAssertEqual(t.endCountdown(atRecorded: 0.1), 5)
}
```

- Existing tests updated: the 10 s snap test becomes `testLengthIsClampedNotSnapped`; the always-on end countdown tests pass `endCountdownSeconds: 10`; `VideoRecorderModelTests` countdown tests set the setting to 10 and `.specify`.

- [ ] **Step 1: Write the listed tests and update the old ones**
- [ ] **Step 2: Run `xcodebuild test -project MakeReady.xcodeproj -scheme MakeReady -only-testing:MakeReadyCaptureTests/RecorderSettingsTests -only-testing:MakeReadyCaptureTests/RecordingTimelineTests -only-testing:MakeReadyCaptureTests/VideoRecorderModelTests` from `iphone/` on a builder simulator — watch them fail**
- [ ] **Step 3: Implement the Interfaces to the Behaviour**
- [ ] **Step 4: Run the same command — watch them pass**
- [ ] **Step 5: Commit** — `feat(video-polish): length mode, unsnapped length and opt-in end countdown`

### Task 2: Layer edge snapping on the editor timeline
App: iphone
Phase: 1
Recipe: test-driven-development
Decisions: D12

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoLayerTiming.swift:19-50` — a pure `snap`
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoEditSession.swift:122-177` — trims and slides pass through `snap`; a `snapTarget` the container watches for the haptic
- Test: `iphone/MakeReadyCaptureTests/VideoLayerTests.swift`, `VideoEditSessionTests.swift`

**Interfaces:**
- Produces: `VideoLayerTiming.snapEngageMs` = 200, `snapReleaseMs` = 300 (8 pt / 12 pt at 40 pt/s); `VideoLayerTiming.snap(_ ms: Int, targets: [Int], current: Int?) -> (ms: Int, target: Int?)` — returns the nearest target within engage distance, or keeps `current` while within release distance, else the input and nil.
- Produces: `VideoEditSession.snapTargets(excluding:)` — 0, `clipMs`, the playhead, and every other layer's start and end; `VideoEditSession.snappedTo: Int?` — the target the live gesture is held to, nil when none; cleared at `endGesture`.

**Behaviour:**
- trimStart/trimEnd snap the dragged edge; slide snaps whichever of the bar's two edges is nearer a target, keeping its length (D12)
- the clamp to the clip and neighbours still applies after the snap, so nothing goes past the clip (D12)
- `snappedTo` changes only when a new target engages — the haptic fires once per snap (D12)

**Tests:**
- `testSnapEngagesWithin200ms` / `testSnapHoldsUntil300ms` / `testSnapReleasesPast300ms` (D12)

```swift
func testSnapEngagesWithin200ms() {
    XCTAssertEqual(VideoLayerTiming.snap(5_150, targets: [5_000], current: nil).ms, 5_000)
    XCTAssertEqual(VideoLayerTiming.snap(5_250, targets: [5_000], current: nil).ms, 5_250)
}
func testSnapHoldsUntil300ms() {
    XCTAssertEqual(VideoLayerTiming.snap(5_280, targets: [5_000], current: 5_000).ms, 5_000)
}
func testSnapReleasesPast300ms() {
    let r = VideoLayerTiming.snap(5_320, targets: [5_000], current: 5_000)
    XCTAssertEqual(r.ms, 5_320); XCTAssertNil(r.target)
}
```

- `testTrimSnapsToOtherLayerEdgeAndPlayhead` / `testSlideSnapsNearerEdge` / `testTrimNeverPassesClipStart` (D12)

```swift
func testTrimSnapsToOtherLayerEdgeAndPlayhead() {
    let s = makeSession(clipMs: 20_000, layers: [layer(0, 4_000), layer(6_000, 9_000)], playheadMs: 12_000)
    s.trimEnd(s.layers[1].id, to: 11_880)
    XCTAssertEqual(s.layers[1].endMs, 12_000); XCTAssertEqual(s.snappedTo, 12_000)
    s.trimStart(s.layers[1].id, to: 4_120)
    XCTAssertEqual(s.layers[1].startMs, 4_000)
}
func testSlideSnapsNearerEdge() {
    let s = makeSession(clipMs: 20_000, layers: [layer(0, 4_000), layer(10_000, 13_000)])
    s.slide(s.layers[1].id, to: 4_150)
    XCTAssertEqual(s.layers[1].startMs, 4_000); XCTAssertEqual(s.layers[1].endMs, 7_000)
}
func testTrimNeverPassesClipStart() {
    let s = makeSession(clipMs: 20_000, layers: [layer(1_000, 4_000)])
    s.trimStart(s.layers[0].id, to: -800)
    XCTAssertEqual(s.layers[0].startMs, 0)
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `-only-testing:MakeReadyCaptureTests/VideoLayerTests -only-testing:MakeReadyCaptureTests/VideoEditSessionTests` — watch them fail**
- [ ] **Step 3: Implement `snap`, `snapTargets` and `snappedTo` to the Behaviour**
- [ ] **Step 4: Run the same — watch them pass**
- [ ] **Step 5: Commit** — `feat(video-polish): snap layer edges to the clip, other layers and the playhead`

### Task 3: d2m changes the recorder and editor views; the owner approves
App: iphone
Phase: 2
Recipe: REFERENCE §The project's own rules — the d2m-channel rule in the root CLAUDE.md (check_project_change, then request_project_change with references, then wait_project_change)
Decisions: D1–D3, D4–D12, D14

**Files:**
- Create: `docs/features/video-polish/d2m-requirements.md` — the d2m brief: every view, its new state and callbacks, and the SPEC rows that bind it (≤ 8 000 chars)
- Modify (by d2m, not by hand): `iphone/MakeReadyUI/Screens/Library/VideoRecorderScreen.swift`, `CameraRail.swift`, `RailTool.swift`, `LengthSlider.swift`, `FilterStrip.swift`, `TeleprompterBand.swift`, `PageHeader.swift` (Done check extracted), `TextSizeSlider.swift`, `VideoEditorLayerTrack.swift`, `VideoEditorLayerToolbar.swift`, `Screens/Library/VideoEditorScreen.swift`, `Screens/Activities/ActivitiesEditorScreen.swift`, their fixtures in `ViewRegistry.swift` / `CaptureFixture.swift`

**Interfaces:**
- Produces (VideoRecorderScreen): State `lengthMode` ("any" / "specify"), `endCountdown` (0 / 3 / 10), `reviewPlaying`, `reviewElapsed`, `reviewDuration`, `reviewScrubbing`; callbacks `onLengthModeChange(String)`, `onEndCountdownChange(Int)`, `onReviewTap()`, `onReviewSeek(TimeInterval)`, `onReviewScrubbingChange(Bool)`; `onLengthChange` sends only committed values (D5).
- Produces (MakeReadyUI): a pure length-entry formatter the Length panel uses — `LengthEntry.digits(_:)` → m:ss text with a 2:00 cap, `LengthEntry.commit(_:)` → seconds 5…120 — named by d2m and recorded here when it lands.
- Produces (C-154): handles inside the bar's ends; intents unchanged.

**Behaviour:**
- every view behaves as its SPEC row says: sheets D1, Filters D2, Teleprompter D3, Length D4–D6, labels D7, Review D9, toolbar and gap D10, size line D11, handles D12
- the end countdown is silent; d2m captures play no audio (§Standing traps)

**Tests:**
- `testLengthEntryFormatsFromTheRight` — 1 → 0:01, 130 → 1:30, 2005 → 2:00 (D5)

```swift
func testLengthEntryFormatsFromTheRight() {
    XCTAssertEqual(LengthEntry.digits("1"), "0:01")
    XCTAssertEqual(LengthEntry.digits("130"), "1:30")
    XCTAssertEqual(LengthEntry.digits("2005"), "2:00")
}
```

- `testLengthEntryCommitNormalisesAndClamps` — 0:75 → 75, 0:02 → 5 (D5)

```swift
func testLengthEntryCommitNormalisesAndClamps() {
    XCTAssertEqual(LengthEntry.commit("0:75"), 75)
    XCTAssertEqual(LengthEntry.commit("0:02"), 5)
}
```

- [ ] **Step 1: `check_project_change` for the views; write and commit `d2m-requirements.md`**
- [ ] **Step 2: `request_project_change` with it as a reference; `wait_project_change` until done, settling handbacks**
- [ ] **Step 3: Show the owner the captures; 🔒 stop for approval**
- [ ] **Step 4: Write the LengthEntry tests in `iphone/MakeReadyCaptureTests/LengthEntryTests.swift`, run them, watch them pass against d2m's formatter (a failure goes back to d2m)**
- [ ] **Step 5: Commit d2m's output with the tests** — `feat(video-polish): d2m views for sheets, Length, Review scrub and editor polish`

### Task 4: Recorder model — teleprompter rule, Review playback
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D3, D9

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:152, :206, :401-411, :448-452, :705-739, :942-967` — teleprompter derived from the script; Review play/pause, end, seek, elapsed; viewState fills the Task 3 State
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderModelTests.swift`

**Interfaces:**
- Consumes: Task 1's `setLengthMode`, `setEndCountdown`; Task 3's State fields.
- Produces: `VideoRecorderModel.reviewTapped()`, `reviewSeek(to:)`, `setReviewScrubbing(_:)`; `teleprompterOn` computed as the trimmed script being non-empty.

**Behaviour:**
- the rail's teleprompter tap only opens the sheet (D3)
- a saved non-empty script shows the band when the recorder opens (D3)
- Review: `loops = false` with an end callback; a tap toggles play; at the end a tap plays from 0; Trim keeps looping (D9)
- while scrubbing, playback is held paused and resumes its prior state on release (D9)

**Tests:**
- `testTeleprompterRailTapDoesNotTurnItOn` / `testSavedScriptTurnsTeleprompterOn` / `testClearTurnsTeleprompterOff` (D3)

```swift
func testTeleprompterRailTapDoesNotTurnItOn() {
    let m = makeModel(); m.rail(.teleprompter)
    XCTAssertFalse(m.viewState.teleprompterOn)
}
func testSavedScriptTurnsTeleprompterOn() {
    let m = makeModel(script: "Welcome")
    XCTAssertTrue(m.viewState.teleprompterOn)
}
func testClearTurnsTeleprompterOff() {
    let m = makeModel(script: "Welcome"); m.setScript("   ")
    XCTAssertFalse(m.viewState.teleprompterOn)
}
```

- `testReviewStopsAtEndAndReplaysFromStart` / `testTrimStillLoops` (D9)

```swift
func testReviewStopsAtEndAndReplaysFromStart() {
    let (m, player) = makeReviewModel()
    XCTAssertFalse(player.loops)
    player.finish()
    XCTAssertFalse(m.viewState.reviewPlaying)
    m.reviewTapped()
    XCTAssertEqual(player.lastSeek, 0); XCTAssertTrue(player.isPlaying)
}
func testTrimStillLoops() {
    let (m, player) = makeReviewModel(); m.openTrim()
    XCTAssertTrue(player.loops)
}
```

- The old `rail(.teleprompter)` turns-it-on test is updated to `testTeleprompterRailTapDoesNotTurnItOn`.

- [ ] **Step 1: Write the listed tests and update the old one**
- [ ] **Step 2: Run `-only-testing:MakeReadyCaptureTests/VideoRecorderModelTests` — watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the same — watch them pass**
- [ ] **Step 5: Commit** — `feat(video-polish): teleprompter on only with text; Review tap, scrub and stop at end`

### Task 5: Recorder container — the new callbacks and delete-last placement
App: iphone
Phase: 3
Recipe: transition-review
Decisions: D4–D6, D8, D9

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift:101-130, :143-192` — pass Task 3's callbacks to Task 1/4's model methods; delete-last at x = (W/2 − 40)/2
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderModelTests.swift` — the mapping helper

**Interfaces:**
- Consumes: Task 1's `setLengthMode`, `setEndCountdown`; Task 4's `reviewTapped`, `reviewSeek(to:)`, `setReviewScrubbing(_:)`; Task 3's callbacks.
- Produces: `VideoRecorderContainer.deleteLastCentreX(width:)` — static, `(width / 2 - 40) / 2`.

**Behaviour:**
- each new screen callback reaches its model method (D4, D6, D9)
- delete-last sits halfway between the leading edge and the record button (D8)

**Tests:**
- `testDeleteLastSitsHalfwayToRecord` (D8)

```swift
func testDeleteLastSitsHalfwayToRecord() {
    XCTAssertEqual(VideoRecorderContainer.deleteLastCentreX(width: 440), 90)
}
```

- [ ] **Step 1: Write the test**
- [ ] **Step 2: Run it — watch it fail**
- [ ] **Step 3: Wire the callbacks and the placement; run `/transition-review` over the diff**
- [ ] **Step 4: Run `-only-testing:MakeReadyCaptureTests/VideoRecorderModelTests` — watch it pass**
- [ ] **Step 5: Commit** — `feat(video-polish): wire Length, end countdown and Review callbacks; move delete-last`

### Task 6: Editor container — tap to play, snap haptic
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D10, D12

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoEditorContainer.swift:68-105` — route the empty-video tap; a selection haptic on each new `snappedTo`
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoEditorModel.swift:104-150` — `tapEmpty(selected:)`
- Test: `iphone/MakeReadyCaptureTests/VideoEditorModelTests.swift`

**Interfaces:**
- Consumes: Task 2's `VideoEditSession.snappedTo`; the existing `playTapped`.
- Produces: `VideoEditorModel.tapEmpty()` — deselects when a layer is selected, else `playTapped()`.

**Behaviour:**
- an empty tap with a selection deselects and leaves playback alone (D10)
- an empty tap with nothing selected toggles play (D10)
- each new `snappedTo` value plays one selection haptic (D12)

**Tests:**
- `testEmptyTapDeselectsFirst` / `testEmptyTapTogglesPlayWhenNothingSelected` (D10)

```swift
func testEmptyTapDeselectsFirst() {
    let m = makeEditor(); m.session.select(m.session.layers[0].id)
    m.tapEmpty()
    XCTAssertNil(m.session.selectedId); XCTAssertFalse(m.isPlaying)
}
func testEmptyTapTogglesPlayWhenNothingSelected() {
    let m = makeEditor()
    m.tapEmpty(); XCTAssertTrue(m.isPlaying)
    m.tapEmpty(); XCTAssertFalse(m.isPlaying)
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `-only-testing:MakeReadyCaptureTests/VideoEditorModelTests` — watch them fail**
- [ ] **Step 3: Implement `tapEmpty` and the haptic hook to the Behaviour**
- [ ] **Step 4: Run the same — watch them pass**
- [ ] **Step 5: Commit** — `feat(video-polish): editor tap to play or deselect; haptic on snap`
