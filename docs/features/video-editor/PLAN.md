# video-editor — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** From Review, a leader adds timed, styled text layers and editable captions to a recorded or imported video; Save draws them into the uploaded file and sends the corrected transcript.

**Architecture:** d2m builds the editor screen first and the owner approves it (P2, D5). Layers are Codable values edited by `VideoEditSession`, kept in the draft, and rasterised by one C-092 renderer the export and Review's player share. `VideoEditorModel` drives its own player and d2m's screen over the recorder. The server contract does not change.

**Tech Stack:** iphone — SwiftUI, `@Observable`, AVFoundation + Core Image, `ImageRenderer`, Speech, XCTest (`MakeReadyCaptureTests`); d2m through `d2m-channel`.

**Spec:** `docs/features/video-editor/SPEC.md` (program rulings P1–P10: `docs/features/video-recording/PROGRAM.md`; design source: `docs/features/video-recording/01-youtube-1-analysis.md` §6–§7)

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(video-editor): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | iphone | 1 | d2m has specced and built the video-editor screen, its parts and Review's Edit, and the owner has approved them (P2, D5) |
| 2 | iphone | 2–5 | The layer model, captions, edit session with undo, and drafts that carry an edit are tested |
| 3 | iphone | 6–9 | The export draws layers, the clip being edited can be transcribed, and Save sends the corrected transcript |
| 4 | iphone | 10–12 | The player and the editor's and recorder's models run the whole edit without a screen |
| 5 | iphone | 13–14 | The editor is live from Review's Edit in both entry points |

---

