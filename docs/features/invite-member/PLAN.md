# invite-member — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** A leader taps TabBar "+" → "Invite a member", picks a group (when they lead 2+), types a name and a 10-digit US number, and sends the existing group-invite SMS; the server stores the invitee's name.

**Architecture:** The server adds a nullable `Invite.recipientName` (accepted by `/send`, returned on leader reads), a `creatorName` on `GET /api/groups`, a Twilio test-mode send and a fixtures layer that seeds the SMS campaigns. The iPhone app hosts the d2m-built `EnrollmentSelectGroupScreen` and `InviteMemberScreen` in two thin containers under `UI2/Containers/Groups/`, pushed onto the selected tab's stack by the shell's Add menu, with a pure mapper and a pure entry decision carrying the logic under test.

**Tech Stack:** server — Express + zod + Prisma (schema YAML → Atlas), vitest + supertest; iphone — SwiftUI, `@Observable` AppState + Actions, XCTest in `MakeReadyCaptureTests`.

**Spec:** `docs/features/invite-member/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. 🔴 You stage your commit and STOP — an iPhone commit is the human's to approve.
- Capture: fixtures are manifest-driven and twins additive-only; register a new twin in the component-capture map and check its BEM root for a collision with a legacy web component before naming it; restart the capture server after editing an adapter, and rebuild the client bundle before any web capture.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test or `/compare` diff, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(invite-member): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal | Gates |
|---|---|---|---|---|
| 1 | server | 1–5 | `recipientName` stored, accepted and returned; `creatorName` on groups; test-mode SMS succeeds; the invite-member fixtures layer seeds the campaigns; contract frozen | `cd server && npx tsc --noEmit` · `cd server && npx tsc --noEmit -p fixtures` · `cd server && npm run test:run` · `cd server && npm run schema:validate` |
| 2 | iphone | 6–7 | `UserGroup.creatorName` decoded; `InviteActions.sendInvite` posts the §Contract body | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 3 | iphone | 8–10 | the shell knows the two invite destinations and the whole-flow pop; the group picker is hosted with real data | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |
| 4 | iphone | 11–13 | the invite page is hosted and sends; the Add-menu row opens the flow; residual sweep proves nothing else points at the old entries | `npm run ios:build-check -- --test` · `cd iphone && swiftlint --baseline .swiftlint-baseline.json` |

---

### Task 1: Invite.recipientName — column, send body, persisted by the service
App: server
Phase: 1
Recipe: `/api` (server endpoint) · SPEC D8, SC1, SC2, T1, T2

**Files:**
- Modify: `server/schema/schema.yaml` (`Invite.fields`, after `recipientPhone`)
- Generated (never hand-edited): `server/prisma/schema.prisma`, `server/atlas/migrations/<new>.sql`, `server/atlas/migrations/atlas.sum`, `server/src/generated/prisma/**`
- Modify: `server/src/services/invite.ts:35-61` (`sendGroupInvite`)
- Modify: `server/src/routes/invites.ts:403-449` (`POST /send`)
- Test: `server/src/routes/__tests__/invites-send-name.request.test.ts` (new)
- Test: `server/src/services/__tests__/invite-recipient-name.test.ts` (new)

**Interfaces:**
- Produces: `sendGroupInvite(groupId, inviterId, inviterName, recipientPhone, groupName, baseUrl, recipientName?: string): Promise<SendInviteResult>` — `recipientName` is the LAST parameter so existing callers are unchanged; `Invite.recipientName: string | null` on the Prisma model.

- [ ] **Step 1: Write the failing route test** — `server/src/routes/__tests__/invites-send-name.request.test.ts`

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  group: { findUnique: vi.fn() },
  member: { findUnique: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/invite.js', () => ({ sendGroupInvite: vi.fn(), getInviteByToken: vi.fn() }))
vi.mock('../../services/permission.js', () => ({ canManageOrgContent: vi.fn() }))
vi.mock('../../services/membership-event.js', () => ({ recordMembershipEvent: vi.fn() }))

import { sendGroupInvite } from '../../services/invite.js'
import { canManageOrgContent } from '../../services/permission.js'
import invitesRoutes from '../invites.js'

const GROUP_ID = '123e4567-e89b-12d3-a456-426614174000'

function appAs(userId: string) {
  const app = express()
  app.use(express.json())
  app.use((req, _res, next) => {
    Object.assign(req, { user: { id: userId, name: 'Leader' }, isAuthenticated: () => true })
    next()
  })
  app.use('/api/invites', invitesRoutes)
  return app
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findUnique.mockResolvedValue({ id: GROUP_ID, name: 'Prayer Team', organizationId: 'org1', creatorId: 'u1' })
  prismaMock.member.findUnique.mockResolvedValue(null)
  vi.mocked(canManageOrgContent).mockResolvedValue(true)
  vi.mocked(sendGroupInvite).mockResolvedValue({ success: true, inviteId: 'inv1', inviteUrl: 'http://x/join' })
})

describe('POST /api/invites/send recipientName (D8)', () => {
  it('passes the trimmed name to the service', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: '  Ada Test  ' })
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ success: true, inviteId: 'inv1', inviteUrl: 'http://x/join', message: 'Invite sent successfully' })
    expect(vi.mocked(sendGroupInvite).mock.calls[0][6]).toBe('Ada Test')
  })

  it('still accepts a body without a name', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123' })
    expect(res.status).toBe(200)
    expect(vi.mocked(sendGroupInvite).mock.calls[0][6]).toBeUndefined()
  })

  it.each([['empty after trim', '   '], ['101 characters', 'a'.repeat(101)]])('rejects a name that is %s', async (_label, name) => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: name })
    expect(res.status).toBe(400)
    expect(res.body.success).toBe(false)
    expect(sendGroupInvite).not.toHaveBeenCalled()
  })

  it('accepts exactly 100 characters', async () => {
    const res = await request(appAs('u1')).post('/api/invites/send')
      .send({ groupId: GROUP_ID, recipientPhone: '+15555550123', recipientName: 'a'.repeat(100) })
    expect(res.status).toBe(200)
  })
})
```

- [ ] **Step 2: Write the failing service test** — `server/src/services/__tests__/invite-recipient-name.test.ts`

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  invite: { create: vi.fn(), delete: vi.fn() },
  group: { findUnique: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../sms-campaign.js', () => ({ sendCampaignSms: vi.fn() }))

import { sendCampaignSms } from '../sms-campaign.js'
import { sendGroupInvite } from '../invite.js'

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.invite.create.mockResolvedValue({ id: 'inv1' })
  prismaMock.group.findUnique.mockResolvedValue({ code: 'ABC123' })
  vi.mocked(sendCampaignSms).mockResolvedValue({ success: true, smsLogId: 's1', messageSid: 'SM1' } as never)
})

describe('sendGroupInvite recipientName (D6, D8)', () => {
  it('writes the name on the invite and leaves the SMS context unchanged', async () => {
    const result = await sendGroupInvite('g1', 'u1', 'Leader', '+15555550123', 'Prayer Team', 'http://app', 'Ada Test')
    expect(result.success).toBe(true)
    expect(prismaMock.invite.create.mock.calls[0][0].data.recipientName).toBe('Ada Test')
    expect(vi.mocked(sendCampaignSms).mock.calls[0][0].context).toEqual({
      'inviter.name': 'Leader',
      'group.name': 'Prayer Team',
      joinUrl: 'http://app/join/group/ABC123?invite=' + prismaMock.invite.create.mock.calls[0][0].data.token,
    })
  })

  it('stores null when no name is given', async () => {
    await sendGroupInvite('g1', 'u1', 'Leader', '+15555550123', 'Prayer Team', 'http://app')
    expect(prismaMock.invite.create.mock.calls[0][0].data.recipientName).toBeNull()
  })
})
```

- [ ] **Step 3: Run them and watch them fail** — `cd server && npx vitest run src/routes/__tests__/invites-send-name.request.test.ts src/services/__tests__/invite-recipient-name.test.ts` → FAIL (the route strips `recipientName`, so `calls[0][6]` is `undefined` and the blank/101-char bodies return 200; the service writes no `recipientName`).

- [ ] **Step 4: Add the column to the schema YAML** — in `server/schema/schema.yaml`, under `Invite.fields`, directly after `recipientPhone`:

```yaml
      recipientName:
        type: string
        nullable: true
```

- [ ] **Step 5: Generate Prisma and the migration** — `cd server && npm run schema:validate && npm run schema:generate && npm run schema:diff && npx prisma generate`. Read the new file under `server/atlas/migrations/`: it must be exactly one `ALTER TABLE "invites" ADD COLUMN "recipientName" ...` (nullable, no default, no backfill — SPEC Data plan). Never edit it by hand.

- [ ] **Step 6: Persist the name in the service** — `server/src/services/invite.ts`:

```ts
export async function sendGroupInvite(
  groupId: string,
  inviterId: string,
  inviterName: string,
  recipientPhone: string,
  groupName: string,
  baseUrl: string,
  recipientName?: string
): Promise<SendInviteResult> {
```

and in the `prisma.invite.create` data, after `recipientPhone,`:

```ts
        recipientName: recipientName ?? null,
```

The `sendCampaignSms` call and its `context` stay exactly as they are (D6).

- [ ] **Step 7: Accept the name in the route** — `server/src/routes/invites.ts` `POST /send`:

```ts
    const sendInviteSchema = z.object({
      groupId: z.string().uuid(),
      recipientPhone: z.string().refine(isValidPhoneNumber, {
        message: 'Invalid phone number format. Must be E.164 format (e.g., +1234567890)',
      }),
      recipientName: z.string().trim().min(1).max(100).optional(),
    });

    const { groupId, recipientPhone, recipientName } = sendInviteSchema.parse(req.body);
```

and pass it as the last argument:

```ts
    const result = await sendGroupInvite(
      groupId,
      user.id,
      user.name,
      recipientPhone,
      group.name,
      baseUrl,
      recipientName
    );
```

Update the route's `@openapi` request body to list `recipientName` (string, 1–100, optional).

- [ ] **Step 8: Run the tests and watch them pass** — `cd server && npx vitest run src/routes/__tests__/invites-send-name.request.test.ts src/services/__tests__/invite-recipient-name.test.ts && npx tsc --noEmit && npm run schema:validate` → PASS

- [ ] **Step 9: Commit** — `feat(invite-member): store the invitee's name on Invite and accept it on /send` (YAML, generated Prisma, migration + atlas.sum, service, route, both tests)

### Task 2: Leader invite reads return recipientName
App: server
Phase: 1
Recipe: `/api` (server endpoint) · SPEC D6, SC3, T3 · tiny

**Files:**
- Modify: `server/src/routes/invites.ts:82-94` (`GET /` map), `:676-684` (`PATCH /:id` response)
- Test: `server/src/routes/__tests__/invites-recipient-name-reads.request.test.ts` (new)

**Interfaces:**
- Consumes: `Invite.recipientName` (Task 1).
- Produces: `GET /api/invites` items and `PATCH /api/invites/:id` `invite` carry `recipientName: string | null`; `GET /api/invites/:token` unchanged.

- [ ] **Step 1: Write the failing test**

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({
  invite: { findMany: vi.fn(), findUnique: vi.fn(), update: vi.fn() },
}))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/invite.js', () => ({ sendGroupInvite: vi.fn(), getInviteByToken: vi.fn() }))
vi.mock('../../services/permission.js', () => ({ canManageOrgContent: vi.fn().mockResolvedValue(true) }))
vi.mock('../../services/membership-event.js', () => ({ recordMembershipEvent: vi.fn() }))

import { getInviteByToken } from '../../services/invite.js'
import invitesRoutes from '../invites.js'

function app(authenticated: boolean) {
  const a = express()
  a.use(express.json())
  a.use((req, _res, next) => {
    Object.assign(req, { user: authenticated ? { id: 'u1' } : undefined, isAuthenticated: () => authenticated })
    next()
  })
  a.use('/api/invites', invitesRoutes)
  return a
}

const created = new Date('2026-10-26T12:00:00Z')
const row = {
  id: 'inv1', token: 'TOK1', groupId: 'g1', inviterId: 'u1', recipientPhone: '+15555550123',
  recipientName: 'Tony Stark', status: 'pending', createdAt: created, expiresAt: null,
  group: { id: 'g1', name: 'Prayer Team', organizationId: 'org1', creatorId: 'u1' },
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.invite.findMany.mockResolvedValue([row])
  prismaMock.invite.findUnique.mockResolvedValue(row)
  prismaMock.invite.update.mockResolvedValue(row)
})

describe('recipientName on leader reads (D6)', () => {
  it('GET /api/invites returns it', async () => {
    const res = await request(app(true)).get('/api/invites')
    expect(res.status).toBe(200)
    expect(res.body.invites[0].recipientName).toBe('Tony Stark')
  })

  it('PATCH /api/invites/:id returns it', async () => {
    const res = await request(app(true)).patch('/api/invites/inv1').send({ status: 'expired' })
    expect(res.status).toBe(200)
    expect(res.body.invite.recipientName).toBe('Tony Stark')
  })

  it('GET /api/invites/:token never returns it', async () => {
    vi.mocked(getInviteByToken).mockResolvedValue({ success: true, invite: { ...row } } as never)
    const res = await request(app(false)).get('/api/invites/TOK1')
    expect(JSON.stringify(res.body)).not.toContain('recipientName')
    expect(JSON.stringify(res.body)).not.toContain('Tony Stark')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/invites-recipient-name-reads.request.test.ts` → FAIL on the first two (`recipientName` undefined). If the `:token` case fails, read `GET /:token` (`invites.ts:751+`): it must build its response from named fields — if it spreads the invite, replace the spread with the fields it returns today minus `recipientName`.

- [ ] **Step 3: Add the field to both leader responses** — in `GET /`'s map, after `recipientPhone: inv.recipientPhone,`:

```ts
        recipientName: inv.recipientName,
```

and in `PATCH /:id`'s `invite` object, after `groupId: updated.groupId,`:

```ts
        recipientName: updated.recipientName,
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/routes/__tests__/invites-recipient-name-reads.request.test.ts && npx tsc --noEmit` → PASS

- [ ] **Step 5: Commit** — `feat(invite-member): leader invite reads return recipientName`

### Task 3: GET /api/groups returns creatorName
App: server
Phase: 1
Recipe: `/api` (server endpoint) · SPEC D9, SC4, T4 · tiny

**Files:**
- Modify: `server/src/routes/groups.ts:240-273` (`GET /`)
- Test: `server/src/routes/__tests__/groups-creator-name.request.test.ts` (new)

**Interfaces:**
- Produces: each `GET /api/groups` group gains `creatorName: string | null` (the creator `User.name`); every existing field unchanged.

- [ ] **Step 1: Write the failing test**

```ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const prismaMock = vi.hoisted(() => ({ group: { findMany: vi.fn() } }))
vi.mock('../../lib/prisma.js', () => ({ prisma: prismaMock, Prisma: {} }))
vi.mock('../../services/permission.js', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../services/permission.js')>()),
  groupManageFilter: vi.fn().mockResolvedValue({ organizationId: 'org1' }),
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

const base = {
  code: 'ABC123', description: null, coverImageUrl: null, isPrivate: false, allowInvites: true,
  memberDirectoryEnabled: true, welcomeMessage: null, ageRangeMin: null, ageRangeMax: null,
  maxMembers: null, _count: { members: 3 }, createdAt: new Date(), updatedAt: new Date(),
}

beforeEach(() => {
  vi.clearAllMocks()
  prismaMock.group.findMany.mockResolvedValue([
    { ...base, id: 'g1', name: 'Prayer Team', creatorId: 'u1', creator: { name: 'Tony Stark' } },
    { ...base, id: 'g2', name: 'Youth', creatorId: 'u2', creator: null },
  ])
})

describe('GET /api/groups creatorName (D9)', () => {
  it('returns the creator name, or null', async () => {
    const res = await request(app()).get('/api/groups')
    expect(res.status).toBe(200)
    expect(res.body.groups.map((g: { creatorName: string | null }) => g.creatorName)).toEqual(['Tony Stark', null])
    expect(res.body.groups[0].creatorId).toBe('u1')
    expect(res.body.groups[0].memberCount).toBe(3)
  })

  it('asks Prisma for the creator name only', async () => {
    await request(app()).get('/api/groups')
    expect(prismaMock.group.findMany.mock.calls[0][0].include.creator).toEqual({ select: { name: true } })
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/routes/__tests__/groups-creator-name.request.test.ts` → FAIL (`creatorName` undefined; `include.creator` undefined). If importing `groups.ts` pulls a module that needs env at import (sharp, storage), add `vi.mock('../../services/storage.js', () => ({ uploadImageVariants: vi.fn() }))` and re-run.

- [ ] **Step 3: Include and map the name** — in `GET /`:

```ts
      include: {
        _count: {
          select: { members: { where: { isActive: true } } },
        },
        creator: { select: { name: true } },
      },
```

and in the response map, after `creatorId: group.creatorId,`:

```ts
      creatorName: group.creator?.name ?? null,
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/routes/__tests__/groups-creator-name.request.test.ts && npx tsc --noEmit` → PASS

- [ ] **Step 5: Commit** — `feat(invite-member): GET /api/groups returns creatorName`

### Task 4: sendSMS succeeds without Twilio in test mode
App: server
Phase: 1
Recipe: `/api` (server, external integration behind its service) · SPEC D17, T9 · tiny

**Files:**
- Modify: `server/src/services/twilio.ts:283-285` (`sendSMS`, the `!twilioClient` branch)
- Test: `server/src/services/__tests__/twilio-test-mode-sms.test.ts` (new)

**Interfaces:**
- Produces: in test mode (`NODE_ENV=test` or `TEST_VERIFICATION_CODES` set) `sendSMS(to, message, opts?)` resolves `{ success: true, messageSid: 'test-<uuid>' }` without a Twilio call; outside test mode unchanged.

- [ ] **Step 1: Write the failing test**

```ts
import { describe, expect, it, vi } from 'vitest'

const twilioFactory = vi.hoisted(() => vi.fn())
vi.mock('twilio', () => ({ default: twilioFactory }))

describe('sendSMS in Twilio test mode (D17)', () => {
  it('returns a test sid and never constructs a Twilio client', async () => {
    vi.stubEnv('NODE_ENV', 'test')
    vi.resetModules()
    const { sendSMS } = await import('../twilio.js')
    const result = await sendSMS('+15555550123', 'hello')
    expect(result.success).toBe(true)
    expect(result.messageSid).toMatch(/^test-[0-9a-f-]{36}$/)
    expect(twilioFactory).not.toHaveBeenCalled()
    vi.unstubAllEnvs()
  })

  it('still rejects a malformed number first', async () => {
    vi.stubEnv('NODE_ENV', 'test')
    vi.resetModules()
    const { sendSMS } = await import('../twilio.js')
    const result = await sendSMS('5555550123', 'hello')
    expect(result.success).toBe(false)
    vi.unstubAllEnvs()
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run src/services/__tests__/twilio-test-mode-sms.test.ts` → FAIL ("Twilio client not initialized (test mode is enabled)").

- [ ] **Step 3: Replace the throw with the test-mode send** — add `import { randomUUID } from 'node:crypto';` at the top of `twilio.ts`, then replace

```ts
    if (!twilioClient) {
      throw new Error('Twilio client not initialized (test mode is enabled)');
    }
```

with

```ts
    // D17: test mode (TEST_VERIFICATION_CODES or NODE_ENV=test) sends nothing — like the
    // verification test codes above — so local and agent-walk envs can send invites.
    if (!twilioClient) {
      const messageSid = `test-${randomUUID()}`;
      console.log(`[Twilio] test mode — SMS not sent to ${to} (${messageSid})`);
      return { success: true, messageSid };
    }
```

- [ ] **Step 4: Run it and watch it pass** — `cd server && npx vitest run src/services/__tests__/twilio-test-mode-sms.test.ts && npm run test:run && npx tsc --noEmit` → PASS. Build-time risk: if any existing suite asserted the old throw, it now fails here — update that assertion to the D17 behaviour in this commit, naming it in the report.

- [ ] **Step 5: Commit** — `feat(invite-member): sendSMS succeeds without Twilio in test mode`

### Task 5: SMS campaign seed module + invite-member fixtures layer; freeze the contract
App: server
Phase: 1
Recipe: `server/fixtures/README.md` (fixtures layers) · SPEC D15, D18, T5, T10

**Files:**
- Create: `server/src/services/sms-campaign-seed.ts`
- Modify: `server/src/scripts/seed-sms-campaigns.ts` (keeps its CLI; the data and upsert move out)
- Modify: `server/fixtures/ids.ts:9-29` (`FIXTURE_KIND` gains `invite: '0014'`)
- Create: `server/fixtures/screens/invite-member.ts`
- Test: `server/fixtures/__tests__/invite-member.test.ts` (new, mocked — always runs)
- Test: `server/fixtures/__tests__/invite-member.db.test.ts` (new, gated on `FIXTURES_TEST_DATABASE_URL` like `shared-edit-field.db.test.ts`)
- Modify: `docs/features/invite-member/MANIFEST.md` (`contract: frozen`)

**Interfaces:**
- Consumes: `Invite.recipientName` (Task 1).
- Produces: `seedSmsCampaigns(prisma: PrismaClient): Promise<void>` and `SMS_CAMPAIGNS` from `server/src/services/sms-campaign-seed.ts`; `INVITE_FIXTURE_RECIPIENT_NAME = 'Tony Stark'` from the layer.

- [ ] **Step 1: Write the failing mocked test** — `server/fixtures/__tests__/invite-member.test.ts`

```ts
import { describe, expect, it, vi } from 'vitest'

vi.mock('../../src/services/sms-campaign-seed.js', () => ({ seedSmsCampaigns: vi.fn().mockResolvedValue(undefined) }))

import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'
import { INVITE_FIXTURE_RECIPIENT_NAME, full } from '../screens/invite-member.js'

describe('invite-member fixtures layer (D15, D18)', () => {
  it('seeds the campaigns first, then one named pending invite on the first base group', async () => {
    const order: string[] = []
    vi.mocked(seedSmsCampaigns).mockImplementation(async () => { order.push('seed') })
    const create = vi.fn(async () => { order.push('invite') })
    const now = new Date('2026-10-26T15:00:00Z')
    await full({ prisma: { invite: { create } }, now, at: (d: number, h: number) => new Date(now.getTime() + d * 86_400_000 + h) } as never)
    expect(order).toEqual(['seed', 'invite'])
    expect(create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        id: fixtureId('invite', 1),
        groupId: FIXTURE_GROUP_IDS[0],
        inviterId: FIXTURE_USER_ID,
        recipientName: INVITE_FIXTURE_RECIPIENT_NAME,
        status: 'pending',
      }),
    })
    expect(INVITE_FIXTURE_RECIPIENT_NAME).toBe('Tony Stark')
  })
})
```

- [ ] **Step 2: Run it and watch it fail** — `cd server && npx vitest run fixtures/__tests__/invite-member.test.ts` → FAIL (module not found).

- [ ] **Step 3: Move the campaigns into a service module** — `server/src/services/sms-campaign-seed.ts`: move the `campaigns` array from `seed-sms-campaigns.ts` verbatim, exported as `SMS_CAMPAIGNS`, and the upsert loop as:

```ts
import type { PrismaClient } from '../generated/prisma/index.js'

/** D18: idempotent — upserts each campaign and template by slug. Used by the CLI script and the
 *  invite-member fixtures layer, so a reset database always has `group-invite-v1`. */
