# master-search — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** make the iPhone Search tab one ranked search across nine content types and every org the leader belongs to, with five filters and per-user recently opened results.

**Architecture:** additive server work: one new table, hand-managed search indexes, and five new routes over a raw-SQL `UNION ALL` of per-type arms sharing one score, scope and filter set; `GET /api/search` stays untouched. The iPhone app adds an `AppState` search domain, `SearchActions`, a pure mapper and a container around the d2m-built `SearchHomeScreen`, plus two pushed pages for the exits that have no detail screen.

**Tech Stack:** server: Express, zod, Prisma raw SQL, PostgreSQL full-text search, Atlas, vitest. iphone: Swift, SwiftUI, `@Observable` + Actions, XCTest.

**Spec:** `docs/features/master-search/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(master-search): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–2 | The recents table and the search indexes exist on both id types |
| 2 | server | 3–7 | C1–C5 answer as §Contract says, the screen fixture seeds them, and the contract freezes |
| 3 | iphone | 8–9 | The search domain, its Actions and the screen's `queryAnswered` input exist |
| 4 | iphone | 10–12 | The Search tab renders the wired screen, every row opens something, and R1 is repointed |

---

### Task 1: Recents table on both id types
App: server
Phase: 1
Recipe: `/api`; SPEC §Schema & API changes *Data plan*

**Files:**
- Modify: `server/schema/schema.yaml:1921` — add `SearchRecentResult` beside `SearchHistory`, and its reverse relation on `User` beside `searchHistory` (`:216`)
- Create: `server/atlas/migrations/<timestamp>_master_search_recents.sql` — the table, through the id-type block
- Create: `server/test/helpers/master-search-db.ts` — lease guard and a scratch text-id database
- Test: `server/test/master-search-migrations.test.ts`

**Interfaces:**
- Produces: `withTextIdSearchDb` — takes an async callback given a scratch database URL whose ids are text, creates the database from the lease's server, drops it afterwards, returns the callback's result. `assertSearchLease` — returns `TEST_DATABASE_URL` after `assertInvitationTestDatabase` accepts it.

**Behaviour:**
- `SearchRecentResult` maps to `search_recent_results`: `id` uuid primary, `userId` string, `resourceType` string, `resourceId` string, `openedAt` datetime default `now()`; `user` many-to-one on `userId`, `onDelete: Cascade`, not nullable; unique `[userId, resourceType, resourceId]`; index `[userId, openedAt]` (SC1)
- `resourceId` has no FK, because it spans tables (SC1)
- `userId` takes whatever type `users.id` has, through the `DO $$ … format_type` block of `20261102071026_invitations.sql:5-9` (SC1)
- `withTextIdSearchDb` follows `test/helpers/invitations-migration-db.ts:27`: only under `assertSearchLease`, creates `postgres_vt_search_<pid>_<hex>`, runs `CREATE EXTENSION IF NOT EXISTS vector`, then `npx --no-install prisma db push --skip-generate` with `DATABASE_URL` and `DIRECT_URL` set to the scratch URL, which yields text ids because `User.id` is a plain `String` (SC1, §Testing)
- Every database test here and in later tasks is `describe.skipIf(!process.env.TEST_DATABASE_URL)`, imports Prisma dynamically after `assertSearchLease`, and never targets `makeready_dev` (§Testing)

Generate with `cd server && npm run schema:generate`, then `cd atlas && ../scripts/atlas.sh migrate diff master_search_recents --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`. Never `npm run schema:diff`: it reads the 1Password pipe. Replace the generated body with this before the first commit, keeping any index name Atlas generated if it differs, then `../scripts/atlas.sh migrate hash`. A second `migrate diff` must report no changes.

```sql
-- master-search SC1: userId takes the type "users"."id" actually has (text on dev/prod, uuid on a migrations-only database).
DO $$
DECLARE id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO id_type
    FROM pg_attribute WHERE attrelid = '"users"'::regclass AND attname = 'id';
  EXECUTE format('CREATE TABLE "search_recent_results" ("id" %1$s NOT NULL DEFAULT gen_random_uuid()::%1$s, "userId" %1$s NOT NULL, "resourceType" character varying NOT NULL, "resourceId" character varying NOT NULL, "openedAt" timestamp NOT NULL DEFAULT now(), PRIMARY KEY ("id"), CONSTRAINT "fk_search_recent_results_user" FOREIGN KEY ("userId") REFERENCES "users" ("id") ON UPDATE NO ACTION ON DELETE CASCADE)', id_type);
END $$;
CREATE UNIQUE INDEX "search_recent_results_userId_resourceType_resourceId_key" ON "search_recent_results" ("userId", "resourceType", "resourceId");
CREATE INDEX "search_recent_results_userId_openedAt_idx" ON "search_recent_results" ("userId", "openedAt");
```

**Tests:**
- `the migration takes uuid on a migrations-only database` — the lease's `userId` column type equals its `users.id` type (SC1)

```ts
it('the migration takes uuid on a migrations-only database', async () => {
  const [row] = await prisma.$queryRaw<{ user: string; recent: string }[]>`
    SELECT format_type(u.atttypid, u.atttypmod) AS user, format_type(r.atttypid, r.atttypmod) AS recent
    FROM pg_attribute u, pg_attribute r
    WHERE u.attrelid = '"users"'::regclass AND u.attname = 'id'
      AND r.attrelid = '"search_recent_results"'::regclass AND r.attname = 'userId'`
  expect(row.recent).toBe(row.user)
})
```

- `the migration takes text where users.id is text` — the file runs on a scratch database with a text `users.id`, the state of a dev-dump restore (SC1)

```ts
it('the migration takes text where users.id is text', async () => {
  await withScratchUsersTable('text', async (client) => {
    await client.query(readMigration('_master_search_recents.sql'))
    const r = await client.query(`SELECT format_type(atttypid, atttypmod) t FROM pg_attribute WHERE attrelid = '"search_recent_results"'::regclass AND attname = 'userId'`)
    expect(r.rows[0].t).toBe('text')
  })
})
```

- `deleting a user cascades to their recents` — §Apps blast radius

```ts
it('deleting a user cascades to their recents', async () => {
  const user = await prisma.user.create({ data: { id: searchId(901), name: 'Gone', email: 'gone@example.invalid' } })
  await prisma.searchRecentResult.create({ data: { userId: user.id, resourceType: 'GROUP', resourceId: 'g1' } })
  await prisma.user.delete({ where: { id: user.id } })
  expect(await prisma.searchRecentResult.count({ where: { userId: user.id } })).toBe(0)
})
```

- `a second row for one resource is refused` — D10's one entry per resource

```ts
it('a second row for one resource is refused', async () => {
  const data = { userId: owner.id, resourceType: 'GROUP', resourceId: 'g1' }
  await prisma.searchRecentResult.create({ data })
  await expect(prisma.searchRecentResult.create({ data })).rejects.toMatchObject({ code: 'P2002' })
})
```

- [ ] **Step 1: Write the listed tests and the helper** — in `server/test/master-search-migrations.test.ts` and `server/test/helpers/master-search-db.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (database tests run only in its lease; `<builder>` is the directory your brief names)
- [ ] **Step 3: Add the YAML model, generate, write the migration above and re-hash**
- [ ] **Step 4: Run `cd server && npm run schema:validate && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): recents table on both id types`

### Task 2: Hand-managed search indexes
App: server
Phase: 1
Recipe: `/api`; SPEC D23, D40

**Files:**
- Create: `server/atlas/migrations/<timestamp>_master_search_indexes.sql` — through `cd server/atlas && ../scripts/atlas.sh migrate new master_search_indexes`, then `migrate hash`
- Modify: `server/schema/schema.yaml` — one comment on each of the eleven models naming the migration
- Create: `server/src/services/master-search-text.ts` — the text expressions, equal to the index expressions
- Test: `server/test/master-search-indexes.test.ts`

**Interfaces:**
- Consumes: `assertSearchLease` and `withTextIdSearchDb` from `server/test/helpers/master-search-db.ts`
- Produces: `SEARCH_TEXT` — a constant object keyed `group`, `program`, `template`, `lesson`, `activity`, `readBlock`, `event`, `post`, `member`, `media`, `mediaTag`, each value the SQL `to_tsvector` expression its GIN index uses, written over the unqualified column names; `SEARCH_TITLE` — the same keys less `activity`, `readBlock` and `mediaTag`, each the `lower(…)` title expression. A `qualifySearchExpr` function takes an expression and a table alias and returns it with every quoted column prefixed.

**Behaviour:**
- Each expression in `SEARCH_TEXT` is character-for-character the migration's GIN expression, and an arm uses the constant so the planner can use the index (D40)
- Member names and contact fields use `simple`; everything else uses `english` (D16)
- The migration uses plain idempotent `CREATE INDEX IF NOT EXISTS`, the form of `20260614223043.sql:28`, inside Atlas's per-file transaction. F15 is settled this way: an agent has no prod row counts, these are per-church tables, and a failed `CONCURRENTLY` leaves an invalid index that the next `IF NOT EXISTS` skips. Name F15 in the report so the owner can object before deploying.
- `drop_index` skip at `atlas/atlas.hcl:33` keeps these from `migrate diff`, so a second diff stays empty; no generator is changed (D40)
- Run `EXPLAIN` under `plan_cache_mode = force_generic_plan` to settle F14. Should a parameterized prefix `LIKE` skip `text_pattern_ops`, use a range comparison on the lower-case title in the arm instead, proved by the same test. Settle how `simple` tokenizes `+15551234567` and `a.b@c.org` there too; D35's rules do not depend on it, so a surprise is only a note in the report (F14)

```sql
-- master-search D23/D40: hand-managed search indexes. Atlas's drop_index skip (atlas/atlas.hcl) keeps them from migrate diff.
-- Each expression equals its constant in server/src/services/master-search-text.ts.
CREATE INDEX IF NOT EXISTS "groups_search_idx" ON "groups" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'') || ' ' || coalesce("code",'')));
CREATE INDEX IF NOT EXISTS "study_programs_search_idx" ON "study_programs" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'')));
CREATE INDEX IF NOT EXISTS "lesson_templates_search_idx" ON "lesson_templates" USING gin (to_tsvector('english', coalesce("name",'') || ' ' || coalesce("description",'')));
CREATE INDEX IF NOT EXISTS "lessons_search_idx" ON "lessons" USING gin (to_tsvector('english', coalesce("title",'')));
CREATE INDEX IF NOT EXISTS "lesson_activities_search_idx" ON "lesson_activities" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("readContent",'') || ' ' || coalesce("helpTitle",'') || ' ' || coalesce("helpDescription",'')));
CREATE INDEX IF NOT EXISTS "activity_read_blocks_search_idx" ON "activity_read_blocks" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("content",''))) WHERE "lessonActivityId" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "events_search_idx" ON "events" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("description",'') || ' ' || coalesce("locationName",'')));
CREATE INDEX IF NOT EXISTS "posts_search_idx" ON "posts" USING gin (to_tsvector('english', coalesce("title",'') || ' ' || coalesce("content",'')));
CREATE INDEX IF NOT EXISTS "members_search_idx" ON "members" USING gin (to_tsvector('simple', coalesce("firstName",'') || ' ' || coalesce("lastName",'') || ' ' || coalesce("email",'') || ' ' || coalesce("phoneNumber",'')));
CREATE INDEX IF NOT EXISTS "media_search_idx" ON "media" USING gin (to_tsvector('english', coalesce("title",'')));
CREATE INDEX IF NOT EXISTS "media_tags_search_idx" ON "media_tags" USING gin (to_tsvector('english', "tag"));
CREATE INDEX IF NOT EXISTS "groups_title_lower_idx" ON "groups" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "study_programs_title_lower_idx" ON "study_programs" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "lesson_templates_title_lower_idx" ON "lesson_templates" (lower("name") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "lessons_title_lower_idx" ON "lessons" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "events_title_lower_idx" ON "events" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "posts_title_lower_idx" ON "posts" (lower("title") text_pattern_ops);
CREATE INDEX IF NOT EXISTS "members_title_lower_idx" ON "members" (lower(btrim(coalesce("firstName",'') || ' ' || coalesce("lastName",''))) text_pattern_ops);
CREATE INDEX IF NOT EXISTS "media_title_lower_idx" ON "media" (lower("title") text_pattern_ops);
```

