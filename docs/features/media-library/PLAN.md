# media-library — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** MakeReady's read-only cover library plus every org the leader belongs to in one Media grid, uploads from Media into an org, and "Choose from library" on group and program covers.

**Architecture:** MakeReady media are ordinary `Media` rows in one flagged Organization (`isMakeReady`) owned by a disabled system user; one read rule opens them to every signed-in user and the generic write paths refuse that org. A new cross-source listing (`/api/media/browse`, `/api/media/sources`) feeds the iPhone Media page, which filters by Source on-device; covers picked from the library carry `sourceMediaId` so the server records a usage instead of capturing a copy.

**Tech Stack:** server — Express + Prisma + Atlas (YAML schema), vitest, R2 via `uploadImageVariants`; iphone — SwiftUI `@Observable` + Actions, UI2 shell (`UI2Destination`, `.filterMenuPresentation`, `ActionMenuOverlay`), d2m channel for `iphone/MakeReadyUI/`, XCTest in `MakeReadyCaptureTests`.

**Spec:** `docs/features/media-library/SPEC.md` · code map: `.builder/media-library/audit-digest.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(media-library): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–3 | MakeReady org exists, its media are readable everywhere and writable only through the super-admin API | `cd server && npx tsc --noEmit` · `npx tsc --noEmit -p fixtures` · `npm run test:run` (scratch DB) · `npm run schema:validate` · `docker restart makeready-server` |
| 2 | server | 4–7 | browse/sources, library-pick covers, event capture, import command + fixtures; contract frozen | same as phase 1 |
| 3 | iphone | 8 | d2m delivers the Source chip on media-home and the media-picker screen | `npm run ios:build-check` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 9–13 | the app reads browse, filters by source, uploads, and picks covers from the library | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: MakeReady org flag, system owner and `ensureMakeReadyOrg`
App: server
Phase: 1
Recipe: `/api` · server/.claude/CLAUDE.md §Database Management

**Files:**
- Modify: `server/schema/schema.yaml` (Organization, ~506-540) — add `isMakeReady`
- Generated: `server/prisma/schema.prisma`, `server/atlas/migrations/*` (via schema:generate + atlas diff)
- Create: `server/src/services/makeready-library.ts`
- Modify: `server/src/services/organization.ts:144-163` — filter `isMakeReady: false`
- Modify: `server/scripts/schema/run-seeds.ts:293-320` — skip the MakeReady org
- Test: `server/src/services/__tests__/makeready-library.test.ts`

**Interfaces:**
- Produces: `MAKEREADY_ORG_ID`, `MAKEREADY_SYSTEM_USER_ID` (fixed UUID constants), `ensureMakeReadyOrg(): Promise<{ orgId: string; userId: string }>`, `isMakeReadyOrg(orgId: string): Promise<boolean>` (memoized per process).

- [ ] **Step 1: Write the failing test**

```ts
import { describe, it, expect } from 'vitest'
import { prisma } from '../../db.js'
import { ensureMakeReadyOrg, isMakeReadyOrg, MAKEREADY_ORG_ID, MAKEREADY_SYSTEM_USER_ID } from '../makeready-library.js'
import { getUserOrganizations } from '../organization.js'

describe('ensureMakeReadyOrg', () => {
  it('creates the org and a disabled system owner once', async () => {
    await ensureMakeReadyOrg(); await ensureMakeReadyOrg()
    const org = await prisma.organization.findUnique({ where: { id: MAKEREADY_ORG_ID } })
    const user = await prisma.user.findUnique({ where: { id: MAKEREADY_SYSTEM_USER_ID } })
    expect(org).toMatchObject({ isMakeReady: true, name: 'MakeReady', ownerId: MAKEREADY_SYSTEM_USER_ID })
    expect(user?.isActive).toBe(false)
    expect(await prisma.organization.count({ where: { isMakeReady: true } })).toBe(1)
    expect(await isMakeReadyOrg(MAKEREADY_ORG_ID)).toBe(true)
  })
  it('never appears in a user org list, even its owner', async () => {
    await ensureMakeReadyOrg()
    const res = await getUserOrganizations(MAKEREADY_SYSTEM_USER_ID)
    expect((res.data ?? []).some((o: any) => o.id === MAKEREADY_ORG_ID)).toBe(false)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && DATABASE_URL=postgresql://postgres:postgres@localhost:5434/mr_test_scratch npx vitest run src/services/__tests__/makeready-library.test.ts` → FAIL, module not found (🔴 scratch DB only: create it with `docker exec makeready-postgres createdb -U postgres mr_test_scratch`, apply migrations with atlas `--var database_url=…/mr_test_scratch`, drop it after)

- [ ] **Step 3: Schema** — in `schema.yaml` Organization fields add:

```yaml
      isMakeReady:
        type: boolean
        default: false
        description: "media-library D6: the one org that owns MakeReady's own media library"
```
and an index `- fields: [isMakeReady]`. Run `npm run schema:validate && npm run schema:generate`, then `cd atlas && ../scripts/atlas.sh migrate diff media_library_makeready_org --env local --var database_url=postgres://postgres:postgres@localhost:5434/makeready_dev` and apply with `migrate apply` (same `--var`). Then `docker exec makeready-server npx prisma generate`.

- [ ] **Step 4: Service**

```ts
// server/src/services/makeready-library.ts — media-library D6/D15
import { prisma } from '../db.js'
export const MAKEREADY_ORG_ID = '0a4e5e11-0000-4000-8000-00000000a11b'
export const MAKEREADY_SYSTEM_USER_ID = '0a4e5e11-0000-4000-8000-00000000a11a'
export async function ensureMakeReadyOrg() {
  await prisma.user.upsert({
    where: { id: MAKEREADY_SYSTEM_USER_ID },
    create: { id: MAKEREADY_SYSTEM_USER_ID, email: 'makeready-library@system.makeready.org', name: 'MakeReady', isActive: false },
    update: {},
  })
  await prisma.organization.upsert({
    where: { id: MAKEREADY_ORG_ID },
    create: { id: MAKEREADY_ORG_ID, name: 'MakeReady', ownerId: MAKEREADY_SYSTEM_USER_ID, isMakeReady: true },
    update: { isMakeReady: true },
  })
  return { orgId: MAKEREADY_ORG_ID, userId: MAKEREADY_SYSTEM_USER_ID }
}
const cache = new Map<string, boolean>()
export async function isMakeReadyOrg(orgId: string | null | undefined): Promise<boolean> {
  if (!orgId) return false
  if (!cache.has(orgId)) {
    const o = await prisma.organization.findUnique({ where: { id: orgId }, select: { isMakeReady: true } })
    cache.set(orgId, o?.isMakeReady ?? false)
  }
  return cache.get(orgId)!
}
```
(Check the `User` model's required fields in `prisma/schema.prisma` and fill any other required column in `create`.) In `getUserOrganizations` add `isMakeReady: false` to both `organization.findMany` `where`s; in `run-seeds.ts` `migrateOrganizationOwners` add `where: { isMakeReady: false }`.

- [ ] **Step 5: Run it and watch it pass** — same command → PASS; `npx tsc --noEmit` clean.

- [ ] **Step 6: Commit** — `feat(media-library): MakeReady org flag and system owner`

### Task 2: Read rule, usages scoping and the closed write paths
App: server
Phase: 1
Recipe: `/api` · SPEC D16

**Files:**
- Modify: `server/src/services/permission.ts:179-251` (`hasPermission` — media.read on a MakeReady-org media row)
- Modify: `server/src/services/media-library.ts:470-475` (usages detail) and `server/src/routes/media.ts:1580-1630` (usages/detail)
- Modify: `server/src/routes/media.ts:1171-1311, 1386` (upload, batch) and `:996` (DELETE)
- Test: `server/src/routes/__tests__/media-makeready-access.test.ts`

**Interfaces:**
- Consumes: `isMakeReadyOrg`, `ensureMakeReadyOrg`, `MAKEREADY_ORG_ID` (Task 1)
- Produces: `scopeUsagesForCaller(mediaOrgId: string, usages: Usage[], userId: string): Promise<Usage[]>` in media-library.ts

- [ ] **Step 1: Write the failing test** — request tests (supertest, the repo's existing route-test helpers for an authenticated leader in org A, a super admin):
  - leader `GET /api/media/:mrMediaId` → 200
  - leader `PATCH /api/media/:mrMediaId`, `POST /api/media/:mrMediaId/tags`, `DELETE /api/media/:mrMediaId` → 403
  - super admin `DELETE /api/media/:mrMediaId` → 403 and `POST /api/organizations/${MAKEREADY_ORG_ID}/media/upload` → 403 (also `/upload/batch`)
  - a MakeReady media with usages on a group in org A and a group in org B: leader of A `GET /api/media/:id/usages` returns only org A's usage; super admin sees both

- [ ] **Step 2: Run it and watch it fail** — `npx vitest run src/routes/__tests__/media-makeready-access.test.ts` (scratch DB) → FAIL on the leader GET (403)

- [ ] **Step 3: Implement** — in `hasPermission`, after resolving the resource's org: `if (action === 'media.read' && resourceType === 'media' && await isMakeReadyOrg(orgId)) return true`. In upload, batch and DELETE handlers, before the permission check: `if (await isMakeReadyOrg(orgId)) return res.status(403).json({ success: false, error: 'MakeReady media is managed by MakeReady' })` (DELETE resolves the media's org first). In the usages/detail service: when the media's org is MakeReady and the caller is not super admin, keep a usage only when its resource (GROUP_COVER → group, PROGRAM_COVER → program, EVENT_COVER → event's group) has an `organizationId` in `getUserOrganizations(caller)`.

- [ ] **Step 4: Run it and watch it pass** → PASS; `npx tsc --noEmit`; `docker restart makeready-server`

- [ ] **Step 5: Commit** — `feat(media-library): MakeReady media readable by all, writable only by its API`

### Task 3: MakeReady admin endpoints
App: server
Phase: 1
Recipe: `/api` · SPEC D2, D15, D18, §Contract

**Files:**
- Modify: `server/src/services/makeready-library.ts` — `createMakeReadyMedia`, `updateMakeReadyMedia`, `deleteMakeReadyMedia`
- Create: `server/src/routes/makeready-media.ts`; mount in `server/src/index.ts` beside the media routes (~276/446)
- Test: `server/src/routes/__tests__/makeready-media.test.ts`

**Interfaces:**
- Consumes: `ensureMakeReadyOrg` (Task 1); `uploadImageVariants` and `extractImageMetadata` as used by `/media/upload` (media.ts:1206-1240)
- Produces: `POST /api/makeready/media` `{ imageData, title, description?, altText?, tags?, d2mSlug? }` → `{ success, data: media }` (409 on an imported `d2mSlug`); `PATCH /api/makeready/media/:id`; `DELETE /api/makeready/media/:id` (isActive false). `createMakeReadyMedia(input): Promise<Media>` — R2 key `makeready/<d2mSlug|uuid>-<stamp>` with `.jpeg` variants; `exifData: { d2mSlug }`; `source: 'import'`; `uploadedBy: MAKEREADY_SYSTEM_USER_ID`.

- [ ] **Step 1: Write the failing test** — super admin POST creates a row in `MAKEREADY_ORG_ID` with tags lower-cased, `uploadedBy` the system user, `source 'import'`; the same `d2mSlug` again → 409; leader POST → 403; PATCH replaces tags; DELETE sets `isActive false` and the row disappears from `/media/browse` later (assert `isActive`). Mock R2 the way existing media upload tests do.
- [ ] **Step 2: Run it and watch it fail** → FAIL 404
- [ ] **Step 3: Implement** — routes thin, `requireAuth` + a local `requireSuperAdmin` (copy sms-campaigns.ts:23-29), zod bodies (`title` 1–200, `tags` array of 1–40-char strings, `imageData` base64 min 1); service calls `ensureMakeReadyOrg()` first.
- [ ] **Step 4: Run it and watch it pass** → PASS; tsc; restart
- [ ] **Step 5: Commit** — `feat(media-library): MakeReady media admin API`

### Task 4: `/api/media/sources` and `/api/media/browse`
App: server
Phase: 2
Recipe: `/api` · SPEC D4, D16, D17, §Contract · build-time risk F11: register both GETs above `GET /media/:mediaId` (media.ts:394)

**Files:**
- Modify: `server/src/services/media-library.ts` — `listSources(userId)`, `listBrowse(filters)` reusing `listLibrary`'s where-builder
- Modify: `server/src/routes/media.ts` (new GETs above :394, with OpenAPI blocks)
- Test: `server/src/routes/__tests__/media-browse.test.ts`

**Interfaces:**
- Consumes: `getUserOrganizations`, `ensureMakeReadyOrg`, `MAKEREADY_ORG_ID`, `hasPermission`
- Produces: `GET /api/media/sources` → `{ success, data: [{ id, name, isMakeReady, canUpload }] }`; `GET /api/media/browse?sources&type&tags&q&cursor&limit` → `{ success, data, limit, hasMore, nextCursor }`, items + `organizationId`, `isMakeReady`.

- [ ] **Step 1: Write the failing test** — leader in orgs A and B: sources = [MakeReady (canUpload false), A, B]; a Member-role org has `canUpload false`; browse with no sources returns MakeReady + A + B rows (not org C's); `sources=<C>` → 403; `limit=500` → 400; paging with `nextCursor` returns the rest with no duplicates; each item carries `organizationId` and `isMakeReady`.
- [ ] **Step 2: Run it and watch it fail** → FAIL 404
- [ ] **Step 3: Implement** — factor `listLibrary`'s `where` into `buildLibraryWhere(filters)`; `listBrowse` uses `organizationId: { in: ids }`, cursor mode only, `limit` 1–200 default 200, maps `isMakeReady = item.organizationId === MAKEREADY_ORG_ID`. `canUpload` = `hasPermission(userId, 'media.create', 'organization', orgId)`.
- [ ] **Step 4: Run it and watch it pass** → PASS; tsc; restart
- [ ] **Step 5: Commit** — `feat(media-library): cross-source media browse and sources`

### Task 5: Library-pick covers and event-cover capture
App: server
Phase: 2
Recipe: `/api` · SPEC D10, D12

**Files:**
- Modify: `server/src/routes/groups.ts:1265-1345`, `server/src/routes/programs.ts:3905-3985` — zod `sourceMediaId: z.string().uuid().optional()`
- Modify: `server/src/routes/events.ts:1334-1398` — capture
- Modify: `server/src/services/media-library.ts` — `recordLibraryPick({ sourceMediaId, resourceOrgId, usageType, resourceId, resourceName })`
- Test: `server/src/routes/__tests__/cover-library-pick.test.ts`

**Interfaces:**
- Consumes: `isMakeReadyOrg`, `captureToLibrary`
- Produces: cover routes accept `sourceMediaId`; `recordLibraryPick` throws `{ status: 403 | 404 }`.

- [ ] **Step 1: Write the failing test** — group cover save with a MakeReady `sourceMediaId` → 200, media count in the group's org unchanged, one `MediaUsage(GROUP_COVER, groupId)` on the source; same for a program; a `sourceMediaId` from another org → 403; unknown id → 404; no `sourceMediaId` → today's capture still happens; event cover save → a Media row in `event.group.organizationId` with an `EVENT_COVER` usage.
- [ ] **Step 2: Run it and watch it fail** → FAIL (zod strips the field; capture still runs)
- [ ] **Step 3: Implement** — validate the source before saving (MakeReady org or the resource's org, `isActive`), save the cover as today, then `recordLibraryPick` (upsert on `[mediaId, usageType, resourceId]`) instead of `captureToLibrary`. Events: after the cover upload, `if (event.group?.organizationId) captureToLibrary({ … usageType: 'EVENT_COVER', resourceId: event.id, resourceName: event.title, organizationId: event.group.organizationId, source: 'auto_capture' })`.
- [ ] **Step 4: Run it and watch it pass** → PASS; tsc; restart
- [ ] **Step 5: Commit** — `feat(media-library): covers link library picks; event covers captured`

### Task 6: Import command
App: server
Phase: 2
Recipe: `/api` · SPEC D5, D15 · build-time risk F10: resize to 1200px before posting, back off on 429

**Files:**
- Modify: `server/src/services/makeready-library.ts` — `importFromCatalog(items: CatalogItem[], opts)`; re-upload when `objectExists` is false (as `placeLadder`, fixtures/images.ts:203-208)
- Create: `server/scripts/media-makeready-import.ts`; `server/package.json` script `media:makeready:import`
- Test: `server/src/services/__tests__/makeready-import.test.ts`

**Interfaces:**
- Consumes: `createMakeReadyMedia` (Task 3)
- Produces: `CatalogItem = { slug, title, alt, tags: string[], file: Buffer }`; `importFromCatalog(items): Promise<{ created: number; skipped: number; repaired: number }>`. CLI: `--from d2m` (reads `<d2m>/api/projects/makeready/images`, keeps live `Use=cover`, tags = Subject + Book terms lower-cased, posts to `--api` with `Authorization: Bearer $MAKEREADY_API_KEY`) or `--from fixtures` (service call, no HTTP).

- [ ] **Step 1: Write the failing test** — two items import as 2 created; rerun → 2 skipped; delete one R2 object (mocked `objectExists` false) → 1 repaired; titles/descriptions/altText/tags match the items.
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement** — service loop; CLI with sharp resize to 1200 longest side, jpeg q88, sequential posts with retry on 429 (wait `Retry-After` or 1s, max 5).
- [ ] **Step 4: Run it and watch it pass** → PASS; tsc
- [ ] **Step 5: Commit** — `feat(media-library): MakeReady import command`

### Task 7: Fixtures — 223 MakeReady covers and a second org; freeze the contract
App: server
Phase: 2
Recipe: `server/fixtures/README.md` · SPEC D5, D20

**Files:**
- Modify: `server/fixtures/images.ts` (manifest type + `makeready` list + per-image `tags`; import inside the storage gate 219-224)
- Modify: `server/fixtures/refresh-images.ts` (select every live `Use=cover`, write flat, record tags)
- Modify: `server/fixtures/base.ts:123-150` (second org "Northside Fellowship", FIXTURE_USER_ID Admin) and `server/fixtures/ids.ts`
- Modify: `server/fixtures/__tests__/base.db.test.ts:63-85` (counts)
- Add: `server/fixtures/images/*.jpg` (new covers) + `manifest.json`

**Interfaces:**
- Consumes: `importFromCatalog` (Task 6)
- Produces: `FIXTURE_ORG2_ID` in ids.ts; manifest `{ makeready: string[], images: { [slug]: { title, alt, mainColor, tags } } }`.

- [ ] **Step 1: Write the failing test** — base.db.test asserts `organizations: 2` (fixture orgs; MakeReady not counted — it is outside the wipe and gated off under vitest), the fixture user holds a role in both; a unit test of the manifest loader returns `tags` for a makeready slug.
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement** — run `npm run fixtures:images:refresh` on the host (d2m at :5961) to pull the covers; base adds org 2 + UserRole Admin; `seedImages` (storage on) calls `importFromCatalog` with the manifest's makeready slugs.
- [ ] **Step 4: Run it and watch it pass** → PASS; `npx tsc --noEmit -p fixtures`; `docker exec makeready-server npm run fixtures:reset` then `curl -s -A 'Mozilla/5.0' localhost:3010/health`
- [ ] **Step 5: Freeze** — `node ~/.claude-home/plugins/cache/claude-builder/builder/5.5.0/scripts/advance.mjs docs/features/media-library --set "contract=frozen 2026-11-01"` with the commit
- [ ] **Step 6: Commit** — `feat(media-library): fixtures carry the MakeReady library and a second org`

### Task 8: d2m — Source chip on media-home and the media-picker screen
App: iphone
Phase: 3
Recipe: root CLAUDE.md §d2m-built views · SPEC D7, D9 · build-time risk F13: the picker screen is new in d2m

**Files:**
- Modified by d2m (never by hand): `iphone/MakeReadyUI/Screens/Media/MediaHomeScreen.swift`, a new `iphone/MakeReadyUI/Screens/Media/MediaPickerScreen.swift`, `ViewRegistry.swift`

**Interfaces:**
- Produces (as d2m names them — read the result and record the exact inputs in the ledger): media-home State gains a Source chip (first chip, label rule as Tags) with an `onSource` closure; `MediaPickerScreen` = C-040 header (back, title "Choose image") + media-home's body, tile tap → `onTap(id, frame)`.

- [ ] **Step 1:** `check_project_change` subject `media-home`, kinds `composition`, summary "Source chip first in the chip row"; it is a handover → `request_project_change` with the D7 wording and `references` none; `wait_project_change` until done; show any questions to the owner before answering.
- [ ] **Step 2:** `request_project_change` for a new screen `media-picker` (namespace media, type picker) per D9; wait.
- [ ] **Step 3:** `npm run ios:build-check` → PASS; leave d2m's edits for review, then commit `feat(media-library): media-home Source chip and media-picker (d2m)` with the owner's approval.

### Task 9: State — sources, browse items and the load gate
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · SPEC §iphone State

**Files:**
- Modify: `iphone/MakeReady/State/Models/MediaModels.swift:40-98` (`MediaLibraryItem.organizationId: String?`, `isMakeReady: Bool?`; new `MediaSource`)
- Modify: `iphone/MakeReady/State/AppState.swift` (`mediaSources`, `mediaSourcesKey`, clear on sign-out 954-999)
- Modify: `iphone/MakeReady/State/Actions/MediaActions.swift:183-233` (`loadSources()`, `loadAllMedia()`)
- Test: `iphone/MakeReadyCaptureTests/ModelDecodingTests.swift`, `MediaLoadAllPhotosTests.swift`, `StatePersistenceRoundTripTests.swift`

**Interfaces:**
- Produces: `struct MediaSource: Codable, Identifiable, Hashable { id, name: String; isMakeReady, canUpload: Bool }`; `MediaActions.loadSources() async`; `MediaActions.loadAllMedia(pageSize: Int = 200) async -> PhotoLoadOutcome` against `/api/media/browse`; `AppState.mediaSourcesKey: String?` (sorted source ids joined by ",").

- [ ] **Step 1: Write the failing tests** — decode an item with and without the two fields; an old persisted cache round-trips; `loadAllMedia` pages to completion against a stubbed browse and sets `mediaSourcesKey`.
- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL
- [ ] **Step 3: Implement** — mirror `loadAllPhotos`'s loop, endpoint `/api/media/browse?limit=200(&cursor=)`; keep `loadAllPhotos` as a thin wrapper until Task 11 removes its callers.
- [ ] **Step 4: Run and watch them pass** → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(media-library): media sources and cross-source load`

### Task 10: Upload queue (photos and videos)
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · SPEC D13, D8

**Files:**
- Create: `iphone/MakeReady/State/Actions/MediaUploadQueue.swift`
- Modify: `iphone/MakeReady/State/Actions/MediaActions.swift:396-452` (`uploadPhoto(image:orgId:sourceData:)`, `uploadVideo(url:orgId:)` via `/media/upload` `type: 'video'` + the returned `uploadUrl`)
- Test: `iphone/MakeReadyCaptureTests/MediaUploadQueueTests.swift`

**Interfaces:**
- Consumes: `MediaSource` (Task 9)
- Produces: `AppState.mediaUploads: MediaUploadQueue` with `enqueue(_ items: [PickedMedia], orgId: String)`; `PickedMedia = .photo(UIImage, data: Data?, takenAt: String?) | .video(URL)`; a finished photo upserts a local `MediaLibraryItem` (tags [], usageCount 0, uploader self, organizationId, isMakeReady false); each failure → `state.recordError(…, surface: true)`.

- [ ] **Step 1: Write the failing test** — two photos enqueued against a stub → both inserted into `mediaLibrary` with the org id; one failure surfaces one error and the other still lands; a video is uploaded but not inserted.
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement** — a serial `Task` owned by AppState (not a view), cancelled only on sign-out.
- [ ] **Step 4: Run and watch it pass** → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(media-library): media upload queue`

### Task 11: Mapper — Source filter and MakeReady ordering
App: iphone
Phase: 4
Recipe: SPEC D7, D22

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeMapper.swift:27-94`
- Test: `iphone/MakeReadyCaptureTests/MediaHomeMapperTests.swift`

**Interfaces:**
- Consumes: `MediaSource`, item `organizationId`/`isMakeReady` (Task 9)
- Produces: `Selection.sources: Set<String>` (empty = all; `"makeready"` key for MakeReady); `MediaHomeMapper.sourceOptions(_ sources: [MediaSource]) -> [FilterOption]`; ordering: MakeReady items first (oldest end) by title A–Z, then org items by takenAt ?? createdAt.

- [ ] **Step 1: Write the failing test** — empty selection shows all; selecting org A hides MakeReady and org B; MakeReady items sort before every org item, A–Z; source options = MakeReady then orgs by name.
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run and watch it pass** → PASS
- [ ] **Step 5: Commit** — `feat(media-library): Source filter and MakeReady ordering`

### Task 12: Media page — browse, Source chip, upload with Upload-to
App: iphone
Phase: 4
Recipe: `/present-overlay` · `/ios-error-surface` · SPEC D7, D8, D13

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Media/MediaHomeContainer.swift` (load gate on `mediaSourcesKey`, `loadSources` + `loadAllMedia`, Source chip menu, PhotosPicker, Upload-to)
- Modify: `iphone/MakeReady/UI2/Shell/TopNavHost.swift:100-108` (Media add slot → container upload)
- Test: `iphone/MakeReadyCaptureTests/MediaHomeContainerTests.swift`

**Interfaces:**
- Consumes: Tasks 8–11
- Produces: `MediaHomeContainer.uploadTargets(_ sources: [MediaSource], selection: Selection) -> (options: [MediaSource], preselected: String?)`

- [ ] **Step 1: Write the failing test** — `uploadTargets`: one canUpload org → straight in (no menu); two → menu, preselected when the Source selection is exactly one of them; none → empty (banner path); sources missing → `state.organizationId`.
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement** — the add slot sets a container flag that presents the Upload-to `.filterMenuPresentation` (`.single`) when needed, then the system `.photosPicker(isPresented:selection:maxSelectionCount: 20, matching: .any(of: [.images, .videos]))` (the repo allows the system picker, as GroupDetailContainer.swift:19-24); results → `AppState.mediaUploads.enqueue`.
- [ ] **Step 4: Run and watch it pass** → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(media-library): Media page browses every source and uploads`

### Task 13: Choose from library on group and program covers
App: iphone
Phase: 4
Recipe: `/push-page` · `/present-overlay` · SPEC D9, D10

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/ImageFramingModel.swift:5-11` (`newPick(UIImage, takenAt: String? = nil, sourceMediaId: String? = nil)`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/EditGroupCoverContainer.swift:60-91,213-220`, `iphone/MakeReady/UI2/Containers/Members/EditMemberAvatarContainer.swift:73`
- Modify: `iphone/MakeReady/UI2/Containers/Shared/CoverOwner.swift:30-53` (`save(… sourceMediaId:)`, coverTap no-cover → menu)
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift:370-410`, `ProgramActions.swift:671-710` (body `sourceMediaId`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift:122-177`, `Programs/StudyProgramHomeContainer.swift:94-106,185-215` (menu rows)
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:19-60` (`.chooseCoverFromLibrary(owner: CoverOwner)`), `UI2Shell.swift:187-212`
- Create: `iphone/MakeReady/UI2/Containers/Media/MediaPickerContainer.swift`
- Test: `iphone/MakeReadyCaptureTests/CoverLibraryPickTests.swift`

**Interfaces:**
- Consumes: `MediaPickerScreen` (Task 8), mapper (Task 11), `loadAllMedia` (Task 9)
- Produces: `UI2Destination.chooseCoverFromLibrary(owner: CoverOwner)`; `GroupActions.saveCover(groupId:rendered:framing:original:takenAt:sourceMediaId:)` and the program twin.

- [ ] **Step 1: Write the failing test** — `saveCover` body contains `sourceMediaId` only when given; `coverTap` with no cover returns `.menu` with rows ["Photos", "Choose from library"]; with a cover the rows are ["Edit image", "Change image", "Choose from library", "View image"].
- [ ] **Step 2: Run it and watch it fail** → FAIL
- [ ] **Step 3: Implement** — picker container hosts `MediaPickerScreen` (photos only), tile tap loads the full image (`ImageLoader`), on success `shell.replaceTop(owner.destination(.newPick(image, takenAt:, sourceMediaId: item.id)))`, on failure the banner "Couldn't open that photo" and stay.
- [ ] **Step 4: Run and watch it pass** → PASS; swiftlint
- [ ] **Step 5: Commit** — `feat(media-library): choose a cover from the library`