export async function seedSmsCampaigns(prisma: PrismaClient): Promise<void> {
  for (const campaign of SMS_CAMPAIGNS) {
    const upserted = await prisma.smsCampaign.upsert({
      where: { slug: campaign.slug },
      update: { name: campaign.name, description: campaign.description },
      create: { slug: campaign.slug, name: campaign.name, description: campaign.description },
    })
    for (const template of campaign.templates) {
      await prisma.smsTemplate.upsert({
        where: { slug: template.slug },
        update: { body: template.body, requiredProps: template.requiredProps, minIntervalMinutes: template.minIntervalMinutes },
        create: {
          campaignId: upserted.id,
          slug: template.slug,
          body: template.body,
          requiredProps: template.requiredProps,
          minIntervalMinutes: template.minIntervalMinutes,
          version: template.version,
        },
      })
    }
  }
}
```

and reduce `src/scripts/seed-sms-campaigns.ts` to its CLI:

```ts
/**
 * SMS Campaign Seeder — Usage: npx tsx src/scripts/seed-sms-campaigns.ts
 * The campaigns and the idempotent upsert live in services/sms-campaign-seed.ts (D18).
 */
import { PrismaClient } from '../generated/prisma/index.js'
import { SMS_CAMPAIGNS, seedSmsCampaigns } from '../services/sms-campaign-seed.js'