**Tests:**
- `every SEARCH_TEXT constant appears verbatim in the migration` — a drifted constant silently loses its index (D40)

```ts
it('every SEARCH_TEXT constant appears verbatim in the migration', () => {
  const sql = readMigration('_master_search_indexes.sql')
  for (const expr of Object.values(SEARCH_TEXT)) expect(sql).toContain(`gin (${expr})`)
  for (const expr of Object.values(SEARCH_TITLE)) expect(sql).toContain(`(${expr} text_pattern_ops)`)
})
```

- `each search and title index exists on the lease` — the migration ran through Atlas (SC2)

```ts
it('each search and title index exists on the lease', async () => {
  const rows = await prisma.$queryRaw<{ indexname: string }[]>`SELECT indexname FROM pg_indexes WHERE indexname LIKE '%\_search\_idx' OR indexname LIKE '%\_title\_lower\_idx'`
  const names = rows.map((r) => r.indexname)
  for (const n of ['groups_search_idx', 'media_tags_search_idx', 'activity_read_blocks_search_idx', 'members_title_lower_idx', 'media_title_lower_idx']) expect(names).toContain(n)
  expect(names.filter((n) => n.endsWith('_search_idx') && n !== 'verses_search_idx')).toHaveLength(11)
  expect(names.filter((n) => n.endsWith('_title_lower_idx'))).toHaveLength(8)
})
```

- `the migration runs on a text-id database` — both id types (§Testing)

```ts
it('the migration runs on a text-id database', async () => {
  await withTextIdSearchDb(async (url) => {
    const client = new Client({ connectionString: url }); await client.connect()
    await client.query(readMigration('_master_search_indexes.sql'))
    const r = await client.query(`SELECT count(*)::int c FROM pg_indexes WHERE indexname = 'posts_search_idx'`)
    expect(r.rows[0].c).toBe(1)
    await client.end()
  })
}, 120_000)
```

- `EXPLAIN uses each arm's index` — with `enable_seqscan = off`, one predicate over each constant names its index (D40, F14)

```ts
it.each(Object.entries(INDEX_BY_KEY))('EXPLAIN uses the index for %s', async (key, index) => {
  const plan = await explainWithoutSeqScan(key)
  expect(plan).toContain(index)
})
```

- [ ] **Step 1: Write the listed tests** — in `server/test/master-search-indexes.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — the Task 1 command
- [ ] **Step 3: Write `master-search-text.ts`, create the migration above through `migrate new`, hash, add the YAML comments**
- [ ] **Step 4: Run `cd server && npm run schema:validate && npx --no-install tsc --noEmit`, confirm a second `migrate diff` is empty, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): hand-managed search indexes`

### Task 3: Query parsing, tokens, cursor and tag spellings
App: server
Phase: 2
Recipe: `/api`; SPEC D17, D18, D31, D35, D38, D39

**Files:**
- Create: `server/src/services/master-search-query.ts` — pure functions, no database
- Test: `server/src/services/__tests__/master-search-query.test.ts`

**Interfaces:**
- Produces: `SEARCH_TYPES` — the closed list PROGRAM, TEMPLATE, MEMBER, GROUP, LESSON, EVENT, POST, VIDEO, PHOTO, with a `SearchType` union. `SearchParamError` — an Error whose message is the 400's `error`. `parseListFilters` — takes the raw query object, returns `types`, `orgIds`, `groupIds`, `leaderIds`, `tags` (each `undefined` when absent), and throws `SearchParamError`. `parseRankedParams` — the same plus `q`, `limit`, `cursor`. `tokenizeQuery` — takes `q`, returns its tokens. `buildTsQuery` — takes tokens, returns the `to_tsquery` string or `null` for none. `escapeLike` — returns the text with `%`, `_` and `\` escaped. `encodeCursor` and `decodeCursor` — convert between an opaque string and `{ score: string, createdAt: string, id: string }`; decode throws `SearchParamError`. `phoneDigits` — takes `q`, returns its digits when `q` holds only digits and phone punctuation and has at least 4 digits, else `null`. `expandTagPicks` — takes the picked tags and `TagCategoryDTO[]`, returns the normalized spellings to match.

**Behaviour:**
- `q` is trimmed; under 2 or over 200 characters, or containing NUL, is a 400 (D18)
- `limit` is an integer 1–50 defaulting to 20 on C1; on C2 it is 1–50 defaulting to 50 (D17, D12)
- `types` values outside `SEARCH_TYPES` are a 400; comma lists drop empty items; a list above 50 ids is a 400; foreign or malformed ids are kept, since they only narrow (D38)
- Tokens match `/[\p{L}\p{N}]+/gu`; each is wrapped in single quotes, joined with ` & `, the last suffixed `:*`, and the whole string is bound as one parameter (D39)
- The cursor is base64url JSON of `{ s, c, i }`, holding raw float8 text, `"createdAt"::text` and id; anything else decodes as a 400, including a `s` that is not a finite number and a `c` that is not a timestamp (D39, D17)
- A phone query holds only digits, spaces and `+ - ( ) .`, and at least 4 digits (D35)
- A picked tag is normalized by `normalizeTag`; a pick that normalizes to a category member expands to every spelling sharing that member's `position` in its category, each normalized (D31)

**Tests:**
- `rejects q out of bounds` — (D18)

```ts
it('rejects q out of bounds', () => {
  for (const q of ['', ' a ', 'x'.repeat(201), 'ab\u0000c']) expect(() => parseRankedParams({ q })).toThrow(SearchParamError)
  expect(parseRankedParams({ q: '  ab ' }).q).toBe('ab')
})
```

- `rejects unknown types, oversized lists and bad limits, keeps foreign ids` — (D38, D17)

```ts
it('rejects unknown types, oversized lists and bad limits, keeps foreign ids', () => {
  expect(() => parseRankedParams({ q: 'ab', types: 'PROGRAM,NOPE' })).toThrow(SearchParamError)
  expect(() => parseRankedParams({ q: 'ab', orgIds: Array(51).fill('x').join(',') })).toThrow(SearchParamError)
  expect(() => parseRankedParams({ q: 'ab', limit: '51' })).toThrow(SearchParamError)
  expect(parseRankedParams({ q: 'ab', orgIds: 'not-a-uuid,' }).orgIds).toEqual(['not-a-uuid'])
  expect(parseRankedParams({ q: 'ab' }).limit).toBe(20)
  expect(parseListFilters({}).types).toBeUndefined()
})
```

- `builds a prefix tsquery and survives punctuation` — (D39)

```ts
it('builds a prefix tsquery and survives punctuation', () => {
  expect(buildTsQuery(tokenizeQuery('romans 8'))).toBe("'romans' & '8':*")
  expect(buildTsQuery(tokenizeQuery("o'brien"))).toBe("'o' & 'brien':*")
  for (const q of ["'", ':', '&', '!', '%', '_']) expect(buildTsQuery(tokenizeQuery(q))).toBeNull()
})
```

- `escapes LIKE metacharacters` — (D39)

```ts
it('escapes LIKE metacharacters', () => {
  expect(escapeLike('50%_a\\')).toBe('50\\%\\_a\\\\')
})
```

- `round-trips a cursor without losing precision and refuses garbage` — microseconds survive (D39)

```ts
it('round-trips a cursor without losing precision and refuses garbage', () => {
  const c = { score: '4.0607927101', createdAt: '2026-10-03 12:00:00.123456', id: 'abc' }
  expect(decodeCursor(encodeCursor(c))).toEqual(c)
  for (const bad of ['nope', Buffer.from('{"s":"NaN","c":"x","i":"y"}').toString('base64url')]) expect(() => decodeCursor(bad)).toThrow(SearchParamError)
})
```

- `recognizes formatted and partial phones only` — (D35)

```ts
it('recognizes formatted and partial phones only', () => {
  expect(phoneDigits('(555) 010-0')).toBe('5550100')
  expect(phoneDigits('555')).toBeNull()
  expect(phoneDigits('grace 5550')).toBeNull()
})
```

- `expands a picked category member to all its spellings` — (D31)

```ts
it('expands a picked category member to all its spellings', () => {
  const cats = [{ key: 'b', name: 'Books', position: 0, tags: [{ tag: '1 samuel', label: '1 Samuel', position: 0 }, { tag: '1samuel', label: '1 Samuel', position: 0 }, { tag: 'mark', label: 'Mark', position: 1 }] }]
  expect(new Set(expandTagPicks(['1 Samuel'], cats))).toEqual(new Set(['1samuel']))
  expect(new Set(expandTagPicks(['Mark', 'Lent Plan'], cats))).toEqual(new Set(['mark', 'lentplan']))
})
```

- [ ] **Step 1: Write the listed tests** — in `server/src/services/__tests__/master-search-query.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/master-search-query.test.ts`, watch them fail** — module not found
- [ ] **Step 3: Implement `server/src/services/master-search-query.ts` to the Behaviour**
- [ ] **Step 4: Run the same command and `npx --no-install tsc --noEmit`, watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): query parsing, tokens and cursor`

### Task 4: C1 ranked search
App: server
Phase: 2
Recipe: `/api`; SPEC §server, D1, D2, D4–D9, D15, D16, D19, D28–D30, D33–D35, D37–D39

**Files:**
- Create: `server/src/services/master-search.ts` — scope, arms, score, hydration shape
- Modify: `server/src/services/study-program.service.ts:64-85` — extract the org-list half of `privateProgramVisibility`
- Modify: `server/src/routes/search.ts` — add C1 with `@openapi`, before `export default router`; existing handlers untouched
- Create: `server/test/helpers/master-search-world.ts` — seeds the shared test world
- Test: `server/test/master-search-ranked.test.ts`, `server/test/master-search-text-ids.test.ts`

**Interfaces:**
- Consumes: `SEARCH_TEXT`, `SEARCH_TITLE`, `qualifySearchExpr` from `master-search-text.ts`; `parseRankedParams`, `SearchParamError`, `SEARCH_TYPES`, `tokenizeQuery`, `buildTsQuery`, `escapeLike`, `encodeCursor`, `decodeCursor`, `phoneDigits`, `expandTagPicks` from `master-search-query.ts`; `getUserOrganizations`, `memberAccessScope`, `normalizePhone`, `listTagCategories`
- Produces: `searchRanked` — takes the user id and parsed params, returns `{ items, nextCursor }`. `buildSearchScope` — takes the user id and `orgIds` filter, returns the resolved scope. `buildArm` — takes a type, the scope, the filters and either the text match or a list of ids, returns one `Prisma.Sql` row source. `serializeSearchItem` — turns a raw arm row into the wire `SearchItem`. `privateProgramAdminOrgIds` — takes a user id, returns the org ids where private programs are visible, or `null` for a super admin; `privateProgramVisibility` is rewritten over it with its answers unchanged.

The frozen contract, verbatim from SPEC §Contract:

```
C1 GET /api/search/ranked · requireAuth
Request: q, optional comma lists types, orgIds, groupIds, leaderIds, tags, limit, cursor
Response: { success: true, items: [SearchItem], nextCursor: string | null }
Errors: 400 bad q, types, limit or cursor, or a filter list above 50; 401

