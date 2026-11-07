# text-activity — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** replace the 1.0 parallel program/group activity tables with frozen lesson versions holding one JSON document per activity, serve them through the §Contract endpoints, and wire the iPhone editor and full-screen viewer onto them.

**Architecture:** the server adds `LessonVersion`, `ContentActivity`, `ProgramVersion(+Lesson)`, `ScheduledLesson` and the empty progress tables beside the old ones, moves every reader onto them, removes the old routes and services, and parks the destructive drop under `server/atlas/cutover/` for the owner's runbook. The iPhone app moves its models, `AppState` and Actions to the new shapes, wires the d2m-built editor and player screens through new `UI2Destination` cases, and drives the player with a pure `ViewerEngine` tested against shared JSON vectors.

**Tech Stack:** server: Express, zod, Prisma, Atlas (YAML → HCL), PostgreSQL, vitest + supertest. iphone: Swift 5, SwiftUI, `@Observable` + Actions, UIKit (`UIPanGestureRecognizer`, `CADisplayLink`), AVKit, WebKit, XCTest.

**Spec:** `docs/features/text-activity/SPEC.md` — and its normative sources `docs/features/activity-viewer/01-experience.md`, `02-content-schema.md`, `05-data-model.md` (the SPEC wins where they differ).

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(text-activity): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–5 | The new tables exist, a document validates, and the draft and activity endpoints answer per §Contract with D31/D32/D34/D35 enforced |
| 2 | server | 6–10 | The old activity surface is gone; sync core, publish, program/lesson reads and writes, templates and program export run on the new model |
| 3 | server | 11–15 | Enrollments, sync routes, search, notes, home, analytics and every other reader run on the new model |
| 4 | server | 16–19 | Boot chain and scripts are clean, fixtures seed the new model, export/import converts 1.0 content, the cutover drop and runbook are written — and the contract freezes |
| 5 | iphone | 20–23 | d2m has the editor changes; models, `AppState`, Actions and the disk cache run on the frozen contract |
| 6 | iphone | 24–25 | The Text tile creates, the editor opens from every entry point, edits round-trip through Done, and the background image picks from the library |
| 7 | iphone | 26–27 | The viewer engine passes the shared vectors and the full-screen viewer plays a lesson's draft from the editor |

---

### Task 1: The new model's tables, columns and the one-draft index
App: server
Phase: 1
Recipe: `/api` (server house rules) · SPEC §Schema & API changes + §Data plan · memory pattern `20261103120000_master_search_recents.sql:3-7` (TEXT id_type DO-block)

**Files:**
- Modify: `server/schema/schema.yaml` — add the SC1 models, the SC2/SC3/SC4/SC5/SC6/SC10/SC11 columns; make the listed old columns optional. Old models stay (removed in Task 19)
- Modify: `server/schema/enums.yaml` — add `LessonVersionStatus { DRAFT, PUBLISHED }`
- Generated: `server/prisma/schema.prisma`, `server/atlas/.schema.hcl` — via `npm run schema:generate`
- Create: `server/atlas/migrations/<ts>_text_activity_model.sql` — generated by atlas diff, then every `CREATE TABLE` for a new table wrapped in the TEXT `id_type` DO-block before the first commit; `migrate hash` after
- Create: `server/atlas/migrations/<ts>_text_activity_draft_index.sql` — hand migration via `migrate new`, SC13
- Test: `server/test/text-activity-migration.test.ts` — static SQL checks + live index behaviour on the lease

**Interfaces:**
- Produces Prisma models `LessonVersion` (`lesson_versions`), `ContentActivity` (`content_activities`, D29), `ProgramVersion` (`program_versions`), `ProgramVersionLesson` (`program_version_lessons`), `ScheduledLesson` (`scheduled_lessons`), `LessonProgress` (`lesson_progress`), `ActivityProgress` (`activity_progress`); new columns `Lesson.programId`, `Lesson.position`, `Lesson.deletedAt`, `Enrollment.programVersionId`, `StudyProgram.currentVersionId`, `Event.scheduledLessonId`, `AiLessonSummary.scheduledLessonId`, `LessonTemplateActivity.kind`, `LessonTemplateActivity.document`, `ClientEvent.scheduledLessonId`, `ClientEvent.activityKey`, `ClientEvent.kind`. Every later server task consumes these names.

The schema, in Prisma notation (write it as YAML in the house format; relation names as the generator needs):

```prisma
model LessonVersion {            // lesson_versions — SC1, D31, D36
  id               String  @id @default(uuid())
  lessonId         String                      // → lessons, onDelete Cascade (NOT nullable: D36 supersedes 05 §2)
  enrollmentId     String?                     // → enrollments, onDelete Cascade
  number           Int
  status           LessonVersionStatus @default(DRAFT)
  title            String?
  contentHash      String  @default("")
  estimatedSeconds Int?
  basedOnVersionId String?                     // → lesson_versions, onDelete SetNull
  publishedAt      DateTime?
  publishedById    String?                     // → users, onDelete SetNull
  createdAt        DateTime @default(now())
  updatedAt        DateTime @updatedAt
  @@index([lessonId]) @@index([enrollmentId])
  // NO @@unique here: both unique keys are NULLS NOT DISTINCT, in the SC13 hand migration
}
model ContentActivity {          // content_activities — SC1, D29
  id String @id @default(uuid())
  lessonVersionId String         // → lesson_versions, onDelete Cascade
  activityKey String
  position Int
  kind String
  title String
  document Json
  estimatedSeconds Int?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  @@unique([lessonVersionId, activityKey]) @@unique([lessonVersionId, position]) @@index([activityKey])
}
model ProgramVersion {           // program_versions
  id String @id @default(uuid())
  programId String               // → study_programs, onDelete Cascade
  number Int
  changeSummary String? @db.Text
  publishedAt DateTime @default(now())
  publishedById String?          // → users, onDelete SetNull
  @@unique([programId, number])
}
model ProgramVersionLesson {     // program_version_lessons
  programVersionId String        // → program_versions, onDelete Cascade
  lessonId String                // → lessons, onDelete Restrict
  lessonVersionId String         // → lesson_versions, onDelete Restrict
  position Int
  @@id([programVersionId, lessonId])
}
model ScheduledLesson {          // scheduled_lessons — SC1, SC10
  id String @id @default(uuid())
  code String? @unique
  enrollmentId String            // → enrollments, onDelete Cascade
  lessonId String?               // → lessons, onDelete SetNull
  scheduledDate DateTime
  currentVersionId String        // → lesson_versions, onDelete Restrict
  removedAt DateTime?
  smsSentAt DateTime?
  templateId String?             // → lesson_templates, onDelete SetNull
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  @@unique([enrollmentId, lessonId]) @@index([currentVersionId]) @@index([scheduledDate])
}
model LessonProgress {           // lesson_progress — D8: created empty
  memberId String                // → the same table MemberLessonProgress.memberId references, onDelete Cascade
  scheduledLessonId String       // → scheduled_lessons, onDelete Cascade
  startedAt DateTime @default(now())
  completedAt DateTime?
  pinnedVersionId String?        // → lesson_versions, onDelete SetNull
  @@id([memberId, scheduledLessonId])
}
model ActivityProgress {         // activity_progress — D8: created empty
  memberId String                // as LessonProgress
  scheduledLessonId String       // → scheduled_lessons, onDelete Cascade
  activityKey String
  startedAt DateTime @default(now())
  completedAt DateTime?
  state Json?
  @@id([memberId, scheduledLessonId, activityKey])
}
// Column changes (all new columns nullable until the cutover, §Data plan step 1):
// Lesson:       + programId String? (→ study_programs, Cascade) + position Int? + deletedAt DateTime?
//               + @@index([programId, position]); studyProgramId, dayNumber, title, estimatedMinutes become optional
// Enrollment:   + programVersionId String? (→ program_versions, SetNull)
// StudyProgram: + currentVersionId String? (→ program_versions, SetNull)
// Event:        + scheduledLessonId String? @unique (→ scheduled_lessons, SetNull); lessonScheduleId stays
// AiLessonSummary: + scheduledLessonId String? (→ scheduled_lessons, Cascade); its lessonScheduleId becomes optional
// LessonTemplateActivity: + kind String? + document Json?; its `type` becomes optional
// ClientEvent:  + scheduledLessonId String? + activityKey String? + kind String? (no FKs, analytics rows)
```

SC13, the hand migration, verbatim:

```sql
-- text-activity D31/SC13: hand-managed. atlas.hcl's drop_index skip keeps these out of migrate diff.
-- enrollmentId is NULL for program versions; NULLS NOT DISTINCT makes NULL collide with NULL.
CREATE UNIQUE INDEX "lesson_versions_one_draft_key"
  ON "lesson_versions" ("lessonId", "enrollmentId") NULLS NOT DISTINCT
  WHERE "status" = 'DRAFT';
CREATE UNIQUE INDEX "lesson_versions_number_key"
  ON "lesson_versions" ("lessonId", "enrollmentId", "number") NULLS NOT DISTINCT;
```

**Behaviour:**
- every new table's id and FK columns take `users.id`'s real type through the DO-block, never a literal `uuid` (Data plan; memory: dev/prod ids are TEXT)
- no old table, column or row is dropped by any migration in `server/atlas/migrations/` (D27, D30)
- two DRAFT versions for one `(lessonId, NULL)` are refused by the database; one DRAFT for `(lessonId, NULL)` and one for `(lessonId, enrollmentA)` coexist (D31)
- two versions with the same `(lessonId, NULL, number)` are refused (D31)

**Pattern:**
- `server/test/enrollment-drafts-migration.test.ts:1-40` — static migration assertions
- `server/atlas/migrations/20261104000602_master_search_indexes.sql` — hand migration header and placement
- `server/test/helpers/master-search-db.ts:7` — `assertSearchLease` for a lease-only DB test

**Tests:**
- `wraps every new table in the id_type DO-block` (Data plan)

```ts
it('wraps every new table in the id_type DO-block', () => {
  const sql = findMigration('CREATE TABLE "lesson_versions"')
  for (const t of ['lesson_versions','content_activities','program_versions','program_version_lessons','scheduled_lessons','lesson_progress','activity_progress'])
    expect(sql).toContain(`CREATE TABLE "${t}"`)
  expect(sql).toMatch(/format_type\(atttypid, atttypmod\) INTO id_type/)
  expect(sql).not.toMatch(/"(lessonId|lessonVersionId|enrollmentId|programId|scheduledLessonId|currentVersionId)" uuid/)
})
```

- `no migration drops an old table` (D27, D30)

```ts
it('no migration drops an old table', () => {
  const all = readAllMigrations()
  expect(all).not.toMatch(/DROP TABLE[^;]*"(lesson_activities|lesson_schedules|text_themes|study_program_versions)"/)
})
```

- `refuses a second program draft for one lesson` (D31)

```ts
it('refuses a second program draft for one lesson', async () => {
  const { lessonId } = await seedLesson()
  await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'DRAFT' })
  await expect(insertVersion({ lessonId, enrollmentId: null, number: 2, status: 'DRAFT' })).rejects.toMatchObject({ code: '23505' })
})
```

- `allows a program draft beside a group draft, and a draft beside published versions` (D31)

```ts
it('allows a program draft beside a group draft, and a draft beside published versions', async () => {
  const { lessonId, enrollmentId } = await seedLessonWithEnrollment()
  await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })
  await insertVersion({ lessonId, enrollmentId: null, number: 2, status: 'DRAFT' })
  await expect(insertVersion({ lessonId, enrollmentId, number: 1, status: 'DRAFT' })).resolves.toBeDefined()
})
```

- `refuses a duplicate version number with a NULL enrollment` (D31)

```ts
it('refuses a duplicate version number with a NULL enrollment', async () => {
  const { lessonId } = await seedLesson()
  await insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })
  await expect(insertVersion({ lessonId, enrollmentId: null, number: 1, status: 'PUBLISHED' })).rejects.toMatchObject({ code: '23505' })
})
```

(`insertVersion` / `seedLesson*` are local helpers in the test file using raw `pg` on `TEST_DATABASE_URL`, so the P2002 path does not depend on Prisma's index knowledge.)

- [ ] **Step 1: Write the listed tests** — in `server/test/text-activity-migration.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (database tests run only in its lease; `<builder>` is the directory your brief names)
- [ ] **Step 3: Edit the YAML; generate** with `cd server && npm run schema:generate`, then `cd atlas && ../scripts/atlas.sh migrate diff text_activity_model --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev` (never `npm run schema:diff`: it reads the 1Password pipe); wrap each new table's DDL in the DO-block; `../scripts/atlas.sh migrate new text_activity_draft_index --env local --var database_url=…` and paste SC13; `../scripts/atlas.sh migrate hash --env local --var database_url=…`
- [ ] **Step 4: Run `cd server && npm run schema:validate && npx --no-install tsc --noEmit`, confirm a second `migrate diff` is empty, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): lesson versions, content activities and the one-draft index`

### Task 2: The activity document — validation, size, refs, text and hash
App: server
Phase: 1
Recipe: `/api` · SPEC §Contract "Shapes" + `docs/features/activity-viewer/02-content-schema.md` §2–§9

**Files:**
- Create: `server/src/services/activity-document.ts` — pure functions over a document; no Prisma
- Test: `server/src/services/__tests__/activity-document.test.ts`

**Interfaces:**
- Produces: `ACTIVITY_KINDS` — `['text','bible','video','youtube','write','poll']`; `MAX_DOCUMENT_BYTES` — `262144`; `parseActivityDocument(input: unknown, kind: string)` — returns `{ ok: true, document }` (the input object, unknown fields intact) or `{ ok: false, code: 'VALIDATION' | 'TOO_LARGE', error: string }`; `documentMediaRefs(doc)` — returns `{ mediaIds: string[], videoIds: string[] }`, de-duplicated; `documentPassages(doc)` — returns the `content.passages` list (empty when absent); `documentText(doc)` — returns the canvas objects' (and `write`/`poll` prompt's) `text` joined with `\n` in reading order; `hashLessonContent({ title, activities })` — `activities` are `{ activityKey, position, kind, title, document }`, returns a 64-char hex sha256; `estimateDocumentSeconds(doc)` — returns seconds or `null`.

**Behaviour:**
- size is checked first: `Buffer.byteLength(JSON.stringify(input))` above `262144` → `TOO_LARGE` "Activity document exceeds 256 KB" (D3, §Contract)
- envelope: `schemaVersion === 1`; `kind` in `ACTIVITY_KINDS` and equal to the `kind` argument; `background.color` matches `^#[0-9A-Fa-f]{6}$`; optional `background.image { mediaId: string, focal { x, y } in [0,1] }`, `wash { color hex, opacity in [0,1] }`, `motion { mode: scroll|fixed|parallax, rate in [0,1] }`; `chrome.topAction` in `share|menu|none`; `fallback { title, body }` strings (02 §2, §5)
- content by kind: `text`/`bible` → `type: "canvas"`, `verticalAnchor: center|top`, `objects[]` (02 §3); `bible` may carry `passages[{ bookNumber, chapterStart, verseStart, chapterEnd, verseEnd }]` integers; `video`, `youtube`, `write`, `poll` → the 02 §8 shapes (D3)
- a text object requires `id`, `text`, `font` in `display|sans|serif|mono` (D18), `weight` in `400|500|700`, `size > 0`, `color` hex, `alignment` in `left|center|right`, `transform { x, y, width > 0, scale > 0, rotation }`; `role`, `lineHeight`, `tracking`, `label`, `listStyle`, `startNumber`, `reference`, `animation`, `effect`, `marks`, `highlights` are optional with the 02 §3 enums; every `marks`/`highlights` range has integer `0 ≤ start < end` (02 §3)
- actions: each `{ id, kind in addToPrayerList|write|openUrl|nextLesson, label, placement in inline|pinned, payload object }`; more than one `pinned` → `VALIDATION` "At most one pinned action per page" (D19)
- every zod object is `.passthrough()`: an unknown field anywhere is kept in the returned document, never stripped (§Contract "Shapes"; 02 §9)
- `documentMediaRefs` reads `background.image.mediaId`, `content.posterMediaId`, `content.presenter.avatarMediaId` into `mediaIds` and `content.videoId` into `videoIds` (D34, 05 §4)
- `documentText` orders canvas objects by `transform.y` ascending, ties by array index (02 §3 "Reading order")
- `hashLessonContent` serializes with keys sorted recursively and activities sorted by `position`, so key order never changes the hash and any title/kind/document/position change does (D20)
- `estimateDocumentSeconds`: canvas and `write` → `ceil(words / WPM × 60)` using the words-per-minute constant already in `services/lesson-estimate.ts`; `video`/`youtube` → `null` (filled from media at save, Task 5)

**Tests:**
- `accepts the 02 §11 example and one example of every other kind` (D3)

```ts
it('accepts the 02 §11 example and one example of every other kind', () => {
  for (const [kind, doc] of Object.entries(EXAMPLES)) expect(parseActivityDocument(doc, kind)).toMatchObject({ ok: true })
})
```

- `keeps unknown fields at every level` (§Contract, 02 §9)

```ts
it('keeps unknown fields at every level', () => {
  const doc = { ...EXAMPLES.text, futureField: { a: 1 } }
  doc.content.objects[0] = { ...doc.content.objects[0], glow: 'soft' }
  const r = parseActivityDocument(doc, 'text')
  expect(r.ok && r.document.futureField).toEqual({ a: 1 })
  expect(r.ok && r.document.content.objects[0].glow).toBe('soft')
})
```

- `refuses a kind mismatch, an unknown kind and a higher schemaVersion` (D3, SC9)

