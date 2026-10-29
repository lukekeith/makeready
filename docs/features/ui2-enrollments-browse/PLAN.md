# ui2-enrollments-browse — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders see every enrollment in their orgs on the UI 2.0 Enrollments section and an enrollment detail page, and an enrollment checklist that has a group and a program becomes a saved, autosaved, resumable, discardable server draft.

**Architecture:** Server first: a new `EnrollmentDraft` table (schema YAML → Atlas) with a scoped CRUD router, `POST /api/enrollments` deleting the pair's drafts, and a new `enrollment-directory.service.ts` that assembles the org-wide feed and the per-enrollment home read with raw-SQL aggregates. Then iPhone: wire types + mappers, memory-only AppState stores and Actions, the two new containers in the shell, and the checklist/group-page draft wiring against the four d2m screen inputs (D14).

**Tech Stack:** server — Express, Prisma (schema YAML → Atlas), zod, vitest + supertest, fixture layers. iphone — SwiftUI, @Observable AppState + Actions, d2m-built screens under `iphone/MakeReadyUI/`, XCTest in `MakeReadyCaptureTests`.

**Spec:** docs/features/ui2-enrollments-browse/SPEC.md (code map: the workspace's `audit-digest.md`)

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-enrollments-browse): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–3 | the `enrollment_drafts` table exists; drafts are created, listed, read, patched and deleted in scope; enrolling deletes the pair's drafts | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` · `docker restart makeready-server` |
| 2 | server | 4–6 | the feed and the enrollment home read match §Contract; fixtures seed the walk — contract FREEZES | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `docker restart makeready-server` |
| 3 | iphone | 7–9 | the phone decodes drafts, the feed and the home read; AppState stores + Actions; the shell routes the Enrollments section and `.enrollmentHome` | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 10–11 | the Enrollments list and the enrollment detail run on live data | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 12–15 | the checklist saves, autosaves, resumes and discards drafts; the group page lists them; legacy surfaces proven repointed | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: `EnrollmentDraft` table — schema YAML, Atlas migration, Prisma client, and the branch's test database
App: server
Phase: 1
Recipe: `/api` · REFERENCE §Schema & API changes (SPEC §Schema & API changes, SC1 + Data plan)

**Files:**
- Modify: `server/schema/schema.yaml:129-132` (User — add `enrollmentDrafts` after `enrollments`), `server/schema/schema.yaml:189-192` (User — add `updatedEnrollmentDrafts` after `updatedEnrollments`), `server/schema/schema.yaml:371-373` (Group — add `enrollmentDrafts` after `enrollments`), `server/schema/schema.yaml:2078-2080` (StudyProgram — add `enrollmentDrafts` after `enrollments`), `server/schema/schema.yaml:2464` (new `EnrollmentDraft` model directly after Enrollment's `indexes:` block, before the "Enrollment Sync Runs" banner)
- Modify (generated, never hand-edited): `server/prisma/schema.prisma`
- Create (generated): `server/atlas/migrations/<timestamp>_enrollment_drafts.sql`, and `server/atlas/migrations/atlas.sum` is updated by Atlas
- Test: `server/test/enrollment-drafts-migration.test.ts`

**Interfaces:**
- Consumes: the existing `EnrollmentSyncMode` (`OFF|AUTO|APPROVAL`) and `LessonAccess` (`ONE_AT_A_TIME|ALL_AT_ONCE`) enums.
- Produces: Prisma model `EnrollmentDraft` (delegate `prisma.enrollmentDraft`) with scalar fields `id, groupId, studyProgramId, startDate: string|null, enabledDays: Json|null, overriddenDates: Json|null, scheduleDates: Json|null, smsTime: string|null, timezone: string|null, syncMode: EnrollmentSyncMode|null, lessonAccess: LessonAccess|null, createdById: string|null, updatedById: string|null, createdAt: Date, updatedAt: Date`; relations `group`, `studyProgram`, `createdBy` (`EnrollmentDraftCreator`), `updatedBy` (`EnrollmentDraftUpdater`); compound unique accessor `groupId_studyProgramId`; inverse relations `Group.enrollmentDrafts`, `StudyProgram.enrollmentDrafts`, `User.enrollmentDrafts`, `User.updatedEnrollmentDrafts`. Table `enrollment_drafts`.
- Produces: the branch test database **`postgresql://postgres:postgres@localhost:5434/makeready_ueb_test`** (migrations from this branch + seeds) that every later server task runs its real-DB tests against.

Environment facts for this task (a fleet worktree): there is **no `server/.env`** here (in the main checkout it is a 1Password pipe). Never run `npm run schema:diff`, `npm run migrate:*`, or anything through `dotenv`. `npx prisma generate` on the host is safe here only because no `.env` exists — check that first. The `makeready-server` container serves the MAIN checkout, so `docker exec makeready-server npx prisma generate` would regenerate the wrong client — do not use it from this worktree. `npm run test:run` with no `DATABASE_URL` fails on every real-DB suite (pre-existing); always pass the test database URL as below.

Build-time risk (this task): the live `makeready_dev` (and prod) tables carry Prisma-era `text` ids, while Atlas generates `uuid` FK columns; applying this migration there may fail with "incompatible types: uuid and text". Applying to `makeready_dev` is NOT part of this task — if you see that error anywhere, STOP and report it; never hand-edit the migration.

- [ ] **Step 1: Write the failing migration test** — `server/test/enrollment-drafts-migration.test.ts`

```ts
/**
 * ui2-enrollments-browse SC1 (D2, D6, D19): enrollment_drafts — group + program required (CASCADE),
 * every checklist field nullable, creator/updater SET NULL, one draft per (group, program).
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('CREATE TABLE "enrollment_drafts"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 enrollment_drafts migration', () => {
  it('creates the table with the two required uuid keys', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/"groupId" uuid NOT NULL/)
    expect(sql).toMatch(/"studyProgramId" uuid NOT NULL/)
  })

  it('makes every checklist field nullable with the SC1 types', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/"startDate" character varying NULL/)
    expect(sql).toMatch(/"enabledDays" jsonb NULL/)
    expect(sql).toMatch(/"overriddenDates" jsonb NULL/)
    expect(sql).toMatch(/"scheduleDates" jsonb NULL/)
    expect(sql).toMatch(/"smsTime" character varying NULL/)
    expect(sql).toMatch(/"timezone" character varying NULL/)
    expect(sql).toMatch(/"syncMode" "EnrollmentSyncMode" NULL/)
    expect(sql).toMatch(/"lessonAccess" "LessonAccess" NULL/)
  })

  it('cascades from group and program and nulls the creator/updater on user delete', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/FOREIGN KEY \("groupId"\) REFERENCES (?:"public"\.)?"groups" \("id"\) ON UPDATE NO ACTION ON DELETE CASCADE/)
    expect(sql).toMatch(/FOREIGN KEY \("studyProgramId"\) REFERENCES (?:"public"\.)?"study_programs" \("id"\) ON UPDATE NO ACTION ON DELETE CASCADE/)
    expect(sql).toMatch(/FOREIGN KEY \("createdById"\) REFERENCES (?:"public"\.)?"users" \("id"\) ON UPDATE NO ACTION ON DELETE SET NULL/)
    expect(sql).toMatch(/FOREIGN KEY \("updatedById"\) REFERENCES (?:"public"\.)?"users" \("id"\) ON UPDATE NO ACTION ON DELETE SET NULL/)
  })

  it('holds one draft per (group, program) and adds no separate groupId index', () => {
    const { sql } = findMigration()
    expect(sql).toMatch(/UNIQUE \("groupId", "studyProgramId"\)/)
    expect(sql).not.toMatch(/CREATE INDEX "[^"]*" ON (?:"public"\.)?"enrollment_drafts" \("groupId"\)/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma model', () => {
    expect(Object.keys(Prisma.EnrollmentDraftScalarFieldEnum)).toEqual([
      'id', 'groupId', 'studyProgramId', 'startDate', 'enabledDays', 'overriddenDates', 'scheduleDates',
      'smsTime', 'timezone', 'syncMode', 'lessonAccess', 'createdById', 'updatedById', 'createdAt', 'updatedAt',
    ])
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/enrollment-drafts-migration.test.ts` → FAIL, `expected [] to have a length of 1` (no migration yet) and `Prisma.EnrollmentDraftScalarFieldEnum` undefined

- [ ] **Step 3: Add the model and inverse relations to `server/schema/schema.yaml`**

After the User `enrollments` relation (`:129-132`):

```yaml
      enrollmentDrafts:
        type: one_to_many
        target: EnrollmentDraft
        name: EnrollmentDraftCreator
```

After the User `updatedEnrollments` relation (`:189-192`):

```yaml
      updatedEnrollmentDrafts:
        type: one_to_many
        target: EnrollmentDraft
        name: EnrollmentDraftUpdater
```

After the Group `enrollments` relation (`:371-373`) AND after the StudyProgram `enrollments` relation (`:2078-2080`) — the same three lines in each:

```yaml
      enrollmentDrafts:
        type: one_to_many
        target: EnrollmentDraft
```

After line `:2464` (the last line of Enrollment's `indexes:`), a blank line, then:

```yaml
  # ---------------------------------------------------------------------------
  # Enrollment drafts (ui2-enrollments-browse SC1 — D2, D6, D19): a 2.0 enroll checklist that holds a
  # group and a study program, saved before Enroll so a leader or co-leader can resume it. One per
  # (group, program). POST /api/enrollments deletes the pair's drafts (D11, D24). Never expires.
  # ---------------------------------------------------------------------------
  EnrollmentDraft:
    table_name: enrollment_drafts
    fields:
      id:
        type: uuid
        primary: true
        default: uuid()
      groupId:
        type: string
      studyProgramId:
        type: string
      startDate:
        type: string
        nullable: true
        description: "yyyy-MM-dd — the checklist's first lesson date"
      enabledDays:
        type: json
        nullable: true
        description: "Weekday names as sent, e.g. ['Sun','Mon']"
      overriddenDates:
        type: json
        nullable: true
        description: "yyyy-MM-dd[] the leader toggled against the weekday walk"
      scheduleDates:
        type: json
        nullable: true
        description: "yyyy-MM-dd[] strictly ascending — the checklist's lesson dates"
      smsTime:
        type: string
        nullable: true
        description: "HH:mm invite time"
      timezone:
        type: string
        nullable: true
        description: "IANA zone, e.g. 'America/Chicago'"
      syncMode:
        type: enum
        enum: EnrollmentSyncMode
        nullable: true
      lessonAccess:
        type: enum
        enum: LessonAccess
        nullable: true
      createdById:
        type: string
        nullable: true
      updatedById:
        type: string
        nullable: true
      createdAt:
        type: datetime
        default: now()
      updatedAt:
        type: datetime
        updatedAt: true
    relations:
      group:
        type: many_to_one
        target: Group
        fields: [groupId]
        references: [id]
        onDelete: Cascade
      studyProgram:
        type: many_to_one
        target: StudyProgram
        fields: [studyProgramId]
        references: [id]
        onDelete: Cascade
      createdBy:
        type: many_to_one
        target: User
        fields: [createdById]
        references: [id]
        name: EnrollmentDraftCreator
        onDelete: SetNull
        nullable: true
      updatedBy:
        type: many_to_one
        target: User
        fields: [updatedById]
        references: [id]
        name: EnrollmentDraftUpdater
        onDelete: SetNull
        nullable: true
    unique:
      - fields: [groupId, studyProgramId]
```

- [ ] **Step 4: Validate, generate, diff** — run each from the worktree root:

```bash
cd server && npm run schema:validate && npm run schema:generate
cd server/atlas && ../scripts/atlas.sh migrate diff enrollment_drafts --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
test ! -e server/.env && (cd server && npx prisma generate)
```

The diff replays the directory into `atlas_dev_template` on the shared postgres (:5434); if it is down, `docker start makeready-postgres` first. Open the new `server/atlas/migrations/*_enrollment_drafts.sql`: it must hold only `CREATE TABLE "enrollment_drafts"` (+ its constraints and `COMMENT ON COLUMN` lines). Anything else means the YAML is out of sync with an earlier migration — STOP and report. If `server/.env` exists, STOP (the `test !` guard) — never let prisma read the 1Password pipe.

- [ ] **Step 5: Build the branch test database** (used by every later server task; re-run these four lines whenever a later task finds it missing):

```bash
docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_ueb_test
docker exec makeready-postgres createdb -U postgres makeready_ueb_test
cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_ueb_test
cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npm run db:seed
```

Then confirm: `docker exec makeready-postgres psql -U postgres -d makeready_ueb_test -tAc "select count(*) from enrollment_drafts"` → `0`.

- [ ] **Step 6: Run the test and watch it pass** — `cd server && npx vitest run test/enrollment-drafts-migration.test.ts` → PASS (6 tests); then `cd server && npx tsc --noEmit` → no errors

- [ ] **Step 7: Commit** — `git add server/schema/schema.yaml server/prisma/schema.prisma server/atlas/migrations server/test/enrollment-drafts-migration.test.ts && git commit -m "feat(ui2-enrollments-browse): enrollment_drafts table (SC1)"`

### Task 2: Draft CRUD — `enrollment-draft.service.ts` + thin `/api/enrollment-drafts` router
App: server
Phase: 1
Recipe: `/api`

**Files:**
- Create: `server/src/services/enrollment-draft.service.ts`
- Create: `server/src/routes/enrollment-drafts.ts`
- Modify: `server/src/index.ts:33` (import) and `server/src/index.ts:462` (mount, directly after `app.use('/api', enrollmentsRoutes)`)
- Test: `server/test/enrollment-drafts.test.ts`

**Interfaces:**
- Consumes (Task 1): `prisma.enrollmentDraft`, unique accessor `groupId_studyProgramId`. Existing: `groupManageFilter(userId): Promise<Prisma.GroupWhereInput>` and `findManageableGroup(userId, groupId): Promise<{id, organizationId} | null>` from `src/services/permission.ts:335,348`; `programReadFilter(userId): Promise<Prisma.StudyProgramWhereInput>` from `src/services/study-program.service.ts:129`; `isValidTimezone(tz): boolean` from `src/utils/timezone.ts:6`; `prisma`, `Prisma` from `src/lib/prisma.ts`.
- Produces (exported from `src/services/enrollment-draft.service.ts`; Tasks 3, 4 and 6 import these names):
  - `DRAFT_SELECT` (a `Prisma.EnrollmentDraftSelect` object), `type DraftRow = Prisma.EnrollmentDraftGetPayload<{ select: typeof DRAFT_SELECT }>`
  - `interface DraftWire { id: string; groupId: string; studyProgramId: string; startDate: string | null; enabledDays: string[] | null; overriddenDates: string[] | null; scheduleDates: string[] | null; smsTime: string | null; timezone: string | null; syncMode: EnrollmentSyncMode | null; lessonAccess: LessonAccess | null; createdBy: { id: string; name: string } | null; createdAt: string; updatedAt: string }` — §Contract **Draft**
  - `toDraftWire(row: DraftRow): DraftWire`
  - `draftCreateSchema`, `draftPatchSchema` (zod, `.strict()`), `type DraftCreateInput`, `type DraftPatchInput`
  - `class DraftError extends Error { status: 404 | 409; draftId?: string }`
  - `createDraft(userId: string, input: DraftCreateInput): Promise<DraftWire>`
  - `listGroupDrafts(userId: string, groupId: string): Promise<DraftWire[]>`
  - `getDraft(userId: string, id: string): Promise<DraftWire>`
  - `updateDraft(userId: string, id: string, patch: DraftPatchInput): Promise<DraftWire>`
  - `deleteDraft(userId: string, id: string): Promise<void>`
  - `deleteDraftsForPair(groupId: string, studyProgramId: string): Promise<number>`
- Produces (wire, §Contract): `POST /api/enrollment-drafts` → 201 `{success, draft}` · 400 · 404 · 409 `{success:false, error:"draft_exists", draftId}`; `GET /api/enrollment-drafts?groupId=` → `{success, drafts}` newest `updatedAt` first · 400 · 404; `GET /api/enrollment-drafts/:id` → `{success, draft}` · 404; `PATCH /api/enrollment-drafts/:id` → `{success, draft}` · 400 · 404 · 409; `DELETE /api/enrollment-drafts/:id` → `{success:true}` · 404.

Every test command in this task runs against the branch test database built in Task 1 (`makeready_ueb_test`); if `docker exec makeready-postgres psql -U postgres -d makeready_ueb_test -tAc "select 1 from enrollment_drafts limit 1"` errors, rebuild it with Task 1 Step 5's four commands (createdb + `atlas migrate apply --var database_url=…/makeready_ueb_test` + `npm run db:seed` with that DATABASE_URL).

- [ ] **Step 1: Write the failing request tests** — `server/test/enrollment-drafts.test.ts`

```ts
/**
 * ui2-enrollments-browse SC2 (D3–D6, D10, D19): /api/enrollment-drafts — scope through the draft's
 * group (groupManageFilter), program read scope on create/move, 409 draft_exists, strict bodies,
 * absent vs null. Real DB + API-key auth, as enrollment-create.test.ts.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('/api/enrollment-drafts (ui2-enrollments-browse SC2)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let coLeader: TestUserWithToken
  let stranger: TestUserWithToken
  let orgId: string
  let foreignOrgId: string
  let groupId: string
  let inactiveGroupId: string
  let foreignGroupId: string
  let inactiveProgramId: string
  let foreignProgramId: string
  const P: string[] = [] // eight active programs in the owner's org, one per test pair

  const as = (u: TestUserWithToken) => ({
    post: (b: Record<string, unknown>) => request(app).post('/api/enrollment-drafts').set('Authorization', bearer(u.token)).send(b),
    list: (gid?: string) =>
      request(app).get('/api/enrollment-drafts').query(gid ? { groupId: gid } : {}).set('Authorization', bearer(u.token)),
    get: (id: string) => request(app).get(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)),
    patch: (id: string, b: Record<string, unknown>) =>
      request(app).patch(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)).send(b),
    del: (id: string) => request(app).delete(`/api/enrollment-drafts/${id}`).set('Authorization', bearer(u.token)),
  })

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ed-owner-${stamp}@cl.test`, name: 'ED Owner' })
    coLeader = await createUserWithApiKey({ email: `ed-co-${stamp}@cl.test`, name: 'ED CoLeader' })
    stranger = await createUserWithApiKey({ email: `ed-stranger-${stamp}@cl.test`, name: 'ED Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `ED Org ${stamp}`, ownerId: owner.userId } })).id
    foreignOrgId = (await prisma.organization.create({ data: { name: `ED Foreign ${stamp}`, ownerId: stranger.userId } })).id
    const role = await prisma.role.create({ data: { name: `ED Leader ${stamp}`, organizationId: orgId, isSystem: false } })
    await prisma.userRole.create({ data: { userId: coLeader.userId, roleId: role.id, organizationId: orgId } })
    const mkGroup = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.group.create({ data: { name, code: `ed-${name}-${stamp}`, creatorId: creator, organizationId: org, isActive } })).id
    groupId = await mkGroup(orgId, owner.userId, 'g')
    inactiveGroupId = await mkGroup(orgId, owner.userId, 'gi', false)
    foreignGroupId = await mkGroup(foreignOrgId, stranger.userId, 'gf')
    const mkProgram = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.studyProgram.create({ data: { name, days: 3, creatorId: creator, organizationId: org, isActive } })).id
    for (let i = 0; i < 8; i++) P.push(await mkProgram(orgId, owner.userId, `ED P${i} ${stamp}`))
    inactiveProgramId = await mkProgram(orgId, owner.userId, `ED Inactive ${stamp}`, false)
    foreignProgramId = await mkProgram(foreignOrgId, stranger.userId, `ED Foreign ${stamp}`)
  })

  afterAll(async () => {
    const orgs = [orgId, foreignOrgId]
    await prisma.enrollmentDraft.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgId } })
    await prisma.role.deleteMany({ where: { organizationId: orgId } })
    const users = [owner.userId, coLeader.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('POST creates a draft from the two ids alone: 201, every other field null, createdBy set (D3)', async () => {
    const res = await as(owner).post({ groupId, studyProgramId: P[0] })
    expect(res.status).toBe(201)
    expect(res.body.success).toBe(true)
    expect(res.body.draft).toMatchObject({
      groupId, studyProgramId: P[0], startDate: null, enabledDays: null, overriddenDates: null, scheduleDates: null,
      smsTime: null, timezone: null, syncMode: null, lessonAccess: null, createdBy: { id: owner.userId, name: 'ED Owner' },
    })
    expect(Object.keys(res.body.draft).sort()).toEqual(
      ['createdAt', 'createdBy', 'enabledDays', 'groupId', 'id', 'lessonAccess', 'overriddenDates', 'scheduleDates',
        'smsTime', 'startDate', 'studyProgramId', 'syncMode', 'timezone', 'updatedAt'].sort(),
    )
  })

  it('POST on a pair that already has a draft → 409 draft_exists with that draftId (D6)', async () => {
    const existing = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[0] } } })
    const res = await as(owner).post({ groupId, studyProgramId: P[0] })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'draft_exists', draftId: existing.id })
  })

  it('two concurrent POSTs on one pair → one 201, one 409', async () => {
    const [a, b] = await Promise.all([as(owner).post({ groupId, studyProgramId: P[1] }), as(owner).post({ groupId, studyProgramId: P[1] })])
    expect([a.status, b.status].sort()).toEqual([201, 409])
  })

  it('POST 400s: a missing id, an unknown field (.strict), unsorted scheduleDates, an invalid timezone', async () => {
    expect((await as(owner).post({ groupId })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], color: 'red' })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], scheduleDates: ['2030-01-02', '2030-01-01'] })).status).toBe(400)
    expect((await as(owner).post({ groupId, studyProgramId: P[2], timezone: 'Mars/Olympus' })).status).toBe(400)
    expect(await prisma.enrollmentDraft.count({ where: { groupId, studyProgramId: P[2] } })).toBe(0)
  })

  it('POST 404s an inactive or out-of-scope group, and an inactive or unreadable program (D5, D19)', async () => {
    expect((await as(owner).post({ groupId: inactiveGroupId, studyProgramId: P[2] })).status).toBe(404)
    expect((await as(owner).post({ groupId: foreignGroupId, studyProgramId: P[2] })).status).toBe(404)
    expect((await as(owner).post({ groupId, studyProgramId: inactiveProgramId })).status).toBe(404)
    expect((await as(owner).post({ groupId, studyProgramId: foreignProgramId })).status).toBe(404)
  })

  it('PATCH writes every field, then a null clears one and absent keys keep theirs', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[2] })).body.draft.id
    const full = {
      startDate: '2030-03-02', enabledDays: ['Mon', 'Wed'], overriddenDates: ['2030-03-04'],
      scheduleDates: ['2030-03-02', '2030-03-03', '2030-03-05'], smsTime: '07:30', timezone: 'America/Chicago',
      syncMode: 'AUTO', lessonAccess: 'ONE_AT_A_TIME',
    }
    const set = await as(owner).patch(id, full)
    expect(set.status).toBe(200)
    expect(set.body.draft).toMatchObject(full)
    const cleared = await as(owner).patch(id, { smsTime: null, scheduleDates: null })
    expect(cleared.status).toBe(200)
    expect(cleared.body.draft).toMatchObject({ ...full, smsTime: null, scheduleDates: null })
    expect((await as(owner).patch(id, { syncMode: 'APPROVAL' })).status).toBe(400)
    expect((await as(owner).patch(id, { nope: 1 })).status).toBe(400)
  })

  it('PATCH moving onto a pair another draft holds → 409 with that draftId, nothing changed (D6)', async () => {
    const holder = (await as(owner).post({ groupId, studyProgramId: P[3] })).body.draft.id
    const mover = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[2] } } })).id
    const res = await as(owner).patch(mover, { studyProgramId: P[3], smsTime: '09:00' })
    expect(res.status).toBe(409)
    expect(res.body).toEqual({ success: false, error: 'draft_exists', draftId: holder })
    const after = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: mover } })
    expect(after.studyProgramId).toBe(P[2])
    expect(after.smsTime).toBeNull()
  })

  it('PATCH re-scopes a moved group or program: out of scope / inactive → 404, nothing changed', async () => {
    const id = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[2] } } })).id
    expect((await as(owner).patch(id, { groupId: foreignGroupId })).status).toBe(404)
    expect((await as(owner).patch(id, { groupId: inactiveGroupId })).status).toBe(404)
    expect((await as(owner).patch(id, { studyProgramId: foreignProgramId })).status).toBe(404)
    expect((await as(owner).patch(id, { studyProgramId: inactiveProgramId, smsTime: '06:00' })).status).toBe(404)
    const after = await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id } })
    expect([after.groupId, after.studyProgramId, after.smsTime]).toEqual([groupId, P[2], null])
  })

  it('GET reads a draft in scope; a stranger gets 404 (D5)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[4] })).body.draft.id
    const res = await as(owner).get(id)
    expect(res.status).toBe(200)
    expect(res.body.draft.id).toBe(id)
    expect((await as(stranger).get(id)).status).toBe(404)
    expect((await as(owner).get('not-a-uuid')).status).toBe(404)
    expect((await as(owner).get('00000000-0000-4000-8000-000000000000')).status).toBe(404)
  })

  it('a co-leader (role-held org) can read, patch and delete a draft another leader started (D5)', async () => {
    const id = (await prisma.enrollmentDraft.findUniqueOrThrow({ where: { groupId_studyProgramId: { groupId, studyProgramId: P[4] } } })).id
    expect((await as(coLeader).get(id)).status).toBe(200)
    const patched = await as(coLeader).patch(id, { lessonAccess: 'ALL_AT_ONCE' })
    expect(patched.status).toBe(200)
    expect(patched.body.draft.createdBy).toEqual({ id: owner.userId, name: 'ED Owner' })
    expect((await prisma.enrollmentDraft.findUniqueOrThrow({ where: { id } })).updatedById).toBe(coLeader.userId)
    expect((await as(coLeader).del(id)).body).toEqual({ success: true })
    expect((await as(owner).get(id)).status).toBe(404)
  })

  it('DELETE removes the draft; a second DELETE and a stranger DELETE are 404 (D10)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[5] })).body.draft.id
    expect((await as(stranger).del(id)).status).toBe(404)
    const res = await as(owner).del(id)
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true })
    expect((await as(owner).del(id)).status).toBe(404)
  })

  it('a draft whose program went inactive is unlisted and 404s on GET and PATCH, and the row stays (D19)', async () => {
    const id = (await as(owner).post({ groupId, studyProgramId: P[6] })).body.draft.id
    await prisma.studyProgram.update({ where: { id: P[6] }, data: { isActive: false } })
    expect((await as(owner).get(id)).status).toBe(404)
    expect((await as(owner).patch(id, { smsTime: '08:00' })).status).toBe(404)
    expect((await as(owner).list(groupId)).body.drafts.map((d: { id: string }) => d.id)).not.toContain(id)
    expect(await prisma.enrollmentDraft.count({ where: { id } })).toBe(1)
  })

  it('createdBy is null once its user is deleted', async () => {
    const temp = await prisma.user.create({ data: { googleId: `gid-ed-temp-${stamp}`, email: `ed-temp-${stamp}@cl.test`, name: 'Temp' } })
    const draft = await prisma.enrollmentDraft.create({ data: { groupId, studyProgramId: P[7], createdById: temp.id } })
    await prisma.user.delete({ where: { id: temp.id } })
    const res = await as(owner).get(draft.id)
    expect(res.status).toBe(200)
    expect(res.body.draft.createdBy).toBeNull()
  })

  it('GET ?groupId lists the group\'s drafts newest updatedAt first; 400 without groupId; 404 out of scope', async () => {
    const res = await as(owner).list(groupId)
    expect(res.status).toBe(200)
    const times = res.body.drafts.map((d: { updatedAt: string }) => Date.parse(d.updatedAt))
    expect(times.length).toBeGreaterThanOrEqual(3)
    expect([...times].sort((a, b) => b - a)).toEqual(times)
    expect((await as(owner).list()).status).toBe(400)
    expect((await as(stranger).list(groupId)).status).toBe(404)
    expect((await as(owner).list(inactiveGroupId)).status).toBe(404)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-drafts.test.ts` → FAIL, every request 404 (route not mounted)

- [ ] **Step 3: Write the service** — `server/src/services/enrollment-draft.service.ts`

```ts
/**
 * Enrollment drafts (ui2-enrollments-browse SC2 — D2–D6, D10, D19, D24): a 2.0 enroll checklist saved
 * once it holds a group and a program. Scope is always the draft's GROUP (groupManageFilter, active);
 * the program must be active, and readable (programReadFilter) when a draft is created on it or moved
 * to it. One draft per (group, program): a unique violation is a 409 carrying the holder's id.
 */
import { z } from 'zod'
import type { EnrollmentSyncMode, LessonAccess } from '../generated/prisma/index.js'
import { Prisma, prisma } from '../lib/prisma.js'
import { isValidTimezone } from '../utils/timezone.js'
import { findManageableGroup, groupManageFilter } from './permission.js'
import { programReadFilter } from './study-program.service.js'

const ymd = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'expected yyyy-MM-dd')
const weekday = z.enum(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'])

// Every checklist field: absent = leave as is, null = clear (written only when the key is present).
const draftFields = {
  startDate: ymd.nullable().optional(),
  enabledDays: z.array(weekday).nullable().optional(),
  overriddenDates: z.array(ymd).nullable().optional(),
  // Strictly ascending; the count and not-before-today are Enroll's checks, never the draft's.
  scheduleDates: z
    .array(ymd)
    .refine((d) => d.every((v, i) => i === 0 || d[i - 1] < v), 'scheduleDates must be strictly ascending')
    .nullable()
    .optional(),
  smsTime: z.string().regex(/^\d{2}:\d{2}$/, 'expected HH:mm').nullable().optional(),
  timezone: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).nullable().optional(),
  syncMode: z.enum(['AUTO', 'OFF']).nullable().optional(),
  lessonAccess: z.enum(['ONE_AT_A_TIME', 'ALL_AT_ONCE']).nullable().optional(),
}

export const draftCreateSchema = z
  .object({ groupId: z.string().uuid(), studyProgramId: z.string().uuid(), ...draftFields })
  .strict()
export const draftPatchSchema = z
  .object({ groupId: z.string().uuid().optional(), studyProgramId: z.string().uuid().optional(), ...draftFields })
  .strict()
export type DraftCreateInput = z.infer<typeof draftCreateSchema>
export type DraftPatchInput = z.infer<typeof draftPatchSchema>

const DRAFT_FIELD_KEYS = [
  'startDate', 'enabledDays', 'overriddenDates', 'scheduleDates', 'smsTime', 'timezone', 'syncMode', 'lessonAccess',
] as const
type DraftFieldKey = (typeof DRAFT_FIELD_KEYS)[number]
const JSON_FIELD_KEYS: ReadonlySet<DraftFieldKey> = new Set(['enabledDays', 'overriddenDates', 'scheduleDates'])

/** Only the keys the body carried; a JSON column's null is Prisma.DbNull (SQL NULL). */
function presentFields(input: Partial<Record<DraftFieldKey, unknown>>): Record<string, unknown> {
  const data: Record<string, unknown> = {}
  for (const key of DRAFT_FIELD_KEYS) {
    const value = input[key]
    if (value === undefined) continue
    data[key] = value === null && JSON_FIELD_KEYS.has(key) ? Prisma.DbNull : value
  }
  return data
}

export const DRAFT_SELECT = {
  id: true,
  groupId: true,
  studyProgramId: true,
  startDate: true,
  enabledDays: true,
  overriddenDates: true,
  scheduleDates: true,
  smsTime: true,
  timezone: true,
  syncMode: true,
  lessonAccess: true,
  createdAt: true,
  updatedAt: true,
  createdBy: { select: { id: true, name: true } },
} satisfies Prisma.EnrollmentDraftSelect
export type DraftRow = Prisma.EnrollmentDraftGetPayload<{ select: typeof DRAFT_SELECT }>

/** §Contract Draft. */
export interface DraftWire {
  id: string
  groupId: string
  studyProgramId: string
  startDate: string | null
  enabledDays: string[] | null
  overriddenDates: string[] | null
  scheduleDates: string[] | null
  smsTime: string | null
  timezone: string | null
  syncMode: EnrollmentSyncMode | null
  lessonAccess: LessonAccess | null
  createdBy: { id: string; name: string } | null
  createdAt: string
  updatedAt: string
}

const asStrings = (v: Prisma.JsonValue | null): string[] | null => (Array.isArray(v) ? (v as string[]) : null)

export function toDraftWire(row: DraftRow): DraftWire {
  return {
    id: row.id,
    groupId: row.groupId,
    studyProgramId: row.studyProgramId,
    startDate: row.startDate,
    enabledDays: asStrings(row.enabledDays),
    overriddenDates: asStrings(row.overriddenDates),
    scheduleDates: asStrings(row.scheduleDates),
    smsTime: row.smsTime,
    timezone: row.timezone,
    syncMode: row.syncMode,
    lessonAccess: row.lessonAccess,
    createdBy: row.createdBy ? { id: row.createdBy.id, name: row.createdBy.name } : null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  }
}

export class DraftError extends Error {
  constructor(
    readonly status: 404 | 409,
    message: string,
    readonly draftId?: string,
  ) {
    super(message)
    this.name = 'DraftError'
  }
}

const isUniqueViolation = (error: unknown): boolean =>
  typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 'P2002'

/** D5 + D19: the draft's group is manageable and active, its program active. */
async function draftScope(userId: string): Promise<Prisma.EnrollmentDraftWhereInput> {
  return { group: { isActive: true, ...(await groupManageFilter(userId)) }, studyProgram: { isActive: true } }
}

async function findReadableProgram(userId: string, id: string): Promise<{ id: string } | null> {
  return prisma.studyProgram.findFirst({ where: { id, isActive: true, ...(await programReadFilter(userId)) }, select: { id: true } })
}

/** D6: the pair is held — 409 with the holder's id (the caller already proved the pair's group in scope). */
async function conflictFor(groupId: string, studyProgramId: string, original: unknown): Promise<never> {
  const holder = await prisma.enrollmentDraft.findUnique({
    where: { groupId_studyProgramId: { groupId, studyProgramId } },
    select: { id: true },
  })
  if (holder) throw new DraftError(409, 'draft_exists', holder.id)
  throw original
}

export async function createDraft(userId: string, input: DraftCreateInput): Promise<DraftWire> {
  if (!(await findManageableGroup(userId, input.groupId))) throw new DraftError(404, 'Group not found')
  if (!(await findReadableProgram(userId, input.studyProgramId))) throw new DraftError(404, 'Study program not found')
  try {
    const row = await prisma.enrollmentDraft.create({
      data: {
        ...presentFields(input),
        groupId: input.groupId,
        studyProgramId: input.studyProgramId,
        createdById: userId,
        updatedById: userId,
      } as Prisma.EnrollmentDraftUncheckedCreateInput,
      select: DRAFT_SELECT,
    })
    return toDraftWire(row)
  } catch (error) {
    if (isUniqueViolation(error)) return conflictFor(input.groupId, input.studyProgramId, error)
    throw error
  }
}

export async function listGroupDrafts(userId: string, groupId: string): Promise<DraftWire[]> {
  if (!(await findManageableGroup(userId, groupId))) throw new DraftError(404, 'Group not found')
  const rows = await prisma.enrollmentDraft.findMany({
    where: { groupId, studyProgram: { isActive: true } },
    orderBy: [{ updatedAt: 'desc' }, { id: 'asc' }],
    select: DRAFT_SELECT,
  })
  return rows.map(toDraftWire)
}

async function findDraftInScope(userId: string, id: string) {
  return prisma.enrollmentDraft.findFirst({ where: { id, ...(await draftScope(userId)) }, select: DRAFT_SELECT })
}

export async function getDraft(userId: string, id: string): Promise<DraftWire> {
  const row = await findDraftInScope(userId, id)
  if (!row) throw new DraftError(404, 'Draft not found')
  return toDraftWire(row)
}

export async function updateDraft(userId: string, id: string, patch: DraftPatchInput): Promise<DraftWire> {
  const current = await findDraftInScope(userId, id)
  if (!current) throw new DraftError(404, 'Draft not found')
  const groupId = patch.groupId ?? current.groupId
  const studyProgramId = patch.studyProgramId ?? current.studyProgramId
  if (groupId !== current.groupId && !(await findManageableGroup(userId, groupId))) {
    throw new DraftError(404, 'Group not found')
  }
  if (studyProgramId !== current.studyProgramId && !(await findReadableProgram(userId, studyProgramId))) {
    throw new DraftError(404, 'Study program not found')
  }
  try {
    const row = await prisma.enrollmentDraft.update({
      where: { id },
      data: { ...presentFields(patch), groupId, studyProgramId, updatedById: userId } as Prisma.EnrollmentDraftUncheckedUpdateInput,
      select: DRAFT_SELECT,
    })
    return toDraftWire(row)
  } catch (error) {
    if (isUniqueViolation(error)) return conflictFor(groupId, studyProgramId, error)
    throw error
  }
}

export async function deleteDraft(userId: string, id: string): Promise<void> {
  const row = await findDraftInScope(userId, id)
  if (!row) throw new DraftError(404, 'Draft not found')
  await prisma.enrollmentDraft.delete({ where: { id } })
}

/** D11 + D24: enrolling a (group, program) promotes its draft — every draft of the pair goes. */
export async function deleteDraftsForPair(groupId: string, studyProgramId: string): Promise<number> {
  const { count } = await prisma.enrollmentDraft.deleteMany({ where: { groupId, studyProgramId } })
  return count
}
```

- [ ] **Step 4: Write the thin router** — `server/src/routes/enrollment-drafts.ts`

```ts
/**
 * /api/enrollment-drafts (ui2-enrollments-browse SC2). Thin: parse, call the service, map errors.
 * Logic and scope live in services/enrollment-draft.service.ts.
 */
import { Router, type Request, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import {
  DraftError,
  createDraft,
  deleteDraft,
  draftCreateSchema,
  draftPatchSchema,
  getDraft,
  listGroupDrafts,
  updateDraft,
} from '../services/enrollment-draft.service.js'

const router = Router()
const uuid = z.string().uuid()
const userIdOf = (req: Request): string => (req.user as { id: string }).id
const notFound = (res: Response) => res.status(404).json({ success: false, error: 'Draft not found' })

function fail(res: Response, error: unknown, label: string) {
  if (error instanceof z.ZodError) {
    return res.status(400).json({
      success: false,
      error: 'invalid_request',
      message: error.issues.map((i) => `${i.path.join('.') || 'body'}: ${i.message}`).join('; '),
    })
  }
  if (error instanceof DraftError) {
    if (error.status === 409) return res.status(409).json({ success: false, error: 'draft_exists', draftId: error.draftId })
    return res.status(error.status).json({ success: false, error: error.message })
  }
  console.error(`Error ${label}:`, error)
  return res.status(500).json({ success: false, error: 'Internal server error' })
}

router.post('/enrollment-drafts', requireAuth, async (req, res) => {
  try {
    const draft = await createDraft(userIdOf(req), draftCreateSchema.parse(req.body))
    res.status(201).json({ success: true, draft })
  } catch (error) {
    fail(res, error, 'creating enrollment draft')
  }
})

router.get('/enrollment-drafts', requireAuth, async (req, res) => {
  try {
    const drafts = await listGroupDrafts(userIdOf(req), uuid.parse(req.query.groupId))
    res.json({ success: true, drafts })
  } catch (error) {
    fail(res, error, 'listing enrollment drafts')
  }
})

router.get('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    res.json({ success: true, draft: await getDraft(userIdOf(req), req.params.id) })
  } catch (error) {
    fail(res, error, 'reading enrollment draft')
  }
})