const prisma = new PrismaClient()

seedSmsCampaigns(prisma)
  .then(() => console.log(`Seeded ${SMS_CAMPAIGNS.length} SMS campaigns.`))
  .catch((e) => {
    console.error('Error seeding SMS campaigns:', e)
    process.exit(1)
  })
  .finally(() => prisma.$disconnect())
```

- [ ] **Step 4: Add the fixture id kind** — in `server/fixtures/ids.ts` `FIXTURE_KIND`, after `mediaUsage: '0013',`:

```ts
  invite: '0014',
```

- [ ] **Step 5: Write the layer** — `server/fixtures/screens/invite-member.ts`

```ts
/**
 * invite-member layer (invite-member D15, D18): the invite flow's walkable world.
 *  - D18: seeds the SMS campaigns first, so `POST /api/invites/send` finds `group-invite-v1` in a
 *    freshly reset database (no migration or seed creates SMS templates).
 *  - D15: one pending invite with `recipientName` on the first base group, sent by the Fixtures
 *    user, so `GET /api/invites` returns a named row. Base's 3+ groups make the group picker show.
 * Creates no org, user or group; the invite is removed with its group by wipe.ts (cascade).
 */
import { seedSmsCampaigns } from '../../src/services/sms-campaign-seed.js'
import type { FixtureContext } from '../context.js'
import { FIXTURE_GROUP_IDS, FIXTURE_USER_ID, fixtureId } from '../ids.js'

