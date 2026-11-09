# text-activity-v2 — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** New activities open on a generated blob gradient, and the iPhone activity editor's tools become a sheet-free stack of rails above an always-visible tool row, with tap-off committing text edits.

**Architecture:** The gradient is an additive, optional field inside the activity document's `background` JSON. The server validates it (zod) and the iPhone app generates, decodes, edits and draws it. The editor's views are d2m-built (handover lane), so one task files the d2m requests and the app-side mapper, container, viewer mapper and thumbnail then code against what d2m returns.

**Tech Stack:** server — Express + zod + vitest. iphone — Swift/SwiftUI, `ActivityDocument` raw-JSON patching, XCTest in `MakeReadyCaptureTests`, d2m via the `d2m-channel` MCP server.

**Spec:** `docs/features/text-activity-v2/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(text-activity-v2): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1 | The server validates and round-trips `background.gradient`; the contract freezes |
| 2 | iphone | 2–5 | The app decodes, generates and edits gradients in documents; new activities start on one and still auto-delete when untouched |
| 3 | iphone | 6 | d2m has built the rails, Idle tools, tap-off, padding, disabled IconButton and gradient drawing |
| 4 | iphone | 7–9 | The editor, viewer and thumbnails are wired to d2m's new views and the document operations |

---

### Task 1: Validate `background.gradient` on the server
App: server
Phase: 1
Recipe: /api · tiny

**Files:**
- Modify: `server/src/services/activity-document.ts:153-166` — add `gradient` to the `background` zod object
- Modify: `docs/features/activity-viewer/02-content-schema.md` §5 (`:133-170`) and §11 (`:247`) — document the field
- Test: `server/src/services/__tests__/activity-document.test.ts` — round-trip and every bound

**Interfaces:**
- Consumes: the `hex` and `unit` helpers (`activity-document.ts:23-24`); `parseActivityDocument(input, kind)` returns `{ ok: true, document }` or `{ ok: false, code: 'VALIDATION', error }`.
- Produces: the frozen contract —

```ts
// background.gradient (optional), every object .passthrough()
gradient?: {
  style: 'blobs'
  base: '#RRGGBB'
  hidden?: boolean
  blobs: Array<{ x: number /* 0–1 */, y: number /* 0–4 */, r: number /* 0–1 */, color: '#RRGGBB' }> // 1–8 entries
}
```

**Behaviour:**
- `gradient` is optional; a document without it parses exactly as before (SC1, D5)
- `style` must be the literal `"blobs"`; `base` and each blob `color` must match `hex`; `x` and `r` use `unit`; `y` is 0–4; `blobs` has 1–8 entries; `hidden` is an optional boolean (§Contract, D17, D14)
- unknown keys inside `gradient` and inside each blob are kept (§Contract)
- every failure is `code: 'VALIDATION'` through the existing `describeIssue` path (§Contract)
- 02 §5 gains `gradient` in its JSON block, the draw order `color`, `gradient`, `image`, `wash`, content (D1), the geometry (fractions of the page box's width, radial `color` → transparent at `r`, D2), `base` and `hidden` (D14, D17); §11 gains one gradient example

**Tests:**
- `accepts a blob gradient and returns it unchanged, unknown keys included` (SC1)

```ts
it('accepts a blob gradient and returns it unchanged, unknown keys included', () => {
  const gradient = { style: 'blobs', base: '#1B1F4A', extra: 1,
    blobs: [{ x: 0.2, y: 1.4, r: 0.6, color: '#3B4BA8', tint: 'keep' }] }
  const doc = { ...textDoc(), background: { color: '#1B1F4A', gradient } }
  const res = parseActivityDocument(doc, 'text')
  expect(res.ok).toBe(true)
  expect((res as any).document.background.gradient).toEqual(gradient)
})
```

- `refuses each gradient bound with VALIDATION` — the §Contract bounds

```ts
it.each([
  ['style', { style: 'mesh' }],
  ['no blobs', { blobs: [] }],
  ['nine blobs', { blobs: Array.from({ length: 9 }, () => blob) }],
  ['x below 0', { blobs: [{ ...blob, x: -0.1 }] }],
  ['x above 1', { blobs: [{ ...blob, x: 1.1 }] }],
  ['y above 4', { blobs: [{ ...blob, y: 4.1 }] }],
  ['r above 1', { blobs: [{ ...blob, r: 1.1 }] }],
  ['blob colour', { blobs: [{ ...blob, color: 'blue' }] }],
  ['missing base', { base: undefined }],
  ['bad base', { base: '#12345' }],
])('refuses a gradient with a bad %s', (_name, patch) => {
  const gradient = { style: 'blobs', base: '#1B1F4A', blobs: [blob], ...patch }
  const res = parseActivityDocument({ ...textDoc(), background: { color: '#1B1F4A', gradient } }, 'text')
  expect(res).toMatchObject({ ok: false, code: 'VALIDATION' })
})
```

(`blob` = `{ x: 0.5, y: 0.5, r: 0.5, color: '#3B4BA8' }`; `textDoc()` is the suite's existing valid text document builder — reuse the one at the top of the file.)

- [ ] **Step 1: Write the listed tests** — in `activity-document.test.ts`, inside the `rejection rules` describe (`:143`) for the bounds
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/activity-document.test.ts`, watch them fail** — the bounds pass through today
- [ ] **Step 3: Add `gradient` to the background zod object and document it in 02 §5/§11 to the Behaviour**
- [ ] **Step 4: Run the same command, watch them pass** — and `npx tsc --noEmit` in `server/`
- [ ] **Step 5: Commit** — `feat(text-activity-v2): validate background.gradient`
- [ ] **Step 6: Record the freeze** — after the phase verifies: `advance.mjs docs/features/text-activity-v2 --set "contract=frozen <YYYY-MM-DD>" --head --commit "chore({feature}): contract frozen"`