```ts
it('refuses a kind mismatch, an unknown kind and a higher schemaVersion', () => {
  expect(parseActivityDocument(EXAMPLES.text, 'bible')).toMatchObject({ ok: false, code: 'VALIDATION' })
  expect(parseActivityDocument({ ...EXAMPLES.text, kind: 'quiz' }, 'quiz')).toMatchObject({ ok: false, code: 'VALIDATION' })
  expect(parseActivityDocument({ ...EXAMPLES.text, schemaVersion: 2 }, 'text')).toMatchObject({ ok: false, code: 'VALIDATION' })
})
```

- `refuses two pinned actions` (D19)

```ts
it('refuses two pinned actions', () => {
  const a = { id: 'a', kind: 'openUrl', label: 'Go', placement: 'pinned', payload: { url: 'https://x.org' } }
  const r = parseActivityDocument({ ...EXAMPLES.text, actions: [a, { ...a, id: 'b' }] }, 'text')
  expect(r).toMatchObject({ ok: false, code: 'VALIDATION', error: 'At most one pinned action per page' })
})
```

- `accepts exactly 256 KB and refuses one byte more` (D3)

```ts
it('accepts exactly 256 KB and refuses one byte more', () => {
  const at = padToBytes(EXAMPLES.text, 262144)
  expect(parseActivityDocument(at, 'text')).toMatchObject({ ok: true })
  expect(parseActivityDocument(padToBytes(EXAMPLES.text, 262145), 'text')).toMatchObject({ ok: false, code: 'TOO_LARGE' })
})
```

- `collects media and video refs` (D34)

```ts
it('collects media and video refs', () => {
  expect(documentMediaRefs(withImage(EXAMPLES.text, 'm1'))).toEqual({ mediaIds: ['m1'], videoIds: [] })
  expect(documentMediaRefs(EXAMPLES.video)).toEqual({ mediaIds: ['poster1', 'avatar1'], videoIds: ['vid1'] })
})
```

- `reads text top to bottom` (02 §3)

```ts
it('reads text top to bottom', () => {
  expect(documentText(EXAMPLES.text)).toBe('PRAYER\nGod, sometimes it\'s hard to focus my mind on good things…')
})
```

- `hash ignores key order and sees a position change` (D20)

```ts
it('hash ignores key order and sees a position change', () => {
  const a = { activityKey: 'k1', position: 0, kind: 'text', title: 'Text', document: { b: 1, a: 2 } }
  const h = hashLessonContent({ title: 'Day 1', activities: [a] })
  expect(hashLessonContent({ title: 'Day 1', activities: [{ ...a, document: { a: 2, b: 1 } }] })).toBe(h)
  expect(hashLessonContent({ title: 'Day 1', activities: [{ ...a, position: 1 }] })).not.toBe(h)
})
```

(`EXAMPLES`, `padToBytes`, `withImage` are fixtures in the test file: `EXAMPLES.text` is 02 §11 verbatim; `EXAMPLES.video` names `videoId: 'vid1'`, `posterMediaId: 'poster1'`, `presenter.avatarMediaId: 'avatar1'`; `padToBytes` grows `fallback.body` to an exact byte length.)

- [ ] **Step 1: Write the listed tests** — in `server/src/services/__tests__/activity-document.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run src/services/__tests__/activity-document.test.ts`, watch them fail** — module not found
- [ ] **Step 3: Implement `server/src/services/activity-document.ts` to the Behaviour**
- [ ] **Step 4: Run the same command and `npx --no-install tsc --noEmit`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): activity document validation, refs and content hash`

### Task 3: Media in documents — access, usage rows, the media map and the delete guards
App: server
Phase: 1
Recipe: `/api` · SPEC D34, SC7

**Files:**
- Create: `server/src/services/content-errors.ts` — `ContentError` and the route helper that writes `{ success: false, error, code }`
- Create: `server/src/services/content-media.service.ts` — D34's checks, `MediaUsage` sync, `MediaMap` building
- Modify: `server/src/services/content.ts:170` — `deleteMedia` refuses with `IN_USE`
- Modify: `server/src/routes/media.ts:1092`, `server/src/routes/videos.ts:1165` — map `IN_USE` to 409
- Create: `server/test/helpers/content-world.ts` — the shared world for this feature's DB tests
- Test: `server/test/content-media.test.ts`

**Interfaces:**
- Produces: `ContentError` — class with `status: number`, `code: 'VALIDATION'|'NOT_FOUND'|'NOT_DRAFT'|'CONFLICT'|'TOO_LARGE'|'IN_USE'`, `message`; `sendContentError(res, err)` — writes `{ success: false, error: message, code }` with `status` for a `ContentError`, rethrows anything else; `assertDocumentMediaAllowed(tx, userId, refs)` — `refs` from `documentMediaRefs`, throws `ContentError(400, 'VALIDATION')` naming the first refused id; `syncActivityMediaUsage(tx, activityKey)` — returns nothing; `buildMediaMap(tx, documents)` — returns `MediaMap` keyed by every `mediaId` and every `videoId`'s media id the documents name
- Produces (helper): `createContentWorld()` — returns `{ leader, outsider, orgId, otherOrgId, programId, lessonId, draftVersionId }` where `leader`/`outsider` are `TestUserWithToken` (`test/helpers/api-auth.ts:14`), the leader can manage `orgId` content and the outsider only `otherOrgId`'s, the program sits in `orgId`, and the lesson has `programId`, `position: 1` and one empty DRAFT `LessonVersion` (`number: 1`, `title: 'Day 1'`); `createMedia(orgId, opts?)` — returns a `Media` row (`opts.videoId` links a `Video`); `destroyContentWorld(world)`
- Consumes: `documentMediaRefs` (Task 2); `canManageOrgContent` (`services/permission.ts:276`); `MAKEREADY_ORG_ID` (`services/makeready-library.ts`)

**Behaviour:**
- a `mediaId` is allowed when its `Media.organizationId` is `MAKEREADY_ORG_ID` or an org where `canManageOrgContent(userId, orgId, null)` is true; a `videoId` is allowed through its `Media` row (`Media.videoId`) by the same rule; a missing row is refused (D34)
- `syncActivityMediaUsage` deletes `MediaUsage` rows with `usageType: 'ACTIVITY'` and `resourceId = activityKey`, then inserts one row per distinct media id named by ANY `ContentActivity` with that key, across every version (D34, SC7)
- `deleteMedia` and video delete answer 409 `{ success: false, error: 'This media is used by an activity', code: 'IN_USE' }` while an `ACTIVITY` usage row names the media (or the video's media); usage rows of other types keep today's behaviour (D34)
- `MediaMap` entry: `url` = `Media.url`, `width`, `height`, `kind` = `'video'` when `Media.type === 'video'` else `'image'`, `posterUrl` = `Media.thumbnailUrl`, `durationSeconds` = `Media.duration`, `uploaderName` = the uploader's display name, `playbackUrl` = the linked `Video`'s Stream playback URL when there is one; absent values are omitted, not null (§Contract `MediaMap`)

**Pattern:**
- `server/test/group-leader-content.test.ts` — creating an org leader with an API key
- `server/src/services/media-library.ts:209` — `recordMediaUsage` (the row shape)

**Tests:**
- `refuses another org's media and video, allows own and library media` (D34)

```ts
it("refuses another org's media and video, allows own and library media", async () => {
  const own = await createMedia(w.orgId), lib = await createMedia(MAKEREADY_ORG_ID)
  const foreign = await createMedia(w.otherOrgId), foreignVid = await createMedia(w.otherOrgId, { videoId: 'v-x' })
  await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [own.id, lib.id], videoIds: [] }))).resolves.toBeUndefined()
  await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [foreign.id], videoIds: [] }))).rejects.toMatchObject({ status: 400, code: 'VALIDATION' })
  await expect(prisma.$transaction(tx => assertDocumentMediaAllowed(tx, w.leader.user.id, { mediaIds: [], videoIds: ['v-x'] }))).rejects.toMatchObject({ code: 'VALIDATION' })
})
```

- `usage is the union over every version holding the key` (D34)

```ts
it('usage is the union over every version holding the key', async () => {
  const m1 = await createMedia(w.orgId), m2 = await createMedia(w.orgId)
  await seedActivity(w, { activityKey: 'k1', versionStatus: 'PUBLISHED', mediaId: m1.id })
  await seedActivity(w, { activityKey: 'k1', versionStatus: 'DRAFT', mediaId: m2.id })
  await prisma.$transaction(tx => syncActivityMediaUsage(tx, 'k1'))
  const rows = await prisma.mediaUsage.findMany({ where: { usageType: 'ACTIVITY', resourceId: 'k1' } })
  expect(rows.map(r => r.mediaId).sort()).toEqual([m1.id, m2.id].sort())
})
```

- `media and video delete answer 409 IN_USE while an activity uses them` (D34)

```ts
it('media and video delete answer 409 IN_USE while an activity uses them', async () => {
  const m = await createMedia(w.orgId, { videoId: 'v-1' })
  await prisma.mediaUsage.create({ data: { mediaId: m.id, usageType: 'ACTIVITY', resourceId: 'k9' } })
  const r1 = await request(app).delete(`/api/media/${m.id}`).set('Authorization', bearer(w.leader.token))
  expect(r1.status).toBe(409); expect(r1.body).toMatchObject({ success: false, code: 'IN_USE' })
  const r2 = await request(app).delete(`/api/videos/v-1`).set('Authorization', bearer(w.leader.token))
  expect(r2.status).toBe(409); expect(r2.body.code).toBe('IN_USE')
})
```

- `the media map carries the contract's fields` (§Contract)

```ts
it("the media map carries the contract's fields", async () => {
  const m = await createMedia(w.orgId, { width: 1080, height: 1920 })
  const map = await prisma.$transaction(tx => buildMediaMap(tx, [withImage(EXAMPLE_TEXT, m.id)]))
  expect(map[m.id]).toMatchObject({ url: m.url, width: 1080, height: 1920, kind: 'image' })
  expect(map[m.id]).not.toHaveProperty('playbackUrl')
})
```

(`seedActivity` creates a `LessonVersion` of the given status on `w.lessonId` and one `ContentActivity`; add it to `content-world.ts`. Use the delete paths the routes actually mount; read `media.ts:1092` and `videos.ts:1165` for them.)

- [ ] **Step 1: Write the helper and the listed tests** — `server/test/helpers/content-world.ts`, `server/test/content-media.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `content-errors.ts`, `content-media.service.ts` and the two delete guards to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): media access, usage and delete guard for activity documents`

### Task 4: Reading a draft and a version — access, draft creation, routes
App: server
Phase: 1
Recipe: `/api` · SPEC §Contract rows 1–2, D31, D35

**Files:**
- Create: `server/src/services/lesson-version.service.ts` — access resolution and the read side (Task 5 adds the writes)
- Create: `server/src/routes/lessons.ts` — `GET /:id/draft`, mounted at `/api/lessons`
- Create: `server/src/routes/lesson-versions.ts` — `GET /:id`, mounted at `/api/lesson-versions`
- Modify: `server/src/index.ts` — mount both beside the program routes
- Test: `server/test/lesson-versions-read.test.ts`

**Interfaces:**
- Produces: `resolveVersionAccess(tx, userId, versionId)` — returns the version with its lesson and program (`organizationId`, `creatorId`) or `null`; `resolveLessonAccess(tx, userId, lessonId)` — the same for a live lesson; `getOrCreateDraft(userId, lessonId)` — returns `LessonVersionPayload` or `null`; `getLessonVersion(userId, versionId)` — returns `LessonVersionPayload` or `null`; `LessonVersionPayload` — `{ version: LessonVersion, activities: ContentActivity[], media: MediaMap }`; `serializeLessonVersion(v)`, `serializeContentActivity(a)` — the §Contract shapes
- Consumes: `buildMediaMap`, `ContentError`, `sendContentError` (Task 3); `canManageOrgContent`

The frozen contract rows this task produces, verbatim from SPEC §Contract:

```
| `GET /api/lessons/:id/draft` | server | iphone (editor, picker) | org content | — | `{ version: LessonVersion, activities: ContentActivity[], media: MediaMap }`. Creates the draft from the latest published version if none exists, keeping keys (D31) | 404 |
| `GET /api/lesson-versions/:id` | server | iphone (viewer) | org content | — | Same shape as above, read-only | 404 |
ContentActivity { id, lessonVersionId, activityKey, position, kind, title, document, estimatedSeconds }
LessonVersion   { id, lessonId, enrollmentId, number, status: 'DRAFT'|'PUBLISHED', title, estimatedSeconds, publishedAt }
MediaMap        { [mediaId]: { url, width?, height?, kind: 'image'|'video', playbackUrl?, posterUrl?, durationSeconds?, uploaderName? } }
```

**Behaviour:**
- access: allowed when `canManageOrgContent(userId, program.organizationId, program.creatorId)`; a version with `enrollmentId` also allows a leader who can manage that enrollment — reuse the predicate behind `enrollmentManageFilter` (`routes/enrollments.ts:1910`), moved into `services/enrollment-access.ts` as `canManageEnrollment(userId, enrollmentId)` if it is not already a service export; no access, no row, or a lesson with `deletedAt` → 404 `{ success: false, error: 'Not found', code: 'NOT_FOUND' }` (D35, D36)
- `getOrCreateDraft` returns the `(lessonId, enrollmentId NULL)` DRAFT when one exists; otherwise inserts DRAFT `number = max(number)+1` (1 when none), `basedOnVersionId` = the latest PUBLISHED, copying its `title` and every activity's `activityKey`, `position`, `kind`, `title`, `document`, `estimatedSeconds`; on P2002 it re-reads the draft the winner created (D31)
- activities are returned ordered by `position` ascending
- the draft read never runs `syncActivityMediaUsage`: copied keys already have usage rows (D34 union)

**Tests:**
- `the draft keeps every activityKey of the latest published version` (D31, 05 §3)

```ts
it('the draft keeps every activityKey of the latest published version', async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }, { activityKey: 'k2' }])
  const res = await request(app).get(`/api/lessons/${pub.lessonId}/draft`).set('Authorization', bearer(w.leader.token))
  expect(res.status).toBe(200)
  expect(res.body.version).toMatchObject({ status: 'DRAFT', number: 2, enrollmentId: null })
  expect(res.body.activities.map((a: any) => a.activityKey)).toEqual(['k1', 'k2'])
  expect(res.body.media).toEqual({})
})
```