### Task 1: File the d2m requests and wait for the approved screens
App: iphone
Phase: 1
Recipe: REFERENCE §Prototype mode (design is d2m's; this task only requests and records)
Decisions: D3, D4, D5, D7, D8, D9, D10, D11, D13, D14, D15, D20, D24

**Files:**
- Modify (by d2m, not by hand): `iphone/MakeReadyUI/**`
- Create: `.builder/video-editor/d2m-api.md` (workspace, git-ignored) — the names, inputs and literals d2m shipped, for Tasks 2, 3, 6, 11, 13 and 14

**Interfaces:**
- Consumes: SPEC §iphone "Phase 1 is d2m", SPEC §Decisions, `01-youtube-1-analysis.md` §6–§7
- Produces (requested; `d2m-api.md` records deviations):
  - `VideoEditorScreen` — a `State` of layers as values, selected id, playhead, duration, playing, frame aspect, filmstrip images, `canUndo`, `canSplit`, captions state and reason, limit message, text tool (text, style, style panels or not); a `feed` `CALayer` as `VideoRecorderScreen` takes; callbacks: cancel, undo, done, play/pause, scrub, select, text, captions, split, edit, delete, trim start, trim end, slide, place, gesture ended, text commit
  - `VideoRecorderScreen`'s Review with **Edit** and its callback
  - the caption house style and placement, default text style, edit slot width in wu, reason and limit copy

**Behaviour:**
- one `request_project_change` each for `new:video-editor` (with a `screen` block) and `video-recorder`: `references` the SPEC, `PROGRAM.md` and `01-youtube-1-analysis.md`, `branch` this branch, intent ≤ 2000 characters naming its decisions (D5)
- `new:video-editor` lists every SPEC §iphone state and new part and the reuse of C-091–C-095 and the panels; moving, snapping, guides and delete target happen in the screen; captions as D4/D24; the frame as D20 (D8, D9)
- F8 (phase 1): d2m fits Filters, Retake, Edit and Save in 440 pt and the lesson's narrower inline width; Retake and Save are app code in `VideoRecorderContainer.reviewRow` (D7)
- F4 (phase 1): d2m decides whether the text parts need video variants (D8)
- F7 (build-time risk): change `cmwsxqfj30001v0bzu8y8qd89` is stopped on struck C-143, its work landed; if it blocks, settle it or `cancel_project_change` it (D5)
- `wait_project_change` until done; settle handbacks from the SPEC (`answer_project_change`, `retry_project_change`; `approve_project_change` for a build checkpoint). The owner's screen approval is a person's step: with none in SPEC §Decisions, park `human-step` naming the screens. Park also when `next` starts `cannot be done:` (D5)
- if d2m landed on `main`, merge `main` into this branch (D5)
- the d2m-channel tools are MCP: the orchestrator runs this task, not an implementer without MCP

**Tests:**
- `the app's suite passes on d2m's last commit` — no new assertions: d2m captures and diffs every state (D5)

- [ ] **Step 1: File the two requests** — on a clean tree
- [ ] **Step 2: Wait and settle handbacks** — until both are done
- [ ] **Step 3: Check every SPEC §iphone state has a capture**
- [ ] **Step 4: Write `d2m-api.md`** from `git log -p -- iphone/MakeReadyUI`
- [ ] **Step 5: Run the iphone-xctest suite on HEAD** — PASS
- [ ] **Step 6: Take the owner's approval** — from SPEC §Decisions, or park

### Task 2: The layer model and its timing rules
App: iphone
Phase: 2
Recipe: test-driven-development
Decisions: D3, D13, D15, D17, D22, D24, D28

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoLayer.swift` — the layer, its style and lenient decoding
- Create: `iphone/MakeReady/Services/Video/VideoLayerTiming.swift` — pure trim, slide and split
- Test: `iphone/MakeReadyCaptureTests/VideoLayerTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: the default text style in `.builder/video-editor/d2m-api.md`
- Produces:
  - `VideoLayer` (Codable, Equatable, Identifiable, Sendable) with D17's fields: `id` UUID, `kind`, `text`, `style`, `centre` CGPoint (y down), `scale`, `rotation` (radians, clockwise), `startMs`, `endMs`, `sourceSegment` optional; its initialiser defaults everything but `kind`, `text`, `startMs`, `endMs`
  - `VideoLayerStyle`: `font`, `weight`, `size` Double in wu, `colour` hex, `background`, `alignment` (D22's cases, CaseIterable); `VideoLayerStyle.standard`
  - `VideoLayer.decodeLenient` — a keyed container and key, returns the layers that decode, nil when absent or not a list
  - `VideoLayer.maxTextLayers` (20), `textLimit` — 200, or a longer caption's own length; `isVisible(at:)` — `startMs <= ms < endMs`
  - `VideoLayerTiming`: `trimStart`, `trimEnd`, `slide` (layer, target ms, bounds range → layer), `bounds` (layer, all layers, clip ms → range), `canSplit` (layer, ms → Bool), `split` (layer, ms → two layers)

**Behaviour:**
- trim clamps to the bounds and keeps at least min(500 ms, own length); slide keeps the length (D3, D24)
- bounds are 0…clip; a caption's also stop at the nearest captions before and after it (D24)
- split keeps the id on the first half and everything else on both; allowed only ≥ 500 ms inside both ends (D13)
- a layer without `id`, `kind`, `text`, `startMs` or `endMs`, or with `endMs <= startMs`, is dropped alone (D28)
- a bad or missing style value reads as `standard`'s, a colour not `#RRGGBB` as `#FFFFFF`, centre, scale and rotation as their defaults (D28)

**Tests:**
- `trim, slide and bounds clamp` (D3, D24)
```swift
func testTrimAndSlide() {
  let l = VideoLayer(kind: .text, text: "T", startMs: 1000, endMs: 4000)
  XCTAssertEqual(VideoLayerTiming.trimStart(l, to: 3900, in: 0...10_000).startMs, 3500)
  XCTAssertEqual(VideoLayerTiming.trimStart(l, to: -50, in: 0...10_000).startMs, 0)
  XCTAssertEqual(VideoLayerTiming.trimEnd(l, to: 99_000, in: 0...10_000).endMs, 10_000)
  let short = VideoLayer(kind: .caption, text: "Hi", startMs: 1000, endMs: 1200)
  XCTAssertEqual(VideoLayerTiming.trimEnd(short, to: 1050, in: 0...10_000).endMs, 1200)
  let late = VideoLayerTiming.slide(l, to: 9000, in: 0...10_000)
  XCTAssertEqual([late.startMs, late.endMs], [7000, 10_000])
  let b = VideoLayer(kind: .caption, text: "b", startMs: 1500, endMs: 2500)
  let all = [VideoLayer(kind: .caption, text: "a", startMs: 0, endMs: 1000), b, VideoLayer(kind: .caption, text: "c", startMs: 3000, endMs: 4000), l]
  XCTAssertEqual(VideoLayerTiming.bounds(of: b, among: all, clipMs: 10_000), 1000...3000)
  XCTAssertEqual(VideoLayerTiming.bounds(of: l, among: all, clipMs: 10_000), 0...10_000)
}
```
- `split meets at the playhead and is refused near an end` — `l` is a caption "Grace", 1000–4000, segment 3 (D13)
```swift
func testSplit() {
  let (a, b) = VideoLayerTiming.split(l, at: 2500)
  XCTAssertEqual([a.startMs, a.endMs, b.startMs, b.endMs], [1000, 2500, 2500, 4000])
  XCTAssertTrue(a.id == l.id && b.id != l.id && b.style == l.style && b.centre == l.centre && b.text == "Grace")
  XCTAssertEqual([a.sourceSegment, b.sourceSegment], [3, 3])
  XCTAssertEqual([500, 1499, 1500, 3500, 3501].map { VideoLayerTiming.canSplit(l, at: $0) }, [false, false, true, true, false])
  XCTAssertTrue(l.isVisible(at: 1000)); XCTAssertFalse(l.isVisible(at: 4000))
}
```
- `one bad layer is dropped, bad style values read as defaults` — `Box` decodes its `layers` with `decodeLenient` (D28, D15)
```swift
func testLenientDecoding() throws {
  let json = #"{"layers":[{"id":"6F9619FF-8B86-D011-B42D-00CF4FC964FF","kind":"text","text":"A","startMs":0,"endMs":900,"style":{"font":"wingdings","colour":"red","background":"neon"}},{"kind":"text"},7]}"#
  let layers = try XCTUnwrap(JSONDecoder().decode(Box.self, from: Data(json.utf8)).layers)
  XCTAssertEqual(layers.map(\.text), ["A"])
  XCTAssertEqual(layers[0].style.font, VideoLayerStyle.standard.font)
  XCTAssertEqual(layers[0].style.colour, "#FFFFFF"); XCTAssertEqual(layers[0].centre, CGPoint(x: 0.5, y: 0.5))
  XCTAssertNil(try JSONDecoder().decode(Box.self, from: Data(#"{"layers":"x"}"#.utf8)).layers)
  let long = String(repeating: "a", count: 250)
  XCTAssertEqual([VideoLayer.Kind.text, .caption].map { VideoLayer(kind: $0, text: long, startMs: 0, endMs: 900).textLimit }, [200, 250])
}
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoLayerTests`, see them fail**
- [ ] **Step 3: Implement `VideoLayer` and `VideoLayerTiming`**
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): video layer model and timing rules`

### Task 3: Captions from a transcript and the corrected transcript
App: iphone
Phase: 2
Recipe: test-driven-development
Decisions: D4, D12, D24, D26

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoCaptions.swift` — captions from segments, and the merge at Save
- Test: `iphone/MakeReadyCaptureTests/VideoCaptionsTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoLayer`, `VideoLayerTiming.split` (Task 2); `VideoTranscript` (`VideoTranscriber.swift:13`); the caption house style and placement in `d2m-api.md`
- Produces: `VideoCaptions.layers(from:clipMs:)` — a transcript, returns caption layers in time order; `VideoCaptions.corrected(_:with:)` — a transcript and all layers, returns the transcript to send; `VideoCaptions.style`, `VideoCaptions.centre`

**Behaviour:**
- windows, skips and long segments as D24; `sourceSegment` is the segment's index (D4, D24)
- `corrected` follows D12 and D26; segments' times never change, and with no captions the transcript is returned unchanged (D12, D26)
- `text` is the segments' trimmed texts joined by single spaces (D12)

**Tests:** (`seg(text, start, end)` builds a segment)
- `one caption per segment, clamped, empty ones skipped` (D4, D24)
```swift
func testLayers() {
  let long = String(repeating: "word", count: 60)
  let t = VideoTranscript(text: "x", segments: [seg(" Hello ", 0, 1200), seg("there", 1000, 2000), seg("  ", 2000, 2500), seg("in", 1100, 1900), seg(long, 2600, 9999)])
  let layers = VideoCaptions.layers(from: t, clipMs: 5000)
  XCTAssertEqual(layers.map(\.text), ["Hello", "there", long])
  XCTAssertEqual(layers.map { [$0.startMs, $0.endMs] }, [[0, 1200], [1200, 2000], [2600, 5000]])
  XCTAssertEqual(layers.map(\.sourceSegment), [0, 1, 4])
  XCTAssertTrue(layers.allSatisfy { $0.kind == .caption && $0.style == VideoCaptions.style && $0.centre == VideoCaptions.centre })
}
```
- `rewording replaces; deleting and trimming keep` — segments "Jon three", "then", "rest" of 1 s each; the first caption reworded "John 3", the second deleted, the third trimmed to 2600 (D12)
```swift
func testCorrected() {
  let out = VideoCaptions.corrected(t, with: layers)
  XCTAssertEqual(out.segments, [seg("John 3", 0, 1000), seg("then", 1000, 2000), seg("rest", 2000, 3000)])
  XCTAssertEqual(out.text, "John 3 then rest")
}
```
- `a split caption gives only its reworded halves, in time order` (D26)
```swift
func testCorrectedAfterASplit() {
  let t = VideoTranscript(text: "Jon three sixteen", segments: [seg("Jon three sixteen", 0, 4000)])
  var (a, b) = VideoLayerTiming.split(VideoCaptions.layers(from: t, clipMs: 4000)[0], at: 2000)
  XCTAssertEqual(VideoCaptions.corrected(t, with: [a, b]).text, "Jon three sixteen")
  a.text = "John"
  XCTAssertEqual(VideoCaptions.corrected(t, with: [a, b]).text, "John")
  b.text = "3:16"
  XCTAssertEqual(VideoCaptions.corrected(t, with: [b, a]).text, "John 3:16")
  XCTAssertEqual(VideoCaptions.corrected(t, with: []), t)
}
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoCaptionsTests`, see them fail**
- [ ] **Step 3: Implement both `VideoCaptions` functions**
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): captions from a transcript and its corrected text`

### Task 4: `VideoEditSession` — layers, selection and undo
App: iphone
Phase: 2
Recipe: test-driven-development
Decisions: D1, D3, D4, D8, D13, D14, D15, D24, D25, D30

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoEditSession.swift` — state, actions and history
- Test: `iphone/MakeReadyCaptureTests/VideoEditSessionTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoLayer`, `VideoLayerTiming` (Task 2); `VideoCaptions.layers` (Task 3)
- Produces `VideoEditSession` (`@MainActor @Observable`), made from layers, clip ms and an `onChange` closure taking the layers:
  - read: `layers`, `selectedId`, `selected`, `playheadMs`, `canUndo`, `canSplit`, `canAddText`, `hasCaptions`
  - `addText` (text, style), `setText` (id, text, style), `delete` (id), `split`, `addCaptions` (transcript), `removeCaptions`, `undo`, `cancel`, `select` (optional id), `seek` (ms)
  - live: `trimStart`, `trimEnd`, `slide` (id, ms), `place` (id, centre, scale, rotation); ended by `endGesture`