export const INVITE_FIXTURE_RECIPIENT_NAME = 'Tony Stark'
/** 555-01xx is reserved for fiction; never a real handset. */
export const INVITE_FIXTURE_PHONE = '+15555550199'

export async function full(ctx: FixtureContext): Promise<void> {
  await seedSmsCampaigns(ctx.prisma)
  await ctx.prisma.invite.create({
    data: {
      id: fixtureId('invite', 1),
      token: 'FIXTUREINV1',
      groupId: FIXTURE_GROUP_IDS[0],
      inviterId: FIXTURE_USER_ID,
      recipientPhone: INVITE_FIXTURE_PHONE,
      recipientName: INVITE_FIXTURE_RECIPIENT_NAME,
      status: 'pending',
      createdAt: ctx.at(-1, 10),
      expiresAt: ctx.at(6, 10),
    },
  })
}
```

(`ctx.at(dayOffset, hour)` — read its doc in `fixtures/context.ts:153` and use the sign that puts `createdAt` one day in the past and `expiresAt` six days in the future.)

- [ ] **Step 6: Write the gated DB test** — `server/fixtures/__tests__/invite-member.db.test.ts`, copying `shared-edit-field.db.test.ts`'s harness (`openFixturesDb`, `db.run('reset', 'full')`, `describe.skipIf(!TEST_DB_URL)`), asserting:

```ts
  it('has the group-invite template and one named invite', async () => {
    const template = await db.prisma.smsTemplate.findUnique({ where: { slug: 'group-invite-v1' } })
    expect(template?.minIntervalMinutes).toBe(1200)
    const invites = await db.prisma.invite.findMany({ where: { recipientName: 'Tony Stark' } })
    expect(invites).toHaveLength(1)
    expect(invites[0].groupId).toBe(FIXTURE_GROUP_IDS[0])
  })
```

- [ ] **Step 7: Run them and watch them pass** — `cd server && npx vitest run fixtures/__tests__/invite-member.test.ts fixtures/__tests__/invite-member.db.test.ts fixtures/__tests__/runner.test.ts && npx tsc --noEmit -p fixtures && npx tsc --noEmit && npm run test:run` → PASS (the DB test prints its skip line when `FIXTURES_TEST_DATABASE_URL` is unset).

- [ ] **Step 8: Commit** — `feat(invite-member): fixtures layer seeds SMS campaigns and a named invite`

- [ ] **Step 9: Freeze the contract** — once Phase 1's gates are green: `node <builder>/scripts/advance.mjs docs/features/invite-member --set "contract=frozen <YYYY-MM-DD>" --head --commit "docs(invite-member): contract frozen"`. No iphone task starts before this line reads `frozen`.

### Task 6: UserGroup.creatorName
App: iphone
Phase: 2
Recipe: iphone/.claude/CLAUDE.md §State Management · SPEC D9, T6 · tiny

**Files:**
- Modify: `iphone/MakeReady/State/Models/GroupModels.swift:17-80` (`UserGroup`)
- Test: `iphone/MakeReadyCaptureTests/ModelDecodingTests.swift` (add two tests)

**Interfaces:**
- Produces: `UserGroup.creatorName: String?`; memberwise `init(…, creatorId:, creatorName: String? = nil, createdAt:, updatedAt:)`.

- [ ] **Step 1: Write the failing tests** — append to `ModelDecodingTests`:

```swift
    // invite-member D9: GET /api/groups' creatorName, optional for released-build caches.
    private func groupJSON(creatorName: String?) -> Data {
        let name = creatorName.map { #","creatorName":"\#($0)""# } ?? ""
        return Data(#"{"id":"g1","code":"ABC123","name":"Prayer Team","isPrivate":false,"allowInvites":true,"memberCount":3,"creatorId":"u1","createdAt":"2026-10-26T12:00:00.000Z","updatedAt":"2026-10-26T12:00:00.000Z"\#(name)}"#.utf8)
    }

    func testUserGroupDecodesCreatorName() throws {
        let group = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: groupJSON(creatorName: "Tony Stark"))
        XCTAssertEqual(group.creatorName, "Tony Stark")
    }

    func testUserGroupWithoutCreatorNameDecodesNil() throws {
        let group = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: groupJSON(creatorName: nil))
        XCTAssertNil(group.creatorName)
        let roundTrip = try JSONDecoder.apiDecoder.decode(UserGroup.self, from: JSONEncoder.apiEncoder.encode(group))
        XCTAssertNil(roundTrip.creatorName)
    }
```

(If `JSONEncoder.apiEncoder` does not exist, use the encoder `StatePersistence` uses — grep `JSONEncoder` in `State/Persistence/StatePersistence.swift`.)

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile (`creatorName` is not a member of `UserGroup`).

- [ ] **Step 3: Add the property** — in `UserGroup`, after `let creatorId: String`:

```swift
    /// invite-member D9: the creator's `User.name` from `GET /api/groups`; nil on an old cache.
    var creatorName: String?
```

in `init(from:)`, after `creatorId = …`:

```swift
        creatorName = try container.decodeIfPresent(String.self, forKey: .creatorName)
```

and in the memberwise init add `creatorName: String? = nil` after `creatorId: String,` with `self.creatorName = creatorName`.

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 5: Commit** — `feat(invite-member): UserGroup decodes creatorName`

### Task 7: InviteActions.sendInvite
App: iphone
Phase: 2
Recipe: `/ios-error-surface` · SPEC D5, D8, §Contract `POST /api/invites/send`, T7

**Files:**
- Modify: `iphone/MakeReady/State/Actions/InviteActions.swift` (add `sendInvite`)
- Create: `iphone/MakeReadyCaptureTests/InviteActionsTests.swift` (add to the `MakeReadyCaptureTests` target the way `UI2ShellModelTests.swift` is: one PBXFileReference, one PBXBuildFile, the group child and the Sources phase entry — grep its four lines in `project.pbxproj`; then `ruby iphone/scripts/capture-targets.rb --check` exits 0)

**Interfaces:**
- Produces: `@MainActor func sendInvite(groupId: String, recipientPhone: String, recipientName: String) async throws -> String` — returns the invite id; throws `APIError.serverError(<server error>)` on `success == false`; writes nothing to `AppState` (D5).

- [ ] **Step 1: Write the failing test** — `InviteActionsTests.swift`

```swift
import XCTest
@testable import MakeReady

