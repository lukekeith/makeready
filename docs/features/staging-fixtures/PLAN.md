# staging-fixtures — implementation plan

> **For agentic workers:** this plan is executed by `/builder:build`, one task at a time, with a
> fresh implementer per task, tested and reviewed as the go-ahead's test plan sets. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** let a tester install a staging TestFlight app, pick the Fully populated or New group fixture on Profile, and reset it, with production unchanged.

**Architecture:** the server gains a second, new-group fixture world, a stricter host:port way through the fixture guard, two key-gated auth routes that look like unknown routes until the gate passes, and a GitHub workflow that does all seeding outside the API image. The iPhone project gains a `Staging` build configuration and scheme; the Profile stopgap gains a Test data group, and `AuthManager.signIn` routes to the new login on Staging when the build has a key.

**Tech Stack:** server: Express, zod, Prisma, vitest, GitHub Actions. iphone: Swift, SwiftUI, `@Observable` + Actions, XCTest, Xcode build configurations.

**Spec:** `docs/features/staging-fixtures/SPEC.md`

## Global Constraints

- Read FIRST the recipe skill or REFERENCE section named on your task's `Recipe:` line, then the SPEC section it implements. The spec is the contract, and **SPEC §Contract is frozen** — if the shape you need differs from it, STOP and report it rather than changing either side.
- **Your task touches ONE app.** Its `App:` line says which. Do not edit another app "while you are in there": a consumer change that is not in your task is a contract violation the spec did not authorize.
- Server: route modules stay thin, `src/services/` owns the logic; the schema YAML under `server/schema/` is the source of truth and `npm run schema:diff` generates the migration — **never hand-edit a committed migration**; org-scoped RBAC is checked in the SERVICE layer and authorizes by the org-level check (`canManageOrgContent`), never by `creatorId`; zod validates every mutating body and must not silently strip fields the consumer sends; external integrations stay behind their service module. 🔴 `docker restart makeready-server` after ANY `server/src` edit, or your test hits the old code.
- Client: Vue islands mounted into Blade, not an SPA (except `/admin`); Pinia domain stores for API data and UI stores for view state, never a component-level `fetch`; admin API through the `/admin/api/{path}` proxy; design-token SCSS only — `npm run guard` enforces it and you report your DELTA, not a green exit; 🔴 never `window.confirm`/`alert`/`prompt` — use the confirm-dialog service with a `.btn--danger` confirm.
- iPhone: `@Observable` + Actions; any server-derived collection more than one screen reads, or any screen mutates, lives in `AppState` (`EntityStore` when it has identity) and a mutating Action refreshes the derived state in the same call; no `APIClient` calls from Pages or Components; overlays through the typed `Route` system — 🔴 never `.sheet`, never `.fullScreenCover`, never `asyncAfter` choreography; `swiftlint` runs from `iphone/`, never the repo root. Builder agents commit under the owner-approved `apps.iphone.commit: auto` policy; other iPhone commit flows retain their human approval requirements.
- Tests ship WITH the task: a service's unit test, a route's request test, a component's test, a schema change's `schema:validate` in the same commit. TDD: the failing test first.
- Commits: **exactly one commit for this task** — code and tests together — `<type>(staging-fixtures): <subject>` where TICKET is the one in your brief. If review sends you back, each fix round is its own commit. **Never `git commit --amend`.**
- Never create a branch, a worktree or a ticket. Never open a PR. Never write to monday.com. Never hand-edit a committed migration. Never write a UI 2.0 contract, registry row or note — those belong to `/ui2-*` and `/d2m-*`.
- Report: status · commits · one-line test summary · concerns, under 15 lines; the detail goes to your report file.

## Phases

| Phase | App | Tasks | Goal |
|---|---|---|---|
| 1 | server | 1–4 | The guard admits only the named staging database, `new-group` seeds and resets beside `full`, C1 and C2 exist behind the gate, the workflow can seed staging, and the contract is frozen |
| 2 | iphone | 5–7 | A `MakeReady Staging` scheme builds under its own bundle id, sign-in uses C1 on Staging, and Profile offers both fixtures and Reset |

---

### Task 1: Fixture guard admits the named staging database
App: server
Phase: 1
Recipe: `server/fixtures/README.md` §Run it; SPEC D8, F6 · tiny

**Files:**
- Modify: `server/fixtures/guard.ts:13-35` — the staging way through, after the `NODE_ENV` check
- Test: `server/fixtures/__tests__/guard.test.ts` — the staging cases

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces: `checkGuard` — same signature and `GuardResult`; reads three more env names: `FIXTURES_TARGET`, `FIXTURES_STAGING_DB_ENDPOINT`, and `DIRECT_URL` as required on this path

**Behaviour:**
- The `NODE_ENV` check stays first and still applies on the staging path (D8)
- With `FIXTURES_TARGET=staging`, only the staging rule decides, so the local host list can never admit a staging run (D8)
- The endpoint must include a port, both URLs must be set, and each URL's `host:port` must equal the endpoint exactly (D8, F6)
- Without `FIXTURES_TARGET=staging`, the local rule is unchanged, so `FIXTURES_STAGING_DB_ENDPOINT` alone admits nothing (D8)

The security mechanism, to be followed as written. `postgresql:` is a non-special URL scheme, so `URL.host` keeps the port as typed and has no default port to drop:

```ts
if (env.FIXTURES_TARGET === 'staging') {
  const endpoint = env.FIXTURES_STAGING_DB_ENDPOINT
  if (!endpoint || !/:\d+$/.test(endpoint)) {
    return { ok: false, reason: 'FIXTURES_STAGING_DB_ENDPOINT must be host:port' }
  }
  for (const name of ['DATABASE_URL', 'DIRECT_URL']) {
    const value = env[name]
    if (!value) return { ok: false, reason: `${name} is not set` }
    let host: string
    try {
      host = new URL(value).host
    } catch {
      return { ok: false, reason: `${name} is not a valid URL` }
    }
    if (host !== endpoint) return { ok: false, reason: `${name} endpoint "${host}" is not the staging endpoint` }
  }
  return { ok: true }
}
```

**Tests:**
- `staging rule passes only with every setting and a matching host:port` — the one way through (D8)
- `staging rule refuses the same hostname on another port` — the shared-proxy case (F6)
- `staging rule refuses an endpoint with no port` — hostname alone is not enough (D8)
- `staging rule refuses the production endpoint` — a production-looking host on a staging endpoint setting (D8)
- `staging rule refuses an unset DIRECT_URL` — both URLs are required (D8)
- `staging rule still refuses NODE_ENV=production` — the NODE_ENV check is not bypassed (D8)
- `an endpoint without FIXTURES_TARGET admits nothing` — the local rule is unchanged (D8)

```ts
const STAGING_ENDPOINT = 'shared.proxy.rlwy.net:41000'
const STAGING_URL = `postgresql://u:p@${STAGING_ENDPOINT}/railway`
const staging = (over: Record<string, string | undefined> = {}) => ({
  NODE_ENV: 'development',
  FIXTURES_TARGET: 'staging',
  FIXTURES_STAGING_DB_ENDPOINT: STAGING_ENDPOINT,
  DATABASE_URL: STAGING_URL,
  DIRECT_URL: STAGING_URL,
  ...over,
})

