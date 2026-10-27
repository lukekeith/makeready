# group-cover-image — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders can add, replace, reframe (zoom · rotate · pan) and view a group's cover on the iPhone 2.0 group page, with the original photo and its framing kept on the server so a crop can always be undone.

**Architecture:** The server stores two new nullable `Group` columns (`coverOriginalUrl`, `coverFraming`) and the cover upload accepts the rendered cover plus optional framing and original in one request, writing all three in one DB update (a new `services/group-cover.ts`); every group payload goes through one `toGroupPayload`. The iPhone renders exactly what the Edit cover frame shows (pure framing math + a `UIGraphicsImageRenderer` render), uploads it through a new `GroupActions.saveCover` on `requestWithStatus`, and wires a cover tap → picker / C-066 menu / viewer / the d2m-built Edit cover screen.

**Tech Stack:** server — Express, zod, Prisma (schema YAML → Atlas migration), sharp, Cloudflare R2, vitest + supertest · iphone — Swift 5 / SwiftUI (iOS 17), `@Observable` + Actions, PhotosUI `PhotosPicker`, ImageIO, UIKit `UIGraphicsImageRenderer`, XCTest.

**Spec:** `docs/features/group-cover-image/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(group-cover-image): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

**Plan notes for every task (not config):**
- This worktree has no `server/.env` (it is a 1Password pipe in the main checkout). Never run `npm run schema:diff`, `npm run migrate:*` or anything through `dotenv` — the exact Atlas command is given in Task 1. `npx prisma generate` is safe here (no `.env` to read).
- The server tests in this plan are unit/request tests with every side effect mocked; they do not need the `makeready-server` container. Run `docker restart makeready-server` only if it is running and you want to probe by hand.
- iPhone: the config marks iphone `commit: auto` (owner 2026-10-26) — commit iPhone tasks like any other; the "stage and STOP" line above predates that ruling.
- iPhone: the Xcode project has NO file-system-synchronised groups. A new `.swift` file is invisible to the compiler until it is referenced in `project.pbxproj`. Register each new file with this command (run from the repo root; `<sibling>` is an existing file in the same folder, `<target>` is `MakeReady` for app files or `MakeReadyCaptureTests` for tests):

  ```bash
  ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' <new-file> <sibling> <target>
  ```

  After adding a file to the `MakeReady` target run `ruby iphone/scripts/capture-targets.rb` (the MakeReadyCapture target mirrors it). Files under `iphone/MakeReadyUI/` are synced with `ruby iphone/scripts/makereadyui-sync.rb` instead.
- iPhone tests run with `npm run ios:build-check -- --test` from the repo root (add `-- -only-testing:MakeReadyCaptureTests/<Class>` style narrowing only if the script supports it; otherwise run the whole suite). Lint: `cd iphone && swiftlint --baseline .swiftlint-baseline.json`.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | `Group.coverOriginalUrl` + `Group.coverFraming` exist (one Atlas migration) and every group payload returns them through one `toGroupPayload` | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | server | 3–4 | the cover upload takes framing + original per D10/D11, clears on legacy bodies and PATCH (D9), captures per D18, deletes old originals (D19); the contract freezes | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 3 | iphone | 5–6 | `UserGroup` carries the two fields (old caches still decode) and `GroupActions.saveCover` uploads and patches `AppState` | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 7–9 | the framing math (D5), the 1200×529 render (D12), the ≤2400px upright pick (D3) and the Edit cover model (D6/D7/D13) exist and are tested | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 10–12 | the viewer (D8), the Edit cover page wired to the d2m screen (D4), and the cover tap → picker / C-066 menu on the group page (D1/D2) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Group cover columns — schema YAML, Atlas migration, Prisma client
App: server
Phase: 1
Recipe: `/api` (server conventions) · SPEC §Schema & API changes SC1–SC2 + Data plan · tiny

**Files:**
- Modify: `server/schema/schema.yaml:286-288` (Group, after `coverImageUrl`)
- Generated (commit them): `server/atlas/migrations/<timestamp>_group_cover_image.sql`, `server/atlas/migrations/atlas.sum`, `server/prisma/schema.prisma`, `server/atlas/.schema.hcl` (only if it is tracked — `git status` tells you)
- Test: `server/test/group-cover-columns-migration.test.ts`

**Interfaces:**
- Consumes: nothing
- Produces: Prisma `Group.coverOriginalUrl: string | null`, `Group.coverFraming: Prisma.JsonValue | null`; DB columns `groups."coverOriginalUrl" text NULL`, `groups."coverFraming" jsonb NULL`

- [ ] **Step 1: Write the failing test** — `server/test/group-cover-columns-migration.test.ts`

```ts
/**
 * group-cover-image SC1–SC2: two nullable Group columns in ONE Atlas migration, no backfill
 * (existing groups read null and use D7's fallback).
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
    .filter((m) => m.sql.includes('"coverOriginalUrl"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1–SC2 migration', () => {
  it('adds both columns as nullable to groups', () => {
    const { sql } = findMigration()
    expect(sql).toContain('ALTER TABLE "groups"')
    expect(sql).toContain('ADD COLUMN "coverOriginalUrl" text NULL')
    expect(sql).toContain('ADD COLUMN "coverFraming" jsonb NULL')
  })

  it('backfills nothing', () => {
    const { sql } = findMigration()
    expect(sql).not.toMatch(/UPDATE\s+"groups"/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates both Prisma fields', () => {
    const fields = Object.keys(Prisma.GroupScalarFieldEnum)
    expect(fields).toContain('coverOriginalUrl')
    expect(fields).toContain('coverFraming')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/group-cover-columns-migration.test.ts` → FAIL, `expected [] to have a length of 1`

- [ ] **Step 3: Add the two fields to the YAML** — in `server/schema/schema.yaml`, Group model, directly after the `coverImageUrl:` block (keep descriptions free of apostrophes; they become SQL comments):

```yaml
      coverOriginalUrl:
        type: string
        nullable: true
        description: "group-cover-image SC1 (D10): the full original cover photo; null means Edit reopens coverImageUrl (D7)"
      coverFraming:
        type: json
        nullable: true
        description: "group-cover-image SC2 (D11): {scale, rotation, offsetX, offsetY} the cover was rendered with"
```

- [ ] **Step 4: Validate and generate** — never via `dotenv`/npm migrate scripts (no `server/.env` here):

```bash
cd server && npm run schema:validate
cd server && npm run schema:generate
cd server/atlas && ../scripts/atlas.sh migrate diff group_cover_image --env local \
  --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
cd server && npx prisma generate
```

The diff needs the shared postgres container on :5434 (its `atlas_dev_template` DB is the dev database). If it is down, `docker start makeready-postgres` first. Open the generated `.sql` and confirm it holds only the two `ADD COLUMN`s and their `COMMENT ON COLUMN` lines; if Atlas emitted anything else, the YAML is out of sync with an earlier migration — STOP and report it.

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run test/group-cover-columns-migration.test.ts` → PASS (4 tests); then `cd server && npx tsc --noEmit` → no errors

- [ ] **Step 6: Commit** — `git add server/schema/schema.yaml server/atlas/migrations server/prisma/schema.prisma server/test/group-cover-columns-migration.test.ts` (plus `server/atlas/.schema.hcl` if tracked) → `feat(group-cover-image): Group.coverOriginalUrl + Group.coverFraming columns`

### Task 2: One `toGroupPayload` carrying the two new fields
App: server
Phase: 1
Recipe: `/api` · SPEC §Contract row 2, D11, D17

**Files:**
- Create: `server/src/services/group-cover.ts` (the framing schema only in this task; Task 3 extends it)
- Create: `server/src/services/group-payload.ts`
- Modify: `server/src/routes/groups.ts:172-194` (POST), `:278-300` (GET list), `:609-630` (GET /:id), `:1118-1140` (PATCH) — each inline mapper replaced by a call
- Modify: `server/src/docs/openapi-definition.ts:253,289` — add the two properties beside `coverImageUrl` in both Group schemas
- Test: `server/src/services/__tests__/group-payload.test.ts`, `server/src/routes/__tests__/groups-cover-payload.request.test.ts`

**Interfaces:**
- Consumes: Task 1's Prisma fields
- Produces:
  - `services/group-cover.ts`: `export const coverFramingSchema` (zod, `.strict()`), `export type CoverFraming = { scale: number; rotation: number; offsetX: number; offsetY: number }`, `export function parseStoredFraming(value: unknown): CoverFraming | null`
  - `services/group-payload.ts`: `export function toGroupPayload(group: GroupPayloadRow, opts?: { organizationName?: string | null }): GroupPayload` — keys: `id, organizationId, code, name, description, coverImageUrl, coverOriginalUrl, coverFraming, isPrivate, allowInvites, memberDirectory, memberDirectoryAccess, welcomeMessage, ageRange, maxMembers, memberCount, creatorId, creatorName, createdAt, updatedAt` plus `organizationName` only when `opts` has the key

- [ ] **Step 1: Write the failing unit test** — `server/src/services/__tests__/group-payload.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { toGroupPayload } from '../group-payload.js'
import { coverFramingSchema, parseStoredFraming } from '../group-cover.js'

const row = (over: Record<string, unknown> = {}) => ({
  id: 'g1', organizationId: 'org1', code: 'ABC123', name: 'Prayer Team', description: null,
  coverImageUrl: 'https://img.test/c.jpeg', coverOriginalUrl: 'https://img.test/o.jpeg',
  coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 },
  isPrivate: false, allowInvites: true, memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED',
  welcomeMessage: null, ageRangeMin: null, ageRangeMax: null, maxMembers: null, creatorId: 'u1',
  createdAt: new Date('2026-10-01T00:00:00Z'), updatedAt: new Date('2026-10-02T00:00:00Z'),
  _count: { members: 3 }, creator: { name: 'Tony Stark' },
  ...over,
})

describe('toGroupPayload (D17)', () => {
  it('returns both cover fields', () => {
    const p = toGroupPayload(row() as any)
    expect(p.coverOriginalUrl).toBe('https://img.test/o.jpeg')
    expect(p.coverFraming).toEqual({ scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 })
  })

  it('returns null for absent cover fields', () => {
    const p = toGroupPayload(row({ coverOriginalUrl: null, coverFraming: null }) as any)
    expect(p.coverOriginalUrl).toBeNull()
    expect(p.coverFraming).toBeNull()
  })

  it('returns null for a stored framing that fails D11', () => {
    expect(toGroupPayload(row({ coverFraming: { scale: 99 } }) as any).coverFraming).toBeNull()
  })

  it('keeps the existing mapping', () => {
    const p = toGroupPayload(row({ ageRangeMin: 18, memberDirectoryEnabled: false }) as any)
    expect(p).toMatchObject({ memberDirectory: false, ageRange: { min: 18, max: null }, memberCount: 3, creatorName: 'Tony Stark' })
    expect(p).not.toHaveProperty('memberDirectoryEnabled')
  })

  it('adds organizationName only when asked', () => {
    expect(toGroupPayload(row() as any)).not.toHaveProperty('organizationName')
    expect(toGroupPayload(row() as any, { organizationName: 'Grace' }).organizationName).toBe('Grace')
    expect(toGroupPayload(row() as any, { organizationName: null })).toHaveProperty('organizationName', null)
  })
})

describe('coverFramingSchema (D11)', () => {
  const ok = { scale: 1, rotation: 0, offsetX: 0, offsetY: 0 }
  it('accepts the bounds', () => {
    expect(coverFramingSchema.parse({ scale: 8, rotation: -180, offsetX: 1, offsetY: -1 })).toBeTruthy()
  })
  it.each([
    ['scale below 1', { ...ok, scale: 0.5 }],
    ['scale above 8', { ...ok, scale: 8.1 }],
    ['rotation above 180', { ...ok, rotation: 181 }],
    ['offsetX beyond 1', { ...ok, offsetX: 1.5 }],
    ['an unknown key', { ...ok, flip: true }],
    ['a missing key', { scale: 1, rotation: 0, offsetX: 0 }],
    ['a non-finite value', { ...ok, scale: Number.POSITIVE_INFINITY }],
  ])('rejects %s', (_label, value) => {
    expect(coverFramingSchema.safeParse(value).success).toBe(false)
  })
  it('parseStoredFraming returns null for junk', () => {
    expect(parseStoredFraming('x')).toBeNull()
    expect(parseStoredFraming(null)).toBeNull()
    expect(parseStoredFraming(ok)).toEqual(ok)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/group-payload.test.ts` → FAIL, `Failed to resolve import "../group-payload.js"`

- [ ] **Step 3: Write `server/src/services/group-cover.ts`**

```ts
/**
 * group-cover-image: the non-destructive group cover — the framing shape (D11). Task 3 adds the
 * upload service (D10, D17) to this module.
 */
import { z } from 'zod'

/** D11: all finite; scale relative to the zoom floor (1…8), degrees, fractions of the frame. */
export const coverFramingSchema = z
  .object({
    scale: z.number().finite().min(1).max(8),
    rotation: z.number().finite().min(-180).max(180),
    offsetX: z.number().finite().min(-1).max(1),
    offsetY: z.number().finite().min(-1).max(1),
  })
  .strict()

export type CoverFraming = z.infer<typeof coverFramingSchema>

/** A stored `coverFraming` as the payload returns it — null when absent or not D11-shaped. */
export function parseStoredFraming(value: unknown): CoverFraming | null {
  const parsed = coverFramingSchema.safeParse(value)
  return parsed.success ? parsed.data : null
}
```

- [ ] **Step 4: Write `server/src/services/group-payload.ts`**

```ts
/**
 * group-cover-image D17: the one group payload every groups route returns (POST, GET list,
 * GET /:id, PATCH) — the four inline mappers it replaced were identical but for the org keys.
 */