**Behaviour:**
- `addText`: whole clip, frame centre, appended last, selected; text trimmed and cut at `textLimit`; whitespace-only adds nothing; at 20 does nothing (D3, D8, D15, D25)
- `setText`: whitespace-only deletes; on a caption only the text changes (D4, D8)
- `addCaptions` goes before every text layer; does nothing when captions exist or none result (D4, D25)
- `place` ignores captions; `canSplit` is false for a text layer at 20 (D15, D24)
- `split` puts the second half directly after the first and selects it (D25)
- each action, and each gesture at `endGesture`, is one history entry and one `onChange`; nothing changed is neither (D14, D30)
- `undo` and `cancel` call `onChange`; a selection whose layer is gone is cleared (D14)
- `seek` clamps to 0…clip (D3)

**Tests:** (`make(layers)` is a 10 s session recording `onChange` in `saved`; `transcript` has "a" 0–1000 and "b" 1000–2000)
- `every D14 action is one undo step` (D14, D30)
```swift
func testUndoStepsBackThroughEveryAction() throws {
  let s = make()
  var before: [[VideoLayer]] = []
  func act(_ body: () -> Void) { before.append(s.layers); body(); XCTAssertNotEqual(s.layers, before.last) }
  act { s.addText("Title", style: .standard) }
  let id = try XCTUnwrap(s.selectedId)
  act { s.setText(id, text: "Titles", style: .standard) }
  act { for x in [0.4, 0.2] { s.place(id, centre: CGPoint(x: x, y: 0.2), scale: 1.5, rotation: 0.3) }; s.endGesture() }
  act { s.trimEnd(id, to: 5000); s.trimEnd(id, to: 4000); s.endGesture() }
  act { s.slide(id, to: 2000); s.endGesture() }
  act { s.seek(3000); s.split() }
  act { s.delete(id) }
  act { s.addCaptions(transcript) }
  act { s.removeCaptions() }
  XCTAssertEqual(saved.count, 9)
  for expected in before.reversed() { s.undo(); XCTAssertEqual(s.layers, expected) }
  XCTAssertFalse(s.canUndo); XCTAssertNil(s.selectedId)
}
```
- `no change is no entry; Cancel restores` (D14, D30)
```swift
func testNoChangeAndCancel() {
  let opened = [VideoLayer(kind: .text, text: "A", startMs: 0, endMs: 10_000)]
  let s = make(opened)
  s.setText(opened[0].id, text: "A", style: opened[0].style)
  s.slide(opened[0].id, to: 500); s.endGesture()
  s.addText("   ", style: .standard)
  XCTAssertFalse(s.canUndo); XCTAssertEqual(saved, [])
  s.addText("B", style: .standard); s.delete(opened[0].id); s.cancel()
  XCTAssertEqual(s.layers, opened); XCTAssertEqual(saved.last, opened); XCTAssertFalse(s.canUndo)
}
```
- `captions sit under text and keep their style and place` (D4, D24, D25)
```swift
func testOrderAndCaptionRules() {
  let s = make()
  s.addText("one", style: .standard); s.addText("two", style: .standard); s.addCaptions(transcript); s.addCaptions(transcript)
  XCTAssertEqual(s.layers.map(\.text), ["a", "b", "one", "two"])
  let a = s.layers[0]
  s.place(a.id, centre: .zero, scale: 3, rotation: 1); s.slide(a.id, to: 800); s.endGesture()
  XCTAssertEqual(s.layers[0], a, "b starts where a ends")
  s.setText(a.id, text: "A!", style: VideoLayerStyle.standard)
  XCTAssertEqual(s.layers[0].text, "A!"); XCTAssertEqual(s.layers[0].style, a.style)
  s.select(s.layers[2].id); s.seek(5000); s.split()
  XCTAssertEqual(s.layers.map(\.text), ["A!", "b", "one", "one", "two"])
  XCTAssertEqual(s.selectedId, s.layers[3].id)
  s.setText(s.layers[4].id, text: " ", style: .standard)
  XCTAssertEqual(s.layers.count, 4)
}
```
- `20 text layers is the limit; captions do not count` — captions added first (D15)
```swift
func testLimits() {
  for i in 0..<21 { XCTAssertEqual(s.canAddText, i < 20); s.addText("t\(i)", style: .standard) }
  s.seek(5000); XCTAssertEqual(s.layers.count, 22); XCTAssertFalse(s.canSplit)
  s.setText(s.layers[2].id, text: String(repeating: "x", count: 300), style: .standard); XCTAssertEqual(s.layers[2].text.count, 200)
  s.select(s.layers[0].id); s.seek(500); XCTAssertTrue(s.canSplit)
  s.seek(99_999); XCTAssertEqual(s.playheadMs, 10_000)
}
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoEditSessionTests`, see them fail**
- [ ] **Step 3: Implement `VideoEditSession`**
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): edit session with undo`

### Task 5: Drafts keep the edit, and imports get a draft
App: iphone
Phase: 2
Recipe: test-driven-development
Decisions: D16, D19, D28

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoDraftStore.swift:28-247` — the manifest's four optional keys, saving an edit, adopting an import
- Modify: `iphone/MakeReady/Services/Video/VideoCaptureEngine.swift:153-182` — the engine's edit save and adoption
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:22-44` — the two `VideoRecorderCapturing` requirements only
- Test: `iphone/MakeReadyCaptureTests/VideoDraftStoreTests.swift`; `iphone/MakeReadyCaptureTests/VideoRecorderModelTests.swift:14-76` (the spy)

**Interfaces:**
- Consumes: `VideoLayer.decodeLenient` (Task 2); `VideoTranscript`, `VideoSource`
- Produces:
  - `VideoDraft` gains `layers` (empty when none), `transcript` (optional), `source` (`.recording` when absent), `window` (optional seconds range)
  - `VideoDraftStore.save(layers:transcript:in:)` and `VideoDraftStore.adopt(imported:duration:window:settings:)` — both throw and return the draft; `VideoDraftStore.current(_:)` — the draft as on disk, or nil
  - `VideoRecorderCapturing`/`VideoCaptureEngine`: throwing `save(layers:transcript:)` (no draft → `VideoDraftError.noDraft`) and `adopt(imported:duration:window:settings:)`, both leaving `draft` current

**Behaviour:**
- each of the four keys that is absent or fails to decode reads as absent; so does a window that is not ascending and finite (D16, D28)
- every other manifest write keeps the four keys (D16)
- `adopt` writes settings, source `.imported` and window first, then moves the file in as the one segment; on failure the file is back in its place, the draft is gone and the error is thrown (D19)

**Tests:**
- `an edit survives a later settings save and a relaunch` — `back` is what `recoverable` gives (D16)
```swift
func testAnEditSurvives() throws {
  XCTAssertEqual(back.layers, layers); XCTAssertEqual(back.transcript, transcript)
  XCTAssertEqual(back.source, .recording); XCTAssertEqual(store.current(draft), back)
}
```
- `an old or damaged manifest keeps the recording` — `draft.json` edited on disk: `old` has none of the four keys; `bad` has layers of one valid ("ok") and one bad, transcript 7, source "hologram", window "x" (D16, D28)
```swift
func testOldAndDamagedManifests() throws {
  XCTAssertEqual(old.layers, []); XCTAssertNil(old.transcript); XCTAssertNil(old.window)
  XCTAssertEqual(bad.layers.map(\.text), ["ok"]); XCTAssertEqual(bad.segments.count, 1)
  XCTAssertNil(bad.transcript); XCTAssertEqual(bad.source, .recording); XCTAssertNil(bad.window)
}
```
- `adopting moves the file and keeps its window; a failure leaves it` — `draft` adopts `file` (300 s, 10…100); `blocked` is a store whose root is a file, refusing `other` (D19)
```swift
func testAdopt() throws {
  XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)); XCTAssertEqual(store.recoverable(), [draft])
  XCTAssertEqual(draft.source, .imported); XCTAssertEqual(draft.window, 10...100); XCTAssertEqual(draft.segments.map(\.duration), [300])
  XCTAssertThrowsError(try blocked.adopt(imported: other, duration: 1, window: nil, settings: VideoDraftSettings()))
  XCTAssertTrue(FileManager.default.fileExists(atPath: other.path))
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run iphone-xctest `VideoDraftStoreTests`, see them fail**
- [ ] **Step 3: Implement the store, `VideoCaptureEngine` and `VideoRecorderCapturing` changes**; the spy records calls and updates its `draft`
- [ ] **Step 4: Run `VideoDraftStoreTests`, `VideoRecorderModelTests`, `VideoCaptureEngineTests`** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): drafts keep the edit and imported clips`

### Task 6: `VideoLayerRenderer` — one renderer for preview and export
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D2, D9, D17, D18, D20, D22, D25

**Files:**
- Create: `iphone/MakeReady/Services/Video/VideoLayerRenderer.swift` — layer → C-092 view, its image, and placing images on a frame
- Test: `iphone/MakeReadyCaptureTests/VideoLayerRendererTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoLayer` (Task 2); `CanvasTextObject` (`iphone/MakeReadyUI/CanvasTextObject.swift:40`); the edit slot width in `d2m-api.md`
- Produces: `VideoLayerRenderer` (`@MainActor` class) with `drawn(_:frame:)` — layers and frame size, returns `DrawnLayer` values in order — and `view(for:)` — a layer's `CanvasTextObject`; `DrawnLayer` (Sendable): `image` CIImage with its extent at the origin, `centre`, `rotation`, `startMs`, `endMs`; `VideoLayerRenderer.compose(_:over:at:frame:)` — nonisolated static, returns the CIImage

**Behaviour:**
- each layer is C-092 in viewer mode in the edit slot's width, unrotated, rasterised at `scale × frame short side / 440` pixels per wu, with D22's inputs only (D20, D22)
- an image is reused while text, style, scale and frame size are unchanged (D18)
- `compose` draws the layers visible at ms, in array order, clipped to the frame; none visible returns the picture (D2, D9, D25)
- the image's middle goes to `(centre.x × width, (1 − centre.y) × height)`, rotated by `−rotation`: Core Image's y axis points up (D22)
- F9 (build-time risk): `ImageRenderer` at large scales is unproven — `testLargeScale` settles it. If blank or clipped, draw the same view through a `UIHostingController` into a `CGContext` at that scale; never a second text renderer (D22)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift:67-84`, `:149-163`

