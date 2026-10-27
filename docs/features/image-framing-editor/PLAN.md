# image-framing-editor — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** turn the group cover's framing editor into one aspect-parameterised editor and give member avatars (1:1, round guide) set / re-frame / view on the iPhone, with the server storing the avatar's original + framing.

**Architecture:** server first — two nullable Member columns, the avatar upload extended (multipart `file|avatar`, `framing`, `original`) through a new `services/member-avatar.ts`, the four other `profilePicture` writers clearing them, the contract frozen at the end of phase 1. Then the iPhone: a pure rename/parameterise of the group cover editor (behaviour unchanged), the member state + a status-returning multipart call + `MemberActions.saveAvatar`, and finally the profile avatar tap, menu, picker, viewer and `EditMemberAvatarContainer` wired to the d2m-generalised `edit-cover` screen.

**Tech Stack:** server — Express, Prisma (schema YAML → Atlas), multer, sharp, zod, vitest. iphone — SwiftUI, @Observable AppState + Actions, XCTest (MakeReadyCaptureTests).

**Spec:** docs/features/image-framing-editor/SPEC.md (code map: .builder/image-framing-editor/audit-digest.md)

## Global Constraints


- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(image-framing-editor): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–4 | Member stores the avatar original + framing; the avatar upload takes them (D8, D14, D16); the other writers clear them (D11); the Google-only fixture member exists; the contract freezes | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | iphone | 5 | the group cover editor runs on shared, aspect-parameterised pieces with unchanged behaviour (D1) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 3 | iphone | 6 | `MemberDetail` carries the two fields, a status-returning multipart call exists, `MemberActions.saveAvatar` saves and patches AppState (D8, D12) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 7–8 | Edit photo wired to the generalised d2m screen for both images (D9, D12), then the profile avatar tap, menu, picker and viewer (D4, D10, D13) | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---
### Task 1: Member avatar columns — schema YAML, Atlas migration, Prisma client, GET payload
App: server
Phase: 1
Recipe: `/api` (server conventions) · SPEC §Schema & API changes SC1–SC2 + Data plan · §Contract row 2 · §server bullet 1

**Files:**
- Modify: `server/schema/schema.yaml:591-593` (Member, directly after the `profilePicture:` block)
- Generated (commit them): `server/atlas/migrations/<timestamp>.sql`, `server/atlas/migrations/atlas.sum`, `server/prisma/schema.prisma`
- Modify: `server/src/services/member.ts:1-4` (imports), `:46-50` (`ScopedMemberResult`), `:464-479` (`getScopedMember` return)
- Modify: `server/src/docs/openapi-definition.ts:237` (the `Member` schema — two properties after `profilePicture`)
- Test: `server/test/member-avatar-columns-migration.test.ts`, `server/src/routes/__tests__/members-avatar-payload.request.test.ts`

**Interfaces:**
- Consumes: `parseStoredFraming(value: unknown): CoverFraming | null` and `type CoverFraming` from `server/src/services/group-cover.ts:27-33` (shipped; `CoverFraming = { scale; rotation; offsetX; offsetY; flipped: boolean; quarterTurns: number }`)
- Produces:
  - Prisma `Member.profilePictureOriginalUrl: string | null`, `Member.profilePictureFraming: Prisma.JsonValue | null`; DB columns `members."profilePictureOriginalUrl" text NULL`, `members."profilePictureFraming" jsonb NULL`
  - `services/member.ts`: `export type ScopedMember = Omit<MemberWithOrganizations, 'profilePictureFraming'> & { profilePictureFraming: CoverFraming | null; isGroupLeader: boolean }`; `ScopedMemberResult.data?: ScopedMember`
  - `GET /api/members/:memberId` → `data.profilePictureOriginalUrl: string | null`, `data.profilePictureFraming: CoverFraming | null`

- [ ] **Step 1: Write the failing migration test** — `server/test/member-avatar-columns-migration.test.ts`

```ts
/**
 * image-framing-editor SC1–SC2: two nullable Member columns in ONE Atlas migration, no backfill
 * (every member reads null and uses D5's fallback).
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
    .filter((m) => m.sql.includes('"profilePictureOriginalUrl"'))
  expect(hits.map((h) => h.file)).toHaveLength(1)
  return hits[0]
}

describe('SC1–SC2 migration', () => {
  it('adds both columns as nullable to members', () => {
    const { sql } = findMigration()
    expect(sql).toContain('ALTER TABLE "members"')
    expect(sql).toContain('ADD COLUMN "profilePictureOriginalUrl" text NULL')
    expect(sql).toContain('ADD COLUMN "profilePictureFraming" jsonb NULL')
  })

  it('touches nothing else and backfills nothing', () => {
    const { sql } = findMigration()
    expect(sql).not.toMatch(/UPDATE\s+"members"/)
    expect(sql).not.toMatch(/DROP|ALTER COLUMN/)
  })

  it('is hashed into atlas.sum', () => {
    const { file } = findMigration()
    expect(readFileSync(join(MIGRATIONS, 'atlas.sum'), 'utf8')).toContain(`${file} h1:`)
  })

  it('generates both Prisma fields', () => {
    const fields = Object.keys(Prisma.MemberScalarFieldEnum)
    expect(fields).toContain('profilePictureOriginalUrl')
    expect(fields).toContain('profilePictureFraming')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run test/member-avatar-columns-migration.test.ts` → FAIL, `expected [] to have a length of 1`

- [ ] **Step 3: Add the two fields to the YAML** — in `server/schema/schema.yaml`, Member model, directly after the `profilePicture:` block (lines 591-593: `profilePicture:` / `type: string` / `nullable: true`). Keep descriptions free of apostrophes (they become SQL comments):

```yaml
      profilePictureOriginalUrl:
        type: text
        nullable: true
        description: "image-framing-editor SC1 (D5, D8): the full original avatar photo; null means Edit reopens profilePicture"
      profilePictureFraming:
        type: json
        nullable: true
        description: "image-framing-editor SC2 (D8): {scale, rotation, offsetX, offsetY, flipped, quarterTurns} the avatar was rendered with"
```

- [ ] **Step 4: Validate, generate, diff, apply** — `server/.env` is a plain file pointing at `localhost:5434/makeready_dev`, so the npm scripts work on the host. The shared postgres container must be up (`docker start makeready-postgres` if `docker ps` does not list it).

```bash
cd server && npm run schema:validate
cd server && npm run schema:generate
cd server && npm run schema:diff
cd server && npm run migrate:apply
cd server && npx prisma generate
```

Open the new `server/atlas/migrations/<timestamp>.sql` and confirm it holds only `ALTER TABLE "members" ADD COLUMN "profilePictureOriginalUrl" text NULL, ADD COLUMN "profilePictureFraming" jsonb NULL;` and the two `COMMENT ON COLUMN` lines. If Atlas emitted anything else, the YAML is out of sync with an earlier migration — STOP and report it; never hand-edit the migration.

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run test/member-avatar-columns-migration.test.ts` → PASS (4 tests)

- [ ] **Step 6: Write the failing GET payload request test** — `server/src/routes/__tests__/members-avatar-payload.request.test.ts`

```ts
/**
 * image-framing-editor §Contract row 2: GET /api/members/:memberId carries the avatar's original
 * URL and its framing, the framing read through parseStoredFraming (null when absent or bad).
 * The real getScopedMember runs; Prisma is mocked; the caller is the member's own session.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn() },
  memberOrganization: { findMany: vi.fn() },
  group: { count: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))

import membersRoutes from '../members.js'

function appAsSelf() {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: 'm1' } })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const row = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  firstName: 'James',
  userId: null,
  profilePicture: 'https://img.test/avatars/members/m1/1.webp',
  profilePictureOriginalUrl: null,
  profilePictureFraming: null,
  organizations: [],
  ...over,
})
const get = () => request(appAsSelf()).get('/api/members/m1')

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.memberOrganization.findMany.mockResolvedValue([])
})

describe('GET /api/members/:memberId — avatar original + framing (§Contract row 2)', () => {
  it('returns both as null for a member with no stored original', async () => {
    prismaMock.member.findUnique.mockResolvedValue(row())
    const res = await get()
    expect(res.status).toBe(200)
    expect(res.body.data).toMatchObject({ profilePictureOriginalUrl: null, profilePictureFraming: null })
  })

  it('returns the stored original and the parsed framing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(
      row({ profilePictureOriginalUrl: 'https://img.test/avatars/members/m1/1-original.jpeg', profilePictureFraming: FRAMING })
    )
    const res = await get()
    expect(res.body.data.profilePictureOriginalUrl).toBe('https://img.test/avatars/members/m1/1-original.jpeg')
    expect(res.body.data.profilePictureFraming).toEqual(FRAMING)
  })

  it('fills flipped / quarterTurns defaults on a stored framing that lacks them', async () => {
    prismaMock.member.findUnique.mockResolvedValue(
      row({ profilePictureFraming: { scale: 1.5, rotation: 0, offsetX: 0, offsetY: 0 } })
    )
    const res = await get()
    expect(res.body.data.profilePictureFraming).toEqual({
      scale: 1.5, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0,
    })
  })

  it.each([
    ['out of range', { ...FRAMING, scale: 99 }],
    ['an unknown key', { ...FRAMING, zoom: 2 }],
    ['not an object', 'junk'],
  ])('returns null for a stored framing that is %s', async (_label, stored) => {
    prismaMock.member.findUnique.mockResolvedValue(row({ profilePictureFraming: stored }))
    const res = await get()
    expect(res.status).toBe(200)
    expect(res.body.data.profilePictureFraming).toBeNull()
  })
})
```

- [ ] **Step 7: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/members-avatar-payload.request.test.ts` → FAIL: the defaults case returns the raw object, and the three malformed cases return the stored value instead of `null`

- [ ] **Step 8: Emit the framing through `parseStoredFraming`** — in `server/src/services/member.ts`:

  At the top (after line 4) add:

```ts
import { parseStoredFraming, type CoverFraming } from './group-cover.js'
```

  Replace `ScopedMemberResult` (lines 46-50) with:

```ts
/** GET /api/members/:id's payload — image-framing-editor SC2: the framing parsed (null when absent or bad). */
export type ScopedMember = Omit<MemberWithOrganizations, 'profilePictureFraming'> & {
  profilePictureFraming: CoverFraming | null
  isGroupLeader: boolean
}

export interface ScopedMemberResult {
  success: boolean
  data?: ScopedMember
  error?: string
}
```

  In `getScopedMember` replace the success return (line 478, `return { success: true, data: { ...member, organizations, isGroupLeader } }`) with:

```ts
    return {
      success: true,
      data: {
        ...member,
        // image-framing-editor §Contract row 2: the group-payload.ts:53 precedent.
        profilePictureFraming: parseStoredFraming(member.profilePictureFraming),
        organizations,
        isGroupLeader,
      },
    }
```

- [ ] **Step 9: OpenAPI** — in `server/src/docs/openapi-definition.ts`, `Member` schema, directly after the `profilePicture:` line (237) add:

```ts
          profilePictureOriginalUrl: { type: 'string', format: 'uri', nullable: true, description: 'image-framing-editor D8: the full original avatar photo; null means Edit opens profilePicture (D5)' },
          profilePictureFraming: {
            type: 'object',
            nullable: true,
            description: 'image-framing-editor D8: the framing the avatar was rendered with (the group cover shape)',
            properties: {
              scale: { type: 'number', minimum: 1, maximum: 8 },
              rotation: { type: 'number', minimum: -45, maximum: 45 },
              offsetX: { type: 'number', minimum: -1, maximum: 1 },
              offsetY: { type: 'number', minimum: -1, maximum: 1 },
              flipped: { type: 'boolean', default: false },
              quarterTurns: { type: 'integer', minimum: 0, maximum: 3, default: 0 },
            },
          },
```

- [ ] **Step 10: Run everything and watch it pass** — `cd server && npx tsc --noEmit && npx vitest run test/member-avatar-columns-migration.test.ts src/routes/__tests__/members-avatar-payload.request.test.ts src/routes/__tests__/members-scope.request.test.ts src/services/__tests__/member-scope.test.ts` → PASS, no type errors

- [ ] **Step 11: Commit** — `git add server/schema/schema.yaml server/atlas/migrations server/prisma/schema.prisma server/src/services/member.ts server/src/docs/openapi-definition.ts server/test/member-avatar-columns-migration.test.ts server/src/routes/__tests__/members-avatar-payload.request.test.ts` → `feat(image-framing-editor): Member.profilePictureOriginalUrl + profilePictureFraming, on GET /api/members/:id`

### Task 2: Avatar upload takes framing + original — `member-avatar.ts` service, thin route, JSON multer errors, visibility gate
App: server
Phase: 1
Recipe: `/api` · SPEC D8, D14, D16, F4 · §Contract row 1 · §server bullet 2 · §Testing (server)

**Files:**
- Create: `server/src/services/image-original.ts` (hoisted from `group-cover.ts` — the decode check, the original's re-encode, the best-effort original delete)
- Modify: `server/src/services/group-cover.ts:5-9` (imports), `:35-41` (moved out), `:67-75` (moved out), `:86` (error class name), `:101-107` (re-encode call), `:123-133` (delete call)
- Create: `server/src/services/member-avatar.ts`
- Modify: `server/src/routes/members.ts:1-4,42` (imports), `:48-61` (the `upload` multer → the avatar multer + JSON error mapping), after `:75` (`requireVisibleMember`), `:1429-1580` (the avatar route's `@openapi` block and handler)
- Test: `server/src/services/__tests__/member-avatar.test.ts`, `server/src/routes/__tests__/members-avatar.request.test.ts`

**Interfaces:**
- Consumes: Task 1's Prisma fields; `coverFramingSchema`, `type CoverFraming` from `services/group-cover.ts`; `uploadMemberAvatar(memberId, buffer, mimeType): Promise<{ success: boolean; url?: string; error?: string }>`, `deleteMemberAvatar(url): Promise<void>`, `uploadToR2(key, buffer, contentType): Promise<string>`, `deleteFromR2(key)`, `extractKeyFromUrl(url): string | null` from `services/storage.ts`; `canViewMember(userId, memberId): Promise<boolean>` from `services/member-access.ts`
- Produces:
  - `services/image-original.ts`: `export const ORIGINAL_MAX_PX = 2400`; `export class ImageUploadError extends Error { readonly status: 400 }`; `export async function assertDecodable(buffer: Buffer, label: string): Promise<void>`; `export function encodeOriginal(buffer: Buffer): Promise<Buffer>`; `export async function deleteOriginalBestEffort(url: string, context: string): Promise<void>`
  - `services/group-cover.ts` keeps exporting `CoverUploadError` (now an alias of `ImageUploadError`) and `ORIGINAL_MAX_PX` — `groups.ts:7` and `group-cover.test.ts` unchanged
  - `services/member-avatar.ts`: `export class MemberAvatarNotFoundError extends Error { readonly status: 404 }`; `export interface SaveMemberAvatarInput { memberId: string; rendered: Buffer; framingJson?: string; original?: Buffer }`; `export interface SaveMemberAvatarResult { url: string; originalUrl: string | null; framing: CoverFraming | null }`; `export function parseFramingField(raw: string): CoverFraming`; `export async function saveMemberAvatar(input: SaveMemberAvatarInput): Promise<SaveMemberAvatarResult>`
  - `POST /api/members/:memberId/avatar` (multipart: `file` | `avatar`, `framing?` JSON string, `original?`) → `200 {success: true, data: {url, originalUrl, framing}}`; `400 {success: false, error}`; `401`/`403` (middleware); `404` (D16 gate or no member); `413 {success: false, error}` over 10MB per file; `500`

- [ ] **Step 1: Write the failing service test** — `server/src/services/__tests__/member-avatar.test.ts`

```ts
/**
 * image-framing-editor D8: the member avatar upload service. Prisma, R2 and sharp are mocked; the
 * service is real.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn(), update: vi.fn() } }))
const storage = vi.hoisted(() => ({
  uploadMemberAvatar: vi.fn(),
  deleteMemberAvatar: vi.fn(),
  uploadToR2: vi.fn(),
  uploadImageVariants: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
const sharpCalls = vi.hoisted(() => [] as Array<{ input: Buffer; ops: Array<[string, unknown[]]> }>)
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../storage.js', () => storage)
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const call = { input, ops: [] as Array<[string, unknown[]]> }
    sharpCalls.push(call)
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'webp', 'rotate']) {
      chain[op] = vi.fn((...args: unknown[]) => { call.ops.push([op, args]); return chain })
    }
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { ImageUploadError } from '../image-original.js'
import { MemberAvatarNotFoundError, parseFramingField, saveMemberAvatar } from '../member-avatar.js'

const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const OLD_AVATAR = 'https://img.test/avatars/members/m1/100.webp'
const NEW_AVATAR = 'https://img.test/avatars/members/m1/200.webp'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const ORIGINAL_URL = /^https:\/\/img\.test\/avatars\/members\/m1\/\d+-original\.jpeg$/
const buf = (s: string) => Buffer.from(s)
const stored = (profilePictureOriginalUrl: string | null = OLD_ORIGINAL, profilePicture: string | null = OLD_AVATAR) => ({
  profilePicture,
  profilePictureOriginalUrl,
})
const written = () => prismaMock.member.update.mock.calls[0][0]
const opsFor = (input: string) => sharpCalls.find((c) => c.input.toString() === input && c.ops.length > 0)!.ops

beforeEach(() => {
  vi.clearAllMocks()
  sharpCalls.length = 0
  prismaMock.member.findUnique.mockResolvedValue(stored())
  prismaMock.member.update.mockResolvedValue({})
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: NEW_AVATAR })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  storage.deleteMemberAvatar.mockResolvedValue(undefined)
})

describe('parseFramingField (D8)', () => {
  it('parses the JSON string and fills flipped / quarterTurns defaults', () => {
    expect(parseFramingField('{"scale":1,"rotation":0,"offsetX":0,"offsetY":0}')).toEqual({
      scale: 1, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0,
    })
    expect(parseFramingField(JSON.stringify(FRAMING))).toEqual(FRAMING)
  })

  it.each([
    ['not JSON', 'scale=2'],
    ['a JSON array', '[]'],
    ['an unknown key', JSON.stringify({ ...FRAMING, zoom: 2 })],
    ['a missing key', JSON.stringify({ scale: 1, rotation: 0, offsetX: 0 })],
    ['rotation beyond 45', JSON.stringify({ ...FRAMING, rotation: 46 })],
    ['quarterTurns 4', JSON.stringify({ ...FRAMING, quarterTurns: 4 })],
  ])('rejects %s with a 400', (_label, raw) => {
    const err = (() => { try { parseFramingField(raw) } catch (e) { return e } })()
    expect(err).toBeInstanceOf(ImageUploadError)
    expect((err as ImageUploadError).status).toBe(400)
  })
})

describe('saveMemberAvatar (D8)', () => {
  it('a new pick stores the avatar, the re-encoded original and the framing in ONE write', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(prismaMock.member.update).toHaveBeenCalledTimes(1)
    expect(written()).toEqual({
      where: { id: 'm1' },
      data: { profilePicture: NEW_AVATAR, profilePictureOriginalUrl: expect.stringMatching(ORIGINAL_URL), profilePictureFraming: FRAMING },
    })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: written().data.profilePictureOriginalUrl, framing: FRAMING })
  })

  it('keeps the 512px WebP re-encode for the rendered avatar (D7)', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })
    expect(opsFor('render')).toEqual([
      ['resize', [512, 512, { fit: 'cover', withoutEnlargement: true }]],
      ['webp', [{ quality: 85 }]],
    ])
    expect(storage.uploadMemberAvatar).toHaveBeenCalledWith('m1', buf('out:render'), 'image/webp')
  })

  it('re-encodes the original: EXIF rotate, ≤ 2400px inside, JPEG 90, under avatars/members/{id}/{ts}-original.jpeg', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(opsFor('orig')).toEqual([
      ['rotate', []],
      ['resize', [2400, 2400, { fit: 'inside', withoutEnlargement: true }]],
      ['jpeg', [{ quality: 90 }]],
    ])
    expect(storage.uploadToR2).toHaveBeenCalledTimes(1)
    expect(storage.uploadToR2.mock.calls[0][0]).toMatch(/^avatars\/members\/m1\/\d+-original\.jpeg$/)
    expect(storage.uploadToR2.mock.calls[0][1]).toEqual(buf('out:orig'))
    expect(storage.uploadToR2.mock.calls[0][2]).toBe('image/jpeg')
  })

  it('framing alone is a re-edit: profilePictureOriginalUrl stays out of the write, the stored one is returned', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING) })
    expect(written().data).toEqual({ profilePicture: NEW_AVATAR, profilePictureFraming: FRAMING })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: OLD_ORIGINAL, framing: FRAMING })
    expect(storage.uploadToR2).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('framing alone with no stored original is a 400 and nothing is uploaded', async () => {
    prismaMock.member.findUnique.mockResolvedValue(stored(null))
    await expect(
      saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING) })
    ).rejects.toMatchObject({ status: 400 })
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('no framing (the web, 1.0-era callers) clears the original and the framing and deletes the old original', async () => {
    const r = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })
    expect(written().data).toEqual({ profilePicture: NEW_AVATAR, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull })
    expect(r).toEqual({ url: NEW_AVATAR, originalUrl: null, framing: null })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
  })

  it('a new original replaces the old one, deleted after the write; the old avatar is deleted too', async () => {
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    const writeOrder = prismaMock.member.update.mock.invocationCallOrder[0]
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(writeOrder)
    expect(storage.deleteMemberAvatar).toHaveBeenCalledWith(OLD_AVATAR)
    expect(storage.deleteMemberAvatar.mock.invocationCallOrder[0]).toBeGreaterThan(writeOrder)
  })

  it('a member with no avatar yet deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(stored(null, null))
    await saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    expect(storage.deleteMemberAvatar).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed old-original delete is logged, never thrown', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })).resolves.toMatchObject({ url: NEW_AVATAR })
  })

  it('an original without framing is a 400 before anything is read or uploaded', async () => {
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), original: buf('orig') })).rejects.toMatchObject({ status: 400 })
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
  })

  it('a bad framing string is a 400 and nothing is uploaded', async () => {
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: '{nope' })).rejects.toBeInstanceOf(ImageUploadError)
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
  })

  it.each([
    ['the rendered avatar', { rendered: buf('bad') }],
    ['the original', { rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('bad') }],
  ])('an undecodable %s is a 400 and nothing is uploaded', async (_l, body) => {
    const err = await saveMemberAvatar({ memberId: 'm1', ...body }).catch((e) => e)
    expect(err).toBeInstanceOf(ImageUploadError)
    expect(err.status).toBe(400)
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a missing member is a 404', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    const err = await saveMemberAvatar({ memberId: 'm1', rendered: buf('render') }).catch((e) => e)
    expect(err).toBeInstanceOf(MemberAvatarNotFoundError)
    expect(err.status).toBe(404)
  })

  it('an R2 failure on the original propagates and leaves the row unchanged', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    await expect(
      saveMemberAvatar({ memberId: 'm1', rendered: buf('render'), framingJson: JSON.stringify(FRAMING), original: buf('orig') })
    ).rejects.toThrow('r2 down')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a failed avatar upload propagates and leaves the row unchanged', async () => {
    storage.uploadMemberAvatar.mockResolvedValue({ success: false, error: 'Internal error uploading avatar' })
    await expect(saveMemberAvatar({ memberId: 'm1', rendered: buf('render') })).rejects.toThrow('Internal error uploading avatar')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/member-avatar.test.ts` → FAIL, `Failed to resolve import "../image-original.js"`

- [ ] **Step 3: Hoist the shared pieces into `server/src/services/image-original.ts`**

```ts
/**
 * image-framing-editor D8 (hoisted from group-cover-image D10/D19): what every framed image's
 * upload shares — the decode check, the original's re-encode and the best-effort delete of a
 * replaced original. The group cover (group-cover.ts) and the member avatar (member-avatar.ts) use it.
 */
