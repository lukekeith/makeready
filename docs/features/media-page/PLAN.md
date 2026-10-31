# media-page — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give leaders the UI 2.0 Media page: the whole photo library in a Photos-style zoomable grid, ordered by when each photo was taken, with search, Tags / Leaders / Time chips and ImageViewer, plus the server's new `Media.takenAt`.

**Architecture:** Server first: one Atlas migration adds and backfills `media.takenAt`; a pure `parseTakenAt` in `services/media-metadata.ts` decides the value on every media create (upload, `captureToLibrary`), the two cover routes pass an optional body `takenAt` through, and a `media-home` fixtures layer seeds 360 dated photos. Then iPhone: cover picks read the capture date with ImageIO and send it; `MediaActions.loadAllPhotos` pages the whole photo library into `AppState.mediaLibrary`; a pure `MediaHomeMapper` sorts and filters it; d2m designs and builds MediaBrowser + `MediaHomeScreen` through the d2m channel; `MediaHomeContainer` wires them into Home's `.media` section, which owns its own scroll.

**Tech Stack:** server — Express, Prisma (schema YAML → Atlas), zod, sharp + exif-reader, vitest + supertest. iphone — SwiftUI, `@Observable` AppState + Actions, ImageIO, XCTest in MakeReadyCaptureTests, the d2m channel (MCP) for MakeReadyUI views.