### Task 2: Decode `background.gradient` without losing the background
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Models/ActivityDocument.swift:128-155` — `ActivityBackground` gains `gradient` and a lenient `init(from:)`
- Test: `iphone/MakeReadyCaptureTests/ActivityDocumentTests.swift` — new cases

**Interfaces:**
- Consumes: §Contract's `gradient` shape (Task 1).
- Produces: `ActivityBackground.Gradient` — `style: String`, `base: String`, `hidden: Bool` (absent → false), `blobs: [Blob]`; `ActivityBackground.Gradient.Blob` — `x`, `y`, `r: Double`, `color: String`; `ActivityBackground.gradient: Gradient?` (nil when absent, malformed, or `style != "blobs"`); `ActivityBackground.Gradient.jsonValue: JSONValue` — the gradient as the document's JSON object (writes `hidden` only when true).

**Behaviour:**
- `ActivityBackground.init(from:)` decodes each field with `try?`, so a malformed `gradient` (or `image`, `wash`, `motion`) leaves the other fields decoded; `color` missing → `"#000000"` (SPEC §iphone, F4)
- a `gradient` with an unknown `style` decodes to `gradient == nil`, and the raw JSON keeps it untouched, so re-encoding the document reproduces it (SPEC §iphone)
- blobs that fail to decode are skipped; a gradient with zero decodable blobs is nil (D1)

**Pattern:**
- `ActivityDocument.swift:198` — `decodeValue(…) ?? .default`, kept as the outer fallback

**Tests:**
- `testAGradientDecodes`

```swift
func testAGradientDecodes() {
    let doc = ActivityDocument(raw: background(["color": "#1B1F4A", "gradient": [
        "style": "blobs", "base": "#1B1F4A", "blobs": [["x": 0.2, "y": 1.4, "r": 0.6, "color": "#3B4BA8"]]]]))
    XCTAssertEqual(doc.background.gradient?.base, "#1B1F4A")
    XCTAssertEqual(doc.background.gradient?.blobs.first?.y, 1.4)
    XCTAssertEqual(doc.background.gradient?.hidden, false)
}
```

- `testAnUnknownStyleIsIgnoredAndReEncodedUnchanged`

```swift
func testAnUnknownStyleIsIgnoredAndReEncodedUnchanged() throws {
    let raw = background(["color": "#1B1F4A", "gradient": ["style": "mesh", "points": [1, 2]]])
    let doc = ActivityDocument(raw: raw)
    XCTAssertNil(doc.background.gradient)
    let reencoded = try JSONDecoder().decode(ActivityDocument.self, from: JSONEncoder().encode(doc))
    XCTAssertEqual(reencoded.raw, raw)
}
```

- `testAMalformedGradientKeepsTheRestOfTheBackground`

```swift
func testAMalformedGradientKeepsTheRestOfTheBackground() {
    let doc = ActivityDocument(raw: background(["color": "#224466", "gradient": "nope",
        "wash": ["color": "#000000", "opacity": 0.4]]))
    XCTAssertEqual(doc.background.color, "#224466")
    XCTAssertEqual(doc.background.wash?.opacity, 0.4)
    XCTAssertNil(doc.background.gradient)
}
```

(`background(_:)` is a test helper in this file building a valid text document whose `background` is the given dictionary as `JSONValue`; add it if the file has none.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `ActivityDocumentTests`, watch them fail** — no `gradient` member
- [ ] **Step 3: Implement `Gradient`, `Blob`, `jsonValue` and the lenient `init(from:)` in `ActivityDocument.swift`**
- [ ] **Step 4: Run the suite for `ActivityDocumentTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): decode background.gradient leniently`

### Task 3: Palettes and the blob generator
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/UI2/Activities/ActivityBackgroundPalettes.swift` — the 12 palettes and the luminance helpers
- Create: `iphone/MakeReady/UI2/Activities/ActivityBackgroundGenerator.swift` — the pure generator
- Create: `iphone/MakeReadyCaptureTests/SeededRandom.swift` — a SplitMix64 `RandomNumberGenerator` for tests
- Test: `iphone/MakeReadyCaptureTests/ActivityBackgroundPalettesTests.swift`, `iphone/MakeReadyCaptureTests/ActivityBackgroundGeneratorTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the new files (app target / test target)

**Interfaces:**
- Consumes: `ActivityBackground.Gradient` and `Gradient.Blob` (Task 2).
- Produces: `ActivityBackgroundPalettes.all: [[String]]` — 12 palettes of 4–5 `#RRGGBB`; `ActivityBackgroundPalettes.contrastWithWhite(_ hex: String) -> Double`; `ActivityBackgroundPalettes.darkest(_ palette: [String]) -> String` (lowest relative luminance); `ActivityBackgroundGenerator.make(palette: [String], rng: inout some RandomNumberGenerator) -> ActivityBackground.Gradient`; `ActivityBackgroundGenerator.randomPalette(rng: inout some RandomNumberGenerator) -> [String]`; test-only `SeededRandom(seed: UInt64)`.