it('staging rule passes only with every setting and a matching host:port', () => {
  expect(checkGuard(staging())).toEqual({ ok: true })
})
it('staging rule refuses the same hostname on another port', () => {
  const other = 'postgresql://u:p@shared.proxy.rlwy.net:33058/railway'
  expect(checkGuard(staging({ DATABASE_URL: other })).ok).toBe(false)
  expect(checkGuard(staging({ DIRECT_URL: other })).ok).toBe(false)
})
it('staging rule refuses an endpoint with no port', () => {
  expect(checkGuard(staging({ FIXTURES_STAGING_DB_ENDPOINT: 'shared.proxy.rlwy.net' })).ok).toBe(false)
  expect(checkGuard(staging({ FIXTURES_STAGING_DB_ENDPOINT: undefined })).ok).toBe(false)
})
it('staging rule refuses the production endpoint', () => {
  const prod = 'postgresql://u:p@hopper.proxy.rlwy.net:33058/railway'
  expect(checkGuard(staging({ DATABASE_URL: prod, DIRECT_URL: prod })).ok).toBe(false)
})
it('staging rule refuses an unset DIRECT_URL', () => {
  const r = checkGuard(staging({ DIRECT_URL: undefined }))
  expect(r.ok).toBe(false)
  if (!r.ok) expect(r.reason).toContain('DIRECT_URL')
})
it('staging rule still refuses NODE_ENV=production', () => {
  expect(checkGuard(staging({ NODE_ENV: 'production' })).ok).toBe(false)
})
it('an endpoint without FIXTURES_TARGET admits nothing', () => {
  expect(checkGuard(staging({ FIXTURES_TARGET: undefined })).ok).toBe(false)
})
```

- [ ] **Step 1: Write the listed tests** — in `server/fixtures/__tests__/guard.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/guard.test.ts`, watch them fail** — this suite opens no database
- [ ] **Step 3: Add the staging path to `checkGuard` and update its header comment to name it**
- [ ] **Step 4: Run the same command, watch them pass, then `npx --no-install tsc --noEmit -p fixtures`**
- [ ] **Step 5: Commit** — `feat(staging-fixtures): fixture guard admits the named staging database`

### Task 2: The `new-group` scenario
App: server
Phase: 1
Recipe: `server/fixtures/README.md` §Scenarios and §Fixed IDs; SPEC D1, D2, D16, §server *Runner*

**Files:**
- Modify: `server/fixtures/ids.ts` — the New group ids and email
- Create: `server/fixtures/new-group.ts` — its wipe, seed and counts
- Modify: `server/fixtures/runner.ts:26,52-55,125-148` — the scenario type, its listing and the branch in `runFixtures`
- Modify: `server/fixtures/__tests__/db-harness.ts:18` — `run` accepts `'new-group'`
- Test: `server/fixtures/__tests__/new-group.test.ts` — wipe order and ids, with fakes
- Test: `server/fixtures/__tests__/new-group.db.test.ts` — the two worlds against the test database
- Test: `server/fixtures/__tests__/runner.test.ts:52-60` — `availableScenarios` lists it

**Interfaces:**
- Consumes: `fixtureId` and `RowCounts`; `FixtureError` from `context.ts`
- Produces:
  - `FIXTURE_NEW_GROUP_USER_EMAIL` = `fixtures-new@makeready.local`, `FIXTURE_NEW_GROUP_USER_ID` = `fixtureId('user', 900)`, `FIXTURE_NEW_GROUP_ORG_ID` = `fixtureId('organization', 900)`, `FIXTURE_NEW_GROUP_GROUP_ID` = `fixtureId('group', 900)`, in `ids.ts`
  - `NEW_GROUP_SCENARIO` — the string `new-group`
  - `wipeNewGroup` — takes a Prisma client narrowed to the models it deletes, returns nothing
  - `seedNewGroup` — takes the Prisma client and a `Date`, returns nothing
  - `newGroupUserExists` — takes the Prisma client, returns a boolean; matches on id or email
  - `countNewGroupRows` — takes the Prisma client, returns `RowCounts` scoped to the New group user and org

**Behaviour:**
- `FIXTURE_USER_IDS`, `fixtureUserExists`, `wipeFixtures`, `seedBase` and `countFixtureRows` are not changed, so `full` cannot touch this world (D1, D16)
- `runFixtures` branches before `wipeFixtures` and `seedBase`: `new-group` runs its own wipe on `reset`, or refuses on `seed` when its user exists with `the New group fixture user already exists — run fixtures:reset -- new-group instead`, then seeds (D16)
- Both branches still end by refreshing analytics through `refreshUntilRan`, then return their own counts, so deleted groups leave the materialized view (D16; SPEC §server *Runner*)
- `wipeNewGroup` deletes in exactly this order: `clientEvent` by `organizationId`, `group`, `studyProgram` and `lessonTemplate` by `organizationId`, then `user` by id, which cascades the org (§server *Runner*)
- It never deletes from `member`: a tester-added member survives, losing its org and group links through the cascades (§server *Runner*)
- `seedNewGroup` looks up the system Owner role as `base.ts:122-123` does and throws the same `FixtureError` when it is missing; it never creates a role (D2, F3)
- It creates exactly these: the user with name `New Group Leader`, the org `New Group Fixtures` owned by that user, one `userRole` with id `fixtureId('userRole', 900)` and the Owner role in that org, and one active group `My First Group` created by that user. It sets no `User.organizationId` (D2, §server *Runner*)
- `availableScenarios` returns the implemented layer scenarios, then `empty`, then `new-group`, and it is not added to `LAYER_SCENARIOS` (D16)

**Pattern:**
- `server/fixtures/base.ts:121-144` — role lookup and user, org and `userRole` creation
- `server/fixtures/__tests__/wipe.test.ts:15-45` — the fake client for the delete order
- `server/fixtures/__tests__/base.db.test.ts:25-40` — `describe.skipIf(!TEST_DB_URL)` and `openFixturesDb`

**Tests:**
- `wipeNewGroup deletes in the spec's order and never members` — the delete order and scope (§server *Runner*)
- `availableScenarios lists new-group last` — the listing (D16)
- `new-group seeds only the D2 world` — the exact contents (D2)
- `new-group and full coexist and neither reset touches the other` — both worlds (D1)
- `reset removes tester rows from the org, keeps the member and can run again` — tester-created rows (§server *Runner*, §Testing)
- `the New group owner may use the iPhone app` — it passes the rule `/auth/leader-access` applies, an owned active org (D2)

```ts
it('wipeNewGroup deletes in the spec\'s order and never members', async () => {
  const calls: Array<{ model: string; args: unknown }> = []
  const model = (name: string) => ({ deleteMany: async (args: unknown) => { calls.push({ model: name, args }); return { count: 0 } } })
  const fake = { clientEvent: model('clientEvent'), group: model('group'), studyProgram: model('studyProgram'), lessonTemplate: model('lessonTemplate'), user: model('user') }
  await wipeNewGroup(fake as never)
  const org = { where: { organizationId: FIXTURE_NEW_GROUP_ORG_ID } }
  expect(calls).toEqual([
    { model: 'clientEvent', args: org },
    { model: 'group', args: org },
    { model: 'studyProgram', args: org },
    { model: 'lessonTemplate', args: org },
    { model: 'user', args: { where: { id: FIXTURE_NEW_GROUP_USER_ID } } },
  ])
})

it('availableScenarios lists new-group last', () => {
  expect(availableScenarios([{ name: 'home-dashboard', module: { full: async () => undefined } }])).toEqual(['full', 'empty', 'new-group'])
  expect(availableScenarios([])).toEqual(['empty', 'new-group'])
})
```

```ts
// new-group.db.test.ts, inside describe.skipIf(!TEST_DB_URL), with db = await openFixturesDb()
const org = FIXTURE_NEW_GROUP_ORG_ID

it('new-group seeds only the D2 world', async () => {
  await db.run('reset', 'new-group')
  const groups = await db.prisma.group.findMany({ where: { organizationId: org } })
  expect(groups.map((g) => [g.name, g.isActive])).toEqual([['My First Group', true]])
  expect((await db.prisma.organization.findUnique({ where: { id: org } }))?.name).toBe('New Group Fixtures')
  expect(await db.prisma.user.count({ where: { email: 'fixtures-new@makeready.local' } })).toBe(1)
  expect(await db.prisma.memberOrganization.count({ where: { organizationId: org } })).toBe(0)
  expect(await db.prisma.studyProgram.count({ where: { organizationId: org } })).toBe(0)
  expect(await db.prisma.enrollment.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
  expect(await db.prisma.event.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
  expect(await db.prisma.post.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
  expect(await db.prisma.media.count({ where: { organizationId: org } })).toBe(0)
})

it('new-group and full coexist and neither reset touches the other', async () => {
  await db.run('reset', 'new-group')
  const fullCounts = await db.run('reset', 'full')
  expect(await db.prisma.group.count({ where: { organizationId: org } })).toBe(1)
  await db.run('reset', 'new-group')
  expect(await countFixtureRows(db.prisma)).toEqual(fullCounts)
})

it('reset removes tester rows from the org, keeps the member and can run again', async () => {
  await db.run('reset', 'new-group')
  const memberId = '0b0b0b0b-0900-4000-8000-000000000001'
  await db.prisma.member.deleteMany({ where: { id: memberId } })
  // Create under the New group user and org: a second group, a program, a template, a post on the
  // seeded group, a client event, and member `memberId` with its member_organizations row and a
  // group_members row, using each model's required fields from prisma/schema.prisma.
  await createTesterRows(db.prisma, { org, userId: FIXTURE_NEW_GROUP_USER_ID, groupId: FIXTURE_NEW_GROUP_GROUP_ID, memberId })
  await db.run('reset', 'new-group')
  expect(await db.prisma.group.count({ where: { organizationId: org } })).toBe(1)
  expect(await db.prisma.studyProgram.count({ where: { organizationId: org } })).toBe(0)
  expect(await db.prisma.lessonTemplate.count({ where: { organizationId: org } })).toBe(0)
  expect(await db.prisma.post.count({ where: { groupId: FIXTURE_NEW_GROUP_GROUP_ID } })).toBe(0)
  expect(await db.prisma.clientEvent.count({ where: { organizationId: org } })).toBe(0)
  expect(await db.prisma.member.count({ where: { id: memberId } })).toBe(1)
  expect(await db.prisma.memberOrganization.count({ where: { memberId } })).toBe(0)
  expect(await db.prisma.groupMember.count({ where: { memberId } })).toBe(0)
  await expect(db.run('reset', 'new-group')).resolves.toBeDefined()
  await db.prisma.member.deleteMany({ where: { id: memberId } })
})

it('the New group owner may use the iPhone app', async () => {
  await db.run('reset', 'new-group')
  const owned = await db.prisma.organization.findFirst({ where: { ownerId: FIXTURE_NEW_GROUP_USER_ID, isActive: true } })
  expect(owned?.id).toBe(org)
  const user = await db.prisma.user.findUnique({ where: { id: FIXTURE_NEW_GROUP_USER_ID } })
  expect(user?.isActive).toBe(true)
})
```