router.patch('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    const draft = await updateDraft(userIdOf(req), req.params.id, draftPatchSchema.parse(req.body))
    res.json({ success: true, draft })
  } catch (error) {
    fail(res, error, 'updating enrollment draft')
  }
})

router.delete('/enrollment-drafts/:id', requireAuth, async (req, res) => {
  if (!uuid.safeParse(req.params.id).success) return notFound(res)
  try {
    await deleteDraft(userIdOf(req), req.params.id)
    res.json({ success: true })
  } catch (error) {
    fail(res, error, 'deleting enrollment draft')
  }
})

export default router
```

- [ ] **Step 5: Mount it** — in `server/src/index.ts`, after line 33 (`import enrollmentsRoutes from './routes/enrollments.js'`):

```ts
import enrollmentDraftsRoutes from './routes/enrollment-drafts.js'
```

and directly after line 462 (`app.use('/api', enrollmentsRoutes)`):

```ts

// Enrollment drafts (ui2-enrollments-browse SC2): saved 2.0 enroll checklists
app.use('/api', enrollmentDraftsRoutes)
```

- [ ] **Step 6: Run it and watch it pass** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-drafts.test.ts` → PASS (14 tests); `cd server && npx tsc --noEmit` → no errors; `docker restart makeready-server`

- [ ] **Step 7: Commit** — `git add server/src/services/enrollment-draft.service.ts server/src/routes/enrollment-drafts.ts server/src/index.ts server/test/enrollment-drafts.test.ts && git commit -m "feat(ui2-enrollments-browse): enrollment draft CRUD (SC2)"`

### Task 3: `POST /api/enrollments` takes `draftId` and deletes the pair's drafts after the welcome post
App: server
Phase: 1
Recipe: `/api` · tiny

**Files:**
- Modify: `server/src/routes/enrollments.ts:27` (import), `:155-156` (zod — add `draftId` after `lessonAccess`), `:442-443` (new try/catch after the step try/catch's closing `}` at :442, before the `// Step 5` comment at :444)
- Test: `server/test/enrollment-draft-promote.test.ts`

**Interfaces:**
- Consumes (Task 2): `deleteDraftsForPair(groupId: string, studyProgramId: string): Promise<number>` from `src/services/enrollment-draft.service.ts`.
- Produces (wire, §Contract): `POST /api/enrollments` accepts optional `draftId` (uuid); response unchanged; after a 200 no `EnrollmentDraft` remains for `(body.groupId, body.studyProgramId)` (D11 + D24), whether or not `draftId` was sent; a `draftId` of another pair or an unknown one deletes nothing else.

Build-time risk (F4): `POST /api/enrollments` is not transactional — the draft delete MUST sit after the step try/catch closes (`:442`), never inside it: that catch deletes the enrollment, so a failing draft delete inside it would destroy a good enrollment. The delete is non-fatal: log only, the 200 stands.
Build-time risk (F10): a double-submit still creates two enrollments (no idempotency, today's behaviour); with `draftId` the second POST deletes nothing and succeeds. Not fixed here — the iPhone checklist's `processing` phase blocks a second Enroll (Task 10's concern).

Every test command runs against the branch test database from Task 1 (`makeready_ueb_test`); rebuild it with Task 1 Step 5 if missing.

- [ ] **Step 1: Write the failing test** — `server/test/enrollment-draft-promote.test.ts`

```ts
/**
 * ui2-enrollments-browse SC3 (D11, D24, F4): enrolling a (group, program) deletes that pair's drafts in
 * its own try/catch after the welcome post — with or without draftId; a failing delete keeps the 200.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const draftDelete = vi.hoisted(() => ({ fail: false }))
vi.mock('../src/services/enrollment-draft.service.js', async (importOriginal) => {
  const real = await importOriginal<typeof import('../src/services/enrollment-draft.service.js')>()
  return {
    ...real,
    deleteDraftsForPair: async (groupId: string, studyProgramId: string) => {
      if (draftDelete.fail) throw new Error('simulated draft delete failure')
      return real.deleteDraftsForPair(groupId, studyProgramId)
    },
  }
})

import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

describe('POST /api/enrollments promotes the pair\'s draft (D11, D24)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let orgId: string
  let groupId: string
  let memberId: string
  const programs: string[] = []

  const enroll = (studyProgramId: string, extra: Record<string, unknown> = {}) =>
    request(app)
      .post('/api/enrollments')
      .set('Authorization', bearer(owner.token))
      .send({
        groupId, studyProgramId, startDate: new Date().toISOString(),
        enabledDays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'], timezone: 'America/Chicago', ...extra,
      })
  const draftFor = (studyProgramId: string) => prisma.enrollmentDraft.create({ data: { groupId, studyProgramId, createdById: owner.userId } })
  const draftsOf = (studyProgramId: string) => prisma.enrollmentDraft.count({ where: { groupId, studyProgramId } })

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `edp-owner-${stamp}@cl.test`, name: 'EDP Owner' })
    orgId = (await prisma.organization.create({ data: { name: `EDP Org ${stamp}`, ownerId: owner.userId } })).id
    groupId = (await prisma.group.create({ data: { name: `EDP Group ${stamp}`, code: `edp-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    memberId = (await prisma.member.create({ data: { firstName: 'Pat', lastName: 'Lee', phoneNumber: `+1557${String(stamp).slice(-7)}` } })).id
    await prisma.groupMember.create({ data: { groupId, memberId, isActive: true } })
    for (let i = 0; i < 5; i++) {
      const p = await prisma.studyProgram.create({
        data: { name: `EDP P${i} ${stamp}`, days: 2, creatorId: owner.userId, organizationId: orgId, isPublished: true, publishedAt: new Date() },
      })
      for (const day of [1, 2]) await prisma.lesson.create({ data: { studyProgramId: p.id, dayNumber: day } })
      programs.push(p.id)
    }
  })

  beforeEach(() => {
    draftDelete.fail = false
  })

  afterAll(async () => {
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.enrollmentDraft.deleteMany({ where: { groupId } })
    await prisma.groupMember.deleteMany({ where: { memberId } })
    await prisma.member.deleteMany({ where: { id: memberId } })
    await prisma.lesson.deleteMany({ where: { studyProgramId: { in: programs } } })
    await prisma.studyProgram.deleteMany({ where: { id: { in: programs } } })
    await prisma.post.deleteMany({ where: { groupId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId: owner.userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: owner.userId } })
  })

  it('with the draft\'s id: 200 and the draft is gone', async () => {
    const draft = await draftFor(programs[0])
    const res = await enroll(programs[0], { draftId: draft.id })
    expect(res.status).toBe(200)
    expect(await prisma.enrollmentDraft.count({ where: { id: draft.id } })).toBe(0)
  })

  it('without draftId (web LeaderApp, 1.0 iPhone): the pair\'s draft is still deleted (D24)', async () => {
    await draftFor(programs[1])
    const res = await enroll(programs[1])
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[1])).toBe(0)
  })

  it('a stale (unknown) draftId is ignored; the pair\'s draft is deleted', async () => {
    await draftFor(programs[2])
    const res = await enroll(programs[2], { draftId: '00000000-0000-4000-8000-000000000000' })
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[2])).toBe(0)
  })

  it('a draftId of another pair deletes nothing beyond this pair', async () => {
    const other = await draftFor(programs[4])
    await draftFor(programs[3])
    const res = await enroll(programs[3], { draftId: other.id })
    expect(res.status).toBe(200)
    expect(await draftsOf(programs[3])).toBe(0)
    expect(await prisma.enrollmentDraft.count({ where: { id: other.id } })).toBe(1)
  })

  it('a failing draft delete keeps the 200 and the enrollment (F4)', async () => {
    await prisma.enrollmentDraft.deleteMany({ where: { groupId, studyProgramId: programs[4] } })
    const draft = await draftFor(programs[4])
    draftDelete.fail = true
    const res = await enroll(programs[4], { draftId: draft.id })
    expect(res.status).toBe(200)
    expect(await prisma.enrollment.count({ where: { id: res.body.enrollment.id } })).toBe(1)
    expect(await prisma.enrollmentDraft.count({ where: { id: draft.id } })).toBe(1)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-draft-promote.test.ts` → FAIL, drafts still present after the 200 (count 1, expected 0)

- [ ] **Step 3: Write the minimal implementation** in `server/src/routes/enrollments.ts`

After line 27 (`import { programReadFilter } from '../services/study-program.service.js'`):

```ts
import { deleteDraftsForPair } from '../services/enrollment-draft.service.js'
```

In the POST zod object, after the `lessonAccess` line (`:156`):

```ts
      // ui2-enrollments-browse D11: the checklist's server draft; an unknown id is ignored (D24 deletes by pair).
      draftId: z.string().uuid().optional(),
```

Between the step try/catch's closing `}` (`:442`) and the `// Step 5: Fetch enrollment summary` comment (`:444`):

```ts

    // ui2-enrollments-browse D11 + D24: the enrollment and its welcome post exist, so the pair's drafts are
    // promoted — deleted whether or not draftId was sent. Its own try/catch, OUTSIDE the step try/catch
    // above (whose catch deletes the enrollment, F4): a failure here is logged and the 200 stands.
    try {
      await deleteDraftsForPair(body.groupId, body.studyProgramId)
    } catch (draftError) {
      console.error('   ⚠️ Could not delete the enrollment drafts for this group + program:', draftError)
    }
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-draft-promote.test.ts test/enrollment-create.test.ts test/enrollment-drafts.test.ts` → PASS (enrollment-create unchanged); `cd server && npx tsc --noEmit` → no errors; `docker restart makeready-server`

- [ ] **Step 5: Commit** — `git add server/src/routes/enrollments.ts server/test/enrollment-draft-promote.test.ts && git commit -m "feat(ui2-enrollments-browse): enrolling deletes the pair's drafts (SC3)"`

### Task 4: The org-wide feed — `enrollment-directory.service.ts` + `GET /api/enrollments-feed`
App: server
Phase: 2
Recipe: `/api`

**Files:**
- Create: `server/src/services/enrollment-directory.service.ts`
- Create: `server/src/routes/enrollment-directory.ts`
- Modify: `server/src/index.ts` (import after the `enrollmentDraftsRoutes` import Task 2 added after `:33`; mount directly after Task 2's `app.use('/api', enrollmentDraftsRoutes)` near `:462`)
- Test: `server/test/enrollments-feed.test.ts`

**Interfaces:**
- Consumes (Task 2): `DRAFT_SELECT`, `toDraftWire(row: DraftRow): DraftWire`, `type DraftWire` from `src/services/enrollment-draft.service.ts`. Existing: `getManageableOrgIds(userId): Promise<string[]>` and `isSuperAdmin(userId): Promise<boolean>` from `src/services/permission.ts:31,305`; `isValidTimezone`, `localDate(instant, tz)`, `todayInTimezone(tz, now?)` from `src/utils/timezone.ts:6,16,21`.
- Produces (exported from `src/services/enrollment-directory.service.ts`; Task 5 adds to this file, Task 6's test calls `getEnrollmentFeed`):
  - `FEED_STATUSES = ['active','upcoming','completed','draft','all'] as const`, `type FeedStatus`, `FEED_ITEM_CAP = 200`
  - `feedQuerySchema` (zod; NOT strict — unknown params such as `q` are ignored, D27), `type FeedQuery = { orgId?: string; groupId?: string; leaderId?: string; status: FeedStatus; tz: string }`
  - `class DirectoryError extends Error { status: 400 | 404 }`
  - `bucketOf(e: { startDate: Date; endDate: Date; timezone: string | null }, today: string): 'active' | 'upcoming' | 'completed'`
  - `interface ProgramRef { id: string; name: string; coverImageUrl: string | null }`, `interface PersonRef { id: string; name: string }`
  - `interface EnrollmentItem`, `interface DraftItem`, `type FeedItem`, `interface FeedSection`, `interface EnrollmentFeed` — §Contract Item/sections/options verbatim (below)
  - `getEnrollmentFeed(userId: string, query: FeedQuery, now?: Date): Promise<EnrollmentFeed>`
- Produces (wire, §Contract): `GET /api/enrollments-feed?orgId&groupId&leaderId&status&tz` → `{success, sections:[{group:{id,name,coverImageUrl,leader:{id,name}|null}, items:[Item]}], options:{groups:[{id,name}], leaders:[{id,name}]}}`; 400 bad `status`/`tz`/`orgId`.

Rules this task implements (SPEC §Decisions): scope D25 — no `orgId`: groups with `organizationId` in `getManageableOrgIds(userId)` OR `creatorId = userId` (super admins included, no platform-wide reach); with `orgId`: that org only, 400 `orgId is not one of your organizations` unless it is in `getManageableOrgIds` (a super admin may name any existing org). Active groups and active programs only. Status D8: Active `start ≤ today ≤ end`, Upcoming `start > today`, Completed `end < today`, with start/end = `localDate(…, enrollment.timezone ?? 'UTC')` and today = `todayInTimezone(tz)`; drafts only under `draft`/`all`; default `active`. Numbers D12/D16 (active `GroupMember`s only, non-removed schedules, lesson completion not version-filtered; never copy `getEnrollmentCompletionStats`). Recency D17: enrollment = latest of `createdAt` and its schedules' `member_lesson_progress.lastUpdatedAt` / `member_activity_progress.lastUpdatedAt` / `member_video_progress.lastWatchedAt`; draft = `updatedAt`; items and sections newest first. D25 cap: at most 200 items, lowest recency dropped BEFORE sectioning. `options` over scope + `orgId` + `status`, never narrowed by `groupId`/`leaderId`; `leaderId` matches `Group.creatorId` (D13).

Raw-SQL note: the live dev/prod tables store ids as `text`, a migration-built database (the test DB) as `uuid`; `enrollment-analytics.service.ts`'s `$1::uuid` form fails against `text` (`operator does not exist: text = uuid`). Every query here compares `col::text = ANY($1::text[])` — a no-op cast on `text` columns, so their indexes stay usable (verified with EXPLAIN on makeready_dev: Index Only Scan on `lesson_schedules_enrollmentId_idx`).

Build-time risk (F11): the aggregates are one GROUP BY query per concern over `lesson_schedules` (`@@index([enrollmentId])`) and the progress tables (`@@index([lessonScheduleId])`). Step 7 measures the feed on the fixture org; report the timing. Over 500 ms → report it as a concern with the EXPLAIN of the slowest query (do not restructure without a review).

Every test command runs against the branch test database from Task 1 (`makeready_ueb_test`); rebuild it with Task 1 Step 5 if missing.

- [ ] **Step 1: Write the failing tests** — `server/test/enrollments-feed.test.ts`

```ts
/**
 * ui2-enrollments-browse SC4 (D7, D8, D12, D13, D15–D17, D25, D27): GET /api/enrollments-feed.
 * Real DB + API-key auth. Dates are UTC days relative to today; enrollments carry timezone 'UTC'.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { bucketOf } from '../src/services/enrollment-directory.service.js'
import { todayInTimezone } from '../src/utils/timezone.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('bucketOf (D8)', () => {
  it('buckets on the enrollment\'s own zone against the request zone\'s today', () => {
    // Kiritimati is UTC+14: these instants fall on 2026-03-11 (start) and 2026-03-21 (end) there.
    const e = { startDate: new Date('2026-03-10T11:00:00Z'), endDate: new Date('2026-03-20T11:00:00Z'), timezone: 'Pacific/Kiritimati' }
    expect(bucketOf(e, '2026-03-10')).toBe('upcoming')
    expect(bucketOf({ ...e, timezone: 'UTC' }, '2026-03-10')).toBe('active')
    expect(bucketOf(e, '2026-03-21')).toBe('active')
    expect(bucketOf({ ...e, timezone: null }, '2026-03-21')).toBe('completed')
  })
})

describe('GET /api/enrollments-feed', () => {
  const stamp = Date.now()
  const now = new Date()
  const today = todayInTimezone('UTC')
  const day = (offset: number) => new Date(`${addDays(today, offset)}T12:00:00Z`)
  const ago = (ms: number) => new Date(now.getTime() - ms)
  const HOUR = 3_600_000
  const DAY = 24 * HOUR
  let owner: TestUserWithToken, leader2: TestUserWithToken, stranger: TestUserWithToken, admin: TestUserWithToken
  let orgA: string, orgB: string
  let g1: string, g2: string, gInactive: string, gB: string
  let program: string, programInactive: string, programB: string
  const memberIds: string[] = []
  let eActive: string, eUpcoming: string, eCompleted: string, eActive2: string
  let eInactiveProgram: string, eInactiveGroup: string, eForeign: string
  let draftId: string
  const progressAt = ago(HOUR)

  const feed = (u: TestUserWithToken, query: Record<string, string> = {}) =>
    request(app).get('/api/enrollments-feed').query({ tz: 'UTC', ...query }).set('Authorization', bearer(u.token))
  const ids = (body: { sections: { items: { kind: string; id?: string; draft?: { id: string } }[] }[] }) =>
    body.sections.flatMap((s) => s.items.map((i) => (i.kind === 'draft' ? i.draft!.id : i.id!)))
  const mkEnrollment = async (groupId: string, studyProgramId: string, start: number, end: number, createdAt: Date) =>
    (await prisma.enrollment.create({
      data: { groupId, studyProgramId, startDate: day(start), endDate: day(end), enabledDays: '["Mon"]', timezone: 'UTC', createdAt },
    })).id

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `ef-owner-${stamp}@cl.test`, name: 'Amy Owner' })
    leader2 = await createUserWithApiKey({ email: `ef-l2-${stamp}@cl.test`, name: 'Ben Leader' })
    stranger = await createUserWithApiKey({ email: `ef-str-${stamp}@cl.test`, name: 'Stranger' })
    admin = await createUserWithApiKey({ email: `ef-sa-${stamp}@cl.test`, name: 'Super', isSuperAdmin: true })
    orgA = (await prisma.organization.create({ data: { name: `EF A ${stamp}`, ownerId: owner.userId } })).id
    orgB = (await prisma.organization.create({ data: { name: `EF B ${stamp}`, ownerId: stranger.userId } })).id
    const role = await prisma.role.create({ data: { name: `EF Leader ${stamp}`, organizationId: orgA, isSystem: false } })
    await prisma.userRole.create({ data: { userId: leader2.userId, roleId: role.id, organizationId: orgA } })
    const mkGroup = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.group.create({ data: { name, code: `ef-${name}-${stamp}`, creatorId: creator, organizationId: org, isActive } })).id
    g1 = await mkGroup(orgA, owner.userId, 'Alpha')
    g2 = await mkGroup(orgA, leader2.userId, 'Bravo')
    gInactive = await mkGroup(orgA, owner.userId, 'Charlie', false)
    gB = await mkGroup(orgB, stranger.userId, 'Delta')
    const mkProgram = async (org: string, creator: string, name: string, isActive = true) =>
      (await prisma.studyProgram.create({ data: { name, days: 3, creatorId: creator, organizationId: org, isActive, coverImageUrl: `https://img.test/${name}.jpg` } })).id
    program = await mkProgram(orgA, owner.userId, `EF Program ${stamp}`)
    programInactive = await mkProgram(orgA, owner.userId, `EF Gone ${stamp}`, false)
    programB = await mkProgram(orgB, stranger.userId, `EF B Program ${stamp}`)

    // g1: three active members + one ex-member (D16: the ex-member's completions never count).
    for (let i = 0; i < 4; i++) {
      const m = await prisma.member.create({ data: { firstName: `M${i}`, lastName: 'Feed', phoneNumber: `+1558${String(stamp).slice(-6)}${i}` } })
      memberIds.push(m.id)
      await prisma.groupMember.create({ data: { groupId: g1, memberId: m.id, isActive: i < 3 } })
    }

    eActive = await mkEnrollment(g1, program, -5, 5, ago(10 * DAY))
    const s = [
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-5), estimatedMinutes: 30, title: 'A' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: new Date(day(-5).getTime() + HOUR), estimatedMinutes: 30, title: 'B' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-4), estimatedMinutes: null, title: 'C' } }),
      await prisma.lessonSchedule.create({ data: { enrollmentId: eActive, scheduledDate: day(-3), estimatedMinutes: 60, title: 'Removed', removedAt: now } }),
    ]
    const complete = (memberIndex: number, scheduleIndexes: number[]) =>
      prisma.memberLessonProgress.createMany({
        data: scheduleIndexes.map((k) => ({
          memberId: memberIds[memberIndex], lessonScheduleId: s[k].id, completedAt: ago(2 * HOUR), startedAt: ago(3 * HOUR), lastUpdatedAt: ago(2 * HOUR),
        })),
      })
    await complete(0, [0, 1, 2, 3]) // every lesson (+ the removed one, which never counts)
    await complete(1, [0])
    await complete(3, [0, 1, 2]) // ex-member
    await prisma.memberLessonProgress.update({
      where: { memberId_lessonScheduleId: { memberId: memberIds[1], lessonScheduleId: s[0].id } },
      data: { lastUpdatedAt: progressAt },
    })

    eUpcoming = await mkEnrollment(g1, program, 3, 10, ago(2 * DAY))
    eCompleted = await mkEnrollment(g1, program, -20, -10, ago(30 * DAY))
    eActive2 = await mkEnrollment(g2, program, -1, 1, ago(HOUR / 2))
    eInactiveProgram = await mkEnrollment(g1, programInactive, -1, 1, now)
    eInactiveGroup = await mkEnrollment(gInactive, program, -1, 1, now)
    eForeign = await mkEnrollment(gB, programB, -1, 1, now)
    draftId = (await prisma.enrollmentDraft.create({ data: { groupId: g1, studyProgramId: program, createdById: owner.userId } })).id
  })

  afterAll(async () => {
    const orgs = [orgA, orgB]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.enrollmentDraft.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.groupMember.deleteMany({ where: { memberId: { in: memberIds } } })
    await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.userRole.deleteMany({ where: { organizationId: orgA } })
    await prisma.role.deleteMany({ where: { organizationId: orgA } })
    const users = [owner.userId, leader2.userId, stranger.userId, admin.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('defaults to Active: sections by newest item, rows newest first, no drafts (D8, D17)', async () => {
    const res = await feed(owner)
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.sections.map((s: { group: { id: string } }) => s.group.id)).toEqual([g2, g1]) // eActive2 (−30 min) beats eActive (−1 h)
    expect(ids(res.body)).toEqual([eActive2, eActive])
    expect(res.body.sections[0].group).toEqual({ id: g2, name: 'Bravo', coverImageUrl: null, leader: { id: leader2.userId, name: 'Ben Leader' } })
  })

  it('computes the row numbers on active members and non-removed lessons (D12, D16, D17)', async () => {
    const res = await feed(owner)
    const item = res.body.sections[1].items[0]
    expect(item).toEqual({
      kind: 'enrollment',
      id: eActive,
      studyProgram: { id: program, name: `EF Program ${stamp}`, coverImageUrl: `https://img.test/EF Program ${stamp}.jpg` },
      startDate: addDays(today, -5),
      endDate: addDays(today, 5),
      enrolledAt: ago(10 * DAY).toISOString(),
      progress: 4 / 9, // (3 + 1) completions ÷ (3 active members × 3 lessons); the ex-member's 3 never count
      completedMembers: 1,
      memberCount: 3,
      plannedMinutes: 60, // 30 + 30 + null(0); the removed 60 is excluded
      recencyAt: progressAt.toISOString(),
    })
    expect(item.progress).toBeLessThanOrEqual(1)
  })

  it('Upcoming, Completed, Draft and All each return only their rows; drafts only under Draft and All (D8)', async () => {
    expect(ids((await feed(owner, { status: 'upcoming' })).body)).toEqual([eUpcoming])
    expect(ids((await feed(owner, { status: 'completed' })).body)).toEqual([eCompleted])
    const drafts = (await feed(owner, { status: 'draft' })).body
    expect(ids(drafts)).toEqual([draftId])
    expect(drafts.sections[0].items[0]).toMatchObject({
      kind: 'draft',
      draft: { id: draftId, groupId: g1, studyProgramId: program, createdBy: { id: owner.userId, name: 'Amy Owner' } },
      studyProgram: { id: program },
    })
    const all = (await feed(owner, { status: 'all' })).body
    expect(all.sections.map((s: { group: { id: string } }) => s.group.id)).toEqual([g1, g2]) // the draft (now) is newest
    expect(ids(all)).toEqual([draftId, eActive, eUpcoming, eCompleted, eActive2])
  })

  it('never lists an inactive group, an inactive program or another org (D19, D25)', async () => {
    const all = ids((await feed(owner, { status: 'all' })).body)
    for (const hidden of [eInactiveProgram, eInactiveGroup, eForeign]) expect(all).not.toContain(hidden)
  })

  it('groupId and leaderId narrow the sections; options stay the scope\'s (D13, §Contract)', async () => {
    const base = (await feed(owner)).body.options
    expect(base).toEqual({
      groups: [{ id: g1, name: 'Alpha' }, { id: g2, name: 'Bravo' }],
      leaders: [{ id: owner.userId, name: 'Amy Owner' }, { id: leader2.userId, name: 'Ben Leader' }],
    })
    const byLeader = (await feed(owner, { leaderId: leader2.userId })).body
    expect(ids(byLeader)).toEqual([eActive2])
    expect(byLeader.options).toEqual(base)
    const byGroup = (await feed(owner, { groupId: g1 })).body
    expect(ids(byGroup)).toEqual([eActive])
    expect(byGroup.options).toEqual(base)
    expect((await feed(owner, { status: 'upcoming' })).body.options.groups).toEqual([{ id: g1, name: 'Alpha' }])
  })

  it('orgId: one of yours narrows; another org is 400 with the D15 message', async () => {
    expect(ids((await feed(owner, { orgId: orgA })).body)).toEqual([eActive2, eActive])
    const res = await feed(owner, { orgId: orgB })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'orgId is not one of your organizations' })
    expect((await feed(owner, { orgId: 'nope' })).status).toBe(400)
  })

  it('a super admin with no orgId sees only orgs they manage; an explicit orgId reaches any org (D25)', async () => {
    expect(ids((await feed(admin, { status: 'all' })).body)).not.toContain(eActive)
    expect(ids((await feed(admin, { orgId: orgA })).body)).toEqual([eActive2, eActive])
  })

  it('400s a bad status or tz; ignores an unknown q (D27)', async () => {
    expect((await feed(owner, { status: 'paused' })).status).toBe(400)
    expect((await feed(owner, { tz: 'Mars/Olympus' })).status).toBe(400)
    expect((await feed(owner, { q: 'alpha' })).status).toBe(200)
  })
})