**Behaviour:**
- 12 palettes, each 4–5 distinct colours, every colour ≥ 4.5:1 against `#FFFFFF` by the WCAG relative-luminance formula — deep tones only (D4, F9)
- `make` sets `style = "blobs"`, `base = darkest(palette)`, `hidden = false`, and exactly 4 blobs whose colours are drawn from the palette's other colours (cycling when fewer than 4), with `x` uniform 0–1, `y` uniform 0–1.6, `r` uniform 0.45–0.8 (D3)
- the same seed and palette always give the same gradient; no global randomness inside `make` (D3)
- the palettes task shows the owner all 12 palettes (swatches in the task report) before committing (F9)

**Tests:**
- `testEveryPaletteHasFourToFiveColoursReadableUnderWhite` (D4)

```swift
func testEveryPaletteHasFourToFiveColoursReadableUnderWhite() {
    XCTAssertEqual(ActivityBackgroundPalettes.all.count, 12)
    for palette in ActivityBackgroundPalettes.all {
        XCTAssertTrue((4...5).contains(palette.count), "\(palette)")
        for hex in palette { XCTAssertGreaterThanOrEqual(ActivityBackgroundPalettes.contrastWithWhite(hex), 4.5, hex) }
    }
}
```

- `testContrastMatchesWCAG` — `#767676` is the WCAG 4.5:1 boundary grey

```swift
func testContrastMatchesWCAG() {
    XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#767676"), 4.54, accuracy: 0.01)
    XCTAssertEqual(ActivityBackgroundPalettes.contrastWithWhite("#000000"), 21, accuracy: 0.01)
}
```

- `testASeedGivesAFixedGradient` (D3)

```swift
func testASeedGivesAFixedGradient() {
    let palette = ActivityBackgroundPalettes.all[0]
    var a = SeededRandom(seed: 42), b = SeededRandom(seed: 42)
    XCTAssertEqual(ActivityBackgroundGenerator.make(palette: palette, rng: &a),
                   ActivityBackgroundGenerator.make(palette: palette, rng: &b))
}
```

- `testBlobsStayInsideTheRulingsRanges` (D3)

```swift
func testBlobsStayInsideTheRulingsRanges() {
    var rng = SeededRandom(seed: 7)
    for palette in ActivityBackgroundPalettes.all {
        let g = ActivityBackgroundGenerator.make(palette: palette, rng: &rng)
        XCTAssertEqual(g.style, "blobs")
        XCTAssertEqual(g.blobs.count, 4)
        XCTAssertEqual(g.base, ActivityBackgroundPalettes.darkest(palette))
        for blob in g.blobs {
            XCTAssertTrue((0...1).contains(blob.x)); XCTAssertTrue((0...1.6).contains(blob.y))
            XCTAssertTrue((0.45...0.8).contains(blob.r)); XCTAssertTrue(palette.contains(blob.color))
            XCTAssertNotEqual(blob.color, g.base)
        }
    }
}
```