**Spec:** docs/features/media-page/SPEC.md (code map: the workspace's `audit-digest.md`)

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(media-page): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | `media.takenAt` exists and is backfilled; every media create stores it through `parseTakenAt` | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` · `docker restart makeready-server` |
| 2 | server | 3–4 | both cover routes carry `takenAt`, the library list returns it, the fixtures seed the Media page — contract FREEZES | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `docker restart makeready-server` |
| 3 | iphone | 5–7 | cover picks send the capture date; the phone decodes `takenAt`, pages the whole photo library, and sorts and filters it | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 8 | d2m has specced and built MediaBrowser and `MediaHomeScreen`, and they are in this branch | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 9–11 | Home's Media section shows the library in MediaBrowser, owns its scroll, loads images on a budget and opens ImageViewer from a tile | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: `Media.takenAt` column + guarded backfill
App: server
Phase: 1
Recipe: /api · SPEC §Schema & API changes SC1 + §Data plan · server/.claude/CLAUDE.md §Database Management

**Files:**
- Modify: `server/schema/schema.yaml:1003-1006` (Media, beside `exifData`)
- Create: `server/atlas/migrations/<generated timestamp>.sql` (+ `server/atlas/migrations/atlas.sum`)
- Regenerate: `server/prisma/schema.prisma`, `server/atlas/.schema.hcl` (by `schema:generate`, never by hand)
- Test: `server/test/media-taken-at-migration.test.ts`

**Interfaces:**
- Produces: column `media."takenAt" timestamp NULL`; Prisma `Media.takenAt: DateTime | null` (field `takenAt`).

- [ ] **Step 1: Write the failing test** — `server/test/media-taken-at-migration.test.ts` (pattern: `test/directory-access-migration.test.ts`):

```ts
/**
 * media-page SC1 / D4: Media.takenAt ships in ONE Atlas migration that adds the nullable column and
 * backfills it from exifData.dateTaken with a guarded cast, then nulls values out of bounds.
 */
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { Prisma } from '../src/generated/prisma/index.js'

const MIGRATIONS = fileURLToPath(new URL('../atlas/migrations', import.meta.url))
const ADD_COLUMN = 'ALTER TABLE "media" ADD COLUMN "takenAt" timestamp NULL'
const BACKFILL =
  `UPDATE "media" SET "takenAt" = CASE WHEN "exifData"->>'dateTaken' ~ '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}' THEN ("exifData"->>'dateTaken')::timestamptz END WHERE "takenAt" IS NULL AND "exifData" ? 'dateTaken';`
const BOUNDS =
  `UPDATE "media" SET "takenAt" = NULL WHERE "takenAt" < '1990-01-01' OR "takenAt" > now() + interval '24 hours';`

function findMigration(): { file: string; sql: string } {
  const hits = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .map((file) => ({ file, sql: readFileSync(join(MIGRATIONS, file), 'utf8') }))
    .filter((m) => m.sql.includes(ADD_COLUMN))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1 migration (D4)', () => {
  it('adds the nullable takenAt column', () => {
    expect(findMigration().sql).toContain(ADD_COLUMN)
  })

  it('backfills from exifData.dateTaken with a guarded cast, after the column exists', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BACKFILL)
    expect(sql.indexOf(BACKFILL)).toBeGreaterThan(sql.indexOf(ADD_COLUMN))
  })

  it('nulls backfilled values outside 1990-01-01 … now + 24 h, after the backfill', () => {
    const { sql } = findMigration()
    expect(sql).toContain(BOUNDS)
    expect(sql.indexOf(BOUNDS)).toBeGreaterThan(sql.indexOf(BACKFILL))
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates the Prisma field', () => {
    expect(Object.values(Prisma.MediaScalarFieldEnum)).toContain('takenAt')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/media-taken-at-migration.test.ts` → FAIL (`expected [] to have a length of 1`).

- [ ] **Step 3: Add the field** to `Media` in `server/schema/schema.yaml`, directly after `exifData`:

```yaml
      takenAt:
        type: datetime
        nullable: true
        description: "When the photo was taken (media-page D4): the request's takenAt, else EXIF DateTimeOriginal, else null"
```

- [ ] **Step 4: Generate the schema and the migration WITHOUT dotenv** (🔴 `npm run schema:diff` reads `server/.env`, a 1Password pipe — never run it):

```bash
cd server && npm run schema:validate && npm run schema:generate
cd server/atlas && ../scripts/atlas.sh migrate diff --env local \
  --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev
```

Open the new file in `server/atlas/migrations/` (the newest timestamp). It must contain exactly the `ADD_COLUMN` line above (Atlas writes `-- Modify "media" table` before it). **Then append to that same new, uncommitted file** (precedent: `20261027064150.sql`):

```sql
-- media-page D4: backfill the date taken from the EXIF the upload already stored; a malformed value stays null.
UPDATE "media" SET "takenAt" = CASE WHEN "exifData"->>'dateTaken' ~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' THEN ("exifData"->>'dateTaken')::timestamptz END WHERE "takenAt" IS NULL AND "exifData" ? 'dateTaken';
-- media-page D4: the same bounds parseTakenAt applies to new rows.
UPDATE "media" SET "takenAt" = NULL WHERE "takenAt" < '1990-01-01' OR "takenAt" > now() + interval '24 hours';
```

Then re-hash: `cd server/atlas && ../scripts/atlas.sh migrate hash --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev`, and regenerate the client: `cd server && npx prisma generate`.

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run test/media-taken-at-migration.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean.

- [ ] **Step 6: Commit** — `feat(media-page): Media.takenAt column with EXIF backfill` (schema.yaml, prisma/schema.prisma, atlas/.schema.hcl, the migration, atlas.sum, the test).

### Task 2: `parseTakenAt` + the upload route and `captureToLibrary` store it
App: server
Phase: 1
Recipe: /api · SPEC D4, SC2, §server

**Files:**
- Modify: `server/src/services/media-metadata.ts` (add the exported pure `parseTakenAt`)
- Modify: `server/src/services/media-library.ts:18-41` (`CaptureToLibraryParams.takenAt?`), `:149-174` (`captureToLibrary` create data)
- Modify: `server/src/routes/media.ts:1171-1178` (`uploadMediaSchema`), `:1194` (destructure), `:1220-1241` (photo create)
- Test: `server/test/parse-taken-at.test.ts`, `server/test/media-capture-taken-at.test.ts`, `server/test/media-upload-taken-at.test.ts`

**Interfaces:**
- Produces: `export function parseTakenAt(input: unknown, exifData: Record<string, unknown> | null | undefined, now?: Date): Date | null` from `services/media-metadata.ts`; `CaptureToLibraryParams.takenAt?: string`; `POST /api/organizations/:organizationId/media/upload` body accepts optional `takenAt: string`.

- [ ] **Step 1: Write the failing unit test** — `server/test/parse-taken-at.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { parseTakenAt } from '../src/services/media-metadata.js'

const NOW = new Date('2026-10-31T12:00:00.000Z')

describe('parseTakenAt (media-page D4)', () => {
  it('takes a body value with Z', () => {
    expect(parseTakenAt('2025-06-14T09:30:00Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.000Z')
  })
  it('takes a body value with an offset, with or without the colon, and with fractions', () => {
    expect(parseTakenAt('2025-06-14T09:30:00-05:00', null, NOW)?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
    expect(parseTakenAt('2025-06-14T09:30:00+0530', null, NOW)?.toISOString()).toBe('2025-06-14T04:00:00.000Z')
    expect(parseTakenAt('2025-06-14T09:30:00.250Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.250Z')
    expect(parseTakenAt('2025-06-14T09:30Z', null, NOW)?.toISOString()).toBe('2025-06-14T09:30:00.000Z')
  })
  it('ignores a date-only, offset-less or garbage body value', () => {
    expect(parseTakenAt('2025-06-14', null, NOW)).toBeNull()
    expect(parseTakenAt('2025-06-14T09:30:00', null, NOW)).toBeNull()
    expect(parseTakenAt('yesterday', null, NOW)).toBeNull()
    expect(parseTakenAt(42, null, NOW)).toBeNull()
    expect(parseTakenAt('2025-13-40T99:99:00Z', null, NOW)).toBeNull()
  })
  it('ignores a body value before 1990-01-01 or more than 24 h after now', () => {
    expect(parseTakenAt('1989-12-31T23:59:59Z', null, NOW)).toBeNull()
    expect(parseTakenAt('2026-11-01T12:00:01Z', null, NOW)).toBeNull()
    expect(parseTakenAt('2026-11-01T11:59:59Z', null, NOW)?.toISOString()).toBe('2026-11-01T11:59:59.000Z')
  })
  it('falls back to exifData.dateTaken (a Date or its ISO string) when the body has none or an invalid one', () => {
    const exifDate = new Date('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt(undefined, { dateTaken: exifDate }, NOW)?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt('bad', { dateTaken: '2024-03-02T10:11:12.000Z' }, NOW)?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
    expect(parseTakenAt(undefined, { dateTaken: '1970-01-01T00:00:00.000Z' }, NOW)).toBeNull()
    expect(parseTakenAt(undefined, { dateTaken: 'not a date' }, NOW)).toBeNull()
  })
  it('prefers a valid body value over EXIF', () => {
    expect(parseTakenAt('2025-06-14T09:30:00Z', { dateTaken: new Date('2024-03-02T10:11:12Z') }, NOW)?.toISOString())
      .toBe('2025-06-14T09:30:00.000Z')
  })
  it('is null with neither', () => {
    expect(parseTakenAt(undefined, null, NOW)).toBeNull()
    expect(parseTakenAt(undefined, undefined, NOW)).toBeNull()
    expect(parseTakenAt(undefined, { cameraMake: 'Apple' }, NOW)).toBeNull()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/parse-taken-at.test.ts` → FAIL (`parseTakenAt is not a function` / not exported).

- [ ] **Step 3: Implement `parseTakenAt`** at the end of `server/src/services/media-metadata.ts`:

```ts
// media-page D4: a full ISO 8601 date-time with Z or a numeric offset; date-only and offset-less are invalid.
const TAKEN_AT_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})$/
const EXIF_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
const TAKEN_AT_FLOOR_MS = Date.UTC(1990, 0, 1)
const TAKEN_AT_LEAD_MS = 24 * 60 * 60 * 1000

function boundedTakenAt(value: Date, now: Date): Date | null {
  const ms = value.getTime()
  if (!Number.isFinite(ms) || ms < TAKEN_AT_FLOOR_MS || ms > now.getTime() + TAKEN_AT_LEAD_MS) return null
  return value
}

/**
 * media-page D4: the date a photo was taken — the request's `takenAt` when valid, else the EXIF
 * `dateTaken` the upload stored (exif-reader labels the camera's wall clock as UTC; accepted), else
 * null. An invalid value is ignored, never an error.
 */
export function parseTakenAt(
  input: unknown,
  exifData: Record<string, unknown> | null | undefined,
  now: Date = new Date(),
): Date | null {
  if (typeof input === 'string' && TAKEN_AT_PATTERN.test(input)) {
    // "+0530" → "+05:30", so every engine parses the offset.
    const normalized = input.replace(/([+-]\d{2})(\d{2})$/, '$1:$2')
    const fromBody = boundedTakenAt(new Date(normalized), now)
    if (fromBody) return fromBody
  }
  const exif = exifData?.dateTaken
  if (exif instanceof Date) return boundedTakenAt(exif, now)
  if (typeof exif === 'string' && EXIF_DATE_PATTERN.test(exif)) return boundedTakenAt(new Date(exif), now)
  return null
}
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run test/parse-taken-at.test.ts` → PASS.

- [ ] **Step 5: Write the failing capture test** — `server/test/media-capture-taken-at.test.ts` (Prisma mocked, as `test/media-library-cursor.test.ts` does):

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const mockFindFirst = vi.fn()
const mockCreate = vi.fn()

vi.mock('../src/lib/prisma.js', () => ({
  prisma: {
    media: {
      findFirst: (...args: unknown[]) => mockFindFirst(...args),
      create: (...args: unknown[]) => mockCreate(...args),
    },
  },
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn() }))

const { captureToLibrary } = await import('../src/services/media-library.js')

const base = {
  title: 'Prayer Team - Cover Image',
  url: 'https://images.test/groups/g1.jpeg',
  type: 'photo',
  organizationId: 'org-1',
  uploadedBy: 'user-1',
  uploadStatus: 'pending', // skips the fire-and-forget AI enrichment
}

describe('captureToLibrary stores takenAt (media-page D4)', () => {
  beforeEach(() => {
    mockFindFirst.mockReset().mockResolvedValue(null)
    mockCreate.mockReset().mockImplementation(async ({ data }: { data: object }) => ({ id: 'm1', ...data }))
  })

  it('stores a valid takenAt from the caller', async () => {
    captureToLibrary({ ...base, takenAt: '2025-06-14T09:30:00-05:00' })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('falls back to exifData.dateTaken', async () => {
    captureToLibrary({ ...base, exifData: { dateTaken: new Date('2024-03-02T10:11:12Z') } })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
  })

  it('stores null with neither, and ignores an invalid takenAt', async () => {
    captureToLibrary({ ...base, takenAt: '2025-06-14' })
    await vi.waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate.mock.calls[0][0].data.takenAt).toBeNull()
  })
})
```

- [ ] **Step 6: Run it and watch it fail** — `cd server && npx vitest run test/media-capture-taken-at.test.ts` → FAIL (`takenAt` is undefined on the create data / a type error on `takenAt` in the params).

- [ ] **Step 7: Implement** in `server/src/services/media-library.ts`: import `parseTakenAt` from `./media-metadata.js`; add to `CaptureToLibraryParams` after `exifData`:

```ts
  /** media-page D3/D4: the capture date the client read from the picked file (ISO 8601 with offset). */
  takenAt?: string
```

and in `captureToLibrary`'s `prisma.media.create({ data: { … } })`, directly after `exifData: …`:

```ts
            takenAt: parseTakenAt(params.takenAt, params.exifData),
```

- [ ] **Step 8: Run it and watch it pass** — `cd server && npx vitest run test/media-capture-taken-at.test.ts` → PASS.

- [ ] **Step 9: Write the failing upload request test** — `server/test/media-upload-taken-at.test.ts` (auth pattern: `test/media-authorization.test.ts`; storage and the AI call are mocked so no bucket is needed):

```ts
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'
import sharp from 'sharp'

vi.mock('../src/services/storage.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/storage.js')>()),
  uploadImageVariants: vi.fn(async (_prefix: string, baseName: string) => ({ url: `https://images.test/library/${baseName}.jpeg` })),
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn(async () => null) }))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')

describe('POST /media/upload stores takenAt (media-page D4, SC2)', () => {
  const stamp = Date.now()
  let token: string
  let userId: string
  let orgId: string

  const jpeg = (exif?: Record<string, Record<string, string>>) => {
    const img = sharp({ create: { width: 8, height: 8, channels: 3, background: '#888888' } })
    return (exif ? img.withExif(exif) : img).jpeg().toBuffer().then((b) => b.toString('base64'))
  }
  const upload = async (body: Record<string, unknown>) =>
    request(app).post(`/api/organizations/${orgId}/media/upload`).set('Authorization', bearer(token))
      .send({ type: 'photo', title: `T ${stamp}`, ...body })

  beforeAll(async () => {
    const owner = await createUserWithApiKey({ email: `mtaken-${stamp}@cl.test`, name: 'Taken Owner' })
    token = owner.token
    userId = owner.userId
    orgId = (await prisma.organization.create({ data: { name: `Taken Org ${stamp}`, ownerId: userId } })).id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.apiKey.deleteMany({ where: { userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  it('stores the body takenAt', async () => {
    const res = await upload({ imageData: await jpeg(), takenAt: '2025-06-14T09:30:00-05:00' })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('falls back to the EXIF DateTimeOriginal of the posted bytes', async () => {
    const res = await upload({ imageData: await jpeg({ IFD2: { DateTimeOriginal: '2024:03:02 10:11:12' } }) })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt?.toISOString()).toBe('2024-03-02T10:11:12.000Z')
  })

  it('ignores an invalid takenAt (never a 400) and stores null without EXIF', async () => {
    const res = await upload({ imageData: await jpeg(), takenAt: '2025-06-14' })
    expect(res.status).toBe(201)
    const row = await prisma.media.findUniqueOrThrow({ where: { id: res.body.data.id } })
    expect(row.takenAt).toBeNull()
  })
})
```

If the route answers 200 rather than 201 on success, assert the status it already returns today (read the `res.status(...)` at the end of the photo branch) — the contract says the response is unchanged.

- [ ] **Step 10: Run it and watch it fail** — `cd server && npx vitest run test/media-upload-taken-at.test.ts` → FAIL (`takenAt` is null for the body case: zod strips the field).

- [ ] **Step 11: Implement** in `server/src/routes/media.ts`: import `parseTakenAt` beside `extractImageMetadata` (`:4`); add to `uploadMediaSchema` after `maxDurationSeconds`:

```ts
  // media-page SC2 / D4: the client's capture date; validated by parseTakenAt (invalid = ignored).
  takenAt: z.string().optional(),
```

destructure it (`const { title, description, type, imageData, tags: tagList, maxDurationSeconds, takenAt } = validation.data`), and in the photo branch's `prisma.media.create` data, directly after `exifData: …`:

```ts
            takenAt: parseTakenAt(takenAt, imageMeta.exifData),
```

- [ ] **Step 12: Run them and watch them pass** — `cd server && npx vitest run test/parse-taken-at.test.ts test/media-capture-taken-at.test.ts test/media-upload-taken-at.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean; `docker restart makeready-server`.

- [ ] **Step 13: Commit** — `feat(media-page): parseTakenAt; upload and library capture store takenAt`

### Task 3: Cover routes accept `takenAt`; the library list returns it
App: server
Phase: 2
Recipe: /api · SPEC §Contract rows 1–3, SC3, F18

**Files:**
- Modify: `server/src/routes/groups.ts:1272-1277` (body schema), `:1316-1334` (captureToLibrary call)
- Modify: `server/src/routes/programs.ts:3912-3917` (body schema), `:3954-3973` (captureToLibrary call)
- Test: `server/test/cover-taken-at.test.ts`

**Interfaces:**
- Consumes: `CaptureToLibraryParams.takenAt?: string` (Task 2); `parseTakenAt` (Task 2).
- Produces: `POST /api/groups/:id/cover-image` and `POST /api/programs/:id/cover-image` bodies accept optional `takenAt: string`; `GET /api/organizations/:organizationId/media/library` items carry `takenAt` (ISO string or null) — already true through `mapRow`'s spread (`media-library.ts:399`), asserted here.

- [ ] **Step 1: Write the failing test** — `server/test/cover-taken-at.test.ts`. The cover services are mocked (no storage); `captureToLibrary` runs for real, so its row is polled:

```ts
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest'
import request from 'supertest'

const saved = (url: string) => ({
  coverImageUrl: url, coverOriginalUrl: null, coverFraming: null,
  renderedBuffer: Buffer.alloc(0), renderedSize: 10, isNewImage: true,
})
vi.mock('../src/services/group-cover.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/group-cover.js')>()),
  saveGroupCover: vi.fn(async () => saved(`https://images.test/groups/g-${Date.now()}.jpeg`)),
  saveCover: vi.fn(async () => saved(`https://images.test/programs/p-${Date.now()}.jpeg`)),
}))
vi.mock('../src/services/media-metadata.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../src/services/media-metadata.js')>()),
  // The rendered cover carries no EXIF (group-cover-image): the capture date comes from the body only.
  extractImageMetadata: vi.fn(async () => ({ width: 8, height: 8, aspectRatio: '1:1', dominantColor: null, fileHash: 'h', exifData: null })),
}))
vi.mock('../src/services/claude.js', () => ({ analyzeImage: vi.fn(async () => null) }))

const { app } = await import('../src/index.js')
const { prisma } = await import('../src/lib/prisma.js')
const { createUserWithApiKey, bearer } = await import('./helpers/api-auth.js')

describe('cover routes carry takenAt to the captured library row (media-page D3, SC3)', () => {
  const stamp = Date.now()
  let token: string
  let userId: string
  let orgId: string
  let groupId: string
  let programId: string
  const cover = { imageData: Buffer.from('x').toString('base64'), contentType: 'image/jpeg' }

  beforeAll(async () => {
    const owner = await createUserWithApiKey({ email: `ctaken-${stamp}@cl.test`, name: 'Cover Owner' })
    token = owner.token
    userId = owner.userId
    orgId = (await prisma.organization.create({ data: { name: `Cover Org ${stamp}`, ownerId: userId } })).id
    groupId = (await prisma.group.create({ data: { name: `Cover Group ${stamp}`, code: `ct-${stamp}`, creatorId: userId, organizationId: orgId } })).id
    programId = (await prisma.studyProgram.create({ data: { name: `Cover Program ${stamp}`, days: 1, creatorId: userId, organizationId: orgId } })).id
  })

  afterAll(async () => {
    await prisma.media.deleteMany({ where: { organizationId: orgId } })
    await prisma.studyProgram.deleteMany({ where: { id: programId } })
    await prisma.group.deleteMany({ where: { id: groupId } })
    await prisma.apiKey.deleteMany({ where: { userId } })
    await prisma.organization.deleteMany({ where: { id: orgId } })
    await prisma.user.deleteMany({ where: { id: userId } })
  })

  const capturedRow = (title: string) =>
    vi.waitFor(async () => {
      const row = await prisma.media.findFirst({ where: { organizationId: orgId, title } })
      expect(row).not.toBeNull()
      return row!
    }, { timeout: 5000 })

  it('group cover: stores the body takenAt on the captured row', async () => {
    const res = await request(app).post(`/api/groups/${groupId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: '2025-06-14T09:30:00-05:00' })
    expect(res.status).toBe(200)
    const row = await capturedRow(`Cover Group ${stamp} - Cover Image`)
    expect(row.takenAt?.toISOString()).toBe('2025-06-14T14:30:00.000Z')
  })

  it('program cover: stores the body takenAt; an invalid one is ignored, not a 400', async () => {
    const res = await request(app).post(`/api/programs/${programId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: '2024-01-05T08:00:00Z' })
    expect(res.status).toBe(200)
    const row = await capturedRow(`Cover Program ${stamp} - Cover Image`)
    expect(row.takenAt?.toISOString()).toBe('2024-01-05T08:00:00.000Z')

    const bad = await request(app).post(`/api/programs/${programId}/cover-image`).set('Authorization', bearer(token))
      .send({ ...cover, takenAt: 'not-a-date' })
    expect(bad.status).toBe(200)
  })

  it('the library list returns takenAt on every item (ISO string or null)', async () => {
    await prisma.media.create({ data: { title: `Undated ${stamp}`, url: `https://images.test/u-${stamp}.jpeg`, type: 'photo', organizationId: orgId, uploadedBy: userId } })
    const res = await request(app).get(`/api/organizations/${orgId}/media/library?type=photo&limit=200`).set('Authorization', bearer(token))
    expect(res.status).toBe(200)
    const byTitle = Object.fromEntries(res.body.data.map((i: { title: string; takenAt: string | null }) => [i.title, i.takenAt]))
    expect(byTitle[`Cover Group ${stamp} - Cover Image`]).toBe('2025-06-14T14:30:00.000Z')
    expect(byTitle[`Undated ${stamp}`]).toBeNull()
  })
})
```

The route-level mocks must not change any other assertion: if `extractImageMetadata`'s real return has more keys than the mock, add them with neutral values (read `ImageMetadata` in `media-metadata.ts`).

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/cover-taken-at.test.ts` → FAIL (group row `takenAt` is null: zod strips `takenAt`).

- [ ] **Step 3: Implement** — in BOTH `groups.ts` and `programs.ts` cover-image body schemas, after `originalData`:

```ts
      // media-page SC3 / D3: the capture date of a NEW pick (none on a re-edit); parseTakenAt validates it.
      takenAt: z.string().optional(),
```

and in each route's `captureToLibrary({ … })` call, after `exifData: imageMeta.exifData ?? undefined,`:

```ts
        takenAt: body.takenAt,
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run test/cover-taken-at.test.ts` → PASS; `cd server && npx tsc --noEmit` → clean; `docker restart makeready-server`.

- [ ] **Step 5: Commit** — `feat(media-page): cover routes pass takenAt to the library capture`

### Task 4: `media-home` fixtures layer — and the contract freeze
App: server
Phase: 2
Recipe: server/fixtures/README.md (new layer + Fixed IDs) · SPEC D14 · build-time risk R3: the layer depends on base's library images; under vitest or with no storage it is skipped and Media is empty. The walk env has storage (s3mock) — the agent walk asserts the `full` scenario yields 360 rows there

**Files:**
- Modify: `server/fixtures/ids.ts:9-37` (add kind `mediaTag: '001c'`)
- Modify: `server/fixtures/README.md:130-140` (§Fixed IDs: `001c` media tags; the layer list)
- Create: `server/fixtures/screens/media-home.ts`
- Test: `server/fixtures/__tests__/media-home.test.ts`
- Modify (freeze): `docs/features/media-page/MANIFEST.md` via `advance.mjs` (never by hand)

**Interfaces:**
- Consumes: `Media.takenAt` (Task 1); `FixtureContext` (`ctx.prisma`, `ctx.now`, `ctx.daysAgo(n)`), `fixtureId`, `FIXTURE_ORG_ID`, `FIXTURE_USER_ID`, `FIXTURE_LEADER_USER_ID` from `fixtures/ids.ts`.
- Produces: `export function mediaHomeRows(now: Date, sources: MediaHomeSource[], daysAgo: (n: number) => Date): MediaHomeRow[]`; constants `MEDIA_HOME_ROW_COUNT = 360`, `MEDIA_HOME_UNDATED = 20`, `MEDIA_HOME_FIRST_N = 1000`, `MEDIA_HOME_TAGS`.

- [ ] **Step 1: Write the failing test** — `server/fixtures/__tests__/media-home.test.ts` (pure; no DB):

```ts
import { describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_USER_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { MEDIA_HOME_ROW_COUNT, MEDIA_HOME_TAGS, MEDIA_HOME_UNDATED, mediaHomeRows } from '../screens/media-home.js'

const NOW = new Date('2026-10-31T17:00:00.000Z')
const daysAgo = (n: number) => new Date(NOW.getTime() - n * 86_400_000)
const sources = Array.from({ length: 12 }, (_, i) => ({
  url: `https://img.test/library/l${i}.jpeg`, thumbnailUrl: `https://img.test/library/l${i}-thumb.jpeg`,
  width: 1200, height: 900, aspectRatio: '4:3', dominantColor: '#334455',
}))

describe('media-home layer rows (media-page D14)', () => {
  const rows = mediaHomeRows(NOW, sources, daysAgo)

  it('makes 360 rows with ids from n 1000, unique', () => {
    expect(rows).toHaveLength(MEDIA_HOME_ROW_COUNT)
    expect(rows[0].media.id).toBe(fixtureId('media', 1000))
    expect(new Set(rows.map((r) => r.media.id)).size).toBe(MEDIA_HOME_ROW_COUNT)
  })

  it('reuses the base library URLs, cycled', () => {
    expect(rows[0].media.url).toBe(sources[0].url)
    expect(rows[12].media.url).toBe(sources[0].url)
    expect(rows[13].media.thumbnailUrl).toBe(sources[1].thumbnailUrl)
  })

  it('leaves 20 rows undated and dates the rest within the last 3 calendar years, none in the future', () => {
    const undated = rows.filter((r) => r.media.takenAt === null)
    expect(undated).toHaveLength(MEDIA_HOME_UNDATED)
    const floor = Date.UTC(NOW.getUTCFullYear() - 3, 0, 1)
    for (const r of rows) {
      if (r.media.takenAt === null) continue
      expect(r.media.takenAt.getTime()).toBeGreaterThanOrEqual(floor)
      expect(r.media.takenAt.getTime()).toBeLessThanOrEqual(NOW.getTime())
    }
  })

  it('leaves month-to-month gaps: some of the last 36 months have no photo', () => {
    const months = new Set(rows.filter((r) => r.media.takenAt).map((r) => r.media.takenAt!.toISOString().slice(0, 7)))
    expect(months.size).toBeGreaterThan(12)
    expect(months.size).toBeLessThan(36)
  })

  it('splits uploads between the two fixture leaders and uses every tag', () => {
    expect(new Set(rows.map((r) => r.media.uploadedBy))).toEqual(new Set([FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID]))
    expect(new Set(rows.flatMap((r) => r.tags))).toEqual(new Set(MEDIA_HOME_TAGS))
  })

  it('gives each tag a fixed mediaTag id', () => {
    const ids = rows.flatMap((r) => r.tagIds)
    expect(new Set(ids).size).toBe(ids.length)
    expect(ids[0].split('-')[1]).toBe('001c')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/media-home.test.ts` → FAIL (cannot resolve `../screens/media-home.js`).

- [ ] **Step 3: Implement** — add to `FIXTURE_KIND` in `server/fixtures/ids.ts`, after `enrollmentDraft`:

```ts
  // media-page D14: the Media page's tags.
  mediaTag: '001c',
```

and create `server/fixtures/screens/media-home.ts`:

```ts
/**
 * media-home layer (media-page D14): 360 photos in the fixture org's library, so the Media page has
 * a grid to zoom through. They reuse the base layer's `source: 'direct'` library images (cycled), so
 * the layer is empty whenever base placed no images (vitest, or no storage configured — the same
 * switches as placeProgramCovers). Dates spread over the last 3 calendar years with month gaps; the
 * last 20 rows have no takenAt and sort by createdAt. Two uploaders and six tags, so every chip has
 * results. Never touches ctx.rand. Creates no org, user or group; the org's deletion removes the rows.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_ORG_ID, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const MEDIA_HOME_ROW_COUNT = 360
export const MEDIA_HOME_UNDATED = 20
export const MEDIA_HOME_FIRST_N = 1000
export const MEDIA_HOME_TAGS = ['baptism', 'family', 'outreach', 'retreat', 'worship', 'youth'] as const

export interface MediaHomeSource {
  url: string
  thumbnailUrl: string | null
  width: number | null
  height: number | null
  aspectRatio: string | null
  dominantColor: string | null
}

export interface MediaHomeRow {
  media: {
    id: string; title: string; url: string; thumbnailUrl: string | null; type: 'photo'; mimeType: 'image/jpeg'
    organizationId: string; uploadedBy: string; visibility: 'members'; uploadStatus: 'ready'; source: 'direct'
    width: number | null; height: number | null; aspectRatio: string | null; dominantColor: string | null
    takenAt: Date | null; createdAt: Date
  }
  tags: string[]
  tagIds: string[]
}

/** Months back from now's month that hold photos: every month of the last 36 except each 5th (gaps). */
const DATED_MONTHS = Array.from({ length: 36 }, (_, m) => m).filter((m) => m % 5 !== 3)

export function mediaHomeRows(now: Date, sources: MediaHomeSource[], daysAgo: (n: number) => Date): MediaHomeRow[] {
  const dated = MEDIA_HOME_ROW_COUNT - MEDIA_HOME_UNDATED
  let tagN = 0
  return Array.from({ length: MEDIA_HOME_ROW_COUNT }, (_, i) => {
    const src = sources[i % sources.length]
    let takenAt: Date | null = null
    if (i < dated) {
      const monthsBack = DATED_MONTHS[i % DATED_MONTHS.length]
      const t = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - monthsBack, 1 + ((i * 7) % 27), 8 + (i % 10), (i * 13) % 60))
      takenAt = t.getTime() > now.getTime() ? new Date(now.getTime() - (i + 1) * 3_600_000) : t
    }
    const tags = i % 4 === 0
      ? [MEDIA_HOME_TAGS[i % MEDIA_HOME_TAGS.length], MEDIA_HOME_TAGS[(i + 3) % MEDIA_HOME_TAGS.length]]
      : [MEDIA_HOME_TAGS[i % MEDIA_HOME_TAGS.length]]
    return {
      media: {
        id: fixtureId('media', MEDIA_HOME_FIRST_N + i),
        title: `Library photo ${i + 1}`,
        url: src.url,
        thumbnailUrl: src.thumbnailUrl,
        type: 'photo',
        mimeType: 'image/jpeg',
        organizationId: FIXTURE_ORG_ID,
        uploadedBy: i % 3 === 0 ? FIXTURE_LEADER_USER_ID : FIXTURE_USER_ID,
        visibility: 'members',
        uploadStatus: 'ready',
        source: 'direct',
        width: src.width,
        height: src.height,
        aspectRatio: src.aspectRatio,
        dominantColor: src.dominantColor,
        takenAt,
        createdAt: daysAgo(i % 30),
      },
      tags,
      tagIds: tags.map(() => fixtureId('mediaTag', ++tagN)),
    }
  })
}

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  const sources = await prisma.media.findMany({
    where: { organizationId: FIXTURE_ORG_ID, source: 'direct' },
    orderBy: { id: 'asc' },
    select: { url: true, thumbnailUrl: true, width: true, height: true, aspectRatio: true, dominantColor: true },
  })
  if (sources.length === 0) return // base placed no images: Media stays empty (R3)
  const rows = mediaHomeRows(ctx.now, sources, (n) => ctx.daysAgo(n))
  await prisma.media.createMany({ data: rows.map((r) => r.media) })
  await prisma.mediaTag.createMany({
    data: rows.flatMap((r) => r.tags.map((tag, k) => ({ id: r.tagIds[k], mediaId: r.media.id, tag }))),
  })
}
```

Check `fixtureId`'s signature in `ids.ts` accepts the new kind key (it takes `keyof typeof FIXTURE_KIND`). If `ctx.daysAgo` already exists on the context (it does: `context.ts:181`), keep it as written.

Update `server/fixtures/README.md` §Fixed IDs (`:137`): append `` `001c` media tags`` to the kind list, and in the layer list add a line `screens/media-home.ts — 360 library photos over 3 years for the Media page (media-page D14); empty without base images`.

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run fixtures/__tests__/media-home.test.ts` → PASS; `cd server && npx tsc --noEmit -p fixtures` → clean; `cd server && npx vitest run fixtures/__tests__/runner.test.ts` → PASS (the runner discovers `screens/*.ts`; the layer exports only `full`).

- [ ] **Step 5: Commit, recording the contract freeze in the same commit** — the producer phase closes here (SPEC §Contract freezes):

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/advance.mjs docs/features/media-page \
  --set "contract=frozen $(date +%F)" \
  --add server/fixtures/ids.ts --add server/fixtures/README.md \
  --add server/fixtures/screens/media-home.ts --add server/fixtures/__tests__/media-home.test.ts \
  --commit "feat(media-page): media-home fixtures layer; contract frozen"
```

### Task 5: Cover picks send their capture date
App: iphone
Phase: 3
Recipe: /ios-error-surface (the pick's catch stays as is) · SPEC D3, §iphone "Cover capture date"

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Shared/CaptureDate.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Groups/ImageFramingModel.swift:5-10` (`ImageEditSource.newPick`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift:60-91` (`Opening`, `immediateOpening`), `:211-216` (save closure)
- Modify: `iphone/MakeReady/UI2/Containers/Members/EditMemberAvatarContainer.swift:73` (pattern only)
- Modify: `iphone/MakeReady/UI2/Containers/Shared/CoverOwner.swift:37-46` (`save`)
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift:370-391`, `iphone/MakeReady/State/Actions/ProgramActions.swift:671-692` (`saveCover`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift:164-170`, `iphone/MakeReady/UI2/Containers/Programs/StudyProgramHomeContainer.swift:206-213` (`openPicked`)
- Modify: `iphone/MakeReady/State/Actions/MediaActions.swift:340-371` (`uploadPhoto` gains `sourceData:`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register the new files)
- Test: `iphone/MakeReadyCaptureTests/CaptureDateTests.swift` (new), `iphone/MakeReadyCaptureTests/GroupSaveCoverTests.swift`, `iphone/MakeReadyCaptureTests/ProgramActionsTests.swift`

**Interfaces:**
- Produces: `enum CaptureDate { static func read(from data: Data, deviceTimeZone: TimeZone = .current) -> String?; static func format(exifDateTime: String, in zone: TimeZone) -> String?; static func timeZone(offset: String) -> TimeZone? }`; `ImageEditSource.newPick(UIImage, takenAt: String? = nil)`; `GroupActions.saveCover(groupId:rendered:framing:original:takenAt:)` and `ProgramActions.saveCover(programId:rendered:framing:original:takenAt:)` with `takenAt: String? = nil`; `CoverOwner.save(rendered:framing:original:takenAt:)`; `MediaActions.uploadPhoto(image:title:sourceData:)` with `sourceData: Data? = nil`.

New Swift files are registered in `project.pbxproj` the way commit `699726a0` registered `CoverOwner.swift` (app target `MakeReady`) and `ProgramCoverTapTests.swift` (test target `MakeReadyCaptureTests`): a `PBXFileReference`, a `PBXBuildFile`, the group's `children` entry and the target's Sources phase entry. Then run `ruby iphone/scripts/capture-targets.rb` so the MakeReadyCapture target picks up the new app file.

- [ ] **Step 1: Write the failing tests** — `iphone/MakeReadyCaptureTests/CaptureDateTests.swift`:

```swift
import XCTest
import ImageIO
import UIKit
import UniformTypeIdentifiers
@testable import MakeReady

/// media-page D3: the capture date a cover pick sends — DateTimeOriginal (+ OffsetTimeOriginal when present,
/// else the device's zone), as ISO 8601 with an offset; nil when the file has none.
final class CaptureDateTests: XCTestCase {
    private func imageData(_ type: UTType, exif: [CFString: Any]?) throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else {
            throw XCTSkip("\(type.identifier) encoding is unavailable on this simulator")
        }
        var props: [CFString: Any] = [:]
        if let exif { props[kCGImagePropertyExifDictionary] = exif }
        CGImageDestinationAddImage(dest, try XCTUnwrap(image.cgImage), props as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return out as Data
    }

    private let chicago = TimeZone(identifier: "America/Chicago")!

    func testDatedJPEGUsesTheDeviceZone() throws {
        let data = try imageData(.jpeg, exif: [kCGImagePropertyExifDateTimeOriginal: "2025:06:14 09:30:00"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2025-06-14T09:30:00-05:00")
    }

    func testDatedHEIC() throws {
        let data = try imageData(.heic, exif: [kCGImagePropertyExifDateTimeOriginal: "2024:01:05 08:00:00"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2024-01-05T08:00:00-06:00")
    }

    func testOffsetTimeOriginalWinsOverTheDevice() throws {
        let data = try imageData(.jpeg, exif: [kCGImagePropertyExifDateTimeOriginal: "2025:06:14 09:30:00",
                                               kCGImagePropertyExifOffsetTimeOriginal: "+05:30"])
        XCTAssertEqual(CaptureDate.read(from: data, deviceTimeZone: chicago), "2025-06-14T09:30:00+05:30")
    }

    func testNoDateIsNil() throws {
        XCTAssertNil(CaptureDate.read(from: try imageData(.jpeg, exif: nil), deviceTimeZone: chicago))
        XCTAssertNil(CaptureDate.read(from: Data("not an image".utf8), deviceTimeZone: chicago))
    }

    func testMalformedValuesAreNil() {
        XCTAssertNil(CaptureDate.format(exifDateTime: "2025:13:14 09:30:00", in: chicago))
        XCTAssertNil(CaptureDate.format(exifDateTime: "0000:00:00 00:00:00", in: chicago))
        XCTAssertNil(CaptureDate.timeZone(offset: "05:30"))
        XCTAssertEqual(CaptureDate.timeZone(offset: "-07:00")?.secondsFromGMT(), -25_200)
    }
}
```

and add to `GroupSaveCoverTests` (and the matching program case to `ProgramActionsTests`, endpoint `/api/programs/p1/cover-image`, using that file's existing `actions`/`image()` helpers):

```swift
    func testNewPickSendsTakenAt() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing,
                                                                     original: image(), takenAt: "2025-06-14T09:30:00-05:00")
        XCTAssertEqual(api.calls.last?.body?["takenAt"] as? String, "2025-06-14T09:30:00-05:00")
    }

    func testNoTakenAtSendsNoKey() async throws {
        stubSuccess()
        _ = try await GroupActions(api: api, state: state).saveCover(groupId: "g1", rendered: image(), framing: framing, original: nil)
        XCTAssertNil(api.calls.last?.body?["takenAt"])
    }
```

and a source-equality case to `EditGroupCoverContainerTests` (beside its `:35` case): `XCTAssertNotEqual(UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img, takenAt: "2025-06-14T09:30:00-05:00")), UI2Destination.editGroupCover(groupId: "g1", source: .newPick(img)))`.

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile (`cannot find 'CaptureDate'`, `extra argument 'takenAt'`).

- [ ] **Step 3: Write `CaptureDate.swift`** (`iphone/MakeReady/UI2/Containers/Shared/CaptureDate.swift`):

```swift
import Foundation
import ImageIO

/// media-page D3: the date a picked photo was taken, read from its bytes while they still exist
/// (the cover is re-encoded before upload, which strips EXIF). `DateTimeOriginal` is a wall-clock
/// time; its zone is `OffsetTimeOriginal` when the file carries one, else the device's. The result
/// is ISO 8601 with an offset ("2025-06-14T09:30:00-05:00"), or nil when the file has no date.
enum CaptureDate {
    static func read(from data: Data, deviceTimeZone: TimeZone = .current) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
              let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let zone = (exif[kCGImagePropertyExifOffsetTimeOriginal] as? String).flatMap(timeZone(offset:)) ?? deviceTimeZone
        return format(exifDateTime: original, in: zone)
    }

    /// "yyyy:MM:dd HH:mm:ss" read as a wall-clock time in `zone`.
    static func format(exifDateTime raw: String, in zone: TimeZone) -> String? {
        let parts = raw.split(whereSeparator: { $0 == ":" || $0 == " " }).compactMap { Int($0) }
        guard parts.count == 6, parts[0] >= 1900, (1...12).contains(parts[1]), (1...31).contains(parts[2]),
              (0...23).contains(parts[3]), (0...59).contains(parts[4]), (0...60).contains(parts[5]) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts[3], minute: parts[4], second: parts[5])
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        let seconds = zone.secondsFromGMT(for: date)
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return "\(parts[0])-\(two(parts[1]))-\(two(parts[2]))T\(two(parts[3])):\(two(parts[4])):\(two(parts[5]))"
            + "\(sign)\(two(magnitude / 3600)):\(two((magnitude % 3600) / 60))"
    }

    /// "+05:30" / "-07:00" → that fixed zone; anything else nil.
    static func timeZone(offset: String) -> TimeZone? {
        guard let first = offset.first, first == "+" || first == "-" else { return nil }
        let fields = offset.dropFirst().split(separator: ":").compactMap { Int($0) }
        guard fields.count == 2, (0...14).contains(fields[0]), (0..<60).contains(fields[1]) else { return nil }
        let seconds = fields[0] * 3600 + fields[1] * 60
        return TimeZone(secondsFromGMT: first == "-" ? -seconds : seconds)
    }
}
```

- [ ] **Step 4: Carry it through** —
  - `ImageFramingModel.swift`: `case newPick(UIImage, takenAt: String? = nil)` (doc: "media-page D3: the pick's capture date, sent with a new cover").
  - `EditGroupCoverContainer.swift`: `Opening` gains `let takenAt: String?`; `immediateOpening` → `case let .newPick(image, takenAt): return Opening(image: image, framing: .identity, isNewPick: true, hasStoredOriginal: true, takenAt: takenAt)` and the `.stored` branch passes `takenAt: nil`; in `makeModelIfReady` capture it — `let takenAt = opening.takenAt` before the closure, and `try await owner.save(rendered: rendered, framing: framing, original: original, takenAt: takenAt)`.
  - `EditMemberAvatarContainer.swift:73`: `case let .newPick(image, _):` (the avatar route never adds to the library — untouched otherwise).
  - `CoverOwner.save(rendered:framing:original:takenAt: String? = nil)` passes `takenAt: takenAt` to both `saveCover` calls.
  - `GroupActions.saveCover(… original: UIImage?, takenAt: String? = nil)` and `ProgramActions.saveCover(… original: UIImage?, takenAt: String? = nil)`: after the `original` block, `if let takenAt { body["takenAt"] = takenAt }`.
  - `GroupDetailContainer.openPicked`: `navigator.push(.editGroupCover(groupId: groupId, source: .newPick(image, takenAt: CaptureDate.read(from: data))))`; `StudyProgramHomeContainer.openPicked`: `navigator.push(coverOwner.destination(.newPick(image, takenAt: CaptureDate.read(from: data))))`.
  - `MediaActions.uploadPhoto(image: UIImage, title: String = "Photo", sourceData: Data? = nil)`: build `body` as `var`, then `if let takenAt = sourceData.flatMap({ CaptureDate.read(from: $0) }) { body["takenAt"] = takenAt }` (parity; it has no 2.0 caller).
  - Register `CaptureDate.swift` (MakeReady target) and `CaptureDateTests.swift` (MakeReadyCaptureTests target) in the pbxproj, then `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 5: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS (CaptureDateTests, GroupSaveCoverTests, ProgramActionsTests, EditGroupCoverContainerTests green; a skipped HEIC case is reported, not failed); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 6: Commit** — `feat(media-page): cover picks send the photo's capture date`

### Task 6: `MediaLibraryItem.takenAt` + `MediaActions.loadAllPhotos`
App: iphone
Phase: 3
Recipe: /ios-error-surface · iphone/.claude/CLAUDE.md §State Management · SPEC D2, D13, D17, F6 · build-time risk R4: `PersistedState` caps persisted media at the 100 newest by `createdAt` (`PersistedState.swift:205`), so a cold launch shows a partial grid until `loadAllPhotos` finishes — settled in Task 11's container

**Files:**
- Modify: `iphone/MakeReady/State/Models/MediaModels.swift:40-95` (`MediaLibraryItem`)
- Modify: `iphone/MakeReady/State/Actions/MediaActions.swift:15-31` (init), new `loadAllPhotos` after `fetchLibrary`
- Modify: `iphone/MakeReady/State/AppState.swift:223-230` (new `mediaPhotosLoadedOrgId`), `:973-974` (`clearInMemory`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register the tests)
- Test: `iphone/MakeReadyCaptureTests/MediaLoadAllPhotosTests.swift` (new), `iphone/MakeReadyCaptureTests/MediaTakenAtDecodingTests.swift` (new)

**Interfaces:**
- Produces: `MediaLibraryItem.takenAt: Date?` (last stored property, default nil, so the memberwise init at `CaptureEnvironment.swift:285` still compiles); `MediaLibraryItem.sortDate: Date` (`takenAt ?? createdAt`); `enum PhotoLoadOutcome: Equatable { case completed, stopped, failed }` (in MediaActions.swift); `MediaActions.init(api:state:onUnauthorized:)` with `onUnauthorized: @escaping @MainActor () async -> Void = {}`; `@MainActor func loadAllPhotos(pageSize: Int = 200, resumeCursor: String? = nil) async -> PhotoLoadOutcome`; `AppState.mediaPhotosLoadedOrgId: String?`.

- [ ] **Step 1: Write the failing tests** — `MediaTakenAtDecodingTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// media-page §iphone Model: takenAt decodes as `.000Z`, as null and absent; sortDate falls back to createdAt.
final class MediaTakenAtDecodingTests: XCTestCase {
    private func item(_ takenAt: String) throws -> MediaLibraryItem {
        let json = """
        {"id":"m1","title":"T","url":"https://img/x.jpeg","type":"photo","uploadStatus":"ready","tags":[],"usageCount":0,
         "createdAt":"2026-10-01T12:00:00.000Z","updatedAt":"2026-10-01T12:00:00.000Z"\(takenAt)}
        """
        return try JSONDecoder.apiDecoder.decode(MediaLibraryItem.self, from: Data(json.utf8))
    }

    func testDecodesFractionalZ() throws {
        let i = try item(#","takenAt":"2025-06-14T14:30:00.000Z""#)
        XCTAssertEqual(i.takenAt, ISO8601DateFormatter().date(from: "2025-06-14T14:30:00Z"))
        XCTAssertEqual(i.sortDate, i.takenAt)
    }

    func testNullAndAbsentFallBackToCreatedAt() throws {
        XCTAssertNil(try item(#","takenAt":null"#).takenAt)
        let absent = try item("")
        XCTAssertNil(absent.takenAt)
        XCTAssertEqual(absent.sortDate, absent.createdAt)
    }
}
```

and `MediaLoadAllPhotosTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// media-page D2/D13/F6: loadAllPhotos follows nextCursor until hasMore is false, writing each page as it
/// lands; an error keeps the loaded pages; cancellation, a sign-out or an org change stops the writes.
@MainActor
final class MediaLoadAllPhotosTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let base = "/api/organizations/o1/media/library?type=photo&limit=2"

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        state.organizationId = "o1"
        api = StubAPIClient()
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func item(_ id: String) -> String {
        #"{"id":"\#(id)","title":"\#(id)","url":"https://img/\#(id).jpeg","type":"photo","uploadStatus":"ready","tags":[],"usageCount":0,"createdAt":"2026-10-01T12:00:00.000Z","updatedAt":"2026-10-01T12:00:00.000Z","takenAt":null}"#
    }

    private func page(_ ids: [String], total: Int? = nil, next: String?) -> String {
        let totalPart = total.map { #","total":\#($0)"# } ?? ""
        let cursor = next.map { #""\#($0)""# } ?? "null"
        return #"{"success":true,"data":[\#(ids.map(item).joined(separator: ","))]\#(totalPart),"hasMore":\#(next != nil),"nextCursor":\#(cursor)}"#
    }

    private func stubThreePages() {
        api.stub("GET", base, json: page(["a", "b"], total: 5, next: "c1"))
        api.stub("GET", base + "&cursor=c1", json: page(["c", "d"], next: "c2"))
        api.stub("GET", base + "&cursor=c2", json: page(["e"], next: nil))
    }

    func testFollowsTheCursorUntilHasMoreIsFalse() async {
        stubThreePages()
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
        XCTAssertEqual(api.calls.count, 3)
        XCTAssertEqual(state.mediaLibraryTotal, 5)
        XCTAssertNil(state.mediaLibraryNextCursor)
        XCTAssertEqual(state.mediaPhotosLoadedOrgId, "o1")
    }

    func testAnErrorKeepsTheLoadedPagesAndARetryResumesFromTheCursor() async {
        stubThreePages()
        api.errorFor = { endpoint, _ in endpoint.hasSuffix("cursor=c1") ? APIError.serverError("boom") : nil }
        let failed = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
        XCTAssertEqual(state.mediaLibraryNextCursor, "c1")
        XCTAssertNil(state.mediaPhotosLoadedOrgId)

        api.errorFor = nil
        let resumed = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2, resumeCursor: "c1")
        XCTAssertEqual(resumed, .completed)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b", "c", "d", "e"])
    }

    func testASignOutMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.initialLoad.reset() } }
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    func testAnOrgChangeMidLoadStopsTheWrites() async {
        stubThreePages()
        api.beforeReturn = { [state] endpoint, _ in if endpoint.hasSuffix("cursor=c1") { state?.organizationId = "o2" } }
        let outcome = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertEqual(Set(state.mediaLibrary.all.map(\.id)), ["a", "b"])
    }

    func testA401SignsOut() async {
        api.errorToThrow = APIError.unauthorized
        var signedOut = false
        let outcome = await MediaActions(api: api, state: state, onUnauthorized: { signedOut = true }).loadAllPhotos(pageSize: 2)
        XCTAssertEqual(outcome, .stopped)
        XCTAssertTrue(signedOut)
    }

    func testClearInMemoryForgetsTheLoadedOrg() async {
        stubThreePages()
        _ = await MediaActions(api: api, state: state).loadAllPhotos(pageSize: 2)
        state.clearInMemory()
        XCTAssertNil(state.mediaPhotosLoadedOrgId)
    }
}
```

If `clearInMemory()` is private or named differently, call the method `AppState.swift:951` sits in (it clears `mediaLibrary`); if `AppState()` is not constructible in tests, use the pattern `GroupSaveCoverTests` uses (it is).

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile (`value of type 'MediaLibraryItem' has no member 'takenAt'`, `has no member 'loadAllPhotos'`).

- [ ] **Step 3: Implement** —
  - `MediaLibraryItem`: after `var updatedAt: Date` add `/// media-page D4: when the photo was taken; nil = unknown (sort by createdAt).` `var takenAt: Date? = nil`, and below `displayTitle`: `/// media-page D5: the grid's order and its month/year pills.` `var sortDate: Date { takenAt ?? createdAt }`.
  - `AppState`: beside `mediaLibraryNextCursor` add `/// media-page D17: the org whose whole photo library this session has loaded; nil = load on open.` `var mediaPhotosLoadedOrgId: String?`, and in the clear block beside `mediaLibraryNextCursor = nil` add `mediaPhotosLoadedOrgId = nil`.
  - `MediaActions`: add `private let onUnauthorized: @MainActor () async -> Void` and the init parameter `onUnauthorized: @escaping @MainActor () async -> Void = {}`; then add:

```swift
/// media-page D2: how a whole-library load ended.
enum PhotoLoadOutcome: Equatable {
    /// Every page landed.
    case completed
    /// Cancelled, signed out, or the org changed: nothing more was written.
    case stopped
    /// A page failed; the pages before it stay, and `mediaLibraryNextCursor` resumes it.
    case failed
}
```

```swift
    /// media-page D2: the whole photo library, one page after another until the server says there is no
    /// more. Page 1 replaces the store and later pages append, each written as it lands, so the grid
    /// fills while it loads. Before each write: not cancelled, same session generation, same org (F6).
    /// A failure is console-only (D13: background load) and keeps what loaded.
    @MainActor
    func loadAllPhotos(pageSize: Int = 200, resumeCursor: String? = nil) async -> PhotoLoadOutcome {
        guard let orgId = state.organizationId else { return .stopped }
        let generation = state.initialLoad.generation
        var cursor = resumeCursor
        var replaces = resumeCursor == nil
        while true {
            var endpoint = "/api/organizations/\(orgId)/media/library?type=photo&limit=\(pageSize)"
            if let cursor { endpoint += "&cursor=\(DashboardActions.queryValue(cursor))" }
            let response: MediaLibraryResponse
            do {
                response = try await api.get(endpoint, responseType: MediaLibraryResponse.self)
            } catch {
                if Task.isCancelled || UI2ImageLoader.isCancellation(error) { return .stopped }
                if AuthStatusPolicy.shouldSignOut(after: error) {
                    await onUnauthorized()
                    return .stopped
                }
                state.recordError(error, context: "MediaActions.loadAllPhotos", surface: false)
                return .failed
            }
            guard !Task.isCancelled, state.initialLoad.isCurrent(generation), state.organizationId == orgId else { return .stopped }
            guard let items = response.data else {
                state.recordError(APIError.serverError(response.error ?? "Failed to load media library"),
                                  context: "MediaActions.loadAllPhotos", surface: false)
                return .failed
            }
            if replaces {
                state.mediaLibrary.replaceAll(items)
                replaces = false
            } else {
                state.mediaLibrary.upsertMany(items)
            }
            if let total = response.total { state.mediaLibraryTotal = total }
            state.mediaLibraryNextCursor = response.nextCursor
            guard response.hasMore == true, let next = response.nextCursor else { break }
            cursor = next
        }
        state.mediaLibraryTotal = state.mediaLibrary.count
        state.mediaPhotosLoadedOrgId = orgId
        state.persist()
        return .completed
    }
```

  - Register both test files in the `MakeReadyCaptureTests` target.

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `feat(media-page): MediaLibraryItem.takenAt and loadAllPhotos`

### Task 7: `MediaHomeMapper` — order, search, chips, tile URLs
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management (pure mapper beside the container, as `MembersHomeMapper`) · SPEC D5–D8, D10, F13

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Media/MediaHomeMapper.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (new group `Media` under `UI2/Containers`, the file in the MakeReady target; the test in MakeReadyCaptureTests), then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MediaHomeMapperTests.swift`

**Interfaces:**
- Consumes: `MediaLibraryItem.sortDate`, `.takenAt`, `.uploader: MediaUploader? {id, name}`, `.tags`, `.title`, `.description`, `.url`, `.thumbnailUrl`, `.type` (Task 6).
- Produces:

```swift
enum MediaHomeMapper {
    enum TimeWindow: String, CaseIterable, Equatable { case all, last7, last30, last90 }   // .label, .days
    struct Selection: Equatable { var search = ""; var tags: Set<String> = []; var leaderIds: Set<String> = []; var time: TimeWindow = .all; var hasFilters: Bool }
    struct Option: Equatable { let id: String; let label: String }
    struct Tile: Equatable, Identifiable { let id: String; let mediumURL: URL?; let thumbURL: URL?; let fullURL: String; let date: Date; let title: String }
    struct Output: Equatable { let tiles: [Tile]; let tagOptions: [String]; let leaderOptions: [Option]; let dateRange: ClosedRange<Date>?; let isEmptyLibrary: Bool; let isNoResults: Bool }
    static func output(items: [MediaLibraryItem], selection: Selection, today: Date, timeZone: TimeZone) -> Output
    static func tileURLs(url: String, thumbnailUrl: String?) -> (medium: URL?, thumb: URL?)
    static func cutoff(_ window: TimeWindow, today: Date, timeZone: TimeZone) -> Date?
}
```

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/MediaHomeMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// media-page D5–D8, D10: oldest→newest by takenAt ?? createdAt; search; Tags / Leaders / Time with AND.
final class MediaHomeMapperTests: XCTestCase {
    typealias M = MediaHomeMapper
    private let chicago = TimeZone(identifier: "America/Chicago")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-31T17:00:00Z")!   // 12:00 in Chicago

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func item(_ id: String, created: String = "2026-10-01T12:00:00Z", taken: String? = nil, title: String = "",
                      description: String? = nil, tags: [String] = [], uploader: (String, String)? = ("u1", "Ann"),
                      url: String? = nil, thumb: String? = nil, type: String = "photo") -> MediaLibraryItem {
        MediaLibraryItem(id: id, title: title, description: description, url: url ?? "https://img/\(id).jpeg", type: type,
                         mimeType: nil, fileSize: nil, thumbnailUrl: thumb ?? "https://img/\(id)-thumb.jpeg",
                         uploadStatus: "ready", duration: nil, tags: tags, usageCount: 0,
                         uploader: uploader.map { MediaUploader(id: $0.0, name: $0.1) }, video: nil,
                         createdAt: date(created), updatedAt: date(created), takenAt: taken.map(date))
    }

    private func ids(_ items: [MediaLibraryItem], _ s: M.Selection = .init()) -> [String] {
        M.output(items: items, selection: s, today: today, timeZone: chicago).tiles.map(\.id)
    }

    func testOrdersOldestToNewestByTakenAtElseCreatedAtTiesById() {
        let items = [item("c", created: "2026-10-03T00:00:00Z"),
                     item("a", created: "2026-10-30T00:00:00Z", taken: "2025-06-14T14:30:00Z"),
                     item("b", created: "2026-10-03T00:00:00Z"),
                     item("v", type: "video")]
        XCTAssertEqual(ids(items), ["a", "b", "c"])
    }

    func testSearchMatchesTitleDescriptionTagAndUploaderCaseInsensitively() {
        let items = [item("t", title: "Easter Sunrise"), item("d", description: "at the LAKE"),
                     item("g", tags: ["baptism"]), item("u", uploader: ("u9", "Nathan Hughes")), item("x")]
        XCTAssertEqual(ids(items, .init(search: "sunrise")), ["t"])
        XCTAssertEqual(ids(items, .init(search: "lake")), ["d"])
        XCTAssertEqual(ids(items, .init(search: "BAPT")), ["g"])
        XCTAssertEqual(ids(items, .init(search: "hughes")), ["u"])
        XCTAssertEqual(ids(items, .init(search: "  ")).count, 5)
    }

    func testTagsAnyOfAndOptionsFromTheLoadedListSorted() {
        let items = [item("1", tags: ["youth", "retreat"]), item("2", tags: ["family"]), item("3")]
        XCTAssertEqual(ids(items, .init(tags: ["Retreat", "family"])), ["1", "2"])
        XCTAssertEqual(M.output(items: items, selection: .init(), today: today, timeZone: chicago).tagOptions,
                       ["family", "retreat", "youth"])
    }

    func testLeadersByIdSameNamesKeptApartAndNoUploaderOnlyWhenEmpty() {
        let items = [item("1", uploader: ("u1", "Sam")), item("2", uploader: ("u2", "Sam")), item("3", uploader: nil)]
        let out = M.output(items: items, selection: .init(), today: today, timeZone: chicago)
        XCTAssertEqual(out.leaderOptions, [.init(id: "u1", label: "Sam"), .init(id: "u2", label: "Sam")])
        XCTAssertEqual(ids(items, .init(leaderIds: ["u2"])), ["2"])
        XCTAssertEqual(ids(items).count, 3)
    }

    func testTimeCutoffIsStartOfTodayMinusNMinusOneDaysInTheDeviceZone() {
        // Chicago 2026-10-31: last 7 days starts 2026-10-25 00:00 CDT = 05:00Z.
        XCTAssertEqual(M.cutoff(.last7, today: today, timeZone: chicago), date("2026-10-25T05:00:00Z"))
        XCTAssertNil(M.cutoff(.all, today: today, timeZone: chicago))
        let items = [item("in", taken: "2026-10-25T05:00:00Z"), item("out", taken: "2026-10-25T04:59:59Z")]
        XCTAssertEqual(ids(items, .init(time: .last7)), ["in"])
    }

    func testChipsCombineWithAnd() {
        let items = [item("1", tags: ["youth"], uploader: ("u1", "Ann")), item("2", tags: ["youth"], uploader: ("u2", "Bo"))]
        XCTAssertEqual(ids(items, .init(tags: ["youth"], leaderIds: ["u2"])), ["2"])
    }

    func testTileURLFallbacks() {
        XCTAssertEqual(M.tileURLs(url: "https://img/a.jpeg", thumbnailUrl: "https://img/a-thumb.jpeg").medium?.absoluteString, "https://img/a-md.jpeg")
        let png = M.tileURLs(url: "https://img/a.png", thumbnailUrl: nil)
        XCTAssertNil(png.medium)
        XCTAssertEqual(png.thumb?.absoluteString, "https://img/a.png")
    }

    func testEmptyAndNoResultsAndDateRange() {
        XCTAssertTrue(M.output(items: [], selection: .init(), today: today, timeZone: chicago).isEmptyLibrary)
        let items = [item("a", taken: "2024-01-05T08:00:00Z"), item("b", taken: "2025-06-14T14:30:00Z")]
        let none = M.output(items: items, selection: .init(search: "zzz"), today: today, timeZone: chicago)
        XCTAssertTrue(none.isNoResults)
        XCTAssertFalse(none.isEmptyLibrary)
        XCTAssertEqual(M.output(items: items, selection: .init(), today: today, timeZone: chicago).dateRange,
                       date("2024-01-05T08:00:00Z")...date("2025-06-14T14:30:00Z"))
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile (`cannot find 'MediaHomeMapper'`).

- [ ] **Step 3: Implement** `iphone/MakeReady/UI2/Containers/Media/MediaHomeMapper.swift`:

```swift
import Foundation

/// media-page §iphone State: AppState.mediaLibrary → what MediaHomeScreen shows. Pure (today and the
/// time zone are inputs), so the order, search and chips are tested without a view.
enum MediaHomeMapper {
    /// D7 Time chip (single-select).
    enum TimeWindow: String, CaseIterable, Equatable {
        case all, last7, last30, last90
        var label: String {
            switch self {
            case .all: return "All time"
            case .last7: return "Last 7 days"
            case .last30: return "Last 30 days"
            case .last90: return "Last 90 days"
            }
        }
        var days: Int? {
            switch self {
            case .all: return nil
            case .last7: return 7
            case .last30: return 30
            case .last90: return 90
            }
        }
    }

    /// The search text and chip picks — the container's `@State`.
    struct Selection: Equatable {
        var search = ""
        var tags: Set<String> = []
        var leaderIds: Set<String> = []
        var time: TimeWindow = .all
        var hasFilters: Bool {
            !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !tags.isEmpty || !leaderIds.isEmpty || time != .all
        }
    }

    struct Option: Equatable {
        let id: String
        let label: String
    }

    /// One grid tile (D10): `mediumURL` at 5 columns, `thumbURL` denser and as every fallback.
    struct Tile: Equatable, Identifiable {
        let id: String
        let mediumURL: URL?
        let thumbURL: URL?
        let fullURL: String
        let date: Date
        let title: String
    }

    struct Output: Equatable {
        /// Oldest → newest (D5).
        let tiles: [Tile]
        let tagOptions: [String]
        let leaderOptions: [Option]
        /// The shown tiles' first and last date; nil when none.
        let dateRange: ClosedRange<Date>?
        let isEmptyLibrary: Bool
        let isNoResults: Bool
    }

    static func output(items: [MediaLibraryItem], selection: Selection, today: Date, timeZone: TimeZone) -> Output {
        let photos = items.filter { $0.type == "photo" }
            .sorted { $0.sortDate == $1.sortDate ? $0.id < $1.id : $0.sortDate < $1.sortDate }
        let tagOptions = Set(photos.flatMap { $0.tags.map { $0.lowercased() } }).sorted()
        var leaders: [String: String] = [:]
        for item in photos { if let u = item.uploader { leaders[u.id] = u.name } }
        let leaderOptions = leaders.map { Option(id: $0.key, label: $0.value) }.sorted {
            let order = $0.label.localizedCaseInsensitiveCompare($1.label)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        let cutoff = cutoff(selection.time, today: today, timeZone: timeZone)
        let query = selection.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantedTags = Set(selection.tags.map { $0.lowercased() })
        let shown = photos.filter { item in
            if !query.isEmpty, !matches(item, query: query) { return false }
            if !wantedTags.isEmpty, wantedTags.isDisjoint(with: item.tags.map { $0.lowercased() }) { return false }
            if !selection.leaderIds.isEmpty {
                guard let id = item.uploader?.id, selection.leaderIds.contains(id) else { return false }
            }
            if let cutoff, item.sortDate < cutoff { return false }
            return true
        }
        let tiles = shown.map { item -> Tile in
            let urls = tileURLs(url: item.url, thumbnailUrl: item.thumbnailUrl)
            return Tile(id: item.id, mediumURL: urls.medium, thumbURL: urls.thumb, fullURL: item.url,
                        date: item.sortDate, title: item.displayTitle)
        }
        let range = tiles.first.flatMap { first in tiles.last.map { first.date...$0.date } }
        return Output(tiles: tiles, tagOptions: tagOptions, leaderOptions: leaderOptions, dateRange: range,
                      isEmptyLibrary: photos.isEmpty, isNoResults: !photos.isEmpty && tiles.isEmpty)
    }

    /// D10: `.jpeg` → `-md.jpeg` for the 5-column tile; `thumbnailUrl ?? url` otherwise and as the fallback.
    static func tileURLs(url: String, thumbnailUrl: String?) -> (medium: URL?, thumb: URL?) {
        let medium = url.hasSuffix(".jpeg") ? URL(string: String(url.dropLast(5)) + "-md.jpeg") : nil
        let thumbSource = (thumbnailUrl?.isEmpty == false ? thumbnailUrl : nil) ?? url
        return (medium, URL(string: thumbSource))
    }

    /// D7: start of today in `timeZone` minus (N − 1) days; nil for All time.
    static func cutoff(_ window: TimeWindow, today: Date, timeZone: TimeZone) -> Date? {
        guard let days = window.days else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: today))
    }

    /// D6: title, description, each tag and the uploader's name, case-insensitive substring.
    private static func matches(_ item: MediaLibraryItem, query: String) -> Bool {
        let fields = [item.title, item.description ?? "", item.uploader?.name ?? ""] + item.tags
        return fields.contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}
```

Register both files (new `Media` group under `UI2/Containers`), then `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Commit** — `feat(media-page): MediaHomeMapper — order, search, chips, tile URLs`

### Task 8: d2m designs and builds MediaBrowser and media-home
App: iphone
Phase: 4
Recipe: SPEC D11 · root CLAUDE.md "d2m-built views" · the d2m-channel MCP server's instructions · build-time risk R1: d2m has no MediaBrowser row, and media-home is `queued, specced: false` (`get_screen media-home` → `buildBlockedReason: no spec`; it has a design-4 PNG and `buildPath Screens/Media/MediaHomeScreen.swift`) — settled by this task, after B1 (resolved: `docs/ui2/references/media-browser.md` is on main, 2c807640) · 🔴 **This task needs the d2m-channel MCP tools** (`request_project_change`, `wait_project_change`, `answer_project_change`, `get_screen`, `get_component`, `list_components`): the build runs it in the controller's main context or in a `general-purpose` agent, never in `builder:implementer`, which has no MCP servers

**Files:**
- Create (by d2m, carried here): `iphone/MakeReadyUI/MediaBrowser.swift` (or the name d2m registers), `iphone/MakeReadyUI/Screens/Media/MediaHomeScreen.swift`, their `ViewRegistry.swift` / `CaptureFixture.swift` cases, and the `project.pbxproj` / `.swiftlint.yml` edits d2m's sync makes
- Never written by hand: anything under `iphone/MakeReadyUI/` (d2m owns it) and anything under `docs/ui2/` (d2m owns it)

**Interfaces:**
- Produces (requested from d2m; the names d2m records in the two Swift files are the binding ones, and Task 11 reads them there):

```swift
// MediaBrowser (new registry row)
struct MediaBrowser: View {
    struct Item: Identifiable, Equatable { let id: String; let date: Date; let accessibilityLabel: String }
    enum Level: Int, CaseIterable { case five, eight, fourteen, thirty }   // ~5 · ~8 · ~13–15 · 30+ columns
    init(items: [Item],                                  // oldest → newest; bottom-anchored (inserts above keep visible tiles still)
         image: @escaping (String) -> UIImage?,          // the container's cache; nil = dark placeholder
         imageGeneration: Int,                           // bumps when new images land
         hiddenItemID: String? = nil,                    // the open item's tile draws blank
         isFrozen: Bool = false,                         // viewer open: no scroll, no level change
         scrollToNewestToken: Int = 0,                   // a change scrolls to the newest end, keeping the level
         timeZone: TimeZone = .current,                  // month/year pills (D5)
         onVisibleRangeChange: @escaping (Range<Int>, Level) -> Void = { _, _ in },   // visible + prefetch (D18)
         onTap: @escaping (String, CGRect) -> Void,      // item id + the tile's GLOBAL frame
         onScrollChange: @escaping (CGFloat, Bool) -> Void = { _, _ in },   // offset from the top incl. insets, finger down (D16)
         onRefresh: (() async -> Void)? = nil)           // pull past the newest end (D16)
}
// MediaHomeScreen (screen media-home)
struct MediaHomeScreen: View {
    struct State: Equatable {
        enum Phase: Equatable { case loading, loaded, empty, noResults, failed }
        var phase: Phase; var query: String; var dateRange: ClosedRange<Date>?
        var tagOptions: [String]; var selectedTags: Set<String>
        var leaderOptions: [(id: String, label: String)] /* or a named Option struct */; var selectedLeaders: Set<String>
        var timeOptions: [String]; var selectedTime: String
    }
    // + the MediaBrowser inputs above passed through, and:
    // onSearch(String), onSaveTags(Set<String>), onSaveLeaders(Set<String>), onSaveTime(String),
    // onClearFilters(), onRetry(), onSearchActiveChange(Bool)
}
```

- [ ] **Step 1: Snapshot the owner's checkout** — d2m writes into its project's `repoPath`, `/Users/lukekeith/www/makeready` (the owner's main checkout), not this worktree. Record what is already dirty there so nothing of the owner's is touched:

```bash
MAIN=/Users/lukekeith/www/makeready
git -C "$MAIN" status --porcelain -- iphone/MakeReadyUI iphone/MakeReadyCaptureTests iphone/MakeReady.xcodeproj iphone/.swiftlint.yml \
  > "$(/Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/workspace media-page)/d2m-before.txt"
```

- [ ] **Step 2: Check d2m's state** — `list_components` (search `MediaBrowser`) and `get_screen` (`screen: "media-home"`, `part: "summary"`). If a MediaBrowser row is already specced and built and media-home is built, skip to Step 5.

- [ ] **Step 3: Request the design** — one `request_project_change`, `subject: "media-home"`, `branch: "builder/media-page"`, `why: "media-page SPEC D1, D9–D12, D16, D18 (docs/features/media-page/SPEC.md on branch builder/media-page): the UI 2.0 Media page; the app container is written against these inputs"`, `intent:`

> Spec and build the media-home screen, and first mint, spec and build its grid as a new component, MediaBrowser, from the repo reference `docs/ui2/references/media-browser.md` (on main; §2 is the normative behaviour). media-home = the shell's TopNav and TabBar (not drawn by the screen) around C-034 SearchField, a row of C-035 FilterChip — Tags (C-036 `.multiple`, Save/Clear), Leaders (C-036 `.multiple`), Time (C-036 `.single`: All time · Last 7 days · Last 30 days · Last 90 days) — and MediaBrowser filling the rest; a header line shows the shown photos' date range. States: loading (MediaBrowser placeholders), loaded, empty (no photos), noResults (one line + a clear-filters action), failed (one line + Retry; loaded photos stay visible). MediaBrowser: four zoom levels (~5 · ~8 · ~13–15 · 30+ columns), crossfade anchored on the pinch so the photo under the fingers stays put, sticky month pills from ~8 columns and year pills from 30+ with push-off; opens at 5 columns on the newest (bottom) end; bottom-anchored — items inserted above the viewport leave the visible tiles still; a `scrollToNewestToken` change scrolls to the newest end keeping the level; `isFrozen` stops scroll and zoom; `hiddenItemID` draws that tile blank; tiles draw from an `image(id) -> UIImage?` provider plus an `imageGeneration` counter, never loading images themselves; it reports the visible + prefetch index range and level (`onVisibleRangeChange`), a tap with the tile's GLOBAL frame (`onTap`), its scroll offset from the top and whether a finger is down (`onScrollChange`, so the shell's TopNav can morph), and offers `onRefresh` on a pull past the newest end. Drags track the finger and a flick moves on its first frame at every level; no decode or network on the main thread. Use the input names in the request's Interfaces block (copied below) unless the rulebook (`get_rules`) says otherwise. Previews: at least one per zoom level, using only the 13 owner-uploaded portraits in the image catalog (`barry-allen` … `wade-wilson`).

  Paste the Interfaces block above into the intent after that paragraph.

- [ ] **Step 4: Wait, answer, retry** — call `wait_project_change` with the returned id (`timeoutSec: 900`) again and again while it returns `timedOut: true`. On `questions`: answer each with `answer_project_change` from SPEC §Decisions (D1, D5–D13, D16, D18 — quote the ruling's substance, never invent a product decision); a question no ruling settles takes d2m's recommended option, and say so in the report. On a stopped build: `retry_project_change` once, then wait again. On `answered` without a change card or `rejected`: read `next` and request again more precisely (at most two more requests). If d2m still has not built both after that, this is not code this task can write: report BLOCKED with the change ids and `next` text, and the controller parks the feature (`kind: human-step`: "d2m won't build media-home").

- [ ] **Step 5: Carry d2m's files into this branch** — from the finished change(s) (`get_project_change` → `files`, plus the screen's and component's build paths):

```bash
MAIN=/Users/lukekeith/www/makeready
for f in <each path d2m listed, relative to the repo root>; do
  mkdir -p "$(dirname "$f")"; cp "$MAIN/$f" "$f"
done
```

For a shared file d2m edited that was ALREADY dirty in `d2m-before.txt` (`ViewRegistry.swift`, `CaptureFixture.swift`, `project.pbxproj`, `.swiftlint.yml`), do not copy the whole file: take only d2m's hunks (`git -C "$MAIN" diff -- <file>` minus what the snapshot shows was there before) and apply them here with `git apply`. Then run `ruby iphone/scripts/makereadyui-sync.rb && ruby iphone/scripts/capture-targets.rb` here so the project file matches the new views.

- [ ] **Step 6: Leave the owner's checkout as it was** — for every path d2m changed that was CLEAN in `d2m-before.txt`: `git -C "$MAIN" checkout -- <path>` for a tracked file, `rm <path>` for a new untracked one. Paths that were dirty before are left exactly as they are, and listed in the report.

- [ ] **Step 7: Verify it compiles here** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 8: Commit, then tell d2m** — `feat(media-page): MediaBrowser and media-home from d2m` (only the carried files). Then `report_project_change` for each change id with this commit's sha, so d2m records the build as committed.

### Task 9: Media owns its scroll — the section opt-out and a shared morph rule
App: iphone
Phase: 5
Recipe: /transition-review (TopNav morph) · /animation-debug if the row misbehaves · SPEC D16, F7

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:5-8` (`UI2Section.ownsScroll`)
- Modify: `iphone/MakeReady/UI2/Shell/HomeSectionLayout.swift:43-55` (the opt-out branch), `:106-175` (`SectionPageScroll` uses the shared rule)
- Create: `iphone/MakeReady/UI2/Shell/SectionScrollMorph.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj`, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/SectionScrollMorphTests.swift`

**Interfaces:**
- Produces: `extension UI2Section { var ownsScroll: Bool }` (true only for `.media`); `enum SectionScrollMorph { static let expandPull: CGFloat = 12; static let collapseScroll: CGFloat = 8; static let triggerDuration: TimeInterval = 0.15; static func target(expansion: Double, interacting: Bool, offset: CGFloat) -> Double? }`; `struct SectionScrollReport { let report: @MainActor (CGFloat, Bool) -> Void }` with `EnvironmentValues.sectionScrollReport` (default: does nothing) — what a scroll-owning section calls with (offset from the top incl. insets, finger down).

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/SectionScrollMorphTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// media-page D16: one rule for the TopNav morph, whether the shell's page scroll or a section's own scroll reports it.
final class SectionScrollMorphTests: XCTestCase {
    func testPullPastTheTopWithAFingerDownOpensTheRow() {
        XCTAssertEqual(SectionScrollMorph.target(expansion: 0, interacting: true, offset: -12), 1)
        XCTAssertNil(SectionScrollMorph.target(expansion: 0, interacting: true, offset: -11))
        XCTAssertNil(SectionScrollMorph.target(expansion: 0, interacting: false, offset: -40))
    }

    func testScrollingUpWhileOpenClosesTheRow() {
        XCTAssertEqual(SectionScrollMorph.target(expansion: 1, interacting: false, offset: 8), 0)
        XCTAssertNil(SectionScrollMorph.target(expansion: 1, interacting: true, offset: 7))
    }

    func testMidMorphDoesNothing() {
        XCTAssertNil(SectionScrollMorph.target(expansion: 0.5, interacting: true, offset: -50))
    }

    func testOnlyMediaOwnsItsScroll() {
        XCTAssertEqual(UI2Section.allCases.filter(\.ownsScroll), [.media])
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile (`cannot find 'SectionScrollMorph'`).

- [ ] **Step 3: Implement** — `iphone/MakeReady/UI2/Shell/SectionScrollMorph.swift`:

```swift
import SwiftUI

/// SPEC D14 (ui2-shell) → media-page D16: when a section's vertical scroll opens or closes the TopNav row.
/// The shell's page scroll and a section that owns its scroll (Media's grid) report through this one rule.
enum SectionScrollMorph {
    // GAP — no pull distance in C-019; the reference fires on a short pull: 12pt past the top.
    static let expandPull: CGFloat = 12
    // GAP — the reference collapses as soon as the page moves up: 8pt, past touch jitter.
    static let collapseScroll: CGFloat = 8
    // GAP — the page-triggered morph settles in ~130ms in the reference.
    static let triggerDuration: TimeInterval = 0.15

    /// The expansion to morph to, or nil to leave the row alone. `offset` is the scroll's distance from
    /// its top including insets (negative = pulled past the top).
    static func target(expansion: Double, interacting: Bool, offset: CGFloat) -> Double? {
        if expansion == 0, interacting, offset <= -expandPull { return 1 }
        if expansion == 1, offset >= collapseScroll { return 0 }
        return nil
    }
}

/// media-page D16: how a section that owns its scroll reports it to the shell's TopNav.
struct SectionScrollReport {
    let report: @MainActor (_ offset: CGFloat, _ interacting: Bool) -> Void
    static let none = SectionScrollReport { _, _ in }
}

private struct SectionScrollReportKey: EnvironmentKey {
    static let defaultValue = SectionScrollReport.none
}

extension EnvironmentValues {
    var sectionScrollReport: SectionScrollReport {
        get { self[SectionScrollReportKey.self] }
        set { self[SectionScrollReportKey.self] = newValue }
    }
}

extension UI2Section {
    /// media-page D16: the section draws its own vertical scroll (Media's bottom-anchored, pinch-zoomed
    /// grid can't nest in the page scroll). Every other section keeps `SectionPageScroll`.
    var ownsScroll: Bool { self == .media }
}
```

In `HomeSectionLayout.body`, inside the `ZStack`, replace the `SectionPageScroll(…) { content }` expression and its three modifiers with a branch (the `navRow`, its offset and the status strip below it stay as they are):

```swift
                if model.section.ownsScroll {
                    // media-page D16: the section scrolls itself and reports to the same morph rule.
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .background(Token.layoutBackground)
                        .offset(y: hidesNav ? 0 : growth)
                        .id(model.section)
                        .environment(\.topNavInset, hidesNav ? 0 : growth)
                        .environment(\.sectionScrollReport, SectionScrollReport { [hidesNav] offset, interacting in
                            guard !hidesNav,
                                  let to = SectionScrollMorph.target(expansion: model.expansion, interacting: interacting, offset: offset)
                            else { return }
                            TopNavHost.morph($model, to: to, duration: SectionScrollMorph.triggerDuration)
                        })
                        .padding(.top, hidesNav ? 0 : Self.collapsedFootprint)
                } else {
                    SectionPageScroll(model: $model, growth: growth, morphs: !hidesNav) { content }
                        .id(model.section)
                        .environment(\.topNavInset, hidesNav ? 0 : growth)
                        .padding(.top, hidesNav ? 0 : Self.collapsedFootprint)
                }
```

In `SectionPageScroll`, delete `expandPull`, `collapseScroll` and `triggerDuration` and make `react` use the shared rule:

```swift
    private func react(to offset: CGFloat) {
        guard morphs,
              let to = SectionScrollMorph.target(expansion: model.expansion, interacting: phase == .interacting, offset: offset)
        else { return }
        TopNavHost.morph($model, to: to, duration: SectionScrollMorph.triggerDuration)
    }
```

If `model.expansion` is a `CGFloat` rather than a `Double`, convert at the call (`Double(model.expansion)`) — `TopNavHost.morph` takes a `Double`. Register the two new files; `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; run `/transition-review` on the diff and fix any FAIL.

- [ ] **Step 5: Commit** — `feat(media-page): a section can own its scroll; one TopNav morph rule`

### Task 10: Tile image budget + ImageViewer seeded flight
App: iphone
Phase: 5
Recipe: /ios-error-surface · /transition-review (ImageViewer open flight) · SPEC D12, D15, D18, F10, F11

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Media/MediaTileImages.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Shared/ImageViewer.swift:9-14` (new `placeholder`), `:80-95` (`open`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/CoverViewerOverlay.swift:14-44` (pass `placeholder` through)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj`, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MediaTileImagesTests.swift`, `iphone/MakeReadyCaptureTests/ImageViewerSeedTests.swift`

**Interfaces:**
- Consumes: `UI2ImageLoader.Fetch` (`@Sendable (URL, CGFloat?) async throws -> UIImage`), `UI2ImageLoader.live`, `UI2ImageLoader.isCancellation`.
- Produces: `@MainActor @Observable final class MediaTileImages { init(countLimit: Int = 3000, maxConcurrent: Int = 6, fetch: @escaping UI2ImageLoader.Fetch = UI2ImageLoader.live); private(set) var generation: Int; func image(for url: URL) -> UIImage?; func hasFailed(_ url: URL) -> Bool; func load(_ requests: [MediaTileImages.Request]) async; func clear() }` with `struct Request: Hashable { let url: URL; let maxPixelSize: CGFloat }`; `ImageViewer(… placeholder: UIImage? = nil)`; `ImageViewer.openingImage(cached: UIImage?, placeholder: UIImage?) -> UIImage?`; `coverViewerPresentation(url:sourceFrame:accessibilityLabel:placeholder:onClose:)` with `placeholder: UIImage? = nil`.

- [ ] **Step 1: Write the failing tests** — `MediaTileImagesTests.swift`:

```swift
import XCTest
import UIKit
@testable import MakeReady

/// media-page D18: only the requested range loads, concurrently (bounded), into a bounded cache.
@MainActor
final class MediaTileImagesTests: XCTestCase {
    private actor Counter {
        var current = 0, peak = 0, calls: [URL] = []
        func enter(_ url: URL) { current += 1; peak = max(peak, current); calls.append(url) }
        func leave() { current -= 1 }
    }

    private func pixel() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
    }
    private func url(_ n: Int) -> URL { URL(string: "https://img/\(n).jpeg")! }
    private func requests(_ range: Range<Int>) -> [MediaTileImages.Request] { range.map { .init(url: url($0), maxPixelSize: 132) } }

    func testLoadsEachRequestOnceWithBoundedConcurrency() async {
        let counter = Counter()
        let image = pixel()
        let tiles = MediaTileImages(countLimit: 100, maxConcurrent: 3, fetch: { url, _ in
            await counter.enter(url)
            try await Task.sleep(nanoseconds: 5_000_000)
            await counter.leave()
            return image
        })
        await tiles.load(requests(0..<10) + requests(0..<10))
        let calls = await counter.calls
        let peak = await counter.peak
        XCTAssertEqual(Set(calls).count, 10)
        XCTAssertEqual(calls.count, 10)
        XCTAssertLessThanOrEqual(peak, 3)
        XCTAssertNotNil(tiles.image(for: url(9)))
        XCTAssertGreaterThan(tiles.generation, 0)
    }

    func testEvictsTheOldestBeyondTheLimitButNotTheLatestRequest() async {
        let image = pixel()
        let tiles = MediaTileImages(countLimit: 5, maxConcurrent: 2, fetch: { _, _ in image })
        await tiles.load(requests(0..<5))
        await tiles.load(requests(5..<8))
        XCTAssertNil(tiles.image(for: url(0)))
        XCTAssertNotNil(tiles.image(for: url(7)))
        XCTAssertNotNil(tiles.image(for: url(5)))
    }

    func testAFailureIsRememberedAndNotRetriedInTheSameLoad() async {
        let tiles = MediaTileImages(countLimit: 10, maxConcurrent: 2, fetch: { _, _ in throw URLError(.badServerResponse) })
        await tiles.load(requests(0..<1))
        XCTAssertTrue(tiles.hasFailed(url(0)))
        XCTAssertNil(tiles.image(for: url(0)))
    }
}
```

and `ImageViewerSeedTests.swift`:

```swift
import XCTest
import UIKit
@testable import MakeReady

/// media-page D12: the open flight starts from the tile's loaded image, not a spinner.
final class ImageViewerSeedTests: XCTestCase {
    func testTheFullImageWinsOverThePlaceholder() {
        let full = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        let tile = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
        XCTAssertTrue(ImageViewer.openingImage(cached: full, placeholder: tile) === full)
        XCTAssertTrue(ImageViewer.openingImage(cached: nil, placeholder: tile) === tile)
        XCTAssertNil(ImageViewer.openingImage(cached: nil, placeholder: nil))
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile (`cannot find 'MediaTileImages'`, `has no member 'openingImage'`).

- [ ] **Step 3: Implement** `iphone/MakeReady/UI2/Containers/Media/MediaTileImages.swift`:

```swift
import Observation
import UIKit

/// media-page D18: the Media grid's tile images. Only what MediaBrowser reports as visible + prefetch is
/// requested; each is fetched off the main thread through the app's ImageCache, downsampled to the tile's
/// pixel size, at most `maxConcurrent` at once, into a cache of at most `countLimit` images (the oldest
/// leave first, never one from the latest request). `generation` bumps as images land, so the grid redraws.
/// Not `Ui2ImageCache`, which is unbounded (F11).
@MainActor
@Observable
final class MediaTileImages {
    struct Request: Hashable {
        let url: URL
        let maxPixelSize: CGFloat
    }

    private(set) var generation = 0
    @ObservationIgnored private var images: [URL: UIImage] = [:]
    @ObservationIgnored private var order: [URL] = []
    @ObservationIgnored private var inFlight: Set<URL> = []
    @ObservationIgnored private var failed: Set<URL> = []
    @ObservationIgnored private let countLimit: Int
    @ObservationIgnored private let maxConcurrent: Int
    @ObservationIgnored private let fetch: UI2ImageLoader.Fetch

    init(countLimit: Int = 3000, maxConcurrent: Int = 6, fetch: @escaping UI2ImageLoader.Fetch = UI2ImageLoader.live) {
        self.countLimit = countLimit
        self.maxConcurrent = maxConcurrent
        self.fetch = fetch
    }

    func image(for url: URL) -> UIImage? { images[url] }

    func hasFailed(_ url: URL) -> Bool { failed.contains(url) }

    func clear() {
        images = [:]
        order = []
        failed = []
        generation += 1
    }

    func load(_ requests: [Request]) async {
        var seen = Set<URL>()
        let wanted = requests.filter { seen.insert($0.url).inserted }
        let protected = Set(wanted.map(\.url))
        let todo = wanted.filter { images[$0.url] == nil && !inFlight.contains($0.url) && !failed.contains($0.url) }
        guard !todo.isEmpty else { return }
        todo.forEach { inFlight.insert($0.url) }
        defer { todo.forEach { inFlight.remove($0.url) } }
        let fetch = self.fetch
        await withTaskGroup(of: (URL, UIImage?).self) { group in
            var next = 0
            func addNext() {
                guard next < todo.count else { return }
                let request = todo[next]
                next += 1
                group.addTask {
                    do { return (request.url, try await fetch(request.url, request.maxPixelSize)) } catch { return (request.url, nil) }
                }
            }
            for _ in 0..<min(maxConcurrent, todo.count) { addNext() }
            while let (url, image) = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                if let image { store(image, for: url, protecting: protected) } else { failed.insert(url) }
                addNext()
            }
        }
    }

    private func store(_ image: UIImage, for url: URL, protecting protected: Set<URL>) {
        images[url] = image
        order.append(url)
        var index = 0
        while images.count > countLimit, index < order.count {
            let candidate = order[index]
            if protected.contains(candidate) { index += 1; continue }
            images[candidate] = nil
            order.remove(at: index)
        }
        generation += 1
    }
}
```

In `ImageViewer`: add after `onClose` `var placeholder: UIImage? = nil` (doc: "media-page D12: the tile's loaded image; the open flight starts from it while `url` loads"), add

```swift
    /// media-page D12: what the open flight starts from — the full image when cached, else the tile's.
    static func openingImage(cached: UIImage?, placeholder: UIImage?) -> UIImage? { cached ?? placeholder }
```

and make `open` fly at once from the placeholder, then swap to the full image:

```swift
    @MainActor
    private func open(viewport: CGRect, origin: CGPoint) async {
        guard let u = URL(string: url) else { return }
        if Ui2ImageCache.shared.image(for: u) == nil, placeholder == nil {
            _ = await UI2ImageLoader.seed([url], context: "ImageViewer")
        }
        guard let first = Self.openingImage(cached: Ui2ImageCache.shared.image(for: u), placeholder: placeholder) else { return }
        image = first
        let target = ImageViewerMath.fittedFrame(imageSize: first.size, in: viewport)
        flightFrame = ImageViewerMath.startFrame(source: sourceFrame?.offsetBy(dx: -origin.x, dy: -origin.y), fitted: target)
        withAnimation(ImageViewerMath.openSpring) {
            flightFrame = target
            backdrop = 1
        } completion: {
            zoomLive = true
        }
        guard Ui2ImageCache.shared.image(for: u) == nil else { return }
        _ = await UI2ImageLoader.seed([url], context: "ImageViewer")
        if !closing, let full = Ui2ImageCache.shared.image(for: u) { image = full }
    }
```

In `CoverViewerPresentation` add `let placeholder: UIImage?`, pass it to `ImageViewer(url:sourceFrame:accessibilityLabel:onClose:placeholder:)`, and give `coverViewerPresentation` a `placeholder: UIImage? = nil` parameter (before `onClose`) so existing callers are unchanged. Register the files; `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test` → PASS (including the existing `CoverViewerOverlayTests`); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `/transition-review` on the ImageViewer diff → no FAIL.

- [ ] **Step 5: Commit** — `feat(media-page): bounded tile image loading; ImageViewer opens from the tile's image`

### Task 11: `MediaHomeContainer` — Home's Media section
App: iphone
Phase: 5
Recipe: /present-overlay (the viewer goes through the shell's overlay host, never `.sheet`/`.fullScreenCover`) · /ios-error-surface · iphone/.claude/CLAUDE.md §State Management · SPEC D1, D2, D9, D12, D13, D16–D18, §iphone Shell/Container · build-time risk R4: a cold launch's first paint shows the loading state until page 1 lands, or the persisted partial set bottom-anchored · build-time risk R2: D15's physical-device check can't run on the agent walk's simulator — the walk records it as **device check pending**; the owner checks it on a device after merge

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:215-224` (`sectionContent`: `case .media`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj`, then `ruby iphone/scripts/capture-targets.rb`
- Test: `iphone/MakeReadyCaptureTests/MediaHomeContainerTests.swift`

**Interfaces:**
- Consumes: `MediaActions.loadAllPhotos(pageSize:resumeCursor:) -> PhotoLoadOutcome`, `MediaActions(onUnauthorized:)`, `AppState.mediaPhotosLoadedOrgId`, `AppState.mediaLibraryNextCursor` (Task 6); `MediaHomeMapper` (Task 7); `MediaHomeScreen` + `MediaBrowser` exactly as Task 8 carried them — 🔴 **read `iphone/MakeReadyUI/Screens/Media/MediaHomeScreen.swift` and `MediaBrowser`'s file first** and bind to the names they actually declare; the code below uses the names Task 8 requested, and every one that differs is renamed to d2m's, never the reverse (never edit under `iphone/MakeReadyUI/`); `EnvironmentValues.sectionScrollReport` (Task 9); `MediaTileImages`, `coverViewerPresentation(…placeholder:…)` (Task 10).
- Produces: `struct MediaHomeContainer: View`; pure statics `MediaHomeContainer.shouldLoad(loadedOrgId: String?, orgId: String?) -> Bool`, `phase(output: MediaHomeMapper.Output, isLoading: Bool, failed: Bool) -> MediaHomeScreen.State.Phase`, `imageRequests(tiles: [MediaHomeMapper.Tile], range: Range<Int>, fiveColumns: Bool, tileSide: CGFloat, scale: CGFloat, failed: (URL) -> Bool) -> [MediaTileImages.Request]`, `tileURL(_ tile: MediaHomeMapper.Tile, fiveColumns: Bool, failed: (URL) -> Bool) -> URL?`.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/MediaHomeContainerTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// media-page D10, D13, D17, D18, R4: the container's decisions, pure.
@MainActor
final class MediaHomeContainerTests: XCTestCase {
    private func tile(_ id: String, medium: String? = "https://img/\("x")-md.jpeg") -> MediaHomeMapper.Tile {
        MediaHomeMapper.Tile(id: id, mediumURL: medium.map { URL(string: $0.replacingOccurrences(of: "x", with: id))! },
                             thumbURL: URL(string: "https://img/\(id)-thumb.jpeg"), fullURL: "https://img/\(id).jpeg",
                             date: Date(timeIntervalSince1970: 0), title: id)
    }
    private func output(_ tiles: [MediaHomeMapper.Tile], empty: Bool = false, noResults: Bool = false) -> MediaHomeMapper.Output {
        .init(tiles: tiles, tagOptions: [], leaderOptions: [], dateRange: nil, isEmptyLibrary: empty, isNoResults: noResults)
    }

    func testLoadsOncePerSessionPerOrg() {
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: "o1"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o1"))
        XCTAssertTrue(MediaHomeContainer.shouldLoad(loadedOrgId: "o1", orgId: "o2"))
        XCTAssertFalse(MediaHomeContainer.shouldLoad(loadedOrgId: nil, orgId: nil))
    }

    func testPhase() {
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], empty: true), isLoading: true, failed: false), .loading)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], empty: true), isLoading: false, failed: false), .empty)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([], noResults: true), isLoading: false, failed: false), .noResults)
        XCTAssertEqual(MediaHomeContainer.phase(output: output([tile("a")]), isLoading: true, failed: false), .loaded)   // R4: a partial set shows
        XCTAssertEqual(MediaHomeContainer.phase(output: output([tile("a")]), isLoading: false, failed: true), .failed)
    }

    func testFiveColumnsUsesMediumThenThumbOnFailureDenserUsesThumb() {
        let t = tile("a")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: true, failed: { _ in false })?.absoluteString, "https://img/a-md.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: true, failed: { $0.absoluteString.hasSuffix("-md.jpeg") })?.absoluteString,
                       "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(t, fiveColumns: false, failed: { _ in false })?.absoluteString, "https://img/a-thumb.jpeg")
        XCTAssertEqual(MediaHomeContainer.tileURL(tile("b", medium: nil), fiveColumns: true, failed: { _ in false })?.absoluteString,
                       "https://img/b-thumb.jpeg")
    }

    func testRequestsOnlyTheReportedRangeAtTilePixelSize() {
        let tiles = (0..<10).map { tile("t\($0)") }
        let requests = MediaHomeContainer.imageRequests(tiles: tiles, range: 3..<6, fiveColumns: false, tileSide: 44, scale: 3,
                                                        failed: { _ in false })
        XCTAssertEqual(requests.map(\.url.absoluteString), ["https://img/t3-thumb.jpeg", "https://img/t4-thumb.jpeg", "https://img/t5-thumb.jpeg"])
        XCTAssertEqual(requests.first?.maxPixelSize, 132)
        XCTAssertTrue(MediaHomeContainer.imageRequests(tiles: tiles, range: 8..<20, fiveColumns: false, tileSide: 44, scale: 3,
                                                       failed: { _ in false }).count == 2)
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile (`cannot find 'MediaHomeContainer'`).

- [ ] **Step 3: Implement** `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift` (pattern: `MembersHomeContainer` for Selection/`onUnauthorized`/`onDisappear` cancel; `EnrollmentsHomeContainer` for loading/failed):

```swift
import SwiftUI

/// media-page §iphone Container: Home's Media section. Shows what AppState.mediaLibrary already holds at
/// once and loads the whole photo library once per session per org (D17), in pages that fill the grid as
/// they land (D2). Search and chips run on the phone (MediaHomeMapper). The section owns its scroll (D16):
/// MediaBrowser reports it to the shell's TopNav. A tile opens ImageViewer over the shell (D12).
struct MediaHomeContainer: View {
    static let pageSize = 200

    @Environment(AuthManager.self) private var authManager
    @Environment(\.displayScale) private var displayScale
    @Environment(\.sectionScrollReport) private var scrollReport
    @State private var selection = MediaHomeMapper.Selection()
    @State private var loadTask: Task<Void, Never>?
    @State private var imageTask: Task<Void, Never>?
    @State private var isLoading = false
    @State private var failed = false
    @State private var tileImages = MediaTileImages()
    @State private var scrollToNewest = 0
    @State private var searchActive = false
    /// D12: the open item, and the tile list frozen while it is open (pages that land meanwhile apply on close).
    @State private var viewer: Viewer?
    @State private var frozenTiles: [MediaHomeMapper.Tile]?
    @State private var level: MediaBrowser.Level = .five

    private struct Viewer: Equatable {
        let id: String
        let url: String
        let frame: CGRect
        let title: String
        let placeholder: UIImage?
    }

    var body: some View {
        let app = AppState.shared
        let output = MediaHomeMapper.output(items: app.mediaLibrary.all, selection: selection, today: Date(), timeZone: .current)
        let tiles = frozenTiles ?? output.tiles
        MediaHomeScreen(
            state: .init(
                phase: Self.phase(output: output, isLoading: isLoading, failed: failed),
                query: selection.search,
                dateRange: output.dateRange,
                tagOptions: output.tagOptions, selectedTags: selection.tags,
                leaderOptions: output.leaderOptions.map { (id: $0.id, label: $0.label) }, selectedLeaders: selection.leaderIds,
                timeOptions: MediaHomeMapper.TimeWindow.allCases.map(\.label), selectedTime: selection.time.label
            ),
            items: tiles.map { MediaBrowser.Item(id: $0.id, date: $0.date, accessibilityLabel: $0.title) },
            image: { id in Self.loadedImage(id: id, tiles: tiles, level: level, cache: tileImages) },
            imageGeneration: tileImages.generation,
            hiddenItemID: viewer?.id,
            isFrozen: viewer != nil,
            scrollToNewestToken: scrollToNewest,
            onVisibleRangeChange: { range, newLevel in
                level = newLevel
                requestImages(tiles: tiles, range: range, level: newLevel)
            },
            onTap: { id, frame in open(id: id, frame: frame, tiles: tiles) },
            onScrollChange: { offset, interacting in scrollReport.report(offset, interacting) },
            onRefresh: { await load(resume: nil) },
            onSearch: { text in update { $0.search = text } },
            onSaveTags: { tags in update { $0.tags = tags } },
            onSaveLeaders: { ids in update { $0.leaderIds = ids } },
            onSaveTime: { label in update { $0.time = MediaHomeMapper.TimeWindow.allCases.first { $0.label == label } ?? .all } },
            onClearFilters: { update { $0 = .init() } },
            onRetry: { startLoad(resume: AppState.shared.mediaLibraryNextCursor) },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .coverViewerPresentation(url: viewer?.url, sourceFrame: viewer?.frame, accessibilityLabel: viewer?.title ?? "",
                                 placeholder: viewer?.placeholder, onClose: { viewer = nil; frozenTiles = nil })
        .task {
            await AppState.shared.loadInitialData()   // waits for the org (as MembersHomeContainer)
            if Self.shouldLoad(loadedOrgId: AppState.shared.mediaPhotosLoadedOrgId, orgId: AppState.shared.organizationId) {
                startLoad(resume: nil)
            }
        }
        .onDisappear {
            loadTask?.cancel()
            imageTask?.cancel()
        }
    }

    // MARK: - Decisions (pure, tested)

    static func shouldLoad(loadedOrgId: String?, orgId: String?) -> Bool {
        guard let orgId else { return false }
        return loadedOrgId != orgId
    }

    /// D13 + R4: loading only while nothing is shown yet; a failure with photos shown keeps them.
    static func phase(output: MediaHomeMapper.Output, isLoading: Bool, failed: Bool) -> MediaHomeScreen.State.Phase {
        if failed { return .failed }
        if output.isEmptyLibrary { return isLoading ? .loading : .empty }
        if output.isNoResults { return .noResults }
        return .loaded
    }

    /// D10: `-md` at 5 columns unless it failed or there is none; the thumb otherwise.
    static func tileURL(_ tile: MediaHomeMapper.Tile, fiveColumns: Bool, failed: (URL) -> Bool) -> URL? {
        if fiveColumns, let medium = tile.mediumURL, !failed(medium) { return medium }
        return tile.thumbURL
    }

    /// D18: the reported range only, at the tile's pixel size.
    static func imageRequests(tiles: [MediaHomeMapper.Tile], range: Range<Int>, fiveColumns: Bool, tileSide: CGFloat,
                              scale: CGFloat, failed: (URL) -> Bool) -> [MediaTileImages.Request] {
        let clamped = range.clamped(to: 0..<tiles.count)
        return clamped.compactMap { index in
            tileURL(tiles[index], fiveColumns: fiveColumns, failed: failed).map { .init(url: $0, maxPixelSize: tileSide * scale) }
        }
    }

    @MainActor
    static func loadedImage(id: String, tiles: [MediaHomeMapper.Tile], level: MediaBrowser.Level, cache: MediaTileImages) -> UIImage? {
        guard let tile = tiles.first(where: { $0.id == id }) else { return nil }
        let five = level == .five
        if let url = tileURL(tile, fiveColumns: five, failed: cache.hasFailed), let image = cache.image(for: url) { return image }
        return tile.thumbURL.flatMap(cache.image(for:))
    }

    // MARK: - Effects

    private var actions: MediaActions {
        MediaActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MediaHomeContainer.signOut", surface: false)
            }
        })
    }

    private func startLoad(resume: String?) {
        loadTask?.cancel()
        loadTask = Task { @MainActor in await load(resume: resume) }
    }

    @MainActor
    private func load(resume: String?) async {
        isLoading = true
        failed = false
        let outcome = await actions.loadAllPhotos(pageSize: Self.pageSize, resumeCursor: resume)
        isLoading = false
        failed = outcome == .failed
    }

    private func update(_ change: (inout MediaHomeMapper.Selection) -> Void) {
        var next = selection
        change(&next)
        selection = next
        scrollToNewest += 1   // D9: a search or chip change keeps the level and goes to the newest end
    }

    private func requestImages(tiles: [MediaHomeMapper.Tile], range: Range<Int>, level: MediaBrowser.Level) {
        let side = UIScreen.main.bounds.width / CGFloat(Self.columns(level))
        let requests = Self.imageRequests(tiles: tiles, range: range, fiveColumns: level == .five, tileSide: side,
                                          scale: displayScale, failed: tileImages.hasFailed)
        imageTask?.cancel()
        imageTask = Task { @MainActor in await tileImages.load(requests) }
    }

    static func columns(_ level: MediaBrowser.Level) -> Int {
        switch level {
        case .five: return 5
        case .eight: return 8
        case .fourteen: return 14
        case .thirty: return 30
        }
    }

    private func open(id: String, frame: CGRect, tiles: [MediaHomeMapper.Tile]) {
        guard viewer == nil, let tile = tiles.first(where: { $0.id == id }) else { return }
        frozenTiles = tiles
        viewer = Viewer(id: id, url: tile.fullURL, frame: frame, title: tile.title,
                        placeholder: Self.loadedImage(id: id, tiles: tiles, level: level, cache: tileImages))
    }
}
```

If MediaBrowser reports the column count rather than a `Level`, drop `columns(_:)` and use what it reports; if `MediaHomeScreen` takes the MediaBrowser inputs nested in a struct, build that struct from the same values. A C-036 menu is presented by the screen above the grid, so a tile can't be tapped while one is open (D12's "after the menu has dismissed" holds by construction) — say in the report if d2m's screen differs.

In `UI2Shell.sectionContent` add above `default:`:

```swift
        case .media: MediaHomeContainer()     // media-page D1
```

and change the `default:` comment to `// SPEC D10: Library…Invites are unwired`. Register the files; `ruby iphone/scripts/capture-targets.rb`.

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `/transition-review` on the diff → no FAIL.

- [ ] **Step 5: Commit** — `feat(media-page): Home's Media section — whole library in MediaBrowser, viewer from a tile`
