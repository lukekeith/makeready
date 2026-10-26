# ui2-members-browse — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** A leader on the UI 2.0 iPhone shell opens Home → Members, searches and filters the org's live member directory (scoped by D7), taps a member and the member page pushes in with live fields, activity rail, groups and program engagement.

**Architecture:** The server adds three nullable Member columns, one shared `memberAccessScope` service (D7/F6) applied in the service layer to the extended members list, the member reads, a new engagement endpoint and `/api/home/days?memberId`, plus `/my/organizations` for non-owner leaders; fixtures fill both screens, and the contract freezes at the server phase close. The iPhone adds tolerant models, `MemberActions` with in-memory `AppState` stores, the shell's per-tab `NavigationStack` push, the MakeReadyUI edits the rulings require, and the two container + mapper pairs.

**Tech Stack:** server — Express, Prisma, PostgreSQL (Atlas migrations from `server/schema/*.yaml`), zod, vitest · iphone — Swift/SwiftUI, `@Observable` + Actions, `NavigationStack`, XCTest (`MakeReadyCaptureTests`).

**Spec:** `docs/features/ui2-members-browse/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(ui2-members-browse): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–3 | Member has address + emergency columns; `memberAccessScope` answers D7; `/my/organizations` lists every org a leader can act in | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run migrate:status` · `cd server && npm run schema:validate` |
| 2 | server | 4–8 | The list, member reads, engagement and `/api/home/days?memberId` answer per §Contract under D7; fixtures fill both screens; the contract freezes | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run migrate:status` |
| 3 | iphone | 9–11 | The app decodes every new payload, holds members in memory-only `AppState` stores, adopts an org for non-owner leaders, and the shell can push a page | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 12–14 | MakeReadyUI carries the rulings: typeable C-034, Members chrome/Leaders chip/initials, non-tappable C-042 and the nine-field member page with the rail on today | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 5 | iphone | 15–16 | Members and the member page are live, wired into the shell's push | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Member columns address / emergencyContactName / emergencyContactPhone
App: server
Phase: 1
Recipe: server/.claude/CLAUDE.md §Database Management - Schema-First Approach

**Files:**
- Modify: `server/schema/schema.yaml:614-617` (three new fields after `userLinkedAt`, before the `relations:` key at `:618`)
- Modify (GENERATED by `npm run schema:generate`, never by hand): `server/prisma/schema.prisma:348` (three lines appear after `userLinkedAt`)
- Create (GENERATED by `npm run schema:diff`, never by hand): `server/atlas/migrations/<timestamp>.sql`
- Modify (GENERATED by `npm run schema:diff`): `server/atlas/migrations/atlas.sum`
- Test: `server/src/services/__tests__/member-columns.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - Postgres `members."address"`, `members."emergencyContactName"`, `members."emergencyContactPhone"` — all `text NULL`, no default, no backfill (existing rows read null).
  - Generated client: `Member.address: string | null`, `Member.emergencyContactName: string | null`, `Member.emergencyContactPhone: string | null`; `Prisma.MemberScalarFieldEnum` gains the three keys.
  - `GET /api/members/:memberId` (`getMember`, `server/src/services/member.ts:104`, which uses `include`, not `select`) returns the three keys as `"address"`, `"emergencyContactName"`, `"emergencyContactPhone"` (string | null) with no code change. `PATCH /api/members/:memberId` is NOT changed — `updateMemberSchema` (`members.ts:1178`) still strips them; that is child 2's (`ui2-members-edit`, SPEC F11).

- [ ] **Step 1: Write the failing test** — create `server/src/services/__tests__/member-columns.test.ts`

```ts
/**
 * ui2-members-browse SC1–SC3: Member.address, emergencyContactName,
 * emergencyContactPhone exist on the generated client and reach the
 * GET /api/members/:id payload (getMember includes every scalar column).
 */
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Prisma, type Member } from '../../generated/prisma/index.js'

const prismaMock = vi.hoisted(() => ({ member: { findUnique: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getMember } from '../member.js'

beforeEach(() => vi.clearAllMocks())

describe('Member SC1–SC3 columns', () => {
  it('are scalar fields of the generated Member model', () => {
    expect(Object.keys(Prisma.MemberScalarFieldEnum)).toEqual(
      expect.arrayContaining(['address', 'emergencyContactName', 'emergencyContactPhone'])
    )
  })

  it('reach the getMember payload as string | null, never filtered out', async () => {
    const columns: Pick<Member, 'address' | 'emergencyContactName' | 'emergencyContactPhone'> = {
      address: '137 Oak St\nEvanston, IL 60201',
      emergencyContactName: 'Sophia Carter',
      emergencyContactPhone: '+15550200001',
    }
    prismaMock.member.findUnique.mockResolvedValue({ id: 'm1', firstName: 'James', organizations: [], ...columns })

    const result = await getMember('m1')

    expect(result.success).toBe(true)
    expect(result.data).toMatchObject(columns)
    // getMember must keep `include` (every scalar) — a `select` here would drop the new columns.
    expect(prismaMock.member.findUnique.mock.calls[0][0]).not.toHaveProperty('select')
  })

  it('reads null for a member who has none of them', async () => {
    prismaMock.member.findUnique.mockResolvedValue({
      id: 'm2',
      organizations: [],
      address: null,
      emergencyContactName: null,
      emergencyContactPhone: null,
    })
    const result = await getMember('m2')
    expect(result.data).toMatchObject({ address: null, emergencyContactName: null, emergencyContactPhone: null })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/member-columns.test.ts` → FAIL: `expected [ 'id', 'phoneNumber', … ] to include 'address'` (the first case; the other two pass on the mock). `cd server && npx tsc --noEmit` → FAIL: `Type '"address"' does not satisfy the constraint keyof Member`.

- [ ] **Step 3: Add the three fields to the YAML source of truth** — in `server/schema/schema.yaml`, directly after the `userLinkedAt:` block of `Member` (`:614-617`) and before `    relations:` (`:618`), insert (6-space indent, same as the sibling fields):

```yaml
      # UI 2.0 member page (ui2-members-browse SC1–SC3) — nullable, no backfill
      address:
        type: text
        nullable: true
        description: "Postal address as entered; may span lines"
      emergencyContactName:
        type: text
        nullable: true
        description: "Emergency contact's name"
      emergencyContactPhone:
        type: text
        nullable: true
        description: "Emergency contact's phone, as entered"
```

- [ ] **Step 4: Validate the YAML** — `cd server && npm run schema:validate` → exit 0 with no errors.

- [ ] **Step 5: Generate the migration with Atlas (never hand-written)** — preconditions: the local Postgres container is up (`docker ps --format '{{.Names}}' | grep makeready-postgres`), and `server/.env` exists (it is gitignored, so a fresh worktree lacks it: `test -f server/.env || cp /Users/lukekeith/www/makeready/server/.env server/.env`). `server/bin/atlas` is absent in worktrees; `scripts/atlas.sh` falls back to the `atlas` on PATH. Then run `cd server && npm run schema:diff`. It regenerates `prisma/schema.prisma` and writes ONE new file under `server/atlas/migrations/` plus an `atlas.sum` change. Check: `git -C server status --short atlas/migrations prisma/schema.prisma` shows exactly one new `.sql`, `M atlas/migrations/atlas.sum` and `M prisma/schema.prisma`; `cat` the new `.sql` — it must contain only the `members` change, in Atlas's form:

```sql
-- Modify "members" table
ALTER TABLE "public"."members" ADD COLUMN "address" text NULL, ADD COLUMN "emergencyContactName" text NULL, ADD COLUMN "emergencyContactPhone" text NULL;
```

If the file holds ANY other statement (drift from another table, an index, a drop), STOP and report it — do not edit the file and do not delete lines from it.

- [ ] **Step 6: Apply locally and regenerate the client** — `cd server && npm run migrate:apply && npx prisma generate && npm run migrate:status` → migrate:status reports the new version as current with no pending files. `git -C server diff prisma/schema.prisma` shows exactly three added lines after `userLinkedAt` (`address String? @db.Text` or `String?`, as the generator writes them, for the three names).

- [ ] **Step 7: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/member-columns.test.ts` → PASS (3 tests); `cd server && npx tsc --noEmit && npx tsc --noEmit -p fixtures` → PASS; `cd server && npm run test:run` → PASS. vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server` (the container neither hot-reloads `server/src` nor sees a host `prisma generate` until restarted).

- [ ] **Step 8: Commit** — stage `server/schema/schema.yaml`, `server/prisma/schema.prisma`, the new `server/atlas/migrations/<timestamp>.sql`, `server/atlas/migrations/atlas.sum` and the test; `feat(ui2-members-browse): member address and emergency contact columns`

### Task 2: `memberAccessScope` — who sees which members (D7)
App: server
Phase: 1
Recipe: /api

This is the recorded exception to the Global Constraints' "authorize by `canManageOrgContent`, never by `creatorId`" rule (SPEC D7, F6, settled at audit 2026-10-25): D7 is a VISIBILITY rule layered under the existing gates (`requirePermission('member.read')`, `requireMemberOrOrgOwner`), not an authorization gate. Its all-members test is deliberately NOT `canManageOrgContent` / `getManageableOrgIds` (`permission.ts:269,305`), which admit every role-holder; every other leader is narrowed by `Group.creatorId`. Say so in the file header so a later reviewer does not "fix" it.

**Files:**
- Create: `server/src/services/member-access.ts`
- Test: `server/src/services/__tests__/member-access.test.ts`

**Interfaces:**
- Consumes: `isSuperAdmin(userId: string): Promise<boolean>` (`server/src/services/permission.ts:31`); Prisma models `organization` (`ownerId`), `userRole` (+ `role.isSystem`, `role.name`), `group` (`creatorId`, `organizationId`, `isActive`), `groupMember` (`memberId`, `groupId`, `isActive`), `memberOrganization` (`memberId`, `organizationId`).
- Produces (all exported from `server/src/services/member-access.ts`):
  - `export type MemberAccessScope = { all: true } | { all: false; groupIds: string[] }`
  - `export type MemberViewer = { kind: 'self' } | { kind: 'user'; userId: string }` — `self` = a member session reading its own record (unscoped, D7 "member sessions reading themselves are unchanged").
  - `export const ALL_MEMBERS_SYSTEM_ROLES = ['Owner', 'Admin'] as const`
  - `export async function memberAccessScope(userId: string, orgId: string): Promise<MemberAccessScope>` — `{all:true}` for super admin, `Organization.ownerId === userId`, or a `UserRole` in `orgId` whose role is `isSystem` with name Owner/Admin; else `{all:false, groupIds}` = ids of ACTIVE groups in `orgId` with `creatorId === userId`, ordered by id asc (empty array when none).
  - `export async function canAccessMember(scope: MemberAccessScope, memberId: string, orgId: string): Promise<boolean>` — all: the member has a `MemberOrganization` row in `orgId`; else: an active `GroupMember` row in one of `scope.groupIds` whose group is active and in `orgId`.
  - `export async function visibleMemberOrgIds(viewer: MemberViewer, memberId: string): Promise<string[]>` — the member's org ids (asc) the viewer may see the member in; `self` → every org the member belongs to.
  - `export async function canViewMember(userId: string, memberId: string, organizationId?: string): Promise<boolean>` — with `organizationId`: that org is visible; without: any org is.

- [ ] **Step 1: Write the failing test** — create `server/src/services/__tests__/member-access.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  organization: { findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
  group: { findMany: vi.fn() },
  groupMember: { count: vi.fn() },
  memberOrganization: { count: vi.fn(), findMany: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import {
  ALL_MEMBERS_SYSTEM_ROLES,
  canAccessMember,
  canViewMember,
  memberAccessScope,
  visibleMemberOrgIds,
} from '../member-access.js'

/** o1 is owned by 'owner-1'; o2 by 'owner-2'. 'gl' created g-led in o1; 'gl2' created g-other in o1. */
const OWNER_OF: Record<string, string> = { o1: 'owner-1', o2: 'owner-2' }
const CREATED: Record<string, Record<string, string[]>> = { gl: { o1: ['g-led'] }, gl2: { o1: ['g-other'] } }

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  prismaMock.organization.findUnique.mockImplementation(async ({ where }: any) =>
    OWNER_OF[where.id] ? { ownerId: OWNER_OF[where.id] } : null
  )
  prismaMock.userRole.findFirst.mockResolvedValue(null)
  prismaMock.group.findMany.mockImplementation(async ({ where }: any) =>
    (CREATED[where.creatorId]?.[where.organizationId] ?? []).map((id) => ({ id }))
  )
  // m1 is active in g-led only.
  prismaMock.groupMember.count.mockImplementation(async ({ where }: any) =>
    where.memberId === 'm1' && where.groupId.in.includes('g-led') ? 1 : 0
  )
  prismaMock.memberOrganization.count.mockResolvedValue(1)
  prismaMock.memberOrganization.findMany.mockResolvedValue([{ organizationId: 'o1' }, { organizationId: 'o2' }])
})

describe('memberAccessScope (D7, F6)', () => {
  it('gives a super admin every member, without reading the org', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    expect(await memberAccessScope('anyone', 'o1')).toEqual({ all: true })
    expect(prismaMock.organization.findUnique).not.toHaveBeenCalled()
  })

  it('gives the org owner (Organization.ownerId) every member', async () => {
    expect(await memberAccessScope('owner-1', 'o1')).toEqual({ all: true })
    expect(prismaMock.userRole.findFirst).not.toHaveBeenCalled()
  })

  it('gives a holder of the SYSTEM Owner or Admin role every member', async () => {
    prismaMock.userRole.findFirst.mockResolvedValue({ id: 'ur-1' })
    expect(await memberAccessScope('admin-1', 'o1')).toEqual({ all: true })
    expect(prismaMock.userRole.findFirst).toHaveBeenCalledWith({
      where: { userId: 'admin-1', organizationId: 'o1', role: { isSystem: true, name: { in: ['Owner', 'Admin'] } } },
      select: { id: true },
    })
    expect([...ALL_MEMBERS_SYSTEM_ROLES]).toEqual(['Owner', 'Admin'])
  })

  it('narrows every other role — Group Leader, Contributor, custom — to the active groups they created in that org', async () => {
    expect(await memberAccessScope('gl', 'o1')).toEqual({ all: false, groupIds: ['g-led'] })
    expect(prismaMock.group.findMany).toHaveBeenCalledWith({
      where: { creatorId: 'gl', organizationId: 'o1', isActive: true },
      select: { id: true },
      orderBy: { id: 'asc' },
    })
  })

  it('gives a leader with no groups in that org an empty group list', async () => {
    expect(await memberAccessScope('gl', 'o2')).toEqual({ all: false, groupIds: [] })
  })
})

describe('canAccessMember', () => {
  it('all: the member belongs to the org', async () => {
    expect(await canAccessMember({ all: true }, 'm1', 'o1')).toBe(true)
    expect(prismaMock.memberOrganization.count).toHaveBeenCalledWith({ where: { memberId: 'm1', organizationId: 'o1' } })
    prismaMock.memberOrganization.count.mockResolvedValue(0)
    expect(await canAccessMember({ all: true }, 'm-foreign', 'o1')).toBe(false)
  })

  it('groups: an active membership in one of the scope groups, active and in the org', async () => {
    expect(await canAccessMember({ all: false, groupIds: ['g-led'] }, 'm1', 'o1')).toBe(true)
    expect(prismaMock.groupMember.count).toHaveBeenCalledWith({
      where: { memberId: 'm1', isActive: true, groupId: { in: ['g-led'] }, group: { isActive: true, organizationId: 'o1' } },
    })
    expect(await canAccessMember({ all: false, groupIds: ['g-other'] }, 'm1', 'o1')).toBe(false)
  })

  it('groups: no groups means no members, without a query', async () => {
    expect(await canAccessMember({ all: false, groupIds: [] }, 'm1', 'o1')).toBe(false)
    expect(prismaMock.groupMember.count).not.toHaveBeenCalled()
  })
})

describe('visibleMemberOrgIds — a member in two orgs', () => {
  it('self sees every org the member belongs to', async () => {
    expect(await visibleMemberOrgIds({ kind: 'self' }, 'm1')).toEqual(['o1', 'o2'])
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1' },
      select: { organizationId: true },
      orderBy: { organizationId: 'asc' },
    })
  })

  it('an owner of one org sees the member only in that org', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'owner-1' }, 'm1')).toEqual(['o1'])
  })

  it('a Group Leader sees the member in the org of the group they lead', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'gl' }, 'm1')).toEqual(['o1'])
  })

  it('a Group Leader whose groups do not hold the member sees no org', async () => {
    expect(await visibleMemberOrgIds({ kind: 'user', userId: 'gl2' }, 'm1')).toEqual([])
  })
})

describe('canViewMember', () => {
  it('checks the named org, or any org when none is named', async () => {
    expect(await canViewMember('gl', 'm1', 'o1')).toBe(true)
    expect(await canViewMember('gl', 'm1', 'o2')).toBe(false)
    expect(await canViewMember('gl', 'm1')).toBe(true)
    expect(await canViewMember('gl2', 'm1')).toBe(false)
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/member-access.test.ts` → FAIL: `Failed to load url ../member-access.js` (the module does not exist).

- [ ] **Step 3: Write the service** — create `server/src/services/member-access.ts`

```ts
/**
 * Which members a leader may SEE in an organization (ui2-members-browse D7).
 *
 *  - all: a super admin, the org's owner (Organization.ownerId), or a holder of
 *    the SYSTEM Owner or Admin role in that org;
 *  - otherwise (Group Leader, Contributor, any custom role): members with an
 *    active GroupMember row in an active group of that org the caller created.
 *
 * Recorded exception (SPEC D7, F6 — settled at audit 2026-10-25): this is a
 * VISIBILITY rule under the existing gates (requirePermission('member.read'),
 * requireMemberOrOrgOwner), not an authorization gate, so it narrows by
 * Group.creatorId ON PURPOSE. Its all-members test is deliberately not
 * canManageOrgContent / getManageableOrgIds, which admit every role-holder.
 * Used by the members list, GET /api/members/:id, /:id/groups,
 * /:id/engagement and /api/home/days?memberId.
 */
import { prisma } from '../lib/prisma.js'
import { isSuperAdmin } from './permission.js'

export type MemberAccessScope = { all: true } | { all: false; groupIds: string[] }

/** Who reads a member: the member's own session (unscoped) or a user (D7-scoped). */
export type MemberViewer = { kind: 'self' } | { kind: 'user'; userId: string }

export const ALL_MEMBERS_SYSTEM_ROLES = ['Owner', 'Admin'] as const

export async function memberAccessScope(userId: string, orgId: string): Promise<MemberAccessScope> {
  if (await isSuperAdmin(userId)) return { all: true }
  const org = await prisma.organization.findUnique({ where: { id: orgId }, select: { ownerId: true } })
  if (org?.ownerId === userId) return { all: true }
  const adminRole = await prisma.userRole.findFirst({
    where: {
      userId,
      organizationId: orgId,
      role: { isSystem: true, name: { in: [...ALL_MEMBERS_SYSTEM_ROLES] } },
    },
    select: { id: true },
  })
  if (adminRole) return { all: true }
  const groups = await prisma.group.findMany({
    where: { creatorId: userId, organizationId: orgId, isActive: true },
    select: { id: true },
    orderBy: { id: 'asc' },
  })
  return { all: false, groupIds: groups.map((g) => g.id) }
}

export async function canAccessMember(scope: MemberAccessScope, memberId: string, orgId: string): Promise<boolean> {
  if (scope.all) {
    return (await prisma.memberOrganization.count({ where: { memberId, organizationId: orgId } })) > 0
  }
  if (scope.groupIds.length === 0) return false
  const memberships = await prisma.groupMember.count({
    where: {
      memberId,
      isActive: true,
      groupId: { in: scope.groupIds },
      group: { isActive: true, organizationId: orgId },
    },
  })
  return memberships > 0
}

export async function visibleMemberOrgIds(viewer: MemberViewer, memberId: string): Promise<string[]> {
  const rows = await prisma.memberOrganization.findMany({
    where: { memberId },
    select: { organizationId: true },
    orderBy: { organizationId: 'asc' },
  })
  const orgIds = rows.map((r) => r.organizationId)
  if (viewer.kind === 'self') return orgIds
  const visible: string[] = []
  for (const orgId of orgIds) {
    const scope = await memberAccessScope(viewer.userId, orgId)
    if (await canAccessMember(scope, memberId, orgId)) visible.push(orgId)
  }
  return visible
}

export async function canViewMember(userId: string, memberId: string, organizationId?: string): Promise<boolean> {
  const visible = await visibleMemberOrgIds({ kind: 'user', userId }, memberId)
  return organizationId ? visible.includes(organizationId) : visible.length > 0
}
```

- [ ] **Step 4: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/member-access.test.ts` → PASS (13 tests); `cd server && npx tsc --noEmit` → PASS. Nothing calls the service yet, so no restart is needed; the gate before any curl or walk against :3010 is `docker restart makeready-server`.

- [ ] **Step 5: Commit** — `feat(ui2-members-browse): member access scope service (D7)`

### Task 3: `GET /api/organizations/my/organizations` (D18)
App: server
Phase: 1
Recipe: /api

**Files:**
- Modify: `server/src/services/organization.ts:15-19` (new `OrganizationsResult` interface after `MembersResult`), and add `getUserOrganizations` after `resolveUserOrganizationId` (`:111-129`)
- Modify: `server/src/routes/organizations.ts:3-8` (import), and insert the new route + its `@openapi` block directly after the `/my/organization` handler (`:452-483`, i.e. after the `})` on `:483`)
- Test: `server/src/services/__tests__/user-organizations.test.ts`
- Test: `server/src/routes/__tests__/my-organizations.request.test.ts`

**Interfaces:**
- Consumes: Prisma `organization` (`ownerId`, `isActive`, `name`), `userRole` (`userId`, `organizationId`); `requireAuth` (`server/src/middleware/auth.ts:21`).
- Produces:
  - `export interface OrganizationsResult { success: boolean; data?: Organization[]; error?: string }`
  - `export async function getUserOrganizations(userId: string): Promise<OrganizationsResult>` — active orgs the user OWNS (`ownerId`, at most one — `ownerId` is unique) first, then active orgs where the user holds any `UserRole`, de-duplicated, ordered by `name` asc then `id` asc.
  - `GET /api/organizations/my/organizations` (`requireAuth`) → `200 {"success":true,"data":[{"id","name","ownerId","isActive","twilioVerifyServiceSid","createdAt","updatedAt"}]}` — the full `Organization` row, exactly what `/my/organization` returns per org (the iPhone's `OrganizationData` decodes `id`, `name`, `ownerId`, `createdAt`, `updatedAt`); an empty array when the user has none (never 404); `401 {"success":false,"error":"Not authenticated"}`; `500 {"success":false,"error":"Internal server error"}`.

Route order: the path has two segments, so the earlier one-segment `/:organizationId` GET (`:363`) cannot capture it, and no `/:organizationId/:x` GET exists (the two-segment GETs are literal `/members`, `/member-organizations`, `/non-members`).

- [ ] **Step 1: Write the failing service test** — create `server/src/services/__tests__/user-organizations.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  organization: { findMany: vi.fn() },
  userRole: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))

import { getUserOrganizations } from '../organization.js'

const org = (id: string, name: string, ownerId: string) => ({
  id,
  name,
  ownerId,
  isActive: true,
  twilioVerifyServiceSid: null,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
})

beforeEach(() => vi.clearAllMocks())

describe('getUserOrganizations (ui2-members-browse D18)', () => {
  it('lists the owned org first, then role-held orgs by name, without duplicates', async () => {
    prismaMock.organization.findMany
      .mockResolvedValueOnce([org('o-owned', 'Zion Church', 'u1')])
      .mockResolvedValueOnce([org('o-a', 'Alpha', 'x'), org('o-b', 'Beta', 'y')])
    prismaMock.userRole.findMany.mockResolvedValue([
      { organizationId: 'o-owned' },
      { organizationId: 'o-b' },
      { organizationId: 'o-a' },
      { organizationId: 'o-b' },
    ])

    const result = await getUserOrganizations('u1')

    expect(result.success).toBe(true)
    expect(result.data?.map((o) => o.id)).toEqual(['o-owned', 'o-a', 'o-b'])
    expect(prismaMock.organization.findMany).toHaveBeenNthCalledWith(1, {
      where: { ownerId: 'u1', isActive: true },
    })
    expect(prismaMock.userRole.findMany).toHaveBeenCalledWith({ where: { userId: 'u1' }, select: { organizationId: true } })
    expect(prismaMock.organization.findMany).toHaveBeenNthCalledWith(2, {
      where: { id: { in: ['o-b', 'o-a'] }, isActive: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    })
  })

  it('serves a role-only leader (no owned org) — the D18 case', async () => {
    prismaMock.organization.findMany.mockResolvedValueOnce([]).mockResolvedValueOnce([org('o-a', 'Alpha', 'x')])
    prismaMock.userRole.findMany.mockResolvedValue([{ organizationId: 'o-a' }])
    expect((await getUserOrganizations('gl')).data?.map((o) => o.id)).toEqual(['o-a'])
  })

  it('returns an empty list, with no second org query, for a user in no org', async () => {
    prismaMock.organization.findMany.mockResolvedValueOnce([])
    prismaMock.userRole.findMany.mockResolvedValue([])
    expect(await getUserOrganizations('nobody')).toEqual({ success: true, data: [] })
    expect(prismaMock.organization.findMany).toHaveBeenCalledTimes(1)
  })

  it('reports a failure instead of throwing', async () => {
    prismaMock.organization.findMany.mockRejectedValue(new Error('db down'))
    prismaMock.userRole.findMany.mockResolvedValue([])
    expect(await getUserOrganizations('u1')).toEqual({ success: false, error: 'Failed to fetch organizations' })
  })
})
```

- [ ] **Step 2: Write the failing request test** — create `server/src/routes/__tests__/my-organizations.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  getUserOrganizations: vi.fn(),
}))

import { getUserOrganizations } from '../../services/organization.js'
import organizationsRoutes from '../organizations.js'

/** requireAuth passes when req.user and req.apiKeyId are set (middleware/auth.ts:27). */
function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/organizations', organizationsRoutes)
  return app
}

const ORG = {
  id: 'o-a',
  name: 'Alpha',
  ownerId: 'x',
  isActive: true,
  twilioVerifyServiceSid: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-02T00:00:00.000Z'),
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getUserOrganizations).mockResolvedValue({ success: true, data: [ORG] })
})

describe('GET /api/organizations/my/organizations (D18, SC10)', () => {
  it('returns the caller’s orgs with the /my/organization fields', async () => {
    const res = await request(appAs('gl')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({
      success: true,
      data: [{ ...ORG, createdAt: '2026-01-01T00:00:00.000Z', updatedAt: '2026-01-02T00:00:00.000Z' }],
    })
    expect(getUserOrganizations).toHaveBeenCalledWith('gl')
  })

  it('answers an empty list with 200, never 404', async () => {
    vi.mocked(getUserOrganizations).mockResolvedValue({ success: true, data: [] })
    const res = await request(appAs('nobody')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: [] })
  })

  it('401s without auth', async () => {
    const res = await request(appAs()).get('/api/organizations/my/organizations')
    expect(res.status).toBe(401)
    expect(getUserOrganizations).not.toHaveBeenCalled()
  })

  it('500s when the service fails', async () => {
    vi.mocked(getUserOrganizations).mockResolvedValue({ success: false, error: 'Failed to fetch organizations' })
    const res = await request(appAs('gl')).get('/api/organizations/my/organizations')
    expect(res.status).toBe(500)
    expect(res.body).toEqual({ success: false, error: 'Internal server error' })
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/user-organizations.test.ts src/routes/__tests__/my-organizations.request.test.ts` → FAIL: `getUserOrganizations is not a function` (service suite) and `expected 404 to be 200` / `expected 404 to be 401` (request suite — no route matches the path yet, so Express answers 404).

- [ ] **Step 4: Write the service** — in `server/src/services/organization.ts`, after the `MembersResult` interface (`:15-19`) add:

```ts
export interface OrganizationsResult {
  success: boolean
  data?: Organization[]
  error?: string
}
```

and after `resolveUserOrganizationId` (ends `:129`) add:

```ts
/**
 * Every active organization a user owns or holds a role in — the owned one
 * first (ownerId is unique, so at most one), then role-held orgs by name
 * (ui2-members-browse D18: a non-owner Admin or Group Leader needs an org id
 * that the owner-only /my/organization cannot give them).
 */
export async function getUserOrganizations(userId: string): Promise<OrganizationsResult> {
  try {
    const [owned, roles] = await Promise.all([
      prisma.organization.findMany({ where: { ownerId: userId, isActive: true } }),
      prisma.userRole.findMany({ where: { userId }, select: { organizationId: true } }),
    ])
    const ownedIds = new Set(owned.map((o) => o.id))
    const roleOrgIds = [...new Set(roles.map((r) => r.organizationId))].filter((id) => !ownedIds.has(id))
    const roleHeld =
      roleOrgIds.length > 0
        ? await prisma.organization.findMany({
            where: { id: { in: roleOrgIds }, isActive: true },
            orderBy: [{ name: 'asc' }, { id: 'asc' }],
          })
        : []
    return { success: true, data: [...owned, ...roleHeld] }
  } catch (error) {
    console.error('Error fetching user organizations:', error)
    return { success: false, error: 'Failed to fetch organizations' }
  }
}
```

- [ ] **Step 5: Write the route** — in `server/src/routes/organizations.ts` add `getUserOrganizations,` to the import list from `'../services/organization.js'` (`:3-8`), and directly after the `/my/organization` handler's closing `})` (`:483`) insert:

```ts

/**
 * @openapi
 * /api/organizations/my/organizations:
 *   get:
 *     tags: [Organizations]
 *     summary: List every organization the user owns or holds a role in
 *     description: Owned organization first, then role-held organizations by name. Active organizations only. Used by the iPhone UI 2.0 shell when /my/organization has none (a non-owner Admin or Group Leader).
 *     security:
 *       - userSession: []
 *     responses:
 *       200:
 *         description: "{ success, data: Organization[] } — empty when the user has none"
 *       401:
 *         description: Not authenticated
 */
router.get('/my/organizations', requireAuth, async (req, res) => {
  try {
    const userId = (req.user as { id?: string } | undefined)?.id
    if (!userId) {
      return res.status(401).json({ success: false, error: 'Not authenticated' })
    }
    const result = await getUserOrganizations(userId)
    if (!result.success) {
      return res.status(500).json({ success: false, error: 'Internal server error' })
    }
    res.json({ success: true, data: result.data ?? [] })
  } catch (error) {
    console.error('Error fetching user organizations:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})
```

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/user-organizations.test.ts src/routes/__tests__/my-organizations.request.test.ts` → PASS (8 tests); `cd server && npx tsc --noEmit && npm run test:run` → PASS (the existing `organizations.test.ts` 401 cases for `/my/organization` are unchanged). vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server`.

- [ ] **Step 7: Commit** — `feat(ui2-members-browse): GET /api/organizations/my/organizations (D18)`

### Task 4: Members list — filters, groupCount, joinedAt order, token search, viewerScope (D6, D7, D15)
App: server
Phase: 2
Recipe: /api
Build-time risk (F9): The list has no pagination and returns whole rows; production org size is unknown — no pagination in this child; explicit `select` keeps the payload to the contract's keys.

**Files:**
- Modify: `server/src/services/organization.ts:1-2` (imports), `:160-213` (replace `getOrganizationMembers` and its doc comment; add `searchTokens`, `OrgMemberListItem`, `OrgMembersQuery`, `OrgMembersResult` above it). Line numbers are before Task 3's additions to this file — find the function by name.
- Modify: `server/src/routes/organizations.ts` — the `router.get('/:organizationId/members', …)` handler (`:723-757` before Task 3's insert above it; find it by that path string) and two new query parameters in its `@openapi` block, after the `includeInactive` parameter (`:646-652` before Task 3).
- Test: `server/src/services/__tests__/organization-members.test.ts`
- Test: `server/src/routes/__tests__/organization-members.request.test.ts`

**Interfaces:**
- Consumes: `memberAccessScope(userId: string, orgId: string): Promise<MemberAccessScope>` and `type MemberAccessScope = { all: true } | { all: false; groupIds: string[] }` (Task 2, `server/src/services/member-access.ts`); `requireAuth`, `requirePermission('member.read', 'organization', …)` (unchanged on the route).
- Produces:
  - `export function searchTokens(search: string | undefined): string[]` — whitespace-split, empties dropped.
  - `export interface OrgMemberListItem { id: string; firstName: string | null; lastName: string | null; profilePicture: string | null; googlePicture: string | null; joinedAt: Date; groupCount: number }`
  - `export interface OrgMembersQuery { includeInactive?: boolean; search?: string; groupId?: string; leaderId?: string }`
  - `export interface OrgMembersResult { success: boolean; data?: OrgMemberListItem[]; viewerScope?: { all: boolean; groupIds: string[] }; error?: string }`
  - `export async function getOrganizationMembers(organizationId: string, viewerUserId: string, options?: OrgMembersQuery): Promise<OrgMembersResult>` (signature CHANGED — the route is its only caller).
  - Wire: `GET /api/organizations/:organizationId/members?search=&groupId=&leaderId=&includeInactive=` → `200 {"success":true,"data":[{"id","firstName","lastName","profilePicture","googlePicture","joinedAt","groupCount"}],"count":<int>,"viewerScope":{"all":<bool>,"groupIds":[<string>]}}` — `joinedAt` = this org's `MemberOrganization.joinedAt` as ISO (`2026-10-25T15:00:00.000Z`); `groupCount` = the member's active memberships in active groups of THIS org; rows ordered `joinedAt` desc then member id asc (D6 — the iPhone does not re-sort); `viewerScope.groupIds` is `[]` when `all` is true; no other member column appears (SC1–SC3 never do). `search` tokens each match first name, last name, email (case-insensitive) or phone (substring) and are AND-combined with each other and with `groupId`/`leaderId`. A `groupId`/`leaderId` outside the org, or outside a narrowed caller's scope (a `groupId` not in `viewerScope.groupIds`, a `leaderId` other than the caller), returns `200` with `data: []`. Errors unchanged: 401 · 403 (`member.read`) · 500.

- [ ] **Step 1: Write the failing service test** — create `server/src/services/__tests__/organization-members.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ memberOrganization: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../member-access.js', () => ({ memberAccessScope: vi.fn() }))

import { memberAccessScope } from '../member-access.js'
import { getOrganizationMembers, searchTokens } from '../organization.js'

const ORG = 'org-1'
const row = (id: string, joinedAt: string, groupCount: number) => ({
  joinedAt: new Date(joinedAt),
  member: {
    id,
    firstName: `F-${id}`,
    lastName: `L-${id}`,
    profilePicture: null,
    googlePicture: `https://g/${id}`,
    _count: { groupMemberships: groupCount },
  },
})
const activeIn = (group: Record<string, unknown>) => ({
  groupMemberships: { some: { isActive: true, group: { isActive: true, organizationId: ORG, ...group } } },
})
const tokenMatch = (t: string) => ({
  OR: [
    { firstName: { contains: t, mode: 'insensitive' } },
    { lastName: { contains: t, mode: 'insensitive' } },
    { email: { contains: t, mode: 'insensitive' } },
    { phoneNumber: { contains: t } },
  ],
})
const SELECT = {
  joinedAt: true,
  member: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      profilePicture: true,
      googlePicture: true,
      _count: {
        select: { groupMemberships: { where: { isActive: true, group: { isActive: true, organizationId: ORG } } } },
      },
    },
  },
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(memberAccessScope).mockResolvedValue({ all: true })
  prismaMock.memberOrganization.findMany.mockResolvedValue([
    row('m2', '2026-10-25T15:00:00Z', 2),
    row('m1', '2026-09-01T15:00:00Z', 1),
  ])
})

describe('searchTokens (D6 search)', () => {
  it('splits on any whitespace and drops empties', () => {
    expect(searchTokens('  jo   sm\tx ')).toEqual(['jo', 'sm', 'x'])
    expect(searchTokens('')).toEqual([])
    expect(searchTokens(undefined)).toEqual([])
  })
})

describe('getOrganizationMembers — Owner/Admin (all)', () => {
  it('queries member_organizations by joinedAt desc with an explicit select and maps the contract keys', async () => {
    const result = await getOrganizationMembers(ORG, 'owner-1')
    expect(memberAccessScope).toHaveBeenCalledWith('owner-1', ORG)
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledWith({
      where: { organizationId: ORG, member: { AND: [{ isActive: true }] } },
      orderBy: [{ joinedAt: 'desc' }, { memberId: 'asc' }],
      select: SELECT,
    })
    expect(result).toEqual({
      success: true,
      viewerScope: { all: true, groupIds: [] },
      data: [
        { id: 'm2', firstName: 'F-m2', lastName: 'L-m2', profilePicture: null, googlePicture: 'https://g/m2', joinedAt: new Date('2026-10-25T15:00:00Z'), groupCount: 2 },
        { id: 'm1', firstName: 'F-m1', lastName: 'L-m1', profilePicture: null, googlePicture: 'https://g/m1', joinedAt: new Date('2026-09-01T15:00:00Z'), groupCount: 1 },
      ],
    })
  })

  it('AND-combines every search token with groupId and leaderId', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { search: 'jo sm', groupId: 'g1', leaderId: 'leader-9' })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: {
        AND: [{ isActive: true }, tokenMatch('jo'), tokenMatch('sm'), activeIn({ id: 'g1' }), activeIn({ creatorId: 'leader-9' })],
      },
    })
  })

  it('drops the isActive filter with includeInactive', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { includeInactive: true })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({ organizationId: ORG, member: { AND: [] } })
  })

  it('lets the org constraint empty a foreign groupId (no special case needed)', async () => {
    await getOrganizationMembers(ORG, 'owner-1', { groupId: 'g-other-org' })
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where.member.AND).toContainEqual(activeIn({ id: 'g-other-org' }))
  })
})

