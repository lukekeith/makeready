# ui2-groups-browse — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the UI 2.0 Groups section (groups-home), the group page (groups-detail, read-only) and create-group on iPhone to live data, and add the server data the group page reads that does not exist yet.

**Architecture:** The server ships additive payload fields, one new history endpoint, a `groupId` scope on `/api/home/days`, a three-state directory-access column and fixture layers; its last task freezes §Contract. The iPhone then decodes the new fields, keeps per-group data in `AppState`, and wires the d2m-built MakeReadyUI screens through containers + pure mappers in `iphone/MakeReady/UI2/Containers/Groups/`, the ui2-members pattern.

**Tech Stack:** server — Express, Prisma, Atlas (schema YAML → migration), zod, vitest · iphone — Swift/SwiftUI, @Observable AppState + Actions, MakeReadyUI, XCTest.

**Spec:** `docs/features/ui2-groups-browse/SPEC.md`

## Global Constraints


- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-groups-browse): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | `memberDirectoryAccess` column + backfill; group payloads carry org, creator name and directory access; cover upload is tracked | `cd server && npx tsc --noEmit` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | server | 3–6 | group history endpoint, next-study title + thumbnails, `/api/home/days?groupId`, scoped member reads | `cd server && npx tsc --noEmit` · `cd server && npm run test:run` |
| 3 | server | 7 | fixture layers for groups-home / groups-detail / create-group; §Contract frozen | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 4 | iphone | 8–10 | decode models, AppState group stores, GroupActions loaders | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 11–13 | screen edits, Groups section live (search, chips, refresh), create-group | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 6 | iphone | 14–16 | the group page on live data, shell routes and exits, residual sweep | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: DirectoryAccess enum + Group.memberDirectoryAccess (SC1)
App: server
Phase: 1
Recipe: `server/.claude/CLAUDE.md` §"Database Management - Schema-First Approach" (YAML is the source; never edit `prisma/schema.prisma` or a committed migration) · SPEC §Schema & API changes SC1 + Data plan · D11

**Files:**
- Modify: `server/schema/enums.yaml` (append the `DirectoryAccess` enum after `SyncRunStatus`, end of file)
- Modify: `server/schema/schema.yaml` (model `Group`, after `memberDirectoryEnabled`, ~line 318)
- Generated (commit them): `server/prisma/schema.prisma`, `server/atlas/migrations/<timestamp>.sql`, `server/atlas/migrations/atlas.sum`
- Test: `server/test/directory-access-migration.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: Postgres enum `"DirectoryAccess"` ('ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED'); column `groups."memberDirectoryAccess"` NOT NULL DEFAULT 'ALLOWED', backfilled 'NOT_ALLOWED' where `"memberDirectoryEnabled" = false`; Prisma `enum DirectoryAccess` exported from `server/src/generated/prisma/index.js` and `Group.memberDirectoryAccess: DirectoryAccess`. Wire value (Tasks 2+, iPhone `UserGroup.memberDirectoryAccess`): the string `"ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED"`.

**Environment facts (read before Step 3):**
- 🔴 Never `npm run schema:diff`, `npm run migrate:apply` or `npm run migrate:status`: they run `dotenv --`, which reads `server/.env` — a 1Password pipe in the main checkout. Call Atlas through `server/scripts/atlas.sh` with `--var database_url=…` instead (it runs `server/bin/atlas`, present in this worktree, else `atlas` on PATH).
- `npm run schema:validate` and `npm run schema:generate` are plain `tsx` scripts (no dotenv) — safe.
- `npx prisma generate` loads `prisma.config.ts`, which does `import "dotenv/config"` and so reads `server/.env` IF it exists. This worktree has no `server/.env`; the command below refuses to run if one appears. Generation needs no database.
- `atlas migrate diff --env local` diffs against the dev database `atlas_dev_template` on the local postgres (`localhost:5434`, `atlas/atlas.hcl`); `database_url` is not connected to by `diff` but must be set for the HCL to evaluate.
- Do NOT apply this migration to `makeready_dev` — walk readiness applies it (`apply_mode: ask`). Step 8 applies it to a throwaway database only.
- vitest needs no env: `test/setup.ts` loads `.env.test` / `.env` only when present (neither exists in this worktree). This test reads files only.

- [ ] **Step 1: Write the failing test** — `server/test/directory-access-migration.test.ts`

```ts
/**
 * ui2-groups-browse SC1 / D11: the DirectoryAccess enum + Group.memberDirectoryAccess column ship
 * in ONE Atlas migration that backfills NOT_ALLOWED from the Boolean memberDirectoryEnabled.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { DirectoryAccess } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const ADD_COLUMN = 'ADD COLUMN "memberDirectoryAccess" "DirectoryAccess" NOT NULL DEFAULT \'ALLOWED\''
const BACKFILL = 'UPDATE "groups" SET "memberDirectoryAccess" = \'NOT_ALLOWED\' WHERE "memberDirectoryEnabled" = false;'

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes('"memberDirectoryAccess"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration (D11)', () => {
  it('creates the enum and the NOT NULL column with default ALLOWED', () => {
    const { sql } = findMigration()
    expect(sql).toContain('CREATE TYPE "DirectoryAccess" AS ENUM (\'ALLOWED\', \'NAMES_ONLY\', \'NOT_ALLOWED\')')
    expect(sql).toContain(ADD_COLUMN)
  })

  it('backfills NOT_ALLOWED where the Boolean is off, after the column exists', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BACKFILL)
    expect(sql.indexOf(BACKFILL)).toBeGreaterThan(sql.indexOf(ADD_COLUMN))
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma enum with the three values', () => {
    expect(Object.values(DirectoryAccess)).toEqual(['ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED'])
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/directory-access-migration.test.ts` → FAIL (no migration mentions `"memberDirectoryAccess"`; `DirectoryAccess` is undefined)

- [ ] **Step 3: Add the enum and the field to the YAML source**

Append to `server/schema/enums.yaml` (same 2-space indent as `SyncRunStatus`):

```yaml
  # ui2-groups-browse D11: who may see a group's member directory. The Boolean
  # Group.memberDirectoryEnabled stays; group writes keep the two in sync.
  DirectoryAccess:
    values:
      - ALLOWED       # members see the directory
      - NAMES_ONLY    # members see names only
      - NOT_ALLOWED   # no directory
```

In `server/schema/schema.yaml`, model `Group`, directly after the `memberDirectoryEnabled` field:

```yaml
      memberDirectoryAccess:
        type: enum
        enum: DirectoryAccess
        default: ALLOWED
        description: "Three-state member directory access (ui2-groups-browse D11); memberDirectoryEnabled is kept in sync"
```

- [ ] **Step 4: Validate and generate** — `cd server && npm run schema:validate && npm run schema:generate` → validation passes; `git diff server/prisma/schema.prisma` shows `enum DirectoryAccess { ALLOWED NAMES_ONLY NOT_ALLOWED }` and, in `model Group`, `memberDirectoryAccess DirectoryAccess @default(ALLOWED)` — and nothing else. Any other change means the YAML was already out of sync with the committed schema: STOP and report.

- [ ] **Step 5: Generate the migration (no dotenv)**

```bash
cd server/atlas && ../scripts/atlas.sh migrate diff --env local \
  --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
```

Expected: one new file `server/atlas/migrations/<14-digit timestamp>.sql` containing exactly

```sql
-- Create enum type "DirectoryAccess"
CREATE TYPE "DirectoryAccess" AS ENUM ('ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED');
-- Modify "groups" table
ALTER TABLE "groups" ADD COLUMN "memberDirectoryAccess" "DirectoryAccess" NOT NULL DEFAULT 'ALLOWED';
```

Any other statement in it: STOP and report (do not hand-trim a diff).

- [ ] **Step 6: Append the D11 backfill to the new (uncommitted) migration, then re-hash** — precedent `server/atlas/migrations/20260621022752.sql` (quoted camelCase columns). Append to the end of the file Step 5 created:

```sql
-- ui2-groups-browse D11: a group whose Boolean directory flag is off reads NOT_ALLOWED.
UPDATE "groups" SET "memberDirectoryAccess" = 'NOT_ALLOWED' WHERE "memberDirectoryEnabled" = false;
```

then

```bash
cd server/atlas && ../scripts/atlas.sh migrate hash --env local \
  --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
```

→ `atlas.sum` gains the new file's line.

- [ ] **Step 7: Regenerate the Prisma client in the worktree** — `cd server && test ! -e .env && npx prisma generate` → "Generated Prisma Client". (If `test` fails, a `server/.env` exists: STOP — it is the 1Password pipe.)

- [ ] **Step 8: Prove the migration applies on a fresh database (throwaway, never makeready_dev)**

```bash
docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_sc1_check
docker exec makeready-postgres createdb -U postgres makeready_sc1_check
cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_sc1_check
cd server/atlas && ../scripts/atlas.sh migrate status --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_sc1_check
docker exec makeready-postgres psql -U postgres -d makeready_sc1_check -c 'SELECT column_name, column_default, is_nullable FROM information_schema.columns WHERE table_name = $$groups$$ AND column_name = $$memberDirectoryAccess$$'
docker exec makeready-postgres dropdb -U postgres --force makeready_sc1_check
```

→ apply succeeds; status reads "Already at latest version"; the column row shows default `'ALLOWED'::"DirectoryAccess"`, `is_nullable = NO`. Quote the status line in your report.

- [ ] **Step 9: Run the tests and watch them pass** — `cd server && npx vitest run test/directory-access-migration.test.ts` → PASS (4 tests); `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 10: Commit** — `feat(ui2-groups-browse): DirectoryAccess enum + Group.memberDirectoryAccess with D11 backfill` (the two YAML files, `prisma/schema.prisma`, the migration, `atlas.sum`, the test).

### Task 2: groups payloads — org fields, creatorName, memberDirectoryAccess, D11 sync, cover trackActivity
App: server
Phase: 1
Recipe: `/api` · SPEC D10, D11, D15 (cover row), SC1–SC3, SC7 · §Contract rows 1–3

**Files:**
- Modify: `server/src/routes/groups.ts` — `POST /` (~97-201), `GET /` (~234-282), `GET /:id` (~559-608), `PATCH /:id` (~907-1042), `POST /:id/cover-image` (~1175-1284)
- Modify: `server/src/routes/__tests__/groups-creator-name.request.test.ts` (its Prisma mock gains `organization.findMany`)
- Test: `server/src/routes/__tests__/groups-browse-fields.request.test.ts`

**Interfaces:**
- Consumes: Task 1 — `Group.memberDirectoryAccess` (`'ALLOWED' | 'NAMES_ONLY' | 'NOT_ALLOWED'`) on the generated Prisma client.
- Produces (wire, consumed by iPhone `UserGroup` — every key additive, every existing key unchanged):
  - `GET /api/groups` → `{ success: true, groups: [{ …existing (incl. creatorId, creatorName), organizationId: string, organizationName: string | null, memberDirectoryAccess: "ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED" }] }`
  - `GET /api/groups/:id`, `PATCH /api/groups/:id`, `POST /api/groups` → `{ success: true, group: { …existing, creatorName: string | null, memberDirectoryAccess } }`
  - Writes: `POST /api/groups` sets `memberDirectoryAccess` = `memberDirectory ? 'ALLOWED' : 'NOT_ALLOWED'` (body default `memberDirectory: true`); `PATCH` with `memberDirectory` present sets it the same way; a PATCH without `memberDirectory` leaves it untouched.
  - `POST /api/groups/:id/cover-image` writes one `Activity` row: `{ actorId, action: 'UPDATED', resourceType: 'GROUP', resourceId: groupId, resourceName: group.name, organizationId, groupId, metadata: { field: 'cover' } }` — Task 3's history maps it to `cover_updated`.

Notes: `Group` has no `organization` relation — org names come from ONE batched `prisma.organization.findMany` over the distinct ids. `GET /` already returns `creatorName` (`groups.ts:272`, invite-member). vitest needs no env and no running server (`docker restart makeready-server` is NOT needed for vitest).

- [ ] **Step 1: Write the failing test** — `server/src/routes/__tests__/groups-browse-fields.request.test.ts`

```ts
/**
 * ui2-groups-browse D10, D11, SC1–SC3, SC7: the additive group payload fields, the D11 enum sync on
 * create / Boolean-only PATCH, and the cover upload's history row. Prisma and every side-effecting
 * service are stubbed; the router is real.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn(), findFirst: vi.fn(), create: vi.fn(), update: vi.fn() },
  organization: { findMany: vi.fn(), findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
}))
const trackActivity = vi.hoisted(() => vi.fn())
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
  isSuperAdmin: vi.fn().mockResolvedValue(false),
}))
vi.mock('../../services/activity.js', () => ({ trackActivity }))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  resolveUserOrganizationId: vi.fn().mockResolvedValue('org1'),
}))
vi.mock('../../lib/group-code.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../lib/group-code.js')>()),
  generateUniqueGroupCode: vi.fn().mockResolvedValue('ABC123'),
}))
vi.mock('../../services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/storage.js')>()),
  uploadImageVariants: vi.fn().mockResolvedValue({ url: 'https://img.test/groups/group-g1.jpeg' }),
}))
vi.mock('../../services/media-library.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-library.js')>()),
  captureToLibrary: vi.fn(),
}))
vi.mock('../../services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/media-metadata.js')>()),
  extractImageMetadata: vi
    .fn()
    .mockResolvedValue({ width: 1, height: 1, aspectRatio: 1, dominantColor: null, fileHash: 'h', exifData: null }),
}))
vi.mock('sharp', () => ({
  default: vi.fn(() => {
    const chain = { resize: vi.fn(), jpeg: vi.fn(), toBuffer: vi.fn().mockResolvedValue(Buffer.from('jpeg')) }
    chain.resize.mockReturnValue(chain)
    chain.jpeg.mockReturnValue(chain)
    return chain
  }),
}))

import groupsRoutes from '../groups.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupsRoutes)
  return a
}

const row = (over: Record<string, unknown> = {}) => ({
  id: 'g1',
  code: 'ABC123',
  name: 'Prayer Team',
  description: null,
  coverImageUrl: null,
  isPrivate: false,
  allowInvites: true,
  memberDirectoryEnabled: true,
  memberDirectoryAccess: 'ALLOWED',
  welcomeMessage: null,
  ageRangeMin: null,
  ageRangeMax: null,
  maxMembers: null,
  creatorId: 'u1',
  organizationId: 'org1',
  isActive: true,
  createdAt: new Date('2026-10-01T00:00:00Z'),
  updatedAt: new Date('2026-10-02T00:00:00Z'),
  _count: { members: 3 },
  creator: { name: 'Tony Stark' },
  ...over,
})

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.organization.findMany.mockResolvedValue([])
})

describe('GET /api/groups — org fields + memberDirectoryAccess (D10, D11)', () => {
  it('adds organizationId, organizationName and memberDirectoryAccess per group', async () => {
    prismaMock.group.findMany.mockResolvedValue([
      row(),
      row({ id: 'g2', organizationId: 'org2', memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }),
      row({ id: 'g3', memberDirectoryAccess: 'NAMES_ONLY' }),
    ])
    prismaMock.organization.findMany.mockResolvedValue([
      { id: 'org1', name: 'Grace Church' },
      { id: 'org2', name: 'Hope Chapel' },
    ])
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(
      res.body.groups.map((g: Record<string, unknown>) => [g.organizationId, g.organizationName, g.memberDirectoryAccess])
    ).toEqual([
      ['org1', 'Grace Church', 'ALLOWED'],
      ['org2', 'Hope Chapel', 'NOT_ALLOWED'],
      ['org1', 'Grace Church', 'NAMES_ONLY'],
    ])
    expect(res.body.groups[0].creatorName).toBe('Tony Stark')
    expect(res.body.groups[1].memberDirectory).toBe(false)
  })

  it('reads org names in ONE batched query over the distinct ids', async () => {
    prismaMock.group.findMany.mockResolvedValue([row(), row({ id: 'g2', organizationId: 'org2' }), row({ id: 'g3' })])
    await request(app()).get('/api/groups')
    expect(prismaMock.organization.findMany).toHaveBeenCalledTimes(1)
    expect(prismaMock.organization.findMany).toHaveBeenCalledWith({
      where: { id: { in: ['org1', 'org2'] } },
      select: { id: true, name: true },
    })
  })

  it('reads organizationName null for an org that no longer exists, and skips the query for no groups', async () => {
    prismaMock.group.findMany.mockResolvedValue([row({ organizationId: 'gone' })])
    expect((await request(app()).get('/api/groups')).body.groups[0].organizationName).toBeNull()
    vi.clearAllMocks()
    prismaMock.group.findMany.mockResolvedValue([])
    expect((await request(app()).get('/api/groups')).body.groups).toEqual([])
    expect(prismaMock.organization.findMany).not.toHaveBeenCalled()
  })
})

describe('GET /api/groups/:id — creatorName + memberDirectoryAccess (D10, D11)', () => {
  it('returns the creator name and the enum, asking Prisma for the name only', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryAccess: 'NAMES_ONLY' }))
    const res = await request(app()).get('/api/groups/g1')
    expect(res.status).toBe(200)
    expect(res.body.group.creatorName).toBe('Tony Stark')
    expect(res.body.group.memberDirectoryAccess).toBe('NAMES_ONLY')
    expect(prismaMock.group.findFirst.mock.calls[0][0].include.creator).toEqual({ select: { name: true } })
  })

  it('reads creatorName null when the creator row is gone', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ creator: null }))
    expect((await request(app()).get('/api/groups/g1')).body.group.creatorName).toBeNull()
  })
})

describe('POST /api/groups — D11 write + payload', () => {
  it('writes ALLOWED by default and returns creatorName + memberDirectoryAccess', async () => {
    prismaMock.group.create.mockResolvedValue(row({ name: 'Walk Test Group' }))
    const res = await request(app()).post('/api/groups').send({ name: 'Walk Test Group' })
    expect(res.status).toBe(200)
    const args = prismaMock.group.create.mock.calls[0][0]
    expect(args.data).toMatchObject({ memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED' })
    expect(args.include.creator).toEqual({ select: { name: true } })
    expect(res.body.group).toMatchObject({ creatorName: 'Tony Stark', memberDirectoryAccess: 'ALLOWED' })
  })

  it('writes NOT_ALLOWED when memberDirectory is false', async () => {
    prismaMock.group.create.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }))
    await request(app()).post('/api/groups').send({ name: 'Quiet Group', memberDirectory: false })
    expect(prismaMock.group.create.mock.calls[0][0].data).toMatchObject({
      memberDirectoryEnabled: false,
      memberDirectoryAccess: 'NOT_ALLOWED',
    })
  })
})

describe('PATCH /api/groups/:id — D11 Boolean-only sync + payload', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
  })

  it('memberDirectory false → NOT_ALLOWED', async () => {
    prismaMock.group.update.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' }))
    const res = await request(app()).patch('/api/groups/g1').send({ memberDirectory: false })
    expect(res.status).toBe(200)
    const args = prismaMock.group.update.mock.calls[0][0]
    expect(args.data).toMatchObject({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' })
    expect(args.include.creator).toEqual({ select: { name: true } })
    expect(res.body.group).toMatchObject({ creatorName: 'Tony Stark', memberDirectoryAccess: 'NOT_ALLOWED' })
  })

  it('memberDirectory true → ALLOWED', async () => {
    prismaMock.group.update.mockResolvedValue(row())
    await request(app()).patch('/api/groups/g1').send({ memberDirectory: true })
    expect(prismaMock.group.update.mock.calls[0][0].data).toMatchObject({
      memberDirectoryEnabled: true,
      memberDirectoryAccess: 'ALLOWED',
    })
  })

  it('leaves the enum alone when memberDirectory is absent', async () => {
    prismaMock.group.update.mockResolvedValue(row({ name: 'Renamed' }))
    await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(prismaMock.group.update.mock.calls[0][0].data).not.toHaveProperty('memberDirectoryAccess')
  })
})

describe('POST /api/groups/:id/cover-image — history row (SC7, D15)', () => {
  it('tracks UPDATED GROUP with metadata.field = "cover"', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockResolvedValue(row())
    const res = await request(app()).post('/api/groups/g1/cover-image').send({ imageData: 'aGVsbG8=' })
    expect(res.status).toBe(200)
    expect(res.body.coverImageUrl).toBe('https://img.test/groups/group-g1.jpeg')
    expect(trackActivity).toHaveBeenCalledWith({
      actorId: 'u1',
      action: 'UPDATED',
      resourceType: 'GROUP',
      resourceId: 'g1',
      resourceName: 'Prayer Team',
      organizationId: 'org1',
      groupId: 'g1',
      metadata: { field: 'cover' },
    })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/groups-browse-fields.request.test.ts` → FAIL (`organizationName` / `memberDirectoryAccess` / `creatorName` undefined; `memberDirectoryAccess` missing from create/update data; `trackActivity` not called)

- [ ] **Step 3: Implement in `server/src/routes/groups.ts`**

`POST /` — in `prisma.group.create`, add to `data` (after `memberDirectoryEnabled: body.memberDirectory,`) and to `include`:

```ts
        memberDirectoryEnabled: body.memberDirectory,
        // ui2-groups-browse D11: the enum follows the Boolean on every Boolean-only write.
        memberDirectoryAccess: body.memberDirectory ? 'ALLOWED' : 'NOT_ALLOWED',
```

```ts
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
        creator: { select: { name: true } },
      },
```

and in its `response` object, after `memberDirectory: group.memberDirectoryEnabled,` and after `creatorId: group.creatorId,` respectively:

```ts
      memberDirectoryAccess: group.memberDirectoryAccess,
```

```ts
      creatorName: group.creator?.name ?? null,
```

`GET /` — after the `prisma.group.findMany(...)` call, before `const response = groups.map(...)`:

```ts
    // ui2-groups-browse D10: Group has no organization relation — one batched lookup.
    const orgIds = [...new Set(groups.map((group) => group.organizationId))]
    const orgNames = new Map(
      orgIds.length > 0
        ? (
            await prisma.organization.findMany({ where: { id: { in: orgIds } }, select: { id: true, name: true } })
          ).map((org) => [org.id, org.name] as const)
        : []
    )
```

and in the mapped object, after `memberDirectory: group.memberDirectoryEnabled,` and after `creatorName: group.creator?.name ?? null,`:

```ts
      memberDirectoryAccess: group.memberDirectoryAccess,
```

```ts
      organizationId: group.organizationId,
      organizationName: orgNames.get(group.organizationId) ?? null,
```

`GET /:id` — add `creator: { select: { name: true } },` to the `findFirst` `include` (beside `_count`), and to `response`: `memberDirectoryAccess: group.memberDirectoryAccess,` after `memberDirectory`, `creatorName: group.creator?.name ?? null,` after `creatorId`.

`PATCH /:id` — after the existing `memberDirectory` line:

```ts
    if (body.memberDirectory !== undefined) updateData.memberDirectoryEnabled = body.memberDirectory
    // ui2-groups-browse D11: a Boolean-only write sets the enum to match (child 2 adds the enum write).
    if (body.memberDirectory !== undefined) {
      updateData.memberDirectoryAccess = body.memberDirectory ? 'ALLOWED' : 'NOT_ALLOWED'
    }
```

add `creator: { select: { name: true } },` to the `prisma.group.update` `include`, and the same two response keys (`memberDirectoryAccess`, `creatorName`) as `GET /:id`.

`POST /:id/cover-image` — directly after `await prisma.group.update({ where: { id }, data: { coverImageUrl } })`:

```ts
    // ui2-groups-browse SC7 / D15: the group history reads this row as "Updated cover photo".
    trackActivity({
      actorId: userId,
      action: 'UPDATED',
      resourceType: 'GROUP',
      resourceId: group.id,
      resourceName: group.name,
      organizationId: group.organizationId,
      groupId: group.id,
      metadata: { field: 'cover' },
    })
```

- [ ] **Step 4: Keep the older list test's mock complete** — in `server/src/routes/__tests__/groups-creator-name.request.test.ts`, replace

```ts
const prismaMock = vi.hoisted(() => ({ group: { findMany: vi.fn() } }))
```

with

```ts
const prismaMock = vi.hoisted(() => ({
  group: { findMany: vi.fn() },
  organization: { findMany: vi.fn().mockResolvedValue([]) },
}))
```

- [ ] **Step 5: Run the tests and watch them pass** — `cd server && npx vitest run src/routes/__tests__/groups-browse-fields.request.test.ts src/routes/__tests__/groups-creator-name.request.test.ts` → PASS; `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 6: Commit** — `feat(ui2-groups-browse): group payloads add org fields, creatorName, memberDirectoryAccess; cover upload tracked`

### Task 3: group history service + GET /api/groups/:id/history (SC4)
App: server
Phase: 2
Recipe: `/api` · SPEC D15 (as amended — REMOVED_ORG not read), F6, SC4 · §Contract row "GET /api/groups/:id/history"

**Files:**
- Create: `server/src/services/group-history.ts`
- Modify: `server/src/services/permission.ts` (add `findManageableGroup` after `groupManageFilter`, ~line 328)
- Modify: `server/src/routes/groups.ts` (imports; new route `GET /:id/history` after `GET /:id`, ~line 608)
- Test: `server/src/services/__tests__/group-history.test.ts`
- Test: `server/src/services/__tests__/find-manageable-group.test.ts`
- Test: `server/src/routes/__tests__/group-history.request.test.ts`

**Interfaces:**
- Consumes: Task 2's cover-upload `Activity` row (`resourceType 'GROUP'`, `action 'UPDATED'`, `metadata.field 'cover'`).
- Produces:
  - `findManageableGroup(userId: string, groupId: string): Promise<{ id: string; organizationId: string } | null>` in `server/src/services/permission.ts` — the active group if `groupManageFilter(userId)` admits it, else null. Tasks 5 and 6 use it as their 404 gate.
  - `export type GroupHistoryKind = 'member_joined' | 'member_left' | 'join_requested' | 'settings_updated' | 'cover_updated' | 'group_created' | 'event_held'`
  - `export type GroupHistoryEvent = { id: string; occurredAt: string; kind: GroupHistoryKind; text: string; highlight: string | null }`
  - `getGroupHistory(groupId: string, limit: number, now?: Date): Promise<GroupHistoryEvent[]>` in `server/src/services/group-history.ts` (newest first, at most `limit`).
  - `memberDisplayName(member: { firstName: string | null; lastName: string | null } | null): string`
  - Wire (iPhone `GroupHistoryEvent` Codable, T12): `GET /api/groups/:id/history?limit=1..50` (default 20) → `200 { success: true, events: [{ id, occurredAt (ISO 8601 with ms, UTC "Z"), kind, text, highlight }] }`; `400 { success: false, error: 'Invalid query', details }` for a limit outside 1–50 or non-integer; `404 { success: false, error: 'Group not found' }` outside `groupManageFilter` or inactive; `401` unauthenticated. `id` is opaque and unique across sources: `"membership:<uuid>"`, `"activity:<uuid>"`, `"event:<uuid>"`.
  - Copy, closed: joined `"«name» joined the group"` · left `"«name» left the group"` · requested `"«name» requested to join"` (highlight = «name») · `"Updated cover photo"` · `"Updated group settings"` · `"Created the group"` (highlight null) · `"Held event at «locationName ?? title»"` (highlight `"event at «locationName ?? title»"`).

**Risk carried from SPEC F6:** `Activity.groupId` is set on every resource type in a group (posts, events…), so a history query on `groupId` alone would pull non-group rows into the GROUP kinds — the Activity query filters `resourceType: 'GROUP'` AND `resourceId: groupId`, never `groupId`. D15 rules: `MembershipEvent` APPROVED/ADDED/REJOINED → joined, REMOVED_GROUP → left, REQUESTED → requested; INVITED, REJECTED and REMOVED_ORG are never read (REMOVED_ORG rows carry no `groupId`, `organizations.ts:1136`). `Event`: `isActive`, `type ≠ LESSON` (enrollments create one LESSON event per day), `date < now`.

- [ ] **Step 1: Write the failing service test** — `server/src/services/__tests__/group-history.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  membershipEvent: { findMany: vi.fn() },
  activity: { findMany: vi.fn() },
  event: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getGroupHistory, memberDisplayName } from '../group-history.js'

const NOW = new Date('2026-10-27T15:00:00Z')
const at = (iso: string) => new Date(iso)
const person = (firstName: string | null, lastName: string | null) => ({ firstName, lastName })

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.membershipEvent.findMany.mockResolvedValue([])
  prismaMock.activity.findMany.mockResolvedValue([])
  prismaMock.event.findMany.mockResolvedValue([])
})

describe('memberDisplayName (D15)', () => {
  it('joins first and last, trims, else Unknown', () => {
    expect(memberDisplayName(person('James', 'Carter'))).toBe('James Carter')
    expect(memberDisplayName(person('James', null))).toBe('James')
    expect(memberDisplayName(person(null, 'Carter'))).toBe('Carter')
    expect(memberDisplayName(person(null, null))).toBe('Unknown')
    expect(memberDisplayName(person('  ', ''))).toBe('Unknown')
    expect(memberDisplayName(null)).toBe('Unknown')
  })
})

describe('getGroupHistory (D15)', () => {
  it('maps membership actions to joined / left / requested with the member name highlighted', async () => {
    prismaMock.membershipEvent.findMany.mockResolvedValue([
      { id: 'me1', action: 'APPROVED', createdAt: at('2026-10-20T10:00:00Z'), member: person('James', 'Carter') },
      { id: 'me2', action: 'ADDED', createdAt: at('2026-10-19T10:00:00Z'), member: person('Emily', 'Price') },
      { id: 'me3', action: 'REJOINED', createdAt: at('2026-10-18T10:00:00Z'), member: person('Sarah', null) },
      { id: 'me4', action: 'REMOVED_GROUP', createdAt: at('2026-10-17T10:00:00Z'), member: person('Leah', 'Graham') },
      { id: 'me5', action: 'REQUESTED', createdAt: at('2026-10-16T10:00:00Z'), member: person(null, null) },
    ])
    expect(await getGroupHistory('g1', 20, NOW)).toEqual([
      { id: 'membership:me1', occurredAt: '2026-10-20T10:00:00.000Z', kind: 'member_joined', text: 'James Carter joined the group', highlight: 'James Carter' },
      { id: 'membership:me2', occurredAt: '2026-10-19T10:00:00.000Z', kind: 'member_joined', text: 'Emily Price joined the group', highlight: 'Emily Price' },
      { id: 'membership:me3', occurredAt: '2026-10-18T10:00:00.000Z', kind: 'member_joined', text: 'Sarah joined the group', highlight: 'Sarah' },
      { id: 'membership:me4', occurredAt: '2026-10-17T10:00:00.000Z', kind: 'member_left', text: 'Leah Graham left the group', highlight: 'Leah Graham' },
      { id: 'membership:me5', occurredAt: '2026-10-16T10:00:00.000Z', kind: 'join_requested', text: 'Unknown requested to join', highlight: 'Unknown' },
    ])
  })

  it('maps GROUP activity rows: CREATED, UPDATED cover, any other UPDATED', async () => {
    prismaMock.activity.findMany.mockResolvedValue([
      { id: 'a1', action: 'UPDATED', metadata: { field: 'cover' }, createdAt: at('2026-10-25T10:00:00Z') },
      { id: 'a2', action: 'UPDATED', metadata: null, createdAt: at('2026-10-24T10:00:00Z') },
      { id: 'a3', action: 'UPDATED', metadata: { field: 'name' }, createdAt: at('2026-10-23T10:00:00Z') },
      { id: 'a4', action: 'CREATED', metadata: null, createdAt: at('2026-08-01T10:00:00Z') },
    ])
    const events = await getGroupHistory('g1', 20, NOW)
    expect(events.map((e) => [e.id, e.kind, e.text, e.highlight])).toEqual([
      ['activity:a1', 'cover_updated', 'Updated cover photo', null],
      ['activity:a2', 'settings_updated', 'Updated group settings', null],
      ['activity:a3', 'settings_updated', 'Updated group settings', null],
      ['activity:a4', 'group_created', 'Created the group', null],
    ])
  })

  it('maps past events to event_held, location first, else the title', async () => {
    prismaMock.event.findMany.mockResolvedValue([
      { id: 'e1', title: 'Monthly Breakfast', locationName: 'Corner Bakery', date: at('2026-10-22T13:00:00Z') },
      { id: 'e2', title: 'Prayer Night', locationName: null, date: at('2026-10-21T01:00:00Z') },
    ])
    expect(await getGroupHistory('g1', 20, NOW)).toEqual([
      { id: 'event:e1', occurredAt: '2026-10-22T13:00:00.000Z', kind: 'event_held', text: 'Held event at Corner Bakery', highlight: 'event at Corner Bakery' },
      { id: 'event:e2', occurredAt: '2026-10-21T01:00:00.000Z', kind: 'event_held', text: 'Held event at Prayer Night', highlight: 'event at Prayer Night' },
    ])
  })

  it('merges all three sources newest first and keeps only `limit`', async () => {
    prismaMock.membershipEvent.findMany.mockResolvedValue([
      { id: 'me1', action: 'REQUESTED', createdAt: at('2026-10-26T10:00:00Z'), member: person('Ruth', 'Diaz') },
      { id: 'me2', action: 'ADDED', createdAt: at('2026-09-01T10:00:00Z'), member: person('Naomi', 'Ford') },
    ])
    prismaMock.activity.findMany.mockResolvedValue([
      { id: 'a1', action: 'UPDATED', metadata: { field: 'cover' }, createdAt: at('2026-10-24T10:00:00Z') },
    ])
    prismaMock.event.findMany.mockResolvedValue([
      { id: 'e1', title: 'Breakfast', locationName: null, date: at('2026-10-25T10:00:00Z') },
    ])
    const events = await getGroupHistory('g1', 3, NOW)
    expect(events.map((e) => e.id)).toEqual(['membership:me1', 'event:e1', 'activity:a1'])
  })

  it('queries each source scoped to the group, per D15 and F6', async () => {
    await getGroupHistory('g1', 5, NOW)
    expect(prismaMock.membershipEvent.findMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', action: { in: ['APPROVED', 'ADDED', 'REJOINED', 'REMOVED_GROUP', 'REQUESTED'] } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { id: true, action: true, createdAt: true, member: { select: { firstName: true, lastName: true } } },
    })
    // F6: resourceType + resourceId, never Activity.groupId (posts/events carry it too).
    expect(prismaMock.activity.findMany).toHaveBeenCalledWith({
      where: { resourceType: 'GROUP', resourceId: 'g1', action: { in: ['CREATED', 'UPDATED'] } },
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { id: true, action: true, metadata: true, createdAt: true },
    })
    expect(prismaMock.event.findMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', isActive: true, type: { not: 'LESSON' }, date: { lt: NOW } },
      orderBy: { date: 'desc' },
      take: 5,
      select: { id: true, title: true, locationName: true, date: true },
    })
  })
})
```

- [ ] **Step 2: Write the failing permission test** — `server/src/services/__tests__/find-manageable-group.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  user: { findUnique: vi.fn() },
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
  group: { findFirst: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { findManageableGroup } from '../permission.js'

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.user.findUnique.mockResolvedValue({ isSuperAdmin: false })
  prismaMock.organization.findMany.mockResolvedValue([{ id: 'o1' }])
  prismaMock.userRole.findMany.mockResolvedValue([])
  prismaMock.group.findFirst.mockResolvedValue({ id: 'g1', organizationId: 'o1' })
})

describe('findManageableGroup (ui2-groups-browse D9, D14, D15)', () => {
  it('resolves the active group through groupManageFilter', async () => {
    expect(await findManageableGroup('u1', 'g1')).toEqual({ id: 'g1', organizationId: 'o1' })
    expect(prismaMock.group.findFirst).toHaveBeenCalledWith({
      where: { id: 'g1', OR: [{ creatorId: 'u1' }, { organizationId: { in: ['o1'] } }], isActive: true },
      select: { id: true, organizationId: true },
    })
  })

  it('gives a super admin every active group', async () => {
    prismaMock.user.findUnique.mockResolvedValue({ isSuperAdmin: true })
    await findManageableGroup('admin', 'g9')
    expect(prismaMock.group.findFirst).toHaveBeenCalledWith({
      where: { id: 'g9', isActive: true },
      select: { id: true, organizationId: true },
    })
  })

  it('returns null outside the caller’s scope', async () => {
    prismaMock.group.findFirst.mockResolvedValue(null)
    expect(await findManageableGroup('u1', 'g-other')).toBeNull()
  })
})
```

- [ ] **Step 3: Write the failing route test** — `server/src/routes/__tests__/group-history.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))
vi.mock('../../services/group-history.js', () => ({ getGroupHistory: vi.fn() }))

import { findManageableGroup } from '../../services/permission.js'
import { getGroupHistory } from '../../services/group-history.js'
import groupsRoutes from '../groups.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupsRoutes)
  return a
}

const EVENT = { id: 'event:e1', occurredAt: '2026-10-22T13:00:00.000Z', kind: 'event_held', text: 'Held event at Corner Bakery', highlight: 'event at Corner Bakery' }

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org1' })
  vi.mocked(getGroupHistory).mockResolvedValue([EVENT] as never)
})

describe('GET /api/groups/:id/history (D15, SC4)', () => {
  it('returns { success, events } with limit 20 by default', async () => {
    const res = await request(app()).get('/api/groups/g1/history')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, events: [EVENT] })
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(getGroupHistory).toHaveBeenCalledWith('g1', 20)
  })

  it('passes limit through', async () => {
    await request(app()).get('/api/groups/g1/history?limit=5')
    expect(getGroupHistory).toHaveBeenCalledWith('g1', 5)
  })

  it.each(['0', '51', 'abc', '2.5', ''])('400s limit=%s before reading anything', async (limit) => {
    const res = await request(app()).get(`/api/groups/g1/history?limit=${limit}`)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(getGroupHistory).not.toHaveBeenCalled()
  })

  it('404s a group outside the caller’s manage scope (or inactive)', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(app()).get('/api/groups/g-other/history')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(getGroupHistory).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 4: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/group-history.test.ts src/services/__tests__/find-manageable-group.test.ts src/routes/__tests__/group-history.request.test.ts` → FAIL (cannot resolve `../group-history.js`; `findManageableGroup` is not a function; route 404s as `GET /:id` never matches `/g1/history`)

- [ ] **Step 5: Write the service** — `server/src/services/group-history.ts`

```ts
/**
 * Group history feed (ui2-groups-browse D15, F6): the group page's Timeline, merged newest-first from
 * three sources already recorded — MembershipEvent (joins, leaves, requests), the Activity ledger's
 * GROUP rows (created, settings, cover) and the group's past non-lesson Events. Read-only.
 */
