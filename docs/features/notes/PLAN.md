# notes — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** leader notes on iPhone: the server stores titled, searchable `NOTE`s with a conflict flag and a context label, and the iPhone gets the markdown codec, autosave with an offline queue, `AppState.studyNotes`, and the wiring of d2m's `library-home` notes list and `note-editor` screen.

**Architecture:** server first: schema, service-derived title/preview, the validated list, 404-scoped `:noteId` routes with D23's locked `stomped`, `contextLabel`, backfill, fixture; its last task freezes §Contract. Then the iPhone against the frozen contract: models + store + `NoteActions`; queue + autosave; then, gated on d2m's views being on this branch, the codec and the two containers. The iPhone writes no view: `iphone/MakeReadyUI/` is d2m's (D1).

**Tech Stack:** server: Express, Prisma/Atlas (schema YAML), zod, vitest + supertest. iphone: Swift 5 / SwiftUI iOS 17+, `@Observable` + Actions, `EntityStore`, Apple `swift-markdown` (new SPM package), `NWPathMonitor`, XCTest (`MakeReadyCaptureTests`).

**Spec:** `docs/features/notes/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(notes): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–4 | `title`/`preview` columns + `[userId, updatedAt]` index; title/preview derived on every write; `NOTE` type; the validated list query (`q`, `orderBy`, bounds); 404-scoped `:noteId` routes with the strict PATCH and D23's locked `stomped` |
| 2 | server | 5–7 | `contextLabel` on every leader note response; the idempotent backfill; the `library-home` fixture and the §Contract request suite; **§Contract freezes** |
| 3 | iphone | 8–9 | `StudyNote` wire models, D3 sectioning, `AppState.studyNotes` (disk-capped) and `NoteActions` |
| 4 | iphone | 10–11 | the per-environment `NoteSaveQueue` with its connectivity flush, and `NoteAutosaveController` (lazy create, 1.5 s debounce, empty-delete, `stomped`) |
| 5 | iphone | 12–14 | 🔴 starts only once d2m's notes views are on this branch (F1/F5). `swift-markdown` + `NoteDocumentCodec`; `LibraryHomeContainer` notes list; `NoteEditorContainer` + the three D17 routes + launch flush |

---

### Task 1: `StudyNote.title`, `preview` and the `[userId, updatedAt]` index
App: server
Phase: 1
Recipe: /api · tiny

**Files:**
- Modify: `server/schema/schema.yaml:3374-3428` — StudyNote gains `title` and `preview` (`type: string`, `nullable: true`) after `content`, and the index `- fields: [userId, updatedAt]`
- Modify (generated, never by hand): `server/prisma/schema.prisma`, `server/atlas/.schema.hcl` — by `npm run schema:generate`
- Create (generated): `server/atlas/migrations/<timestamp>_note_title_preview.sql` + `atlas.sum` — by Atlas `migrate diff`
- Test: `server/test/notes-schema.test.ts` — the new columns' defaults

**Interfaces:**
- Produces: `StudyNote.title` and `StudyNote.preview` (nullable strings) on every Prisma note row; index `[userId, updatedAt]` (SC1, SC2, SC9)

**Behaviour:**
- both columns are nullable with no default, so no migration-time backfill (Data plan; SC1, SC2)
- the migration is additive only: exactly two `ADD COLUMN … NULL` on `study_notes` and one `CREATE INDEX` on `("userId", "updatedAt")`; nothing else (Data plan; SC9)

**Tests:**
- `a new note row has null title and preview` (SC1, SC2)

```ts
it('a new note row has null title and preview', async () => {
  const user = await prisma.user.create({ data: { email: `ns-${Date.now()}@t.test`, name: 'ns' } })
  const note = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: 'x' } })
  expect(note).toMatchObject({ title: null, preview: null })
  await prisma.user.delete({ where: { id: user.id } })
})
```

- `the user/updatedAt index exists` (SC9)

```ts
it('the user/updatedAt index exists', async () => {
  const rows = await prisma.$queryRaw<{ indexdef: string }[]>`SELECT indexdef FROM pg_indexes WHERE tablename = 'study_notes'`
  expect(rows.some((r) => /\("userId", "updatedAt"\)/.test(r.indexdef))).toBe(true)
})
```

> ⚠ environment: `npm run schema:diff` reads the `server/.env` 1Password pipe via `dotenv`. Run `npm run schema:generate`, then `cd server/atlas && ../scripts/atlas.sh migrate diff note_title_preview --env local --var database_url=postgresql://postgres:postgres@localhost:5434/postgres`. Never open `server/.env`.

- [ ] **Step 1: Write the listed tests; run `cd server && npx vitest run test/notes-schema.test.ts`, watch them fail**: `title` not in the row
- [ ] **Step 2:** Edit the YAML; `npm run schema:validate`; generate the migration as the note says; confirm the SQL is the Behaviour's three statements only; `npx prisma generate`
- [ ] **Step 3: Run them, watch them pass**; `npx tsc --noEmit` clean
- [ ] **Step 4: Commit**: `feat(notes): StudyNote title, preview and user/updatedAt index`

### Task 2: title/preview derivation on every write, and `NOTE_TYPES.NOTE`
App: server
Phase: 1
Recipe: /api

**Files:**
- Create: `server/src/services/note-title.ts` — the pure markdown-line stripper and `deriveTitlePreview`
- Modify: `server/src/services/notes.service.ts:36-44` — `NOTE: 'NOTE'` in `NOTE_TYPES`
- Modify: `server/src/services/notes.service.ts:208-258` (`createNote`) and `:536-555` (`updateNote`) — write `title` and `preview` from `deriveTitlePreview(content)` in the same `create`/`update` call
- Test: `server/src/services/__tests__/note-title.test.ts` — the pure cases
- Test: `server/test/notes-title-writes.test.ts` — the leader POST and the member service writes (real DB)

**Interfaces:**
- Consumes: `StudyNote.title`, `StudyNote.preview` (Task 1)
- Produces: `deriveTitlePreview` takes the note's markdown content and returns `{ title: string | null; preview: string | null }`; `stripMarkdownLine` takes one line and returns it stripped and trimmed; `NOTE_TYPES.NOTE` = `'NOTE'`

**Behaviour:**
- title = first line non-empty after stripping; preview = the next such line; either is `null` when there is none (D11)
- stripping, per line, in this order: drop one leading `#{1,6} `, `- `, `* `, `+ `, `\d+\. ` or `> `; remove `**`, `__`, `~~`, `==`, `<u>`, `</u>`, then paired single `*` and paired single `_`; unescape `\X` → `X`; trim (D11)
- each is cut to 120 code points with `Array.from(s).slice(0, 120).join('')`, never splitting a surrogate pair (D11)
- `createNote` and `updateNote` are the only writers of `content`, and both write title/preview for leader and member notes alike (D11; §Apps blast radius)
- `NOTE_TYPES.NOTE` exists; `type` validation is unchanged (`z.string().min(1)`) (D6, SC3)

**Tests:**
- `title is the first stripped line and preview the next` (D11)

```ts
it('title is the first stripped line and preview the next', () => {
  expect(deriveTitlePreview('# Hello **world**\n\nSecond *line*\nthird')).toEqual({ title: 'Hello world', preview: 'Second line' })
  expect(deriveTitlePreview(' \n\n ')).toEqual({ title: null, preview: null })
})
```

- `blank and markup-only lines are skipped, list markers dropped` (D11)

```ts
it('blank and markup-only lines are skipped, list markers dropped', () => {
  expect(deriveTitlePreview('\n\n**\n- one\n\n1. two')).toEqual({ title: 'one', preview: 'two' })
})
```

- `underline, strike, highlight markers removed and escapes undone` (D11)

```ts
it('underline, strike, highlight markers removed and escapes undone', () => {
  expect(deriveTitlePreview('<u>a</u> ~~b~~ ==c==\nPrice \\*not\\* bold')).toEqual({ title: 'a b c', preview: 'Price *not* bold' })
})
```

- `the cut is 120 code points and never splits a surrogate pair` (D11)

```ts
it('the cut is 120 code points and never splits a surrogate pair', () => {
  const { title } = deriveTitlePreview('😀'.repeat(130))
  expect(Array.from(title!)).toHaveLength(120)
  expect(title).toBe('😀'.repeat(120))
})
```

- `the leader POST stores title and preview` (D11, D6)

```ts
it('the leader POST stores title and preview', async () => {
  const r = await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: NOTE_TYPES.NOTE, content: '# Walk\nPsalm 23 thoughts' })
  expect(r.status).toBe(201)
  expect(r.body.data).toMatchObject({ type: 'NOTE', title: 'Walk', preview: 'Psalm 23 thoughts' })
})
```

- `member notes get title and preview on create and update` (D11)

```ts
it('member notes get title and preview on create and update', async () => {
  const c = await createNote({ memberId, type: 'JOURNAL', content: 'First\nSecond' })
  expect(c.data).toMatchObject({ title: 'First', preview: 'Second' })
  const u = await updateNote(c.data!.id, 'New top\n\nNew next')
  expect(u.data).toMatchObject({ title: 'New top', preview: 'New next' })
})
```

- [ ] **Step 1: Write the listed tests**: the DB file uses `createContentWorld`/`destroyContentWorld` and a created `Member` as `server/test/text-activity-readers.test.ts:23-36` does
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/note-title.test.ts test/notes-title-writes.test.ts`, watch them fail**: `deriveTitlePreview` is not exported
- [ ] **Step 3:** Implement `note-title.ts` to the Behaviour; add `NOTE`; call it in `createNote`/`updateNote`; `docker restart makeready-server`
- [ ] **Step 4: Run them, watch them pass**; `npx tsc --noEmit` clean
- [ ] **Step 5: Commit**: `feat(notes): derive note title and preview on every write`

### Task 3: the validated leader list query: `q`, `orderBy`, bounds
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/src/services/notes.service.ts:96-110` (`GetNotesOptions`) and `:261-318` (`getNotes`) — `q` and `orderBy`
- Modify: `server/src/routes/notes.ts:1328-1385` (leader `GET /notes`) — a `listNotesQuerySchema` replaces the raw `parseInt`s; the pagination envelope uses the parsed values
- Test: `server/test/notes-list-query.test.ts` — real DB through supertest