import type { Group } from '../generated/prisma/index.js'
import { parseStoredFraming, type CoverFraming } from './group-cover.js'

export type GroupPayloadRow = Pick<
  Group,
  | 'id' | 'organizationId' | 'code' | 'name' | 'description' | 'coverImageUrl' | 'coverOriginalUrl'
  | 'coverFraming' | 'isPrivate' | 'allowInvites' | 'memberDirectoryEnabled' | 'memberDirectoryAccess'
  | 'welcomeMessage' | 'ageRangeMin' | 'ageRangeMax' | 'maxMembers' | 'creatorId' | 'createdAt' | 'updatedAt'
> & {
  _count: { members: number }
  creator?: { name: string | null } | null
}

export interface GroupPayload {
  id: string
  organizationId: string
  code: string | null
  name: string
  description: string | null
  coverImageUrl: string | null
  coverOriginalUrl: string | null
  coverFraming: CoverFraming | null
  isPrivate: boolean
  allowInvites: boolean
  memberDirectory: boolean
  memberDirectoryAccess: Group['memberDirectoryAccess']
  welcomeMessage: string | null
  ageRange: { min: number | null; max: number | null } | null
  maxMembers: number | null
  memberCount: number
  creatorId: string
  creatorName: string | null
  organizationName?: string | null
  createdAt: Date
  updatedAt: Date
}

/** Transform a group row to match the iOS model. `organizationName` is added only when passed. */
export function toGroupPayload(group: GroupPayloadRow, opts: { organizationName?: string | null } = {}): GroupPayload {
  const payload: GroupPayload = {
    id: group.id,
    organizationId: group.organizationId,
    code: group.code,
    name: group.name,
    description: group.description,
    coverImageUrl: group.coverImageUrl,
    coverOriginalUrl: group.coverOriginalUrl ?? null,
    coverFraming: parseStoredFraming(group.coverFraming),
    isPrivate: group.isPrivate,
    allowInvites: group.allowInvites,
    memberDirectory: group.memberDirectoryEnabled,
    memberDirectoryAccess: group.memberDirectoryAccess,
    welcomeMessage: group.welcomeMessage,
    ageRange:
      group.ageRangeMin !== null || group.ageRangeMax !== null
        ? { min: group.ageRangeMin, max: group.ageRangeMax }
        : null,
    maxMembers: group.maxMembers,
    memberCount: group._count.members,
    creatorId: group.creatorId,
    creatorName: group.creator?.name ?? null,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
  }
  if ('organizationName' in opts) payload.organizationName = opts.organizationName ?? null
  return payload
}
```

If `tsc` reports `organizationId` or `creatorId` nullable on `Group`, widen the matching `GroupPayload` field to `| null` — do not cast.

- [ ] **Step 5: Run the unit test and watch it pass** — `cd server && npx vitest run src/services/__tests__/group-payload.test.ts` → PASS

- [ ] **Step 6: Write the failing request test** — `server/src/routes/__tests__/groups-cover-payload.request.test.ts`. Copy the whole mock block, `app()` and `row()` helpers from `server/src/routes/__tests__/groups-edit-fields.request.test.ts:1-86` verbatim (they are the house pattern), then extend `row()`'s defaults with `coverOriginalUrl: 'https://img.test/o.jpeg', coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 }`, and add:

```ts
const COVER = { coverOriginalUrl: 'https://img.test/o.jpeg', coverFraming: { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 } }

describe('group payloads carry the cover fields (§Contract row 2)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.findMany.mockResolvedValue([row()])
    prismaMock.group.create.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
    prismaMock.organization.findMany.mockResolvedValue([{ id: 'org1', name: 'Grace' }])
  })

  it('GET /api/groups', async () => {
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(res.body.groups[0]).toMatchObject({ ...COVER, organizationName: 'Grace' })
  })

  it('GET /api/groups/:id', async () => {
    const res = await request(app()).get('/api/groups/g1')
    expect(res.body.group).toMatchObject(COVER)
  })

  it('PATCH /api/groups/:id', async () => {
    const res = await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(res.body.group).toMatchObject({ ...COVER, name: 'Renamed' })
  })

  it('POST /api/groups', async () => {
    const res = await request(app()).post('/api/groups').send({ name: 'Prayer Team' })
    expect(res.status).toBe(200)
    expect(res.body.group).toMatchObject(COVER)
  })
})
```

- [ ] **Step 7: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/groups-cover-payload.request.test.ts` → FAIL, `coverOriginalUrl` missing from the response

- [ ] **Step 8: Replace the four inline mappers** — in `server/src/routes/groups.ts` add `import { toGroupPayload } from '../services/group-payload.js'`, then:
  - POST (172-194): `const response = toGroupPayload(group)`
  - GET list (278-300): `const response = groups.map((group) => toGroupPayload(group, { organizationName: orgNames.get(group.organizationId) ?? null }))`
  - GET /:id (609-630): `const response = toGroupPayload(group)`
  - PATCH (1118-1140): `const response = toGroupPayload(group)`

  Keep each `// Transform response to match iOS model` comment line. Leave `GET /api/groups/code/:code`, the public group endpoint, `members.ts` and `public.ts` untouched (SPEC §Apps blast radius).

- [ ] **Step 9: OpenAPI** — in `server/src/docs/openapi-definition.ts`, beside both `coverImageUrl` lines (253, 289) add:

```ts
          coverOriginalUrl: { type: 'string', format: 'uri', nullable: true, description: 'group-cover-image D10: the full original cover photo' },
          coverFraming: {
            type: 'object',
            nullable: true,
            description: 'group-cover-image D11: the framing the cover was rendered with',
            properties: {
              scale: { type: 'number', minimum: 1, maximum: 8 },
              rotation: { type: 'number', minimum: -180, maximum: 180 },
              offsetX: { type: 'number', minimum: -1, maximum: 1 },
              offsetY: { type: 'number', minimum: -1, maximum: 1 },
            },
          },
```

- [ ] **Step 10: Run everything and watch it pass** — `cd server && npx tsc --noEmit && npx vitest run src/services/__tests__/group-payload.test.ts src/routes/__tests__/` → PASS (every existing groups request test still green)

- [ ] **Step 11: Commit** — `feat(group-cover-image): one toGroupPayload returning coverOriginalUrl + coverFraming`

### Task 3: `saveGroupCover` service — re-encode, upload, one atomic write, old-original delete
App: server
Phase: 2
Recipe: `/api` · SPEC D9, D10, D16, D17, D19, F9

**Files:**
- Modify: `server/src/services/group-cover.ts` (append)
- Test: `server/src/services/__tests__/group-cover.test.ts`

**Interfaces:**
- Consumes: Task 2's `coverFramingSchema`, `CoverFraming`; `storage.ts` `uploadImageVariants`, `uploadToR2`, `deleteFromR2`, `extractKeyFromUrl`; `prisma` from `../lib/prisma.js`; `Prisma.DbNull` from `../generated/prisma/index.js`
- Produces:
  - `export class CoverUploadError extends Error { readonly status: 400 }`
  - `export interface SaveGroupCoverInput { group: { id: string; coverOriginalUrl: string | null }; imageData: string; framing?: CoverFraming; originalData?: string }`
  - `export interface SaveGroupCoverResult { coverImageUrl: string; coverOriginalUrl: string | null; coverFraming: CoverFraming | null; renderedBuffer: Buffer; renderedSize: number; isNewImage: boolean }`
  - `export async function saveGroupCover(input: SaveGroupCoverInput): Promise<SaveGroupCoverResult>`
  - `export const ORIGINAL_MAX_PX = 2400`

- [ ] **Step 1: Write the failing test** — `server/src/services/__tests__/group-cover.test.ts`

```ts
/**
 * group-cover-image D9/D10/D17/D19: the cover upload service. Prisma, R2 and sharp are mocked; the
 * service is real.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ group: { update: vi.fn() } }))
const storage = vi.hoisted(() => ({
  uploadImageVariants: vi.fn(),
  uploadToR2: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
const sharpCalls = vi.hoisted(() => [] as Array<{ input: Buffer; ops: Array<[string, unknown[]]> }>)
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock }))
vi.mock('../storage.js', () => storage)
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const call = { input, ops: [] as Array<[string, unknown[]]> }
    sharpCalls.push(call)
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'rotate']) {
      chain[op] = vi.fn((...args: unknown[]) => { call.ops.push([op, args]); return chain })
    }
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { CoverUploadError, saveGroupCover } from '../group-cover.js'

const b64 = (s: string) => Buffer.from(s).toString('base64')
const FRAMING = { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 }
const group = (coverOriginalUrl: string | null = null) => ({ id: 'g1', coverOriginalUrl })
const written = () => prismaMock.group.update.mock.calls[0][0].data

beforeEach(() => {
  vi.clearAllMocks()
  sharpCalls.length = 0
  storage.uploadImageVariants.mockResolvedValue({ url: 'https://img.test/groups/group-g1-1.jpeg' })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.group.update.mockResolvedValue({})
})

describe('saveGroupCover', () => {
  it('a new pick stores the rendered cover, the re-encoded original and the framing in ONE write', async () => {
    const r = await saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(prismaMock.group.update).toHaveBeenCalledTimes(1)
    expect(written()).toEqual({
      coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg',
      coverOriginalUrl: expect.stringMatching(/^https:\/\/img\.test\/groups\/group-g1-\d+-original\.jpeg$/),
      coverFraming: FRAMING,
    })
    expect(r).toMatchObject({ coverFraming: FRAMING, isNewImage: true })
    expect(r.coverOriginalUrl).toBe(written().coverOriginalUrl)
  })

  it('re-encodes the original: EXIF rotate, ≤ 2400px inside, JPEG 90, own key, no WebP ladder (D10, F9)', async () => {
    await saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    const orig = sharpCalls.find((c) => c.input.toString() === 'orig' && c.ops.length > 0)!
    expect(orig.ops).toEqual([
      ['rotate', []],
      ['resize', [2400, 2400, { fit: 'inside', withoutEnlargement: true }]],
      ['jpeg', [{ quality: 90 }]],
    ])
    expect(storage.uploadToR2).toHaveBeenCalledTimes(1)
    expect(storage.uploadToR2.mock.calls[0][0]).toMatch(/^groups\/group-g1-\d+-original\.jpeg$/)
    expect(storage.uploadToR2.mock.calls[0][2]).toBe('image/jpeg')
  })

  it('framing without an original keeps the stored original (a re-edit)', async () => {
    const r = await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render'), framing: FRAMING })
    expect(written().coverOriginalUrl).toBe('https://img.test/old-original.jpeg')
    expect(storage.uploadToR2).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
    expect(r.isNewImage).toBe(false)
  })

  it('a legacy body (no framing) clears the original and the framing (D9) and deletes the old original (D19)', async () => {
    const r = await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render') })
    expect(written()).toEqual({ coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg', coverOriginalUrl: null, coverFraming: Prisma.DbNull })
    expect(r).toMatchObject({ coverOriginalUrl: null, coverFraming: null, isNewImage: true })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('old-original.jpeg')
  })

  it('a new original replaces the old one, deleted after the write (D19)', async () => {
    await saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('old-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.group.update.mock.invocationCallOrder[0])
  })

  it('a failed old-original delete is logged, never thrown (D19)', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveGroupCover({ group: group('https://img.test/old-original.jpeg'), imageData: b64('render') })
    ).resolves.toBeTruthy()
  })

  it('an original without framing is a 400 and nothing is uploaded (D10)', async () => {
    await expect(saveGroupCover({ group: group(), imageData: b64('render'), originalData: b64('orig') })).rejects.toMatchObject({ status: 400 })
    expect(storage.uploadImageVariants).not.toHaveBeenCalled()
  })

  it.each([
    ['the rendered cover', { imageData: b64('bad') }],
    ['the original', { imageData: b64('render'), framing: FRAMING, originalData: b64('bad') }],
  ])('an undecodable %s is a 400 and nothing is uploaded (D10)', async (_l, body) => {
    const err = await saveGroupCover({ group: group(), ...body }).catch((e) => e)
    expect(err).toBeInstanceOf(CoverUploadError)
    expect(err.status).toBe(400)
    expect(storage.uploadImageVariants).not.toHaveBeenCalled()
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('an R2 failure propagates and leaves the row unchanged (D10)', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveGroupCover({ group: group(), imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    ).rejects.toThrow('r2 down')
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('strips a data-URL prefix from either image', async () => {
    await saveGroupCover({ group: group(), imageData: `data:image/jpeg;base64,${b64('render')}`, framing: FRAMING, originalData: `data:image/jpeg;base64,${b64('orig')}` })
    expect(sharpCalls.some((c) => c.input.toString() === 'orig')).toBe(true)
    expect(sharpCalls.some((c) => c.input.toString() === 'render')).toBe(true)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/group-cover.test.ts` → FAIL, `saveGroupCover is not a function` / import error

- [ ] **Step 3: Append the service to `server/src/services/group-cover.ts`** (add the imports at the top of the file)