import { prisma } from '../lib/prisma.js'

export type GroupHistoryKind =
  | 'member_joined'
  | 'member_left'
  | 'join_requested'
  | 'settings_updated'
  | 'cover_updated'
  | 'group_created'
  | 'event_held'

export type GroupHistoryEvent = {
  id: string
  occurredAt: string
  kind: GroupHistoryKind
  text: string
  highlight: string | null
}

/** D15: INVITED, REJECTED and REMOVED_ORG are never read (REMOVED_ORG carries no groupId). */
const MEMBERSHIP_KIND = {
  APPROVED: 'member_joined',
  ADDED: 'member_joined',
  REJOINED: 'member_joined',
  REMOVED_GROUP: 'member_left',
  REQUESTED: 'join_requested',
} as const satisfies Record<string, GroupHistoryKind>
type ReadAction = keyof typeof MEMBERSHIP_KIND
const READ_ACTIONS = Object.keys(MEMBERSHIP_KIND) as ReadAction[]

const ACTIVITY_TEXT = {
  group_created: 'Created the group',
  cover_updated: 'Updated cover photo',
  settings_updated: 'Updated group settings',
} as const

/** «name» = first + " " + last, trimmed, else "Unknown" (as group-members.ts:221). */
export function memberDisplayName(member: { firstName: string | null; lastName: string | null } | null): string {
  const name = `${member?.firstName ?? ''} ${member?.lastName ?? ''}`.trim()
  return name || 'Unknown'
}

function membershipText(kind: (typeof MEMBERSHIP_KIND)[ReadAction], name: string): string {
  if (kind === 'member_joined') return `${name} joined the group`
  if (kind === 'member_left') return `${name} left the group`
  return `${name} requested to join`
}

function metadataField(metadata: unknown): unknown {
  return metadata !== null && typeof metadata === 'object' && !Array.isArray(metadata)
    ? (metadata as Record<string, unknown>).field
    : undefined
}

export async function getGroupHistory(groupId: string, limit: number, now: Date = new Date()): Promise<GroupHistoryEvent[]> {
  const [memberships, activities, events] = await Promise.all([
    prisma.membershipEvent.findMany({
      where: { groupId, action: { in: READ_ACTIONS } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true, action: true, createdAt: true, member: { select: { firstName: true, lastName: true } } },
    }),
    // F6: Activity.groupId is set for every resource in the group — match the GROUP resource itself.
    prisma.activity.findMany({
      where: { resourceType: 'GROUP', resourceId: groupId, action: { in: ['CREATED', 'UPDATED'] } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { id: true, action: true, metadata: true, createdAt: true },
    }),
    // Enrollments create one LESSON event per day (enrollments.ts:342) — those are not history.
    prisma.event.findMany({
      where: { groupId, isActive: true, type: { not: 'LESSON' }, date: { lt: now } },
      orderBy: { date: 'desc' },
      take: limit,
      select: { id: true, title: true, locationName: true, date: true },
    }),
  ])

  const out: GroupHistoryEvent[] = []
  for (const m of memberships) {
    const kind = MEMBERSHIP_KIND[m.action as ReadAction]
    const name = memberDisplayName(m.member)
    out.push({ id: `membership:${m.id}`, occurredAt: m.createdAt.toISOString(), kind, text: membershipText(kind, name), highlight: name })
  }
  for (const a of activities) {
    const kind: keyof typeof ACTIVITY_TEXT =
      a.action === 'CREATED' ? 'group_created' : metadataField(a.metadata) === 'cover' ? 'cover_updated' : 'settings_updated'
    out.push({ id: `activity:${a.id}`, occurredAt: a.createdAt.toISOString(), kind, text: ACTIVITY_TEXT[kind], highlight: null })
  }
  for (const e of events) {
    const place = e.locationName ?? e.title
    out.push({
      id: `event:${e.id}`,
      occurredAt: e.date.toISOString(),
      kind: 'event_held',
      text: `Held event at ${place}`,
      highlight: `event at ${place}`,
    })
  }
  return out
    .sort((x, y) => y.occurredAt.localeCompare(x.occurredAt) || x.id.localeCompare(y.id))
    .slice(0, limit)
}
```

- [ ] **Step 6: Add the gate to `server/src/services/permission.ts`** — directly after `groupManageFilter`:

```ts
/**
 * The active group `groupId` when `userId` may manage it (`groupManageFilter`), else null — the
 * 404 gate shared by the group history (ui2-groups-browse D15), `/api/home/days?groupId` (D14) and
 * the group member list + membership history (D9).
 */
export async function findManageableGroup(
  userId: string,
  groupId: string
): Promise<{ id: string; organizationId: string } | null> {
  return prisma.group.findFirst({
    where: { id: groupId, ...(await groupManageFilter(userId)), isActive: true },
    select: { id: true, organizationId: true },
  })
}
```

- [ ] **Step 7: Add the route to `server/src/routes/groups.ts`** — imports:

```ts
import { isSuperAdmin, groupManageFilter, findManageableGroup } from '../services/permission.js'
import { getGroupHistory } from '../services/group-history.js'
```

and directly after the `GET /:id` handler:

```ts
const historyQuery = z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) })

/**
 * @openapi
 * /api/groups/{id}/history:
 *   get:
 *     tags: [Groups]
 *     summary: Group history feed
 *     description: |
 *       Newest-first merge of the group's membership events (joined / left / requested), its
 *       GROUP activity rows (created, settings, cover) and its past non-lesson events
 *       (ui2-groups-browse D15).
 *     security:
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: query
 *         name: limit
 *         schema: { type: integer, minimum: 1, maximum: 50, default: 20 }
 *     responses:
 *       200:
 *         description: History events
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success: { type: boolean, example: true }
 *                 events:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id: { type: string }
 *                       occurredAt: { type: string, format: date-time }
 *                       kind:
 *                         type: string
 *                         enum: [member_joined, member_left, join_requested, settings_updated, cover_updated, group_created, event_held]
 *                       text: { type: string }
 *                       highlight: { type: string, nullable: true }
 *       400:
 *         description: Invalid limit
 *       404:
 *         description: Group not found
 */