describe('getOrganizationMembers — narrowed leader (D7, D15)', () => {
  beforeEach(() => {
    vi.mocked(memberAccessScope).mockResolvedValue({ all: false, groupIds: ['g-led'] })
  })

  it('limits the list to members of the caller’s groups and reports viewerScope', async () => {
    const result = await getOrganizationMembers(ORG, 'gl')
    expect(prismaMock.memberOrganization.findMany.mock.calls[0][0].where).toEqual({
      organizationId: ORG,
      member: { AND: [{ isActive: true }, activeIn({ id: { in: ['g-led'] } })] },
    })
    expect(result.viewerScope).toEqual({ all: false, groupIds: ['g-led'] })
  })

  it('accepts its own group and itself as leader', async () => {
    await getOrganizationMembers(ORG, 'gl', { groupId: 'g-led', leaderId: 'gl' })
    expect(prismaMock.memberOrganization.findMany).toHaveBeenCalledTimes(1)
  })

  it.each([
    ['a groupId outside its scope', { groupId: 'g-someone-else' }],
    ['a leaderId other than itself', { leaderId: 'other-leader' }],
  ])('answers %s with an empty list, without querying', async (_label, options) => {
    const result = await getOrganizationMembers(ORG, 'gl', options)
    expect(result).toEqual({ success: true, data: [], viewerScope: { all: false, groupIds: ['g-led'] } })
    expect(prismaMock.memberOrganization.findMany).not.toHaveBeenCalled()
  })

  it('answers a leader with no groups with an empty list', async () => {
    vi.mocked(memberAccessScope).mockResolvedValue({ all: false, groupIds: [] })
    const result = await getOrganizationMembers(ORG, 'gl')
    expect(result).toEqual({ success: true, data: [], viewerScope: { all: false, groupIds: [] } })
    expect(prismaMock.memberOrganization.findMany).not.toHaveBeenCalled()
  })
})

describe('getOrganizationMembers — failure', () => {
  it('reports instead of throwing', async () => {
    prismaMock.memberOrganization.findMany.mockRejectedValue(new Error('db down'))
    expect(await getOrganizationMembers(ORG, 'owner-1')).toEqual({ success: false, error: 'Failed to fetch members' })
  })
})
```

- [ ] **Step 2: Write the failing request test** — create `server/src/routes/__tests__/organization-members.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // member.read itself is exercised by the existing permission tests; here it always passes.
  requirePermission: () => (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/organization.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/organization.js')>()),
  getOrganizationMembers: vi.fn(),
}))

import { getOrganizationMembers } from '../../services/organization.js'
import organizationsRoutes from '../organizations.js'

function appAs(userId?: string) {
  const app = express()
  app.use((req, _res, next) => {
    if (userId) Object.assign(req, { user: { id: userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/organizations', organizationsRoutes)
  return app
}

const ITEM = {
  id: 'm2',
  firstName: 'Ruth',
  lastName: 'Sullivan',
  profilePicture: null,
  googlePicture: null,
  joinedAt: new Date('2026-10-25T15:00:00.000Z'),
  groupCount: 2,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getOrganizationMembers).mockResolvedValue({
    success: true,
    data: [ITEM],
    viewerScope: { all: false, groupIds: ['g-led'] },
  })
})

describe('GET /api/organizations/:organizationId/members (SC4, SC9)', () => {
  it('passes the caller and every filter to the service and returns the contract body', async () => {
    const res = await request(appAs('gl')).get(
      '/api/organizations/org-1/members?search=ru%20su&groupId=g-led&leaderId=gl&includeInactive=true'
    )
    expect(res.status).toBe(200)
    expect(getOrganizationMembers).toHaveBeenCalledWith('org-1', 'gl', {
      search: 'ru su',
      groupId: 'g-led',
      leaderId: 'gl',
      includeInactive: true,
    })
    expect(res.body).toEqual({
      success: true,
      data: [{ ...ITEM, joinedAt: '2026-10-25T15:00:00.000Z' }],
      count: 1,
      viewerScope: { all: false, groupIds: ['g-led'] },
    })
  })

  it('treats absent or empty filters as absent', async () => {
    await request(appAs('owner-1')).get('/api/organizations/org-1/members?groupId=&search=')
    expect(getOrganizationMembers).toHaveBeenCalledWith('org-1', 'owner-1', {
      search: undefined,
      groupId: undefined,
      leaderId: undefined,
      includeInactive: false,
    })
  })

  it('answers an empty result with 200 and count 0', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: true, data: [], viewerScope: { all: false, groupIds: [] } })
    const res = await request(appAs('gl')).get('/api/organizations/org-1/members?groupId=g-foreign')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, data: [], count: 0, viewerScope: { all: false, groupIds: [] } })
  })

  it('500s when the service fails, 401s without auth', async () => {
    vi.mocked(getOrganizationMembers).mockResolvedValue({ success: false, error: 'Failed to fetch members' })
    expect((await request(appAs('gl')).get('/api/organizations/org-1/members')).status).toBe(500)
    expect((await request(appAs()).get('/api/organizations/org-1/members')).status).toBe(401)
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/organization-members.test.ts src/routes/__tests__/organization-members.request.test.ts` → FAIL: `searchTokens is not a function`; `expected "spy" to be called with arguments: [ 'owner-1', 'org-1' ]` (memberAccessScope is never called); the request suite fails on `toHaveBeenCalledWith('org-1', 'gl', …)` (today the route passes `(organizationId, { search, includeInactive })`) and on the missing `viewerScope`.

- [ ] **Step 4: Write the service** — in `server/src/services/organization.ts` change the imports (`:1-2`) to

```ts
import { prisma } from '../lib/prisma.js'
import type { Organization, Member, Prisma } from '../generated/prisma/index.js'
import { memberAccessScope } from './member-access.js'
```

(`Member` stays imported only if `MembersResult` still uses it — it does; keep `MembersResult` as it is.) Replace the doc comment and body of `getOrganizationMembers` (`:160-213`) with:

```ts
export interface OrgMemberListItem {
  id: string
  firstName: string | null
  lastName: string | null
  profilePicture: string | null
  googlePicture: string | null
  /** This org's MemberOrganization.joinedAt (D6). */
  joinedAt: Date
  /** Active memberships in active groups of this org (SC4). */
  groupCount: number
}

export interface OrgMembersQuery {
  includeInactive?: boolean
  search?: string
  groupId?: string
  /** A User.id from /api/group-leaders → members of groups with that creatorId. */
  leaderId?: string
}

export interface OrgMembersResult {
  success: boolean
  data?: OrgMemberListItem[]
  /** D15: how the iPhone learns the caller's D7 scope. groupIds is [] when all. */
  viewerScope?: { all: boolean; groupIds: string[] }
  error?: string
}

/** D6 search: whitespace-separated tokens, each matched on its own and AND-combined. */
export function searchTokens(search: string | undefined): string[] {
  return (search ?? '').split(/\s+/).filter((t) => t.length > 0)
}

/**
 * The org's member directory (ui2-members-browse SC4, SC9, D6, D7, D15).
 * Queried through member_organizations because Prisma cannot order Member by a
 * filtered to-many (the joinedAt of THIS org). An explicit select keeps the
 * payload to the contract's keys (F9 — no pagination in this child). A narrowed
 * caller (memberAccessScope → groups) sees only members of the groups they
 * created; a groupId or leaderId outside that scope answers an empty list.
 */
export async function getOrganizationMembers(
  organizationId: string,
  viewerUserId: string,
  options: OrgMembersQuery = {}
): Promise<OrgMembersResult> {
  try {
    const { includeInactive = false, search, groupId, leaderId } = options
    const scope = await memberAccessScope(viewerUserId, organizationId)
    const viewerScope = { all: scope.all, groupIds: scope.all ? [] : scope.groupIds }
    if (!scope.all) {
      const outside =
        scope.groupIds.length === 0 ||
        (groupId !== undefined && !scope.groupIds.includes(groupId)) ||
        (leaderId !== undefined && leaderId !== viewerUserId)
      if (outside) return { success: true, data: [], viewerScope }
    }

    const activeIn = (group: Prisma.GroupWhereInput): Prisma.MemberWhereInput => ({
      groupMemberships: { some: { isActive: true, group: { isActive: true, organizationId, ...group } } },
    })
    const and: Prisma.MemberWhereInput[] = []
    if (!includeInactive) and.push({ isActive: true })
    for (const token of searchTokens(search)) {
      and.push({
        OR: [
          { firstName: { contains: token, mode: 'insensitive' } },
          { lastName: { contains: token, mode: 'insensitive' } },
          { email: { contains: token, mode: 'insensitive' } },
          { phoneNumber: { contains: token } },
        ],
      })
    }
    if (groupId !== undefined) and.push(activeIn({ id: groupId }))
    if (leaderId !== undefined) and.push(activeIn({ creatorId: leaderId }))
    if (!scope.all) and.push(activeIn({ id: { in: scope.groupIds } }))

    const rows = await prisma.memberOrganization.findMany({
      where: { organizationId, member: { AND: and } },
      orderBy: [{ joinedAt: 'desc' }, { memberId: 'asc' }],
      select: {
        joinedAt: true,
        member: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            profilePicture: true,
            googlePicture: true,
            _count: {
              select: {
                groupMemberships: { where: { isActive: true, group: { isActive: true, organizationId } } },
              },
            },
          },
        },
      },
    })

    return {
      success: true,
      viewerScope,
      data: rows.map(({ joinedAt, member }) => ({
        id: member.id,
        firstName: member.firstName,
        lastName: member.lastName,
        profilePicture: member.profilePicture,
        googlePicture: member.googlePicture,
        joinedAt,
        groupCount: member._count.groupMemberships,
      })),
    }
  } catch (error) {
    console.error('Error fetching organization members:', error)
    return { success: false, error: 'Failed to fetch members' }
  }
}
```

- [ ] **Step 5: Point the route at it** — in `server/src/routes/organizations.ts`, replace the body of the `router.get('/:organizationId/members', requireAuth, requirePermission(…), async (req, res) => { … })` handler (keep both middlewares exactly as they are) with:

```ts
  async (req, res) => {
    try {
      const { organizationId } = req.params
      const userId = (req.user as { id: string }).id // requirePermission has already 401'd a missing user
      const text = (v: unknown) => (typeof v === 'string' && v.length > 0 ? v : undefined)

      const result = await getOrganizationMembers(organizationId, userId, {
        search: text(req.query.search),
        groupId: text(req.query.groupId),
        leaderId: text(req.query.leaderId),
        includeInactive: req.query.includeInactive === 'true',
      })

      if (!result.success) {
        return res.status(500).json({
          success: false,
          error: result.error,
        })
      }

      res.json({
        success: true,
        data: result.data,
        count: result.data?.length || 0,
        viewerScope: result.viewerScope,
      })
    } catch (error) {
      console.error('Error fetching organization members:', error)
      res.status(500).json({
        success: false,
        error: 'Internal server error',
      })
    }
  }