**Interfaces:**
- Consumes: `NOTE_TYPES.NOTE` (Task 2)
- Produces: `GetNotesOptions.q` (optional string) and `GetNotesOptions.orderBy` (`'createdAt' | 'updatedAt'`, default `'createdAt'`); `listNotesQuerySchema` (route-local zod)
- Produces (wire, §Contract `GET /api/notes`): `200 { success: true, data: Note[], pagination: { total, limit, offset, hasMore } }`, `hasMore = total > offset + limit`; 400 `{ success: false, error: 'Invalid query', details }`

**Behaviour:**
- `limit` int 1–100 default 50; `offset` int ≥ 0 default 0; `orderBy` ∈ {`createdAt`, `updatedAt`} default `createdAt`; `q` string ≤ 200 chars; any bad value → 400 (D25)
- `startDate`/`endDate` stay optional (`z.coerce.date()`, an invalid date → 400); `type`, `linkType`, `linkRefId` optional strings; unknown keys ignored (§Contract "existing params")
- `q`, trimmed and non-empty, filters `content` with `{ contains: q, mode: 'insensitive' }`; an empty `q` is no filter (D8)
- order is `[{ [orderBy]: 'desc' }, { id: 'desc' }]` (D25, SC6)
- the list is always the session user's own active notes (D6)

**Tests:**
- `q matches case-insensitively, only the caller's NOTEs` (D8, D6)

```ts
it('q matches case-insensitively and only the caller\'s notes', async () => {
  await post(w.leader, 'Morning GRACE here'); await post(w.leader, 'nothing'); await post(w.outsider, 'grace too')
  await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: 'JOURNAL', content: 'grace journal' })
  const r = await list(w.leader, '?type=NOTE&q=grace')
  expect(r.status).toBe(200)
  expect(r.body.data.map((n: any) => n.content)).toEqual(['Morning GRACE here'])
})
```

- `orderBy=updatedAt puts the last-edited first; the default stays createdAt` (SC6)

```ts
it('orderBy=updatedAt puts the last-edited first; the default stays createdAt', async () => {
  const a = await post(w.leader, 'order-a'); const b = await post(w.leader, 'order-b')
  await request(app).patch(`/api/notes/${a}`).set('Authorization', bearer(w.leader.token)).send({ content: 'order-a edited' })
  const byUpdated = await list(w.leader, '?type=NOTE&q=order-&orderBy=updatedAt')
  expect(byUpdated.body.data.map((n: any) => n.id)).toEqual([a, b])
  const byCreated = await list(w.leader, '?type=NOTE&q=order-')
  expect(byCreated.body.data.map((n: any) => n.id)).toEqual([b, a])
})
```

- `bad bounds are 400` (D25)

```ts
it.each(['limit=101', 'limit=0', 'limit=abc', 'offset=-1', 'orderBy=title', `q=${'x'.repeat(201)}`, 'startDate=notadate'])('%s is 400', async (qs) => {
  const r = await list(w.leader, `?${qs}`)
  expect(r.status).toBe(400)
  expect(r.body.success).toBe(false)
})
```

- `pagination pages with hasMore` (§Contract)

```ts
it('pagination pages with hasMore', async () => {
  for (const c of ['pg-1', 'pg-2', 'pg-3']) await post(w.leader, c)
  const p1 = await list(w.leader, '?type=NOTE&q=pg-&limit=2')
  expect(p1.body.pagination).toEqual({ total: 3, limit: 2, offset: 0, hasMore: true })
  const p2 = await list(w.leader, '?type=NOTE&q=pg-&limit=2&offset=2')
  expect(p2.body.pagination).toEqual({ total: 3, limit: 2, offset: 2, hasMore: false })
})
```

- [ ] **Step 1: Write the listed tests**: `post(user, content)` POSTs a `NOTE` and returns its id; `list(user, qs)` GETs `/api/notes${qs}`; one `createContentWorld()` per file
- [ ] **Step 2: Run `cd server && npx vitest run test/notes-list-query.test.ts`, watch them fail**: `q` is ignored, `limit=101` is 200
- [ ] **Step 3:** Implement to the Behaviour; `docker restart makeready-server`
- [ ] **Step 4: Run them, watch them pass**; `npx tsc --noEmit` clean
- [ ] **Step 5: Commit**: `feat(notes): validated note list query with q and orderBy`

### Task 4: leader `:noteId` routes: 404 scoping, strict PATCH, locked `stomped`
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/src/services/notes.service.ts` — add `getUserNote`, `updateUserNote`, `deleteUserNote`, `isStomped` beside `getNote` (`:515`); member functions untouched
- Modify: `server/src/routes/notes.ts:217-231` — add `updateUserNoteSchema`; the shared `updateNoteSchema` stays for the member route
- Modify: `server/src/routes/notes.ts:1448` (GET one), `:1562` (PATCH), `:1687` (DELETE) — call the new service functions; no ownership logic left in the route
- Test: `server/src/services/__tests__/note-stomped.test.ts` — `isStomped` cases
- Test: `server/test/notes-note-routes.test.ts` — real DB through supertest

**Interfaces:**
- Consumes: `deriveTitlePreview` (Task 2)
- Produces: `getUserNote` takes `noteId` and `userId`, returns the active own note with links or `{ success: false, notFound: true }`; `updateUserNote` takes `{ noteId, userId, content, baseUpdatedAt? }`, returns `{ success: true, data, stomped: boolean }` or `{ success: false, notFound: true }`; `deleteUserNote` takes `noteId` and `userId`, returns `{ success: true }` or `{ success: false, notFound: true }`; `isStomped` takes the stored `Date` and the base ISO string and returns a boolean
- Produces (wire, frozen at Task 7, verbatim from §Contract):

```
PATCH /api/notes/:noteId   requireAuth
  body   { content: string (min 1), baseUpdatedAt?: ISO datetime with offset }   .strict() — unknown keys → 400
  200    { success: true, data: Note, stomped: boolean }
  errors 400 · 404 missing, inactive or another user's · 401
GET /api/notes/:noteId     200 { success: true, data: Note } · 404 missing, inactive or another user's · 401
DELETE /api/notes/:noteId  200 { success: true, message: "Note deleted" } (already-inactive own note: still 200) · 404 missing or another user's · 401
```

**Behaviour:**
- `updateUserNoteSchema = z.object({ content: z.string().min(1), baseUpdatedAt: z.string().datetime({ offset: true }).optional() }).strict()` (SC5, D23)
- a `noteId` that is not a UUID → 404 before any query (SC8)
- GET/PATCH: missing, inactive or another user's → 404 `{ success: false, error: 'Note not found' }`; DELETE: missing or another user's → 404, own inactive → 200 (SC8, §Contract)
- PATCH runs in one `prisma.$transaction`: the row lock, then the decision, then the update writing `content`, `title`, `preview`; never read-then-update outside the lock (D23):

```ts
const [row] = await tx.$queryRaw<{ updatedAt: Date; userId: string | null; isActive: boolean }[]>`
  SELECT "updatedAt", "userId", "isActive" FROM study_notes WHERE id = ${noteId}::uuid FOR UPDATE`
if (!row || row.userId !== userId || !row.isActive) return { success: false, notFound: true }
const stomped = baseUpdatedAt ? isStomped(row.updatedAt, baseUpdatedAt) : false
```

- `isStomped`: when the base's time carries a fraction (`/T[^Z+-]*\.\d+/`), `stored.getTime() > Date.parse(base)`; otherwise compare whole seconds, `Math.floor(stored / 1000) > Math.floor(Date.parse(base) / 1000)` (D23)
- the server always writes, and `stomped` is only reported (D7)

**Tests:**
- `isStomped compares at ms with a fraction, at seconds without` (D23)

```ts
it('isStomped compares at ms with a fraction, at seconds without', () => {
  const stored = new Date('2026-11-20T10:00:00.700Z')
  expect(isStomped(stored, '2026-11-20T10:00:00.700Z')).toBe(false)
  expect(isStomped(stored, '2026-11-20T10:00:00.699Z')).toBe(true)
  expect(isStomped(stored, '2026-11-20T10:00:00Z')).toBe(false)
  expect(isStomped(stored, '2026-11-20T09:59:59Z')).toBe(true)
  expect(isStomped(stored, '2026-11-20T04:00:00.700-06:00')).toBe(false)
})
```

- `another user's or an inactive note is 404 on GET and PATCH` (SC8, D6)

```ts
it('another user\'s or an inactive note is 404 on GET and PATCH', async () => {
  const id = await post(w.leader, 'mine')
  expect((await get(w.outsider, id)).status).toBe(404)
  expect((await patch(w.outsider, id, { content: 'x' })).status).toBe(404)
  await prisma.studyNote.update({ where: { id }, data: { isActive: false } })
  expect((await get(w.leader, id)).status).toBe(404)
  expect((await patch(w.leader, id, { content: 'revive' })).status).toBe(404)
  expect((await prisma.studyNote.findUnique({ where: { id } }))!.content).toBe('mine')
  expect((await get(w.leader, 'not-a-uuid')).status).toBe(404)
})
```

- `the PATCH body is strict and baseUpdatedAt must carry an offset` (SC5)

```ts
it.each([{ content: 'a', extra: 1 }, { content: 'a', baseUpdatedAt: 'yesterday' }, { content: 'a', baseUpdatedAt: '2026-11-20T10:00:00' }, { content: '' }])('%o is 400', async (body) => {
  const id = await post(w.leader, 'strict')
  expect((await patch(w.leader, id, body)).status).toBe(400)
})
```

- `stomped is false for the echoed updatedAt and true for an older base; both write` (D7, D23)

```ts
it('stomped is false for the echoed updatedAt and true for an older base; both write', async () => {
  const created = await request(app).post('/api/notes').set('Authorization', bearer(w.leader.token)).send({ type: 'NOTE', content: 'v1' })
  const fresh = await patch(w.leader, created.body.data.id, { content: 'v2', baseUpdatedAt: created.body.data.updatedAt })
  expect(fresh.body).toMatchObject({ success: true, stomped: false, data: { content: 'v2', title: 'v2' } })
  const stale = await patch(w.leader, created.body.data.id, { content: 'v3', baseUpdatedAt: created.body.data.updatedAt })
  expect(stale.body).toMatchObject({ success: true, stomped: true, data: { content: 'v3' } })
  const none = await patch(w.leader, created.body.data.id, { content: 'v4' })
  expect(none.body.stomped).toBe(false)
})
```

- `DELETE is 404 for another user's and idempotent for the owner` (§Contract, SC8)

