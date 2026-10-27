# ui2-groups-edit — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaders on iPhone 2.0 can edit a group's six settings (name, description, visibility, age range, maximum members, member directory access) and delete the group from the group page.

**Architecture:** The server's `PATCH /api/groups/:id` learns `memberDirectoryAccess` (D7), keeps a stored Names-only on Boolean-only writes (D12) and rejects an inverted age range (D8); the directory rule lives in a small pure service. On the iPhone, the member edit pattern is cloned for groups: a `GroupField` enum, a pure `GroupFieldEditModel`, a `GroupFieldEditContainer` behind a new `.editGroupField` destination, a one-key `GroupPatch` sent through `GroupActions.updateGroup(id:patch:)`, and Delete through the built C-066 `ActionMenuOverlay` with a new destructive row tone.

**Tech Stack:** server — Express, zod, Prisma, vitest + supertest; iphone — SwiftUI, `@Observable` AppState + Actions, MakeReadyUI built screens, XCTest (`MakeReadyCaptureTests`).

**Spec:** `docs/features/ui2-groups-edit/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-groups-edit): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–2 | PATCH `/api/groups/:id` accepts `memberDirectoryAccess`, keeps Names only on Boolean-only writes, rejects an inverted age range; the rich fixture group carries a stored value in every edited field. Contract frozen at its close | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` |
| 2 | iphone | 3–8 | The six edit pages open from the group page and save; Delete Group confirms through the red C-066 row and returns to Groups | `npm run ios:build-check` · `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: PATCH directory access + age validation (SC1, SC2, SC3)
App: server
Phase: 1
Recipe: `/api` (server endpoint) — SPEC §server, §Contract, D7, D8, D12

**Files:**
- Create: `server/src/services/group-fields.ts`
- Create: `server/src/services/__tests__/group-fields.test.ts`
- Modify: `server/src/routes/groups.ts:996-1135` (PATCH `/:id`: zod schema 1005-1023, update build 1038-1054)
- Create: `server/src/routes/__tests__/groups-edit-fields.request.test.ts`

**Interfaces:**
- Consumes: `groupManageFilter`, `isSuperAdmin` (`server/src/services/permission.js`), the existing PATCH handler.
- Produces: `PATCH /api/groups/:id` per SPEC §Contract — body key `memberDirectoryAccess?: 'ALLOWED' | 'NAMES_ONLY' | 'NOT_ALLOWED'`; 400 `{ success: false, error: 'memberDirectory conflicts with memberDirectoryAccess' }` on a D7 conflict; 400 `{ success: false, error: 'Minimum age must not exceed maximum age' }` on D8; response unchanged (already carries `memberDirectoryAccess`). Service exports `directoryWrite(input, stored)` and `isAgeRangeInverted(range)`.

- [ ] **Step 1: Write the failing service test** — `server/src/services/__tests__/group-fields.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { directoryWrite, isAgeRangeInverted } from '../group-fields.js'

describe('directoryWrite (D7, D12)', () => {
  it('writes nothing when neither key is sent', () => {
    expect(directoryWrite({}, 'NAMES_ONLY')).toBeNull()
  })

  it.each([
    ['ALLOWED', true],
    ['NAMES_ONLY', false],
    ['NOT_ALLOWED', false],
  ] as const)('memberDirectoryAccess %s → enum + Boolean %s (D7)', (access, enabled) => {
    expect(directoryWrite({ memberDirectoryAccess: access }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: access,
      memberDirectoryEnabled: enabled,
    })
  })

  it('accepts both keys when they agree', () => {
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'ALLOWED' }, 'NOT_ALLOWED')).toEqual({
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
    expect(directoryWrite({ memberDirectory: false, memberDirectoryAccess: 'NAMES_ONLY' }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: 'NAMES_ONLY',
      memberDirectoryEnabled: false,
    })
  })

  it('flags a conflict when the two keys disagree (D7)', () => {
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'NAMES_ONLY' }, 'ALLOWED')).toBe('conflict')
    expect(directoryWrite({ memberDirectory: true, memberDirectoryAccess: 'NOT_ALLOWED' }, 'ALLOWED')).toBe('conflict')
    expect(directoryWrite({ memberDirectory: false, memberDirectoryAccess: 'ALLOWED' }, 'ALLOWED')).toBe('conflict')
  })

  it('Boolean-only true → ALLOWED (D12)', () => {
    expect(directoryWrite({ memberDirectory: true }, 'NAMES_ONLY')).toEqual({
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
  })

  it('Boolean-only false keeps a stored NAMES_ONLY or NOT_ALLOWED, turns ALLOWED into NOT_ALLOWED (D12)', () => {
    expect(directoryWrite({ memberDirectory: false }, 'NAMES_ONLY')).toEqual({
      memberDirectoryAccess: 'NAMES_ONLY',
      memberDirectoryEnabled: false,
    })
    expect(directoryWrite({ memberDirectory: false }, 'NOT_ALLOWED')).toEqual({
      memberDirectoryAccess: 'NOT_ALLOWED',
      memberDirectoryEnabled: false,
    })
    expect(directoryWrite({ memberDirectory: false }, 'ALLOWED')).toEqual({
      memberDirectoryAccess: 'NOT_ALLOWED',
      memberDirectoryEnabled: false,
    })
  })
})

describe('isAgeRangeInverted (D8)', () => {
  it.each([
    [undefined, false],
    [null, false],
    [{ min: 30, max: 20 }, true],
    [{ min: 20, max: 20 }, false],
    [{ min: 20, max: 30 }, false],
    [{ min: 30, max: null }, false],
    [{ min: null, max: 20 }, false],
    [{ min: 30 }, false],
  ])('%j → %s', (range, inverted) => {
    expect(isAgeRangeInverted(range)).toBe(inverted)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/group-fields.test.ts` → FAIL, "Failed to load url ../group-fields.js"

- [ ] **Step 3: Write the service** — `server/src/services/group-fields.ts`

```ts
/**
 * ui2-groups-edit D7, D8, D12: the PATCH /api/groups/:id rules for the directory pair and the
 * age range. Pure — the route reads the stored enum and applies what these return.
 */
export type DirectoryAccess = 'ALLOWED' | 'NAMES_ONLY' | 'NOT_ALLOWED'

export interface DirectoryInput {
  memberDirectory?: boolean
  memberDirectoryAccess?: DirectoryAccess
}

export interface DirectoryUpdate {
  memberDirectoryAccess: DirectoryAccess
  memberDirectoryEnabled: boolean
}

/**
 * D7: `memberDirectoryAccess` writes the enum and sets the Boolean to (value == ALLOWED); sent with a
 * disagreeing `memberDirectory` it is a conflict. D12: `memberDirectory` alone — true → ALLOWED;
 * false → NOT_ALLOWED only when the stored value is ALLOWED (a stored NAMES_ONLY / NOT_ALLOWED is kept).
 * null = neither key sent, nothing to write.
 */
export function directoryWrite(input: DirectoryInput, stored: DirectoryAccess): DirectoryUpdate | 'conflict' | null {
  const { memberDirectory, memberDirectoryAccess } = input
  if (memberDirectoryAccess !== undefined) {
    const enabled = memberDirectoryAccess === 'ALLOWED'
    if (memberDirectory !== undefined && memberDirectory !== enabled) return 'conflict'
    return { memberDirectoryAccess, memberDirectoryEnabled: enabled }
  }
  if (memberDirectory === undefined) return null
  if (memberDirectory) return { memberDirectoryAccess: 'ALLOWED', memberDirectoryEnabled: true }
  return { memberDirectoryAccess: stored === 'ALLOWED' ? 'NOT_ALLOWED' : stored, memberDirectoryEnabled: false }
}

/** D8: both bounds present and min > max. */
export function isAgeRangeInverted(range: { min?: number | null; max?: number | null } | null | undefined): boolean {
  if (!range) return false
  const { min, max } = range
  return min != null && max != null && min > max
}

export const AGE_RANGE_INVERTED_MESSAGE = 'Minimum age must not exceed maximum age'
export const DIRECTORY_CONFLICT_MESSAGE = 'memberDirectory conflicts with memberDirectoryAccess'
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/group-fields.test.ts` → PASS

- [ ] **Step 5: Write the failing request test** — `server/src/routes/__tests__/groups-edit-fields.request.test.ts`. Copy the mock block, `app()` and `row()` from `server/src/routes/__tests__/groups-browse-fields.request.test.ts` lines 1–96 **verbatim** (the `vi.hoisted` prismaMock, every `vi.mock(...)`, `import groupsRoutes from '../groups.js'`, `function app()`, `const row = ...`, and the `beforeEach` with `vi.clearAllMocks()`), change the header comment to `ui2-groups-edit SC1–SC3 (D7, D8, D12): PATCH /api/groups/:id directory access + age range`, then add:

```ts
import { groupManageFilter } from '../../services/permission.js'

const patch = (body: Record<string, unknown>) => request(app()).patch('/api/groups/g1').send(body)
const updateData = () => prismaMock.group.update.mock.calls[0][0].data

describe('PATCH memberDirectoryAccess (SC1, D7)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it.each([
    ['ALLOWED', true],
    ['NAMES_ONLY', false],
    ['NOT_ALLOWED', false],
  ])('%s writes the enum and the Boolean %s', async (access, enabled) => {
    const res = await patch({ memberDirectoryAccess: access })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ memberDirectoryAccess: access, memberDirectoryEnabled: enabled })
    expect(res.body.group).toMatchObject({ memberDirectoryAccess: access, memberDirectory: enabled })
  })

  it('rejects an unknown value with 400 and writes nothing', async () => {
    const res = await patch({ memberDirectoryAccess: 'SOMETIMES' })
    expect(res.status).toBe(400)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('400s when memberDirectory disagrees with memberDirectoryAccess', async () => {
    const res = await patch({ memberDirectory: true, memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'memberDirectory conflicts with memberDirectoryAccess' })
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('accepts both when they agree', async () => {
    const res = await patch({ memberDirectory: false, memberDirectoryAccess: 'NOT_ALLOWED' })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ memberDirectoryAccess: 'NOT_ALLOWED', memberDirectoryEnabled: false })
  })
})

describe('PATCH memberDirectory alone (SC3, D12)', () => {
  beforeEach(() => {
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it('false keeps a stored NAMES_ONLY', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' }))
    const res = await patch({ name: 'Renamed', memberDirectory: false })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ name: 'Renamed', memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' })
  })

  it('false on a stored ALLOWED → NOT_ALLOWED', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    await patch({ memberDirectory: false })
    expect(updateData()).toMatchObject({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NOT_ALLOWED' })
  })

  it('true → ALLOWED, even from NAMES_ONLY', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row({ memberDirectoryEnabled: false, memberDirectoryAccess: 'NAMES_ONLY' }))
    await patch({ memberDirectory: true })
    expect(updateData()).toMatchObject({ memberDirectoryEnabled: true, memberDirectoryAccess: 'ALLOWED' })
  })

  it('leaves both columns alone when neither key is sent', async () => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    await patch({ name: 'Renamed' })
    expect(updateData()).not.toHaveProperty('memberDirectoryAccess')
    expect(updateData()).not.toHaveProperty('memberDirectoryEnabled')
  })
})