```ts
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { deleteFromR2, extractKeyFromUrl, uploadImageVariants, uploadToR2 } from './storage.js'

/** D10: the original's longest side, re-enforced server-side (D16). */
export const ORIGINAL_MAX_PX = 2400

/** A client error the route maps to its status (D10: a bad image is a 400, not a 500). */
export class CoverUploadError extends Error {
  readonly status = 400 as const
}

export interface SaveGroupCoverInput {
  group: { id: string; coverOriginalUrl: string | null }
  /** D10: the rendered cover, JPEG base64 (a data-URL prefix is tolerated). */
  imageData: string
  framing?: CoverFraming
  originalData?: string
}

export interface SaveGroupCoverResult {
  coverImageUrl: string
  coverOriginalUrl: string | null
  coverFraming: CoverFraming | null
  /** The decoded rendered cover — the route's media-library capture reads it (D18). */
  renderedBuffer: Buffer
  /** Bytes of the 1200px rendered JPEG uploaded (the capture's fileSize). */
  renderedSize: number
  /** D18: a new image (an original, or no framing) rather than a re-edit. */
  isNewImage: boolean
}

function decodeBase64(data: string): Buffer {
  return Buffer.from(data.replace(/^data:image\/\w+;base64,/, ''), 'base64')
}

/** D10: either image failing sharp's metadata read is a 400. */
async function assertDecodable(buffer: Buffer, label: string): Promise<void> {
  try {
    const meta = await sharp(buffer).metadata()
    if (!meta.format) throw new Error('no format')
  } catch {
    throw new CoverUploadError(`The ${label} could not be decoded as an image`)
  }
}

/**
 * D10 / D17: decode + validate both images, upload the rendered ladder (1200/400/150, as before)
 * and the re-encoded original, then ONE group update writing all three cover columns. D9: no
 * framing clears the original and the framing. D19: a replaced or cleared original is deleted
 * from R2 after the write, best-effort. Any R2 failure rejects before the write (orphans accepted).
 */
export async function saveGroupCover(input: SaveGroupCoverInput): Promise<SaveGroupCoverResult> {
  const { group, framing } = input
  if (input.originalData !== undefined && framing === undefined) {
    throw new CoverUploadError('originalData requires framing')
  }

  const rendered = decodeBase64(input.imageData)
  const original = input.originalData !== undefined ? decodeBase64(input.originalData) : null
  await assertDecodable(rendered, 'cover image')
  if (original) await assertDecodable(original, 'original image')

  const timestamp = Date.now()
  const baseName = `group-${group.id}-${timestamp}`

  const [large, medium, thumb, originalJpeg] = await Promise.all([
    sharp(rendered).resize(1200, null, { withoutEnlargement: true }).jpeg({ quality: 85 }).toBuffer(),
    sharp(rendered).resize(400, null, { withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer(),
    sharp(rendered).resize(150, null, { withoutEnlargement: true }).jpeg({ quality: 75 }).toBuffer(),
    original
      ? sharp(original)
          .rotate()
          .resize(ORIGINAL_MAX_PX, ORIGINAL_MAX_PX, { fit: 'inside', withoutEnlargement: true })
          .jpeg({ quality: 90 })
          .toBuffer()
      : Promise.resolve(null),
  ])

  const [{ url: coverImageUrl }, uploadedOriginalUrl] = await Promise.all([
    uploadImageVariants('groups', baseName, 'jpeg', large, medium, thumb),
    originalJpeg ? uploadToR2(`groups/${baseName}-original.jpeg`, originalJpeg, 'image/jpeg') : Promise.resolve(null),
  ])

  const coverOriginalUrl = framing ? (uploadedOriginalUrl ?? group.coverOriginalUrl) : null
  const coverFraming = framing ?? null

  await prisma.group.update({
    where: { id: group.id },
    data: { coverImageUrl, coverOriginalUrl, coverFraming: coverFraming ?? Prisma.DbNull },
  })

  const previous = group.coverOriginalUrl
  if (previous && previous !== coverOriginalUrl) {
    const key = extractKeyFromUrl(previous)
    if (key) {
      try {
        await deleteFromR2(key)
      } catch (error) {
        console.warn(`saveGroupCover: could not delete the old original ${key}:`, error)
      }
    }
  }

  return {
    coverImageUrl,
    coverOriginalUrl,
    coverFraming,
    renderedBuffer: rendered,
    renderedSize: large.length,
    isNewImage: original !== null || framing === undefined,
  }
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/group-cover.test.ts src/services/__tests__/group-payload.test.ts` → PASS; `cd server && npx tsc --noEmit` → no errors

- [ ] **Step 5: Commit** — `feat(group-cover-image): saveGroupCover — original + framing in one atomic write`

### Task 4: Cover upload route on the service, PATCH clearing, OpenAPI — and the contract freeze
App: server
Phase: 2
Recipe: `/api` · SPEC §Contract row 1, D9, D10, D14, D18 · §Testing (server)

**Files:**
- Modify: `server/src/routes/groups.ts:1241-1414` (the cover upload route and its `@openapi` block), `:1012-1055` (PATCH: the `coverImageUrl` clear)
- Test: `server/src/routes/__tests__/groups-cover-image.request.test.ts`
- Modify (freeze): `docs/features/group-cover-image/MANIFEST.md` (via `advance.mjs`, last step)

**Interfaces:**
- Consumes: Task 3's `saveGroupCover`, `CoverUploadError`; Task 2's `coverFramingSchema`
- Produces: `POST /api/groups/:id/cover-image` → `200 {success: true, coverImageUrl, coverOriginalUrl, coverFraming}`; `400 {success: false, error}`; `404`; `500`. PATCH with a `coverImageUrl` key writes `coverOriginalUrl: null, coverFraming: Prisma.DbNull`.

- [ ] **Step 1: Write the failing request test** — `server/src/routes/__tests__/groups-cover-image.request.test.ts`. Copy the mock block, `app()` and `row()` from `groups-edit-fields.request.test.ts:1-86` verbatim, then change two mocks: the storage mock becomes

```ts
const storage = vi.hoisted(() => ({
  uploadImageVariants: vi.fn(),
  uploadToR2: vi.fn(),
  deleteFromR2: vi.fn(),
}))
vi.mock('../../services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/storage.js')>()),
  ...storage,
  extractKeyFromUrl: (url: string) => url.replace('https://img.test/', ''),
}))
```

and the sharp mock gains `rotate` and `metadata` (`metadata` rejects for the input `bad`):

```ts
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const chain: Record<string, any> = {}
    for (const op of ['resize', 'jpeg', 'rotate']) chain[op] = vi.fn(() => chain)
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from('jpeg'))
    chain.metadata = vi.fn(() =>
      input?.toString() === 'bad' ? Promise.reject(new Error('bad')) : Promise.resolve({ format: 'jpeg', width: 1, height: 1 })
    )
    return chain
  }),
}))
```

Keep the `captureToLibrary` mock and import it for assertions (`import { captureToLibrary } from '../../services/media-library.js'`). Then:

```ts
import { Prisma } from '../../generated/prisma/index.js'

const b64 = (s: string) => Buffer.from(s).toString('base64')
const FRAMING = { scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2 }
const upload = (body: Record<string, unknown>) => request(app()).post('/api/groups/g1/cover-image').send(body)
const written = () => prismaMock.group.update.mock.calls[0][0].data

beforeEach(() => {
  storage.uploadImageVariants.mockResolvedValue({ url: 'https://img.test/groups/group-g1-1.jpeg' })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.group.findFirst.mockResolvedValue(row({ coverOriginalUrl: 'https://img.test/old-original.jpeg', coverFraming: FRAMING }))
  prismaMock.group.update.mockResolvedValue(row())
})

describe('POST /api/groups/:id/cover-image (D10)', () => {
  it('framing + original: stores both and answers flat', async () => {
    const res = await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg',
      coverOriginalUrl: expect.stringMatching(/-original\.jpeg$/),
      coverFraming: FRAMING,
    })
    expect(res.body).not.toHaveProperty('data')
  })

  it('framing only keeps the stored original', async () => {
    const res = await upload({ imageData: b64('render'), framing: FRAMING })
    expect(res.body.coverOriginalUrl).toBe('https://img.test/old-original.jpeg')
  })

  it('the legacy body (imageData + contentType) clears both and still answers coverImageUrl top-level (D9)', async () => {
    const res = await upload({ imageData: b64('render'), contentType: 'image/jpeg' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, coverImageUrl: 'https://img.test/groups/group-g1-1.jpeg', coverOriginalUrl: null, coverFraming: null })
    expect(written()).toMatchObject({ coverOriginalUrl: null, coverFraming: Prisma.DbNull })
  })

  it.each([
    ['originalData without framing', { imageData: b64('r'), originalData: b64('o') }],
    ['a framing out of range', { imageData: b64('r'), framing: { ...FRAMING, scale: 9 } }],
    ['a framing with an unknown key', { imageData: b64('r'), framing: { ...FRAMING, flip: true } }],
    ['a framing missing a key', { imageData: b64('r'), framing: { scale: 1, rotation: 0, offsetX: 0 } }],
    ['an undecodable image', { imageData: b64('bad') }],
    ['no imageData', { framing: FRAMING }],
  ])('400 on %s, nothing written', async (_l, body) => {
    const res = await upload(body)
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('404 for a non-manager (groupManageFilter finds nothing, D14)', async () => {
    prismaMock.group.findFirst.mockResolvedValue(null)
    const res = await upload({ imageData: b64('render'), framing: FRAMING })
    expect(res.status).toBe(404)
  })

  it('500 on an R2 failure, row unchanged', async () => {
    storage.uploadImageVariants.mockRejectedValue(new Error('r2 down'))
    const res = await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    expect(res.status).toBe(500)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('D18: a new pick and a legacy upload capture the rendered cover; a re-edit captures nothing', async () => {
    await upload({ imageData: b64('render'), framing: FRAMING, originalData: b64('orig') })
    await upload({ imageData: b64('render') })
    expect(captureToLibrary).toHaveBeenCalledTimes(2)
    expect(vi.mocked(captureToLibrary).mock.calls[0][0]).toMatchObject({ url: 'https://img.test/groups/group-g1-1.jpeg', usageType: 'GROUP_COVER' })
    vi.mocked(captureToLibrary).mockClear()
    await upload({ imageData: b64('render'), framing: FRAMING })
    expect(captureToLibrary).not.toHaveBeenCalled()
  })

  it('records the cover history row on every save', async () => {
    await upload({ imageData: b64('render'), framing: FRAMING })
    expect(trackActivity).toHaveBeenCalledWith(expect.objectContaining({ metadata: { field: 'cover' } }))
  })
})

describe('PATCH clears the original and framing with the coverImageUrl key (D9)', () => {
  beforeEach(() => {
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it.each([['a URL', 'https://img.test/other.jpeg'], ['null', null]])('coverImageUrl = %s', async (_l, value) => {
    await request(app()).patch('/api/groups/g1').send({ coverImageUrl: value })
    expect(written()).toMatchObject({ coverImageUrl: value, coverOriginalUrl: null, coverFraming: Prisma.DbNull })
  })

  it('a PATCH without the key leaves them alone', async () => {
    await request(app()).patch('/api/groups/g1').send({ name: 'Renamed' })
    expect(written()).not.toHaveProperty('coverOriginalUrl')
    expect(written()).not.toHaveProperty('coverFraming')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/groups-cover-image.request.test.ts` → FAIL (response lacks `coverOriginalUrl`; 400 cases return 200/500)

- [ ] **Step 3: Rewrite the route body** — in `server/src/routes/groups.ts` add `import { CoverUploadError, coverFramingSchema, saveGroupCover } from '../services/group-cover.js'` and `import { Prisma } from '../generated/prisma/index.js'` (drop `uploadImageVariants` and, if now unused, `sharp` from the imports). Replace the handler body of `router.post('/:id/cover-image', …)` with:

```ts
router.post('/:id/cover-image', requireAuth, async (req, res) => {
  try {
    const { id } = req.params
    const userId = (req.user as any).id

    // group-cover-image D10/D11: the legacy body (imageData, contentType) still works; framing is
    // strict; contentType is accepted and ignored for the original (always re-encoded JPEG).
    const schema = z.object({
      imageData: z.string().min(1, 'Image data is required'),
      contentType: z.string().default('image/jpeg'),
      framing: coverFramingSchema.optional(),
      originalData: z.string().min(1).optional(),
    })

    const body = schema.parse(req.body)
    if (body.originalData !== undefined && body.framing === undefined) {
      return res.status(400).json({ success: false, error: 'originalData requires framing' })
    }

    // Creator, the group org's owner/role-holders, or a super admin may edit (D14).
    const group = await prisma.group.findFirst({
      where: { id, ...(await groupManageFilter(userId)), isActive: true },
    })

    if (!group) {
      return res.status(404).json({ success: false, error: 'Group not found' })
    }

    const saved = await saveGroupCover({
      group: { id: group.id, coverOriginalUrl: group.coverOriginalUrl },
      imageData: body.imageData,
      framing: body.framing,
      originalData: body.originalData,
    })

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

    // group-cover-image D18: capture a new image (an original, or a framing-less upload); a re-edit
    // captures nothing, and the original is never captured.
    if (group.organizationId && saved.isNewImage) {
      const imageMeta = await extractImageMetadata(saved.renderedBuffer)
      captureToLibrary({
        title: `${group.name} - Cover Image`,
        url: saved.coverImageUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        fileSize: saved.renderedSize,
        thumbnailUrl: saved.coverImageUrl.replace('.jpeg', '-thumb.jpeg'),
        organizationId: group.organizationId,
        uploadedBy: userId,
        source: 'auto_capture',
        usageType: 'GROUP_COVER',
        resourceId: group.id,
        resourceName: group.name,
        width: imageMeta.width,
        height: imageMeta.height,
        aspectRatio: imageMeta.aspectRatio,
        dominantColor: imageMeta.dominantColor ?? undefined,
        fileHash: imageMeta.fileHash,
        exifData: imageMeta.exifData ?? undefined,
      })
    }

    // D10: flat — coverImageUrl stays top-level for released 1.0 and the web.
    res.json({
      success: true,
      coverImageUrl: saved.coverImageUrl,
      coverOriginalUrl: saved.coverOriginalUrl,
      coverFraming: saved.coverFraming,
    })
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({ success: false, error: error.errors })
    }
    if (error instanceof CoverUploadError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    console.error('Error uploading cover image:', error)
    res.status(500).json({ success: false, error: 'Failed to upload cover image' })
  }
})
```