```ts
it('DELETE is 404 for another user\'s and idempotent for the owner', async () => {
  const id = await post(w.leader, 'bye')
  expect((await del(w.outsider, id)).status).toBe(404)
  const first = await del(w.leader, id)
  expect(first.status).toBe(200)
  expect(first.body).toEqual({ success: true, message: 'Note deleted' })
  expect((await del(w.leader, id)).status).toBe(200)
  expect((await get(w.leader, id)).status).toBe(404)
})
```

- `a PATCH racing a DELETE is all-or-nothing` (D23: the lock)

```ts
it('a PATCH racing a DELETE is all-or-nothing', async () => {
  for (let i = 0; i < 5; i++) {
    const id = await post(w.leader, 'old')
    const [p] = await Promise.all([patch(w.leader, id, { content: 'new' }), del(w.leader, id)])
    const row = await prisma.studyNote.findUniqueOrThrow({ where: { id } })
    expect(row.isActive).toBe(false)
    expect(p.status === 200 ? row.content === 'new' : p.status === 404 && row.content === 'old').toBe(true)
  }
})
```

- [ ] **Step 1: Write the listed tests**: `post`, `get`, `patch(user, id, body)`, `del` wrap supertest with `bearer(user.token)`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/note-stomped.test.ts test/notes-note-routes.test.ts`, watch them fail**: 403 instead of 404, no `stomped`
- [ ] **Step 3:** Implement the service functions and the routes to the Behaviour; `docker restart makeready-server`
- [ ] **Step 4: Run them plus `src/routes/__tests__/notes-removed-link-types.request.test.ts`, watch them pass**; `npx tsc --noEmit` clean
- [ ] **Step 5: Commit**: `feat(notes): 404-scoped note routes with strict PATCH and stomped`

### Task 5: `contextLabel` on every leader note response
App: server
Phase: 2
Recipe: /api

**Files:**
- Create: `server/src/services/note-context-label.ts` — the batched, visibility-scoped label resolver
- Modify: `server/src/routes/notes.ts` — leader `POST /notes` (`:1191`), `GET /notes` (`:1328`), `GET /notes/:noteId` (`:1448`), `PATCH /notes/:noteId` (`:1562`) pass their notes through `attachContextLabels` before responding; member routes untouched
- Test: `server/test/notes-context-label.test.ts` — real DB

**Interfaces:**
- Consumes: `getUserNote`, `updateUserNote` (Task 4); `getNotes` (Task 3)
- Produces: `attachContextLabels` takes a list of notes with their `links` and the session `userId`, returns the same notes each with `contextLabel: string | null`, in one batch (one query per entity kind, whatever the list length)
- Produces (wire, §Contract): `Note` = the Prisma row + `title`, `preview`, `contextLabel` on every leader note response

**Behaviour:**
- one link per note is chosen: `refType` priority MEMO (0) > GROUP (1) > PROGRAM (2), then `createdAt` asc, then `id` asc; other refTypes are never chosen (D22)
- the chosen link resolves only when visible: GROUP → `Group.name` and PROGRAM → `StudyProgram.name` when its `organizationId` is an org the user owns (`Organization.ownerId`) or holds a `UserRole` in; otherwise `null`, and the next link is not tried (D22)
- MEMO → `null` on this branch: no `prisma.voiceMemo` reference (F9, build-time risk below)
- no links, or only LESSON/ENROLLMENT/VERSE/unknown → `null`; the key is always present (§Contract)

> ⚠ build-time risk (F9): `VoiceMemo` exists only on unmerged `builder/memo`, which also edits `createNote`/`addNoteLink`. No `prisma.voiceMemo` reference here; MEMO → null. Whichever of notes and memo lands second on `feature/memo` adds the MEMO label (the user's own active memo → its `title`) and resolves the `notes.service.ts` conflict.

**Tests:**
- `a group or program in the user's org names the note` (D22, D2)

```ts
it('a group or program in the user\'s org names the note', async () => {
  const { groupId } = await createGroupWithMember(w)
  const g = await postWithLinks(w.leader, [{ refType: 'GROUP', refId: groupId }])
  const p = await postWithLinks(w.leader, [{ refType: 'PROGRAM', refId: w.programId }])
  const group = await prisma.group.findUniqueOrThrow({ where: { id: groupId } })
  const program = await prisma.studyProgram.findUniqueOrThrow({ where: { id: w.programId } })
  expect(g.contextLabel).toBe(group.name)
  expect((await get(w.leader, p.id)).body.data.contextLabel).toBe(program.name)
})
```

- `GROUP outranks PROGRAM` (D22)

```ts
it('GROUP outranks PROGRAM', async () => {
  const { groupId } = await createGroupWithMember(w)
  const n = await postWithLinks(w.leader, [{ refType: 'PROGRAM', refId: w.programId }, { refType: 'GROUP', refId: groupId }])
  expect(n.contextLabel).toBe((await prisma.group.findUniqueOrThrow({ where: { id: groupId } })).name)
})
```

- `another org's group is null until the user holds a role there` (D22)

```ts
it('another org\'s group is null until the user holds a role there', async () => {
  const other = await prisma.group.create({ data: { name: 'Hidden', code: `h-${Date.now()}`, creatorId: w.outsider.userId, organizationId: w.otherOrgId } })
  const n = await postWithLinks(w.leader, [{ refType: 'GROUP', refId: other.id }])
  expect(n.contextLabel).toBeNull()
  const role = await prisma.role.findFirstOrThrow()
  await prisma.userRole.create({ data: { userId: w.leader.userId, roleId: role.id, organizationId: w.otherOrgId } })
  expect((await get(w.leader, n.id)).body.data.contextLabel).toBe('Hidden')
})
```

- `LESSON, MEMO and no links are null, and every list item carries the key` (D22, F9)

```ts
it('LESSON, MEMO and no links are null, and every list item carries the key', async () => {
  const l = await postWithLinks(w.leader, [{ refType: 'LESSON', refId: w.lessonId }])
  const m = await postWithLinks(w.leader, [])
  await prisma.noteLink.create({ data: { noteId: m.id, refType: 'MEMO', refId: crypto.randomUUID() } })
  expect(l.contextLabel).toBeNull()
  expect((await get(w.leader, m.id)).body.data.contextLabel).toBeNull()
  const list = await request(app).get('/api/notes?type=NOTE&limit=100').set('Authorization', bearer(w.leader.token))
  for (const item of list.body.data) expect(item).toHaveProperty('contextLabel')
})
```

- [ ] **Step 1: Write the listed tests**: `postWithLinks(user, links)` POSTs `{ type: 'NOTE', content: 'ctx', links }` and returns `body.data`; groups and user roles created here are deleted in `afterAll`
- [ ] **Step 2: Run `cd server && npx vitest run test/notes-context-label.test.ts`, watch them fail**: `contextLabel` is undefined
- [ ] **Step 3:** Implement (patterns: `notes.service.ts:367-505` batch resolver; visible orgs as `services/organization.ts:144-160`); wire the four routes; `docker restart makeready-server`
- [ ] **Step 4: Run them plus Tasks 3–4's files, watch them pass**; `npx tsc --noEmit` clean
- [ ] **Step 5: Commit**: `feat(notes): contextLabel on leader note responses`

### Task 6: the title/preview backfill script
App: server
Phase: 2
Recipe: /api · tiny

**Files:**
- Create: `server/src/scripts/backfill-note-titles.ts` — exported `backfillNoteTitles` plus a `main()` that runs only when executed directly, honouring `--dry-run` (precedent `src/scripts/backfill-program-org.ts:1-20`)
- Modify: `server/package.json` — `"backfill:note-titles": "tsx src/scripts/backfill-note-titles.ts"`
- Test: `server/test/backfill-note-titles.test.ts` — real DB

**Interfaces:**
- Consumes: `deriveTitlePreview` (Task 2)
- Produces: `backfillNoteTitles` takes `{ dryRun?: boolean; batchSize?: number }` (default 500) and returns `{ scanned: number; updated: number }`

**Behaviour:**
- pages by keyset on `id`: `findMany({ where: { id: { gt: lastId } }, orderBy: { id: 'asc' }, take: batchSize, select: { id, content, title, preview } })` over every row, active or not; never `WHERE title IS NULL` (D11)
- writes only rows whose derived values differ, by raw SQL `UPDATE study_notes SET title = $1, preview = $2 WHERE id = $3::uuid`, leaving `updatedAt` untouched (D11, F6)
- `--dry-run` counts what it would update and writes nothing; a second run updates 0 (idempotent) (D11)
- staging/prod run `node dist/scripts/backfill-note-titles.js` after deploy (F4: an ops step in the ship notes, not this task)

**Tests:**
- `fills title/preview, keeps updatedAt, and a second run updates nothing` (D11, F6)

```ts
it('fills title/preview, keeps updatedAt, and a second run updates nothing', async () => {
  const n = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: '# Old title\nold preview' } })
  await prisma.$executeRaw`UPDATE study_notes SET title = NULL, preview = NULL, "updatedAt" = '2025-01-02T03:04:05.678Z' WHERE id = ${n.id}::uuid`
  const first = await backfillNoteTitles({ batchSize: 2 })
  expect(first.updated).toBeGreaterThanOrEqual(1)
  const row = await prisma.studyNote.findUniqueOrThrow({ where: { id: n.id } })
  expect(row).toMatchObject({ title: 'Old title', preview: 'old preview' })
  expect(row.updatedAt.toISOString()).toBe('2025-01-02T03:04:05.678Z')
  expect((await backfillNoteTitles({ batchSize: 2 })).updated).toBe(0)
})
```

- `a dry run writes nothing` (D11)

```ts
it('a dry run writes nothing', async () => {
  const n = await prisma.studyNote.create({ data: { userId: user.id, type: 'NOTE', content: 'Dry\nrun' } })
  await prisma.$executeRaw`UPDATE study_notes SET title = NULL WHERE id = ${n.id}::uuid`
  const r = await backfillNoteTitles({ dryRun: true })
  expect(r.updated).toBeGreaterThanOrEqual(1)
  expect((await prisma.studyNote.findUniqueOrThrow({ where: { id: n.id } })).title).toBeNull()
})
```

- [ ] **Step 1: Write the listed tests; run `cd server && npx vitest run test/backfill-note-titles.test.ts`, watch them fail**: module not found
- [ ] **Step 2:** Implement the script and the npm script to the Behaviour
- [ ] **Step 3: Run them, watch them pass**; `npm run backfill:note-titles -- --dry-run` against the local DB prints its counts; `npx tsc --noEmit` clean
- [ ] **Step 4: Commit**: `feat(notes): idempotent note title/preview backfill`