router.get('/:id/history', requireAuth, async (req, res) => {
  try {
    const parsed = historyQuery.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({ success: false, error: 'Invalid query', details: parsed.error.errors })
    }
    const userId = (req.user as any).id
    if (!(await findManageableGroup(userId, req.params.id))) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }
    const events = await getGroupHistory(req.params.id, parsed.data.limit)
    res.json({ success: true, events })
  } catch (error) {
    console.error('Error fetching group history:', error)
    res.status(500).json({ success: false, error: 'Failed to fetch group history' })
  }
})
```

- [ ] **Step 8: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/group-history.test.ts src/services/__tests__/find-manageable-group.test.ts src/routes/__tests__/group-history.request.test.ts src/routes/__tests__/groups-browse-fields.request.test.ts` → PASS; `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 9: Commit** — `feat(ui2-groups-browse): GET /api/groups/:id/history merges membership, activity and event history`

### Task 4: next-study title, versionId, thumbnailUrl (SC5)
App: server
Phase: 2
Recipe: `/api` · SPEC D17, T6, SC5 · §Contract row "GET /api/groups/:id/next-study"

**Files:**
- Create: `server/src/services/next-study-thumbnail.ts`
- Modify: `server/src/routes/enrollments.ts` — `GET /groups/:groupId/next-study` (~1283-1369) + imports (~line 22)
- Test: `server/src/services/__tests__/next-study-thumbnail.test.ts`
- Test: `server/src/routes/__tests__/next-study.request.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `activityThumbnailUrl(activity: ThumbnailSource): string | null` and `interface ThumbnailSource { type: string; youtubeThumbnailUrl: string | null; video: { thumbnailUrl: string | null } | null; readBlocks: Array<{ backgroundImageUrl: string | null }> }` in `server/src/services/next-study-thumbnail.ts` (Task 7's fixture DB test reuses it).
  - Wire (iPhone `NextStudy` Codable, T11): `GET /api/groups/:groupId/next-study` → `200 { success: true, study: { id, code, title: string | null, dayNumber, scheduledDate, enrollment, studyProgram, activities: [{ id, type, orderNumber, title, videoUrl, sourceReferences, versionId: string | null, thumbnailUrl: string | null }] } }`; `204` (no body) when nothing is scheduled today or later — unchanged; `404` outside scope — unchanged. `activities` holds only the schedule's current version (plus legacy null-version rows), ordered by `orderNumber`.
  - `thumbnailUrl` rule (T6): `youtubeThumbnailUrl` ?? `video.thumbnailUrl` ?? (READ only) the `backgroundImageUrl` of the lowest-`orderNumber` read block that has one ?? `null`.

Note: the activity select had no `versionId`, so `filterActivitiesToVersion` (`lesson-version-resolution.ts:50`) kept every version's rows — selecting it is the fix. `title` is a LessonSchedule scalar, so `include` already returns it. The route keeps `scheduledDate >= today` with `today` = the server's local midnight (`enrollments.ts:~1303`) — unchanged.

- [ ] **Step 1: Write the failing helper test** — `server/src/services/__tests__/next-study-thumbnail.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { activityThumbnailUrl, type ThumbnailSource } from '../next-study-thumbnail.js'

const src = (over: Partial<ThumbnailSource>): ThumbnailSource => ({
  type: 'READ',
  youtubeThumbnailUrl: null,
  video: null,
  readBlocks: [],
  ...over,
})

describe('activityThumbnailUrl (D17, T6)', () => {
  it('prefers the YouTube thumbnail', () => {
    expect(
      activityThumbnailUrl(src({ type: 'YOUTUBE', youtubeThumbnailUrl: 'https://yt/1.jpg', video: { thumbnailUrl: 'https://v/1.jpg' } }))
    ).toBe('https://yt/1.jpg')
  })

  it('falls back to the uploaded video’s thumbnail', () => {
    expect(activityThumbnailUrl(src({ type: 'VIDEO', video: { thumbnailUrl: 'https://v/1.jpg' } }))).toBe('https://v/1.jpg')
  })

  it('uses the first read block image of a READ activity', () => {
    expect(
      activityThumbnailUrl(src({ type: 'READ', readBlocks: [{ backgroundImageUrl: null }, { backgroundImageUrl: 'https://r/2.jpg' }] }))
    ).toBe('https://r/2.jpg')
  })

  it('ignores read blocks on a non-READ activity', () => {
    expect(activityThumbnailUrl(src({ type: 'USER_INPUT', readBlocks: [{ backgroundImageUrl: 'https://r/2.jpg' }] }))).toBeNull()
  })

  it('is null with no source (incl. a video without a thumbnail)', () => {
    expect(activityThumbnailUrl(src({ type: 'VIDEO', video: { thumbnailUrl: null } }))).toBeNull()
    expect(activityThumbnailUrl(src({ type: 'READ' }))).toBeNull()
  })
})
```

- [ ] **Step 2: Write the failing route test** — `server/src/routes/__tests__/next-study.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ group: { findFirst: vi.fn() }, lessonSchedule: { findFirst: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
}))

import enrollmentsRoutes from '../enrollments.js'

function app() {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: { id: 'u1', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api', enrollmentsRoutes)
  return a
}

const act = (over: Record<string, unknown>) => ({
  id: 'a',
  type: 'READ',
  orderNumber: 1,
  title: 'Activity',
  videoUrl: null,
  sourceReferences: [],
  versionId: null,
  youtubeThumbnailUrl: null,
  video: null,
  readBlocks: [],
  ...over,
})

const schedule = (over: Record<string, unknown> = {}) => ({
  id: 's1',
  code: 'XYZ123',
  title: 'Love one another',
  currentVersionId: 'v2',
  scheduledDate: new Date('2026-10-27T17:00:00Z'),
  lesson: {
    dayNumber: 14,
    studyProgram: { id: 'p1', name: 'Foundations of Faith', description: null, days: 21, coverImageUrl: null, requireResponse: false },
  },
  enrollment: { id: 'e1', requireResponse: false, startDate: new Date('2026-10-14T17:00:00Z'), endDate: new Date('2026-11-03T17:00:00Z') },
  scheduledActivities: [
    act({ id: 'a-old', versionId: 'v1', type: 'YOUTUBE', youtubeThumbnailUrl: 'https://img.test/old.jpg' }),
    act({ id: 'a1', versionId: 'v2', orderNumber: 1, type: 'YOUTUBE', youtubeThumbnailUrl: 'https://i.ytimg.com/vi/x/hqdefault.jpg' }),
    act({ id: 'a2', versionId: 'v2', orderNumber: 2, type: 'VIDEO', video: { thumbnailUrl: 'https://img.test/video.jpg' } }),
    act({ id: 'a3', versionId: 'v2', orderNumber: 3, type: 'READ', readBlocks: [{ backgroundImageUrl: 'https://img.test/read.jpg' }] }),
    act({ id: 'a4', versionId: 'v2', orderNumber: 4, type: 'USER_INPUT' }),
  ],
  ...over,
})

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findFirst.mockResolvedValue({ id: 'g1' })
  prismaMock.lessonSchedule.findFirst.mockResolvedValue(schedule())
})

describe('GET /api/groups/:groupId/next-study (D17, SC5)', () => {
  it('adds study.title and per-activity thumbnailUrl, current version only', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    expect(res.status).toBe(200)
    expect(res.body.study.title).toBe('Love one another')
    expect(res.body.study.dayNumber).toBe(14)
    expect(res.body.study.activities.map((a: { id: string; thumbnailUrl: string | null }) => [a.id, a.thumbnailUrl])).toEqual([
      ['a1', 'https://i.ytimg.com/vi/x/hqdefault.jpg'],
      ['a2', 'https://img.test/video.jpg'],
      ['a3', 'https://img.test/read.jpg'],
      ['a4', null],
    ])
  })

  it('keeps the wire free of the thumbnail source fields', async () => {
    const res = await request(app()).get('/api/groups/g1/next-study')
    const first = res.body.study.activities[0]
    expect(first).not.toHaveProperty('youtubeThumbnailUrl')
    expect(first).not.toHaveProperty('video')
    expect(first).not.toHaveProperty('readBlocks')
    expect(first).toMatchObject({ id: 'a1', type: 'YOUTUBE', orderNumber: 1, title: 'Activity', videoUrl: null, versionId: 'v2' })
  })

  it('selects versionId and the three thumbnail sources', async () => {
    await request(app()).get('/api/groups/g1/next-study')
    const select = prismaMock.lessonSchedule.findFirst.mock.calls[0][0].include.scheduledActivities.select
    expect(select).toMatchObject({
      versionId: true,
      youtubeThumbnailUrl: true,
      video: { select: { thumbnailUrl: true } },
      readBlocks: {
        where: { backgroundImageUrl: { not: null } },
        orderBy: { orderNumber: 'asc' },
        take: 1,
        select: { backgroundImageUrl: true },
      },
    })
  })

  it('reads title null when the schedule has none', async () => {
    prismaMock.lessonSchedule.findFirst.mockResolvedValue(schedule({ title: null }))
    expect((await request(app()).get('/api/groups/g1/next-study')).body.study.title).toBeNull()
  })

  it('still answers 204 with nothing upcoming and 404 outside scope', async () => {
    prismaMock.lessonSchedule.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g1/next-study')).status).toBe(204)
    prismaMock.group.findFirst.mockResolvedValue(null)
    expect((await request(app()).get('/api/groups/g-other/next-study')).status).toBe(404)
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/next-study-thumbnail.test.ts src/routes/__tests__/next-study.request.test.ts` → FAIL (cannot resolve `../next-study-thumbnail.js`; `study.title` undefined; `a-old` present; no `thumbnailUrl`)

- [ ] **Step 4: Write the helper** — `server/src/services/next-study-thumbnail.ts`

```ts
/**
 * One image per next-lesson activity (ui2-groups-browse D17, T6): the YouTube thumbnail, else the
 * uploaded video's thumbnail, else (READ only) the first read block with a background image.
 */
export interface ThumbnailSource {
  type: string
  youtubeThumbnailUrl: string | null
  video: { thumbnailUrl: string | null } | null
  /** Ordered by orderNumber; the route asks only for blocks that have an image. */
  readBlocks: Array<{ backgroundImageUrl: string | null }>
}

export function activityThumbnailUrl(activity: ThumbnailSource): string | null {
  if (activity.youtubeThumbnailUrl) return activity.youtubeThumbnailUrl
  if (activity.video?.thumbnailUrl) return activity.video.thumbnailUrl
  if (activity.type === 'READ') {
    return activity.readBlocks.find((block) => block.backgroundImageUrl)?.backgroundImageUrl ?? null
  }
  return null
}
```

- [ ] **Step 5: Wire it into the route** — in `server/src/routes/enrollments.ts` add the import beside `filterActivitiesToVersion`:

```ts
import { activityThumbnailUrl } from '../services/next-study-thumbnail.js'
```

replace the `scheduledActivities` include of the next-study query with:

```ts
        scheduledActivities: {
          orderBy: { orderNumber: 'asc' },
          select: {
            id: true,
            type: true,
            orderNumber: true,
            title: true,
            videoUrl: true,
            // ui2-groups-browse D17: without versionId, filterActivitiesToVersion keeps every version.
            versionId: true,
            sourceReferences: {
              select: { passageReference: true },
            },
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
```

and replace the `study` object with:

```ts
    const study = {
      id: nextLesson.id,
      code: nextLesson.code,
      title: nextLesson.title ?? null,
      dayNumber: nextLesson.lesson?.dayNumber ?? 0,
      scheduledDate: nextLesson.scheduledDate,
      enrollment: nextLesson.enrollment,
      studyProgram: nextLesson.lesson?.studyProgram ?? null,
      activities: filterActivitiesToVersion(nextLesson.scheduledActivities, nextLesson.currentVersionId).map(
        ({ youtubeThumbnailUrl, video, readBlocks, ...activity }) => ({
          ...activity,
          thumbnailUrl: activityThumbnailUrl({ type: activity.type, youtubeThumbnailUrl, video, readBlocks }),
        })
      ),
    }
```

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/next-study-thumbnail.test.ts src/routes/__tests__/next-study.request.test.ts` → PASS; `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 7: Commit** — `feat(ui2-groups-browse): next-study returns title, current-version activities and thumbnailUrl`

### Task 5: /api/home/days groupId (SC6)
App: server
Phase: 2
Recipe: `/api` · SPEC D14, T7, SC6 · §Contract row "GET /api/home/days (+ groupId)"

**Files:**
- Modify: `server/src/routes/home.ts` (`daysQuery` ~line 21; `GET /days` handler; imports)
- Modify: `server/src/services/home-dashboard.ts` (`getHomeDays`, ~line 246)
- Modify: `server/src/services/home-sessions.ts` (`loadSessions`, ~line 64)
- Modify: `server/src/services/__tests__/home-sessions.test.ts`, `server/src/services/__tests__/home-dashboard.test.ts`
- Test: `server/src/routes/__tests__/home-days-group.request.test.ts`

**Interfaces:**
- Consumes: Task 3 — `findManageableGroup(userId: string, groupId: string): Promise<{ id: string; organizationId: string } | null>` from `server/src/services/permission.ts`.
- Produces:
  - `loadSessions(scope, window, opts?: { memberId?: string; groupId?: string })`; `getHomeDays(scope, from, to, tz, opts?: { memberId?: string; groupId?: string })`.
  - Wire (iPhone `GroupActions.loadGroupDays`, T13, reusing `HomeDay`): `GET /api/home/days?from=YYYY-MM-DD&to=YYYY-MM-DD&tz=<IANA>&groupId=<uuid>` → `200 { days: [{ day, sessionSeconds, blocks: number[12] (seconds), lastActivityAt }] }` — the existing shape, sessions only of members with an active `GroupMember` row in that group (a member of two groups counts in both). `400 { success: false, error: 'memberId and groupId cannot be combined' }` when both are sent; `400` for an empty `groupId`; `404 { success: false, error: 'Not found' }` when the group fails `groupManageFilter` / is inactive, or the caller has no user id (API-key caller); `401` unauthenticated.

Note: `daysQuery` is a `z.object`, which strips undeclared keys — `groupId` must be declared or the rail silently reads the whole org (T7).

- [ ] **Step 1: Write the failing sessions test** — in `server/src/services/__tests__/home-sessions.test.ts`, add `groupMember: { findMany: vi.fn() },` to the `prismaMock` hoisted object, then add inside `describe('loadSessions (D2 sources)', …)` after the memberId test:

```ts
  it('narrows every source to the group’s active members when groupId is set (ui2-groups-browse D14)', async () => {
    prismaMock.groupMember.findMany.mockResolvedValue([{ memberId: 'm1' }, { memberId: 'm3' }, { memberId: 'm1' }])
    await loadSessions(scope, window, { groupId: 'g1' })
    expect(prismaMock.groupMember.findMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', isActive: true, memberId: { not: null } },
      select: { memberId: true },
    })
    const inGroup = { in: ['m1', 'm3'] }
    expect(prismaMock.clientEvent.findMany.mock.calls[0][0].where.memberId).toEqual(inGroup)
    expect(prismaMock.memberLessonProgress.findMany.mock.calls[0][0].where.memberId).toEqual(inGroup)
    expect(prismaMock.memberVideoProgress.findMany.mock.calls[0][0].where.memberId).toEqual(inGroup)
  })

  it('counts a member of two groups in both (D14)', async () => {
    prismaMock.groupMember.findMany.mockImplementation(async ({ where }: any) =>
      where.groupId === 'g1' ? [{ memberId: 'm1' }] : [{ memberId: 'm1' }, { memberId: 'm2' }]
    )
    prismaMock.clientEvent.findMany.mockImplementation(async ({ where }: any) =>
      [
        { memberId: 'm1', occurredAt: at('2026-10-20T10:05:00Z') },
        { memberId: 'm2', occurredAt: at('2026-10-20T10:30:00Z') },
      ].filter((e) => where.memberId.in.includes(e.memberId))
    )
    prismaMock.member.findMany.mockResolvedValue([{ id: 'm1' }, { id: 'm2' }])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([])
    prismaMock.memberVideoProgress.findMany.mockResolvedValue([])
    expect((await loadSessions(scope, window, { groupId: 'g1' })).map((s) => s.memberId)).toEqual(['m1'])
    expect((await loadSessions(scope, window, { groupId: 'g2' })).map((s) => s.memberId)).toEqual(['m1', 'm2'])
  })

  it('reads no group members when groupId is absent', async () => {
    await loadSessions(scope, window)
    expect(prismaMock.groupMember.findMany).not.toHaveBeenCalled()
  })
```

- [ ] **Step 2: Write the failing dashboard test** — in `server/src/services/__tests__/home-dashboard.test.ts`, inside `describe('getHomeDays', …)`:

```ts
  it('passes groupId through to loadSessions (ui2-groups-browse D14)', async () => {
    vi.mocked(loadSessions).mockResolvedValue([])
    await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI, { groupId: 'g1' })
    expect(loadSessions).toHaveBeenCalledWith(
      SCOPE,
      { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') },
      { groupId: 'g1' }
    )
  })
```

- [ ] **Step 3: Write the failing route test** — `server/src/routes/__tests__/home-days-group.request.test.ts`

```ts
/**
 * /api/home/days?groupId (ui2-groups-browse D14): the group must pass groupManageFilter for the
 * caller; sessions narrow to its members. Scope, the dashboard service and the gate are stubbed.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const pgMock = vi.hoisted(() => ({
  query: vi.fn().mockResolvedValue({ rows: [{ exists: true }] }),
  release: vi.fn(),
}))
vi.mock('pg', () => ({
  default: { Pool: vi.fn().mockImplementation(() => ({ connect: vi.fn().mockResolvedValue(pgMock) })) },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: {}, Prisma: {} }))
vi.mock('../../services/analytics-scope.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/analytics-scope.js')>()),
  deriveAnalyticsScope: vi.fn(),
}))
vi.mock('../../services/home-dashboard.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/home-dashboard.js')>()),
  getHomeDays: vi.fn(),
}))
vi.mock('../../services/member-access.js', () => ({ canViewMember: vi.fn(), visibleMemberOrgIds: vi.fn() }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))

import { deriveAnalyticsScope } from '../../services/analytics-scope.js'
import { getHomeDays } from '../../services/home-dashboard.js'
import { findManageableGroup } from '../../services/permission.js'
import homeRoutes from '../home.js'

const SCOPE = { all: false as const, orgIds: ['org-1'], groupIds: [] as string[] }
const DAYS = { days: [{ day: '2026-10-27', sessionSeconds: 600, blocks: Array(12).fill(0), lastActivityAt: null }] }

/** requireAuth passes when req.user and req.apiKeyId are set; `user` without an id = an API-key caller. */
function appAs(user: { id?: string; isActive: boolean }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { user, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/home', homeRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(deriveAnalyticsScope).mockResolvedValue(SCOPE)
  vi.mocked(getHomeDays).mockResolvedValue(DAYS as never)
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org-1' })
})

describe('GET /api/home/days?groupId (D14)', () => {
  it('reads the group’s days when the caller manages it', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get(
      '/api/home/days?from=2026-09-28&to=2026-10-27&tz=America%2FChicago&groupId=g1'
    )
    expect(res.status).toBe(200)
    expect(res.body).toEqual(DAYS)
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-09-28', '2026-10-27', 'America/Chicago', { groupId: 'g1' })
  })

  it('404s a group outside the caller’s manage scope, before reading sessions', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=g-other')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('404s a caller with no user id (API-key caller), as the memberId path', async () => {
    const res = await request(appAs({ isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=g1')
    expect(res.status).toBe(404)
    expect(findManageableGroup).not.toHaveBeenCalled()
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s memberId together with groupId', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get(
      '/api/home/days?from=2026-10-01&to=2026-10-02&memberId=m1&groupId=g1'
    )
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'memberId and groupId cannot be combined' })
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s an empty groupId (it is declared, never stripped)', async () => {
    const res = await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-02&groupId=')
    expect(res.status).toBe(400)
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('keeps Home’s call exactly as it was without groupId', async () => {
    await request(appAs({ id: 'u1', isActive: true })).get('/api/home/days?from=2026-10-01&to=2026-10-31&organizationId=org-1')
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-10-01', '2026-10-31', 'UTC')
    expect(vi.mocked(getHomeDays).mock.calls[0]).toHaveLength(4)
    expect(findManageableGroup).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 4: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/home-sessions.test.ts src/services/__tests__/home-dashboard.test.ts src/routes/__tests__/home-days-group.request.test.ts` → FAIL (groupMember never queried; getHomeDays ignores groupId; the route strips groupId and answers 200 with the org's days)

- [ ] **Step 5: Implement `loadSessions`'s member filter** — in `server/src/services/home-sessions.ts`, add above `loadSessions`:

```ts
type MemberFilter = { memberId?: string | { in: string[] } }

/** ui2-members-browse D12: one member · ui2-groups-browse D14: the active members of one group. */
async function memberFilter(opts: { memberId?: string; groupId?: string }): Promise<MemberFilter> {
  if (opts.memberId) return { memberId: opts.memberId }
  if (!opts.groupId) return {}
  const rows = await prisma.groupMember.findMany({
    where: { groupId: opts.groupId, isActive: true, memberId: { not: null } },
    select: { memberId: true },
  })
  return { memberId: { in: [...new Set(rows.flatMap((r) => (r.memberId ? [r.memberId] : [])))] } }
}
```

change the signature to `opts: { memberId?: string; groupId?: string } = {}` and replace

```ts
  // ui2-members-browse D12: the member page's day rail reads one member's sessions.
  const member = opts.memberId ? { memberId: opts.memberId } : {}
```

with

```ts
  // ui2-members-browse D12 (member page rail) / ui2-groups-browse D14 (group page rail).
  const member = await memberFilter(opts)
```

- [ ] **Step 6: Pass groupId through `getHomeDays`** — in `server/src/services/home-dashboard.ts`:

```ts
export async function getHomeDays(
  scope: AnalyticsScope,
  from: string,
  to: string,
  tz: string,
  opts: { memberId?: string; groupId?: string } = {}
): Promise<{ days: HomeDay[] }> {
  const window = { from: zonedMidnight(from, tz), to: zonedMidnight(addDays(to, 1), tz) }
  const sessions = opts.memberId
    ? await loadSessions(scope, window, { memberId: opts.memberId })
    : opts.groupId
      ? await loadSessions(scope, window, { groupId: opts.groupId })
      : await loadSessions(scope, window)
  return { days: bucketDays(sessions, from, to, tz) }
}
```

- [ ] **Step 7: Gate it in the route** — in `server/src/routes/home.ts` add the import

```ts
import { findManageableGroup } from '../services/permission.js'
```

declare the key in `daysQuery` (after `memberId`):

```ts
  // ui2-groups-browse D14: declared, or z.object strips it and the group rail would read the whole org.
  groupId: z.string().min(1).max(64).optional(),
```

in the `/days` handler, directly after the `rangeError` check:

```ts
    if (parsed.data.memberId && parsed.data.groupId) {
      return res.status(400).json({ success: false, error: 'memberId and groupId cannot be combined' })
    }
```

and replace `const { from, to, memberId, organizationId: orgId } = parsed.data` plus the `if (!memberId) { … }` block that follows it with:

```ts
    const { from, to, memberId, groupId, organizationId: orgId } = parsed.data
    if (groupId) {
      // D14: the caller must manage the group (groupManageFilter + isActive); an API-key caller has no user id.
      const groupUserId = callerOf(req).userId
      if (!groupUserId || !(await findManageableGroup(groupUserId, groupId))) {
        res.status(404).json({ success: false, error: 'Not found' })
        return
      }
      res.json(await getHomeDays(scope, from, to, parsed.data.tz, { groupId }))
      return
    }
    if (!memberId) {
      res.json(await getHomeDays(scope, from, to, parsed.data.tz))
      return
    }
```

(the memberId path below stays exactly as it is.)

- [ ] **Step 8: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/home-sessions.test.ts src/services/__tests__/home-dashboard.test.ts src/routes/__tests__/home-days-group.request.test.ts src/routes/__tests__/home.test.ts` → PASS (home.test unchanged and green); `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 9: Commit** — `feat(ui2-groups-browse): /api/home/days takes groupId, gated by groupManageFilter`

### Task 6: scope GET group members + membership-history (D9)
App: server
Phase: 2
Recipe: `/api` · SPEC D9, T8, F2 · §Contract row "GET /api/groups/:groupId/members, /membership-history (scoped)"

**Files:**
- Modify: `server/src/routes/group-members.ts` — imports (~1-17), `GET /:groupId/members` (~187), `GET /:groupId/membership-history` (~712)
- Test: `server/src/routes/__tests__/group-members-scope.request.test.ts`

**Interfaces:**
- Consumes: Task 3 — `findManageableGroup(userId: string, groupId: string): Promise<{ id: string; organizationId: string } | null>` from `server/src/services/permission.ts`.
- Produces (wire, iPhone `GroupActions` members load): both endpoints' 200 bodies unchanged — `GET /api/groups/:groupId/members` → `{ success: true, members: [{ id (GroupMember id), userId (Member id), groupId, role, name, avatarUrl, joinedAt }] }`; `GET /api/groups/:groupId/membership-history` → `{ success: true, events }`. NEW: `404 { success: false, error: 'Group not found' }` when the caller does not manage the group (`groupManageFilter`), the group is inactive, or the caller has no user id; checked before any member row is read.

**Risk carried from SPEC F2:** this is the one non-additive change. Audited callers of GET members — `GroupActions.swift:428`, `client/…/members.domain.ts:57`, `leader-group-home.store.ts:337`, `leader-groups.store.ts:155` — all pass group ids from manage-scoped lists, so no in-scope caller gets a new 404; membership-history has no live caller. POST/PATCH/DELETE in this file already use `requireGroupManage` — leave them alone.

- [ ] **Step 1: Write the failing test** — `server/src/routes/__tests__/group-members-scope.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ groupMember: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  findManageableGroup: vi.fn(),
}))
vi.mock('../../services/membership-event.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/membership-event.js')>()),
  getMembershipHistory: vi.fn(),
}))

import { findManageableGroup } from '../../services/permission.js'
import { getMembershipHistory } from '../../services/membership-event.js'
import groupMembersRoutes from '../group-members.js'

function appAs(user: { id?: string; isActive: boolean }) {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user, apiKeyId: 'test-key' })
    next()
  })
  a.use('/api/groups', groupMembersRoutes)
  return a
}
const leader = () => appAs({ id: 'u1', isActive: true })

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(findManageableGroup).mockResolvedValue({ id: 'g1', organizationId: 'org1' })
  prismaMock.groupMember.findMany.mockResolvedValue([
    {
      id: 'gm1',
      memberId: 'm1',
      groupId: 'g1',
      role: 'member',
      joinedAt: new Date('2026-10-01T15:00:00Z'),
      member: { firstName: 'James', lastName: 'Carter', profilePicture: null },
    },
  ])
  vi.mocked(getMembershipHistory).mockResolvedValue([{ id: 'me1' }] as never)
})

describe('GET /api/groups/:groupId/members (D9)', () => {
  it('lists members of a group the caller manages, shape unchanged', async () => {
    const res = await request(leader()).get('/api/groups/g1/members')
    expect(res.status).toBe(200)
    expect(findManageableGroup).toHaveBeenCalledWith('u1', 'g1')
    expect(res.body).toEqual({
      success: true,
      members: [
        { id: 'gm1', userId: 'm1', groupId: 'g1', role: 'MEMBER', name: 'James Carter', avatarUrl: null, joinedAt: '2026-10-01T15:00:00.000Z' },
      ],
    })
  })

  it('404s outside the caller’s manage scope, before reading members', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(leader()).get('/api/groups/g-other/members')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(prismaMock.groupMember.findMany).not.toHaveBeenCalled()
  })

  it('404s a caller with no user id', async () => {
    const res = await request(appAs({ isActive: true })).get('/api/groups/g1/members')
    expect(res.status).toBe(404)
    expect(findManageableGroup).not.toHaveBeenCalled()
  })
})

describe('GET /api/groups/:groupId/membership-history (D9)', () => {
  it('returns history for a group the caller manages', async () => {
    const res = await request(leader()).get('/api/groups/g1/membership-history?limit=10')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, events: [{ id: 'me1' }] })
    expect(getMembershipHistory).toHaveBeenCalledWith({ groupId: 'g1', search: undefined, action: undefined, limit: 10 })
  })

  it('404s outside the caller’s manage scope, before reading history', async () => {
    vi.mocked(findManageableGroup).mockResolvedValue(null)
    const res = await request(leader()).get('/api/groups/g-other/membership-history')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Group not found' })
    expect(getMembershipHistory).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/group-members-scope.request.test.ts` → FAIL (both out-of-scope cases answer 200; `findManageableGroup` never called)

- [ ] **Step 3: Implement** — in `server/src/routes/group-members.ts` add the import:

```ts
import { findManageableGroup } from '../services/permission.js'
```

In `GET /:groupId/members`, directly after `const { includeInactive } = req.query`:

```ts
    // ui2-groups-browse D9: only a caller who manages the (active) group reads its members.
    const userId = (req.user as { id?: string } | undefined)?.id
    if (!userId || !(await findManageableGroup(userId, groupId))) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }
```

In `GET /:groupId/membership-history`, directly after `const { search, limit } = req.query`:

```ts
    // ui2-groups-browse D9: only a caller who manages the (active) group reads its history.
    const userId = (req.user as { id?: string } | undefined)?.id
    if (!userId || !(await findManageableGroup(userId, groupId))) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }
```

Also add `404: { description: Group not found or outside the caller's manage scope }` to both handlers' `@openapi` `responses`.

- [ ] **Step 4: Run the tests and watch them pass** — `cd server && npx vitest run src/routes/__tests__/group-members-scope.request.test.ts src/routes/__tests__/group-members.test.ts` → PASS (the older suite only asserts 401s for unauthenticated calls); `cd server && npx tsc --noEmit` → no errors.

- [ ] **Step 5: Commit** — `fix(ui2-groups-browse): scope GET group members and membership history to groupManageFilter`

### Task 7: fixtures — empty group, groups-home / groups-detail / create-group layers; contract freeze
App: server
Phase: 3
Recipe: `server/fixtures/README.md` (§Layers, §FixtureContext, §Fixed IDs, §A new screen layer) · SPEC D19, D25, D26, T9

**Files:**
- Modify: `server/fixtures/ids.ts` (new kinds + `FIXTURE_EMPTY_GROUP_ID`)
- Modify: `server/fixtures/base.ts` (5th group "Empty Group", outside `created.groups`)
- Create: `server/fixtures/screens/groups-detail.ts`, `server/fixtures/screens/groups-home.ts`, `server/fixtures/screens/create-group.ts`
- Modify: `server/fixtures/README.md` (kinds list + a "What `full` makes non-empty on Groups" section)
- Modify (counts the new rows change): `server/fixtures/__tests__/base.db.test.ts:69`, `server/fixtures/__tests__/home-dashboard.db.test.ts:32,96`, `server/fixtures/__tests__/members.db.test.ts:114`
- Test: `server/fixtures/__tests__/groups-browse.test.ts` (no DB), `server/fixtures/__tests__/groups-browse.db.test.ts` (DB, gated on `FIXTURES_TEST_DATABASE_URL`)
- Then: `docs/features/ui2-groups-browse/MANIFEST.md` via `advance.mjs` (contract freeze)

**Interfaces:**
- Consumes: Task 3 `getGroupHistory(groupId, limit)` (`server/src/services/group-history.ts`); Task 4 `activityThumbnailUrl(activity)` (`server/src/services/next-study-thumbnail.ts`); Task 5 `getHomeDays(scope, from, to, tz, { groupId })` (`server/src/services/home-dashboard.ts`); base exports `scheduleId(enrollmentIndex, day)`, `ENROLLMENT_PLAN`, `ALL_DAYS`, `lessonOffsets` (`server/fixtures/base.ts`).
- Produces (what the iPhone walk reads after `fixtures:reset`):
  - `FIXTURE_EMPTY_GROUP_ID = fixtureId('group', 5)`, `EMPTY_GROUP_NAME = 'Empty Group'` — no members, enrollments, schedules, requests or history: every group-page empty line (D4).
  - Rich group = base group 1 `FIXTURE_GROUP_IDS[0]` "Tuesday Men's Group" (`RICH_GROUP_ID`): 2 pending join requests (Ruth Hamilton, Esther Graham — members 20, 21, from Women's Bible Study); next lesson = enrollment 4 day 14 (today) — and day 15 (tomorrow), in case the server's midnight has rolled past today's noon-Chicago schedule — each with 3 `ScheduledLessonActivity` rows: YOUTUBE (`youtubeThumbnailUrl`), VIDEO (a `Video` with `thumbnailUrl`), READ (a read block `backgroundImageUrl`); history covering all 7 kinds (newest first: requested ×2 at −1/−2 days, cover at −3, event at −5, left at −6, settings at −10, joined at −20, base joins at −62…−59, created at −75), plus a future SOCIAL event and a past LESSON event that history must NOT show; the rail's 30 days come from base + home-dashboard (enrollment 1 runs −48…−19, enrollment 4 −13…+7, so −18…−14 read "0 lessons" — the D12 `nothing` card).
  - `GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS: string[]` (4 ids) — the only membership events this layer adds.
  - New `FIXTURE_KIND` codes: `joinRequest '0015'`, `feedActivity '0016'`, `event '0017'`, `scheduledActivity '0018'`, `video '0019'`, `readBlock '001a'`.

Rules (README §Layers): a screen layer creates no org, user or group; every row takes a fixed id; every date comes from `ctx`; nothing runs at import time. 🔴 `groups-detail.ts` sorts BEFORE `home-dashboard.ts`, so it must never call `ctx.rand` — one draw would shift every home-dashboard number. Everything it creates is deleted by reset's existing cascades (join requests + membership events via the fixture members; events and schedules via the fixture groups; Activity and Video rows via the fixture user) — no `wipe.ts` line. Joins by invite write no `MembershipEvent` (D26), so joins are seeded as `MembershipEvent` rows directly.

DB tests need a throwaway database on the local postgres (`localhost:5434`), never `makeready_dev` (`fixtures/__tests__/db-harness.ts` refuses it). No `server/.env` is read anywhere below.

- [ ] **Step 1: Write the failing no-DB test** — `server/fixtures/__tests__/groups-browse.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { ALL_DAYS, ENROLLMENT_PLAN, EMPTY_GROUP_NAME, MEMBERS_PER_GROUP, lessonOffsets, scheduleId } from '../base.js'
import { localDate } from '../context.js'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_GROUP_IDS, FIXTURE_KIND, FIXTURE_LEADER_GROUP_ID, fixtureId } from '../ids.js'
import {
  GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS,
  LEFT_MEMBER_INDEX,
  NEXT_LESSON_SCHEDULE_IDS,
  REQUESTER_INDICES,
  RICH_GROUP_ID,
} from '../screens/groups-detail.js'

describe('groups-browse fixture ids (D19, D25)', () => {
  it('adds the Empty Group as group 5, apart from the base and leader groups', () => {
    expect(FIXTURE_EMPTY_GROUP_ID).toBe(fixtureId('group', 5))
    expect([...FIXTURE_GROUP_IDS, FIXTURE_LEADER_GROUP_ID]).not.toContain(FIXTURE_EMPTY_GROUP_ID)
    expect(EMPTY_GROUP_NAME).toBe('Empty Group')
  })

  it('gives every kind a distinct code', () => {
    const codes = Object.values(FIXTURE_KIND)
    expect(new Set(codes).size).toBe(codes.length)
    expect(FIXTURE_KIND).toMatchObject({
      joinRequest: '0015',
      feedActivity: '0016',
      event: '0017',
      scheduledActivity: '0018',
      video: '0019',
      readBlock: '001a',
    })
  })

  it('puts the next lesson on enrollment 4 (group 1) today and tomorrow', () => {
    const e4 = ENROLLMENT_PLAN[3]
    expect(e4.index).toBe(4)
    expect(FIXTURE_GROUP_IDS[e4.groupIndex]).toBe(RICH_GROUP_ID)
    const offsets = lessonOffsets(localDate(new Date()), e4.startOffset, 21, ALL_DAYS)
    expect([offsets[13], offsets[14]]).toEqual([0, 1])
    expect(NEXT_LESSON_SCHEDULE_IDS).toEqual([scheduleId(4, 14), scheduleId(4, 15)])
  })

  it('takes requesters and the leaver from outside group 1', () => {
    for (const i of [...REQUESTER_INDICES, LEFT_MEMBER_INDEX]) expect(i).toBeGreaterThanOrEqual(MEMBERS_PER_GROUP)
    expect(GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS).toHaveLength(4)
  })
})
```

- [ ] **Step 2: Write the failing DB test** — `server/fixtures/__tests__/groups-browse.db.test.ts`

```ts
/**
 * groups-home / groups-detail layers against a throwaway database (ui2-groups-browse D19, D25):
 * the rich group fills every group-page section, the Empty Group none. Gated on
 * FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { activityThumbnailUrl } from '../../src/services/next-study-thumbnail.js'
import { addDays, localDate } from '../context.js'
import { FIXTURE_EMPTY_GROUP_ID, FIXTURE_ORG_ID } from '../ids.js'
import { NEXT_LESSON_SCHEDULE_IDS, RICH_GROUP_ID } from '../screens/groups-detail.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }

describe.skipIf(!TEST_DB_URL)('groups-browse layers against the test database (D19, D25)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('lists five fixture groups, two leaders (groups-home)', async () => {
    const groups = await db.prisma.group.findMany({ where: { organizationId: FIXTURE_ORG_ID, isActive: true } })
    expect(groups.map((g) => g.name).sort()).toEqual(
      ['Empty Group', 'Prayer Team', "Tuesday Men's Group", "Women's Bible Study", 'Young Adults'].sort()
    )
    expect(new Set(groups.map((g) => g.creatorId)).size).toBe(2)
    expect(groups.every((g) => g.memberDirectoryAccess === 'ALLOWED')).toBe(true)
  })

  it('leaves the Empty Group with nothing in any section', async () => {
    const { getGroupHistory } = await import('../../src/services/group-history.js')
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await db.prisma.enrollment.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await db.prisma.groupJoinRequest.count({ where: { groupId: FIXTURE_EMPTY_GROUP_ID } })).toBe(0)
    expect(await getGroupHistory(FIXTURE_EMPTY_GROUP_ID, 50)).toEqual([])
  })

  it('gives the rich group two pending join requests', async () => {
    const requests = await db.prisma.groupJoinRequest.findMany({
      where: { groupId: RICH_GROUP_ID, status: 'pending' },
      include: { member: { select: { firstName: true, lastName: true } } },
      orderBy: { createdAt: 'desc' },
    })
    expect(requests.map((r) => `${r.member.firstName} ${r.member.lastName}`)).toEqual(['Esther Graham', 'Ruth Hamilton'])
  })

  it('gives the next lessons three activities, each with a thumbnail', async () => {
    for (const id of NEXT_LESSON_SCHEDULE_IDS) {
      const activities = await db.prisma.scheduledLessonActivity.findMany({
        where: { lessonScheduleId: id },
        orderBy: { orderNumber: 'asc' },
        select: {
          type: true,
          youtubeThumbnailUrl: true,
          video: { select: { thumbnailUrl: true } },
          readBlocks: { where: { backgroundImageUrl: { not: null } }, orderBy: { orderNumber: 'asc' }, take: 1, select: { backgroundImageUrl: true } },
        },
      })
      expect(activities.map((a) => a.type)).toEqual(['YOUTUBE', 'VIDEO', 'READ'])
      for (const a of activities) expect(activityThumbnailUrl(a)).toMatch(/^https:\/\//)
    }
  })

  it('serves history across all seven kinds, newest first, without future or LESSON events', async () => {
    const { getGroupHistory } = await import('../../src/services/group-history.js')
    const all = await getGroupHistory(RICH_GROUP_ID, 50)
    expect(new Set(all.map((e) => e.kind))).toEqual(
      new Set(['member_joined', 'member_left', 'join_requested', 'settings_updated', 'cover_updated', 'group_created', 'event_held'])
    )
    expect(all.filter((e) => e.kind === 'event_held').map((e) => e.text)).toEqual(['Held event at Corner Bakery'])
    const latest = await getGroupHistory(RICH_GROUP_ID, 5)
    expect(latest.map((e) => e.kind)).toEqual(['join_requested', 'join_requested', 'cover_updated', 'event_held', 'member_left'])
    expect(latest[0].text).toBe('Esther Graham requested to join')
    expect(all[all.length - 1].kind).toBe('group_created')
  })

  it('fills the rail: scheduled lessons, partial completions and sessions over the last 30 days', async () => {
    const { getHomeDays } = await import('../../src/services/home-dashboard.js')
    const { runAnalyticsQuery } = await import('../../src/services/analytics.service.js')
    const today = localDate(new Date())
    const from = addDays(today, -29)
    const { days } = await getHomeDays(scope, from, today, TZ, { groupId: RICH_GROUP_ID })
    expect(days).toHaveLength(30)
    expect(days.filter((d) => d.sessionSeconds > 0).length).toBeGreaterThanOrEqual(15)
    const filters = { organizationId: FIXTURE_ORG_ID, groupId: RICH_GROUP_ID, from, to: today }
    const scheduled = await runAnalyticsQuery({ metrics: ['scheduled_lessons'], dimensions: ['day'], filters, timezone: TZ }, scope)
    const completed = await runAnalyticsQuery({ metrics: ['lesson_completions'], dimensions: ['day'], filters, timezone: TZ }, scope)
    const sum = (rows: Record<string, unknown>[], key: string) => rows.reduce((s, r) => s + Number(r[key] ?? 0), 0)
    expect(scheduled.rows.filter((r) => Number(r.scheduled_lessons) > 0).length).toBeGreaterThanOrEqual(20)
    expect(completed.rows.filter((r) => Number(r.lesson_completions) > 0).length).toBeGreaterThanOrEqual(10)
    expect(sum(completed.rows, 'lesson_completions')).toBeLessThan(sum(scheduled.rows, 'scheduled_lessons'))
  })
})
```

- [ ] **Step 3: Run them and watch them fail**

```bash
docker exec makeready-postgres dropdb -U postgres --if-exists --force makeready_fixtures_test
docker exec makeready-postgres createdb -U postgres makeready_fixtures_test
cd server/atlas && ../scripts/atlas.sh migrate apply --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_fixtures_test
cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_fixtures_test npx tsx scripts/schema/run-seeds.ts
cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_fixtures_test npx vitest run fixtures/__tests__/groups-browse.test.ts fixtures/__tests__/groups-browse.db.test.ts
```

→ FAIL (cannot resolve `../screens/groups-detail.js`; `EMPTY_GROUP_NAME` / `FIXTURE_EMPTY_GROUP_ID` not exported). (`run-seeds.ts` creates the system Owner / Group Leader roles base needs; it reads `DATABASE_URL` from the environment, not dotenv.)

- [ ] **Step 4: Add the ids** — in `server/fixtures/ids.ts`, extend `FIXTURE_KIND` after `invite: '0014',`:

```ts
  // ui2-groups-browse D25 / T9: the group page's rows.
  joinRequest: '0015',
  feedActivity: '0016',
  event: '0017',
  scheduledActivity: '0018',
  video: '0019',
  readBlock: '001a',
```

and after `FIXTURE_LEADER_GROUP_ID`:

```ts
/** ui2-groups-browse D25: a group with no members, enrollments, schedules or history (the empty states). */
export const FIXTURE_EMPTY_GROUP_ID = fixtureId('group', 5)
```

and add `emptyGroup: FIXTURE_EMPTY_GROUP_ID,` to `FIXTURE_IDS`.

- [ ] **Step 5: Add the Empty Group to base** — in `server/fixtures/base.ts` add `FIXTURE_EMPTY_GROUP_ID` to the `./ids.js` import, export the name beside `LEADER_GROUP_NAME`:

```ts
/** ui2-groups-browse D25: the group page's empty states. */
export const EMPTY_GROUP_NAME = 'Empty Group'
```

and directly after the Prayer Team `prisma.group.create(...)`:

```ts
  // ui2-groups-browse D25: no members, enrollments, schedules or history, so the group page shows
  // every designed empty line. Kept out of created.groups (like Prayer Team): no other layer sees it.
  await prisma.group.create({
    data: {
      id: FIXTURE_EMPTY_GROUP_ID,
      name: EMPTY_GROUP_NAME,
      creatorId: FIXTURE_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    },
  })
```

- [ ] **Step 6: Write the groups-detail layer** — `server/fixtures/screens/groups-detail.ts`

```ts
/**
 * groups-detail layer (ui2-groups-browse D19, T9): what the group page reads beyond base, on the rich
 * group — base group 1, Tuesday Men's Group.
 *  - Lessons up next: enrollment 4's day 14 (today) and day 15 (tomorrow) each get three
 *    ScheduledLessonActivity rows — YOUTUBE (youtubeThumbnailUrl), VIDEO (a Video with a thumbnail)
 *    and READ (a read block image) — so next-study has three thumbnails whichever of the two the
 *    server's midnight picks.
 *  - Requests: members 20 and 21 (Women's Bible Study) have pending join requests + REQUESTED events.
 *  - Timeline: member 12 joined (APPROVED, −20) and left (REMOVED_GROUP, −6); the group was created
 *    (−75), its settings (−10) and cover (−3) updated (Activity rows, resourceType GROUP); a breakfast
 *    was held (−5). A future social and a past LESSON event exist and must not show (D15). Base's
 *    joins come from home-dashboard's ADDED events; joins by invite write none (D26).
 *  - Activity rail + chart: base + home-dashboard already schedule, complete and sessionize group 1.
 * Never touches ctx.rand: this file runs before home-dashboard.ts, and one draw would shift its numbers.
 * Creates no org, user or group.
 */
import { scheduleId } from '../base.js'
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const RICH_GROUP_ID = FIXTURE_GROUP_IDS[0]
/** Enrollment 4 (group 1) runs daily from today−13: day 14 is today, day 15 tomorrow. */
export const NEXT_LESSON_SCHEDULE_IDS: readonly string[] = [scheduleId(4, 14), scheduleId(4, 15)]
/** Ruth Hamilton (20) and Esther Graham (21), newest request last in this list. */
export const REQUESTER_INDICES: readonly number[] = [20, 21]
/** Sophia Powell (12) joined group 1 and left it. */
export const LEFT_MEMBER_INDEX = 12
export const GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS: string[] = [101, 102, 103, 104].map((n) => fixtureId('membershipEvent', n))

export const YOUTUBE_THUMBNAIL_URL = 'https://picsum.photos/seed/makeready-fixture-youtube/640/360'
export const VIDEO_THUMBNAIL_URL = 'https://picsum.photos/seed/makeready-fixture-video/640/360'
export const READ_IMAGE_URL = 'https://picsum.photos/seed/makeready-fixture-read/640/360'
const VIDEO_ID = fixtureId('video', 1)
const VIDEO_PLAYBACK_URL = 'https://videodelivery.net/fixture-video-1/manifest/video.m3u8'

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const groupName = ctx.created.groups[0]?.name ?? "Tuesday Men's Group"
  const member = (i: number) => FIXTURE_MEMBER_IDS[i]
  const [ruth, esther] = REQUESTER_INDICES
  const requestedAt = [ctx.at(-2, 15), ctx.at(-1, 9)]

  // Requests section (D18) + their history rows.
  await prisma.groupJoinRequest.createMany({
    data: REQUESTER_INDICES.map((i, n) => ({
      id: fixtureId('joinRequest', n + 1),
      groupId: RICH_GROUP_ID,
      memberId: member(i),
      status: 'pending',
      message: 'I’d love to join this group.',
      createdAt: requestedAt[n],
    })),
  })
  const membership = (n: number, memberIndex: number, action: 'APPROVED' | 'REMOVED_GROUP' | 'REQUESTED', createdAt: Date) => ({
    id: fixtureId('membershipEvent', n),
    memberId: member(memberIndex),
    groupId: RICH_GROUP_ID,
    organizationId: FIXTURE_ORG_ID,
    action,
    actorId: action === 'REQUESTED' ? member(memberIndex) : FIXTURE_USER_ID,
    actorType: action === 'REQUESTED' ? 'member' : 'user',
    createdAt,
  })
  await prisma.membershipEvent.createMany({
    data: [
      membership(101, LEFT_MEMBER_INDEX, 'APPROVED', ctx.at(-20, 10)),
      membership(102, LEFT_MEMBER_INDEX, 'REMOVED_GROUP', ctx.at(-6, 18)),
      membership(103, ruth, 'REQUESTED', requestedAt[0]),
      membership(104, esther, 'REQUESTED', requestedAt[1]),
    ],
  })

  // Timeline: the Activity ledger's GROUP rows (D15 — resourceType + resourceId, F6).
  const groupActivity = (n: number, action: 'CREATED' | 'UPDATED', createdAt: Date, metadata?: { field: string }) => ({
    id: fixtureId('feedActivity', n),
    actorId: FIXTURE_USER_ID,
    action,
    resourceType: 'GROUP',
    resourceId: RICH_GROUP_ID,
    resourceName: groupName,
    organizationId: FIXTURE_ORG_ID,
    groupId: RICH_GROUP_ID,
    ...(metadata ? { metadata } : {}),
    createdAt,
  })
  await prisma.activity.createMany({
    data: [
      groupActivity(1, 'CREATED', ctx.daysAgo(75)),
      groupActivity(2, 'UPDATED', ctx.at(-10, 14)),
      groupActivity(3, 'UPDATED', ctx.at(-3, 11), { field: 'cover' }),
    ],
  })

  // Timeline: one past meeting is shown; a future social and a past LESSON event are not (D15).
  await prisma.event.createMany({
    data: [
      { id: fixtureId('event', 1), groupId: RICH_GROUP_ID, type: 'MEETING', title: 'Monthly Breakfast', locationName: 'Corner Bakery', date: ctx.at(-5, 8), createdById: FIXTURE_USER_ID },
      { id: fixtureId('event', 2), groupId: RICH_GROUP_ID, type: 'SOCIAL', title: 'Summer Cookout', date: ctx.at(12, 17), createdById: FIXTURE_USER_ID },
      { id: fixtureId('event', 3), groupId: RICH_GROUP_ID, type: 'LESSON', title: 'Day 10', date: ctx.at(-4, 12), createdById: FIXTURE_USER_ID },
    ],
  })

  // Lessons up next (D17): a YouTube, an uploaded video and a READ block image on today's and tomorrow's lesson.
  await prisma.video.create({
    data: {
      id: VIDEO_ID,
      title: 'A welcome from your leader',
      cloudflareUid: 'fixture-video-1',
      playbackUrl: VIDEO_PLAYBACK_URL,
      thumbnailUrl: VIDEO_THUMBNAIL_URL,
      duration: 180,
      status: 'ready',
      userId: FIXTURE_USER_ID,
      createdAt: ctx.daysAgo(30),
    },
  })
  for (const [k, lessonScheduleId] of NEXT_LESSON_SCHEDULE_IDS.entries()) {
    const id = (order: number) => fixtureId('scheduledActivity', (k + 1) * 10 + order)
    await prisma.scheduledLessonActivity.createMany({
      data: [
        {
          id: id(1),
          lessonScheduleId,
          type: 'YOUTUBE',
          orderNumber: 1,
          title: 'Watch: Overview of John',
          youtubeUrl: 'https://www.youtube.com/watch?v=G-2e9mMf7E8',
          youtubeVideoId: 'G-2e9mMf7E8',
          youtubeThumbnailUrl: YOUTUBE_THUMBNAIL_URL,
        },
        { id: id(2), lessonScheduleId, type: 'VIDEO', orderNumber: 2, title: 'A welcome from your leader', videoId: VIDEO_ID, videoUrl: VIDEO_PLAYBACK_URL },
        { id: id(3), lessonScheduleId, type: 'READ', orderNumber: 3, title: 'Read John 3', referenceTitle: 'John 3', readContent: 'Read John 3 slowly, twice.' },
      ],
    })
    await prisma.activityReadBlock.create({
      data: {
        id: fixtureId('readBlock', k + 1),
        scheduledActivityId: id(3),
        orderNumber: 1,
        title: 'John 3',
        content: 'For God so loved the world…',
        backgroundImageUrl: READ_IMAGE_URL,
      },
    })
  }
}
```

- [ ] **Step 7: Write the two thin layers** — `server/fixtures/screens/groups-home.ts`

```ts
/**
 * groups-home layer (ui2-groups-browse D3, D19): the Groups list reads only base — five groups in
 * one org (Tuesday Men's Group, Young Adults, Women's Bible Study and Empty Group by Fixture Leader;
 * Prayer Team by Nathan Hughes), so the Leaders chip offers two names and the Orgs chip stays hidden
 * (one org, D3). Covers come from base's images. Nothing to add; the layer exists so the screen is
 * registered in `screens/` (README §A new screen layer).
 */
import type { FixtureContext } from '../context.js'

export async function full(_ctx: FixtureContext): Promise<void> {}
```

`server/fixtures/screens/create-group.ts`

```ts
/**
 * create-group layer (ui2-groups-browse D8, D19): the form starts empty and writes through
 * POST /api/groups — no fixture rows. The group a walk creates belongs to the fixture org, so the
 * next reset deletes it (wipe.ts step 3).
 */
import type { FixtureContext } from '../context.js'

export async function full(_ctx: FixtureContext): Promise<void> {}
```

- [ ] **Step 8: Update the counts the new rows change**

`server/fixtures/__tests__/base.db.test.ts` (reset `empty`): `      groups: 4,` → `      groups: 5,`

`server/fixtures/__tests__/home-dashboard.db.test.ts`: add `import { GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS } from '../screens/groups-detail.js'`; replace

```ts
    expect(first.membership_events).toBe(24)
```

with

```ts
    expect(first.membership_events).toBe(24 + GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS.length) // + groups-detail's history (ui2-groups-browse D19)
```

and

```ts
    const joins = await db.prisma.membershipEvent.findMany({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })
```

with

```ts
    const joins = await db.prisma.membershipEvent.findMany({
      where: { memberId: { in: FIXTURE_MEMBER_IDS }, id: { notIn: GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS } },
    })
```

`server/fixtures/__tests__/members.db.test.ts`: add the same import; replace

```ts
    expect(await db.prisma.membershipEvent.count({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })).toBe(24)
```

with

```ts
    expect(
      await db.prisma.membershipEvent.count({
        where: { memberId: { in: FIXTURE_MEMBER_IDS }, id: { notIn: GROUPS_DETAIL_MEMBERSHIP_EVENT_IDS } },
      })
    ).toBe(24)
```

- [ ] **Step 9: Document it** — in `server/fixtures/README.md`: append to the §Fixed IDs kinds sentence `` `0015` join requests, `0016` feed activities, `0017` events, `0018` scheduled activities, `0019` videos, `001a` read blocks``, note that `group` n 5 is the Empty Group, and add after §"What `full` makes non-empty on Members":

```markdown
### What `full` makes non-empty on Groups

`base.ts` + `screens/groups-home.ts` + `screens/groups-detail.ts` (ui2-groups-browse D19, D25): the
list shows five groups (Empty Group is base group 5 — no members, enrollments or history, for every
empty line). Tuesday Men's Group is the rich group: two pending join requests (Ruth Hamilton, Esther
Graham), today's and tomorrow's lesson each with a YouTube, a video and a READ thumbnail, and a
Timeline with every kind — requests (−1, −2 days), cover (−3), breakfast at Corner Bakery (−5), Sophia
Powell left (−6), settings (−10), joined (−20), base joins (−62…−59), created (−75). Its day rail is
base + home-dashboard: enrollment 1 (−48…−19) and 4 (−13…+7) leave −18…−14 at 0 lessons.
```

- [ ] **Step 10: Run the tests and watch them pass**

```bash
cd server && npx tsc --noEmit -p fixtures
cd server && npx tsc --noEmit
cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/makeready_fixtures_test npx vitest run fixtures/__tests__/
cd server && npx vitest run
docker exec makeready-postgres dropdb -U postgres --force makeready_fixtures_test
```

→ both typechecks clean; every fixtures suite PASSES against the throwaway DB (quote the `Test Files … passed` line); the full `vitest run` passes (its fixtures DB suites print the skip line — no `FIXTURES_TEST_DATABASE_URL`). If a DB-backed suite outside `fixtures/` fails for lack of a database, name it and show it fails the same on `main` (pre-existing), not because of this feature.

- [ ] **Step 11: Commit** — `feat(ui2-groups-browse): fixture Empty Group + groups-home, groups-detail and create-group layers`

- [ ] **Step 12: Record the contract freeze** (server phase verified; SPEC §Contract is now frozen — any change goes through `/builder:revise`). From the repo root:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.2.0/scripts/advance.mjs docs/features/ui2-groups-browse --set "contract=frozen $(date +%F)" --head --commit "chore(ui2-groups-browse): contract frozen"
```

→ `MANIFEST.md` reads `contract: frozen <today>` and the commit `chore(ui2-groups-browse): contract frozen` is HEAD.

### Task 8: decode models — UserGroup fields, NextStudy, GroupHistoryEvent
App: iphone
Phase: 4
Recipe: iphone/.claude/CLAUDE.md (§State Management — models; the iPhone app is a released artifact, so every new key decodes optional)

**Files:**
- Modify: `iphone/MakeReady/State/Models/GroupModels.swift:17-84` (`UserGroup`)
- Create: `iphone/MakeReady/State/Models/GroupPageModels.swift`
- Test: `iphone/MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (through the Ruby step below — never by hand)

**Interfaces:**
- Consumes: the frozen §Contract shapes from server Tasks 1–7: `GET /api/groups` per-group `organizationId`, `organizationName`, `memberDirectoryAccess`; `GET /api/groups/:id/next-study` → `{success, study:{id, code, dayNumber, scheduledDate, title?, studyProgram{id,name,description?,coverImageUrl?}?, activities:[{id,type,orderNumber,title,thumbnailUrl?}]}}` (204 = no body); `GET /api/groups/:id/history` → `{success, events:[{id, occurredAt, kind, text, highlight|null}]}`.
- Produces:
  - `UserGroup.organizationId: String?`, `UserGroup.organizationName: String?`, `UserGroup.memberDirectoryAccess: String?` ("ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED", kept a String); `UserGroup.init(…, creatorName: String? = nil, organizationId: String? = nil, organizationName: String? = nil, memberDirectoryAccess: String? = nil, createdAt: Date, updatedAt: Date)`.
  - `struct NextStudyResponse: Codable, Equatable { var success: Bool; var study: NextStudy? }`
  - `struct NextStudy: Codable, Equatable { var id: String; var code: String?; var dayNumber: Int; var scheduledDate: String; var title: String?; var studyProgram: NextStudyProgram?; var activities: [NextStudyActivity] }` (memberwise init, every field defaulted)
  - `struct NextStudyProgram: Codable, Equatable { var id: String; var name: String; var description: String?; var coverImageUrl: String? }`
  - `struct NextStudyActivity: Codable, Equatable { var id: String; var type: String; var orderNumber: Int; var title: String?; var thumbnailUrl: String? }`
  - `struct GroupHistoryResponse: Codable, Equatable { var success: Bool; var events: [GroupHistoryEvent] }`
  - `struct GroupHistoryEvent: Codable, Equatable, Identifiable { var id: String; var occurredAt: String; var kind: String; var text: String; var highlight: String? }`

**How a new file joins the Xcode project here.** The project has NO file-system-synchronized groups (objectVersion 56, `iphone/scripts/makereadyui-sync.rb` header) — a file on disk is invisible to the compiler until the pbxproj references it. Register every new file with the `xcodeproj` gem (the same gem `iphone/scripts/*.rb` use), then run `ruby iphone/scripts/capture-targets.rb` so the MakeReadyCapture target picks up the app target's new sources. Run from the repo root.

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse T10–T12: the extended and new group payloads decode; every new key is
/// optional, so an old disk cache and an old server both still load (F7).
final class GroupsBrowseDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(T.self, from: Data(json.utf8))
    }

    private let baseGroup = #""id":"g1","code":"ABC123","name":"Prayer Team","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-26T12:00:00.000Z","updatedAt":"2026-10-26T12:00:00.000Z""#

    // MARK: - T10 UserGroup

    func testUserGroupDecodesTheThreeNewFields() throws {
        let group: UserGroup = try decode(
            "{\(baseGroup),\"organizationId\":\"o1\",\"organizationName\":\"Grace Church\",\"memberDirectoryAccess\":\"NAMES_ONLY\"}"
        )
        XCTAssertEqual(group.organizationId, "o1")
        XCTAssertEqual(group.organizationName, "Grace Church")
        XCTAssertEqual(group.memberDirectoryAccess, "NAMES_ONLY")
    }

    /// F7: each new key absent on its own — the other two still decode, the absent one is nil.
    func testUserGroupDecodesWithEachNewKeyAbsent() throws {
        let keys: [(String, String)] = [
            ("organizationId", "\"o1\""),
            ("organizationName", "\"Grace Church\""),
            ("memberDirectoryAccess", "\"ALLOWED\"")
        ]
        for absent in keys.indices {
            let present = keys.indices.filter { $0 != absent }.map { "\"\(keys[$0].0)\":\(keys[$0].1)" }
            let group: UserGroup = try decode("{\(baseGroup),\(present.joined(separator: ","))}")
            XCTAssertEqual(group.organizationId == nil, absent == 0, "absent: \(keys[absent].0)")
            XCTAssertEqual(group.organizationName == nil, absent == 1, "absent: \(keys[absent].0)")
            XCTAssertEqual(group.memberDirectoryAccess == nil, absent == 2, "absent: \(keys[absent].0)")
        }
    }

    /// F7: a released build's disk cache carries none of the keys and round-trips unchanged.
    func testOldCacheWithoutAnyNewKeyRoundTrips() throws {
        let group: UserGroup = try decode("{\(baseGroup)}")
        XCTAssertNil(group.organizationId)
        XCTAssertNil(group.organizationName)
        XCTAssertNil(group.memberDirectoryAccess)
        let roundTrip = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertEqual(roundTrip.name, "Prayer Team")
        XCTAssertNil(roundTrip.memberDirectoryAccess)
    }

    /// A value this build does not know (a later enum widening) never fails the decode.
    func testUnknownDirectoryAccessValueStillDecodes() throws {
        let group: UserGroup = try decode("{\(baseGroup),\"memberDirectoryAccess\":\"SOMETHING_NEW\"}")
        XCTAssertEqual(group.memberDirectoryAccess, "SOMETHING_NEW")
    }

    // MARK: - T11 NextStudy

    func testNextStudyDecodesTheExtendedPayload() throws {
        let response: NextStudyResponse = try decode(#"""
        {"success":true,"study":{"id":"s1","code":"ABC-3","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z",
         "title":"Faith over fear","enrollment":{"id":"e1"},
         "studyProgram":{"id":"p1","name":"Daily Inspiration","description":"30 days","days":30,"coverImageUrl":"https://img/p1.jpg","requireResponse":false},
         "activities":[{"id":"a1","type":"VIDEO","orderNumber":1,"title":"Watch","videoUrl":null,"sourceReferences":[],"thumbnailUrl":"https://img/a1.jpg"},
                       {"id":"a2","type":"READ","orderNumber":2,"title":"Read","thumbnailUrl":null}]}}
        """#)
        let study = try XCTUnwrap(response.study)
        XCTAssertTrue(response.success)
        XCTAssertEqual(study.code, "ABC-3")
        XCTAssertEqual(study.dayNumber, 3)
        XCTAssertEqual(study.scheduledDate, "2026-10-26T00:00:00.000Z")
        XCTAssertEqual(study.title, "Faith over fear")
        XCTAssertEqual(study.studyProgram, NextStudyProgram(id: "p1", name: "Daily Inspiration", description: "30 days", coverImageUrl: "https://img/p1.jpg"))
        XCTAssertEqual(study.activities.map(\.id), ["a1", "a2"])
        XCTAssertEqual(study.activities.map(\.thumbnailUrl), ["https://img/a1.jpg", nil])
    }

    /// An old server (no `title`, no `thumbnailUrl`) and a null program still decode.
    func testNextStudyToleratesAbsentOptionalKeys() throws {
        let response: NextStudyResponse = try decode(#"""
        {"success":true,"study":{"id":"s1","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z","studyProgram":null,
         "activities":[{"id":"a1","type":"READ","orderNumber":1}]}}
        """#)
        let study = try XCTUnwrap(response.study)
        XCTAssertNil(study.title)
        XCTAssertNil(study.code)
        XCTAssertNil(study.studyProgram)
        XCTAssertEqual(study.activities, [NextStudyActivity(id: "a1", type: "READ", orderNumber: 1)])
    }

    // MARK: - T12 GroupHistoryEvent

    func testHistoryDecodesEventsWithAndWithoutHighlight() throws {
        let response: GroupHistoryResponse = try decode(#"""
        {"success":true,"events":[
          {"id":"h1","occurredAt":"2026-10-25T17:30:00.000Z","kind":"member_joined","text":"Tony Stark joined the group","highlight":"Tony Stark"},
          {"id":"h2","occurredAt":"2026-10-20T09:00:00.000Z","kind":"settings_updated","text":"Updated group settings","highlight":null}]}
        """#)
        XCTAssertEqual(response.events, [
            GroupHistoryEvent(id: "h1", occurredAt: "2026-10-25T17:30:00.000Z", kind: "member_joined",
                              text: "Tony Stark joined the group", highlight: "Tony Stark"),
            GroupHistoryEvent(id: "h2", occurredAt: "2026-10-20T09:00:00.000Z", kind: "settings_updated",
                              text: "Updated group settings", highlight: nil)
        ])
    }

    func testHistoryWithoutEventsDecodesEmpty() throws {
        let response: GroupHistoryResponse = try decode(#"{"success":true}"#)
        XCTAssertEqual(response.events, [])
    }
}
```

Register the test file in the test target (from the repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupsBrowseDecodingTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` (repo root; the script runs the whole MakeReady scheme's tests and takes no test filter) → FAIL, compile errors: "value of type 'UserGroup' has no member 'organizationId'", "cannot find type 'NextStudyResponse' in scope", "cannot find type 'GroupHistoryResponse' in scope".

- [ ] **Step 3: Write the minimal implementation**

In `iphone/MakeReady/State/Models/GroupModels.swift`, `UserGroup` — add the three stored properties directly after `var creatorName: String?`:

```swift
    /// ui2-groups-browse D10: the group's org, from `GET /api/groups` — the Groups Orgs chip
    /// (D3). nil on an old cache or an old server (F7).
    var organizationId: String?
    var organizationName: String?
    /// ui2-groups-browse D11: "ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED". A String, not an enum,
    /// so a value this build does not know never fails the decode (F7). nil on an old cache.
    var memberDirectoryAccess: String?
```

In `init(from decoder:)`, directly after the `creatorName = …` line:

```swift
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        organizationName = try container.decodeIfPresent(String.self, forKey: .organizationName)
        memberDirectoryAccess = try container.decodeIfPresent(String.self, forKey: .memberDirectoryAccess)
```

Replace the memberwise `init(…)` signature line `creatorId: String, creatorName: String? = nil, createdAt: Date, updatedAt: Date` with:

```swift
        creatorId: String, creatorName: String? = nil, organizationId: String? = nil,
        organizationName: String? = nil, memberDirectoryAccess: String? = nil,
        createdAt: Date, updatedAt: Date
```

and add to its body, after `self.creatorName = creatorName`:

```swift
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.memberDirectoryAccess = memberDirectoryAccess
```

(`UserGroup` has no explicit `CodingKeys`; the synthesized keys pick the new properties up, and the synthesized `encode(to:)` writes them, so the disk cache keeps them.)

Create `iphone/MakeReady/State/Models/GroupPageModels.swift`:

```swift
//
//  GroupPageModels.swift
//  MakeReady
//
//  ui2-groups-browse: the group page's payloads that have no model yet — the next lesson
//  (T11, D17) and the merged group history (T12, D15). Every key decodes leniently: these are
//  read by a released app, so a missing key is a default, never a failed decode.
//

import Foundation

// MARK: - GET /api/groups/:id/next-study (T11, D17)

/// `{success, study}`. A 204 (no lesson ahead) has no body and never reaches this decode —
/// `GroupActions.loadNextStudy` reads the empty body as "no lesson".
struct NextStudyResponse: Codable, Equatable {
    var success: Bool = false
    var study: NextStudy?
}

extension NextStudyResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        study = try c.decodeIfPresent(NextStudy.self, forKey: .study)
    }
}

/// The group's next scheduled lesson (a `LessonSchedule`). `scheduledDate` stays the wire's ISO
/// string (the ui2-members F7 rule): the mapper reads its UTC calendar date (D17).
struct NextStudy: Codable, Equatable {
    var id: String = ""
    var code: String?
    var dayNumber: Int = 0
    var scheduledDate: String = ""
    /// SC5: `LessonSchedule.title`; nil → the card shows "Day «dayNumber»" (D17).
    var title: String?
    var studyProgram: NextStudyProgram?
    var activities: [NextStudyActivity] = []
}

extension NextStudy {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        code = try c.decodeIfPresent(String.self, forKey: .code)
        dayNumber = try c.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 0
        scheduledDate = try c.decodeIfPresent(String.self, forKey: .scheduledDate) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title)
        studyProgram = try c.decodeIfPresent(NextStudyProgram.self, forKey: .studyProgram)
        activities = try c.decodeIfPresent([NextStudyActivity].self, forKey: .activities) ?? []
    }
}

struct NextStudyProgram: Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var description: String?
    var coverImageUrl: String?
}

extension NextStudyProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
    }
}

/// One scheduled activity of the next lesson. SC5: `thumbnailUrl` = the YouTube / video
/// thumbnail, else a READ activity's first image, else nil.
struct NextStudyActivity: Codable, Equatable {
    var id: String = ""
    var type: String = ""
    var orderNumber: Int = 0
    var title: String?
    var thumbnailUrl: String?
}

extension NextStudyActivity {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        orderNumber = try c.decodeIfPresent(Int.self, forKey: .orderNumber) ?? 0
        title = try c.decodeIfPresent(String.self, forKey: .title)
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
    }
}

// MARK: - GET /api/groups/:id/history (T12, D15)

struct GroupHistoryResponse: Codable, Equatable {
    var success: Bool = false
    var events: [GroupHistoryEvent] = []
}

extension GroupHistoryResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        events = try c.decodeIfPresent([GroupHistoryEvent].self, forKey: .events) ?? []
    }
}

/// One Timeline row, newest first. `kind` stays a String (member_joined | member_left |
/// join_requested | settings_updated | cover_updated | group_created | event_held) so a kind a
/// released build does not know still decodes; the page renders `text` and `highlight` only.
struct GroupHistoryEvent: Codable, Equatable, Identifiable {
    var id: String = ""
    /// ISO 8601 — kept a String (F7); the mapper parses it for D16's label.
    var occurredAt: String = ""
    var kind: String = ""
    var text: String = ""
    var highlight: String?
}

extension GroupHistoryEvent {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        occurredAt = try c.decodeIfPresent(String.self, forKey: .occurredAt) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        highlight = try c.decodeIfPresent(String.self, forKey: .highlight)
    }
}
```

Register it in the app target, then sync the capture target (repo root):

```bash
ruby - "app:MakeReady/State/Models:GroupPageModels.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check   # → exit 0, nothing out of sync
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupsBrowseDecodingTests` 8/8 pass (and `ModelDecodingTests`' existing UserGroup cases still pass). Then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/State/Models/GroupModels.swift iphone/MakeReady/State/Models/GroupPageModels.swift iphone/MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): decode the group org, directory access, next study and history"`

### Task 9: AppState group stores + myOrganizations
App: iphone
Phase: 4
Recipe: iphone/.claude/CLAUDE.md (§"Where does this data live?" — every collection added to AppState is cleared in `clearInMemory()`) · tiny

**Files:**
- Modify: `iphone/MakeReady/State/AppState.swift:142-160` (stores, after `memberDaysById`) and `:813-874` (`clearInMemory()`)
- Modify: `iphone/MakeReady/State/Models/GroupPageModels.swift` (add `GroupChart`)
- Test: `iphone/MakeReadyCaptureTests/GroupStoresTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration, Ruby step)

**Interfaces:**
- Consumes: Task 8's `NextStudy`, `GroupHistoryEvent`; existing `HomeDay`, `OrganizationData`, `JoinRequest`.
- Produces (all on `AppState`, in memory only — never in `PersistedState`):
  - `var nextStudyByGroupId: [String: NextStudy]` — a 204 REMOVES the key
  - `var historyByGroupId: [String: [GroupHistoryEvent]]`
  - `var groupDaysByGroupId: [String: [HomeDay]]`
  - `var groupChartByGroupId: [String: GroupChart]`
  - `var myOrganizations: [OrganizationData]`
  - `struct GroupChart: Equatable { var scheduled: [String: Int] = [:]; var completed: [String: Int] = [:] }` — per local `yyyy-MM-dd` day, the two D21 series (in `GroupPageModels.swift`)
  - `clearInMemory()` empties all five plus `pendingJoinRequestsByGroupId` (not cleared today, `AppState.swift:239`).

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupStoresTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse T14: the group page's stores live in memory only and leave with the
/// session — sign-out and environment switch go through `clearInMemory()`.
@MainActor
final class GroupStoresTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func seed() {
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1", dayNumber: 3, title: "Faith over fear")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1", text: "Held event at Riverside Park")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25", sessionSeconds: 60)]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 3], completed: ["2026-10-25": 1])
        state.myOrganizations = [OrganizationData(id: "o1", name: "Grace Church"), OrganizationData(id: "o2", name: "Hope Chapel")]
        state.pendingJoinRequestsByGroupId["g1"] = [
            JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: Date(),
                        member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: "Stark", avatarUrl: nil))
        ]
    }

    func testClearAllDataEmptiesEveryGroupPageStore() {
        seed()
        state.clearAllData()
        XCTAssertTrue(state.nextStudyByGroupId.isEmpty)
        XCTAssertTrue(state.historyByGroupId.isEmpty)
        XCTAssertTrue(state.groupDaysByGroupId.isEmpty)
        XCTAssertTrue(state.groupChartByGroupId.isEmpty)
        XCTAssertTrue(state.myOrganizations.isEmpty)
        XCTAssertTrue(state.pendingJoinRequestsByGroupId.isEmpty)    // pre-existing leak (SPEC §iphone)
    }

    func testEnvironmentSwitchEmptiesThemToo() {
        seed()
        state.reloadForEnvironmentSwitch()
        XCTAssertTrue(state.nextStudyByGroupId.isEmpty)
        XCTAssertTrue(state.groupChartByGroupId.isEmpty)
        XCTAssertTrue(state.myOrganizations.isEmpty)
    }

    /// T14: the stores never reach the device's disk cache.
    func testGroupPageStoresNeverReachTheDiskCache() throws {
        seed()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(PersistedState(from: state)), as: UTF8.self)
        for marker in ["Faith over fear", "Riverside Park", "Hope Chapel"] {
            XCTAssertFalse(json.contains(marker), marker)
        }
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupStoresTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "value of type 'AppState' has no member 'nextStudyByGroupId'", "cannot find 'GroupChart' in scope".

- [ ] **Step 3: Write the minimal implementation**

Append to `iphone/MakeReady/State/Models/GroupPageModels.swift`:

```swift
// MARK: - The group page's activity series (T13, D21)

/// The two D21 analytics series of one group, per local `yyyy-MM-dd` day — `scheduled_lessons`
/// and `lesson_completions`, each from its own query. A day missing from a map is zero; the
/// mapper zero-fills the window (D13). A failed query leaves its map as it was (D21).
struct GroupChart: Equatable {
    var scheduled: [String: Int] = [:]
    var completed: [String: Int] = [:]
}
```

In `iphone/MakeReady/State/AppState.swift`, directly after `var memberDaysById: [String: [HomeDay]] = [:]` (≈ line 142), add:

```swift

    // MARK: ui2-groups-browse — group page stores (T14: in memory only)
    // `PersistedState` never encodes these; `clearInMemory()` empties them on sign-out and
    // environment switch.

    /// `GET /api/groups/:id/next-study`, by group id. A 204 (no lesson ahead) REMOVES the key.
    var nextStudyByGroupId: [String: NextStudy] = [:]

    /// `GET /api/groups/:id/history?limit=5` — the Timeline's latest events, by group id (D15).
    var historyByGroupId: [String: [GroupHistoryEvent]] = [:]

    /// `GET /api/home/days?groupId=` — the group page's rail series (D12), by group id.
    var groupDaysByGroupId: [String: [HomeDay]] = [:]

    /// D21's two single-metric analytics series, by group id (rail lines + chart).
    var groupChartByGroupId: [String: GroupChart] = [:]

    /// D3: `GET /api/organizations/my/organizations` for every role — the Groups Orgs chip.
    /// Separate from `userOrganizations`, which the shell's org scoping owns.
    var myOrganizations: [OrganizationData] = []
```

In `clearInMemory()`, directly after `memberDaysById = [:]`, add:

```swift
        nextStudyByGroupId = [:]
        historyByGroupId = [:]
        groupDaysByGroupId = [:]
        groupChartByGroupId = [:]
        myOrganizations = []
        // ui2-groups-browse T14: org-scoped and never cleared before — fixed here deliberately.
        pendingJoinRequestsByGroupId = [:]
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupStoresTests` 3/3. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/State/AppState.swift iphone/MakeReady/State/Models/GroupPageModels.swift iphone/MakeReadyCaptureTests/GroupStoresTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): in-memory group page stores, cleared with the session"`

### Task 10: GroupActions loaders — next study, history, days, chart, my organizations
App: iphone
Phase: 4
Recipe: /ios-error-surface (background loads: console-only; 401 → sign-out; a 404 is scope, not failure)

**Files:**
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift:12-29` (stored properties + init) and append a new section at the end of the struct
- Test: `iphone/MakeReadyCaptureTests/GroupActionsLoadersTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration, Ruby step)

**Interfaces:**
- Consumes: Task 8 models; Task 9 stores + `GroupChart`; existing `MemberActions.path(_:_:)`, `HomeDashboardMapper.days(endingAt:back:ahead:tz:)`, `AnalyticsQueryResponse`, `AnalyticsValue`, `MyOrganizationsResponse`, `HomeDaysResponse`, `APIHTTPError`, `AuthStatusPolicy.shouldSignOut(after:)`, `AppState.initialLoad.generation` / `isCurrent(_:)`, `APIClientProtocol.requestWithStatus(endpoint:method:body:)`.
- Produces (on `GroupActions`):
  - `init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current, onUnauthorized: @escaping @MainActor () async -> Void = {})` — every existing `GroupActions()` / `GroupActions(api:state:)` call still compiles
  - `static let railDays = 30`, `static let chartAheadDays = 3`, `static let historyLimit = 5`
  - `@MainActor func loadNextStudy(groupId: String) async`
  - `@MainActor func loadHistory(groupId: String, limit: Int = GroupActions.historyLimit) async`
  - `@MainActor func loadGroupDays(groupId: String) async`
  - `@MainActor func loadGroupChart(groupId: String) async`
  - `@MainActor func loadMyOrganizations() async`
  - `static func byDay(_ rows: [[String: AnalyticsValue]], metric: String) -> [String: Int]`
  - `static func isCancellation(_ error: Error) -> Bool`
  - Behaviour of every new loader: never throws; 401 → `onUnauthorized()` and nothing recorded; a 404 (`APIHTTPError.status == 404`) writes and records nothing (D23); any other failure → `recordError(…, context: "GroupActions.<loader>", surface: false)` and the store keeps what it held; a cancelled load or a stale generation (sign-out mid-flight) writes nothing.

**Wire notes the code relies on.** `APIClient.get` turns every non-2xx into `APIError.serverError(message)` and a 204's empty body into a decode failure, so these loaders use `requestWithStatus` (a non-2xx keeps its status as `APIHTTPError`; a 2xx returns raw `Data`, empty for a 204) and decode with `JSONDecoder.apiDecoder` themselves. The analytics body is Home's real shape — dates go in `filters.from` / `filters.to` (`server/src/routes/analytics.ts:106-118`, `DashboardActions.query`), not a `timeRange` key.

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupActionsLoadersTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse T11–T13, T18: the group page's loaders write the in-memory group stores;
/// a 401 signs out, a 404 is scope (D23), any other failure is recorded console-only and keeps
/// the store; a sign-out mid-load drops the result.
@MainActor
final class GroupActionsLoadersTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Sun Oct 25, 12:00 local

    private let nextStudyJSON = #"{"success":true,"study":{"id":"s1","dayNumber":3,"scheduledDate":"2026-10-26T00:00:00.000Z","title":"Faith over fear","studyProgram":{"id":"p1","name":"Daily Inspiration"},"activities":[{"id":"a1","type":"VIDEO","orderNumber":1,"title":"Watch","thumbnailUrl":"https://img/a1.jpg"}]}}"#
    private let historyJSON = #"{"success":true,"events":[{"id":"h1","occurredAt":"2026-10-25T17:30:00.000Z","kind":"member_joined","text":"Tony Stark joined the group","highlight":"Tony Stark"}]}"#
    private let analyticsJSON = #"{"rows":[{"day":"2026-10-25","scheduled_lessons":3,"lesson_completions":1},{"day":"2026-10-24","scheduled_lessons":2,"lesson_completions":2}]}"#

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

    private func actions(onUnauthorized: @escaping @MainActor () async -> Void = {}) -> GroupActions {
        GroupActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: onUnauthorized)
    }

    // MARK: - T11 next study

    func testNextStudyLandsByGroup() async {
        api.stub("GET", "/api/groups/g1/next-study", json: nextStudyJSON)
        await actions().loadNextStudy(groupId: "g1")
        XCTAssertEqual(state.nextStudyByGroupId["g1"]?.title, "Faith over fear")
        XCTAssertEqual(state.nextStudyByGroupId["g1"]?.activities.first?.thumbnailUrl, "https://img/a1.jpg")
    }

    /// T11: 204 → no lesson ahead — the key goes, nothing is recorded.
    func testNoContentRemovesTheNextStudy() async {
        state.nextStudyByGroupId["g1"] = NextStudy(id: "old")
        api.stub("GET", "/api/groups/g1/next-study", json: "")
        await actions().loadNextStudy(groupId: "g1")
        XCTAssertNil(state.nextStudyByGroupId["g1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    // MARK: - T12 history

    func testHistoryAsksForTheLatestFive() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/history?limit=5"), 1)
        XCTAssertEqual(state.historyByGroupId["g1"]?.map(\.highlight), ["Tony Stark"])
    }

    /// D23: a group outside the caller's scope is a 404 — nothing written, nothing recorded.
    func testNotFoundWritesAndRecordsNothing() async {
        let cached = [GroupHistoryEvent(id: "h0", text: "Created the group")]
        state.historyByGroupId["g1"] = cached
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(state.historyByGroupId["g1"], cached)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testOtherFailureKeepsTheStoreAndRecordsConsoleOnly() async {
        let cached = [GroupHistoryEvent(id: "h0", text: "Created the group")]
        state.historyByGroupId["g1"] = cached
        api.errorFor = { _, _ in APIHTTPError(status: 500, message: "boom") }
        await actions().loadHistory(groupId: "g1")
        XCTAssertEqual(state.historyByGroupId["g1"], cached)
        XCTAssertEqual(state.errors.last?.context, "GroupActions.loadHistory")
        XCTAssertEqual(state.errors.last?.surface, false)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testUnauthorizedSignsOutAndRecordsNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        await actions(onUnauthorized: { signedOut = true }).loadNextStudy(groupId: "g1")
        XCTAssertTrue(signedOut)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// A sign-out while the request is in flight retires the old session's result.
    func testSignOutMidLoadDropsTheResult() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        api.beforeReturn = { _, _ in self.state.clearAllData() }
        await actions().loadHistory(groupId: "g1")
        XCTAssertNil(state.historyByGroupId["g1"])
    }

    func testCancelledLoadWritesAndRecordsNothing() async {
        api.stub("GET", "/api/groups/g1/history?limit=5", json: historyJSON)
        api.delayFor = { _ in 0.5 }
        let groupActions = actions()
        let task = Task { @MainActor in await groupActions.loadHistory(groupId: "g1") }
        task.cancel()
        await task.value
        XCTAssertNil(state.historyByGroupId["g1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    // MARK: - T13 days + chart

    /// D12/D14: the 30 local days ending today, filtered to the group.
    func testDaysCoverTheThirtyDaysEndingTodayForTheGroup() async {
        let path = "/api/home/days?from=2026-09-26&to=2026-10-25&tz=America/Denver&groupId=g1"
        api.stub("GET", path, json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0]}]}"#)
        await actions().loadGroupDays(groupId: "g1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.groupDaysByGroupId["g1"]?.first?.sessionSeconds, 1530)
    }

    /// D21: two single-metric queries over today−29 … today+3, merged per day.
    func testChartRunsTwoSingleMetricQueriesAndMergesThem() async {
        api.stub("POST", "/api/analytics/query", json: analyticsJSON)
        await actions().loadGroupChart(groupId: "g1")
        let bodies = api.calls.filter { $0.endpoint == "/api/analytics/query" }.compactMap(\.body)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(Set(bodies.compactMap { ($0["metrics"] as? [String])?.joined() }), ["scheduled_lessons", "lesson_completions"])
        for body in bodies {
            XCTAssertEqual(body["dimensions"] as? [String], ["day"])
            XCTAssertEqual(body["timezone"] as? String, "America/Denver")
            let filters = body["filters"] as? [String: Any]
            XCTAssertEqual(filters?["groupId"] as? String, "g1")
            XCTAssertEqual(filters?["from"] as? String, "2026-09-26")
            XCTAssertEqual(filters?["to"] as? String, "2026-10-28")
        }
        XCTAssertEqual(state.groupChartByGroupId["g1"], GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2],
                                                                   completed: ["2026-10-25": 1, "2026-10-24": 2]))
    }

    /// D21: either query failing keeps the other series and records the error.
    func testChartKeepsTheSeriesThatLanded() async {
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: [:], completed: ["2026-10-01": 9])
        api.stub("POST", "/api/analytics/query", json: analyticsJSON)
        api.errorFor = { _, body in
            (body?["metrics"] as? [String]) == ["lesson_completions"] ? APIHTTPError(status: 500, message: "boom") : nil
        }
        await actions().loadGroupChart(groupId: "g1")
        XCTAssertEqual(state.groupChartByGroupId["g1"]?.scheduled, ["2026-10-25": 3, "2026-10-24": 2])
        XCTAssertEqual(state.groupChartByGroupId["g1"]?.completed, ["2026-10-01": 9])
        XCTAssertEqual(state.errors.last?.context, "GroupActions.loadGroupChart.completed")
    }

    func testByDayReadsOneMetricPerDay() {
        let rows: [[String: AnalyticsValue]] = [
            ["day": .string("2026-10-25"), "scheduled_lessons": .int(3)],
            ["day": .string("2026-10-24"), "scheduled_lessons": .double(2.0)],
            ["day": .null, "scheduled_lessons": .int(7)]
        ]
        XCTAssertEqual(GroupActions.byDay(rows, metric: "scheduled_lessons"), ["2026-10-25": 3, "2026-10-24": 2])
    }

    // MARK: - T18 my organizations

    func testMyOrganizationsLandForEveryRole() async {
        api.stub("GET", "/api/organizations/my/organizations",
                 json: #"{"success":true,"data":[{"id":"o1","name":"Grace Church"},{"id":"o2","name":"Hope Chapel"}]}"#)
        await actions().loadMyOrganizations()
        XCTAssertEqual(state.myOrganizations.map(\.name), ["Grace Church", "Hope Chapel"])
    }

    func testCancellationSeesThroughTheNetworkWrapper() {
        XCTAssertTrue(GroupActions.isCancellation(CancellationError()))
        XCTAssertTrue(GroupActions.isCancellation(APIError.networkError(URLError(.cancelled))))
        XCTAssertFalse(GroupActions.isCancellation(APIError.networkError(URLError(.timedOut))))
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupActionsLoadersTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "extra arguments at positions #3, #4, #5 in call" (the new init), "value of type 'GroupActions' has no member 'loadNextStudy'".

- [ ] **Step 3: Write the minimal implementation**

In `iphone/MakeReady/State/Actions/GroupActions.swift`, replace the stored properties and init (lines 15–29: from `private let api: APIClientProtocol` through the closing `}` of `init`) with:

```swift
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    /// ui2-groups-browse: the clock and zone the group page's day windows read (D12, D21).
    private let now: () -> Date
    private let timeZone: TimeZone
    /// ui2-groups-browse (ui2-shell D27): what a 401 from the group page's loaders does.
    private let onUnauthorized: @MainActor () async -> Void

    /// Injected state when testing, else the shared singleton.
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    /// - Parameters:
    ///   - api: client for network calls; stub in tests
    ///   - state: AppState to read/mutate; nil means AppState.shared (an
    ///     Optional because Swift 5 mode can't evaluate a @MainActor default
    ///     argument like `= .shared` from a nonisolated init)
    ///   - now / timeZone: the group page's "today" (ui2-groups-browse D12, D21)
    ///   - onUnauthorized: the group page loaders' 401 (ui2-shell D27); the throwing
    ///     Actions above keep throwing and never call it
    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.now = now
        self.timeZone = timeZone
        self.onUnauthorized = onUnauthorized
    }
```

Append, before the struct's final closing `}`:

```swift
    // MARK: - ui2-groups-browse: the group page's loads (T11–T13, T18)
    // Non-throwing, as MemberActions: a 401 signs out, a 404 is the caller's scope (D23) and
    // writes nothing, anything else is recorded console-only (these are background loads, D4)
    // and the store keeps what it held. A cancelled load or a retired session writes nothing.

    /// D12: the rail's 30 local days, today trailing.
    static let railDays = 30
    /// D13/D21: the chart's days reach three past today.
    static let chartAheadDays = 3
    /// D4: the Timeline shows the latest 5.
    static let historyLimit = 5

    /// T11/D17: the next lesson; a 204 (no lesson ahead) removes the group's entry.
    @MainActor
    func loadNextStudy(groupId: String) async {
        guard let data = await send("loadNextStudy", "GET", "/api/groups/\(groupId)/next-study") else { return }
        guard !data.isEmpty else {
            state.nextStudyByGroupId.removeValue(forKey: groupId)
            return
        }
        guard let response = decode("loadNextStudy", data, NextStudyResponse.self) else { return }
        if let study = response.study {
            state.nextStudyByGroupId[groupId] = study
        } else {
            state.nextStudyByGroupId.removeValue(forKey: groupId)
        }
    }

    /// T12/D15: the merged group history, newest first.
    @MainActor
    func loadHistory(groupId: String, limit: Int = GroupActions.historyLimit) async {
        let path = MemberActions.path("/api/groups/\(groupId)/history", [("limit", "\(limit)")])
        guard let data = await send("loadHistory", "GET", path),
              let response = decode("loadHistory", data, GroupHistoryResponse.self) else { return }
        state.historyByGroupId[groupId] = response.events
    }

    /// T13/D12/D14: `/api/home/days` filtered to the group's members, today−29 … today, local tz.
    @MainActor
    func loadGroupDays(groupId: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: 0, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let path = MemberActions.path("/api/home/days", [
            ("from", from), ("to", to), ("tz", timeZone.identifier), ("groupId", groupId)
        ])
        guard let data = await send("loadGroupDays", "GET", path),
              let response = decode("loadGroupDays", data, HomeDaysResponse.self) else { return }
        state.groupDaysByGroupId[groupId] = response.days
    }

    /// T13/D21: `scheduled_lessons` and `lesson_completions` cannot share a query (the engine
    /// 400s on mixed buckets), so two run at once over today−29 … today+3. Each series that lands
    /// replaces its map; a failed one keeps the old map and is recorded.
    @MainActor
    func loadGroupChart(groupId: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: Self.chartAheadDays, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let generation = state.initialLoad.generation
        async let scheduled = dailyCounts("loadGroupChart.scheduled", metric: "scheduled_lessons",
                                          groupId: groupId, from: from, to: to)
        async let completed = dailyCounts("loadGroupChart.completed", metric: "lesson_completions",
                                          groupId: groupId, from: from, to: to)
        let (scheduledDays, completedDays) = await (scheduled, completed)
        guard state.initialLoad.isCurrent(generation), scheduledDays != nil || completedDays != nil else { return }
        var chart = state.groupChartByGroupId[groupId] ?? GroupChart()
        if let scheduledDays { chart.scheduled = scheduledDays }
        if let completedDays { chart.completed = completedDays }
        state.groupChartByGroupId[groupId] = chart
    }

    /// T18/D3: every org the caller holds a role in — the Groups Orgs chip, for every role.
    @MainActor
    func loadMyOrganizations() async {
        guard let data = await send("loadMyOrganizations", "GET", "/api/organizations/my/organizations"),
              let response = decode("loadMyOrganizations", data, MyOrganizationsResponse.self) else { return }
        state.myOrganizations = response.data
    }

    /// One metric's rows keyed by their `day` (rows without a day or a number are skipped).
    static func byDay(_ rows: [[String: AnalyticsValue]], metric: String) -> [String: Int] {
        Dictionary(rows.compactMap { row in row["day"]?.string.flatMap { key in row[metric]?.int.map { (key, $0) } } },
                   uniquingKeysWith: { $1 })
    }

    /// A cancelled load — directly, or wrapped by APIClient as a network error.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return true }
        if case APIError.networkError(let inner) = error { return isCancellation(inner) }
        return false
    }

    /// D21: one single-metric analytics query, per day, or nil when it failed.
    @MainActor
    private func dailyCounts(_ context: String, metric: String, groupId: String, from: String, to: String) async -> [String: Int]? {
        let body: [String: Any] = [
            "metrics": [metric],
            "dimensions": ["day"],
            "timezone": timeZone.identifier,
            "filters": ["groupId": groupId, "from": from, "to": to]
        ]
        guard let data = await send(context, "POST", "/api/analytics/query", body: body),
              let response = decode(context, data, AnalyticsQueryResponse.self) else { return nil }
        return Self.byDay(response.rows, metric: metric)
    }

    /// One request through `requestWithStatus`, so a 404 keeps its status. nil = failed,
    /// cancelled, or a sign-out retired the session meanwhile; empty Data = a 204.
    @MainActor
    private func send(_ context: String, _ method: String, _ path: String, body: [String: Any]? = nil) async -> Data? {
        let generation = state.initialLoad.generation
        do {
            let data = try await api.requestWithStatus(endpoint: path, method: method, body: body)
            guard !Task.isCancelled, state.initialLoad.isCurrent(generation) else { return nil }
            return data
        } catch {
            await handle(error, context)
            return nil
        }
    }

    @MainActor
    private func decode<T: Decodable>(_ context: String, _ data: Data, _ type: T.Type) -> T? {
        do {
            return try JSONDecoder.apiDecoder.decode(type, from: data)
        } catch {
            state.recordError(APIError.decodingError(error), context: "GroupActions.\(context)", surface: false)
            return nil
        }
    }

    @MainActor
    private func handle(_ error: Error, _ context: String) async {
        if Self.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()                                         // ui2-shell D27
            return
        }
        if let http = error as? APIHTTPError, http.status == 404 { return } // D23: scope, not failure
        state.recordError(error, context: "GroupActions.\(context)", surface: false)
    }
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupActionsLoadersTests` 14/14, and the existing `MemberActionsTests` / `InviteActionsTests` (which build `GroupActions(api:state:)`) still pass. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/State/Actions/GroupActions.swift iphone/MakeReadyCaptureTests/GroupActionsLoadersTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): group page loaders for next study, history, days, chart and orgs"`

### Task 11: MakeReadyUI screen edits (D2, D22, D27)
App: iphone
Phase: 5
Recipe: /transition-review (the rail's `scrollPosition` + `withAnimation`-free jump; run it on the diff before committing)

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Home/GroupsHomeScreen.swift` (header comment, `State`, callbacks/init, body, `navRow` removed, header top gap, `SearchField` editable, new empty line)
- Modify: `iphone/MakeReadyUI/Screens/Groups/GroupsDetailScreen.swift` (`showsHeader`, rail `scrollPosition`)
- Modify: `iphone/MakeReadyUI/Screens/Groups/CreateGroupScreen.swift:76-83` (live `FieldGroup`)
- Test: `iphone/MakeReadyCaptureTests/GroupsScreensEditTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration only — the three screens are already members of MakeReady, MakeReadyUI and MakeReadyCapture)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `GroupsHomeScreen.State.listEmpty: String = ""` — `""` (nothing drawn) | `"noGroups"` | `"noMatch"`; `static func emptyCopy(_ listEmpty: String) -> String?` ("No groups yet" / "No groups match your search" / nil).
  - `GroupsHomeScreen.init(state:onSearch:onSaveOrgs:onSaveLeaders:onOpenGroup:)` — `onSelectTab`, `onToggleNav`, `onAddGroup` are GONE (D2).
  - `GroupsDetailScreen.init(state:showsHeader: Bool = true, onBack:…, onDeleteGroup:)` and `let showsHeader: Bool`; `static func openingRailIndex(_ dayCount: Int) -> Int?`.
  - `CreateGroupScreen.fieldEditing(creating: Bool) -> TextInput.Editing`.

**Why these edits sit in MakeReadyUI.** The three screens are d2m-generated views (ui2-shell D2) and the app must not re-implement them. D2/D27 rule the edits made here, exactly as ui2-members-browse D4 did for `MembersHomeScreen`; F3 routes them to `/ui2-resolve` after the build so d2m regenerates the same view — the commit body below carries that routing list (this plan never edits SPEC). One edit beyond D2/D22/D27 is needed and made under D3: `GroupsHomeScreen`'s C-034 is today the static (non-editable) form (`SearchField.swift:68`, `editable` defaults to `false`), so search could not be typed; it takes `editable: true`, the members-browse D19 precedent. Capture previews keep compiling: `ViewRegistry.swift:2519-2545` (groups-home), `:3614+` (groups-detail) and `:2091-2105` (create-group) build each screen with `state:` only, every new parameter is defaulted, and `capture/fixtures/ui2/` carries no fixture for these three screens (`grep -rl "groups-home\|groups-detail\|create-group" capture/fixtures/ui2` → no hits).

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupsScreensEditTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse D2/D22/D27: the three groups screens' wiring edits (routed to /ui2-resolve, F3).
@MainActor
final class GroupsScreensEditTests: XCTestCase {
    /// D22: the groups-home list's one line when no row shows.
    func testGroupsHomeEmptyLineCopy() {
        XCTAssertEqual(GroupsHomeScreen.emptyCopy("noGroups"), "No groups yet")
        XCTAssertEqual(GroupsHomeScreen.emptyCopy("noMatch"), "No groups match your search")
        XCTAssertNil(GroupsHomeScreen.emptyCopy(""))                 // loading: chips + an empty list
        XCTAssertEqual(GroupsHomeScreen.State.populated.listEmpty, "")
    }

    /// D27: the container pins C-040 itself; the capture render keeps the screen's own header.
    func testGroupsDetailHeaderDefaultsOnAndCanBePinnedOut() {
        XCTAssertTrue(GroupsDetailScreen(state: .populated).showsHeader)
        XCTAssertFalse(GroupsDetailScreen(state: .populated, showsHeader: false).showsHeader)
    }

    /// D27/D12: the day rail opens at its last card (today trails).
    func testGroupsDetailOpensTheRailAtItsLastCard() {
        XCTAssertEqual(GroupsDetailScreen.openingRailIndex(30), 29)
        XCTAssertEqual(GroupsDetailScreen.openingRailIndex(1), 0)
        XCTAssertNil(GroupsDetailScreen.openingRailIndex(0))
    }

    /// D27: the name field is live, focuses on appear, and locks while the create is in flight.
    func testCreateGroupFieldIsLiveAndLocksWhileCreating() {
        let idle = CreateGroupScreen.fieldEditing(creating: false)
        XCTAssertTrue(idle.focusOnAppear)
        XCTAssertTrue(idle.isEnabled)
        let creating = CreateGroupScreen.fieldEditing(creating: true)
        XCTAssertTrue(creating.focusOnAppear)
        XCTAssertFalse(creating.isEnabled)
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupsScreensEditTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "type 'GroupsHomeScreen' has no member 'emptyCopy'", "extra argument 'showsHeader' in call", "type 'CreateGroupScreen' has no member 'fieldEditing'".

- [ ] **Step 3: Write the minimal implementation — GroupsHomeScreen (D2, D3, D22)**

In `iphone/MakeReadyUI/Screens/Home/GroupsHomeScreen.swift`:

(a) Replace the header-comment line `//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.` with:

```swift
//  Wired by MakeReady/UI2/Containers/Groups/GroupsHomeContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edits, routed to /ui2-resolve (F3): no C-019 row of its own (D2 — the
//  shell's TopNav is the only one, its Groups `+` opens create-group), an editable C-034 (D3),
//  and `listEmpty`'s one line (D22).
```

(b) In the struct doc comment, replace `/// Groups (leader directory) — the Groups tab root (§6): a flat, filtered list of the caller's` … through `/// C-043 render only inside C-037 (§4).` with:

```swift
/// Groups (leader directory) — the Home tab's Groups section (§6): a flat, filtered list of the
/// caller's groups. A header of C-034 search over two C-035 filter chips, then the group list of
/// C-037 rows separated by hairlines (§2). §2's collapsed C-019 nav row is the shell's TopNav
/// (D2), so this screen starts at the header. Composed only of §4's C-034, C-035, C-036 and
/// C-037; C-038 and C-043 render only inside C-037 (§4).
```

(c) In `struct State`, add after `var groupMemberCounts: [Int]`:

```swift
        // ── D22 (ui2-groups-browse): the list's one line when no row shows ──
        /// "" = nothing (loading, or rows showing) · "noGroups" · "noMatch" — the caller decides;
        /// the copy is the screen's (`emptyCopy`).
        var listEmpty: String = ""
```

(d) Delete the three properties `var onSelectTab …`, `var onToggleNav …`, and the `OQ-groups-home-2` comment + `var onAddGroup: () -> Void = {}`. Replace the whole `init(…)` with:

```swift
    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSaveOrgs: @escaping (Set<String>) -> Void = { _ in },
        onSaveLeaders: @escaping (Set<String>) -> Void = { _ in },
        onOpenGroup: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSaveOrgs = onSaveOrgs
        self.onSaveLeaders = onSaveLeaders
        self.onOpenGroup = onOpenGroup
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }
```

(e) Delete `private static let selectedTab = "Groups"` and its two-line comment. Add, under `private static let memberCountLabel = "members"`:

```swift
    /// D22 (ui2-groups-browse): the two list lines — no copy on the frame, ruled at audit.
    private static let noGroupsCopy = "No groups yet"
    private static let noMatchCopy = "No groups match your search"

    /// D22: `State.listEmpty` → its line; nil draws nothing.
    static func emptyCopy(_ listEmpty: String) -> String? {
        switch listEmpty {
        case "noGroups": return noGroupsCopy
        case "noMatch": return noMatchCopy
        default: return nil
        }
    }
```

(f) In `body`, replace

```swift
        VStack(alignment: .leading, spacing: 0) {
            navRow
            header
            groupList
        }
```

with

```swift
        VStack(alignment: .leading, spacing: 0) {
            header
            groupList
            emptyLine
        }
```

and delete the whole `private var navRow: some View { … }` property with its doc comment.

(g) In `header`, delete the FIRST `Spacer().frame(height: Self.headerGap)` (the one above `SearchField`) and put in its place:

```swift
            // §2's "16 inset" above the field is the gap under the nav row. The row is now the
            // shell's (D2) and `HomeSectionLayout.navGap` (16) already is that gap, so the
            // screen adds none of its own (the MembersHomeScreen D4 precedent).
```

and replace the `SearchField(…)` call with the editable form:

```swift
            // §4: C-034, its editable form (D3 — members-browse D19 precedent); focus is the field's own.
            SearchField(
                text: query,
                placeholder: Self.searchPlaceholder,
                focused: false,
                onChange: { newValue in
                    query = newValue
                    onSearch(newValue)
                },
                onClear: {
                    query = ""
                    onSearch("")
                },
                editable: true
            )
```

(h) Add after the `groupList` property:

```swift
    /// D22: one centred `type-body-sm` `color-text-secondary` line under the chips when no row
    /// shows — the groups-detail §3 section-empty treatment.
    @ViewBuilder private var emptyLine: some View {
        if state.groupNames.isEmpty, let copy = Self.emptyCopy(state.listEmpty) {
            Text(copy)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Token.Space.pageMargin)
        }
    }
```

- [ ] **Step 4: Write the minimal implementation — GroupsDetailScreen (D27)**

In `iphone/MakeReadyUI/Screens/Groups/GroupsDetailScreen.swift`:

(a) Replace `//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.` with:

```swift
//  Wired by MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edits, routed to /ui2-resolve (F3): `showsHeader` (D27 — the container
//  pins C-040 above its ScrollView) and the day rail opening at its last card (D27/D12).
```

(b) After `let state: State` add:

```swift
    /// D27: false when the container pins C-040 above its own ScrollView, so the header is not
    /// drawn twice. True (the default) keeps the capture / ViewRegistry render whole.
    let showsHeader: Bool
```

(c) In `init`, add the parameter `showsHeader: Bool = true,` directly after `state: State,` and the assignment `self.showsHeader = showsHeader` directly after `self.state = state`.

(d) Replace the comment block that starts `// §3 has one interaction that stays on the screen` (3 lines) with:

```swift
    // R-31 ephemeral UI: the day rail's scroll position. D27/D12: the rail opens at its last card
    // (today trails) and "Jump to today" scrolls back to it.
    @SwiftUI.State private var railDay: Int?

    /// D27: the card the rail opens on — the last (today trails, D12); nil while the rail is empty.
    static func openingRailIndex(_ dayCount: Int) -> Int? { dayCount > 0 ? dayCount - 1 : nil }
```

(e) In `body`, wrap the `PageHeader(…)…​.ui2Element("C-040 PageHeader")` expression in `if showsHeader { … }`.

(f) In `dayRail`, add `.scrollTargetLayout()` on the `HStack` directly before its `.padding(.horizontal, Token.Space.pageMargin)`, and replace the rail's trailing `.scrollIndicators(.hidden)` with:

```swift
        .scrollIndicators(.hidden)
        // D27: opens on the last card; days that land after the page opened re-align it.
        .scrollPosition(id: $railDay, anchor: .trailing)
        .onAppear { railDay = Self.openingRailIndex(state.dayNumbers.count) }
        .onChange(of: state.dayNumbers.count) { _, count in railDay = Self.openingRailIndex(count) }
```

(g) Replace `scrollToToday(_:)`'s body with:

```swift
        guard let today = state.dayDateStates.firstIndex(of: "today") else { return }
        railDay = today
        proxy.scrollTo(today, anchor: .trailing)
```

- [ ] **Step 5: Write the minimal implementation — CreateGroupScreen (D27)**

In `iphone/MakeReadyUI/Screens/Groups/CreateGroupScreen.swift`:

(a) Replace `//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.` with:

```swift
//  Wired by MakeReady/UI2/Containers/Groups/CreateGroupContainer.swift (ui2-groups-browse).
//  ui2-groups-browse edit, routed to /ui2-resolve (F3): the name field is live (D27 — the
//  `editing:` precedent of InviteMemberScreen.swift:160), read-only while creating.
```

(b) Replace the `FieldGroup(…)` call (lines 76–83) with:

```swift
                FieldGroup(
                    label: Self.label,
                    field: .text,
                    style: fieldFocused ? .focus : .default,
                    layout: .default,
                    text: text,
                    placeholder: Self.placeholder,
                    editing: Self.fieldEditing(creating: state.creating),
                    // §3: "The input does not accept characters past 200 (server limit, §5)."
                    onChange: { text = String($0.prefix(Self.maxLength)) }
                )
```

(c) Add next to `private static let maxLength = 200`:

```swift
    /// D27: C-045's live form — focused on appear (§3 `empty`), locked while creating (§3
    /// `creating`: "the field is read-only").
    static func fieldEditing(creating: Bool) -> TextInput.Editing {
        TextInput.Editing(focusOnAppear: true, isEnabled: !creating)
    }
```

- [ ] **Step 6: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`: `GroupsScreensEditTests` 4/4, `GroupsHomeFilterTests` (UI2MembersComponentTests.swift:188) still green, and `MakeReadyCaptureTests/ViewRegistry.swift` compiles unchanged. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (`raw_horizontal_scrollview` stays clean: the rail is still `HorizontalRail`). Run `/transition-review` on `git diff` → PASS (no `asyncAfter`, no implicit `.animation(`, scroll position is a binding write).

- [ ] **Step 7: Commit** — the body is the F3 routing list for `/ui2-resolve`:

```bash
git add iphone/MakeReadyUI/Screens/Home/GroupsHomeScreen.swift iphone/MakeReadyUI/Screens/Groups/GroupsDetailScreen.swift iphone/MakeReadyUI/Screens/Groups/CreateGroupScreen.swift iphone/MakeReadyCaptureTests/GroupsScreensEditTests.swift iphone/MakeReady.xcodeproj/project.pbxproj
git commit -F - <<'MSG'
feat(ui2-groups-browse): groups screens take the shell's nav, live fields and empty lines

Route to /ui2-resolve after the build (F3) so d2m regenerates the same views:
- groups-home (GroupsHomeScreen): no C-019 row and no onSelectTab/onToggleNav/onAddGroup (D2);
  no top 16 above C-034 (the shell's navGap); C-034 editable: true (D3, members-browse D19);
  State.listEmpty -> "No groups yet" / "No groups match your search", one centred body-sm
  text-secondary line (D22)
- groups-detail (GroupsDetailScreen): showsHeader: Bool = true (D27); the day rail opens at its
  last card through scrollPosition(id:anchor: .trailing) (D27/D12)
- create-group (CreateGroupScreen): FieldGroup editing: .init(focusOnAppear: true,
  isEnabled: !creating) + onChange with the 200-character cap (D27)
MSG
```

### Task 12: GroupsHomeMapper + GroupsHomeContainer
App: iphone
Phase: 5
Recipe: /ios-error-surface (D22: a failed first load surfaces the banner; leaders/orgs stay console-only)

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupsHomeMapper.swift`
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupsHomeContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/GroupsHomeMapperTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Ruby step + `capture-targets.rb`)

**Interfaces:**
- Consumes: Task 8 `UserGroup.organizationId`; Task 9 `AppState.myOrganizations`; Task 10 `GroupActions(state:onUnauthorized:)`, `loadMyOrganizations()`, `GroupActions.isCancellation(_:)`; Task 11 `GroupsHomeScreen.init(state:onSearch:onSaveOrgs:onSaveLeaders:onOpenGroup:)` and `State.listEmpty`; existing `MemberProfileMapper.leaderShortName(_:)`, `FilterMenuOverlay.chipLabel(picked:resting:noun:)`, `GroupLeader.displayName`, `ProgramActions(state:).loadGroupLeaders()`, `UI2Navigator.push`.
- Produces:
  - `enum GroupsHomeMapper` — `static let allOrgs = "All Orgs"`, `static let allLeaders = "All Leaders"`; `struct Selection: Equatable { var search = ""; var orgLabels: Set<String> = []; var leaderLabels: Set<String> = [] }`; `struct Output { var state: GroupsHomeScreen.State; var groupIds: [String]; func groupId(atRow: Int) -> String? }`; `static func output(groups: [UserGroup], leaders: [GroupLeader], organizations: [OrganizationData], selection: Selection, typedSearch: String, loaded: Bool) -> Output`; `static func sorted(_: [UserGroup]) -> [UserGroup]`; `static func matches(_ name: String, search: String) -> Bool`; `static func listEmpty(rows: Int, groups: Int, loaded: Bool) -> String`.
  - `struct GroupsHomeContainer: View` — `init(destination: @escaping (_ id: String, _ name: String) -> UI2Destination)` (UI2Shell passes `.groupDetail`, Task 16); `static let searchDebounce: Duration = .milliseconds(300)`; `static let loadFailedMessage = "Couldn't load your groups"`; `@MainActor @discardableResult static func load(authManager: AuthManager, forceRefresh: Bool = false) async -> Bool`; `@MainActor static func refresh(authManager: AuthManager) async` (Task 16's pull-to-refresh); `@MainActor static func route(_ error: Error, context: String, surface: Bool, state: AppState, onUnauthorized: @MainActor () async -> Void) async`.

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupsHomeMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse D3/D20/D22: the Groups section from `AppState.groups`.
@MainActor
final class GroupsHomeMapperTests: XCTestCase {
    private let stamp = ISO8601DateFormatter().date(from: "2026-10-01T12:00:00Z")!

    private func group(_ id: String, _ name: String, creator: String = "u1", creatorName: String? = "Luke Keith",
                       org: String? = "o1", members: Int = 3, cover: String? = nil) -> UserGroup {
        UserGroup(id: id, code: "C\(id)", name: name, coverImageUrl: cover, isPrivate: false, allowInvites: true,
                  memberCount: members, creatorId: creator, creatorName: creatorName, organizationId: org,
                  createdAt: stamp, updatedAt: stamp)
    }

    private func leader(_ id: String, _ first: String, _ last: String) -> GroupLeader {
        GroupLeader(id: id, firstName: first, lastName: last, avatarUrl: nil, programCount: 0, mediaCount: 0)
    }

    private let orgs = [OrganizationData(id: "o1", name: "Grace Church"), OrganizationData(id: "o2", name: "Hope Chapel")]

    private func output(_ groups: [UserGroup], leaders: [GroupLeader] = [], organizations: [OrganizationData]? = nil,
                        selection: GroupsHomeMapper.Selection = .init(), loaded: Bool = true) -> GroupsHomeMapper.Output {
        GroupsHomeMapper.output(groups: groups, leaders: leaders, organizations: organizations ?? orgs,
                                selection: selection, typedSearch: selection.search, loaded: loaded)
    }

    /// D3: by name, case- and diacritic-insensitive.
    func testRowsSortByNameIgnoringCaseAndDiacritics() {
        let out = output([group("1", "zeta"), group("2", "Émile"), group("3", "alpha"), group("4", "Beta")])
        XCTAssertEqual(out.state.groupNames, ["alpha", "Beta", "Émile", "zeta"])
        XCTAssertEqual(out.groupIds, ["3", "4", "2", "1"])
        XCTAssertEqual(out.groupId(atRow: 1), "4")
        XCTAssertNil(out.groupId(atRow: 9))
    }

    /// D3: case-insensitive substring of the name, trimmed.
    func testSearchIsACaseInsensitiveSubstring() {
        let out = output([group("1", "zeta"), group("2", "Beta"), group("3", "alpha")],
                         selection: .init(search: "  ETA "))
        XCTAssertEqual(out.state.groupNames, ["Beta", "zeta"])
        XCTAssertTrue(GroupsHomeMapper.matches("Young Pros", search: ""))
        XCTAssertFalse(GroupsHomeMapper.matches("Young Pros", search: "old"))
    }

    /// D3: search AND leaders AND orgs; a pick maps its label to every id with that label.
    func testChipsAndSearchCombineWithAnd() {
        let groups = [
            group("1", "Alpha Men", creator: "u1", org: "o1"),
            group("2", "Alpha Women", creator: "u2", org: "o1"),
            group("3", "Alpha Youth", creator: "u1", org: "o2"),
            group("4", "Beta", creator: "u1", org: "o1")
        ]
        let leaders = [leader("u1", "Tony", "Stark"), leader("u2", "Pepper", "Potts")]
        let out = output(groups, leaders: leaders,
                         selection: .init(search: "alpha", orgLabels: ["Grace Church"], leaderLabels: ["Tony Stark"]))
        XCTAssertEqual(out.state.groupNames, ["Alpha Men"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
        XCTAssertEqual(out.state.orgFilterLabel, "Grace Church")
        XCTAssertEqual(out.state.selectedLeaders, ["Tony Stark"])
        XCTAssertEqual(out.state.selectedOrgs, ["Grace Church"])
    }

    /// D3: two leaders with one name are one option and select together.
    func testSameNamedLeadersSelectTogether() {
        let groups = [group("1", "A", creator: "u1"), group("2", "B", creator: "u9"), group("3", "C", creator: "u2")]
        let leaders = [leader("u1", "Sam", "Lee"), leader("u9", "Sam", "Lee"), leader("u2", "Ann", "Ray")]
        let out = output(groups, leaders: leaders, selection: .init(leaderLabels: ["Sam Lee"]))
        XCTAssertEqual(out.state.leaderOptions, ["Sam Lee", "Ann Ray"])
        XCTAssertEqual(out.state.groupNames, ["A", "B"])
    }

    /// D3: an empty selection is "all"; two picks read "2 leaders".
    func testChipLabels() {
        let leaders = [leader("u1", "Tony", "Stark"), leader("u2", "Pepper", "Potts")]
        XCTAssertEqual(output([], leaders: leaders).state.leaderFilterLabel, "All Leaders")
        XCTAssertEqual(output([], leaders: leaders).state.orgFilterLabel, "All Orgs")
        XCTAssertEqual(output([], leaders: leaders, selection: .init(leaderLabels: ["Tony Stark", "Pepper Potts"]))
            .state.leaderFilterLabel, "2 leaders")
    }

    /// D3: the Orgs chip shows only with ≥2 orgs, and a hidden chip filters nothing.
    func testOrgChipNeedsTwoOrgs() {
        XCTAssertTrue(output([]).state.orgFilterVisible)
        let one = output([group("1", "A", org: "o2")], organizations: [orgs[0]], selection: .init(orgLabels: ["Grace Church"]))
        XCTAssertFalse(one.state.orgFilterVisible)
        XCTAssertEqual(one.state.groupNames, ["A"])
        XCTAssertEqual(one.state.orgOptions, ["Grace Church"])
    }

    /// D20: the leader slot is the short name; D3: cover, member count.
    func testRowShowsShortLeaderNameCoverAndCount() {
        let out = output([group("1", "A", creatorName: "Luke Keith", members: 25, cover: "https://img/a.jpg"),
                          group("2", "B", creatorName: nil, members: 0)])
        XCTAssertEqual(out.state.groupLeaderNames, ["L. Keith", ""])
        XCTAssertEqual(out.state.groupPhotoURLs, ["https://img/a.jpg", ""])
        XCTAssertEqual(out.state.groupMemberCounts, [25, 0])
    }

    /// D22: loading draws nothing; zero groups and no match each get their line.
    func testEmptyLines() {
        XCTAssertEqual(output([], loaded: false).state.listEmpty, "")
        XCTAssertEqual(output([], loaded: true).state.listEmpty, "noGroups")
        XCTAssertEqual(output([group("1", "Alpha")], selection: .init(search: "zzz")).state.listEmpty, "noMatch")
        XCTAssertEqual(output([group("1", "Alpha")]).state.listEmpty, "")
    }

    /// D22 + ui2-shell D28: a failed load surfaces the banner; a 401 signs out instead.
    func testLoadFailureRouting() async {
        let state = AppState()
        var signedOut = false
        await GroupsHomeContainer.route(APIError.unauthorized, context: "GroupsHomeContainer.loadGroups", surface: true,
                                        state: state, onUnauthorized: { signedOut = true })
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
        await GroupsHomeContainer.route(APIError.serverError("boom"), context: "GroupsHomeContainer.loadGroups", surface: true,
                                        state: state, onUnauthorized: {})
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't load your groups")
        await GroupsHomeContainer.route(CancellationError(), context: "x", surface: true, state: state, onUnauthorized: {})
        XCTAssertEqual(state.errors.count, 1)
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupsHomeMapperTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "cannot find 'GroupsHomeMapper' in scope", "cannot find 'GroupsHomeContainer' in scope".

- [ ] **Step 3: Write the minimal implementation**

Create `iphone/MakeReady/UI2/Containers/Groups/GroupsHomeMapper.swift`:

```swift
import Foundation

/// ui2-groups-browse D3/D20/D22 + groups-home §3: the Groups section from `AppState.groups`.
/// Pure — the container owns the typed text, the debounce and the chip picks. The screen's chip
/// menus speak labels (`GroupsHomeScreen.State.selectedOrgs` / `selectedLeaders`), so a pick is a
/// label set mapped to ids here; two leaders with one name select together (D3).
enum GroupsHomeMapper {
    static let allOrgs = "All Orgs"
    static let allLeaders = "All Leaders"

    /// The container's query. `search` is the APPLIED text — written 300 ms after the last
    /// keystroke (D3); [] = no filter.
    struct Selection: Equatable {
        var search = ""
        var orgLabels: Set<String> = []
        var leaderLabels: Set<String> = []
    }

    /// The State plus the group id behind every row it renders.
    struct Output {
        var state: GroupsHomeScreen.State
        var groupIds: [String]

        func groupId(atRow row: Int) -> String? {
            groupIds.indices.contains(row) ? groupIds[row] : nil
        }
    }

    static func output(groups: [UserGroup], leaders: [GroupLeader], organizations: [OrganizationData],
                       selection: Selection, typedSearch: String, loaded: Bool) -> Output {
        let orgChipShown = organizations.count >= 2
        let leaderLabels = unique(leaders.map(\.displayName))
        let orgLabels = unique(organizations.map(\.name))
        let pickedLeaders = leaderLabels.filter { selection.leaderLabels.contains($0) }
        // A hidden Orgs chip (< 2 orgs) can't be cleared, so it filters nothing.
        let pickedOrgs = orgChipShown ? orgLabels.filter { selection.orgLabels.contains($0) } : []
        let leaderIds = Set(leaders.filter { pickedLeaders.contains($0.displayName) }.map(\.id))
        let orgIds = Set(organizations.filter { pickedOrgs.contains($0.name) }.map(\.id))
        let rows = sorted(groups).filter { group in
            matches(group.name, search: selection.search)
                && (pickedLeaders.isEmpty || leaderIds.contains(group.creatorId))
                && (pickedOrgs.isEmpty || group.organizationId.map { orgIds.contains($0) } == true)
        }
        let state = GroupsHomeScreen.State(
            searchText: typedSearch,
            orgFilterVisible: orgChipShown,
            orgFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedOrgs, resting: allOrgs, noun: "orgs"),
            leaderFilterLabel: FilterMenuOverlay.chipLabel(picked: pickedLeaders, resting: allLeaders, noun: "leaders"),
            orgOptions: orgLabels,
            leaderOptions: leaderLabels,
            selectedOrgs: Set(pickedOrgs),
            selectedLeaders: Set(pickedLeaders),
            groupNames: rows.map(\.name),
            groupPhotoURLs: rows.map { $0.coverImageUrl ?? "" },
            groupLeaderNames: rows.map { MemberProfileMapper.leaderShortName($0.creatorName) },   // D20
            groupMemberCounts: rows.map(\.memberCount),
            listEmpty: listEmpty(rows: rows.count, groups: groups.count, loaded: loaded)
        )
        return Output(state: state, groupIds: rows.map(\.id))
    }

    /// D3: by name, case- and diacritic-insensitive; equal names keep a stable order by id.
    static func sorted(_ groups: [UserGroup]) -> [UserGroup] {
        groups.sorted { lhs, rhs in
            switch lhs.name.compare(rhs.name, options: [.caseInsensitive, .diacriticInsensitive]) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: return lhs.id < rhs.id
            }
        }
    }

    /// D3: a case-insensitive substring of the name; an empty (trimmed) query matches all.
    static func matches(_ name: String, search: String) -> Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || name.range(of: query, options: .caseInsensitive) != nil
    }

    /// D22: "" while loading or while rows show; "noGroups" when the caller has none;
    /// "noMatch" when search or a chip hides every group.
    static func listEmpty(rows: Int, groups: Int, loaded: Bool) -> String {
        guard rows == 0, loaded else { return "" }
        return groups == 0 ? "noGroups" : "noMatch"
    }

    /// Labels in first-seen order, each once (C-036 options are keyed by label).
    private static func unique(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.filter { seen.insert($0).inserted }
    }
}
```

Create `iphone/MakeReady/UI2/Containers/Groups/GroupsHomeContainer.swift`:

```swift
import SwiftUI

/// ui2-groups-browse §iphone Groups home: the Home tab's Groups section (D3, D20, D22).
/// Cache-first: renders `AppState.groups` at once, then loads groups, leaders and the caller's
/// orgs. The screen has no root scroll — the shell's page scroll (HomeSectionLayout) scrolls it.
/// A row tap pushes `destination(id, name)` on this tab's stack (UI2Shell passes `.groupDetail`).
struct GroupsHomeContainer: View {
    /// D3: the search applies this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)
    /// D22: the banner over a list whose load failed.
    static let loadFailedMessage = "Couldn't load your groups"

    /// D1: the page a row opens.
    let destination: (_ id: String, _ name: String) -> UI2Destination

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// The text as typed (the field shows it); `selection.search` is the debounced copy.
    @State private var typedSearch = ""
    @State private var selection = GroupsHomeMapper.Selection()
    /// The pending debounce; a newer keystroke cancels it (Task + `Task.sleep`, never `asyncAfter`).
    @State private var searchTask: Task<Void, Never>?
    /// D22: true once a load succeeded — before that an empty list draws no line.
    @State private var loaded = false

    var body: some View {
        let app = AppState.shared
        let output = GroupsHomeMapper.output(
            groups: app.groups.all, leaders: app.groupLeaders, organizations: app.myOrganizations,
            selection: selection, typedSearch: typedSearch, loaded: loaded || !app.groups.all.isEmpty
        )
        GroupsHomeScreen(
            state: output.state,
            onSearch: { text in
                typedSearch = text
                searchTask?.cancel()
                searchTask = Task { @MainActor in
                    try? await Task.sleep(for: Self.searchDebounce)
                    guard !Task.isCancelled else { return }
                    selection.search = text
                }
            },
            onSaveOrgs: { selection.orgLabels = $0 },
            onSaveLeaders: { selection.leaderLabels = $0 },
            onOpenGroup: { row in
                guard let id = output.groupId(atRow: row) else { return }
                navigator.push(destination(id, output.state.groupNames[row]))
            }
        )
        .task { loaded = await Self.load(authManager: authManager) }
        .onDisappear { searchTask?.cancel() }
    }

    /// D3/D22: groups (cache-first; a failure surfaces the banner), leaders and orgs (console-only)
    /// all at once. Returns whether the groups load succeeded.
    @MainActor
    @discardableResult
    static func load(authManager: AuthManager, forceRefresh: Bool = false) async -> Bool {
        let state = AppState.shared
        let onUnauthorized = signOut(authManager)
        async let leaders: () = loadLeaders(state: state, onUnauthorized: onUnauthorized)
        async let orgs: () = GroupActions(onUnauthorized: onUnauthorized).loadMyOrganizations()
        var ok = true
        do {
            try await GroupActions().loadGroups(forceRefresh: forceRefresh)
        } catch {
            ok = false
            await route(error, context: "GroupsHomeContainer.loadGroups", surface: true,
                        state: state, onUnauthorized: onUnauthorized)
        }
        _ = await (leaders, orgs)
        return ok
    }

    /// D3: the Groups section's pull-to-refresh (UI2Shell.refreshAction).
    @MainActor
    static func refresh(authManager: AuthManager) async {
        await load(authManager: authManager, forceRefresh: true)
    }

    /// D22 + ui2-shell D28: a cancelled load is nothing; a 401 signs out; anything else is
    /// recorded — surfaced with `loadFailedMessage` when `surface` (the groups list), else console-only.
    @MainActor
    static func route(_ error: Error, context: String, surface: Bool, state: AppState,
                      onUnauthorized: @MainActor () async -> Void) async {
        if GroupActions.isCancellation(error) { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        state.recordError(error, context: context, surface: surface,
                          friendlyMessage: surface ? loadFailedMessage : nil)
    }

    @MainActor
    private static func loadLeaders(state: AppState, onUnauthorized: @escaping @MainActor () async -> Void) async {
        do {
            try await ProgramActions(state: state).loadGroupLeaders()
        } catch {
            await route(error, context: "GroupsHomeContainer.loadGroupLeaders", surface: false,
                        state: state, onUnauthorized: onUnauthorized)
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    private static func signOut(_ authManager: AuthManager) -> @MainActor () async -> Void {
        { [authManager] in
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "GroupsHomeContainer.signOut", surface: false)
            }
        }
    }
}
```

Register both in the app target and sync the capture target (repo root):

```bash
ruby - "app:MakeReady/UI2:Containers/Groups/GroupsHomeMapper.swift" "app:MakeReady/UI2:Containers/Groups/GroupsHomeContainer.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check   # → exit 0
```

(Nothing renders `GroupsHomeContainer` yet — UI2Shell's `.groups` section wires it in Task 16.)

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupsHomeMapperTests` 9/9. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/UI2/Containers/Groups/GroupsHomeMapper.swift iphone/MakeReady/UI2/Containers/Groups/GroupsHomeContainer.swift iphone/MakeReadyCaptureTests/GroupsHomeMapperTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): Groups section mapper and container — sort, search, chips, empty lines"`

### Task 13: UI2Navigator.replaceTop + CreateGroupContainer
App: iphone
Phase: 5
Recipe: /ios-error-surface (a failed create is user-initiated → surfaced; 401 → sign-out first)

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift` (add `replaceTop(_:with:on:)` after `popIfTop`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Navigation.swift:5-15` (add `replaceTop` to `UI2Navigator`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:121-127` (inject `replaceTop` into each stack's navigator)
- Create: `iphone/MakeReady/UI2/Containers/Groups/CreateGroupContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (append), `iphone/MakeReadyCaptureTests/CreateGroupSubmitTests.swift` (new)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Ruby step + `capture-targets.rb`)

**Interfaces:**
- Consumes: Task 10's `GroupActions.isCancellation(_:)`; Task 11's live `CreateGroupScreen`; existing `GroupActions.createGroup(name:…)` (it already `upsert`s into `AppState.groups` and persists, `GroupActions.swift:172-173` — the container adds no merge of its own), `AuthStatusPolicy.shouldSignOut(after:)`, `View.ui2PushedPageFill()`.
- Produces:
  - `UI2ShellModel.replaceTop(_ expected: UI2Destination, with next: UI2Destination, on tab: TabBar.Tab)` — one path write, only while `expected` is the tab's last entry.
  - `UI2Navigator.replaceTop: (UI2Destination, UI2Destination) -> Void` (expected, next); UI2Shell wires it per stack.
  - `enum CreateGroupSubmit { static let failedMessage = "Couldn't create the group"; static let maxLength = 200; @MainActor static func run(name: String, actions: GroupActions = GroupActions(), state: AppState? = nil, onUnauthorized: @MainActor () async -> Void) async -> UserGroup? }`
  - `struct CreateGroupContainer: View { init(route: UI2Destination, destination: @escaping (UserGroup) -> UI2Destination) }` — on success calls `navigator.replaceTop(route, destination(group))`. Task 16 passes `route: .createGroup, destination: { .groupDetail(id: $0.id, name: $0.name) }` once those cases exist.

- [ ] **Step 1: Write the failing tests**

Append inside `final class UI2ShellModelTests` (before its closing `}`) in `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`:

```swift

    // MARK: - ui2-groups-browse D8 / T17: the guarded replace

    /// D8: one path write — the top entry becomes the new page; back returns to what was below.
    func testReplaceTopSwapsOnlyTheLastEntry() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.replaceTop(editPhone, with: .memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        XCTAssertEqual(m.path(for: .home), [tony, .memberDetail(id: "m2", name: "Clark Kent")])
    }

    /// D8: swiped back mid-create (the form is no longer on top) → nothing is written.
    func testReplaceTopIsANoOpWhenTheExpectedPageIsNotOnTop() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        m.push(editPhone, on: .home)
        m.setPath([tony], for: .home)                                    // the system edge-swipe pop
        m.replaceTop(editPhone, with: .memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.replaceTop(editPhone, with: tony, on: .profile)                // empty tab: no-op
        XCTAssertEqual(m.path(for: .profile), [])
    }
```

Create `iphone/MakeReadyCaptureTests/CreateGroupSubmitTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse D8: the create call — trimmed name, default flags, stored on success;
/// a failure surfaces "Couldn't create the group"; a 401 signs out and surfaces nothing.
@MainActor
final class CreateGroupSubmitTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let created = #"{"success":true,"group":{"id":"g9","code":"WALK01","name":"Walk Test Group","isPrivate":false,"allowInvites":true,"memberDirectory":true,"memberDirectoryAccess":"ALLOWED","memberCount":0,"creatorId":"u1","creatorName":"Luke Keith","createdAt":"2026-10-27T12:00:00.000Z","updatedAt":"2026-10-27T12:00:00.000Z"}}"#

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

    private func run(_ name: String, onUnauthorized: @MainActor () async -> Void = {}) async -> UserGroup? {
        await CreateGroupSubmit.run(name: name, actions: GroupActions(api: api, state: state), state: state,
                                    onUnauthorized: onUnauthorized)
    }

    func testCreateSendsTheTrimmedNameWithDefaultFlagsAndStoresTheGroup() async {
        api.stub("POST", "/api/groups", json: created)
        let group = await run("  Walk Test Group \n")
        XCTAssertEqual(group?.id, "g9")
        XCTAssertEqual(state.groups["g9"]?.name, "Walk Test Group")
        let body = api.calls.first { $0.method == "POST" }?.body
        XCTAssertEqual(body?["name"] as? String, "Walk Test Group")
        XCTAssertEqual(body?["isPrivate"] as? Bool, false)
        XCTAssertEqual(body?["allowInvites"] as? Bool, true)
        XCTAssertEqual(body?["memberDirectory"] as? Bool, true)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testFailureSurfacesTheFriendlyMessage() async {
        api.errorFor = { _, _ in APIError.serverError("Name already taken") }
        let group = await run("Walk Test Group")
        XCTAssertNil(group)
        XCTAssertEqual(state.activeSurfacedError?.message, "Couldn't create the group")
        XCTAssertEqual(state.errors.last?.context, "CreateGroupContainer.create")
    }

    func testUnauthorizedSignsOutAndSurfacesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        let group = await run("Walk Test Group", onUnauthorized: { signedOut = true })
        XCTAssertNil(group)
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.activeSurfacedError)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testBlankNameSendsNothingAndLongNamesAreCapped() async {
        let blank = await run("   ")
        XCTAssertNil(blank)
        XCTAssertTrue(api.calls.isEmpty)
        api.stub("POST", "/api/groups", json: created)
        _ = await run(String(repeating: "a", count: 250))
        XCTAssertEqual((api.calls.first?.body?["name"] as? String)?.count, 200)
    }
}
```

Register the new test file (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:CreateGroupSubmitTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "value of type 'UI2ShellModel' has no member 'replaceTop'", "cannot find 'CreateGroupSubmit' in scope".

- [ ] **Step 3: Write the minimal implementation**

In `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift`, after `popIfTop(_:on:)`:

```swift
    /// ui2-groups-browse D8: the create form's success — `next` replaces `expected` in ONE path
    /// write, only while `expected` is still the tab's last entry (as `popIfTop`), so a swipe-back
    /// or a Home re-tap mid-create writes nothing. Back from `next` returns to what was below.
    mutating func replaceTop(_ expected: UI2Destination, with next: UI2Destination, on tab: TabBar.Tab) {
        guard var path = paths[tab], path.last == expected else { return }
        path[path.count - 1] = next
        paths[tab] = path
    }
```

In `iphone/MakeReady/UI2/Shell/UI2Navigation.swift`, inside `struct UI2Navigator`, after `var depth: () -> Int = { 0 }`:

```swift
    /// ui2-groups-browse D8: replace the top entry (first) with a new page (second) — a no-op
    /// unless the first is still on top.
    var replaceTop: (UI2Destination, UI2Destination) -> Void = { _, _ in }
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift`, in `stack(for:)`, replace the navigator construction with:

```swift
        .environment(\.ui2Navigator, UI2Navigator(
            push: { model.push($0, on: tab) },
            pop: { model.pop(on: tab) },
            popIfTop: { model.popIfTop($0, on: tab) },
            popTo: { model.popTo(depth: $0, on: tab) },
            depth: { model.path(for: tab).count },
            replaceTop: { model.replaceTop($0, with: $1, on: tab) }
        ))
```

Create `iphone/MakeReady/UI2/Containers/Groups/CreateGroupContainer.swift`:

```swift
import SwiftUI

/// ui2-groups-browse D8: the create call and its error routing, apart from the view so it is
/// testable (the InviteMemberSend precedent).
enum CreateGroupSubmit {
    static let failedMessage = "Couldn't create the group"
    /// D8 / create-group §3: 1–200 characters (the server's limit).
    static let maxLength = 200

    /// Creates the group with `GroupActions.createGroup`'s default flags (`isPrivate:false,
    /// allowInvites:true, memberDirectory:true` → D11 `ALLOWED`); the Action upserts it into
    /// `AppState.groups`. A 401 signs out first and surfaces nothing; a cancelled request is
    /// silent; any other failure surfaces `failedMessage`. nil on any failure or a blank name.
    @MainActor
    static func run(name: String, actions: GroupActions = GroupActions(), state: AppState? = nil,
                    onUnauthorized: @MainActor () async -> Void) async -> UserGroup? {
        let state = state ?? .shared
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return nil }
        do {
            return try await actions.createGroup(name: trimmed)
        } catch {
            if GroupActions.isCancellation(error) { return nil }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()                                   // ui2-shell D27
                return nil
            }
            state.recordError(error, context: "CreateGroupContainer.create", surface: true,
                              friendlyMessage: failedMessage)
            return nil
        }
    }
}

/// ui2-groups-browse D8: hosts the d2m-built `CreateGroupScreen`. Owns only the in-flight flag:
/// creating = Create disabled + the field read-only (§3 `creating`); a failure keeps the typed
/// name (the screen's own state) and re-enables Create as the retry. Success replaces this form
/// with the new group's page in one path write — back then returns to Groups.
struct CreateGroupContainer: View {
    /// This form's own route — what `replaceTop` expects on top (UI2Shell passes `.createGroup`).
    let route: UI2Destination
    /// The page that replaces the form (UI2Shell passes the new group's `.groupDetail`).
    let destination: (UserGroup) -> UI2Destination

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var creating = false

    var body: some View {
        CreateGroupScreen(
            state: .init(text: "", focused: !creating, creating: creating),
            onBack: { navigator.pop() },
            onCreate: create
        )
        .ui2PushedPageFill()
    }

    private func create(_ name: String) {
        guard !creating else { return }                              // §3 creating: one request
        creating = true
        Task { @MainActor in
            let group = await CreateGroupSubmit.run(name: name, onUnauthorized: { [authManager] in
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "CreateGroupContainer.signOut", surface: false)
                }
            })
            creating = false
            if let group { navigator.replaceTop(route, destination(group)) }
        }
    }
}
```

Register it and sync the capture target (repo root):

```bash
ruby - "app:MakeReady/UI2:Containers/Groups/CreateGroupContainer.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check   # → exit 0
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`: the 2 new `UI2ShellModelTests` cases and `CreateGroupSubmitTests` 4/4, every existing shell test still green. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/UI2/Shell/UI2ShellModel.swift iphone/MakeReady/UI2/Shell/UI2Navigation.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReady/UI2/Containers/Groups/CreateGroupContainer.swift iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift iphone/MakeReadyCaptureTests/CreateGroupSubmitTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): guarded replaceTop and the create-group container"`

### Task 14: GroupDetailMapper
App: iphone
Phase: 6
Recipe: iphone/.claude/CLAUDE.md (pure mapper — no state, no I/O)

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailMapper.swift`
- Test: `iphone/MakeReadyCaptureTests/GroupDetailMapperTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Ruby step + `capture-targets.rb`)

**Interfaces:**
- Consumes: Task 8 `NextStudy`, `NextStudyActivity`, `NextStudyProgram`, `GroupHistoryEvent`, `UserGroup.memberDirectoryAccess`; Task 9 `GroupChart`; Task 10 `GroupActions.railDays` (30), `GroupActions.chartAheadDays` (3); Task 11 `GroupsDetailScreen.State`; existing `MembersHomeMapper.parseDate / mediumDate / joinedLabel / displayName / nonEmpty`, `HomeDashboardMapper.days / key / blockMinutes / shortMonths`, `MemberProfileMapper.Rail`, `GroupMember`, `JoinRequest`, `EnrollmentWithProgram`, `HomeDay`, `AgeRange`.
- Produces:
  - `enum GroupDetailMapper` with `static let chartBackDays = 23`
  - `struct Input { var name: String; var group: UserGroup? = nil; var members: [GroupMember] = []; var requests: [JoinRequest] = []; var enrollments: [EnrollmentWithProgram] = []; var nextStudy: NextStudy? = nil; var history: [GroupHistoryEvent] = []; var days: [HomeDay]? = nil; var chart: GroupChart? = nil }`
  - `struct MemberRow: Equatable { let id: String; let name: String }` (id = `GroupMember.userId`, D7)
  - `struct Output { var state: GroupsDetailScreen.State; var memberRows: [MemberRow]; func member(atRow: Int) -> MemberRow? }`
  - `struct Chart: Equatable { var dates: [String]; var scheduled: [Int]; var completed: [Int]; var windowStart: String; var windowEnd: String; var today: String }`
  - `static func output(_ input: Input, now: Date, timeZone: TimeZone) -> Output`
  - `static func ageLabel(_: AgeRange?) -> String`, `visibilityLabel(_ isPrivate: Bool) -> String`, `maxMembersLabel(_: Int?) -> String`, `directoryAccessLabel(_ access: String?, memberDirectory: Bool) -> String`, `dateLabel(_: Date, now: Date, timeZone: TimeZone) -> String`, `lessonMeta(_ scheduledDate: String, now: Date, timeZone: TimeZone) -> String`, `line2(scheduled: Int, completed: Int, isToday: Bool) -> String`, `rail(days: [HomeDay]?, chart: GroupChart?, now: Date, timeZone: TimeZone) -> MemberProfileMapper.Rail`, `chart(_: GroupChart?, now: Date, timeZone: TimeZone) -> Chart`.

**Build-time risk notes carried by this task.**
- **F1/F9 — design drift.** d2m marks groups-detail `updateNeeded` (its Figma ref was re-added after the spec). The baseline this SPEC was written against (2026-10-27): `changedSinceSpec` holds exactly ONE entry, `{nodeId: "3766:11160", why: "added"}`, `pendingUpdateCards` 0, `markdownChangedSinceSpec` false. Anything beyond that is drift — STOP and report it for `/builder:revise` before mapping (Step 1).
- **F8 — accent tone.** The mapper sends `eventTones` "accent" for highlighted rows (D16); C-065's built `Tone` predates `accent`, so `GroupsDetailScreen.tone(_:)` renders those rows plain until `/d2m:component:build C-065` — expected, not a defect of this task.

- [ ] **Step 1: Run the d2m drift check for groups-detail (F1/F9)** — from the repo root:

```bash
curl -sf http://localhost:5961/api/projects/makeready/eras/2.0/screens/groups-detail | python3 -c '
import json, sys
d = json.load(sys.stdin)
extra = [c for c in (d.get("changedSinceSpec") or []) if not (c.get("nodeId") == "3766:11160" and c.get("why") == "added")]
print({"updateNeeded": d.get("updateNeeded"), "pendingUpdateCards": d.get("pendingUpdateCards"),
       "markdownChangedSinceSpec": d.get("markdownChangedSinceSpec"), "extraChanges": extra})
sys.exit(1 if extra or d.get("pendingUpdateCards") or d.get("markdownChangedSinceSpec") else 0)'
```

Expected: exit 0, `extraChanges: []`. Exit 1 → STOP this task and report the printed dict (the drifted section goes through `/builder:revise`). `curl` failing (d2m on :5961 not running) → do not guess: continue, and put "F1 drift check NOT RUN — d2m down" under concerns in your report so the reviewer sees it.

- [ ] **Step 2: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupDetailMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse D4, D5, D12, D13/D21, D16–D18: the group page from the group stores.
final class GroupDetailMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!    // Sun Oct 25, 12:00 local

    private func iso(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func group(ageRange: AgeRange? = nil, maxMembers: Int? = nil, isPrivate: Bool = false,
                       access: String? = "ALLOWED", memberDirectory: Bool = true) -> UserGroup {
        UserGroup(id: "g1", code: "ABC123", name: "Young Professionals", description: "Weeknights downtown",
                  coverImageUrl: "https://img/g1.jpg", isPrivate: isPrivate, allowInvites: true,
                  memberDirectory: memberDirectory, ageRange: ageRange, maxMembers: maxMembers, memberCount: 2,
                  creatorId: "u1", creatorName: "Luke Keith", memberDirectoryAccess: access,
                  createdAt: iso("2025-01-15T10:30:00Z"), updatedAt: iso("2025-01-15T10:30:00Z"))
    }

    private func output(_ input: GroupDetailMapper.Input) -> GroupDetailMapper.Output {
        GroupDetailMapper.output(input, now: now, timeZone: tz)
    }

    // MARK: - D5 stats + settings

    func testCoreFieldsAndStats() {
        let s = output(.init(name: "Pushed", group: group())).state
        XCTAssertEqual(s.groupName, "Young Professionals")
        XCTAssertEqual(s.coverURL, "https://img/g1.jpg")
        XCTAssertEqual(s.leaderName, "Luke Keith")                       // D5: creatorName, full
        XCTAssertEqual(s.createdLabel, "Jan 15, 2025")
        XCTAssertEqual(s.groupDescription, "Weeknights downtown")
        XCTAssertEqual(s.visibility, "Public")
        XCTAssertEqual(s.ageRange, "Any age")
        XCTAssertEqual(s.maximumMembers, "Unlimited")
        XCTAssertEqual(s.memberDirectoryAccess, "Allowed")
    }

    /// D4: the push renders at once under the row's name; every section empty until it loads.
    func testUnloadedGroupKeepsThePushedNameAndEmptySections() {
        let s = output(.init(name: "Prayer Team")).state
        XCTAssertEqual(s.groupName, "Prayer Team")
        XCTAssertEqual([s.leaderName, s.createdLabel, s.visibility, s.ageRange, s.maximumMembers, s.memberDirectoryAccess],
                       ["", "", "", "", "", ""])
        XCTAssertEqual(s.lessonTitles, [])
        XCTAssertEqual(s.memberNames, [])
        XCTAssertEqual(s.requestNames, [])
        XCTAssertEqual(s.programTitles, [])
        XCTAssertEqual(s.eventTexts, [])
        XCTAssertEqual(s.chartDates, [])                                 // C-026's empty state
        XCTAssertEqual(s.dayNumbers.count, 30)                           // C-071 `Nothing` cards
    }

    func testEveryAgeForm() {
        XCTAssertEqual(GroupDetailMapper.ageLabel(nil), "Any age")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: nil, max: nil)), "Any age")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: 18, max: 30)), "18 - 30")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: 18, max: nil)), "18+")
        XCTAssertEqual(GroupDetailMapper.ageLabel(AgeRange(min: nil, max: 30)), "Up to 30")
    }

    func testVisibilityAndMaxMembers() {
        XCTAssertEqual(GroupDetailMapper.visibilityLabel(true), "Private")
        XCTAssertEqual(GroupDetailMapper.visibilityLabel(false), "Public")
        XCTAssertEqual(GroupDetailMapper.maxMembersLabel(nil), "Unlimited")
        XCTAssertEqual(GroupDetailMapper.maxMembersLabel(50), "50")
        XCTAssertEqual(output(.init(name: "x", group: group(isPrivate: true))).state.visibility, "Private")
    }

    /// D5/D11: the three-state enum; an old server (nil) or an unknown value falls back to the Boolean.
    func testDirectoryAccessLabels() {
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("ALLOWED", memberDirectory: false), "Allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("NAMES_ONLY", memberDirectory: true), "Names only")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("NOT_ALLOWED", memberDirectory: true), "Not allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel(nil, memberDirectory: true), "Allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel(nil, memberDirectory: false), "Not allowed")
        XCTAssertEqual(GroupDetailMapper.directoryAccessLabel("SOMETHING_NEW", memberDirectory: false), "Not allowed")
    }

    // MARK: - D12 rail

    func testRailIsThirtyDaysWithTodayTrailing() {
        let r = GroupDetailMapper.rail(days: nil, chart: nil, now: now, timeZone: tz)
        XCTAssertEqual(r.numbers.count, 30)
        XCTAssertEqual(r.numbers.first, "26")
        XCTAssertEqual(r.months.first, "SEP")
        XCTAssertEqual(r.weekdays.first, "SAT")                          // Sep 26 2026
        XCTAssertEqual(r.weekdays.last, "")                              // today shows no weekday
        XCTAssertEqual(r.dateStates.last, "today")
        XCTAssertEqual(r.dateStates.first, "default")
        XCTAssertEqual(Set(r.line1s), ["0 lessons"])
        XCTAssertEqual(Set(r.line2s), [""])
        XCTAssertEqual(Set(r.detailsStates), ["nothing"])
        XCTAssertEqual(r.series.first, Array(repeating: 0, count: 12))
    }

    func testRailLinesFromTheChartAndSeriesFromSessions() {
        let chart = GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2], completed: ["2026-10-25": 1, "2026-10-24": 2])
        let days = [HomeDay(day: "2026-10-23", sessionSeconds: 600, blocks: [0, 0, 0, 0, 600, 0, 0, 0, 0, 0, 0, 0])]
        let r = GroupDetailMapper.rail(days: days, chart: chart, now: now, timeZone: tz)
        XCTAssertEqual([r.line1s[29], r.line2s[29], r.detailsStates[29]], ["3 lessons", "2 left", "default"])     // today
        XCTAssertEqual([r.line1s[28], r.line2s[28], r.detailsStates[28]], ["2 lessons", "2 complete", "default"])
        XCTAssertEqual([r.line1s[27], r.line2s[27], r.detailsStates[27]], ["0 lessons", "", "default"])           // sessions only
        XCTAssertEqual(r.series[27], [0, 0, 0, 0, 10, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(r.detailsStates[26], "nothing")
    }

    /// D12: today says "«N−C» left" while lessons remain, else "«C» complete"; no lessons → empty.
    func testLine2Rules() {
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 3, completed: 1, isToday: true), "2 left")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 2, completed: 2, isToday: true), "2 complete")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 3, completed: 1, isToday: false), "1 complete")
        XCTAssertEqual(GroupDetailMapper.line2(scheduled: 0, completed: 0, isToday: true), "")
    }

    // MARK: - D13/D21 chart

    func testChartZeroFillsTheLoadedRangeAndOpensOnTheDesignedWindow() {
        let chart = GroupChart(scheduled: ["2026-10-25": 3, "2026-10-24": 2], completed: ["2026-10-25": 1])
        let c = GroupDetailMapper.chart(chart, now: now, timeZone: tz)
        XCTAssertEqual(c.dates.count, 33)                                // today−29 … today+3
        XCTAssertEqual(c.dates.first, "2026-09-26")
        XCTAssertEqual(c.dates.last, "2026-10-28")
        XCTAssertEqual(c.today, "2026-10-25")
        XCTAssertEqual(c.windowStart, "2026-10-02")                      // today−23
        XCTAssertEqual(c.windowEnd, "2026-10-28")                        // today+3
        let todayIndex = c.dates.firstIndex(of: "2026-10-25")!
        XCTAssertEqual(c.scheduled[todayIndex], 3)
        XCTAssertEqual(c.completed[todayIndex], 1)
        XCTAssertEqual(c.scheduled.reduce(0, +), 5)
        XCTAssertEqual(c.completed[todayIndex + 1], 0)
    }

    func testUnloadedChartIsEmpty() {
        let c = GroupDetailMapper.chart(nil, now: now, timeZone: tz)
        XCTAssertEqual(c.dates, [])
        XCTAssertEqual(c.today, "2026-10-25")
    }

    // MARK: - D16 dates

    func testDateLabels() {
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T17:30:00Z"), now: now, timeZone: tz), "Just now")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T15:00:00Z"), now: now, timeZone: tz), "Today")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-24T20:00:00Z"), now: now, timeZone: tz), "Yesterday")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-10-25T05:00:00Z"), now: now, timeZone: tz), "Yesterday")  // Oct 24, 23:00 local
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2026-03-04T12:00:00Z"), now: now, timeZone: tz), "Mar 4")
        XCTAssertEqual(GroupDetailMapper.dateLabel(iso("2025-12-31T12:00:00Z"), now: now, timeZone: tz), "Dec 31, 2025")
    }

    // MARK: - D17 next lesson

    /// D17: the scheduled date's UTC calendar date against the phone's local today.
    func testLessonMetaLabels() {
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-25T00:00:00.000Z", now: now, timeZone: tz), "Today")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-26T00:00:00.000Z", now: now, timeZone: tz), "Tomorrow")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-29T00:00:00.000Z", now: now, timeZone: tz), "Thursday")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-10-31T00:00:00.000Z", now: now, timeZone: tz), "Saturday")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("2026-11-01T00:00:00.000Z", now: now, timeZone: tz), "Nov 1")
        XCTAssertEqual(GroupDetailMapper.lessonMeta("not a date", now: now, timeZone: tz), "")
    }

    func testNextLessonCard() {
        let activities = [
            NextStudyActivity(id: "a1", type: "VIDEO", orderNumber: 1, title: "Watch", thumbnailUrl: "https://img/a1.jpg"),
            NextStudyActivity(id: "a2", type: "READ", orderNumber: 2, title: "Read", thumbnailUrl: nil),
            NextStudyActivity(id: "a3", type: "READ", orderNumber: 3, title: nil, thumbnailUrl: "https://img/a3.jpg"),
            NextStudyActivity(id: "a4", type: "VIDEO", orderNumber: 4, title: "Fourth", thumbnailUrl: "https://img/a4.jpg")
        ]
        var study = NextStudy(id: "s1", dayNumber: 3, scheduledDate: "2026-10-26T00:00:00.000Z", title: nil,
                              studyProgram: NextStudyProgram(id: "p1", name: "Faith over fear"), activities: activities)
        var s = output(.init(name: "x", nextStudy: study)).state
        XCTAssertEqual(s.lessonTitles, ["Day 3"])
        XCTAssertEqual(s.lessonProgramNames, ["Faith over fear"])
        XCTAssertEqual(s.lessonMetaLabels, ["Tomorrow"])
        XCTAssertEqual(s.lessonSlideImages, [["https://img/a1.jpg", "", "https://img/a3.jpg"]])
        XCTAssertEqual(s.lessonSlideLabels, [["Watch", "Read", ""]])
        study.title = "Week one"
        s = output(.init(name: "x", nextStudy: study)).state
        XCTAssertEqual(s.lessonTitles, ["Week one"])
    }

    // MARK: - D18 members, requests, enrollments

    func testMembersNewestFirstWithJoinedLabels() {
        let ann = GroupMember(id: "gm1", userId: "u-a", groupId: "g1", role: .member, name: "Ann Lee", avatarUrl: nil,
                              joinedAt: iso("2026-10-20T15:00:00Z"))
        let bob = GroupMember(id: "gm2", userId: "u-b", groupId: "g1", role: .member, name: "Bob Ray",
                              avatarUrl: "https://img/b.jpg", joinedAt: iso("2026-10-25T15:00:00Z"))
        let out = output(.init(name: "x", members: [ann, bob]))
        XCTAssertEqual(out.state.memberNames, ["Bob Ray", "Ann Lee"])
        XCTAssertEqual(out.state.memberJoinedLabels, ["Joined Today", "Joined 5 days ago"])
        XCTAssertEqual(out.state.memberPhotoURLs, ["https://img/b.jpg", ""])
        XCTAssertEqual(out.member(atRow: 0), GroupDetailMapper.MemberRow(id: "u-b", name: "Bob Ray"))   // D7: userId
        XCTAssertNil(out.member(atRow: 5))
    }

    func testRequestsNameOrUnknownAndDateAndAreNotMembers() {
        let tony = JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: iso("2026-10-24T20:00:00Z"),
                               member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: "Stark", avatarUrl: nil))
        let nameless = JoinRequest(id: "r2", status: "PENDING", message: nil, createdAt: iso("2026-03-04T12:00:00Z"),
                                   member: JoinRequestMember(id: "m2", firstName: nil, lastName: nil, avatarUrl: nil))
        let s = output(.init(name: "x", requests: [tony, nameless])).state
        XCTAssertEqual(s.requestNames, ["Tony Stark", "Unknown"])
        XCTAssertEqual(s.requestDates, ["Yesterday", "Mar 4"])
        XCTAssertEqual(s.memberNames, [])                                // not counted in "«N» members"
    }

    func testEnrollmentsNewestFirst() throws {
        let json = #"""
        [{"id":"e1","groupId":"g1","programId":"p1","startedAt":"2026-09-01T00:00:00Z","createdAt":"2026-09-01T15:00:00Z",
          "studyProgram":{"id":"p1","title":"Faith over fear","description":"30 days","coverImageUrl":"https://img/p1.jpg"}},
         {"id":"e2","groupId":"g1","programId":"p2","startedAt":"2026-10-01T00:00:00Z","createdAt":"2026-10-01T15:00:00Z",
          "studyProgram":{"id":"p2","title":"Daily Inspiration"}}]
        """#
        let enrollments = try JSONDecoder.apiDecoder.decode([EnrollmentWithProgram].self, from: Data(json.utf8))
        let s = output(.init(name: "x", enrollments: enrollments)).state
        XCTAssertEqual(s.programTitles, ["Daily Inspiration", "Faith over fear"])
        XCTAssertEqual(s.programDescriptions, ["", "30 days"])
        XCTAssertEqual(s.programEnrolledDates, ["Oct 1, 2026", "Sep 1, 2026"])
        XCTAssertEqual(s.programCoverURLs, ["", "https://img/p1.jpg"])
    }

    // MARK: - D16 timeline

    func testTimelineTextsHighlightsAndTones() {
        let events = [
            GroupHistoryEvent(id: "h1", occurredAt: "2026-10-25T17:30:00.000Z", kind: "member_joined",
                              text: "Tony Stark joined the group", highlight: "Tony Stark"),
            GroupHistoryEvent(id: "h2", occurredAt: "2025-12-31T12:00:00.000Z", kind: "settings_updated",
                              text: "Updated group settings", highlight: nil)
        ]
        let s = output(.init(name: "x", history: events)).state
        XCTAssertEqual(s.eventDates, ["Just now", "Dec 31, 2025"])
        XCTAssertEqual(s.eventTexts, ["Tony Stark joined the group", "Updated group settings"])
        XCTAssertEqual(s.eventHighlights, ["Tony Stark", ""])
        XCTAssertEqual(s.eventTones, ["accent", "neutral"])              // F8: renders plain until C-065 rebuild
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupDetailMapperTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "cannot find 'GroupDetailMapper' in scope".

- [ ] **Step 4: Write the minimal implementation** — create `iphone/MakeReady/UI2/Containers/Groups/GroupDetailMapper.swift`:

```swift
import Foundation

/// ui2-groups-browse D4, D5, D12, D13/D21, D16–D18 + groups-detail §2–§3: one group's page from
/// the group stores. Pure. A store never loaded keeps its section empty (D4) — the screen draws
/// each section's empty line; the stats count the lists themselves (the screen's R-30).
enum GroupDetailMapper {
    private static let weekdaysShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let weekdaysLong = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current
    /// D13: the chart opens on today−23 … today+3 (today 4th from the end).
    static let chartBackDays = 23

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    struct Input {
        /// The pushing row's name — the header while the group loads (D4).
        var name: String
        var group: UserGroup? = nil
        var members: [GroupMember] = []
        var requests: [JoinRequest] = []
        var enrollments: [EnrollmentWithProgram] = []
        var nextStudy: NextStudy? = nil
        var history: [GroupHistoryEvent] = []
        var days: [HomeDay]? = nil
        var chart: GroupChart? = nil
    }

    /// D7: a member row opens the MEMBER (`GroupMember.userId`), not the membership row.
    struct MemberRow: Equatable {
        let id: String
        let name: String
    }

    struct Output {
        var state: GroupsDetailScreen.State
        var memberRows: [MemberRow]

        func member(atRow row: Int) -> MemberRow? {
            memberRows.indices.contains(row) ? memberRows[row] : nil
        }
    }

    struct Chart: Equatable {
        var dates: [String] = []
        var scheduled: [Int] = []
        var completed: [Int] = []
        var windowStart: String = ""
        var windowEnd: String = ""
        var today: String = ""
    }

    static func output(_ input: Input, now: Date, timeZone: TimeZone) -> Output {
        let g = input.group
        // D18: newest member first (the AppState index is a Set and loses the server's order).
        let members = input.members.sorted { lhs, rhs in
            lhs.joinedAt != rhs.joinedAt ? lhs.joinedAt > rhs.joinedAt : lhs.name < rhs.name
        }
        let enrollments = input.enrollments.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        let rail = rail(days: input.days, chart: input.chart, now: now, timeZone: timeZone)
        let chart = chart(input.chart, now: now, timeZone: timeZone)
        let study = input.nextStudy
        let slides = Array((study?.activities ?? []).prefix(3))          // D17: the first 3
        let state = GroupsDetailScreen.State(
            groupName: MembersHomeMapper.nonEmpty(g?.name) ?? input.name,
            coverURL: g?.coverImageUrl ?? "",
            leaderName: g?.creatorName ?? "",
            createdLabel: g.map { MembersHomeMapper.mediumDate($0.createdAt, timeZone: timeZone) } ?? "",
            groupDescription: g?.description ?? "",
            visibility: g.map { visibilityLabel($0.isPrivate) } ?? "",
            ageRange: g.map { ageLabel($0.ageRange) } ?? "",
            maximumMembers: g.map { maxMembersLabel($0.maxMembers) } ?? "",
            memberDirectoryAccess: g.map { directoryAccessLabel($0.memberDirectoryAccess, memberDirectory: $0.memberDirectory) } ?? "",
            lessonTitles: study.map { [MembersHomeMapper.nonEmpty($0.title) ?? "Day \($0.dayNumber)"] } ?? [],
            lessonProgramNames: study.map { [$0.studyProgram?.name ?? ""] } ?? [],
            lessonMetaLabels: study.map { [lessonMeta($0.scheduledDate, now: now, timeZone: timeZone)] } ?? [],
            lessonSlideImages: study == nil ? [] : [slides.map { $0.thumbnailUrl ?? "" }],
            lessonSlideLabels: study == nil ? [] : [slides.map { $0.title ?? "" }],
            dayMonths: rail.months,
            dayWeekdays: rail.weekdays,
            dayNumbers: rail.numbers,
            dayDateStates: rail.dateStates,
            daySeries: rail.series,
            dayLine1s: rail.line1s,
            dayLine2s: rail.line2s,
            dayDetailsStates: rail.detailsStates,
            chartDates: chart.dates,
            chartScheduled: chart.scheduled,
            chartCompleted: chart.completed,
            chartWindowStart: chart.windowStart,
            chartWindowEnd: chart.windowEnd,
            chartToday: chart.today,
            memberNames: members.map(\.name),
            memberPhotoURLs: members.map { $0.avatarUrl ?? "" },
            memberJoinedLabels: members.map {
                MembersHomeMapper.joinedLabel(isoFractional.string(from: $0.joinedAt), today: now, timeZone: timeZone)
            },
            requestNames: input.requests.map {
                MembersHomeMapper.nonEmpty(MembersHomeMapper.displayName(first: $0.member.firstName, last: $0.member.lastName)) ?? "Unknown"
            },
            requestDates: input.requests.map { dateLabel($0.createdAt, now: now, timeZone: timeZone) },
            programTitles: enrollments.map { $0.studyProgram?.name ?? "" },
            programDescriptions: enrollments.map { $0.studyProgram?.description ?? "" },
            programEnrolledDates: enrollments.map { e in
                e.createdAt.map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? ""
            },
            programCoverURLs: enrollments.map { $0.studyProgram?.coverImageUrl ?? "" },
            eventDates: input.history.map { event in
                MembersHomeMapper.parseDate(event.occurredAt).map { dateLabel($0, now: now, timeZone: timeZone) } ?? ""
            },
            eventTexts: input.history.map(\.text),
            eventHighlights: input.history.map { $0.highlight ?? "" },
            // D16; F8: C-065's built Tone renders "accent" plain until its rebuild.
            eventTones: input.history.map { $0.highlight == nil ? "neutral" : "accent" }
        )
        return Output(state: state, memberRows: members.map { MemberRow(id: $0.userId, name: $0.name) })
    }

    // MARK: - D5 settings values

    static func ageLabel(_ range: AgeRange?) -> String {
        switch (range?.min, range?.max) {
        case let (min?, max?): return "\(min) - \(max)"
        case let (min?, nil): return "\(min)+"
        case let (nil, max?): return "Up to \(max)"
        case (nil, nil): return "Any age"
        }
    }

    static func visibilityLabel(_ isPrivate: Bool) -> String { isPrivate ? "Private" : "Public" }

    static func maxMembersLabel(_ max: Int?) -> String { max.map { "\($0)" } ?? "Unlimited" }

    /// D5/D11: the enum's three labels; a server without the enum (nil) or a value this build does
    /// not know reads the Boolean the enum was backfilled from.
    static func directoryAccessLabel(_ access: String?, memberDirectory: Bool) -> String {
        switch access {
        case "ALLOWED": return "Allowed"
        case "NAMES_ONLY": return "Names only"
        case "NOT_ALLOWED": return "Not allowed"
        default: return memberDirectory ? "Allowed" : "Not allowed"
        }
    }

    // MARK: - D16 / D17 dates

    /// D16: < 60 min "Just now", today "Today", yesterday "Yesterday", this year "MMM d", else
    /// "MMM d, yyyy" — local calendar days.
    static func dateLabel(_ date: Date, now: Date, timeZone: TimeZone) -> String {
        if now.timeIntervalSince(date) < 3600 { return "Just now" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let age = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        if age == 0 { return "Today" }
        if age == 1 { return "Yesterday" }
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        let short = "\(HomeDashboardMapper.shortMonths[m - 1]) \(d)"
        return y == cal.component(.year, from: now) ? short : "\(short), \(y)"
    }

    /// D17: "Today" / "Tomorrow" / the weekday within 6 days / "MMM d", from `scheduledDate`'s UTC
    /// calendar date against the phone's local today.
    static func lessonMeta(_ scheduledDate: String, now: Date, timeZone: TimeZone) -> String {
        guard let stamp = MembersHomeMapper.parseDate(scheduledDate) else { return "" }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = utc
        var localCal = Calendar(identifier: .gregorian)
        localCal.timeZone = timeZone
        let s = utcCal.dateComponents([.year, .month, .day], from: stamp)
        let t = localCal.dateComponents([.year, .month, .day], from: now)
        guard let month = s.month, let day = s.day,
              let scheduled = utcCal.date(from: DateComponents(year: s.year, month: month, day: day)),
              let today = utcCal.date(from: DateComponents(year: t.year, month: t.month, day: t.day)) else { return "" }
        let offset = utcCal.dateComponents([.day], from: today, to: scheduled).day ?? 0
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return weekdaysLong[utcCal.component(.weekday, from: scheduled) - 1]
        default: return "\(HomeDashboardMapper.shortMonths[month - 1]) \(day)"
        }
    }

    // MARK: - D12 rail

    /// D12: the 30 local days today−29 … today (today trailing). Line 1 = "«N» lessons"
    /// (`scheduled_lessons`), line 2 per `line2`, `nothing` when no lessons and no sessions;
    /// series = the day's 12 two-hour session blocks in minutes. Never loaded → zero days.
    static func rail(days: [HomeDay]?, chart: GroupChart?, now: Date, timeZone: TimeZone) -> MemberProfileMapper.Rail {
        let byDay = Dictionary((days ?? []).map { ($0.day, $0) }, uniquingKeysWith: { $1 })
        let todayKey = HomeDashboardMapper.key(now, tz: timeZone)
        var r = MemberProfileMapper.Rail()
        for day in HomeDashboardMapper.days(endingAt: now, back: GroupActions.railDays - 1, ahead: 0, tz: timeZone) {
            let isToday = day.key == todayKey
            let scheduled = chart?.scheduled[day.key] ?? 0
            let completed = chart?.completed[day.key] ?? 0
            let seconds = byDay[day.key]?.sessionSeconds ?? 0
            r.months.append(HomeDashboardMapper.shortMonths[day.month - 1].uppercased())
            r.weekdays.append(isToday ? "" : weekdaysShort[day.weekday - 1])
            r.numbers.append("\(day.day)")
            r.dateStates.append(isToday ? "today" : "default")
            r.series.append(HomeDashboardMapper.blockMinutes(byDay[day.key]?.blocks))
            r.line1s.append("\(scheduled) lessons")
            r.line2s.append(line2(scheduled: scheduled, completed: completed, isToday: isToday))
            r.detailsStates.append(scheduled == 0 && seconds == 0 ? "nothing" : "default")
        }
        return r
    }

    /// D12: "«C» complete"; today "«N−C» left" while N > C; empty when N = 0.
    static func line2(scheduled: Int, completed: Int, isToday: Bool) -> String {
        guard scheduled > 0 else { return "" }
        if isToday && scheduled > completed { return "\(scheduled - completed) left" }
        return "\(completed) complete"
    }

    // MARK: - D13/D21 chart

    /// D13/D21: every day of the loaded range today−29 … today+3, zero-filled; the window opens on
    /// today−23 … today+3. Never loaded → no days (C-026's empty state).
    static func chart(_ chart: GroupChart?, now: Date, timeZone: TimeZone) -> Chart {
        let todayKey = HomeDashboardMapper.key(now, tz: timeZone)
        guard let chart else { return Chart(today: todayKey) }
        let keys = HomeDashboardMapper.days(endingAt: now, back: GroupActions.railDays - 1,
                                            ahead: GroupActions.chartAheadDays, tz: timeZone).map(\.key)
        let window = HomeDashboardMapper.days(endingAt: now, back: chartBackDays,
                                              ahead: GroupActions.chartAheadDays, tz: timeZone)
        return Chart(
            dates: keys,
            scheduled: keys.map { chart.scheduled[$0] ?? 0 },
            completed: keys.map { chart.completed[$0] ?? 0 },
            windowStart: window.first?.key ?? todayKey,
            windowEnd: window.last?.key ?? todayKey,
            today: todayKey
        )
    }
}
```

Register it and sync the capture target (repo root):

```bash
ruby - "app:MakeReady/UI2:Containers/Groups/GroupDetailMapper.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check   # → exit 0
```

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupDetailMapperTests` 17/17. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (the formatter is `static`).

- [ ] **Step 6: Commit** — `git add iphone/MakeReady/UI2/Containers/Groups/GroupDetailMapper.swift iphone/MakeReadyCaptureTests/GroupDetailMapperTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): group page mapper — stats, settings, rail, chart, lesson, members, timeline"`

### Task 15: GroupDetailContainer + GroupDetailHost
App: iphone
Phase: 6
Recipe: /ios-error-surface (D4: every section load is background → console-only; D23: a 404 is scope, no banner; 401 → sign-out)

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift`
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailHost.swift`
- Test: `iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Ruby step + `capture-targets.rb`)

**Interfaces:**
- Consumes: Task 9 stores; Task 10 `GroupActions(onUnauthorized:)` + `loadNextStudy / loadHistory / loadGroupDays / loadGroupChart`, `GroupActions.isCancellation(_:)`; Task 11 `GroupsDetailScreen(state:showsHeader:…onInviteMember:onOpenMember:…)`; Task 14 `GroupDetailMapper.Input`, `.output(_:now:timeZone:)`, `Output.member(atRow:)`; existing `GroupActions.getGroup(id:)`, `loadMembers(groupId:)`, `loadJoinRequests(groupId:)`, `EnrollmentActions().loadEnrollments(groupId:)`, `AppState.membersFor(groupId:)`, `enrollmentsFor(groupId:)`, `pendingJoinRequestsByGroupId`, `MemberProfileContainer.seedCovers(_:)` / `cachedCoverURLs(_:)` (statics, reused), `PageHeader`, `UI2Destination.memberDetail(id:name:)`, `.inviteMember(groupId:returnDepth:)`, `UI2Navigator.push / pop / depth`.
- Produces:
  - `struct GroupDetailHost: View { init(id: String, name: String) }` — the D1 host Task 16 maps `.groupDetail` to.
  - `struct GroupDetailContainer: View { init(groupId: String, name: String) }`
  - `@MainActor static func GroupDetailContainer.input(groupId: String, name: String, state: AppState) -> GroupDetailMapper.Input`
  - `static func GroupDetailContainer.imageURLs(_ state: GroupsDetailScreen.State) -> [String]`
  - `@MainActor static func GroupDetailContainer.attempt(_ context: String, state: AppState? = nil, onUnauthorized: @MainActor () async -> Void, _ work: @MainActor () async throws -> Void) async`
  - `@MainActor static func GroupDetailContainer.load(groupId: String, authManager: AuthManager) async`

**Exits (D6/D7).** Wired: C-040 back → `navigator.pop()`; a member row → `.memberDetail(id: GroupMember.userId, name)`; Members `add` → `.inviteMember(groupId:, returnDepth: navigator.depth())`; "Jump to today" is the screen's own. Inert (screen defaults, no closure passed): the six C-042 rows, Delete Group, join-request rows, enrollment rows, the LessonCard, Enrollments `add`, Timeline "All history", chart pan.

- [ ] **Step 1: Write the failing test** — create `iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-browse D4/D17/D23: the group page's loads, error routing and image seeding inputs.
@MainActor
final class GroupDetailContainerTests: XCTestCase {
    private var state: AppState!

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    func testUnauthorizedSignsOutAndRecordsNothing() async {
        var signedOut = false
        await GroupDetailContainer.attempt("getGroup", state: state, onUnauthorized: { signedOut = true }) {
            throw APIError.unauthorized
        }
        XCTAssertTrue(signedOut)
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D4/D23: a failed or out-of-scope load is recorded console-only — never a banner.
    func testFailedOrOutOfScopeLoadIsConsoleOnly() async {
        await GroupDetailContainer.attempt("getGroup", state: state, onUnauthorized: {}) {
            throw APIError.serverError("Group not found")
        }
        XCTAssertEqual(state.errors.last?.context, "GroupDetailContainer.getGroup")
        XCTAssertEqual(state.errors.last?.surface, false)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testCancelledLoadIsSilent() async {
        await GroupDetailContainer.attempt("loadMembers", state: state, onUnauthorized: {}) {
            throw APIError.networkError(URLError(.cancelled))
        }
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// D17: the container seeds the cover, the slide images and the enrollment covers.
    func testImageURLsAreTheCoverSlidesAndProgramCovers() {
        var s = GroupsDetailScreen.State.populated
        s.coverURL = "https://img/c.jpg"
        s.lessonSlideImages = [["https://img/1.jpg", ""]]
        s.programCoverURLs = ["", "https://img/p.jpg"]
        XCTAssertEqual(GroupDetailContainer.imageURLs(s), ["https://img/c.jpg", "https://img/1.jpg", "https://img/p.jpg"])
    }

    /// D4: the page reads every group store for its id.
    func testInputReadsEveryGroupStore() {
        let stamp = Date()
        state.groups.upsert(UserGroup(id: "g1", code: "C1", name: "Young Pros", isPrivate: false, allowInvites: true,
                                      memberCount: 0, creatorId: "u1", createdAt: stamp, updatedAt: stamp))
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25")]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 1])
        state.pendingJoinRequestsByGroupId["g1"] = [
            JoinRequest(id: "r1", status: "PENDING", message: nil, createdAt: stamp,
                        member: JoinRequestMember(id: "m1", firstName: "Tony", lastName: nil, avatarUrl: nil))
        ]
        let input = GroupDetailContainer.input(groupId: "g1", name: "Pushed", state: state)
        XCTAssertEqual(input.name, "Pushed")
        XCTAssertEqual(input.group?.name, "Young Pros")
        XCTAssertEqual(input.nextStudy?.id, "s1")
        XCTAssertEqual(input.history.map(\.id), ["h1"])
        XCTAssertEqual(input.days?.count, 1)
        XCTAssertEqual(input.chart?.scheduled["2026-10-25"], 1)
        XCTAssertEqual(input.requests.map(\.id), ["r1"])
        XCTAssertNil(GroupDetailContainer.input(groupId: "g2", name: "Other", state: state).group)
    }
}
```

Register it (repo root):

```bash
ruby - "test:MakeReadyCaptureTests:GroupDetailContainerTests.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "cannot find 'GroupDetailContainer' in scope".

- [ ] **Step 3: Write the minimal implementation**

Create `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift`:

```swift
import SwiftUI

/// ui2-groups-browse §iphone Group page: the pushed `.groupDetail` page (D1, D4). It owns its
/// ScrollView and pins C-040 above it (D27: the screen's `showsHeader: false`, the
/// MemberProfileContainer precedent). Cache-first: the stores render at once under the pushed
/// name, and eight loads run in parallel; a failure keeps what is shown (D4) and a group outside
/// the caller's scope just stays empty (D23).
struct GroupDetailContainer: View {
    let groupId: String
    let name: String

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe (D17).
    @State private var imagesSeeded = 0

    var body: some View {
        let output = GroupDetailMapper.output(Self.input(groupId: groupId, name: name, state: AppState.shared),
                                              now: Date(), timeZone: .current)
        let _ = imagesSeeded
        // D17: the screen reads images only from Ui2ImageCache, so an image reaches it once cached
        // and its arrival changes the screen's input.
        let state = Self.cachedImages(output.state)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: state.groupName,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }       // groups-detail §3: back pops to the pusher
            )
            ScrollView(.vertical) {
                GroupsDetailScreen(
                    state: state,
                    showsHeader: false,
                    // D7: Members `add` → invite; Cancel/Done return here.
                    onInviteMember: { navigator.push(.inviteMember(groupId: groupId, returnDepth: navigator.depth())) },
                    // D7: a member row → the member page (GroupMember.userId). D6: everything else inert.
                    onOpenMember: { row in
                        guard let member = output.member(atRow: row) else { return }
                        navigator.push(.memberDetail(id: member.id, name: member.name))
                    }
                )
            }
            .scrollIndicators(.hidden)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await Self.load(groupId: groupId, authManager: authManager) }
        .task(id: Self.imageURLs(output.state)) {
            if await MemberProfileContainer.seedCovers(Self.imageURLs(output.state)) { imagesSeeded += 1 }
        }
    }

    /// D4: every group store, read for this group.
    @MainActor
    static func input(groupId: String, name: String, state app: AppState) -> GroupDetailMapper.Input {
        GroupDetailMapper.Input(
            name: name,
            group: app.groups[groupId],
            members: app.membersFor(groupId: groupId),
            requests: app.pendingJoinRequestsByGroupId[groupId] ?? [],
            enrollments: app.enrollmentsFor(groupId: groupId),
            nextStudy: app.nextStudyByGroupId[groupId],
            history: app.historyByGroupId[groupId] ?? [],
            days: app.groupDaysByGroupId[groupId],
            chart: app.groupChartByGroupId[groupId]
        )
    }

    /// D17: the images the container seeds — the cover, the lesson slides, the enrollment covers.
    static func imageURLs(_ state: GroupsDetailScreen.State) -> [String] {
        ([state.coverURL] + state.lessonSlideImages.flatMap { $0 } + state.programCoverURLs).filter { !$0.isEmpty }
    }

    /// Each image URL already in Ui2ImageCache, else "" (the component's empty look until it lands).
    @MainActor
    static func cachedImages(_ mapped: GroupsDetailScreen.State) -> GroupsDetailScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        s.programCoverURLs = MemberProfileContainer.cachedCoverURLs(mapped.programCoverURLs)
        return s
    }

    /// D4: the eight section loads, all at once.
    @MainActor
    static func load(groupId: String, authManager: AuthManager) async {
        let onUnauthorized: @MainActor () async -> Void = { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "GroupDetailContainer.signOut", surface: false)
            }
        }
        let groups = GroupActions(onUnauthorized: onUnauthorized)
        async let group: () = attempt("getGroup", onUnauthorized: onUnauthorized) { _ = try await groups.getGroup(id: groupId) }
        async let members: () = attempt("loadMembers", onUnauthorized: onUnauthorized) { _ = try await groups.loadMembers(groupId: groupId) }
        async let requests: () = attempt("loadJoinRequests", onUnauthorized: onUnauthorized) { try await groups.loadJoinRequests(groupId: groupId) }
        async let enrollments: () = attempt("loadEnrollments", onUnauthorized: onUnauthorized) {
            _ = try await EnrollmentActions().loadEnrollments(groupId: groupId)
        }
        async let next: () = groups.loadNextStudy(groupId: groupId)
        async let history: () = groups.loadHistory(groupId: groupId)
        async let days: () = groups.loadGroupDays(groupId: groupId)
        async let chart: () = groups.loadGroupChart(groupId: groupId)
        _ = await (group, members, requests, enrollments, next, history, days, chart)
    }

    /// D4/D23 for the four throwing loaders: cancelled → nothing; 401 → sign-out; anything else —
    /// a 404 outside the caller's scope included — console-only, so the page keeps what it shows.
    @MainActor
    static func attempt(_ context: String, state: AppState? = nil, onUnauthorized: @MainActor () async -> Void,
                        _ work: @MainActor () async throws -> Void) async {
        do {
            try await work()
        } catch {
            if GroupActions.isCancellation(error) { return }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                await onUnauthorized()
                return
            }
            (state ?? .shared).recordError(error, context: "GroupDetailContainer.\(context)", surface: false)
        }
    }
}
```

Create `iphone/MakeReady/UI2/Containers/Groups/GroupDetailHost.swift`:

```swift
import SwiftUI

/// ui2-groups-browse D1: the `.groupDetail` destination of the shell's stacks — the group page.
struct GroupDetailHost: View {
    let id: String
    let name: String

    var body: some View {
        GroupDetailContainer(groupId: id, name: name)
    }
}
```

Register both and sync the capture target (repo root):

```bash
ruby - "app:MakeReady/UI2:Containers/Groups/GroupDetailContainer.swift" "app:MakeReady/UI2:Containers/Groups/GroupDetailHost.swift" <<'RUBY'
require "xcodeproj"
proj = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
targets = { "app" => "MakeReady", "test" => "MakeReadyCaptureTests" }
ARGV.each do |spec|
  kind, group_path, file = spec.split(":")
  group = proj.main_group.find_subpath(group_path, false) or abort("no group #{group_path}")
  next puts("already referenced: #{file}") if group.files.any? { |f| f.path == file }
  ref = group.new_reference(file)
  proj.targets.find { |t| t.name == targets.fetch(kind) }.add_file_references([ref])
  puts "added #{kind} #{group_path}/#{file}"
end
proj.save
RUBY
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check   # → exit 0
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`, `GroupDetailContainerTests` 5/5. `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations. Run `/transition-review` on the diff (a pushed page with a pinned header, no custom animation) → PASS.

- [ ] **Step 5: Commit** — `git add iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift iphone/MakeReady/UI2/Containers/Groups/GroupDetailHost.swift iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift iphone/MakeReady.xcodeproj/project.pbxproj && git commit -m "feat(ui2-groups-browse): group page container — parallel loads, pinned header, image seeding, exits"`

### Task 16: shell wiring + members-profile group row + residual sweep
App: iphone
Phase: 6
Recipe: /nav-route (typed destinations; the shell's `UI2Destination` switch stays exhaustive)

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:14-26` (`UI2Destination` cases) + add `refreshableSection`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:139-167` (`page(for:)`, `refreshAction`, `sectionContent`)
- Modify: `iphone/MakeReady/UI2/Shell/TopNavHost.swift:96-99` (`onAdd`)
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift:36-48` (group row → group page)
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (append)

**Interfaces:**
- Consumes: Task 12 `GroupsHomeContainer(destination:)` + `GroupsHomeContainer.refresh(authManager:)`; Task 13 `UI2ShellModel.replaceTop(_:with:on:)`, `CreateGroupContainer(route:destination:)`; Task 15 `GroupDetailHost(id:name:)`; existing `MembersProfileScreen(…onOpenGroup:)`, `AppState.memberGroupsById`, `MemberGroupItem`.
- Produces:
  - `UI2Destination.groupDetail(id: String, name: String)` and `UI2Destination.createGroup` (D1)
  - `UI2ShellModel.refreshableSection: UI2Section?` — `.home` / `.groups` on the Home tab, else nil
  - `static func MemberProfileContainer.groupDestination(_ groups: [MemberGroupItem]?, row: Int) -> UI2Destination?`

- [ ] **Step 1: Write the failing test** — append inside `final class UI2ShellModelTests` in `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`:

```swift

    // MARK: - ui2-groups-browse D1/D3/D7/D8: the group routes

    private let walkGroup = UI2Destination.groupDetail(id: "g9", name: "Walk Test Group")

    /// D1: the group page is keyed by id and name, and pushes on the Home stack like any page.
    func testGroupDetailPushesOnTheHomeStack() {
        var m = UI2ShellModel()
        m.apply(.section(.groups))
        m.push(walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [walkGroup])
        XCTAssertNotEqual(walkGroup, .groupDetail(id: "g8", name: "Walk Test Group"))
        m.push(.memberDetail(id: "m1", name: "Tony Stark"), on: .home)   // D7: member row
        XCTAssertEqual(m.path(for: .home).count, 2)
    }

    /// D8: TopNav `+` pushes the form; success replaces it with the new group's page; back → Groups.
    func testCreateGroupIsReplacedByTheNewGroupsPage() {
        var m = UI2ShellModel()
        m.apply(.section(.groups))
        m.push(.createGroup, on: .home)
        m.replaceTop(.createGroup, with: walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [walkGroup])
        m.pop(on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        XCTAssertEqual(m.section, .groups)
    }

    /// D8: swiped back mid-create → the success writes nothing.
    func testCreateSwipedBackMidCreateWritesNothing() {
        var m = UI2ShellModel()
        m.push(.createGroup, on: .home)
        m.setPath([], for: .home)
        m.replaceTop(.createGroup, with: walkGroup, on: .home)
        XCTAssertEqual(m.path(for: .home), [])
    }

    /// D3 + home-dashboard-data D24: pull-to-refresh is wired for Home and Groups only.
    func testRefreshableSectionsAreHomeAndGroups() {
        var m = UI2ShellModel()
        XCTAssertEqual(m.refreshableSection, .home)
        m.apply(.section(.groups))
        XCTAssertEqual(m.refreshableSection, .groups)
        m.apply(.section(.members))
        XCTAssertNil(m.refreshableSection)
        m.apply(.section(.groups))
        m.apply(.tab(.search))
        XCTAssertNil(m.refreshableSection)
    }

    /// D7: a member page's group row opens that group (rows are `memberGroupsById` in order).
    func testMemberPageGroupRowOpensTheGroup() {
        let groups = [MemberGroupItem(id: "g1", name: "Young professionals"), MemberGroupItem(id: "g2", name: "The kids")]
        XCTAssertEqual(MemberProfileContainer.groupDestination(groups, row: 1), .groupDetail(id: "g2", name: "The kids"))
        XCTAssertNil(MemberProfileContainer.groupDestination(groups, row: 2))
        XCTAssertNil(MemberProfileContainer.groupDestination(nil, row: 0))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL, "type 'UI2Destination' has no member 'groupDetail'", "value of type 'UI2ShellModel' has no member 'refreshableSection'", "type 'MemberProfileContainer' has no member 'groupDestination'".

- [ ] **Step 3: Write the minimal implementation**

In `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift`, add to `enum UI2Destination` after `case inviteMember(groupId: String, returnDepth: Int)`:

```swift
    /// ui2-groups-browse D1: one group's page. `name` is the list-known title C-040 shows while
    /// the group loads (D4).
    case groupDetail(id: String, name: String)
    /// ui2-groups-browse D1/D8: the create form, pushed on the Home stack by the Groups `+`;
    /// success replaces it with the new group's `.groupDetail`.
    case createGroup
```

and inside `struct UI2ShellModel`, after `var showsTopNav: Bool { tab == .home }`:

```swift
    /// home-dashboard-data D24 + ui2-groups-browse D3: the section whose pull-to-refresh is
    /// wired — Home and Groups, on the Home tab; nil anywhere else.
    var refreshableSection: UI2Section? {
        guard tab == .home, section == .home || section == .groups else { return nil }
        return section
    }
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift`:

(a) In `page(for:)`, add after the `.inviteMember` case:

```swift
        case let .groupDetail(id, name): GroupDetailHost(id: id, name: name)                 // ui2-groups-browse D1
        case .createGroup:                                                                    // ui2-groups-browse D1/D8
            CreateGroupContainer(route: .createGroup, destination: { .groupDetail(id: $0.id, name: $0.name) })
```

(b) Replace `refreshAction` (doc comment + body) with:

```swift
    /// home-dashboard-data D24 + ui2-groups-browse D3: the pull-to-refresh of the page on screen —
    /// Home's dashboard and the Groups list (the other sections are unwired, D10).
    private var refreshAction: (@MainActor () async -> Void)? {
        switch model.refreshableSection {
        case .home?: return { [authManager] in await HomeDashboardContainer.refresh(authManager: authManager) }
        case .groups?: return { [authManager] in await GroupsHomeContainer.refresh(authManager: authManager) }
        default: return nil
        }
    }
```

(c) In `sectionContent`, add after `case .members: MembersHomeContainer() // ui2-members-browse`:

```swift
        case .groups: GroupsHomeContainer(destination: { .groupDetail(id: $0, name: $1) })  // ui2-groups-browse D1/D3
```

In `iphone/MakeReady/UI2/Shell/TopNavHost.swift`, replace the `onAdd:` argument and its comment with:

```swift
            // The Members `add` opens the invite flow, exactly as the Add menu's row does (owner
            // 2026-10-26); the Groups `add` pushes create-group on the Home stack (ui2-groups-browse
            // D7/D8, OQ-groups-home-2); the other add slots stay no-ops (SPEC D10).
            onAdd: { tab in
                switch UI2Section(rawValue: tab) {
                case .members?: InviteEntry.open(on: .home, model: $model)
                case .groups?: model.push(.createGroup, on: .home)
                default: return
                }
            }
```

In `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift`:

(a) Replace the `MembersProfileScreen(…)` call inside the `ScrollView` with:

```swift
                MembersProfileScreen(
                    state: state,
                    showsHeader: false,
                    // ui2-members-edit D2: a field row pushes its edit page on this tab's stack.
                    onEditField: { navigator.push(.editMemberField(memberId: memberId, field: $0)) },
                    // ui2-groups-browse D7: a group row opens that group's page. Program rows, both
                    // `add`s and the day cards stay no-ops (browse D5).
                    onOpenGroup: { row in
                        guard let page = Self.groupDestination(app.memberGroupsById[memberId], row: row) else { return }
                        navigator.push(page)
                    }
                )
```

(b) Add the static, after `cachedCoverURLs(_:)`:

```swift
    /// ui2-groups-browse D7: the page a group row opens — rows are `memberGroupsById` in order
    /// (MemberProfileMapper maps them one-for-one).
    static func groupDestination(_ groups: [MemberGroupItem]?, row: Int) -> UI2Destination? {
        guard let groups, groups.indices.contains(row) else { return nil }
        return .groupDetail(id: groups[row].id, name: groups[row].name)
    }
```

Leave `UI2Shell`'s deep-link drop (`.onChange(of: PushNotificationManager.shared.pendingDeepLink)`) as it is — group deep links stay out of scope (D24).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → `** TEST SUCCEEDED **`: the 5 new `UI2ShellModelTests` cases plus the whole suite (every task 8–15 test still green). `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Residual sweep (R1–R3) — prove the replaced 1.0 screens have no compiled caller; delete nothing.** From the repo root:

```bash
# 1. None of the four legacy files is compiled by the app or the capture target.
ruby -e 'require "xcodeproj"; p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); %w[MakeReady MakeReadyCapture].each { |tn| names = p.targets.find { |t| t.name == tn }.source_build_phase.files_references.compact.map { |f| File.basename(f.path.to_s) }; %w[MainGroups.swift GroupHomePage.swift GroupMembersPage.swift CreateGroupPage.swift].each { |n| puts "#{tn} compiles #{n}" if names.include?(n) } }'
# expected: no output

# 2. No compiled source names any of the four types (comment lines excluded).
ruby -e 'require "xcodeproj"; p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); %w[MakeReady MakeReadyCapture MakeReadyCaptureTests].each { |tn| p.targets.find { |t| t.name == tn }.source_build_phase.files_references.compact.each { |f| puts f.real_path } }' | sort -u | tr '\n' '\0' | xargs -0 grep -nwE "MainGroups|GroupHomePage|GroupMembersPage|CreateGroupPage" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' | wc -l
# expected: 0
```

Expected: command 1 prints nothing and command 2 prints `0`. Any hit means a compiled caller still reaches a replaced screen — STOP and report it (file:line); do not repoint or delete anything in this task. (At planning time both returned zero; the only textual mentions are comments in `EnrollmentActions.swift:381` and `AppState.swift:276`.)

- [ ] **Step 6: Commit** — `git add iphone/MakeReady/UI2/Shell/UI2ShellModel.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReady/UI2/Shell/TopNavHost.swift iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift && git commit -m "feat(ui2-groups-browse): wire Groups, the group page, create-group and the member page's group row into the shell"`