- [ ] **Step 1: Write the listed tests, the `createTesterRows` helper inside the DB test file, and the `db-harness.ts` type change**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (database tests run only in its lease; `<builder>` is the directory your brief names)
- [ ] **Step 3: Add the ids, write `new-group.ts`, and branch `runFixtures` and `availableScenarios`**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit -p fixtures`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(staging-fixtures): new-group fixture scenario`

### Task 3: C1 and C2 behind the fixture gate
App: server
Phase: 1
Recipe: `/api`; SPEC D6, D11, D17, §Contract, F7

**Files:**
- Create: `server/src/services/fixture-access.ts` — the gate, the fixture-to-email map and the GitHub dispatch
- Modify: `server/src/routes/auth.ts:1178` — the two thin routes, before `export default router`
- Test: `server/src/services/__tests__/fixture-access.test.ts` — the gate and the dispatch
- Test: `server/src/routes/__tests__/auth-fixture.test.ts` — both routes through the app

**Interfaces:**
- Consumes: the rows `seedBase` and `seedNewGroup` create, by email only. 🔴 `server/src/` must not import from `server/fixtures/`: the API image contains no `fixtures/` directory (SPEC §How it fits today), so a build that imports it fails in production
- Produces:
  - `fixtureGateOpen` — takes the header value (string or undefined) and an env record, returns a boolean
  - `fixtureBodySchema` — zod object with `fixture` as an enum of `full` and `new-group`
  - `FIXTURE_LOGIN_EMAILS` — maps each fixture to its email
  - `dispatchFixtureReset` — takes the fixture and an env record, returns a promise of a boolean: true only on GitHub's 204
  - The frozen contract, verbatim from SPEC §Contract:

```markdown
| Contract | Producer | Consumers | Auth | Request | Response | Errors |
|---|---|---|---|---|---|---|
| C1 `POST /auth/fixture-login` | server | iphone | `X-Fixture-Key` + `FIXTURE_LOGIN_ENABLED=true` | `{ fixture: "full" \| "new-group" }` | 200, same body as `/auth/dev-login`: `{ success: true, user: { id, email, name, avatarURL }, sessionCookie }` | 404 (Express's unknown-route answer, not JSON) when the flag is unset, the server key is unset or empty, or the key is missing or wrong; 400 unknown fixture; 404 `{ success: false, error: "fixtures_not_seeded" }` when its user is missing, so the app decides on the body; 429 from the shared `/auth/` limiter |
| C2 `POST /auth/fixture-reset` | server | iphone | as C1 | `{ fixture: "full" \| "new-group" }` | 202 `{ success: true }` once GitHub accepts the dispatch | 404 as C1; 400 unknown fixture; 502 `{ success: false, error: "reset_unavailable" }` when GitHub refuses or times out, or no token is set; 429 from the shared `/auth/` limiter |
```

**Behaviour:**
- Each route opens with the gate and answers a closed gate by calling `next()`, so the response is Express's own HTML 404 (D6, D17)
- Then zod on `{ fixture }`, so an unknown fixture answers 400 `{ success: false, error: "unknown_fixture" }` only to a caller holding the key (D17)
- C1 takes no email: anything else in the body is ignored and the user comes from `FIXTURE_LOGIN_EMAILS` (D6)
- C1 with no such user answers 404 `{ success: false, error: "fixtures_not_seeded" }` (§Contract, D12)
- C1's session, signed cookie and response body follow dev-login at `auth.ts:1197-1222`, and an unexpected failure answers 500 `{ success: false, error: "Login failed" }`. Dev-login's own code is not edited (D6)
- C2 answers 202 `{ success: true }` when `dispatchFixtureReset` is true, otherwise 502 `{ success: false, error: "reset_unavailable" }` (§Contract, D11)
- Neither route gets an `@openapi` block (D17)
- `dispatchFixtureReset` returns false with no request when `FIXTURE_RESET_GITHUB_TOKEN` is unset or empty, returns false on any thrown error or timeout, and never logs the token (D11)

The security mechanism and the dispatch, to be followed as written:

```ts
const sha256 = (value: string) => createHash('sha256').update(value).digest()

export function fixtureGateOpen(header: string | undefined, env: Record<string, string | undefined>): boolean {
  if (env.FIXTURE_LOGIN_ENABLED !== 'true') return false
  const serverKey = env.FIXTURE_ACCESS_KEY
  if (!serverKey || !header) return false
  return timingSafeEqual(sha256(header), sha256(serverKey))
}

export const FIXTURE_LOGIN_EMAILS = {
  full: 'fixtures@makeready.local',
  'new-group': 'fixtures-new@makeready.local',
} as const

// POST, 10-second timeout, true only on status 204:
const url = 'https://api.github.com/repos/lukekeith/makeready/actions/workflows/reset-staging-fixtures.yml/dispatches'
const init = {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${token}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ ref: 'main', inputs: { fixture } }),
  signal: AbortSignal.timeout(10_000),
}
```

**Pattern:**
- `server/src/routes/auth.ts:1185-1230` — dev-login's session and response
- `server/src/routes/__tests__/auth.test.ts:7-10` — supertest against `app`

**Tests:**
- `the gate is closed for every missing or wrong part` — flag, server key and header (D6, F7)
- `the gate opens only on a matching key` — the one way through (D6)
- `dispatch sends the fixture against main and is true only on 204` — the request (D11)
- `dispatch is false on refusal, on a thrown timeout and with no token` — the failures (D11)
- `both routes look like an unknown route while the gate is closed` — HTML 404 for every closed-gate case (D6, F7)
- `an unknown fixture is 400 only with the key` — gate before zod (D17)
- `C1 signs in each fixture account and returns a working session` — both accounts (D6, §Contract)
- `C1 ignores an email in the body` — no choice of account (D6)
- `C1 answers fixtures_not_seeded when the user is missing` — the app's cue (D12)
- `C2 is 202 on dispatch and 502 otherwise` — status mapping (D11, §Contract)

```ts
// fixture-access.test.ts
const on = { FIXTURE_LOGIN_ENABLED: 'true', FIXTURE_ACCESS_KEY: 'abc123' }

it('the gate is closed for every missing or wrong part', () => {
  expect(fixtureGateOpen('abc123', { FIXTURE_ACCESS_KEY: 'abc123' })).toBe(false)
  expect(fixtureGateOpen('abc123', { ...on, FIXTURE_LOGIN_ENABLED: 'false' })).toBe(false)
  expect(fixtureGateOpen('', { FIXTURE_LOGIN_ENABLED: 'true' })).toBe(false)
  expect(fixtureGateOpen('', { FIXTURE_LOGIN_ENABLED: 'true', FIXTURE_ACCESS_KEY: '' })).toBe(false)
  expect(fixtureGateOpen(undefined, on)).toBe(false)
  expect(fixtureGateOpen('', on)).toBe(false)
  expect(fixtureGateOpen('wrong', on)).toBe(false)
  expect(fixtureGateOpen('a-much-longer-wrong-key', on)).toBe(false)
})
it('the gate opens only on a matching key', () => {
  expect(fixtureGateOpen('abc123', on)).toBe(true)
})
it('dispatch sends the fixture against main and is true only on 204', async () => {
  const fetchStub = vi.fn(async () => new Response(null, { status: 204 }))
  vi.stubGlobal('fetch', fetchStub)
  expect(await dispatchFixtureReset('new-group', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(true)
  const [url, init] = fetchStub.mock.calls[0] as unknown as [string, RequestInit]
  expect(url).toBe('https://api.github.com/repos/lukekeith/makeready/actions/workflows/reset-staging-fixtures.yml/dispatches')
  expect(JSON.parse(init.body as string)).toEqual({ ref: 'main', inputs: { fixture: 'new-group' } })
  expect((init.headers as Record<string, string>).Authorization).toBe('Bearer t')
  expect(init.signal).toBeInstanceOf(AbortSignal)
})
it('dispatch is false on refusal, on a thrown timeout and with no token', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 403 })))
  expect(await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(false)
  vi.stubGlobal('fetch', vi.fn(async () => { throw new DOMException('timed out', 'TimeoutError') }))
  expect(await dispatchFixtureReset('full', { FIXTURE_RESET_GITHUB_TOKEN: 't' })).toBe(false)
  const noCall = vi.fn()
  vi.stubGlobal('fetch', noCall)
  expect(await dispatchFixtureReset('full', {})).toBe(false)
  expect(noCall).not.toHaveBeenCalled()
})
```