**Tests:** (`px(image, x, y)` is the colour over black at a unit point, y down; `block` is "████", red, size 60, 1000–2000 ms; `frame` 540×960; `blue` a picture of it; `shown(layers, ms)` draws and composes over `blue`)
- `drawn at its centre, only inside its window` (D2, D20)
```swift
func testPlaceAndWindow() {
  var l = block; l.centre = CGPoint(x: 0.5, y: 0.2)
  XCTAssertEqual(px(shown([l], 1500), 0.5, 0.2), .red)
  XCTAssertEqual(px(shown([l], 1500), 0.5, 0.8), .blue)
  XCTAssertEqual(shown([l], 1500).extent, CGRect(origin: .zero, size: frame))
  XCTAssertEqual([999, 2000].map { px(shown([l], $0), 0.5, 0.2) }, [.blue, .blue])
}
```
- `rotation is clockwise; later is on top; size follows the short side` (D20, D22, D25)
```swift
func testRotationOrderAndSize() throws {
  var l = block; l.text = "████████"; l.style.size = 30; l.rotation = .pi / 4
  XCTAssertEqual(px(shown([l], 1500), 0.5 + 60 / 540, 0.5 + 60 / 960), .red, "its right end points down")
  XCTAssertEqual(px(shown([l], 1500), 0.5 + 60 / 540, 0.5 - 60 / 960), .blue)
  var green = block; green.style.colour = "#00FF00"
  XCTAssertEqual(px(shown([block, green], 1500), 0.5, 0.5), .green)
  let heights = [frame, CGSize(width: 1920, height: 1080)].map { VideoLayerRenderer().drawn([block], frame: $0)[0].image.extent.height }
  XCTAssertEqual(heights[1] / heights[0], 2, accuracy: 0.05)
}
```
- `the same image everywhere, reused until the layer changes; large scales draw` — `moved` differs in centre, rotation and window, `reworded` in text, `big` is one block at scale 6 (D17, D18)
```swift
func testImages() {
  XCTAssertTrue(image(moved, r) === image(block, r)); XCTAssertFalse(image(reworded, r) === image(block, r))
  XCTAssertEqual(data(image(block, r)), data(image(block, VideoLayerRenderer())))
}
func testLargeScale() { XCTAssertEqual(px(shown([big], 1500), 0.5, 0.5), .red) }
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoLayerRendererTests`, see them fail**
- [ ] **Step 3: Implement `VideoLayerRenderer`**
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): one renderer for layers`

### Task 7: The export and the player item draw the layers
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D2, D18, D20, D22, D23

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoExporter.swift:30-166` — `layers` on export and player item, the frame size
- Test: `iphone/MakeReadyCaptureTests/VideoExporterTests.swift`

**Interfaces:**
- Consumes: `VideoLayerRenderer`, `DrawnLayer` (Task 6)
- Produces: `VideoExporter.export(segments:timeRange:filter:strength:layers:to:)` (layers default none); `VideoExporter.playerItem(segments:look:layers:)` taking a `VideoLayersBox` (default empty); `VideoLayersBox` (locked as `VideoLookBox` is): `drawn` and `startSeconds`; `VideoExporter.frameSize(of:)` — async throws, clips' URLs to the render size

**Behaviour:**
- layers are drawn above the filter in the same pass, at `compositionTime − window start` in ms (window start after intersecting with the clip) (D2, D20)
- the renderer runs on the main actor before the session starts; the frame handler only calls `compose` (D22)
- the no-drawing shortcut applies only with no layers; the existing cases prove that output is unchanged (D18)
- F1 (build-time risk): the pixel test covers place and time; the look is proven only on a device, owed to the human walk (D2)
- F2 (build-time risk): D18's 1.5× export budget is measured in the human walk; the report names it as owed (D18)