- [ ] **Step 4: PATCH clearing (D9)** — in the PATCH handler replace line 1055 with:

```ts
    if (body.coverImageUrl !== undefined) {
      updateData.coverImageUrl = body.coverImageUrl
      // group-cover-image D9: a cover set elsewhere drops the stored original and framing.
      updateData.coverOriginalUrl = null
      updateData.coverFraming = Prisma.DbNull
    }
```

- [ ] **Step 5: OpenAPI block** — in the route's `@openapi` comment (1241-1292): under `requestBody … properties` add `framing` (object: `scale` 1–8, `rotation` −180–180, `offsetX`/`offsetY` −1–1, `additionalProperties: false`, description "D11 — required with originalData") and `originalData` (string, "Base64 JPEG of the full original; requires framing"); under the 200 response add `coverOriginalUrl` (string uri, nullable) and `coverFraming` (object, nullable); add a `400` response (`$ref: '#/components/schemas/Error'`, "Invalid framing, originalData without framing, or an undecodable image") and a `413` ("Body over the 10mb JSON limit"). Update `description:` to say the request may carry the original and framing, and that a framing-less upload clears them.

- [ ] **Step 6: Run everything and watch it pass** — `cd server && npx tsc --noEmit && npx tsc --noEmit -p fixtures && npm run test:run` → all green (the new request test, the service tests, every existing groups test)

- [ ] **Step 7: Commit** — `feat(group-cover-image): cover upload takes framing + original; PATCH clears them`

- [ ] **Step 8: Record the contract freeze** — after the phase-2 gates pass (the build loop runs them at the phase close), the producer phase closes the contract. Run from the repo root:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/advance.mjs docs/features/group-cover-image \
  --set "contract=frozen $(date +%Y-%m-%d)" --head --commit "chore(group-cover-image): contract frozen — server phase verified"
```

No iPhone task starts before the manifest reads `contract: frozen`.

### Task 5: `UserGroup.coverOriginalUrl` + `coverFraming`, decoding old caches and bad values
App: iphone
Phase: 3
Recipe: SPEC §iphone State · D11 · iphone/.claude/CLAUDE.md (models) · tiny

**Files:**
- Modify: `iphone/MakeReady/State/Models/GroupModels.swift:17-96`
- Test: `iphone/MakeReadyCaptureTests/GroupCoverDecodingTests.swift` (register in `MakeReadyCaptureTests`, sibling `iphone/MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift`)

**Interfaces:**
- Consumes: §Contract row 2 (`coverOriginalUrl: string|null`, `coverFraming: {scale, rotation, offsetX, offsetY}|null`)
- Produces:
  - `struct CoverFraming: Codable, Equatable, Hashable { var scale: Double; var rotation: Double; var offsetX: Double; var offsetY: Double; static let identity; var requestBody: [String: Any] }`
  - `UserGroup.coverOriginalUrl: String?`, `UserGroup.coverFraming: CoverFraming?`; memberwise init gains `coverOriginalUrl: String? = nil, coverFraming: CoverFraming? = nil` (after `coverImageUrl`)

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/GroupCoverDecodingTests.swift`

```swift
import XCTest
@testable import MakeReady

/// group-cover-image §iphone State / D11: the two cover fields decode; a bad framing and an old
/// cache without them never fail the group decode.
final class GroupCoverDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> UserGroup {
        try JSONDecoder.apiDecoder.decode(UserGroup.self, from: Data(json.utf8))
    }

    private let base = #""id":"g1","code":"ABC123","name":"Prayer Team","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-26T12:00:00.000Z","updatedAt":"2026-10-26T12:00:00.000Z""#

    func testDecodesBothFields() throws {
        let group = try decode(#"{\#(base),"coverImageUrl":"https://img/c.jpeg","coverOriginalUrl":"https://img/o.jpeg","coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2}}"#)
        XCTAssertEqual(group.coverOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(group.coverFraming, CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2))
    }

    func testNullFieldsDecodeAsNil() throws {
        let group = try decode(#"{\#(base),"coverOriginalUrl":null,"coverFraming":null}"#)
        XCTAssertNil(group.coverOriginalUrl)
        XCTAssertNil(group.coverFraming)
    }

    /// D11: a bad stored value never fails a group list decode.
    func testBadFramingDecodesAsNilAndKeepsTheGroup() throws {
        let group = try decode(#"{\#(base),"coverFraming":{"scale":"big"}}"#)
        XCTAssertNil(group.coverFraming)
        XCTAssertEqual(group.name, "Prayer Team")
    }

    /// An old disk cache (schemaVersion 1, no migration) carries neither key.
    func testOldCacheRoundTrips() throws {
        let group = try decode("{\(base)}")
        XCTAssertNil(group.coverOriginalUrl)
        XCTAssertNil(group.coverFraming)
        let again = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertNil(again.coverFraming)
    }

    func testFramingRoundTripsThroughTheCache() throws {
        var group = try decode("{\(base)}")
        group.coverFraming = CoverFraming(scale: 3, rotation: -45, offsetX: 0, offsetY: 0.5)
        let again = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertEqual(again.coverFraming, group.coverFraming)
    }

    func testRequestBodyHasTheFourKeys() {
        let body = CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2).requestBody
        XCTAssertEqual(Set(body.keys), ["scale", "rotation", "offsetX", "offsetY"])
        XCTAssertEqual(body["rotation"] as? Double, 15)
    }

    func testIdentity() {
        XCTAssertEqual(CoverFraming.identity, CoverFraming(scale: 1, rotation: 0, offsetX: 0, offsetY: 0))
    }
}
```

- [ ] **Step 2: Register the test file and watch it fail** — run the register command from the Plan notes (`iphone/MakeReadyCaptureTests/GroupCoverDecodingTests.swift iphone/MakeReadyCaptureTests/GroupsBrowseDecodingTests.swift MakeReadyCaptureTests`), then `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'CoverFraming' in scope`

- [ ] **Step 3: Add the model** — in `GroupModels.swift`, above `struct UserGroup`:

```swift
/// group-cover-image D11: how the cover was framed — `scale` relative to the zoom floor (1…8),
/// `rotation` in degrees (−180…180), `offsetX`/`offsetY` as fractions of the frame's width/height
/// from centred (−1…1). The server rejects anything else.
struct CoverFraming: Codable, Equatable, Hashable {
    var scale: Double
    var rotation: Double
    var offsetX: Double
    var offsetY: Double

    /// D7: a cover with no stored original opens at identity — the floor, unrotated, centred.
    static let identity = CoverFraming(scale: 1, rotation: 0, offsetX: 0, offsetY: 0)

    /// The upload body's `framing` (D10).
    var requestBody: [String: Any] {
        ["scale": scale, "rotation": rotation, "offsetX": offsetX, "offsetY": offsetY]
    }
}
```

In `UserGroup`, after `var coverImageUrl: String?`:

```swift
    /// group-cover-image SC1 (D7): the full original photo; nil = Edit reopens `coverImageUrl`.
    var coverOriginalUrl: String?
    /// group-cover-image SC2 (D11): the framing the cover was rendered with. nil on an old cache.
    var coverFraming: CoverFraming?
```

In `init(from:)`, after the `coverImageUrl` line:

```swift
        coverOriginalUrl = try container.decodeIfPresent(String.self, forKey: .coverOriginalUrl)
        // D11: a bad stored value decodes as nil, never failing the group list.
        coverFraming = (try? container.decodeIfPresent(CoverFraming.self, forKey: .coverFraming)) ?? nil
```

In the memberwise init add the parameters `coverOriginalUrl: String? = nil, coverFraming: CoverFraming? = nil,` right after `coverImageUrl: String? = nil,` and assign them. (`CodingKeys` and `encode(to:)` are synthesized from the stored properties.)

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the new class and every existing test); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 5: Commit** — `feat(group-cover-image): UserGroup carries coverOriginalUrl + coverFraming`

### Task 6: `GroupActions.saveCover` on `requestWithStatus` with a timeout
App: iphone
Phase: 3
Recipe: `/ios-error-surface` · SPEC D10, D13 · F6

**Files:**
- Modify: `iphone/MakeReady/State/API/APIClient.swift:209-221` (`requestWithStatus` gains `timeout`), `:450-458` (protocol), extension at `:464-480` (default mirror)
- Modify: `iphone/MakeReadyCaptureTests/StubAPIClient.swift:76-78`
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift` (new `saveCover` after `uploadCoverImage`, ~:361)
- Test: `iphone/MakeReadyCaptureTests/GroupSaveCoverTests.swift` (register in `MakeReadyCaptureTests`, sibling `iphone/MakeReadyCaptureTests/GroupPatchTests.swift`)

**Interfaces:**
- Consumes: Task 5's `CoverFraming`, `UserGroup.coverOriginalUrl/coverFraming`; §Contract row 1
- Produces:
  - `APIClientProtocol.requestWithStatus(endpoint:method:body:timeout:) async throws -> Data`; extension `requestWithStatus(endpoint:method:body:)` = timeout 30 (existing call sites unchanged)
  - `struct CoverSaveResult: Equatable { let coverImageUrl: String; let coverOriginalUrl: String?; let coverFraming: CoverFraming? }`
  - `GroupActions.saveCover(groupId: String, rendered: UIImage, framing: CoverFraming, original: UIImage?) async throws -> CoverSaveResult` — `@MainActor`; throws `APIError.unauthorized` on 401 and `APIHTTPError(status:)` on other non-2xx; on success patches the three fields into `state.groups[groupId]` and persists
  - `GroupActions.coverSaveTimeout: TimeInterval = 120`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/GroupSaveCoverTests.swift`

```swift
import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D10/D13: saveCover posts the rendered cover + framing (+ the original on a new
/// pick) through requestWithStatus and patches the returned fields into AppState.
@MainActor
final class GroupSaveCoverTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let endpoint = "/api/groups/g1/cover-image"
    private let framing = CoverFraming(scale: 2, rotation: 15, offsetX: 0.1, offsetY: -0.2)

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        state.groups.upsert(UserGroup(id: "g1", code: "ABC123", name: "Prayer Team", coverImageUrl: "https://img/old.jpeg",
                                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u1",
                                      createdAt: Date(), updatedAt: Date()))
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func image(_ size: CGSize = CGSize(width: 40, height: 20)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func stubSuccess() {
        api.stub("POST", endpoint, json: #"{"success":true,"coverImageUrl":"https://img/new.jpeg","coverOriginalUrl":"https://img/new-original.jpeg","coverFraming":{"scale":2,"rotation":15,"offsetX":0.1,"offsetY":-0.2}}"#)
    }

    func testNewPickSendsRenderedFramingAndOriginal() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: image())
        let body = try XCTUnwrap(api.calls.last?.body)
        XCTAssertFalse((body["imageData"] as? String ?? "").isEmpty)
        XCTAssertEqual(body["contentType"] as? String, "image/jpeg")
        XCTAssertEqual((body["framing"] as? [String: Any])?["scale"] as? Double, 2)
        XCTAssertFalse((body["originalData"] as? String ?? "").isEmpty)
    }

    func testReEditSendsNoOriginal() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
        XCTAssertNil(api.calls.last?.body?["originalData"])
    }

    func testSuccessPatchesTheThreeFieldsIntoAppState() async throws {
        stubSuccess()
        let result = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: image())
        XCTAssertEqual(result, CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: "https://img/new-original.jpeg", coverFraming: framing))
        let group = try XCTUnwrap(state.groups["g1"])
        XCTAssertEqual(group.coverImageUrl, "https://img/new.jpeg")
        XCTAssertEqual(group.coverOriginalUrl, "https://img/new-original.jpeg")
        XCTAssertEqual(group.coverFraming, framing)
    }

    /// F6: the status survives — a 404 is APIHTTPError(404), not a folded serverError.
    func testNotFoundKeepsItsStatus() async {
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        do {
            _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: 404, message: "Group not found"))
        }
        XCTAssertEqual(state.groups["g1"]?.coverImageUrl, "https://img/old.jpeg")
    }

    func testRenderedIsJPEGBase64() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
        let b64 = try XCTUnwrap(api.calls.last?.body?["imageData"] as? String)
        let data = try XCTUnwrap(Data(base64Encoded: b64))
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])   // JPEG SOI
    }
}
```

- [ ] **Step 2: Register and watch it fail** — register (`iphone/MakeReadyCaptureTests/GroupSaveCoverTests.swift iphone/MakeReadyCaptureTests/GroupPatchTests.swift MakeReadyCaptureTests`), then `npm run ios:build-check -- --test` → FAIL to compile, `value of type 'GroupActions' has no member 'saveCover'`

- [ ] **Step 3: The timeout parameter** — in `APIClient.swift`:

```swift
    /// ui2-members-edit T6: an uncoalesced request whose non-2xx failure keeps its HTTP status
    /// (`APIHTTPError`). Opt-in: `MemberActions.updateMember`, `GroupActions.saveCover`.
    /// group-cover-image D13: `timeout` (30 by default) — the cover upload needs 120.
    func requestWithStatus(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data {
        let request = try buildRequest(endpoint: endpoint, method: method, body: body, timeout: timeout)
        // …rest unchanged
```

The protocol requirement becomes `func requestWithStatus(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data`, and the protocol extension gains:

```swift
    func requestWithStatus(endpoint: String, method: String, body: [String: Any]?) async throws -> Data {
        try await requestWithStatus(endpoint: endpoint, method: method, body: body, timeout: 30)
    }
```