```ts
// auth-fixture.test.ts: env through vi.stubEnv, fetch through vi.stubGlobal, unstubbed in afterEach;
// the two fixture users created in beforeEach and removed by email in afterEach
const post = (path: string, body: object, key?: string) => {
  const r = request(app).post(path).send(body)
  return key === undefined ? r : r.set('X-Fixture-Key', key)
}
const open = () => { vi.stubEnv('FIXTURE_LOGIN_ENABLED', 'true'); vi.stubEnv('FIXTURE_ACCESS_KEY', 'abc123') }

it.each(['/auth/fixture-login', '/auth/fixture-reset'])('both routes look like an unknown route while the gate is closed: %s', async (path) => {
  const expectUnknown = (res: request.Response) => {
    expect(res.status).toBe(404)
    expect(res.type).toMatch(/html/)
    expect(res.text).toContain(`Cannot POST ${path}`)
  }
  vi.stubEnv('FIXTURE_LOGIN_ENABLED', '')
  vi.stubEnv('FIXTURE_ACCESS_KEY', 'abc123')
  expectUnknown(await post(path, { fixture: 'full' }, 'abc123'))
  vi.stubEnv('FIXTURE_LOGIN_ENABLED', 'true')
  vi.stubEnv('FIXTURE_ACCESS_KEY', '')
  expectUnknown(await post(path, { fixture: 'full' }, ''))
  open()
  expectUnknown(await post(path, { fixture: 'full' }))
  expectUnknown(await post(path, { fixture: 'full' }, 'wrong'))
  expectUnknown(await post(path, { fixture: 'nope' }, 'wrong'))
})
it('an unknown fixture is 400 only with the key', async () => {
  open()
  for (const path of ['/auth/fixture-login', '/auth/fixture-reset']) {
    const res = await post(path, { fixture: 'nope' }, 'abc123')
    expect(res.status).toBe(400)
    expect(res.body).toEqual({ success: false, error: 'unknown_fixture' })
  }
})
it.each([['full', 'fixtures@makeready.local'], ['new-group', 'fixtures-new@makeready.local']])('C1 signs in each fixture account and returns a working session: %s', async (fixture, email) => {
  open()
  const res = await post('/auth/fixture-login', { fixture }, 'abc123')
  expect(res.status).toBe(200)
  expect(res.body.success).toBe(true)
  expect(res.body.user.email).toBe(email)
  expect(Object.keys(res.body.user).sort()).toEqual(['avatarURL', 'email', 'id', 'name'])
  expect(res.body.sessionCookie).toMatch(/^s:/)
  const me = await request(app).get('/auth/me').set('Cookie', `connect.sid=${res.body.sessionCookie}`)
  expect(me.status).toBe(200)
})
it('C1 ignores an email in the body', async () => {
  open()
  const res = await post('/auth/fixture-login', { fixture: 'full', email: 'someone-else@example.com' }, 'abc123')
  expect(res.status).toBe(200)
  expect(res.body.user.email).toBe('fixtures@makeready.local')
})
it('C1 answers fixtures_not_seeded when the user is missing', async () => {
  open()
  await prisma.user.deleteMany({ where: { email: 'fixtures-new@makeready.local' } })
  const res = await post('/auth/fixture-login', { fixture: 'new-group' }, 'abc123')
  expect(res.status).toBe(404)
  expect(res.body).toEqual({ success: false, error: 'fixtures_not_seeded' })
})
it('C2 is 202 on dispatch and 502 otherwise', async () => {
  open()
  vi.stubEnv('FIXTURE_RESET_GITHUB_TOKEN', 't')
  vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 204 })))
  const ok = await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')
  expect(ok.status).toBe(202)
  expect(ok.body).toEqual({ success: true })
  vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 403 })))
  const refused = await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')
  expect(refused.status).toBe(502)
  expect(refused.body).toEqual({ success: false, error: 'reset_unavailable' })
  vi.stubEnv('FIXTURE_RESET_GITHUB_TOKEN', '')
  expect((await post('/auth/fixture-reset', { fixture: 'full' }, 'abc123')).status).toBe(502)
})
```

- [ ] **Step 1: Write the listed tests** — in the two test files above
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (database tests run only in its lease; `<builder>` is the directory your brief names)
- [ ] **Step 3: Write `fixture-access.ts` and the two routes**
- [ ] **Step 4: Run `cd server && npx --no-install tsc --noEmit`, then the same verifier request, and watch them pass**
- [ ] **Step 5: Commit** — `feat(staging-fixtures): key-gated fixture login and reset routes`

### Task 4: The reset workflow, its settings and the contract freeze
App: server
Phase: 1
Recipe: `server/fixtures/README.md` §Images; SPEC D10, §server *Workflow*, *Server settings*, *Docs*; REFERENCE §Contract and the contract freeze

**Files:**
- Create: `.github/workflows/reset-staging-fixtures.yml` — the nightly and manual reset
- Modify: `server/.env.example` — the three staging-only settings, commented as staging only
- Modify: `server/fixtures/README.md` — `new-group`, the staging guard path and the workflow
- Modify: `docs/features/staging-fixtures/MANIFEST.md` — `contract: frozen <today>` in this task's commit
- Test: `server/fixtures/__tests__/reset-workflow.test.ts` — the workflow's fixed values, parsed with the `yaml` package

**Interfaces:**
- Consumes: `checkGuard`'s `FIXTURES_TARGET` and `FIXTURES_STAGING_DB_ENDPOINT`; `fixtures:reset -- <scenario>` with `full` and `new-group`; `dispatchFixtureReset`, which names this workflow file and its `fixture` input
- Produces: `reset-staging-fixtures.yml` with `workflow_dispatch` input `fixture` = `full`, `new-group` or `all`

**Behaviour:**
- Triggers, concurrency, timeout and environment are exactly the fence below (D10, D8)
- The job's first step, with `id: secrets`, checks three secrets: `STAGING_DATABASE_URL`, `STAGING_DIRECT_URL` and `FIXTURES_STAGING_DB_ENDPOINT`. With any unset, a `schedule` run writes a `::notice::`, sets the step output `skip=true` and passes; any other event writes `::error::` naming the missing secrets and exits 1. Every later step has `if: steps.secrets.outputs.skip != 'true'` (D10)
- Then checkout, node setup, `npm ci` at the root and `npx prisma generate` in `server/`, as `.github/workflows/ci.yml:186-197`, using `npm ci` rather than its `npm install` (§server *Workflow*)
- The reset step runs in `server/` and reads the input through the `FIXTURE` env, never by interpolating it into the script: `all` runs `npm run fixtures:reset -- full`, then `npm run fixtures:reset -- new-group`, stopping on the first failure; `full` or `new-group` runs that one; anything else is `::error::` and exit 1 (D10)
- 🔴 `FIXTURE_IMAGES` is always `off` in this workflow, and a comment there says it stays off until the owner confirms staging has its own bucket (F2)
- Seeding never runs inside the API image, so no Dockerfile or image file changes (D10)
- `server/.env.example` gains `FIXTURE_LOGIN_ENABLED`, `FIXTURE_ACCESS_KEY` and `FIXTURE_RESET_GITHUB_TOKEN`, empty, under a comment saying they are set on staging only and never on production (D9, §server *Server settings*)
- README: a `new-group` row under Scenarios with D2's contents; the staging guard's settings beside the existing refusal text; the workflow, its input, its GitHub secrets and that a reset is not one transaction, so a failed run leaves a partial fixture until the next good run (F5)
- 🟡 **Build-time risk F2:** images stay off, so fixtures may show no pictures on staging. Report that in your task report as the owner's follow-up
- 🟡 **Build-time risk F3:** confirm what you can without touching any database: run `gh secret list` (names only, never values) and report which of the three secrets exist. Whether a public staging connection exists, and whether the system Owner role is there, is proved by the owner's first dispatch. Say so in your report. Absent secrets are not a failure of this task
- 🟡 **Build-time risk F10:** seed time over the public proxy is measured by the owner's first dispatch and bounded by the 30-minute timeout. Say so in your report; do not change D11's text
- Once the suite is green, write `contract: frozen <today>` to the manifest, in this task's one commit (REFERENCE §Contract and the contract freeze)

The workflow's fixed values:

```yaml
name: Reset Staging Fixtures

on:
  schedule:
    - cron: '0 8 * * *'
  workflow_dispatch:
    inputs:
      fixture:
        description: Which fixture to reset
        required: true
        type: choice
        default: all
        options: [full, new-group, all]

concurrency:
  group: reset-staging-fixtures
  cancel-in-progress: false

jobs:
  reset:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    env:
      NODE_ENV: development
      FIXTURES_TARGET: staging
      FIXTURE_IMAGES: 'off'
      FIXTURE: ${{ inputs.fixture || 'all' }}
      DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
      DIRECT_URL: ${{ secrets.STAGING_DIRECT_URL }}
      FIXTURES_STAGING_DB_ENDPOINT: ${{ secrets.FIXTURES_STAGING_DB_ENDPOINT }}
```

**Pattern:**
- `.github/workflows/backfill-bible-search.yml:55-60` — the missing-secrets check
- `.github/workflows/build-api-image.yml:1-32` — the header comment and concurrency style