describe('GET /api/enrollments-feed cap (D25)', () => {
  const stamp = Date.now()
  let owner: TestUserWithToken
  let orgId: string
  let groupId: string
  let programId: string
  const created: string[] = []

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `efc-owner-${stamp}@cl.test`, name: 'Cap Owner' })
    orgId = (await prisma.organization.create({ data: { name: `EFC ${stamp}`, ownerId: owner.userId } })).id
    groupId = (await prisma.group.create({ data: { name: 'Cap', code: `efc-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({ data: { name: 'Cap P', days: 1, creatorId: owner.userId, organizationId: orgId } })).id
    const now = Date.now()
    const today = todayInTimezone('UTC')
    for (let i = 0; i < 201; i++) {
      const id = crypto.randomUUID()
      created.push(id)
      await prisma.enrollment.create({
        data: {
          id, groupId, studyProgramId: programId, enabledDays: '["Mon"]', timezone: 'UTC',
          startDate: new Date(`${addDays(today, -1)}T12:00:00Z`), endDate: new Date(`${addDays(today, 1)}T12:00:00Z`),
          createdAt: new Date(now - (i + 1) * 60_000),
        },
      })
    }
  })

  afterAll(async () => {
    await prisma.enrollment.deleteMany({ where: { groupId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId: owner.userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: owner.userId } })
  })

  it('returns at most 200 items and drops the oldest', async () => {
    const res = await request(app).get('/api/enrollments-feed').query({ tz: 'UTC' }).set('Authorization', bearer(owner.token))
    expect(res.status).toBe(200)
    const items = res.body.sections.flatMap((s: { items: { id: string }[] }) => s.items.map((i) => i.id))
    expect(items).toHaveLength(200)
    expect(items).toEqual(created.slice(0, 200))
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollments-feed.test.ts` → FAIL, `Failed to resolve import "../src/services/enrollment-directory.service.js"`

- [ ] **Step 3: Write the service** — `server/src/services/enrollment-directory.service.ts`

```ts
/**
 * The leader's enrollment directory (ui2-enrollments-browse SC4): the org-wide feed of enrollments and
 * drafts, sectioned by group. Raw-SQL aggregates, one query per concern over the kept enrollment ids
 * (no per-enrollment fan-out), as enrollment-analytics.service.ts does — but every id comparison is
 * `col::text = ANY($1::text[])`, which works on both the live text ids and migration-built uuid ids.
 */
import { z } from 'zod'
import type { Prisma } from '../generated/prisma/index.js'
import { prisma } from '../lib/prisma.js'
import { isValidTimezone, localDate, todayInTimezone } from '../utils/timezone.js'
import { DRAFT_SELECT, toDraftWire, type DraftWire } from './enrollment-draft.service.js'
import { getManageableOrgIds, isSuperAdmin } from './permission.js'

export const FEED_STATUSES = ['active', 'upcoming', 'completed', 'draft', 'all'] as const
export type FeedStatus = (typeof FEED_STATUSES)[number]
/** D25: the most items one response carries, across all sections. */
export const FEED_ITEM_CAP = 200

// Not .strict(): an unknown query param (e.g. a `q`) is ignored, never a 400 (D27).
export const feedQuerySchema = z.object({
  orgId: z.string().uuid().optional(),
  groupId: z.string().uuid().optional(),
  leaderId: z.string().uuid().optional(),
  status: z.enum(FEED_STATUSES).default('active'),
  tz: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).default('UTC'),
})
export type FeedQuery = z.infer<typeof feedQuerySchema>

export interface ProgramRef {
  id: string
  name: string
  coverImageUrl: string | null
}
export interface PersonRef {
  id: string
  name: string
}
export interface EnrollmentItem {
  kind: 'enrollment'
  id: string
  studyProgram: ProgramRef
  startDate: string
  endDate: string
  enrolledAt: string
  progress: number
  completedMembers: number
  memberCount: number
  plannedMinutes: number
  recencyAt: string
}
export interface DraftItem {
  kind: 'draft'
  draft: DraftWire
  studyProgram: ProgramRef
  recencyAt: string
}
export type FeedItem = EnrollmentItem | DraftItem
export interface FeedSection {
  group: { id: string; name: string; coverImageUrl: string | null; leader: PersonRef | null }
  items: FeedItem[]
}
export interface EnrollmentFeed {
  sections: FeedSection[]
  options: { groups: { id: string; name: string }[]; leaders: PersonRef[] }
}

export class DirectoryError extends Error {
  constructor(
    readonly status: 400 | 404,
    message: string,
  ) {
    super(message)
    this.name = 'DirectoryError'
  }
}

export type EnrollmentBucket = 'active' | 'upcoming' | 'completed'

/** D8: local start/end dates in the enrollment's own zone, against today in the request's zone. */
export function bucketOf(e: { startDate: Date; endDate: Date; timezone: string | null }, today: string): EnrollmentBucket {
  const tz = e.timezone ?? 'UTC'
  if (localDate(e.startDate, tz) > today) return 'upcoming'
  if (localDate(e.endDate, tz) < today) return 'completed'
  return 'active'
}

/** D15 + D25: the groups the feed may show. */
async function feedGroupScope(userId: string, orgId: string | undefined): Promise<Prisma.GroupWhereInput> {
  const orgIds = await getManageableOrgIds(userId)
  if (orgId) {
    const allowed =
      orgIds.includes(orgId) ||
      ((await isSuperAdmin(userId)) && (await prisma.organization.count({ where: { id: orgId } })) > 0)
    if (!allowed) throw new DirectoryError(400, 'orgId is not one of your organizations')
    return { isActive: true, organizationId: orgId }
  }
  return { isActive: true, OR: [{ organizationId: { in: orgIds } }, { creatorId: userId }] }
}

interface ScheduleTotals {
  plannedMinutes: number
  scheduleCount: number
}

/** D12: Σ estimatedMinutes (null = 0) and the count of non-removed schedules, per enrollment. */
async function scheduleTotals(ids: string[]): Promise<Map<string, ScheduleTotals>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; plannedMinutes: number; scheduleCount: number }[]>(
    `SELECT ls."enrollmentId"::text AS "enrollmentId",
            COALESCE(SUM(ls."estimatedMinutes"), 0)::int AS "plannedMinutes",
            COUNT(*)::int AS "scheduleCount"
       FROM lesson_schedules ls
      WHERE ls."enrollmentId"::text = ANY($1::text[])
        AND ls."removedAt" IS NULL
      GROUP BY ls."enrollmentId"`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, { plannedMinutes: r.plannedMinutes, scheduleCount: r.scheduleCount }]))
}

/** D16: active members of each enrollment's group. */
async function activeMemberCounts(ids: string[]): Promise<Map<string, number>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; memberCount: number }[]>(
    `SELECT e.id::text AS "enrollmentId", COUNT(DISTINCT gm."memberId")::int AS "memberCount"
       FROM enrollments e
       JOIN group_members gm
         ON gm."groupId" = e."groupId" AND gm."isActive" = true AND gm."memberId" IS NOT NULL
      WHERE e.id::text = ANY($1::text[])
      GROUP BY e.id`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, r.memberCount]))
}

/** D16: per enrollment, each ACTIVE member's count of completed non-removed lessons (not version-filtered). */
async function memberCompletions(ids: string[]): Promise<Map<string, number[]>> {
  const out = new Map<string, number[]>()
  if (ids.length === 0) return out
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; completed: number }[]>(
    `SELECT ls."enrollmentId"::text AS "enrollmentId", COUNT(DISTINCT ls.id)::int AS "completed"
       FROM lesson_schedules ls
       JOIN enrollments e ON e.id = ls."enrollmentId"
       JOIN member_lesson_progress mlp
         ON mlp."lessonScheduleId" = ls.id AND mlp."completedAt" IS NOT NULL
       JOIN group_members gm
         ON gm."groupId" = e."groupId" AND gm."memberId" = mlp."memberId" AND gm."isActive" = true
      WHERE ls."enrollmentId"::text = ANY($1::text[])
        AND ls."removedAt" IS NULL
      GROUP BY ls."enrollmentId", mlp."memberId"`,
    ids,
  )
  for (const r of rows) out.set(r.enrollmentId, [...(out.get(r.enrollmentId) ?? []), r.completed])
  return out
}

/** D17: the latest member progress touch on any of an enrollment's schedules. */
async function latestProgress(ids: string[]): Promise<Map<string, Date>> {
  if (ids.length === 0) return new Map()
  const rows = await prisma.$queryRawUnsafe<{ enrollmentId: string; lastAt: Date }[]>(
    `SELECT x."enrollmentId", MAX(x.at) AS "lastAt" FROM (
       SELECT ls."enrollmentId"::text AS "enrollmentId", MAX(p."lastUpdatedAt") AS at
         FROM lesson_schedules ls JOIN member_lesson_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
       UNION ALL
       SELECT ls."enrollmentId"::text, MAX(p."lastUpdatedAt")
         FROM lesson_schedules ls JOIN member_activity_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
       UNION ALL
       SELECT ls."enrollmentId"::text, MAX(p."lastWatchedAt")
         FROM lesson_schedules ls JOIN member_video_progress p ON p."lessonScheduleId" = ls.id
        WHERE ls."enrollmentId"::text = ANY($1::text[]) GROUP BY ls."enrollmentId"
     ) x GROUP BY x."enrollmentId"`,
    ids,
  )
  return new Map(rows.map((r) => [r.enrollmentId, new Date(r.lastAt)]))
}

const byName = (a: { name: string }, b: { name: string }) => a.name.localeCompare(b.name)
const later = (a: Date, b: Date | undefined) => (b && b > a ? b : a)

export async function getEnrollmentFeed(userId: string, query: FeedQuery, now: Date = new Date()): Promise<EnrollmentFeed> {
  const groups = await prisma.group.findMany({
    where: await feedGroupScope(userId, query.orgId),
    select: { id: true, name: true, coverImageUrl: true, creatorId: true, creator: { select: { id: true, name: true } } },
  })
  const groupById = new Map(groups.map((g) => [g.id, g]))
  const groupIds = groups.map((g) => g.id)
  const today = todayInTimezone(query.tz, now)
  const programSelect = { select: { id: true, name: true, coverImageUrl: true } } as const

  const enrollments =
    query.status === 'draft' || groupIds.length === 0
      ? []
      : (
          await prisma.enrollment.findMany({
            where: { groupId: { in: groupIds }, studyProgram: { isActive: true } },
            select: { id: true, groupId: true, startDate: true, endDate: true, timezone: true, createdAt: true, studyProgram: programSelect },
          })
        ).filter((e) => query.status === 'all' || bucketOf(e, today) === query.status)
  const drafts =
    (query.status === 'draft' || query.status === 'all') && groupIds.length > 0
      ? await prisma.enrollmentDraft.findMany({
          where: { groupId: { in: groupIds }, studyProgram: { isActive: true } },
          select: { ...DRAFT_SELECT, studyProgram: programSelect },
        })
      : []

  // §Contract: options over scope + orgId + status — before the groupId / leaderId narrowing.
  const listed = new Set([...enrollments.map((e) => e.groupId), ...drafts.map((d) => d.groupId)])
  const optionGroups = groups.filter((g) => listed.has(g.id))
  const leaders = new Map(optionGroups.map((g) => [g.creator.id, { id: g.creator.id, name: g.creator.name }]))
  const options = {
    groups: optionGroups.map((g) => ({ id: g.id, name: g.name })).sort(byName),
    leaders: [...leaders.values()].sort(byName),
  }

  const keep = (groupId: string) =>
    (!query.groupId || groupId === query.groupId) && (!query.leaderId || groupById.get(groupId)?.creatorId === query.leaderId)
  const keptEnrollments = enrollments.filter((e) => keep(e.groupId))
  const latest = await latestProgress(keptEnrollments.map((e) => e.id))

  // D17 recency, newest first (id breaks ties); D25 cap before sectioning.
  const ranked = [
    ...keptEnrollments.map((row) => ({ kind: 'enrollment' as const, row, recency: later(row.createdAt, latest.get(row.id)) })),
    ...drafts.filter((d) => keep(d.groupId)).map((row) => ({ kind: 'draft' as const, row, recency: row.updatedAt })),
  ]
    .sort((a, b) => b.recency.getTime() - a.recency.getTime() || a.row.id.localeCompare(b.row.id))
    .slice(0, FEED_ITEM_CAP)

  const ids = ranked.flatMap((r) => (r.kind === 'enrollment' ? [r.row.id] : []))
  const [totals, members, completions] = await Promise.all([scheduleTotals(ids), activeMemberCounts(ids), memberCompletions(ids)])

  const sections = new Map<string, FeedSection>()
  for (const r of ranked) {
    let item: FeedItem
    if (r.kind === 'enrollment') {
      const e = r.row
      const tz = e.timezone ?? 'UTC'
      const t = totals.get(e.id) ?? { plannedMinutes: 0, scheduleCount: 0 }
      const memberCount = members.get(e.id) ?? 0
      const perMember = completions.get(e.id) ?? []
      const denominator = memberCount * t.scheduleCount
      const done = perMember.reduce((sum, c) => sum + c, 0)
      item = {
        kind: 'enrollment',
        id: e.id,
        studyProgram: e.studyProgram,
        startDate: localDate(e.startDate, tz),
        endDate: localDate(e.endDate, tz),
        enrolledAt: e.createdAt.toISOString(),
        progress: denominator === 0 ? 0 : Math.min(1, done / denominator),
        completedMembers: t.scheduleCount === 0 ? 0 : perMember.filter((c) => c >= t.scheduleCount).length,
        memberCount,
        plannedMinutes: t.plannedMinutes,
        recencyAt: r.recency.toISOString(),
      }
    } else {
      const { studyProgram, ...draftRow } = r.row
      item = { kind: 'draft', draft: toDraftWire(draftRow), studyProgram, recencyAt: r.recency.toISOString() }
    }
    const groupId = r.row.groupId
    let section = sections.get(groupId)
    if (!section) {
      const g = groupById.get(groupId)!
      section = {
        group: { id: g.id, name: g.name, coverImageUrl: g.coverImageUrl, leader: g.creator ? { id: g.creator.id, name: g.creator.name } : null },
        items: [],
      }
      sections.set(groupId, section)
    }
    section.items.push(item)
  }
  return { sections: [...sections.values()], options }
}
```

- [ ] **Step 4: Write the thin router** — `server/src/routes/enrollment-directory.ts`

```ts
/**
 * The leader's enrollment directory (ui2-enrollments-browse SC4, SC5). Thin: parse, call the service,
 * map errors. Logic lives in services/enrollment-directory.service.ts.
 */
import { Router, type Request, type Response } from 'express'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth.js'
import { DirectoryError, feedQuerySchema, getEnrollmentFeed } from '../services/enrollment-directory.service.js'

const router = Router()
const userIdOf = (req: Request): string => (req.user as { id: string }).id

function fail(res: Response, error: unknown, label: string) {
  if (error instanceof z.ZodError) {
    return res.status(400).json({
      success: false,
      error: 'invalid_request',
      message: error.issues.map((i) => `${i.path.join('.') || 'query'}: ${i.message}`).join('; '),
    })
  }
  if (error instanceof DirectoryError) return res.status(error.status).json({ success: false, error: error.message })
  console.error(`Error ${label}:`, error)
  return res.status(500).json({ success: false, error: 'Internal server error' })
}

router.get('/enrollments-feed', requireAuth, async (req, res) => {
  try {
    const feed = await getEnrollmentFeed(userIdOf(req), feedQuerySchema.parse(req.query))
    res.json({ success: true, ...feed })
  } catch (error) {
    fail(res, error, 'building the enrollments feed')
  }
})

export default router
```

- [ ] **Step 5: Mount it** — in `server/src/index.ts`, after Task 2's `import enrollmentDraftsRoutes from './routes/enrollment-drafts.js'`:

```ts
import enrollmentDirectoryRoutes from './routes/enrollment-directory.js'
```

and directly after Task 2's `app.use('/api', enrollmentDraftsRoutes)`:

```ts

// Enrollment directory (ui2-enrollments-browse SC4/SC5): the org-wide feed and the enrollment home read
app.use('/api', enrollmentDirectoryRoutes)
```

- [ ] **Step 6: Run it and watch it pass** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollments-feed.test.ts` → PASS (10 tests); `cd server && npx tsc --noEmit` → no errors; `docker restart makeready-server`

- [ ] **Step 7: Measure the feed on the fixture org (F11)** — seed the base fixture world into the test database, then time one feed call for the fixture owner:

```bash
cd server && NODE_ENV=development DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npm run fixtures:reset
cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx tsx --eval 'import("./src/services/enrollment-directory.service.ts").then(async (m) => { await m.getEnrollmentFeed("f1f1f1f1-0001-4000-8000-000000000001", { status: "all", tz: "America/Chicago" }); const t = Date.now(); const f = await m.getEnrollmentFeed("f1f1f1f1-0001-4000-8000-000000000001", { status: "all", tz: "America/Chicago" }); console.log(`feed ${Date.now() - t} ms, ${f.sections.length} sections, ${f.sections.reduce((n, s) => n + s.items.length, 0)} items`); process.exit(0) })'
```

Put the printed line in your report. Over 500 ms → report it as a concern with `EXPLAIN ANALYZE` of the slowest of the four queries (run through `docker exec makeready-postgres psql -U postgres -d makeready_ueb_test`); do not restructure the queries in this task.

- [ ] **Step 8: Commit** — `git add server/src/services/enrollment-directory.service.ts server/src/routes/enrollment-directory.ts server/src/index.ts server/test/enrollments-feed.test.ts && git commit -m "feat(ui2-enrollments-browse): org-wide enrollments feed (SC4)"`

### Task 5: The enrollment home read — `getEnrollmentHome` + `GET /api/enrollments/:id/home`
App: server
Phase: 2
Recipe: `/api`

**Files:**
- Modify: `server/src/services/enrollment-directory.service.ts` (append the Home types, `homeQuerySchema` and `getEnrollmentHome`; add two imports)
- Modify: `server/src/routes/enrollment-directory.ts` (one route + import names)
- Test: `server/test/enrollment-home.test.ts`

**Interfaces:**
- Consumes (Task 4): `PersonRef`, `DirectoryError` and the file's existing imports (`prisma`, `localDate`, `isValidTimezone`, `z`) in `src/services/enrollment-directory.service.ts`; the router's `fail`/`userIdOf` helpers in `src/routes/enrollment-directory.ts`. Existing: `enrollmentManageFilter(userId): Promise<Prisma.EnrollmentWhereInput>` (`src/services/permission.ts:365`); `filterActivitiesToVersion(activities, resolvedVersionId)` (`src/services/lesson-version-resolution.ts:45`); `activityThumbnailUrl({type, youtubeThumbnailUrl, video, readBlocks}): string | null` (`src/services/next-study-thumbnail.ts:13`).
- Produces (exported from `src/services/enrollment-directory.service.ts`; Task 6's test calls it):
  - `homeQuerySchema` (zod, `{ tz?: string }` validated IANA)
  - `interface HomeActivity { id: string; type: string; title: string; thumbnailUrl: string | null }`
  - `interface HomeDay { scheduleId: string; date: string; percent: number; lessonCount: number; plannedMinutes: number }`
  - `interface HomeLesson { scheduleId: string; dayNumber: number; title: string; date: string; progress: number | null; activities: HomeActivity[] }`
  - `interface EnrollmentHome { id; studyProgram: { id; name; description: string | null; coverImageUrl: string | null; authorName: string }; group: { id; name; leader: PersonRef | null }; memberCount: number; enrolledAt: string; startDate: string; endDate: string; lessonAccess: LessonAccess; smsTime: string | null; timezone: string | null; days: HomeDay[]; lessons: HomeLesson[] }` — §Contract **Home** verbatim
  - `getEnrollmentHome(userId: string, enrollmentId: string): Promise<EnrollmentHome | null>`
- Produces (wire, §Contract): `GET /api/enrollments/:id/home?tz=` → `{success, home}`; 404 outside `enrollmentManageFilter`, unknown or malformed id; 400 invalid `tz`.

Rules (SPEC D20 + §Contract Home): `days`/`lessons` exclude removed schedules and are ordered by `scheduledDate` (id breaks ties); `days` = one entry per distinct local date (`localDate(scheduledDate, enrollment.timezone ?? 'UTC')`), `scheduleId` = that date's first schedule, `percent` = round(100 × active members who completed EVERY schedule on that date ÷ active members), 0 with no active members, `lessonCount`, `plannedMinutes` = Σ `estimatedMinutes` (null = 0); `lessons[].dayNumber` = 1-based position among the non-removed schedules; `progress` = active completers ÷ active members, `null` only when there are no active members; activities = the schedule's current version (`filterActivitiesToVersion(…, currentVersionId)`), `thumbnailUrl` = `activityThumbnailUrl()`; `authorName` = the program creator's `User.name`; `group.leader` = the group creator (D13); `smsTime`/`timezone` = the enrollment's own; every date `yyyy-MM-dd` in the enrollment's zone, `enrolledAt` an ISO instant. `tz` is validated (400) but changes nothing — §Contract puts every Home date in the enrollment's own zone.

Every test command runs against the branch test database from Task 1 (`makeready_ueb_test`); rebuild it with Task 1 Step 5 if missing.

- [ ] **Step 1: Write the failing tests** — `server/test/enrollment-home.test.ts`

```ts
/**
 * ui2-enrollments-browse SC5 (D16, D20, §Contract Home): GET /api/enrollments/:id/home.
 * Real DB + API-key auth.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { app } from '../src/index.js'
import { prisma } from '../src/lib/prisma.js'
import { todayInTimezone, zonedMidnight } from '../src/utils/timezone.js'
import { createUserWithApiKey, bearer, type TestUserWithToken } from './helpers/api-auth.js'

const CHI = 'America/Chicago'
const addDays = (ymd: string, n: number) => {
  const d = new Date(`${ymd}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10)
}

describe('GET /api/enrollments/:id/home', () => {
  const stamp = Date.now()
  const D = addDays(todayInTimezone(CHI), -2)
  let owner: TestUserWithToken, stranger: TestUserWithToken
  let orgId: string, strangerOrgId: string
  let groupId: string, emptyGroupId: string, programId: string
  let enrollmentId: string, emptyEnrollmentId: string, emptyScheduleId: string
  const memberIds: string[] = []
  let s1: string, s2: string, s3: string, removed: string
  let aYoutube: string, aVideo: string, aRead: string, aInput: string
  let enrolledAt: Date

  const home = (u: TestUserWithToken, id: string, query: Record<string, string> = {}) =>
    request(app).get(`/api/enrollments/${id}/home`).query(query).set('Authorization', bearer(u.token))

  beforeAll(async () => {
    owner = await createUserWithApiKey({ email: `eh-owner-${stamp}@cl.test`, name: 'Hana Author' })
    stranger = await createUserWithApiKey({ email: `eh-str-${stamp}@cl.test`, name: 'Stranger' })
    orgId = (await prisma.organization.create({ data: { name: `EH Org ${stamp}`, ownerId: owner.userId } })).id
    strangerOrgId = (await prisma.organization.create({ data: { name: `EH Other ${stamp}`, ownerId: stranger.userId } })).id
    groupId = (await prisma.group.create({ data: { name: 'Home Group', code: `eh-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    emptyGroupId = (await prisma.group.create({ data: { name: 'Empty', code: `ehe-${stamp}`, creatorId: owner.userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({
      data: { name: 'Romans', description: 'Twelve readings', coverImageUrl: 'https://img.test/cover.jpg', days: 3, creatorId: owner.userId, organizationId: orgId },
    })).id
    for (let i = 0; i < 3; i++) {
      const m = await prisma.member.create({ data: { firstName: `H${i}`, lastName: 'Home', phoneNumber: `+1559${String(stamp).slice(-6)}${i}` } })
      memberIds.push(m.id)
      await prisma.groupMember.create({ data: { groupId, memberId: m.id, isActive: i < 2 } }) // member 2 left
    }
    enrolledAt = new Date(Date.now() - 5 * 86_400_000)
    enrollmentId = (await prisma.enrollment.create({
      data: {
        groupId, studyProgramId: programId, startDate: zonedMidnight(D, CHI), endDate: zonedMidnight(addDays(D, 1), CHI),
        enabledDays: '["Mon"]', smsTime: '07:30', timezone: CHI, lessonAccess: 'ONE_AT_A_TIME', createdAt: enrolledAt,
      },
    })).id
    const mkSchedule = async (date: Date, title: string, estimatedMinutes: number | null, removedAt: Date | null = null) =>
      (await prisma.lessonSchedule.create({ data: { enrollmentId, scheduledDate: date, title, estimatedMinutes, removedAt } })).id
    s1 = await mkSchedule(zonedMidnight(D, CHI), 'Day one', 20)
    s2 = await mkSchedule(new Date(zonedMidnight(D, CHI).getTime() + 3_600_000), 'Day one, part two', 10) // same local date
    s3 = await mkSchedule(zonedMidnight(addDays(D, 1), CHI), 'Day two', null)
    removed = await mkSchedule(zonedMidnight(addDays(D, 2), CHI), 'Gone', 99, new Date())

    // s1's activities: an old version's row (never shown) and the current version's four, one per thumbnail rule.
    const v1 = await prisma.lessonScheduleVersion.create({ data: { lessonScheduleId: s1, versionNumber: 1 } })
    const v2 = await prisma.lessonScheduleVersion.create({ data: { lessonScheduleId: s1, versionNumber: 2 } })
    await prisma.lessonSchedule.update({ where: { id: s1 }, data: { currentVersionId: v2.id } })
    const video = await prisma.video.create({
      data: { cloudflareUid: `eh-${stamp}`, playbackUrl: 'https://video.test/v.m3u8', userId: owner.userId, thumbnailUrl: 'https://img.test/vid.jpg' },
    })
    const act = async (data: Record<string, unknown>) =>
      (await prisma.scheduledLessonActivity.create({ data: { lessonScheduleId: s1, ...data } as never })).id
    await act({ type: 'YOUTUBE', orderNumber: 1, title: 'Old', versionId: v1.id, youtubeThumbnailUrl: 'https://img.test/old.jpg' })
    aYoutube = await act({ type: 'YOUTUBE', orderNumber: 1, title: 'Watch', versionId: v2.id, youtubeThumbnailUrl: 'https://img.test/yt.jpg' })
    aVideo = await act({ type: 'VIDEO', orderNumber: 2, title: 'Video', versionId: v2.id, videoId: video.id })
    aRead = await act({ type: 'READ', orderNumber: 3, title: 'Read', versionId: v2.id })
    aInput = await act({ type: 'USER_INPUT', orderNumber: 4, title: 'Reflect', versionId: v2.id })
    await prisma.activityReadBlock.create({ data: { scheduledActivityId: aRead, orderNumber: 1, content: 'no image' } })
    await prisma.activityReadBlock.create({ data: { scheduledActivityId: aRead, orderNumber: 2, content: 'image', backgroundImageUrl: 'https://img.test/read.jpg' } })

    const complete = (memberIndex: number, scheduleIds: string[]) =>
      prisma.memberLessonProgress.createMany({ data: scheduleIds.map((lessonScheduleId) => ({ memberId: memberIds[memberIndex], lessonScheduleId, completedAt: new Date() })) })
    await complete(0, [s1, s2, s3, removed])
    await complete(1, [s1])
    await complete(2, [s1, s2, s3]) // ex-member: never counts

    emptyEnrollmentId = (await prisma.enrollment.create({
      data: { groupId: emptyGroupId, studyProgramId: programId, startDate: zonedMidnight(D, CHI), endDate: zonedMidnight(D, CHI), enabledDays: '["Mon"]', timezone: CHI },
    })).id
    emptyScheduleId = (await prisma.lessonSchedule.create({ data: { enrollmentId: emptyEnrollmentId, scheduledDate: zonedMidnight(D, CHI), title: 'Solo', estimatedMinutes: 5 } })).id
  })

  afterAll(async () => {
    const orgs = [orgId, strangerOrgId]
    await prisma.enrollment.deleteMany({ where: { group: { organizationId: { in: orgs } } } })
    await prisma.video.deleteMany({ where: { userId: owner.userId } })
    await prisma.groupMember.deleteMany({ where: { memberId: { in: memberIds } } })
    await prisma.member.deleteMany({ where: { id: { in: memberIds } } })
    await prisma.studyProgram.deleteMany({ where: { organizationId: { in: orgs } } })
    await prisma.group.deleteMany({ where: { organizationId: { in: orgs } } })
    const users = [owner.userId, stranger.userId]
    await prisma.apiKey.deleteMany({ where: { userId: { in: users } } })
    await prisma.organization.deleteMany({ where: { id: { in: orgs } } })
    await prisma.user.deleteMany({ where: { id: { in: users } } })
  })

  it('assembles the header: program + author, group + leader, active members, span, invite time (D20)', async () => {
    const res = await home(owner, enrollmentId)
    expect(res.status).toBe(200)
    expect(res.body.success).toBe(true)
    expect(res.body.home).toMatchObject({
      id: enrollmentId,
      studyProgram: { id: programId, name: 'Romans', description: 'Twelve readings', coverImageUrl: 'https://img.test/cover.jpg', authorName: 'Hana Author' },
      group: { id: groupId, name: 'Home Group', leader: { id: owner.userId, name: 'Hana Author' } },
      memberCount: 2,
      enrolledAt: enrolledAt.toISOString(),
      startDate: D,
      endDate: addDays(D, 1),
      lessonAccess: 'ONE_AT_A_TIME',
      smsTime: '07:30',
      timezone: CHI,
    })
  })

  it('days: one per local date, first schedule\'s id, everyone-on-that-date percent, removed excluded (D20)', async () => {
    const { days } = (await home(owner, enrollmentId)).body.home
    expect(days).toEqual([
      { scheduleId: s1, date: D, percent: 50, lessonCount: 2, plannedMinutes: 30 }, // member 0 did both; member 1 only s1
      { scheduleId: s3, date: addDays(D, 1), percent: 50, lessonCount: 1, plannedMinutes: 0 },
    ])
  })

  it('lessons: dayNumber by position, progress over active members, current-version activities with thumbnails', async () => {
    const { lessons } = (await home(owner, enrollmentId)).body.home
    expect(lessons.map((l: { scheduleId: string; dayNumber: number; title: string; date: string; progress: number }) =>
      [l.scheduleId, l.dayNumber, l.title, l.date, l.progress])).toEqual([
      [s1, 1, 'Day one', D, 1],
      [s2, 2, 'Day one, part two', D, 0.5],
      [s3, 3, 'Day two', addDays(D, 1), 0.5],
    ])
    expect(lessons[0].activities).toEqual([
      { id: aYoutube, type: 'YOUTUBE', title: 'Watch', thumbnailUrl: 'https://img.test/yt.jpg' },
      { id: aVideo, type: 'VIDEO', title: 'Video', thumbnailUrl: 'https://img.test/vid.jpg' },
      { id: aRead, type: 'READ', title: 'Read', thumbnailUrl: 'https://img.test/read.jpg' },
      { id: aInput, type: 'USER_INPUT', title: 'Reflect', thumbnailUrl: null },
    ])
    expect(lessons[1].activities).toEqual([])
  })

  it('no active members: progress null and day percent 0', async () => {
    const body = (await home(owner, emptyEnrollmentId)).body.home
    expect(body.memberCount).toBe(0)
    expect(body.days).toEqual([{ scheduleId: emptyScheduleId, date: D, percent: 0, lessonCount: 1, plannedMinutes: 5 }])
    expect(body.lessons[0].progress).toBeNull()
  })

  it('404 outside enrollmentManageFilter, for an unknown id and a malformed one; 400 on a bad tz', async () => {
    expect((await home(stranger, enrollmentId)).status).toBe(404)
    expect((await home(owner, '00000000-0000-4000-8000-000000000000')).status).toBe(404)
    expect((await home(owner, 'nope')).status).toBe(404)
    expect((await home(owner, enrollmentId, { tz: 'Mars/Olympus' })).status).toBe(400)
    expect((await home(owner, enrollmentId, { tz: 'Asia/Tokyo' })).body.home.startDate).toBe(D) // enrollment's own zone
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-home.test.ts` → FAIL, every request 404 (`/enrollments/:id/home` not routed)

- [ ] **Step 3: Append the home read to the service** — `server/src/services/enrollment-directory.service.ts`

Add to the imports at the top:

```ts
import type { LessonAccess } from '../generated/prisma/index.js'
import { filterActivitiesToVersion } from './lesson-version-resolution.js'
import { activityThumbnailUrl } from './next-study-thumbnail.js'
```

and change the existing permission import to:

```ts
import { enrollmentManageFilter, getManageableOrgIds, isSuperAdmin } from './permission.js'
```

Append at the end of the file:

```ts
// ── SC5: the enrollment home read (D20, §Contract Home) ──────────────────────

/** `tz` is validated but changes nothing: every Home date is in the enrollment's own zone (§Contract). */
export const homeQuerySchema = z.object({
  tz: z.string().refine(isValidTimezone, { message: 'Invalid timezone' }).optional(),
})

export interface HomeActivity {
  id: string
  type: string
  title: string
  thumbnailUrl: string | null
}
export interface HomeDay {
  scheduleId: string
  date: string
  percent: number
  lessonCount: number
  plannedMinutes: number
}
export interface HomeLesson {
  scheduleId: string
  dayNumber: number
  title: string
  date: string
  progress: number | null
  activities: HomeActivity[]
}
export interface EnrollmentHome {
  id: string
  studyProgram: { id: string; name: string; description: string | null; coverImageUrl: string | null; authorName: string }
  group: { id: string; name: string; leader: PersonRef | null }
  memberCount: number
  enrolledAt: string
  startDate: string
  endDate: string
  lessonAccess: LessonAccess
  smsTime: string | null
  timezone: string | null
  days: HomeDay[]
  lessons: HomeLesson[]
}

export async function getEnrollmentHome(userId: string, enrollmentId: string): Promise<EnrollmentHome | null> {
  const enrollment = await prisma.enrollment.findFirst({
    where: { id: enrollmentId, ...(await enrollmentManageFilter(userId)) },
    select: {
      id: true,
      groupId: true,
      createdAt: true,
      startDate: true,
      endDate: true,
      lessonAccess: true,
      smsTime: true,
      timezone: true,
      studyProgram: {
        select: { id: true, name: true, description: true, coverImageUrl: true, creator: { select: { name: true } } },
      },
      group: { select: { id: true, name: true, creator: { select: { id: true, name: true } } } },
      lessonSchedules: {
        where: { removedAt: null },
        orderBy: [{ scheduledDate: 'asc' }, { id: 'asc' }],
        select: {
          id: true,
          title: true,
          scheduledDate: true,
          estimatedMinutes: true,
          currentVersionId: true,
          scheduledActivities: {
            orderBy: { orderNumber: 'asc' },
            select: {
              id: true,
              type: true,
              title: true,
              versionId: true,
              youtubeThumbnailUrl: true,
              video: { select: { thumbnailUrl: true } },
              readBlocks: {
                where: { backgroundImageUrl: { not: null } },
                orderBy: { orderNumber: 'asc' },
                take: 1,
                select: { backgroundImageUrl: true },
              },
            },
          },
        },
      },
    },
  })
  if (!enrollment) return null
  const tz = enrollment.timezone ?? 'UTC'
  const schedules = enrollment.lessonSchedules

  // D16 / F5: active members only.
  const active = await prisma.groupMember.findMany({
    where: { groupId: enrollment.groupId, isActive: true, memberId: { not: null } },
    select: { memberId: true },
  })
  const activeIds = [...new Set(active.map((m) => m.memberId as string))]
  const memberCount = activeIds.length
  const completers = new Map<string, Set<string>>(schedules.map((s) => [s.id, new Set<string>()]))
  if (memberCount > 0 && schedules.length > 0) {
    const rows = await prisma.memberLessonProgress.findMany({
      where: { lessonScheduleId: { in: schedules.map((s) => s.id) }, memberId: { in: activeIds }, completedAt: { not: null } },
      select: { memberId: true, lessonScheduleId: true },
    })
    for (const r of rows) completers.get(r.lessonScheduleId)?.add(r.memberId)
  }

  const byDate = new Map<string, typeof schedules>()
  for (const s of schedules) {
    const date = localDate(s.scheduledDate, tz)
    byDate.set(date, [...(byDate.get(date) ?? []), s])
  }
  const days: HomeDay[] = [...byDate.entries()].map(([date, onDate]) => {
    const everyOne = activeIds.filter((m) => onDate.every((s) => completers.get(s.id)?.has(m))).length
    return {
      scheduleId: onDate[0].id,
      date,
      percent: memberCount === 0 ? 0 : Math.round((100 * everyOne) / memberCount),
      lessonCount: onDate.length,
      plannedMinutes: onDate.reduce((sum, s) => sum + (s.estimatedMinutes ?? 0), 0),
    }
  })

  const lessons: HomeLesson[] = schedules.map((s, index) => ({
    scheduleId: s.id,
    dayNumber: index + 1,
    title: s.title ?? '',
    date: localDate(s.scheduledDate, tz),
    progress: memberCount === 0 ? null : (completers.get(s.id)?.size ?? 0) / memberCount,
    activities: filterActivitiesToVersion(s.scheduledActivities, s.currentVersionId).map((a) => ({
      id: a.id,
      type: a.type,
      title: a.title,
      thumbnailUrl: activityThumbnailUrl({ type: a.type, youtubeThumbnailUrl: a.youtubeThumbnailUrl, video: a.video, readBlocks: a.readBlocks }),
    })),
  }))

  const leader = enrollment.group.creator
  return {
    id: enrollment.id,
    studyProgram: {
      id: enrollment.studyProgram.id,
      name: enrollment.studyProgram.name,
      description: enrollment.studyProgram.description,
      coverImageUrl: enrollment.studyProgram.coverImageUrl,
      authorName: enrollment.studyProgram.creator.name,
    },
    group: { id: enrollment.group.id, name: enrollment.group.name, leader: leader ? { id: leader.id, name: leader.name } : null },
    memberCount,
    enrolledAt: enrollment.createdAt.toISOString(),
    startDate: localDate(enrollment.startDate, tz),
    endDate: localDate(enrollment.endDate, tz),
    lessonAccess: enrollment.lessonAccess,
    smsTime: enrollment.smsTime,
    timezone: enrollment.timezone,
    days,
    lessons,
  }
}
```

- [ ] **Step 4: Add the route** — in `server/src/routes/enrollment-directory.ts`, change the service import to:

```ts
import {
  DirectoryError,
  feedQuerySchema,
  getEnrollmentFeed,
  getEnrollmentHome,
  homeQuerySchema,
} from '../services/enrollment-directory.service.js'
```

and add before `export default router`:

```ts
router.get('/enrollments/:id/home', requireAuth, async (req, res) => {
  const notFound = () => res.status(404).json({ success: false, error: 'Enrollment not found' })
  if (!z.string().uuid().safeParse(req.params.id).success) return notFound()
  try {
    homeQuerySchema.parse(req.query)
    const home = await getEnrollmentHome(userIdOf(req), req.params.id)
    if (!home) return notFound()
    res.json({ success: true, home })
  } catch (error) {
    fail(res, error, 'reading the enrollment home')
  }
})
```

- [ ] **Step 5: Run it and watch it pass** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run test/enrollment-home.test.ts test/enrollments-feed.test.ts` → PASS; `cd server && npx tsc --noEmit` → no errors; `docker restart makeready-server`

- [ ] **Step 6: Commit** — `git add server/src/services/enrollment-directory.service.ts server/src/routes/enrollment-directory.ts server/test/enrollment-home.test.ts && git commit -m "feat(ui2-enrollments-browse): enrollment home read (SC5)"`

### Task 6: Fixture layers for the walk — `enrollment-home.ts`, `enrollments-home.ts`, kind `001b` — then freeze the contract
App: server
Phase: 2
Recipe: `server/fixtures/README.md` §A new screen layer (SPEC D22)

**Files:**
- Modify: `server/fixtures/ids.ts:35` (add the kind after `readBlock: '001a',`)
- Create: `server/fixtures/screens/enrollment-home.ts`
- Create: `server/fixtures/screens/enrollments-home.ts`
- Modify: `server/fixtures/README.md` (§Fixed IDs kinds list; a new "What `full` makes non-empty on Enrollments" section after §What `full` makes non-empty on Groups)
- Test: `server/fixtures/__tests__/enrollments-home.db.test.ts`
- Unchanged on purpose: `server/fixtures/wipe.ts` — drafts go with the group cascade (`wipe.ts:29` deletes the fixture org's groups); enrollments with their group.

**Interfaces:**
- Consumes (Task 1): `prisma.enrollmentDraft`. (Task 4) `getEnrollmentFeed(userId, { status, tz }): Promise<EnrollmentFeed>`; (Task 5) `getEnrollmentHome(userId, enrollmentId): Promise<EnrollmentHome | null>` — both from `src/services/enrollment-directory.service.ts`. Base: `lessonId(programIndex, day)` (`fixtures/base.ts:106`), `FIXTURE_LEADER_GROUP_ID`, `FIXTURE_LEADER_USER_ID`, `FIXTURE_GROUP_IDS`, `FIXTURE_PROGRAM_IDS`, `FIXTURE_USER_ID`, `fixtureId` (`fixtures/ids.ts`), `FIXTURE_TZ` (`fixtures/context.ts:22`), `YOUTUBE_THUMBNAIL_URL`, `READ_IMAGE_URL` (`fixtures/screens/groups-detail.ts:42,44`). DB harness `openFixturesDb`, `TEST_DB_URL` (`fixtures/__tests__/db-harness.ts`).
- Produces: fixture kind `enrollmentDraft: '001b'`; exports `HOME_ENROLLMENT_ID`, `HOME_LESSON_COUNT`, `HOME_SMS_TIME` (enrollment-home.ts); `UPCOMING_ENROLLMENT_ID`, `DRAFT_PARTIAL_ID`, `DRAFT_STALE_ID` (enrollments-home.ts). After this task: `contract: frozen <date>` in `docs/features/ui2-enrollments-browse/MANIFEST.md`.

Layer rules (fixtures/README.md): layers are discovered by filename (`runner.ts` loads every `screens/*.ts` in order — no registration needed; `enrollment-home.ts` and `enrollments-home.ts` sort before `groups-*.ts` and `home-dashboard.ts`). They must **never touch `ctx.rand`** (one draw would shift home-dashboard's numbers), must not create orgs, users or groups, must take every id from `fixtureId`, and every date from `ctx` — never a literal. They add NO member progress or client events: home-dashboard's fixture test asserts `client_events ≥ member_lesson_progress` and exact video totals; base enrollment 4 (Tuesday Men's Group, progress spread over days by home-dashboard) is D22's "progress spread over days" enrollment. Both new enrollments sit on the Prayer Team (base group 4, created by Nathan Hughes — D22's second group creator), which home-dashboard's per-group history never walks.

The fixture DB test runs only with `FIXTURES_TEST_DATABASE_URL` set (it is skipped and prints a line otherwise — never count a skip as a pass): use the branch test database from Task 1 (`makeready_ueb_test`, which carries the seeded system Owner role); rebuild it with Task 1 Step 5 if missing.

- [ ] **Step 1: Write the failing layer test** — `server/fixtures/__tests__/enrollments-home.db.test.ts`

```ts
/**
 * enrollments-home + enrollment-home layers (ui2-enrollments-browse D22) against a throwaway database:
 * the two drafts, every status bucket of the feed, two group creators, and the rich detail enrollment.
 * Gated on FIXTURES_TEST_DATABASE_URL (db-harness.ts).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { FIXTURE_TZ, localDate } from '../context.js'
import { FIXTURE_ENROLLMENT_IDS, FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { HOME_ENROLLMENT_ID, HOME_LESSON_COUNT, HOME_SMS_TIME } from '../screens/enrollment-home.js'
import { DRAFT_PARTIAL_ID, DRAFT_STALE_ID, UPCOMING_ENROLLMENT_ID } from '../screens/enrollments-home.js'
import { ENROLL_ENDED_ENROLLMENT_ID } from '../screens/groups-enroll-program.js'
import { READ_IMAGE_URL, YOUTUBE_THUMBNAIL_URL } from '../screens/groups-detail.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

type Directory = typeof import('../../src/services/enrollment-directory.service.js')

describe.skipIf(!TEST_DB_URL)('enrollments-home + enrollment-home full scenario against the test database', () => {
  let db: FixturesDb
  let dir: Directory
  const ids = (feed: Awaited<ReturnType<Directory['getEnrollmentFeed']>>) =>
    feed.sections.flatMap((s) => s.items.map((i) => (i.kind === 'draft' ? i.draft.id : i.id)))
  const feedOf = (status: 'active' | 'upcoming' | 'completed' | 'draft' | 'all') =>
    dir.getEnrollmentFeed(FIXTURE_USER_ID, { status, tz: FIXTURE_TZ })

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
    dir = await import('../../src/services/enrollment-directory.service.js')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('seeds a 2/6 draft (group + program only) and a 6/6 draft whose first lesson date is past', async () => {
    const partial = await db.prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: DRAFT_PARTIAL_ID } })
    expect(partial).toMatchObject({ startDate: null, scheduleDates: null, smsTime: null, syncMode: null, lessonAccess: null, createdById: FIXTURE_USER_ID })
    const stale = await db.prisma.enrollmentDraft.findUniqueOrThrow({ where: { id: DRAFT_STALE_ID } })
    expect(stale).toMatchObject({ smsTime: '08:00', timezone: FIXTURE_TZ, syncMode: 'AUTO', lessonAccess: 'ONE_AT_A_TIME', createdById: FIXTURE_LEADER_USER_ID })
    const dates = stale.scheduleDates as string[]
    expect(dates).toHaveLength(21)
    expect(stale.startDate).toBe(dates[0])
    expect(dates[0] < localDate(new Date(), FIXTURE_TZ)).toBe(true)
  })

  it('Draft lists exactly the two drafts', async () => {
    expect(ids(await feedOf('draft')).sort()).toEqual([DRAFT_PARTIAL_ID, DRAFT_STALE_ID].sort())
  })

  it('Upcoming lists exactly the Prayer Team upcoming enrollment', async () => {
    expect(ids(await feedOf('upcoming'))).toEqual([UPCOMING_ENROLLMENT_ID])
  })

  it('Active lists base enrollments 2–4 and the Prayer Team detail enrollment, across four groups', async () => {
    const active = await feedOf('active')
    expect(ids(active).sort()).toEqual([...FIXTURE_ENROLLMENT_IDS.slice(1), HOME_ENROLLMENT_ID].sort())
    expect(active.sections.length).toBeGreaterThanOrEqual(3)
  })

  it('Completed lists every fixture enrollment that ended before today (Chicago)', async () => {
    const today = localDate(new Date(), FIXTURE_TZ)
    const ended = (await db.prisma.enrollment.findMany({ where: { group: { organizationId: FIXTURE_ORG_ID } }, select: { id: true, endDate: true } }))
      .filter((e) => localDate(e.endDate, FIXTURE_TZ) < today)
      .map((e) => e.id)
    const completed = ids(await feedOf('completed'))
    expect(completed.sort()).toEqual(ended.sort())
    expect(completed).toContain(FIXTURE_ENROLLMENT_IDS[0])
    expect(completed).toContain(ENROLL_ENDED_ENROLLMENT_ID)
  })

  it('All offers both group creators as leaders', async () => {
    expect((await feedOf('all')).options.leaders.map((l) => l.name)).toEqual(['Fixture Leader', 'Nathan Hughes'])
  })

  it('the detail enrollment reads 21 lessons, its invite time, Nathan as leader and slide thumbnails', async () => {
    const home = await dir.getEnrollmentHome(FIXTURE_USER_ID, HOME_ENROLLMENT_ID)
    expect(home).not.toBeNull()
    expect(home!.lessons).toHaveLength(HOME_LESSON_COUNT)
    expect(home!.smsTime).toBe(HOME_SMS_TIME)
    expect(home!.group.leader?.name).toBe('Nathan Hughes')
    expect(home!.memberCount).toBe(3)
    expect(home!.lessons[0].activities.map((a) => a.thumbnailUrl)).toEqual([YOUTUBE_THUMBNAIL_URL, READ_IMAGE_URL])
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run fixtures/__tests__/enrollments-home.db.test.ts` → FAIL, `Failed to resolve import "../screens/enrollment-home.js"` (confirm the output does NOT say "fixtures DB tests skipped")

- [ ] **Step 3: Add the fixture id kind** — in `server/fixtures/ids.ts`, after `readBlock: '001a',` (`:35`):

```ts
  // ui2-enrollments-browse D22: saved enroll checklists.
  enrollmentDraft: '001b',
```

- [ ] **Step 4: Write the detail layer** — `server/fixtures/screens/enrollment-home.ts`

```ts
/**
 * enrollment-home layer (ui2-enrollments-browse D22): the enrollment detail page's walk enrollment.
 *  - enrollment n 950 on the Prayer Team (base group 4, created by Nathan Hughes — the feed's second
 *    group creator): "Foundations of Faith" (21 lessons, one a day from −10 to +10, so active today),
 *    invite 07:30 Chicago, one lesson at a time. Its 3 members come from members-home.ts.
 *  - days 1–3 each carry a YOUTUBE (youtubeThumbnailUrl) and a READ (read-block image) activity, so
 *    the lesson rows show slide thumbnails.
 * No member progress or client events (home-dashboard's totals stay exact); base enrollment 4 carries
 * the progress spread over days. Never touches ctx.rand. Creates no org, user or group; wipe.ts removes
 * all of it with the Prayer Team (group cascade).
 */
import { lessonId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_PROGRAM_IDS, fixtureId } from '../ids.js'
import { READ_IMAGE_URL, YOUTUBE_THUMBNAIL_URL } from './groups-detail.js'

export const HOME_ENROLLMENT_ID = fixtureId('enrollment', 950)
export const HOME_LESSON_COUNT = 21
export const HOME_START_OFFSET = -10
export const HOME_SMS_TIME = '07:30'
const PROGRAM_INDEX = 1 // base PROGRAMS: days21 = index 1 "Foundations of Faith"
const scheduleIdFor = (day: number) => fixtureId('schedule', 950_000 + day)
const activityIdFor = (day: number, order: number) => fixtureId('scheduledActivity', 950_000 + day * 10 + order)
const readBlockIdFor = (day: number) => fixtureId('readBlock', 950_000 + day)

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const days = Array.from({ length: HOME_LESSON_COUNT }, (_, i) => i + 1)
  const offsetOf = (day: number) => HOME_START_OFFSET + day - 1
  await prisma.enrollment.create({
    data: {
      id: HOME_ENROLLMENT_ID,
      groupId: FIXTURE_LEADER_GROUP_ID,
      studyProgramId: FIXTURE_PROGRAM_IDS.days21,
      startDate: ctx.at(offsetOf(1), 12),
      endDate: ctx.at(offsetOf(HOME_LESSON_COUNT), 12),
      enabledDays: JSON.stringify(['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']),
      smsTime: HOME_SMS_TIME,
      timezone: FIXTURE_TZ,
      lessonAccess: 'ONE_AT_A_TIME',
      createdById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.daysAgo(12),
    },
  })
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: scheduleIdFor(day),
      enrollmentId: HOME_ENROLLMENT_ID,
      lessonId: lessonId(PROGRAM_INDEX, day),
      scheduledDate: ctx.at(offsetOf(day), 12),
      title: `Day ${day}`,
      estimatedMinutes: 25,
    })),
  })
  for (const day of [1, 2, 3]) {
    await prisma.scheduledLessonActivity.createMany({
      data: [
        {
          id: activityIdFor(day, 1),
          lessonScheduleId: scheduleIdFor(day),
          type: 'YOUTUBE',
          orderNumber: 1,
          title: 'Watch: Overview',
          youtubeUrl: 'https://www.youtube.com/watch?v=G-2e9mMf7E8',
          youtubeVideoId: 'G-2e9mMf7E8',
          youtubeThumbnailUrl: YOUTUBE_THUMBNAIL_URL,
        },
        { id: activityIdFor(day, 2), lessonScheduleId: scheduleIdFor(day), type: 'READ', orderNumber: 2, title: `Read John ${day}`, referenceTitle: `John ${day}` },
      ],
    })
    await prisma.activityReadBlock.create({
      data: { id: readBlockIdFor(day), scheduledActivityId: activityIdFor(day, 2), orderNumber: 1, title: `John ${day}`, content: `Read John ${day} slowly.`, backgroundImageUrl: READ_IMAGE_URL },
    })
  }
}
```

- [ ] **Step 5: Write the list layer** — `server/fixtures/screens/enrollments-home.ts`

```ts
/**
 * enrollments-home layer (ui2-enrollments-browse D22): what the Enrollments list adds beyond base,
 * home-dashboard's history, groups-enroll-program's ended enrollment and enrollment-home.ts.
 *  - Upcoming: enrollment n 960 on the Prayer Team — "Walking Through John" (30 lessons, one a day from
 *    +5), created yesterday by Nathan Hughes. Base and every other layer have no upcoming enrollment.
 *  - Draft · 2/6: draft n 1 — Women's Bible Study + "Walking Through John", group and program only,
 *    started by Fixture Leader, last touched yesterday.
 *  - Draft · 6/6 read as 5/6 (D9 stale start): draft n 2 — Young Adults + "Foundations of Faith", every
 *    row set, its 21 lesson dates from 3 days ago, started by Nathan Hughes.
 * Never touches ctx.rand. Creates no org, user or group; wipe.ts removes the drafts and the enrollment
 * with their groups (cascade).
 */
import { lessonId } from '../base.js'
import { FIXTURE_TZ, type FixtureContext } from '../context.js'
import {
  FIXTURE_GROUP_IDS,
  FIXTURE_LEADER_GROUP_ID,
  FIXTURE_LEADER_USER_ID,
  FIXTURE_PROGRAM_IDS,
  FIXTURE_USER_ID,
  fixtureId,
} from '../ids.js'

export const UPCOMING_ENROLLMENT_ID = fixtureId('enrollment', 960)
export const UPCOMING_START_OFFSET = 5
const UPCOMING_LESSONS = 30
const UPCOMING_PROGRAM_INDEX = 2 // base PROGRAMS: days30 = index 2 "Walking Through John"
export const DRAFT_PARTIAL_ID = fixtureId('enrollmentDraft', 1)
export const DRAFT_STALE_ID = fixtureId('enrollmentDraft', 2)
export const DRAFT_STALE_START_OFFSET = -3
const DRAFT_STALE_LESSONS = 21
const ALL_WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const days = Array.from({ length: UPCOMING_LESSONS }, (_, i) => i + 1)
  const offsetOf = (day: number) => UPCOMING_START_OFFSET + day - 1
  await prisma.enrollment.create({
    data: {
      id: UPCOMING_ENROLLMENT_ID,
      groupId: FIXTURE_LEADER_GROUP_ID,
      studyProgramId: FIXTURE_PROGRAM_IDS.days30,
      startDate: ctx.at(offsetOf(1), 12),
      endDate: ctx.at(offsetOf(UPCOMING_LESSONS), 12),
      enabledDays: JSON.stringify(ALL_WEEKDAYS),
      smsTime: '08:00',
      timezone: FIXTURE_TZ,
      createdById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.daysAgo(1),
    },
  })
  await prisma.lessonSchedule.createMany({
    data: days.map((day) => ({
      id: fixtureId('schedule', 960_000 + day),
      enrollmentId: UPCOMING_ENROLLMENT_ID,
      lessonId: lessonId(UPCOMING_PROGRAM_INDEX, day),
      scheduledDate: ctx.at(offsetOf(day), 12),
      title: `Day ${day}`,
      estimatedMinutes: 25,
    })),
  })

  const staleDates = Array.from({ length: DRAFT_STALE_LESSONS }, (_, i) => ctx.dateOf(DRAFT_STALE_START_OFFSET + i))
  await prisma.enrollmentDraft.create({
    data: {
      id: DRAFT_PARTIAL_ID,
      groupId: FIXTURE_GROUP_IDS[2],
      studyProgramId: FIXTURE_PROGRAM_IDS.days30,
      createdById: FIXTURE_USER_ID,
      updatedById: FIXTURE_USER_ID,
      createdAt: ctx.at(-2, 10),
      updatedAt: ctx.at(-1, 15),
    },
  })
  await prisma.enrollmentDraft.create({
    data: {
      id: DRAFT_STALE_ID,
      groupId: FIXTURE_GROUP_IDS[1],
      studyProgramId: FIXTURE_PROGRAM_IDS.days21,
      startDate: staleDates[0],
      enabledDays: ALL_WEEKDAYS,
      overriddenDates: [],
      scheduleDates: staleDates,
      smsTime: '08:00',
      timezone: FIXTURE_TZ,
      syncMode: 'AUTO',
      lessonAccess: 'ONE_AT_A_TIME',
      createdById: FIXTURE_LEADER_USER_ID,
      updatedById: FIXTURE_LEADER_USER_ID,
      createdAt: ctx.at(-6, 9),
      updatedAt: ctx.at(-4, 18),
    },
  })
}
```

- [ ] **Step 6: Document it in `server/fixtures/README.md`** — in §Fixed IDs, change `` `001a` read blocks. `` to `` `001a` read blocks, `001b` enrollment drafts. ``; and after the §What `full` makes non-empty on Groups section add:

```markdown
### What `full` makes non-empty on Enrollments

`screens/enrollments-home.ts` + `screens/enrollment-home.ts` (ui2-enrollments-browse D22): the list's
Active reads base enrollments 2–4 plus the Prayer Team's "Foundations of Faith" (enrollment 950,
−10…+10, invite 07:30, three members, thumbnails on days 1–3 — the detail walk); Upcoming reads the
Prayer Team's "Walking Through John" from +5 (enrollment 960); Completed reads base enrollment 1,
home-dashboard's history and groups-enroll-program's "Romans in 12 Days"; Draft reads two drafts —
Women's Bible Study + "Walking Through John" (group and program only, `Draft · 2/6`, started by
Fixture Leader) and Young Adults + "Foundations of Faith" (every row set, lesson dates from 3 days
ago, so the app's stale-start rule reads `Draft · 5/6`, started by Nathan Hughes). The Prayer Team
makes Nathan Hughes the second group creator in the Leaders filter. Neither layer adds member
progress; base enrollment 4's progress (home-dashboard) is spread over days.
```

- [ ] **Step 7: Run it and watch it pass** — `cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npx vitest run fixtures/__tests__` → PASS, including every existing fixture DB suite (home-dashboard, groups-enroll-program, members, base); `cd server && npx tsc --noEmit -p fixtures` → no errors; then the whole server suite once: `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test DIRECT_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_ueb_test npm run test:run` → report the totals (any failure that also fails on the base commit is pre-existing — name it, don't fix it)

- [ ] **Step 8: Commit** — `git add server/fixtures/ids.ts server/fixtures/screens/enrollment-home.ts server/fixtures/screens/enrollments-home.ts server/fixtures/README.md server/fixtures/__tests__/enrollments-home.db.test.ts && git commit -m "feat(ui2-enrollments-browse): enrollments fixture layers (D22)"`

- [ ] **Step 9: Record the contract freeze** (the server half of §Contract is built and verified) — from the worktree root: `node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/advance.mjs docs/features/ui2-enrollments-browse --set "contract=frozen $(date +%F)" --head --commit "chore(ui2-enrollments-browse): contract frozen"` → `MANIFEST.md` reads `contract: frozen <today>` in its own commit

### Task 7: Draft wire type, EnrollmentDraft server fields, Draft ↔ EnrollmentDraft mapper and the PATCH body
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management (SPEC §iphone "Draft model", §Contract **Draft**, F7, T7, D9)

**Files:**
- Create: `iphone/MakeReady/State/Models/EnrollmentDraftWire.swift` — `EnrollmentWireRef`, `DraftWire` (§Contract Draft, verbatim field names)
- Create: `iphone/MakeReady/State/EnrollmentDraftMapping.swift` — wire ↔ local mapping, POST body, PATCH body
- Modify: `iphone/MakeReady/State/EnrollmentDraft.swift:6-40` — `serverId`, `createdByName`, `serverUpdatedAt`, `clearStaleStart(today:calendar:)`
- Modify: `iphone/MakeReady/State/Actions/EnrollmentActions.swift:15-45` — `EnrollmentWire.date(ymd:in:)`, `EnrollmentWire.lessonAccessLocal(_:)`
- Test: `iphone/MakeReadyCaptureTests/EnrollmentDraftWireTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the three new files (command in Steps 1 and 3; never hand-edit the pbxproj), then `ruby iphone/scripts/capture-targets.rb` re-syncs the MakeReadyCapture target

**Interfaces:**
- Consumes: `EnrollmentWire.dayNames: [String]`, `EnrollmentWire.dayNames(_: Set<Int>) -> [String]`, `EnrollmentWire.ymd(_:in:) -> String`, `EnrollmentWire.lessonAccessWire(_: String) -> String?` (existing, `EnrollmentActions.swift:15-45`); `EnrollmentDraft.init(id:groupId:studyProgramId:)`, `setProgram(_:)` (existing)
- Produces:
  - `struct EnrollmentWireRef: Codable, Equatable, Hashable { let id: String; let name: String? }`
  - `struct DraftWire: Codable, Equatable { id, groupId, studyProgramId: String; startDate: String?; enabledDays, overriddenDates, scheduleDates: [String]?; smsTime, timezone, syncMode, lessonAccess: String?; createdBy: EnrollmentWireRef?; createdAt, updatedAt: String }`
  - `EnrollmentDraft.serverId: String?`, `.createdByName: String?`, `.serverUpdatedAt: String?`
  - `@discardableResult mutating func EnrollmentDraft.clearStaleStart(today: Date, calendar: Calendar = .current) -> Bool`
  - `static func EnrollmentWire.date(ymd: String, in zone: TimeZone = .current) -> Date?`, `static func EnrollmentWire.lessonAccessLocal(_ wire: String?) -> String?`
  - `enum EnrollmentDraftMapping { static func draft(_ wire: DraftWire, flowId: UUID, zone: TimeZone = .current) -> EnrollmentDraft; static func createBody(_ d: EnrollmentDraft, zone: TimeZone = .current) -> [String: Any]; static func patchBody(from baseline: EnrollmentDraft, to current: EnrollmentDraft, zone: TimeZone = .current) -> [String: Any] }`

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/EnrollmentDraftWireTests.swift`, then register it in the test target (from the repo root):

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollmentDraftWireTests.swift", "MakeReadyCaptureTests"); p.save'
```

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse T7/F7: §Contract Draft ↔ the checklist's EnrollmentDraft, and the save bodies.
final class EnrollmentDraftWireTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!

    private func day(_ ymd: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone; f.dateFormat = "yyyy-MM-dd"
        return f.date(from: ymd)!
    }

    private let full = #"{"id":"d1","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08","enabledDays":["Mon","Wed"],"overriddenDates":["2035-01-10"],"scheduleDates":["2035-01-08","2035-01-15","2035-01-17"],"smsTime":"07:30","timezone":"America/Chicago","syncMode":"AUTO","lessonAccess":"ONE_AT_A_TIME","createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-02T00:00:00.000Z"}"#
    private let bare = #"{"id":"d2","groupId":"g1","studyProgramId":"p1","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":null,"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z"}"#

    private func decode(_ json: String) throws -> DraftWire {
        try JSONDecoder.apiDecoder.decode(DraftWire.self, from: Data(json.utf8))
    }

    func testAFullDraftMapsEveryField() throws {
        let id = UUID()
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: id, zone: zone)
        XCTAssertEqual(d.id, id)                                   // D21: the flow id stays local
        XCTAssertEqual(d.serverId, "d1")
        XCTAssertEqual(d.createdByName, "Luke Keith")
        XCTAssertEqual(d.serverUpdatedAt, "2035-01-02T00:00:00.000Z")
        XCTAssertEqual(d.groupId, "g1")
        XCTAssertEqual(d.studyProgramId, "p1")
        XCTAssertEqual(d.startDate, day("2035-01-08"))
        XCTAssertEqual(d.enabledDays, [1, 3])                      // Mon, Wed
        XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertEqual(d.scheduleDates, [day("2035-01-08"), day("2035-01-15"), day("2035-01-17")])
        XCTAssertEqual(d.smsTime, "07:30")
        XCTAssertEqual(d.timezone, "America/Chicago")
        XCTAssertEqual(d.syncMode, "AUTO")
        XCTAssertEqual(d.lessonAccess, "one-at-a-time")
        XCTAssertEqual(d.phase, .checklist)
    }

    func testNullsMapToNotChosen() throws {
        let d = EnrollmentDraftMapping.draft(try decode(bare), flowId: UUID(), zone: zone)
        XCTAssertNil(d.startDate)
        XCTAssertEqual(d.enabledDays, [])
        XCTAssertEqual(d.overriddenDates, [])
        XCTAssertEqual(d.scheduleDates, [])
        XCTAssertNil(d.endDate)
        XCTAssertNil(d.smsTime); XCTAssertNil(d.timezone); XCTAssertNil(d.syncMode); XCTAssertNil(d.lessonAccess)
        XCTAssertNil(d.createdByName)                               // F9: createdBy null → no starter
        XCTAssertFalse(d.scheduleDone)
    }

    func testEndDateIsDerivedFromTheLastScheduleDate() throws {  // F7
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        XCTAssertEqual(d.endDate, day("2035-01-17"))
    }

    func testCreateBodyRoundTripsTheWire() throws {
        let d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        let body = EnrollmentDraftMapping.createBody(d, zone: zone)
        XCTAssertEqual(body["groupId"] as? String, "g1")
        XCTAssertEqual(body["studyProgramId"] as? String, "p1")
        XCTAssertEqual(body["startDate"] as? String, "2035-01-08")
        XCTAssertEqual(body["enabledDays"] as? [String], ["Mon", "Wed"])
        XCTAssertEqual(body["overriddenDates"] as? [String], ["2035-01-10"])
        XCTAssertEqual(body["scheduleDates"] as? [String], ["2035-01-08", "2035-01-15", "2035-01-17"])
        XCTAssertEqual(body["smsTime"] as? String, "07:30")
        XCTAssertEqual(body["timezone"] as? String, "America/Chicago")
        XCTAssertEqual(body["syncMode"] as? String, "AUTO")
        XCTAssertEqual(body["lessonAccess"] as? String, "ONE_AT_A_TIME")
        XCTAssertNil(body["endDate"])                               // F7: never on the wire
    }

    func testCreateBodyOmitsUnsetFields() {
        let body = EnrollmentDraftMapping.createBody(EnrollmentDraft(id: UUID(), groupId: "g1", studyProgramId: "p1"), zone: zone)
        XCTAssertEqual(Set(body.keys), ["groupId", "studyProgramId"])
    }

    func testPatchSendsOnlyChangedKeysWithExplicitNulls() throws {
        let base = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        var next = base
        next.smsTime = "08:00"
        next.syncMode = nil
        let body = EnrollmentDraftMapping.patchBody(from: base, to: next, zone: zone)
        XCTAssertEqual(Set(body.keys), ["smsTime", "syncMode"])
        XCTAssertEqual(body["smsTime"] as? String, "08:00")
        XCTAssertTrue(body["syncMode"] is NSNull)
        XCTAssertTrue(EnrollmentDraftMapping.patchBody(from: base, to: base, zone: zone).isEmpty)
    }

    func testAProgramChangeAlwaysSendsScheduleDatesNull() throws {   // D4 + D23
        let base = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        var next = base
        next.setProgram("p2")
        let body = EnrollmentDraftMapping.patchBody(from: base, to: next, zone: zone)
        XCTAssertEqual(body["studyProgramId"] as? String, "p2")
        XCTAssertTrue(body["scheduleDates"] is NSNull)
        XCTAssertNil(body["startDate"])                              // start / weekdays / overrides kept
        // D23: the local schedule was already cleared, the server's was not — still null.
        var cleared = base
        cleared.scheduleDates = []; cleared.startDate = nil; cleared.endDate = nil
        var moved = cleared
        moved.setProgram("p3")
        XCTAssertTrue(EnrollmentDraftMapping.patchBody(from: cleared, to: moved, zone: zone)["scheduleDates"] is NSNull)
    }

    func testStaleStartClearsOnlyTheSchedule() throws {               // D9
        var cal = Calendar(identifier: .gregorian); cal.timeZone = zone
        var d = EnrollmentDraftMapping.draft(try decode(full), flowId: UUID(), zone: zone)
        XCTAssertFalse(d.clearStaleStart(today: day("2035-01-08"), calendar: cal))   // first date is today: kept
        XCTAssertTrue(d.scheduleDone)
        XCTAssertTrue(d.clearStaleStart(today: day("2035-01-09"), calendar: cal))
        XCTAssertNil(d.startDate); XCTAssertEqual(d.scheduleDates, []); XCTAssertNil(d.endDate)
        XCTAssertEqual(d.enabledDays, [1, 3]); XCTAssertEqual(d.overriddenDates, [day("2035-01-10")])
        XCTAssertEqual(d.smsTime, "07:30")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` (repo root) → FAIL to compile, "cannot find type 'DraftWire' in scope" / "cannot find 'EnrollmentDraftMapping' in scope"

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/State/Models/EnrollmentDraftWire.swift`:

```swift
import Foundation

/// ui2-enrollments-browse §Contract: a `{id, name}` reference — a draft's `createdBy`, a feed
/// group's `leader`, a feed filter option. `name` is optional so a null never fails the decode.
struct EnrollmentWireRef: Codable, Equatable, Hashable {
    let id: String
    let name: String?
}

/// ui2-enrollments-browse §Contract **Draft** — the server row behind a checklist (SC1). Unset
/// fields are null; dates are `yyyy-MM-dd`; `createdAt`/`updatedAt` stay ISO text (compared as text,
/// the server writes one format).
struct DraftWire: Codable, Equatable {
    let id: String
    let groupId: String
    let studyProgramId: String
    let startDate: String?
    let enabledDays: [String]?
    let overriddenDates: [String]?
    let scheduleDates: [String]?
    let smsTime: String?
    let timezone: String?
    let syncMode: String?
    let lessonAccess: String?
    let createdBy: EnrollmentWireRef?
    let createdAt: String
    let updatedAt: String
}
```

`iphone/MakeReady/State/EnrollmentDraft.swift` — add inside `struct EnrollmentDraft`, after `var phase`:

```swift
    /// ui2-enrollments-browse D21: the server draft backing this flow — nil until D3's POST or a resume.
    var serverId: String?
    /// D7: `Draft.createdBy.name`; nil = no starter line (F9).
    var createdByName: String?
    /// D21: the server row's `updatedAt` this flow was last seeded from or saved to.
    var serverUpdatedAt: String?

    /// D9/D23: a schedule whose first date is before today counts as not done — start, dates and
    /// end clear; weekdays and overrides stay as the picker's seed. Local only: sends nothing.
    @discardableResult
    mutating func clearStaleStart(today: Date, calendar: Calendar = .current) -> Bool {
        guard let first = scheduleDates.first, first < calendar.startOfDay(for: today) else { return false }
        startDate = nil
        scheduleDates = []
        endDate = nil
        return true
    }
```

`iphone/MakeReady/State/Actions/EnrollmentActions.swift` — add inside `enum EnrollmentWire` (after `ymd`, it reuses the private `ymdFormatter`):

```swift
    /// T7: a `yyyy-MM-dd` wire day as the start of that day in `zone`.
    static func date(ymd: String, in zone: TimeZone = .current) -> Date? {
        ymdFormatter.timeZone = zone
        return ymdFormatter.date(from: ymd)
    }

    /// T7: the server enum → the screen's kebab value (nil = not chosen).
    static func lessonAccessLocal(_ wire: String?) -> String? {
        switch wire {
        case "ONE_AT_A_TIME": return "one-at-a-time"
        case "ALL_AT_ONCE": return "all-at-once"
        default: return nil
        }
    }
```

`iphone/MakeReady/State/EnrollmentDraftMapping.swift`:

```swift
import Foundation

/// ui2-enrollments-browse T7/F7: §Contract Draft ↔ `EnrollmentDraft`, written once. Dates are
/// `yyyy-MM-dd` in `zone` (the device's), weekdays names ↔ 0…6, access kebab ↔ enum, sync as is;
/// `endDate` is derived from the last schedule date and never sent. An empty set or list is null.
enum EnrollmentDraftMapping {
    static func draft(_ wire: DraftWire, flowId: UUID, zone: TimeZone = .current) -> EnrollmentDraft {
        var d = EnrollmentDraft(id: flowId, groupId: wire.groupId, studyProgramId: wire.studyProgramId)
        d.serverId = wire.id
        d.createdByName = wire.createdBy?.name
        d.serverUpdatedAt = wire.updatedAt
        d.startDate = wire.startDate.flatMap { EnrollmentWire.date(ymd: $0, in: zone) }
        d.enabledDays = Set((wire.enabledDays ?? []).compactMap { EnrollmentWire.dayNames.firstIndex(of: $0) })
        d.overriddenDates = Set((wire.overriddenDates ?? []).compactMap { EnrollmentWire.date(ymd: $0, in: zone) })
        d.scheduleDates = (wire.scheduleDates ?? []).compactMap { EnrollmentWire.date(ymd: $0, in: zone) }
        d.endDate = d.scheduleDates.last
        d.smsTime = wire.smsTime
        d.timezone = wire.timezone
        d.syncMode = wire.syncMode
        d.lessonAccess = EnrollmentWire.lessonAccessLocal(wire.lessonAccess)
        return d
    }

    /// One field's wire value, comparable so a PATCH sends only what changed.
    enum FieldValue: Equatable {
        case null, text(String), list([String])
        var json: Any {
            switch self {
            case .null: return NSNull()
            case .text(let s): return s
            case .list(let l): return l
            }
        }
    }

    /// The §Contract PATCH fields, in a fixed order.
    static let fieldKeys = ["groupId", "studyProgramId", "startDate", "enabledDays", "overriddenDates",
                            "scheduleDates", "smsTime", "timezone", "syncMode", "lessonAccess"]

    static func fieldValues(_ d: EnrollmentDraft, zone: TimeZone = .current) -> [String: FieldValue] {
        func text(_ s: String?) -> FieldValue { s.map(FieldValue.text) ?? .null }
        func list(_ l: [String]) -> FieldValue { l.isEmpty ? .null : .list(l) }
        return [
            "groupId": text(d.groupId),
            "studyProgramId": text(d.studyProgramId),
            "startDate": text(d.startDate.map { EnrollmentWire.ymd($0, in: zone) }),
            "enabledDays": list(EnrollmentWire.dayNames(d.enabledDays)),
            "overriddenDates": list(d.overriddenDates.sorted().map { EnrollmentWire.ymd($0, in: zone) }),
            "scheduleDates": list(d.scheduleDates.map { EnrollmentWire.ymd($0, in: zone) }),
            "smsTime": text(d.smsTime),
            "timezone": text(d.timezone),
            "syncMode": text(d.syncMode),
            "lessonAccess": text(d.lessonAccess.flatMap(EnrollmentWire.lessonAccessWire))
        ]
    }

    /// D3: the first save — both ids and every field already set (unset fields are left out).
    static func createBody(_ d: EnrollmentDraft, zone: TimeZone = .current) -> [String: Any] {
        fieldValues(d, zone: zone).filter { $0.value != .null }.mapValues(\.json)
    }

    /// D4: only the keys whose wire value differs from `baseline`; a cleared value is an explicit
    /// null. A program change always carries `scheduleDates: null` — the local cascade cleared the
    /// dates, and after D23's local-only clear the server may still hold the old ones.
    static func patchBody(from baseline: EnrollmentDraft, to current: EnrollmentDraft,
                          zone: TimeZone = .current) -> [String: Any] {
        let old = fieldValues(baseline, zone: zone)
        let new = fieldValues(current, zone: zone)
        var body: [String: Any] = [:]
        for key in fieldKeys where old[key] != new[key] {
            body[key] = new[key]?.json
        }
        if body["studyProgramId"] != nil, new["scheduleDates"] == .null {
            body["scheduleDates"] = NSNull()
        }
        return body
    }
}
```

Register the two new app files in the MakeReady target and re-sync the capture target (repo root):

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReady/State/Models", "EnrollmentDraftWire.swift", "MakeReady"); add.("MakeReady/State", "EnrollmentDraftMapping.swift", "MakeReady"); p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (EnrollmentDraftWireTests 8/8, EnrollmentDraftTests unchanged); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): Draft wire type and the Draft ↔ EnrollmentDraft mapper (T7, F7)`

### Task 8: AppState stores, EnrollmentDraftActions, feed and home loads, draftId on Enroll
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management (SPEC §iphone "Store" + "Actions", §Contract Item/sections/options/Home, D6, D11, D24, D30) · `/ios-error-surface` for the status mapping

**Files:**
- Create: `iphone/MakeReady/State/Models/EnrollmentBrowseModels.swift` — feed filter, feed, Item, sections, options, Home (§Contract verbatim)
- Create: `iphone/MakeReady/State/Actions/EnrollmentDraftActions.swift`
- Modify: `iphone/MakeReady/State/AppState.swift:454-477` (draft MARK: new stores + helpers; `endEnrollmentDraft`/`pruneEnrollmentDrafts` drop baselines) and `:870-930` (`clearInMemory` clears the new stores)
- Modify: `iphone/MakeReady/State/Actions/EnrollmentActions.swift:245-330` — `createEnrollment(… draftId:)`, plus `loadFeed`, `loadHome`
- Modify: `iphone/MakeReady/State/API/APIClient.swift:45-55,228-233` — `APIHTTPError.details` (a 409's `draftId`), equality on status + message only
- Test: `iphone/MakeReadyCaptureTests/EnrollmentBrowseActionsTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the new files (commands in Steps 1 and 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes (Task 7): `DraftWire`, `EnrollmentWireRef`, `EnrollmentDraftMapping.draft(_:flowId:zone:)`, `EnrollmentDraft.serverId`; existing `StubAPIClient` (`responses`, `errorFor`, `beforeReturn`, `delayFor`, `calls`, `callCount`), `APIClientProtocol.requestWithStatus(endpoint:method:body:)`, `APIHTTPError`, `JSONDecoder.apiDecoder`
- Produces:
  - `APIHTTPError.details: [String: String]` (default `[:]`; every string field of the error body except `error`); `==` compares `status` and `message` only
  - `struct EnrollmentFeedFilter: Hashable { var orgId: String?; var groupId: String?; var leaderId: String?; var status: Status = .active; func path(timeZone: TimeZone) -> String }`, `enum EnrollmentFeedFilter.Status: String, CaseIterable { active, upcoming, completed, draft, all; var label: String }`
  - `struct EnrollmentFeedProgram: Decodable, Equatable { id, name: String; coverImageUrl: String? }`
  - `struct EnrollmentFeedSection: Decodable, Equatable { let group: GroupRef; let items: [EnrollmentFeedItem] }`, `EnrollmentFeedSection.GroupRef { id, name: String; coverImageUrl: String?; leader: EnrollmentWireRef? }`
  - `struct EnrollmentFeedItem: Decodable, Equatable { kind: String; id: String?; draft: DraftWire?; studyProgram: EnrollmentFeedProgram; startDate, endDate, enrolledAt: String?; progress: Double?; completedMembers, memberCount, plannedMinutes: Int?; recencyAt: String }`
  - `struct EnrollmentFeedOptions: Decodable, Equatable { groups, leaders: [EnrollmentWireRef] }`, `struct EnrollmentFeed: Equatable { sections: [EnrollmentFeedSection]; options: EnrollmentFeedOptions }`
  - `struct EnrollmentHome: Decodable, Equatable` with `ProgramRef`, `GroupRef`, `Day`, `Lesson`, `Activity` (fields in Step 3) and `static func path(id: String, timeZone: TimeZone) -> String`
  - `AppState.enrollmentDraftsByGroupId: [String: [DraftWire]]`, `.enrollmentFeed: [EnrollmentFeedFilter: EnrollmentFeed]`, `.enrollmentHomes: [String: EnrollmentHome]`, `.enrollmentDraftBaselines: [UUID: EnrollmentDraft]`
  - `@discardableResult func AppState.seedEnrollmentDraft(_ wire: DraftWire, flowId: UUID? = nil) -> UUID`, `func enrollmentFlowId(forServerId: String) -> UUID?`, `func upsertEnrollmentDraftWire(_: DraftWire)`, `func removeEnrollmentDraftWire(id: String)`, `func removeEnrollmentDrafts(groupId: String, studyProgramId: String)`
  - `enum DraftWriteOutcome: Equatable { case saved(DraftWire); case exists(draftId: String) }`
  - `struct EnrollmentDraftActions { init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil); create(body:) async throws -> DraftWriteOutcome; update(id:body:) async throws -> DraftWriteOutcome; load(id:) async throws -> DraftWire; listByGroup(groupId:) async throws; delete(id:) async throws; forget(id:) }` (all `@MainActor`)
  - `EnrollmentActions.loadFeed(filter: EnrollmentFeedFilter, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws`, `loadHome(id: String, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws`, `createEnrollment(…, lessonAccess: String? = nil, draftId: String? = nil)`

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/EnrollmentBrowseActionsTests.swift` and register it:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollmentBrowseActionsTests.swift", "MakeReadyCaptureTests"); p.save'
```

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse §iphone Store/Actions: drafts, the feed and the home read; memory-only stores.
@MainActor
final class EnrollmentBrowseActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let chicago = TimeZone(identifier: "America/Chicago")!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func wire(_ id: String, group: String = "g1", program: String = "p1",
                      updated: String = "2035-01-02T00:00:00.000Z") -> DraftWire {
        DraftWire(id: id, groupId: group, studyProgramId: program, startDate: nil, enabledDays: nil,
                  overriddenDates: nil, scheduleDates: nil, smsTime: nil, timezone: nil, syncMode: nil,
                  lessonAccess: nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: updated)
    }

    /// One §Contract Draft object.
    private func draftObject(_ id: String, group: String = "g1", program: String = "p1",
                             updated: String = "2035-01-02T00:00:00.000Z") -> String {
        #"{"id":"\#(id)","groupId":"\#(group)","studyProgramId":"\#(program)","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"\#(updated)"}"#
    }

    /// `{success, draft}`.
    private func draftJSON(_ id: String, group: String = "g1", program: String = "p1",
                           updated: String = "2035-01-02T00:00:00.000Z") -> String {
        #"{"success":true,"draft":\#(draftObject(id, group: group, program: program, updated: updated))}"#
    }

    private var drafts: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }
    private func anyFeed() -> EnrollmentFeed { EnrollmentFeed(sections: [], options: EnrollmentFeedOptions(groups: [], leaders: [])) }

    // MARK: drafts

    func testCreateStoresTheDraftUnderItsGroupAndDropsTheFeed() async throws {
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        let outcome = try await drafts.create(body: ["groupId": "g1", "studyProgramId": "p1"])
        XCTAssertEqual(outcome, .saved(wire("d1")))
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    func testAConflictReturnsTheExistingDraftId() async throws {        // D6
        api.errorFor = { _, _ in APIHTTPError(status: 409, message: "draft_exists", details: ["draftId": "d9"]) }
        let outcome = try await drafts.create(body: ["groupId": "g1", "studyProgramId": "p1"])
        XCTAssertEqual(outcome, .exists(draftId: "d9"))
        let patched = try await drafts.update(id: "d1", body: ["groupId": "g2"])
        XCTAssertEqual(patched, .exists(draftId: "d9"))
    }

    func testStatusErrorKeepsTheBodysDraftId() {
        let data = Data(#"{"success":false,"error":"draft_exists","draftId":"d9"}"#.utf8)
        let error = APIClient.statusError(status: 409, data: data) as? APIHTTPError
        XCTAssertEqual(error?.details["draftId"], "d9")
        XCTAssertEqual(error, APIHTTPError(status: 409, message: "draft_exists"))   // details are not identity
    }

    func testAGroupChangeMovesTheDraftBetweenBothGroupsLists() async throws {
        state.enrollmentDraftsByGroupId = ["g1": [wire("d1"), wire("d0")], "g2": [wire("d5", group: "g2", updated: "2035-01-01T00:00:00.000Z")]]
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", group: "g2", updated: "2035-01-03T00:00:00.000Z"))
        _ = try await drafts.update(id: "d1", body: ["groupId": "g2"])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d0"])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g2"]?.map(\.id), ["d1", "d5"])   // newest updatedAt first
    }

    func testDeleteRemovesTheDraftAndDropsTheFeed() async throws {
        state.enrollmentDraftsByGroupId = ["g1": [wire("d1")]]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        api.stub("DELETE", "/api/enrollment-drafts/d1", json: #"{"success":true}"#)
        try await drafts.delete(id: "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    func testA404KeepsItsStatus() async {                                // D30 needs the status
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        do { _ = try await drafts.load(id: "d1"); XCTFail("expected a throw") } catch {
            XCTAssertEqual((error as? APIHTTPError)?.status, 404)
        }
    }

    func testListByGroupStoresTheServersOrder() async throws {
        api.stub("GET", "/api/enrollment-drafts?groupId=g1",
                 json: #"{"success":true,"drafts":[\#(draftObject("d2")),\#(draftObject("d1"))]}"#)
        try await drafts.listByGroup(groupId: "g1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d2", "d1"])
    }

    func testSeedAndFindTheFlowOfAServerDraft() {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        XCTAssertEqual(state.enrollmentDrafts[flow]?.serverId, "d1")
        XCTAssertEqual(state.enrollmentDraftBaselines[flow], state.enrollmentDrafts[flow])
        XCTAssertEqual(state.enrollmentFlowId(forServerId: "d1"), flow)
        XCTAssertNil(state.enrollmentFlowId(forServerId: "d2"))
        state.seedEnrollmentDraft(wire("d7", program: "p7"), flowId: flow)      // D6: in place
        XCTAssertEqual(state.enrollmentDrafts[flow]?.serverId, "d7")
        XCTAssertEqual(state.enrollmentDrafts.count, 1)
        state.endEnrollmentDraft(flow)
        XCTAssertNil(state.enrollmentDraftBaselines[flow])
    }

    // MARK: feed + home

    private let feedJSON = #"{"success":true,"sections":[{"group":{"id":"g1","name":"Young Professionals","coverImageUrl":null,"leader":{"id":"u1","name":"Luke Keith"}},"items":[{"kind":"enrollment","id":"e1","studyProgram":{"id":"p1","name":"Romans","coverImageUrl":"https://x/p1.png"},"startDate":"2035-01-08","endDate":"2035-02-01","enrolledAt":"2035-01-01T15:00:00.000Z","progress":0.5,"completedMembers":3,"memberCount":12,"plannedMinutes":90,"recencyAt":"2035-01-05T00:00:00.000Z"},{"kind":"draft","draft":{"id":"d1","groupId":"g1","studyProgramId":"p2","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":null,"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-04T00:00:00.000Z"},"studyProgram":{"id":"p2","name":"John","coverImageUrl":null},"recencyAt":"2035-01-04T00:00:00.000Z"}]}],"options":{"groups":[{"id":"g1","name":"Young Professionals"}],"leaders":[{"id":"u1","name":"Luke Keith"}]}}"#

    func testFeedPathCarriesTheFilterAndTheDeviceZone() {
        XCTAssertEqual(EnrollmentFeedFilter().path(timeZone: chicago), "/api/enrollments-feed?status=active&tz=America/Chicago")
        XCTAssertEqual(EnrollmentFeedFilter(orgId: "o1", groupId: "g1", leaderId: "u1", status: .draft).path(timeZone: chicago),
                       "/api/enrollments-feed?orgId=o1&groupId=g1&leaderId=u1&status=draft&tz=America/Chicago")
        XCTAssertEqual(EnrollmentFeedFilter.Status.allCases.map(\.label), ["Active", "Upcoming", "Completed", "Draft", "All"])
    }

    func testLoadFeedDecodesAndIsCacheFirst() async throws {
        api.stub("GET", "/api/enrollments-feed?status=active&tz=America/Chicago", json: feedJSON)
        let actions = EnrollmentActions(api: api, state: state)
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), timeZone: chicago)
        let feed = try XCTUnwrap(state.enrollmentFeed[EnrollmentFeedFilter()])
        XCTAssertEqual(feed.sections.first?.group.leader?.name, "Luke Keith")
        XCTAssertEqual(feed.sections.first?.items.map(\.kind), ["enrollment", "draft"])
        XCTAssertEqual(feed.sections.first?.items.last?.draft?.id, "d1")
        XCTAssertEqual(feed.options.leaders.map(\.id), ["u1"])
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), timeZone: chicago)
        XCTAssertEqual(api.calls.count, 1)                                     // cached
        try await actions.loadFeed(filter: EnrollmentFeedFilter(), forceRefresh: true, timeZone: chicago)
        XCTAssertEqual(api.calls.count, 2)
    }

    func testLoadHomeDecodes() async throws {
        api.stub("GET", "/api/enrollments/e1/home?tz=America/Chicago", json: #"{"success":true,"home":{"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":"Paul's letter","coverImageUrl":null,"authorName":"Jonathan Edwards"},"group":{"id":"g1","name":"Young Professionals","leader":{"id":"u1","name":"Tony Stark"}},"memberCount":17,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-03-10","lessonAccess":"ALL_AT_ONCE","smsTime":"07:30","timezone":"America/Chicago","days":[{"scheduleId":"s1","date":"2035-01-08","percent":78,"lessonCount":1,"plannedMinutes":15}],"lessons":[{"scheduleId":"s1","dayNumber":1,"title":"It is evident","date":"2035-01-08","progress":0.69,"activities":[{"id":"a1","type":"READ","title":"Romans 1","thumbnailUrl":"https://x/a1.png"}]}]}}"#)
        try await EnrollmentActions(api: api, state: state).loadHome(id: "e1", timeZone: chicago)
        let home = try XCTUnwrap(state.enrollmentHomes["e1"])
        XCTAssertEqual(home.group.leader?.name, "Tony Stark")
        XCTAssertEqual(home.days.first?.percent, 78)
        XCTAssertEqual(home.lessons.first?.activities.first?.thumbnailUrl, "https://x/a1.png")
        XCTAssertEqual(home.smsTime, "07:30")
    }

    // MARK: enroll (D11/D24)

    func testCreateEnrollmentSendsDraftIdAndRemovesThePairsDrafts() async throws {
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollments" ? nil : APIError.serverError("refresh not stubbed") }
        api.stub("POST", "/api/enrollments", json: #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-12T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#)
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1", program: "p1"), wire("d2", program: "p2")]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        _ = try await EnrollmentActions(api: api, state: state).createEnrollment(
            groupId: "g1", studyProgramId: "p1", startDate: Date(timeIntervalSince1970: 2_051_222_400),
            enabledDays: ["Mon"], smsTime: "07:30", timezone: "America/Chicago", draftId: "d1")
        XCTAssertEqual(api.calls.first { $0.endpoint == "/api/enrollments" }?.body?["draftId"] as? String, "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d2"])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
    }

    func testClearAllDataClearsTheNewStores() {
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        state.enrollmentFeed[EnrollmentFeedFilter()] = anyFeed()
        _ = state.seedEnrollmentDraft(wire("d1"))
        state.clearAllData()
        XCTAssertTrue(state.enrollmentDraftsByGroupId.isEmpty)
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
        XCTAssertTrue(state.enrollmentHomes.isEmpty)
        XCTAssertTrue(state.enrollmentDraftBaselines.isEmpty)
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "cannot find 'EnrollmentDraftActions' in scope", "extra argument 'details' in call", "value of type 'AppState' has no member 'enrollmentFeed'"

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/State/API/APIClient.swift` — replace the `APIHTTPError` struct and the last two lines of `statusError`:

```swift
struct APIHTTPError: LocalizedError, Equatable {
    let status: Int
    /// The response body's `error` string, when it carried one.
    let message: String?
    /// ui2-enrollments-browse D6: the body's other string fields (a 409 `draft_exists` carries
    /// `draftId`). Not part of equality — two errors are the same status and message.
    var details: [String: String] = [:]

    var errorDescription: String? { message ?? "Server returned status \(status)" }

    static func == (lhs: APIHTTPError, rhs: APIHTTPError) -> Bool {
        lhs.status == rhs.status && lhs.message == rhs.message
    }
}
```

```swift
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let details = (json ?? [:]).compactMapValues { $0 as? String }.filter { $0.key != "error" }
        return APIHTTPError(status: status, message: json?["error"] as? String, details: details)
```

`iphone/MakeReady/State/Models/EnrollmentBrowseModels.swift`:

```swift
import Foundation

/// ui2-enrollments-browse §Contract `GET /api/enrollments-feed` query (D8, D13, D15; no `q` — D27).
/// The `AppState.enrollmentFeed` key: one cached answer per filter.
struct EnrollmentFeedFilter: Hashable {
    enum Status: String, CaseIterable {
        case active, upcoming, completed, draft, all
        /// D8: the chip and menu text, in the menu's order.
        var label: String {
            switch self {
            case .active: return "Active"
            case .upcoming: return "Upcoming"
            case .completed: return "Completed"
            case .draft: return "Draft"
            case .all: return "All"
            }
        }
    }

    var orgId: String?
    var groupId: String?
    var leaderId: String?
    var status: Status = .active

    /// The request path; `tz` is the device zone (D8's "today").
    func path(timeZone: TimeZone) -> String {
        var c = URLComponents()
        c.path = "/api/enrollments-feed"
        c.queryItems = [
            orgId.map { URLQueryItem(name: "orgId", value: $0) },
            groupId.map { URLQueryItem(name: "groupId", value: $0) },
            leaderId.map { URLQueryItem(name: "leaderId", value: $0) },
            URLQueryItem(name: "status", value: status.rawValue),
            URLQueryItem(name: "tz", value: timeZone.identifier)
        ].compactMap { $0 }
        return c.string ?? c.path
    }
}

/// §Contract Item's `studyProgram`.
struct EnrollmentFeedProgram: Decodable, Equatable {
    let id: String
    let name: String
    let coverImageUrl: String?
}

/// §Contract **Item** — `kind` "enrollment" (the numbers set) or "draft" (`draft` set).
/// Dates are `yyyy-MM-dd` in the enrollment's zone; `enrolledAt`/`recencyAt` ISO instants.
struct EnrollmentFeedItem: Decodable, Equatable {
    let kind: String
    let id: String?
    let draft: DraftWire?
    let studyProgram: EnrollmentFeedProgram
    let startDate: String?
    let endDate: String?
    let enrolledAt: String?
    let progress: Double?
    let completedMembers: Int?
    let memberCount: Int?
    let plannedMinutes: Int?
    let recencyAt: String
}

/// §Contract `sections[]` — one group (D7, D13) and its items, ordered per D17.
struct EnrollmentFeedSection: Decodable, Equatable {
    struct GroupRef: Decodable, Equatable {
        let id: String
        let name: String
        let coverImageUrl: String?
        let leader: EnrollmentWireRef?
    }
    let group: GroupRef
    let items: [EnrollmentFeedItem]
}

/// §Contract `options` — over scope + orgId + status, never narrowed by group or leader.
struct EnrollmentFeedOptions: Decodable, Equatable {
    let groups: [EnrollmentWireRef]
    let leaders: [EnrollmentWireRef]
}

/// One feed answer, stored per `EnrollmentFeedFilter`.
struct EnrollmentFeed: Equatable {
    let sections: [EnrollmentFeedSection]
    let options: EnrollmentFeedOptions
}

/// §Contract **Home** — `GET /api/enrollments/:id/home` (D20).
struct EnrollmentHome: Decodable, Equatable {
    struct ProgramRef: Decodable, Equatable {
        let id: String
        let name: String
        let description: String?
        let coverImageUrl: String?
        let authorName: String?
    }
    struct GroupRef: Decodable, Equatable {
        let id: String
        let name: String
        let leader: EnrollmentWireRef?
    }
    struct Day: Decodable, Equatable {
        let scheduleId: String
        let date: String
        let percent: Double
        let lessonCount: Int
        let plannedMinutes: Int
    }
    struct Activity: Decodable, Equatable {
        let id: String
        let type: String
        let title: String?
        let thumbnailUrl: String?
    }
    struct Lesson: Decodable, Equatable {
        let scheduleId: String
        let dayNumber: Int
        let title: String?
        let date: String
        let progress: Double?
        let activities: [Activity]
    }

    let id: String
    let studyProgram: ProgramRef
    let group: GroupRef
    let memberCount: Int
    let enrolledAt: String
    let startDate: String
    let endDate: String
    let lessonAccess: String?
    let smsTime: String?
    let timezone: String?
    let days: [Day]
    let lessons: [Lesson]

    static func path(id: String, timeZone: TimeZone) -> String {
        var c = URLComponents()
        c.path = "/api/enrollments/\(id)/home"
        c.queryItems = [URLQueryItem(name: "tz", value: timeZone.identifier)]
        return c.string ?? c.path
    }
}
```

`iphone/MakeReady/State/AppState.swift` — under the `// MARK: - Enrollment drafts` block, add the stores and helpers, and make `endEnrollmentDraft`/`pruneEnrollmentDrafts` drop the baseline too:

```swift
    // MARK: ui2-enrollments-browse — enrollment stores (memory-only: never PersistedState;
    // `clearInMemory()` empties them)

    /// `GET /api/enrollment-drafts?groupId=`, by group, newest `updatedAt` first (ISO text compares
    /// in time order — the server writes one format). Kept current by EnrollmentDraftActions and an enroll.
    var enrollmentDraftsByGroupId: [String: [DraftWire]] = [:]
    /// `GET /api/enrollments-feed`, one answer per filter. Every draft or enrollment mutation drops it whole.
    var enrollmentFeed: [EnrollmentFeedFilter: EnrollmentFeed] = [:]
    /// `GET /api/enrollments/:id/home`, by enrollment id (D20).
    var enrollmentHomes: [String: EnrollmentHome] = [:]
    /// D4: per flow, the draft as the server last acknowledged it — the PATCH diff's base.
    var enrollmentDraftBaselines: [UUID: EnrollmentDraft] = [:]

    /// D21: a flow seeded from a server draft — a new flow, or `flowId` overwritten in place (D6).
    @discardableResult
    func seedEnrollmentDraft(_ wire: DraftWire, flowId: UUID? = nil) -> UUID {
        let id = flowId ?? UUID()
        let draft = EnrollmentDraftMapping.draft(wire, flowId: id)
        enrollmentDrafts[id] = draft
        enrollmentDraftBaselines[id] = draft
        return id
    }

    /// D21: the open flow already backed by server draft `serverId`.
    func enrollmentFlowId(forServerId serverId: String) -> UUID? {
        enrollmentDrafts.first { $0.value.serverId == serverId }?.key
    }

    /// The draft leaves every group's list and joins its own (a group change moves it), newest first.
    func upsertEnrollmentDraftWire(_ wire: DraftWire) {
        removeEnrollmentDraftWire(id: wire.id)
        var list = enrollmentDraftsByGroupId[wire.groupId] ?? []
        list.append(wire)
        enrollmentDraftsByGroupId[wire.groupId] = list.sorted { $0.updatedAt > $1.updatedAt }
    }

    func removeEnrollmentDraftWire(id: String) {
        for (groupId, list) in enrollmentDraftsByGroupId where list.contains(where: { $0.id == id }) {
            enrollmentDraftsByGroupId[groupId] = list.filter { $0.id != id }
        }
    }

    /// D11/D24: an enroll deletes the pair's drafts on the server.
    func removeEnrollmentDrafts(groupId: String, studyProgramId: String) {
        guard let list = enrollmentDraftsByGroupId[groupId] else { return }
        enrollmentDraftsByGroupId[groupId] = list.filter { $0.studyProgramId != studyProgramId }
    }
```

```swift
    func endEnrollmentDraft(_ id: UUID) {
        enrollmentDrafts[id] = nil
        enrollmentDraftBaselines[id] = nil
    }

    /// D13: a flow whose checklist left every stack (back-swipe, Home re-tap) loses its LOCAL draft.
    /// ui2-enrollments-browse D2/R4: never a server request — a saved draft stays on the server.
    func pruneEnrollmentDrafts(keeping ids: Set<UUID>) {
        enrollmentDrafts = enrollmentDrafts.filter { ids.contains($0.key) }
        enrollmentDraftBaselines = enrollmentDraftBaselines.filter { ids.contains($0.key) }
    }
```

and in `clearInMemory()`, after `enrollmentDrafts = [:]`:

```swift
        // ui2-enrollments-browse: memory-only stores, org-scoped — die with the session.
        enrollmentDraftsByGroupId = [:]
        enrollmentFeed = [:]
        enrollmentHomes = [:]
        enrollmentDraftBaselines = [:]
```

`iphone/MakeReady/State/Actions/EnrollmentDraftActions.swift`:

```swift
import Foundation

/// ui2-enrollments-browse D6: a draft write's result — saved, or the pair already has a draft.
enum DraftWriteOutcome: Equatable {
    case saved(DraftWire)
    case exists(draftId: String)
}

/// ui2-enrollments-browse SC2: `/api/enrollment-drafts`. Every call keeps the HTTP status
/// (`requestWithStatus`) so callers see 404 (D30) and 409 (D6). Writes refresh
/// `enrollmentDraftsByGroupId` (both groups on a group change) and drop `enrollmentFeed` in the same call.
struct EnrollmentDraftActions {
    private let api: APIClientProtocol
    private let stateOverride: AppState?

    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    private struct One: Decodable { let success: Bool; let draft: DraftWire }
    private struct Many: Decodable { let success: Bool; let drafts: [DraftWire] }

    /// D3: the first save. 409 → `.exists` with the pair's draft id.
    @MainActor
    func create(body: [String: Any]) async throws -> DraftWriteOutcome {
        try await write("POST", "/api/enrollment-drafts", body)
    }

    /// D4: the changed fields. 409 (pair move onto another draft) → `.exists`.
    @MainActor
    func update(id: String, body: [String: Any]) async throws -> DraftWriteOutcome {
        try await write("PATCH", "/api/enrollment-drafts/\(id)", body)
    }

    /// D21 resume / D6 re-seed.
    @MainActor
    func load(id: String) async throws -> DraftWire {
        let data = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts/\(id)", method: "GET", body: nil)
        let wire = try decode(One.self, data).draft
        state.upsertEnrollmentDraftWire(wire)
        return wire
    }

    /// D7b: the group page's drafts, in the server's order (newest `updatedAt` first).
    @MainActor
    func listByGroup(groupId: String) async throws {
        let data = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts?groupId=\(groupId)", method: "GET", body: nil)
        state.enrollmentDraftsByGroupId[groupId] = try decode(Many.self, data).drafts
    }

    /// D10: Discard.
    @MainActor
    func delete(id: String) async throws {
        _ = try await api.requestWithStatus(endpoint: "/api/enrollment-drafts/\(id)", method: "DELETE", body: nil)
        forget(id: id)
    }

    /// D30 / after a delete: the draft is gone from every store.
    @MainActor
    func forget(id: String) {
        state.removeEnrollmentDraftWire(id: id)
        state.enrollmentFeed = [:]
    }

    @MainActor
    private func write(_ method: String, _ endpoint: String, _ body: [String: Any]) async throws -> DraftWriteOutcome {
        do {
            let data = try await api.requestWithStatus(endpoint: endpoint, method: method, body: body)
            let wire = try decode(One.self, data).draft
            state.upsertEnrollmentDraftWire(wire)
            state.enrollmentFeed = [:]
            return .saved(wire)
        } catch let error as APIHTTPError where error.status == 409 {
            guard let draftId = error.details["draftId"] else { throw error }
            return .exists(draftId: draftId)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder.apiDecoder.decode(type, from: data) } catch { throw APIError.decodingError(error) }
    }
}
```

`iphone/MakeReady/State/Actions/EnrollmentActions.swift` — `createEnrollment` gains a last parameter `draftId: String? = nil`; after the `lessonAccess` body line add the key, and after the two index adds the store refresh:

```swift
        if let draftId {                                        // ui2-enrollments-browse D11
            body["draftId"] = draftId
        }
```

```swift
        // ui2-enrollments-browse D11/D24: the server deleted the pair's drafts; the feed changed.
        state.removeEnrollmentDrafts(groupId: groupId, studyProgramId: studyProgramId)
        state.enrollmentFeed = [:]
```

and add the two loads (a new `// MARK: - Enrollments feed + home` section):

```swift
    /// ui2-enrollments-browse D8/D27: the org-wide feed for `filter`. Cache-first within the session.
    @MainActor
    func loadFeed(filter: EnrollmentFeedFilter, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws {
        if !forceRefresh, state.enrollmentFeed[filter] != nil { return }
        struct Response: Decodable {
            let success: Bool
            let sections: [EnrollmentFeedSection]
            let options: EnrollmentFeedOptions
        }
        let data = try await api.requestWithStatus(endpoint: filter.path(timeZone: timeZone), method: "GET", body: nil)
        let response: Response
        do { response = try JSONDecoder.apiDecoder.decode(Response.self, from: data) } catch { throw APIError.decodingError(error) }
        state.enrollmentFeed[filter] = EnrollmentFeed(sections: response.sections, options: response.options)
    }

    /// ui2-enrollments-browse D20: one enrollment's assembled detail.
    @MainActor
    func loadHome(id: String, forceRefresh: Bool = false, timeZone: TimeZone = .current) async throws {
        if !forceRefresh, state.enrollmentHomes[id] != nil { return }
        struct Response: Decodable { let success: Bool; let home: EnrollmentHome }
        let data = try await api.requestWithStatus(endpoint: EnrollmentHome.path(id: id, timeZone: timeZone), method: "GET", body: nil)
        let response: Response
        do { response = try JSONDecoder.apiDecoder.decode(Response.self, from: data) } catch { throw APIError.decodingError(error) }
        state.enrollmentHomes[id] = response.home
    }
```

Register the new app files and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReady/State/Models", "EnrollmentBrowseModels.swift", "MakeReady"); add.("MakeReady/State/Actions", "EnrollmentDraftActions.swift", "MakeReady"); p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (EnrollmentBrowseActionsTests 13/13; MemberSaveAvatarTests, EnrollSubmitTests, EnrollmentDraftTests still green); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): enrollment stores, draft actions, feed and home loads, draftId on enroll`

### Task 9: The `.enrollmentHome` destination and its page
App: iphone
Phase: 3
Recipe: `/nav-route` · `/push-page` (UI 2.0 shell form: a typed `UI2Destination` case + `page(for:)`, as `.studyProgramHome` — R2)

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-60` — `case enrollmentHome(id: String, name: String)`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:184-208` — `page(for:)` routes it
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeHost.swift` — the destination's page (renders `EmptyPage()` until Task 11 swaps in `EnrollmentHomeContainer`, so every commit compiles)
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (existing file, already in the test target)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register `EnrollmentHomeHost.swift` (Step 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes: `UI2ShellModel.push(_:on:)`, `popIfTop(_:on:)`, `path(for:)`, `showsTabBar`, `enrollmentFlowIds`, `UI2Destination.isFullScreen` (existing)
- Produces: `UI2Destination.enrollmentHome(id: String, name: String)`; `struct EnrollmentHomeHost: View { let id: String; let name: String }` — Task 11 replaces its body with `EnrollmentHomeContainer(enrollmentId: id, name: name)`; Task 10 and Task 14 push `.enrollmentHome(id:name:)`

- [ ] **Step 1: Write the failing test** — append inside `final class UI2ShellModelTests`:

```swift
    // ui2-enrollments-browse R2/D7/D28: one enrollment's page, pushed on the stack it was tapped on.
    func testEnrollmentHomePushesWithTheTabBarAndPopsOnlyWhenOnTop() {
        var m = UI2ShellModel()
        let page = UI2Destination.enrollmentHome(id: "e1", name: "Romans")
        m.push(page, on: .home)
        XCTAssertEqual(m.path(for: .home), [page])
        XCTAssertTrue(m.showsTabBar)
        XCTAssertFalse(page.isFullScreen)
        XCTAssertTrue(m.enrollmentFlowIds.isEmpty)                  // not a checklist: prune ignores it
        m.popIfTop(.enrollmentHome(id: "e2", name: "Romans"), on: .home)
        XCTAssertEqual(m.path(for: .home), [page])
        m.popIfTop(page, on: .home)
        XCTAssertTrue(m.path(for: .home).isEmpty)
    }

    func testEnrollmentHomeIsKeyedByItsId() {
        XCTAssertNotEqual(UI2Destination.enrollmentHome(id: "e1", name: "A"), .enrollmentHome(id: "e2", name: "A"))
        XCTAssertNotEqual(UI2Destination.enrollmentHome(id: "e1", name: "A"), .studyProgramHome(id: "e1", name: "A"))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "type 'UI2Destination' has no member 'enrollmentHome'"

- [ ] **Step 3: Write the minimal implementation**

`UI2ShellModel.swift` — in `enum UI2Destination`, after `case editProgramCover`:

```swift
    /// ui2-enrollments-browse D7/D28: one enrollment's page. `name` is the list-known program name
    /// the page shows while the home read loads.
    case enrollmentHome(id: String, name: String)
```

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeHost.swift`:

```swift
import SwiftUI

/// ui2-enrollments-browse R2: the `.enrollmentHome` destination of the shell's stacks. Task 11 of
/// the plan puts `EnrollmentHomeContainer` here; until then the route lands on the unwired page.
struct EnrollmentHomeHost: View {
    let id: String
    let name: String

    var body: some View {
        EmptyPage()
    }
}
```

`UI2Shell.swift` — in `page(for:)`, after the `.editProgramCover` case:

```swift
        case let .enrollmentHome(id, name): EnrollmentHomeHost(id: id, name: name)               // ui2-enrollments-browse R2
```

Register and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReady/UI2/Containers/Enrollments", "EnrollmentHomeHost.swift", "MakeReady"); p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (UI2ShellModelTests incl. the two new tests); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): the enrollmentHome destination (R2)`

### Task 10: The Enrollments section — EnrollmentsHomeContainer, EnrollmentsHomeMapper and draft-row opening
App: iphone
Phase: 4
Recipe: `/push-page` (section root → pushed pages) · `/ios-error-surface` (feed load = background, console-only) · build-time risk F1: start only once d2m change cmvt1w1vg0001v0sxb79srw16 (enrollments-home: `programDraftLabels`/`programDraftStarters` per row, the screen's own C-019 nav row removed, `.pinnedBelowTopNav()` + `onSearchActiveChange`) is done and its files are committed on this branch · build-time risk F1: start only once d2m change cmvt1w9a9000jv0sx8bflv7gc (groups-enroll-program: `public static func completedSteps(_ state: State) -> Int`, `onDiscard`) is done and its files are committed on this branch

Read `iphone/MakeReadyUI/Screens/Enrollments/EnrollmentsHomeScreen.swift` and `iphone/MakeReadyUI/Screens/Groups/GroupsEnrollProgramScreen.swift` as d2m landed them FIRST. This block codes against `EnrollmentsHomeScreen.State.programDraftLabels: [String]`, `.programDraftStarters: [String]`, `EnrollmentsHomeScreen(state:onSearch:onOpenFilter:onOpenGroup:onOpenEnrollment:onSearchActiveChange:)` (no `onSelectTab`/`onToggleNav`) and `GroupsEnrollProgramScreen.completedSteps(_:)`. If d2m named any of them differently, use d2m's name and say so in your report. Never edit a file under `iphone/MakeReadyUI/`.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentsHomeMapper.swift` — feed → `EnrollmentsHomeScreen.State`, the four C-036 menus, row targets
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentsHomeContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollDraftOpen.swift` — `EnrollmentRowTarget`, D21 open/refresh, D30 `gone`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:211-218` — `sectionContent` gains `case .enrollments: EnrollmentsHomeContainer()` (R1)
- Test: `iphone/MakeReadyCaptureTests/EnrollmentsHomeMapperTests.swift`, `iphone/MakeReadyCaptureTests/EnrollDraftOpenTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the five new files (Steps 1 and 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes (Task 7): `DraftWire`, `EnrollmentWireRef`, `EnrollmentDraftMapping.draft(_:flowId:zone:)`, `EnrollmentDraft.clearStaleStart(today:calendar:)`, `EnrollmentDraft.serverUpdatedAt`. (Task 8): `EnrollmentFeed`, `EnrollmentFeedSection`(`.GroupRef`), `EnrollmentFeedItem`, `EnrollmentFeedOptions`, `EnrollmentFeedFilter`(`.Status`, `.label`), `AppState.enrollmentFeed`, `AppState.seedEnrollmentDraft(_:flowId:)`, `AppState.enrollmentFlowId(forServerId:)`, `EnrollmentDraftActions.load(id:)`, `.forget(id:)`, `EnrollmentActions.loadFeed(filter:forceRefresh:timeZone:)`. (Task 9): `UI2Destination.enrollmentHome(id:name:)`. Existing: `EnrollChecklistMapper.state(_:group:program:today:)`, `MembersHomeMapper.parseDate(_:)`, `MembersHomeMapper.mediumDate(_:timeZone:)`, `GroupActions(onUnauthorized:).loadMyOrganizations()`, `AppState.myOrganizations: [OrganizationData]`, `FilterMenuOverlay`, `.filterMenuPresentation(isPresented:onDismiss:menu:)`, `.pageRefresh`, `UI2HidesTopNavKey`, `CoverImageLoader.seedList/cachedListURLs`, `UI2Navigator` (`push`, `popTo`, `depth`).
- Produces:
  - `enum EnrollmentRowTarget: Equatable { case enrollment(id: String, name: String); case draft(DraftWire) }`
  - `@MainActor enum EnrollDraftOpen { static let goneMessage = "This draft no longer exists"; @discardableResult static func open(_ wire: DraftWire, push: (UI2Destination) -> Void, state: AppState? = nil) -> UUID; static func refresh(flowId: UUID, wire: DraftWire, pop: @escaping () -> Void, state: AppState? = nil, actions: EnrollmentDraftActions? = nil) async; static func isNewer(_ candidate: String, than held: String?) -> Bool; static func gone(flowId: UUID, draftId: String?, error: Error, pop: () -> Void, state: AppState, actions: EnrollmentDraftActions); static func route(_ target: EnrollmentRowTarget?, navigator: UI2Navigator) }`
  - `enum EnrollmentsHomeMapper` with `Selection`, `Dimension`, `Input`, `Output` (`state`, `rowTargets`, `sections`, `target(atRow:)`, `groupDestination(section:)`), `output(_:today:timeZone:)`, `hours(minutes: Int) -> String`, `draftLabel(completed: Int) -> String`, `starterLabel(_ name: String?) -> String`, `draftCompletedSteps(_ wire: DraftWire, group: UserGroup?, program: StudyProgram?, groupName: String, programName: String, today: Date, timeZone: TimeZone) -> Int`, `menu(_:options:organizations:)`, `selectedId(_:_:)`, `selecting(_:in:_:)`, `clearing(_:_:)`, `isAtRest(_:_:)`
  - `struct EnrollmentsHomeContainer: View` (no parameters)

- [ ] **Step 1: Write the failing tests** — create both test files and register them:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollmentsHomeMapperTests.swift", "MakeReadyCaptureTests"); add.("MakeReadyCaptureTests", "EnrollDraftOpenTests.swift", "MakeReadyCaptureTests"); p.save'
```

`iphone/MakeReadyCaptureTests/EnrollmentsHomeMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D7, D8, D12, D13, D15, D16, D19, D27: the feed → the Enrollments section.
@MainActor
final class EnrollmentsHomeMapperTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2035-01-06T18:00:00Z")!     // Sat Jan 6, 12:00 local

    private func draft(_ id: String, start: String? = nil, schedule: [String]? = nil, sms: String? = nil,
                       sync: String? = nil, access: String? = nil, by name: String? = "Luke Keith") -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: "p2", startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: sms, timezone: sms == nil ? nil : "America/Chicago",
                  syncMode: sync, lessonAccess: access, createdBy: name.map { EnrollmentWireRef(id: "u1", name: $0) },
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-04T00:00:00.000Z")
    }

    private func enrollment(_ id: String, name: String, progress: Double, done: Int, members: Int, minutes: Int) -> EnrollmentFeedItem {
        EnrollmentFeedItem(kind: "enrollment", id: id, draft: nil,
                           studyProgram: EnrollmentFeedProgram(id: "p-\(id)", name: name, coverImageUrl: "https://x/\(id).png"),
                           startDate: "2035-01-08", endDate: "2035-02-01", enrolledAt: "2035-01-01T15:00:00.000Z",
                           progress: progress, completedMembers: done, memberCount: members, plannedMinutes: minutes,
                           recencyAt: "2035-01-05T00:00:00.000Z")
    }

    private func draftItem(_ wire: DraftWire, name: String = "John") -> EnrollmentFeedItem {
        EnrollmentFeedItem(kind: "draft", id: nil, draft: wire,
                           studyProgram: EnrollmentFeedProgram(id: wire.studyProgramId, name: name, coverImageUrl: nil),
                           startDate: nil, endDate: nil, enrolledAt: nil, progress: nil, completedMembers: nil,
                           memberCount: nil, plannedMinutes: nil, recencyAt: wire.updatedAt)
    }

    private func feed(_ items: [EnrollmentFeedItem]) -> EnrollmentFeed {
        EnrollmentFeed(
            sections: [
                EnrollmentFeedSection(group: .init(id: "g1", name: "Young Professionals", coverImageUrl: "https://x/g1.png",
                                                   leader: EnrollmentWireRef(id: "u1", name: "Luke Keith")), items: items),
                EnrollmentFeedSection(group: .init(id: "g2", name: "Stickane Family", coverImageUrl: nil, leader: nil),
                                      items: [enrollment("e2", name: "Daily Inspiration", progress: 1, done: 4, members: 4, minutes: 720)])
            ],
            options: EnrollmentFeedOptions(groups: [EnrollmentWireRef(id: "g1", name: "Young Professionals")],
                                           leaders: [EnrollmentWireRef(id: "u1", name: "Luke Keith")]))
    }

    private func output(_ feed: EnrollmentFeed?, selection: EnrollmentsHomeMapper.Selection = .init()) -> EnrollmentsHomeMapper.Output {
        EnrollmentsHomeMapper.output(.init(feed: feed, options: feed?.options, selection: selection),
                                     today: today, timeZone: zone)
    }

    func testSectionsRowsAndNumbers() {
        let o = output(feed([enrollment("e1", name: "Romans", progress: 0.5, done: 3, members: 12, minutes: 90),
                             draftItem(draft("d1"))]))
        let s = o.state
        XCTAssertEqual(s.groupNames, ["Young Professionals", "Stickane Family"])
        XCTAssertEqual(s.groupLeaderNames, ["Luke Keith", ""])
        XCTAssertEqual(s.groupPhotoURLs, ["https://x/g1.png", ""])
        XCTAssertEqual(s.programGroupIndexes, [0, 0, 1])
        XCTAssertEqual(s.programTitles, ["Romans", "John", "Daily Inspiration"])
        XCTAssertEqual(s.programProgress, [0.5, 0, 1])
        XCTAssertEqual(s.programCompleteCounts, ["3/12", "", "4/4"])          // D16
        XCTAssertEqual(s.programHours, ["1.5", "", "12"])                      // D12
        XCTAssertEqual(s.programEnrolledDates, ["Jan 1, 2035", "", "Jan 1, 2035"])
        XCTAssertEqual(s.programCoverURLs, ["https://x/e1.png", "", "https://x/e2.png"])
        XCTAssertEqual(s.programDraftLabels, ["", "Draft · 2/6", ""])          // D7: group + program only
        XCTAssertEqual(s.programDraftStarters, ["", "Started by Luke Keith", ""])
        XCTAssertFalse(s.loading); XCTAssertFalse(s.failed)
        XCTAssertEqual(s.searchText, "")                                       // D27: the screen filters locally
    }

    func testRowTargetsAndGroupArrow() {
        let wire = draft("d1")
        let o = output(feed([enrollment("e1", name: "Romans", progress: 0.5, done: 3, members: 12, minutes: 90), draftItem(wire)]))
        XCTAssertEqual(o.target(atRow: 0), .enrollment(id: "e1", name: "Romans"))
        XCTAssertEqual(o.target(atRow: 1), .draft(wire))
        XCTAssertNil(o.target(atRow: 9))
        XCTAssertEqual(o.groupDestination(section: 1), .groupDetail(id: "g2", name: "Stickane Family"))   // D7(d)
        XCTAssertNil(o.groupDestination(section: 5))
    }

    func testHoursHaveAtMostOneDecimalAndNoTrailingZero() {                    // D12
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 0), "0")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 60), "1")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 90), "1.5")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 100), "1.7")
        XCTAssertEqual(EnrollmentsHomeMapper.hours(minutes: 720), "12")
    }

    func testDraftCountAppliesTheStaleRule() {                                 // D9 + D19
        let future = draft("d1", start: "2035-01-08", schedule: ["2035-01-08"], sms: "07:30", sync: "AUTO", access: "ALL_AT_ONCE")
        let stale = draft("d2", start: "2035-01-01", schedule: ["2035-01-01"], sms: "07:30", sync: "AUTO", access: "ALL_AT_ONCE")
        func count(_ w: DraftWire) -> Int {
            EnrollmentsHomeMapper.draftCompletedSteps(w, group: nil, program: nil, groupName: "Young Professionals",
                                                      programName: "John", today: today, timeZone: zone)
        }
        XCTAssertEqual(count(future), 6)
        XCTAssertEqual(count(stale), 5)
        XCTAssertEqual(EnrollmentsHomeMapper.draftLabel(completed: 5), "Draft · 5/6")
        XCTAssertEqual(EnrollmentsHomeMapper.starterLabel(nil), "")             // F9
    }

    func testLoadingAndFailedOnlyWithNothingToShow() {
        let loading = EnrollmentsHomeMapper.output(.init(feed: nil, options: nil, loading: true), today: today, timeZone: zone).state
        XCTAssertTrue(loading.loading)
        XCTAssertEqual(loading.groupNames, [])
        let failed = EnrollmentsHomeMapper.output(.init(feed: nil, options: nil, failed: true), today: today, timeZone: zone).state
        XCTAssertTrue(failed.failed)
    }

    func testChipsRestAndNarrow() {                                            // D8, D13, D15
        var sel = EnrollmentsHomeMapper.Selection()
        var s = output(nil, selection: sel).state
        XCTAssertEqual([s.orgFilterLabel, s.groupFilterLabel, s.leaderFilterLabel, s.statusFilterLabel],
                       ["All Orgs", "All groups", "All Leaders", "Active"])
        sel = EnrollmentsHomeMapper.selecting(.init(id: "o1", label: "Grace Church"), in: .orgs, sel)
        sel = EnrollmentsHomeMapper.selecting(.init(id: "draft", label: "Draft"), in: .status, sel)
        s = output(nil, selection: sel).state
        XCTAssertEqual(s.orgFilterLabel, "Grace Church")
        XCTAssertEqual(s.statusFilterLabel, "Draft")
        XCTAssertEqual(sel.filter, EnrollmentFeedFilter(orgId: "o1", status: .draft))
        sel = EnrollmentsHomeMapper.selecting(.init(id: "", label: "All Orgs"), in: .orgs, sel)   // D15: "All Orgs" = no orgId
        XCTAssertNil(sel.filter.orgId)
        sel = EnrollmentsHomeMapper.clearing(.status, sel)
        XCTAssertEqual(sel.filter.status, .active)
        XCTAssertTrue(EnrollmentsHomeMapper.isAtRest(.status, sel))
    }

    func testMenus() throws {
        let orgs = try JSONDecoder.apiDecoder.decode([OrganizationData].self, from: Data(#"[{"id":"o1","name":"Grace Church"}]"#.utf8))
        let options = feed([]).options
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.orgs, options: options, organizations: orgs).map(\.label), ["All Orgs", "Grace Church"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.groups, options: options, organizations: orgs).map(\.id), ["g1"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.leaders, options: options, organizations: orgs).map(\.label), ["Luke Keith"])
        XCTAssertEqual(EnrollmentsHomeMapper.menu(.status, options: nil, organizations: []).map(\.label),
                       ["Active", "Upcoming", "Completed", "Draft", "All"])
        XCTAssertEqual(EnrollmentsHomeMapper.selectedId(.orgs, .init()), "")      // "All Orgs" checked at rest
        XCTAssertEqual(EnrollmentsHomeMapper.selectedId(.status, .init()), "active")
    }
}
```

`iphone/MakeReadyCaptureTests/EnrollDraftOpenTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D21 (draft ↔ checklist identity) and D30 (draft gone) for a list tap.
@MainActor
final class EnrollDraftOpenTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func wire(_ id: String, sms: String? = nil, updated: String = "2035-01-02T00:00:00.000Z") -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: "p1", startDate: nil, enabledDays: nil, overriddenDates: nil,
                  scheduleDates: nil, smsTime: sms, timezone: nil, syncMode: nil, lessonAccess: nil,
                  createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: updated)
    }

    private func json(_ w: DraftWire) -> String {
        let sms = w.smsTime.map { "\"\($0)\"" } ?? "null"
        return #"{"success":true,"draft":{"id":"\#(w.id)","groupId":"g1","studyProgramId":"p1","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":\#(sms),"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"\#(w.updatedAt)"}}"#
    }

    private var actions: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }

    func testANewTapSeedsAFlowAndPushesItsChecklist() {
        var pushed: [UI2Destination] = []
        let flow = EnrollDraftOpen.open(wire("d1"), push: { pushed.append($0) }, state: state)
        XCTAssertEqual(pushed, [.enrollChecklist(flowId: flow)])
        XCTAssertEqual(state.enrollmentDrafts[flow]?.serverId, "d1")
    }

    func testATapReusesTheOpenFlowOfThatDraft() {
        let open = state.seedEnrollmentDraft(wire("d1"))
        var pushed: [UI2Destination] = []
        let flow = EnrollDraftOpen.open(wire("d1"), push: { pushed.append($0) }, state: state)
        XCTAssertEqual(flow, open)
        XCTAssertEqual(state.enrollmentDrafts.count, 1)
        XCTAssertEqual(pushed, [.enrollChecklist(flowId: open)])
    }

    func testANewerServerCopyReseedsTheFlowInPlace() async {
        let listed = wire("d1")
        let flow = state.seedEnrollmentDraft(listed)
        api.stub("GET", "/api/enrollment-drafts/d1", json: json(wire("d1", sms: "07:30", updated: "2035-01-03T00:00:00.000Z")))
        await EnrollDraftOpen.refresh(flowId: flow, wire: listed, pop: {}, state: state, actions: actions)
        XCTAssertEqual(state.enrollmentDrafts[flow]?.smsTime, "07:30")
        XCTAssertEqual(state.enrollmentDraftBaselines[flow]?.smsTime, "07:30")
    }

    func testASameAgeServerCopyChangesNothing() async {
        let listed = wire("d1")
        let flow = state.seedEnrollmentDraft(listed)
        state.updateEnrollmentDraft(flow) { $0.smsTime = "06:00" }                   // a local edit already made
        api.stub("GET", "/api/enrollment-drafts/d1", json: json(listed))
        await EnrollDraftOpen.refresh(flowId: flow, wire: listed, pop: {}, state: state, actions: actions)
        XCTAssertEqual(state.enrollmentDrafts[flow]?.smsTime, "06:00")
    }

    func testAGoneDraftEndsTheFlowBannersAndPops() async {                          // D30
        let listed = wire("d1")
        let flow = state.seedEnrollmentDraft(listed)
        state.enrollmentDraftsByGroupId["g1"] = [listed]
        state.enrollmentFeed[EnrollmentFeedFilter()] = EnrollmentFeed(sections: [], options: .init(groups: [], leaders: []))
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var popped = false
        await EnrollDraftOpen.refresh(flowId: flow, wire: listed, pop: { popped = true }, state: state, actions: actions)
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertTrue(state.enrollmentFeed.isEmpty)
        XCTAssertEqual(state.activeSurfacedError?.message, "This draft no longer exists")
        XCTAssertTrue(popped)
    }

    func testGoneIsSilentOncePastTheChecklist() {                                  // D30 last clause
        let flow = state.seedEnrollmentDraft(wire("d1"))
        state.updateEnrollmentDraft(flow) { $0.phase = .enrolled }
        var popped = false
        EnrollDraftOpen.gone(flowId: flow, draftId: "d1", error: APIHTTPError(status: 404, message: nil),
                             pop: { popped = true }, state: state, actions: actions)
        XCTAssertNotNil(state.enrollmentDrafts[flow])
        XCTAssertNil(state.activeSurfacedError)
        XCTAssertFalse(popped)
    }

    func testIsNewerComparesInstants() {
        XCTAssertTrue(EnrollDraftOpen.isNewer("2035-01-03T00:00:00.000Z", than: "2035-01-02T00:00:00.000Z"))
        XCTAssertFalse(EnrollDraftOpen.isNewer("2035-01-02T00:00:00.000Z", than: "2035-01-02T00:00:00.000Z"))
        XCTAssertTrue(EnrollDraftOpen.isNewer("2035-01-02T00:00:00.000Z", than: nil))
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile, "cannot find 'EnrollmentsHomeMapper' in scope", "cannot find 'EnrollDraftOpen' in scope"

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollDraftOpen.swift`:

```swift
import SwiftUI

/// ui2-enrollments-browse D28/D21: what a tapped enrollments-list or group-page row opens.
enum EnrollmentRowTarget: Equatable {
    case enrollment(id: String, name: String)
    case draft(DraftWire)
}

/// ui2-enrollments-browse D21: a draft row → the checklist for that draft (an open flow backed by
/// the same server row is reused; else a new local flow is seeded from the listed Draft), then the
/// server copy is fetched and re-seeds the flow when newer. D30: a 404 ends the flow.
@MainActor
enum EnrollDraftOpen {
    static let goneMessage = "This draft no longer exists"

    @discardableResult
    static func open(_ wire: DraftWire, push: (UI2Destination) -> Void, state: AppState? = nil) -> UUID {
        let state = state ?? .shared
        let flowId = state.enrollmentFlowId(forServerId: wire.id) ?? state.seedEnrollmentDraft(wire)
        push(.enrollChecklist(flowId: flowId))
        return flowId
    }

    static func refresh(flowId: UUID, wire: DraftWire, pop: @escaping () -> Void,
                        state: AppState? = nil, actions: EnrollmentDraftActions? = nil) async {
        let state = state ?? .shared
        let actions = actions ?? EnrollmentDraftActions(state: state)
        do {
            let fresh = try await actions.load(id: wire.id)
            guard let held = state.enrollmentDrafts[flowId], held.phase == .checklist,
                  isNewer(fresh.updatedAt, than: held.serverUpdatedAt) else { return }
            state.seedEnrollmentDraft(fresh, flowId: flowId)
        } catch {
            if GroupActions.isCancellation(error) { return }
            if let http = error as? APIHTTPError, http.status == 404 {
                gone(flowId: flowId, draftId: wire.id, error: error, pop: pop, state: state, actions: actions)
                return
            }
            // Background read: the listed copy is already on screen — console-only.
            state.recordError(error, context: "EnrollDraftOpen.refresh")
        }
    }

    static func isNewer(_ candidate: String, than held: String?) -> Bool {
        guard let held, let heldDate = MembersHomeMapper.parseDate(held) else { return true }
        guard let date = MembersHomeMapper.parseDate(candidate) else { return false }
        return date > heldDate
    }

    /// D30: the server has no such draft — forget it everywhere, end the flow, say so, pop the
    /// checklist. Silent once the flow has left `checklist` (a just-enrolled draft is gone on purpose).
    static func gone(flowId: UUID, draftId: String?, error: Error, pop: () -> Void,
                     state: AppState, actions: EnrollmentDraftActions) {
        guard state.enrollmentDrafts[flowId]?.phase == .checklist else { return }
        if let draftId { actions.forget(id: draftId) }
        state.endEnrollmentDraft(flowId)
        state.recordError(error, context: "EnrollDraftOpen.gone", surface: true, friendlyMessage: goneMessage)
        pop()
    }

    /// D28 + D21: an enrollment row pushes its page; a draft row pushes the checklist and refreshes
    /// it, popping back to this page if the draft turns out to be gone.
    static func route(_ target: EnrollmentRowTarget?, navigator: UI2Navigator) {
        switch target {
        case let .enrollment(id, name)?:
            navigator.push(.enrollmentHome(id: id, name: name))
        case let .draft(wire)?:
            let depth = navigator.depth()
            let flowId = open(wire, push: navigator.push)
            Task { @MainActor in
                await refresh(flowId: flowId, wire: wire, pop: { navigator.popTo(depth) })
            }
        case nil:
            break
        }
    }
}
```

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentsHomeMapper.swift`:

```swift
import Foundation

/// ui2-enrollments-browse §iphone EnrollmentsHomeContainer: the feed → `EnrollmentsHomeScreen.State`.
/// Pure. Rows keep the feed's order (D17); search is the screen's own local filter (D27).
enum EnrollmentsHomeMapper {
    static let allOrgsLabel = "All Orgs"
    static let allGroupsLabel = "All groups"
    static let allLeadersLabel = "All Leaders"

    /// The four chips, by the dimension name the screen's `onOpenFilter` passes.
    enum Dimension: String, CaseIterable { case orgs = "Orgs", groups = "Groups", leaders = "Leaders", status = "Status" }

    /// The chips' picks — ids for the request, labels for the chips.
    struct Selection: Equatable {
        var orgId: String?
        var orgLabel: String?
        var groupId: String?
        var groupLabel: String?
        var leaderId: String?
        var leaderLabel: String?
        var status: EnrollmentFeedFilter.Status = .active

        var filter: EnrollmentFeedFilter {
            EnrollmentFeedFilter(orgId: orgId, groupId: groupId, leaderId: leaderId, status: status)
        }
    }

    struct Input {
        var feed: EnrollmentFeed?
        /// The menus' options — the shown feed's, else the last loaded one's.
        var options: EnrollmentFeedOptions?
        var selection = Selection()
        var loading = false
        var failed = false
        var group: (String) -> UserGroup? = { _ in nil }
        var program: (String) -> StudyProgram? = { _ in nil }
    }

    struct Output {
        var state: EnrollmentsHomeScreen.State
        var rowTargets: [EnrollmentRowTarget]
        var sections: [EnrollmentFeedSection.GroupRef]

        func target(atRow row: Int) -> EnrollmentRowTarget? {
            rowTargets.indices.contains(row) ? rowTargets[row] : nil
        }

        /// D7(d): a section's C-058 arrow → that group's page.
        func groupDestination(section: Int) -> UI2Destination? {
            sections.indices.contains(section) ? .groupDetail(id: sections[section].id, name: sections[section].name) : nil
        }
    }

    static func output(_ input: Input, today: Date, timeZone: TimeZone) -> Output {
        let sections = input.feed?.sections ?? []
        var indexes: [Int] = [], titles: [String] = [], progress: [Double] = []
        var completes: [String] = [], hoursLabels: [String] = [], enrolled: [String] = [], covers: [String] = []
        var draftLabels: [String] = [], starters: [String] = []
        var targets: [EnrollmentRowTarget] = []
        for (sectionIndex, section) in sections.enumerated() {
            for item in section.items {
                indexes.append(sectionIndex)
                titles.append(item.studyProgram.name)
                covers.append(item.studyProgram.coverImageUrl ?? "")
                if item.kind == "draft", let wire = item.draft {
                    let n = draftCompletedSteps(wire, group: input.group(wire.groupId), program: input.program(wire.studyProgramId),
                                                groupName: section.group.name, programName: item.studyProgram.name,
                                                today: today, timeZone: timeZone)
                    progress.append(0); completes.append(""); hoursLabels.append(""); enrolled.append("")
                    draftLabels.append(draftLabel(completed: n))
                    starters.append(starterLabel(wire.createdBy?.name))
                    targets.append(.draft(wire))
                } else {
                    progress.append(item.progress ?? 0)
                    completes.append("\(item.completedMembers ?? 0)/\(item.memberCount ?? 0)")       // D16
                    hoursLabels.append(hours(minutes: item.plannedMinutes ?? 0))                       // D12
                    enrolled.append(item.enrolledAt.flatMap(MembersHomeMapper.parseDate)
                        .map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? "")
                    draftLabels.append(""); starters.append("")
                    targets.append(.enrollment(id: item.id ?? "", name: item.studyProgram.name))
                }
            }
        }
        let sel = input.selection
        var state = EnrollmentsHomeScreen.State(
            searchText: "",
            orgFilterLabel: sel.orgLabel ?? allOrgsLabel,
            groupFilterLabel: sel.groupLabel ?? allGroupsLabel,
            leaderFilterLabel: sel.leaderLabel ?? allLeadersLabel,
            statusFilterLabel: sel.status.label,
            loading: input.loading && input.feed == nil,
            failed: input.failed && input.feed == nil,
            groupNames: sections.map(\.group.name),
            groupLeaderNames: sections.map { $0.group.leader?.name ?? "" },
            groupPhotoURLs: sections.map { $0.group.coverImageUrl ?? "" },
            programGroupIndexes: indexes,
            programTitles: titles,
            programProgress: progress,
            programCompleteCounts: completes,
            programHours: hoursLabels,
            programEnrolledDates: enrolled,
            programCoverURLs: covers
        )
        state.programDraftLabels = draftLabels                                          // D14.1
        state.programDraftStarters = starters
        return Output(state: state, rowTargets: targets, sections: sections.map(\.group))
    }

    /// D12: hours with at most one decimal and no trailing `.0`.
    static func hours(minutes: Int) -> String {
        let tenths = Int((Double(minutes) / 6).rounded())
        return tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
    }

    static func draftLabel(completed: Int) -> String { "Draft · \(completed)/6" }

    /// D7: "Started by «name»"; no starter (a deleted user, F9) → "".
    static func starterLabel(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "" }
        return "Started by \(name)"
    }

    /// D19: the checklist's own count (D14.3) over the draft as the checklist would show it, with
    /// D9's stale rule; group/program from the stores, else the feed's names.
    static func draftCompletedSteps(_ wire: DraftWire, group: UserGroup?, program: StudyProgram?,
                                    groupName: String, programName: String, today: Date, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var draft = EnrollmentDraftMapping.draft(wire, flowId: UUID(), zone: timeZone)
        draft.clearStaleStart(today: today, calendar: cal)
        var state = EnrollChecklistMapper.state(draft, group: group, program: program, today: today)
        if state.groupName.isEmpty { state.groupName = groupName }
        if state.programName.isEmpty { state.programName = programName }
        return GroupsEnrollProgramScreen.completedSteps(state)
    }

    // MARK: - The four C-036 menus (D8, D13, D15) — single pick; Clear returns the chip to rest

    static func menu(_ dimension: Dimension, options: EnrollmentFeedOptions?,
                     organizations: [OrganizationData]) -> [FilterMenuOverlay.Option] {
        switch dimension {
        case .orgs:
            return [.init(id: "", label: allOrgsLabel)] + organizations.map { .init(id: $0.id, label: $0.name) }
        case .groups:
            return (options?.groups ?? []).map { .init(id: $0.id, label: $0.name ?? "") }
        case .leaders:
            return (options?.leaders ?? []).map { .init(id: $0.id, label: $0.name ?? "") }
        case .status:
            return EnrollmentFeedFilter.Status.allCases.map { .init(id: $0.rawValue, label: $0.label) }
        }
    }

    static func selectedId(_ dimension: Dimension, _ s: Selection) -> String {
        switch dimension {
        case .orgs: return s.orgId ?? ""
        case .groups: return s.groupId ?? ""
        case .leaders: return s.leaderId ?? ""
        case .status: return s.status.rawValue
        }
    }

    static func selecting(_ option: FilterMenuOverlay.Option, in dimension: Dimension, _ s: Selection) -> Selection {
        var next = s
        let id: String? = option.id.isEmpty ? nil : option.id
        switch dimension {
        case .orgs: next.orgId = id; next.orgLabel = id == nil ? nil : option.label
        case .groups: next.groupId = id; next.groupLabel = id == nil ? nil : option.label
        case .leaders: next.leaderId = id; next.leaderLabel = id == nil ? nil : option.label
        case .status: next.status = EnrollmentFeedFilter.Status(rawValue: option.id) ?? .active
        }
        return next
    }

    static func clearing(_ dimension: Dimension, _ s: Selection) -> Selection {
        selecting(.init(id: dimension == .status ? EnrollmentFeedFilter.Status.active.rawValue : "", label: ""), in: dimension, s)
    }

    static func isAtRest(_ dimension: Dimension, _ s: Selection) -> Bool {
        dimension == .status ? s.status == .active : selectedId(dimension, s).isEmpty
    }
}
```

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentsHomeContainer.swift`:

```swift
import SwiftUI

/// ui2-enrollments-browse §iphone: the Home tab's Enrollments section (R1). Cache-first per filter
/// (`AppState.enrollmentFeed`); a filter whose answer is missing — first visit, or dropped by a
/// draft/enroll mutation — loads. The screen has no root scroll: the shell's page scroll scrolls it.
/// Load failures are background (console-only); pull-down reloads.
struct EnrollmentsHomeContainer: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var selection = EnrollmentsHomeMapper.Selection()
    @State private var openMenu: EnrollmentsHomeMapper.Dimension?
    @State private var searchActive = false
    @State private var loading = false
    @State private var failed = false
    /// Bumped when covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0

    /// Reload trigger: the filter, and whether its answer is missing.
    private struct LoadKey: Equatable { let filter: EnrollmentFeedFilter; let missing: Bool }

    var body: some View {
        let app = AppState.shared
        let feed = app.enrollmentFeed[selection.filter]
        let options = feed?.options ?? app.enrollmentFeed.values.first?.options
        let output = EnrollmentsHomeMapper.output(
            .init(feed: feed, options: options, selection: selection, loading: loading, failed: failed,
                  group: { app.groups[$0] }, program: { app.programs[$0] }),
            today: Date(), timeZone: .current)
        let _ = coversSeeded
        let state = {
            var s = output.state
            s.groupPhotoURLs = CoverImageLoader.cachedListURLs(s.groupPhotoURLs)
            s.programCoverURLs = CoverImageLoader.cachedListURLs(s.programCoverURLs)
            return s
        }()
        EnrollmentsHomeScreen(
            state: state,
            onOpenFilter: { openMenu = EnrollmentsHomeMapper.Dimension(rawValue: $0) },
            onOpenGroup: { section in
                if let next = output.groupDestination(section: section) { navigator.push(next) }
            },
            onOpenEnrollment: { row in EnrollDraftOpen.route(output.target(atRow: row), navigator: navigator) },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .filterMenuPresentation(isPresented: openMenu != nil, onDismiss: { openMenu = nil }) {
            if let dimension = openMenu {
                FilterMenuOverlay(
                    options: EnrollmentsHomeMapper.menu(dimension, options: options, organizations: app.myOrganizations),
                    selectionMode: .single,
                    selectedIDs: [EnrollmentsHomeMapper.selectedId(dimension, selection)],
                    onSelect: { option in
                        selection = EnrollmentsHomeMapper.selecting(option, in: dimension, selection)
                        openMenu = nil
                    },
                    onClose: { openMenu = nil },
                    onClear: {
                        selection = EnrollmentsHomeMapper.clearing(dimension, selection)
                        openMenu = nil
                    },
                    clearEnabled: !EnrollmentsHomeMapper.isAtRest(dimension, selection)
                )
            }
        }
        .task { await GroupActions(onUnauthorized: signOut).loadMyOrganizations() }      // D15 "All Orgs" menu
        .task(id: LoadKey(filter: selection.filter, missing: feed == nil)) {
            if feed == nil { await reload(force: false) }
        }
        .pageRefresh { await reload(force: true) }
        .task(id: output.state.groupPhotoURLs + output.state.programCoverURLs) {
            if await CoverImageLoader.seedList(output.state.groupPhotoURLs + output.state.programCoverURLs) { coversSeeded += 1 }
        }
    }

    @MainActor
    private func reload(force: Bool) async {
        loading = true
        defer { loading = false }
        failed = !(await Self.load(selection.filter, force: force, actions: EnrollmentActions(),
                                   state: .shared, onUnauthorized: signOut))
    }

    /// true = the feed is (or stays) loaded. A cancelled load is nothing; a 401 signs out; anything
    /// else is a background failure — recorded console-only (ios-error-surface).
    @MainActor
    static func load(_ filter: EnrollmentFeedFilter, force: Bool, actions: EnrollmentActions, state: AppState,
                     onUnauthorized: @MainActor () async -> Void) async -> Bool {
        do {
            try await actions.loadFeed(filter: filter, forceRefresh: force)
            return true
        } catch {
            if GroupActions.isCancellation(error) { return true }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            state.recordError(error, context: "EnrollmentsHomeContainer.loadFeed")
            return false
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    private var signOut: @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EnrollmentsHomeContainer.signOut", surface: false)
            }
        }
    }
}
```

`UI2Shell.swift` — `sectionContent`, before `default:`:

```swift
        case .enrollments: EnrollmentsHomeContainer()  // ui2-enrollments-browse R1
```

Register and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; %w[EnrollDraftOpen.swift EnrollmentsHomeMapper.swift EnrollmentsHomeContainer.swift].each { |f| add.("MakeReady/UI2/Containers/Enrollments", f, "MakeReady") }; p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS (EnrollmentsHomeMapperTests 7/7, EnrollDraftOpenTests 7/7); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (if it flags `function_body_length` on `EnrollmentsHomeMapper.output`, move the per-item loop body into a `private static func` — no behaviour change)

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): the Enrollments section on the live feed, draft rows open the checklist (R1, D7, D21)`

### Task 11: The enrollment page — EnrollmentHomeContainer and EnrollmentHomeMapper
App: iphone
Phase: 4
Recipe: `/push-page` · `/ios-error-surface` (home load = page load, console-only + `failed`, pull-down retries) · build-time risk F1: start only once d2m change cmvt1wcja000sv0sxakupqsc6 (enrollment-home: `showsScheduleEditing`, `showsHeader`, `loading`, `failed`, `onRetry`) is done and its files are committed on this branch · build-time risk F2: d2m reports the frame drift note (`3773:6944` vs the owner's `4751:54817`) on cmvt1wcja000sv0sxakupqsc6 — read that note in the landed change before wiring, and report any layout input it adds or renames

Read `iphone/MakeReadyUI/Screens/Enrollments/EnrollmentHomeScreen.swift` as d2m landed it FIRST. This block assumes the study-program-home pattern: `showsHeader: Bool` and `showsScheduleEditing: Bool` are init parameters, `loading`/`failed` are defaulted `State` fields, `onRetry: () -> Void` is an init closure. If d2m placed or named any of them differently, use d2m's and say so in your report. Never edit a file under `iphone/MakeReadyUI/`.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeMapper.swift`
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeContainer.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeHost.swift` — body becomes `EnrollmentHomeContainer(enrollmentId: id, name: name)`
- Test: `iphone/MakeReadyCaptureTests/EnrollmentHomeMapperTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the three new files (Steps 1 and 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes (Task 8): `EnrollmentHome` (+ `.Day`, `.Lesson`, `.Activity`), `AppState.enrollmentHomes`, `EnrollmentActions.loadHome(id:forceRefresh:timeZone:)`. (Task 7): `EnrollmentWire.date(ymd:in:)`. (Task 9): `EnrollmentHomeHost(id:name:)`. Existing: `MembersHomeMapper.parseDate`, `.mediumDate`, `MemberProfileContainer.cachedCoverURLs(_:)`, `UI2ImageLoader.seed(_:context:)`, `PageHeader`, `.pullDownRefresh`.
- Produces: `enum EnrollmentHomeMapper { struct Input { var name: String; var home: EnrollmentHome?; var loading = false; var failed = false }; static func state(_ input: Input, today: Date, timeZone: TimeZone) -> EnrollmentHomeScreen.State; static func inviteTime(_ smsTime: String?) -> String; static func span(from: Date, to: Date, calendar: Calendar) -> (months: Int, days: Int); static func relativeLabel(_ date: Date, today: Date, calendar: Calendar) -> String }`; `struct EnrollmentHomeContainer: View { let enrollmentId: String; let name: String }`

- [ ] **Step 1: Write the failing test** — create and register `iphone/MakeReadyCaptureTests/EnrollmentHomeMapperTests.swift`:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollmentHomeMapperTests.swift", "MakeReadyCaptureTests"); p.save'
```

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D20 + §Contract Home → `EnrollmentHomeScreen.State`.
final class EnrollmentHomeMapperTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2035-01-09T18:00:00Z")!     // Tue Jan 9, 12:00 local

    private func home() throws -> EnrollmentHome {
        try JSONDecoder.apiDecoder.decode(EnrollmentHome.self, from: Data(#"""
        {"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":"Paul's letter","coverImageUrl":"https://x/p1.png","authorName":"Jonathan Edwards"},
         "group":{"id":"g1","name":"Young Professionals","leader":{"id":"u1","name":"Tony Stark"}},
         "memberCount":17,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-03-10",
         "lessonAccess":"ALL_AT_ONCE","smsTime":"07:30","timezone":"America/Chicago",
         "days":[{"scheduleId":"s1","date":"2035-01-08","percent":78,"lessonCount":1,"plannedMinutes":15},
                 {"scheduleId":"s2","date":"2035-01-09","percent":65.4,"lessonCount":2,"plannedMinutes":30}],
         "lessons":[{"scheduleId":"s1","dayNumber":1,"title":"It is evident","date":"2035-01-08","progress":1,"activities":[]},
                    {"scheduleId":"s2","dayNumber":2,"title":"In the beginning","date":"2035-01-09","progress":0.69,
                     "activities":[{"id":"a1","type":"READ","title":"Romans 1","thumbnailUrl":"https://x/a1.png"},
                                   {"id":"a2","type":"VIDEO","title":null,"thumbnailUrl":null}]},
                    {"scheduleId":"s3","dayNumber":3,"title":null,"date":"2035-01-10","progress":0,"activities":[]},
                    {"scheduleId":"s4","dayNumber":4,"title":"Later","date":"2035-01-22","progress":null,"activities":[]}]}
        """#.utf8))
    }

    private func state(_ home: EnrollmentHome?, loading: Bool = false, failed: Bool = false) -> EnrollmentHomeScreen.State {
        EnrollmentHomeMapper.state(.init(name: "Pushed", home: home, loading: loading, failed: failed), today: today, timeZone: zone)
    }

    func testIdentityAndDetails() throws {
        let s = state(try home())
        XCTAssertEqual(s.coverURL, "https://x/p1.png")
        XCTAssertEqual(s.programName, "Romans")
        XCTAssertEqual(s.programDescription, "Paul's letter")
        XCTAssertEqual(s.memberCount, 17)
        XCTAssertEqual(s.authorName, "Jonathan Edwards")
        XCTAssertEqual(s.enrolledLabel, "Jan 1, 2035")
        XCTAssertEqual(s.leaderName, "Tony Stark")                               // D13
    }

    func testScheduleCardsAndSpan() throws {
        let s = state(try home())
        XCTAssertEqual([s.startMonth, s.startWeekday, s.startDay], ["Jan", "Mon", "8"])
        XCTAssertEqual([s.endMonth, s.endWeekday, s.endDay], ["Mar", "Sat", "10"])
        XCTAssertEqual(s.spanMonths, 2)
        XCTAssertEqual(s.spanDays, 2)
    }

    func testDayRail() throws {
        let s = state(try home())
        XCTAssertEqual(s.dayMonths, ["JAN", "JAN"])
        XCTAssertEqual(s.dayWeekdays, ["MON", "TUE"])
        XCTAssertEqual(s.dayNumbers, ["8", "9"])
        XCTAssertEqual(s.dayDateStates, ["default", "today"])                    // vs the device's today
        XCTAssertEqual(s.dayPercents, [78, 65])
        XCTAssertEqual(s.dayLine1s, ["1", "2"])                                  // lessons that day
        XCTAssertEqual(s.dayLine2s, ["7:30am", "7:30am"])                        // the invite time
        XCTAssertEqual(s.dayDetailsStates, ["lessonDay", "lessonDay"])
    }

    func testLessons() throws {
        let s = state(try home())
        XCTAssertEqual(s.lessonNumbers, [1, 2, 3, 4])
        XCTAssertEqual(s.lessonTitles, ["It is evident", "In the beginning", "Day 3", "Later"])
        XCTAssertEqual(s.lessonMetaLabels, ["Jan 8", "Today", "Tomorrow", "Jan 22"])
        XCTAssertEqual(s.lessonProgress, [nil, 0.69, nil, nil])                 // §2.5: today's card only
        XCTAssertEqual(s.lessonSlideImages, [[], ["https://x/a1.png", ""], [], []])
        XCTAssertEqual(s.lessonSlideLabels, [[], ["Read: Romans 1", "Video"], [], []])
    }

    func testInviteTimeFormat() {                                                // T8
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("07:30"), "7:30am")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("19:05"), "7:05pm")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime("00:00"), "12:00am")
        XCTAssertEqual(EnrollmentHomeMapper.inviteTime(nil), "")
    }

    func testNoScheduleRendersTheStartCardOnly() throws {                      // OQ-enrollment-home-8
        let json = Data(#"{"id":"e1","studyProgram":{"id":"p1","name":"Romans","description":null,"coverImageUrl":null,"authorName":null},"group":{"id":"g1","name":"YP","leader":null},"memberCount":0,"enrolledAt":"2035-01-01T15:00:00.000Z","startDate":"2035-01-08","endDate":"2035-01-08","lessonAccess":null,"smsTime":null,"timezone":null,"days":[],"lessons":[]}"#.utf8)
        let s = state(try JSONDecoder.apiDecoder.decode(EnrollmentHome.self, from: json))
        XCTAssertEqual(s.startDay, "8")
        XCTAssertEqual([s.endMonth, s.endWeekday, s.endDay], ["", "", ""])
        XCTAssertEqual([s.spanMonths, s.spanDays], [0, 0])
        XCTAssertEqual(s.dayNumbers, []); XCTAssertEqual(s.lessonTitles, [])
        XCTAssertEqual(s.leaderName, ""); XCTAssertEqual(s.authorName, "")
    }

    func testLoadingKeepsThePushedNameAndFailedShowsOnlyWithNothingCached() throws {
        let loading = state(nil, loading: true)
        XCTAssertEqual(loading.programName, "Pushed")
        XCTAssertTrue(loading.loading)
        XCTAssertTrue(state(nil, failed: true).failed)
        XCTAssertFalse(state(try home(), failed: true).failed)                   // a cached page stays
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "cannot find 'EnrollmentHomeMapper' in scope"

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeMapper.swift`:

```swift
import Foundation

/// ui2-enrollments-browse D20: §Contract Home → `EnrollmentHomeScreen.State`. Pure. Every
/// `yyyy-MM-dd` is shown as sent and compared with the device's today (F9). The empty schedule is
/// the built `empty-schedule` state: start card only, zero span, no rail, no lessons.
enum EnrollmentHomeMapper {
    struct Input {
        var name: String
        var home: EnrollmentHome?
        var loading = false
        var failed = false
    }

    static func state(_ input: Input, today: Date, timeZone: TimeZone) -> EnrollmentHomeScreen.State {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let h = input.home
        let start = h.flatMap { EnrollmentWire.date(ymd: $0.startDate, in: timeZone) }
        let end = h.flatMap { EnrollmentWire.date(ymd: $0.endDate, in: timeZone) }
        let hasSchedule = !(h?.days.isEmpty ?? true)
        let span = (hasSchedule ? zip2(start, end) : nil).map { span(from: $0.0, to: $0.1, calendar: cal) } ?? (0, 0)
        let days = h?.days ?? []
        let dayDates = days.map { EnrollmentWire.date(ymd: $0.date, in: timeZone) }
        let lessons = h?.lessons ?? []
        let invite = inviteTime(h?.smsTime)
        let f = { (d: Date?, p: String) in d.map { format($0, p, timeZone) } ?? "" }
        var state = EnrollmentHomeScreen.State(
            coverURL: h?.studyProgram.coverImageUrl ?? "",
            programName: h?.studyProgram.name ?? input.name,
            programDescription: h?.studyProgram.description ?? "",
            memberCount: h?.memberCount ?? 0,
            authorName: h?.studyProgram.authorName ?? "",
            enrolledLabel: h.flatMap { MembersHomeMapper.parseDate($0.enrolledAt) }
                .map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? "",
            leaderName: h?.group.leader?.name ?? "",
            startMonth: f(start, "MMM"),
            startWeekday: f(start, "EEE"),
            startDay: f(start, "d"),
            endMonth: hasSchedule ? f(end, "MMM") : "",
            endWeekday: hasSchedule ? f(end, "EEE") : "",
            endDay: hasSchedule ? f(end, "d") : "",
            spanMonths: span.0,
            spanDays: span.1,
            dayMonths: dayDates.map { f($0, "MMM").uppercased() },
            dayWeekdays: dayDates.map { f($0, "EEE").uppercased() },
            dayNumbers: dayDates.map { f($0, "d") },
            dayDateStates: dayDates.map { d in d.map { cal.isDate($0, inSameDayAs: today) } == true ? "today" : "default" },
            dayPercents: days.map { Int($0.percent.rounded()) },
            dayLine1s: days.map { "\($0.lessonCount)" },
            dayLine2s: days.map { _ in invite },
            dayDetailsStates: days.map { _ in "lessonDay" },
            lessonNumbers: lessons.map(\.dayNumber),
            lessonTitles: lessons.map { MembersHomeMapper.nonEmpty($0.title) ?? "Day \($0.dayNumber)" },
            lessonMetaLabels: lessons.map { l in
                EnrollmentWire.date(ymd: l.date, in: timeZone).map { relativeLabel($0, today: today, calendar: cal) } ?? ""
            },
            lessonProgress: lessons.map { l in
                let isToday = EnrollmentWire.date(ymd: l.date, in: timeZone).map { cal.isDate($0, inSameDayAs: today) } ?? false
                return isToday ? l.progress : nil
            },
            lessonSlideImages: lessons.map { $0.activities.map { $0.thumbnailUrl ?? "" } },
            lessonSlideLabels: lessons.map { $0.activities.map(slideLabel) }
        )
        state.loading = input.loading && h == nil                                         // D14.4
        state.failed = input.failed && h == nil
        return state
    }

    /// T8 day line 2: `HH:mm` → `h:mma` lower-case ("7:30am"); null → "".
    static func inviteTime(_ smsTime: String?) -> String {
        guard let parts = smsTime?.split(separator: ":"), parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return "" }
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", h12, minute, hour < 12 ? "am" : "pm")
    }

    /// The span between the start and end cards: whole months, then the remaining days.
    static func span(from start: Date, to end: Date, calendar: Calendar) -> (months: Int, days: Int) {
        let c = calendar.dateComponents([.month, .day], from: start, to: end)
        return (c.month ?? 0, c.day ?? 0)
    }

    /// C-063 `metaLabel`: "Today" / "Tomorrow" / "Mon D".
    static func relativeLabel(_ date: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: today) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return format(date, "MMM d", calendar.timeZone)
    }

    /// VoiceOver only: "Read: Romans 1", "Video".
    private static func slideLabel(_ a: EnrollmentHome.Activity) -> String {
        let type = a.type.lowercased().capitalized
        guard let title = MembersHomeMapper.nonEmpty(a.title) else { return type }
        return "\(type): \(title)"
    }

    private static func zip2(_ a: Date?, _ b: Date?) -> (Date, Date)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private static func format(_ date: Date, _ pattern: String, _ zone: TimeZone) -> String {
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
```

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeContainer.swift`:

```swift
import SwiftUI

/// ui2-enrollments-browse §iphone: the pushed `.enrollmentHome` page (D20). It owns its ScrollView
/// and pins C-040 above it (`showsHeader: false`, the StudyProgramHomeContainer precedent). The store
/// renders at once under the pushed name; every visit reloads. "Edit schedule" and the calendar glyph
/// are hidden (`showsScheduleEditing: false`, P10); day-card, lesson and slide taps are inert.
struct EnrollmentHomeContainer: View {
    let enrollmentId: String
    let name: String

    static let pageTitle = "Enrollment"

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var loading = false
    @State private var failed = false
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var imagesSeeded = 0

    var body: some View {
        let mapped = EnrollmentHomeMapper.state(
            .init(name: name, home: AppState.shared.enrollmentHomes[enrollmentId], loading: loading, failed: failed),
            today: Date(), timeZone: .current)
        let _ = imagesSeeded
        let state = Self.cachedImages(mapped)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: Self.pageTitle,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            ScrollView(.vertical) {
                EnrollmentHomeScreen(
                    state: state,
                    showsHeader: false,
                    showsScheduleEditing: false,
                    onBack: { navigator.pop() },
                    onRetry: { Task { await reload() } }
                )
            }
            .scrollIndicators(.hidden)
            .pullDownRefresh { await reload() }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await reload() }
        .task(id: Self.imageURLs(mapped)) {
            if await UI2ImageLoader.seed(Self.imageURLs(mapped), context: "EnrollmentHomeContainer") { imagesSeeded += 1 }
        }
    }

    @MainActor
    private func reload() async {
        loading = true
        defer { loading = false }
        failed = !(await Self.load(id: enrollmentId, actions: EnrollmentActions(), state: .shared, onUnauthorized: signOut))
    }

    /// true = loaded. Cancelled → nothing; 401 → sign-out; anything else (a 404 included) keeps what
    /// is shown, console-only — the page's retry is pull-down.
    @MainActor
    static func load(id: String, actions: EnrollmentActions, state: AppState,
                     onUnauthorized: @MainActor () async -> Void) async -> Bool {
        do {
            try await actions.loadHome(id: id, forceRefresh: true)
            return true
        } catch {
            if GroupActions.isCancellation(error) { return true }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            state.recordError(error, context: "EnrollmentHomeContainer.loadHome")
            return false
        }
    }

    static func imageURLs(_ s: EnrollmentHomeScreen.State) -> [String] {
        ([s.coverURL] + s.lessonSlideImages.flatMap { $0 }).filter { !$0.isEmpty }
    }

    @MainActor
    static func cachedImages(_ mapped: EnrollmentHomeScreen.State) -> EnrollmentHomeScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        return s
    }

    private var signOut: @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EnrollmentHomeContainer.signOut", surface: false)
            }
        }
    }
}
```

`EnrollmentHomeHost.swift` — the body becomes:

```swift
    var body: some View {
        EnrollmentHomeContainer(enrollmentId: id, name: name)
    }
```

(and update its doc comment: "ui2-enrollments-browse R2: the `.enrollmentHome` destination — the enrollment page.")

Register and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; %w[EnrollmentHomeMapper.swift EnrollmentHomeContainer.swift].each { |f| add.("MakeReady/UI2/Containers/Enrollments", f, "MakeReady") }; p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (EnrollmentHomeMapperTests 7/7); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (if it flags `function_body_length` on `EnrollmentHomeMapper.state`, move the day-rail and lesson arrays into `private static func`s — no behaviour change)

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): the enrollment page on the home read (D20, R2)`

### Task 12: Checklist autosave — EnrollDraftSync and the six commit points
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §State Management · `/ios-error-surface` (the D26 banner with Retry; D30 banner) — SPEC D3, D4, D6, D21, D26, D30

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollDraftSync.swift` — the per-flow save engine (`EnrollDraftSync`) and its registry (`EnrollDraftSyncs`)
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectGroupContainer.swift:107-110` (`commit`)
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectProgramContainer.swift:77-80` (`commit`)
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectScheduleContainer.swift:21-27` (`onSelect`, when `applied`)
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelectValueContainers.swift:33,51,69` (invite time, sync, access)
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistContainer.swift:63-68` (`onAppear`: register this flow's sync)
- Test: `iphone/MakeReadyCaptureTests/EnrollDraftSyncTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the two new files (Steps 1 and 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes (Task 7): `EnrollmentDraftMapping.createBody(_:zone:)`, `.patchBody(from:to:zone:)`, `EnrollmentDraft.serverId/createdByName/serverUpdatedAt`. (Task 8): `AppState.enrollmentDraftBaselines`, `AppState.seedEnrollmentDraft(_:flowId:)`, `EnrollmentDraftActions.create(body:)`, `.update(id:body:)`, `.load(id:)`, `DraftWriteOutcome`, `APIHTTPError.details`. (Task 10): `EnrollDraftOpen.gone(flowId:draftId:error:pop:state:actions:)`. Existing: `AppState.updateEnrollmentDraft(_:_:)`, `recordError(_:context:surface:friendlyMessage:retry:)`, `GroupActions.isCancellation(_:)`, `AuthStatusPolicy.shouldSignOut(after:)`, `StubAPIClient`.
- Produces:
  - `@MainActor final class EnrollDraftSync { static let retryDelay: Duration; static let saveFailedMessage = "Couldn't save the draft"; init(flowId: UUID, state: AppState, actions: EnrollmentDraftActions, sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }); var onGone: @MainActor () -> Void; var onUnauthorized: @MainActor () async -> Void; private(set) var dirty: Bool; func changed(); func cancelPending(); func stop(); func flush() async }`
  - `@MainActor enum EnrollDraftSyncs { static func sync(for: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil) -> EnrollDraftSync; static func changed(_: UUID); static func cancelPending(_: UUID); static func stop(_: UUID); static func prune(keeping: Set<UUID>); static func isRegistered(_: UUID) -> Bool }`

- [ ] **Step 1: Write the failing test** — create and register `iphone/MakeReadyCaptureTests/EnrollDraftSyncTests.swift`:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollDraftSyncTests.swift", "MakeReadyCaptureTests"); p.save'
```

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D3/D4/D6/D26/D30: the checklist's autosave — first save, PATCH order and
/// coalescing, retry-then-banner once per dirty episode, 409 re-seed, 404 gone, cancel.
@MainActor
final class EnrollDraftSyncTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private var sleeps = 0

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        sleeps = 0
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func wire(_ id: String, program: String = "p1", start: String? = nil, schedule: [String]? = nil) -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: program, startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: nil, timezone: nil, syncMode: nil, lessonAccess: nil,
                  createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
    }

    private func draftJSON(_ id: String, program: String = "p1", sms: String? = nil) -> String {
        let smsValue = sms.map { "\"\($0)\"" } ?? "null"
        return #"{"success":true,"draft":{"id":"\#(id)","groupId":"g1","studyProgramId":"\#(program)","startDate":null,"enabledDays":null,"overriddenDates":null,"scheduleDates":null,"smsTime":\#(smsValue),"timezone":null,"syncMode":null,"lessonAccess":null,"createdBy":{"id":"u1","name":"Luke Keith"},"createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-03T00:00:00.000Z"}}"#
    }

    private var actions: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }

    private func sync(_ flowId: UUID) -> EnrollDraftSync {
        EnrollDraftSync(flowId: flowId, state: state, actions: actions, sleep: { [weak self] _ in self?.sleeps += 1 })
    }

    private func patches() -> [[String: Any]] { api.calls.filter { $0.method == "PATCH" }.compactMap(\.body) }

    func testNothingIsSavedUntilGroupAndProgramAreBothSet() async {          // D3
        let st = state!
        let id = st.startEnrollmentDraft(groupId: "g1", studyProgramId: nil)
        let s = sync(id)
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        st.updateEnrollmentDraft(id) { $0.setProgram("p1") }
        s.changed(); await s.flush()
        XCTAssertEqual(api.callCount("POST", "/api/enrollment-drafts"), 1)
        XCTAssertEqual(Set(api.calls[0].body?.keys.map { $0 } ?? []), ["groupId", "studyProgramId"])
        XCTAssertEqual(st.enrollmentDrafts[id]?.serverId, "d1")              // D21: adopted, flowId unchanged
        XCTAssertEqual(st.enrollmentDrafts[id]?.createdByName, "Luke Keith")
        XCTAssertEqual(st.enrollmentDraftsByGroupId["g1"]?.map(\.id), ["d1"])
    }

    func testChangesMadeWhileThePostIsInFlightArePatchedOnceItReturns() async {  // D4
        let st = state!
        api.stub("POST", "/api/enrollment-drafts", json: draftJSON("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        let id = st.startEnrollmentDraft(groupId: "g1", studyProgramId: "p1")
        let s = sync(id)
        var fired = false
        api.beforeReturn = { endpoint, _ in
            guard endpoint == "/api/enrollment-drafts", !fired else { return }
            fired = true
            st.updateEnrollmentDraft(id) { $0.smsTime = "07:30"; $0.timezone = "America/Chicago" }
            s.changed()                                                      // in flight → coalesced
        }
        s.changed()
        await s.flush()
        XCTAssertEqual(api.calls.map(\.method), ["POST", "PATCH"])
        XCTAssertEqual(Set(patches()[0].keys), ["smsTime", "timezone"])
    }

    func testChangesWhileAPatchIsInFlightCoalesceIntoTheNextPatch() async {    // D4: one in flight
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1"))
        let s = sync(id)
        var first = true
        api.beforeReturn = { _, _ in
            guard first else { return }
            first = false
            st.updateEnrollmentDraft(id) { $0.syncMode = "AUTO" }
            s.changed()
            st.updateEnrollmentDraft(id) { $0.lessonAccess = "all-at-once" }
            s.changed()
        }
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertEqual(Set(patches()[0].keys), ["smsTime"])
        XCTAssertEqual(Set(patches()[1].keys), ["syncMode", "lessonAccess"])
        XCTAssertEqual(patches()[1]["lessonAccess"] as? String, "ALL_AT_ONCE")
    }

    func testAProgramChangeSendsScheduleDatesNull() async {                  // D4
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"]))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", program: "p2"))
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.setProgram("p2") }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().first?["studyProgramId"] as? String, "p2")
        XCTAssertTrue(patches().first?["scheduleDates"] is NSNull)
        XCTAssertNil(patches().first?["startDate"])                           // the seed is kept
    }

    func testAFailedPatchRetriesOnceAfterTheDelay() async {                   // D26
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        var failures = 1
        api.errorFor = { endpoint, _ in
            guard endpoint == "/api/enrollment-drafts/d1", failures > 0 else { return nil }
            failures -= 1
            return APIError.serverError("offline")
        }
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertEqual(sleeps, 1)
        XCTAssertEqual(EnrollDraftSync.retryDelay, .seconds(2))
        XCTAssertFalse(s.dirty)
        XCTAssertNil(st.activeSurfacedError)
    }

    func testASecondFailureBannersOncePerDirtyEpisodeAndResendsEverything() async {   // D26
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollment-drafts/d1" ? APIError.serverError("offline") : nil }
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 2)
        XCTAssertTrue(s.dirty)
        XCTAssertEqual(st.activeSurfacedError?.message, "Couldn't save the draft")
        XCTAssertNotNil(st.activeSurfacedError?.retry)
        st.activeSurfacedError = nil
        st.updateEnrollmentDraft(id) { $0.syncMode = "AUTO" }                  // a later Select while dirty
        s.changed(); await s.flush()
        XCTAssertEqual(patches().count, 4)
        XCTAssertEqual(Set(patches()[3].keys), ["smsTime", "syncMode"])
        XCTAssertNil(st.activeSurfacedError)                                   // no second banner
        api.errorFor = nil
        api.stub("PATCH", "/api/enrollment-drafts/d1", json: draftJSON("d1", sms: "07:30"))
        s.changed(); await s.flush()                                           // Retry
        XCTAssertEqual(Set(patches()[4].keys), ["smsTime", "syncMode"])
        XCTAssertFalse(s.dirty)
    }

    func testAConflictReseedsThisFlowInPlace() async {                        // D6, also with a picker on top
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { endpoint, _ in
            endpoint == "/api/enrollment-drafts/d1"
                ? APIHTTPError(status: 409, message: "draft_exists", details: ["draftId": "d9"]) : nil
        }
        api.stub("GET", "/api/enrollment-drafts/d9", json: draftJSON("d9", program: "p3", sms: "06:00"))
        var gone = false
        let s = sync(id)
        s.onGone = { gone = true }
        st.updateEnrollmentDraft(id) { $0.setProgram("p3") }
        s.changed(); await s.flush()
        let d = st.enrollmentDrafts[id]
        XCTAssertEqual(d?.serverId, "d9")
        XCTAssertEqual(d?.studyProgramId, "p3")
        XCTAssertEqual(d?.smsTime, "06:00")
        XCTAssertEqual(d?.phase, .checklist)
        XCTAssertEqual(st.enrollmentDraftBaselines[id], d)
        XCTAssertFalse(gone)                                                   // no navigation
        XCTAssertEqual(api.callCount("PATCH", "/api/enrollment-drafts/d1"), 1) // a 409 is not retried
    }

    func testA404EndsTheFlowWithTheGoneBanner() async {                       // D30
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        st.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var gone = false
        let s = sync(id)
        s.onGone = { gone = true }
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed(); await s.flush()
        XCTAssertNil(st.enrollmentDrafts[id])
        XCTAssertEqual(st.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertEqual(st.activeSurfacedError?.message, "This draft no longer exists")
        XCTAssertTrue(gone)
        XCTAssertEqual(patches().count, 1)                                    // a 404 is not retried
    }

    func testStopCancelsPendingWorkForGood() async {                          // D30: Discard/Enroll/Back
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        let s = sync(id)
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30" }
        s.changed()
        s.stop()
        await s.flush()
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testNothingIsSavedOncePastTheChecklist() async {                     // processing/enrolled never PATCH
        let st = state!
        let id = st.seedEnrollmentDraft(wire("d1"))
        st.updateEnrollmentDraft(id) { $0.smsTime = "07:30"; $0.phase = .processing }
        let s = sync(id)
        s.changed(); await s.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testTheRegistryKeepsOneSyncPerFlowAndPruneStopsTheRest() {
        let a = UUID(), b = UUID()
        let sa = EnrollDraftSyncs.sync(for: a, state: state, actions: actions)
        XCTAssertTrue(EnrollDraftSyncs.sync(for: a) === sa)
        _ = EnrollDraftSyncs.sync(for: b, state: state, actions: actions)
        EnrollDraftSyncs.prune(keeping: [a])
        XCTAssertTrue(EnrollDraftSyncs.isRegistered(a))
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(b))
        EnrollDraftSyncs.stop(a)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(a))
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "cannot find 'EnrollDraftSync' in scope"

- [ ] **Step 3: Write the minimal implementation**

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollDraftSync.swift`:

```swift
import Foundation

/// ui2-enrollments-browse D3/D4/D6/D26/D30: one checklist flow's autosave. A commit point calls
/// `changed()`; the sync sends D3's POST once the draft holds a group and a program (adopting the
/// server id, D21), then a PATCH of what differs from the server's last acknowledged copy
/// (`AppState.enrollmentDraftBaselines`). At most one request is in flight: changes made meanwhile
/// are picked up when it returns. A failure retries once after `retryDelay`; a second failure marks
/// the flow dirty and banners once per dirty episode (D26). 409 re-seeds the flow in place (D6);
/// 404 is D30's gone path. Never a timer for UI — the only wait is the retry's `sleep`.
@MainActor
final class EnrollDraftSync {
    static let retryDelay: Duration = .seconds(2)
    static let saveFailedMessage = "Couldn't save the draft"

    let flowId: UUID
    private let state: AppState
    private let actions: EnrollmentDraftActions
    private let sleep: @MainActor (Duration) async throws -> Void
    /// D30: pop the checklist back to the page that pushed it (set by the checklist container).
    var onGone: @MainActor () -> Void = {}
    /// ui2-shell D27: a 401 ends the session.
    var onUnauthorized: @MainActor () async -> Void = {}

    private(set) var dirty = false
    private var bannerShown = false
    private var stopped = false
    private var inFlight: Task<Void, Never>?
    private var generation = 0

    init(flowId: UUID, state: AppState, actions: EnrollmentDraftActions,
         sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.flowId = flowId
        self.state = state
        self.actions = actions
        self.sleep = sleep
    }

    /// A commit point wrote the draft, or Retry was tapped.
    func changed() {
        guard !stopped, inFlight == nil else { return }
        generation += 1
        let mine = generation
        inFlight = Task { [weak self] in
            await self?.pump()
            if self?.generation == mine { self?.inFlight = nil }
        }
    }

    /// Drop the request or retry in flight; the unsent fields stay unsent until the next `changed()`.
    func cancelPending() {
        inFlight?.cancel()
        inFlight = nil
        generation += 1
    }

    /// Discard, Enroll (success) and Back: nothing more is ever sent for this flow.
    func stop() {
        stopped = true
        cancelPending()
    }

    /// Tests: wait until the sync is idle.
    func flush() async {
        while let task = inFlight { await task.value }
    }

    private func pump() async {
        var retried = false
        while !Task.isCancelled, !stopped,
              let current = state.enrollmentDrafts[flowId], current.phase == .checklist {
            do {
                if let serverId = current.serverId {
                    let base = state.enrollmentDraftBaselines[flowId] ?? EnrollmentDraft(id: flowId)
                    let body = EnrollmentDraftMapping.patchBody(from: base, to: current)
                    if body.isEmpty { settle(); return }
                    let outcome = try await actions.update(id: serverId, body: body)
                    guard !Task.isCancelled else { return }
                    try await apply(outcome, sent: current)
                } else {
                    guard current.groupId != nil, current.studyProgramId != nil else { return }      // D3
                    let outcome = try await actions.create(body: EnrollmentDraftMapping.createBody(current))
                    guard !Task.isCancelled else { return }
                    try await apply(outcome, sent: current)
                }
                retried = false
            } catch {
                if Task.isCancelled || GroupActions.isCancellation(error) { return }
                if AuthStatusPolicy.shouldSignOut(after: error) {
                    await onUnauthorized()
                    return
                }
                if let http = error as? APIHTTPError, http.status == 404 {                         // D30
                    EnrollDraftOpen.gone(flowId: flowId, draftId: current.serverId, error: error,
                                         pop: onGone, state: state, actions: actions)
                    return
                }
                if !retried {                                                                     // D26
                    retried = true
                    do { try await sleep(Self.retryDelay) } catch { return }
                    continue
                }
                markDirty(error)
                return
            }
        }
    }

    private func apply(_ outcome: DraftWriteOutcome, sent: EnrollmentDraft) async throws {
        switch outcome {
        case .saved(let wire):
            var base = sent
            base.serverId = wire.id
            base.createdByName = wire.createdBy?.name
            base.serverUpdatedAt = wire.updatedAt
            state.enrollmentDraftBaselines[flowId] = base
            state.updateEnrollmentDraft(flowId) {
                $0.serverId = wire.id
                $0.createdByName = wire.createdBy?.name
                $0.serverUpdatedAt = wire.updatedAt
            }
        case .exists(let draftId):                                                                 // D6
            let wire = try await actions.load(id: draftId)
            guard !Task.isCancelled else { return }
            state.seedEnrollmentDraft(wire, flowId: flowId)
        }
        settle()
    }

    private func settle() {
        dirty = false
        bannerShown = false
    }

    private func markDirty(_ error: Error) {
        dirty = true
        guard !bannerShown else { return }
        bannerShown = true
        state.recordError(error, context: "EnrollDraftSync.save", surface: true,
                          friendlyMessage: Self.saveFailedMessage,
                          retry: { [weak self] in Task { @MainActor in self?.changed() } })
    }
}

/// One `EnrollDraftSync` per open flow, shared by the checklist and its six pickers.
@MainActor
enum EnrollDraftSyncs {
    private static var syncs: [UUID: EnrollDraftSync] = [:]

    static func sync(for flowId: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil) -> EnrollDraftSync {
        if let existing = syncs[flowId] { return existing }
        let state = state ?? .shared
        let created = EnrollDraftSync(flowId: flowId, state: state, actions: actions ?? EnrollmentDraftActions(state: state))
        syncs[flowId] = created
        return created
    }

    /// D4: called by each picker right after its Select/Save wrote the draft.
    static func changed(_ flowId: UUID) { sync(for: flowId).changed() }

    static func cancelPending(_ flowId: UUID) { syncs[flowId]?.cancelPending() }

    static func stop(_ flowId: UUID) { syncs.removeValue(forKey: flowId)?.stop() }

    /// The shell's prune: flows whose checklist left every stack stop saving (never a DELETE, R4).
    static func prune(keeping ids: Set<UUID>) {
        for id in Array(syncs.keys) where !ids.contains(id) { stop(id) }
    }

    static func isRegistered(_ flowId: UUID) -> Bool { syncs[flowId] != nil }
}
```

The six commit points — one line each, after the draft write and before the pop:

`EnrollSelectGroupContainer.swift`:

```swift
    private func commit(_ groupId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.groupId = groupId }   // group change cascades nothing
        EnrollDraftSyncs.changed(flowId)                                        // ui2-enrollments-browse D3/D4
        navigator.popIfTop(.enrollSelectGroup(flowId: flowId))
    }
```

`EnrollSelectProgramContainer.swift`:

```swift
    private func commit(_ programId: String) {
        AppState.shared.updateEnrollmentDraft(flowId) { $0.setProgram(programId) }
        EnrollDraftSyncs.changed(flowId)                                        // ui2-enrollments-browse D3/D4
        navigator.popIfTop(.enrollSelectProgram(flowId: flowId))
    }
```

`EnrollSelectScheduleContainer.swift` (`onSelect`):

```swift
                if applied {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectSchedule(flowId: flowId))
                }
```

`EnrollSelectValueContainers.swift` — invite time:

```swift
            onSelect: { time, zone in
                AppState.shared.updateEnrollmentDraft(flowId) { EnrollValueWrite.inviteTime(time, timezone: zone, into: &$0) }
                EnrollDraftSyncs.changed(flowId)                                // ui2-enrollments-browse D4
                navigator.popIfTop(.enrollSelectInviteTime(flowId: flowId))
            }
```

sync and access (same shape in both `onSave`s):

```swift
                if saved {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectSync(flowId: flowId))
                }
```

```swift
                if saved {
                    EnrollDraftSyncs.changed(flowId)                            // ui2-enrollments-browse D4
                    navigator.popIfTop(.enrollSelectAccess(flowId: flowId))
                }
```

`EnrollChecklistContainer.swift` — extend the existing `.onAppear`:

```swift
        .onAppear {
            // A5: no swipe-back while the POST is in flight.
            backSwipe?.blocksBackSwipe = { AppState.shared.enrollmentDrafts[flowId]?.phase == .processing }
            // ui2-enrollments-browse D3/D30: this flow's autosave; a gone draft pops to the pusher.
            let entryDepth = max(0, navigator.depth() - 1)
            let sync = EnrollDraftSyncs.sync(for: flowId)
            sync.onGone = { [navigator] in navigator.popTo(entryDepth) }
            sync.onUnauthorized = { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                }
            }
            sync.changed()
        }
