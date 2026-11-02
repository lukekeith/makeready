# Tag categories — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Books-of-the-Bible tags show as their own section, in canonical book order, in a redesigned (Figma 4770:11375) Tags filter overlay on iPhone Media.

**Architecture:** The server stores MakeReady-defined tag categories (`tag_categories` + `tag_category_tags`, seeded by the migration) and serves them at `GET /api/tags/categories`. The iPhone caches them in `AppState.tagCategories`; `MediaHomeMapper` turns the photos' tags into titled sections ordered, labelled and de-duplicated by those categories; d2m builds the sectioned chip-flow overlay form the container presents.

**Tech Stack:** server — Express + Prisma + Atlas (YAML schema), vitest + supertest · iphone — SwiftUI, `@Observable` AppState + Actions, XCTest, d2m-built `MakeReadyUI` views.

**Spec:** `docs/features/tag-categories/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(tag-categories): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | The two tables exist with Books of the Bible seeded, and `GET /api/tags/categories` returns them (contract frozen) | `cd server && npx tsc --noEmit` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | iphone | 3–4 | The app loads and caches the categories, and Media's mapper builds ordered, labelled tag sections | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 3 | iphone | 5 | Media's Tags chip opens the d2m-built sectioned chip-flow overlay | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Tag-category tables and the Books of the Bible seed
App: server
Phase: 1
Recipe: `/api` (schema part) · server/.claude/CLAUDE.md §Database Management

**Files:**
- Modify: `server/schema/schema.yaml` (two models after `MediaTag`, ~line 1106)
- Generated: `server/prisma/schema.prisma`, `server/atlas/.schema.hcl`, `server/atlas/migrations/<ts>_tag_categories.sql`, `server/atlas/migrations/atlas.sum`
- Test: `server/test/tag-categories-migration.test.ts`

**Interfaces:**
- Produces: Prisma models `TagCategory { id, key, name, position, createdAt, tags TagCategoryTag[] }` and `TagCategoryTag { id, categoryId, tag, label, position, createdAt, category }`; tables `tag_categories`, `tag_category_tags`; one category `bible-books` with 69 member rows.

- [ ] **Step 1: Write the failing test** — `server/test/tag-categories-migration.test.ts`, copying `test/media-taken-at-migration.test.ts`'s file lookup:

```ts
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const CREATE = 'CREATE TABLE "tag_category_tags"'

function findMigration() {
  const hits = readdirSync(MIGRATIONS).filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes(CREATE))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