**Tests:**
- `the workflow runs nightly and by hand with the three inputs` — triggers (D10)
- `runs never overlap and the job is bounded` — concurrency and timeout (D10)
- `it targets staging with images off and only staging secrets` — environment (D8, F2)
- `every step after the secrets check is skipped on a scheduled skip` — the skip path (D10)

```ts
const wf = parse(readFileSync(join(FIXTURES_DIR, '../../.github/workflows/reset-staging-fixtures.yml'), 'utf8'))
const job = wf.jobs.reset

it('the workflow runs nightly and by hand with the three inputs', () => {
  expect(wf.on.schedule).toEqual([{ cron: '0 8 * * *' }])
  expect(wf.on.workflow_dispatch.inputs.fixture.options).toEqual(['full', 'new-group', 'all'])
})
it('runs never overlap and the job is bounded', () => {
  expect(wf.concurrency).toEqual({ group: 'reset-staging-fixtures', 'cancel-in-progress': false })
  expect(job['timeout-minutes']).toBe(30)
})
it('it targets staging with images off and only staging secrets', () => {
  expect(job.env.FIXTURES_TARGET).toBe('staging')
  expect(job.env.NODE_ENV).toBe('development')
  expect(job.env.FIXTURE_IMAGES).toBe('off')
  expect(job.env.DATABASE_URL).toBe('${{ secrets.STAGING_DATABASE_URL }}')
  expect(job.env.DIRECT_URL).toBe('${{ secrets.STAGING_DIRECT_URL }}')
  expect(JSON.stringify(wf)).not.toContain('PRODUCTION_')
})
it('every step after the secrets check is skipped on a scheduled skip', () => {
  const steps = job.steps as Array<{ id?: string; if?: string; run?: string }>
  expect(steps[0].id).toBe('secrets')
  expect(steps[0].run).toContain('schedule')
  for (const step of steps.slice(1)) expect(step.if).toBe("steps.secrets.outputs.skip != 'true'")
})
```

- [ ] **Step 1: Write the listed tests** — in `server/fixtures/__tests__/reset-workflow.test.ts`
- [ ] **Step 2: Run `cd server && npx vitest run fixtures/__tests__/reset-workflow.test.ts`, watch them fail** — no workflow file yet
- [ ] **Step 3: Write the workflow, then the `.env.example` and README edits**
- [ ] **Step 4: Run the same command and watch them pass, then run `gh secret list` for F3**
- [ ] **Step 5: Write `contract: frozen <today>` to the manifest** — `node <builder>/scripts/advance.mjs docs/features/staging-fixtures --set "contract=frozen <today>" --no-commit`, so it joins this task's commit
- [ ] **Step 6: Commit** — `feat(staging-fixtures): staging fixture reset workflow, contract frozen`

### Task 5: The Staging build configuration and scheme
App: iphone
Phase: 2
Recipe: `iphone/.claude/BUILD_CONFIGURATION.md`; SPEC D3, D5, D13, §iphone *Build*, §Testing *iphone (Staging build)*, F8

**Files:**
- Move: `iphone/MakeReady/Configuration/Staging.xcconfig` → `iphone/Staging.xcconfig` — D3's settings
- Modify: `iphone/Debug.xcconfig`, `iphone/Release.xcconfig` — empty `FIXTURE_ACCESS_KEY`, `APP_DISPLAY_NAME = MakeReady`
- Modify: `iphone/MakeReady/Info.plist:40,61-64` — `CFBundleDisplayName` and `FIXTURE_ACCESS_KEY` keys
- Modify: `iphone/MakeReady.xcodeproj/project.pbxproj:1301-1302,2076,3107-3221,4543,4632-4660` — the file reference and a `Staging` configuration on the project and all six configuration lists
- Create: `iphone/MakeReady.xcodeproj/xcshareddata/xcschemes/MakeReady Staging.xcscheme` — the archive scheme
- Modify: `.gitignore` — one row, `iphone/Staging.local.xcconfig`
- Modify: `iphone/README.md` — a `## Staging TestFlight build` section
- Modify: `iphone/.claude/CLAUDE.md` — the Build Configurations table's Staging row: DEV_MODE YES, switcher lists Staging and Production
- Modify: `scripts/builder-verify.mjs:87` — a `staging-build` mode before the final `else`
- Modify: `.claude/builder.md:76` — the check that runs that mode at the phase tier
- Test: `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift` — a `StagingBuildConfigTests` class in this existing file, so the test target's file list does not change

**Interfaces:**
- Consumes: nothing from earlier tasks
- Produces:
  - Build configuration `Staging` and scheme `MakeReady Staging`
  - Build settings `FIXTURE_ACCESS_KEY` and `APP_DISPLAY_NAME`
  - Info.plist keys `FIXTURE_ACCESS_KEY` and `CFBundleDisplayName`, read by `AppConfiguration.fixtureAccessKey` in a later task
  - Verifier check `iphone-staging-build`

**Behaviour:**
- `iphone/Staging.xcconfig` holds exactly the fence below, with the optional include last so a local key wins (D3, D5, D13, §iphone *Build*)
- Each of the six configuration lists gains `Staging`, copied from that list's `Release`. Where a `Release` has `baseConfigurationReference` to `Release.xcconfig` (project `:4543`, `MakeReady` target `:4632`, capture target `:4679`), its `Staging` references `Staging.xcconfig`. `defaultConfigurationName` stays `Release` (D3)
- The `MakeReady` target's `Staging` sets `PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging` and keeps `PRODUCT_NAME = "$(TARGET_NAME)"`. `MakeReady` and Release keep their settings (D3, F8)
- `MakeReady Staging.xcscheme` is `MakeReady.xcscheme` with Launch, Profile and Archive on `Staging`; Test and Analyze stay on `Debug` (D3)
- The new scheme is shared; `MakeReady.xcscheme` is not edited (D3)
- 🔴 **Do not run `xcodebuild`, `simctl` or Simulator yourself:** `iphone/.claude/CLAUDE.md` forbids them outside its named carve-outs. The build happens in the verifier's `iphone-staging-build` check
- The check's mode follows the algorithm below. It runs at the phase tier, and the verifier runs every check of a tier for every phase of every feature, so the skip test in step 1 of the algorithm is what keeps it from adding builds to unrelated work (§Testing *iphone (Staging build)*)
- 🟡 **At phase close, read this check's result:** it must be `pass`. The target branch has no `staging-build` mode, so a failure here can be filed as already failing on the target instead of as a regression. Treat that as a failure (§Testing *iphone (Staging build)*)
- 🟡 **Build-time risk F9:** with no key in `Staging.local.xcconfig`, a staging archive shows no picker and signs in through Google, and nothing fails the build. The README section states, as the archive steps: create `iphone/Staging.local.xcconfig` with `FIXTURE_ACCESS_KEY = <alphanumeric key>`, because `//` starts an xcconfig comment (D13); archive the `MakeReady Staging` scheme; upload to the MakeReady-Staging record, which needs the App Store Connect record and App ID of F4; rotate by changing the server setting and rebuilding
- 🟡 **Build-time risk F14:** run `ruby iphone/scripts/capture-targets.rb` once, then `ruby iphone/scripts/capture-targets.rb --check`, which must exit 0, because d2m's `record.sh` depends on it. A second run must leave `git diff` empty. Whatever the script legitimately adds for `Staging` on the capture targets stays in this commit; restore anything else with `git checkout -- iphone/MakeReady.xcodeproj` and report it. The check's Debug build of `MakeReadyCapture` confirms the capture targets still build

`iphone/Staging.xcconfig`:

```
// Staging.xcconfig
// Configuration for the staging TestFlight app (com.makeready.app.staging)

API_BASE_URL = https:/$()/staging.api.makeready.org

PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging
PRODUCT_NAME = MakeReady
APP_DISPLAY_NAME = MakeReady-Staging

MARKETING_VERSION = 1.1.3

// Enables the environment switcher, limited to Staging and Production in this build
DEV_MODE = YES

SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING
ENABLE_USER_SCRIPT_SANDBOXING = NO

// Empty unless iphone/Staging.local.xcconfig (git-ignored) sets it. Alphanumeric only.
FIXTURE_ACCESS_KEY =
#include? "Staging.local.xcconfig"
```

The check, in `.claude/builder.md` under `verify.checks`:

```yaml
    iphone-staging-build: { cwd: iphone, run: node ../scripts/builder-verify.mjs staging-build, needs: [verify-safe], tiers: [phase] }
```

The `staging-build` mode's algorithm:

```
1. base = `git merge-base HEAD main`, else `git merge-base HEAD origin/main`.
   If base resolves and `git diff --name-only <base> HEAD --` over iphone/Debug.xcconfig,
   iphone/Release.xcconfig, iphone/Staging.xcconfig, iphone/MakeReady.xcodeproj and
   iphone/MakeReady/Info.plist is empty: print "staging-build: nothing to check" and exit 0.
   If base does not resolve, build anyway.
2. dir = mkdtemp under tmpdir() with prefix makeready-verifier-staging-.
3. Build three times with the same -derivedDataPath <dir>, each with
   -project MakeReady.xcodeproj -destination 'generic/platform=iOS Simulator'
   CODE_SIGNING_ALLOWED=NO build:
     -scheme "MakeReady Staging" -configuration Staging
     -scheme MakeReady -configuration Release
     -scheme MakeReadyCapture -configuration Debug
   No simulator is created, booted or touched.
4. Read keys with `plutil -extract <key> raw` from
   <dir>/Build/Products/<config>-iphonesimulator/MakeReady.app/Info.plist and require:
     Staging: CFBundleIdentifier = com.makeready.app.staging, DEV_MODE = YES,
              CFBundleDisplayName = MakeReady-Staging
     Release: CFBundleIdentifier = com.makeready.app, DEV_MODE = NO,
              FIXTURE_ACCESS_KEY = (empty), CFBundleDisplayName = MakeReady
   A mismatch prints the key, the expected and the actual value, and exits 1.
5. Always, success or failure: `git checkout -- iphone/MakeReady/Info.plist` (a build bumps
   CFBundleVersion) and remove <dir>.
```

**Tests:**
- `testStagingXcconfigHoldsTheStagingSettings` — the moved file's values and the optional include (D3, D5, D13)
- `testDebugAndReleaseCarryNoKey` — no store or Debug build has a key (D9, D13)
- `testOldStagingXcconfigIsGone` — no second, unreferenced copy (F8)
- `testProjectHasAStagingConfigurationOnEveryList` — six lists and one staging bundle id (D3, F8)
- `testStagingSchemeArchivesWithStaging` — the scheme (D3)
- `testInfoPlistCarriesTheNewKeys` — both keys read their build settings (D13, §iphone *Build*)

```swift
final class StagingBuildConfigTests: XCTestCase {
    private func text(_ path: String) throws -> String {
        let iphone = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: iphone.appendingPathComponent(path), encoding: .utf8)
    }

    func testStagingXcconfigHoldsTheStagingSettings() throws {
        let config = try text("Staging.xcconfig")
        XCTAssertTrue(config.contains("DEV_MODE = YES"))
        XCTAssertTrue(config.contains("PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging"))
        XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady-Staging"))
        XCTAssertTrue(config.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS = STAGING"))
        XCTAssertTrue(config.contains("#include? \"Staging.local.xcconfig\""))
    }

    func testDebugAndReleaseCarryNoKey() throws {
        for name in ["Debug.xcconfig", "Release.xcconfig"] {
            let config = try text(name)
            let line = config.split(separator: "\n").first { $0.hasPrefix("FIXTURE_ACCESS_KEY") }
            XCTAssertEqual(line.map { $0.trimmingCharacters(in: .whitespaces) }, "FIXTURE_ACCESS_KEY =")
            XCTAssertTrue(config.contains("APP_DISPLAY_NAME = MakeReady"))
            XCTAssertFalse(config.contains("Staging.local"))
        }
    }

    func testOldStagingXcconfigIsGone() {
        XCTAssertThrowsError(try text("MakeReady/Configuration/Staging.xcconfig"))
    }

    func testProjectHasAStagingConfigurationOnEveryList() throws {
        let project = try text("MakeReady.xcodeproj/project.pbxproj")
        XCTAssertEqual(project.components(separatedBy: "name = Staging;").count - 1, 6)
        XCTAssertEqual(project.components(separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app.staging;").count - 1, 1)
        XCTAssertEqual(project.components(separatedBy: "PRODUCT_BUNDLE_IDENTIFIER = com.makeready.app;").count - 1, 2)
    }

    func testStagingSchemeArchivesWithStaging() throws {
        let scheme = try text("MakeReady.xcodeproj/xcshareddata/xcschemes/MakeReady Staging.xcscheme")
        let archive = try XCTUnwrap(scheme.range(of: "<ArchiveAction"))
        XCTAssertTrue(scheme[archive.upperBound...].contains("buildConfiguration = \"Staging\""))
        let test = try XCTUnwrap(scheme.range(of: "<TestAction"))
        XCTAssertTrue(String(scheme[test.upperBound...].prefix(60)).contains("buildConfiguration = \"Debug\""))
    }

    func testInfoPlistCarriesTheNewKeys() throws {
        let plist = try text("MakeReady/Info.plist")
        XCTAssertTrue(plist.contains("<key>FIXTURE_ACCESS_KEY</key>\n\t<string>$(FIXTURE_ACCESS_KEY)</string>"))
        XCTAssertTrue(plist.contains("<key>CFBundleDisplayName</key>\n\t<string>$(APP_DISPLAY_NAME)</string>"))
    }
}
```

- [ ] **Step 1: Write the listed tests** — in `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift`
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (`<builder>` is the directory your brief names)
- [ ] **Step 3: Move and fill the xcconfigs, add the Info.plist keys, `.gitignore` row and README and CLAUDE.md edits**
- [ ] **Step 4: Add the `Staging` configurations to the project and write the scheme** — with the `xcodeproj` gem `capture-targets.rb` already uses, or by hand
- [ ] **Step 5: Add the `staging-build` mode and the check, then settle F14 with `capture-targets.rb` as the Behaviour says**
- [ ] **Step 6: Run the same verifier request and watch them pass** — also confirm `git check-ignore iphone/Staging.local.xcconfig` prints the path
- [ ] **Step 7: Commit** — `feat(staging-fixtures): Staging build configuration and scheme`

### Task 6: Config and sign-in for the staging build
App: iphone
Phase: 2
Recipe: `/ios-error-surface`; SPEC D1, D5, D6, D12, D13, §iphone *Config*, *Auth*

**Files:**
- Modify: `iphone/MakeReady/Configuration.swift:121-133,322-351` — the key, the environment list and default, and `StagingFixture`
- Modify: `iphone/MakeReady/AuthManager.swift:32-50,54-73,155-163,469-539` — the error case, the key seam, the route, `fixtureLogin` and `fixtureReset`
- Modify: `iphone/MakeReady/UI2/Containers/Auth/LoginOutcome.swift:9` — D12's message
- Test: `iphone/MakeReadyCaptureTests/AuthManagerLaunchTests.swift` — routing, decode and failures through `AuthIO`
- Test: `iphone/MakeReadyCaptureTests/LoginOutcomeTests.swift` — the message
- Test: `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift` — the pure environment functions, in a `StagingEnvironmentTests` class

**Interfaces:**
- Consumes: C1 and C2 as frozen in SPEC §Contract; Info.plist key `FIXTURE_ACCESS_KEY`; `AppConfiguration.Environment`
- Produces:
  - `AppConfiguration.fixtureAccessKey` — a string, empty when absent
  - `AppConfiguration.switcherEnvironments(for:)` — takes an `Environment`, returns the list of `SelectedEnvironment`
  - `AppConfiguration.defaultEnvironment(for:)` — takes an `Environment`, returns a `SelectedEnvironment`
  - `StagingFixture` — enum with `full` (raw `full`) and `newGroup` (raw `new-group`), `title`, and persisted `current`, default `full`
  - `AuthError.fixturesBeingReset`
  - `AuthManager.LoginRoute` — `devLogin`, `fixtureLogin`, `google`
  - `AuthManager.loginRoute(env:devMode:fixtureKey:)` — returns a `LoginRoute`
  - `AuthManager.fixtureLogin(_:)` — takes a `StagingFixture`, async throwing
  - `AuthManager.fixtureLoginFailure(status:body:)` — returns an `Error`
  - `AuthManager.fixtureReset(_:)` — takes a `StagingFixture`, async throwing
  - `AuthIO.fixtureKey` — a closure returning a string, defaulting to `AppConfiguration.fixtureAccessKey`, so existing `AuthIO` call sites compile unchanged

**Behaviour:**
- `switcherEnvironments`: `.staging` build gives Staging and Production; every other build gives `SelectedEnvironment.allCases` (D5)
- `defaultEnvironment`: `.staging` build gives Staging; every other build gives Production. The `selectedEnvironment` getter uses it when nothing is saved, and `guard devMode else { return .production }` stays (D5)
- `StagingFixture` titles are "Fully populated" and "New group", in that order (D1)
- `loginRoute`: `devMode` and Local → `devLogin`; `devMode`, Staging and a non-empty key → `fixtureLogin`; otherwise `google` (D6)
- `signIn` keeps `resolveLoginEnvironment()` first, then switches on `loginRoute`; on `fixtureLogin` it calls `fixtureLogin(StagingFixture.current)` and never opens Google (D6)
- `fixtureLogin` posts to `\(AppConfiguration.baseURL)/auth/fixture-login` with `X-Fixture-Key` from `io.fixtureKey()` and JSON `{ "fixture": <raw value> }`, through `io.send` (§Contract, D6)
- On 200 it stores the session and runs the `/auth/leader-access` check exactly as `devLogin` does: extract `devLogin`'s lines 490-526 into one private method both call, with existing dev-login tests staying green (§iphone *Auth*)
- `fixtureLoginFailure`: status 404 with JSON `error` equal to `fixtures_not_seeded` gives `AuthError.fixturesBeingReset`; everything else, including a non-JSON 404, gives `URLError(.userAuthenticationRequired)` (D12, §Contract)
- `StagingFixture.current` is kept on that failure, unlike `DevLoginIdentity`, which reverts (D12)
- `AuthError.fixturesBeingReset` and `LoginOutcome.message(for:)` both read "This test data is being reset. Try again in a few minutes." The `fixturesNotSeeded` case and its text are unchanged (D12)
- `fixtureReset` posts to `/auth/fixture-reset` with the same header and body, returns on 202, and throws `URLError(.badServerResponse)` on anything else (§Contract, D11)
- `LoginScreen` and the login button's label are not changed, since `LoginScreen` is d2m's (§iphone *Auth*)