- [ ] **Step 1: Write the listed tests and `SeededRandom`**
- [ ] **Step 2: Run the iphone-xctest suite for both classes, watch them fail**
- [ ] **Step 3: Implement the palettes and generator to the Behaviour; register files with the project**
- [ ] **Step 4: Run the suite for both classes, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): blob gradient palettes and generator`

### Task 4: New activities start on a gradient and still auto-delete when untouched
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:67-81` — `textDocument` generates the background
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift:11, 112-118` — untouched rule
- Test: `iphone/MakeReadyCaptureTests/ActivityNewContainerTests.swift` (`:38`, `:109-115` rewritten), `iphone/MakeReadyCaptureTests/ActivitiesEditorMapperTests.swift` (`:44-45` rewritten), `iphone/MakeReadyCaptureTests/ActivitiesEditorContainerTests.swift` (`:48` kept passing)

**Interfaces:**
- Consumes: `ActivityBackgroundGenerator.make`, `randomPalette`, `Gradient.jsonValue` (Tasks 2–3).
- Produces: `ActivityNewContainer.textDocument(title: String, palette: [String]? = nil, rng: inout some RandomNumberGenerator)` plus the existing one-argument `textDocument(title:)` using `SystemRandomNumberGenerator`; `ActivitiesEditorMapper.isUntouched(_:)` with the D16 rule.

**Behaviour:**
- the starter's `background` is `{ color: gradient.base, gradient: <generated> }` — no `#FFFFFF` (D5, D17)
- untouched = no text objects, no actions, no `background.image`, no `background.wash`; `color` and `gradient` are ignored; `starterBackground` is deleted (D16)
- the test at `ActivityNewContainerTests:38` that compares two calls is rewritten to compare two calls with the same `SeededRandom` seed (D3)

**Tests:**
- `testTheStarterCarriesABlobGradient` (D5)

```swift
func testTheStarterCarriesABlobGradient() {
    var rng = SeededRandom(seed: 1)
    let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
    let gradient = try XCTUnwrap(doc.background.gradient)
    XCTAssertEqual(gradient.style, "blobs")
    XCTAssertEqual(doc.background.color, gradient.base)
    XCTAssertNotEqual(doc.background.color.uppercased(), "#FFFFFF")
}
```

- `testAGeneratedStarterIsUntouchedUntilContentArrives` (D16)

```swift
func testAGeneratedStarterIsUntouchedUntilContentArrives() {
    var rng = SeededRandom(seed: 2)
    let starter = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
    XCTAssertTrue(ActivitiesEditorMapper.isUntouched(starter))
    XCTAssertFalse(ActivitiesEditorMapper.isUntouched(ActivitiesEditorMapper.appendObject(to: starter, centerY: 100).document))
    XCTAssertFalse(ActivitiesEditorMapper.isUntouched(ActivitiesEditorMapper.settingBackgroundImage(mediaId: "m1", in: starter)))
}
```

- `testBackingOutOfAnUntouchedActivityDeletesIt` (existing, `ActivitiesEditorContainerTests:48`) — must pass with a generated starter as the loaded document (D16)