`StubAPIClient.requestWithStatus` becomes `func requestWithStatus(endpoint: String, method: String, body: [String: Any]?, timeout: TimeInterval) async throws -> Data { try await request(endpoint: endpoint, method: method, body: body, timeout: timeout) }`. If any other type conforms to `APIClientProtocol` (`grep -rn "APIClientProtocol" iphone --include=*.swift`), update it the same way.

- [ ] **Step 4: The Action** — in `GroupActions.swift`, after `uploadCoverImage`:

```swift
    /// group-cover-image D13: the cover upload's long timeout (two images, ≤ ~4.5MB, D16).
    static let coverSaveTimeout: TimeInterval = 120

    /// group-cover-image D10/D13: upload the rendered cover (JPEG 0.9) with its framing — and the
    /// original on a new pick — then patch the three returned fields into the group and persist.
    /// Uses `requestWithStatus` so a 404 keeps its status (F6); a 401 throws `.unauthorized`.
    @MainActor
    func saveCover(groupId: String, rendered: UIImage, framing: CoverFraming, original: UIImage?) async throws -> CoverSaveResult {
        struct Response: Decodable {
            let success: Bool
            let coverImageUrl: String?
            let coverOriginalUrl: String?
            let coverFraming: CoverFraming?
            let error: String?
        }
        guard let renderedJPEG = rendered.jpegData(compressionQuality: 0.9) else {
            throw APIError.serverError("Couldn't encode the cover")
        }
        var body: [String: Any] = [
            "imageData": renderedJPEG.base64EncodedString(),
            "contentType": "image/jpeg",
            "framing": framing.requestBody
        ]
        if let original {
            guard let originalJPEG = original.jpegData(compressionQuality: 0.9) else {
                throw APIError.serverError("Couldn't encode the original photo")
            }
            body["originalData"] = originalJPEG.base64EncodedString()
        }

        let data = try await api.requestWithStatus(endpoint: "/api/groups/\(groupId)/cover-image", method: "POST",
                                                   body: body, timeout: Self.coverSaveTimeout)
        let response = try JSONDecoder.apiDecoder.decode(Response.self, from: data)
        guard response.success, let url = response.coverImageUrl else {
            throw APIError.serverError(response.error ?? "Failed to save the cover")
        }
        let result = CoverSaveResult(coverImageUrl: url, coverOriginalUrl: response.coverOriginalUrl,
                                     coverFraming: response.coverFraming)
        if var group = state.groups[groupId] {
            group.coverImageUrl = result.coverImageUrl
            group.coverOriginalUrl = result.coverOriginalUrl
            group.coverFraming = result.coverFraming
            state.groups.upsert(group)
            state.persist()
        }
        return result
    }
```

And, at file scope below `struct GroupActions`:

```swift
/// group-cover-image D10: the three fields the cover upload returns.
struct CoverSaveResult: Equatable {
    let coverImageUrl: String
    let coverOriginalUrl: String?
    let coverFraming: CoverFraming?
}
```

- [ ] **Step 5: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (incl. the existing `MemberActions` tests through the defaulted overload); swiftlint from `iphone/` → no new violations

- [ ] **Step 6: Commit** — `feat(group-cover-image): GroupActions.saveCover on requestWithStatus (120s)`

### Task 7: Cover framing math — zoom floor, pan clamp, ±3° snap, relative scale
App: iphone
Phase: 4
Recipe: SPEC D5, D11 · iphone/.claude/CLAUDE.md

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/CoverFramingMath.swift` (register in `MakeReady`, sibling `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Test: `iphone/MakeReadyCaptureTests/CoverFramingMathTests.swift` (register in `MakeReadyCaptureTests`, sibling `GroupPatchTests.swift`)

**Interfaces:**
- Consumes: Task 5's `CoverFraming`
- Produces: `enum CoverFramingMath` with
  - `static let frameAspect: CGFloat = 408.0 / 180.0`, `static let maxRelativeScale: Double = 8`, `static let snapDegrees: Double = 3`
  - `static func zoomFloor(image: CGSize, frame: CGSize, rotationDegrees: Double) -> CGFloat` — the smallest absolute scale (image points → frame points) at which the rotated image covers the frame
  - `static func clamped(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CoverFraming` — scale into 1…8, rotation normalised into −180…180, offsets pulled back until the frame is covered
  - `static func snapped(rotationDegrees: Double) -> Double` — 0 within ±3°, else the input normalised
  - `static func normalized(degrees: Double) -> Double`
  - `static func absoluteScale(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CGFloat` = `framing.scale × zoomFloor`
  - `static func imageCenter(_ framing: CoverFraming, frame: CGSize) -> CGPoint` — the image centre's offset from the frame centre, in frame points (`offsetX × frame.width`, `offsetY × frame.height`)

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/CoverFramingMathTests.swift`

```swift
import XCTest
@testable import MakeReady

/// group-cover-image D5/D11: no empty corners at any rotation; scale is relative to the floor.
final class CoverFramingMathTests: XCTestCase {
    private let frame = CGSize(width: 408, height: 180)
    private let wide = CGSize(width: 2400, height: 1600)
    private let tall = CGSize(width: 1200, height: 2400)

    /// Every frame corner, mapped into the image's own axes, lies inside the scaled image.
    private func covers(_ f: CoverFraming, image: CGSize, accuracy: CGFloat = 0.01) -> Bool {
        let s = CoverFramingMath.absoluteScale(f, image: image, frame: frame)
        let c = CoverFramingMath.imageCenter(f, frame: frame)
        let t = f.rotation * .pi / 180
        let corners = [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].map {
            CGPoint(x: $0.0 * frame.width / 2, y: $0.1 * frame.height / 2)
        }
        return corners.allSatisfy { p in
            let dx = p.x - c.x, dy = p.y - c.y
            let u = dx * cos(t) + dy * sin(t), v = -dx * sin(t) + dy * cos(t)
            return abs(u) <= s * image.width / 2 + accuracy && abs(v) <= s * image.height / 2 + accuracy
        }
    }

    func testFloorAtZeroIsTheCoverFit() {
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0), 408.0 / 2400.0, accuracy: 1e-6)
        XCTAssertEqual(CoverFramingMath.zoomFloor(image: tall, frame: frame, rotationDegrees: 0), 408.0 / 1200.0, accuracy: 1e-6)
    }

    func testFloorCoversAt0_45_90ForWideAndTall() {
        for image in [wide, tall] {
            for deg in [0.0, 45, 90, -30, 180] {
                let f = CoverFraming(scale: 1, rotation: deg, offsetX: 0, offsetY: 0)
                XCTAssertTrue(covers(f, image: image), "\(image) at \(deg)°")
                // …and is the smallest such scale: 1% below it leaves a corner empty.
                let floor = CoverFramingMath.zoomFloor(image: image, frame: frame, rotationDegrees: deg)
                let below = CoverFraming(scale: 0.99, rotation: deg, offsetX: 0, offsetY: 0)
                XCTAssertGreaterThan(floor, 0)
                XCTAssertFalse(covers(below, image: image, accuracy: 0), "\(image) at \(deg)° not minimal")
            }
        }
    }

    func testFloorGrowsWithRotation() {
        let f0 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 0)
        let f45 = CoverFramingMath.zoomFloor(image: wide, frame: frame, rotationDegrees: 45)
        XCTAssertGreaterThan(f45, f0)
    }

    func testClampPullsAnOffsetBackUntilCovered() {
        for deg in [0.0, 20, 45, 90] {
            let wild = CoverFraming(scale: 1.5, rotation: deg, offsetX: 1, offsetY: -1)
            let c = CoverFramingMath.clamped(wild, image: wide, frame: frame)
            XCTAssertTrue(covers(c, image: wide), "\(deg)°")
        }
    }

    func testClampAtTheFloorCentres() {
        let c = CoverFramingMath.clamped(CoverFraming(scale: 1, rotation: 0, offsetX: 0.5, offsetY: 0.5), image: wide, frame: frame)
        // wide at floor: width fits exactly, so no horizontal slack.
        XCTAssertEqual(c.offsetX, 0, accuracy: 1e-6)
        XCTAssertNotEqual(c.offsetY, 0)   // 2400×1600 at 0.17 is 272pt tall in a 180pt frame: vertical slack exists
    }

    func testClampKeepsALegalOffset() {
        let f = CoverFraming(scale: 2, rotation: 0, offsetX: 0.1, offsetY: 0.05)
        XCTAssertEqual(CoverFramingMath.clamped(f, image: wide, frame: frame), f)
    }

    func testScaleIsClampedTo1Through8() {
        XCTAssertEqual(CoverFramingMath.clamped(CoverFraming(scale: 0.4, rotation: 0, offsetX: 0, offsetY: 0), image: wide, frame: frame).scale, 1)
        XCTAssertEqual(CoverFramingMath.clamped(CoverFraming(scale: 12, rotation: 0, offsetX: 0, offsetY: 0), image: wide, frame: frame).scale, 8)
    }

    func testSnap() {
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 2.9), 0)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: -3), 0)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 3.1), 3.1, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.snapped(rotationDegrees: 358), 0)          // −2° after normalising
        XCTAssertEqual(CoverFramingMath.normalized(degrees: 190), -170, accuracy: 1e-9)
        XCTAssertEqual(CoverFramingMath.normalized(degrees: -190), 170, accuracy: 1e-9)
    }

    /// D11: scale is relative to the floor, so the same framing reproduces the same crop at a
    /// different frame size (the 1200×529 render vs the on-screen frame).
    func testRelativeScaleRoundTripsAcrossFrameSizes() {
        let f = CoverFraming(scale: 2.5, rotation: 30, offsetX: 0.05, offsetY: -0.1)
        let big = CGSize(width: 1200, height: 1200 / CoverFramingMath.frameAspect)
        let sSmall = CoverFramingMath.absoluteScale(f, image: wide, frame: frame)
        let sBig = CoverFramingMath.absoluteScale(f, image: wide, frame: big)
        XCTAssertEqual(sBig / sSmall, big.width / frame.width, accuracy: 1e-3)
        XCTAssertEqual(CoverFramingMath.clamped(f, image: wide, frame: big), CoverFramingMath.clamped(f, image: wide, frame: frame))
    }
}
```

- [ ] **Step 2: Register both files (the source file empty with `import CoreGraphics` for now) and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'CoverFramingMath' in scope`

- [ ] **Step 3: Write `CoverFramingMath.swift`**

```swift
import CoreGraphics
import Foundation

/// group-cover-image D5/D11: the Edit cover geometry, pure. Frame and image sizes are in points;
/// rotation in degrees; the image is centred on the frame centre plus `imageCenter`.
///
/// Coverage: the frame, mapped into the image's own (unrotated) axes, has half-extents
/// `ex = (w|cos θ| + h|sin θ|)/2`, `ey = (w|sin θ| + h|cos θ|)/2`. The frame centre, in the same
/// axes, must stay within `(s·iw/2 − ex, s·ih/2 − ey)` of the image centre.
enum CoverFramingMath {
    /// D5: the cover's aspect, 408:180.
    static let frameAspect: CGFloat = 408.0 / 180.0
    /// D5: the zoom ceiling, relative to the floor.
    static let maxRelativeScale: Double = 8
    /// D5: rotation snaps to 0° when released within this.
    static let snapDegrees: Double = 3

    static func normalized(degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    static func snapped(rotationDegrees: Double) -> Double {
        let d = normalized(degrees: rotationDegrees)
        return abs(d) <= snapDegrees ? 0 : d
    }

    private static func halfExtents(frame: CGSize, radians t: Double) -> (CGFloat, CGFloat) {
        let c = CGFloat(abs(cos(t))), s = CGFloat(abs(sin(t)))
        return ((frame.width * c + frame.height * s) / 2, (frame.width * s + frame.height * c) / 2)
    }

    /// D5: the smallest absolute scale at which the image, rotated, covers the frame.
    static func zoomFloor(image: CGSize, frame: CGSize, rotationDegrees: Double) -> CGFloat {
        guard image.width > 0, image.height > 0 else { return 1 }
        let (ex, ey) = halfExtents(frame: frame, radians: rotationDegrees * .pi / 180)
        return max(2 * ex / image.width, 2 * ey / image.height)
    }

    static func absoluteScale(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CGFloat {
        CGFloat(framing.scale) * zoomFloor(image: image, frame: frame, rotationDegrees: framing.rotation)
    }

    static func imageCenter(_ framing: CoverFraming, frame: CGSize) -> CGPoint {
        CGPoint(x: CGFloat(framing.offsetX) * frame.width, y: CGFloat(framing.offsetY) * frame.height)
    }

    /// D5/D11: scale into 1…8, rotation into −180…180, and the offset pulled back (in the image's
    /// axes) until the frame is covered. A legal framing comes back unchanged.
    static func clamped(_ framing: CoverFraming, image: CGSize, frame: CGSize) -> CoverFraming {
        var f = framing
        f.scale = min(max(f.scale, 1), maxRelativeScale)
        f.rotation = normalized(degrees: f.rotation)
        guard frame.width > 0, frame.height > 0 else { return f }

        let t = f.rotation * .pi / 180
        let s = absoluteScale(f, image: image, frame: frame)
        let (ex, ey) = halfExtents(frame: frame, radians: t)
        let maxU = max(0, s * image.width / 2 - ex)
        let maxV = max(0, s * image.height / 2 - ey)

        // The frame centre relative to the image centre is −p; into image axes by R(−θ).
        let p = imageCenter(f, frame: frame)
        let ct = CGFloat(cos(t)), st = CGFloat(sin(t))
        var u = -p.x * ct - p.y * st
        var v = p.x * st - p.y * ct
        guard abs(u) > maxU || abs(v) > maxV else { return f }
        u = min(max(u, -maxU), maxU)
        v = min(max(v, -maxV), maxV)
        // Back to frame axes: p = −R(θ)·(u, v).
        let px = -(u * ct - v * st)
        let py = -(u * st + v * ct)
        f.offsetX = Double(px / frame.width)
        f.offsetY = Double(py / frame.height)
        return f
    }
}
```