**Pattern:**
- `iphone/MakeReady/AuthManager.swift:469-539` — `devLogin` and `devLoginFailure`
- `iphone/MakeReady/Configuration.swift:327-351` — `DevLoginIdentity`
- `iphone/MakeReadyCaptureTests/AuthManagerLaunchTests.swift:138-250` — the `AuthIO` harness

**Tests:**
- `testEnvironmentListForEachBuild` and `testDefaultEnvironmentForEachBuild` — pure functions, callable from Debug (D5)
- `testStagingFixtureTitlesOrderAndDefault` — the closed list (D1)
- `testLoginRouteForEveryEnvironmentAndKey` — the routing table (D6)
- `testSignInUsesC1OnStagingWithAKey` — the route reaches C1 with the key and selected fixture (D6)
- `testFixtureLoginDecodesAndAuthenticates` — decode of C1 (§Contract)
- `testFixturesNotSeededMapsToBeingResetAndKeepsTheFixture` — D12's message path (D12)
- `testNonJsonFixture404IsNotBeingReset` — a closed gate is not a reset (§Contract)
- `testFixtureResetSucceedsOnlyOn202` — C2's statuses (§Contract)
- `testFixturesBeingResetMessage` — the copy (D12)

```swift
// ProfileStopgapTests.swift, class StagingEnvironmentTests
func testEnvironmentListForEachBuild() {
    XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .staging), [.staging, .production])
    XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .debug), [.local, .staging, .production])
    XCTAssertEqual(AppConfiguration.switcherEnvironments(for: .production), [.local, .staging, .production])
}
func testDefaultEnvironmentForEachBuild() {
    XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .staging), .staging)
    XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .debug), .production)
    XCTAssertEqual(AppConfiguration.defaultEnvironment(for: .production), .production)
}
func testStagingFixtureTitlesOrderAndDefault() {
    let saved = UserDefaults.standard.string(forKey: "stagingFixture")
    defer { UserDefaults.standard.set(saved, forKey: "stagingFixture") }
    UserDefaults.standard.removeObject(forKey: "stagingFixture")
    XCTAssertEqual(StagingFixture.allCases.map(\.title), ["Fully populated", "New group"])
    XCTAssertEqual(StagingFixture.allCases.map(\.rawValue), ["full", "new-group"])
    XCTAssertEqual(StagingFixture.current, .full)
    StagingFixture.current = .newGroup
    XCTAssertEqual(StagingFixture.current, .newGroup)
}
func testLoginRouteForEveryEnvironmentAndKey() {
    XCTAssertEqual(AuthManager.loginRoute(env: .local, devMode: true, fixtureKey: "k"), .devLogin)
    XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: true, fixtureKey: "k"), .fixtureLogin)
    XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: true, fixtureKey: ""), .google)
    XCTAssertEqual(AuthManager.loginRoute(env: .production, devMode: true, fixtureKey: "k"), .google)
    XCTAssertEqual(AuthManager.loginRoute(env: .staging, devMode: false, fixtureKey: "k"), .google)
}
```

```swift
// AuthManagerLaunchTests.swift: extend io() with fixtureKey and record each request's X-Fixture-Key;
// save and restore the "stagingFixture" default in setUp and tearDown, as the identity default is
private let c1Body = #"{"success":true,"user":{"id":"u1","email":"fixtures-new@makeready.local","name":"New","avatarURL":null},"sessionCookie":"s:abc"}"#

func testSignInUsesC1OnStagingWithAKey() async throws {
    AppConfiguration.selectedEnvironment = .staging
    StagingFixture.current = .newGroup
    fixtureKey = "k"
    responses["/auth/fixture-login"] = .success((200, c1Body))
    api.stub("/auth/leader-access", json: #"{"canAccess":true}"#)
    let auth = AuthManager(io: io())
    try await auth.signIn()
    XCTAssertEqual(sentFixtureKeys["/auth/fixture-login"], ["k"])
    let body = try XCTUnwrap(sentBodies["/auth/fixture-login"]?.first)
    XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["fixture": "new-group"])
    XCTAssertEqual(devLoginEmails(), [])
}
func testFixtureLoginDecodesAndAuthenticates() async throws {
    fixtureKey = "k"
    responses["/auth/fixture-login"] = .success((200, c1Body))
    api.stub("/auth/leader-access", json: #"{"canAccess":true}"#)
    let auth = AuthManager(io: io())
    try await auth.fixtureLogin(.newGroup)
    XCTAssertTrue(auth.isAuthenticated)
    XCTAssertEqual(auth.currentUser?.email, "fixtures-new@makeready.local")
    XCTAssertEqual(credential, "s:abc")
}
func testFixturesNotSeededMapsToBeingResetAndKeepsTheFixture() async {
    StagingFixture.current = .newGroup
    responses["/auth/fixture-login"] = .success((404, #"{"success":false,"error":"fixtures_not_seeded"}"#))
    let auth = AuthManager(io: io())
    do {
        try await auth.fixtureLogin(.newGroup)
        XCTFail("expected a failure")
    } catch {
        guard case AuthError.fixturesBeingReset = error else { return XCTFail("got \(error)") }
    }
    XCTAssertEqual(StagingFixture.current, .newGroup)
    XCTAssertFalse(auth.isAuthenticated)
}
func testNonJsonFixture404IsNotBeingReset() {
    let error = AuthManager.fixtureLoginFailure(status: 404, body: Data("<html>Cannot POST</html>".utf8))
    XCTAssertEqual((error as? URLError)?.code, .userAuthenticationRequired)
}
func testFixtureResetSucceedsOnlyOn202() async throws {
    fixtureKey = "k"
    responses["/auth/fixture-reset"] = .success((202, #"{"success":true}"#))
    let auth = AuthManager(io: io())
    try await auth.fixtureReset(.full)
    XCTAssertEqual(sentFixtureKeys["/auth/fixture-reset"], ["k"])
    responses["/auth/fixture-reset"] = .success((502, #"{"success":false,"error":"reset_unavailable"}"#))
    do {
        try await auth.fixtureReset(.full)
        XCTFail("expected a failure")
    } catch {
        XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
    }
}
```

```swift
// LoginOutcomeTests.swift
func testFixturesBeingResetMessage() {
    let text = "This test data is being reset. Try again in a few minutes."
    XCTAssertEqual(LoginOutcome.message(for: AuthError.fixturesBeingReset), text)
    XCTAssertEqual(AuthError.fixturesBeingReset.errorDescription, text)
}
```

The harness's existing leader-access stub in `testDevLoginLeaderSucceeds` (`:167`) is the form to use where these tests write `api.stub`.

- [ ] **Step 1: Write the listed tests and extend the harness**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (`<builder>` is the directory your brief names)
- [ ] **Step 3: Add the `Configuration.swift` parts, then the `AuthManager` and `LoginOutcome` parts**
- [ ] **Step 4: Run the same verifier request and watch them pass**
- [ ] **Step 5: Commit** — `feat(staging-fixtures): sign in with C1 on the staging build`

### Task 7: Test data on Profile
App: iphone
Phase: 2
Recipe: `/ios-error-surface`; SPEC D4, D5, D11, D12, D14, D15, §iphone *Profile*

**Files:**
- Modify: `iphone/MakeReady/State/Actions/EnvironmentActions.swift:93-105` — `switchFixture` and `resetFixture`
- Modify: `iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift:7-11,26,38,119,121` — the predicate, the environment list, the Test data group and the confirm
- Test: `iphone/MakeReadyCaptureTests/ProfileStopgapTests.swift` — the predicate and copy
- Test: `iphone/MakeReadyCaptureTests/EnvironmentActionsTests.swift` — `EnvironmentIdentitySwitchTests` gains the switch, reset and fresh-world cases