describe('PATCH ageRange (SC2, D8)', () => {
  beforeEach(() => {
    prismaMock.group.findFirst.mockResolvedValue(row())
    prismaMock.group.update.mockImplementation(async ({ data }: { data: Record<string, unknown> }) => row(data))
  })

  it('400s on min > max and writes nothing', async () => {
    const res = await patch({ ageRange: { min: 30, max: 20 } })
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Minimum age must not exceed maximum age' })
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })

  it('accepts equal bounds', async () => {
    const res = await patch({ ageRange: { min: 30, max: 30 } })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: 30, ageRangeMax: 30 })
  })

  it('accepts a partial range (one bound null)', async () => {
    const res = await patch({ ageRange: { min: 30, max: null } })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: 30, ageRangeMax: null })
  })

  it('clears both bounds with ageRange: null', async () => {
    const res = await patch({ ageRange: null })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ ageRangeMin: null, ageRangeMax: null })
  })

  it('clears maxMembers and description with null', async () => {
    const res = await patch({ maxMembers: null })
    expect(res.status).toBe(200)
    expect(updateData()).toMatchObject({ maxMembers: null })
    prismaMock.group.update.mockClear()
    await patch({ description: null })
    expect(updateData()).toMatchObject({ description: null })
  })
})

describe('PATCH scope', () => {
  it('404s for a caller who cannot manage the group (groupManageFilter finds nothing)', async () => {
    vi.mocked(groupManageFilter).mockResolvedValueOnce({ id: '__none__' } as never)
    prismaMock.group.findFirst.mockResolvedValue(null)
    const res = await patch({ memberDirectoryAccess: 'NAMES_ONLY' })
    expect(res.status).toBe(404)
    expect(prismaMock.group.update).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 6: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/groups-edit-fields.request.test.ts` → FAIL: the enum is stripped (`memberDirectoryAccess` absent from update data), the conflict and inverted-range cases return 200, and the D12 NAMES_ONLY case writes NOT_ALLOWED.

- [ ] **Step 7: Wire the route** — in `server/src/routes/groups.ts`:

Add the import beside the other service imports (after line 14):

```ts
import {
  AGE_RANGE_INVERTED_MESSAGE,
  DIRECTORY_CONFLICT_MESSAGE,
  type DirectoryAccess,
  directoryWrite,
  isAgeRangeInverted,
} from '../services/group-fields.js'
```

In the PATCH zod object, directly under `memberDirectory: z.boolean().optional(),`:

```ts
      // ui2-groups-edit D7: the three-state directory access; the Boolean follows it.
      memberDirectoryAccess: z.enum(['ALLOWED', 'NAMES_ONLY', 'NOT_ALLOWED']).optional(),
```

Directly after `const body = schema.parse(req.body)`:

```ts
    // ui2-groups-edit D8: an inverted range is rejected before anything is read or written.
    if (isAgeRangeInverted(body.ageRange)) {
      return res.status(400).json({ success: false, error: AGE_RANGE_INVERTED_MESSAGE })
    }
```

Replace the three lines that write the directory pair today:

```ts
    if (body.memberDirectory !== undefined) updateData.memberDirectoryEnabled = body.memberDirectory
    // ui2-groups-browse D11: a Boolean-only write sets the enum to match (child 2 adds the enum write).
    if (body.memberDirectory !== undefined) {
      updateData.memberDirectoryAccess = body.memberDirectory ? 'ALLOWED' : 'NOT_ALLOWED'
    }
```

with:

```ts
    // ui2-groups-edit D7 + D12: the enum and the Boolean move together; a Boolean-only `false`
    // keeps a stored NAMES_ONLY (LeaderApp and iPhone 1.0 send `memberDirectory` on every save).
    const directory = directoryWrite(
      { memberDirectory: body.memberDirectory, memberDirectoryAccess: body.memberDirectoryAccess },
      existingGroup.memberDirectoryAccess as DirectoryAccess
    )
    if (directory === 'conflict') {
      return res.status(400).json({ success: false, error: DIRECTORY_CONFLICT_MESSAGE })
    }
    if (directory) {
      updateData.memberDirectoryAccess = directory.memberDirectoryAccess
      updateData.memberDirectoryEnabled = directory.memberDirectoryEnabled
    }
```

- [ ] **Step 8: Run it and watch it pass** — `cd server && npx vitest run src/routes/__tests__/groups-edit-fields.request.test.ts src/routes/__tests__/groups-browse-fields.request.test.ts src/services/__tests__/group-fields.test.ts` → PASS (the browse file's three D11 cases still pass: its stored row is ALLOWED). Then `cd server && npx tsc --noEmit` → no errors. `docker restart makeready-server` only if the container serves this checkout (a fleet worktree's does not — skip and say so).

- [ ] **Step 9: Commit** — `feat(ui2-groups-edit): PATCH group accepts memberDirectoryAccess, keeps Names only, rejects inverted age range`

### Task 2: Fixture values on the rich group (T5) + contract freeze
App: server
Phase: 1
Recipe: `server/fixtures/README.md` (fixtures house rule) — SPEC §server T5, F6 · tiny

> **build-time risk (F6):** browse's fixture tests may assert the rich group's defaults (`server/fixtures/__tests__/`) — adjust them in this task. Known: `server/fixtures/__tests__/groups-browse.db.test.ts:34` asserts every fixture group is `ALLOWED`; after this task the rich group is `NAMES_ONLY`.

**Files:**
- Modify: `server/fixtures/screens/groups-detail.ts` (exports + the top of `full()`)
- Modify: `server/fixtures/__tests__/groups-browse.test.ts`
- Modify: `server/fixtures/__tests__/groups-browse.db.test.ts:28-35`
- Modify: `docs/features/ui2-groups-edit/MANIFEST.md` (via `advance.mjs`, Step 6)

**Interfaces:**
- Consumes: `RICH_GROUP_ID`, `FIXTURE_EMPTY_GROUP_ID`.
- Produces: `RICH_GROUP_FIELDS` (exported) — the walk opens every edit page on these stored values: description `"Men meeting Tuesday mornings to read the Gospels together."`, age 26–35 (the "26 - 35" preset), maximum members 40, directory `NAMES_ONLY` with `memberDirectoryEnabled: false`. Empty Group keeps every default.

- [ ] **Step 1: Write the failing unit test** — append to `server/fixtures/__tests__/groups-browse.test.ts` (and add `RICH_GROUP_FIELDS` to its `../screens/groups-detail.js` import):

```ts
describe('groups-detail rich group fields (ui2-groups-edit T5, F6)', () => {
  it('stores a value in every edited field, in step with each other', () => {
    expect(RICH_GROUP_FIELDS).toEqual({
      description: 'Men meeting Tuesday mornings to read the Gospels together.',
      ageRangeMin: 26,
      ageRangeMax: 35,
      maxMembers: 40,
      memberDirectoryAccess: 'NAMES_ONLY',
      memberDirectoryEnabled: false,
    })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/groups-browse.test.ts` → FAIL, "RICH_GROUP_FIELDS is not exported" / undefined

- [ ] **Step 3: Write the layer change** — in `server/fixtures/screens/groups-detail.ts`, add to the header comment's bullet list:

```ts
 *  - Settings (ui2-groups-edit T5): the rich group stores a description, age 26–35, a 40-member cap
 *    and Names-only directory access, so every edit page opens on a stored value; Empty Group keeps
 *    the defaults.
```

below `export const RICH_GROUP_ID = FIXTURE_GROUP_IDS[0]` add:

```ts
/** ui2-groups-edit T5: the rich group's stored settings (age 26–35 is the "26 - 35" preset). */
export const RICH_GROUP_FIELDS = {
  description: 'Men meeting Tuesday mornings to read the Gospels together.',
  ageRangeMin: 26,
  ageRangeMax: 35,
  maxMembers: 40,
  memberDirectoryAccess: 'NAMES_ONLY',
  memberDirectoryEnabled: false,
} as const
```

and as the first statement after the `const [ruth, esther] = …` / `const requestedAt = …` lines in `full()`:

```ts
  // Settings (ui2-groups-edit T5): a stored value behind every edit page.
  await prisma.group.update({ where: { id: RICH_GROUP_ID }, data: RICH_GROUP_FIELDS })
```

- [ ] **Step 4: Update the db test** — in `server/fixtures/__tests__/groups-browse.db.test.ts`, import `RICH_GROUP_FIELDS` from `../screens/groups-detail.js` and replace

```ts
    expect(groups.every((g) => g.memberDirectoryAccess === 'ALLOWED')).toBe(true)
```

with

```ts
    // ui2-groups-edit T5: the rich group is Names only; every other group keeps the default.
    expect(groups.filter((g) => g.id !== RICH_GROUP_ID).every((g) => g.memberDirectoryAccess === 'ALLOWED')).toBe(true)
```

and add a case inside the same `describe`:

```ts
  it('stores the rich group settings and leaves the Empty Group on defaults (ui2-groups-edit T5)', async () => {
    const rich = await db.prisma.group.findUniqueOrThrow({ where: { id: RICH_GROUP_ID } })
    expect(rich).toMatchObject(RICH_GROUP_FIELDS)
    const empty = await db.prisma.group.findUniqueOrThrow({ where: { id: FIXTURE_EMPTY_GROUP_ID } })
    expect(empty).toMatchObject({
      description: null,
      ageRangeMin: null,
      ageRangeMax: null,
      maxMembers: null,
      memberDirectoryAccess: 'ALLOWED',
      memberDirectoryEnabled: true,
    })
  })
```

- [ ] **Step 5: Run it and watch it pass** — `cd server && npx vitest run fixtures/__tests__/groups-browse.test.ts fixtures/__tests__/groups-browse.db.test.ts` → PASS (the db file prints its skip line when `FIXTURES_TEST_DATABASE_URL` is unset — say so in the report); `cd server && npx tsc --noEmit -p fixtures` → no errors; `cd server && npm run test:run` → PASS.

- [ ] **Step 6: Commit, then freeze the contract** — commit `feat(ui2-groups-edit): rich fixture group stores a value in every edited setting`. This is the producer phase's last task: record the freeze so no consumer task starts against an open contract:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/5.4.0/scripts/advance.mjs docs/features/ui2-groups-edit --set "contract=frozen $(date +%F)" --head --commit "chore(ui2-groups-edit): contract frozen"
```

### Task 3: C-066 destructive row tone (T6, D13)
App: iphone
Phase: 2
Recipe: `/ui2-resolve` (a UI 2.0 component fix) — SPEC D13, F4, F7 · tiny

> **build-time risk (F7):** re-capture C-066 after the tone change and diff it against its frozen snapshot — the default tone must be pixel-identical.

**Files:**
- Modify: `iphone/MakeReadyUI/ActionMenuOverlay.swift:43-47` (ActionItem), `:93` (row construction)
- Create: `iphone/MakeReadyCaptureTests/ActionMenuToneTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration, Step 2)

**Interfaces:**
- Consumes: `ActionMenuRow.Tone` (`.standard`, `.destructive`) — `iphone/MakeReadyUI/ActionMenuRow.swift:18-21`.
- Produces: `ActionMenuOverlay.ActionItem(glyph: String, label: String, tone: ActionMenuRow.Tone = .standard)` — every existing `.init(glyph:label:)` call compiles unchanged.

- [ ] **Step 1: Write the failing test** — `iphone/MakeReadyCaptureTests/ActionMenuToneTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-edit D13: C-066 rows carry C-067's tone; the default keeps the frozen look.
final class ActionMenuToneTests: XCTestCase {
    func testActionItemDefaultsToStandardTone() {
        XCTAssertEqual(ActionMenuOverlay.ActionItem(glyph: "c066-record", label: "Record a video").tone, .standard)
    }

    func testActionItemCarriesADestructiveTone() {
        let item = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Delete Alpha", tone: .destructive)
        XCTAssertEqual(item.tone, .destructive)
    }
}
```

- [ ] **Step 2: Register the test file** — from the repo root:

```bash
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
t = p.targets.find { |x| x.name == "MakeReadyCaptureTests" }
anchor = p.files.find { |f| f.path.to_s.end_with?("GroupStoresTests.swift") }
ref = anchor.parent.new_reference(File.expand_path("iphone/MakeReadyCaptureTests/ActionMenuToneTests.swift"))
t.add_file_references([ref])
p.save'
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "value of type 'ActionMenuOverlay.ActionItem' has no member 'tone'" / "extra argument 'tone' in call"

- [ ] **Step 4: Add the tone** — in `iphone/MakeReadyUI/ActionMenuOverlay.swift` replace the `ActionItem` struct with:

```swift
    /// C-066 §4: one entry of `actions: [ActionItem]`. Its fields are C-067's own §4 props —
    /// the container supplies each row's content and nothing else.
    struct ActionItem: Identifiable {
        let glyph: String
        let label: String
        /// ui2-groups-edit D13: C-067 §4 `tone`. Default `.standard` keeps the frozen C-066 snapshot.
        // GAP — C-066 §4 lists no `tone` on ActionItem; routed to /ui2-resolve C-066 (ui2-groups-edit F4).
        var tone: ActionMenuRow.Tone = .standard

        var id: String { "\(glyph)|\(label)" }
    }
```

and the row construction in `actionsList` with:

```swift
                ActionMenuRow(glyph: action.glyph, label: action.label, tone: action.tone) { onSelect(action) }
```

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 6: Pixel check C-066 (F7)** — when the capture server answers (`curl -sf localhost:5951/api/compare/manifest >/dev/null`), run `node capture/runners/ui2/capture.mjs C-066 '*'` and `node capture/runners/compare/diff.mjs` for the C-066 comparison; the default-tone render must match its pre-change render (no hot bands). When capture is not up (the fleet worktree has none), record "C-066 recapture not run — capture down; default tone path unchanged (same `ActionMenuRow` default)" in the report; the walk's Add-menu item re-checks the look.

- [ ] **Step 7: Commit** — `feat(ui2-groups-edit): C-066 action rows carry C-067's tone`

### Task 4: GroupPatch + GroupActions.updateGroup(id:patch:) (T3, D6)
App: iphone
Phase: 2
Recipe: `/ios-error-surface` (failures keep their HTTP status for the container) — SPEC D5, D6, T3

**Files:**
- Modify: `iphone/MakeReady/State/Models/GroupModels.swift` (append `GroupPatch` after `AgeRange`, ~line 118)
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift` (add `updateGroup(id:patch:)` after the existing `updateGroup(...)`, ~line 252)
- Create: `iphone/MakeReadyCaptureTests/GroupPatchTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration, Step 2)

**Interfaces:**
- Consumes: `APIClientProtocol.requestWithStatus(endpoint:method:body:)` (throws `APIError.unauthorized` on 401, `APIHTTPError(status:message:)` on any other non-2xx); `GroupResponse`; `upsertKeepingOrganization(_:)`.
- Produces:
  - `enum GroupPatch: Equatable { case name(String); case description(String?); case isPrivate(Bool); case ageRange(AgeRange?); case maxMembers(Int?); case memberDirectoryAccess(String) }` with `var body: [String: Any]` — exactly one key; `nil` → JSON `null`; an `AgeRange` bound `nil` → `null`.
  - `GroupActions.updateGroup(id: String, patch: GroupPatch) async throws -> UserGroup` (`@MainActor`) — merges the response into `AppState.groups` keeping the cached org; the existing labelled `updateGroup(id:name:…)` is unchanged.

- [ ] **Step 1: Write the failing tests** — `iphone/MakeReadyCaptureTests/GroupPatchTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-edit D6/T3: one key per request; nil reaches the server as JSON null.
@MainActor
final class GroupPatchTests: XCTestCase {
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

    private func json(_ patch: GroupPatch) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: patch.body, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func testEachPatchEncodesOneKey() throws {
        XCTAssertEqual(try json(.name("Alpha")), #"{"name":"Alpha"}"#)
        XCTAssertEqual(try json(.description("Hi")), #"{"description":"Hi"}"#)
        XCTAssertEqual(try json(.description(nil)), #"{"description":null}"#)
        XCTAssertEqual(try json(.isPrivate(true)), #"{"isPrivate":true}"#)
        XCTAssertEqual(try json(.maxMembers(40)), #"{"maxMembers":40}"#)
        XCTAssertEqual(try json(.maxMembers(nil)), #"{"maxMembers":null}"#)
        XCTAssertEqual(try json(.memberDirectoryAccess("NAMES_ONLY")), #"{"memberDirectoryAccess":"NAMES_ONLY"}"#)
    }

    func testAgeRangeEncodesNullRangeAndNullBounds() throws {
        XCTAssertEqual(try json(.ageRange(nil)), #"{"ageRange":null}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 26, max: 35))), #"{"ageRange":{"max":35,"min":26}}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: 18, max: nil))), #"{"ageRange":{"max":null,"min":18}}"#)
        XCTAssertEqual(try json(.ageRange(AgeRange(min: nil, max: 50))), #"{"ageRange":{"max":50,"min":null}}"#)
    }

    private let groupJSON = #"{"id":"g1","code":"ABC123","name":"Alpha","description":null,"isPrivate":false,"allowInvites":true,"memberDirectory":false,"memberDirectoryAccess":"NAMES_ONLY","ageRange":null,"maxMembers":null,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-01T10:00:00Z","updatedAt":"2026-10-27T10:00:00Z"}"#

    func testUpdateGroupSendsThePatchAndMergesKeepingTheOrg() async throws {
        state.groups.upsert(UserGroup(id: "g1", code: "ABC123", name: "Alpha", isPrivate: false, allowInvites: true,
                                      maxMembers: 40, memberCount: 3, creatorId: "u1", organizationId: "o1",
                                      organizationName: "Grace Church", memberDirectoryAccess: "ALLOWED",
                                      createdAt: Date(), updatedAt: Date()))
        api.stub("PATCH", "/api/groups/g1", json: #"{"success":true,"group":"# + groupJSON + "}")
        let group = try await GroupActions(api: api, state: state).updateGroup(id: "g1", patch: .memberDirectoryAccess("NAMES_ONLY"))
        XCTAssertEqual(api.calls.last?.method, "PATCH")
        XCTAssertEqual(api.calls.last?.body?["memberDirectoryAccess"] as? String, "NAMES_ONLY")
        XCTAssertEqual(api.calls.last?.body?.count, 1)
        XCTAssertEqual(group.memberDirectoryAccess, "NAMES_ONLY")
        XCTAssertNil(state.groups["g1"]?.maxMembers)                 // the response wins
        XCTAssertEqual(state.groups["g1"]?.organizationId, "o1")     // the cached org is kept
    }

    func testUpdateGroupKeepsTheHTTPStatusOfAFailure() async {
        api.errorFor = { _, _ in APIHTTPError(status: 404, message: "Group not found") }
        do {
            _ = try await GroupActions(api: api, state: state).updateGroup(id: "g1", patch: .name("Beta"))
            XCTFail("expected a throw")
        } catch {
            XCTAssertEqual(error as? APIHTTPError, APIHTTPError(status: 404, message: "Group not found"))
        }
    }
}
```

- [ ] **Step 2: Register the test file** — from the repo root:

```bash
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
t = p.targets.find { |x| x.name == "MakeReadyCaptureTests" }
anchor = p.files.find { |f| f.path.to_s.end_with?("GroupStoresTests.swift") }
ref = anchor.parent.new_reference(File.expand_path("iphone/MakeReadyCaptureTests/GroupPatchTests.swift"))
t.add_file_references([ref])
p.save'
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "cannot find type 'GroupPatch' in scope"

- [ ] **Step 4: Write `GroupPatch`** — append to `iphone/MakeReady/State/Models/GroupModels.swift`, after the `AgeRange` struct:

```swift
/// ui2-groups-edit D6: one group field's PATCH. The iPhone sends one key per request, so a case
/// is the "sent" state, its `nil` payload the "null" state, and every other key stays absent.
enum GroupPatch: Equatable {
    case name(String)
    case description(String?)
    case isPrivate(Bool)
    /// nil clears both bounds; a nil bound inside is sent as null.
    case ageRange(AgeRange?)
    /// nil = no limit.
    case maxMembers(Int?)
    /// "ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED" (D7).
    case memberDirectoryAccess(String)

    /// The request body. `JSONSerialization` writes `NSNull` as `null`.
    var body: [String: Any] {
        switch self {
        case .name(let v): return ["name": v]
        case .description(let v): return ["description": Self.json(v)]
        case .isPrivate(let v): return ["isPrivate": v]
        case .ageRange(let range):
            guard let range else { return ["ageRange": NSNull()] }
            return ["ageRange": ["min": Self.json(range.min), "max": Self.json(range.max)]]
        case .maxMembers(let v): return ["maxMembers": Self.json(v)]
        case .memberDirectoryAccess(let v): return ["memberDirectoryAccess": v]
        }
    }

    private static func json<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }
}
```

- [ ] **Step 5: Write the Action** — in `iphone/MakeReady/State/Actions/GroupActions.swift`, directly after the existing labelled `updateGroup(...)` (before `// MARK: - Delete Group`):

```swift
    /// ui2-groups-edit D5/D6: one field's PATCH. Uses the status-keeping request so the edit page
    /// can tell a 404 (the group is gone or out of scope) from a failure worth retrying; a 401
    /// still throws `APIError.unauthorized`. Merges the response, keeping the cached org (D10 of
    /// ui2-groups-browse — the PATCH response carries none).
    @MainActor
    func updateGroup(id: String, patch: GroupPatch) async throws -> UserGroup {
        let data = try await api.requestWithStatus(endpoint: "/api/groups/\(id)", method: "PATCH", body: patch.body)
        let response = try JSONDecoder.apiDecoder.decode(GroupResponse.self, from: data)
        guard response.success, let group = response.group else {
            throw APIError.serverError(response.error ?? "Failed to update group")
        }
        upsertKeepingOrganization(group)
        state.persist()
        return state.groups[group.id] ?? group
    }
```

- [ ] **Step 6: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS (GroupPatchTests and the existing GroupActionsLoadersTests); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 7: Commit** — `feat(ui2-groups-edit): GroupPatch and a one-key updateGroup that can clear fields`

### Task 5: deleteGroup clears every group-keyed store (T4, D10)
App: iphone
Phase: 2
Recipe: iphone `CLAUDE.md` §State Management ("a mutating Action refreshes the derived state in the same call") — SPEC D10, T4

**Files:**
- Modify: `iphone/MakeReady/State/Actions/GroupActions.swift:258-286` (`deleteGroup`)
- Create: `iphone/MakeReadyCaptureTests/GroupDeleteCleanupTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (test file registration, Step 2)

**Interfaces:**
- Consumes: the stores at `AppState.swift:154` (`memberGroupsById`), `:164-176` (`nextStudyByGroupId`, `historyByGroupId`, `groupDaysByGroupId`, `groupChartByGroupId`), `:264` (`pendingJoinRequestsByGroupId`), `:294` (`groupInvitesByGroupId`), `dashboard.following` (`HomeFollowingResponse.programs[].groups[]` of `HomeFollowedGroup`, keyed by `enrollmentId`), `groupEnrollmentIndex`.
- Produces: `GroupActions.forgetGroup(id: String)` (`@MainActor`, no network) — the D10 local cleanup, also used by the edit page's 404 path (Task 7); `deleteGroup(id:)` = `DELETE /api/groups/:id` then `forgetGroup(id:)`.

> Ruling (plan, D10): there is no `loadFollowing` loader — Home's following comes from `DashboardActions.refresh()` — and `HomeFollowedGroup` carries `enrollmentId`, not a group id. D10's "refetch following when it lists the group" is met by removing, from the cached `dashboard.following`, every followed group whose `enrollmentId` belongs to the deleted group (read from `groupEnrollmentIndex` before it is cleared), and dropping a program left with no groups by that removal. The next dashboard refresh replaces it from the server either way.

- [ ] **Step 1: Write the failing tests** — `iphone/MakeReadyCaptureTests/GroupDeleteCleanupTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-edit D10/T4: a deleted group leaves no row behind in any store keyed by or listing it.
@MainActor
final class GroupDeleteCleanupTests: XCTestCase {
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

    private func group(_ id: String) -> UserGroup {
        UserGroup(id: id, code: "ABC123", name: id, isPrivate: false, allowInvites: true, memberCount: 0,
                  creatorId: "u1", createdAt: Date(), updatedAt: Date())
    }

    private func seed() {
        state.groups.upsert(group("g1"))
        state.groups.upsert(group("g2"))
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")
        state.nextStudyByGroupId["g1"] = NextStudy(id: "s1", dayNumber: 3, title: "Faith over fear")
        state.historyByGroupId["g1"] = [GroupHistoryEvent(id: "h1", text: "Held event")]
        state.groupDaysByGroupId["g1"] = [HomeDay(day: "2026-10-25", sessionSeconds: 60)]
        state.groupChartByGroupId["g1"] = GroupChart(scheduled: ["2026-10-25": 3], completed: [:])
        state.pendingJoinRequestsByGroupId["g1"] = []
        state.nextStudyByGroupId["g2"] = NextStudy(id: "s2", dayNumber: 1, title: "Keep me")
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1", name: "g1"), MemberGroupItem(id: "g2", name: "g2")]
        state.memberGroupsById["m2"] = [MemberGroupItem(id: "g1", name: "g1")]
        state.dashboard.following = HomeFollowingResponse(programs: [
            HomeFollowedProgram(id: "p1", title: "Only g1", groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "g1")]),
            HomeFollowedProgram(id: "p2", title: "Both", groups: [HomeFollowedGroup(enrollmentId: "e1", groupName: "g1"),
                                                                    HomeFollowedGroup(enrollmentId: "e9", groupName: "g2")]),
        ])
    }

    func testForgetGroupClearsEveryStoreForThatGroupOnly() {
        seed()
        GroupActions(api: api, state: state).forgetGroup(id: "g1")
        XCTAssertNil(state.groups["g1"])
        XCTAssertNotNil(state.groups["g2"])
        XCTAssertNil(state.nextStudyByGroupId["g1"])
        XCTAssertNil(state.historyByGroupId["g1"])
        XCTAssertNil(state.groupDaysByGroupId["g1"])
        XCTAssertNil(state.groupChartByGroupId["g1"])
        XCTAssertNil(state.pendingJoinRequestsByGroupId["g1"])
        XCTAssertNil(state.groupInvitesByGroupId["g1"])
        XCTAssertEqual(state.nextStudyByGroupId["g2"]?.title, "Keep me")
        XCTAssertEqual(state.memberGroupsById["m1"]?.map(\.id), ["g2"])
        XCTAssertEqual(state.memberGroupsById["m2"]?.map(\.id), [])
        XCTAssertEqual(state.dashboard.following?.programs.map(\.id), ["p2"])
        XCTAssertEqual(state.dashboard.following?.programs.first?.groups.map(\.enrollmentId), ["e9"])
        XCTAssertTrue(state.groupEnrollmentIndex.get("g1").isEmpty)
    }

    func testDeleteGroupCallsDeleteThenForgets() async throws {
        seed()
        api.stub("DELETE", "/api/groups/g1", json: #"{"success":true,"message":"Group deleted"}"#)
        try await GroupActions(api: api, state: state).deleteGroup(id: "g1")
        XCTAssertEqual(api.callCount("DELETE", "/api/groups/g1"), 1)
        XCTAssertNil(state.groups["g1"])
        XCTAssertNil(state.nextStudyByGroupId["g1"])
    }

    func testAFailedDeleteKeepsEverything() async {
        seed()
        api.errorToThrow = APIError.serverError("Failed to delete group")
        do {
            try await GroupActions(api: api, state: state).deleteGroup(id: "g1")
            XCTFail("expected a throw")
        } catch {}
        XCTAssertNotNil(state.groups["g1"])
        XCTAssertNotNil(state.nextStudyByGroupId["g1"])
    }
}
```

If `NextStudy`, `GroupHistoryEvent`, `HomeDay` or `GroupChart` initialisers differ from the ones above, copy the exact initialiser calls `iphone/MakeReadyCaptureTests/GroupStoresTests.swift:22-26` uses (that file compiles today).

- [ ] **Step 2: Register the test file** — from the repo root:

```bash
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
t = p.targets.find { |x| x.name == "MakeReadyCaptureTests" }
anchor = p.files.find { |f| f.path.to_s.end_with?("GroupStoresTests.swift") }
ref = anchor.parent.new_reference(File.expand_path("iphone/MakeReadyCaptureTests/GroupDeleteCleanupTests.swift"))
t.add_file_references([ref])
p.save'
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "value of type 'GroupActions' has no member 'forgetGroup'"

- [ ] **Step 4: Split `deleteGroup`** — replace the body of `deleteGroup(id:)` from `// Remove from state` to its closing brace with a call to a new `forgetGroup(id:)`:

```swift
    /// Delete a group (server archives it: `isActive = false`), then forget it locally (D10).
    @MainActor
    func deleteGroup(id: String) async throws {
        let groupName = state.groups[id]?.name ?? id

        let response: APISuccessResponse = try await api.delete("/api/groups/\(id)", responseType: APISuccessResponse.self)

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete group")
        }

        forgetGroup(id: id)
        Log.state.info("GroupActions: deleted group \(groupName, privacy: .private)")
    }

    /// ui2-groups-edit D10: drop a group from every store keyed by or listing it, so nothing
    /// stale stays tappable — the entity stores and indexes, the group page's stores, each
    /// member's group list, and Home's followed groups (matched by the group's enrollment ids,
    /// read before the index is cleared). Local only: also the edit page's 404 path (D5).
    @MainActor
    func forgetGroup(id: String) {
        let enrollmentIds = Set(state.groupEnrollmentIndex.get(id))

        state.groups.remove(id)

        let postIds = state.groupPostIndex.get(id)
        state.posts.removeMany(postIds)
        state.groupPostIndex.removeAll(parentId: id)

        let memberIds = state.groupMemberIndex.get(id)
        state.members.removeMany(memberIds)
        state.groupMemberIndex.removeAll(parentId: id)

        state.enrollments.removeMany(Array(enrollmentIds))
        state.groupEnrollmentIndex.removeAll(parentId: id)

        state.nextStudyByGroupId[id] = nil
        state.historyByGroupId[id] = nil
        state.groupDaysByGroupId[id] = nil
        state.groupChartByGroupId[id] = nil
        state.pendingJoinRequestsByGroupId[id] = nil
        state.groupInvitesByGroupId[id] = nil

        for (memberId, items) in state.memberGroupsById where items.contains(where: { $0.id == id }) {
            state.memberGroupsById[memberId] = items.filter { $0.id != id }
        }

        if var following = state.dashboard.following {
            following.programs = following.programs.compactMap { program in
                let kept = program.groups.filter { !enrollmentIds.contains($0.enrollmentId) }
                guard kept.count != program.groups.count else { return program }
                guard !kept.isEmpty else { return nil }
                var trimmed = program
                trimmed.groups = kept
                return trimmed
            }
            state.dashboard.following = following
        }

        state.persist()
    }
```

The old `NSLog("👥 GroupActions: Deleted group '\(groupName)'")` line goes (SwiftLint forbids new `NSLog`; `Log.state` is the wrapper in `Utilities/Log.swift`). If `state.enrollments.removeMany` takes a `[String]`, keep `Array(enrollmentIds)`; if it takes a `Set`, pass `enrollmentIds`.

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 6: Commit** — `feat(ui2-groups-edit): deleting a group clears every store that lists it`

### Task 6: GroupField + GroupFieldEditModel (D1–D5)
App: iphone
Phase: 2
Recipe: `/push-page` (read for the edit-page pattern; this task is the pure model only) — SPEC D1, D2, D3, D4, D5, §iphone Model

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditor.swift`
- Create: `iphone/MakeReadyCaptureTests/GroupFieldEditorTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Step 2 — app source + test file)

**Interfaces:**
- Consumes: `UserGroup`, `AgeRange`, `GroupPatch` (Task 4), `GroupDetailMapper.directoryAccessLabel(_:memberDirectory:)` (`GroupDetailMapper.swift:139`), the built screens' `State` structs (`EditTextSingleFieldScreen.State`, `EditTextMultiFieldScreen.State`, `EditOptionFieldScreen.State`, `EditOptionsCustomFieldScreen.State`), `GroupActions.isCancellation(_:)`, `AuthStatusPolicy.shouldSignOut(after:)`, `APIHTTPError`.
- Produces:
  - `enum GroupField: String, Hashable, CaseIterable { case name, description, visibility, ageRange, maxMembers, directoryAccess }` with `init?(label: String)`.
  - `enum GroupFieldPage { case textSingle(EditTextSingleFieldScreen.State, canSave: (String) -> Bool); case textMulti(EditTextMultiFieldScreen.State); case option(EditOptionFieldScreen.State); case ageRange(EditOptionsCustomFieldScreen.State) }`
  - `enum GroupFieldInput { case text(String); case option(String); case ageRange(minimum: String, maximum: String) }`
  - `enum GroupSaveFailure: Equatable { case cancelled, signOut, gone, retry }`
  - `enum GroupFieldEditModel` with `static let saveFailedMessage = "Couldn't save. Try again."`, `static func title(_:) -> String`, `static func description(_:) -> String`, `static func page(_ field: GroupField, group: UserGroup, saving: Bool, errorMessage: String) -> GroupFieldPage`, `static func nameCanSave(_ typed: String, stored: String) -> Bool`, `static func maxMembersCanSave(_ typed: String, stored: Int?) -> Bool`, `static func ageSelection(_ range: AgeRange?) -> String`, `static func patch(_ field: GroupField, _ input: GroupFieldInput) -> GroupPatch?`, `static func failure(for error: Error) -> GroupSaveFailure`.

- [ ] **Step 1: Write the failing tests** — `iphone/MakeReadyCaptureTests/GroupFieldEditorTests.swift`

```swift
import XCTest
@testable import MakeReady

/// ui2-groups-edit D1–D5: the group edit pages' pure rules.
final class GroupFieldEditorTests: XCTestCase {
    private func group(description: String? = "Men meeting Tuesday mornings.", isPrivate: Bool = true,
                       ageRange: AgeRange? = AgeRange(min: 26, max: 35), maxMembers: Int? = 40,
                       access: String? = "NAMES_ONLY") -> UserGroup {
        UserGroup(id: "g1", code: "ABC123", name: "Tuesday Men's Group", description: description, isPrivate: isPrivate,
                  allowInvites: true, memberDirectory: access == "ALLOWED", ageRange: ageRange, maxMembers: maxMembers,
                  memberCount: 8, creatorId: "u1", memberDirectoryAccess: access, createdAt: Date(), updatedAt: Date())
    }

    // MARK: D1

    func testLabelsMapToFieldsAndUnknownLabelsDoNothing() {
        XCTAssertEqual(GroupField(label: "Group name"), .name)
        XCTAssertEqual(GroupField(label: "Description"), .description)
        XCTAssertEqual(GroupField(label: "Visibility"), .visibility)
        XCTAssertEqual(GroupField(label: "Age"), .ageRange)
        XCTAssertEqual(GroupField(label: "Maximum members"), .maxMembers)
        XCTAssertEqual(GroupField(label: "Member directory access"), .directoryAccess)
        XCTAssertNil(GroupField(label: "Cover"))
    }

    // MARK: D2/D3 pages

    func testNamePage() {
        guard case let .textSingle(s, canSave) = GroupFieldEditModel.page(.name, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("name is a text-single page")
        }
        XCTAssertEqual(s.title, "Group name")
        XCTAssertEqual(s.text, "Tuesday Men's Group")
        XCTAssertEqual(s.loadedValue, "Tuesday Men's Group")
        XCTAssertEqual(s.maxLength, 200)
        XCTAssertFalse(s.allowsEmpty)
        XCTAssertFalse(s.showsAISuggestions)
        XCTAssertTrue(s.description.hasPrefix("The group name is the primary title"))
        XCTAssertFalse(canSave("Tuesday Men's Group"))
        XCTAssertFalse(canSave("  Tuesday Men's Group  "))          // trimmed = stored
        XCTAssertTrue(canSave("Thursday Men"))
    }

    func testNameCanSaveRules() {
        XCTAssertFalse(GroupFieldEditModel.nameCanSave("   ", stored: "A"))
        XCTAssertFalse(GroupFieldEditModel.nameCanSave(String(repeating: "x", count: 201), stored: "A"))
        XCTAssertTrue(GroupFieldEditModel.nameCanSave(String(repeating: "x", count: 200), stored: "A"))
    }

    func testDescriptionPage() {
        guard case let .textMulti(s) = GroupFieldEditModel.page(.description, group: group(description: nil), saving: false, errorMessage: "") else {
            return XCTFail("description is a text-multi page")
        }
        XCTAssertEqual(s.title, "Description")
        XCTAssertEqual(s.text, "")
        XCTAssertEqual(s.maxLength, 2000)
        XCTAssertFalse(s.showsAISuggestions)
    }

    func testVisibilityPage() {
        guard case let .option(s) = GroupFieldEditModel.page(.visibility, group: group(isPrivate: false), saving: false, errorMessage: "") else {
            return XCTFail("visibility is an option page")
        }
        XCTAssertEqual(s.title, "Visibility")
        XCTAssertEqual(s.options, ["Private", "Public"])
        XCTAssertEqual(s.optionDescriptions.count, 2)
        XCTAssertEqual(s.selectedOption, "Public")
        XCTAssertEqual(s.loadedValue, "Public")
    }

    func testDirectoryPage() {
        guard case let .option(s) = GroupFieldEditModel.page(.directoryAccess, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("directory is an option page")
        }
        XCTAssertEqual(s.title, "Member directory access")
        XCTAssertEqual(s.description, "Choose what members of this group can see about each other.")
        XCTAssertEqual(s.options, ["Allowed", "Names only", "Not allowed"])
        XCTAssertEqual(s.selectedOption, "Names only")
    }

    func testMaxMembersPage() {
        guard case let .textSingle(s, canSave) = GroupFieldEditModel.page(.maxMembers, group: group(), saving: false, errorMessage: "") else {
            return XCTFail("maxMembers is a text-single page")
        }
        XCTAssertEqual(s.title, "Maximum members")
        XCTAssertEqual(s.description, "The most members this group can have. Leave it blank for no limit.")
        XCTAssertEqual(s.text, "40")
        XCTAssertEqual(s.keyboard, .numberPad)
        XCTAssertTrue(s.allowsEmpty)
        XCTAssertFalse(canSave("40"))
        XCTAssertTrue(canSave("41"))
        XCTAssertTrue(canSave(""))
    }

    func testMaxMembersCanSaveRules() {
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("", stored: nil))     // Unlimited → Unlimited
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave("", stored: 40))       // → Unlimited
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("0", stored: nil))
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("4a", stored: nil))
        XCTAssertFalse(GroupFieldEditModel.maxMembersCanSave("-3", stored: nil))
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave("1", stored: nil))
        XCTAssertTrue(GroupFieldEditModel.maxMembersCanSave(" 12 ", stored: 40))
    }

    // MARK: D4 age range

    func testAgeSelectionFromStoredBounds() {
        XCTAssertEqual(GroupFieldEditModel.ageSelection(nil), "Any age")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: nil, max: nil)), "Any age")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 18, max: 25)), "18 - 25")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 26, max: 35)), "26 - 35")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 36, max: 50)), "36 - 50")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 30, max: nil)), "Custom range")
        XCTAssertEqual(GroupFieldEditModel.ageSelection(AgeRange(min: 20, max: 30)), "Custom range")
    }

    func testAgePage() {
        guard case let .ageRange(s) = GroupFieldEditModel.page(.ageRange, group: group(), saving: true, errorMessage: "") else {
            return XCTFail("age is an options-custom page")
        }
        XCTAssertEqual(s.title, "Age range")
        XCTAssertEqual(s.options, ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"])
        XCTAssertEqual(s.presetMinimums, [18, 26, 36])
        XCTAssertEqual(s.presetMaximums, [25, 35, 50])
        XCTAssertEqual(s.minimumLabel, "Minimum age")
        XCTAssertEqual(s.maximumLabel, "Maximum age")
        XCTAssertEqual(s.selectedOption, "26 - 35")
        XCTAssertEqual(s.minimum, "26")
        XCTAssertEqual(s.loadedMaximum, "35")
        XCTAssertTrue(s.saving)
    }

    // MARK: D2/D4 patches

    func testPatches() {
        XCTAssertEqual(GroupFieldEditModel.patch(.name, .text("  Alpha  ")), .name("Alpha"))
        XCTAssertEqual(GroupFieldEditModel.patch(.description, .text("  ")), .description(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.description, .text("Hello")), .description("Hello"))
        XCTAssertEqual(GroupFieldEditModel.patch(.visibility, .option("Private")), .isPrivate(true))
        XCTAssertEqual(GroupFieldEditModel.patch(.visibility, .option("Public")), .isPrivate(false))
        XCTAssertEqual(GroupFieldEditModel.patch(.maxMembers, .text("")), .maxMembers(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.maxMembers, .text("25")), .maxMembers(25))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Allowed")), .memberDirectoryAccess("ALLOWED"))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Names only")), .memberDirectoryAccess("NAMES_ONLY"))
        XCTAssertEqual(GroupFieldEditModel.patch(.directoryAccess, .option("Not allowed")), .memberDirectoryAccess("NOT_ALLOWED"))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "", maximum: "")), .ageRange(nil))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "26", maximum: "35")), .ageRange(AgeRange(min: 26, max: 35)))
        XCTAssertEqual(GroupFieldEditModel.patch(.ageRange, .ageRange(minimum: "30", maximum: "")), .ageRange(AgeRange(min: 30, max: nil)))
        XCTAssertNil(GroupFieldEditModel.patch(.name, .option("Private")))           // wrong input for the field
        XCTAssertNil(GroupFieldEditModel.patch(.visibility, .option("Sometimes")))
    }

    // MARK: D5 failures

    func testFailureClasses() {
        XCTAssertEqual(GroupFieldEditModel.failure(for: CancellationError()), .cancelled)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIError.unauthorized), .signOut)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIHTTPError(status: 404, message: "Group not found")), .gone)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIHTTPError(status: 400, message: "bad")), .retry)
        XCTAssertEqual(GroupFieldEditModel.failure(for: APIError.serverError("boom")), .retry)
    }
}
```

- [ ] **Step 2: Register both files** — from the repo root (the app source joins the MakeReady target beside `GroupDetailContainer.swift`; `capture-targets.rb` then adds it to MakeReadyCapture):

```bash
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
app = p.targets.find { |x| x.name == "MakeReady" }
tests = p.targets.find { |x| x.name == "MakeReadyCaptureTests" }
src_anchor = p.files.find { |f| f.path.to_s.end_with?("GroupDetailContainer.swift") }
src = src_anchor.parent.new_reference(File.expand_path("iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditor.swift"))
app.add_file_references([src])
test_anchor = p.files.find { |f| f.path.to_s.end_with?("GroupStoresTests.swift") }
test = test_anchor.parent.new_reference(File.expand_path("iphone/MakeReadyCaptureTests/GroupFieldEditorTests.swift"))
tests.add_file_references([test])
p.save'
ruby iphone/scripts/capture-targets.rb
```

Create an empty `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditor.swift` (`import Foundation`) first so the reference resolves.

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "cannot find 'GroupField' in scope"

- [ ] **Step 4: Write the model** — `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditor.swift`

```swift
import Foundation
import SwiftUI

/// ui2-groups-edit D1: the group page's six setting rows.
enum GroupField: String, Hashable, CaseIterable {
    case name, description, visibility, ageRange, maxMembers, directoryAccess

    /// D1: GroupsDetailScreen's row label → its field; any other label is nil (the tap does nothing).
    init?(label: String) {
        switch label {
        case "Group name": self = .name
        case "Description": self = .description
        case "Visibility": self = .visibility
        case "Age": self = .ageRange
        case "Maximum members": self = .maxMembers
        case "Member directory access": self = .directoryAccess
        default: return nil
        }
    }
}

/// D2: the built screen a field opens, with its State.
enum GroupFieldPage {
    case textSingle(EditTextSingleFieldScreen.State, canSave: (String) -> Bool)
    case textMulti(EditTextMultiFieldScreen.State)
    case option(EditOptionFieldScreen.State)
    case ageRange(EditOptionsCustomFieldScreen.State)
}

/// What an edit page hands back on Save.
enum GroupFieldInput {
    case text(String)
    case option(String)
    case ageRange(minimum: String, maximum: String)
}

/// D5: what a failed save does.
enum GroupSaveFailure: Equatable {
    /// The task was cancelled — nothing to show.
    case cancelled
    /// 401 — ui2-shell D27 sign-out.
    case signOut
    /// 404 — the group is gone or out of scope: forget it locally and pop to Groups.
    case gone
    /// Anything else — the inline line (the age page: the banner); the value is kept.
    case retry
}

/// ui2-groups-edit §iphone Model: each field's screen State from the cached group, the Save
/// rules the screens do not own, the one-key patch and the failure class. Pure —
/// `GroupFieldEditContainer` renders and saves.
enum GroupFieldEditModel {
    static let saveFailedMessage = "Couldn't save. Try again."

    static let visibilityOptions = ["Private", "Public"]
    static let directoryOptions = ["Allowed", "Names only", "Not allowed"]
    static let ageOptions = ["Any age", "18 - 25", "26 - 35", "36 - 50", "Custom range"]
    static let agePresetMinimums = [18, 26, 36]
    static let agePresetMaximums = [25, 35, 50]
    /// D2: the column is a 32-bit Int; nine digits always fit.
    static let maxMembersDigits = 9

    /// D2: shared-edit-field §2b titles ("Age range" opens from the "Age" row).
    static func title(_ field: GroupField) -> String {
        switch field {
        case .name: return "Group name"
        case .description: return "Description"
        case .visibility: return "Visibility"
        case .ageRange: return "Age range"
        case .maxMembers: return "Maximum members"
        case .directoryAccess: return "Member directory access"
        }
    }

    /// D3: §2b's descriptions verbatim; the two the design left blank are D3's drafts.
    static func description(_ field: GroupField) -> String {
        switch field {
        case .name:
            return "The group name is the primary title for your group that will be surfaced anytime the group is displayed in a MakeReady app"
        case .description:
            return "The group description is used to help others understand the purpose of your group at a glance."
        case .visibility:
            return "Visibility determines who is able to view the group"
        case .ageRange:
            return "If an age range is specified, then every member who joins must fall within the specified range."
        case .maxMembers:
            return "The most members this group can have. Leave it blank for no limit."
        case .directoryAccess:
            return "Choose what members of this group can see about each other."
        }
    }

    static let visibilityDescriptions = [
        "Only active members of the group can view information about the group, organization, and group leader.",
        "Anyone can search and view information about the group and the group leader."
    ]

    static let directoryDescriptions = [
        "All members are able to view the full membership directory with contact information for every member",
        "Members are able to see who is in the group, but they are not able to view any contact information",
        "Members are not able to view any information about members in the group"
    ]

    /// D2 arrangement per field, from the cached group.
    static func page(_ field: GroupField, group: UserGroup, saving: Bool, errorMessage: String) -> GroupFieldPage {
        switch field {
        case .name:
            var s = single(field, text: group.name, saving: saving, errorMessage: errorMessage)
            s.maxLength = 200
            s.autocapitalization = .words
            let stored = group.name
            return .textSingle(s, canSave: { nameCanSave($0, stored: stored) })
        case .maxMembers:
            var s = single(field, text: group.maxMembers.map(String.init) ?? "", saving: saving, errorMessage: errorMessage)
            s.keyboard = .numberPad
            s.autocapitalization = .never
            s.autocorrect = false
            s.allowsEmpty = true
            s.maxLength = maxMembersDigits
            let stored = group.maxMembers
            return .textSingle(s, canSave: { maxMembersCanSave($0, stored: stored) })
        case .description:
            let text = group.description ?? ""
            var s = EditTextMultiFieldScreen.State(
                title: title(field), description: description(field), label: title(field), placeholder: "",
                text: text, loadedValue: text, focused: false, saving: saving,
                promptCopy: "", aiState: "prompt", suggestions: []
            )
            s.maxLength = 2000
            s.errorMessage = errorMessage
            s.showsAISuggestions = false                       // P11
            s.editable = true
            s.focusOnAppear = true
            return .textMulti(s)
        case .visibility:
            let selected = group.isPrivate ? "Private" : "Public"
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: visibilityOptions, optionDescriptions: visibilityDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .directoryAccess:
            let selected = GroupDetailMapper.directoryAccessLabel(group.memberDirectoryAccess, memberDirectory: group.memberDirectory)
            return .option(EditOptionFieldScreen.State(
                title: title(field), description: description(field),
                options: directoryOptions, optionDescriptions: directoryDescriptions,
                loadedValue: selected, selectedOption: selected,
                saving: saving, errorMessage: errorMessage
            ))
        case .ageRange:
            let minimum = group.ageRange?.min.map(String.init) ?? ""
            let maximum = group.ageRange?.max.map(String.init) ?? ""
            return .ageRange(EditOptionsCustomFieldScreen.State(
                title: title(field), description: description(field),
                options: ageOptions, presetMinimums: agePresetMinimums, presetMaximums: agePresetMaximums,
                minimumLabel: "Minimum age", maximumLabel: "Maximum age",
                minimumPlaceholder: "18", maximumPlaceholder: "24",
                selectedOption: ageSelection(group.ageRange),
                minimum: minimum, maximum: maximum,
                loadedMinimum: minimum, loadedMaximum: maximum,
                focusedInput: "", saving: saving
            ))
        }
    }

    /// D2: 1–200 characters after trimming, and different from the stored name.
    static func nameCanSave(_ typed: String, stored: String) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 200 && trimmed != stored
    }

    /// D2: empty = Unlimited; otherwise ASCII digits forming an integer ≥ 1; different from stored.
    static func maxMembersCanSave(_ typed: String, stored: Int?) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return stored != nil }
        guard trimmed.allSatisfy({ ("0"..."9").contains($0) }), let value = Int(trimmed), value >= 1 else { return false }
        return value != stored
    }

    /// D4: both null → "Any age"; equal to a preset → that preset; anything else → "Custom range".
    static func ageSelection(_ range: AgeRange?) -> String {
        guard let range, range.min != nil || range.max != nil else { return ageOptions[0] }
        for (i, low) in agePresetMinimums.enumerated() where range.min == low && range.max == agePresetMaximums[i] {
            return ageOptions[i + 1]
        }
        return ageOptions[ageOptions.count - 1]
    }

    /// D2/D4: the one key and its wire value; nil when the input does not belong to the field.
    static func patch(_ field: GroupField, _ input: GroupFieldInput) -> GroupPatch? {
        switch (field, input) {
        case (.name, .text(let s)):
            return .name(s.trimmingCharacters(in: .whitespacesAndNewlines))
        case (.description, .text(let s)):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return .description(trimmed.isEmpty ? nil : trimmed)
        case (.maxMembers, .text(let s)):
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return .maxMembers(trimmed.isEmpty ? nil : Int(trimmed))
        case (.visibility, .option(let label)):
            switch label {
            case "Private": return .isPrivate(true)
            case "Public": return .isPrivate(false)
            default: return nil
            }
        case (.directoryAccess, .option(let label)):
            switch label {
            case "Allowed": return .memberDirectoryAccess("ALLOWED")
            case "Names only": return .memberDirectoryAccess("NAMES_ONLY")
            case "Not allowed": return .memberDirectoryAccess("NOT_ALLOWED")
            default: return nil
            }
        case (.ageRange, .ageRange(let minimum, let maximum)):
            if minimum.isEmpty && maximum.isEmpty { return .ageRange(nil) }
            return .ageRange(AgeRange(min: Int(minimum), max: Int(maximum)))
        default:
            return nil
        }
    }

    /// D5: cancelled → nothing; 401 → sign-out; 404 → gone; anything else → retry.
    static func failure(for error: Error) -> GroupSaveFailure {
        if GroupActions.isCancellation(error) { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) { return .signOut }
        if let http = error as? APIHTTPError, http.status == 404 { return .gone }
        return .retry
    }

    /// D2: a group text-single page — title = label, no placeholder, no AI block (P11), focused on appear.
    private static func single(_ field: GroupField, text: String, saving: Bool, errorMessage: String) -> EditTextSingleFieldScreen.State {
        var s = EditTextSingleFieldScreen.State(
            title: title(field), description: description(field), label: title(field), placeholder: "",
            text: text, loadedValue: text, focused: false, saving: saving,
            promptCopy: "", aiState: "prompt", suggestions: []
        )
        s.errorMessage = errorMessage
        s.showsAISuggestions = false
        s.editable = true
        s.focusOnAppear = true
        return s
    }
}
```

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `ruby iphone/scripts/capture-targets.rb --check` → exit 0.

- [ ] **Step 6: Commit** — `feat(ui2-groups-edit): GroupField and the pure group field edit model`

### Task 7: `.editGroupField` route + GroupFieldEditContainer + group page wiring (D1, D2, D5)
App: iphone
Phase: 2
Recipe: `/push-page` (a pushed edit page on the tab stack) — SPEC D1, D5, §iphone Route/Container/Group page

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditContainer.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:18-33` (`UI2Destination`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:150-159` (`page(for:)`)
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift` (`onEditField`)
- Modify: `iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift` (append)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (Step 2)

**Interfaces:**
- Consumes: `GroupField`, `GroupFieldPage`, `GroupFieldInput`, `GroupFieldEditModel` (Task 6); `GroupActions.updateGroup(id:patch:)` (Task 4); `GroupActions.forgetGroup(id:)` (Task 5); `UI2Navigator` (`push`, `pop`, `popIfTop`, `popTo`).
- Produces: `UI2Destination.editGroupField(groupId: String, field: GroupField)`; `GroupFieldEditContainer(groupId:field:)`; `GroupDetailContainer.editDestination(groupId: String, label: String, group: UserGroup?) -> UI2Destination?` (static, D1 — nil for an unknown label or an unloaded group).

- [ ] **Step 1: Write the failing test** — append to `iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift` (inside the existing test class, which is `@MainActor`; if it is not, mark these two functions `@MainActor`):

```swift
    // MARK: ui2-groups-edit D1

    func testEditFieldPushesTheFieldsPageOnceTheGroupIsLoaded() {
        let g = UserGroup(id: "g1", code: "ABC123", name: "Alpha", isPrivate: false, allowInvites: true,
                          memberCount: 0, creatorId: "u1", createdAt: Date(), updatedAt: Date())
        XCTAssertEqual(GroupDetailContainer.editDestination(groupId: "g1", label: "Age", group: g),
                       .editGroupField(groupId: "g1", field: .ageRange))
        XCTAssertEqual(GroupDetailContainer.editDestination(groupId: "g1", label: "Group name", group: g),
                       .editGroupField(groupId: "g1", field: .name))
        XCTAssertNil(GroupDetailContainer.editDestination(groupId: "g1", label: "Cover", group: g))
        XCTAssertNil(GroupDetailContainer.editDestination(groupId: "g1", label: "Age", group: nil))
    }
```

- [ ] **Step 2: Register the container** — create `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditContainer.swift` containing `import SwiftUI`, then from the repo root:

```bash
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("iphone/MakeReady.xcodeproj")
app = p.targets.find { |x| x.name == "MakeReady" }
anchor = p.files.find { |f| f.path.to_s.end_with?("GroupDetailContainer.swift") }
ref = anchor.parent.new_reference(File.expand_path("iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditContainer.swift"))
app.add_file_references([ref])
p.save'
ruby iphone/scripts/capture-targets.rb
```

- [ ] **Step 3: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "type 'UI2Destination' has no member 'editGroupField'"

- [ ] **Step 4: Add the destination** — in `UI2ShellModel.swift`, inside `enum UI2Destination`, after `case groupDetail(id: String, name: String)`:

```swift
    /// ui2-groups-edit D1/D2: one group setting's edit page, above the group page.
    case editGroupField(groupId: String, field: GroupField)
```

and in `UI2Shell.swift` `page(for:)`, after the `.groupDetail` case:

```swift
        case let .editGroupField(groupId, field): GroupFieldEditContainer(groupId: groupId, field: field)  // ui2-groups-edit D2
```

- [ ] **Step 5: Write the container** — `iphone/MakeReady/UI2/Containers/Groups/GroupFieldEditContainer.swift`

```swift
import SwiftUI

/// ui2-groups-edit §iphone Container: the `.editGroupField` destination (D2). Reads only
/// `AppState.groups[groupId]`, builds the field's built screen, owns `saving` and the inline
/// error (D5), saves one key through `GroupActions.updateGroup(id:patch:)` and pops only if this
/// page is still on top. Back discards silently: the draft lives only in the screen's own state.
struct GroupFieldEditContainer: View {
    let groupId: String
    let field: GroupField

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// D5 `saving` — set synchronously on Save, so a second tap is a no-op.
    @State private var saving = false
    /// D5: the inline line above Save; "" draws none. The age page has no slot (banner instead).
    @State private var errorText = ""

    var body: some View {
        Group {
            if let group = AppState.shared.groups[groupId] {
                screen(GroupFieldEditModel.page(field, group: group, saving: saving, errorMessage: errorText))
            } else {
                // D1: rows open this page only once the group is loaded; a sign-out or a 404
                // mid-page clears the store and the page pops.
                Token.layoutBackground
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
    }

    @ViewBuilder private func screen(_ page: GroupFieldPage) -> some View {
        switch page {
        case let .textSingle(state, canSave):
            EditTextSingleFieldScreen(state: state, onBack: { navigator.pop() },
                                      onSave: { save(.text($0)) }, canSave: canSave)
        case let .textMulti(state):
            EditTextMultiFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.text($0)) })
        case let .option(state):
            EditOptionFieldScreen(state: state, onBack: { navigator.pop() }, onSave: { save(.option($0)) })
        case let .ageRange(state):
            EditOptionsCustomFieldScreen(state: state, onBack: { navigator.pop() },
                                         onSave: { save(.ageRange(minimum: $0, maximum: $1)) })
        }
    }

    /// D5: `saving` set synchronously, the PATCH in an unstructured Task, the pop only if this
    /// page is still the last entry; a failure keeps the typed value and re-enables Save.
    private func save(_ input: GroupFieldInput) {
        guard !saving, let patch = GroupFieldEditModel.patch(field, input) else { return }
        saving = true
        errorText = ""
        let destination = UI2Destination.editGroupField(groupId: groupId, field: field)
        let actions = GroupActions()
        Task { @MainActor in
            do {
                _ = try await actions.updateGroup(id: groupId, patch: patch)
                saving = false
                navigator.popIfTop(destination)
            } catch {
                saving = false
                switch GroupFieldEditModel.failure(for: error) {
                case .cancelled:
                    return
                case .signOut:
                    // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                    do { try await authManager.signOut() } catch {
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.signOut", surface: false)
                    }
                case .gone:
                    // D5/D10: the group is gone or out of scope — forget it, back to Groups.
                    actions.forgetGroup(id: groupId)
                    navigator.popTo(0)
                case .retry:
                    if field == .ageRange {
                        // EditOptionsCustomFieldScreen has no error slot (D4/D5): the shell banner.
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.save", surface: true,
                                                    friendlyMessage: GroupFieldEditModel.saveFailedMessage)
                    } else {
                        AppState.shared.recordError(error, context: "GroupFieldEditContainer.save", surface: false)
                        errorText = GroupFieldEditModel.saveFailedMessage
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 6: Wire the group page's rows** — in `GroupDetailContainer.swift`, pass `onEditField` to `GroupsDetailScreen` (after `showsHeader: false,`):

```swift
                    // ui2-groups-edit D1: a settings row → that field's edit page.
                    onEditField: { label in
                        guard let next = Self.editDestination(groupId: groupId, label: label,
                                                              group: AppState.shared.groups[groupId]) else { return }
                        navigator.push(next)
                    },
```

and add, beside the other statics:

```swift
    /// ui2-groups-edit D1: the row label's edit page — nil for an unknown label, or while the
    /// group has not loaded (the page has nothing to edit yet).
    static func editDestination(groupId: String, label: String, group: UserGroup?) -> UI2Destination? {
        guard group != nil, let field = GroupField(label: label) else { return nil }
        return .editGroupField(groupId: groupId, field: field)
    }
```

- [ ] **Step 7: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; `ruby iphone/scripts/capture-targets.rb --check` → exit 0.

- [ ] **Step 8: Commit** — `feat(ui2-groups-edit): group setting rows open their edit pages and save`

### Task 8: Delete Group through the red C-066 menu (D9, D13, D14)
App: iphone
Phase: 2
Recipe: `/present-overlay` (read for the overlay rules; C-066 presents through MakeReadyUI's hostable `actionMenuPresentation`, the shell's Add-menu precedent at `UI2Shell.swift:59`) · `/ios-error-surface` — SPEC D9, D10, D13, D14

**Files:**
- Modify: `iphone/MakeReady/UI2/Containers/Groups/GroupDetailContainer.swift`
- Modify: `iphone/MakeReadyCaptureTests/GroupDetailContainerTests.swift` (append)

**Interfaces:**
- Consumes: `ActionMenuOverlay.ActionItem(glyph:label:tone:)` (Task 3); `View.actionMenuPresentation(isPresented:onDismiss:menu:)` (`MakeReadyUI/ActionMenuPresentation.swift:10`), hosted by the shell's `.ui2OverlayHost()`; `GroupActions.deleteGroup(id:)` (Task 5); `UI2Navigator.popTo`.
- Produces: `GroupDetailContainer.deleteAction(groupName: String) -> ActionMenuOverlay.ActionItem`; `GroupDetailContainer.deleteFailedMessage = "Couldn't delete the group"`.

> Ruling (plan, D9): D9 names glyph `trash`; MakeReadyUI's library has no `trash`, its trash glyph is `trash-2` (`GlyphName.trash2`, `MakeReadyUI/Glyph.swift:201`). The row uses `"trash-2"`. The label is `"Delete \(groupName)"` — D9's «» mark the name, they are not drawn.

- [ ] **Step 1: Write the failing test** — append to `GroupDetailContainerTests.swift`:

```swift
    // MARK: ui2-groups-edit D9/D13/D14

    func testDeleteActionIsOneRedRowNamingTheGroup() {
        let item = GroupDetailContainer.deleteAction(groupName: "Empty Group")
        XCTAssertEqual(item.label, "Delete Empty Group")
        XCTAssertEqual(item.glyph, "trash-2")
        XCTAssertEqual(item.tone, .destructive)
        XCTAssertEqual(GroupDetailContainer.deleteFailedMessage, "Couldn't delete the group")
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile: "type 'GroupDetailContainer' has no member 'deleteAction'"

- [ ] **Step 3: Wire Delete** — in `GroupDetailContainer.swift`:

Add beside `imagesSeeded`:

```swift
    /// ui2-groups-edit D9: the Delete Group menu is up.
    @State private var deleteMenuOpen = false
```

Pass `onDeleteGroup` to `GroupsDetailScreen` (after `onOpenMember`):

```swift
                    // ui2-groups-edit D9: C-048 Delete Group → the C-066 confirmation.
                    onDeleteGroup: { deleteMenuOpen = true }
```

Attach the menu to the outer `VStack`, directly after `.background(Token.layoutBackground.ignoresSafeArea())`:

```swift
        // ui2-groups-edit D9/D14: one red row and Done, nothing else; Done = cancel. Hosted by the
        // shell's `.ui2OverlayHost()`, like the Add menu.
        .actionMenuPresentation(isPresented: deleteMenuOpen, onDismiss: { deleteMenuOpen = false }) {
            ActionMenuOverlay(
                actions: [Self.deleteAction(groupName: state.groupName)],
                onSelect: { _ in
                    deleteMenuOpen = false
                    Task { await deleteGroup() }
                },
                onDone: { deleteMenuOpen = false }
            )
        }
```

and the statics + the delete:

```swift
    /// ui2-groups-edit D9/D13: the menu's one row.
    static func deleteAction(groupName: String) -> ActionMenuOverlay.ActionItem {
        .init(glyph: "trash-2", label: "Delete \(groupName)", tone: .destructive)
    }

    /// ui2-groups-edit D9: the banner a failed delete shows; the page stays.
    static let deleteFailedMessage = "Couldn't delete the group"

    /// D9/D10: delete, then the Groups stack back to its root (the Groups list, without the group).
    @MainActor
    private func deleteGroup() async {
        do {
            try await GroupActions().deleteGroup(id: groupId)
            navigator.popTo(0)
        } catch {
            if GroupActions.isCancellation(error) { return }
            if AuthStatusPolicy.shouldSignOut(after: error) {
                // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
                do { try await authManager.signOut() } catch {
                    AppState.shared.recordError(error, context: "GroupDetailContainer.signOut", surface: false)
                }
                return
            }
            AppState.shared.recordError(error, context: "GroupDetailContainer.deleteGroup", surface: true,
                                        friendlyMessage: Self.deleteFailedMessage,
                                        retry: { Task { await deleteGroup() } })
        }
    }
```

`state` is the local `let state = Self.cachedImages(output.state)` already in `body`; the `.actionMenuPresentation` closure reads it there. If `recordError`'s `retry:` closure cannot capture `self` from a `View` struct, drop `retry:` (the banner without a retry still meets D9).

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test` → PASS; `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations; run `/transition-review` over this task's diff (it adds an overlay presentation) and fix any FAIL.

- [ ] **Step 5: Commit** — `feat(ui2-groups-edit): Delete Group confirms through the red C-066 row`