The image is drawn rotated by +θ about its own centre, so the frame's corners in image axes are `R(−θ)(corner − p)`; the test's `covers` uses the same convention.

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; swiftlint from `iphone/` → no new violations

- [ ] **Step 5: Commit** — `feat(group-cover-image): cover framing math — floor, clamp, snap (D5)`

### Task 8: The 1200×529 render and the ≤ 2400px upright pick
App: iphone
Phase: 4
Recipe: SPEC D3, D12, F9

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/CoverImageRendering.swift` (register in `MakeReady`, sibling `GroupDetailContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Test: `iphone/MakeReadyCaptureTests/CoverImageRenderingTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: Task 7's `CoverFramingMath`; Task 5's `CoverFraming`
- Produces: `enum CoverImageRendering` with
  - `static let renderSize = CGSize(width: 1200, height: 529)` (D12), `static let originalMaxPixels: CGFloat = 2400` (D3)
  - `static func render(_ image: UIImage, framing: CoverFraming) -> UIImage` — 1200×529 at scale 1, opaque, exactly the frame's content
  - `static func uprightDownsampled(_ data: Data, maxPixels: CGFloat = originalMaxPixels) -> UIImage?` — ImageIO thumbnail with the EXIF transform applied, longest side ≤ `maxPixels`, `imageOrientation == .up`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/CoverImageRenderingTests.swift`

```swift
import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import MakeReady

/// group-cover-image D3/D12: the render is 1200×529 and shows the framed region; the pick is
/// upright and ≤ 2400px.
final class CoverImageRenderingTests: XCTestCase {
    /// Left half red, right half blue.
    private func halves(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            UIColor.blue.setFill(); ctx.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
        }
    }

    private func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        let cg = image.cgImage!
        var buf = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &buf, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (buf[0], buf[1], buf[2])
    }

    func testRenderIs1200x529AtScale1() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertEqual(out.cgImage?.width, 1200)
        XCTAssertEqual(out.cgImage?.height, 529)
    }

    func testIdentityShowsBothHalves() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity)
        XCTAssertGreaterThan(pixel(out, 100, 264).r, 200)    // left = red
        XCTAssertGreaterThan(pixel(out, 1100, 264).b, 200)   // right = blue
    }

    /// Image centre moved right by a quarter frame → the frame's left edge now shows… more red.
    func testOffsetMovesTheContent() {
        let zoomed = CoverFraming(scale: 2, rotation: 0, offsetX: 0.25, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: zoomed)
        XCTAssertGreaterThan(pixel(out, 700, 264).r, 200)    // the red/blue seam moved right of centre
    }

    func testRotationLeavesNoEmptyCorners() {
        let f = CoverFraming(scale: 1, rotation: 45, offsetX: 0, offsetY: 0)
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: f)
        for (x, y) in [(1, 1), (1198, 1), (1, 527), (1198, 527)] {
            let p = pixel(out, x, y)
            XCTAssertTrue(p.r > 200 || p.b > 200, "corner \(x),\(y) is \(p)")
        }
    }

    func testPickIsDownsampledTo2400() throws {
        let data = try XCTUnwrap(halves(CGSize(width: 4000, height: 1000)).jpegData(compressionQuality: 0.9))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data))
        XCTAssertEqual(max(out.size.width * out.scale, out.size.height * out.scale), 2400, accuracy: 1)
        XCTAssertEqual(out.imageOrientation, .up)
    }

    func testSmallPickIsNotEnlarged() throws {
        let data = try XCTUnwrap(halves(CGSize(width: 800, height: 600)).jpegData(compressionQuality: 0.9))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data))
        XCTAssertEqual(out.size.width * out.scale, 800, accuracy: 1)
    }

    /// An EXIF-rotated JPEG (orientation 6 = 90° CW): 800×600 stored pixels come back upright as 600×800.
    func testExifOrientationIsApplied() throws {
        let src = halves(CGSize(width: 800, height: 600)).cgImage!
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, src, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let out = try XCTUnwrap(CoverImageRendering.uprightDownsampled(data as Data))
        XCTAssertEqual(out.size.width * out.scale, 600, accuracy: 1)
        XCTAssertEqual(out.size.height * out.scale, 800, accuracy: 1)
        XCTAssertEqual(out.imageOrientation, .up)
    }

    func testJunkDataIsNil() {
        XCTAssertNil(CoverImageRendering.uprightDownsampled(Data("not an image".utf8)))
    }
}
```

(If `pixel`'s flipped-coordinate draw is off by a row, sample a few pixels in from the edges — the assertions are about colour regions, not exact pixels.)

- [ ] **Step 2: Register and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'CoverImageRendering' in scope`

- [ ] **Step 3: Write `CoverImageRendering.swift`**

```swift
import ImageIO
import UIKit

/// group-cover-image D12: the phone renders exactly what the Edit cover frame shows; D3: a pick is
/// made upright and ≤ 2400px before Edit cover opens (memory, and D16's body size).
enum CoverImageRendering {
    /// D12: 408:180 at 1200 wide.
    static let renderSize = CGSize(width: 1200, height: 529)
    /// D3 / D10: the original's longest side.
    static let originalMaxPixels: CGFloat = 2400

    /// D12: the framed image at `renderSize`, scale 1, opaque. `UIImage.draw(in:)` applies the
    /// image's orientation (`APIClient.resizeImageIfNeeded` does not).
    static func render(_ image: UIImage, framing: CoverFraming) -> UIImage {
        let frame = renderSize
        let f = CoverFramingMath.clamped(framing, image: image.size, frame: frame)
        let scale = CoverFramingMath.absoluteScale(f, image: image.size, frame: frame)
        let center = CoverFramingMath.imageCenter(f, frame: frame)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: frame, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: frame.width / 2 + center.x, y: frame.height / 2 + center.y)
            cg.rotate(by: CGFloat(f.rotation * .pi / 180))
            let w = image.size.width * scale, h = image.size.height * scale
            image.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
    }

    /// D3: decode with the EXIF transform applied, longest side ≤ `maxPixels`, never enlarged.
    static func uprightDownsampled(_ data: Data, maxPixels: CGFloat = originalMaxPixels) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        let w = (props[kCGImagePropertyPixelWidth] as? CGFloat) ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? CGFloat) ?? 0
        guard w > 0, h > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maxPixels, max(w, h))
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; swiftlint from `iphone/` → no new violations

- [ ] **Step 5: Commit** — `feat(group-cover-image): 1200×529 cover render + upright ≤2400px pick`

### Task 9: `EditGroupCoverModel` — gesture state, D6/D7 opening, D13 save outcomes
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · SPEC D5, D6, D7, D13

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverModel.swift` (register in `MakeReady`, sibling `GroupDetailContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Test: `iphone/MakeReadyCaptureTests/EditGroupCoverModelTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: Task 6 `GroupActions.saveCover`, `CoverSaveResult`; Task 7 `CoverFramingMath`; Task 8 `CoverImageRendering.render`; `Ui2ImageCache.shared.seed(_:for:)`
- Produces:
  - `enum CoverEditSource: Hashable { case newPick(UIImage); case stored }`
  - `@MainActor @Observable final class EditGroupCoverModel` — `init(groupId: String, image: UIImage, framing: CoverFraming, isNewPick: Bool, frameSize: CGSize, save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult)`; `private(set) var framing: CoverFraming`; `private(set) var isSaving: Bool`; `func updateGesture(magnification: CGFloat, rotationDegrees: Double, translation: CGSize)`; `func endGesture()`; `func save() async -> SaveOutcome`
  - `enum EditGroupCoverModel.SaveOutcome: Equatable { case saved, ignored, unauthorized, gone, failed(String) }`
  - `static func opening(group: UserGroup) -> (url: String, framing: CoverFraming)?` — D7: `coverOriginalUrl` at `coverFraming ?? .identity`; no original → `coverImageUrl` at `.identity`; no cover → nil
  - `static let saveFailedMessage = "Couldn't save the cover"`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EditGroupCoverModelTests.swift`

```swift
import XCTest
import UIKit
@testable import MakeReady

/// group-cover-image D5/D6/D7/D13: the Edit cover page's state, without the view.
@MainActor
final class EditGroupCoverModelTests: XCTestCase {
    private let frame = CGSize(width: 408, height: 180)
    private func image(_ size: CGSize = CGSize(width: 2400, height: 1600)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    private let ok = CoverSaveResult(coverImageUrl: "https://img/new.jpeg", coverOriginalUrl: "https://img/o.jpeg", coverFraming: .identity)

    private func model(isNewPick: Bool = true, framing: CoverFraming = .identity,
                       save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult) -> EditGroupCoverModel {
        EditGroupCoverModel(groupId: "g1", image: image(), framing: framing, isNewPick: isNewPick, frameSize: frame, save: save)
    }

    /// D6: a new pick opens centred at the floor, unrotated.
    func testNewPickOpensAtIdentity() {
        XCTAssertEqual(model(save: { _, _, _ in self.ok }).framing, .identity)
    }

    func testPinchRotatePanTogetherThenSnapOnRelease() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 2, rotationDegrees: 2, translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(m.framing.scale, 2, accuracy: 1e-9)
        XCTAssertEqual(m.framing.rotation, 2, accuracy: 1e-9)
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 0)                    // D5 ±3° snap on release
        m.updateGesture(magnification: 1, rotationDegrees: 20, translation: .zero)
        m.endGesture()
        XCTAssertEqual(m.framing.rotation, 20, accuracy: 1e-9)   // cumulative from the committed base
        XCTAssertEqual(m.framing.scale, 2, accuracy: 1e-9)
    }

    func testZoomIsClampedToTheFloorAndTheCeiling() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 0.2, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 1)
        m.updateGesture(magnification: 50, rotationDegrees: 0, translation: .zero)
        XCTAssertEqual(m.framing.scale, 8)
    }

    func testPanIsClamped() {
        let m = model(save: { _, _, _ in self.ok })
        m.updateGesture(magnification: 1, rotationDegrees: 0, translation: CGSize(width: 5000, height: 0))
        XCTAssertEqual(m.framing.offsetX, 0, accuracy: 1e-6)    // no horizontal slack at the floor for a wide image
    }

    /// D13: a new pick sends the original; a re-edit does not.
    func testSaveSendsTheOriginalOnlyForANewPick() async {
        var originals: [Bool] = []
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult = { _, _, o in originals.append(o != nil); return self.ok }
        _ = await model(isNewPick: true, save: save).save()
        _ = await model(isNewPick: false, save: save).save()
        XCTAssertEqual(originals, [true, false])
    }

    func testSaveRendersAt1200x529() async {
        var size: CGSize?
        _ = await model(save: { r, _, _ in size = CGSize(width: r.cgImage!.width, height: r.cgImage!.height); return self.ok }).save()
        XCTAssertEqual(size, CGSize(width: 1200, height: 529))
    }

    /// D13: a second Save while saving is ignored.
    func testSecondSaveWhileSavingIsIgnored() async {
        var calls = 0
        let m = model(save: { _, _, _ in calls += 1; try await Task.sleep(nanoseconds: 200_000_000); return self.ok })
        async let first = m.save()
        await Task.yield()
        XCTAssertTrue(m.isSaving)
        let second = await m.save()
        XCTAssertEqual(second, .ignored)
        XCTAssertEqual(await first, .saved)
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(m.isSaving)
    }

    /// D13: success seeds the cache under the new URL so the cover does not flash the placeholder.
    func testSuccessSeedsTheImageCache() async {
        let url = "https://img/seed-\(UUID().uuidString).jpeg"
        let m = model(save: { _, _, _ in CoverSaveResult(coverImageUrl: url, coverOriginalUrl: nil, coverFraming: nil) })
        XCTAssertEqual(await m.save(), .saved)
        XCTAssertNotNil(Ui2ImageCache.shared.image(for: URL(string: url)!))
    }

    func testOutcomes() async {
        XCTAssertEqual(await model(save: { _, _, _ in throw APIError.unauthorized }).save(), .unauthorized)
        XCTAssertEqual(await model(save: { _, _, _ in throw APIHTTPError(status: 404, message: nil) }).save(), .gone)
        XCTAssertEqual(await model(save: { _, _, _ in throw APIHTTPError(status: 500, message: "x") }).save(), .failed("x"))
        XCTAssertEqual(await model(save: { _, _, _ in throw APIError.networkError(URLError(.timedOut)) }).save(),
                       .failed(APIError.networkError(URLError(.timedOut)).localizedDescription))
    }

    /// D7: the original at its framing; no original → the cover at identity; no cover → nil.
    func testOpening() {
        func group(cover: String?, original: String?, framing: CoverFraming?) -> UserGroup {
            UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original, coverFraming: framing,
                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
        }
        let f = CoverFraming(scale: 3, rotation: 10, offsetX: 0, offsetY: 0)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: f))?.url, "o")
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: f))?.framing, f)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: "o", framing: nil))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: nil, framing: f))?.url, "c")
        XCTAssertEqual(EditGroupCoverModel.opening(group: group(cover: "c", original: nil, framing: f))?.framing, .identity)
        XCTAssertNil(EditGroupCoverModel.opening(group: group(cover: nil, original: nil, framing: nil)))
    }
}
```