**Interfaces:**
- Consumes: `AppConfiguration.fixtureAccessKey`, `AppConfiguration.switcherEnvironments(for:)`, `AppConfiguration.current`, `StagingFixture`, `AuthManager.signIn`, `AuthManager.signOut`, `AuthManager.fixtureReset(_:)`, `AuthManager.loginNotice`, `LoginOutcome.message(for:)`, `AuthError.fixturesBeingReset`
- Produces:
  - `ProfileStopgapContainer.showsFixturePicker(fixtureKey:env:)` — returns a boolean
  - `EnvironmentActions.switchFixture(_:auth:)` — takes a `StagingFixture` and an `AuthManager`, async throwing
  - `EnvironmentActions.resetFixture(_:auth:)` — same arguments, async throwing, returns nothing
  - `FixtureResetCopy` — enum in `ProfileStopgapContainer.swift`, so no project file changes: `confirmTitle`, `confirmMessage(for:)`, `action`, `cancelLabel`, `startedMessage`, `failedMessage`

**Behaviour:**
- `showsFixturePicker` is true only with a non-empty key and Staging (D4)
- The group is titled "Test data" and has one `RadioOptionRow` per `StagingFixture`, then a `PageActionButton` labelled "Reset" with role `.secondary`, reusing `identityPicker`'s layout (D4, §iphone *Profile*)
- The environment rows and `refreshHealth` use `AppConfiguration.switcherEnvironments(for: AppConfiguration.current)` in place of `allCases` at `:26,119,121`, so the staging build neither lists nor probes Local (D5)
- `switchFixture` returns at once if the fixture is already current; otherwise it persists the fixture, signs out and signs in, and `signIn` uses C1 (§iphone *Profile*, D6)
- On failure `switchFixture` sets `auth.loginNotice` from `LoginOutcome.message(for:)` and rethrows, and does **not** revert the fixture, unlike `switchIdentity` (D12)
- The container logs that failure with `recordError(..., surface: false)`, as `selectIdentity` does, because Profile has unmounted and Login shows the message (D12)
- Reset opens `ActionMenuOverlay` through `.actionMenuPresentation` with the exact copy below; Cancel closes it and does nothing else (D14)
- On confirm, `resetFixture` calls `auth.fixtureReset` for `StagingFixture.current`. Success shows `startedMessage` inline; failure shows `failedMessage` inline and logs with `recordError(error, context: "ProfileStopgapContainer.reset", surface: false)` (D11, D14)
- The started message uses a neutral text colour (`Token.textSecondary`) in a separate state from `switchError`, at the same position; a failure uses `switchError`, which is `Token.negative`. Each attempt clears both first (D14)
- A second tap on Reset, a fixture row or an environment row while `isSwitching` is true is ignored (§iphone *Profile*)
- The app does not sign out on a 202 and does not watch for the reset's end; there is no progress state (D11, D15)
- No `.sheet`, `.fullScreenCover` or `asyncAfter`; no `MakeReadyUI/` file is edited, because the stopgap is not a d2m file (§iphone *Profile*)
- `ProfilePage` is not edited, because it is unreachable (§iphone *Profile*)
- 🟡 **Build-time risk F12:** a tester's cached `AppState` can show rows from before a reset, so sign-out and sign-in must show the fresh world. `testSignOutThenSignInDropsTheCachedWorld` settles this

The exact copy (D11, D14). `<fixture title>` is `StagingFixture.title`:

```swift
enum FixtureResetCopy {
    static let confirmTitle = "Reset this test data?"
    static func confirmMessage(for fixture: StagingFixture) -> String { "Reset \(fixture.title) for everyone on it?" }
    static let action = ActionMenuOverlay.ActionItem(glyph: "trash-2", label: "Reset", tone: .destructive)
    static let cancelLabel = "Cancel"
    static let startedMessage = "Reset started. This takes a few minutes and affects everyone on this fixture."
    static let failedMessage = "Couldn't start the reset. Try again."
}
```

**Pattern:**
- `iphone/MakeReady/UI2/Containers/Enrollments/EnrollChecklistContainer.swift:90-110` — `ActionMenuOverlay` as a confirm
- `iphone/MakeReady/UI2/Containers/Profile/ProfileStopgapContainer.swift:53-67,101-115` — `identityPicker` and `selectIdentity`

**Tests:**
- `testFixturePickerOnlyWithAKeyOnStaging` — the predicate (D4)
- `testResetCopy` — the exact strings (D11, D14)
- `testSwitchFixtureSignsInAsTheFixture` — sign out, then C1 with the new fixture (§iphone *Profile*)
- `testSwitchFixtureKeepsTheFixtureOnFailure` — D12's message on Login, and the fixture kept (D12)
- `testResetFixturePostsTheCurrentFixtureAndKeepsTheSession` — C2 and no sign-out (D11, D15)
- `testSignOutThenSignInDropsTheCachedWorld` — the fresh world after a reset (D15, F12)

```swift
// ProfileStopgapTests.swift
func testFixturePickerOnlyWithAKeyOnStaging() {
    XCTAssertTrue(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .staging))
    XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "", env: .staging))
    XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .production))
    XCTAssertFalse(ProfileStopgapContainer.showsFixturePicker(fixtureKey: "k", env: .local))
}
func testResetCopy() {
    XCTAssertEqual(FixtureResetCopy.confirmTitle, "Reset this test data?")
    XCTAssertEqual(FixtureResetCopy.confirmMessage(for: .newGroup), "Reset New group for everyone on it?")
    XCTAssertEqual(FixtureResetCopy.action.label, "Reset")
    XCTAssertEqual(FixtureResetCopy.cancelLabel, "Cancel")
    XCTAssertEqual(FixtureResetCopy.startedMessage, "Reset started. This takes a few minutes and affects everyone on this fixture.")
    XCTAssertEqual(FixtureResetCopy.failedMessage, "Couldn't start the reset. Try again.")
}
```

```swift
// EnvironmentActionsTests.swift, EnvironmentIdentitySwitchTests: extend its harness with fixtureKey,
// save and restore the "stagingFixture" default, select .staging in the setup of these tests
func testSwitchFixtureSignsInAsTheFixture() async throws {
    StagingFixture.current = .full
    fixtureKey = "k"
    responses["/auth/fixture-login"] = .success((200, c1Body))
    let auth = signedInAuth()
    try await EnvironmentActions().switchFixture(.newGroup, auth: auth)
    XCTAssertEqual(StagingFixture.current, .newGroup)
    XCTAssertEqual(sentPaths.filter { $0.hasPrefix("/auth/") }.suffix(2), ["/auth/logout", "/auth/fixture-login"])
    XCTAssertTrue(auth.isAuthenticated)
}
func testSwitchFixtureKeepsTheFixtureOnFailure() async {
    StagingFixture.current = .full
    fixtureKey = "k"
    responses["/auth/fixture-login"] = .success((404, #"{"success":false,"error":"fixtures_not_seeded"}"#))
    let auth = signedInAuth()
    do {
        try await EnvironmentActions().switchFixture(.newGroup, auth: auth)
        XCTFail("expected a failure")
    } catch {}
    XCTAssertEqual(StagingFixture.current, .newGroup)
    XCTAssertEqual(auth.loginNotice, "This test data is being reset. Try again in a few minutes.")
    XCTAssertFalse(auth.isAuthenticated)
}
func testResetFixturePostsTheCurrentFixtureAndKeepsTheSession() async throws {
    StagingFixture.current = .newGroup
    fixtureKey = "k"
    responses["/auth/fixture-reset"] = .success((202, #"{"success":true}"#))
    let auth = signedInAuth()
    try await EnvironmentActions().resetFixture(.newGroup, auth: auth)
    let body = try XCTUnwrap(sentBodies["/auth/fixture-reset"]?.first)
    XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["fixture": "new-group"])
    XCTAssertTrue(auth.isAuthenticated)
    XCTAssertFalse(sentPaths.contains("/auth/logout"))
}
func testSignOutThenSignInDropsTheCachedWorld() async throws {
    fixtureKey = "k"
    responses["/auth/fixture-login"] = .success((200, c1Body))
    let auth = signedInAuth()
    AppState.shared.organizationId = "world-before-the-reset"
    try await auth.signOut()
    XCTAssertNil(AppState.shared.organizationId)
    try await auth.signIn()
    XCTAssertTrue(auth.isAuthenticated)
    XCTAssertNil(AppState.shared.organizationId)
}
```

`signedInAuth()`, `c1Body`, `sentPaths` and `fixtureKey` are harness additions in this test class: `signedInAuth()` returns an `AuthManager` over its `AuthIO` with a stored credential and a passing leader-access stub.

- [ ] **Step 1: Write the listed tests and extend the harness**
- [ ] **Step 2: Request a focused verifier run and watch them fail** — `node <builder>/scripts/verify/verify.mjs request "$(git rev-parse --show-toplevel)" HEAD --tier commit --tree`, then `verify.mjs wait <id>` (`<builder>` is the directory your brief names)
- [ ] **Step 3: Add `switchFixture` and `resetFixture` to `EnvironmentActions`**
- [ ] **Step 4: Add the predicate, `FixtureResetCopy`, the Test data group, the confirm and the environment-list change to the container**
- [ ] **Step 5: Run the same verifier request and watch them pass**
- [ ] **Step 6: Commit** — `feat(staging-fixtures): Test data picker and Reset on Profile`