```

Register and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReady/UI2/Containers/Enrollments", "EnrollDraftSync.swift", "MakeReady"); p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (EnrollDraftSyncTests 11/11; EnrollSubmitTests, EnrollPickerWarningsTests still green); `grep -c "EnrollDraftSyncs.changed" iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelect*.swift` → the four files total 6; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): checklist autosave with retry, conflict re-seed and gone handling (D3, D4, D6, D26, D30)`

### Task 13: Stale start on open, Discard enrollment, draftId on Enroll, Back keeps the server draft
App: iphone
Phase: 5
Recipe: `/present-overlay` (UI 2.0 form: `.actionMenuPresentation` hosted by the shell's `.ui2OverlayHost()`, the `GroupDetailContainer.swift:177` C-066 precedent — never `.sheet`/`.fullScreenCover`/`asyncAfter`) · `/ios-error-surface` — SPEC D2, D9, D10, D11, D23, D29, D30, F10, R4 · build-time risk F1: start only once d2m change cmvt1w9a9000jv0sx8bflv7gc (groups-enroll-program: `onDiscard: (() -> Void)?`, `public static func completedSteps(_ state: State) -> Int`) is done and its files are committed on this branch

Read `iphone/MakeReadyUI/Screens/Groups/GroupsEnrollProgramScreen.swift` as d2m landed it FIRST. This block passes `onDiscard:` as the last argument of `GroupsEnrollProgramScreen(state:scrollsContent:onBack:onSelectStep:onEnroll:onDone:onDiscard:)`; if d2m named or placed it differently, use d2m's and say so in your report. Never edit a file under `iphone/MakeReadyUI/`.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollDiscard.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistContainer.swift:5-101` — `EnrollSubmit.run` sends `draftId` and cancels/stops the sync; the container gains `onDiscard` + the C-066 menu, `offersDiscard(_:)`, `endFlow(_:state:)`
- Modify: `iphone/MakeReady/State/AppState.swift` — `seedEnrollmentDraft(_:flowId:today:)` applies D9's stale clear to the draft AND its baseline (D23: no request)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:125-127` — the prune also stops the pruned flows' syncs
- Test: `iphone/MakeReadyCaptureTests/EnrollDraftLifecycleTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — register the two new files (Steps 1 and 3), then `ruby iphone/scripts/capture-targets.rb`

**Interfaces:**
- Consumes (Task 7): `EnrollmentDraft.clearStaleStart(today:calendar:)`. (Task 8): `AppState.seedEnrollmentDraft(_:flowId:)`, `.enrollmentDraftBaselines`, `.enrollmentDraftsByGroupId`, `EnrollmentDraftActions.delete(id:)`, `EnrollmentActions.createEnrollment(… draftId:)`. (Task 10): `EnrollDraftOpen.gone(...)`. (Task 12): `EnrollDraftSync`, `EnrollDraftSyncs.sync(for:state:actions:)`, `.cancelPending(_:)`, `.stop(_:)`, `.prune(keeping:)`, `.isRegistered(_:)`. Existing: `EnrollSubmit.run(flowId:actions:state:onUnauthorized:)`, `ActionMenuOverlay`, `.actionMenuPresentation(isPresented:onDismiss:menu:)`.
- Produces: `@discardableResult func AppState.seedEnrollmentDraft(_ wire: DraftWire, flowId: UUID? = nil, today: Date = Date()) -> UUID` (signature-compatible with Task 8's); `@MainActor enum EnrollDiscard { static let label = "Discard enrollment"; static let failedMessage = "Couldn't discard the draft"; static let action: ActionMenuOverlay.ActionItem; @discardableResult static func run(flowId: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil, pop: @escaping () -> Void, onUnauthorized: @escaping @MainActor () async -> Void = {}) async -> Bool }`; `static func EnrollChecklistContainer.offersDiscard(_ draft: EnrollmentDraft) -> Bool`; `@MainActor static func EnrollChecklistContainer.endFlow(_ flowId: UUID, state: AppState? = nil)`

- [ ] **Step 1: Write the failing test** — create and register `iphone/MakeReadyCaptureTests/EnrollDraftLifecycleTests.swift`:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReadyCaptureTests", "EnrollDraftLifecycleTests.swift", "MakeReadyCaptureTests"); p.save'
```

```swift
import XCTest
@testable import MakeReady

/// ui2-enrollments-browse D9/D23 (stale start on open), D10/D29/D30 (Discard), D11/F10 (Enroll),
/// D2/R4 (Back and prune end the LOCAL flow only).
@MainActor
final class EnrollDraftLifecycleTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func day(_ ymd: String) -> Date { EnrollmentWire.date(ymd: ymd)! }

    private func wire(_ id: String, start: String? = nil, schedule: [String]? = nil, complete: Bool = false) -> DraftWire {
        DraftWire(id: id, groupId: "g1", studyProgramId: "p1", startDate: start, enabledDays: schedule == nil ? nil : ["Mon"],
                  overriddenDates: nil, scheduleDates: schedule, smsTime: complete ? "07:30" : nil,
                  timezone: complete ? "America/Chicago" : nil, syncMode: complete ? "AUTO" : nil,
                  lessonAccess: complete ? "ALL_AT_ONCE" : nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
    }

    private var actions: EnrollmentDraftActions { EnrollmentDraftActions(api: api, state: state) }

    // MARK: D9/D23

    func testOpeningAStaleDraftClearsTheScheduleLocallyAndSendsNothing() async {
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-01", schedule: ["2035-01-01"], complete: true),
                                             today: day("2035-01-06"))
        let d = state.enrollmentDrafts[flow]
        XCTAssertNil(d?.startDate)
        XCTAssertEqual(d?.scheduleDates, [])
        XCTAssertNil(d?.endDate)
        XCTAssertEqual(d?.enabledDays, [1])                                    // the picker's seed stays
        XCTAssertEqual(d?.smsTime, "07:30")                                    // every other row keeps its value
        XCTAssertEqual(state.enrollmentDraftBaselines[flow], d)               // so no PATCH carries the clear
        let sync = EnrollDraftSync(flowId: flow, state: state, actions: actions, sleep: { _ in })
        sync.changed(); await sync.flush()
        XCTAssertTrue(api.calls.isEmpty)
    }

    func testAFreshDraftKeepsItsSchedule() {
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"]), today: day("2035-01-06"))
        XCTAssertEqual(state.enrollmentDrafts[flow]?.scheduleDone, true)
    }

    // MARK: D10/D29/D30 Discard

    func testDiscardIsOfferedOnlyForASavedDraftOnTheChecklist() {
        var d = EnrollmentDraft(id: UUID(), groupId: "g1", studyProgramId: "p1")
        XCTAssertFalse(EnrollChecklistContainer.offersDiscard(d))             // not saved yet
        d.serverId = "d1"
        XCTAssertTrue(EnrollChecklistContainer.offersDiscard(d))
        d.phase = .processing
        XCTAssertFalse(EnrollChecklistContainer.offersDiscard(d))
        XCTAssertEqual(EnrollDiscard.action.label, "Discard enrollment")
        XCTAssertEqual(EnrollDiscard.action.tone, .destructive)
    }

    func testDiscardDeletesEndsTheFlowAndPops() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        api.stub("DELETE", "/api/enrollment-drafts/d1", json: #"{"success":true}"#)
        var popped = false
        let ok = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertTrue(ok)
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertTrue(popped)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }

    func testDiscardFailureBannersWithRetryAndStays() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { _, _ in APIError.serverError("offline") }
        var popped = false
        let ok = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertFalse(ok)
        XCTAssertNotNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't discard the draft")
        XCTAssertNotNil(state.activeSurfacedError?.retry)
        XCTAssertFalse(popped)
        EnrollDraftSyncs.stop(flow)
    }

    func testDiscardOfAGoneDraftIsTheGonePath() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Not found") }
        var popped = false
        _ = await EnrollDiscard.run(flowId: flow, state: state, actions: actions, pop: { popped = true })
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertEqual(state.activeSurfacedError?.message, "This draft no longer exists")
        XCTAssertTrue(popped)
    }

    // MARK: D11/F10 Enroll

    private let created = #"{"success":true,"enrollment":{"id":"e9","groupId":"g1","studyProgramId":"p1","startDate":"2035-01-08T06:00:00.000Z","endDate":"2035-01-08T06:00:00.000Z","enabledDays":"[\"Mon\"]","createdAt":"2035-01-01T00:00:00.000Z","updatedAt":"2035-01-01T00:00:00.000Z","lessonAccess":"ALL_AT_ONCE","syncMode":"AUTO"}}"#

    func testEnrollSendsTheDraftIdAndDropsTheStoredDraft() async {
        api.errorFor = { endpoint, _ in endpoint == "/api/enrollments" ? nil : APIError.serverError("refresh not stubbed") }
        api.stub("POST", "/api/enrollments", json: created)
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"], complete: true),
                                             today: day("2035-01-06"))
        state.enrollmentDraftsByGroupId["g1"] = [wire("d1")]
        let ok = await EnrollSubmit.run(flowId: flow, actions: EnrollmentActions(api: api, state: state), state: state,
                                        onUnauthorized: {})
        XCTAssertTrue(ok)
        XCTAssertEqual(api.calls.first { $0.endpoint == "/api/enrollments" }?.body?["draftId"] as? String, "d1")
        XCTAssertEqual(state.enrollmentDraftsByGroupId["g1"], [])
        XCTAssertEqual(state.enrollmentDrafts[flow]?.phase, .enrolled)
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }

    func testASecondEnrollWhileProcessingSendsNothing() async {               // F10
        let flow = state.seedEnrollmentDraft(wire("d1", start: "2035-01-08", schedule: ["2035-01-08"], complete: true),
                                             today: day("2035-01-06"))
        state.updateEnrollmentDraft(flow) { $0.phase = .processing }
        let ok = await EnrollSubmit.run(flowId: flow, actions: EnrollmentActions(api: api, state: state), state: state,
                                        onUnauthorized: {})
        XCTAssertFalse(ok)
        XCTAssertTrue(api.calls.isEmpty)
    }

    // MARK: D2/R4 Back + prune

    func testBackEndsTheLocalFlowCancelsPendingSavesAndNeverDeletes() async {
        let flow = state.seedEnrollmentDraft(wire("d1"))
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: actions)
        state.updateEnrollmentDraft(flow) { $0.smsTime = "07:30" }               // an unsent change
        EnrollChecklistContainer.endFlow(flow, state: state)
        sync.changed(); await sync.flush()
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertNil(state.enrollmentDraftBaselines[flow])
        XCTAssertTrue(api.calls.isEmpty)                                      // no PATCH, and never a DELETE
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "extra argument 'today' in call", "cannot find 'EnrollDiscard' in scope", "type 'EnrollChecklistContainer' has no member 'offersDiscard'"

- [ ] **Step 3: Write the minimal implementation**

`AppState.swift` — replace `seedEnrollmentDraft`:

```swift
    /// D21: a flow seeded from a server draft — a new flow, or `flowId` overwritten in place (D6).
    /// D9/D23: a schedule that starts before `today` is cleared in the LOCAL draft and its baseline
    /// alike, so no request carries the clear; the server keeps its schedule until the next
    /// Schedule Select's PATCH.
    @discardableResult
    func seedEnrollmentDraft(_ wire: DraftWire, flowId: UUID? = nil, today: Date = Date()) -> UUID {
        let id = flowId ?? UUID()
        var draft = EnrollmentDraftMapping.draft(wire, flowId: id)
        draft.clearStaleStart(today: today)
        enrollmentDrafts[id] = draft
        enrollmentDraftBaselines[id] = draft
        return id
    }
```

`iphone/MakeReady/UI2/Containers/Enrollments/EnrollDiscard.swift`:

```swift
import SwiftUI

/// ui2-enrollments-browse D10/D29/D30: Discard enrollment — DELETE the saved draft, end the local
/// flow, pop to the page that pushed the checklist. A failure keeps the page with a Retry banner; a
/// 404 is D30's gone path. Any pending autosave is cancelled first so no PATCH races the DELETE.
@MainActor
enum EnrollDiscard {
    static let label = "Discard enrollment"
    static let failedMessage = "Couldn't discard the draft"
    /// D29: the C-066 menu's one row; its Done keeps editing.
    static let action = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: label, tone: .destructive)

    @discardableResult
    static func run(flowId: UUID, state: AppState? = nil, actions: EnrollmentDraftActions? = nil,
                    pop: @escaping () -> Void,
                    onUnauthorized: @escaping @MainActor () async -> Void = {}) async -> Bool {
        let state = state ?? .shared
        let actions = actions ?? EnrollmentDraftActions(state: state)
        guard let draft = state.enrollmentDrafts[flowId], draft.phase == .checklist,
              let serverId = draft.serverId else { return false }
        EnrollDraftSyncs.cancelPending(flowId)
        do {
            try await actions.delete(id: serverId)
            EnrollDraftSyncs.stop(flowId)
            state.endEnrollmentDraft(flowId)
            pop()
            return true
        } catch {
            if GroupActions.isCancellation(error) { return false }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return false
            }
            if let http = error as? APIHTTPError, http.status == 404 {
                EnrollDraftSyncs.stop(flowId)
                EnrollDraftOpen.gone(flowId: flowId, draftId: serverId, error: error, pop: pop, state: state, actions: actions)
                return false
            }
            state.recordError(error, context: "EnrollChecklistContainer.discard", surface: true,
                              friendlyMessage: failedMessage,
                              retry: {
                                  Task { @MainActor in
                                      await run(flowId: flowId, state: state, actions: actions, pop: pop,
                                                onUnauthorized: onUnauthorized)
                                  }
                              })
            return false
        }
    }
}
```

`EnrollChecklistContainer.swift` — in `EnrollSubmit.run`, the createEnrollment call and its success path:

```swift
        state.updateEnrollmentDraft(flowId) { $0.phase = .processing }
        EnrollDraftSyncs.cancelPending(flowId)                       // ui2-enrollments-browse D30: no PATCH after Enroll
        do {
            _ = try await actions.createEnrollment(
                groupId: groupId, studyProgramId: programId, startDate: start,
                enabledDays: EnrollmentWire.dayNames(d.enabledDays), smsTime: smsTime,
                timezone: d.timezone ?? TimeZone.current.identifier,
                syncMode: syncMode == "AUTO" ? .auto : .off,
                scheduleDates: d.scheduleDates, lessonAccess: access,
                draftId: d.serverId)                                 // D11: the server deletes the draft
            state.updateEnrollmentDraft(flowId) { $0.phase = .enrolled }
            EnrollDraftSyncs.stop(flowId)
            return true
```

In `EnrollChecklistContainer`: add the state, pass `onDiscard`, present the menu, and route Back through `endFlow`:

```swift
    /// D10: the Discard confirmation menu is up.
    @State private var discardMenuOpen = false
```

```swift
        GroupsEnrollProgramScreen(
            state: EnrollChecklistMapper.state(draft,
                                               group: draft.groupId.flatMap { app.groups[$0] },
                                               program: draft.studyProgramId.flatMap { app.programs[$0] }),
            scrollsContent: true,              // the checklist scrolls under the pinned header
            onBack: leave,
            onSelectStep: { navigator.push(Self.destination(for: $0, flowId: flowId)) },
            onEnroll: enroll,
            onDone: leave,
            // ui2-enrollments-browse D10: only while a saved draft backs the checklist (nil = no button).
            onDiscard: Self.offersDiscard(draft) ? { discardMenuOpen = true } : nil
        )
        .ui2PushedPageFill()
        // D10/D29: one red row; Done keeps editing. Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [EnrollDiscard.action],
                onSelect: { _ in
                    discardMenuOpen = false
                    Task { @MainActor in
                        await EnrollDiscard.run(flowId: flowId,
                                                pop: { navigator.popIfTop(.enrollChecklist(flowId: flowId)) },
                                                onUnauthorized: { [authManager] in
                                                    do { try await authManager.signOut() } catch {
                                                        AppState.shared.recordError(error, context: "EnrollChecklistContainer.signOut", surface: false)
                                                    }
                                                })
                    }
                },
                onDone: { discardMenuOpen = false }
            )
        }