- [ ] **Step 2: Register and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'EditGroupCoverModel' in scope`

- [ ] **Step 3: Write `EditGroupCoverModel.swift`**

```swift
import Observation
import UIKit

/// group-cover-image §iphone Edit cover: where the page opens from (D1/D2 → D6/D7).
enum CoverEditSource: Hashable {
    /// D6: a photo just picked, already upright and ≤ 2400px (D3).
    case newPick(UIImage)
    /// D7: the stored original (or the cover itself) at its stored framing.
    case stored
}

/// group-cover-image D5/D6/D7/D13: the Edit cover page's state. Gestures accumulate on a committed
/// base (pinch × scale, rotate + degrees, pan + points) and every change is clamped (D5); release
/// snaps the rotation. Save renders what the frame shows (D12) and maps the result to an outcome
/// the container routes.
@MainActor
@Observable
final class EditGroupCoverModel {
    enum SaveOutcome: Equatable { case saved, ignored, unauthorized, gone, failed(String) }

    static let saveFailedMessage = "Couldn't save the cover"

    let groupId: String
    let image: UIImage
    let isNewPick: Bool
    let frameSize: CGSize
    private(set) var framing: CoverFraming
    private(set) var isSaving = false
    private var base: CoverFraming
    @ObservationIgnored private let send: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult

    init(groupId: String, image: UIImage, framing: CoverFraming, isNewPick: Bool, frameSize: CGSize,
         save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult) {
        self.groupId = groupId
        self.image = image
        self.isNewPick = isNewPick
        self.frameSize = frameSize
        let start = CoverFramingMath.clamped(framing, image: image.size, frame: frameSize)
        self.framing = start
        self.base = start
        self.send = save
    }

    /// D5: pinch, rotate and pan together, relative to the committed base. Ignored while saving.
    func updateGesture(magnification: CGFloat, rotationDegrees: Double, translation: CGSize) {
        guard !isSaving else { return }
        var next = base
        next.scale = base.scale * Double(magnification)
        next.rotation = base.rotation + rotationDegrees
        next.offsetX = base.offsetX + Double(translation.width / frameSize.width)
        next.offsetY = base.offsetY + Double(translation.height / frameSize.height)
        framing = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
    }

    /// D5: release — snap within ±3°, re-clamp (the floor changes with rotation), commit.
    func endGesture() {
        var next = framing
        next.rotation = CoverFramingMath.snapped(rotationDegrees: next.rotation)
        framing = CoverFramingMath.clamped(next, image: image.size, frame: frameSize)
        base = framing
    }

    /// D13: one save at a time; success seeds Ui2ImageCache under the new URL.
    func save() async -> SaveOutcome {
        guard !isSaving else { return .ignored }
        isSaving = true
        defer { isSaving = false }
        let rendered = CoverImageRendering.render(image, framing: framing)
        do {
            let result = try await send(rendered, framing, isNewPick ? image : nil)
            if let url = URL(string: result.coverImageUrl) { Ui2ImageCache.shared.seed(rendered, for: url) }
            return .saved
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { return .unauthorized }
            if let http = error as? APIHTTPError, http.status == 404 { return .gone }
            return .failed(error.localizedDescription)
        }
    }

    /// D7: Edit image reopens the original at its framing; a cover with no original opens the
    /// cover itself at identity; no cover → nil (the menu is not offered then, D2).
    static func opening(group: UserGroup) -> (url: String, framing: CoverFraming)? {
        if let original = group.coverOriginalUrl, !original.isEmpty {
            return (original, group.coverFraming ?? .identity)
        }
        if let cover = group.coverImageUrl, !cover.isEmpty { return (cover, .identity) }
        return nil
    }
}
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; swiftlint from `iphone/` → no new violations

- [ ] **Step 5: Commit** — `feat(group-cover-image): EditGroupCoverModel — gestures, D7 opening, D13 outcomes`

### Task 10: The full-screen cover viewer (D8)
App: iphone
Phase: 5
Recipe: `/present-overlay` · SPEC D8 · F3 (build-made, routed to `/ui2-resolve` after the build)

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/CoverViewerOverlay.swift` (register in `MakeReady`, sibling `GroupDetailContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Test: `iphone/MakeReadyCaptureTests/CoverViewerOverlayTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: `UI2HostedOverlay`, `UI2HostedOverlayKey`, `\.ui2HostsOverlays` (`MakeReadyUI/FilterMenuOverlay.swift:364-410`); `Token.layoutBackground`; `Ui2ImageCache`; `MemberProfileContainer.seedCovers`
- Produces:
  - `struct CoverViewerOverlay: View { let url: String; let onClose: () -> Void }`
  - `extension View { func coverViewerPresentation(url: String?, onClose: @escaping () -> Void) -> some View }` — presents when `url` is non-nil, through the shell's overlay host (in place elsewhere)
  - `static func CoverViewerOverlay.viewerURL(group: UserGroup) -> String?` = `coverOriginalUrl ?? coverImageUrl` (non-empty)
  - `static let CoverViewerOverlay.dismissDistance: CGFloat = 80`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/CoverViewerOverlayTests.swift`

```swift
import XCTest
@testable import MakeReady

/// group-cover-image D8: the viewer shows the original when there is one, else the cover.
final class CoverViewerOverlayTests: XCTestCase {
    private func group(cover: String?, original: String?) -> UserGroup {
        UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original,
                  isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testViewerShowsTheOriginalFirst() {
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "o")), "o")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: nil)), "c")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "")), "c")
        XCTAssertNil(CoverViewerOverlay.viewerURL(group: group(cover: nil, original: nil)))
    }

    func testSwipeDownPastTheThresholdCloses() {
        XCTAssertTrue(CoverViewerOverlay.closes(dragHeight: 81))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: 40))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: -200))
    }
}
```

- [ ] **Step 2: Register and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'CoverViewerOverlay' in scope`

- [ ] **Step 3: Write `CoverViewerOverlay.swift`**

```swift
import SwiftUI

/// group-cover-image D8: the whole original, aspect-fit over `color-layout-background` at 0.95;
/// tap anywhere or swipe down closes it; no zoom in v1. Build-made (no d2m design) — routed to
/// `/ui2-resolve` after the build (F3).
struct CoverViewerOverlay: View {
    let url: String
    let onClose: () -> Void

    /// GAP — no design: a downward drag past this closes the viewer (the C-066 sheet's threshold).
    static let dismissDistance: CGFloat = 80

    @State private var image: UIImage?
    @State private var drag: CGFloat = 0

    static func viewerURL(group: UserGroup) -> String? {
        if let original = group.coverOriginalUrl, !original.isEmpty { return original }
        if let cover = group.coverImageUrl, !cover.isEmpty { return cover }
        return nil
    }

    static func closes(dragHeight: CGFloat) -> Bool { dragHeight > dismissDistance }

    var body: some View {
        ZStack {
            Token.layoutBackground.opacity(0.95).ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .offset(y: max(0, drag))
                    .accessibilityLabel("Group cover")
            } else {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { value in
                    if Self.closes(dragHeight: value.translation.height) { onClose() } else {
                        withAnimation(Token.Motion.menuFadeOut) { drag = 0 }
                    }
                }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onClose() }
        .task(id: url) {
            guard let u = URL(string: url) else { return }
            if Ui2ImageCache.shared.image(for: u) == nil { _ = await MemberProfileContainer.seedCovers([url]) }
            image = Ui2ImageCache.shared.image(for: u)
        }
    }
}

private struct CoverViewerPresentation: ViewModifier {
    let url: String?
    let onClose: () -> Void
    @Environment(\.ui2HostsOverlays) private var hosted

    func body(content: Content) -> some View {
        let layer = url.map { CoverViewerOverlay(url: $0, onClose: onClose) }
        if hosted {
            content.preference(key: UI2HostedOverlayKey.self,
                               value: layer.map { UI2HostedOverlay(view: AnyView($0)) })
        } else {
            content.overlay { if let layer { layer } }
        }
    }
}

extension View {
    /// D8: presents the viewer while `url` is non-nil, through the shell's `.ui2OverlayHost()`
    /// (crossfade, the filter-menu default). Present it only after any C-066 menu has finished
    /// sliding out — the host keeps the first presented overlay (`FilterMenuOverlay.swift:384-389`).
    func coverViewerPresentation(url: String?, onClose: @escaping () -> Void) -> some View {
        modifier(CoverViewerPresentation(url: url, onClose: onClose))
    }
}
```

If `Token.Motion.menuFadeOut` is not an `Animation`, use the motion token the C-066 sheet uses (`ActionMenuMotion.slide`). Run `/transition-review` over this file before committing.

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS; swiftlint from `iphone/` → no new violations

- [ ] **Step 5: Commit** — `feat(group-cover-image): full-screen cover viewer (D8)`

### Task 11: Edit cover page — wire the d2m-built screen to `EditGroupCoverModel`, route `.editGroupCover`
App: iphone
Phase: 5
Recipe: `/push-page` · `/ios-error-surface` · SPEC D4, D5, D6, D7, D13 · ⚠ build-time risk F1

> **⚠ build-time risk (F1):** Edit cover (Figma 4724:53609, title "Edit cover") must already be specced and built in d2m by the owner. **First step:** find it — `grep -rl "4724:53609\|Edit cover" iphone/MakeReadyUI docs/ui2/screens`. Expected under `iphone/MakeReadyUI/Screens/Groups/` (the `GroupsDetailScreen.swift` naming pattern). **If it does not exist, STOP and report BLOCKED citing F1** — do not write the screen yourself (D4: the build wires it and never writes it); under `--agent-walk` the run parks as a human step: "the owner runs the d2m screen spec + build for Edit cover (Figma 4724:53609), then /builder:agent". Tasks 5–10 stay committed.
>
> **F5 build-time risk** rides with Task 12 (menu glyphs).

**Files:**
- Read first: the d2m screen file and its contract under `docs/ui2/screens/` (its `State`, its `on…` closures, the slot or prop where the framed image goes)
- Create: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift` (register in `MakeReady`, sibling `GroupDetailContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:1` (`import UIKit` — `CoverEditSource` carries a `UIImage`) and `:18-34` (new case)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:150-161` (the destination switch)
- Test: `iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: Task 9 `EditGroupCoverModel`, `CoverEditSource`, `EditGroupCoverModel.opening(group:)`; Task 6 `GroupActions().saveCover`; Task 7 `CoverFramingMath`
- Produces:
  - `UI2Destination.editGroupCover(groupId: String, source: CoverEditSource)`
  - `struct EditGroupCoverContainer: View { let groupId: String; let source: CoverEditSource }`
  - `static func EditGroupCoverContainer.route(_ outcome: EditGroupCoverModel.SaveOutcome) -> Route` with `enum Route: Equatable { case pop, popToRoot, signOut, banner, stay }`
  - `struct CoverFramingCanvas: View` — the framed image + the simultaneous pinch/rotate/drag gestures, bound to the model; placed in the d2m screen's frame slot

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift`

```swift
import XCTest
@testable import MakeReady

/// group-cover-image D13: each save outcome's route.
final class EditGroupCoverContainerTests: XCTestCase {
    func testOutcomeRoutes() {
        XCTAssertEqual(EditGroupCoverContainer.route(.saved), .pop)
        XCTAssertEqual(EditGroupCoverContainer.route(.gone), .popToRoot)
        XCTAssertEqual(EditGroupCoverContainer.route(.unauthorized), .signOut)
        XCTAssertEqual(EditGroupCoverContainer.route(.failed("x")), .banner)
        XCTAssertEqual(EditGroupCoverContainer.route(.ignored), .stay)
    }

    func testDestinationIsHashableWithAPick() {
        let img = UIImage()
        let a = UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img))
        XCTAssertEqual(a, UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img)))
        XCTAssertNotEqual(a, UI2Destination.editGroupCover(groupId: "g1", source: .stored))
    }
}
```

- [ ] **Step 2: Register and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `type 'UI2Destination' has no member 'editGroupCover'`

- [ ] **Step 3: The route** — `UI2ShellModel.swift`: add `import UIKit` under `import CoreGraphics`, and in `UI2Destination`:

```swift
    /// group-cover-image D6/D7: the Edit cover page, above the group page — a new pick, or the
    /// stored original at its framing.
    case editGroupCover(groupId: String, source: CoverEditSource)
```

`UI2Shell.swift` switch:

```swift
        case let .editGroupCover(groupId, source): EditGroupCoverContainer(groupId: groupId, source: source)  // group-cover-image D4
```

- [ ] **Step 4: Write `EditGroupCoverContainer.swift`** — the shape below is fixed; the screen call is written against the d2m file's real `State` and closure names (read it first; R-03 closures, `state:` input):

```swift
import SwiftUI

/// group-cover-image D4/D6/D7/D13: wires the d2m-built Edit cover screen. A new pick opens at once;
/// a stored cover loads its original (`coverOriginalUrl ?? coverImageUrl`) first. Cancel or back
/// discards (D6). Save → D13: pop on success (AppState + the image cache already updated), 404 →
/// back to Groups, 401 → sign-out, anything else → the surfaced banner with the page kept.
struct EditGroupCoverContainer: View {
    let groupId: String
    let source: CoverEditSource

    enum Route: Equatable { case pop, popToRoot, signOut, banner, stay }

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var model: EditGroupCoverModel?

    static func route(_ outcome: EditGroupCoverModel.SaveOutcome) -> Route {
        switch outcome {
        case .saved: return .pop
        case .gone: return .popToRoot
        case .unauthorized: return .signOut
        case .failed: return .banner
        case .ignored: return .stay
        }
    }

    var body: some View {
        content
            .background(Token.layoutBackground.ignoresSafeArea())
            .task { await prepare() }
    }