### Task 7: `library-home` fixture, the §Contract request suite, and the contract freeze
App: server
Phase: 2
Recipe: /api

**Files:**
- Modify: `server/fixtures/ids.ts:46-51` — `studyNote: '0025'` in `FIXTURE_KIND`
- Create: `server/fixtures/screens/library-home.ts` — `libraryHomeRows(now, daysAgo)` (pure) and the `full` layer (pattern `server/fixtures/screens/search-home.ts:21,79`)
- Test: `server/fixtures/__tests__/library-home.test.ts` — the pure rows (`wipe.ts` is unchanged: the owner's deletion cascades to its notes)
- Test: `server/test/notes-contract.test.ts` — one request test per §Contract row, the shape the iPhone decodes

**Interfaces:**
- Consumes: every Phase 1–2 producer
- Produces: `libraryHomeRows` takes `now: Date` and `daysAgo(n)` and returns `{ notes, links }`: the Fixtures owner's (`FIXTURE_USER_ID`) `NOTE` rows with `fixtureId('studyNote', n)` ids, `title`/`preview` from `deriveTitlePreview`, and one GROUP `NoteLink` to `FIXTURE_GROUP_IDS[0]`
- Produces: the frozen §Contract (SPEC §Contract, verbatim; the `Note` wire type is `{ id, memberId: null, userId, type, content, title: string|null, preview: string|null, contextLabel: string|null, isActive, createdAt, updatedAt, links: [{ id, noteId, refType, refId, metadata, createdAt }] }`)

**Behaviour:**
- `full` seeds one note in each D3 bucket: today (`now` − 1 h), yesterday (`daysAgo(1)`), Previous 7 Days (`daysAgo(4)`), Previous 30 Days (`daysAgo(15)`), an earlier month (`daysAgo(45)`), an earlier year (`daysAgo(400)`); `createdAt` = `updatedAt` = that time; the today note carries the GROUP link (D19, F11)
- the `empty` scenario is base only, with no notes; the layer exports no `empty` (D19; `fixtures/runner.ts:59`)
- the layer creates no org, user or group, and never reads `ctx.rand`; dates only from `ctx.now`/`ctx.daysAgo` (house rules: fixtures)

**Tests:**
- `one note per D3 bucket, newest first, the today note linked to a group` (D19)

```ts
it('one note per D3 bucket, newest first, the today note linked to a group', () => {
  const NOW = new Date('2026-11-20T17:00:00.000Z')
  const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
  const { notes, links } = libraryHomeRows(NOW, daysAgo)
  expect(notes).toHaveLength(6)
  expect(notes.every((n) => n.type === 'NOTE' && n.userId === FIXTURE_USER_ID && n.title)).toBe(true)
  const ages = notes.map((n) => Math.round((NOW.getTime() - n.updatedAt.getTime()) / 86_400_000))
  expect(ages).toEqual([0, 1, 4, 15, 45, 400])
  expect(links).toEqual([expect.objectContaining({ noteId: notes[0].id, refType: 'GROUP', refId: FIXTURE_GROUP_IDS[0] })])
  expect(notes[0].id).toBe(fixtureId('studyNote', 1))
})
```

- `every §Contract row answers the frozen shape` (§Contract)

```ts
it('every §Contract row answers the frozen shape', async () => {
  const auth = { Authorization: bearer(w.leader.token) }
  const c = await request(app).post('/api/notes').set(auth).send({ type: 'NOTE', content: '# Shape\nbody' })
  expect(c.status).toBe(201)
  expect(Object.keys(c.body.data).sort()).toEqual(['contextLabel', 'content', 'createdAt', 'id', 'isActive', 'links', 'memberId', 'preview', 'title', 'type', 'updatedAt', 'userId'])
  const l = await request(app).get('/api/notes?type=NOTE&orderBy=updatedAt&limit=100').set(auth)
  expect(Object.keys(l.body.pagination).sort()).toEqual(['hasMore', 'limit', 'offset', 'total'])
  const g = await request(app).get(`/api/notes/${c.body.data.id}`).set(auth)
  expect(g.body).toMatchObject({ success: true, data: { id: c.body.data.id, title: 'Shape', preview: 'body' } })
  const p = await request(app).patch(`/api/notes/${c.body.data.id}`).set(auth).send({ content: 'x', baseUpdatedAt: c.body.data.updatedAt })
  expect(typeof p.body.stomped).toBe('boolean')
  const d = await request(app).delete(`/api/notes/${c.body.data.id}`).set(auth)
  expect(d.body).toEqual({ success: true, message: 'Note deleted' })
  expect((await request(app).get('/api/notes')).status).toBe(401)
})
```

- [ ] **Step 1: Write the listed tests; run `cd server && npx vitest run fixtures/__tests__/library-home.test.ts test/notes-contract.test.ts`, watch the fixture test fail**: module not found
- [ ] **Step 2:** Add the id kind and the layer to the Behaviour
- [ ] **Step 3: Run them, watch them pass**; `npm run fixtures:reset` against the local DB succeeds; `npx tsc --noEmit` and the fixtures typecheck (`npx tsc -p fixtures/tsconfig.json --noEmit`) clean
- [ ] **Step 4: Commit**: `feat(notes): library-home fixture and the notes contract suite`
- [ ] **Step 5: Record the freeze**: `node "$BUILDER_DIR"/scripts/advance.mjs docs/features/notes --set "contract=frozen <YYYY-MM-DD>" --commit "chore(notes): contract frozen"` (the phase close that verifies this task is the freeze; no iphone task starts before it)

### Task 8: `StudyNote` wire models, D3 sectioning, and `AppState.studyNotes`
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/State/Models/NoteModels.swift` — the wire types, `NotesPagination`, `NoteSection`, `NotesSectioning`
- Modify: `iphone/MakeReady/State/AppState.swift` — `let studyNotes = EntityStore<StudyNote>()` beside the other stores (`:76-138`); cleared in `clearInMemory` (`:923`) (and so by `clearAllData`, `:901`)
- Modify: `iphone/MakeReady/State/Persistence/PersistedState.swift:146-299` — a `studyNotes: [StudyNote]` snapshot field, `decodeIfPresent … ?? []`, no schema-version bump, capped at 200
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs for each new file; then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/NoteModelsTests.swift`

**Interfaces:**
- Consumes: the frozen §Contract `Note` wire type (Task 7)
- Produces: `StudyNote` (Codable, Identifiable, Equatable): `id`, `userId: String?`, `type`, `content`, `title: String?`, `preview: String?`, `contextLabel: String?`, `isActive`, `createdAt: String`, `updatedAt: String`, `links: [NoteLinkRef]`; computed `displayTitle: String` and `updatedDate: Date?`
- Produces: `NoteLinkRef` (`id`, `noteId`, `refType: String`, `refId`); `NotesPagination` (`total`, `limit`, `offset`, `hasMore`); `NoteSection` (`title: String`, `notes: [StudyNote]`)
- Produces: `NotesSectioning.sections(_ notes: [StudyNote], now: Date, calendar: Calendar) -> [NoteSection]` and `NotesSectioning.dateLabel(_ date: Date, now: Date, calendar: Calendar) -> String`

**Behaviour:**
- `createdAt`/`updatedAt` stay the server's ISO strings, verbatim; `updatedDate` parses them with fractional seconds, else without (D23)
- `refType` is an open `String`, so `"MEMO"` or any new value decodes (§Contract; released artifact)
- `displayTitle` = `title`, else the content's first non-empty line with leading `#`s and spaces trimmed (a string op, never a markdown parse), else `"New Note"` (F4)
- sections from `dayDiff` = calendar days from `startOfDay(updatedDate)` to `startOfDay(now)`: ≤ 0 "Today", 1 "Yesterday", 2…7 "Previous 7 Days", 8…30 "Previous 30 Days"; older in `now`'s year → the month's full name (`MMMM`); earlier years → `yyyy`. Sections newest first, empty ones omitted, rows `updatedAt` desc then `id` desc (D3)
- `dateLabel`: `dayDiff` ≤ 0 → time (`h:mm a`), 1…6 → weekday (`EEEE`), else `M/d/yy` (D3)
- the persisted snapshot keeps the 200 most recently updated notes with full content; the in-memory store is not capped (D26)
- `studyNotes` empties in `clearInMemory`, which `clearAllData` runs (D26, D24)

**Tests:**
- `testNoteDecodesTheContractShapeAndKeepsTimestampsVerbatim` (§Contract, D23)

```swift
func testNoteDecodesTheContractShapeAndKeepsTimestampsVerbatim() throws {
    let json = #"{"id":"n1","memberId":null,"userId":"u1","type":"NOTE","content":"# Walk\nbody","title":"Walk","preview":"body","contextLabel":"Youth Group","isActive":true,"createdAt":"2026-11-20T10:00:00.123Z","updatedAt":"2026-11-20T10:05:00.456Z","links":[{"id":"l1","noteId":"n1","refType":"MEMO","refId":"m1","metadata":null,"createdAt":"2026-11-20T10:00:00.123Z"}]}"#
    let note = try JSONDecoder.apiDecoder.decode(StudyNote.self, from: Data(json.utf8))
    XCTAssertEqual(note.updatedAt, "2026-11-20T10:05:00.456Z")
    XCTAssertEqual(note.links.first?.refType, "MEMO")
    XCTAssertEqual(note.contextLabel, "Youth Group")
}
```

- `testDisplayTitleFallsBackToTheFirstContentLine` (F4)

```swift
func testDisplayTitleFallsBackToTheFirstContentLine() {
    XCTAssertEqual(StudyNote.stub(content: "\n## Old note\nmore", title: nil).displayTitle, "Old note")
    XCTAssertEqual(StudyNote.stub(content: "  ", title: nil).displayTitle, "New Note")
}
```

- `testSectionsBucketByCalendarDayNewestFirst` (D3)

```swift
func testSectionsBucketByCalendarDayNewestFirst() {
    let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
    let ages = [0, 1, 4, 7, 8, 30, 45, 400]
    let notes = ages.map { StudyNote.stub(id: "n\($0)", updatedAt: now.addingTimeInterval(-Double($0) * 86_400)) }
    let sections = NotesSectioning.sections(notes.reversed(), now: now, calendar: chicago)
    XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "October", "2025"])
    XCTAssertEqual(sections[2].notes.map(\.id), ["n4", "n7"])
}
```

- `testDateLabelIsTimeWeekdayOrShortDate` (D3)

```swift
func testDateLabelIsTimeWeekdayOrShortDate() {
    let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
    XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-3_600), now: now, calendar: chicago), "11:00 AM")
    XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-2 * 86_400), now: now, calendar: chicago), "Wednesday")
    XCTAssertEqual(NotesSectioning.dateLabel(now.addingTimeInterval(-9 * 86_400), now: now, calendar: chicago), "11/11/26")
}
```

- `testPersistedSnapshotKeepsThe200NewestNotesAndOldCachesDecode` (D26)

```swift
func testPersistedSnapshotKeepsThe200NewestNotesAndOldCachesDecode() throws {
    let state = AppState()
    let base = Date(timeIntervalSince1970: 1_790_000_000)
    state.studyNotes.replaceAll((0..<250).map { StudyNote.stub(id: "n\($0)", updatedAt: base.addingTimeInterval(Double($0))) })
    let snapshot = PersistedState(from: state)
    XCTAssertEqual(Set(snapshot.studyNotes.map(\.id)), Set((50..<250).map { "n\($0)" }))
    var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(snapshot)) as! [String: Any]; dict["studyNotes"] = nil
    XCTAssertEqual(try JSONDecoder().decode(PersistedState.self, from: JSONSerialization.data(withJSONObject: dict)).studyNotes.count, 0)
}
```

- `testClearAllDataEmptiesStudyNotes` (D24, D26)

```swift
func testClearAllDataEmptiesStudyNotes() {
    let state = AppState()
    state.studyNotes.upsert(.stub(id: "n1"))
    state.clearAllData()
    XCTAssertTrue(state.studyNotes.all.isEmpty)
}
```

> ⚠ environment: new Swift files need explicit `pbxproj` refs (no folder sync), and MakeReadyCapture breaks until `ruby iphone/scripts/capture-targets.rb` re-syncs. `StudyNote.stub(…)` (every field defaulted) and `chicago` (gregorian, America/Chicago, `en_US_POSIX`) are test-only helpers in this test file; Tasks 9–14's tests copy them. Match `PersistedState`'s real init (`:146-299`) if it is not `init(from: AppState)`.

- [ ] **Step 1: Write the listed tests; run them through the verifier (`MakeReadyCaptureTests/NoteModelsTests`), watch them fail**: `StudyNote` not in scope
- [ ] **Step 2:** Write `NoteModels.swift`, the store, the snapshot field and its cap; add refs and re-sync
- [ ] **Step 3: Run them, watch them pass**; `cd iphone && swiftlint` adds no finding
- [ ] **Step 4: Commit**: `feat(notes): note models, sectioning and AppState.studyNotes`

### Task 9: `NoteActions`
App: iphone
Phase: 3
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/State/Actions/NoteActions.swift` — the only `APIClient` user for notes
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/NoteActionsTests.swift` — with `StubAPIClient`

**Interfaces:**
- Consumes: `StudyNote`, `NotesPagination`, `AppState.studyNotes` (Task 8); §Contract rows (Task 7)
- Produces: `NoteActions` (`struct`, `init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil)`, pattern `EnrollmentDraftActions.swift:12-50`):
  - `load(q: String? = nil) async throws -> [String]` (ids in server order), `loadOne(id:) -> StudyNote`, `create(content:) -> StudyNote`, `update(id:content:baseUpdatedAt:) -> NoteUpdateResult`, `softDelete(id:)`, all `async throws`
- Produces: `NoteUpdateResult { note: StudyNote; stomped: Bool }`; `NoteActions.isNotFound(_:) -> Bool` (`APIHTTPError` status 404)

**Behaviour:**
- every call goes through `api.requestWithStatus(endpoint:method:body:)`, so a non-2xx arrives as `APIHTTPError` with its status (`APIClient.swift:47-60`)
- `load` requests `/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=<n>` (+ `&q=<percent-encoded>` when `q` is non-empty), following `pagination.hasMore` until false (SC6; pattern `ProgramActions.swift:304-331`)
- `load()` with no `q` merges the whole list into `studyNotes` with `removeStale: true`; with `q` it upserts the matches only and removes nothing (D8, D3)
- `create` POSTs `{ "type": "NOTE", "content": … }`; `update` PATCHes `{ "content": …, "baseUpdatedAt": … }`, omitting `baseUpdatedAt` when nil, the string sent verbatim (D23)
- `create`, `update`, `loadOne` upsert the returned note; `softDelete` DELETEs and removes the id from `studyNotes`, and a 404 also removes it (D10, D24)

**Tests:**
- `testLoadPagesUntilHasMoreIsFalseAndDropsStaleNotes` (SC6, D3)

```swift
func testLoadPagesUntilHasMoreIsFalseAndDropsStaleNotes() async throws {
    let api = StubAPIClient(); let state = AppState()
    state.studyNotes.upsert(.stub(id: "gone"))
    api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=0", json: page(["a", "b"], total: 3, offset: 0, hasMore: true))
    api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=100", json: page(["c"], total: 3, offset: 100, hasMore: false))
    let ids = try await NoteActions(api: api, state: state).load()
    XCTAssertEqual(ids, ["a", "b", "c"])
    XCTAssertEqual(Set(state.studyNotes.all.map(\.id)), ["a", "b", "c"])
}
```

- `testSearchUpsertsMatchesWithoutDroppingOthers` (D8)

```swift
func testSearchUpsertsMatchesWithoutDroppingOthers() async throws {
    let api = StubAPIClient(); let state = AppState()
    state.studyNotes.upsert(.stub(id: "other"))
    api.stub("GET", "/api/notes?type=NOTE&orderBy=updatedAt&limit=100&offset=0&q=grace%20alone", json: page(["g"], total: 1, offset: 0, hasMore: false))
    XCTAssertEqual(try await NoteActions(api: api, state: state).load(q: "grace alone"), ["g"])
    XCTAssertEqual(Set(state.studyNotes.all.map(\.id)), ["other", "g"])
}
```

- `testUpdateEchoesBaseUpdatedAtVerbatimAndReturnsStomped` (D23, D7)

```swift
func testUpdateEchoesBaseUpdatedAtVerbatimAndReturnsStomped() async throws {
    let api = StubAPIClient(); let state = AppState()
    api.stub("PATCH", "/api/notes/n1", json: #"{"success":true,"stomped":true,"data":\#(noteJSON("n1", content: "v2"))}"#)
    let result = try await NoteActions(api: api, state: state).update(id: "n1", content: "v2", baseUpdatedAt: "2026-11-20T10:05:00.456Z")
    XCTAssertTrue(result.stomped)
    XCTAssertEqual(api.calls.last?.body?["baseUpdatedAt"] as? String, "2026-11-20T10:05:00.456Z")
    XCTAssertEqual(state.studyNotes["n1"]?.content, "v2")
}
```

- `testCreatePostsANoteAndStoresIt` (D6, D10)

```swift
func testCreatePostsANoteAndStoresIt() async throws {
    let api = StubAPIClient(); let state = AppState()
    api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON("srv1", content: "Hi"))}"#)
    let note = try await NoteActions(api: api, state: state).create(content: "Hi")
    XCTAssertEqual(api.calls.last?.body?["type"] as? String, "NOTE")
    XCTAssertEqual(note.id, "srv1")
    XCTAssertNotNil(state.studyNotes["srv1"])
}
```

- `testSoftDeleteRemovesTheNoteEvenOn404` (D10, D24)

```swift
func testSoftDeleteRemovesTheNoteEvenOn404() async throws {
    let api = StubAPIClient(); let state = AppState()
    state.studyNotes.upsert(.stub(id: "n1"))
    api.errorFor = { endpoint, _ in endpoint == "/api/notes/n1" ? APIHTTPError(status: 404, message: "Note not found") : nil }
    try await NoteActions(api: api, state: state).softDelete(id: "n1")
    XCTAssertNil(state.studyNotes["n1"])
}
```

- [ ] **Step 1: Write the listed tests**: `page(…)` and `noteJSON(…)` are file-private §Contract JSON builders; use the stub's and `EntityStore`'s real lookup names if they differ
- [ ] **Step 2: Run them through the verifier (`MakeReadyCaptureTests/NoteActionsTests`), watch them fail**: `NoteActions` not in scope
- [ ] **Step 3:** Implement to the Behaviour; add refs and re-sync
- [ ] **Step 4: Run them, watch them pass**; `cd iphone && swiftlint` adds no finding
- [ ] **Step 5: Commit**: `feat(notes): NoteActions over the notes API`

### Task 10: `NoteSaveQueue` and its connectivity flush
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Notes/NoteSaveQueue.swift` — the persistent per-environment queue and `flush()`
- Create: `iphone/MakeReady/Services/Notes/NotesConnectivity.swift` — the `NWPathMonitor` wrapper that calls `flush()` when the path becomes satisfied
- Modify: `iphone/MakeReady/State/AppState.swift:901` — `clearAllData` also clears `NoteSaveQueue.shared`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs; `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/NoteSaveQueueTests.swift`

**Interfaces:**
- Consumes: `NoteActions` (`create`, `update`, `softDelete`, `isNotFound`), `NoteUpdateResult`, `AppState.studyNotes` (Tasks 8–9)
- Produces: `NoteSaveEntry` (Codable, Equatable): `.upsert(content: String, baseUpdatedAt: String?)` or `.delete`
- Produces: `NoteSaveQueue` (`@MainActor final class`, `init(fileURL: URL, actions: NoteActions, state: AppState)`; `static let shared`, its file `notes-queue.json` in `StatePersistence`'s per-environment directory, `StatePersistence.swift:27-62`):
  - `enqueue(noteId:_:)`, `entry(for:)`, `flush() async -> [NoteFlushOutcome]`, `clear()`, `onIdAdopted: (String, String) -> Void` (local id, server id)
- Produces: `NoteFlushOutcome` (`.sent(noteId)`, `.stomped(noteId)`, `.dropped(noteId)`, `.kept(noteId)`); `NoteSaveQueue.isLocalId(_:) -> Bool` (prefix `local-`); `NotesConnectivity` with `onSatisfied`, `handle(_ status: NWPath.Status)` and `start(queue:)`

**Behaviour:**
- one entry per note id, latest wins; the file is rewritten on every change and read on init (D13, D24)
- `.upsert` with a `local-` id → `create`, then the server note replaces the local one in `studyNotes`, the entry is re-keyed, and `onIdAdopted` fires (D13)
- `.upsert` with a server id → `update` with the stored `baseUpdatedAt`; `stomped` is logged (`Log` notes category) and reported as `.stomped`, with the server's text kept (D7, D13)
- `.delete` with a `local-` id → dropped with no request; with a server id → `softDelete` (D24)
- a 404 drops the entry and removes the note from `studyNotes`; any other `APIHTTPError` (4xx/5xx) drops the entry, logged; a transport error (offline) keeps it and stops this flush (D24, D20)
- one request in flight at a time, entries in insertion order; a `flush()` while one runs returns `[]` at once (D24)
- `clear()` empties memory and deletes the file; `AppState.clearAllData` calls it (D24)
- `NotesConnectivity` starts one `NWPathMonitor` and calls its `onSatisfied` on each transition into `.satisfied`, not on repeats; `start(queue:)` sets `onSatisfied` to `queue.flush()` (D13)

**Tests:**
- `testQueueSurvivesARelaunchLatestWins` (D13, D24)

```swift
func testQueueSurvivesARelaunchLatestWins() {
    let url = tmpURL()
    let q1 = NoteSaveQueue(fileURL: url, actions: NoteActions(api: StubAPIClient(), state: AppState()), state: AppState())
    q1.enqueue(noteId: "n1", .upsert(content: "a", baseUpdatedAt: nil))
    q1.enqueue(noteId: "n1", .upsert(content: "b", baseUpdatedAt: "t1"))
    let q2 = NoteSaveQueue(fileURL: url, actions: NoteActions(api: StubAPIClient(), state: AppState()), state: AppState())
    XCTAssertEqual(q2.entry(for: "n1"), .upsert(content: "b", baseUpdatedAt: "t1"))
}
```

- `testALocalNoteFlushesAsPostAndAdoptsTheServerId` (D13)

```swift
func testALocalNoteFlushesAsPostAndAdoptsTheServerId() async {
    let api = StubAPIClient(); let state = AppState()
    state.studyNotes.upsert(.stub(id: "local-1"))
    api.stub("POST", "/api/notes", json: #"{"success":true,"data":\#(noteJSON("srv1", content: "hi"))}"#)
    let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
    var adopted: (String, String)?
    q.onIdAdopted = { adopted = ($0, $1) }
    q.enqueue(noteId: "local-1", .upsert(content: "hi", baseUpdatedAt: nil))
    _ = await q.flush()
    XCTAssertNil(state.studyNotes["local-1"]); XCTAssertNotNil(state.studyNotes["srv1"])
    XCTAssertEqual(adopted?.1, "srv1")
    XCTAssertNil(q.entry(for: "local-1")); XCTAssertNil(q.entry(for: "srv1"))
}
```

- `testStompedIsReportedAndTheEntryCleared` (D7)

```swift
func testStompedIsReportedAndTheEntryCleared() async {
    let api = StubAPIClient(); let state = AppState()
    api.stub("PATCH", "/api/notes/n1", json: #"{"success":true,"stomped":true,"data":\#(noteJSON("n1", content: "mine"))}"#)
    let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
    q.enqueue(noteId: "n1", .upsert(content: "mine", baseUpdatedAt: "2026-11-20T10:00:00.000Z"))
    XCTAssertEqual(await q.flush(), [.stomped("n1")])
    XCTAssertNil(q.entry(for: "n1"))
}
```

- `testA404DropsTheEntryAndTheNote` (D24)

```swift
func testA404DropsTheEntryAndTheNote() async {
    let api = StubAPIClient(); let state = AppState()
    state.studyNotes.upsert(.stub(id: "n1"))
    api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Note not found") }
    let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
    q.enqueue(noteId: "n1", .upsert(content: "x", baseUpdatedAt: nil))
    XCTAssertEqual(await q.flush(), [.dropped("n1")])
    XCTAssertNil(state.studyNotes["n1"])
}
```

- `testOfflineKeepsTheEntryAndALocalDeleteSendsNothing` (D24)

```swift
func testOfflineKeepsTheEntryAndALocalDeleteSendsNothing() async {
    let api = StubAPIClient(); let state = AppState()
    api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
    let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
    q.enqueue(noteId: "local-9", .delete)
    q.enqueue(noteId: "n2", .upsert(content: "x", baseUpdatedAt: nil))
    XCTAssertEqual(await q.flush(), [.dropped("local-9"), .kept("n2")])
    XCTAssertEqual(api.calls.count, 1)
    XCTAssertNotNil(q.entry(for: "n2"))
}
```

- `testAFlushDuringAFlushSendsOnce` and `testConnectivityFlushesOnlyOnTransitionToSatisfied` (D24, D13)

```swift
func testAFlushDuringAFlushSendsOnce() async {
    let api = StubAPIClient(); let state = AppState(); api.delayFor = { _ in 0.2 }
    let q = NoteSaveQueue(fileURL: tmpURL(), actions: NoteActions(api: api, state: state), state: state)
    q.enqueue(noteId: "n1", .delete)
    async let first = q.flush()
    XCTAssertEqual(await q.flush(), [])
    _ = await first
    XCTAssertEqual(api.calls.count, 1)
}
func testConnectivityFlushesOnlyOnTransitionToSatisfied() {
    let c = NotesConnectivity(); var fired = 0
    c.onSatisfied = { fired += 1 }
    [.unsatisfied, .satisfied, .satisfied, .unsatisfied, .satisfied].forEach { c.handle($0) }
    XCTAssertEqual(fired, 2)
}
```

- `testClearAllDataEmptiesTheQueue` (D24)

```swift
func testClearAllDataEmptiesTheQueue() {
    NoteSaveQueue.shared.enqueue(noteId: "n1", .delete)
    AppState.shared.clearAllData()
    XCTAssertNil(NoteSaveQueue.shared.entry(for: "n1"))
}
```

- [ ] **Step 1: Write the listed tests**: `tmpURL()` is a fresh file under `FileManager.default.temporaryDirectory`; `noteJSON` as in Task 9's test file (copy it file-private)
- [ ] **Step 2: Run them through the verifier (`MakeReadyCaptureTests/NoteSaveQueueTests`), watch them fail**: `NoteSaveQueue` not in scope
- [ ] **Step 3:** Implement both files to the Behaviour (serial pattern `MediaUploadQueue.swift:16-40`); hook `clearAllData`; add refs and re-sync
- [ ] **Step 4: Run them, watch them pass**; `cd iphone && swiftlint` adds no finding
- [ ] **Step 5: Commit**: `feat(notes): persistent per-environment note save queue`

### Task 11: `NoteAutosaveController`
App: iphone
Phase: 4
Recipe: /ios-error-surface

**Files:**
- Create: `iphone/MakeReady/Services/Notes/NoteAutosaveController.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs; `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/NoteAutosaveControllerTests.swift`

**Interfaces:**
- Consumes: `NoteActions`, `NoteUpdateResult` (Task 9); `NoteSaveQueue`, `NoteSaveEntry` (Task 10)
- Produces: `NoteAutosaveController` (`@MainActor final class`, `init(note: StudyNote?, actions: NoteActions, queue: NoteSaveQueue, state: AppState, debounce: Duration = .milliseconds(1500), sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) })`):
  - `noteId: String?` (nil until the first POST; a `local-` id while offline), `edited(_ markdown: String)`, `flush() async`, `leave() async`, `onStomped: @MainActor () -> Void`

**Behaviour:**
- `edited` stores the latest markdown and (re)starts the debounce; when it elapses the controller saves; nothing is sent while the trimmed content is empty (D12, D10)
- the first save of a new note is `create`, adopting the server id; later saves are `update` with `baseUpdatedAt` = the last response's `updatedAt` (D10, D23)
- at most one request in flight; an edit during it is saved when it returns (D24; pattern `EnrollDraftSync.swift:52-80`)
- `flush()` cancels the debounce and saves now, waiting for the request in flight first; the editor calls it on leave and on `scenePhase` → background (D12)
- `leave()`: trimmed content empty → an existing note gets `softDelete`, and a never-created note sends nothing and drops any queued entry; else `flush()` (D10)
- a transport or 5xx failure enqueues `.upsert(content, baseUpdatedAt)` under the note's id, minting `local-<UUID>` for a never-created note and upserting a local `StudyNote` into `studyNotes` (`updatedAt` = now, ISO) so the list shows it; logged console-only (D13, D20, D24)
- `stomped` → log it, keep the editor's text, call `onStomped` (the container refreshes the list) (D7)

**Tests:**
- `testNoRequestUntilContentIsNonEmptyThenOnePostAfterTheDebounce` (D10, D12)

```swift
func testNoRequestUntilContentIsNonEmptyThenOnePostAfterTheDebounce() async {
    let (c, api, clock) = makeController(note: nil, stubPost: "srv1")
    c.edited("   ")
    await clock.advance(.milliseconds(1500))
    XCTAssertTrue(api.calls.isEmpty)
    c.edited("H"); c.edited("Hi")
    await clock.advance(.milliseconds(1499))
    XCTAssertTrue(api.calls.isEmpty)
    await clock.advance(.milliseconds(1))
    XCTAssertEqual(api.calls.map(\.method), ["POST"])
    XCTAssertEqual(api.calls[0].body?["content"] as? String, "Hi")
    XCTAssertEqual(c.noteId, "srv1")
}
```

- `testLaterSavesPatchWithTheLastUpdatedAt` (D23)

```swift
func testLaterSavesPatchWithTheLastUpdatedAt() async {
    let (c, api, _) = makeController(note: .stub(id: "n1", updatedAtString: "2026-11-20T10:00:00.123Z"), stubPatch: "n1")
    c.edited("v2")
    await c.flush()
    XCTAssertEqual(api.calls.last?.method, "PATCH")
    XCTAssertEqual(api.calls.last?.body?["baseUpdatedAt"] as? String, "2026-11-20T10:00:00.123Z")
}
```

- `testLeavingAnEmptiedNoteDeletesItAndANewEmptyOneSendsNothing` (D10)

```swift
func testLeavingAnEmptiedNoteDeletesItAndANewEmptyOneSendsNothing() async {
    let (existing, api1, _) = makeController(note: .stub(id: "n1"), stubDelete: "n1")
    existing.edited("")
    await existing.leave()
    XCTAssertEqual(api1.calls.map(\.method), ["DELETE"])
    let (fresh, api2, _) = makeController(note: nil)
    fresh.edited(" \n ")
    await fresh.leave()
    XCTAssertTrue(api2.calls.isEmpty)
}
```

- `testOfflineSaveQueuesUnderALocalIdAndShowsInTheList` (D13, D20)

```swift
func testOfflineSaveQueuesUnderALocalIdAndShowsInTheList() async {
    let (c, api, _, queue, state) = makeControllerWithQueue(note: nil)
    api.errorFor = { _, _ in URLError(.notConnectedToInternet) }
    c.edited("Offline idea")
    await c.flush()
    let id = try! XCTUnwrap(c.noteId)
    XCTAssertTrue(NoteSaveQueue.isLocalId(id))
    XCTAssertEqual(queue.entry(for: id), .upsert(content: "Offline idea", baseUpdatedAt: nil))
    XCTAssertEqual(state.studyNotes[id]?.content, "Offline idea")
}
```

- `testStompedKeepsTheTextAndAsksForARefresh` (D7)

```swift
func testStompedKeepsTheTextAndAsksForARefresh() async {
    let (c, _, _) = makeController(note: .stub(id: "n1"), stubPatch: "n1", stomped: true)
    var refreshed = false
    c.onStomped = { refreshed = true }
    c.edited("my words")
    await c.flush()
    XCTAssertTrue(refreshed)
}
```

- `testAnEditDuringTheRequestIsSavedAfterIt` (D24)

```swift
func testAnEditDuringTheRequestIsSavedAfterIt() async {
    let (c, api, _) = makeController(note: .stub(id: "n1"), stubPatch: "n1", patchDelay: 0.2)
    c.edited("one")
    let first = Task { await c.flush() }
    try? await Task.sleep(for: .milliseconds(50))
    c.edited("two")
    await first.value
    await c.flush()
    XCTAssertEqual(api.calls.compactMap { $0.body?["content"] as? String }, ["one", "two"])
}
```

- [ ] **Step 1: Write the listed tests**: `makeController(…)` wires `StubAPIClient`, `AppState`, a temp-file queue and a manual clock whose `sleep` resumes on `advance` (pattern `EnrollDraftSyncTests.swift`)
- [ ] **Step 2: Run them through the verifier (`MakeReadyCaptureTests/NoteAutosaveControllerTests`), watch them fail**: `NoteAutosaveController` not in scope
- [ ] **Step 3:** Implement to the Behaviour; add refs and re-sync
- [ ] **Step 4: Run them plus `NoteSaveQueueTests`, watch them pass**; `cd iphone && swiftlint` adds no finding
- [ ] **Step 5: Commit**: `feat(notes): note autosave with lazy create and empty delete`

### Task 12: the d2m gate, `swift-markdown`, and `NoteDocumentCodec`
App: iphone
Phase: 5
Recipe: test-driven-development

**Files:**
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — package `https://github.com/swiftlang/swift-markdown`, `kind = exactVersion` (the latest tag, named in the commit), its `Markdown` product linked by hand to BOTH `MakeReady` and `MakeReadyCapture` (`capture-targets.rb` doesn't sync packages; precedent `:3448,5505-5521`); file refs; re-sync
- Create: `iphone/MakeReady/Services/Notes/NoteDocumentCodec.swift` — markdown ⇄ C-001's `AttributedString`
- Test: `iphone/MakeReadyCaptureTests/NoteDocumentCodecTests.swift` — the round-trip corpus

**Interfaces:**
- Consumes: d2m's `NoteEditorModels.swift` under `iphone/MakeReadyUI/`: C-001's paragraph-style attribute (Title / Body / Bulleted / Numbered) and the shared `InlineStyle`/`ListStyle` types. Use their real names; the codec defines no attribute key of its own (D9 as superseded)
- Produces: `NoteDocumentCodec.parse(_ markdown: String) -> AttributedString`; `NoteDocumentCodec.serialize(_ doc: AttributedString) -> String`; `NoteDocumentCodec.runs(_ doc: AttributedString) -> [NoteRun]` and its inverse `NoteDocumentCodec.document(_ runs: [NoteRun]) -> AttributedString`, the test seam that maps to and from d2m's attributes, where `NoteRun { block: Int; text: String; paragraph: NoteParagraphKind; bold, italic, underline, strike: Bool }` (all but `block`/`text`/`paragraph` default `false`), `block` the paragraph's index, and `NoteParagraphKind` is `title`, `body`, `bulleted`, `numbered`

> 🔴 **The d2m gate (F1, F5), before Step 1.** `git ls-files iphone/MakeReadyUI` must list `NoteEditorModels.swift`, the views of C-001/002/003/005/008/009/010/015 and the `note-editor` screen, and `LibraryHomeScreen.swift` must have a notes state. If any is missing, **STOP and report BLOCKED** with this park line: `the notes views d2m builds are not on this branch yet [F1/F5] — next: finish d2m changes cmwoogs5g001mv0h9jj3070bk + cmwoogn700001v0h9l69stkz3 and the note-editor screen, land them on feature/memo, then /builder:agent`. The build lead, holding the `d2m-channel` tools, first tries to move them: `get_project_change` on both ids; `answer_project_change` on every open question per D21 (recommended option, except OQ-C-001-003 → option 2; OQ-C-003-001 and OQ-C-015-001 → "spec from the written measurements; the first accepted capture freezes as the snapshot (D68 precedent)"; OQ-C-001-001 and OQ-C-002-001 → option 4); `request_project_change` for `note-editor` if it isn't minted; `retry_project_change` on cmwoogn700001v0h9l69stkz3 once C-005/008/010 are built; `wait_project_change`. Never write a view, contract or registry row (D1).

**Behaviour:**
- `parse` uses `Markdown.Document(parsing:)` once; `serialize` walks the `AttributedString` paragraphs; neither runs per keystroke (D9)
- the first non-empty paragraph is `title`, serialized `# <text>`; a `# ` heading as the first block parses to `title`; any later heading parses to a `body` paragraph of its text (D5)
- the editor emits only `# ` (first line), bare paragraphs, `**`, `*`, `~~`, `<u>…</u>`, `- `, `1. ` (D4)
- blocks are separated by one blank line; consecutive items of one list by a single newline; numbered items are numbered `1.`, `2.`, … in order; empty paragraphs are dropped on serialize (D4)
- inline nesting, outermost first: `~~`, `**`, `*`, `<u>`; leading/trailing spaces of a styled run go outside its markers (`**a** b`, never `**a **b`) (D4)
- escaping on serialize: `\`, `*`, `_`, `~`, `=`, `<`, `>`, `#` in text get a backslash; a body line beginning `- `, `+ ` or `<digits>. ` is escaped (`\- `, `1\. `) (D4)
- parse: `<u>…</u>` (inline HTML) → underline; `==text==` → the text, unstyled, markers dropped (highlight parsed, not emitted in v1); a `makeready://memo/…` link → its text, as for any link (D4, D2, D14)
- the round trip `parse(serialize(doc)) == doc` holds over the corpus (D9; F3)

**Tests:**
- `testCorpusRoundTripsExactly` (D9, D4, F3)

```swift
static let corpus = [
    "# Title only",
    "# Walk\n\nA plain body line.",
    "# T\n\n**bold** *italic* ~~strike~~ <u>under</u>",
    "# T\n\n***bold italic*** and ~~**<u>all</u>**~~",
    "# T\n\n- one\n- two\n\nafter",
    "# T\n\n1. first\n2. second",
    "# T\n\nescapes \\* \\_ \\~ \\= \\< \\> \\# \\\\ done",
    "# T\n\n\\- not a list\n\n1\\. not numbered",
]
func testCorpusRoundTripsExactly() {
    for md in Self.corpus {
        let doc = NoteDocumentCodec.parse(md)
        XCTAssertEqual(NoteDocumentCodec.serialize(doc), md, md)
        XCTAssertEqual(NoteDocumentCodec.parse(NoteDocumentCodec.serialize(doc)), doc, md)
    }
}
```

- `testTitleAndStylesLandOnTheRightRuns` (D5, D4)

```swift
func testTitleAndStylesLandOnTheRightRuns() {
    let runs = NoteDocumentCodec.runs(NoteDocumentCodec.parse("# Walk\n\n**bold** plain\n\n- item"))
    XCTAssertEqual(runs.first, NoteRun(block: 0, text: "Walk", paragraph: .title))
    XCTAssertTrue(runs.contains(NoteRun(block: 1, text: "bold", paragraph: .body, bold: true)))
    XCTAssertEqual(runs.last?.paragraph, .bulleted)
}
```

- `testSpacesMoveOutsideMarkersAndEmptyParagraphsDrop` (D4)

```swift
func testSpacesMoveOutsideMarkersAndEmptyParagraphsDrop() {
    let spaced = NoteDocumentCodec.document([NoteRun(block: 0, text: "T", paragraph: .title),
                                             NoteRun(block: 1, text: "a ", paragraph: .body, bold: true),
                                             NoteRun(block: 1, text: "b", paragraph: .body),
                                             NoteRun(block: 2, text: "", paragraph: .body),
                                             NoteRun(block: 3, text: "end", paragraph: .body)])
    XCTAssertEqual(NoteDocumentCodec.serialize(spaced), "# T\n\n**a** b\n\nend")
}
```

- `testHighlightParsesToPlainTextAndMemoLinksToText` (D4, D2)

```swift
func testHighlightParsesToPlainTextAndMemoLinksToText() {
    XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\n==glow== on")), "# T\n\nglow on")
    XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\n[Memo](makeready://memo/m1)")), "# T\n\nMemo")
}
```

- [ ] **Step 1: The d2m gate above.** Blocked → report BLOCKED with the park line and stop
- [ ] **Step 2:** Add the package (exact version) to both targets
- [ ] **Step 3: Write the listed tests; run them through the verifier (`MakeReadyCaptureTests/NoteDocumentCodecTests`), watch them fail**: `NoteDocumentCodec` not in scope
- [ ] **Step 4:** Implement the codec to the Behaviour; add refs and re-sync
- [ ] **Step 5: Run them, watch them pass**; the full iphone XCTest suite still builds; `cd iphone && swiftlint` adds no finding
- [ ] **Step 6: Commit**: `feat(notes): swift-markdown note codec with round-trip corpus` (the package version in the body)

### Task 13: `LibraryHomeContainer`: the notes list
App: iphone
Phase: 5
Recipe: /push-page

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeContainer.swift:1-9` — maps `AppState.studyNotes` to d2m's `LibraryHomeScreen` notes state; `.comingSoon` stops being the default (RS1, R1)
- Create: `iphone/MakeReady/UI2/Containers/Library/LibraryHomeMapper.swift` — the pure state → view-props mapping
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs; `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/LibraryHomeMapperTests.swift`

**Interfaces:**
- Consumes: `NotesSectioning`, `StudyNote.displayTitle` (Task 8); `NoteActions.load(q:)` (Task 9); `UI2Destination.newNote(flowId:)` and `.noteEditor(noteId:)`, pushed via `@Environment(\.ui2Navigator)` (added here exactly as named; Task 14 gives them pages); d2m's `LibraryHomeScreen` notes props and C-005/C-008/C-010, by their real names
- Produces: `LibraryHomeMapper.rows(notes:searchIds:now:calendar:) -> [NoteSection]`; `LibraryHomeMapper.phase(isLoading:loadFailed:sections:query:)` → loading / error / empty / noResults / list

**Behaviour:**
- on appear: `NoteActions().load()`; the list is `AppState.studyNotes` sectioned by `NotesSectioning` (D3; walk item 1)
- a row shows `displayTitle`, `dateLabel(updatedDate)`, `preview`, and `contextLabel` when non-nil (D3, D2, F4)
- the search capsule sends `q` 300 ms after the last keystroke, cancelling the previous search; a cleared query shows the full list again; no client-side corpus search (D8; walk item 5)
- compose pushes `.newNote(flowId: UUID())`; a row tap pushes `.noteEditor(noteId:)` (D17; walk items 3–4)
- a failed load: the store's notes stay on screen when there are any, else d2m's error state; routed per `/ios-error-surface` (D20)

> ⚠ build-time risk (F14): no in-scope view has been built or captured before, so the wiring's walk is the first time these states are seen. A missing prop or state goes back to d2m with `request_project_change` (D1); never draw it here.

**Tests:**
- `testRowsCarryTitleDatePreviewAndContextInSections` (D3, D2)

```swift
func testRowsCarryTitleDatePreviewAndContextInSections() {
    let now = ISO8601DateFormatter().date(from: "2026-11-20T18:00:00Z")!
    let notes = [StudyNote.stub(id: "a", title: "Walk", preview: "Psalm", contextLabel: "Youth", updatedAt: now.addingTimeInterval(-60)),
                 StudyNote.stub(id: "b", title: nil, content: "# Old\nx", updatedAt: now.addingTimeInterval(-86_400))]
    let sections = LibraryHomeMapper.rows(notes: notes, searchIds: nil, now: now, calendar: chicago)
    XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday"])
    XCTAssertEqual(sections[1].notes.first?.displayTitle, "Old")
}
```

- `testSearchShowsOnlyTheServerMatches` (D8)

```swift
func testSearchShowsOnlyTheServerMatches() {
    let now = Date()
    let notes = ["a", "b", "c"].map { StudyNote.stub(id: $0, updatedAt: now) }
    XCTAssertEqual(LibraryHomeMapper.rows(notes: notes, searchIds: ["b"], now: now, calendar: chicago).flatMap(\.notes).map(\.id), ["b"])
}
```

- `testPhaseIsEmptyNoResultsOrErrorAsDesigned` (D20)

```swift
func testPhaseIsEmptyNoResultsOrErrorAsDesigned() {
    XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: ""), .empty)
    XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: false, sections: [], query: "zzz"), .noResults)
    XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [], query: ""), .error)
    XCTAssertEqual(LibraryHomeMapper.phase(isLoading: false, loadFailed: true, sections: [NoteSection(title: "Today", notes: [.stub(id: "a")])], query: ""), .list)
}
```

- [ ] **Step 1: Gate:** the Task 12 file check still passes (it is in the same phase); else report BLOCKED with Task 12's park line
- [ ] **Step 2: Write the listed tests**: map `.empty`/`.noResults`/`.error` to d2m's real state names; run them through the verifier (`MakeReadyCaptureTests/LibraryHomeMapperTests`), watch them fail
- [ ] **Step 3:** Implement the mapper and the container to the Behaviour; add refs and re-sync
- [ ] **Step 4: Run them, watch them pass**; `cd iphone && swiftlint` adds no finding; `/transition-review` on the diff if it touches motion
- [ ] **Step 5: Commit**: `feat(notes): Library section lists notes`

### Task 14: `NoteEditorContainer`, the three D17 routes, launch flush
App: iphone
Phase: 5
Recipe: /push-page

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Notes/NoteEditorContainer.swift` — hosts d2m's `note-editor` screen with the codec and `NoteAutosaveController`
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-120` — both cases `isFullScreen` (`:151`), if Task 13 has not
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:175-221` — `page(for:)` rows; `:96-99` — the "Write a note" row pushes `.newNote(flowId: UUID())` on `model.tab` (RS2, R2); `:130` `.task` — start `NotesConnectivity` and `await NoteSaveQueue.shared.flush()` once a session exists
- Create: `iphone/MakeReady/UI2/Containers/Notes/NoteEntry.swift` — the "Write a note" row label and its push (pattern `InviteEntry.swift:1-46`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — refs; `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/NoteEditorContainerTests.swift`

**Interfaces:**
- Consumes: `NoteDocumentCodec` (Task 12); `NoteAutosaveController` (Task 11); `NoteSaveQueue.shared`, `NotesConnectivity` (Task 10); `NoteActions` (Task 9); `UI2Destination.newNote`/`.noteEditor` (Task 13); d2m's `note-editor` view and C-001's `AttributedString` + `NSRange` binding (D9), by their real names
- Produces: `UI2Destination.newNote(flowId: UUID)`, `UI2Destination.noteEditor(noteId: String)`; `NoteEntry.rowLabel` = `"Write a note"`, `NoteEntry.open(on:model:)`

**Behaviour:**
- three routes open the editor: the Add menu's "Write a note" → `.newNote` on the current tab; library compose → `.newNote`; a row → `.noteEditor`; all through `UI2Navigator`, never `.sheet`/`.fullScreenCover`, no deep link (D17)
- both destinations are full screen, with no TabBar (D17)
- a new note opens with the keyboard up and the caret at the start, zero taps (D9, D5; d2m's new-note state; walk item 2)
- open: `.noteEditor` parses the stored `content` once (`loadOne` refreshes in the background); `.newNote` starts empty with no request (D9, D10; walk item 4)
- each edit serializes on the controller's save only: the container hands `edited` the latest `serialize(doc)` through the debounce, never per keystroke (D9, D12)
- back → `await controller.leave()` before popping; `scenePhase` → `.background` → `flush()` (D12, D10)
- `onStomped` → `NoteActions().load()` in the background; the editor keeps its text (D7; Task 11 tests the callback)
- the editor never lifts itself by a manual keyboard offset (standing trap; `/transition-review`)
- the queue flushes on launch from the shell's `.task` once signed in, and on connectivity (D24; Task 10 tests the flush)
- C-001 keeps the system keyboard: `inputView == nil`, `keyboardType == .default` (D16)

> ⚠ build-time risk (F10): D16's `inputView == nil` lives inside d2m's C-001 `UITextView`. Host C-001 in a `MakeReadyCaptureTests` window and find the `UITextView` in its hierarchy; if C-001 hides it, `request_project_change` for a test hook (D1) and report it.

**Tests:**
- `testWriteANoteRowPushesAFreshNewNoteOnTheCurrentTab` (D17)

```swift
func testWriteANoteRowPushesAFreshNewNoteOnTheCurrentTab() {
    var model = UI2ShellModel(); model.tab = .search
    let binding = Binding(get: { model }, set: { model = $0 })
    NoteEntry.open(on: .search, model: binding)
    NoteEntry.open(on: .search, model: binding)
    guard case .newNote(let a) = model.path(for: .search)[0], case .newNote(let b) = model.path(for: .search)[1] else { return XCTFail("not newNote") }
    XCTAssertNotEqual(a, b)
    XCTAssertTrue(UI2Destination.newNote(flowId: a).isFullScreen)
    XCTAssertTrue(UI2Destination.noteEditor(noteId: "n1").isFullScreen)
    XCTAssertTrue(UI2Shell.addMenuActions.contains { $0.label == NoteEntry.rowLabel })
}
```

- `testBackLeavesThroughTheControllerSoAnEmptiedNoteIsDeleted` (D10, D12)

```swift
func testBackLeavesThroughTheControllerSoAnEmptiedNoteIsDeleted() async {
    let (container, api) = makeEditor(noteId: "n1", content: "# Old\nx", stubDelete: "n1")
    container.model.setText(AttributedString(""))
    await container.model.back()
    XCTAssertEqual(api.calls.last?.method, "DELETE")
}
```

- `testBackgroundFlushesThePendingEdit` (D12)

```swift
func testBackgroundFlushesThePendingEdit() async {
    let (container, api) = makeEditor(noteId: "n1", content: "# Old", stubPatch: "n1")
    container.model.setText(NoteDocumentCodec.parse("# New"))
    await container.model.scenePhaseChanged(.background)
    XCTAssertEqual(api.calls.last?.body?["content"] as? String, "# New")
}
```

- `testTheEditorKeepsTheSystemKeyboard` (D16, F10)

```swift
func testTheEditorKeepsTheSystemKeyboard() throws {
    let textView = try XCTUnwrap(hostAndFindTextView(newNoteEditor()))
    XCTAssertNil(textView.inputView)
    XCTAssertEqual(textView.keyboardType, .default)
}
```

- [ ] **Step 1: Gate:** the Task 12 file check still passes; else report BLOCKED with Task 12's park line
- [ ] **Step 2: Write the listed tests**: `container.model` is the container's `@Observable` model (`setText`, `back()`, `scenePhaseChanged(_:)`); `hostAndFindTextView` hosts the view in a `UIWindow` and walks subviews; run them through the verifier (`MakeReadyCaptureTests/NoteEditorContainerTests`), watch them fail
- [ ] **Step 3:** Implement the container, the destinations, `page(for:)`, `NoteEntry`, the menu branch and the launch flush to the Behaviour; add refs and re-sync
- [ ] **Step 4: Run them plus every `Note*Tests`, watch them pass**; `cd iphone && swiftlint` adds no finding; run `/transition-review` on the diff
- [ ] **Step 5: Commit**: `feat(notes): note editor wiring and the three entry routes`