**Tests:** (`red(start, end)` is "████", red, size 60, centre 0.5/0.25; `area` is 0.45, 0.24, 0.1 × 0.02)
- `a red layer is drawn only in its window` — `out` is a 3 s blue 540×960 clip, Normal, `red(1000, 2000)` (D2)
```swift
func testLayersAreDrawnInTheirWindow() async throws {
  for (seconds, colour) in [(0.5, TestMovie.Colour.blue), (1.5, .red), (2.5, .blue)] {
    let shown = try await TestMovie.dominantColour(of: out.url, at: seconds, in: area)
    XCTAssertEqual(shown, colour)
  }
}
```
- `times count from the kept window` — seconds 2–4 of a green 960×540 clip, Vivid, `red(0, 1000)` (D20)
```swift
func testLayerTimesCountFromTheWindow() async throws {
  let early = try await TestMovie.dominantColour(of: out.url, at: 0.5, in: area), late = try await TestMovie.dominantColour(of: out.url, at: 1.5, in: area)
  XCTAssertEqual([early, late], [.red, .green]); XCTAssertEqual(frame, CGSize(width: 960, height: 540))
}
```
- `the player item draws what the box holds` — `itemColour` reads a frame of an item on a blue 540×960 clip through an `AVAssetImageGenerator` with its composition, before and after `box.drawn` is set to `red(0, 2000)` drawn (D23)
```swift
func testPlayerItemDrawsTheBox() async throws { XCTAssertEqual([before, after], [.blue, .red]) }
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run iphone-xctest `VideoExporterTests`, see them fail**
- [ ] **Step 3: Implement the `VideoExporter` changes and `VideoLayersBox`**
- [ ] **Step 4: Run again** — PASS, the existing cases included
- [ ] **Step 5: Commit** — `feat(video-editor): export draws the layers`

### Task 8: Transcribe the clip being edited
App: iphone
Phase: 3
Recipe: test-driven-development
Decisions: D11, D21

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoExporter.swift` — the clip's sound as `.m4a`
- Modify: `iphone/MakeReady/Services/Video/VideoTranscriber.swift:19-67` — entries for an audio file and for clips
- Test: `iphone/MakeReadyCaptureTests/VideoTranscriberTests.swift`; `iphone/MakeReadyCaptureTests/VideoExporterTests.swift`

**Interfaces:**
- Produces: `VideoExporter.exportSound(segments:timeRange:to:)` async throws; `VideoExportError.noSound`; `VideoTranscriber.transcribe(audio:timeout:)` and `VideoTranscriber.transcribe(clips:window:timeout:)` (optional seconds range), both async to an optional `VideoTranscript`

**Behaviour:**
- the sound comes from the joined composition, its audio mix and the window, with `AVAssetExportPresetAppleM4A`; no audio track throws `.noSound` (D21)
- the clips entry puts one timeout over export and transcription, deletes its file, and answers nil on failure, timeout, cancellation or blank text; times count from the window's start (D11, D21)
- `transcribe(video:timeout:)` behaves as today (D11)

**Tests:**
- `the window's sound is one m4a; silence is refused` — seconds 1–3 of two 2 s clips; `silent` is a `TestMovie` with `audio: false` (D21)
```swift
func testExportSound() async throws {
  XCTAssertEqual(seconds, 2, accuracy: 0.2); XCTAssertTrue(videoTracks.isEmpty)
  do { try await VideoExporter.exportSound(segments: [silent], timeRange: nil, to: tmp("n.m4a")); XCTFail("expected noSound") }
  catch { XCTAssertEqual(error as? VideoExportError, .noSound) }
}
```
- `clips are transcribed; blank text and a timeout are nil` — `heard` is seconds 1–3 of two 2 s clips through `FileTranscriber`, `blank` its answer " ", `late` a `SlowTranscriber` of 5 s with a 1 s timeout (D11, D21)
```swift
func testTranscribesClips() async throws {
  XCTAssertEqual(heard?.text, "hi"); XCTAssertEqual(core.seconds ?? 0, 2, accuracy: 0.2)
  XCTAssertNil(blank); XCTAssertNil(late)
}
```

- [ ] **Step 1: Write the tests**
- [ ] **Step 2: Run iphone-xctest for both files, see them fail**
- [ ] **Step 3: Implement `exportSound` and both entries**, sharing the existing timeout race
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): transcribe the clip being edited`

### Task 9: Save draws the layers and sends the corrected transcript
App: iphone
Phase: 3
Recipe: ios-error-surface
Decisions: D2, D11, D12, D26, D27

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoSaver.swift:64-262` — layers and transcript from the manifest, the export and the queue protocol
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift`

**Interfaces:**
- Consumes: `VideoDraftStore.current` (Task 5); `VideoCaptions.corrected` (Task 3); `VideoExporter.export` (Task 7)
- Produces: `VideoSaver.Export` gains the layers before the destination; `VideoSaveQueue.enqueue` gains an optional `transcript`, and its `transcriptHold` becomes optional

**Behaviour:**
- layers and transcript are read from the manifest on disk when the work starts (D27)
- with a transcript: enqueue `VideoCaptions.corrected` of it, no hold, no transcription; if the queue already took the video, only discard the draft (D12, D26, D27)
- without one: hold, transcribe and supply as today, layers drawn all the same (D27)

**Tests:** (`ExportSpy.Call` gains `layers`, `QueueSpy.Item` gains `transcript` with an optional hold; `edited(transcript)` is a 4 s draft holding a title and, with a transcript, its captions, the first reworded "John"; `heard` is one segment "Jon"; `plusSave` a plus-menu save)
- `a save draws the layers and enqueues the corrected transcript` — once by `start`, once by `markSaving` then `resume`, settled (D12, D27)
```swift
func testSaveWithATranscript() async throws {
  for resumed in [false, true] {
    let (queue, layers) = try await saved(resumed: resumed)
    XCTAssertEqual(exporter.calls.last?.layers, layers); XCTAssertEqual(queue.items.map(\.transcript?.text), ["John"])
    XCTAssertNil(queue.items[0].holdsForTranscript); XCTAssertEqual(transcriptTimeouts, []); XCTAssertEqual(queue.supplied, [])
  }
}
```
- `layers without a transcript still transcribe after enqueue` — `edited(nil)` saved, the transcriber answering `heard` (D27)
```swift
func testSaveWithoutATranscript() async throws {
  XCTAssertEqual(exporter.calls.map(\.layers), [layers]); XCTAssertEqual(queue.supplied, [heard])
  XCTAssertNotNil(queue.items[0].holdsForTranscript); XCTAssertNil(queue.items[0].transcript)
}
```

- [ ] **Step 1: Write the tests and extend the spies**
- [ ] **Step 2: Run iphone-xctest `VideoRecorderSaveTests`, see them fail**
- [ ] **Step 3: Implement the `VideoSaver` changes**
- [ ] **Step 4: Run again** — PASS, the existing cases included
- [ ] **Step 5: Commit** — `feat(video-editor): Save draws the layers and sends the corrected transcript`

### Task 10: A player the editor can drive
App: iphone
Phase: 4
Recipe: test-driven-development
Decisions: D20, D22, D23

**Files:**
- Modify: `iphone/MakeReady/Services/Video/VideoReviewPlayer.swift:28-115` — pause, seek, time, end, looping choice and layers
- Test: `iphone/MakeReadyCaptureTests/VideoReviewPlayerTests.swift` (new); `iphone/MakeReadyCaptureTests/VideoRecorderSaveTests.swift:48-63` (the spy)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register

**Interfaces:**
- Consumes: `VideoLayersBox`, `VideoExporter.playerItem`, `VideoExporter.frameSize` (Task 7); `VideoLayerRenderer` (Task 6)
- Produces: `VideoReviewPlaying` gains `loops` and `autoplays` (Bool, default true), `pause`, `seek(to:)` and `currentTime` (seconds from the window's start), `onEnd` (optional closure), `show(layers:)`

**Behaviour:**
- `show(layers:)` draws them into the picture at the clips' frame size, window-relative; before a load it applies when the load ends; a paused player redraws its frame; `stop` forgets them (D20, D22, D23)
- with `loops` false it stops at the end, calls `onEnd`, and `play` there starts at 0 (D23)
- `seek` is exact and does not start playback; `currentTime` is clamped to the window; with `autoplays` false a load stays paused (D23)

**Tests:** (`until` polls every 20 ms for at most 5 s; `session` is a no-op `MemoPlaybackSessionControlling`)
- `time, seek, pause and the end count from the window's start` — a 4 s clip loaded with window 1…3, `loops` and `autoplays` false, `ends` counting `onEnd` (D20, D23)
```swift
func testDriving() async throws {
  p.seek(to: 1.5)
  try await until { abs(p.currentTime - 1.5) < 0.05 }
  XCTAssertEqual(try XCTUnwrap(p.item).currentTime().seconds, 2.5, accuracy: 0.05)
  p.play(); p.pause()
  let held = p.currentTime
  try await Task.sleep(for: .milliseconds(300))
  XCTAssertEqual(p.currentTime, held, accuracy: 0.05)
  p.play()
  try await until { ends == 1 }
  XCTAssertEqual(p.currentTime, 2, accuracy: 0.1)
  p.play()
  try await until { p.currentTime < 1 }
}
```
- `layers shown before a load are drawn` — `middle(p)` is `TestMovie.itemColour` (moved from `VideoExporterTests`) of the centre at 1 s of a blue clip; `block` is red "████" (D23)
```swift
func testShowsLayers() async throws {
  p.show(layers: [block]); try await p.load(clips: [clip], window: nil, look: VideoLook())
  let drawn = try await middle(p); p.show(layers: [])
  let bare = try await middle(p)
  XCTAssertEqual([drawn, bare], [.red, .blue])
}
```