    @ViewBuilder private var content: some View {
        // Replace `EditCoverScreen` with the d2m screen type and bind its real props:
        //   - title "Edit cover", Cancel → navigator.pop(), Save → Task { await save() }
        //   - Save disabled + spinner while `model.isSaving` (D13), gestures off (the model ignores them)
        //   - the frame slot ← CoverFramingCanvas(model:) — or, when the screen takes the image and
        //     transform as props, those props ← model.image / model.framing via CoverFramingMath.
        if let model {
            EditCoverScreen(/* the d2m screen's state + closures, as above */)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @MainActor
    private func prepare() async {
        guard model == nil else { return }
        let frame = CGSize(width: 408, height: 408 / CoverFramingMath.frameAspect)   // replace with the d2m frame size if it states one
        let save: @MainActor (UIImage, CoverFraming, UIImage?) async throws -> CoverSaveResult = { [groupId] rendered, framing, original in
            try await GroupActions().saveCover(groupId: groupId, rendered: rendered, framing: framing, original: original)
        }
        switch source {
        case let .newPick(image):
            model = EditGroupCoverModel(groupId: groupId, image: image, framing: .identity, isNewPick: true, frameSize: frame, save: save)
        case .stored:
            guard let group = AppState.shared.groups[groupId],
                  let opening = EditGroupCoverModel.opening(group: group),
                  let url = URL(string: opening.url) else { navigator.pop(); return }
            if Ui2ImageCache.shared.image(for: url) == nil { _ = await MemberProfileContainer.seedCovers([opening.url]) }
            guard let image = Ui2ImageCache.shared.image(for: url) else {
                AppState.shared.recordError(APIError.invalidResponse, context: "EditGroupCoverContainer.loadOriginal",
                                            surface: true, friendlyMessage: "Couldn't load the cover")
                navigator.pop()
                return
            }
            model = EditGroupCoverModel(groupId: groupId, image: image, framing: opening.framing, isNewPick: false, frameSize: frame, save: save)
        }
    }

    @MainActor
    private func save() async {
        guard let model else { return }
        let outcome = await model.save()
        switch Self.route(outcome) {
        case .pop: navigator.pop()
        case .popToRoot: navigator.popTo(0)
        case .signOut:
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EditGroupCoverContainer.signOut", surface: false)
            }
        case .banner:
            if case let .failed(message) = outcome {
                AppState.shared.recordError(APIError.serverError(message), context: "EditGroupCoverContainer.save", surface: true,
                                            friendlyMessage: EditGroupCoverModel.saveFailedMessage,
                                            retry: { Task { await save() } })
            }
        case .stay: break
        }
    }
}

/// D5: the framed image and its three simultaneous gestures. Clipped to the frame; the model
/// clamps every change, so no corner is ever empty.
struct CoverFramingCanvas: View {
    let model: EditGroupCoverModel

    var body: some View {
        GeometryReader { geo in
            let f = model.framing
            let scale = CoverFramingMath.absoluteScale(f, image: model.image.size, frame: model.frameSize) * (geo.size.width / model.frameSize.width)
            let center = CoverFramingMath.imageCenter(f, frame: geo.size)
            Image(uiImage: model.image)
                .resizable()
                .frame(width: model.image.size.width * scale, height: model.image.size.height * scale)
                .rotationEffect(.degrees(f.rotation))
                .position(x: geo.size.width / 2 + center.x, y: geo.size.height / 2 + center.y)
        }
        .aspectRatio(CoverFramingMath.frameAspect, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                SimultaneousGesture(MagnifyGesture(), RotateGesture()),
                DragGesture(minimumDistance: 0)
            )
            .onChanged { value in
                model.updateGesture(magnification: value.first?.first?.magnification ?? 1,
                                    rotationDegrees: value.first?.second?.rotation.degrees ?? 0,
                                    translation: value.second?.translation ?? .zero)
            }
            .onEnded { _ in model.endGesture() }
        )
        .allowsHitTesting(!model.isSaving)
        .accessibilityLabel("Cover framing")
        .accessibilityHint("Pinch to zoom, rotate with two fingers, drag to move")
    }
}
```

The canvas's on-screen frame may differ from `model.frameSize` (the d2m frame width); the gesture translation is in on-screen points, so if the screen's frame is not 408 wide, construct the model with the frame size the canvas actually lays out at (read it from the d2m contract), keeping the 408:180 aspect. Run `/transition-review` over the diff before committing.

- [ ] **Step 5: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the new tests, every existing shell/destination test); swiftlint from `iphone/` → no new violations

- [ ] **Step 6: Commit** — `feat(group-cover-image): Edit cover page wired to the d2m screen (D4–D7, D13)`

### Task 12: The cover tap on the group page — picker, C-066 menu, viewer (D1/D2/D3/D8)
App: iphone
Phase: 5
Recipe: `/present-overlay` · SPEC D1, D2, D3, D8 · F3, F5, F7

> **F5 build-time risk:** the menu uses glyphs `upload` / `edit` / `eye` (existing `GlyphName` cases, `Glyph.swift:86,88,207`). If the Figma menu frame for this feature draws different glyphs, do not draw one: note it in your report for `/ui2-component-update C-066`.
> **F3:** `onCoverTap` on `GroupsDetailScreen` and the `onHidden` hook on `.actionMenuPresentation` are MakeReadyUI edits outside d2m — list both in your report so they are routed to `/ui2-resolve` after the build.

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Groups/GroupsDetailScreen.swift:113-153` (new `onCoverTap` closure + init param, defaulted), `:286-290` (the tappable cover)
- Modify: `iphone/MakeReadyUI/ActionMenuPresentation.swift:10-16,118-147` (optional `onHidden`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift` (tap routing, menu, picker, viewer)
- Test: `iphone/MakeReadyCaptureTests/GroupDetailCoverTapTests.swift` (register in `MakeReadyCaptureTests`)

**Interfaces:**
- Consumes: Task 10 `coverViewerPresentation`, `CoverViewerOverlay.viewerURL(group:)`; Task 11 `UI2Destination.editGroupCover`; Task 8 `CoverImageRendering.uprightDownsampled`; `ActionMenuOverlay.ActionItem`
- Produces:
  - `GroupsDetailScreen.onCoverTap: () -> Void = {}` (init param after `onDeleteGroup`, defaulted — `ViewRegistry.swift:3631` and `GroupsScreensEditTests.swift:25-26` keep compiling)
  - `.actionMenuPresentation(isPresented:onDismiss:onHidden:menu:)` with `onHidden: @escaping () -> Void = {}`
  - `enum GroupDetailContainer.CoverTap: Equatable { case none, picker, menu }`, `static func coverTap(group: UserGroup?) -> CoverTap`
  - `enum GroupDetailContainer.CoverChoice: String { case change, edit, view }`, `static let coverActions: [ActionMenuOverlay.ActionItem]`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/GroupDetailCoverTapTests.swift`

```swift
import XCTest
@testable import MakeReady

/// group-cover-image D1/D2/F7: what a cover tap does, read from AppState's group (never the screen
/// state, whose coverURL is "" until the image is cached).
@MainActor
final class GroupDetailCoverTapTests: XCTestCase {
    private func group(cover: String?) -> UserGroup {
        UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, isPrivate: false, allowInvites: true,
                  memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testNoCoverOpensThePicker() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: nil)), .picker)
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: "")), .picker)
    }

    func testACoverOpensTheMenu() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: group(cover: "https://img/c.jpeg")), .menu)
    }

    /// F7: while the group is not in AppState the tap does nothing.
    func testUnloadedGroupIsInert() {
        XCTAssertEqual(GroupDetailContainer.coverTap(group: nil), .none)
    }

    /// D2: three rows, in order, with existing glyphs.
    func testMenuRows() {
        let rows = GroupDetailContainer.coverActions
        XCTAssertEqual(rows.map(\.label), ["Change image", "Edit image", "View image"])
        XCTAssertEqual(rows.map(\.glyph), ["upload", "edit", "eye"])
        for row in rows { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(rows.map { GroupDetailContainer.CoverChoice(label: $0.label) }, [.change, .edit, .view])
    }
}
```

(Check the glyph enum's real type name in `MakeReadyUI/Glyph.swift` — `GlyphName` per D2 — and use it.)

- [ ] **Step 2: Register and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `type 'GroupDetailContainer' has no member 'coverTap'`

- [ ] **Step 3: The screen hook** — `GroupsDetailScreen.swift`: add `var onCoverTap: () -> Void = {}   // C-087 tap → picker or the cover menu (group-cover-image D1/D2)` after `onDeleteGroup`, the init parameter `onCoverTap: @escaping () -> Void = {}` last, and `self.onCoverTap = onCoverTap`. Replace the `cover` property with:

```swift
    /// §2.1: "C-087 CoverImage 408×180 at y119 (`radius-card`)". group-cover-image D1/D2: tappable;
    /// CoverImage is accessibilityHidden, so the button carries its own label and trait.
    private var cover: some View {
        SwiftUI.Button(action: onCoverTap) {
            CoverImage(image: Self.cachedImage(state.coverURL))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.coverURL.isEmpty ? "Add cover image" : "Cover image")
        .accessibilityAddTraits(.isButton)
        .ui2Element("C-087 CoverImage")
        .padding(.horizontal, Token.Space.pageMargin)
    }
```

(`SwiftUI.Button` — a registry row named `Button` shadows SwiftUI's module-wide.) Run `ruby iphone/scripts/makereadyui-sync.rb` only if it reports the file out of sync (no new files here).

- [ ] **Step 4: `onHidden` on the action-menu presentation** — `ActionMenuPresentation.swift`:

```swift
    func actionMenuPresentation<Menu: View>(
        isPresented: Bool,
        onDismiss: @escaping () -> Void,
        onHidden: @escaping () -> Void = {},
        @ViewBuilder menu: () -> Menu
    ) -> some View {
        modifier(HostableActionMenuPresentation(isPresented: isPresented, onDismiss: onDismiss, onHidden: onHidden, menu: menu()))
    }
```

and in `HostableActionMenuPresentation` add `let onHidden: () -> Void` and change the layer to `ActionMenuLayer(visible: isPresented, onDismiss: onDismiss, onHidden: { mounted = false; onHidden() }, menu: menu)`. Every existing caller keeps compiling through the default.

- [ ] **Step 5: The container** — `GroupDetailContainer.swift`: add `import PhotosUI`, the state

```swift
    /// group-cover-image D1/D3: the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D2: the cover menu, and the row chosen in it — acted on once the menu has slid out (D8).
    @State private var coverMenuOpen = false
    @State private var pendingCoverChoice: CoverChoice?
    /// D8: the viewer's URL while it is up.
    @State private var viewerURL: String?
```

pass `onCoverTap: { handleCoverTap() }` to `GroupsDetailScreen`, and add after the delete menu's `.actionMenuPresentation`:

```swift
        // group-cover-image D2: Change · Edit · View; Done cancels. The chosen row runs after the
        // menu has finished hiding — the overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: coverMenuOpen, onDismiss: { coverMenuOpen = false },
                                onHidden: { runPendingCoverChoice() }) {
            ActionMenuOverlay(
                actions: Self.coverActions,
                onSelect: { item in
                    pendingCoverChoice = CoverChoice(label: item.label)
                    coverMenuOpen = false
                },
                onDone: { coverMenuOpen = false }
            )
        }
        // D1/D3: the system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        // D8
        .coverViewerPresentation(url: viewerURL, onClose: { viewerURL = nil })
```

and the helpers:

```swift
    enum CoverTap: Equatable { case none, picker, menu }

    enum CoverChoice: String {
        case change = "Change image", edit = "Edit image", view = "View image"
        init?(label: String) { self.init(rawValue: label) }
    }

    /// D2: the menu rows, in order — existing glyphs (an unknown name renders the red stub).
    static let coverActions: [ActionMenuOverlay.ActionItem] = [
        .init(glyph: "upload", label: CoverChoice.change.rawValue),
        .init(glyph: "edit", label: CoverChoice.edit.rawValue),
        .init(glyph: "eye", label: CoverChoice.view.rawValue)
    ]

    /// D1/D2/F7: read from AppState's group — inert until it has loaded.
    static func coverTap(group: UserGroup?) -> CoverTap {
        guard let group else { return .none }
        return (group.coverImageUrl ?? "").isEmpty ? .picker : .menu
    }

    private func handleCoverTap() {
        switch Self.coverTap(group: AppState.shared.groups[groupId]) {
        case .none: break
        case .picker: pickerOpen = true
        case .menu: coverMenuOpen = true
        }
    }

    private func runPendingCoverChoice() {
        guard let choice = pendingCoverChoice else { return }
        pendingCoverChoice = nil
        switch choice {
        case .change: pickerOpen = true
        case .edit: navigator.push(.editGroupCover(groupId: groupId, source: .stored))
        case .view: viewerURL = AppState.shared.groups[groupId].flatMap(CoverViewerOverlay.viewerURL(group:))
        }
    }

    /// D3/D6: load the pick, make it upright and ≤ 2400px, then Edit cover. Dismissing the picker
    /// changes nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(.editGroupCover(groupId: groupId, source: .newPick(image)))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "GroupDetailContainer.openPicked", surface: true,
                                        friendlyMessage: "Couldn't open that photo")
        }
    }
```

Run `/transition-review` over the diff (it touches a presentation) before committing.

- [ ] **Step 6: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the new tests, `GroupsScreensEditTests`, `GroupDetailContainerTests`, the ViewRegistry capture case still compiling); swiftlint from `iphone/` → no new violations

- [ ] **Step 7: Commit** — `feat(group-cover-image): cover tap → picker / Change · Edit · View menu / viewer (D1–D3, D8)`