// One INSERT row per member: ('<uuid expr>', '<categoryId>', '<tag>', '<label>', <position>)
function members(sql: string) {
  return [...sql.matchAll(/INSERT INTO "tag_category_tags"[^;]*?VALUES\s*\(.*?'([a-z0-9]+)',\s*'([^']+)',\s*(\d+)\)/g)]
    .map((m) => ({ tag: m[1], label: m[2], position: Number(m[3]) }))
}

describe('tag-categories migration (D4, D11)', () => {
  it('seeds Books of the Bible: 69 spellings over 66 positions, no abbreviations', () => {
    const { file, sql } = findMigration()
    expect(sql).toContain(`'bible-books', 'Books of the Bible', 1`)
    const rows = members(sql)
    expect(rows).toHaveLength(69)
    expect(new Set(rows.map((r) => r.position)).size).toBe(66)
    expect(rows.find((r) => r.tag === 'genesis')).toEqual({ tag: 'genesis', label: 'Genesis', position: 1 })
    expect(rows.find((r) => r.tag === '1samuel')).toEqual({ tag: '1samuel', label: '1 Samuel', position: 9 })
    expect(rows.find((r) => r.tag === 'psalm')?.position).toBe(19)
    expect(rows.find((r) => r.tag === 'songofsongs')?.label).toBe('Song of Solomon')
    expect(rows.find((r) => r.tag === 'revelations')?.position).toBe(66)
    for (const abbrev of ['gen', 'ex', 'ne', 'ss', 'jn', 'ps']) expect(rows.find((r) => r.tag === abbrev)).toBeUndefined()
    expect(sql).toContain('ON CONFLICT DO NOTHING')
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(file)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/tag-categories-migration.test.ts` → FAIL (no migration with `tag_category_tags`).

- [ ] **Step 3: Add the models** to `server/schema/schema.yaml` after `MediaTag`, in its syntax:

```yaml
  TagCategory:
    table_name: tag_categories
    description: "tag-categories D1/D3: a MakeReady-defined tag category (seeded, no editor)"
    fields:
      id: { type: uuid, primary: true, default: uuid() }
      key: { type: string, unique: true, description: "Stable key, e.g. bible-books" }
      name: { type: string, description: "Section header, e.g. Books of the Bible" }
      position: { type: int, description: "Section order (ascending)" }
      createdAt: { type: datetime, default: now() }
  TagCategoryTag:
    table_name: tag_category_tags
    description: "tag-categories D10/D12: one spelling of a category member; tag is normalized (lowercase, no whitespace)"
    fields:
      id: { type: uuid, primary: true, default: uuid() }
      categoryId: { type: uuid }
      tag: { type: string, unique: true, description: "normalize(tag): lowercase, whitespace removed" }
      label: { type: string, description: "Display label, e.g. 1 Samuel" }
      position: { type: int, description: "Order inside the category; spellings of one member share it" }
      createdAt: { type: datetime, default: now() }
    relations:
      category:
        type: many_to_one
        target: TagCategory
        fields: [categoryId]
        references: [id]
        onDelete: Cascade
    indexes:
      - fields: [categoryId, position]
```

(Use the block style the file already uses if it doesn't accept flow maps. Add the inverse `tags` relation on `TagCategory` the way other one-to-many pairs in the file declare it, if the generator requires it.)

- [ ] **Step 4: Generate without touching the 1Password env** — `cd server && npm run schema:validate && npm run schema:generate`, then `cd server/atlas && ../scripts/atlas.sh migrate diff tag_categories --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`. Review the new SQL: two CREATE TABLEs, the unique and FK.

- [ ] **Step 5: Append the seed** to that new migration (before it is ever committed), generated from `BOOK_MAP`'s 66 full-name keys (key === name lowercased with whitespace removed) plus `psalm`→19, `songofsongs`→22, `revelations`→66:

```sql
-- tag-categories D4/D11: Books of the Bible, MakeReady-defined
INSERT INTO "tag_categories" ("id", "key", "name", "position") VALUES (gen_random_uuid(), 'bible-books', 'Books of the Bible', 1) ON CONFLICT DO NOTHING;
INSERT INTO "tag_category_tags" ("id", "categoryId", "tag", "label", "position") VALUES (gen_random_uuid(), (SELECT "id" FROM "tag_categories" WHERE "key" = 'bible-books'), 'genesis', 'Genesis', 1) ON CONFLICT DO NOTHING;
-- … one line per spelling, 69 in all
```

Then re-hash: `cd server/atlas && ../scripts/atlas.sh migrate hash`.

- [ ] **Step 6: Apply locally and regenerate Prisma** — `cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`, then `docker exec makeready-server npx prisma generate` and `docker restart makeready-server`. Check: `docker exec makeready-postgres psql -U postgres -d makeready_dev -Atc "select count(*) from tag_category_tags"` → 69. Apply the same migration to the test DB the suite uses (`makeready_test` on :5433) the way the repo's test setup expects.

- [ ] **Step 7: Run it and watch it pass** — `cd server && npx vitest run test/tag-categories-migration.test.ts` → PASS; `npx tsc --noEmit` clean.

- [ ] **Step 8: Commit** — `feat(tag-categories): tag_categories + tag_category_tags, Books of the Bible seeded`

### Task 2: GET /api/tags/categories
App: server
Phase: 1
Recipe: `/api` · `server/src/routes/makeready-media.ts` pattern

**Files:**
- Create: `server/src/services/tag-categories.ts`
- Create: `server/src/routes/tags.ts`
- Modify: `server/src/index.ts` (import near :28, mount `app.use('/api/tags', tagsRoutes)` ahead of the bare `/api` routers ~:447)
- Test: `server/src/services/__tests__/tag-categories.test.ts` (mocked prisma) · `server/test/tags-categories.route.test.ts` (supertest)

**Interfaces:**
- Consumes: Task 1's Prisma models.
- Produces: `normalizeTag(s: string): string` and `listTagCategories(): Promise<TagCategoryDTO[]>` where `TagCategoryDTO = { key: string; name: string; position: number; tags: { tag: string; label: string; position: number }[] }`; route `GET /api/tags/categories` → `200 { success: true, categories: TagCategoryDTO[] }` · `401` · `500 { success: false, error }`.

- [ ] **Step 1: Write the failing tests**

```ts
// server/src/services/__tests__/tag-categories.test.ts
import { describe, expect, it, vi } from 'vitest'
vi.mock('../../lib/prisma.js', () => ({ prisma: { tagCategory: { findMany: vi.fn(async () => [
  { key: 'bible-books', name: 'Books of the Bible', position: 1, tags: [
    { tag: 'genesis', label: 'Genesis', position: 1 }, { tag: 'psalm', label: 'Psalms', position: 19 } ] } ]) } } }))
import { listTagCategories, normalizeTag } from '../tag-categories.js'

describe('tag-categories service', () => {
  it('normalizes like the Bible parser (D10)', () => {
    expect(normalizeTag('1 Samuel')).toBe('1samuel')
    expect(normalizeTag('  PSALMS ')).toBe('psalms')
    expect(normalizeTag('song of songs')).toBe('songofsongs')
  })
  it('returns categories and members in the contract shape', async () => {
    const cats = await listTagCategories()
    expect(cats).toEqual([{ key: 'bible-books', name: 'Books of the Bible', position: 1,
      tags: [{ tag: 'genesis', label: 'Genesis', position: 1 }, { tag: 'psalm', label: 'Psalms', position: 19 }] }])
  })
})
```

```ts
// server/test/tags-categories.route.test.ts — copy media-makeready-access.test.ts's setup
it('401 without a session', async () => { await request(app).get('/api/tags/categories').set('User-Agent', 'Mozilla/5.0').expect(401) })
it('returns Books of the Bible in book order', async () => {
  const res = await request(app).get('/api/tags/categories').set(bearer(apiKey)).expect(200)
  expect(res.body.success).toBe(true)
  const bible = res.body.categories.find((c: any) => c.key === 'bible-books')
  expect(bible.tags).toHaveLength(69)
  expect(bible.tags[0]).toEqual({ tag: 'genesis', label: 'Genesis', position: 1 })
  expect(bible.tags.at(-1).position).toBe(66)
})
```

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/tag-categories.test.ts test/tags-categories.route.test.ts` → FAIL (module not found / 404).

- [ ] **Step 3: Implement**

```ts
// server/src/services/tag-categories.ts
import { prisma } from '../lib/prisma.js'

export type TagCategoryDTO = { key: string; name: string; position: number; tags: { tag: string; label: string; position: number }[] }

/** tag-categories D10: the Bible parser's own rule — lowercase, all whitespace removed. */
export function normalizeTag(s: string): string {
  return s.toLowerCase().replace(/\s+/g, '')
}

/** tag-categories D15: MakeReady-defined, global, read-only. */
export async function listTagCategories(): Promise<TagCategoryDTO[]> {
  const rows = await prisma.tagCategory.findMany({
    orderBy: { position: 'asc' },
    select: { key: true, name: true, position: true,
      tags: { select: { tag: true, label: true, position: true }, orderBy: [{ position: 'asc' }, { tag: 'asc' }] } },
  })
  return rows.map((c) => ({ key: c.key, name: c.name, position: c.position, tags: c.tags }))
}
```

```ts
// server/src/routes/tags.ts
import { Router } from 'express'
import { requireAuth } from '../middleware/auth.js'
import { listTagCategories } from '../services/tag-categories.js'

const router = Router()

/**
 * @openapi
 * /api/tags/categories:
 *   get:
 *     tags: [Tags]
 *     summary: MakeReady-defined tag categories (tag-categories D3/D15)
 *     description: Global and read-only. Each category lists its member spellings (normalized) with label and position.
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: "{ success, categories: [{ key, name, position, tags: [{ tag, label, position }] }] }"
 */
router.get('/categories', requireAuth, async (_req, res) => {
  try {
    res.json({ success: true, categories: await listTagCategories() })
  } catch (error) {
    console.error('Error listing tag categories:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})

export default router
```

Mount in `src/index.ts`: `import tagsRoutes from './routes/tags.js'` and `app.use('/api/tags', tagsRoutes)` before the bare `app.use('/api', …)` routers. Then `docker restart makeready-server`.

- [ ] **Step 4: Run them and watch them pass** — the two files above → PASS; `npx tsc --noEmit` clean; `npm run test:run` green. Smoke: `curl -s -A 'Mozilla/5.0' localhost:3010/api/tags/categories` → 401.

- [ ] **Step 5: Freeze the contract** — this is the producer phase's last task: after the phase gates pass, `advance.mjs docs/features/tag-categories --set "contract=frozen <YYYY-MM-DD>"` (the build loop records it at phase close).

- [ ] **Step 6: Commit** — `feat(tag-categories): GET /api/tags/categories`

### Task 3: Tag categories in AppState, loaded by MediaActions
App: iphone
Phase: 2
Recipe: `/ios-error-surface` · iphone/.claude/CLAUDE.md §State Management

**Files:**
- Modify: `iphone/MakeReady/State/Models/MediaModels.swift:289-301` (add models)
- Modify: `iphone/MakeReady/State/AppState.swift:467` (property) and `:1007` (`clearInMemory`)
- Modify: `iphone/MakeReady/State/Actions/MediaActions.swift` (add `loadTagCategories()` beside `loadSources()` :252-268)
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:193` (call it after `loadSources()`)
- Test: `iphone/MakeReadyCaptureTests/TagCategoriesTests.swift` (register with the test target as the repo's other test files are)

**Interfaces:**
- Consumes: §Contract `GET /api/tags/categories`.
- Produces: `struct TagCategory: Codable, Hashable { let key: String; let name: String; let position: Int; let tags: [TagCategoryMember] }` · `struct TagCategoryMember: Codable, Hashable { let tag: String; let label: String; let position: Int }` · `AppState.tagCategories: [TagCategory]` · `MediaActions.loadTagCategories() async` (non-throwing).

- [ ] **Step 1: Write the failing test** — decode the contract shape, and the action writes state (copy `MediaLoadAllPhotosTests.swift:143`'s `MediaActions(api:state:)` stub pattern):

```swift
func testDecodesTheContractShape() throws {
    let json = #"{"success":true,"categories":[{"key":"bible-books","name":"Books of the Bible","position":1,"tags":[{"tag":"genesis","label":"Genesis","position":1}]}]}"#
    let r = try JSONDecoder().decode(TagCategoriesResponse.self, from: Data(json.utf8))
    XCTAssertEqual(r.categories?.first?.tags.first, TagCategoryMember(tag: "genesis", label: "Genesis", position: 1))
}
func testLoadTagCategoriesWritesStateAndClearInMemoryEmptiesIt() async { /* stub api → categories; await loadTagCategories(); assert state.tagCategories.count == 1; state.clearInMemory(); assert empty */ }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → compile FAIL (`TagCategoriesResponse` undefined).

- [ ] **Step 3: Implement**

```swift
// MediaModels.swift — tag-categories §Contract
struct TagCategoryMember: Codable, Hashable { let tag: String; let label: String; let position: Int }
struct TagCategory: Codable, Hashable { let key: String; let name: String; let position: Int; let tags: [TagCategoryMember] }
struct TagCategoriesResponse: Codable { let success: Bool; let categories: [TagCategory]?; let error: String? }

// AppState.swift, beside allMediaTags — MakeReady-defined tag categories (tag-categories D14)
var tagCategories: [TagCategory] = []
// clearInMemory(): tagCategories = []

// MediaActions.swift
/// tag-categories D14: the MakeReady-defined tag categories into `AppState.tagCategories`. Console-only on
/// failure — the Tags overlay falls back to one A→Z flow (D7).
@MainActor
func loadTagCategories() async {
    do {
        let response: TagCategoriesResponse = try await api.get("/api/tags/categories", responseType: TagCategoriesResponse.self)
        guard response.success, let categories = response.categories else {
            throw APIError.serverError(response.error ?? "Failed to load tag categories")
        }
        state.tagCategories = categories
    } catch {
        if Task.isCancelled || UI2ImageLoader.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) { await onUnauthorized(); return }
        state.recordError(error, context: "MediaActions.loadTagCategories", surface: false)
    }
}
// MediaHomeContainer.swift .task, after `await actions.loadSources()`: `await actions.loadTagCategories()`
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → TEST SUCCEEDED; `cd iphone && swiftlint --baseline .swiftlint-baseline.json --quiet <changed files>` clean.

- [ ] **Step 5: Commit** — `feat(tag-categories): tag categories cached in AppState`

### Task 4: Media's tag sections — order, labels, one chip per book
App: iphone
Phase: 2
Recipe: `builder:test-driven-development` · SPEC D7, D8, D10, D12, D13, D16

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeMapper.swift` (:39-42 Option, :59 Output, :69 options, :78-81 filter, :101 init; new `TagSection`, `normalizeTag`, `tagLabel`)
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:76` (pass `categories: app.tagCategories`), `:104` (`selectedTags` = display labels in option order), `:311` (until Task 5, flatten `tagSections` into the list overlay's options)
- Test: `iphone/MakeReadyCaptureTests/MediaHomeMapperTests.swift` (rewrite `testTagsAnyOfAndOptionsFromTheLoadedListSorted` :80-85's options half; add the cases below) · `MediaHomeContainerTests.swift:13` (`tagOptions: []` → `tagSections: []`)

**Interfaces:**
- Consumes: Task 3's `TagCategory` / `TagCategoryMember`, `AppState.tagCategories`.
- Produces: `MediaHomeMapper.TagSection: Equatable { let title: String?; let options: [Option] }` · `Output.tagSections: [TagSection]` (replaces `tagOptions`) · `MediaHomeMapper.output(items:selection:today:timeZone:categories: [TagCategory] = [])` · `static func normalizeTag(_:) -> String` · `static func tagLabels(for ids: Set<String>, in sections: [TagSection]) -> [String]` (option order, unknown ids skipped). Option ids: uncategorized = lowercased tag; book = `cat:<key>:<position>` (D12/D16).

- [ ] **Step 1: Write the failing tests** (in `MediaHomeMapperTests`, using its `item(tags:)` helper and a `bible` fixture of `TagCategory(key: "bible-books", name: "Books of the Bible", position: 1, tags: [genesis 1, exodus 2, 1samuel 9, psalms 19, psalm 19])`):

```swift
func testBooksFirstInBookOrderThenContentAToZ() {
    let out = MediaHomeMapper.output(items: [item(tags: ["dogs", "exodus", "1 samuel", "animals", "genesis"])],
                                     selection: .init(), today: today, timeZone: utc, categories: [bible])
    XCTAssertEqual(out.tagSections.map(\.title), ["BOOKS OF THE BIBLE", "CONTENT"])
    XCTAssertEqual(out.tagSections[0].options.map(\.label), ["Genesis", "Exodus", "1 Samuel"])
    XCTAssertEqual(out.tagSections[1].options.map(\.label), ["Animals", "Dogs"])
}
func testOnlyUncategorizedIsOneUntitledSection() { /* tags ["youth","family"] → [TagSection(title: nil, options: Family, Youth)] */ }
func testOnlyBooksHasNoContentSection() { /* ["genesis"] → one titled section */ }
func testPsalmAndPsalmsAreOneOptionThatMatchesBoth() {
    // two items tagged "psalm" and "psalms" → one option id "cat:bible-books:19", label "Psalms";
    // selection.tags = ["cat:bible-books:19"] → both items shown
}
func testTitleCaseLabelsAndNoCategoriesFallsBackToOneFlow() { /* "new life" → "New Life"; categories [] with "genesis" → untitled "Genesis" (title-cased) */ }
func testTagLabelsFollowOptionOrderAndSkipUnknownIds() { /* ["dogs","cat:bible-books:1","gone"] → ["Genesis","Dogs"] */ }
func testALiteralCatColonTagIsTreatedAsText() { /* tag "cat:nope" with no matching member → uncategorized option id "cat:nope", filters as text */ }
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → compile FAIL (`tagSections` / `categories:` unknown).

- [ ] **Step 3: Implement** in `MediaHomeMapper`:

```swift
struct TagSection: Equatable { let title: String?; let options: [Option] }

/// tag-categories D10: lowercase, all whitespace removed — the server's rule.
static func normalizeTag(_ s: String) -> String { s.lowercased().filter { !$0.isWhitespace } }

/// D13: uncategorized tags read in Title Case of their lowercased text.
static func titleCase(_ tag: String) -> String {
    tag.lowercased().split(separator: " ", omittingEmptySubsequences: false)
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
}

/// D7/D8/D12/D16: the photos' tags as sections — each category with a present member (category order,
/// member position), then CONTENT A→Z; no titles at all when nothing is categorized.
static func tagSections(tags: Set<String>, categories: [TagCategory]) -> [TagSection] {
    var byKey: [String: (TagCategory, TagCategoryMember)] = [:]
    for c in categories { for m in c.tags { byKey[m.tag] = (c, m) } }
    var found: [String: [Int: TagCategoryMember]] = [:]   // category key → position → member
    var plain: [String] = []
    for tag in tags {
        if let (c, m) = byKey[normalizeTag(tag)] { found[c.key, default: [:]][m.position] = m } else { plain.append(tag) }
    }
    let content = plain.map { Option(id: $0, label: titleCase($0)) }
        .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    let titled = categories.sorted { $0.position < $1.position }.compactMap { c -> TagSection? in
        guard let members = found[c.key], !members.isEmpty else { return nil }
        let opts = members.keys.sorted().map { Option(id: "cat:\(c.key):\($0)", label: members[$0]!.label) }
        return TagSection(title: c.name.uppercased(), options: opts)
    }
    if titled.isEmpty { return content.isEmpty ? [] : [TagSection(title: nil, options: content)] }
    return titled + (content.isEmpty ? [] : [TagSection(title: "CONTENT", options: content)])
}

/// D12/D16: the normalized spellings a selected id stands for — a `cat:` id that resolves to a loaded
/// member expands to all of that member's spellings; anything else is its own (lowercased) text.
static func wantedSpellings(_ ids: Set<String>, categories: [TagCategory]) -> Set<String> {
    var out = Set<String>()
    for id in ids {
        let parts = id.split(separator: ":", maxSplits: 2).map(String.init)
        if parts.count == 3, parts[0] == "cat", let pos = Int(parts[2]),
           let c = categories.first(where: { $0.key == parts[1] }) {
            let spellings = c.tags.filter { $0.position == pos }.map(\.tag)
            if !spellings.isEmpty { out.formUnion(spellings); continue }
        }
        out.insert(normalizeTag(id))
    }
    return out
}

static func tagLabels(for ids: Set<String>, in sections: [TagSection]) -> [String] {
    sections.flatMap(\.options).filter { ids.contains($0.id) }.map(\.label)
}
```

In `output(…, categories: [TagCategory] = [])`: build `tagSections` from the photos' lowercased tags; filter with `let wanted = wantedSpellings(selection.tags, categories: categories)` and `wanted.isDisjoint(with: item.tags.map(normalizeTag))`. `Output.tagOptions` → `tagSections`. Container: pass `categories: app.tagCategories` at :76; `selectedTags: MediaHomeMapper.tagLabels(for: selection.tags, in: output.tagSections)` at :104; the `.tags` overlay's options at :311 become `output.tagSections.flatMap(\.options).map { FilterMenuOverlay.Option(id: $0.id, label: $0.label) }` until Task 5 swaps the form.

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → TEST SUCCEEDED (the existing any-of, search and chips-combine tests still pass); swiftlint clean on the changed files.

- [ ] **Step 5: Commit** — `feat(tag-categories): Media tag options grouped, ordered and labelled by category`

### Task 5: The Tags overlay becomes the sectioned chip flow
App: iphone
Phase: 3
Recipe: d2m-channel (`check_project_change` → `request_project_change` → `wait_project_change`) · `/transition-review`

**Files:**
- d2m-made (handover, never hand-edited): the C-036 chip-flow form (or the new component d2m's registry rules mint) + the two-state tag chip + a wrapping layout inside `iphone/MakeReadyUI/`, their capture cases
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:309-317` (the `.tags` case presents the new form)
- Test: `iphone/MakeReadyCaptureTests/MediaHomeContainerTests.swift` (the sections handed to the form equal `output.tagSections`)

**Interfaces:**
- Consumes: Task 4's `[MediaHomeMapper.TagSection]`.
- Produces: the Tags menu in draft mode — Clear applies empty and closes · Save applies the draft · ✕ discards — rendering sections per D6/D7.

- [ ] **Step 1: Request the design from d2m** — `check_project_change` (subject `C-036`, kinds `[composition, new-state]`) → handover → `request_project_change` with intent: a sectioned chip-flow form for multi-select tag filtering per Figma 4770:11375 — optional uppercase section headers (none when a single untitled section), options as a wrapping flow of two-state chips (unselected = plain text, selected = white pill), the existing draft-mode header (Clear · Save) and C-082 close disc; input sections `[(title: String?, options: [Option])]`; the list form unchanged for every other caller; a wrapping layout inside `MakeReadyUI` (the app's `FlowLayout` isn't reachable). Then `wait_project_change` until done; answer any `questions` with the owner first.

- [ ] **Step 2: Write the failing test** — in `MediaHomeContainerTests`, assert the Tags menu's sections are `output.tagSections` (via the static builder the container uses for the menu, extracted so it's testable): `XCTAssertEqual(MediaHomeContainer.tagMenuSections(output).map(\.title), ["BOOKS OF THE BIBLE", "CONTENT"])`.

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL.

- [ ] **Step 4: Wire it** — the `.tags` case presents d2m's form with `tagMenuSections(output)`, `selectedIDs: selection.tags`, `onClose: { openMenu = nil }`, `onSave: { ids in update { $0.tags = ids }; openMenu = nil }`. Leaders, Time, Source and Upload-to keep `FilterMenuOverlay`'s list form. Run `/transition-review` on the diff.

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → TEST SUCCEEDED; swiftlint clean. Build-time risk F4: the form's states were never rendered before — check d2m's captures of the sections, the no-header flow and a selected pill.

- [ ] **Step 6: Commit** — `feat(tag-categories): Media's Tags overlay is the sectioned chip flow` (with d2m's files as d2m reports them)