- [ ] **Step 1: Write/rewrite the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for the three classes, watch the new ones fail**
- [ ] **Step 3: Implement the starter and the untouched rule**
- [ ] **Step 4: Run the suite for the three classes, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): new activities start on a generated gradient`

### Task 5: Background document operations
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift:184-210` — gradient-aware background operations
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorMapperTests.swift`

**Interfaces:**
- Consumes: `ActivityBackground.Gradient`, `jsonValue`, `ActivityBackgroundGenerator`, `ActivityBackgroundPalettes` (Tasks 2–3); `ActivityDocument.updating(_:)`.
- Produces: `ActivitiesEditorMapper.BackgroundOption` (`.gradient`, `.colour`, `.image`); `backgroundOption(of: ActivityDocument) -> BackgroundOption`; `showingGradient(in:rng:) -> ActivityDocument`; `choosingColour(_ hex: String, in:) -> ActivityDocument`; `shuffling(in:rng:) -> ActivityDocument`; `choosingPalette(_ palette: [String], in:rng:) -> ActivityDocument`; `paletteColours(of: ActivityBackground.Gradient) -> [String]` (base first, then the distinct blob colours, in order).

**Behaviour:**
- `backgroundOption`: `image` set → `.image`; else no `gradient` or `hidden` → `.colour`; else `.gradient` (D14)
- `showingGradient`: removes `image` and `wash` (D18); with a gradient stored, clears `hidden` and sets `color = base`; with none, generates one from `randomPalette` and sets `color = base` (D14, D17)
- `choosingColour`: sets `color`; sets `gradient.hidden = true` when a gradient exists; removes `image` and `wash` (D14, D18)
- `shuffling`: a new `make` from `paletteColours(of:)` of the stored gradient; `color = base`; `hidden` cleared (D13)
- `choosingPalette`: a new `make` from the given palette; `color = base`; `hidden` cleared (D13)
- every operation patches the raw JSON by path; `motion` and unknown keys stay (SPEC §iphone)

**Tests:**

```swift
func testShuffleKeepsThePalettesColours() {
    var rng = SeededRandom(seed: 3)
    let doc = starter(&rng)
    let before = ActivitiesEditorMapper.paletteColours(of: doc.background.gradient!)
    let shuffled = ActivitiesEditorMapper.shuffling(in: doc, rng: &rng)
    XCTAssertEqual(Set(ActivitiesEditorMapper.paletteColours(of: shuffled.background.gradient!)).isSubset(of: Set(before)), true)
    XCTAssertNotEqual(shuffled.background.gradient!.blobs, doc.background.gradient!.blobs)
}

func testAPaletteChipSwapsTheColours() {
    var rng = SeededRandom(seed: 4)
    let palette = ActivityBackgroundPalettes.all[5]
    let doc = ActivitiesEditorMapper.choosingPalette(palette, in: starter(&rng), rng: &rng)
    XCTAssertEqual(doc.background.gradient!.base, ActivityBackgroundPalettes.darkest(palette))
    XCTAssertEqual(doc.background.color, doc.background.gradient!.base)
}

func testColourThenGradientRestoresTheBase() {
    var rng = SeededRandom(seed: 5)
    let doc = starter(&rng)
    let coloured = ActivitiesEditorMapper.choosingColour("#AA0000", in: doc)
    XCTAssertEqual(coloured.background.color, "#AA0000")
    XCTAssertEqual(coloured.background.gradient?.hidden, true)
    XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: coloured), .colour)
    let back = ActivitiesEditorMapper.showingGradient(in: coloured, rng: &rng)
    XCTAssertEqual(back.background.color, doc.background.gradient!.base)
    XCTAssertEqual(back.background.gradient, doc.background.gradient)
    XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: back), .gradient)
}

func testGradientOrColourRemovesTheImageAndWash() {
    var rng = SeededRandom(seed: 6)
    let withImage = ActivitiesEditorMapper.settingBackgroundImage(mediaId: "m1", in: starter(&rng))
    XCTAssertEqual(ActivitiesEditorMapper.backgroundOption(of: withImage), .image)
    XCTAssertNil(ActivitiesEditorMapper.showingGradient(in: withImage, rng: &rng).background.image)
    let coloured = ActivitiesEditorMapper.choosingColour("#112233", in: withImage)
    XCTAssertNil(coloured.background.image); XCTAssertNil(coloured.background.wash)
}

func testImageKeepsTheGradient() {
    var rng = SeededRandom(seed: 8)
    let doc = starter(&rng)
    XCTAssertEqual(ActivitiesEditorMapper.settingBackgroundImage(mediaId: "m1", in: doc).background.gradient, doc.background.gradient)
}

func testGradientOnALegacyDocumentGeneratesOne() {
    var rng = SeededRandom(seed: 9)
    let legacy = ActivityDocument(raw: .object(["schemaVersion": .number(1), "kind": .string("text"),
        "background": .object(["color": .string("#FFFFFF")])]))
    let doc = ActivitiesEditorMapper.showingGradient(in: legacy, rng: &rng)
    XCTAssertEqual(doc.background.gradient?.blobs.count, 4)
    XCTAssertEqual(doc.background.color, doc.background.gradient?.base)
}
```

(`starter(&rng)` = `ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)`.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `ActivitiesEditorMapperTests`, watch them fail**
- [ ] **Step 3: Implement the operations to the Behaviour**
- [ ] **Step 4: Run the suite, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): gradient-aware background operations`