SearchItem:
{ "type": "LESSON", "id": "…", "title": "Day 3: Grace", "createdAt": "2026-10-03T…Z",
  "score": 2.41, "imageUrl": null,
  "parent": { "type": "PROGRAM", "id": "…", "name": "Romans in 30 days" } }
```

`imageUrl` is `Media.url` for PHOTO and `null` for every other type. `parent` is set for LESSON (PROGRAM), EVENT and POST (GROUP), and `null` otherwise. `score` is a number on C1, comparable only within one response's query. `title` is never null. `id` is always the row's own table id, serialized as text.

**Behaviour:**
- Scope is the caller's `getUserOrganizations`, intersected with a set `orgIds`; a set `orgIds` with no overlap answers an empty list, and any set `orgIds` drops system templates. No Super Admin bypass, and an org-less program is out (D38, D8, D4)
- A caller with no orgs gets 200 and can still get system templates (D19)
- The security rules per arm, all compared with `::text` on both sides (§server):

```
PROGRAM   isActive, org ∈ scope, private rule
LESSON    its program passes PROGRAM
TEMPLATE  isActive, (org ∈ scope OR (isSystem AND no orgIds filter))
GROUP     isActive, org ∈ scope
EVENT     isActive, group active, group org ∈ scope, type::text <> 'LESSON',
          no earlier active row in the same recurrenceGroupId by (date, id::text)
POST      isActive, group active, group org ∈ scope
PHOTO     isActive, org ∈ scope, type='photo', uploadStatus='ready',
          source IS DISTINCT FROM 'auto_capture', groupId NULL or its group active