- [ ] **Step 1: Write the tests; register the file**
- [ ] **Step 2: Run iphone-xctest `VideoReviewPlayerTests`, see them fail**
- [ ] **Step 3: Implement the `VideoReviewPlayer` changes**; the spy records `pauses`, `seeks`, `plays`, `shownLayers` and has a settable `currentTime`
- [ ] **Step 4: Run them and `VideoRecorderSaveTests`** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): review player pauses, seeks and draws layers`

### Task 11: `VideoEditorModel` — the editor without a screen
App: iphone
Phase: 4
Recipe: test-driven-development
Decisions: D3, D4, D7, D8, D11, D14, D15, D20, D21, D23, D30

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoEditorModel.swift` — playback, text tool, captions and leaving
- Test: `iphone/MakeReadyCaptureTests/VideoEditorModelTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoEditSession` (Task 4); `VideoReviewPlaying` (Task 10)
- Produces `VideoEditorModel` (`@MainActor @Observable`), made from a `Clip` (`urls`, optional `window`, kept `duration`, `frame`, `look`), layers, optional transcript, player, `transcribe` (async closure to an optional transcript), `save` (closure: layers, optional transcript), `report` and `sleep`:
  - read: `session`, `isPlaying`, `captions` (`.off`, `.transcribing`, `.added`, `.unavailable`), `textTool` (nil, or `id` optional, `text`, `style`, `offersStyle`), `limitMessage`, `offersRemoveCaptions`, `confirmsCancel`, `isClosed`, `playerLayer`, settable `onFinished` (takes the layers)
  - `open`, `playTapped`, `tick`, `scrub(toMs:)`, `gestureEnded`, `textTapped`, `editTapped`, `commitText(_:style:)`, `captionsTapped`, `captionsSettled` (async), `removeCaptionsConfirmed`, `cancelTapped`, `cancelConfirmed`, `dismissConfirm`, `doneTapped`, `backgrounded`
  - `captionsReason` — d2m's copy, else "Captions aren't available for this video"; `limitText` "Up to 20 text layers"

**Behaviour:**
- `open` loads the player with `loops` and `autoplays` false and never gives it layers; a failure is reported "Couldn't play this video" (D23, D20)
- while playing, `tick` moves the playhead; at the end it stops with the playhead at the clip's end; scrub, the text tool and `backgrounded` pause (D3, D8, D23)
- the 21st Text tap opens nothing and sets `limitMessage`; `offersStyle` is false for a caption (D4, D8, D15)
- Captions with captions present offers Remove; with a kept transcript adds at once; else transcribes, keeps the transcript through `save` and adds (D4, D11, D30)
- nil, or no caption resulting → `.unavailable`, nothing added or saved; a later tap tries again; a tap while transcribing does nothing (D11, D21)
- Done, Cancel and `backgrounded` cancel it: `.off`, a late answer dropped (D21)
- every session change saves layers and transcript (D30)
- Cancel closes at once with an empty history, else confirms, then restores and saves the layers at Edit; a made transcript stays (D14, D30)
- closing stops the player and calls `onFinished` once (D7, D23)