/// invite-member T7: sendInvite posts the §Contract body and maps the server's failure.
@MainActor
final class InviteActionsTests: XCTestCase {
    private var api: StubAPIClient!

    override func setUp() {
        super.setUp()
        api = StubAPIClient()
    }

    func testPostsTheContractBodyAndReturnsTheInviteId() async throws {
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"inv1","inviteUrl":"http://x","message":"Invite sent successfully"}"#)
        let id = try await InviteActions(api: api).sendInvite(groupId: "g1", recipientPhone: "+15555550123", recipientName: "Ada Test")
        XCTAssertEqual(id, "inv1")
        let body = try XCTUnwrap(api.calls.first?.body)
        XCTAssertEqual(body["groupId"] as? String, "g1")
        XCTAssertEqual(body["recipientPhone"] as? String, "+15555550123")
        XCTAssertEqual(body["recipientName"] as? String, "Ada Test")
        XCTAssertEqual(body.count, 3)
    }

    func testSuccessFalseThrowsTheServerError() async {
        api.stub("POST", "/api/invites/send", json: #"{"success":false,"error":"Rate limited"}"#)
        do {
            _ = try await InviteActions(api: api).sendInvite(groupId: "g1", recipientPhone: "+15555550123", recipientName: "Ada")
            XCTFail("expected a throw")
        } catch APIError.serverError(let message) {
            XCTAssertEqual(message, "Rate limited")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile (`sendInvite` not found).

- [ ] **Step 3: Add the Action** — in `InviteActions`, after `createInvite`:

```swift
    // MARK: - SMS invite (invite-member)

    /// invite-member T7: `POST /api/invites/send` — the existing group-invite SMS, carrying the
    /// invitee's name (D8). Returns the created invite's id. D5: no AppState write — no screen
    /// reads invites yet.
    @MainActor
    func sendInvite(groupId: String, recipientPhone: String, recipientName: String) async throws -> String {
        struct SendInviteResponse: Codable {
            let success: Bool
            let inviteId: String?
            let error: String?
        }

        let response: SendInviteResponse = try await api.post(
            "/api/invites/send",
            body: ["groupId": groupId, "recipientPhone": recipientPhone, "recipientName": recipientName],
            responseType: SendInviteResponse.self
        )

        guard response.success, let inviteId = response.inviteId else {
            throw APIError.serverError(response.error ?? "Couldn't send the invite")
        }
        return inviteId
    }
```

- [ ] **Step 4: Run it and watch it pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 5: Commit** — `feat(invite-member): InviteActions.sendInvite`

### Task 8: The invite destinations and the whole-flow pop
App: iphone
Phase: 3
Recipe: `/push-page` · SPEC D2, D11, F6

**Files:**
- Modify: `iphone/MakeReady/UI2/Shell/UI2ShellModel.swift` (`UI2Destination` cases; `popTo(depth:on:)`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Navigation.swift` (`UI2Navigator.popTo`, `depth`)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`stack(for:)` navigator; `page(for:)` maps the two cases to `EmptyPage()` until Tasks 10 and 11 replace them)
- Test: `iphone/MakeReadyCaptureTests/UI2ShellModelTests.swift`

**Interfaces:**
- Produces: `UI2Destination.inviteSelectGroup(returnDepth: Int)`, `UI2Destination.inviteMember(groupId: String, returnDepth: Int)`; `UI2ShellModel.popTo(depth: Int, on: TabBar.Tab)`; `UI2Navigator.popTo: (Int) -> Void` and `UI2Navigator.depth: () -> Int` (the tab's current path count). `returnDepth` is the stack depth when "+" was tapped — D11's whole-flow pop target.

- [ ] **Step 1: Write the failing tests** — append to `UI2ShellModelTests`:

```swift
    // MARK: - invite-member D11: the whole-flow pop

    func testPopToDepthDropsEveryInvitePageAboveTheEntry() {
        var m = UI2ShellModel()
        m.push(tony, on: .home)                                         // depth 1 when "+" is tapped
        m.push(.inviteSelectGroup(returnDepth: 1), on: .home)
        m.push(.inviteMember(groupId: "g1", returnDepth: 1), on: .home)
        m.popTo(depth: 1, on: .home)
        XCTAssertEqual(m.path(for: .home), [tony])
    }

    func testPopToDepthAtOrAboveTheCountIsANoOp() {
        var m = UI2ShellModel()
        m.push(.inviteMember(groupId: "g1", returnDepth: 0), on: .calendar)
        m.popTo(depth: 3, on: .calendar)
        XCTAssertEqual(m.path(for: .calendar), [.inviteMember(groupId: "g1", returnDepth: 0)])
        m.popTo(depth: 0, on: .calendar)
        XCTAssertEqual(m.path(for: .calendar), [])
        m.popTo(depth: -1, on: .calendar)                               // never negative
        XCTAssertEqual(m.path(for: .calendar), [])
    }
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile.

- [ ] **Step 3: Add the cases and `popTo`** — `UI2ShellModel.swift`:

```swift
enum UI2Destination: Hashable {
    case memberDetail(id: String, name: String)
    case editMemberField(memberId: String, field: MemberField)
    /// invite-member D2/D3: the group pick before the invite (2+ groups). `returnDepth` = the
    /// stack depth when "+" was tapped (D11).
    case inviteSelectGroup(returnDepth: Int)
    /// invite-member D1/D2: the invite page for one group.
    case inviteMember(groupId: String, returnDepth: Int)
}
```

and in `UI2ShellModel`:

```swift
    /// invite-member D11: Cancel / Done pop the whole flow back to the page "+" was tapped on.
    mutating func popTo(depth: Int, on tab: TabBar.Tab) {
        let path = path(for: tab)
        guard depth < path.count else { return }
        paths[tab] = Array(path.prefix(max(0, depth)))
    }
```

- [ ] **Step 4: Extend the navigator** — `UI2Navigation.swift`:

```swift
struct UI2Navigator {
    var push: (UI2Destination) -> Void = { _ in }
    var pop: () -> Void = {}
    /// ui2-members-edit D13: pop only if `destination` is still on top.
    var popIfTop: (UI2Destination) -> Void = { _ in }
    /// invite-member D11: pop the stack back to `depth` entries.
    var popTo: (Int) -> Void = { _ in }
    /// invite-member D11: the stack's current depth (the entry depth a flow returns to).
    var depth: () -> Int = { 0 }
}
```

and in `UI2Shell.stack(for:)` add to the `UI2Navigator(...)`:

```swift
            popIfTop: { model.popIfTop($0, on: tab) },
            popTo: { model.popTo(depth: $0, on: tab) },
            depth: { model.path(for: tab).count }
```

and in `page(for:)`:

```swift
        case .inviteSelectGroup: EmptyPage()      // invite-member: InviteSelectGroupContainer (Task 10)
        case .inviteMember: EmptyPage()           // invite-member: InviteMemberContainer (Task 11)
```

- [ ] **Step 5: Run them and watch them pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 6: Commit** — `feat(invite-member): invite destinations and the whole-flow pop`

### Task 9: InviteSelectGroupMapper — the picker's state from AppState
App: iphone
Phase: 3
Recipe: iphone/.claude/CLAUDE.md §State Management · SPEC D3, D14, D16, Alignment table

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupMapper.swift` (add to BOTH the MakeReady and MakeReadyCapture targets the way `MemberFieldEditContainer.swift` is — grep its PBXFileReference (`path = Containers/Members/…`), its two PBXBuildFile lines, its group child and its two Sources entries in `project.pbxproj`; a new `Groups` group sits beside `Members`; then `ruby iphone/scripts/capture-targets.rb --check` exits 0)
- Create: `iphone/MakeReadyCaptureTests/InviteSelectGroupMapperTests.swift` (MakeReadyCaptureTests target, as in Task 7)

**Interfaces:**
- Consumes: `UserGroup.creatorName` (Task 6).
- Produces:

```swift
enum InviteSelectGroupMapper {
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]   // groupId → AppState.enrollmentsFor(groupId:).count
        var query: String
        var leader: String?                   // the chosen Leaders option, nil = all
        var loading: Bool
        var failed: Bool
    }
    struct Output {
        var state: EnrollmentSelectGroupScreen.State
        var groupIds: [String]                // row index → group id, the visible rows
        var leaderOptions: [String]           // distinct non-empty creator names, A→Z
    }
    static func output(_ input: Input) -> Output
}
```

- [ ] **Step 1: Write the failing tests** — `InviteSelectGroupMapperTests.swift`

```swift
import XCTest
@testable import MakeReady

/// invite-member D3/D14/D16: the picker rows, chips, search and Leaders filter, all local.
final class InviteSelectGroupMapperTests: XCTestCase {
    private func group(_ id: String, _ name: String, leader: String?, members: Int, cover: String? = nil) -> UserGroup {
        UserGroup(id: id, code: "C\(id)", name: name, coverImageUrl: cover, isPrivate: false, allowInvites: false,
                  memberCount: members, creatorId: "u-\(id)", creatorName: leader, createdAt: Date(), updatedAt: Date())
    }

    private var groups: [UserGroup] {
        [group("g1", "youth night", leader: "Tony Stark", members: 4),
         group("g2", "Prayer Team", leader: "Pepper Potts", members: 14, cover: "https://img/p.jpg"),
         group("g3", "Men's Study", leader: nil, members: 0)]
    }

    private func input(query: String = "", leader: String? = nil) -> InviteSelectGroupMapper.Input {
        .init(groups: groups, enrollmentCounts: ["g2": 2], query: query, leader: leader, loading: false, failed: false)
    }

    func testRowsAreAlphabeticalWithEveryChip() {
        let out = InviteSelectGroupMapper.output(input())
        XCTAssertEqual(out.state.groupNames, ["Men's Study", "Prayer Team", "youth night"])
        XCTAssertEqual(out.groupIds, ["g3", "g2", "g1"])
        XCTAssertEqual(out.state.groupLeaderNames, ["", "Pepper Potts", "Tony Stark"])
        XCTAssertEqual(out.state.groupMemberCounts, [0, 14, 4])
        XCTAssertEqual(out.state.groupEnrollmentCounts, [0, 2, 0])
        XCTAssertEqual(out.state.groupPhotoURLs, ["", "https://img/p.jpg", ""])
        XCTAssertEqual(out.state.selectedIndex, -1)
        XCTAssertFalse(out.state.orgFilterVisible)                      // D16
        XCTAssertEqual(out.state.leaderFilterLabel, "Leaders")
        XCTAssertEqual(out.state.orgFilterLabel, "Orgs")
    }

    func testSearchFiltersByNameCaseInsensitively() {
        let out = InviteSelectGroupMapper.output(input(query: "PRAY"))
        XCTAssertEqual(out.groupIds, ["g2"])
        XCTAssertEqual(out.state.searchText, "PRAY")
    }

    func testLeaderFilterNarrowsAndLabelsTheChip() {
        let out = InviteSelectGroupMapper.output(input(leader: "Tony Stark"))
        XCTAssertEqual(out.groupIds, ["g1"])
        XCTAssertEqual(out.state.leaderFilterLabel, "Tony Stark")
    }

    func testLeaderOptionsAreDistinctNonEmptyAndSorted() {
        let more = groups + [group("g4", "Alpha", leader: "Tony Stark", members: 1)]
        let out = InviteSelectGroupMapper.output(.init(groups: more, enrollmentCounts: [:], query: "", leader: nil, loading: false, failed: false))
        XCTAssertEqual(out.leaderOptions, ["Pepper Potts", "Tony Stark"])
    }

    func testLoadingAndFailedPassThrough() {
        var i = input()
        i.loading = true
        i.failed = true
        let out = InviteSelectGroupMapper.output(i)
        XCTAssertTrue(out.state.loading)
        XCTAssertTrue(out.state.failed)
    }
}
```

- [ ] **Step 2: Run them and watch them fail** — `npm run ios:build-check -- --test` → FAIL to compile.

- [ ] **Step 3: Write the mapper** — `InviteSelectGroupMapper.swift`

```swift
import Foundation

/// invite-member D3/D14/D16: AppState's groups → `EnrollmentSelectGroupScreen.State`. Every
/// group `GET /api/groups` returns is listed (D14), A→Z by name; search and the Leaders filter
/// narrow it locally; the Orgs chip never shows (D16). Pure — the container owns the inputs.
enum InviteSelectGroupMapper {
    struct Input {
        var groups: [UserGroup]
        var enrollmentCounts: [String: Int]
        var query: String
        var leader: String?
        var loading: Bool
        var failed: Bool
    }

    struct Output {
        var state: EnrollmentSelectGroupScreen.State
        var groupIds: [String]
        var leaderOptions: [String]
    }

    static let restingLeaderLabel = "Leaders"
    static let restingOrgLabel = "Orgs"

    static func output(_ input: Input) -> Output {
        let query = input.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = input.groups
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .filter { input.leader == nil || $0.creatorName == input.leader }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let leaderOptions = Set(input.groups.compactMap { $0.creatorName }.filter { !$0.isEmpty })
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let state = EnrollmentSelectGroupScreen.State(
            searchText: input.query,
            orgFilterVisible: false,
            orgFilterLabel: restingOrgLabel,
            leaderFilterLabel: input.leader ?? restingLeaderLabel,
            groupNames: rows.map(\.name),
            groupPhotoURLs: rows.map { $0.coverImageUrl ?? "" },
            groupLeaderNames: rows.map { $0.creatorName ?? "" },
            groupMemberCounts: rows.map(\.memberCount),
            groupEnrollmentCounts: rows.map { input.enrollmentCounts[$0.id] ?? 0 },
            selectedIndex: -1,
            loading: input.loading,
            failed: input.failed
        )
        return Output(state: state, groupIds: rows.map(\.id), leaderOptions: leaderOptions)
    }
}
```

- [ ] **Step 4: Run them and watch them pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 5: Commit** — `feat(invite-member): group-picker mapper`

### Task 10: InviteSelectGroupContainer — host the picker
App: iphone
Phase: 3
Recipe: `/present-overlay` (the C-036 Leaders menu through the shell's overlay host) · SPEC D3, D11, D16, T8, F8

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/InviteSelectGroupContainer.swift` (both targets, as Task 9)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`page(for:)` `.inviteSelectGroup`)

**Interfaces:**
- Consumes: `InviteSelectGroupMapper` (Task 9); `UI2Destination.inviteSelectGroup(returnDepth:)`, `.inviteMember(groupId:returnDepth:)`, `UI2Navigator.push/pop` (Task 8); `EnrollmentActions(api:state:).loadEnrollments(groupId:)`.
- Produces: `InviteSelectGroupContainer(returnDepth: Int)`.

- [ ] **Step 1: Re-capture the reused screen (F8)** — `node capture/runners/ui2/capture.mjs enrollment-select-group` (the named carve-out runner); read its diff line. A diff the d2m run did not have is reported, not "fixed": `MakeReadyUI/**` is frozen. If the capture server is not up, say so in the report and continue.

- [ ] **Step 2: Write the container** — `InviteSelectGroupContainer.swift`

```swift
import SwiftUI

/// invite-member D3: the group pick before the invite, for a leader of 2+ groups. Hosts the
/// d2m-built `EnrollmentSelectGroupScreen` unchanged; rows come from AppState (D14), search and
/// the Leaders filter are local UI state, the Orgs chip never shows (D16). T8: each listed group's
/// enrollments load in the background so the third chip fills in as they land.
struct InviteSelectGroupContainer: View {
    let returnDepth: Int

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leader: String?
    @State private var leaderMenuOpen = false

    var body: some View {
        let app = AppState.shared
        let groups = app.groups.all
        let output = InviteSelectGroupMapper.output(.init(
            groups: groups,
            enrollmentCounts: Dictionary(uniqueKeysWithValues: groups.map { ($0.id, app.enrollmentsFor(groupId: $0.id).count) }),
            query: query,
            leader: leader,
            loading: groups.isEmpty && app.loadingStates.isLoading(.groups),
            failed: false
        ))
        EnrollmentSelectGroupScreen(
            state: output.state,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard output.groupIds.indices.contains(index) else { return }
                navigator.push(.inviteMember(groupId: output.groupIds[index], returnDepth: returnDepth))
            },
            onSearch: { query = $0 },
            onOpenLeaderFilter: { leaderMenuOpen = true }
        )
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0, label: $0) },
                selectionMode: .single,
                selectedIDs: leader.map { [$0] } ?? [],
                onSelect: { option in
                    leader = (leader == option.id) ? nil : option.id   // re-tapping the chosen leader clears it
                    leaderMenuOpen = false
                },
                onClose: { leaderMenuOpen = false }
            )
        }
        .task { await Self.loadEnrollmentCounts(for: groups.map(\.id)) }
    }

    /// T8: no list endpoint carries an enrollment count, so each group without cached
    /// enrollments loads its own, concurrently. Background: failures stay console-only.
    @MainActor
    static func loadEnrollmentCounts(for groupIds: [String], state: AppState = .shared) async {
        let missing = groupIds.filter { !state.groupEnrollmentIndex.hasChildren($0) }
        await withTaskGroup(of: Void.self) { tasks in
            for id in missing {
                tasks.addTask { @MainActor in
                    do {
                        _ = try await EnrollmentActions(state: state).loadEnrollments(groupId: id)
                    } catch {
                        state.recordError(error, context: "InviteSelectGroupContainer.loadEnrollmentCounts")
                    }
                }
            }
        }
    }
}
```

Check two names against the code before compiling: `app.loadingStates.isLoading(.groups)` (grep `LoadingStateManager.swift` for the real query — use it), and `EnrollmentActions(api:state:)`'s `state` parameter (`EnrollmentActions.swift:26`).

- [ ] **Step 3: Write the failing test for the background load** — append to `InviteSelectGroupMapperTests.swift`:

```swift
@MainActor
final class InviteSelectGroupEnrollmentLoadTests: XCTestCase {
    func testLoadsOnlyGroupsWithoutCachedEnrollments() async {
        StatePersistence.shared.clear()
        let state = AppState()
        state.groupEnrollmentIndex.add(parentId: "g1", childId: "e1")
        let api = StubAPIClient()
        api.stub("GET", "/api/groups/g2/enrollments", json: #"{"success":true,"enrollments":[]}"#)
        await InviteSelectGroupContainer.loadEnrollmentCounts(for: ["g1", "g2"], state: state, api: api)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g1/enrollments"), 0)
        XCTAssertEqual(api.callCount("GET", "/api/groups/g2/enrollments"), 1)
    }
}
```

and give `loadEnrollmentCounts` an `api: APIClientProtocol = APIClient.shared` parameter passed to `EnrollmentActions(api: api, state: state)`. Read `EnrollmentActions.loadEnrollments` for the exact endpoint and response shape it decodes and make the stub match it.

- [ ] **Step 4: Run it and watch it fail, then pass** — `npm run ios:build-check -- --test` → FAIL before the `api:` parameter exists; PASS after.

- [ ] **Step 5: Map the destination** — in `UI2Shell.page(for:)`:

```swift
        case let .inviteSelectGroup(returnDepth): InviteSelectGroupContainer(returnDepth: returnDepth)  // invite-member D3
```

- [ ] **Step 6: Gates** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 7: Commit** — `feat(invite-member): host the group picker for the invite flow`

### Task 11: InviteMemberContainer — host the invite page and send
App: iphone
Phase: 4
Recipe: `/ios-error-surface` · SPEC D1, D4, D7, D10, D11, F2, F8

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/InviteMemberContainer.swift` (both targets, as Task 9)
- Create: `iphone/MakeReadyCaptureTests/InviteMemberSendTests.swift` (MakeReadyCaptureTests target)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift` (`page(for:)` `.inviteMember`)

**Interfaces:**
- Consumes: `InviteActions.sendInvite` (Task 7); `UI2Navigator.pop/popTo` (Task 8); `InviteMemberScreen` with D7's two additions.
- Produces: `InviteMemberContainer(groupId: String, returnDepth: Int)`; `InviteMemberSend.run(groupId:name:phone:actions:state:) async -> Bool`.

- [ ] **Step 1: Check D7 has landed (F2)** — read `iphone/MakeReadyUI/Screens/Groups/InviteMemberScreen.swift`. It must have (a) an input that hides View invite (default showing) and (b) adoption of a later `State.step` change (an `onChange(of: state.step)` or equivalent). (Landed 2026-10-26 in place — `showsViewInvite:` and `.onChange(of: state.step)`, D7 superseded.) Either missing → STOP this task and report `BLOCKED: D7 not landed`. Do not edit `MakeReadyUI/**`, and do not work around it with `.id(...)` (D7 rejected that).

- [ ] **Step 2: Re-capture the screen (F8)** — `node capture/runners/ui2/capture.mjs invite-member`; report any diff the d2m run did not have. Capture server down → say so and continue.

- [ ] **Step 3: Write the failing test** — `InviteMemberSendTests.swift`

```swift
import XCTest
@testable import MakeReady

/// invite-member D10: a failed send records a surfaced error with the server's message and
/// reports false (the screen stays on step 2); success reports true.
@MainActor
final class InviteMemberSendTests: XCTestCase {
    func testSuccessReturnsTrueAndRecordsNothing() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("POST", "/api/invites/send", json: #"{"success":true,"inviteId":"inv1"}"#)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada Test", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertTrue(ok)
        XCTAssertNil(state.activeSurfacedError)
    }

    func testFailureSurfacesTheServerMessage() async {
        let state = AppState()
        let api = StubAPIClient()
        api.stub("POST", "/api/invites/send", json: #"{"success":false,"error":"Rate limited: try later"}"#)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.activeSurfacedError?.friendlyMessage, "Rate limited: try later")
    }

    func testANonServerFailureUsesTheFallbackCopy() async {
        let state = AppState()
        let api = StubAPIClient()
        api.errorToThrow = URLError(.notConnectedToInternet)
        let ok = await InviteMemberSend.run(groupId: "g1", name: "Ada", phone: "+15555550123",
                                            actions: InviteActions(api: api), state: state)
        XCTAssertFalse(ok)
        XCTAssertEqual(state.activeSurfacedError?.friendlyMessage, "Couldn't send the invite")
    }
}
```

(Read `AppState.recordError` / `AppError` for the real name of the surfaced error's message property and use it in the assertions.)

- [ ] **Step 4: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile.

- [ ] **Step 5: Write the container** — `InviteMemberContainer.swift`. The two D7 inputs are written here as `showsViewInvite:` and a `State.step` the screen adopts — use the names the landed d2m update actually gives them.

```swift
import SwiftUI

/// invite-member D10: the send and its error routing, apart from the view so it is testable.
enum InviteMemberSend {
    static let fallbackMessage = "Couldn't send the invite"

    @MainActor
    static func run(groupId: String, name: String, phone: String,
                    actions: InviteActions = InviteActions(), state: AppState = .shared) async -> Bool {
        do {
            _ = try await actions.sendInvite(groupId: groupId, recipientPhone: phone, recipientName: name)
            return true
        } catch {
            let serverMessage: String? = { if case APIError.serverError(let m) = error { return m } else { return nil } }()
            state.recordError(error, context: "InviteMemberContainer.send", surface: true,
                              friendlyMessage: serverMessage ?? fallbackMessage)
            return false
        }
    }
}

/// invite-member D1: hosts the d2m-built `InviteMemberScreen` for one group. Owns the send's
/// in-flight flag and moves the screen to `sent` after a successful send (D7b); View invite is
/// hidden (D4, D7a). Exits per D11: Cancel / Done / step-3 back pop the whole flow to
/// `returnDepth`; step-1 back pops one page.
struct InviteMemberContainer: View {
    let groupId: String
    let returnDepth: Int

    @Environment(\.ui2Navigator) private var navigator
    @State private var step = "name"
    @State private var sentName = ""
    @State private var sentDigits = ""
    @State private var sending = false

    var body: some View {
        InviteMemberScreen(
            state: .init(step: step, inviteeName: sentName, digits: sentDigits, sending: sending),
            showsViewInvite: false,
            onBack: { navigator.pop() },
            onCancel: { navigator.popTo(returnDepth) },
            onSendInvite: { name, phone in send(name: name, phone: phone) },
            onDone: { navigator.popTo(returnDepth) }
        )
    }

    private func send(name: String, phone: String) {
        guard !sending else { return }                          // §3 sending: one request in flight
        sending = true
        Task { @MainActor in
            let ok = await InviteMemberSend.run(groupId: groupId, name: name, phone: phone)
            sending = false
            if ok {
                sentName = name
                sentDigits = String(phone.dropFirst(2))          // "+1" + 10 digits → the 10 digits
                step = "sent"
            }
        }
    }
}
```

On failure the screen stays on step 2 with its own name and digits kept (D10) — the container changes nothing but `sending`.

- [ ] **Step 6: Map the destination** — in `UI2Shell.page(for:)`:

```swift
        case let .inviteMember(groupId, returnDepth): InviteMemberContainer(groupId: groupId, returnDepth: returnDepth)  // invite-member D1
```

- [ ] **Step 7: Run it and watch it pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 8: Commit** — `feat(invite-member): host the invite page and send the invite`

### Task 12: The Add-menu row opens the flow
App: iphone
Phase: 4
Recipe: `/nav-route` · SPEC D2, D12, D13, R1

**Files:**
- Create: `iphone/MakeReady/UI2/Containers/Groups/InviteEntry.swift` (both targets, as Task 9)
- Create: `iphone/MakeReadyCaptureTests/InviteEntryTests.swift` (MakeReadyCaptureTests target)
- Modify: `iphone/MakeReady/UI2/Shell/UI2Shell.swift:26-31,56-62` (the Add menu's `onSelect`)

**Interfaces:**
- Consumes: `UI2Destination.inviteSelectGroup(returnDepth:)`, `.inviteMember(groupId:returnDepth:)`, `UI2ShellModel.push`, `path(for:)` (Task 8).
- Produces: `InviteEntry.destination(groups: [UserGroup], returnDepth: Int) -> UI2Destination?`; `InviteEntry.noGroupsMessage`, `InviteEntry.loadFailedMessage`.

- [ ] **Step 1: Write the failing test** — `InviteEntryTests.swift`

```swift
import XCTest
@testable import MakeReady

/// invite-member D2/D12: 0 groups → nothing, 1 → the invite page, 2+ → the picker.
final class InviteEntryTests: XCTestCase {
    private func group(_ id: String) -> UserGroup {
        UserGroup(id: id, code: "C", name: id, isPrivate: false, allowInvites: true, memberCount: 0,
                  creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testNoGroupsPushesNothing() {
        XCTAssertNil(InviteEntry.destination(groups: [], returnDepth: 0))
    }

    func testOneGroupGoesStraightToTheInvitePage() {
        XCTAssertEqual(InviteEntry.destination(groups: [group("g1")], returnDepth: 2),
                       .inviteMember(groupId: "g1", returnDepth: 2))
    }

    func testTwoOrMoreGroupsOpenThePicker() {
        XCTAssertEqual(InviteEntry.destination(groups: [group("g1"), group("g2")], returnDepth: 0),
                       .inviteSelectGroup(returnDepth: 0))
    }

    func testTheCopy() {
        XCTAssertEqual(InviteEntry.noGroupsMessage, "Create a group before inviting members")
        XCTAssertEqual(InviteEntry.loadFailedMessage, "Couldn't load your groups")
    }
}
```

- [ ] **Step 2: Run it and watch it fail** — `npm run ios:build-check -- --test` → FAIL to compile.

- [ ] **Step 3: Write the entry decision** — `InviteEntry.swift`

```swift
import Foundation

/// invite-member D2/D12/D13: where the Add menu's "Invite a member" row goes.
enum InviteEntry {
    static let rowLabel = "Invite a member"
    static let noGroupsMessage = "Create a group before inviting members"
    static let loadFailedMessage = "Couldn't load your groups"

    static func destination(groups: [UserGroup], returnDepth: Int) -> UI2Destination? {
        switch groups.count {
        case 0: return nil
        case 1: return .inviteMember(groupId: groups[0].id, returnDepth: returnDepth)
        default: return .inviteSelectGroup(returnDepth: returnDepth)
        }
    }

    /// D13: cache-first load, then decide. D12: no groups → the banner, nothing pushed.
    @MainActor
    static func open(state: AppState = .shared, push: (UI2Destination) -> Void, returnDepth: Int) async {
        do {
            try await GroupActions().loadGroups()
        } catch {
            if state.groups.all.isEmpty {
                state.recordError(error, context: "InviteEntry.open", surface: true, friendlyMessage: loadFailedMessage)
                return
            }
            state.recordError(error, context: "InviteEntry.open")       // stale cache still usable
        }
        guard let destination = destination(groups: state.groups.all, returnDepth: returnDepth) else {
            state.recordError(APIError.serverError(noGroupsMessage), context: "InviteEntry.open",
                              surface: true, friendlyMessage: noGroupsMessage)
            return
        }
        push(destination)
    }
}
```

- [ ] **Step 4: Wire the row** — in `UI2Shell`, replace the Add menu's `onSelect: { _ in addMenuOpen = false },` with:

```swift
                        onSelect: { action in
                            addMenuOpen = false
                            guard action.label == InviteEntry.rowLabel else { return }  // the other rows land with their screens
                            let tab = model.tab
                            let depth = model.path(for: tab).count
                            Task { @MainActor in
                                await InviteEntry.open(push: { model.push($0, on: tab) }, returnDepth: depth)
                            }
                        },
```

and update the `addMenuActions` doc comment: "Invite a member" now opens the invite flow (invite-member D2); the other three still only close the menu.

- [ ] **Step 5: Run it and watch it pass** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 6: Commit** — `feat(invite-member): the Add menu's Invite a member row opens the invite flow`

### Task 13: Residual sweep — nothing else points at the old invite entries
App: iphone
Phase: 4
Recipe: SPEC §Replaced surfaces + §Findings R1–R4 · tiny

**Files:**
- Read only, unless a hit is found: `iphone/MakeReady/UI2/**`, `iphone/MakeReady/MakeReadyApp.swift`

**Interfaces:**
- Consumes: Tasks 8–12.
- Produces: the sweep's evidence in the report; no code unless a hit is found.

- [ ] **Step 1: Re-grep the retired and absorbed entries in the app target's sources** — run each; every one must print nothing:

```bash
cd iphone && grep -rn "GroupInvitePage\|groupsInviteMenu\|InviteMenu(" MakeReady/UI2 MakeReady/MakeReadyApp.swift
cd iphone && grep -rn "onSelect: { _ in addMenuOpen = false }" MakeReady/UI2
cd iphone && grep -rn "EnrollmentSelectGroupScreen(" MakeReady/UI2 | grep -v "Containers/Groups/InviteSelectGroupContainer.swift"
cd iphone && grep -rn "InviteMemberScreen(" MakeReady/UI2 | grep -v "Containers/Groups/InviteMemberContainer.swift"
```

- [ ] **Step 2: Prove the legacy files are still outside the app target** — `cd iphone && ruby -rxcodeproj -e 'p=Xcodeproj::Project.open("MakeReady.xcodeproj"); t=p.targets.find{|x|x.name=="MakeReady"}; puts t.source_build_phase.files_references.map(&:path).grep(/GroupInvitePage|InviteMenu|Services\/Route\.swift/)'` → prints nothing (R3, R4: legacy 1.0, untouched).

- [ ] **Step 3: A hit is a defect** — any line printed by Step 1 or 2 is repointed to the 2.0 flow in this task (with a test in `InviteEntryTests` when it is behaviour) and the step re-run until clean.

- [ ] **Step 4: Gates** — `npm run ios:build-check -- --test && (cd iphone && swiftlint --baseline .swiftlint-baseline.json)` → PASS

- [ ] **Step 5: Commit** — only if Step 3 changed code: `fix(invite-member): repoint <what> to the invite flow`; otherwise record "sweep clean, no commit" in the report.