- `ten concurrent draft reads create one draft` (D31; F13 — runs on the verifier's atlas-migrated lease, which carries SC13)

```ts
it('ten concurrent draft reads create one draft', async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
  const res = await Promise.all(Array.from({ length: 10 }, () =>
    request(app).get(`/api/lessons/${pub.lessonId}/draft`).set('Authorization', bearer(w.leader.token))))
  expect(res.every(r => r.status === 200)).toBe(true)
  expect(new Set(res.map(r => r.body.version.id)).size).toBe(1)
  expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId, status: 'DRAFT' } })).toBe(1)
})
```

- `another org's leader gets 404 on both reads` (D35)

```ts
it("another org's leader gets 404 on both reads", async () => {
  const a = await request(app).get(`/api/lessons/${w.lessonId}/draft`).set('Authorization', bearer(w.outsider.token))
  const b = await request(app).get(`/api/lesson-versions/${w.draftVersionId}`).set('Authorization', bearer(w.outsider.token))
  expect([a.status, b.status]).toEqual([404, 404])
  expect(a.body).toMatchObject({ success: false, code: 'NOT_FOUND' })
})
```

- `a soft-deleted lesson has no draft` (D36)

```ts
it('a soft-deleted lesson has no draft', async () => {
  await prisma.lesson.update({ where: { id: w.lessonId }, data: { deletedAt: new Date() } })
  const res = await request(app).get(`/api/lessons/${w.lessonId}/draft`).set('Authorization', bearer(w.leader.token))
  expect(res.status).toBe(404)
})
```

- `a version read is read-only and returns the media map` (§Contract)

```ts
it('a version read is read-only and returns the media map', async () => {
  const m = await createMedia(w.orgId)
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1', mediaId: m.id }])
  const res = await request(app).get(`/api/lesson-versions/${pub.versionId}`).set('Authorization', bearer(w.leader.token))
  expect(res.body.version.status).toBe('PUBLISHED')
  expect(Object.keys(res.body.media)).toEqual([m.id])
  expect(await prisma.lessonVersion.count({ where: { lessonId: pub.lessonId } })).toBe(1)
})
```

(Add `seedPublishedLesson(w, activities)` → `{ lessonId, versionId }` to `content-world.ts`: a new lesson in `w.programId` with one PUBLISHED version number 1 holding the activities.)

- [ ] **Step 1: Write the listed tests** — in `server/test/lesson-versions-read.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the service, the two thin routers and the mounts to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): draft and lesson-version reads`

### Task 5: Writing a draft — create, replace, delete, reorder
App: server
Phase: 1
Recipe: `/api` · SPEC §Contract rows 3–6, D3, D32, D34

**Files:**
- Modify: `server/src/services/lesson-version.service.ts` — the four writes inside one locking helper
- Modify: `server/src/routes/lesson-versions.ts` — `POST /:id/activities`, `PATCH /:id/activities/order`
- Create: `server/src/routes/content-activities.ts` — `PUT /:id`, `DELETE /:id`, mounted at `/api/content-activities` (D29)
- Modify: `server/src/index.ts` — mount it
- Test: `server/test/content-activities-write.test.ts`

**Interfaces:**
- Produces: `withDraftLock(versionId, userId, fn)` — runs `fn(tx, version)` in one `$transaction` after `SELECT … FROM lesson_versions WHERE id = $1 FOR UPDATE`; `createActivity(userId, versionId, { kind, title, document })` → `{ activity, media }`; `replaceActivity(userId, activityId, { title?, document })` → `{ activity, media }`; `deleteActivity(userId, activityId)` → nothing; `reorderActivities(userId, versionId, activityIds)` → `ContentActivity[]`
- Consumes: `resolveVersionAccess`, `serializeContentActivity` (Task 4); `parseActivityDocument`, `documentMediaRefs`, `estimateDocumentSeconds` (Task 2); `assertDocumentMediaAllowed`, `syncActivityMediaUsage`, `buildMediaMap`, `ContentError` (Task 3)

The frozen contract rows this task produces, verbatim from SPEC §Contract:

```
| `POST /api/lesson-versions/:id/activities` | server | iphone (Text tile) | org content | `{ kind, title, document }` | `{ activity, media }`, new `activityKey`, appended | 400 `VALIDATION`, 404, 409 `NOT_DRAFT`/`CONFLICT`, 413 `TOO_LARGE` |
| `PUT /api/content-activities/:id` | server | iphone (editor Done) | org content | `{ title?, document }`, whole document | `{ activity, media }` | 400 `VALIDATION`, 404, 409 `NOT_DRAFT`, 413 `TOO_LARGE` |
| `DELETE /api/content-activities/:id` | server | iphone (empty back-out, rail delete) | org content | — | `{ success: true }`, positions closed up | 404, 409 `NOT_DRAFT` |
| `PATCH /api/lesson-versions/:id/activities/order` | server | iphone (rail reorder) | org content | `{ activityIds: string[] }`, exact set | `{ activities }` | 400 `VALIDATION`, 404, 409 `NOT_DRAFT`/`CONFLICT` |
```

**Behaviour:**
- every write runs inside `withDraftLock`: access per D35 (404 otherwise), then `status !== 'DRAFT'` → 409 `{ code: 'NOT_DRAFT', error: 'This lesson version is published' }` (D32)
- request bodies are zod-validated with `.passthrough()` on the outer object only where the contract allows extra keys; `kind` is a string, `title` a non-empty string ≤ 200 chars, `document` is checked by `parseActivityDocument(document, kind)` — `TOO_LARGE` → 413, `VALIDATION` → 400 (D3); PUT keeps the stored `kind`
- create: `activityKey` = a new uuid, `position` = max+1 (0 when empty) (05 §3)
- replace writes the whole `document` (and `title` when sent), recomputes `estimatedSeconds` — for `video` from the video's `Media.duration` when present (D3)
- before writing a document, `assertDocumentMediaAllowed`; after writing, `syncActivityMediaUsage(tx, activityKey)` (D34); delete also re-syncs, so a key held only by the deleted row loses its usage rows
- delete closes positions up; reorder requires `activityIds` to be exactly the version's set (no missing, extra or duplicate id) else 400 `VALIDATION`; position changes are two-phase inside the lock: every row to `position + 10000`, then each to its final index (D32)
- a P2002 inside a write → 409 `{ code: 'CONFLICT' }`; never a 500 (D32)
- responses: `{ activity, media }` where `media` is `buildMediaMap` over that one document; reorder returns `{ activities }`

**Tests:**
- `create appends with a new key; replace keeps it` (05 §3)

```ts
it('create appends with a new key; replace keeps it', async () => {
  const c = await post(w, w.draftVersionId, { kind: 'text', title: 'Text', document: EXAMPLE_TEXT })
  expect(c.status).toBe(201); expect(c.body.activity).toMatchObject({ position: 0, kind: 'text', title: 'Text' })
  const p = await put(w, c.body.activity.id, { document: { ...EXAMPLE_TEXT, extra: 1 } })
  expect(p.body.activity.activityKey).toBe(c.body.activity.activityKey)
  expect(p.body.activity.document.extra).toBe(1)
})
```

- `256 KB + 1 byte is 413 on POST and PUT` (D3)

```ts
it('256 KB + 1 byte is 413 on POST and PUT', async () => {
  const big = padToBytes(EXAMPLE_TEXT, 262145)
  expect((await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: big })).status).toBe(413)
  const c = await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT })
  const r = await put(w, c.body.activity.id, { document: big })
  expect(r.status).toBe(413); expect(r.body.code).toBe('TOO_LARGE')
})
```

- `a published version refuses every write with 409 NOT_DRAFT` (D32)

```ts
it('a published version refuses every write with 409 NOT_DRAFT', async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
  const [actId] = await activityIds(pub.versionId)
  const codes = [
    await post(w, pub.versionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT }),
    await put(w, actId, { document: EXAMPLE_TEXT }),
    await del(w, actId),
    await order(w, pub.versionId, [actId]),
  ].map(r => [r.status, r.body.code])
  expect(codes).toEqual(Array(4).fill([409, 'NOT_DRAFT']))
})
```

- `a foreign media id is refused and usage follows saves` (D34)

```ts
it('a foreign media id is refused and usage follows saves', async () => {
  const foreign = await createMedia(w.otherOrgId), own = await createMedia(w.orgId)
  expect((await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: withImage(EXAMPLE_TEXT, foreign.id) })).status).toBe(400)
  const c = await post(w, w.draftVersionId, { kind: 'text', title: 'T', document: withImage(EXAMPLE_TEXT, own.id) })
  expect(await usageIds(c.body.activity.activityKey)).toEqual([own.id])
  await del(w, c.body.activity.id)
  expect(await usageIds(c.body.activity.activityKey)).toEqual([])
})
```

- `delete closes up positions; reorder needs the exact set; double POST gives no 500` (D32)

```ts
it('delete closes up positions; reorder needs the exact set; double POST gives no 500', async () => {
  const body = { kind: 'text', title: 'T', document: EXAMPLE_TEXT }
  const [a, b] = await Promise.all([post(w, w.draftVersionId, body), post(w, w.draftVersionId, body)])
  expect([a.status, b.status].every(s => s === 201 || s === 409)).toBe(true)
  const c = await post(w, w.draftVersionId, body)
  const ids = await activityIds(w.draftVersionId)
  expect((await order(w, w.draftVersionId, ids.slice(1))).status).toBe(400)
  expect((await order(w, w.draftVersionId, [...ids].reverse())).body.activities.map((x: any) => x.id)).toEqual([...ids].reverse())
  await del(w, ids[0])
  expect((await positions(w.draftVersionId))).toEqual([...Array(ids.length - 1).keys()])
})
```

- `order with another version's ids is 400, and another org gets 404 on every write` (D35)

```ts
it("order with another version's ids is 400, and another org gets 404 on every write", async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'kx' }])
  expect((await order(w, w.draftVersionId, await activityIds(pub.versionId))).status).toBe(400)
  const o = { ...w, leader: w.outsider }
  expect((await post(o, w.draftVersionId, { kind: 'text', title: 'T', document: EXAMPLE_TEXT })).status).toBe(404)
})
```

(`post`, `put`, `del`, `order`, `activityIds`, `positions`, `usageIds` are thin local helpers over supertest/Prisma in the test file.)

- [ ] **Step 1: Write the listed tests** — in `server/test/content-activities-write.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `withDraftLock` and the four writes, the routes and the mount to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): draft activity create, replace, delete and reorder`

### Task 6: Remove the old activity surface
App: server
Phase: 2
Recipe: `/architect` · SPEC §server "Delete" row, §Contract "Removed with no replacement row", SC8

**Files:**
- Delete: `server/src/routes/activity-progress.ts`, `routes/member-lessons.ts`, `routes/study-preview.ts`, `routes/themes.ts`, `services/member-progress.service.ts`, `services/lesson-version-resolution.ts`
- Modify: `server/src/routes/programs.ts:1656-3900` — remove every lesson-activity, read-block, highlight (incl. `exegesis-` aliases), source-reference and `preview-data` route (`:1790`, `:2038`); lesson create/patch/delete and `reorder-lessons` stay for Task 9
- Modify: `server/src/routes/enrollments.ts:2233-2660` (member lesson views) and `:3163-4800` (scheduled-activity CRUD, `reorder-activities` `:4751`) — remove
- Modify: `server/src/index.ts:329-331`, `:519-531`, `:580` — drop the mounts of the deleted routers
- Delete tests: `server/test/lesson-activities.test.ts`, `src/routes/__tests__/content-highlights.test.ts`, `member-lessons.test.ts`, `member-version-resolution.test.ts`, and any other test whose subject this task removes
- Test: `server/test/old-activity-routes-removed.test.ts`

**Interfaces:**
- Produces: nothing new. Consumes nothing.

**Behaviour:**
- every route on SPEC §Contract's "Removed" list answers 404 (SC8; §Contract "Removed with no replacement row")
- a test that covered a removed route is deleted with it; a test that covered surviving behaviour in the same file is kept and still passes (residual guard rule)
- nothing in `server/src` imports a deleted file (tsc proves it)

**Tests:**
- `the removed routes are gone` (SC8)

```ts
it.each([
  ['get', '/api/themes'],
  ['get', `/api/programs/P/lessons/L/activities`],
  ['patch', '/api/programs/activities/A'],
  ['get', '/api/programs/P/lessons/L/preview-data'],
  ['get', '/api/enrollments/E/lessons/S/activities'],
  ['post', '/api/activity-progress/A'],
  ['get', '/api/study-preview/P'],
])('%s %s is gone', async (method, path) => {
  const res = await (request(app) as any)[method](path).set('Authorization', bearer(w.leader.token))
  expect(res.status).toBe(404)
})
```

(Replace each example path with the exact path the deleted handler declared — read it before deleting — one case per removed router or route family.)

- [ ] **Step 1: Write the listed test** — in `server/test/old-activity-routes-removed.test.ts`, with the exact paths
- [ ] **Step 2: Request a focused verifier run and watch it fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Delete the files, route blocks, mounts and their tests**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch it pass**
- [ ] **Step 5: Commit** — `refactor(text-activity): remove the 1.0 activity, theme and member-lesson routes`

### Task 7: The sync core — moving an enrollment onto a program version
App: server
Phase: 2
Recipe: `/api` · SPEC D5, D37, 05 §3 "Sync" + "Enroll"

**Files:**
- Modify: `server/src/services/enrollment-sync.ts` — replace the old run machinery (`:70`, `:100-155`, `:572` fan-out) with `applyProgramVersion`; keep the push sender (`:644-678`), retyped
- Modify: `server/src/services/enrollment-sync-changes.ts:43,64` — `computePendingChanges` on `ProgramVersionLesson`
- Test: `server/test/enrollment-sync-core.test.ts`; delete or port `src/routes/__tests__/enrollment-sync-engine.test.ts`

**Interfaces:**
- Produces: `applyProgramVersion(tx, enrollmentId, programVersionId)` — returns `{ movedLessonIds, addedLessonIds, removedLessonIds, skippedCustomizedLessonIds }`; `createScheduledLessons(tx, enrollmentId, programVersionId, dates)` — used by enroll (Task 11), `dates` maps `lessonId → Date`; `computePendingChanges(enrollmentId)` — returns today's `PendingChanges` keys from the new model; `sendSyncPushes(enrollmentIds, programVersion)` — the existing push, called after commit
- Consumes: Task 1 models

**Behaviour:**
- for each `ProgramVersionLesson` of the target: an existing `ScheduledLesson` for `(enrollmentId, lessonId)` whose current version has `enrollmentId` set is skipped and reported (D5); otherwise `currentVersionId` moves to the row's `lessonVersionId` (05 §3)
- a lesson in the target with no `ScheduledLesson` gets one, dated by the rule today's sync uses for an added lesson (read it in `enrollment-sync.ts` before replacing it)
- a live `ScheduledLesson` whose lesson is absent from the target: deleted when it has no `LessonProgress` row, else `removedAt = now` (05 §3)
- `Enrollment.programVersionId` = the target; no `EnrollmentSyncRun` is written (D37, SC8)
- `computePendingChanges` diffs the enrollment's `programVersionId` lessons against the program's `currentVersionId` lessons by `lessonId` and `lessonVersionId`

**Tests:**
- `sync moves pointers and copies nothing` (05 §3)

```ts
it('sync moves pointers and copies nothing', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 2 })
  const v2 = await publishNewVersion(s, { changeLesson: 0 })
  const before = await prisma.contentActivity.count()
  const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
  expect(r.movedLessonIds).toEqual([s.lessonIds[0], s.lessonIds[1]])
  expect(await prisma.contentActivity.count()).toBe(before)
  expect((await prisma.enrollment.findUnique({ where: { id: s.enrollmentId } }))!.programVersionId).toBe(v2.id)
})
```

- `a removed lesson is deleted without progress and soft-removed with it` (05 §3)

```ts
it('a removed lesson is deleted without progress and soft-removed with it', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 2 })
  await prisma.lessonProgress.create({ data: { memberId: s.memberId, scheduledLessonId: s.scheduledLessonIds[1] } })
  const v2 = await publishNewVersion(s, { dropLessons: [0, 1] })
  await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
  expect(await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[0] } })).toBeNull()
  expect((await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[1] } }))!.removedAt).not.toBeNull()
})
```

- `a customized lesson is skipped and reported` (D5)

```ts
it('a customized lesson is skipped and reported', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1 })
  const groupV = await customizeForEnrollment(s, 0)
  const v2 = await publishNewVersion(s, { changeLesson: 0 })
  const r = await prisma.$transaction(tx => applyProgramVersion(tx, s.enrollmentId, v2.id))
  expect(r.skippedCustomizedLessonIds).toEqual([s.lessonIds[0]])
  expect((await prisma.scheduledLesson.findUnique({ where: { id: s.scheduledLessonIds[0] } }))!.currentVersionId).toBe(groupV.id)
})
```

(Add `seedEnrolledProgram`, `publishNewVersion`, `customizeForEnrollment` to `content-world.ts` writing rows directly — Task 8's publish service doesn't exist yet. `customizeForEnrollment` writes a PUBLISHED version with `enrollmentId` set and points the scheduled lesson at it.)

- [ ] **Step 1: Write the listed tests** — in `server/test/enrollment-sync-core.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the sync core to the Behaviour; keep callers compiling (routes switch in Task 12)**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): sync moves enrollments onto program versions`

### Task 8: Publish
App: server
Phase: 2
Recipe: `/api` · SPEC D20, D32, D37, §Contract publish row

**Files:**
- Create: `server/src/services/program-publish.service.ts` — the one publish transaction
- Delete: `server/src/services/study-program-publish.ts`, `services/lesson-content-hash.ts`
- Modify: `server/src/routes/programs.ts` — add `POST /:id/publish`; remove `publish-preview` (`:1203`), `publish-updates` (`:1261`), `GET /:id/versions` (`:1344`); the `isPublished` flip in `PATCH /:id` (`~:1017-1146`) calls `publishProgram`
- Test: `server/test/program-publish.test.ts`; delete `src/routes/__tests__/program-publish.test.ts` (its subject is gone)

**Interfaces:**
- Produces: `publishProgram(userId, programId, { changeSummary? })` — returns `{ programVersion: ProgramVersion | null, changedLessonIds: string[] }`, throws `ContentError` 404
- Consumes: `hashLessonContent` (Task 2); `applyProgramVersion`, `sendSyncPushes` (Task 7); `withDraftLock`'s lock statement (Task 5); `ContentError` (Task 3)

The frozen contract row, verbatim from SPEC §Contract:

```
| `POST /api/programs/:id/publish` | server | iphone (`ProgramActions` publish) | org content | `{ changeSummary? }` | `{ programVersion \| null, changedLessonIds }` (D37). Replaces `publish-updates`; `publish-preview` and `GET versions` are removed; the `isPublished` flip in `PATCH /programs/:id` calls the same service | 400 `VALIDATION`, 404 |
```

The transaction, which the tests can't fully pin (D32, D37):

```
$transaction:
  lock study_programs row FOR UPDATE; access per D35 else 404
  lessons = live lessons of the program (deletedAt null) by position
  changed = []
  for lesson in lessons with a program DRAFT (lock the draft FOR UPDATE):
    hash = hashLessonContent(draft.title + draft activities)
    latest = highest-number PUBLISHED, enrollmentId null
    if latest and latest.contentHash == hash: delete draft (activities cascade)
    else: draft → PUBLISHED, contentHash = hash, publishedAt = now, publishedById = user,
          estimatedSeconds = Σ activity estimatedSeconds; changed += lesson.id
  rows = for each live lesson: (lessonId, its latest PUBLISHED version id, position)
  if changed is empty and rows equal the current ProgramVersion's rows: return { programVersion: null, changedLessonIds: [] }
  pv = ProgramVersion(number = max+1, changeSummary, publishedById); insert rows; StudyProgram.currentVersionId = pv.id
  for enrollment of program with syncMode AUTO: applyProgramVersion(tx, enrollment.id, pv.id)
after commit: sendSyncPushes(moved AUTO enrollments, pv); if no changeSummary was sent, summarizeProgramChanges (services/claude.ts) runs best-effort and updates pv.changeSummary
```

**Behaviour:**
- a lesson whose hash matches its latest published version discards its draft (D20)
- no changed lesson and an unchanged lesson list → nothing written, no push, `{ programVersion: null, changedLessonIds: [] }` (D37)
- a failure anywhere inside rolls the whole publish back: no version frozen, no pointer moved (D32)
- AUTO enrollments move inside the transaction; APPROVAL and OFF enrollments don't (D37)
- `changeSummary` is an optional string ≤ 2000 chars, zod-validated; other types → 400 `VALIDATION`
- the `isPublished: true` transition in `PATCH /programs/:id` calls `publishProgram` and keeps its own response shape

**Tests:**
- `publish freezes changed lessons and skips unchanged ones` (D20)

```ts
it('publish freezes changed lessons and skips unchanged ones', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 2 })
  await openDraft(w, s.lessonIds[0]); await openDraft(w, s.lessonIds[1])
  await editFirstActivity(w, s.lessonIds[0])
  const r = await request(app).post(`/api/programs/${s.programId}/publish`).set('Authorization', bearer(w.leader.token)).send({})
  expect(r.status).toBe(200); expect(r.body.changedLessonIds).toEqual([s.lessonIds[0]])
  expect(await prisma.lessonVersion.count({ where: { lessonId: s.lessonIds[1], status: 'DRAFT' } })).toBe(0)
})
```

- `publish with no changes writes nothing and sends no push` (D37)

```ts
it('publish with no changes writes nothing and sends no push', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
  const push = vi.spyOn(sync, 'sendSyncPushes')
  const before = await prisma.programVersion.count()
  const r = await request(app).post(`/api/programs/${s.programId}/publish`).set('Authorization', bearer(w.leader.token)).send({})
  expect(r.body).toEqual({ programVersion: null, changedLessonIds: [] })
  expect(await prisma.programVersion.count()).toBe(before); expect(push).not.toHaveBeenCalled()
})
```

- `AUTO enrollments move inside the publish; a PUT racing publish leaves the frozen version unchanged` (D32, D37)

```ts
it('AUTO enrollments move inside the publish; a PUT racing publish leaves the frozen version unchanged', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
  const draft = await openDraft(w, s.lessonIds[0]); await editFirstActivity(w, s.lessonIds[0])
  const [pub, put] = await Promise.all([
    request(app).post(`/api/programs/${s.programId}/publish`).set('Authorization', bearer(w.leader.token)).send({}),
    request(app).put(`/api/content-activities/${draft.activities[0].id}`).set('Authorization', bearer(w.leader.token)).send({ document: RACE_DOC }),
  ])
  expect(pub.status).toBe(200)
  const frozen = await prisma.contentActivity.findFirst({ where: { lessonVersionId: draft.version.id } })
  if (put.status === 409) expect(frozen!.document).not.toEqual(RACE_DOC)
  expect((await prisma.enrollment.findUnique({ where: { id: s.enrollmentId } }))!.programVersionId).toBe(pub.body.programVersion.id)
})
```

- `a failure inside publish rolls everything back` (D32)

```ts
it('a failure inside publish rolls everything back', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1, syncMode: 'AUTO' })
  await openDraft(w, s.lessonIds[0]); await editFirstActivity(w, s.lessonIds[0])
  vi.spyOn(sync, 'applyProgramVersion').mockRejectedValueOnce(new Error('boom'))
  await request(app).post(`/api/programs/${s.programId}/publish`).set('Authorization', bearer(w.leader.token)).send({})
  expect(await prisma.lessonVersion.count({ where: { lessonId: s.lessonIds[0], status: 'DRAFT' } })).toBe(1)
  expect((await prisma.studyProgram.findUnique({ where: { id: s.programId } }))!.currentVersionId).toBe(s.programVersionId)
})
```

- `another org's leader gets 404` (D35)

```ts
it("another org's leader gets 404", async () => {
  const r = await request(app).post(`/api/programs/${w.programId}/publish`).set('Authorization', bearer(w.outsider.token)).send({})
  expect(r.status).toBe(404)
})
```

(`openDraft` calls `GET /api/lessons/:id/draft`; `editFirstActivity` PUTs a changed document; `sync` is `import * as sync from '../src/services/enrollment-sync'` — if the spy can't intercept an internal call, inject the function through a module-level seam the service reads.)

- [ ] **Step 1: Write the listed tests** — in `server/test/program-publish.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `program-publish.service.ts`, the route and the `PATCH` flip; delete the replaced services and test**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): publish freezes drafts into a program version`

### Task 9: The program read and lesson writes
App: server
Phase: 2
Recipe: `/api` · SPEC §Contract `GET /api/programs/:id` and lesson rows, D26, D36, SC2, SC10

**Files:**
- Modify: `server/src/routes/programs.ts:729` (GET program, activities + readBlocks `:782-815`), `:4045` (lesson create), `:4211` (lesson patch), `:1656` (lesson delete), `reorder-lessons`, and program create from a template — thin; logic to the service
- Create: `server/src/services/program-lessons.service.ts` — the program read and the lesson writes
- Modify: `server/src/services/lesson-copy.ts:161,354`, `lesson-estimate.ts`, `lesson-summary.ts`, `claude.ts:41,182` — on versions and documents
- Test: `server/test/program-lessons.test.ts`; port `src/routes/__tests__/programs-add-lesson.request.test.ts` to the new model

**Interfaces:**
- Produces: `getProgramForUser(userId, programId)` — returns the program payload; `createLesson(userId, programId, body)`, `updateLesson(userId, lessonId, body)`, `deleteLesson(userId, lessonId)`, `reorderLessons(userId, programId, lessonIds)`; `ActivitySummary` serializer `serializeActivitySummary(a)` → `{ id, activityKey, position, kind, title, document }`
- Consumes: `getOrCreateDraft`, `serializeLessonVersion` (Task 4); `buildMediaMap` (Task 3); `documentText`, `estimateDocumentSeconds` (Task 2)

The frozen contract rows, verbatim from SPEC §Contract:

```
| `GET /api/programs/:id` (changed) | server | iphone (program home) | org content | — | Lessons each carry `id`, `position`, `title`, `estimatedSeconds` (from the draft, else the latest published version), `draftVersionId`, `publishedVersionId`, and `activities: ActivitySummary[]` of that same version; the response adds `media: MediaMap` | 404 |
| `POST /api/programs/:id/lessons`, `PATCH`/`DELETE /lessons/:id`, `reorder-lessons` (changed, same shape) | server | iphone (program home) | org content | As today | Create makes `Lesson` + a draft `LessonVersion`; a title edit writes the draft's `title`; delete per D36 | 400, 404 |
ActivitySummary { id, activityKey, position, kind, title, document }   // document feeds D26's rail slides
```

**Behaviour:**
- program read: live lessons by `position`; each lesson's `title`, `estimatedSeconds` and `activities` come from its DRAFT when one exists, else its latest PUBLISHED; `draftVersionId`/`publishedVersionId` are those ids or `null`; `media` covers every listed document; program-level keys the iPhone reads today stay (§Contract)
- create writes `Lesson { programId, position }` and DRAFT number 1 with the body's title; a program created from a template creates, per template lesson, a lesson and a draft holding one `ContentActivity` per template activity that has `kind` and `document` (SC6)
- a title edit writes the draft's `title`, creating the draft first through `getOrCreateDraft` when none exists (§Contract)
- delete: any PUBLISHED version → `deletedAt = now` and its draft removed; none → hard delete; live lessons' positions close up (D36)
- authorization for every lesson write is D35's, 404 otherwise; zod bodies keep today's fields and strip none the iPhone sends
- `lesson-copy` copies the source's draft (else latest published) activities into the target's draft with new `activityKey`s; `claude.ts` and `lesson-summary` read `documentText` and `documentPassages`; `lesson-estimate` sums `estimatedSeconds`

**Tests:**
- `the program read lists lessons from the draft, else the published version` (§Contract)

```ts
it('the program read lists lessons from the draft, else the published version', async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
  const r = await request(app).get(`/api/programs/${w.programId}`).set('Authorization', bearer(w.leader.token))
  const [l1, l2] = r.body.lessons
  expect(l1).toMatchObject({ id: w.lessonId, title: 'Day 1', draftVersionId: w.draftVersionId, publishedVersionId: null, activities: [] })
  expect(l2).toMatchObject({ id: pub.lessonId, draftVersionId: null, publishedVersionId: pub.versionId })
  expect(l2.activities[0]).toEqual(expect.objectContaining({ activityKey: 'k1', kind: 'text', document: expect.any(Object) }))
  expect(r.body.media).toEqual({})
})
```

- `create makes a lesson and its draft; a title edit lands in the draft` (§Contract)

```ts
it('create makes a lesson and its draft; a title edit lands in the draft', async () => {
  const c = await request(app).post(`/api/programs/${w.programId}/lessons`).set('Authorization', bearer(w.leader.token)).send({ title: 'Day 2' })
  const lessonId = c.body.lesson?.id ?? c.body.id
  await request(app).patch(`/api/programs/lessons/${lessonId}`).set('Authorization', bearer(w.leader.token)).send({ title: 'Renamed' })
  const d = await prisma.lessonVersion.findFirst({ where: { lessonId, status: 'DRAFT' } })
  expect(d!.title).toBe('Renamed')
})
```

- `delete soft-deletes a published lesson and hard-deletes a draft-only one` (D36)

```ts
it('delete soft-deletes a published lesson and hard-deletes a draft-only one', async () => {
  const pub = await seedPublishedLesson(w, [{ activityKey: 'k1' }])
  await request(app).delete(`/api/programs/lessons/${pub.lessonId}`).set('Authorization', bearer(w.leader.token))
  await request(app).delete(`/api/programs/lessons/${w.lessonId}`).set('Authorization', bearer(w.leader.token))
  expect((await prisma.lesson.findUnique({ where: { id: pub.lessonId } }))!.deletedAt).not.toBeNull()
  expect(await prisma.lesson.findUnique({ where: { id: w.lessonId } })).toBeNull()
})
```

- `lesson writes from another org are 404` (D35)

```ts
it('lesson writes from another org are 404', async () => {
  const r = await request(app).patch(`/api/programs/lessons/${w.lessonId}`).set('Authorization', bearer(w.outsider.token)).send({ title: 'x' })
  expect(r.status).toBe(404)
})
```

(Use the exact lesson paths `programs.ts` declares at `:1656`, `:4045`, `:4211`; the examples assume `/api/programs/lessons/:id`.)

- [ ] **Step 1: Write the listed tests** — in `server/test/program-lessons.test.ts`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the service, thin the routes, rewrite the four lesson services to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): program read and lesson writes on lesson versions`

### Task 10: Templates and the program export file
App: server
Phase: 2
Recipe: `/api` · SPEC SC6, SC9, D43

**Files:**
- Modify: `server/src/routes/templates.ts:125,420,465` — `kind` + `document` replace the `TemplateActivityType` enum
- Modify: `server/src/services/program-export.ts:80` — format `version: 2` on the new model
- Test: `server/test/templates-kind.test.ts`, `server/test/program-export-v2.test.ts`

**Interfaces:**
- Produces: `ProgramExportV2` — `{ version: 2, program: { title, description, … today's program fields }, lessons: [{ position, title, activities: [{ kind, title, document }] }] }`; `exportProgram(userId, programId)` and `importProgram(userId, orgId, file)` keep their current names and signatures
- Consumes: `ACTIVITY_KINDS`, `parseActivityDocument`, `documentMediaRefs` (Task 2); `assertDocumentMediaAllowed` (Task 3)

**Behaviour:**
- template activity writes take `kind` in `ACTIVITY_KINDS` and a `document` checked by `parseActivityDocument`; responses add `kind` and `document`; the old `type` field is no longer accepted (SC6, SC9, D1)
- export writes each live lesson's draft when one exists, else its latest published version (D43)
- a `version: 1` file → 400 `{ success: false, error: 'Unsupported export version', code: 'VALIDATION' }` (D43); a `version: 2` file imports as a new program whose lessons each get a DRAFT with new `activityKey`s, every document validated and media-checked as POST does (D3, D34)

**Tests:**
- `a template activity stores kind and document, and refuses the old type field` (SC6, SC9)

```ts
it('a template activity stores kind and document, and refuses the old type field', async () => {
  const ok = await createTemplateActivity(w, { kind: 'text', title: 'Starter', document: EXAMPLE_TEXT })
  expect(ok.body).toMatchObject({ kind: 'text', document: EXAMPLE_TEXT })
  expect((await createTemplateActivity(w, { type: 'READ', title: 'Old' })).status).toBe(400)
})
```

- `export round-trips as version 2 and version 1 is refused` (D43)

```ts
it('export round-trips as version 2 and version 1 is refused', async () => {
  await seedPublishedLesson(w, [{ activityKey: 'k1' }])
  const file = await exportFile(w)
  expect(file.version).toBe(2)
  const imported = await importFile(w, file)
  expect(imported.status).toBe(201)
  const v1 = await importFile(w, { ...file, version: 1 })
  expect(v1.status).toBe(400); expect(v1.body.code).toBe('VALIDATION')
})
```

(`createTemplateActivity`, `exportFile`, `importFile` call the routes `templates.ts` and the program export/import routes declare today.)

- [ ] **Step 1: Write the listed tests** — in the two test files
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the template and export changes to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): template kinds and program export v2`

### Task 11: Enrollment create, home, schedule and next study
App: server
Phase: 3
Recipe: `/api` · SPEC §Contract enrollment rows, SC10

**Files:**
- Modify: `server/src/routes/enrollments.ts:143-190` (enroll), `:939`, `:1061` (group/study home), `:1359` (next-study), `:1669` (edit/preview), `:4883`/`:5156`/`:5237` (schedule CRUD), and `GET /:id`, `GET /:id/home` — read and write `ScheduledLesson`
- Modify: `server/src/services/enrollment-edit.ts:12,62`, `next-study-thumbnail.ts`, `enrollment-directory.ts`, `routes/enrollment-directory.ts`
- Test: `server/test/enrollment-scheduled-lessons.test.ts`; port `test/enrollment-home.test.ts`, `src/routes/__tests__/next-study.request.test.ts`, `enrollment-edit.test.ts`, `test/enrollment-create.test.ts` to the new model

**Interfaces:**
- Produces: `thumbnailFromDocument(doc, media)` — returns the background image URL, else the video poster URL, else `null`
- Consumes: `createScheduledLessons` (Task 7); `buildMediaMap` (Task 3)

The frozen contract rows, verbatim from SPEC §Contract:

```
| `GET /api/enrollments/:id/home` (changed, same shape) | server | iphone (enrollment home) | enrollment | — | As today, from `ScheduledLesson.currentVersionId`; each activity's `type` is the new `kind` and `thumbnailUrl` comes from the document's background or poster | 404 |
| `POST /api/enrollments`, `GET /api/enrollments/:id`, `edit/preview`, schedule add/patch/delete (changed, same shape) | server | iphone (enroll flow, select schedule) | enrollment | As today | `lessonSchedules[]` keys kept, built from `ScheduledLesson` rows pointing at current versions; `smsSentAt` still locks edits | 400, 404 |
| `GET /api/groups/:id/next-study` (changed, same shape) | server | iphone (group page) | group | — | As today; thumbnail from the next lesson version's first activity document | 404 |
```

**Behaviour:**
- enroll creates one `ScheduledLesson` per `ProgramVersionLesson` of the program's `currentVersionId`, dated by today's enroll date rule, and sets `Enrollment.programVersionId`; a program with no `currentVersionId` → 400 `VALIDATION` "Publish this program before enrolling a group" (D2)
- every "same shape" response keeps every JSON key it returns today; `title` and `estimatedMinutes` come from the current version (`ceil(estimatedSeconds / 60)`), `templateName` from `ScheduledLesson.templateId`'s template (§Contract, SC10)
- `smsSentAt` set on a `ScheduledLesson` still refuses its schedule edit as today (SC10)
- `removedAt` lessons stay out of upcoming lists, as today
- enrollment-home activity `type` = `kind`; `thumbnailUrl` = `thumbnailFromDocument` (§Contract)

**Tests:**
- `enroll points scheduled lessons at the program version's lessons` (05 §3)

```ts
it("enroll points scheduled lessons at the program version's lessons", async () => {
  const s = await seedPublishedProgram(w, { lessons: 2 })
  const r = await enroll(w, s.programId)
  const rows = await prisma.scheduledLesson.findMany({ where: { enrollmentId: r.body.id ?? r.body.enrollment.id }, orderBy: { scheduledDate: 'asc' } })
  expect(rows.map(x => x.currentVersionId)).toEqual(s.versionIds)
})
```

- `home keeps today's keys with kind as type and the document's thumbnail` (§Contract)

```ts
it("home keeps today's keys with kind as type and the document's thumbnail", async () => {
  const m = await createMedia(w.orgId)
  const s = await seedEnrolledProgram(w, { lessons: 1, mediaId: m.id })
  const r = await request(app).get(`/api/enrollments/${s.enrollmentId}/home`).set('Authorization', bearer(w.leader.token))
  expect(Object.keys(r.body).sort()).toEqual(HOME_KEYS_TODAY)
  const act = findFirstActivity(r.body)
  expect(act).toMatchObject({ type: 'text', thumbnailUrl: m.url })
})
```

- `an SMS-sent lesson still refuses a schedule edit` (SC10)

```ts
it('an SMS-sent lesson still refuses a schedule edit', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1 })
  await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { smsSentAt: new Date() } })
  expect((await patchSchedule(w, s, 0, { scheduledDate: '2030-01-01' })).status).toBe(SMS_LOCK_STATUS_TODAY)
})
```

- `next-study thumbnail comes from the next lesson's first document` (§Contract)

```ts
it("next-study thumbnail comes from the next lesson's first document", async () => {
  const m = await createMedia(w.orgId)
  const s = await seedEnrolledProgram(w, { lessons: 1, mediaId: m.id })
  const r = await request(app).get(`/api/groups/${s.groupId}/next-study`).set('Authorization', bearer(w.leader.token))
  expect(JSON.stringify(r.body)).toContain(m.url)
})
```

(Fill `HOME_KEYS_TODAY` and `SMS_LOCK_STATUS_TODAY` from the current response and lock status before rewriting — read them from the existing tests or route; `findFirstActivity` walks the home payload to its first activity; `enroll`/`patchSchedule` call the existing routes. Add `seedPublishedProgram` and a `mediaId` option on `seedEnrolledProgram` to `content-world.ts`.)

- [ ] **Step 1: Capture today's keys, write the listed tests and port the four existing tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Rewrite the routes' reads and writes and the four services to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): enrollments schedule scheduled lessons on lesson versions`

### Task 12: The sync routes
App: server
Phase: 3
Recipe: `/api` · SPEC §Contract sync row, D5, SC3

**Files:**
- Modify: `server/src/routes/enrollments.ts:1904` (`GET /:id/sync`), `:1999` (`/sync/changes`), `:2049` (`POST /sync/apply`; `lessonKeys` `:2058`; numbers `:1958-1962`)
- Test: `server/test/enrollment-sync-routes.test.ts`; port `src/routes/__tests__/enrollment-sync.test.ts`

**Interfaces:**
- Consumes: `applyProgramVersion`, `computePendingChanges`, `sendSyncPushes` (Task 7)

The frozen contract row, verbatim from SPEC §Contract:

```
| `GET /api/enrollments/:id/sync`, `/sync/changes`, `POST /sync/apply` (changed) | server | iphone (`EnrollmentActions` sync) | enrollment | As today, `lessonKeys` kept | Same fields; `syncedProgramVersionNumber`, `currentVersionNumber` and `versionNumber` are `ProgramVersion.number`; adds `skippedCustomizedLessonIds` (D5) | 404 |
```

**Behaviour:**
- every field today's responses carry stays; the three version numbers are `ProgramVersion.number` of the enrollment's and the program's version (SC3, SC4)
- `POST /sync/apply` runs `applyProgramVersion` to the program's `currentVersionId` in one transaction, sends pushes after commit, and returns `skippedCustomizedLessonIds` (D5)
- `lessonKeys` keeps its request meaning: apply only the listed lessons when present — the others keep their pointers
- sync after the program is deleted → 404 (§Testing)

**Tests:**
- `apply moves the enrollment and reports skipped customized lessons` (D5)

```ts
it('apply moves the enrollment and reports skipped customized lessons', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 2 })
  await customizeForEnrollment(s, 1)
  const v2 = await publishNewVersion(s, { changeLesson: 0 })
  await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: v2.id } })
  const r = await request(app).post(`/api/enrollments/${s.enrollmentId}/sync/apply`).set('Authorization', bearer(w.leader.token)).send({})
  expect(r.status).toBe(200); expect(r.body.skippedCustomizedLessonIds).toEqual([s.lessonIds[1]])
})
```

- `sync status reports ProgramVersion numbers` (SC3)

```ts
it('sync status reports ProgramVersion numbers', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1 })
  const v2 = await publishNewVersion(s, { changeLesson: 0 })
  await prisma.studyProgram.update({ where: { id: s.programId }, data: { currentVersionId: v2.id } })
  const r = await request(app).get(`/api/enrollments/${s.enrollmentId}/sync`).set('Authorization', bearer(w.leader.token))
  expect(r.body).toMatchObject({ syncedProgramVersionNumber: 1, currentVersionNumber: 2 })
})
```

- `sync after the program is deleted is 404` (§Testing)

```ts
it('sync after the program is deleted is 404', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1 })
  await prisma.studyProgram.delete({ where: { id: s.programId } })
  expect((await request(app).get(`/api/enrollments/${s.enrollmentId}/sync`).set('Authorization', bearer(w.leader.token))).status).toBe(404)
})
```

- [ ] **Step 1: Write the listed tests and port the existing sync request test**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Rewrite the three routes to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): sync routes on program versions`