import sharp from 'sharp'
import { deleteFromR2, extractKeyFromUrl } from './storage.js'

/** The original's longest side, re-enforced server-side. */
export const ORIGINAL_MAX_PX = 2400

/** A client error the route maps to its status (a bad image or body is a 400, not a 500). */
export class ImageUploadError extends Error {
  readonly status = 400 as const
}

/** An image failing sharp's metadata read is a 400. */
export async function assertDecodable(buffer: Buffer, label: string): Promise<void> {
  try {
    const meta = await sharp(buffer).metadata()
    if (!meta.format) throw new Error('no format')
  } catch {
    throw new ImageUploadError(`The ${label} could not be decoded as an image`)
  }
}

/** The stored original: EXIF orientation applied, longest side ≤ 2400px, JPEG 90, metadata stripped. */
export function encodeOriginal(buffer: Buffer): Promise<Buffer> {
  return sharp(buffer)
    .rotate()
    .resize(ORIGINAL_MAX_PX, ORIGINAL_MAX_PX, { fit: 'inside', withoutEnlargement: true })
    .jpeg({ quality: 90 })
    .toBuffer()
}

/** Deletes a replaced or cleared original after the write; a failure is logged, never thrown. */
export async function deleteOriginalBestEffort(url: string, context: string): Promise<void> {
  const key = extractKeyFromUrl(url)
  if (!key) return
  try {
    await deleteFromR2(key)
  } catch (error) {
    console.warn(`${context}: could not delete the old original ${key}:`, error)
  }
}
```

- [ ] **Step 4: Point `group-cover.ts` at the hoisted pieces** — in `server/src/services/group-cover.ts`:
  - Imports (lines 5-9) become:

```ts
import { z } from 'zod'
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { uploadImageVariants, uploadToR2 } from './storage.js'
import { ImageUploadError, assertDecodable, deleteOriginalBestEffort, encodeOriginal } from './image-original.js'

/** Kept under their shipped names — routes/groups.ts and the group-cover tests import them from here. */
export { ImageUploadError as CoverUploadError, ORIGINAL_MAX_PX } from './image-original.js'
```

  - Delete lines 35-41 (`ORIGINAL_MAX_PX` and `class CoverUploadError`) and lines 67-75 (`assertDecodable`).
  - Line 86: `throw new CoverUploadError('originalData requires framing')` → `throw new ImageUploadError('originalData requires framing')`.
  - In the `Promise.all` (lines 101-107) replace the `original ? sharp(original).rotate()…toBuffer() : Promise.resolve(null)` element with `original ? encodeOriginal(original) : Promise.resolve(null),`.
  - Replace the delete block (lines 123-133) with:

```ts
  const previous = group.coverOriginalUrl
  if (previous && previous !== coverOriginalUrl) await deleteOriginalBestEffort(previous, 'saveGroupCover')
```

  Then `cd server && npx vitest run src/services/__tests__/group-cover.test.ts src/routes/__tests__/groups-cover-image.request.test.ts` → PASS (behaviour unchanged).

- [ ] **Step 5: Write `server/src/services/member-avatar.ts`**

```ts
/**
 * image-framing-editor D8: the member avatar upload — the rendered avatar (re-encoded to the 512px
 * WebP every reader expects), its framing and the full original, written in ONE member update.
 * framing + original: a new pick, both stored. framing alone: a re-edit, the stored original kept
 * (400 when there is none). Neither: the web / 1.0-era path, original and framing cleared. Any R2
 * failure rejects before the write (orphans accepted); the old avatar and a replaced or cleared
 * original are deleted after it, best-effort.
 */
import sharp from 'sharp'
import { prisma } from '../lib/prisma.js'
import { Prisma } from '../generated/prisma/index.js'
import { coverFramingSchema, type CoverFraming } from './group-cover.js'
import { ImageUploadError, assertDecodable, deleteOriginalBestEffort, encodeOriginal } from './image-original.js'
import { deleteMemberAvatar, uploadMemberAvatar, uploadToR2 } from './storage.js'

/** The route answers 404 (the member vanished between the auth check and the upload). */
export class MemberAvatarNotFoundError extends Error {
  readonly status = 404 as const
}

export interface SaveMemberAvatarInput {
  memberId: string
  /** D8/D14: the rendered avatar — multipart `file`, else `avatar`. */
  rendered: Buffer
  /** D8: the raw multipart `framing` field, a JSON string. */
  framingJson?: string
  /** D8: the full original photo (multipart `original`); requires framing. */
  original?: Buffer
}

export interface SaveMemberAvatarResult {
  url: string
  originalUrl: string | null
  framing: CoverFraming | null
}

/** D8: `framing` is JSON.parse'd, then validated by the group cover's strict schema. */
export function parseFramingField(raw: string): CoverFraming {
  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch {
    throw new ImageUploadError('framing must be a JSON object')
  }
  const parsed = coverFramingSchema.safeParse(value)
  if (!parsed.success) {
    throw new ImageUploadError(`Invalid framing: ${parsed.error.errors[0]?.message ?? 'unexpected shape'}`)
  }
  return parsed.data
}

export async function saveMemberAvatar(input: SaveMemberAvatarInput): Promise<SaveMemberAvatarResult> {
  const { memberId, rendered, original } = input
  if (original && input.framingJson === undefined) {
    throw new ImageUploadError('original requires framing')
  }
  const framing = input.framingJson !== undefined ? parseFramingField(input.framingJson) : null

  const member = await prisma.member.findUnique({
    where: { id: memberId },
    select: { profilePicture: true, profilePictureOriginalUrl: true },
  })
  if (!member) throw new MemberAvatarNotFoundError('Member not found')
  if (framing && !original && !member.profilePictureOriginalUrl) {
    throw new ImageUploadError('No stored original to re-frame; send the original with the framing')
  }

  await assertDecodable(rendered, 'avatar image')
  if (original) await assertDecodable(original, 'original image')

  const [avatarWebp, originalJpeg] = await Promise.all([
    sharp(rendered).resize(512, 512, { fit: 'cover', withoutEnlargement: true }).webp({ quality: 85 }).toBuffer(),
    original ? encodeOriginal(original) : Promise.resolve(null),
  ])

  const timestamp = Date.now()
  const [avatar, uploadedOriginalUrl] = await Promise.all([
    uploadMemberAvatar(memberId, avatarWebp, 'image/webp'),
    originalJpeg
      ? uploadToR2(`avatars/members/${memberId}/${timestamp}-original.jpeg`, originalJpeg, 'image/jpeg')
      : Promise.resolve(null),
  ])
  if (!avatar.success || !avatar.url) throw new Error(avatar.error ?? 'Failed to upload avatar')

  const reEdit = framing !== null && uploadedOriginalUrl === null
  const originalUrl = framing === null ? null : (uploadedOriginalUrl ?? member.profilePictureOriginalUrl)

  await prisma.member.update({
    where: { id: memberId },
    data: {
      profilePicture: avatar.url,
      // D8: a re-edit leaves profilePictureOriginalUrl out of the write.
      ...(reEdit ? {} : { profilePictureOriginalUrl: originalUrl }),
      profilePictureFraming: framing ?? Prisma.DbNull,
    },
  })

  if (member.profilePicture) await deleteMemberAvatar(member.profilePicture)
  const previous = member.profilePictureOriginalUrl
  if (previous && previous !== originalUrl) await deleteOriginalBestEffort(previous, 'saveMemberAvatar')

  return { url: avatar.url, originalUrl, framing }
}
```

- [ ] **Step 6: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/member-avatar.test.ts src/services/__tests__/group-cover.test.ts` → PASS

- [ ] **Step 7: Write the failing request test** — `server/src/routes/__tests__/members-avatar.request.test.ts`

```ts
/**
 * image-framing-editor D8/D14/D16 + F4: POST /api/members/:memberId/avatar over HTTP — the real
 * requireMemberOrOrgOwner, the real D16 gate, the real multer instance and the real member-avatar
 * service. Prisma, R2, sharp, the permission lookups and canViewMember are mocked.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn(), update: vi.fn() } }))
const storage = vi.hoisted(() => ({
  uploadMemberAvatar: vi.fn(),
  deleteMemberAvatar: vi.fn(),
  uploadToR2: vi.fn(),
  uploadImageVariants: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => storage)
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  isSuperAdmin: vi.fn(),
  getManageableOrgIds: vi.fn(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))
vi.mock('sharp', () => ({
  default: vi.fn((input: Buffer) => {
    const chain: Record<string, unknown> = {}
    for (const op of ['resize', 'jpeg', 'webp', 'rotate']) chain[op] = vi.fn(() => chain)
    chain.toBuffer = vi.fn().mockResolvedValue(Buffer.from(`out:${input.toString()}`))
    chain.metadata = vi.fn(() =>
      input.toString() === 'bad' ? Promise.reject(new Error('unsupported image format')) : Promise.resolve({ format: 'jpeg', width: 10, height: 10 })
    )
    return chain
  }),
}))

import { getManageableOrgIds, isSuperAdmin } from '../../services/permission.js'
import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

type Who = { userId?: string; memberId?: string }
function appAs(who: Who) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const SELF: Who = { memberId: 'm1' }
const LEADER: Who = { userId: 'gl' }
const STRANGER: Who = { userId: 'other' }
const FRAMING = { scale: 2, rotation: 10, offsetX: 0.1, offsetY: -0.2, flipped: true, quarterTurns: 1 }
const OLD_AVATAR = 'https://img.test/avatars/members/m1/100.webp'
const NEW_AVATAR = 'https://img.test/avatars/members/m1/200.webp'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const JPEG = { filename: 'avatar.jpg', contentType: 'image/jpeg' }
const member = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  profilePicture: OLD_AVATAR,
  profilePictureOriginalUrl: OLD_ORIGINAL,
  organizations: [{ organizationId: 'o1', organization: { ownerId: 'owner-1' } }],
  ...over,
})
const post = (who: Who = SELF) => request(appAs(who)).post('/api/members/m1/avatar')
const written = () => prismaMock.member.update.mock.calls[0][0].data

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue(member())
  prismaMock.member.update.mockResolvedValue({})
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: NEW_AVATAR })
  storage.uploadToR2.mockImplementation(async (key: string) => `https://img.test/${key}`)
  storage.deleteFromR2.mockResolvedValue(undefined)
  storage.deleteMemberAvatar.mockResolvedValue(undefined)
  vi.mocked(isSuperAdmin).mockResolvedValue(false)
  vi.mocked(getManageableOrgIds).mockResolvedValue(['o1'])
  vi.mocked(canViewMember).mockResolvedValue(true)
})

describe('POST /api/members/:memberId/avatar — bodies (D8, D14)', () => {
  it('file + framing + original: stores both and answers {success, data: {url, originalUrl, framing}}', async () => {
    const res = await post()
      .attach('file', Buffer.from('render'), JPEG)
      .field('framing', JSON.stringify(FRAMING))
      .attach('original', Buffer.from('orig'), { filename: 'original.jpg', contentType: 'image/jpeg' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      data: { url: NEW_AVATAR, originalUrl: expect.stringMatching(/^https:\/\/img\.test\/avatars\/members\/m1\/\d+-original\.jpeg$/), framing: FRAMING },
    })
    expect(written()).toMatchObject({ profilePicture: NEW_AVATAR, profilePictureFraming: FRAMING })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteMemberAvatar).toHaveBeenCalledWith(OLD_AVATAR)
  })

  it('framing alone keeps the stored original (a re-edit)', async () => {
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING))
    expect(res.status).toBe(200)
    expect(res.body.data).toEqual({ url: NEW_AVATAR, originalUrl: OLD_ORIGINAL, framing: FRAMING })
    expect(written()).not.toHaveProperty('profilePictureOriginalUrl')
    expect(storage.uploadToR2).not.toHaveBeenCalled()
  })

  it('file alone (the web path) clears the original and the framing; data.url is kept', async () => {
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: { url: NEW_AVATAR, originalUrl: null, framing: null } })
    expect(written()).toEqual({ profilePicture: NEW_AVATAR, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull })
  })

  it('D14: the web field name `avatar` uploads the same way', async () => {
    const res = await post().attach('avatar', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(res.body.data.url).toBe(NEW_AVATAR)
    expect(storage.uploadMemberAvatar).toHaveBeenCalledWith('m1', Buffer.from('out:render'), 'image/webp')
  })

  it('a failed old-original delete still answers 200', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
  })
})

