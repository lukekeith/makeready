# bible-verse-picker — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders add scripture to a lesson in the UI 2.0 iPhone app by browsing or searching to a chapter, selecting words in a verse reader, and getting a locked, exactly cited, highlightable Bible activity.

**Architecture:** The server makes verse text canonical (D9), validates word-offset passages on `bible` documents (D8, D22) and adds two search refinements (SC4, SC5); its phase close freezes §Contract. The iPhone app then gains models and `BibleActions` in AppState, files one batch of d2m handover requests for every view under `iphone/MakeReadyUI/`, and wires the picker pages and the editor's Bible handling in containers against what d2m ships.

**Tech Stack:** server — Express + zod + Prisma + vitest (supertest on 127.0.0.1). iphone — Swift/SwiftUI, `@Observable` + Actions, `ActivityDocument` raw-JSON patching, XCTest in `MakeReadyCaptureTests`, d2m via the `d2m-channel` MCP server.

**Spec:** `docs/features/bible-verse-picker/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(bible-verse-picker): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–4 | Canonical chapter text, passage/offset validation, `record` + per-query recent delete, picker fixtures; the contract freezes |
| 2 | iphone | 5–7 | The app decodes passages and scripture objects, knows every book's category, and loads translations, chapters, search and recents through `BibleActions` into AppState |
| 3 | iphone | 8 | d2m has built the four picker screens, BibleVerseReader, the C-052/C-085 variants, five colour tokens and the D21 editor changes |
| 4 | iphone | 9–11 | The picker runs: four pushed pages, search, translation switching, word selection and Select returning a pick by flow id |
| 5 | iphone | 12–15 | The editor creates, locks, highlights, changes and splits Bible activities, and thumbnails draw verse numbers |
| 6 | server | 16 | SC6: scripture objects carry `verseNumbers` and `inset`; the contract re-freezes |
| 7 | iphone | 17 | The scripture document has no split: verse-number defaults, D28 style defaults and the D29 page height |
| 8 | iphone | 18 | d2m has built the gutter/hidden modes, the scrolling Bible page with the D28 style panel, and the player's in-page scroll |
| 9 | iphone | 19 | The editor, player and thumbnails run page-laid-out scripture end to end |
| 10 | server | 20 | SC7: scripture objects carry `verticalAlignment`; the contract re-freezes |
| 11 | iphone | 21 | d2m has imported the Figma glyphs and built the reorganised Bible tool bar and Align panel |
| 12 | iphone | 22 | Vertical alignment and the new tool bar work in the editor, player and thumbnails |
| 13 | iphone | 23 | The reference is ordinary, editable text above the passage, with no translation code |

---

### Task 1: Canonical verse text, titles off, versioned chapter cache
App: server
Phase: 1
Recipe: test-driven-development

**Files:**
- Create: `server/src/utils/verse-text.ts` — `normalizeVerseText`
- Modify: `server/src/services/bible-chapter.ts:33-80` — normalize on both branches; versioned cache key
- Modify: `server/src/services/api-bible.ts:213-223` — `'include-titles': false` in `getChapter`
- Test: `server/src/utils/__tests__/verse-text.test.ts`, `server/src/services/__tests__/bible-chapter.test.ts`

**Interfaces:**
- Produces: `normalizeVerseText` — takes a verse string, returns the canonical string (D9); `CHAPTER_CACHE_VERSION` — the string `v2`, exported from `bible-chapter.ts`.
- §Contract row `GET /api/bible/:code/:book/:chapter`: envelope unchanged, `text` canonical, no section titles.

**Behaviour:**
- remove every `¶`; replace `\r`, `\n` and the literal two-character sequences `\r`/`\n` (backslash + letter) with one space; collapse every whitespace run to one space; trim (D9)
- `getChapterVerses` returns normalized `text` on the cache-hit branch and the cache-miss branch, and caches the normalized verses (D9)
- the cache key is `chapter:v2:${bibleId}:${chapterId}`, so 14-day raw entries are never read (D9, SC3)
- `getChapter` asks API.Bible for `include-titles: false` (D9, F4)

**Tests:**
- `normalizeVerseText cleans pilcrows, breaks, escapes and runs` (D9)

```ts
it('normalizeVerseText cleans pilcrows, breaks, escapes and runs', () => {
  expect(normalizeVerseText('¶ For God\r\nso  loved\\nthe\\rworld \n')).toBe('For God so loved the world')
  expect(normalizeVerseText('  plain  ')).toBe('plain')
})
```

- `getChapterVerses normalizes a cached chapter and reads the v2 key` — mock `bibleCache` and `apiBible` (D9)

```ts
it('getChapterVerses normalizes a cached chapter and reads the v2 key', async () => {
  mockGetCached.mockResolvedValue({ responseJson: JSON.stringify([{ verse: 1, text: '¶ In the\nbeginning' }]), copyright: 'PD' })
  const r = await getChapterVerses('bib', 'GEN', 1, { skipFums: true })
  expect(mockGetCached).toHaveBeenCalledWith('chapter:v2:bib:GEN.1')
  expect(r.verses[0].text).toBe('In the beginning')
})
```

- `getChapterVerses normalizes and caches a fetched chapter` (D9)

```ts
it('getChapterVerses normalizes and caches a fetched chapter', async () => {
  mockGetCached.mockResolvedValue(null)
  mockGetChapter.mockResolvedValue({ data: { content: '[1] ¶ In the  beginning\\n', copyright: 'PD' }, meta: {} })
  const r = await getChapterVerses('bib', 'GEN', 1)
  expect(r.verses[0].text).toBe('In the beginning')
  expect(mockSetCache.mock.calls[0][0]).toBe('chapter:v2:bib:GEN.1')
  expect(mockSetCache.mock.calls[0][3][0].text).toBe('In the beginning')
})
```

- [ ] **Step 1: Write the listed tests** — mock `../bible-cache.js` and `../api-bible.js` with `vi.mock` as `test/semantic-search.test.ts:1-60` does; check the real module names in `bible-chapter.ts` imports
- [ ] **Step 2: Run `cd server && npx vitest run src/utils/__tests__/verse-text.test.ts src/services/__tests__/bible-chapter.test.ts`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run the same command, watch them pass** — and `npx tsc --noEmit` in `server/`
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): canonical chapter verse text (D9)`

### Task 2: Validate passages with offsets and paired scripture references
App: server
Phase: 1
Recipe: test-driven-development

**Files:**
- Modify: `server/src/services/activity-document.ts:85-97` (`bibleContent`) and the `bible` entry of `CONTENT_BY_KIND`
- Test: `server/src/services/__tests__/activity-document.test.ts` — a new `describe('bible passages (bible-verse-picker)')`

**Interfaces:**
- Consumes: `parseActivityDocument(input, kind)` → `{ ok: true, document }` | `{ ok: false, code, error }`.
- Produces: the frozen document shape —

```ts
// content.passages[] (bible), .passthrough()
{ bookNumber: int, chapterStart: int, verseStart: int, chapterEnd: int, verseEnd: int,
  startOffset?: int >= 0, endOffset?: int >= 0, translation?: string }
// textObject.reference, validated only on role 'scripture' when present
{ start: { book: int, chapter: int, verse: int, offset?: int >= 0 },
  end:   { book: int, chapter: int, verse: int, offset?: int >= 0 }, translation: string }
```