**Tests:** (`make(layers, answers:, held:)` is a 10 s clip over `ReviewPlayerSpy`, counting `asked`, recording `saves`; `held` answers wait for `release`; `t` has "a" 0–1000 and "b" 1000–2000)
- `captions are transcribed once and kept through Cancel` (D4, D11, D30)
```swift
func testCaptions() async {
  let m = make(answers: [t])
  m.captionsTapped(); XCTAssertEqual(m.captions, .transcribing)
  m.captionsTapped(); await m.captionsSettled()
  XCTAssertEqual(m.captions, .added); XCTAssertEqual(m.session.layers.map(\.text), ["a", "b"]); XCTAssertEqual(saves.last?.transcript, t)
  m.captionsTapped(); XCTAssertTrue(m.offersRemoveCaptions)
  m.removeCaptionsConfirmed(); XCTAssertEqual(m.captions, .off); XCTAssertEqual(m.session.layers, [])
  m.captionsTapped(); XCTAssertEqual(m.captions, .added)
  m.cancelTapped(); XCTAssertTrue(m.confirmsCancel)
  m.cancelConfirmed()
  XCTAssertTrue(m.isClosed); XCTAssertEqual(saves.last?.layers, []); XCTAssertEqual(saves.last?.transcript, t); XCTAssertEqual(asked, 1)
}
```
- `no transcript adds nothing and a tap tries again` (D11, D21)
```swift
func testCaptionsUnavailable() async {
  let m = make(answers: [nil, VideoTranscript(text: " ", segments: []), t])
  for expected in [VideoEditorModel.Captions.unavailable, .unavailable, .added] {
    XCTAssertTrue(saves.isEmpty); XCTAssertFalse(m.session.canUndo)
    m.captionsTapped(); await m.captionsSettled()
    XCTAssertEqual(m.captions, expected)
  }
}
```
- `leaving or backgrounding cancels the transcription` (D21)
```swift
func testLeavingCancelsTranscribing() async {
  for leave in [{ (m: VideoEditorModel) in m.backgrounded() }, { $0.doneTapped() }, { $0.cancelTapped() }] {
    let m = make(answers: [t], held: true)
    m.captionsTapped(); leave(m)
    XCTAssertEqual(m.captions, .off)
    release(); await m.captionsSettled()
    XCTAssertEqual(m.session.layers, []); XCTAssertTrue(saves.isEmpty)
  }
}
```
- `playback follows the player, stops at the end and pauses` (D3, D8, D23)
```swift
func testPlayback() {
  let m = make(); m.open()
  XCTAssertFalse(player.loops || player.autoplays)
  m.playTapped(); player.currentTime = 1.25; m.tick()
  XCTAssertEqual(m.session.playheadMs, 1250)
  m.scrub(toMs: 2000); XCTAssertFalse(m.isPlaying); XCTAssertEqual(player.seeks.last, 2)
  m.playTapped(); player.onEnd?()
  XCTAssertFalse(m.isPlaying); XCTAssertEqual(m.session.playheadMs, 10_000)
  m.playTapped(); m.textTapped(); XCTAssertFalse(m.isPlaying)
  m.commitText("Hi", style: .standard)
  m.playTapped(); m.backgrounded(); XCTAssertFalse(m.isPlaying)
  XCTAssertTrue(player.shownLayers.isEmpty)
}
```
- `the text tool adds, edits, hides style for captions and refuses the 21st` (D4, D8, D15)
```swift
func testTextTool() async {
  let m = make(answers: [t])
  m.textTapped(); XCTAssertEqual(m.textTool?.text, "")
  m.commitText("Title", style: .standard); XCTAssertNil(m.textTool)
  m.editTapped(); XCTAssertEqual(m.textTool?.text, "Title"); XCTAssertEqual(m.textTool?.offersStyle, true)
  m.commitText("", style: .standard); XCTAssertEqual(m.session.layers, [])
  m.captionsTapped(); await m.captionsSettled()
  m.session.select(m.session.layers[0].id); m.editTapped(); XCTAssertEqual(m.textTool?.offersStyle, false)
  m.commitText("A", style: .standard)
  for i in 0..<20 { m.textTapped(); m.commitText("t\(i)", style: .standard) }
  XCTAssertNil(m.limitMessage)
  m.textTapped(); XCTAssertNil(m.textTool); XCTAssertEqual(m.limitMessage, "Up to 20 text layers")
}
```
- `Done keeps; Cancel without a change closes at once; a dismissed confirm stays` (D7, D14)
```swift
func testLeaving() {
  let m = make(); m.onFinished = { finished.append($0) }
  m.cancelTapped(); m.doneTapped()
  XCTAssertFalse(m.confirmsCancel); XCTAssertEqual(finished, [[]]); XCTAssertEqual(player.stops, 1)
  let n = make(); n.textTapped(); n.commitText("Title", style: .standard)
  n.cancelTapped(); n.dismissConfirm(); XCTAssertFalse(n.isClosed)
  n.doneTapped(); XCTAssertEqual(saves.last?.layers.map(\.text), ["Title"])
}
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoEditorModelTests`, see them fail**
- [ ] **Step 3: Implement `VideoEditorModel`**
- [ ] **Step 4: Run again** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): editor model`

### Task 12: Review's Edit in the recorder's model
App: iphone
Phase: 4
Recipe: ios-error-surface
Decisions: D7, D11, D16, D19, D23, D27, D28

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderModel.swift:196-330,520-760` — the editor, recovery, Retake, Save
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift` (`live`) — the editor's player and transcriber
- Test: `iphone/MakeReadyCaptureTests/VideoRecorderEditTests.swift` (new); `iphone/MakeReadyCaptureTests/VideoRecorderModelTests.swift` (doubles)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register

**Interfaces:**
- Consumes: `VideoEditorModel` (Task 11); the engine's `adopt` and `save(layers:transcript:)`, `VideoDraft` (Task 5); `show(layers:)` (Task 10); `VideoExporter.frameSize` (Task 7); `VideoTranscriber.transcribe(clips:window:timeout:)` (Task 8)
- Produces: `VideoRecorderModel` gains `editor` (optional), `editTapped` (async), `editorHidden`, `layers`, `canEdit`, and an init parameter `makeEditor` (clip, layers, optional transcript, save closure; async throws to a `VideoEditorModel`) with a live default

**Behaviour:**
- `canEdit`: in Review, nothing saving, no editor open (D7)
- `editTapped` waits for the engine, adopts an import that has no draft (`importedClip.url` becomes the draft's file), stops Review's player and opens the editor on the draft's layers and transcript; a failure is reported "Couldn't open the editor" and Review plays on (D7, D19, D23)
- an editor save goes to the engine; a failed write is logged with `Log.media`, never reported, and memory keeps the layers (D16, D28)
- when the editor finishes, Review's player reloads with the layers; `editorHidden` drops the editor (D7, D23)
- while it is open, the foreground does not play Review's player and `backgrounded` reaches the editor (D23)
- `open`: an imported draft restores `importedClip` and `trimWindow` in Review; a recording with layers or a transcript opens Review with them; else paused as today. `syncTimeline` skips an imported draft (D16, D19)
- Retake and Discard delete the draft, the import and the layers (D7, D19)
- Save with a draft first writes the edit again; if that throws, "Couldn't save your video" and the recorder stays open. An adopted import saves as `.draft`, source `.imported`, with its window; an unedited one as `.file` (D19, D27)
- the live editor transcribes with a 60 s timeout (D11)

**Tests:** (`model(entry:editorFails:)` runs over a real engine and store as `VideoRecorderSaveTests.makeModel` does; `saver` records saves and clips; the editor gets its own `ReviewPlayerSpy`; `inReview` records 4 s, calls `done` and settles)
- `an edit reaches Review, the draft and Save, and Edit resumes it` (D7, D16, D27)
```swift
func testEditARecording() async throws {
  let m = model(); await inReview(m); XCTAssertTrue(m.canEdit)
  await m.editTapped(); XCTAssertFalse(m.canEdit); XCTAssertEqual(player.stops, 1)
  m.editor?.textTapped(); m.editor?.commitText("Title", style: .standard); m.editor?.doneTapped()
  XCTAssertEqual(player.shownLayers.last?.map(\.text), ["Title"])
  m.editorHidden(); XCTAssertNil(m.editor)
  await m.editTapped(); XCTAssertEqual(m.editor?.session.layers.map(\.text), ["Title"])
  m.editor?.cancelTapped(); m.editorHidden()
  await m.save()
  guard case let .draft(draft)? = saver.clips.first else { return XCTFail("a draft") }
  XCTAssertEqual(drafts.current(draft)?.layers.map(\.text), ["Title"])
}
```
- `the first Edit on an import moves it into a draft that saves as imported` — `m` is a lesson's import of 300 s trimmed to 10…100, Edit then Done; `plain` an import saved unedited (D19)
```swift
func testEditAnImport() async throws {
  let draft = try XCTUnwrap(drafts.recoverable(for: lesson).first)
  XCTAssertEqual(draft.source, .imported); XCTAssertEqual(draft.window, 10...100)
  XCTAssertEqual(m.importedClip?.url, draft.segments[0].url); XCTAssertEqual(m.screenState.segments, [])
  await m.save()
  XCTAssertEqual(saver.saves.last?.source, .imported); XCTAssertEqual(saver.saves.last?.window, 10...100)
  guard case .draft? = saver.clips.last else { return XCTFail("a draft") }
  await plain.save()
  guard case .file? = saver.clips.last else { return XCTFail("a file") }
}
```
- `a kill mid-edit comes back to Review; Retake clears it` — `plain` opens on a recording with no edit, `m` on one with `layers`, `n` on an import adopted at 300 s, 10…100 (D16, D19)
```swift
func testRecovery() async throws {
  XCTAssertEqual(plain.screenState.phase, .paused)
  XCTAssertEqual(m.screenState.phase, .review); XCTAssertEqual(m.layers, layers); XCTAssertEqual(player.shownLayers.last, layers)
  XCTAssertEqual(n.screenState.phase, .review); XCTAssertEqual(n.screenState.segments, [])
  XCTAssertEqual(n.trimWindow, 10...100); XCTAssertEqual(n.importedClip?.duration, 300)
  n.retakeConfirmed(); await n.settled()
  XCTAssertNil(n.importedClip); XCTAssertEqual(drafts.recoverable(), [])
}
```
- `opening fails loudly, a failed write is silent, at Save it is reported; the background reaches the editor` — `m`'s editor fails; `n` is being edited and playing (D19, D23, D27, D28)
```swift
func testFailuresAndBackground() async throws {
  XCTAssertNil(m.editor); XCTAssertEqual(reports, ["Couldn't open the editor"]); XCTAssertEqual(m.screenState.phase, .review)
  reports = []; n.backgrounded(); n.becameActive()
  XCTAssertEqual(n.editor?.isPlaying, false); XCTAssertEqual(player.plays, plays)
  for draft in drafts.recoverable() { try FileManager.default.removeItem(at: draft.folder) }
  n.editor?.textTapped(); n.editor?.commitText("T", style: .standard)
  XCTAssertEqual(reports, []); XCTAssertEqual(n.layers.count, 1)
  n.editor?.doneTapped(); n.editorHidden(); await n.save()
  XCTAssertEqual(reports, ["Couldn't save your video"]); XCTAssertFalse(n.isClosed)
}
```

- [ ] **Step 1: Write the tests; register the file**
- [ ] **Step 2: Run iphone-xctest `VideoRecorderEditTests`, see them fail**
- [ ] **Step 3: Implement the `VideoRecorderModel` changes and the live `makeEditor`**
- [ ] **Step 4: Run them, `VideoRecorderModelTests` and `VideoRecorderSaveTests`** — PASS
- [ ] **Step 5: Commit** — `feat(video-editor): Edit in the recorder's model`