describe('400s — nothing written', () => {
  it.each([
    ['no file', () => post().field('framing', JSON.stringify(FRAMING))],
    ['an original without framing', () => post().attach('file', Buffer.from('r'), JPEG).attach('original', Buffer.from('o'), JPEG)],
    ['framing that is not JSON', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', 'scale=2')],
    ['framing with an unknown key', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify({ ...FRAMING, zoom: 2 }))],
    ['framing out of range', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify({ ...FRAMING, scale: 9 }))],
    ['framing sent twice', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).field('framing', JSON.stringify(FRAMING))],
    ['an unexpected text field', () => post().attach('file', Buffer.from('r'), JPEG).field('caption', 'hi')],
    ['an unexpected file field', () => post().attach('photo', Buffer.from('r'), JPEG)],
    ['a second file part', () => post().attach('file', Buffer.from('r'), JPEG).attach('file', Buffer.from('r2'), JPEG)],
    ['a non-image file type', () => post().attach('file', Buffer.from('r'), { filename: 'a.pdf', contentType: 'application/pdf' })],
    ['an undecodable avatar', () => post().attach('file', Buffer.from('bad'), JPEG)],
    ['an undecodable original', () => post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', Buffer.from('bad'), JPEG)],
  ])('%s', async (_label, send) => {
    const res = await send()
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(typeof res.body.error).toBe('string')
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('framing alone with no stored original', async () => {
    prismaMock.member.findUnique.mockResolvedValue(member({ profilePictureOriginalUrl: null }))
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING))
    expect(res.status).toBe(400)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})

describe('413 over 10MB per file, as JSON (F4)', () => {
  const big = Buffer.alloc(10 * 1024 * 1024 + 1, 1)

  it('the rendered avatar', async () => {
    const res = await post().attach('file', big, JPEG)
    expect(res.status).toBe(413)
    expect(res.headers['content-type']).toMatch(/application\/json/)
    expect(res.body.success).toBe(false)
  })

  it('the original', async () => {
    const res = await post().attach('file', Buffer.from('r'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', big, JPEG)
    expect(res.status).toBe(413)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a 6MB original (over the old 5MB limit) is accepted', async () => {
    const res = await post()
      .attach('file', Buffer.from('render'), JPEG)
      .field('framing', JSON.stringify(FRAMING))
      .attach('original', Buffer.alloc(6 * 1024 * 1024, 1), JPEG)
    expect(res.status).toBe(200)
  })
})

describe('who may replace an avatar (D6, D16)', () => {
  it('the member themself — no visibility check', async () => {
    const res = await post(SELF).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(canViewMember).not.toHaveBeenCalled()
  })

  it('a role-holder who can view the member', async () => {
    const res = await post(LEADER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(200)
    expect(canViewMember).toHaveBeenCalledWith('gl', 'm1')
  })

  it('a role-holder WITHOUT visibility gets 404 and nothing is uploaded (D16)', async () => {
    vi.mocked(canViewMember).mockResolvedValue(false)
    const res = await post(LEADER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
    expect(storage.uploadMemberAvatar).not.toHaveBeenCalled()
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a non-manager gets 403', async () => {
    vi.mocked(getManageableOrgIds).mockResolvedValue([])
    const res = await post(STRANGER).attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(403)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('a member in no org can be changed only by themself', async () => {
    prismaMock.member.findUnique.mockResolvedValue(member({ organizations: [] }))
    expect((await post(LEADER).attach('file', Buffer.from('render'), JPEG)).status).toBe(403)
    expect((await post(SELF).attach('file', Buffer.from('render'), JPEG)).status).toBe(200)
  })
})

describe('500 — R2 failures leave the row unchanged', () => {
  it('the original upload fails', async () => {
    storage.uploadToR2.mockRejectedValue(new Error('r2 down'))
    const res = await post().attach('file', Buffer.from('render'), JPEG).field('framing', JSON.stringify(FRAMING)).attach('original', Buffer.from('orig'), JPEG)
    expect(res.status).toBe(500)
    expect(res.body.success).toBe(false)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })

  it('the avatar upload fails', async () => {
    storage.uploadMemberAvatar.mockResolvedValue({ success: false, error: 'Internal error uploading avatar' })
    const res = await post().attach('file', Buffer.from('render'), JPEG)
    expect(res.status).toBe(500)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 8: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/members-avatar.request.test.ts` → FAIL: the response has no `originalUrl`/`framing`, `avatar` and `original` are rejected as unexpected multer fields (HTML 500), the D16 case answers 200, the 6MB original answers 500

- [ ] **Step 9: The avatar multer, JSON error mapping and the D16 gate** — in `server/src/routes/members.ts`:
  - Line 1: `import { Router, type Request } from 'express'` → `import { Router, type Request, type RequestHandler } from 'express'`
  - Delete line 4 (`import sharp from 'sharp'`) and line 42 (`import { uploadMemberAvatar, deleteMemberAvatar } from '../services/storage.js'`) — both become unused, and `noUnusedLocals` is on.
  - Add beside the other service imports:

```ts
import { MemberAvatarNotFoundError, saveMemberAvatar } from '../services/member-avatar.js'
import { ImageUploadError } from '../services/image-original.js'
```

  - Replace the `upload` multer (lines 47-61, the comment and `const upload = multer({…})`) — the avatar route is its only user — with:

```ts
/** image-framing-editor D8: per file — a detailed 2400px JPEG 0.9 original can approach 5MB. */
const AVATAR_FILE_LIMIT = 10 * 1024 * 1024
const AVATAR_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']

const avatarUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: AVATAR_FILE_LIMIT },
  fileFilter: (_req, file, cb) => {
    if (AVATAR_TYPES.includes(file.mimetype)) cb(null, true)
    else cb(new Error('Invalid file type. Allowed: JPEG, PNG, GIF, WebP'))
  },
}).fields([
  { name: 'file', maxCount: 1 },
  { name: 'avatar', maxCount: 1 },
  { name: 'original', maxCount: 1 },
])

/** D8 / F4: multer errors answer JSON — over the limit 413, an unexpected field or file type 400. */
const receiveAvatarUpload: RequestHandler = (req, res, next) => {
  avatarUpload(req, res, (err: unknown) => {
    if (!err) return next()
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      res.status(413).json({ success: false, error: 'Each file must be 10MB or smaller' })
      return
    }
    res.status(400).json({ success: false, error: err instanceof Error ? err.message : 'Invalid upload' })
  })
}
```

  - Directly after `viewerOf` (ends line 75) add:

```ts
/**
 * image-framing-editor D16: the PATCH visibility gate on a route behind requireMemberOrOrgOwner —
 * a user the member is hidden from gets GET's 404 before anything is read or written.
 */
const requireVisibleMember: RequestHandler = async (req, res, next) => {
  try {
    const { memberId } = req.params
    const viewer = viewerOf(req, memberId)
    if (viewer?.kind === 'user' && !(await canViewMember(viewer.userId, memberId))) {
      res.status(404).json({ success: false, error: 'Member not found' })
      return
    }
    next()
  } catch (error) {
    next(error)
  }
}
```

- [ ] **Step 10: The thin route** — replace the avatar route's `@openapi` block and handler (lines 1429-1580, from `/**` above ` * /api/members/{memberId}/avatar:` through the closing `)`) with:

```ts
/**
 * @openapi
 * /api/members/{memberId}/avatar:
 *   post:
 *     tags: [Members]
 *     summary: Upload member avatar (with optional framing + original)
 *     description: |
 *       image-framing-editor D8. The rendered avatar (`file`, or `avatar` — D14) is re-encoded to a
 *       512px WebP and becomes profilePicture. With `framing` + `original` the full original
 *       (re-encoded: EXIF applied, longest side 2400px, JPEG 90) and the framing are stored too;
 *       `framing` alone re-frames the stored original; neither clears both. One DB write; the old
 *       avatar and a replaced original are deleted afterwards. A user who cannot view the member
 *       gets 404 (D16).
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - in: path
 *         name: memberId
 *         required: true
 *         schema:
 *           type: string
 *         description: Member ID
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *                 description: The rendered avatar (JPEG, PNG, GIF, WebP), max 10MB. Required unless sent as `avatar`.
 *               avatar:
 *                 type: string
 *                 format: binary
 *                 description: D14 — the same image under the web's field name.
 *               framing:
 *                 type: string
 *                 description: 'JSON string {scale 1–8, rotation -45–45, offsetX/offsetY -1–1, flipped?, quarterTurns? 0–3}; strict. Required with original.'
 *               original:
 *                 type: string
 *                 format: binary
 *                 description: The full original photo, max 10MB. Requires framing.
 *     responses:
 *       200:
 *         description: Avatar saved
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                   example: true
 *                 data:
 *                   type: object
 *                   properties:
 *                     url:
 *                       type: string
 *                       format: uri
 *                       description: The new profilePicture (512px WebP)
 *                     originalUrl:
 *                       type: string
 *                       format: uri
 *                       nullable: true
 *                     framing:
 *                       type: object
 *                       nullable: true
 *       400:
 *         description: No file, bad or unknown-key framing, original without framing, framing alone with no stored original, an unexpected field or file type, or an undecodable image
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       403:
 *         description: Not the member and not a manager of one of the member's orgs
 *       404:
 *         description: Member not found, or hidden from the caller (D16)
 *       413:
 *         description: A file over 10MB
 *       500:
 *         description: Storage or database failure — the member row is unchanged
 */
router.post(
  '/:memberId/avatar',
  requireMemberOrOrgOwner,
  requireVisibleMember,
  receiveAvatarUpload,
  async (req, res) => {
    try {
      const files = (req.files ?? {}) as Record<string, Array<{ buffer: Buffer }> | undefined>
      const body = (req.body ?? {}) as Record<string, unknown>

      // D8: `framing` is the only text field.
      const unexpected = Object.keys(body).find((key) => key !== 'framing')
      if (unexpected) {
        return res.status(400).json({ success: false, error: `Unexpected field: ${unexpected}` })
      }
      if (body.framing !== undefined && typeof body.framing !== 'string') {
        return res.status(400).json({ success: false, error: 'framing must be one JSON string' })
      }

      // D14: the phone sends the rendered image as `file`, the web as `avatar`.
      const rendered = files.file?.[0] ?? files.avatar?.[0]
      if (!rendered) {
        return res.status(400).json({ success: false, error: 'No file uploaded' })
      }

      const saved = await saveMemberAvatar({
        memberId: req.params.memberId,
        rendered: rendered.buffer,
        framingJson: body.framing as string | undefined,
        original: files.original?.[0]?.buffer,
      })

      res.json({ success: true, data: saved })
    } catch (error) {
      if (error instanceof ImageUploadError || error instanceof MemberAvatarNotFoundError) {
        return res.status(error.status).json({ success: false, error: error.message })
      }
      console.error('Error uploading avatar:', error)
      res.status(500).json({ success: false, error: 'Internal server error' })
    }
  }
)
```

  `getMember` stays imported (other routes use it at lines 309, 783, 1634, 1885).

- [ ] **Step 11: Run everything and watch it pass** — `cd server && npx tsc --noEmit && npx vitest run src/routes/__tests__/members-avatar.request.test.ts src/services/__tests__/member-avatar.test.ts src/services/__tests__/group-cover.test.ts src/routes/__tests__/` → PASS (the new tests, every existing members and groups request test)

- [ ] **Step 12: Commit** — `feat(image-framing-editor): avatar upload takes framing + original — member-avatar service, JSON multer errors, visibility gate`

### Task 3: The four non-upload `profilePicture` writers clear the original and framing (D11)
App: server
Phase: 1
Recipe: `/api` · SPEC D11 · §server bullet 3 · §Schema & API changes SC4

**Files:**
- Modify: `server/src/services/member-avatar.ts` (append `clearedAvatarOriginal`)
- Modify: `server/src/services/member.ts:65-80` (`UpdateMemberData`), `:274-306` (`updateMember`) — covers `PATCH /api/members/:memberId` (`members.ts:1348`) and `POST /:memberId/avatar/sync-google` (`members.ts:1675`), both of which write through `updateMember`
- Modify: `server/src/services/member-google.ts:194-200` (`syncGoogleProfile` — `POST /:memberId/sync-google-profile`)
- Modify: `server/src/services/account-linking.ts:44-70` (`syncProfilePictureFromUrl` — OAuth link `:175`, user link `:335`, `scripts/sync-linked-member-avatars.ts:53`)
- Test: `server/src/routes/__tests__/members-avatar-clear.request.test.ts`, `server/src/services/__tests__/account-linking-avatar.test.ts`

**Interfaces:**
- Consumes: Task 2's `deleteOriginalBestEffort(url: string, context: string): Promise<void>` (`services/image-original.ts`); Task 1's Prisma fields
- Produces:
  - `services/member-avatar.ts`: `export function clearedAvatarOriginal(): { profilePictureOriginalUrl: null; profilePictureFraming: typeof Prisma.DbNull }`
  - `UpdateMemberData` gains `profilePictureOriginalUrl?: null` and `profilePictureFraming?: typeof Prisma.DbNull` (set by `updateMember` itself; the PATCH zod stays `.strict()` and does NOT accept them)

- [ ] **Step 1: Write the failing request test for the three route writers** — `server/src/routes/__tests__/members-avatar-clear.request.test.ts`

```ts
/**
 * image-framing-editor D11: every profilePicture write other than the avatar upload clears the
 * stored original + framing and deletes the old original after the write, best-effort. The real
 * routes and the real updateMember / syncGoogleProfile run; Prisma and R2 are mocked.
 */
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn(), update: vi.fn() },
  user: { findUnique: vi.fn() },
}))
const storage = vi.hoisted(() => ({
  uploadMemberAvatar: vi.fn(),
  deleteMemberAvatar: vi.fn(),
  uploadToR2: vi.fn(),
  uploadImageVariants: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => storage)
vi.mock('../../lib/activity-log.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../lib/activity-log.js')>()),
  logSuccess: vi.fn(),
}))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-access.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-access.js')>()),
  canViewMember: vi.fn(),
}))

import { canViewMember } from '../../services/member-access.js'
import membersRoutes from '../members.js'

function appAsLeader() {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { session: {}, user: { id: 'gl', isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'
const GOOGLE_PICTURE = 'https://lh3.googleusercontent.com/a/photo=s96-c'
const CLEARED = { profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull }
const memberRow = (over: Record<string, unknown> = {}) => ({
  id: 'm1',
  email: 'james.carter@example.org',
  profilePicture: 'https://img.test/avatars/members/m1/100.webp',
  profilePictureOriginalUrl: OLD_ORIGINAL,
  profilePictureFraming: { scale: 2, rotation: 0, offsetX: 0, offsetY: 0, flipped: false, quarterTurns: 0 },
  googleId: 'g-1',
  googlePicture: GOOGLE_PICTURE,
  organizations: [],
  ...over,
})
const written = () => prismaMock.member.update.mock.calls[0][0].data
const deletedAfterWrite = () => {
  expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
  expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.member.update.mock.invocationCallOrder[0])
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.member.findUnique.mockResolvedValue(memberRow())
  prismaMock.member.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => memberRow(data))
  prismaMock.user.findUnique.mockResolvedValue({ id: 'u1', picture: GOOGLE_PICTURE, googleId: 'g-1' })
  storage.deleteFromR2.mockResolvedValue(undefined)
  vi.mocked(canViewMember).mockResolvedValue(true)
})

describe('PATCH /api/members/:memberId with the profilePicture key (D11)', () => {
  it.each([['a URL', 'https://img.test/elsewhere.jpeg'], ['null', null]])('profilePicture = %s clears both', async (_l, value) => {
    const res = await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: value })
    expect(res.status).toBe(200)
    expect(written()).toMatchObject({ profilePicture: value, ...CLEARED })
    deletedAfterWrite()
  })

  it('a PATCH without the key leaves them alone and reads nothing extra', async () => {
    await request(appAsLeader()).patch('/api/members/m1').send({ firstName: 'Ann' })
    expect(written()).not.toHaveProperty('profilePictureOriginalUrl')
    expect(written()).not.toHaveProperty('profilePictureFraming')
    expect(prismaMock.member.findUnique).not.toHaveBeenCalled()
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it.each([['profilePictureOriginalUrl', 'https://img.test/x.jpeg'], ['profilePictureFraming', { scale: 1 }]])(
    'a client cannot write %s (the PATCH zod stays strict)',
    async (key, value) => {
      const res = await request(appAsLeader()).patch('/api/members/m1').send({ [key]: value })
      expect(res.status).toBe(400)
      expect(prismaMock.member.update).not.toHaveBeenCalled()
    }
  )

  it('no stored original: clears, deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue(memberRow({ profilePictureOriginalUrl: null }))
    await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: null })
    expect(written()).toMatchObject(CLEARED)
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed delete is logged, the PATCH still answers 200', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    const res = await request(appAsLeader()).patch('/api/members/m1').send({ profilePicture: null })
    expect(res.status).toBe(200)
  })
})

describe('POST /api/members/:memberId/avatar/sync-google (D11)', () => {
  it('writes the Google picture and clears both', async () => {
    const res = await request(appAsLeader()).post('/api/members/m1/avatar/sync-google')
    expect(res.status).toBe(200)
    expect(written()).toMatchObject({ profilePicture: GOOGLE_PICTURE, ...CLEARED })
    deletedAfterWrite()
  })
})

describe('POST /api/members/:memberId/sync-google-profile (D11)', () => {
  it('writes the linked googlePicture and clears both', async () => {
    const res = await request(appAsLeader()).post('/api/members/m1/sync-google-profile')
    expect(res.status).toBe(200)
    expect(res.body.data.profilePicture).toBe(GOOGLE_PICTURE)
    expect(prismaMock.member.update.mock.calls[0][0]).toEqual({
      where: { id: 'm1' },
      data: { profilePicture: GOOGLE_PICTURE, ...CLEARED },
    })
    deletedAfterWrite()
  })
})
```

- [ ] **Step 2: Write the failing unit test for the link-time copy** — `server/src/services/__tests__/account-linking-avatar.test.ts`

```ts
/**
 * image-framing-editor D11/D15: syncProfilePictureFromUrl (OAuth link, user link, the sync script)
 * copies the Google picture into R2 as the avatar and clears the stored original + framing.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn(), update: vi.fn() } }))
const storage = vi.hoisted(() => ({
  uploadMemberAvatar: vi.fn(),
  deleteMemberAvatar: vi.fn(),
  uploadToR2: vi.fn(),
  uploadImageVariants: vi.fn(),
  deleteFromR2: vi.fn(),
  extractKeyFromUrl: vi.fn((url: string) => url.replace('https://img.test/', '')),
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../storage.js', () => storage)

import { syncProfilePictureFromUrl } from '../account-linking.js'

const COPY = 'https://img.test/avatars/members/m1/300.jpg'
const OLD_ORIGINAL = 'https://img.test/avatars/members/m1/100-original.jpeg'

beforeEach(() => {
  vi.clearAllMocks()
  vi.stubGlobal(
    'fetch',
    vi.fn().mockResolvedValue(new Response(Buffer.from('img'), { status: 200, headers: { 'content-type': 'image/jpeg' } }))
  )
  storage.uploadMemberAvatar.mockResolvedValue({ success: true, url: COPY })
  storage.deleteFromR2.mockResolvedValue(undefined)
  prismaMock.member.findUnique.mockResolvedValue({ profilePictureOriginalUrl: OLD_ORIGINAL })
  prismaMock.member.update.mockResolvedValue({})
})

afterEach(() => {
  vi.unstubAllGlobals()
})

describe('syncProfilePictureFromUrl (D11)', () => {
  it('writes the R2 copy and clears the original + framing, then deletes the old original', async () => {
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
    expect(prismaMock.member.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: { profilePicture: COPY, profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull },
    })
    expect(storage.deleteFromR2).toHaveBeenCalledWith('avatars/members/m1/100-original.jpeg')
    expect(storage.deleteFromR2.mock.invocationCallOrder[0]).toBeGreaterThan(prismaMock.member.update.mock.invocationCallOrder[0])
  })

  it('no stored original: deletes nothing', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ profilePictureOriginalUrl: null })
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
    expect(storage.deleteFromR2).not.toHaveBeenCalled()
  })

  it('a failed delete still returns true', async () => {
    storage.deleteFromR2.mockRejectedValue(new Error('r2 down'))
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(true)
  })

  it('a failed download writes nothing', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('nope', { status: 404 })))
    expect(await syncProfilePictureFromUrl('m1', 'https://lh3.googleusercontent.com/a/x')).toBe(false)
    expect(prismaMock.member.update).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/routes/__tests__/members-avatar-clear.request.test.ts src/services/__tests__/account-linking-avatar.test.ts` → FAIL: the writes carry no `profilePictureOriginalUrl` / `profilePictureFraming`, and `deleteFromR2` is never called

- [ ] **Step 4: The clearing fields** — append to `server/src/services/member-avatar.ts`:

```ts
/**
 * D11: what every profilePicture write OTHER than the avatar upload also sets — the stored
 * original and framing no longer describe the avatar, so Edit must not reopen them.
 */
export function clearedAvatarOriginal(): { profilePictureOriginalUrl: null; profilePictureFraming: typeof Prisma.DbNull } {
  return { profilePictureOriginalUrl: null, profilePictureFraming: Prisma.DbNull }
}
```

- [ ] **Step 5: `updateMember` clears whenever it writes `profilePicture`** — in `server/src/services/member.ts`:
  - Add after the existing imports:

```ts
import { clearedAvatarOriginal } from './member-avatar.js'
import { deleteOriginalBestEffort } from './image-original.js'
```

  - In `UpdateMemberData` (lines 65-80), after `profilePicture?: string | null` add:

```ts
  /** image-framing-editor D11: set by updateMember itself whenever profilePicture is written. */
  profilePictureOriginalUrl?: null
  profilePictureFraming?: typeof Prisma.DbNull
```

  - In `updateMember`, directly after `const update: UpdateMemberData = { ...data }` (line 280) add:

```ts
    // image-framing-editor D11: a profilePicture written here (PATCH, avatar/sync-google) drops the
    // stored original + framing; the old original is deleted after the write, best-effort.
    let replacedOriginal: string | null = null
    if (data.profilePicture !== undefined) {
      const stored = await prisma.member.findUnique({
        where: { id: memberId },
        select: { profilePictureOriginalUrl: true },
      })
      replacedOriginal = stored?.profilePictureOriginalUrl ?? null
      Object.assign(update, clearedAvatarOriginal())
    }
```

  - Directly after the `const member = await prisma.member.update({…})` statement (ends line 306) add:

```ts
    if (replacedOriginal) await deleteOriginalBestEffort(replacedOriginal, 'updateMember')
```

- [ ] **Step 6: `syncGoogleProfile`** — in `server/src/services/member-google.ts` add the imports

```ts
import { clearedAvatarOriginal } from './member-avatar.js'
import { deleteOriginalBestEffort } from './image-original.js'
```

  and replace the update (lines 194-200) with:

```ts
    // Update member's profile picture with Google picture; image-framing-editor D11 clears the
    // stored original + framing and deletes the old original after the write.
    const updatedMember = await prisma.member.update({
      where: { id: memberId },
      data: {
        profilePicture: member.googlePicture,
        ...clearedAvatarOriginal(),
      },
    })
    if (member.profilePictureOriginalUrl) {
      await deleteOriginalBestEffort(member.profilePictureOriginalUrl, 'syncGoogleProfile')
    }
```

- [ ] **Step 7: `syncProfilePictureFromUrl`** — in `server/src/services/account-linking.ts` add the imports

```ts
import { clearedAvatarOriginal } from './member-avatar.js'
import { deleteOriginalBestEffort } from './image-original.js'
```

  and replace the `// Update member's profilePicture` block (the `await prisma.member.update({ where: { id: memberId }, data: { profilePicture: uploadResult.url } })` at lines 63-67) with:

```ts
    // Update member's profilePicture; image-framing-editor D11/D15: the R2 copy counts as an
    // uploaded avatar with no original yet, so the stored original + framing are cleared.
    const stored = await prisma.member.findUnique({
      where: { id: memberId },
      select: { profilePictureOriginalUrl: true },
    })
    await prisma.member.update({
      where: { id: memberId },
      data: { profilePicture: uploadResult.url, ...clearedAvatarOriginal() },
    })
    if (stored?.profilePictureOriginalUrl) {
      await deleteOriginalBestEffort(stored.profilePictureOriginalUrl, 'syncProfilePictureFromUrl')
    }
```

- [ ] **Step 8: Run everything and watch it pass** — `cd server && npx tsc --noEmit && npx vitest run src/routes/__tests__/members-avatar-clear.request.test.ts src/services/__tests__/account-linking-avatar.test.ts src/services/__tests__/member-update.test.ts src/routes/__tests__/members-edit.request.test.ts src/routes/__tests__/members-avatar.request.test.ts` → PASS; then `cd server && npm run test:run` → all green

- [ ] **Step 9: Commit** — `feat(image-framing-editor): legacy profilePicture writers clear the avatar original + framing`

### Task 4: Google-only fixture member — and the contract freeze
App: server
Phase: 1
Recipe: SPEC §Testing (Fixtures) · D4 · `server/fixtures/README.md` (layer conventions)

**Files:**
- Modify: `server/fixtures/screens/members-profile.ts:1-18`
- Modify: `server/fixtures/__tests__/members.test.ts:1-6` (imports), append after `:85`
- Modify: `server/fixtures/README.md:69-75` (the "What `full` makes non-empty on Members" paragraph)
- Modify (freeze): `docs/features/image-framing-editor/MANIFEST.md` (via `advance.mjs`, last step)

**Interfaces:**
- Consumes: `AVATAR_MEMBER_INDICES` (`fixtures/images.ts:45` — `[0, 1, 2, 3, 4, 5, 6, 7, 9, 12, 15, 18, 21]`), `FIXTURE_MEMBER_IDS` (`fixtures/ids.ts`), `memberProfile(i, today)` (`fixtures/base.ts`), `FixtureContext` (`fixtures/context.ts`); images are placed by `seedImages` inside the base layer (`base.ts:327`), before any screen layer runs
- Produces: `fixtures/screens/members-profile.ts` exports `GOOGLE_ONLY_MEMBER_INDEX = 10` (Hannah Jenkins), `GOOGLE_ONLY_GOOGLE_ID = 'fixture-google-member-10'`, `GOOGLE_ONLY_GOOGLE_EMAIL = 'hannah.jenkins@example.org'`, `GOOGLE_PICTURE_SOURCE_INDEX` (= `AVATAR_MEMBER_INDICES[0]`, member 0); after `full`, member 10 has `googleId`, `googleEmail`, `googleLinkedAt`, `googlePicture` = member 0's placed avatar URL (null when images are off) and no `profilePicture`. MANIFEST `contract: frozen <date>`.

- [ ] **Step 1: Write the failing fixture test** — in `server/fixtures/__tests__/members.test.ts` change the first line to `import { describe, expect, it, vi } from 'vitest'`, add the imports

```ts
import type { FixtureContext } from '../context.js'
import {
  GOOGLE_ONLY_GOOGLE_EMAIL,
  GOOGLE_ONLY_GOOGLE_ID,
  GOOGLE_ONLY_MEMBER_INDEX,
  GOOGLE_PICTURE_SOURCE_INDEX,
  full as membersProfileFull,
} from '../screens/members-profile.js'
```

  (keep the existing `LEADER_MEMBER_INDEX` import from the same module — merge it into this import), and append at the end of the file:

```ts
describe('members-profile layer — the Google-only member (image-framing-editor D4)', () => {
  type UpdateArgs = { where: { id: string }; data: Record<string, unknown> }
  const fakeCtx = (sourcePicture: string | null) => {
    const updates: UpdateArgs[] = []
    const findUnique = vi.fn(async () => ({ profilePicture: sourcePicture }))
    const ctx = {
      prisma: {
        member: {
          update: vi.fn(async (args: UpdateArgs) => {
            updates.push(args)
            return {}
          }),
          findUnique,
        },
      },
      daysAgo: (n: number) => new Date(Date.UTC(2026, 9, 27) - n * 86_400_000),
    } as unknown as FixtureContext
    return { ctx, updates, findUnique }
  }
  const googleUpdate = (updates: UpdateArgs[]) =>
    updates.find((u) => u.where.id === FIXTURE_MEMBER_IDS[GOOGLE_ONLY_MEMBER_INDEX])

  it('picks a member with no fixture avatar who is not the leader, and a source that has one', () => {
    expect(AVATAR_MEMBER_INDICES).not.toContain(GOOGLE_ONLY_MEMBER_INDEX)
    expect(GOOGLE_ONLY_MEMBER_INDEX).not.toBe(LEADER_MEMBER_INDEX)
    expect(AVATAR_MEMBER_INDICES).toContain(GOOGLE_PICTURE_SOURCE_INDEX)
  })

  it('links the Google account under the member’s own email', () => {
    expect(memberProfile(GOOGLE_ONLY_MEMBER_INDEX, '2026-10-25').email).toBe(GOOGLE_ONLY_GOOGLE_EMAIL)
  })

  it('uses the source member’s placed avatar URL as the Google picture', async () => {
    const placed = 'https://img.test/avatars/members/m0/1700000000001.webp'
    const { ctx, updates, findUnique } = fakeCtx(placed)
    await membersProfileFull(ctx)
    expect(findUnique).toHaveBeenCalledWith({
      where: { id: FIXTURE_MEMBER_IDS[GOOGLE_PICTURE_SOURCE_INDEX] },
      select: { profilePicture: true },
    })
    expect(googleUpdate(updates)?.data).toEqual({
      googleId: GOOGLE_ONLY_GOOGLE_ID,
      googleEmail: GOOGLE_ONLY_GOOGLE_EMAIL,
      googlePicture: placed,
      googleLinkedAt: expect.any(Date),
    })
    expect(googleUpdate(updates)?.data).not.toHaveProperty('profilePicture')
  })

  it('still links the account (picture null) when images are off', async () => {
    const { ctx, updates } = fakeCtx(null)
    await membersProfileFull(ctx)
    expect(googleUpdate(updates)?.data).toMatchObject({ googleId: GOOGLE_ONLY_GOOGLE_ID, googlePicture: null })
  })

  it('keeps the member-7 leader link', async () => {
    const { ctx, updates } = fakeCtx(null)
    await membersProfileFull(ctx)
    expect(updates.find((u) => u.where.id === FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX])?.data).toMatchObject({ userId: expect.any(String) })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/members.test.ts` → FAIL, `GOOGLE_ONLY_MEMBER_INDEX` is not exported by `../screens/members-profile.js`

- [ ] **Step 3: Extend the layer** — replace `server/fixtures/screens/members-profile.ts` with:

```ts
/**
 * members-profile layer (ui2-members-browse D8, T7): what the member page reads beyond base.
 * Base fills the D13 fields, the groups (members-home adds the second membership) and, with
 * home-dashboard, the activity rail and program progress. This layer links member 7 (Nathan
 * Hughes) to the Group-Leader user of the same name, so his Role reads "Group leader" (D8 —
 * the linked user created a group in the org). image-framing-editor D4: it also links member 10
 * (Hannah Jenkins, no fixture avatar) to a Google account, so her avatar tap shows the Google-only
 * menu (Change image + View image). The Google picture is member 0's placed avatar URL — a fixture
 * never fetches googleusercontent.com; with images off it is null and she shows initials.
 * Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'
import { AVATAR_MEMBER_INDICES } from '../images.js'

export const LEADER_MEMBER_INDEX = 7
/** image-framing-editor D4: a member with a Google link and no uploaded avatar. */
export const GOOGLE_ONLY_MEMBER_INDEX = 10
export const GOOGLE_ONLY_GOOGLE_ID = 'fixture-google-member-10'
export const GOOGLE_ONLY_GOOGLE_EMAIL = 'hannah.jenkins@example.org'
/** Whose placed avatar stands in for the Google picture. */
export const GOOGLE_PICTURE_SOURCE_INDEX = AVATAR_MEMBER_INDICES[0]

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] },
    data: { userId: FIXTURE_LEADER_USER_ID, userLinkedAt: ctx.daysAgo(30) },
  })

  const source = await ctx.prisma.member.findUnique({
    where: { id: FIXTURE_MEMBER_IDS[GOOGLE_PICTURE_SOURCE_INDEX] },
    select: { profilePicture: true },
  })
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[GOOGLE_ONLY_MEMBER_INDEX] },
    data: {
      googleId: GOOGLE_ONLY_GOOGLE_ID,
      googleEmail: GOOGLE_ONLY_GOOGLE_EMAIL,
      googlePicture: source?.profilePicture ?? null,
      googleLinkedAt: ctx.daysAgo(20),
    },
  })
}
```

- [ ] **Step 4: README** — in `server/fixtures/README.md`, at the end of the "What `full` makes non-empty on Members" paragraph (after "…so his Role reads "Group leader"." on line 75) add the sentence: `Hannah Jenkins (member 10, no fixture avatar) is linked to a Google account whose picture is James Carter's placed avatar URL, so her avatar tap shows the Google-only menu (image-framing-editor D4); with images off her googlePicture is null.`

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run fixtures/__tests__/members.test.ts fixtures/__tests__/shared-edit-field.test.ts` → PASS; `cd server && npx tsc --noEmit -p fixtures` → no errors; `cd server && npm run test:run` → all green

- [ ] **Step 6: Check it against the running stack** — this step hits the container, so restart it first (it does not pick up host edits, nor Tasks 1–3's server code, without a restart):

```bash
docker restart makeready-server
docker exec makeready-server npm run fixtures:reset
docker exec makeready-postgres psql -U postgres -d makeready_dev -tAc \
  "SELECT \"googleId\", \"googlePicture\" IS NOT NULL, \"profilePicture\" IS NULL FROM members WHERE \"googleId\" = 'fixture-google-member-10'"
```

  Expect `fixture-google-member-10|t|t` (the middle column reads `f` only when the container has no R2 settings and skipped images — the reset log then prints `skipping fixture images`; report that rather than changing the layer).

- [ ] **Step 7: Commit** — `git add server/fixtures/screens/members-profile.ts server/fixtures/__tests__/members.test.ts server/fixtures/README.md` → `feat(image-framing-editor): Google-only fixture member for the avatar menu`

- [ ] **Step 8: Record the contract freeze** — after the phase-1 gates pass (the build loop runs them at the phase close), the producer phase closes the contract. Run from the repo root:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.4.1/scripts/advance.mjs docs/features/image-framing-editor \
  --set "contract=frozen $(date +%Y-%m-%d)" --head --commit "chore({feature}): {feature} — contract frozen at phase 1"
```

  No iPhone task starts before the manifest reads `contract: frozen`.
### Task 5: Shared, aspect-parameterised framing editor — the group cover moved onto it, behaviour unchanged
App: iphone
Phase: 2
Recipe: SPEC §iphone "Shared editor (D1)" · D1, D12 · iphone/.claude/CLAUDE.md · ⚠ build-time risk F2

> **Commits:** the config now marks iphone `commit: auto` (owner 2026-10-26) — commit this task like any other; the Global Constraints' "stage and STOP" line predates that ruling.

> **⚠ build-time risk (F2):** these pieces shipped hours ago with agent sign-off only. The gate for this task is **behaviour unchanged**: the group cover's whole existing test set — `CoverFramingMathTests` (17), `CoverImageRenderingTests` (11), `EditGroupCoverModelTests` (28), `EditGroupCoverContainerTests` (10), `CoverViewerOverlayTests` (5), `GroupCoverDecodingTests` (9), `GroupDetailCoverTapTests` (4), `GroupSaveCoverTests` (5) = **89 test methods** — passes BEFORE you start and AFTER, every one of the 89 still present by name (some move class, below). Only mechanical edits touch them: renamed types, the init's new arguments, the save closure returning a `String`, the 16:9 constant read from the group side.

> **Do not touch `iphone/MakeReadyUI/`** in this task. `EditCoverScreen.swift` may carry an uncommitted owner hand edit (F3) — never stage it. Its doc comment mentions `CoverFramingCanvas`; leave it (d2m owns that file).

**Files:**
- Rename: `iphone/MakeReady/UI2/Containers/Groups/CoverFramingMath.swift` → `iphone/MakeReady/UI2/Containers/Groups/ImageFramingMath.swift` (`:12-14` lose `frameAspect`)
- Rename: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverModel.swift` → `iphone/MakeReady/UI2/Containers/Groups/ImageFramingModel.swift` (`:1-56` header/init, `:146-167` save, `:169-178` `opening(group:)` removed)
- Create: `iphone/MakeReady/UI2/Containers/Groups/ImageFramingCanvas.swift` (the canvas, moved out of `EditGroupCoverContainer.swift:225-277`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/CoverImageRendering.swift:4-34` (`renderSize` removed, `render(_:framing:size:)`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift:10-12, 39-68, 104-108, 144-150, 160-222, 225-277`
- Modify: `iphone/MakeReady/UI2/Containers/Groups/CoverViewerOverlay.swift:6-8, 32, 58-81` (accessibility label input)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift:104` (viewer label)
- Modify: `iphone/MakeReady/State/Models/GroupModels.swift:15-55` (`CoverFraming` → `ImageFraming` + typealias)
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:35-37` (`ImageEditSource`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (the renames, the new file — app + test targets; then `ruby iphone/scripts/capture-targets.rb`)
- Rename/Test: `iphone/MakeReadyCaptureTests/CoverFramingMathTests.swift` → `iphone/MakeReadyCaptureTests/ImageFramingMathTests.swift`
- Rename/Test: `iphone/MakeReadyCaptureTests/EditGroupCoverModelTests.swift` → `iphone/MakeReadyCaptureTests/ImageFramingModelTests.swift`
- Test: `iphone/MakeReadyCaptureTests/CoverImageRenderingTests.swift`, `iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift`, `iphone/MakeReadyCaptureTests/CoverViewerOverlayTests.swift:52,61`

**Interfaces:**
- Consumes: the shipped group-cover editor (no earlier task in this plan).
- Produces (later tasks use exactly these names):
  - `struct ImageFraming: Codable, Equatable, Hashable { var scale: Double; var rotation: Double; var offsetX: Double; var offsetY: Double; var flipped: Bool; var quarterTurns: Int; static let identity; var requestBody: [String: Any] }` and `typealias CoverFraming = ImageFraming` (in `GroupModels.swift`)
  - `enum ImageEditSource: Hashable { case newPick(UIImage); case stored }`
  - `enum ImageFramingMath` — same statics as `CoverFramingMath` minus `frameAspect`
  - `CoverImageRendering.render(_ image: UIImage, framing: ImageFraming, size: CGSize) -> UIImage`; `CoverImageRendering.uprightDownsampled(_:maxPixels:)` unchanged
  - `@MainActor @Observable final class ImageFramingModel` — `init(image: UIImage, framing: ImageFraming, isNewPick: Bool, hasStoredOriginal: Bool, frameSize: CGSize, outputSize: CGSize, saveFailedMessage: String, save: @escaping @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String)`; `enum SaveOutcome: Equatable { case saved, ignored, unauthorized, forbidden, gone, failed(String) }`; `let outputSize: CGSize`; `let saveFailedMessage: String`; everything else as `EditGroupCoverModel` had it (`framing`, `isSaving`, `isGestureActive`, `isTwisting`, `hasChanges`, `readoutDegrees`, `updateGesture`, `straighten(to:)`, `endGesture`, `endStraighten`, `flip`, `rotate90`, `save() async -> SaveOutcome`)
  - `struct ImageFramingCanvas: View { let model: ImageFramingModel; let frame: CGRect; let accessibilityLabel: String; static let settle: Animation }`
  - `CoverViewerOverlay(url:accessibilityLabel:onClose:)` and `View.coverViewerPresentation(url: String?, accessibilityLabel: String, onClose: @escaping () -> Void)`
  - On `EditGroupCoverContainer`: `static let frameAspect: CGFloat = 16/9`, `static let renderSize = CGSize(width: 1200, height: 675)`, `static let saveFailedMessage = "Couldn't save the cover"`, `static let canvasLabel = "Cover framing"`, `static func opening(group: UserGroup) -> (url: String, framing: ImageFraming, hasOriginal: Bool)?`; the existing `route`, `cancelAction(hasChanges:isSaving:)`, `blocksBackSwipe(hasChanges:isSaving:)`, `discardPops(isSaving:)`, `discardAction`, `screenState(_:)` (now taking `ImageFramingModel?`) stay — Task 7's avatar container reuses them
  - `UI2Destination.editGroupCover(groupId: String, source: ImageEditSource)`

All commands run from the repo root `/Users/lukekeith/www/makeready` unless they `cd`.

- [ ] **Step 1: Preflight and the F2 baseline** — `git status --porcelain iphone/MakeReady.xcodeproj/project.pbxproj` must print nothing; if it shows a modification you did not make, STOP and report it (this task rewrites the pbxproj and must not commit someone else's edit). Then run `npm run ios:build-check -- --test` → PASS. Write down the pass count and confirm the 89 group-cover methods ran:

```bash
grep -c "func test" iphone/MakeReadyCaptureTests/{CoverFramingMathTests,CoverImageRenderingTests,EditGroupCoverModelTests,EditGroupCoverContainerTests,CoverViewerOverlayTests,GroupCoverDecodingTests,GroupDetailCoverTapTests,GroupSaveCoverTests}.swift
```

→ 17 · 11 · 28 · 10 · 5 · 9 · 4 · 5.

- [ ] **Step 2: Rename the two test files in git and in the project** — the Xcode project has no file-system-synchronised groups, so a file is only compiled through its `project.pbxproj` reference. This one-liner re-points an existing reference to the new file name (both targets share the reference):

```bash
cd /Users/lukekeith/www/makeready
rename_ref() { ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); o=File.expand_path(ARGV[0]); n=File.expand_path(ARGV[1]); r=p.files.find{|f| f.real_path.to_s==o} or abort("not in project: #{ARGV[0]}"); r.path=r.path.sub(/[^\/]+\z/, File.basename(n)); r.name=File.basename(n) if r.name; p.save' "$1" "$2" && git mv "$1" "$2"; }
rename_ref iphone/MakeReadyCaptureTests/CoverFramingMathTests.swift iphone/MakeReadyCaptureTests/ImageFramingMathTests.swift
rename_ref iphone/MakeReadyCaptureTests/EditGroupCoverModelTests.swift iphone/MakeReadyCaptureTests/ImageFramingModelTests.swift
```

Then the mechanical renames in the four editor test files:

```bash
perl -pi -e 's/\bCoverFramingMathTests\b/ImageFramingMathTests/g; s/\bEditGroupCoverModelTests\b/ImageFramingModelTests/g; s/\bCoverFramingMath\b/ImageFramingMath/g; s/\bEditGroupCoverModel\b/ImageFramingModel/g; s/\bCoverEditSource\b/ImageEditSource/g' \
  iphone/MakeReadyCaptureTests/ImageFramingMathTests.swift iphone/MakeReadyCaptureTests/ImageFramingModelTests.swift \
  iphone/MakeReadyCaptureTests/CoverImageRenderingTests.swift iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift
perl -pi -e 's/async throws -> CoverSaveResult/async throws -> String/g' iphone/MakeReadyCaptureTests/ImageFramingModelTests.swift
perl -pi -e 's/coverViewerPresentation\(url: nil, onClose:/coverViewerPresentation(url: nil, accessibilityLabel: "Group cover", onClose:/g' iphone/MakeReadyCaptureTests/CoverViewerOverlayTests.swift
perl -pi -e 's/CoverImageRendering\.render\(/renderCover(/g; s/CoverImageRendering\.renderSize/EditGroupCoverContainer.renderSize/g' iphone/MakeReadyCaptureTests/CoverImageRenderingTests.swift
```

(`CoverFraming` stays in the tests — the typealias keeps it; the tests are left as close to unchanged as the API allows.)

- [ ] **Step 3: Hand edits to the test files (the API change, the moved tests, the new 1:1 tests)**

`ImageFramingMathTests.swift` — delete `testFrameIs16By9` (lines 36-38, it moves to `EditGroupCoverContainerTests`); in `testRelativeScaleRoundTripsAcrossFrameSizes` change `1200 / ImageFramingMath.frameAspect` to `1200 / EditGroupCoverContainer.frameAspect`. Append inside the class, before its closing brace:

```swift
    // MARK: - image-framing-editor D1/D3: the same math at 1:1 (the avatar)

    private let square = CGSize(width: 300, height: 300)

    private func coversSquare(_ f: CoverFraming, image: CGSize, accuracy: CGFloat = 0.01) -> Bool {
        let turned = f.quarterTurns % 2 == 0 ? image : CGSize(width: image.height, height: image.width)
        let s = ImageFramingMath.absoluteScale(f, image: image, frame: square)
        let c = ImageFramingMath.imageCenter(f, frame: square)
        let t = f.rotation * .pi / 180
        return [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)].allSatisfy { corner in
            let dx = corner.0 * square.width / 2 - c.x, dy = corner.1 * square.height / 2 - c.y
            let u = dx * cos(t) + dy * sin(t), v = -dx * sin(t) + dy * cos(t)
            return abs(u) <= s * turned.width / 2 + accuracy && abs(v) <= s * turned.height / 2 + accuracy
        }
    }

    /// D1: at 1:1 the shorter side binds at 0° and 90°, the square's diagonal at 45°.
    func testSquareFloorForWideAndTallAt0And45And90() {
        let diagonal = 300 * 2.0.squareRoot()
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: wide, frame: square, rotationDegrees: 0), 300.0 / 1600.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: wide, frame: square, rotationDegrees: 45), diagonal / 1600.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: wide, frame: square, rotationDegrees: 90), 300.0 / 1600.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: tall, frame: square, rotationDegrees: 0), 300.0 / 1200.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: tall, frame: square, rotationDegrees: 45), diagonal / 1200.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.zoomFloor(image: tall, frame: square, rotationDegrees: 90), 300.0 / 1200.0, accuracy: 1e-6)
    }

    /// D1/group-cover D21: a quarter turn swaps the image's sides; at 1:1 the shorter side still binds.
    func testSquareFloorAtAQuarterTurn() {
        XCTAssertEqual(ImageFramingMath.absoluteScale(framing(quarterTurns: 1), image: wide, frame: square), 300.0 / 1600.0, accuracy: 1e-6)
        XCTAssertEqual(ImageFramingMath.absoluteScale(framing(quarterTurns: 1), image: tall, frame: square), 300.0 / 1200.0, accuracy: 1e-6)
    }

    /// D1: a clamped framing covers the square frame at every fine rotation and quarter turn.
    func testClampedCoversTheSquareFrame() {
        for q in 0..<4 {
            for r in [-45.0, -20, 0, 13, 45] {
                let f = ImageFramingMath.clamped(framing(scale: 1.2, rotation: r, offsetX: 0.9, offsetY: -0.9, quarterTurns: q),
                                                 image: wide, frame: square)
                XCTAssertTrue(coversSquare(f, image: wide), "q=\(q) r=\(r)")
            }
        }
    }