```

and in that route's `@openapi` block, after the `includeInactive` query parameter (the lines ending `example: "true"`), add:

```ts
 *       - in: query
 *         name: groupId
 *         required: false
 *         schema:
 *           type: string
 *         description: Only members active in this group of the organization (empty list when outside the org or the caller's scope)
 *       - in: query
 *         name: leaderId
 *         required: false
 *         schema:
 *           type: string
 *         description: A User.id from /api/group-leaders — only members of groups that user created
```

and change the `search` parameter's description to `Whitespace-separated tokens; each matches first name, last name, email or phone, and all must match`.

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/organization-members.test.ts src/routes/__tests__/organization-members.request.test.ts` → PASS (15 tests); `cd server && npx tsc --noEmit && npm run test:run` → PASS (the existing `organizations.test.ts` 401 cases for this route are unchanged). vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server`.

- [ ] **Step 7: Commit** — `feat(ui2-members-browse): members list filters, groupCount, joinedAt order and viewer scope`

### Task 5: `GET /api/members/:id` and `/:id/groups` scoped (D7, D8, D16)
App: server
Phase: 2
Recipe: /api

D7 is applied in the SERVICE layer, not inside `requireMemberOrOrgOwner` (SPEC T3): that middleware also guards PATCH, DELETE, link-google and history (`members.ts:1189,1267,1682,1875`), which this child must not change. The middleware keeps answering 401 (no session) and 403 (caller manages none of the member's orgs); the service answers "in-org but outside the caller's D7 scope" as not found → 404.

**Files:**
- Modify: `server/src/services/member.ts:1-2` (imports), `:21-25` (add `ScopedGroupsResult`, `MemberWithOrganizations`, `ScopedMemberResult` after `GroupsResult`), `:310-330` (`getMemberGroups` gains an optional `organizationIds` filter), and add `getScopedMember` + `getScopedMemberGroups` after `getMemberGroups` (after `:371`)
- Modify: `server/src/routes/members.ts:1` (`type Request` import), `:5-13` (service imports: add `getScopedMember`, `getScopedMemberGroups`; REMOVE `getMemberGroups`, which the route no longer calls — `noUnusedLocals`), `:24-28` (add the `MemberViewer` type import below the middleware import), `:52` (add `viewerOf` after `const router = Router()`), `:1096-1119` (the `GET /:memberId` handler), `:1608-1637` (the `GET /:memberId/groups` handler)
- Test: `server/src/services/__tests__/member-scope.test.ts`
- Test: `server/src/routes/__tests__/members-scope.request.test.ts`

**Interfaces:**
- Consumes: `visibleMemberOrgIds(viewer: MemberViewer, memberId: string): Promise<string[]>`, `type MemberViewer = { kind: 'self' } | { kind: 'user'; userId: string }` (Task 2, `server/src/services/member-access.ts`); `Member.address`, `emergencyContactName`, `emergencyContactPhone` (Task 1); `requireMemberOrOrgOwner` (`server/src/middleware/auth.ts:246`, unchanged).
- Produces:
  - `export type MemberWithOrganizations = Prisma.MemberGetPayload<typeof memberWithOrganizations>` — a Member row with `organizations: [{ id, memberId, organizationId, joinedAt, createdAt, updatedAt, organization: { id, name, ownerId } }]`.
  - `export interface ScopedMemberResult { success: boolean; data?: MemberWithOrganizations & { isGroupLeader: boolean }; error?: string }`
  - `export interface ScopedGroupsResult extends GroupsResult { notFound?: boolean }`
  - `export async function getScopedMember(memberId: string, viewer: MemberViewer): Promise<ScopedMemberResult>`
  - `export async function getScopedMemberGroups(memberId: string, viewer: MemberViewer, includeInactive?: boolean): Promise<ScopedGroupsResult>`
  - `getMemberGroups(memberId: string, includeInactive?: boolean, organizationIds?: string[]): Promise<GroupsResult>` (third parameter new, optional).
  - Wire `GET /api/members/:memberId` → `200 {"success":true,"data":{…every Member column incl. "address","emergencyContactName","emergencyContactPhone" (string|null)…, "organizations":[{…,"organization":{"id","name","ownerId"}}], "isGroupLeader":<bool>}}` — `organizations[]` holds only the orgs the caller's D7 scope covers (a member session reading itself: all of its orgs); `isGroupLeader` = `userId` non-null and that user created ≥ 1 active group in one of those orgs; `404 {"success":false,"error":"Member not found"}` when the member is outside the caller's scope in every org; 401 · 403 from the middleware as today.
  - Wire `GET /api/members/:memberId/groups` → existing `{"success":true,"data":[…group, "memberCount", "joinedAt"],"count"}`, limited to groups in the caller-visible orgs (D16 — every group of the member there, not only the caller's own); `404 {"success":false,"error":"Member not found"}` outside the scope; a member reading itself is unchanged (every org).
  - Route helper (module-private): `viewerOf(req: Request, memberId: string): MemberViewer | null`.

- [ ] **Step 1: Write the failing service test** — create `server/src/services/__tests__/member-scope.test.ts` (the REAL `member-access.ts` runs over mocked Prisma, so the D7 rule itself is exercised end to end)

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  member: { findUnique: vi.fn() },
  memberOrganization: { findMany: vi.fn(), count: vi.fn() },
  organization: { findUnique: vi.fn() },
  userRole: { findFirst: vi.fn() },
  group: { findMany: vi.fn(), count: vi.fn() },
  groupMember: { count: vi.fn(), findMany: vi.fn() },
}))
const permissionMock = vi.hoisted(() => ({ isSuperAdmin: vi.fn() }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../permission.js', () => permissionMock)

import { getScopedMember, getScopedMemberGroups } from '../member.js'

/** m1 belongs to o1 (owner-1) and o2 (owner-2); it is active in g-led (o1), which 'gl' created. */
const OWNER_OF: Record<string, string> = { o1: 'owner-1', o2: 'owner-2' }
const CREATED: Record<string, Record<string, string[]>> = { gl: { o1: ['g-led'] }, gl2: { o1: ['g-other'] } }
const orgRow = (id: string, name: string) => ({
  id: `mo-${id}`,
  memberId: 'm1',
  organizationId: id,
  joinedAt: new Date('2026-08-24T15:00:00Z'),
  createdAt: new Date('2026-08-24T15:00:00Z'),
  updatedAt: new Date('2026-08-24T15:00:00Z'),
  organization: { id, name, ownerId: OWNER_OF[id] },
})
const MEMBER = {
  id: 'm1',
  firstName: 'James',
  lastName: 'Carter',
  userId: 'u-linked',
  address: '100 Maple Ave\nChicago, IL 60614',
  emergencyContactName: 'Sophia Carter',
  emergencyContactPhone: '+15550200001',
  organizations: [orgRow('o1', 'Grace Church'), orgRow('o2', 'Hope Chapel')],
}
const MEMBERSHIP = {
  joinedAt: new Date('2026-09-01T15:00:00Z'),
  group: { id: 'g-led', name: 'Prayer Team', organizationId: 'o1', creator: { id: 'gl', name: 'Nathan Hughes', email: null, picture: null }, _count: { members: 3 } },
}

beforeEach(() => {
  vi.clearAllMocks()
  permissionMock.isSuperAdmin.mockResolvedValue(false)
  prismaMock.member.findUnique.mockResolvedValue(MEMBER)
  prismaMock.memberOrganization.findMany.mockResolvedValue([{ organizationId: 'o1' }, { organizationId: 'o2' }])
  prismaMock.memberOrganization.count.mockResolvedValue(1)
  prismaMock.organization.findUnique.mockImplementation(async ({ where }: any) => ({ ownerId: OWNER_OF[where.id] }))
  prismaMock.userRole.findFirst.mockResolvedValue(null)
  prismaMock.group.findMany.mockImplementation(async ({ where }: any) =>
    (CREATED[where.creatorId]?.[where.organizationId] ?? []).map((id) => ({ id }))
  )
  prismaMock.groupMember.count.mockImplementation(async ({ where }: any) =>
    where.memberId === 'm1' && where.groupId.in.includes('g-led') ? 1 : 0
  )
  prismaMock.group.count.mockResolvedValue(1)
  prismaMock.groupMember.findMany.mockResolvedValue([MEMBERSHIP])
})

describe('getScopedMember (D7, D8, SC8)', () => {
  it('Owner of one org: sees the member, organizations[] keeps only that org, Role from the linked user', async () => {
    const result = await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })
    expect(result.success).toBe(true)
    expect(result.data?.organizations.map((o) => o.organization.name)).toEqual(['Grace Church'])
    expect(result.data).toMatchObject({
      address: MEMBER.address,
      emergencyContactName: 'Sophia Carter',
      emergencyContactPhone: '+15550200001',
      isGroupLeader: true,
    })
    expect(prismaMock.group.count).toHaveBeenCalledWith({
      where: { creatorId: 'u-linked', isActive: true, organizationId: { in: ['o1'] } },
    })
  })

  it('super admin: every org of a multi-org member', async () => {
    permissionMock.isSuperAdmin.mockResolvedValue(true)
    const result = await getScopedMember('m1', { kind: 'user', userId: 'sa' })
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1', 'o2'])
  })

  it('Group Leader whose group holds the member: sees it in that org', async () => {
    const result = await getScopedMember('m1', { kind: 'user', userId: 'gl' })
    expect(result.success).toBe(true)
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1'])
  })

  it('Group Leader whose groups do not hold the member: not found (the route answers 404)', async () => {
    expect(await getScopedMember('m1', { kind: 'user', userId: 'gl2' })).toEqual({ success: false, error: 'Member not found' })
    expect(prismaMock.group.count).not.toHaveBeenCalled()
  })

  it('isGroupLeader is false, without a query, when no user is linked', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ ...MEMBER, userId: null })
    const result = await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })
    expect(result.data?.isGroupLeader).toBe(false)
    expect(prismaMock.group.count).not.toHaveBeenCalled()
  })

  it('isGroupLeader is false when the linked user created no active group in a visible org', async () => {
    prismaMock.group.count.mockResolvedValue(0)
    expect((await getScopedMember('m1', { kind: 'user', userId: 'owner-1' })).data?.isGroupLeader).toBe(false)
  })

  it('a member reading itself is unscoped: every org', async () => {
    const result = await getScopedMember('m1', { kind: 'self' })
    expect(result.data?.organizations.map((o) => o.organizationId)).toEqual(['o1', 'o2'])
    expect(prismaMock.organization.findUnique).not.toHaveBeenCalled()
  })

  it('a member with no org can still read itself', async () => {
    prismaMock.member.findUnique.mockResolvedValue({ ...MEMBER, organizations: [] })
    prismaMock.memberOrganization.findMany.mockResolvedValue([])
    const result = await getScopedMember('m1', { kind: 'self' })
    expect(result).toMatchObject({ success: true, data: { organizations: [], isGroupLeader: false } })
  })

  it('an unknown member is not found', async () => {
    prismaMock.member.findUnique.mockResolvedValue(null)
    expect(await getScopedMember('nope', { kind: 'user', userId: 'owner-1' })).toEqual({ success: false, error: 'Member not found' })
  })
})

describe('getScopedMemberGroups (D16)', () => {
  it('limits a user to groups in the orgs they see the member in — every such group, not only their own', async () => {
    const result = await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl' })
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      isActive: true,
      group: { isActive: true, organizationId: { in: ['o1'] } },
    })
    expect(result).toMatchObject({ success: true, data: [{ id: 'g-led', memberCount: 3 }] })
  })

  it('keeps the org filter with includeInactive', async () => {
    await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl' }, true)
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      group: { organizationId: { in: ['o1'] } },
    })
  })

  it('is not found outside the caller’s scope, without reading groups', async () => {
    expect(await getScopedMemberGroups('m1', { kind: 'user', userId: 'gl2' })).toEqual({
      success: false,
      error: 'Member not found',
      notFound: true,
    })
    expect(prismaMock.groupMember.findMany).not.toHaveBeenCalled()
  })

  it('a member reading itself is unchanged: no org filter', async () => {
    await getScopedMemberGroups('m1', { kind: 'self' })
    expect(prismaMock.groupMember.findMany.mock.calls[0][0].where).toEqual({
      memberId: 'm1',
      isActive: true,
      group: { isActive: true },
    })
  })
})
```

- [ ] **Step 2: Write the failing request test** — create `server/src/routes/__tests__/members-scope.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  // 401/403 stay the middleware's (unchanged); these tests are about D7 in the service.
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member.js')>()),
  getScopedMember: vi.fn(),
  getScopedMemberGroups: vi.fn(),
}))

import { getScopedMember, getScopedMemberGroups } from '../../services/member.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const DATA = {
  id: 'm1',
  firstName: 'James',
  address: '100 Maple Ave\nChicago, IL 60614',
  emergencyContactName: 'Sophia Carter',
  emergencyContactPhone: '+15550200001',
  organizations: [],
  isGroupLeader: false,
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getScopedMember).mockResolvedValue({ success: true, data: DATA as never })
  vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: true, data: [] })
})

describe('GET /api/members/:memberId (D7)', () => {
  it('scopes a user caller and returns the member with the new keys', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1')
    expect(res.status).toBe(200)
    expect(getScopedMember).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' })
    expect(res.body).toEqual({ success: true, data: DATA })
  })

  it('404s a member outside the caller’s scope', async () => {
    vi.mocked(getScopedMember).mockResolvedValue({ success: false, error: 'Member not found' })
    const res = await request(appAs({ userId: 'gl2' })).get('/api/members/m1')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
  })

  it('reads a member session’s own record unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1')
    expect(getScopedMember).toHaveBeenCalledWith('m1', { kind: 'self' })
  })

  it('403s a caller that is neither the member nor a user', async () => {
    const res = await request(appAs({ memberId: 'm-other' })).get('/api/members/m1')
    expect(res.status).toBe(403)
    expect(getScopedMember).not.toHaveBeenCalled()
  })
})

describe('GET /api/members/:memberId/groups (D7, D16)', () => {
  it('scopes a user caller and keeps the existing body', async () => {
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: true, data: [{ id: 'g-led' } as never] })
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/groups?includeInactive=true')
    expect(res.status).toBe(200)
    expect(getScopedMemberGroups).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' }, true)
    expect(res.body).toEqual({ success: true, data: [{ id: 'g-led' }], count: 1 })
  })

  it('404s outside the scope, 500s any other failure', async () => {
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: false, error: 'Member not found', notFound: true })
    expect((await request(appAs({ userId: 'gl2' })).get('/api/members/m1/groups')).status).toBe(404)
    vi.mocked(getScopedMemberGroups).mockResolvedValue({ success: false, error: 'Failed to fetch groups' })
    expect((await request(appAs({ userId: 'gl' })).get('/api/members/m1/groups')).status).toBe(500)
  })

  it('reads a member session’s own groups unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1/groups')
    expect(getScopedMemberGroups).toHaveBeenCalledWith('m1', { kind: 'self' }, false)
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/member-scope.test.ts src/routes/__tests__/members-scope.request.test.ts` → FAIL: `getScopedMember is not a function` / `getScopedMemberGroups is not a function` (service suite); the request suite fails `expected "spy" to be called with arguments: [ 'm1', { kind: 'user', userId: 'gl' } ]` (the route still calls `getMember`).

- [ ] **Step 4: Write the service** — in `server/src/services/member.ts` change `:1-2` to

```ts
import { prisma } from '../lib/prisma.js'
import type { Member, Group, Prisma } from '../generated/prisma/index.js'
import { type MemberViewer, visibleMemberOrgIds } from './member-access.js'
```

after `GroupsResult` (`:21-25`) add

```ts
export interface ScopedGroupsResult extends GroupsResult {
  /** The member is outside the caller's D7 scope in every org → 404. */
  notFound?: boolean
}

const memberWithOrganizations = {
  include: {
    organizations: { include: { organization: { select: { id: true, name: true, ownerId: true } } } },
  },
} satisfies Prisma.MemberDefaultArgs

export type MemberWithOrganizations = Prisma.MemberGetPayload<typeof memberWithOrganizations>

export interface ScopedMemberResult {
  success: boolean
  data?: MemberWithOrganizations & { isGroupLeader: boolean }
  error?: string
}
```

change `getMemberGroups`' signature and `where` (`:316-328`) to

```ts
export async function getMemberGroups(
  memberId: string,
  includeInactive: boolean = false,
  organizationIds?: string[]
): Promise<GroupsResult> {
  try {
    const where: any = {
      memberId,
    }

    if (!includeInactive) {
      where.isActive = true
      where.group = { isActive: true }
    }

    // D16: a scoped caller sees only the member's groups in the orgs it sees the member in.
    if (organizationIds) {
      where.group = { ...(where.group ?? {}), organizationId: { in: organizationIds } }
    }
```

(the rest of `getMemberGroups` is unchanged), and after `getMemberGroups` (after `:371`) add

```ts
/**
 * GET /api/members/:id for the UI 2.0 member page (ui2-members-browse D7, D8,
 * SC8). A user sees the member only through orgs memberAccessScope covers;
 * outside every one → "Member not found" (the route answers 404). The payload
 * keeps only those orgs in organizations[], and isGroupLeader = the linked user
 * created an active group in one of them. A member reading itself is unscoped.
 */
export async function getScopedMember(memberId: string, viewer: MemberViewer): Promise<ScopedMemberResult> {
  try {
    const member = await prisma.member.findUnique({ where: { id: memberId }, ...memberWithOrganizations })
    if (!member) return { success: false, error: 'Member not found' }
    const visible = await visibleMemberOrgIds(viewer, memberId)
    if (viewer.kind === 'user' && visible.length === 0) return { success: false, error: 'Member not found' }

    const organizations = member.organizations.filter((mo) => visible.includes(mo.organizationId))
    const isGroupLeader =
      member.userId !== null &&
      visible.length > 0 &&
      (await prisma.group.count({
        where: { creatorId: member.userId, isActive: true, organizationId: { in: visible } },
      })) > 0

    return { success: true, data: { ...member, organizations, isGroupLeader } }
  } catch (error) {
    console.error('Error fetching scoped member:', error)
    return { success: false, error: 'Failed to fetch member' }
  }
}

/** GET /api/members/:id/groups under D7 + D16; a member reading itself is unchanged. */
export async function getScopedMemberGroups(
  memberId: string,
  viewer: MemberViewer,
  includeInactive: boolean = false
): Promise<ScopedGroupsResult> {
  if (viewer.kind === 'self') return getMemberGroups(memberId, includeInactive)
  try {
    const visible = await visibleMemberOrgIds(viewer, memberId)
    if (visible.length === 0) return { success: false, error: 'Member not found', notFound: true }
    return getMemberGroups(memberId, includeInactive, visible)
  } catch (error) {
    console.error('Error fetching scoped member groups:', error)
    return { success: false, error: 'Failed to fetch groups' }
  }
}
```

- [ ] **Step 5: Point the two routes at it** — in `server/src/routes/members.ts`: line 1 becomes `import { Router, type Request } from 'express'`; in the `'../services/member.js'` import list (`:5-13`) replace `getMemberGroups,` with `getScopedMember,` and `getScopedMemberGroups,`; after the middleware import (`:24-28`) add `import type { MemberViewer } from '../services/member-access.js'`; after `const router = Router()` (`:52`) add

```ts

/**
 * ui2-members-browse D7: a member session reading its own record is unscoped;
 * any other caller is a user, scoped in the service by memberAccessScope.
 * null = neither (requireMemberOrOrgOwner normally 403s that first).
 */
function viewerOf(req: Request, memberId: string): MemberViewer | null {
  if (req.session?.memberId === memberId) return { kind: 'self' }
  const userId = (req.user as { id?: string } | undefined)?.id
  return userId ? { kind: 'user', userId } : null
}
```

replace the `GET /:memberId` handler (`:1096-1119`) with

```ts
router.get('/:memberId', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params
    const viewer = viewerOf(req, memberId)
    if (!viewer) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this member',
      })
    }

    const result = await getScopedMember(memberId, viewer)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        error: result.error,
      })
    }

    res.json({
      success: true,
      data: result.data,
    })
  } catch (error) {
    console.error('Error fetching member:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})
```

and replace the `GET /:memberId/groups` handler (`:1608-1637`) with

```ts
router.get('/:memberId/groups', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params
    const { includeInactive } = req.query
    const viewer = viewerOf(req, memberId)
    if (!viewer) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this member',
      })
    }

    const result = await getScopedMemberGroups(memberId, viewer, includeInactive === 'true')

    if (result.notFound) {
      return res.status(404).json({
        success: false,
        error: result.error,
      })
    }

    if (!result.success) {
      return res.status(500).json({
        success: false,
        error: result.error,
      })
    }

    res.json({
      success: true,
      data: result.data,
      count: result.data?.length || 0,
    })
  } catch (error) {
    console.error('Error fetching member groups:', error)
    res.status(500).json({
      success: false,
      error: 'Internal server error',
    })
  }
})
```

In both routes' `@openapi` blocks add a `404` response line if absent: `description: Member not found, or outside the caller's D7 scope (owners/admins see every member; other leaders only members of groups they created)`.

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/member-scope.test.ts src/routes/__tests__/members-scope.request.test.ts` → PASS (20 tests); `cd server && npx tsc --noEmit && npm run test:run` → PASS (the existing `members.test.ts` 401 cases for `/:memberId` and `/:memberId/groups` are unchanged — the middleware still runs first). vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server`.

- [ ] **Step 7: Commit** — `feat(ui2-members-browse): scope member reads to the caller's groups (D7, D8, D16)`

### Task 6: `GET /api/members/:id/engagement` (D11, D14, D16, D17)
App: server
Phase: 2
Recipe: /api

How D17 reuses the Home sessionizer: `sessionize` (`server/src/services/home-sessions.ts:19-52`) groups moments by their `memberId` field and applies home-dashboard-data's session rule (moments < 30 min apart form one session; duration = last − first, floored at 60 s). A `Session` carries no lesson link (`home-sessions.ts:12`), so this task does NOT reuse `loadSessions`; it loads only the member's moments tied to each enrollment — `client_events` with that `enrollmentId`, `member_lesson_progress.completedAt` and `member_video_progress.startedAt`/`lastWatchedAt` whose `lessonSchedule.enrollmentId` matches — and hands them to `sessionize` keyed by ENROLLMENT id in the `memberId` slot, so two enrollments' interleaved moments never merge into one session (D17: no double counting). Σ session seconds ÷ 3600, rounded, is `hours`.

**Files:**
- Create: `server/src/services/member-engagement.ts`
- Modify: `server/src/routes/members.ts` — imports (`'../services/member-engagement.js'`, `'../services/analytics.service.js'`), and a new `GET /:memberId/engagement` route + `@openapi` block inserted directly after the `GET /:memberId/groups` handler (Task 5 rewrote it; it ends just before the `/api/members/{memberId}/link-google` `@openapi` block)
- Test: `server/src/services/__tests__/member-engagement.test.ts`
- Test: `server/src/routes/__tests__/members-engagement.request.test.ts`

**Interfaces:**
- Consumes: `sessionize(moments: Moment[], gapMs?, floorSeconds?): Session[]` with `type Moment = { memberId: string; at: Date }` (`server/src/services/home-sessions.ts:11,19`); `localDateOf(instant: Date, tz: string): string` and `storedDate(d: Date): string` (`server/src/services/home-dashboard.ts:68,117`); `assertValidTimezone(tz: string): void` and `AnalyticsQueryError` (`server/src/services/analytics.service.ts:440`, `:369` — throws `AnalyticsQueryError(400, 'Invalid timezone: <tz>')`); `visibleMemberOrgIds(viewer: MemberViewer, memberId: string): Promise<string[]>` and `type MemberViewer` (Task 2); `viewerOf(req, memberId): MemberViewer | null` (Task 5, module-private in `routes/members.ts`); `requireMemberOrOrgOwner` (unchanged).
- Produces:
  - `export interface EngagementProgram { enrollmentId: string; programId: string; title: string; coverImageUrl: string | null; completedCount: number; totalCount: number; hours: number; percent: number }`
  - `export interface MemberEngagement { programs: EngagementProgram[] }`
  - `export type EnrollmentMoment = { enrollmentId: string; at: Date }`
  - `export function enrollmentSeconds(moments: EnrollmentMoment[]): Map<string, number>`
  - `export function summarizeEnrollment(schedules: { id: string; date: string }[], completedIds: ReadonlySet<string>, seconds: number, today: string): { completedCount: number; totalCount: number; hours: number; percent: number }`
  - `export async function getMemberEngagement(memberId: string, viewer: MemberViewer, tz: string, now?: Date): Promise<MemberEngagement | null>` — `null` = outside the caller's D7 scope.
  - Wire `GET /api/members/:memberId/engagement?tz=` (`tz` default `UTC`) → `200 {"programs":[{"enrollmentId","programId","title","coverImageUrl","completedCount","totalCount","hours","percent"}]}` — one row per enrollment of an ACTIVE group the member is active in, within the caller-visible orgs (D16; a member reading itself: every org), ordered by enrollment `startDate` desc then id asc; `title` ← `StudyProgram.name`, `coverImageUrl` ← `StudyProgram.coverImageUrl` (string|null); `totalCount` = the enrollment's `LessonSchedule` rows with `removedAt` null (D14); `completedCount` = those with the member's `MemberLessonProgress.completedAt` non-null; `percent` = round(completedCount ÷ lessons whose stored `scheduledDate` is before today in `tz` × 100), capped at 100, 0 when that denominator is 0; `hours` = int per D17. The iPhone renders `Complete` iff `totalCount > 0 && completedCount >= totalCount` (D14). Errors: `400 {"success":false,"error":"Invalid timezone: <tz>"}` · 401/403 (middleware) · `404 {"success":false,"error":"Member not found"}` · 500.

- [ ] **Step 1: Write the failing service test** — create `server/src/services/__tests__/member-engagement.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  enrollment: { findMany: vi.fn() },
  memberLessonProgress: { findMany: vi.fn() },
  memberVideoProgress: { findMany: vi.fn() },
  clientEvent: { findMany: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../member-access.js', () => ({ visibleMemberOrgIds: vi.fn() }))

import { visibleMemberOrgIds } from '../member-access.js'
import { enrollmentSeconds, getMemberEngagement, summarizeEnrollment } from '../member-engagement.js'

const at = (iso: string) => new Date(iso)
const CHI = 'America/Chicago'
const NOW = at('2026-10-25T15:00:00Z') // 10:00 CDT → today = 2026-10-25 in Chicago

describe('summarizeEnrollment (D11, D14)', () => {
  const schedules = [
    { id: 's1', date: '2026-10-23' },
    { id: 's2', date: '2026-10-24' },
    { id: 's3', date: '2026-10-25' }, // today: not yet due
    { id: 's4', date: '2026-10-26' },
  ]

  it('counts completions on the listed lessons against the lessons due before today', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1', 's3', 'removed-lesson']), 4260, '2026-10-25')).toEqual({
      completedCount: 2,
      totalCount: 4,
      hours: 1,
      percent: 100,
    })
  })

  it('caps percent at 100 when the member is ahead of the schedule', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1', 's3', 's4']), 0, '2026-10-25').percent).toBe(100)
  })

  it('rounds percent and reads 0 when nothing is due yet', () => {
    expect(summarizeEnrollment(schedules, new Set(['s1']), 0, '2026-10-26').percent).toBe(33) // 1 of 3
    expect(summarizeEnrollment(schedules, new Set(['s1']), 0, '2026-10-01').percent).toBe(0)
    expect(summarizeEnrollment([], new Set(), 0, '2026-10-25')).toEqual({ completedCount: 0, totalCount: 0, hours: 0, percent: 0 })
  })

  it('rounds hours to whole hours (1 h 29 m → 1, 1 h 30 m → 2)', () => {
    expect(summarizeEnrollment([], new Set(), 5340, '2026-10-25').hours).toBe(1)
    expect(summarizeEnrollment([], new Set(), 5400, '2026-10-25').hours).toBe(2)
  })
})

describe('enrollmentSeconds (D17)', () => {
  it('sessionizes each enrollment on its own, so interleaved moments never merge', () => {
    const totals = enrollmentSeconds([
      { enrollmentId: 'e1', at: at('2026-10-23T15:00:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T15:25:00Z') },
      { enrollmentId: 'e2', at: at('2026-10-23T15:05:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T15:50:00Z') },
      { enrollmentId: 'e1', at: at('2026-10-23T16:10:00Z') }, // e1: one 70-min session = 4200 s
      { enrollmentId: 'e2', at: at('2026-10-23T16:50:00Z') }, // e2: 105 min after its last → two 60 s floors
      { enrollmentId: 'e1', at: at('2026-10-24T15:00:00Z') }, // e1: a lone moment = 60 s
    ])
    expect(totals.get('e1')).toBe(4260)
    expect(totals.get('e2')).toBe(120)
  })
})

describe('getMemberEngagement', () => {
  const sched = (id: string, iso: string) => ({ id, scheduledDate: at(iso) })
  beforeEach(() => {
    vi.clearAllMocks()
    vi.mocked(visibleMemberOrgIds).mockResolvedValue(['o1'])
    prismaMock.enrollment.findMany.mockResolvedValue([
      {
        id: 'e1',
        studyProgramId: 'p-john',
        studyProgram: { name: 'Walking Through John', coverImageUrl: 'http://img/john.jpg' },
        lessonSchedules: [
          sched('s1', '2026-10-23T17:00:00Z'),
          sched('s2', '2026-10-24T17:00:00Z'),
          sched('s3', '2026-10-25T17:00:00Z'),
          sched('s4', '2026-10-26T17:00:00Z'),
        ],
      },
      {
        id: 'e2',
        studyProgramId: 'p-faith',
        studyProgram: { name: 'Foundations of Faith', coverImageUrl: null },
        lessonSchedules: [sched('t1', '2026-11-02T17:00:00Z')],
      },
    ])
    prismaMock.memberLessonProgress.findMany.mockResolvedValue([
      { lessonScheduleId: 's1', completedAt: at('2026-10-24T15:00:00Z'), lessonSchedule: { enrollmentId: 'e1' } },
      { lessonScheduleId: 's3', completedAt: at('2026-10-23T16:10:00Z'), lessonSchedule: { enrollmentId: 'e1' } },
      { lessonScheduleId: 's2', completedAt: null, lessonSchedule: { enrollmentId: 'e1' } },
    ])
    prismaMock.memberVideoProgress.findMany.mockResolvedValue([
      { startedAt: at('2026-10-23T15:05:00Z'), lastWatchedAt: at('2026-10-23T16:50:00Z'), lessonSchedule: { enrollmentId: 'e2' } },
    ])
    prismaMock.clientEvent.findMany.mockResolvedValue([
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:00:00Z') },
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:25:00Z') },
      { enrollmentId: 'e1', occurredAt: at('2026-10-23T15:50:00Z') },
    ])
  })

  it('returns one row per enrollment with the D11/D14 keys verbatim', async () => {
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)).toEqual({
      programs: [
        {
          enrollmentId: 'e1',
          programId: 'p-john',
          title: 'Walking Through John',
          coverImageUrl: 'http://img/john.jpg',
          completedCount: 2,
          totalCount: 4,
          hours: 1, // 4200 + 60 s
          percent: 100, // 2 completed ÷ 2 due (s1, s2)
        },
        {
          enrollmentId: 'e2',
          programId: 'p-faith',
          title: 'Foundations of Faith',
          coverImageUrl: null,
          completedCount: 0,
          totalCount: 1,
          hours: 0,
          percent: 0, // nothing due yet
        },
      ],
    })
  })

  it('reads enrollments of active groups the member is active in, inside the visible orgs (D16)', async () => {
    await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)
    expect(prismaMock.enrollment.findMany).toHaveBeenCalledWith({
      where: {
        group: { isActive: true, organizationId: { in: ['o1'] }, members: { some: { memberId: 'm1', isActive: true } } },
      },
      select: {
        id: true,
        studyProgramId: true,
        studyProgram: { select: { name: true, coverImageUrl: true } },
        lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } },
      },
      orderBy: [{ startDate: 'desc' }, { id: 'asc' }],
    })
    const tied = { lessonSchedule: { enrollmentId: { in: ['e1', 'e2'] } } }
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', ...tied },
      select: { lessonScheduleId: true, completedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', ...tied },
      select: { startedAt: true, lastWatchedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    })
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', enrollmentId: { in: ['e1', 'e2'] } },
      select: { enrollmentId: true, occurredAt: true },
    })
  })

  it('is null for a user who sees the member in no org (the route answers 404)', async () => {
    vi.mocked(visibleMemberOrgIds).mockResolvedValue([])
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl2' }, CHI, NOW)).toBeNull()
    expect(prismaMock.enrollment.findMany).not.toHaveBeenCalled()
  })

  it('reads every org for a member reading itself, with no scope lookup', async () => {
    await getMemberEngagement('m1', { kind: 'self' }, 'UTC', NOW)
    expect(visibleMemberOrgIds).not.toHaveBeenCalled()
    expect(prismaMock.enrollment.findMany.mock.calls[0][0].where).toEqual({
      group: { isActive: true, members: { some: { memberId: 'm1', isActive: true } } },
    })
  })

  it('answers no enrollments with an empty list and no progress queries', async () => {
    prismaMock.enrollment.findMany.mockResolvedValue([])
    expect(await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, NOW)).toEqual({ programs: [] })
    expect(prismaMock.memberLessonProgress.findMany).not.toHaveBeenCalled()
  })

  it('takes "today" in the caller’s tz', async () => {
    // 2026-10-26T03:00Z is still 2026-10-25 in Chicago but already 2026-10-26 in UTC.
    const late = at('2026-10-26T03:00:00Z')
    const chicago = await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, CHI, late)
    const utc = await getMemberEngagement('m1', { kind: 'user', userId: 'gl' }, 'UTC', late)
    expect(chicago?.programs[0].percent).toBe(100) // 2 of 2 due
    expect(utc?.programs[0].percent).toBe(67) // 2 of 3 due (s3 now due)
  })
})
```

- [ ] **Step 2: Write the failing request test** — create `server/src/routes/__tests__/members-engagement.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/twilio.js', () => ({ sendVerificationCode: vi.fn(), verifyCode: vi.fn() }))
vi.mock('../../services/storage.js', () => ({ uploadMemberAvatar: vi.fn(), deleteMemberAvatar: vi.fn() }))
vi.mock('../../middleware/auth.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../middleware/auth.js')>()),
  requireMemberOrOrgOwner: (_req: unknown, _res: unknown, next: () => void) => next(),
}))
vi.mock('../../services/member-engagement.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/member-engagement.js')>()),
  getMemberEngagement: vi.fn(),
}))

import { getMemberEngagement } from '../../services/member-engagement.js'
import membersRoutes from '../members.js'

function appAs(who: { userId?: string; memberId?: string }) {
  const app = express()
  app.use((req, _res, next) => {
    Object.assign(req, { session: { memberId: who.memberId } })
    if (who.userId) Object.assign(req, { user: { id: who.userId, isActive: true }, apiKeyId: 'test-key' })
    next()
  })
  app.use('/api/members', membersRoutes)
  return app
}

const BODY = {
  programs: [
    { enrollmentId: 'e1', programId: 'p1', title: 'Walking Through John', coverImageUrl: null, completedCount: 30, totalCount: 30, hours: 9, percent: 100 },
  ],
}

beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(getMemberEngagement).mockResolvedValue(BODY)
})

describe('GET /api/members/:memberId/engagement (SC5)', () => {
  it('returns the D11 body for a scoped user, tz passed through', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement?tz=America%2FChicago')
    expect(res.status).toBe(200)
    expect(res.body).toEqual(BODY)
    expect(getMemberEngagement).toHaveBeenCalledWith('m1', { kind: 'user', userId: 'gl' }, 'America/Chicago', expect.any(Date))
  })

  it('defaults tz to UTC and reads a member session’s own engagement unscoped', async () => {
    await request(appAs({ memberId: 'm1' })).get('/api/members/m1/engagement')
    expect(getMemberEngagement).toHaveBeenCalledWith('m1', { kind: 'self' }, 'UTC', expect.any(Date))
  })

  it('400s a bad timezone before reading anything', async () => {
    const res = await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement?tz=Mars%2FBase')
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'Invalid timezone: Mars/Base' })
    expect(getMemberEngagement).not.toHaveBeenCalled()
  })

  it('404s a member outside the caller’s scope', async () => {
    vi.mocked(getMemberEngagement).mockResolvedValue(null)
    const res = await request(appAs({ userId: 'gl2' })).get('/api/members/m1/engagement')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Member not found' })
  })

  it('403s a caller that is neither the member nor a user, 500s a failure', async () => {
    expect((await request(appAs({ memberId: 'm-other' })).get('/api/members/m1/engagement')).status).toBe(403)
    vi.mocked(getMemberEngagement).mockRejectedValue(new Error('db down'))
    expect((await request(appAs({ userId: 'gl' })).get('/api/members/m1/engagement')).status).toBe(500)
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/member-engagement.test.ts src/routes/__tests__/members-engagement.request.test.ts` → FAIL: `Failed to load url ../member-engagement.js` (both suites — the module does not exist).

- [ ] **Step 4: Write the service** — create `server/src/services/member-engagement.ts`

```ts
/**
 * Per-member program engagement for the UI 2.0 member page
 * (ui2-members-browse D11, D14, D16, D17) — GET /api/members/:id/engagement.
 *
 * Rows: every enrollment of an active group the member is active in, inside
 * the orgs the caller sees the member in (D16). Lessons = the enrollment's
 * LessonSchedule rows with removedAt null. percent is against lessons due
 * before today in tz (stored calendar date, as Home's engagement), so it can
 * read 100 mid-program; the iPhone's `Complete` comes from totalCount (D14).
 * hours (D17): only the member's moments tied to THAT enrollment, sessionized
 * with Home's rule — a Session carries no lesson link, so loadSessions cannot
 * be split by enrollment.
 */
import { prisma } from '../lib/prisma.js'
import { localDateOf, storedDate } from './home-dashboard.js'
import { sessionize } from './home-sessions.js'
import { type MemberViewer, visibleMemberOrgIds } from './member-access.js'

export interface EngagementProgram {
  enrollmentId: string
  programId: string
  title: string
  coverImageUrl: string | null
  completedCount: number
  totalCount: number
  hours: number
  percent: number
}

export interface MemberEngagement {
  programs: EngagementProgram[]
}

export type EnrollmentMoment = { enrollmentId: string; at: Date }

/**
 * D17: Σ session seconds per enrollment. sessionize groups by its `memberId`
 * slot; passing the ENROLLMENT id there keeps each enrollment's moments in
 * their own sessions, so interleaved programs never merge or double-count.
 */
export function enrollmentSeconds(moments: EnrollmentMoment[]): Map<string, number> {
  const totals = new Map<string, number>()
  for (const s of sessionize(moments.map((m) => ({ memberId: m.enrollmentId, at: m.at })))) {
    totals.set(s.memberId, (totals.get(s.memberId) ?? 0) + s.seconds)
  }
  return totals
}

export function summarizeEnrollment(
  schedules: { id: string; date: string }[],
  completedIds: ReadonlySet<string>,
  seconds: number,
  today: string
): { completedCount: number; totalCount: number; hours: number; percent: number } {
  const completedCount = schedules.filter((s) => completedIds.has(s.id)).length
  const due = schedules.filter((s) => s.date < today).length
  return {
    completedCount,
    totalCount: schedules.length,
    hours: Math.round(seconds / 3600),
    percent: due === 0 ? 0 : Math.min(100, Math.round((completedCount / due) * 100)),
  }
}

export async function getMemberEngagement(
  memberId: string,
  viewer: MemberViewer,
  tz: string,
  now: Date = new Date()
): Promise<MemberEngagement | null> {
  const orgIds = viewer.kind === 'user' ? await visibleMemberOrgIds(viewer, memberId) : null
  if (orgIds !== null && orgIds.length === 0) return null

  const enrollments = await prisma.enrollment.findMany({
    where: {
      group: {
        isActive: true,
        ...(orgIds !== null ? { organizationId: { in: orgIds } } : {}),
        members: { some: { memberId, isActive: true } },
      },
    },
    select: {
      id: true,
      studyProgramId: true,
      studyProgram: { select: { name: true, coverImageUrl: true } },
      lessonSchedules: { where: { removedAt: null }, select: { id: true, scheduledDate: true } },
    },
    orderBy: [{ startDate: 'desc' }, { id: 'asc' }],
  })
  if (enrollments.length === 0) return { programs: [] }

  const enrollmentIds = enrollments.map((e) => e.id)
  const tied = { lessonSchedule: { enrollmentId: { in: enrollmentIds } } }
  const [lessons, videos, events] = await Promise.all([
    prisma.memberLessonProgress.findMany({
      where: { memberId, ...tied },
      select: { lessonScheduleId: true, completedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    }),
    prisma.memberVideoProgress.findMany({
      where: { memberId, ...tied },
      select: { startedAt: true, lastWatchedAt: true, lessonSchedule: { select: { enrollmentId: true } } },
    }),
    prisma.clientEvent.findMany({
      where: { memberId, enrollmentId: { in: enrollmentIds } },
      select: { enrollmentId: true, occurredAt: true },
    }),
  ])

  const completed = new Set<string>()
  const moments: EnrollmentMoment[] = []
  for (const l of lessons) {
    if (!l.completedAt) continue
    completed.add(l.lessonScheduleId)
    moments.push({ enrollmentId: l.lessonSchedule.enrollmentId, at: l.completedAt })
  }
  for (const v of videos) {
    moments.push({ enrollmentId: v.lessonSchedule.enrollmentId, at: v.startedAt })
    moments.push({ enrollmentId: v.lessonSchedule.enrollmentId, at: v.lastWatchedAt })
  }
  for (const e of events) if (e.enrollmentId) moments.push({ enrollmentId: e.enrollmentId, at: e.occurredAt })

  const seconds = enrollmentSeconds(moments)
  const today = localDateOf(now, tz)
  return {
    programs: enrollments.map((e) => ({
      enrollmentId: e.id,
      programId: e.studyProgramId,
      title: e.studyProgram.name,
      coverImageUrl: e.studyProgram.coverImageUrl ?? null,
      ...summarizeEnrollment(
        e.lessonSchedules.map((s) => ({ id: s.id, date: storedDate(s.scheduledDate) })),
        completed,
        seconds.get(e.id) ?? 0,
        today
      ),
    })),
  }
}
```

- [ ] **Step 5: Write the route** — in `server/src/routes/members.ts` add the imports

```ts
import { getMemberEngagement } from '../services/member-engagement.js'
import { AnalyticsQueryError, assertValidTimezone } from '../services/analytics.service.js'
```

(`z` is already imported at `:2`), and directly after the `GET /:memberId/groups` handler's closing `})` insert

```ts

const engagementQuery = z.object({ tz: z.string().min(1).max(64).default('UTC') })

/**
 * @openapi
 * /api/members/{memberId}/engagement:
 *   get:
 *     tags: [Members]
 *     summary: The member's programs with progress and hours (UI 2.0 member page, iPhone)
 *     description: One row per enrollment of an active group the member is in, inside the orgs the caller may see the member in (owners/admins every member; other leaders only members of groups they created).
 *     security:
 *       - memberSession: []
 *       - userSession: []
 *     parameters:
 *       - { in: path, name: memberId, required: true, schema: { type: string } }
 *       - { in: query, name: tz, schema: { type: string, example: America/Chicago } }
 *     responses:
 *       200: { description: "{ programs: [{ enrollmentId, programId, title, coverImageUrl, completedCount, totalCount, hours, percent }] }" }
 *       400: { description: Bad timezone }
 *       404: { description: Member not found, or outside the caller's scope }
 */
router.get('/:memberId/engagement', requireMemberOrOrgOwner, async (req, res) => {
  try {
    const { memberId } = req.params
    const parsed = engagementQuery.safeParse(req.query)
    if (!parsed.success) {
      return res.status(400).json({ success: false, error: 'Invalid query' })
    }
    assertValidTimezone(parsed.data.tz)
    const viewer = viewerOf(req, memberId)
    if (!viewer) {
      return res.status(403).json({
        success: false,
        error: 'You do not have permission to access this member',
      })
    }

    const engagement = await getMemberEngagement(memberId, viewer, parsed.data.tz, new Date())
    if (!engagement) {
      return res.status(404).json({ success: false, error: 'Member not found' })
    }
    res.json(engagement)
  } catch (error) {
    if (error instanceof AnalyticsQueryError) {
      return res.status(error.status).json({ success: false, error: error.message })
    }
    console.error('Error fetching member engagement:', error)
    res.status(500).json({ success: false, error: 'Internal server error' })
  }
})
```

- [ ] **Step 6: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/member-engagement.test.ts src/routes/__tests__/members-engagement.request.test.ts` → PASS (16 tests); `cd server && npx tsc --noEmit && npm run test:run` → PASS. vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server`.

- [ ] **Step 7: Commit** — `feat(ui2-members-browse): GET /api/members/:id/engagement (D11, D14, D17)`

### Task 7: `/api/home/days` — `memberId` filter + per-day `lastActivityAt` (D12, D7)
App: server
Phase: 2
Recipe: /api
Build-time risk (F8): A session crossing local midnight is bucketed by `start` (`bucketDays`, `home-dashboard.ts:218`), so its day's `lastActivityAt` can read the next day's time — accept, and test the crossing case.

D7 is checked in this route through `canViewMember` (Task 2), NOT taken from `deriveAnalyticsScope`: that D9 scope gives a role-holding Group Leader the whole org (`getManageableOrgIds`), which is right for Home and wrong for one member's rail. Home's existing call (no `memberId`) must stay byte-for-byte the same call — the tests pin its argument list.

**Files:**
- Modify: `server/src/services/home-sessions.ts:64-84` (`loadSessions` gains `opts: { memberId?: string }`)
- Modify: `server/src/services/home-dashboard.ts:33-37` (`HomeDay.lastActivityAt`), `:218-243` (`bucketDays`, `getHomeDays`)
- Modify: `server/src/routes/home.ts:1-13` (header comment line for `/days`), `:20` (import `canViewMember` on the next line), `:27` (`daysQuery`), `:90-119` (the `/days` `@openapi` block and handler)
- Test: `server/src/services/__tests__/home-dashboard.test.ts:60-95` (update the two `bucketDays` cases, add the midnight case and the `getHomeDays` memberId cases)
- Test: `server/src/services/__tests__/home-sessions.test.ts` (one new case inside `describe('loadSessions (D2 sources)')`, after its last `it`)
- Test: `server/src/routes/__tests__/home.test.ts:20-23` (mock), `:35-38` (import), `:55-62` (`beforeEach`), `:59` (mock body), after `:125` (new describe)

**Interfaces:**
- Consumes: `canViewMember(userId: string, memberId: string, organizationId?: string): Promise<boolean>` (Task 2, `server/src/services/member-access.ts`); `deriveAnalyticsScope`, `isEmptyScope` (unchanged, via `scopeOrRespond`, `home.ts:37`).
- Produces:
  - `export interface HomeDay { day: string; sessionSeconds: number; blocks: number[]; lastActivityAt: string | null }`
  - `export async function loadSessions(scope: AnalyticsScope, window: { from: Date; to: Date }, opts?: { memberId?: string }): Promise<Session[]>`
  - `export function bucketDays(sessions: Session[], from: string, to: string, tz: string): HomeDay[]` — each day's `lastActivityAt` = ISO of the latest `end` among the sessions bucketed into it (by start), `null` on a day with none.
  - `export async function getHomeDays(scope: AnalyticsScope, from: string, to: string, tz: string, opts?: { memberId?: string }): Promise<{ days: HomeDay[] }>`
  - Wire `GET /api/home/days?from=&to=&tz=&organizationId=&memberId=` → `200 {"days":[{"day","sessionSeconds","blocks":[12],"lastActivityAt":"<ISO>"|null}]}` — every day zero-filled; with `memberId`, only that member's sessions; `404 {"success":false,"error":"Not found"}` when `memberId` is outside the caller's D7 scope (in `organizationId` when given, else in every one of the member's orgs) or the D9 scope is empty; `400` for a bad range, tz or an empty `memberId`; `401` without auth. `lastActivityAt` is additive on every response, Home's included (its `HomeDay` decodes with `decodeIfPresent`).

- [ ] **Step 1: Write the failing service tests** — in `server/src/services/__tests__/home-dashboard.test.ts` replace the `describe('bucketDays (D6)', …)` and `describe('getHomeDays', …)` blocks (`:60-95`) with

```ts
describe('bucketDays (D6, SC7)', () => {
  it('zero-fills every day with 12 blocks summing to sessionSeconds and no last activity', () => {
    const days = bucketDays([], '2026-10-30', '2026-11-02', CHI)
    expect(days.map((d) => d.day)).toEqual(['2026-10-30', '2026-10-31', '2026-11-01', '2026-11-02'])
    for (const d of days) {
      expect(d.blocks).toEqual(Array(12).fill(0))
      expect(d.sessionSeconds).toBe(0)
      expect(d.lastActivityAt).toBeNull()
    }
  })

  it('puts sessions in the caller-tz block they start in across the DST boundary, and ends each day at its last session', () => {
    const days = bucketDays(
      [
        session('a', '2026-11-01T05:30:00Z', 600), // 00:30 CDT → Nov 1 block 0
        session('b', '2026-11-01T07:30:00Z', 300), // 01:30 CST (the repeated hour) → block 0
        session('c', '2026-11-01T08:30:00Z', 120), // 02:30 CST → block 1
        session('d', '2026-11-02T05:30:00Z', 60), // 23:30 CST, still Nov 1 → block 11, ends 05:31Z
        session('e', '2026-11-02T06:30:00Z', 90), // 00:30 CST Nov 2 → block 0, ends 06:31:30Z
      ],
      '2026-11-01',
      '2026-11-02',
      CHI
    )
    expect(days[0]).toEqual({
      day: '2026-11-01',
      sessionSeconds: 1080,
      blocks: [900, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 60],
      lastActivityAt: '2026-11-02T05:31:00.000Z',
    })
    expect(days[1]).toEqual({
      day: '2026-11-02',
      sessionSeconds: 90,
      blocks: [90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      lastActivityAt: '2026-11-02T06:31:30.000Z',
    })
  })

  it('F8 (accepted): a session crossing local midnight stays on its start day and reports the next day’s end time', () => {
    // 23:50 CDT Oct 24 → 00:20 CDT Oct 25
    const days = bucketDays([session('a', '2026-10-25T04:50:00Z', 1800)], '2026-10-24', '2026-10-25', CHI)
    expect(days[0]).toEqual({
      day: '2026-10-24',
      sessionSeconds: 1800,
      blocks: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1800],
      lastActivityAt: '2026-10-25T05:20:00.000Z',
    })
    expect(days[1]).toMatchObject({ day: '2026-10-25', sessionSeconds: 0, lastActivityAt: null })
  })
})

describe('getHomeDays', () => {
  it('loads exactly the local days [from 00:00, to + 1 00:00) — Home’s call, two arguments', async () => {
    vi.mocked(loadSessions).mockResolvedValue([session('a', '2026-11-01T05:30:00Z', 600)])
    const result = await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI)
    expect(loadSessions).toHaveBeenCalledWith(SCOPE, { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') })
    expect(vi.mocked(loadSessions).mock.calls[0]).toHaveLength(2)
    expect(result.days).toHaveLength(2)
    expect(result.days[0].sessionSeconds).toBe(600)
    expect(result.days[0].lastActivityAt).toBe('2026-11-01T05:40:00.000Z')
  })

  it('passes memberId through to loadSessions (ui2-members-browse D12)', async () => {
    vi.mocked(loadSessions).mockResolvedValue([])
    await getHomeDays(SCOPE, '2026-11-01', '2026-11-02', CHI, { memberId: 'm1' })
    expect(loadSessions).toHaveBeenCalledWith(
      SCOPE,
      { from: at('2026-11-01T05:00:00Z'), to: at('2026-11-03T06:00:00Z') },
      { memberId: 'm1' }
    )
  })
})
```

and in `server/src/services/__tests__/home-sessions.test.ts`, inside `describe('loadSessions (D2 sources)', …)` after its last `it`, add

```ts
  it('narrows every source to one member when memberId is set (ui2-members-browse D12)', async () => {
    await loadSessions(scope, window, { memberId: 'm1' })
    const padded = { gte: at('2026-10-20T04:00:00Z'), lt: at('2026-10-20T18:00:00Z') }
    const scheduleWhere = { enrollment: { group: { OR: [{ organizationId: { in: ['o1'] } }, { id: { in: [] } }] } } }
    expect(prismaMock.clientEvent.findMany).toHaveBeenCalledWith({
      where: { memberId: 'm1', occurredAt: padded, OR: [{ organizationId: { in: ['o1'] } }, { groupId: { in: [] } }] },
      select: { memberId: true, occurredAt: true },
    })
    expect(prismaMock.memberLessonProgress.findMany).toHaveBeenCalledWith({
      where: { completedAt: padded, lessonSchedule: scheduleWhere, memberId: 'm1' },
      select: { memberId: true, completedAt: true },
    })
    expect(prismaMock.memberVideoProgress.findMany).toHaveBeenCalledWith({
      where: { OR: [{ startedAt: padded }, { lastWatchedAt: padded }], lessonSchedule: scheduleWhere, memberId: 'm1' },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    })
  })
```

- [ ] **Step 2: Write the failing route tests** — in `server/src/routes/__tests__/home.test.ts`: after the `home-following.js` mock (`:30-33`) add

```ts
vi.mock('../../services/member-access.js', () => ({ canViewMember: vi.fn() }))
```

after the imports (`:35-38`) add `import { canViewMember } from '../../services/member-access.js'`; in `beforeEach` (`:55-62`) replace the `getHomeDays` line (`:59`) with

```ts
  vi.mocked(getHomeDays).mockResolvedValue({
    days: [{ day: '2026-10-25', sessionSeconds: 60, blocks: [60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], lastActivityAt: '2026-10-25T14:05:00.000Z' }],
  })
  vi.mocked(canViewMember).mockResolvedValue(true)
```

and after the existing `describe('GET /api/home/days', …)` block (ends `:125`) add

```ts
describe('GET /api/home/days?memberId (ui2-members-browse D12, D7)', () => {
  it('keeps Home’s call exactly as it was when memberId is absent', async () => {
    const res = await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-31&organizationId=org-1')
    expect(res.status).toBe(200)
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-10-01', '2026-10-31', 'UTC')
    expect(vi.mocked(getHomeDays).mock.calls[0]).toHaveLength(4)
    expect(canViewMember).not.toHaveBeenCalled()
  })

  it('filters to a member the caller may see and returns lastActivityAt per day', async () => {
    const res = await request(appAs('u1')).get(
      '/api/home/days?from=2026-09-26&to=2026-10-25&tz=America%2FChicago&organizationId=org-1&memberId=m1'
    )
    expect(res.status).toBe(200)
    expect(canViewMember).toHaveBeenCalledWith('u1', 'm1', 'org-1')
    expect(getHomeDays).toHaveBeenCalledWith(SCOPE, '2026-09-26', '2026-10-25', 'America/Chicago', { memberId: 'm1' })
    expect(res.body.days[0].lastActivityAt).toBe('2026-10-25T14:05:00.000Z')
  })

  it('checks every org of the member when organizationId is absent', async () => {
    await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-02&memberId=m1')
    expect(canViewMember).toHaveBeenCalledWith('u1', 'm1', undefined)
  })

  it('404s a member outside the caller’s D7 scope, before reading sessions', async () => {
    vi.mocked(canViewMember).mockResolvedValue(false)
    const res = await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-02&organizationId=org-1&memberId=m-other')
    expect(res.status).toBe(404)
    expect(res.body).toEqual({ success: false, error: 'Not found' })
    expect(getHomeDays).not.toHaveBeenCalled()
  })

  it('400s an empty memberId (it is declared, never stripped)', async () => {
    expect((await request(appAs('u1')).get('/api/home/days?from=2026-10-01&to=2026-10-02&memberId=')).status).toBe(400)
    expect(getHomeDays).not.toHaveBeenCalled()
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/services/__tests__/home-dashboard.test.ts src/services/__tests__/home-sessions.test.ts src/routes/__tests__/home.test.ts` → FAIL: `expected undefined to be null` / missing `lastActivityAt` in the `bucketDays` cases; `loadSessions` called without `{ memberId: 'm1' }`; the memberId cases fail with `expected "spy" to be called with arguments: [ 'u1', 'm1', 'org-1' ]` (zod strips the undeclared `memberId`, so Home's whole-org days come back) and `expected 200 to be 404` / `expected 200 to be 400`. The no-memberId case passes already — it is the regression guard.

- [ ] **Step 4: Filter `loadSessions` by member** — in `server/src/services/home-sessions.ts` replace `:64-84` (the signature through the `Promise.all`) with

```ts
export async function loadSessions(
  scope: AnalyticsScope,
  window: { from: Date; to: Date },
  opts: { memberId?: string } = {}
): Promise<Session[]> {
  const from = new Date(window.from.getTime() - LOAD_PAD_MS)
  const to = new Date(window.to.getTime() + LOAD_PAD_MS)
  const range = { gte: from, lt: to }
  const inRange = (d: Date) => d >= from && d < to
  const scheduleWhere = { enrollment: { group: scopeGroupWhere(scope) } }
  // ui2-members-browse D12: the member page's day rail reads one member's sessions.
  const member = opts.memberId ? { memberId: opts.memberId } : {}

  const [events, lessons, videos] = await Promise.all([
    prisma.clientEvent.findMany({
      where: { memberId: { not: null }, occurredAt: range, ...clientEventScope(scope), ...member },
      select: { memberId: true, occurredAt: true },
    }),
    prisma.memberLessonProgress.findMany({
      where: { completedAt: range, lessonSchedule: scheduleWhere, ...member },
      select: { memberId: true, completedAt: true },
    }),
    prisma.memberVideoProgress.findMany({
      where: { OR: [{ startedAt: range }, { lastWatchedAt: range }], lessonSchedule: scheduleWhere, ...member },
      select: { memberId: true, startedAt: true, lastWatchedAt: true },
    }),
  ])
```

(the rest of the function is unchanged; without `memberId` the three `where`s are exactly today's).

- [ ] **Step 5: Add `lastActivityAt` and the member option** — in `server/src/services/home-dashboard.ts` change `HomeDay` (`:33-37`) to

```ts
export interface HomeDay {
  day: string
  sessionSeconds: number
  blocks: number[]
  /** ui2-members-browse SC7/D12: ISO end of the day's last session; null on a day with none. */
  lastActivityAt: string | null
}
```

and replace `bucketDays` and `getHomeDays` (`:218-243`) with

```ts
export function bucketDays(sessions: Session[], from: string, to: string, tz: string): HomeDay[] {
  const days: HomeDay[] = []
  const byDay = new Map<string, HomeDay>()
  for (let d = from; d <= to; d = addDays(d, 1)) {
    const day: HomeDay = { day: d, sessionSeconds: 0, blocks: Array(DAY_BLOCKS).fill(0), lastActivityAt: null }
    days.push(day)
    byDay.set(d, day)
  }
  const lastEnd = new Map<string, number>()
  for (const s of sessions) {
    const key = localDateOf(s.start, tz)
    const day = byDay.get(key)
    if (!day) continue
    day.blocks[Math.floor(localHourOf(s.start, tz) / 2)] += s.seconds
    day.sessionSeconds += s.seconds
    // A session belongs to the day it STARTS (F8): one crossing local midnight
    // reports the next day's end time here — accepted (SPEC F8).
    const end = s.end.getTime()
    if (end > (lastEnd.get(key) ?? Number.NEGATIVE_INFINITY)) {
      lastEnd.set(key, end)
      day.lastActivityAt = s.end.toISOString()
    }
  }
  return days
}

export async function getHomeDays(
  scope: AnalyticsScope,
  from: string,
  to: string,
  tz: string,
  opts: { memberId?: string } = {}
): Promise<{ days: HomeDay[] }> {
  const window = { from: zonedMidnight(from, tz), to: zonedMidnight(addDays(to, 1), tz) }
  const sessions = opts.memberId
    ? await loadSessions(scope, window, { memberId: opts.memberId })
    : await loadSessions(scope, window)
  return { days: bucketDays(sessions, from, to, tz) }
}
```

- [ ] **Step 6: Declare `memberId` and check D7 in the route** — in `server/src/routes/home.ts`: in the header comment change the `/days` line to ` *   GET /api/home/days?from=&to=&tz=&organizationId=&memberId=`; after the `home-following.js` import (`:20`) add `import { canViewMember } from '../services/member-access.js'`; change `daysQuery` (`:27`) to

```ts
const daysQuery = z.object({
  from: z.string().max(10),
  to: z.string().max(10),
  tz,
  organizationId,
  // ui2-members-browse D12: declared, or z.object strips it and the rail would read the whole org.
  memberId: z.string().min(1).max(64).optional(),
})
```

and replace the `/days` `@openapi` block and handler (`:90-119`) with

```ts
/**
 * @openapi
 * /api/home/days:
 *   get:
 *     tags: [Home]
 *     summary: Per-day session seconds, 12 two-hour blocks and the last activity time, for the Home day cards and the member page's day rail (iPhone)
 *     parameters:
 *       - { in: query, name: from, required: true, schema: { type: string, example: "2026-09-27" } }
 *       - { in: query, name: to, required: true, schema: { type: string, example: "2026-11-01" } }
 *       - { in: query, name: tz, schema: { type: string } }
 *       - { in: query, name: organizationId, schema: { type: string } }
 *       - { in: query, name: memberId, schema: { type: string }, description: "Only this member's sessions; 404 outside the caller's member scope" }
 *     responses:
 *       200: { description: "{ days: [{ day, sessionSeconds, blocks[12], lastActivityAt (ISO|null) }] } — every day, zero-filled" }
 *       400: { description: Bad dates, more than 62 days, bad timezone or an empty memberId }
 *       404: { description: Empty scope, or memberId outside the caller's member scope }
 */
router.get('/days', requireAuth, async (req, res) => {
  try {
    const parsed = daysQuery.safeParse(req.query)
    if (!parsed.success) return invalid(res, parsed.error)
    const rangeError = validateDayRange(parsed.data.from, parsed.data.to)
    if (rangeError) return res.status(400).json({ success: false, error: rangeError })
    assertValidTimezone(parsed.data.tz)
    const scope = await scopeOrRespond(req, res, parsed.data.organizationId)
    if (!scope) return
    const { from, to, memberId, organizationId: orgId } = parsed.data
    if (!memberId) {
      res.json(await getHomeDays(scope, from, to, parsed.data.tz))
      return
    }
    // D7 is checked here, not taken from the D9 scope (which gives a role-holding Group Leader the whole org).
    const userId = callerOf(req).userId
    if (!userId || !(await canViewMember(userId, memberId, orgId))) {
      res.status(404).json({ success: false, error: 'Not found' })
      return
    }
    res.json(await getHomeDays(scope, from, to, parsed.data.tz, { memberId }))
  } catch (error) {
    failed(res, error, 'days')
  }
})
```

- [ ] **Step 7: Run the tests and watch them pass** — `cd server && npx vitest run src/services/__tests__/home-dashboard.test.ts src/services/__tests__/home-sessions.test.ts src/routes/__tests__/home.test.ts src/routes/__tests__/home-following.request.test.ts` → PASS; `cd server && npx tsc --noEmit && npx tsc --noEmit -p fixtures && npm run test:run` → PASS (the fixtures' Home DB suites, when `FIXTURES_TEST_DATABASE_URL` is set, still pass — they read `sessionSeconds`/`blocks`, which did not move). vitest needs no restart; before any curl or walk against :3010, `docker restart makeready-server`.

- [ ] **Step 8: Commit** — `feat(ui2-members-browse): /api/home/days memberId filter and lastActivityAt (D12)`

### Task 8: Fixtures — every Members section populated, then freeze the contract (D13, T7)
App: server
Phase: 2
Recipe: server/fixtures/README.md — read it in full first (layer rules, fixed IDs, `ctx` helpers, what reset deletes)

Where each fact lives, and why: the layer rule is "a screen layer reads base entities and must not create orgs, users or groups", so the second fixture user (system **Group Leader** role) and the one group it created go in **base.ts**; the D13 fields are base members' own columns, so base too; the avatars go through `images.ts` (the D22 path) because base already calls `seedImages`. The two screen layers only add rows that hang off base entities: `screens/members-home.ts` adds three memberships in the leader's group (so `groupCount` 2 exists and the Group-Leader session sees exactly three members) and re-dates six org joins across the D6 label buckets; `screens/members-profile.ts` links member 7 (Nathan Hughes) to the leader user of the same name, so D8's Role reads "Group leader". The leader group is kept OUT of `ctx.created.groups` and its memberships out of `ctx.created.groupMembers`, so `screens/home-dashboard.ts` (which walks those, and runs first by filename) and its DB tests (`membership_events` = 24, 3 groups) do not move.

Known data limit, recorded rather than worked around: the d2m set's 13 `Use: avatar` images are all of men; the 13 avatar slots take the 8 male members first, so 5 female-named members get a male avatar. The other 11 members fall back to initials.

**Files:**
- Modify: `server/fixtures/ids.ts:42-60` (leader constants + `FIXTURE_USER_IDS` before `FIXTURE_IDS`; two keys added to `FIXTURE_IDS`)
- Modify: `server/fixtures/base.ts:1-7` (header), `:8-19` (imports), `:21-40` (leader constants, D13 helpers after `LAST_NAMES`), `:85-104` (Group Leader role lookup, leader user + its role), `:115` (leader group after `created.groups`), `:119-128` (members `createMany` gains the D13 fields)
- Modify: `server/fixtures/images.ts:1-13` (header), `:21` (import), `:27-29` (avatar constants), `:65-70` (`Selection.avatars`), `:77-103` (`selectImages`), after `:184` (`storeAvatar`), `:260` (avatars at the end of `seedImages`)
- Modify: `server/fixtures/wipe.ts:1-37` (both fixture users)
- Modify: `server/fixtures/counts.ts:6,37,39` (both fixture users)
- Create: `server/fixtures/screens/members-home.ts`
- Create: `server/fixtures/screens/members-profile.ts`
- Modify: `server/fixtures/README.md` (Fixed IDs line, a "What `full` makes non-empty on Members" section, the Group-Leader identity)
- Test: `server/fixtures/__tests__/members.test.ts` (create — always runs)
- Test: `server/fixtures/__tests__/images.test.ts` (add the avatar describe)
- Test: `server/fixtures/__tests__/wipe.test.ts` (both users)
- Test: `server/fixtures/__tests__/home-dashboard.test.ts:105-108` (layer discovery finds the two new layers)
- Test: `server/fixtures/__tests__/base.db.test.ts:63-85` (the `empty` row counts)
- Test: `server/fixtures/__tests__/members.db.test.ts` (create — gated on `FIXTURES_TEST_DATABASE_URL` through `db-harness.ts`, as the existing DB suites)

**Interfaces:**
- Consumes: `Member.address`, `emergencyContactName`, `emergencyContactPhone` (Task 1); `memberAccessScope` (Task 2); `getOrganizationMembers(organizationId, viewerUserId, options?)` (Task 4); `getScopedMember(memberId, viewer)` (Task 5); `getMemberEngagement(memberId, viewer, tz, now?)` (Task 6); `getHomeDays(scope, from, to, tz, opts?)` (Task 7); `fixtureId`, `FIXTURE_*` ids, `FixtureContext` (`ctx.now`, `ctx.today`, `ctx.at`, `ctx.daysAgo`), `openFixturesDb`/`TEST_DB_URL` (`fixtures/__tests__/db-harness.ts`).
- Produces:
  - `ids.ts`: `FIXTURE_LEADER_EMAIL = 'fixtures-leader@makeready.local'`, `FIXTURE_LEADER_USER_ID = fixtureId('user', 2)` (`f1f1f1f1-0001-4000-8000-000000000002`), `FIXTURE_LEADER_GROUP_ID = fixtureId('group', 4)` (`f1f1f1f1-0003-4000-8000-000000000004`), `FIXTURE_USER_IDS: string[]` (both users); `FIXTURE_IDS.leaderUser`, `FIXTURE_IDS.leaderGroup`.
  - `base.ts`: `FIXTURE_LEADER_NAME = 'Nathan Hughes'`, `LEADER_GROUP_NAME = 'Prayer Team'`, `MALE_MEMBER_COUNT = 8`, `memberNominalAge(i: number): number`, `memberProfile(i: number, today: string): { email: string; birthday: Date; gender: 'male' | 'female'; address: string; emergencyContactName: string; emergencyContactPhone: string }`.
  - `images.ts`: `AVATAR_COUNT = 13`, `AVATAR_SIZE = 200`, `AVATAR_MEMBER_INDICES: readonly number[]`, `Selection.avatars: D2mImage[]`.
  - `screens/members-home.ts`: `MULTI_GROUP_MEMBER_INDICES = [0, 8, 16]`, `JOINED_OFFSETS: ReadonlyArray<readonly [memberIndex: number, dayOffset: number]>`, `RECENT_JOIN_LEAD_MS`, `full(ctx)`.
  - `screens/members-profile.ts`: `LEADER_MEMBER_INDEX = 7`, `full(ctx)`.
  - Walk facts (after `fixtures:reset`): the Fixtures owner lists 24 members, the first six joined Today / Yesterday / 4 days ago / 1 week ago / 2 weeks ago / a date; James Carter, Emily Price and Sarah Griffin read `groupCount` 2; `POST /auth/dev-login {"email":"fixtures-leader@makeready.local"}` gives a Group-Leader session that lists exactly those three and gets 404 for any other member; Nathan Hughes's Role reads "Group leader"; under images-on resets 13 members carry a photo.
  - Manifest: `contract: frozen 2026-10-25` (Step 13).

- [ ] **Step 1: Write the failing unit tests** — create `server/fixtures/__tests__/members.test.ts`

```ts
import { describe, expect, it } from 'vitest'
import { FIXTURE_LEADER_NAME, MALE_MEMBER_COUNT, MEMBERS_PER_GROUP, memberNominalAge, memberProfile } from '../base.js'
import { FIXTURE_MEMBER_IDS } from '../ids.js'
import { AVATAR_COUNT, AVATAR_MEMBER_INDICES } from '../images.js'
import { JOINED_OFFSETS, MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'

const indices = Array.from({ length: FIXTURE_MEMBER_IDS.length }, (_, i) => i)
/** Whole years between a birthday and a YYYY-MM-DD day. */
function ageOn(birthday: Date, today: string): number {
  const [y, m, d] = today.split('-').map(Number)
  const notYet = m - 1 < birthday.getUTCMonth() || (m - 1 === birthday.getUTCMonth() && d < birthday.getUTCDate())
  return y - birthday.getUTCFullYear() - (notYet ? 1 : 0)
}

describe('D13 member fields (base.ts)', () => {
  it('gives every member a unique first.last@example.org', () => {
    const emails = indices.map((i) => memberProfile(i, '2026-10-25').email)
    for (const e of emails) expect(e).toMatch(/^[a-z]+\.[a-z]+@example\.org$/)
    expect(new Set(emails).size).toBe(24)
    expect(emails[0]).toBe('james.carter@example.org')
  })

  it.each(['2026-01-01', '2026-10-25', '2026-12-31'])('keeps every age within 19–67 on %s', (today) => {
    for (const i of indices) {
      const age = ageOn(memberProfile(i, today).birthday, today)
      expect(age).toBeGreaterThanOrEqual(19)
      expect(age).toBeLessThanOrEqual(67)
    }
  })

  it('spreads the ages across the range', () => {
    expect(new Set(indices.map(memberNominalAge)).size).toBeGreaterThanOrEqual(20)
  })

  it('fills gender, a two-line city address and an emergency name and phone', () => {
    for (const i of indices) {
      const p = memberProfile(i, '2026-10-25')
      expect(p.gender).toBe(i < MALE_MEMBER_COUNT ? 'male' : 'female')
      expect(p.address).toMatch(/^\d+ [A-Za-z ]+\n[A-Za-z ]+, IL \d{5}$/)
      expect(p.emergencyContactName).toMatch(/^[A-Z][a-z]+ [A-Z][a-z]+$/)
      expect(p.emergencyContactPhone).toMatch(/^\+1555020\d{4}$/)
    }
  })
})

describe('D13 avatars (images.ts)', () => {
  it('names 13 distinct members of the 24; the other 11 fall back to initials', () => {
    expect(AVATAR_COUNT).toBe(13)
    expect(AVATAR_MEMBER_INDICES).toHaveLength(AVATAR_COUNT)
    expect(new Set(AVATAR_MEMBER_INDICES).size).toBe(AVATAR_COUNT)
    for (const i of AVATAR_MEMBER_INDICES) {
      expect(i).toBeGreaterThanOrEqual(0)
      expect(i).toBeLessThan(FIXTURE_MEMBER_IDS.length)
    }
  })
})

describe('members-home layer', () => {
  it('puts one member of each base group in the Prayer Team (groupCount 2)', () => {
    expect(MULTI_GROUP_MEMBER_INDICES.map((i) => Math.floor(i / MEMBERS_PER_GROUP))).toEqual([0, 1, 2])
  })

  it('re-dates joins so every D6 label bucket appears: 0, 1, 2–6, 7–13, 14–29, ≥ 30 days', () => {
    const ages = JOINED_OFFSETS.map(([, offset]) => -offset)
    expect(ages).toContain(0)
    expect(ages).toContain(1)
    expect(ages.some((d) => d >= 2 && d <= 6)).toBe(true)
    expect(ages.some((d) => d >= 7 && d <= 13)).toBe(true)
    expect(ages.some((d) => d >= 14 && d <= 29)).toBe(true)
    expect(ages.some((d) => d >= 30 && d < 51)).toBe(true) // still newer than every base join (−62 … −51)
    const members = JOINED_OFFSETS.map(([i]) => i)
    expect(new Set(members).size).toBe(members.length)
    for (const i of members) expect(MULTI_GROUP_MEMBER_INDICES).not.toContain(i)
    expect([...ages].sort((a, b) => a - b)).toEqual(ages) // listed newest first
  })
})

describe('members-profile layer', () => {
  it('links the Group-Leader user to the member of the same name (D8 Role)', () => {
    expect(memberProfile(LEADER_MEMBER_INDEX, '2026-10-25').email).toBe(
      `${FIXTURE_LEADER_NAME.toLowerCase().replace(' ', '.')}@example.org`
    )
  })
})
```

in `server/fixtures/__tests__/images.test.ts` change the import on `:3` to `import { AVATAR_COUNT, type D2mImage, LIBRARY_SIZE, imageBaseUrl, selectImages } from '../images.js'` and add at the end of the file

```ts
describe('fixture avatars (ui2-members-browse D13)', () => {
  const faces = Array.from({ length: 15 }, (_, i) =>
    img(`face-${String(i).padStart(2, '0')}`, [['Subject', 'person'], ['Use', 'avatar']])
  )
  const s = selectImages([...catalog, ...faces, img('face-retired', [['Use', 'avatar']], true)])

  it('takes the first 13 live `Use: avatar` images by slug', () => {
    expect(s.avatars).toHaveLength(AVATAR_COUNT)
    expect(s.avatars.map((a) => a.slug)).toEqual(['avatar-1', ...faces.slice(0, 12).map((f) => f.slug)])
  })

  it('never takes a cover or library image as an avatar, nor an avatar as a cover', () => {
    const covers = new Set([...s.groups, ...Object.values(s.programs), ...s.library].map((i) => i?.slug))
    for (const a of s.avatars) expect(covers.has(a.slug)).toBe(false)
  })
})
```

in `server/fixtures/__tests__/wipe.test.ts` change the import on `:2` to `import { FIXTURE_LEADER_EMAIL, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_EMAIL, FIXTURE_USER_ID } from '../ids.js'` and `:3` to `import { type WipeClient, fixtureUserExists, wipeFixtures } from '../wipe.js'`, replace the last expected call (`{ model: 'user', args: { where: { id: FIXTURE_USER_ID } } }`) with

```ts
      { model: 'user', args: { where: { id: { in: [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID] } } } },
```

and add after that `it`, inside the describe:

```ts
  it('seed refuses when either fixture user exists, by id or by email', async () => {
    let args: unknown
    const fake = {
      user: {
        findFirst: async (a: unknown) => {
          args = a
          return null
        },
      },
    } as unknown as Parameters<typeof fixtureUserExists>[0]
    expect(await fixtureUserExists(fake)).toBe(false)
    expect(args).toEqual({
      where: {
        OR: [
          { id: { in: [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID] } },
          { email: { in: [FIXTURE_USER_EMAIL, FIXTURE_LEADER_EMAIL] } },
        ],
      },
      select: { id: true },
    })
  })
```

and in `server/fixtures/__tests__/home-dashboard.test.ts:105-108` change the discovery case to

```ts
  it('finds base plus the home-dashboard and members layers, which offer full only', async () => {
    const layers = await loadLayers(FIXTURES_DIR)
    expect(layers.screens.map((s) => s.name)).toEqual(['home-dashboard', 'members-home', 'members-profile'])
    expect(availableScenarios(layers.screens)).toEqual(['full', 'empty'])
  })
```

- [ ] **Step 2: Run them and watch them fail** — `cd server && npx vitest run fixtures/__tests__/members.test.ts fixtures/__tests__/images.test.ts fixtures/__tests__/wipe.test.ts fixtures/__tests__/home-dashboard.test.ts` → FAIL: `Failed to load url ../screens/members-home.js` (members suite); `s.avatars` is `undefined` (images suite); `FIXTURE_LEADER_USER_ID` is `undefined` in the wipe expectation; the discovery case finds only `['home-dashboard']`.

- [ ] **Step 3: Write the failing DB test** — create `server/fixtures/__tests__/members.db.test.ts`

```ts
/**
 * ui2-members-browse D13/T7 against a throwaway database: the Members list and
 * the member page read live, non-empty data for the Fixtures owner, and the
 * Group-Leader fixture user sees only its group's members. Gated on
 * FIXTURES_TEST_DATABASE_URL (db-harness.ts); absent, it prints the skip line.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { addDays, localDate } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_ID } from '../ids.js'
import { JOINED_OFFSETS, MULTI_GROUP_MEMBER_INDICES } from '../screens/members-home.js'
import { LEADER_MEMBER_INDEX } from '../screens/members-profile.js'
import { type FixturesDb, TEST_DB_URL, openFixturesDb } from './db-harness.js'

const TZ = 'America/Chicago'
const owner = { kind: 'user' as const, userId: FIXTURE_USER_ID }
const leader = { kind: 'user' as const, userId: FIXTURE_LEADER_USER_ID }
const idOf = (i: number) => FIXTURE_MEMBER_IDS[i]

describe.skipIf(!TEST_DB_URL)('members layers against the test database (ui2-members-browse D13, T7)', () => {
  let db: FixturesDb

  beforeAll(async () => {
    db = await openFixturesDb()
    await db.run('reset', 'full')
  }, 180_000)

  afterAll(async () => {
    if (db) await db.close()
  })

  it('fills the D13 fields on all 24 members', async () => {
    const members = await db.prisma.member.findMany({ where: { id: { in: FIXTURE_MEMBER_IDS } } })
    expect(members).toHaveLength(24)
    for (const m of members) {
      expect(m.email).toMatch(/^[a-z]+\.[a-z]+@example\.org$/)
      expect(m.birthday).not.toBeNull()
      expect(['male', 'female']).toContain(m.gender)
      expect(m.address).toContain('\n')
      expect(m.emergencyContactName).toBeTruthy()
      expect(m.emergencyContactPhone).toMatch(/^\+1555020\d{4}$/)
    }
  })

  it('makes the Group-Leader user a system Group Leader of the org with exactly one group', async () => {
    const role = await db.prisma.userRole.findFirstOrThrow({ where: { userId: FIXTURE_LEADER_USER_ID }, include: { role: true } })
    expect(role).toMatchObject({ organizationId: FIXTURE_ORG_ID, role: { name: 'Group Leader', isSystem: true, organizationId: null } })
    expect(await db.prisma.group.findMany({ where: { creatorId: FIXTURE_LEADER_USER_ID }, select: { id: true } })).toEqual([
      { id: FIXTURE_LEADER_GROUP_ID },
    ])
    expect(await db.prisma.groupMember.count({ where: { groupId: FIXTURE_LEADER_GROUP_ID, isActive: true } })).toBe(3)
  })

  it('lists 24 for the owner, newest join first, groupCount 2 for the three multi-group members', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_USER_ID)
    expect(list.viewerScope).toEqual({ all: true, groupIds: [] })
    expect(list.data).toHaveLength(24)
    expect(list.data!.slice(0, JOINED_OFFSETS.length).map((m) => m.id)).toEqual(JOINED_OFFSETS.map(([i]) => idOf(i)))
    const counts = new Map(list.data!.map((m) => [m.id, m.groupCount]))
    for (const i of MULTI_GROUP_MEMBER_INDICES) expect(counts.get(idOf(i))).toBe(2)
    expect([...counts.values()].filter((c) => c === 1)).toHaveLength(21)
  })

  it('lists only the Prayer Team for the Group-Leader user, with its scope (D7, D15)', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_LEADER_USER_ID)
    expect(list.viewerScope).toEqual({ all: false, groupIds: [FIXTURE_LEADER_GROUP_ID] })
    expect(list.data!.map((m) => m.id).sort()).toEqual(MULTI_GROUP_MEMBER_INDICES.map(idOf).sort())
  })

  it('AND-combines search tokens', async () => {
    const { getOrganizationMembers } = await import('../../src/services/organization.js')
    const list = await getOrganizationMembers(FIXTURE_ORG_ID, FIXTURE_USER_ID, { search: 'james carter' })
    expect(list.data!.map((m) => m.id)).toEqual([idOf(0)])
  })

  it('reads Role and Organization (D8) and hides members outside the leader’s groups (D7)', async () => {
    const { getScopedMember } = await import('../../src/services/member.js')
    const nathan = await getScopedMember(idOf(LEADER_MEMBER_INDEX), owner)
    expect(nathan.data?.isGroupLeader).toBe(true)
    expect(nathan.data?.organizations.map((o) => o.organization.name)).toEqual(['MakeReady Fixtures'])
    expect((await getScopedMember(idOf(1), owner)).data?.isGroupLeader).toBe(false)
    expect((await getScopedMember(idOf(0), leader)).success).toBe(true)
    expect(await getScopedMember(idOf(1), leader)).toEqual({ success: false, error: 'Member not found' })
  })

  it('fills Engagement with a Complete row and live hours for a caught-up member (D11, D14, D16)', async () => {
    const { getMemberEngagement } = await import('../../src/services/member-engagement.js')
    const asOwner = await getMemberEngagement(idOf(0), owner, TZ)
    expect(asOwner!.programs.length).toBeGreaterThan(0)
    expect(asOwner!.programs.some((p) => p.totalCount > 0 && p.completedCount >= p.totalCount)).toBe(true)
    expect(asOwner!.programs.some((p) => p.hours > 0)).toBe(true)
    for (const p of asOwner!.programs) {
      expect(Number.isInteger(p.hours)).toBe(true)
      expect(p.percent).toBeGreaterThanOrEqual(0)
      expect(p.percent).toBeLessThanOrEqual(100)
    }
    // D16: a Group Leader who can see the member sees every group's enrollments of that member in the org.
    const asLeader = await getMemberEngagement(idOf(0), leader, TZ)
    expect(asLeader!.programs.map((p) => p.enrollmentId).sort()).toEqual(asOwner!.programs.map((p) => p.enrollmentId).sort())
  })

  it('fills the member’s 30-day rail with sessions and lastActivityAt (D12)', async () => {
    const { getHomeDays } = await import('../../src/services/home-dashboard.js')
    const today = localDate(new Date())
    const scope = { all: false as const, orgIds: [FIXTURE_ORG_ID], groupIds: [] as string[] }
    const { days } = await getHomeDays(scope, addDays(today, -29), today, TZ, { memberId: idOf(0) })
    expect(days).toHaveLength(30)
    expect(days.some((d) => d.sessionSeconds > 0)).toBe(true)
    for (const d of days) expect(d.lastActivityAt === null).toBe(d.sessionSeconds === 0)
  })

  it('leaves Home’s membership events at 24 (members-home adds memberships, not events)', async () => {
    expect(await db.prisma.membershipEvent.count({ where: { memberId: { in: FIXTURE_MEMBER_IDS } } })).toBe(24)
  })
})
```

and in `server/fixtures/__tests__/base.db.test.ts` change the `(e)` expectation (`:65-84`) to `users: 2`, `user_roles: 2`, `groups: 4` (every other count unchanged — `empty` runs base only, so the leader's group has no members yet and `group_members` stays 24).

- [ ] **Step 4: Run the DB tests and watch them fail (when a test DB is available)** — first bring the throwaway DB to the new schema: `cd server/atlas && ../scripts/atlas.sh migrate apply --dir file://migrations --url "$FIXTURES_TEST_DATABASE_URL"` (append `?sslmode=disable` if Atlas asks). Then `cd server && FIXTURES_TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5434/<throwaway_db> npx vitest run fixtures/__tests__/members.db.test.ts fixtures/__tests__/base.db.test.ts` → FAIL: `Failed to load url ../screens/members-home.js`, and `(e)` `expected 1 to be 2`. Without the variable both suites print `fixtures DB tests skipped — set FIXTURES_TEST_DATABASE_URL` — record that and rely on Step 2's red.

- [ ] **Step 5: Add the leader ids** — in `server/fixtures/ids.ts`, after `FIXTURE_ENROLLMENT_IDS` (`:51`) and before `FIXTURE_IDS` (`:53`) insert

```ts
/** ui2-members-browse T7: the Group-Leader fixture user (system Group Leader role) and the one group it created. */
export const FIXTURE_LEADER_EMAIL = 'fixtures-leader@makeready.local'
export const FIXTURE_LEADER_USER_ID = fixtureId('user', 2)
export const FIXTURE_LEADER_GROUP_ID = fixtureId('group', 4)
/** Every fixture user — reset deletes exactly these. */
export const FIXTURE_USER_IDS: string[] = [FIXTURE_USER_ID, FIXTURE_LEADER_USER_ID]
```

and add `leaderUser: FIXTURE_LEADER_USER_ID,` and `leaderGroup: FIXTURE_LEADER_GROUP_ID,` to `FIXTURE_IDS`.

- [ ] **Step 6: Base — the leader, its group and the D13 fields** — in `server/fixtures/base.ts`:

Header (`:1-7`) last sentence becomes: `Every base group's and program's creatorId is the fixture user, so deleting that user cascades the graph (D7); the Group-Leader user (ui2-members-browse T7) and its one group are deleted with it by reset (wipe.ts).`

Add `FIXTURE_LEADER_EMAIL`, `FIXTURE_LEADER_GROUP_ID`, `FIXTURE_LEADER_USER_ID` to the `'./ids.js'` import (`:10-19`).

After `export const FIXTURE_ORG_NAME = 'MakeReady Fixtures'` (`:22`) add

```ts
/** ui2-members-browse T7: the Group-Leader fixture user — the same person as member 7 (members-profile links them, D8). */
export const FIXTURE_LEADER_NAME = 'Nathan Hughes'
export const LEADER_GROUP_NAME = 'Prayer Team'
```

After `LAST_NAMES` (`:36-40`) add

```ts
/** FIRST_NAMES 0–7 are men's names (Tuesday Men's Group), 8–23 women's. */
export const MALE_MEMBER_COUNT = 8
const STREETS = ['Maple Ave', 'Oak St', 'Cedar Ln', 'Elm St', 'Willow Dr', 'Birch Rd', 'Pine St', 'Lakeview Ave'] as const
const CITY_LINES = ['Chicago, IL 60614', 'Evanston, IL 60201', 'Oak Park, IL 60302', 'Naperville, IL 60540'] as const

/** D13: nominal age 20–66; when the birthday has not come yet this year the true age is one less, so 19–66. */
export const memberNominalAge = (i: number): number => 20 + ((i * 17) % 47)

/** ui2-members-browse D13: every fixture member's personal fields, derived from its index and ctx.today. */
export function memberProfile(i: number, today: string) {
  const last = LAST_NAMES[i]
  return {
    email: `${FIRST_NAMES[i]}.${last}@example.org`.toLowerCase(),
    birthday: new Date(Date.UTC(Number(today.slice(0, 4)) - memberNominalAge(i), (i * 5) % 12, 1 + ((i * 11) % 28), 12)),
    gender: (i < MALE_MEMBER_COUNT ? 'male' : 'female') as 'male' | 'female',
    address: `${100 + i * 37} ${STREETS[i % STREETS.length]}\n${CITY_LINES[i % CITY_LINES.length]}`,
    emergencyContactName: `${FIRST_NAMES[(i + 12) % FIRST_NAMES.length]} ${last}`,
    emergencyContactPhone: `+1555020${String(i + 1).padStart(4, '0')}`,
  }
}
```

After the Owner role check (`:86-87`) add

```ts
  const groupLeaderRole = await prisma.role.findFirst({ where: { name: 'Group Leader', isSystem: true, organizationId: null } })
  if (!groupLeaderRole) throw new FixtureError('the system Group Leader role is missing — run `npm run db:seed` first')
```

After the fixture user's `userRole.create` (ends `:104`) add

```ts
  // ui2-members-browse T7: a second leader with the system Group Leader role who created one
  // group, so a Group-Leader session sees only that group's members (D7). Base, not a screen
  // layer: screen layers may not create users or groups.
  await prisma.user.create({
    data: { id: FIXTURE_LEADER_USER_ID, email: FIXTURE_LEADER_EMAIL, name: FIXTURE_LEADER_NAME, createdAt: seededAt },
  })
  await prisma.userRole.create({
    data: {
      id: fixtureId('userRole', 2),
      userId: FIXTURE_LEADER_USER_ID,
      roleId: groupLeaderRole.id,
      organizationId: FIXTURE_ORG_ID,
      assignedAt: seededAt,
      assignedBy: FIXTURE_USER_ID,
    },
  })
```

After `created.groups = …` (`:115`) add

```ts
  // Kept out of created.groups on purpose: home-dashboard walks the three base groups.
  // Its members are added by screens/members-home.ts.
  await prisma.group.create({
    data: {
      id: FIXTURE_LEADER_GROUP_ID,
      name: LEADER_GROUP_NAME,
      creatorId: FIXTURE_LEADER_USER_ID,
      organizationId: FIXTURE_ORG_ID,
      createdAt: seededAt,
    },
  })
```

and in the members `createMany` (`:119-128`) add `...memberProfile(i, ctx.today),` after `lastName: LAST_NAMES[i],`.

- [ ] **Step 7: Avatars through the D22 image path** — in `server/fixtures/images.ts`:

Header (`:1-13`): after the first bullet add this line:

```ts
 * - Avatars (ui2-members-browse D13): the set's `Use: avatar` images, square-cropped to AVATAR_SIZE, become 13 members' profilePicture (not library media).
```


`:21` import gains `FIXTURE_MEMBER_IDS`. After `export const LIBRARY_SIZE = 12` (`:29`) add

```ts
export const AVATAR_COUNT = 13
export const AVATAR_SIZE = 200
/**
 * D13: the members who get an avatar, by base index — the 8 men first, because the d2m set's 13
 * `Use: avatar` faces are all men; the other 11 members fall back to initials.
 */
export const AVATAR_MEMBER_INDICES: readonly number[] = [0, 1, 2, 3, 4, 5, 6, 7, 9, 12, 15, 18, 21]
```

In `Selection` (`:65-70`) add

```ts
  /** D13: up to AVATAR_COUNT live `Use: avatar` images, by slug — member photos, not library media. */
  avatars: D2mImage[]
```

In `selectImages`, replace `return { groups, programs, library }` (`:102`) with

```ts
  const avatars = live.filter((i) => has(i, 'Use', 'avatar') && !used.has(i.slug)).slice(0, AVATAR_COUNT)
  return { groups, programs, library, avatars }
```

After `store` (ends `:184`) add

```ts
/** D13: a square AVATAR_SIZE JPEG (centre crop), from the cache or d2m; the file name, or null. */
async function storeAvatar(image: D2mImage): Promise<string | null> {
  const file = `${image.slug}-${(image.sha256 ?? 'x').slice(0, 8)}-avatar-${AVATAR_SIZE}.jpg`
  const filePath = path.join(IMAGE_DIR, file)
  try {
    if (!existsSync(filePath)) {
      const res = await fetch(image.url, { signal: AbortSignal.timeout(30_000) })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const original = Buffer.from(await res.arrayBuffer())
      await writeFile(
        filePath,
        await sharp(original).resize({ width: AVATAR_SIZE, height: AVATAR_SIZE, fit: 'cover' }).jpeg({ quality: 80 }).toBuffer()
      )
    }
    return file
  } catch (error) {
    console.warn(`fixtures: avatar ${image.slug} skipped (${(error as Error).message})`)
    return null
  }
}
```

and after the final `await prisma.mediaUsage.createMany(…)` (`:260`) add

```ts

  // D13 (ui2-members-browse): avatars are Member.profilePicture only, never library media.
  for (const [n, image] of selection.avatars.entries()) {
    const memberIndex = AVATAR_MEMBER_INDICES[n]
    if (memberIndex === undefined) break
    const file = await storeAvatar(image)
    if (!file) continue
    await prisma.member.update({ where: { id: FIXTURE_MEMBER_IDS[memberIndex] }, data: { profilePicture: urlOf(file) } })
  }
```

- [ ] **Step 8: Reset deletes both users** — in `server/fixtures/wipe.ts`: header step 4 becomes ` *  4. the fixture users (FIXTURE_USER_IDS: the owner — cascading the owned org, and through creatorId its groups, programs, lessons, activities, enrollments, schedules, user_roles and member_organizations — and the Group-Leader user, cascading its user_role).`; the import (`:14`) becomes `import { FIXTURE_LEADER_EMAIL, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_EMAIL, FIXTURE_USER_IDS } from './ids.js'`; `:27` becomes `await prisma.user.deleteMany({ where: { id: { in: FIXTURE_USER_IDS } } })`; and in `fixtureUserExists` the `where` becomes `{ OR: [{ id: { in: FIXTURE_USER_IDS } }, { email: { in: [FIXTURE_USER_EMAIL, FIXTURE_LEADER_EMAIL] } }] }`. (The leader's group is in the fixture org, so step 3 already deletes it.) In `server/fixtures/counts.ts` the import (`:6`) becomes `import { FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, FIXTURE_USER_IDS } from './ids.js'`, `users:` (`:37`) counts `{ where: { id: { in: FIXTURE_USER_IDS } } }` and `user_roles:` (`:39`) counts `{ where: { userId: { in: FIXTURE_USER_IDS } } }`.

- [ ] **Step 9: The two screen layers** — create `server/fixtures/screens/members-home.ts`

```ts
/**
 * members-home layer (ui2-members-browse D6, D7, D15, T7): what the Members list reads.
 *  - groupCount and the Group-Leader view: members 0, 8 and 16 (one per base group) also join
 *    base's Prayer Team, the Group-Leader user's one group → three rows read groupCount 2, and a
 *    Group-Leader session lists exactly those three.
 *  - D6 "Joined" labels: six members' MemberOrganization.joinedAt move to Today, Yesterday,
 *    4 days ago, 1 week ago, 2 weeks ago and 40 days ago (a dated label), so the list leads with
 *    every label form; the other 18 keep base's −62 … −51.
 * Creates no org, user or group, and no membership events (home-dashboard counts base's 24).
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_GROUP_ID, FIXTURE_MEMBER_IDS, FIXTURE_ORG_ID, fixtureId } from '../ids.js'

export const MULTI_GROUP_MEMBER_INDICES: readonly number[] = [0, 8, 16]
/** [member index, day offset from today], newest first. */
export const JOINED_OFFSETS: ReadonlyArray<readonly [memberIndex: number, dayOffset: number]> = [
  [23, 0],
  [22, -1],
  [21, -4],
  [20, -9],
  [19, -16],
  [18, -40],
]
/** Today's join lands this long before ctx.now, so it is never in the future. */
export const RECENT_JOIN_LEAD_MS = 5 * 60_000

export async function full(ctx: FixtureContext): Promise<void> {
  const { prisma } = ctx
  await prisma.groupMember.createMany({
    data: MULTI_GROUP_MEMBER_INDICES.map((memberIndex, n) => ({
      id: fixtureId('groupMember', FIXTURE_MEMBER_IDS.length + 1 + n), // 25 … 27, after base's 1 … 24
      groupId: FIXTURE_LEADER_GROUP_ID,
      memberId: FIXTURE_MEMBER_IDS[memberIndex],
      joinedAt: ctx.at(-45 + n, 10),
    })),
  })
  for (const [memberIndex, offset] of JOINED_OFFSETS) {
    const joinedAt = offset === 0 ? new Date(ctx.now.getTime() - RECENT_JOIN_LEAD_MS) : ctx.at(offset, 10)
    await prisma.memberOrganization.update({
      where: { memberId_organizationId: { memberId: FIXTURE_MEMBER_IDS[memberIndex], organizationId: FIXTURE_ORG_ID } },
      data: { joinedAt },
    })
  }
}
```

and create `server/fixtures/screens/members-profile.ts`

```ts
/**
 * members-profile layer (ui2-members-browse D8, T7): what the member page reads beyond base.
 * Base fills the D13 fields, the groups (members-home adds the second membership) and, with
 * home-dashboard, the activity rail and program progress. This layer links member 7 (Nathan
 * Hughes) to the Group-Leader user of the same name, so his Role reads "Group leader" (D8 —
 * the linked user created a group in the org). Creates no org, user or group.
 */
import type { FixtureContext } from '../context.js'
import { FIXTURE_LEADER_USER_ID, FIXTURE_MEMBER_IDS } from '../ids.js'

export const LEADER_MEMBER_INDEX = 7

export async function full(ctx: FixtureContext): Promise<void> {
  await ctx.prisma.member.update({
    where: { id: FIXTURE_MEMBER_IDS[LEADER_MEMBER_INDEX] },
    data: { userId: FIXTURE_LEADER_USER_ID, userLinkedAt: ctx.daysAgo(30) },
  })
}
```

- [ ] **Step 10: Note it in the README** — three edits to `server/fixtures/README.md`. (1) In the opening paragraph, after the sentence that names **Fixture Leader**, add:

```markdown
A second user, **Nathan Hughes** (`fixtures-leader@makeready.local`), holds the system Group Leader
role and created one group, **Prayer Team**.
```

(2) At the end of the **Fixed IDs** paragraph, add:

```markdown
The Group-Leader user is `user` n 2 and its group `group` n 4; the members-home memberships are
`groupMember` n 25–27. Reset deletes both users (`FIXTURE_USER_IDS`).
```

(3) Directly before the `## Layers` heading (after the Home section and its "Six months of history" paragraph), add:

```markdown
### What `full` makes non-empty on Members

`base.ts` + `screens/members-home.ts` + `screens/members-profile.ts` (ui2-members-browse D13, T7):
every member has an email (`first.last@example.org`), a birthday (ages 19–67), a gender, a
two-line city address and an emergency contact name and phone; 13 of 24 have a d2m avatar photo
when images are on (the set's avatars are all men, so 5 women carry one), the rest show initials.
The list leads with joins of today, yesterday, 4 days, 1 and 2 weeks and 40 days ago; James
Carter, Emily Price and Sarah Griffin are in two groups (their base group + Prayer Team). Nathan
Hughes (member 7) is linked to the Group-Leader user, so his Role reads "Group leader".

Group-Leader session for the walk (the iPhone's Local identity offers only Fixtures):
`curl -s -X POST http://localhost:3010/auth/dev-login -H 'Content-Type: application/json' -d '{"email":"fixtures-leader@makeready.local"}'`
— it lists exactly the three Prayer Team members and gets 404 for anyone else.
```

- [ ] **Step 11: Run the tests and watch them pass** — `cd server && npx vitest run fixtures/__tests__/members.test.ts fixtures/__tests__/images.test.ts fixtures/__tests__/wipe.test.ts fixtures/__tests__/home-dashboard.test.ts fixtures/__tests__/runner.test.ts` → PASS; `cd server && npx tsc --noEmit -p fixtures && npx tsc --noEmit` → PASS; with the test DB `cd server && FIXTURES_TEST_DATABASE_URL=… npx vitest run fixtures/__tests__/` → PASS (members.db, base.db with the new `(e)` counts, and home-dashboard.db / home-sessions.db / scheduled-lessons.db unchanged). Then `cd server && npm run test:run` → PASS. On the local DB: `docker restart makeready-server` (it must load Tasks 1–7's `server/src` and the regenerated Prisma client), then `docker exec makeready-server npm run fixtures:reset` → exit 0 with the row-count table showing `users 2`, `user_roles 2`, `groups 4` — skipped when the build runs with `--no-dev-env`; the walk lane resets fixtures instead.

- [ ] **Step 12: Commit** — `feat(ui2-members-browse): fixtures fill the Members screens (D13)`

- [ ] **Step 13: Freeze the contract (AFTER the Step 12 commit — the server phase is verified)** — run exactly:

```bash
node /Users/lukekeith/.claude-home/plugins/cache/claude-builder/builder/4.14.8/scripts/advance.mjs docs/features/ui2-members-browse --set "contract=frozen 2026-10-25" --commit "chore(ui2-members-browse): contract frozen at the server phase close"
```

### Task 9: Member payload models — tolerant Codable, every date a String
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — models only; the `AppState` stores that hold them are Task 10's
Finding (F7): Prisma writes `.SSSZ` dates and the app decoder (`JSONDecoder.apiDecoder`, `StudyModels.swift:1074`) is `.iso8601` — SPEC T9 rules that `joinedAt`, `birthday` and `lastActivityAt` decode as `String` and are parsed in the mappers (Tasks 15–16) with the fractional-then-plain fallback (`HomeDashboardMapper.swift:111-121`). Never type them `Date`, and do not reuse `MemberProfile` (`GroupModels.swift:196`, holds `Date`s).

**Files:**
- Create: `iphone/MakeReady/State/Models/MemberModels.swift`
- Modify: `iphone/MakeReady/State/Models/DashboardModels.swift:109-122` (`HomeDay` + its `init(from:)` — gains `lastActivityAt`)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` — the project uses explicit file references (no synchronized folders): a new app source joins target `MakeReady` through the `xcodeproj` gem and `ruby scripts/capture-targets.rb` then mirrors it into `MakeReadyCapture`; a new test file joins `MakeReadyCaptureTests` only. Exact commands in Steps 1 and 3.
- Test: Create `iphone/MakeReadyCaptureTests/MemberModelsTests.swift`

**Interfaces:**
- Consumes: `JSONDecoder.apiDecoder` (`StudyModels.swift:1074`); `OrganizationData` (`MediaModels.swift:253`, unchanged — `id`, `name`, `ownerId?`, `createdAt?`, `updatedAt?`); the existing `HomeDay(day:sessionSeconds:blocks:)` memberwise init (used by `HomeDashboardMapperTests`, must keep compiling).
- Produces (all `Codable, Equatable`; every stored property defaulted so the memberwise init takes any subset, in declaration order; every type has a hand-written tolerant `init(from:)` in an extension):
  - `struct ViewerScope { var all: Bool = false; var groupIds: [String] = [] }` — D15
  - `struct OrgMemberListItem: Identifiable { var id = ""; var firstName: String?; var lastName: String?; var profilePicture: String?; var googlePicture: String?; var joinedAt = ""; var groupCount = 0 }`
  - `struct OrgMembersResponse { var success = false; var data: [OrgMemberListItem] = []; var count = 0; var viewerScope: ViewerScope? }` — `GET /api/organizations/:id/members`; `viewerScope == nil` means a server without D15
  - `struct OrgMemberDirectory { var search = ""; var groupId: String?; var leaderId: String?; var members: [OrgMemberListItem] = []; var viewerScope: ViewerScope? }` (`Equatable` only — the in-memory store value, Task 10)
  - `struct MemberOrganizationRef { var id = ""; var name = "" }`, `struct MemberDetailOrganization { var organizationId = ""; var joinedAt = ""; var organization: MemberOrganizationRef? }`
  - `struct MemberDetail: Identifiable { var id = ""; var phoneNumber = ""; var phoneVerified = false; var firstName: String?; var lastName: String?; var email: String?; var googleEmail: String?; var gender: String?; var birthday: String?; var profilePicture: String?; var googlePicture: String?; var userId: String?; var address: String?; var emergencyContactName: String?; var emergencyContactPhone: String?; var isGroupLeader = false; var organizations: [MemberDetailOrganization] = [] }`
  - `struct MemberDetailResponse { var success = false; var data: MemberDetail?; var error: String? }` — `GET /api/members/:id`
  - `struct MemberGroupCreator { var id = ""; var name: String? }`, `struct MemberGroupItem { var id = ""; var name = ""; var coverImageUrl: String?; var organizationId = ""; var memberCount = 0; var joinedAt = ""; var creator: MemberGroupCreator? }`, `struct MemberGroupsResponse { var success = false; var data: [MemberGroupItem] = []; var count = 0 }` — `GET /api/members/:id/groups`
  - `struct MemberEngagementProgram { var enrollmentId = ""; var programId = ""; var title = ""; var coverImageUrl: String?; var completedCount = 0; var totalCount = 0; var hours = 0; var percent = 0 }`, `struct MemberEngagement { var programs: [MemberEngagementProgram] = [] }` — `GET /api/members/:id/engagement` (top-level `programs`, as `/api/home/*`; `hours` is an `Int`, SPEC §Contract)
  - `struct MyOrganizationsResponse { var success = false; var data: [OrganizationData] = [] }` — `GET /api/organizations/my/organizations` (D18)
  - `HomeDay` gains `var lastActivityAt: String? = nil` (SC7; ISO end of the day's last session, nil on a zero day)

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/MemberModelsTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-browse T9 / F7: SPEC §Contract's member payloads decode through the app's API
/// decoder; every date stays the server's String (Prisma `.SSSZ`), every missing key defaults.
final class MemberModelsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.apiDecoder.decode(type, from: Data(json.utf8))
    }

    func testDirectoryDecodesTheListShapeWithViewerScope() throws {
        let json = #"{"success":true,"data":[{"id":"m1","firstName":"Barry","lastName":"Allen","profilePicture":null,"googlePicture":"https://lh3.example/b.jpg","joinedAt":"2026-10-25T14:03:22.123Z","groupCount":2},{"id":"m2","firstName":"Clark","lastName":null,"joinedAt":"2026-07-25T00:00:00Z","groupCount":0}],"count":2,"viewerScope":{"all":false,"groupIds":["g1","g2"]}}"#
        let r = try decode(OrgMembersResponse.self, json)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r.data.map(\.id), ["m1", "m2"])
        XCTAssertEqual(r.data[0].joinedAt, "2026-10-25T14:03:22.123Z")          // .SSSZ kept verbatim
        XCTAssertNil(r.data[0].profilePicture)
        XCTAssertEqual(r.data[0].googlePicture, "https://lh3.example/b.jpg")
        XCTAssertEqual(r.data[0].groupCount, 2)
        XCTAssertNil(r.data[1].lastName)
        XCTAssertEqual(r.viewerScope, ViewerScope(all: false, groupIds: ["g1", "g2"]))
    }

    func testDirectoryWithoutTheNewKeysDefaults() throws {
        let r = try decode(OrgMembersResponse.self, #"{"success":true,"data":[{"id":"m1"}]}"#)
        XCTAssertNil(r.viewerScope)
        XCTAssertEqual(r.count, 0)
        XCTAssertEqual(r.data.first?.joinedAt, "")
        XCTAssertEqual(r.data.first?.groupCount, 0)
        XCTAssertNil(r.data.first?.firstName)
    }

    func testMemberDetailDecodesTheScopedPayload() throws {
        let json = #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890","phoneVerified":true,"smsConsent":true,"firstName":"Tony","lastName":"Stark","email":null,"googleEmail":"tony@gmail.example","gender":"male","birthday":"1974-06-25T00:00:00.000Z","profilePicture":null,"googlePicture":"https://lh3.example/t.jpg","isActive":true,"userId":"u1","address":"10880 Malibu Point\nMalibu, CA 90265","emergencyContactName":"Pepper Potts","emergencyContactPhone":"+11234567891","isGroupLeader":true,"createdAt":"2026-01-02T03:04:05.678Z","organizations":[{"id":"mo1","memberId":"m1","organizationId":"org1","joinedAt":"2026-07-05T14:03:22.123Z","createdAt":"2026-07-05T14:03:22.123Z","organization":{"id":"org1","name":"MakeReady","ownerId":"u9"}}]}}"#
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, json).data)
        XCTAssertEqual(d.id, "m1")
        XCTAssertEqual(d.phoneNumber, "+11234567890")
        XCTAssertTrue(d.phoneVerified)
        XCTAssertEqual(d.firstName, "Tony")
        XCTAssertNil(d.email)
        XCTAssertEqual(d.googleEmail, "tony@gmail.example")
        XCTAssertEqual(d.gender, "male")
        XCTAssertEqual(d.birthday, "1974-06-25T00:00:00.000Z")
        XCTAssertEqual(d.googlePicture, "https://lh3.example/t.jpg")
        XCTAssertEqual(d.address, "10880 Malibu Point\nMalibu, CA 90265")
        XCTAssertEqual(d.emergencyContactName, "Pepper Potts")
        XCTAssertEqual(d.emergencyContactPhone, "+11234567891")
        XCTAssertTrue(d.isGroupLeader)
        XCTAssertEqual(d.organizations, [MemberDetailOrganization(
            organizationId: "org1", joinedAt: "2026-07-05T14:03:22.123Z",
            organization: MemberOrganizationRef(id: "org1", name: "MakeReady"))])
    }

    func testMemberDetailFromAServerWithoutTheNewColumnsDefaults() throws {
        let d = try XCTUnwrap(try decode(MemberDetailResponse.self, #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890"}}"#).data)
        XCTAssertNil(d.address)
        XCTAssertNil(d.emergencyContactName)
        XCTAssertNil(d.emergencyContactPhone)
        XCTAssertFalse(d.isGroupLeader)
        XCTAssertFalse(d.phoneVerified)
        XCTAssertEqual(d.organizations, [])
    }

    func testMemberGroupsDecodeTheGroupPayload() throws {
        let json = #"{"success":true,"data":[{"id":"g1","code":"ABC123","name":"Young professionals","coverImageUrl":"https://cdn.example/g1.jpg","creatorId":"u2","organizationId":"org1","isActive":true,"createdAt":"2025-01-01T00:00:00.000Z","memberCount":9,"joinedAt":"2025-07-03T16:00:00.000Z","creator":{"id":"u2","name":"Luke Keith","email":"luke@example.org","picture":null},"_count":{"members":9}}],"count":1}"#
        let r = try decode(MemberGroupsResponse.self, json)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r.data, [MemberGroupItem(
            id: "g1", name: "Young professionals", coverImageUrl: "https://cdn.example/g1.jpg",
            organizationId: "org1", memberCount: 9, joinedAt: "2025-07-03T16:00:00.000Z",
            creator: MemberGroupCreator(id: "u2", name: "Luke Keith"))])
    }

    func testEngagementDecodesTotalCountAndWholeHours() throws {
        let json = #"{"programs":[{"enrollmentId":"e1","programId":"p1","title":"Daily Inspiration","coverImageUrl":"https://cdn.example/p1.jpg","completedCount":12,"totalCount":30,"hours":15,"percent":68},{"enrollmentId":"e2","programId":"p2","title":"Romans in 30 days","coverImageUrl":null,"completedCount":31,"totalCount":31,"hours":92,"percent":100}]}"#
        let e = try decode(MemberEngagement.self, json)
        XCTAssertEqual(e.programs.count, 2)
        XCTAssertEqual(e.programs[0], MemberEngagementProgram(
            enrollmentId: "e1", programId: "p1", title: "Daily Inspiration",
            coverImageUrl: "https://cdn.example/p1.jpg", completedCount: 12, totalCount: 30, hours: 15, percent: 68))
        XCTAssertNil(e.programs[1].coverImageUrl)
        XCTAssertEqual(e.programs[1].totalCount, 31)
    }

    func testEngagementMissingKeysDefault() throws {
        let e = try decode(MemberEngagement.self, #"{"programs":[{"title":"Romans"}]}"#)
        XCTAssertEqual(e.programs, [MemberEngagementProgram(title: "Romans")])
        XCTAssertEqual(try decode(MemberEngagement.self, "{}").programs, [])
    }

    /// SC7: `lastActivityAt` is additive on a payload Home already decodes.
    func testHomeDayCarriesLastActivityAt() throws {
        let json = #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0],"lastActivityAt":"2026-10-24T13:20:00.000Z"},{"day":"2026-10-25","sessionSeconds":0,"blocks":[0,0,0,0,0,0,0,0,0,0,0,0],"lastActivityAt":null},{"day":"2026-10-26","sessionSeconds":0}]}"#
        let days = try decode(HomeDaysResponse.self, json).days
        XCTAssertEqual(days[0].lastActivityAt, "2026-10-24T13:20:00.000Z")
        XCTAssertNil(days[1].lastActivityAt)
        XCTAssertNil(days[2].lastActivityAt)
        XCTAssertEqual(days[2].blocks, [])
        XCTAssertNil(HomeDay(day: "2026-10-24", sessionSeconds: 60, blocks: [60]).lastActivityAt)   // old init still compiles
    }

    /// D18: the shape `/my/organization` already decodes, as a list.
    func testMyOrganizationsDecodesTheList() throws {
        let json = #"{"success":true,"data":[{"id":"org2","name":"Grace Church","ownerId":"u9","createdAt":"2024-01-15T10:30:00.000Z","updatedAt":"2024-01-15T10:30:00.000Z"},{"id":"org3","name":"Second Org"}]}"#
        let r = try decode(MyOrganizationsResponse.self, json)
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.data.map(\.id), ["org2", "org3"])
        XCTAssertEqual(try decode(MyOrganizationsResponse.self, #"{"success":true}"#).data, [])
    }
}
```

Register the test file (from `iphone/`):

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "MemberModelsTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — from the repo root: `npm run ios:build-check -- --test` → FAIL (the test target does not compile): "cannot find 'OrgMembersResponse' in scope", "value of type 'HomeDay' has no member 'lastActivityAt'".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReady/State/Models/DashboardModels.swift`, replace the `HomeDay` struct and its decoder extension (lines 109-122) with:

```swift
/// One day of `GET /api/home/days` — Σ blocks = sessionSeconds (D6).
struct HomeDay: Codable, Equatable {
    var day: String = ""               // yyyy-MM-dd
    var sessionSeconds: Int = 0
    var blocks: [Int] = []             // 12 two-hour blocks, seconds, index 0 = 12–2 AM
    /// ui2-members-browse SC7/D12: ISO end of the day's last session (nil on a zero day). A
    /// String, never a Date (F7); read only by the member page's rail.
    var lastActivityAt: String? = nil
}

extension HomeDay {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decodeIfPresent(String.self, forKey: .day) ?? ""
        sessionSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionSeconds) ?? 0
        blocks = try c.decodeIfPresent([Int].self, forKey: .blocks) ?? []
        lastActivityAt = try c.decodeIfPresent(String.self, forKey: .lastActivityAt)
    }
}
```

Create `iphone/MakeReady/State/Models/MemberModels.swift`:

```swift
import Foundation

// MARK: - ui2-members-browse §Contract — the iPhone's side of the member payloads
//
// T9 / F7: every date here (`joinedAt`, `birthday`) is the server's ISO 8601 STRING, parsed in
// the mappers (MembersHomeMapper.parseDate) with the fractional-then-plain fallback — Prisma
// writes `.SSSZ`. Every key decodes with a default (`decodeIfPresent`) so a server a step behind
// or ahead never fails a whole page. `MemberProfile` (GroupModels.swift) holds Dates and is not
// reused.

/// D15: the caller's D7 scope, from the server's `memberAccessScope`. `all` = Owner, Admin,
/// Super Admin; otherwise `groupIds` are the groups the caller created.
struct ViewerScope: Codable, Equatable {
    var all: Bool = false
    var groupIds: [String] = []
}

extension ViewerScope {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        all = try c.decodeIfPresent(Bool.self, forKey: .all) ?? false
        groupIds = try c.decodeIfPresent([String].self, forKey: .groupIds) ?? []
    }
}

/// One row of `GET /api/organizations/:organizationId/members` (P12, D6).
struct OrgMemberListItem: Codable, Equatable, Identifiable {
    var id: String = ""
    var firstName: String?
    var lastName: String?
    var profilePicture: String?
    var googlePicture: String?
    var joinedAt: String = ""          // this org's MemberOrganization.joinedAt, ISO (F7)
    var groupCount: Int = 0
}

extension OrgMemberListItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        profilePicture = try c.decodeIfPresent(String.self, forKey: .profilePicture)
        googlePicture = try c.decodeIfPresent(String.self, forKey: .googlePicture)
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        groupCount = try c.decodeIfPresent(Int.self, forKey: .groupCount) ?? 0
    }
}

/// `GET /api/organizations/:organizationId/members` — server-ordered `joinedAt` desc (D6).
struct OrgMembersResponse: Codable, Equatable {
    var success: Bool = false
    var data: [OrgMemberListItem] = []
    var count: Int = 0
    var viewerScope: ViewerScope?      // nil = a server without D15 — the mapper treats it as `all`
}

extension OrgMembersResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([OrgMemberListItem].self, forKey: .data) ?? []
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        viewerScope = try c.decodeIfPresent(ViewerScope.self, forKey: .viewerScope)
    }
}

/// `AppState.orgMembersByOrgId`'s value: the last directory load for an org and the query it
/// answered (in memory only, D21).
struct OrgMemberDirectory: Equatable {
    var search: String = ""
    var groupId: String?
    var leaderId: String?
    var members: [OrgMemberListItem] = []
    var viewerScope: ViewerScope?
}

/// `organizations[].organization` on the member payload (D8: already caller-scoped by the server).
struct MemberOrganizationRef: Codable, Equatable {
    var id: String = ""
    var name: String = ""
}

extension MemberOrganizationRef {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

/// One `MemberOrganization` row on the member payload.
struct MemberDetailOrganization: Codable, Equatable {
    var organizationId: String = ""
    var joinedAt: String = ""          // ISO (F7)
    var organization: MemberOrganizationRef?
}

extension MemberDetailOrganization {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        organizationId = try c.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        organization = try c.decodeIfPresent(MemberOrganizationRef.self, forKey: .organization)
    }
}

/// `GET /api/members/:memberId` — the existing member columns plus SC1–SC3 and SC8.
struct MemberDetail: Codable, Equatable, Identifiable {
    var id: String = ""
    var phoneNumber: String = ""
    var phoneVerified: Bool = false
    var firstName: String?
    var lastName: String?
    var email: String?
    var googleEmail: String?
    var gender: String?                // stored lowercase ("male" / "female")
    var birthday: String?              // ISO, a calendar date at UTC midnight (F7)
    var profilePicture: String?
    var googlePicture: String?
    var userId: String?
    var address: String?               // SC1 — multi-line (P7)
    var emergencyContactName: String?  // SC2 (P6)
    var emergencyContactPhone: String? // SC3 (P6)
    var isGroupLeader: Bool = false    // SC8 (D8)
    var organizations: [MemberDetailOrganization] = []
}

extension MemberDetail {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        phoneNumber = try c.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        phoneVerified = try c.decodeIfPresent(Bool.self, forKey: .phoneVerified) ?? false
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        googleEmail = try c.decodeIfPresent(String.self, forKey: .googleEmail)
        gender = try c.decodeIfPresent(String.self, forKey: .gender)
        birthday = try c.decodeIfPresent(String.self, forKey: .birthday)
        profilePicture = try c.decodeIfPresent(String.self, forKey: .profilePicture)
        googlePicture = try c.decodeIfPresent(String.self, forKey: .googlePicture)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        address = try c.decodeIfPresent(String.self, forKey: .address)
        emergencyContactName = try c.decodeIfPresent(String.self, forKey: .emergencyContactName)
        emergencyContactPhone = try c.decodeIfPresent(String.self, forKey: .emergencyContactPhone)
        isGroupLeader = try c.decodeIfPresent(Bool.self, forKey: .isGroupLeader) ?? false
        organizations = try c.decodeIfPresent([MemberDetailOrganization].self, forKey: .organizations) ?? []
    }
}

struct MemberDetailResponse: Codable, Equatable {
    var success: Bool = false
    var data: MemberDetail?
    var error: String?
}

extension MemberDetailResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent(MemberDetail.self, forKey: .data)
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// `creator` on a member's group — the leader shown as C-043 `Single` ("L. Keith").
struct MemberGroupCreator: Codable, Equatable {
    var id: String = ""
    var name: String?
}

extension MemberGroupCreator {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name)
    }
}

/// One group of `GET /api/members/:memberId/groups` (the group row + `memberCount`, `joinedAt`).
struct MemberGroupItem: Codable, Equatable {
    var id: String = ""
    var name: String = ""
    var coverImageUrl: String?
    var organizationId: String = ""
    var memberCount: Int = 0
    var joinedAt: String = ""          // this membership's GroupMember.joinedAt, ISO (F7)
    var creator: MemberGroupCreator?
}

extension MemberGroupItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        organizationId = try c.decodeIfPresent(String.self, forKey: .organizationId) ?? ""
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        joinedAt = try c.decodeIfPresent(String.self, forKey: .joinedAt) ?? ""
        creator = try c.decodeIfPresent(MemberGroupCreator.self, forKey: .creator)
    }
}

struct MemberGroupsResponse: Codable, Equatable {
    var success: Bool = false
    var data: [MemberGroupItem] = []
    var count: Int = 0
}

extension MemberGroupsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([MemberGroupItem].self, forKey: .data) ?? []
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

/// One enrollment of `GET /api/members/:memberId/engagement` (D11 + D14 `totalCount`; `hours` is
/// whole hours, D17 — the iPhone formats it).
struct MemberEngagementProgram: Codable, Equatable {
    var enrollmentId: String = ""
    var programId: String = ""
    var title: String = ""
    var coverImageUrl: String?
    var completedCount: Int = 0
    var totalCount: Int = 0
    var hours: Int = 0
    var percent: Int = 0
}

extension MemberEngagementProgram {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enrollmentId = try c.decodeIfPresent(String.self, forKey: .enrollmentId) ?? ""
        programId = try c.decodeIfPresent(String.self, forKey: .programId) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        coverImageUrl = try c.decodeIfPresent(String.self, forKey: .coverImageUrl)
        completedCount = try c.decodeIfPresent(Int.self, forKey: .completedCount) ?? 0
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        hours = try c.decodeIfPresent(Int.self, forKey: .hours) ?? 0
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
    }
}

/// `GET /api/members/:memberId/engagement` — `{programs:[…]}`, top level like `/api/home/*`.
struct MemberEngagement: Codable, Equatable {
    var programs: [MemberEngagementProgram] = []
}

extension MemberEngagement {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        programs = try c.decodeIfPresent([MemberEngagementProgram].self, forKey: .programs) ?? []
    }
}

/// D18: `GET /api/organizations/my/organizations` — orgs owned or role-held, owned first.
struct MyOrganizationsResponse: Codable, Equatable {
    var success: Bool = false
    var data: [OrganizationData] = []
}

extension MyOrganizationsResponse {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent([OrganizationData].self, forKey: .data) ?? []
    }
}
```

Register the new source in target `MakeReady`, then mirror it into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReady/State/Models", "MemberModels.swift", "MakeReady"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```
→ the last command exits 0 (in sync).

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the nine new tests plus every existing `HomeDashboardMapperTests` / `DashboardActionsTests` case that builds `HomeDay` — the memberwise init still takes `day:sessionSeconds:blocks:`); then `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — iPhone is `commit: manual`: `git add iphone/MakeReady/State/Models/MemberModels.swift iphone/MakeReady/State/Models/DashboardModels.swift iphone/MakeReadyCaptureTests/MemberModelsTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): member payload models decode the scoped member contract`. Do not run `git commit`.

### Task 10: MemberActions + in-memory member stores + the non-owner org fallback
App: iphone
Phase: 3
Recipe: /ios-error-surface — background loads: a 401 signs out, every other failure `recordError(…, surface: false)` and keeps what the store holds (ui2-shell D28); a cancelled load is not an error

**Files:**
- Create: `iphone/MakeReady/State/Actions/MemberActions.swift`
- Modify: `iphone/MakeReady/State/AppState.swift:139` (new stores directly after `var dashboard = DashboardSnapshot()`), `:809` (cleared in `clearInMemory()` right after `dashboard = DashboardSnapshot()`), `:901-925` (`loadOrganization` + `adoptOrganization` — D18 fallback)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register the two new files — Steps 1 and 3)
- Test: Create `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`; append to `iphone/MakeReadyCaptureTests/AppStateInitialLoadTests.swift`

**Interfaces:**
- Consumes (Task 9): `OrgMembersResponse`, `OrgMemberListItem`, `ViewerScope`, `OrgMemberDirectory`, `MemberDetail`, `MemberDetailResponse`, `MemberGroupItem`, `MemberGroupsResponse`, `MemberEngagement`, `HomeDaysResponse`/`HomeDay` (with `lastActivityAt`), `MyOrganizationsResponse`. Existing: `APIClientProtocol.get(_:responseType:)`, `StubAPIClient` (`stub`, `errorFor`, `beforeReturn`, `delayFor`, `calls`, `callCount`), `AuthStatusPolicy.shouldSignOut(after:)`, `AppState.recordError(_:context:surface:)`, `AppState.errors` (`AppError.context`), `AppState.initialLoad` (`generation`, `isCurrent(_:)`, `run`), `DashboardActions.queryValue(_:)` (static, percent-encodes one query value), `HomeDashboardMapper.days(endingAt:back:ahead:tz:)` (→ `[Day]` with `.key` yyyy-MM-dd), `GroupActions(api:state:).loadGroups(forceRefresh:)`, `ProgramActions(api:state:).loadGroupLeaders()`, `PersistedState(from:)`.
- Produces:
  - `AppState` (in memory only, D21; all cleared in `clearInMemory()`): `var orgMembersByOrgId: [String: OrgMemberDirectory]`, `let memberDetails = EntityStore<MemberDetail>()`, `var memberGroupsById: [String: [MemberGroupItem]]`, `var memberEngagementById: [String: MemberEngagement]`, `var memberDaysById: [String: [HomeDay]]`
  - `AppState.loadOrganization(api: APIClientProtocol = APIClient.shared, generation: Int) async` (now internal; D18 fallback) and `AppState.adoptOrganizations(_ orgs: [OrganizationData], generation: Int)`
  - `struct MemberActions` — `init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil, now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current, onUnauthorized: @escaping @MainActor () async -> Void = {})`; `static let railDays = 30`; `static func path(_ base: String, _ params: [(String, String)]) -> String` (drops empty values, encodes each with `DashboardActions.queryValue`); `@MainActor` async, non-throwing: `loadDirectory(orgId: String, search: String = "", groupId: String? = nil, leaderId: String? = nil)`, `loadMember(_ id: String)`, `loadMemberGroups(_ id: String)`, `loadEngagement(_ id: String)`, `loadMemberDays(_ id: String)`, `loadFilterOptions()`
  - request paths, exact: `/api/organizations/<org>/members[?search=<trimmed>][&groupId=<g>][&leaderId=<l>]`; `/api/members/<id>`; `/api/members/<id>/groups`; `/api/members/<id>/engagement?tz=<tz>`; `/api/home/days?from=<today−29>&to=<today>&tz=<tz>&memberId=<id>[&organizationId=<org>]`

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/MemberActionsTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-browse T10: MemberActions writes the in-memory member stores; a 401 signs out,
/// any other failure is recorded and keeps the store (ui2-shell D28); D21 keeps it off disk.
@MainActor
final class MemberActionsTests: XCTestCase {
    private var state: AppState!
    private var api: StubAPIClient!
    private let tz = TimeZone(identifier: "America/Denver")!
    private let now = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!

    private let directoryJSON = #"{"success":true,"data":[{"id":"m1","firstName":"Barry","lastName":"Allen","profilePicture":null,"googlePicture":null,"joinedAt":"2026-10-25T14:03:22.123Z","groupCount":2},{"id":"m2","firstName":"Clark","lastName":"Kent","joinedAt":"2026-07-25T00:00:00.000Z","groupCount":1}],"count":2,"viewerScope":{"all":false,"groupIds":["g1"]}}"#

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

    private func actions(onUnauthorized: @escaping @MainActor () async -> Void = {}) -> MemberActions {
        MemberActions(api: api, state: state, now: { self.now }, timeZone: tz, onUnauthorized: onUnauthorized)
    }

    func testDirectoryLandsUnderItsOrgWithTheQueryAndScope() async {
        api.stub("GET", "/api/organizations/org1/members", json: directoryJSON)
        await actions().loadDirectory(orgId: "org1")
        let directory = state.orgMembersByOrgId["org1"]
        XCTAssertEqual(directory?.members.map(\.id), ["m1", "m2"])          // server order kept (D6)
        XCTAssertEqual(directory?.search, "")
        XCTAssertNil(directory?.groupId)
        XCTAssertEqual(directory?.viewerScope, ViewerScope(all: false, groupIds: ["g1"]))
    }

    func testDirectoryQuerySendsTrimmedSearchAndBothFilters() async {
        let path = "/api/organizations/org1/members?search=clark%20%20kent&groupId=g1&leaderId=u1"
        api.stub("GET", path, json: directoryJSON)
        await actions().loadDirectory(orgId: "org1", search: "  clark  kent \n", groupId: "g1", leaderId: "u1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.search, "clark  kent")
        XCTAssertEqual(state.orgMembersByOrgId["org1"]?.leaderId, "u1")
    }

    func testPathDropsEmptyValuesAndEncodesTheRest() {
        XCTAssertEqual(MemberActions.path("/a", [("search", ""), ("groupId", "g1")]), "/a?groupId=g1")
        XCTAssertEqual(MemberActions.path("/a", [("tz", "Etc/GMT+5")]), "/a?tz=Etc/GMT%2B5")
        XCTAssertEqual(MemberActions.path("/a", []), "/a")
    }

    func testFailedDirectoryKeepsTheCachedEntryAndRecords() async {
        let cached = OrgMemberDirectory(members: [OrgMemberListItem(id: "m9", firstName: "Cached")])
        state.orgMembersByOrgId["org1"] = cached
        api.errorFor = { _, _ in APIError.serverError("boom") }
        await actions().loadDirectory(orgId: "org1", search: "x")
        XCTAssertEqual(state.orgMembersByOrgId["org1"], cached)
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadDirectory")
    }

    func testUnauthorizedSignsOutAndWritesNothing() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = false
        await actions(onUnauthorized: { signedOut = true }).loadMember("m1")
        XCTAssertTrue(signedOut)
        XCTAssertNil(state.memberDetails["m1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    /// T13: a newer keystroke cancels the older search — the cancelled load is no error.
    func testCancelledLoadWritesAndRecordsNothing() async {
        api.stub("GET", "/api/organizations/org1/members?search=b", json: directoryJSON)
        api.delayFor = { _ in 0.5 }
        let memberActions = actions()
        let task = Task { @MainActor in await memberActions.loadDirectory(orgId: "org1", search: "b") }
        task.cancel()
        await task.value
        XCTAssertNil(state.orgMembersByOrgId["org1"])
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testLoadMemberUpsertsTheDetail() async {
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","phoneNumber":"+11234567890","firstName":"Tony","address":"10880 Malibu Point","isGroupLeader":true}}"#)
        await actions().loadMember("m1")
        XCTAssertEqual(state.memberDetails["m1"]?.firstName, "Tony")
        XCTAssertEqual(state.memberDetails["m1"]?.address, "10880 Malibu Point")
        XCTAssertEqual(state.memberDetails["m1"]?.isGroupLeader, true)
    }

    func testOutOfScopeMemberIsRecordedNotSurfaced() async {
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Cached"))
        api.errorFor = { _, _ in APIError.serverError("Member not found") }       // D7: 404 outside scope
        await actions().loadMember("m1")
        XCTAssertEqual(state.memberDetails["m1"]?.firstName, "Cached")
        XCTAssertEqual(state.errors.last?.context, "MemberActions.loadMember")
        XCTAssertEqual(state.errors.last?.surface, false)
    }

    func testGroupsAndEngagementLandByMember() async {
        api.stub("GET", "/api/members/m1/groups", json: #"{"success":true,"data":[{"id":"g1","name":"Young professionals","joinedAt":"2025-07-03T16:00:00.000Z","creator":{"id":"u2","name":"Luke Keith"}}],"count":1}"#)
        api.stub("GET", "/api/members/m1/engagement?tz=America/Denver", json: #"{"programs":[{"enrollmentId":"e1","title":"Daily Inspiration","completedCount":12,"totalCount":30,"hours":15,"percent":68}]}"#)
        await actions().loadMemberGroups("m1")
        await actions().loadEngagement("m1")
        XCTAssertEqual(state.memberGroupsById["m1"]?.map(\.name), ["Young professionals"])
        XCTAssertEqual(state.memberEngagementById["m1"]?.programs.first?.hours, 15)
    }

    /// D12: the 30 local days ending today, filtered to the member; the org narrows when known.
    func testDaysCoverTheThirtyDaysEndingToday() async {
        state.organizationId = "org1"
        let path = "/api/home/days?from=2026-09-26&to=2026-10-25&tz=America/Denver&memberId=m1&organizationId=org1"
        api.stub("GET", path, json: #"{"days":[{"day":"2026-10-24","sessionSeconds":1530,"blocks":[0,0,0,0,600,0,930,0,0,0,0,0],"lastActivityAt":"2026-10-24T13:20:00.000Z"}]}"#)
        await actions().loadMemberDays("m1")
        XCTAssertEqual(api.callCount("GET", path), 1)
        XCTAssertEqual(state.memberDaysById["m1"]?.first?.lastActivityAt, "2026-10-24T13:20:00.000Z")
    }

    /// A sign-out while the request is in flight retires the old session's result.
    func testSignOutMidLoadDropsTheResult() async {
        api.stub("GET", "/api/members/m1", json: #"{"success":true,"data":{"id":"m1","firstName":"Tony"}}"#)
        api.beforeReturn = { _, _ in self.state.clearAllData() }
        await actions().loadMember("m1")
        XCTAssertNil(state.memberDetails["m1"])
    }

    func testFilterOptionsUnauthorizedSignsOut() async {
        api.errorFor = { _, _ in APIError.unauthorized }
        var signedOut = 0
        await actions(onUnauthorized: { signedOut += 1 }).loadFilterOptions()
        XCTAssertGreaterThanOrEqual(signedOut, 1)
        XCTAssertTrue(state.errors.isEmpty)
    }

    func testClearAllDataEmptiesEveryMemberStore() {
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m1")])
        state.memberDetails.upsert(MemberDetail(id: "m1"))
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1")]
        state.memberEngagementById["m1"] = MemberEngagement(programs: [MemberEngagementProgram(title: "R")])
        state.memberDaysById["m1"] = [HomeDay(day: "2026-10-25")]
        state.clearAllData()
        XCTAssertEqual(state.orgMembersByOrgId, [:])
        XCTAssertNil(state.memberDetails["m1"])
        XCTAssertTrue(state.memberGroupsById.isEmpty)
        XCTAssertTrue(state.memberEngagementById.isEmpty)
        XCTAssertTrue(state.memberDaysById.isEmpty)
    }

    /// D21: addresses and emergency contacts never reach the device's disk cache.
    func testMemberStoresNeverReachTheDiskCache() throws {
        state.memberDetails.upsert(MemberDetail(id: "m1", firstName: "Tony", address: "10880 Malibu Point",
                                                emergencyContactName: "Pepper Potts"))
        state.orgMembersByOrgId["org1"] = OrgMemberDirectory(members: [OrgMemberListItem(id: "m2", firstName: "Barry")])
        state.memberGroupsById["m1"] = [MemberGroupItem(id: "g1", name: "Young professionals")]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = String(decoding: try encoder.encode(PersistedState(from: state)), as: UTF8.self)
        for secret in ["Malibu", "Pepper", "Barry", "Tony", "Young professionals"] {
            XCTAssertFalse(json.contains(secret), secret)
        }
    }
}
```

Append to `final class AppStateInitialLoadTests` in `iphone/MakeReadyCaptureTests/AppStateInitialLoadTests.swift`:

```swift
    // MARK: - ui2-members-browse D18 / T16: a non-owner leader still gets an org

    private let ownedJSON = #"{"success":true,"data":{"id":"org1","name":"MakeReady","ownerId":"u1"}}"#
    private let listJSON = #"{"success":true,"data":[{"id":"org2","name":"Grace Church","ownerId":"u9"},{"id":"org3","name":"Second Org"}]}"#

    func testAnOwnerAdoptsTheOwnedOrgWithoutTheFallback() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organization", json: ownedJSON)
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertEqual(state.organizationId, "org1")
        XCTAssertEqual(api.callCount("GET", "/api/organizations/my/organizations"), 0)
    }

    /// `/my/organization` 404s for an Admin or Group Leader (organization.ts:73) — the first org
    /// they hold a role in is adopted instead.
    func testANonOwnerAdoptsTheFirstRoleHeldOrg() async {
        let api = StubAPIClient()   // no canned /my/organization → it throws, as the 404 does
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertEqual(state.organizationId, "org2")
        XCTAssertEqual(state.userOrganizations.map(\.id), ["org2", "org3"])
    }

    func testTheFallbackIsGenerationGuarded() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organizations", json: listJSON)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        state.clearAllData()                                     // signed out mid-load
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertNil(state.organizationId)
        XCTAssertTrue(state.userOrganizations.isEmpty)
    }

    func testNoOrgAnywhereLeavesTheOrgUnset() async {
        let api = StubAPIClient()
        api.stub("GET", "/api/organizations/my/organizations", json: #"{"success":true,"data":[]}"#)
        var startedIn = -1
        await state.initialLoad.run { generation in startedIn = generation }
        await state.loadOrganization(api: api, generation: startedIn)
        XCTAssertNil(state.organizationId)
        XCTAssertTrue(state.userOrganizations.isEmpty)
    }
```

Register the new test file:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "MemberActionsTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "cannot find 'MemberActions' in scope", "value of type 'AppState' has no member 'orgMembersByOrgId'", "'loadOrganization' is inaccessible due to 'private' protection level".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReady/State/AppState.swift`, insert directly after `var dashboard = DashboardSnapshot()` (line 139):

```swift

    // MARK: ui2-members-browse — member stores (D21: in memory only)
    // Personal data: `PersistedState` never encodes these, they are cache-first within the
    // session only, and `clearInMemory()` empties them on sign-out and environment switch.

    /// T10: the last Members directory load per org — the list, the query it answered, and the
    /// caller's D15 scope.
    var orgMembersByOrgId: [String: OrgMemberDirectory] = [:]

    /// T10: `GET /api/members/:id` payloads. Identity → an EntityStore. Not `members`
    /// (`EntityStore<GroupMember>`) and not `memberDirectory` (an unrelated Group flag).
    let memberDetails = EntityStore<MemberDetail>()

    /// `GET /api/members/:id/groups`, by member id.
    var memberGroupsById: [String: [MemberGroupItem]] = [:]

    /// `GET /api/members/:id/engagement`, by member id.
    var memberEngagementById: [String: MemberEngagement] = [:]

    /// `GET /api/home/days?memberId=` — the member page's D12 rail, by member id.
    var memberDaysById: [String: [HomeDay]] = [:]
```

In `clearInMemory()`, directly after `dashboard = DashboardSnapshot()` (line 809):

```swift
        orgMembersByOrgId = [:]
        memberDetails.clear()
        memberGroupsById = [:]
        memberEngagementById = [:]
        memberDaysById = [:]
```

Replace `loadOrganization(generation:)` (lines 901-911) with:

```swift
    /// The org the shell scopes to. An owner gets the org they own; anyone else — an Admin or a
    /// Group Leader, whom `/my/organization` answers 404 (organization.ts:73) — gets the first
    /// org they hold a role in (ui2-members-browse D18).
    func loadOrganization(api: APIClientProtocol = APIClient.shared, generation: Int) async {
        do {
            let response: OrganizationResponse = try await api.get(
                "/api/organizations/my/organization",
                responseType: OrganizationResponse.self
            )
            if let owned = response.data {
                adoptOrganization(owned, generation: generation)
                return
            }
        } catch {
            // D18: routed deliberately — for a non-owner this 404 is the expected signal to use
            // the fallback below, which records its own failure; a 401 is AuthManager's.
            Log.state.info("no owned organization (\(error.localizedDescription, privacy: .public)) — trying role-held orgs")
        }
        do {
            let response = try await api.get(
                "/api/organizations/my/organizations",
                responseType: MyOrganizationsResponse.self
            )
            adoptOrganizations(response.data, generation: generation)
        } catch {
            recordError(error, context: "AppState.loadOrganization.myOrganizations")
        }
    }
```

Directly after `adoptOrganization(_:generation:)` (after line 925), add:

```swift

    /// D18: the role-held orgs, owned first (server order); the first scopes the shell. Ignored
    /// when its load was retired by a sign-out or environment switch (T16, as above).
    func adoptOrganizations(_ orgs: [OrganizationData], generation: Int) {
        guard initialLoad.isCurrent(generation) else { return }
        organizationId = orgs.first?.id
        userOrganizations = orgs
        if let id = orgs.first?.id { Log.state.info("adopted role-held organization \(id, privacy: .public)") }
    }
```

(`performInitialLoad` keeps calling `loadOrganization(generation: generation)` — the `api` default is `APIClient.shared`.)

Create `iphone/MakeReady/State/Actions/MemberActions.swift`:

```swift
import Foundation

/// ui2-members-browse §iphone State: the Members directory and one member's page. Writes the
/// in-memory member stores on `AppState` (D21). A 401 ends the session (ui2-shell D27); any other
/// failure is recorded console-only — these are background loads — and keeps what the store
/// already holds (D28); a cancelled load (a newer keystroke) is neither written nor recorded.
struct MemberActions {
    /// D12: the member page's day rail — the 30 local days ending today.
    static let railDays = 30

    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private let now: () -> Date
    private let timeZone: TimeZone
    private let onUnauthorized: @MainActor () async -> Void
    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil,
         now: @escaping () -> Date = Date.init, timeZone: TimeZone = .current,
         onUnauthorized: @escaping @MainActor () async -> Void = {}) {
        self.api = api
        self.stateOverride = state
        self.now = now
        self.timeZone = timeZone
        self.onUnauthorized = onUnauthorized
    }

    // MARK: - Directory (members-home)

    /// D6/P12: one directory load — the server orders, filters and D7-scopes it. `search` is
    /// trimmed; empty values are not sent.
    @MainActor
    func loadDirectory(orgId: String, search: String = "", groupId: String? = nil, leaderId: String? = nil) async {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = Self.path("/api/organizations/\(orgId)/members",
                             [("search", query), ("groupId", groupId ?? ""), ("leaderId", leaderId ?? "")])
        guard let response = await fetch("loadDirectory", path, OrgMembersResponse.self) else { return }
        state.orgMembersByOrgId[orgId] = OrgMemberDirectory(
            search: query, groupId: groupId, leaderId: leaderId,
            members: response.data, viewerScope: response.viewerScope
        )
    }

    /// The Groups and Leaders chip options (members-home §5): `/api/groups` → `AppState.groups`,
    /// `/api/group-leaders` → `AppState.groupLeaders`. Each is independent.
    @MainActor
    func loadFilterOptions() async {
        do {
            try await GroupActions(api: api, state: state).loadGroups()
        } catch {
            await handle(error, "loadFilterOptions.groups")
        }
        do {
            try await ProgramActions(api: api, state: state).loadGroupLeaders()
        } catch {
            await handle(error, "loadFilterOptions.leaders")
        }
    }

    // MARK: - One member (members-profile)

    @MainActor
    func loadMember(_ id: String) async {
        guard let response = await fetch("loadMember", "/api/members/\(id)", MemberDetailResponse.self),
              let detail = response.data else { return }
        state.memberDetails.upsert(detail)
    }

    @MainActor
    func loadMemberGroups(_ id: String) async {
        guard let response = await fetch("loadMemberGroups", "/api/members/\(id)/groups", MemberGroupsResponse.self)
        else { return }
        state.memberGroupsById[id] = response.data
    }

    /// D11: `tz` makes "lessons scheduled before today" the caller's today.
    @MainActor
    func loadEngagement(_ id: String) async {
        let path = Self.path("/api/members/\(id)/engagement", [("tz", timeZone.identifier)])
        guard let engagement = await fetch("loadEngagement", path, MemberEngagement.self) else { return }
        state.memberEngagementById[id] = engagement
    }

    /// D12/P14: `/api/home/days` filtered to the member, for today−29 … today in the caller's tz.
    @MainActor
    func loadMemberDays(_ id: String) async {
        let window = HomeDashboardMapper.days(endingAt: now(), back: Self.railDays - 1, ahead: 0, tz: timeZone)
        guard let from = window.first?.key, let to = window.last?.key else { return }
        let path = Self.path("/api/home/days", [
            ("from", from), ("to", to), ("tz", timeZone.identifier),
            ("memberId", id), ("organizationId", state.organizationId ?? "")
        ])
        guard let response = await fetch("loadMemberDays", path, HomeDaysResponse.self) else { return }
        state.memberDaysById[id] = response.days
    }

    // MARK: - Helpers

    /// `APIClient.get` takes the raw path, so each value is encoded here
    /// (`DashboardActions.queryValue` — `+`, `&`, `=`, `#` escaped). Empty values are dropped.
    static func path(_ base: String, _ params: [(String, String)]) -> String {
        let items = params.filter { !$0.1.isEmpty }
        guard !items.isEmpty else { return base }
        return base + "?" + items.map { "\($0.0)=\(DashboardActions.queryValue($0.1))" }.joined(separator: "&")
    }

    /// One GET. Returns nil — and writes nothing — when it failed, was cancelled, or a sign-out
    /// retired the session while it was in flight.
    @MainActor
    private func fetch<T: Decodable>(_ context: String, _ path: String, _ type: T.Type) async -> T? {
        let generation = state.initialLoad.generation
        do {
            let response = try await api.get(path, responseType: type)
            guard !Task.isCancelled, state.initialLoad.isCurrent(generation) else { return nil }
            return response
        } catch {
            await handle(error, context)
            return nil
        }
    }

    @MainActor
    private func handle(_ error: Error, _ context: String) async {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        if AuthStatusPolicy.shouldSignOut(after: error) {
            await onUnauthorized()
            return
        }
        state.recordError(error, context: "MemberActions.\(context)", surface: false)
    }
}
```

Register it in `MakeReady` and mirror it into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReady/State/Actions", "MemberActions.swift", "MakeReady"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (14 new `MemberActionsTests`, 4 new `AppStateInitialLoadTests`, and every existing case — `testTheCurrentLoadAdoptsItsOrganization` / `testALoadInFlightAtSignOutCannotWriteTheOldOrganization` still call `adoptOrganization` unchanged); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (no `print`/`NSLog`, no force unwraps in `MakeReady/`).

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/State/Actions/MemberActions.swift iphone/MakeReady/State/AppState.swift iphone/MakeReadyCaptureTests/MemberActionsTests.swift iphone/MakeReadyCaptureTests/AppStateInitialLoadTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): MemberActions + in-memory member stores; non-owner leaders adopt a role-held org`. Do not run `git commit`.

### Task 11: The shell's push — one NavigationStack per tab, paths in UI2ShellModel
App: iphone
Phase: 3
Recipe: /push-page — read its Step 0 table and the "build detail content from the MOUNTED item" rule; the MECHANISM here is SPEC D1/P1 (a system `NavigationStack`), which supersedes that skill's SlideStack for the UI2 shell
Build-time risk (F2): Hiding the system nav bar disables the interactive pop gesture by default — re-enable it and verify on device. `UI2InteractivePop` below re-arms `interactivePopGestureRecognizer` on the stack's own `UINavigationController` (scoped, not a global `UINavigationController` extension, so the 1.0 screens in the same binary are untouched); its delegate is unit-tested, but the edge swipe itself is only provable on device — it is a named item of the human walk (SPEC §Testing), never claimed from the simulator build.

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift:1-34` (whole file — `UI2Destination`, `tabs`, `paths`, push/pop/setPath, D20 re-tap)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:12-58` (the `UI2Shell` struct)
- Create: `iphone/MakeReady/UI2/Shell/UI2Navigation.swift` (`UI2Navigator` environment value, `UI2InteractivePop`, `UI2PopGestureDelegate`)
- Create: `iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register the two new files — Step 3)
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (append to the class)

**Interfaces:**
- Consumes: existing `UI2ShellModel` (`tab`, `section`, `expansion`, `scrollOffset`, `showsTopNav`, `apply(_:)`), `UI2Route`, `TabBar.Tab` (`.home/.calendar/.search/.profile`, not `CaseIterable` — MakeReadyUI is d2m-owned, so the order is listed here), `HomeSectionLayout(model:onRefresh:content:)`, `EmptyPage`, `ProfileStopgapContainer`, `HomeDashboardContainer`, `PageHeader(style:title:showTitle:showIcons:leadingGlyph:rightButtons:onLeading:)`, `Token.layoutBackground`.
- Produces:
  - `enum UI2Destination: Hashable { case memberDetail(id: String, name: String) }` — `name` is the list-known title the header shows while the page loads
  - `UI2ShellModel`: `static let tabs: [TabBar.Tab]` (`[.home, .calendar, .search, .profile]`), `var paths: [TabBar.Tab: [UI2Destination]]`, `func path(for: TabBar.Tab) -> [UI2Destination]`, `mutating func setPath(_: [UI2Destination], for: TabBar.Tab)`, `mutating func push(_: UI2Destination, on: TabBar.Tab)`, `mutating func pop(on: TabBar.Tab)`; `apply(.tab(t))` with `t == tab` and a non-empty path empties that path and changes nothing else (D20)
  - `struct UI2Navigator { var push: (UI2Destination) -> Void; var pop: () -> Void }` read as `@Environment(\.ui2Navigator)` — UI2Shell injects one per stack, bound to that stack's tab; the default is no-ops (previews, capture)
  - `struct MemberDetailHost: View { let id: String; let name: String }` — the `.memberDetail` destination. In this task it is a real, minimal page: the C-040 header with the list-known name and back = pop. **Task 16 replaces its body with `MemberProfileContainer(memberId: id, name: name)`** — the type, file and init stay, so this task's routing never changes.
  - `final class UI2PopGestureDelegate: NSObject, UIGestureRecognizerDelegate { weak var navigationController: UINavigationController? }` — begins only above the root

- [ ] **Step 1: Write the failing tests** — append to `final class UI2ShellModelTests` in `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift` (add `import UIKit` under `import XCTest` at the top of the file):

```swift
    // MARK: - ui2-members-browse D1/D2/D20: per-tab push paths

    private let tony = UI2Destination.memberDetail(id: "m1", name: "Tony Stark")

    func testEveryTabStartsAtItsRoot() {
        let m = UI2ShellModel()
        XCTAssertEqual(UI2ShellModel.tabs, [.home, .calendar, .search, .profile])
        for tab in UI2ShellModel.tabs { XCTAssertEqual(m.path(for: tab), []) }
    }

    func testPushAndPopActOnTheNamedTabOnly() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.path(for: .profile), [])
        m.pop(on: .profile)                                    // nothing to pop: no-op
        XCTAssertEqual(m.path(for: .home), [tony])
        m.pop(on: .home)
        XCTAssertEqual(m.path(for: .home), [])
        m.pop(on: .home)                                       // popping an empty path is safe
        XCTAssertEqual(m.path(for: .home), [])
    }

    /// D2: leaving a tab and coming back restores its pushed page.
    func testAPushedPageSurvivesATabRoundTrip() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.apply(.tab(.search))
        XCTAssertEqual(m.tab, .search)
        XCTAssertEqual(m.path(for: .search), [])
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [tony])
        XCTAssertEqual(m.section, .members)
    }

    /// D20: re-tapping the selected tab with a page pushed pops to the root and keeps the section.
    func testRetapWithAPushedPagePopsToTheRootOnly() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.push(tony, on: .home)
        m.push(.memberDetail(id: "m2", name: "Clark Kent"), on: .home)
        m.apply(.tab(.home))
        XCTAssertEqual(m.path(for: .home), [])
        XCTAssertEqual(m.section, .members)
        XCTAssertEqual(m.tab, .home)
    }

    /// D20: with an empty path the re-tap keeps today's behaviour (`.home` section).
    func testRetapWithAnEmptyPathResetsTheSectionAsBefore() {
        var m = UI2ShellModel()
        m.apply(.section(.members))
        m.apply(.tab(.home))
        XCTAssertEqual(m.section, .home)
    }

    func testSetPathIsTheStackBinding() {
        var m = UI2ShellModel()
        m.setPath([tony], for: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
        m.setPath([], for: .home)                              // the system edge-swipe pop writes this
        XCTAssertEqual(m.path(for: .home), [])
    }

    func testTopNavStaysARootPageFact() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)
        XCTAssertTrue(m.showsTopNav)                           // D1: no hide logic — the pushed page covers it
    }

    /// F2: the re-armed edge swipe may begin only when there is a page to pop.
    @MainActor
    func testPopGestureBeginsOnlyAboveTheRoot() {
        let nav = UINavigationController(rootViewController: UIViewController())
        let delegate = UI2PopGestureDelegate()
        delegate.navigationController = nav
        let gesture = UIScreenEdgePanGestureRecognizer()
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(gesture))
        nav.pushViewController(UIViewController(), animated: false)
        XCTAssertTrue(delegate.gestureRecognizerShouldBegin(gesture))
        XCTAssertFalse(UI2PopGestureDelegate().gestureRecognizerShouldBegin(gesture))   // no stack known
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "cannot find 'UI2Destination' in scope", "type 'UI2ShellModel' has no member 'tabs'", "cannot find 'UI2PopGestureDelegate' in scope".

- [ ] **Step 3: Write the minimal implementation** — replace the whole of `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift` with:

```swift
import CoreGraphics

/// SPEC D12/D13: the 8 TopNav sections, in C-019's closed order.
enum UI2Section: String, CaseIterable {
    case home = "Home", library = "Library", groups = "Groups", members = "Members"
    case enrollments = "Enrollments", invites = "Invites", programs = "Programs", media = "Media"
}

/// Release 1 routes: only the two navigation levels (SPEC §iphone Phase 3).
enum UI2Route: Equatable {
    case tab(TabBar.Tab)
    case section(UI2Section)
}

/// ui2-members-browse D1: a page pushed onto a tab's NavigationStack. `name` is the list-known
/// title the pushed page's C-040 header shows while it loads (members-profile §3 `loading`).
enum UI2Destination: Hashable {
    case memberDetail(id: String, name: String)
}

/// Ephemeral shell state (SPEC D19) — held as @State by UI2Shell, never persisted.
struct UI2ShellModel {
    /// The four root tabs in TabBar order — one NavigationStack each (ui2-members-browse D1).
    static let tabs: [TabBar.Tab] = [.home, .calendar, .search, .profile]

    var tab: TabBar.Tab = .home
    var section: UI2Section = .home
    var expansion: Double = 0
    var scrollOffset: CGFloat = 0
    /// D1/D2: each tab's push path; a tab missing from the map is at its root.
    var paths: [TabBar.Tab: [UI2Destination]] = [:]

    /// D1: TopNav is part of the Home stack's ROOT page, so a pushed page covers it — no hide logic.
    var showsTopNav: Bool { tab == .home }

    func path(for tab: TabBar.Tab) -> [UI2Destination] { paths[tab] ?? [] }

    /// The stack's `path:` binding writes here — including the system back and edge-swipe pops.
    mutating func setPath(_ path: [UI2Destination], for tab: TabBar.Tab) { paths[tab] = path }

    mutating func push(_ destination: UI2Destination, on tab: TabBar.Tab) {
        paths[tab, default: []].append(destination)
    }

    mutating func pop(on tab: TabBar.Tab) {
        guard var path = paths[tab], !path.isEmpty else { return }
        path.removeLast()
        paths[tab] = path
    }

    mutating func apply(_ route: UI2Route) {
        switch route {
        case .tab(let next):
            // ui2-members-browse D20: re-tapping the selected tab with a page pushed pops that
            // tab to its root (the system pop animates it) and changes nothing else.
            if next == tab, !path(for: next).isEmpty {
                paths[next] = []
                return
            }
            if next == .home && tab == .home { section = .home }
            tab = next
        case .section(let next):
            // SPEC D14(b), revised 2026-10-25: selecting leaves `expansion` as it is.
            section = next
        }
    }
}
```

Create `iphone/MakeReady/UI2/Shell/UI2Navigation.swift`:

```swift
import SwiftUI
import UIKit

/// ui2-members-browse D1: how a container moves its own tab's stack. UI2Shell injects one per
/// NavigationStack, bound to that stack's tab; the default (previews, capture) does nothing.
struct UI2Navigator {
    var push: (UI2Destination) -> Void = { _ in }
    var pop: () -> Void = {}
}

private struct UI2NavigatorKey: EnvironmentKey {
    static let defaultValue = UI2Navigator()
}

extension EnvironmentValues {
    var ui2Navigator: UI2Navigator {
        get { self[UI2NavigatorKey.self] }
        set { self[UI2NavigatorKey.self] = newValue }
    }
}

/// SPEC D1 / F2: `.toolbar(.hidden, for: .navigationBar)` disables the stack's interactive
/// left-edge pop. Placed in a page of the stack, this re-arms THAT stack's recognizer with a
/// delegate that begins only above the root — scoped to the UI2 stacks, so the 1.0 screens'
/// navigation controllers keep their own behaviour. Re-attached on every appearance, because
/// a push may reset the recognizer's delegate.
struct UI2InteractivePop: UIViewControllerRepresentable {
    func makeCoordinator() -> UI2PopGestureDelegate { UI2PopGestureDelegate() }

    func makeUIViewController(context: Context) -> Probe { Probe(popDelegate: context.coordinator) }

    func updateUIViewController(_ uiViewController: Probe, context: Context) {}

    /// An invisible child controller whose only job is to find its UINavigationController.
    final class Probe: UIViewController {
        private let popDelegate: UI2PopGestureDelegate

        init(popDelegate: UI2PopGestureDelegate) {
            self.popDelegate = popDelegate
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { return nil }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attach()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            attach()
        }

        private func attach() {
            guard let navigationController else { return }
            popDelegate.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = popDelegate
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

/// F2: the edge swipe may begin only when the stack has a page above its root.
final class UI2PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}
```

Create `iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift`:

```swift
import SwiftUI

/// ui2-members-browse D1: the `.memberDetail` destination of the shell's stacks — a pushed page
/// (it owns its own scroll; the system bar is hidden, so it draws C-040, back = pop).
/// Task 16 of the plan points this body at `MemberProfileContainer`; until then it is the page's
/// header with the list-known name (members-profile §3 `loading`: "header renders with the name").
struct MemberDetailHost: View {
    let id: String
    let name: String
    @Environment(\.ui2Navigator) private var navigator

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: name,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Token.layoutBackground.ignoresSafeArea())
    }
}
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift`, replace the `UI2Shell` struct (lines 12-58) with:

```swift
struct UI2Shell: View {
    @State private var model = UI2ShellModel()
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 0) {
            // ui2-members-browse D1/D2: one NavigationStack per tab, above the TabBar. Home stays
            // mounted — its TopNav keeps its own scroll position (SPEC D12) and its pushed page
            // survives a tab switch (D2); any other tab mounts while selected (none pushes yet).
            ZStack {
                ForEach(UI2ShellModel.tabs, id: \.self) { tab in
                    if tab == .home || tab == model.tab {
                        stack(for: tab)
                            .opacity(tab == model.tab ? 1 : 0)
                            .allowsHitTesting(tab == model.tab)
                            .accessibilityHidden(tab != model.tab)
                    }
                }
            }
            // C-084 §2 Motion: "the selection switches instantly with no animation"; a re-tap
            // with a page pushed pops it (D20, the system pop).
            TabBar(selected: model.tab, onSelect: { model.apply(.tab($0)) }, onAdd: {})
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Token.layoutBackground.ignoresSafeArea())
        .task {
            PushNotificationManager.shared.clearPendingDeepLink()  // SPEC D17
            await AppState.shared.loadInitialData()                 // SPEC D24
        }
        // SPEC D17: release 1 has no deep-link consumer, so a link set while the shell is
        // mounted (a push tap, a URL, a file open) is dropped rather than left to fire later.
        // Remove when the first 2.0 deep-link consumer lands.
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, link in
            if link != .none { PushNotificationManager.shared.clearPendingDeepLink() }
        }
    }

    /// D1: the system bar is hidden on every page (pushed pages draw C-040); the interactive
    /// edge pop is re-armed on the root and on every pushed page (F2). The motion is the system
    /// push — no custom curve, duration or scrim.
    private func stack(for tab: TabBar.Tab) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            root(for: tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .background(UI2InteractivePop())
                .navigationDestination(for: UI2Destination.self) { destination in
                    page(for: destination)
                        .toolbar(.hidden, for: .navigationBar)
                        .background(UI2InteractivePop())
                }
        }
        .environment(\.ui2Navigator, UI2Navigator(
            push: { model.push($0, on: tab) },
            pop: { model.pop(on: tab) }
        ))
    }

    private func pathBinding(for tab: TabBar.Tab) -> Binding<[UI2Destination]> {
        Binding(get: { model.path(for: tab) }, set: { model.setPath($0, for: tab) })
    }

    /// A tab's root page. Home's root is the TopNav + section page (D1: the stack wraps
    /// `HomeSectionLayout`, so TopNav slides left with the root under a push).
    @ViewBuilder private func root(for tab: TabBar.Tab) -> some View {
        switch tab {
        case .home: HomeSectionLayout(model: $model, onRefresh: refreshAction) { sectionContent }
        case .calendar, .search: EmptyPage()
        case .profile: ProfileStopgapContainer()
        }
    }

    @ViewBuilder private func page(for destination: UI2Destination) -> some View {
        switch destination {
        case let .memberDetail(id, name): MemberDetailHost(id: id, name: name)
        }
    }

    /// home-dashboard-data D24: the pull-to-refresh of the page on screen — Home only (the other
    /// sections are unwired, D10).
    private var refreshAction: (@MainActor () async -> Void)? {
        guard model.tab == .home, model.section == .home else { return nil }
        return { [authManager] in await HomeDashboardContainer.refresh(authManager: authManager) }
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: HomeDashboardContainer()  // SPEC D8/D13
        default: EmptyPage()                  // SPEC D10: Library…Media are unwired
        }
    }
}
```

Keep the file's doc comment above the struct (lines 3-11) and append one line to it: `/// ui2-members-browse D1: each tab is its own NavigationStack; paths live in UI2ShellModel.paths.`

Register the two new sources in `MakeReady` (both under the `MakeReady/UI2` group tree) and mirror them into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReady/UI2/Shell", "UI2Navigation.swift", "MakeReady"],
 ["MakeReady/UI2", "Containers/Members/MemberDetailHost.swift", "MakeReady"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```
(`Containers/Home/*.swift` sit in the `UI2` group with a `Containers/Home/…` path the same way — `project.pbxproj:786`.)

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (eight new `UI2ShellModelTests` cases plus the six existing ones — `testRetapHomeReturnsToHomeSection` still holds with an empty path; `TopNavDragTests` and `HomeDashboardContainerTests` unchanged); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations. The edge-swipe pop (F2), the push feel and "TopNav slides left with the root" are walk items for the human on device — do not launch a simulator to claim them.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Shell/UI2ShellModel.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReady/UI2/Shell/UI2Navigation.swift iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): shell push — a NavigationStack per tab, hidden bar, edge-swipe pop, re-tap pops`. Do not run `git commit`.

### Task 12: C-034 SearchField gains its editable form
App: iphone
Phase: 4
Recipe: /ui2-component-build — the built view's conventions (R-01 controlled props, R-02 ephemeral state, §2 placed geometry); do NOT re-run the capture/diff loop here (Task 13 re-captures the screen that consumes it)
Design ownership (F3): `iphone/MakeReadyUI/` is d2m-owned. This edit is authorized by SPEC D19 (C-034's editable form implementing its existing `onChange` / `focused` / `onClear` contract). After the build, route it to `/ui2-resolve` so the design records the editable form; never write anything under `docs/ui2/`.

**Files:**
- Modify: `iphone/MakeReadyUI/SearchField.swift:6` (header line), `:40-60` (a new `editable` prop + `@FocusState`, init), `:79-86` (derived state → one `appearance` function), `:114-130` (body), `:166-186` (content row: display form kept, editable form added), `:197-205` (clear button keeps focus)
- Test: Create `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register the test file — Step 1)

**Interfaces:**
- Consumes: the existing `SearchField(text:placeholder:focused:onChange:onClear:showsClearWhenEmpty:)` and its `Geometry`, `ClearSearchButton(action:)`, `Token.TypeStyle.input`, `Token.inputValue`, `Token.inputPlaceholder`, `Token.accent`, `.designTextStyle(_:)`, `.ui2Element(_:)`.
- Produces:
  - `SearchField.init(text: String, placeholder: String, focused: Bool, onChange: @escaping (String) -> Void = { _ in }, onClear: @escaping () -> Void = {}, showsClearWhenEmpty: Bool = false, editable: Bool = false)` — every existing call site (ViewRegistry `component.ui2.C-034`, the screens) compiles unchanged and stays display-only
  - `let editable: Bool` — `true` renders a `TextField` drawn as §2's text run; typing calls `onChange`, its focus drives the border/fill/caret (`focused` is ignored), the C-039 clear calls `onClear` and keeps the field focused
  - `enum SearchField.Appearance: Equatable { case `default`, focus, hasValue }` and `static func appearance(text: String, focused: Bool) -> Appearance` — §4's derived state, the single place it is computed

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-browse: the MakeReadyUI edits this feature makes (D19 C-034, T11/T12 screens,
/// D3 C-042). Render parity is the d2m capture's job (F14); these pin the props.
final class UI2MembersComponentTests: XCTestCase {

    // MARK: - Task 12: C-034 SearchField (D19)

    /// C-034 §4: `Default` = empty ∧ ¬focused · `Focus` = empty ∧ focused · `Has value` = ¬empty.
    func testSearchFieldAppearanceIsDerivedFromTextAndFocus() {
        XCTAssertEqual(SearchField.appearance(text: "", focused: false), .default)
        XCTAssertEqual(SearchField.appearance(text: "", focused: true), .focus)
        XCTAssertEqual(SearchField.appearance(text: "ke", focused: false), .hasValue)
        XCTAssertEqual(SearchField.appearance(text: "ke", focused: true), .hasValue)
    }

    func testSearchFieldIsDisplayOnlyUnlessAskedToEdit() {
        XCTAssertFalse(SearchField(text: "", placeholder: "Search members", focused: false).editable)
        XCTAssertTrue(SearchField(text: "", placeholder: "Search members", focused: false, editable: true).editable)
    }
}
```

Register it:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "UI2MembersComponentTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "type 'SearchField' has no member 'appearance'", "extra argument 'editable' in call".

- [ ] **Step 3: Write the minimal implementation** — all in `iphone/MakeReadyUI/SearchField.swift`.

Line 6, replace `//  PREVIEW ONLY: referenced by no screen, route, tab or flag.` with:

```swift
//  Consumed by MembersHomeScreen (editable form, ui2-members-browse D19 — routed to /ui2-resolve, F3).
```

After `let showsClearWhenEmpty: Bool` (line 44) add:

```swift
    /// D19 (ui2-members-browse): the editable form — a `TextField` drawn as §2's text run, its
    /// own focus driving `focused` (the prop is then ignored). `false` keeps the display-only
    /// render every preview and capture case uses, so every §3 state stays reachable by props.
    let editable: Bool

    /// The editable form's focus — ephemeral UI state (R-02), never a prop.
    @FocusState private var inputFocused: Bool
```

Replace the init (lines 46-60) with:

```swift
    init(
        text: String,
        placeholder: String,
        focused: Bool,
        onChange: @escaping (String) -> Void = { _ in },
        onClear: @escaping () -> Void = {},
        showsClearWhenEmpty: Bool = false,
        editable: Bool = false
    ) {
        self.text = text
        self.placeholder = placeholder
        self.focused = focused
        self.onChange = onChange
        self.onClear = onClear
        self.showsClearWhenEmpty = showsClearWhenEmpty
        self.editable = editable
    }
```

Replace the two derived properties (lines 85-86, `isDefault` / `hasValue`) — keep the `// §4: …` comment above them — with:

```swift
    /// §4's derived `state`, computed in one place for both forms.
    enum Appearance: Equatable {
        case `default`, focus, hasValue
    }

    static func appearance(text: String, focused: Bool) -> Appearance {
        if !text.isEmpty { return .hasValue }
        return focused ? .focus : .default
    }

    /// The `focused` §4 derives from: the prop when display-only, the field's own focus when
    /// editable (D19).
    private var isFocused: Bool { editable ? inputFocused : focused }
    private var isDefault: Bool { Self.appearance(text: text, focused: isFocused) == .default }
    private var hasValue: Bool { Self.appearance(text: text, focused: isFocused) == .hasValue }
```

Replace `body` (lines 114-130) with:

```swift
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                        .strokeBorder(border, lineWidth: Geometry.borderWidth)
                )

            searchGlyph
            if editable { editableRow } else { contentRow }
            if hasValue || showsClearWhenEmpty { clearButton }
        }
        .frame(maxWidth: .infinity, minHeight: Geometry.height, maxHeight: Geometry.height)
        .clipped()                                  // §2: "content clipped"
        .contentShape(Rectangle())
        // D19: a tap anywhere on the field (the glyph, the inset) focuses the editable form.
        .simultaneousGesture(TapGesture().onEnded { if editable { inputFocused = true } })
        .ui2Element("SearchField")
    }
```

In `contentRow` (lines 170-186) replace the two `focused` reads with `isFocused` (`if isFocused && !hasValue { caret }` and `if isFocused && hasValue { caret }`) — unchanged behaviour in the display form. Directly after `contentRow` add:

```swift
    /// D19: the editable form of the content row — the same §2 placement (left edge 36,
    /// vertically centred, `type-input`) with a `TextField` in place of the drawn text. The
    /// system caret, tinted `color-accent`, stands in for the drawn 2×24 caret.
    private var editableRow: some View {
        TextField(
            "",
            text: Binding(get: { text }, set: { onChange($0) }),
            prompt: Text(placeholder).foregroundColor(Token.inputPlaceholder)
        )
        .designTextStyle(Token.TypeStyle.input)
        .foregroundColor(Token.inputValue)
        .tint(Token.accent)
        .focused($inputFocused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .ui2Element(hasValue ? "Value" : "Placeholder")
        .padding(.leading, Geometry.contentLeft)
        .padding(.trailing, hasValue || showsClearWhenEmpty ? Self.clearReserve : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ui2Element("Content row")
    }

    // GAP — C-034 §2 draws no typed text long enough to reach C-039; the editable form keeps a
    // value clear of it: C-039's 32 + its trailing inset 7.
    private static let clearReserve: CGFloat = 39
```

Replace `clearButton` (lines 200-205) with:

```swift
    private var clearButton: some View {
        ClearSearchButton(action: {
            onClear()
            if editable { inputFocused = true }     // §4: clears `text`, field **stays focused**
        })
        .padding(.trailing, Geometry.clearTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .ui2Element("Clear button")
    }
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (the two new tests; `ViewRegistryKeysTests` and every screen that builds C-034 still compile — none passes `editable`); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReadyUI/SearchField.swift iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): C-034 SearchField gains its editable form (D19)`. Do not run `git commit`. Note for the report: C-034's editable form is owed to `/ui2-resolve` (F3).

### Task 13: MembersHomeScreen — shell chrome only, scoped Leaders chip, initials, typeable search
App: iphone
Phase: 4
Recipe: /ui2-component-build — screen edits keep the built conventions (R-03 no-op closures, parallel-array State, `.ui2Element` part names); the d2m harness re-captures + diffs the screen after the edit (F14)
Design ownership (F3): `iphone/MakeReadyUI/` is d2m-owned. These edits are authorized by SPEC D4 (no C-019 row), D7/D15 (Leaders chip hidden for a scoped leader), D19 (typeable search) and T11 (initials passed to C-037). After the build, route all of them to `/ui2-resolve`; never write anything under `docs/ui2/`.
Build-time risk (F13): C-038 initials at 164pt (OQ-C-038-2/-3) are undesigned; C-035's applied state is designed but no screen draws it (OQ-C-035-1); the C-036 dim is an overlay inside the shell's scroll, so it may not cover TopNav/TabBar — verify on the walk; carried OQs, no ruling here. Do not "fix" the dim by restructuring the overlay in this task.
Build-time risk (F14): Built-screen render vs frozen Figma snapshot was not diffed at audit — this screen is edited here and re-captured + diffed through the d2m harness after its edit, superseding a pre-build diff. Record the diff result (or that the harness could not be reached) in the task report; never edit the screen further to make a diff pass.

**Files:**
- Modify: `iphone/MakeReadyUI/Screens/Members/MembersHomeScreen.swift:5-10` (header), `:15-19` (type doc), `:29-50` (State), `:58-91` (props + init), `:95-96` (drop `selectedTab`), `:113-141` (body; drop `navRow`), `:148-184` (header), `:210-224` (row), `:274-296` (`populated`)
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift:2498-2510` (`screen.2.0.members-home` State init)
- Modify: `iphone/MakeReadyCaptureTests/CaptureFixture.swift:861` (two additive optional fields after `memberGroupCounts`)
- Test: `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift` (append to the class)

**Interfaces:**
- Consumes (Task 12): `SearchField(text:placeholder:focused:onChange:onClear:editable:)`. Existing: `ListResultRow(subject:title:detail:description:count:trailing:imageURL:initials:onTap:)` (memberwise; `initials` is passed through to C-038), `FilterChip`, `FilterMenuOverlay`, `HomeSectionLayout.navGap` (16, the shell's gap under TopNav).
- Produces:
  - `MembersHomeScreen.State` field order (memberwise init, used by Task 15's mapper): `searchText`, `groupFilterLabel`, `leaderFilterLabel`, `groupOptions`, `leaderOptions`, `showsLeaderFilter: Bool`, `memberNames`, `memberPhotoURLs`, `memberInitials: [String]`, `memberJoinedLabels`, `memberGroupCounts`
  - `MembersHomeScreen.init(state:onSearch:onSelectGroup:onSelectLeader:onOpenMember:)` — `onSelectTab` / `onToggleNav` are gone (D4); `onSelectGroup` / `onSelectLeader` hand back the option LABEL, `onOpenMember` the row index
  - `CaptureComponent.showsLeaderFilter: Bool?`, `.memberInitials: [String]?`

- [ ] **Step 1: Write the failing tests** — append to `final class UI2MembersComponentTests`:

```swift
    // MARK: - Task 13: MembersHomeScreen (D4, D7/D15, T11)

    func testMembersHomeSampleCarriesTheLeaderChipAndInitials() {
        let s = MembersHomeScreen.State.populated
        XCTAssertTrue(s.showsLeaderFilter)
        XCTAssertEqual(s.memberInitials, ["BA", "CK", "IH", "DT", "BW"])
        XCTAssertEqual(s.memberInitials.count, s.memberNames.count)
    }

    /// D4: the screen is built from its State and its four outward actions alone.
    func testMembersHomeTakesNoNavCallbacks() {
        var opened: [Int] = []
        let screen = MembersHomeScreen(state: .populated, onOpenMember: { opened.append($0) })
        screen.onOpenMember(2)
        XCTAssertEqual(opened, [2])
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "value of type 'MembersHomeScreen.State' has no member 'showsLeaderFilter'", "... has no member 'memberInitials'".

- [ ] **Step 3: Write the minimal implementation** — in `iphone/MakeReadyUI/Screens/Members/MembersHomeScreen.swift`:

Replace lines 5-10 (from `//  Built from screen members-home …` through `//  PREVIEW ONLY: …`) with:

```swift
//  Built from screen members-home in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: GET /api/organizations/{organizationId}/members ·
//  GET /api/groups · GET /api/group-leaders
//  Wired by MakeReady/UI2/Containers/Members/MembersHomeContainer.swift (ui2-members-browse).
//  ui2-members-browse edits, routed to /ui2-resolve (F3): no C-019 row of its own (D4 — the
//  shell's TopNav is the only one), `showsLeaderFilter` (D7/D15), `memberInitials` (T11), and an
//  editable C-034 (D19).
```

Replace the type's doc comment (lines 15-19) with:

```swift
/// Members (leader directory) — the Home tab's Members section (§6): the org-wide member
/// directory. A header of C-034 search over the C-035 filter chips, then the member list of
/// C-037 rows separated by hairlines (§2). §2's collapsed C-019 nav row is the shell's TopNav
/// (D4), so this screen starts at the header. Composed only of §4's C-034, C-035, C-036 and
/// C-037; C-038 renders only inside C-037 (§4).
```

In `State`, directly after `var leaderOptions: [String]` (line 41) add:

```swift
        /// D7/D15: the Leaders chip shows only for a caller who sees every member of the org;
        /// a Group Leader's directory is already their own groups.
        var showsLeaderFilter: Bool
```

and directly after `var memberPhotoURLs: [String]` (line 45) add:

```swift
        /// C-038's initials inside C-037 — the fallback when the photo is "" (T11; the row
        /// passes them straight through).
        var memberInitials: [String]
```

Replace the props and init (lines 58-91, from `let state: State` through the init's closing brace) with:

```swift
    let state: State
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    // The screen never decides what an action means. (D4: no tab / nav-toggle callbacks — the
    // shell's TopNav owns them.)
    var onSearch: (String) -> Void = { _ in }       // §3: typing filters the list live (debounced)
    var onSelectGroup: (String) -> Void = { _ in }  // §3: a Groups option applies that filter
    var onSelectLeader: (String) -> Void = { _ in } // §3: a Leaders option applies that filter
    var onOpenMember: (Int) -> Void = { _ in }      // §3: MemberRow tap → members-profile, by row

    // R-31 ephemeral UI: the query as typed (§3 "typing in C-034 filters the list live") and the
    // presented menu (§3 "Tap a chip → FilterMenuOverlay (C-036) opens").
    @SwiftUI.State private var query: String
    @SwiftUI.State private var presentedMenu: FilterMenu?

    init(
        state: State,
        onSearch: @escaping (String) -> Void = { _ in },
        onSelectGroup: @escaping (String) -> Void = { _ in },
        onSelectLeader: @escaping (String) -> Void = { _ in },
        onOpenMember: @escaping (Int) -> Void = { _ in }
    ) {
        self.state = state
        self.onSearch = onSearch
        self.onSelectGroup = onSelectGroup
        self.onSelectLeader = onSelectLeader
        self.onOpenMember = onOpenMember
        _query = SwiftUI.State(initialValue: state.searchText)
        _presentedMenu = SwiftUI.State(initialValue: nil)
    }
```

Delete lines 95-96 (`/// §4 (C-019): "collapsed, Members active".` and `private static let selectedTab = "Members"`).

Replace `body` and `navRow` (lines 113-141) with:

```swift
    var body: some View {
        // D22: no ScrollView at the root — in the app the shell's page scroll scrolls it
        // (HomeSectionLayout); the capture canvas lays it out at its full length.
        VStack(alignment: .leading, spacing: 0) {
            header
            memberList
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)                      // §2: `color-layout-background`
        .overlay { filterMenu }
    }
```

Replace `header` (lines 148-184) with:

```swift
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // §2's "16pt top inset" is the gap between the nav row and the field. The row is now
            // the shell's (D4) and `HomeSectionLayout.navGap` (16) already is that gap, so the
            // screen adds none of its own (routed to /ui2-resolve with D4, F3).
            // §4: C-034, its editable form (D19) — focus is the field's own.
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
            .ui2Element("C-034 SearchField")
            Spacer().frame(height: Self.headerGap)
            // OQ-members-home-3 (non-blocking) proposed default: single line; the chips scroll
            // horizontally only when long selections overflow — the resting row fits, so it is a
            // plain HStack here.
            HStack(spacing: Token.Space.elementGap) {                // §2: "8pt gap"
                FilterChip(type: .menu, active: false, label: state.groupFilterLabel) {
                    presentedMenu = .groups
                }
                .ui2Element("C-035 FilterChip")
                if state.showsLeaderFilter {                         // D7/D15
                    FilterChip(type: .menu, active: false, label: state.leaderFilterLabel) {
                        presentedMenu = .leaders
                    }
                    .ui2Element("C-035 FilterChip 2")
                }
            }
            Spacer().frame(height: Self.headerGap)
        }
        .padding(.horizontal, Token.Space.pageMargin)                // §2: content inset 16
    }
```

Replace `memberRow(at:)` (lines 210-224) with:

```swift
    private func memberRow(at index: Int) -> some View {
        let photo = state.memberPhotoURLs[safe: index] ?? ""
        let initials = state.memberInitials[safe: index] ?? ""
        let count = state.memberGroupCounts[safe: index] ?? 0
        return ListResultRow(
            subject: .member,
            title: state.memberNames[index],
            detail: .text,
            description: state.memberJoinedLabels[safe: index],
            count: count > 0 ? count : nil,
            trailing: .chevron,
            imageURL: photo.isEmpty ? nil : URL(string: photo),
            initials: initials.isEmpty ? nil : initials,             // T11: C-038's fallback
            onTap: { onOpenMember(index) }
        )
        .ui2Element(Self.partName("C-037 ListResultRow", ordinal: index + 1))
    }
```

In `static let populated` (lines 274-296), add `showsLeaderFilter: true,` directly after the `leaderOptions: ["All Leaders"],` line, and add directly after the `memberPhotoURLs: [ … ],` array:

```swift
        memberInitials: ["BA", "CK", "IH", "DT", "BW"],
```

In `iphone/MakeReadyCaptureTests/CaptureFixture.swift`, directly after `let memberGroupCounts: [Int]?` (line 861) add:

```swift
    // ui2-members-browse T11 (D7/D15; C-038 initials inside C-037) — additive.
    let showsLeaderFilter: Bool?
    let memberInitials: [String]?
```

In `iphone/MakeReadyCaptureTests/ViewRegistry.swift`, `case "screen.2.0.members-home"`, replace the `state: .init(…)` argument (lines 2499-2509) with:

```swift
            state: .init(
                searchText: c.searchText ?? sample.searchText,
                groupFilterLabel: c.groupFilterLabel ?? sample.groupFilterLabel,
                leaderFilterLabel: c.leaderFilterLabel ?? sample.leaderFilterLabel,
                groupOptions: c.groupOptions ?? sample.groupOptions,
                leaderOptions: c.leaderOptions ?? sample.leaderOptions,
                showsLeaderFilter: c.showsLeaderFilter ?? sample.showsLeaderFilter,
                memberNames: c.memberNames ?? sample.memberNames,
                memberPhotoURLs: c.memberPhotoURLs ?? sample.memberPhotoURLs,
                memberInitials: c.memberInitials ?? sample.memberInitials,
                memberJoinedLabels: c.memberJoinedLabels ?? sample.memberJoinedLabels,
                memberGroupCounts: c.memberGroupCounts ?? sample.memberGroupCounts
            )
```

The `#Preview("populated")` block needs no change (it passes `.populated` only).

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (two new tests; `ViewRegistryKeysTests` unchanged — no case label changed); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations. Then re-capture `screen.2.0.members-home` through the d2m build harness by slug (never `*`) and record the diff result per F14 in the report.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReadyUI/Screens/Members/MembersHomeScreen.swift iphone/MakeReadyCaptureTests/ViewRegistry.swift iphone/MakeReadyCaptureTests/CaptureFixture.swift iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): MembersHomeScreen drops its nav row, scopes the Leaders chip, passes initials`. Do not run `git commit`. Note for the report: D4, D7/D15, D19, T11 and the dropped top inset are owed to `/ui2-resolve` (F3).

### Task 14: C-042 non-tappable form + MembersProfileScreen — nine display-only fields, rail opens on today
App: iphone
Phase: 4
Recipe: /ui2-component-build — screen and component edits keep the built conventions (R-03, R-17 accessibility, `.ui2Element` part names); the d2m harness re-captures + diffs after the edit (F14)
Design ownership (F3): `iphone/MakeReadyUI/` is d2m-owned. These edits are authorized by SPEC D3 (non-tappable C-042, chevron hidden — contradicts OQ-C-042-3 "no disabled rows", which goes to `/ui2-resolve` with F3), P5/D9 (no Email indicator), P6 (an "Emergency phone" row, nine rows), P7 (Address multi-line), D10 (`age` empty when absent) and D12/T12 (rail opens on today). After the build, route all of them to `/ui2-resolve`; never write anything under `docs/ui2/`.
Build-time risk (F5): `MembersProfileScreen` builds `populated` + `partial` only (`loading`/`error` named, unbuilt) and the shell has no loading/error surface (ui2-shell D28): loading renders the cached or empty State (header with the list-known name), a failure keeps the last State; the designed skeleton/error states go to `/ui2-component-build` — never built here to make a check pass.
Build-time risk (F13): C-038 initials at 164pt (OQ-C-038-2/-3) are undesigned — verify on the walk; carried OQ, no ruling here. Do not restyle the 164pt initials in this task.
Build-time risk (F14): Built-screen render vs frozen Figma snapshot was not diffed at audit — this screen is edited here and re-captured + diffed through the d2m harness after its edit, superseding a pre-build diff. Record the result in the report.

**Files:**
- Modify: `iphone/MakeReadyUI/EditableFieldRow.swift:6` (header line), `:67-99` (`isTappable` + body), `:164-182` (chevron only when tappable)
- Modify: `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift:10` (header line), `:40-50` (State: `age`, emergency fields, no `emailVerified`), `:106-108` (rail state), `:123-127` (labels), `:252` (Age cell), `:270-315` (fields), `:317-355` (Activity rail), `:506-575` (samples)
- Modify: `iphone/MakeReadyCaptureTests/ViewRegistry.swift:2405-2414` (`screen.2.0.members-profile` State init)
- Modify: `iphone/MakeReadyCaptureTests/CaptureFixture.swift:837` (one additive optional field)
- Test: `iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift` (append to the class)

**Interfaces:**
- Consumes: existing `EditableFieldRow` memberwise init (`label:value:tags:indicator:multiline:onTap:`), `EditableFieldRow.Indicator`, `HorizontalRail`, `RailCard`, `SectionHeader`, `ScrollViewReader` (the `HomeDashboardScreen.swift:283` pattern).
- Produces:
  - `EditableFieldRow.isTappable: Bool = true` — declared after `onTap`, so the memberwise init is `EditableFieldRow(label:value:tags:indicator:multiline:onTap:isTappable:)`; `false` renders no `SwiftUI.Button`, no chevron, no button trait
  - `MembersProfileScreen.State` field order (memberwise, used by Task 16): `memberName`, `email`, `avatarURL`, `initials`, `age: String`, `role`, `birthday`, `joined`, `organization`, `phone`, `phoneVerified`, `gender`, `address`, `emergencyContactName`, `emergencyContactPhone`, then the unchanged `day*`, `group*`, `program*` arrays
  - `static let fieldLabels: [String]` (the nine rows, top → bottom), `static let fieldsTappable = false` (D3), `static func fieldValue(_ label: String, _ s: State) -> String`, `static func indicator(forField label: String, state: State) -> EditableFieldRow.Indicator?`, `static func todayIndex(_ dateStates: [String]) -> Int?`
  - `CaptureComponent.emergencyContactPhone: String?`

- [ ] **Step 1: Write the failing tests** — append to `final class UI2MembersComponentTests`:

```swift
    // MARK: - Task 14: C-042 non-tappable form + MembersProfileScreen (D3, P5/D9, P6, P7, D10, D12)

    func testEditableFieldRowIsTappableUnlessToldOtherwise() {
        XCTAssertTrue(EditableFieldRow(label: "Email address", value: "a@b.example").isTappable)
        XCTAssertFalse(EditableFieldRow(label: "Role", value: "Member", isTappable: false).isTappable)
    }

    /// P6: nine rows, "Emergency phone" last; D3: none of them tappable in this child.
    func testMemberPageDrawsNineDisplayOnlyFields() {
        XCTAssertEqual(MembersProfileScreen.fieldLabels, [
            "Organization", "Role", "Phone number", "Email address", "Birthday",
            "Gender", "Address", "Emergency contact", "Emergency phone"
        ])
        XCTAssertFalse(MembersProfileScreen.fieldsTappable)
    }

    func testFieldValuesComeFromTheirOwnStateFields() {
        let s = MembersProfileScreen.State.populated
        XCTAssertEqual(MembersProfileScreen.fieldValue("Emergency contact", s), s.emergencyContactName)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Emergency phone", s), s.emergencyContactPhone)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Address", s), s.address)
        XCTAssertEqual(MembersProfileScreen.fieldValue("Organization", s), s.organization)
    }

    /// P5/D9: Email carries no indicator; Phone reads Verified / Unverified.
    func testOnlyPhoneCarriesAVerificationIndicator() {
        var s = MembersProfileScreen.State.populated
        XCTAssertNil(MembersProfileScreen.indicator(forField: "Email address", state: s))
        XCTAssertEqual(MembersProfileScreen.indicator(forField: "Phone number", state: s)?.text, "Verified")
        s.phoneVerified = false
        XCTAssertEqual(MembersProfileScreen.indicator(forField: "Phone number", state: s)?.text, "Unverified")
        s.phone = ""
        XCTAssertNil(MembersProfileScreen.indicator(forField: "Phone number", state: s))   // D10: no value, no indicator
    }

    /// D10: Age is a String so a missing birthday renders an empty value line.
    func testSamplesCarryTheSplitEmergencyContactAndAStringAge() {
        XCTAssertEqual(MembersProfileScreen.State.populated.age, "52")
        XCTAssertEqual(MembersProfileScreen.State.populated.emergencyContactName, "Pepper Stark")
        XCTAssertEqual(MembersProfileScreen.State.populated.emergencyContactPhone, "+1 (123) 456-7891")
        XCTAssertEqual(MembersProfileScreen.State.partial.emergencyContactPhone, "")
    }

    /// D12: today is the rail's trailing card.
    func testRailTodayIndex() {
        XCTAssertEqual(MembersProfileScreen.todayIndex(["default", "default", "today"]), 2)
        XCTAssertEqual(MembersProfileScreen.todayIndex(MembersProfileScreen.State.populated.dayDateStates), 3)
        XCTAssertNil(MembersProfileScreen.todayIndex([]))
    }
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "extra argument 'isTappable' in call", "type 'MembersProfileScreen' has no member 'fieldLabels'", "value of type 'MembersProfileScreen.State' has no member 'emergencyContactName'".

- [ ] **Step 3a: C-042's non-tappable form** — in `iphone/MakeReadyUI/EditableFieldRow.swift`:

Line 6, replace `//  PREVIEW ONLY: referenced by no screen, route, tab or flag.` with:

```swift
//  Consumed by MembersProfileScreen in its non-tappable form (ui2-members-browse D3 — routed to
//  /ui2-resolve with OQ-C-042-3, F3).
```

Directly after `var onTap: () -> Void = {}` (line 71) add:

```swift
    /// D3 (ui2-members-browse): `false` renders the row display-only — no button, no press
    /// highlight, no chevron — for a host whose field has no edit page yet. It contradicts
    /// OQ-C-042-3's "no disabled rows (omit instead)", which is routed to /ui2-resolve (F3).
    var isTappable: Bool = true
```

Replace `body` (lines 73-99) with:

```swift
    var body: some View {
        if isTappable {
            SwiftUI.Button(action: onTap) { row }
                // OQ-C-042-3 (ruled 2026-09-21): "system highlight on press" — `.plain` is exactly
                // that: no idle decoration, the system's own pressed feedback, held as ephemeral
                // button state (R-02), never as a prop.
                .buttonStyle(.plain)
                // R-17: the one interactive element carries its label and the button trait. The
                // label reads what the row shows — label, then value / tags, then indicator.
                .accessibilityLabel(accessibilityText)
                .accessibilityAddTraits(.isButton)
                .ui2Element("EditableFieldRow")           // capture element map — UI2Element.swift
        } else {
            // D3: the same row as static content — R-17 still reads it as one element.
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
                .ui2Element("EditableFieldRow")
        }
    }

    private var row: some View {
        // §2: "gap 8" — also the measured distance between the indicator and the chevron, and
        // between the left column and the trailing group.
        HStack(spacing: Token.Space.elementGap) {
            leftColumn.ui2Element("Left column")
            Spacer(minLength: Token.Space.elementGap)
            trailing.ui2Element("Trailing")
        }
        // §2: "py16". No horizontal inset: the row is width-driven and its consumers own the
        // page margin (§1 deviation 2).
        .padding(.vertical, Token.Space.pageMargin)
        // §2: "full-width tappable" — the whole row, not just its ink.
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
```

In `trailing` (lines 166-182) replace `chevron.ui2Element("Chevron")` with:

```swift
            if isTappable { chevron.ui2Element("Chevron") }   // D3: hidden on a display-only row
```

- [ ] **Step 3b: the member page** — in `iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift`:

Line 10, replace `//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.` with:

```swift
//  Wired by MakeReady/UI2/Containers/Members/MemberProfileContainer.swift (ui2-members-browse).
//  ui2-members-browse edits, routed to /ui2-resolve (F3): display-only C-042 rows (D3), no Email
//  indicator (P5/D9), "Emergency contact" + "Emergency phone" (P6), multi-line Address (P7),
//  `age` as a String (D10), the rail opening on today (D12).
```

In `State`, replace `var age: Int` (line 40) with:

```swift
        /// D10: "" when the birthday is absent → an empty value line.
        var age: String
```

delete `var emailVerified: Bool` (line 47) — P5/D9: no email indicator — and replace `var emergencyContact: String` (line 50) with:

```swift
        /// P6: two fields, two rows.
        var emergencyContactName: String
        var emergencyContactPhone: String
```

Replace the comment at lines 106-108 (`// §3 has no UI-only rule on this screen … So there is no \`@SwiftUI.State\` here.`) with:

```swift
    // R-31 ephemeral UI: the day rail's scroll position (D12: it opens on today, "Jump to today"
    // returns there). Everything else leaves the screen.
    @SwiftUI.State private var railDay: Int?
```

Directly after `private static let emergencyContactLabel = "Emergency contact"` (line 123) add:

```swift
    private static let emergencyPhoneLabel = "Emergency phone"
    /// §2.4 + P6: the nine field rows, top → bottom.
    static let fieldLabels = [
        organizationLabel, roleLabel, phoneLabel, emailLabel, birthdayLabel,
        genderLabel, addressLabel, emergencyContactLabel, emergencyPhoneLabel
    ]
    /// D3: every C-042 row on this page is display-only in this child (child 2 enables them).
    static let fieldsTappable = false
```

Line 252, replace `statCell(label: Self.ageLabel, value: "\(state.age)", ordinal: 1)` with:

```swift
                statCell(label: Self.ageLabel, value: state.age, ordinal: 1)
```

Replace the whole `// MARK: §2.4 Fields` block — the doc comment, `fields`, `fieldRow(…)` and `verification(…)` (lines 270-315) — with:

```swift
    // MARK: §2.4 Fields

    /// §2.4 + P6: nine stacked EditableFieldRow (C-042) rows, 74pt each, no separators. §3
    /// `partial`: an absent value is passed as "", never nil (nil drops the value line, D10).
    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.fieldLabels.enumerated()), id: \.offset) { index, label in
                EditableFieldRow(
                    label: label,
                    value: Self.fieldValue(label, state),
                    indicator: Self.indicator(forField: label, state: state),
                    multiline: label == Self.addressLabel,              // P7
                    onTap: { onEditField(label) },
                    isTappable: Self.fieldsTappable                     // D3
                )
                .ui2Element(Self.partName("C-042 EditableFieldRow", ordinal: index + 1))
            }
        }
        .padding(.horizontal, Token.Space.pageMargin)
    }

    static func fieldValue(_ label: String, _ s: State) -> String {
        switch label {
        case Self.organizationLabel: return s.organization
        case Self.roleLabel: return s.role
        case Self.phoneLabel: return s.phone
        case Self.emailLabel: return s.email
        case Self.birthdayLabel: return s.birthday
        case Self.genderLabel: return s.gender
        case Self.addressLabel: return s.address
        case Self.emergencyContactLabel: return s.emergencyContactName
        case Self.emergencyPhoneLabel: return s.emergencyContactPhone
        default: return ""
        }
    }

    /// P5/D9: only Phone carries an indicator — Green "Verified" / Red "Unverified"; display-only
    /// (§3). No value, no indicator.
    static func indicator(forField label: String, state s: State) -> EditableFieldRow.Indicator? {
        guard label == Self.phoneLabel, !s.phone.isEmpty else { return nil }
        return s.phoneVerified
            ? .init(text: verifiedText, tone: .positive)
            : .init(text: unverifiedText, tone: .negative)
    }
```

Replace the `// MARK: §2.5 Activity` block — `activitySection` (lines 317-355) — with:

```swift
    // MARK: §2.5 Activity

    /// D12: today's card — the rail's trailing card; nil while the rail is empty.
    static func todayIndex(_ dateStates: [String]) -> Int? { dateStates.lastIndex(of: "today") }

    // GAP — no motion token for the recentre: HomeDashboardScreen's ease-in-out, 0.45s.
    private static var jumpAnimation: Animation { .easeInOut(duration: 0.45) }

    private var activitySection: some View {
        // T12: the reader lets "Jump to today" scroll the rail directly (HomeDashboardScreen.swift
        // pattern) — a binding write the rail already holds would not move it.
        ScrollViewReader { rail in
            VStack(alignment: .leading, spacing: 0) {
                // §2.5: "C-020 SectionHeader (title + `text-link` accessory "Jump to today")".
                SectionHeader(
                    title: Self.activityTitle,
                    accessory: .link(label: Self.jumpToTodayLabel, style: .muted),
                    onAccessoryTap: { jumpToToday(rail) }
                )
                .padding(.horizontal, Token.Space.pageMargin)
                .ui2Element("C-020 SectionHeader")
                Spacer().frame(height: Token.Space.sectionGap)           // frame: 1236→1268
                // §2.5: "Day rail: C-023 RailCard `kind=day · transparent` ×N, 131×192, shared 1px
                // borders, horizontal scroll". A horizontal carousel keeps its own ScrollView (D22).
                HorizontalRail {
                    HStack(alignment: .top, spacing: Self.dayCardOverlap) {
                        ForEach(state.dayNumbers.indices, id: \.self) { index in
                            RailCard(
                                kind: .day,
                                series: state.daySeries[safe: index] ?? [],
                                state: .transparent,
                                month: state.dayMonths[safe: index] ?? "",
                                weekday: state.dayWeekdays[safe: index] ?? "",
                                day: state.dayNumbers[index],
                                dateState: Self.dateState(state.dayDateStates[safe: index]),
                                line1: state.dayLine1s[safe: index] ?? "",
                                line2: Self.optionalText(state.dayLine2s[safe: index]),
                                detailsState: Self.detailsState(state.dayDetailsStates[safe: index])
                            )
                            .frame(width: Self.dayCardWidth)
                            .ui2Element(Self.partName("C-023 RailCard", ordinal: index + 1))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, Token.Space.pageMargin)
                }
                .scrollIndicators(.hidden)
                // D12: the rail opens with today as its trailing card; days that land after the
                // page opened (cache-first, F5) re-align it.
                .scrollPosition(id: $railDay, anchor: .trailing)
                .onAppear { railDay = Self.todayIndex(state.dayDateStates) }
                .onChange(of: Self.todayIndex(state.dayDateStates)) { _, today in railDay = today }
            }
        }
    }

    /// members-profile §3: "Jump to today" recentres the rail on today (most recent day trailing).
    private func jumpToToday(_ rail: ScrollViewProxy) {
        if let today = Self.todayIndex(state.dayDateStates) {
            withAnimation(Self.jumpAnimation) {
                railDay = today
                rail.scrollTo(today, anchor: .trailing)
            }
        }
        onJumpToToday()
    }
```

In `static let populated` (lines 506-554): change `age: 52,` to `age: "52",`; delete the line `emailVerified: false,`; replace `emergencyContact: "Pepper Stark",` with:

```swift
        emergencyContactName: "Pepper Stark",
        emergencyContactPhone: "+1 (123) 456-7891",
```

In `static let partial` (lines 557-591): delete the line `emailVerified: populated.emailVerified,`; replace `emergencyContact: "",` with:

```swift
        emergencyContactName: "",
        emergencyContactPhone: "",
```

(`age: populated.age,` stays — it is now a String.)

- [ ] **Step 3c: keep the capture case compiling** — in `iphone/MakeReadyCaptureTests/CaptureFixture.swift`, directly after `let emergencyContact: String?` (line 837) add:

```swift
    // ui2-members-browse P6: `emergencyContact` feeds the "Emergency contact" (name) row; the new
    // "Emergency phone" row reads this — additive.
    let emergencyContactPhone: String?
```

In `iphone/MakeReadyCaptureTests/ViewRegistry.swift`, `case "screen.2.0.members-profile"`: replace `age: c.age ?? sample.age,` with `age: c.age.map { String($0) } ?? sample.age,`; delete the line `emailVerified: c.emailVerified ?? sample.emailVerified,`; replace `emergencyContact: c.emergencyContact ?? sample.emergencyContact,` with:

```swift
                emergencyContactName: c.emergencyContact ?? sample.emergencyContactName,
                emergencyContactPhone: c.emergencyContactPhone ?? sample.emergencyContactPhone,
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (six new tests; the `component.ui2.C-042` capture case still builds the tappable row — it passes no `isTappable`); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (`HorizontalRail` keeps `raw_horizontal_scrollview` quiet). Then re-capture `screen.2.0.members-profile` and `component.ui2.C-042` through the d2m harness by slug and record the diff results per F14.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReadyUI/EditableFieldRow.swift iphone/MakeReadyUI/Screens/Members/MembersProfileScreen.swift iphone/MakeReadyCaptureTests/ViewRegistry.swift iphone/MakeReadyCaptureTests/CaptureFixture.swift iphone/MakeReadyCaptureTests/UI2MembersComponentTests.swift`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): member page — nine display-only fields, split emergency contact, rail opens on today`. Do not run `git commit`. Note for the report: D3 (vs OQ-C-042-3), P5/D9, P6, P7, D10, D12 are owed to `/ui2-resolve` (F3).

### Task 15: MembersHomeContainer + MembersHomeMapper — the Members section, live
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — the container reads `AppState` and calls `MemberActions`, the mapper is a pure function of the stores; the selection and the debounce are UI state (`@State` in the container); nothing under `iphone/MakeReadyUI/` is edited
Build-time risk (F5): `MembersHomeScreen.State` has no `loading`/`empty`/`error`, and the shell has no loading/error surface (ui2-shell D28 — Home is cache-first, failures `recordError(surface: false)`): loading renders the cached or empty State, a failure keeps the last State; the designed skeleton/empty/error states go to `/ui2-component-build` — never built here to make a check pass.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Members/MembersHomeMapper.swift`
- Create: `iphone/MakeReady/UI2/Containers/Members/MembersHomeContainer.swift`
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`sectionContent`: Members → `MembersHomeContainer()`)
- Modify: `iphone/MakeReady/UI2/Shell/HomeSectionLayout.swift:129` (`.scrollDismissesKeyboard(.interactively)` on the section page's ScrollView — D19's "on the list": the list scrolls in this ScrollView, not its own)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register three new files — Steps 1 and 3)
- Test: Create `iphone/MakeReadyCaptureTests/MembersHomeMapperTests.swift`

**Interfaces:**
- Consumes (Task 9): `OrgMemberDirectory`, `OrgMemberListItem(id:firstName:lastName:profilePicture:googlePicture:joinedAt:groupCount:)`, `ViewerScope(all:groupIds:)`. (Task 10): `AppState.orgMembersByOrgId`, `MemberActions(onUnauthorized:)`, `.loadDirectory(orgId:search:groupId:leaderId:)`, `.loadFilterOptions()`. (Task 11): `@Environment(\.ui2Navigator)` → `push(.memberDetail(id:name:))`. (Task 13): `MembersHomeScreen(state:onSearch:onSelectGroup:onSelectLeader:onOpenMember:)` and its `State` memberwise order (`searchText, groupFilterLabel, leaderFilterLabel, groupOptions, leaderOptions, showsLeaderFilter, memberNames, memberPhotoURLs, memberInitials, memberJoinedLabels, memberGroupCounts`). Existing: `AppState.groups` (`EntityStore<UserGroup>`, `.all`), `AppState.groupLeaders: [GroupLeader]` (`.displayName`), `HomeDashboardMapper.shortMonths`, `AuthManager.signOut()`.
- Produces (Task 16 relies on the four helpers):
  - `enum MembersHomeMapper` — `static let allGroups = "All Groups"`, `static let allLeaders = "All Leaders"`; `struct Option: Equatable { let id: String; let label: String }`; `struct Selection: Equatable { var search = ""; var groupId: String?; var leaderId: String? }`; `enum Pick: Equatable { case all, option(String), unknown }`; `struct Output { var state: MembersHomeScreen.State; var memberIds: [String]; var groupOptionIds: [String]; var leaderOptionIds: [String]; func memberId(atRow: Int) -> String?; func groupPick(_ label: String) -> Pick; func leaderPick(_ label: String) -> Pick }`
  - `static func output(directory: OrgMemberDirectory?, groups: [Option], leaders: [Option], selection: Selection, today: Date, timeZone: TimeZone) -> Output`
  - `static func joinedLabel(_ iso: String, today: Date, timeZone: TimeZone) -> String` (D6)
  - `static func parseDate(_ iso: String) -> Date?` (fractional, then plain ISO 8601 — F7)
  - `static func mediumDate(_ date: Date, timeZone: TimeZone) -> String` ("Jan 5, 2025")
  - `static func displayName(first: String?, last: String?) -> String`, `static func initials(first: String?, last: String?) -> String`
  - `struct MembersHomeContainer: View` — `static let searchDebounce: Duration = .milliseconds(300)`, `static func groupOptions(_: [UserGroup]) -> [MembersHomeMapper.Option]` (by name, case-insensitive), `static func leaderOptions(_: [GroupLeader]) -> [MembersHomeMapper.Option]` (server order)

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/MembersHomeMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-browse T13 (Members half): D6 labels, D7/D15 chips, the [id] snapshot behind
/// every index the screen renders.
final class MembersHomeMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Oct 25, noon MDT
    private let groups = [MembersHomeMapper.Option(id: "g1", label: "The kids"),
                          MembersHomeMapper.Option(id: "g2", label: "Young professionals")]
    private let leaders = [MembersHomeMapper.Option(id: "u1", label: "Luke Keith"),
                           MembersHomeMapper.Option(id: "u2", label: "Scott Stickane")]

    private func member(_ id: String, _ first: String?, _ last: String?, joined: String = "2026-10-25T07:00:00.000Z",
                        photo: String? = nil, google: String? = nil, groupCount: Int = 0) -> OrgMemberListItem {
        OrgMemberListItem(id: id, firstName: first, lastName: last, profilePicture: photo,
                          googlePicture: google, joinedAt: joined, groupCount: groupCount)
    }

    private func map(_ directory: OrgMemberDirectory?, _ selection: MembersHomeMapper.Selection = .init()) -> MembersHomeMapper.Output {
        MembersHomeMapper.output(directory: directory, groups: groups, leaders: leaders,
                                 selection: selection, today: today, timeZone: tz)
    }

    /// D6, every cut, by LOCAL calendar-day age (Denver).
    func testJoinedLabelAtEveryCut() {
        let cases: [(iso: String, label: String)] = [
            ("2026-10-25T07:00:00.000Z", "Joined Today"),             // Oct 25 01:00 local
            ("2026-10-25T05:59:00.000Z", "Joined Yesterday"),         // Oct 24 23:59 local — tz, not UTC
            ("2026-10-23T18:00:00Z", "Joined 2 days ago"),
            ("2026-10-19T18:00:00Z", "Joined 6 days ago"),
            ("2026-10-18T18:00:00Z", "Joined 1 week ago"),
            ("2026-10-12T18:00:00Z", "Joined 1 week ago"),            // 13 days
            ("2026-10-11T18:00:00Z", "Joined 2 weeks ago"),           // 14 days
            ("2026-09-26T18:00:00Z", "Joined 4 weeks ago"),           // 29 days
            ("2026-09-25T18:00:00Z", "Joined Sep 25, 2026"),          // 30 days — the absolute cut
            ("2025-01-05T18:00:00.000Z", "Joined Jan 5, 2025"),
            ("2026-10-26T18:00:00Z", "Joined Today"),                 // a future stamp clamps to today
            ("garbage", "")
        ]
        for c in cases {
            XCTAssertEqual(MembersHomeMapper.joinedLabel(c.iso, today: today, timeZone: tz), c.label, c.iso)
        }
    }

    /// D6: the server's order is the list's order; T13: every row index resolves to its id.
    func testRowsKeepServerOrderAndResolveToIds() {
        let out = map(OrgMemberDirectory(members: [
            member("m2", "Clark", "Kent", groupCount: 1),
            member("m1", "Barry", "Allen", groupCount: 2)
        ]))
        XCTAssertEqual(out.state.memberNames, ["Clark Kent", "Barry Allen"])
        XCTAssertEqual(out.memberIds, ["m2", "m1"])
        XCTAssertEqual(out.state.memberGroupCounts, [1, 2])
        XCTAssertEqual(out.memberId(atRow: 1), "m1")
        XCTAssertNil(out.memberId(atRow: 2))
    }

    func testPhotoFallsBackToGoogleThenToInitials() {
        let out = map(OrgMemberDirectory(members: [
            member("m1", "Barry", "Allen", photo: "https://cdn.example/b.jpg", google: "https://lh3.example/b.jpg"),
            member("m2", "Clark", "Kent", photo: "", google: "https://lh3.example/c.jpg"),
            member("m3", "Cher", nil)
        ]))
        XCTAssertEqual(out.state.memberPhotoURLs, ["https://cdn.example/b.jpg", "https://lh3.example/c.jpg", ""])
        XCTAssertEqual(out.state.memberInitials, ["BA", "CK", "CH"])
        XCTAssertEqual(out.state.memberNames, ["Barry Allen", "Clark Kent", "Cher"])
    }

    func testNamesAndInitialsHelpers() {
        XCTAssertEqual(MembersHomeMapper.displayName(first: " Tony ", last: "Stark"), "Tony Stark")
        XCTAssertEqual(MembersHomeMapper.displayName(first: nil, last: nil), "")
        XCTAssertEqual(MembersHomeMapper.initials(first: "tony", last: "stark"), "TS")
        XCTAssertEqual(MembersHomeMapper.initials(first: nil, last: "Stark"), "ST")
        XCTAssertEqual(MembersHomeMapper.initials(first: nil, last: nil), "")
    }

    /// D7/D15: everyone-visible callers (or a server without D15) get every group and the Leaders chip.
    func testAnOwnerSeesEveryGroupAndTheLeaderChip() {
        for scope in [ViewerScope(all: true, groupIds: []), nil] {
            let out = map(OrgMemberDirectory(viewerScope: scope))
            XCTAssertTrue(out.state.showsLeaderFilter)
            XCTAssertEqual(out.state.groupOptions, ["All Groups", "The kids", "Young professionals"])
            XCTAssertEqual(out.state.leaderOptions, ["All Leaders", "Luke Keith", "Scott Stickane"])
        }
    }

    /// D15: a scoped leader's Groups options are only `viewerScope.groupIds`; no Leaders chip.
    func testAScopedLeaderSeesOnlyTheirGroupsAndNoLeaderChip() {
        let out = map(OrgMemberDirectory(viewerScope: ViewerScope(all: false, groupIds: ["g2"])))
        XCTAssertFalse(out.state.showsLeaderFilter)
        XCTAssertEqual(out.state.groupOptions, ["All Groups", "Young professionals"])
        XCTAssertEqual(out.groupPick("The kids"), .unknown)
        XCTAssertEqual(out.groupPick("Young professionals"), .option("g2"))
    }

    func testChipLabelsFollowTheSelection() {
        var selection = MembersHomeMapper.Selection(search: "kent", groupId: "g2", leaderId: "u2")
        var out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.searchText, "kent")
        XCTAssertEqual(out.state.groupFilterLabel, "Young professionals")
        XCTAssertEqual(out.state.leaderFilterLabel, "Scott Stickane")
        selection.groupId = "gone"
        selection.leaderId = nil
        out = map(OrgMemberDirectory(), selection)
        XCTAssertEqual(out.state.groupFilterLabel, "All Groups")
        XCTAssertEqual(out.state.leaderFilterLabel, "All Leaders")
    }

    /// T13: an option pick resolves against the options that were rendered.
    func testPicksResolveAgainstTheRenderedOptions() {
        let out = map(OrgMemberDirectory())
        XCTAssertEqual(out.groupPick("All Groups"), .all)
        XCTAssertEqual(out.groupPick("The kids"), .option("g1"))
        XCTAssertEqual(out.leaderPick("All Leaders"), .all)
        XCTAssertEqual(out.leaderPick("Luke Keith"), .option("u1"))
        XCTAssertEqual(out.leaderPick("Nobody"), .unknown)
    }

    /// F5: no directory yet renders the empty list with the header live.
    func testNoDirectoryYetIsAnEmptyList() {
        let out = map(nil)
        XCTAssertEqual(out.state.memberNames, [])
        XCTAssertEqual(out.memberIds, [])
        XCTAssertTrue(out.state.showsLeaderFilter)
        XCTAssertEqual(out.state.groupFilterLabel, "All Groups")
    }

    func testParseDateTakesFractionalAndPlainStamps() {
        XCTAssertNotNil(MembersHomeMapper.parseDate("2026-07-05T14:03:22.123Z"))
        XCTAssertNotNil(MembersHomeMapper.parseDate("2026-07-05T14:03:22Z"))
        XCTAssertNil(MembersHomeMapper.parseDate("July 5"))
        XCTAssertEqual(MembersHomeMapper.mediumDate(try XCTUnwrap(MembersHomeMapper.parseDate("2025-01-05T18:00:00Z")), timeZone: tz), "Jan 5, 2025")
    }

    func testContainerOptionsAndDebounce() {
        let epoch = Date(timeIntervalSince1970: 0)
        func group(_ id: String, _ name: String) -> UserGroup {
            UserGroup(id: id, code: "ABC123", name: name, isPrivate: false, allowInvites: true,
                      memberCount: 1, creatorId: "u1", createdAt: epoch, updatedAt: epoch)
        }
        XCTAssertEqual(MembersHomeContainer.groupOptions([group("g2", "Young professionals"), group("g1", "the kids")]),
                       [MembersHomeMapper.Option(id: "g1", label: "the kids"),
                        MembersHomeMapper.Option(id: "g2", label: "Young professionals")])
        let leaders = [
            GroupLeader(id: "u2", firstName: "Scott", lastName: "Stickane", avatarUrl: nil, programCount: 0, mediaCount: 0),
            GroupLeader(id: "u1", firstName: "Luke", lastName: "Keith", avatarUrl: nil, programCount: 2, mediaCount: 0)
        ]
        XCTAssertEqual(MembersHomeContainer.leaderOptions(leaders).map(\.id), ["u2", "u1"])   // server order
        XCTAssertEqual(MembersHomeContainer.searchDebounce, .milliseconds(300))
    }
}
```

Register it:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "MembersHomeMapperTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "cannot find 'MembersHomeMapper' in scope", "cannot find 'MembersHomeContainer' in scope".

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReady/UI2/Containers/Members/MembersHomeMapper.swift`:

```swift
import Foundation

/// ui2-members-browse D6/D7/D15 + members-home §3: the Members section from the directory store.
/// Pure — the container owns the selection and the debounce. Order is the server's (`joinedAt`
/// desc); the mapper never re-sorts.
enum MembersHomeMapper {
    static let allGroups = "All Groups"
    static let allLeaders = "All Leaders"

    /// One chip-menu option: the id the server filters by, the label C-036 shows.
    struct Option: Equatable {
        let id: String
        let label: String
    }

    /// The container's query: search text and the two chip picks (nil = "All …").
    struct Selection: Equatable {
        var search = ""
        var groupId: String?
        var leaderId: String?
    }

    enum Pick: Equatable {
        case all
        case option(String)
        case unknown
    }

    /// T13: the State plus the ids behind every index it renders, so a row tap or an option pick
    /// resolves against the snapshot that was on screen, never a re-read store.
    struct Output {
        var state: MembersHomeScreen.State
        var memberIds: [String]
        var groupOptionIds: [String]       // parallel to state.groupOptions minus its leading "All Groups"
        var leaderOptionIds: [String]      // parallel to state.leaderOptions minus its leading "All Leaders"

        func memberId(atRow row: Int) -> String? {
            memberIds.indices.contains(row) ? memberIds[row] : nil
        }

        func groupPick(_ label: String) -> Pick {
            Self.pick(label, all: MembersHomeMapper.allGroups, labels: state.groupOptions, ids: groupOptionIds)
        }

        func leaderPick(_ label: String) -> Pick {
            Self.pick(label, all: MembersHomeMapper.allLeaders, labels: state.leaderOptions, ids: leaderOptionIds)
        }

        private static func pick(_ label: String, all: String, labels: [String], ids: [String]) -> Pick {
            if label == all { return .all }
            guard let index = labels.firstIndex(of: label), index > 0, ids.indices.contains(index - 1)
            else { return .unknown }
            return .option(ids[index - 1])
        }
    }

    static func output(directory: OrgMemberDirectory?, groups: [Option], leaders: [Option],
                       selection: Selection, today: Date, timeZone: TimeZone) -> Output {
        // D15: a server without `viewerScope` (nil) is read as "sees everyone" — it was before D7.
        let scope = directory?.viewerScope
        let seesAll = scope?.all ?? true
        let visibleGroups = seesAll ? groups : groups.filter { (scope?.groupIds ?? []).contains($0.id) }
        let members = directory?.members ?? []
        let state = MembersHomeScreen.State(
            searchText: selection.search,
            groupFilterLabel: visibleGroups.first { $0.id == selection.groupId }?.label ?? allGroups,
            leaderFilterLabel: leaders.first { $0.id == selection.leaderId }?.label ?? allLeaders,
            groupOptions: [allGroups] + visibleGroups.map(\.label),
            leaderOptions: [allLeaders] + leaders.map(\.label),
            showsLeaderFilter: seesAll,
            memberNames: members.map { displayName(first: $0.firstName, last: $0.lastName) },
            memberPhotoURLs: members.map { nonEmpty($0.profilePicture) ?? nonEmpty($0.googlePicture) ?? "" },
            memberInitials: members.map { initials(first: $0.firstName, last: $0.lastName) },
            memberJoinedLabels: members.map { joinedLabel($0.joinedAt, today: today, timeZone: timeZone) },
            memberGroupCounts: members.map(\.groupCount)
        )
        return Output(state: state, memberIds: members.map(\.id),
                      groupOptionIds: visibleGroups.map(\.id), leaderOptionIds: leaders.map(\.id))
    }

    // MARK: - Helpers (also read by MemberProfileMapper)

    /// D6: "Joined " + the LOCAL calendar-day age d — 0 "Today", 1 "Yesterday", 2–6 "d days ago",
    /// 7–29 "⌊d/7⌋ week(s) ago", ≥ 30 "MMM d, yyyy". "" when the stamp does not parse.
    static func joinedLabel(_ iso: String, today: Date, timeZone: TimeZone) -> String {
        guard let joined = parseDate(iso) else { return "" }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let age = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: joined), to: cal.startOfDay(for: today)).day ?? 0)
        switch age {
        case 0: return "Joined Today"
        case 1: return "Joined Yesterday"
        case 2...6: return "Joined \(age) days ago"
        case 7...29:
            let weeks = age / 7
            return "Joined \(weeks) \(weeks == 1 ? "week" : "weeks") ago"
        default: return "Joined " + mediumDate(joined, timeZone: timeZone)
        }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// F7: Prisma's `.SSSZ` first, then a plain ISO 8601 stamp.
    static func parseDate(_ iso: String) -> Date? {
        isoFractional.date(from: iso) ?? isoPlain.date(from: iso)
    }

    /// "MMM d, yyyy" in `timeZone` — D6's absolute form ("Jan 5, 2025").
    static func mediumDate(_ date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return "\(HomeDashboardMapper.shortMonths[m - 1]) \(d), \(y)"
    }

    static func displayName(first: String?, last: String?) -> String {
        [first, last]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// C-038 initials (OQ-C-038-3: two characters, uppercased): first + last initial, or the
    /// first two letters of the one name there is.
    static func initials(first: String?, last: String?) -> String {
        let f = nonEmpty(first?.trimmingCharacters(in: .whitespacesAndNewlines))
        let l = nonEmpty(last?.trimmingCharacters(in: .whitespacesAndNewlines))
        switch (f, l) {
        case let (f?, l?): return (String(f.prefix(1)) + String(l.prefix(1))).uppercased()
        case let (f?, nil): return String(f.prefix(2)).uppercased()
        case let (nil, l?): return String(l.prefix(2)).uppercased()
        case (nil, nil): return ""
        }
    }

    static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
```

Create `iphone/MakeReady/UI2/Containers/Members/MembersHomeContainer.swift`:

```swift
import SwiftUI

/// ui2-members-browse §iphone Members: the Home tab's Members section (P12, D6, D7/D15, D19).
/// Cache-first for the session (D21): renders the directory store at once and loads after the
/// shell's initial load, so the org id is known (D18). The screen has no root scroll — the
/// shell's page scroll (HomeSectionLayout) scrolls it. A row tap pushes the member page (D1).
struct MembersHomeContainer: View {
    /// members-home §3 / T13: search waits this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var selection = MembersHomeMapper.Selection()
    /// The one in-flight directory load; a newer keystroke or pick cancels it (T13: Task cancel +
    /// `Task.sleep`, never `asyncAfter`).
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        let app = AppState.shared
        let output = MembersHomeMapper.output(
            directory: app.organizationId.flatMap { app.orgMembersByOrgId[$0] },
            groups: Self.groupOptions(app.groups.all),
            leaders: Self.leaderOptions(app.groupLeaders),
            selection: selection, today: Date(), timeZone: .current
        )
        MembersHomeScreen(
            state: output.state,
            onSearch: { text in
                var next = selection
                next.search = text
                selection = next
                reload(next, after: Self.searchDebounce)
            },
            onSelectGroup: { label in
                var next = selection
                switch output.groupPick(label) {
                case .all: next.groupId = nil
                case .option(let id): next.groupId = id
                case .unknown: return
                }
                selection = next
                reload(next, after: nil)
            },
            onSelectLeader: { label in
                var next = selection
                switch output.leaderPick(label) {
                case .all: next.leaderId = nil
                case .option(let id): next.leaderId = id
                case .unknown: return
                }
                selection = next
                reload(next, after: nil)
            },
            onOpenMember: { row in
                guard let id = output.memberId(atRow: row) else { return }
                navigator.push(.memberDetail(id: id, name: output.state.memberNames[row]))
            }
        )
        .task {
            reload(selection, after: nil)
            await actions.loadFilterOptions()
        }
        .onDisappear { loadTask?.cancel() }
    }

    /// members-home §5: the Groups options, by name.
    static func groupOptions(_ groups: [UserGroup]) -> [MembersHomeMapper.Option] {
        groups
            .map { MembersHomeMapper.Option(id: $0.id, label: $0.name) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// members-home §5: the Leaders options, in `/api/group-leaders` order; the id is the
    /// leader's `User.id` the list's `leaderId` filter takes.
    static func leaderOptions(_ leaders: [GroupLeader]) -> [MembersHomeMapper.Option] {
        leaders.map { MembersHomeMapper.Option(id: $0.id, label: $0.displayName) }
    }

    private var actions: MemberActions {
        MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MembersHomeContainer.signOut", surface: false)
            }
        })
    }

    private func reload(_ next: MembersHomeMapper.Selection, after delay: Duration?) {
        loadTask?.cancel()
        let memberActions = self.actions
        loadTask = Task { @MainActor in
            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            await Self.load(next, actions: memberActions)
        }
    }

    @MainActor
    static func load(_ selection: MembersHomeMapper.Selection, actions: MemberActions) async {
        await AppState.shared.loadInitialData()                      // D18: waits for the org
        guard let orgId = AppState.shared.organizationId else { return }
        await actions.loadDirectory(orgId: orgId, search: selection.search,
                                    groupId: selection.groupId, leaderId: selection.leaderId)
    }
}
```

In `iphone/MakeReady/UI2/Shell/UI2Shell.swift`, replace `sectionContent` with:

```swift
    @ViewBuilder private var sectionContent: some View {
        switch model.section {
        case .home: HomeDashboardContainer()     // SPEC D8/D13
        case .members: MembersHomeContainer()    // ui2-members-browse
        default: EmptyPage()                     // SPEC D10: the other sections are unwired
        }
    }
```

In `iphone/MakeReady/UI2/Shell/HomeSectionLayout.swift`, in `SectionPageScroll.body`, directly after `.scrollBounceBehavior(.always, axes: .vertical)` (line 129) add:

```swift
        // ui2-members-browse D19: a drag on the section page (Members' list) dismisses the
        // keyboard the editable C-034 raised; inert on a page with no text input.
        .scrollDismissesKeyboard(.interactively)
```

Register both sources in `MakeReady` and mirror them into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReady/UI2", "Containers/Members/MembersHomeMapper.swift", "MakeReady"],
 ["MakeReady/UI2", "Containers/Members/MembersHomeContainer.swift", "MakeReady"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (eleven new `MembersHomeMapperTests` plus every existing case — `HomeDashboardContainerTests` and the pull-to-refresh are untouched: `refreshAction` stays Home-only); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations. Search-as-you-type, both chips against Fixtures, and the C-036 dim over TopNav/TabBar (F13) are walk items.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Containers/Members/MembersHomeMapper.swift iphone/MakeReady/UI2/Containers/Members/MembersHomeContainer.swift iphone/MakeReady/UI2/Shell/UI2Shell.swift iphone/MakeReady/UI2/Shell/HomeSectionLayout.swift iphone/MakeReadyCaptureTests/MembersHomeMapperTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): Members section lists, searches and filters the live directory`. Do not run `git commit`.

### Task 16: MemberProfileContainer + MemberProfileMapper — the member page, live
App: iphone
Phase: 5
Recipe: iphone/.claude/CLAUDE.md §🏛️ State Management Architecture (CRITICAL) — the container reads the member stores and calls `MemberActions`; the mapper is a pure function of them; nothing under `iphone/MakeReadyUI/` is edited
Build-time risk (F5): `MembersProfileScreen` builds `populated` + `partial` only (`loading`/`error` named, unbuilt) and the shell has no loading/error surface (ui2-shell D28): loading renders the cached or empty State with the header carrying the list-known name, a failure keeps the last State (the stores are written only on success); the designed skeleton/error states go to `/ui2-component-build` — never built here to make a check pass.

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift`
- Create: `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift`
- Modify: `iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift` (Task 11's file — its body becomes the container)
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj` (register three new files — Steps 1 and 3)
- Test: Create `iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift`

**Interfaces:**
- Consumes (Task 9): `MemberDetail` (memberwise, all 17 fields), `MemberDetailOrganization(organizationId:joinedAt:organization:)`, `MemberOrganizationRef(id:name:)`, `MemberGroupItem(id:name:coverImageUrl:organizationId:memberCount:joinedAt:creator:)`, `MemberGroupCreator(id:name:)`, `MemberEngagement(programs:)`, `MemberEngagementProgram(enrollmentId:programId:title:coverImageUrl:completedCount:totalCount:hours:percent:)`, `HomeDay(day:sessionSeconds:blocks:lastActivityAt:)`. (Task 10): `AppState.memberDetails` / `memberGroupsById` / `memberEngagementById` / `memberDaysById`, `MemberActions.railDays` (30), `MemberActions(onUnauthorized:)` `.loadMember/.loadMemberGroups/.loadEngagement/.loadMemberDays`. (Task 11): `MemberDetailHost(id:name:)`, `@Environment(\.ui2Navigator).pop()`. (Task 14): `MembersProfileScreen(state:onBack:…)` and its `State` memberwise order (`memberName, email, avatarURL, initials, age, role, birthday, joined, organization, phone, phoneVerified, gender, address, emergencyContactName, emergencyContactPhone, dayMonths, dayWeekdays, dayNumbers, dayDateStates, daySeries, dayLine1s, dayLine2s, dayDetailsStates, groupTitles, groupPhotoURLs, groupLeaders, groupJoinedDates, programTitles, programStates, programProgress, programCompleteCounts, programHours, programCoverURLs`). (Task 15): `MembersHomeMapper.parseDate(_:)`, `.mediumDate(_:timeZone:)`, `.displayName(first:last:)`, `.initials(first:last:)`, `.nonEmpty(_:)`. Existing: `HomeDashboardMapper.days(endingAt:back:ahead:tz:)` (`Day.key/.month/.day/.weekday`), `.key(_:tz:)`, `.blockMinutes(_:)`, `.shortMonths`; `Ui2ImageCache.shared` (`image(for:)`, `seed(_:for:)`).
- Produces: `enum MemberProfileMapper` — `struct Input { var name: String; var detail: MemberDetail? = nil; var groups: [MemberGroupItem]? = nil; var engagement: MemberEngagement? = nil; var days: [HomeDay]? = nil; var organizationId: String? = nil }`; `static func state(_ input: Input, today: Date, timeZone: TimeZone) -> MembersProfileScreen.State`; `static func age(birthday: String?, today: Date, timeZone: TimeZone) -> String`; `static func leaderShortName(_ name: String?) -> String`; `static func phoneLabel(_ e164: String) -> String`; `static func isComplete(_ program: MemberEngagementProgram) -> Bool` (D14). `struct MemberProfileContainer: View { let memberId: String; let name: String }`.

- [ ] **Step 1: Write the failing tests** — create `iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift`:

```swift
import XCTest
@testable import MakeReady

/// ui2-members-browse T13 (member half): D8 role/org, D9, D10 empties, D12 rail, D14 state,
/// email ?? googleEmail, capitalized gender, "L. Keith", whole hours; F5 loading.
final class MemberProfileMapperTests: XCTestCase {
    private let tz = TimeZone(identifier: "America/Denver")!
    private let today = ISO8601DateFormatter().date(from: "2026-10-25T18:00:00Z")!   // Sun Oct 25, noon MDT

    private func tony(email: String? = nil, isGroupLeader: Bool = true) -> MemberDetail {
        MemberDetail(
            id: "m1", phoneNumber: "+11234567890", phoneVerified: true, firstName: "Tony", lastName: "Stark",
            email: email, googleEmail: "tony@gmail.example", gender: "male", birthday: "1974-06-25T00:00:00.000Z",
            profilePicture: nil, googlePicture: "https://lh3.example/t.jpg", userId: "u1",
            address: "10880 Malibu Point\nMalibu, CA 90265", emergencyContactName: "Pepper Potts",
            emergencyContactPhone: "+11234567891", isGroupLeader: isGroupLeader,
            organizations: [
                MemberDetailOrganization(organizationId: "org2", joinedAt: "2025-03-01T12:00:00.000Z",
                                         organization: MemberOrganizationRef(id: "org2", name: "Grace Church")),
                MemberDetailOrganization(organizationId: "org1", joinedAt: "2026-07-05T14:03:22.123Z",
                                         organization: MemberOrganizationRef(id: "org1", name: "MakeReady"))
            ]
        )
    }

    private func map(_ input: MemberProfileMapper.Input) -> MembersProfileScreen.State {
        MemberProfileMapper.state(input, today: today, timeZone: tz)
    }

    func testIdentityQuickStatsAndFields() {
        let st = map(.init(name: "Tony S.", detail: tony(), organizationId: "org1"))
        XCTAssertEqual(st.memberName, "Tony Stark")                         // the payload wins over the list name
        XCTAssertEqual(st.email, "tony@gmail.example")                      // email ?? googleEmail
        XCTAssertEqual(st.avatarURL, "https://lh3.example/t.jpg")
        XCTAssertEqual(st.initials, "TS")
        XCTAssertEqual(st.age, "52")
        XCTAssertEqual(st.role, "Group leader")                             // D8
        XCTAssertEqual(st.birthday, "Jun 25, 1974")                         // a UTC calendar date — not Jun 24 in Denver
        XCTAssertEqual(st.joined, "Jul 5, 2026")                            // the shell's org's joinedAt
        XCTAssertEqual(st.organization, "Grace Church, MakeReady")          // D8: comma-joined
        XCTAssertEqual(st.phone, "+1 (123) 456-7890")
        XCTAssertTrue(st.phoneVerified)
        XCTAssertEqual(st.gender, "Male")                                   // stored lowercase
        XCTAssertEqual(st.address, "10880 Malibu Point\nMalibu, CA 90265")
        XCTAssertEqual(st.emergencyContactName, "Pepper Potts")
        XCTAssertEqual(st.emergencyContactPhone, "+1 (123) 456-7891")
    }

    func testJoinedFallsBackToTheFirstOrgWhenTheShellOrgIsUnknown() {
        XCTAssertEqual(map(.init(name: "", detail: tony())).joined, "Mar 1, 2025")
    }

    func testEmailPrefersTheMemberEmailAndSkipsAnEmptyOne() {
        XCTAssertEqual(map(.init(name: "", detail: tony(email: "tony@stark.example"))).email, "tony@stark.example")
        XCTAssertEqual(map(.init(name: "", detail: tony(email: ""))).email, "tony@gmail.example")
    }

    func testRoleIsMemberWithoutALedGroup() {
        XCTAssertEqual(map(.init(name: "", detail: tony(isGroupLeader: false))).role, "Member")
    }

    func testAgeAroundTheBirthday() {
        XCTAssertEqual(MemberProfileMapper.age(birthday: "1974-11-02T00:00:00.000Z", today: today, timeZone: tz), "51")
        XCTAssertEqual(MemberProfileMapper.age(birthday: "1974-10-25T00:00:00.000Z", today: today, timeZone: tz), "52")
        XCTAssertEqual(MemberProfileMapper.age(birthday: nil, today: today, timeZone: tz), "")
        XCTAssertEqual(MemberProfileMapper.age(birthday: "garbage", today: today, timeZone: tz), "")
    }

    /// D10: absent values are "" (the row keeps its label); F5: loading shows the list-known name.
    func testLoadingIsTheListNameOverEmptySections() {
        let st = map(.init(name: "Tony Stark"))
        XCTAssertEqual(st.memberName, "Tony Stark")
        XCTAssertEqual(st.initials, "TS")
        for value in [st.email, st.avatarURL, st.age, st.role, st.birthday, st.joined, st.organization,
                      st.phone, st.gender, st.address, st.emergencyContactName, st.emergencyContactPhone] {
            XCTAssertEqual(value, "")
        }
        XCTAssertFalse(st.phoneVerified)
        XCTAssertEqual(st.dayNumbers, [])
        XCTAssertEqual(st.groupTitles, [])
        XCTAssertEqual(st.programTitles, [])
    }

    /// D12: 30 local days, today−29 … today, today the trailing card.
    func testRailIsThirtyDaysEndingToday() {
        let days = [
            HomeDay(day: "2026-10-24", sessionSeconds: 1530, blocks: [0, 0, 0, 0, 600, 0, 930, 0, 0, 0, 0, 0],
                    lastActivityAt: "2026-10-24T13:20:00.000Z"),
            HomeDay(day: "2026-10-23", sessionSeconds: 300, blocks: [0, 0, 0, 0, 0, 0, 0, 300, 0, 0, 0, 0],
                    lastActivityAt: "2026-10-23T20:05:00.000Z")
        ]
        let st = map(.init(name: "Tony Stark", days: days))
        XCTAssertEqual(st.dayNumbers.count, 30)
        XCTAssertEqual(st.dayNumbers.first, "26")
        XCTAssertEqual(st.dayNumbers.last, "25")
        XCTAssertEqual(st.dayMonths.first, "SEP")
        XCTAssertEqual(st.dayMonths.last, "OCT")
        XCTAssertEqual(st.dayWeekdays.first, "SAT")                         // Sep 26, 2026
        XCTAssertEqual(st.dayWeekdays[28], "SAT")                           // Oct 24
        XCTAssertEqual(st.dayWeekdays.last, "")                             // today's card shows no weekday
        XCTAssertEqual(st.dayDateStates.last, "today")
        XCTAssertEqual(st.dayDateStates.filter { $0 == "today" }.count, 1)
        XCTAssertEqual(st.dayLine1s[28], "26 mins")                         // 1530 s = 25.5 → 26
        XCTAssertEqual(st.dayLine2s[28], "7:20 am")                         // local h:mm a
        XCTAssertEqual(st.dayDetailsStates[28], "muted")
        XCTAssertEqual(st.daySeries[28], [0, 0, 0, 0, 10, 0, 15.5, 0, 0, 0, 0, 0])
        XCTAssertEqual(st.dayLine1s[27], "5 mins")
        XCTAssertEqual(st.dayLine2s[27], "2:05 pm")
        XCTAssertEqual(st.dayLine1s[29], "0 mins")                          // today, no sessions
        XCTAssertEqual(st.dayLine2s[29], "")
        XCTAssertEqual(st.dayDetailsStates[29], "nothing")
        XCTAssertEqual(st.daySeries[29], Array(repeating: 0, count: 12))
    }

    func testMembershipRows() {
        let groups = [
            MemberGroupItem(id: "g1", name: "Young professionals", coverImageUrl: "https://cdn.example/g1.jpg",
                            organizationId: "org1", memberCount: 9, joinedAt: "2025-07-03T16:00:00.000Z",
                            creator: MemberGroupCreator(id: "u2", name: "Luke Keith")),
            MemberGroupItem(id: "g2", name: "The kids", joinedAt: "2025-08-05T16:00:00.000Z",
                            creator: MemberGroupCreator(id: "u3", name: "Cher")),
            MemberGroupItem(id: "g3", name: "Orphans", joinedAt: "garbage")
        ]
        let st = map(.init(name: "", groups: groups))
        XCTAssertEqual(st.groupTitles, ["Young professionals", "The kids", "Orphans"])
        XCTAssertEqual(st.groupPhotoURLs, ["https://cdn.example/g1.jpg", "", ""])
        XCTAssertEqual(st.groupLeaders, ["L. Keith", "Cher", ""])
        XCTAssertEqual(st.groupJoinedDates, ["Jul 3, 2025", "Aug 5, 2025", ""])
    }

    /// D14: `Complete` iff totalCount > 0 and completedCount ≥ totalCount — never from percent alone.
    func testEngagementRowsAndTheCompleteRule() {
        let programs = [
            MemberEngagementProgram(enrollmentId: "e1", programId: "p1", title: "Daily Inspiration",
                                    coverImageUrl: "https://cdn.example/p1.jpg", completedCount: 12, totalCount: 30, hours: 15, percent: 68),
            MemberEngagementProgram(enrollmentId: "e2", programId: "p2", title: "Romans in 30 days",
                                    completedCount: 31, totalCount: 31, hours: 92, percent: 100),
            MemberEngagementProgram(enrollmentId: "e3", programId: "p3", title: "Up to date",
                                    completedCount: 10, totalCount: 20, hours: 3, percent: 100),
            MemberEngagementProgram(enrollmentId: "e4", programId: "p4", title: "Not started")
        ]
        let st = map(.init(name: "", engagement: MemberEngagement(programs: programs)))
        XCTAssertEqual(st.programTitles, ["Daily Inspiration", "Romans in 30 days", "Up to date", "Not started"])
        XCTAssertEqual(st.programStates, ["Progress", "Complete", "Progress", "Progress"])
        XCTAssertEqual(st.programProgress, [0.68, 1, 1, 0])
        XCTAssertEqual(st.programCompleteCounts, ["12", "31", "10", "0"])
        XCTAssertEqual(st.programHours, ["15", "92", "3", "0"])
        XCTAssertEqual(st.programCoverURLs, ["https://cdn.example/p1.jpg", "", "", ""])
    }

    func testLeaderShortNameAndPhoneLabel() {
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Luke Keith"), "L. Keith")
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Mary Ann Smith"), "M. Smith")
        XCTAssertEqual(MemberProfileMapper.leaderShortName("Cher"), "Cher")
        XCTAssertEqual(MemberProfileMapper.leaderShortName(nil), "")
        XCTAssertEqual(MemberProfileMapper.phoneLabel("+11234567890"), "+1 (123) 456-7890")
        XCTAssertEqual(MemberProfileMapper.phoneLabel("+447700900123"), "+447700900123")   // non-NANP as stored
        XCTAssertEqual(MemberProfileMapper.phoneLabel(""), "")
    }
}
```

Register it:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReadyCaptureTests", "MemberProfileMapperTests.swift", "MakeReadyCaptureTests"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save'
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL (test target does not compile): "cannot find 'MemberProfileMapper' in scope".

- [ ] **Step 3: Write the minimal implementation** — create `iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift`:

```swift
import Foundation

/// ui2-members-browse D8–D12, D14 + members-profile §2–§3: one member's page from the member
/// stores. Pure. A store never loaded keeps its section empty (D10), and a failed load keeps the
/// last State because the stores are only written on success (F5).
enum MemberProfileMapper {
    private static let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .current

    struct Input {
        /// The list row's name — the header while the page loads (members-profile §3 `loading`).
        var name: String
        var detail: MemberDetail? = nil
        var groups: [MemberGroupItem]? = nil
        var engagement: MemberEngagement? = nil
        var days: [HomeDay]? = nil
        /// The shell's org — whose `joinedAt` the Joined stat shows.
        var organizationId: String? = nil
    }

    static func state(_ input: Input, today: Date, timeZone: TimeZone) -> MembersProfileScreen.State {
        let d = input.detail
        let detailName = MembersHomeMapper.displayName(first: d?.firstName, last: d?.lastName)
        let detailInitials = MembersHomeMapper.initials(first: d?.firstName, last: d?.lastName)
        let rail = rail(input.days, today: today, timeZone: timeZone)
        let groups = input.groups ?? []
        let programs = input.engagement?.programs ?? []
        return MembersProfileScreen.State(
            memberName: detailName.isEmpty ? input.name : detailName,
            // T13: email ?? googleEmail (the `MemberProfile.displayEmail` precedent).
            email: MembersHomeMapper.nonEmpty(d?.email) ?? MembersHomeMapper.nonEmpty(d?.googleEmail) ?? "",
            avatarURL: MembersHomeMapper.nonEmpty(d?.profilePicture) ?? MembersHomeMapper.nonEmpty(d?.googlePicture) ?? "",
            initials: detailInitials.isEmpty ? listInitials(input.name) : detailInitials,
            age: age(birthday: d?.birthday, today: today, timeZone: timeZone),
            role: d.map { $0.isGroupLeader ? "Group leader" : "Member" } ?? "",              // D8
            birthday: d?.birthday.flatMap(MembersHomeMapper.parseDate).map { MembersHomeMapper.mediumDate($0, timeZone: utc) } ?? "",
            joined: joined(d, organizationId: input.organizationId, timeZone: timeZone),
            organization: (d?.organizations ?? [])
                .compactMap { MembersHomeMapper.nonEmpty($0.organization?.name) }
                .joined(separator: ", "),                                                 // D8
            phone: phoneLabel(d?.phoneNumber ?? ""),
            phoneVerified: d?.phoneVerified ?? false,                                     // D9
            gender: capitalized(d?.gender),
            address: d?.address ?? "",
            emergencyContactName: d?.emergencyContactName ?? "",
            emergencyContactPhone: phoneLabel(d?.emergencyContactPhone ?? ""),
            dayMonths: rail.months,
            dayWeekdays: rail.weekdays,
            dayNumbers: rail.numbers,
            dayDateStates: rail.dateStates,
            daySeries: rail.series,
            dayLine1s: rail.line1s,
            dayLine2s: rail.line2s,
            dayDetailsStates: rail.detailsStates,
            groupTitles: groups.map(\.name),
            groupPhotoURLs: groups.map { $0.coverImageUrl ?? "" },
            groupLeaders: groups.map { leaderShortName($0.creator?.name) },
            groupJoinedDates: groups.map { group in
                MembersHomeMapper.parseDate(group.joinedAt).map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? ""
            },
            programTitles: programs.map(\.title),
            programStates: programs.map { isComplete($0) ? "Complete" : "Progress" },    // D14
            programProgress: programs.map { isComplete($0) ? 1 : Double(min(max($0.percent, 0), 100)) / 100 },
            programCompleteCounts: programs.map { "\($0.completedCount)" },
            programHours: programs.map { "\($0.hours)" },                                // D17: whole hours
            programCoverURLs: programs.map { $0.coverImageUrl ?? "" }
        )
    }

    // MARK: - Helpers

    /// D14: finished only when every live lesson is complete — `percent` counts lessons scheduled
    /// TO DATE, so 100% mid-program is not done.
    static func isComplete(_ program: MemberEngagementProgram) -> Bool {
        program.totalCount > 0 && program.completedCount >= program.totalCount
    }

    /// Whole years from the stored birthday (a UTC calendar date) to the caller's today; "" when
    /// there is no birthday (D10).
    static func age(birthday: String?, today: Date, timeZone: TimeZone) -> String {
        guard let birthday, let born = MembersHomeMapper.parseDate(birthday) else { return "" }
        var bornCal = Calendar(identifier: .gregorian)
        bornCal.timeZone = utc
        var todayCal = Calendar(identifier: .gregorian)
        todayCal.timeZone = timeZone
        let b = bornCal.dateComponents([.year, .month, .day], from: born)
        let t = todayCal.dateComponents([.year, .month, .day], from: today)
        guard let by = b.year, let bm = b.month, let bd = b.day,
              let ty = t.year, let tm = t.month, let td = t.day else { return "" }
        let years = ty - by - ((tm, td) < (bm, bd) ? 1 : 0)
        return years >= 0 ? "\(years)" : ""
    }

    /// C-043 `Single` on a group row: "Luke Keith" → "L. Keith" (members-profile §4).
    static func leaderShortName(_ name: String?) -> String {
        let parts = (name ?? "").split(separator: " ").map(String.init)
        guard parts.count > 1, let first = parts.first?.first, let last = parts.last else { return parts.first ?? "" }
        return "\(first). \(last)"
    }

    /// The stored E.164 number as the members-profile frame draws it ("+1 (123) 456-7890") for a
    /// NANP number; any other number as stored.
    static func phoneLabel(_ e164: String) -> String {
        let digits = Array(e164.filter(\.isNumber))
        guard e164.hasPrefix("+1"), digits.count == 11 else { return e164 }
        let n = digits.dropFirst().map { String($0) }
        return "+1 (\(n[0..<3].joined())) \(n[3..<6].joined())-\(n[6..<10].joined())"
    }

    private static func capitalized(_ gender: String?) -> String {
        guard let g = MembersHomeMapper.nonEmpty(gender) else { return "" }
        return g.prefix(1).uppercased() + g.dropFirst()
    }

    private static func listInitials(_ name: String) -> String {
        let words = name.split(separator: " ").map(String.init)
        return MembersHomeMapper.initials(first: words.first, last: words.count > 1 ? words.last : nil)
    }

    /// The Joined stat: this member's `joinedAt` in the shell's org, else their first org.
    private static func joined(_ detail: MemberDetail?, organizationId: String?, timeZone: TimeZone) -> String {
        let orgs = detail?.organizations ?? []
        guard let entry = orgs.first(where: { $0.organizationId == organizationId }) ?? orgs.first,
              let date = MembersHomeMapper.parseDate(entry.joinedAt) else { return "" }
        return MembersHomeMapper.mediumDate(date, timeZone: timeZone)
    }

    struct Rail {
        var months: [String] = []
        var weekdays: [String] = []
        var numbers: [String] = []
        var dateStates: [String] = []
        var series: [[Double]] = []
        var line1s: [String] = []
        var line2s: [String] = []
        var detailsStates: [String] = []
    }

    /// D12: the 30 local days today−29 … today (today trailing); line 1 = session minutes, line 2 =
    /// the last activity's local "h:mm a" (C-071 `Muted`), a zero day the `Nothing` state. Never
    /// loaded (nil) → no cards.
    static func rail(_ days: [HomeDay]?, today: Date, timeZone: TimeZone) -> Rail {
        guard let days else { return Rail() }
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { $1 })
        let todayKey = HomeDashboardMapper.key(today, tz: timeZone)
        var r = Rail()
        for day in HomeDashboardMapper.days(endingAt: today, back: MemberActions.railDays - 1, ahead: 0, tz: timeZone) {
            let data = byDay[day.key]
            let seconds = data?.sessionSeconds ?? 0
            let isToday = day.key == todayKey
            r.months.append(HomeDashboardMapper.shortMonths[day.month - 1].uppercased())
            r.weekdays.append(isToday ? "" : weekdays[day.weekday - 1])
            r.numbers.append("\(day.day)")
            r.dateStates.append(isToday ? "today" : "default")
            r.series.append(HomeDashboardMapper.blockMinutes(data?.blocks))
            r.line1s.append("\(Int((Double(seconds) / 60).rounded())) mins")
            r.line2s.append(seconds > 0 ? (data?.lastActivityAt.flatMap { clockTime($0, timeZone: timeZone) } ?? "") : "")
            r.detailsStates.append(seconds > 0 ? "muted" : "nothing")
        }
        return r
    }

    /// "7:20 am" — `h:mm a` with the members-profile frame's lowercase day-period symbols.
    private static func clockTime(_ iso: String, timeZone: TimeZone) -> String? {
        guard let date = MembersHomeMapper.parseDate(iso) else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f.string(from: date)
    }
}
```

Create `iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift`:

```swift
import SwiftUI

/// ui2-members-browse §iphone Member page: the pushed `.memberDetail` page (D1). It owns its
/// ScrollView (the screen has no root scroll); C-040 back pops its tab's stack. Cache-first for
/// the session (D21): the stores render at once — the list-known name heads the page while it
/// loads (F5) — and four loads refresh them; a failure keeps what is shown.
struct MemberProfileContainer: View {
    let memberId: String
    let name: String

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when program covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0

    var body: some View {
        let app = AppState.shared
        let state = MemberProfileMapper.state(
            .init(name: name, detail: app.memberDetails[memberId], groups: app.memberGroupsById[memberId],
                  engagement: app.memberEngagementById[memberId], days: app.memberDaysById[memberId],
                  organizationId: app.organizationId),
            today: Date(), timeZone: .current
        )
        let _ = coversSeeded
        ScrollView(.vertical) {
            MembersProfileScreen(
                state: state,
                onBack: { navigator.pop() }       // members-profile §3: back pops to the presenter
                // D3/D5: field rows, group rows, program rows, both `add`s and the day cards do
                // nothing in this child — the screen's no-op defaults.
            )
        }
        .scrollIndicators(.hidden)
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await Self.load(memberId: memberId, authManager: authManager) }
        .task(id: state.programCoverURLs) {
            if await Self.seedCovers(state.programCoverURLs) { coversSeeded += 1 }
        }
    }

    @MainActor
    static func load(memberId: String, authManager: AuthManager) async {
        await AppState.shared.loadInitialData()                      // the org for the rail's scope
        let actions = MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MemberProfileContainer.signOut", surface: false)
            }
        })
        async let detail: () = actions.loadMember(memberId)
        async let groups: () = actions.loadMemberGroups(memberId)
        async let engagement: () = actions.loadEngagement(memberId)
        async let days: () = actions.loadMemberDays(memberId)
        _ = await (detail, groups, engagement, days)
    }

    /// C-059 §4 `cover: Image?` is caller-resolved: the screen reads Ui2ImageCache only
    /// (`MembersProfileScreen.cachedImage`), so the page puts each program cover there. A cover
    /// that fails to load keeps C-059's missing-cover box. Returns whether any cover landed.
    @MainActor
    static func seedCovers(_ urls: [String]) async -> Bool {
        var seeded = false
        for raw in urls {
            guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: url) == nil else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    Ui2ImageCache.shared.seed(image, for: url)
                    seeded = true
                }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return seeded }
                AppState.shared.recordError(error, context: "MemberProfileContainer.seedCovers", surface: false)
            }
        }
        return seeded
    }
}
```

In `iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift`, replace the doc comment, the `@Environment(\.ui2Navigator)` property and `body` with:

```swift
/// ui2-members-browse D1: the `.memberDetail` destination of the shell's stacks — the member page.
struct MemberDetailHost: View {
    let id: String
    let name: String

    var body: some View {
        MemberProfileContainer(memberId: id, name: name)
    }
}
```

Register both sources in `MakeReady` and mirror them into `MakeReadyCapture`:

```bash
cd iphone && ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("MakeReady.xcodeproj")
[["MakeReady/UI2", "Containers/Members/MemberProfileMapper.swift", "MakeReady"],
 ["MakeReady/UI2", "Containers/Members/MemberProfileContainer.swift", "MakeReady"]].each do |group, path, target|
  g = p.main_group.find_subpath(group, false) or abort("no group #{group}")
  next if g.files.any? { |f| f.path == path }
  p.targets.find { |t| t.name == target }.add_file_references([g.new_reference(path)])
end
p.save' && ruby scripts/capture-targets.rb && ruby scripts/capture-targets.rb --check
```

- [ ] **Step 4: Run the tests and watch them pass** — `npm run ios:build-check -- --test` → PASS (ten new `MemberProfileMapperTests` plus every earlier case — `UI2ShellModelTests` still routes `.memberDetail` to `MemberDetailHost`); `cd iphone && swiftlint --baseline .swiftlint-baseline.json` → no new violations (no force unwraps in `MakeReady/`: `utc` falls back to `.current`, the phone digits are bounds-checked). The live page against Fixtures (fields, rail, groups, programs), back and edge-swipe pop, and a Group-Leader session's 404 for another group's member (recorded, page keeps the list name) are walk items.

- [ ] **Step 5: Stage and stop for the owner** — `git add iphone/MakeReady/UI2/Containers/Members/MemberProfileMapper.swift iphone/MakeReady/UI2/Containers/Members/MemberProfileContainer.swift iphone/MakeReady/UI2/Containers/Members/MemberDetailHost.swift iphone/MakeReadyCaptureTests/MemberProfileMapperTests.swift iphone/MakeReady.xcodeproj/project.pbxproj`, then STOP and ask the owner to commit with the proposed message `feat(ui2-members-browse): member page pushed live — fields, activity rail, groups, program progress`. Do not run `git commit`.