```

```swift
    /// D10: the button shows while a saved draft backs the checklist and it is still a checklist.
    static func offersDiscard(_ draft: EnrollmentDraft) -> Bool {
        draft.serverId != nil && draft.phase == .checklist
    }

    /// D2/R4: Back (and Done after enrolling) ends the LOCAL flow only — a saved draft stays on the
    /// server and is never DELETEd here; D30: any pending PATCH or retry is cancelled.
    @MainActor
    static func endFlow(_ flowId: UUID, state: AppState? = nil) {
        EnrollDraftSyncs.stop(flowId)
        (state ?? .shared).endEnrollmentDraft(flowId)
    }

    private func leave() {
        Self.endFlow(flowId)
        navigator.popIfTop(.enrollChecklist(flowId: flowId))
    }
```

`UI2Shell.swift` — the prune modifier:

```swift
        // ui2-enrollment-create D13: a checklist that left every stack (swipe-back, Home re-tap)
        // takes its LOCAL draft with it. ui2-enrollments-browse D2/R4: and its autosave stops —
        // a saved draft stays on the server; the prune never DELETEs.
        .onChange(of: model.enrollmentFlowIds) { _, ids in
            AppState.shared.pruneEnrollmentDrafts(keeping: ids)
            EnrollDraftSyncs.prune(keeping: ids)
        }