```

`CoverImageRenderingTests.swift` — add inside the class, right after the `same(_:_:)` helper:

```swift
    /// The group cover's render (image-framing-editor D1: the size is the caller's).
    private func renderCover(_ image: UIImage, framing: CoverFraming) -> UIImage {
        CoverImageRendering.render(image, framing: framing, size: EditGroupCoverContainer.renderSize)
    }

    /// image-framing-editor D7: the avatar renders at exactly 512×512 — at identity, the photo's centred square.
    func testAvatarRenderIs512x512() {
        let out = CoverImageRendering.render(halves(CGSize(width: 2400, height: 1600)), framing: .identity,
                                             size: CGSize(width: 512, height: 512))
        XCTAssertEqual(out.cgImage?.width, 512)
        XCTAssertEqual(out.cgImage?.height, 512)
        XCTAssertTrue(same(out.pixel(100, 256), (r: 255, g: 0, b: 0)))
        XCTAssertTrue(same(out.pixel(400, 256), (r: 0, g: 0, b: 255)))
    }
```

`ImageFramingModelTests.swift` — replace the `ok` constant and the `model(...)` helper (lines 15-21) with:

```swift
    private let ok = "https://img/new.jpeg"

    private func model(isNewPick: Bool = true, hasStoredOriginal: Bool = true, framing: CoverFraming = .identity,
                       save: @escaping @MainActor (UIImage, CoverFraming, UIImage?) async throws -> String) -> ImageFramingModel {
        ImageFramingModel(image: image(), framing: framing, isNewPick: isNewPick,
                          hasStoredOriginal: hasStoredOriginal, frameSize: frame,
                          outputSize: EditGroupCoverContainer.renderSize,
                          saveFailedMessage: EditGroupCoverContainer.saveFailedMessage,
                          save: save)
    }
```

In `testSuccessSeedsTheImageCache` replace `let m = model(save: { _, _, _ in CoverSaveResult(coverImageUrl: url, coverOriginalUrl: nil, coverFraming: nil) })` with `let m = model(save: { _, _, _ in url })`. Cut the whole `testOpening()` method (the last method, `/// D7: the original at its framing…` through its closing brace) — it moves to `EditGroupCoverContainerTests` below. Append:

```swift
    /// image-framing-editor D12: a 403 is its own outcome (the avatar pops to its profile on it).
    func testForbiddenOutcome() async {
        let outcome = await model(save: { _, _, _ in throw APIHTTPError(status: 403, message: "Forbidden") }).save()
        XCTAssertEqual(outcome, .forbidden)
    }

    /// image-framing-editor D1/D7: the render follows the model's output size — 512×512 for the avatar.
    func testSaveRendersAtTheOutputSize() async {
        var size: CGSize?
        let m = ImageFramingModel(image: image(), framing: .identity, isNewPick: true, hasStoredOriginal: true,
                                  frameSize: CGSize(width: 300, height: 300), outputSize: CGSize(width: 512, height: 512),
                                  saveFailedMessage: "Couldn't save the photo",
                                  save: { r, _, _ in size = CGSize(width: r.cgImage!.width, height: r.cgImage!.height); return self.ok })
        _ = await m.save()
        XCTAssertEqual(size, CGSize(width: 512, height: 512))
        XCTAssertEqual(m.saveFailedMessage, "Couldn't save the photo")
    }
```

`EditGroupCoverContainerTests.swift` — replace the `ok` constant and the `model(isNewPick:)` helper (lines 9-20) with:

```swift
    private let ok = "https://img/new.jpeg"

    private func model(isNewPick: Bool) -> ImageFramingModel {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let size = CGSize(width: 1600, height: 1200)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return ImageFramingModel(image: image, framing: .identity, isNewPick: isNewPick,
                                 hasStoredOriginal: true, frameSize: CGSize(width: 320, height: 180),
                                 outputSize: EditGroupCoverContainer.renderSize,
                                 saveFailedMessage: EditGroupCoverContainer.saveFailedMessage,
                                 save: { _, _, _ in self.ok })
    }
```

and append, before the class's closing brace:

```swift
    /// Moved from CoverFramingMathTests (image-framing-editor D1): the 16:9 frame and the 1200×675
    /// render are the group cover's own constants now.
    func testFrameIs16By9() {
        XCTAssertEqual(EditGroupCoverContainer.frameAspect, 16.0 / 9.0, accuracy: 1e-12)
        XCTAssertEqual(EditGroupCoverContainer.renderSize, CGSize(width: 1200, height: 675))
    }

    /// image-framing-editor D12: the model's new 403 outcome keeps the group cover's old behaviour — the banner.
    func testForbiddenKeepsTheGroupBanner() {
        XCTAssertEqual(EditGroupCoverContainer.route(.forbidden), .banner)
    }

    /// Moved from EditGroupCoverModelTests (group-cover-image D7): the original at its framing; no
    /// original -> the cover at identity; no cover -> nil.
    func testOpening() {
        func group(cover: String?, original: String?, framing: CoverFraming?) -> UserGroup {
            UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original, coverFraming: framing,
                      isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
        }
        let f = CoverFraming(scale: 3, rotation: 10, offsetX: 0, offsetY: 0)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.url, "o")
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.hasOriginal, true)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: f))?.framing, f)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: "o", framing: nil))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.url, "c")
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.framing, .identity)
        XCTAssertEqual(EditGroupCoverContainer.opening(group: group(cover: "c", original: nil, framing: f))?.hasOriginal, false)
        XCTAssertNil(EditGroupCoverContainer.opening(group: group(cover: nil, original: nil, framing: nil)))
    }
```

- [ ] **Step 4: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `cannot find 'ImageFramingMath' in scope` (and `ImageFramingModel`, `EditGroupCoverContainer.frameAspect`)

- [ ] **Step 5: Rename the source files and apply the mechanical renames**

```bash
cd /Users/lukekeith/www/makeready
rename_ref() { ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); o=File.expand_path(ARGV[0]); n=File.expand_path(ARGV[1]); r=p.files.find{|f| f.real_path.to_s==o} or abort("not in project: #{ARGV[0]}"); r.path=r.path.sub(/[^\/]+\z/, File.basename(n)); r.name=File.basename(n) if r.name; p.save' "$1" "$2" && git mv "$1" "$2"; }
G=iphone/MakeReady/UI2/Containers/Groups
rename_ref $G/CoverFramingMath.swift $G/ImageFramingMath.swift
rename_ref $G/EditGroupCoverModel.swift $G/ImageFramingModel.swift
perl -pi -e 's/\bCoverFramingMath\b/ImageFramingMath/g; s/\bEditGroupCoverModel\b/ImageFramingModel/g; s/\bCoverEditSource\b/ImageEditSource/g; s/\bCoverFramingCanvas\b/ImageFramingCanvas/g; s/\bCoverFraming\b/ImageFraming/g' \
  $G/ImageFramingMath.swift $G/ImageFramingModel.swift $G/CoverImageRendering.swift $G/EditGroupCoverContainer.swift \
  iphone/MakeReady/UI2/Shell/UI2ShellModel.swift
```

In `ImageFramingMath.swift` delete lines 13-14 (`/// D20: the cover's aspect, 16:9.` and `static let frameAspect …`) and change the doc comment's first line to `/// image-framing-editor D1 (group-cover-image D5/D11/D20/D21/D25): the framing geometry for any frame aspect, pure. Frame and image sizes are in`.

In `GroupModels.swift` rename the struct (lines 15-55): `struct CoverFraming:` → `struct ImageFraming:`, `static let identity = CoverFraming(` → `static let identity = ImageFraming(`, the doc comment's first line → `/// image-framing-editor D1 (group-cover-image D11/D21): how an image was framed — \`scale\` relative to the zoom floor (1…8),`, and add directly below the struct's closing brace:

```swift

/// image-framing-editor D1: the group cover's name for the shared framing (stored on the group and,
/// as `profilePictureFraming`, on a member).
typealias CoverFraming = ImageFraming
```

- [ ] **Step 6: `ImageFramingModel` takes the output size, the failure text and a URL-returning save** — in `ImageFramingModel.swift` replace everything from line 1 through the end of `init` (old lines 1-56) with:

```swift
import Observation
import UIKit

/// image-framing-editor D1 (group-cover-image §iphone Edit cover): where the framing editor opens from.
enum ImageEditSource: Hashable {
    /// A photo just picked, already upright and ≤ 2400px (group-cover-image D3/D6, image-framing-editor D7).
    case newPick(UIImage)
    /// The stored original (or the image itself) at its stored framing (group-cover-image D7, image-framing-editor D5).
    case stored
}

/// image-framing-editor D1: one framing editor's state for every framed image (today the group cover
/// at 16:9 and the member avatar at 1:1) — group-cover-image D5/D6/D7/D13/D20–D26 unchanged. The
/// frame's size (so its aspect), the output pixel size and the failure text are inputs; each image
/// kind supplies its own save, which returns the new rendered URL. Gestures accumulate on a
/// committed base (pinch × scale, rotate + degrees, pan + points); while one is active the image may
/// go past the coverage limit with rubber-band resistance, and release settles it — the ±3° snap,
/// then the nearest covering framing (D25). Flip and Rotate 90° commit at once, re-applying the
/// floor. Save renders what the frame shows at `outputSize` and maps the result to an outcome the container routes.
@MainActor
@Observable
final class ImageFramingModel {
    /// image-framing-editor D12: `.forbidden` is a 403 — each container routes it (the group cover keeps its banner).
    enum SaveOutcome: Equatable { case saved, ignored, unauthorized, forbidden, gone, failed(String) }

    /// D24: a rotation this small is the jitter of a pinch, not a twist — the readout stays hidden.
    static let twistThreshold: Double = 1

    let image: UIImage
    let isNewPick: Bool
    let frameSize: CGSize
    /// image-framing-editor D1: the rendered image's pixel size (group cover 1200×675, avatar 512×512).
    let outputSize: CGSize
    /// image-framing-editor D1: the banner text the container shows when a save fails.
    let saveFailedMessage: String
    private(set) var framing: ImageFraming
    private(set) var isSaving = false
    /// D30: any gesture (twist or dial) is in progress — the rule-of-thirds grid shows.
    private(set) var isGestureActive = false
    /// D30: the current gesture has twisted (or the dial is turning) at least `twistThreshold` — the degree readout shows.
    private(set) var isTwisting = false
    private var base: ImageFraming
    /// D22: the framing the page opened at; a re-edit is savable only once it differs.
    @ObservationIgnored private let opened: ImageFraming
    /// D7: false when there is no stored original, so `image` IS the current image and Save stores it as one.
    @ObservationIgnored private let hasStoredOriginal: Bool
    @ObservationIgnored private let send: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String

    init(image: UIImage, framing: ImageFraming, isNewPick: Bool, hasStoredOriginal: Bool,
         frameSize: CGSize, outputSize: CGSize, saveFailedMessage: String,
         save: @escaping @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String) {
        self.image = image
        self.isNewPick = isNewPick
        self.hasStoredOriginal = hasStoredOriginal
        self.frameSize = frameSize
        self.outputSize = outputSize
        self.saveFailedMessage = saveFailedMessage
        let start = ImageFramingMath.clamped(framing, image: image.size, frame: frameSize)
        self.framing = start
        self.base = start
        self.opened = start
        self.send = save
    }
```

Replace the `save()` method (old lines 146-167) with:

```swift
    /// D13: one save at a time; success seeds Ui2ImageCache under the new URL.
    func save() async -> SaveOutcome {
        guard !isSaving else { return .ignored }
        // D5/D25: Done mid-gesture saves what release would settle to — snapped and covered.
        framing = ImageFramingMath.settle(framing, image: image.size, frame: frameSize)
        base = framing
        isGestureActive = false
        isTwisting = false
        isSaving = true
        defer { isSaving = false }
        let rendered = CoverImageRendering.render(image, framing: framing, size: outputSize)
        do {
            let original = (isNewPick || !hasStoredOriginal) ? image : nil
            let url = try await send(rendered, framing, original)
            if let seeded = URL(string: url) { Ui2ImageCache.shared.seed(rendered, for: seeded) }
            return .saved
        } catch {
            if AuthStatusPolicy.shouldSignOut(after: error) { return .unauthorized }
            if let http = error as? APIHTTPError, http.status == 403 { return .forbidden }
            if let http = error as? APIHTTPError, http.status == 404 { return .gone }
            return .failed(error.localizedDescription)
        }
    }
```

Delete `opening(group:)` and its doc comment (old lines 169-178) — it moves to `EditGroupCoverContainer` in Step 9. Leave every other method exactly as it is.

- [ ] **Step 7: The render takes its size; the viewer takes its label**

`CoverImageRendering.swift` lines 4-34 become:

```swift
/// group-cover-image D12: the phone renders exactly what the editor's frame shows; D3: a pick is
/// made upright and ≤ 2400px before the editor opens (memory, and the upload's body size).
/// image-framing-editor D1: the output size is the caller's (group cover 1200×675, avatar 512×512).
enum CoverImageRendering {
    /// D3 / D10: the original's longest side.
    static let originalMaxPixels: CGFloat = 2400

    /// D12/D21: the framed image at `size`, scale 1, opaque — the image flipped, then turned
    /// counter-clockwise by its quarter turns, then rotated by the fine angle, then scaled and offset.
    /// `UIImage.draw(in:)` applies the image's orientation (`APIClient.resizeImageIfNeeded` does not).
    static func render(_ image: UIImage, framing: ImageFraming, size: CGSize) -> UIImage {
        let frame = size
        let f = ImageFramingMath.clamped(framing, image: image.size, frame: frame)
        let scale = ImageFramingMath.absoluteScale(f, image: image.size, frame: frame)
        let center = ImageFramingMath.imageCenter(f, frame: frame)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: frame, format: format).image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: frame.width / 2 + center.x, y: frame.height / 2 + center.y)
            cg.rotate(by: CGFloat(f.rotation * .pi / 180))
            // Context transforms apply to the drawing innermost-last: this turn acts before the fine
            // rotation, and the mirror below before the turn. Negative = counter-clockwise (y down).
            cg.rotate(by: -CGFloat(f.quarterTurns) * .pi / 2)
            if f.flipped { cg.scaleBy(x: -1, y: 1) }
            let w = image.size.width * scale, h = image.size.height * scale
            image.draw(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        }
    }
```

(`uprightDownsampled` below it is unchanged.)

`CoverViewerOverlay.swift`: add `let accessibilityLabel: String` between `let url: String` and `let onClose: () -> Void` (line 7), change line 32 to `.accessibilityLabel(accessibilityLabel)`, and replace lines 58-81 with:

```swift
private struct CoverViewerPresentation: ViewModifier {
    let url: String?
    let accessibilityLabel: String
    let onClose: () -> Void
    @Environment(\.ui2HostsOverlays) private var hosted

    func body(content: Content) -> some View {
        let layer = url.map { CoverViewerOverlay(url: $0, accessibilityLabel: accessibilityLabel, onClose: onClose) }
        if hosted {
            content.hostedOverlay(layer.map { UI2HostedOverlay(view: AnyView($0)) })
        } else {
            content.overlay { if let layer { layer } }
        }
    }
}

extension View {
    /// D8: presents the viewer while `url` is non-nil, through the shell's `.ui2OverlayHost()`
    /// (crossfade, the filter-menu default). Present it only after any C-066 menu has finished
    /// sliding out — the host keeps the first presented overlay (`UI2HostedOverlayKey` and
    /// `hostedOverlay(_:)` in FilterMenuOverlay.swift). image-framing-editor D13: the image's
    /// accessibility label is the caller's ("Group cover", "Profile photo").
    func coverViewerPresentation(url: String?, accessibilityLabel: String, onClose: @escaping () -> Void) -> some View {
        modifier(CoverViewerPresentation(url: url, accessibilityLabel: accessibilityLabel, onClose: onClose))
    }
}
```

`GroupDetailContainer.swift:104` becomes `.coverViewerPresentation(url: viewerURL, accessibilityLabel: "Group cover", onClose: { viewerURL = nil })`.

- [ ] **Step 8: The canvas moves to its own file with a label input** — cut `CoverFramingCanvas` (now `ImageFramingCanvas` after the perl, `EditGroupCoverContainer.swift` lines 225-277) out of that file and create `iphone/MakeReady/UI2/Containers/Groups/ImageFramingCanvas.swift`:

```swift
import SwiftUI

/// image-framing-editor D1 (group-cover-image D5/D25/D30): the framed image and its three
/// simultaneous gestures, placed in the edit screen's canvas slot for any framed image. It fills the
/// whole canvas area, clipped to that slot but not to `frame` (the screen dims what lies outside
/// `frame`), and draws the image as `CoverImageRendering` renders it — mirrored, turned, rotated,
/// scaled, offset — against `frame`. The model clamps every change; release springs back to coverage (D25).
struct ImageFramingCanvas: View {
    let model: ImageFramingModel
    /// The screen's frame rect, in this view's coordinates.
    let frame: CGRect
    /// image-framing-editor D1: the caller's label ("Cover framing", "Photo framing").
    let accessibilityLabel: String

    /// D25: the spring back to the nearest covering framing on release.
    static let settle = Animation.spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        let f = model.framing
        let scale = ImageFramingMath.absoluteScale(f, image: model.image.size, frame: frame.size)
        let center = ImageFramingMath.imageCenter(f, frame: frame.size)
        ZStack(alignment: .topLeading) {
            Color.clear
            Image(uiImage: model.image)
                .resizable()
                .frame(width: model.image.size.width * scale, height: model.image.size.height * scale)
                .scaleEffect(x: f.flipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(-90 * Double(f.quarterTurns)))   // D21: counter-clockwise turns
                .rotationEffect(.degrees(f.rotation))
                .position(x: frame.midX + center.x, y: frame.midY + center.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // D30: clipped to the canvas slot, not the frame — the screen dims the overflow inside the
        // slot, and nothing paints over the header or the toolbar.
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            SimultaneousGesture(
                SimultaneousGesture(MagnifyGesture(), RotateGesture()),
                // pan-ok: the canvas move pans the image in any direction, not a sideways scroll.
                DragGesture(minimumDistance: 0)
            )
            .onChanged { value in
                model.updateGesture(magnification: value.first?.first?.magnification ?? 1,
                                    rotationDegrees: value.first?.second?.rotation.degrees ?? 0,
                                    translation: value.second?.translation ?? .zero)
            }
            .onEnded { _ in
                withAnimation(Self.settle) { model.endGesture() }
            }
        )
        .allowsHitTesting(!model.isSaving)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Pinch to zoom, rotate with two fingers, drag to move")
    }
}
```

Register it (sibling = a file already in the project's same group; target `MakeReady`), then mirror into the capture target:

```bash
cd /Users/lukekeith/www/makeready
ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' \
  iphone/MakeReady/UI2/Containers/Groups/ImageFramingCanvas.swift iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift MakeReady
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check
```

→ the `--check` run exits 0 (nothing out of sync).

- [ ] **Step 9: The group cover supplies its own geometry, text, opening and save** — in `EditGroupCoverContainer.swift`:

Directly after `enum CancelAction: Equatable { case confirmDiscard, pop, ignore }` (line 16) add:

```swift

    /// group-cover-image D20 — image-framing-editor D1: the cover's frame is 16:9; the shared editor
    /// takes it as an input, and no other 16:9 constant remains.
    static let frameAspect: CGFloat = 16.0 / 9.0
    /// group-cover-image D12/D20: the rendered cover, 1200×675.
    static let renderSize = CGSize(width: 1200, height: 675)
    /// group-cover-image D13: the banner a failed save shows.
    static let saveFailedMessage = "Couldn't save the cover"
    /// The canvas's accessibility label.
    static let canvasLabel = "Cover framing"

    /// group-cover-image D7: Edit image reopens the original at its framing; a cover with no original
    /// opens the cover itself at identity; no cover → nil (the menu is not offered then, D2).
    /// `hasOriginal` is false for the cover fallback: the caller passes it on as `hasStoredOriginal`.
    static func opening(group: UserGroup) -> (url: String, framing: ImageFraming, hasOriginal: Bool)? {
        if let original = group.coverOriginalUrl, !original.isEmpty {
            return (original, group.coverFraming ?? .identity, true)
        }
        if let cover = group.coverImageUrl, !cover.isEmpty { return (cover, .identity, false) }
        return nil
    }
```

In `immediateOpening` and `prepare()` replace `ImageFramingModel.opening(group: group)` with `Self.opening(group: group)` (two places). In `route(_:)` add the case `case .forbidden: return .banner   // image-framing-editor D12: a 403 shows the banner, as before`. In the `canvas` view builder replace the canvas line with `ImageFramingCanvas(model: model, frame: frameRect, accessibilityLabel: Self.canvasLabel)`. Replace `makeModelIfReady()`'s first lines (the `save` closure and the `let built = …` call) with:

```swift
        guard model == nil, let opening, frameRect.width > 0, frameRect.height > 0 else { return }
        let save: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String = { [groupId] rendered, framing, original in
            try await GroupActions().saveCover(groupId: groupId, rendered: rendered, framing: framing, original: original).coverImageUrl
        }
        let built = ImageFramingModel(image: opening.image, framing: opening.framing,
                                      isNewPick: opening.isNewPick, hasStoredOriginal: opening.hasStoredOriginal,
                                      frameSize: frameRect.size, outputSize: Self.renderSize,
                                      saveFailedMessage: Self.saveFailedMessage, save: save)
```

(the `model = built` and back-swipe lines after it stay). In `save()` replace the `.banner` case with:

```swift
        case .banner:
            // D13: the friendly text is the model's; a 403 (image-framing-editor D12) carries no server text of its own.
            let message: String
            if case let .failed(text) = outcome { message = text } else { message = model.saveFailedMessage }
            AppState.shared.recordError(APIError.serverError(message), context: "EditGroupCoverContainer.save", surface: true,
                                        friendlyMessage: model.saveFailedMessage,
                                        retry: { Task { await save() } })
```

Finally make sure the file no longer contains the canvas struct (moved in Step 8) and `grep -rn "CoverFramingMath\|EditGroupCoverModel\|CoverEditSource\|CoverFramingCanvas\|renderSize\b" iphone/MakeReady` prints only `EditGroupCoverContainer.renderSize` uses.

- [ ] **Step 10: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS. The pass count is Step 1's plus 7 new tests (3 math, 1 render, 2 model, 1 container); `testFrameIs16By9` and `testOpening` moved class, they were not added. Re-run the Step 1 grep against the new names and confirm the 89 group methods are all present:

```bash
grep -c "func test" iphone/MakeReadyCaptureTests/{ImageFramingMathTests,CoverImageRenderingTests,ImageFramingModelTests,EditGroupCoverContainerTests,CoverViewerOverlayTests,GroupCoverDecodingTests,GroupDetailCoverTapTests,GroupSaveCoverTests}.swift
```

→ 19 · 12 · 29 · 13 · 5 · 9 · 4 · 5. Then `npm run ios:build-check` → PASS, and `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 11: Commit** — stage only this task's files (`git add iphone/MakeReady.xcodeproj/project.pbxproj iphone/MakeReady/UI2 iphone/MakeReady/State/Models/GroupModels.swift iphone/MakeReadyCaptureTests`; never `iphone/MakeReadyUI/` or `iphone/MakeReady/Info.plist`) → `refactor(image-framing-editor): one aspect-parameterised framing editor, the group cover moved onto it`

### Task 6: Member avatar state — the two new fields, a status-keeping multipart call, `MemberActions.saveAvatar`
App: iphone
Phase: 3
Recipe: SPEC §iphone "State" · D5, D7, D8, D12 · SPEC §Contract rows 1–2 · iphone/.claude/CLAUDE.md (Actions)

**Files:**
- Modify: `iphone/MakeReady/State/Models/MemberModels.swift:109-151` (`MemberDetail` + its decoder)
- Modify: `iphone/MakeReady/State/API/APIClient.swift:275-324` (new `uploadWithStatus` after `upload`), `:449-460` (protocol requirement)
- Modify: `iphone/MakeReadyCaptureTests/StubAPIClient.swift:37-42, 101-103` (record + answer the upload)
- Modify: `iphone/MakeReady/State/Actions/MemberActions.swift:1` (`import UIKit`), new `// MARK: - Avatar` section before `// MARK: - Helpers` (`:162`)
- Test: `iphone/MakeReadyCaptureTests/MemberModelsTests.swift` (append), `iphone/MakeReadyCaptureTests/MemberSaveAvatarTests.swift` (new — register in `MakeReadyCaptureTests`, sibling `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`)

**Interfaces:**
- Consumes: Task 5's `ImageFraming` (`requestBody`, `Codable`); §Contract row 1 (`POST /api/members/:memberId/avatar`, multipart `file` · `framing` (JSON string) · `original`; response `{success, data: {url, originalUrl, framing}}`; errors 400/401/403/404/413/500) and row 2 (`GET /api/members/:memberId` adds `profilePictureOriginalUrl: string|null`, `profilePictureFraming: framing|null`)
- Produces:
  - `MemberDetail.profilePictureOriginalUrl: String?`, `MemberDetail.profilePictureFraming: ImageFraming?` (last two stored properties; memberwise init gains them last, defaulted nil)
  - `APIClientProtocol.uploadWithStatus(endpoint: String, boundary: String, body: Data, timeout: TimeInterval) async throws -> Data` — POST multipart; a non-2xx throws `APIClient.statusError` (`APIError.unauthorized` for 401, else `APIHTTPError(status:message:)`)
  - `StubAPIClient.lastUpload: (endpoint: String, boundary: String, body: Data, timeout: TimeInterval)?`; the stub answers `uploadWithStatus` from `stub("POST", endpoint, json:)`
  - `MemberActions.avatarSaveTimeout: TimeInterval = 120`
  - `static func MemberActions.avatarBody(boundary: String, rendered: Data, framing: ImageFraming, original: Data?) throws -> Data`
  - `@MainActor func MemberActions.saveAvatar(memberId: String, rendered: UIImage, framing: ImageFraming, original: UIImage?) async throws -> String` — returns the new `profilePicture` URL; throws the transport error untouched (401 → `APIError.unauthorized`, which `AuthStatusPolicy.shouldSignOut(after:)` reads; 403/404 → `APIHTTPError`); on success patches `memberDetails[memberId]` (`profilePicture`, `profilePictureOriginalUrl`, `profilePictureFraming`) and `profilePicture` on every `orgMembersByOrgId[*].members` row with that id (D12)

- [ ] **Step 1: Write the failing decode tests** — append inside `MemberModelsTests` (before its closing brace):

```swift
    // MARK: - image-framing-editor SC1/SC2 (§iphone State)

    func testMemberDetailDecodesTheAvatarOriginalAndFraming() throws {
        let json = #"{"success":true,"data":{"id":"m1","profilePicture":"https://img/a.webp","profilePictureOriginalUrl":"https://img/o.jpeg","profilePictureFraming":{"scale":2,"rotation":15,"offsetX":0.25,"offsetY":-0.5,"flipped":true,"quarterTurns":1}}}"#
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, json).data)
        XCTAssertEqual(d.profilePictureOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(d.profilePictureFraming, ImageFraming(scale: 2, rotation: 15, offsetX: 0.25, offsetY: -0.5, flipped: true, quarterTurns: 1))
    }

    /// A server without SC1/SC2 (and the in-memory store written before them) still decodes.
    func testMemberDetailWithoutTheAvatarFieldsDecodesAsNil() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","profilePicture":null}}"#).data)
        XCTAssertNil(d.profilePictureOriginalUrl)
        XCTAssertNil(d.profilePictureFraming)
        let nulls = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","profilePictureOriginalUrl":null,"profilePictureFraming":null}}"#).data)
        XCTAssertNil(nulls.profilePictureFraming)
    }

    /// A bad stored framing never fails the member decode.
    func testBadAvatarFramingDecodesAsNilAndKeepsTheMember() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","firstName":"Tony","profilePictureFraming":{"scale":"big"}}}"#).data)
        XCTAssertNil(d.profilePictureFraming)
        XCTAssertEqual(d.firstName, "Tony")
    }

    /// The memory-only store round-trips the two fields through Codable.
    func testMemberDetailRoundTripsTheAvatarFields() throws {
        let f = ImageFraming(scale: 3, rotation: -10, offsetX: 0, offsetY: 0.5)
        let d = MemberDetail(id: "m1", profilePictureOriginalUrl: "https://img/o.jpeg", profilePictureFraming: f)
        let again = try JSONDecoder.apiDecoder.decode(MemberDetail.self, from: JSONEncoder().encode(d))
        XCTAssertEqual(again.profilePictureOriginalUrl, "https://img/o.jpeg")
        XCTAssertEqual(again.profilePictureFraming, f)
    }
```

- [ ] **Step 2: Write the failing Action tests** — create `iphone/MakeReadyCaptureTests/MemberSaveAvatarTests.swift`:

```swift
import XCTest
import UIKit
@testable import MakeReady

/// image-framing-editor D8/D12: saveAvatar posts the D8 multipart body through uploadWithStatus,
/// keeps the HTTP status on failure, and on success patches the member detail and every Members
/// list row of that member.
@MainActor
final class MemberSaveAvatarTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let endpoint = "/api/members/m1/avatar"
    private let framing = ImageFraming(scale: 2, rotation: 15, offsetX: 0.25, offsetY: -0.5, flipped: true, quarterTurns: 1)

    override func setUp() {
        super.setUp()
        StatePersistence.shared.clear()
        state = AppState()
        api = StubAPIClient()
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Tony", profilePicture: "https://img/old.webp"))
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [
            OrgMemberListItem(id: "m1", profilePicture: "https://img/old.webp"),
            OrgMemberListItem(id: "m2", profilePicture: "https://img/m2.webp")
        ])
        state.orgMembersByOrgId["org2"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m1")])
    }

    override func tearDown() {
        StatePersistence.shared.clear()
        super.tearDown()
    }

    private func image(_ size: CGSize = CGSize(width: 40, height: 40)) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func actions() -> MemberActions { MemberActions(api: api, state: state) }

    private func stubSuccess() {
        api.stub("POST", endpoint, json: #"{"success":true,"data":{"url":"https://img/new.webp","originalUrl":"https://img/new-original.jpeg","framing":{"scale":2,"rotation":15,"offsetX":0.25,"offsetY":-0.5,"flipped":true,"quarterTurns":1}}}"#)
    }

    /// The parts of a multipart body by field name: each part's header block and payload.
    private func parts(_ body: Data, boundary: String) -> [String: (headers: String, payload: Data)] {
        var result: [String: (headers: String, payload: Data)] = [:]
        let delimiter = Data("--\(boundary)".utf8)
        let headerEnd = Data("\r\n\r\n".utf8)
        var cursor = body.startIndex
        while let start = body.range(of: delimiter, in: cursor..<body.endIndex),
              let next = body.range(of: delimiter, in: start.upperBound..<body.endIndex) {
            let chunk = Data(body[start.upperBound..<next.lowerBound])     // "\r\n<headers>\r\n\r\n<payload>\r\n"
            if let split = chunk.range(of: headerEnd), chunk.count >= split.upperBound + 2 {
                let headers = String(decoding: chunk.subdata(in: 0..<split.lowerBound), as: UTF8.self)
                let payload = chunk.subdata(in: split.upperBound..<(chunk.count - 2))
                if let name = headers.components(separatedBy: "name=\"").dropFirst().first?.components(separatedBy: "\"").first {
                    result[name] = (headers, payload)
                }
            }
            cursor = next.lowerBound
        }
        return result
    }

    /// D8: a new pick sends `framing` (a JSON string), `file` and `original`, each file a JPEG part.
    func testNewPickSendsFramingFileAndOriginal() async throws {
        stubSuccess()
        _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: image(CGSize(width: 80, height: 60)))
        let upload = try XCTUnwrap(api.lastUpload)
        XCTAssertEqual(upload.endpoint, endpoint)
        XCTAssertEqual(upload.timeout, 120)
        let p = parts(upload.body, boundary: upload.boundary)
        XCTAssertEqual(Set(p.keys), ["framing", "file", "original"])
        for name in ["file", "original"] {
            let part = try XCTUnwrap(p[name])
            XCTAssertTrue(part.headers.contains("Content-Type: image/jpeg"), name)
            XCTAssertTrue(part.headers.contains("filename=\""), name)
            XCTAssertEqual(Array(part.payload.prefix(2)), [0xFF, 0xD8], name)            // JPEG SOI
        }
        let framingPart = try XCTUnwrap(p["framing"])
        XCTAssertFalse(framingPart.headers.contains("Content-Type"))                      // a plain text field
        XCTAssertEqual(try JSONDecoder().decode(ImageFraming.self, from: framingPart.payload), framing)
    }

    /// D8: a re-edit of a stored original sends no `original`; the body closes with the final boundary.
    func testReEditSendsNoOriginal() async throws {
        stubSuccess()
        _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
        let upload = try XCTUnwrap(api.lastUpload)
        XCTAssertEqual(Set(parts(upload.body, boundary: upload.boundary).keys), ["framing", "file"])
        XCTAssertTrue(String(decoding: upload.body.suffix(64), as: UTF8.self).hasSuffix("--\(upload.boundary)--\r\n"))
    }

    /// D12: the returned fields land on the detail and on every Members-list row of the member.
    func testSuccessPatchesTheDetailAndEveryListRow() async throws {
        stubSuccess()
        let url = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: image())
        XCTAssertEqual(url, "https://img/new.webp")
        let d = try XCTUnwrap(state.memberDetails["m1"])
        XCTAssertEqual(d.profilePicture, "https://img/new.webp")
        XCTAssertEqual(d.profilePictureOriginalUrl, "https://img/new-original.jpeg")
        XCTAssertEqual(d.profilePictureFraming, framing)
        XCTAssertEqual(d.firstName, "Tony")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.members.map(\.profilePicture), ["https://img/new.webp", "https://img/m2.webp"])
        XCTAssertEqual(state.orgMembersByOrgId["org2"]?.members.first?.profilePicture, "https://img/new.webp")
    }

    /// D12: 403 and 404 keep their status for the model's outcome; nothing is written.
    func testForbiddenAndNotFoundKeepTheirStatusAndWriteNothing() async {
        for status in [403, 404] {
            api.errorFor = { _, _ in APIHTTPError(status: status, message: "no") }
            do {
                _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
                XCTFail("expected a throw for \(status)")
            } catch {
                XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: status, message: "no"))
            }
        }
        XCTAssertEqual(state.memberDetails["m1"]?.profilePicture, "https://img/old.webp")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.members.first?.profilePicture, "https://img/old.webp")
    }

    /// ui2-shell D27: a 401 surfaces as the error the sign-out policy reads.
    func testUnauthorizedIsTheSignOutError() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        do {
            _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertTrue(AuthStatusPolicy.shouldSignOut(after: error))
        }
    }

    /// A 2xx without `success`/`data.url` is a failure, and writes nothing.
    func testUnsuccessfulBodyThrowsAndWritesNothing() async {
        api.stub("POST", endpoint, json: #"{"success":false,"error":"nope"}"#)
        do {
            _ = try await actions().saveAvatar(memberId: "m1", rendered: image(), framing: framing, original: nil)
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error.localizedDescription, APIError.serverError("nope").localizedDescription)
        }
        XCTAssertEqual(state.memberDetails["m1"]?.profilePicture, "https://img/old.webp")
    }

    /// D8: the avatar route's 413 keeps its status through the shared mapping `uploadWithStatus` uses.
    func testStatusMappingKeepsA413() {
        let data = Data(#"{"error":"File too large"}"#.utf8)
        XCTAssertEqual(APIClient.statusError(status: 413, data: data) as? APIHTTPError, APIHTTPError(status: 413, message: "File too large"))
        XCTAssertNil(APIClient.statusError(status: 200, data: data))
    }
}
```

Register it (repo root):

```bash
ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' \
  iphone/MakeReadyCaptureTests/MemberSaveAvatarTests.swift iphone/MakeReadyCaptureTests/MemberActionsTests.swift MakeReadyCaptureTests
```

- [ ] **Step 3: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile, `value of type 'MemberDetail' has no member 'profilePictureOriginalUrl'` / `value of type 'MemberActions' has no member 'saveAvatar'`

- [ ] **Step 4: The two fields** — in `MemberModels.swift`, in `struct MemberDetail` after `var organizations: [MemberDetailOrganization] = []` (line 127):

```swift
    var profilePictureOriginalUrl: String?   // image-framing-editor SC1 (D5): the full photo Edit reopens
    var profilePictureFraming: ImageFraming? // image-framing-editor SC2 (D8): the framing the avatar was rendered with
```

and in `init(from:)` after the `organizations = …` line (149):

```swift
        profilePictureOriginalUrl = try c.decodeIfPresent(String.self, forKey: .profilePictureOriginalUrl)
        // image-framing-editor §iphone State: a bad stored framing decodes as nil, never failing the member.
        profilePictureFraming = (try? c.decodeIfPresent(ImageFraming.self, forKey: .profilePictureFraming)) ?? nil
```

Update the struct's doc line to `/// \`GET /api/members/:memberId\` — the existing member columns plus SC1–SC3 and SC8, and image-framing-editor SC1–SC2.`

- [ ] **Step 5: `uploadWithStatus`** — in `APIClient.swift` directly after `upload(endpoint:boundary:body:timeout:)` (ends line 324):

```swift

    /// image-framing-editor §iphone State: a multipart POST whose non-2xx failure keeps its HTTP
    /// status (`statusError` — 401 → `.unauthorized`, else `APIHTTPError`); `upload` above folds every
    /// status into a `serverError`. Opt-in: `MemberActions.saveAvatar` (D8, 120s).
    func uploadWithStatus(endpoint: String, boundary: String, body: Data, timeout: TimeInterval) async throws -> Data {
        guard getSessionCookie() != nil else { throw APIError.notAuthenticated }
        guard let url = URL(string: "\(baseURL)\(endpoint)") else { throw APIError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        if let cookie = getSessionCookie() {
            request.setValue("connect.sid=\(cookie)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = body
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if let error = Self.statusError(status: http.statusCode, data: data) { throw error }
        return data
    }
```

In `protocol APIClientProtocol` after the `upload(...)` requirement (line 458) add:

```swift
    /// image-framing-editor: as `upload`, but a non-2xx throws `statusError` (the status survives).
    func uploadWithStatus(endpoint: String, boundary: String, body: Data, timeout: TimeInterval) async throws -> Data
```

In `StubAPIClient.swift` add under `var calls` (line 42):

```swift

    /// The last `uploadWithStatus` call — its body is multipart `Data`, which `RecordedCall.body` cannot hold.
    private var recordedUpload: (endpoint: String, boundary: String, body: Data, timeout: TimeInterval)?
    var lastUpload: (endpoint: String, boundary: String, body: Data, timeout: TimeInterval)? { callsLock.withLock { recordedUpload } }
```

and after `upload(...)` (line 103):

```swift

    /// Recorded (`lastUpload`) and answered like a POST: `stub("POST", endpoint, json:)`, or an
    /// `APIHTTPError` from `errorFor` to play a status.
    func uploadWithStatus(endpoint: String, boundary: String, body: Data, timeout: TimeInterval) async throws -> Data {
        callsLock.withLock { recordedUpload = (endpoint, boundary, body, timeout) }
        return try await request(endpoint: endpoint, method: "POST", body: nil, timeout: timeout)
    }
```

(`grep -rn "APIClientProtocol {" iphone --include='*.swift'` lists the conformers; today only `APIClient` and `StubAPIClient`.)

- [ ] **Step 6: `MemberActions.saveAvatar`** — change line 1 of `MemberActions.swift` to `import UIKit` (it brings Foundation), and insert before `// MARK: - Helpers`:

```swift
    // MARK: - Avatar (image-framing-editor)

    /// image-framing-editor D8/D12: the avatar upload's long timeout (two JPEGs, up to 10MB each).
    static let avatarSaveTimeout: TimeInterval = 120

    /// D8: the multipart body — `framing` (the six-key framing as a JSON string field), `file` (the
    /// rendered avatar) and, when given, `original`; each file part `Content-Type: image/jpeg`.
    static func avatarBody(boundary: String, rendered: Data, framing: ImageFraming, original: Data?) throws -> Data {
        let json = try JSONSerialization.data(withJSONObject: framing.requestBody, options: [.sortedKeys])
        var body = Data()
        func text(_ s: String) { body.append(Data(s.utf8)) }
        func file(_ name: String, _ filename: String, _ data: Data) {
            text("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
            text("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            text("\r\n")
        }
        text("--\(boundary)\r\nContent-Disposition: form-data; name=\"framing\"\r\n\r\n")
        body.append(json)
        text("\r\n")
        file("file", "avatar.jpg", rendered)
        if let original { file("original", "original.jpg", original) }
        text("--\(boundary)--\r\n")
        return body
    }

    /// D7/D8/D12: upload the rendered 512×512 avatar (JPEG 0.9) with its framing — and the original
    /// (JPEG 0.9) on a new pick or a first edit — then write the returned fields into `memberDetails`
    /// and the avatar URL into every Members-list row of the member (memory-only stores; group-detail
    /// member rows refresh on their next load). Throws the transport error untouched: 401 →
    /// `APIError.unauthorized` (the caller signs out), 403/404 → `APIHTTPError`. A sign-out while
    /// in flight writes nothing. Returns the new `profilePicture` URL.
    @MainActor
    func saveAvatar(memberId: String, rendered: UIImage, framing: ImageFraming, original: UIImage?) async throws -> String {
        struct Payload: Decodable {
            let url: String?
            let originalUrl: String?
            let framing: ImageFraming?
        }
        struct Response: Decodable {
            let success: Bool
            let data: Payload?
            let error: String?
        }
        guard let renderedJPEG = rendered.jpegData(compressionQuality: 0.9) else {
            throw APIError.serverError("Couldn't encode the photo")
        }
        var originalJPEG: Data?
        if let original {
            guard let data = original.jpegData(compressionQuality: 0.9) else {
                throw APIError.serverError("Couldn't encode the original photo")
            }
            originalJPEG = data
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = try Self.avatarBody(boundary: boundary, rendered: renderedJPEG, framing: framing, original: originalJPEG)
        let generation = state.initialLoad.generation
        let data = try await api.uploadWithStatus(endpoint: "/api/members/\(memberId)/avatar", boundary: boundary,
                                                  body: body, timeout: Self.avatarSaveTimeout)
        let response = try JSONDecoder.apiDecoder.decode(Response.self, from: data)
        guard response.success, let url = response.data?.url, !url.isEmpty else {
            throw APIError.serverError(response.error ?? "Failed to save the photo")
        }
        guard state.initialLoad.isCurrent(generation) else { return url }
        state.memberDetails.update(memberId) {
            $0.profilePicture = url
            $0.profilePictureOriginalUrl = response.data?.originalUrl
            $0.profilePictureFraming = response.data?.framing
        }
        for (orgId, var directory) in state.orgMembersByOrgId where directory.members.contains(where: { $0.id == memberId }) {
            for index in directory.members.indices where directory.members[index].id == memberId {
                directory.members[index].profilePicture = url
            }
            state.orgMembersByOrgId[orgId] = directory
        }
        return url
    }

```

- [ ] **Step 7: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the 4 new `MemberModelsTests`, the 7 `MemberSaveAvatarTests`, and every existing test); `npm run ios:build-check` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 8: Commit** — `feat(image-framing-editor): MemberDetail avatar fields, uploadWithStatus, MemberActions.saveAvatar`

