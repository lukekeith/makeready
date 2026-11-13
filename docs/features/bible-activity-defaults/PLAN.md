# Bible activity defaults — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** new Bible activities start as black Playfair Display (font key `classic`) on a white page, and `classic` is a fifth font for all canvas text.

**Architecture:** the server's activity-document zod enum gains `classic` (the contract, frozen at Phase 1's close). On the iPhone, d2m adds the face to its components (C-092 font set, C-035 chip sample, editor and player screens) through one handover request. The app side maps the key and changes `BibleScripture`'s defaults.

**Tech Stack:** server — TypeScript, zod, vitest, fixtures runner · iphone — SwiftUI, XCTest, bundled TTFs, d2m channel.

**Spec:** docs/features/bible-activity-defaults/SPEC.md

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(bible-activity-defaults): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1 | the server accepts `classic`; Bible fixtures use the new defaults; contract frozen |
| 2 | iphone | 2–3 | Playfair Display drawn everywhere a font key is, and new Bible activities default to classic · #000000 · #FFFFFF |

---

### Task 1: Accept the `classic` font key and restyle the Bible fixture
App: server
Phase: 1
Recipe: test-driven-development · tiny

**Files:**
- Modify: `server/src/services/activity-document.ts:36` — the text object's `font` enum gains `'classic'`
- Modify: `server/fixtures/activity-documents.ts:13` — the helper's `font` union gains `'classic'`
- Modify: `server/fixtures/screens/bible-reader.ts:32-48` — `d10Document`: both text objects `font: 'classic'`, `color: '#000000'`; page `{ color: '#FFFFFF' }` (D8). `legacyDocument` untouched.
- Test: `server/src/services/__tests__/activity-document.test.ts` — classic accepted, unknown still refused

**Interfaces:**
- Produces: the frozen contract (SPEC §Contract), verbatim:

```
content.objects[].font ∈ 'display' | 'sans' | 'serif' | 'mono' | 'classic'
any other value → parseActivityDocument returns { ok: false, code: 'VALIDATION' }
```

**Behaviour:**
- `classic` validates on any kind's text object (D3, D5, SC1)
- a value outside the five keeps failing with the existing VALIDATION result (SPEC §Contract)
- the fixture helper default stays `'sans'` (D4)

**Pattern:**
- `server/src/services/__tests__/activity-document.test.ts:11` — the `text()` document builder; tests call `parseActivityDocument(doc, 'text')`

**Tests:**
- `a text object in the classic face validates` (D5)

```ts
it('a text object in the classic face validates', () => {
  const doc = text(); doc.content.objects[1].font = 'classic'
  const r = parseActivityDocument(doc, 'text')
  expect(r.ok).toBe(true)
  expect(r.ok && r.document.content.objects[1].font).toBe('classic')
})
```

- `a font key outside the five is still refused` (SPEC §Contract)

```ts
it('a font key outside the five is still refused', () => {
  const doc = text(); doc.content.objects[1].font = 'playfair'
  const r = parseActivityDocument(doc, 'text')
  expect(r.ok).toBe(false)
  expect(!r.ok && r.code).toBe('VALIDATION')
})
```

- [ ] **Step 1: Write the two tests** in `server/src/services/__tests__/activity-document.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/activity-document.test.ts`, watch the first fail** — classic refused
- [ ] **Step 3: Add `'classic'` to the enum and the fixture union; restyle `d10Document`** (D8)
- [ ] **Step 4: Run the test file and `cd server && npx --no-install tsc --noEmit -p fixtures`, watch them pass**
- [ ] **Step 5: `docker restart makeready-server`**
- [ ] **Step 6: Commit** — `feat(bible-activity-defaults): accept the classic font key`
- [ ] **Step 7: Record the freeze** — `advance.mjs docs/features/bible-activity-defaults --set "contract=frozen <YYYY-MM-DD>"` at the phase close

### Task 2: d2m adds Playfair Display to the canvas text components
App: iphone
Phase: 2
Recipe: REFERENCE §Design source — UI 2.0 (d2m-channel: check_project_change → request_project_change → wait_project_change)

**Files:**
- Create (by d2m): `iphone/MakeReadyUI/Resources/Fonts/PlayfairDisplay/` — PlayfairDisplay-Regular, -Medium, -Bold, -Italic, -MediumItalic, -BoldItalic .ttf + `OFL.txt` (D9)
- Modify (by d2m): `iphone/MakeReadyUI/CanvasTextObject.swift:41-44, 1031-1060, 1100-1110` — `Font.classic`, its face and registration, system fallback `.serif` (D9, D12)
- Modify (by d2m): `iphone/MakeReadyUI/FilterChip.swift:259-273` — `.classic` chip label in Playfair Display Regular (D12)
- Modify (by d2m): `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift:181, 2858-2875, 2980-2985` — `bibleFace` preview default `classic` (D11), key ⇄ Font, D5's five-item list labelled "Playfair Display"
- Modify (by d2m): `iphone/MakeReadyUI/Screens/Activities/ActivitiesPlayerScreen.swift:886-893` — `"classic"` → `.classic`
- Modify (by d2m): `iphone/MakeReadyCaptureTests/ViewRegistry.swift:1005-1012, 2830-2837` — `"classic"` → `.classic`

**Interfaces:**
- Produces: `CanvasTextObject.Font.classic` — the fifth case; `.classic.face(weight:italic:size:)` returns a Playfair Display `SwiftUI.Font`; the bundled PostScript names `PlayfairDisplay-Regular`, `PlayfairDisplay-Medium`, `PlayfairDisplay-Bold` (plus `…Italic`) are registered at first face lookup.