### Task 6: File the d2m handover requests and wait for the builds
App: iphone
Phase: 3
Recipe: REFERENCE §Prototype mode (design is d2m's; this task only requests and records)

**Files:**
- Modify (by d2m, not by hand): `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift`, `iphone/MakeReadyUI/Screens/Activities/ActivitiesPlayerScreen.swift`, `iphone/MakeReadyUI/ActivityCanvas.swift`, `iphone/MakeReadyUI/IconButton.swift`, `iphone/MakeReadyUI/ActivityNavBar.swift`, and `ActivityNewScreen.swift` (the C-081 host)
- Create: `.builder/text-activity-v2/d2m-api.md` (workspace, git-ignored) — the names d2m shipped, for Tasks 7–9

**Interfaces:**
- Consumes: SPEC §Decisions D6–D13, D17–D23, §iphone · Rails (committed on `feature/text-activity`, passed as `references`).
- Produces (requested names; `d2m-api.md` records any deviation, and Tasks 7–9 use what it records):
  - C-091 `ActivityCanvas.Background.Gradient` (`base: Color`, `hidden: Bool`, `blobs: [Blob]` with `x`, `y`, `r: Double`, `color: Color`) and `Background.gradient: Gradient?`, drawn between colour and image; a reusable `ActivityBlobGradient` view taking a `Gradient` and a page size
  - C-102 `IconButton` `isDisabled: Bool` (disabled tone, no tap)
  - C-081 `ActivityNavBar` `bottomInset: CGFloat` (default 0)
  - `ActivitiesEditorScreen.State`: `backgroundOption` (gradient · colour · image), `gradient`, `palettes: [[Color]]`, `libraryImages: [LibraryImage]` (id + URL), `hasMoreImages: Bool`; callbacks `onTapOff()`, `onBackground(BackgroundCommand)` with cases `.gradient`, `.colour(Color)`, `.shuffle`, `.palette(Int)`, `.image(id: String)`, `.moreImages`, `.loadMoreImages`, `.focal(CGPoint)`, `.wash(Color?, Double)`; `onActionsChange([PageAction])` (live, no Done); `onPageRailsClosed()`; the screen does not report an empty-canvas tap while any rail is open (D21) and reports `onTapObject` while editing (D20)
  - `ActivitiesPlayerScreen` per-page background `State` gains `gradient`

**Behaviour:**
- one `request_project_change` per subject: `activities-editor` screen, `activities-player` screen, C-091, C-102, C-081; each with `references: ["docs/features/text-activity-v2/SPEC.md"]`, `branch: "feature/text-activity"`, an intent ≤ 2000 characters naming the decisions it implements (D12)
- the editor request pins rail heights for a 375pt phone with the keyboard up (F2) and "no canvas scroll while Image is open" (F8)
- `wait_project_change` until each is done; a handback is settled from the SPEC (questions → `answer_project_change` with the ruling's text; held items → `approve_project_change`; a failed step → `retry_project_change`); park only on `next` starting `cannot be done:` (D12, F1)
- the working-tree edits of F3 are committed before the first request (F3)

**Tests:**
- `the editor screen still compiles against the container` — the iphone-xctest suite runs green after d2m's last commit (existing tests; screen contract tests asserting `sheetLayout` are rewritten in Task 8)

```swift
// No new assertions here: d2m's own builds capture and diff each subject. The gate is the existing
// MakeReadyCaptureTests suite compiling and passing on d2m's final commit, minus the sheetLayout
// cases Task 8 rewrites (record them in d2m-api.md if d2m removed them).
```

- [ ] **Step 1: Confirm F3's edits are committed** — `git status --short iphone/ docker-compose.yml` is empty
- [ ] **Step 2: File the five requests** — `request_project_change` per subject, as the Behaviour says
- [ ] **Step 3: Wait and settle handbacks** — `wait_project_change` per subject until done
- [ ] **Step 4: Record the shipped names** — write `d2m-api.md` from the landed diffs (`git log -p` of d2m's commits)
- [ ] **Step 5: Run the iphone-xctest suite on HEAD** — PASS except cases d2m's change made obsolete, listed in `d2m-api.md`

### Task 7: Tap-off, tap-another and the save moments
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:238-300` — `commitEdit`, `tapOff`, `tapObject`, `cancel`, `changeActions`, `closePageRails`
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorContainerTests.swift`

**Interfaces:**
- Consumes: the screen callbacks `onTapOff`, `onTapObject`, `onActionsChange`, `onPageRailsClosed` (Task 6, `d2m-api.md`); `ActivitiesEditorMapper.applyActions`, `removeObject`, `text(at:in:)`.
- Produces: `Model.commitEdit() async` (extracted from `done()`'s edit branch, `:275-280`); `Model.tapOff() async`; `Model.closePageRails() async`; `done()` calls `commitEdit()`.

**Behaviour:**
- `tapOff` while editing = `commitEdit`: an added object left empty is dropped, the edit ends, one PUT (D10)
- `tapObject(i)` while editing another object: `commitEdit`, then edit `i` (D20)
- `cancel` restores only the edited object from `editStart` (an added object is removed), keeps every other change, and PUTs once if the document now differs from the saved one (D19)
- `changeActions` patches the document live and no longer PUTs (D19)
- `closePageRails` drops actions whose label is empty, then PUTs once if the document changed (D19)
- a failed save keeps today's alert path (text-activity D46); whether the rails survive the re-seed is checked and stated in the task report (F7)

**Tests:**

```swift
func testTapOffWhileEditingCommitsAndSavesOnce() async {
    let (model, api) = editing(text: "Hello")
    await model.tapOff()
    XCTAssertEqual(model.editingIndex, -1)
    XCTAssertEqual(api.savedDocuments.count, 1)
    XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: api.savedDocuments[0]), "Hello")
}

func testTapOffOnAnAddedEmptyObjectDropsIt() async {
    let (model, api) = addedEmpty()
    await model.tapOff()
    XCTAssertTrue(ActivitiesEditorMapper.rawObjects(model.document).isEmpty)
    XCTAssertEqual(api.savedDocuments.count, 1)
}

func testTappingAnotherObjectCommitsThenEditsIt() async {
    let (model, api) = editingFirstOfTwo(text: "One")
    await model.tapObject(1)
    XCTAssertEqual(model.editingIndex, 1)
    XCTAssertEqual(api.savedDocuments.count, 1)
}

func testCancelRestoresOnlyTheObjectAndSavesPageEdits() async {
    let (model, api) = editing(text: "Changed", original: "Original")
    await model.changeActions([.init(kind: .write, label: "Go")])
    await model.cancel()
    XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: model.document), "Original")
    XCTAssertEqual(api.savedDocuments.count, 1)
    XCTAssertEqual(api.savedDocuments[0].actions.map(\.label), ["Go"])
    XCTAssertEqual(ActivitiesEditorMapper.text(at: 0, in: api.savedDocuments[0]), "Original")
}

func testActionEditsSaveWhenTheRailClosesAndEmptyOnesDrop() async {
    let (model, api) = idle()
    await model.changeActions([.init(kind: .write, label: "Go"), .init(kind: .write, label: "")])
    XCTAssertTrue(api.savedDocuments.isEmpty)
    await model.closePageRails()
    XCTAssertEqual(api.savedDocuments.count, 1)
    XCTAssertEqual(api.savedDocuments[0].actions.map(\.label), ["Go"])
}
```

(`editing`, `addedEmpty`, `editingFirstOfTwo`, `idle` are fixtures built on the suite's existing fake API. The D21 rule — no object added by a canvas tap while a rail is open — is the screen's (Task 6) and is asserted in Task 8's contract tests.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `ActivitiesEditorContainerTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the suite, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): tap-off commits, rails save on close`

### Task 8: Wire the Background rail, the inline image picker and the tool states
App: iphone
Phase: 4
Recipe: /push-page

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift:22-110` — `state()` fills the screen's new background fields
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:290-312` — `changeBackground(_ command:)`, library images, More…
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift` — passes `bottomInset: 16` to its screen (D23)
- Modify: `iphone/MakeReadyCaptureTests/ActivitiesEditorScreenContractTests.swift:49-60`, `ViewRegistry.swift:3918`, `CaptureFixture.swift:1087` — sheet values become rail values
- Test: `ActivitiesEditorMapperTests`, `ActivitiesEditorContainerTests`, `ActivitiesEditorScreenContractTests`

**Interfaces:**
- Consumes: `BackgroundCommand`, `State.backgroundOption`, `gradient`, `palettes`, `libraryImages`, `hasMoreImages`, C-102 `isDisabled`, C-081 `bottomInset` (Task 6); Task 5's operations; `MediaActions().loadLibrary()` and the AppState media store; the existing `.chooseActivityBackground(activityId:)` route and `takeBackgroundPick` (D22).
- Produces: `Model.changeBackground(_ command: BackgroundCommand)`; `Model.loadMoreImages() async`.

**Behaviour:**
- `state()` maps `backgroundOption(of:)`, the gradient (hex → `Color`), `ActivityBackgroundPalettes.all`, and the newest library images from AppState (D13, D14, D22)
- `.gradient` → `showingGradient`; `.colour(c)` → `choosingColour`; `.shuffle` → `shuffling`; `.palette(i)` → `choosingPalette(all[i])`; `.image(id)` → `settingBackgroundImage`; `.focal`/`.wash` → today's `applyBackground` focal/wash path; `.moreImages` → push `.chooseActivityBackground(activityId:)`; `.loadMoreImages` → `loadMoreImages()` (D13, D14, D18, D22)
- background commands patch live and save per D19 (with `closePageRails`, Task 7)
- the screen is passed C-081 `bottomInset: 16` by the editor and by ActivityNewContainer (D11, D23)
- tool enablement in Idle: Background and Actions enabled, Colour/Alignment/Font disabled via C-102 `isDisabled`; all enabled while editing (D9) — asserted in the screen contract test
- an empty-canvas tap with a rail open adds no object (D21) — asserted in the screen contract test through the screen's tap reporting

**Tests:**

```swift
func testStateDerivesTheBackgroundOption() {
    var rng = SeededRandom(seed: 10)
    let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
    XCTAssertEqual(ActivitiesEditorMapper.state(for: doc).backgroundOption, .gradient)
    XCTAssertEqual(ActivitiesEditorMapper.state(for: ActivitiesEditorMapper.choosingColour("#123456", in: doc)).backgroundOption, .colour)
}

func testIdleToolsEnableOnlyPageTools() {
    let screen = ActivitiesEditorScreen.contractTools(mode: .idle)
    XCTAssertEqual(screen.enabled, [.background, .actions])
    XCTAssertEqual(ActivitiesEditorScreen.contractTools(mode: .editing).enabled.count, 5)
}

func testMoreImagesPushesThePickPage() {
    let (model, navigator) = idleWithNavigator()
    model.changeBackground(.moreImages)
    XCTAssertEqual(navigator.pushed.last, .chooseActivityBackground(activityId: model.activityId))
}
```

(Use the state-builder and tool-contract names `d2m-api.md` records; `contractTools` stands for whatever helper the existing contract tests use to read tool enablement.)

- [ ] **Step 1: Write the listed tests and rewrite the `sheetLayout` contract cases and fixture `openTool` values**
- [ ] **Step 2: Run the iphone-xctest suite for the three classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the full iphone-xctest suite, watch it pass; `cd iphone && swiftlint` shows no new findings**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): background rail, inline images, tool states`

### Task 9: The viewer and the rail thumbnails draw the gradient
App: iphone
Phase: 4
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift:277-293, 360-367` — pass the gradient to the player screen
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift:77-110` — draw the gradient in `Page`
- Test: `iphone/MakeReadyCaptureTests/ActivityViewerMapperTests.swift`, `iphone/MakeReadyCaptureTests/ActivityThumbnailTests.swift`

**Interfaces:**
- Consumes: `ActivityBackground.gradient` (Task 2); the player screen's per-page `gradient` and C-091's `ActivityBlobGradient` (Task 6).
- Produces: nothing new for other tasks.

**Behaviour:**
- the viewer mapper copies a visible gradient (not `hidden`) into the page's background state; hidden or absent → nil (D1, D14)
- `ActivityThumbnail.Page` draws `ActivityBlobGradient` between colour and image on its 440×956 reference page when the gradient is visible (D1, D2)

**Tests:**

```swift
func testAVisibleGradientReachesThePage() {
    var rng = SeededRandom(seed: 11)
    let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
    XCTAssertNotNil(pageBackground(mapping: doc).gradient)
    XCTAssertNil(pageBackground(mapping: ActivitiesEditorMapper.choosingColour("#123456", in: doc)).gradient)
}

func testTheThumbnailDrawsAVisibleGradient() {
    var rng = SeededRandom(seed: 12)
    let doc = ActivityNewContainer.textDocument(title: "T", palette: nil, rng: &rng)
    XCTAssertTrue(ActivityThumbnail.drawsGradient(for: doc.background))
    XCTAssertFalse(ActivityThumbnail.drawsGradient(for: ActivitiesEditorMapper.choosingColour("#123456", in: doc).background))
}
```

(`pageBackground(mapping:)` reads the mapped page's background from the viewer mapper's output; `ActivityThumbnail.drawsGradient(for:)` is a small static the `Page` view uses.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for both classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the suite, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity-v2): viewer and thumbnails draw the gradient`