### Task 7: Edit photo — the avatar editor route on the generalised d2m screen, and the group cover passing its own geometry
App: iphone
Phase: 4
Recipe: `/push-page` · `/ios-error-surface` · SPEC D3, D5, D9, D12 · ⚠ build-time risks F1, F3

> **Order note:** this task carries the `UI2Destination.editMemberAvatar` route and its container so that Task 8's avatar tap has a page to push; Task 8 wires the tap, menu, picker and viewer.

> **⚠ build-time risk (F1) — FIRST STEP, before anything else:** the d2m screen `edit-cover` must already be generalised by the owner (D9: inputs `aspect`, `mask` `.rectangle | .circle`, `title`). Check its initializer:
>
> ```bash
> sed -n '/^    init(/,/^    ) {/p' iphone/MakeReadyUI/Screens/Groups/EditCoverScreen.swift | grep -nE "aspect|mask|title"
> ```
>
> Three hits (one each) → proceed, writing the screen call below against the REAL parameter names and mask case names in that file. **No hits (or fewer than three) → STOP and report BLOCKED citing F1** — never write or edit the d2m screen yourself (D9: the build only wires it). Under agent mode the run parks as a human step: "the owner runs the d2m update of screen `edit-cover` (D9: `aspect`, `mask`, `title`, states recaptured at 1:1 circle), then /builder:agent". Tasks 5–6 stay committed.
>
> **F3:** also run `git status --porcelain iphone/MakeReadyUI/Screens/Groups/EditCoverScreen.swift`. If it shows a modification, the owner's hand edit is still uncommitted — do not stage that file, and say so in your report.

**Files:**
- Read first: `iphone/MakeReadyUI/Screens/Groups/EditCoverScreen.swift` (its `init`, the mask type and its cases)
- Create: `iphone/MakeReady/UI2/Containers/Members/EditMemberAvatarContainer.swift` (register in `MakeReady`, sibling `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift`, then `ruby iphone/scripts/capture-targets.rb`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:35-38` (new case)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:158-159` (the destination switch)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift` (the `EditCoverScreen(` call at old `:111-127`; a `title` constant)
- Test: `iphone/MakeReadyCaptureTests/EditMemberAvatarContainerTests.swift` (register in `MakeReadyCaptureTests`, sibling `iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift`)

**Interfaces:**
- Consumes: Task 5 `ImageFramingModel` (init with `outputSize:`/`saveFailedMessage:`, `SaveOutcome` incl. `.forbidden`), `ImageEditSource`, `ImageFraming`, `ImageFramingCanvas(model:frame:accessibilityLabel:)`, `EditGroupCoverContainer.screenState(_:)`, `.cancelAction(hasChanges:isSaving:)`, `.blocksBackSwipe(hasChanges:isSaving:)`, `.discardPops(isSaving:)`, `.discardAction`, `.frameAspect`; Task 6 `MemberActions().saveAvatar(memberId:rendered:framing:original:) -> String`, `MemberDetail.profilePictureOriginalUrl/profilePictureFraming`; `MemberProfileContainer.seedCovers(_:)`
- Produces:
  - `UI2Destination.editMemberAvatar(memberId: String, source: ImageEditSource)`
  - `struct EditMemberAvatarContainer: View { let memberId: String; let source: ImageEditSource }`
  - `enum EditMemberAvatarContainer.Route: Equatable { case pop, signOut, banner, stay }`; `static func route(_ outcome: ImageFramingModel.SaveOutcome) -> Route`
  - `static func EditMemberAvatarContainer.opening(detail: MemberDetail) -> (url: String, framing: ImageFraming, hasOriginal: Bool)?`
  - `EditMemberAvatarContainer.frameAspect: CGFloat = 1`, `.renderSize = CGSize(width: 512, height: 512)`, `.title = "Edit photo"`, `.saveFailedMessage = "Couldn't save the photo"`, `.loadFailedMessage = "Couldn't load the photo"`, `.canvasLabel = "Photo framing"`
  - `EditGroupCoverContainer.title = "Edit cover"`

- [ ] **Step 1: The F1 + F3 checks above** — run both commands; continue only on three hits.

- [ ] **Step 2: Write the failing test** — `iphone/MakeReadyCaptureTests/EditMemberAvatarContainerTests.swift`:

```swift
import XCTest
import UIKit
@testable import MakeReady

/// image-framing-editor D3/D5/D7/D9/D12: the Edit photo page's geometry, opening rule and routing,
/// without the view.
@MainActor
final class EditMemberAvatarContainerTests: XCTestCase {
    /// D12: success, 403 and 404 all pop back to the profile; 401 signs out; anything else is the banner.
    func testOutcomeRoutes() {
        XCTAssertEqual(EditMemberAvatarContainer.route(.saved), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.forbidden), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.gone), .pop)
        XCTAssertEqual(EditMemberAvatarContainer.route(.unauthorized), .signOut)
        XCTAssertEqual(EditMemberAvatarContainer.route(.failed("x")), .banner)
        XCTAssertEqual(EditMemberAvatarContainer.route(.ignored), .stay)
    }

    func testDestinationIsHashableWithAPick() {
        let img = UIImage()
        let a = UI2Destination.editMemberAvatar(memberId: "m1", source: .newPick(img))
        XCTAssertEqual(a, UI2Destination.editMemberAvatar(memberId: "m1", source: .newPick(img)))
        XCTAssertNotEqual(a, UI2Destination.editMemberAvatar(memberId: "m1", source: .stored))
        XCTAssertNotEqual(UI2Destination.editMemberAvatar(memberId: "m1", source: .stored),
                          UI2Destination.editGroupCover(groupId: "m1", source: .stored))
    }

    /// D5: the stored original at its framing; no original → the avatar itself at identity (and the
    /// first save stores it as the original); no avatar → nil.
    func testOpening() {
        let f = ImageFraming(scale: 2, rotation: 10, offsetX: 0.1, offsetY: 0)
        let stored = MemberDetail(id: "m1", profilePicture: "https://img/a.webp",
                                  profilePictureOriginalUrl: "https://img/o.jpeg", profilePictureFraming: f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.url, "https://img/o.jpeg")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.framing, f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: stored)?.hasOriginal, true)

        let noFraming = MemberDetail(id: "m1", profilePicture: "https://img/a.webp", profilePictureOriginalUrl: "https://img/o.jpeg")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: noFraming)?.framing, .identity)

        let legacy = MemberDetail(id: "m1", profilePicture: "https://img/a.webp", profilePictureOriginalUrl: "", profilePictureFraming: f)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.url, "https://img/a.webp")
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.framing, .identity)
        XCTAssertEqual(EditMemberAvatarContainer.opening(detail: legacy)?.hasOriginal, false)

        XCTAssertNil(EditMemberAvatarContainer.opening(detail: MemberDetail(id: "m1", profilePicture: "")))
        XCTAssertNil(EditMemberAvatarContainer.opening(detail: MemberDetail(id: "m1")))
    }

    /// D3/D7/D9: square frame, 512×512 render, "Edit photo"; the group cover keeps 16:9 and "Edit cover".
    func testGeometryAndText() {
        XCTAssertEqual(EditMemberAvatarContainer.frameAspect, 1)
        XCTAssertEqual(EditMemberAvatarContainer.renderSize, CGSize(width: 512, height: 512))
        XCTAssertEqual(EditMemberAvatarContainer.title, "Edit photo")
        XCTAssertEqual(EditMemberAvatarContainer.saveFailedMessage, "Couldn't save the photo")
        XCTAssertEqual(EditGroupCoverContainer.title, "Edit cover")
        XCTAssertEqual(EditGroupCoverContainer.frameAspect, 16.0 / 9.0, accuracy: 1e-12)
    }
}
```

Register it:

```bash
ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' \
  iphone/MakeReadyCaptureTests/EditMemberAvatarContainerTests.swift iphone/MakeReadyCaptureTests/EditGroupCoverContainerTests.swift MakeReadyCaptureTests
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `type 'UI2Destination' has no member 'editMemberAvatar'`

- [ ] **Step 4: The route** — `UI2ShellModel.swift`, after the `editGroupCover` case:

```swift
    /// image-framing-editor D4/D5: the Edit photo page, above the member page — a new pick, or the
    /// stored original (else the avatar itself) at its framing.
    case editMemberAvatar(memberId: String, source: ImageEditSource)
```

`UI2Shell.swift`, after the `.editGroupCover` line:

```swift
        case let .editMemberAvatar(memberId, source): EditMemberAvatarContainer(memberId: memberId, source: source)  // image-framing-editor D9
```

- [ ] **Step 5: Write `EditMemberAvatarContainer.swift`** — the shape is fixed; the `EditCoverScreen(` call uses the d2m file's real names for `aspect`, `mask` and `title` (the values are fixed: `1 · circle · "Edit photo"`):