**Behaviour:**
- the editor's font strip lists, in order: Poppins (`display`), Inter (`sans`), Source Serif 4 (`serif`), Courier Prime (`mono`), Playfair Display (`classic`) — for the text and Bible tools alike (D5)
- weights 400/500/700 map to Regular/Medium/Bold (D9)
- no file under `iphone/MakeReadyUI/` is edited by hand (D10)

**Tests:**
- d2m's own preview captures of C-092, C-035 and the editor screen re-render with the fifth font; its report names them. Task 3's XCTests prove the face resolves.

```swift
// asserted in Task 3 (ActivityViewerMapperTests): the bundled face loads, not the system fallback
XCTAssertEqual(ActivityViewerMapper.measuringFont(key: "classic", weight: 400, size: 18).familyName, "Playfair Display")
```

- [ ] **Step 1: `check_project_change`** — subject C-092 CanvasTextObject (+ C-035 FilterChip, activities-editor, activities-player screens), kinds font/token, summary "add font key classic = Playfair Display"
- [ ] **Step 2: `request_project_change`** — intent: the Files and Behaviour above, with D5/D9/D11/D12 quoted as rulings; references: `docs/features/bible-activity-defaults/SPEC.md` on `main`
- [ ] **Step 3: `wait_project_change`** until done; settle each handback from SPEC §Decisions (answer_project_change / approve_project_change / retry_project_change); re-call on `timedOut`
- [ ] **Step 4: Confirm d2m's commit landed on the branch** — `git log -1 --stat` lists the font files and the five Swift files; build: `cd iphone && xcodebuild -project MakeReady.xcodeproj -scheme MakeReady -configuration Debug -destination 'generic/platform=iOS Simulator' build` succeeds
- [ ] **Step 5: No commit of our own** — d2m commits its change (D10)

### Task 3: Map `classic` app-side and default new Bible activities to it
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift:146` — `fontKeys` gains `"classic"`
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift:366-377` — `case "classic": UIFont(name: "PlayfairDisplay-\(style)", size:) ?? .systemFont`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift:183` — `"classic"` → `.classic`
- Modify: `iphone/MakeReady/UI2/Containers/Bible/BibleScripture.swift:84, 104-121, 236-247` — D1–D3
- Test: `iphone/MakeReadyCaptureTests/BibleScriptureTests.swift` — new defaults; update the three `"display"` asserts (:106, :108, :166)
- Test: `iphone/MakeReadyCaptureTests/BibleEditorTests.swift:322` — `bibleFace` expectation `"classic"` when `bibleDoc` comes from `BibleScripture.document`
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorMapperTests.swift`, `iphone/MakeReadyCaptureTests/ActivityViewerMapperTests.swift` — key kept, face resolves

**Interfaces:**
- Consumes: `CanvasTextObject.Font.classic` and the registered `PlayfairDisplay-*` faces (Task 2); the frozen contract (Task 1)
- Produces: `BibleScripture.document(for:background:)` — unchanged signature; nil background → `{ "color": "#FFFFFF" }`

**Behaviour:**
- scripture and citation objects: `font "classic"`, `color "#000000"` (D2, D3)
- nil background → `#FFFFFF`; a passed background is written as given (D1); `ActivityBackground.default` stays `#000000` (D1, D4)
- `height(of:)` measures with `measuringFont(key: "classic", weight: 400, …)` (D3)
- comments citing bible-verse-picker D44 now cite this spec's D3
- `fontKey("classic") == "classic"`; unknown keys still → `"sans"` (D6)

**Pattern:**
- `iphone/MakeReadyCaptureTests/BibleScriptureTests.swift:103-114` — `testTheDocumentUsesTheD10Layout`

**Tests:**
- `testANewBibleDocumentIsBlackClassicOnWhite` (D1–D3)

```swift
func testANewBibleDocumentIsBlackClassicOnWhite() {
    let doc = BibleScripture.document(for: Self.pick16b18, background: nil)
    XCTAssertEqual(doc.textObjects.map(\.font), ["classic", "classic"])
    XCTAssertEqual(doc.textObjects.map(\.color), ["#000000", "#000000"])
    XCTAssertEqual(doc.background?.color, "#FFFFFF")
}
```

- `testAPassedBackgroundIsKept` (D1)

```swift
func testAPassedBackgroundIsKept() {
    let bg = ActivityBackground(color: "#0E4A4D", image: nil, wash: nil, motion: nil)
    XCTAssertEqual(BibleScripture.document(for: Self.pick16b18, background: bg).background?.color, "#0E4A4D")
    XCTAssertEqual(ActivityBackground.default.color, "#000000")
}
```

- `testTheClassicKeyIsKept` (D6)

```swift
func testTheClassicKeyIsKept() {
    XCTAssertEqual(ActivitiesEditorMapper.fontKey("classic"), "classic")
    XCTAssertEqual(ActivitiesEditorMapper.fontKey("playfair"), "sans")
}
```

- `testTheClassicFaceIsPlayfairDisplay` (D9)

```swift
func testTheClassicFaceIsPlayfairDisplay() {
    XCTAssertEqual(ActivityViewerMapper.measuringFont(key: "classic", weight: 400, size: 18).familyName, "Playfair Display")
}
```

- [ ] **Step 1: Write the four tests; change the existing `"display"` asserts (BibleScriptureTests :106, :108, :166; BibleEditorTests :322) to `"classic"`**
- [ ] **Step 2: Run the iphone-xctest suite on these classes, watch them fail**
- [ ] **Step 3: Implement the Behaviour in the four app files**
- [ ] **Step 4: Run them again, watch them pass; `cd iphone && swiftlint` reports no new violations**
- [ ] **Step 5: Commit** — `feat(bible-activity-defaults): new Bible activities default to black Playfair Display on white`