**Behaviour:**
- unpaired passages (no scripture object's `reference` equals them) are checked structurally only: the integer fields, optional non-negative int offsets, optional string `translation` (D22, SC1)
- a `role: 'scripture'` object carrying `reference` must match the SC2 shape; it is paired with the passage whose `bookNumber`=`start.book`=`end.book`, `chapterStart`=`start.chapter`, `chapterEnd`=`end.chapter`, `verseStart`=`start.verse`, `verseEnd`=`end.verse`, `startOffset`=`start.offset`, `endOffset`=`end.offset` (absent equals absent), `translation`=`reference.translation`; none → VALIDATION `content.objects.<i>.reference: no matching passage` (D22)
- for a paired passage: `translation` required; `chapterStart` = `chapterEnd`; `verseStart` ≤ `verseEnd`; when `verseStart` = `verseEnd` and both offsets present, `startOffset` < `endOffset`; the object's `startNumber` = `verseStart`; at most one scripture object per passage (D22)
- offsets are never compared with verse length (D22); every failure is `code: 'VALIDATION'` via `describeIssue`; unknown keys survive (`.passthrough()`)

**Tests:**
- `accepts a D10 document and keeps it intact` · `refuses each paired-rule breach` · `a converter-shaped legacy document stays valid` (D22)

```ts
const ref = { start: { book: 43, chapter: 3, verse: 16, offset: 9 }, end: { book: 43, chapter: 3, verse: 18 }, translation: 'ENGKJV' }
const passage = { bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: 9, translation: 'ENGKJV' }
const scripture = (o: any = {}) => ({ ...textObj('s', 'scripture'), listStyle: 'bibleVerse', startNumber: 16, reference: ref, ...o })
const doc = (objects: any[], passages: any[]) => ({ ...EXAMPLES.bible, content: { ...EXAMPLES.bible.content, objects, passages } })

it('accepts a D10 document and keeps it intact', () => {
  const r: any = parseActivityDocument(doc([scripture(), textObj('c', 'citation')], [passage]), 'bible')
  expect(r.ok).toBe(true)
  expect(r.document.content.passages[0]).toEqual(passage)
})

it.each([
  ['no matching passage', [scripture()], [{ ...passage, verseEnd: 17 }]],
  ['missing translation', [scripture({ reference: { ...ref, translation: undefined } })], [{ ...passage, translation: undefined }]],
  ['cross-chapter', [scripture({ reference: { ...ref, end: { book: 43, chapter: 4, verse: 1 } } })], [{ ...passage, chapterEnd: 4, verseEnd: 1 }]],
  ['reversed', [scripture({ startNumber: 18, reference: { ...ref, start: { book: 43, chapter: 3, verse: 18 }, end: { book: 43, chapter: 3, verse: 16 } } })], [{ ...passage, verseStart: 18, verseEnd: 16, startOffset: undefined }]],
  ['equal offsets', [scripture({ reference: { ...ref, end: { book: 43, chapter: 3, verse: 16, offset: 9 } } })], [{ ...passage, verseEnd: 16, endOffset: 9 }]],
  ['startNumber', [scripture({ startNumber: 1 })], [passage]],
  ['two scriptures', [scripture(), scripture({ id: 's2' })], [passage]],
  ['negative offset', [textObj('b', 'body')], [{ ...passage, startOffset: -1 }]],
])('refuses %s', (_n, objects, passages) => {
  expect(parseActivityDocument(doc(objects as any[], passages as any[]), 'bible')).toMatchObject({ ok: false, code: 'VALIDATION' })
})

it('a converter-shaped legacy document stays valid', () => {
  const legacy = doc([textObj('a', 'scripture'), textObj('b', 'scripture'), textObj('c', 'citation')],
    [{ bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16 }])
  expect(parseActivityDocument(legacy, 'bible')).toMatchObject({ ok: true })
  expect(parseActivityDocument(EXAMPLES.bible, 'bible')).toMatchObject({ ok: true })
})
```

(`textObj(id, role)` — a valid text object built from the suite's existing helper at the top of the file; add it there if none takes a role.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/activity-document.test.ts`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour** — a `superRefine` on the bible content, in the style at `activity-document.ts:184`
- [ ] **Step 4: Run the same command plus `npx vitest run test/content-activities-write.test.ts test/text-activity-readers.test.ts`, watch them pass** — `og-meta.ts`, `claude.ts`, `program-export.ts` and `templates.ts` read `documentPassages` and must accept the extended shape; `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): validate word-offset passages (D8, D22)`

### Task 3: Smart search `record`, per-query recent delete, canonical direct hits
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/src/routes/search.ts:861-1030` — `record` on `/smart`; `handleDirectReference` via `getChapterVerses`
- Modify: `server/src/routes/search.ts:1270-1280` — `DELETE /recent/:id` after `DELETE /recent`
- Test: `server/test/bible-search-recents.test.ts` (DB lease), `server/test/bible-direct-reference.test.ts` (mocked)

**Interfaces:**
- Produces (frozen): `POST /api/search/smart` body `{query, translation, limit, record?: boolean}`, `record` default `true`; `DELETE /api/search/recent/:id` → `{success:true}` | 404 `{error:'Recent search not found'}`.

**Behaviour:**
- `record === false` skips `saveSearchHistory` on every branch; absent or `true` saves as today (SC5, D17)
- `DELETE /recent/:id`: identity as `GET /recent` (`userId` else `memberId`); no identity → 404; a row not found or not the caller's (malformed id included) → 404; else delete every caller row with `searchType` equal to the row's and `query` equal case-insensitively (`mode: 'insensitive'`) → `{success:true}` (SC4, F6)
- `handleDirectReference` reads verses via `getChapterVerses(bibleId, apiBookId, chapter)` and slices `verseStart..verseEnd` (single verse: that one; none: the whole chapter); the response keeps its shape, `copyright` and `fumsToken` from the chapter result (D9, §server)

**Tests:**
- `record:false writes no history` · `record defaults to true`
- `deleting one recent removes every row of that query, case-insensitively, and nothing else`
- `another caller's or a malformed id is 404`

```ts
it('record:false writes no history', async () => {
  await smart(user, { query: 'john 3:16', translation: 'ENGKJV', record: false }).expect(200)
  await flush()
  expect(await prisma.searchHistory.count({ where: { userId: user.id } })).toBe(0)
})
it('record defaults to true', async () => {
  await smart(user, { query: 'john 3:16', translation: 'ENGKJV' }).expect(200)
  await flush()
  expect(await prisma.searchHistory.count({ where: { userId: user.id, searchType: 'bible' } })).toBe(1)
})
it('deleting one recent removes every row of that query, case-insensitively, and nothing else', async () => {
  const [a] = await seed(user, ['grace', 'Grace', 'GRACE', 'love'])
  await del(user, a.id).expect(200, { success: true })
  expect((await prisma.searchHistory.findMany({ where: { userId: user.id } })).map((r) => r.query)).toEqual(['love'])
})
it("another caller's or a malformed id is 404", async () => {
  const [a] = await seed(other, ['grace'])
  await del(user, a.id).expect(404)
  await del(user, 'not-an-id').expect(404)
  expect(await prisma.searchHistory.count({ where: { userId: other.id } })).toBe(1)
})
```

- `a direct reference returns canonical, sliced chapter text` — `getChapterVerses` mocked (D9)

```ts
it('a direct reference returns canonical, sliced chapter text', async () => {
  mockResolveBibleId.mockResolvedValue('bib')
  mockGetChapterVerses.mockResolvedValue({ verses: [15, 16, 17, 18].map((v) => ({ verse: v, text: `v${v}` })), copyright: 'PD', fumsToken: 't' })
  const res = await smart({ query: 'John 3:16-17', translation: 'ENGKJV', record: false }).expect(200)
  expect(res.body.type).toBe('direct')
  expect(res.body.verses.map((v: any) => v.text)).toEqual(['v16', 'v17'])
  expect(res.body.copyright).toBe('PD')
})
```

(`smart`, `del`, `seed`, `flush` — local helpers: supertest against an express app mounting `searchRoutes` on `listen(0, '127.0.0.1')` with an injected user, exactly as `test/master-search-recents.test.ts:12-35`; `flush` awaits the fire-and-forget create with a short poll. Mock embeddings/semantic search for `record` cases so `/smart` returns without a model. DB suite gated `describe.skipIf(!process.env.TEST_DATABASE_URL)`; never `makeready_dev`.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run test/bible-search-recents.test.ts test/bible-direct-reference.test.ts`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour** — route stays thin; the delete-by-query goes in a small function beside `saveSearchHistory`
- [ ] **Step 4: Run the same command and `npx vitest run test/semantic-search.test.ts test/master-search-recents.test.ts`, watch them pass**; `npx tsc --noEmit`
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): smart-search record flag and per-query recent delete (SC4, SC5)`

### Task 4: Picker fixtures, then freeze the contract
App: server
Phase: 1
Recipe: test-driven-development

**Files:**
- Create: `server/fixtures/screens/bible-books.ts` — `full`: six `bible` recents for `FIXTURE_USER_ID`
- Create: `server/fixtures/screens/bible-reader.ts` — `full`: program 212 "Bible Picker Samples", one lesson, a draft holding a D10-shaped John 3:16b-18 activity and the existing legacy sample (D23)
- Modify: `server/fixtures/ids.ts:104-130` — `BIBLE_READER_IDS` (`programId: fixtureId('program', 212)`, `lessonId`, `lessonVersionId`), added to `FIXTURE_IDS.bibleReader`
- Modify: `server/fixtures/activity-documents.ts:72-78` — `bibleDocument` passage type gains the optional SC1 fields
- Test: `server/fixtures/__tests__/bible-screens.db.test.ts`

**Interfaces:**
- Consumes: `parseActivityDocument` with Task 2's rules; `writeVersions`, `textObject`, `bibleDocument` (`activities-editor.ts` pattern).
- Produces: screen ids `bible-books`, `bible-chapters`, `bible-verses`, `bible-reader` (Task 8 names d2m screens with them); `FIXTURE_IDS.bibleReader`.

**Behaviour:**
- recents: queries "john 3:16", "grace", "Psalm 23", "love one another", "Romans 8", "faith" — `searchType: 'bible'`, `createdAt` from `ctx.daysAgo` (house rule: fixtures)
- the D10 activity: scripture `role: 'scripture'`, `listStyle: 'bibleVerse'`, `startNumber: 16`, `font: 'serif'`, `size: 18`, `reference` = Task 2's `ref`; citation text `John 3:16b-18 ENGKJV`; passage = Task 2's `passage`; one highlight on "eternal life" (D10, D21)
- `bible-chapters` and `bible-verses` read no server rows beyond the "used" passages, which `bible-reader.ts` seeds; their screen specs cite it (house rule: fixtures)
- layers read base ids only, never create orgs, users or groups, never touch `ctx.rand`

**Tests:**
- `the full scenario seeds bible recents and a valid D10 activity` (house rule: fixtures)

```ts
it('the full scenario seeds bible recents and a valid D10 activity', async () => {
  await db.run('reset', 'full')
  expect(await db.prisma.searchHistory.count({ where: { userId: FIXTURE_USER_ID, searchType: 'bible' } })).toBe(6)
  const acts = await db.prisma.contentActivity.findMany({ where: { lessonVersionId: ids.bibleReader.lessonVersionId, kind: 'bible' } })
  const d10 = acts.find((a) => (a.document as any).content.passages?.[0]?.startOffset !== undefined)!
  expect(parseActivityDocument(d10.document, 'bible')).toMatchObject({ ok: true })
  expect((d10.document as any).content.objects.find((o: any) => o.role === 'citation').text).toBe('John 3:16b-18 ENGKJV')
}, 180_000)
```

- [ ] **Step 1: Write the listed test**
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/bible-screens.db.test.ts`, watch it fail**
- [ ] **Step 3: Implement the two layers and ids to the Behaviour**
- [ ] **Step 4: Run it and `npx vitest run fixtures/__tests__/activities-screens.db.test.ts`, watch them pass**; `npx tsc -p fixtures --noEmit`
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): bible picker screen fixtures`
- [ ] **Step 6: Record the freeze** — after the phase verifies: `node "$BUILDER_DIR"/scripts/advance.mjs docs/features/bible-verse-picker --set "contract=frozen <YYYY-MM-DD>" --head --commit "chore({feature}): contract frozen"`

### Task 5: Decode passages and scripture objects
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Models/ActivityDocument.swift:14-83, 253-346` — `TextObject` accessors; `BiblePassage`; `ActivityDocument.passages`
- Test: `iphone/MakeReadyCaptureTests/BiblePassageDecodingTests.swift`

**Interfaces:**
- Consumes: §Contract SC1/SC2 shapes (Task 2).
- Produces: `BiblePassage` (`Codable, Hashable`) — `bookNumber`, `chapterStart`, `verseStart`, `chapterEnd`, `verseEnd: Int`, `startOffset`, `endOffset: Int?`, `translation: String?`; `ScriptureReference` — `start`, `end: Point` (`book`, `chapter`, `verse: Int`, `offset: Int?`), `translation: String`; on `TextObject`: `role: String?`, `listStyle: String?`, `startNumber: Int?`, `reference: ScriptureReference?` read from the raw JSON; `ActivityDocument.passages: [BiblePassage]` (get + set, writes `content.passages`); `TextObject.isLockedScripture: Bool` — `role` is `scripture`/`citation` and the object (or, for a citation, the activity's scripture object) carries `reference`.

**Behaviour:**
- a passage missing a required int is skipped; a missing `translation` decodes as nil (D22, Data plan)
- `reference.start.book` is the book number (SC2); a malformed `reference` decodes as nil and the raw JSON stays untouched on re-encode (D23)
- writing `passages` and the accessors round-trips every unknown key (02 §9 passthrough)

**Tests:**

```swift
func testAD10PassageAndReferenceDecode() throws {
    let doc = try ActivityDocument.fixture(bible: Self.d10JSON)
    XCTAssertEqual(doc.passages, [BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3,
        verseEnd: 18, startOffset: 9, endOffset: nil, translation: "ENGKJV")])
    let s = doc.textObjects.first { $0.role == "scripture" }!
    XCTAssertEqual(s.listStyle, "bibleVerse"); XCTAssertEqual(s.startNumber, 16)
    XCTAssertEqual(s.reference?.start.offset, 9); XCTAssertEqual(s.reference?.translation, "ENGKJV")
    XCTAssertTrue(s.isLockedScripture)
}
func testALegacyPassageHasNoTranslationAndIsNotLocked() throws {
    let doc = try ActivityDocument.fixture(bible: Self.legacyJSON)
    XCTAssertNil(doc.passages.first?.translation)
    XCTAssertFalse(doc.textObjects.contains { $0.isLockedScripture })
}
func testPassagesRoundTripUnknownKeys() throws {
    var doc = try ActivityDocument.fixture(bible: Self.d10JSON)
    doc.passages = doc.passages
    XCTAssertEqual(try doc.jsonObject()["content.passages.0.extra"] as? String, "keep")
}
```

(`d10JSON` = the Task 4 fixture document with `"extra":"keep"` on the passage; `legacyJSON` = `fixtures/activity-samples.ts:97-108`. Use whatever document-from-JSON and key-path helpers `ActivityDocumentTests.swift` already has; `fixture(bible:)`/`jsonObject()` stand for them.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BiblePassageDecodingTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it and `ActivityDocumentTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): decode passages and scripture references`

### Task 6: The book catalog — categories, unique abbreviations, chapter stepping
App: iphone
Phase: 2
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/Services/BibleCacheManager.swift:96-160` (`bookData`) — a `category` per book; "Phil"/"Phlm"
- Create: `iphone/MakeReady/Services/BibleBookCatalog.swift` — category enum, testament, chapter stepping
- Test: `iphone/MakeReadyCaptureTests/BibleBookCatalogTests.swift`

**Interfaces:**
- Produces: `BibleCategory` — `law`, `history`, `wisdom`, `majorProphets`, `minorProphets`, `gospelsActs`, `pauline`, `general`, `apocalyptic`; `BibleCategory.colorToken: String` — `bibleOlive`, `bibleTeal`, `bibleGreen`, `bibleBrown`, `bibleMaroon` (Task 8 asks d2m for these exact names); `BibleBookCatalog.book(_ number: Int) -> BookInfo?`, `.category(of:)`, `.isOldTestament(_:)`, `.chapterCount(of:)`; `BibleBookCatalog.step(book:chapter:by:) -> (book: Int, chapter: Int)?` — ±1 chapter, across books, nil past Genesis 1 / Revelation 22.

**Behaviour:**
- categories by `BibleData.swift:21-70`: books 1–5 law, 6–17 history, 18–22 wisdom, 23–27 major prophets, 28–39 minor prophets, 40–44 gospels/acts, 45–57 Pauline, 58–65 general, 66 apocalyptic (D5)
- token mapping: law + Pauline → olive (`#424216`), history + major prophets → teal (`#143F45`), wisdom → green (`#254422`), minor prophets + general → brown (`#563B2D`), gospels/acts + apocalyptic → maroon (`#563139`) (D5)
- abbreviations are unique across all 66 (Philippians "Phil", Philemon "Phlm") (D18)
- stepping uses the bundled chapter counts, never the server's `navigation` (D4)

**Tests:**

```swift
func testEveryBookHasACategoryAndUniqueAbbreviation() {
    let books = (1...66).compactMap { BibleBookCatalog.book($0) }
    XCTAssertEqual(books.count, 66)
    XCTAssertEqual(Set(books.map(\.abbreviation)).count, 66)
    XCTAssertEqual(BibleBookCatalog.book(50)?.abbreviation, "Phil"); XCTAssertEqual(BibleBookCatalog.book(57)?.abbreviation, "Phlm")
}
func testMinorProphetsShareOneColour() {
    XCTAssertEqual(Set((28...39).map { BibleBookCatalog.category(of: $0).colorToken }), ["bibleBrown"])
    XCTAssertEqual(BibleBookCatalog.category(of: 1).colorToken, BibleBookCatalog.category(of: 45).colorToken)
}
func testChapterSteppingCrossesBooksAndStopsAtTheEnds() {
    XCTAssertEqual(BibleBookCatalog.step(book: 1, chapter: 50, by: 1)?.book, 2)
    XCTAssertEqual(BibleBookCatalog.step(book: 2, chapter: 1, by: -1).map { [$0.book, $0.chapter] }, [1, 50])
    XCTAssertNil(BibleBookCatalog.step(book: 1, chapter: 1, by: -1))
    XCTAssertNil(BibleBookCatalog.step(book: 66, chapter: 22, by: 1))
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleBookCatalogTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): bible book categories and chapter stepping`

### Task 7: `BibleActions` and the AppState Bible domain
App: iphone
Phase: 2
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/State/Actions/BibleActions.swift`
- Modify: `iphone/MakeReady/State/AppState.swift:257-264, 1092-1107` — the Bible domain
- Modify: `iphone/MakeReady/State/Models/ExtractedModels.swift:69-95` — `BibleVersion.popularity: Int?`
- Create: `iphone/MakeReady/State/Models/BibleModels.swift` — chapter and smart-search response types
- Modify: `iphone/MakeReady/Services/BibleCacheManager.swift:287-377` — versioned disk key; chapter fetch exposes `copyright` and throws
- Test: `iphone/MakeReadyCaptureTests/BibleActionsTests.swift`

**Interfaces:**
- Consumes: §Contract rows `/translations`, `/:code/:book/:chapter`, `/search/smart` (with `record`), `GET /search/recent?type=bible`, `DELETE /search/recent/:id`.
- Produces: `BibleActions(api:state:)` with `loadTranslations()`, `loadChapter(book:chapter:translation:) async throws -> BibleChapter`, `search(_ query: String, record: Bool) async`, `loadRecents() async`, `deleteRecent(id:) async`; `BibleChapter` — `book`, `chapter: Int`, `translation: String`, `verses: [BibleVerse]` (`verse: Int`, `text: String`), `copyright: String`; `BibleSearchResult` — `.direct(book: Int, chapter: Int, verses: [BibleVerse])`, `.grouped(books: [BibleBookHit], verses: [BibleVerseHit])` (also for `semantic`), `.error(String)`; `BibleVerseHit` — `bookNumber`, `chapter`, `verse`, `verseEnd: Int?`, `reference`, `text`, `title`, `summary: String?`; AppState: `bibleSearchResult: BibleSearchResult?`, `bibleRecents: [BibleRecent]` (`id`, `query`), `bibleChapters: [String: BibleChapter]` keyed `"\(translation)|\(book)|\(chapter)"`, `selectedBibleTranslation`, `sortedBibleTranslations: [BibleVersion]`.

**Behaviour:**
- translations ordered by `popularity` descending (nil last), then `name` (D7); if `selectedBibleTranslation` is not a served `code`, it becomes the served code whose `name` equals the stored code's `knownBibleVersions` name, else the first in order (D7: store the code as served)
- the chapter disk cache key carries `v2`; a cached chapter is returned without a request; a failed fetch throws a typed `BibleActionsError.chapterUnavailable` and writes nothing (D9, D18, D24)
- `search` always sends `translation` = `selectedBibleTranslation`, `limit: 10` and `record`; a response for a superseded query is dropped; `{type:"error"}` and thrown errors surface the top banner (`recordError(... surface: true)`) and keep the last result (D17)
- `deleteRecent` removes the row from `bibleRecents` on success; failure surfaces the banner and keeps the row (D17)

**Tests:**

```swift
func testTranslationsArePopularFirstAndKJVResolvesToTheServedCode() async {
    api.stub("GET", "/api/bible/translations", json: #"{"translations":[{"id":"a","code":"WEBBE","name":"World English Bible, British Edition","language":"eng","copyright":"","popularity":10},{"id":"b","code":"ENGKJV","name":"King James (Authorised) Version","language":"eng","copyright":"","popularity":80},{"id":"c","code":"NIV11","name":"New International Version","language":"eng","copyright":"","popularity":100}]}"#)
    state.selectedBibleTranslation = "KJV"
    await actions.loadTranslations()
    XCTAssertEqual(state.sortedBibleTranslations.map(\.code), ["NIV11", "ENGKJV", "WEBBE"])
    XCTAssertEqual(state.selectedBibleTranslation, "ENGKJV")
}
func testSearchSendsRecordAndTranslation() async {
    api.stub("POST", "/api/search/smart", json: #"{"type":"grouped","books":[],"verses":[]}"#)
    await actions.search("jo", record: false)
    let body = api.calls.last!.body!
    XCTAssertEqual(body["record"] as? Bool, false); XCTAssertEqual(body["translation"] as? String, state.selectedBibleTranslation)
}
func testEverySmartSearchTypeDecodes() throws {
    XCTAssertEqual(try decode(#"{"type":"direct","book":{"bookNumber":43,"name":"John","abbrev":"John"},"chapter":3,"verses":[{"verse":16,"text":"For God","reference":"John 3:16"}]}"#), .direct(book: 43, chapter: 3, verses: [BibleVerse(verse: 16, text: "For God")]))
    if case .grouped(_, let v) = try decode(#"{"type":"semantic","books":[],"verses":[{"bookNumber":19,"chapter":23,"verse":1,"verseEnd":6,"reference":"Psalm 23:1-6","text":"The Lord","title":"The Shepherd","summary":"Care"}]}"#) {
        XCTAssertEqual(v.first?.verseEnd, 6) } else { XCTFail() }
    XCTAssertEqual(try decode(#"{"type":"error","error":"nope"}"#), .error("nope"))
}
func testAnErrorTypeSurfacesTheBanner() async {
    api.stub("POST", "/api/search/smart", json: #"{"type":"error","error":"Translation not found"}"#)
    await actions.search("john", record: true)
    XCTAssertNotNil(state.currentError)
}
func testDeleteRecentRemovesTheRow() async {
    state.bibleRecents = [BibleRecent(id: "r1", query: "grace"), BibleRecent(id: "r2", query: "love")]
    api.stub("DELETE", "/api/search/recent/r1", json: #"{"success":true}"#)
    await actions.deleteRecent(id: "r1")
    XCTAssertEqual(state.bibleRecents.map(\.id), ["r2"])
}
func testAFailedChapterThrowsTypedAndWritesNothing() async {
    api.errorToThrow = URLError(.notConnectedToInternet)
    do { _ = try await actions.loadChapter(book: 43, chapter: 3, translation: "ENGKJV"); XCTFail() }
    catch { XCTAssertEqual(error as? BibleActionsError, .chapterUnavailable) }
    XCTAssertTrue(state.bibleChapters.isEmpty)
}
```

(`decode` = `JSONDecoder.apiDecoder` into `BibleSearchResult`; `currentError` = whatever property `recordError` writes — read `AppState.recordError`. Setup as `SearchActionsTests.swift:24-40`. The disk cache must be injectable or cleared in setUp so a cached chapter cannot mask the failure case.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleActionsTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour** — route the chapter fetch through `APIClientProtocol` so the stub sees it; `BibleCacheManager` keeps only the disk cache
- [ ] **Step 4: Run it and `SearchActionsTests`, `StatePersistenceRoundTripTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): BibleActions and the AppState Bible domain`

### Task 8: File the d2m handover requests and wait for the builds
App: iphone
Phase: 3
Recipe: REFERENCE §Prototype mode (design is d2m's; this task only requests and records)

**Files:**
- Create/modify (by d2m, not by hand): `iphone/MakeReadyUI/Screens/Bible/BibleBooksScreen.swift`, `BibleChaptersScreen.swift`, `BibleVersesScreen.swift`, `BibleReaderScreen.swift`, `iphone/MakeReadyUI/BibleVerseReader.swift`, `DayChip.swift`, `SearchResultRow.swift`, `Tokens.swift`, `CanvasTextObject.swift`, `Screens/Activities/ActivitiesEditorScreen.swift`, `ActivityTypeGrid` host if it gates the tile
- Create: `.builder/bible-verse-picker/d2m-api.md` (workspace, git-ignored) — the names d2m shipped, for Tasks 9–15

**Interfaces:**
- Consumes: SPEC §Decisions D3–D7, D10–D12, D17, D20, D21, §iphone; screen ids from Task 4; token names from Task 6.
- Produces (requested names; `d2m-api.md` records any deviation, and Tasks 9–15 use what it records):
  - `BibleBooksScreen.State` — `translationCode`, `query`, `isSearchFocused`, `oldTestament`/`newTestament: [BookCell]` (`number`, `label`, `colorToken`, `isUsed`), `recents: [Recent]`, `results: Results?` (`books`, `verses` rows), `isSearching`, `isEmpty`; callbacks `onBack`, `onBook(Int)`, `onQuery(String)`, `onSubmit`, `onRecent(String)`, `onRemoveRecent(String)`, `onBookResult(Int)`, `onVerseResult(Int)` (row index), `onTranslation(String)`, `translations: [(code, name)]`
  - `BibleChaptersScreen.State` / `BibleVersesScreen.State` — `title`, `cells: [NumberCell]` (`number`, `isUsed`), `isLoading`; `onBack`, `onSelect(Int)`
  - `BibleReaderScreen.State` — `title`, `translationCode`, `translations`, `chapterHeading`, `verses: [(number, text)]`, `selection: BibleVerseReader.Selection?`, `usedRanges: [BibleVerseReader.Selection]`, `copyright`, `scrollToVerse: Int?`, `isLoading`, `canSelect`; `onBack`, `onSelect`, `onSelectionChange(Selection?)`, `onSwipeChapter(Int)` (±1), `onTranslation(String)`, `onTopVerseChange(Int)`
  - `BibleVerseReader.Selection` — `startVerse`, `startOffset`, `endVerse`, `endOffset: Int` (UTF-16, end exclusive, word-snapped) (D4, D8)
  - C-052 `DayChip.Content.label(String)`, `fillToken: String?`, `isUsed: Bool` (2 pt solid `accent`); C-085 kinds `.book(dotToken:)`, `.verse` with 2-line description; tokens `bibleOlive`, `bibleTeal`, `bibleGreen`, `bibleBrown`, `bibleMaroon`
  - C-092 `CanvasTextObject` `isLocked: Bool`, highlighting mode reporting `onHighlightRange(start:end:)`; `BibleReferenceFormatter` `b`/`a` partial markers
  - `ActivitiesEditorScreen.State.showsHighlightTool`, per-object `isLocked`, `highlightingObjectID: String?`; callbacks `onHighlightRange(objectIndex:start:end:)`, `onEndHighlighting()`

**Behaviour:**
- the five colour tokens first, by `set_color_token` with D5's hexes (D5)
- then one `request_project_change` per subject: the four screens (ids `bible-books` … `bible-reader`, fixtures `server/fixtures/screens/bible-books.ts`, `bible-reader.ts`), BibleVerseReader (new, D4 — gestures per D4 and F17: chapter swipe starts outside the leading edge-swipe zone; touch-and-hold drag vs vertical scroll), C-052 (D5), C-085 (D6), C-092 + ActivitiesEditorScreen (D11, D21, `BibleReferenceFormatter` per D10/OQ-C-092-004); each with `references: ["docs/features/bible-verse-picker/SPEC.md"]`, `branch: "builder/bible-verse-picker"`, intent ≤ 2000 characters naming its decisions; C-066 glyphs for **Change passage** / **Highlight** chosen in the editor request (D12); empty search uses C-132 glyph `search`, "No results found", "Try a book, a reference or words from a verse." (D17)
- `wait_project_change` until each is done; a handback is settled from the SPEC (questions → `answer_project_change` with the ruling's text; held → `approve_project_change`; failed step → `retry_project_change`); park only on `next` starting `cannot be done:` (F16)
- any new component beyond BibleVerseReader that d2m proposes is refused citing D3

**Tests:**
- `the app still builds and its suite passes on d2m's last commit` — existing tests

```swift
// No new assertions: d2m's own builds capture and diff each subject. The gate is MakeReadyCaptureTests
// compiling and passing on d2m's final commit; cases d2m made obsolete are listed in d2m-api.md.
```

- [ ] **Step 1: Confirm a clean tree** — `git status --short iphone/` is empty
- [ ] **Step 2: Set the five colour tokens, then file the requests** — as the Behaviour says
- [ ] **Step 3: Wait and settle handbacks** — `wait_project_change` per subject until done
- [ ] **Step 4: Record the shipped names** — write `d2m-api.md` from d2m's landed diffs (`git log -p`)
- [ ] **Step 5: Run the iphone-xctest suite on HEAD** — PASS except cases listed in `d2m-api.md`

### Task 9: Picker destinations, flow state and the one-write return
App: iphone
Phase: 4
Recipe: /nav-route

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:18-110` — four destinations, `isFullScreen`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Navigation.swift:6-19` and the shell's navigator construction — `popToAndPush`
- Create: `iphone/MakeReady/UI2/Containers/Bible/BiblePickFlow.swift` — flow record + pick mailbox
- Modify: `iphone/MakeReady/State/AppState.swift` — `biblePickFlows: [UUID: BiblePickFlow]`
- Test: `iphone/MakeReadyCaptureTests/BiblePickFlowTests.swift`, `UI2ShellModelTests.swift`

**Interfaces:**
- Produces: `UI2Destination.bibleBooks(flowId: UUID)`, `.bibleChapters(book: Int, flowId: UUID)`, `.bibleVerses(book: Int, chapter: Int, flowId: UUID)`, `.bibleReader(book: Int, chapter: Int, verse: Int, flowId: UUID)`, all `isFullScreen`; `UI2Navigator.popToAndPush: (Int, UI2Destination?) -> Void` — pops to depth and optionally pushes, as ONE path write; `BiblePickFlow` — `caller: Caller` (`.newActivity(lessonId: String, afterActivityId: String?)` | `.change(activityId: String)`), `returnDepth: Int`, `used: [BiblePassage]`, `initial: BiblePassage?`; `BiblePassagePick.shared` with `deliver(_ pick: BiblePick, for flowId: UUID)` / `take(for:) -> BiblePick?`; `BiblePick` — `passage: BiblePassage`, `verses: [BibleVerse]` (the chapter's canonical text for `verseStart...verseEnd`), `bookName: String`.

**Behaviour:**
- Select = `deliver` then `popToAndPush(flow.returnDepth, nil)` — the whole picker leaves in one write (D2, D25)
- Back from Books pops one page and delivers nothing (D15)
- the flow record is removed when its pick is taken (D2)
- no picker destination has a deep link (D24)

**Tests:**

```swift
func testPickerPagesAreFullScreen() {
    let f = UUID()
    for d in [UI2Destination.bibleBooks(flowId: f), .bibleChapters(book: 43, flowId: f),
              .bibleVerses(book: 43, chapter: 3, flowId: f), .bibleReader(book: 43, chapter: 3, verse: 16, flowId: f)] {
        XCTAssertTrue(d.isFullScreen) }
}
func testPopToAndPushIsOnePathWrite() {
    var writes = 0
    let path = PathRecorder(depth: 6) { writes += 1 }
    path.navigator.popToAndPush(2, nil)
    XCTAssertEqual(path.depth, 2); XCTAssertEqual(writes, 1)
}
func testAPickIsTakenOnceAndClearsItsFlow() {
    let f = UUID(); state.biblePickFlows[f] = BiblePickFlow(caller: .change(activityId: "a"), returnDepth: 2, used: [], initial: nil)
    BiblePassagePick.shared.deliver(Self.pick, for: f)
    XCTAssertEqual(BiblePassagePick.shared.take(for: f), Self.pick)
    XCTAssertNil(BiblePassagePick.shared.take(for: f))
}
```

(`PathRecorder` — build the navigator the way the shell does in `UI2Navigation.swift`, over a recorded path binding; if the shell's construction is private, expose an internal factory taking the binding.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BiblePickFlowTests` and `UI2ShellModelTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour** — the shell's destination switch gets the four cases rendering `EmptyView()`; Tasks 10–11 replace each with its container
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): picker destinations and flow return`

### Task 10: Books (with search and translation), Chapters and Verses pages
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Bible/BibleBooksContainer.swift`, `BibleChaptersContainer.swift`, `BibleVersesContainer.swift`, `BiblePickerMapper.swift`
- Modify: the shell's destination switch — route `.bibleBooks`, `.bibleChapters`, `.bibleVerses`
- Test: `iphone/MakeReadyCaptureTests/BiblePickerMapperTests.swift`

**Interfaces:**
- Consumes: `BibleBooksScreen`/`BibleChaptersScreen`/`BibleVersesScreen` `State` and callbacks (Task 8, `d2m-api.md`); `BibleBookCatalog`; `BibleActions`; `BiblePickFlow.used`.
- Produces: `BiblePickerMapper.books(used:recents:result:translation:query:) -> BibleBooksScreen.State`, `.chapters(book:used:)`, `.verses(book:chapter:verseCount:used:)`; `BiblePickerMapper.isUsed(book:chapter:verse:in:)`; `BibleSearchDebouncer` (300 ms).

**Behaviour:**
- Books: OT then NT, 5 columns, each cell `fillToken` = its category token, `label` = catalog abbreviation (D5); used book/chapter/verse = any passage in `used` touches it, rendered `isUsed` (D16, D5)
- Chapters always shown, even for one-chapter books; 6 columns (D1, D5)
- Verses: `isLoading` until the chapter's verse count for THIS chapter arrives; failure → banner with Retry (D18, D24)
- search: typing searches after 300 ms with `record: false`, no minimum; return searches at once with `record: true` and dismisses the keyboard; empty field + focus shows recents or "Type to search the Bible"; book result → Chapters; verse result → Reader at that verse with `verseStart...verseEnd` preselected for a named passage (D1, D17)
- the translation chip shows the full `code`; choosing one sets `selectedBibleTranslation` and re-runs an active search (D7)
- Back on Books pops and delivers nothing (D15)

**Tests:**

```swift
func testBooksAreColouredAndUsedIsMarked() {
    let s = BiblePickerMapper.books(used: [Self.john3], recents: [], result: nil, translation: "ENGKJV", query: "")
    XCTAssertEqual(s.oldTestament.count, 39); XCTAssertEqual(s.newTestament.count, 27)
    XCTAssertEqual(s.oldTestament[27].colorToken, "bibleBrown")
    XCTAssertTrue(s.newTestament[3].isUsed); XCTAssertFalse(s.newTestament[2].isUsed)
}
func testAOneChapterBookStillListsItsChapter() {
    XCTAssertEqual(BiblePickerMapper.chapters(book: 57, used: []).cells.map(\.number), [1])
}
func testVersesWaitForTheirOwnChapterCount() {
    XCTAssertTrue(BiblePickerMapper.verses(book: 43, chapter: 4, verseCount: nil, used: []).isLoading)
    let v = BiblePickerMapper.verses(book: 43, chapter: 3, verseCount: 36, used: [Self.john3])
    XCTAssertEqual(v.cells.filter(\.isUsed).map(\.number), [16, 17, 18])
}
func testTypingSearchesUnrecordedAfter300msAndReturnRecords() async {
    let d = BibleSearchDebouncer(delay: .milliseconds(300)) { q, rec in calls.append((q, rec)) }
    d.type("j"); d.type("jo"); try? await Task.sleep(for: .milliseconds(400))
    d.submit("john 3:16")
    XCTAssertEqual(calls.map(\.0), ["jo", "john 3:16"]); XCTAssertEqual(calls.map(\.1), [false, true])
}
```

(`john3` = `BiblePassage(43, 3, 16, 3, 18, 9, nil, "ENGKJV")`.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BiblePickerMapperTests`, watch them fail**
- [ ] **Step 3: Implement the mapper, debouncer and three containers to the Behaviour** — copy `SearchHomeScreen` wiring (`MakeReadyUI/Screens/Search/SearchHomeScreen.swift:40-130`) for C-131 + recents
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): books, chapters and verses pages`

### Task 11: The Reader page — selection, chapter swipe, translation, Select
App: iphone
Phase: 4
Recipe: /transition-review

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Bible/BibleReaderContainer.swift`, `BibleReaderMapper.swift`
- Modify: the shell's destination switch — route `.bibleReader`
- Test: `iphone/MakeReadyCaptureTests/BibleReaderMapperTests.swift`

**Interfaces:**
- Consumes: `BibleReaderScreen.State`, `BibleVerseReader.Selection` (Task 8); `BibleActions.loadChapter`; `BibleBookCatalog.step`; `BiblePassagePick`, `UI2Navigator.popToAndPush` (Task 9).
- Produces: `BibleReaderMapper.passage(from: Selection, book: Int, chapter: Int, verses: [BibleVerse], translation: String) -> BiblePassage`; `BibleReaderMapper.selection(from: BiblePassage, verses: [BibleVerse]) -> Selection` (absent offsets → 0 / the verse's UTF-16 length); `BibleReaderMapper.state(chapter: BibleChapter, selection: Selection?, used: [BiblePassage], top: Int) -> BibleReaderScreen.State`; `BibleReaderMapper.pick(passage:chapter:bookName:) -> BiblePick`.

**Behaviour:**
- a selection covering a whole first verse writes no `startOffset`; one ending at its last verse's end writes no `endOffset` (D8: absent = whole verse)
- `canSelect` only while a selection exists; Select delivers the pick for the flow and pops the picker in one write (D2, D25)
- swipe ±1 steps by `BibleBookCatalog.step`, loads that chapter and clears the selection; nil step = no change (rubber band is the view's) (D4)
- translation change reloads at the verse currently at the top, clears the selection, writes `selectedBibleTranslation` (D7)
- opened from Change passage: `initial` passage preselected and scrolled to (D12); used ranges from the flow drawn as underlay (D16)
- copyright from the chapter response under the last verse (D20); chapter failure → banner with Retry (D24)

**Tests:**

```swift
func testAPartialSelectionKeepsItsOffsets() {
    let p = BibleReaderMapper.passage(from: .init(startVerse: 16, startOffset: 9, endVerse: 18, endOffset: Self.v18.utf16.count),
        book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
    XCTAssertEqual(p, BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18,
        startOffset: 9, endOffset: nil, translation: "ENGKJV"))
}
func testAWholeVerseSelectionHasNoOffsets() {
    let p = BibleReaderMapper.passage(from: .init(startVerse: 16, startOffset: 0, endVerse: 16, endOffset: Self.v16.utf16.count),
        book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
    XCTAssertNil(p.startOffset); XCTAssertNil(p.endOffset)
}
func testSelectionRoundTripsThroughAPassage() {
    let sel = BibleVerseReader.Selection(startVerse: 16, startOffset: 9, endVerse: 17, endOffset: 12)
    let p = BibleReaderMapper.passage(from: sel, book: 43, chapter: 3, verses: Self.verses, translation: "ENGKJV")
    XCTAssertEqual(BibleReaderMapper.selection(from: p, verses: Self.verses), sel)
}
func testSelectIsDisabledWithoutASelection() {
    XCTAssertFalse(BibleReaderMapper.state(chapter: Self.chapter, selection: nil, used: [], top: 1).canSelect)
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleReaderMapperTests`, watch them fail**
- [ ] **Step 3: Implement the mapper and container to the Behaviour**; run `/transition-review` over the diff (F17)
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): the Reader page and Select`

### Task 12: Scripture document logic — mapping, used, re-anchoring, splitting
App: iphone
Phase: 5
Recipe: test-driven-development

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Bible/BibleScripture.swift`
- Test: `iphone/MakeReadyCaptureTests/BibleScriptureTests.swift`

**Interfaces:**
- Consumes: `BiblePick`, `BiblePassage`, `ScriptureReference` (Tasks 5, 9); `BibleReferenceFormatter` with `b`/`a` (Task 8).
- Produces: `BibleScripture.citation(_ passage: BiblePassage, bookName: String) -> String`; `.document(for pick: BiblePick, background: ActivityDocument.Background?) -> ActivityDocument`; `.title(for:bookName:)`; `.used(in activities: [ContentActivity]) -> [BiblePassage]`; `.reanchor(highlights: [TextObject.Highlight], old: BiblePick, new: BiblePick) -> (kept: [TextObject.Highlight], removed: Int)`; `.split(_ pick: BiblePick, fits: ([BibleVerse]) -> Bool) -> [BiblePick]`; `.fits(verses:width:) -> Bool` at the D10 default style.

**Behaviour:**
- document: scripture `role: scripture`, `listStyle: bibleVerse`, `startNumber` = `verseStart`, text = verses joined by `\n`, first trimmed from `startOffset`, last cut at `endOffset`; `font: serif`, size 18, left, 32 pt side insets, top 96 on 440×956; citation 16 pt below, serif 14; `reference` per SC2 on scripture only, never passed to C-092's citation line; `content.passages` = [passage] (D10)
- citation: formatter string, `b` on a start verse beginning mid-verse, `a` on an end verse ending mid-verse, hyphen, then a space and the translation code; no code when `translation` is nil — e.g. "John 3:16b-18 ENGKJV"; title = citation without the code (D10, Data plan)
- used: every passage of every `bible` activity in the lesson's draft (D16)
- re-anchor: a highlight kept when every word is inside the new passage, its offsets moved to the new text; a different translation removes all (D13)
- split: at verse boundaries only, greedy, each part fits = scripture + citation height ≤ 956 − 192 at the D10 style; a partial start/end offset stays on the first/last part (D14)

**Tests:**

```swift
func testCitationMarksPartialEnds() {
    XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: 9, endOffset: nil, translation: "ENGKJV"), bookName: "John"), "John 3:16b-18 ENGKJV")
    XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18, startOffset: nil, endOffset: 20, translation: "ENGKJV"), bookName: "John"), "John 3:16-18a ENGKJV")
    XCTAssertEqual(BibleScripture.citation(.init(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 16, startOffset: nil, endOffset: nil, translation: nil), bookName: "John"), "John 3:16")
}
func testTheDocumentCarriesTrimmedNumberedScriptureAndItsPassage() {
    let doc = BibleScripture.document(for: Self.pick16b18, background: nil)
    let s = doc.textObjects[0]
    XCTAssertEqual(s.role, "scripture"); XCTAssertEqual(s.startNumber, 16); XCTAssertEqual(s.listStyle, "bibleVerse")
    XCTAssertEqual(s.text, [String(Self.v16.utf16.dropFirst(9))!, Self.v17, Self.v18].joined(separator: "\n"))
    XCTAssertEqual(s.reference?.start.offset, 9); XCTAssertNil(doc.textObjects[1].reference)
    XCTAssertEqual(doc.textObjects[1].text, "John 3:16b-18 ENGKJV"); XCTAssertEqual(doc.passages, [Self.pick16b18.passage])
}
func testReanchorKeepsInsideAndCountsOutside() {
    let r = BibleScripture.reanchor(highlights: [Self.hlEternalLifeIn16, Self.hlIn18], old: Self.pick16b18, new: Self.pick16to17)
    XCTAssertEqual(r.kept.count, 1); XCTAssertEqual(r.removed, 1)
    XCTAssertEqual(r.kept[0].start, Self.offsetOfEternalLifeIn(Self.pick16to17))
}
func testATranslationChangeRemovesEveryHighlight() {
    XCTAssertEqual(BibleScripture.reanchor(highlights: [Self.hlEternalLifeIn16], old: Self.pick16b18, new: Self.pick16b18WEB).removed, 1)
}
func testSplitAtVerseBoundariesKeepsPartialEnds() {
    let parts = BibleScripture.split(Self.john3All, fits: { $0.count <= 12 })
    XCTAssertEqual(parts.map { [$0.passage.verseStart, $0.passage.verseEnd] }, [[1, 12], [13, 24], [25, 36]])
}
func testUsedCollectsEveryBiblePassageInTheDraft() {
    XCTAssertEqual(BibleScripture.used(in: [Self.bibleActivity, Self.textActivity]), [Self.pick16b18.passage])
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleScriptureTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): scripture document, citation, re-anchor and split`

### Task 13: The Bible tile creates activities, split and ordered
App: iphone
Phase: 5
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:18, 115-231` — `unavailableTypes` loses `bibleVerse`; `selectBible()`; `createBible(pick:)`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:581-623` — in-place grid's Bible path; `placeAfterInsertPoint` moves several
- Create: `iphone/MakeReady/UI2/Containers/Bible/BibleSave.swift` — the ordered multi-request save with resume
- Test: `iphone/MakeReadyCaptureTests/BibleSaveTests.swift`, `ActivityNewContainerTests.swift`

**Interfaces:**
- Consumes: `ActivityNewContainer.Actions` (`draftVersionId`, `create`, `reorder`); `BibleScripture.split/document/title`; `BiblePickFlow`, `BiblePassagePick` (Task 9).
- Produces: `BibleSave.Plan` — `posts: [ActivityDocument]`, `order: [String]?`, `put: (activityId: String, document: ActivityDocument)?`; `BibleSave.run(_ plan:, actions:, from step: Int) async -> Result<[String], BibleSave.Failure>` where `Failure` carries the failed step index `step` (for Retry); `BibleSave.plan(new: [BiblePick], version: String, existing: [String], after: String?) -> Plan` and `BibleSave.plan(change: String, parts: [BiblePick], version: String, existing: [String]) -> Plan`, created ids substituted into `order` as they land; `ActivityNewContainer.Model.selectBible()` pushes `.bibleBooks` with a new flow (`.newActivity(lessonId:afterActivityId:)`, `returnDepth` = current depth).

**Behaviour:**
- the Bible tile is enabled on New Activity and in the editor's grid; tapping pushes Books; Back creates nothing (D15)
- on pick: parts = `split`; new activity → POST each part in order, then `PATCH …/order` placing them after the insert point (text-activity-v2 D37 slot), then open the first in the editor (D14, D15)
- change of an existing activity → POST every extra part, `PATCH …/order` placing them after it, PUT the original last (D14)
- a failure stops; the banner shows with Retry; Retry resumes from the failed step, never re-POSTing a created part (D14, F15 — build-time risk: half-split lesson)
- the editor shows its existing save state during the save; Select never waited on it (D25)

**Tests:**

```swift
func testANewSplitPassagePostsInOrderThenReorders() async {
    let r = await BibleSave.run(BibleSave.plan(new: Self.threeParts, version: "v", existing: ["a", "b"], after: "a"), actions: stub.actions, from: 0)
    XCTAssertEqual(stub.log, ["POST", "POST", "POST", "PATCH a,p1,p2,p3,b"]); XCTAssertEqual(try r.get(), ["p1", "p2", "p3"])
}
func testAChangeSplitPutsTheOriginalLast() async {
    _ = await BibleSave.run(BibleSave.plan(change: "a", parts: Self.twoParts, version: "v", existing: ["a", "b"]), actions: stub.actions, from: 0)
    XCTAssertEqual(stub.log, ["POST", "PATCH a,p1,b", "PUT a"])
}
func testRetryResumesFromTheFailedStep() async {
    stub.failAt = 1
    guard case .failure(let f) = await BibleSave.run(Self.plan3, actions: stub.actions, from: 0) else { return XCTFail() }
    XCTAssertEqual(f.step, 1); stub.failAt = nil
    _ = await BibleSave.run(Self.plan3, actions: stub.actions, from: f.step)
    XCTAssertEqual(stub.log.filter { $0 == "POST" }.count, 3)
}
func testTheBibleTileIsAvailable() {
    XCTAssertFalse(ActivityNewContainer.unavailableTypes.contains(ActivityTypeGrid.ActivityType.bibleVerse.rawValue))
}
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleSaveTests` and `ActivityNewContainerTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them and `ActivitiesEditorContainerTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): the Bible tile creates split, ordered activities`

### Task 14: The editor — locked scripture, the passage menu, highlighting, change passage
App: iphone
Phase: 5
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift:19-155` — `showsHighlightTool` for `bible`; per-object `isLocked`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift:302-330, 456-461` — `tapObject` routing, highlighting mode, change passage, delete confirm
- Create: `iphone/MakeReady/UI2/Containers/Bible/BiblePassageMenu.swift` — the D12 menu and D11/D13 confirmations, after `ActivitySlideMenu.swift:6-30`
- Test: `iphone/MakeReadyCaptureTests/BibleEditorTests.swift`

**Interfaces:**
- Consumes: `ActivitiesEditorScreen.State.showsHighlightTool`, `isLocked`, `highlightingObjectID`, `onHighlightRange`, `onEndHighlighting` (Task 8, `d2m-api.md`); `TextObject.isLockedScripture` (Task 5); `BibleScripture.reanchor/document`, `BibleSave` (Tasks 12–13); `BiblePickFlow` (Task 9).
- Produces: `BiblePassageMenu.items` — `Change passage`, `Highlight`; `BiblePassageMenu.changeConfirmation(removed: Int)` and `.deleteConfirmation`; `ActivitiesEditorContainer.Model.changePassage(pick:)`.

**Behaviour:**
- `bible` activities only: `showsHighlightTool` true; `text` keeps it hidden (D21)
- locked scripture/citation: no text input, no text deletion; move, scale, rotate, restyle, highlight, notes allowed (D11); legacy objects without `reference` are ordinary text (D23)
- tapping a locked object in Idle opens the menu; **Change passage** pushes Books→Reader at the current passage (the flow's `initial`, Reader at its chapter, selection shown); **Highlight** enters highlighting mode without the keyboard (D12, D21)
- a highlight range toggles a highlight through the existing callbacks; notes as today (D21)
- change: re-anchor; if any removed, the confirmation — title "Change passage?", message "N highlights are outside the new passage and will be removed" (N = count; "1 highlight is outside the new passage and will be removed" for one), confirm "Change", cancel "Cancel" — before saving; then split/save via `BibleSave` (D13, D14)
- deleting a locked object asks first, then deletes the whole passage (both objects) (D11)

**Tests:**

```swift
func testOnlyBibleShowsTheHighlightTool() {
    XCTAssertTrue(ActivitiesEditorMapper.state(Self.bibleDoc).showsHighlightTool)
    XCTAssertFalse(ActivitiesEditorMapper.state(Self.textDoc).showsHighlightTool)
}
func testReferencedScriptureIsLockedAndLegacyIsNot() {
    XCTAssertEqual(ActivitiesEditorMapper.state(Self.bibleDoc).objects.map(\.isLocked), [true, true])
    XCTAssertEqual(ActivitiesEditorMapper.state(Self.legacyBibleDoc).objects.map(\.isLocked), [false, false])
}
func testTappingLockedScriptureOpensThePassageMenu() async {
    await model.tapObject(0)
    XCTAssertEqual(presenter.lastMenu?.titles, ["Change passage", "Highlight"]); XCTAssertNil(model.editingIndex)
}
func testAChangeThatDropsAHighlightAsksWithTheCount() async {
    await model.changePassage(pick: Self.pick1to2)
    XCTAssertEqual(presenter.lastConfirmation?.title, "Change passage?")
    XCTAssertEqual(presenter.lastConfirmation?.message, "1 highlight is outside the new passage and will be removed")
    XCTAssertEqual(presenter.lastConfirmation?.confirm, "Change")
}
func testAChangeThatKeepsEveryHighlightSavesWithoutAsking() async {
    await model.changePassage(pick: Self.pick16to21)
    XCTAssertNil(presenter.lastConfirmation); XCTAssertEqual(stub.callCount("PUT", "/api/content-activities/a1"), 1)
}
```

(`ActivitiesEditorMapper.state(doc)` stands for the mapper's document→State entry at `ActivitiesEditorMapper.swift:19-155` — use its real name. `presenter` records `actionMenuPresentation` calls — inject it the way `ActivitySlideMenuTests.swift` does; `model` is the editor model over a stubbed `bibleDoc` activity with "eternal life" highlighted in 3:16.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleEditorTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it and `ActivitiesEditorMapperTests`, `ActivitiesEditorContainerTests`, `ActivitySlideMenuTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): locked scripture, passage menu and highlighting in the editor`

### Task 15: Thumbnails and the player draw verse numbers and highlights
App: iphone
Phase: 5
Recipe: test-driven-development · tiny

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift:133-166` — pass `listStyle`, `startNumber`, highlights
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift:403-440` — never pass `reference` to the object's citation line
- Test: `iphone/MakeReadyCaptureTests/ActivityThumbnailTests.swift`, `ActivityViewerMapperTests.swift`

**Interfaces:**
- Consumes: `TextObject.listStyle`, `startNumber`, `reference` (Task 5).

**Behaviour:**
- thumbnails honour `listStyle: bibleVerse`, `startNumber` and highlights like the player (F13 — build-time risk settled here)
- the player and thumbnail map a scripture object with `reference` WITHOUT C-092's own citation (D10: never drawn twice)

**Tests:**

```swift
func testABibleThumbnailKeepsVerseNumbersAndHighlights() {
    let o = ActivityThumbnail.objects(for: Self.bibleDoc)[0]
    XCTAssertEqual(o.listStyle, .bibleVerse); XCTAssertEqual(o.startNumber, 16); XCTAssertEqual(o.highlights.count, 1)
}
func testThePlayerNeverDrawsTheScriptureReference() {
    XCTAssertNil(ActivityViewerMapper.objects(for: Self.bibleDoc)[0].reference)
}
```

(`ActivityThumbnail.objects(for:)` and `ActivityViewerMapper.objects(for:)` stand for each file's existing document→object mapping — use the real names.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for both classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them, watch them pass**
- [ ] **Step 5: Commit** — `fix(bible-verse-picker): bible thumbnails keep verse numbers and highlights (F13)`

### Task 16: SC6 — verse-number mode and inset on scripture objects
App: server
Phase: 6
Recipe: test-driven-development · tiny

**Files:**
- Modify: `server/src/services/activity-document.ts:30-60, 57-98` — the scripture fields
- Test: `server/src/services/__tests__/activity-document.test.ts`

**Interfaces:**
- §Contract rows `POST /api/lesson-versions/:id/activities` and `PUT /api/content-activities/:id` (EDIT: SC6).

**Behaviour:**
- a `role: scripture` text object in a `bible` document may carry `verseNumbers` ∈ {`gutter`, `hidden`, `inline`} and `inset` (a number, 16 ≤ inset ≤ 64); any other value → 400 VALIDATION (SC6, D27, D28)
- on that object `lineHeight`, when present, is 1.0 ≤ lineHeight ≤ 2.0 (D28)
- a document with neither field stays valid; legacy converter documents stay valid (D22, Backward compatibility)

**Tests:**

```ts
it('accepts the three verse-number modes and an inset in range', () => {
  for (const mode of ['gutter', 'hidden', 'inline'])
    expect(parseActivityDocument('bible', withScripture({ verseNumbers: mode, inset: 32 })).ok).toBe(true)
})
it('rejects an unknown mode, an inset out of range and a line height out of range', () => {
  expect(parseActivityDocument('bible', withScripture({ verseNumbers: 'margin' })).ok).toBe(false)
  expect(parseActivityDocument('bible', withScripture({ inset: 8 })).ok).toBe(false)
  expect(parseActivityDocument('bible', withScripture({ inset: 80 })).ok).toBe(false)
  expect(parseActivityDocument('bible', withScripture({ lineHeight: 2.5 })).ok).toBe(false)
})
it('keeps a scripture object without the new fields valid', () => {
  expect(parseActivityDocument('bible', withScripture({})).ok).toBe(true)
})
```

(`parseActivityDocument` and `withScripture` stand for the file's parse entry and the test file's existing D22 fixture builder — use the real names.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the server vitest file, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): scripture verse-number mode and inset (SC6)`

### Task 17: Scripture document without split — defaults and page height
App: iphone
Phase: 7
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/State/Models/ActivityDocument.swift` — `TextObject.verseNumbers`, `inset` accessors (encode/decode)
- Modify: `iphone/MakeReady/UI2/Containers/Bible/BibleScripture.swift` — remove `split`/`fits`; defaults; `pageHeight`
- Modify: `iphone/MakeReady/UI2/Containers/Bible/BibleSave.swift` — plans for exactly one activity (no extra POSTs)
- Modify: `iphone/MakeReadyCaptureTests/BibleScriptureTests.swift`, `BibleSaveTests.swift` — drop the split tests (D14 superseded)

**Interfaces:**
- Consumes: `BiblePick`, `TextObject` (Tasks 5, 12).
- Produces: `TextObject.verseNumbers: VerseNumbers?` (`.gutter` · `.hidden` · `.inline`, nil reads `.inline`), `TextObject.inset: Double?`; `BibleScripture.pageHeight(scriptureHeight: CGFloat, citationHeight: CGFloat) -> CGFloat`; `BibleSave.plan(new: BiblePick, version:existing:after:)`, `BibleSave.plan(change: String, pick: BiblePick, version:)`.

**Behaviour:**
- `document(for:)` writes `verseNumbers` = `.hidden` for a one-verse pick, `.gutter` for two or more; `inset` 32; `lineHeight` 1.4; size 18; serif 400 (D27, D28)
- a pick is one activity: no split, no length cap; a new pick POSTs one activity then `PATCH …/order` to the slot; a change PUTs the original only (D29, D15)
- `pageHeight` = max(956, 96 + scripture + 16 + citation + 96) (D29)
- a document without `verseNumbers` decodes to `.inline`; encoding never writes the field when it was absent (D27, Backward compatibility)

**Tests:**

```swift
func testDefaultsHideNumbersForOneVerseAndGutterForSeveral() {
    XCTAssertEqual(BibleScripture.document(for: Self.pick16, background: nil).textObjects[0].verseNumbers, .hidden)
    XCTAssertEqual(BibleScripture.document(for: Self.pick16b18, background: nil).textObjects[0].verseNumbers, .gutter)
    XCTAssertEqual(BibleScripture.document(for: Self.pick16b18, background: nil).textObjects[0].inset, 32)
}
func testPageHeightNeverDropsBelowTheTextPage() {
    XCTAssertEqual(BibleScripture.pageHeight(scriptureHeight: 200, citationHeight: 20), 956)
    XCTAssertEqual(BibleScripture.pageHeight(scriptureHeight: 1400, citationHeight: 20), 1628)
}
func testALegacyScriptureReadsInline() throws {
    XCTAssertEqual(try Self.decode(Self.legacyScriptureJSON).verseNumbers, .inline)
}
func testAWholeChapterIsOneActivity() async {
    _ = await BibleSave.run(BibleSave.plan(new: Self.john3All, version: "v", existing: ["a", "b"], after: "a"), actions: stub.actions, from: 0)
    XCTAssertEqual(stub.log, ["POST", "PATCH a,p1,b"])
}
```

- [ ] **Step 1: Write the listed tests; delete the split tests**
- [ ] **Step 2: Run the iphone-xctest suite for `BibleScriptureTests` and `BibleSaveTests`, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them and `ActivityDocumentTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): one activity per passage, verse-number defaults, page height`

### Task 18: d2m — verse-number modes, the scrolling Bible page, the style panel, the player's in-page scroll
App: iphone
Phase: 8
Recipe: d2m handover (`request_project_change`, then `wait_project_change`)

**Files:**
- Modify (by d2m): `iphone/MakeReadyUI/CanvasTextObject.swift` (C-092), `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift`, `iphone/MakeReadyUI/Screens/Activities/ActivitiesPlayerScreen.swift`, fixtures and `ViewRegistry.swift` as d2m writes them
- Reference: this SPEC (D26–D30), committed on `builder/bible-verse-picker`

**Interfaces:**
- Produces (named by d2m; record the real names in the workspace `d2m-api.md`): C-092 `verseNumbers` input (`gutter` · `hidden` · `inline`, default `inline`) and a `pageLaidOut` flag that hides transform handles; ActivitiesEditorScreen `State.pageHeight` (vertical scroll when > 956, tool bar fixed), the D28 Bible style panel inputs (face, weight, size, line height, inset, verse numbers) with their change callbacks, Animation/effects hidden for `bible`; ActivitiesPlayerScreen in-page vertical scroll for a page taller than the screen with D30's edge hand-off to the pager.

**Behaviour:**
- `gutter`: one line-start per verse, number right-aligned in a column left of the text, text wraps in its own column; `hidden`: run-on paragraph, no numbers; `inline`: today's superscript drawing (D27)
- page-laid-out objects show no move/scale/rotate handles and ignore drag/pinch/rotate (D26)
- the editor page scrolls vertically when taller than 956; background fills the full height (D29)
- the style panel offers exactly D28's controls and ranges; Color/Background unchanged (D28)
- the player scrolls a tall page first and pages at its top/bottom edge (D30)

**Tests:**

```text
d2m captures, per subject, one state each: C-092 gutter · hidden · inline (John 3:16-18);
ActivitiesEditorScreen bible-tall (John 3:1-36, scrolled to the citation) and bible-style-panel;
ActivitiesPlayerScreen bible-tall-mid-scroll. Each render is read before the task is ticked.
```

- [ ] **Step 1: `check_project_change` per subject; `request_project_change` with D26–D30 and this SPEC as the reference**
- [ ] **Step 2: `wait_project_change` until done; settle any handback from the SPEC**
- [ ] **Step 3: Read every listed render**
- [ ] **Step 4: Record the produced names in `d2m-api.md`**
- [ ] **Step 5: Commit** — d2m's commits land on the branch; commit `d2m-api.md` only if tracked

### Task 19: The editor, player and thumbnails run page-laid-out scripture
App: iphone
Phase: 9
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift` — `pageLaidOut`, `verseNumbers`, `pageHeight`, the style panel state for `bible`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — style panel callbacks write the scripture (and the citation's face/colour/alignment/inset); transform callbacks ignored for page-laid-out objects
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift` — layout from D26, `verseNumbers`, page height
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift` — D26 layout, top 440×956
- Test: `iphone/MakeReadyCaptureTests/BibleEditorTests.swift`, `ActivityViewerMapperTests.swift`, `ActivityThumbnailTests.swift`

**Interfaces:**
- Consumes: Task 18's names (`d2m-api.md`); `BibleScripture.pageHeight`, `TextObject.verseNumbers/inset` (Task 17).

**Behaviour:**
- `bible` scripture/citation map with `pageLaidOut` true; their stored `transform` is never changed by the editor (D26)
- the style panel edits face, weight, size 14–40, line height 1.0–2.0, inset 16–64, verse numbers; the citation follows face, colour, alignment and inset (D28)
- the toolbar for `bible` has no Animation/effects (D28); the menu and highlighting stand (D31)
- player and thumbnail place scripture and citation per D26 and size the page per D29; the thumbnail crops to the top 956 (D30)

**Tests:**

```swift
func testPageLaidOutObjectsIgnoreTransforms() async {
    let before = model.document.textObjects[0].transform
    await model.moveObject(0, by: CGSize(width: 40, height: 40))
    XCTAssertEqual(model.document.textObjects[0].transform, before)
}
func testTheStylePanelWritesScriptureAndCitationTogether() async {
    await model.setBibleStyle(.inset(48)); await model.setBibleStyle(.face(.sans))
    XCTAssertEqual(model.document.textObjects[0].inset, 48); XCTAssertEqual(model.document.textObjects[1].inset, 48)
    XCTAssertEqual(model.document.textObjects[1].font, "sans")
}
func testBibleHidesAnimation() {
    XCTAssertFalse(ActivitiesEditorMapper.state(Self.bibleDoc).showsEffectsTool)
}
func testAWholeChapterPageIsTallerThanTheScreen() {
    XCTAssertGreaterThan(ActivityViewerMapper.page(for: Self.john3AllDoc).height, 956)
}
```

(`model.moveObject`, `setBibleStyle`, `ActivitiesEditorMapper.state` and `ActivityViewerMapper.page(for:)` stand for the real entry points — use their names from the files and `d2m-api.md`.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for the three classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them and `ActivitiesEditorContainerTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): page-laid-out scripture in the editor, player and thumbnails`

### Task 20: SC7 — vertical alignment on scripture objects
App: server
Phase: 10
Recipe: test-driven-development · tiny

**Files:**
- Modify: `server/src/services/activity-document.ts` — the scripture field beside SC6's
- Test: `server/src/services/__tests__/activity-document.test.ts`

**Interfaces:**
- §Contract rows `POST /api/lesson-versions/:id/activities` and `PUT /api/content-activities/:id` (EDIT: SC7).

**Behaviour:**
- a `role: scripture` object in a `bible` document may carry `verticalAlignment` ∈ {`top`, `center`, `bottom`}; any other value → 400 VALIDATION (SC7, D32)
- absent stays valid (Backward compatibility)

**Tests:**

```ts
it('accepts the three vertical alignments', () => {
  for (const v of ['top', 'center', 'bottom'])
    expect(parseActivityDocument('bible', withScripture({ verticalAlignment: v })).ok).toBe(true)
})
it('rejects an unknown vertical alignment', () => {
  expect(parseActivityDocument('bible', withScripture({ verticalAlignment: 'middle' })).ok).toBe(false)
})
```

(Real names as in Task 16.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the server vitest file, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run it, watch it pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): scripture vertical alignment (SC7)`

### Task 21: d2m — Figma glyphs and the reorganised Bible tool bar
App: iphone
Phase: 11
Recipe: d2m handover (`request_project_change`, then `wait_project_change`)

**Files:**
- Modify (by d2m): the glyph library (`Glyph`/asset catalog as d2m writes it), `iphone/MakeReadyUI/Screens/Activities/ActivitiesEditorScreen.swift`, `iphone/MakeReadyUI/CanvasTextObject.swift` (C-092) if vertical placement lives there, fixtures and `ViewRegistry.swift`
- Reference: this SPEC (D32, D33) and Figma `https://www.figma.com/design/nVva9a2WvYmcWQo6zlHupO/Make-Ready-Mobile?node-id=4800-11364`

**Interfaces:**
- Produces (named by d2m; record them in the workspace `d2m-api.md`): glyphs for vertical align top · center · bottom, the new Font tool glyph, `text--scale`, `pan--vertical`, `pan--horizontal`; ActivitiesEditorScreen `bible` tool bar in D33's order; the Align panel's three rows with change callbacks for vertical alignment and verse numbers; Size, Line height and Padding as separate tool bar buttons, each opening a slider; the Font panel reduced to face + weight; a `verticalAlignment` input for the page-laid-out block.

**Behaviour:**
- exactly D33's tool bar, panels, ranges and glyphs; `text` activities unchanged (D33)
- top / center / bottom place the block within the 96 pt insets on a 956 page; a taller page is unaffected (D32)

**Tests:**

```text
d2m captures: ActivitiesEditorScreen bible-toolbar, bible-align-panel, bible-font-panel, bible-size-slider,
and bible-vertical-center (John 3:16). Each render is read before the task is ticked.
```

- [ ] **Step 1: `check_project_change` per subject; `request_project_change` with D32–D33, this SPEC and the Figma node as references (glyph import first)**
- [ ] **Step 2: `wait_project_change` until done; settle any handback from the SPEC**
- [ ] **Step 3: Read every listed render**
- [ ] **Step 4: Record the produced names in `d2m-api.md`**
- [ ] **Step 5: Commit** — d2m's commits land on the branch

### Task 22: The containers wire vertical alignment and the new tool bar
App: iphone
Phase: 12
Recipe: /ios-error-surface

**Files:**
- Modify: `iphone/MakeReady/State/Models/ActivityDocument.swift` — `TextObject.verticalAlignment`
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift`, `ActivitiesEditorContainer.swift` — the D33 tool bar state and callbacks
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift`, `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift` — D32 placement
- Test: `iphone/MakeReadyCaptureTests/BibleEditorTests.swift`, `ActivityViewerMapperTests.swift`

**Interfaces:**
- Consumes: Task 21's names (`d2m-api.md`); `BibleScripture.pageHeight` (Task 17).
- Produces: `TextObject.verticalAlignment: VerticalAlignment?` (nil reads `.top`).

**Behaviour:**
- the Align panel writes horizontal alignment (scripture and citation), `verticalAlignment` and `verseNumbers`; Size, Line height and Padding write `size`, `lineHeight`, `inset` (citation follows padding) (D33)
- editor, player and thumbnail place the block per D32 on a 956 page; a taller page draws as top (D32)
- a document without `verticalAlignment` decodes `.top` and never gains the field on save unless changed

**Tests:**

```swift
func testTheAlignPanelWritesVerticalAlignmentAndVerseNumbers() async {
    await model.setBibleStyle(.vertical(.center)); await model.setBibleStyle(.verseNumbers(.inline))
    XCTAssertEqual(model.document.textObjects[0].verticalAlignment, .center)
    XCTAssertEqual(model.document.textObjects[0].verseNumbers, .inline)
}
func testCenterMovesAShortPassageButNotATallOne() {
    XCTAssertGreaterThan(ActivityViewerMapper.page(for: Self.john316Centered).scriptureTop, 96)
    XCTAssertEqual(ActivityViewerMapper.page(for: Self.john3AllCentered).scriptureTop, 96)
}
func testALegacyScriptureReadsTop() throws {
    XCTAssertEqual(try Self.decode(Self.legacyScriptureJSON).verticalAlignment ?? .top, .top)
}
```

(Real entry-point names from the files and `d2m-api.md`.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run the iphone-xctest suite for both classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them and `ActivitiesEditorContainerTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): vertical alignment and the reorganised Bible tool bar`

### Task 23: The reference becomes ordinary text above the passage
App: iphone
Phase: 13
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Bible/BibleScripture.swift` — citation text without translation; placement above; `pageHeight` without the citation; change-passage citation rule
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift`, `ActivitiesEditorContainer.swift` — the citation is unlocked, not page-laid-out, keeps its transform, edits/moves/deletes as text; the D12 menu and style-panel follow-through apply to the scripture only
- Modify: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift`, `iphone/MakeReady/UI2/Containers/Programs/ActivityThumbnail.swift` — draw the citation from its own transform
- Test: `iphone/MakeReadyCaptureTests/BibleScriptureTests.swift`, `BibleEditorTests.swift`, `ActivityViewerMapperTests.swift`

**Interfaces:**
- Consumes: `BibleScripture.title(for:bookName:)` (Task 12); Task 18/21 names in `d2m-api.md`.
- Produces: `BibleScripture.pageHeight(scriptureHeight:) -> CGFloat`; `BibleScripture.citationAfterChange(current: String, old: BiblePick, new: BiblePick) -> String`.

**Behaviour:**
- a new pick's citation text = the reference without translation ("John 3:16b-18"); placed at top 40, left = inset, width 440 − 2·inset, scripture face 14 pt, scripture colour and horizontal alignment (D34)
- the citation is an ordinary text object: typing, moving, scaling, rotating, restyling and deleting (no confirmation) work as on a `text` activity; tapping it never opens the D12 menu (D34)
- the scripture's style changes no longer write the citation (D34)
- page height = max(956, 96 + scripture + 96) (D34, D29)
- Change passage: citation text becomes the new reference only when it equals the old reference; otherwise unchanged (D34)
- player and thumbnail draw the citation at its own transform (D34)

**Tests:**

```swift
func testTheReferenceHasNoTranslationAndSitsAbove() {
    let c = BibleScripture.document(for: Self.pick16b18, background: nil).textObjects[1]
    XCTAssertEqual(c.text, "John 3:16b-18"); XCTAssertEqual(c.transform.y, 40, accuracy: 0.5)
}
func testTheReferenceIsOrdinaryText() async {
    XCTAssertFalse(ActivitiesEditorMapper.state(Self.bibleDoc).objects[1].isLocked)
    await model.tapObject(1)
    XCTAssertNil(presenter.lastMenu); XCTAssertEqual(model.editingIndex, 1)
}
func testScriptureStyleNoLongerWritesTheReference() async {
    await model.setBibleStyle(.inset(48))
    XCTAssertNotEqual(model.document.textObjects[1].inset, 48)
}
func testChangePassageKeepsAnEditedReference() {
    XCTAssertEqual(BibleScripture.citationAfterChange(current: "John 3:16b-18", old: Self.pick16b18, new: Self.pick16to21), "John 3:16b-21")
    XCTAssertEqual(BibleScripture.citationAfterChange(current: "For God so loved", old: Self.pick16b18, new: Self.pick16to21), "For God so loved")
}
func testPageHeightIgnoresTheReference() {
    XCTAssertEqual(BibleScripture.pageHeight(scriptureHeight: 1400), 1592)
}
```

(Real entry-point names from the files and `d2m-api.md`.)

- [ ] **Step 1: Write the listed tests; update tests that assumed the old citation**
- [ ] **Step 2: Run the iphone-xctest suite for the three classes, watch them fail**
- [ ] **Step 3: Implement to the Behaviour**
- [ ] **Step 4: Run them and `ActivitiesEditorContainerTests`, `BibleSaveTests`, watch them pass**
- [ ] **Step 5: Commit** — `feat(bible-verse-picker): the reference is ordinary text above the passage`