### Task 13: The editor's container over d2m's screen
App: iphone
Phase: 5
Recipe: present-overlay
Decisions: D1, D3, D4, D5, D8, D9, D13, D14, D20, D22, D24, D29, D30

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoEditorMapper.swift` — model values → `VideoEditorScreen.State`
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoEditorContainer.swift` — the screen, its callbacks, filmstrip and confirms
- Test: `iphone/MakeReadyCaptureTests/VideoEditorMapperTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoEditorScreen` (names from `d2m-api.md`); `VideoEditorModel` (Task 11)
- Produces: `VideoEditorContainer` taking the model; `VideoEditorMapper.state(of:filmstrip:)`, `VideoEditorMapper.trackLabel(_:)`, `VideoEditorMapper.style(_:)` both ways; `VideoFilmstrip.frames(of:window:count:)` async to images

**Behaviour:**
- text tracks newest on top, captions on one track below; the preview shows only layers visible at the playhead (D3, D24)
- Split and Undo follow `canSplit` and `canUndo` (D13, D14)
- a track's accessibility label is its text and window, seconds rounded down: "Title, 0:00 to 0:12" (D3)
- the Remove captions offer and the Cancel confirm are destructive `ActionMenuOverlay`s drawn in place (D4, D14, D29)
- screen gestures call the session's live changes, their end `gestureEnded`; the delete target calls `delete` (D1, D9, D30)
- filmstrip frames fill in as they are read from the window; an unreadable one stays the placeholder (D3)
- the keyboard inset is measured on un-offset chrome with `.ignoresSafeArea(.keyboard)` (D8, `.claude/builder.md` standing trap)
- no `MakeReadyUI` edit; a gap goes back to d2m (D5)

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift` — `confirmMenu`, `followKeyboard`

**Tests:** (`textTracks`, `captionTrack`, `previewTexts` read d2m's `State`; `make(layers)` is Task 11's model)
- `tracks, labels, preview and controls` (D3, D13, D14, D24)
```swift
func testState() {
  let m = make([VideoLayer(kind: .caption, text: "a", startMs: 0, endMs: 1000), VideoLayer(kind: .text, text: "Old", startMs: 0, endMs: 12_900),
                VideoLayer(kind: .text, text: "New", startMs: 61_000, endMs: 75_000)])
  var state = VideoEditorMapper.state(of: m, filmstrip: [])
  XCTAssertEqual(textTracks(state), ["New", "Old"]); XCTAssertEqual(captionTrack(state), ["a"]); XCTAssertEqual(previewTexts(state), ["a", "Old"])
  XCTAssertEqual(m.session.layers.dropFirst().map(VideoEditorMapper.trackLabel), ["Old, 0:00 to 0:12", "New, 1:01 to 1:15"])
  XCTAssertFalse(state.canSplit); XCTAssertFalse(state.canUndo)
  m.session.select(m.session.layers[1].id); m.session.seek(5000)
  state = VideoEditorMapper.state(of: m, filmstrip: [])
  XCTAssertTrue(state.canSplit); XCTAssertEqual(previewTexts(state), ["Old"])
  m.session.split()
  XCTAssertTrue(VideoEditorMapper.state(of: m, filmstrip: []).canUndo)
}
```
- `a style goes to the screen and back unchanged` — every font × background, left, "#3EA6FF", 51 wu (D22)
```swift
func testStyleRoundTrip() { for s in styles { XCTAssertEqual(VideoEditorMapper.style(VideoEditorMapper.style(s)), s) } }
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoEditorMapperTests`, see them fail**
- [ ] **Step 3: Implement `VideoEditorMapper`, `VideoFilmstrip` and `VideoEditorContainer`**
- [ ] **Step 4: Run again** — PASS; `swiftlint` from `iphone/` adds no finding
- [ ] **Step 5: Run `/transition-review` on the diff** and fix every FAIL
- [ ] **Step 6: Commit** — `feat(video-editor): editor container`

### Task 14: Edit on Review, in both entry points
App: iphone
Phase: 5
Recipe: present-overlay
Decisions: D2, D7, D10, D20, D23, D29

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Video/VideoEditorPresentation.swift` — the overlay, hosted or in place
- Modify: `iphone/MakeReady/UI2/Containers/Video/VideoRecorderContainer.swift:71-130,236-264` — Review's Edit and the presentation
- Test: `iphone/MakeReadyCaptureTests/VideoEditorPresentationTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register + `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `VideoRecorderModel` (Task 12); `VideoEditorContainer` (Task 13); `VideoRecorderScreen`'s Edit input (`d2m-api.md`)
- Produces: `videoEditorPresentation(model:)` — a view modifier taking the `VideoRecorderModel`

**Behaviour:**
- hosted where `ui2HostsOverlays` is true, in place where false; full screen in both; inside it `ui2HostsOverlays` is false (D10, D29)
- it slides itself on `Token.Motion.sheetPresent`, stays mounted until the slide-out ends, then calls `editorHidden`; escape is Cancel (D29)
- Edit shows in Review only, where d2m placed it, disabled when `canEdit` is false (D7)
- from a lesson, Done and Cancel return to the same inline recorder, neither closed nor rebuilt (D10)
- Review keeps its aspect-fill crop; the layers are in the player's picture (D20, D23)
- the report names which steps of SPEC §Testing's cross-app walk a simulator can do (the import ones) and which are owed to a real iPhone (D2)

**Pattern:**
- `iphone/MakeReadyUI/ActionMenuPresentation.swift:115-150`; `VideoRecorderOverlay` (the slide); `iphone/MakeReadyCaptureTests/UI2ErrorBannerHostTests.swift` (the test window)

**Tests:** (`reviewModel` is Task 12's test model in Review; `show` puts a view in a window; `until` as in Task 10's tests)
- `handed up only where something hosts` — `handedUp(hosted)` opens Edit on a `Color.clear` carrying the modifier under that `ui2HostsOverlays` and reads `UI2HostedOverlayKey` with `overlayPreferenceValue` (D29)
```swift
func testPlacement() async throws {
  for hosted in [false, true] { let up = try await handedUp(hosted); XCTAssertEqual(up, hosted) }
}
```
- `the editor is dropped after it slides out` — drawn in place, Edit then Done (D10, D29)
```swift
func testHiddenAfterDone() async throws {
  try await until { m.editor == nil }
  XCTAssertFalse(m.isClosed); XCTAssertEqual(m.screenState.phase, .review)
}
```

- [ ] **Step 1: Write the tests; register the files**
- [ ] **Step 2: Run iphone-xctest `VideoEditorPresentationTests`, see them fail**
- [ ] **Step 3: Implement `videoEditorPresentation` and Review's Edit**
- [ ] **Step 4: Run them and the whole iphone-xctest suite** — PASS; `swiftlint` from `iphone/` adds no finding
- [ ] **Step 5: Run `/transition-review` on the diff** and fix every FAIL
- [ ] **Step 6: Commit** — `feat(video-editor): Edit opens the editor from Review`