VIDEO     as PHOTO with type='video'
MEMBER    isActive, and (a member_organizations row in an org whose memberAccessScope is all,
          or an active group_members row in a group from a limited scope's groupIds, that group active)

private rule = NOT isPrivate OR creatorId = caller OR leaderId = caller
               OR org ∈ privateProgramAdminOrgIds; TRUE when that is null
```

- Scope for MEMBER is one `memberAccessScope` call per org in scope, gathered into `allOrgIds` and `limitedGroupIds` before the query (D30)
- Filters are `EXISTS`, never joins, so a lesson with many activities or a program with many enrollments stays one row (D39). A picked filter drops every type with no value for it (D6). The closed mapping, leader columns all `User.id` (D7, D37):

```
Org     PROGRAM TEMPLATE GROUP PHOTO VIDEO own column · EVENT POST group's · LESSON program's · MEMBER membership
Group   GROUP itself · EVENT POST PHOTO VIDEO own column · MEMBER active membership · PROGRAM enrollment ·
        LESSON its program's enrollment · TEMPLATE none (drops out)
Leader  GROUP creatorId · PROGRAM leaderId or creatorId · LESSON its program's leaderId or creatorId ·
        TEMPLATE creatorId · EVENT createdById · POST authorId · PHOTO VIDEO uploadedBy · MEMBER none
Tags    PROGRAM study_program_tags · PHOTO VIDEO media_tags · LESSON its program's · others none
```

- A `groupIds` filter counts only groups whose org is in scope, so a foreign id cannot reveal a visible member's membership elsewhere (D38)
- Tags compare `lower(regexp_replace(tag, '\s+', '', 'g')) = ANY(expandTagPicks(...))` (D31)
- Score and order, for every arm (D1, D39):

```
tsq    = to_tsquery(<english|simple>, <one bound param>), absent when buildTsQuery is null
tier   = CASE WHEN lower(title) = lq THEN 4
              WHEN lower(title) LIKE lqEscaped || '%' ESCAPE '\' THEN 3
              WHEN tsq present AND to_tsvector(cfg, coalesce(title,'')) @@ tsq THEN 2
              ELSE 1 END
match  = lower(title) = lq OR lower(title) LIKE prefix OR (tsq present AND SEARCH_TEXT[arm] @@ tsq)
score  = tier + coalesce(ts_rank(vector, tsq, 32), 0)  as float8
outer  = SELECT … FROM (arm UNION ALL arm …) ORDER BY score DESC, "createdAt" DESC, id DESC LIMIT limit + 1
cursor = (score, "createdAt", id) < ($s::float8, $c::timestamp, $i)
```

- `title` above is the stored title only; a fallback title is computed for output and never scores above tier 1 (D28)
- LESSON's match adds `EXISTS` over `lesson_activities` and over `activity_read_blocks` where `lessonActivityId` is set, and its rank is `GREATEST` over its texts through `LATERAL`, as `routes/search.ts:625-740` does (D16, D39). F4 risk: measure this arm against the fixture data once Task 7 lands; if it is slow, report it, and a stored search column on `lessons` is the fallback (F4)
- PHOTO and VIDEO also match `EXISTS media_tags` over `SEARCH_TEXT.mediaTag` at tier 1 (D16)
- MEMBER adds to `match`: `lower(email) = lq` and `phoneNumber = normalizePhone(q)`, both tier 4; with `phoneDigits(q)`, `phoneNumber LIKE '%' || digits || '%'` at tier 1 (D35, D16)
- Output titles: POST title, else the first line of content cut to 80 characters; LESSON title, else `Day <dayNumber>`; MEMBER first + last trimmed, else email, else `phoneNumber` (D28). POST's first-line fallback is computed in `serializeSearchItem` only.
- Dates on the wire are `.SSSZ` from `toISOString()`; the cursor keeps `"createdAt"::text`, so each arm also selects it as `"createdAtText"`, and `"score"::text` as `"scoreText"` (D39)
- `nextCursor` is built from the last returned row when the `limit + 1`th exists, else `null` (D17)
- Route: `SearchParamError` → 400 `{ success: false, error }`; any other error → 500 `{ success: false, error: 'Search failed' }`; success `{ success: true, items, nextCursor }` (D32). Route thin; all else in the service.
- Stop-word-only queries log no failure: F13 is settled by the stop-word test below (F13)
- `GET /api/search` handlers are not edited (D3)

**Tests:** in `server/test/master-search-ranked.test.ts`, through an express app with `/api/search` mounted and `req.user` set as `programs-list.request.test.ts:25-34` does. `world` from the helper holds owner, admin, group leader, outsider, two orgs, and one row of each type sharing the word `grace`.

- `orders by tier across types` — exact title, then prefix, then all words, then other text (D1, D2)

```ts
it('orders by tier across types', async () => {
  const { items } = await search(world.owner, { q: 'grace notes' })
  expect(items.map((i: any) => i.id).slice(0, 4)).toEqual([world.exactPostId, world.prefixProgramId, world.wordsGroupId, world.otherLessonId])
  expect(items[0].score).toBeGreaterThanOrEqual(4)
  expect(items[0].score).toBeLessThan(5)
  expect(typeof items[0].score).toBe('number')
  expect(new Set(items.map((i: any) => i.type)).size).toBeGreaterThan(2)
})
```

- `Owner, Admin and Group Leader see the org; an outsider sees only system templates` — (D4, D8, D19)

```ts
it('Owner, Admin and Group Leader see the org; an outsider sees only system templates', async () => {
  for (const u of [world.owner, world.admin, world.leader]) expect((await search(u, { q: 'grace', types: 'GROUP' })).items).not.toHaveLength(0)
  expect((await search(world.outsider, { q: 'grace', types: 'GROUP' })).items).toHaveLength(0)
  expect((await search(world.outsider, { q: 'video study' })).items.map((i: any) => i.type)).toEqual(['TEMPLATE'])
})
```

- `a set Orgs filter drops system templates and an empty overlap is empty` — (D8, D38)

```ts
it('a set Orgs filter drops system templates and an empty overlap is empty', async () => {
  expect((await search(world.owner, { q: 'video study', orgIds: world.orgA })).items.filter((i: any) => i.type === 'TEMPLATE' && i.id === world.systemTemplateId)).toHaveLength(0)
  expect((await search(world.owner, { q: 'grace', orgIds: 'foreign,not-a-uuid' })).items).toHaveLength(0)
})
```

- `each filter maps as D7 rules, with drop-outs` — one row per filter and type (D6, D7, D37)

```ts
it.each([
  ['groupIds', () => world.groupA, ['GROUP', 'EVENT', 'POST', 'PHOTO', 'VIDEO', 'MEMBER', 'PROGRAM', 'LESSON']],
  ['leaderIds', () => world.nullLeaderProgramCreator, ['PROGRAM', 'LESSON']],
  ['tags', () => 'lent', ['PROGRAM', 'LESSON', 'PHOTO', 'VIDEO']],
] as const)('each filter maps as D7 rules, with drop-outs: %s', async (key, value, types) => {
  const { items } = await search(world.owner, { q: 'grace', limit: '50', [key]: value() })
  expect(new Set(items.map((i: any) => i.type))).toEqual(new Set(types))
})
```

- `D30: a Group Leader finds only members of their active groups; Owner finds a group-less member` — both roles, and a phone cannot be turned into a name (D30)

```ts
it('D30: a Group Leader finds only members of their active groups; Owner finds a group-less member', async () => {
  const q = { q: world.grouplessPhone, types: 'MEMBER' }
  expect((await search(world.owner, q)).items.map((i: any) => i.id)).toEqual([world.grouplessMemberId])
  expect((await search(world.admin, q)).items.map((i: any) => i.id)).toEqual([world.grouplessMemberId])
  expect((await search(world.leader, q)).items).toHaveLength(0)
  expect((await search(world.leader, { q: 'gracie', types: 'MEMBER' })).items.map((i: any) => i.id)).toEqual([world.leadersMemberId])
})
```

- `D33: a private program and its lessons stay hidden from another leader` — (D33)

```ts
it('D33: a private program and its lessons stay hidden from another leader', async () => {
  const q = { q: 'secret', types: 'PROGRAM,LESSON' }
  expect((await search(world.leader, q)).items).toHaveLength(0)
  expect((await search(world.admin, q)).items).toHaveLength(2)
  expect((await search(world.privateCreator, q)).items).toHaveLength(2)
})
```

- `D34 and D15: an auto-captured cover and a pending row are out` — (D34, D15)

```ts
it('D34 and D15: an auto-captured cover and a pending row are out', async () => {
  const ids = (await search(world.owner, { q: 'grace', types: 'PHOTO', limit: '50' })).items.map((i: any) => i.id)
  expect(ids).toContain(world.photoId)
  expect(ids).not.toContain(world.autoCaptureId)
  expect(ids).not.toContain(world.pendingPhotoId)
  const video = (await search(world.owner, { q: 'grace', types: 'VIDEO' })).items[0]
  expect(video.imageUrl).toBeNull()
  expect((await search(world.owner, { q: 'grace', types: 'PHOTO' })).items[0].imageUrl).toMatch(/^https:/)
})
```

- `D35: formatted and partial phones and any-case email find a member` — (D35, D16)

```ts
it('D35: formatted and partial phones and any-case email find a member', async () => {
  const first = async (q: string) => (await search(world.owner, { q, types: 'MEMBER' })).items[0]
  expect((await first(world.memberPhoneFormatted)).score).toBeGreaterThanOrEqual(4)
  expect((await first(world.memberPhoneLast4)).score).toBeLessThan(2)
  expect((await first(world.memberEmail.toUpperCase())).id).toBe(world.leadersMemberId)
})
```

- `D29: one row per series, no generated lesson events` — (D29)

```ts
it('D29: one row per series, no generated lesson events', async () => {
  const { items } = await search(world.owner, { q: 'grace series', types: 'EVENT' })
  expect(items.map((i: any) => i.id)).toEqual([world.seriesFirstEventId])
  expect((await search(world.owner, { q: 'day 1 grace', types: 'EVENT' })).items).toHaveLength(0)
})
```

- `D28: fallback titles, scoring tier 1 at most` — (D28)

```ts
it('D28: fallback titles, scoring tier 1 at most', async () => {
  const post = (await search(world.owner, { q: 'untitled grace body', types: 'POST' })).items[0]
  expect(post.title).toBe(world.untitledPostFirstLine80)
  expect(post.score).toBeLessThan(2)
  expect((await search(world.owner, { q: 'lessontext', types: 'LESSON' })).items[0].title).toBe('Day 7')
})
```

- `parent, id and date shapes` — §Contract, D32, D39

```ts
it('parent, id and date shapes', async () => {
  const { items } = await search(world.owner, { q: 'grace', types: 'LESSON' })
  expect(items[0].parent).toEqual({ type: 'PROGRAM', id: world.programId, name: world.programName })
  expect(items[0].createdAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/)
  expect(typeof items[0].id).toBe('string')
})
```

- `pages with no repeats or gaps, including tied scores and microsecond dates` — (D17, D39)

```ts
it('pages with no repeats or gaps, including tied scores and microsecond dates', async () => {
  const seen: string[] = []
  let cursor: string | undefined
  do {
    const page = await search(world.owner, { q: 'tieword', limit: '3', ...(cursor ? { cursor } : {}) })
    seen.push(...page.items.map((i: any) => `${i.type}:${i.id}`))
    cursor = page.nextCursor ?? undefined
  } while (cursor)
  expect(new Set(seen).size).toBe(seen.length)
  expect(seen).toHaveLength(world.tiedRowCount)
})
```

- `a many-activity lesson and a many-enrollment program are one row` — (D39)

```ts
it('a many-activity lesson and a many-enrollment program are one row', async () => {
  const { items } = await search(world.owner, { q: 'manyword', types: 'LESSON,PROGRAM', groupIds: `${world.groupA},${world.groupB}` })
  expect(items).toHaveLength(2)
})
```

- `punctuation, stop words and NUL behave` — (D18, D39, F13)

```ts
it.each(["'%", '_:', '&!', 'the', 'gospel of j'])('answers 200 for %s', async (q) => {
  const res = await rawSearch(world.owner, { q })
  expect(res.status).toBe(200)
  expect(Array.isArray(res.body.items)).toBe(true)
})
it('finds an exact stop-word title and refuses NUL', async () => {
  expect((await search(world.owner, { q: 'the', types: 'GROUP' })).items.map((i: any) => i.id)).toEqual([world.groupTitledThe])
  expect((await rawSearch(world.owner, { q: 'ab\u0000' })).status).toBe(400)
})
```

- `400s and 401 use the error form` — (D18, D32, D38)

```ts
it('400s and 401 use the error form', async () => {
  for (const q of [{ q: 'a' }, { q: 'ab', types: 'NOPE' }, { q: 'ab', cursor: 'nope' }]) {
    const res = await rawSearch(world.owner, q)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(typeof res.body.error).toBe('string')
  }
  expect((await rawSearch(null, { q: 'ab' })).status).toBe(401)
})
```

- `GET /api/search keeps its grouped response` — (D3)

```ts
it('GET /api/search keeps its grouped response', async () => {
  const res = await request(appFor(world.owner)).get('/api/search').query({ q: 'grace', types: 'GROUP' })
  expect(res.status).toBe(200)
  expect(Object.keys(res.body).sort()).toEqual(LEGACY_SEARCH_KEYS)
  expect(res.body.items).toBeUndefined()
})
```

- `every arm runs on a text-id database` — in `master-search-text-ids.test.ts`: `withTextIdSearchDb`, set `DATABASE_URL`, `vi.resetModules()`, dynamic import, seed the world, one query per type (§server, §Testing)

```ts
it('every arm runs on a text-id database', async () => {
  await withTextIdSearchDb(async (url) => {
    const { searchRanked, world } = await loadSearchAgainst(url)
    for (const type of SEARCH_TYPES) {
      const { items } = await searchRanked(world.owner.id, parseRankedParams({ q: 'grace', types: type, ...(type === 'TEMPLATE' ? { q: 'video study' } : {}) }))
      expect(items.length, type).toBeGreaterThan(0)
    }
  })
}, 180_000)
```

- `privateProgramVisibility answers as before` — the extracted helper changes nothing; extend `src/services/__tests__/study-program.service.test.ts`

```ts
it('privateProgramVisibility answers as before', async () => {
  isSuperAdminMock.mockResolvedValue(true)
  await expect(privateProgramVisibility('u1')).resolves.toEqual({})
  expect(await privateProgramAdminOrgIds('u1')).toBeNull()
})
```

- [ ] **Step 1: Write the world helper and the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `privateProgramAdminOrgIds`, then `master-search.ts` and C1 to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): ranked search across nine types (C1)`

### Task 5: C2, C3, C4 recents
App: server
Phase: 2
Recipe: `/api`; SPEC §server *C3 write*, D10–D12, D22, D30, D33

**Files:**
- Modify: `server/src/services/master-search.ts` — add recents over the same arms
- Modify: `server/src/routes/search.ts` — add C2, C3, C4 with `@openapi`, zod on C3's body
- Test: `server/test/master-search-recents.test.ts`

**Interfaces:**
- Consumes: `buildSearchScope`, `buildArm`, `serializeSearchItem` (`master-search.ts`); `parseListFilters`, `SEARCH_TYPES`, `SearchParamError` (`master-search-query.ts`)
- Produces: `listRecentResults` — takes user id and parsed filters, returns the items with `openedAt`. `recordRecentResult` — takes user id, type, id; returns `false` when the item isn't visible. `deleteRecentResult` — takes user id, type, id.

The frozen contract, verbatim from SPEC §Contract:

```
C2 GET /api/search/recent-results · requireAuth
Request: optional types, orgIds, groupIds, leaderIds, tags, limit (default and max 50)
Response: { success: true, items: [SearchItem & { openedAt: ISO8601 }] }; score is null
Errors: 400 bad types or limit, or a filter list above 50; 401

C3 PUT /api/search/recent-results · requireAuth
Request: { type: SearchType, id: string }
Response: 200 { success: true }
Errors: 400 bad body; 401; 404 not found, or not visible by the same per-type rules as C1 (a PHOTO id sent as VIDEO is a 404)

C4 DELETE /api/search/recent-results/:type/:id · requireAuth
Request: path only
Response: 200 { success: true }, including when no entry exists
Errors: 400 bad type; 401
```

**Behaviour:**
- C2 reads the caller's newest rows, runs each type's `buildArm` over those ids with no text match, applies D6/D7's filters identically to C1, joins back on type + id, orders by `openedAt` desc then row id desc, returns at most `limit`, with `score: null` (D11, D6, D12)
- A row whose resource is deleted, inactive or no longer visible simply yields no arm row and drops out, the D30/D33 rules included (D11)
- Reading more rows than `limit` is required so a filter or a drop-out cannot starve the page: read all of the user's rows, which D12's cap of 100 bounds (D12)
- C3 checks visibility with the arm for that exact type, then in one transaction runs (§server, D12):

```sql
INSERT INTO "search_recent_results" ("userId", "resourceType", "resourceId")
VALUES (<userId>, <type>, <id>)
ON CONFLICT ("userId", "resourceType", "resourceId") DO UPDATE SET "openedAt" = now();

DELETE FROM "search_recent_results" WHERE "id" IN (
  SELECT "id" FROM "search_recent_results" WHERE "userId"::text = <userId>
  ORDER BY "openedAt" DESC, "id" DESC OFFSET 100);
```

- Bind `<userId>` so it fits both id types (`CAST` through the column's type: `(SELECT "id" FROM "users" WHERE "id"::text = $1)`) (§server, D38)
- C3's zod body is strict on `type` from `SEARCH_TYPES` and a non-empty `id`; any other field is a 400 rather than silently stripped (global constraint)
- C4 deletes only the caller's row and answers 200 whether one existed or not; a bad `:type` is a 400 (§Contract)
- An EVENT recent on a non-first row of a series drops out like any other non-visible row (D11, D29)

**Tests:**
- `C2 returns newest first with null score and openedAt` — (D10, D11)

```ts
it('C2 returns newest first with null score and openedAt', async () => {
  await put(world.owner, 'GROUP', world.groupA); await put(world.owner, 'PROGRAM', world.programId)
  const res = await list(world.owner)
  expect(res.body.items.map((i: any) => i.id)).toEqual([world.programId, world.groupA])
  expect(res.body.items[0].score).toBeNull()
  expect(res.body.items[0].openedAt).toMatch(/\.\d{3}Z$/)
})
```

- `re-opening moves an entry up without a second row, including concurrently` — (D10, §server)

```ts
it('re-opening moves an entry up without a second row, including concurrently', async () => {
  await put(world.owner, 'GROUP', world.groupA); await put(world.owner, 'PROGRAM', world.programId)
  const results = await Promise.all([put(world.owner, 'GROUP', world.groupA), put(world.owner, 'GROUP', world.groupA)])
  expect(results.map((r) => r.status)).toEqual([200, 200])
  const res = await list(world.owner)
  expect(res.body.items.map((i: any) => i.id)).toEqual([world.groupA, world.programId])
})
```

- `C2 drops deleted, inactive and no-longer-visible rows` — the three drop-outs (D11)

```ts
it('C2 drops deleted, inactive and no-longer-visible rows', async () => {
  await put(world.owner, 'GROUP', world.tempGroupId); await put(world.owner, 'POST', world.tempPostId); await put(world.leader, 'GROUP', world.groupA)
  await prisma.group.update({ where: { id: world.tempGroupId }, data: { isActive: false } })
  await prisma.post.delete({ where: { id: world.tempPostId } })
  await removeRolesOf(world.leader)
  expect((await list(world.owner)).body.items.map((i: any) => i.id)).not.toEqual(expect.arrayContaining([world.tempGroupId, world.tempPostId]))
  expect((await list(world.leader)).body.items).toHaveLength(0)
})
```

- `C2's filters match C1's` — (D6)

```ts
it("C2's filters match C1's", async () => {
  await put(world.owner, 'PHOTO', world.photoId); await put(world.owner, 'GROUP', world.groupA)
  expect((await list(world.owner, { tags: 'lent' })).body.items.map((i: any) => i.type)).toEqual(['PHOTO'])
  expect((await list(world.owner, { types: 'GROUP' })).body.items.map((i: any) => i.type)).toEqual(['GROUP'])
  expect((await list(world.owner, { types: 'NOPE' })).status).toBe(400)
})
```

- `C3 keeps the newest 100 and C2 returns at most 50` — (D12)

```ts
it('C3 keeps the newest 100 and C2 returns at most 50', async () => {
  await seedRecents(world.owner, 100, 'GROUP')
  await put(world.owner, 'GROUP', world.groupA)
  expect(await prisma.searchRecentResult.count({ where: { userId: world.owner.id } })).toBe(100)
  expect((await list(world.owner)).body.items.length).toBeLessThanOrEqual(50)
  expect((await list(world.owner, { limit: '51' })).status).toBe(400)
})
```

- `C3 answers 404 per type, including a wrong type and an invisible member` — (§Contract, D30)

```ts
it('C3 answers 404 per type, including a wrong type and an invisible member', async () => {
  expect((await put(world.owner, 'VIDEO', world.photoId)).status).toBe(404)
  expect((await put(world.owner, 'PROGRAM', 'missing')).status).toBe(404)
  expect((await put(world.outsider, 'GROUP', world.groupA)).status).toBe(404)
  expect((await put(world.leader, 'MEMBER', world.grouplessMemberId)).status).toBe(404)
  expect((await put(world.leader, 'PROGRAM', world.privateProgramId)).status).toBe(404)
})
```

- `C3 refuses a bad body rather than stripping it` — (global constraint)

```ts
it('C3 refuses a bad body rather than stripping it', async () => {
  for (const body of [{}, { type: 'NOPE', id: 'x' }, { type: 'GROUP', id: '' }, { type: 'GROUP', id: 'x', extra: 1 }]) {
    const res = await request(appFor(world.owner)).put('/api/search/recent-results').send(body)
    expect(res.status).toBe(400)
  }
})
```

- `C4 is idempotent, touches only the caller's entry, refuses a bad type` — (§Contract)

```ts
it("C4 is idempotent, touches only the caller's entry, refuses a bad type", async () => {
  await put(world.owner, 'GROUP', world.groupA)
  expect((await del(world.admin, 'GROUP', world.groupA)).status).toBe(200)
  expect((await list(world.owner)).body.items).toHaveLength(1)
  expect((await del(world.owner, 'GROUP', world.groupA)).status).toBe(200)
  expect((await del(world.owner, 'GROUP', world.groupA)).body).toEqual({ success: true })
  expect((await list(world.owner)).body.items).toHaveLength(0)
  expect((await del(world.owner, 'NOPE', 'x')).status).toBe(400)
})
```

- `recents work on a text-id database` — extend `master-search-text-ids.test.ts` (§Testing)

```ts
it('recents work on a text-id database', async () => {
  await withTextIdSearchDb(async (url) => {
    const { recordRecentResult, listRecentResults, world } = await loadSearchAgainst(url)
    expect(await recordRecentResult(world.owner.id, 'GROUP', world.groupA)).toBe(true)
    expect((await listRecentResults(world.owner.id, {})).map((i: any) => i.id)).toEqual([world.groupA])
  })
}, 180_000)
```

- [ ] **Step 1: Write the listed tests** — in `server/test/master-search-recents.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the three service functions and routes to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): recently opened results (C2, C3, C4)`

### Task 6: C5 filter options
App: server
Phase: 2
Recipe: `/api`; SPEC D13, D14, D31, D38

**Files:**
- Modify: `server/src/services/master-search.ts` — add the options read
- Modify: `server/src/routes/search.ts` — add C5 with `@openapi`
- Test: `server/test/master-search-options.test.ts`

**Interfaces:**
- Consumes: `getUserOrganizations`; `listTagCategories`, `normalizeTag`
- Produces: `searchFilterOptions` — takes the user id, returns `{ organizations, groups, leaders, tags }`

The frozen contract, verbatim from SPEC §Contract:

```
C5 GET /api/search/filter-options · requireAuth
Request: none
Response: { success: true, organizations: [{ id, name }], groups: [{ id, name, organizationId }],
            leaders: [{ id, name }], tags: [{ tag, label, category: string | null }] }
          tags in D31's display order
Errors: 401
```

**Behaviour:**
- Orgs, groups and leaders sort by name, then id (D38). Groups are active groups of the caller's orgs (D13)
- Leaders are, across the caller's orgs, one row per user: active group creators plus Owner, Admin and Group Leader role holders, the definition of `routes/programs.ts:648` without its counts (D38, §server)
- Tags merge `MediaTag` on active media and `StudyProgramTag` on active programs of the caller's orgs (D14)
- Tag options, in this display order: one per category member (its first spelling as `tag`, its `label`, `category` = `TagCategory.name`), categories by `position`, members by `position`; then one per remaining normalized tag (`tag` its first stored spelling, `label` title-cased, `category` null), by label. Spellings sharing a member's `position` are one option. A stored tag equal to a category member by `normalizeTag` is that member, not a remaining tag (D31)
- A caller with no orgs gets 200 with empty `organizations`, `groups`, `leaders` and the category options, whose content is global (D19, D31)
- `/api/group-leaders` and `/api/media/tags` are not changed (D13)

**Tests:**
- `lists every org, its groups and leaders across orgs, sorted, one row per user` — (D13, D38)

```ts
it('lists every org, its groups and leaders across orgs, sorted, one row per user', async () => {
  const body = await options(world.multiOrgLeader)
  expect(body.organizations.map((o: any) => o.id)).toEqual(world.multiOrgIdsByName)
  expect(body.groups.every((g: any) => world.multiOrgIdsByName.includes(g.organizationId))).toBe(true)
  expect(body.groups.map((g: any) => g.id)).not.toContain(world.inactiveGroupId)
  const ids = body.leaders.map((l: any) => l.id)
  expect(new Set(ids).size).toBe(ids.length)
  expect(ids).toEqual(expect.arrayContaining([world.creatorInOrgA, world.roleHolderInOrgB]))
  expect(body.leaders.map((l: any) => l.name)).toEqual([...body.leaders.map((l: any) => l.name)].sort())
})
```

- `D31: one option per category member, in display order, then uncategorized by label` — two spellings collapse; both stores merge (D14, D31)

```ts
it('D31: one option per category member, in display order, then uncategorized by label', async () => {
  const { tags } = await options(world.owner)
  const samuel = tags.filter((t: any) => t.label === '1 Samuel')
  expect(samuel).toHaveLength(1)
  expect(samuel[0].category).toBe(world.categoryName)
  const firstUncategorized = tags.findIndex((t: any) => t.category === null)
  expect(tags.slice(firstUncategorized).every((t: any) => t.category === null)).toBe(true)
  expect(tags.slice(firstUncategorized).map((t: any) => t.label)).toEqual(expect.arrayContaining(['Lent', 'Outreach']))
})
```

- `two spellings of one member both match when one is picked` — the C1 side of D31, end to end

```ts
it('two spellings of one member both match when one is picked', async () => {
  const { items } = await search(world.owner, { q: 'grace', tags: '1samuel', types: 'PROGRAM,PHOTO' })
  expect(items.map((i: any) => i.id).sort()).toEqual([world.spacedSpellingProgramId, world.joinedSpellingPhotoId].sort())
})
```

- `a caller with no orgs gets the normal shape; no session gets 401` — (D19, D32)

```ts
it('a caller with no orgs gets the normal shape; no session gets 401', async () => {
  const body = await options(world.outsider)
  expect(body).toMatchObject({ success: true, organizations: [], groups: [], leaders: [] })
  expect(Array.isArray(body.tags)).toBe(true)
  expect((await request(appFor(null)).get('/api/search/filter-options')).status).toBe(401)
})
```

- [ ] **Step 1: Write the listed tests** — in `server/test/master-search-options.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `searchFilterOptions` and the route to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): filter options across orgs (C5)`

### Task 7: search-home screen fixture and the contract freeze
App: server
Phase: 2
Recipe: `server/fixtures/README.md` §Layers; SPEC D25, T6

**Files:**
- Create: `server/fixtures/screens/search-home.ts` — the `full` layer and its pure rows
- Modify: `server/fixtures/ids.ts:9-42` — new kinds `post: '001e'`, `template: '001f'`, `programTag: '0020'`, `recent: '0021'`
- Modify: `server/fixtures/wipe.ts:18-30` — delete the org's templates
- Modify: `server/fixtures/__tests__/wipe.test.ts:36-42` — the exact call list
- Modify: `server/fixtures/README.md` — one line under the layer list
- Modify: `docs/features/master-search/MANIFEST.md` — `contract: frozen <today>` in this task's commit
- Test: `server/fixtures/__tests__/search-home.test.ts`, `server/fixtures/__tests__/search-home.db.test.ts`

**Interfaces:**
- Consumes: `searchRanked`, `listRecentResults` from `server/src/services/master-search.ts`; `parseRankedParams` from `master-search-query.ts`; `fixtureId`, `FIXTURE_ORG_ID`, `FIXTURE_USER_ID`, `FIXTURE_PROGRAM_IDS`; `FixtureContext`
- Produces: `searchHomeRows` — takes `now` and a `daysAgo` function, returns the plain rows `full` writes. `SEARCH_HOME_WORD` — the constant `'Grace'`. `full` — the layer.

**Behaviour:**
- `full` adds rows of every D5 type sharing the word `Grace`: a program `Grace in Romans` with a tag `romans` and a lesson `Day 3: Grace`; a group-owned post titled exactly `Grace` (the exact-title row); a non-system org template `Grace Study Template`; an event `Grace Night` plus a 3-occurrence recurring series, and a `type: 'LESSON'` event titled `Day 1: Grace in Romans`; an untitled post with `Grace` in its content; a `photo` and a `video` Media row titled `Grace …`, each `uploadStatus: 'ready'`, `source: 'direct'` and tagged `romans`, written unconditionally because `media-home`'s layer exits when images are off, with `https://fixtures.invalid/search-home/…` URLs (D25, T6)
- Members and groups come from the base layer: no new member, since `members.db.test.ts:34` asserts 24 and base already has a first name `Grace`; D30's group-less case stays a vitest row (T6)
- Recents for `FIXTURE_USER_ID`, newest first by distinct `openedAt` from `ctx.daysAgo`: program, lesson, group, photo, post, member (D25)
- Every row takes a fixed id from `fixtureId`; dates come from `ctx.now`; `ctx.rand` is never touched; no org, user or group is created (fixtures README)
- `wipeFixtures` adds `lessonTemplate.deleteMany({ where: { organizationId: FIXTURE_ORG_ID } })` after `studyProgram`, because a template otherwise survives reset; `WipeClient` gains `'lessonTemplate'` (T6)
- The rows land on one base group. If a count asserted by an existing group or home fixture test breaks, move them to another base group rather than editing that test (T6)
- Once the suite is green, write `contract: frozen <today>` to the manifest (§Contract and the contract freeze)

**Tests:**
- `covers every D5 type with the shared word` — pure rows (D25)

```ts
it('covers every D5 type with the shared word', () => {
  const rows = searchHomeRows(NOW, daysAgo)
  const titled = [rows.program, rows.lesson, rows.exactPost, rows.orgTemplate, rows.event, rows.photo, rows.video].map((r) => r.title ?? r.name)
  for (const t of titled) expect(t).toContain(SEARCH_HOME_WORD)
  expect(rows.exactPost.title).toBe('Grace')
  expect(rows.untitledPost.title).toBeNull()
  expect(rows.photo.uploadStatus).toBe('ready')
  expect(rows.video.type).toBe('video')
  expect(new Set(rows.series.map((e) => e.recurrenceGroupId)).size).toBe(1)
  expect(rows.lessonEvent.type).toBe('LESSON')
})
```

- `recents are newest-first with fixed ids` — (D25)

```ts
it('recents are newest-first with fixed ids', () => {
  const { recents } = searchHomeRows(NOW, daysAgo)
  expect(recents.map((r) => r.resourceType)).toEqual(['PROGRAM', 'LESSON', 'GROUP', 'PHOTO', 'POST', 'MEMBER'])
  const times = recents.map((r) => r.openedAt.getTime())
  expect(times).toEqual([...times].sort((a, b) => b - a))
  expect(recents[0].id).toBe(fixtureId('recent', 1))
})
```

- `wipe deletes the org's templates` — update the existing exact list in `wipe.test.ts`

```ts
it('deletes in the expected order, templates included', async () => {
  await wipeFixtures(fake)
  expect(calls.map((c) => c.model)).toEqual(['clientEvent', 'member', 'group', 'studyProgram', 'lessonTemplate', 'user'])
  expect(calls[4].args).toEqual({ where: { organizationId: FIXTURE_ORG_ID } })
})
```

- `after reset, grace returns mixed types, exact title first, and recents hydrate` — real service against the seeded database (§Testing walk 1, 2)

```ts
describe.skipIf(!TEST_DB_URL)('search-home fixture', () => {
  it('after reset, grace returns mixed types, exact title first, and recents hydrate', async () => {
    const { searchRanked, listRecentResults } = await import('../../src/services/master-search.js')
    const { parseRankedParams } = await import('../../src/services/master-search-query.js')
    const { items } = await searchRanked(FIXTURE_USER_ID, parseRankedParams({ q: 'grace', limit: '50' }))
    expect(items[0].title).toBe('Grace')
    expect(new Set(items.map((i: any) => i.type)).size).toBeGreaterThanOrEqual(8)
    expect((await listRecentResults(FIXTURE_USER_ID, {})).map((i: any) => i.type)).toEqual(['PROGRAM', 'LESSON', 'GROUP', 'PHOTO', 'POST', 'MEMBER'])
  }, 180_000)

  it('a second reset succeeds with the same ids', async () => {
    const ids = async () => (await db.prisma.searchRecentResult.findMany({ where: { userId: FIXTURE_USER_ID }, orderBy: { id: 'asc' }, select: { id: true } })).map((r) => r.id)
    const first = await ids()
    await db.run('reset', 'full')
    expect(await ids()).toEqual(first)
  }, 180_000)
})
```

- [ ] **Step 1: Write the listed tests, update `wipe.test.ts`**
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/search-home.test.ts fixtures/__tests__/wipe.test.ts`, watch them fail**
- [ ] **Step 3: Implement the layer, kinds and wipe line to the Behaviour**
- [ ] **Step 4: Run the same command and `npx --no-install tsc --noEmit -p fixtures`, then `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree` and `verify.mjs wait <id>` for the database half, and watch them pass; report how long the LESSON arm took on this data (F4)**
- [ ] **Step 5: Write the freeze to the manifest and commit** — `feat(master-search): search-home fixture; contract frozen`

### Task 8: Search domain, models and Actions
App: iphone
Phase: 3
Recipe: `/ios-error-surface`; SPEC §iphone *API*, D20, D22, D24, D26, D36, D42

**Files:**
- Create: `iphone/MakeReady/State/Models/SearchModels.swift` — C1–C5 wire types
- Create: `iphone/MakeReady/State/Actions/SearchActions.swift` — every search API call and state write
- Modify: `iphone/MakeReady/State/AppState.swift:144-199` — the memory-only search domain; `:1045` area `clearInMemory()` empties it
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift:297`, `ProgramActions.swift:453`, `MediaActions.swift:293` — D42's drops
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — explicit entries for each new source and test; then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/SearchModelsTests.swift`, `iphone/MakeReadyCaptureTests/SearchActionsTests.swift`

**Interfaces:**
- Consumes: C1–C5 of SPEC §Contract, as frozen: `GET /api/search/ranked`, `GET`/`PUT /api/search/recent-results`, `DELETE /api/search/recent-results/:type/:id`, `GET /api/search/filter-options`
- Produces: `SearchItem` — `Codable`, `Equatable`, `Identifiable`: `type: String`, `id: String`, `title: String`, `createdAt: String`, `imageUrl: String?`, `parent: SearchItemParent?`, `openedAt: String?`, with `key` = type + ":" + id; `score` is not decoded. `SearchItemParent` — `type`, `id`, `name`. `SearchItemsResponse` — `success`, `items`, `nextCursor: String?`, `error: String?`. `SearchFilterOptions` — `organizations`, `groups`, `leaders`, `tags`, with `SearchFilterOrg`, `SearchFilterGroup`, `SearchFilterLeader`, `SearchFilterTag`. `SearchFilters` — `types`, `orgIds`, `groupIds`, `leaderIds`, `tags`, each `[String]`, `Equatable`, with `queryPairs` returning only the non-empty lists comma-joined. `SearchActions` — `init(api:state:onUnauthorized:)` as `MediaActions.swift:27-46` does; `search(query:filters:) async`, `loadNextPage(query:filters:) async`, `loadRecents(filters:) async`, `loadFilterOptions() async`, `recordOpened(_ item:) async`, `removeRecent(_ item:) async`, `cancelQuery()`. On `AppState`: `searchRecents: [SearchItem]`, `searchResults: [SearchItem]`, `searchNextCursor: String?`, `searchAnsweredQuery: String?`, `searchFilterOptions: SearchFilterOptions?`, `searchPendingRemovals: Set<String>`, and `dropSearchItems(where:)`.

**Behaviour:**
- Recents and results are ordered arrays de-duplicated by `key`, because a ranked list has no key to re-sort by; none of it is added to `PersistedState`; `clearInMemory()` empties it all (D26)
- `q`, `cursor` and each list go through `DashboardActions.queryValue`, because `urlQueryAllowed` keeps `+` (§iphone API)
- C3 goes through `api.request(endpoint:method:"PUT",body:responseType:)`, as `FilterState.swift:78-83` does; C4 through `api.delete` decoding `APISuccessResponse` (D32, §iphone API)
- `type` decodes as a string, so a later type cannot fail a page. `openedAt` is optional (§iphone API)
- `search` takes a new request token; after its await it applies the response only if the token is still current, `!Task.isCancelled`, and `state.initialLoad.isCurrent(generation)`, because a superseded GET still returns success through the coalescer and a late one could refill the next user's state (D42). The same guard wraps every load
- On a first-page success `search` replaces `searchResults` and sets `searchAnsweredQuery` to the trimmed query; until then prior results stay (D20, D41). `loadNextPage` appends, de-duplicated by `key`, and is a no-op with no cursor or a page in flight (D17, D20)
- Failures: a cancellation (`GroupActions.isCancellation`) does nothing; a 401 (`AuthStatusPolicy.shouldSignOut`) runs `onUnauthorized`; anything else `recordError(…, surface: false)`, keeping the rendered state with no error UI, and `searchAnsweredQuery` is left alone, so a failed query never prints no-results (D20, D24, D41). Mark these `// Silent:` per the recipe skill, naming D20 or D24
- `cancelQuery` invalidates the current token, clears `searchResults`, `searchNextCursor` and `searchAnsweredQuery` (D41)
- `recordOpened` moves the item to the top of `searchRecents` at once, then sends C3; a failure logs and moves on, and never blocks opening (D24, D42). It does not touch `searchResults` (D42)
- `removeRecent` splices the row out and adds its `key` to `searchPendingRemovals`; on success removes the key; on failure restores the row at its original index, removes the key, and surfaces (D22, D36):

```swift
state.recordError(error, context: "SearchActions.removeRecent", surface: true,
                  friendlyMessage: "Couldn't remove that search",
                  retry: { Task { await self.removeRecent(item) } })
```

- `loadRecents` merges C2's answer with rows in `searchPendingRemovals` filtered out, so a slow removal cannot bring a row back (D42)
- `forgetGroup`, `forgetProgram` and a successful `deleteMedia` call `dropSearchItems` for that id across recents and results; `forgetProgram` also drops results whose `parent.id` is the program (D42)

**Tests:**
- `decodes C1–C5 with nulls, tolerates an unknown type, ignores score` — (§iphone API)

```swift
func testDecodesItemWithNullsAndUnknownType() throws {
    let json = #"{"success":true,"items":[{"type":"FUTURE","id":"1","title":"T","createdAt":"2026-10-03T12:00:00.000Z","score":2.41,"imageUrl":null,"parent":null}],"nextCursor":null}"#
    let r = try JSONDecoder.apiDecoder.decode(SearchItemsResponse.self, from: Data(json.utf8))
    XCTAssertEqual(r.items[0].type, "FUTURE")
    XCTAssertNil(r.items[0].openedAt)
    XCTAssertNil(r.nextCursor)
}
```

- `testDecodesFilterOptions` — a `null` category and all four arrays (§Contract)

```swift
func testDecodesFilterOptions() throws {
    let json = #"{"success":true,"organizations":[{"id":"o","name":"O"}],"groups":[{"id":"g","name":"G","organizationId":"o"}],"leaders":[{"id":"l","name":"L"}],"tags":[{"tag":"lent","label":"Lent","category":null}]}"#
    let r = try JSONDecoder.apiDecoder.decode(SearchFilterOptions.self, from: Data(json.utf8))
    XCTAssertNil(r.tags[0].category)
    XCTAssertEqual(r.groups[0].organizationId, "o")
}
```

- `testEncodesPlusAmpersandEquals` — (§iphone API)

```swift
func testEncodesPlusAmpersandEquals() async {
    api.stub("GET", "/api/search/ranked?q=%2B1%20a%26b%3Dc", json: page(["a"], next: nil))
    await actions.search(query: "+1 a&b=c", filters: SearchFilters())
    XCTAssertEqual(state.searchResults.map(\.id), ["a"])
}
```

- `testPagesMergeWithoutDuplicates` — (D17, D26)

```swift
func testPagesMergeWithoutDuplicates() async {
    api.stub("GET", "/api/search/ranked?q=gr", json: page(["a", "b"], next: "c1"))
    api.stub("GET", "/api/search/ranked?q=gr&cursor=c1", json: page(["b", "c"], next: nil))
    await actions.search(query: "gr", filters: SearchFilters())
    await actions.loadNextPage(query: "gr", filters: SearchFilters())
    XCTAssertEqual(state.searchResults.map(\.id), ["a", "b", "c"])
    XCTAssertNil(state.searchNextCursor)
}
```

- `testStaleResponseIsDropped` — through the stub's `responseFor` barrier; `AsyncGate` is a small actor local to this test file (D20, D42)

```swift
func testStaleResponseIsDropped() async {
    let gate = AsyncGate()
    api.responseFor = { _, endpoint in
        if endpoint.contains("q=old") { await gate.wait(); return Data(self.page(["old"], next: nil).utf8) }
        return Data(self.page(["new"], next: nil).utf8)
    }
    let first = Task { await actions.search(query: "old", filters: SearchFilters()) }
    await Task.yield()
    await actions.search(query: "new", filters: SearchFilters())
    await gate.open(); await first.value
    XCTAssertEqual(state.searchResults.map(\.id), ["new"])
    XCTAssertEqual(state.searchAnsweredQuery, "new")
}
```

- `testFailureLeavesTheQueryUnanswered` — (D20, D41)

```swift
func testFailureLeavesTheQueryUnanswered() async {
    state.searchResults = [item("a")]
    api.errorToThrow = APIError.serverError("boom")
    await actions.search(query: "gr", filters: SearchFilters())
    XCTAssertEqual(state.searchResults.map(\.id), ["a"])
    XCTAssertNil(state.searchAnsweredQuery)
    XCTAssertFalse(state.errors.contains { $0.surface })
}
```

- `testCancelQueryClearsAndIgnoresALateResponse` — (D41)

```swift
func testCancelQueryClearsAndIgnoresALateResponse() async {
    let gate = AsyncGate()
    api.responseFor = { _, _ in await gate.wait(); return Data(self.page(["late"], next: nil).utf8) }
    let t = Task { await actions.search(query: "gr", filters: SearchFilters()) }
    await Task.yield()
    actions.cancelQuery()
    await gate.open(); await t.value
    XCTAssertTrue(state.searchResults.isEmpty)
    XCTAssertNil(state.searchAnsweredQuery)
}
```

- `testResponseAfterSignOutIsIgnored` — (D42)

```swift
func testResponseAfterSignOutIsIgnored() async {
    api.beforeReturn = { [state] _, _ in state!.clearAllData() }
    api.stub("GET", "/api/search/recent-results", json: page(["a"], next: nil))
    await actions.loadRecents(filters: SearchFilters())
    XCTAssertTrue(state.searchRecents.isEmpty)
}
```

- `testClearAllDataEmptiesTheDomain` — (D26)

```swift
func testClearAllDataEmptiesTheDomain() {
    state.searchRecents = [item("a")]; state.searchResults = [item("b")]; state.searchAnsweredQuery = "gr"
    state.clearAllData()
    XCTAssertTrue(state.searchRecents.isEmpty && state.searchResults.isEmpty)
    XCTAssertNil(state.searchAnsweredQuery)
}
```

- `testRecordOpenedMovesToTopAndSendsPut` — body checked; a failure is silent (D24, D42)

```swift
func testRecordOpenedMovesToTopAndSendsPut() async {
    state.searchRecents = [item("a"), item("b")]
    api.stub("PUT", "/api/search/recent-results", json: #"{"success":true}"#)
    await actions.recordOpened(item("b"))
    XCTAssertEqual(state.searchRecents.map(\.id), ["b", "a"])
    XCTAssertEqual(api.calls.last?.method, "PUT")
    XCTAssertEqual(api.calls.last?.body?["id"] as? String, "b")
    XCTAssertEqual(api.calls.last?.body?["type"] as? String, "GROUP")
}
```

- `testFailedRemovalRestoresInPlaceAndSurfacesWithRetry` — (D22, D36)

```swift
func testFailedRemovalRestoresInPlaceAndSurfacesWithRetry() async {
    state.searchRecents = [item("a"), item("b"), item("c")]
    api.errorToThrow = APIError.serverError("boom")
    await actions.removeRecent(item("b"))
    XCTAssertEqual(state.searchRecents.map(\.id), ["a", "b", "c"])
    XCTAssertTrue(state.searchPendingRemovals.isEmpty)
    XCTAssertEqual(state.errors.last?.message, "Couldn't remove that search")
    XCTAssertEqual(state.errors.last?.surface, true)
    XCTAssertNotNil(state.errors.last?.retry)
}
```

- `testRecentsMergeSkipsAPendingRemoval` — (D42)

```swift
func testRecentsMergeSkipsAPendingRemoval() async {
    state.searchPendingRemovals = [item("a").key]
    api.stub("GET", "/api/search/recent-results", json: page(["a", "b"], next: nil))
    await actions.loadRecents(filters: SearchFilters())
    XCTAssertEqual(state.searchRecents.map(\.id), ["b"])
}
```

- `testEachUnauthorizedSignsOut` — every call (§iphone Errors)

```swift
func testEachUnauthorizedSignsOut() async {
    api.errorToThrow = APIError.unauthorized
    await actions.search(query: "gr", filters: SearchFilters())
    await actions.loadRecents(filters: SearchFilters())
    await actions.loadFilterOptions()
    await actions.recordOpened(item("a"))
    await actions.removeRecent(item("a"))
    XCTAssertEqual(signOuts, 5)
}
```

- `testForgetDropsMatchingRows` — one test per forget path (D42)

```swift
func testForgetDropsMatchingRows() {
    state.searchRecents = [item("g1", type: "GROUP"), item("a")]
    GroupActions(state: state).forgetGroup(id: "g1")
    XCTAssertEqual(state.searchRecents.map(\.id), ["a"])
    state.searchResults = [item("l1", type: "LESSON", parent: "p1"), item("p1", type: "PROGRAM")]
    ProgramActions(state: state).forgetProgram(id: "p1")
    XCTAssertTrue(state.searchResults.isEmpty)
}
```

- [ ] **Step 1: Write the listed tests, add the pbxproj entries, run `ruby iphone/scripts/capture-targets.rb`**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (XCTest runs on the verifier's own simulator; never launch one yourself)
- [ ] **Step 3: Implement the models, the domain and `SearchActions` to the Behaviour**
- [ ] **Step 4: Run `ruby iphone/scripts/capture-targets.rb --check`, `cd iphone && swiftlint` on the new files, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): iPhone search domain and actions`

### Task 9: queryAnswered input and member days from another org
App: iphone
Phase: 3
Recipe: `/ios-error-surface`; SPEC D41, §iphone *Member days*, *d2m views*

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Search/SearchHomeScreen.swift:29-52,103-130` — the one d2m file this task may touch, under d2m ticket `cmw1bjpj70001v0dwuy22fmf1`, lane `fast`, kind `input-added-with-default`
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift` or `CaptureFixture.swift` — only if the new field needs it to decode; both are on the ticket's file list
- Modify: `iphone/MakeReady/State/Actions/MemberActions.swift:91-99` — omit a foreign org
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift:147-151` — load the detail before the days
- Test: `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`

**Interfaces:**
- Produces: `SearchHomeScreen.State.queryAnswered` — `Bool`, default `true`. Every existing initializer and fixture keeps compiling.

**Behaviour:**
- Add the field last in `State`, with its default, so a capture of any existing state renders as before (D41, d2m rule R-07). A d2m view ships no automated test (d2m rule R-20), so the screen change is proved through the build and Task 10's mapper test
- The screen's branch becomes exactly this; with no rows and no answer it keeps showing what it showed before the query (D41, design §3 states 5 and 6):

```swift
if isQuerying && (!state.resultTitles.isEmpty || state.queryAnswered) {
    queryContent
} else if !state.recentTitles.isEmpty {
    recentSection
}
```

- `loadMemberDays` omits `organizationId` when `state.memberDetails[id]` is loaded and its `organizations` has no row whose `organizationId` is the active org, so a member from a second org opens with its days; a member with no loaded detail sends it as today (§iphone Member days)
- `MemberProfileContainer.load` awaits `loadMember` first, then runs groups, engagement and days together, because a cold open from search would otherwise read no detail (§iphone Member days)
- 🔴 The implementer has no d2m tool. Put the commit sha and `changeId cmw1bjpj70001v0dwuy22fmf1` under *concerns* in the report: the coordinator calls `report_project_change` with them and the summary `SearchHomeScreen.State gains queryAnswered: Bool = true; the no-results line shows only when it is true, otherwise the screen keeps the last render (master-search D41).`

**Tests:**
- `testMemberDaysOmitsAForeignOrg` — and keeps the active one (§iphone Member days)

```swift
func testMemberDaysOmitsAForeignOrg() async {
    state.organizationId = "o1"
    state.memberDetails.upsert(memberDetail("m1", orgIds: ["o2"]))
    api.responseFor = { _, _ in Data(#"{"success":true,"days":[]}"#.utf8) }
    await actions.loadMemberDays("m1")
    XCTAssertFalse(api.calls.last!.endpoint.contains("organizationId"))
    state.memberDetails.upsert(memberDetail("m2", orgIds: ["o1"]))
    await actions.loadMemberDays("m2")
    XCTAssertTrue(api.calls.last!.endpoint.contains("organizationId=o1"))
}
```

- [ ] **Step 1: Write the listed test** — in `MemberActionsTests.swift`
- [ ] **Step 2: Request a focused verifier run and watch it fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Make the screen change and the `loadMemberDays` change to the Behaviour**
- [ ] **Step 4: Run the same verifier request and watch it pass, with the app target compiling**
- [ ] **Step 5: Commit** — `feat(master-search): queryAnswered input; member days without a foreign org`, then report the sha and `changeId` as above

### Task 10: SearchHomeMapper and SearchHomeContainer
App: iphone
Phase: 4
Recipe: `/ios-error-surface`; `/present-overlay`; SPEC §iphone, D9, D14, D20, D21, D26, D27, D41

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Search/SearchHomeMapper.swift` — pure: items to `State`, labels, tag sections, routing
- Create: `iphone/MakeReady/UI2/Containers/Search/SearchHomeContainer.swift` — renders the d2m screen, debounce, picks, presentations
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-68` — add `case mediaHome` and `case programsHome`, not full-screen, so the TabBar stays (§iphone Pushed pages)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:188-217` — `page(for:)` stays exhaustive; both cases render a placeholder `EmptyPage()` until Task 11
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — explicit entries; then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/SearchHomeMapperTests.swift`

**Interfaces:**
- Consumes: `SearchItem`, `SearchFilters`, `SearchFilterOptions`, `SearchActions` and the `AppState` search domain from `SearchActions.swift`/`SearchModels.swift`; `SearchHomeScreen.State.queryAnswered`; `HomeDashboardMapper.createdLabel`; `FilterMenuOverlay.chipLabel`; `MediaHomeMapper.tagSections` as the shape to follow
- Produces: `SearchHomeMapper.Selection` — picked ids per chip, `Equatable`. `SearchHomeMapper.output(recents:results:query:answeredQuery:selection:options:tz:)` — returns `state: SearchHomeScreen.State`, `recentItems`, `resultItems` (only rows of a known type). `SearchHomeMapper.filters(_ selection:)` — returns `SearchFilters`. `SearchHomeMapper.exit(for item:)` — returns `SearchHomeExit`: `.push(UI2Destination)` or `.viewer(url: String, title: String)`. `SearchHomeMapper.typeOptions`, `SearchHomeMapper.tagSections(options:)`.

**Behaviour:**
- Kind map: PROGRAM, TEMPLATE → `program`; MEMBER → `member`; GROUP → `group`; LESSON → `lesson`; EVENT → `event`; POST → `post`; VIDEO → `media`; PHOTO → `photo`. An unknown type is dropped by the mapper (D21, §iphone API)
- Description is `HomeDashboardMapper.createdLabel(createdAt, tz:)` (D21)
- Type chip options, in order: Programs, Members, Groups, Lessons, Events, Posts, Videos, Photos; Programs sends PROGRAM and TEMPLATE (D5, design §3)
- Chip labels through `FilterMenuOverlay.chipLabel`, resting `Type`, `Orgs`, `Groups`, `Leaders`, `Tags`, nouns `types`, `orgs`, `groups`, `leaders`, `tags`; a chip with picks is in `activeFilters` (design §3)
- Tag sections keep C5's order: one section per `category` in first-seen order, then one untitled section for null categories (D14, D31)
- `queryAnswered` is `answeredQuery == query` trimmed (D41)
- Exits (D9, D27):

```
PROGRAM  .push(.studyProgramHome(id, title))
TEMPLATE .push(.programsHome)
MEMBER   .push(.memberDetail(id, title))
GROUP    .push(.groupDetail(id, title))
LESSON   .push(.studyProgramHome(parent.id, parent.name))
EVENT    .push(.groupDetail(parent.id, parent.name))
POST     .push(.groupDetail(parent.id, parent.name))
VIDEO    .push(.mediaHome)
PHOTO    .viewer(imageUrl, title)
```

- Container: query and picks are `@State`; the store lives in `AppState` (D20, D26). No `APIClient` here (global constraint)
- Typing: at 2+ trimmed characters, cancel the pending task and start a `Task` that `Task.sleep`s 300 ms, then calls `search`, as `GroupsHomeContainer.swift:41-50` does. Below 2 trimmed characters, including the field's ✕: cancel the debounce, call `cancelQuery()`, and refetch C2 if picks changed since its last load (D20, D41)
- A pick change with a live query reruns `search` at once and refreshes C2; prior rows stay until the response (D6, D20)
- `onResultAppear(index)` calls `loadNextPage` only when `index >= resultItems.count - 5`. F11 risk: rows sit in an eager `VStack` inside the lazy stack, so every row may fire at once. Log `onResultAppear` over 40 rows in the build; if it chains through every page, report it as a concern, because the fix moves rows into the lazy stack through d2m's channel (F11)
- Row taps: `recordOpened` runs in its own `Task`, and the exit fires without waiting for it (D24, design §3). Row lookup is `output.resultItems[index]`, computed in `body`, never a stored copy, as `GroupsHomeContainer.swift` does (§iphone Row lookup)
- `.task`: `loadRecents` and `loadFilterOptions`, without `loadInitialData()`; `onAppear` of the root reloads C2 so C3 shows on return; results clear on unmount because the tab unmounts and the query goes with it (D26, D42, §iphone API)
- Chips present `.filterMenuPresentation` with the list form, `.multiple`, draft mode, and the Tags chip with the tag-flow form; a photo presents `.imageViewerPresentation` with `ImageViewer(url:sourceFrame:nil,…)`, the one-image init; pattern `MediaHomeContainer.swift:167-192` (R2, R3, §iphone Photo row)
- The container's `onUnauthorized` signs out through the auth manager, as `MediaHomeContainer.swift:347-354` does (§iphone Errors)

**Tests:**
- `testKindMapDropsUnknownTypes` — (D21)

```swift
func testKindMapDropsUnknownTypes() {
    let types = ["PROGRAM","TEMPLATE","MEMBER","GROUP","LESSON","EVENT","POST","VIDEO","PHOTO","FUTURE"]
    let out = output(results: types.map { item($0, type: $0) }, query: "gr", answered: "gr")
    XCTAssertEqual(out.state.resultKinds, ["program","program","member","group","lesson","event","post","media","photo"])
    XCTAssertEqual(out.resultItems.count, 9)
}
```

- `testExitsForEveryType` — the routing table, TEMPLATE included (D9, D27)

```swift
func testExitsForEveryType() {
    let parent = SearchItemParent(type: "PROGRAM", id: "p", name: "Romans")
    XCTAssertEqual(SearchHomeMapper.exit(for: item("t", type: "TEMPLATE")), .push(.programsHome))
    XCTAssertEqual(SearchHomeMapper.exit(for: item("l", type: "LESSON", parent: parent)), .push(.studyProgramHome(id: "p", name: "Romans")))
    XCTAssertEqual(SearchHomeMapper.exit(for: item("v", type: "VIDEO")), .push(.mediaHome))
    XCTAssertEqual(SearchHomeMapper.exit(for: item("m", type: "MEMBER", title: "Ann")), .push(.memberDetail(id: "m", name: "Ann")))
    XCTAssertEqual(SearchHomeMapper.exit(for: item("g", type: "GROUP", title: "G")), .push(.groupDetail(id: "g", name: "G")))
    XCTAssertEqual(SearchHomeMapper.exit(for: item("ph", type: "PHOTO", title: "P", imageUrl: "https://i")), .viewer(url: "https://i", title: "P"))
}
```

- `testChipLabels` — rest, one, several, and `activeFilters` (design §3)

```swift
func testChipLabels() {
    var sel = SearchHomeMapper.Selection()
    XCTAssertEqual(output(selection: sel).state.typeFilterLabel, "Type")
    sel.orgIds = ["o1"]
    XCTAssertEqual(output(selection: sel).state.orgFilterLabel, "Org One")
    sel.groupIds = ["g1", "g2"]
    let out = output(selection: sel)
    XCTAssertEqual(out.state.groupFilterLabel, "2 groups")
    XCTAssertEqual(Set(out.state.activeFilters), ["orgs", "groups"])
}
```

- `testProgramsChipSendsBothTypes` — (D5)

```swift
func testProgramsChipSendsBothTypes() {
    var sel = SearchHomeMapper.Selection()
    sel.typeIds = ["programs", "photos"]
    XCTAssertEqual(Set(SearchHomeMapper.filters(sel).types), ["PROGRAM", "TEMPLATE", "PHOTO"])
}
```

- `testTagSectionsKeepC5Order` — (D14, D31)

```swift
func testTagSectionsKeepC5Order() {
    let tags = [tag("1 samuel", "1 Samuel", "Books"), tag("mark", "Mark", "Books"), tag("lent", "Lent", nil)]
    let sections = SearchHomeMapper.tagSections(options: options(tags: tags))
    XCTAssertEqual(sections.map(\.title), ["Books", nil])
    XCTAssertEqual(sections[0].options.map(\.label), ["1 Samuel", "Mark"])
}
```

- `testNoResultsHeldUntilAnswered` — the screen's input; a stale answer for another query is not an answer (D41)

```swift
func testNoResultsHeldUntilAnswered() {
    XCTAssertFalse(output(results: [], query: "gra", answered: nil).state.queryAnswered)
    XCTAssertFalse(output(results: [], query: "gra", answered: "gr").state.queryAnswered)
    XCTAssertTrue(output(results: [], query: " gra ", answered: "gra").state.queryAnswered)
}
```

- `testDescriptionIsCreatedDate` — (D21)

```swift
func testDescriptionIsCreatedDate() {
    let out = output(results: [item("a", createdAt: "2026-10-03T12:00:00.000Z")], query: "gr", answered: "gr")
    XCTAssertEqual(out.state.resultDescriptions, ["Created Oct 3, 2026"])
}
```

- [ ] **Step 1: Write the listed tests, add the pbxproj entries, run `ruby iphone/scripts/capture-targets.rb`**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the mapper, the two destination cases and the container to the Behaviour**
- [ ] **Step 4: Run `ruby iphone/scripts/capture-targets.rb --check`, `cd iphone && swiftlint` on the new files, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): search-home mapper and container`

### Task 11: Pushed Media and Programs pages
App: iphone
Phase: 4
Recipe: `/push-page`; `/nav-route`; SPEC §iphone *Pushed pages*, D9, D27, F6, F12

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:17-21,95-99,505-509` — add `Mode.pushed`
- Create: `iphone/MakeReady/UI2/Containers/Programs/ProgramsHomeHost.swift` — the small pushed host
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:188-217` — `.mediaHome` and `.programsHome` render their real pages
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — explicit entry; then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MediaHomeContainerTests.swift`, `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`

**Interfaces:**
- Consumes: `UI2Destination.mediaHome`, `UI2Destination.programsHome`; `UI2Navigator`; `ui2PushedPageFill()`; `pullDownRefresh`; `StudyProgramsContainer.refresh`
- Produces: `MediaHomeContainer.Mode.pushed`; `ProgramsHomeHost`

**Behaviour:**
- `.pushed` draws `PageHeader` with a back button, turns the viewer on, offers no upload, and measures the grid below the header (§iphone Pushed pages, D9)
- `.pushed` hides TopNav-related preference as `.pick` does, because a pushed page has no TopNav (§iphone Pushed pages)
- `ProgramsHomeHost` is `PageHeader` + `ScrollView` + `.pullDownRefresh` + `.ui2PushedPageFill()` around `StudyProgramsContainer`, because that container relies on the shell's scroll (§iphone Pushed pages, D27)
- Both keep the TabBar: neither case joins `isFullScreen` (§iphone Pushed pages)
- F12 risk: `fetchPrograms` calls `replaceAll`, so a program opened by id but missing from the list could lose its store row while open (`ProgramActions.swift:95`). Compare `GET /api/programs` scope with D38 and the same for groups. If a row searchable under D38 can be absent from the list and the page breaks, report it as a concern with the case; do not widen a server scope (F12)
- F6 stands: the Media grid shows photos only, so the video exit opens a page that does not show the tapped video; the owner's D9 accepts it and no filter is changed (F6)

**Tests:**
- `testPushedModeOffersNoUploadAndShowsViewer` — the mode's closed behaviour, through the container's static helpers as `MediaHomeContainerTests` does (§iphone Pushed pages)

```swift
func testPushedModeOffersNoUploadAndShowsViewer() {
    XCTAssertFalse(MediaHomeContainer.allowsUpload(.pushed))
    XCTAssertTrue(MediaHomeContainer.opensViewer(.pushed))
    XCTAssertTrue(MediaHomeContainer.drawsHeader(.pushed))
    XCTAssertFalse(MediaHomeContainer.drawsHeader(.browse))
}
```

- `testExitDestinationsKeepTheTabBar` — (§iphone Pushed pages)

```swift
func testExitDestinationsKeepTheTabBar() {
    XCTAssertFalse(UI2Destination.mediaHome.isFullScreen)
    XCTAssertFalse(UI2Destination.programsHome.isFullScreen)
}
```

- [ ] **Step 1: Write the listed tests, add the pbxproj entry, run `ruby iphone/scripts/capture-targets.rb`**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `Mode.pushed`, `ProgramsHomeHost` and the shell cases to the Behaviour**
- [ ] **Step 4: Run `ruby iphone/scripts/capture-targets.rb --check`, `cd iphone && swiftlint` on the changed files, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(master-search): pushed Media and Programs pages`

### Task 12: Repoint the Search tab root
App: iphone
Phase: 4
Recipe: `/push-page`; SPEC §Findings R1, §iphone *Root scroll*

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:183` — the R1 root switch; `:57` the stale comment
- Modify: `iphone/MakeReady/UI2/Containers/Search/SearchHomeContainer.swift` — the root scroll
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`

**Interfaces:**
- Consumes: `SearchHomeContainer`
- Produces: `UI2Shell.rootPage(for:)` — a static helper naming the page each tab's root renders, so a test can read it

**Behaviour:**
- `.search` renders `SearchHomeContainer()`; `.calendar` stays `EmptyPage()`; the two split into their own cases (R1, §iphone Root scroll)
- The `:57` comment `any other tab mounts while selected (none pushes yet)` is corrected, because Search now pushes (T9)
- The container adds the `ScrollView` the screen lacks, with `.scrollDismissesKeyboard(.interactively)`, `.scrollBounceBehavior(.always, axes: .vertical)` and `HomeSectionLayout.swift:72-74`'s status-bar strip, and no extra top padding, because `.underScreenHeader` already gives safe area + 16 (§iphone Root scroll)
- Residual sweep: `grep -rn 'case .calendar, .search' iphone/MakeReady` is zero hits (R1)
- No deep link or notification targets Search, so no other site repoints (R1)

**Tests:**
- `testSearchTabRendersSearchAndCalendarStaysEmpty` — (R1)

```swift
func testSearchTabRendersSearchAndCalendarStaysEmpty() {
    XCTAssertEqual(UI2Shell.rootPage(for: .search), .search)
    XCTAssertEqual(UI2Shell.rootPage(for: .calendar), .empty)
}
```

- [ ] **Step 1: Write the listed test** — in `UI2ShellModelTests.swift`
- [ ] **Step 2: Request a focused verifier run and watch it fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Split the switch, add the root scroll, fix the comment to the Behaviour**
- [ ] **Step 4: Run the residual grep, `cd iphone && swiftlint` on the changed files, then the same verifier request, and watch it pass**
- [ ] **Step 5: Commit** — `feat(master-search): Search tab renders the ranked search screen`