### Task 13: Search on versions and documents
App: server
Phase: 3
Recipe: `/api` · SPEC SC12 (search half), §server "Search and AI summaries"

**Files:**
- Create: `server/atlas/migrations/<ts>_text_activity_search_indexes.sql` — via `migrate new`; hand migration
- Modify: `server/src/services/master-search.ts:254-272`, `master-search-text.ts`, `routes/search.ts`
- Test: `server/test/master-search-lessons.test.ts`; port the lesson cases of the existing master-search tests

**Interfaces:**
- Produces: `LESSON_SEARCH_TEXT_SQL` (or the existing constant's name, kept) in `master-search-text.ts` — the exact expression both the GIN index and the query use

**Behaviour:**
- the lesson arm searches the latest PUBLISHED version (else the draft) per live lesson: its `title` plus the text of its activities' documents (`content.objects[].text`, the `write`/`poll` prompt text) (§server)
- the GIN index expression and the query expression are the same string constant, so the planner uses the index (SC12; F18)
- the old lesson GIN indexes from `20261104000602` are dropped in the new hand migration only if they index old tables that still exist and would otherwise be stale; a dropped index name is listed in the migration's header comment

**Tests:**
- `finds a lesson by its draft title and by text inside a document` (§server)

```ts
it('finds a lesson by its draft title and by text inside a document', async () => {
  await seedPublishedLesson(w, [{ activityKey: 'k1', text: 'Finally, brothers and sisters, quillwort' }])
  const r = await search(w, 'quillwort')
  expect(r.body.results.some((x: any) => x.type === 'lesson')).toBe(true)
})
```

- `the index expression matches the query expression` (SC12)

```ts
it('the index expression matches the query expression', () => {
  const sql = findMigration('text_activity_search')
  expect(sql).toContain(normalizeSql(LESSON_SEARCH_TEXT_SQL))
})
```

(`search` calls the master search route the existing tests use; `seedPublishedLesson` gains a `text` option writing the first object's text.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Write the hand migration (`cd server/atlas && ../scripts/atlas.sh migrate new text_activity_search_indexes --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`, then `migrate hash`) and rewrite the lesson arm**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): lesson search on versions and document text`

### Task 14: The other readers — notes, home, status, share previews, logging
App: server
Phase: 3
Recipe: `/api` · SPEC §server "Rewrite on the new model" rows, D42

**Files:**
- Modify: `server/src/routes/notes.ts`, `services/notes.ts` — no `LESSON_ACTIVITY`/`SCHEDULED_ACTIVITY`/`LESSON_SCHEDULE` link reads or writes
- Modify: `server/src/services/home-dashboard.ts`, `home-following.ts`, `home-sessions.ts` — `ScheduledLesson`
- Modify: `server/src/routes/status.ts`, `lib/og-meta.ts`, `lib/study-code.ts`, `middleware/request-logger.ts`
- Test: `server/test/text-activity-readers.test.ts`; port `src/routes/__tests__/home.test.ts`, `home-days-group.request.test.ts`, `home-following.request.test.ts`, `lesson-lookup.test.ts` to the new model

**Interfaces:**
- Consumes: `documentText`, `documentPassages` (Task 2); `thumbnailFromDocument` (Task 11)

**Behaviour:**
- notes refuse the three removed ref types with 400 `VALIDATION`; existing `StudyNote` bodies keep working (D42)
- home dashboard, following and sessions read lessons from `ScheduledLesson` + current version, keeping every response key (§Contract "same shape" rule)
- `study-code` and `og-meta` resolve a 6-char code through `ScheduledLesson.code`, with the share description from `documentText` and scripture from `documentPassages` (§server)
- the request logger stops naming removed models

**Tests:**
- `a note can no longer link a lesson activity` (D42)

```ts
it('a note can no longer link a lesson activity', async () => {
  const r = await createNote(w, { body: 'x', links: [{ refType: 'LESSON_ACTIVITY', refId: 'a' }] })
  expect(r.status).toBe(400)
})
```

- `a scheduled lesson code resolves with document text in the preview` (§server)

```ts
it('a scheduled lesson code resolves with document text in the preview', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1, text: 'quillwort preview' })
  await prisma.scheduledLesson.update({ where: { id: s.scheduledLessonIds[0] }, data: { code: 'AB12CD' } })
  const meta = await ogMetaForCode('AB12CD')
  expect(meta.description).toContain('quillwort preview')
})
```

(`createNote` calls the notes create route; `ogMetaForCode` is the `og-meta.ts` export the study-code page uses — read its name there.)

- [ ] **Step 1: Write the listed tests and port the four existing tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Rewrite the readers to the Behaviour**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `refactor(text-activity): notes, home, status and share previews on scheduled lessons`

### Task 15: Analytics — the materialized view and its readers
App: server
Phase: 3
Recipe: `/api` · SPEC SC11, SC12 (analytics half), D8, D42; F18 build-time risk below

**Files:**
- Create: `server/atlas/migrations/<ts>_text_activity_analytics_view.sql` — via `migrate new`; drops and recreates `analytics_events`, copied from `20261025200000.sql` with its arms rewritten
- Modify: `server/src/services/analytics-metrics.ts`, `analytics.ts`, `enrollment-analytics.ts`, `member-engagement.ts`; `routes/analytics.ts`, `routes/engagement.ts`, `routes/program-analytics.ts:197`
- Modify: client event ingestion (the route writing `ClientEvent`) — accepts and writes `scheduledLessonId`, `activityKey`, `kind`
- Test: `server/test/analytics-view.test.ts`; port the analytics and engagement request tests (`members-engagement.request.test.ts` and any test reading the view)

**Interfaces:**
- Consumes: Task 1 columns `ClientEvent.scheduledLessonId`, `activityKey`, `kind`; `LessonProgress`, `ActivityProgress`

> **Build-time risk (F18):** the view and indexes are hand SQL outside the YAML and the largest unscoped server item. Diff the old and new view column lists (they must be identical), and run the `analytics-metrics` tests.

**Behaviour:**
- the new view keeps every output column of `20261025200000.sql`'s `analytics_events`, in the same order and types; arms that read `lesson_schedules`, `scheduled_lesson_activities` and `member_*_progress` read `scheduled_lessons`, `content_activities` (by `activityKey`), `lesson_progress` and `activity_progress` (SC12)
- note-link arms drop the three removed ref types (D42)
- with no progress rows, member metrics are zero, never an error (D8)
- `program-analytics.ts:197` raw SQL reads the new tables
- client event ingestion writes `scheduledLessonId`, `activityKey`, `kind` and no longer writes the old three columns (SC11)

**Tests:**
- `the rewritten view keeps every output column` (SC12, F18)

```ts
it('the rewritten view keeps every output column', async () => {
  const cols = await viewColumns('analytics_events')
  expect(cols).toEqual(VIEW_COLUMNS_20261025200000)
})
```

- `metrics compute to zero with empty progress tables` (D8)

```ts
it('metrics compute to zero with empty progress tables', async () => {
  const s = await seedEnrolledProgram(w, { lessons: 1 })
  await refreshAnalyticsView()
  const r = await request(app).get(`/api/programs/${s.programId}/analytics`).set('Authorization', bearer(w.leader.token))
  expect(r.status).toBe(200)
})
```

- `a client event stores the new keys` (SC11)

```ts
it('a client event stores the new keys', async () => {
  await postClientEvent(w, { scheduledLessonId: 's1', activityKey: 'k1', kind: 'text', name: 'activity_view' })
  const row = await prisma.clientEvent.findFirst({ orderBy: { createdAt: 'desc' } })
  expect(row).toMatchObject({ scheduledLessonId: 's1', activityKey: 'k1', kind: 'text' })
})
```

(`VIEW_COLUMNS_20261025200000` is the `(name, type)` list read off the old view on a lease before the rewrite and pasted into the test; `viewColumns` reads `pg_attribute` for the view; `postClientEvent` and the analytics path are the existing routes — read them.)

- [ ] **Step 1: Read the old view's columns on a lease, write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Write the view migration (`cd server/atlas && ../scripts/atlas.sh migrate new text_activity_analytics_view --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`, then `migrate hash`) and rewrite the readers and ingestion**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `refactor(text-activity): analytics view and readers on scheduled lessons`

### Task 16: Boot chain, scripts and seeds — and the residual sweep
App: server
Phase: 4
Recipe: `/architect` · SPEC D30, §server "Delete" + "Outside `src/`"

**Files:**
- Modify: `server/Dockerfile:76`, `server/package.json:11` — boot runs `migrate apply` then the server; no `load-themes`, no backfills (D30); remove the `themes:load` and `backfill:study-sync` npm scripts
- Delete: `server/src/scripts/load-themes.ts`, `scripts/backfill-highlights.ts`, `scripts/backfill-lesson-estimates.ts`, `scripts/backfill-study-sync.ts`, `.github/workflows/server-migrate-readblocks.yml`
- Modify or delete (each): `server/prisma/seed-dev.ts`, `seed-lessons.ts`; `server/scripts/` import-templates, backfill-media-library, seed-preview-smoke-test, repair-enrollment-date-ranges, migrate-readblocks-to-markdown, test-enrollment.js — rewrite on the new model when it still has a job, delete when its job was the old model
- Modify: every remaining test or helper under `server/test`, `server/src/**/__tests__` that names a removed model (about 33 per §Apps)
- Test: `server/test/boot-chain.test.ts`, `server/test/old-model-residue.test.ts`

**Interfaces:**
- Produces nothing. Consumes nothing.

**Behaviour:**
- the boot command contains `migrate apply` and the server start, and none of `load-themes`, `backfill` (D30)
- zero references to the SC8 model accessors remain in `server/src`, `server/scripts`, `server/prisma` and `server/test` (residual sweep; `server/fixtures` is Task 17's)
- a test of surviving behaviour that read a removed model is ported to the new model, not deleted (residual guard rule)

**Tests:**
- `boot runs migrations and the server only` (D30)

```ts
it('boot runs migrations and the server only', () => {
  const docker = readFileSync('Dockerfile', 'utf8'), pkg = JSON.parse(readFileSync('package.json', 'utf8'))
  for (const s of [docker, pkg.scripts.start]) expect(s).not.toMatch(/load-themes|backfill/)
  expect(docker).toMatch(/migrate apply/)
})
```

- `no old-model accessor remains outside fixtures` (SC8)

```ts
const OLD = /prisma\.(lessonActivity|scheduledLessonActivity|activityReadBlock|contentHighlight|activitySourceReference|textTheme|lessonSchedule|lessonScheduleVersion|memberActivityProgress|memberVideoProgress|memberLessonProgress|studyProgramVersion|enrollmentSyncRun)\b|tx\.(lessonActivity|lessonSchedule|textTheme)\b/
it('no old-model accessor remains outside fixtures', () => {
  const hits = walk(['src', 'scripts', 'prisma', 'test']).filter(f => OLD.test(readFileSync(f, 'utf8')))
  expect(hits.filter(f => !f.endsWith('old-model-residue.test.ts'))).toEqual([])
})
```

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run test/boot-chain.test.ts test/old-model-residue.test.ts`, watch them fail** — the residue list names files
- [ ] **Step 3: Edit the boot chain, delete or rewrite each script and seed, port the remaining tests until the residue list is empty**
- [ ] **Step 4: Run the same command and `npx --no-install tsc --noEmit`, then request a verifier run (`node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, `verify.mjs wait <id>`) and watch everything pass**
- [ ] **Step 5: Commit** — `chore(text-activity): boot chain without themes and backfills; old-model residue removed`

### Task 17: Fixtures on the new model, and the editor and player screens
App: server
Phase: 4
Recipe: `server/fixtures/README.md` · SPEC §iphone "Fixtures", house rule "fixtures"

**Files:**
- Modify: `server/fixtures/` base, context (`context.ts:158`), counts, new-group, wipe, ids; screens `activity-new.ts`, `enrollment-home.ts`, `enrollments-home.ts`, `groups-detail.ts`, `groups-enroll-program.ts`, `home-dashboard.ts`, `search-home.ts` — seed `Lesson.programId/position`, `LessonVersion`, `ContentActivity`, `ProgramVersion(+Lesson)`, `ScheduledLesson`
- Create: `server/fixtures/screens/activities-editor.ts`, `server/fixtures/screens/activities-player.ts` — on the `activity-new.ts` pattern; register in the load order (`runner.ts:89-111`)
- Test: `server/fixtures/__tests__/activities-screens.db.test.ts`; port `fixtures/__tests__/scheduled-lessons.db.test.ts`

**Interfaces:**
- Produces: fixture ids `ids.activitiesEditor.lessonId`, `ids.activitiesPlayer.lessonVersionId` (add to `ids`) — the agent walk opens these

**Behaviour:**
- `full` scenarios of both new screens hold: one activity of each kind (`text`, `bible`, `video`, `youtube`, `write`, and one unknown kind `quiz` for D11's fallback), one `text` page long enough to scroll on a 956 pt viewport, a background image, an inline action and a pinned action (§iphone "Fixtures")
- the player fixture's lesson is published (version 1) and also has a draft, so both reads have data (D22)
- layers read base entities and never create orgs, users or groups; dates come from `ctx.now` (house rule)
- every document written by a fixture passes `parseActivityDocument` except the deliberate `quiz` row, written directly
- the residual sweep regex of Task 16 has zero hits in `server/fixtures`

**Tests:**
- `the full player scenario holds every kind, a long page and both placements` (§iphone)

```ts
it('the full player scenario holds every kind, a long page and both placements', async () => {
  await runScenario('activities-player', 'full')
  const acts = await prisma.contentActivity.findMany({ where: { lessonVersionId: ids.activitiesPlayer.lessonVersionId } })
  expect(new Set(acts.map(a => a.kind))).toEqual(new Set(['text', 'bible', 'video', 'youtube', 'write', 'quiz']))
  const placements = acts.flatMap(a => ((a.document as any).actions ?? []).map((x: any) => x.placement))
  expect(placements).toEqual(expect.arrayContaining(['inline', 'pinned']))
  expect(acts.some(a => (a.document as any).background?.image?.mediaId)).toBe(true)
})
```

- `every fixture document validates except the fallback row` (D3, D11)

```ts
it('every fixture document validates except the fallback row', async () => {
  await runScenario('activities-editor', 'full'); await runScenario('activities-player', 'full')
  const bad = (await prisma.contentActivity.findMany()).filter(a => a.kind !== 'quiz' && !parseActivityDocument(a.document, a.kind).ok)
  expect(bad).toEqual([])
})
```

(`runScenario` is the helper the existing fixture DB tests use.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/activities-screens.db.test.ts` under the verifier's lease (`node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`), watch them fail**
- [ ] **Step 3: Move the base fixtures and the seven screens to the new model; write the two new screens**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit -p fixtures`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): fixtures on lesson versions; editor and player screens`

### Task 18: Content export and import
App: server
Phase: 4
Recipe: `/api` · SPEC §server "Export and import", 05 §6 (in full), D13, D38, F3, F7

**Files:**
- Create: `server/scripts/content-export.ts` — reads a restored dump (old tables), writes `bundle.json` + `report.md`
- Create: `server/scripts/content-import.ts` — loads a bundle into the new tables; re-runnable
- Create: `server/scripts/content-convert.ts` — the pure 05 §6 mapping, shared by both
- Test: `server/scripts/__tests__/content-convert.test.ts`, `server/test/content-import.test.ts`

**Interfaces:**
- Produces: `convertActivity(old)` — takes an old `LessonActivity` with its read blocks, highlights and source refs, returns `{ activities: [{ activityKey, kind, title, document }], losses: string[] }`; `runExport(databaseUrl, outDir, { confirmProduction })`; `runImport(databaseUrl, bundlePath, { confirmProduction })` → `{ created, updated, conflicts: string[] }`
- Consumes: `parseActivityDocument`, `hashLessonContent` (Task 2)

**Behaviour:**
- mapping is 05 §6's table in full: `VIDEO`→`video`, `YOUTUBE`→`youtube`, `USER_INPUT`→`write` (prompt from title + help text, placeholder kept), `EXEGESIS`→`bible` with highlights and notes moved into its text object, `READ` locked scripture→`bible`, `READ` unstyled blocks→one `text` object (markdown → `weight` + `marks`), `READ` block with its own background→its own `text` activity (05 §6)
- `activityKey` = the old `LessonActivity.id`; a split block's extra activities get `<oldId>:<n>`; `Lesson.id` is kept and `Lesson.programId`/`position` are backfilled from `studyProgramId`/`dayNumber` (§server, Data plan step 2)
- each program's latest published content → version 1 `PUBLISHED`; unpublished edits → its DRAFT; a `ProgramVersion` 1 lists them and `StudyProgram.currentVersionId` points at it (05 §6)
- imported text: single column, `verticalAnchor: top`, 24u margins (`transform.x = 220`, `width = 392`) (05 §6, F3)
- themes dropped; font scale → `size`; animated themes import static (05 §6)
- a `backgroundImageUrl` with no `Media` row gets one registered; an unresolved `Video`/`Media` reference is listed in the report (F7)
- not carried: enrollments, progress, notes, analytics rows (D13)
- re-run: upsert by `activityKey`; a DRAFT's content is replaced only when its current hash equals the hash recorded at the previous import (stored in the bundle's import ledger table or a JSON sidecar the import writes); otherwise kept and listed as a conflict (D38)
- the report lists, per program, counts by old type and new kind, every lossy conversion, every unresolved reference and every D38 conflict (§server)
- both scripts refuse a `DATABASE_URL` whose host is not `localhost`/`127.0.0.1`/a `postgres_vt_*` lease unless `--confirm-production` is passed (§server)

**Tests:**
- `converts every row of the 05 §6 table` (05 §6)

```ts
it.each(OLD_ROWS)('converts $name', ({ old, expectKinds }) => {
  const r = convertActivity(old)
  expect(r.activities.map(a => a.kind)).toEqual(expectKinds)
  for (const a of r.activities) expect(parseActivityDocument(a.document, a.kind).ok).toBe(true)
})
```

- `the first activity keeps the old id as its key` (§server)

```ts
it('the first activity keeps the old id as its key', () => {
  expect(convertActivity(OLD_ROWS[0].old).activities[0].activityKey).toBe(OLD_ROWS[0].old.id)
})
```

- `import is idempotent` (D38)

```ts
it('import is idempotent', async () => {
  const bundle = await exportFrom(await seedOldModelDump())
  const a = await runImport(url, bundle, {}), b = await runImport(url, bundle, {})
  expect(b.created).toBe(0); expect(b.conflicts).toEqual([])
  expect(await prisma.contentActivity.count()).toBe(a.created)
})
```

- `a draft edited after import is kept and reported` (D38)

```ts
it('a draft edited after import is kept and reported', async () => {
  const bundle = await exportFrom(await seedOldModelDump({ unpublishedEdit: true }))
  await runImport(url, bundle, {})
  const draft = await prisma.contentActivity.findFirstOrThrow({ where: { lessonVersion: { status: 'DRAFT' } } })
  await prisma.contentActivity.update({ where: { id: draft.id }, data: { document: EDITED } })
  const r = await runImport(url, bundle, {})
  expect(r.conflicts).toContain(draft.activityKey)
  expect((await prisma.contentActivity.findUniqueOrThrow({ where: { id: draft.id } })).document).toEqual(EDITED)
})
```

- `a production URL is refused without the flag` (§server)

```ts
it('a production URL is refused without the flag', async () => {
  await expect(runImport('postgresql://u:p@db.railway.internal:5432/railway', 'b.json', {})).rejects.toThrow(/--confirm-production/)
})
```

(`OLD_ROWS` holds one old-row fixture per 05 §6 table row; `seedOldModelDump` writes old-model rows into the lease DB, where Task 1 left the old tables in place.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Run `cd server && npx vitest run scripts/__tests__/content-convert.test.ts`, watch it fail; request a verifier run for the DB test (`node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`), watch it fail**
- [ ] **Step 3: Implement `content-convert.ts`, then the two scripts, to the Behaviour**
- [ ] **Step 4: Run the same commands and `npx --no-install tsc --noEmit`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): 1.0 content export, conversion and re-runnable import`

### Task 19: The cutover migration, the runbook — and the contract freeze
App: server
Phase: 4
Recipe: SPEC D27, D30, D42, §Data plan steps 3–4 · REFERENCE §Contract and the contract freeze

**Files:**
- Modify: `server/schema/schema.yaml`, `enums.yaml` — final state: SC8 models and `TemplateActivityType` removed (SC9); back-relations on `Video`, `User`, `Organization`, `LessonTemplate` removed (SC14); `Lesson.programId` and `Lesson.position` required (`StudyProgram.currentVersionId` stays optional); old columns removed from the models; regenerate Prisma and HCL
- Create: `server/atlas/cutover/<ts>_text_activity_cutover.sql` — hand-written; NOT in `server/atlas/migrations/`; `atlas.sum` unchanged
- Create: `docs/features/text-activity/CUTOVER.md` — the owner's runbook
- Test: `server/test/text-activity-cutover.test.ts`

**Interfaces:**
- Produces nothing for the iPhone; closes the producer phases.

The cutover SQL's statements, in this order (D27, D42, D13, SC8–SC14, Data plan 3–4):

```sql
-- text-activity cutover. Applied ONLY by the owner's runbook (CUTOVER.md), after a verified pg_dump.
BEGIN;
DELETE FROM "note_links" WHERE "refType" IN ('LESSON_ACTIVITY','SCHEDULED_ACTIVITY','LESSON_SCHEDULE');   -- D42
DELETE FROM "preview_states";                                                                            -- D42
DELETE FROM "client_events" WHERE "lessonScheduleId" IS NOT NULL OR "scheduledActivityId" IS NOT NULL;   -- D42
DELETE FROM "ai_lesson_summaries" WHERE "scheduledLessonId" IS NULL;                                     -- D13 (derived rows)
DELETE FROM "enrollments";                                                                               -- D13: not carried
DELETE FROM "lessons" WHERE "programId" IS NULL;                                                         -- never imported
ALTER TABLE "lessons" ALTER COLUMN "programId" SET NOT NULL, ALTER COLUMN "position" SET NOT NULL;
DROP TABLE <every SC8 table> CASCADE;                                         -- one statement per table, by its real name
ALTER TABLE "lessons" DROP COLUMN "studyProgramId", DROP COLUMN "dayNumber", DROP COLUMN "title", DROP COLUMN "estimatedMinutes";
ALTER TABLE "enrollments" DROP COLUMN "syncedProgramVersionNumber";
ALTER TABLE "study_programs" DROP COLUMN "currentVersionNumber";
ALTER TABLE "events" DROP COLUMN "lessonScheduleId";
ALTER TABLE "ai_lesson_summaries" DROP COLUMN "lessonScheduleId";
ALTER TABLE "lesson_template_activities" DROP COLUMN "type";
ALTER TABLE "client_events" DROP COLUMN "lessonScheduleId", DROP COLUMN "scheduledActivityId", DROP COLUMN "activityType";
DROP TYPE IF EXISTS "TemplateActivityType";
COMMIT;
```

(`StudyProgram.currentVersionId` is optional in the final YAML — an unpublished program has no version; the SPEC's Data plan step 3 names it among the backfills, and the import sets it for every program with content. Use real table and column names from `schema.prisma` `@@map`/`@map` wherever they differ from the ones above.)

**Behaviour:**
- no file under `server/atlas/migrations/` drops a SC8 table or an old column; the drop exists only under `server/atlas/cutover/` (D27, D30)
- the cutover SQL applies cleanly to a lease database that has every committed migration plus an import run, and afterwards the generated Prisma client's models all resolve (D27)
- `CUTOVER.md` lists, in order: `pg_dump` and its verification (restore into a scratch DB, row counts compared); restore to scratch; `content-export` dry run; the owner reads the report; deploy this branch (additive migrations run at boot); `content-export` + `content-import` against production with `--confirm-production`, immediately before the drop (D38); move the cutover file into `server/atlas/migrations/`, `migrate hash`, deploy; the undo is the `pg_dump` restore. It warns that any other feature's `migrate diff` before cutover will try to emit these drops, and that the guard test catches it (D27, D30, D38)
- this task records the freeze: `contract: frozen <today>` on the manifest (REFERENCE §Contract and the contract freeze)

**Tests:**
- `the drop lives only under cutover/` (D30)

```ts
it('the drop lives only under cutover/', () => {
  const live = readAllMigrations()
  expect(live).not.toMatch(/DROP TABLE[^;]*"(lesson_activities|lesson_schedules|text_themes|enrollment_sync_runs)"/)
  expect(readCutover()).toMatch(/DROP TABLE[^;]*"lesson_activities"/)
})
```

- `the cutover applies to a migrated and imported database` (D27)

```ts
it('the cutover applies to a migrated and imported database', async () => {
  await withMigratedScratchDb(async url => {
    await runImport(url, await exportFrom(await seedOldModelDump()), {})
    await applySql(url, readCutover())
    const c = new PrismaClient({ datasourceUrl: url })
    expect(await c.contentActivity.count()).toBeGreaterThan(0)
    expect(await c.lesson.count()).toBeGreaterThan(0)
    await c.$disconnect()
  })
})
```

(`withMigratedScratchDb` creates a `postgres_vt_*` scratch DB from the lease, applying every committed migration with `atlas migrate apply` — extend `test/helpers/master-search-db.ts`'s scratch helper.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Finalize the YAML (`cd server && npm run schema:generate`; never `migrate diff` into `migrations/`), write the cutover SQL and `CUTOVER.md`**
- [ ] **Step 4: Run `cd server && npm run schema:validate && npx --no-install tsc --noEmit && npx --no-install tsc --noEmit -p fixtures`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): cutover drop under atlas/cutover and the owner's runbook`
- [ ] **Step 6: Record the freeze** — `node <builder>/scripts/advance.mjs docs/features/text-activity --set "contract=frozen <YYYY-MM-DD>" --commit "chore(text-activity): contract frozen"`

### Task 20: The d2m request for the editor and player changes
App: iphone
Phase: 5
Recipe: d2m-channel MCP (`check_project_change`, `request_project_change`, `wait_project_change`, `answer_project_change`) · SPEC D33, D22, F15 build-time risk below. **Needs the `d2m-channel` MCP server**: the build loop runs this task in a session that has it, not a tool-less implementer

**Files:**
- No hand edits. d2m's own commits land under `iphone/MakeReadyUI/Screens/Activities/` (and any component it names) on this branch
- Create: `docs/features/text-activity/d2m-request.md` — the request's intent and the change id d2m returns, committed as the reference the request cites

**Interfaces:**
- Produces (from d2m, names as d2m returns them; record them in `d2m-request.md` for Tasks 24–27): on `ActivitiesEditorScreen` — an object-edit callback carrying the object index and the changed fields (text, font, weight, size, color, alignment, width, transform); `State` colors as hex strings with C-094 swatches as presets; an Idle-header play glyph with its callback; a load-failed state (banner, then pop) on both `ActivitiesEditorScreen` and `ActivitiesPlayerScreen`

> **Build-time risk (F15):** d2m returns the change before the container tasks (24–27) start. Do not close this task until `wait_project_change` reports done and the commits are on the branch.

**Behaviour:**
- one `request_project_change` on subject `ActivitiesEditorScreen` (and `ActivitiesPlayerScreen` for the load-failed state), `references: ["docs/features/text-activity/d2m-request.md"]`, `branch` = this branch, with the four D33 items; intent ≤ 2000 chars (memory: d2m request pitfalls)
- `check_project_change` first; a `fast` lane is still delivered by d2m because the view files are d2m-owned (D33 rejected in-place edits)
- a handback is settled from the SPEC: questions answered with D17/D18/D22/D33's rulings via `answer_project_change`; held items approved; a failed step retried once; park only on a `cannot be done:` reply
- the screen still carries every document field it doesn't edit through unchanged — the container's job, so no request item asks the screen to hold them (D33)

**Tests:**
- `ActivitiesEditorScreenContractTests` — compiles only when the callback and play glyph exist (D33)

```swift
final class ActivitiesEditorScreenContractTests: XCTestCase {
    func testEditorExposesObjectEditAndPlay() {
        var edits = 0, plays = 0
        let screen = ActivitiesEditorScreen(state: .preview, onObjectEdit: { _ in edits += 1 }, onPlay: { plays += 1 })
        screen.onObjectEdit(.preview); screen.onPlay()
        XCTAssertEqual([edits, plays], [1, 1])
    }
    func testColorsAreHex() {
        XCTAssertTrue(ActivitiesEditorScreen.State.preview.draftColor.hasPrefix("#"))
    }
}
```

(Rename `onObjectEdit`, `onPlay`, `.preview` and the edit payload type to what d2m returns; the test pins existence and hex colours, nothing more.)

- [ ] **Step 1: Write `d2m-request.md` (the four D33 items, each with its SPEC row) and commit it** — `docs(text-activity): d2m request for the editor and player`. This task carries two commits of its own by necessity: d2m reads `references` from the branch, so the reference lands before the request
- [ ] **Step 2: `check_project_change`, then `request_project_change`, then `wait_project_change` until done, settling handbacks per the Behaviour**
- [ ] **Step 3: Write `iphone/MakeReadyCaptureTests/ActivitiesEditorScreenContractTests.swift` against the returned names**
- [ ] **Step 4: Request a verifier run and watch it pass** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (XCTest runs on the verifier's own simulator; never launch one yourself)
- [ ] **Step 5: Commit** — `test(text-activity): editor screen exposes object edits, hex colours and play`; record the change id and returned names in `d2m-request.md` in the same commit

### Task 21: Models and the lenient document decoder
App: iphone
Phase: 5
Recipe: SPEC §iphone "State", D11, §Contract "Shapes"

**Files:**
- Create: `iphone/MakeReady/State/Models/ContentActivityModels.swift` — `ContentActivity`, `LessonVersion`, `ActivitySummary`, `MediaMapEntry`, `LessonVersionPayload`
- Create: `iphone/MakeReady/State/Models/ActivityDocument.swift` — envelope-first decode, typed views, raw-preserving re-encode
- Create: `iphone/MakeReady/State/Models/JSONValue.swift` — `JSONValue` moved out of `ThemeModels.swift:14` (that file goes in Task 22)
- Test: `iphone/MakeReadyCaptureTests/ActivityDocumentTests.swift`, `iphone/MakeReadyCaptureTests/ContentActivityDecodingTests.swift`

**Interfaces:**
- Produces: `ContentActivity` (`Codable`, `Identifiable`, `Hashable`) with `id`, `lessonVersionId`, `activityKey`, `position`, `kind`, `title`, `document: ActivityDocument`, `estimatedSeconds: Int?`; `LessonVersion` with `id`, `lessonId`, `enrollmentId: String?`, `number`, `status: Status` (`.draft`, `.published`, raw `DRAFT`/`PUBLISHED`), `title: String?`, `estimatedSeconds: Int?`, `publishedAt: Date?`; `ActivitySummary` with `id`, `activityKey`, `position`, `kind`, `title`, `document`; `MediaMapEntry` with `url`, `width?`, `height?`, `kind`, `playbackUrl?`, `posterUrl?`, `durationSeconds?`, `uploaderName?`; `LessonVersionPayload` with `version`, `activities`, `media: [String: MediaMapEntry]`
- Produces: `ActivityDocument` — `raw: JSONValue`; `renderable: Renderable` where `enum Renderable { case canvas(CanvasContent), video(VideoContent), youtube(YouTubeContent), write(WriteContent), fallback(title: String, body: String) }`; `background: Background`, `actions: [Action]`; `func updating(_ edit: (inout JSONValue) -> Void) -> ActivityDocument`; `encode` writes `raw`
- Produces: `TextObject` with `id`, `text`, `font`, `weight`, `size`, `lineHeight`, `color`, `alignment`, `transform`, `marks`, `highlights`; `func utf16Range(start:end:) -> Range<String.Index>?` for marks and highlights

**Behaviour:**
- decoding never throws for a document: the envelope decodes first; an unknown `kind`, `schemaVersion > 1`, or content that fails to decode yields `.fallback(title:body:)` from `fallback` (defaults "A new activity" / "Update the app to see this."), and a malformed one logs (D11, 02 §9)
- unknown fields survive a decode → edit → encode cycle unchanged (02 §9 "preserved on save")
- `marks`/`highlights` offsets are UTF-16 code units; `utf16Range` converts at the boundary (02 §3)
- an unknown action `kind` decodes and is skipped by `actions`' renderable list (02 §9)

**Tests:**
- `testUnknownKindHigherVersionAndMalformedAllFallBack` (D11)

```swift
func testUnknownKindHigherVersionAndMalformedAllFallBack() throws {
    for json in [Fixture.quiz, Fixture.textSchemaV2, Fixture.textMissingObjects] {
        let doc = try JSONDecoder().decode(ActivityDocument.self, from: Data(json.utf8))
        guard case .fallback(let title, _) = doc.renderable else { return XCTFail("expected fallback for \(json.prefix(40))") }
        XCTAssertFalse(title.isEmpty)
    }
}
```

- `testUnknownFieldsSurviveAnEditAndSave` (02 §9)

```swift
func testUnknownFieldsSurviveAnEditAndSave() throws {
    let doc = try JSONDecoder().decode(ActivityDocument.self, from: Data(Fixture.textWithFutureFields.utf8))
    let edited = doc.updating { $0[path: ["content", "objects", 0, "text"]] = .string("Edited") }
    let out = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edited)) as! [String: Any]
    XCTAssertEqual(out["futureField"] as? String, "kept")
    XCTAssertEqual(((out["content"] as! [String: Any])["objects"] as! [[String: Any]])[0]["glow"] as? String, "soft")
}
```

- `testUTF16OffsetsAfterEmoji` (02 §3)

```swift
func testUTF16OffsetsAfterEmoji() {
    let obj = TextObject.fixture(text: "🙏 Pray now")
    let range = obj.utf16Range(start: 3, end: 8)!
    XCTAssertEqual(String(obj.text[range]), "Pray ")
}
```

- `testLessonVersionPayloadDecodes` (§Contract)

```swift
func testLessonVersionPayloadDecodes() throws {
    let p = try JSONDecoder.api.decode(LessonVersionPayload.self, from: Data(Fixture.draftPayload.utf8))
    XCTAssertEqual(p.version.status, .draft)
    XCTAssertEqual(p.activities.map(\.activityKey), ["k1", "k2"])
    XCTAssertEqual(p.media["m1"]?.kind, "image")
}
```

(`Fixture` is a private enum in each test file holding the JSON strings — `quiz` is a valid envelope with `kind: "quiz"`; `draftPayload` is a §Contract `GET /draft` response. `JSONDecoder.api` is the app's configured decoder — use the name `APIClient` uses. `JSONValue` gains a `subscript(path:)` setter if it lacks one.)

- [ ] **Step 1: Write the listed tests** — one `final class` per file, named after the file (memory rule)
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (XCTest runs on the verifier's own simulator); check `results.jsonl` names each new test
- [ ] **Step 3: Implement the three model files to the Behaviour; run `ruby iphone/scripts/makereadyui-sync.rb` or the project's file-registration script so the new files compile in the app target**
- [ ] **Step 4: Run the same verifier request and `cd iphone && swiftlint`, and watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): content activity models and a lenient document decoder`

### Task 22: Program-side state and Actions on the new model
App: iphone
Phase: 5
Recipe: `/ios-error-surface` · SPEC §iphone "State", D41, D45

**Files:**
- Modify: `iphone/MakeReady/State/AppState.swift:84-135,264,630,687-738,1001-1090,1213-1221` — `activities: EntityStore<ContentActivity>`, add `lessonVersions: EntityStore<LessonVersion>` and `mediaMap: [String: MediaMapEntry]`; remove `contentHighlights`, `textThemes`; drop the `/api/themes` launch call; clear all in `clearInMemory()`
- Create: `iphone/MakeReady/State/Actions/ActivityActions.swift` — the draft endpoints
- Delete: `ProgramActions+Activities.swift`, `ThemeActions.swift`, `HomeActions.swift`, `Services/Highlighting/*`, `Utilities/ActivityStyle.swift`, `StripContent.swift`, `State/Models/ThemeModels.swift`; old program-side types in `StudyModels.swift:296-408,439-1098` (`StudyActivity`, `ActivityReadBlock`, `ContentHighlight`, `ActivitySourceReference`, `ActivityType`, `PassageData`) unless the enrollment side still compiles against one (then Task 23 deletes it)
- Modify: `ProgramActions.swift:384-417` (publish → `POST /publish`, D41), `ProgramActions+Lessons.swift:19-102`, `Lesson` in `StudyModels.swift` (§Contract program-read fields), `UI2/Containers/Programs/StudyProgramHomeMapper.swift:21-67`, `StudyProgramHomeContainer.swift:293,348`
- Test: `iphone/MakeReadyCaptureTests/ActivityActionsTests.swift`, `ProgramActionsPublishTests.swift`; port `StudyProgramHomeMapperTests`, `StudyProgramHomeContainerTests`, `ProgramActionsTests`, `ModelDecodingTests`; delete `Highlight*Tests`

**Interfaces:**
- Produces: `ActivityActions` with `loadDraft(lessonId:) async throws`, `loadVersion(id:) async throws`, `create(versionId:kind:title:document:) async throws -> ContentActivity`, `save(activityId:title:document:) async throws`, `delete(activityId:) async throws`, `reorder(versionId:activityIds:) async throws`; each writes `AppState.activities`, `lessonVersions`, `mediaMap` and refreshes the derived state in the same call; `AppState.activities(forVersion:) -> [ContentActivity]` sorted by `position`; `AppState.draftVersionId(forLesson:) -> String?`
- Produces: `ActivityActionsError.notDraft` thrown on a 409 `NOT_DRAFT` (D46 consumes it in Task 25)
- Produces: `ProgramActions.publish(programId:changeSummary:) async throws -> PublishResult` with `programVersionNumber: Int?`, `changedLessonIds: [String]`
- Produces: `Lesson` fields `position`, `title`, `estimatedSeconds`, `draftVersionId`, `publishedVersionId`, `activities: [ActivitySummary]`
- Consumes: Task 21 models; the frozen §Contract rows 1–9

**Behaviour:**
- every Action decodes the §Contract shape, writes `AppState`, and returns `Void` (or the created entity for `create`, which the Text tile needs); no Page or Component calls `APIClient` (house rule)
- a non-409 failure throws to the caller; routing to the banner is the container's (`/ios-error-surface`)
- `StudyProgramHomeMapper` reads `title`, `estimatedSeconds` (shown as minutes, `ceil(/60)`), `position` and the rail slides from `activities` (D26 renders them in Task 24's slide view); publish goes through `POST /api/programs/:id/publish` (D41)
- uncompiled legacy files under `Pages/` and `Components/` stay untouched (D45)

**Tests:**
- `testCreateAppendsToTheVersionAndStoresMedia` (§Contract)

```swift
func testCreateAppendsToTheVersionAndStoresMedia() async throws {
    let api = StubAPIClient(responses: ["POST /api/lesson-versions/v1/activities": Fixture.createResponse])
    let state = AppState.testing()
    let act = try await ActivityActions(api: api, state: state).create(versionId: "v1", kind: "text", title: "Text", document: .emptyText)
    XCTAssertEqual(state.activities(forVersion: "v1").map(\.id), [act.id])
    XCTAssertNotNil(state.mediaMap["m1"])
}
```

- `testDeleteRemovesAndClosesUpPositions` (§Contract)

```swift
func testDeleteRemovesAndClosesUpPositions() async throws {
    let state = AppState.testing(activities: [.fixture(id: "a", position: 0, version: "v1"), .fixture(id: "b", position: 1, version: "v1")])
    let api = StubAPIClient(responses: ["DELETE /api/content-activities/a": #"{"success":true}"#])
    try await ActivityActions(api: api, state: state).delete(activityId: "a")
    XCTAssertEqual(state.activities(forVersion: "v1").map { [$0.id, String($0.position)] }, [["b", "0"]])
}
```

- `testSaveConflictThrowsNotDraft` (D46)

```swift
func testSaveConflictThrowsNotDraft() async {
    let api = StubAPIClient(responses: ["PUT /api/content-activities/a": .status(409, #"{"success":false,"code":"NOT_DRAFT","error":"x"}"#)])
    do { try await ActivityActions(api: api, state: .testing()).save(activityId: "a", title: nil, document: .emptyText); XCTFail() }
    catch { XCTAssertEqual(error as? ActivityActionsError, .notDraft) }
}
```

- `testPublishPostsToPublishAndReadsNullVersion` (D37, D41)

```swift
func testPublishPostsToPublishAndReadsNullVersion() async throws {
    let api = StubAPIClient(responses: ["POST /api/programs/p1/publish": #"{"programVersion":null,"changedLessonIds":[]}"#])
    let r = try await ProgramActions(api: api, state: .testing()).publish(programId: "p1", changeSummary: nil)
    XCTAssertNil(r.programVersionNumber); XCTAssertEqual(r.changedLessonIds, [])
}
```

(Match `StubAPIClient`'s and `AppState.testing`'s real signatures — read an existing `*ActionsTests.swift`; add `ActivityDocument.emptyText` as a test-only extension.)

- [ ] **Step 1: Write the listed tests and port the four existing ones**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Retype `AppState`, write `ActivityActions`, move the program-side Actions and mapper, delete the listed files**
- [ ] **Step 4: Run the same verifier request and `cd iphone && swiftlint`, watch them pass; check `results.jsonl` names each new test**
- [ ] **Step 5: Commit** — `feat(text-activity): program-side state and Actions on lesson versions`

### Task 23: Enrollment-side state, Actions and the disk cache
App: iphone
Phase: 5
Recipe: `/ios-error-surface` · SPEC §iphone "State", D44, §Contract enrollment rows

**Files:**
- Modify: `iphone/MakeReady/State/Models/LessonModels.swift:16,237,329` — `ScheduledActivity`, `LessonWithActivities`, `LessonSchedule` replaced by what the "same shape" rows decode (`lessonSchedules[]` keys, activity `type` = kind)
- Modify: `EnrollmentModels.swift:276,566,583-640` (sync models: adds `skippedCustomizedLessonIds`), `EnrollmentBrowseModels.swift:99-150`, `GroupPageModels.swift:29-90`
- Modify: `AppState.swift` — `scheduledLessons` retyped, `lessonScheduleMap` removed or retyped, cleared in `clearInMemory()`
- Modify: `EnrollmentActions.swift`, `GroupActions.swift:815`; `UI2/Containers/Enrollments/EnrollmentHomeMapper.swift:52-62`, `EnrollSelectScheduleContainer.swift:93`, `EnrollChecklistContainer.swift:34` (`slideLabel` reads `kind`)
- Modify: `State/Persistence/PersistedState.swift:39-58,107,140,176-297`, `StatePersistence.swift:83-93` — `schemaVersion = 2`; a different version is discarded at launch
- Delete: whatever old type Task 22 left for this side
- Test: `iphone/MakeReadyCaptureTests/PersistedStateVersionTests.swift`, `EnrollmentSyncDecodingTests.swift`; port `StatePersistenceRoundTripTests`, `GroupDetailMapperTests`, `GroupsBrowseDecodingTests`

**Interfaces:**
- Produces: `PersistedState.currentSchemaVersion` = `2`; `StatePersistence.load() -> PersistedState?` returns `nil` and deletes the file when `schemaVersion != 2`
- Produces: `EnrollmentSyncResult.skippedCustomizedLessonIds: [String]`
- Consumes: Task 21–22 models; the frozen §Contract rows 10–13

**Behaviour:**
- a version-1 cache (or one without `schemaVersion`) is discarded at launch, never leniently decoded (D44)
- the three sync version numbers decode as `ProgramVersion.number` values under today's keys; `skippedCustomizedLessonIds` decodes, defaulting to `[]` (D5)
- every "same shape" response decodes with today's keys; `slideLabel` reads the activity `type` string as the new kind (§Contract)

**Tests:**
- `testVersionOneCacheIsDiscarded` (D44)

```swift
func testVersionOneCacheIsDiscarded() throws {
    let url = try TempCache.write(#"{"schemaVersion":1,"programs":[]}"#)
    XCTAssertNil(StatePersistence(fileURL: url).load())
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
}
```

- `testVersionTwoRoundTrips` (D44)

```swift
func testVersionTwoRoundTrips() throws {
    let p = StatePersistence(fileURL: try TempCache.empty())
    try p.save(PersistedState.fixture(activities: [.fixture(id: "a", position: 0, version: "v1")]))
    XCTAssertEqual(p.load()?.activities.map(\.id), ["a"])
}
```

- `testSyncApplyDecodesSkippedLessons` (D5)

```swift
func testSyncApplyDecodesSkippedLessons() throws {
    let r = try JSONDecoder.api.decode(EnrollmentSyncResult.self, from: Data(#"{"syncedProgramVersionNumber":2,"currentVersionNumber":2,"skippedCustomizedLessonIds":["l2"]}"#.utf8))
    XCTAssertEqual(r.skippedCustomizedLessonIds, ["l2"])
}
```

(Use `StatePersistence`'s real initializer and the real name of the sync-apply response type; `TempCache` is a private helper in the test file.)

- [ ] **Step 1: Write the listed tests and port the three existing ones**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Move the enrollment-side models, state, Actions, mappers and the cache to the Behaviour**
- [ ] **Step 4: Run the same verifier request and `cd iphone && swiftlint`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): enrollment-side state on scheduled lessons; disk cache v2`

### Task 24: Destinations, the Text tile, entry points and the background pick
App: iphone
Phase: 6
Recipe: `/nav-route` · SPEC D14, D15, D16, D26, D39, D40

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-92` — `case activitiesEditor(activityId: String)`, `case activityViewer(lessonVersionId: String, activityId: String)`; `isFullScreen` true for the viewer
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:236` — route both cases to their containers (the editor container is Task 25's, the viewer's Task 27's; until then each case renders its container's placeholder init, which those tasks replace)
- Modify: `iphone/MakeReady/UI2/Containers/Programs/ActivityNewContainer.swift:1-36` — Text tile (D16), `unavailableTypes` (D15), slide taps (D39)
- Modify: `StudyProgramHomeContainer.swift:92-105` — `onOpenActivity` (D39); rail slides render C-092 viewer mode at thumbnail scale (D26)
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift:17-20,471-484`, `CoverOwner.swift:5-8` — a pick mode returning a `mediaId` to its caller (D40)
- Create: `iphone/MakeReady/UI2/Containers/Programs/ActivityEntry.swift` — the one rule for "open this activity"
- Test: `iphone/MakeReadyCaptureTests/ActivityEntryTests.swift`, `ActivityNewContainerTests.swift`

**Interfaces:**
- Produces: `ActivityEntry.destination(for kind: String, activityId: String) -> ActivityEntry.Result` where `enum Result { case open(UI2Destination), cannotEdit(message: String) }`; `ActivityEntry.cannotEditMessage` = `"This activity can't be edited yet."`; `ActivityEntry.canvasKinds` = `["text", "bible"]`
- Produces: `MediaPickMode.activityBackground(onPick: (String) -> Void)` (or the case name that fits `CoverOwner`'s pattern) — returns the picked `mediaId`
- Produces: `ActivityNewContainer.textDocument(title:)` — the starter `ActivityDocument` for a new Text activity (empty canvas, `background.color` = the C-094 first preset, `chrome.topAction: "share"`, `fallback` per 02 §2)
- Consumes: `ActivityActions.create` (Task 22); `UI2Destination`

**Behaviour:**
- tapping Text calls `create(versionId:kind:"text", title:"Text", document:textDocument)` on the lesson's draft (loading it first if needed), disables the tile while the request is in flight, then swaps to `.activitiesEditor(activityId:)` in place (D16)
- `unavailableTypes` = Bible verse, Video, YouTube, Write and Poll — visible, dimmed, inert (D15)
- a slide tap (picker `onSelectSlide`, program home `onOpenActivity`) for `text`/`bible` opens `.activitiesEditor`; any other kind shows "This activity can't be edited yet." through the error banner channel (D14, D39)
- a create failure surfaces the banner and leaves the tile enabled (`/ios-error-surface`)
- program-home rail slides for canvas kinds render the document with C-092 viewer mode at thumbnail scale; other kinds keep their tile glyph (D26)
- the Background sheet's image pick opens Media in the new pick mode and returns the `mediaId` (D40)

**Tests:**
- `testCanvasKindsOpenTheEditorOthersCannotEdit` (D14, D39)

```swift
func testCanvasKindsOpenTheEditorOthersCannotEdit() {
    XCTAssertEqual(ActivityEntry.destination(for: "bible", activityId: "a"), .open(.activitiesEditor(activityId: "a")))
    XCTAssertEqual(ActivityEntry.destination(for: "video", activityId: "a"), .cannotEdit(message: "This activity can't be edited yet."))
}
```

- `testOtherTilesAreUnavailable` (D15)

```swift
func testOtherTilesAreUnavailable() {
    XCTAssertEqual(Set(ActivityNewContainer.unavailableTypes), Set(["bibleVerse", "video", "youtube", "write", "poll"]))
}
```

- `testTextTileCreatesThenOpensTheEditor` (D16)

```swift
func testTextTileCreatesThenOpensTheEditor() async {
    let nav = RecordingNavigator()
    let model = ActivityNewContainer.Model(lessonId: "l1", actions: .stub(createdId: "new1"), navigator: nav)
    await model.selectText()
    XCTAssertEqual(nav.replaced, [.activitiesEditor(activityId: "new1")])
    XCTAssertFalse(model.isCreating)
}
```

- `testViewerIsFullScreen` (D39)

```swift
func testViewerIsFullScreen() {
    XCTAssertTrue(UI2Destination.activityViewer(lessonVersionId: "v", activityId: "a").isFullScreen)
    XCTAssertFalse(UI2Destination.activitiesEditor(activityId: "a").isFullScreen)
}
```

(Use the raw case names `ActivityTypeGrid.ActivityType` declares at `ActivityTypeGrid.swift:28`; `RecordingNavigator` and `.stub` are test doubles over whatever seam the container takes for navigation and Actions — give the container that seam if it has none.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Add the destinations, `ActivityEntry`, the container wiring, the slide rendering and the pick mode**
- [ ] **Step 4: Run the same verifier request and `cd iphone && swiftlint`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): Text tile, activity entry points and the background pick`

### Task 25: The editor container — load, edit buffer, Done, conflicts, back-out
App: iphone
Phase: 6
Recipe: `/ios-error-surface` · `/transition-review` before commit · SPEC §iphone "Editor wiring", D16, D17, D33, D46

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorContainer.swift` — owns the edit buffer and the store ↔ screen mapping
- Create: `iphone/MakeReady/UI2/Containers/Programs/ActivitiesEditorMapper.swift` — pure: `ActivityDocument` + `MediaMap` → `ActivitiesEditorScreen.State`, and an object edit → document patch
- Modify: `UI2Shell.swift` — `.activitiesEditor` renders this container
- Test: `iphone/MakeReadyCaptureTests/ActivitiesEditorMapperTests.swift`, `ActivitiesEditorContainerTests.swift`

**Interfaces:**
- Produces: `ActivitiesEditorMapper.state(document:media:slides:activeID:) -> ActivitiesEditorScreen.State`; `ActivitiesEditorMapper.apply(_ edit: <d2m's edit payload>, to: ActivityDocument) -> ActivityDocument`; `ActivitiesEditorMapper.isUntouched(_ doc: ActivityDocument) -> Bool`
- Consumes: d2m's object-edit callback, hex colours, play glyph and load-failed state (Task 20, names in `docs/features/text-activity/d2m-request.md`); `ActivityActions.loadDraft`, `save`, `delete` and `ActivityActionsError.notDraft` (Task 22); `MediaPickMode.activityBackground` (Task 24)

**Behaviour:**
- the mapper sets `showsHighlightTool`, `showsEffectsTool`, `showsEyedropper` to `false` (D17)
- font keys map `display|sans|serif|mono` ↔ Poppins, Inter, Source Serif 4, Courier Prime; an unknown key renders as `sans` (D18)
- each object edit patches only the edited fields of that object in the document buffer; every other document field passes through unchanged (D33)
- Done PUTs the whole document per the screen's optimistic rule (D3)
- Done on 409 `NOT_DRAFT`: reload `GET /draft`, find the activity by `activityKey`, re-PUT once to its new id; a second failure shows "Couldn't save activity" with Retry and Discard changes (D46)
- backing out of an activity with no objects, the starter background colour and no actions deletes it (D16)
- the play glyph pushes `.activityViewer(lessonVersionId: <the draft's id>, activityId:)` (D22)
- a failed load shows the screen's load-failed state, then pops (D33 item 4)
- no `.sheet`, no `.fullScreenCover`, no `asyncAfter` (house rule)

**Tests:**
- `testFlagsOffAndFontsMapped` (D17, D18)

```swift
func testFlagsOffAndFontsMapped() {
    let s = ActivitiesEditorMapper.state(document: .fixtureTwoObjects, media: [:], slides: [], activeID: "a")
    XCTAssertEqual([s.showsHighlightTool, s.showsEffectsTool, s.showsEyedropper], [false, false, false])
    XCTAssertEqual(s.objectFonts, ["Source Serif 4", "Poppins"])
}
```

- `testAnEditPatchesOnlyItsFields` (D33)

```swift
func testAnEditPatchesOnlyItsFields() throws {
    let out = ActivitiesEditorMapper.apply(.fixture(index: 0, color: "#FF0000"), to: .fixtureTwoObjectsWithFutureFields)
    let json = try out.jsonObject()
    XCTAssertEqual(json.objects[0]["color"] as? String, "#FF0000")
    XCTAssertEqual(json.objects[0]["glow"] as? String, "soft")
    XCTAssertEqual(json.objects[1] as NSDictionary, try ActivityDocument.fixtureTwoObjectsWithFutureFields.jsonObject().objects[1] as NSDictionary)
}
```

- `testNotDraftRefetchesRemapsAndRePutsOnce` (D46)

```swift
func testNotDraftRefetchesRemapsAndRePutsOnce() async {
    let actions = ScriptedActivityActions(save: [.failure(.notDraft), .success], draft: .withActivity(id: "a2", key: "k1"))
    let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
    await model.done()
    XCTAssertEqual(actions.savedIds, ["a1", "a2"]); XCTAssertNil(model.saveError)
}
```

- `testSecondFailureShowsRetryAndDiscard` (D46)

```swift
func testSecondFailureShowsRetryAndDiscard() async {
    let actions = ScriptedActivityActions(save: [.failure(.notDraft), .failure(.notDraft)], draft: .withActivity(id: "a2", key: "k1"))
    let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", actions: actions)
    await model.done()
    XCTAssertEqual(model.saveError?.message, "Couldn't save activity")
    XCTAssertEqual(model.saveError?.options, ["Retry", "Discard changes"])
}
```

- `testBackingOutOfAnUntouchedActivityDeletesIt` (D16)

```swift
func testBackingOutOfAnUntouchedActivityDeletesIt() async {
    let actions = ScriptedActivityActions()
    let model = ActivitiesEditorContainer.Model(activityId: "a1", activityKey: "k1", document: ActivityNewContainer.textDocument(title: "Text"), actions: actions)
    await model.back()
    XCTAssertEqual(actions.deletedIds, ["a1"])
}
```

(`fixtureTwoObjects` is serif then display; `jsonObject().objects` is a test-only accessor; `ScriptedActivityActions` is a test double over the protocol the container takes — introduce `ActivityActionsProtocol` if needed.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the mapper and container to the Behaviour; route the shell case**
- [ ] **Step 4: Run `/transition-review` on the diff, the same verifier request and `cd iphone && swiftlint`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): activity editor container with save, conflict retry and back-out`

### Task 26: The viewer engine and the shared vectors
App: iphone
Phase: 7
Recipe: SPEC D10, `docs/features/activity-viewer/01-experience.md` §4–§8, §13; F4 build-time risk below

**Files:**
- Create: `iphone/MakeReady/UI2/Viewer/ViewerEngine.swift` — pure Swift, imports `Foundation` only
- Create: `iphone/MakeReady/UI2/Viewer/viewer-engine-vectors.json` — the §13 table as data, bundled into the test target too
- Test: `iphone/MakeReadyCaptureTests/ViewerEngineTests.swift`

**Interfaces:**
- Produces: `ViewerEngine` (a `struct`) with `viewportHeight: Double`, `pageHeights: [Double]`, `anchor: Int`, `drag: Double`, `inner: [Double]`, `owner: Owner` (`.none`, `.inner`, `.pager`), `activePage: Int`, `settle: Settle?`; methods `touchBegan()`, `touchMoved(dy: Double) -> [Output]`, `touchEnded(velocity: Double) -> [Output]`, `tick(dt: Double) -> [Output]`, `static railWindow(active: Int, pageCount: Int) -> (start: Int, slots: Int)`, `thumbFraction(page: Int) -> Double?`; `enum Output { case activeChanged(Int), settled(Int), commitStarted(to: Int) }`
- Produces: constants `ViewerEngine.velocityProjection = 0.25`, `springOmega = 20`, `edgeResistance = 0.55`, `momentumDecay = 0.998` (per ms), `endEpsilon = 0.5`, `endSpeed = 5`

> **Build-time risk (F4):** `0.25` and `ω = 20` are measured brackets, not exact. The constants are the vectors' values; the device feel check (01 §13, walk item 6) may retune them — record any change in this file's header and in the vectors.

The decision and the spring, verbatim from 01 §6 (the tests can't determine the curve):

```
projected = drag + v × 0.25
if projected >  viewportHeight / 2 and a next page exists      → commit to next
if projected < −viewportHeight / 2 and a previous page exists  → commit to previous
otherwise                                                      → return to anchor
x(t) = (x₀ + (ωx₀ − v₀)·t) · e^(−ωt)    ω = 20; end when |x| < 0.5 pt and speed < 5 pt/s, then jump
```

**Behaviour:**
- ownership is decided once at first movement and held until lift: up with `inner < max` → `inner`; up at max → `pager`; down with `inner > 0` → `inner`; down at 0 → `pager` (01 §5)
- `pager`: `drag` follows 1:1 across rest in both directions; every `inner` is frozen; past the first page's top `drag` follows at 0.55× (01 §5)
- `inner`: follows 1:1, then momentum at ×0.998/ms; reaching a limit stops with no spill into `drag` (01 §5)
- snapping only on lift with `pager` owner and `drag ≠ 0`; one release moves at most one page (01 §6)
- `activePage` flips the instant `|drag|` passes `viewportHeight / 2`, emitting `activeChanged` once per crossing, and flips back on reversal (01 §7)
- `inner[i]` is retained for the session; a first visit from below starts at the page's max (01 §4)
- a touch during a settle stops the spring and hands the finger to `pager`; `anchor` becomes the page covering the midline (01 §6)
- rail window: `slots = min(5, pageCount)`, `start = clamp(active − 2, 0, pageCount − slots)`; thumb = `inner / maxInner`, `nil` when no range (01 §8)

**Tests:**
- `testEveryVectorPasses` — each §13 row, loaded from the JSON (D10)

```swift
func testEveryVectorPasses() throws {
    let url = Bundle(for: Self.self).url(forResource: "viewer-engine-vectors", withExtension: "json")!
    let cases = try JSONDecoder().decode([VectorCase].self, from: Data(contentsOf: url))
    XCTAssertGreaterThanOrEqual(cases.count, 16)
    for c in cases { XCTAssertEqual(c.run(), c.expect, c.name) }
}
```

- `testSettleCurveIsCriticallyDampedWithoutOvershoot` (01 §6)

```swift
func testSettleCurveIsCriticallyDampedWithoutOvershoot() {
    var e = ViewerEngine.fixture(pages: [956, 956], viewport: 956)
    e.touchBegan(); _ = e.touchMoved(dy: 500); _ = e.touchEnded(velocity: 0)
    var maxDrag = 0.0, t = 0.0
    while e.settle != nil, t < 2 { _ = e.tick(dt: 1.0 / 60); maxDrag = max(maxDrag, e.drag); t += 1.0 / 60 }
    XCTAssertLessThanOrEqual(maxDrag, 956.0001); XCTAssertEqual(e.anchor, 1)
    XCTAssertGreaterThan(t, 0.3); XCTAssertLessThan(t, 0.5)
}
```

(`VectorCase` decodes `{ name, start: { anchor, drag, inner, pageHeights, owner }, input: { kind: "lift"|"move"|"tick"|"rail", … }, expect: { … } }` and `run()` drives a `ViewerEngine`; write the JSON with every row of 01 §13 at `viewportHeight = 956`, in a shape a TypeScript engine can load unchanged.)

- [ ] **Step 1: Write the vectors JSON and the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement `ViewerEngine` to the Behaviour; add the JSON to both the app and test targets**
- [ ] **Step 4: Run the same verifier request and `cd iphone && swiftlint`, watch them pass; check `results.jsonl` names both tests**
- [ ] **Step 5: Commit** — `feat(text-activity): viewer engine with the shared position vectors`

### Task 27: The viewer container — load, drive, video and YouTube slots
App: iphone
Phase: 7
Recipe: `/transition-review` before commit · `/ios-error-surface` · SPEC §iphone "Viewer", D9, D12, D21–D25, D39

**Files:**
- Create: `iphone/MakeReady/UI2/Viewer/ActivityViewerContainer.swift` — loads, owns the engine, the pan recognizer and the display link
- Create: `iphone/MakeReady/UI2/Viewer/ActivityViewerMapper.swift` — pure: payload + engine → `ActivitiesPlayerScreen.State`
- Create: `iphone/MakeReady/UI2/Viewer/ViewerVideoHost.swift` — `AVPlayer` for the active page ±1
- Create: `iphone/MakeReady/UI2/Viewer/ViewerYouTubeHost.swift` — `WKWebView` limited to YouTube's IFrame player
- Modify: `UI2Shell.swift` — `.activityViewer` renders this container
- Test: `iphone/MakeReadyCaptureTests/ActivityViewerMapperTests.swift`, `ViewerYouTubeHostTests.swift`

**Interfaces:**
- Produces: `ActivityViewerMapper.state(payload:engine:viewport:playback:) -> ActivitiesPlayerScreen.State`; `ActivityViewerMapper.mountedPages(active: Int, count: Int) -> [Int]`; `ViewerYouTubeHost.allows(_ url: URL) -> Bool`
- Consumes: `ViewerEngine` (Task 26); `ActivityActions.loadVersion` (Task 22); `LessonVersionPayload`, `ActivityDocument.renderable` (Task 21); d2m's player load-failed state (Task 20)

**Behaviour:**
- loads `GET /api/lesson-versions/:id`, opens on the given `activityId`'s page; the page list is the activities plus the completion page (D22, D23)
- one `UIPanGestureRecognizer` and a `CADisplayLink` drive `ViewerEngine`; layer transforms render positions (D10)
- the active page and one neighbour each side are mounted (§iphone "Viewer")
- unknown kinds and malformed documents take a page and show `fallback` (D11)
- video: autoplay when active, pause when the midline is crossed away, position kept per page (01 §9); presenter row = the document's `presenter`, else the video's `uploaderName`, no Follow button (§Contract)
- YouTube: `WKWebView` navigation allowed only to `https://www.youtube.com/embed/…` and `https://www.youtube-nocookie.com/embed/…`; paused at the midline through the IFrame API (D24)
- rail: bottom right, indicator only, touches pass through; fades 1.5 s after settling on a playing video over 0.3 s, fades in over 0.1 s on movement (D12, 01 §8)
- action sheets open with Save disabled and a "Preview" label; `write` pages show a disabled field labelled "Preview"; no progress is written (D9, D25)
- the completion page shows the lesson title, "End of lesson" and Close; Close returns to the editor (D22, D23)
- a load failure shows the load-failed state, then pops (D33 item 4)

**Tests:**
- `testPagesAreActivitiesPlusTheEndPage` (D23)

```swift
func testPagesAreActivitiesPlusTheEndPage() {
    let s = ActivityViewerMapper.state(payload: .fixture(kinds: ["text", "video", "quiz"]), engine: .fixture(pages: 4), viewport: 956, playback: .idle)
    XCTAssertEqual(s.pageKinds, ["canvas", "video", "fallback", "end"])
}
```

- `testOnlyActiveAndNeighboursMount` (§iphone)

```swift
func testOnlyActiveAndNeighboursMount() {
    XCTAssertEqual(ActivityViewerMapper.mountedPages(active: 3, count: 8), [2, 3, 4])
    XCTAssertEqual(ActivityViewerMapper.mountedPages(active: 0, count: 8), [0, 1])
}
```

- `testPresenterFallsBackToUploader` (§Contract)

```swift
func testPresenterFallsBackToUploader() {
    let s = ActivityViewerMapper.state(payload: .fixtureVideo(presenter: nil, uploaderName: "Ana Ruiz"), engine: .fixture(pages: 2), viewport: 956, playback: .idle)
    XCTAssertEqual(s.pagePresenterNames.first, "Ana Ruiz")
}
```

- `testWriteAndActionSheetArePreviewOnly` (D9, D25)

```swift
func testWriteAndActionSheetArePreviewOnly() {
    let s = ActivityViewerMapper.state(payload: .fixture(kinds: ["write"]), engine: .fixture(pages: 2), viewport: 956, playback: .idle)
    XCTAssertEqual(s.pagePlaceholders.first, "Preview")
}
```

- `testYouTubeHostAllowsOnlyTheEmbedPlayer` (D24)

```swift
func testYouTubeHostAllowsOnlyTheEmbedPlayer() {
    XCTAssertTrue(ViewerYouTubeHost.allows(URL(string: "https://www.youtube.com/embed/abc?enablejsapi=1")!))
    XCTAssertFalse(ViewerYouTubeHost.allows(URL(string: "https://www.youtube.com/watch?v=abc")!))
    XCTAssertFalse(ViewerYouTubeHost.allows(URL(string: "https://example.com/embed/abc")!))
}
```

(Use the page-kind and field strings `ActivitiesPlayerScreen.State` actually uses — read `ActivitiesPlayerScreen.swift:34-200` — and adjust the expected values to them, keeping each test's meaning.)

- [ ] **Step 1: Write the listed tests**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>`
- [ ] **Step 3: Implement the mapper, the two hosts and the container to the Behaviour; route the shell case**
- [ ] **Step 4: Run `/transition-review` on the diff, the same verifier request and `cd iphone && swiftlint`, watch them pass**
- [ ] **Step 5: Commit** — `feat(text-activity): full-screen lesson viewer on the engine, with video and YouTube`