```swift
import SwiftUI

/// image-framing-editor D3/D5/D9/D12: Edit photo — the generalised d2m `edit-cover` screen at 1:1
/// with the round guide, wired to the shared `ImageFramingModel` (D1). A new pick opens at once; a
/// stored avatar loads its original (`profilePictureOriginalUrl`, else `profilePicture` at identity —
/// D5) first. The model is built once both the image and the screen's frame rect are known, so its
/// `frameSize` is the frame the canvas really draws. Cancel or an edge swipe with a change asks to
/// discard (C-066 "Discard changes" + Done), else pops. Done saves → D12: pop on success (AppState
/// and the image cache already updated), 403/404 → pop to the profile, 401 → sign-out, anything
/// else → the surfaced banner with the page kept. The chrome rules are the group cover's
/// (`EditGroupCoverContainer`, group-cover-image D13/D26/D28/D30) — one copy.
struct EditMemberAvatarContainer: View {
    let memberId: String
    let source: ImageEditSource

    enum Route: Equatable { case pop, signOut, banner, stay }

    /// D3/D9: the frame is square; the screen dims outside the circle inscribed in it.
    static let frameAspect: CGFloat = 1
    /// D7: the rendered avatar, 512×512 (the server keeps its 512px WebP re-encode).
    static let renderSize = CGSize(width: 512, height: 512)
    /// D9: the screen's title.
    static let title = "Edit photo"
    /// D12: the banner a failed save shows.
    static let saveFailedMessage = "Couldn't save the photo"
    /// D5: the banner a stored photo that will not load shows; the page pops.
    static let loadFailedMessage = "Couldn't load the photo"
    /// The canvas's accessibility label.
    static let canvasLabel = "Photo framing"

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D12: this page's veto on the shell's edge swipe.
    @Environment(\.ui2BackSwipeGuard) private var backSwipe
    /// The photo to frame and where it opens — set once it is in hand.
    @State private var opening: Opening?
    /// The screen's frame rect, in the canvas slot's coordinates (`onFrameLayout`).
    @State private var frameRect: CGRect = .zero
    @State private var model: ImageFramingModel?
    /// D12: the C-066 "Discard changes" confirmation is up.
    @State private var discardMenuOpen = false

    private struct Opening {
        let image: UIImage
        let framing: ImageFraming
        let isNewPick: Bool
        let hasStoredOriginal: Bool
    }

    /// Cache-first: a new pick, or a stored photo already in Ui2ImageCache, is in hand before the
    /// push animates in; only an uncached one waits for `prepare()`.
    init(memberId: String, source: ImageEditSource) {
        self.memberId = memberId
        self.source = source
        _opening = State(initialValue: Self.immediateOpening(memberId: memberId, source: source))
    }

    /// D5: the stored original at its framing; no original → the avatar itself at identity
    /// (`hasOriginal` false, so the first save stores it as the original); no avatar → nil.
    static func opening(detail: MemberDetail) -> (url: String, framing: ImageFraming, hasOriginal: Bool)? {
        if let original = detail.profilePictureOriginalUrl, !original.isEmpty {
            return (original, detail.profilePictureFraming ?? .identity, true)
        }
        if let avatar = detail.profilePicture, !avatar.isEmpty { return (avatar, .identity, false) }
        return nil
    }

    @MainActor
    private static func immediateOpening(memberId: String, source: ImageEditSource) -> Opening? {
        switch source {
        case let .newPick(image):
            // At the floor, centred; the pick itself is uploaded as the original.
            return Opening(image: image, framing: .identity, isNewPick: true, hasStoredOriginal: true)
        case .stored:
            guard let detail = AppState.shared.memberDetails[memberId],
                  let stored = opening(detail: detail),
                  let url = URL(string: stored.url),
                  let image = Ui2ImageCache.shared.image(for: url) else { return nil }
            return Opening(image: image, framing: stored.framing, isNewPick: false, hasStoredOriginal: stored.hasOriginal)
        }
    }

    static func route(_ outcome: ImageFramingModel.SaveOutcome) -> Route {
        switch outcome {
        case .saved, .forbidden, .gone: return .pop
        case .unauthorized: return .signOut
        case .failed: return .banner
        case .ignored: return .stay
        }
    }

    var body: some View {
        EditCoverScreen(
            state: EditGroupCoverContainer.screenState(model),
            aspect: Self.frameAspect,
            mask: .circle,
            title: Self.title,
            canvas: { canvas },
            onFrameLayout: { rect in
                frameRect = rect
                makeModelIfReady()
            },
            onCancel: cancel,
            onDone: { Task { await save() } },
            onFlip: { model?.flip() },
            onRotate90: { model?.rotate90() },
            onStraighten: { model?.straighten(to: $0) },
            onStraightenEnd: {
                guard let model else { return }
                withAnimation(ImageFramingCanvas.settle) { model.endStraighten() }
            }
        )
        .background(Token.layoutBackground.ignoresSafeArea())
        // D12: one red row and Done; Done stays. Hosted by the shell's `.ui2OverlayHost()`.
        .actionMenuPresentation(isPresented: discardMenuOpen, onDismiss: { discardMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [EditGroupCoverContainer.discardAction],
                onSelect: { _ in
                    discardMenuOpen = false
                    guard EditGroupCoverContainer.discardPops(isSaving: model?.isSaving ?? false) else { return }
                    navigator.pop()
                },
                onDone: { discardMenuOpen = false }
            )
        }
        .task { await prepare() }
    }

    @ViewBuilder private var canvas: some View {
        if let model {
            ImageFramingCanvas(model: model, frame: frameRect, accessibilityLabel: Self.canvasLabel)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cancel() {
        switch EditGroupCoverContainer.cancelAction(hasChanges: model?.hasChanges ?? false, isSaving: model?.isSaving ?? false) {
        case .pop: navigator.pop()
        case .confirmDiscard: discardMenuOpen = true
        case .ignore: break
        }
    }

    /// The model is built once, from the first laid-out frame that has a size.
    private func makeModelIfReady() {
        guard model == nil, let opening, frameRect.width > 0, frameRect.height > 0 else { return }
        let save: @MainActor (UIImage, ImageFraming, UIImage?) async throws -> String = { [memberId] rendered, framing, original in
            try await MemberActions().saveAvatar(memberId: memberId, rendered: rendered, framing: framing, original: original)
        }
        let built = ImageFramingModel(image: opening.image, framing: opening.framing,
                                      isNewPick: opening.isNewPick, hasStoredOriginal: opening.hasStoredOriginal,
                                      frameSize: frameRect.size, outputSize: Self.renderSize,
                                      saveFailedMessage: Self.saveFailedMessage, save: save)
        model = built
        // D12: an edge swipe with a change does not pop; it asks to discard, as Cancel does; while saving it neither pops nor asks.
        backSwipe?.blocksBackSwipe = { [weak built] in
            EditGroupCoverContainer.blocksBackSwipe(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
        }
        backSwipe?.onBlockedBackSwipe = { [weak built] in
            let action = EditGroupCoverContainer.cancelAction(hasChanges: built?.hasChanges ?? false, isSaving: built?.isSaving ?? false)
            if action == .confirmDiscard { discardMenuOpen = true }
        }
    }

    @MainActor
    private func prepare() async {
        // A new pick and a cached photo were set in `init`; this loads an uncached one (D5).
        guard opening == nil else { return }
        // Pops only this page: the member may already have left it (Cancel pops at once while loading).
        let leave = { navigator.popIfTop(.editMemberAvatar(memberId: memberId, source: source)) }
        guard let detail = AppState.shared.memberDetails[memberId],
              let stored = Self.opening(detail: detail) else { leave(); return }
        _ = await MemberProfileContainer.seedCovers([stored.url])
        // Silent: the page was closed during the load — no banner for a page that is gone.
        guard !Task.isCancelled else { return }
        guard let opened = Self.immediateOpening(memberId: memberId, source: source) else {
            AppState.shared.recordError(APIError.invalidResponse, context: "EditMemberAvatarContainer.loadOriginal",
                                        surface: true, friendlyMessage: Self.loadFailedMessage)
            leave()
            return
        }
        opening = opened
        makeModelIfReady()
    }

    @MainActor
    private func save() async {
        guard let model else { return }
        let outcome = await model.save()
        switch Self.route(outcome) {
        case .pop: navigator.popIfTop(.editMemberAvatar(memberId: memberId, source: source))
        case .signOut:
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "EditMemberAvatarContainer.signOut", surface: false)
            }
        case .banner:
            if case let .failed(message) = outcome {
                AppState.shared.recordError(APIError.serverError(message), context: "EditMemberAvatarContainer.save", surface: true,
                                            friendlyMessage: model.saveFailedMessage,
                                            retry: { Task { await save() } })
            }
        case .stay: break
        }
    }
}
```

Register it and mirror it into the capture target:

```bash
ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' \
  iphone/MakeReady/UI2/Containers/Members/EditMemberAvatarContainer.swift iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift MakeReady
ruby iphone/scripts/capture-targets.rb
ruby iphone/scripts/capture-targets.rb --check
```

- [ ] **Step 6: The group cover passes its own geometry (D9)** — in `EditGroupCoverContainer.swift` add next to `frameAspect`:

```swift
    /// image-framing-editor D9: the generalised screen's title for the group cover.
    static let title = "Edit cover"
```

and in `body` add the three inputs to the `EditCoverScreen(` call, right after `state: Self.screenState(model),` (again with the d2m file's real names):

```swift
            aspect: Self.frameAspect,
            mask: .rectangle,
            title: Self.title,
```

Behaviour of the group cover is unchanged: 16:9, today's rectangular dim, "Edit cover".

- [ ] **Step 7: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the 4 new tests and every existing one, incl. `EditGroupCoverContainerTests`); `npm run ios:build-check` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations

- [ ] **Step 8: Commit** — never stage `iphone/MakeReadyUI/` → `feat(image-framing-editor): Edit photo route on the generalised edit-cover screen`

### Task 8: The avatar tap on the member page — picker, C-066 menu, viewer (D4, D10, D13)
App: iphone
Phase: 4
Recipe: `/present-overlay` · SPEC §iphone "Member profile (D4, D10)" · D4, D10, D13, D15 · ⚠ F1 (D10 half)

> **D10 is a mechanical build edit to d2m-owned `MembersProfileScreen`** (the `onCoverTap` precedent, `GroupsDetailScreen.swift:124, 291-297`): one defaulted closure and a button around the avatar — nothing else in that file. List it in your report so it is routed to `/ui2-resolve` after the build. The C-066 glyphs `upload` / `edit` / `eye` already exist (`GlyphName`); if a design shows different ones, do not draw one — note it for `/ui2-component-update C-066`.

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift:101-128` (`onAvatarTap` + init param, defaulted, last), `:276-281` (the tappable avatar)
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift:1-65` (tap routing, menu, picker, viewer) and new statics after `:97`
- Test: `iphone/MakeReadyCaptureTests/MemberProfileAvatarTapTests.swift` (register in `MakeReadyCaptureTests`, sibling `iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift`)

**Interfaces:**
- Consumes: Task 7 `UI2Destination.editMemberAvatar(memberId:source:)`; Task 6 `MemberDetail.profilePictureOriginalUrl`; Task 5 `ImageEditSource`, `coverViewerPresentation(url:accessibilityLabel:onClose:)`; `CoverImageRendering.uprightDownsampled(_:)`; `.actionMenuPresentation(isPresented:onDismiss:onHidden:menu:)`; `ActionMenuOverlay.ActionItem`; `GroupActions.isCancellation(_:)`
- Produces:
  - `MembersProfileScreen.onAvatarTap: () -> Void = {}` (init param last, defaulted — `ViewRegistry.swift:2400`, the two `#Preview`s and `UI2MembersComponentTests.swift:112-113` keep compiling)
  - `enum MemberProfileContainer.AvatarTap: Equatable { case none, picker, menu, googleMenu }`; `static func avatarTap(detail: MemberDetail?) -> AvatarTap`; `static func isGoogleOnly(_ detail: MemberDetail) -> Bool`
  - `enum MemberProfileContainer.AvatarChoice: String { case change = "Change image", edit = "Edit image", view = "View image" }` with `init?(label:)`; `static func avatarActions(_ tap: AvatarTap) -> [ActionMenuOverlay.ActionItem]`
  - `static func MemberProfileContainer.avatarViewerURL(detail: MemberDetail?) -> String?`; `static let viewerLabel = "Profile photo"`

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/MemberProfileAvatarTapTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// image-framing-editor D4/D10/D13: what an avatar tap does, read from AppState's member detail
/// (never the screen state); the menu rows per photo state; the viewer's URL.
@MainActor
final class MemberProfileAvatarTapTests: XCTestCase {
    private let r2 = "https://pub.r2.example/avatars/members/m1/1700000000.webp"
    private let google = "https://lh3.googleusercontent.com/a/ACg8oc=s96-c"

    private func detail(_ picture: String?, google: String? = nil, original: String? = nil) -> MemberDetail {
        MemberDetail(id: "m1", profilePicture: picture, googlePicture: google, profilePictureOriginalUrl: original)
    }

    /// D4: a tap before the detail loads does nothing.
    func testUnloadedMemberIsInert() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: nil), .none)
    }

    /// D4: no photo and no Google picture → the system picker.
    func testNoPhotoOpensThePicker() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(nil)), .picker)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("")), .picker)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("", google: "")), .picker)
    }

    /// D4/D15: an uploaded avatar (incl. the R2 copy made at Google linking) → Change · Edit · View.
    func testUploadedPhotoOpensTheFullMenu() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(r2)), .menu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(r2, google: google)), .menu)
    }

    /// D4: Google-only — no avatar, the avatar IS the Google picture, or it is hosted on googleusercontent.com.
    func testGoogleOnlyOpensChangeAndView() {
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(nil, google: google)), .googleMenu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail(google, google: google)), .googleMenu)
        XCTAssertEqual(MemberProfileContainer.avatarTap(detail: detail("https://lh5.googleusercontent.com/x/photo.jpg")), .googleMenu)
    }

    /// D4: the rows, in order, with existing glyphs; Google-only has no Edit; the picker states have none.
    func testMenuRowsPerState() {
        let full = MemberProfileContainer.avatarActions(.menu)
        XCTAssertEqual(full.map(\.label), ["Change image", "Edit image", "View image"])
        XCTAssertEqual(full.map(\.glyph), ["upload", "edit", "eye"])
        let googleOnly = MemberProfileContainer.avatarActions(.googleMenu)
        XCTAssertEqual(googleOnly.map(\.label), ["Change image", "View image"])
        XCTAssertEqual(googleOnly.map(\.glyph), ["upload", "eye"])
        XCTAssertTrue(MemberProfileContainer.avatarActions(.picker).isEmpty)
        XCTAssertTrue(MemberProfileContainer.avatarActions(.none).isEmpty)
        for row in full { XCTAssertNotNil(GlyphName(rawValue: row.glyph), row.glyph) }
        XCTAssertEqual(full.map { MemberProfileContainer.AvatarChoice(label: $0.label) }, [.change, .edit, .view])
    }

    /// D13: the stored original first, else the avatar, else the Google picture.
    func testViewerURL() {
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(r2, google: google, original: "https://img/o.jpeg")), "https://img/o.jpeg")
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(r2, google: google, original: "")), r2)
        XCTAssertEqual(MemberProfileContainer.avatarViewerURL(detail: detail(nil, google: google)), google)
        XCTAssertNil(MemberProfileContainer.avatarViewerURL(detail: detail(nil)))
        XCTAssertNil(MemberProfileContainer.avatarViewerURL(detail: nil))
        XCTAssertEqual(MemberProfileContainer.viewerLabel, "Profile photo")
    }

    /// D10: the screen stores the closure; its default is a no-op.
    func testScreenAvatarHook() {
        var tapped = false
        let screen = MembersProfileScreen(state: .populated, showsHeader: false, onAvatarTap: { tapped = true })
        screen.onAvatarTap()
        XCTAssertTrue(tapped)
        MembersProfileScreen(state: .populated).onAvatarTap()
    }
}
```

Register it:

```bash
ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("iphone/MakeReady.xcodeproj"); n=File.expand_path(ARGV[0]); s=p.files.find{|f| f.real_path.to_s==File.expand_path(ARGV[1])} or abort("sibling not in project"); abort("already added") if p.files.any?{|f| f.real_path.to_s==n}; r=s.parent.new_reference(n); p.targets.find{|t| t.name==ARGV[2]}.add_file_references([r]); p.save' \
  iphone/MakeReadyCaptureTests/MemberProfileAvatarTapTests.swift iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift MakeReadyCaptureTests
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile, `type 'MemberProfileContainer' has no member 'avatarTap'`

- [ ] **Step 3: The screen hook (D10)** — `MembersProfileScreen.swift`: after `var onEnroll: () -> Void = {}` (line 108) add

```swift
    var onAvatarTap: () -> Void = {}                // C-038 tap → picker or the photo menu (image-framing-editor D4/D10)
```

add the init parameter `onAvatarTap: @escaping () -> Void = {}` after `onEnroll: @escaping () -> Void = {}` (making `onEnroll`'s line end with a comma), and `self.onAvatarTap = onAvatarTap` after `self.onEnroll = onEnroll`. In `identityBlock` replace the `Avatar(…)` call and its `.ui2Element("C-038 Avatar")` (lines 276-281) with:

```swift
            // image-framing-editor D10: tappable; the button carries its own label and trait
            // (the group cover's `onCoverTap` precedent).
            SwiftUI.Button(action: onAvatarTap) {
                Avatar(
                    imageURL: Self.optionalText(state.avatarURL).flatMap(URL.init(string:)),
                    initials: Self.optionalText(state.initials),
                    size: Self.avatarSize
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.avatarURL.isEmpty ? "Add photo" : "Profile photo")
            .accessibilityAddTraits(.isButton)
            .ui2Element("C-038 Avatar")
```

Then `ruby iphone/scripts/makereadyui-sync.rb` (no new file, it must report nothing to change).

- [ ] **Step 4: The routing statics** — in `MemberProfileContainer.swift`, after `groupDestination(_:row:)` (ends line 97), add:

```swift
    // MARK: image-framing-editor D4/D13 — the avatar tap

    enum AvatarTap: Equatable { case none, picker, menu, googleMenu }

    enum AvatarChoice: String {
        case change = "Change image", edit = "Edit image", view = "View image"
        init?(label: String) { self.init(rawValue: label) }
    }

    /// D13: the viewer image's accessibility label.
    static let viewerLabel = "Profile photo"
    /// The banner an unreadable pick shows; the page stays.
    static let pickFailedMessage = "Couldn't open that photo"

    /// D4: read from AppState's member detail — inert until it has loaded. No avatar and no Google
    /// picture → the picker; Google-only → Change · View; an uploaded avatar → Change · Edit · View.
    static func avatarTap(detail: MemberDetail?) -> AvatarTap {
        guard let detail else { return .none }
        let picture = MembersHomeMapper.nonEmpty(detail.profilePicture)
        let google = MembersHomeMapper.nonEmpty(detail.googlePicture)
        if picture == nil && google == nil { return .picker }
        return isGoogleOnly(detail) ? .googleMenu : .menu
    }

    /// D4: the shown picture is Google's — no avatar (the Google picture shows), the avatar equals the
    /// Google picture, or it is served from googleusercontent.com. An R2 copy made at linking is not (D15).
    static func isGoogleOnly(_ detail: MemberDetail) -> Bool {
        guard let picture = MembersHomeMapper.nonEmpty(detail.profilePicture) else {
            return MembersHomeMapper.nonEmpty(detail.googlePicture) != nil
        }
        if picture == detail.googlePicture { return true }
        return URL(string: picture)?.host?.hasSuffix("googleusercontent.com") == true
    }

    /// D4: the C-066 rows, in order — existing glyphs (an unknown name renders the red stub).
    static func avatarActions(_ tap: AvatarTap) -> [ActionMenuOverlay.ActionItem] {
        let change = ActionMenuOverlay.ActionItem(glyph: "upload", label: AvatarChoice.change.rawValue)
        let edit = ActionMenuOverlay.ActionItem(glyph: "edit", label: AvatarChoice.edit.rawValue)
        let view = ActionMenuOverlay.ActionItem(glyph: "eye", label: AvatarChoice.view.rawValue)
        switch tap {
        case .menu: return [change, edit, view]
        case .googleMenu: return [change, view]
        case .none, .picker: return []
        }
    }

    /// D13: the stored original when there is one, else the avatar, else the Google picture.
    static func avatarViewerURL(detail: MemberDetail?) -> String? {
        guard let detail else { return nil }
        return MembersHomeMapper.nonEmpty(detail.profilePictureOriginalUrl)
            ?? MembersHomeMapper.nonEmpty(detail.profilePicture)
            ?? MembersHomeMapper.nonEmpty(detail.googlePicture)
    }
```

(`MembersHomeMapper.nonEmpty(_:)` is an internal static at `MembersHomeMapper.swift:123`.)

- [ ] **Step 5: Wire the tap, menu, picker and viewer** — in `MemberProfileContainer.swift` add `import PhotosUI` above `import SwiftUI`; add the state under `@State private var coversSeeded = 0`:

```swift
    /// image-framing-editor D4: the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D4: the photo menu, its rows, and the row chosen — acted on once the menu has slid out.
    @State private var avatarMenuOpen = false
    @State private var avatarMenuRows: [ActionMenuOverlay.ActionItem] = []
    @State private var pendingAvatarChoice: AvatarChoice?
    /// D13: the viewer's URL while it is up.
    @State private var viewerURL: String?
```

Pass the hook in the `MembersProfileScreen(` call after `onOpenGroup: { … }`:

```swift
                    ,
                    // image-framing-editor D4: no photo → the picker; a photo → Change · Edit · View (Google-only: no Edit).
                    onAvatarTap: { handleAvatarTap() }
```

(i.e. add a comma after the `onOpenGroup` closure's closing brace, then the `onAvatarTap:` argument.) After `.background(Token.layoutBackground.ignoresSafeArea())` add:

```swift
        // D4: the C-066 photo menu; Done cancels. The chosen row runs after the menu has finished
        // hiding — the overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: avatarMenuOpen, onDismiss: { avatarMenuOpen = false },
                                onHidden: { runPendingAvatarChoice() }) {
            ActionMenuOverlay(
                actions: avatarMenuRows,
                onSelect: { item in
                    pendingAvatarChoice = AvatarChoice(label: item.label)
                    avatarMenuOpen = false
                },
                onDone: { avatarMenuOpen = false }
            )
        }
        // D4: the system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        // D13
        .coverViewerPresentation(url: viewerURL, accessibilityLabel: Self.viewerLabel, onClose: { viewerURL = nil })
```

and the handlers (inside the struct, after `body`):

```swift
    private func handleAvatarTap() {
        let tap = Self.avatarTap(detail: AppState.shared.memberDetails[memberId])
        switch tap {
        case .none: break
        case .picker: pickerOpen = true
        case .menu, .googleMenu:
            avatarMenuRows = Self.avatarActions(tap)
            avatarMenuOpen = true
        }
    }

    private func runPendingAvatarChoice() {
        guard let choice = pendingAvatarChoice else { return }
        pendingAvatarChoice = nil
        switch choice {
        case .change: pickerOpen = true
        case .edit: navigator.push(.editMemberAvatar(memberId: memberId, source: .stored))
        case .view: viewerURL = Self.avatarViewerURL(detail: AppState.shared.memberDetails[memberId])
        }
    }

    /// D4/D7: load the pick, make it upright and ≤ 2400px, then Edit photo. Dismissing the picker
    /// changes nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(.editMemberAvatar(memberId: memberId, source: .newPick(image)))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "MemberProfileContainer.openPicked", surface: true,
                                        friendlyMessage: Self.pickFailedMessage)
        }
    }
```

- [ ] **Step 6: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the 7 new tests, `UI2MembersComponentTests` and every existing test); `npm run ios:build-check` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations. Run `/transition-review` on the diff (it adds overlay presentations) and fix any FAIL.

- [ ] **Step 7: Commit** — stage `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift`, `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift`, `iphone/MakeReadyCaptureTests/MemberProfileAvatarTapTests.swift`, `iphone/MakeReady.xcodeproj/project.pbxproj` → `feat(image-framing-editor): avatar tap on the member page — picker, photo menu, viewer`