```

Register and re-sync:

```bash
ruby -rxcodeproj -e 'p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); add = ->(group, file, target) { ref = p.main_group.find_subpath(group, false).new_reference(file); p.targets.find { |t| t.name == target }.add_file_references([ref]) }; add.("MakeReady/UI2/Containers/Enrollments", "EnrollDiscard.swift", "MakeReady"); p.save' && ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (EnrollDraftLifecycleTests 10/10; EnrollSubmitTests, EnrollDraftSyncTests, EnrollDraftOpenTests still green); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): stale start on open, Discard enrollment, draftId on Enroll, Back keeps the draft (D9, D10, D11, D23, D29)`

### Task 14: Group page — draft rows after the enrollments, row taps open the enrollment or the draft
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §State Management · `/push-page` — SPEC D7(b), D14.2, D19, D21, D28, R3, F6 · build-time risk F1: start only once d2m change cmvt1w5iu000av0sx172y76el (groups-detail: `programDraftLabels`/`programDraftStarters` on the Enrollments rows; the stat and «N» count only `""` rows; taps via the existing `onOpenEnrollment(index)`) is done and its files are committed on this branch · build-time risk F1: start only once d2m change cmvt1w9a9000jv0sx8bflv7gc (groups-enroll-program: `public static func completedSteps(_ state: State) -> Int`) is done and its files are committed on this branch

Read `iphone/MakeReadyUI/Screens/Groups/GroupsDetailScreen.swift` as d2m landed it FIRST. This block codes against `GroupsDetailScreen.State.programDraftLabels: [String]` and `.programDraftStarters: [String]` (defaulted, one entry per Enrollments row) and the existing `onOpenEnrollment: (Int) -> Void`. If d2m named them differently, use d2m's and say so in your report. Never edit a file under `iphone/MakeReadyUI/`.

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailMapper.swift:19-29,55-110` — `Input.drafts`, `Input.programsById`, `Output.enrollmentTargets` + `enrollmentTarget(atRow:)`, draft rows appended after the enrollments
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift:47-70` (pass `onOpenEnrollment`), `:205-219` (`input` reads the drafts and their programs), `:225-245` (`load` lists the group's drafts)
- Test: `iphone/MakeReadyCaptureTests/GroupDetailMapperTests.swift` (existing file, already in the test target)

**Interfaces:**
- Consumes (Task 7): `DraftWire`, `EnrollmentWireRef`, `EnrollmentDraftMapping.draft(_:flowId:zone:)`, `EnrollmentDraft.clearStaleStart(today:calendar:)`. (Task 8): `AppState.enrollmentDraftsByGroupId`, `EnrollmentDraftActions.listByGroup(groupId:)`. (Task 10): `EnrollmentRowTarget`, `EnrollDraftOpen.route(_:navigator:)`, `EnrollmentsHomeMapper.draftCompletedSteps(_:group:program:groupName:programName:today:timeZone:)`, `.draftLabel(completed:)`, `.starterLabel(_:)`. Existing: `ProgramActions().loadPrograms()`, `EnrollChecklistMapper.state`, `GroupsEnrollProgramScreen.completedSteps(_:)` (d2m).
- Produces: `GroupDetailMapper.Input.drafts: [DraftWire] = []`, `.programsById: [String: StudyProgram] = [:]`; `GroupDetailMapper.Output.enrollmentTargets: [EnrollmentRowTarget] = []`, `func enrollmentTarget(atRow row: Int) -> EnrollmentRowTarget?`

- [ ] **Step 1: Write the failing test** — append inside `final class GroupDetailMapperTests`:

```swift
    // MARK: - ui2-enrollments-browse D7b/D14.2/D19/D28

    private func romans() throws -> StudyProgram {
        try JSONDecoder.apiDecoder.decode(StudyProgram.self, from: Data(
            #"{"id":"p2","name":"Romans in 30 days","description":"A deep dive","days":30,"isPublished":true,"coverImageUrl":"https://x/p2.png","createdAt":"2025-01-01T00:00:00.000Z","updatedAt":"2025-01-01T00:00:00.000Z"}"#.utf8))
    }

    private func groupDraft(start: String? = nil, schedule: [String]? = nil, sms: String? = "07:30",
                            sync: String? = nil, access: String? = nil) -> DraftWire {
        DraftWire(id: "d1", groupId: "g1", studyProgramId: "p2", startDate: start,
                  enabledDays: schedule == nil ? nil : ["Mon"], overriddenDates: nil, scheduleDates: schedule,
                  smsTime: sms, timezone: sms == nil ? nil : "America/Denver", syncMode: sync, lessonAccess: access,
                  createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                  createdAt: "2026-10-20T00:00:00.000Z", updatedAt: "2026-10-21T00:00:00.000Z")
    }

    func testDraftRowsFollowTheEnrollmentsWithTheirMarkersAndTargets() throws {
        let json = #"[{"id":"e1","groupId":"g1","programId":"p1","startedAt":"2026-09-01T00:00:00Z","createdAt":"2026-09-01T15:00:00Z","studyProgram":{"id":"p1","title":"Faith over fear","description":"30 days","coverImageUrl":"https://img/p1.jpg"}}]"#
        let enrollments = try JSONDecoder.apiDecoder.decode([EnrollmentWithProgram].self, from: Data(json.utf8))
        let draft = groupDraft()
        let o = output(.init(name: "x", group: group(), enrollments: enrollments, drafts: [draft], programsById: ["p2": try romans()]))
        let s = o.state
        XCTAssertEqual(s.programTitles, ["Faith over fear", "Romans in 30 days"])
        XCTAssertEqual(s.programDescriptions, ["30 days", ""])
        XCTAssertEqual(s.programEnrolledDates, ["Sep 1, 2026", ""])
        XCTAssertEqual(s.programCoverURLs, ["https://img/p1.jpg", "https://x/p2.png"])
        XCTAssertEqual(s.programDraftLabels, ["", "Draft · 3/6"])                   // group, program, invite time
        XCTAssertEqual(s.programDraftStarters, ["", "Started by Luke Keith"])
        XCTAssertEqual(o.enrollmentTarget(atRow: 0), .enrollment(id: "e1", name: "Faith over fear"))   // D28
        XCTAssertEqual(o.enrollmentTarget(atRow: 1), .draft(draft))                                    // D21
        XCTAssertNil(o.enrollmentTarget(atRow: 2))
    }

    func testTheGroupPagesCountEqualsTheChecklistsIncludingTheStaleRule() throws {   // D19 + D9
        let program = try romans()
        let stale = groupDraft(start: "2026-10-01", schedule: ["2026-10-01"], sync: "AUTO", access: "ALL_AT_ONCE")
        let s = output(.init(name: "x", group: group(), drafts: [stale], programsById: ["p2": program])).state
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var checklist = EnrollmentDraftMapping.draft(stale, flowId: UUID(), zone: tz)
        checklist.clearStaleStart(today: now, calendar: cal)
        let n = GroupsEnrollProgramScreen.completedSteps(EnrollChecklistMapper.state(checklist, group: group(), program: program, today: now))
        XCTAssertEqual(n, 5)
        XCTAssertEqual(s.programDraftLabels, ["Draft · \(n)/6"])
    }

    func testNoDraftsLeavesTheEnrollmentRowsUnmarked() throws {
        let s = output(.init(name: "x", group: group())).state
        XCTAssertEqual(s.programDraftLabels, [])
        XCTAssertEqual(s.programDraftStarters, [])
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, "extra arguments 'drafts', 'programsById' in call", "value of type 'GroupDetailMapper.Output' has no member 'enrollmentTarget'"

- [ ] **Step 3: Write the minimal implementation**

`GroupDetailMapper.swift` — `Input` gains (after `chart`):

```swift
        /// ui2-enrollments-browse D7b: the group's saved drafts, newest first — listed after the enrollments.
        var drafts: [DraftWire] = []
        /// The drafts' programs, by id (the drafts list carries only `studyProgramId`).
        var programsById: [String: StudyProgram] = [:]
```

`Output` gains:

```swift
        /// D28/D21: what each Enrollments row opens — enrollments first, then drafts.
        var enrollmentTargets: [EnrollmentRowTarget] = []

        func enrollmentTarget(atRow row: Int) -> EnrollmentRowTarget? {
            enrollmentTargets.indices.contains(row) ? enrollmentTargets[row] : nil
        }
```

In `output(_:now:timeZone:)`: change `let state = GroupsDetailScreen.State(` to `var state = …`, and replace the final `return` with:

```swift
        // ui2-enrollments-browse D7b/D14.2: draft rows after the enrollments; the screen counts only
        // "" rows in the Enrollments stat and «N» meta (F6).
        let drafts = draftRows(input, now: now, timeZone: timeZone)
        state.programTitles += drafts.map(\.title)
        state.programDescriptions += drafts.map { _ in "" }
        state.programEnrolledDates += drafts.map { _ in "" }
        state.programCoverURLs += drafts.map(\.cover)
        state.programDraftLabels = enrollments.map { _ in "" } + drafts.map(\.label)
        state.programDraftStarters = enrollments.map { _ in "" } + drafts.map(\.starter)
        let targets = enrollments.map { EnrollmentRowTarget.enrollment(id: $0.id, name: $0.studyProgram?.name ?? "") }
            + input.drafts.map { EnrollmentRowTarget.draft($0) }
        return Output(state: state, memberRows: members.map { MemberRow(id: $0.userId, name: $0.name) },
                      enrollmentTargets: targets)
```

and add:

```swift
    // MARK: - ui2-enrollments-browse D7b/D19 draft rows

    private struct DraftRow {
        let title: String
        let cover: String
        let label: String
        let starter: String
    }

    /// D19: `Draft · n/6` with the checklist's own count and D9's stale rule.
    private static func draftRows(_ input: Input, now: Date, timeZone: TimeZone) -> [DraftRow] {
        input.drafts.map { wire in
            let program = input.programsById[wire.studyProgramId]
            let n = EnrollmentsHomeMapper.draftCompletedSteps(
                wire, group: input.group, program: program,
                groupName: input.group?.name ?? input.name, programName: program?.name ?? "",
                today: now, timeZone: timeZone)
            return DraftRow(title: program?.name ?? "", cover: program?.coverImageUrl ?? "",
                            label: EnrollmentsHomeMapper.draftLabel(completed: n),
                            starter: EnrollmentsHomeMapper.starterLabel(wire.createdBy?.name))
        }
    }
```

`GroupDetailContainer.swift` — the screen call gains (beside `onEnrollProgram`):

```swift
                    // ui2-enrollments-browse D28/D21: an enrollment row → its page; a draft row → its checklist.
                    onOpenEnrollment: { row in EnrollDraftOpen.route(output.enrollmentTarget(atRow: row), navigator: navigator) },
```

`input(groupId:name:state:)` — read the drafts and their programs:

```swift
    static func input(groupId: String, name: String, state app: AppState) -> GroupDetailMapper.Input {
        let drafts = app.enrollmentDraftsByGroupId[groupId] ?? []
        return GroupDetailMapper.Input(
            name: name,
            group: app.groups[groupId],
            members: app.membersFor(groupId: groupId),
            requests: app.pendingJoinRequestsByGroupId[groupId] ?? [],
            enrollments: app.enrollmentsFor(groupId: groupId),
            nextStudy: app.nextStudyByGroupId[groupId],
            history: app.historyByGroupId[groupId] ?? [],
            days: app.groupDaysByGroupId[groupId],
            chart: app.groupChartByGroupId[groupId],
            drafts: drafts,
            programsById: Dictionary(drafts.compactMap { d in app.programs[d.studyProgramId].map { (d.studyProgramId, $0) } },
                                     uniquingKeysWith: { first, _ in first })
        )
    }
```

`load(groupId:authManager:)` — a ninth load beside the enrollments (and add `drafts` to the final `await` tuple):

```swift
        async let drafts: () = attempt("loadDrafts", onUnauthorized: onUnauthorized) {
            try await EnrollmentDraftActions().listByGroup(groupId: groupId)
            // D7b: a draft row's title is its program's — load the programs when one is unknown.
            let ids = (AppState.shared.enrollmentDraftsByGroupId[groupId] ?? []).map(\.studyProgramId)
            if ids.contains(where: { AppState.shared.programs[$0] == nil }) {
                try await ProgramActions().loadPrograms()
            }
        }
```

```swift
        _ = await (group, members, requests, enrollments, next, history, days, chart, drafts)
```

(Update the doc comment "the eight section loads" → "the nine section loads".)

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (GroupDetailMapperTests incl. the three new tests; GroupDetailContainerTests still green); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(ui2-enrollments-browse): group page lists drafts and opens enrollment and draft rows (D7b, D28, R3)`

### Task 15: Repoint + retire sweep — prove R1–R5 and guard the prune
App: iphone
Phase: 5
Recipe: SPEC §Findings R1–R5 + §Replaced surfaces · tiny

**Files:**
- Test: `iphone/MakeReadyCaptureTests/EnrollmentDraftTests.swift` (existing file, already in the test target) — one shell-path guard for R4
- No production file changes unless a grep below finds a residue; a residue is fixed in the file the grep names, in this task's one commit

**Interfaces:**
- Consumes: `UI2ShellModel` (`push`, `pop`, `enrollmentFlowIds`), `AppState.seedEnrollmentDraft(_:flowId:today:)`, `.pruneEnrollmentDrafts(keeping:)`, `EnrollDraftSyncs.sync(for:state:actions:)`, `.prune(keeping:)`, `.isRegistered(_:)`, `EnrollmentDraftActions(api:state:)`, `StubAPIClient`, `DraftWire`, `EnrollmentWireRef`
- Produces: nothing new — the evidence that R1–R5 are repointed and nothing retired lost its guard

- [ ] **Step 1: Write the failing test** — append inside `final class EnrollmentDraftTests` (the existing tests in this file — start/update/end/prune, clear on sign-out, the program cascade, the schedule math — stay as they are: they guard the absorbed in-memory draft, Replaced surface 2):

```swift
    /// ui2-enrollments-browse R4/D2: a checklist that leaves every stack drops the LOCAL flow and
    /// stops its autosave — the shell's prune sends no request, and never a DELETE.
    func testThePruneOfASavedDraftsFlowSendsNoRequest() async {
        let api = StubAPIClient()
        let state = AppState()
        var model = UI2ShellModel()
        let wire = DraftWire(id: "d1", groupId: "g1", studyProgramId: "p1", startDate: nil, enabledDays: nil,
                             overriddenDates: nil, scheduleDates: nil, smsTime: nil, timezone: nil, syncMode: nil,
                             lessonAccess: nil, createdBy: EnrollmentWireRef(id: "u1", name: "Luke Keith"),
                             createdAt: "2035-01-01T00:00:00.000Z", updatedAt: "2035-01-02T00:00:00.000Z")
        let flow = state.seedEnrollmentDraft(wire)
        let sync = EnrollDraftSyncs.sync(for: flow, state: state, actions: EnrollmentDraftActions(api: api, state: state))
        model.push(.enrollChecklist(flowId: flow), on: .home)
        state.updateEnrollmentDraft(flow) { $0.smsTime = "07:30" }                 // an unsent change
        model.pop(on: .home)                                                     // swipe-back
        state.pruneEnrollmentDrafts(keeping: model.enrollmentFlowIds)            // UI2Shell's onChange, both halves
        EnrollDraftSyncs.prune(keeping: model.enrollmentFlowIds)
        sync.changed()
        await sync.flush()
        XCTAssertNil(state.enrollmentDrafts[flow])
        XCTAssertFalse(EnrollDraftSyncs.isRegistered(flow))
        XCTAssertTrue(api.calls.isEmpty)
    }
```

- [ ] **Step 2: Run it and watch it** — `npm run ios:build-check -- --test` → this guard PASSES at once if Tasks 12–13 landed correctly (it is a regression guard, not new behaviour); if it FAILS, the prune path still sends a request — fix `UI2Shell.swift`'s `.onChange(of: model.enrollmentFlowIds)` or `EnrollDraftSyncs.prune` until it passes. Record which in your report.

- [ ] **Step 3: Run the residual greps (repo root) — each must read exactly as stated**

```bash
# R1: the Enrollments section reaches the container, not EmptyPage
grep -n "case .enrollments" iphone/MakeReady/UI2/Shell/UI2Shell.swift          # → 1 hit: EnrollmentsHomeContainer()
grep -n "EmptyPage()" iphone/MakeReady/UI2/Shell/UI2Shell.swift                # → only `.calendar, .search` and `default:` (Library, Invites, Media)
# R2: the destination is routed
grep -n "enrollmentHome" iphone/MakeReady/UI2/Shell/UI2Shell.swift             # → 1 hit in page(for:)
grep -n "EnrollmentHomeContainer" iphone/MakeReady/UI2/Containers/Enrollments/EnrollmentHomeHost.swift   # → 1 hit (no EmptyPage left)
# R3: group-page enrollment rows are live
grep -n "onOpenEnrollment" iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift             # → 1 hit
# R4: nothing DELETEs a draft except Discard
grep -rn "\.delete(id:" iphone/MakeReady/UI2                                   # → only EnrollDiscard.swift
grep -rn "\"DELETE\"" iphone/MakeReady/State/Actions/EnrollmentDraftActions.swift                         # → 1 hit (delete(id:))
grep -n "EnrollDraftSyncs.prune" iphone/MakeReady/UI2/Shell/UI2Shell.swift     # → 1 hit, beside pruneEnrollmentDrafts
grep -c "EnrollDraftSyncs.changed" iphone/MakeReady/UI2/Containers/Enrollments/EnrollSelect*.swift       # → totals 6 (D4's commit points)
# R4: TopNav add unchanged
git diff main -- iphone/MakeReady/UI2/Shell/TopNavHost.swift                    # → empty
# R5: no deep-link consumer was added (the 2.0 shell still drops every link)
grep -n "clearPendingDeepLink" iphone/MakeReady/UI2/Shell/UI2Shell.swift       # → the 2 existing hits, unchanged
# memory-only: the new stores never reach the disk snapshot
grep -n "enrollmentFeed\|enrollmentHomes\|enrollmentDraftsByGroupId\|enrollmentDraftBaselines" iphone/MakeReady/State/Persistence/PersistedState.swift   # → no hits
```

Any line that reads otherwise is a residue: fix it in the named file (repoint, never delete a guard) and re-run.

- [ ] **Step 4: Run the phase gates** — `npm run ios:build-check -- --test` → PASS, every test target green; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `test(ui2-enrollments-browse): repoint sweep — the prune never deletes a saved draft (R1–R5)`
